module Vendor;
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

import hw.xfree86.parser.xf86Parser;
import xf86tokens;
import Configint;
import xf86Parser_priv;
import xf86tokens;
import Configint;
import core.stdc.string;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import common.misc;
import hw.xfree86.parser.Flags;
import scan;
import core.stdc.string;
import externs.gnu;
import read;
import hw.xfree86.common.xf86Option;
import Input;
import Screen;
import Device;
import os.log;
import Video;
import Monitor;


private const(xf86ConfigSymTabRec)[5] VendorSubTab = [
    {ENDSUBSECTION, "endsubsection"},
    {IDENTIFIER, "identifier"},
    {OPTION, "option"},
    {-1, ""},
];

private void xf86freeVendorSubList(XF86ConfVendSubPtr ptr)
{
    XF86ConfVendSubPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.vs_identifier`));
        mixin(TestFree!(`ptr.vs_name`));
        mixin(TestFree!(`ptr.vs_comment`));
        xf86optionListFree(ptr.vs_option_lst);
        prev = ptr;
        ptr = cast(_XF86ConfVendSubRec*)ptr.list.next;
        free(prev);
    }
}

alias CLEANUP = xf86freeVendorSubList;

private XF86ConfVendSubPtr xf86parseVendorSubSection()
{
    int has_ident = FALSE;
    int token = void;

    mixin(parsePrologue!("XF86ConfVendSubPtr", "XF86ConfVendSubRec"));

        while ((token = xf86getToken(VendorSubTab.ptr)) != ENDSUBSECTION) {
        switch (token) {
        case COMMENT:
            ptr.vs_comment = xf86addComment(ptr.vs_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.vs_comment)))
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.vs_identifier = xf86_lex_val.str;
            has_ident = TRUE;
            break;
        case OPTION:
            ptr.vs_option_lst = xf86parseOption(ptr.vs_option_lst);
            break;

        case EOF_TOKEN:
            mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
            break;
        default:
            mixin(ErrorP!(`INVALID_KEYWORD_MSG, xf86tokenString()`));
            break;
        }
    }

version (DEBUG) {
    printf("Vendor subsection parsed\n");
}

    return ptr;
}

private const(xf86ConfigSymTabRec)[6] VendorTab = [
    {ENDSECTION, "endsection"},
    {IDENTIFIER, "identifier"},
    {OPTION, "option"},
    {SUBSECTION, "subsection"},
    {-1, ""},
];

alias CLEANUP = xf86freeVendorList;

XF86ConfVendorPtr xf86parseVendorSection()
{
    int has_ident = FALSE;
    int token = void;

    mixin(parsePrologue!("XF86ConfVendorPtr", "XF86ConfVendorRec"));

        while ((token = xf86getToken(VendorTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.vnd_comment = xf86addComment(ptr.vnd_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.vnd_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.vnd_identifier = xf86_lex_val.str;
            has_ident = TRUE;
            break;
        case OPTION:
            ptr.vnd_option_lst = xf86parseOption(ptr.vnd_option_lst);
            break;
        case SUBSECTION:
            if (xf86getSubToken(&(ptr.vnd_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "SubSection"`));
            {
                mixin(HANDLE_LIST!("vnd_sub_lst", "&xf86parseVendorSubSection", "XF86ConfVendSubPtr"));
            }
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
    printf("Vendor section parsed\n");
}

    return ptr;
}

void xf86printVendorSection(FILE* cf, XF86ConfVendorPtr ptr)
{
    XF86ConfVendSubPtr pptr = void;

    while (ptr) {
        fprintf(cf, "Section \"Vendor\"\n");
        if (ptr.vnd_comment)
            fprintf(cf, "%s", ptr.vnd_comment);
        if (ptr.vnd_identifier)
            fprintf(cf, "\tIdentifier     \"%s\"\n", ptr.vnd_identifier);

        xf86printOptionList(cf, ptr.vnd_option_lst, 1);
        for (pptr = ptr.vnd_sub_lst; pptr; pptr = cast(_XF86ConfVendSubRec*)pptr.list.next) {
            fprintf(cf, "\tSubSection \"Vendor\"\n");
            if (pptr.vs_comment)
                fprintf(cf, "%s", pptr.vs_comment);
            if (pptr.vs_identifier)
                fprintf(cf, "\t\tIdentifier \"%s\"\n", pptr.vs_identifier);
            xf86printOptionList(cf, pptr.vs_option_lst, 2);
            fprintf(cf, "\tEndSubSection\n");
        }
        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfVendorRec*)ptr.list.next;
    }
}

void xf86freeVendorList(XF86ConfVendorPtr p)
{
    if (p is null)
        return;
    xf86freeVendorSubList(p.vnd_sub_lst);
    mixin(TestFree!(`p.vnd_identifier`));
    mixin(TestFree!(`p.vnd_comment`));
    xf86optionListFree(p.vnd_option_lst);
    free(p);
}
