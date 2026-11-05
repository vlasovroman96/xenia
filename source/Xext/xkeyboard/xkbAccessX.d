module xkb.xkbAccessX;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
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

static if (!HasVersion!"Windows") {
import core.sys.posix.sys.time;
}
import core.stdc.stdio;
import core.stdc.math;
//import x11.X;
//import x11.Xproto;
import x11.keysymdef;
// import externs.X11.extensions.XKBstr;

import dix.input_priv;
import dix.inpututils_priv;
import os.log_priv;
import xkb.xkbsrv_priv;

import dix.inputstr;
import dix.events;
import externs.X11.extensions.XKBproto;
import include.xkbstr;
import dix.inpututils;
import os.utils;
import os.log;
import os.WaitFor;
import dix.events;
import dix.devices;


int XkbDfltRepeatDelay = 660;
int XkbDfltRepeatInterval = 40;

enum _OFF_TIMER =              0;
enum _KRG_WARN_TIMER =         1;
enum _KRG_TIMER =              2;
enum _SK_TIMEOUT_TIMER =       3;
enum _ALL_TIMEOUT_TIMER =      4;

enum	DFLT_TIMEOUT_CTRLS = (XkbAX_KRGMask|XkbStickyKeysMask|XkbMouseKeysMask);
enum	DFLT_TIMEOUT_OPTS =  (XkbAX_IndicatorFBMask);

ushort XkbDfltAccessXTimeout = 120;
uint XkbDfltAccessXTimeoutMask = DFLT_TIMEOUT_CTRLS;
private uint XkbDfltAccessXTimeoutValues = 0;
private uint XkbDfltAccessXTimeoutOptionsMask = DFLT_TIMEOUT_OPTS;
private uint XkbDfltAccessXTimeoutOptionsValues = 0;
uint XkbDfltAccessXFeedback = XkbAccessXFeedbackMask;
ushort XkbDfltAccessXOptions = XkbAX_AllOptionsMask & ~(XkbAX_IndicatorFBMask | XkbAX_SKReleaseFBMask |
                             XkbAX_SKRejectFBMask);

void AccessXComputeCurveFactor(XkbSrvInfoPtr xkbi, XkbControlsPtr ctrls)
{
    xkbi.mouseKeysCurve = 1.0 + ((cast(double) ctrls.mk_curve) * 0.001);
    xkbi.mouseKeysCurveFactor = ((cast(double) ctrls.mk_max_speed) /
                                  pow(cast(double) ctrls.mk_time_to_max,
                                      xkbi.mouseKeysCurve));
    return;
}

void AccessXInit(DeviceIntPtr keybd)
{
    XkbSrvInfoPtr xkbi = keybd.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;

    xkbi.shiftKeyCount = 0;
    xkbi.mouseKeysCounter = 0;
    xkbi.inactiveKey = 0;
    xkbi.slowKey = 0;
    xkbi.repeatKey = 0;
    xkbi.krgTimerActive = _OFF_TIMER;
    xkbi.beepType = _BEEP_NONE;
    xkbi.beepCount = 0;
    xkbi.mouseKeyTimer = null;
    xkbi.slowKeysTimer = null;
    xkbi.bounceKeysTimer = null;
    xkbi.repeatKeyTimer = null;
    xkbi.krgTimer = null;
    xkbi.beepTimer = null;
    xkbi.checkRepeat = null;
    ctrls.repeat_delay = cast(ushort)XkbDfltRepeatDelay;
    ctrls.repeat_interval = cast(ushort)XkbDfltRepeatInterval;
    ctrls.debounce_delay = 300;
    ctrls.slow_keys_delay = 300;
    ctrls.mk_delay = 160;
    ctrls.mk_interval = 40;
    ctrls.mk_time_to_max = 30;
    ctrls.mk_max_speed = 30;
    ctrls.mk_curve = 500;
    ctrls.mk_dflt_btn = 1;
    ctrls.ax_timeout = XkbDfltAccessXTimeout;
    ctrls.axt_ctrls_mask = XkbDfltAccessXTimeoutMask;
    ctrls.axt_ctrls_values = XkbDfltAccessXTimeoutValues;
    ctrls.axt_opts_mask = cast(ushort)XkbDfltAccessXTimeoutOptionsMask;
    ctrls.axt_opts_values = cast(ushort)XkbDfltAccessXTimeoutOptionsValues;
    if (XkbDfltAccessXTimeout)
        ctrls.enabled_ctrls |= XkbAccessXTimeoutMask;
    else
        ctrls.enabled_ctrls &= ~XkbAccessXTimeoutMask;
    ctrls.enabled_ctrls |= XkbDfltAccessXFeedback;
    ctrls.ax_options = XkbDfltAccessXOptions;
    AccessXComputeCurveFactor(xkbi, ctrls);
    return;
}

/************************************************************************/
/*									*/
/* AccessXKeyboardEvent							*/
/*									*/
/*	Generate a synthetic keyboard event.				*/
/*									*/
/************************************************************************/
private void AccessXKeyboardEvent(DeviceIntPtr keybd, int type, BYTE keyCode, Bool isRepeat)
{
    DeviceEvent event = void;

    init_device_event(&event, keybd, GetTimeInMillis(), EVENT_SOURCE_NORMAL);
    event.type = cast(EventType)type;
    event.detail.key = keyCode;
    event.key_repeat = isRepeat;

    if (xkbDebugFlags & 0x8) {
        DebugF("[xkb] AXKE: Key %d %s\n", keyCode,
               (event.type == ET_KeyPress ? "down".ptr : "up".ptr));
    }

    XkbProcessKeyboardEvent(&event, keybd);
    return;
}                               /* AccessXKeyboardEvent */

/************************************************************************/
/*									*/
/* AccessXKRGTurnOn							*/
/*									*/
/*	Turn the keyboard response group on.				*/
/*									*/
/************************************************************************/
private void AccessXKRGTurnOn(DeviceIntPtr dev, CARD16 KRGControl, xkbControlsNotify* pCN)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    XkbControlsRec old = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    old = *ctrls;
    ctrls.enabled_ctrls |= (KRGControl & XkbAX_KRGMask);
    if (XkbComputeControlsNotify(dev, &old, ctrls, pCN, FALSE))
        XkbSendControlsNotify(dev, pCN);
    cause.kc = pCN.keycode;
    cause.event = pCN.eventType;
    cause.mjr = pCN.requestMajor;
    cause.mnr = pCN.requestMinor;
    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(dev, sli.usesControls, TRUE, null, &cause);
    if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_FeatureFBMask")))
        XkbDDXAccessXBeep(dev, _BEEP_FEATURE_ON, cast(uint)KRGControl);
    return;

}                               /* AccessXKRGTurnOn */

/************************************************************************/
/*									*/
/* AccessXKRGTurnOff							*/
/*									*/
/*	Turn the keyboard response group off.				*/
/*									*/
/************************************************************************/
private void AccessXKRGTurnOff(DeviceIntPtr dev, xkbControlsNotify* pCN)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    XkbControlsRec old = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    old = *ctrls;
    ctrls.enabled_ctrls &= ~XkbAX_KRGMask;
    if (XkbComputeControlsNotify(dev, &old, ctrls, pCN, FALSE))
        XkbSendControlsNotify(dev, pCN);
    cause.kc = pCN.keycode;
    cause.event = pCN.eventType;
    cause.mjr = pCN.requestMajor;
    cause.mnr = pCN.requestMinor;
    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(dev, sli.usesControls, TRUE, null, &cause);
    if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_FeatureFBMask"))) {
        uint changes = old.enabled_ctrls ^ ctrls.enabled_ctrls;

        XkbDDXAccessXBeep(dev, _BEEP_FEATURE_OFF, cast(uint)changes);
    }
    return;

}                               /* AccessXKRGTurnOff */

/************************************************************************/
/*									*/
/* AccessXStickyKeysTurnOn						*/
/*									*/
/*	Turn StickyKeys on.						*/
/*									*/
/************************************************************************/
private void AccessXStickyKeysTurnOn(DeviceIntPtr dev, xkbControlsNotify* pCN)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    XkbControlsRec old = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    old = *ctrls;
    ctrls.enabled_ctrls |= XkbStickyKeysMask;
    xkbi.shiftKeyCount = 0;
    if (XkbComputeControlsNotify(dev, &old, ctrls, pCN, FALSE))
        XkbSendControlsNotify(dev, pCN);
    cause.kc = pCN.keycode;
    cause.event = pCN.eventType;
    cause.mjr = pCN.requestMajor;
    cause.mnr = pCN.requestMinor;
    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(dev, sli.usesControls, TRUE, null, &cause);
    if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_FeatureFBMask"))) {
        XkbDDXAccessXBeep(dev, _BEEP_FEATURE_ON, cast(uint)XkbStickyKeysMask);
    }
    return;

}                               /* AccessXStickyKeysTurnOn */

/************************************************************************/
/*									*/
/* AccessXStickyKeysTurnOff						*/
/*									*/
/*	Turn StickyKeys off.						*/
/*									*/
/************************************************************************/
private void AccessXStickyKeysTurnOff(DeviceIntPtr dev, xkbControlsNotify* pCN)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    XkbControlsRec old = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    old = *ctrls;
    ctrls.enabled_ctrls &= ~XkbStickyKeysMask;
    xkbi.shiftKeyCount = 0;
    if (XkbComputeControlsNotify(dev, &old, ctrls, pCN, FALSE))
        XkbSendControlsNotify(dev, pCN);

    cause.kc = pCN.keycode;
    cause.event = pCN.eventType;
    cause.mjr = pCN.requestMajor;
    cause.mnr = pCN.requestMinor;
    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(dev, sli.usesControls, TRUE, null, &cause);
    if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_FeatureFBMask"))) {
        XkbDDXAccessXBeep(dev, _BEEP_FEATURE_OFF, cast(uint)XkbStickyKeysMask);
    }
version (NO_CLEAR_LATCHES_FOR_STICKY_KEYS_OFF) {} else {
    XkbClearAllLatchesAndLocks(dev, xkbi, FALSE, &cause);
}
    return;
}                               /* AccessXStickyKeysTurnOff */

private CARD32 AccessXKRGExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    xkbControlsNotify cn = { 0 };
    DeviceIntPtr dev = cast(DeviceIntPtr)arg;
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;

    if (xkbi.krgTimerActive == _KRG_WARN_TIMER) {
        XkbDDXAccessXBeep(dev, _BEEP_SLOW_WARN, cast(uint)XkbStickyKeysMask);
        xkbi.krgTimerActive = _KRG_TIMER;
        return 4000;
    }
    xkbi.krgTimerActive = _OFF_TIMER;
    cn.keycode = xkbi.slowKeyEnableKey;
    cn.eventType = KeyPress;
    cn.requestMajor = 0;
    cn.requestMinor = 0;
    if (xkbi.desc.ctrls.enabled_ctrls & XkbSlowKeysMask) {
        AccessXKRGTurnOff(dev, &cn);
        LogMessage(X_INFO, "XKB SlowKeys are disabled.\n");
    }
    else {
        AccessXKRGTurnOn(dev, cast(ushort)XkbSlowKeysMask, &cn);
        LogMessage(X_INFO, "XKB SlowKeys are now enabled. Hold shift to disable.\n");
    }

    xkbi.slowKeyEnableKey = 0;
    return 0;
}

private CARD32 AccessXRepeatKeyExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) arg;
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;

    if (xkbi.repeatKey == 0)
        return 0;

    if (xkbi.checkRepeat is null || xkbi.checkRepeat (dev, xkbi, xkbi.repeatKey))
        AccessXKeyboardEvent(dev, ET_KeyPress, xkbi.repeatKey, TRUE);

    return xkbi.desc.ctrls.repeat_interval;
}

void AccessXCancelRepeatKey(XkbSrvInfoPtr xkbi, KeyCode key)
{
    if (xkbi.repeatKey == key)
        xkbi.repeatKey = 0;
    return;
}

private CARD32 AccessXSlowKeyExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    DeviceIntPtr keybd = void;
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;
    XkbControlsPtr ctrls = void;

    keybd = cast(DeviceIntPtr) arg;
    xkbi = keybd.key.xkbInfo;
    xkb = xkbi.desc;
    ctrls = xkb.ctrls;
    if (xkbi.slowKey != 0) {
        xkbAccessXNotify ev = { 0 };
        KeySym* sym = mixin(XkbKeySymsPtr!("xkb", "xkbi.slowKey"));

        ev.detail = XkbAXN_SKAccept;
        ev.keycode = xkbi.slowKey;
        ev.slowKeysDelay = ctrls.slow_keys_delay;
        ev.debounceDelay = ctrls.debounce_delay;
        XkbSendAccessXNotify(keybd, &ev);
        if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_SKAcceptFBMask")))
            XkbDDXAccessXBeep(keybd, _BEEP_SLOW_ACCEPT, cast(uint)XkbSlowKeysMask);
        AccessXKeyboardEvent(keybd, ET_KeyPress, xkbi.slowKey, FALSE);
        /* check for magic sequences */
        if ((ctrls.enabled_ctrls & XkbAccessXKeysMask) &&
            ((sym[0] == XK_Shift_R) || (sym[0] == XK_Shift_L)))
            xkbi.shiftKeyCount++;

        /* Start repeating if necessary.  Stop autorepeating if the user
         * presses a non-modifier key that doesn't autorepeat.
         */
        if (keybd.kbdfeed.ctrl.autoRepeat &&
            ((xkbi.slowKey != xkbi.mouseKey) || (!xkbi.mouseKeysAccel)) &&
            (ctrls.enabled_ctrls & XkbRepeatKeysMask)) {
            if (mixin(BitIsOn!("keybd.kbdfeed.ctrl.autoRepeats", "xkbi.slowKey"))) {
                xkbi.repeatKey = xkbi.slowKey;
                xkbi.repeatKeyTimer = TimerSet(xkbi.repeatKeyTimer,
                                                0, ctrls.repeat_delay,
                                                &AccessXRepeatKeyExpire,
                                                cast(void*) keybd);
            }
        }
    }
    return 0;
}

private CARD32 AccessXBounceKeyExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    XkbSrvInfoPtr xkbi = (cast(DeviceIntPtr) arg).key.xkbInfo;

    xkbi.inactiveKey = 0;
    return 0;
}

private CARD32 AccessXTimeoutExpire(OsTimerPtr timer, CARD32 now, void* arg)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) arg;
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    XkbControlsRec old = { 0 };
    xkbControlsNotify cn = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    if (xkbi.lastPtrEventTime) {
        uint timeToWait = (ctrls.ax_timeout * 1000);
        uint timeElapsed = cast(uint)(now - xkbi.lastPtrEventTime);

        if (timeToWait > timeElapsed)
            return timeToWait - timeElapsed;
    }
    old = *ctrls;
    xkbi.shiftKeyCount = 0;
    ctrls.enabled_ctrls &= ~ctrls.axt_ctrls_mask;
    ctrls.enabled_ctrls |= (ctrls.axt_ctrls_values & ctrls.axt_ctrls_mask);
    if (ctrls.axt_opts_mask) {
        ctrls.ax_options &= ~ctrls.axt_opts_mask;
        ctrls.ax_options |= (ctrls.axt_opts_values & ctrls.axt_opts_mask);
    }
    if (XkbComputeControlsNotify(dev, &old, ctrls, &cn, FALSE)) {
        cn.keycode = 0;
        cn.eventType = 0;
        cn.requestMajor = 0;
        cn.requestMinor = 0;
        XkbSendControlsNotify(dev, &cn);
    }
    mixin(XkbSetCauseUnknown!("&cause"));
    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(dev, sli.usesControls, TRUE, null, &cause);
    if (ctrls.ax_options != old.ax_options) {
        uint set = void, cleared = void, bell = void;

        set = ctrls.ax_options & (~old.ax_options);
        cleared = (~ctrls.ax_options) & old.ax_options;
        if (set && cleared)
            bell = _BEEP_FEATURE_CHANGE;
        else if (set)
            bell = _BEEP_FEATURE_ON;
        else
            bell = _BEEP_FEATURE_OFF;
        XkbDDXAccessXBeep(dev, bell, cast(uint)XkbAccessXTimeoutMask);
    }
    xkbi.krgTimerActive = _OFF_TIMER;
    return 0;
}

/************************************************************************/
/*									*/
/* AccessXFilterPressEvent						*/
/*									*/
/* Filter events before they get any further if SlowKeys is turned on.	*/
/* In addition, this routine handles the ever so popular magic key	*/
/* acts for turning various accessibility features on/off.		*/
/*									*/
/* Returns TRUE if this routine has discarded the event.		*/
/* Returns FALSE if the event needs further processing.			*/
/*									*/
/************************************************************************/
Bool AccessXFilterPressEvent(DeviceEvent* event, DeviceIntPtr keybd)
{
    XkbSrvInfoPtr xkbi = keybd.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    Bool ignoreKeyEvent = FALSE;
    KeyCode key = cast(ubyte)event.detail.key;
    KeySym* sym = mixin(XkbKeySymsPtr!("xkbi.desc", "key"));

    if (ctrls.enabled_ctrls & XkbAccessXKeysMask) {
        /* check for magic sequences */
        if ((sym[0] == XK_Shift_R) || (sym[0] == XK_Shift_L)) {
            xkbi.slowKeyEnableKey = key;
            if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_SlowWarnFBMask"))) {
                xkbi.krgTimerActive = _KRG_WARN_TIMER;
                xkbi.krgTimer = TimerSet(xkbi.krgTimer, 0, 4000,
                                          &AccessXKRGExpire, cast(void*) keybd);
            }
            else {
                xkbi.krgTimerActive = _KRG_TIMER;
                xkbi.krgTimer = TimerSet(xkbi.krgTimer, 0, 8000,
                                          &AccessXKRGExpire, cast(void*) keybd);
            }
            if (!(ctrls.enabled_ctrls & XkbSlowKeysMask)) {
                CARD32 now = GetTimeInMillis();

                if ((now - xkbi.lastShiftEventTime) > 15000)
                    xkbi.shiftKeyCount = 1;
                else
                    xkbi.shiftKeyCount++;
                xkbi.lastShiftEventTime = now;
            }
        }
        else {
            if (xkbi.krgTimerActive) {
                xkbi.krgTimer = TimerSet(xkbi.krgTimer, 0, 0, null, null);
                xkbi.krgTimerActive = _OFF_TIMER;
            }
        }
    }

    /* Don't transmit the KeyPress if SlowKeys is turned on;
     * The wakeup handler will synthesize one for us if the user
     * has held the key long enough.
     */
    if (ctrls.enabled_ctrls & XkbSlowKeysMask) {
        xkbAccessXNotify ev = { 0 };

        /* If key was already pressed, ignore subsequent press events
         * from the server's autorepeat
         */
        if (xkbi.slowKey == key)
            return TRUE;
        ev.detail = XkbAXN_SKPress;
        ev.keycode = key;
        ev.slowKeysDelay = ctrls.slow_keys_delay;
        ev.debounceDelay = ctrls.debounce_delay;
        XkbSendAccessXNotify(keybd, &ev);
        if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_SKPressFBMask")))
            XkbDDXAccessXBeep(keybd, _BEEP_SLOW_PRESS, cast(uint)XkbSlowKeysMask);
        xkbi.slowKey = key;
        xkbi.slowKeysTimer = TimerSet(xkbi.slowKeysTimer,
                                       0, ctrls.slow_keys_delay,
                                       &AccessXSlowKeyExpire, cast(void*) keybd);
        ignoreKeyEvent = TRUE;
    }

    /* Don't transmit the KeyPress if BounceKeys is turned on
     * and the user pressed the same key within a given time period
     * from the last release.
     */
    else if ((ctrls.enabled_ctrls & XkbBounceKeysMask) &&
             (key == xkbi.inactiveKey)) {
        if (mixin(XkbAX_NeedFeedback!("ctrls", "XkbAX_BKRejectFBMask")))
            XkbDDXAccessXBeep(keybd, _BEEP_BOUNCE_REJECT, cast(uint)XkbBounceKeysMask);
        ignoreKeyEvent = TRUE;
    }

    /* Start repeating if necessary.  Stop autorepeating if the user
     * presses a non-modifier key that doesn't autorepeat.
     */
    if (XkbDDXUsesSoftRepeat(keybd)) {
        if ((keybd.kbdfeed.ctrl.autoRepeat) &&
            ((ctrls.enabled_ctrls & (XkbSlowKeysMask | XkbRepeatKeysMask)) ==
             XkbRepeatKeysMask)) {
            if (mixin(BitIsOn!("keybd.kbdfeed.ctrl.autoRepeats", "key"))) {
                if (xkbDebugFlags & 0x10)
                    DebugF("Starting software autorepeat...\n");
                if (xkbi.repeatKey == key)
                    ignoreKeyEvent = TRUE;
                else {
                    xkbi.repeatKey = key;
                    xkbi.repeatKeyTimer = TimerSet(xkbi.repeatKeyTimer,
                                                    0, ctrls.repeat_delay,
                                                    &AccessXRepeatKeyExpire,
                                                    cast(void*) keybd);
                }
            }
        }
    }

    /* Check for two keys being pressed at the same time.  This section
     * essentially says the following:
     *
     *  If StickyKeys is on, and a modifier is currently being held down,
     *  and one of the following is true:  the current key is not a modifier
     *  or the currentKey is a modifier, but not the only modifier being
     *  held down, turn StickyKeys off if the TwoKeys off ctrl is set.
     */
    if ((ctrls.enabled_ctrls & XkbStickyKeysMask) &&
        (xkbi.state.base_mods != 0) &&
        (mixin(XkbAX_NeedOption!("ctrls", "XkbAX_TwoKeysMask")))) {
        xkbControlsNotify cn = { 0 };

        cn.keycode = key;
        cn.eventType = KeyPress;
        cn.requestMajor = 0;
        cn.requestMinor = 0;
        AccessXStickyKeysTurnOff(keybd, &cn);
    }

    if (!ignoreKeyEvent)
        XkbProcessKeyboardEvent(event, keybd);
    return ignoreKeyEvent;
}                               /* AccessXFilterPressEvent */

/************************************************************************/
/*									*/
/* AccessXFilterReleaseEvent						*/
/*									*/
/* Filter events before they get any further if SlowKeys is turned on.	*/
/* In addition, this routine handles the ever so popular magic key	*/
/* acts for turning various accessibility features on/off.		*/
/*									*/
/* Returns TRUE if this routine has discarded the event.		*/
/* Returns FALSE if the event needs further processing.			*/
/*									*/
/************************************************************************/
Bool AccessXFilterReleaseEvent(DeviceEvent* event, DeviceIntPtr keybd)
{
    XkbSrvInfoPtr xkbi = keybd.key.xkbInfo;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    KeyCode key = cast(ubyte)event.detail.key;
    Bool ignoreKeyEvent = FALSE;

    /* Don't transmit the KeyRelease if BounceKeys is on and
     * this is the release of a key that was ignored due to
     * BounceKeys.
     */
    if (ctrls.enabled_ctrls & XkbBounceKeysMask) {
        if ((key != xkbi.mouseKey) && (!mixin(BitIsOn!("keybd.key.down", "key"))))
            ignoreKeyEvent = TRUE;
        xkbi.inactiveKey = key;
        xkbi.bounceKeysTimer = TimerSet(xkbi.bounceKeysTimer, 0,
                                         ctrls.debounce_delay,
                                         &AccessXBounceKeyExpire,
                                         cast(void*) keybd);
    }

    /* Don't transmit the KeyRelease if SlowKeys is turned on and
     * the user didn't hold the key long enough.  We know we passed
     * the key if the down bit was set by CoreProcessKeyboardEvent.
     */
    if (ctrls.enabled_ctrls & XkbSlowKeysMask) {
        xkbAccessXNotify ev = { 0 };
        uint beep_type = void;
        uint mask = void;

        ev.keycode = key;
        ev.slowKeysDelay = ctrls.slow_keys_delay;
        ev.debounceDelay = ctrls.debounce_delay;
        if (mixin(BitIsOn!("keybd.key.down", "key")) || (xkbi.mouseKey == key)) {
            ev.detail = XkbAXN_SKRelease;
            beep_type = _BEEP_SLOW_RELEASE;
            mask = cast(uint)XkbAX_SKReleaseFBMask;
        }
        else {
            ev.detail = XkbAXN_SKReject;
            beep_type = _BEEP_SLOW_REJECT;
            mask = cast(uint)XkbAX_SKRejectFBMask;
            ignoreKeyEvent = TRUE;
        }
        XkbSendAccessXNotify(keybd, &ev);
        if (mixin(XkbAX_NeedFeedback!("ctrls", "mask"))) {
            XkbDDXAccessXBeep(keybd, beep_type, cast(uint)XkbSlowKeysMask);
        }
        if (xkbi.slowKey == key)
            xkbi.slowKey = 0;
    }

    /* Stop Repeating if the user releases the key that is currently
     * repeating.
     */
    if (xkbi.repeatKey == key) {
        xkbi.repeatKey = 0;
    }

    if ((ctrls.enabled_ctrls & XkbAccessXTimeoutMask) &&
        (ctrls.ax_timeout > 0)) {
        xkbi.lastPtrEventTime = 0;
        xkbi.krgTimer = TimerSet(xkbi.krgTimer, 0,
                                  ctrls.ax_timeout * 1000,
                                  &AccessXTimeoutExpire, cast(void*) keybd);
        xkbi.krgTimerActive = _ALL_TIMEOUT_TIMER;
    }
    else if (xkbi.krgTimerActive != _OFF_TIMER) {
        xkbi.krgTimer = TimerSet(xkbi.krgTimer, 0, 0, null, null);
        xkbi.krgTimerActive = _OFF_TIMER;
    }

    /* Keep track of how many times the Shift key has been pressed.
     * If it has been pressed and released 5 times in a row, toggle
     * the state of StickyKeys.
     */
    if ((!ignoreKeyEvent) && (xkbi.shiftKeyCount)) {
        KeySym* pSym = mixin(XkbKeySymsPtr!("xkbi.desc", "key"));

        if ((pSym[0] != XK_Shift_L) && (pSym[0] != XK_Shift_R)) {
            xkbi.shiftKeyCount = 0;
        }
        else if (xkbi.shiftKeyCount >= 5) {
            xkbControlsNotify cn = { 0 };

            cn.keycode = key;
            cn.eventType = KeyPress;
            cn.requestMajor = 0;
            cn.requestMinor = 0;
            if (ctrls.enabled_ctrls & XkbStickyKeysMask)
                AccessXStickyKeysTurnOff(keybd, &cn);
            else
                AccessXStickyKeysTurnOn(keybd, &cn);
            xkbi.shiftKeyCount = 0;
        }
    }

    if (!ignoreKeyEvent)
        XkbProcessKeyboardEvent(event, keybd);
    return ignoreKeyEvent;

}                               /* AccessXFilterReleaseEvent */

/************************************************************************/
/*									*/
/* ProcessPointerEvent							*/
/*									*/
/* This routine merely sets the shiftKeyCount and clears the keyboard   */
/* response group timer (if necessary) on a mouse event.  This is so	*/
/* multiple shifts with just the mouse and shift-drags with the mouse	*/
/* don't accidentally turn on StickyKeys or the Keyboard Response Group.*/
/*									*/
/************************************************************************/
int xkbDevicePrivateIndex;
void ProcessPointerEvent(InternalEvent* ev, DeviceIntPtr mouse)
{
    XkbSrvInfoPtr xkbi = null;
    uint changed = 0;
    ProcessInputProc backupproc = void;
    xkbDeviceInfoPtr xkbPrivPtr = mixin(XKBDEVICEINFO!("mouse"));
    DeviceEvent* event = &ev.device_event;

    DeviceIntPtr dev = InputDevIsFloating(mouse)
        ? mouse : GetMaster(mouse, MASTER_KEYBOARD);

    if (dev && dev.key) {
        xkbi = dev.key.xkbInfo;
        xkbi.shiftKeyCount = 0;
        xkbi.lastPtrEventTime = cast(uint)event.time;
    }

    if (event.type == ET_ButtonPress) {
        changed |= XkbPointerButtonMask;
    }
    else if (event.type == ET_ButtonRelease) {
        if (InputDevIsMaster(dev)) {
            DeviceIntPtr source = void;
            int rc = void;

            rc = dixLookupDevice(&source, event.sourceid, serverClient,
                    DixWriteAccess);
            if (rc != Success)
                ErrorF("[xkb] bad sourceid '%d' on button release event.\n",
                        event.sourceid);
            else if (!IsXTestDevice(source, GetMaster(dev, MASTER_POINTER))) {
                DeviceIntPtr xtest_device = void;

                xtest_device = GetXTestDevice(GetMaster(dev, MASTER_POINTER));
                if (button_is_down(xtest_device, ev.device_event.detail.button, BUTTON_PROCESSED))
                    XkbFakeDeviceButton(dev, FALSE, event.detail.key);
            }
        }

        if (xkbi)
            xkbi.lockedPtrButtons &= ~(1 << (event.detail.key & 0x7));

        changed |= XkbPointerButtonMask;
    }

    mixin(UNWRAP_PROCESS_INPUT_PROC!("mouse", "xkbPrivPtr", "backupproc"));
    mouse.public_.processInputProc(ev, mouse);
    mixin(COND_WRAP_PROCESS_INPUT_PROC!("mouse", "xkbPrivPtr", "backupproc", "&xkbUnwrapProc"));

    if (!xkbi)
        return;

    xkbi.state.ptr_buttons = (mouse.button) ? mouse.button.state : 0;

    /* clear any latched modifiers */
    if (xkbi.state.latched_mods && (event.type == ET_ButtonRelease)) {
        uint changed_leds = void;
        XkbStateRec oldState = { 0 };
        XkbSrvLedInfoPtr sli = void;

        sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
        oldState = xkbi.state;
        XkbLatchModifiers(dev, 0xFF, 0x00);

        XkbComputeDerivedState(xkbi);
        changed |= XkbStateChangedFlags(&oldState, &xkbi.state);
        if (changed & sli.usedComponents) {
            changed_leds = XkbIndicatorsToUpdate(dev, changed, FALSE);
            if (changed_leds) {
                XkbEventCauseRec cause = { 0 };
                mixin(XkbSetCauseKey!("&cause", "(event.detail.key & 0x7)", "cast(ubyte)event.type"));
                XkbUpdateIndicators(dev, changed_leds, TRUE, null, &cause);
            }
        }
    }

    if (((xkbi.flags & _XkbStateNotifyInProgress) == 0) && (changed != 0)) {
        xkbStateNotify sn = {
            keycode: cast(ubyte)event.detail.key,
            eventType: cast(ubyte)event.type,
            changed: cast(ushort)changed,
        };
        XkbSendStateNotify(dev, &sn);
    }

}                               /* ProcessPointerEvent */
