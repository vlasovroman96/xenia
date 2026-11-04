module Xext.xtest;
@nogc nothrow:
extern(C): __gshared:
/*

   Copyright 1992, 1998  The Open Group

   Permission to use, copy, modify, distribute, and sell this software and its
   documentation for any purpose is hereby granted without fee, provided that
   the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
   IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
   OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
   OTHER DEALINGS IN THE SOFTWARE.

   Except as contained in this notice, the name of The Open Group shall
   not be used in advertising or otherwise to promote the sale, use or
   other dealings in this Software without prior written authorization
   from The Open Group.

 */

import std.conv;

import build.dix_config;

//import x11.X;
//import x11.Xproto;
//import externs.X11.Xatom;
// //import externs.X11.extensions.xtestproto;
import externs.X11.extensions.XI;
// // //import externs.X11.extensions.XIproto;

import dix.input_priv;
import dix.dix_priv;
import dix.exevents_priv;
import dix.inpututils_priv;
import dix.request_priv;
import dix.screensaver_priv;
import dix.window_priv;
import mi.mi_priv;
import mi.mipointer_priv;
import miext.extinit_priv;
import os.client_priv;
import os.osdep;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import include.misc;
import include.os;
import dix.dixstruct_priv;
import include.windowstr;
import include.inputstr;
import include.scrnintstr;
import Xext.sleepuntil;
import include.xkbsrv;
import include.xkbsrv;
import Xi.exglobals;
import mi.mipointer;
import include.xserver_properties;
import dix.events;
import externs.X11.extensions.xtestproto;
import externs.X11.extensions.xtestconst;
import dix.dixutils;
import std.conv;
import os.log;
import externs.gnu;
import externs.X11.Xatom;
import dix.extension;
import dix.devices;
import Xi.xiproperty;
import os.io;
import dix.events;
import dix.timestamp;
import dix.inpututils;
import dix.dispatch;
import dix.window;

enum XTestCurrentCursor = cast(Cursor)1;

Bool noTestExtensions = FALSE;

/* XTest events are sent during request processing and may be interrupted by
 * a SIGIO. We need a separate event list to avoid events overwriting each
 * other's memory.
 */
private InternalEvent* xtest_evlist;

/**
 * xtestpointer
 * is the virtual pointer for XTest. It is the first slave
 * device of the VCP.
 * xtestkeyboard
 * is the virtual keyboard for XTest. It is the first slave
 * device of the VCK
 *
 * Neither of these devices can be deleted.
 */
DeviceIntPtr xtestpointer, xtestkeyboard;



private int ProcXTestGetVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXTestGetVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!"minorVersion");

    xXTestGetVersionReply reply = {
        majorVersion: XTestMajorVersion,
        minorVersion: XTestMinorVersion
    };

    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXTestCompareCursor(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXTestCompareCursorReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"cursor");

    WindowPtr pWin = void;
    CursorPtr pCursor = void;
    DeviceIntPtr ptr = PickPointer(client);

    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    if (!ptr) {
        return BadAccess;
    }

    if (stuff.cursor == None) {
        pCursor = NullCursor;
    } else if (stuff.cursor == XTestCurrentCursor) {
        pCursor = InputDevGetSpriteCursor(ptr);
    } else {
        rc = dixLookupResourceByType(cast(void**) &pCursor, stuff.cursor,
                                     X11_RESTYPE_CURSOR, client, DixReadAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.cursor;
            return rc;
        }
    }

    xXTestCompareCursorReply reply = {
        same: (mixin(wCursor!("pWin")) is pCursor)
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

void XTestDeviceSendEvents(DeviceIntPtr dev, int type, int detail, int flags, const(ValuatorMask)* mask)
{
    int nevents = 0;
    int i = void;

    switch (type) {
    case MotionNotify:
        nevents = GetPointerEvents(xtest_evlist, dev, type, 0, flags, mask);
        break;
    case ButtonPress:
    case ButtonRelease:
        nevents = GetPointerEvents(xtest_evlist, dev, type, detail, flags, mask);
        break;
    case KeyPress:
    case KeyRelease:
        nevents =
            GetKeyboardEvents(xtest_evlist, dev, type, detail);
        break;
    default: break;}

    for (i = 0; i < nevents; i++)
        mieqProcessDeviceEvent(dev, &xtest_evlist[i], miPointerGetScreen(inputInfo.pointer));
}

private int ProcXTestFakeInput(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_NO_CHECK!("xXTestFakeInputReq"));

    if (client.swapped) {
        int n = XTestSwapFakeInput(client, cast(xReq*)stuff);
        if (n != Success) {
            return n;
        }
    }

    int nev = void, n = void, type = void;
    xEvent* ev = void;
    DeviceIntPtr dev = null;
    WindowPtr root = void;
    Bool extension = FALSE;
    ValuatorMask mask = void;
    int[MAX_VALUATORS] valuators = 0;
    int numValuators = 0;
    int firstValuator = 0;
    int base = 0;
    int flags = 0;
    int need_ptr_update = 1;

    nev = cast(uint)(cast(uint)(client.req_len << 2) - xReq.sizeof);
    if ((nev % xEvent.sizeof) || !nev)
        return BadLength;
    nev /= xEvent.sizeof;
    UpdateCurrentTime();
    ev = cast(xEvent*) &(cast(xReq*) stuff)[1];
    type = ev.u.u.type & octal!"177";

    if (type >= EXTENSION_EVENT_BASE) {
        extension = TRUE;

        /* check device */
        int rc = dixLookupDevice(&dev, stuff.deviceid & octal!"177", client,
                             DixWriteAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.deviceid & octal!"177";
            return rc;
        }

        /* check type */
        type -= DeviceValuator;
        switch (type) {
        case XI_DeviceKeyPress:
        case XI_DeviceKeyRelease:
            if (!dev.key) {
                client.errorValue = cast(uint)ev.u.u.type;
                return BadValue;
            }
            break;
        case XI_DeviceButtonPress:
        case XI_DeviceButtonRelease:
            if (!dev.button) {
                client.errorValue = cast(uint)ev.u.u.type;
                return BadValue;
            }
            break;
        case XI_DeviceMotionNotify:
            if (!dev.valuator) {
                client.errorValue = cast(uint)ev.u.u.type;
                return BadValue;
            }
            break;
        case XI_ProximityIn:
        case XI_ProximityOut:
            if (!dev.proximity) {
                client.errorValue = cast(uint)ev.u.u.type;
                return BadValue;
            }
            break;
        default:
            client.errorValue = cast(uint)ev.u.u.type;
            return BadValue;
        }

        /* check validity */
        if (nev == 1 && type == XI_DeviceMotionNotify) {
            return BadLength;   /* DevMotion must be followed by DevValuator */
        }

        if (type == XI_DeviceMotionNotify) {
            firstValuator = (cast(deviceValuator*) (ev + 1)).first_valuator;
            if (firstValuator > dev.valuator.numAxes) {
                client.errorValue = cast(uint)ev.u.u.type;
                return BadValue;
            }

            if (ev.u.u.detail == xFalse) {
                flags |= POINTER_ABSOLUTE;
            }
        } else {
            firstValuator = 0;
            flags |= POINTER_ABSOLUTE;
        }

        if (nev > 1 && !dev.valuator) {
            client.errorValue = cast(uint)firstValuator;
            return BadValue;
        }

        /* check validity of valuator events */
        base = firstValuator;
        for (n = 1; n < nev; n++) {
            deviceValuator* dv = cast(deviceValuator*) (ev + n);
            if (dv.type != DeviceValuator) {
                client.errorValue = cast(uint)dv.type;
                return BadValue;
            }
            if (dv.first_valuator != base) {
                client.errorValue = cast(uint)dv.first_valuator;
                return BadValue;
            }
            switch (dv.num_valuators) {
            case 6:
                valuators[base + 5] = cast(int)dv.valuator5;
                goto case 5;
            case 5:
                valuators[base + 4] = cast(int)dv.valuator4;
                goto case 4;
            case 4:
                valuators[base + 3] = cast(int)dv.valuator3;
                goto case 3;
            case 3:
                valuators[base + 2] = cast(int)dv.valuator2;
                goto case 2;
            case 2:
                valuators[base + 1] = cast(int)dv.valuator1;
                goto case 1;
            case 1:
                valuators[base] = cast(int)dv.valuator0;
                break;
            default:
                client.errorValue = cast(uint)dv.num_valuators;
                return BadValue;
            }

            base += dv.num_valuators;
            numValuators += dv.num_valuators;

            if (firstValuator + numValuators > dev.valuator.numAxes) {
                client.errorValue = cast(uint)dv.num_valuators;
                return BadValue;
            }
        }
        type = type - XI_DeviceKeyPress + KeyPress;

    }
    else {
        if (nev != 1)
            return BadLength;
        switch (type) {
        case KeyPress:
        case KeyRelease:
            dev = PickKeyboard(client);
            break;
        case ButtonPress:
        case ButtonRelease:
            dev = PickPointer(client);
            break;
        case MotionNotify:
            dev = PickPointer(client);
            valuators[0] = ev.u.keyButtonPointer.rootX;
            valuators[1] = ev.u.keyButtonPointer.rootY;
            numValuators = 2;
            firstValuator = 0;
            if (ev.u.u.detail == xFalse)
                flags = POINTER_ABSOLUTE | POINTER_DESKTOP;
            break;
        default:
            client.errorValue = cast(uint)ev.u.u.type;
            return BadValue;
        }

        /* Technically the protocol doesn't allow for BadAccess here but
         * this can only happen when all MDs are disabled.  */
        if (!dev) {
            return BadAccess;
        }

        dev = GetXTestDevice(dev);

        /* This can only happen if we passed a slave to GetXTestDevice() */
        if (!dev) {
            return BadAccess;
        }
    }


    /* If the event has a time set, wait for it to pass */
    if (ev.u.keyButtonPointer.time) {
        TimeStamp activateTime = void;
        CARD32 ms = void;

        activateTime = currentTime;
        ms = activateTime.milliseconds + ev.u.keyButtonPointer.time;
        if (ms < activateTime.milliseconds) {
            activateTime.months++;
        }
        activateTime.milliseconds = ms;
        ev.u.keyButtonPointer.time = 0;

        /* see mbuf.c:QueueDisplayRequest (from the deprecated Multibuffer
         * extension) for code similar to this */

        if (!ClientSleepUntil(client, &activateTime, null, null)) {
            return BadAlloc;
        }
        /* swap the request back so we can simply re-execute it */
        if (client.swapped) {
            cast(void) XTestSwapFakeInput(client, cast(xReq*) stuff);
        }
        ResetCurrentRequest(client);
        client.sequence--;
        return Success;
    }

    switch (type) {
    case KeyPress:
    case KeyRelease:
        if ((!dev) || (!dev.key)) {
            return BadDevice;
        }

        if (ev.u.u.detail < dev.key.xkbInfo.desc.min_key_code ||
            ev.u.u.detail > dev.key.xkbInfo.desc.max_key_code) {
            client.errorValue = cast(uint)ev.u.u.detail;
            return BadValue;
        }

        need_ptr_update = 0;
        break;
    case MotionNotify:
        if (!dev || !dev.valuator) {
            return BadDevice;
        }

        if (!(extension || ev.u.keyButtonPointer.root == None)) {
            int rc = dixLookupWindow(&root, ev.u.keyButtonPointer.root,
                                 client, DixGetAttrAccess);
            if (rc != Success) {
                return rc;
            }
            if (root.parent) {
                client.errorValue = cast(uint)ev.u.keyButtonPointer.root;
                return BadValue;
            }

            /* Add the root window's offset to the valuators */
            if ((flags & POINTER_ABSOLUTE) && firstValuator <= 1 && numValuators > 0) {
                if (firstValuator == 0) {
                    valuators[0] += root.drawable.pScreen.x;
                }
                if (firstValuator + numValuators > 1) {
                    valuators[1 - firstValuator] += root.drawable.pScreen.y;
                }
            }
        }
        if (ev.u.u.detail != xTrue && ev.u.u.detail != xFalse) {
            client.errorValue = cast(uint)ev.u.u.detail;
            return BadValue;
        }

        /* FIXME: Xinerama! */

        break;
    case ButtonPress:
    case ButtonRelease:
        if (!dev || !dev.button) {
            return BadDevice;
        }

        if (!ev.u.u.detail || ev.u.u.detail > dev.button.numButtons) {
            client.errorValue = cast(uint)ev.u.u.detail;
            return BadValue;
        }
        break;
    default: break;}
    if (screenIsSaved == SCREEN_SAVER_ON)
        dixSaveScreens(serverClient, SCREEN_SAVER_OFF, ScreenSaverReset);

    valuator_mask_set_range(&mask, firstValuator, numValuators, valuators.ptr);

    if (dev && dev.sendEventsProc) {
        (*dev.sendEventsProc) (dev, type, ev.u.u.detail, flags, &mask);
    }

    if (need_ptr_update) {
        miPointerUpdateSprite(dev);
    }
    return Success;
}

private int ProcXTestGrabControl(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXTestGrabControlReq);

    if ((stuff.impervious != xTrue) && (stuff.impervious != xFalse)) {
        client.errorValue = cast(uint)stuff.impervious;
        return BadValue;
    }
    if (stuff.impervious) {
        MakeClientGrabImpervious(client);
    } else {
        MakeClientGrabPervious(client);
    }
    return Success;
}

private int ProcXTestDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_XTestGetVersion:
        return ProcXTestGetVersion(client);
    case X_XTestCompareCursor:
        return ProcXTestCompareCursor(client);
    case X_XTestFakeInput:
        return ProcXTestFakeInput(client);
    case X_XTestGrabControl:
        return ProcXTestGrabControl(client);
    default:
        return BadRequest;
    }
}

private int XTestSwapFakeInput(ClientPtr client, xReq* req)
{
    int nev = void;
    xEvent* ev = void;
    xEvent sev = void;
    EventSwapPtr proc = void;

    nev = cast(uint)(((client.req_len << 2) - xReq.sizeof) / xEvent.sizeof);
    for (ev = cast(xEvent*) &req[1]; --nev >= 0; ev++) {
        int evtype = ev.u.u.type & octal!"177";
        /* Swap event */
        proc = EventSwapVector[evtype];
        /* no swapping proc; invalid event type? */
        if (!proc || proc == &NotImplemented || evtype == GenericEvent) {
            client.errorValue = cast(uint)ev.u.u.type;
            return BadValue;
        }
        (*proc) (ev, &sev);
        *ev = sev;
    }
    return Success;
}

/**
 * Allocate an virtual slave device for xtest events, this
 * is a slave device to inputInfo master devices
 */
void InitXTestDevices()
{
    if (AllocXTestDevice(serverClient, "Virtual core",
                         &xtestpointer, &xtestkeyboard,
                         inputInfo.pointer, inputInfo.keyboard) != Success) {
         FatalError("Failed to allocate XTest devices");
    }

    if (ActivateDevice(xtestpointer, TRUE) != Success ||
        ActivateDevice(xtestkeyboard, TRUE) != Success) {
        FatalError("Failed to activate XTest core devices.");
    }

    if (!EnableDevice(xtestpointer, TRUE) || !EnableDevice(xtestkeyboard, TRUE)) {
        FatalError("Failed to enable XTest core devices.");
    }

    AttachDevice(null, xtestpointer, inputInfo.pointer);
    AttachDevice(null, xtestkeyboard, inputInfo.keyboard);
}

/**
 * Don't allow changing the XTest property.
 */
private int DeviceSetXTestProperty(DeviceIntPtr dev, Atom property, XIPropertyValuePtr prop, BOOL checkonly)
{
    if (property == XIGetKnownProperty(XI_PROP_XTEST_DEVICE)) {
        return BadAccess;
    }

    return Success;
}

/**
 * Allocate a device pair that is initialised as a slave
 * device with properties that identify the devices as belonging
 * to XTest subsystem.
 * This only creates the pair, Activate/Enable Device
 * still need to be called.
 */
int AllocXTestDevice(ClientPtr client, const(char)* name, DeviceIntPtr* ptr, DeviceIntPtr* keybd, DeviceIntPtr master_ptr, DeviceIntPtr master_keybd)
{
    int retval = void;
    char* xtestname = void;
    char dummy = 1;

    if (asprintf(&xtestname, "%s XTEST", name) == -1) {
        return BadAlloc;
    }

    retval =
        AllocDevicePair(client, xtestname, ptr, keybd, &CorePointerProc,
                        &CoreKeyboardProc, FALSE);
    if (retval == Success) {
        (*ptr).xtest_master_id = master_ptr.id;
        (*keybd).xtest_master_id = master_keybd.id;

        XIChangeDeviceProperty(*ptr, XIGetKnownProperty(XI_PROP_XTEST_DEVICE),
                               XA_INTEGER, 8, PropModeReplace, 1, &dummy,
                               FALSE);
        XISetDevicePropertyDeletable(*ptr,
                                     XIGetKnownProperty(XI_PROP_XTEST_DEVICE),
                                     FALSE);
        XIRegisterPropertyHandler(*ptr, &DeviceSetXTestProperty, null, null);
        XIChangeDeviceProperty(*keybd, XIGetKnownProperty(XI_PROP_XTEST_DEVICE),
                               XA_INTEGER, 8, PropModeReplace, 1, &dummy,
                               FALSE);
        XISetDevicePropertyDeletable(*keybd,
                                     XIGetKnownProperty(XI_PROP_XTEST_DEVICE),
                                     FALSE);
        XIRegisterPropertyHandler(*keybd, &DeviceSetXTestProperty, null, null);
    }

    free(xtestname);

    return retval;
}

/**
 * If master is NULL, return TRUE if the given device is an xtest device or
 * FALSE otherwise.
 * If master is not NULL, return TRUE if the given device is this master's
 * xtest device.
 */
BOOL IsXTestDevice(DeviceIntPtr dev, DeviceIntPtr master)
{
    if (InputDevIsMaster(dev)) {
        return FALSE;
    }

    /* deviceid 0 is reserved for XIAllDevices, non-zero mid means XTest
     * device */
    if (master) {
        return dev.xtest_master_id == master.id;
    }

    return dev.xtest_master_id != 0;
}

/**
 * @return The X Test virtual device for the given master.
 */
DeviceIntPtr GetXTestDevice(DeviceIntPtr master)
{
    DeviceIntPtr it = void;

    for (it = inputInfo.devices; it; it = it.next) {
        if (IsXTestDevice(it, master)) {
            return it;
        }
    }

    /* This only happens if master is a slave device. don't do that */
    return null;
}

private void XTestExtensionTearDown(ExtensionEntry* e)
{
    FreeEventList(xtest_evlist, GetMaximumEventsNum());
    xtest_evlist = null;
}

void XTestExtensionInit()
{
    AddExtension(XTestExtensionName, 0, 0,
                 &ProcXTestDispatch, &ProcXTestDispatch,
                 &XTestExtensionTearDown, &StandardMinorOpcode);

    xtest_evlist = cast(_InternalEvent*)InitEventList(GetMaximumEventsNum());
}
