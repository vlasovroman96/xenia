module dix.rpcbuf;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

import build.dix_config;

import core.stdc.stddef;

import dix.dix_priv;
import dix.rpcbuf;
import dix.swapreq;
import common.bytes;
import common.swap;

//must be deleted after D rewriting
public import abi.common;

/*
 * buffer for easing RPC payload assembly
 *
 * the structure should be zero-initialized. subsequent operations will
 * automatically allocate enough buffer space under the hood
 *
 * Example:
 *
 * RPCBuffer x_rpcbuf buf = { 0 };
 * x_rpcbuf_write_string(&buf, "hello world");
 * x_rpcbuf_write_CARD1&(&buf, 91126);
 * ...
 * ...
 * do_write_out(buf->buffer, buf->wpos);
 * x_rpcbuf_clear(&buf);
 */

struct RPCBuffer {
    size_t wpos;    /* length of data inside the buffer / next write position */
    ubyte[] buffer;   /* pointer to whole buffer */
    bool swapped;   /* True when typed write operation shall byte-swap */
    bool error;     /* True when the last allocation failed */
    bool err_clear; /* set to True if should automatically clear on error */

    /*
    * retrieve number of 4-byte-units (padded) of data written in the buffer
    * @return          number of 4-byte units (w/ padding) written into the buffer
    */
@nogc: nothrow:
    CARD32 writedSizeUnits() => cast(CARD32) ((this.wpos + 3) / 4);

    /*
    * make sure there's enough room for `needed` bytes in the buffer.
    * @param needed    amount of free space needed in the buffer
    * @return          True if there (now) is enough room, False on alloc failure
    */
    bool makeRoom(size_t needed) {
        /* break out of alreay in error state */
        if (this.error)
            return false;

        /* still enough space */
        if (this.buffer.length > this.wpos + needed)
            return true;

        const(size_t) newsize = (((this.wpos + needed) / XLIBRE_RPCBUF_CHUNK_SIZE) + 1)
                                    * XLIBRE_RPCBUF_CHUNK_SIZE;

        ubyte* newbuf = cast(ubyte*) realloc(this.buffer.ptr, newsize);
        if (!newbuf)
            goto err;

        this.buffer = newbuf[0..newsize];

        return true;

    //Issue #70: Use scope(failure)
    err:
        this.error = true;
        if (this.err_clear) {
            free(this.buffer.ptr);
            this.buffer = null;
        }
        return false;
    }

    /*
    * reset rpcbuf and clear memory, but doesn't free it.
    *
    * this is for reusing existing buffers for different purpose, w/o
    * having to go through new allocatons.
    */
    void reset() {
        /* no need to reset if never been actually written to */
        if (!this.buffer.length || !this.wpos)
            return;

        /* clear memory, but don't free it */
        this.wpos = 0;
    }

    /*
    * clear rpcbuf and free all held memory.
    */
    void  clear() {
        free(this.buffer.ptr);
        memset(&this, 0, RPCBuffer.sizeof);
    }

    /*
    * reserve a piece of buffer and move the buffer pointer forward.
    *
    * the returned slice can be used to directly write data into the
    * reserved region. buffer pointer is moved right after that region.
    *
    * NOTE: that region is only valid until another operation on this
    * buffer that might affect the allocated memory block: when buffer
    * needs to be resized, it may get a new memory location.
    *
    * @param needed    amount of bytes needed
    * @return          reserved slice of buffer
    */
    ubyte[] reserve(size_t needed, bool fillZero = false) {
        if (!this.makeRoom(needed))
            return null;
        
        ubyte[] reserved = buffer[this.wpos..this.wpos + needed];

        if(fillZero) {
            reserved[] = 0;
        }

        this.wpos += needed;

        return reserved;
    }

    auto reserve0(size_t needed) => this.reserve(needed, true);

    /*
    * write binary data to rpc buffer and pad it.
    *
    * allocate a region for the string (padded to 32bits) and copy in the data.
    * if given data is NULL or size is zero , nothing happens.
    *
    * @param needed    string to plain C string
    * @return          True on success, False on allocation failure
    */
    bool writeBinPad(ubyte[] val, size_t padding = 0) {
        size_t blen = padForInt32(cast(int)(val.length + padding));

        auto reserved = this.reserve(blen);
        if (!reserved)
            return false;

        reserved[0..val.length] = val[];
        reserved[val.length..$] = 0;
        return true;
    }

    /*
    * pad the buffer to 4-byte-units (ie. write extra zeros if necessary)
    *
    * @param rpcbuf    pointer to RPCBuffer to operate on
    */
    void doPad() {
        this.reserve0(
            (((this.wpos + 3) / 4) * 4) - this.wpos);
    }

    /* write a plain C string to rpc buffer and pad it.
    *
    * allocate a region for the string (padded to 32bits) and copy in the string.
    * if given string is NULL or zero-size, nothing happens.
    *
    * @param str        string to plain C string
    * @return          True on success, False on allocation failure
    */
    bool writeStringPad(string str) {
        if (!str)
            return True;

        return this.writeBinPad(cast(ubyte[])str);
    }

    /*
    * write a CARD8(ubyte)
    *
    * allocate a region for CARD8 and write it into the buffer.
    *
    * doesn't do any padding.
    *
    * @param value     the CARD8 value to write
    * @return          True on success, False on allocation failure
    */
    bool writeCard8(CARD8 value) {
        auto reserved = this.reserve(value.sizeof);
        if (!reserved)
            return false;

        reserved[0] = value;
        return true;
    }

    /*
    * write a CARD16 and do byte-swapping (when needed).
    *
    * allocate a region for CARD16, write it into the buffer and do byte-swap
    * if buffer is configured to do so (`swapped` field is True).
    *
    * doesn't do any padding.
    *
    * @param value     the CARD16 value to write
    * @return          True on success, False on allocation failure
    */
    bool writeCard16(CARD16 value) {
        CARD16* reserved = cast(ushort*)this.reserve(value.sizeof).ptr;
        if (!reserved)
            return false;

        *reserved = value;

        if (this.swapped)
            swaps(reserved);

        return true;
    }

    /*
    * write a CARD32 and do byte-swapping (when needed).
    *
    * allocate a region for CARD32, write it into the buffer and do byte-swap
    * if buffer is configured to do so (`swapped` field is True).
    *
    * doesn't do any padding.
    *
    * @param value     the CARD32 value to write
    * @return          True on success, False on allocation failure
    */
    bool writeCard32(CARD32 value) {
        CARD32* reserved = cast(uint*)this.reserve(value.sizeof).ptr;
        if (!reserved)
            return false;

        *reserved = value;

        if (this.swapped)
            swapl(reserved);

        return true;
    }

    //NOT USED. REMOVE THIS?
    /*
    * write a CARD64 and do byte-swapping (when needed).
    *
    * allocate a region for CARD64, write it into the buffer and do byte-swap
    * if buffer is configured to do so (`swapped` field is True).
    *
    * doesn't do any padding.
    *
    * @param value     the CARD64 value to write
    * @return          True on success, False on allocation failure
    */
    bool writeCard64(CARD64 value) {
        CARD64* reserved = cast(ulong*)this.reserve(value.sizeof).ptr;
        if (!reserved)
            return false;

        *reserved = value;

        if (this.swapped)
            swapll(reserved);

        return true;
    }

    /*
    * write a plain C string with terminating 0 to rpc buffer and pad it.
    *
    * allocate a region for the string (padded to 32bits) and copy in the string.
    * if given string is NULL or zero-size, only a (CARD32)0 is written.
    *
    * @param needed    string to plain C string
    * @return          True on success, False on allocation failure
    */
    bool writeString0tPad(const(char)* str) {
        if (!str)
            return this.writeCard32(0);

        return this.writeBinPad(cast(ubyte[])str[0..strlen(str)], 1);
    }

    /*
    * write a INT16 and do byte-swapping (when needed).
    *
    * allocate a region for INT16, write it into the buffer and do byte-swap
    * if buffer is configured to do so (`swapped` field is True).
    *
    * doesn't do any padding.
    *
    * @param value     the CARD16 value to write
    * @return          True on success, False on allocation failure
    */
    bool writeInt16(INT16 value) {
        return this.writeCard16(cast(CARD16)value);
    }

    /*
    * write an X11 RECTANGLE protocol structure into the buffer
    *
    * @param x         X value of the rectangle
    * @param y         Y value of the rectangle
    * @param width     WIDTH value of the rectangle
    * @param height    HEIGHT value of the rectangle
    */
    void writeProtoRect(INT16 x, INT16 y, CARD16 width, CARD16 height) {
        this.writeInt16(x);
        this.writeInt16(y);
        this.writeCard16(width);
        this.writeCard16(height);
    }
}

enum XLIBRE_RPCBUF_CHUNK_SIZE = 4096;

/*
 * write a Pascal-like counted string, starting with CARD16 couter,
 * followed by the char bytes, padded to full protocol units (4-bytes).
 *
 * if str is NULL, don't write anything
 *
 * @param rpcbuf    pointer to the RPCBuffer to operate on
 * @param str       zero-terminated string to write into the buffer
 */
pragma(inline, true) void x_rpcbuf_write_counted_string_pad(RPCBuffer* rpcbuf, const(char)* str)
{
    if (str) {
        CARD16 len = cast(CARD16)strlen(str); /* 64k should really be enough */
        rpcbuf.writeCard16(len);
        x_rpcbuf_write_CARD8s(rpcbuf, cast(CARD8*)str, len);
        rpcbuf.doPad();
    }
}

/*
 * write contents of an rpcbuf into another one (padded) and clear the source buffer
 *
 * @param rpcbuf    pointer to the RPCBuffer to operate on
 * @param source    pointer to source RPCBuffer
 */
pragma(inline, true) void x_rpcbuf_write_rpcbuf_pad(RPCBuffer* rpcbuf, RPCBuffer* source)
{
    if (!source)
        return;

    if (source.error) {
        rpcbuf.error = True;
        if (rpcbuf.err_clear) {
            free(rpcbuf.buffer.ptr);
            rpcbuf.buffer = null;
        }
    } else {
        x_rpcbuf_write_binary_pad(rpcbuf, source.buffer.ptr, source.wpos);
    }
    source.clear();
}

/*
 * write a INT32 and do byte-swapping (when needed).
 *
 * allocate a region for INT32, write it into the buffer and do byte-swap
 * if buffer is configured to do so (`swapped` field is True).
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param value     the CARD16 value to write
 * @return          True on success, False on allocation failure
 */
pragma(inline, true) Bool x_rpcbuf_write_INT32(RPCBuffer* rpcbuf, INT32 value) {
    return rpcbuf.writeCard32(cast(CARD32)value);
}

/*
 * write array of INT32s and do byte-swapping (when needed).
 *
 * allocate a region for INT32s, write them into the buffer and do byte-swap
 * if buffer is configured to do so (`swapped` field is True).
 * when `values` or `count` are zero, does nothing.
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param values    pointer to INT32 array to write
 * @param count     number of elements in the array
 * @return          True on success, False on allocation failure
 */
pragma(inline, true) Bool x_rpcbuf_write_INT32s(RPCBuffer* rpcbuf, const(INT32)* values, size_t count)
{
    return x_rpcbuf_write_CARD32s(rpcbuf, cast(CARD32*)values, count);
}

/*
 * write array of CARD8s and do byte-swapping (when needed).
 *
 * allocate a region for CARD8, write them into the buffer.
 * when `values` or `count` are zero, does nothing.
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param values    pointer to CARD16 array to write
 * @param count     number of elements in the array
 * @return          True on success, False on allocation failure
 */
Bool  x_rpcbuf_write_CARD8s(RPCBuffer* rpcbuf, const(CARD8)* values, size_t count)
{
    if ((!values) || (!count))
        return True;

    INT16* reserved = cast(short*)rpcbuf.reserve(count).ptr;
    if (!reserved)
        return False;

    memcpy(reserved, values, count);

    return True;
}

/*
 * write array of CARD16s and do byte-swapping (when needed).
 *
 * allocate a region for CARD16s, write them into the buffer and do byte-swap
 * if buffer is configured to do so (`swapped` field is True).
 * when `values` or `count` are zero, does nothing.
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param values    pointer to CARD16 array to write
 * @param count     number of elements in the array
 * @return          True on success, False on allocation failure
 */
Bool x_rpcbuf_write_CARD16s(RPCBuffer* rpcbuf, const(CARD16)* values, size_t count)
{
    if ((!values) || (!count))
        return True;

    INT16* reserved = cast(short*)rpcbuf.reserve(((CARD16).sizeof * count)).ptr;
    if (!reserved)
        return False;

    memcpy(reserved, values, ((CARD16).sizeof * count));

    if (rpcbuf.swapped)
        SwapShorts(reserved, count);

    return True;
}

/*
 * write array of CARD32s and do byte-swapping (when needed).
 *
 * allocate a region for CARD32s, write them into the buffer and do byte-swap
 * if buffer is configured to do so (`swapped` field is True).
 * when `values` or `count` are zero, does nothing.
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param values    pointer to CARD32 array to write
 * @param count     number of elements in the array
 * @return          True on success, False on allocation failure
 */
Bool  x_rpcbuf_write_CARD32s(RPCBuffer* rpcbuf, const(CARD32)* values, size_t count)
{
    if ((!values) || (!count))
        return True;

    CARD32* reserved = cast(uint*)rpcbuf.reserve(((CARD32).sizeof * count)).ptr;
    if (!reserved)
        return False;

    memcpy(reserved, values, ((CARD32).sizeof * count));

    if (rpcbuf.swapped)
        SwapLongs(reserved, count);

    return True;
}

/*
 * write array of CARD64s and do byte-swapping (when needed).
 *
 * allocate a region for CARD64s, write them into the buffer and do byte-swap
 * if buffer is configured to do so (`swapped` field is True).
 * when `values` or `count` are zero, does nothing.
 *
 * doesn't do any padding.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param values    pointer to CARD64 array to write
 * @param count     number of elements in the array
 * @return          True on success, False on allocation failure
 */
Bool x_rpcbuf_write_CARD64s(RPCBuffer* rpcbuf, const(CARD64)* values, size_t count)
{
    if ((!values) || (!count))
        return True;

    CARD64* reserved = cast(ulong*)rpcbuf.reserve(((CARD64).sizeof * count)).ptr;
    if (!reserved)
        return False;

    memcpy(reserved, values, ((CARD64).sizeof * count));

    if (rpcbuf.swapped)
        for (size_t x = 0; x<count; x++)
            swapll(&reserved[x]);

    return True;
}

/*
 * write binary data to rpc buffer and pad it.
 *
 * allocate a region for the string (padded to 32bits) and copy in the data.
 * if given data is NULL or size is zero , nothing happens.
 *
 * @param rpcbuf    pointer to RPCBuffer to operate on
 * @param needed    string to plain C string
 * @return          True on success, False on allocation failure
 */
Bool x_rpcbuf_write_binary_pad(RPCBuffer* rpcbuf, const(void)* values, size_t size)
{
    if ((!values) || (!size))
        return True;

    return rpcbuf.writeBinPad(cast(ubyte[])values[0..size]);
}
