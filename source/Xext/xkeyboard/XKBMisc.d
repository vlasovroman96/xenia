module xkb.XKBMisc;
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

import xkb.xkbfmisc_priv;
import xkb.xkbsrv_priv;

import common.misc;
import dix.inputstr;
import xkb.xkbstr;
import externs.X11.extensions.XKB;
import xkb.XKBMAlloc;


/***====================================================================***/

enum string	CORE_SYM(string i) = `(` ~ i ~ `<map_width?core_syms[` ~ i ~ `]:NoSymbol)`;
enum string	XKB_OFFSET(string g,string l) = `(((` ~ g ~ `)*groupsWidth)+(` ~ l ~ `))`;

int XkbKeyTypesForCoreSymbols(XkbDescPtr xkb, int map_width, KeySym* core_syms, uint protected_, int* types_inout, KeySym* xkb_syms_rtrn)
{
    int[XkbNumKbdGroups] nSyms = 0;
    BOOL replicated = FALSE;

    /* Section 12.2 of the protocol describes this process in more detail */
    /* Step 1:  find the # of symbols in the core mapping per group */
    int groupsWidth = 2;
    for (int i = 0; i < XkbNumKbdGroups; i++) {
        if ((protected_ & (1 << i)) && (types_inout[i] < xkb.map.num_types)) {
            nSyms[i] = xkb.map.types[types_inout[i]].num_levels;
            if (nSyms[i] > groupsWidth)
                groupsWidth = nSyms[i];
        }
        else {
            types_inout[i] = XkbTwoLevelIndex;  /* don't really know, yet */
            nSyms[i] = 2;
        }
    }
    if (nSyms[XkbGroup1Index] < 2)
        nSyms[XkbGroup1Index] = 2;
    if (nSyms[XkbGroup2Index] < 2)
        nSyms[XkbGroup2Index] = 2;
    /* Step 2:  Copy the symbols from the core ordering to XKB ordering */
    /*          symbols in the core are in the order:                   */
    /*          G1L1 G1L2 G2L1 G2L2 [G1L[3-n]] [G2L[3-n]] [G3L*] [G3L*] */
    xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup1Index`, `0`))] = mixin(CORE_SYM!(`0`));
    xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup1Index`, `1`))] = mixin(CORE_SYM!(`1`));
    for (int i = 2; i < nSyms[XkbGroup1Index]; i++) {
        xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup1Index`, `i`))] = mixin(CORE_SYM!(`2 + i`));
    }
    xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup2Index`, `0`))] = mixin(CORE_SYM!(`2`));
    xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup2Index`, `1`))] = mixin(CORE_SYM!(`3`));
    int tmp = 2 + (nSyms[XkbGroup1Index] - 2);      /* offset to extra group2 syms */
    for (int i = 2; i < nSyms[XkbGroup2Index]; i++) {
        xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup2Index`, `i`))] = mixin(CORE_SYM!(`tmp + i`));
    }

    /* Special case: if only the first group is explicit, and the symbols
     * replicate across all groups, then we have a Section 12.4 replication */
    if ((protected_ & ~XkbExplicitKeyType1Mask) == 0) {
        int width = nSyms[XkbGroup1Index];
        replicated = TRUE;

        /* Check ABAB in ABABCDECDEABCDE */
        if ((width > 0 && mixin(CORE_SYM!(`0`)) != mixin(CORE_SYM!(`2`))) ||
            (width > 1 && mixin(CORE_SYM!(`1`)) != mixin(CORE_SYM!(`3`))))
            replicated = FALSE;

        /* Check CDECDE in ABABCDECDEABCDE */
        for (int i = 2; i < width && replicated; i++) {
            if (mixin(CORE_SYM!(`2 + i`)) != mixin(CORE_SYM!(`i + width`)))
                replicated = FALSE;
        }

        /* Check ABCDE in ABABCDECDEABCDE */
        for (int j = 2; replicated &&
             j < XkbNumKbdGroups && map_width >= width * (j + 1); j++) {
            for (int i = 0; i < width && replicated; i++) {
                if (mixin(CORE_SYM!(`((i < 2) ? i : 2 + i)`)) != mixin(CORE_SYM!(`i + width * j`)))
                    replicated = FALSE;
            }
        }
    }

    int nGroups = 0;
    if (replicated) {
        nSyms[XkbGroup2Index] = 0;
        nSyms[XkbGroup3Index] = 0;
        nSyms[XkbGroup4Index] = 0;
        nGroups = 1;
    }
    else {
        tmp = nSyms[XkbGroup1Index] + nSyms[XkbGroup2Index];
        if ((tmp >= map_width) &&
            ((protected_ & (XkbExplicitKeyType3Mask | XkbExplicitKeyType4Mask))
             == 0)) {
            nSyms[XkbGroup3Index] = 0;
            nSyms[XkbGroup4Index] = 0;
            nGroups = 2;
        }
        else {
            nGroups = 3;
            for (int i = 0; i < nSyms[XkbGroup3Index]; i++, tmp++) {
                xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup3Index`, `i`))] = mixin(CORE_SYM!(`tmp`));
            }
            if ((tmp < map_width) || (protected_ & XkbExplicitKeyType4Mask)) {
                nGroups = 4;
                for (int i = 0; i < nSyms[XkbGroup4Index]; i++, tmp++) {
                    xkb_syms_rtrn[mixin(XKB_OFFSET!(`XkbGroup4Index`, `i`))] =
                        mixin(CORE_SYM!(`tmp`));
                }
            }
            else {
                nSyms[XkbGroup4Index] = 0;
            }
        }
    }
    /* steps 3&4: alphanumeric expansion,  assign canonical types */
    uint empty = 0;
    for (int i = 0; i < nGroups; i++) {
        KeySym* syms = &xkb_syms_rtrn[mixin(XKB_OFFSET!(`i`, `0`))];

        if ((nSyms[i] > 1) && (syms[1] == NoSymbol) && (syms[0] != NoSymbol)) {
            KeySym upper = void, lower = void;

            XkbConvertCase(syms[0], &lower, &upper);
            if (upper != lower) {
                xkb_syms_rtrn[mixin(XKB_OFFSET!(`i`, `0`))] = lower;
                xkb_syms_rtrn[mixin(XKB_OFFSET!(`i`, `1`))] = upper;
                if ((protected_ & (1 << i)) == 0)
                    types_inout[i] = XkbAlphabeticIndex;
            }
            else if ((protected_ & (1 << i)) == 0) {
                types_inout[i] = XkbOneLevelIndex;
                /*      nSyms[i]=       1; */
            }
        }
        if (((protected_ & (1 << i)) == 0) &&
            (types_inout[i] == XkbTwoLevelIndex)) {
            if (XkbKSIsKeypad(syms[0]) || XkbKSIsKeypad(syms[1]))
                types_inout[i] = XkbKeypadIndex;
            else {
                KeySym upper = void, lower = void;

                XkbConvertCase(syms[0], &lower, &upper);
                if ((syms[0] == lower) && (syms[1] == upper))
                    types_inout[i] = XkbAlphabeticIndex;
            }
        }
        if (syms[0] == NoSymbol) {
            Bool found = FALSE;

            for (int n = 1; (!found) && (n < nSyms[i]); n++) {
                found = (syms[n] != NoSymbol);
            }
            if (!found)
                empty |= (1 << i);
        }
    }
    /* step 5: squoosh out empty groups */
    if (empty) {
        for (int i = nGroups - 1; i >= 0; i--) {
            if (((empty & (1 << i)) == 0) || (protected_ & (1 << i)))
                break;
            nGroups--;
        }
    }
    if (nGroups < 1)
        return 0;

    /* step 6: replicate group 1 into group two, if necessary */
    if ((nGroups > 1) &&
        ((empty & (XkbGroup1Mask | XkbGroup2Mask)) == XkbGroup2Mask)) {
        if ((protected_ & (XkbExplicitKeyType1Mask | XkbExplicitKeyType2Mask)) ==
            0) {
            nSyms[XkbGroup2Index] = nSyms[XkbGroup1Index];
            types_inout[XkbGroup2Index] = types_inout[XkbGroup1Index];
            memcpy(cast(char*) &xkb_syms_rtrn[2], cast(char*) xkb_syms_rtrn,
                   2 * KeySym.sizeof);
        }
        else if (types_inout[XkbGroup1Index] == types_inout[XkbGroup2Index]) {
            memcpy(cast(char*) &xkb_syms_rtrn[nSyms[XkbGroup1Index]],
                   cast(char*) xkb_syms_rtrn,
                   nSyms[XkbGroup1Index] * KeySym.sizeof);
        }
    }

    /* step 7: check for all groups identical or all width 1
     *
     * Special feature: if group 1 has an explicit type and all other groups
     * have canonical types with same symbols, we assume it's info lost from
     * the core replication.
     */
    if (nGroups > 1) {
        Bool sameType = TRUE, canonical = TRUE, allOneLevel = (xkb.map.types[types_inout[0]].num_levels == 1);

        for (int i = 1; (allOneLevel || sameType) && (i < nGroups); i++) {
            sameType = (sameType &&
                        (types_inout[i] == types_inout[XkbGroup1Index]));
            if (allOneLevel)
                allOneLevel = (xkb.map.types[types_inout[i]].num_levels == 1);
            if (types_inout[i] > XkbLastRequiredType)
                canonical = FALSE;
        }
        if (((sameType) || canonical) &&
            (!(protected_ &
               (XkbExplicitKeyTypesMask & ~XkbExplicitKeyType1Mask)))) {
            Bool identical = TRUE;

            for (int i = 1; identical && (i < nGroups); i++) {
                KeySym* syms = void;

                if (nSyms[i] != nSyms[XkbGroup1Index])
                    identical = FALSE;
                syms = &xkb_syms_rtrn[mixin(XKB_OFFSET!(`i`, `0`))];
                for (int s = 0; identical && (s < nSyms[i]); s++) {
                    if (syms[s] != xkb_syms_rtrn[s])
                        identical = FALSE;
                }
            }
            if (identical)
                nGroups = 1;
        }
        if (allOneLevel && (nGroups > 1)) {
            KeySym* syms = &xkb_syms_rtrn[nSyms[XkbGroup1Index]];
            nSyms[XkbGroup1Index] = 1;
            for (int i = 1; i < nGroups; i++) {
                xkb_syms_rtrn[i] = syms[0];
                syms += nSyms[i];
                nSyms[i] = 1;
            }
        }
    }
    return nGroups;
}

private XkbSymInterpretPtr _XkbFindMatchingInterp(XkbDescPtr xkb, KeySym sym, uint real_mods, uint level)
{
    uint i = void;
    XkbSymInterpretPtr interp = void, rtrn = void;
    CARD8 mods = void;

    rtrn = null;
    interp = xkb.compat.sym_interpret;
    for (i = 0; i < xkb.compat.num_si; i++, interp++) {
        if ((interp.sym == NoSymbol) || (sym == interp.sym)) {
            int match = void;

            if ((level == 0) || ((interp.match & XkbSI_LevelOneOnly) == 0))
                mods = cast(ubyte)real_mods;
            else
                mods = 0;
            switch (interp.match & XkbSI_OpMask) {
            case XkbSI_NoneOf:
                match = ((interp.mods & mods) == 0);
                break;
            case XkbSI_AnyOfOrNone:
                match = ((mods == 0) || ((interp.mods & mods) != 0));
                break;
            case XkbSI_AnyOf:
                match = ((interp.mods & mods) != 0);
                break;
            case XkbSI_AllOf:
                match = ((interp.mods & mods) == interp.mods);
                break;
            case XkbSI_Exactly:
                match = (interp.mods == mods);
                break;
            default:
                match = 0;
                break;
            }
            if (match) {
                if (interp.sym != NoSymbol) {
                    return interp;
                }
                else if (rtrn is null) {
                    rtrn = interp;
                }
            }
        }
    }
    return rtrn;
}

private void _XkbAddKeyChange(KeyCode* pFirst, ubyte* pNum, KeyCode newKey)
{
    KeyCode last = void;

    last = cast(ubyte)((*pFirst) + (*pNum));
    if (newKey < *pFirst) {
        *pFirst = newKey;
        *pNum = cast(ubyte)((last - newKey) + 1);
    }
    else if (newKey > last) {
        *pNum = cast(ubyte)((last - *pFirst) + 1);
    }
    return;
}

private void _XkbSetActionKeyMods(XkbDescPtr xkb, XkbAction* act, uint mods)
{
    uint tmp = void;

    switch (act.type) {
    case XkbSA_SetMods:
    case XkbSA_LatchMods:
    case XkbSA_LockMods:
        if (act.mods.flags & XkbSA_UseModMapMods)
            act.mods.real_mods = act.mods.mask = cast(ubyte)mods;
        if ((tmp = mixin(XkbModActionVMods!("&act.mods"))) != 0) {
            XkbVirtualModsToReal(xkb, tmp, &tmp);
            act.mods.mask |= tmp;
        }
        break;
    case XkbSA_ISOLock:
        if (act.iso.flags & XkbSA_UseModMapMods)
            act.iso.real_mods = act.iso.mask = cast(ubyte)mods;
        if ((tmp = mixin(XkbModActionVMods!("&act.iso"))) != 0) {
            XkbVirtualModsToReal(xkb, tmp, &tmp);
            act.iso.mask |= tmp;
        }
        break;
    default: break;}
    return;
}

enum	IBUF_SIZE =	8;

Bool XkbApplyCompatMapToKey(XkbDescPtr xkb, KeyCode key, XkbChangesPtr changes)
{
    if ((!xkb) || (!xkb.map) || (!xkb.map.key_sym_map) ||
        (!xkb.compat) || (!xkb.compat.sym_interpret) ||
        (key < xkb.min_key_code) || (key > xkb.max_key_code)) {
        return FALSE;
    }
    if (((!xkb.server) || (!xkb.server.key_acts)) &&
        (XkbAllocServerMap(xkb, XkbAllServerInfoMask, 0) != Success)) {
        return FALSE;
    }

    uint changed = 0;   /* keeps track of what has changed in _this_ call */
    ubyte explicit = xkb.server.explicit[key];

    if (explicit & XkbExplicitInterpretMask)    /* nothing to do */
        return TRUE;

    ubyte mods = (xkb.map.modmap ? xkb.map.modmap[key] : 0);
    int nSyms = mixin(XkbKeyNumSyms!("xkb", "key"));
    KeySym* syms = mixin(XkbKeySymsPtr!("xkb", "key"));

    XkbSymInterpretPtr* interps = void;
    XkbSymInterpretPtr[IBUF_SIZE] ibuf;
    if (nSyms > IBUF_SIZE) {
        interps = cast(XkbSymInterpretPtr*) calloc(nSyms, XkbSymInterpretPtr.sizeof);
        if (interps is null) {
            interps = ibuf.ptr;
            nSyms = IBUF_SIZE;
        }
    }
    else {
        interps = ibuf.ptr;
    }

    int found = 0;
    for (int n = 0; n < nSyms; n++) {
        uint level = (n % mixin(XkbKeyGroupsWidth!("xkb", "key")));

        interps[n] = null;
        if (syms[n] != NoSymbol) {
            interps[n] = _XkbFindMatchingInterp(xkb, syms[n], mods, level);
            if (interps[n] && interps[n].act.type != XkbSA_NoAction)
                found++;
            else
                interps[n] = null;
        }
    }
    /* 1/28/96 (ef) -- XXX! WORKING HERE */
    if (!found) {
        if (xkb.server.key_acts[key] != 0) {
            xkb.server.key_acts[key] = 0;
            changed |= XkbKeyActionsMask;
        }
    }
    else {
        XkbAction* pActs = XkbResizeKeyActions(xkb, key, nSyms);
        uint new_vmodmask = 0;

        changed |= XkbKeyActionsMask;
        if (!pActs) {
            if (nSyms > IBUF_SIZE)
                free(interps);
            return FALSE;
        }
        for (int n = 0; n < nSyms; n++) {
            if (interps[n]) {
                uint effMods = 0;

                pActs[n] = *(cast(XkbAction*) &interps[n].act);
                if ((n == 0) || ((interps[n].match & XkbSI_LevelOneOnly) == 0)) {
                    effMods = mods;
                    if (interps[n].virtual_mod != XkbNoModifier)
                        new_vmodmask |= (1 << interps[n].virtual_mod);
                }
                _XkbSetActionKeyMods(xkb, &pActs[n], effMods);
            }
            else
                pActs[n].type = XkbSA_NoAction;
        }
        if (((explicit & XkbExplicitVModMapMask) == 0) &&
            (xkb.server.vmodmap[key] != new_vmodmask)) {
            changed |= XkbVirtualModMapMask;
            xkb.server.vmodmap[key] = cast(ushort)new_vmodmask;
        }
        if (interps[0]) {
            if ((interps[0].flags & XkbSI_LockingKey) &&
                ((explicit & XkbExplicitBehaviorMask) == 0)) {
                xkb.server.behaviors[key].type = XkbKB_Lock;
                changed |= XkbKeyBehaviorsMask;
            }
            if (((explicit & XkbExplicitAutoRepeatMask) == 0) && (xkb.ctrls)) {
                CARD8 old = mixin(BitIsOn!("xkb.ctrls.per_key_repeat", "key"));
                if (interps[0].flags & XkbSI_AutoRepeat)
                    mixin(SetBit!("xkb.ctrls.per_key_repeat", "key"));
                else
                    mixin(ClearBit!("xkb.ctrls.per_key_repeat", "key"));
                if (changes && old != mixin(BitIsOn!("xkb.ctrls.per_key_repeat", "key")))
                    changes.ctrls.changed_ctrls |= XkbPerKeyRepeatMask;
            }
        }
    }
    if ((!found) || (interps[0] is null)) {
        if (((explicit & XkbExplicitAutoRepeatMask) == 0) && (xkb.ctrls)) {
            CARD8 old = mixin(BitIsOn!("xkb.ctrls.per_key_repeat", "key"));

            mixin(SetBit!("xkb.ctrls.per_key_repeat", "key"));
            if (changes && (old != mixin(BitIsOn!("xkb.ctrls.per_key_repeat", "key"))))
                changes.ctrls.changed_ctrls |= XkbPerKeyRepeatMask;
        }
        if (((explicit & XkbExplicitBehaviorMask) == 0) &&
            (xkb.server.behaviors[key].type == XkbKB_Lock)) {
            xkb.server.behaviors[key].type = XkbKB_Default;
            changed |= XkbKeyBehaviorsMask;
        }
    }
    if (changes) {
        XkbMapChangesPtr mc = &changes.map;
        uint tmp = (changed & mc.changed);

        if (tmp & XkbKeyActionsMask)
            _XkbAddKeyChange(&mc.first_key_act, &mc.num_key_acts, key);
        else if (changed & XkbKeyActionsMask) {
            mc.changed |= XkbKeyActionsMask;
            mc.first_key_act = key;
            mc.num_key_acts = 1;
        }
        if (tmp & XkbKeyBehaviorsMask) {
            _XkbAddKeyChange(&mc.first_key_behavior, &mc.num_key_behaviors,
                             key);
        }
        else if (changed & XkbKeyBehaviorsMask) {
            mc.changed |= XkbKeyBehaviorsMask;
            mc.first_key_behavior = key;
            mc.num_key_behaviors = 1;
        }
        if (tmp & XkbVirtualModMapMask)
            _XkbAddKeyChange(&mc.first_vmodmap_key, &mc.num_vmodmap_keys,
                             key);
        else if (changed & XkbVirtualModMapMask) {
            mc.changed |= XkbVirtualModMapMask;
            mc.first_vmodmap_key = key;
            mc.num_vmodmap_keys = 1;
        }
        mc.changed |= changed;
    }
    if (interps != ibuf.ptr)
        free(interps);
    return TRUE;
}

Status XkbChangeTypesOfKey(XkbDescPtr xkb, int key, int nGroups, uint groups, int* newTypesIn, XkbMapChangesPtr changes)
{
    XkbKeyTypePtr pOldType = void, pNewType = void;
    int i = void;
    int width = void, nOldGroups = void, oldWidth = void;

    if ((!xkb) || (!mixin(XkbKeycodeInRange!("xkb", "key"))) || (!xkb.map) ||
        (!xkb.map.types) || (!newTypesIn) ||
        ((groups & XkbAllGroupsMask) == 0) || (nGroups > XkbNumKbdGroups)) {
        return BadMatch;
    }
    if (nGroups == 0) {
        for (i = 0; i < XkbNumKbdGroups; i++) {
            xkb.map.key_sym_map[key].kt_index[i] = XkbOneLevelIndex;
        }
        i = xkb.map.key_sym_map[key].group_info;
        i = mixin(XkbSetNumGroups!("i", "0"));
        xkb.map.key_sym_map[key].group_info = cast(ubyte)i;
        XkbResizeKeySyms(xkb, key, 0);
        XkbResizeKeyActions(xkb, key, 0);
        return Success;
    }

    nOldGroups = mixin(XkbKeyNumGroups!("xkb", "key"));
    oldWidth = mixin(XkbKeyGroupsWidth!("xkb", "key"));

    int[XkbNumKbdGroups] newTypes = 0;
    for (width = i = 0; i < nGroups; i++) {
        if (groups & (1 << i))
            newTypes[i] = newTypesIn[i];
        else if (i < nOldGroups)
            newTypes[i] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "i"));
        else if (nOldGroups > 0)
            newTypes[i] = mixin(XkbKeyKeyTypeIndex!("xkb", "key", "XkbGroup1Index"));
        else
            newTypes[i] = XkbTwoLevelIndex;
        if (newTypes[i] > xkb.map.num_types)
            return BadMatch;
        pNewType = &xkb.map.types[newTypes[i]];
        if (pNewType.num_levels > width)
            width = pNewType.num_levels;
    }
    if ((xkb.ctrls) && (nGroups > xkb.ctrls.num_groups))
        xkb.ctrls.num_groups = cast(ubyte)(cast(ubyte)nGroups);
    if ((width != oldWidth) || (nGroups != nOldGroups)) {
        KeySym[XkbMaxSymsPerKey] oldSyms = void; KeySym* pSyms = void;
        int nCopy = void;

        if (nOldGroups == 0) {
            pSyms = XkbResizeKeySyms(xkb, key, width * nGroups);
            if (pSyms !is null) {
                i = xkb.map.key_sym_map[key].group_info;
                i = mixin(XkbSetNumGroups!("i", "nGroups"));
                xkb.map.key_sym_map[key].group_info = cast(ubyte)i;
                xkb.map.key_sym_map[key].width = cast(ubyte)width;
                for (i = 0; i < nGroups; i++) {
                    xkb.map.key_sym_map[key].kt_index[i] = cast(ubyte)newTypes[i];
                }
                return Success;
            }
            return BadAlloc;
        }
        pSyms = mixin(XkbKeySymsPtr!("xkb", "key"));
        memcpy(oldSyms.ptr, pSyms, mixin(XkbKeyNumSyms!("xkb", "key")) * KeySym.sizeof);
        pSyms = XkbResizeKeySyms(xkb, key, width * nGroups);
        if (pSyms is null)
            return BadAlloc;
        memset(pSyms, 0, width * nGroups * KeySym.sizeof);
        for (i = 0; (i < nGroups) && (i < nOldGroups); i++) {
            pOldType = mixin(XkbKeyKeyType!("xkb", "key", "i"));
            pNewType = &xkb.map.types[newTypes[i]];
            if (pNewType.num_levels > pOldType.num_levels)
                nCopy = pOldType.num_levels;
            else
                nCopy = pNewType.num_levels;
            memcpy(&pSyms[i * width], &oldSyms[i * oldWidth],
                   nCopy * KeySym.sizeof);
        }
        if (mixin(XkbKeyHasActions!("xkb", "key"))) {
            XkbAction[XkbMaxSymsPerKey] oldActs = void; XkbAction* pActs = void;

            pActs = mixin(XkbKeyActionsPtr!("xkb", "key"));
            memcpy(oldActs.ptr, pActs, mixin(XkbKeyNumSyms!("xkb", "key")) * XkbAction.sizeof);
            pActs = XkbResizeKeyActions(xkb, key, width * nGroups);
            if (pActs is null)
                return BadAlloc;
            memset(pActs, 0, width * nGroups * XkbAction.sizeof);
            for (i = 0; (i < nGroups) && (i < nOldGroups); i++) {
                pOldType = mixin(XkbKeyKeyType!("xkb", "key", "i"));
                pNewType = &xkb.map.types[newTypes[i]];
                if (pNewType.num_levels > pOldType.num_levels)
                    nCopy = pOldType.num_levels;
                else
                    nCopy = pNewType.num_levels;
                memcpy(&pActs[i * width], &oldActs[i * oldWidth],
                       nCopy * XkbAction.sizeof);
            }
        }
        i = xkb.map.key_sym_map[key].group_info;
        i = mixin(XkbSetNumGroups!("i", "nGroups"));
        xkb.map.key_sym_map[key].group_info = cast(ubyte)i;
        xkb.map.key_sym_map[key].width = cast(ubyte)width;
    }
    width = 0;
    for (i = 0; i < nGroups; i++) {
        xkb.map.key_sym_map[key].kt_index[i] = cast(ubyte)newTypes[i];
        if (xkb.map.types[newTypes[i]].num_levels > width)
            width = xkb.map.types[newTypes[i]].num_levels;
    }
    xkb.map.key_sym_map[key].width = cast(ubyte)width;
    if (changes !is null) {
        if (changes.changed & XkbKeySymsMask) {
            _XkbAddKeyChange(&changes.first_key_sym, &changes.num_key_syms,
                             cast(ubyte)key);
        }
        else {
            changes.changed |= XkbKeySymsMask;
            changes.first_key_sym = cast(ubyte)key;
            changes.num_key_syms = 1;
        }
    }
    return Success;
}

/***====================================================================***/

Bool XkbVirtualModsToReal(XkbDescPtr xkb, uint virtual_mask, uint* mask_rtrn)
{
    if ((xkb is null) || (xkb.server is null)) {
        *mask_rtrn = 0;
        return FALSE;
    }
    if (virtual_mask == 0) {
        *mask_rtrn = 0;
        return TRUE;
    }

    int bit = 1;
    uint mask = 0;
    for (int i = 0; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (virtual_mask & bit)
            mask |= xkb.server.vmods[i];
    }
    *mask_rtrn = mask;
    return TRUE;
}

/***====================================================================***/

private Bool XkbUpdateActionVirtualMods(XkbDescPtr xkb, XkbAction* act, uint changed)
{
    uint tmp = void;

    switch (act.type) {
    case XkbSA_SetMods:
    case XkbSA_LatchMods:
    case XkbSA_LockMods:
        if (((tmp = mixin(XkbModActionVMods!("&act.mods"))) & changed) != 0) {
            XkbVirtualModsToReal(xkb, tmp, &tmp);
            act.mods.mask = act.mods.real_mods;
            act.mods.mask |= tmp;
            return TRUE;
        }
        break;
    case XkbSA_ISOLock:
        if ((((tmp = mixin(XkbModActionVMods!("&act.iso"))) != 0) & changed) != 0) {
            XkbVirtualModsToReal(xkb, tmp, &tmp);
            act.iso.mask = act.iso.real_mods;
            act.iso.mask |= tmp;
            return TRUE;
        }
        break;
    default: break;}
    return FALSE;
}

private void XkbUpdateKeyTypeVirtualMods(XkbDescPtr xkb, XkbKeyTypePtr type, uint changed, XkbChangesPtr changes)
{
    uint mask = void;

    XkbVirtualModsToReal(xkb, type.mods.vmods, &mask);
    type.mods.mask = cast(ubyte)(type.mods.real_mods | mask);
    if ((type.map_count > 0) && (type.mods.vmods != 0)) {
        XkbKTMapEntryPtr entry = type.map;

        for (uint i = 0; i < type.map_count; i++, entry++) {
            if (entry.mods.vmods != 0) {
                XkbVirtualModsToReal(xkb, entry.mods.vmods, &mask);
                entry.mods.mask = cast(ubyte)(entry.mods.real_mods | mask);
                /* entry is active if vmods are bound */
                entry.active = (mask != 0);
            }
            else
                entry.active = 1;
        }
    }
    if (changes) {
        int type_ndx = cast(int)(type - xkb.map.types);

        if ((type_ndx < 0) || (type_ndx > xkb.map.num_types))
            return;
        if (changes.map.changed & XkbKeyTypesMask) {
            int last = changes.map.first_type + changes.map.num_types - 1;
            if (type_ndx < changes.map.first_type) {
                changes.map.first_type = cast(ubyte)type_ndx;
                changes.map.num_types = cast(ubyte)(cast(ubyte)((last - type_ndx) + 1));
            }
            else if (type_ndx > last) {
                changes.map.num_types =
                    cast(ubyte)((type_ndx - changes.map.first_type) + 1);
            }
        }
        else {
            changes.map.changed |= XkbKeyTypesMask;
            changes.map.first_type = cast(ubyte)type_ndx;
            changes.map.num_types = cast(ubyte)(1);
        }
    }
    return;
}

Bool XkbApplyVirtualModChanges(XkbDescPtr xkb, uint changed, XkbChangesPtr changes)
{
    uint checkState = 0;

    if ((!xkb) || (!xkb.map) || (changed == 0))
        return FALSE;
    for (int i = 0; i < xkb.map.num_types; i++) {
        if (xkb.map.types[i].mods.vmods & changed)
            XkbUpdateKeyTypeVirtualMods(xkb, &xkb.map.types[i], changed,
                                        changes);
    }
    if (changed & xkb.ctrls.internal.vmods) {
        uint newMask = void;

        XkbVirtualModsToReal(xkb, xkb.ctrls.internal.vmods, &newMask);
        newMask |= xkb.ctrls.internal.real_mods;
        if (xkb.ctrls.internal.mask != newMask) {
            xkb.ctrls.internal.mask = cast(ubyte)newMask;
            if (changes) {
                changes.ctrls.changed_ctrls |= XkbInternalModsMask;
                checkState = TRUE;
            }
        }
    }
    if (changed & xkb.ctrls.ignore_lock.vmods) {
        uint newMask = void;

        XkbVirtualModsToReal(xkb, xkb.ctrls.ignore_lock.vmods, &newMask);
        newMask |= xkb.ctrls.ignore_lock.real_mods;
        if (xkb.ctrls.ignore_lock.mask != newMask) {
            xkb.ctrls.ignore_lock.mask = cast(ubyte)newMask;
            if (changes) {
                changes.ctrls.changed_ctrls |= XkbIgnoreLockModsMask;
                checkState = TRUE;
            }
        }
    }
    if (xkb.indicators !is null) {
        XkbIndicatorMapPtr map = &xkb.indicators.maps[0];

        for (int i = 0; i < XkbNumIndicators; i++, map++) {
            if (map.mods.vmods & changed) {
                uint newMask = void;

                XkbVirtualModsToReal(xkb, map.mods.vmods, &newMask);
                newMask |= map.mods.real_mods;
                if (newMask != map.mods.mask) {
                    map.mods.mask = cast(ubyte)newMask;
                    if (changes) {
                        changes.indicators.map_changes |= (1 << i);
                        checkState = TRUE;
                    }
                }
            }
        }
    }
    if (xkb.compat !is null) {
        XkbCompatMapPtr compat = xkb.compat;

        for (int i = 0; i < XkbNumKbdGroups; i++) {
            uint newMask = void; 

            XkbVirtualModsToReal(xkb, compat.groups[i].vmods, &newMask);
            newMask |= compat.groups[i].real_mods;
            if (compat.groups[i].mask != newMask) {
                compat.groups[i].mask = cast(ubyte)newMask;
                if (changes) {
                    changes.compat.changed_groups |= (1 << i);
                    checkState = TRUE;
                }
            }
        }
    }
    if (xkb.map && xkb.server) {
        int highChange = 0, lowChange = -1;

        for (int i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
            if (mixin(XkbKeyHasActions!("xkb", "i"))) {
                XkbAction* pAct = mixin(XkbKeyActionsPtr!("xkb", "i"));
                for (int n = mixin(XkbKeyNumActions!("xkb", "i")); n > 0; n--, pAct++) {
                    if ((pAct.type != XkbSA_NoAction) &&
                        XkbUpdateActionVirtualMods(xkb, pAct, changed)) {
                        if (lowChange < 0)
                            lowChange = i;
                        highChange = i;
                    }
                }
            }
        }
        if (changes && (lowChange > 0)) {       /* something changed */
            if (changes.map.changed & XkbKeyActionsMask) {
                if (changes.map.first_key_act < lowChange)
                    lowChange = changes.map.first_key_act;
                int last = changes.map.first_key_act + changes.map.num_key_acts - 1;
                if (last > highChange)
                    highChange = last;
            }
            changes.map.changed |= XkbKeyActionsMask;
            changes.map.first_key_act = cast(ubyte)(cast(ubyte)lowChange);
            changes.map.num_key_acts = cast(ubyte)(cast(ubyte)((highChange - lowChange) + 1));
        }
    }
    return checkState;
}
