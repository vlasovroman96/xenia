module rpcbuf;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
import build.dix_config;

import core.stdc.stddef;

import dix.dix_priv;
import dix.rpcbuf_priv;
import dix.swapreq;
import common.bytes;
import common.swap;

pragma(inline, true) Bool __x_rpcbuf_write_bin_pad(x_rpcbuf_t* rpcbuf, const(char)* val, size_t len)
{
    const(size_t) blen = padForInt32(cast(int)len);

    char* reserved = cast(char*)x_rpcbuf_reserve(rpcbuf, blen);
    if (!reserved)
        return FALSE;

    memcpy(reserved, val, len);
    memset(reserved + len, 0, blen - len);
    return TRUE;
}

Bool x_rpcbuf_makeroom(x_rpcbuf_t* rpcbuf, size_t needed)
{
    /* break out of alreay in error state */
    if (rpcbuf.error)
        return FALSE;

    /* still enough space */
    if (rpcbuf.size > rpcbuf.wpos + needed)
        return TRUE;

    const(size_t) newsize = (((rpcbuf.wpos + needed) / XLIBRE_RPCBUF_CHUNK_SIZE) + 1)
                                * XLIBRE_RPCBUF_CHUNK_SIZE;

    char* newbuf = cast(char*) realloc(rpcbuf.buffer, newsize);
    if (!newbuf)
        goto err;

    rpcbuf.buffer = newbuf;
    rpcbuf.size = newsize;

    return TRUE;

err:
    rpcbuf.error = TRUE;
    if (rpcbuf.err_clear) {
        free(rpcbuf.buffer);
        rpcbuf.buffer = null;
    }
    return FALSE;
}

void  x_rpcbuf_clear(x_rpcbuf_t* rpcbuf)
{
    free(rpcbuf.buffer);
    memset(rpcbuf, 0, x_rpcbuf_t.sizeof);
}

void x_rpcbuf_reset(x_rpcbuf_t* rpcbuf)
{
    /* no need to reset if never been actually written to */
    if ((!rpcbuf.buffer) || (!rpcbuf.size) || (!rpcbuf.wpos))
        return;

    /* clear memory, but don't free it */
    rpcbuf.wpos = 0;
}

void* x_rpcbuf_reserve(x_rpcbuf_t* rpcbuf, size_t needed)
{
    if (!x_rpcbuf_makeroom(rpcbuf, needed))
        return null;

    void* pos = rpcbuf.buffer + rpcbuf.wpos;
    rpcbuf.wpos += needed;

    return pos;
}

void * x_rpcbuf_reserve0(x_rpcbuf_t* rpcbuf, size_t needed)
{
    void* buf = x_rpcbuf_reserve(rpcbuf, needed);
    if (!buf)
        return null;

    memset(buf, 0, needed);
    return buf;
}

Bool x_rpcbuf_write_string_pad(x_rpcbuf_t* rpcbuf, const(char)* str)
{
    if (!str)
        return TRUE;

    return __x_rpcbuf_write_bin_pad(rpcbuf, str, strlen(str));
}

int x_rpcbuf_write_string_0t_pad(x_rpcbuf_t* rpcbuf, const(char)* str)
{
    if (!str)
        return x_rpcbuf_write_CARD32(rpcbuf, 0);

    return __x_rpcbuf_write_bin_pad(rpcbuf, str, strlen(str)+1);
}

Bool x_rpcbuf_write_CARD8(x_rpcbuf_t* rpcbuf, CARD8 value)
{
    CARD8* reserved = cast(ubyte*)x_rpcbuf_reserve(rpcbuf, value.sizeof);
    if (!reserved)
        return FALSE;

    *reserved = value;

    return TRUE;
}

Bool x_rpcbuf_write_CARD16(x_rpcbuf_t* rpcbuf, CARD16 value)
{
    CARD16* reserved = cast(ushort*)x_rpcbuf_reserve(rpcbuf, value.sizeof);
    if (!reserved)
        return FALSE;

    *reserved = value;

    if (rpcbuf.swapped)
        swaps(reserved);

    return TRUE;
}

int x_rpcbuf_write_CARD32(x_rpcbuf_t* rpcbuf, CARD32 value)
{
    CARD32* reserved = cast(uint*)x_rpcbuf_reserve(rpcbuf, value.sizeof);
    if (!reserved)
        return FALSE;

    *reserved = value;

    if (rpcbuf.swapped)
        swapl(reserved);

    return TRUE;
}

Bool x_rpcbuf_write_CARD64(x_rpcbuf_t* rpcbuf, CARD64 value)
{
    CARD64* reserved = cast(ulong*)x_rpcbuf_reserve(rpcbuf, value.sizeof);
    if (!reserved)
        return FALSE;

    *reserved = value;

    if (rpcbuf.swapped)
        swapll(reserved);

    return TRUE;
}

Bool  x_rpcbuf_write_CARD8s(x_rpcbuf_t* rpcbuf, const(CARD8)* values, size_t count)
{
    if ((!values) || (!count))
        return TRUE;

    INT16* reserved = cast(short*)x_rpcbuf_reserve(rpcbuf, count);
    if (!reserved)
        return FALSE;

    memcpy(reserved, values, count);

    return TRUE;
}

Bool x_rpcbuf_write_CARD16s(x_rpcbuf_t* rpcbuf, const(CARD16)* values, size_t count)
{
    if ((!values) || (!count))
        return TRUE;

    INT16* reserved = cast(short*)x_rpcbuf_reserve(rpcbuf, ((CARD16).sizeof * count));
    if (!reserved)
        return FALSE;

    memcpy(reserved, values, ((CARD16).sizeof * count));

    if (rpcbuf.swapped)
        SwapShorts(reserved, count);

    return TRUE;
}

Bool  x_rpcbuf_write_CARD32s(x_rpcbuf_t* rpcbuf, const(CARD32)* values, size_t count)
{
    if ((!values) || (!count))
        return TRUE;

    CARD32* reserved = cast(uint*)x_rpcbuf_reserve(rpcbuf, ((CARD32).sizeof * count));
    if (!reserved)
        return FALSE;

    memcpy(reserved, values, ((CARD32).sizeof * count));

    if (rpcbuf.swapped)
        SwapLongs(reserved, count);

    return TRUE;
}

Bool x_rpcbuf_write_CARD64s(x_rpcbuf_t* rpcbuf, const(CARD64)* values, size_t count)
{
    if ((!values) || (!count))
        return TRUE;

    CARD64* reserved = cast(ulong*)x_rpcbuf_reserve(rpcbuf, ((CARD64).sizeof * count));
    if (!reserved)
        return FALSE;

    memcpy(reserved, values, ((CARD64).sizeof * count));

    if (rpcbuf.swapped)
        for (size_t x = 0; x<count; x++)
            swapll(&reserved[x]);

    return TRUE;
}

Bool x_rpcbuf_write_binary_pad(x_rpcbuf_t* rpcbuf, const(void)* values, size_t size)
{
    if ((!values) || (!size))
        return TRUE;

    return __x_rpcbuf_write_bin_pad(rpcbuf,cast(const char*) values, size);
}
