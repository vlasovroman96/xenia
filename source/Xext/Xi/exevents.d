module Xi.exevents;
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

/*
 * Copyright © 2010 Collabora Ltd.
 * Copyright © 2011 Red Hat, Inc.
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
 * Author: Daniel Stone <daniel@fooishbar.org>
 */

/********************************************************************
 *
 *  Routines to register and initialize extension input devices.
 *  This also contains ProcessOtherEvent, the routine called from DDX
 *  to route extension events.
 *
 */

import build.dix_config;

//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.geproto;
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;
// //import externs.X11.extensions.XI2proto;
// //import externs.X11.extensions.XKBproto;

import dix.cursor_priv;
import dix.devices_priv;
import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.eventconvert;
import dix.exevents_priv;
import dix.input_priv;
import dix.inpututils_priv;
import dix.resource_priv;
import dix.window_priv;
import mi.mi_priv;
import os.bug_priv;
import os.log_priv;
import os.osdep;
import xkb.xkbsrv_priv;

import include.inputstr;
import include.windowstr;
import include.miscstruct;
import include.extnsionst;
import Xi.exglobals;
import include.eventstr;
import include.scrnintstr;
import Xext.xace;
import Xi.xiquerydevice;      /* For List*Info */
import include.eventstr;
import dix.devices;
import os.log;
import os.log_priv;
import dix.dixutils;
import include.xkbstr;

import externs.X11.extensions.XI2proto;
import externs.X11.extensions.XI;
import x11.X;
import dix.events;
import dix.enterleave;
import dix.inpututils;
import os.inputthread;



enum string WID(string w) = `((` ~ w ~ `) ? ((` ~ w ~ `).drawable.id) : 0)`;
enum AllModifiersMask = ( 
	ShiftMask | LockMask | ControlMask | Mod1Mask | Mod2Mask | 
	Mod3Mask | Mod4Mask | Mod5Mask );
enum AllButtonsMask = ( 
	Button1Mask | Button2Mask | Button3Mask | Button4Mask | Button5Mask );

enum RevertToNone = cast(int)0;
enum RevertToPointerRoot = cast(int)PointerRoot;
enum RevertToFollowKeyboard = 	cast(int)3;


/*
 * Only let the given client know of core events which will affect its
 * interpretation of input events, if the client's ClientPointer (or the
 * paired keyboard) is the current device.
 */
int XIShouldNotify(ClientPtr client, DeviceIntPtr dev)
{
    DeviceIntPtr current_ptr = PickPointer(client);
    DeviceIntPtr current_kbd = GetMaster(current_ptr, KEYBOARD_OR_FLOAT);

    if (dev is current_kbd || dev is current_ptr)
        return 1;

    return 0;
}

Bool IsPointerEvent(InternalEvent* event)
{
    switch (event.any.type) {
    case ET_ButtonPress:
    case ET_ButtonRelease:
    case ET_Motion:
        /* XXX: enter/leave ?? */
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

Bool IsTouchEvent(InternalEvent* event)
{
    switch (event.any.type) {
    case ET_TouchBegin:
    case ET_TouchUpdate:
    case ET_TouchEnd:
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

Bool IsGestureEvent(InternalEvent* event)
{
    switch (event.any.type) {
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

Bool IsGestureBeginEvent(InternalEvent* event)
{
    switch (event.any.type) {
    case ET_GesturePinchBegin:
    case ET_GestureSwipeBegin:
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

Bool IsGestureEndEvent(InternalEvent* event)
{
    switch (event.any.type) {
    case ET_GesturePinchEnd:
    case ET_GestureSwipeEnd:
        return TRUE;
    default:
        break;
    }
    return FALSE;
}

/**
 * @return the device matching the deviceid of the device set in the event, or
 * NULL if the event is not an XInput event.
 */
DeviceIntPtr XIGetDevice(xEvent* xE)
{
    DeviceIntPtr pDev = null;

    if (xE.u.u.type == DeviceButtonPress ||
        xE.u.u.type == DeviceButtonRelease ||
        xE.u.u.type == DeviceMotionNotify ||
        xE.u.u.type == ProximityIn ||
        xE.u.u.type == ProximityOut || xE.u.u.type == DevicePropertyNotify) {
        int rc = void;
        int id = void;

        id = (cast(deviceKeyButtonPointer*) xE).deviceid & ~MORE_EVENTS;

        rc = dixLookupDevice(&pDev, id, serverClient, DixUnknownAccess);
        if (rc != Success)
            ErrorF("[dix] XIGetDevice failed on XACE restrictions (%d)\n", rc);
    }
    return pDev;
}

/**
 * Copy the device->key into master->key and send a mapping notify to the
 * clients if appropriate.
 * master->key needs to be allocated by the caller.
 *
 * Device is the slave device. If it is attached to a master device, we may
 * need to send a mapping notify to the client because it causes the MD
 * to change state.
 *
 * Mapping notify needs to be sent in the following cases:
 *      - different slave device on same master
 *      - different master
 *
 * XXX: They way how the code is we also send a map notify if the slave device
 * stays the same, but the master changes. This isn't really necessary though.
 *
 * XXX: this gives you funny behaviour with the ClientPointer. When a
 * MappingNotify is sent to the client, the client usually responds with a
 * GetKeyboardMapping. This will retrieve the ClientPointer's keyboard
 * mapping, regardless of which keyboard sent the last mapping notify request.
 * So depending on the CP setting, your keyboard may change layout in each
 * app...
 *
 * This code is basically the old SwitchCoreKeyboard.
 */

void CopyKeyClass(DeviceIntPtr device, DeviceIntPtr master)
{
    KeyClassPtr mk = master.key;

    if (device == master)
        return;

    mk.sourceid = device.id;

    if (!XkbDeviceApplyKeymap(master, device.key.xkbInfo.desc))
        FatalError("Couldn't pivot keymap from device to core!\n");
}

/**
 * Copies the feedback classes from device "from" into device "to". Classes
 * are duplicated (not just flipping the pointers). All feedback classes are
 * linked lists, the full list is duplicated.
 */
private void DeepCopyFeedbackClasses(DeviceIntPtr from, DeviceIntPtr to)
{
    ClassesPtr classes = void;

    if (from.intfeed) {
        IntegerFeedbackPtr* i = void; IntegerFeedbackPtr it = void;

        if (!to.intfeed) {
            classes = to.unused_classes;
            to.intfeed = classes.intfeed;
            classes.intfeed = null;
        }

        i = &to.intfeed;
        for (it = from.intfeed; it; it = it.next) {
            if (!(*i)) {
                *i = cast(_IntegerFeedbackClassRec*)cast(IntegerFeedbackClassRec*) calloc(1, IntegerFeedbackClassRec.sizeof);
                if (!(*i)) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*i).CtrlProc = it.CtrlProc;
            (*i).ctrl = it.ctrl;

            i = &(*i).next;
        }
    }
    else if (to.intfeed && !from.intfeed) {
        classes = to.unused_classes;
        classes.intfeed = to.intfeed;
        to.intfeed = null;
    }

    if (from.stringfeed) {
        StringFeedbackPtr* s = void; StringFeedbackPtr it = void;

        if (!to.stringfeed) {
            classes = to.unused_classes;
            to.stringfeed = classes.stringfeed;
            classes.stringfeed = null;
        }

        s = &to.stringfeed;
        for (it = from.stringfeed; it; it = it.next) {
            if (!(*s)) {
                *s = cast(StringFeedbackClassRec*) calloc(1, StringFeedbackClassRec.sizeof);
                if (!(*s)) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*s).CtrlProc = it.CtrlProc;
            (*s).ctrl = it.ctrl;

            s = &(*s).next;
        }
    }
    else if (to.stringfeed && !from.stringfeed) {
        classes = to.unused_classes;
        classes.stringfeed = to.stringfeed;
        to.stringfeed = null;
    }

    if (from.bell) {
        BellFeedbackPtr* b = void; BellFeedbackPtr it = void;

        if (!to.bell) {
            classes = to.unused_classes;
            to.bell = classes.bell;
            classes.bell = null;
        }

        b = &to.bell;
        for (it = from.bell; it; it = it.next) {
            if (!(*b)) {
                *b = cast(BellFeedbackClassRec*) calloc(1, BellFeedbackClassRec.sizeof);
                if (!(*b)) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*b).BellProc = it.BellProc;
            (*b).CtrlProc = it.CtrlProc;
            (*b).ctrl = it.ctrl;

            b = &(*b).next;
        }
    }
    else if (to.bell && !from.bell) {
        classes = to.unused_classes;
        classes.bell = to.bell;
        to.bell = null;
    }

    if (from.leds) {
        LedFeedbackPtr* l = void; LedFeedbackPtr it = void;

        if (!to.leds) {
            classes = to.unused_classes;
            to.leds = classes.leds;
            classes.leds = null;
        }

        l = &to.leds;
        for (it = from.leds; it; it = it.next) {
            if (!(*l)) {
                *l = cast(LedFeedbackClassRec*) calloc(1, LedFeedbackClassRec.sizeof);
                if (!(*l)) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*l).CtrlProc = it.CtrlProc;
            (*l).ctrl = it.ctrl;
            if ((*l).xkb_sli)
                XkbFreeSrvLedInfo((*l).xkb_sli);
            (*l).xkb_sli = XkbCopySrvLedInfo(from, it.xkb_sli, null, *l);

            l = &(*l).next;
        }
    }
    else if (to.leds && !from.leds) {
        classes = to.unused_classes;
        classes.leds = to.leds;
        to.leds = null;
    }
}

private void DeepCopyKeyboardClasses(DeviceIntPtr from, DeviceIntPtr to)
{
    ClassesPtr classes = void;

    /* XkbInitDevice (->XkbInitIndicatorMap->XkbFindSrvLedInfo) relies on the
     * kbdfeed to be set up properly, so let's do the feedback classes first.
     */
    if (from.kbdfeed) {
        KbdFeedbackPtr* k = void; KbdFeedbackPtr it = void;

        if (!to.kbdfeed) {
            classes = to.unused_classes;

            to.kbdfeed = classes.kbdfeed;
            if (!to.kbdfeed)
                InitKeyboardDeviceStruct(to, null, null, null);
            classes.kbdfeed = null;
        }

        k = &to.kbdfeed;
        for (it = from.kbdfeed; it; it = it.next) {
            if (!(*k)) {
                *k = cast(KbdFeedbackClassRec*) calloc(1, KbdFeedbackClassRec.sizeof);
                if (!*k) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*k).BellProc = it.BellProc;
            (*k).CtrlProc = it.CtrlProc;
            (*k).ctrl = it.ctrl;
            if ((*k).xkb_sli)
                XkbFreeSrvLedInfo((*k).xkb_sli);
            (*k).xkb_sli = XkbCopySrvLedInfo(from, it.xkb_sli, *k, null);

            k = &(*k).next;
        }
    }
    else if (to.kbdfeed && !from.kbdfeed) {
        classes = to.unused_classes;
        classes.kbdfeed = to.kbdfeed;
        to.kbdfeed = null;
    }

    if (from.key) {
        if (!to.key) {
            classes = to.unused_classes;
            to.key = classes.key;
            if (!to.key)
                InitKeyboardDeviceStruct(to, null, null, null);
            else
                classes.key = null;
        }

        CopyKeyClass(from, to);
    }
    else if (to.key && !from.key) {
        classes = to.unused_classes;
        classes.key = to.key;
        to.key = null;
    }

    /* If a SrvLedInfoPtr's flags are XkbSLI_IsDefault, the names and maps
     * pointer point into the xkbInfo->desc struct.  XkbCopySrvLedInfo
     * didn't update the pointers so we need to do it manually here.
     */
    if (to.kbdfeed) {
        KbdFeedbackPtr k = void;

        for (k = to.kbdfeed; k; k = k.next) {
            if (!k.xkb_sli)
                continue;
            if (k.xkb_sli.flags & XkbSLI_IsDefault) {
                assert(to.key);
                k.xkb_sli.names = to.key.xkbInfo.desc.names.indicators.ptr;
                k.xkb_sli.maps = to.key.xkbInfo.desc.indicators.maps.ptr;
            }
        }
    }

    /* We can't just copy over the focus class. When an app sets the focus,
     * it'll do so on the master device. Copying the SDs focus means losing
     * the focus.
     * So we only copy the focus class if the device didn't have one,
     * otherwise we leave it as it is.
     */
    if (from.focus) {
        if (!to.focus) {
            WindowPtr* oldTrace = void;

            classes = to.unused_classes;
            to.focus = classes.focus;
            if (!to.focus) {
                to.focus = cast(FocusClassRec*) calloc(1, FocusClassRec.sizeof);
                if (!to.focus)
                    FatalError("[Xi] no memory for class shift.\n");
            }
            else
                classes.focus = null;

            oldTrace = to.focus.trace;
            memcpy(to.focus, from.focus, FocusClassRec.sizeof);
            to.focus.trace = cast(WindowPtr*)reallocarray(oldTrace,
                                            to.focus.traceSize,
                                            WindowPtr.sizeof);
            if (!to.focus.trace && to.focus.traceSize)
                FatalError("[Xi] no memory for trace.\n");
            memcpy(to.focus.trace, from.focus.trace,
                   from.focus.traceSize * WindowPtr.sizeof);
            to.focus.sourceid = from.id;
        }
    }
    else if (to.focus) {
        classes = to.unused_classes;
        classes.focus = to.focus;
        to.focus = null;
    }

}

/* FIXME: this should really be shared with the InitValuatorAxisClassRec and
 * similar */
private void DeepCopyPointerClasses(DeviceIntPtr from, DeviceIntPtr to)
{
    ClassesPtr classes = void;

    /* Feedback classes must be copied first */
    if (from.ptrfeed) {
        PtrFeedbackPtr* p = void; PtrFeedbackPtr it = void;

        if (!to.ptrfeed) {
            classes = to.unused_classes;
            to.ptrfeed = classes.ptrfeed;
            classes.ptrfeed = null;
        }

        p = &to.ptrfeed;
        for (it = from.ptrfeed; it; it = it.next) {
            if (!(*p)) {
                *p = cast(PtrFeedbackClassRec*) calloc(1, PtrFeedbackClassRec.sizeof);
                if (!*p) {
                    ErrorF("[Xi] Cannot alloc memory for class copy.");
                    return;
                }
            }
            (*p).CtrlProc = it.CtrlProc;
            (*p).ctrl = it.ctrl;

            p = &(*p).next;
        }
    }
    else if (to.ptrfeed && !from.ptrfeed) {
        classes = to.unused_classes;
        classes.ptrfeed = to.ptrfeed;
        to.ptrfeed = null;
    }

    if (from.valuator) {
        ValuatorClassPtr v = void;

        if (!to.valuator) {
            classes = to.unused_classes;
            to.valuator = classes.valuator;
            if (to.valuator)
                classes.valuator = null;
        }

        v = AllocValuatorClass(to.valuator, from.valuator.numAxes);

        if (!v)
            FatalError("[Xi] no memory for class shift.\n");

        to.valuator = v;
        memcpy(v.axes, from.valuator.axes, v.numAxes * AxisInfo.sizeof);

        v.sourceid = from.id;
    }
    else if (to.valuator && !from.valuator) {
        classes = to.unused_classes;
        classes.valuator = to.valuator;
        to.valuator = null;
    }

    if (from.button) {
        if (!to.button) {
            classes = to.unused_classes;
            to.button = classes.button;
            if (!to.button) {
                to.button = cast(ButtonClassRec*) calloc(1, ButtonClassRec.sizeof);
                if (!to.button)
                    FatalError("[Xi] no memory for class shift.\n");
                to.button.numButtons = from.button.numButtons;
            }
            else
                classes.button = null;
        }

        if (from.button.xkb_acts) {
            size_t maxbuttons = max(to.button.numButtons, from.button.numButtons);
            to.button.xkb_acts = cast(XkbAction*)XNFreallocarray(to.button.xkb_acts,
                                                   maxbuttons,
                                                   XkbAction.sizeof);
            memset(to.button.xkb_acts, 0, maxbuttons * XkbAction.sizeof);
            memcpy(to.button.xkb_acts, from.button.xkb_acts,
                   from.button.numButtons * XkbAction.sizeof);
        }
        else {
            free(to.button.xkb_acts);
            to.button.xkb_acts = null;
        }

        memcpy(to.button.labels.ptr, from.button.labels.ptr,
               from.button.numButtons * Atom.sizeof);
        to.button.sourceid = from.id;
    }
    else if (to.button && !from.button) {
        classes = to.unused_classes;
        classes.button = to.button;
        to.button = null;
    }

    if (from.proximity) {
        if (!to.proximity) {
            classes = to.unused_classes;
            to.proximity = classes.proximity;
            if (!to.proximity) {
                to.proximity = cast(ProximityClassRec*) calloc(1, ProximityClassRec.sizeof);
                if (!to.proximity)
                    FatalError("[Xi] no memory for class shift.\n");
            }
            else
                classes.proximity = null;
        }
        memcpy(to.proximity, from.proximity, ProximityClassRec.sizeof);
        to.proximity.sourceid = from.id;
    }
    else if (to.proximity) {
        classes = to.unused_classes;
        classes.proximity = to.proximity;
        to.proximity = null;
    }

    if (from.touch) {
        TouchClassPtr t = void, f = void;

        if (!to.touch) {
            classes = to.unused_classes;
            to.touch = classes.touch;
            if (!to.touch) {
                int i = void;

                to.touch = cast(TouchClassRec*) calloc(1, TouchClassRec.sizeof);
                if (!to.touch)
                    FatalError("[Xi] no memory for class shift.\n");
                to.touch.num_touches = from.touch.num_touches;
                to.touch.touches = cast(TouchPointInfoRec*)calloc(to.touch.num_touches,
                                            TouchPointInfoRec.sizeof);
                for (i = 0; i < to.touch.num_touches; i++)
                    TouchInitTouchPoint(to.touch, to.valuator, i);
                if (!to.touch)
                    FatalError("[Xi] no memory for class shift.\n");
            }
            else
                classes.touch = null;
        }

        t = to.touch;
        f = from.touch;
        t.sourceid = f.sourceid;
        t.max_touches = f.max_touches;
        t.mode = f.mode;
        t.buttonsDown = f.buttonsDown;
        t.state = f.state;
        t.motionMask = f.motionMask;
        /* to->touches and to->num_touches are separate on the master,
         * don't copy */
    }
    /* Don't remove touch class if from->touch is non-existent. The to device
     * may have an active touch grab, so we need to keep the touch class record
     * around. */

    if (from.gesture) {
        if (!to.gesture) {
            classes = to.unused_classes;
            to.gesture = classes.gesture;
            if (!to.gesture) {
                if (!InitGestureClassDeviceStruct(to, from.gesture.max_touches))
                    FatalError("[Xi] no memory for class shift.\n");
            }
            else
                classes.gesture = null;
        }

        to.gesture.sourceid = from.gesture.sourceid;
        /* to->gesture->gesture is separate on the master,  don't copy */
    }
    /* Don't remove gesture class if from->gesture is non-existent. The to device
     * may have an active gesture grab, so we need to keep the gesture class record
     * around. */
}

/**
 * Copies the CONTENT of the classes of device from into the classes in device
 * to. From and to are identical after finishing.
 *
 * If to does not have classes from currently has, the classes are stored in
 * to's devPrivates system. Later, we recover it again from there if needed.
 * Saves a few memory allocations.
 */
void DeepCopyDeviceClasses(DeviceIntPtr from, DeviceIntPtr to, DeviceChangedEvent* dce)
{
    input_lock();

    /* generic feedback classes, not tied to pointer and/or keyboard */
    DeepCopyFeedbackClasses(from, to);

    if ((dce.flags & DEVCHANGE_KEYBOARD_EVENT))
        DeepCopyKeyboardClasses(from, to);
    if ((dce.flags & DEVCHANGE_POINTER_EVENT))
        DeepCopyPointerClasses(from, to);

    input_unlock();
}

/**
 * Send an XI2 DeviceChangedEvent to all interested clients.
 */
void XISendDeviceChangedEvent(DeviceIntPtr device, DeviceChangedEvent* dce)
{
    xXIDeviceChangedEvent* dcce = void;
    int rc = void;

    rc = EventToXI2(cast(InternalEvent*) dce, cast(xEvent**) &dcce);
    if (rc != Success) {
        ErrorF("[Xi] event conversion from DCE failed with code %d\n", rc);
        return;
    }

    /* we don't actually swap if there's a NULL client, swapping is done
     * later when event is delivered. */
    SendEventToAllWindows(device, XI_DeviceChangedMask, cast(xEvent*) dcce, 1);
    free(dcce);
}

private void ChangeMasterDeviceClasses(DeviceIntPtr device, DeviceChangedEvent* dce)
{
    DeviceIntPtr slave = void;
    int rc = void;

    /* For now, we don't have devices that change physically. */
    if (!InputDevIsMaster(device))
        return;

    rc = dixLookupDevice(&slave, dce.sourceid, serverClient, DixReadAccess);

    if (rc != Success)
        return;                 /* Device has disappeared */

    if (InputDevIsMaster(slave))
        return;

    if (InputDevIsFloating(slave))
        return;                 /* set floating since the event */

    if (GetMaster(slave, MASTER_ATTACHED).id != dce.masterid)
        return;                 /* not our slave anymore, don't care */

    /* FIXME: we probably need to send a DCE for the new slave now */

    device.public_.devicePrivate = slave.public_.devicePrivate;

    /* FIXME: the classes may have changed since we generated the event. */
    DeepCopyDeviceClasses(slave, device, dce);
    dce.deviceid = device.id;
    XISendDeviceChangedEvent(device, dce);
}

/**
 * Add state and motionMask to the filter for this event. The protocol
 * supports some extra masks for motion when a button is down:
 * ButtonXMotionMask and the DeviceButtonMotionMask to trigger only when at
 * least one button (or that specific button is down). These masks need to
 * be added to the filters for core/XI motion events.
 *
 * @param device The device to update the mask for
 * @param state The current button state mask
 * @param motion_mask The motion mask (DeviceButtonMotionMask or 0)
 */
private void UpdateDeviceMotionMask(DeviceIntPtr device, ushort state, Mask motion_mask)
{
    Mask mask = void;

    mask = PointerMotionMask | state | motion_mask;
    SetMaskForEvent(device.id, mask, DeviceMotionNotify);
    SetMaskForEvent(device.id, mask, MotionNotify);
}

private void IncreaseButtonCount(DeviceIntPtr dev, int key, CARD8* buttons_down, Mask* motion_mask, ushort* state)
{
    if (dev.valuator)
        dev.valuator.motionHintWindow = NullWindow;

    (*buttons_down)++;
    *motion_mask = DeviceButtonMotionMask;
    if (dev.button.map[key] <= 5)
        *state |= (Button1Mask >> 1) << dev.button.map[key];
}

private void DecreaseButtonCount(DeviceIntPtr dev, int key, CARD8* buttons_down, Mask* motion_mask, ushort* state)
{
    if (dev.valuator)
        dev.valuator.motionHintWindow = NullWindow;

    if (*buttons_down >= 1 && !--(*buttons_down))
        *motion_mask = 0;
    if (dev.button.map[key] <= 5)
        *state &= ~((Button1Mask >> 1) << dev.button.map[key]);
}

/**
 * Update the device state according to the data in the event.
 *
 * return values are
 *   DEFAULT ... process as normal
 *   DONT_PROCESS ... return immediately from caller
 */
enum DEFAULT = 0;
enum DONT_PROCESS = 1;
int UpdateDeviceState(DeviceIntPtr device, DeviceEvent* event)
{
    int i = void;
    int key = 0, last_valuator = void;

    KeyClassPtr k = null;
    ButtonClassPtr b = null;
    ValuatorClassPtr v = null;
    TouchClassPtr t = null;

    /* This event is always the first we get, before the actual events with
     * the data. However, the way how the DDX is set up, "device" will
     * actually be the slave device that caused the event.
     */
    switch (event.type) {
    case ET_DeviceChanged:
        ChangeMasterDeviceClasses(device, cast(DeviceChangedEvent*) event);
        return DONT_PROCESS;    /* event has been sent already */
    case ET_Motion:
    case ET_ButtonPress:
    case ET_ButtonRelease:
    case ET_KeyPress:
    case ET_KeyRelease:
    case ET_ProximityIn:
    case ET_ProximityOut:
    case ET_TouchBegin:
    case ET_TouchUpdate:
    case ET_TouchEnd:
        break;
    default:
        /* other events don't update the device */
        return DEFAULT;
    }

    k = device.key;
    v = device.valuator;
    b = device.button;
    t = device.touch;

    key = event.detail.key;

    /* Update device axis */
    /* Check valuators first */
    last_valuator = -1;
    for (i = 0; i < MAX_VALUATORS; i++) {
        if (mixin(BitIsOn!("&event.valuators.mask", "i"))) {
            if (!v) {
                ErrorF("[Xi] Valuators reported for non-valuator device '%s'. "
                       ~ "Ignoring event.\n", device.name);
                return DONT_PROCESS;
            }
            else if (v.numAxes <= i) {
                ErrorF("[Xi] Too many valuators reported for device '%s'. "
                       ~ "Ignoring event.\n", device.name);
                return DONT_PROCESS;
            }
            last_valuator = i;
        }
    }

    for (i = 0; i <= last_valuator && i < v.numAxes; i++) {
        /* XXX: Relative/Absolute mode */
        if (mixin(BitIsOn!("&event.valuators.mask", "i")))
            v.axisVal[i] = event.valuators.data[i];
    }

    if (event.type == ET_KeyPress) {
        if (!k)
            return DONT_PROCESS;

        /* don't allow ddx to generate multiple downs, but repeats are okay */
        if (key_is_down(device, key, KEY_PROCESSED) && !event.key_repeat)
            return DONT_PROCESS;

        if (device.valuator)
            device.valuator.motionHintWindow = NullWindow;
        set_key_down(device, key, KEY_PROCESSED);
    }
    else if (event.type == ET_KeyRelease) {
        if (!k)
            return DONT_PROCESS;

        if (!key_is_down(device, key, KEY_PROCESSED))   /* guard against duplicates */
            return DONT_PROCESS;
        if (device.valuator)
            device.valuator.motionHintWindow = NullWindow;
        set_key_up(device, key, KEY_PROCESSED);
    }
    else if (event.type == ET_ButtonPress) {
        if (!b)
            return DONT_PROCESS;

        if (button_is_down(device, key, BUTTON_PROCESSED))
            return DONT_PROCESS;

        set_button_down(device, key, BUTTON_PROCESSED);

        if (!b.map[key])
            return DONT_PROCESS;

        IncreaseButtonCount(device, key, &b.buttonsDown, &b.motionMask,
                            &b.state);
        UpdateDeviceMotionMask(device, b.state, b.motionMask);
    }
    else if (event.type == ET_ButtonRelease) {
        if (!b)
            return DONT_PROCESS;

        if (!button_is_down(device, key, BUTTON_PROCESSED))
            return DONT_PROCESS;
        if (InputDevIsMaster(device)) {
            DeviceIntPtr sd = void;

            /*
             * Leave the button down if any slave has the
             * button still down. Note that this depends on the
             * event being delivered through the slave first
             */
            for (sd = inputInfo.devices; sd; sd = sd.next) {
                if (InputDevIsMaster(sd) || GetMaster(sd, MASTER_POINTER) != device)
                    continue;
                if (!sd.button)
                    continue;
                for (i = 1; i <= sd.button.numButtons; i++)
                    if (sd.button.map[i] == key &&
                        button_is_down(sd, i, BUTTON_PROCESSED))
                        return DONT_PROCESS;
            }
        }
        set_button_up(device, key, BUTTON_PROCESSED);
        if (!b.map[key])
            return DONT_PROCESS;

        DecreaseButtonCount(device, key, &b.buttonsDown, &b.motionMask,
                            &b.state);
        UpdateDeviceMotionMask(device, b.state, b.motionMask);
    }
    else if (event.type == ET_ProximityIn)
        device.proximity.in_proximity = TRUE;
    else if (event.type == ET_ProximityOut)
        device.proximity.in_proximity = FALSE;
    else if (event.type == ET_TouchBegin) {
        mixin(BUG_RETURN_VAL!("!b || !v", "DONT_PROCESS"));
        mixin(BUG_RETURN_VAL!("!t", "DONT_PROCESS"));

        if (!b.map[key])
            return DONT_PROCESS;

        if (!(event.flags & TOUCH_POINTER_EMULATED) ||
            (event.flags & TOUCH_REPLAYING))
            return DONT_PROCESS;

        IncreaseButtonCount(device, key, &t.buttonsDown, &t.motionMask,
                            &t.state);
        UpdateDeviceMotionMask(device, t.state, DeviceButtonMotionMask);
    }
    else if (event.type == ET_TouchEnd) {
        mixin(BUG_RETURN_VAL!("!b || !v", "DONT_PROCESS"));
        mixin(BUG_RETURN_VAL!("!t", "DONT_PROCESS"));

        if (t.buttonsDown <= 0 || !b.map[key])
            return DONT_PROCESS;

        if (!(event.flags & TOUCH_POINTER_EMULATED))
            return DONT_PROCESS;

        DecreaseButtonCount(device, key, &t.buttonsDown, &t.motionMask,
                            &t.state);
        UpdateDeviceMotionMask(device, t.state, DeviceButtonMotionMask);
    }

    return DEFAULT;
}

/**
 * A client that does not have the TouchOwnership mask set may not receive a
 * TouchBegin event if there is at least one grab active.
 *
 * @return TRUE if the client selected for ownership events on the given
 * window for this device, FALSE otherwise
 */
pragma(inline, true) private Bool TouchClientWantsOwnershipEvents(ClientPtr client, DeviceIntPtr dev, WindowPtr win)
{
    InputClients* iclient = void;

    assert(mixin(wOtherInputMasks!("win")));
    mixin(nt_list_for_each_entry!("iclient", "mixin(wOtherInputMasks!(`win`)).inputClients", "next", q{
        if (dixClientForInputClients(iclient) != client)
            continue;

        return xi2mask_isset(iclient.xi2mask, dev, XI_TouchOwnership);
    }));

    return FALSE;
}

private void TouchSendOwnershipEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, int reason, XID resource)
{
    int nev = void, i = void;
    InternalEvent* tel = cast(InternalEvent*)InitEventList(GetMaximumEventsNum());

    if (!tel)
        return;

    nev = GetTouchOwnershipEvents(tel, dev, ti, cast(ubyte)reason, resource, 0);
    for (i = 0; i < nev; i++)
        mieqProcessDeviceEvent(dev, tel + i, null);

    FreeEventList(tel, GetMaximumEventsNum());
}

/**
 * Attempts to deliver a touch event to the given client.
 */
private Bool DeliverOneTouchEvent(ClientPtr client, DeviceIntPtr dev, TouchPointInfoPtr ti, GrabPtr grab, WindowPtr win, InternalEvent* ev)
{
    int err = void;
    xEvent* xi2 = void;
    Mask filter = void;
    Window child = DeepestSpriteWin(&ti.sprite).drawable.id;

    /* FIXME: owner event handling */

    /* If the client does not have the ownership mask set and is not
     * the current owner of the touch, only pretend we delivered */
    if (!grab && ti.num_grabs != 0 &&
        !TouchClientWantsOwnershipEvents(client, dev, win))
        return TRUE;

    /* If we fail here, we're going to leave a client hanging. */
    err = EventToXI2(ev, &xi2);
    if (err != Success)
        FatalError("[Xi] %s: XI2 conversion failed in %s"
                   ~ " (%d)\n", dev.name, __FUNCTION__.ptr, err);

    FixUpEventFromWindow(&ti.sprite, xi2, win, child, FALSE, XI2);
    filter = GetEventFilter(dev, xi2);
    if (XaceHookReceiveAccess(client, win, xi2, 1) != Success)
        return FALSE;
    TryClientEvents(client, dev, xi2, 1, filter, filter, NullGrab);
    free(xi2);

    /* Returning the value from TryClientEvents isn't useful, since all our
     * resource-gone cleanups will update the delivery list anyway. */
    return TRUE;
}

private void ActivateEarlyAccept(DeviceIntPtr dev, TouchPointInfoPtr ti)
{
    ClientPtr client = void;
    XID error = void;
    GrabPtr grab = ti.listeners[0].grab;

     mixin(BUG_RETURN!("ti.listeners[0].type != TOUCH_LISTENER_GRAB &&
               ti.listeners[0].type != TOUCH_LISTENER_POINTER_GRAB"));
    mixin(BUG_RETURN!("!grab"));

    client = dixClientForGrab(grab);

    if (TouchAcceptReject(client, dev, XIAcceptTouch, ti.client_id,
                          ti.listeners[0].window.drawable.id, &error) != Success)
        ErrorF("[Xi] Failed to accept touch grab after early acceptance.\n");
}

/**
 * Find the oldest touch that still has a pointer emulation client.
 *
 * Pointer emulation can only be performed for the oldest touch. Otherwise, the
 * order of events seen by the client will be wrong. This function helps us find
 * the next touch to be emulated.
 *
 * @param dev The device to find touches for.
 */
private TouchPointInfoPtr FindOldestPointerEmulatedTouch(DeviceIntPtr dev)
{
    TouchPointInfoPtr oldest = null;
    int i = void;

    for (i = 0; i < dev.touch.num_touches; i++) {
        TouchPointInfoPtr ti = dev.touch.touches + i;
        int j = void;

        if (!ti.active || !ti.emulate_pointer)
            continue;

        for (j = 0; j < ti.num_listeners; j++) {
            if (ti.listeners[j].type == TOUCH_LISTENER_POINTER_GRAB ||
                ti.listeners[j].type == TOUCH_LISTENER_POINTER_REGULAR)
                break;
        }
        if (j == ti.num_listeners)
            continue;

        if (!oldest) {
            oldest = ti;
            continue;
        }

        if (oldest.client_id - ti.client_id < UINT_MAX / 2)
            oldest = ti;
    }

    return oldest;
}

/**
 * If the current owner has rejected the event, deliver the
 * TouchOwnership/TouchBegin to the next item in the sprite stack.
 */
private void TouchPuntToNextOwner(DeviceIntPtr dev, TouchPointInfoPtr ti, TouchOwnershipEvent* ev)
{
    TouchListener* listener = &ti.listeners[0]; /* new owner */
    int accepted_early = listener.state == TOUCH_LISTENER_EARLY_ACCEPT;

    /* Deliver the ownership */
    if (listener.state == TOUCH_LISTENER_AWAITING_OWNER || accepted_early)
        DeliverTouchEvents(dev, ti, cast(InternalEvent*) ev,
                           listener.listener);
    else if (listener.state == TOUCH_LISTENER_AWAITING_BEGIN) {
        /* We can't punt to a pointer listener unless all older pointer
         * emulated touches have been seen already. */
        if ((listener.type == TOUCH_LISTENER_POINTER_GRAB ||
             listener.type == TOUCH_LISTENER_POINTER_REGULAR) &&
            ti != FindOldestPointerEmulatedTouch(dev))
            return;

        TouchEventHistoryReplay(ti, dev, listener.listener);
    }

    /* New owner has Begin/Update but not end. If touch is pending_finish,
     * emulate the TouchEnd now */
    if (ti.pending_finish) {
        TouchEmitTouchEnd(dev, ti, 0, 0);

        /* If the last owner is not a touch grab, finalise the touch, we
           won't get more correspondence on this.
         */
        if (ti.num_listeners == 1 &&
            (ti.num_grabs == 0 ||
             listener.grab.grabtype != XI2 ||
             !xi2mask_isset(listener.grab.xi2mask, dev, XI_TouchBegin))) {
            TouchEndTouch(dev, ti);
            return;
        }
    }

    if (accepted_early)
        ActivateEarlyAccept(dev, ti);
}

/**
 * Check the oldest touch to see if it needs to be replayed to its pointer
 * owner.
 *
 * Touch event propagation is paused if it hits a pointer listener while an
 * older touch with a pointer listener is waiting on accept or reject. This
 * function will restart propagation of a paused touch if needed.
 *
 * @param dev The device to check touches for.
 */
private void CheckOldestTouch(DeviceIntPtr dev)
{
    TouchPointInfoPtr oldest = FindOldestPointerEmulatedTouch(dev);

    if (oldest && oldest.listeners[0].state == TOUCH_LISTENER_AWAITING_BEGIN)
        TouchPuntToNextOwner(dev, oldest, null);
}

/**
 * Process a touch rejection.
 *
 * @param sourcedev The source device of the touch sequence.
 * @param ti The touchpoint info record.
 * @param resource The resource of the client rejecting the touch.
 * @param ev TouchOwnership event to send. Set to NULL if no event should be
 *        sent.
 */
void TouchRejected(DeviceIntPtr sourcedev, TouchPointInfoPtr ti, XID resource, TouchOwnershipEvent* ev)
{
    Bool was_owner = (resource == ti.listeners[0].listener);
    int i = void;

    /* Send a TouchEnd event to the resource being removed, but only if they
     * haven't received one yet already */
    for (i = 0; i < ti.num_listeners; i++) {
        if (ti.listeners[i].listener == resource) {
            if (ti.listeners[i].state != TOUCH_LISTENER_HAS_END)
                TouchEmitTouchEnd(sourcedev, ti, TOUCH_REJECT, resource);
            break;
        }
    }

    /* Remove the resource from the listener list, updating
     * ti->num_listeners, as well as ti->num_grabs if it was a grab. */
    TouchRemoveListener(ti, resource);

    /* If the current owner was removed and there are further listeners, deliver
     * the TouchOwnership or TouchBegin event to the new owner. */
    if (ev && ti.num_listeners > 0 && was_owner)
        TouchPuntToNextOwner(sourcedev, ti, ev);
    else if (ti.num_listeners == 0)
        TouchEndTouch(sourcedev, ti);

    CheckOldestTouch(sourcedev);
}

/**
 * Processes a TouchOwnership event, indicating a grab has accepted the touch
 * it currently owns, or a grab or selection has been removed.  Will generate
 * and send TouchEnd events to all clients removed from the delivery list, as
 * well as possibly sending the new TouchOwnership event.  May end the
 * touchpoint if it is pending finish.
 */
private void ProcessTouchOwnershipEvent(TouchOwnershipEvent* ev, DeviceIntPtr dev)
{
    TouchPointInfoPtr ti = TouchFindByClientID(dev, ev.touchid);

    if (!ti) {
        DebugF("[Xi] %s: Failed to get event %d for touchpoint %d\n",
               dev.name, ev.type, ev.touchid);
        return;
    }

    if (ev.reason == XIRejectTouch)
        TouchRejected(dev, ti, ev.resource, ev);
    else if (ev.reason == XIAcceptTouch) {
        int i = void;


        /* For pointer-emulated listeners that ungrabbed the active grab,
         * the state was forced to TOUCH_LISTENER_HAS_END. Still go
         * through the motions of ending the touch if the listener has
         * already seen the end. This ensures that the touch record is ended in
         * the server.
         */
        if (ti.listeners[0].state == TOUCH_LISTENER_HAS_END)
            TouchEmitTouchEnd(dev, ti, TOUCH_ACCEPT, ti.listeners[0].listener);

        /* The touch owner has accepted the touch.  Send TouchEnd events to
         * everyone else, and truncate the list of listeners. */
        for (i = 1; i < ti.num_listeners; i++)
            TouchEmitTouchEnd(dev, ti, TOUCH_ACCEPT, ti.listeners[i].listener);

        while (ti.num_listeners > 1)
            TouchRemoveListener(ti, ti.listeners[1].listener);
        /* Owner accepted after receiving end */
        if (ti.listeners[0].state == TOUCH_LISTENER_HAS_END)
            TouchEndTouch(dev, ti);
        else
            ti.listeners[0].state = TOUCH_LISTENER_HAS_ACCEPTED;
    }
    else {  /* this is the very first ownership event for a grab */
        DeliverTouchEvents(dev, ti, cast(InternalEvent*) ev, ev.resource);
    }
}

/**
 * Copy the event's valuator information into the touchpoint, we may need
 * this for emulated TouchEnd events.
 */
private void TouchCopyValuatorData(DeviceEvent* ev, TouchPointInfoPtr ti)
{
    int i = void;

    for (i = 0; i < mixin(ARRAY_SIZE!("ev.valuators.data")); i++)
        if (mixin(BitIsOn!("ev.valuators.mask", "i")))
            valuator_mask_set_double(ti.valuators, i, ev.valuators.data[i]);
}

/**
 * Given a touch event and a potential listener, retrieve info needed for
 * processing the event.
 *
 * @param dev The device generating the touch event.
 * @param ti The touch point info record for the touch event.
 * @param ev The touch event to process.
 * @param listener The touch event listener that may receive the touch event.
 * @param[out] client The client that should receive the touch event.
 * @param[out] win The window to deliver the event on.
 * @param[out] grab The grab to deliver the event through, if any.
 * @param[out] mask The XI 2.x event mask of the grab or selection, if any.
 * @return TRUE if an event should be delivered to the listener, FALSE
 *         otherwise.
 */
private Bool RetrieveTouchDeliveryData(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, TouchListener* listener, ClientPtr* client, WindowPtr* win, GrabPtr* grab, XI2Mask** mask)
{
    int rc = void;
    *mask = null;

    if (listener.type == TOUCH_LISTENER_GRAB ||
        listener.type == TOUCH_LISTENER_POINTER_GRAB) {
        *grab = listener.grab;

        mixin(BUG_RETURN_VAL!("!*grab", "FALSE"));

        *client = dixClientForGrab(*grab);
        *win = (*grab).window;
        *mask = (*grab).xi2mask;
    }
    else {
        rc = dixLookupResourceByType(cast(void**) win, listener.listener,
                                     listener.resource_type,
                                     serverClient, DixSendAccess);
        if (rc != Success)
            return FALSE;

        if (listener.level == XI2) {
            int evtype = void;

            if (ti.emulate_pointer &&
                listener.type == TOUCH_LISTENER_POINTER_REGULAR)
                evtype = GetXI2Type(cast(EventType)TouchGetPointerEventType(ev));
            else
                evtype = GetXI2Type(ev.any.type);

            assert(mixin(wOtherInputMasks!("*win")));

            InputClients* iclients = null;
            mixin(nt_list_for_each_entry!("iclients",
                                `mixin(wOtherInputMasks!("*win")).inputClients`, `next`, q{
                if (xi2mask_isset(iclients.xi2mask, dev, evtype))
                break;
            }));

            mixin(BUG_RETURN_VAL!("!iclients", "FALSE"));

            *mask = iclients.xi2mask;
            *client = dixClientForInputClients(iclients);
        }
        else if (listener.level == XI) {
            int xi_type = GetXIType(cast(EventType)TouchGetPointerEventType(ev));
            Mask xi_filter = event_get_filter_from_type(dev, xi_type);

            assert(mixin(wOtherInputMasks!("*win")));

            InputClients* iclients = null;
            mixin(nt_list_for_each_entry!("iclients",
                                   `mixin(wOtherInputMasks!("*win")).inputClients`, `next`, q{
                if (iclients.mask[dev.id] & xi_filter)
                break;
            }));

            mixin(BUG_RETURN_VAL!("!iclients", "FALSE"));

            *client = dixClientForInputClients(iclients);
        }
        else {
            int coretype = GetCoreType(cast(EventType)TouchGetPointerEventType(ev));
            Mask core_filter = event_get_filter_from_type(dev, coretype);
            OtherClients* oclients = void;

            /* all others */
            mixin(nt_list_for_each_entry!("oclients",
                                   `cast(OtherClients*) mixin(wOtherClients!("*win"))`, `next`, q{
                if (oclients.mask & core_filter)
                    break;
            }));

            /* if owner selected, oclients is NULL */
            *client = oclients ? dixClientForOtherClients(oclients) : dixClientForWindow(*win);
        }

        *grab = null;
    }

    return TRUE;
}

private int DeliverTouchEmulatedEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, TouchListener* listener, WindowPtr win, GrabPtr grab)
{
    InternalEvent motion = void, button = void;
    InternalEvent* ptrev = &motion;
    int nevents = void;
    DeviceIntPtr kbd = void;

    /* There may be a pointer grab on the device */
    if (!grab) {
        grab = dev.deviceGrab.grab;
        if (grab) win = grab.window;
    }

    /* We don't deliver pointer events to non-owners */
    if (!TouchResourceIsOwner(ti, listener.listener))
        return !Success;

    if (!ti.emulate_pointer)
        return !Success;

    nevents = TouchConvertToPointerEvent(ev, &motion, &button);
    mixin(BUG_RETURN_VAL!("nevents == 0", "BadValue"));

    /* Note that here we deliver only part of the events that are generated by the touch event:
     *
     * TouchBegin results in ButtonPress (motion is handled in DeliverEmulatedMotionEvent)
     * TouchUpdate results in Motion
     * TouchEnd results in ButtonRelease (motion is handled in DeliverEmulatedMotionEvent)
     */
    if (nevents > 1)
        ptrev = &button;

    kbd = GetMaster(dev, KEYBOARD_OR_FLOAT);
    event_set_state(dev, kbd, &ptrev.device_event);
    ptrev.device_event.corestate = event_get_corestate(dev, kbd);

    if (grab) {
        /* this side-steps the usual activation mechanisms, but... */
        if (ev.any.type == ET_TouchBegin && !dev.deviceGrab.grab)
            ActivatePassiveGrab(dev, grab, ptrev, ev);  /* also delivers the event */
        else {
            int deliveries = 0;

            /* 'grab' is the passive grab, but if the grab isn't active,
             * don't deliver */
            if (!dev.deviceGrab.grab)
                return !Success;

            if (grab.ownerEvents) {
                WindowPtr focus = NullWindow;
                WindowPtr sprite_win = DeepestSpriteWin(dev.spriteInfo.sprite);

                deliveries = DeliverDeviceEvents(sprite_win, ptrev, grab, focus, dev);
            }

            if (!deliveries)
                deliveries = DeliverOneGrabbedEvent(ptrev, dev, grab.grabtype);

            /* We must accept the touch sequence once a pointer listener has
             * received one event past ButtonPress. */
            if (deliveries && ev.any.type != ET_TouchBegin &&
                !(ev.device_event.flags & TOUCH_CLIENT_ID))
                TouchListenerAcceptReject(dev, ti, 0, XIAcceptTouch);

            if (ev.any.type == ET_TouchEnd &&
                ti.num_listeners == 1 &&
                !dev.button.buttonsDown &&
                dev.deviceGrab.fromPassiveGrab && GrabIsPointerGrab(grab)) {
                (*dev.deviceGrab.DeactivateGrab) (dev);
                CheckOldestTouch(dev);
                return Success;
            }
        }
    }
    else {
        GrabPtr devgrab = dev.deviceGrab.grab;
        WindowPtr sprite_win = DeepestSpriteWin(dev.spriteInfo.sprite);

        DeliverDeviceEvents(sprite_win, ptrev, grab, win, dev);
        /* FIXME: bad hack
         * Implicit passive grab activated in response to this event. Store
         * the event.
         */
        if (!devgrab && dev.deviceGrab.grab && dev.deviceGrab.implicitGrab) {
            TouchListener* l = void;
            GrabPtr g = void;

            devgrab = dev.deviceGrab.grab;
            g = AllocGrab(devgrab);
            mixin(BUG_WARN!("!g"));

            CopyPartialInternalEvent(dev.deviceGrab.sync.event, ev);

            /* The listener array has a sequence of grabs and then one event
             * selection. Implicit grab activation occurs through delivering an
             * event selection. Thus, we update the last listener in the array.
             */
            l = &ti.listeners[ti.num_listeners - 1];
            l.listener = g.resource;
            l.grab = g;
            //l->resource_type = X11_RESTYPE_NONE;

            if (devgrab.grabtype != XI2 || devgrab.type != XI_TouchBegin)
                l.type = TOUCH_LISTENER_POINTER_GRAB;
            else
                l.type = TOUCH_LISTENER_GRAB;
        }

    }
    if (ev.any.type == ET_TouchBegin)
        listener.state = TOUCH_LISTENER_IS_OWNER;
    else if (ev.any.type == ET_TouchEnd)
        listener.state = TOUCH_LISTENER_HAS_END;

    return Success;
}

private void DeliverEmulatedMotionEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev)
{
    InternalEvent motion = void;

    if (ti.num_listeners) {
        ClientPtr client = void;
        WindowPtr win = void;
        GrabPtr grab = void;
        XI2Mask* mask = void;

        if (ti.listeners[0].type != TOUCH_LISTENER_POINTER_REGULAR &&
            ti.listeners[0].type != TOUCH_LISTENER_POINTER_GRAB)
            return;

        motion.device_event = ev.device_event;
        motion.device_event.type = ET_TouchUpdate;
        motion.device_event.detail.button = 0;

        if (!RetrieveTouchDeliveryData(dev, ti, &motion,
                                       &ti.listeners[0], &client, &win, &grab,
                                       &mask))
            return;

        DeliverTouchEmulatedEvent(dev, ti, &motion, &ti.listeners[0], win, grab);
    }
    else {
        InternalEvent button = void;
        int converted = void;

        converted = TouchConvertToPointerEvent(ev, &motion, &button);

        mixin(BUG_WARN!("converted == 0"));
        if (converted)
            ProcessOtherEvent(&motion, dev);
    }
}

/**
 * Processes and delivers a TouchBegin, TouchUpdate, or a
 * TouchEnd event.
 *
 * Due to having rather different delivery semantics (see the Xi 2.2 protocol
 * spec for more information), this implements its own grab and event-selection
 * delivery logic.
 */
private void ProcessTouchEvent(InternalEvent* ev, DeviceIntPtr dev)
{
    TouchClassPtr t = dev.touch;
    TouchPointInfoPtr ti = void;
    uint touchid = void;
    int type = ev.any.type;
    int emulate_pointer = ! !(ev.device_event.flags & TOUCH_POINTER_EMULATED);
    DeviceIntPtr kbd = void;

    if (!t)
        return;

    touchid = ev.device_event.touchid;

    if (type == ET_TouchBegin && !(ev.device_event.flags & TOUCH_REPLAYING)) {
        ti = TouchBeginTouch(dev, ev.device_event.sourceid, touchid,
                             emulate_pointer);
    }
    else
        ti = TouchFindByClientID(dev, touchid);

    /* Active pointer grab */
    if (emulate_pointer && dev.deviceGrab.grab && !dev.deviceGrab.fromPassiveGrab &&
        (dev.deviceGrab.grab.grabtype == CORE ||
         dev.deviceGrab.grab.grabtype == XI ||
         !xi2mask_isset(dev.deviceGrab.grab.xi2mask, dev, XI_TouchBegin)))
    {
        /* Active pointer grab on touch point and we get a TouchEnd - claim this
         * touchpoint accepted, otherwise clients waiting for ownership will
         * wait on this touchpoint until this client ungrabs, or the cows come
         * home, whichever is earlier */
        if (ti && type == ET_TouchEnd)
            TouchListenerAcceptReject(dev, ti, 0, XIAcceptTouch);
        else if (!ti && type != ET_TouchBegin) {
            /* Under the following circumstances we create a new touch record for an
             * existing touch:
             *
             * - The touch may be pointer emulated
             * - An explicit grab is active on the device
             * - The grab is a pointer grab
             *
             * This allows for an explicit grab to receive pointer events for an already
             * active touch.
             */
            ti = TouchBeginTouch(dev, ev.device_event.sourceid, touchid,
                                 emulate_pointer);
            if (!ti) {
                DebugF("[Xi] %s: Failed to create new dix record for explicitly "
                       ~ "grabbed touchpoint %d\n",
                       dev.name, touchid);
                return;
            }

            TouchBuildSprite(dev, ti, ev);
            TouchSetupListeners(dev, ti, ev);
        }
    }

    if (!ti) {
        DebugF("[Xi] %s: Failed to get event %d for touchpoint %d\n",
               dev.name, type, touchid);
        goto out_;
    }

    /* if emulate_pointer is set, emulate the motion event right
     * here, so we can ignore it for button event emulation. TouchUpdate
     * events which _only_ emulate motion just work normally */
    if (emulate_pointer && (ev.any.type == ET_TouchBegin ||
                           (ev.any.type == ET_TouchEnd && ti.num_listeners > 0)))
        DeliverEmulatedMotionEvent(dev, ti, ev);

    if (emulate_pointer && InputDevIsMaster(dev))
        CheckMotion(&ev.device_event, dev);

    kbd = GetMaster(dev, KEYBOARD_OR_FLOAT);
    event_set_state(null, kbd, &ev.device_event);
    ev.device_event.corestate = event_get_corestate(null, kbd);

    /* Make sure we have a valid window trace for event delivery; must be
     * called after event type mutation. Touch end events are always processed
     * in order to end touch records. */
    /* FIXME: check this */
    if ((type == ET_TouchBegin &&
         !(ev.device_event.flags & TOUCH_REPLAYING) &&
         !TouchBuildSprite(dev, ti, ev)) ||
        (type != ET_TouchEnd && ti.sprite.spriteTraceGood == 0))
        return;

    TouchCopyValuatorData(&ev.device_event, ti);
    /* WARNING: the event type may change to TouchUpdate in
     * DeliverTouchEvents if a TouchEnd was delivered to a grabbing
     * owner */
    DeliverTouchEvents(dev, ti, ev, ev.device_event.resource);
    if (ev.any.type == ET_TouchEnd)
        TouchEndTouch(dev, ti);

 out_:
    if (emulate_pointer)
        UpdateDeviceState(dev, &ev.device_event);
}

private void ProcessBarrierEvent(InternalEvent* e, DeviceIntPtr dev)
{
    Mask filter = void;
    WindowPtr pWin = void;
    BarrierEvent* be = &e.barrier_event;
    xEvent* ev = void;
    int rc = void;
    GrabPtr grab = dev.deviceGrab.grab;

    if (!InputDevIsMaster(dev))
        return;

    if (dixLookupWindow(&pWin, be.window, serverClient, DixReadAccess) != Success)
        return;

    if (grab)
        be.flags |= XIBarrierDeviceIsGrabbed;

    rc = EventToXI2(e, &ev);
    if (rc != Success) {
        ErrorF("[Xi] event conversion from %s failed with code %d\n", __FUNCTION__.ptr, rc);
        return;
    }

    /* A client has a grab, deliver to this client if the grab_window is the
       barrier window.

       Otherwise, deliver normally to the client.
     */
    if (grab &&
        dixClientIdForXID(cast(XID)(be.barrierid)) == dixClientIdForXID(grab.resource) &&
        grab.window.drawable.id == be.window) {
        DeliverGrabbedEvent(e, dev, FALSE);
    } else {
        filter = GetEventFilter(dev, ev);

        DeliverEventsToWindow(dev, pWin, ev, 1,
                              filter, NullGrab);
    }
    free(ev);
}

private BOOL IsAnotherGestureActiveOnMaster(DeviceIntPtr dev, InternalEvent* ev)
{
    GestureClassPtr g = dev.gesture;
    if (g.gesture.active && g.gesture.sourceid != ev.gesture_event.sourceid) {
        return TRUE;
    }
    return FALSE;
}

/**
 * Processes and delivers a Gesture{Pinch,Swipe}{Begin,Update,End}.
 *
 * Due to having rather different delivery semantics (see the Xi 2.4 protocol
 * spec for more information), this implements its own grab and event-selection
 * delivery logic.
 */
void ProcessGestureEvent(InternalEvent* ev, DeviceIntPtr dev)
{
    GestureInfoPtr gi = void;
    DeviceIntPtr kbd = void;
    Bool deactivateGestureGrab = FALSE;
    Bool delivered = FALSE;

    if (!dev.gesture)
        return;

    if (InputDevIsMaster(dev) && IsAnotherGestureActiveOnMaster(dev, ev))
        return;

    if (IsGestureBeginEvent(ev))
        gi = GestureBeginGesture(dev, ev);
    else
        gi = GestureFindActiveByEventType(dev, ev.any.type);

    if (!gi) {
        /* This may happen if gesture is no longer active or was never started. */
        return;
    }

    kbd = GetMaster(dev, KEYBOARD_OR_FLOAT);
    event_set_state_gesture(kbd, &ev.gesture_event);

    if (IsGestureBeginEvent(ev))
        GestureSetupListener(dev, gi, ev);

    if (IsGestureEndEvent(ev) &&
            dev.deviceGrab.grab &&
            dev.deviceGrab.fromPassiveGrab &&
            GrabIsGestureGrab(dev.deviceGrab.grab))
        deactivateGestureGrab = TRUE;

    delivered = DeliverGestureEventToOwner(dev, gi, ev);

    if (delivered && !deactivateGestureGrab &&
            (IsGestureBeginEvent(ev) || IsGestureEndEvent(ev)))
        FreezeThisEventIfNeededForSyncGrab(dev, ev);

    if (IsGestureEndEvent(ev))
        GestureEndGesture(gi);

    if (deactivateGestureGrab)
        (*dev.deviceGrab.DeactivateGrab) (dev);
}

/**
 * Process DeviceEvents and DeviceChangedEvents.
 */
private void ProcessDeviceEvent(InternalEvent* ev, DeviceIntPtr device)
{
    GrabPtr grab = void;
    Bool deactivateDeviceGrab = FALSE;
    int key = 0, rootX = void, rootY = void;
    ButtonClassPtr b = void;
    int ret = 0;
    int corestate = void;
    DeviceIntPtr mouse = null, kbd = null;
    DeviceEvent* event = &ev.device_event;

    if (IsPointerDevice(device)) {
        kbd = GetMaster(device, KEYBOARD_OR_FLOAT);
        mouse = device;
        if (!kbd.key)          /* can happen with floating SDs */
            kbd = null;
    }
    else {
        mouse = GetMaster(device, POINTER_OR_FLOAT);
        kbd = device;
        if (!mouse.valuator || !mouse.button) /* may be float. SDs */
            mouse = null;
    }

    corestate = event_get_corestate(mouse, kbd);
    event_set_state(mouse, kbd, event);

    ret = UpdateDeviceState(device, event);
    if (ret == DONT_PROCESS)
        return;

    b = device.button;

    if (InputDevIsMaster(device) || InputDevIsFloating(device))
        CheckMotion(event, device);

    switch (event.type) {
    case ET_Motion:
    case ET_ButtonPress:
    case ET_ButtonRelease:
    case ET_KeyPress:
    case ET_KeyRelease:
    case ET_ProximityIn:
    case ET_ProximityOut:
        GetSpritePosition(device, &rootX, &rootY);
        event.root_x = cast(short)rootX;
        event.root_y = cast(short)rootY;
        NoticeEventTime(cast(InternalEvent*) event, device);
        event.corestate = corestate;
        key = event.detail.key;
        break;
    default:
        break;
    }

    if (DeviceEventCallback && !syncEvents.playingEvents) {
        DeviceEventInfoRec eventinfo = void;
        SpritePtr pSprite = device.spriteInfo.sprite;

        /* see comment in EnqueueEvents regarding the next three lines */
        if (ev.any.type == ET_Motion)
            ev.device_event.root = pSprite.hotPhys.pScreen.root.drawable.id;

        eventinfo.device = device;
        eventinfo.event = ev;
        CallCallbacks(&DeviceEventCallback, cast(void*) &eventinfo);
    }

    grab = device.deviceGrab.grab;

    switch (event.type) {
    case ET_KeyPress:
        /* Don't deliver focus events (e.g. from KeymapNotify when running
         * nested) to clients. */
        if (event.source_type == EVENT_SOURCE_FOCUS)
            return;
        if (!grab && CheckDeviceGrabs(device, ev, null))
            return;
        break;
    case ET_KeyRelease:
        if (grab && device.deviceGrab.fromPassiveGrab &&
            (key == device.deviceGrab.activatingKey) &&
            GrabIsKeyboardGrab(device.deviceGrab.grab))
            deactivateDeviceGrab = TRUE;
        break;
    case ET_ButtonPress:
        if (b.map[key] == 0)   /* there's no button 0 */
            return;
        event.detail.button = b.map[key];
        if (!grab && CheckDeviceGrabs(device, ev, null)) {
            /* if a passive grab was activated, the event has been sent
             * already */
            return;
        }
        break;
    case ET_ButtonRelease:
        if (b.map[key] == 0)   /* there's no button 0 */
            return;
        event.detail.button = b.map[key];
        if (grab && !b.buttonsDown &&
            device.deviceGrab.fromPassiveGrab &&
            GrabIsPointerGrab(device.deviceGrab.grab))
            deactivateDeviceGrab = TRUE;
        break;
    default:
        break;
    }

    /* Don't deliver focus events (e.g. from KeymapNotify when running
     * nested) to clients. */
    if (event.source_type != EVENT_SOURCE_FOCUS) {
        if (grab)
            DeliverGrabbedEvent(cast(InternalEvent*) event, device,
                                deactivateDeviceGrab);
        else if (device.focus && !IsPointerEvent(ev))
            DeliverFocusedEvent(device, cast(InternalEvent*) event,
                                InputDevSpriteWindow(device));
        else
            DeliverDeviceEvents(InputDevSpriteWindow(device), cast(InternalEvent*) event,
                                NullGrab, NullWindow, device);
    }

    if (deactivateDeviceGrab == TRUE) {
        (*device.deviceGrab.DeactivateGrab) (device);

        if (!InputDevIsMaster (device) && !InputDevIsFloating (device)) {
            int flags = void, num_events = 0;
            InternalEvent dce = void;

            flags = (IsPointerDevice (device)) ?
                DEVCHANGE_POINTER_EVENT : DEVCHANGE_KEYBOARD_EVENT;
            UpdateFromMaster (&dce, device, flags, &num_events);
            mixin(BUG_WARN!("num_events > 1"));

            if (num_events == 1)
                ChangeMasterDeviceClasses(GetMaster (device, MASTER_ATTACHED),
                                          &dce.changed_event);
        }

    }

    event.detail.key = key;
}

/**
 * Main device event processing function.
 * Called from when processing the events from the event queue.
 *
 */
void ProcessOtherEvent(InternalEvent* ev, DeviceIntPtr device)
{
    verify_internal_event(ev);

    switch (ev.any.type) {
    case ET_RawKeyPress:
    case ET_RawKeyRelease:
    case ET_RawButtonPress:
    case ET_RawButtonRelease:
    case ET_RawMotion:
    case ET_RawTouchBegin:
    case ET_RawTouchUpdate:
    case ET_RawTouchEnd:
        DeliverRawEvent(&ev.raw_event, device);
        break;
    case ET_TouchBegin:
    case ET_TouchUpdate:
    case ET_TouchEnd:
        ProcessTouchEvent(ev, device);
        break;
    case ET_TouchOwnership:
        /* TouchOwnership events are handled separately from the rest, as they
         * have more complex semantics. */
        ProcessTouchOwnershipEvent(&ev.touch_ownership_event, device);
        break;
    case ET_BarrierHit:
    case ET_BarrierLeave:
        ProcessBarrierEvent(ev, device);
        break;
    case ET_GesturePinchBegin:
    case ET_GesturePinchUpdate:
    case ET_GesturePinchEnd:
    case ET_GestureSwipeBegin:
    case ET_GestureSwipeUpdate:
    case ET_GestureSwipeEnd:
        ProcessGestureEvent(ev, device);
        break;
    default:
        ProcessDeviceEvent(ev, device);
        break;
    }
}

private int DeliverTouchBeginEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, TouchListener* listener, ClientPtr client, WindowPtr win, GrabPtr grab, XI2Mask* xi2mask)
{
    TouchListenerState state = void;
    int rc = Success;
    Bool has_ownershipmask = void;

    if (listener.type == TOUCH_LISTENER_POINTER_REGULAR ||
        listener.type == TOUCH_LISTENER_POINTER_GRAB) {
        rc = DeliverTouchEmulatedEvent(dev, ti, ev, listener, win, grab);
        if (rc == Success) {
            listener.state = TOUCH_LISTENER_IS_OWNER;
            /* async grabs cannot replay, so automatically accept this touch */
            if (listener.type == TOUCH_LISTENER_POINTER_GRAB &&
                dev.deviceGrab.grab &&
                dev.deviceGrab.fromPassiveGrab &&
                dev.deviceGrab.grab.pointerMode == GrabModeAsync)
                ActivateEarlyAccept(dev, ti);
        }
        goto out_;
    }

    has_ownershipmask = xi2mask_isset(xi2mask, dev, XI_TouchOwnership);

    if (TouchResourceIsOwner(ti, listener.listener) || has_ownershipmask)
        rc = DeliverOneTouchEvent(client, dev, ti, grab, win, ev);
    if (!TouchResourceIsOwner(ti, listener.listener)) {
        if (has_ownershipmask)
            state = TOUCH_LISTENER_AWAITING_OWNER;
        else
            state = TOUCH_LISTENER_AWAITING_BEGIN;
    }
    else {
        if (has_ownershipmask)
            TouchSendOwnershipEvent(dev, ti, 0, listener.listener);

        if (listener.type == TOUCH_LISTENER_REGULAR)
            state = TOUCH_LISTENER_HAS_ACCEPTED;
        else
            state = TOUCH_LISTENER_IS_OWNER;
    }
    listener.state = state;

 out_:
    return rc;
}

private int DeliverTouchEndEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, TouchListener* listener, ClientPtr client, WindowPtr win, GrabPtr grab, XI2Mask* xi2mask)
{
    int rc = Success;

    if (listener.type == TOUCH_LISTENER_POINTER_REGULAR ||
        listener.type == TOUCH_LISTENER_POINTER_GRAB) {
        /* Note: If the active grab was ungrabbed, we already changed the
         * state to TOUCH_LISTENER_HAS_END but still get here. So we mustn't
         * actually send the event.
         * This is part two of the hack in DeactivatePointerGrab
         */
        if (listener.state != TOUCH_LISTENER_HAS_END) {
            rc = DeliverTouchEmulatedEvent(dev, ti, ev, listener, win, grab);

             /* Once we send a TouchEnd to a legacy listener, we're already well
              * past the accepting/rejecting stage (can only happen on
              * GrabModeSync + replay. This listener now gets the end event,
              * and we can continue.
              */
            if (rc == Success)
                listener.state = TOUCH_LISTENER_HAS_END;
        }
        goto out_;
    }

    /* A client is waiting for the begin, don't give it a TouchEnd */
    if (listener.state == TOUCH_LISTENER_AWAITING_BEGIN) {
        listener.state = TOUCH_LISTENER_HAS_END;
        goto out_;
    }

    /* Event in response to reject */
    if (ev.device_event.flags & TOUCH_REJECT ||
        (ev.device_event.flags & TOUCH_ACCEPT && !TouchResourceIsOwner(ti, listener.listener))) {
        /* Touch has been rejected, or accepted by its owner which is not this listener */
        if (listener.state != TOUCH_LISTENER_HAS_END)
            rc = DeliverOneTouchEvent(client, dev, ti, grab, win, ev);
        listener.state = TOUCH_LISTENER_HAS_END;
    }
    else if (TouchResourceIsOwner(ti, listener.listener)) {
        Bool normal_end = !(ev.device_event.flags & TOUCH_ACCEPT);

        /* FIXME: what about early acceptance */
        if (normal_end && listener.state != TOUCH_LISTENER_HAS_END)
            rc = DeliverOneTouchEvent(client, dev, ti, grab, win, ev);

        if ((ti.num_listeners > 1 ||
             (ti.num_grabs > 0 && listener.state != TOUCH_LISTENER_HAS_ACCEPTED)) &&
            (ev.device_event.flags & (TOUCH_ACCEPT | TOUCH_REJECT)) == 0) {
            ev.any.type = ET_TouchUpdate;
            ev.device_event.flags |= TOUCH_PENDING_END;
            ti.pending_finish = TRUE;
        }

        if (normal_end)
            listener.state = TOUCH_LISTENER_HAS_END;
    }

 out_:
    return rc;
}

private int DeliverTouchEvent(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, TouchListener* listener, ClientPtr client, WindowPtr win, GrabPtr grab, XI2Mask* xi2mask)
{
    Bool has_ownershipmask = FALSE;
    int rc = Success;

    if (xi2mask)
        has_ownershipmask = xi2mask_isset(xi2mask, dev, XI_TouchOwnership);

    if (ev.any.type == ET_TouchOwnership) {
        ev.touch_ownership_event.deviceid = dev.id;
        if (!TouchResourceIsOwner(ti, listener.listener))
            goto out_;
        rc = DeliverOneTouchEvent(client, dev, ti, grab, win, ev);
        listener.state = TOUCH_LISTENER_IS_OWNER;
    }
    else
        ev.device_event.deviceid = dev.id;

    if (ev.any.type == ET_TouchBegin) {
        rc = DeliverTouchBeginEvent(dev, ti, ev, listener, client, win, grab,
                                    xi2mask);
    }
    else if (ev.any.type == ET_TouchUpdate) {
        if (listener.type == TOUCH_LISTENER_POINTER_REGULAR ||
            listener.type == TOUCH_LISTENER_POINTER_GRAB)
            DeliverTouchEmulatedEvent(dev, ti, ev, listener, win, grab);
        else if (TouchResourceIsOwner(ti, listener.listener) ||
                 has_ownershipmask)
            rc = DeliverOneTouchEvent(client, dev, ti, grab, win, ev);
    }
    else if (ev.any.type == ET_TouchEnd)
        rc = DeliverTouchEndEvent(dev, ti, ev, listener, client, win, grab,
                                  xi2mask);

 out_:
    return rc;
}

/**
 * Delivers a touch events to all interested clients.  For TouchBegin events,
 * will update ti->listeners, ti->num_listeners, and ti->num_grabs.
 * May also mutate ev (type and flags) upon successful delivery.  If
 * @resource is non-zero, will only attempt delivery to the owner of that
 * resource.
 *
 * @return TRUE if the event was delivered at least once, FALSE otherwise
 */
void DeliverTouchEvents(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, XID resource)
{
    int i = void;

    if (ev.any.type == ET_TouchBegin &&
        !(ev.device_event.flags & (TOUCH_CLIENT_ID | TOUCH_REPLAYING)))
        TouchSetupListeners(dev, ti, ev);

    TouchEventHistoryPush(ti, &ev.device_event);

    for (i = 0; i < ti.num_listeners; i++) {
        GrabPtr grab = null;
        ClientPtr client = void;
        WindowPtr win = void;
        XI2Mask* mask = void;
        TouchListener* listener = &ti.listeners[i];

        if (resource && listener.listener != resource)
            continue;

        if (!RetrieveTouchDeliveryData(dev, ti, ev, listener, &client, &win,
                                       &grab, &mask))
            continue;

        DeliverTouchEvent(dev, ti, ev, listener, client, win, grab, mask);
    }
}

/**
 * Attempts to deliver a gesture event to the given client.
 */
private Bool DeliverOneGestureEvent(ClientPtr client, DeviceIntPtr dev, GestureInfoPtr gi, GrabPtr grab, WindowPtr win, InternalEvent* ev)
{
    int err = void;
    xEvent* xi2 = void;
    Mask filter = void;
    Window child = DeepestSpriteWin(&gi.sprite).drawable.id;

    /* If we fail here, we're going to leave a client hanging. */
    err = EventToXI2(ev, &xi2);
    if (err != Success)
        FatalError("[Xi] %s: XI2 conversion failed in %s"
                   ~ " (%d)\n", dev.name, __FUNCTION__.ptr, err);

    FixUpEventFromWindow(&gi.sprite, xi2, win, child, FALSE, XI2);
    filter = GetEventFilter(dev, xi2);
    if (XaceHookReceiveAccess(client, win, xi2, 1) != Success)
        return FALSE;
    TryClientEvents(client, dev, xi2, 1, filter, filter, NullGrab);
    free(xi2);

    /* Returning the value from TryClientEvents isn't useful, since all our
     * resource-gone cleanups will update the delivery list anyway. */
    return TRUE;
}

/**
 * Given a gesture event and a potential listener, retrieve info needed for processing the event.
 *
 * @param dev The device generating the gesture event.
 * @param ev The gesture event to process.
 * @param listener The gesture event listener that may receive the gesture event.
 * @param[out] client The client that should receive the gesture event.
 * @param[out] win The window to deliver the event on.
 * @param[out] grab The grab to deliver the event through, if any.
 * @return TRUE if an event should be delivered to the listener, FALSE
 *         otherwise.
 */
private Bool RetrieveGestureDeliveryData(DeviceIntPtr dev, InternalEvent* ev, GestureListener* listener, ClientPtr* client, WindowPtr* win, GrabPtr* grab)
{
    int rc = void;
    int evtype = void;
    InputClients* iclients = null;
    *grab = null;

    if (listener.type == GESTURE_LISTENER_GRAB ||
        listener.type == GESTURE_LISTENER_NONGESTURE_GRAB) {
        *grab = listener.grab;

        mixin(BUG_RETURN_VAL!("!*grab", "FALSE"));

        *client = dixClientForGrab(*grab);
        *win = (*grab).window;
    }
    else {
        rc = dixLookupResourceByType(cast(void**) win, listener.listener, listener.resource_type,
                                     serverClient, DixSendAccess);
        if (rc != Success)
            return FALSE;

        /* note that we only will have XI2 listeners as
           listener->type == GESTURE_LISTENER_REGULAR */
        evtype = GetXI2Type(ev.any.type);

        assert(mixin(wOtherInputMasks!("*win")));
        mixin(nt_list_for_each_entry!("iclients", "mixin(wOtherInputMasks!(`*win`)).inputClients", "next", q{
            if (xi2mask_isset(iclients.xi2mask, dev, evtype))
                break;
        }));

        mixin(BUG_RETURN_VAL!("!iclients", "FALSE"));

        *client = dixClientForInputClients(iclients);
    }

    return TRUE;
}

/**
 * Delivers a gesture to the owner, if possible and needed. Returns whether
 * an event was delivered.
 */
Bool DeliverGestureEventToOwner(DeviceIntPtr dev, GestureInfoPtr gi, InternalEvent* ev)
{
    GrabPtr grab = null;
    ClientPtr client = void;
    WindowPtr win = void;

    if (!gi.has_listener || gi.listener.type == GESTURE_LISTENER_NONGESTURE_GRAB) {
        return 0;
    }

    if (!RetrieveGestureDeliveryData(dev, ev, &gi.listener, &client, &win, &grab))
        return 0;

    ev.gesture_event.deviceid = dev.id;

    return DeliverOneGestureEvent(client, dev, gi, grab, win, ev);
}

int InitProximityClassDeviceStruct(DeviceIntPtr dev)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.proximity !is null", "FALSE"));

    ProximityClassPtr proxc = cast(ProximityClassRec*) calloc(1, ProximityClassRec.sizeof);
    if (!proxc)
        return FALSE;
    proxc.sourceid = dev.id;
    proxc.in_proximity = TRUE;
    dev.proximity = proxc;
    return TRUE;
}

/**
 * Initialise the device's valuators. The memory must already be allocated,
 * this function merely inits the matching axis (specified through axnum) to
 * sane values.
 *
 * It is a condition that (minval < maxval).
 *
 * @see InitValuatorClassDeviceStruct
 */
Bool InitValuatorAxisStruct(DeviceIntPtr dev, int axnum, Atom label, int minval, int maxval, int resolution, int min_res, int max_res, int mode)
{
    AxisInfoPtr ax = void;

    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.valuator is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("axnum >= dev.valuator.numAxes", "FALSE"));
    mixin(BUG_RETURN_VAL!("minval > maxval && mode == Absolute", "FALSE"));

    ax = dev.valuator.axes + axnum;

    ax.min_value = minval;
    ax.max_value = maxval;
    ax.resolution = resolution;
    ax.min_resolution = min_res;
    ax.max_resolution = max_res;
    ax.label = label;
    ax.mode = cast(ubyte)mode;

    if (mode & OutOfProximity)
        dev.proximity.in_proximity = FALSE;

    return SetScrollValuator(dev, axnum, SCROLL_TYPE_NONE, 0, SCROLL_FLAG_NONE);
}

/**
 * Set the given axis number as a scrolling valuator.
 */
Bool SetScrollValuator(DeviceIntPtr dev, int axnum, ScrollType type, double increment, int flags)
{
    AxisInfoPtr ax = void;
    int* current_ax = void;
    InternalEvent dce = void;
    DeviceIntPtr master = void;

    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.valuator is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("axnum >= dev.valuator.numAxes", "FALSE"));

    switch (type) {
    case SCROLL_TYPE_VERTICAL:
        current_ax = &dev.valuator.v_scroll_axis;
        break;
    case SCROLL_TYPE_HORIZONTAL:
        current_ax = &dev.valuator.h_scroll_axis;
        break;
    case SCROLL_TYPE_NONE:
        ax = &dev.valuator.axes[axnum];
        ax.scroll.type = type;
        return TRUE;
    default:
        return FALSE;
    }

    if (increment == 0.0)
        return FALSE;

    if (*current_ax != -1 && axnum != *current_ax) {
        ax = &dev.valuator.axes[*current_ax];
        if (ax.scroll.type == type &&
            (flags & SCROLL_FLAG_PREFERRED) &&
            (ax.scroll.flags & SCROLL_FLAG_PREFERRED))
            return FALSE;
    }
    *current_ax = axnum;

    ax = &dev.valuator.axes[axnum];
    ax.scroll.type = type;
    ax.scroll.increment = increment;
    ax.scroll.flags = flags;

    master = GetMaster(dev, MASTER_ATTACHED);
    CreateClassesChangedEvent(&dce, master, dev,
                              DEVCHANGE_POINTER_EVENT |
                              DEVCHANGE_DEVICE_CHANGE);
    XISendDeviceChangedEvent(dev, &dce.changed_event);

    /* if the current slave is us, update the master. If not, we'll update
     * whenever the next slave switch happens anyway. CMDC sends the event
     * for us */
    if (master && master.lastSlave == dev)
        ChangeMasterDeviceClasses(master, &dce.changed_event);

    return TRUE;
}

int CheckGrabValues(ClientPtr client, GrabParameters* param)
{
    if (param.grabtype != CORE &&
        param.grabtype != XI && param.grabtype != XI2) {
        ErrorF("[Xi] grabtype is invalid. This is a bug.\n");
        return BadImplementation;
    }

    if ((param.this_device_mode != GrabModeSync) &&
        (param.this_device_mode != GrabModeAsync) &&
        (param.this_device_mode != XIGrabModeTouch)) {
        client.errorValue = cast(uint)param.this_device_mode;
        return BadValue;
    }
    if ((param.other_devices_mode != GrabModeSync) &&
        (param.other_devices_mode != GrabModeAsync) &&
        (param.other_devices_mode != XIGrabModeTouch)) {
        client.errorValue = cast(uint)param.other_devices_mode;
        return BadValue;
    }

    if (param.modifiers != AnyModifier &&
        param.modifiers != XIAnyModifier &&
        (param.modifiers & ~AllModifiersMask)) {
        client.errorValue = cast(uint)param.modifiers;
        return BadValue;
    }

    if ((param.ownerEvents != xFalse) && (param.ownerEvents != xTrue)) {
        client.errorValue = cast(uint)param.ownerEvents;
        return BadValue;
    }
    return Success;
}

int GrabButton(ClientPtr client, DeviceIntPtr dev, DeviceIntPtr modifier_device, int button, GrabParameters* param, InputLevel grabtype, GrabMask* mask)
{
    WindowPtr pWin = void, confineTo = void;
    CursorPtr cursor = void;
    GrabPtr grab = void;
    int rc = void, type = -1;
    Mask access_mode = DixGrabAccess;

    rc = CheckGrabValues(client, param);
    if (rc != Success)
        return rc;
    if (param.confineTo == None)
        confineTo = NullWindow;
    else {
        rc = dixLookupWindow(&confineTo, param.confineTo, client,
                             DixSetAttrAccess);
        if (rc != Success)
            return rc;
    }
    if (param.cursor == None)
        cursor = NullCursor;
    else {
        rc = dixLookupResourceByType(cast(void**) &cursor, param.cursor,
                                     X11_RESTYPE_CURSOR, client, DixUseAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)param.cursor;
            return rc;
        }
        access_mode |= DixForceAccess;
    }
    if (param.this_device_mode == GrabModeSync ||
        param.other_devices_mode == GrabModeSync)
        access_mode |= DixFreezeAccess;
    rc = dixCallDeviceAccessCallback(client, dev, access_mode);
    if (rc != Success)
        return rc;
    rc = dixLookupWindow(&pWin, param.grabWindow, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;

    if (grabtype == XI)
        type = DeviceButtonPress;
    else if (grabtype == XI2)
        type = XI_ButtonPress;

    grab = CreateGrab(client, dev, modifier_device, pWin, grabtype,
                      mask, cast(_GrabParameters*)param, type, cast(ubyte)button, confineTo, cursor);
    if (!grab)
        return BadAlloc;
    return AddPassiveGrabToList(client, grab);
}

/**
 * Grab the given key.
 */
int GrabKey(ClientPtr client, DeviceIntPtr dev, DeviceIntPtr modifier_device, int key, GrabParameters* param, InputLevel grabtype, GrabMask* mask)
{
    WindowPtr pWin = void;
    GrabPtr grab = void;
    KeyClassPtr k = dev.key;
    Mask access_mode = DixGrabAccess;
    int rc = void, type = -1;

    rc = CheckGrabValues(client, param);
    if (rc != Success)
        return rc;
    if ((dev.id != XIAllDevices && dev.id != XIAllMasterDevices) && k is null)
        return BadMatch;
    if (grabtype == XI) {
        if ((key > k.xkbInfo.desc.max_key_code ||
             key < k.xkbInfo.desc.min_key_code)
            && (key != AnyKey)) {
            client.errorValue = cast(uint)key;
            return BadValue;
        }
        type = DeviceKeyPress;
    }
    else if (grabtype == XI2)
        type = XI_KeyPress;

    rc = dixLookupWindow(&pWin, param.grabWindow, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    if (param.this_device_mode == GrabModeSync ||
        param.other_devices_mode == GrabModeSync)
        access_mode |= DixFreezeAccess;
    rc = dixCallDeviceAccessCallback(client, dev, access_mode);
    if (rc != Success)
        return rc;

    grab = CreateGrab(client, dev, modifier_device, pWin, grabtype,
                      mask, cast(_GrabParameters*)param, type, cast(ubyte)key, null, null);
    if (!grab)
        return BadAlloc;
    return AddPassiveGrabToList(client, grab);
}

/* Enter/FocusIn grab */
int GrabWindow(ClientPtr client, DeviceIntPtr dev, int type, GrabParameters* param, GrabMask* mask)
{
    WindowPtr pWin = void;
    CursorPtr cursor = void;
    GrabPtr grab = void;
    Mask access_mode = DixGrabAccess;
    int rc = void;

    rc = CheckGrabValues(client, param);
    if (rc != Success)
        return rc;

    rc = dixLookupWindow(&pWin, param.grabWindow, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    if (param.cursor == None)
        cursor = NullCursor;
    else {
        rc = dixLookupResourceByType(cast(void**) &cursor, param.cursor,
                                     X11_RESTYPE_CURSOR, client, DixUseAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)param.cursor;
            return rc;
        }
        access_mode |= DixForceAccess;
    }
    if (param.this_device_mode == GrabModeSync ||
        param.other_devices_mode == GrabModeSync)
        access_mode |= DixFreezeAccess;
    rc = dixCallDeviceAccessCallback(client, dev, access_mode);
    if (rc != Success)
        return rc;

    grab = CreateGrab(client, dev, dev, pWin, XI2,
                      mask, cast(_GrabParameters*)param,
                      (type == XIGrabtypeEnter) ? XI_Enter : XI_FocusIn, 0,
                      null, cursor);

    if (!grab)
        return BadAlloc;

    return AddPassiveGrabToList(client, grab);
}

/* Touch grab */
int GrabTouchOrGesture(ClientPtr client, DeviceIntPtr dev, DeviceIntPtr mod_dev, int type, GrabParameters* param, GrabMask* mask)
{
    WindowPtr pWin = void;
    GrabPtr grab = void;
    int rc = void;

    rc = CheckGrabValues(client, param);
    if (rc != Success)
        return rc;

    rc = dixLookupWindow(&pWin, param.grabWindow, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    rc = dixCallDeviceAccessCallback(client, dev, DixGrabAccess);
    if (rc != Success)
        return rc;

    grab = CreateGrab(client, dev, mod_dev, pWin, XI2,
                      mask, cast(_GrabParameters*)param, type, 0, NullWindow, NullCursor);
    if (!grab)
        return BadAlloc;

    return AddPassiveGrabToList(client, grab);
}

int SelectForWindow(DeviceIntPtr dev, WindowPtr pWin, ClientPtr client, Mask mask, Mask exclusivemasks)
{
    int mskidx = dev.id;
    int i = void, ret = void;
    Mask check = void;
    InputClientsPtr others = void;

    check = (mask & exclusivemasks);
    if (mixin(wOtherInputMasks!("pWin"))) {
        if (check & mixin(wOtherInputMasks!("pWin")).inputEvents[mskidx]) {
            /* It is illegal for two different clients to select on any of
             * the events for maskcheck. However, it is OK, for some client
             * to continue selecting on one of those events.
             */
            for (others = mixin(wOtherInputMasks!("pWin")).inputClients; others;
                 others = others.next) {
                if (!mixin(SameClient!("others", "client")) && (check &
                                                    others.mask[mskidx]))
                    return BadAccess;
            }
        }
        assert(mixin(wOtherInputMasks!("pWin")));
        for (others = mixin(wOtherInputMasks!("pWin")).inputClients; others;
             others = others.next) {
            if (mixin(SameClient!("others", "client"))) {
                check = others.mask[mskidx];
                others.mask[mskidx] = mask;
                if (mask == 0) {
                    for (i = 0; i < EMASKSIZE; i++)
                        if (i != mskidx && others.mask[i] != 0)
                            break;
                    if (i == EMASKSIZE) {
                        RecalculateDeviceDeliverableEvents(pWin);
                        if (ShouldFreeInputMasks(pWin, FALSE))
                            FreeResource(cast(uint)others.resource, X11_RESTYPE_NONE);
                        return Success;
                    }
                }
                goto maskSet;
            }
        }
    }
    check = 0;
    if ((ret = AddExtensionClient(pWin, client, mask, mskidx)) != Success)
        return ret;
 maskSet:
    if (dev.valuator)
        if ((dev.valuator.motionHintWindow == pWin) &&
            (mask & DevicePointerMotionHintMask) &&
            !(check & DevicePointerMotionHintMask) && !dev.deviceGrab.grab)
            dev.valuator.motionHintWindow = NullWindow;
    RecalculateDeviceDeliverableEvents(pWin);
    return Success;
}

private void FreeInputClient(InputClientsPtr* other)
{
    xi2mask_free(&(*other).xi2mask);
    free(*other);
    *other = null;
}

private InputClientsPtr AllocInputClient()
{
    return cast(InputClients*) calloc(1, InputClients.sizeof);
}

int AddExtensionClient(WindowPtr pWin, ClientPtr client, Mask mask, int mskidx)
{
    InputClientsPtr others = void;

    if (!MakeWindowOptional(pWin))
        return BadAlloc;
    others = AllocInputClient();
    if (!others)
        return BadAlloc;
    if (!pWin.optional.inputMasks && !MakeInputMasks(pWin))
        goto bail;
    others.xi2mask = xi2mask_new();
    if (!others.xi2mask)
        goto bail;
    others.mask[mskidx] = mask;
    others.resource = FakeClientID(client.index);
    others.next = pWin.optional.inputMasks.inputClients;
    pWin.optional.inputMasks.inputClients = others;
    if (!AddResource(cast(uint)others.resource, RT_INPUTCLIENT, cast(void*) pWin))
        goto bail;
    return Success;

 bail:
    FreeInputClient(&others);
    return BadAlloc;
}

private Bool MakeInputMasks(WindowPtr pWin)
{
    _OtherInputMasks* imasks = void;

    imasks = cast(_OtherInputMasks*) cast(_OtherInputMasks*) calloc(1, _OtherInputMasks.sizeof);
    if (!imasks)
        return FALSE;
    imasks.xi2mask = xi2mask_new();
    if (!imasks.xi2mask) {
        free(imasks);
        return FALSE;
    }
    pWin.optional.inputMasks = imasks;
    return TRUE;
}

private void FreeInputMask(OtherInputMasks** imask)
{
    xi2mask_free(&(*imask).xi2mask);
    free(*imask);
    *imask = null;
}

enum XIPropagateMask = (KeyPressMask | 
                         KeyReleaseMask | 
                         ButtonPressMask | 
                         ButtonReleaseMask | 
                         PointerMotionMask);

void RecalculateDeviceDeliverableEvents(WindowPtr pWin)
{
    InputClientsPtr others = void;
    _OtherInputMasks* inputMasks = void;        /* default: NULL */
    WindowPtr pChild = void, tmp = void;
    int i = void;

    pChild = pWin;
    while (1) {
        if ((inputMasks = mixin(wOtherInputMasks!("pChild"))) !is null) {
            xi2mask_zero(inputMasks.xi2mask, -1);
            for (others = inputMasks.inputClients; others;
                 others = others.next) {
                for (i = 0; i < EMASKSIZE; i++)
                    inputMasks.inputEvents[i] |= others.mask[i];
                xi2mask_merge(inputMasks.xi2mask, others.xi2mask);
            }
            for (i = 0; i < EMASKSIZE; i++)
                inputMasks.deliverableEvents[i] = inputMasks.inputEvents[i];
            for (tmp = pChild.parent; tmp; tmp = tmp.parent)
                if (mixin(wOtherInputMasks!("tmp")))
                    for (i = 0; i < EMASKSIZE; i++)
                        inputMasks.deliverableEvents[i] |=
                            (mixin(wOtherInputMasks!("tmp")).deliverableEvents[i]
                             & ~inputMasks.dontPropagateMask[i] &
                             XIPropagateMask);
        }
        if (pChild.firstChild) {
            pChild = pChild.firstChild;
            continue;
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            break;
        pChild = pChild.nextSib;
    }
}

int InputClientGone(WindowPtr pWin, XID id)
{
    InputClientsPtr other = void, prev = void;

    if (!mixin(wOtherInputMasks!("pWin")))
        return Success;
    prev = null;
    for (other = mixin(wOtherInputMasks!("pWin")).inputClients; other;
         other = other.next) {
        if (other.resource == id) {
            if (prev) {
                prev.next = other.next;
                FreeInputClient(&other);
            }
            else if (!(other.next)) {
                if (ShouldFreeInputMasks(pWin, TRUE)) {
                    OtherInputMasks* mask = mixin(wOtherInputMasks!("pWin"));

                    mask.inputClients = other.next;
                    FreeInputMask(&mask);
                    pWin.optional.inputMasks = cast(OtherInputMasks*) null;
                    CheckWindowOptionalNeed(pWin);
                    FreeInputClient(&other);
                }
                else {
                    other.resource = dixAllocServerXID();
                    if (!AddResource(cast(uint)other.resource, RT_INPUTCLIENT,
                                     cast(void*) pWin))
                        return BadAlloc;
                }
            }
            else {
                mixin(wOtherInputMasks!("pWin")).inputClients = other.next;
                FreeInputClient(&other);
            }
            RecalculateDeviceDeliverableEvents(pWin);
            return Success;
        }
        prev = other;
    }
    FatalError("client not on device event list");
    assert(0);
}

/**
 * Search for window in each touch trace for each device. Remove the window
 * and all its subwindows from the trace when found. The initial window
 * order is preserved.
 */
void WindowGone(WindowPtr win)
{
    DeviceIntPtr dev = void;

    for (dev = inputInfo.devices; dev; dev = dev.next) {
        TouchClassPtr t = dev.touch;
        int i = void;

        if (!t)
            continue;

        for (i = 0; i < t.num_touches; i++) {
            SpritePtr sprite = &t.touches[i].sprite;
            int j = void;

            for (j = 0; j < sprite.spriteTraceGood; j++) {
                if (sprite.spriteTrace[j] == win) {
                    sprite.spriteTraceGood = j;
                    break;
                }
            }
        }
    }
}

int SendEvent(ClientPtr client, DeviceIntPtr d, Window dest, Bool propagate, xEvent* ev, Mask mask, int count)
{
    WindowPtr pWin = void;
    WindowPtr effectiveFocus = NullWindow;      /* only set if dest==InputFocus */
    WindowPtr spriteWin = InputDevSpriteWindow(d);

    if (dest == PointerWindow)
        pWin = spriteWin;
    else if (dest == InputFocus) {
        WindowPtr inputFocus = void;

        if (!d.focus)
            inputFocus = spriteWin;
        else
            inputFocus = d.focus.win;

        if (inputFocus == FollowKeyboardWin)
            inputFocus = inputInfo.keyboard.focus.win;

        if (inputFocus == NoneWin)
            return Success;

        /* If the input focus is PointerRootWin, send the event to where
         * the pointer is if possible, then perhaps propagate up to root. */
        if (inputFocus == PointerRootWin)
            inputFocus = InputDevCurrentRootWindow(d);

        if (WindowIsParent(inputFocus, spriteWin)) {
            effectiveFocus = inputFocus;
            pWin = spriteWin;
        }
        else
            effectiveFocus = pWin = inputFocus;
    }
    else
        dixLookupWindow(&pWin, dest, client, DixSendAccess);
    if (!pWin)
        return BadWindow;
    if ((propagate != xFalse) && (propagate != xTrue)) {
        client.errorValue = cast(uint)propagate;
        return BadValue;
    }
    ev.u.u.type |= 0x80;
    if (propagate) {
        for (; pWin; pWin = pWin.parent) {
            if (DeliverEventsToWindow(d, pWin, ev, count, mask, NullGrab))
                return Success;
            if (pWin == effectiveFocus)
                return Success;
            if (mixin(wOtherInputMasks!("pWin")))
                mask &= ~mixin(wOtherInputMasks!("pWin")).dontPropagateMask[d.id];
            if (!mask)
                break;
        }
    }
    else if (!XaceHookSendAccess(client, null, pWin, ev, count))
        DeliverEventsToWindow(d, pWin, ev, count, mask, NullGrab);
    return Success;
}

int SetButtonMapping(ClientPtr client, DeviceIntPtr dev, int nElts, BYTE* map)
{
    int i = void;
    ButtonClassPtr b = dev.button;

    if (b is null)
        return BadMatch;

    if (nElts != b.numButtons) {
        client.errorValue = cast(uint)nElts;
        return BadValue;
    }
    if (BadDeviceMap(&map[0], nElts, 1, 255, &client.errorValue))
        return BadValue;
    for (i = 0; i < nElts; i++)
        if ((b.map[i + 1] != map[i]) && mixin(BitIsOn!("b.down", "i + 1")))
            return MappingBusy;
    for (i = 0; i < nElts; i++)
        b.map[i + 1] = map[i];
    return Success;
}

int ChangeKeyMapping(ClientPtr client, DeviceIntPtr dev, uint len, int type, KeyCode firstKeyCode, CARD8 keyCodes, CARD8 keySymsPerKeyCode, KeySym* map)
{
    KeySymsRec keysyms = void;
    KeyClassPtr k = dev.key;

    if (k is null)
        return BadMatch;

    if (len != (keyCodes * keySymsPerKeyCode))
        return BadLength;

    if ((firstKeyCode < k.xkbInfo.desc.min_key_code) ||
        (firstKeyCode + keyCodes - 1 > k.xkbInfo.desc.max_key_code)) {
        client.errorValue = cast(uint)firstKeyCode;
        return BadValue;
    }
    if (keySymsPerKeyCode == 0) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }
    keysyms.minKeyCode = firstKeyCode;
    keysyms.maxKeyCode = cast(ubyte)(firstKeyCode + keyCodes - 1);
    keysyms.mapWidth = keySymsPerKeyCode;
    keysyms.map = map;

    XkbApplyMappingChange(dev, &keysyms, firstKeyCode, keyCodes, null,
                          serverClient);

    return Success;
}

private void DeleteDeviceFromAnyExtEvents(WindowPtr pWin, DeviceIntPtr dev)
{
    WindowPtr parent = void;

    /* Deactivate any grabs performed on this window, before making
     * any input focus changes.
     * Deactivating a device grab should cause focus events. */

    if (dev.deviceGrab.grab && (dev.deviceGrab.grab.window == pWin))
        (*dev.deviceGrab.DeactivateGrab) (dev);

    /* If the focus window is a root window (ie. has no parent)
     * then don't delete the focus from it. */

    if (dev.focus && (pWin == dev.focus.win) && (pWin.parent != NullWindow)) {
        int focusEventMode = NotifyNormal;

        /* If a grab is in progress, then alter the mode of focus events. */

        if (dev.deviceGrab.grab)
            focusEventMode = NotifyWhileGrabbed;

        switch (dev.focus.revert) {
        case RevertToNone:
            if (!ActivateFocusInGrab(dev, pWin, NoneWin))
                DoFocusEvents(dev, pWin, NoneWin, focusEventMode);
            dev.focus.win = NoneWin;
            dev.focus.traceGood = 0;
            break;
        case x11.X.RevertToParent:
            parent = pWin;
            do {
                parent = parent.parent;
                dev.focus.traceGood--;
            }
            while (!parent.realized);
            if (!ActivateFocusInGrab(dev, pWin, parent))
                DoFocusEvents(dev, pWin, parent, focusEventMode);
            dev.focus.win = parent;
            dev.focus.revert = RevertToNone;
            break;
        case RevertToPointerRoot:
            if (!ActivateFocusInGrab(dev, pWin, PointerRootWin))
                DoFocusEvents(dev, pWin, PointerRootWin, focusEventMode);
            dev.focus.win = PointerRootWin;
            dev.focus.traceGood = 0;
            break;
        case RevertToFollowKeyboard:
        {
            DeviceIntPtr kbd = GetMaster(dev, MASTER_KEYBOARD);

            if (!kbd || (kbd == dev && kbd != inputInfo.keyboard))
                kbd = inputInfo.keyboard;
            if (kbd.focus.win) {
                if (!ActivateFocusInGrab(dev, pWin, kbd.focus.win))
                    DoFocusEvents(dev, pWin, kbd.focus.win, focusEventMode);
                dev.focus.win = FollowKeyboardWin;
                dev.focus.traceGood = 0;
            }
            else {
                if (!ActivateFocusInGrab(dev, pWin, NoneWin))
                    DoFocusEvents(dev, pWin, NoneWin, focusEventMode);
                dev.focus.win = NoneWin;
                dev.focus.traceGood = 0;
            }
        }
            break;
        default: break;}
    }

    if (dev.valuator)
        if (dev.valuator.motionHintWindow == pWin)
            dev.valuator.motionHintWindow = NullWindow;
}

void DeleteWindowFromAnyExtEvents(WindowPtr pWin, Bool freeResources)
{
    int i = void;
    DeviceIntPtr dev = void;
    InputClientsPtr ic = void;
    _OtherInputMasks* inputMasks = void;

    for (dev = inputInfo.devices; dev; dev = dev.next) {
        DeleteDeviceFromAnyExtEvents(pWin, dev);
    }

    for (dev = inputInfo.off_devices; dev; dev = dev.next)
        DeleteDeviceFromAnyExtEvents(pWin, dev);

    if (freeResources)
        while ((inputMasks = mixin(wOtherInputMasks!("pWin"))) !is null) {
            ic = inputMasks.inputClients;
            for (i = 0; i < EMASKSIZE; i++)
                inputMasks.dontPropagateMask[i] = 0;
            FreeResource(cast(uint)ic.resource, X11_RESTYPE_NONE);
        }
}

int MaybeSendDeviceMotionNotifyHint(deviceKeyButtonPointer* pEvents, Mask mask)
{
    DeviceIntPtr dev = void;

    dixLookupDevice(&dev, pEvents.deviceid & DEVICE_BITS, serverClient,
                    DixReadAccess);
    if (!dev)
        return 0;

    if (pEvents.type == DeviceMotionNotify) {
        if (mask & DevicePointerMotionHintMask) {
            if (mixin(WID!(`dev.valuator.motionHintWindow`)) == pEvents.event) {
                return 1;       /* don't send, but pretend we did */
            }
            pEvents.detail = NotifyHint;
        }
        else {
            pEvents.detail = NotifyNormal;
        }
    }
    return 0;
}

void CheckDeviceGrabAndHintWindow(WindowPtr pWin, int type, deviceKeyButtonPointer* xE, GrabPtr grab, ClientPtr client, Mask deliveryMask)
{
    DeviceIntPtr dev = void;

    dixLookupDevice(&dev, xE.deviceid & DEVICE_BITS, serverClient,
                    DixGrabAccess);
    if (!dev)
        return;

    if (type == DeviceMotionNotify)
        dev.valuator.motionHintWindow = pWin;
    else if ((type == DeviceButtonPress) && (!grab) &&
             (deliveryMask & DeviceButtonGrabMask)) {
        GrabPtr tempGrab = void;

        tempGrab = AllocGrab(null);
        if (!tempGrab)
            return;

        tempGrab.device = dev;
        tempGrab.resource = client.clientAsMask;
        tempGrab.window = pWin;
        tempGrab.ownerEvents =
            (deliveryMask & DeviceOwnerGrabButtonMask) ? TRUE : FALSE;
        tempGrab.eventMask = deliveryMask;
        tempGrab.keyboardMode = GrabModeAsync;
        tempGrab.pointerMode = GrabModeAsync;
        tempGrab.confineTo = NullWindow;
        tempGrab.cursor = NullCursor;
        tempGrab.next = null;
        (*dev.deviceGrab.ActivateGrab) (dev, tempGrab, currentTime, TRUE);
        FreeGrab(tempGrab);
    }
}

private Mask DeviceEventMaskForClient(DeviceIntPtr dev, WindowPtr pWin, ClientPtr client)
{
    InputClientsPtr other = void;

    if (!mixin(wOtherInputMasks!("pWin")))
        return 0;
    for (other = mixin(wOtherInputMasks!("pWin")).inputClients; other;
         other = other.next) {
        if (mixin(SameClient!("other", "client")))
            return other.mask[dev.id];
    }
    return 0;
}

void MaybeStopDeviceHint(DeviceIntPtr dev, ClientPtr client)
{
    WindowPtr pWin = void;
    GrabPtr grab = dev.deviceGrab.grab;

    pWin = dev.valuator.motionHintWindow;

    if ((grab && mixin(SameClient!("grab", "client")) &&
         ((grab.eventMask & DevicePointerMotionHintMask) ||
          (grab.ownerEvents &&
           (DeviceEventMaskForClient(dev, pWin, client) &
            DevicePointerMotionHintMask)))) ||
        (!grab &&
         (DeviceEventMaskForClient(dev, pWin, client) &
          DevicePointerMotionHintMask)))
        dev.valuator.motionHintWindow = NullWindow;
}

int DeviceEventSuppressForWindow(WindowPtr pWin, ClientPtr client, Mask mask, int maskndx)
{
    _OtherInputMasks* inputMasks = mixin(wOtherInputMasks!("pWin"));

    if (mask & ~XIPropagateMask) {
        client.errorValue = cast(uint)mask;
        return BadValue;
    }

    if (mask == 0) {
        if (inputMasks)
            inputMasks.dontPropagateMask[maskndx] = mask;
    }
    else {
        if (!inputMasks) {
            int ret = AddExtensionClient(pWin, client, 0, 0);

            if (ret != Success)
                return ret;
            inputMasks = mixin(wOtherInputMasks!("pWin"));
            mixin(BUG_RETURN_VAL!("!inputMasks", "BadAlloc"));
        }
        inputMasks.dontPropagateMask[maskndx] = mask;
    }
    RecalculateDeviceDeliverableEvents(pWin);
    if (ShouldFreeInputMasks(pWin, FALSE)) {
        mixin(BUG_RETURN_VAL!("!inputMasks", "BadImplementation"));
        mixin(BUG_RETURN_VAL!("!inputMasks.inputClients", "BadImplementation"));
        FreeResource(cast(uint)inputMasks.inputClients.resource, X11_RESTYPE_NONE);
    }
    return Success;
}

Bool ShouldFreeInputMasks(WindowPtr pWin, Bool ignoreSelectedEvents)
{
    int i = void;
    Mask allInputEventMasks = 0;
    _OtherInputMasks* inputMasks = mixin(wOtherInputMasks!("pWin"));

    for (i = 0; i < EMASKSIZE; i++)
        allInputEventMasks |= inputMasks.dontPropagateMask[i];
    if (!ignoreSelectedEvents)
        for (i = 0; i < EMASKSIZE; i++)
            allInputEventMasks |= inputMasks.inputEvents[i];
    if (allInputEventMasks == 0)
        return TRUE;
    else
        return FALSE;
}

/***********************************************************************
 *
 * Walk through the window tree, finding all clients that want to know
 * about the Event.
 *
 */

private void FindInterestedChildren(DeviceIntPtr dev, WindowPtr p1, Mask mask, xEvent* ev, int count)
{
    WindowPtr p2 = void;

    while (p1) {
        p2 = p1.firstChild;
        DeliverEventsToWindow(dev, p1, ev, count, mask, NullGrab);
        FindInterestedChildren(dev, p2, mask, ev, count);
        p1 = p1.nextSib;
    }
}

/***********************************************************************
 *
 * Send an event to interested clients in all windows on all screens.
 *
 */

void SendEventToAllWindows(DeviceIntPtr dev, Mask mask, xEvent* ev, int count)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        WindowPtr pWin = walkScreen.root;
        if (!pWin)
            continue;
        DeliverEventsToWindow(dev, pWin, ev, count, mask, NullGrab);
        FindInterestedChildren(dev, pWin.firstChild, mask, ev, count);
    });
}

/**
 * Set the XI2 mask for the given client on the given window.
 * @param dev The device to set the mask for.
 * @param win The window to set the mask on.
 * @param client The client setting the mask.
 * @param len Number of bytes in mask.
 * @param mask Event mask in the form of (1 << eventtype)
 */
int XISetEventMask(DeviceIntPtr dev, WindowPtr win, ClientPtr client, uint len, ubyte* mask)
{
    OtherInputMasks* masks = void;
    InputClientsPtr others = null;

    masks = mixin(wOtherInputMasks!("win"));
    if (masks) {
        for (others = mixin(wOtherInputMasks!("win")).inputClients; others;
             others = others.next) {
            if (mixin(SameClient!("others", "client"))) {
                xi2mask_zero(others.xi2mask, dev.id);
                break;
            }
        }
    }

    if (len && !others) {
        if (AddExtensionClient(win, client, 0, 0) != Success)
            return BadAlloc;
        assert(mixin(wOtherInputMasks!("win")));
        others = mixin(wOtherInputMasks!("win")).inputClients;
    }

    if (others) {
        xi2mask_zero(others.xi2mask, dev.id);
        len = cast(uint)min(len, xi2mask_mask_size(others.xi2mask));
    }

    if (len) {
        assert(others);
        xi2mask_set_one_mask(others.xi2mask, dev.id, mask, len);
    }

    RecalculateDeviceDeliverableEvents(win);

    return Success;
}
