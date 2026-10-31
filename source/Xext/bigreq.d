module Xext.bigreq;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1992, 1998  The Open Group

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

//import x11.X;
//import x11.Xproto;
import externs.X11.extensions.bigreqsproto;

import dix.dix_priv;
import dix.request_priv;
import include.extnsionst;
import miext.extinit_priv;
import dix.extension;

private int ProcBigReqDispatch(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!(xBigReqEnableReq));

    if (stuff.brReqType != X_BigReqEnable) {
        return BadRequest;
    }

    client.big_requests = TRUE;

    xBigReqEnableReply reply = {
        max_request_size: cast(uint)maxBigRequestSize
    };

    mixin(X_REPLY_FIELD_CARD32!("max_request_size"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

void BigReqExtensionInit()
{
    AddExtension(XBigReqExtensionName, 0, 0,
                 &ProcBigReqDispatch, &ProcBigReqDispatch,
                 null, &StandardMinorOpcode);
}
