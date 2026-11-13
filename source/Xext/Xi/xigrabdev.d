module Xi.xigrabdev;
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
 * Request to grab or ungrab input device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI2;
// //import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.inpututils_priv;
import dix.request_priv;
import dix.resource_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import Xi.exglobals;          /* BadDevice */
import externs.X11.extensions.XI2proto;
import dix.devices;
import dix.dixutils;
import dix.events;
import dix.inpututils;
import dix.timestamp;
import common.math;
import common.swap;


int ProcXIGrabDevice(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXIGrabDeviceReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"grab_window");
    mixin(X_REQUEST_FIELD_CARD32!"cursor");
    mixin(X_REQUEST_FIELD_CARD32!"time");
    mixin(X_REQUEST_FIELD_CARD16!"mask_len");

    DeviceIntPtr dev = void;
    int ret = Success;
    ubyte status = void;
    GrabMask mask = { 0 };
    int mask_len = void;
    uint keyboard_mode = void;
    uint pointer_mode = void;

    mixin(REQUEST_FIXED_SIZE!("xXIGrabDeviceReq", "(cast(size_t) stuff.mask_len) * 4"));

    ret = dixLookupDevice(&dev, stuff.deviceid, client, DixGrabAccess);
    if (ret != Success)
        return ret;

    if (!dev.enabled) {
        status = XIAlreadyGrabbed;
        goto reply;
    }

    if (!InputDevIsMaster(dev))
        stuff.paired_device_mode = GrabModeAsync;

    if (IsKeyboardDevice(dev)) {
        keyboard_mode = stuff.grab_mode;
        pointer_mode = stuff.paired_device_mode;
    }
    else {
        keyboard_mode = stuff.paired_device_mode;
        pointer_mode = stuff.grab_mode;
    }

    if (XICheckInvalidMaskBits(client, cast(ubyte*) &stuff[1],
                               stuff.mask_len * 4) != Success)
        return BadValue;

    mask.xi2mask = xi2mask_new();
    if (!mask.xi2mask)
        return BadAlloc;

    mask_len = cast(int)min(xi2mask_mask_size(mask.xi2mask), stuff.mask_len * 4);
    /* FIXME: I think the old code was broken here */
    xi2mask_set_one_mask(mask.xi2mask, dev.id, cast(ubyte*) &stuff[1],
                         mask_len);

    ret = GrabDevice(client, dev, pointer_mode,
                     keyboard_mode,
                     stuff.grab_window,
                     stuff.owner_events,
                     stuff.time,
                     &mask, XI2, stuff.cursor, None /* confineTo */ ,
                     &status);

    xi2mask_free(&mask.xi2mask);

    if (ret != Success)
        return ret;

reply:
    {}
    xXIGrabDeviceReply reply = {
        RepType: X_XIGrabDevice,
        status: status
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXIUngrabDevice(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIUngrabDeviceReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"time");

    DeviceIntPtr dev = void;
    GrabPtr grab = void;
    int ret = Success;
    TimeStamp time = void;

    ret = dixLookupDevice(&dev, stuff.deviceid, client, DixGetAttrAccess);
    if (ret != Success)
        return ret;

    grab = dev.deviceGrab.grab;

    time = ClientTimeToServerTime(stuff.time);
    if ((CompareTimeStamps(time, currentTime) != LATER) &&
        (CompareTimeStamps(time, dev.deviceGrab.grabTime) != EARLIER) &&
        (grab) && mixin(SameClient!("grab", "client")) && grab.grabtype == XI2)
        (*dev.deviceGrab.DeactivateGrab) (dev);

    return Success;
}
