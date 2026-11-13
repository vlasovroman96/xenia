module Xi.xiallowev;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2009 Red Hat, Inc.
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
 * Request to allow some device events.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI2;
// //import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.request_priv;
import os.fmt;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import dix.events;
import Xi.exglobals;          /* BadDevice */
import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI2proto;

import externs.X11.extensions.XI;
import dix.devices;
import dix.dixutils;
import dix.events;
import dix.timestamp;
import common.swap;

int ProcXIAllowEvents(ClientPtr client)
{
    Bool have_xi22 = FALSE;
    CARD32 clientTime = void;
    int deviceId = void;
    int mode = void;
    Window grabWindow = 0;
    uint touchId = 0;

    XIClientPtr xi_client = XIClientPriv(client);
    if (!xi_client)
        return BadImplementation;

    if (version_compare(xi_client.major_version,
                        xi_client.minor_version, 2, 2) >= 0) {
        // Xi >= v2.2 request
        mixin(X_REQUEST_HEAD_AT_LEAST!xXI2_2AllowEventsReq);
        mixin(X_REQUEST_FIELD_CARD16!"deviceid");
        mixin(X_REQUEST_FIELD_CARD32!"time");
        mixin(X_REQUEST_FIELD_CARD32!"touchid");
        mixin(X_REQUEST_FIELD_CARD32!"grab_window");

        have_xi22 = TRUE;
        clientTime = stuff.time;
        deviceId = stuff.deviceid;
        mode = stuff.mode;
        grabWindow = stuff.grab_window;
        touchId = stuff.touchid;
    }
    else {
        // Xi < v2.2 request
        mixin(X_REQUEST_HEAD_AT_LEAST!xXIAllowEventsReq);
        mixin(X_REQUEST_FIELD_CARD16!"deviceid");
        mixin(X_REQUEST_FIELD_CARD32!"time");

        clientTime = stuff.time;
        deviceId = stuff.deviceid;
        mode = stuff.mode;
    }

    DeviceIntPtr dev = void;
    int ret = dixLookupDevice(&dev, deviceId, client, DixGetAttrAccess);
    if (ret != Success)
        return ret;

    TimeStamp time = ClientTimeToServerTime(clientTime);

    switch (mode) {
    case XIReplayDevice:
        AllowSome(client, time, dev, GRAB_STATE_NOT_GRABBED);
        break;
    case XISyncDevice:
        AllowSome(client, time, dev, GRAB_STATE_FREEZE_NEXT_EVENT);
        break;
    case XIAsyncDevice:
        AllowSome(client, time, dev, GRAB_STATE_THAWED);
        break;
    case XIAsyncPairedDevice:
        if (InputDevIsMaster(dev))
            AllowSome(client, time, dev, GRAB_STATE_THAW_OTHERS);
        break;
    case XISyncPair:
        if (InputDevIsMaster(dev))
            AllowSome(client, time, dev, GRAB_STATE_FREEZE_BOTH_NEXT_EVENT);
        break;
    case XIAsyncPair:
        if (InputDevIsMaster(dev))
            AllowSome(client, time, dev, GRAB_STATE_THAWED_BOTH);
        break;
    case XIRejectTouch:
    case XIAcceptTouch:
    {
        int rc = void;
        WindowPtr win = void;

        if (!have_xi22)
            return BadValue;

        rc = dixLookupWindow(&win, grabWindow, client, DixReadAccess);
        if (rc != Success)
            return rc;

        ret = TouchAcceptReject(client, dev, mode, touchId,
                                grabWindow, &client.errorValue);
    }
        break;
    default:
        client.errorValue = cast(uint)mode;
        ret = BadValue;
    }

    return ret;
}
