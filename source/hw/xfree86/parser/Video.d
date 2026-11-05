module Video;
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

private const(xf86ConfigSymTabRec)[5] VideoPortTab = [
    {ENDSUBSECTION, "endsubsection"},
    {IDENTIFIER, "identifier"},
    {OPTION, "option"},
    {-1, ""},
];

alias CLEANUP = xf86freeVideoPortList;

private void xf86freeVideoPortList(XF86ConfVideoPortPtr ptr)
{
    XF86ConfVideoPortPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.vp_identifier`));
        mixin(TestFree!(`ptr.vp_comment`));
        xf86optionListFree(ptr.vp_option_lst);
        prev = ptr;
        ptr = cast(_XF86ConfVideoPortRec*)ptr.list.next;
        free(prev);
    }
}

private XF86ConfVideoPortPtr xf86parseVideoPortSubSection()
{
    int has_ident = FALSE;
    int token = void;

    mixin(parsePrologue!("XF86ConfVideoPortPtr", "XF86ConfVideoPortRec"));

        while ((token = xf86getToken(VideoPortTab.ptr)) != ENDSUBSECTION) {
        switch (token) {
        case COMMENT:
            ptr.vp_comment = xf86addComment(ptr.vp_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.vp_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.vp_identifier = xf86_lex_val.str;
            has_ident = TRUE;
            break;
        case OPTION:
            ptr.vp_option_lst = xf86parseOption(ptr.vp_option_lst);
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
    printf("VideoPort subsection parsed\n");
}

    return ptr;
}

private const(xf86ConfigSymTabRec)[10] VideoAdaptorTab = [
    {ENDSECTION, "endsection"},
    {IDENTIFIER, "identifier"},
    {VENDOR, "vendorname"},
    {BOARD, "boardname"},
    {BUSID, "busid"},
    {DRIVER, "driver"},
    {OPTION, "option"},
    {SUBSECTION, "subsection"},
    {-1, ""},
];

alias CLEANUP = xf86freeVideoAdaptorList;

XF86ConfVideoAdaptorPtr xf86parseVideoAdaptorSection()
{
    int has_ident = FALSE;
    int token = void;

    mixin(parsePrologue!("XF86ConfVideoAdaptorPtr", "XF86ConfVideoAdaptorRec"));

        while ((token = xf86getToken(VideoAdaptorTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.va_comment = xf86addComment(ptr.va_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            ptr.va_identifier = xf86_lex_val.str;
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            has_ident = TRUE;
            break;
        case VENDOR:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Vendor"`));
            ptr.va_vendor = xf86_lex_val.str;
            break;
        case BOARD:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Board"`));
            ptr.va_board = xf86_lex_val.str;
            break;
        case BUSID:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "BusID"`));
            ptr.va_busid = xf86_lex_val.str;
            break;
        case DRIVER:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Driver"`));
            ptr.va_driver = xf86_lex_val.str;
            break;
        case OPTION:
            ptr.va_option_lst = xf86parseOption(ptr.va_option_lst);
            break;
        case SUBSECTION:
            if (xf86getSubToken(&(ptr.va_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "SubSection"`));
            {
                mixin(HANDLE_LIST!("va_port_lst", "&xf86parseVideoPortSubSection", "XF86ConfVideoPortPtr"));
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
    printf("VideoAdaptor section parsed\n");
}

    return ptr;
}

void xf86printVideoAdaptorSection(FILE* cf, XF86ConfVideoAdaptorPtr ptr)
{
    XF86ConfVideoPortPtr pptr = void;

    while (ptr) {
        fprintf(cf, "Section \"VideoAdaptor\"\n");
        if (ptr.va_comment)
            fprintf(cf, "%s", ptr.va_comment);
        if (ptr.va_identifier)
            fprintf(cf, "\tIdentifier  \"%s\"\n", ptr.va_identifier);
        if (ptr.va_vendor)
            fprintf(cf, "\tVendorName  \"%s\"\n", ptr.va_vendor);
        if (ptr.va_board)
            fprintf(cf, "\tBoardName   \"%s\"\n", ptr.va_board);
        if (ptr.va_busid)
            fprintf(cf, "\tBusID       \"%s\"\n", ptr.va_busid);
        if (ptr.va_driver)
            fprintf(cf, "\tDriver      \"%s\"\n", ptr.va_driver);
        xf86printOptionList(cf, ptr.va_option_lst, 1);
        for (pptr = ptr.va_port_lst; pptr; pptr = cast(_XF86ConfVideoPortRec*)pptr.list.next) {
            fprintf(cf, "\tSubSection \"VideoPort\"\n");
            if (pptr.vp_comment)
                fprintf(cf, "%s", pptr.vp_comment);
            if (pptr.vp_identifier)
                fprintf(cf, "\t\tIdentifier \"%s\"\n", pptr.vp_identifier);
            xf86printOptionList(cf, pptr.vp_option_lst, 2);
            fprintf(cf, "\tEndSubSection\n");
        }
        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfVideoAdaptorRec*)ptr.list.next;
    }

}

void xf86freeVideoAdaptorList(XF86ConfVideoAdaptorPtr ptr)
{
    XF86ConfVideoAdaptorPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.va_identifier`));
        mixin(TestFree!(`ptr.va_vendor`));
        mixin(TestFree!(`ptr.va_board`));
        mixin(TestFree!(`ptr.va_busid`));
        mixin(TestFree!(`ptr.va_driver`));
        mixin(TestFree!(`ptr.va_fwdref`));
        mixin(TestFree!(`ptr.va_comment`));
        xf86freeVideoPortList(ptr.va_port_lst);
        xf86optionListFree(ptr.va_option_lst);
        prev = ptr;
        ptr = cast(_XF86ConfVideoAdaptorRec*)ptr.list.next;
        free(prev);
    }
}

XF86ConfVideoAdaptorPtr xf86findVideoAdaptor(const(char)* ident, XF86ConfVideoAdaptorPtr p)
{
    while (p) {
        if (xf86nameCompare(ident, p.va_identifier) == 0)
            return p;

        p = cast(XF86ConfVideoAdaptorPtr)p.list.next;
    }
    return null;
}
