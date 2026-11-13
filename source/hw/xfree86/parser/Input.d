module Input;
@nogc nothrow:
extern(C): __gshared:
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

import os.os;
import hw.xfree86.parser.xf86Parser;
import xf86tokens;
import Configint;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import hw.xfree86.parser.Flags;
import scan;
import core.stdc.string;
import externs.gnu;
import read;


private const(xf86ConfigSymTabRec)[6] InputTab = [
    {ENDSECTION, "endsection"},
    {IDENTIFIER, "identifier"},
    {OPTION, "option"},
    {DRIVER, "driver"},
    {-1, ""},
];

alias CLEANUP = xf86freeInputList;

XF86ConfInputPtr xf86parseInputSection()
{
    int has_ident = FALSE;
    int token = void;

    mixin(parsePrologue!("XF86ConfInputPtr", "XF86ConfInputRec"));

        while ((token = xf86getToken(InputTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.inp_comment = xf86addComment(ptr.inp_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.inp_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.inp_identifier = xf86_lex_val.str;
            has_ident = TRUE;
            break;
        case DRIVER:
            if (xf86getSubToken(&(ptr.inp_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Driver"`));
            if (strcmp(xf86_lex_val.str, "keyboard") == 0) {
                ptr.inp_driver = strdup("kbd");
                free(xf86_lex_val.str);
            }
            else
                ptr.inp_driver = xf86_lex_val.str;
            break;
        case OPTION:
            ptr.inp_option_lst = xf86parseOption(ptr.inp_option_lst);
            break;
        case EOF_TOKEN:
            mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
            break;
        default:
            mixin(ErrorP!(`INVALID_KEYWORD_MSG, xf86tokenString()`));
            break;
        }
    }

    if (!has_ident)
        mixin(ErrorP!(`NO_IDENT_MSG`));

version (DEBUG) {
    printf("InputDevice section parsed\n");
}

    return ptr;
}

void xf86printInputSection(FILE* cf, XF86ConfInputPtr ptr)
{
    while (ptr) {
        fprintf(cf, "Section \"InputDevice\"\n");
        if (ptr.inp_comment)
            fprintf(cf, "%s", ptr.inp_comment);
        if (ptr.inp_identifier)
            fprintf(cf, "\tIdentifier  \"%s\"\n", ptr.inp_identifier);
        if (ptr.inp_driver)
            fprintf(cf, "\tDriver      \"%s\"\n", ptr.inp_driver);
        xf86printOptionList(cf, ptr.inp_option_lst, 1);
        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfInputRec*)ptr.list.next;
    }
}

void xf86freeInputList(XF86ConfInputPtr ptr)
{
    XF86ConfInputPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.inp_identifier`));
        mixin(TestFree!(`ptr.inp_driver`));
        mixin(TestFree!(`ptr.inp_comment`));
        xf86optionListFree(ptr.inp_option_lst);

        prev = ptr;
        ptr = cast(_XF86ConfInputRec*)ptr.list.next;
        free(prev);
    }
}

int xf86validateInput(XF86ConfigPtr p)
{
    XF86ConfInputPtr input = p.conf_input_lst;

    while (input) {
        if (!input.inp_driver) {
            xf86validationError(UNDEFINED_INPUTDRIVER_MSG,
                                input.inp_identifier);
            return FALSE;
        }
        input = cast(_XF86ConfInputRec*)input.list.next;
    }
    return TRUE;
}

XF86ConfInputPtr xf86findInput(const(char)* ident, XF86ConfInputPtr p)
{
    while (p) {
        if (xf86nameCompare(ident, p.inp_identifier) == 0)
            return p;

        p = cast(_XF86ConfInputRec*)p.list.next;
    }
    return null;
}

XF86ConfInputPtr xf86findInputByDriver(const(char)* driver, XF86ConfInputPtr p)
{
    while (p) {
        if (xf86nameCompare(driver, p.inp_driver) == 0)
            return p;

        p = cast(_XF86ConfInputRec*)p.list.next;
    }
    return null;
}
