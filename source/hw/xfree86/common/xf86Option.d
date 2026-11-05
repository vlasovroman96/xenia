module hw.xfree86.common.xf86Option;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 1998-2003 by The XFree86 Project, Inc.
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

/*
 * Author: David Dawes <dawes@xfree86.org>
 *
 * This file includes public option handling functions.
 */
import build.xorg_config;

import core.stdc.stdlib;
import core.stdc.ctype;
//import x11.X;
import os.os;
import xf86Opt_priv;
import hw.xfree86.common.xf86Xinput;
import include.xf86Optrec;
import include.xf86Parser;
import xf86platformBus;
import xf86Bus;
import hw.xfree86.parser.Flags;
import hw.xfree86.common.xf86Helper;
import scan;
import os.log;
import externs.gnu;
import xf86platformBus;

struct XF86OptionRec {
    GenericListRec list;
    const(char)* opt_name;
    const(char)* opt_val;
    int opt_used;
    const(char)* opt_comment;
}
/*
 * xf86CollectOptions collects the options from each of the config file
 * sections used by the screen and puts the combined list in pScrn->options.
 * This function requires that the following have been initialised:
 *
 *	pScrn->confScreen
 *	pScrn->Entities[i]->device
 *	pScrn->display
 *	pScrn->monitor
 *
 * The extraOpts parameter may optionally contain a list of additional options
 * to include.
 *
 * The order of precedence for options is:
 *
 *   extraOpts, display, confScreen, monitor, device, outputClassOptions
 */

void xf86CollectOptions(ScrnInfoPtr pScrn, XF86OptionPtr extraOpts)
{
    XF86OptionPtr tmp = void;
    XF86OptionPtr extras = cast(XF86OptionPtr) extraOpts;
    GDevPtr device = void;

    int i = void;

    pScrn.options = null;

    for (i = pScrn.numEntities - 1; i >= 0; i--) {
        xf86MergeOutputClassOptions(pScrn.entityList[i], &pScrn.options);

        device = xf86GetDevFromEntity(pScrn.entityList[i],
                                      pScrn.entityInstanceList[i]);
        if (device && device.options) {
            tmp = xf86optionListDup(cast(_InputOption*)device.options);
            if (pScrn.options)
                pScrn.options = xf86optionListMerge(cast(_InputOption*)pScrn.options, tmp);
            else
                pScrn.options = tmp;
        }
    }
    if (pScrn.monitor.options) {
        tmp = xf86optionListDup(cast(_InputOption*)pScrn.monitor.options);
        if (pScrn.options)
            pScrn.options = xf86optionListMerge(cast(_InputOption*)pScrn.options, tmp);
        else
            pScrn.options = tmp;
    }
    if (pScrn.confScreen.options) {
        tmp = xf86optionListDup(cast(_InputOption*)pScrn.confScreen.options);
        if (pScrn.options)
            pScrn.options = xf86optionListMerge(cast(_InputOption*)pScrn.options, tmp);
        else
            pScrn.options = tmp;
    }
    if (pScrn.display.options) {
        tmp = xf86optionListDup(cast(_InputOption*)pScrn.display.options);
        if (pScrn.options)
            pScrn.options = xf86optionListMerge(cast(_InputOption*)pScrn.options, tmp);
        else
            pScrn.options = tmp;
    }
    if (extras) {
        tmp = xf86optionListDup(cast(_InputOption*)extras);
        if (pScrn.options)
            pScrn.options = xf86optionListMerge(cast(_InputOption*)pScrn.options, tmp);
        else
            pScrn.options = tmp;
    }
}

/*
 * xf86CollectInputOptions collects extra options for an InputDevice (other
 * than those added by the config backend).
 * The options are merged into the existing ones and thus take precedence
 * over the others.
 */

void xf86CollectInputOptions(InputInfoPtr pInfo, const(char)** defaultOpts)
{
    if (defaultOpts) {
        XF86OptionPtr tmp = xf86optionListCreate(defaultOpts, -1, 0);

        if (pInfo.options)
            pInfo.options = xf86optionListMerge(cast(_InputOption*)tmp, pInfo.options);
        else
            pInfo.options = tmp;
    }
}

/**
 * Duplicate the option list passed in. The returned pointer will be a newly
 * allocated option list and must be freed by the caller.
 */
XF86OptionPtr xf86OptionListDuplicate(XF86OptionPtr options)
{
    XF86OptionPtr o = null;

    while (options) {
        o = xf86AddNewOption(o, xf86OptionName(options),
                             xf86OptionValue(options));
        options = xf86nextOption(options);
    }

    return o;
}

/* Created for new XInput stuff -- essentially extensions to the parser	*/

private int LookupIntOption(XF86OptionPtr optlist, const(char)* name, int deflt, Bool markUsed)
{
    OptionInfoRec o = void;

    o.name = name;
    o.type = OPTV_INTEGER;
    if (ParseOptionValue(-1, optlist, &o, markUsed))
        deflt = cast(int)o.value.num;
    return deflt;
}

private double LookupRealOption(XF86OptionPtr optlist, const(char)* name, double deflt, Bool markUsed)
{
    OptionInfoRec o = void;

    o.name = name;
    o.type = OPTV_REAL;
    if (ParseOptionValue(-1, optlist, &o, markUsed))
        deflt = o.value.realnum;
    return deflt;
}

private char* LookupStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* deflt, Bool markUsed)
{
    OptionInfoRec o = void;

    o.name = name;
    o.type = OPTV_STRING;
    if (ParseOptionValue(-1, optlist, &o, markUsed))
        deflt = o.value.str;
    if (deflt)
        return strdup(deflt);
    else
        return null;
}

private int LookupBoolOption(XF86OptionPtr optlist, const(char)* name, int deflt, Bool markUsed)
{
    OptionInfoRec o = void;

    o.name = name;
    o.type = OPTV_BOOLEAN;
    if (ParseOptionValue(-1, optlist, &o, markUsed))
        deflt = o.value.boolean;
    return deflt;
}

private double LookupPercentOption(XF86OptionPtr optlist, const(char)* name, double deflt, Bool markUsed)
{
    OptionInfoRec o = void;

    o.name = name;
    o.type = OPTV_PERCENT;
    if (ParseOptionValue(-1, optlist, &o, markUsed))
        deflt = o.value.realnum;
    return deflt;
}

/* These xf86Set* functions are intended for use by non-screen specific code */

int xf86SetIntOption(XF86OptionPtr optlist, const(char)* name, int deflt)
{
    return LookupIntOption(optlist, name, deflt, TRUE);
}

double xf86SetRealOption(XF86OptionPtr optlist, const(char)* name, double deflt)
{
    return LookupRealOption(optlist, name, deflt, TRUE);
}

char* xf86SetStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* deflt)
{
    return LookupStrOption(optlist, name, deflt, TRUE);
}

int xf86SetBoolOption(XF86OptionPtr optlist, const(char)* name, int deflt)
{
    return LookupBoolOption(optlist, name, deflt, TRUE);
}

double xf86SetPercentOption(XF86OptionPtr optlist, const(char)* name, double deflt)
{
    return LookupPercentOption(optlist, name, deflt, TRUE);
}

/*
 * These are like the Set*Option functions, but they don't mark the options
 * as used.
 */
int xf86CheckIntOption(XF86OptionPtr optlist, const(char)* name, int deflt)
{
    return LookupIntOption(optlist, name, deflt, FALSE);
}

char* xf86CheckStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* deflt)
{
    return LookupStrOption(optlist, name, deflt, FALSE);
}

int xf86CheckBoolOption(XF86OptionPtr optlist, const(char)* name, int deflt)
{
    return LookupBoolOption(optlist, name, deflt, FALSE);
}

double xf86CheckPercentOption(XF86OptionPtr optlist, const(char)* name, double deflt)
{
    return LookupPercentOption(optlist, name, deflt, FALSE);
}

/*
 * xf86AddNewOption() has the required property of replacing the option value
 * if the option is already present.
 */
XF86OptionPtr xf86ReplaceIntOption(XF86OptionPtr optlist, const(char)* name, const(int) val)
{
    char[16] tmp = void;

    snprintf(tmp.ptr, tmp.sizeof, "%i", val);
    return xf86AddNewOption(optlist, name, tmp.ptr);
}

XF86OptionPtr xf86ReplaceBoolOption(XF86OptionPtr optlist, const(char)* name, const(Bool) val)
{
    return xf86AddNewOption(optlist, name, val ? "True" : "False");
}

XF86OptionPtr xf86ReplaceStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* val)
{
    return xf86AddNewOption(optlist, name, val);
}

XF86OptionPtr xf86AddNewOption(XF86OptionPtr head, const(char)* name, const(char)* val)
{
    /* XXX These should actually be allocated in the parser library. */
    char* tmp = val ? strdup(val) : null;
    char* tmp_name = strdup(name);

    return xf86addNewOption(head, tmp_name, tmp);
}

XF86OptionPtr xf86NextOption(XF86OptionPtr list)
{
    return xf86nextOption(list);
}

XF86OptionPtr xf86OptionListCreate(const(char)** options, int count, int used)
{
    return xf86optionListCreate(options, count, used);
}

XF86OptionPtr xf86OptionListMerge(XF86OptionPtr head, XF86OptionPtr tail)
{
    return xf86optionListMerge(cast(_InputOption*)head, tail);
}

void xf86OptionListFree(XF86OptionPtr opt)
{
    xf86optionListFree(opt);
}

char* xf86OptionName(XF86OptionPtr opt)
{
    return xf86optionName(opt);
}

char* xf86OptionValue(XF86OptionPtr opt)
{
    return xf86optionValue(opt);
}

void xf86OptionListReport(XF86OptionPtr parm)
{
    XF86OptionPtr opts = parm;

    while (opts) {
        if (xf86optionValue(opts))
            xf86ErrorFVerb(5, "\tOption \"%s\" \"%s\"\n",
                           xf86optionName(opts), xf86optionValue(opts));
        else
            xf86ErrorFVerb(5, "\tOption \"%s\"\n", xf86optionName(opts));
        opts = xf86nextOption(opts);
    }
}

/* End of XInput-caused section	*/

XF86OptionPtr xf86FindOption(XF86OptionPtr options, const(char)* name)
{
    return xf86findOption(options, name);
}

const(char)* xf86FindOptionValue(XF86OptionPtr options, const(char)* name)
{
    return xf86findOptionValue(options, name);
}

void xf86MarkOptionUsed(XF86OptionPtr option)
{
    if (option !is null)
        option.opt_used = TRUE;
}

void xf86MarkOptionUsedByName(XF86OptionPtr options, const(char)* name)
{
    XF86OptionPtr opt = void;

    opt = xf86findOption(options, name);
    if (opt !is null)
        opt.opt_used = TRUE;
}

private Bool xf86CheckIfOptionUsedByName(XF86OptionPtr options, const(char)* name)
{
    XF86OptionPtr opt = void;

    opt = xf86findOption(options, name);
    if (opt !is null)
        return opt.opt_used;
    else
        return FALSE;
}

void xf86ShowUnusedOptions(int scrnIndex, XF86OptionPtr opt)
{
    while (opt) {
        if (opt.opt_name && !opt.opt_used) {
            xf86DrvMsg(scrnIndex, X_WARNING, "Option \"%s\" is not used\n",
                       opt.opt_name);
        }
        opt = cast(_InputOption*)opt.list.next;
    }
}

private Bool GetBoolValue(OptionInfoPtr p, const(char)* s)
{
    return xf86getBoolValue(&p.value.boolean, s);
}

private Bool ParseOptionValue(int scrnIndex, XF86OptionPtr options, OptionInfoPtr p, Bool markUsed)
{
    const(char)* s = void;
    char* end = void;
    Bool wasUsed = FALSE;

    if ((s = xf86findOptionValue(options, p.name)) !is null) {
        if (markUsed) {
            wasUsed = xf86CheckIfOptionUsedByName(options, p.name);
            xf86MarkOptionUsedByName(options, p.name);
        }
        switch (p.type) {
        case OPTV_INTEGER:
            if (*s == '\0') {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires an integer value\n",
                               p.name);
                }
                p.found = FALSE;
            }
            else {
                p.value.num = strtoul(s, cast(const(char)**)&end, 0);
                if (*end == '\0') {
                    p.found = TRUE;
                }
                else {
                    if (markUsed) {
                        xf86DrvMsg(scrnIndex, X_WARNING,
                                   "Option \"%s\" requires an integer value\n",
                                   p.name);
                    }
                    p.found = FALSE;
                }
            }
            break;
        case OPTV_STRING:
            if (*s == '\0') {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires a string value\n",
                               p.name);
                }
                p.found = FALSE;
            }
            else {
                p.value.str = s;
                p.found = TRUE;
            }
            break;
        case OPTV_ANYSTR:
            p.value.str = s;
            p.found = TRUE;
            break;
        case OPTV_REAL:
            if (*s == '\0') {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires a floating point "
                               ~ "value\n", p.name);
                }
                p.found = FALSE;
            }
            else {
                p.value.realnum = strtod(s, cast(const(char)**)&end);
                if (*end == '\0') {
                    p.found = TRUE;
                }
                else {
                    if (markUsed) {
                        xf86DrvMsg(scrnIndex, X_WARNING,
                                   "Option \"%s\" requires a floating point "
                                   ~ "value\n", p.name);
                    }
                    p.found = FALSE;
                }
            }
            break;
        case OPTV_BOOLEAN:
            if (GetBoolValue(p, s)) {
                p.found = TRUE;
            }
            else {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires a boolean value\n",
                               p.name);
                }
                p.found = FALSE;
            }
            break;
        case OPTV_PERCENT:
        {
            char tmp = 0;

            /* awkward match, but %% doesn't increase the match counter,
             * hence 100 looks the same as 100% to the caller of sccanf
             */
            if (sscanf(s, "%lf%c", &p.value.realnum, &tmp) != 2 || tmp != '%') {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires a percent value\n",
                               p.name);
                }
                p.found = FALSE;
            }
            else {
                p.found = TRUE;
            }
        }
            break;
        case OPTV_FREQ:
            if (*s == '\0') {
                if (markUsed) {
                    xf86DrvMsg(scrnIndex, X_WARNING,
                               "Option \"%s\" requires a frequency value\n",
                               p.name);
                }
                p.found = FALSE;
            }
            else {
                double freq = strtod(s, cast(const(char)**)&end);
                int units = 0;

                if (end != s) {
                    p.found = TRUE;
                    if (!xf86NameCmp(end, "Hz"))
                        units = 1;
                    else if (!xf86NameCmp(end, "kHz") || !xf86NameCmp(end, "k"))
                        units = 1000;
                    else if (!xf86NameCmp(end, "MHz") || !xf86NameCmp(end, "M"))
                        units = 1000000;
                    else {
                        if (markUsed) {
                            xf86DrvMsg(scrnIndex, X_WARNING,
                                       "Option \"%s\" requires a frequency value\n",
                                       p.name);
                        }
                        p.found = FALSE;
                    }
                    if (p.found)
                        freq *= cast(double) units;
                }
                else {
                    if (markUsed) {
                        xf86DrvMsg(scrnIndex, X_WARNING,
                                   "Option \"%s\" requires a frequency value\n",
                                   p.name);
                    }
                    p.found = FALSE;
                }
                if (p.found) {
                    p.value.freq.freq = freq;
                    p.value.freq.units = units;
                }
            }
            break;
        case OPTV_NONE:
            /* Should never get here */
            p.found = FALSE;
            break;
        default: break;}
        if (p.found && markUsed) {
            int verb = 2;

            if (wasUsed)
                verb = 4;
            xf86DrvMsgVerb(scrnIndex, X_CONFIG, verb, "Option \"%s\"", p.name);
            if (!(p.type == OPTV_BOOLEAN && *s == 0)) {
                xf86ErrorFVerb(verb, " \"%s\"", s);
            }
            xf86ErrorFVerb(verb, "\n");
        }
    }
    else if (p.type == OPTV_BOOLEAN) {
        /* Look for matches with options with or without a "No" prefix. */
        char* n = void, newn = void;
        OptionInfoRec opt = void;

        n = xf86NormalizeName(p.name);
        if (!n) {
            p.found = FALSE;
            return FALSE;
        }
        if (strncmp(n, "no", 2) == 0) {
            newn = n + 2;
        }
        else {
            free(n);
            if (asprintf(&n, "No%s", p.name) == -1) {
                p.found = FALSE;
                return FALSE;
            }
            newn = n;
        }
        if ((s = xf86findOptionValue(options, newn)) !is null) {
            if (markUsed)
                xf86MarkOptionUsedByName(options, newn);
            if (GetBoolValue(&opt, s)) {
                p.value.boolean = !opt.value.boolean;
                p.found = TRUE;
            }
            else {
                xf86DrvMsg(scrnIndex, X_WARNING,
                           "Option \"%s\" requires a boolean value\n", newn);
                p.found = FALSE;
            }
        }
        else {
            p.found = FALSE;
        }
        if (p.found && markUsed) {
            xf86DrvMsgVerb(scrnIndex, X_CONFIG, 2, "Option \"%s\"", newn);
            if (*s != 0) {
                xf86ErrorFVerb(2, " \"%s\"", s);
            }
            xf86ErrorFVerb(2, "\n");
        }
        free(n);
    }
    else {
        p.found = FALSE;
    }
    return p.found;
}

void xf86ProcessOptions(int scrnIndex, XF86OptionPtr options, OptionInfoPtr optinfo)
{
    OptionInfoPtr p = void;

    for (p = optinfo; p.name !is null; p++) {
        ParseOptionValue(scrnIndex, options, p, TRUE);
    }
}

OptionInfoPtr xf86TokenToOptinfo(const(OptionInfoRec)* table, int token)
{
    const(OptionInfoRec)* p = void, match = null, set = null;

    if (!table) {
        ErrorF("xf86TokenToOptinfo: table is NULL\n");
        return null;
    }

    for (p = table; p.token >= 0; p++) {
        if (p.token == token) {
            match = p;
            if (p.found)
                set = p;
        }
    }

    if (set)
        return cast(OptionInfoPtr) set;
    else if (match)
        return cast(OptionInfoPtr) match;
    else
        return null;
}

const(char)* xf86TokenToOptName(const(OptionInfoRec)* table, int token)
{
    const(OptionInfoRec)* p = void;

    p = xf86TokenToOptinfo(table, token);
    return p ? p.name : null;
}

Bool xf86IsOptionSet(const(OptionInfoRec)* table, int token)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    return p && p.found;
}

const(char)* xf86GetOptValString(const(OptionInfoRec)* table, int token)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found)
        return p.value.str;
    else
        return null;
}

Bool xf86GetOptValInteger(const(OptionInfoRec)* table, int token, int* value)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found) {
        *value = cast(int)p.value.num;
        return TRUE;
    }
    else
        return FALSE;
}

Bool xf86GetOptValULong(const(OptionInfoRec)* table, int token, c_ulong* value)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found) {
        *value = p.value.num;
        return TRUE;
    }
    else
        return FALSE;
}

Bool xf86GetOptValFreq(const(OptionInfoRec)* table, int token, OptFreqUnits expectedUnits, double* value)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found) {
        if (p.value.freq.units > 0) {
            /* Units give, so the scaling is known. */
            switch (expectedUnits) {
            case OPTUNITS_HZ:
                *value = p.value.freq.freq;
                break;
            case OPTUNITS_KHZ:
                *value = p.value.freq.freq / 1000.0;
                break;
            case OPTUNITS_MHZ:
                *value = p.value.freq.freq / 1000000.0;
                break;
            default: break;}
        }
        else {
            /* No units given, so try to guess the scaling. */
            switch (expectedUnits) {
            case OPTUNITS_HZ:
                *value = p.value.freq.freq;
                break;
            case OPTUNITS_KHZ:
                if (p.value.freq.freq > 1000.0)
                    *value = p.value.freq.freq / 1000.0;
                else
                    *value = p.value.freq.freq;
                break;
            case OPTUNITS_MHZ:
                if (p.value.freq.freq > 1000000.0)
                    *value = p.value.freq.freq / 1000000.0;
                else if (p.value.freq.freq > 1000.0)
                    *value = p.value.freq.freq / 1000.0;
                else
                    *value = p.value.freq.freq;
            goto default;
            default: break;}
        }
        return TRUE;
    }
    else
        return FALSE;
}

Bool xf86GetOptValBool(const(OptionInfoRec)* table, int token, Bool* value)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found) {
        *value = p.value.boolean;
        return TRUE;
    }
    else
        return FALSE;
}

Bool xf86ReturnOptValBool(const(OptionInfoRec)* table, int token, Bool def)
{
    OptionInfoPtr p = void;

    p = xf86TokenToOptinfo(table, token);
    if (p && p.found) {
        return p.value.boolean;
    }
    else
        return def;
}

int xf86NameCmp(const(char)* s1, const(char)* s2)
{
    return xf86nameCompare(s1, s2);
}

char* xf86NormalizeName(const(char)* s)
{
    char* q = void;
    const(char)* p = void;

    if (s is null)
        return null;

    char* ret = cast(char*) calloc(1, strlen(s) + 1);
    if (!ret)
        return null;
    for (p = s, q = ret; *p != 0; p++) {
        switch (*p) {
        case '_':
        case ' ':
        case '\t':
            continue;
        default:
            if (isupper(cast(ubyte)*p))
                *q++ = cast(char)tolower(cast(ubyte)*p);
            else
                *q++ = *p;
        }
    }
    *q = '\0';
    return ret;
}
