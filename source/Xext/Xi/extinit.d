module Xi.extinit;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1989 by Hewlett-Packard Company, Palo Alto, California.

			All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Hewlett-Packard not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

HEWLETT-PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
HEWLETT-PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

/********************************************************************
 *
 *  Dispatch routines and initialization routines for the X input extension.
 *
 */
enum	 NUMTYPES = 15;

import build.dix_config;

import core.stdc.assert_;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI2proto;
// //import externs.X11.extensions.geproto;

import dix.request_priv;
import dix.dispatch;
import dix.dix_priv;
import dix.input_priv;
import dix.exevents_priv;
import dix.extension_priv;
import miext.extinit_priv;
import Xext.geext_priv;

import dix.inputstr;import dix.gc;           /* pointer for extnsionst.h */
import Xi.exglobals;
import dix.swaprep;
import dix.privates;
import include.protocol_versions;

/* modules local to Xi */
import Xi.handlers;
import Xi.xibarriers;
import Xi.xiproperty;
import Xi.getvers;
import Xi.listdev;
import Xi.opendev;
import Xi.closedev;
import Xi.setmode;
import Xi.getselev;
import Xi.selectev;
import Xi.getprop;
import Xi.chgprop;
import Xi.gtmotion;
import Xi.chgkbd;
import Xi.chgptr;
import Xi.grabdev;
import Xi.grabdevb;
import Xi.ungrdev;
import Xi.ungrdevb;
import Xi.grabdevk;
import Xi.ungrdevk;
import Xi.allowev;
import Xi.getfocus;
// allowev
import Xi.exevents;
import Xi.getprop;
import Xi.setmode;
import Xi.xigetclientpointer;
import Xi.xisetdevfocus;
import Xi.chgdctl;
import Xi.exglobals;
import Xi.getselev;
import Xi.opendev;
import Xi.stubs;
import Xi.xigrabdev;
import Xi.XIstubs;
import Xi.chgfctl;
import Xi.extinit;
import Xi.getvers;
import Xi.queryst;
import Xi.ungrdevb;
import Xi.xipassivegrab;
import Xi.xiwarppointer;
import Xi.chgkbd;
import Xi.getbmap;
import Xi.grabdevb;
import Xi.selectev;
import Xi.ungrdev;
import Xi.xiproperty;
import Xi.chgkmap;
import Xi.getdctl;
import Xi.grabdev;
import Xi.sendexev;
import Xi.ungrdevk;
import Xi.xiquerydevice;
import Xi.chgprop;
import Xi.getfctl;
import Xi.grabdevk;
import Xi.setbmap;
import Xi.xiallowev;
import Xi.xiquerypointer;
import Xi.chgptr;
import Xi.getfocus;
import Xi.gtmotion;
import Xi.setdval;
import Xi.xibarriers;
import Xi.xiqueryversion;
import Xi.closedev;
import Xi.getkmap;
import Xi.handlers;
import Xi.setfocus;
import Xi.xichangecursor;
import Xi.xiselectev;
import Xi.devbell;
import Xi.getmmap;
import Xi.listdev;
import Xi.setmmap;
import Xi.xichangehierarchy;
import Xi.xisetclientpointer;
import dix.events;
import tables;
import common.misc;
import os.log;
import std.conv;
import dix.extension;

import externs.X11.extensions.XI;

/* Masks for XI events have to be aligned with core event (partially anyway).
 * If DeviceButtonMotionMask is != ButtonMotionMask, event delivery
 * breaks down. The device needs the dev->button->motionMask. If DBMM is
 * the same as BMM, we can ensure that both core and device events can be
 * delivered, without the need for extra structures in the DeviceIntRec. */
const(Mask) DeviceProximityMask = (1L << 4);
const(Mask) DeviceStateNotifyMask = (1L << 5);
const(Mask) DevicePointerMotionHintMask = PointerMotionHintMask;
const(Mask) DeviceButton1MotionMask = Button1MotionMask;
const(Mask) DeviceButton2MotionMask = Button2MotionMask;
const(Mask) DeviceButton3MotionMask = Button3MotionMask;
const(Mask) DeviceButton4MotionMask = Button4MotionMask;
const(Mask) DeviceButton5MotionMask = Button5MotionMask;
const(Mask) DeviceButtonMotionMask = ButtonMotionMask;
const(Mask) DeviceFocusChangeMask = (1L << 14);
const(Mask) DeviceMappingNotifyMask = (1L << 15);
const(Mask) ChangeDeviceNotifyMask = (1L << 16);
const(Mask) DeviceButtonGrabMask = (1L << 17);
const(Mask) DeviceOwnerGrabButtonMask = (1L << 17);
const(Mask) DevicePresenceNotifyMask = (1L << 18);
const(Mask) DevicePropertyNotifyMask = (1L << 19);
const(Mask) XIAllMasks = (1L << 20) - 1;

int ExtEventIndex;

struct dev_type_ {
    Atom type;
    const(char)* name;
}

private dev_type_[18] dev_type = [
    {0, XI_KEYBOARD},
    {0, XI_MOUSE},
    {0, XI_TABLET},
    {0, XI_TOUCHSCREEN},
    {0, XI_TOUCHPAD},
    {0, XI_BARCODE},
    {0, XI_BUTTONBOX},
    {0, XI_KNOB_BOX},
    {0, XI_ONE_KNOB},
    {0, XI_NINE_KNOB},
    {0, XI_TRACKBALL},
    {0, XI_QUADRATURE},
    {0, XI_ID_MODULE},
    {0, XI_SPACEBALL},
    {0, XI_DATAGLOVE},
    {0, XI_EYETRACKER},
    {0, XI_CURSORKEYS},
    {0, XI_FOOTMOUSE}
];

CARD8[numInputClasses] event_base;
XExtEventInfo[32] EventInfo;

private DeviceIntRec xi_all_devices;
private DeviceIntRec xi_all_master_devices;

/*****************************************************************
 *
 * Globals referenced elsewhere in the server.
 *
 */

int IEventBase = 0;
int BadDevice = 0;
private int BadEvent = 1;
int BadMode = 2;
int DeviceBusy = 3;
int BadClass = 4;

int DeviceValuator;
int DeviceKeyPress;
int DeviceKeyRelease;
int DeviceButtonPress;
int DeviceButtonRelease;
int DeviceMotionNotify;
int DeviceFocusIn;
int DeviceFocusOut;
int ProximityIn;
int ProximityOut;
int DeviceStateNotify;
int DeviceKeyStateNotify;
int DeviceButtonStateNotify;
int DeviceMappingNotify;
int ChangeDeviceNotify;
int DevicePresenceNotify;
int DevicePropertyNotify;

RESTYPE RT_INPUTCLIENT;

/*****************************************************************
 *
 * Externs defined elsewhere in the X server.
 *
 */

XExtensionVersion XIVersion;

/*****************************************************************
 *
 * Versioning support
 *
 */

DevPrivateKeyRec XIClientPrivateKeyRec;

/*****************************************************************
 *
 * Declarations of local routines.
 *
 */

/*************************************************************************
 *
 * ProcIDispatch - main dispatch routine for requests to this extension.
 * This routine is used if server and client have the same byte ordering.
 *
 */

private int ProcIDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    UpdateCurrentTimeIf();

    switch (stuff.data) {
        case X_GetExtensionVersion:
            return ProcXGetExtensionVersion(client);
        case X_ListInputDevices:
            return ProcXListInputDevices(client);
        case X_OpenDevice:
            return ProcXOpenDevice(client);
        case X_CloseDevice:
            return ProcXCloseDevice(client);
        case X_SetDeviceMode:
            return ProcXSetDeviceMode(client);
        case X_SelectExtensionEvent:
            return ProcXSelectExtensionEvent(client);
        case X_GetSelectedExtensionEvents:
            return ProcXGetSelectedExtensionEvents(client);
        case X_ChangeDeviceDontPropagateList:
            return ProcXChangeDeviceDontPropagateList(client);
        case X_GetDeviceDontPropagateList:
            return ProcXGetDeviceDontPropagateList(client);
        case X_GetDeviceMotionEvents:
            return ProcXGetDeviceMotionEvents(client);
        case X_ChangeKeyboardDevice:
            return ProcXChangeKeyboardDevice(client);
        case X_ChangePointerDevice:
            return ProcXChangePointerDevice(client);
        case X_GrabDevice:
            return ProcXGrabDevice(client);
        case X_UngrabDevice:
            return ProcXUngrabDevice(client);
        case X_GrabDeviceKey:
            return ProcXGrabDeviceKey(client);
        case X_UngrabDeviceKey:
            return ProcXUngrabDeviceKey(client);
        case X_GrabDeviceButton:
            return ProcXGrabDeviceButton(client);
        case X_UngrabDeviceButton:
            return ProcXUngrabDeviceButton(client);
        case X_AllowDeviceEvents:
            return ProcXAllowDeviceEvents(client);
        case X_GetDeviceFocus:
            return ProcXGetDeviceFocus(client);
        case X_SetDeviceFocus:
            return ProcXSetDeviceFocus(client);
        case X_GetFeedbackControl:
            return ProcXGetFeedbackControl(client);
        case X_ChangeFeedbackControl:
            return ProcXChangeFeedbackControl(client);
        case X_GetDeviceKeyMapping:
            return ProcXGetDeviceKeyMapping(client);
        case X_ChangeDeviceKeyMapping:
            return ProcXChangeDeviceKeyMapping(client);
        case X_GetDeviceModifierMapping:
            return ProcXGetDeviceModifierMapping(client);
        case X_SetDeviceModifierMapping:
            return ProcXSetDeviceModifierMapping(client);
        case X_GetDeviceButtonMapping:
            return ProcXGetDeviceButtonMapping(client);
        case X_SetDeviceButtonMapping:
            return ProcXSetDeviceButtonMapping(client);
        case X_QueryDeviceState:
            return ProcXQueryDeviceState(client);
        case X_SendExtensionEvent:
            return ProcXSendExtensionEvent(client);
        case X_DeviceBell:
            return ProcXDeviceBell(client);
        case X_SetDeviceValuators:
            return ProcXSetDeviceValuators(client);
        case X_GetDeviceControl:
            return ProcXGetDeviceControl(client);
        case X_ChangeDeviceControl:
            return ProcXChangeDeviceControl(client);
        /* XI 1.5 */
        case X_ListDeviceProperties:
            return ProcXListDeviceProperties(client);
        case X_ChangeDeviceProperty:
            return ProcXChangeDeviceProperty(client);
        case X_DeleteDeviceProperty:
            return ProcXDeleteDeviceProperty(client);
        case X_GetDeviceProperty:
            return ProcXGetDeviceProperty(client);
        /* XI 2 */
        case X_XIQueryPointer:
            return ProcXIQueryPointer(client);
        case X_XIWarpPointer:
            return ProcXIWarpPointer(client);
        case X_XIChangeCursor:
            return ProcXIChangeCursor(client);
        case X_XIChangeHierarchy:
            return ProcXIChangeHierarchy(client);
        case X_XISetClientPointer:
            return ProcXISetClientPointer(client);
        case X_XIGetClientPointer:
            return ProcXIGetClientPointer(client);
        case X_XISelectEvents:
            return ProcXISelectEvents(client);
        case X_XIQueryVersion:
            return ProcXIQueryVersion(client);
        case X_XIQueryDevice:
            return ProcXIQueryDevice(client);
        case X_XISetFocus:
            return ProcXISetFocus(client);
        case X_XIGetFocus:
            return ProcXIGetFocus(client);
        case X_XIGrabDevice:
            return ProcXIGrabDevice(client);
        case X_XIUngrabDevice:
            return ProcXIUngrabDevice(client);
        case X_XIAllowEvents:
            return ProcXIAllowEvents(client);
        case X_XIPassiveGrabDevice:
            return ProcXIPassiveGrabDevice(client);
        case X_XIPassiveUngrabDevice:
            return ProcXIPassiveUngrabDevice(client);
        case X_XIListProperties:
            return ProcXIListProperties(client);
        case X_XIChangeProperty:
            return ProcXIChangeProperty(client);
        case X_XIDeleteProperty:
            return ProcXIDeleteProperty(client);
        case X_XIGetProperty:
            return ProcXIGetProperty(client);
        case X_XIGetSelectedEvents:
            return ProcXIGetSelectedEvents(client);
        case X_XIBarrierReleasePointer:
            return ProcXIBarrierReleasePointer(client);
        default:
            return BadRequest;
    }
}

/************************************************************************
 *
 * This function swaps the DeviceValuator event.
 *
 */

private void SEventDeviceValuator(deviceValuator* from, deviceValuator* to)
{
    int i = void;
    INT32* ip = void;

    *to = *from;
    swaps(&to.sequenceNumber);
    swaps(&to.device_state);
    ip = &to.valuator0;
    for (i = 0; i < 6; i++) {
        swapl(ip + i);
    }
}

private void SEventFocus(deviceFocus* from, deviceFocus* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
    swapl(&to.window);
}

private void SDeviceStateNotifyEvent(deviceStateNotify* from, deviceStateNotify* to)
{
    int i = void;
    INT32* ip = void;

    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
    ip = &to.valuator0;
    for (i = 0; i < 3; i++) {
        swapl(ip + i);
    }
}

private void SDeviceKeyStateNotifyEvent(deviceKeyStateNotify* from, deviceKeyStateNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
}

private void SDeviceButtonStateNotifyEvent(deviceButtonStateNotify* from, deviceButtonStateNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
}

private void SChangeDeviceNotifyEvent(changeDeviceNotify* from, changeDeviceNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
}

private void SDeviceMappingNotifyEvent(deviceMappingNotify* from, deviceMappingNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
}

private void SDevicePresenceNotifyEvent(devicePresenceNotify* from, devicePresenceNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
    swaps(&to.control);
}

private void SDevicePropertyNotifyEvent(devicePropertyNotify* from, devicePropertyNotify* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.time);
    swapl(&to.atom);
}

private void SDeviceLeaveNotifyEvent(xXILeaveEvent* from, xXILeaveEvent* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.root);
    swapl(&to.event);
    swapl(&to.child);
    swapl(&to.root_x);
    swapl(&to.root_y);
    swapl(&to.event_x);
    swapl(&to.event_y);
    swaps(&to.sourceid);
    swaps(&to.buttons_len);
    swapl(&to.mods.base_mods);
    swapl(&to.mods.latched_mods);
    swapl(&to.mods.locked_mods);
}

private void SDeviceChangedEvent(xXIDeviceChangedEvent* from, xXIDeviceChangedEvent* to)
{
    int i = void, j = void;
    xXIAnyInfo* any = void;

    *to = *from;
    memcpy(&to[1], &from[1], from.length * 4);

    any = cast(xXIAnyInfo*) &to[1];
    for (i = 0; i < to.num_classes; i++) {
        int length = any.length;

        switch (any.type) {
        case KeyClass:
        {
            xXIKeyInfo* ki = cast(xXIKeyInfo*) any;
            uint* key = cast(uint*) &ki[1];

            for (j = 0; j < ki.num_keycodes; j++, key++)
                swapl(key);
            swaps(&ki.num_keycodes);
        }
            break;
        case ButtonClass:
        {
            xXIButtonInfo* bi = cast(xXIButtonInfo*) any;
            Atom* labels = cast(Atom*) (cast(char*) bi + ((xXIButtonInfo).sizeof +
                                     pad_to_int32(bits_to_bytes
                                                  (bi.num_buttons))));
            for (j = 0; j < bi.num_buttons; j++)
                swapl(&labels[j]);
            swaps(&bi.num_buttons);
        }
            break;
        case ValuatorClass:
        {
            xXIValuatorInfo* ai = cast(xXIValuatorInfo*) any;

            swapl(&ai.label);
            swapl(&ai.min.integral);
            swapl(&ai.min.frac);
            swapl(&ai.max.integral);
            swapl(&ai.max.frac);
            swapl(&ai.resolution);
            swaps(&ai.number);
        }
            break;
        default: break;}

        swaps(&any.type);
        swaps(&any.length);
        swaps(&any.sourceid);

        any = cast(xXIAnyInfo*) (cast(char*) any + length * 4);
    }

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swaps(&to.num_classes);
    swaps(&to.sourceid);

}

private void SDeviceEvent(xXIDeviceEvent* from, xXIDeviceEvent* to)
{
    int i = void;
    char* ptr = void;
    char* vmask = void;

    memcpy(to, from, xEvent.sizeof + from.length * 4);

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.detail);
    swapl(&to.root);
    swapl(&to.event);
    swapl(&to.child);
    swapl(&to.root_x);
    swapl(&to.root_y);
    swapl(&to.event_x);
    swapl(&to.event_y);
    swaps(&to.buttons_len);
    swaps(&to.valuators_len);
    swaps(&to.sourceid);
    swapl(&to.mods.base_mods);
    swapl(&to.mods.latched_mods);
    swapl(&to.mods.locked_mods);
    swapl(&to.mods.effective_mods);
    swapl(&to.flags);

    ptr = cast(char*) (&to[1]);
    ptr += from.buttons_len * 4;
    vmask = ptr;                /* valuator mask */
    ptr += from.valuators_len * 4;
    for (i = 0; i < from.valuators_len * 32; i++) {
        if (mixin(BitIsOn!("vmask", "i"))) {
            swapl((cast(uint*) ptr));
            ptr += 4;
            swapl((cast(uint*) ptr));
            ptr += 4;
        }
    }
}

private void SDeviceHierarchyEvent(xXIHierarchyEvent* from, xXIHierarchyEvent* to)
{
    int i = void;
    xXIHierarchyInfo* info = void;

    *to = *from;
    memcpy(&to[1], &from[1], from.length * 4);
    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.flags);
    swaps(&to.num_info);

    info = cast(xXIHierarchyInfo*) &to[1];
    for (i = 0; i < from.num_info; i++) {
        swaps(&info.deviceid);
        swaps(&info.attachment);
        info++;
    }
}

private void SXIPropertyEvent(xXIPropertyEvent* from, xXIPropertyEvent* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.property);
}

private void SRawEvent(xXIRawEvent* from, xXIRawEvent* to)
{
    int i = void;
    FP3232* values = void;
    ubyte* mask = void;

    memcpy(to, from, (xEvent).sizeof + from.length * 4);

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.detail);

    mask = cast(ubyte*) &to[1];
    values = cast(FP3232*) (mask + from.valuators_len * 4);

    for (i = 0; i < from.valuators_len * 4 * 8; i++) {
        if (mixin(BitIsOn!("mask", "i"))) {
            /* for each bit set there are two FP3232 values on the wire, in
             * the order abcABC for data and data_raw. Here we swap as if
             * they were in aAbBcC order because it's easier and really
             * doesn't matter.
             */
            swapl(&values.integral);
            swapl(&values.frac);
            values++;
            swapl(&values.integral);
            swapl(&values.frac);
            values++;
        }
    }

    swaps(&to.valuators_len);
}

private void STouchOwnershipEvent(xXITouchOwnershipEvent* from, xXITouchOwnershipEvent* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swaps(&to.sourceid);
    swapl(&to.touchid);
    swapl(&to.flags);
    swapl(&to.root);
    swapl(&to.event);
    swapl(&to.child);
}

private void SBarrierEvent(xXIBarrierEvent* from, xXIBarrierEvent* to) {

    *to = *from;

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swapl(&to.time);
    swaps(&to.deviceid);
    swaps(&to.sourceid);
    swapl(&to.event);
    swapl(&to.root);
    swapl(&to.root_x);
    swapl(&to.root_y);

    swapl(&to.dx.integral);
    swapl(&to.dx.frac);
    swapl(&to.dy.integral);
    swapl(&to.dy.frac);
    swapl(&to.dtime);
    swapl(&to.barrier);
    swapl(&to.eventid);
}

private void SGesturePinchEvent(xXIGesturePinchEvent* from, xXIGesturePinchEvent* to)
{
    *to = *from;

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.detail);
    swapl(&to.root);
    swapl(&to.event);
    swapl(&to.child);
    swapl(&to.root_x);
    swapl(&to.root_y);
    swapl(&to.event_x);
    swapl(&to.event_y);

    swapl(&to.delta_x);
    swapl(&to.delta_y);
    swapl(&to.delta_unaccel_x);
    swapl(&to.delta_unaccel_y);
    swapl(&to.scale);
    swapl(&to.delta_angle);
    swaps(&to.sourceid);

    swapl(&to.mods.base_mods);
    swapl(&to.mods.latched_mods);
    swapl(&to.mods.locked_mods);
    swapl(&to.mods.effective_mods);
    swapl(&to.flags);
}

private void SGestureSwipeEvent(xXIGestureSwipeEvent* from, xXIGestureSwipeEvent* to)
{
    *to = *from;

    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    swaps(&to.deviceid);
    swapl(&to.time);
    swapl(&to.detail);
    swapl(&to.root);
    swapl(&to.event);
    swapl(&to.child);
    swapl(&to.root_x);
    swapl(&to.root_y);
    swapl(&to.event_x);
    swapl(&to.event_y);

    swapl(&to.delta_x);
    swapl(&to.delta_y);
    swapl(&to.delta_unaccel_x);
    swapl(&to.delta_unaccel_y);
    swaps(&to.sourceid);

    swapl(&to.mods.base_mods);
    swapl(&to.mods.latched_mods);
    swapl(&to.mods.locked_mods);
    swapl(&to.mods.effective_mods);
    swapl(&to.flags);
}

/** Event swapping function for XI2 events. */
void XI2EventSwap(xGenericEvent* from, xGenericEvent* to)
{
    switch (from.evtype) {
    case XI_Enter:
    case XI_Leave:
    case XI_FocusIn:
    case XI_FocusOut:
        SDeviceLeaveNotifyEvent(cast(xXILeaveEvent*) from, cast(xXILeaveEvent*) to);
        break;
    case XI_DeviceChanged:
        SDeviceChangedEvent(cast(xXIDeviceChangedEvent*) from,
                            cast(xXIDeviceChangedEvent*) to);
        break;
    case XI_HierarchyChanged:
        SDeviceHierarchyEvent(cast(xXIHierarchyEvent*) from,
                              cast(xXIHierarchyEvent*) to);
        break;
    case XI_PropertyEvent:
        SXIPropertyEvent(cast(xXIPropertyEvent*) from, cast(xXIPropertyEvent*) to);
        break;
    case XI_Motion:
    case XI_KeyPress:
    case XI_KeyRelease:
    case XI_ButtonPress:
    case XI_ButtonRelease:
    case XI_TouchBegin:
    case XI_TouchUpdate:
    case XI_TouchEnd:
        SDeviceEvent(cast(xXIDeviceEvent*) from, cast(xXIDeviceEvent*) to);
        break;
    case XI_TouchOwnership:
        STouchOwnershipEvent(cast(xXITouchOwnershipEvent*) from,
                             cast(xXITouchOwnershipEvent*) to);
        break;
    case XI_RawMotion:
    case XI_RawKeyPress:
    case XI_RawKeyRelease:
    case XI_RawButtonPress:
    case XI_RawButtonRelease:
    case XI_RawTouchBegin:
    case XI_RawTouchUpdate:
    case XI_RawTouchEnd:
        SRawEvent(cast(xXIRawEvent*) from, cast(xXIRawEvent*) to);
        break;
    case XI_BarrierHit:
    case XI_BarrierLeave:
        SBarrierEvent(cast(xXIBarrierEvent*) from,
                      cast(xXIBarrierEvent*) to);
        break;
    case XI_GesturePinchBegin:
    case XI_GesturePinchUpdate:
    case XI_GesturePinchEnd:
        SGesturePinchEvent(cast(xXIGesturePinchEvent*) from,
                           cast(xXIGesturePinchEvent*) to);
        break;
    case XI_GestureSwipeBegin:
    case XI_GestureSwipeUpdate:
    case XI_GestureSwipeEnd:
        SGestureSwipeEvent(cast(xXIGestureSwipeEvent*) from,
                           cast(xXIGestureSwipeEvent*) to);
        break;
    default:
        ErrorF("[Xi] Unknown event type to swap. This is a bug.\n");
        break;
    }
}

/**************************************************************************
 *
 * Record an event mask where there is no unique corresponding event type.
 * We can't call SetMaskForEvent, since that would clobber the existing
 * mask for that event.  MotionHint and ButtonMotion are examples.
 *
 * Since extension event types will never be less than 64, we can use
 * 0-63 in the EventInfo array as the "type" to be used to look up this
 * mask.  This means that the corresponding macros such as
 * DevicePointerMotionHint must have access to the same constants.
 *
 */

private void SetEventInfo(Mask mask, int constant)
{
    EventInfo[ExtEventIndex].mask = cast(uint)mask;
    EventInfo[ExtEventIndex++].type = cast(ubyte)constant;
}

/**************************************************************************
 *
 * Assign the specified mask to the specified event.
 *
 */

private void SetMaskForExtEvent(Mask mask, int event)
{
    int i = void;

    EventInfo[ExtEventIndex].mask = cast(uint)mask;
    EventInfo[ExtEventIndex++].type = cast(ubyte)event;

    if ((event < LASTEvent) || (event >= 128))
        FatalError("MaskForExtensionEvent: bogus event number");

    for (i = 0; i < MAXDEVICES; i++)
        SetMaskForEvent(i, mask, event);
}

/************************************************************************
 *
 * This function sets up extension event types and masks.
 *
 */

private void FixExtensionEvents(ExtensionEntry* extEntry)
{
    DeviceValuator = extEntry.eventBase;
    DeviceKeyPress = DeviceValuator + 1;
    DeviceKeyRelease = DeviceKeyPress + 1;
    DeviceButtonPress = DeviceKeyRelease + 1;
    DeviceButtonRelease = DeviceButtonPress + 1;
    DeviceMotionNotify = DeviceButtonRelease + 1;
    DeviceFocusIn = DeviceMotionNotify + 1;
    DeviceFocusOut = DeviceFocusIn + 1;
    ProximityIn = DeviceFocusOut + 1;
    ProximityOut = ProximityIn + 1;
    DeviceStateNotify = ProximityOut + 1;
    DeviceMappingNotify = DeviceStateNotify + 1;
    ChangeDeviceNotify = DeviceMappingNotify + 1;
    DeviceKeyStateNotify = ChangeDeviceNotify + 1;
    DeviceButtonStateNotify = DeviceKeyStateNotify + 1;
    DevicePresenceNotify = DeviceButtonStateNotify + 1;
    DevicePropertyNotify = DevicePresenceNotify + 1;

    event_base[KeyClass] = cast(ubyte)DeviceKeyPress;
    event_base[ButtonClass] = cast(ubyte)DeviceButtonPress;
    event_base[ValuatorClass] = cast(ubyte)DeviceMotionNotify;
    event_base[ProximityClass] = cast(ubyte)ProximityIn;
    event_base[FocusClass] = cast(ubyte)DeviceFocusIn;
    event_base[OtherClass] = cast(ubyte)DeviceStateNotify;

    BadDevice += extEntry.errorBase;
    BadEvent += extEntry.errorBase;
    BadMode += extEntry.errorBase;
    DeviceBusy += extEntry.errorBase;
    BadClass += extEntry.errorBase;

    SetMaskForExtEvent(KeyPressMask, DeviceKeyPress);
    SetCriticalEvent(DeviceKeyPress);

    SetMaskForExtEvent(KeyReleaseMask, DeviceKeyRelease);
    SetCriticalEvent(DeviceKeyRelease);

    SetMaskForExtEvent(ButtonPressMask, DeviceButtonPress);
    SetCriticalEvent(DeviceButtonPress);

    SetMaskForExtEvent(ButtonReleaseMask, DeviceButtonRelease);
    SetCriticalEvent(DeviceButtonRelease);

    SetMaskForExtEvent(DeviceProximityMask, ProximityIn);
    SetMaskForExtEvent(DeviceProximityMask, ProximityOut);

    SetMaskForExtEvent(DeviceStateNotifyMask, DeviceStateNotify);

    SetMaskForExtEvent(PointerMotionMask, DeviceMotionNotify);
    SetCriticalEvent(DeviceMotionNotify);

    SetEventInfo(DevicePointerMotionHintMask, _devicePointerMotionHint);
    SetEventInfo(DeviceButton1MotionMask, _deviceButton1Motion);
    SetEventInfo(DeviceButton2MotionMask, _deviceButton2Motion);
    SetEventInfo(DeviceButton3MotionMask, _deviceButton3Motion);
    SetEventInfo(DeviceButton4MotionMask, _deviceButton4Motion);
    SetEventInfo(DeviceButton5MotionMask, _deviceButton5Motion);
    SetEventInfo(DeviceButtonMotionMask, _deviceButtonMotion);

    SetMaskForExtEvent(DeviceFocusChangeMask, DeviceFocusIn);
    SetMaskForExtEvent(DeviceFocusChangeMask, DeviceFocusOut);

    SetMaskForExtEvent(DeviceMappingNotifyMask, DeviceMappingNotify);
    SetMaskForExtEvent(ChangeDeviceNotifyMask, ChangeDeviceNotify);

    SetEventInfo(DeviceButtonGrabMask, _deviceButtonGrab);
    SetEventInfo(DeviceOwnerGrabButtonMask, _deviceOwnerGrabButton);
    SetEventInfo(DevicePresenceNotifyMask, _devicePresence);
    SetMaskForExtEvent(DevicePropertyNotifyMask, DevicePropertyNotify);

    SetEventInfo(0, _noExtensionEvent);
}

/************************************************************************
 *
 * This function restores extension event types and masks to their
 * initial state.
 *
 */

private void RestoreExtensionEvents()
{
    int i = void, j = void;

    IEventBase = 0;

    for (i = 0; i < ExtEventIndex - 1; i++) {
        if ((EventInfo[i].type >= LASTEvent) && (EventInfo[i].type < 128)) {
            for (j = 0; j < MAXDEVICES; j++)
                SetMaskForEvent(j, 0, EventInfo[i].type);
        }
        EventInfo[i].mask = 0;
        EventInfo[i].type = 0;
    }
    ExtEventIndex = 0;
    DeviceValuator = 0;
    DeviceKeyPress = 1;
    DeviceKeyRelease = 2;
    DeviceButtonPress = 3;
    DeviceButtonRelease = 4;
    DeviceMotionNotify = 5;
    DeviceFocusIn = 6;
    DeviceFocusOut = 7;
    ProximityIn = 8;
    ProximityOut = 9;
    DeviceStateNotify = 10;
    DeviceMappingNotify = 11;
    ChangeDeviceNotify = 12;
    DeviceKeyStateNotify = 13;
    DeviceButtonStateNotify = 13;
    DevicePresenceNotify = 14;
    DevicePropertyNotify = 15;

    BadDevice = 0;
    BadEvent = 1;
    BadMode = 2;
    DeviceBusy = 3;
    BadClass = 4;

}

/***********************************************************************
 *
 * IResetProc.
 * Remove reply-swapping routine.
 * Remove event-swapping routine.
 *
 */

private void IResetProc(ExtensionEntry* unused)
{
    EventSwapVector[DeviceValuator] = &NotImplemented;
    EventSwapVector[DeviceKeyPress] = &NotImplemented;
    EventSwapVector[DeviceKeyRelease] = &NotImplemented;
    EventSwapVector[DeviceButtonPress] = &NotImplemented;
    EventSwapVector[DeviceButtonRelease] = &NotImplemented;
    EventSwapVector[DeviceMotionNotify] = &NotImplemented;
    EventSwapVector[DeviceFocusIn] = &NotImplemented;
    EventSwapVector[DeviceFocusOut] = &NotImplemented;
    EventSwapVector[ProximityIn] = &NotImplemented;
    EventSwapVector[ProximityOut] = &NotImplemented;
    EventSwapVector[DeviceStateNotify] = &NotImplemented;
    EventSwapVector[DeviceKeyStateNotify] = &NotImplemented;
    EventSwapVector[DeviceButtonStateNotify] = &NotImplemented;
    EventSwapVector[DeviceMappingNotify] = &NotImplemented;
    EventSwapVector[ChangeDeviceNotify] = &NotImplemented;
    EventSwapVector[DevicePresenceNotify] = &NotImplemented;
    EventSwapVector[DevicePropertyNotify] = &NotImplemented;
    RestoreExtensionEvents();

    free(xi_all_devices.name);
    free(xi_all_master_devices.name);

    XIBarrierReset();
}

/***********************************************************************
 *
 * Assign an id and type to an input device.
 *
 */

void AssignTypeAndName(DeviceIntPtr dev, Atom type, const(char)* name)
{
    dev.xinput_type = type;
    dev.name = cast(char*)XNFstrdup(name);
}

/***********************************************************************
 *
 * Make device type atoms.
 *
 */

private void MakeDeviceTypeAtoms()
{
    int i = void;

    for (i = 0; i < NUMTYPES; i++)
        dev_type[i].type = dixAddAtom(dev_type[i].name);
}

/*****************************************************************************
 *
 *	SEventIDispatch
 *
 *	Swap any events defined in this extension.
 */
enum string DO_SWAP(string func,string type) = `` ~ func ~ ` (cast(`~type~`*)from, cast(`~type~`*)to);`;

private void SEventIDispatch(xEvent* from, xEvent* to)
{
    int type = from.u.u.type & octal!"177";

    if (type == DeviceValuator)
        mixin(DO_SWAP!(`SEventDeviceValuator`, `deviceValuator`));
    else if (type == DeviceKeyPress) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceKeyRelease) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceButtonPress) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceButtonRelease) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceMotionNotify) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceFocusIn)
        mixin(DO_SWAP!(`SEventFocus`, `deviceFocus`));
    else if (type == DeviceFocusOut)
        mixin(DO_SWAP!(`SEventFocus`, `deviceFocus`));
    else if (type == ProximityIn) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == ProximityOut) {
        SKeyButtonPtrEvent(from, to);
        to.u.keyButtonPointer.pad1 = from.u.keyButtonPointer.pad1;
    }
    else if (type == DeviceStateNotify)
        mixin(DO_SWAP!(`SDeviceStateNotifyEvent`, `deviceStateNotify`));
    else if (type == DeviceKeyStateNotify)
        mixin(DO_SWAP!(`SDeviceKeyStateNotifyEvent`, `deviceKeyStateNotify`));
    else if (type == DeviceButtonStateNotify)
        mixin(DO_SWAP!(`SDeviceButtonStateNotifyEvent`, `deviceButtonStateNotify`));
    else if (type == DeviceMappingNotify)
        mixin(DO_SWAP!(`SDeviceMappingNotifyEvent`, `deviceMappingNotify`));
    else if (type == ChangeDeviceNotify)
        mixin(DO_SWAP!(`SChangeDeviceNotifyEvent`, `changeDeviceNotify`));
    else if (type == DevicePresenceNotify)
        mixin(DO_SWAP!(`SDevicePresenceNotifyEvent`, `devicePresenceNotify`));
    else if (type == DevicePropertyNotify)
        mixin(DO_SWAP!(`SDevicePropertyNotifyEvent`, `devicePropertyNotify`));
    else {
        FatalError("XInputExtension: Impossible event!\n");
    }
}

/**********************************************************************
 *
 * IExtensionInit - initialize the input extension.
 *
 //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
 * Called from InitExtensions in main() or from QueryExtension() if the
 * extension is dynamically loaded.
 *
 * This extension has several events and errors.
 *
 * XI is mandatory nowadays, so if we fail to init XI, we die.
 */

void XInputExtensionInit()
{
    ExtensionEntry* extEntry = void;

    XExtensionVersion thisversion = { XI_Present,
        SERVER_XI_MAJOR_VERSION,
        SERVER_XI_MINOR_VERSION,
    };

    if (!dixRegisterPrivateKey
        (&XIClientPrivateKeyRec, PRIVATE_CLIENT, XIClientRec.sizeof))
        FatalError("Cannot request private for XI.\n");

    if (!XIBarrierInit())
        FatalError("Could not initialize barriers.\n");

    extEntry = AddExtension(INAME, IEVENTS, IERRORS, &ProcIDispatch,
                            &ProcIDispatch, &IResetProc, &StandardMinorOpcode);
    if (extEntry) {
        // pragma(msg, EXTENSION_MAJOR_XINPUT);
        assert(extEntry.base == EXTENSION_MAJOR_XINPUT);

        IEventBase = extEntry.eventBase;
        XIVersion = thisversion;
        MakeDeviceTypeAtoms();
        RT_INPUTCLIENT = CreateNewResourceType(cast(DeleteType) &InputClientGone,
                                               "INPUTCLIENT");
        if (!RT_INPUTCLIENT)
            FatalError("Failed to add resource type for XI.\n");
        FixExtensionEvents(extEntry);
        EventSwapVector[DeviceValuator] = &SEventIDispatch;
        EventSwapVector[DeviceKeyPress] = &SEventIDispatch;
        EventSwapVector[DeviceKeyRelease] = &SEventIDispatch;
        EventSwapVector[DeviceButtonPress] = &SEventIDispatch;
        EventSwapVector[DeviceButtonRelease] = &SEventIDispatch;
        EventSwapVector[DeviceMotionNotify] = &SEventIDispatch;
        EventSwapVector[DeviceFocusIn] = &SEventIDispatch;
        EventSwapVector[DeviceFocusOut] = &SEventIDispatch;
        EventSwapVector[ProximityIn] = &SEventIDispatch;
        EventSwapVector[ProximityOut] = &SEventIDispatch;
        EventSwapVector[DeviceStateNotify] = &SEventIDispatch;
        EventSwapVector[DeviceKeyStateNotify] = &SEventIDispatch;
        EventSwapVector[DeviceButtonStateNotify] = &SEventIDispatch;
        EventSwapVector[DeviceMappingNotify] = &SEventIDispatch;
        EventSwapVector[ChangeDeviceNotify] = &SEventIDispatch;
        EventSwapVector[DevicePresenceNotify] = &SEventIDispatch;

        GERegisterExtension(EXTENSION_MAJOR_XINPUT, &XI2EventSwap);

        memset(&xi_all_devices, 0, xi_all_devices.sizeof);
        memset(&xi_all_master_devices, 0, xi_all_master_devices.sizeof);
        xi_all_devices.id = XIAllDevices;
        xi_all_devices.name = cast(char*)XNFstrdup("XIAllDevices");
        xi_all_master_devices.id = XIAllMasterDevices;
        xi_all_master_devices.name = cast(char*)XNFstrdup("XIAllMasterDevices");

        inputInfo.all_devices = &xi_all_devices;
        inputInfo.all_master_devices = &xi_all_master_devices;

        XIResetProperties();
    }
    else {
        FatalError("IExtensionInit: AddExtensions failed\n");
    }
}
