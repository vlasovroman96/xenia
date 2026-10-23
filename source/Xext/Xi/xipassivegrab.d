module Xi.xipassivegrab;
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

import externs.X11.extensions.XI2;
import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.exevents_priv;
import dix.inpututils_priv;
import dix.rpcbuf_priv;
import dix.request_priv;
import Xi.handlers;

import include.inputstr;           /* DeviceIntPtr      */
import include.windowstr;          /* window structure  */
import dix.swaprep;
import Xi.exglobals;          /* BadDevice */
import include.misc;
import dix.dixutils;
import dix.devices;
import dix.events;
import dix.inpututils;


int ProcXIPassiveGrabDevice(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXIPassiveGrabDeviceReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"grab_window");
    mixin(X_REQUEST_FIELD_CARD32!"cursor");
    mixin(X_REQUEST_FIELD_CARD32!"time");
    mixin(X_REQUEST_FIELD_CARD32!"detail");
    mixin(X_REQUEST_FIELD_CARD16!"mask_len");
    mixin(X_REQUEST_FIELD_CARD16!"num_modifiers");
    mixin(REQUEST_FIXED_SIZE!("xXIPassiveGrabDeviceReq",
        "(cast(uint) stuff.mask_len + stuff.num_modifiers) *4"));
    mixin(X_REQUEST_REST_CARD32!()); /* event mask and modifiers list */

    DeviceIntPtr dev = void, mod_dev = void;
    xXIPassiveGrabDeviceReply reply = {
        repType: X_Reply,
        RepType: X_XIPassiveGrabDevice,
        sequenceNumber: cast(ushort)client.sequence,
        length: 0,
        num_modifiers: 0
    };
    int i = void, ret = Success;
    uint* modifiers = void;
    GrabMask mask = { 0 };
    GrabParameters param = void;
    void* tmp = void;
    int mask_len = void;

    if (stuff.deviceid == XIAllDevices)
        dev = inputInfo.all_devices;
    else if (stuff.deviceid == XIAllMasterDevices)
        dev = inputInfo.all_master_devices;
    else {
        ret = dixLookupDevice(&dev, stuff.deviceid, client, DixGrabAccess);
        if (ret != Success) {
            client.errorValue = cast(uint)stuff.deviceid;
            return ret;
        }
    }

    if (stuff.grab_type != XIGrabtypeButton &&
        stuff.grab_type != XIGrabtypeKeycode &&
        stuff.grab_type != XIGrabtypeEnter &&
        stuff.grab_type != XIGrabtypeFocusIn &&
        stuff.grab_type != XIGrabtypeTouchBegin &&
        stuff.grab_type != XIGrabtypeGesturePinchBegin &&
        stuff.grab_type != XIGrabtypeGestureSwipeBegin) {
        client.errorValue = cast(uint)stuff.grab_type;
        return BadValue;
    }

    if ((stuff.grab_type == XIGrabtypeEnter ||
         stuff.grab_type == XIGrabtypeFocusIn ||
         stuff.grab_type == XIGrabtypeTouchBegin ||
         stuff.grab_type == XIGrabtypeGesturePinchBegin ||
         stuff.grab_type == XIGrabtypeGestureSwipeBegin) && stuff.detail != 0) {
        client.errorValue = cast(uint)stuff.detail;
        return BadValue;
    }

    if (stuff.grab_type == XIGrabtypeTouchBegin &&
        (stuff.grab_mode != XIGrabModeTouch ||
         stuff.paired_device_mode != GrabModeAsync)) {
        client.errorValue = cast(uint)stuff.grab_mode;
        return BadValue;
    }

    if (XICheckInvalidMaskBits(client, cast(ubyte*) &stuff[1],
                               stuff.mask_len * 4) != Success)
        return BadValue;

    mask.xi2mask = xi2mask_new();
    if (!mask.xi2mask)
        return BadAlloc;

    mask_len = cast(int)min(xi2mask_mask_size(mask.xi2mask), stuff.mask_len * 4);
    xi2mask_set_one_mask(mask.xi2mask, stuff.deviceid,
                         cast(ubyte*) &stuff[1], mask_len);

    memset(&param, 0, param.sizeof);
    param.grabtype = XI2;
    param.ownerEvents = stuff.owner_events;
    param.grabWindow = stuff.grab_window;
    param.cursor = stuff.cursor;

    if (IsKeyboardDevice(dev)) {
        param.this_device_mode = stuff.grab_mode;
        param.other_devices_mode = stuff.paired_device_mode;
    }
    else {
        param.this_device_mode = stuff.paired_device_mode;
        param.other_devices_mode = stuff.grab_mode;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (stuff.cursor != None) {
        ret = dixLookupResourceByType(&tmp, stuff.cursor,
                                      X11_RESTYPE_CURSOR, client, DixUseAccess);
        if (ret != Success) {
            client.errorValue = cast(uint)stuff.cursor;
            goto out_;
        }
    }

    ret =
        dixLookupWindow(cast(WindowPtr*) &tmp, stuff.grab_window, client,
                        DixSetAttrAccess);
    if (ret != Success)
        goto out_;

    ret = CheckGrabValues(client, &param);
    if (ret != Success)
        goto out_;

    modifiers = cast(uint*) &stuff[1] + stuff.mask_len;
    mod_dev = (InputDevIsFloating(dev)) ? dev : GetMaster(dev, MASTER_KEYBOARD);

    for (i = 0; i < stuff.num_modifiers; i++, modifiers++) {
        ubyte status = Success;

        /* XI2 allows 32-bit keycodes but thanks to XKB we can never
         * implement this. Pretend that all keycodes above 255 are
         * already grabbed, same for buttons > 255. */
        if (stuff.detail > 255) {
            status = XIAlreadyGrabbed;
            goto modifier_done;
        }

        param.modifiers = *modifiers;
        ret = CheckGrabValues(client, &param);
        if (ret != Success)
            goto out_;

        switch (stuff.grab_type) {
        case XIGrabtypeButton:
            status = cast(ubyte)GrabButton(client, dev, mod_dev, stuff.detail,
                                &param, XI2, &mask);
            break;
        case XIGrabtypeKeycode:
            status = cast(ubyte)GrabKey(client, dev, mod_dev, stuff.detail,
                             &param, XI2, &mask);
            break;
        case XIGrabtypeEnter:
        case XIGrabtypeFocusIn:
            status = cast(ubyte)GrabWindow(client, dev, stuff.grab_type, &param, &mask);
            break;
        case XIGrabtypeTouchBegin:
            status = cast(ubyte)GrabTouchOrGesture(client, dev, mod_dev, XI_TouchBegin,
                                        &param, &mask);
            break;
        case XIGrabtypeGesturePinchBegin:
            status = cast(ubyte)GrabTouchOrGesture(client, dev, mod_dev,
                                        XI_GesturePinchBegin, &param, &mask);
            break;
        case XIGrabtypeGestureSwipeBegin:
            status = cast(ubyte)GrabTouchOrGesture(client, dev, mod_dev,
                                        XI_GestureSwipeBegin, &param, &mask);
            break;
        default: break;}

modifier_done:
        if (status != cast(ubyte)GrabSuccess) {
            /* write xXIGrabModifierInfo */
            x_rpcbuf_write_CARD32(&rpcbuf, *modifiers);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)status);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)0); /* pad0 */
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad1 */

            reply.num_modifiers++;
        }
    }

    xi2mask_free(&mask.xi2mask);

    mixin(X_REPLY_FIELD_CARD16!"num_modifiers");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

 out_:
    xi2mask_free(&mask.xi2mask);
    x_rpcbuf_clear(&rpcbuf);
    return ret;
}

int ProcXIPassiveUngrabDevice(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXIPassiveUngrabDeviceReq);
    mixin(X_REQUEST_FIELD_CARD32!"grab_window");
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"detail");
    mixin(X_REQUEST_FIELD_CARD16!"num_modifiers");
    mixin(REQUEST_FIXED_SIZE!("xXIPassiveUngrabDeviceReq",
                       "(cast(uint) stuff.num_modifiers) << 2"));
    mixin(X_REQUEST_REST_CARD32!()); /* modifiers list */

    DeviceIntPtr dev = void, mod_dev = void;
    WindowPtr win = void;
    GrabPtr tempGrab = void;
    uint* modifiers = void;
    int i = void, rc = void;

    if (stuff.deviceid == XIAllDevices)
        dev = inputInfo.all_devices;
    else if (stuff.deviceid == XIAllMasterDevices)
        dev = inputInfo.all_master_devices;
    else {
        rc = dixLookupDevice(&dev, stuff.deviceid, client, DixGrabAccess);
        if (rc != Success)
            return rc;
    }

    if (stuff.grab_type != XIGrabtypeButton &&
        stuff.grab_type != XIGrabtypeKeycode &&
        stuff.grab_type != XIGrabtypeEnter &&
        stuff.grab_type != XIGrabtypeFocusIn &&
        stuff.grab_type != XIGrabtypeTouchBegin &&
        stuff.grab_type != XIGrabtypeGesturePinchBegin &&
        stuff.grab_type != XIGrabtypeGestureSwipeBegin) {
        client.errorValue = cast(uint)stuff.grab_type;
        return BadValue;
    }

    if ((stuff.grab_type == XIGrabtypeEnter ||
         stuff.grab_type == XIGrabtypeFocusIn ||
         stuff.grab_type == XIGrabtypeTouchBegin) && stuff.detail != 0) {
        client.errorValue = cast(uint)stuff.detail;
        return BadValue;
    }

    /* We don't allow passive grabs for details > 255 anyway */
    if (stuff.detail > 255) {
        client.errorValue = cast(uint)stuff.detail;
        return BadValue;
    }

    rc = dixLookupWindow(&win, stuff.grab_window, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;

    mod_dev = (InputDevIsFloating(dev)) ? dev : GetMaster(dev, MASTER_KEYBOARD);

    tempGrab = AllocGrab(null);
    if (!tempGrab)
        return BadAlloc;

    tempGrab.resource = client.clientAsMask;
    tempGrab.device = dev;
    tempGrab.window = win;
    switch (stuff.grab_type) {
    case XIGrabtypeButton:
        tempGrab.type = XI_ButtonPress;
        break;
    case XIGrabtypeKeycode:
        tempGrab.type = XI_KeyPress;
        break;
    case XIGrabtypeEnter:
        tempGrab.type = XI_Enter;
        break;
    case XIGrabtypeFocusIn:
        tempGrab.type = XI_FocusIn;
        break;
    case XIGrabtypeTouchBegin:
        tempGrab.type = XI_TouchBegin;
        break;
    case XIGrabtypeGesturePinchBegin:
        tempGrab.type = XI_GesturePinchBegin;
        break;
    case XIGrabtypeGestureSwipeBegin:
        tempGrab.type = XI_GestureSwipeBegin;
        break;
    default: break;}
    tempGrab.grabtype = XI2;
    tempGrab.modifierDevice = mod_dev;
    tempGrab.modifiersDetail.pMask = null;
    tempGrab.detail.exact = stuff.detail;
    tempGrab.detail.pMask = null;

    modifiers = cast(uint*) &stuff[1];

    for (i = 0; i < stuff.num_modifiers; i++, modifiers++) {
        tempGrab.modifiersDetail.exact = *modifiers;
        DeletePassiveGrabFromList(tempGrab);
    }

    FreeGrab(tempGrab);

    return Success;
}
