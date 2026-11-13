module hw.xfree86.parser.Flags;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

import hw.xfree86.parser.xf86Parser;
import xf86tokens;
import Configint;
////import x11.Xfuncproto;
import os.xprintf;
import xf86tokens;
import Configint;
import x11.Xmd;
import x11.Xdefs;
import dix.input;
import scan;
import core.stdc.string;
import externs.gnu;
import read;

struct _InputOption {
    GenericListRec list;
    char* opt_name;
    char* opt_val;
    int opt_used;
    char* opt_comment;
}

alias XF86OptionPtr = InputOption*;

private const(xf86ConfigSymTabRec)[16] ServerFlagsTab = [
    {ENDSECTION, "endsection"},
    {DONTZAP, "dontzap"},
    {DONTZOOM, "dontzoom"},
    {DISABLEVIDMODE, "disablevidmodeextension"},
    {ALLOWNONLOCAL, "allownonlocalxvidtune"},
    {DISABLEMODINDEV, "disablemodindev"},
    {MODINDEVALLOWNONLOCAL, "allownonlocalmodindev"},
    {ALLOWMOUSEOPENFAIL, "allowmouseopenfail"},
    {OPTION, "option"},
    {BLANKTIME, "blanktime"},
    {STANDBYTIME, "standbytime"},
    {SUSPENDTIME, "suspendtime"},
    {OFFTIME, "offtime"},
    {DEFAULTLAYOUT, "defaultserverlayout"},
    {-1, ""},
];

alias CLEANUP = xf86freeFlags;

XF86ConfFlagsPtr xf86parseFlagsSection(XF86ConfFlagsPtr ptr)
{
    int token = void;

    if (ptr is null)
    {
        if((ptr=cast(XF86ConfFlagsRec*) calloc(1, XF86ConfFlagsRec.sizeof)) is null)
        {
            return null;
        }
    }

    while ((token = xf86getToken(ServerFlagsTab.ptr)) != ENDSECTION) {
        int hasvalue = False;
        int strvalue = False;
        int tokentype = void;

        switch (token) {
        case COMMENT:
            ptr.flg_comment = xf86addComment(ptr.flg_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
            break;
            /*
             * these old keywords are turned into standard generic options.
             * we fall through here on purpose
             */
        case DEFAULTLAYOUT:
            strvalue = True;
            goto case;
        case BLANKTIME,STANDBYTIME,SUSPENDTIME,OFFTIME:
            hasvalue = True;
        
        goto case;
        case DONTZAP,
         DONTZOOM,
         DISABLEVIDMODE,
         ALLOWNONLOCAL,
         DISABLEMODINDEV,
         MODINDEVALLOWNONLOCAL,
         ALLOWMOUSEOPENFAIL:
        {
            int i = 0;

            while (ServerFlagsTab[i].token != -1) {
                char* tmp = void;

                if (ServerFlagsTab[i].token == token) {
                    char* valstr = null;

                    tmp = strdup(ServerFlagsTab[i].name);
                    if (hasvalue) {
                        tokentype = xf86getSubToken(&(ptr.flg_comment));
                        if (strvalue) {
                            if (tokentype != XF86_TOKEN_STRING)
                                mixin(ErrorP!(`QUOTE_MSG, tmp`));
                            valstr = xf86_lex_val.str;
                        }
                        else {
                            if (tokentype != NUMBER)
                                mixin(ErrorP!(`NUMBER_MSG, tmp`));
                            if (asprintf(&valstr, "%d", xf86_lex_val.num) == -1)
                                valstr = null;
                        }
                    }
                    ptr.flg_option_lst = xf86addNewOption
                        (ptr.flg_option_lst, tmp, valstr);
                }
                i++;
            }
        }
            break;
        case OPTION:
            ptr.flg_option_lst = xf86parseOption(ptr.flg_option_lst);
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
    printf("Flags section parsed\n");
}

    return ptr;
}

void xf86printServerFlagsSection(FILE* f, XF86ConfFlagsPtr flags)
{
    XF86OptionPtr p = void;

    if ((!flags) || (!flags.flg_option_lst))
        return;
    p = flags.flg_option_lst;
    fprintf(f, "Section \"ServerFlags\"\n");
    if (flags.flg_comment)
        fprintf(f, "%s", flags.flg_comment);
    xf86printOptionList(f, p, 1);
    fprintf(f, "EndSection\n\n");
}

private XF86OptionPtr addNewOption2(XF86OptionPtr head, char* name, char* _val, int used)
{
    XF86OptionPtr new_ = void, old = null;

    /* Don't allow duplicates, free old strings */
    if (head !is null && (old = xf86findOption(head, name)) !is null) {
        new_ = old;
        free(new_.opt_name);
        free(new_.opt_val);
    }
    else
        new_ = cast(_InputOption*)calloc(1, typeof(*new_).sizeof);
    assert(new_);
    new_.opt_name = name;
    new_.opt_val = _val;
    new_.opt_used = used;

    if (old)
        return head;
    return (cast(XF86OptionPtr) xf86addListItem(cast(glp) head, cast(glp) new_));
}

XF86OptionPtr xf86addNewOption(XF86OptionPtr head, char* name, char* _val)
{
    return addNewOption2(head, name, _val, 0);
}

void xf86freeFlags(XF86ConfFlagsPtr flags)
{
    if (flags is null)
        return;
    xf86optionListFree(flags.flg_option_lst);
    mixin(TestFree!(`flags.flg_comment`));
    free(flags);
}

XF86OptionPtr xf86optionListDup(XF86OptionPtr opt)
{
    XF86OptionPtr newopt = null;
    char* _val = void;

    while (opt) {
        _val = opt.opt_val ? strdup(opt.opt_val) : null;
        newopt = xf86addNewOption(newopt, strdup(opt.opt_name), _val);
        newopt.opt_used = opt.opt_used;
        if (opt.opt_comment)
            newopt.opt_comment = strdup(opt.opt_comment);
        opt = cast(_InputOption*)opt.list.next;
    }
    return newopt;
}

void xf86optionListFree(XF86OptionPtr opt)
{
    XF86OptionPtr prev = void;

    while (opt) {
        mixin(TestFree!(`opt.opt_name`));
        mixin(TestFree!(`opt.opt_val`));
        mixin(TestFree!(`opt.opt_comment`));
        prev = opt;
        opt = cast(_InputOption*)opt.list.next;
        free(prev);
    }
}

char* xf86optionName(XF86OptionPtr opt)
{
    if (opt)
        return opt.opt_name;
    return null;
}

char* xf86optionValue(XF86OptionPtr opt)
{
    if (opt)
        return opt.opt_val;
    return null;
}

XF86OptionPtr xf86newOption(char* name, char* value)
{
    XF86OptionPtr opt = void;

    opt = cast(_InputOption*)calloc(1, typeof(*opt).sizeof);
    if (!opt)
        return null;

    opt.opt_used = 0;
    opt.list.next = null;
    opt.opt_name = name;
    opt.opt_val = value;

    return opt;
}

XF86OptionPtr xf86nextOption(XF86OptionPtr list)
{
    if (!list)
        return null;
    return cast(_InputOption*)list.list.next;
}

/*
 * this function searches the given option list for the named option and
 * returns a pointer to the option rec if found. If not found, it returns
 * NULL
 */

XF86OptionPtr xf86findOption(XF86OptionPtr list, const(char)* name)
{
    while (list) {
        if (xf86nameCompare(list.opt_name, name) == 0)
            return list;
        list = cast(_InputOption*)list.list.next;
    }
    return null;
}

/*
 * this function searches the given option list for the named option. If
 * found and the option has a parameter, a pointer to the parameter is
 * returned.  If the option does not have a parameter an empty string is
 * returned.  If the option is not found, a NULL is returned.
 */

const(char)* xf86findOptionValue(XF86OptionPtr list, const(char)* name)
{
    XF86OptionPtr p = xf86findOption(list, name);

    if (p) {
        if (p.opt_val)
            return p.opt_val;
        else
            return "";
    }
    return null;
}

XF86OptionPtr xf86optionListCreate(const(char)** options, int count, int used)
{
    XF86OptionPtr p = null;
    char* t1 = void, t2 = void;
    int i = void;

    if (count == -1) {
        for (count = 0; options[count]; count++){}
    }
    if ((count % 2) != 0) {
        fprintf(stderr,
                "xf86optionListCreate: count must be an even number.\n");
        return null;
    }
    for (i = 0; i < count; i += 2) {
        t1 = strdup(options[i]);
        t2 = strdup(options[i + 1]);
        p = addNewOption2(p, t1, t2, used);
    }

    return p;
}

/* the 2 given lists are merged. If an option with the same name is present in
 * both, the option from the user list - specified in the second argument -
 * is used. The end result is a single valid list of options. Duplicates
 * are freed, and the original lists are no longer guaranteed to be complete.
 */
XF86OptionPtr xf86optionListMerge(XF86OptionPtr head, XF86OptionPtr tail)
{
    XF86OptionPtr a = void, b = void, ap = null, bp = null;

    a = tail;
    b = head;
    while (tail && b) {
        if (xf86nameCompare(a.opt_name, b.opt_name) == 0) {
            if (b == head)
                head = a;
            else
                bp.list.next = a;
            if (a == tail)
                tail = cast(_InputOption*)a.list.next;
            else
                ap.list.next = a.list.next;
            a.list.next = b.list.next;
            b.list.next = null;
            xf86optionListFree(b);
            b = cast(_InputOption*)a.list.next;
            bp = a;
            a = tail;
            ap = null;
        }
        else {
            ap = a;
            if (((a = cast(_InputOption*)a.list.next) is null)) {
                a = tail;
                bp = b;
                b = cast(_InputOption*)b.list.next;
                ap = null;
            }
        }
    }

    if (head) {
        for (a = head; a.list.next; a = cast(_InputOption*)a.list.next){}
        a.list.next = tail;
    }
    else
        head = tail;

    return head;
}

char* xf86uLongToString(c_ulong i)
{
    char* s = void;

    if (asprintf(&s, "%lu", i) == -1)
        return null;
    return s;
}

XF86OptionPtr xf86parseOption(XF86OptionPtr head)
{
    XF86OptionPtr option = void, cnew = void, old = void;
    char* name = void, comment = null;
    int token = void;

    if ((token = xf86getSubToken(&comment)) != XF86_TOKEN_STRING) {
        xf86parseError(BAD_OPTION_MSG);
        free(comment);
        return head;
    }

    name = xf86_lex_val.str;
    if ((token = xf86getSubToken(&comment)) == XF86_TOKEN_STRING) {
        option = xf86newOption(name, xf86_lex_val.str);
        assert(option);
        option.opt_comment = comment;
        if ((token = xf86getToken(null)) == COMMENT) {
            option.opt_comment = xf86addComment(option.opt_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
        } else {
            xf86unGetToken(token);
        }
    }
    else {
        option = xf86newOption(name, null);
        assert(option);
        option.opt_comment = comment;
        if (token == COMMENT) {
            option.opt_comment = xf86addComment(option.opt_comment, xf86_lex_val.str);
            free(xf86_lex_val.str);
            xf86_lex_val.str = null;
        } else {
            xf86unGetToken(token);
        }
    }

    old = null;

    /* Don't allow duplicates */
    if (head !is null && (old = xf86findOption(head, name)) !is null) {
        cnew = old;
        free(option.opt_name);
        mixin(TestFree!(`option.opt_val`));
        mixin(TestFree!(`option.opt_comment`));
        free(option);
    }
    else
        cnew = option;

    if (old is null)
        return (cast(XF86OptionPtr) xf86addListItem(cast(glp) head, cast(glp) cnew));

    return head;
}

void xf86printOptionList(FILE* fp, XF86OptionPtr list, int tabs)
{
    int i = void;

    if (!list)
        return;
    while (list) {
        for (i = 0; i < tabs; i++)
            fputc('\t', fp);
        if (list.opt_val)
            fprintf(fp, "Option	    \"%s\" \"%s\"", list.opt_name,
                    list.opt_val);
        else
            fprintf(fp, "Option	    \"%s\"", list.opt_name);
        if (list.opt_comment)
            fprintf(fp, "%s", list.opt_comment);
        else
            fputc('\n', fp);
        list = cast(_InputOption*)list.list.next;
    }
}
