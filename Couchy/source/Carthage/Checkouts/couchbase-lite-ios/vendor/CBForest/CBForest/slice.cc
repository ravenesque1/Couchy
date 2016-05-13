//
//  slice.cc
//  CBForest
//
//  Created by Jens Alfke on 5/12/14.
//  Copyright (c) 2014 Couchbase. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#include "slice.hh"
#include <algorithm>
#include <stdlib.h>

namespace cbforest {

    int slice::compare(slice b) const {
        size_t minSize = std::min(this->size, b.size);
        int result = memcmp(this->buf, b.buf, minSize);
        if (result == 0) {
            if (this->size < b.size)
                result = -1;
            else if (this->size > b.size)
                result = 1;
        }
        return result;
    }

    slice slice::read(size_t nBytes) {
        if (nBytes > size)
            return null;
        slice result(buf, nBytes);
        moveStart(nBytes);
        return result;
    }

    bool slice::readInto(slice dst) {
        if (dst.size > size)
            return false;
        ::memcpy((void*)dst.buf, buf, dst.size);
        moveStart(dst.size);
        return true;
    }

    bool slice::writeFrom(slice src) {
        if (src.size > size)
            return false;
        ::memcpy((void*)buf, src.buf, src.size);
        moveStart(src.size);
        return true;
    }

    slice slice::copy() const {
        if (buf == NULL)
            return *this;
        void* copied = ::malloc(size);
        ::memcpy(copied, buf, size);
        return slice(copied, size);
    }

    void slice::free() {
        ::free((void*)buf);
        buf = NULL;
        size = 0;
    }
    
    bool slice::hasPrefix(slice s) const {
        return s.size > 0 && size >= s.size && ::memcmp(buf, s.buf, s.size) == 0;
    }

    slice::operator std::string() const {
        return std::string((const char*)buf, size);
    }

    const slice slice::null;

    void* alloc_slice::alloc(const void* src, size_t s) {
        void* buf = ::malloc(s);
        ::memcpy((void*)buf, src, s);
        return buf;
    }

    alloc_slice& alloc_slice::operator=(slice s) {
        s = s.copy();
        buf = s.buf;
        size = s.size;
        reset((char*)buf);
        return *this;
    }


    std::string slice::hexString() const {
        static const char kDigits[17] = "0123456789abcdef";
        std::string result;
        for (size_t i = 0; i < size; i++) {
            uint8_t byte = (*this)[(unsigned)i];
            result += kDigits[byte >> 4];
            result += kDigits[byte & 0xF];
        }
        return result;
    }

}
