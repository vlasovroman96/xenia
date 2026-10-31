module os.mitauth;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1988, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

/*
 * MIT-MAGIC-COOKIE-1 authorization scheme
 * Author:  Keith Packard, MIT X Consortium
 */

import build.dix_config;

//import x11.X;
import include.os;
import os.osdep;
import os.mitauth;
import dix.dixstruct_priv;
import externs.gnu;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import os.WaitFor;
import dix.resource;
import os.timingsafe_memcmp;


struct auth {
    auth* next;
    ushort len;
    char* data;
    XID id;
}private auth* mit_auth;

XID MitAddCookie(ushort data_length, const(char)* data)
{
    auth* new_ = void;

    // check for possible duplicate and return it instead
    for (auth* walk = mit_auth; walk; walk=walk.next) {
        if ((walk.len == data_length) &&
            (memcmp(walk.data, data, data_length) == 0))
            return walk.id;
    }

    new_ = cast(auth*) calloc(1, auth.sizeof);
    if (!new_)
        return 0;
    new_.data = cast(char*)calloc(1, cast(uint) data_length);
    if (!new_.data) {
        free(new_);
        return 0;
    }
    new_.next = mit_auth;
    mit_auth = new_;
    memcpy(new_.data, data, cast(size_t) data_length);
    new_.len = data_length;
    new_.id = dixAllocServerXID();
    return new_.id;
}

XID MitCheckCookie(ushort data_length, const(char)* data, ClientPtr client, const(char*)* reason)
{
    auth* auth = void;

    for (auth = mit_auth; auth; auth = auth.next) {
        if (data_length == auth.len &&
            timingsafe_memcmp(data, auth.data, cast(int) data_length) == 0)
            return auth.id;
    }
    reason = cast(const(char*)*)"Invalid MIT-MAGIC-COOKIE-1 key".ptr;
    return cast(XID) -1;
}

int MitResetCookie()
{
    auth* auth = void, next = void;

    for (auth = mit_auth; auth; auth = next) {
        next = auth.next;
        free(auth.data);
        free(auth);
    }
    mit_auth = null;
    return 0;
}

int MitFromID(XID id, ushort* data_lenp, char** datap)
{
    auth* auth = void;

    for (auth = mit_auth; auth; auth = auth.next) {
        if (id == auth.id) {
            *data_lenp = auth.len;
            *datap = auth.data;
            return 1;
        }
    }
    return 0;
}

int MitRemoveCookie(ushort data_length, const(char)* data)
{
    auth* auth = void, prev = void;

    prev = null;
    for (auth = mit_auth; auth; prev = auth, auth = auth.next) {
        if (data_length == auth.len &&
            memcmp(data, auth.data, data_length) == 0) {
            if (prev)
                prev.next = auth.next;
            else
                mit_auth = auth.next;
            free(auth.data);
            free(auth);
            return 1;
        }
    }
    return 0;
}

private char[16] cookie = 0;         /* 128 bits */

XID MitGenerateCookie(uint data_length, const(char)* data, uint* data_length_return, char** data_return)
{
    int i = 0;

    while (data_length--) {
        cookie[i++] += *data++;
        if (i >= cookie.sizeof)
            i = 0;
    }
    arc4random_buf(cookie.ptr, cookie.sizeof);
    XID id = MitAddCookie(cookie.sizeof, cookie.ptr);
    if (!id)
        return 0;

    *data_return = cookie.ptr;
    *data_length_return = cookie.sizeof;
    return id;
}
