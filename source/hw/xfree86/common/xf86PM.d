module xf86PM;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2000-2002 by The XFree86 Project, Inc.
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
import build.xorg_config;

//import x11.X;

import xf86_priv;
import hw.xfree86.common.xf86Priv;
import hw.xfree86.os_support.xf86_OSproc;;
import xf86Globals;
import dix.devices;
import os.log;
import os.inputthread;
import dix.window;

int function(int fd, pmEvent* events, int num) xf86PMGetEventFromOs = null;
pmWait function(int fd, pmEvent event) xf86PMConfirmEventToOs = null;

private Bool suspended = False;

private int eventName(pmEvent event, const(char)** str)
{
    switch (event) {
    case XF86_APM_SYS_STANDBY:
        *str = "System Standby Request";
        return 0;
    case XF86_APM_SYS_SUSPEND:
        *str = "System Suspend Request";
        return 0;
    case XF86_APM_CRITICAL_SUSPEND:
        *str = "Critical Suspend";
        return 0;
    case XF86_APM_USER_STANDBY:
        *str = "User System Standby Request";
        return 0;
    case XF86_APM_USER_SUSPEND:
        *str = "User System Suspend Request";
        return 0;
    case XF86_APM_STANDBY_RESUME:
        *str = "System Standby Resume";
        return 0;
    case XF86_APM_NORMAL_RESUME:
        *str = "Normal Resume System";
        return 0;
    case XF86_APM_CRITICAL_RESUME:
        *str = "Critical Resume System";
        return 0;
    case XF86_APM_LOW_BATTERY:
        *str = "Battery Low";
        return 3;
    case XF86_APM_POWER_STATUS_CHANGE:
        *str = "Power Status Change";
        return 3;
    case XF86_APM_UPDATE_TIME:
        *str = "Update Time";
        return 3;
    case XF86_APM_CAPABILITY_CHANGED:
        *str = "Capability Changed";
        return 3;
    case XF86_APM_STANDBY_FAILED:
        *str = "Standby Request Failed";
        return 0;
    case XF86_APM_SUSPEND_FAILED:
        *str = "Suspend Request Failed";
        return 0;
    default:
        *str = "Unknown Event";
        return 0;
    }
}

private void suspend(pmEvent event, Bool undo)
{
    int i = void;
    InputInfoPtr pInfo = void;

    for (i = 0; i < xf86NumScreens; i++) {
        if (xf86Screens[i].EnableDisableFBAccess)
            (*xf86Screens[i].EnableDisableFBAccess) (xf86Screens[i], False);
    }
    pInfo = xf86InputDevs;
    while (pInfo) {
        DisableDevice(pInfo.dev, True);
        pInfo = pInfo.next;
    }
    input_lock();
    for (i = 0; i < xf86NumScreens; i++) {
        if (xf86Screens[i].PMEvent)
            xf86Screens[i].PMEvent(xf86Screens[i], event, undo);
        else {
            xf86Screens[i].LeaveVT(xf86Screens[i]);
            xf86Screens[i].vtSema = False;
        }
    }
}

private void resume(pmEvent event, Bool undo)
{
    int i = void;
    InputInfoPtr pInfo = void;

    for (i = 0; i < xf86NumScreens; i++) {
        if (xf86Screens[i].PMEvent)
            xf86Screens[i].PMEvent(xf86Screens[i], event, undo);
        else {
            xf86Screens[i].vtSema = True;
            xf86Screens[i].EnterVT(xf86Screens[i]);
        }
    }
    input_unlock();
    for (i = 0; i < xf86NumScreens; i++) {
        if (xf86Screens[i].EnableDisableFBAccess)
            (*xf86Screens[i].EnableDisableFBAccess) (xf86Screens[i], True);
    }
    dixSaveScreens(serverClient, SCREEN_SAVER_FORCER, ScreenSaverReset);
    pInfo = xf86InputDevs;
    while (pInfo) {
        EnableDevice(pInfo.dev, True);
        pInfo = pInfo.next;
    }
}

private void DoApmEvent(pmEvent event, Bool undo)
{
    int i = void;

    switch (event) {
version (none) {
    case XF86_APM_SYS_STANDBY:
    case XF86_APM_USER_STANDBY:
}
    case XF86_APM_SYS_SUSPEND:
    case XF86_APM_CRITICAL_SUSPEND:    /*do we want to delay a critical suspend? */
    case XF86_APM_USER_SUSPEND:
        /* should we do this ? */
        if (!undo && !suspended) {
            suspend(event, undo);
            suspended = True;
        }
        else if (undo && suspended) {
            resume(event, undo);
            suspended = False;
        }
        break;
version (none) {
    case XF86_APM_STANDBY_RESUME:
}
    case XF86_APM_NORMAL_RESUME:
    case XF86_APM_CRITICAL_RESUME:
        if (suspended) {
            resume(event, undo);
            suspended = False;
        }
        break;
    default:
        input_lock();
        for (i = 0; i < xf86NumScreens; i++) {
            if (xf86Screens[i].PMEvent) {
                xf86Screens[i].PMEvent(xf86Screens[i], event, undo);
            }
        }
        input_unlock();
        break;
    }
}

enum MAX_NO_EVENTS = 8;

void xf86HandlePMEvents(int fd, void* data)
{
    pmEvent[MAX_NO_EVENTS] events = void;
    int i = void, n = void;
    Bool wait = False;

    if (!xf86PMGetEventFromOs)
        return;

    if ((n = xf86PMGetEventFromOs(fd, events.ptr, MAX_NO_EVENTS)) != 0) {
        do {
            for (i = 0; i < n; i++) {
                const(char)* str = null;
                int verb = eventName(events[i], &str);

                LogMessageVerb(X_INFO, verb, "PM Event received: %s\n", str);
                DoApmEvent(events[i], False);
                switch (xf86PMConfirmEventToOs(fd, events[i])) {
                case PM_WAIT:
                    wait = True;
                    break;
                case PM_CONTINUE:
                    wait = False;
                    break;
                case PM_FAILED:
                    DoApmEvent(events[i], True);
                    wait = False;
                    break;
                default:
                    break;
                }
            }
            if (wait)
                n = xf86PMGetEventFromOs(fd, events.ptr, MAX_NO_EVENTS);
            else
                break;
        } while (1);
    }
}
