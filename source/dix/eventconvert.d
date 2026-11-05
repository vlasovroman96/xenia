module dix.eventconvert;
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
 */

/**
 * @file eventconvert.c
 * This file contains event conversion routines from InternalEvent to the
 * matching protocol events.
 */

import build.dix_config;

import core.stdc.stdint;
//import x11.X;
// //import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI2proto;
//import externs.X11.extensions.XI;
//import externs.X11.extensions.XI2;

import dix.dix_priv;
import dix.eventconvert;
import dix.exevents_priv;
import dix.extension_priv;
import dix.inpututils_priv;

import dix.inputstr;
import common.misc;
import dix.events;
import Xi.exglobals;
import Xi.xiquerydevice;
import xkb.xkbsrv_priv;
import os.log;
import dix.devices;
import dix.inpututils;
import xkb.xkbstr;











/* Do not use, read comments below */


/**
 * Hack to allow detectable autorepeat for core and XI1 events.
 * The sequence number is unused until we send to the client and can be
 * misused to store data. More or less, anyway.
 *
 * Do not use this. It may change any time without warning, eat your babies
 * and piss on your cat.
 */
private void EventSetKeyRepeatFlag(xEvent* event, BOOL on)
{
    event.u.u.sequenceNumber = on;
}

/**
 * Check if the event was marked as a repeat event before.
 * NOTE: This is a nasty hack and should NOT be used by anyone else but
 * TryClientEvents.
 */
BOOL EventIsKeyRepeat(xEvent* event)
{
    return ! !event.u.u.sequenceNumber;
}

/**
 * Convert the given event to the respective core event.
 *
 * Return values:
 * Success ... core contains the matching core event.
 * BadValue .. One or more values in the internal event are invalid.
 * BadMatch .. The event has no core equivalent.
 *
 * @param[in] event The event to convert into a core event.
 * @param[in] core The memory location to store the core event at.
 * @return Success or the matching error code.
 */
int EventToCore(InternalEvent* event, xEvent** core_out, int* count_out)
{
    xEvent* core = null;
    int count = 0;
    int ret = BadImplementation;

    switch (event.any.type) {
    case ET_Motion:
    {
        DeviceEvent* e = &event.device_event;

        /* Don't create core motion event if neither x nor y are
         * present */
        if (!mixin(BitIsOn!("e.valuators.mask", "0")) && !mixin(BitIsOn!("e.valuators.mask", "1"))) {
            ret = BadMatch;
            goto out_;
        }
    }
    goto case ET_ButtonPress;
        /* fallthrough */
    case ET_ButtonPress,
        ET_ButtonRelease, 
        ET_KeyPress, 
        ET_KeyRelease:
    {
        DeviceEvent* e = &event.device_event;

        if (e.detail.key > 0xFF) {
            ret = BadMatch;
            goto out_;
        }

        core = cast(xEvent*) calloc(1, typeof(*core).sizeof);
        if (!core)
            return BadAlloc;
        count = 1;
        core.u.u.type = cast(ubyte)(e.type - ET_KeyPress + KeyPress);
        core.u.u.detail = e.detail.key & 0xFF;
        core.u.keyButtonPointer.time = e.time;
        core.u.keyButtonPointer.rootX = e.root_x;
        core.u.keyButtonPointer.rootY = e.root_y;
        core.u.keyButtonPointer.state = cast(ushort)e.corestate;
        core.u.keyButtonPointer.root = cast(uint)e.root;
        EventSetKeyRepeatFlag(core, (e.type == ET_KeyPress && e.key_repeat));
        ret = Success;
    }
        break;
    case ET_ProximityIn,
        ET_ProximityOut,
        ET_RawKeyPress,
        ET_RawKeyRelease,
        ET_RawButtonPress,
        ET_RawButtonRelease,
        ET_RawMotion,
        ET_RawTouchBegin,
        ET_RawTouchUpdate,
        ET_RawTouchEnd,
        ET_TouchBegin,
        ET_TouchUpdate,
        ET_TouchEnd,
        ET_TouchOwnership,
        ET_BarrierHit,
        ET_BarrierLeave,
        ET_GesturePinchBegin,
        ET_GesturePinchUpdate,
        ET_GesturePinchEnd,
        ET_GestureSwipeBegin,
        ET_GestureSwipeUpdate,
        ET_GestureSwipeEnd:
        ret = BadMatch;
        break;
    default:
        /* XXX: */
        ErrorF("[dix] EventToCore: Not implemented yet \n");
        ret = BadImplementation;
    }

 out_:
    *core_out = core;
    *count_out = count;
    return ret;
}

/**
 * Convert the given event to the respective XI 1.x event and store it in
 * xi. xi is allocated on demand and must be freed by the caller.
 * count returns the number of events in xi. If count is 1, and the type of
 * xi is GenericEvent, then xi may be larger than 32 bytes.
 *
 * Return values:
 * Success ... core contains the matching core event.
 * BadValue .. One or more values in the internal event are invalid.
 * BadMatch .. The event has no XI equivalent.
 *
 * @param[in] ev The event to convert into an XI 1 event.
 * @param[out] xi Future memory location for the XI event.
 * @param[out] count Number of elements in xi.
 *
 * @return Success or the error code.
 */
int EventToXI(InternalEvent* ev, xEvent** xi, int* count)
{
    switch (ev.any.type) {
    case ET_Motion:
    case ET_ButtonPress:
    case ET_ButtonRelease:
    case ET_KeyPress:
    case ET_KeyRelease:
    case ET_ProximityIn:
    case ET_ProximityOut:
        return eventToKeyButtonPointer(&ev.device_event, xi, count);
    case ET_DeviceChanged:
    case ET_RawKeyPress:
    case ET_RawKeyRelease:
    case ET_RawButtonPress:
    case ET_RawButtonRelease:
    case ET_RawMotion:
    case ET_RawTouchBegin:
    case ET_RawTouchUpdate:
    case ET_RawTouchEnd:
    case ET_TouchBegin:
    case ET_TouchUpdate:
    case ET_TouchEnd:
    case ET_TouchOwnership:
    case ET_BarrierHit:
    case ET_BarrierLeave:
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        *count = 0;
        *xi = null;
        return BadMatch;
    default:
        break;
    }

    ErrorF("[dix] EventToXI: Not implemented for %d \n", ev.any.type);
    return BadImplementation;
}

/**
 * Convert the given event to the respective XI 2.x event and store it in xi.
 * xi is allocated on demand and must be freed by the caller.
 *
 * Return values:
 * Success ... core contains the matching core event.
 * BadValue .. One or more values in the internal event are invalid.
 * BadMatch .. The event has no XI2 equivalent.
 *
 * @param[in] ev The event to convert into an XI2 event
 * @param[out] xi Future memory location for the XI2 event.
 *
 * @return Success or the error code.
 */
int EventToXI2(InternalEvent* ev, xEvent** xi)
{
    switch (ev.any.type) {
        /* Enter/FocusIn are for grabs. We don't need an actual event, since
         * the real events delivered are triggered elsewhere */
    case ET_Enter:
    case ET_FocusIn:
        *xi = null;
        return Success;
    case ET_Motion:
    case ET_ButtonPress:
    case ET_ButtonRelease:
    case ET_KeyPress:
    case ET_KeyRelease:
    case ET_TouchBegin:
    case ET_TouchUpdate:
    case ET_TouchEnd:
        return eventToDeviceEvent(&ev.device_event, xi);
    case ET_TouchOwnership:
        return eventToTouchOwnershipEvent(&ev.touch_ownership_event, xi);
    case ET_ProximityIn:
    case ET_ProximityOut:
        *xi = null;
        return BadMatch;
    case ET_DeviceChanged:
        return eventToDeviceChanged(&ev.changed_event, xi);
    case ET_RawKeyPress:
    case ET_RawKeyRelease:
    case ET_RawButtonPress:
    case ET_RawButtonRelease:
    case ET_RawMotion:
    case ET_RawTouchBegin:
    case ET_RawTouchUpdate:
    case ET_RawTouchEnd:
        return eventToRawEvent(&ev.raw_event, xi);
    case ET_BarrierHit:
    case ET_BarrierLeave:
        return eventToBarrierEvent(&ev.barrier_event, xi);
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
        return eventToGesturePinchEvent(&ev.gesture_event, xi);
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        return eventToGestureSwipeEvent(&ev.gesture_event, xi);
    default:
        break;
    }

    ErrorF("[dix] EventToXI2: Not implemented for %d \n", ev.any.type);
    return BadImplementation;
}

private int eventToKeyButtonPointer(DeviceEvent* ev, xEvent** xi, int* count)
{
    int num_events = void;
    int first = void;                  /* dummy */
    deviceKeyButtonPointer* kbp = void;

    /* Sorry, XI 1.x protocol restrictions. */
    if (ev.detail.button > 0xFF || ev.deviceid >= 0x80) {
        *count = 0;
        return Success;
    }

    num_events = (countValuators(ev, &first) + 5) / 6;  /* valuator ev */
    if (num_events <= 0) {
        switch (ev.type) {
        case ET_KeyPress:
        case ET_KeyRelease:
        case ET_ButtonPress:
        case ET_ButtonRelease:
            /* no axes is ok */
            break;
        case ET_Motion:
        case ET_ProximityIn:
        case ET_ProximityOut:
            *count = 0;
            return BadMatch;
        default:
            *count = 0;
            return BadImplementation;
        }
    }

    num_events++;               /* the actual event event */

    *xi = cast(_xEvent*)calloc(num_events, xEvent.sizeof);
    if (!(*xi)) {
        return BadAlloc;
    }

    kbp = cast(deviceKeyButtonPointer*) (*xi);
    kbp.detail = cast(ubyte)ev.detail.button;
    kbp.time = cast(uint)ev.time;
    kbp.root = cast(uint)ev.root;
    kbp.root_x = ev.root_x;
    kbp.root_y = ev.root_y;
    kbp.deviceid = cast(ubyte)ev.deviceid;
    kbp.state = cast(ushort)ev.corestate;
    EventSetKeyRepeatFlag(cast(xEvent*) kbp,
                          (ev.type == ET_KeyPress && ev.key_repeat));

    if (num_events > 1)
        kbp.deviceid |= MORE_EVENTS;

    switch (ev.type) {
    case ET_Motion:
        kbp.type = cast(ubyte)DeviceMotionNotify;
        break;
    case ET_ButtonPress:
        kbp.type = cast(ubyte)DeviceButtonPress;
        break;
    case ET_ButtonRelease:
        kbp.type = cast(ubyte)DeviceButtonRelease;
        break;
    case ET_KeyPress:
        kbp.type = cast(ubyte)DeviceKeyPress;
        break;
    case ET_KeyRelease:
        kbp.type = cast(ubyte)DeviceKeyRelease;
        break;
    case ET_ProximityIn:
        kbp.type = cast(ubyte)ProximityIn;
        break;
    case ET_ProximityOut:
        kbp.type = cast(ubyte)ProximityOut;
        break;
    default:
        break;
    }

    if (num_events > 1) {
        getValuatorEvents(ev, cast(deviceValuator*) (kbp + 1));
    }

    *count = num_events;
    return Success;
}

/**
 * Set first to the first valuator in the event ev and return the number of
 * valuators from first to the last set valuator.
 */
private int countValuators(DeviceEvent* ev, int* first)
{
    int first_valuator = -1, last_valuator = -1, num_valuators = 0;

    for (int i = 0; i < cast(int)(((ev.valuators.mask).sizeof * 8)); i++) {
        if (mixin(BitIsOn!("ev.valuators.mask", "i"))) {
            if (first_valuator == -1)
                first_valuator = i;
            last_valuator = i;
        }
    }

    if (first_valuator != -1) {
        num_valuators = last_valuator - first_valuator + 1;
        *first = first_valuator;
    }

    return num_valuators;
}

private int getValuatorEvents(DeviceEvent* ev, deviceValuator* xv)
{
    int state = 0;
    int first_valuator = void, num_valuators = void;

    num_valuators = countValuators(ev, &first_valuator);
    if (num_valuators > 0) {
        DeviceIntPtr dev = null;

        dixLookupDevice(&dev, ev.deviceid, serverClient, DixUseAccess);
        /* State needs to be assembled BEFORE the device is updated. */
        state = (dev &&
                 dev.key) ? mixin(XkbStateFieldFromRec!("&dev.key.xkbInfo.
                                                  state")) : 0;
        state |= (dev && dev.button) ? (dev.button.state) : 0;
    }

    for (int i = 0; i < num_valuators; i += 6, xv++) {
        INT32* valuators = &xv.valuator0;      // Treat all 6 vals as an array

        xv.type = cast(ubyte)DeviceValuator;
        xv.first_valuator = cast(ubyte)(first_valuator + i);
        xv.num_valuators = cast(ubyte)(((num_valuators - i) > 6) ? 6 : (num_valuators - i));
        xv.deviceid = cast(ubyte)ev.deviceid;
        xv.device_state = cast(ushort)state;

        /* Unset valuators in masked valuator events have the proper data values
         * in the case of an absolute axis in between two set valuators. */
        for (int j = 0; j < xv.num_valuators; j++)
            valuators[j] = cast(int)ev.valuators.data[xv.first_valuator + j];

        if (i + 6 < num_valuators)
            xv.deviceid |= MORE_EVENTS;
    }

    return (num_valuators + 5) / 6;
}

private int appendKeyInfo(DeviceChangedEvent* dce, xXIKeyInfo* info)
{
    uint* kc = void;

    info.type = XIKeyClass;
    info.num_keycodes = cast(ushort)(dce.keys.max_keycode - dce.keys.min_keycode + 1);
    info.length = cast(ushort)(xXIKeyInfo.sizeof / 4 + info.num_keycodes);
    info.sourceid = cast(ushort)dce.sourceid;

    kc = cast(uint*) &info[1];
    for (int i = 0; i < info.num_keycodes; i++)
        *kc++ = i + dce.keys.min_keycode;

    return info.length * 4;
}

private int appendButtonInfo(DeviceChangedEvent* dce, xXIButtonInfo* info)
{
    ubyte* bits = void;
    int mask_len = void;

    mask_len = cast(int)bytes_to_int32(bits_to_bytes(dce.buttons.num_buttons));

    info.type = XIButtonClass;
    info.num_buttons = cast(ushort)dce.buttons.num_buttons;
    info.length = cast(ushort)(bytes_to_int32(xXIButtonInfo.sizeof) +
        info.num_buttons + mask_len);
    info.sourceid = cast(ushort)dce.sourceid;

    bits = cast(ubyte*) &info[1];
    memset(bits, 0, mask_len * 4);
    /* FIXME: is_down? */

    bits += mask_len * 4;
    memcpy(bits, dce.buttons.names.ptr, dce.buttons.num_buttons * Atom.sizeof);

    return info.length * 4;
}

private int appendValuatorInfo(DeviceChangedEvent* dce, xXIValuatorInfo* info, int axisnumber)
{
    info.type = XIValuatorClass;
    info.length = xXIValuatorInfo.sizeof / 4;
    info.label = cast(uint)dce.valuators[axisnumber].name;
    info.min.integral = dce.valuators[axisnumber].min;
    info.min.frac = 0;
    info.max.integral = dce.valuators[axisnumber].max;
    info.max.frac = 0;
    info.value = double_to_fp3232(dce.valuators[axisnumber].value);
    info.resolution = dce.valuators[axisnumber].resolution;
    info.number = cast(ushort)axisnumber;
    info.mode = dce.valuators[axisnumber].mode;
    info.sourceid = cast(ushort)dce.sourceid;

    return info.length * 4;
}

private int appendScrollInfo(DeviceChangedEvent* dce, xXIScrollInfo* info, int axisnumber)
{
    if (dce.valuators[axisnumber].scroll.type == SCROLL_TYPE_NONE)
        return 0;

    info.type = XIScrollClass;
    info.length = xXIScrollInfo.sizeof / 4;
    info.number = cast(ushort)axisnumber;
    switch (dce.valuators[axisnumber].scroll.type) {
    case SCROLL_TYPE_VERTICAL:
        info.scroll_type = XIScrollTypeVertical;
        break;
    case SCROLL_TYPE_HORIZONTAL:
        info.scroll_type = XIScrollTypeHorizontal;
        break;
    default:
        ErrorF("[Xi] Unknown scroll type %d. This is a bug.\n",
               dce.valuators[axisnumber].scroll.type);
        break;
    }
    info.increment =
        double_to_fp3232(dce.valuators[axisnumber].scroll.increment);
    info.sourceid = cast(ushort)dce.sourceid;

    info.flags = 0;

    if (dce.valuators[axisnumber].scroll.flags & SCROLL_FLAG_DONT_EMULATE)
        info.flags |= XIScrollFlagNoEmulation;
    if (dce.valuators[axisnumber].scroll.flags & SCROLL_FLAG_PREFERRED)
        info.flags |= XIScrollFlagPreferred;

    return info.length * 4;
}

private int eventToDeviceChanged(DeviceChangedEvent* dce, xEvent** xi)
{
    xXIDeviceChangedEvent* dcce = void;
    int len = xXIDeviceChangedEvent.sizeof;
    int nkeys = void;
    char* ptr = void;

    if (dce.buttons.num_buttons) {
        len += xXIButtonInfo.sizeof;
        len += dce.buttons.num_buttons * Atom.sizeof; /* button names */
        len += pad_to_int32(bits_to_bytes(dce.buttons.num_buttons));
    }
    if (dce.num_valuators) {
        len += ((xXIValuatorInfo).sizeof * dce.num_valuators);

        for (int i = 0; i < dce.num_valuators; i++)
            if (dce.valuators[i].scroll.type != SCROLL_TYPE_NONE)
                len += xXIScrollInfo.sizeof;
    }

    nkeys = (dce.keys.max_keycode > 0) ?
        dce.keys.max_keycode - dce.keys.min_keycode + 1 : 0;
    if (nkeys > 0) {
        len += xXIKeyInfo.sizeof;
        len += ((CARD32).sizeof * nkeys);  /* keycodes */
    }

    dcce = cast(xXIDeviceChangedEvent*) calloc(1, len);
    if (!dcce) {
        ErrorF("[Xi] BadAlloc in SendDeviceChangedEvent.\n");
        return BadAlloc;
    }

    dcce.type = GenericEvent;
    dcce.extension = EXTENSION_MAJOR_XINPUT;
    dcce.evtype = XI_DeviceChanged;
    dcce.time = cast(uint)dce.time;
    dcce.deviceid = cast(ushort)dce.deviceid;
    dcce.sourceid = cast(ushort)dce.sourceid;
    dcce.reason =
        (dce.flags & DEVCHANGE_DEVICE_CHANGE) ? XIDeviceChange : XISlaveSwitch;
    dcce.num_classes = 0;
    dcce.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);

    ptr = cast(char*) &dcce[1];
    if (dce.buttons.num_buttons) {
        dcce.num_classes++;
        ptr += appendButtonInfo(dce, cast(xXIButtonInfo*) ptr);
    }

    if (nkeys) {
        dcce.num_classes++;
        ptr += appendKeyInfo(dce, cast(xXIKeyInfo*) ptr);
    }

    if (dce.num_valuators) {
        dcce.num_classes += dce.num_valuators;
        for (int i = 0; i < dce.num_valuators; i++)
            ptr += appendValuatorInfo(dce, cast(xXIValuatorInfo*) ptr, i);

        for (int i = 0; i < dce.num_valuators; i++) {
            if (dce.valuators[i].scroll.type != SCROLL_TYPE_NONE) {
                dcce.num_classes++;
                ptr += appendScrollInfo(dce, cast(xXIScrollInfo*) ptr, i);
            }
        }
    }

    *xi = cast(xEvent*) dcce;

    return Success;
}

private int count_bits(ubyte* ptr, int len)
{
    int bits = 0;
    ubyte x = void;

    for (uint i = 0; i < len; i++) {
        x = ptr[i];
        while (x > 0) {
            bits += (x & 0x1);
            x >>= 1;
        }
    }
    return bits;
}

private int eventToDeviceEvent(DeviceEvent* ev, xEvent** xi)
{
    int len = xXIDeviceEvent.sizeof;
    xXIDeviceEvent* xde = void;
    int btlen = void, vallen = void;
    char* ptr = void;
    FP3232* axisval = void;

    /* FIXME: this should just send the buttons we have, not MAX_BUTTONs. Same
     * with MAX_VALUATORS below */
    /* btlen is in 4 byte units */
    btlen = cast(int)bytes_to_int32(bits_to_bytes(MAX_BUTTONS));
    len += btlen * 4;           /* buttonmask len */

    vallen = count_bits(ev.valuators.mask.ptr, ev.valuators.mask.length);
    len += vallen * 2 * uint.sizeof;       /* axisvalues */
    vallen = cast(int)bytes_to_int32(bits_to_bytes(MAX_VALUATORS));
    len += vallen * 4;          /* valuators mask */

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    xde = cast(xXIDeviceEvent*) * xi;
    xde.type = GenericEvent;
    xde.extension = EXTENSION_MAJOR_XINPUT;
    xde.evtype = cast(ushort)GetXI2Type(ev.type);
    xde.time = cast(uint)ev.time;
    xde.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    if (IsTouchEvent(cast(InternalEvent*) ev))
        xde.detail = ev.touchid;
    else
        xde.detail = ev.detail.button;

    xde.root = cast(uint)ev.root;
    xde.buttons_len = cast(ushort)btlen;
    xde.valuators_len = cast(ushort)vallen;
    xde.deviceid = cast(ushort)ev.deviceid;
    xde.sourceid = cast(ushort)ev.sourceid;
    xde.root_x = double_to_fp1616(ev.root_x + ev.root_x_frac);
    xde.root_y = double_to_fp1616(ev.root_y + ev.root_y_frac);

    if (IsTouchEvent(cast(InternalEvent*)ev)) {
        if (ev.type == ET_TouchUpdate)
            xde.flags |= (ev.flags & TOUCH_PENDING_END) ? XITouchPendingEnd : 0;

        if (ev.flags & TOUCH_POINTER_EMULATED)
            xde.flags |= XITouchEmulatingPointer;
    } else {
        xde.flags = ev.flags;

        if (ev.key_repeat)
            xde.flags |= XIKeyRepeat;
    }

    xde.mods.base_mods = ev.mods.base;
    xde.mods.latched_mods = ev.mods.latched;
    xde.mods.locked_mods = ev.mods.locked;
    xde.mods.effective_mods = ev.mods.effective;

    xde.group.base_group = ev.group.base;
    xde.group.latched_group = ev.group.latched;
    xde.group.locked_group = ev.group.locked;
    xde.group.effective_group = ev.group.effective;

    ptr = cast(char*) &xde[1];
    for (int i = 0; i < ((ev.buttons).sizeof * 8); i++) {
        if (mixin(BitIsOn!("ev.buttons", "i")))
            mixin(SetBit!("ptr", "i"));
    }

    ptr += xde.buttons_len * 4;
    axisval = cast(FP3232*) (ptr + xde.valuators_len * 4);
    for (int i = 0; i < MAX_VALUATORS; i++) {
        if (mixin(BitIsOn!("ev.valuators.mask", "i"))) {
            mixin(SetBit!("ptr", "i"));
            *axisval = double_to_fp3232(ev.valuators.data[i]);
            axisval++;
        }
    }

    return Success;
}

private int eventToTouchOwnershipEvent(TouchOwnershipEvent* ev, xEvent** xi)
{
    int len = xXITouchOwnershipEvent.sizeof;
    xXITouchOwnershipEvent* xtoe = void;

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    xtoe = cast(xXITouchOwnershipEvent*) * xi;
    xtoe.type = GenericEvent;
    xtoe.extension = EXTENSION_MAJOR_XINPUT;
    xtoe.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    xtoe.evtype = cast(ushort)GetXI2Type(ev.type);
    xtoe.deviceid = cast(ushort)ev.deviceid;
    xtoe.time = cast(uint)ev.time;
    xtoe.sourceid = cast(ushort)ev.sourceid;
    xtoe.touchid = ev.touchid;
    xtoe.flags = 0;            /* we don't have wire flags for ownership yet */

    return Success;
}

private int eventToRawEvent(RawDeviceEvent* ev, xEvent** xi)
{
    xXIRawEvent* raw = void;
    int vallen = void, nvals = void;
    int len = xXIRawEvent.sizeof;
    char* ptr = void;
    FP3232* axisval = void, axisval_raw = void;

    nvals = count_bits(ev.valuators.mask.ptr, typeof(ev.valuators.mask).sizeof);
    len += nvals * ((FP3232).sizeof * 2);  /* 8 byte per valuator, once
                                           raw, once processed */
    vallen = cast(int)bytes_to_int32(bits_to_bytes(MAX_VALUATORS));
    len += vallen * 4;          /* valuators mask */

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    raw = cast(xXIRawEvent*) * xi;
    raw.type = GenericEvent;
    raw.extension = EXTENSION_MAJOR_XINPUT;
    raw.evtype = cast(ushort)GetXI2Type(ev.type);
    raw.time = cast(uint)ev.time;
    raw.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    raw.detail = ev.detail.button;
    raw.deviceid = cast(ushort)ev.deviceid;
    raw.sourceid = cast(ushort)ev.sourceid;
    raw.valuators_len = cast(ushort)vallen;
    raw.flags = ev.flags;

    ptr = cast(char*) &raw[1];
    axisval = cast(FP3232*) (ptr + raw.valuators_len * 4);
    axisval_raw = axisval + nvals;
    for (int i = 0; i < MAX_VALUATORS; i++) {
        if (mixin(BitIsOn!("ev.valuators.mask", "i"))) {
            mixin(SetBit!("ptr", "i"));
            *axisval = double_to_fp3232(ev.valuators.data[i]);
            *axisval_raw = double_to_fp3232(ev.valuators.data_raw[i]);
            axisval++;
            axisval_raw++;
        }
    }

    return Success;
}

private int eventToBarrierEvent(BarrierEvent* ev, xEvent** xi)
{
    xXIBarrierEvent* barrier = void;
    int len = xXIBarrierEvent.sizeof;

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    barrier = cast(xXIBarrierEvent*) *xi;
    barrier.type = GenericEvent;
    barrier.extension = EXTENSION_MAJOR_XINPUT;
    barrier.evtype = cast(ushort)GetXI2Type(ev.type);
    barrier.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    barrier.deviceid = cast(ushort)ev.deviceid;
    barrier.sourceid = cast(ushort)ev.sourceid;
    barrier.time = cast(uint)ev.time;
    barrier.event = cast(uint)ev.window;
    barrier.root = cast(uint)ev.root;
    barrier.dx = double_to_fp3232(ev.dx);
    barrier.dy = double_to_fp3232(ev.dy);
    barrier.dtime = ev.dt;
    barrier.flags = ev.flags;
    barrier.eventid = ev.event_id;
    barrier.barrier = ev.barrierid;
    barrier.root_x = double_to_fp1616(ev.root_x);
    barrier.root_y = double_to_fp1616(ev.root_y);

    return Success;
}

int eventToGesturePinchEvent(GestureEvent* ev, xEvent** xi)
{
    int len = xXIGesturePinchEvent.sizeof;
    xXIGesturePinchEvent* xpe = void;

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    xpe = cast(xXIGesturePinchEvent*) * xi;
    xpe.type = GenericEvent;
    xpe.extension = EXTENSION_MAJOR_XINPUT;
    xpe.evtype = cast(ushort)GetXI2Type(ev.type);
    xpe.time = cast(uint)ev.time;
    xpe.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    xpe.detail = ev.num_touches;

    xpe.root = cast(uint)ev.root;
    xpe.deviceid = cast(ushort)ev.deviceid;
    xpe.sourceid = cast(ushort)ev.sourceid;
    xpe.root_x = double_to_fp1616(ev.root_x);
    xpe.root_y = double_to_fp1616(ev.root_y);
    xpe.flags |= (ev.flags & GESTURE_CANCELLED) ? XIGesturePinchEventCancelled : 0;

    xpe.delta_x = double_to_fp1616(ev.delta_x);
    xpe.delta_y = double_to_fp1616(ev.delta_y);
    xpe.delta_unaccel_x = double_to_fp1616(ev.delta_unaccel_x);
    xpe.delta_unaccel_y = double_to_fp1616(ev.delta_unaccel_y);
    xpe.scale = double_to_fp1616(ev.scale);
    xpe.delta_angle = double_to_fp1616(ev.delta_angle);

    xpe.mods.base_mods = ev.mods.base;
    xpe.mods.latched_mods = ev.mods.latched;
    xpe.mods.locked_mods = ev.mods.locked;
    xpe.mods.effective_mods = ev.mods.effective;

    xpe.group.base_group = ev.group.base;
    xpe.group.latched_group = ev.group.latched;
    xpe.group.locked_group = ev.group.locked;
    xpe.group.effective_group = ev.group.effective;

    return Success;
}

int eventToGestureSwipeEvent(GestureEvent* ev, xEvent** xi)
{
    int len = xXIGestureSwipeEvent.sizeof;
    xXIGestureSwipeEvent* xde = void;

    *xi = cast(_xEvent*)calloc(1, len);
    if (*xi is null)
        return BadAlloc;
    xde = cast(xXIGestureSwipeEvent*) * xi;
    xde.type = GenericEvent;
    xde.extension = EXTENSION_MAJOR_XINPUT;
    xde.evtype = cast(ushort)GetXI2Type(ev.type);
    xde.time = cast(uint)ev.time;
    xde.length = cast(uint)bytes_to_int32(len - xEvent.sizeof);
    xde.detail = ev.num_touches;

    xde.root = cast(uint)ev.root;
    xde.deviceid = cast(ushort)ev.deviceid;
    xde.sourceid = cast(ushort)ev.sourceid;
    xde.root_x = double_to_fp1616(ev.root_x);
    xde.root_y = double_to_fp1616(ev.root_y);
    xde.flags |= (ev.flags & GESTURE_CANCELLED) ? XIGestureSwipeEventCancelled : 0;

    xde.delta_x = double_to_fp1616(ev.delta_x);
    xde.delta_y = double_to_fp1616(ev.delta_y);
    xde.delta_unaccel_x = double_to_fp1616(ev.delta_unaccel_x);
    xde.delta_unaccel_y = double_to_fp1616(ev.delta_unaccel_y);

    xde.mods.base_mods = ev.mods.base;
    xde.mods.latched_mods = ev.mods.latched;
    xde.mods.locked_mods = ev.mods.locked;
    xde.mods.effective_mods = ev.mods.effective;

    xde.group.base_group = ev.group.base;
    xde.group.latched_group = ev.group.latched;
    xde.group.locked_group = ev.group.locked;
    xde.group.effective_group = ev.group.effective;

    return Success;
}

/**
 * Return the corresponding core type for the given event or 0 if no core
 * equivalent exists.
 */
int GetCoreType(EventType type)
{
    int coretype = 0;

    switch (type) {
    case ET_Motion:
        coretype = MotionNotify;
        break;
    case ET_ButtonPress:
        coretype = ButtonPress;
        break;
    case ET_ButtonRelease:
        coretype = ButtonRelease;
        break;
    case ET_KeyPress:
        coretype = KeyPress;
        break;
    case ET_KeyRelease:
        coretype = KeyRelease;
        break;
    default:
        break;
    }
    return coretype;
}

/**
 * Return the corresponding XI 1.x type for the given event or 0 if no
 * equivalent exists.
 */
int GetXIType(EventType type)
{
    int xitype = 0;

    switch (type) {
    case ET_Motion:
        xitype = DeviceMotionNotify;
        break;
    case ET_ButtonPress:
        xitype = DeviceButtonPress;
        break;
    case ET_ButtonRelease:
        xitype = DeviceButtonRelease;
        break;
    case ET_KeyPress:
        xitype = DeviceKeyPress;
        break;
    case ET_KeyRelease:
        xitype = DeviceKeyRelease;
        break;
    case ET_ProximityIn:
        xitype = ProximityIn;
        break;
    case ET_ProximityOut:
        xitype = ProximityOut;
        break;
    default:
        break;
    }
    return xitype;
}

/**
 * Return the corresponding XI 2.x type for the given event or 0 if no
 * equivalent exists.
 */
int GetXI2Type(EventType type)
{
    int xi2type = 0;

    switch (type) {
    case ET_Motion:
        xi2type = XI_Motion;
        break;
    case ET_ButtonPress:
        xi2type = XI_ButtonPress;
        break;
    case ET_ButtonRelease:
        xi2type = XI_ButtonRelease;
        break;
    case ET_KeyPress:
        xi2type = XI_KeyPress;
        break;
    case ET_KeyRelease:
        xi2type = XI_KeyRelease;
        break;
    case ET_Enter:
        xi2type = XI_Enter;
        break;
    case ET_Leave:
        xi2type = XI_Leave;
        break;
    case ET_Hierarchy:
        xi2type = XI_HierarchyChanged;
        break;
    case ET_DeviceChanged:
        xi2type = XI_DeviceChanged;
        break;
    case ET_RawKeyPress:
        xi2type = XI_RawKeyPress;
        break;
    case ET_RawKeyRelease:
        xi2type = XI_RawKeyRelease;
        break;
    case ET_RawButtonPress:
        xi2type = XI_RawButtonPress;
        break;
    case ET_RawButtonRelease:
        xi2type = XI_RawButtonRelease;
        break;
    case ET_RawMotion:
        xi2type = XI_RawMotion;
        break;
    case ET_RawTouchBegin:
        xi2type = XI_RawTouchBegin;
        break;
    case ET_RawTouchUpdate:
        xi2type = XI_RawTouchUpdate;
        break;
    case ET_RawTouchEnd:
        xi2type = XI_RawTouchEnd;
        break;
    case ET_FocusIn:
        xi2type = XI_FocusIn;
        break;
    case ET_FocusOut:
        xi2type = XI_FocusOut;
        break;
    case ET_TouchBegin:
        xi2type = XI_TouchBegin;
        break;
    case ET_TouchEnd:
        xi2type = XI_TouchEnd;
        break;
    case ET_TouchUpdate:
        xi2type = XI_TouchUpdate;
        break;
    case ET_TouchOwnership:
        xi2type = XI_TouchOwnership;
        break;
    case ET_BarrierHit:
        xi2type = XI_BarrierHit;
        break;
    case ET_BarrierLeave:
        xi2type = XI_BarrierLeave;
        break;
    case ET_GesturePinchBegin:
        xi2type = XI_GesturePinchBegin;
        break;
    case ET_GesturePinchUpdate:
        xi2type = XI_GesturePinchUpdate;
        break;
    case ET_GesturePinchEnd:
        xi2type = XI_GesturePinchEnd;
        break;
    case ET_GestureSwipeBegin:
        xi2type = XI_GestureSwipeBegin;
        break;
    case ET_GestureSwipeUpdate:
        xi2type = XI_GestureSwipeUpdate;
        break;
    case ET_GestureSwipeEnd:
        xi2type = XI_GestureSwipeEnd;
        break;
    default:
        break;
    }
    return xi2type;
}

/**
 * Converts a gesture type to corresponding Gesture{Pinch,Swipe}Begin.
 * Returns 0 if the input type is not a gesture.
 */
EventType GestureTypeToBegin(EventType type)
{
    switch (type) {
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
        return ET_GesturePinchBegin;
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        return ET_GestureSwipeBegin;
    default:
        return cast(EventType)0;
    }
}

/**
 * Converts a gesture type to corresponding Gesture{Pinch,Swipe}End.
 * Returns 0 if the input type is not a gesture.
 */
EventType GestureTypeToEnd(EventType type)
{
    switch (type) {
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
        return ET_GesturePinchEnd;
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        return ET_GestureSwipeEnd;
    default:
        return cast(EventType)0;
    }
}
