module xf86Events;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1990,91 by Thomas Roell, Dinkelscherben, Germany.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Thomas Roell not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Thomas Roell makes no representations
 * about the suitability of this software for any purpose.  It is provided
 * "as is" without express or implied warranty.
 *
 * THOMAS ROELL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THOMAS ROELL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 */
/*
 * Copyright (c) 1994-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

/* [JCH-96/01/21] Extended std reverse map to four buttons. */
import build.xorg_config;

import core.stdc.errno;
//import x11.X;
//import x11.Xproto;
//import externs.X11.Xatom;
////import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;
//import x11.keysym;
import xf86platformBus;

import dix.dix_priv;
import dix.input_priv;
import include.property;
import hw.xfree86.common.action_priv;
import mi.mi_priv;
import os.log_priv;
import os.inputthread;

import include.misc;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;
import xf86Cursor;
// import xf86platformBus_priv;

static if(build.xlibre_server.XFreeXDGA){
import include.dgaproc;
import hw.xfree86.common.dgaproc_priv;
}

import include.inputstr;
import xf86Xinput_priv;
import mi.mipointer;
import include.xkbsrv;
import include.xkbsrv;
import build.xlibre_server;
import externs.X11.extensions.dpmsconst;
import Xext.dpms;

static if(DPMSExtension) {
//import externs.X11.extensions.dpmsconst;
import Xext.dpmsproc;
}

import hw.xfree86.os_support.linux.systemd_logind;
import seatd_libseat;
import xf86Globals;
import os.utils;
import os.log;
import dix.events;
import dix.devices;
import dix.property;
import hw.xfree86.common.xf86Helper;
import externs.X11.Xatom;
import os.connection;
public import xf86Init;


// void function() xf86OSPMClose;



/*
 * Allow arbitrary drivers or other XFree86 code to register with our main
 * Wakeup handler.
 */
struct x_IHRec {
    int fd;
    InputHandlerProc ihproc;
    void* data;
    Bool enabled;
    Bool is_input;
    x_IHRec* next;
}alias IHRec = x_IHRec;
alias IHPtr = x_IHRec*;

private IHPtr InputHandlers = null;

/*
 * TimeSinceLastInputEvent --
 *      Function used for screensaver purposes by the os module. Returns the
 *      time in milliseconds since there last was any input.
 */
int TimeSinceLastInputEvent()
{
    if (xf86Info.lastEventTime == 0) {
        xf86Info.lastEventTime = cast(int)GetTimeInMillis();
    }
    return cast(int)(GetTimeInMillis() - xf86Info.lastEventTime);
}

/*
 * SetTimeSinceLastInputEvent --
 *      Set the lastEventTime to now.
 */
void SetTimeSinceLastInputEvent()
{
    xf86Info.lastEventTime = cast(int)GetTimeInMillis();
}

/*
 * ProcessInputEvents --
 *      Retrieve all waiting input events and pass them to DIX in their
 *      correct chronological order. Only reads from the system pointer
 *      and keyboard.
 */
void ProcessInputEvents()
{
    int x = void, y = void;

    mieqProcessInputEvents();

    /* FIXME: This is a problem if we have multiple pointers */
    miPointerGetPosition(inputInfo.pointer, &x, &y);

    xf86SetViewport(xf86Info.currentScreen, x, y);
}

/*
 * Handle keyboard events that cause some kind of "action"
 * (i.e., server termination, video mode changes, VT switches, etc.)
 */
void xf86ProcessActionEvent(ActionEvent action, void* arg)
{
    DebugF("ProcessActionEvent(%d,%p)\n", cast(int) action, arg);
    switch (action) {
    case ACTION_TERMINATE:
        if (!xf86Info.dontZap) {
            LogMessageVerb(X_INFO, 1, "Server zapped. Shutting down.\n");
            GiveUp(0);
        }
        break;
    case ACTION_NEXT_MODE:
        if (!xf86Info.dontZoom)
            xf86ZoomViewport(xf86Info.currentScreen, 1);
        break;
    case ACTION_PREV_MODE:
        if (!xf86Info.dontZoom)
            xf86ZoomViewport(xf86Info.currentScreen, -1);
        break;
    case ACTION_SWITCHSCREEN:
        if (!xf86Info.dontVTSwitch && arg) {
            int vtno = *(cast(int*) arg);

            if (vtno != xf86Info.vtno) {
                if (seatd_libseat_controls_session()) {
                    seatd_libseat_switch_session(vtno);
                } else if (!xf86VTActivate(vtno)) {
                    ErrorF("Failed to switch from vt%02d to vt%02d: %s\n",
                           xf86Info.vtno, vtno, strerror(errno));
                }
            }
        }
        break;
    case ACTION_SWITCHSCREEN_NEXT:
        if (!xf86Info.dontVTSwitch) {
            if (seatd_libseat_controls_session()) {
                seatd_libseat_switch_session(xf86Info.vtno + 1);
            } else if (!xf86VTActivate(xf86Info.vtno + 1)) {
                /* If first try failed, assume this is the last VT and
                 * try wrapping around to the first vt.
                 */
                if (!xf86VTActivate(1)) {
                    ErrorF("Failed to switch from vt%02d to next vt: %s\n",
                           xf86Info.vtno, strerror(errno));
                }
            }
        }
        break;
    case ACTION_SWITCHSCREEN_PREV:
        if (!xf86Info.dontVTSwitch && xf86Info.vtno > 0) {
            if (seatd_libseat_controls_session()) {
                seatd_libseat_switch_session(xf86Info.vtno - 1);
            } else if (!xf86VTActivate(xf86Info.vtno - 1)) {
                /* Don't know what the maximum VT is, so can't wrap around */
                ErrorF("Failed to switch from vt%02d to previous vt: %s\n",
                       xf86Info.vtno, strerror(errno));
            }
        }
        break;
    default:
        break;
    }
}

/*
 * xf86Wakeup --
 *      Os wakeup handler.
 */

/* ARGSUSED */
void xf86Wakeup(void* blockData, int err)
{
    if (xf86VTSwitchPending() ||
        (dispatchException & DE_TERMINATE)){
            xf86VTSwitch();
    }
}

/*
 * xf86ReadInput --
 *    input thread handler
 */

private void xf86ReadInput(int fd, int ready, void* closure)
{
    InputInfoPtr pInfo = cast(InputInfoPtr)closure;

    pInfo.read_input(pInfo);
}

/*
 * xf86AddEnabledDevice --
 *
 */
void xf86AddEnabledDevice(InputInfoPtr pInfo)
{
    InputThreadRegisterDev(pInfo.fd, &xf86ReadInput, pInfo);
}

/*
 * xf86RemoveEnabledDevice --
 *
 */
void xf86RemoveEnabledDevice(InputInfoPtr pInfo)
{
    InputThreadUnregisterDev(pInfo.fd);
}

private void xf86ReleaseKeys(DeviceIntPtr pDev)
{
    KeyClassPtr keyc = void;
    int i = void;

    if (!pDev || !pDev.key)
        return;

    keyc = pDev.key;

    /*
     * Hmm... here is the biggest hack of every time !
     * It may be possible that a switch-vt procedure has finished BEFORE
     * you released all keys necessary to do this. That peculiar behavior
     * can fool the X-server pretty much, cause it assumes that some keys
     * were not released. TWM may stuck almost completely....
     * OK, what we are doing here is after returning from the vt-switch
     * explicitly unrelease all keyboard keys before the input-devices
     * are re-enabled.
     */

    for (i = keyc.xkbInfo.desc.min_key_code;
         i < keyc.xkbInfo.desc.max_key_code; i++) {
        if (key_is_down(pDev, i, KEY_POSTED)) {
            input_lock();
            QueueKeyboardEvents(pDev, KeyRelease, i);
            input_unlock();
        }
    }
}

private void xf86DisableInputDeviceForVTSwitch(InputInfoPtr pInfo)
{
    if (!pInfo.dev)
        return;

    if (!pInfo.dev.enabled)
        pInfo.flags |= XI86_DEVICE_DISABLED;

    xf86ReleaseKeys(pInfo.dev);
    ProcessInputEvents();
    DisableDevice(pInfo.dev, TRUE);
    seatd_libseat_close_device(pInfo);
}

void xf86EnableInputDeviceForVTSwitch(InputInfoPtr pInfo)
{
    if (pInfo.dev && (pInfo.flags & XI86_DEVICE_DISABLED) == 0)
        EnableDevice(pInfo.dev, TRUE);
    pInfo.flags &= ~XI86_DEVICE_DISABLED;
}

/*
 * xf86UpdateHasVTProperty --
 *    Update a flag property on the root window to say whether the server VT
 *    is currently the active one as some clients need to know this.
 */
private void xf86UpdateHasVTProperty(Bool hasVT)
{
    int value = hasVT ? 1 : 0;
    int i = void;

    Atom property_name = dixAddAtom(HAS_VT_ATOM_NAME);
    for (i = 0; i < xf86NumScreens; i++) {
        dixChangeWindowProperty(serverClient,
                                xf86ScrnToScreen(xf86Screens[i]).root,
                                property_name, XA_INTEGER, 32,
                                PropModeReplace, 1, &value, TRUE);
    }
}











void xf86EnableGeneralHandler(void* handler) {
    LogMessageVerb(X_WARNING, 0, "Outdated driver still using xf86EnableGeneralHandler() !\n");
    LogMessageVerb(X_WARNING, 0, "File a bug report to driver vendor or use a FOSS driver.\n");
    LogMessageVerb(X_WARNING, 0, "https://forums.developer.nvidia.com/c/gpu-graphics/linux/148\n");
    LogMessageVerb(X_WARNING, 0, "Proprietary drivers are inherently unstable, they just can't be done right.\n");
    _xf86EnableGeneralHandler(handler);
}

void xf86DisableGeneralHandler(void* handler) {
    LogMessageVerb(X_WARNING, 0, "Outdated driver still using xf86DisableGeneralHandler() !\n");
    LogMessageVerb(X_WARNING, 0, "File a bug report to driver vendor or use a FOSS driver.\n");
    LogMessageVerb(X_WARNING, 0, "https://forums.developer.nvidia.com/c/gpu-graphics/linux/148\n");
    LogMessageVerb(X_WARNING, 0, "Proprietary drivers are inherently unstable, they just can't be done right.\n");
    _xf86DisableGeneralHandler(handler);
}

void xf86VTLeave()
{
    int i = void;
    InputInfoPtr pInfo = void;
    IHPtr ih = void;

    DebugF("xf86VTSwitch: Leaving, xf86Exiting is %s\n",
           (dispatchException & DE_TERMINATE) ? "TRUE".ptr : "FALSE".ptr);
static if(DPMSExtension) {
    if (DPMSPowerLevel != DPMSModeOn)
        DPMSSet(serverClient, DPMSModeOn);
}
    for (i = 0; i < xf86NumScreens; i++) {
        if (!(dispatchException & DE_TERMINATE))
            if (xf86Screens[i].EnableDisableFBAccess)
                (*xf86Screens[i].EnableDisableFBAccess) (xf86Screens[i], FALSE);
    }

    /*
     * Keep the order: Disable Device > LeaveVT
     *                        EnterVT > EnableDevice
     */
    for (ih = InputHandlers; ih; ih = ih.next) {
        if (ih.is_input)
            xf86DisableInputHandler(ih);
        else
            _xf86DisableGeneralHandler(ih);
    }
    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next)
        xf86DisableInputDeviceForVTSwitch(pInfo);

    input_lock();
    for (i = 0; i < xf86NumScreens; i++)
        xf86Screens[i].LeaveVT(xf86Screens[i]);
    for (i = 0; i < xf86NumGPUScreens; i++)
        xf86GPUScreens[i].LeaveVT(xf86GPUScreens[i]);

    if (systemd_logind_controls_session()) {
        systemd_logind_drop_master();
    }

    if (!xf86VTSwitchAway())
        goto switch_failed;

    if (xf86OSPMClose)
        xf86OSPMClose();
    xf86OSPMClose = null;

    for (i = 0; i < xf86NumScreens; i++) {
        /*
         * zero all access functions to
         * trap calls when switched away.
         */
        xf86Screens[i].vtSema = FALSE;
    }
    if (xorgHWAccess)
        xf86DisableIO();

    xf86UpdateHasVTProperty(FALSE);

    return;

switch_failed:
    DebugF("xf86VTSwitch: Leave failed\n");
    for (i = 0; i < xf86NumScreens; i++) {
        if (!xf86Screens[i].EnterVT(xf86Screens[i]))
            FatalError("EnterVT failed for screen %d\n", i);
    }
    for (i = 0; i < xf86NumGPUScreens; i++) {
        if (!xf86GPUScreens[i].EnterVT(xf86GPUScreens[i]))
            FatalError("EnterVT failed for gpu screen %d\n", i);
    }
    if (!(dispatchException & DE_TERMINATE)) {
        for (i = 0; i < xf86NumScreens; i++) {
            if (xf86Screens[i].EnableDisableFBAccess)
                (*xf86Screens[i].EnableDisableFBAccess) (xf86Screens[i], TRUE);
        }
    }
    dixSaveScreens(serverClient, SCREEN_SAVER_FORCER, ScreenSaverReset);

    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next)
        xf86EnableInputDeviceForVTSwitch(pInfo);
    for (ih = InputHandlers; ih; ih = ih.next) {
        if (ih.is_input)
            xf86EnableInputHandler(ih);
        else
            _xf86EnableGeneralHandler(ih);
    }
    input_unlock();
}

void xf86VTEnter()
{
    int i = void;
    InputInfoPtr pInfo = void;
    IHPtr ih = void;

    DebugF("xf86VTSwitch: Entering\n");
    if (!xf86VTSwitchTo())
        return;

    xf86OSPMClose = xf86OSPMOpen();

    if (xorgHWAccess)
        xf86EnableIO();
    for (i = 0; i < xf86NumScreens; i++) {
        xf86Screens[i].vtSema = TRUE;
        if (!xf86Screens[i].EnterVT(xf86Screens[i]))
            FatalError("EnterVT failed for screen %d\n", i);
    }
    for (i = 0; i < xf86NumGPUScreens; i++) {
        xf86GPUScreens[i].vtSema = TRUE;
        if (!xf86GPUScreens[i].EnterVT(xf86GPUScreens[i]))
            FatalError("EnterVT failed for gpu screen %d\n", i);
    }
    for (i = 0; i < xf86NumScreens; i++) {
        if (xf86Screens[i].EnableDisableFBAccess)
            (*xf86Screens[i].EnableDisableFBAccess) (xf86Screens[i], TRUE);
    }

    /* Turn screen saver off when switching back */
    dixSaveScreens(serverClient, SCREEN_SAVER_FORCER, ScreenSaverReset);

    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next) {
        /* Devices with server managed fds get enabled on logind/libseat resume */
        if (!(pInfo.flags & XI86_SERVER_FD))
            xf86EnableInputDeviceForVTSwitch(pInfo);
    }

    for (ih = InputHandlers; ih; ih = ih.next) {
        if (ih.is_input)
            xf86EnableInputHandler(ih);
        else
            _xf86EnableGeneralHandler(ih);
    }
static if(XSERVER_PLATFORM_BUS){
    /* check for any new output devices */
    xf86platformVTProbe();
}

    xf86UpdateHasVTProperty(TRUE);

    input_unlock();
}

/*
 * xf86VTSwitch --
 *      Handle requests for switching the vt.
 */
private void xf86VTSwitch()
{
    DebugF("xf86VTSwitch()\n");

    if(!(dispatchException & DE_TERMINATE))
        assert(!seatd_libseat_controls_session());

static if(build.xlibre_server.XFreeXDGA){
    if (!DGAVTSwitch())
        return;
}

    /*
     * Since all screens are currently all in the same state it is sufficient
     * check the first.  This might change in future.
     *
     * VTLeave is always handled here (VT_PROCESS guarantees this is safe),
     * if we use systemd_logind xf86VTEnter() gets called by systemd-logind.c
     * once it has resumed all drm nodes.
     */
    if (xf86VTOwner())
        xf86VTLeave();
    else if (!systemd_logind_controls_session())
        xf86VTEnter();
}

/* Input handler registration */

private void xf86InputHandlerNotify(int fd, int ready, void* data)
{
    IHPtr ih = cast(IHPtr)data;

    if (ih.enabled && ih.fd >= 0 && ih.ihproc) {
        ih.ihproc(ih.fd, ih.data);
    }
}

private void* addInputHandler(int fd, InputHandlerProc proc, void* data)
{
    IHPtr ih = void;

    if (fd < 0 || !proc)
        return null;

    ih = cast(IHPtr)calloc(1, typeof(*ih).sizeof);
    if (!ih)
        return null;

    ih.fd = fd;
    ih.ihproc = proc;
    ih.data = data;
    ih.enabled = TRUE;

    if (!SetNotifyFd(fd, &xf86InputHandlerNotify, X_NOTIFY_READ, ih)) {
        free(ih);
        return null;
    }

    ih.next = InputHandlers;
    InputHandlers = ih;

    return ih;
}

void* xf86AddGeneralHandler(int fd, InputHandlerProc proc, void* data)
{
    IHPtr ih = cast(IHPtr)addInputHandler(fd, proc, data);

    return ih;
}

/**
 * Set the handler for the console's fd. Replaces (and returns) the previous
 * handler or NULL, whichever appropriate.
 * proc may be NULL if the server should not handle events on the console.
 */
InputHandlerProc xf86SetConsoleHandler(InputHandlerProc proc, void* data)
{
    static IHPtr handler = null;
    InputHandlerProc old_proc = null;

    if (handler) {
        old_proc = handler.ihproc;
        xf86RemoveGeneralHandler(handler);
    }

    handler = cast(IHPtr)xf86AddGeneralHandler(xf86Info.consoleFd, proc, data);

    return old_proc;
}

private void removeInputHandler(IHPtr ih)
{
    IHPtr p = void;

    if (ih.fd >= 0)
        RemoveNotifyFd(ih.fd);
    if (ih == InputHandlers)
        InputHandlers = ih.next;
    else {
        p = InputHandlers;
        while (p && p.next != ih)
            p = p.next;
        if (ih && p)
            p.next = ih.next;
    }
    free(ih);
}

int xf86RemoveGeneralHandler(void* handler)
{
    IHPtr ih = void;
    int fd = void;

    if (!handler)
        return -1;

    ih = cast(IHPtr)handler;
    fd = ih.fd;

    removeInputHandler(ih);

    return fd;
}

private void xf86DisableInputHandler(void* handler)
{
    IHPtr ih = void;

    if (!handler)
        return;

    ih = cast(IHPtr)handler;
    ih.enabled = FALSE;
    if (ih.fd >= 0)
        RemoveNotifyFd(ih.fd);
}

private void _xf86DisableGeneralHandler(void* handler)
{
    IHPtr ih = void;

    if (!handler)
        return;

    ih = cast(IHPtr)handler;
    ih.enabled = FALSE;
    if (ih.fd >= 0)
        RemoveNotifyFd(ih.fd);
}

private void xf86EnableInputHandler(void* handler)
{
    IHPtr ih = void;

    if (!handler)
        return;

    ih = cast(IHPtr)handler;
    ih.enabled = TRUE;
    if (ih.fd >= 0)
        SetNotifyFd(ih.fd, &xf86InputHandlerNotify, X_NOTIFY_READ, ih);
}

private void _xf86EnableGeneralHandler(void* handler)
{
    IHPtr ih = void;

    if (!handler)
        return;

    ih = cast(IHPtr)handler;
    ih.enabled = TRUE;
    if (ih.fd >= 0)
        SetNotifyFd(ih.fd, &xf86InputHandlerNotify, X_NOTIFY_READ, ih);
}

void DDXRingBell(int volume, int pitch, int duration)
{
    xf86OSRingBell(volume, pitch, duration);
}

Bool xf86VTOwner()
{
    /* at system startup xf86Screens[0] won't be set - but we will own the VT */
    if (xf86NumScreens == 0)
	return TRUE;
    return xf86Screens[0].vtSema;
}
