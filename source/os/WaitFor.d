module os.WaitFor;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

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

******************************************************************/

/*****************************************************************
 * OS Dependent input routines:
 *
 *  WaitForSomething
 *  TimerForce, TimerSet, TimerFree
 *
 *****************************************************************/

import build.dix_config;
import os.inputthread;

import core.stdc.errno;
import core.stdc.stdio;
import dix.dispatch;

version (Windows) {
//import externs.X11.Xwinsock;
}
// //import x11.Xos;            /* for strings, fcntl, time */
//import x11.X;

import dix.dix_priv;
import dix.screensaver_priv;
import os.busfault;
import os.client_priv;
import os.ossock;
import os.screensaver;

import common.misc;
import os.osdep;
import dix.dixstruct_priv;
// import os.utils;
import os.io;
import os.log;
import dix.events;
import build.xlibre_server;
import externs.X11.extensions.dpmsconst;
import Xext.dpms;
import dix.window;

static if(DPMSExtension) {
import Xext.dpmsproc;
}

version (Windows) {
/* Error codes from windows sockets differ from fileio error codes  */
enum EINTR = WSAEINTR;
enum EINVAL = WSAEINVAL;
enum EBADF = WSAENOTSOCK;
/* Windows select does not set errno. Use GetErrno as wrapper for
   WSAGetLastError */
enum GetErrno = WSAGetLastError;
} else {
/* This is just a fallback to errno to hide the differences between unix and
   Windows in the code */
enum string GetErrno() = `errno`;
}

static if(DPMSExtension) {
//import externs.X11.extensions.dpmsconst;
}

struct _OsTimerRec {
    XList list;
    CARD32 expires;
    CARD32 delta;
    OsTimerCallback callback;
    void* arg;
}



private /*volatile*/ XList timers;

pragma(inline, true) private OsTimerPtr first_timer()
{
    /* inline xorg_list_is_empty which can't handle volatile */
    if (timers.next == &timers)
        return null;
        
    return timers.getFirstEntry!(_OsTimerRec, "list");
}

/*
 * Compute timeout until next timer, running
 * any expired timers
 */
private int check_timers()
{
    OsTimerPtr timer = void;

    if ((timer = first_timer()) !is null) {
        CARD32 now = GetTimeInMillis();
        int timeout = cast(int)(timer.expires - now);

        if (timeout <= 0) {
            DoTimers(now);
        } else {
            /* Make sure the timeout is sane */
            if (timeout < timer.delta + 250)
                return timeout;

            /* time has rewound.  reset the timers. */
            CheckAllTimers();
        }

        return 0;
    }
    return -1;
}

/*****************
 * WaitForSomething:
 *     Make the server suspend until there is
 *	1. data from clients or
 *	2. input events available or
 *	3. ddx notices something of interest (graphics
 *	   queue ready, etc.) or
 *	4. clients that have buffered replies/events are ready
 *
 *     If the time between INPUT events is
 *     greater than ScreenSaverTime, the display is turned off (or
 *     saved, depending on the hardware).  So, WaitForSomething()
 *     has to handle this also (that's why the select() has a timeout.
 *     For more info on ClientsWithInput, see ReadRequestFromClient().
 *     pClientsReady is an array to store ready client->index values into.
 *****************/

Bool WaitForSomething(Bool are_ready)
{
    int i = void;
    int timeout = void;
    int pollerr = void;
    static Bool were_ready;
    Bool timer_is_running = void;

    timer_is_running = were_ready;

    if (were_ready && !are_ready) {
        timer_is_running = FALSE;
        SmartScheduleStopTimer();
    }

    were_ready = FALSE;

    busfault_check();

    /* We need a while loop here to handle
       crashed connections and the screen saver timeout */
    while (1) {
        /* deal with any blocked jobs */
        ProcessWorkQueue();

        timeout = check_timers();
        are_ready = clients_are_ready();

        if (are_ready)
            timeout = 0;

        BlockHandler(&timeout);
        if (NewOutputPending)
            FlushAllOutput();
        /* keep this check close to select() call to minimize race */
        if (dispatchException)
            i = -1;
        else
            i = ospoll_wait(server_poll, timeout);
        pollerr = mixin(GetErrno!());
        WakeupHandler(i);
        if (i <= 0) {           /* An error or timeout occurred */
            if (dispatchException)
                return FALSE;
            if (i < 0) {
                if (pollerr != EINTR && ossock_wouldblock(pollerr)) {
                    ErrorF("WaitForSomething(): poll: %s\n",
                           strerror(pollerr));
                }
            }
        } else
            are_ready = clients_are_ready();

        if (InputCheckPending())
            return FALSE;

        if (are_ready) {
            were_ready = TRUE;
            if (!timer_is_running)
                SmartScheduleStartTimer();
            return TRUE;
        }
    }
}

void AdjustWaitForDelay(void* waitTime, int newdelay)
{
    int* timeoutp = cast(int*)waitTime;
    int timeout = *timeoutp;

    if (timeout < 0 || newdelay < timeout)
        *timeoutp = newdelay;
}

pragma(inline, true) private Bool timer_pending(OsTimerPtr timer) {
    return !timer.list.isEmpty();
}

/* If time has rewound, re-run every affected timer.
 * Timers might drop out of the list, so we have to restart every time. */
private void CheckAllTimers()
{
    CARD32 now = void;

    input_lock();
 start:
    now = GetTimeInMillis();

    foreach(timer; timers.byEntries!OsTimerPtr) {
        if (timer.expires - now > timer.delta + 250) {
            DoTimer(timer, now);
            goto start;
        }
    }
    input_unlock();
}

private void DoTimer(OsTimerPtr timer, CARD32 now)
{
    CARD32 newTime = void;

    timer.list.removeFromList();
    newTime = (*timer.callback) (timer, now, timer.arg);
    if (newTime)
        TimerSet(timer, 0, newTime, timer.callback, timer.arg);
}

void DoTimers(CARD32 now)
{
    OsTimerPtr timer = void;

    input_lock();
    while ((timer = first_timer()) !is null) {
        if (cast(int) (timer.expires - now) > 0)
            break;
        DoTimer(timer, now);
    }
    input_unlock();
}

OsTimerPtr TimerSet(OsTimerPtr timer, int flags, CARD32 millis, OsTimerCallback func, void* arg)
{
    CARD32 now = GetTimeInMillis();

    if (!timer) {
        timer = cast(_OsTimerRec*) calloc(1, _OsTimerRec.sizeof);
        if (!timer)
            return null;
        timer.list.initList();
    }
    else {
        input_lock();
        if (timer_pending(timer)) {
            timer.list.removeFromList();
            if (flags & TimerForceOld)
                cast(void) (*timer.callback) (timer, now, timer.arg);
        }
        input_unlock();
    }
    if (!millis)
        return timer;
    if (flags & TimerAbsolute) {
        timer.delta = millis - now;
    }
    else {
        timer.delta = millis;
        millis += now;
    }
    timer.expires = millis;
    timer.callback = func;
    timer.arg = arg;
    input_lock();

    XList* position = &timers;
    foreach(existing_; timers.byEntries!(OsTimerPtr)) {
        if (cast(int) (existing_.expires - millis) > 0) {
            position = &existing_.list;
            break;
        }
    }
    /* This even works at the end of the list -- existing->list will be timers */
    position.appendList(&timer.list);

    /* Check to see if the timer is ready to run now */
    if (cast(int) (millis - now) <= 0)
        DoTimer(timer, now);

    input_unlock();
    return timer;
}

Bool TimerForce(OsTimerPtr timer)
{
    int pending = void;

    input_lock();
    pending = timer_pending(timer);
    if (pending)
        DoTimer(timer, GetTimeInMillis());
    input_unlock();
    return pending;
}

void TimerCancel(OsTimerPtr timer)
{
    if (!timer)
        return;
    input_lock();
    timer.list.removeFromList();
    input_unlock();
}

void TimerFree(OsTimerPtr timer)
{
    if (!timer)
        return;
    TimerCancel(timer);
    free(timer);
}

void TimerInit()
{
    static Bool been_here;

    if (!been_here) {
        been_here = TRUE;
        timers.initList();
    }

    foreach(timer; timers.byEntriesSafe!OsTimerPtr) {
        timer.list.removeFromList();
        free(timer);
    }
}

static if(DPMSExtension) {

enum string DPMS_CHECK_MODE(string mode,string time) = `
    if (` ~ time ~ ` > 0 && DPMSPowerLevel < ` ~ mode ~ ` && timeout >= ` ~ time ~ `)
	DPMSSet(serverClient, ` ~ mode ~ `);`;

enum string DPMS_CHECK_TIMEOUT(string time) = `
    if (` ~ time ~ ` > 0 && (` ~ time ~ ` - timeout) > 0)
	return ` ~ time ~ ` - timeout;`;

private CARD32 NextDPMSTimeout(INT32 timeout)
{
    /*
     * Return the amount of time remaining until we should set
     * the next power level. Fallthroughs are intentional.
     */
    switch (DPMSPowerLevel) {
    case DPMSModeOn:
        mixin(DPMS_CHECK_TIMEOUT!(`DPMSStandbyTime`));
    goto case;
    case DPMSModeStandby:
        mixin(DPMS_CHECK_TIMEOUT!(`DPMSSuspendTime`));
        /* fallthrough */
    goto case;
    case DPMSModeSuspend:
        mixin(DPMS_CHECK_TIMEOUT!("DPMSOffTime"));
        /* fallthrough */
        goto default;
    default:                   /* DPMSModeOff */
        return 0;
    }
    // default: break;}
}
}                          /* DPMSExtension */

private CARD32 ScreenSaverTimeoutExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    INT32 timeout = now - LastEventTime(XIAllDevices).milliseconds;
    CARD32 nextTimeout = 0;

static if(DPMSExtension) {
    /*
     * Check each mode lowest to highest, since a lower mode can
     * have the same timeout as a higher one.
     */
    if (DPMSEnabled) {
        mixin(DPMS_CHECK_MODE!(`DPMSModeOff`, `DPMSOffTime`));
            mixin(DPMS_CHECK_MODE!(`DPMSModeSuspend`, `DPMSSuspendTime`));
            mixin(DPMS_CHECK_MODE!(`DPMSModeStandby`, `DPMSStandbyTime`));

            nextTimeout = NextDPMSTimeout(timeout);
    }

    /*
     * Only do the screensaver checks if we're not in a DPMS
     * power saving mode
     */
    if (DPMSPowerLevel != DPMSModeOn)
        return nextTimeout;
}                          /* DPMSExtension */

    if (!ScreenSaverTime)
        return nextTimeout;

    if (timeout < ScreenSaverTime) {
        return nextTimeout > 0 ?
            min(ScreenSaverTime - timeout, nextTimeout) :
            ScreenSaverTime - timeout;
    }

    ResetOsBuffers();           /* not ideal, but better than nothing */
    dixSaveScreens(serverClient, SCREEN_SAVER_ON, ScreenSaverActive);

    if (ScreenSaverInterval > 0) {
        nextTimeout = nextTimeout > 0 ?
            min(ScreenSaverInterval, nextTimeout) : ScreenSaverInterval;
    }

    return nextTimeout;
}

private OsTimerPtr ScreenSaverTimer = null;

void FreeScreenSaverTimer()
{
    if (ScreenSaverTimer) {
        TimerFree(ScreenSaverTimer);
        ScreenSaverTimer = null;
    }
}

void SetScreenSaverTimer()
{
    CARD32 timeout = 0;

static if(DPMSExtension) {
    if (DPMSEnabled) {
        /*
         * A higher DPMS level has a timeout that's either less
         * than or equal to that of a lower DPMS level.
         */
        if (DPMSStandbyTime > 0)
            timeout = DPMSStandbyTime;

        else if (DPMSSuspendTime > 0)
            timeout = DPMSSuspendTime;

        else if (DPMSOffTime > 0)
            timeout = DPMSOffTime;
    }
}

    if (ScreenSaverTime > 0) {
        timeout = timeout > 0 ? min(ScreenSaverTime, timeout) : ScreenSaverTime;
    }

static if(SCREENSAVER){
    if (timeout && !screenSaverSuspended) {
        if (timeout) {
            ScreenSaverTimer = TimerSet(ScreenSaverTimer, 0, timeout,
                                        &ScreenSaverTimeoutExpire, null);
        }
        else if (ScreenSaverTimer) {
            FreeScreenSaverTimer();
        }
    }
}
else {
        if (timeout) {
            ScreenSaverTimer = TimerSet(ScreenSaverTimer, 0, timeout,
                                        &ScreenSaverTimeoutExpire, null);
        }
        else if (ScreenSaverTimer) {
            FreeScreenSaverTimer();
        }
    }
}
