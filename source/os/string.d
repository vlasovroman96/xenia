module os.string;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 1987, 1998  The Open Group
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
import build.dix_config;

import core.stdc.stdlib;
import core.stdc.string;

import os.fmt;

import os.os;
import os.log;

char* Xstrdup(const(char)* s)
{
    if (s is null)
        return null;
    return strdup(s);
}

char* XNFstrdup(const(char)* s)
{
    char* ret = void;

    if (s is null)
        return null;

    ret = strdup(s);
    if (!ret)
        FatalError("XNFstrdup: Out of memory");
    return ret;
}

/*
 * Tokenize a string into a NULL terminated array of strings. Always returns
 * an allocated array unless an error occurs.
 */
char** xstrtokenize(const(char)* str, const(char)* separators)
{
    char** list = void, nlist = void;
    char* tok = void, tmp = void;
    uint num = 0, n = void;

    if (!str)
        return null;
    list = cast(char**) calloc(1, typeof(*list).sizeof);
    if (!list)
        return null;
    tmp = strdup(str);
    if (!tmp)
        goto error;
    for (tok = strtok(tmp, separators); tok; tok = strtok(null, separators)) {
        nlist = cast(char**)reallocarray(list, num + 2, typeof(*list).sizeof);
        if (!nlist)
            goto error;
        list = nlist;
        list[num] = strdup(tok);
        if (!list[num])
            goto error;
        list[++num] = null;
    }
    free(tmp);
    return list;

 error:
    free(tmp);
    for (n = 0; n < num; n++)
        free(list[n]);
    free(list);
    return null;
}
