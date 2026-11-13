module InputClass;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2009 Dan Nicholson
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

import core.stdc.string;

import os.fmt;

import os.os;
import xf86Parser_priv;
import xf86tokens;
import Configint;
import hw.xfree86.parser.xf86Parser;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import hw.xfree86.parser.Flags;
import scan;
import core.stdc.string;
import externs.gnu;
import read;

private const(xf86ConfigSymTabRec)[31] InputClassTab = [
    {ENDSECTION, "endsection"},
    {IDENTIFIER, "identifier"},
    {OPTION, "option"},
    {DRIVER, "driver"},
    {MATCH_PRODUCT, "matchproduct"},
    {MATCH_VENDOR, "matchvendor"},
    {MATCH_DEVICE_PATH, "matchdevicepath"},
    {MATCH_OS, "matchos"},
    {MATCH_PNPID, "matchpnpid"},
    {MATCH_USBID, "matchusbid"},
    {MATCH_DRIVER, "matchdriver"},
    {MATCH_TAG, "matchtag"},
    {MATCH_LAYOUT, "matchlayout"},
    {MATCH_IS_KEYBOARD, "matchiskeyboard"},
    {MATCH_IS_POINTER, "matchispointer"},
    {MATCH_IS_JOYSTICK, "matchisjoystick"},
    {MATCH_IS_TABLET, "matchistablet"},
    {MATCH_IS_TABLET_PAD, "matchistabletpad"},
    {MATCH_IS_TOUCHPAD, "matchistouchpad"},
    {MATCH_IS_TOUCHSCREEN, "matchistouchscreen"},
    {NOMATCH_PRODUCT, "nomatchproduct"},
    {NOMATCH_VENDOR, "nomatchvendor"},
    {NOMATCH_DEVICE_PATH, "nomatchdevicepath"},
    {NOMATCH_OS, "nomatchos"},
    {NOMATCH_PNPID, "nomatchpnpid"},
    {NOMATCH_USBID, "nomatchusbid"},
    {NOMATCH_DRIVER, "nomatchdriver"},
    {NOMATCH_TAG, "nomatchtag"},
    {NOMATCH_LAYOUT, "nomatchlayout"},
    {-1, ""},
];

private void xf86freeInputClassList(XF86ConfInputClassPtr ptr)
{
    XF86ConfInputClassPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.identifier`));
        mixin(TestFree!(`ptr.driver`));

        xf86freeMatchGroupList(&ptr.match_product);
        xf86freeMatchGroupList(&ptr.match_vendor);
        xf86freeMatchGroupList(&ptr.match_device);
        xf86freeMatchGroupList(&ptr.match_os);
        xf86freeMatchGroupList(&ptr.match_pnpid);
        xf86freeMatchGroupList(&ptr.match_usbid);
        xf86freeMatchGroupList(&ptr.match_driver);
        xf86freeMatchGroupList(&ptr.match_tag);
        xf86freeMatchGroupList(&ptr.match_layout);

        mixin(TestFree!(`ptr.comment`));
        xf86optionListFree(ptr.option_lst);

        prev = ptr;
        ptr = cast(_XF86ConfInputClassRec*)ptr.list.next;
        free(prev);
    }
}

alias CLEANUP = xf86freeInputClassList;

XF86ConfInputClassPtr xf86parseInputClassSection()
{
    int has_ident = FALSE;
    int token = void;
    Bool negated = void;
    xf86MatchGroup* group = void;

    mixin(parsePrologue!("XF86ConfInputClassPtr", "XF86ConfInputClassRec"));

    /* Initialize MatchGroup lists */
    ptr.match_product.initList();
    ptr.match_vendor.initList();
    ptr.match_device.initList();
    ptr.match_os.initList();
    ptr.match_pnpid.initList();
    ptr.match_usbid.initList();
    ptr.match_driver.initList();
    ptr.match_tag.initList();
    ptr.match_layout.initList();

    while ((token = xf86getToken(InputClassTab.ptr)) != ENDSECTION) {
        negated = FALSE;

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
            if (strcmp(xf86_lex_val.str, "keyboard") == 0) {
                ptr.driver = strdup("kbd");
                free(xf86_lex_val.str);
            }
            else
                ptr.driver = xf86_lex_val.str;
            break;
        case OPTION:
            ptr.option_lst = xf86parseOption(ptr.option_lst);
            break;
        case NOMATCH_PRODUCT:
            negated = TRUE;
            goto case;
            /* fallthrough */
        case MATCH_PRODUCT:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchProduct"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_AS_SUBSTRING, negated);
                if (group)
                    ptr.match_product.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_VENDOR:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_VENDOR:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchVendor"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_AS_SUBSTRING, negated);
                if (group)
                    ptr.match_vendor.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_DEVICE_PATH:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_DEVICE_PATH:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchDevicePath"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_AS_PATHNAME, negated);
                if (group)
                    ptr.match_device.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_OS:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_OS:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchOS"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT_NOCASE, negated);
                if (group)
                    ptr.match_os.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_PNPID:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_PNPID:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchPnPID"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_AS_FILENAME, negated);
                if (group)
                    ptr.match_pnpid.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_USBID:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_USBID:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchUSBID"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_AS_FILENAME, negated);
                if (group)
                    ptr.match_usbid.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_DRIVER:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_DRIVER:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchDriver"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT, negated);
                if (group)
                    ptr.match_driver.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_TAG:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_TAG:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchTag"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT, negated);
                if (group)
                    ptr.match_tag.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case NOMATCH_LAYOUT:
            negated = TRUE;
            /* fallthrough */
            goto case;
        case MATCH_LAYOUT:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchLayout"`));
            else {
                group = xf86createMatchGroup(xf86_lex_val.str, MATCH_EXACT, negated);
                if (group)
                    ptr.match_layout.addListNext(&group.entry);
                free(xf86_lex_val.str);
            }
            break;
        case MATCH_IS_KEYBOARD:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsKeyboard"`));
            ptr.is_keyboard.set = xf86getBoolValue(&ptr.is_keyboard.val,
                                                    xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_keyboard.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsKeyboard"`));
            break;
        case MATCH_IS_POINTER:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsPointer"`));
            ptr.is_pointer.set = xf86getBoolValue(&ptr.is_pointer.val,
                                                   xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_pointer.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsPointer"`));
            break;
        case MATCH_IS_JOYSTICK:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsJoystick"`));
            ptr.is_joystick.set = xf86getBoolValue(&ptr.is_joystick.val,
                                                    xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_joystick.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsJoystick"`));
            break;
        case MATCH_IS_TABLET:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsTablet"`));
            ptr.is_tablet.set = xf86getBoolValue(&ptr.is_tablet.val, xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_tablet.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsTablet"`));
            break;
        case MATCH_IS_TABLET_PAD:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsTabletPad"`));
            ptr.is_tablet_pad.set = xf86getBoolValue(&ptr.is_tablet_pad.val, xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_tablet_pad.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsTabletPad"`));
            break;
        case MATCH_IS_TOUCHPAD:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsTouchpad"`));
            ptr.is_touchpad.set = xf86getBoolValue(&ptr.is_touchpad.val,
                                                    xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_touchpad.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsTouchpad"`));
            break;
        case MATCH_IS_TOUCHSCREEN:
            if (xf86getSubToken(&(ptr.comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchIsTouchscreen"`));
            ptr.is_touchscreen.set = xf86getBoolValue(&ptr.is_touchscreen.val,
                                                       xf86_lex_val.str);
            free(xf86_lex_val.str);
            if (!ptr.is_touchscreen.set)
                mixin(ErrorP!(`BOOL_MSG, "MatchIsTouchscreen"`));
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
    printf("InputClass section parsed\n");
}

    return ptr;
}

void xf86printInputClassSection(FILE* cf, XF86ConfInputClassPtr ptr)
{
    Bool not_first = void;

    while (ptr) {
        fprintf(cf, "Section \"InputClass\"\n");
        if (ptr.comment)
            fprintf(cf, "%s", ptr.comment);
        if (ptr.identifier)
            fprintf(cf, "\tIdentifier      \"%s\"\n", ptr.identifier);
        if (ptr.driver)
            fprintf(cf, "\tDriver          \"%s\"\n", ptr.driver);

        foreach(group; ptr.match_product.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchProduct  \"");
            else                   fprintf(cf, "\tMatchProduct    \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_vendor.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchVendor   \"");
            else                   fprintf(cf, "\tMatchVendor     \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_device.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchDevicePath \"");
            else                   fprintf(cf, "\tMatchDevicePath   \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_os.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchOS       \"");
            else                   fprintf(cf, "\tMatchOS         \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_pnpid.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchPnPID    \"");
            else                   fprintf(cf, "\tMatchPnPID      \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_usbid.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchUSBID    \"");
            else                   fprintf(cf, "\tMatchUSBID      \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_driver.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchDriver   \"");
            else                   fprintf(cf, "\tMatchDriver     \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_tag.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchTAG      \"");
            else                   fprintf(cf, "\tMatchTAG        \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        foreach(group; ptr.match_layout.byEntries!(xf86MatchGroup, "entry")) {
            if (group.is_negated) fprintf(cf, "\tNoMatchLayout   \"");
            else                   fprintf(cf, "\tMatchLayout     \"");
            not_first = FALSE;
            foreach(pattern; group.patterns.byEntries!(xf86MatchPattern, "entry")) {
                xf86printMatchPattern(cf, pattern, not_first);
                not_first = TRUE;
            }
            fprintf(cf, "\"\n");
        }
        if (ptr.is_keyboard.set)
            fprintf(cf, "\tIsKeyboard      \"%s\"\n",
                    ptr.is_keyboard.val ? "yes".ptr : "no".ptr);
        if (ptr.is_pointer.set)
            fprintf(cf, "\tIsPointer       \"%s\"\n",
                    ptr.is_pointer.val ? "yes".ptr : "no".ptr);
        if (ptr.is_joystick.set)
            fprintf(cf, "\tIsJoystick      \"%s\"\n",
                    ptr.is_joystick.val ? "yes".ptr : "no".ptr);
        if (ptr.is_tablet.set)
            fprintf(cf, "\tIsTablet        \"%s\"\n",
                    ptr.is_tablet.val ? "yes".ptr : "no".ptr);
        if (ptr.is_tablet_pad.set)
            fprintf(cf, "\tIsTabletPad     \"%s\"\n",
                    ptr.is_tablet_pad.val ? "yes".ptr : "no".ptr);
        if (ptr.is_touchpad.set)
            fprintf(cf, "\tIsTouchpad      \"%s\"\n",
                    ptr.is_touchpad.val ? "yes".ptr : "no".ptr);
        if (ptr.is_touchscreen.set)
            fprintf(cf, "\tIsTouchscreen   \"%s\"\n",
                    ptr.is_touchscreen.val ? "yes".ptr : "no".ptr);
        xf86printOptionList(cf, ptr.option_lst, 1);
        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfInputClassRec*)ptr.list.next;
    }
}
