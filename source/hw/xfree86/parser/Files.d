module Files;
@nogc nothrow:
extern(C): __gshared:
/*
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

import x11.Xos;
import include.xf86Parser;
import xf86tokens;
import Configint;
import include.xf86Parser;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import include.misc;
import scan;
import core.stdc.string;
import externs.gnu;

private const(xf86ConfigSymTabRec)[9] FilesTab = [
    {ENDSECTION, "endsection"},
    {FONTPATH, "fontpath"},
    {MODULEPATH, "modulepath"},
    {LOGFILEPATH, "logfile"},
    {XKBDIR, "xkbdir"},
    /* Obsolete keywords that aren't used but shouldn't cause errors: */
    {OBSOLETE_TOKEN, "rgbpath"},
    {OBSOLETE_TOKEN, "inputdevices"},
    {-1, ""},
];

alias CLEANUP = xf86freeFiles;

XF86ConfFilesPtr xf86parseFilesSection(XF86ConfFilesPtr ptr)
{
    int i = void, j = void;
    int k = void, l = void;
    char* str = void;
    int token = void;

    if (ptr is null)
    {
        if((ptr=cast(XF86ConfFilesRec*) calloc(1, XF86ConfFilesRec.sizeof)) is null)
        {
            return null;
        }
    }

    while ((token = xf86getToken(FilesTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.file_comment = xf86addComment(ptr.file_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case FONTPATH:
            if (xf86getSubToken(&(ptr.file_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "FontPath"`));
            j = FALSE;
            str = xf86_lex_val.str;
            if (ptr.file_fontpath is null) {
                ptr.file_fontpath = cast(char*)calloc(1, 1);
                i = cast(int)(strlen(str) + 1);
            }
            else {
                i = cast(int)(strlen(ptr.file_fontpath) + strlen(str) + 1);
                if (ptr.file_fontpath[strlen(ptr.file_fontpath) - 1] != ',') {
                    i++;
                    j = TRUE;
                }
            }
            ptr.file_fontpath = cast(char*)realloc(ptr.file_fontpath, i);
            assert(ptr.file_fontpath);
            if (j)
                strcat(ptr.file_fontpath, ",");
            strcat(ptr.file_fontpath, str);
            free(xf86_lex_val.str);
            break;
        case MODULEPATH:
            if (xf86getSubToken(&(ptr.file_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "ModulePath"`));
            l = FALSE;
            str = xf86_lex_val.str;
            if (ptr.file_modulepath is null) {
                ptr.file_modulepath = cast(char*)calloc(1, 1);
                assert(ptr.file_modulepath);
                ptr.file_modulepath[0] = '\0';
                k = cast(int)(strlen(str) + 1);
            }
            else {
                k = cast(int)(strlen(ptr.file_modulepath) + strlen(str) + 1);
                if (ptr.file_modulepath[strlen(ptr.file_modulepath) - 1] !=
                    ',') {
                    k++;
                    l = TRUE;
                }
            }
            ptr.file_modulepath = cast(char*)realloc(ptr.file_modulepath, k);
            assert(ptr.file_modulepath);
            if (l)
                strcat(ptr.file_modulepath, ",");

            strcat(ptr.file_modulepath, str);
            free(xf86_lex_val.str);
            break;
        case LOGFILEPATH:
            if (xf86getSubToken(&(ptr.file_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "LogFile"`));
            ptr.file_logfile = xf86_lex_val.str;
            break;
        case XKBDIR:
            if (xf86getSubToken(&(ptr.file_xkbdir)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "XkbDir"`));
            ptr.file_xkbdir = xf86_lex_val.str;
            break;
        case EOF_TOKEN:
            mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
            break;
        case OBSOLETE_TOKEN:
            xf86parseError(OBSOLETE_MSG, xf86tokenString());
            xf86getSubToken(&(ptr.file_comment));
            break;
        default:
            mixin(ErrorP!(`INVALID_KEYWORD_MSG, xf86tokenString()`));
            break;
        }
    }

version (DEBUG) {
    printf("File section parsed\n");
}

    return ptr;
}

void xf86printFileSection(FILE* cf, XF86ConfFilesPtr ptr)
{
    char* p = void, s = void;

    if (ptr is null)
        return;

    if (ptr.file_comment)
        fprintf(cf, "%s", ptr.file_comment);
    if (ptr.file_logfile)
        fprintf(cf, "\tLogFile      \"%s\"\n", ptr.file_logfile);
    if (ptr.file_modulepath) {
        s = ptr.file_modulepath;
        p = index(s, ',');
        while (p) {
            *p = '\000';
            fprintf(cf, "\tModulePath   \"%s\"\n", s);
            *p = ',';
            s = p;
            s++;
            p = index(s, ',');
        }
        fprintf(cf, "\tModulePath   \"%s\"\n", s);
    }
    if (ptr.file_fontpath) {
        s = ptr.file_fontpath;
        p = index(s, ',');
        while (p) {
            *p = '\000';
            fprintf(cf, "\tFontPath     \"%s\"\n", s);
            *p = ',';
            s = p;
            s++;
            p = index(s, ',');
        }
        fprintf(cf, "\tFontPath     \"%s\"\n", s);
    }
    if (ptr.file_xkbdir)
        fprintf(cf, "\tXkbDir		\"%s\"\n", ptr.file_xkbdir);
}

void xf86freeFiles(XF86ConfFilesPtr p)
{
    if (p is null)
        return;

    mixin(TestFree!(`p.file_logfile`));
    mixin(TestFree!(`p.file_modulepath`));
    mixin(TestFree!(`p.file_fontpath`));
    mixin(TestFree!(`p.file_comment`));
    mixin(TestFree!(`p.file_xkbdir`));

    free(p);
}
