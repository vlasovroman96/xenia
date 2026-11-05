module Module;
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

import core.stdc.assert_;

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
import Input;
import Screen;
import Device;


private const(xf86ConfigSymTabRec)[4] SubModuleTab = [
    {ENDSUBSECTION, "endsubsection"},
    {OPTION, "option"},
    {-1, ""},
];

private const(xf86ConfigSymTabRec)[7] ModuleTab = [
    {ENDSECTION, "endsection"},
    {LOAD, "load"},
    {DISABLE, "disable"},
    {LOAD_DRIVER, "loaddriver"},
    {SUBSECTION, "subsection"},
    {-1, ""},
];

alias CLEANUP = xf86freeModules;

private XF86LoadPtr xf86parseModuleSubSection(XF86LoadPtr head, char* name)
{
    int token = void;

    mixin(parsePrologue!("XF86LoadPtr", "XF86LoadRec"));

        ptr.load_name = name;
    ptr.load_type = XF86_LOAD_MODULE;
    ptr.ignore = 0;
    ptr.load_opt = null;
    ptr.list.next = null;

    while ((token = xf86getToken(SubModuleTab.ptr)) != ENDSUBSECTION) {
        switch (token) {
        case COMMENT:
            ptr.load_comment = xf86addComment(ptr.load_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case OPTION:
            ptr.load_opt = xf86parseOption(ptr.load_opt);
            break;
        case EOF_TOKEN:
            xf86parseError(UNEXPECTED_EOF_MSG);
            free(ptr);
            return null;
        default:
            xf86parseError(INVALID_KEYWORD_MSG, xf86tokenString());
            free(ptr);
            return null;
            break;
        }

    }

    return (cast(XF86LoadPtr) xf86addListItem(cast(glp) head, cast(glp) ptr));
}

XF86ConfModulePtr xf86parseModuleSection(XF86ConfModulePtr ptr)
{
    int token = void;

    if (ptr is null)
    {
        if((ptr=cast(XF86ConfModuleRec*) calloc(1, XF86ConfModuleRec.sizeof)) is null)
        {
            return null;
        }
    }

    while ((token = xf86getToken(ModuleTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.mod_comment = xf86addComment(ptr.mod_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case LOAD:
            if (xf86getSubToken(&(ptr.mod_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Load"`));
            ptr.mod_load_lst =
                xf86addNewLoadDirective(ptr.mod_load_lst, xf86_lex_val.str,
                                        XF86_LOAD_MODULE, null);
            break;
        case DISABLE:
            if (xf86getSubToken(&(ptr.mod_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Disable"`));
            ptr.mod_disable_lst =
                xf86addNewLoadDirective(ptr.mod_disable_lst, xf86_lex_val.str,
                                        XF86_DISABLE_MODULE, null);
            break;
        case LOAD_DRIVER:
            if (xf86getSubToken(&(ptr.mod_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "LoadDriver"`));
            ptr.mod_load_lst =
                xf86addNewLoadDirective(ptr.mod_load_lst, xf86_lex_val.str,
                                        XF86_LOAD_DRIVER, null);
            break;
        case SUBSECTION:
            if (xf86getSubToken(&(ptr.mod_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "SubSection"`));
            ptr.mod_load_lst =
                xf86parseModuleSubSection(ptr.mod_load_lst, xf86_lex_val.str);
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
    printf("Module section parsed\n");
}

    return ptr;
}

void xf86printModuleSection(FILE* cf, XF86ConfModulePtr ptr)
{
    XF86LoadPtr lptr = void;

    if (ptr is null)
        return;

    if (ptr.mod_comment)
        fprintf(cf, "%s", ptr.mod_comment);
    for (lptr = ptr.mod_load_lst; lptr; lptr = cast(_XF86LoadRec*)lptr.list.next) {
        switch (lptr.load_type) {
        case XF86_LOAD_MODULE:
            if (lptr.load_opt is null) {
                fprintf(cf, "\tLoad  \"%s\"", lptr.load_name);
                if (lptr.load_comment)
                    fprintf(cf, "%s", lptr.load_comment);
                else
                    fputc('\n', cf);
            }
            else {
                fprintf(cf, "\tSubSection \"%s\"\n", lptr.load_name);
                if (lptr.load_comment)
                    fprintf(cf, "%s", lptr.load_comment);
                xf86printOptionList(cf, lptr.load_opt, 2);
                fprintf(cf, "\tEndSubSection\n");
            }
            break;
        case XF86_LOAD_DRIVER:
            fprintf(cf, "\tLoadDriver  \"%s\"", lptr.load_name);
            if (lptr.load_comment)
                fprintf(cf, "%s", lptr.load_comment);
            else
                fputc('\n', cf);
            break;
// version (none) {
        default:
            fprintf(cf, "#\tUnknown type  \"%s\"\n", lptr.load_name);
            break;
// }
        }
    }
}

XF86LoadPtr xf86addNewLoadDirective(XF86LoadPtr head, const(char)* name, int type, XF86OptionPtr opts)
{
    XF86LoadPtr new_ = void;
    int token = void;

    new_ = cast(XF86LoadRec*) calloc(1, XF86LoadRec.sizeof);
    assert(new_);
    new_.load_name = name;
    new_.load_type = type;
    new_.load_opt = opts;
    new_.ignore = 0;
    new_.list.next = null;

    if ((token = xf86getToken(null)) == COMMENT) {
        new_.load_comment = xf86addComment(new_.load_comment, xf86_lex_val.str);
        free(xf86_lex_val.str);
        xf86_lex_val.str = null;
    } else {
        xf86unGetToken(token);
    }

    return (cast(XF86LoadPtr) xf86addListItem(cast(glp) head, cast(glp) new_));
}

void xf86freeModules(XF86ConfModulePtr ptr)
{
    XF86LoadPtr lptr = void;
    XF86LoadPtr prev = void;

    if (ptr is null)
        return;
    lptr = ptr.mod_load_lst;
    while (lptr) {
        mixin(TestFree!(`lptr.load_name`));
        mixin(TestFree!(`lptr.load_comment`));
        prev = lptr;
        lptr = cast(_XF86LoadRec*)lptr.list.next;
        free(prev);
    }
    lptr = ptr.mod_disable_lst;
    while (lptr) {
        mixin(TestFree!(`lptr.load_name`));
        mixin(TestFree!(`lptr.load_comment`));
        prev = lptr;
        lptr = cast(_XF86LoadRec*)lptr.list.next;
        free(prev);
    }
    mixin(TestFree!(`ptr.mod_comment`));
    free(ptr);
}
