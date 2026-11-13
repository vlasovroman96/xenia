module Xi.xigetclientpointer;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2007-2008 Peter Hutterer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Author: Peter Hutterer, University of South Australia, NICTA
 */

import build.dix_config;

//import x11.X;              /* for inputstr.h    */
//import x11.Xproto;         /* Request macro     */
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.request_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import dix.scrnintstr;         /* screen structure  */
import dix.extension;
import Xi.exevents;
import Xi.exglobals;
import dix.devices;
import dix.dixutils;
import externs.X11.extensions.XI2proto;
import common.swap;

/***********************************************************************
 * This procedure allows a client to query another client's client pointer
 * setting.
 */

int ProcXIGetClientPointer(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIGetClientPointerReq);
    mixin(X_REQUEST_FIELD_CARD32!"win");

    int rc = void;
    ClientPtr winclient = void;

    if (stuff.win != None) {
        rc = dixLookupResourceOwner(&winclient, stuff.win, client, DixGetAttrAccess);

        if (rc != Success)
            return BadWindow;
    }
    else
        winclient = client;

    xXIGetClientPointerReply reply = {
        RepType: X_XIGetClientPointer,
        set: (winclient.clientPtr !is null),
        deviceid: (winclient.clientPtr) ? cast(ushort)winclient.clientPtr.id : 0
    };

    mixin(X_REPLY_FIELD_CARD16!"deviceid");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}
