module Layout;
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

import xf86Parser_priv;
import xf86tokens;
import Configint;
import core.stdc.string;
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
import hw.xfree86.common.xf86Option;
import Input;
import Screen;
import Device;


/* Needed for auto server layout */
// int xf86CheckBoolOption(void* optlist, const(char)* name, int deflt);


private const(xf86ConfigSymTabRec)[9] LayoutTab = [
    {ENDSECTION, "endsection"},
    {SCREEN, "screen"},
    {IDENTIFIER, "identifier"},
    {MATCHSEAT, "matchseat"},
    {INACTIVE, "inactive"},
    {INPUTDEVICE, "inputdevice"},
    {OPTION, "option"},
    {-1, ""},
];

private const(xf86ConfigSymTabRec)[8] AdjTab = [
    {RIGHTOF, "rightof"},
    {LEFTOF, "leftof"},
    {ABOVE, "above"},
    {BELOW, "below"},
    {RELATIVE, "relative"},
    {ABSOLUTE, "absolute"},
    {-1, ""},
];

alias CLEANUP = xf86freeLayoutList;

XF86ConfLayoutPtr xf86parseLayoutSection()
{
    int has_ident = False;
    int token = void;

    mixin(parsePrologue!("XF86ConfLayoutPtr", "XF86ConfLayoutRec"));

        while ((token = xf86getToken(LayoutTab.ptr)) != ENDSECTION) {
        switch (token) {
        case COMMENT:
            ptr.lay_comment = xf86addComment(ptr.lay_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
        case IDENTIFIER:
            if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "Identifier"`));
            if (has_ident == True)
                mixin(ErrorP!(`MULTIPLE_MSG, "Identifier"`));
            ptr.lay_identifier = xf86_lex_val.str;
            has_ident = True;
            break;
        case MATCHSEAT:
            if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING)
                mixin(ErrorP!(`QUOTE_MSG, "MatchSeat"`));
            ptr.match_seat = xf86_lex_val.str;
            break;
        case INACTIVE:
        {
            XF86ConfInactivePtr iptr = void;

            iptr = cast(XF86ConfInactiveRec*) calloc(1, XF86ConfInactiveRec.sizeof);
            iptr.list.next = null;
            if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING) {
                free(iptr);
                mixin(ErrorP!(`INACTIVE_MSG`));
            }
            iptr.inactive_device_str = xf86_lex_val.str;
            ptr.lay_inactive_lst = cast(XF86ConfInactivePtr)
                xf86addListItem(cast(glp) ptr.lay_inactive_lst, cast(glp) iptr);
        }
            break;
        case SCREEN:
        {
            XF86ConfAdjacencyPtr aptr = void;
            int absKeyword = 0;

            aptr = cast(XF86ConfAdjacencyRec*) calloc(1, XF86ConfAdjacencyRec.sizeof);
            aptr.list.next = null;
            aptr.adj_scrnum = -1;
            aptr.adj_where = CONF_ADJ_OBSOLETE;
            aptr.adj_x = 0;
            aptr.adj_y = 0;
            aptr.adj_refscreen = null;
            if ((token = xf86getSubToken(&(ptr.lay_comment))) == NUMBER)
                aptr.adj_scrnum = xf86_lex_val.num;
            else
                xf86unGetToken(token);
            token = xf86getSubToken(&(ptr.lay_comment));
            if (token != XF86_TOKEN_STRING) {
                free(aptr);
                mixin(ErrorP!(`SCREEN_MSG`));
            }
            aptr.adj_screen_str = xf86_lex_val.str;

            token = xf86getSubTokenWithTab(&(ptr.lay_comment), AdjTab.ptr);
            switch (token) {
            case RIGHTOF:
                aptr.adj_where = CONF_ADJ_RIGHTOF;
                break;
            case LEFTOF:
                aptr.adj_where = CONF_ADJ_LEFTOF;
                break;
            case ABOVE:
                aptr.adj_where = CONF_ADJ_ABOVE;
                break;
            case BELOW:
                aptr.adj_where = CONF_ADJ_BELOW;
                break;
            case RELATIVE:
                aptr.adj_where = CONF_ADJ_RELATIVE;
                break;
            case ABSOLUTE:
                aptr.adj_where = CONF_ADJ_ABSOLUTE;
                absKeyword = 1;
                break;
            case EOF_TOKEN:
                free(aptr);
                mixin(ErrorP!(`UNEXPECTED_EOF_MSG`));
                break;
            default:
                xf86unGetToken(token);
                token = xf86getSubToken(&(ptr.lay_comment));
                if (token == XF86_TOKEN_STRING)
                    aptr.adj_where = CONF_ADJ_OBSOLETE;
                else
                    aptr.adj_where = CONF_ADJ_ABSOLUTE;
            }
            switch (aptr.adj_where) {
            case CONF_ADJ_ABSOLUTE:
                if (absKeyword)
                    token = xf86getSubToken(&(ptr.lay_comment));
                if (token == NUMBER) {
                    aptr.adj_x = xf86_lex_val.num;
                    token = xf86getSubToken(&(ptr.lay_comment));
                    if (token != NUMBER) {
                        free(aptr);
                        mixin(ErrorP!(`INVALID_SCR_MSG`));
                    }
                    aptr.adj_y = xf86_lex_val.num;
                }
                else {
                    if (absKeyword) {
                        free(aptr);
                        mixin(ErrorP!(`INVALID_SCR_MSG`));
                    }
                    else
                        xf86unGetToken(token);
                }
                break;
            case CONF_ADJ_RIGHTOF:
            case CONF_ADJ_LEFTOF:
            case CONF_ADJ_ABOVE:
            case CONF_ADJ_BELOW:
            case CONF_ADJ_RELATIVE:
                token = xf86getSubToken(&(ptr.lay_comment));
                if (token != XF86_TOKEN_STRING) {
                    free(aptr);
                    mixin(ErrorP!(`INVALID_SCR_MSG`));
                }
                aptr.adj_refscreen = xf86_lex_val.str;
                if (aptr.adj_where == CONF_ADJ_RELATIVE) {
                    token = xf86getSubToken(&(ptr.lay_comment));
                    if (token != NUMBER) {
                        free(aptr);
                        mixin(ErrorP!(`INVALID_SCR_MSG`));
                    }
                    aptr.adj_x = xf86_lex_val.num;
                    token = xf86getSubToken(&(ptr.lay_comment));
                    if (token != NUMBER) {
                        free(aptr);
                        mixin(ErrorP!(`INVALID_SCR_MSG`));
                    }
                    aptr.adj_y = xf86_lex_val.num;
                }
                break;
            case CONF_ADJ_OBSOLETE:
                /* top */
                aptr.adj_top_str = xf86_lex_val.str;

                /* bottom */
                if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING) {
                    free(aptr);
                    mixin(ErrorP!(`SCREEN_MSG`));
                }
                aptr.adj_bottom_str = xf86_lex_val.str;

                /* left */
                if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING) {
                    free(aptr);
                    mixin(ErrorP!(`SCREEN_MSG`));
                }
                aptr.adj_left_str = xf86_lex_val.str;

                /* right */
                if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING) {
                    free(aptr);
                    mixin(ErrorP!(`SCREEN_MSG`));
                }
                aptr.adj_right_str = xf86_lex_val.str;
            goto default;
            default: break;}
            ptr.lay_adjacency_lst = cast(XF86ConfAdjacencyPtr)
                xf86addListItem(cast(glp) ptr.lay_adjacency_lst, cast(glp) aptr);
        }
            break;
        case INPUTDEVICE:
        {
            XF86ConfInputrefPtr iptr = void;

            iptr = cast(XF86ConfInputrefRec*) calloc(1, XF86ConfInputrefRec.sizeof);
            iptr.list.next = null;
            iptr.iref_option_lst = null;
            if (xf86getSubToken(&(ptr.lay_comment)) != XF86_TOKEN_STRING) {
                free(iptr);
                mixin(ErrorP!(`INPUTDEV_MSG`));
            }
            iptr.iref_inputdev_str = xf86_lex_val.str;
            while ((token = xf86getSubToken(&(ptr.lay_comment))) == XF86_TOKEN_STRING) {
                iptr.iref_option_lst =
                    xf86addNewOption(iptr.iref_option_lst, xf86_lex_val.str, null);
            }
            xf86unGetToken(token);
            ptr.lay_input_lst = cast(XF86ConfInputrefPtr)
                xf86addListItem(cast(glp) ptr.lay_input_lst, cast(glp) iptr);
        }
            break;
        case OPTION:
            ptr.lay_option_lst = xf86parseOption(ptr.lay_option_lst);
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
    printf("Layout section parsed\n");
}

    return ptr;
}

void xf86printLayoutSection(FILE* cf, XF86ConfLayoutPtr ptr)
{
    XF86ConfAdjacencyPtr aptr = void;
    XF86ConfInactivePtr iptr = void;
    XF86ConfInputrefPtr inptr = void;
    XF86OptionPtr optr = void;

    while (ptr) {
        fprintf(cf, "Section \"ServerLayout\"\n");
        if (ptr.lay_comment)
            fprintf(cf, "%s", ptr.lay_comment);
        if (ptr.lay_identifier)
            fprintf(cf, "\tIdentifier     \"%s\"\n", ptr.lay_identifier);

        for (aptr = ptr.lay_adjacency_lst; aptr; aptr = cast(_XF86ConfAdjacencyRec*)aptr.list.next) {
            fprintf(cf, "\tScreen     ");
            if (aptr.adj_scrnum >= 0)
                fprintf(cf, "%2d", aptr.adj_scrnum);
            else
                fprintf(cf, "  ");
            fprintf(cf, "  \"%s\"", aptr.adj_screen_str);
            switch (aptr.adj_where) {
            case CONF_ADJ_OBSOLETE:
                fprintf(cf, " \"%s\"", aptr.adj_top_str);
                fprintf(cf, " \"%s\"", aptr.adj_bottom_str);
                fprintf(cf, " \"%s\"", aptr.adj_right_str);
                fprintf(cf, " \"%s\"\n", aptr.adj_left_str);
                break;
            case CONF_ADJ_ABSOLUTE:
                if (aptr.adj_x != -1)
                    fprintf(cf, " %d %d\n", aptr.adj_x, aptr.adj_y);
                else
                    fprintf(cf, "\n");
                break;
            case CONF_ADJ_RIGHTOF:
                fprintf(cf, " RightOf \"%s\"\n", aptr.adj_refscreen);
                break;
            case CONF_ADJ_LEFTOF:
                fprintf(cf, " LeftOf \"%s\"\n", aptr.adj_refscreen);
                break;
            case CONF_ADJ_ABOVE:
                fprintf(cf, " Above \"%s\"\n", aptr.adj_refscreen);
                break;
            case CONF_ADJ_BELOW:
                fprintf(cf, " Below \"%s\"\n", aptr.adj_refscreen);
                break;
            case CONF_ADJ_RELATIVE:
                fprintf(cf, " Relative \"%s\" %d %d\n", aptr.adj_refscreen,
                        aptr.adj_x, aptr.adj_y);
                break;
            default: break;}
        }
        for (iptr = ptr.lay_inactive_lst; iptr; iptr = cast(_XF86ConfInactiveRec*)iptr.list.next)
            fprintf(cf, "\tInactive       \"%s\"\n", iptr.inactive_device_str);
        for (inptr = ptr.lay_input_lst; inptr; inptr = cast(_XF86ConfInputrefRec*)inptr.list.next) {
            fprintf(cf, "\tInputDevice    \"%s\"", inptr.iref_inputdev_str);
            for (optr = inptr.iref_option_lst; optr; optr = cast(_InputOption*)optr.list.next) {
                fprintf(cf, " \"%s\"", optr.opt_name);
            }
            fprintf(cf, "\n");
        }
        xf86printOptionList(cf, ptr.lay_option_lst, 1);
        fprintf(cf, "EndSection\n\n");
        ptr = cast(_XF86ConfLayoutRec*)ptr.list.next;
    }
}

private void xf86freeAdjacencyList(XF86ConfAdjacencyPtr ptr)
{
    XF86ConfAdjacencyPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.adj_screen_str`));
        mixin(TestFree!(`ptr.adj_top_str`));
        mixin(TestFree!(`ptr.adj_bottom_str`));
        mixin(TestFree!(`ptr.adj_left_str`));
        mixin(TestFree!(`ptr.adj_right_str`));

        prev = ptr;
        ptr = cast(_XF86ConfAdjacencyRec*)ptr.list.next;
        free(prev);
    }

}

private void xf86freeInputrefList(XF86ConfInputrefPtr ptr)
{
    XF86ConfInputrefPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.iref_inputdev_str`));
        xf86optionListFree(ptr.iref_option_lst);
        prev = ptr;
        ptr = cast(_XF86ConfInputrefRec*)ptr.list.next;
        free(prev);
    }

}

void xf86freeLayoutList(XF86ConfLayoutPtr ptr)
{
    XF86ConfLayoutPtr prev = void;

    while (ptr) {
        mixin(TestFree!(`ptr.lay_identifier`));
        mixin(TestFree!(`ptr.lay_comment`));
        xf86freeAdjacencyList(ptr.lay_adjacency_lst);
        xf86freeInputrefList(ptr.lay_input_lst);
        prev = ptr;
        ptr = cast(_XF86ConfLayoutRec*)ptr.list.next;
        free(prev);
    }
}

int xf86layoutAddInputDevices(XF86ConfigPtr config, XF86ConfLayoutPtr layout)
{
    int count = 0;
    XF86ConfInputPtr input = config.conf_input_lst;
    XF86ConfInputrefPtr inptr = void;

    /* add all AutoServerLayout devices to the server layout */
    while (input) {
        if (xf86CheckBoolOption
            (input.inp_option_lst, "AutoServerLayout", False)) {
            XF86ConfInputrefPtr iref = layout.lay_input_lst;

            /* avoid duplicates if referenced but lists AutoServerLayout too */
            while (iref) {
                if (strcmp(iref.iref_inputdev_str, input.inp_identifier) == 0)
                    break;
                iref = cast(_XF86ConfInputrefRec*)iref.list.next;
            }

            if (!iref) {
                XF86ConfInputrefPtr iptr = cast(XF86ConfInputrefRec*) calloc(1, XF86ConfInputrefRec.sizeof);
                if (!iptr)
                    return -1;
                iptr.iref_inputdev_str = input.inp_identifier;
                layout.lay_input_lst = cast(XF86ConfInputrefPtr)
                    xf86addListItem(cast(glp) layout.lay_input_lst, cast(glp) iptr);
                count++;
            }
        }
        input = cast(_XF86ConfInputRec*)input.list.next;
    }

    inptr = layout.lay_input_lst;
    while (inptr) {
        input = xf86findInput(inptr.iref_inputdev_str, config.conf_input_lst);
        if (!input) {
            xf86validationError(UNDEFINED_INPUT_MSG,
                                inptr.iref_inputdev_str,
                                layout.lay_identifier);
            return -1;
        }
        else
            inptr.iref_inputdev = input;
        inptr = cast(_XF86ConfInputrefRec*)inptr.list.next;
    }

    return count;
}

int xf86validateLayout(XF86ConfigPtr p)
{
    XF86ConfLayoutPtr layout = p.conf_layout_lst;
    XF86ConfAdjacencyPtr adj = void;
    XF86ConfInactivePtr iptr = void;
    XF86ConfScreenPtr screen = void;
    XF86ConfDevicePtr device = void;

    while (layout) {
        adj = layout.lay_adjacency_lst;
        while (adj) {
            /* the first one can't be "" but all others can */
            screen = xf86findScreen(adj.adj_screen_str, p.conf_screen_lst);
            if (!screen) {
                xf86validationError(UNDEFINED_SCREEN_MSG,
                                    adj.adj_screen_str,
                                    layout.lay_identifier);
                return False;
            }
            else
                adj.adj_screen = screen;

            adj = cast(_XF86ConfAdjacencyRec*)adj.list.next;
        }
        iptr = layout.lay_inactive_lst;
        while (iptr) {
            device = xf86findDevice(iptr.inactive_device_str,
                                    p.conf_device_lst);
            if (!device) {
                xf86validationError(UNDEFINED_DEVICE_LAY_MSG,
                                    iptr.inactive_device_str,
                                    layout.lay_identifier);
                return False;
            }
            else
                iptr.inactive_device = device;
            iptr = cast(_XF86ConfInactiveRec*)iptr.list.next;
        }

        if (xf86layoutAddInputDevices(p, layout) == -1)
            return False;

        layout = cast(_XF86ConfLayoutRec*)layout.list.next;
    }
    return True;
}

XF86ConfLayoutPtr xf86findLayout(const(char)* name, XF86ConfLayoutPtr list)
{
    while (list) {
        if (xf86nameCompare(list.lay_identifier, name) == 0)
            return list;
        list = cast(_XF86ConfLayoutRec*)list.list.next;
    }
    return null;
}
