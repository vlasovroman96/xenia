module Xi.xiselectev;
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

import build.dix_config;

import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.inpututils_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.window_priv;
import Xi.handlers;

import dix.dixstruct_priv;
import dix.window;
import dix.devices;
import dix.dixutils;
import dix.events;
import dix.inpututils;
import common.bytes;

/**
 * Ruleset:
 * - if A has XIAllDevices, B may select on device X
 * - If A has XIAllDevices, B may select on XIAllMasterDevices
 * - If A has XIAllMasterDevices, B may select on device X
 * - If A has XIAllMasterDevices, B may select on XIAllDevices
 * - if A has device X, B may select on XIAllDevices/XIAllMasterDevices
 */
private int check_for_touch_selection_conflicts(ClientPtr B, WindowPtr win, int deviceid, int evtype)
{
    OtherInputMasks* inputMasks = mixin(wOtherInputMasks!("win"));
    InputClients* A = null;

    if (inputMasks)
        A = inputMasks.inputClients;
    for (; A; A = A.next) {
        DeviceIntPtr tmp = void;

        if (dixClientIdForXID(A.resource) == B.index)
            continue;

        if (deviceid == XIAllDevices)
            tmp = inputInfo.all_devices;
        else if (deviceid == XIAllMasterDevices)
            tmp = inputInfo.all_master_devices;
        else
            dixLookupDevice(&tmp, deviceid, serverClient, DixReadAccess);
        if (!tmp)
            return BadImplementation;       /* this shouldn't happen */

        /* A has XIAllDevices */
        if (xi2mask_isset_for_device(A.xi2mask, inputInfo.all_devices, evtype)) {
            if (deviceid == XIAllDevices)
                return BadAccess;
        }

        /* A has XIAllMasterDevices */
        if (xi2mask_isset_for_device(A.xi2mask, inputInfo.all_master_devices, evtype)) {
            if (deviceid == XIAllMasterDevices)
                return BadAccess;
        }

        /* A has this device */
        if (xi2mask_isset_for_device(A.xi2mask, tmp, evtype))
            return BadAccess;
    }

    return Success;
}


/**
 * Check the given mask (in len bytes) for invalid mask bits.
 * Invalid mask bits are any bits above XI2LastEvent.
 *
 * @return BadValue if at least one invalid bit is set or Success otherwise.
 */
int XICheckInvalidMaskBits(ClientPtr client, ubyte* mask, int len)
{
    if (len >= mixin(XIMaskLen!("XI2LASTEVENT"))) {
        int i = void;

        for (i = XI2LASTEVENT + 1; i < len * 8; i++) {
            if (mixin(BitIsOn!("mask", "i"))) {
                client.errorValue = cast(uint)i;
                return BadValue;
            }
        }
    }

    return Success;
}

int ProcXISelectEvents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXISelectEventsReq);
    mixin(X_REQUEST_FIELD_CARD32!"win");
    mixin(X_REQUEST_FIELD_CARD16!"num_masks");

    if (client.swapped) {
        int len = cast(int)(client.req_len - int32ForBytes(xXISelectEventsReq.sizeof));
        xXIEventMask* evmask = cast(xXIEventMask*) &stuff[1];
        for (int i = 0; i < stuff.num_masks; i++) {
            if (len < int32ForBytes(xXIEventMask.sizeof))
                return BadLength;
            len -= int32ForBytes(xXIEventMask.sizeof);
            swaps(&evmask.deviceid);
            swaps(&evmask.mask_len);
            if (len < evmask.mask_len)
                return BadLength;
            len -= evmask.mask_len;
            evmask =
                cast(xXIEventMask*) ((cast(char*) &evmask[1]) + evmask.mask_len * 4);
        }
    }

    if (stuff.num_masks == 0)
        return BadValue;

    WindowPtr win = void;
    int rc = dixLookupWindow(&win, stuff.win, client, DixReceiveAccess);

    // when access to the window is denied, just pretend everything's okay
    if (rc == BadAccess)
        return Success;

    if (rc != Success)
        return rc;

    int len = sz_xXISelectEventsReq;

    /* check request validity */
    xXIEventMask* evmask = cast(xXIEventMask*) &stuff[1];
    int num_masks = stuff.num_masks;
    while (num_masks--) {
        len += (xXIEventMask).sizeof + evmask.mask_len * 4;

        if (int32ForBytes(len) > client.req_len)
            return BadLength;

        DeviceIntPtr dev = void;

        if (evmask.deviceid != XIAllDevices &&
            evmask.deviceid != XIAllMasterDevices)
            rc = dixLookupDevice(&dev, evmask.deviceid, client, DixUseAccess);
        else {
            /* XXX: XACE here? */
        }
        if (rc != Success)
            return rc;

        /* hierarchy event mask is not allowed on devices */
        if (evmask.deviceid != XIAllDevices && evmask.mask_len >= 1) {
            ubyte* bits = cast(ubyte*) &evmask[1];

            if (mixin(BitIsOn!("bits", "XI_HierarchyChanged"))) {
                client.errorValue = cast(uint)XI_HierarchyChanged;
                return BadValue;
            }
        }

        /* Raw events may only be selected on root windows */
        if (win.parent && evmask.mask_len >= 1) {
            ubyte* bits = cast(ubyte*) &evmask[1];

            if (mixin(BitIsOn!("bits", "XI_RawKeyPress")) ||
                mixin(BitIsOn!("bits", "XI_RawKeyRelease")) ||
                mixin(BitIsOn!("bits", "XI_RawButtonPress")) ||
                mixin(BitIsOn!("bits", "XI_RawButtonRelease")) ||
                mixin(BitIsOn!("bits", "XI_RawMotion")) ||
                mixin(BitIsOn!("bits", "XI_RawTouchBegin")) ||
                mixin(BitIsOn!("bits", "XI_RawTouchUpdate")) ||
                mixin(BitIsOn!("bits", "XI_RawTouchEnd"))) {
                client.errorValue = cast(uint)XI_RawKeyPress;
                return BadValue;
            }
        }

        if (evmask.mask_len >= 1) {
            ubyte* bits = cast(ubyte*) &evmask[1];

            /* All three touch events must be selected at once */
            if ((mixin(BitIsOn!("bits", "XI_TouchBegin")) ||
                 mixin(BitIsOn!("bits", "XI_TouchUpdate")) ||
                 mixin(BitIsOn!("bits", "XI_TouchOwnership")) ||
                 mixin(BitIsOn!("bits", "XI_TouchEnd"))) &&
                (!mixin(BitIsOn!("bits", "XI_TouchBegin")) ||
                 !mixin(BitIsOn!("bits", "XI_TouchUpdate")) ||
                 !mixin(BitIsOn!("bits", "XI_TouchEnd")))) {
                client.errorValue = cast(uint)XI_TouchBegin;
                return BadValue;
            }

            /* All three pinch gesture events must be selected at once */
            if ((mixin(BitIsOn!("bits", "XI_GesturePinchBegin")) ||
                 mixin(BitIsOn!("bits", "XI_GesturePinchUpdate")) ||
                 mixin(BitIsOn!("bits", "XI_GesturePinchEnd"))) &&
                (!mixin(BitIsOn!("bits", "XI_GesturePinchBegin")) ||
                 !mixin(BitIsOn!("bits", "XI_GesturePinchUpdate")) ||
                 !mixin(BitIsOn!("bits", "XI_GesturePinchEnd")))) {
                client.errorValue = cast(uint)XI_GesturePinchBegin;
                return BadValue;
            }

            /* All three swipe gesture events must be selected at once. Note
               that the XI_GestureSwipeEnd is at index 32 which is on the next
               4-byte mask element */
            if (evmask.mask_len == 1 &&
                (mixin(BitIsOn!("bits", "XI_GestureSwipeBegin")) ||
                 mixin(BitIsOn!("bits", "XI_GestureSwipeUpdate"))))
            {
                client.errorValue = cast(uint)XI_GestureSwipeBegin;
                return BadValue;
            }

            if (evmask.mask_len >= 2 &&
                (mixin(BitIsOn!("bits", "XI_GestureSwipeBegin")) ||
                 mixin(BitIsOn!("bits", "XI_GestureSwipeUpdate")) ||
                 mixin(BitIsOn!("bits", "XI_GestureSwipeEnd"))) &&
                (!mixin(BitIsOn!("bits", "XI_GestureSwipeBegin")) ||
                 !mixin(BitIsOn!("bits", "XI_GestureSwipeUpdate")) ||
                 !mixin(BitIsOn!("bits", "XI_GestureSwipeEnd")))) {
                client.errorValue = cast(uint)XI_GestureSwipeBegin;
                return BadValue;
            }

            /* Only one client per window may select for touch or gesture events
             * on the same devices, including master devices.
             * XXX: This breaks if a device goes from floating to attached. */
            if (mixin(BitIsOn!("bits", "XI_TouchBegin"))) {
                rc = check_for_touch_selection_conflicts(client,
                                                         win,
                                                         evmask.deviceid,
                                                         XI_TouchBegin);
                if (rc != Success)
                    return rc;
            }
            if (mixin(BitIsOn!("bits", "XI_GesturePinchBegin"))) {
                rc = check_for_touch_selection_conflicts(client,
                                                         win,
                                                         evmask.deviceid,
                                                         XI_GesturePinchBegin);
                if (rc != Success)
                    return rc;
            }
            if (mixin(BitIsOn!("bits", "XI_GestureSwipeBegin"))) {
                rc = check_for_touch_selection_conflicts(client,
                                                         win,
                                                         evmask.deviceid,
                                                         XI_GestureSwipeBegin);
                if (rc != Success)
                    return rc;
            }
        }

        if (XICheckInvalidMaskBits(client, cast(ubyte*) &evmask[1],
                                   evmask.mask_len * 4) != Success)
            return BadValue;

        evmask =
            cast(xXIEventMask*) ((cast(ubyte*) evmask) +
                              evmask.mask_len * 4);
        evmask++;
    }

    if (int32ForBytes(len) != client.req_len)
        return BadLength;

    /* Set masks on window */
    evmask = cast(xXIEventMask*) &stuff[1];
    num_masks = stuff.num_masks;
    while (num_masks--) {
        DeviceIntPtr dev = void;
        DeviceIntRec dummy;
        if (evmask.deviceid == XIAllDevices ||
            evmask.deviceid == XIAllMasterDevices) {
            dummy.id = evmask.deviceid;
            dev = &dummy;
        }
        else
            dixLookupDevice(&dev, evmask.deviceid, client, DixUseAccess);
        if (XISetEventMask(dev, win, client, evmask.mask_len * 4,
                           cast(ubyte*) &evmask[1]) != Success)
            return BadAlloc;
        evmask =
            cast(xXIEventMask*) ((cast(ubyte*) evmask) +
                              evmask.mask_len * 4);
        evmask++;
    }

    RecalculateDeliverableEvents(win);
    return Success;
}

int ProcXIGetSelectedEvents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIGetSelectedEventsReq);
    mixin(X_REQUEST_FIELD_CARD32!"win");

    int rc = void, i = void;
    WindowPtr win = void;
    OtherInputMasks* masks = void;
    InputClientsPtr others = null;
    DeviceIntPtr dev = void;

    rc = dixLookupWindow(&win, stuff.win, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xXIGetSelectedEventsReply reply = {
        RepType: X_XIGetSelectedEvents,
    };

    masks = mixin(wOtherInputMasks!("win"));
    if (masks) {
        for (others = mixin(wOtherInputMasks!("win")).inputClients; others;
             others = others.next) {
            if (mixin(SameClient!("others", "client"))) {
                break;
            }
        }
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (!others)
        goto finish;

    for (i = 0; i < MAXDEVICES; i++) {
        int j = void;
        const(ubyte)* devmask = xi2mask_get_one_mask(others.xi2mask, i);

        if (i > 2) {
            rc = dixLookupDevice(&dev, i, client, DixGetAttrAccess);
            if (rc != Success)
                continue;
        }

        for (j = cast(int)(xi2mask_mask_size(others.xi2mask) - 1); j >= 0; j--) {
            /* scan backwards to skip trailing zeros. mask is always written in 32bit granularity */
            if (devmask[j] != 0) {

                int mask_len = (j + 4) / 4;     /* j is an index, hence + 4, not + 3 */

                /* write xXIEventMask */
                x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)i);
                x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)mask_len);

                /* write mask -- be prepared for original mask not 32bit aligned */
                x_rpcbuf_write_CARD8s(&rpcbuf, devmask, j+1);
                CARD8[8] zero = 0;
                x_rpcbuf_write_CARD8s(&rpcbuf, zero.ptr, (mask_len*4) - (j+1));

                reply.num_masks++;

                /* found out the mask size and written it, so break out here */
                break;
            }
        }
    }

finish: {}

    mixin(X_REPLY_FIELD_CARD16!"num_masks");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
