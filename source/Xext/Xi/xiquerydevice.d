module Xi.xiquerydevice;
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
 * Authors: Peter Hutterer
 *
 */

/**
 * @file Protocol handling for the XIQueryDevice request/reply.
 */

import build.dix_config;

//import x11.X;
//import externs.X11.Xatom;
import externs.X11.extensions.XI2proto;
import externs.X11.extensions.XI;


import dix.devices_priv;
import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.inpututils_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import os.fmt;
import Xi.handlers;

import dix.inputstr;
import xkb.xkbsrv_priv;
import xkb.xkbsrv_priv;
import common.xserver_properties;
import Xi.exglobals;
import dix.privates;
import Xi.xiquerydevice;
import dix.devices;
import os.log;
import dix.events;
import dix.inpututils;
import xkb.xkbstr;
import common.bytes;
import common.swap;


//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// static Bool ShouldSkipDevice(ClientPtr client, int deviceid, DeviceIntPtr d);
// static int
//  ListDeviceInfo(ClientPtr client, DeviceIntPtr dev, xXIDeviceInfo * info);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// static int SizeDeviceInfo(DeviceIntPtr dev);
// static void SwapDeviceInfo(DeviceIntPtr dev, xXIDeviceInfo * info);

int ProcXIQueryDevice(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIQueryDeviceReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");

    DeviceIntPtr dev = null;
    int rc = Success;
    int i = 0, len = 0;
    char* info = void;
    Bool* skip = null;

    if (stuff.deviceid != XIAllDevices &&
        stuff.deviceid != XIAllMasterDevices) {
        rc = dixLookupDevice(&dev, stuff.deviceid, client, DixGetAttrAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.deviceid;
            return rc;
        }
        len += SizeDeviceInfo(dev);
    }
    else {
        skip = cast(Bool*) calloc(inputInfo.numDevices, Bool.sizeof);
        if (!skip)
            return BadAlloc;

        for (dev = inputInfo.devices; dev; dev = dev.next, i++) {
            skip[i] = ShouldSkipDevice(client, stuff.deviceid, dev);
            if (!skip[i])
                len += SizeDeviceInfo(dev);
        }

        for (dev = inputInfo.off_devices; dev; dev = dev.next, i++) {
            skip[i] = ShouldSkipDevice(client, stuff.deviceid, dev);
            if (!skip[i])
                len += SizeDeviceInfo(dev);
        }
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: True };

    info = cast(char*)x_rpcbuf_reserve(&rpcbuf, len);
    if (!info) {
        free(skip);
        return BadAlloc;
    }

    xXIQueryDeviceReply reply = {
        RepType: X_XIQueryDevice,
    };

    if (dev) {
        len = ListDeviceInfo(client, dev, cast(xXIDeviceInfo*) info);
        if (client.swapped)
            SwapDeviceInfo(dev, cast(xXIDeviceInfo*) info);
        info += len;
        reply.num_devices = 1;
    }
    else {
        i = 0;
        for (dev = inputInfo.devices; dev; dev = dev.next, i++) {
            if (!skip[i]) {
                len = ListDeviceInfo(client, dev, cast(xXIDeviceInfo*) info);
                if (client.swapped)
                    SwapDeviceInfo(dev, cast(xXIDeviceInfo*) info);
                info += len;
                reply.num_devices++;
            }
        }

        for (dev = inputInfo.off_devices; dev; dev = dev.next, i++) {
            if (!skip[i]) {
                len = ListDeviceInfo(client, dev, cast(xXIDeviceInfo*) info);
                if (client.swapped)
                    SwapDeviceInfo(dev, cast(xXIDeviceInfo*) info);
                info += len;
                reply.num_devices++;
            }
        }
    }

    free(skip);

    mixin(X_REPLY_FIELD_CARD16!"num_devices");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/**
 * @return Whether the device should be included in the returned list.
 */
pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private Bool ShouldSkipDevice(ClientPtr client, int deviceid, DeviceIntPtr dev)
{
    /* if all devices are not being queried, only master devices are */
    if (deviceid == XIAllDevices || InputDevIsMaster(dev)) {
        int rc = dixCallDeviceAccessCallback(client, dev, DixGetAttrAccess);
        if (rc == Success)
            return False;
    }
    return True;
}

/**
 * @return The number of bytes needed to store this device's xXIDeviceInfo
 * (and its classes).
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int SizeDeviceInfo(DeviceIntPtr dev)
{
    int len = xXIDeviceInfo.sizeof;

    /* 4-padded name */
    len += padForInt32(cast(int)strlen(dev.name));

    return len + SizeDeviceClasses(dev);

}

/*
 * @return The number of bytes needed to store this device's classes.
 */
int SizeDeviceClasses(DeviceIntPtr dev)
{
    int len = 0;

    if (dev.button) {
        len += xXIButtonInfo.sizeof;
        len += dev.button.numButtons * Atom.sizeof;
        len += padForInt32(bytesForBits(dev.button.numButtons));
    }

    if (dev.key) {
        XkbDescPtr xkb = dev.key.xkbInfo.desc;

        len += xXIKeyInfo.sizeof;
        len += (xkb.max_key_code - xkb.min_key_code + 1) * uint.sizeof;
    }

    if (dev.valuator) {
        int i = void;

        len += (xXIValuatorInfo.sizeof) * dev.valuator.numAxes;

        for (i = 0; i < dev.valuator.numAxes; i++) {
            if (dev.valuator.axes[i].scroll.type != SCROLL_TYPE_NONE)
                len += xXIScrollInfo.sizeof;
        }
    }

    if (dev.touch)
        len += xXITouchInfo.sizeof;

    if (dev.gesture)
        len += xXIGestureInfo.sizeof;

    return len;
}

/**
 * Get pointers to button information areas holding button mask and labels.
 */
private void ButtonInfoData(xXIButtonInfo* info, int* mask_words, ubyte** mask, Atom** atoms)
{
    *mask_words = cast(int)int32ForBytes(bytesForBits(info.num_buttons));
    *mask = cast(ubyte*) &info[1];
    *atoms = cast(Atom*) ((*mask) + (*mask_words) * 4);
}

/**
 * Write button information into info.
 * @return Number of bytes written into info.
 */
int ListButtonInfo(DeviceIntPtr dev, xXIButtonInfo* info, Bool reportState)
{
    ubyte* bits = void;
    Atom* labels = void;
    int mask_len = void;
    int i = void;

    if (!dev || !dev.button)
        return 0;

    info.type = ButtonClass;
    info.num_buttons = dev.button.numButtons;
    ButtonInfoData(info, &mask_len, &bits, &labels);
    info.length = cast(ushort)(int32ForBytes(xXIButtonInfo.sizeof) +
        info.num_buttons + cast(ushort)mask_len);
    info.sourceid = cast(ushort)dev.button.sourceid;

    memset(bits, 0, mask_len * 4);

    if (reportState)
        for (i = 0; i < dev.button.numButtons; i++)
            if (mixin(BitIsOn!("dev.button.down", "i")))
                mixin(SetBit!("bits", "i"));

    memcpy(labels, dev.button.labels.ptr, dev.button.numButtons * Atom.sizeof);

    return info.length * 4;
}

private void SwapButtonInfo(DeviceIntPtr dev, xXIButtonInfo* info)
{
    Atom* btn = void;
    int mask_len = void;
    ubyte* mask = void;

    int i = void;
    ButtonInfoData(info, &mask_len, &mask, &btn);

    swaps(&info.type);
    swaps(&info.length);
    swaps(&info.sourceid);

    for (i = 0 ; i < info.num_buttons; i++, btn++)
        swapl(btn);

    swaps(&info.num_buttons);
}

/**
 * Write key information into info.
 * @return Number of bytes written into info.
 */
int ListKeyInfo(DeviceIntPtr dev, xXIKeyInfo* info)
{
    int i = void;
    XkbDescPtr xkb = dev.key.xkbInfo.desc;
    uint* kc = void;

    info.type = KeyClass;
    info.num_keycodes = cast(ushort)(xkb.max_key_code - xkb.min_key_code + 1);
    info.length = cast(ushort)(xXIKeyInfo.sizeof / 4 + info.num_keycodes);
    info.sourceid = cast(ushort)dev.key.sourceid;

    kc = cast(uint*) &info[1];
    for (i = xkb.min_key_code; i <= xkb.max_key_code; i++, kc++)
        *kc = i;

    return info.length * 4;
}

private void SwapKeyInfo(DeviceIntPtr dev, xXIKeyInfo* info)
{
    uint* key = void;
    int i = void;

    swaps(&info.type);
    swaps(&info.length);
    swaps(&info.sourceid);

    for (i = 0, key = cast(uint*) &info[1]; i < info.num_keycodes;
         i++, key++)
        swapl(key);

    swaps(&info.num_keycodes);
}

/**
 * List axis information for the given axis.
 *
 * @return The number of bytes written into info.
 */
int ListValuatorInfo(DeviceIntPtr dev, xXIValuatorInfo* info, int axisnumber, Bool reportState)
{
    ValuatorClassPtr v = dev.valuator;

    info.type = ValuatorClass;
    info.length = xXIValuatorInfo.sizeof / 4;
    info.label = cast(uint)v.axes[axisnumber].label;
    info.min.integral = v.axes[axisnumber].min_value;
    info.min.frac = 0;
    info.max.integral = v.axes[axisnumber].max_value;
    info.max.frac = 0;
    info.value = double_to_fp3232(v.axisVal[axisnumber]);
    info.resolution = v.axes[axisnumber].resolution;
    info.number = cast(ushort)axisnumber;
    info.mode = cast(ubyte)valuator_get_mode(dev, axisnumber);
    info.sourceid = cast(ushort)v.sourceid;

    if (!reportState)
        info.value = info.min;

    return info.length * 4;
}

private void SwapValuatorInfo(DeviceIntPtr dev, xXIValuatorInfo* info)
{
    swaps(&info.type);
    swaps(&info.length);
    swapl(&info.label);
    swapl(&info.min.integral);
    swapl(&info.min.frac);
    swapl(&info.max.integral);
    swapl(&info.max.frac);
    swapl(&info.value.integral);
    swapl(&info.value.frac);
    swapl(&info.resolution);
    swaps(&info.number);
    swaps(&info.sourceid);
}

int ListScrollInfo(DeviceIntPtr dev, xXIScrollInfo* info, int axisnumber)
{
    ValuatorClassPtr v = dev.valuator;
    AxisInfoPtr axis = &v.axes[axisnumber];

    if (axis.scroll.type == SCROLL_TYPE_NONE)
        return 0;

    info.type = XIScrollClass;
    info.length = xXIScrollInfo.sizeof / 4;
    info.number = cast(ushort)axisnumber;
    switch (axis.scroll.type) {
    case SCROLL_TYPE_VERTICAL:
        info.scroll_type = XIScrollTypeVertical;
        break;
    case SCROLL_TYPE_HORIZONTAL:
        info.scroll_type = XIScrollTypeHorizontal;
        break;
    default:
        ErrorF("[Xi] Unknown scroll type %d. This is a bug.\n",
               axis.scroll.type);
        break;
    }
    info.increment = double_to_fp3232(axis.scroll.increment);
    info.sourceid = cast(ushort)v.sourceid;

    info.flags = 0;

    if (axis.scroll.flags & SCROLL_FLAG_DONT_EMULATE)
        info.flags |= XIScrollFlagNoEmulation;
    if (axis.scroll.flags & SCROLL_FLAG_PREFERRED)
        info.flags |= XIScrollFlagPreferred;

    return info.length * 4;
}

private void SwapScrollInfo(DeviceIntPtr dev, xXIScrollInfo* info)
{
    swaps(&info.type);
    swaps(&info.length);
    swaps(&info.number);
    swaps(&info.sourceid);
    swaps(&info.scroll_type);
    swapl(&info.increment.integral);
    swapl(&info.increment.frac);
}

/**
 * List multitouch information
 *
 * @return The number of bytes written into info.
 */
int ListTouchInfo(DeviceIntPtr dev, xXITouchInfo* touch)
{
    touch.type = XITouchClass;
    touch.length = (xXITouchInfo.sizeof >> 2);
    touch.sourceid = cast(ushort)dev.touch.sourceid;
    touch.mode = dev.touch.mode;
    touch.num_touches = cast(ubyte)dev.touch.num_touches;

    return touch.length << 2;
}

private void SwapTouchInfo(DeviceIntPtr dev, xXITouchInfo* touch)
{
    swaps(&touch.type);
    swaps(&touch.length);
    swaps(&touch.sourceid);
}

private Bool ShouldListGestureInfo(ClientPtr client)
{
    /* libxcb 14.1 and older are not forwards-compatible with new device classes as it does not
     * properly ignore unknown device classes. Since breaking libxcb would break quite a lot of
     * applications, we instead report Gesture device class only if the client advertised support
     * for XI 2.4. Clients may still not work in cases when a client advertises XI 2.4 support
     * and then a completely separate module Xi.within the client uses broken libxcb to call
     * XIQueryDevice.
     */
    XIClientPtr pXIClient = XIClientPriv(client);
    if (pXIClient.major_version) {
        return version_compare(pXIClient.major_version, pXIClient.minor_version, 2, 4) >= 0;
    }
    return False;
}

/**
 * List gesture information
 *
 * @return The number of bytes written into info.
 */
private int ListGestureInfo(DeviceIntPtr dev, xXIGestureInfo* gesture)
{
    gesture.type = XIGestureClass;
    gesture.length = xXIGestureInfo.sizeof >> 2;
    gesture.sourceid = cast(ushort)dev.gesture.sourceid;
    gesture.num_touches = cast(ubyte)dev.gesture.max_touches;

    return gesture.length << 2;
}

private void SwapGestureInfo(DeviceIntPtr dev, xXIGestureInfo* gesture)
{
    swaps(&gesture.type);
    swaps(&gesture.length);
    swaps(&gesture.sourceid);
}

int GetDeviceUse(DeviceIntPtr dev, ushort* attachment)
{
    DeviceIntPtr master = GetMaster(dev, MASTER_ATTACHED);
    int use = void;

    if (InputDevIsMaster(dev)) {
        DeviceIntPtr paired = GetPairedDevice(dev);

        use = IsPointerDevice(dev) ? XIMasterPointer : XIMasterKeyboard;
        *attachment = (paired ? cast(ushort)paired.id : 0);
    }
    else if (!InputDevIsFloating(dev)) {
        use = IsPointerDevice(master) ? XISlavePointer : XISlaveKeyboard;
        *attachment = cast(ushort)master.id;
    }
    else
        use = XIFloatingSlave;

    return use;
}



/**
 * Write the info for device dev into the buffer pointed to by info.
 *
 * @return The number of bytes used.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int ListDeviceInfo(ClientPtr client, DeviceIntPtr dev, xXIDeviceInfo* info)
{
    char* any = cast(char*) &info[1];
    int len = 0, total_len = 0;

    info.deviceid = cast(ushort)dev.id;
    info.use = cast(ushort)GetDeviceUse(dev, &info.attachment);
    info.num_classes = 0;
    info.name_len = cast(ushort)strlen(dev.name);
    info.enabled = cast(ubyte)dev.enabled;
    total_len = xXIDeviceInfo.sizeof;

    len = padForInt32(info.name_len);
    memset(any, 0, len);
    strncpy(any, dev.name, info.name_len);
    any += len;
    total_len += len;

    total_len += ListDeviceClasses(client, dev, any, &info.num_classes);
    return total_len;
}

/**
 * Write the class info of the device into the memory pointed to by any, set
 * nclasses to the number of classes in total and return the number of bytes
 * written.
 */
private int ListDeviceClasses(ClientPtr client, DeviceIntPtr dev, char* any, ushort* nclasses)
{
    int total_len = 0;
    int len = void;
    int i = void;

    /* Check if the current device state should be suppressed */
    int rc = dixCallDeviceAccessCallback(client, dev, DixReadAccess);
    if (dev.button) {
        (*nclasses)++;
        len = ListButtonInfo(dev, cast(xXIButtonInfo*) any, rc == Success);
        any += len;
        total_len += len;
    }

    if (dev.key) {
        (*nclasses)++;
        len = ListKeyInfo(dev, cast(xXIKeyInfo*) any);
        any += len;
        total_len += len;
    }

    for (i = 0; dev.valuator && i < dev.valuator.numAxes; i++) {
        (*nclasses)++;
        len = ListValuatorInfo(dev, cast(xXIValuatorInfo*) any, i, rc == Success);
        any += len;
        total_len += len;
    }

    for (i = 0; dev.valuator && i < dev.valuator.numAxes; i++) {
        len = ListScrollInfo(dev, cast(xXIScrollInfo*) any, i);
        if (len)
            (*nclasses)++;
        any += len;
        total_len += len;
    }

    if (dev.touch) {
        (*nclasses)++;
        len = ListTouchInfo(dev, cast(xXITouchInfo*) any);
        any += len;
        total_len += len;
    }

    if (dev.gesture && ShouldListGestureInfo(client)) {
        (*nclasses)++;
        len = ListGestureInfo(dev, cast(xXIGestureInfo*) any);
        any += len;
        total_len += len;
    }

    return total_len;
}

private void SwapDeviceInfo(DeviceIntPtr dev, xXIDeviceInfo* info)
{
    char* any = cast(char*) &info[1];
    int i = void;

    /* Skip over name */
    any += padForInt32(info.name_len);

    for (i = 0; i < info.num_classes; i++) {
        int len = (cast(xXIAnyInfo*) any).length;

        switch ((cast(xXIAnyInfo*) any).type) {
        case XIButtonClass:
            SwapButtonInfo(dev, cast(xXIButtonInfo*) any);
            break;
        case XIKeyClass:
            SwapKeyInfo(dev, cast(xXIKeyInfo*) any);
            break;
        case XIValuatorClass:
            SwapValuatorInfo(dev, cast(xXIValuatorInfo*) any);
            break;
        case XIScrollClass:
            SwapScrollInfo(dev, cast(xXIScrollInfo*) any);
            break;
        case XITouchClass:
            SwapTouchInfo(dev, cast(xXITouchInfo*) any);
            break;
        case XIGestureClass:
            SwapGestureInfo(dev, cast(xXIGestureInfo*) any);
            break;
        default: break;}

        any += len * 4;
    }

    swaps(&info.deviceid);
    swaps(&info.use);
    swaps(&info.attachment);
    swaps(&info.num_classes);
    swaps(&info.name_len);

}
