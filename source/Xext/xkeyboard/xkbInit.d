module xkb.xkbInit;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
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

import config.xkb_config;
import dix.atom;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.unistd;
import core.stdc.math;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
import externs.X11.Xatom;
// //import externs.X11.extensions.XKMformat;
import externs.X11.extensions.XKB;
import externs.X11.extensions.XKM;



import dix.screenint_priv;
import os.bug_priv;
import os.cmdline;
import os.log_priv;
import xkb.xkbsrv_priv;

import include.misc;
import dix.inputstr;import include.scrnintstr;
import xkb.xkbgeom_priv;
import include.xkbstr;
import include.xkbstr;
import include.misc;
import dix.inputstr;import Xi.exevents;
import dix.events;
import mi.mipointer;
import include.xkbstr;
import os.WaitFor;
import include.xkbstr;
import os.log;
import os.utils;
import dix.events;
import externs.gnu;
import dix.devices;
import dix.inpututils;
import dix.property;
import xkb.xkbDflts;
import xkb.XKBMAlloc;
public import xkb.xkbAccessX;


// import externs.X11.extensions.XKBstr;

enum      _XKB_RF_NAMES_PROP_ATOM =         "_XKB_RULES_NAMES";

static if (HasVersion!"Alpha" || HasVersion!"Alpha") {
enum	LED_COMPOSE =	2;
enum LED_CAPS =	3;
enum	LED_SCROLL =	4;
enum	LED_NUM =		5;
enum	PHYS_LEDS =	0x1f;
} else {
version (__sun) {
enum LED_NUM =		1;
enum	LED_SCROLL =	2;
enum	LED_COMPOSE =	3;
enum LED_CAPS =	4;
enum	PHYS_LEDS =	0x0f;
} else {
enum	LED_CAPS =	1;
enum	LED_NUM =		2;
enum	LED_SCROLL =	3;
enum	PHYS_LEDS =	0x07;
}
}

/***====================================================================***/

enum	XKB_DFLT_RULES_PROP =	TRUE;


const(char)* XkbBaseDirectory = XKB_BASE_DIRECTORY;
const(char)* XkbBinDirectory = XKB_BIN_DIRECTORY;
private int XkbWantAccessX = 0;

private char* XkbRulesDflt = null;
private char* XkbModelDflt = null;
private char* XkbLayoutDflt = null;
private char* XkbVariantDflt = null;
private char* XkbOptionsDflt = null;

private char* XkbRulesUsed = null;
private char* XkbModelUsed = null;
private char* XkbLayoutUsed = null;
private char* XkbVariantUsed = null;
private char* XkbOptionsUsed = null;

private XkbDescPtr xkb_cached_map = null;

private Bool XkbWantRulesProp = XKB_DFLT_RULES_PROP;

alias XKB_DFLT_RULES = build.dix_config.XKB_DFLT_RULES;

/***====================================================================***/

/**
 * Get the current default XKB rules.
 * Caller must free the data in rmlvo.
 */
void XkbGetRulesDflts(XkbRMLVOSet* rmlvo)
{
    rmlvo.rules = cast(char*)XNFstrdup(XkbRulesDflt ? XkbRulesDflt : XKB_DFLT_RULES);
    rmlvo.model = cast(char*)XNFstrdup(XkbModelDflt ? XkbModelDflt : XKB_DFLT_MODEL);
    rmlvo.layout = cast(char*)XNFstrdup(XkbLayoutDflt ? XkbLayoutDflt : XKB_DFLT_LAYOUT);
    rmlvo.variant = cast(char*)XNFstrdup(XkbVariantDflt ? XkbVariantDflt : XKB_DFLT_VARIANT);
    rmlvo.options = cast(char*)XNFstrdup(XkbOptionsDflt ? XkbOptionsDflt : XKB_DFLT_OPTIONS);
}

void XkbFreeRMLVOSet(XkbRMLVOSet* rmlvo, Bool freeRMLVO)
{
    if (!rmlvo)
        return;

    free(rmlvo.rules);
    free(rmlvo.model);
    free(rmlvo.layout);
    free(rmlvo.variant);
    free(rmlvo.options);

    if (freeRMLVO)
        free(rmlvo);
    else
        memset(rmlvo, 0, XkbRMLVOSet.sizeof);
}

private Bool XkbWriteRulesProp()
{
    int len = void, out_ = void;
    Atom name = void;

    len = cast(int)(XkbRulesUsed ? strlen(XkbRulesUsed) : 0);
    len += (XkbModelUsed ? strlen(XkbModelUsed) : 0);
    len += (XkbLayoutUsed ? strlen(XkbLayoutUsed) : 0);
    len += (XkbVariantUsed ? strlen(XkbVariantUsed) : 0);
    len += (XkbOptionsUsed ? strlen(XkbOptionsUsed) : 0);
    if (len < 1)
        return TRUE;

    len += 5;                   /* trailing NULs */

    name =
        MakeAtom(_XKB_RF_NAMES_PROP_ATOM.ptr, cast(uint)strlen(_XKB_RF_NAMES_PROP_ATOM.ptr), 1);
    if (name == None) {
        ErrorF("[xkb] Atom error: %s not created\n", _XKB_RF_NAMES_PROP_ATOM.ptr);
        return TRUE;
    }
    char* pval = cast(char*) calloc(1, len);
    if (!pval) {
        ErrorF("[xkb] Allocation error: %s proprerty not created\n",
               _XKB_RF_NAMES_PROP_ATOM.ptr);
        return TRUE;
    }
    out_ = 0;
    if (XkbRulesUsed) {
        strcpy(&pval[out_], XkbRulesUsed);
        out_ += strlen(XkbRulesUsed);
    }
    pval[out_++] = '\0';
    if (XkbModelUsed) {
        strcpy(&pval[out_], XkbModelUsed);
        out_ += strlen(XkbModelUsed);
    }
    pval[out_++] = '\0';
    if (XkbLayoutUsed) {
        strcpy(&pval[out_], XkbLayoutUsed);
        out_ += strlen(XkbLayoutUsed);
    }
    pval[out_++] = '\0';
    if (XkbVariantUsed) {
        strcpy(&pval[out_], XkbVariantUsed);
        out_ += strlen(XkbVariantUsed);
    }
    pval[out_++] = '\0';
    if (XkbOptionsUsed) {
        strcpy(&pval[out_], XkbOptionsUsed);
        out_ += strlen(XkbOptionsUsed);
    }
    pval[out_++] = '\0';
    if (out_ != len) {
        ErrorF("[xkb] Internal Error! bad size (%d!=%d) for _XKB_RULES_NAMES\n",
               out_, len);
    }
    dixChangeWindowProperty(serverClient, dixGetMasterScreen().root, name,
                            XA_STRING, 8, PropModeReplace, len, pval, TRUE);
    free(pval);
    return TRUE;
}

void XkbInitRules(XkbRMLVOSet* rmlvo, const(char)* rules, const(char)* model, const(char)* layout, const(char)* variant, const(char)* options)
{
    rmlvo.rules = cast(char*)(rules ? strdup(rules) : null);
    rmlvo.model = cast(char*)(model ? strdup(model) : null);
    rmlvo.layout = cast(char*)(layout ? strdup(layout) : null);
    rmlvo.variant = cast(char*)(variant ? strdup(variant) : null);
    rmlvo.options = cast(char*)(options ? strdup(options) : null);
}

private void XkbSetRulesUsed(XkbRMLVOSet* rmlvo)
{
    free(XkbRulesUsed);
    XkbRulesUsed = cast(char*)(rmlvo.rules ? Xstrdup(rmlvo.rules) : null);
    free(XkbModelUsed);
    XkbModelUsed = cast(char*)(rmlvo.model ? Xstrdup(rmlvo.model) : null);
    free(XkbLayoutUsed);
    XkbLayoutUsed = cast(char*)(rmlvo.layout ? Xstrdup(rmlvo.layout) : null);
    free(XkbVariantUsed);
    XkbVariantUsed = cast(char*)(rmlvo.variant ? Xstrdup(rmlvo.variant) : null);
    free(XkbOptionsUsed);
    XkbOptionsUsed = cast(char*)(rmlvo.options ? Xstrdup(rmlvo.options) : null);
    if (XkbWantRulesProp)
        XkbWriteRulesProp();
    return;
}

void XkbSetRulesDflts(XkbRMLVOSet* rmlvo)
{
    if (rmlvo.rules) {
        free(XkbRulesDflt);
        XkbRulesDflt = cast(char*)Xstrdup(rmlvo.rules);
    }
    if (rmlvo.model) {
        free(XkbModelDflt);
        XkbModelDflt = cast(char*)Xstrdup(rmlvo.model);
    }
    if (rmlvo.layout) {
        free(XkbLayoutDflt);
        XkbLayoutDflt = cast(char*)Xstrdup(rmlvo.layout);
    }
    if (rmlvo.variant) {
        free(XkbVariantDflt);
        XkbVariantDflt = cast(char*)Xstrdup(rmlvo.variant);
    }
    if (rmlvo.options) {
        free(XkbOptionsDflt);
        XkbOptionsDflt = cast(char*)Xstrdup(rmlvo.options);
    }
    return;
}

void XkbDeleteRulesUsed()
{
    free(XkbRulesUsed);
    XkbRulesUsed = null;
    free(XkbModelUsed);
    XkbModelUsed = null;
    free(XkbLayoutUsed);
    XkbLayoutUsed = null;
    free(XkbVariantUsed);
    XkbVariantUsed = null;
    free(XkbOptionsUsed);
    XkbOptionsUsed = null;
}

void XkbDeleteRulesDflts()
{
    free(XkbRulesDflt);
    XkbRulesDflt = null;
    free(XkbModelDflt);
    XkbModelDflt = null;
    free(XkbLayoutDflt);
    XkbLayoutDflt = null;
    free(XkbVariantDflt);
    XkbVariantDflt = null;
    free(XkbOptionsDflt);
    XkbOptionsDflt = null;

    XkbFreeKeyboard(xkb_cached_map, XkbAllComponentsMask, TRUE);
    xkb_cached_map = null;
}

enum string DIFFERS(string a, string b) = `(strcmp((` ~ a ~ `) ? (` ~ a ~ `) : "", (` ~ b ~ `) ? (` ~ b ~ `) : "") != 0)`;

private Bool XkbCompareUsedRMLVO(XkbRMLVOSet* rmlvo)
{
    if (mixin(DIFFERS!(`rmlvo.rules`, `XkbRulesUsed`)) ||
        mixin(DIFFERS!(`rmlvo.model`, `XkbModelUsed`)) ||
        mixin(DIFFERS!(`rmlvo.layout`, `XkbLayoutUsed`)) ||
        mixin(DIFFERS!(`rmlvo.variant`, `XkbVariantUsed`)) ||
        mixin(DIFFERS!(`rmlvo.options`, `XkbOptionsUsed`)))
        return FALSE;
    return TRUE;
}

/***====================================================================***/

import xkb.xkbDflts;

private Bool XkbInitKeyTypes(XkbDescPtr xkb)
{
    if (xkb.defined & XkmTypesMask)
        return TRUE;

    initTypeNames(null);
    if (XkbAllocClientMap(xkb, XkbKeyTypesMask, num_dflt_types) != Success)
        return FALSE;
    if (XkbCopyKeyTypes(dflt_types.ptr, xkb.map.types, num_dflt_types) != Success) {
        return FALSE;
    }
    xkb.map.size_types = cast(ubyte)xkb.map.num_types = cast(ubyte)(num_dflt_types);
    return TRUE;
}

private void XkbInitRadioGroups(XkbSrvInfoPtr xkbi)
{
    xkbi.nRadioGroups = 0;
    xkbi.radioGroups = null;
    return;
}

private Status XkbInitCompatStructs(XkbDescPtr xkb)
{
    int i = void;
    XkbCompatMapPtr compat = void;

    if (xkb.defined & XkmCompatMapMask)
        return TRUE;

    if (XkbAllocCompatMap(xkb, XkbAllCompatMask, num_dfltSI) != Success)
        return BadAlloc;
    compat = xkb.compat;
    if (compat.sym_interpret) {
        compat.num_si = num_dfltSI;
        memcpy(cast(char*) compat.sym_interpret, cast(char*) dfltSI, dfltSI.sizeof);
    }
    for (i = 0; i < XkbNumKbdGroups; i++) {
        compat.groups[i] = compatMap.groups[i];
        if (compat.groups[i].vmods != 0) {
            uint mask = void;

            mask = XkbMaskForVMask(xkb, compat.groups[i].vmods);
            compat.groups[i].mask = cast(ubyte)(compat.groups[i].real_mods | mask);
        }
        else
            compat.groups[i].mask = cast(ubyte)(compat.groups[i].real_mods);
    }
    return Success;
}

private void XkbInitSemantics(XkbDescPtr xkb)
{
    XkbInitKeyTypes(xkb);
    XkbInitCompatStructs(xkb);
    return;
}

/***====================================================================***/

private Status XkbInitNames(XkbSrvInfoPtr xkbi)
{
    XkbDescPtr xkb = void;
    XkbNamesPtr names = void;
    Status rtrn = void;
    Atom unknown = void;

    xkb = xkbi.desc;
    if ((rtrn = XkbAllocNames(xkb, XkbAllNamesMask, 0, 0)) != Success)
        return rtrn;
    unknown = dixAddAtom("unknown");
    names = xkb.names;
    if (names.keycodes == None)
        names.keycodes = unknown;
    if (names.geometry == None)
        names.geometry = unknown;
    if (names.phys_symbols == None)
        names.phys_symbols = unknown;
    if (names.symbols == None)
        names.symbols = unknown;
    if (names.types == None)
        names.types = unknown;
    if (names.compat == None)
        names.compat = unknown;
    if (!(xkb.defined & XkmVirtualModsMask)) {
        if (names.vmods[vmod_NumLock] == None)
            names.vmods[vmod_NumLock] = dixAddAtom("NumLock");
        if (names.vmods[vmod_Alt] == None)
            names.vmods[vmod_Alt] = dixAddAtom("Alt");
        if (names.vmods[vmod_AltGr] == None)
            names.vmods[vmod_AltGr] = dixAddAtom("ModeSwitch");
    }

    if (!(xkb.defined & XkmIndicatorsMask) ||
        !(xkb.defined & XkmGeometryMask)) {
        initIndicatorNames(null, xkb);
        if (names.indicators[LED_CAPS - 1] == None)
            names.indicators[LED_CAPS - 1] = dixAddAtom("Caps Lock");
        if (names.indicators[LED_NUM - 1] == None)
            names.indicators[LED_NUM - 1] = dixAddAtom("Num Lock");
        if (names.indicators[LED_SCROLL - 1] == None)
            names.indicators[LED_SCROLL - 1] = dixAddAtom("Scroll Lock");
version (LED_COMPOSE) {
        if (names.indicators[LED_COMPOSE - 1] == None)
            names.indicators[LED_COMPOSE - 1] = dixAddAtom("Compose");
}
    }

    if (xkb.geom !is null)
        names.geometry = xkb.geom.name;
    else
        names.geometry = unknown;

    return Success;
}

private Status XkbInitIndicatorMap(XkbSrvInfoPtr xkbi)
{
    XkbDescPtr xkb = void;
    XkbIndicatorPtr map = void;
    XkbSrvLedInfoPtr sli = void;

    xkb = xkbi.desc;
    if (XkbAllocIndicatorMaps(xkb) != Success)
        return BadAlloc;

    if (!(xkb.defined & XkmIndicatorsMask)) {
        map = xkb.indicators;
        map.phys_indicators = PHYS_LEDS;
        map.maps[LED_CAPS - 1].flags = cast(ubyte)XkbIM_NoExplicit;
        map.maps[LED_CAPS - 1].which_mods = cast(ubyte)XkbIM_UseLocked;
        map.maps[LED_CAPS - 1].mods.mask = cast(ubyte)LockMask;
        map.maps[LED_CAPS - 1].mods.real_mods = cast(ubyte)LockMask;

        map.maps[LED_NUM - 1].flags = cast(ubyte)XkbIM_NoExplicit;
        map.maps[LED_NUM - 1].which_mods = cast(ubyte)XkbIM_UseLocked;
        map.maps[LED_NUM - 1].mods.mask = cast(ubyte)0;
        map.maps[LED_NUM - 1].mods.real_mods = cast(ubyte)0;
        map.maps[LED_NUM - 1].mods.vmods = cast(ubyte)vmod_NumLockMask;

        map.maps[LED_SCROLL - 1].flags = cast(ubyte)XkbIM_NoExplicit;
        map.maps[LED_SCROLL - 1].which_mods = cast(ubyte)XkbIM_UseLocked;
        map.maps[LED_SCROLL - 1].mods.mask = cast(ubyte)Mod3Mask;
        map.maps[LED_SCROLL - 1].mods.real_mods = cast(ubyte)Mod3Mask;
    }

    sli = XkbFindSrvLedInfo(xkbi.device, XkbDfltXIClass, XkbDfltXIId, 0);
    if (sli)
        XkbCheckIndicatorMaps(xkbi.device, sli, XkbAllIndicatorsMask);

    return Success;
}

private Status XkbInitControls(DeviceIntPtr pXDev, XkbSrvInfoPtr xkbi)
{
    XkbDescPtr xkb = void;
    XkbControlsPtr ctrls = void;

    xkb = xkbi.desc;
    /* 12/31/94 (ef) -- XXX! Should check if controls loaded from file */
    if (XkbAllocControls(xkb, XkbAllControlsMask) != Success)
        FatalError("Couldn't allocate keyboard controls\n");
    ctrls = xkb.ctrls;
    if (!(xkb.defined & XkmSymbolsMask))
        ctrls.num_groups = 1;
    ctrls.groups_wrap = mixin(XkbSetGroupInfo!("1", "XkbWrapIntoRange", "0"));
    ctrls.internal.mask = 0;
    ctrls.internal.real_mods = 0;
    ctrls.internal.vmods = 0;
    ctrls.ignore_lock.mask = 0;
    ctrls.ignore_lock.real_mods = 0;
    ctrls.ignore_lock.vmods = 0;
    ctrls.enabled_ctrls = cast(ubyte)(XkbAccessXTimeoutMask | XkbRepeatKeysMask |
        XkbMouseKeysAccelMask | XkbAudibleBellMask | XkbIgnoreGroupLockMask);
    if (XkbWantAccessX)
        ctrls.enabled_ctrls |= XkbAccessXKeysMask;
    AccessXInit(pXDev);
    return Success;
}

private Status XkbInitOverlayState(XkbSrvInfoPtr xkbi)
{
    memset(xkbi.overlay_perkey_state.ptr, 0, typeof(xkbi.overlay_perkey_state).sizeof);
    return Success;
}

private Bool InitKeyboardDeviceStructInternal(DeviceIntPtr dev, XkbRMLVOSet* rmlvo, const(char)* keymap, int keymap_length, BellProcPtr bell_func, KbdCtrlProcPtr ctrl_func)
{
    int i = void;
    uint check = void;
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;
    XkbSrvLedInfoPtr sli = void;
    XkbChangesRec changes = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbRMLVOSet rmlvo_dflts = { null };

    mixin(BUG_RETURN_VAL!("dev is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.key !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("dev.kbdfeed !is null", "FALSE"));
    mixin(BUG_RETURN_VAL!("rmlvo && keymap", "FALSE"));

    if (!rmlvo && !keymap) {
        rmlvo = &rmlvo_dflts;
        XkbGetRulesDflts(rmlvo);
    }

    memset(&changes, 0, changes.sizeof);
    mixin(XkbSetCauseUnknown!("&cause"));

    dev.key = cast(_KeyClassRec*)calloc(1, typeof(*dev.key).sizeof);
    if (!dev.key) {
        ErrorF("XKB: Failed to allocate key class\n");
        goto unwind_rmlvo;
    }
    dev.key.sourceid = dev.id;

    dev.kbdfeed = cast(_KbdFeedbackClassRec*)calloc(1, typeof(*dev.kbdfeed).sizeof);
    if (!dev.kbdfeed) {
        ErrorF("XKB: Failed to allocate key feedback class\n");
        goto unwind_key;
    }

    xkbi = cast(_XkbSrvInfo*)calloc(1, typeof(*xkbi).sizeof);
    if (!xkbi) {
        ErrorF("XKB: Failed to allocate XKB info\n");
        goto unwind_kbdfeed;
    }
    dev.key.xkbInfo = xkbi;

    if (xkb_cached_map && (keymap || (rmlvo && !XkbCompareUsedRMLVO(rmlvo)))) {
        XkbFreeKeyboard(xkb_cached_map, XkbAllComponentsMask, TRUE);
        xkb_cached_map = null;
    }

    if (xkb_cached_map)
        LogMessageVerb(X_INFO, 4, "XKB: Reusing cached keymap\n");
    else {
        if (rmlvo)
            xkb_cached_map = XkbCompileKeymap(dev, rmlvo);
        else
            xkb_cached_map = XkbCompileKeymapFromString(dev, keymap, keymap_length);

        if (!xkb_cached_map) {
            ErrorF("XKB: Failed to compile keymap\n");
            goto unwind_info;
        }
    }

    xkb = XkbAllocKeyboard();
    if (!xkb) {
        ErrorF("XKB: Failed to allocate keyboard description\n");
        goto unwind_info;
    }

    if (!XkbCopyKeymap(xkb, xkb_cached_map)) {
        ErrorF("XKB: Failed to copy keymap\n");
        goto unwind_desc;
    }
    xkb.defined = xkb_cached_map.defined;
    xkb.flags = xkb_cached_map.flags;
    xkb.device_spec = xkb_cached_map.device_spec;
    xkbi.desc = xkb;

    if (xkb.min_key_code == 0)
        xkb.min_key_code = 8;
    if (xkb.max_key_code == 0)
        xkb.max_key_code = 255;

    i = mixin(XkbNumKeys!("xkb")) / 3 + 1;
    if (XkbAllocClientMap(xkb, XkbAllClientInfoMask, 0) != Success)
        goto unwind_desc;
    if (XkbAllocServerMap(xkb, XkbAllServerInfoMask, i) != Success)
        goto unwind_desc;

    xkbi.dfltPtrDelta = 1;
    xkbi.device = dev;

    XkbInitSemantics(xkb);
    XkbInitNames(xkbi);
    XkbInitRadioGroups(xkbi);

    XkbInitControls(dev, xkbi);

    XkbInitIndicatorMap(xkbi);

    XkbInitOverlayState(xkbi);

    XkbUpdateActions(dev, xkb.min_key_code, cast(ubyte)mixin(XkbNumKeys!("xkb")), &changes,
                     &check, &cause);

    if (!dev.focus)
        InitFocusClassDeviceStruct(dev);

    xkbi.kbdProc = ctrl_func;
    dev.kbdfeed.BellProc = bell_func;
    dev.kbdfeed.CtrlProc = &XkbDDXKeybdCtrlProc;

    dev.kbdfeed.ctrl = defaultKeyboardControl;
    if (dev.kbdfeed.ctrl.autoRepeat)
        xkb.ctrls.enabled_ctrls |= XkbRepeatKeysMask;

    memcpy(dev.kbdfeed.ctrl.autoRepeats.ptr, xkb.ctrls.per_key_repeat.ptr,
           XkbPerKeyBitArraySize);

    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId, 0);
    if (sli)
        XkbCheckIndicatorMaps(dev, sli, XkbAllIndicatorsMask);
    else
        DebugF("XKB: No indicator feedback in XkbFinishInit!\n");

    dev.kbdfeed.CtrlProc(dev, &dev.kbdfeed.ctrl);

    if (rmlvo) {
        XkbSetRulesDflts(rmlvo);
        XkbSetRulesUsed(rmlvo);
    }
    XkbFreeRMLVOSet(&rmlvo_dflts, FALSE);

    return TRUE;

 unwind_desc:
    XkbFreeKeyboard(xkb, 0, TRUE);
 unwind_info:
    free(xkbi);
    dev.key.xkbInfo = null;
 unwind_kbdfeed:
    free(dev.kbdfeed);
    dev.kbdfeed = null;
 unwind_key:
    free(dev.key);
    dev.key = null;
 unwind_rmlvo:
    XkbFreeRMLVOSet(&rmlvo_dflts, FALSE);
    return FALSE;
}

Bool InitKeyboardDeviceStruct(DeviceIntPtr dev, XkbRMLVOSet* rmlvo, BellProcPtr bell_func, KbdCtrlProcPtr ctrl_func)
{
    return InitKeyboardDeviceStructInternal(dev, rmlvo,
                                            null, 0, bell_func, ctrl_func);
}

Bool InitKeyboardDeviceStructFromString(DeviceIntPtr dev, const(char)* keymap, int keymap_length, BellProcPtr bell_func, KbdCtrlProcPtr ctrl_func)
{
    return InitKeyboardDeviceStructInternal(dev, null,
                                            keymap, keymap_length,
                                            bell_func, ctrl_func);
}

/***====================================================================***/

        /*
         * Be very careful about what does and doesn't get freed by this
         * function.  To reduce fragmentation, XkbInitDevice allocates a
         * single huge block per device and divides it up into most of the
         * fixed-size structures for the device.   Don't free anything that
         * is part of this larger block.
         */
void XkbFreeInfo(XkbSrvInfoPtr xkbi)
{
    free(xkbi.radioGroups);
    xkbi.radioGroups = null;
    if (xkbi.mouseKeyTimer) {
        TimerFree(xkbi.mouseKeyTimer);
        xkbi.mouseKeyTimer = null;
    }
    if (xkbi.slowKeysTimer) {
        TimerFree(xkbi.slowKeysTimer);
        xkbi.slowKeysTimer = null;
    }
    if (xkbi.bounceKeysTimer) {
        TimerFree(xkbi.bounceKeysTimer);
        xkbi.bounceKeysTimer = null;
    }
    if (xkbi.repeatKeyTimer) {
        TimerFree(xkbi.repeatKeyTimer);
        xkbi.repeatKeyTimer = null;
    }
    if (xkbi.krgTimer) {
        TimerFree(xkbi.krgTimer);
        xkbi.krgTimer = null;
    }
    xkbi.beepType = _BEEP_NONE;
    if (xkbi.beepTimer) {
        TimerFree(xkbi.beepTimer);
        xkbi.beepTimer = null;
    }
    if (xkbi.desc) {
        XkbFreeKeyboard(xkbi.desc, XkbAllComponentsMask, TRUE);
        xkbi.desc = null;
    }
    free(xkbi.filters);
    free(xkbi);
    return;
}

/***====================================================================***/

// int XkbDfltRepeatDelay;
// int XkbDfltRepeatInterval;

// ushort XkbDfltAccessXTimeout;
// uint XkbDfltAccessXTimeoutMask;
// uint XkbDfltAccessXFeedback;
// ushort XkbDfltAccessXOptions;

int XkbProcessArguments(int argc, char** argv, int i)
{
    if (strncmp(argv[i], "-xkbdir", 7) == 0) {
        if (++i < argc) {
static if (!HasVersion!"Windows" && !HasVersion!"Cygwin") {
            if (getuid() != geteuid()) {
                LogMessage(X_WARNING,
                           "-xkbdir is not available for setuid X servers\n");
                return -1;
            }
            else
            {
                if (strlen(argv[i]) < PATH_MAX) {
                    XkbBaseDirectory = argv[i];
                    return 2;
                }
                else {
                    LogMessage(X_ERROR, "-xkbdir pathname too long\n");
                    return -1;
                }
            }
}
else {
                if (strlen(argv[i]) < PATH_MAX) {
                    XkbBaseDirectory = argv[i];
                    return 2;
                }
                else {
                    LogMessage(X_ERROR, "-xkbdir pathname too long\n");
                    return -1;
                }
}
        }
        else {
            return -1;
        }
    }
    else if ((strncmp(argv[i], "-accessx", 8) == 0) ||
             (strncmp(argv[i], "+accessx", 8) == 0)) {
        int j = 1;

        if (argv[i][0] == '-')
            XkbWantAccessX = 0;
        else {
            XkbWantAccessX = 1;

            if (((i + 1) < argc) && (isdigit(cast(ubyte)argv[i + 1][0]))) {
                XkbDfltAccessXTimeout = cast(ushort)atoi(argv[++i]);
                j++;

                if (((i + 1) < argc) && (isdigit(cast(ubyte)argv[i + 1][0]))) {
                    /*
                     * presumption that the reasonably useful range of
                     * values fits in 0..MAXINT since SunOS 4 doesn't
                     * have strtoul.
                     */
                    XkbDfltAccessXTimeoutMask = cast(uint)
                        strtol(argv[++i], null, 16);
                    j++;
                }
                if (((i + 1) < argc) && (isdigit(cast(ubyte)argv[i + 1][0]))) {
                    if (argv[++i][0] == '1')
                        XkbDfltAccessXFeedback = cast(uint)XkbAccessXFeedbackMask;
                    else
                        XkbDfltAccessXFeedback = 0;
                    j++;
                }
                if (((i + 1) < argc) && (isdigit(cast(ubyte)argv[i + 1][0]))) {
                    XkbDfltAccessXOptions = cast(ushort)
                        strtol(argv[++i], null, 16);
                    j++;
                }
            }
        }
        return j;
    }
    if ((strcmp(argv[i], "-ardelay") == 0) || (strcmp(argv[i], "-ar1") == 0)) { /* -ardelay int */
        if (++i >= argc)
            UseMsg();
        else
            XkbDfltRepeatDelay = cast(c_long) atoi(argv[i]);
        return 2;
    }
    if ((strcmp(argv[i], "-arinterval") == 0) || (strcmp(argv[i], "-ar2") == 0)) {      /* -arinterval int */
        if (++i >= argc)
            UseMsg();
        else
            XkbDfltRepeatInterval = cast(c_long) atoi(argv[i]);
        return 2;
    }
    return 0;
}

void XkbUseMsg()
{
    ErrorF
        ("[+-]accessx [ timeout [ timeout_mask [ feedback [ options_mask] ] ] ]\n");
    ErrorF("                       enable/disable accessx key sequences\n");
    ErrorF("-ardelay               set XKB autorepeat delay\n");
    ErrorF("-arinterval            set XKB autorepeat interval\n");
}
