module xf86Opt_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import x11.Xdefs;
// //public import x11.Xfuncproto;

import hw.xfree86.parser.Flags;                

struct OptFrequency {
    double freq = 0;
    int units;
}

union ValueUnion {
    c_ulong num;
    const(char)* str;
    double realnum;
    Bool boolean;
    OptFrequency freq;
}

enum OptionValueType {
    OPTV_NONE = 0,
    OPTV_INTEGER,
    OPTV_STRING,                /* a non-empty string */
    OPTV_ANYSTR,                /* Any string, including an empty one */
    OPTV_REAL,
    OPTV_BOOLEAN,
    OPTV_PERCENT,
    OPTV_FREQ
}
alias OPTV_NONE = OptionValueType.OPTV_NONE;
alias OPTV_INTEGER = OptionValueType.OPTV_INTEGER;
alias OPTV_STRING = OptionValueType.OPTV_STRING;
alias OPTV_ANYSTR = OptionValueType.OPTV_ANYSTR;
alias OPTV_REAL = OptionValueType.OPTV_REAL;
alias OPTV_BOOLEAN = OptionValueType.OPTV_BOOLEAN;
alias OPTV_PERCENT = OptionValueType.OPTV_PERCENT;
alias OPTV_FREQ = OptionValueType.OPTV_FREQ;


enum OptFreqUnits {
    OPTUNITS_HZ = 1,
    OPTUNITS_KHZ,
    OPTUNITS_MHZ
}
alias OPTUNITS_HZ = OptFreqUnits.OPTUNITS_HZ;
alias OPTUNITS_KHZ = OptFreqUnits.OPTUNITS_KHZ;
alias OPTUNITS_MHZ = OptFreqUnits.OPTUNITS_MHZ;


struct _OptionInfoRec {
    int token;
    const(char)* name;
    OptionValueType type;
    ValueUnion value;
    Bool found;
}alias OptionInfoRec = _OptionInfoRec;
alias OptionInfoPtr = OptionInfoRec*;

// void  xf86SetIntOption(XF86OptionPtr optlist, const(char)* name, int deflt);
// void  xf86SetRealOption(XF86OptionPtr optlist, const(char)* name, double deflt);
// void * xf86SetStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* deflt);
// void  xf86SetBoolOption(XF86OptionPtr list, const(char)* name, int deflt);
void  xf86SetPercentOption(XF86OptionPtr list, const(char)* name, double deflt);
// void  xf86CheckIntOption(XF86OptionPtr optlist, const(char)* name, int deflt);
// void * xf86CheckStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* deflt);
// void  xf86CheckBoolOption(XF86OptionPtr list, const(char)* name, int deflt);
void  xf86CheckPercentOption(XF86OptionPtr list, const(char)* name, double deflt);
// void  xf86AddNewOption(XF86OptionPtr head, const(char)* name, const(char)* val);
// void  xf86NextOption(XF86OptionPtr list);
void  xf86OptionListCreate(const(char)** options, int count, int used);
// void  xf86OptionListMerge(XF86OptionPtr head, XF86OptionPtr tail);
void  xf86OptionListDuplicate(XF86OptionPtr list);
// void  xf86OptionListFree(XF86OptionPtr opt);
// void * xf86OptionName(XF86OptionPtr opt);
// void * xf86OptionValue(XF86OptionPtr opt);
// void  xf86FindOption(XF86OptionPtr options, const(char)* name);
// const(void )* xf86FindOptionValue(XF86OptionPtr options, const(char)* name);
// void  xf86MarkOptionUsedByName(XF86OptionPtr options, const(char)* name);
// void  xf86ShowUnusedOptions(int scrnIndex, XF86OptionPtr options);
// void  xf86ProcessOptions(int scrnIndex, XF86OptionPtr options, OptionInfoPtr optinfo);
void  xf86TokenToOptinfo(const(OptionInfoRec)* table, int token);
const(void )* xf86TokenToOptName(const(OptionInfoRec)* table, int token);
// void  xf86IsOptionSet(const(OptionInfoRec)* table, int token);
// const(void )* xf86GetOptValString(const(OptionInfoRec)* table, int token);
// void  xf86GetOptValInteger(const(OptionInfoRec)* table, int token, int* value);
void  xf86GetOptValULong(const(OptionInfoRec)* table, int token, c_ulong* value);
// void  xf86GetOptValFreq(const(OptionInfoRec)* table, int token, OptFreqUnits expectedUnits, double* value);
// void  xf86GetOptValBool(const(OptionInfoRec)* table, int token, Bool* value);
// void  xf86ReturnOptValBool(const(OptionInfoRec)* table, int token, Bool def);
// void  xf86NameCmp(const(char)* s1, const(char)* s2);
// void * xf86NormalizeName(const(char)* s);
// void  xf86ReplaceIntOption(XF86OptionPtr optlist, const(char)* name, const(int) val);
void  xf86ReplaceBoolOption(XF86OptionPtr optlist, const(char)* name, const(Bool) val);
// void  xf86ReplaceStrOption(XF86OptionPtr optlist, const(char)* name, const(char)* val);

// void xf86OptionListReport(XF86OptionPtr parm);
// void xf86MarkOptionUsed(XF86OptionPtr option);

 /* _XORG_XF86OPTION_PRIV_H */
