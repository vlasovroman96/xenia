module xcmisc;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993, 1998  The Open Group

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

import build.dix_config;

// import core.stdc.stdint;
//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.xcmiscproto;

import dix.dix_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.rpcbuf_priv;
import miext.extinit_priv;

import common.misc;
import include.os;
import dix.dixstruct_priv;
import dix.swaprep;
import externs.X11.extensions.xcmiscproto;
import dix.extension;

private int ProcXCMiscGetVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXCMiscGetVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!"majorVersion");
    mixin(X_REQUEST_FIELD_CARD16!"minorVersion");

    xXCMiscGetVersionReply reply = {
        majorVersion: XCMiscMajorVersion,
        minorVersion: XCMiscMinorVersion
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXCMiscGetXIDRange(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXCMiscGetXIDRangeReq);

    XID min_id = void, max_id = void;
    GetXIDRange(client.index, FALSE, &min_id, &max_id);

    xXCMiscGetXIDRangeReply reply = {
        start_id: cast(uint)min_id,
        count: cast(uint)(max_id - min_id + 1)
    };

    mixin(X_REPLY_FIELD_CARD32!"start_id");
    mixin(X_REPLY_FIELD_CARD32!"count");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXCMiscGetXIDList(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXCMiscGetXIDListReq);
    mixin(X_REQUEST_FIELD_CARD32!"count");

    if (stuff.count > uint.max / XID.sizeof) {
        return BadAlloc;
    }

    XID* pids = cast(XID*) calloc(stuff.count, XID.sizeof);
    if (!pids) {
        return BadAlloc;
    }

    size_t count = GetXIDList(client, cast(uint)stuff.count, pids);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)pids, count);
    free(pids);

    xXCMiscGetXIDListReply reply = {
        count: cast(uint)count
    };

    mixin(X_REPLY_FIELD_CARD32!"count");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXCMiscDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_XCMiscGetVersion:
        return ProcXCMiscGetVersion(client);
    case X_XCMiscGetXIDRange:
        return ProcXCMiscGetXIDRange(client);
    case X_XCMiscGetXIDList:
        return ProcXCMiscGetXIDList(client);
    default:
        return BadRequest;
    }
}

void XCMiscExtensionInit()
{
    AddExtension(XCMiscExtensionName, 0, 0,
                 &ProcXCMiscDispatch, &ProcXCMiscDispatch,
                 null, &StandardMinorOpcode);
}
