module xkb.maprules;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
 Copyright (c) 1996 by Silicon Graphics Computer Systems, Inc.

 Permission to use, copy, modify, and distribute this
 software and its documentation for any purpose and without
 fee is hereby granted, provided that the above copyright
 notice appear in all copies and that both that copyright
 notice and this permission notice appear in supporting
 documentation, and that the name of Silicon Graphics not be
 used in advertising or publicity pertaining to distribution
 of the software without specific prior written permission.
 Silicon Graphics makes no representation about the suitability
 of this software for any purpose. It is provided "as is"
 without any express or implied warranty.

 SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
 SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
 GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
 DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
 OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
 THE USE OR PERFORMANCE OF THIS SOFTWARE.

 ********************************************************/

import build.dix_config;

import core.stdc.stdio;
import core.stdc.ctype;
import core.stdc.stdlib;

version = X_INCLUDE_STRING_H;
version = XOS_USE_NO_LOCKING;
import x11.Xos;

//import x11.Xproto;
//import x11.X;
// //import x11.Xfuncs;
//import externs.X11.Xatom;
import externs.X11.extensions.XKB;

import os.log_priv;
import xkb.xkbrules_priv;

import dix.inputstr;
import os.os;
import xkb.xkbsrv_priv;
import xkb.xkbsrv_priv;
import xkb.xkbstr;
import os.log;
import externs.gnu;
alias memcpy = core.stdc.string.memcpy;
alias strchr = core.stdc.string.strchr;
alias memset = core.stdc.string.memset;
alias strcmp = core.stdc.string.strcmp;
alias strlen = core.stdc.string.strlen;
alias strncmp = core.stdc.string.strncmp;
alias strcat = core.stdc.string.strcat;

alias strcpy = core.stdc.string.strcpy;

alias _Xstrtokparams = char *;
alias _XStrtok = strtok_r;

enum XkbRF_PendingMatch =      (1L<<1);
enum XkbRF_Option =            (1L<<2);
enum XkbRF_Append =            (1L<<3);
enum XkbRF_Normal =            (1L<<4);

enum DFLT_LINE_SIZE =	128;

struct InputLine {
    int line_num;
    int sz_line;
    int num_line;
    char[DFLT_LINE_SIZE] buf = 0;
    char* line;
}

private void InitInputLine(InputLine* line)
{
    line.line_num = 1;
    line.num_line = 0;
    line.sz_line = DFLT_LINE_SIZE;
    line.line = line.buf.ptr;
    return;
}

private void FreeInputLine(InputLine* line)
{
    if (line.line !is line.buf.ptr)
        free(line.line);
    line.line_num = 1;
    line.num_line = 0;
    line.sz_line = DFLT_LINE_SIZE;
    line.line = line.buf.ptr;
    return;
}

private int InputLineAddChar(InputLine* line, int ch)
{
    if (line.num_line >= line.sz_line) {
        if (line.line is line.buf.ptr) {
            line.line = cast(char*)calloc(line.sz_line, 2);
            if (line.line is null)
                return -1;
            memcpy(line.line, line.buf.ptr, line.sz_line);
        }
        else {
            line.line = cast(char*)reallocarray(line.line, line.sz_line, 2);
        }
        line.sz_line *= 2;
    }
    line.line[line.num_line++] = cast(char)ch;
    return ch;
}

enum string	ADD_CHAR(string l,string c) = `((` ~ l ~ `).num_line<(` ~ l ~ `).sz_line?
				cast(int)((` ~ l ~ `).line[(` ~ l ~ `).num_line++]= cast(char)(` ~ c ~ `)):
				InputLineAddChar(` ~ l ~ `,` ~ c ~ `));`;

private Bool GetInputLine(FILE* file, InputLine* line, Bool checkbang)
{
    int ch = void;
    Bool endOfFile = void, spacePending = void, slashPending = void, inComment = void;

    endOfFile = False;
    while ((!endOfFile) && (line.num_line == 0)) {
        spacePending = slashPending = inComment = False;
        while (((ch = getc(file)) != '\n') && (ch != EOF)) {
            if (ch == '\\') {
                if ((ch = getc(file)) == EOF)
                    break;
                if (ch == '\n') {
                    inComment = False;
                    ch = ' ';
                    line.line_num++;
                }
            }
            if (inComment)
                continue;
            if (ch == '/') {
                if (slashPending) {
                    inComment = True;
                    slashPending = False;
                }
                else {
                    slashPending = True;
                }
                continue;
            }
            else if (slashPending) {
                if (spacePending) {
                    mixin(ADD_CHAR!(`line`, `' '`));
                    spacePending = False;
                }
                mixin(ADD_CHAR!(`line`, `'/'`));
                slashPending = False;
            }
            if (isspace(ch)) {
                while (isspace(ch) && (ch != '\n') && (ch != EOF)) {
                    ch = getc(file);
                }
                if (ch == EOF)
                    break;
                if ((ch != '\n') && (line.num_line > 0))
                    spacePending = True;
                ungetc(ch, file);
            }
            else {
                if (spacePending) {
                    mixin(ADD_CHAR!(`line`, `' '`));
                    spacePending = False;
                }
                if (checkbang && ch == '!') {
                    if (line.num_line != 0) {
                        DebugF("The '!' legal only at start of line\n");
                        DebugF("Line containing '!' ignored\n");
                        line.num_line = 0;
                        inComment = 0;
                        break;
                    }

                }
                mixin(ADD_CHAR!(`line`, `ch`));
            }
        }
        if (ch == EOF)
            endOfFile = True;
/*	else line->num_line++;*/
    }
    if ((line.num_line == 0) && (endOfFile))
        return False;
    mixin(ADD_CHAR!(`line`, `'\0'`));
    return True;
}

/***====================================================================***/

enum	MODEL =		0;
enum	LAYOUT =		1;
enum	VARIANT =		2;
enum	OPTION =		3;
enum	KEYCODES =	4;
enum SYMBOLS =		5;
enum	TYPES =		6;
enum	COMPAT =		7;
enum	GEOMETRY =	8;
enum	MAX_WORDS =	9;

enum	PART_MASK =	0x000F;
enum	COMPONENT_MASK =	0x03F0;

private const(char)*[MAX_WORDS] cname = [
    "model", "layout", "variant", "option",
    "keycodes", "symbols", "types", "compat", "geometry"
];

struct RemapSpec {
    int number;
    int num_remap;
    struct _Remap {
        int word;
        int index;
    }_Remap[MAX_WORDS] remap;
}

struct _FileSpec {
    char*[MAX_WORDS] name;
    _FileSpec* pending;
}
// FileSpec
alias FileSpec = _FileSpec;

struct _XkbRF_MultiDefsRec {
    const(char)* model;
    const(char)*[XkbNumKbdGroups + 1] layout;
    const(char)*[XkbNumKbdGroups + 1] variant;
    const(char)* options;
}alias XkbRF_MultiDefsRec = _XkbRF_MultiDefsRec;
alias XkbRF_MultiDefsPtr = XkbRF_MultiDefsRec*;

enum NDX_BUFF_SIZE =	4;

/***====================================================================***/

private char* get_index(char* str, int* ndx)
{
    char[NDX_BUFF_SIZE] ndx_buf = 0;
    char* end = void;

    if (*str != '[') {
        *ndx = 0;
        return str;
    }
    str++;
    end = strchr(str, ']');
    if (end is null) {
        *ndx = -1;
        return str - 1;
    }
    if ((end - str) >= NDX_BUFF_SIZE) {
        *ndx = -1;
        return end + 1;
    }
    strlcpy(ndx_buf.ptr, str, 1 + end - str);
    *ndx = atoi(ndx_buf.ptr);
    return end + 1;
}

private void SetUpRemap(InputLine* line, RemapSpec* remap)
{
    char* tok = void;
    _Xstrtokparams strtok_buf = void;

    uint l_ndx_present = 0;
    uint v_ndx_present = 0;
    uint present = 0;
    char* str = &line.line[1];
    int len = remap.number;

    memset(cast(char*) remap, 0, RemapSpec.sizeof);
    remap.number = len;
    while ((tok = _XStrtok(str, " ", &strtok_buf)) !is null) {
        Bool found = False;
        str = null;
        if (strcmp(tok, "=") == 0)
            continue;
        for (int i = 0; i < MAX_WORDS; i++) {
            len = cast(int)strlen(cname[i]);
            if (strncmp(cname[i], tok, len) == 0) {
                int ndx = void;
                if (strlen(tok) > len) {
                    char* end = get_index(tok + len, &ndx);

                    if ((i != LAYOUT && i != VARIANT) ||
                        *end != '\0' || ndx == -1)
                        break;
                    if (ndx < 1 || ndx > XkbNumKbdGroups) {
                        DebugF("Illegal %s index: %d\n", cname[i], ndx);
                        DebugF("Index must be in range 1..%d\n",
                               XkbNumKbdGroups);
                        break;
                    }
                }
                else {
                    ndx = 0;
                }
                found = True;
                if (present & (1 << i)) {
                    if ((i == LAYOUT && l_ndx_present & (1 << ndx)) ||
                        (i == VARIANT && v_ndx_present & (1 << ndx))) {
                        DebugF("Component \"%s\" listed twice\n", tok);
                        DebugF("Second definition ignored\n");
                        break;
                    }
                }
                present |= (1 << i);
                if (i == LAYOUT)
                    l_ndx_present |= 1 << ndx;
                if (i == VARIANT)
                    v_ndx_present |= 1 << ndx;
                remap.remap[remap.num_remap].word = i;
                remap.remap[remap.num_remap++].index = ndx;
                break;
            }
        }
        if (!found) {
            fprintf(stderr, "Unknown component \"%s\" ignored\n", tok);
        }
    }
    if ((present & PART_MASK) == 0) {
        uint mask = PART_MASK;

        ErrorF("Mapping needs at least one of ");
        for (int i = 0; (i < MAX_WORDS); i++) {
            if ((1L << i) & mask) {
                mask &= ~(1L << i);
                if (mask)
                    DebugF("\"%s,\" ", cname[i]);
                else
                    DebugF("or \"%s\"\n", cname[i]);
            }
        }
        DebugF("Illegal mapping ignored\n");
        remap.num_remap = 0;
        return;
    }
    if ((present & COMPONENT_MASK) == 0) {
        DebugF("Mapping needs at least one component\n");
        DebugF("Illegal mapping ignored\n");
        remap.num_remap = 0;
        return;
    }
    remap.number++;
    return;
}

private Bool MatchOneOf(const(char)* wanted, const(char)* vals_defined)
{
    int want_len = cast(int)strlen(wanted);

    const(char)* str = void, next = null;
    for (str = vals_defined; str !is null; str = next) {
        int len = void;

        next = strchr(str, ',');
        if (next) {
            len = cast(int)(next - str);
            next++;
        }
        else {
            len = cast(int)strlen(str);
        }
        if ((len == want_len) && (strncmp(wanted, str, len) == 0))
            return True;
    }
    return False;
}

/***====================================================================***/

private Bool CheckLine(InputLine* line, RemapSpec* remap, XkbRF_RulePtr rule, XkbRF_GroupPtr group)
{
    if (line && line.line && line.line[0] == '!') {
        if (line.line[1] == '$' ||
            (line.line[1] == ' ' && line.line[2] == '$')) {
            char* gname = strchr(line.line, '$');
            char* words = strchr(gname, ' ');

            if (!words)
                return False;
            *words++ = '\0';
            for (; *words; words++) {
                if (*words != '=' && *words != ' ')
                    break;
            }
            if (*words == '\0')
                return False;
            group.name = cast(char*)Xstrdup(gname);
            group.words = cast(char*)Xstrdup(words);

            int i = void;
            for (i = 1, words = group.words; *words; words++) {
                if (*words == ' ') {
                    *words++ = '\0';
                    i++;
                }
            }
            group.number = i;
            return True;
        }
        else {
            SetUpRemap(line, remap);
            return False;
        }
    }

    if (remap.num_remap == 0) {
        DebugF("Must have a mapping before first line of data\n");
        DebugF("Illegal line of data ignored\n");
        return False;
    }

    FileSpec tmp = { null };

    char* str = line.line;

    int nread = void;
    _Xstrtokparams strtok_buf = void;
    char* tok = void;
    Bool append = False;

    for (nread = 0; (tok = _XStrtok(str, " ", &strtok_buf)) !is null; nread++) {
        str = null;
        if (strcmp(tok, "=") == 0) {
            nread--;
            continue;
        }
        if (nread > remap.num_remap) {
            DebugF("Too many words on a line\n");
            DebugF("Extra word \"%s\" ignored\n", tok);
            continue;
        }
        tmp.name[remap.remap[nread].word] = tok;
        if (*tok == '+' || *tok == '|')
            append = True;
    }
    if (nread < remap.num_remap) {
        DebugF("Too few words on a line: %s\n", line.line);
        DebugF("line ignored\n");
        return False;
    }

    rule.flags = 0;
    rule.number = remap.number;
    if (tmp.name[OPTION])
        rule.flags |= XkbRF_Option;
    else if (append)
        rule.flags |= XkbRF_Append;
    else
        rule.flags |= XkbRF_Normal;
    rule.model = cast(char*)Xstrdup(tmp.name[MODEL]);
    rule.layout = cast(char*)Xstrdup(tmp.name[LAYOUT]);
    rule.variant = cast(char*)Xstrdup(tmp.name[VARIANT]);
    rule.option = cast(char*)Xstrdup(tmp.name[OPTION]);

    rule.keycodes = cast(char*)Xstrdup(tmp.name[KEYCODES]);
    rule.symbols = cast(char*)Xstrdup(tmp.name[SYMBOLS]);
    rule.types = cast(char*)Xstrdup(tmp.name[TYPES]);
    rule.compat = cast(char*)Xstrdup(tmp.name[COMPAT]);
    rule.geometry = cast(char*)Xstrdup(tmp.name[GEOMETRY]);

    rule.layout_num = rule.variant_num = 0;
    for (int i = 0; i < nread; i++) {
        if (remap.remap[i].index) {
            if (remap.remap[i].word == LAYOUT)
                rule.layout_num = remap.remap[i].index;
            if (remap.remap[i].word == VARIANT)
                rule.variant_num = remap.remap[i].index;
        }
    }
    return True;
}

private char* _Concat(char* str1, const(char)* str2)
{
    if ((!str1) || (!str2))
        return str1;
    int len = cast(int)(strlen(str1) + strlen(str2) + 1);
    str1 = cast(char*)realloc(str1, len * char.sizeof);
    if (str1)
        strcat(str1, str2);
    return str1;
}

private void squeeze_spaces(char* p1)
{
    for (char* p2 = p1; *p2; p2++) {
        *p1 = *p2;
        if (*p1 != ' ')
            p1++;
    }
    *p1 = '\0';
}

private Bool MakeMultiDefs(XkbRF_MultiDefsPtr mdefs, XkbRF_VarDefsPtr defs)
{
    memset(cast(char*) mdefs, 0, XkbRF_MultiDefsRec.sizeof);
    mdefs.model = defs.model;

    char* options = cast(char*)Xstrdup(defs.options);
    if (options)
        squeeze_spaces(options);
    mdefs.options = options;

    if (defs.layout) {
        if (!strchr(defs.layout, ',')) {
            mdefs.layout[0] = defs.layout;
        }
        else {
            char* layout = cast(char*)Xstrdup(defs.layout);
            if (layout is null)
                return False;
            squeeze_spaces(layout);
            mdefs.layout[1] = layout;
            char* p = layout;
            for (int i = 2; i <= XkbNumKbdGroups; i++) {
                if ((p = strchr(p, ',')) !is null) {
                    *p++ = '\0';
                    mdefs.layout[i] = p;
                }
                else {
                    break;
                }
            }
            if (p && (p = strchr(p, ',')) !is null)
                *p = '\0';
        }
    }

    if (defs.variant) {
        if (!strchr(defs.variant, ',')) {
            mdefs.variant[0] = defs.variant;
        }
        else {
            char* variant = cast(char*)Xstrdup(defs.variant);
            if (variant is null)
                return False;
            squeeze_spaces(variant);
            mdefs.variant[1] = variant;
            char* p = variant;
            for (int i = 2; i <= XkbNumKbdGroups; i++) {
                if ((p = strchr(p, ','))!is null) {
                    *p++ = '\0';
                    mdefs.variant[i] = p;
                }
                else {
                    break;
                }
            }
            if (p && (p = strchr(p, ','))!is null)
                *p = '\0';
        }
    }
    return True;
}

private void FreeMultiDefs(XkbRF_MultiDefsPtr defs)
{
    free(cast(void*) defs.options);
    free(cast(void*) defs.layout[1]);
    free(cast(void*) defs.variant[1]);
}

private void Apply(const(char)* src, char** dst)
{
    if (src) {
        if (*src == '+' || *src == '|') {
            *dst = _Concat(*dst, src);
        }
        else {
            if (*dst is null)
                *dst = cast(char*)Xstrdup(src);
        }
    }
}

private void XkbRF_ApplyRule(XkbRF_RulePtr rule, XkbComponentNamesPtr names)
{
    rule.flags &= ~XkbRF_PendingMatch; /* clear the flag because it's applied */

    Apply(rule.keycodes, &names.keycodes);
    Apply(rule.symbols, &names.symbols);
    Apply(rule.types, &names.types);
    Apply(rule.compat, &names.compat);
    Apply(rule.geometry, &names.geometry);
}

private Bool CheckGroup(XkbRF_RulesPtr rules, const(char)* group_name, const(char)* name)
{
    int i = void;
    char* p = void;
    XkbRF_GroupPtr group = void;

    for (i = 0, group = rules.groups; i < rules.num_groups; i++, group++) {
        if (!strcmp(group.name, group_name)) {
            break;
        }
    }
    if (i == rules.num_groups)
        return False;
    for (i = 0, p = group.words; i < group.number; i++, p += strlen(p) + 1) {
        if (!strcmp(p, name)) {
            return True;
        }
    }
    return False;
}

private int XkbRF_CheckApplyRule(XkbRF_RulePtr rule, XkbRF_MultiDefsPtr mdefs, XkbComponentNamesPtr names, XkbRF_RulesPtr rules)
{
    Bool pending = False;

    if (rule.model !is null) {
        if (mdefs.model is null)
            return 0;
        if (strcmp(rule.model, "*") == 0) {
            pending = True;
        }
        else {
            if (rule.model[0] == '$') {
                if (!CheckGroup(rules, rule.model, mdefs.model))
                    return 0;
            }
            else {
                if (strcmp(rule.model, mdefs.model) != 0)
                    return 0;
            }
        }
    }
    if (rule.option !is null) {
        if (mdefs.options is null)
            return 0;
        if ((!MatchOneOf(rule.option, mdefs.options)))
            return 0;
    }

    if (rule.layout !is null) {
        if (mdefs.layout[rule.layout_num] is null ||
            *mdefs.layout[rule.layout_num] == '\0')
            return 0;
        if (strcmp(rule.layout, "*") == 0) {
            pending = True;
        }
        else {
            if (rule.layout[0] == '$') {
                if (!CheckGroup(rules, rule.layout,
                                mdefs.layout[rule.layout_num]))
                    return 0;
            }
            else {
                if (strcmp(rule.layout, mdefs.layout[rule.layout_num]) != 0)
                    return 0;
            }
        }
    }
    if (rule.variant !is null) {
        if (mdefs.variant[rule.variant_num] is null ||
            *mdefs.variant[rule.variant_num] == '\0')
            return 0;
        if (strcmp(rule.variant, "*") == 0) {
            pending = True;
        }
        else {
            if (rule.variant[0] == '$') {
                if (!CheckGroup(rules, rule.variant,
                                mdefs.variant[rule.variant_num]))
                    return 0;
            }
            else {
                if (strcmp(rule.variant,
                           mdefs.variant[rule.variant_num]) != 0)
                    return 0;
            }
        }
    }
    if (pending) {
        rule.flags |= XkbRF_PendingMatch;
        return rule.number;
    }
    /* exact match, apply it now */
    XkbRF_ApplyRule(rule, names);
    return rule.number;
}

private void XkbRF_ClearPartialMatches(XkbRF_RulesPtr rules)
{
    int i = void;
    XkbRF_RulePtr rule = void;

    for (i = 0, rule = rules.rules; i < rules.num_rules; i++, rule++) {
        rule.flags &= ~XkbRF_PendingMatch;
    }
}

private void XkbRF_ApplyPartialMatches(XkbRF_RulesPtr rules, XkbComponentNamesPtr names)
{
    int i = void;
    XkbRF_RulePtr rule = void;

    for (rule = rules.rules, i = 0; i < rules.num_rules; i++, rule++) {
        if ((rule.flags & XkbRF_PendingMatch) == 0)
            continue;
        XkbRF_ApplyRule(rule, names);
    }
}

private void XkbRF_CheckApplyRules(XkbRF_RulesPtr rules, XkbRF_MultiDefsPtr mdefs, XkbComponentNamesPtr names, int flags)
{
    int i = void;
    XkbRF_RulePtr rule = void;
    int skip = void;

    for (rule = rules.rules, i = 0; i < rules.num_rules; rule++, i++) {
        if ((rule.flags & flags) != flags)
            continue;
        skip = XkbRF_CheckApplyRule(rule, mdefs, names, rules);
        if (skip && !(flags & XkbRF_Option)) {
            for (; (i < rules.num_rules) && (rule.number == skip);
                 rule++, i++){}
            rule--;
            i--;
        }
    }
}

/***====================================================================***/

private char* XkbRF_SubstituteVars(char* name, XkbRF_MultiDefsPtr mdefs)
{
    char* str = void, outstr = void, orig = void, var = void;
    int len = void, ndx = void;

    orig = name;
    str = index(name, '%');
    if (str is null)
        return name;
    len = cast(int)strlen(name);
    while (str !is null) {
        char pfx = str[1];
        int extra_len = 0;

        if ((pfx == '+') || (pfx == '|') || (pfx == '_') || (pfx == '-')) {
            extra_len = 1;
            str++;
        }
        else if (pfx == '(') {
            extra_len = 2;
            str++;
        }
        var = str + 1;
        str = get_index(var + 1, &ndx);
        if (ndx == -1) {
            str = index(str, '%');
            continue;
        }
        if ((*var == 'l') && mdefs.layout[ndx] && *mdefs.layout[ndx])
            len += strlen(mdefs.layout[ndx]) + extra_len;
        else if ((*var == 'm') && mdefs.model)
            len += strlen(mdefs.model) + extra_len;
        else if ((*var == 'v') && mdefs.variant[ndx] && *mdefs.variant[ndx])
            len += strlen(mdefs.variant[ndx]) + extra_len;
        if ((pfx == '(') && (*str == ')')) {
            str++;
        }
        str = index(&str[0], '%');
    }
    name = cast(char*)calloc(1, len + 1);
    str = orig;
    outstr = name;
    while (*str != '\0') {
        if (str[0] == '%') {
            char pfx = void, sfx = void;

            str++;
            pfx = str[0];
            sfx = '\0';
            if ((pfx == '+') || (pfx == '|') || (pfx == '_') || (pfx == '-')) {
                str++;
            }
            else if (pfx == '(') {
                sfx = ')';
                str++;
            }
            else
                pfx = '\0';

            var = str;
            str = get_index(var + 1, &ndx);
            if (ndx == -1) {
                continue;
            }
            if ((*var == 'l') && mdefs.layout[ndx] && *mdefs.layout[ndx]) {
                if (pfx)
                    *outstr++ = pfx;
                strcpy(outstr, mdefs.layout[ndx]);
                outstr += strlen(mdefs.layout[ndx]);
                if (sfx)
                    *outstr++ = sfx;
            }
            else if ((*var == 'm') && (mdefs.model)) {
                if (pfx)
                    *outstr++ = pfx;
                strcpy(outstr, mdefs.model);
                outstr += strlen(mdefs.model);
                if (sfx)
                    *outstr++ = sfx;
            }
            else if ((*var == 'v') && mdefs.variant[ndx] &&
                     *mdefs.variant[ndx]) {
                if (pfx)
                    *outstr++ = pfx;
                strcpy(outstr, mdefs.variant[ndx]);
                outstr += strlen(mdefs.variant[ndx]);
                if (sfx)
                    *outstr++ = sfx;
            }
            if ((pfx == '(') && (*str == ')'))
                str++;
        }
        else {
            *outstr++ = *str++;
        }
    }
    *outstr++ = '\0';
    if (orig != name)
        free(orig);
    return name;
}

/***====================================================================***/

Bool XkbRF_GetComponents(XkbRF_RulesPtr rules, XkbRF_VarDefsPtr defs, XkbComponentNamesPtr names)
{
    XkbRF_MultiDefsRec mdefs = { null };

    MakeMultiDefs(&mdefs, defs);

    memset(cast(char*) names, 0, XkbComponentNamesRec.sizeof);
    XkbRF_ClearPartialMatches(rules);
    XkbRF_CheckApplyRules(rules, &mdefs, names, XkbRF_Normal);
    XkbRF_ApplyPartialMatches(rules, names);
    XkbRF_CheckApplyRules(rules, &mdefs, names, XkbRF_Append);
    XkbRF_ApplyPartialMatches(rules, names);
    XkbRF_CheckApplyRules(rules, &mdefs, names, XkbRF_Option);
    XkbRF_ApplyPartialMatches(rules, names);

    if (names.keycodes)
        names.keycodes = XkbRF_SubstituteVars(names.keycodes, &mdefs);
    if (names.symbols)
        names.symbols = XkbRF_SubstituteVars(names.symbols, &mdefs);
    if (names.types)
        names.types = XkbRF_SubstituteVars(names.types, &mdefs);
    if (names.compat)
        names.compat = XkbRF_SubstituteVars(names.compat, &mdefs);
    if (names.geometry)
        names.geometry = XkbRF_SubstituteVars(names.geometry, &mdefs);

    FreeMultiDefs(&mdefs);
    return (names.keycodes && names.symbols && names.types &&
            names.compat && names.geometry);
}

private XkbRF_RulePtr XkbRF_AddRule(XkbRF_RulesPtr rules)
{
    if (rules.sz_rules < 1) {
        rules.sz_rules = 16;
        rules.num_rules = 0;
        if (((rules.rules = cast(_XkbRF_Rule*)calloc(rules.sz_rules, XkbRF_RuleRec.sizeof)) is null))
            return null;
    }
    else if (rules.num_rules >= rules.sz_rules) {
        rules.sz_rules *= 2;
        if (((rules.rules = cast(_XkbRF_Rule*)reallocarray(rules.rules,
                                    rules.sz_rules, XkbRF_RuleRec.sizeof)) is null))
            return null;
    }
    if (!rules.rules) {
        rules.sz_rules = rules.num_rules = 0;
        DebugF("Allocation failure in XkbRF_AddRule\n");
        return null;
    }
    memset(cast(char*) &rules.rules[rules.num_rules], 0, XkbRF_RuleRec.sizeof);
    return &rules.rules[rules.num_rules++];
}

private XkbRF_GroupPtr XkbRF_AddGroup(XkbRF_RulesPtr rules)
{
    if (rules.sz_groups < 1) {
        rules.sz_groups = 16;
        rules.num_groups = 0;
        if (((rules.groups = cast(_XkbRF_Group*)calloc(rules.sz_groups, XkbRF_GroupRec.sizeof)) is null))
            return null;
    }
    else if (rules.num_groups >= rules.sz_groups) {
        rules.sz_groups *= 2;
        if (((rules.groups = cast(_XkbRF_Group*)reallocarray(rules.groups,
                                     rules.sz_groups, XkbRF_GroupRec.sizeof)) is null))
            return null;
    }
    if (!rules.groups) {
        rules.sz_groups = rules.num_groups = 0;
        return null;
    }

    memset(cast(char*) &rules.groups[rules.num_groups], 0,
           XkbRF_GroupRec.sizeof);
    return &rules.groups[rules.num_groups++];
}

Bool XkbRF_LoadRules(FILE* file, XkbRF_RulesPtr rules)
{
    InputLine line = void;
    RemapSpec remap = void;
    XkbRF_RuleRec trule = void; XkbRF_RuleRec* rule = void;
    XkbRF_GroupRec tgroup = void; XkbRF_GroupRec* group = void;

    if (!(rules && file))
        return False;
    memset(cast(char*) &remap, 0, RemapSpec.sizeof);
    memset(cast(char*) &tgroup, 0, XkbRF_GroupRec.sizeof);
    InitInputLine(&line);
    while (GetInputLine(file, &line, True)) {
        if (CheckLine(&line, &remap, &trule, &tgroup)) {
            if (tgroup.number) {
                if ((group = XkbRF_AddGroup(rules)) !is null) {
                    *group = tgroup;
                    memset(cast(char*) &tgroup, 0, XkbRF_GroupRec.sizeof);
                }
            }
            else {
                if ((rule = XkbRF_AddRule(rules)) !is null) {
                    *rule = trule;
                    memset(cast(char*) &trule, 0, XkbRF_RuleRec.sizeof);
                }
            }
        }
        line.num_line = 0;
    }
    FreeInputLine(&line);
    return True;
}

void XkbRF_Free(XkbRF_RulesPtr rules)
{
    if (!rules)
        return;

    if (rules.rules) {
        XkbRF_RulePtr r = rules.rules;
        int num = rules.num_rules;
        for (int i = 0; i < num; i++) {
            // the typecast on free() is necessary because the pointers are const
            free(cast(void*) r[i].model);
            free(cast(void*) r[i].layout);
            free(cast(void*) r[i].variant);
            free(cast(void*) r[i].option);
            free(cast(void*) r[i].keycodes);
            free(cast(void*) r[i].symbols);
            free(cast(void*) r[i].types);
            free(cast(void*) r[i].compat);
            free(cast(void*) r[i].geometry);
        }
        free(rules.rules);
    }

    if (rules.groups) {
        XkbRF_GroupPtr g = rules.groups;
        int num = rules.num_groups;
        for (int i = 0; i < num; i++) {
            // the typecast on free() is necessary because the pointers are const
            free(cast(void*) g[i].name);
            free(g[i].words);
        }
        free(rules.groups);
    }

    free(rules);
    return;
}
