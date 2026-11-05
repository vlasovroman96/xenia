module xkb.xkbtext;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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
import core.stdc.ctype;
import core.stdc.stdlib;
// //import x11.Xos;
//import x11.X;
//import x11.Xproto;
import externs.X11.extensions.XKM;

import xkb.xkbtext_priv;
import dix.atom;
import common.misc;
import dix.inputstr;import include.xkbsrv;
import include.xkbsrv;
import xkb.xkbgeom_priv;
import externs.X11.extensions.XKB;

import include.xkbstr;

/***====================================================================***/

enum NUM_BUFFER =      8;
struct textBuffer_t {
    int size;
    char* buffer;
}
private textBuffer_t[NUM_BUFFER] textBuffer;
private int textBufferIndex;

private char* tbGetBuffer(uint size)
{
    textBuffer_t* tb = void;

    tb = &textBuffer[textBufferIndex];
    textBufferIndex = (textBufferIndex + 1) % NUM_BUFFER;

    if (size > tb.size) {
        free(tb.buffer);
        tb.buffer = cast(char*)XNFalloc(size);
        tb.size = size;
    }
    return tb.buffer;
}

/***====================================================================***/

pragma(inline, true) private char* tbGetBufferString(const(char)* str)
{
    size_t size = strlen(str) + 1;
    char* rtrn = tbGetBuffer(cast(uint) size);

    if (rtrn !is null)
        memcpy(rtrn, str, size);

    return rtrn;
}

/***====================================================================***/

char* XkbAtomText(Atom atm, uint format)
{
    const(char)* atmstr = void;
    char* rtrn = void, tmp = void;

    atmstr = NameForAtom(atm);
    if (atmstr !is null) {
        rtrn = tbGetBufferString(atmstr);
    }
    else {
        rtrn = tbGetBuffer(1);
        rtrn[0] = '\0';
    }
    if (format == XkbCFile) {
        for (tmp = rtrn; *tmp != '\0'; tmp++) {
            if ((tmp == rtrn) && (!isalpha(cast(ubyte)*tmp)))
                *tmp = '_';
            else if (!isalnum(cast(ubyte)*tmp))
                *tmp = '_';
        }
    }
    return XkbStringText(rtrn, format);
}

/***====================================================================***/

char* XkbVModIndexText(XkbDescPtr xkb, uint ndx, uint format)
{
    int len = void;
    Atom* vmodNames = void;
    char* rtrn = void;
    const(char)* tmp = void;
    char[20] numBuf = 0;

    if (xkb && xkb.names)
        vmodNames = xkb.names.vmods.ptr;
    else
        vmodNames = null;

    tmp = null;
    if (ndx >= XkbNumVirtualMods)
        tmp = "illegal";
    else if (vmodNames && (vmodNames[ndx] != None))
        tmp = NameForAtom(vmodNames[ndx]);
    if (tmp is null) {
        snprintf(numBuf.ptr, numBuf.sizeof, "%d", ndx);
        tmp = numBuf.ptr;
    }

    len = cast(int)(strlen(tmp) + 1);
    if (format == XkbCFile)
        len += 5;
    rtrn = tbGetBuffer(len);
    if (format == XkbCFile) {
        strcpy(rtrn, "vmod_");
        strncpy(&rtrn[5], tmp, len - 5);
    }
    else
        strncpy(rtrn, tmp, len);
    return rtrn;
}

enum VMOD_BUFFER_SIZE =        512;

char* XkbVModMaskText(XkbDescPtr xkb, uint modMask, uint mask, uint format)
{
    int i = void, bit = void;
    int len = void;
    char* mm = void, rtrn = void;
    char* str = void; char[VMOD_BUFFER_SIZE] buf = 0;

    if ((modMask == 0) && (mask == 0)) {
        const(int) rtrnsize = 5;
        rtrn = tbGetBuffer(rtrnsize);
        if (format == XkbCFile)
            snprintf(rtrn, rtrnsize, "0");
        else
            snprintf(rtrn, rtrnsize, "none");
        return rtrn;
    }
    if (modMask != 0)
        mm = XkbModMaskText(modMask, format);
    else
        mm = null;

    str = buf.ptr;
    buf[0] = '\0';
    if (mask) {
        char* tmp = void;

        for (i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
            if (mask & bit) {
                tmp = XkbVModIndexText(xkb, i, format);
                len = cast(int)(strlen(tmp) + 1 + (str == buf.ptr ? 0 : 1));
                if (format == XkbCFile)
                    len += 4;
                if ((str - buf.ptr) + len > VMOD_BUFFER_SIZE)
                    continue; /* Skip */
                if (str != buf.ptr) {
                    if (format == XkbCFile)
                        *str++ = '|';
                    else
                        *str++ = '+';
                    len--;
                }
                if (format == XkbCFile)
                    sprintf(str, "%sMask", tmp);
                else
                    strcpy(str, tmp);
                str = &str[len - 1];
            }
        }
        str = buf.ptr;
    }
    else
        str = null;
    if (mm)
        len = cast(int)strlen(mm);
    else
        len = 0;
    if (str)
        len += strlen(str) + (mm is null ? 0 : 1);
    rtrn = tbGetBuffer(len + 1);
    rtrn[0] = '\0';

    if (mm !is null) {
        i = cast(int)strlen(mm);
        if (i > len)
            i = len;
        strcpy(rtrn, mm);
    }
    else {
        i = 0;
    }
    if (str !is null) {
        if (mm !is null) {
            if (format == XkbCFile)
                strcat(rtrn, "|");
            else
                strcat(rtrn, "+");
        }
        strncat(rtrn, str, len - i);
    }
    rtrn[len] = '\0';
    return rtrn;
}

private const(char)*[XkbNumModifiers] modNames = [
    "Shift", "Lock", "Control", "Mod1", "Mod2", "Mod3", "Mod4", "Mod5"
];

char* XkbModIndexText(uint ndx, uint format)
{
    char[100] buf = 0;

    if (format == XkbCFile) {
        if (ndx < XkbNumModifiers)
            snprintf(buf.ptr, buf.sizeof, "%sMapIndex", modNames[ndx]);
        else if (ndx == XkbNoModifier)
            snprintf(buf.ptr, buf.sizeof, "XkbNoModifier");
        else
            snprintf(buf.ptr, buf.sizeof, "0x%02x", ndx);
    }
    else {
        if (ndx < XkbNumModifiers)
            strcpy(buf.ptr, modNames[ndx]);
        else if (ndx == XkbNoModifier)
            strcpy(buf.ptr, "none");
        else
            snprintf(buf.ptr, buf.sizeof, "ILLEGAL_%02x", ndx);
    }
    return tbGetBufferString(buf.ptr);
}

char* XkbModMaskText(uint mask, uint format)
{
    int i = void, bit = void;
    char[64] buf = 0;
    char* rtrn = void;

    if ((mask & 0xff) == 0xff) {
        if (format == XkbCFile)
            strcpy(buf.ptr, "0xff");
        else
            strcpy(buf.ptr, "all");
    }
    else if ((mask & 0xff) == 0) {
        if (format == XkbCFile)
            strcpy(buf.ptr, "0");
        else
            strcpy(buf.ptr, "none");
    }
    else {
        char* str = buf.ptr;

        buf[0] = '\0';
        for (i = 0, bit = 1; i < XkbNumModifiers; i++, bit <<= 1) {
            if (mask & bit) {
                if (str != buf.ptr) {
                    if (format == XkbCFile)
                        *str++ = '|';
                    else
                        *str++ = '+';
                }
                strcpy(str, modNames[i]);
                str = &str[strlen(str)];
                if (format == XkbCFile) {
                    strcpy(str, "Mask");
                    str += 4;
                }
            }
        }
    }
    rtrn = tbGetBufferString(buf.ptr);
    return rtrn;
}

/***====================================================================***/

 /*ARGSUSED*/ char* XkbConfigText(uint config, uint format)
{
    static char* buf;
    const(int) bufsize = 32;

    buf = tbGetBuffer(bufsize);
    switch (config) {
    case XkmSemanticsFile:
        strcpy(buf, "Semantics");
        break;
    case XkmLayoutFile:
        strcpy(buf, "Layout");
        break;
    case XkmKeymapFile:
        strcpy(buf, "Keymap");
        break;
    case XkmGeometryFile:
    case XkmGeometryIndex:
        strcpy(buf, "Geometry");
        break;
    case XkmTypesIndex:
        strcpy(buf, "Types");
        break;
    case XkmCompatMapIndex:
        strcpy(buf, "CompatMap");
        break;
    case XkmSymbolsIndex:
        strcpy(buf, "Symbols");
        break;
    case XkmIndicatorsIndex:
        strcpy(buf, "Indicators");
        break;
    case XkmKeyNamesIndex:
        strcpy(buf, "KeyNames");
        break;
    case XkmVirtualModsIndex:
        strcpy(buf, "VirtualMods");
        break;
    default:
        snprintf(buf, bufsize, "unknown(%d)", config);
        break;
    }
    return buf;
}

/***====================================================================***/

char* XkbKeysymText(KeySym sym, uint format)
{
    static char[32] buf = 0;

    if (sym == NoSymbol)
        strcpy(buf.ptr, "NoSymbol");
    else
        snprintf(buf.ptr, buf.sizeof, "0x%lx", cast(c_long) sym);
    return buf.ptr;
}

char* XkbKeyNameText(char* name, uint format)
{
    char* buf = void;

    if (format == XkbCFile) {
        buf = tbGetBuffer(5);
        memcpy(buf, name, 4);
        buf[4] = '\0';
    }
    else {
        int len = void;

        buf = tbGetBuffer(7);
        buf[0] = '<';
        memcpy(&buf[1], name, 4);
        buf[5] = '\0';
        len = cast(int)strlen(buf);
        buf[len++] = '>';
        buf[len] = '\0';
    }
    return buf;
}

/***====================================================================***/

private const(char)*[5] siMatchText = [
    "NoneOf", "AnyOfOrNone", "AnyOf", "AllOf", "Exactly"
];

const(char)* XkbSIMatchText(uint type, uint format)
{
    static char[40] buf = 0;
    const(char)* rtrn = void;

    switch (type & XkbSI_OpMask) {
    case XkbSI_NoneOf:
        rtrn = siMatchText[0];
        break;
    case XkbSI_AnyOfOrNone:
        rtrn = siMatchText[1];
        break;
    case XkbSI_AnyOf:
        rtrn = siMatchText[2];
        break;
    case XkbSI_AllOf:
        rtrn = siMatchText[3];
        break;
    case XkbSI_Exactly:
        rtrn = siMatchText[4];
        break;
    default:
        snprintf(buf.ptr, buf.sizeof, "0x%x", type & XkbSI_OpMask);
        return buf.ptr;
    }
    if (format == XkbCFile) {
        if (type & XkbSI_LevelOneOnly)
            snprintf(buf.ptr, buf.sizeof, "XkbSI_LevelOneOnly|XkbSI_%s", rtrn);
        else
            snprintf(buf.ptr, buf.sizeof, "XkbSI_%s", rtrn);
        rtrn = buf.ptr;
    }
    return rtrn;
}

/***====================================================================***/

private const(char)*[5] imWhichNames = [
    "base",
    "latched",
    "locked",
    "effective",
    "compat"
];

char* XkbIMWhichStateMaskText(uint use_which, uint format)
{
    int len = void, bufsize = void;
    uint i = void, bit = void, tmp = void;
    char* buf = void;

    if (use_which == 0) {
        buf = tbGetBuffer(2);
        strcpy(buf, "0");
        return buf;
    }
    tmp = use_which & XkbIM_UseAnyMods;
    for (len = i = 0, bit = 1; tmp != 0; i++, bit <<= 1) {
        if (tmp & bit) {
            tmp &= ~bit;
            len += strlen(imWhichNames[i]) + 1;
            if (format == XkbCFile)
                len += 9;
        }
    }
    bufsize = len + 1;
    buf = tbGetBuffer(bufsize);
    tmp = use_which & XkbIM_UseAnyMods;
    for (len = i = 0, bit = 1; tmp != 0; i++, bit <<= 1) {
        if (tmp & bit) {
            tmp &= ~bit;
            if (format == XkbCFile) {
                if (len != 0)
                    buf[len++] = '|';
                snprintf(&buf[len], bufsize - len,
                         "XkbIM_Use%s", imWhichNames[i]);
                buf[len + 9] = cast(char)toupper(cast(ubyte)buf[len + 9]);
            }
            else {
                if (len != 0)
                    buf[len++] = '+';
                snprintf(&buf[len], bufsize - len, "%s", imWhichNames[i]);
            }
            len += strlen(&buf[len]);
        }
    }
    return buf;
}

private const(char)*[13] ctrlNames = [
    "repeatKeys",
    "slowKeys",
    "bounceKeys",
    "stickyKeys",
    "mouseKeys",
    "mouseKeysAccel",
    "accessXKeys",
    "accessXTimeout",
    "accessXFeedback",
    "audibleBell",
    "overlay1",
    "overlay2",
    "ignoreGroupLock"
];

char* XkbControlsMaskText(uint ctrls, uint format)
{
    int len = void;
    uint i = void, bit = void, tmp = void;
    char* buf = void;

    if (ctrls == 0) {
        buf = tbGetBuffer(5);
        if (format == XkbCFile)
            strcpy(buf, "0");
        else
            strcpy(buf, "none");
        return buf;
    }
    tmp = ctrls & XkbAllBooleanCtrlsMask;
    for (len = i = 0, bit = 1; tmp != 0; i++, bit <<= 1) {
        if (tmp & bit) {
            tmp &= ~bit;
            len += strlen(ctrlNames[i]) + 1;
            if (format == XkbCFile)
                len += 7;
        }
    }
    buf = tbGetBuffer(len + 1);
    tmp = ctrls & XkbAllBooleanCtrlsMask;
    for (len = i = 0, bit = 1; tmp != 0; i++, bit <<= 1) {
        if (tmp & bit) {
            tmp &= ~bit;
            if (format == XkbCFile) {
                if (len != 0)
                    buf[len++] = '|';
                sprintf(&buf[len], "Xkb%sMask", ctrlNames[i]);
                buf[len + 3] = cast(char)toupper(cast(ubyte)buf[len + 3]);
            }
            else {
                if (len != 0)
                    buf[len++] = '+';
                sprintf(&buf[len], "%s", ctrlNames[i]);
            }
            len += strlen(&buf[len]);
        }
    }
    return buf;
}

/***====================================================================***/

char* XkbStringText(char* str, uint format)
{
    char* buf = void;
    char* in_ = void, out_ = void;
    int len = void;
    Bool ok = void;

    if (str is null) {
        buf = tbGetBuffer(2);
        buf[0] = '\0';
        return buf;
    }
    else if (format == XkbXKMFile)
        return str;
    for (ok = TRUE, len = 0, in_ = str; *in_ != '\0'; in_++, len++) {
        if (!isprint(cast(ubyte)*in_)) {
            ok = FALSE;
            switch (*in_) {
            case '\n':
            case '\t':
            case '\v':
            case '\b':
            case '\r':
            case '\f':
                len++;
                break;
            default:
                len += 4;
                break;
            }
        }
    }
    if (ok)
        return str;
    buf = tbGetBuffer(len + 1);
    for (in_ = str, out_ = buf; *in_ != '\0'; in_++) {
        if (isprint(cast(ubyte)*in_))
            *out_++ = *in_;
        else {
            *out_++ = '\\';
            if (*in_ == '\n')
                *out_++ = 'n';
            else if (*in_ == '\t')
                *out_++ = 't';
            else if (*in_ == '\v')
                *out_++ = 'v';
            else if (*in_ == '\b')
                *out_++ = 'b';
            else if (*in_ == '\r')
                *out_++ = 'r';
            else if (*in_ == '\f')
                *out_++ = 'f';
            else if ((*in_ == '\033') && (format == XkbXKMFile)) {
                *out_++ = 'e';
            }
            else {
                *out_++ = '0';
                sprintf(out_, "%o", cast(ubyte) *in_);
                while (*out_ != '\0')
                    out_++;
            }
        }
    }
    *out_++ = '\0';
    return buf;
}

/***====================================================================***/

char* XkbGeomFPText(int val, uint format)
{
    int whole = void, frac = void;
    char* buf = void;
    const(int) bufsize = 13;

    buf = tbGetBuffer(bufsize);
    if (format == XkbCFile) {
        snprintf(buf, bufsize, "%d", val);
    }
    else {
        whole = val / XkbGeomPtsPerMM;
        frac = abs(val % XkbGeomPtsPerMM);
        if (frac != 0) {
            if (val < 0)
            {
                int wholeabs = void;
                wholeabs = abs(whole);
                snprintf(buf, bufsize, "-%d.%d", wholeabs, frac);
            }
            else
                snprintf(buf, bufsize, "%d.%d", whole, frac);
        }
        else
            snprintf(buf, bufsize, "%d", whole);
    }
    return buf;
}

char* XkbDoodadTypeText(uint type, uint format)
{
    char* buf = void;

    if (format == XkbCFile) {
        const(int) bufsize = 24;
        buf = tbGetBuffer(bufsize);
        if (type == XkbOutlineDoodad)
            strcpy(buf, "XkbOutlineDoodad");
        else if (type == XkbSolidDoodad)
            strcpy(buf, "XkbSolidDoodad");
        else if (type == XkbTextDoodad)
            strcpy(buf, "XkbTextDoodad");
        else if (type == XkbIndicatorDoodad)
            strcpy(buf, "XkbIndicatorDoodad");
        else if (type == XkbLogoDoodad)
            strcpy(buf, "XkbLogoDoodad");
        else
            snprintf(buf, bufsize, "UnknownDoodad%d", type);
    }
    else {
        const(int) bufsize = 12;
        buf = tbGetBuffer(bufsize);
        if (type == XkbOutlineDoodad)
            strcpy(buf, "outline");
        else if (type == XkbSolidDoodad)
            strcpy(buf, "solid");
        else if (type == XkbTextDoodad)
            strcpy(buf, "text");
        else if (type == XkbIndicatorDoodad)
            strcpy(buf, "indicator");
        else if (type == XkbLogoDoodad)
            strcpy(buf, "logo");
        else
            snprintf(buf, bufsize, "unknown%d", type);
    }
    return buf;
}

private const(char)*[XkbSA_NumActions] actionTypeNames = [
    "NoAction",
    "SetMods", "LatchMods", "LockMods",
    "SetGroup", "LatchGroup", "LockGroup",
    "MovePtr",
    "PtrBtn", "LockPtrBtn",
    "SetPtrDflt",
    "ISOLock",
    "Terminate", "SwitchScreen",
    "SetControls", "LockControls",
    "ActionMessage",
    "RedirectKey",
    "DeviceBtn", "LockDeviceBtn"
];

const(char)* XkbActionTypeText(uint type, uint format)
{
    static char[32] buf = 0;
    const(char)* rtrn = void;

    if (type <= XkbSA_LastAction) {
        rtrn = actionTypeNames[type];
        if (format == XkbCFile) {
            snprintf(buf.ptr, buf.sizeof, "XkbSA_%s", rtrn);
            return buf.ptr;
        }
        return rtrn;
    }
    snprintf(buf.ptr, buf.sizeof, "Private");
    return buf.ptr;
}

/***====================================================================***/

private int TryCopyStr(char* to, const(char)* from, int* pLeft)
{
    int len = void;

    if (*pLeft > 0) {
        len = cast(int)strlen(from);
        if (len < ((*pLeft) - 3)) {
            strcat(to, from);
            *pLeft -= len;
            return TRUE;
        }
    }
    *pLeft = -1;
    return FALSE;
}

 /*ARGSUSED*/ private Bool CopyNoActionArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    return TRUE;
}

private Bool CopyModActionArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbModAction* act = void;
    uint tmp = void;

    act = &action.mods;
    tmp = mixin(XkbModActionVMods!("act"));
    TryCopyStr(buf, "modifiers=", sz);
    if (act.flags & XkbSA_UseModMapMods)
        TryCopyStr(buf, "modMapMods", sz);
    else if (act.real_mods || tmp) {
        TryCopyStr(buf,
                   XkbVModMaskText(xkb, act.real_mods, tmp, XkbXKBFile), sz);
    }
    else
        TryCopyStr(buf, "none", sz);
    if (act.type == XkbSA_LockMods)
        return TRUE;
    if (act.flags & XkbSA_ClearLocks)
        TryCopyStr(buf, ",clearLocks", sz);
    if (act.flags & XkbSA_LatchToLock)
        TryCopyStr(buf, ",latchToLock", sz);
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyGroupActionArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbGroupAction* act = void;
    char[32] tbuf = 0;

    act = &action.group;
    TryCopyStr(buf, "group=", sz);
    if (act.flags & XkbSA_GroupAbsolute)
        snprintf(tbuf.ptr, tbuf.sizeof, "%d", mixin(XkbSAGroup!("act")) + 1);
    else if (mixin(XkbSAGroup!("act")) < 0)
        snprintf(tbuf.ptr, tbuf.sizeof, "%d", mixin(XkbSAGroup!("act")));
    else
        snprintf(tbuf.ptr, tbuf.sizeof, "+%d", mixin(XkbSAGroup!("act")));
    TryCopyStr(buf, tbuf.ptr, sz);
    if (act.type == XkbSA_LockGroup)
        return TRUE;
    if (act.flags & XkbSA_ClearLocks)
        TryCopyStr(buf, ",clearLocks", sz);
    if (act.flags & XkbSA_LatchToLock)
        TryCopyStr(buf, ",latchToLock", sz);
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyMovePtrArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbPtrAction* act = void;
    int x = void, y = void;
    char[32] tbuf = 0;

    act = &action.ptr;
    x = mixin(XkbPtrActionX!("act"));
    y = mixin(XkbPtrActionY!("act"));
    if ((act.flags & XkbSA_MoveAbsoluteX) || (x < 0))
        snprintf(tbuf.ptr, tbuf.sizeof, "x=%d", x);
    else
        snprintf(tbuf.ptr, tbuf.sizeof, "x=+%d", x);
    TryCopyStr(buf, tbuf.ptr, sz);

    if ((act.flags & XkbSA_MoveAbsoluteY) || (y < 0))
        snprintf(tbuf.ptr, tbuf.sizeof, ",y=%d", y);
    else
        snprintf(tbuf.ptr, tbuf.sizeof, ",y=+%d", y);
    TryCopyStr(buf, tbuf.ptr, sz);
    if (act.flags & XkbSA_NoAcceleration)
        TryCopyStr(buf, ",!accel", sz);
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyPtrBtnArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbPtrBtnAction* act = void;
    char[32] tbuf = 0;

    act = &action.btn;
    TryCopyStr(buf, "button=", sz);
    if ((act.button > 0) && (act.button < 6)) {
        snprintf(tbuf.ptr, tbuf.sizeof, "%d", act.button);
        TryCopyStr(buf, tbuf.ptr, sz);
    }
    else
        TryCopyStr(buf, "default", sz);
    if (act.count > 0) {
        snprintf(tbuf.ptr, tbuf.sizeof, ",count=%d", act.count);
        TryCopyStr(buf, tbuf.ptr, sz);
    }
    if (action.type == XkbSA_LockPtrBtn) {
        switch (act.flags & (XkbSA_LockNoUnlock | XkbSA_LockNoLock)) {
        case XkbSA_LockNoLock:
            TryCopyStr(buf, ",affect=unlock", sz);
            break;
        case XkbSA_LockNoUnlock:
            TryCopyStr(buf, ",affect=lock", sz);
            break;
        case XkbSA_LockNoUnlock | XkbSA_LockNoLock:
            TryCopyStr(buf, ",affect=neither", sz);
            break;
        default:
            TryCopyStr(buf, ",affect=both", sz);
            break;
        }
    }
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopySetPtrDfltArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbPtrDfltAction* act = void;
    char[32] tbuf = 0;

    act = &action.dflt;
    if (act.affect == XkbSA_AffectDfltBtn) {
        TryCopyStr(buf, "affect=button,button=", sz);
        if ((act.flags & XkbSA_DfltBtnAbsolute) ||
            (mixin(XkbSAPtrDfltValue!("act")) < 0))
            snprintf(tbuf.ptr, tbuf.sizeof, "%d", mixin(XkbSAPtrDfltValue!("act")));
        else
            snprintf(tbuf.ptr, tbuf.sizeof, "+%d", mixin(XkbSAPtrDfltValue!("act")));
        TryCopyStr(buf, tbuf.ptr, sz);
    }
    return TRUE;
}

private Bool CopyISOLockArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbISOAction* act = void;
    char[64] tbuf = 0;

    act = &action.iso;
    if (act.flags & XkbSA_ISODfltIsGroup) {
        TryCopyStr(tbuf.ptr, "group=", sz);
        if (act.flags & XkbSA_GroupAbsolute)
            snprintf(tbuf.ptr, tbuf.sizeof, "%d", mixin(XkbSAGroup!("act")) + 1);
        else if (mixin(XkbSAGroup!("act")) < 0)
            snprintf(tbuf.ptr, tbuf.sizeof, "%d", mixin(XkbSAGroup!("act")));
        else
            snprintf(tbuf.ptr, tbuf.sizeof, "+%d", mixin(XkbSAGroup!("act")));
        TryCopyStr(buf, tbuf.ptr, sz);
    }
    else {
        uint tmp = void;

        tmp = mixin(XkbModActionVMods!("act"));
        TryCopyStr(buf, "modifiers=", sz);
        if (act.flags & XkbSA_UseModMapMods)
            TryCopyStr(buf, "modMapMods", sz);
        else if (act.real_mods || tmp) {
            if (act.real_mods) {
                TryCopyStr(buf, XkbModMaskText(act.real_mods, XkbXKBFile), sz);
                if (tmp)
                    TryCopyStr(buf, "+", sz);
            }
            if (tmp)
                TryCopyStr(buf, XkbVModMaskText(xkb, 0, tmp, XkbXKBFile), sz);
        }
        else
            TryCopyStr(buf, "none", sz);
    }
    TryCopyStr(buf, ",affect=", sz);
    if ((act.affect & XkbSA_ISOAffectMask) == 0)
        TryCopyStr(buf, "all", sz);
    else {
        int nOut = 0;

        if ((act.affect & XkbSA_ISONoAffectMods) == 0) {
            TryCopyStr(buf, "mods", sz);
            nOut++;
        }
        if ((act.affect & XkbSA_ISONoAffectGroup) == 0) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sgroups", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if ((act.affect & XkbSA_ISONoAffectPtr) == 0) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%spointer", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if ((act.affect & XkbSA_ISONoAffectCtrls) == 0) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%scontrols", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
    }
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopySwitchScreenArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbSwitchScreenAction* act = void;
    char[32] tbuf = 0;

    act = &action.screen;
    if ((act.flags & XkbSA_SwitchAbsolute) || (mixin(XkbSAScreen!("act")) < 0))
        snprintf(tbuf.ptr, tbuf.sizeof, "screen=%d", mixin(XkbSAScreen!("act")));
    else
        snprintf(tbuf.ptr, tbuf.sizeof, "screen=+%d", mixin(XkbSAScreen!("act")));
    TryCopyStr(buf, tbuf.ptr, sz);
    if (act.flags & XkbSA_SwitchApplication)
        TryCopyStr(buf, ",!same", sz);
    else
        TryCopyStr(buf, ",same", sz);
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopySetLockControlsArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbCtrlsAction* act = void;
    uint tmp = void;
    char[32] tbuf = 0;

    act = &action.ctrls;
    tmp = mixin(XkbActionCtrls!("act"));
    TryCopyStr(buf, "controls=", sz);
    if (tmp == 0)
        TryCopyStr(buf, "none", sz);
    else if ((tmp & XkbAllBooleanCtrlsMask) == XkbAllBooleanCtrlsMask)
        TryCopyStr(buf, "all", sz);
    else {
        int nOut = 0;

        if (tmp & XkbRepeatKeysMask) {
            TryCopyStr(buf, "RepeatKeys", sz);
            nOut++;
        }
        if (tmp & XkbSlowKeysMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sSlowKeys", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbBounceKeysMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sBounceKeys", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbStickyKeysMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sStickyKeys", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbMouseKeysMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sMouseKeys", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbMouseKeysAccelMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sMouseKeysAccel",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbAccessXKeysMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sAccessXKeys",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbAccessXTimeoutMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sAccessXTimeout",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbAccessXFeedbackMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sAccessXFeedback",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbAudibleBellMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sAudibleBell",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbOverlay1Mask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sOverlay1", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbOverlay2Mask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sOverlay2", (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
        if (tmp & XkbIgnoreGroupLockMask) {
            snprintf(tbuf.ptr, tbuf.sizeof, "%sIgnoreGroupLock",
                     (nOut > 0 ? "+".ptr : "".ptr));
            TryCopyStr(buf, tbuf.ptr, sz);
            nOut++;
        }
    }
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyActionMessageArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbMessageAction* act = void;
    uint all = void;
    char[32] tbuf = 0;

    act = &action.msg;
    all = cast(uint)(XkbSA_MessageOnPress | XkbSA_MessageOnRelease);
    TryCopyStr(buf, "report=", sz);
    if ((act.flags & all) == 0)
        TryCopyStr(buf, "none", sz);
    else if ((act.flags & all) == all)
        TryCopyStr(buf, "all", sz);
    else if (act.flags & XkbSA_MessageOnPress)
        TryCopyStr(buf, "KeyPress", sz);
    else
        TryCopyStr(buf, "KeyRelease", sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[0]=0x%02x", act.message[0]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[1]=0x%02x", act.message[1]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[2]=0x%02x", act.message[2]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[3]=0x%02x", act.message[3]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[4]=0x%02x", act.message[4]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[5]=0x%02x", act.message[5]);
    TryCopyStr(buf, tbuf.ptr, sz);
    return TRUE;
}

private Bool CopyRedirectKeyArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbRedirectKeyAction* act = void;
    char[32] tbuf = 0;
    char* tmp = void;
    uint kc = void;
    uint vmods = void, vmods_mask = void;

    act = &action.redirect;
    kc = act.new_key;
    vmods = mixin(XkbSARedirectVMods!("act"));
    vmods_mask = mixin(XkbSARedirectVModsMask!("act"));
    if (xkb && xkb.names && xkb.names.keys && (kc <= xkb.max_key_code) &&
        (xkb.names.keys[kc].name[0] != '\0')) {
        char* kn = void;

        kn = XkbKeyNameText(xkb.names.keys[kc].name.ptr, XkbXKBFile);
        snprintf(tbuf.ptr, tbuf.sizeof, "key=%s", kn);
    }
    else
        snprintf(tbuf.ptr, tbuf.sizeof, "key=%d", kc);
    TryCopyStr(buf, tbuf.ptr, sz);
    if ((act.mods_mask == 0) && (vmods_mask == 0))
        return TRUE;
    if ((act.mods_mask == XkbAllModifiersMask) &&
        (vmods_mask == XkbAllVirtualModsMask)) {
        tmp = XkbVModMaskText(xkb, act.mods, vmods, XkbXKBFile);
        TryCopyStr(buf, ",mods=", sz);
        TryCopyStr(buf, tmp, sz);
    }
    else {
        if ((act.mods_mask & act.mods) || (vmods_mask & vmods)) {
            tmp = XkbVModMaskText(xkb, act.mods_mask & act.mods,
                                  vmods_mask & vmods, XkbXKBFile);
            TryCopyStr(buf, ",mods= ", sz);
            TryCopyStr(buf, tmp, sz);
        }
        if ((act.mods_mask & (~act.mods)) || (vmods_mask & (~vmods))) {
            tmp = XkbVModMaskText(xkb, act.mods_mask & (~act.mods),
                                  vmods_mask & (~vmods), XkbXKBFile);
            TryCopyStr(buf, ",clearMods= ", sz);
            TryCopyStr(buf, tmp, sz);
        }
    }
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyDeviceBtnArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbDeviceBtnAction* act = void;
    char[32] tbuf = 0;

    act = &action.devbtn;
    snprintf(tbuf.ptr, tbuf.sizeof, "device= %d", act.device);
    TryCopyStr(buf, tbuf.ptr, sz);
    TryCopyStr(buf, ",button=", sz);
    snprintf(tbuf.ptr, tbuf.sizeof, "%d", act.button);
    TryCopyStr(buf, tbuf.ptr, sz);
    if (act.count > 0) {
        snprintf(tbuf.ptr, tbuf.sizeof, ",count=%d", act.count);
        TryCopyStr(buf, tbuf.ptr, sz);
    }
    if (action.type == XkbSA_LockDeviceBtn) {
        switch (act.flags & (XkbSA_LockNoUnlock | XkbSA_LockNoLock)) {
        case XkbSA_LockNoLock:
            TryCopyStr(buf, ",affect=unlock", sz);
            break;
        case XkbSA_LockNoUnlock:
            TryCopyStr(buf, ",affect=lock", sz);
            break;
        case XkbSA_LockNoUnlock | XkbSA_LockNoLock:
            TryCopyStr(buf, ",affect=neither", sz);
            break;
        default:
            TryCopyStr(buf, ",affect=both", sz);
            break;
        }
    }
    return TRUE;
}

 /*ARGSUSED*/ private Bool CopyOtherArgs(XkbDescPtr xkb, XkbAction* action, char* buf, int* sz)
{
    XkbAnyAction* act = void;
    char[32] tbuf = 0;

    act = &action.any;
    snprintf(tbuf.ptr, tbuf.sizeof, "type=0x%02x", act.type);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[0]=0x%02x", act.data[0]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[1]=0x%02x", act.data[1]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[2]=0x%02x", act.data[2]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[3]=0x%02x", act.data[3]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[4]=0x%02x", act.data[4]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[5]=0x%02x", act.data[5]);
    TryCopyStr(buf, tbuf.ptr, sz);
    snprintf(tbuf.ptr, tbuf.sizeof, ",data[6]=0x%02x", act.data[6]);
    TryCopyStr(buf, tbuf.ptr, sz);
    return TRUE;
}

alias actionCopy = Bool function(XkbDescPtr, XkbAction*, char*, int*);

private actionCopy[XkbSA_NumActions] copyActionArgs = [
    &CopyNoActionArgs /* NoAction     */ ,
    &CopyModActionArgs /* SetMods      */ ,
    &CopyModActionArgs /* LatchMods    */ ,
    &CopyModActionArgs /* LockMods     */ ,
    &CopyGroupActionArgs /* SetGroup     */ ,
    &CopyGroupActionArgs /* LatchGroup   */ ,
    &CopyGroupActionArgs /* LockGroup    */ ,
    &CopyMovePtrArgs /* MovePtr      */ ,
    &CopyPtrBtnArgs /* PtrBtn       */ ,
    &CopyPtrBtnArgs /* LockPtrBtn   */ ,
    &CopySetPtrDfltArgs /* SetPtrDflt   */ ,
    &CopyISOLockArgs /* ISOLock      */ ,
    &CopyNoActionArgs /* Terminate    */ ,
    &CopySwitchScreenArgs /* SwitchScreen */ ,
    &CopySetLockControlsArgs /* SetControls  */ ,
    &CopySetLockControlsArgs /* LockControls */ ,
    &CopyActionMessageArgs /* ActionMessage */ ,
    &CopyRedirectKeyArgs /* RedirectKey  */ ,
    &CopyDeviceBtnArgs /* DeviceBtn    */ ,
    &CopyDeviceBtnArgs           /* LockDeviceBtn */
];

enum	ACTION_SZ =	256;

char* XkbActionText(XkbDescPtr xkb, XkbAction* action, uint format)
{
    char[ACTION_SZ] buf = 0;
    int sz = void;

    if (format == XkbCFile) {
        snprintf(buf.ptr, buf.sizeof,
                 "{ %20s, { 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%02x } }",
                 XkbActionTypeText(action.type, XkbCFile),
                 action.any.data[0], action.any.data[1], action.any.data[2],
                 action.any.data[3], action.any.data[4], action.any.data[5],
                 action.any.data[6]);
    }
    else {
        snprintf(buf.ptr, buf.sizeof, "%s(",
                 XkbActionTypeText(action.type, XkbXKBFile));
        sz = cast(int)(ACTION_SZ - strlen(buf.ptr) + 2);       /* room for close paren and NULL */
        if (action.type < cast(uint) XkbSA_NumActions)
            (*copyActionArgs[action.type]) (xkb, action, buf.ptr, &sz);
        else
            CopyOtherArgs(xkb, action, buf.ptr, &sz);
        TryCopyStr(buf.ptr, ")", &sz);
    }
    return tbGetBufferString(buf.ptr);
}

char* XkbBehaviorText(XkbDescPtr xkb, XkbBehavior* behavior, uint format)
{
    char[256] buf = 0;

    if (format == XkbCFile) {
        if (behavior.type == XkbKB_Default)
            snprintf(buf.ptr, buf.sizeof, "{   0,    0 }");
        else
            snprintf(buf.ptr, buf.sizeof, "{ %3d, 0x%02x }", behavior.type,
                     behavior.data);
    }
    else {
        uint type = void, permanent = void;

        type = behavior.type & XkbKB_OpMask;
        permanent = ((behavior.type & XkbKB_Permanent) != 0);

        if (type == XkbKB_Lock) {
            snprintf(buf.ptr, buf.sizeof, "lock= %s",
                     (permanent ? "Permanent".ptr : "TRUE".ptr));
        }
        else if (type == XkbKB_RadioGroup) {
            int g = void;
            char* tmp = void;
            size_t tmpsize = void;

            g = ((behavior.data) & (~XkbKB_RGAllowNone)) + 1;
            if (XkbKB_RGAllowNone & behavior.data) {
                snprintf(buf.ptr, buf.sizeof, "allowNone,");
                tmp = &buf[strlen(buf.ptr)];
            }
            else
                tmp = buf.ptr;
            tmpsize = ((buf).ptr - (tmp - buf.ptr)).sizeof;
            if (permanent)
                snprintf(tmp, tmpsize, "permanentRadioGroup= %d", g);
            else
                snprintf(tmp, tmpsize, "radioGroup= %d", g);
        }
        else if ((type == XkbKB_Overlay1) || (type == XkbKB_Overlay2)) {
            int ndx = void, kc = void;
            char* kn = void;

            ndx = ((type == XkbKB_Overlay1) ? 1 : 2);
            kc = behavior.data;
            if ((xkb) && (xkb.names) && (xkb.names.keys))
                kn = XkbKeyNameText(xkb.names.keys[kc].name.ptr, XkbXKBFile);
            else {
                static char[8] tbuf = 0;

                snprintf(tbuf.ptr, tbuf.sizeof, "%d", kc);
                kn = tbuf.ptr;
            }
            if (permanent)
                snprintf(buf.ptr, buf.sizeof, "permanentOverlay%d= %s", ndx, kn);
            else
                snprintf(buf.ptr, buf.sizeof, "overlay%d= %s", ndx, kn);
        }
    }
    return tbGetBufferString(buf.ptr);
}

/***====================================================================***/

char* XkbIndentText(uint size)
{
    static char[32] buf = 0;
    int i = void;

    if (size > 31)
        size = 31;

    for (i = 0; i < size; i++) {
        buf[i] = ' ';
    }
    buf[size] = '\0';
    return buf.ptr;
}
