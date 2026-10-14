module dix.devices;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

Copyright 1987, 1998  The Open Group

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

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

import build.dix_config;

import core.stdc.math;
import pixman;
// //import stdbool;
//import x11.X;
//import x11.Xproto;
import externs.X11.Xatom;
import externs.X11.extensions.XI;
import externs.X11.extensions.XI2;
// //import externs.X11.extensions.XIproto;
import os.inputthread;

import dix.devices_priv;
import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.ptrveloc_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.screenint_priv;
import mi.mi_priv;
import os.bug_priv;
import os.log_priv;
import os.osdep;
import xkb.xkbsrv_priv;

import include.misc;
import include.resource;
import include.windowstr;
import include.inputstr;
import include.scrnintstr;
import dix.cursor;
import include.dixstruct;
import ptrveloc;
import include.privates;
import dix.dispatch;
import dix.swaprep;
import mi.mipointer;
import include.eventstr;
import Xi.exglobals;
import Xi.xiquerydevice;      /* for SizeDeviceClasses */
import Xi.xiproperty;
import dix.enterleave;         /* for EnterWindow() */
import include.xserver_properties;
import Xi.xichangehierarchy;  /* For XISendDeviceHierarchyEvent */
import Xext.syncsrv;
import externs.attrs;
import os.log;
import dix.dixutils;
import dix.globals;
import os.utils;
import externs.gnu;
import dix.events;
import dix.inpututils;
import include.xkbstr;


/** @file
 * This file handles input device-related stuff.
 */

// CallbackListPtr DeviceAccessCallback = null;



private void DeviceSetTransform(DeviceIntPtr dev, float* transform_data)
{
    /**
     * calculate combined transformation matrix:
     *
     * M = InvScale * Transform * Scale
     *
     * So we can later transform points using M * p
     *
     * Where:
     *  Scale scales coordinates into 0..1 range
     *  Transform is the user supplied (affine) transform
     *  InvScale scales coordinates back up into their native range
     */
    double sx = dev.valuator.axes[0].max_value - dev.valuator.axes[0].min_value + 1;
    double sy = dev.valuator.axes[1].max_value - dev.valuator.axes[1].min_value + 1;

    /* invscale */
    pixman_f_transform scale = { 0 };
    assumeNoGC(&pixman_f_transform_init_scale)(&scale, sx, sy);
    scale.m[0][2] = dev.valuator.axes[0].min_value;
    scale.m[1][2] = dev.valuator.axes[1].min_value;

    /* transform */
    pixman_f_transform transform = { 0 };
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            transform.m[y][x] = *transform_data++;

    assumeNoGC(&pixman_f_transform_multiply)(&dev.scale_and_transform, &scale, &transform);

    /* scale */
    assumeNoGC(&pixman_f_transform_init_scale)(&scale, 1.0 / sx, 1.0 / sy);
    scale.m[0][2] = -dev.valuator.axes[0].min_value / sx;
    scale.m[1][2] = -dev.valuator.axes[1].min_value / sy;

    assumeNoGC(&pixman_f_transform_multiply)(&dev.scale_and_transform, &dev.scale_and_transform, &scale);

    /* remove translation component for relative movements */
    dev.relative_transform = transform;
    dev.relative_transform.m[0][2] = 0;
    dev.relative_transform.m[1][2] = 0;
}

/**
 * DIX property handler.
 */
private int DeviceSetProperty(DeviceIntPtr dev, Atom property, XIPropertyValuePtr prop, BOOL checkonly)
{
    if (property == XIGetKnownProperty(XI_PROP_ENABLED)) {
        if (prop.format != 8 || prop.type != XA_INTEGER || prop.size != 1)
            return BadValue;

        /* Don't allow disabling of VCP/VCK or XTest devices */
        if ((dev == inputInfo.pointer ||
             dev == inputInfo.keyboard ||
             IsXTestDevice(dev, null))
            &&!(*cast(CARD8*) prop.data))
            return BadAccess;

        if (!checkonly) {
            if ((*(cast(CARD8*) prop.data)) && !dev.enabled)
                EnableDevice(dev, TRUE);
            else if (!(*(cast(CARD8*) prop.data)) && dev.enabled)
                DisableDevice(dev, TRUE);
        }
    }
    else if (property == XIGetKnownProperty(XI_PROP_TRANSFORM)) {
        float* f = cast(float*) prop.data;

        if (prop.format != 32 || prop.size != 9 ||
            prop.type != XIGetKnownProperty(XATOM_FLOAT))
            return BadValue;

        for (int i = 0; i < 9; i++)
            if (!isfinite(f[i]))
                return BadValue;

        if (!dev.valuator)
            return BadMatch;

        if (!checkonly)
            DeviceSetTransform(dev, f);
    }

    return Success;
}

/* Pair the keyboard to the pointer device. Keyboard events will follow the
 * pointer sprite. Only applicable for master devices.
 */
private int PairDevices(DeviceIntPtr ptr, DeviceIntPtr kbd)
{
    if (!ptr)
        return BadDevice;

    /* Don't allow pairing for slave devices */
    if (!InputDevIsMaster(ptr) || !InputDevIsMaster(kbd))
        return BadDevice;

    if (ptr.spriteInfo.paired)
        return BadDevice;

    if (kbd.spriteInfo.spriteOwner) {
        free(kbd.spriteInfo.sprite);
        kbd.spriteInfo.sprite = null;
        kbd.spriteInfo.spriteOwner = FALSE;
    }

    kbd.spriteInfo.sprite = ptr.spriteInfo.sprite;
    kbd.spriteInfo.paired = ptr;
    ptr.spriteInfo.paired = kbd;
    return Success;
}

/**
 * Find and return the next unpaired MD pointer device.
 */
private DeviceIntPtr NextFreePointerDevice()
{
    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next)
        if (InputDevIsMaster(dev) &&
            dev.spriteInfo.spriteOwner && !dev.spriteInfo.paired)
            return dev;
    return null;
}

/**
 * Create a new input device and init it to sane values. The device is added
 * to the server's off_devices list.
 *
 * @param deviceProc Callback for device control function (switch dev on/off).
 * @return The newly created device.
 */
DeviceIntPtr AddInputDevice(ClientPtr client, DeviceProc deviceProc, Bool autoStart)
{
    /* Find next available id, 0 and 1 are reserved */
    char[MAXDEVICES] devind = 0;
    for (DeviceIntPtr devtmp = inputInfo.devices; devtmp; devtmp = devtmp.next)
        devind[devtmp.id]++;
    for (DeviceIntPtr devtmp = inputInfo.off_devices; devtmp; devtmp = devtmp.next)
        devind[devtmp.id]++;

    int devid = void;
    for (devid = 2; devid < MAXDEVICES && devind[devid]; devid++){}

    if (devid >= MAXDEVICES)
        return cast(DeviceIntPtr) null;

    DeviceIntPtr dev = cast(DeviceIntPtr) calloc(1,
                 ((DeviceIntRec).sizeof +
                 SpriteInfoRec.sizeof));
    if (!dev)
        return cast(DeviceIntPtr) null;

    if (!dixAllocatePrivates(&dev.devPrivates, PRIVATE_DEVICE)) {
        free(dev);
        return null;
    }

    dev.last.scroll = null;
    dev.last.touches = null;
    dev.id = devid;
    dev.public_.processInputProc = &ProcessOtherEvent;
    dev.public_.realInputProc = &ProcessOtherEvent;
    dev.public_.enqueueInputProc = &EnqueueEvent;
    dev.deviceProc = deviceProc;
    dev.startup = autoStart;

    /* device grab defaults */
    UpdateCurrentTimeIf();
    dev.deviceGrab.grabTime = currentTime;
    dev.deviceGrab.ActivateGrab = &ActivateKeyboardGrab;
    dev.deviceGrab.DeactivateGrab = &DeactivateKeyboardGrab;
    if (((dev.deviceGrab.sync.event = cast(InternalEvent*) calloc(1, InternalEvent.sizeof)) is null)) {
        dixFreePrivates(dev.devPrivates, PRIVATE_DEVICE);
        free(dev);
        return null;
    }

    dev.sendEventsProc = &XTestDeviceSendEvents;

    XkbSetExtension(dev, &ProcessKeyboardEvent);

    dev.coreEvents = TRUE;

    /* sprite defaults */
    dev.spriteInfo = cast(SpriteInfoPtr) &dev[1];

    /*  security creation/labeling check
     */
    if (dixCallDeviceAccessCallback(client, dev, DixCreateAccess)) {
        dixFreePrivates(dev.devPrivates, PRIVATE_DEVICE);
        free(dev.deviceGrab.sync.event);
        free(dev);
        return null;
    }

    inputInfo.numDevices++;

    DeviceIntPtr* prev = void;    /* not a typo */
    for (prev = &inputInfo.off_devices; *prev; prev = &(*prev).next){}
    *prev = dev;
    dev.next = null;

    BOOL enabled = FALSE;
    XIChangeDeviceProperty(dev, XIGetKnownProperty(XI_PROP_ENABLED),
                           XA_INTEGER, 8, PropModeReplace, 1, &enabled, FALSE);
    XISetDevicePropertyDeletable(dev, XIGetKnownProperty(XI_PROP_ENABLED),
                                 FALSE);

    /* unity matrix */
    float[9] transform = 0;
    transform[0] = transform[4] = transform[8] = 1.0f;
    dev.relative_transform.m[0][0] = 1.0;
    dev.relative_transform.m[1][1] = 1.0;
    dev.relative_transform.m[2][2] = 1.0;
    dev.scale_and_transform = dev.relative_transform;

    XIChangeDeviceProperty(dev, XIGetKnownProperty(XI_PROP_TRANSFORM),
                           XIGetKnownProperty(XATOM_FLOAT), 32,
                           PropModeReplace, 9, transform.ptr, FALSE);
    XISetDevicePropertyDeletable(dev, XIGetKnownProperty(XI_PROP_TRANSFORM),
                                 FALSE);

    XIRegisterPropertyHandler(dev, &DeviceSetProperty, null, null);

    return dev;
}

void SendDevicePresenceEvent(int deviceid, int type)
{
    UpdateCurrentTimeIf();

    devicePresenceNotify ev = {
        type: cast(ubyte)DevicePresenceNotify,
        time: currentTime.milliseconds,
        devchange: cast(ubyte)type,
        deviceid: cast(ubyte)deviceid,
    };

    DeviceIntRec dummyDev = { id:  XIAllDevices };

    SendEventToAllWindows(&dummyDev, DevicePresenceNotifyMask,
                          cast(xEvent*) &ev, 1);
}

/**
 * Enable the device through the driver, add the device to the device list.
 * Switch device ON through the driver and push it onto the global device
 * list. Initialize the DIX sprite or pair the device. All clients are
 * notified about the device being enabled.
 *
 * A master pointer device needs to be enabled before a master keyboard
 * device.
 *
 * @param The device to be enabled.
 * @param sendevent True if an XI2 event should be sent.
 * @return TRUE on success or FALSE otherwise.
 */
Bool EnableDevice(DeviceIntPtr dev, BOOL sendevent)
{
    DeviceIntPtr* prev = void;
    for (prev = &inputInfo.off_devices;
         *prev && (*prev != dev); prev = &(*prev).next){}

    if (!dev.spriteInfo.sprite) {
        if (InputDevIsMaster(dev)) {
            /* Sprites appear on first root window, so we can hardcode it */
            if (dev.spriteInfo.spriteOwner) {
                ScreenPtr masterScreen = dixGetMasterScreen();
                InitializeSprite(dev, masterScreen.root);
                /* mode doesn't matter */
                EnterWindow(dev, masterScreen.root, NotifyAncestor);
            }
            else {
                DeviceIntPtr other = NextFreePointerDevice();
                mixin(BUG_RETURN_VAL_MSG!("other is null", "FALSE",
                                   "[dix] cannot find pointer to pair with.\n"));
                PairDevices(other, dev);
            }
        }
        else {
            DeviceIntPtr other = void;
            if (dev.coreEvents)
                other = (IsPointerDevice(dev)) ? inputInfo.pointer:
                    inputInfo.keyboard;
            else
                other = null;   /* auto-float non-core devices */
            AttachDevice(null, dev, other);
        }
    }

    input_lock();
    if ((*prev != dev) || !dev.inited ||
        (((*dev.deviceProc) (dev, DEVICE_ON)) != Success)) {
        ErrorF("[dix] couldn't enable device %d\n", dev.id);
        input_unlock();
        return FALSE;
    }
    dev.enabled = TRUE;
    *prev = dev.next;

    for (prev = &inputInfo.devices; *prev; prev = &(*prev).next){}
    *prev = dev;
    dev.next = null;
    input_unlock();

    BOOL enabled = TRUE;
    XIChangeDeviceProperty(dev, XIGetKnownProperty(XI_PROP_ENABLED),
                           XA_INTEGER, 8, PropModeReplace, 1, &enabled, TRUE);

    SendDevicePresenceEvent(dev.id, DeviceEnabled);
    if (sendevent) {
        int[MAXDEVICES] flags = 0;
        flags[dev.id] |= XIDeviceEnabled;
        XISendDeviceHierarchyEvent(flags.ptr);
    }

    if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
        XkbPushLockedStateToSlaves(GetMaster(dev, MASTER_KEYBOARD), 0, 0);

    /* Now make sure our LEDs are in sync with the locked state */
    XkbForceUpdateDeviceLEDs(dev);

    RecalculateMasterButtons(dev);

    /* initialise an idle timer for this device*/
    dev.idle_counter = SyncInitDeviceIdleTime(dev);

    return TRUE;
}


/**
 * Switch a device off through the driver and push it onto the off_devices
 * list. A device will not send events while disabled. All clients are
 * notified about the device being disabled.
 *
 * Master keyboard devices have to be disabled before master pointer devices
 * otherwise things turn bad.
 *
 * @param sendevent True if an XI2 event should be sent.
 * @return TRUE on success or FALSE otherwise.
 */
Bool DisableDevice(DeviceIntPtr dev, BOOL sendevent)
{
    if (!dev.enabled)
        return TRUE;

    BOOL dev_in_devices_list = FALSE;
    for (DeviceIntPtr other = inputInfo.devices; other; other = other.next) {
        if (other == dev) {
            dev_in_devices_list = TRUE;
            break;
        }
    }

    if (!dev_in_devices_list)
        return FALSE;

    TouchEndPhysicallyActiveTouches(dev);
    GestureEndActiveGestures(dev);
    ReleaseButtonsAndKeys(dev);
    SyncRemoveDeviceIdleTime(dev.idle_counter);
    dev.idle_counter = null;

    /* float attached devices */
    int[MAXDEVICES] flags = 0;
    if (InputDevIsMaster(dev)) {
        for (DeviceIntPtr other = inputInfo.devices; other; other = other.next) {
            if (!InputDevIsMaster(other) && GetMaster(other, MASTER_ATTACHED) == dev) {
                AttachDevice(null, other, null);
                flags[other.id] |= XISlaveDetached;
            }
        }

        for (DeviceIntPtr other = inputInfo.off_devices; other; other = other.next) {
            if (!InputDevIsMaster(other) && GetMaster(other, MASTER_ATTACHED) == dev) {
                AttachDevice(null, other, null);
                flags[other.id] |= XISlaveDetached;
            }
        }
    }
    else {
        for (DeviceIntPtr other = inputInfo.devices; other; other = other.next) {
            if (InputDevIsMaster(other) && other.lastSlave == dev)
                other.lastSlave = null;
        }
    }

    if (InputDevIsMaster(dev) && dev.spriteInfo.sprite) {
        for (DeviceIntPtr other = inputInfo.devices; other; other = other.next)
            if (other.spriteInfo.paired == dev && !other.spriteInfo.spriteOwner)
                DisableDevice(other, sendevent);
    }

    if (dev.spriteInfo.paired)
        dev.spriteInfo.paired = null;

    input_lock();
    cast(void) (*dev.deviceProc) (dev, DEVICE_OFF);
    dev.enabled = FALSE;

    /* now that the device is disabled, we can reset the event reader's
     * last.slave */
    for (DeviceIntPtr other = inputInfo.devices; other; other = other.next) {
        if (other.last.slave == dev)
            other.last.slave = null;
    }
    input_unlock();

    FreeSprite(dev);

    LeaveWindow(dev);
    SetFocusOut(dev);

    DeviceIntPtr* prev = void;
    for (prev = &inputInfo.devices;
         *prev && (*prev != dev); prev = &(*prev).next){}

    *prev = dev.next;
    dev.next = inputInfo.off_devices;
    inputInfo.off_devices = dev;

    BOOL enabled = FALSE;
    XIChangeDeviceProperty(dev, XIGetKnownProperty(XI_PROP_ENABLED),
                           XA_INTEGER, 8, PropModeReplace, 1, &enabled, TRUE);

    SendDevicePresenceEvent(dev.id, DeviceDisabled);
    if (sendevent) {
        flags[dev.id] = XIDeviceDisabled;
        XISendDeviceHierarchyEvent(flags.ptr);
    }

    RecalculateMasterButtons(dev);
    dev.master = null;

    return TRUE;
}

void DisableAllDevices()
{
    DeviceIntPtr dev = void, tmp = void;

    /* Disable slave devices first, excluding XTest devices */
    mixin(nt_list_for_each_entry_safe!("dev", "tmp", "inputInfo.devices", "next", q{
        if (!IsXTestDevice(dev, null) && !InputDevIsMaster(dev))
            DisableDevice(dev, FALSE);
    }));
    /* Disable XTest devices */
    mixin(nt_list_for_each_entry_safe!("dev", "tmp", "inputInfo.devices", "next", q{
        if (!InputDevIsMaster(dev))
            DisableDevice(dev, FALSE);
    }));
    /* master keyboards need to be disabled first */
    mixin(nt_list_for_each_entry_safe!("dev", "tmp", "inputInfo.devices", "next", q{
        if (dev.enabled && InputDevIsMaster(dev) && IsKeyboardDevice(dev))
            DisableDevice(dev, FALSE);
    }));
    mixin(nt_list_for_each_entry_safe!("dev", "tmp", "inputInfo.devices", "next", q{
        if (dev.enabled)
            DisableDevice(dev, FALSE);
    }));
}

/**
 * Initialise a new device through the driver and tell all clients about the
 * new device.
 *
 * Must be called before EnableDevice.
 * The device will NOT send events until it is enabled!
 *
 * @param sendevent True if an XI2 event should be sent.
 * @return Success or an error code on failure.
 */
int ActivateDevice(DeviceIntPtr dev, BOOL sendevent)
{
    int ret = Success;
    ScreenPtr masterScreen = dixGetMasterScreen();

    if (!dev || !dev.deviceProc)
        return BadImplementation;

    input_lock();
    ret = (*dev.deviceProc) (dev, DEVICE_INIT);
    input_unlock();
    dev.inited = (ret == Success);
    if (!dev.inited)
        return ret;

    /* Initialize memory for sprites. */
    if (InputDevIsMaster(dev) && dev.spriteInfo.spriteOwner)
        if (!masterScreen.DeviceCursorInitialize(dev, masterScreen))
            ret = BadAlloc;

    SendDevicePresenceEvent(dev.id, DeviceAdded);
    if (sendevent) {
        int[MAXDEVICES] flags = 0;
        flags[dev.id] = XISlaveAdded;
        XISendDeviceHierarchyEvent(flags.ptr);
    }
    return ret;
}

/**
 * Ring the bell.
 * The actual task of ringing the bell is the job of the DDX.
 */
private void CoreKeyboardBell(int volume, DeviceIntPtr pDev, void* arg, int something)
{
    KeybdCtrl* ctrl = cast(KeybdCtrl*)arg;

    DDXRingBell(volume, ctrl.bell_pitch, ctrl.bell_duration);
}

private void CoreKeyboardCtl(DeviceIntPtr pDev, KeybdCtrl* ctrl)
{
    return;
}

/**
 * Device control function for the Virtual Core Keyboard.
 */
int CoreKeyboardProc(DeviceIntPtr pDev, int what)
{

    switch (what) {
    case DEVICE_INIT:
        if (!InitKeyboardDeviceStruct(pDev, null, &CoreKeyboardBell,
                                      &CoreKeyboardCtl)) {
            ErrorF("Keyboard initialization failed. This could be a missing "
                   ~ "or incorrect setup of xkeyboard-config.\n");
            return BadValue;
        }
        return Success;

    case DEVICE_ON:
    case DEVICE_OFF:
        return Success;

    case DEVICE_CLOSE:
        return Success;
    default: break;}

    return BadMatch;
}

/**
 * Device control function for the Virtual Core Pointer.
 */
int CorePointerProc(DeviceIntPtr pDev, int what)
{
enum NBUTTONS = 10;
enum NAXES = 2;
    BYTE[NBUTTONS + 1] map = 0;
    Atom[NBUTTONS] btn_labels = 0;
    Atom[NAXES] axes_labels = 0;

    switch (what) {
    case DEVICE_INIT:
        for (int i = 1; i <= NBUTTONS; i++)
            map[i] = cast(ubyte)i;

        btn_labels[0] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_LEFT);
        btn_labels[1] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_MIDDLE);
        btn_labels[2] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_RIGHT);
        btn_labels[3] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_UP);
        btn_labels[4] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_DOWN);
        btn_labels[5] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_LEFT);
        btn_labels[6] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_RIGHT);
        /* don't know about the rest */

        axes_labels[0] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_X);
        axes_labels[1] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y);

        if (!InitPointerDeviceStruct
            (cast(DevicePtr) pDev, map.ptr, NBUTTONS, btn_labels.ptr,
             cast(PtrCtrlProcPtr) &NoopDDA, GetMotionHistorySize(), NAXES,
             axes_labels.ptr)) {
            ErrorF("Could not initialize device '%s'. Out of memory.\n",
                   pDev.name);
            return BadAlloc;    /* IPDS only fails on allocs */
        }
        /* axisVal is per-screen, last.valuators is desktop-wide */
        ScreenPtr masterScreen = dixGetMasterScreen();
        pDev.valuator.axisVal[0] = masterScreen.width / 2;
        pDev.last.valuators[0] = pDev.valuator.axisVal[0] + masterScreen.x;
        pDev.valuator.axisVal[1] = masterScreen.height / 2;
        pDev.last.valuators[1] = pDev.valuator.axisVal[1] + masterScreen.y;
        break;

    case DEVICE_CLOSE:
        break;

    default:
        break;
    }

    return Success;

}

/**
 * Initialise the two core devices, VCP and VCK (see events.c).
 * Both devices are not tied to physical devices, but guarantee that there is
 * always a keyboard and a pointer present and keep the protocol semantics.
 *
 * Note that the server MUST have two core devices at all times, even if there
 * is no physical device connected.
 */
void InitCoreDevices()
{
    int result = AllocDevicePair(serverClient, "Virtual core",
                             &inputInfo.pointer, &inputInfo.keyboard,
                             &CorePointerProc, &CoreKeyboardProc, TRUE);
    if (result != Success) {
        FatalError("Failed to allocate virtual core devices: %d", result);
    }

    result = ActivateDevice(inputInfo.pointer, TRUE);
    if (result != Success) {
        FatalError("Failed to activate virtual core pointer: %d", result);
    }

    result = ActivateDevice(inputInfo.keyboard, TRUE);
    if (result != Success) {
        FatalError("Failed to activate virtual core keyboard: %d", result);
    }

    if (!EnableDevice(inputInfo.pointer, TRUE)) {
         FatalError("Failed to enable virtual core pointer.");
    }

    if (!EnableDevice(inputInfo.keyboard, TRUE)) {
         FatalError("Failed to enable virtual core keyboard.");
    }

    InitXTestDevices();
}

/**
 * Activate all switched-off devices and then enable all those devices.
 *
 * Will return an error if no core keyboard or core pointer is present.
 * In theory this should never happen if you call InitCoreDevices() first.
 *
 * InitAndStartDevices needs to be called AFTER the windows are initialized.
 * Devices will start sending events after InitAndStartDevices() has
 * completed.
 *
 * @return Success or error code on failure.
 */
int InitAndStartDevices()
{
    for (DeviceIntPtr dev = inputInfo.off_devices; dev; dev = dev.next) {
        DebugF("(dix) initialising device %d\n", dev.id);
        if (!dev.inited)
            ActivateDevice(dev, TRUE);
    }

    /* enable real devices */
    for (DeviceIntPtr dev = inputInfo.off_devices, next = void; dev; dev = next) {
        DebugF("(dix) enabling device %d\n", dev.id);
        next = dev.next;
        if (dev.inited && dev.startup)
            EnableDevice(dev, TRUE);
    }

    return Success;
}

/**
 * Free the given device class and reset the pointer to NULL.
 */
void FreeDeviceClass(int type, void** class_)
{
    if (!(*class_))
        return;

    switch (type) {
    case KeyClass:
    {
        KeyClassPtr* k = cast(KeyClassPtr*) class_;

        if ((*k).xkbInfo) {
            XkbFreeInfo((*k).xkbInfo);
            (*k).xkbInfo = null;
        }
        free((*k));
        break;
    }
    case ButtonClass:
    {
        ButtonClassPtr* b = cast(ButtonClassPtr*) class_;

        free((*b).xkb_acts);
        free((*b));
        break;
    }
    case ValuatorClass:
    {
        ValuatorClassPtr* v = cast(ValuatorClassPtr*) class_;

        free((*v).motion);
        free((*v));
        break;
    }
    case XITouchClass:
    {
        TouchClassPtr* t = cast(TouchClassPtr*) class_;

        for (int i = 0; i < (*t).num_touches; i++) {
            free((*t).touches[i].sprite.spriteTrace);
            free((*t).touches[i].listeners);
            free((*t).touches[i].valuators);
        }

        free((*t).touches);
        free((*t));
        break;
    }
    case XIGestureClass:
    {
        GestureClassPtr* g = cast(GestureClassPtr*) class_;

        GestureFreeGestureInfo(&(*g).gesture);
        free((*g));
        break;
    }
    case FocusClass:
    {
        FocusClassPtr* f = cast(FocusClassPtr*) class_;

        free((*f).trace);
        free((*f));
        break;
    }
    case ProximityClass:
    {
        ProximityClassPtr* p = cast(ProximityClassPtr*) class_;

        free((*p));
        break;
    }
    default: break;}
    *class_ = null;
}

private void FreeFeedbackClass(int type, void** class_)
{
    if (!(*class_))
        return;

    switch (type) {
    case KbdFeedbackClass:
    {
        for (KbdFeedbackPtr k = *cast(KbdFeedbackPtr*)class_, knext = void; k; k = knext) {
            knext = k.next;
            if (k.xkb_sli)
                XkbFreeSrvLedInfo(k.xkb_sli);
            free(k);
        }
        break;
    }
    case PtrFeedbackClass:
    {
        for (PtrFeedbackPtr p = *cast(PtrFeedbackPtr*)class_, pnext = void; p; p = pnext) {
            pnext = p.next;
            free(p);
        }
        break;
    }
    case IntegerFeedbackClass:
    {
        for (IntegerFeedbackPtr i = *cast(IntegerFeedbackPtr*)class_, inext = void; i; i = inext) {
            inext = i.next;
            free(i);
        }
        break;
    }
    case StringFeedbackClass:
    {
        for (StringFeedbackPtr s = *cast(StringFeedbackPtr*)class_, snext = void; s; s = snext) {
            snext = s.next;
            free(s.ctrl.symbols_supported);
            free(s.ctrl.symbols_displayed);
            free(s);
        }
        break;
    }
    case BellFeedbackClass:
    {
        for (BellFeedbackPtr b = *cast(BellFeedbackPtr*)class_, bnext = void; b; b = bnext) {
            bnext = b.next;
            free(b);
        }
        break;
    }
    case LedFeedbackClass:
    {
        for (LedFeedbackPtr l = *cast(LedFeedbackPtr*)class_, lnext = void; l; l = lnext) {
            lnext = l.next;
            if (l.xkb_sli)
                XkbFreeSrvLedInfo(l.xkb_sli);
            free(l);
        }
        break;
    }
    default: break;}
    *class_ = null;
}

private void FreeAllDeviceClasses(ClassesPtr classes)
{
    if (!classes)
        return;

    FreeDeviceClass(KeyClass, cast(void**) &classes.key);
    FreeDeviceClass(ValuatorClass, cast(void**) &classes.valuator);
    FreeDeviceClass(XITouchClass, cast(void**) &classes.touch);
    FreeDeviceClass(ButtonClass, cast(void**) &classes.button);
    FreeDeviceClass(FocusClass, cast(void**) &classes.focus);
    FreeDeviceClass(ProximityClass, cast(void**) &classes.proximity);
    FreeDeviceClass(XIGestureClass, cast(void**) &classes.gesture);

    FreeFeedbackClass(KbdFeedbackClass, cast(void**) &classes.kbdfeed);
    FreeFeedbackClass(PtrFeedbackClass, cast(void**) &classes.ptrfeed);
    FreeFeedbackClass(IntegerFeedbackClass, cast(void**) &classes.intfeed);
    FreeFeedbackClass(StringFeedbackClass, cast(void**) &classes.stringfeed);
    FreeFeedbackClass(BellFeedbackClass, cast(void**) &classes.bell);
    FreeFeedbackClass(LedFeedbackClass, cast(void**) &classes.leds);

}

private void FreePendingFrozenDeviceEvents(DeviceIntPtr dev)
{
    QdEventPtr qe = void, tmp = void;

    if (!dev.deviceGrab.sync.frozen)
        return;

    /* Dequeue any frozen pending events */
    mixin(xorg_list_for_each_entry_safe!("qe", "tmp", "&syncEvents.pending", "next", q{
        if (qe.device == dev) {
            xorg_list_del(&qe.next);
            free(qe);
        }
    }));
}

/**
 * Close down a device and free all resources.
 * Once closed down, the driver will probably not expect you that you'll ever
 * enable it again and free associated structs. If you want the device to just
 * be disabled, DisableDevice().
 * Don't call this function directly, use RemoveDevice() instead.
 *
 * Called with input lock held.
 */
private void CloseDevice(DeviceIntPtr dev)
{
    if (!dev)
        return;

    XIDeleteAllDeviceProperties(dev);

    if (dev.inited)
        cast(void) (*dev.deviceProc) (dev, DEVICE_CLOSE);

    FreeSprite(dev);

    if (InputDevIsMaster(dev)) {
        ScreenPtr masterScreen = dixGetMasterScreen();
        masterScreen.DeviceCursorCleanup(dev, masterScreen);
    }

    /* free acceleration info */
    if (dev.valuator && dev.valuator.accelScheme.AccelCleanupProc)
        dev.valuator.accelScheme.AccelCleanupProc(dev);

    while (dev.xkb_interest)
        XkbRemoveResourceClient(cast(DevicePtr) dev, dev.xkb_interest.resource);

    free(dev.name);

    ClassesPtr classes = cast(ClassesPtr) &dev.key;
    FreeAllDeviceClasses(classes);

    if (InputDevIsMaster(dev)) {
        classes = dev.unused_classes;
        FreeAllDeviceClasses(classes);
        free(classes);
    }

    /* a client may have the device set as client pointer */
    for (int j = 0; j < currentMaxClients; j++) {
        if (clients[j] && clients[j].clientPtr == dev) {
            clients[j].clientPtr = null;
            clients[j].clientPtr = PickPointer(clients[j]);
        }
    }

    FreeGrab(dev.deviceGrab.grab);
    free(dev.deviceGrab.sync.event);
    free(dev.config_info);     /* Allocated in xf86ActivateDevice. */
    free(dev.last.scroll);
    for (int j = 0; j < dev.last.num_touches; j++)
        valuator_mask_free(&dev.last.touches[j].valuators);
    free(dev.last.touches);
    dev.config_info = null;
    FreePendingFrozenDeviceEvents(dev);
    dixFreePrivates(dev.devPrivates, PRIVATE_DEVICE);
    free(dev);
}

/**
 * Shut down all devices of one list and free all resources.
 */
private void CloseDeviceList(DeviceIntPtr* listHead)
{
    if (listHead is null)
        return;

    DeviceIntPtr dev = *listHead;

    /* Used to mark devices that we tried to free */
    bool[MAXDEVICES] freedIds = 0;

    while (dev !is null) {
        freedIds[dev.id] = TRUE;
        DeleteInputDeviceRequest(dev);

        dev = *listHead;
        while (dev !is null && freedIds[dev.id])
            dev = dev.next;
    }
}

/**
 * Shut down all devices, free all resources, etc.
 * Only useful if you're shutting down the server!
 */
void CloseDownDevices()
{
    input_lock();

    /* Float all SDs before closing them. Note that at this point resources
     * (e.g. cursors) have been freed already, so we can't just call
     * AttachDevice(NULL, dev, NULL). Instead, we have to forcibly set master
     * to NULL and pretend nothing happened.
     */
    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
            dev.master = null;
    }

    for (DeviceIntPtr dev = inputInfo.off_devices; dev; dev = dev.next) {
        if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
            dev.master = null;
    }

    CloseDeviceList(&inputInfo.devices);
    CloseDeviceList(&inputInfo.off_devices);

    CloseDevice(inputInfo.pointer);

    CloseDevice(inputInfo.keyboard);

    inputInfo.devices = null;
    inputInfo.off_devices = null;
    inputInfo.keyboard = null;
    inputInfo.pointer = null;

    XkbDeleteRulesDflts();
    XkbDeleteRulesUsed();

    input_unlock();
}

/**
 * Signal all devices that we're in the process of aborting.
 * This function is called from a signal handler.
 */
void AbortDevices()
{
    DeviceIntPtr dev = void;

    /* Do not call input_lock as we don't know what
     * state the input thread might be in, and that could
     * cause a dead-lock.
     */
    mixin(nt_list_for_each_entry!("dev", "inputInfo.devices", "next", q{
        if (!InputDevIsMaster(dev))
            (*dev.deviceProc) (dev, DEVICE_ABORT);
    }));

    mixin(nt_list_for_each_entry!("dev", "inputInfo.off_devices", "next", q{
        if (!InputDevIsMaster(dev))
            (*dev.deviceProc) (dev, DEVICE_ABORT);
    }));
}

/**
 * Remove the cursor sprite for all devices. This needs to be done before any
 * resources are freed or any device is deleted.
 */
void UndisplayDevices()
{
    ScreenPtr masterScreen = dixGetMasterScreen();

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next)
        masterScreen.DisplayCursor(dev, masterScreen, NullCursor);
}

private int CloseOneDevice(const(DeviceIntPtr) dev, DeviceIntPtr* listHead)
{
    for (DeviceIntPtr tmp = *listHead, next = void, prev = null;
        tmp; (prev = tmp), (tmp = next)) {
        next = tmp.next;
        if (tmp == dev) {
            if (prev is null)
                *listHead = next;
            else
                prev.next = next;

            CloseDevice(tmp);
            return Success;
        }
    }
    return BadMatch;
}

/**
 * Remove a device from the device list, closes it and thus frees all
 * resources.
 * Removes both enabled and disabled devices and notifies all devices about
 * the removal of the device.
 *
 * No PresenceNotify is sent for device that the client never saw. This can
 * happen if a calloc fails during the addition of master devices. If
 * dev->init is FALSE it means the client never received a DeviceAdded event,
 * so let's not send a DeviceRemoved event either.
 *
 * @param sendevent True if an XI2 event should be sent.
 */
int RemoveDevice(DeviceIntPtr dev, BOOL sendevent)
{
    DebugF("(dix) removing device %d\n", dev.id);

    if (!dev || dev == inputInfo.keyboard || dev == inputInfo.pointer)
        return BadImplementation;

    int initialized = dev.inited;
    int deviceid = dev.id;
    int[MAXDEVICES] flags = 0;

    if (initialized) {
        if (DevHasCursor(dev)) {
            ScreenPtr masterScreen = dixGetMasterScreen();
            masterScreen.DisplayCursor(dev, masterScreen, NullCursor);
        }

        DisableDevice(dev, sendevent);
        flags[dev.id] = XIDeviceDisabled;
    }

    int flag = InputDevIsMaster(dev) ? XIMasterRemoved : XISlaveRemoved;

    input_lock();

    int ret = BadMatch;
    if ((ret = CloseOneDevice(dev, &inputInfo.devices)) == Success ||
        (ret = CloseOneDevice(dev, &inputInfo.off_devices)) == Success)
        flags[deviceid] = flag;

    input_unlock();

    if (ret == Success && initialized) {
        inputInfo.numDevices--;
        SendDevicePresenceEvent(deviceid, DeviceRemoved);
        if (sendevent)
            XISendDeviceHierarchyEvent(flags.ptr);
    }

    return ret;
}

int NumMotionEvents()
{
    /* only called to fill data in initial connection reply.
     * VCP is ok here, it is the only fixed device we have. */
    return inputInfo.pointer.valuator.numMotionEvents;
}

int dixLookupDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode)
{
    *pDev = null;

    DeviceIntPtr dev = void;
    for (dev = inputInfo.devices; dev; dev = dev.next) {
        if (dev.id == id)
            goto found;
    }
    for (dev = inputInfo.off_devices; dev; dev = dev.next) {
        if (dev.id == id)
            goto found;
    }
    return BadDevice;

found:
    {
        int rc = dixCallDeviceAccessCallback(client, dev, access_mode);
        if (rc == Success)
            *pDev = dev;
        return rc;
    }
}

void QueryMinMaxKeyCodes(KeyCode* minCode, KeyCode* maxCode)
{
    if (inputInfo.keyboard) {
        *minCode = inputInfo.keyboard.key.xkbInfo.desc.min_key_code;
        *maxCode = inputInfo.keyboard.key.xkbInfo.desc.max_key_code;
    }
}

Bool InitButtonClassDeviceStruct(DeviceIntPtr dev, int numButtons, Atom* labels, CARD8* map)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.button !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("numButtons >= MAX_BUTTONS", "FALSE"));

    ButtonClassPtr butc = cast(ButtonClassRec*) calloc(1, ButtonClassRec.sizeof);
    if (!butc)
        return FALSE;
    butc.numButtons = cast(ubyte)numButtons;
    butc.sourceid = dev.id;
    for (int i = 1; i <= numButtons; i++)
        butc.map[i] = map[i];
    for (int i = numButtons + 1; i < MAP_LENGTH; i++)
        butc.map[i] = cast(ubyte)i;
    memcpy(butc.labels.ptr, labels, numButtons * Atom.sizeof);
    dev.button = butc;
    return TRUE;
}

/**
 * Allocate a valuator class and set up the pointers for the axis values
 * appropriately.
 *
 * @param src If non-NULL, the memory is reallocated from src. If NULL, the
 * memory is calloc'd.
 * @parma numAxes Number of axes to allocate.
 * @return The allocated valuator struct.
 */
ValuatorClassPtr AllocValuatorClass(ValuatorClassPtr src, int numAxes)
{
    ValuatorClassPtr v = void;

    /* force alignment with double */
    union align_u {
        _ValuatorClassRec valc = void;
        double d = void;
    }align_u* align_ = void;
    int size = void;

    size =
        cast(int)((align_u).sizeof + numAxes * (double.sizeof + AxisInfo.sizeof));
    align_ = cast(align_u*) realloc(src, size);

    if (!align_)
        return null;

    if (!src)
        memset(align_, 0, size);

    v = &align_.valc;
    v.numAxes = cast(ushort)numAxes;
    v.axisVal = cast(double*) (align_ + 1);
    v.axes = cast(AxisInfoPtr) (v.axisVal + numAxes);

    return v;
}

Bool InitValuatorClassDeviceStruct(DeviceIntPtr dev, int numAxes, Atom* labels, int numMotionEvents, int mode)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("numAxes == 0", "FALSE"));

    if (numAxes > MAX_VALUATORS) {
        LogMessage(X_WARNING,
                   "Device '%s' has %d axes, only using first %d.\n",
                   dev.name, numAxes, MAX_VALUATORS);
        numAxes = MAX_VALUATORS;
    }

    ValuatorClassPtr valc = AllocValuatorClass(null, numAxes);
    if (!valc)
        return FALSE;

    dev.last.scroll = cast(ValuatorMask*)valuator_mask_new(numAxes);
    if (!dev.last.scroll) {
        free(valc);
        return FALSE;
    }

    valc.sourceid = dev.id;
    valc.motion = null;
    valc.first_motion = 0;
    valc.last_motion = 0;
    valc.h_scroll_axis = -1;
    valc.v_scroll_axis = -1;

    valc.numMotionEvents = numMotionEvents;
    valc.motionHintWindow = NullWindow;

    if ((mode & OutOfProximity) && !dev.proximity)
        InitProximityClassDeviceStruct(dev);

    dev.valuator = valc;

    AllocateMotionHistory(dev);

    for (int i = 0; i < numAxes; i++) {
        InitValuatorAxisStruct(dev, i, labels[i], NO_AXIS_LIMITS,
                               NO_AXIS_LIMITS, 0, 0, 0, mode);
        valc.axisVal[i] = 0;
    }

    dev.last.numValuators = numAxes;

    if (InputDevIsMaster(dev) ||        /* do not accelerate master or xtest devices */
        IsXTestDevice(dev, null))
        InitPointerAccelerationScheme(dev, PtrAccelNoOp);
    else
        InitPointerAccelerationScheme(dev, PtrAccelDefault);
    return TRUE;
}

/* global list of acceleration schemes */
ValuatorAccelerationRec[4] pointerAccelerationScheme = [
    {PtrAccelNoOp, null, null, null, null},
    {PtrAccelPredictable, &acceleratePointerPredictable, null,
     &InitPredictableAccelerationScheme, &AccelerationDefaultCleanup},
    {PtrAccelLightweight, &acceleratePointerLightweight, null, null, null},
    {-1, null, null, null, null}        /* terminator */
];

/**
 * install an acceleration scheme. returns TRUE on success, and should not
 * change anything if unsuccessful.
 */
Bool InitPointerAccelerationScheme(DeviceIntPtr dev, int scheme)
{
    ValuatorClassPtr val = dev.valuator;

    if (!val)
        return FALSE;

    if (InputDevIsMaster(dev) && scheme != PtrAccelNoOp)
        return FALSE;

    int i = -1;
    for (int x = 0; pointerAccelerationScheme[x].number >= 0; x++) {
        if (pointerAccelerationScheme[x].number == scheme) {
            i = x;
            break;
        }
    }

    if (-1 == i)
        return FALSE;

    if (val.accelScheme.AccelCleanupProc)
        val.accelScheme.AccelCleanupProc(dev);

    if (pointerAccelerationScheme[i].AccelInitProc) {
        if (!pointerAccelerationScheme[i].AccelInitProc(dev,
                                            &pointerAccelerationScheme[i])) {
            return FALSE;
        }
    }
    else {
        val.accelScheme = pointerAccelerationScheme[i];
    }
    return TRUE;
}

Bool InitFocusClassDeviceStruct(DeviceIntPtr dev)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.focus !is null", "FALSE"));

    FocusClassPtr focc = cast(FocusClassRec*) calloc(1, FocusClassRec.sizeof);
    if (!focc)
        return FALSE;
    UpdateCurrentTimeIf();
    focc.win = PointerRootWin;
    focc.revert = None;
    focc.time = currentTime;
    focc.trace = cast(WindowPtr*) null;
    focc.traceSize = 0;
    focc.traceGood = 0;
    focc.sourceid = dev.id;
    dev.focus = focc;
    return TRUE;
}

Bool InitPtrFeedbackClassDeviceStruct(DeviceIntPtr dev, PtrCtrlProcPtr controlProc)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));

    PtrFeedbackPtr feedc = cast(PtrFeedbackClassRec*) calloc(1, PtrFeedbackClassRec.sizeof);
    if (!feedc)
        return FALSE;
    feedc.CtrlProc = controlProc;
    feedc.ctrl = defaultPointerControl;
    feedc.ctrl.id = 0;
    if ((feedc.next = dev.ptrfeed) !is null)
        feedc.ctrl.id = cast(ubyte)(dev.ptrfeed.ctrl.id + 1);
    dev.ptrfeed = feedc;
    (*controlProc) (dev, &feedc.ctrl);
    return TRUE;
}

private LedCtrl defaultLedControl = {
    DEFAULT_LEDS, DEFAULT_LEDS_MASK, 0
};

private BellCtrl defaultBellControl = {
    DEFAULT_BELL,
    DEFAULT_BELL_PITCH,
    DEFAULT_BELL_DURATION,
    0
};

private IntegerCtrl defaultIntegerControl = {
    DEFAULT_INT_RESOLUTION,
    DEFAULT_INT_MIN_VALUE,
    DEFAULT_INT_MAX_VALUE,
    DEFAULT_INT_DISPLAYED,
    0
};

Bool InitStringFeedbackClassDeviceStruct(DeviceIntPtr dev, StringCtrlProcPtr controlProc, int max_symbols, int num_symbols_supported, KeySym* symbols)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));

    StringFeedbackPtr feedc = cast(StringFeedbackClassRec*) calloc(1, StringFeedbackClassRec.sizeof);
    if (!feedc)
        return FALSE;
    feedc.CtrlProc = controlProc;
    feedc.ctrl.num_symbols_supported = num_symbols_supported;
    feedc.ctrl.num_symbols_displayed = 0;
    feedc.ctrl.max_symbols = max_symbols;
    feedc.ctrl.symbols_supported =
        cast(uint*)calloc(num_symbols_supported, KeySym.sizeof);
    feedc.ctrl.symbols_displayed = cast(uint*)calloc(max_symbols, KeySym.sizeof);
    if (!feedc.ctrl.symbols_supported || !feedc.ctrl.symbols_displayed) {
        free(feedc.ctrl.symbols_supported);
        free(feedc.ctrl.symbols_displayed);
        free(feedc);
        return FALSE;
    }
    for (int i = 0; i < num_symbols_supported; i++)
        *(feedc.ctrl.symbols_supported + i) = *symbols++;
    for (int i = 0; i < max_symbols; i++)
        *(feedc.ctrl.symbols_displayed + i) = cast(KeySym) 0;
    feedc.ctrl.id = 0;
    if ((feedc.next = dev.stringfeed) !is null)
        feedc.ctrl.id = cast(ubyte)(dev.stringfeed.ctrl.id + 1);
    dev.stringfeed = feedc;
    (*controlProc) (dev, &feedc.ctrl);
    return TRUE;
}

Bool InitBellFeedbackClassDeviceStruct(DeviceIntPtr dev, BellProcPtr bellProc, BellCtrlProcPtr controlProc)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));

    BellFeedbackPtr feedc = cast(BellFeedbackClassRec*) calloc(1, BellFeedbackClassRec.sizeof);
    if (!feedc)
        return FALSE;
    feedc.CtrlProc = controlProc;
    feedc.BellProc = bellProc;
    feedc.ctrl = defaultBellControl;
    feedc.ctrl.id = 0;
    if ((feedc.next = dev.bell) !is null)
        feedc.ctrl.id = cast(ubyte)(dev.bell.ctrl.id + 1);
    dev.bell = feedc;
    (*controlProc) (dev, &feedc.ctrl);
    return TRUE;
}

Bool InitLedFeedbackClassDeviceStruct(DeviceIntPtr dev, LedCtrlProcPtr controlProc)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));

    LedFeedbackPtr feedc = cast(LedFeedbackClassRec*) calloc(1, LedFeedbackClassRec.sizeof);
    if (!feedc)
        return FALSE;
    feedc.CtrlProc = controlProc;
    feedc.ctrl = defaultLedControl;
    feedc.ctrl.id = 0;
    if ((feedc.next = dev.leds) !is null)
        feedc.ctrl.id = cast(ubyte)(dev.leds.ctrl.id + 1);
    feedc.xkb_sli = null;
    dev.leds = feedc;
    (*controlProc) (dev, &feedc.ctrl);
    return TRUE;
}

Bool InitIntegerFeedbackClassDeviceStruct(DeviceIntPtr dev, IntegerCtrlProcPtr controlProc)
{
    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));

    IntegerFeedbackPtr feedc = cast(IntegerFeedbackClassRec*) calloc(1, IntegerFeedbackClassRec.sizeof);
    if (!feedc)
        return FALSE;
    feedc.CtrlProc = controlProc;
    feedc.ctrl = defaultIntegerControl;
    feedc.ctrl.id = 0;
    if ((feedc.next = dev.intfeed) !is null)
        feedc.ctrl.id = cast(ubyte)(dev.intfeed.ctrl.id + 1);
    dev.intfeed = feedc;
    (*controlProc) (dev, &feedc.ctrl);
    return TRUE;
}

Bool InitPointerDeviceStruct(DevicePtr device, CARD8* map, int numButtons, Atom* btn_labels, PtrCtrlProcPtr controlProc, int numMotionEvents, int numAxes, Atom* axes_labels)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) device;

    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.button !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.valuator !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.ptrfeed !is null", "FALSE"));

    return (InitButtonClassDeviceStruct(dev, numButtons, btn_labels, map) &&
            InitValuatorClassDeviceStruct(dev, numAxes, axes_labels,
                                          numMotionEvents, Relative) &&
            InitPtrFeedbackClassDeviceStruct(dev, controlProc));
}

/**
 * Sets up multitouch capabilities on @device.
 *
 * @max_touches The maximum number of simultaneous touches, or 0 for unlimited.
 * @mode The mode of the touch device (XIDirectTouch or XIDependentTouch).
 * @num_axes The number of touch valuator axes.
 */
Bool InitTouchClassDeviceStruct(DeviceIntPtr device, uint max_touches, uint mode, uint num_axes)
{
    mixin(BUG_RETURN_VAL!("device is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("device.touch !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("device.valuator is null", "FALSE"));

    /* Check the mode is valid, and at least X and Y axes. */
    mixin(BUG_RETURN_VAL!("mode != XIDirectTouch && mode != XIDependentTouch", "FALSE"));
    mixin(BUG_RETURN_VAL!("num_axes < 2", "FALSE"));

    if (num_axes > MAX_VALUATORS) {
        LogMessage(X_WARNING,
                   "Device '%s' has %d touch axes, only using first %d.\n",
                   device.name, num_axes, MAX_VALUATORS);
        num_axes = MAX_VALUATORS;
    }

    TouchClassPtr touch = cast(TouchClassPtr) calloc(1, TouchClassRec.sizeof);
    if (!touch)
        return FALSE;

    touch.max_touches = cast(ushort)max_touches;
    if (max_touches == 0)
        max_touches = 5;        /* arbitrary number plucked out of the air */
    touch.touches = cast(_TouchPointInfo*)calloc(max_touches, typeof(*touch.touches).sizeof);
    if (!touch.touches)
        goto err;
    touch.num_touches = cast(ushort)max_touches;
    for (int i = 0; i < max_touches; i++)
        TouchInitTouchPoint(touch, device.valuator, i);

    touch.mode = cast(ubyte)mode;
    touch.sourceid = device.id;

    device.touch = touch;
    if (((device.last.touches = cast(_DDXTouchPointInfo*)calloc(max_touches, typeof(*device.last.touches).sizeof)) is null))
        goto err;
    device.last.num_touches = touch.num_touches;
    for (int i = 0; i < touch.num_touches; i++)
        TouchInitDDXTouchPoint(device, &device.last.touches[i]);

    return TRUE;

 err:
    for (int i = 0; i < touch.num_touches; i++)
        TouchFreeTouchPoint(device, i);

    free(touch.touches);
    free(touch);

    device.touch = null;

    return FALSE;
}

/**
 * Sets up gesture capabilities on @device.
 *
 * @max_touches The maximum number of simultaneous touches, or 0 for unlimited.
 */
Bool InitGestureClassDeviceStruct(DeviceIntPtr device, uint max_touches)
{
    mixin(BUG_RETURN_VAL!("device is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("device.gesture !is null", "FALSE"));

    GestureClassPtr g = cast(GestureClassPtr) calloc(1, _GestureClassRec.sizeof);
    if (!g)
        return FALSE;

    g.sourceid = cast(ushort)device.id;
    g.max_touches = cast(ushort)max_touches;
    GestureInitGestureInfo(&g.gesture);

    device.gesture = g;

    return TRUE;
}

/*
 * Check if the given buffer contains elements between low (inclusive) and
 * high (inclusive) only.
 *
 * @return TRUE if the device map is invalid, FALSE otherwise.
 */
Bool BadDeviceMap(BYTE* buff, int length, uint low, uint high, XID* errval)
{
    for (int i = 0; i < length; i++)
        if (buff[i]) {          /* only check non-zero elements */
            if ((low > buff[i]) || (high < buff[i])) {
                *errval = buff[i];
                return TRUE;
            }
        }
    return FALSE;
}

int ProcSetModifierMapping(ClientPtr client)
{
    mixin(REQUEST!xSetModifierMappingReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetModifierMappingReq);

    if (client.req_len != ((stuff.numKeyPerModifier << 1) +
                            bytes_to_int32(xSetModifierMappingReq.sizeof)))
        return BadLength;


    int rc = change_modmap(client, PickKeyboard(client), cast(KeyCode*) &stuff[1],
                       stuff.numKeyPerModifier);
    if (rc == MappingFailed)
        return BadValue;
    if (rc != MappingSuccess && rc != MappingFailed && rc != MappingBusy)
        return rc;

    xSetModifierMappingReply reply = {
        success: cast(ubyte)rc,
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcGetModifierMapping(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    int max_keys_per_mod = 0;
    KeyCode* modkeymap = null;
    generate_modkeymap(client, PickKeyboard(client), &modkeymap,
                       &max_keys_per_mod);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_binary_pad(&rpcbuf, modkeymap, max_keys_per_mod * 8);

    free(modkeymap);

    xGetModifierMappingReply reply = {
        numKeyPerModifier: cast(ubyte)max_keys_per_mod,
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcChangeKeyboardMapping(ClientPtr client)
{
    mixin(REQUEST!xChangeKeyboardMappingReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeKeyboardMappingReq);

    uint len = cast(int)(client.req_len - bytes_to_int32(xChangeKeyboardMappingReq.sizeof));
    if (len != (stuff.keyCodes * stuff.keySymsPerKeyCode))
        return BadLength;

    DeviceIntPtr pDev = PickKeyboard(client);

    if ((stuff.firstKeyCode < pDev.key.xkbInfo.desc.min_key_code) ||
        (stuff.firstKeyCode > pDev.key.xkbInfo.desc.max_key_code)) {
        client.errorValue = cast(uint)stuff.firstKeyCode;
        return BadValue;

    }
    if ((cast(uint) (stuff.firstKeyCode + stuff.keyCodes - 1) >
         pDev.key.xkbInfo.desc.max_key_code) ||
        (stuff.keySymsPerKeyCode == 0)) {
        client.errorValue = cast(uint)stuff.keySymsPerKeyCode;
        return BadValue;
    }

    KeySymsRec keysyms = {
        minKeyCode: cast(ubyte)stuff.firstKeyCode,
        maxKeyCode: cast(ubyte)(stuff.firstKeyCode + stuff.keyCodes - 1),
        mapWidth: stuff.keySymsPerKeyCode,
        map: cast(KeySym*) &stuff[1],
    };

    int rc = dixCallDeviceAccessCallback(client, pDev, DixManageAccess);
    if (rc != Success)
        return rc;

    XkbApplyMappingChange(pDev, &keysyms, stuff.firstKeyCode,
                          stuff.keyCodes, null, client);

    for (DeviceIntPtr tmp = inputInfo.devices; tmp; tmp = tmp.next) {
        if (InputDevIsMaster(tmp) || GetMaster(tmp, MASTER_KEYBOARD) != pDev)
            continue;
        if (!tmp.key)
            continue;

        rc = dixCallDeviceAccessCallback(client, pDev, DixManageAccess);
        if (rc != Success)
            continue;

        XkbApplyMappingChange(tmp, &keysyms, stuff.firstKeyCode,
                              stuff.keyCodes, null, client);
    }

    return Success;
}

int ProcSetPointerMapping(ClientPtr client)
{
    mixin(REQUEST!xSetPointerMappingReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetPointerMappingReq);

    if (client.req_len !=
        bytes_to_int32(((xSetPointerMappingReq).sizeof + stuff.nElts)))
        return BadLength;

    BYTE* map = cast(BYTE*) &stuff[1];
    DeviceIntPtr ptr = PickPointer(client);

    /* So we're bounded here by the number of core buttons.  This check
     * probably wants disabling through XFixes. */
    /* MPX: With ClientPointer, we can return the right number of buttons.
     * Let's just hope nobody changed ClientPointer between GetPointerMapping
     * and SetPointerMapping
     */
    if (stuff.nElts != ptr.button.numButtons) {
        client.errorValue = cast(uint)stuff.nElts;
        return BadValue;
    }

    /* Core protocol specs don't allow for duplicate mappings; this check
     * almost certainly wants disabling through XFixes too. */
    for (int i = 0; i < stuff.nElts; i++) {
        for (int j = i + 1; j < stuff.nElts; j++) {
            if (map[i] && map[i] == map[j]) {
                client.errorValue = cast(uint)map[i];
                return BadValue;
            }
        }
    }

    int ret = ApplyPointerMapping(ptr, map, stuff.nElts, client);

    if (ret == -1)
        return BadValue;
    if (ret != Success && ret != MappingBusy)
        return ret;

    xSetPointerMappingReply reply = {
        success: (ret == MappingBusy) ? MappingBusy : MappingSuccess,
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcGetKeyboardMapping(ClientPtr client)
{
    mixin(REQUEST!xGetKeyboardMappingReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGetKeyboardMappingReq);

    DeviceIntPtr kbd = PickKeyboard(client);
    int rc = dixCallDeviceAccessCallback(client, kbd, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    XkbDescPtr xkb = kbd.key.xkbInfo.desc;

    if ((stuff.firstKeyCode < xkb.min_key_code) ||
        (stuff.firstKeyCode > xkb.max_key_code)) {
        client.errorValue = cast(uint)stuff.firstKeyCode;
        return BadValue;
    }
    if (stuff.firstKeyCode + stuff.count > xkb.max_key_code + 1) {
        client.errorValue = cast(uint)stuff.count;
        return BadValue;
    }

    KeySymsPtr syms = XkbGetCoreMap(kbd);
    if (!syms)
        return BadAlloc;

    const(int) count = syms.mapWidth * stuff.count;

    xGetKeyboardMappingReply reply = {
        keySymsPerKeyCode: cast(ubyte)syms.mapWidth,
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(
        &rpcbuf,
        &syms.map[syms.mapWidth * (stuff.firstKeyCode - syms.minKeyCode)],
        count);

    free(syms.map);
    free(syms);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcGetPointerMapping(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    /* Apps may get different values each time they call GetPointerMapping as
     * the ClientPointer could change. */
    DeviceIntPtr ptr = PickPointer(client);
    int rc = dixCallDeviceAccessCallback(client, ptr, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    ButtonClassPtr butc = ptr.button;
    int nElts = (butc) ? butc.numButtons : 0;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_binary_pad(&rpcbuf, &butc.map[1], nElts);

    xGetPointerMappingReply reply = {
        nElts: cast(ubyte)nElts,
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

void NoteLedState(DeviceIntPtr keybd, int led, Bool on)
{
    KeybdCtrl* ctrl = &keybd.kbdfeed.ctrl;

    if (on)
        ctrl.leds |= (cast(Leds) 1 << (led - 1));
    else
        ctrl.leds &= ~(cast(Leds) 1 << (led - 1));
}

private int DoChangeKeyboardControl(ClientPtr client, DeviceIntPtr keybd, XID* vlist, BITS32 vmask)
{
enum DO_ALL =    (-1);
    int key = DO_ALL;
    int mask = cast(int)vmask;
    KeybdCtrl ctrl = keybd.kbdfeed.ctrl;

    while (vmask) {
        int led = DO_ALL;
        BITS32 index2 = cast(BITS32) mixin(lowbit!vmask);
        vmask &= ~index2;
        switch (cast(ulong)index2) {
        case KBKeyClickPercent:
        {
            int t = cast(INT8) *vlist;
            vlist++;
            if (t == -1) {
                t = defaultKeyboardControl.click;
            }
            else if (t < 0 || t > 100) {
                client.errorValue = cast(uint)t;
                return BadValue;
            }
            ctrl.click = t;
            break;
        }
        case KBBellPercent:
        {
            int t = cast(INT8) *vlist;
            vlist++;
            if (t == -1) {
                t = defaultKeyboardControl.bell;
            }
            else if (t < 0 || t > 100) {
                client.errorValue = cast(uint)t;
                return BadValue;
            }
            ctrl.bell = t;
            break;
        }
        case KBBellPitch:
        {
            int t = cast(INT16) *vlist;
            vlist++;
            if (t == -1) {
                t = defaultKeyboardControl.bell_pitch;
            }
            else if (t < 0) {
                client.errorValue = cast(uint)t;
                return BadValue;
            }
            ctrl.bell_pitch = t;
            break;
        }
        case KBBellDuration:
        {
            int t = cast(INT16) *vlist;
            vlist++;
            if (t == -1)
                t = defaultKeyboardControl.bell_duration;
            else if (t < 0) {
                client.errorValue = cast(uint)t;
                return BadValue;
            }
            ctrl.bell_duration = t;
            break;
        }
        case KBLed:
        {
            led = cast(CARD8) *vlist;
            vlist++;
            if (led < 1 || led > 32) {
                client.errorValue = cast(uint)led;
                return BadValue;
            }
            if (!(mask & KBLedMode))
                return BadMatch;
            break;
        }
        case KBLedMode:
        {
            int t = cast(CARD8) *vlist;
            vlist++;

            if (t == LedModeOff) {
                if (led == DO_ALL)
                    ctrl.leds = 0x0;
                else
                    ctrl.leds &= ~((cast(Leds) (1)) << (led - 1));
            }
            else if (t == LedModeOn) {
                if (led == DO_ALL)
                    ctrl.leds = ~0L;
                else
                    ctrl.leds |= ((cast(Leds) (1)) << (led - 1));
            }
            else {
                client.errorValue = cast(uint)t;
                return BadValue;
            }

            XkbEventCauseRec cause = void;
            mixin(XkbSetCauseCoreReq!("&cause", "X_ChangeKeyboardControl", "client"));
            XkbSetIndicators(keybd, cast(uint)((led == DO_ALL) ? ~0L : (1L << (led - 1))),
                             cast(uint)ctrl.leds, &cause);
            ctrl.leds = keybd.kbdfeed.ctrl.leds;

            break;
        }
        case KBKey:
        {
            key = cast(KeyCode) *vlist;
            vlist++;
            if (cast(KeyCode) key < keybd.key.xkbInfo.desc.min_key_code ||
                cast(KeyCode) key > keybd.key.xkbInfo.desc.max_key_code) {
                client.errorValue = cast(uint)key;
                return BadValue;
            }
            if (!(mask & KBAutoRepeatMode))
                return BadMatch;
            break;
        }
        case KBAutoRepeatMode:
        {
            int i = (key >> 3);
            mask = (1 << (key & 7));
            int t = cast(CARD8) *vlist;
            vlist++;
            if (key != DO_ALL)
                XkbDisableComputedAutoRepeats(keybd, key);
            if (t == AutoRepeatModeOff) {
                if (key == DO_ALL)
                    ctrl.autoRepeat = FALSE;
                else
                    ctrl.autoRepeats[i] &= ~mask;
            }
            else if (t == AutoRepeatModeOn) {
                if (key == DO_ALL)
                    ctrl.autoRepeat = TRUE;
                else
                    ctrl.autoRepeats[i] |= mask;
            }
            else if (t == AutoRepeatModeDefault) {
                if (key == DO_ALL)
                    ctrl.autoRepeat = defaultKeyboardControl.autoRepeat;
                else
                    ctrl.autoRepeats[i] =
                        (ctrl.autoRepeats[i] & ~mask) |
                        (defaultKeyboardControl.autoRepeats[i] & mask);
            }
            else {
                client.errorValue = cast(uint)t;
                return BadValue;
            }
            break;
        }
        default:
            client.errorValue = cast(uint)mask;
            return BadValue;
        }
    }
    keybd.kbdfeed.ctrl = ctrl;

    /* The XKB RepeatKeys control and core protocol global autorepeat */
    /* value are linked */
    XkbSetRepeatKeys(keybd, key, keybd.kbdfeed.ctrl.autoRepeat);

    return Success;

}

/**
 * Changes kbd control on the ClientPointer and all attached SDs.
 */
int ProcChangeKeyboardControl(ClientPtr client)
{
    mixin(REQUEST!xChangeKeyboardControlReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeKeyboardControlReq);

    BITS32 vmask = stuff.mask;
    if (client.req_len !=
        (xChangeKeyboardControlReq.sizeof >> 2) + Ones(vmask))
        return BadLength;

    DeviceIntPtr keyboard = PickKeyboard(client);

    for (DeviceIntPtr pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if ((pDev == keyboard ||
             (!InputDevIsMaster(pDev) && GetMaster(pDev, MASTER_KEYBOARD) == keyboard))
            && pDev.kbdfeed && pDev.kbdfeed.CtrlProc) {
            int ret = dixCallDeviceAccessCallback(client, pDev, DixManageAccess);
            if (ret != Success)
                return ret;
        }
    }

    int error = Success;
    XID* vlist = cast(XID*) &stuff[1];
    for (DeviceIntPtr pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if ((pDev == keyboard ||
             (!InputDevIsMaster(pDev) && GetMaster(pDev, MASTER_KEYBOARD) == keyboard))
            && pDev.kbdfeed && pDev.kbdfeed.CtrlProc) {
            int ret = DoChangeKeyboardControl(client, pDev, vlist, vmask);
            if (ret != Success)
                error = ret;
        }
    }

    return error;
}

int ProcGetKeyboardControl(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    DeviceIntPtr kbd = PickKeyboard(client);
    int rc = dixCallDeviceAccessCallback(client, kbd, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    KeybdCtrl* ctrl = &kbd.kbdfeed.ctrl;
    xGetKeyboardControlReply reply = {
        globalAutoRepeat: cast(ubyte)ctrl.autoRepeat,
        ledMask: cast(uint)ctrl.leds,
        keyClickPercent: cast(ubyte)ctrl.click,
        bellPercent: cast(ubyte)ctrl.bell,
        bellPitch: cast(ubyte)ctrl.bell_pitch,
        bellDuration: cast(ubyte)ctrl.bell_duration
    };
    for (int i = 0; i < 32; i++)
        reply.map[i] = ctrl.autoRepeats[i];

    mixin(X_REPLY_FIELD_CARD32!"ledMask");
    mixin(X_REPLY_FIELD_CARD16!"bellPitch");
    mixin(X_REPLY_FIELD_CARD16!"bellDuration");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcBell(ClientPtr client)
{
    mixin(REQUEST!xBellReq);
    mixin(REQUEST_AT_LEAST_SIZE!xBellReq);

    if (stuff.percent < -100 || stuff.percent > 100) {
        client.errorValue = cast(uint)stuff.percent;
        return BadValue;
    }

    DeviceIntPtr keybd = PickKeyboard(client);
    int base = keybd.kbdfeed.ctrl.bell;
    int newpercent = (base * stuff.percent) / 100;
    if (stuff.percent < 0)
        newpercent = base + newpercent;
    else
        newpercent = base - newpercent + stuff.percent;

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if ((dev == keybd ||
             (!InputDevIsMaster(dev) && GetMaster(dev, MASTER_KEYBOARD) == keybd)) &&
            ((dev.kbdfeed && dev.kbdfeed.BellProc) || dev.xkb_interest)) {

            int rc = dixCallDeviceAccessCallback(client, dev, DixBellAccess);
            if (rc != Success)
                return rc;
            XkbHandleBell(FALSE, FALSE, dev, cast(ubyte)newpercent,
                          &dev.kbdfeed.ctrl, 0, None, null, client);
        }
    }

    return Success;
}

int ProcChangePointerControl(ClientPtr client)
{
    mixin(REQUEST!xChangePointerControlReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangePointerControlReq);

    DeviceIntPtr mouse = PickPointer(client);

    /* If the device has no PtrFeedbackPtr, the xserver has a bug */
    mixin(BUG_RETURN_VAL!("mouse.ptrfeed", "BadImplementation"));

    PtrCtrl ctrl = mouse.ptrfeed.ctrl;
    if ((stuff.doAccel != xTrue) && (stuff.doAccel != xFalse)) {
        client.errorValue = cast(uint)stuff.doAccel;
        return BadValue;
    }
    if ((stuff.doThresh != xTrue) && (stuff.doThresh != xFalse)) {
        client.errorValue = cast(uint)stuff.doThresh;
        return BadValue;
    }
    if (stuff.doAccel) {
        if (stuff.accelNum == -1) {
            ctrl.num = defaultPointerControl.num;
        }
        else if (stuff.accelNum < 0) {
            client.errorValue = cast(uint)stuff.accelNum;
            return BadValue;
        }
        else {
            ctrl.num = stuff.accelNum;
        }

        if (stuff.accelDenum == -1) {
            ctrl.den = defaultPointerControl.den;
        }
        else if (stuff.accelDenum <= 0) {
            client.errorValue = cast(uint)stuff.accelDenum;
            return BadValue;
        }
        else {
            ctrl.den = stuff.accelDenum;
        }
    }
    if (stuff.doThresh) {
        if (stuff.threshold == -1) {
            ctrl.threshold = defaultPointerControl.threshold;
        }
        else if (stuff.threshold < 0) {
            client.errorValue = cast(uint)stuff.threshold;
            return BadValue;
        }
        else {
            ctrl.threshold = stuff.threshold;
        }
    }

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if ((dev == mouse ||
             (!InputDevIsMaster(dev) && GetMaster(dev, MASTER_POINTER) == mouse)) &&
            dev.ptrfeed) {
            int rc = dixCallDeviceAccessCallback(client, dev, DixManageAccess);
            if (rc != Success)
                return rc;
        }
    }

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if ((dev == mouse ||
             (!InputDevIsMaster(dev) && GetMaster(dev, MASTER_POINTER) == mouse)) &&
            dev.ptrfeed) {
            dev.ptrfeed.ctrl = ctrl;
        }
    }

    return Success;
}

int ProcGetPointerControl(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    DeviceIntPtr ptr = PickPointer(client);
    int rc = dixCallDeviceAccessCallback(client, ptr, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    PtrCtrl* ctrl = ( (ptr.ptrfeed) ? &ptr.ptrfeed.ctrl
                                     : &defaultPointerControl);

    xGetPointerControlReply reply = {
        accelNumerator: cast(ushort)ctrl.num,
        accelDenominator: cast(ushort)ctrl.den,
        threshold: cast(ushort)ctrl.threshold
    };

    mixin(X_REPLY_FIELD_CARD16!"accelNumerator");
    mixin(X_REPLY_FIELD_CARD16!"accelDenominator");
    mixin(X_REPLY_FIELD_CARD16!"threshold");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

void MaybeStopHint(DeviceIntPtr dev, ClientPtr client)
{
    GrabPtr grab = dev.deviceGrab.grab;

    if ((grab && mixin(SameClient!("grab", "client")) &&
         ((grab.eventMask & PointerMotionHintMask) ||
          (grab.ownerEvents &&
           (EventMaskForClient(dev.valuator.motionHintWindow, client) &
            PointerMotionHintMask)))) ||
        (!grab &&
         (EventMaskForClient(dev.valuator.motionHintWindow, client) &
          PointerMotionHintMask)))
        dev.valuator.motionHintWindow = NullWindow;
}

int ProcGetMotionEvents(ClientPtr client)
{
    mixin(REQUEST!xGetMotionEventsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGetMotionEventsReq);

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    DeviceIntPtr mouse = PickPointer(client);

    rc = dixCallDeviceAccessCallback(client, mouse, DixReadAccess);
    if (rc != Success)
        return rc;

    UpdateCurrentTimeIf();
    if (mouse.valuator.motionHintWindow)
        MaybeStopHint(mouse, client);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    c_ulong nEvents = 0;
    TimeStamp start = ClientTimeToServerTime(stuff.start);
    TimeStamp stop = ClientTimeToServerTime(stuff.stop);
    if ((CompareTimeStamps(start, stop) != LATER) &&
        (CompareTimeStamps(start, currentTime) != LATER) &&
        mouse.valuator.numMotionEvents) {
        if (CompareTimeStamps(stop, currentTime) == LATER)
            stop = currentTime;

        xTimecoord* coords = null;

        int count = GetMotionHistory(mouse, &coords, start.milliseconds,
                                 stop.milliseconds, pWin.drawable.pScreen,
                                 TRUE);
        int xmin = pWin.drawable.x - mixin(wBorderWidth!("pWin"));
        int xmax = pWin.drawable.x + cast(int) pWin.drawable.width +
            mixin(wBorderWidth!("pWin"));
        int ymin = pWin.drawable.y - mixin(wBorderWidth!("pWin"));
        int ymax = pWin.drawable.y + cast(int) pWin.drawable.height +
            mixin(wBorderWidth!("pWin"));
        for (int i = 0; i < count; i++)
            if ((xmin <= coords[i].x) && (coords[i].x < xmax) &&
                (ymin <= coords[i].y) && (coords[i].y < ymax)) {
                nEvents++;

                /* write xTimecoord */
                x_rpcbuf_write_CARD32(&rpcbuf, coords[i].time);
                x_rpcbuf_write_INT16(&rpcbuf, cast(short)(coords[i].x - pWin.drawable.x));
                x_rpcbuf_write_INT16(&rpcbuf, cast(short)(coords[i].y - pWin.drawable.y));
            }

        free(coords);
    }

    xGetMotionEventsReply reply = {
        nEvents: cast(uint)nEvents,
    };

    mixin(X_REPLY_FIELD_CARD32!"nEvents");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcQueryKeymap(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    xQueryKeymapReply reply = { 0 };

    DeviceIntPtr keybd = PickKeyboard(client);
    int rc = dixCallDeviceAccessCallback(client, keybd, DixReadAccess);
    /* If rc is Success, we're allowed to copy out the keymap.
     * If it's BadAccess, we leave it empty & lie to the client.
     */
    if (rc == Success) {
        CARD8* down = keybd.key.down.ptr;
        for (int i = 0; i < 32; i++)
            reply.map[i] = down[i];
    }
    else if (rc != BadAccess)
        return rc;

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/**
 * Recalculate the number of buttons for the master device. The number of
 * buttons on the master device is equal to the number of buttons on the
 * slave device with the highest number of buttons.
 */
private void RecalculateMasterButtons(DeviceIntPtr slave)
{
    if (!slave.button || InputDevIsMaster(slave))
        return;

    DeviceIntPtr master = GetMaster(slave, MASTER_POINTER);
    if (!master)
        return;

    int maxbuttons = 0;
    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if (InputDevIsMaster(dev) ||
            GetMaster(dev, MASTER_ATTACHED) != master || !dev.button)
            continue;

        maxbuttons = max(maxbuttons, dev.button.numButtons);
    }

    if (master.button && master.button.numButtons != maxbuttons) {
        int last_num_buttons = master.button.numButtons;

        DeviceChangedEvent event = {
            header: ET_Internal,
            type: ET_DeviceChanged,
            time: GetTimeInMillis(),
            deviceid: master.id,
            flags: DEVCHANGE_POINTER_EVENT | DEVCHANGE_DEVICE_CHANGE,
            // .buttons.num_buttons: maxbuttons
        };

        event.buttons.num_buttons = maxbuttons;

        master.button.numButtons = cast(ubyte)maxbuttons;
        if (last_num_buttons < maxbuttons) {
            master.button.xkb_acts = cast(_XkbAction*)XNFreallocarray(master.button.xkb_acts,
                                                       maxbuttons,
                                                       XkbAction.sizeof);
            memset(&master.button.xkb_acts[last_num_buttons],
                   0,
                   (maxbuttons - last_num_buttons) * XkbAction.sizeof);
        }

        memcpy(event.buttons.names.ptr, master.button.labels.ptr, maxbuttons *
               Atom.sizeof);

        if (master.valuator) {
            event.num_valuators = master.valuator.numAxes;
            for (int i = 0; i < event.num_valuators; i++) {
                event.valuators[i].min = master.valuator.axes[i].min_value;
                event.valuators[i].max = master.valuator.axes[i].max_value;
                event.valuators[i].resolution =
                    master.valuator.axes[i].resolution;
                event.valuators[i].mode = master.valuator.axes[i].mode;
                event.valuators[i].name = master.valuator.axes[i].label;
            }
        }

        if (master.key) {
            event.keys.min_keycode = master.key.xkbInfo.desc.min_key_code;
            event.keys.max_keycode = master.key.xkbInfo.desc.max_key_code;
        }

        XISendDeviceChangedEvent(master, &event);
    }
}

/**
 * Generate release events for all keys/button currently down on this
 * device.
 */
void ReleaseButtonsAndKeys(DeviceIntPtr dev)
{
    InternalEvent* eventlist = cast(_InternalEvent*)InitEventList(GetMaximumEventsNum());
    if (!eventlist)             /* no release events for you */
        return;

    /* Release all buttons */
    ButtonClassPtr b = dev.button;
    for (int i = 0; b && i < b.numButtons; i++) {
        if (mixin(BitIsOn!("b.down", "i"))) {
            int nevents = GetPointerEvents(eventlist, dev, ButtonRelease, i, 0, null);
            for (int j = 0; j < nevents; j++)
                mieqProcessDeviceEvent(dev, &eventlist[j], null);
        }
    }

    /* Release all keys */
    KeyClassPtr k = dev.key;
    for (int i = 0; k && i < MAP_LENGTH; i++) {
        if (mixin(BitIsOn!("k.down", "i"))) {
            int nevents = GetKeyboardEvents(eventlist, dev, KeyRelease, i);
            for (int j = 0; j < nevents; j++)
                mieqProcessDeviceEvent(dev, &eventlist[j], null);
        }
    }

    FreeEventList(eventlist, GetMaximumEventsNum());
}

/**
 * Attach device 'dev' to device 'master'.
 * Client is set to the client that issued the request, or NULL if it comes
 * from some internal automatic pairing.
 *
 * Master may be NULL to set the device floating.
 *
 * We don't allow multi-layer hierarchies right now. You can't attach a slave
 * to another slave.
 */
int AttachDevice(ClientPtr client, DeviceIntPtr dev, DeviceIntPtr master)
{
    if (!dev || InputDevIsMaster(dev))
        return BadDevice;

    if (master && !InputDevIsMaster(master))    /* can't attach to slaves */
        return BadDevice;

    /* set from floating to floating? */
    if (InputDevIsFloating(dev) && !master && dev.enabled)
        return Success;

    input_lock();

    /* free the existing sprite. */
    if (InputDevIsFloating(dev) && dev.spriteInfo.paired == dev) {
        ScreenPtr pScreen = miPointerGetScreen(dev);
        pScreen.DeviceCursorCleanup(dev, pScreen);
        free(dev.spriteInfo.sprite);
        dev.spriteInfo.sprite = null;
    }

    dev.master = master;

    /* If device is set to floating, we need to create a sprite for it,
     * otherwise things go bad. However, we don't want to render the cursor,
     * so we reset spriteOwner.
     * Sprite has to be forced to NULL first, otherwise InitializeSprite won't
     * alloc new memory but overwrite the previous one.
     */
    if (!master) {
        WindowPtr currentRoot = void;

        if (dev.spriteInfo.sprite)
            currentRoot = InputDevCurrentRootWindow(dev);
        else                    /* new device auto-set to floating */
            currentRoot = dixGetMasterScreen().root;

        /* we need to init a fake sprite */
        ScreenPtr pScreen = currentRoot.drawable.pScreen;
        pScreen.DeviceCursorInitialize(dev, pScreen);
        dev.spriteInfo.sprite = null;
        InitializeSprite(dev, currentRoot);
        dev.spriteInfo.spriteOwner = FALSE;
        dev.spriteInfo.paired = dev;
    }
    else {
        DeviceIntPtr keyboard = GetMaster(dev, MASTER_KEYBOARD);

        dev.spriteInfo.sprite = master.spriteInfo.sprite;
        dev.spriteInfo.paired = master;
        dev.spriteInfo.spriteOwner = FALSE;

        if (keyboard)
            XkbPushLockedStateToSlaves(keyboard, 0, 0);
        RecalculateMasterButtons(master);
    }

    input_unlock();
    /* XXX: in theory, the MD should change back to its old, original
     * classes when the last SD is detached. Thanks to the XTEST devices,
     * we'll always have an SD attached until the MD is removed.
     * So let's not worry about that.
     */

    return Success;
}

/**
 * Return the device paired with the given device or NULL.
 * Returns the device paired with the parent master if the given device is a
 * slave device.
 */
DeviceIntPtr GetPairedDevice(DeviceIntPtr dev)
{
    if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
        dev = GetMaster(dev, MASTER_ATTACHED);

    return (dev && dev.spriteInfo) ? dev.spriteInfo.paired: null;
}

/**
 * Returns the requested master for this device.
 * The return values are:
 * - MASTER_ATTACHED: the master for this device or NULL for a floating
 *   slave.
 * - MASTER_KEYBOARD: the master keyboard for this device or NULL for a
 *   floating slave
 * - MASTER_POINTER: the master pointer for this device or NULL for a
 *   floating slave
 * - POINTER_OR_FLOAT: the master pointer for this device or the device for
 *   a floating slave
 * - KEYBOARD_OR_FLOAT: the master keyboard for this device or the device for
 *   a floating slave
 *
 * @param which ::MASTER_KEYBOARD or ::MASTER_POINTER, ::MASTER_ATTACHED,
 * ::POINTER_OR_FLOAT or ::KEYBOARD_OR_FLOAT.
 * @return The requested master device
 */
DeviceIntPtr GetMaster(DeviceIntPtr dev, int which)
{
    DeviceIntPtr master = void;

    if (InputDevIsMaster(dev))
        master = dev;
    else {
        master = dev.master;
        if (!master &&
            (which == POINTER_OR_FLOAT || which == KEYBOARD_OR_FLOAT))
            return dev;
    }

    if (!master)
        return null;

    if (which == MASTER_ATTACHED)
        return master;

    if (which == MASTER_KEYBOARD || which == KEYBOARD_OR_FLOAT) {
        if (master.type != MASTER_KEYBOARD)
            return GetPairedDevice(master);
    }
    else {
        if (master.type != MASTER_POINTER)
            return GetPairedDevice(master);
    }

    return master;
}

/**
 * Create a new device pair (== one pointer, one keyboard device).
 * Only allocates the devices, you will need to call ActivateDevice() and
 * EnableDevice() manually.
 * Either a master or a slave device can be created depending on
 * the value for master.
 */
int AllocDevicePair(ClientPtr client, const(char)* name, DeviceIntPtr* ptr, DeviceIntPtr* keybd, DeviceProc ptr_proc, DeviceProc keybd_proc, Bool master)
{
    *ptr = *keybd = null;

    XkbInitPrivates();

    DeviceIntPtr pointer = AddInputDevice(client, ptr_proc, TRUE);

    if (!pointer)
        return BadAlloc;

    char* dev_name = void;
    DeviceIntPtr keyboard = AddInputDevice(client, keybd_proc, TRUE);
    if (asprintf(&dev_name, "%s pointer", name) == -1) {
        goto remove_pointer;
    }
    pointer.name = dev_name;

    pointer.public_.processInputProc = &ProcessOtherEvent;
    pointer.public_.realInputProc = &ProcessOtherEvent;
    XkbSetExtension(pointer, &ProcessPointerEvent);
    pointer.deviceGrab.ActivateGrab = &ActivatePointerGrab;
    pointer.deviceGrab.DeactivateGrab = &DeactivatePointerGrab;
    pointer.coreEvents = TRUE;
    pointer.spriteInfo.spriteOwner = TRUE;

    pointer.lastSlave = null;
    pointer.last.slave = null;
    pointer.type = (master) ? MASTER_POINTER : SLAVE;

    if (!keyboard) {
        goto remove_pointer;
    }

    if (asprintf(&dev_name, "%s keyboard", name) == -1) {
        goto remove_both_devices;
    }
    keyboard.name = dev_name;

    keyboard.public_.processInputProc = &ProcessOtherEvent;
    keyboard.public_.realInputProc = &ProcessOtherEvent;
    XkbSetExtension(keyboard, &ProcessKeyboardEvent);
    keyboard.deviceGrab.ActivateGrab = &ActivateKeyboardGrab;
    keyboard.deviceGrab.DeactivateGrab = &DeactivateKeyboardGrab;
    keyboard.coreEvents = TRUE;
    keyboard.spriteInfo.spriteOwner = FALSE;

    keyboard.lastSlave = null;
    keyboard.last.slave = null;
    keyboard.type = (master) ? MASTER_KEYBOARD : SLAVE;

    /* The ClassesRec stores the device classes currently not used. */
    if (InputDevIsMaster(pointer)) {
        pointer.unused_classes = cast(_ClassesRec*) calloc(1, _ClassesRec.sizeof);
        keyboard.unused_classes = cast(_ClassesRec*) calloc(1, _ClassesRec.sizeof);
        if (!pointer.unused_classes || !keyboard.unused_classes) {
            free(keyboard.unused_classes);
            free(pointer.unused_classes);
            pointer.unused_classes = null;
            keyboard.unused_classes = null;
            goto remove_both_devices;
        }
    }

    *ptr = pointer;
    *keybd = keyboard;

    return Success;

remove_both_devices:
    RemoveDevice(keyboard, FALSE);

remove_pointer:
    RemoveDevice(pointer, FALSE);
    return BadAlloc;
}

/**
 * Return Relative or Absolute for the device.
 */
int valuator_get_mode(DeviceIntPtr dev, int axis)
{
    return (dev.valuator.axes[axis].mode & DeviceMode);
}

/**
 * Set the given mode for the axis. If axis is VALUATOR_MODE_ALL_AXES, then
 * set the mode for all axes.
 */
void valuator_set_mode(DeviceIntPtr dev, int axis, int mode)
{
    if (axis != VALUATOR_MODE_ALL_AXES)
        dev.valuator.axes[axis].mode = cast(ubyte)mode;
    else {
        for (int i = 0; i < dev.valuator.numAxes; i++)
            dev.valuator.axes[i].mode = cast(ubyte)mode;
    }
}

void DeliverDeviceClassesChangedEvent(int sourceid, Time time)
{
    DeviceIntPtr dev = void;
    dixLookupDevice(&dev, sourceid, serverClient, DixWriteAccess);

    if (!dev)
        return;

    /* UpdateFromMaster generates at most one event */
    int num_events = 0;
    InternalEvent dcce;
    UpdateFromMaster(&dcce, dev, DEVCHANGE_POINTER_EVENT, &num_events);
    mixin(BUG_WARN!("num_events > 1"));

    if (num_events) {
        dcce.any.time = time;
        /* FIXME: This doesn't do anything */
        dev.public_.processInputProc(&dcce, dev);
    }
}
