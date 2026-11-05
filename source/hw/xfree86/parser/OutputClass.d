module OutputClass;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2014 NVIDIA Corporation. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
import build.xorg_config;

import os.fmt;

import os.os;
import xf86Parser_priv;
import xf86tokens;
import Configint;
import xf86Parser_priv;
import xf86tokens;
import Configint;
import core.stdc.string;
import hw.xfree86.parser.xf86Parser;
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

private const(xf86ConfigSymTabRec)[10] OutputClassTab = [
    {ENDSECTION, "endsection"},
    {IDENTIFIER, "identifier"},
    {DRIVER, "driver"},
    {MODULE, "module"},
    {MODULEPATH, "modulepath"},
    {OPTION, "option"},
    {MATCH_DRIVER, "matchdriver"},
    {MATCH_LAYOUT, "matchlayout"},
    {-1, ""},
];

private void xf86freeOutputClassList(XF86ConfOutputClassPtr ptr)
{
    XF86ConfOutputClassPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.identifier`));
        mixin(TestFree!(`ptr.comment`));
        mixin(TestFree!(`ptr.driver`));
        mixin(TestFree!(`ptr.modules`));
        mixin(TestFree!(`ptr.modulepath`));

        xf86freeMatchGroupList(&ptr.match_driver);
        xf86freeMatchGroupList(&ptr.match_layout);

        xf86optionListFree(ptr.option_lst);

        prev = ptr;
        ptr = cast(_XF86ConfOutputClassRec*)ptr.list.next;
        free(prev);
    }
}

alias CLEANUP = xf86freeOutputClassList;

XF86ConfOutputClassPtr xf86parseOutputClassSection()
{
    int has_ident = FALSE;
    int token = void;
    xf86MatchGroup* group = void;

    mixin(parsePrologue!("XF86ConfOutputClassPtr", "XF86ConfOutputClassRec"));

    /* MatchGroup and MatchLayout lists are zeroed by parsePrologue(),
     * which is equivalent to xorg_list_init() */

    while ((token = xf86getToken(OutputClassTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.comment = xf86addComment(ptr.comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == TRUE)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.identifier = xf86_lex_val.str;
            has_ident = TRUE;
            break;
        case DRIVER:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Driver"`));
            else
                ptr.driver = xf86_lex_val.str;
            break;
        case MODULE:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Module"`));
            if (ptr.modules) {
                char* path = void;
                XNFasprintf(&path, "%s,%s", ptr.modules, xf86_lex_val.str);
                free(xf86_lex_val.str);
                free(ptr.modules);
                ptr.modules = path;
            } else {
                ptr.modules = xf86_lex_val.str;
            }
            break;
        case MODULEPATH:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "ModulePath"`));
            if (ptr.modulepath) {
                char* path = null;
                if (asprintf(&path, "%s,%s", ptr.modulepath, xf86_lex_val.str) == -1)
                    FatalError("xf86parseOutputClassSection() malloc failed\n");
                free(xf86_lex_val.str);
                free(ptr.modulepath);
                ptr.modulepath = path;
            } else {
                ptr.modulepath = xf86_lex_val.str;
            }
            break;
        case OPTION:
            ptr.option_lst = xf86parseOption(ptr.option_lst);
            break;
        case MATCH_DRIVER:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchDriver"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT, FALSE);
                if (group)
                    xorg_list_add(&group.entry, &ptr.match_driver);
                free(xf86_lex_val.str);
            }
            break;
        case MATCH_LAYOUT:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchLayout"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT, FALSE);
                if (group)
                    xorg_list_add(&group.entry, &ptr.match_layout);
                free(xf86_lex_val.str);
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
    printf("OutputClass section parsed\n");
}

    return ptr;
}

void xf86printOutputClassSection(FILE* cf, XF86ConfOutputClassPtr ptr)
{
    xf86MatchGroup* group = void;
    xf86MatchPattern* pattern = void;
    Bool not_first = void;

    while (ptr) {
        fprintf(cf, "Section \"OutputClass\"\n");
        if (ptr.comment)
            fprintf(cf, "%s", ptr.comment);
        if (ptr.identifier)
            fprintf(cf, "\tIdentifier      \"%s\"\n", ptr.identifier);
        if (ptr.driver)
            fprintf(cf, "\tDriver          \"%s\"\n", ptr.driver);
        if (ptr.modules)
            fprintf(cf, "\tModule          \"%s\"\n", ptr.modules);
        if (ptr.modulepath)
            fprintf(cf, "\tModulePath      \"%s\"\n", ptr.modulepath);

        mixin(xorg_list_for_each_entry!("group", "&ptr.match_driver", "entry", q{
            fprintf(cf, "\tMatchDriver     \"");
            not_first = FALSE;
            mixin(xorg_list_for_each_entry!("pattern", "&group.patterns", "entry", q{
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }));
            fprintf(cf, "\"\n");
        }));

        mixin(xorg_list_for_each_entry!("group", "&ptr.match_layout", "entry", q{
            fprintf(cf, "\tMatchLayout     \"");
            not_first = FALSE;
            mixin(xorg_list_for_each_entry!("pattern", "&group.patterns", "entry", q{
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }));
            fprintf(cf, "\"\n");
        }));

        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfOutputClassRec*)ptr.list.next;
    }
}
