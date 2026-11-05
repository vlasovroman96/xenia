module patterns;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT or X11
 *
 * Copyright (c) 2025 Oleh Nykyforchyn <oleh.nyk@gmail.com>
 *
 */
import build.xorg_config;

import core.stdc.stdio;
import core.stdc.stdlib;
import common.misc;
import xf86Parser_priv;
import configProcs;
import include.os;
import os.log;
import xf86Parser_priv;


/*
 *  Utilities used by InputClass.c and OutputClass.c
 */

/* A group (which is a struct xf86MatchGroup) represents a complex condition
 * that should be satisfied if is_negated_is true or should not be satisfied
 * otherwise, for an input or output device to be accepted. A group contains
 * an xorg_list patterns.
 *
 * Each pattern (a struct xf86MatchPattern) is a subcondition. The logical value
 * of a group is true if and only if at least one subcondition is true, i.e.,
 * the patterns are combined by logical 'OR', which is represented by '|' in
 * the string that defines a group.
 *
 * If a string that defines a pattern is preceded by '!', then the logical
 * value of the pattern is negated. Note that a second '!' does not cancel
 * the first one, so '!!' does not make sense.
 *
 * A string correponding to a pattern (after an eventual '!') can be treated
 * either as a regular expression, if it is prepended with '~', or otherwise
 * as a string with which an attribute of a device is compared.
 * The mode of comparison is of the type enum xf86MatchMode and depends on
 * the type of the attribute.
 *
 * If a string is not a regular expression but contains one or more '&'s, then
 * it is treated as a sequence of &'-separated substrings that should ALL be
 * present in an attribute (in arbitrary places and order) for the logical value
 * to be positive (so empty substrings are inessential and dropped).
 * They are kept in pattern.str '\0'-separated, with a final second '\0'.
 */

enum LOG_OR = '|';
enum LOG_AND = '&';

enum NEG_FLAG = '!';
enum REGEX_FLAG = '~';


xf86MatchGroup* xf86createMatchGroup(const(char)* arg, xf86MatchMode pref_mode, Bool negated)
 {
    xf86MatchPattern* pattern = void;
    xf86MatchGroup* group = void;
    const(char)* str = arg;
    uint n = void;
    static const(char)[2] sep_or = [ LOG_OR,  '\0' ];
    static const(char)[2] sep_and = [ LOG_AND, '\0' ];

    if (!str)
        return null;

    group = cast(xf86MatchGroup*) malloc(typeof(*group).sizeof);
    if (!group) return null;
    xorg_list_init(&group.patterns);
    xorg_list_init(&group.entry);
    group.is_negated = negated;

  again:
    /* start new pattern */
    if ((pattern = cast(xf86MatchPattern*) malloc(typeof(*pattern).sizeof)) is null)
        goto fail;

    xorg_list_add(&pattern.entry, &group.patterns);

    /* Pattern starting with '!' should NOT be matched */
    if (*str == NEG_FLAG) {
        pattern.is_negated = TRUE;
        str++;
    }
    else
        pattern.is_negated = FALSE;

    pattern.str = null;
    pattern.regex = null;

    /* Check if there is a regex prefix */
    if (*str == REGEX_FLAG) {
        pattern.mode = MATCH_REGEX;
        str ++;
        if (*str) {
            char* last = void;
            last = cast(char*)strchr(str+1, *str);
            if (last)
                n = cast(uint)(last-str-1);
            else
                n = cast(uint)strlen(str+1);
            pattern.str = strndup(str+1, n);
            if (pattern.str is null)
                goto fail;
            *(pattern.str+n) = '\0';
            str += n+1;
            if (*str) str++;
        }
        else {
        /* no regex, notning to match against */
            pattern.mode = MATCH_IS_INVALID;
            LogMessageVerb(X_ERROR, 1,
                "No regular expression supplied after \'%c\' in \"%s\", ignoring\n",
                REGEX_FLAG, arg);
            free(pattern.str);
            pattern.str = null;
        }
    }
    else {
        n = cast(uint)strcspn(str, sep_or.ptr);
        if (n > strcspn(str, sep_and.ptr)) {
            pattern.mode = MATCH_SUBSTRINGS_SEQUENCE;
            pattern.str = cast(char*)malloc(n+2);
            if (pattern.str) {
                char* s = void, d = void;
                strncpy(pattern.str, str, n);
                str += n;
                *(pattern.str+n) = '\0';
                s = d = pattern.str;
                n = 0;
              next_chunk:
                while ((*s) && (*s != LOG_AND)) {
                    if (n == -1) {
                        *(d++) = '\0';
                        n = 0;
                    }
                    *(d++) = *(s++);
                    n++;
                }
                while ((*s) == LOG_AND) s++;
                if (*s) {
                    n = -1;
                    goto next_chunk;
                }
                if (d == pattern.str) {
                /* All chunks are empty */
                    pattern.mode = MATCH_IS_INVALID;
                    LogMessageVerb(X_ERROR, 1,
                        "No non-empty substrings supplied in the alternative \"%s\" of \"%s\", ignoring\n",
                        pattern.str, arg);
                }
                *(++d) = '\0';
            }
            else
                goto fail;
        }
        else {
            pattern.mode = pref_mode;
            pattern.str = strndup(str, n);
            if (pattern.str is null)
                goto fail;
            *(pattern.str+n) = '\0'; /* should already be, but to be sure */
            str += n;
        }
    }

    while (*str == LOG_OR)
        str++;

    if (*str)
        goto again;

    return group;

  fail:
    xf86freeMatchGroup(group);
    return null;
}

void xf86printMatchPattern(FILE* cf, const(xf86MatchPattern)* pattern, Bool not_first)
{
    if (!pattern) return;
    if (not_first)
        fprintf(cf, "%c", LOG_OR);
    if (pattern.is_negated)
        fprintf(cf, "%c", NEG_FLAG);
    if (pattern.mode == MATCH_IS_INVALID)
        fprintf(cf, "invalid:%s",
            pattern.str ? pattern.str : "(none)");
    else if (pattern.mode == MATCH_REGEX)
    /* FIXME: Hope there is no '~' in the pattern */
        fprintf(cf, "%c%s%c", REGEX_FLAG,
            pattern.str ? pattern.str : "(none)".ptr, REGEX_FLAG);
    else if (pattern.mode == MATCH_SUBSTRINGS_SEQUENCE) {
        Bool after = FALSE;
        char* str = cast(char*)pattern.str;
        while (*str) {
            if (after)
                fprintf(cf, "%c", LOG_AND);
            fprintf(cf, "%s", str);
            str += strlen(str);
            str++;
            after = TRUE;
        }
    }
    else
        fprintf(cf, "%s",
            pattern.str ? pattern.str : "(none)");
}
