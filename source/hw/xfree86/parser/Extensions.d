module Extensions;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2004 Red Hat Inc., Raleigh, North Carolina.
 *
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation on the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NON-INFRINGEMENT.  IN NO EVENT SHALL RED HAT AND/OR THEIR SUPPLIERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/*
 * Authors:
 *   Kevin E. Martin <kem@redhat.com>
 *
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


private const(xf86ConfigSymTabRec)[4] ExtensionsTab = [
    {ENDSECTION, "endsection"},
    {OPTION, "option"},
    {-1, ""},
];

alias CLEANUP = xf86freeExtensions;

XF86ConfExtensionsPtr xf86parseExtensionsSection()
{
    int token = void;

    mixin(parsePrologue!("XF86ConfExtensionsPtr", "XF86ConfExtensionsRec"));

    while ((token = xf86getToken(ExtensionsTab.ptr)) != ENDSECTION) {
        switch (token) {
        case OPTION:
            ptr.ext_option_lst = xf86parseOption(ptr.ext_option_lst);
            break;
        case EOF_TOKEN:
            mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
            break;
        case COMMENT:
            ptr.extensions_comment =
                xf86addComment(ptr.extensions_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        default:
            mixin(ErrorP!(`INVALID_KEYWORD_MSG, xf86tokenString()`));
            break;
        }
    }

version (DEBUG) {
    ErrorF("Extensions section parsed\n");
}

    return ptr;
}

void xf86printExtensionsSection(FILE* cf, XF86ConfExtensionsPtr ptr)
{
    XF86OptionPtr p = void;

    if (ptr is null || ptr.ext_option_lst is null)
        return;

    p = ptr.ext_option_lst;
    fprintf(cf, "Section \"Extensions\"\n");
    if (ptr.extensions_comment)
        fprintf(cf, "%s", ptr.extensions_comment);
    xf86printOptionList(cf, p, 1);
    fprintf(cf, "EndSection\n\n");
}

void xf86freeExtensions(XF86ConfExtensionsPtr ptr)
{
    if (ptr is null)
        return;

    xf86optionListFree(ptr.ext_option_lst);
    mixin(TestFree!(`ptr.extensions_comment`));
    free(ptr);
}
