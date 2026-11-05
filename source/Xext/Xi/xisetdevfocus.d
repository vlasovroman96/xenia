module Xi.xisetdevfocus;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2008 Red Hat, Inc.
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
 * Author: Peter Hutterer
 */
/***********************************************************************
 *
 * Request to set and get an input device's focus.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI2;
import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.request_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import include.windowstr;          /* window structure  */
import Xi.exglobals;          /* BadDevice */
import dix.devices;
import dix.dixutils;

int ProcXISetFocus(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXISetFocusReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"focus");
    mixin(X_REQUEST_FIELD_CARD32!"time");

    DeviceIntPtr dev = void;
    int ret = void;

    ret = dixLookupDevice(&dev, stuff.deviceid, client, DixSetFocusAccess);
    if (ret != Success)
        return ret;
    if (!dev.focus)
        return BadDevice;

    return SetInputFocus(client, dev, stuff.focus, x11.X.RevertToParent,
                         stuff.time, TRUE);
}

int ProcXIGetFocus(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXIGetFocusReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");

    DeviceIntPtr dev = void;
    int ret = void;

    ret = dixLookupDevice(&dev, stuff.deviceid, client, DixGetFocusAccess);
    if (ret != Success)
        return ret;
    if (!dev.focus)
        return BadDevice;

    xXIGetFocusReply reply = {
        RepType: X_XIGetFocus,
    };

    if (dev.focus.win == NoneWin)
        reply.focus = None;
    else if (dev.focus.win == PointerRootWin)
        reply.focus = PointerRoot;
    else if (dev.focus.win == FollowKeyboardWin)
        reply.focus = FollowKeyboard;
    else
        reply.focus = cast(uint)dev.focus.win.drawable.id;

    mixin(X_REPLY_FIELD_CARD32!"focus");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}
