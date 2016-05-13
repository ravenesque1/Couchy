//
//  BLIPPool.h
//  BLIP
//
//  Created by Jens Alfke on 9/16/13.
//  Copyright (c) 2013-2015 Couchbase, Inc. All rights reserved.

#import "BLIPConnection.h"


/** A pool of open BLIPWebSocketConnections to different URLs.
    By using this class you can conserve sockets by opening only a single socket to a WebSocket endpoint. */
@interface BLIPPool : NSObject

- (instancetype) initWithDelegate: (id<BLIPConnectionDelegate>)delegate
                    dispatchQueue: (dispatch_queue_t)queue;

/** All the opened sockets will call this delegate. */
@property (weak) id<BLIPConnectionDelegate> delegate;

/** Returns an open BLIPConnection to the given URL. If none is open yet, it will open one. */
- (BLIPConnection*) socketToURL: (NSURL*)url error: (NSError**)outError;

/** Returns an already-open BLIPConnection to the given URL, or nil if there is none. */
- (BLIPConnection*) existingSocketToURL: (NSURL*)url error: (NSError**)outError;

/** Closes all open sockets, with the default status code. */
- (void) close;

/** Closes all open sockets. */
- (void) closeWithCode:(NSInteger)code reason:(NSString *)reason;

@end
