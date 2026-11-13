module xkb.xkbsrv_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 1993 Silicon Graphics Computer Systems, Inc.
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;
//public import x11.Xmd;

public import xkb.xkbrules_priv;

public import dix.input;
public import dix.privates;
public import xkb.xkbsrv_priv;
public import xkb.xkbsrv_priv;
import externs.X11.extensions.XKBproto;
import xkb.xkbstr;
public import build.dix_config;
public import xkb.xkbInit;

alias SrvXkbFreeKeyboard = XkbFreeKeyboard;			

//public import x11.Xdefs;
// public // //import externs.X11.extensions.XKBproto;

public import common.xlibre_ptrtypes;
// public import externs.X11.extensions.XKBstr;
// public import include.xkbrules;
public import dix.inputstr;
import externs.X11.extensions.XKB;
import dix.input;
import xkb.xkbstr;

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

public import xkb.xkbsrv_priv;
public import include.xkbrules;

                          /* _XKBSRV_H_ */


enum _BEEP_NONE =              0;
enum _BEEP_FEATURE_ON =        1;
enum _BEEP_FEATURE_OFF =       2;
enum _BEEP_FEATURE_CHANGE =    3;
enum _BEEP_SLOW_WARN =         4;
enum _BEEP_SLOW_PRESS =        5;
enum _BEEP_SLOW_ACCEPT =       6;
enum _BEEP_SLOW_REJECT =       7;
enum _BEEP_SLOW_RELEASE =      8;
enum _BEEP_STICKY_LATCH =      9;
enum _BEEP_STICKY_LOCK =       10;
enum _BEEP_STICKY_UNLOCK =     11;
enum _BEEP_LED_ON =            12;
enum _BEEP_LED_OFF =           13;
enum _BEEP_LED_CHANGE =        14;
enum _BEEP_BOUNCE_REJECT =     15;

enum string XkbSetCauseKey(string c,string k,string e) = `{ (` ~ c ~ `).kc= cast(ubyte)(` ~ k ~ `),(` ~ c ~ `).event= (` ~ e ~ `),
                                  (` ~ c ~ `).mjr= (` ~ c ~ `).mnr= 0; 
                                  (` ~ c ~ `).client= null; }`;
enum string XkbSetCauseReq(string c,string j,string n,string cl) = `{ (` ~ c ~ `).kc= (` ~ c ~ `).event= 0,
                                  (` ~ c ~ `).mjr= cast(ubyte)(` ~ j ~ `),(` ~ c ~ `).mnr= cast(ubyte)(` ~ n ~ `);
                                  (` ~ c ~ `).client= (` ~ cl ~ `); }`;
enum string XkbSetCauseCoreReq(string c,string e,string cl) = `` ~ XkbSetCauseReq!(c,e,`0`,cl) ~ ``;
enum string XkbSetCauseXkbReq(string c,string e,string cl) = `` ~ XkbSetCauseReq!(c,`XkbReqCode`,e,cl) ~ ``;
enum string XkbSetCauseUnknown(string c) = `` ~ XkbSetCauseKey!(c,`0`,`0`) ~ ``;

enum XkbSLI_IsDefault =        (1L<<0);
enum XkbSLI_HasOwnState =      (1L<<1);

enum XkbAX_KRGMask =    (XkbSlowKeysMask|XkbBounceKeysMask);
enum XkbAllFilteredEventsMask = 
        (XkbAccessXKeysMask|XkbRepeatKeysMask|XkbMouseKeysAccelMask|XkbAX_KRGMask);

/*
 * Settings for xkbClientFlags field (used by DIX)
 * These flags _must_ not overlap with XkbPCF_*
 */
enum _XkbClientInitialized =           (1<<7);
enum _XkbClientIsAncient =             (1<<6);

/*
 * Settings for flags field
 */
enum _XkbStateNotifyInProgress =       (1<<0);

//#define _XkbLibError(c,l,d)     /* Epoch fail */

/* "a" is a "unique" numeric identifier that just defines which error
 * code statement it is. _XkbErrCode2(4, foo) means "this is the 4th error
 * statement in this function". lovely.
 */
enum string _XkbErrCode2(string a,string b) = `(cast(XID)(((cast(uint)(` ~ a ~ `))<<24)|((` ~ b ~ `)&0xffffff)))`;
enum string _XkbErrCode3(string a,string b,string c) = `` ~ _XkbErrCode2!(a,`((cast(uint)(` ~ b ~ `))<<16)|(` ~ c ~ `)`);
enum string _XkbErrCode4(string a,string b,string c,string d) = _XkbErrCode3!(a,b,`(((cast(uint)(` ~ c ~ `))<<8)|(` ~ d ~ `))`);

enum string WRAP_PROCESS_INPUT_PROC(string device, string oldprocs, string proc, string unwrapproc) = `
        ` ~ device ~ `.public_.processInputProc = ` ~ proc ~ `; 
        ` ~ oldprocs ~ `.processInputProc = 
        ` ~ oldprocs ~ `.realInputProc = ` ~ device ~ `.public_.realInputProc; 
        ` ~ device ~ `.public_.realInputProc = ` ~ proc ~ `; 
        ` ~ oldprocs ~ `.unwrapProc = ` ~ device ~ `.unwrapProc; 
        ` ~ device ~ `.unwrapProc = ` ~ unwrapproc ~ `;`;

enum string COND_WRAP_PROCESS_INPUT_PROC(string device, string oldprocs, string proc, string unwrapproc) = `
        if (` ~ device ~ `.public_.processInputProc == ` ~ device ~ `.public_.realInputProc)
            ` ~ device ~ `.public_.processInputProc = ` ~ proc ~ `; 
        ` ~ oldprocs ~ `.processInputProc = 
        ` ~ oldprocs ~ `.realInputProc = ` ~ device ~ `.public_.realInputProc; 
        ` ~ device ~ `.public_.realInputProc = ` ~ proc ~ `; 
        ` ~ oldprocs ~ `.unwrapProc = ` ~ device ~ `.unwrapProc; 
        ` ~ device ~ `.unwrapProc = ` ~ unwrapproc ~ `;`;

enum string UNWRAP_PROCESS_INPUT_PROC(string device, string oldprocs, string backupproc) = `
        ` ~ backupproc ~ ` = ` ~ device ~ `.public_.realInputProc; 
        if (` ~ device ~ `.public_.processInputProc == ` ~ device ~ `.public_.realInputProc)
            ` ~ device ~ `.public_.processInputProc = ` ~ oldprocs ~ `.realInputProc; 
        ` ~ device ~ `.public_.realInputProc = ` ~ oldprocs ~ `.realInputProc; 
        ` ~ device ~ `.unwrapProc = ` ~ oldprocs ~ `.unwrapProc;`;

RESTYPE RT_XKBCLIENT;

void xkbUnwrapProc(DeviceIntPtr, DeviceHandleProc, void*);

void XkbForceUpdateDeviceLEDs(DeviceIntPtr keybd);

void XkbPushLockedStateToSlaves(DeviceIntPtr master, int evtype, int key);

Bool XkbCopyKeymap(XkbDescPtr dst, XkbDescPtr src);

void XkbFilterEvents(ClientPtr pClient, int nEvents, xEvent* xE);

int XkbGetEffectiveGroup(XkbSrvInfoPtr xkbi, XkbStatePtr xkbstate, CARD8 keycode);

void XkbMergeLockedPtrBtns(DeviceIntPtr master);

void XkbFakeDeviceButton(DeviceIntPtr dev, int press, int button);
void XkbUseMsg();
int XkbProcessArguments(int argc, char** argv, int i);
Bool XkbInitPrivates();
void XkbSetExtension(DeviceIntPtr device, ProcessInputProc proc);
void XkbFreeCompatMap(XkbDescPtr xkb, uint which, Bool freeMap);
void XkbFreeNames(XkbDescPtr xkb, uint which, Bool freeMap);
XkbDescPtr XkbAllocKeyboard();
int XkbAllocIndicatorMaps(XkbDescPtr xkb);
int XkbAllocCompatMap(XkbDescPtr xkb, uint which, uint nInterpret);
int XkbAllocNames(XkbDescPtr xkb, uint which, int nTotalRG, int nTotalAliases);
int XkbAllocControls(XkbDescPtr xkb, uint which);
// int XkbCopyKeyTypes(XkbKeyTypePtr from, XkbKeyTypePtr into, int num_types);
// int XkbResizeKeyType(XkbDescPtr xkb, int type_ndx, int map_count, Bool want_preserve, int new_num_lvls);
void XkbFreeComponentNames(XkbComponentNamesPtr names, Bool freeNames);
void XkbSetActionKeyMods(XkbDescPtr xkb, XkbAction* act, uint mods);
uint XkbMaskForVMask(XkbDescPtr xkb, uint vmask);
Bool XkbVirtualModsToReal(XkbDescPtr xkb, uint virtual_mask, uint* mask_rtrn);
uint XkbAdjustGroup(int group, XkbControlsPtr ctrls);
// KeySym* XkbResizeKeySyms(XkbDescPtr xkb, int key, int needed);
// XkbAction* XkbResizeKeyActions(XkbDescPtr xkb, int key, int needed);
void XkbUpdateDescActions(XkbDescPtr xkb, KeyCode first, CARD8 num, XkbChangesPtr changes);
void XkbUpdateActions(DeviceIntPtr pXDev, KeyCode first, CARD8 num, XkbChangesPtr pChanges, uint* needChecksRtrn, XkbEventCausePtr);
void XkbSetIndicators(DeviceIntPtr pXDev, CARD32 affect, CARD32 values, XkbEventCausePtr cause);
void XkbUpdateIndicators(DeviceIntPtr keybd, CARD32 changed, Bool check_edevs, XkbChangesPtr pChanges, XkbEventCausePtr cause);
void XkbUpdateAllDeviceIndicators(XkbChangesPtr changes, XkbEventCausePtr cause);
uint XkbIndicatorsToUpdate(DeviceIntPtr dev, c_ulong state_changes, Bool enabled_ctrl_changes);
void XkbComputeDerivedState(XkbSrvInfoPtr xkbi);
void XkbCheckSecondaryEffects(XkbSrvInfoPtr xkbi, uint which, XkbChangesPtr changes, XkbEventCausePtr cause);
void XkbCheckIndicatorMaps(DeviceIntPtr dev, XkbSrvLedInfoPtr sli, uint which);
uint XkbStateChangedFlags(XkbStatePtr old, XkbStatePtr new_);
void XkbHandleBell(BOOL force, BOOL eventOnly, DeviceIntPtr kbd, CARD8 percent, void* ctrl, CARD8 class_, Atom name, WindowPtr pWin, ClientPtr pClient);
void XkbHandleActions(DeviceIntPtr dev, DeviceIntPtr kbd, DeviceEvent* event);
void XkbProcessKeyboardEvent(DeviceEvent* event, DeviceIntPtr keybd);
Bool XkbEnableDisableControls(XkbSrvInfoPtr xkbi, c_ulong change, c_ulong newValues, XkbChangesPtr changes, XkbEventCausePtr cause);
void XkbDisableComputedAutoRepeats(DeviceIntPtr pXDev, uint key);
XkbGeometryPtr XkbLookupNamedGeometry(DeviceIntPtr dev, Atom name, Bool* shouldFree);
void XkbConvertCase(KeySym sym, KeySym* lower, KeySym* upper);
// int XkbChangeKeycodeRange(XkbDescPtr xkb, int minKC, int maxKC, XkbChangesPtr changes);
void XkbFreeInfo(XkbSrvInfoPtr xkbi);
int XkbChangeTypesOfKey(XkbDescPtr xkb, int key, int nGroups, uint groups, int* newTypesIn, XkbMapChangesPtr changes);
int XkbKeyTypesForCoreSymbols(XkbDescPtr xkb, int map_width, KeySym* core_syms, uint protected_, int* types_inout, KeySym* xkb_syms_rtrn);
Bool XkbApplyCompatMapToKey(XkbDescPtr xkb, KeyCode key, XkbChangesPtr changes);
Bool XkbApplyVirtualModChanges(XkbDescPtr xkb, uint changed, XkbChangesPtr changes);
Bool XkbDeviceApplyKeymap(DeviceIntPtr dst, XkbDescPtr src);
void XkbCopyControls(XkbDescPtr dst, XkbDescPtr src);


DevPrivateKeyRec xkbDevicePrivateKeyRec;

enum string XKBDEVICEINFO(string dev) = `(cast(xkbDeviceInfoPtr)dixLookupPrivate(&(` ~ dev ~ `).devPrivates, &xkbDevicePrivateKeyRec))`;

int XkbReqCode;
int XkbEventBase;
int XkbKeyboardErrorCode;
// const(char)* XkbBaseDirectory;
// const(char)* XkbBinDirectory;
CARD32 xkbDebugFlags;

/* AccessX functions */
void XkbSendAccessXNotify(DeviceIntPtr kbd, xkbAccessXNotify* pEv);
// void AccessXInit(DeviceIntPtr dev);
Bool AccessXFilterPressEvent(DeviceEvent* event, DeviceIntPtr keybd);
Bool AccessXFilterReleaseEvent(DeviceEvent* event, DeviceIntPtr keybd);
void AccessXCancelRepeatKey(XkbSrvInfoPtr xkbi, KeyCode key);
void AccessXComputeCurveFactor(XkbSrvInfoPtr xkbi, XkbControlsPtr ctrls);
int XkbDDXAccessXBeep(DeviceIntPtr dev, uint what, uint which);

/* DDX entry points - DDX needs to implement these */
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXTerminateServer(DeviceIntPtr dev, KeyCode key, XkbAction* act);
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXSwitchScreen(DeviceIntPtr dev, KeyCode key, XkbAction* act);
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXPrivate(DeviceIntPtr dev, KeyCode key, XkbAction* act);

/* client resources */
XkbInterestPtr XkbFindClientResource(DevicePtr inDev, ClientPtr client);
XkbInterestPtr XkbAddClientResource(DevicePtr inDev, ClientPtr client, XID id);
int XkbRemoveResourceClient(DevicePtr inDev, XID id);

/* key latching */
int XkbLatchModifiers(DeviceIntPtr pXDev, CARD8 mask, CARD8 latches);
int XkbLatchGroup(DeviceIntPtr pXDev, int group);
void XkbClearAllLatchesAndLocks(DeviceIntPtr dev, XkbSrvInfoPtr xkbi, Bool genEv, XkbEventCausePtr cause);

/* xkb rules */
void XkbInitRules(XkbRMLVOSet* rmlvo, const(char)* rules, const(char)* model, const(char)* layout, const(char)* variant, const(char)* options);
void XkbSetRulesDflts(XkbRMLVOSet* rmlvo);
void XkbDeleteRulesDflts();
void XkbDeleteRulesUsed();

/* notification sending */
void XkbSendStateNotify(DeviceIntPtr kbd, xkbStateNotify* pSN);
void XkbSendMapNotify(DeviceIntPtr kbd, xkbMapNotify* ev);
int XkbComputeControlsNotify(DeviceIntPtr kbd, XkbControlsPtr old, XkbControlsPtr new_, xkbControlsNotify* pCN, Bool forceCtrlProc);
void XkbSendControlsNotify(DeviceIntPtr kbd, xkbControlsNotify* ev);
void XkbSendCompatMapNotify(DeviceIntPtr kbd, xkbCompatMapNotify* ev);
void XkbSendNamesNotify(DeviceIntPtr kbd, xkbNamesNotify* ev);
void XkbSendActionMessage(DeviceIntPtr kbd, xkbActionMessage* ev);
void XkbSendExtensionDeviceNotify(DeviceIntPtr kbd, ClientPtr client, xkbExtensionDeviceNotify* ev);
void XkbSendNotification(DeviceIntPtr kbd, XkbChangesPtr pChanges, XkbEventCausePtr cause);
void XkbSendNewKeyboardNotify(DeviceIntPtr kbd, xkbNewKeyboardNotify* pNKN);

/* device lookup */
int _XkbLookupAnyDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err);
int _XkbLookupKeyboard(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err);
int _XkbLookupBellDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err);
int _XkbLookupLedDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err);
int _XkbLookupButtonDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err);

/* XkbSrvLedInfo functions */
XkbSrvLedInfoPtr XkbAllocSrvLedInfo(DeviceIntPtr dev, KbdFeedbackPtr kf, LedFeedbackPtr lf, uint needed_parts);
XkbSrvLedInfoPtr XkbCopySrvLedInfo(DeviceIntPtr dev, XkbSrvLedInfoPtr src, KbdFeedbackPtr kf, LedFeedbackPtr lf);
XkbSrvLedInfoPtr XkbFindSrvLedInfo(DeviceIntPtr dev, uint class_, uint id, uint needed_parts);
void XkbFreeSrvLedInfo(XkbSrvLedInfoPtr sli);

/* keymap compile */
XkbDescPtr XkbCompileKeymap(DeviceIntPtr dev, XkbRMLVOSet* rmlvo);
XkbDescPtr XkbCompileKeymapFromString(DeviceIntPtr dev, const(char)* keymap, int keymap_length);

/* client map */
// int XkbAllocClientMap(XkbDescPtr xkb, uint which, uint nTypes);
void XkbFreeClientMap(XkbDescPtr xkb, uint what, Bool freeMap);

/* server map */
// int XkbAllocServerMap(XkbDescPtr xkb, uint which, uint nNewActions);
void XkbFreeServerMap(XkbDescPtr xkb, uint what, Bool freeMap);

/* led functions */
void XkbApplyLedNameChanges(DeviceIntPtr dev, XkbSrvLedInfoPtr sli, uint changed_names, xkbExtensionDeviceNotify* ed, XkbChangesPtr changes, XkbEventCausePtr cause);
void XkbApplyLedMapChanges(DeviceIntPtr dev, XkbSrvLedInfoPtr sli, uint changed_maps, xkbExtensionDeviceNotify* ed, XkbChangesPtr changes, XkbEventCausePtr cause);
void XkbApplyLedStateChanges(DeviceIntPtr dev, XkbSrvLedInfoPtr sli, uint changed_leds, xkbExtensionDeviceNotify* ed, XkbChangesPtr changes, XkbEventCausePtr cause);
void XkbFlushLedEvents(DeviceIntPtr dev, DeviceIntPtr kbd, XkbSrvLedInfoPtr sli, xkbExtensionDeviceNotify* ed, XkbChangesPtr changes, XkbEventCausePtr cause);

/* XkbDDX* functions */
uint XkbDDXLoadKeymapByNames(DeviceIntPtr keybd, XkbComponentNamesPtr names, uint want, uint need, XkbDescPtr* finfoRtrn, char* keymapNameRtrn, int keymapNameRtrnLen);
Bool XkbDDXNamesFromRules(DeviceIntPtr keybd, const(char)* rules, XkbRF_VarDefsPtr defs, XkbComponentNamesPtr names);
int XkbDDXUsesSoftRepeat(DeviceIntPtr dev);
void XkbDDXKeybdCtrlProc(DeviceIntPtr dev, KeybdCtrl* ctrl);
void XkbDDXUpdateDeviceIndicators(DeviceIntPtr dev, XkbSrvLedInfoPtr sli, CARD32 newState);
 /* _XSERVER_XKBSRV_PRIV_H_ */
