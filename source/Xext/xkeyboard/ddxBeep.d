module xkb.ddxBeep;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.

Permission to use, copy, modify, and distribute this
software and its documentation for any purpose and without
fee is hereby granted, provided that the above copyright
notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting
documentation, and that the name of Silicon Graphics not be
used in advertising or publicity pertaining to distribution
of the software without specific prior written permission.
Silicon Graphics makes no representation about the suitability
of this software for any purpose. It is provided "as is"
without any express or implied warranty.

SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

import build.dix_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
import externs.X11.extensions.XKB;

import dix.dix_priv;
import xkb.xkbsrv_priv;

import dix.inputstr;import include.scrnintstr;
import include.windowstr;
import include.xkbsrv;
import os.log;
import os.utils;
import os.WaitFor;
/*#define FALLING_TONE	1*/
/*#define RISING_TONE	1*/
enum FALLING_TONE =	10;
enum RISING_TONE =	10;
enum	SHORT_TONE =	50;
enum	SHORT_DELAY =	60;
enum	LONG_TONE =	75;
enum	VERY_LONG_TONE =	100;
enum	LONG_DELAY =	85;
enum CLICK_DURATION =	1;

enum	DEEP_PITCH =	250;
enum	LOW_PITCH =	500;
enum	MID_PITCH =	1000;
enum	HIGH_PITCH =	2000;
enum CLICK_PITCH =	1500;

private Atom featureOn;
private Atom featureOff;
private Atom featureChange;
private Atom ledOn;
private Atom ledOff;
private Atom ledChange;
private Atom slowWarn;
private Atom slowPress;
private Atom slowReject;
private Atom slowAccept;
private Atom slowRelease;
private Atom stickyLatch;
private Atom stickyLock;
private Atom stickyUnlock;
private Atom bounceReject;
private char doesPitch = 1;

enum	FEATURE_ON =	"AX_FeatureOn";
enum	FEATURE_OFF =	"AX_FeatureOff";
enum	FEATURE_CHANGE =	"AX_FeatureChange";
enum	LED_ON =		"AX_IndicatorOn";
enum	LED_OFF =		"AX_IndicatorOff";
enum	LED_CHANGE =	"AX_IndicatorChange";
enum	SLOW_WARN =	"AX_SlowKeysWarning";
enum	SLOW_PRESS =	"AX_SlowKeyPress";
enum	SLOW_REJECT =	"AX_SlowKeyReject";
enum	SLOW_ACCEPT =	"AX_SlowKeyAccept";
enum	SLOW_RELEASE =	"AX_SlowKeyRelease";
enum	STICKY_LATCH =	"AX_StickyLatch";
enum	STICKY_LOCK =	"AX_StickyLock";
enum	STICKY_UNLOCK =	"AX_StickyUnlock";
enum	BOUNCE_REJECT =	"AX_BounceKeyReject";

private void _XkbDDXBeepInitAtoms()
{
    featureOn = dixAddAtom(FEATURE_ON);
    featureOff = dixAddAtom(FEATURE_OFF);
    featureChange = dixAddAtom(FEATURE_CHANGE);
    ledOn = dixAddAtom(LED_ON);
    ledOff = dixAddAtom(LED_OFF);
    ledChange = dixAddAtom(LED_CHANGE);
    slowWarn = dixAddAtom(SLOW_WARN);
    slowPress = dixAddAtom(SLOW_PRESS);
    slowReject = dixAddAtom(SLOW_REJECT);
    slowAccept = dixAddAtom(SLOW_ACCEPT);
    slowRelease = dixAddAtom(SLOW_RELEASE);
    stickyLatch = dixAddAtom(STICKY_LATCH);
    stickyLock = dixAddAtom(STICKY_LOCK);
    stickyUnlock = dixAddAtom(STICKY_UNLOCK);
    bounceReject = dixAddAtom(BOUNCE_REJECT);
    return;
}

private CARD32 _XkbDDXBeepExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) arg;
    KbdFeedbackPtr feed = void;
    KeybdCtrl* ctrl = void;
    XkbSrvInfoPtr xkbInfo = void;
    CARD32 next = void;
    int pitch = void, duration = void;
    int oldPitch = void, oldDuration = void;
    Atom name = void;

    if ((dev is null) || (dev.key is null) || (dev.key.xkbInfo is null) ||
        (dev.kbdfeed is null))
        return 0;

    _XkbDDXBeepInitAtoms();

    feed = dev.kbdfeed;
    ctrl = &feed.ctrl;
    xkbInfo = dev.key.xkbInfo;
    next = 0;
    pitch = oldPitch = ctrl.bell_pitch;
    duration = oldDuration = ctrl.bell_duration;
    name = None;
    switch (xkbInfo.beepType) {
    default:
        ErrorF("[xkb] Unknown beep type %d\n", xkbInfo.beepType);
        goto case;
    case _BEEP_NONE:
        duration = 0;
        break;

        /* When an LED is turned on, we want a high-pitched beep.
         * When the LED it turned off, we want a low-pitched beep.
         * If we cannot do pitch, we want a single beep for on and two
         * beeps for off.
         */
    case _BEEP_LED_ON:
        if (name == None)
            name = ledOn;
        duration = SHORT_TONE;
        pitch = HIGH_PITCH;
        break;
    case _BEEP_LED_OFF:
        if (name == None)
            name = ledOff;
        duration = SHORT_TONE;
        pitch = LOW_PITCH;
        if (!doesPitch && xkbInfo.beepCount < 1)
            next = SHORT_DELAY;
        break;

        /* When a Feature is turned on, we want an up-siren.
         * When a Feature is turned off, we want a down-siren.
         * If we cannot do pitch, we want a single beep for on and two
         * beeps for off.
         */
    case _BEEP_FEATURE_ON:
        if (name == None)
            name = featureOn;
        if (xkbInfo.beepCount < 1) {
            pitch = LOW_PITCH;
            duration = VERY_LONG_TONE;
            if (doesPitch)
                next = SHORT_DELAY;
        }
        else {
            pitch = MID_PITCH;
            duration = SHORT_TONE;
        }
        break;

    case _BEEP_FEATURE_OFF:
        if (name == None)
            name = featureOff;
        if (xkbInfo.beepCount < 1) {
            pitch = MID_PITCH;
            if (doesPitch)
                duration = VERY_LONG_TONE;
            else
                duration = SHORT_TONE;
            next = SHORT_DELAY;
        }
        else {
            pitch = LOW_PITCH;
            duration = SHORT_TONE;
        }
        break;

        /* Two high beeps indicate an LED or Feature changed
         * state, but that another LED or Feature is also on.
         * [[[WDW - This is not in AccessDOS ]]]
         */
    case _BEEP_LED_CHANGE:
        if (name == None)
            name = ledChange;
            goto case;
    case _BEEP_FEATURE_CHANGE:
        if (name == None)
            name = featureChange;
        duration = SHORT_TONE;
        pitch = HIGH_PITCH;
        if (xkbInfo.beepCount < 1) {
            next = SHORT_DELAY;
        }
        break;

        /* Three high-pitched beeps are the warning that SlowKeys
         * is going to be turned on or off.
         */
    case _BEEP_SLOW_WARN:
        if (name == None)
            name = slowWarn;
        duration = SHORT_TONE;
        pitch = HIGH_PITCH;
        if (xkbInfo.beepCount < 2)
            next = SHORT_DELAY;
        break;

        /* Click on SlowKeys press and accept.
         * Deep pitch when a SlowKey or BounceKey is rejected.
         * [[[WDW - Rejects are not in AccessDOS ]]]
         * If we cannot do pitch, we want single beeps.
         */
    case _BEEP_SLOW_PRESS:
        if (name == None)
            name = slowPress;
            goto case;
    case _BEEP_SLOW_ACCEPT:
        if (name == None)
            name = slowAccept;
            goto case;
    case _BEEP_SLOW_RELEASE:
        if (name == None)
            name = slowRelease;
        duration = CLICK_DURATION;
        pitch = CLICK_PITCH;
        break;
    case _BEEP_BOUNCE_REJECT:
        if (name == None)
            name = bounceReject;
            goto case;
    case _BEEP_SLOW_REJECT:
        if (name == None)
            name = slowReject;
        duration = SHORT_TONE;
        pitch = DEEP_PITCH;
        break;

        /* Low followed by high pitch when a StickyKey is latched.
         * High pitch when a StickyKey is locked.
         * Low pitch when unlocked.
         * If we cannot do pitch, two beeps for latch, nothing for
         * lock, and two for unlock.
         */
    case _BEEP_STICKY_LATCH:
        if (name == None)
            name = stickyLatch;
        duration = SHORT_TONE;
        if (xkbInfo.beepCount < 1) {
            next = SHORT_DELAY;
            pitch = LOW_PITCH;
        }
        else
            pitch = HIGH_PITCH;
        break;
    case _BEEP_STICKY_LOCK:
        if (name == None)
            name = stickyLock;
        if (doesPitch) {
            duration = SHORT_TONE;
            pitch = HIGH_PITCH;
        }
        break;
    case _BEEP_STICKY_UNLOCK:
        if (name == None)
            name = stickyUnlock;
        duration = SHORT_TONE;
        pitch = LOW_PITCH;
        if (!doesPitch && xkbInfo.beepCount < 1)
            next = SHORT_DELAY;
        break;
    }
    if (timer is null && duration > 0) {
        CARD32 starttime = GetTimeInMillis();
        CARD32 elapsedtime = void;

        ctrl.bell_duration = duration;
        ctrl.bell_pitch = pitch;
        if (xkbInfo.beepCount == 0) {
            XkbHandleBell(0, 0, dev, cast(ubyte)ctrl.bell, cast(void*) ctrl,
                          KbdFeedbackClass, name, null, null);
        }
        else if (xkbInfo.desc.ctrls.enabled_ctrls & XkbAudibleBellMask) {
            (*dev.kbdfeed.BellProc) (ctrl.bell, dev, cast(void*) ctrl,
                                       KbdFeedbackClass);
        }
        ctrl.bell_duration = oldDuration;
        ctrl.bell_pitch = oldPitch;
        xkbInfo.beepCount++;

        /* Some DDX schedule the beep and return immediately, others don't
           return until the beep is completed.  We measure the time and if
           it's less than the beep duration, make sure not to schedule the
           next beep until after the current one finishes. */

        elapsedtime = GetTimeInMillis();
        if (elapsedtime > starttime) {  /* watch out for millisecond counter
                                           overflow! */
            elapsedtime -= starttime;
        }
        else {
            elapsedtime = 0;
        }
        if (elapsedtime < duration) {
            next += duration - elapsedtime;
        }

    }
    return next;
}

int XkbDDXAccessXBeep(DeviceIntPtr dev, uint what, uint which)
{
    XkbSrvInfoRec* xkbInfo = dev.key.xkbInfo;
    CARD32 next = void;

    xkbInfo.beepType = cast(ubyte)what;
    xkbInfo.beepCount = 0;
    next = _XkbDDXBeepExpire(null, 0, cast(void*) dev);
    if (next > 0) {
        xkbInfo.beepTimer = TimerSet(xkbInfo.beepTimer,
                                      0, next,
                                      &_XkbDDXBeepExpire, cast(void*) dev);
    }
    return 1;
}
