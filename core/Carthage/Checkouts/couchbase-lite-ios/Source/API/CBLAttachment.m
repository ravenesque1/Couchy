//
//  CBLAttachment.m
//  CouchbaseLite
//
//  Created by Jens Alfke on 6/21/12.
//  Copyright (c) 2012-2013 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CBLAttachment.h"
#import "CouchbaseLitePrivate.h"

#import "CBLDatabase+Attachments.h"
#import "CBL_Attachment.h"
#import "CBL_BlobStoreWriter.h"
#import "CBLInternal.h"


@implementation CBLAttachment
{
    CBLRevision* _rev;
    NSString* _name;
    NSDictionary* _metadata;
    id _body;
}


- (instancetype) initWithRevision: (CBLRevision*)rev
                             name: (NSString*)name
                         metadata: (NSDictionary*)metadata
{
    NSParameterAssert(rev);
    NSParameterAssert(name);
    NSParameterAssert(metadata);
    self = [super init];
    if (self) {
        _rev = rev;
        _name = [name copy];
        _metadata = [metadata copy];
    }
    return self;
}


- (instancetype) _initWithContentType: (NSString*)contentType
                                 body: (id)body
{
    NSParameterAssert(contentType);
    NSParameterAssert(body);
    Assert([body isKindOfClass: [NSData class]] ||
                 ([body isKindOfClass: [NSURL class]] && [body isFileURL]),
           @"Invalid attachment body: %@", body);
    self = [super init];
    if (self) {
        NSNumber* lengthObj = nil;
        if ([body isKindOfClass: [NSData class]])
            lengthObj = @([body length]);
        else
            [(NSURL*)body getResourceValue: &lengthObj forKey: NSURLFileSizeKey error: NULL];
        _metadata = $dict({@"content_type", contentType},
                          {@"length", lengthObj},
                          {@"follows", $true});
        _body = body;
    }
    return self;
}


@synthesize revision=_rev, name=_name, metadata=_metadata;


- (NSString *)description
{
    return [NSString stringWithFormat:@"%@[%@, %lld bytes]",
            [self class], self.contentType, self.length];
}


- (CBLDocument*) document {
    return _rev.document;
}


- (NSString*) contentType {
    return $castIf(NSString, _metadata[@"content_type"]);
}


- (UInt64) length {
    NSNumber* lengthObj = $castIf(NSNumber, _metadata[@"length"]);
    return lengthObj ? [lengthObj longLongValue] : 0;
}


- (UInt64) encodedLength {
    NSNumber* lengthObj = $castIf(NSNumber, _metadata[@"encoded_length"] ?: _metadata[@"length"]);
    return lengthObj ? [lengthObj longLongValue] : 0;
}


#pragma mark - BODY


- (CBL_Attachment*) _internalAttachment {
    CBLStatus status;
    return [_rev.database attachmentForDict: _metadata named: _name status: &status];
}


- (NSData*) bodyIfNew {
    return _body ? self.content : nil;
}


- (BOOL) contentAvailable {
    if (_body) {
        return ([_body isKindOfClass: [NSData class]] ||
                ([_body isKindOfClass: [NSURL class]] && [_body isFileURL]));
    } else {
        return self._internalAttachment.hasContent;
    }
}


- (NSData*) content {
    if (_body) {
        if ([_body isKindOfClass: [NSData class]])
            return _body;
        else if ([_body isKindOfClass: [NSURL class]] && [_body isFileURL]) {
            return [NSData dataWithContentsOfURL: _body
                                         options: NSDataReadingUncached
                                           error: nil];
        }
        return nil;
    } else {
        return self._internalAttachment.content;
    }
}


- (NSURL*) contentURL {
    if (_body) {
        if ([_body isKindOfClass: [NSURL class]] && [_body isFileURL])
            return _body;
        return nil;
    } else {
        return self._internalAttachment.contentURL;
    }
}


- (NSInputStream*) openContentStream {
    NSInputStream* stream = nil;
    if (_body) {
        if ([_body isKindOfClass: [NSData class]])
            stream = [NSInputStream inputStreamWithData: _body];
        else if ([_body isKindOfClass: [NSURL class]] && [_body isFileURL])
            stream = [NSInputStream inputStreamWithURL: _body];
    } else {
        stream = self._internalAttachment.contentStream;
    }
    [stream open];
    return stream;
}


- (BOOL) purge {
    CBLBlobKey key;
    return !_body
        && [CBL_Attachment digest: _metadata[@"digest"] toBlobKey: &key]
        && [_rev.database.attachmentStore deleteBlobForKey: key];
}


static CBL_BlobStoreWriter* blobStoreWriterForBody(CBLDatabase* tddb, NSData* body) {
    CBL_BlobStoreWriter* writer = tddb.attachmentWriter;
    [writer appendData: body];
    [writer finish];
    return writer;
}


// Goes through an _attachments dictionary and replaces any values that are CBLAttachment objects
// with proper JSON metadata dicts. It registers the attachment bodies with the blob store and sets
// the metadata 'digest' and 'follows' properties accordingly.
+ (NSDictionary*) installAttachmentBodies: (NSDictionary*)attachments
                             intoDatabase: (CBLDatabase*)database
{
    CBLDatabase* tddb = database;
    return [attachments my_dictionaryByUpdatingValues: ^id(NSString* name, id value) {
        CBLAttachment* attachment = $castIf(CBLAttachment, value);
        if (attachment) {
            // Replace the attachment object with a metadata dictionary:
            NSMutableDictionary* metadata = [attachment.metadata mutableCopy];
            value = metadata;
            NSData* body = attachment.bodyIfNew;
            if (body) {
                // Copy attachment body into the database's blob store:
                // OPT: If _body is an NSURL, could just copy the file without reading into RAM
                CBL_BlobStoreWriter* writer = blobStoreWriterForBody(tddb, body);
                metadata[@"length"] = @(body.length);
                metadata[@"digest"] = writer.MD5DigestString;
                metadata[@"follows"] = $true;
                [tddb rememberAttachmentWriter: writer];
            }
        }
        return value;
    }];
}


@end
