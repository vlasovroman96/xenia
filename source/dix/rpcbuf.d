module dix.rpcbuf;

/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

import x11.Xmd; //CARD(8/16/32/64) types

import core.stdc.stdlib : realloc, free;
import core.stdc.string : memset;

import common.bytes : padForInt32;
import common.swap; //swap funcs

//must be deleted after D rewriting
public import abi.common : charsToString;

struct RPCBuffer {
    enum ChunkSize = 4096;

    size_t wpos;    /* length of data inside the buffer / next write position */
    ubyte[] buffer;   /* pointer to whole buffer */
    bool swapped;   /* true when typed write operation shall byte-swap */
    bool error;     /* true when the last allocation failed */
    bool err_clear; /* set to true if should automatically clear on error */

    /*
    * retrieve number of 4-byte-units (padded) of data written in the buffer
    * @return          number of 4-byte units (w/ padding) written into the buffer
    */
@nogc: nothrow:
    CARD32 writedSizeUnits() => cast(CARD32) ((this.wpos + 3) / 4);

    /*
    * make sure there's enough room for `needed` bytes in the buffer.
    * @param needed    amount of free space needed in the buffer
    * @return          true if there (now) is enough room, false on alloc failure
    */
    bool makeRoom(size_t needed) {
        /* break out of alreay in error state */
        if (this.error)
            return false;

        /* still enough space */
        if (this.buffer.length > this.wpos + needed)
            return true;

        const(size_t) newsize = (((this.wpos + needed) / ChunkSize) + 1)
                                    * ChunkSize;

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

    /** 
     * reserve a piece of buffer and move the buffer pointer forward.
     * 
     * Params:
     *   needed = needed size
     *   fillZero = true if filling by zeroes is needed
     * Returns:
     *   reserved slice of ubyte[] 
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
    * @return          true on success, false on allocation failure
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
    * @return          true on success, false on allocation failure
    */
    bool writeStringPad(string str) {
        if (!str)
            return true;

        return this.writeBinPad(cast(ubyte[])str);
    }

    /** 
     * 
     * Params:
     *      value = CARD8/CARD16/CARD32/CARD64 value
     * Returns: 
     *      true if data have been writed
     */
    bool writeCardN(T) (T value) {
        T* reserved = cast(T*)this.reserve(value.sizeof).ptr;
        if (!reserved)
            return false;

        *reserved = value;

        if (!is(T == CARD8) && this.swapped) {
            static if(is(T == CARD16))
                swaps(reserved);
            else static if(is(T == CARD32))
                swapl(reserved);
            else
                swapll(reserved);
        }

        return true;
    }

    //alias for writeCardN
    bool writeCard8(CARD8 value) => writeCardN(value);

    //alias for writeCardN
    bool writeCard16(CARD16 value) => writeCardN(value);

    //alias for writeCardN
    bool writeCard32(CARD32 value) => writeCardN(value);

    //NOT USED. REMOVE THIS?
    //alias for writeCardN
    bool writeCard64(CARD64 value) => writeCardN(value);

    /** 
     * Writes CARD* arrays to the buffer with swapping if needed
     * 
     * Params:
     *      values = slice of T (CARD8/CARD16/CARD32/CARD64)
     * Returns: 
     *      true if data have been written
     */
    bool writeCardNs(T)(const(T[]) values) {
        //empty slice
        if (!values)
            return true;

        CARD8[] rawReserve = this.reserve(T.sizeof * values.length);
        // CARD8[] rawReserve = this.reserve(values[].sizeof);

        //reserving error
        if (!rawReserve)
            return false;

        rawReserve[] = cast(CARD8[])values[];

        if (!is(T == CARD8) && this.swapped) {
            T[] reserved = cast(T[])rawReserve;
         
            foreach(ref T val; reserved) {
                static if(is(T == CARD16))
                    swaps(&val);
                else static if(is(T == CARD32))
                    swapl(&val);
                else
                    swapll(&val);
            }
        }

        return true;
    }

    //alias for writeCardNs
    bool writeCard8s(CARD8* values, size_t count)
        => writeCardNs(values[0..count]);

    //alias for writeCardNs
    bool writeCard16s(CARD16* values, size_t count)
        => writeCardNs(values[0..count]);

    //alias for writeCardNs
    bool  writeCard32s(CARD32* values, size_t count)
        => writeCardNs(values[0..count]);

    //alias for writeCardNs
    bool writeCard64s(CARD64* values, size_t count)
        => writeCardNs(values[0..count]);

    //alias for this.writeCard16
    bool writeInt16(INT16 value) => this.writeCard16(cast(CARD16)value);

    //alias for this.writeCard32
    bool writeInt32(INT32 value) => this.writeCard32(cast(CARD32)value);

    //alias for writeCard32s
    bool writeInt32s(const(INT32)* values, size_t count)
        => this.writeCard32s(cast(CARD32*)values, count);

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

    /*
    * write a plain C string with terminating 0 to rpc buffer and pad it.
    *
    * allocate a region for the string (padded to 32bits) and copy in the string.
    * if given string is NULL or zero-size, only a (CARD32)0 is written.
    *
    * @param needed    string to plain C string
    * @return          true on success, false on allocation failure
    */
    bool writeString0tPad(string str) {
        if (!str)
            return this.writeCard32(0);

        return this.writeBinPad(cast(ubyte[])str, 1);
    }

    /*
    * write a Pascal-like counted string, starting with CARD16 couter,
    * followed by the char bytes, padded to full protocol units (4-bytes).
    *
    * if str is NULL, don't write anything
    *
    * @param rpcbuf    pointer to the RPCBuffer to operate on
    * @param str       zero-terminated string to write into the buffer
    */
    deprecated("Use writeCountedStringPad(string str)")
    void writeCountedStringPad(const(char)* str) =>
        writeCountedStringPad(str.charsToString());

    void writeCountedStringPad(string str) {
        if (str) {
            CARD16 len = cast(CARD16)str.length; /* 64k should really be enough */
            this.writeCard16(len);
            this.writeCard8s(cast(CARD8*)str.ptr, len);
            this.doPad();
        }
    }

    /** 
     * write binary data to rpc buffer and pad it.
     * 
     * Params:
     *   values = type-unified slice ov void[]
     * Returns: 
     *   true on success
     */
    deprecated("Use writeBinaryPad(void[] values)")
    bool writeBinaryPad(const(void)* values, size_t size) =>
        writeBinaryPad(cast(void[])values[0..size]);

    bool writeBinaryPad(void[] values) {
        if (!values)
            return true;

        return this.writeBinPad(cast(ubyte[])values);
    }

    /*
    * write contents of an rpcbuf into another one (padded) and clear the source buffer
    *
    * @param rpcbuf    pointer to the RPCBuffer to operate on
    * @param source    pointer to source RPCBuffer
    */
    void moveFromBuffer(RPCBuffer* source) {
        if (!source)
            return;

        if (source.error) {
            this.error = true;
            if (this.err_clear) {
                free(this.buffer.ptr);
                this.buffer = null;
            }
        } else {
            this.writeBinaryPad(source.buffer[0..source.wpos]);
        }
        source.clear();
    }
}

enum XLIBRE_RPCBUF_CHUNK_SIZE = 4096;

