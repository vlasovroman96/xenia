module Pointer;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright (c) 1997  Metro Link Incorporated
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Metro Link shall not be
 * used in advertising or otherwise to promote the sale, use or other dealings
 * in this Software without prior written authorization from Metro Link.
 *
 */
/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
import build.xorg_config;

import include.xf86Parser;
import xf86tokens;
import Configint;
import os.xprintf;
import xf86Parser_priv;
import xf86tokens;
import Configint;
import core.stdc.string;
import include.optionstr;
import include.xf86Parser;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import include.misc;
import Flags;
import scan;
import core.stdc.string;
import externs.gnu;
import read;
import xf86Option;
import Input;
import Screen;
import Device;
import os.log;

private const(xf86ConfigSymTabRec)[19] PointerTab = [
    {PROTOCOL, "protocol"},
    {EMULATE3, "emulate3buttons"},
    {EM3TIMEOUT, "emulate3timeout"},
    {ENDSUBSECTION, "endsubsection"},
    {ENDSECTION, "endsection"},
    {PDEVICE, "device"},
    {PDEVICE, "port"},
    {BAUDRATE, "baudrate"},
    {SAMPLERATE, "samplerate"},
    {CLEARDTR, "cleardtr"},
    {CLEARRTS, "clearrts"},
    {CHORDMIDDLE, "chordmiddle"},
    {PRESOLUTION, "resolution"},
    {DEVICE_NAME, "devicename"},
    {ALWAYSCORE, "alwayscore"},
    {PBUTTONS, "buttons"},
    {ZAXISMAPPING, "zaxismapping"},
    {-1, ""},
];

private const(xf86ConfigSymTabRec)[4] ZMapTab = [
    {XAXIS, "x"},
    {YAXIS, "y"},
    {-1, ""},
];

alias CLEANUP = xf86freeInputList;

XF86ConfInputPtr xf86parsePointerSection()
{
    char* s = void;
    c_ulong val1 = void;
    int token = void;

    mixin(parsePrologue!("XF86ConfInputPtr", "XF86ConfInputRec"));

        while ((token = xf86getToken(PointerTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.inp_comment = xf86addComment(ptr.inp_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case PROTOCOL:
            if (xf86getSubToken(&(ptr.inp_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Protocol"`));
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Protocol"), xf86_lex_val.str);
            break;
        case PDEVICE:
            if (xf86getSubToken(&(ptr.inp_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Device"`));
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Device"), xf86_lex_val.str);
            break;
        case EMULATE3:
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Emulate3Buttons"),
                                                   null);
            break;
        case EM3TIMEOUT:
            if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER || xf86_lex_val.num < 0)
                mixin(ErrorP!(`POSITIVE_INT_MSG, "Emulate3Timeout"`));
            s = xf86uLongToString(xf86_lex_val.num);
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Emulate3Timeout"),
                                                   s);
            break;
        case CHORDMIDDLE:
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("ChordMiddle"), null);
            break;
        case PBUTTONS:
            if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER || xf86_lex_val.num < 0)
                mixin(ErrorP!(`POSITIVE_INT_MSG, "Buttons"`));
            s = xf86uLongToString(xf86_lex_val.num);
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Buttons"), s);
            break;
        case BAUDRATE:
            if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER || xf86_lex_val.num < 0)
                mixin(ErrorP!(`POSITIVE_INT_MSG, "BaudRate"`));
            s = xf86uLongToString(xf86_lex_val.num);
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("BaudRate"), s);
            break;
        case SAMPLERATE:
            if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER || xf86_lex_val.num < 0)
                mixin(ErrorP!(`POSITIVE_INT_MSG, "SampleRate"`));
            s = xf86uLongToString(xf86_lex_val.num);
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("SampleRate"), s);
            break;
        case PRESOLUTION:
            if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER || xf86_lex_val.num < 0)
                mixin(ErrorP!(`POSITIVE_INT_MSG, "Resolution"`));
            s = xf86uLongToString(xf86_lex_val.num);
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("Resolution"), s);
            break;
        case CLEARDTR:
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("ClearDTR"), null);
            break;
        case CLEARRTS:
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("ClearRTS"), null);
            break;
        case ZAXISMAPPING:
            switch (xf86getToken(ZMapTab.ptr)) {
            case NUMBER:
                if (xf86_lex_val.num < 0)
                    mixin(ErrorP!(`ZAXISMAPPING_MSG`));
                val1 = xf86_lex_val.num;
                if (xf86getSubToken(&(ptr.inp_comment)) != NUMBER ||
                    xf86_lex_val.num < 0) {
                    mixin(ErrorP!(`ZAXISMAPPING_MSG`));
                }
                if (asprintf(&s, "%lu %u", val1, xf86_lex_val.num) == -1)
                    s = null;
                break;
            case XAXIS:
                s = strdup("x");
                break;
            case YAXIS:
                s = strdup("y");
                break;
            default:
                mixin(ErrorP!(`ZAXISMAPPING_MSG`));
                break;
            }
            ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                                   strdup("ZAxisMapping"), s);
            break;
        case ALWAYSCORE:
            break;
        case EOF_TOKEN:
            mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
            break;
        default:
            mixin(ErrorP!(`INVALID_KEYWORD_MSG, xf86tokenString()`));
            break;
        }
    }

    ptr.inp_identifier = strdup(CONF_IMPLICIT_POINTER);
    ptr.inp_driver = strdup("mouse");
    ptr.inp_option_lst = xf86addNewOption(ptr.inp_option_lst,
                                           strdup("CorePointer"), null);

version (DEBUG) {
    printf("Pointer section parsed\n");
}

    return ptr;
}

