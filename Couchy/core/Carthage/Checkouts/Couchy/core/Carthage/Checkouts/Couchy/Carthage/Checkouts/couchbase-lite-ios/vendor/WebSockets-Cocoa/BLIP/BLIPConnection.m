//
//  BLIPConnection.m
//  WebSocket
//
//  Created by Jens Alfke on 4/1/13.
//  Copyright (c) 2013 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "BLIPConnection.h"
#import "BLIPConnection+Transport.h"
#import "BLIPRequest.h"
#import "BLIP_Internal.h"

#import "ExceptionUtils.h"
#import "Logging.h"
#import "Test.h"
#import "MYData.h"


#define kDefaultFrameSize 4096


@interface BLIPConnection ()
@property (readwrite) BOOL active;
@end


@implementation BLIPConnection
{
    dispatch_queue_t _transportQueue;
    bool _transportIsOpen;
    NSError* _error;
    __weak id<BLIPConnectionDelegate> _delegate;
    dispatch_queue_t _delegateQueue;
    
    NSMutableArray *_outBox;
    UInt32 _numRequestsSent;

    UInt32 _numRequestsReceived;
    NSMutableDictionary *_pendingRequests, *_pendingResponses;
    NSUInteger _poppedMessageCount;
}

@synthesize error=_error, dispatchPartialMessages=_dispatchPartialMessages, active=_active;


- (instancetype) initWithTransportQueue: (dispatch_queue_t)transportQueue
                                 isOpen: (BOOL)isOpen
{
    Assert(transportQueue);
    self = [super init];
    if (self) {
        _transportQueue = transportQueue;
        _transportIsOpen = isOpen;
        _delegateQueue = dispatch_get_main_queue();
        _pendingRequests = [[NSMutableDictionary alloc] init];
        _pendingResponses = [[NSMutableDictionary alloc] init];
    }
    return self;
}


// Public API
- (void) setDelegate: (id<BLIPConnectionDelegate>)delegate
               queue: (dispatch_queue_t)delegateQueue
{
    Assert(!_delegate, @"Don't change the delegate");
    _delegate = delegate;
    _delegateQueue = delegateQueue ?: dispatch_get_main_queue();
}


- (void) _callDelegate: (SEL)selector block: (void(^)(id<BLIPConnectionDelegate>))block {
    id<BLIPConnectionDelegate> delegate = _delegate;
    if (delegate && [delegate respondsToSelector: selector]) {
        dispatch_async(_delegateQueue, ^{
            block(delegate);
        });
    }
}


// Public API
- (NSURL*) URL {
    return nil; // Subclasses should override
}


- (void) updateActive {
    BOOL active = _outBox.count || _pendingRequests.count ||
                    _pendingResponses.count || _poppedMessageCount;
    if (active != _active) {
        LogTo(BLIPVerbose, @"%@ active = %@", self, (active ?@"YES" : @"NO"));
        self.active = active;
    }
}


#pragma mark - OPEN/CLOSE:


// Public API
- (BOOL) connect: (NSError**)outError {
    AssertAbstractMethod();
}

// Public API
- (void)close {
    AssertAbstractMethod();
}


- (void) _closeWithError: (NSError*)error {
    self.error = error;
    [self close];
}


// Subclasses call this
- (void) transportDidOpen {
    LogTo(BLIP, @"%@ is open!", self);
    _transportIsOpen = true;
    if (_outBox.count > 0)
        [self feedTransport]; // kick the queue to start sending

    [self _callDelegate: @selector(blipConnectionDidOpen:)
                  block: ^(id<BLIPConnectionDelegate> delegate) {
        [delegate blipConnectionDidOpen: self];
    }];
}


// Subclasses call this
- (void) transportDidCloseWithError:(NSError *)error {
    LogTo(BLIP, @"%@ closed with error %@", self, error);
    if (_transportIsOpen) {
        _transportIsOpen = NO;
        [self _callDelegate: @selector(blipConnection:didCloseWithError:)
                      block: ^(id<BLIPConnectionDelegate> delegate) {
                          [delegate blipConnection: self didCloseWithError: error];
                      }];
    } else {
        if (error && !_error)
            self.error = error;
        [self _callDelegate: @selector(blipConnection:didFailWithError:)
                      block: ^(id<BLIPConnectionDelegate> delegate) {
            [delegate blipConnection: self didFailWithError: error];
        }];
    }
}


#pragma mark - SENDING:


// Public API
- (BLIPRequest*) request {
    return [[BLIPRequest alloc] _initWithConnection: self body: nil properties: nil];
}

// Public API
- (BLIPRequest*) requestWithBody: (NSData*)body
                      properties: (NSDictionary*)properties
{
    return [[BLIPRequest alloc] _initWithConnection: self body: body properties: properties];
}

// Public API
- (BLIPResponse*) sendRequest: (BLIPRequest*)request {
    if (!request.isMine || request.sent) {
        // This was an incoming request that I'm being asked to forward or echo;
        // or it's an outgoing request being sent to multiple connections.
        // Since a particular BLIPRequest can only be sent once, make a copy of it to send:
        request = [request mutableCopy];
    }
    BLIPConnection* itsConnection = request.connection;
    if (itsConnection==nil)
        request.connection = self;
    else
        Assert(itsConnection==self,@"%@ is already assigned to a different connection",request);
    return [request send];
}


- (void) _queueMessage: (BLIPMessage*)msg isNew: (BOOL)isNew {
    NSInteger n = _outBox.count, index;
    if (msg.urgent && n > 1) {
        // High-priority gets queued after the last existing high-priority message,
        // leaving one regular-priority message in between if possible.
        for (index=n-1; index>0; index--) {
            BLIPMessage *otherMsg = _outBox[index];
            if ([otherMsg urgent]) {
                index = MIN(index+2, n);
                break;
            } else if (isNew && otherMsg._bytesWritten==0) {
                // But have to keep message starts in order
                index = index+1;
                break;
            }
        }
        if (index==0)
            index = 1;
    } else {
        // Regular priority goes at the end of the queue:
        index = n;
    }
    if (! _outBox)
        _outBox = [[NSMutableArray alloc] init];
    [_outBox insertObject: msg atIndex: index];

    if (isNew) {
        LogTo(BLIP,@"%@ queuing outgoing %@ at index %li",self,msg,(long)index);
        if (n==0 && _transportIsOpen) {
            dispatch_async(_transportQueue, ^{
                [self feedTransport];  // queue the first message now
            });
        }
    }
    [self updateActive];
}


// BLIPMessageSender protocol: Called from -[BLIPRequest send]
- (BOOL) _sendRequest: (BLIPRequest*)q response: (BLIPResponse*)response {
    Assert(!q.sent,@"message has already been sent");
    __block BOOL result;
    dispatch_sync(_transportQueue, ^{
        if (_transportIsOpen && !self.transportCanSend) {
            Warn(@"%@: Attempt to send a request after the connection has started closing: %@",self,q);
            result = NO;
            return;
        }
        [q _assignedNumber: ++_numRequestsSent];
        if (response) {
            [response _assignedNumber: _numRequestsSent];
            _pendingResponses[$object(response.number)] = response;
            [self updateActive];
        }
        [self _queueMessage: q isNew: YES];
        result = YES;
    });
    return result;
}

// Internal API: Called from -[BLIPResponse send]
- (BOOL) _sendResponse: (BLIPResponse*)response {
    Assert(!response.sent,@"message has already been sent");
    dispatch_async(_transportQueue, ^{
        [self _queueMessage: response isNew: YES];
    });
    return YES;
}


// Subclasses call this
// Pull a frame from the outBox queue and send it to the transport:
- (void) feedTransport {
    if (_outBox.count > 0) {
        // Pop first message in queue:
        BLIPMessage *msg = _outBox[0];
        [_outBox removeObjectAtIndex: 0];
        ++_poppedMessageCount; // remember that this message is still active
        
        // As an optimization, allow message to send a big frame unless there's a higher-priority
        // message right behind it:
        size_t frameSize = kDefaultFrameSize;
        if (msg.urgent || _outBox.count==0 || ! [_outBox[0] urgent])
            frameSize *= 4;

        // Ask the message to generate its next frame. Do this on the delegate queue:
        __block BOOL moreComing;
        __block NSData* frame;
        dispatch_async(_delegateQueue, ^{
            frame = [msg nextFrameWithMaxSize: (UInt16)frameSize moreComing: &moreComing];
            void (^onSent)() = moreComing ? nil : msg.onSent;
            dispatch_async(_transportQueue, ^{
                // SHAZAM! Send the frame to the transport:
                [self sendFrame: frame];

                if (moreComing) {
                    // add the message back so it can send its next frame later:
                    [self _queueMessage: msg isNew: NO];
                } else {
                    if (onSent)
                        dispatch_async(_delegateQueue, onSent);
                }
                --_poppedMessageCount;
                [self updateActive];
            });
        });
    } else {
        //LogTo(BLIPVerbose,@"%@: no more work for writer",self);
    }
}


- (BOOL) transportCanSend {
    AssertAbstractMethod();
}

- (void) sendFrame:(NSData *)frame {
    AssertAbstractMethod();
}


#pragma mark - RECEIVING FRAMES:


// Subclasses call this
- (void) didReceiveFrame:(NSData*)frame {
    const void* start = frame.bytes;
    const void* end = start + frame.length;
    UInt64 messageNum;
    const void* pos = MYDecodeVarUInt(start, end, &messageNum);
    if (pos) {
        UInt64 flags;
        pos = MYDecodeVarUInt(pos, end, &flags);
        if (pos && flags <= kBLIP_MaxFlag) {
            NSData* body = [NSData dataWithBytes: pos length: frame.length - (pos-start)];
            [self receivedFrameWithNumber: (UInt32)messageNum
                                    flags: (BLIPMessageFlags)flags
                                     body: body];
            return;
        }
    }
    [self _closeWithError: BLIPMakeError(kBLIPError_BadFrame,
                                         @"Bad varint encoding in frame flags")];
}


- (void) receivedFrameWithNumber: (UInt32)requestNumber
                           flags: (BLIPMessageFlags)flags
                            body: (NSData*)body
{
    static const char* kTypeStrs[16] = {"MSG","RPY","ERR","3??","4??","5??","6??","7??"};
    BLIPMessageType type = flags & kBLIP_TypeMask;
    LogTo(BLIPVerbose,@"%@ rcvd frame of %s #%u, length %lu",self,kTypeStrs[type],(unsigned int)requestNumber,(unsigned long)body.length);

    id key = $object(requestNumber);
    BOOL complete = ! (flags & kBLIP_MoreComing);
    switch(type) {
        case kBLIP_MSG: {
            // Incoming request:
            BLIPRequest *request = _pendingRequests[key];
            if (request) {
                // Continuation frame of a request:
                if (complete) {
                    [_pendingRequests removeObjectForKey: key];
                }
            } else if (requestNumber == _numRequestsReceived+1) {
                // Next new request:
                request = [[BLIPRequest alloc] _initWithConnection: self
                                                            isMine: NO
                                                             flags: flags | kBLIP_MoreComing
                                                            number: requestNumber
                                                              body: nil];
                if (! complete)
                    _pendingRequests[key] = request;
                _numRequestsReceived++;
            } else {
                return [self _closeWithError: BLIPMakeError(kBLIPError_BadFrame, 
                                               @"Received bad request frame #%u (next is #%u)",
                                               (unsigned int)requestNumber,
                                               (unsigned)_numRequestsReceived+1)];
            }

            [self _receiveFrameWithFlags: flags body: body complete: complete forMessage: request];
            break;
        }
            
        case kBLIP_RPY:
        case kBLIP_ERR: {
            BLIPResponse *response = _pendingResponses[key];
            if (response) {
                if (complete) {
                    [_pendingResponses removeObjectForKey: key];
                }
                [self _receiveFrameWithFlags: flags body: body complete: complete forMessage: response];

            } else {
                if (requestNumber <= _numRequestsSent)
                    LogTo(BLIP,@"??? %@ got unexpected response frame to my msg #%u",
                          self,(unsigned int)requestNumber); //benign
                else
                    return [self _closeWithError: BLIPMakeError(kBLIPError_BadFrame, 
                                                          @"Bogus message number %u in response",
                                                          (unsigned int)requestNumber)];
            }
            break;
        }
            
        default:
            // To leave room for future expansion, undefined message types are just ignored.
            Log(@"??? %@ received header with unknown message type %i", self,type);
            break;
    }
}


- (void) _receiveFrameWithFlags: (BLIPMessageFlags)flags
                           body: (NSData*)body
                       complete: (BOOL)complete
                     forMessage: (BLIPMessage*)message
{
    [self updateActive];
    dispatch_async(_delegateQueue, ^{
        BOOL ok = [message _receivedFrameWithFlags: flags body: body];
        if (!ok) {
            dispatch_async(_transportQueue, ^{
                [self _closeWithError: BLIPMakeError(kBLIPError_BadFrame,
                                                     @"Couldn't parse message frame")];
            });
        } else if (complete && !self.dispatchPartialMessages) {
            if (message.isRequest)
                [self _dispatchRequest: (BLIPRequest*)message];
            else
                [self _dispatchResponse: (BLIPResponse*)message];
        }
    });
}


#pragma mark - DISPATCHING:


// called on delegate queue
- (void) _messageReceivedProperties: (BLIPMessage*)message {
    if (self.dispatchPartialMessages) {
        if (message.isRequest)
            [self _dispatchRequest: (BLIPRequest*)message];
        else
            [self _dispatchResponse: (BLIPResponse*)message];
    }
}


// Called on the delegate queue (by _dispatchRequest)!
- (BOOL) _dispatchMetaRequest: (BLIPRequest*)request {
#if 0
    NSString* profile = request.profile;
    if ([profile isEqualToString: kBLIPProfile_Bye]) {
        [self _handleCloseRequest: request];
        return YES;
    }
#endif
    return NO;
}


// called on delegate queue
- (void) _dispatchRequest: (BLIPRequest*)request {
    id<BLIPConnectionDelegate> delegate = _delegate;
    LogTo(BLIP,@"Dispatching %@",request.descriptionWithProperties);
    @try{
        BOOL handled;
        if (request._flags & kBLIP_Meta)
            handled =[self _dispatchMetaRequest: request];
        else {
            handled = [delegate respondsToSelector: @selector(blipConnection:receivedRequest:)]
                   && [delegate blipConnection: self receivedRequest: request];
        }

        if (request.complete) {
            if (!handled) {
                LogTo(BLIP,@"No handler found for incoming %@",request);
                [request respondWithErrorCode: kBLIPError_NotFound message: @"No handler was found"];
            } else if (! request.noReply && ! request.repliedTo) {
                LogTo(BLIP,@"Returning default empty response to %@",request);
                [request respondWithData: nil contentType: nil];
            }
        }
    }@catch( NSException *x ) {
        MYReportException(x,@"Dispatching BLIP request");
        [request respondWithException: x];
    }
}

- (void) _dispatchResponse: (BLIPResponse*)response {
    LogTo(BLIP,@"Dispatching %@",response);
    [self _callDelegate: @selector(blipConnection:receivedResponse:)
                  block: ^(id<BLIPConnectionDelegate> delegate) {
        [delegate blipConnection: self receivedResponse: response];
    }];
}


@end
