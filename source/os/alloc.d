module os.alloc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 1987, 1998  The Open Group
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
import build.dix_config;

import core.stdc.stdlib;

import os.os;
import os.osdep;
import os.log;
import os.access;

void* XNFalloc(c_ulong amount)
{
    void* ptr = calloc(1, amount);

    if (!ptr)
        FatalError("Out of memory");
    return ptr;
}

/* The original XNFcalloc was used with the xnfcalloc macro which multiplied
 * the arguments at the call site without allowing calloc to check for overflow.
 * XNFcallocarray was added to fix that without breaking ABI.
 */
void* XNFcalloc(c_ulong amount)
{
    return XNFcallocarray(1, amount);
}

void* XNFcallocarray(size_t nmemb, size_t size)
{
    void* ret = calloc(nmemb, size);

    if (!ret)
        FatalError("XNFcalloc: Out of memory");
    return ret;
}

void* XNFrealloc(void* ptr, c_ulong amount)
{
    void* ret = realloc(ptr, amount);

    if (!ret)
        FatalError("XNFrealloc: Out of memory");
    return ret;
}

void* XNFreallocarray(void* ptr, size_t nmemb, size_t size)
{
    void* ret = reallocarray(ptr, nmemb, size);

    if (!ret)
        FatalError("XNFreallocarray: Out of memory");
    return ret;
}
