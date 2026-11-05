module include.xkbsrv;
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

 
alias SrvXkbFreeKeyboard = XkbFreeKeyboard;			

//public import x11.Xdefs;
// public // //import externs.X11.extensions.XKBproto;

public import include.xlibre_ptrtypes;
// public import externs.X11.extensions.XKBstr;
// public import include.xkbrules;
public import include.inputstr;
import externs.X11.extensions.XKB;
import dix.input;
import include.xkbstr;

// enum string XkbBuildCoreState(string m, string g)=`	((((`~g~`)&0x3)<<13)|((`~m~`)&0xff))`;

struct _XkbInterest {
    DeviceIntPtr dev;
    ClientPtr client;
    XID resource;
    _XkbInterest* next;
    CARD16 extDevNotifyMask;
    CARD16 stateNotifyMask;
    CARD16 namesNotifyMask;
    CARD32 ctrlsNotifyMask;
    CARD8 compatNotifyMask;
    BOOL bellNotifyMask;
    BOOL actionMessageMask;
    CARD16 accessXNotifyMask;
    CARD32 iStateNotifyMask;
    CARD32 iMapNotifyMask;
    CARD16 altSymsNotifyMask;
    CARD32 autoCtrls;
    CARD32 autoCtrlValues;
}alias XkbInterestRec = _XkbInterest;
alias XkbInterestPtr = _XkbInterest*;

struct _XkbRadioGroup {
    CARD8 flags;
    CARD8 nMembers;
    CARD8 dfltDown;
    CARD8 currentDown;
    CARD8[XkbRGMaxMembers] members;
}alias XkbRadioGroupRec = _XkbRadioGroup;
alias XkbRadioGroupPtr = _XkbRadioGroup*;

struct _XkbEventCause {
    CARD8 kc;
    CARD8 event;
    CARD8 mjr;
    CARD8 mnr;
    ClientPtr client;
}alias XkbEventCauseRec = _XkbEventCause;
alias XkbEventCausePtr = _XkbEventCause*;

struct _XkbFilter {
    CARD16 keycode;
    CARD8 what;
    CARD8 active;
    CARD8 filterOthers;
    CARD32 priv;
    XkbAction upAction;
    int function(_XkbSrvInfo*, _XkbFilter*, uint, XkbAction*) @nogc nothrow filter;
    _XkbFilter* next;
}alias XkbFilterRec = _XkbFilter;
alias XkbFilterPtr = _XkbFilter*;

alias XkbSrvCheckRepeatPtr = Bool function(DeviceIntPtr dev, _XkbSrvInfo*, uint);

struct _XkbSrvInfo {
    XkbStateRec prev_state;
    XkbStateRec state;
    XkbDescPtr desc;

    DeviceIntPtr device;
    KbdCtrlProcPtr kbdProc;

    XkbRadioGroupPtr radioGroups;
    CARD8 nRadioGroups;
    CARD8 clearMods;
    CARD8 setMods;
    INT16 groupChange;

    CARD16 dfltPtrDelta;

    double mouseKeysCurve = 0;
    double mouseKeysCurveFactor = 0;
    INT16 mouseKeysDX;
    INT16 mouseKeysDY;
    CARD8 mouseKeysFlags;
    Bool mouseKeysAccel;
    CARD8 mouseKeysCounter;

    CARD8 lockedPtrButtons;
    CARD8 shiftKeyCount;
    KeyCode mouseKey;
    KeyCode inactiveKey;
    KeyCode slowKey;
    KeyCode slowKeyEnableKey;
    KeyCode repeatKey;
    CARD8 krgTimerActive;
    CARD8 beepType;
    CARD8 beepCount;

    CARD32 flags;
    CARD32 lastPtrEventTime;
    CARD32 lastShiftEventTime;
    OsTimerPtr beepTimer;
    OsTimerPtr mouseKeyTimer;
    OsTimerPtr slowKeysTimer;
    OsTimerPtr bounceKeysTimer;
    OsTimerPtr repeatKeyTimer;
    OsTimerPtr krgTimer;

    int szFilters;
    XkbFilterPtr filters;

    XkbSrvCheckRepeatPtr checkRepeat;

    char[256/8] overlay_perkey_state = 0; /* bitfield */
}alias XkbSrvInfoRec = _XkbSrvInfo;
alias XkbSrvInfoPtr = _XkbSrvInfo*;

struct _XkbSrvLedInfo {
    CARD16 flags;
    CARD16 class_;
    CARD16 id;
    union _Fb {
        KbdFeedbackPtr kf;
        LedFeedbackPtr lf;
    }_Fb fb;

    CARD32 physIndicators;
    CARD32 autoState;
    CARD32 explicitState;
    CARD32 effectiveState;

    CARD32 mapsPresent;
    CARD32 namesPresent;
    XkbIndicatorMapPtr maps;
    Atom* names;

    CARD32 usesBase;
    CARD32 usesLatched;
    CARD32 usesLocked;
    CARD32 usesEffective;
    CARD32 usesCompat;
    CARD32 usesControls;

    CARD32 usedComponents;
}alias XkbSrvLedInfoRec = _XkbSrvLedInfo;
alias XkbSrvLedInfoPtr = _XkbSrvLedInfo*;

struct _XkbDeviceInfoRec {
    ProcessInputProc processInputProc;
    /* If processInputProc is set to something different than realInputProc,
     * UNWRAP and COND_WRAP will not touch processInputProc and update only
     * realInputProc.  This ensures that
     *   processInputProc == (frozen ? EnqueueEvent : realInputProc)
     *
     * WRAP_PROCESS_INPUT_PROC should only be called during initialization,
     * since it may destroy this invariant.
     */
    ProcessInputProc realInputProc;
    DeviceUnwrapProc unwrapProc;
}alias xkbDeviceInfoRec = _XkbDeviceInfoRec;
alias xkbDeviceInfoPtr = xkbDeviceInfoRec*;

/***====================================================================***/

alias	Status =		int;

void XkbFreeKeyboard(XkbDescPtr, uint, Bool);

/**
 * @brief get the current keysym map
 *
 * This call might be used after a keyboard mapping has been reloaded
 * with InitKeyboardDeviceStruct() to get the information needed to
 * pass to XkbApplyMappingChange()
 *
 * The returned value is dynamically allocated, and must be
 * freed after use.
 *
 * @param keybd  Keyboard to use to get the map
 *
 * @return keysym map, or NULL if an error occurs
 */
KeySymsPtr XkbGetCoreMap(DeviceIntPtr  /* keybd */
    );

void XkbApplyMappingChange(DeviceIntPtr, KeySymsPtr, KeyCode, CARD8, CARD8*, ClientPtr);

void XkbDDXChangeControls(DeviceIntPtr, XkbControlsPtr, XkbControlsPtr);

/**
 * @brief Set global autorepeat / sync core protocol repeat flags
 *
 * This call performs one of two actions, depending on whether
 * key is set to -1 or not.
 *
 * If the key is set to -1, the global autorepeat setting is
 * set to the value specified in the onoff parameter.
 *
 * If the key is a keycode, the XKB repeat setting for the key is
 * synchronised from the core protocol setting, and the onoff
 * parameter is ignored.
 *
 * @param pxDev Keyboard to use
 * @param key   Keycode, or -1
 * @param onoff One of { AutoRepeatModeOff, AutoRepeatModeOn }
 *              Used only if key == -1
 *
 */
void XkbSetRepeatKeys(DeviceIntPtr, int, int);

// void XkbGetRulesDflts(XkbRMLVOSet*);

// void XkbFreeRMLVOSet(XkbRMLVOSet*, Bool);

void XkbCopyDeviceKeymap(DeviceIntPtr, DeviceIntPtr);

public import include.xkbsrv;
public import include.xkbrules;

                          /* _XKBSRV_H_ */
