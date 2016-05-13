//
//  varint.hh
//  CBForest
//
//  Created by Jens Alfke on 3/31/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#ifndef CBForest_varint_hh
#define CBForest_varint_hh

#include <stddef.h>
#include "slice.hh"

namespace cbforest {

// Based on varint implementation from the Go language (src/pkg/encoding/binary/varint.go)
// This file implements "varint" encoding of 64-bit integers.
// The encoding is:
// - unsigned integers are serialized 7 bits at a time, starting with the
//   least significant bits
// - the most significant bit (msb) in each output byte indicates if there
//   is a continuation byte (msb = 1)


/** MaxVarintLenN is the maximum length of a varint-encoded N-bit integer. */
enum {
    kMaxVarintLen16 = 3,
    kMaxVarintLen32 = 5,
    kMaxVarintLen64 = 10,
};

/** Returns the number of bytes needed to encode a specific integer. */
size_t SizeOfVarInt(uint64_t n);

/** Encodes n as a varint, writing it to buf. Returns the number of bytes written. */
size_t PutUVarInt(void *buf, uint64_t n);

/** Decodes a varint from the bytes in buf, storing it into *n.
    Returns the number of bytes read, or 0 if the data is invalid (buffer too short or number
    too long.) */
size_t GetUVarInt(slice buf, uint64_t *n);

/** Decodes a varint from buf, and advances buf to the remaining space after it.
    Returns false if the end of the buffer is reached or there is a parse error. */
bool ReadUVarInt(slice *buf, uint64_t *n);

/** Encodes a varint into buf, and advances buf to the remaining space after it.
    Returns false if there isn't enough room. */
bool WriteUVarInt(slice *buf, uint64_t n);

}

#endif
