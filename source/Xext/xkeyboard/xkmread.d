module xkb.xkmread;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
 Copyright (c) 1994 by Silicon Graphics Computer Systems, Inc.

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
// //import x11.Xos;
// //import x11.Xfuncs;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
// //import externs.X11.extensions.XKMformat;
// import externs.X11.extensions.XKBgeom;

import os.log_priv;
import xkb.xkbfile_priv;
import xkb.xkbfmisc_priv;
import xkb.xkbsrv_priv;

import common.misc;
import dix.inputstr;
import include.xkbsrv;
import xkb.xkbgeom_priv;
import externs.X11.extensions.XKMformat;
import externs.X11.extensions.XKB;
// import externs.X11.extensions.XKBstr;
import include.xkbstr;
import xkb.XKBMAlloc;
import os.log;
alias XkbNumRequiredTypes = xkb.XKBMAlloc.XkbNumRequiredTypes;
import xkb.XKBGAlloc;
import dix.atom;


private Atom XkbInternAtom(char* str, Bool only_if_exists)
{
    if (str is null)
        return None;
    return MakeAtom(str, cast(uint)strlen(str), !only_if_exists);
}

/***====================================================================***/

private void* XkmInsureSize(void* oldPtr, int oldCount, int* newCountRtrn, int elemSize)
{
    int newCount = *newCountRtrn;

    if (oldPtr is null) {
        if (newCount == 0)
            return null;
        oldPtr = calloc(newCount, elemSize);
    }
    else if (oldCount < newCount) {
        oldPtr = reallocarray(oldPtr, newCount, elemSize);
        if (oldPtr !is null) {
            char* tmp = cast(char*) oldPtr;

            memset(&tmp[oldCount * elemSize], 0,
                   (newCount - oldCount) * elemSize);
        }
    }
    else if (newCount < oldCount) {
        *newCountRtrn = oldCount;
    }
    return oldPtr;
}

enum string	XkmInsureTypedSize(string p,string o,string n,string t) = `((` ~ p ~ `)=(cast(`~t~`*)XkmInsureSize(cast(char*)(` ~ p ~ `),(` ~ o ~ `),(` ~ n ~ `),` ~ t ~ `.sizeof)))`;

private CARD8 XkmGetCARD8(FILE* file, int* pNRead)
{
    int tmp = void;

    tmp = getc(file);
    if (pNRead && (tmp != EOF))
        (*pNRead) += 1;
    return cast(ubyte)tmp;
}

private CARD16 XkmGetCARD16(FILE* file, int* pNRead)
{
    CARD16 val = void;

    if ((fread(&val, 2, 1, file) == 1) && (pNRead))
        (*pNRead) += 2;
    return val;
}

private CARD32 XkmGetCARD32(FILE* file, int* pNRead)
{
    CARD32 val = void;

    if ((fread(&val, 4, 1, file) == 1) && (pNRead))
        (*pNRead) += 4;
    return val;
}

private int XkmSkipPadding(FILE* file, uint pad)
{
    int i = void, nRead = 0;

    for (i = 0; i < pad; i++) {
        if (getc(file) != EOF)
            nRead++;
    }
    return nRead;
}

private int XkmGetCountedString(FILE* file, char* str, int max_len)
{
    int count = void, nRead = 0;

    count = XkmGetCARD16(file, &nRead);
    if (count > 0) {
        int tmp = void;

        if (count > max_len) {
            tmp = cast(int)fread(str, 1, max_len, file);
            while (tmp < count) {
                if ((getc(file)) != EOF)
                    tmp++;
                else
                    break;
            }
        }
        else {
            tmp = cast(int)fread(str, 1, count, file);
        }
        nRead += tmp;
    }
    if (count >= max_len)
        str[max_len - 1] = '\0';
    else
        str[count] = '\0';
    count = mixin(XkbPaddedSize!("nRead")) - nRead;
    if (count > 0)
        nRead += XkmSkipPadding(file, count);
    return nRead;
}

/***====================================================================***/

private int ReadXkmVirtualMods(FILE* file, XkbDescPtr xkb, XkbChangesPtr changes)
{
    uint i = void, bit = void;
    uint bound = void, named = void, tmp = void;
    int nRead = 0;

    if (XkbAllocServerMap(xkb, XkbVirtualModsMask, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmVirtualMods", 0);
        return -1;
    }
    bound = XkmGetCARD16(file, &nRead);
    named = XkmGetCARD16(file, &nRead);
    for (i = tmp = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (bound & bit) {
            xkb.server.vmods[i] = XkmGetCARD8(file, &nRead);
            if (changes)
                changes.map.vmods |= bit;
            tmp++;
        }
    }
    if ((i = mixin(XkbPaddedSize!("tmp")) - tmp) > 0)
        nRead += XkmSkipPadding(file, i);
    if (XkbAllocNames(xkb, XkbVirtualModNamesMask, 0, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmVirtualMods", 0);
        return -1;
    }
    for (i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        char[100] name = void;

        if (named & bit) {
            if ((nRead += XkmGetCountedString(file, name.ptr, 100)) != 0) {
                xkb.names.vmods[i] = XkbInternAtom(name.ptr, FALSE);
                if (changes)
                    changes.names.changed_vmods |= bit;
            }
        }
    }
    return nRead;
}

/***====================================================================***/

private int ReadXkmKeycodes(FILE* file, XkbDescPtr xkb, XkbChangesPtr changes)
{
    int i = void;
    uint minKC = void, maxKC = void, nAl = void;
    int nRead = 0;
    char[100] name = 0;
    XkbKeyNamePtr pN = void;

    name[0] = '\0';
    nRead += XkmGetCountedString(file, name.ptr, 100);
    minKC = XkmGetCARD8(file, &nRead);
    maxKC = XkmGetCARD8(file, &nRead);
    if (xkb.min_key_code == 0) {
        xkb.min_key_code = cast(ubyte)minKC;
        xkb.max_key_code = cast(ubyte)maxKC;
    }
    else {
        if (minKC < xkb.min_key_code)
            xkb.min_key_code = cast(ubyte)minKC;
        if (maxKC > xkb.max_key_code) {
            //_XkbLibError(_XkbErrBadValue, "ReadXkmKeycodes", maxKC);
            return -1;
        }
    }
    nAl = XkmGetCARD8(file, &nRead);
    nRead += XkmSkipPadding(file, 1);

enum WANTED = (XkbKeycodesNameMask|XkbKeyNamesMask|XkbKeyAliasesMask);
    if (XkbAllocNames(xkb, WANTED, 0, nAl) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmKeycodes", 0);
        return -1;
    }
    if (name[0] != '\0') {
        xkb.names.keycodes = XkbInternAtom(name.ptr, FALSE);
    }

    for (pN = &xkb.names.keys[minKC], i = minKC; i <= cast(int) maxKC; i++, pN++) {
        if (fread(pN, 1, XkbKeyNameLength, file) != XkbKeyNameLength) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmKeycodes", 0);
            return -1;
        }
        nRead += XkbKeyNameLength;
    }
    if (nAl > 0) {
        XkbKeyAliasPtr pAl = void;

        for (pAl = xkb.names.key_aliases, i = 0; i < nAl; i++, pAl++) {
            int tmp = void;

            tmp = cast(int)fread(pAl, 1, 2 * XkbKeyNameLength, file);
            if (tmp != 2 * XkbKeyNameLength) {
                //_XkbLibError(_XkbErrBadLength, "ReadXkmKeycodes", 0);
                return -1;
            }
            nRead += 2 * XkbKeyNameLength;
        }
        if (changes)
            changes.names.changed |= XkbKeyAliasesMask;
    }
    if (changes)
        changes.names.changed |= XkbKeyNamesMask;
    return nRead;
}

/***====================================================================***/

private int ReadXkmKeyTypes(FILE* file, XkbDescPtr xkb, XkbChangesPtr changes)
{
    uint i = void, n = void;
    uint num_types = void;
    int nRead = 0;
    int tmp = void;
    XkbKeyTypePtr type = void;
    xkmKeyTypeDesc wire = { 0 };
    XkbKTMapEntryPtr entry = void;
    xkmKTMapEntryDesc wire_entry = { 0 };
    char[100] buf = 0;

    if ((tmp = XkmGetCountedString(file, buf.ptr, 100)) < 1) {
        //_XkbLibError(_XkbErrBadLength, "ReadXkmKeyTypes", 0);
        return -1;
    }
    nRead += tmp;
    if (buf[0] != '\0') {
        if (XkbAllocNames(xkb, XkbTypesNameMask, 0, 0) != Success) {
            //_XkbLibError(_XkbErrBadAlloc, "ReadXkmKeyTypes", 0);
            return -1;
        }
        xkb.names.types = XkbInternAtom(buf.ptr, FALSE);
    }
    num_types = XkmGetCARD16(file, &nRead);
    nRead += XkmSkipPadding(file, 2);
    if (num_types < 1)
        return nRead;
    if (XkbAllocClientMap(xkb, XkbKeyTypesMask, num_types) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmKeyTypes", 0);
        return nRead;
    }
    xkb.map.num_types = cast(ubyte)(num_types);
    if (num_types < XkbNumRequiredTypes) {
        //_XkbLibError(_XkbErrMissingReqTypes, "ReadXkmKeyTypes", 0);
        return -1;
    }
    type = xkb.map.types;
    for (i = 0; i < num_types; i++, type++) {
        if (cast(int) fread(&wire, xkmKeyTypeDesc.sizeof, 1, file) < 1) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmKeyTypes", 0);
            return -1;
        }
        nRead += xkmKeyTypeDesc.sizeof;
        if (((i == XkbOneLevelIndex) && (wire.numLevels != 1)) ||
            (((i == XkbTwoLevelIndex) || (i == XkbAlphabeticIndex) ||
              ((i) == XkbKeypadIndex)) && (wire.numLevels != 2))) {
            //_XkbLibError(_XkbErrBadTypeWidth, "ReadXkmKeyTypes", i);
            return -1;
        }
        tmp = wire.nMapEntries;
        mixin(XkmInsureTypedSize!(`type.map`, `type.map_count`, `&tmp`, `XkbKTMapEntryRec`)~";");
        if ((wire.nMapEntries > 0) && (type.map is null)) {
            //_XkbLibError(_XkbErrBadValue, "ReadXkmKeyTypes", wire.nMapEntries);
            return -1;
        }
        for (n = 0, entry = type.map; n < wire.nMapEntries; n++, entry++) {
            if (fread(&wire_entry, xkmKTMapEntryDesc.sizeof, 1, file) <
                cast(int) 1) {
                //_XkbLibError(_XkbErrBadLength, "ReadXkmKeyTypes", 0);
                return -1;
            }
            nRead += xkmKTMapEntryDesc.sizeof;
            entry.active = (wire_entry.virtualMods == 0);
            entry.level = wire_entry.level;
            entry.mods.mask = wire_entry.realMods;
            entry.mods.real_mods = wire_entry.realMods;
            entry.mods.vmods = wire_entry.virtualMods;
        }
        nRead += XkmGetCountedString(file, buf.ptr, 100);
        if (((i == XkbOneLevelIndex) && (strcmp(buf.ptr, "ONE_LEVEL") != 0)) ||
            ((i == XkbTwoLevelIndex) && (strcmp(buf.ptr, "TWO_LEVEL") != 0)) ||
            ((i == XkbAlphabeticIndex) && (strcmp(buf.ptr, "ALPHABETIC") != 0)) ||
            ((i == XkbKeypadIndex) && (strcmp(buf.ptr, "KEYPAD") != 0))) {
            //_XkbLibError(_XkbErrBadTypeName, "ReadXkmKeyTypes", 0);
            return -1;
        }
        if (buf[0] != '\0') {
            type.name = XkbInternAtom(buf.ptr, FALSE);
        }
        else
            type.name = None;

        if (wire.preserve) {
            xkmModsDesc p_entry = void;
            XkbModsPtr pre = void;

            mixin(XkmInsureTypedSize!(`type.preserve`, `type.map_count`, `&tmp`,
                               `XkbModsRec`)~";");
            if (type.preserve is null) {
                //_XkbLibError(_XkbErrBadMatch, "ReadXkmKeycodes", 0);
                return -1;
            }
            for (n = 0, pre = type.preserve; n < wire.nMapEntries; n++, pre++) {
                if (fread(&p_entry, xkmModsDesc.sizeof, 1, file) < 1) {
                    //_XkbLibError(_XkbErrBadLength, "ReadXkmKeycodes", 0);
                    return -1;
                }
                nRead += xkmModsDesc.sizeof;
                pre.mask = p_entry.realMods;
                pre.real_mods = p_entry.realMods;
                pre.vmods = p_entry.virtualMods;
            }
        }
        if (wire.nLevelNames > 0) {
            int width = wire.numLevels;

            if (wire.nLevelNames > cast(uint) width) {
                //_XkbLibError(_XkbErrBadMatch, "ReadXkmKeycodes", 0);
                return -1;
            }
            mixin(XkmInsureTypedSize!(`type.level_names`, `type.num_levels`, `&width`,
                               `Atom`)~";");
            if (type.level_names !is null) {
                for (n = 0; n < wire.nLevelNames; n++) {
                    if ((tmp = XkmGetCountedString(file, buf.ptr, 100)) < 1)
                        return -1;
                    nRead += tmp;
                    if (strlen(buf.ptr) == 0)
                        type.level_names[n] = None;
                    else
                        type.level_names[n] = XkbInternAtom(buf.ptr, 0);
                }
            }
        }
        type.mods.mask = wire.realMods;
        type.mods.real_mods = wire.realMods;
        type.mods.vmods = wire.virtualMods;
        type.num_levels = cast(ubyte*)wire.numLevels;
        type.map_count = cast(ubyte)cast(ubyte*)wire.nMapEntries;
    }
    if (changes) {
        changes.map.changed |= XkbKeyTypesMask;
        changes.map.first_type = cast(ubyte)(0);
        changes.map.num_types = cast(ubyte)(xkb.map.num_types);
    }
    return nRead;
}

/***====================================================================***/

private int ReadXkmCompatMap(FILE* file, XkbDescPtr xkb, XkbChangesPtr changes)
{
    int i = void;
    uint num_si = void, groups = void;
    char[100] name = 0;
    XkbSymInterpretPtr interp = void;
    xkmSymInterpretDesc wire = { 0 };
    uint tmp = void;
    int nRead = 0;
    XkbCompatMapPtr compat = void;
    XkbAction* act = void;

    if ((tmp = XkmGetCountedString(file, name.ptr, 100)) < 1) {
        //_XkbLibError(_XkbErrBadLength, "ReadXkmCompatMap", 0);
        return -1;
    }
    nRead += tmp;
    if (name[0] != '\0') {
        if (XkbAllocNames(xkb, XkbCompatNameMask, 0, 0) != Success) {
            //_XkbLibError(_XkbErrBadAlloc, "ReadXkmCompatMap", 0);
            return -1;
        }
        xkb.names.compat = XkbInternAtom(name.ptr, FALSE);
    }
    num_si = XkmGetCARD16(file, &nRead);
    groups = XkmGetCARD8(file, &nRead);
    nRead += XkmSkipPadding(file, 1);
    if (XkbAllocCompatMap(xkb, XkbAllCompatMask, num_si) != Success)
        return -1;
    compat = xkb.compat;
    compat.num_si = 0;
    interp = compat.sym_interpret;
    for (i = 0; i < num_si; i++) {
        tmp = cast(int)fread(&wire, xkmSymInterpretDesc.sizeof, 1, file);
        nRead += tmp * xkmSymInterpretDesc.sizeof;
        interp.sym = wire.sym;
        interp.mods = wire.mods;
        interp.match = wire.match;
        interp.virtual_mod = wire.virtualMod;
        interp.flags = wire.flags;
        interp.act.type = wire.actionType;
        act = cast(XkbAction*) &interp.act;

        switch (interp.act.type) {
        case XkbSA_SetMods:
        case XkbSA_LatchMods:
        case XkbSA_LockMods:
            act.mods.flags = wire.actionData[0];
            act.mods.mask = wire.actionData[1];
            act.mods.real_mods = wire.actionData[2];
            act.mods.vmods1 = wire.actionData[3];
            act.mods.vmods2 = wire.actionData[4];
            break;
        case XkbSA_SetGroup:
        case XkbSA_LatchGroup:
        case XkbSA_LockGroup:
            act.group.flags = wire.actionData[0];
            act.group.group_XXX = wire.actionData[1];
            break;
        case XkbSA_MovePtr:
            act.ptr.flags = wire.actionData[0];
            act.ptr.high_XXX = wire.actionData[1];
            act.ptr.low_XXX = wire.actionData[2];
            act.ptr.high_YYY = wire.actionData[3];
            act.ptr.low_YYY = wire.actionData[4];
            break;
        case XkbSA_PtrBtn:
        case XkbSA_LockPtrBtn:
            act.btn.flags = wire.actionData[0];
            act.btn.count = wire.actionData[1];
            act.btn.button = wire.actionData[2];
            break;
        case XkbSA_DeviceBtn:
        case XkbSA_LockDeviceBtn:
            act.devbtn.flags = wire.actionData[0];
            act.devbtn.count = wire.actionData[1];
            act.devbtn.button = wire.actionData[2];
            act.devbtn.device = wire.actionData[3];
            break;
        case XkbSA_SetPtrDflt:
            act.dflt.flags = wire.actionData[0];
            act.dflt.affect = wire.actionData[1];
            act.dflt.valueXXX = wire.actionData[2];
            break;
        case XkbSA_ISOLock:
            act.iso.flags = wire.actionData[0];
            act.iso.mask = wire.actionData[1];
            act.iso.real_mods = wire.actionData[2];
            act.iso.group_XXX = wire.actionData[3];
            act.iso.affect = wire.actionData[4];
            act.iso.vmods1 = wire.actionData[5];
            act.iso.vmods2 = wire.actionData[6];
            break;
        case XkbSA_SwitchScreen:
            act.screen.flags = wire.actionData[0];
            act.screen.screenXXX = wire.actionData[1];
            break;
        case XkbSA_SetControls:
        case XkbSA_LockControls:
            act.ctrls.flags = wire.actionData[0];
            act.ctrls.ctrls3 = wire.actionData[1];
            act.ctrls.ctrls2 = wire.actionData[2];
            act.ctrls.ctrls1 = wire.actionData[3];
            act.ctrls.ctrls0 = wire.actionData[4];
            break;
        case XkbSA_RedirectKey:
            act.redirect.new_key = wire.actionData[0];
            act.redirect.mods_mask = wire.actionData[1];
            act.redirect.mods = wire.actionData[2];
            act.redirect.vmods_mask0 = wire.actionData[3];
            act.redirect.vmods_mask1 = wire.actionData[4];
            act.redirect.vmods0 = wire.actionData[4];
            act.redirect.vmods1 = wire.actionData[5];
            break;
        case XkbSA_DeviceValuator:
            act.devval.device = wire.actionData[0];
            act.devval.v1_what = wire.actionData[1];
            act.devval.v1_ndx = wire.actionData[2];
            act.devval.v1_value = wire.actionData[3];
            act.devval.v2_what = wire.actionData[4];
            act.devval.v2_ndx = wire.actionData[5];
            act.devval.v2_value = wire.actionData[6];
            break;

        case XkbSA_XFree86Private:
            /*
             * Bugfix for broken xkbcomp: if we encounter an XFree86Private
             * action with Any+AnyOfOrNone(All), then we skip the interp as
             * broken.  Versions of xkbcomp below 1.2.2 had a bug where they
             * would interpret a symbol that couldn't be found in an interpret
             * as Any.  So, an XF86LogWindowTree+AnyOfOrNone(All) interp that
             * triggered the PrWins action would make every key without an
             * action trigger PrWins if libX11 didn't yet know about the
             * XF86LogWindowTree keysym.  None too useful.
             *
             * We only do this for XFree86 actions, as the current XKB
             * dataset relies on Any+AnyOfOrNone(All) -> SetMods for Ctrl in
             * particular.
             *
             * See xkbcomp commits 2a473b906943ffd807ad81960c47530ee7ae9a60 and
             * 3caab5aa37decb7b5dc1642a0452efc3e1f5100e for more details.
             */
            if (interp.sym == NoSymbol && interp.match == XkbSI_AnyOfOrNone &&
                (interp.mods & 0xff) == 0xff) {
                ErrorF("XKB: Skipping broken Any+AnyOfOrNone(All) -> Private "
                       ~ "action from compiled keymap\n");
                continue;
            }
            /* copy the kind of action */
            memcpy(act.any.data.ptr, wire.actionData.ptr, XkbAnyActionDataSize);
            break;

        case XkbSA_Terminate:
            /* no args, kinda (note: untrue for xfree86). */
            break;
        case XkbSA_ActionMessage:
            /* unsupported. */
            break;
        default: break;}
        interp++;
        compat.num_si++;
    }
    if ((num_si > 0) && (changes)) {
        changes.compat.first_si = 0;
        changes.compat.num_si = compat.num_si;
    }
    if (groups) {
        uint bit = void;

        for (i = 0, bit = 1; i < XkbNumKbdGroups; i++, bit <<= 1) {
            xkmModsDesc md = void;

            if (groups & bit) {
                tmp = cast(int)fread(&md, xkmModsDesc.sizeof, 1, file);
                nRead += tmp * xkmModsDesc.sizeof;
                xkb.compat.groups[i].real_mods = md.realMods;
                xkb.compat.groups[i].vmods = md.virtualMods;
                if (md.virtualMods != 0) {
                    uint mask = void;

                    if (XkbVirtualModsToReal(xkb, md.virtualMods, &mask))
                        xkb.compat.groups[i].mask = cast(ubyte)(md.realMods | mask);
                }
                else
                    xkb.compat.groups[i].mask = md.realMods;
            }
        }
        if (changes)
            changes.compat.changed_groups |= groups;
    }
    return nRead;
}

private int ReadXkmIndicators(FILE* file, XkbDescPtr xkb, XkbChangesPtr changes)
{
    uint nLEDs = void;
    xkmIndicatorMapDesc wire = { 0 };
    char[100] buf = 0;
    uint tmp = void;
    int nRead = 0;

    if ((xkb.indicators is null) && (XkbAllocIndicatorMaps(xkb) != Success)) {
        //_XkbLibError(_XkbErrBadAlloc, "indicator rec", 0);
        return -1;
    }
    if (XkbAllocNames(xkb, XkbIndicatorNamesMask, 0, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "indicator names", 0);
        return -1;
    }
    nLEDs = XkmGetCARD8(file, &nRead);
    nRead += XkmSkipPadding(file, 3);
    xkb.indicators.phys_indicators = XkmGetCARD32(file, &nRead);
    while (nLEDs-- > 0) {
        Atom name = void;
        XkbIndicatorMapPtr map = void;

        if ((tmp = XkmGetCountedString(file, buf.ptr, 100)) < 1) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmIndicators", 0);
            return -1;
        }
        nRead += tmp;
        if (buf[0] != '\0')
            name = XkbInternAtom(buf.ptr, FALSE);
        else
            name = None;
        if ((tmp = cast(int)fread(&wire, xkmIndicatorMapDesc.sizeof, 1, file)) < 1) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmIndicators", 0);
            return -1;
        }
        nRead += tmp * xkmIndicatorMapDesc.sizeof;
        if (xkb.names) {
            xkb.names.indicators[wire.indicator - 1] = name;
            if (changes)
                changes.names.changed_indicators |=
                    (1 << (wire.indicator - 1));
        }
        map = &xkb.indicators.maps[wire.indicator - 1];
        map.flags = wire.flags;
        map.which_groups = wire.which_groups;
        map.groups = wire.groups;
        map.which_mods = wire.which_mods;
        map.mods.mask = wire.real_mods;
        map.mods.real_mods = wire.real_mods;
        map.mods.vmods = wire.vmods;
        map.ctrls = cast(uint)wire.ctrls;
    }
    return nRead;
}

private XkbKeyTypePtr FindTypeForKey(XkbDescPtr xkb, Atom name, uint width, KeySym* syms)
{
    if ((!xkb) || (!xkb.map))
        return null;
    if (name != None) {
        uint i = void;

        for (i = 0; i < xkb.map.num_types; i++) {
            if (xkb.map.types[i].name == name) {
                if (xkb.map.types[i].num_levels != width)
                    DebugF("Group width mismatch between key and type\n");
                return &xkb.map.types[i];
            }
        }
    }
    if ((width < 2) || ((syms !is null) && (syms[1] == NoSymbol)))
        return &xkb.map.types[XkbOneLevelIndex];
    if (syms !is null) {
        if (XkbKSIsLower(syms[0]) && XkbKSIsUpper(syms[1]))
            return &xkb.map.types[XkbAlphabeticIndex];
        else if (XkbKSIsKeypad(syms[0]) || XkbKSIsKeypad(syms[1]))
            return &xkb.map.types[XkbKeypadIndex];
    }
    return &xkb.map.types[XkbTwoLevelIndex];
}

private int ReadXkmSymbols(FILE* file, XkbDescPtr xkb)
{
    int i = void, g = void, s = void, totalVModMaps = void;
    xkmKeySymMapDesc wireMap = { 0 };
    char[100] buf = 0;
    uint minKC = void, maxKC = void, groupNames = void, tmp = void;
    int nRead = 0;

    if ((tmp = XkmGetCountedString(file, buf.ptr, 100)) < 1)
        return -1;
    nRead += tmp;
    minKC = XkmGetCARD8(file, &nRead);
    maxKC = XkmGetCARD8(file, &nRead);
    groupNames = XkmGetCARD8(file, &nRead);
    totalVModMaps = XkmGetCARD8(file, &nRead);
    if (XkbAllocNames(xkb,
                      XkbSymbolsNameMask | XkbPhysSymbolsNameMask |
                      XkbGroupNamesMask, 0, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "physical names", 0);
        return -1;
    }
    if ((buf[0] != '\0') && (xkb.names)) {
        Atom name = void;

        name = XkbInternAtom(buf.ptr, 0);
        xkb.names.symbols = name;
        xkb.names.phys_symbols = name;
    }
    for (i = 0, g = 1; i < XkbNumKbdGroups; i++, g <<= 1) {
        if (groupNames & g) {
            if ((tmp = XkmGetCountedString(file, buf.ptr, 100)) < 1)
                return -1;
            nRead += tmp;

            if (!xkb.names)
                continue;

            if (buf[0] != '\0') {
                Atom name = void;

                name = XkbInternAtom(buf.ptr, 0);
                xkb.names.groups[i] = name;
            }
            else
                xkb.names.groups[i] = None;
        }
    }
    if (XkbAllocServerMap(xkb, XkbAllServerInfoMask, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "server map", 0);
        return -1;
    }
    if (XkbAllocClientMap(xkb, XkbAllClientInfoMask, 0) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "client map", 0);
        return -1;
    }
    if (XkbAllocControls(xkb, XkbAllControlsMask) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "controls", 0);
        return -1;
    }
    if ((xkb.map is null) || (xkb.server is null))
        return -1;
    if (xkb.min_key_code < 8)
        xkb.min_key_code = cast(ubyte)minKC;
    if (xkb.max_key_code < 8)
        xkb.max_key_code = cast(ubyte)maxKC;
    if ((minKC >= 8) && (minKC < xkb.min_key_code))
        xkb.min_key_code = cast(ubyte)minKC;
    if ((maxKC >= 8) && (maxKC > xkb.max_key_code)) {
        //_XkbLibError(_XkbErrBadValue, "keys in symbol map", maxKC);
        return -1;
    }
    for (i = minKC; i <= cast(int) maxKC; i++) {
        Atom[XkbNumKbdGroups] typeName = void;
        XkbKeyTypePtr[XkbNumKbdGroups] type = void;

        if ((tmp = cast(int)fread(&wireMap, xkmKeySymMapDesc.sizeof, 1, file)) < 1) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmSymbols", 0);
            return -1;
        }
        nRead += tmp * xkmKeySymMapDesc.sizeof;
        memset(cast(char*) typeName, 0, XkbNumKbdGroups * Atom.sizeof);
        memset(cast(char*) type, 0, XkbNumKbdGroups * XkbKeyTypePtr.sizeof);
        if (wireMap.flags & XkmKeyHasTypes) {
            for (g = 0; g < XkbNumKbdGroups; g++) {
                if ((wireMap.flags & (1 << g)) &&
                    ((tmp = XkmGetCountedString(file, buf.ptr, 100)) > 0)) {
                    typeName[g] = XkbInternAtom(buf.ptr, 1);
                    nRead += tmp;
                }
                type[g] = FindTypeForKey(xkb, typeName[g], wireMap.width, null);
                if (type[g] is null) {
                    //_XkbLibError(_XkbErrMissingTypes, "ReadXkmSymbols", 0);
                    return -1;
                }
                if (typeName[g] == type[g].name)
                    xkb.server.explicit[i] |= (1 << g);
            }
        }
        if (wireMap.flags & XkmRepeatingKey) {
            xkb.ctrls.per_key_repeat[i / 8] |= (1 << (i % 8));
            xkb.server.explicit[i] |= XkbExplicitAutoRepeatMask;
        }
        else if (wireMap.flags & XkmNonRepeatingKey) {
            xkb.ctrls.per_key_repeat[i / 8] &= ~(1 << (i % 8));
            xkb.server.explicit[i] |= XkbExplicitAutoRepeatMask;
        }
        xkb.map.modmap[i] = wireMap.modifier_map;
        if (mixin(XkbNumGroups!("wireMap.num_groups")) > 0) {
            KeySym* sym = void;
            int nSyms = void;

            if (mixin(XkbNumGroups!("wireMap.num_groups")) > xkb.ctrls.num_groups)
                xkb.ctrls.num_groups = cast(ubyte)(wireMap.num_groups);
            nSyms = mixin(XkbNumGroups!("wireMap.num_groups")) * wireMap.width;
            sym = XkbResizeKeySyms(xkb, i, nSyms);
            if (!sym)
                return -1;
            for (s = 0; s < nSyms; s++) {
                *sym++ = XkmGetCARD32(file, &nRead);
            }
            if (wireMap.flags & XkmKeyHasActions) {
                XkbAction* act = void;

                act = XkbResizeKeyActions(xkb, i, nSyms);
                for (s = 0; s < nSyms; s++, act++) {
                    tmp = cast(int)fread(act, xkmActionDesc.sizeof, 1, file);
                    nRead += tmp * xkmActionDesc.sizeof;
                }
                xkb.server.explicit[i] |= XkbExplicitInterpretMask;
            }
        }
        for (g = 0; g < mixin(XkbNumGroups!("wireMap.num_groups")); g++) {
            if (((xkb.server.explicit[i] & (1 << g)) == 0) ||
                (type[g] is null)) {
                KeySym* tmpSyms = void;

                tmpSyms = mixin(XkbKeySymsPtr!("xkb", "i")) + (wireMap.width * g);
                type[g] = FindTypeForKey(xkb, None, wireMap.width, tmpSyms);
            }
            xkb.map.key_sym_map[i].kt_index[g] =
                cast(ubyte)(type[g] - (&xkb.map.types[0]));
        }
        xkb.map.key_sym_map[i].group_info = wireMap.num_groups;
        xkb.map.key_sym_map[i].width = wireMap.width;
        if (wireMap.flags & XkmKeyHasBehavior) {
            xkmBehaviorDesc b = void;

            tmp = cast(int)fread(&b, xkmBehaviorDesc.sizeof, 1, file);
            nRead += tmp * xkmBehaviorDesc.sizeof;
            xkb.server.behaviors[i].type = b.type;
            xkb.server.behaviors[i].data = b.data;
            xkb.server.explicit[i] |= XkbExplicitBehaviorMask;
        }
    }
    if (totalVModMaps > 0) {
        xkmVModMapDesc v = void;

        for (i = 0; i < totalVModMaps; i++) {
            tmp = cast(int)fread(&v, xkmVModMapDesc.sizeof, 1, file);
            nRead += tmp * xkmVModMapDesc.sizeof;
            if (tmp > 0)
                xkb.server.vmodmap[v.key] = v.vmods;
        }
    }
    return nRead;
}

private int ReadXkmGeomDoodad(FILE* file, XkbGeometryPtr geom, XkbSectionPtr section)
{
    XkbDoodadPtr doodad = void;
    xkmDoodadDesc doodadWire;
    char[100] buf = 0;
    uint tmp = void;
    int nRead = 0;

    nRead += XkmGetCountedString(file, buf.ptr, 100);
    tmp = cast(uint)fread(&doodadWire, xkmDoodadDesc.sizeof, 1, file);
    nRead += xkmDoodadDesc.sizeof * tmp;
    doodad = XkbAddGeomDoodad(geom, section, XkbInternAtom(buf.ptr, FALSE));
    if (!doodad)
        return nRead;
    doodad.any.type = doodadWire.any.type;
    doodad.any.priority = doodadWire.any.priority;
    doodad.any.top = doodadWire.any.top;
    doodad.any.left = doodadWire.any.left;
    switch (doodadWire.any.type) {
    case XkbOutlineDoodad:
    case XkbSolidDoodad:
        doodad.shape.angle = doodadWire.shape.angle;
        doodad.shape.color_ndx = doodadWire.shape.color_ndx;
        doodad.shape.shape_ndx = doodadWire.shape.shape_ndx;
        break;
    case XkbTextDoodad:
        doodad.text.angle = doodadWire.text.angle;
        doodad.text.width = doodadWire.text.width;
        doodad.text.height = doodadWire.text.height;
        doodad.text.color_ndx = doodadWire.text.color_ndx;
        nRead += XkmGetCountedString(file, buf.ptr, 100);
        doodad.text.text = cast(char*)Xstrdup(buf.ptr);
        nRead += XkmGetCountedString(file, buf.ptr, 100);
        doodad.text.font = cast(char*)Xstrdup(buf.ptr);
        break;
    case XkbIndicatorDoodad:
        doodad.indicator.shape_ndx = doodadWire.indicator.shape_ndx;
        doodad.indicator.on_color_ndx = doodadWire.indicator.on_color_ndx;
        doodad.indicator.off_color_ndx = doodadWire.indicator.off_color_ndx;
        break;
    case XkbLogoDoodad:
        doodad.logo.angle = doodadWire.logo.angle;
        doodad.logo.color_ndx = doodadWire.logo.color_ndx;
        doodad.logo.shape_ndx = doodadWire.logo.shape_ndx;
        nRead += XkmGetCountedString(file, buf.ptr, 100);
        doodad.logo.logo_name = cast(char*)Xstrdup(buf.ptr);
        break;
    default:
        /* report error? */
        return nRead;
    }
    return nRead;
}

private int ReadXkmGeomOverlay(FILE* file, XkbGeometryPtr geom, XkbSectionPtr section)
{
    char[100] buf = 0;
    uint tmp = void;
    int nRead = 0;
    XkbOverlayPtr ol = void;
    XkbOverlayRowPtr row = void;
    xkmOverlayDesc olWire = { 0 };
    xkmOverlayRowDesc rowWire = { 0 };
    int r = void;

    nRead += XkmGetCountedString(file, buf.ptr, 100);
    tmp = cast(uint)fread(&olWire, xkmOverlayDesc.sizeof, 1, file);
    nRead += tmp * xkmOverlayDesc.sizeof;
    ol = XkbAddGeomOverlay(section, XkbInternAtom(buf.ptr, FALSE), olWire.num_rows);
    if (!ol)
        return nRead;
    for (r = 0; r < olWire.num_rows; r++) {
        int k = void;
        xkmOverlayKeyDesc keyWire = void;

        tmp = cast(uint)fread(&rowWire, xkmOverlayRowDesc.sizeof, 1, file);
        nRead += tmp * xkmOverlayRowDesc.sizeof;
        row = XkbAddGeomOverlayRow(ol, rowWire.row_under, rowWire.num_keys);
        if (!row) {
            //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeomOverlay", 0);
            return nRead;
        }
        for (k = 0; k < rowWire.num_keys; k++) {
            tmp = cast(uint)fread(&keyWire, xkmOverlayKeyDesc.sizeof, 1, file);
            nRead += tmp * xkmOverlayKeyDesc.sizeof;
            memcpy(row.keys[k].over.name.ptr, keyWire.over.ptr, XkbKeyNameLength);
            memcpy(row.keys[k].under.name.ptr, keyWire.under.ptr, XkbKeyNameLength);
        }
        row.num_keys = rowWire.num_keys;
    }
    return nRead;
}

private int ReadXkmGeomSection(FILE* file, XkbGeometryPtr geom)
{
    int i = void;
    XkbSectionPtr section = void;
    xkmSectionDesc sectionWire = { 0 };
    uint tmp = void;
    int nRead = 0;
    char[100] buf = 0;
    Atom nameAtom = void;

    nRead += XkmGetCountedString(file, buf.ptr, 100);
    nameAtom = XkbInternAtom(buf.ptr, FALSE);
    tmp = cast(uint)fread(&sectionWire, xkmSectionDesc.sizeof, 1, file);
    nRead += xkmSectionDesc.sizeof * tmp;
    section = XkbAddGeomSection(geom, nameAtom, sectionWire.num_rows,
                                sectionWire.num_doodads,
                                sectionWire.num_overlays);
    if (!section) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeomSection", 0);
        return nRead;
    }
    section.top = sectionWire.top;
    section.left = sectionWire.left;
    section.width = sectionWire.width;
    section.height = sectionWire.height;
    section.angle = sectionWire.angle;
    section.priority = sectionWire.priority;
    if (sectionWire.num_rows > 0) {
        int k = void;
        XkbRowPtr row = void;
        xkmRowDesc rowWire = { 0 };
        XkbKeyPtr key = void;
        xkmKeyDesc keyWire = { 0 };

        for (i = 0; i < sectionWire.num_rows; i++) {
            tmp = cast(uint)fread(&rowWire, xkmRowDesc.sizeof, 1, file);
            nRead += xkmRowDesc.sizeof * tmp;
            row = XkbAddGeomRow(section, rowWire.num_keys);
            if (!row) {
                //_XkbLibError(_XkbErrBadAlloc, "ReadXkmKeycodes", 0);
                return nRead;
            }
            row.top = rowWire.top;
            row.left = rowWire.left;
            row.vertical = rowWire.vertical;
            for (k = 0; k < rowWire.num_keys; k++) {
                tmp = cast(uint)fread(&keyWire, xkmKeyDesc.sizeof, 1, file);
                nRead += xkmKeyDesc.sizeof * tmp;
                key = XkbAddGeomKey(row);
                if (!key) {
                    //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeomSection", 0);
                    return nRead;
                }
                memcpy(key.name.name.ptr, keyWire.name.ptr, XkbKeyNameLength);
                key.gap = keyWire.gap;
                key.shape_ndx = keyWire.shape_ndx;
                key.color_ndx = keyWire.color_ndx;
            }
        }
    }
    if (sectionWire.num_doodads > 0) {
        for (i = 0; i < sectionWire.num_doodads; i++) {
            tmp = ReadXkmGeomDoodad(file, geom, section);
            nRead += tmp;
            if (tmp < 1)
                return nRead;
        }
    }
    if (sectionWire.num_overlays > 0) {
        for (i = 0; i < sectionWire.num_overlays; i++) {
            tmp = ReadXkmGeomOverlay(file, geom, section);
            nRead += tmp;
            if (tmp < 1)
                return nRead;
        }
    }
    return nRead;
}

private int ReadXkmGeometry(FILE* file, XkbDescPtr xkb)
{
    int i = void;
    char[100] buf = 0;
    uint tmp = void;
    int nRead = 0;
    xkmGeometryDesc wireGeom = { 0 };
    XkbGeometryPtr geom = void;
    XkbGeometrySizesRec sizes = { 0 };

    nRead += XkmGetCountedString(file, buf.ptr, 100);
    tmp = cast(uint)fread(&wireGeom, xkmGeometryDesc.sizeof, 1, file);
    nRead += tmp * xkmGeometryDesc.sizeof;
    sizes.which = XkbGeomAllMask;
    sizes.num_properties = wireGeom.num_properties;
    sizes.num_colors = wireGeom.num_colors;
    sizes.num_shapes = wireGeom.num_shapes;
    sizes.num_sections = wireGeom.num_sections;
    sizes.num_doodads = wireGeom.num_doodads;
    sizes.num_key_aliases = wireGeom.num_key_aliases;
    if (XkbAllocGeometry(xkb, &sizes) != Success) {
        //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeometry", 0);
        return nRead;
    }
    geom = xkb.geom;
    geom.name = XkbInternAtom(buf.ptr, FALSE);
    geom.width_mm = wireGeom.width_mm;
    geom.height_mm = wireGeom.height_mm;
    nRead += XkmGetCountedString(file, buf.ptr, 100);
    geom.label_font = cast(char*)Xstrdup(buf.ptr);
    if (wireGeom.num_properties > 0) {
        char[1024] val = void;

        for (i = 0; i < wireGeom.num_properties; i++) {
            nRead += XkmGetCountedString(file, buf.ptr, 100);
            nRead += XkmGetCountedString(file, val.ptr, 1024);
            if (XkbAddGeomProperty(geom, buf.ptr, val.ptr) is null) {
                //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeometry", 0);
                return nRead;
            }
        }
    }
    if (wireGeom.num_colors > 0) {
        for (i = 0; i < wireGeom.num_colors; i++) {
            nRead += XkmGetCountedString(file, buf.ptr, 100);
            if (XkbAddGeomColor(geom, buf.ptr, i) is null) {
                //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeometry", 0);
                return nRead;
            }
        }
    }
    geom.base_color = &geom.colors[wireGeom.base_color_ndx];
    geom.label_color = &geom.colors[wireGeom.label_color_ndx];
    if (wireGeom.num_shapes > 0) {
        XkbShapePtr shape = void;
        xkmShapeDesc shapeWire = void;
        Atom nameAtom = void;

        for (i = 0; i < wireGeom.num_shapes; i++) {
            int n = void;
            XkbOutlinePtr ol = void;
            xkmOutlineDesc olWire = void;

            nRead += XkmGetCountedString(file, buf.ptr, 100);
            nameAtom = XkbInternAtom(buf.ptr, FALSE);
            tmp = cast(uint)fread(&shapeWire, xkmShapeDesc.sizeof, 1, file);
            nRead += tmp * xkmShapeDesc.sizeof;
            shape = XkbAddGeomShape(geom, nameAtom, shapeWire.num_outlines);
            if (!shape) {
                //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeometry", 0);
                return nRead;
            }
            for (n = 0; n < shapeWire.num_outlines; n++) {
                int p = void;
                xkmPointDesc ptWire = void;

                tmp = cast(uint)fread(&olWire, xkmOutlineDesc.sizeof, 1, file);
                nRead += tmp * xkmOutlineDesc.sizeof;
                ol = XkbAddGeomOutline(shape, olWire.num_points);
                if (!ol) {
                    //_XkbLibError(_XkbErrBadAlloc, "ReadXkmGeometry", 0);
                    return nRead;
                }
                ol.num_points = olWire.num_points;
                ol.corner_radius = olWire.corner_radius;
                for (p = 0; p < olWire.num_points; p++) {
                    tmp = cast(uint)fread(&ptWire, xkmPointDesc.sizeof, 1, file);
                    nRead += tmp * xkmPointDesc.sizeof;
                    ol.points[p].x = ptWire.x;
                    ol.points[p].y = ptWire.y;
                    if (ptWire.x < shape.bounds.x1)
                        shape.bounds.x1 = ptWire.x;
                    if (ptWire.x > shape.bounds.x2)
                        shape.bounds.x2 = ptWire.x;
                    if (ptWire.y < shape.bounds.y1)
                        shape.bounds.y1 = ptWire.y;
                    if (ptWire.y > shape.bounds.y2)
                        shape.bounds.y2 = ptWire.y;
                }
            }
            if (shapeWire.primary_ndx != XkbNoShape)
                shape.primary = &shape.outlines[shapeWire.primary_ndx];
            if (shapeWire.approx_ndx != XkbNoShape)
                shape.approx = &shape.outlines[shapeWire.approx_ndx];
        }
    }
    if (wireGeom.num_sections > 0) {
        for (i = 0; i < wireGeom.num_sections; i++) {
            tmp = ReadXkmGeomSection(file, geom);
            nRead += tmp;
            if (tmp == 0)
                return nRead;
        }
    }
    if (wireGeom.num_doodads > 0) {
        for (i = 0; i < wireGeom.num_doodads; i++) {
            tmp = ReadXkmGeomDoodad(file, geom, null);
            nRead += tmp;
            if (tmp == 0)
                return nRead;
        }
    }
    if ((wireGeom.num_key_aliases > 0) && (geom.key_aliases)) {
        int sz = XkbKeyNameLength * 2;
        int num = wireGeom.num_key_aliases;

        if (fread(geom.key_aliases, sz, num, file) != num) {
            //_XkbLibError(_XkbErrBadLength, "ReadXkmGeometry", 0);
            return -1;
        }
        nRead += (num * sz);
        geom.num_key_aliases = cast(ushort)num;
    }
    return nRead;
}

private Bool XkmReadTOC(FILE* file, xkmFileInfo* file_info, int max_toc, xkmSectionInfo* toc)
{
    uint hdr = void, tmp = void;
    int nRead = 0;
    uint i = void, size_toc = void;

    hdr = (('x' << 24) | ('k' << 16) | ('m' << 8) | XkmFileVersion);
    tmp = cast(uint)XkmGetCARD32(file, &nRead);
    if (tmp != hdr) {
        if ((tmp & (~0xff)) == (hdr & (~0xff))) {
            //_XkbLibError(_XkbErrBadFileVersion, "XkmReadTOC", tmp & 0xff);
        }
        else {
            //_XkbLibError(_XkbErrBadFileType, "XkmReadTOC", tmp);
        }
        return 0;
    }
    if (fread(file_info, xkmFileInfo.sizeof, 1, file) != 1)
        return 0;
    size_toc = file_info.num_toc;
    if (size_toc > max_toc) {
        DebugF("Warning! Too many TOC entries; last %d ignored\n",
               size_toc - max_toc);
        size_toc = max_toc;
    }
    for (i = 0; i < size_toc; i++) {
        if (fread(&toc[i], xkmSectionInfo.sizeof, 1, file) != 1)
            return 0;
    }
    return 1;
}

/***====================================================================***/

enum	MAX_TOC =	16;
uint XkmReadFile(FILE* file, uint need, uint want, XkbDescPtr* xkb)
{
    uint i = void;
    xkmSectionInfo[MAX_TOC] toc;
    xkmSectionInfo tmpTOC = { 0 };
    xkmFileInfo fileInfo = { 0 };
    uint tmp = void, nRead = 0;
    uint which = need | want;

    if (!XkmReadTOC(file, &fileInfo, MAX_TOC, toc.ptr))
        return which;
    if ((fileInfo.present & need) != need) {
        //_XkbLibError(_XkbErrIllegalContents, "XkmReadFile",
                    //  need & (~fileInfo.present));
        return which;
    }
    if (*xkb is null)
        *xkb = XkbAllocKeyboard();
    for (i = 0; i < fileInfo.num_toc; i++) {
        fseek(file, toc[i].offset, SEEK_SET);
        tmp = cast(uint)fread(&tmpTOC, xkmSectionInfo.sizeof, 1, file);
        nRead = cast(uint)(tmp * xkmSectionInfo.sizeof);
        if ((tmpTOC.type != toc[i].type) || (tmpTOC.format != toc[i].format) ||
            (tmpTOC.size != toc[i].size) || (tmpTOC.offset != toc[i].offset)) {
            return which;
        }
        if ((which & (1 << tmpTOC.type)) == 0) {
            continue;
        }
        switch (tmpTOC.type) {
        case XkmVirtualModsIndex:
            tmp = ReadXkmVirtualMods(file, *xkb, null);
            break;
        case XkmTypesIndex:
            tmp = ReadXkmKeyTypes(file, *xkb, null);
            break;
        case XkmCompatMapIndex:
            tmp = ReadXkmCompatMap(file, *xkb, null);
            break;
        case XkmKeyNamesIndex:
            tmp = ReadXkmKeycodes(file, *xkb, null);
            break;
        case XkmIndicatorsIndex:
            tmp = ReadXkmIndicators(file, *xkb, null);
            break;
        case XkmSymbolsIndex:
            tmp = ReadXkmSymbols(file, *xkb);
            break;
        case XkmGeometryIndex:
            tmp = ReadXkmGeometry(file, *xkb);
            break;
        default:
            //_XkbLibError(_XkbErrBadImplementation,
                        //  XkbConfigText(tmpTOC.type, XkbMessage), 0);
            tmp = 0;
            break;
        }
        if (tmp > 0) {
            nRead += tmp;
            which &= ~(1 << toc[i].type);
            (*xkb).defined |= (1 << toc[i].type);
        }
        if (nRead != tmpTOC.size) {
            //_XkbLibError(_XkbErrBadLength,
                        //  XkbConfigText(tmpTOC.type, XkbMessage),
                        //  nRead - tmpTOC.size);
        }
    }
    return which;
}
