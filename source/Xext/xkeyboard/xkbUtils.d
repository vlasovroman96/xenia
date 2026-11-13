module xkb.xkbUtils;
@nogc nothrow:
extern(C): __gshared:
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
/*

Copyright © 2008 Red Hat Inc.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice (including the next
paragraph) shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/

import build.dix_config;

import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.math;
//import x11.X;
//import x11.Xproto;
version =	XK_CYRILLIC;
import x11.keysymdef;

import dix.input_priv;
import os.log_priv;
import xkb.xkbsrv_priv;

import os.os;
import dix.inputstr;
import dix.events;
import xkb.xkbgeom_priv;
import externs.X11.extensions.XKB;
import externs.X11.extensions.XKBproto;
import xkb.xkbstr;
import dix.events;
import dix.devices;
import os.log;
import xkb.XKBGAlloc;

/***====================================================================***/

int _XkbLookupAnyDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err)
{
    int rc = XkbKeyboardErrorCode;

    if (id == XkbUseCoreKbd)
        id = PickKeyboard(client).id;
    else if (id == XkbUseCorePtr)
        id = PickPointer(client).id;

    rc = dixLookupDevice(pDev, id, client, access_mode);
    if (rc != Success)
        *xkb_err = XkbErr_BadDevice;

    return rc;
}

int _XkbLookupKeyboard(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err)
{
    DeviceIntPtr dev = void;
    int rc = void;

    if (id == XkbDfltXIId)
        id = XkbUseCoreKbd;

    rc = _XkbLookupAnyDevice(pDev, id, client, access_mode, xkb_err);
    if (rc != Success)
        return rc;

    dev = *pDev;
    if (!dev.key || !dev.key.xkbInfo) {
        *pDev = null;
        *xkb_err = XkbErr_BadClass;
        return XkbKeyboardErrorCode;
    }
    return Success;
}

int _XkbLookupBellDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err)
{
    DeviceIntPtr dev = void;
    int rc = void;

    rc = _XkbLookupAnyDevice(pDev, id, client, access_mode, xkb_err);
    if (rc != Success)
        return rc;

    dev = *pDev;
    if (!dev.kbdfeed && !dev.bell) {
        *pDev = null;
        *xkb_err = XkbErr_BadClass;
        return XkbKeyboardErrorCode;
    }
    return Success;
}

int _XkbLookupLedDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err)
{
    DeviceIntPtr dev = void;
    int rc = void;

    if (id == XkbDfltXIId)
        id = XkbUseCorePtr;

    rc = _XkbLookupAnyDevice(pDev, id, client, access_mode, xkb_err);
    if (rc != Success)
        return rc;

    dev = *pDev;
    if (!dev.kbdfeed && !dev.leds) {
        *pDev = null;
        *xkb_err = XkbErr_BadClass;
        return XkbKeyboardErrorCode;
    }
    return Success;
}

int _XkbLookupButtonDevice(DeviceIntPtr* pDev, int id, ClientPtr client, Mask access_mode, int* xkb_err)
{
    DeviceIntPtr dev = void;
    int rc = void;

    rc = _XkbLookupAnyDevice(pDev, id, client, access_mode, xkb_err);
    if (rc != Success)
        return rc;

    dev = *pDev;
    if (!dev.button) {
        *pDev = null;
        *xkb_err = XkbErr_BadClass;
        return XkbKeyboardErrorCode;
    }
    return Success;
}

void XkbSetActionKeyMods(XkbDescPtr xkb, XkbAction* act, uint mods)
{
    uint tmp = void;

    switch (act.type) {
    case XkbSA_SetMods:
    case XkbSA_LatchMods:
    case XkbSA_LockMods:
        if (act.mods.flags & XkbSA_UseModMapMods)
            act.mods.real_mods = act.mods.mask = cast(ubyte)mods;
        if ((tmp = mixin(XkbModActionVMods!("&act.mods"))) != 0)
            act.mods.mask |= XkbMaskForVMask(xkb, tmp);
        break;
    case XkbSA_ISOLock:
        if (act.iso.flags & XkbSA_UseModMapMods)
            act.iso.real_mods = act.iso.mask = cast(ubyte)mods;
        if ((tmp = mixin(XkbModActionVMods!("&act.iso"))) != 0)
            act.iso.mask |= XkbMaskForVMask(xkb, tmp);
        break;
    default: break;}
    return;
}

uint XkbMaskForVMask(XkbDescPtr xkb, uint vmask)
{
    int i = void, bit = void;
    uint mask = void;

    for (mask = i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (vmask & bit)
            mask |= xkb.server.vmods[i];
    }
    return mask;
}

/***====================================================================***/

private void XkbUpdateKeyTypesFromCore(DeviceIntPtr pXDev, KeySymsPtr pCore, KeyCode first, CARD8 num, XkbChangesPtr changes)
{
    XkbDescPtr xkb = void;
    uint key = void, nG = void, explicit = void;
    int[XkbNumKbdGroups] types = 0;
    KeySym[XkbMaxSymsPerKey] tsyms = NoSymbol; KeySym* syms = void;
    XkbMapChangesPtr mc = void;

    xkb = pXDev.key.xkbInfo.desc;
    if (first + num - 1 > xkb.max_key_code) {
        /* 1/12/95 (ef) -- XXX! should allow XKB structures to grow */
        num = cast(ubyte)(xkb.max_key_code - first + 1);
    }

    mc = (changes ? (&changes.map) : null);

    syms = &pCore.map[(first - pCore.minKeyCode) * pCore.mapWidth];
    for (key = first; key < (first + num); key++, syms += pCore.mapWidth) {
        explicit = xkb.server.explicit[key] & XkbExplicitKeyTypesMask;
        types[XkbGroup1Index] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "XkbGroup1Index"));
        types[XkbGroup2Index] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "XkbGroup2Index"));
        types[XkbGroup3Index] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "XkbGroup3Index"));
        types[XkbGroup4Index] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "XkbGroup4Index"));
        nG = XkbKeyTypesForCoreSymbols(xkb, pCore.mapWidth, syms, explicit,
                                       types.ptr, tsyms.ptr);
        XkbChangeTypesOfKey(xkb, key, nG, XkbAllGroupsMask, types.ptr, mc);
        memcpy(cast(char*) mixin(XkbKeySymsPtr!("xkb", "key")), cast(char*) tsyms,
               mixin(XkbKeyNumSyms!("xkb", "key")) * KeySym.sizeof);
    }
    if (changes.map.changed & XkbKeySymsMask) {
        CARD8 oldLast = void, newLast = void;

        oldLast = cast(ubyte)(changes.map.first_key_sym + changes.map.num_key_syms - 1);
        newLast = cast(ubyte)(first + num - 1);

        if (first < changes.map.first_key_sym)
            changes.map.first_key_sym = cast(ubyte)(first);
        if (oldLast > newLast)
            newLast = oldLast;
        changes.map.num_key_syms = cast(ubyte)(newLast - changes.map.first_key_sym + 1);
    }
    else {
        changes.map.changed |= XkbKeySymsMask;
        changes.map.first_key_sym = cast(ubyte)(first);
        changes.map.num_key_syms = cast(ubyte)(num);
    }
    return;
}

void XkbUpdateDescActions(XkbDescPtr xkb, KeyCode first, CARD8 num, XkbChangesPtr changes)
{
    uint key = void;

    for (key = first; key < (first + num); key++) {
        XkbApplyCompatMapToKey(xkb, cast(ubyte)key, changes);
    }

    if (changes.map.changed & (XkbVirtualModMapMask | XkbModifierMapMask)) {
        ubyte[XkbNumVirtualMods] newVMods = void;
        uint bit = void, i = void;
        uint present = void;

        memset(newVMods.ptr, 0, XkbNumVirtualMods);
        present = 0;
        for (key = xkb.min_key_code; key <= xkb.max_key_code; key++) {
            if (xkb.server.vmodmap[key] == 0)
                continue;
            for (i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
                if (bit & xkb.server.vmodmap[key]) {
                    present |= bit;
                    newVMods[i] |= xkb.map.modmap[key];
                }
            }
        }
        for (i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
            if ((bit & present) && (newVMods[i] != xkb.server.vmods[i])) {
                changes.map.changed |= XkbVirtualModsMask;
                changes.map.vmods |= bit;
                xkb.server.vmods[i] = newVMods[i];
            }
        }
    }
    if (changes.map.changed & XkbVirtualModsMask)
        XkbApplyVirtualModChanges(xkb, changes.map.vmods, changes);

    if (changes.map.changed & XkbKeyActionsMask) {
        CARD8 oldLast = void, newLast = void;

        oldLast = cast(ubyte)(changes.map.first_key_act + changes.map.num_key_acts - 1);
        newLast = cast(ubyte)(first + num - 1);

        if (first < changes.map.first_key_act)
            changes.map.first_key_act = cast(ubyte)(first);
        if (newLast > oldLast)
            newLast = cast(ubyte)oldLast;
        changes.map.num_key_acts = cast(ubyte)(newLast - changes.map.first_key_act + 1);
    }
    else {
        changes.map.changed |= XkbKeyActionsMask;
        changes.map.first_key_act = cast(ubyte)(first);
        changes.map.num_key_acts = cast(ubyte)(num);
    }
    return;
}

void XkbUpdateActions(DeviceIntPtr pXDev, KeyCode first, CARD8 num, XkbChangesPtr changes, uint* needChecksRtrn, XkbEventCausePtr cause)
{
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;
    CARD8* repeat = void;

    if (needChecksRtrn)
        *needChecksRtrn = 0;
    xkbi = pXDev.key.xkbInfo;
    xkb = xkbi.desc;
    repeat = xkb.ctrls.per_key_repeat.ptr;

    /* before letting XKB do any changes, copy the current core values */
    if (pXDev.kbdfeed)
        memcpy(repeat, pXDev.kbdfeed.ctrl.autoRepeats.ptr, XkbPerKeyBitArraySize);

    XkbUpdateDescActions(xkb, first, num, changes);

    if ((pXDev.kbdfeed) &&
        (changes.ctrls.changed_ctrls & XkbPerKeyRepeatMask)) {
        /* now copy the modified changes back to core */
        memcpy(pXDev.kbdfeed.ctrl.autoRepeats.ptr, repeat, XkbPerKeyBitArraySize);
        if (pXDev.kbdfeed.CtrlProc)
            (*pXDev.kbdfeed.CtrlProc) (pXDev, &pXDev.kbdfeed.ctrl);
    }
    return;
}

KeySymsPtr XkbGetCoreMap(DeviceIntPtr keybd)
{
    int key = void, tmp = void;
    int maxSymsPerKey = void, maxGroup1Width = void;
    XkbDescPtr xkb = void;
    KeySymsPtr syms = void;
    int maxNumberOfGroups = void;

    if (!keybd || !keybd.key || !keybd.key.xkbInfo)
        return null;

    xkb = keybd.key.xkbInfo.desc;
    maxSymsPerKey = maxGroup1Width = 0;
    maxNumberOfGroups = 0;

    /* determine sizes */
    for (key = xkb.min_key_code; key <= xkb.max_key_code; key++) {
        if (mixin(XkbKeycodeInRange!("xkb", "key"))) {
            int nGroups = void;
            int w = void;

            nGroups = mixin(XkbKeyNumGroups!("xkb", "key"));
            tmp = 0;
            if (nGroups > 0) {
                if ((w = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup1Index"))) <= 2)
                    tmp += 2;
                else
                    tmp += w + 2;
                /* remember highest G1 width */
                if (w > maxGroup1Width)
                    maxGroup1Width = w;
            }
            if (nGroups > 1) {
                if (tmp <= 2) {
                    if ((w = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup2Index"))) < 2)
                        tmp += 2;
                    else
                        tmp += w;
                }
                else {
                    if ((w = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup2Index"))) > 2)
                        tmp += w - 2;
                }
            }
            if (nGroups > 2)
                tmp += mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup3Index"));
            if (nGroups > 3)
                tmp += mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup4Index"));
            if (tmp > maxSymsPerKey)
                maxSymsPerKey = tmp;
            if (nGroups > maxNumberOfGroups)
                maxNumberOfGroups = nGroups;
        }
    }

    if (maxSymsPerKey <= 0)
        return null;

    syms = cast(_KeySymsRec*)calloc(1, typeof(*syms).sizeof);
    if (!syms)
        return null;

    /* See Section 12.4 of the XKB Protocol spec. Because of the
     * single-group distribution for multi-group keyboards, we have to
     * have enough symbols for the largest group 1 to replicate across the
     * number of groups on the keyboard. e.g. a single-group key with 4
     * symbols on a keyboard that has 3 groups -> 12 syms per key */
    if (maxSymsPerKey < maxNumberOfGroups * maxGroup1Width)
        maxSymsPerKey = maxNumberOfGroups * maxGroup1Width;

    syms.mapWidth = maxSymsPerKey;
    syms.minKeyCode = xkb.min_key_code;
    syms.maxKeyCode = xkb.max_key_code;

    tmp = syms.mapWidth * (xkb.max_key_code - xkb.min_key_code + 1);
    syms.map = cast(uint*)calloc(tmp, typeof(*syms.map).sizeof);
    if (!syms.map) {
        free(syms);
        return null;
    }

    for (key = xkb.min_key_code; key <= xkb.max_key_code; key++) {
        KeySym* pCore = void, pXKB = void;
        uint nGroups = void, groupWidth = void, n = void, nOut = void;

        nGroups = mixin(XkbKeyNumGroups!("xkb", "key"));
        n = (key - xkb.min_key_code) * syms.mapWidth;
        pCore = &syms.map[n];
        pXKB = mixin(XkbKeySymsPtr!("xkb", "key"));
        nOut = 2;
        if (nGroups > 0) {
            groupWidth = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup1Index"));
            if (groupWidth > 0)
                pCore[0] = pXKB[0];
            if (groupWidth > 1)
                pCore[1] = pXKB[1];
            for (n = 2; n < groupWidth; n++)
                pCore[2 + n] = pXKB[n];
            if (groupWidth > 2)
                nOut = groupWidth;
        }

        /* See XKB Protocol Sec, Section 12.4.
           A 1-group key with ABCDE on a 2 group keyboard must be
           duplicated across all groups as ABABCDECDE.
         */
        if (nGroups == 1) {
            int idx = void, j = void;

            groupWidth = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup1Index"));

            /* AB..CDE... -> ABABCDE... */
            if (groupWidth > 0 && syms.mapWidth >= 3)
                pCore[2] = pCore[0];
            if (groupWidth > 1 && syms.mapWidth >= 4)
                pCore[3] = pCore[1];

            /* ABABCDE... -> ABABCDECDE */
            idx = 2 + groupWidth;
            while (groupWidth > 2 && idx < syms.mapWidth &&
                   idx < groupWidth * 2) {
                pCore[idx] = pCore[idx - groupWidth + 2];
                idx++;
            }
            idx = 2 * groupWidth;
            if (idx < 4)
                idx = 4;
            /* 3 or more groups: ABABCDECDEABCDEABCDE */
            for (j = 3; j <= maxNumberOfGroups; j++)
                for (n = 0; n < groupWidth && idx < maxSymsPerKey; n++)
                    pCore[idx++] = pXKB[n];
        }

        pXKB += mixin(XkbKeyGroupsWidth!("xkb", "key"));
        nOut += 2;
        if (nGroups > 1) {
            groupWidth = mixin(XkbKeyGroupWidth!("xkb", "key", "XkbGroup2Index"));
            if (groupWidth > 0)
                pCore[2] = pXKB[0];
            if (groupWidth > 1)
                pCore[3] = pXKB[1];
            for (n = 2; n < groupWidth; n++) {
                pCore[nOut + (n - 2)] = pXKB[n];
            }
            if (groupWidth > 2)
                nOut += (groupWidth - 2);
        }
        pXKB += mixin(XkbKeyGroupsWidth!("xkb", "key"));
        for (n = XkbGroup3Index; n < nGroups; n++) {
            int s = void;

            groupWidth = mixin(XkbKeyGroupWidth!("xkb", "key", "n"));
            for (s = 0; s < groupWidth; s++) {
                pCore[nOut++] = pXKB[s];
            }
            pXKB += mixin(XkbKeyGroupsWidth!("xkb", "key"));
        }
    }

    return syms;
}

void XkbSetRepeatKeys(DeviceIntPtr pXDev, int key, int onoff)
{
    if (pXDev && pXDev.key && pXDev.key.xkbInfo) {
        xkbControlsNotify cn = { 0 };
        XkbControlsPtr ctrls = pXDev.key.xkbInfo.desc.ctrls;
        XkbControlsRec old = { 0 };

        old = *ctrls;

        if (key == -1) {        /* global autorepeat setting changed */
            if (onoff)
                ctrls.enabled_ctrls |= XkbRepeatKeysMask;
            else
                ctrls.enabled_ctrls &= ~XkbRepeatKeysMask;
        }
        else if (pXDev.kbdfeed) {
            ctrls.per_key_repeat[key / 8] =
                pXDev.kbdfeed.ctrl.autoRepeats[key / 8];
        }

        if (XkbComputeControlsNotify(pXDev, &old, ctrls, &cn, True))
            XkbSendControlsNotify(pXDev, &cn);
    }
    return;
}

/* Applies a change to a single device, does not traverse the device tree. */
void XkbApplyMappingChange(DeviceIntPtr kbd, KeySymsPtr map, KeyCode first_key, CARD8 num_keys, CARD8* modmap, ClientPtr client)
{
    XkbDescPtr xkb = kbd.key.xkbInfo.desc;
    XkbEventCauseRec cause = { 0 };
    XkbChangesRec changes = { 0 };
    uint check = void;

    if (map && first_key && num_keys) {
        check = 0;
        mixin(XkbSetCauseCoreReq!("&cause", "X_ChangeKeyboardMapping", "client"));

        XkbUpdateKeyTypesFromCore(kbd, map, first_key, num_keys, &changes);
        XkbUpdateActions(kbd, first_key, num_keys, &changes, &check, &cause);

        if (check)
            XkbCheckSecondaryEffects(kbd.key.xkbInfo, 1, &changes, &cause);
    }

    if (modmap) {
        /* A keymap change can imply a modmap change, se we prefer the
         * former. */
        if (!cause.mjr)
            mixin(XkbSetCauseCoreReq!("&cause", "X_SetModifierMapping", "client"));

        check = 0;
        num_keys = cast(ubyte)(xkb.max_key_code - xkb.min_key_code + 1);
        changes.map.changed |= XkbModifierMapMask;
        changes.map.first_modmap_key = cast(ubyte)(xkb.min_key_code);
        changes.map.num_modmap_keys = cast(ubyte)(num_keys);
        memcpy(kbd.key.xkbInfo.desc.map.modmap, modmap, MAP_LENGTH);
        XkbUpdateActions(kbd, xkb.min_key_code, num_keys, &changes, &check,
                         &cause);

        if (check)
            XkbCheckSecondaryEffects(kbd.key.xkbInfo, 1, &changes, &cause);
    }

    XkbSendNotification(kbd, &changes, &cause);
}

void XkbDisableComputedAutoRepeats(DeviceIntPtr dev, uint key)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    xkbMapNotify mn = { 0 };

    xkbi.desc.server.explicit[key] |= XkbExplicitAutoRepeatMask;
    mn.changed = cast(ushort)XkbExplicitComponentsMask;
    mn.firstKeyExplicit = cast(ubyte)key;
    mn.nKeyExplicit = 1;
    XkbSendMapNotify(dev, &mn);
    return;
}

uint XkbStateChangedFlags(XkbStatePtr old, XkbStatePtr new_)
{
    int changed = void;

    changed = cast(int)(old.group != new_.group ? XkbGroupStateMask : 0);
    changed |= (old.base_group != new_.base_group ? XkbGroupBaseMask : 0);
    changed |=
        (old.latched_group != new_.latched_group ? XkbGroupLatchMask : 0);
    changed |= (old.locked_group != new_.locked_group ? XkbGroupLockMask : 0);
    changed |= (old.mods != new_.mods ? XkbModifierStateMask : 0);
    changed |= (old.base_mods != new_.base_mods ? XkbModifierBaseMask : 0);
    changed |=
        (old.latched_mods != new_.latched_mods ? XkbModifierLatchMask : 0);
    changed |= (old.locked_mods != new_.locked_mods ? XkbModifierLockMask : 0);
    changed |=
        (old.compat_state != new_.compat_state ? XkbCompatStateMask : 0);
    changed |= (old.grab_mods != new_.grab_mods ? XkbGrabModsMask : 0);
    if (old.compat_grab_mods != new_.compat_grab_mods)
        changed |= XkbCompatGrabModsMask;
    changed |= (old.lookup_mods != new_.lookup_mods ? XkbLookupModsMask : 0);
    if (old.compat_lookup_mods != new_.compat_lookup_mods)
        changed |= XkbCompatLookupModsMask;
    changed |=
        (old.ptr_buttons != new_.ptr_buttons ? XkbPointerButtonMask : 0);
    return changed;
}

private void XkbComputeCompatState(XkbSrvInfoPtr xkbi)
{
    CARD16 grp_mask = void;
    XkbStatePtr state = &xkbi.state;
    XkbCompatMapPtr map = void;
    XkbControlsPtr ctrls = void;

    if (!state || !xkbi.desc || !xkbi.desc.ctrls || !xkbi.desc.compat)
        return;

    map = xkbi.desc.compat;
    grp_mask = map.groups[state.group].mask;
    state.compat_state = cast(ubyte)(state.mods | grp_mask);
    state.compat_lookup_mods = cast(ubyte)(state.lookup_mods | grp_mask);
    ctrls= xkbi.desc.ctrls;

    if (ctrls.enabled_ctrls & XkbIgnoreGroupLockMask) {
	ubyte grp = cast(ubyte)(state.base_group+state.latched_group);
	if (grp >= ctrls.num_groups)
	    grp = cast(ubyte)XkbAdjustGroup(mixin(XkbCharToInt!("grp")), ctrls);
        grp_mask = map.groups[grp].mask;
    }
    state.compat_grab_mods = cast(ubyte)(state.grab_mods | grp_mask);
    return;
}

uint XkbAdjustGroup(int group, XkbControlsPtr ctrls)
{
    uint act = void;

    act = mixin(XkbOutOfRangeGroupAction!("ctrls.groups_wrap"));
    if (group < 0) {
        while (group < 0) {
            if (act == XkbClampIntoRange) {
                group = XkbGroup1Index;
            }
            else if (act == XkbRedirectIntoRange) {
                int newGroup = void;

                newGroup = mixin(XkbOutOfRangeGroupNumber!("ctrls.groups_wrap"));
                if (newGroup >= ctrls.num_groups)
                    group = XkbGroup1Index;
                else
                    group = newGroup;
            }
            else {
                group += ctrls.num_groups;
            }
        }
    }
    else if (group >= ctrls.num_groups) {
        if (act == XkbClampIntoRange) {
            group = ctrls.num_groups - 1;
        }
        else if (act == XkbRedirectIntoRange) {
            int newGroup = void;

            newGroup = mixin(XkbOutOfRangeGroupNumber!("ctrls.groups_wrap"));
            if (newGroup >= ctrls.num_groups)
                group = XkbGroup1Index;
            else
                group = newGroup;
        }
        else {
            group %= ctrls.num_groups;
        }
    }
    return group;
}

void XkbComputeDerivedState(XkbSrvInfoPtr xkbi)
{
    XkbStatePtr state = &xkbi.state;
    XkbControlsPtr ctrls = xkbi.desc.ctrls;
    ubyte grp = void;

    if (!state || !ctrls)
        return;

    state.mods = (state.base_mods | state.latched_mods | state.locked_mods);
    state.lookup_mods = state.mods & (~ctrls.internal.mask);
    state.grab_mods = state.lookup_mods & (~ctrls.ignore_lock.mask);
    state.grab_mods |=
        ((state.base_mods | state.latched_mods) & ctrls.ignore_lock.mask);

    grp = state.locked_group;
    if (grp >= ctrls.num_groups)
        state.locked_group = cast(ubyte)XkbAdjustGroup(mixin(XkbCharToInt!("grp")), ctrls);

    grp = cast(ubyte)(state.locked_group + state.base_group + state.latched_group);
    if (grp >= ctrls.num_groups)
        state.group = cast(ubyte)XkbAdjustGroup(mixin(XkbCharToInt!("grp")), ctrls);
    else
        state.group = grp;
    XkbComputeCompatState(xkbi);
    return;
}

/***====================================================================***/

void XkbCheckSecondaryEffects(XkbSrvInfoPtr xkbi, uint which, XkbChangesPtr changes, XkbEventCausePtr cause)
{
    if (which & XkbStateNotifyMask) {
        XkbStateRec old = { 0 };

        old = xkbi.state;
        changes.state_changes |= XkbStateChangedFlags(&old, &xkbi.state);
        XkbComputeDerivedState(xkbi);
    }
    if (which & XkbIndicatorStateNotifyMask)
        XkbUpdateIndicators(xkbi.device, XkbAllIndicatorsMask, True, changes,
                            cause);
    return;
}

/***====================================================================***/

Bool XkbEnableDisableControls(XkbSrvInfoPtr xkbi, c_ulong change, c_ulong newValues, XkbChangesPtr changes, XkbEventCausePtr cause)
{
    XkbControlsPtr ctrls = void;
    uint old = void;
    XkbSrvLedInfoPtr sli = void;

    ctrls = xkbi.desc.ctrls;
    old = ctrls.enabled_ctrls;
    ctrls.enabled_ctrls &= ~change;
    ctrls.enabled_ctrls |= (change & newValues);
    if (old == ctrls.enabled_ctrls)
        return False;
    if (cause !is null) {
        xkbControlsNotify cn = { 0 };

        cn.numGroups = ctrls.num_groups;
        cn.changedControls = cast(uint)XkbControlsEnabledMask;
        cn.enabledControls = ctrls.enabled_ctrls;
        cn.enabledControlChanges = (ctrls.enabled_ctrls ^ old);
        cn.keycode = cause.kc;
        cn.eventType = cause.event;
        cn.requestMajor = cause.mjr;
        cn.requestMinor = cause.mnr;
        XkbSendControlsNotify(xkbi.device, &cn);
    }
    else {
        /* Yes, this really should be an XOR.  If ctrls->enabled_ctrls_changes */
        /* is non-zero, the controls in question changed already in "this" */
        /* request and this change merely undoes the previous one.  By the */
        /* same token, we have to figure out whether or not ControlsEnabled */
        /* should be set or not in the changes structure */
        changes.ctrls.enabled_ctrls_changes ^= (ctrls.enabled_ctrls ^ old);
        if (changes.ctrls.enabled_ctrls_changes)
            changes.ctrls.changed_ctrls |= XkbControlsEnabledMask;
        else
            changes.ctrls.changed_ctrls &= ~XkbControlsEnabledMask;
    }
    sli = XkbFindSrvLedInfo(xkbi.device, XkbDfltXIClass, XkbDfltXIId, 0);
    XkbUpdateIndicators(xkbi.device, sli.usesControls, True, changes, cause);
    return True;
}

/***====================================================================***/

enum	MAX_TOC =	16;

XkbGeometryPtr XkbLookupNamedGeometry(DeviceIntPtr dev, Atom name, Bool* shouldFree)
{
    XkbSrvInfoPtr xkbi = dev.key.xkbInfo;
    XkbDescPtr xkb = xkbi.desc;

    *shouldFree = 0;
    if (name == None) {
        if (xkb.geom !is null)
            return xkb.geom;
        name = xkb.names.geometry;
    }
    if ((xkb.geom !is null) && (xkb.geom.name == name))
        return xkb.geom;
    *shouldFree = 1;
    return null;
}

void XkbConvertCase(KeySym sym, KeySym* lower, KeySym* upper)
{
    *lower = sym;
    *upper = sym;
    switch (sym >> 8) {
    case 0:                    /* Latin 1 */
        if ((sym >= XK_A) && (sym <= XK_Z))
            *lower += (XK_a - XK_A);
        else if ((sym >= XK_a) && (sym <= XK_z))
            *upper -= (XK_a - XK_A);
        else if ((sym >= XK_Agrave) && (sym <= XK_Odiaeresis))
            *lower += (XK_agrave - XK_Agrave);
        else if ((sym >= XK_agrave) && (sym <= XK_odiaeresis))
            *upper -= (XK_agrave - XK_Agrave);
        else if ((sym >= XK_Ooblique) && (sym <= XK_Thorn))
            *lower += (XK_oslash - XK_Ooblique);
        else if ((sym >= XK_oslash) && (sym <= XK_thorn))
            *upper -= (XK_oslash - XK_Ooblique);
        break;
    case 1:                    /* Latin 2 */
        /* Assume the KeySym is a legal value (ignore discontinuities) */
        if (sym == XK_Aogonek)
            *lower = XK_aogonek;
        else if (sym >= XK_Lstroke && sym <= XK_Sacute)
            *lower += (XK_lstroke - XK_Lstroke);
        else if (sym >= XK_Scaron && sym <= XK_Zacute)
            *lower += (XK_scaron - XK_Scaron);
        else if (sym >= XK_Zcaron && sym <= XK_Zabovedot)
            *lower += (XK_zcaron - XK_Zcaron);
        else if (sym == XK_aogonek)
            *upper = XK_Aogonek;
        else if (sym >= XK_lstroke && sym <= XK_sacute)
            *upper -= (XK_lstroke - XK_Lstroke);
        else if (sym >= XK_scaron && sym <= XK_zacute)
            *upper -= (XK_scaron - XK_Scaron);
        else if (sym >= XK_zcaron && sym <= XK_zabovedot)
            *upper -= (XK_zcaron - XK_Zcaron);
        else if (sym >= XK_Racute && sym <= XK_Tcedilla)
            *lower += (XK_racute - XK_Racute);
        else if (sym >= XK_racute && sym <= XK_tcedilla)
            *upper -= (XK_racute - XK_Racute);
        break;
    case 2:                    /* Latin 3 */
        /* Assume the KeySym is a legal value (ignore discontinuities) */
        if (sym >= XK_Hstroke && sym <= XK_Hcircumflex)
            *lower += (XK_hstroke - XK_Hstroke);
        else if (sym >= XK_Gbreve && sym <= XK_Jcircumflex)
            *lower += (XK_gbreve - XK_Gbreve);
        else if (sym >= XK_hstroke && sym <= XK_hcircumflex)
            *upper -= (XK_hstroke - XK_Hstroke);
        else if (sym >= XK_gbreve && sym <= XK_jcircumflex)
            *upper -= (XK_gbreve - XK_Gbreve);
        else if (sym >= XK_Cabovedot && sym <= XK_Scircumflex)
            *lower += (XK_cabovedot - XK_Cabovedot);
        else if (sym >= XK_cabovedot && sym <= XK_scircumflex)
            *upper -= (XK_cabovedot - XK_Cabovedot);
        break;
    case 3:                    /* Latin 4 */
        /* Assume the KeySym is a legal value (ignore discontinuities) */
        if (sym >= XK_Rcedilla && sym <= XK_Tslash)
            *lower += (XK_rcedilla - XK_Rcedilla);
        else if (sym >= XK_rcedilla && sym <= XK_tslash)
            *upper -= (XK_rcedilla - XK_Rcedilla);
        else if (sym == XK_ENG)
            *lower = XK_eng;
        else if (sym == XK_eng)
            *upper = XK_ENG;
        else if (sym >= XK_Amacron && sym <= XK_Umacron)
            *lower += (XK_amacron - XK_Amacron);
        else if (sym >= XK_amacron && sym <= XK_umacron)
            *upper -= (XK_amacron - XK_Amacron);
        break;
    case 6:                    /* Cyrillic */
        /* Assume the KeySym is a legal value (ignore discontinuities) */
        if (sym >= XK_Serbian_DJE && sym <= XK_Cyrillic_DZHE)
            *lower -= (XK_Serbian_DJE - XK_Serbian_dje);
        else if (sym >= XK_Serbian_dje && sym <= XK_Cyrillic_dzhe)
            *upper += (XK_Serbian_DJE - XK_Serbian_dje);
        else if (sym >= XK_Cyrillic_YU && sym <= XK_Cyrillic_HARDSIGN)
            *lower -= (XK_Cyrillic_YU - XK_Cyrillic_yu);
        else if (sym >= XK_Cyrillic_yu && sym <= XK_Cyrillic_hardsign)
            *upper += (XK_Cyrillic_YU - XK_Cyrillic_yu);
        break;
    case 7:                    /* Greek */
        /* Assume the KeySym is a legal value (ignore discontinuities) */
        if (sym >= XK_Greek_ALPHAaccent && sym <= XK_Greek_OMEGAaccent)
            *lower += (XK_Greek_alphaaccent - XK_Greek_ALPHAaccent);
        else if (sym >= XK_Greek_alphaaccent && sym <= XK_Greek_omegaaccent &&
                 sym != XK_Greek_iotaaccentdieresis &&
                 sym != XK_Greek_upsilonaccentdieresis)
            *upper -= (XK_Greek_alphaaccent - XK_Greek_ALPHAaccent);
        else if (sym >= XK_Greek_ALPHA && sym <= XK_Greek_OMEGA)
            *lower += (XK_Greek_alpha - XK_Greek_ALPHA);
        else if (sym >= XK_Greek_alpha && sym <= XK_Greek_omega &&
                 sym != XK_Greek_finalsmallsigma)
            *upper -= (XK_Greek_alpha - XK_Greek_ALPHA);
        break;
    default: break;}
}

private Bool _XkbCopyClientMap(XkbDescPtr src, XkbDescPtr dst)
{
    void* tmp = null;
    int i = void;
    int gap = void;
    XkbKeyTypePtr stype = null, dtype = null;

    /* client map */
    if (src.map) {
        if (!dst.map) {
            tmp = cast(XkbClientMapRec*) calloc(1, XkbClientMapRec.sizeof);
            if (!tmp)
                return False;
            dst.map = cast(_XkbClientMapRec*)tmp;
        }

        if (src.map.syms) {
            if (src.map.size_syms != dst.map.size_syms) {
                tmp = reallocarray(dst.map.syms,
                                   src.map.size_syms, KeySym.sizeof);
                if (!tmp)
                    return False;
                dst.map.syms = cast(uint*)tmp;

            }
            memcpy(dst.map.syms, src.map.syms,
                   src.map.size_syms * KeySym.sizeof);
        }
        else {
            free(dst.map.syms);
            dst.map.syms = cast(uint*)null;
        }
        dst.map.num_syms = src.map.num_syms;
        dst.map.size_syms = src.map.size_syms;
        gap = MAP_LENGTH - (src.max_key_code + 1);

        if (src.map.key_sym_map) {
            if (!dst.map.key_sym_map) {
                tmp = reallocarray(dst.map.key_sym_map,
                                   MAP_LENGTH, XkbSymMapRec.sizeof);
                if (!tmp)
                    return False;
                dst.map.key_sym_map = cast(_XkbSymMapRec*)tmp;
            }
            if (gap > 0) {
                memset(cast(char*) &dst.map.key_sym_map[gap], 0,
                       gap * XkbSymMapRec.sizeof);
            }
            memcpy(dst.map.key_sym_map, src.map.key_sym_map,
                   (src.max_key_code + 1) * XkbSymMapRec.sizeof);
        }
        else {
            free(dst.map.key_sym_map);
            dst.map.key_sym_map = cast(_XkbSymMapRec*)null;
        }

        if (src.map.types && src.map.num_types) {
            if (src.map.num_types > dst.map.size_types ||
                !dst.map.types || !dst.map.size_types) {
                if (dst.map.types && dst.map.size_types) {
                    tmp = reallocarray(dst.map.types, src.map.num_types,
                                       XkbKeyTypeRec.sizeof);
                    if (!tmp)
                        return False;
                    dst.map.types = cast(_XkbKeyType*)tmp;
                    memset(dst.map.types + dst.map.num_types, 0,
                           (src.map.num_types - dst.map.num_types) *
                           XkbKeyTypeRec.sizeof);
                }
                else {
                    tmp = calloc(src.map.num_types, XkbKeyTypeRec.sizeof);
                    if (!tmp)
                        return False;
                    dst.map.types = cast(_XkbKeyType*)tmp;
                }
            }
            else if (src.map.num_types < dst.map.num_types &&
                     dst.map.types) {
                for (i = src.map.num_types, dtype = (dst.map.types + i);
                     i < dst.map.num_types; i++, dtype++) {
                    free(dtype.level_names);
                    dtype.level_names = cast(uint*)null;
                    dtype.num_levels = cast(ubyte*)0;
                    if (dtype.map_count) {
                        free(dtype.map);
                        free(dtype.preserve);
                    }
                }
            }

            stype = src.map.types;
            dtype = dst.map.types;
            for (i = 0; i < src.map.num_types; i++, dtype++, stype++) {
                if (stype.num_levels && stype.level_names) {
                    if (stype.num_levels != dtype.num_levels &&
                        dtype.num_levels && dtype.level_names &&
                        i < dst.map.num_types) {
                        tmp = reallocarray(dtype.level_names,
                                           stype.num_levels, Atom.sizeof);
                        if (!tmp)
                            continue;
                        dtype.level_names = cast(uint*)tmp;
                    }
                    else if (!dtype.num_levels || !dtype.level_names ||
                             i >= dst.map.num_types) {
                        tmp = calloc(stype.num_levels, Atom.sizeof);
                        if (!tmp)
                            continue;
                        dtype.level_names = cast(uint*)tmp;
                    }
                    dtype.num_levels = cast(ubyte*)stype.num_levels;
                    memcpy(dtype.level_names, stype.level_names,
                           stype.num_levels * Atom.sizeof);
                }
                else {
                    if (dtype.num_levels && dtype.level_names &&
                        i < dst.map.num_types)
                        free(dtype.level_names);
                    dtype.num_levels = cast(ubyte*)stype.num_levels;
                    dtype.level_names = cast(uint*)null;
                }

                dtype.name = stype.name;
                memcpy(&dtype.mods, &stype.mods, XkbModsRec.sizeof);

                if (stype.map_count) {
                    if (stype.map) {
                        if (stype.map_count != dtype.map_count &&
                            dtype.map_count && dtype.map &&
                            i < dst.map.num_types) {
                            tmp = reallocarray(dtype.map,
                                               stype.map_count,
                                               XkbKTMapEntryRec.sizeof);
                            if (!tmp)
                                return False;
                            dtype.map = cast(_XkbKTMapEntry*)tmp;
                        }
                        else if (!dtype.map_count || !dtype.map ||
                                 i >= dst.map.num_types) {
                            tmp = calloc(stype.map_count,
                                         XkbKTMapEntryRec.sizeof);
                            if (!tmp)
                                return False;
                            dtype.map = cast(_XkbKTMapEntry*)tmp;
                        }

                        memcpy(dtype.map, stype.map,
                               stype.map_count * XkbKTMapEntryRec.sizeof);
                    }
                    else {
                        if (dtype.map && i < dst.map.num_types)
                            free(dtype.map);
                        dtype.map = null;
                    }

                    if (stype.preserve) {
                        if (stype.map_count != dtype.map_count &&
                            dtype.map_count && dtype.preserve &&
                            i < dst.map.num_types) {
                            tmp = reallocarray(dtype.preserve,
                                               stype.map_count,
                                               XkbModsRec.sizeof);
                            if (!tmp)
                                return False;
                            dtype.preserve = cast(_XkbMods*)tmp;
                        }
                        else if (!dtype.preserve || !dtype.map_count ||
                                 i >= dst.map.num_types) {
                            tmp = calloc(stype.map_count, XkbModsRec.sizeof);
                            if (!tmp)
                                return False;
                            dtype.preserve = cast(_XkbMods*)tmp;
                        }

                        memcpy(dtype.preserve, stype.preserve,
                               stype.map_count * XkbModsRec.sizeof);
                    }
                    else {
                        if (dtype.preserve && i < dst.map.num_types)
                            free(dtype.preserve);
                        dtype.preserve = cast(_XkbMods*)null;
                    }

                    dtype.map_count = cast(ubyte)cast(ubyte*)stype.map_count;
                }
                else {
                    if (dtype.map_count && i < dst.map.num_types) {
                        free(dtype.map);
                        free(dtype.preserve);
                    }
                    dtype.map_count = cast(ubyte)cast(ubyte*)0;
                    dtype.map = null;
                    dtype.preserve = cast(_XkbMods*)null;
                }
            }

            dst.map.size_types = cast(ubyte)src.map.num_types;
            dst.map.num_types = src.map.num_types;
        }
        else {
            if (dst.map.types) {
                for (i = 0, dtype = dst.map.types; i < dst.map.num_types;
                     i++, dtype++) {
                    free(dtype.level_names);
                    if (dtype.map && dtype.map_count)
                        free(dtype.map);
                    if (dtype.preserve && dtype.map_count)
                        free(dtype.preserve);
                }
            }
            free(dst.map.types);
            dst.map.types = null;
            dst.map.num_types = 0;
            dst.map.size_types = cast(ubyte)0;
        }

        if (src.map.modmap) {
            if (!dst.map.modmap) {
                tmp = realloc(dst.map.modmap, MAP_LENGTH);
                if (!tmp)
                    return False;
                dst.map.modmap = cast(ubyte*)tmp;
            }
            if (gap > 0) {
                memset(dst.map.modmap + gap, 0, gap);
            }
            memcpy(dst.map.modmap, src.map.modmap, src.max_key_code + 1);
        }
        else {
            free(dst.map.modmap);
            dst.map.modmap = cast(ubyte*)null;
        }
    }
    else {
        if (dst.map)
            XkbFreeClientMap(dst, XkbAllClientInfoMask, True);
    }

    return True;
}

private Bool _XkbCopyServerMap(XkbDescPtr src, XkbDescPtr dst)
{
    void* tmp = null;
    int gap = void;

    /* server map */
    if (src.server) {
        if (!dst.server) {
            tmp = cast(XkbServerMapRec*) calloc(1, XkbServerMapRec.sizeof);
            if (!tmp)
                return False;
            dst.server = cast(_XkbServerMapRec*)tmp;
        }

        gap = MAP_LENGTH - (src.max_key_code + 1);
        if (src.server.explicit) {
            if (!dst.server.explicit) {
                tmp = realloc(dst.server.explicit, MAP_LENGTH);
                if (!tmp)
                    return False;
                dst.server.explicit = cast(ubyte*)tmp;
            }
            if (gap > 0)
                memset(dst.server.explicit + gap, 0, gap);
            memcpy(dst.server.explicit, src.server.explicit,
                   src.max_key_code + 1);
        }
        else {
            free(dst.server.explicit);
            dst.server.explicit = null;
        }

        if (src.server.acts) {
            if (src.server.size_acts != dst.server.size_acts) {
                tmp = reallocarray(dst.server.acts,
                                   src.server.size_acts, XkbAction.sizeof);
                if (!tmp)
                    return False;
                dst.server.acts = cast(_XkbAction*)tmp;
            }
            memcpy(dst.server.acts, src.server.acts,
                   src.server.size_acts * XkbAction.sizeof);
        }
        else {
            free(dst.server.acts);
            dst.server.acts = null;
        }
        dst.server.size_acts = src.server.size_acts;
        dst.server.num_acts = src.server.num_acts;

        if (src.server.key_acts) {
            if (!dst.server.key_acts) {
                tmp = reallocarray(dst.server.key_acts,
                                   MAP_LENGTH, ushort.sizeof);
                if (!tmp)
                    return False;
                dst.server.key_acts = cast(ushort*)tmp;
            }
            if (gap > 0)
                memset(cast(char*) &dst.server.key_acts[gap], 0, gap * ushort.sizeof);
            memcpy(dst.server.key_acts, src.server.key_acts,
                   (src.max_key_code + 1) * ushort.sizeof);
        }
        else {
            free(dst.server.key_acts);
            dst.server.key_acts = null;
        }

        if (src.server.behaviors) {
            if (!dst.server.behaviors) {
                tmp = reallocarray(dst.server.behaviors,
                                   MAP_LENGTH, XkbBehavior.sizeof);
                if (!tmp)
                    return False;
                dst.server.behaviors = cast(_XkbBehavior*)tmp;
            }
            if (gap > 0)
                memset(cast(char*) &dst.server.behaviors[gap], 0, gap * XkbBehavior.sizeof);
            memcpy(dst.server.behaviors, src.server.behaviors,
                   (src.max_key_code + 1) * XkbBehavior.sizeof);
        }
        else {
            free(dst.server.behaviors);
            dst.server.behaviors = null;
        }

        memcpy(dst.server.vmods.ptr, src.server.vmods.ptr, XkbNumVirtualMods);

        if (src.server.vmodmap) {
            if (!dst.server.vmodmap) {
                tmp = reallocarray(dst.server.vmodmap,
                                   MAP_LENGTH, ushort.sizeof);
                if (!tmp)
                    return False;
                dst.server.vmodmap = cast(ushort*)tmp;
            }
            if (gap > 0)
                memset(cast(char*) &dst.server.vmodmap[gap], 0, gap * ushort.sizeof);
            memcpy(dst.server.vmodmap, src.server.vmodmap,
                   (src.max_key_code + 1) * ushort.sizeof);
        }
        else {
            free(dst.server.vmodmap);
            dst.server.vmodmap = null;
        }
    }
    else {
        if (dst.server)
            XkbFreeServerMap(dst, XkbAllServerInfoMask, True);
    }

    return True;
}

private Bool _XkbCopyNames(XkbDescPtr src, XkbDescPtr dst)
{
    void* tmp = null;
    int gap = void;

    /* names */
    if (src.names) {
        if (!dst.names) {
            dst.names = cast(XkbNamesRec*) calloc(1, XkbNamesRec.sizeof);
            if (!dst.names)
                return False;
        }

        gap = MAP_LENGTH - (src.max_key_code + 1);
        if (src.names.keys) {
            if (!dst.names.keys) {
                tmp = reallocarray(dst.names.keys, MAP_LENGTH,
                                   XkbKeyNameRec.sizeof);
                if (!tmp)
                    return False;
                dst.names.keys = cast(_XkbKeyNameRec*)tmp;
            }
            if (gap > 0)
                memset(cast(char*) &dst.names.keys[gap], 0, gap * XkbKeyNameRec.sizeof);
            memcpy(dst.names.keys, src.names.keys,
                   (src.max_key_code + 1) * XkbKeyNameRec.sizeof);
        }
        else {
            free(dst.names.keys);
            dst.names.keys = null;
        }

        if (src.names.num_key_aliases) {
            if (src.names.num_key_aliases != dst.names.num_key_aliases) {
                tmp = reallocarray(dst.names.key_aliases,
                                   src.names.num_key_aliases,
                                   XkbKeyAliasRec.sizeof);
                if (!tmp)
                    return False;
                dst.names.key_aliases = cast(_XkbKeyAliasRec*)tmp;
            }
            memcpy(dst.names.key_aliases, src.names.key_aliases,
                   src.names.num_key_aliases * XkbKeyAliasRec.sizeof);
        }
        else {
            free(dst.names.key_aliases);
            dst.names.key_aliases = null;
        }
        dst.names.num_key_aliases = cast(ubyte)src.names.num_key_aliases;

        if (src.names.num_rg) {
            if (src.names.num_rg != dst.names.num_rg) {
                tmp = reallocarray(dst.names.radio_groups,
                                   src.names.num_rg, Atom.sizeof);
                if (!tmp)
                    return False;
                dst.names.radio_groups = cast(uint*)tmp;
            }
            memcpy(dst.names.radio_groups, src.names.radio_groups,
                   src.names.num_rg * Atom.sizeof);
        }
        else {
            free(dst.names.radio_groups);
            dst.names.radio_groups = null;
        }
        dst.names.num_rg = cast(ushort)src.names.num_rg;

        dst.names.keycodes = src.names.keycodes;
        dst.names.geometry = src.names.geometry;
        dst.names.symbols = src.names.symbols;
        dst.names.types = src.names.types;
        dst.names.compat = src.names.compat;
        dst.names.phys_symbols = src.names.phys_symbols;

        memcpy(dst.names.vmods.ptr, src.names.vmods.ptr,
               XkbNumVirtualMods * Atom.sizeof);
        memcpy(dst.names.indicators.ptr, src.names.indicators.ptr,
               XkbNumIndicators * Atom.sizeof);
        memcpy(dst.names.groups.ptr, src.names.groups.ptr,
               XkbNumKbdGroups * Atom.sizeof);
    }
    else {
        if (dst.names)
            XkbFreeNames(dst, XkbAllNamesMask, True);
    }

    return True;
}

private Bool _XkbCopyCompat(XkbDescPtr src, XkbDescPtr dst)
{
    void* tmp = null;

    /* compat */
    if (src.compat) {
        if (!dst.compat) {
            dst.compat = cast(XkbCompatMapRec*) calloc(1, XkbCompatMapRec.sizeof);
            if (!dst.compat)
                return False;
        }

        if (src.compat.sym_interpret && src.compat.num_si) {
            if (src.compat.num_si != dst.compat.size_si) {
                tmp = reallocarray(dst.compat.sym_interpret,
                                   src.compat.num_si,
                                   XkbSymInterpretRec.sizeof);
                if (!tmp)
                    return False;
                dst.compat.sym_interpret = cast(_XkbSymInterpretRec*)tmp;
            }
            memcpy(dst.compat.sym_interpret, src.compat.sym_interpret,
                   src.compat.num_si * XkbSymInterpretRec.sizeof);

            dst.compat.num_si = src.compat.num_si;
            dst.compat.size_si = src.compat.num_si;
        }
        else {
            if (dst.compat.sym_interpret && dst.compat.size_si)
                free(dst.compat.sym_interpret);

            dst.compat.sym_interpret = null;
            dst.compat.num_si = 0;
            dst.compat.size_si = 0;
        }

        memcpy(dst.compat.groups.ptr, src.compat.groups.ptr,
               XkbNumKbdGroups * XkbModsRec.sizeof);
    }
    else {
        if (dst.compat)
            XkbFreeCompatMap(dst, XkbAllCompatMask, True);
    }

    return True;
}

private Bool _XkbCopyGeom(XkbDescPtr src, XkbDescPtr dst)
{
    void* tmp = null;
    int i = 0, j = 0, k = 0;
    XkbColorPtr scolor = null, dcolor = null;
    XkbDoodadPtr sdoodad = null, ddoodad = null;
    XkbOutlinePtr soutline = null, doutline = null;
    XkbPropertyPtr sprop = null, dprop = null;
    XkbRowPtr srow = null, drow = null;
    XkbSectionPtr ssection = null, dsection = null;
    XkbShapePtr sshape = null, dshape = null;

    /* geometry */
    if (src.geom) {
        if (!dst.geom) {
            dst.geom = cast(_XkbGeometry*)calloc(XkbGeometryRec.sizeof, 1);
            if (!dst.geom)
                return False;
        }

        /* properties */
        if (src.geom.num_properties) {
            /* If we've got more properties in the destination than
             * the source, run through and free all the excess ones
             * first. */
            if (src.geom.num_properties < dst.geom.sz_properties) {
                for (i = src.geom.num_properties, dprop =
                     dst.geom.properties + i; i < dst.geom.num_properties;
                     i++, dprop++) {
                    free(dprop.name);
                    free(dprop.value);
                }
            }

            /* Reallocate and clear all new items if the buffer grows. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.properties, dst.geom.sz_properties,
                 src.geom.num_properties, XkbPropertyRec.sizeof,
                 XKB_GEOM_CLEAR_EXCESS))
                return False;
            /* We don't set num_properties as we need it to try and avoid
             * too much reallocing. */
            dst.geom.sz_properties = src.geom.num_properties;

            for (i = 0,
                 sprop = src.geom.properties,
                 dprop = dst.geom.properties;
                 i < src.geom.num_properties; i++, sprop++, dprop++) {
                if (i < dst.geom.num_properties) {
                    if (strlen(sprop.name) != strlen(dprop.name)) {
                        tmp = realloc(dprop.name, strlen(sprop.name) + 1);
                        if (!tmp)
                            return False;
                        dprop.name = cast(char*)tmp;
                    }
                    if (strlen(sprop.value) != strlen(dprop.value)) {
                        tmp = realloc(dprop.value, strlen(sprop.value) + 1);
                        if (!tmp)
                            return False;
                        dprop.value = cast(char*)tmp;
                    }
                    strcpy(dprop.name, sprop.name);
                    strcpy(dprop.value, sprop.value);
                }
                else {
                    dprop.name = cast(char*)Xstrdup(sprop.name);
                    dprop.value = cast(char*)Xstrdup(sprop.value);
                }
            }

            /* ... which is already src->geom->num_properties. */
            dst.geom.num_properties = dst.geom.sz_properties;
        }
        else {
            if (dst.geom.sz_properties) {
                for (i = 0, dprop = dst.geom.properties;
                     i < dst.geom.num_properties; i++, dprop++) {
                    free(dprop.name);
                    free(dprop.value);
                }
                free(dst.geom.properties);
                dst.geom.properties = null;
            }

            dst.geom.num_properties = 0;
            dst.geom.sz_properties = 0;
        }

        /* colors */
        if (src.geom.num_colors) {
            if (src.geom.num_colors < dst.geom.sz_colors) {
                for (i = src.geom.num_colors, dcolor = dst.geom.colors + i;
                     i < dst.geom.num_colors; i++, dcolor++) {
                    free(dcolor.spec);
                }
            }

            /* Reallocate and clear all new items if the buffer grows. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.colors, dst.geom.sz_colors,
                 src.geom.num_colors, XkbColorRec.sizeof,
                 XKB_GEOM_CLEAR_EXCESS))
                return False;
            dst.geom.sz_colors = src.geom.num_colors;

            for (i = 0,
                 scolor = src.geom.colors,
                 dcolor = dst.geom.colors;
                 i < src.geom.num_colors; i++, scolor++, dcolor++) {
                if (i < dst.geom.num_colors) {
                    if (strlen(scolor.spec) != strlen(dcolor.spec)) {
                        tmp = realloc(dcolor.spec, strlen(scolor.spec) + 1);
                        if (!tmp)
                            return False;
                        dcolor.spec = cast(char*)tmp;
                    }
                    strcpy(dcolor.spec, scolor.spec);
                }
                else {
                    dcolor.spec = cast(char*)Xstrdup(scolor.spec);
                }
                dcolor.pixel = scolor.pixel;
            }

            dst.geom.num_colors = dst.geom.sz_colors;
        }
        else {
            if (dst.geom.sz_colors) {
                for (i = 0, dcolor = dst.geom.colors;
                     i < dst.geom.num_colors; i++, dcolor++) {
                    free(dcolor.spec);
                }
                free(dst.geom.colors);
                dst.geom.colors = null;
            }

            dst.geom.num_colors = 0;
            dst.geom.sz_colors = 0;
        }

        /* shapes */
        /* shapes break down into outlines, which break down into points. */
        if (dst.geom.num_shapes) {
            for (i = 0, dshape = dst.geom.shapes;
                 i < dst.geom.num_shapes; i++, dshape++) {
                for (j = 0, doutline = dshape.outlines;
                     j < dshape.num_outlines; j++, doutline++) {
                    if (doutline.sz_points)
                        free(doutline.points);
                }

                if (dshape.sz_outlines) {
                    free(dshape.outlines);
                    dshape.outlines = null;
                }

                dshape.num_outlines = 0;
                dshape.sz_outlines = 0;
            }
        }

        if (src.geom.num_shapes) {
            /* Reallocate and clear all items. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.shapes, dst.geom.sz_shapes,
                 src.geom.num_shapes, XkbShapeRec.sizeof,
                 XKB_GEOM_CLEAR_ALL))
                return False;

            for (i = 0, sshape = src.geom.shapes, dshape = dst.geom.shapes;
                 i < src.geom.num_shapes; i++, sshape++, dshape++) {
                if (sshape.num_outlines) {
                    tmp = calloc(sshape.num_outlines, XkbOutlineRec.sizeof);
                    if (!tmp)
                        return False;
                    dshape.outlines = cast(_XkbOutline*)tmp;

                    for (j = 0,
                         soutline = sshape.outlines,
                         doutline = dshape.outlines;
                         j < sshape.num_outlines;
                         j++, soutline++, doutline++) {
                        if (soutline.num_points) {
                            tmp = calloc(soutline.num_points,
                                         XkbPointRec.sizeof);
                            if (!tmp)
                                return False;
                            doutline.points = cast(_XkbPoint*)tmp;

                            memcpy(doutline.points, soutline.points,
                                   soutline.num_points * XkbPointRec.sizeof);

                            doutline.corner_radius = soutline.corner_radius;
                        }

                        doutline.num_points = soutline.num_points;
                        doutline.sz_points = soutline.num_points;
                    }
                }

                dshape.num_outlines = sshape.num_outlines;
                dshape.sz_outlines = sshape.num_outlines;
                dshape.name = sshape.name;
                dshape.bounds = sshape.bounds;

                dshape.approx = null;
                if (sshape.approx && sshape.num_outlines > 0) {

                    const(ptrdiff_t) approx_idx = sshape.approx - sshape.outlines;

                    if (approx_idx < dshape.num_outlines) {
                        dshape.approx = dshape.outlines + approx_idx;
                    }
                    else {
                        LogMessage(X_WARNING, "XKB: approx outline "
                                   ~ "index is out of range\n");
                    }
                }

                dshape.primary = null;
                if (sshape.primary && sshape.num_outlines > 0) {

                    const(ptrdiff_t) primary_idx = sshape.primary - sshape.outlines;

                    if (primary_idx < dshape.num_outlines) {
                        dshape.primary = dshape.outlines + primary_idx;
                    }
                    else {
                        LogMessage(X_WARNING, "XKB: primary outline "
                                   ~ "index is out of range\n");
                    }
                }
            }

            dst.geom.num_shapes = src.geom.num_shapes;
            dst.geom.sz_shapes = src.geom.num_shapes;
        }
        else {
            if (dst.geom.sz_shapes) {
                free(dst.geom.shapes);
            }
            dst.geom.shapes = null;
            dst.geom.num_shapes = 0;
            dst.geom.sz_shapes = 0;
        }

        /* sections */
        /* sections break down into doodads, and also into rows, which break
         * down into keys. */
        if (dst.geom.num_sections) {
            for (i = 0, dsection = dst.geom.sections;
                 i < dst.geom.num_sections; i++, dsection++) {
                for (j = 0, drow = dsection.rows;
                     j < dsection.num_rows; j++, drow++) {
                    if (drow.num_keys)
                        free(drow.keys);
                }

                if (dsection.num_rows)
                    free(dsection.rows);

                /* cut and waste from geom/doodad below. */
                for (j = 0, ddoodad = dsection.doodads;
                     j < dsection.num_doodads; j++, ddoodad++) {
                    if (ddoodad.any.type == XkbTextDoodad) {
                        free(ddoodad.text.text);
                        ddoodad.text.text = null;
                        free(ddoodad.text.font);
                        ddoodad.text.font = null;
                    }
                    else if (ddoodad.any.type == XkbLogoDoodad) {
                        free(ddoodad.logo.logo_name);
                        ddoodad.logo.logo_name = null;
                    }
                }

                free(dsection.doodads);
            }

            dst.geom.num_sections = 0;
        }

        if (src.geom.num_sections) {
            /* Reallocate and clear all items. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.sections, dst.geom.sz_sections,
                 src.geom.num_sections, XkbSectionRec.sizeof,
                 XKB_GEOM_CLEAR_ALL))
                return False;
            dst.geom.num_sections = src.geom.num_sections;
            dst.geom.sz_sections = src.geom.num_sections;

            for (i = 0,
                 ssection = src.geom.sections,
                 dsection = dst.geom.sections;
                 i < src.geom.num_sections; i++, ssection++, dsection++) {
                *dsection = *ssection;
                if (ssection.num_rows) {
                    tmp = calloc(ssection.num_rows, XkbRowRec.sizeof);
                    if (!tmp)
                        return False;
                    dsection.rows = cast(_XkbRow*)tmp;
                }
                dsection.num_rows = ssection.num_rows;
                dsection.sz_rows = ssection.num_rows;

                for (j = 0, srow = ssection.rows, drow = dsection.rows;
                     j < ssection.num_rows; j++, srow++, drow++) {
                    if (srow.num_keys) {
                        tmp = calloc(srow.num_keys, XkbKeyRec.sizeof);
                        if (!tmp)
                            return False;
                        drow.keys = cast(_XkbKey*)tmp;
                        memcpy(drow.keys, srow.keys,
                               srow.num_keys * XkbKeyRec.sizeof);
                    }
                    drow.num_keys = srow.num_keys;
                    drow.sz_keys = srow.num_keys;
                    drow.top = srow.top;
                    drow.left = srow.left;
                    drow.vertical = srow.vertical;
                    drow.bounds = srow.bounds;
                }

                if (ssection.num_doodads) {
                    tmp = calloc(ssection.num_doodads, XkbDoodadRec.sizeof);
                    if (!tmp)
                        return False;
                    dsection.doodads = cast(_XkbDoodad*)tmp;
                }
                else {
                    dsection.doodads = null;
                }

                dsection.sz_doodads = ssection.num_doodads;
                for (k = 0,
                     sdoodad = ssection.doodads,
                     ddoodad = dsection.doodads;
                     k < ssection.num_doodads; k++, sdoodad++, ddoodad++) {
                    memcpy(ddoodad, sdoodad, XkbDoodadRec.sizeof);
                    if (sdoodad.any.type == XkbTextDoodad) {
                        if (sdoodad.text.text)
                            ddoodad.text.text = strdup(sdoodad.text.text);
                        if (sdoodad.text.font)
                            ddoodad.text.font = strdup(sdoodad.text.font);
                    }
                    else if (sdoodad.any.type == XkbLogoDoodad) {
                        if (sdoodad.logo.logo_name)
                            ddoodad.logo.logo_name =
                                strdup(sdoodad.logo.logo_name);
                    }
                }
                dsection.overlays = null;
                dsection.sz_overlays = 0;
                dsection.num_overlays = 0;
            }
        }
        else {
            if (dst.geom.sz_sections) {
                free(dst.geom.sections);
            }

            dst.geom.sections = null;
            dst.geom.num_sections = 0;
            dst.geom.sz_sections = 0;
        }

        /* doodads */
        if (dst.geom.num_doodads) {
            for (i = src.geom.num_doodads,
                 ddoodad = dst.geom.doodads +
                 src.geom.num_doodads;
                 i < dst.geom.num_doodads; i++, ddoodad++) {
                if (ddoodad.any.type == XkbTextDoodad) {
                    free(ddoodad.text.text);
                    ddoodad.text.text = null;
                    free(ddoodad.text.font);
                    ddoodad.text.font = null;
                }
                else if (ddoodad.any.type == XkbLogoDoodad) {
                    free(ddoodad.logo.logo_name);
                    ddoodad.logo.logo_name = null;
                }
            }
            dst.geom.num_doodads = 0;
        }

        if (src.geom.num_doodads) {
            /* Reallocate and clear all items. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.doodads, dst.geom.sz_doodads,
                 src.geom.num_doodads, XkbDoodadRec.sizeof,
                 XKB_GEOM_CLEAR_ALL))
                return False;

            dst.geom.sz_doodads = src.geom.num_doodads;

            for (i = 0,
                 sdoodad = src.geom.doodads,
                 ddoodad = dst.geom.doodads;
                 i < src.geom.num_doodads; i++, sdoodad++, ddoodad++) {
                memcpy(ddoodad, sdoodad, XkbDoodadRec.sizeof);
                if (sdoodad.any.type == XkbTextDoodad) {
                    if (sdoodad.text.text)
                        ddoodad.text.text = strdup(sdoodad.text.text);
                    if (sdoodad.text.font)
                        ddoodad.text.font = strdup(sdoodad.text.font);
                }
                else if (sdoodad.any.type == XkbLogoDoodad) {
                    if (sdoodad.logo.logo_name)
                        ddoodad.logo.logo_name =
                            strdup(sdoodad.logo.logo_name);
                }
            }

            dst.geom.num_doodads = dst.geom.sz_doodads;
        }
        else {
            if (dst.geom.sz_doodads) {
                free(dst.geom.doodads);
            }

            dst.geom.doodads = null;
            dst.geom.num_doodads = 0;
            dst.geom.sz_doodads = 0;
        }

        /* key aliases */
        if (src.geom.num_key_aliases) {
            /* Reallocate but don't clear any items. There is no need
             * to clear anything because data is immediately copied
             * over the whole memory area with memcpy. */
            if (!XkbGeomRealloc
                (cast(void**) &dst.geom.key_aliases, dst.geom.sz_key_aliases,
                 src.geom.num_key_aliases, 2 * XkbKeyNameLength,
                 XKB_GEOM_CLEAR_NONE))
                return False;

            dst.geom.sz_key_aliases = src.geom.num_key_aliases;

            memcpy(dst.geom.key_aliases, src.geom.key_aliases,
                   src.geom.num_key_aliases * 2 * XkbKeyNameLength);

            dst.geom.num_key_aliases = dst.geom.sz_key_aliases;
        }
        else {
            free(dst.geom.key_aliases);
            dst.geom.key_aliases = null;
            dst.geom.num_key_aliases = 0;
            dst.geom.sz_key_aliases = 0;
        }

        /* font */
        if (src.geom.label_font) {
            if (!dst.geom.label_font) {
                tmp = calloc(1, strlen(src.geom.label_font) + 1);
                if (!tmp)
                    return False;
                dst.geom.label_font = cast(char*)tmp;
            }
            else if (strlen(src.geom.label_font) !=
                     strlen(dst.geom.label_font)) {
                tmp = realloc(dst.geom.label_font,
                              strlen(src.geom.label_font) + 1);
                if (!tmp)
                    return False;
                dst.geom.label_font = cast(char*)tmp;
            }

            strcpy(dst.geom.label_font, src.geom.label_font);
            i = mixin(XkbGeomColorIndex!("src.geom", "src.geom.label_color"));
            dst.geom.label_color = &(dst.geom.colors[i]);
            i = mixin(XkbGeomColorIndex!("src.geom", "src.geom.base_color"));
            dst.geom.base_color = &(dst.geom.colors[i]);
        }
        else {
            free(dst.geom.label_font);
            dst.geom.label_font = null;
            dst.geom.label_color = null;
            dst.geom.base_color = null;
        }

        dst.geom.name = src.geom.name;
        dst.geom.width_mm = src.geom.width_mm;
        dst.geom.height_mm = src.geom.height_mm;
    }
    else {
        if (dst.geom) {
            /* I LOVE THE DIFFERENT CALL SIGNATURE.  REALLY, I DO. */
            XkbFreeGeometry(dst.geom, XkbGeomAllMask, True);
            dst.geom = null;
        }
    }

    return True;
}

private Bool _XkbCopyIndicators(XkbDescPtr src, XkbDescPtr dst)
{
    /* indicators */
    if (src.indicators) {
        if (!dst.indicators) {
            dst.indicators = cast(XkbIndicatorRec*) calloc(1, XkbIndicatorRec.sizeof);
            if (!dst.indicators)
                return False;
        }
        memcpy(dst.indicators, src.indicators, XkbIndicatorRec.sizeof);
    }
    else {
        free(dst.indicators);
        dst.indicators = null;
    }
    return True;
}

private Bool _XkbCopyControls(XkbDescPtr src, XkbDescPtr dst)
{
    /* controls */
    if (src.ctrls) {
        if (!dst.ctrls) {
            dst.ctrls = cast(XkbControlsRec*) calloc(1, XkbControlsRec.sizeof);
            if (!dst.ctrls)
                return False;
        }
        memcpy(dst.ctrls, src.ctrls, XkbControlsRec.sizeof);
    }
    else {
        free(dst.ctrls);
        dst.ctrls = null;
    }
    return True;
}

/**
 * Copy an XKB map from src to dst, reallocating when necessary: if some
 * map components are present in one, but not in the other, the destination
 * components will be allocated or freed as necessary.
 *
 * Basic map consistency is assumed on both sides, so maps with random
 * uninitialised data (e.g. names->radio_grous == NULL, names->num_rg == 19)
 * _will_ cause failures.  You've been warned.
 *
 * Returns True on success, or False on failure.  If this function fails,
 * dst may be in an inconsistent state: all its pointers are guaranteed
 * to remain valid, but part of the map may be from src and part from dst.
 *
 */

Bool XkbCopyKeymap(XkbDescPtr dst, XkbDescPtr src)
{

    if (!src || !dst) {
        DebugF("XkbCopyKeymap: src (%p) or dst (%p) is NULL\n", src, dst);
        return False;
    }

    if (src == dst)
        return True;

    if (!_XkbCopyClientMap(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy client map\n");
        return False;
    }
    if (!_XkbCopyServerMap(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy server map\n");
        return False;
    }
    if (!_XkbCopyIndicators(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy indicators\n");
        return False;
    }
    if (!_XkbCopyControls(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy controls\n");
        return False;
    }
    if (!_XkbCopyNames(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy names\n");
        return False;
    }
    if (!_XkbCopyCompat(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy compat map\n");
        return False;
    }
    if (!_XkbCopyGeom(src, dst)) {
        DebugF("XkbCopyKeymap: failed to copy geometry\n");
        return False;
    }

    dst.min_key_code = src.min_key_code;
    dst.max_key_code = src.max_key_code;

    return True;
}

Bool XkbDeviceApplyKeymap(DeviceIntPtr dst, XkbDescPtr desc)
{
    Bool ret = void;

    if (!dst.key || !desc)
        return False;

    xkbNewKeyboardNotify nkn = {
        oldMinKeyCode: dst.key.xkbInfo.desc.min_key_code,
        oldMaxKeyCode: dst.key.xkbInfo.desc.max_key_code,
        deviceID: cast(ubyte)dst.id,
        oldDeviceID: cast(ubyte)dst.id,
        minKeyCode: desc.min_key_code,
        maxKeyCode: desc.max_key_code,
        requestMajor: cast(ubyte)XkbReqCode,
        requestMinor: X_kbSetMap,      /* Near enough's good enough. */
        changed: cast(ushort)XkbNKN_KeycodesMask,
    };

    if (desc.geom)
        nkn.changed |= XkbNKN_GeometryMask;

    ret = XkbCopyKeymap(dst.key.xkbInfo.desc, desc);
    if (ret)
        XkbSendNewKeyboardNotify(dst, &nkn);

    return ret;
}

Bool XkbCopyDeviceKeymap(DeviceIntPtr dst, DeviceIntPtr src)
{
    return XkbDeviceApplyKeymap(dst, src.key.xkbInfo.desc);
}

int XkbGetEffectiveGroup(XkbSrvInfoPtr xkbi, XkbStatePtr xkbState, CARD8 keycode)
{
    XkbDescPtr xkb = xkbi.desc;
    int effectiveGroup = xkbState.group;

    if (!mixin(XkbKeycodeInRange!("xkb", "keycode")))
        return -1;

    if (effectiveGroup == XkbGroup1Index)
        return effectiveGroup;

    if (mixin(XkbKeyNumGroups!("xkb", "keycode")) > 1U) {
        if (effectiveGroup >= mixin(XkbKeyNumGroups!("xkb", "keycode"))) {
            uint gi = mixin(XkbKeyGroupInfo!("xkb", "keycode"));

            switch (mixin(XkbOutOfRangeGroupAction!("gi"))) {
            default:
            case XkbWrapIntoRange:
                effectiveGroup %= mixin(XkbKeyNumGroups!("xkb", "keycode"));
                break;
            case XkbClampIntoRange:
                effectiveGroup = mixin(XkbKeyNumGroups!("xkb", "keycode")) - 1;
                break;
            case XkbRedirectIntoRange:
                effectiveGroup = mixin(XkbOutOfRangeGroupInfo!("gi"));
                if (effectiveGroup >= mixin(XkbKeyNumGroups!("xkb", "keycode")))
                    effectiveGroup = 0;
                break;
            }
        }
    }
    else
        effectiveGroup = XkbGroup1Index;

    return effectiveGroup;
}

/* Merge the lockedPtrButtons from all attached SDs for the given master
 * device into the MD's state.
 */
void XkbMergeLockedPtrBtns(DeviceIntPtr master)
{
    DeviceIntPtr d = inputInfo.devices;
    XkbSrvInfoPtr xkbi = null;

    if (!InputDevIsMaster(master))
        return;

    if (!master.key)
        return;

    xkbi = master.key.xkbInfo;
    xkbi.lockedPtrButtons = 0;

    for (; d; d = d.next) {
        if (InputDevIsMaster(d) || GetMaster(d, MASTER_KEYBOARD) != master || !d.key)
            continue;

        xkbi.lockedPtrButtons |= d.key.xkbInfo.lockedPtrButtons;
    }
}

void XkbCopyControls(XkbDescPtr dst, XkbDescPtr src)
{
    int i = void, nG = void, nTG = void;

    if (!dst || !src)
        return;

    *dst.ctrls = *src.ctrls;

    for (nG = nTG = 0, i = dst.min_key_code; i <= dst.max_key_code; i++) {
        nG = mixin(XkbKeyNumGroups!("dst", "i"));
        if (nG >= XkbNumKbdGroups) {
            nTG = XkbNumKbdGroups;
            break;
        }
        if (nG > nTG) {
            nTG = nG;
        }
    }
    dst.ctrls.num_groups = cast(ubyte)nTG;
}
