module glx.indirect_util;
@nogc nothrow:
extern(C): __gshared:
/*
 * (C) Copyright IBM Corporation 2005
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sub license,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.  IN NO EVENT SHALL
 * IBM,
 * AND/OR THEIR SUPPLIERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import build.dix_config;

import core.stdc.inttypes;
import core.stdc.string;
//import x11.Xmd; // needs to be before glxproto.h
// import externs.gl;
import externs.glxproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;

import glx.indirect_size;
import glx.indirect_size_get;
import glx.indirect_dispatch;
import glx.glxserver;
import glx.singlesize;
import glx.glxext;
import glx.indirect_table;
import glx.indirect_util;
import common.bytes;
 import Xext.glx.fix;
 import core.stdc.stdint;
 import os.io;
import common.swap;
import common.bools;

 alias SIZE_MAX = core.stdc.stdint.SIZE_MAX;


//import externs.GL.glx;
//import externs.GL.gl;


enum string __GLX_PAD(string a) = `(((` ~ a ~ `)+3)&~3)`;

GLint __glGetBooleanv_variable_size(GLenum e)
{
    if (e == GL_COMPRESSED_TEXTURE_FORMATS) {
        GLint temp = void;

        glGetIntegerv(GL_NUM_COMPRESSED_TEXTURE_FORMATS, &temp);
        return temp;
    }
    else {
        return 0;
    }
}

/**
 * Get a properly aligned buffer to hold reply data.
 *
 * \warning
 * This function assumes that \c local_buffer is already properly aligned.
 * It also assumes that \c alignment is a power of two.
 */
void* __glXGetAnswerBuffer(__GLXclientState* cl, size_t required_size, void* local_buffer, size_t local_size, uint alignment)
{
    void* buffer = local_buffer;
    const(intptr_t) mask = alignment - 1;

    if (local_size < required_size) {
        size_t worst_case_size = void;
        intptr_t temp_buf = void;

        if (required_size < SIZE_MAX - alignment)
            worst_case_size = required_size + alignment;
        else
            return null;

        if (cl.returnBufSize < worst_case_size) {
            void* temp = realloc(cl.returnBuf, worst_case_size);

            if (temp is null) {
                return null;
            }

            cl.returnBuf = cast(byte*)temp;
            cl.returnBufSize = cast(int)worst_case_size;
        }

        temp_buf = cast(intptr_t) cl.returnBuf;
        temp_buf = (temp_buf + mask) & ~mask;
        buffer = cast(void*) temp_buf;
    }

    return buffer;
}

/**
 * Send a GLX reply to the client.
 *
 * Technically speaking, there are several different ways to encode a GLX
 * reply.  The primary difference is whether or not certain fields (e.g.,
 * retval, size, and "pad3") are set.  This function gets around that by
 * always setting all of the fields to "reasonable" values.  This does no
 * harm to clients, but it does make the server-side code much more compact.
 */
void __glXSendReply(ClientPtr client, const(void)* data, size_t elements, size_t element_size, GLboolean always_array, CARD32 retval)
{
    size_t reply_ints = 0;

    if (__glXErrorOccured()) {
        elements = 0;
    }
    else if ((elements > 1) || always_array) {
        reply_ints = int32ForBytes(elements * element_size);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    /* data should already be padded */
    x_rpcbuf_write_CARD8s(&rpcbuf, cast(ubyte*)data, reply_ints * 4);

    xGLXSingleReply reply = {
        size: cast(uint)elements,
        retval: cast(uint)retval,
    };

    /* Single element goes in reply padding; don't leak uninitialized data. */
    if (elements == 1) {
        cast(void) memcpy(&reply.pad3, data, element_size);
    }

    mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf")~";");
}

/**
 * Send a GLX reply to the client.
 *
 * Technically speaking, there are several different ways to encode a GLX
 * reply.  The primary difference is whether or not certain fields (e.g.,
 * retval, size, and "pad3") are set.  This function gets around that by
 * always setting all of the fields to "reasonable" values.  This does no
 * harm to clients, but it does make the server-side code much more compact.
 *
 * \warning
 * This function assumes that values stored in \c data will be byte-swapped
 * by the caller if necessary.
 */
alias CARD32 = x11.Xmd.CARD32;

void __glXSendReplySwap(ClientPtr client, const(void)* data, size_t elements, size_t element_size, GLboolean always_array, CARD32 retval)
{
    size_t reply_ints = 0;

    if (__glXErrorOccured()) {
        elements = 0;
    }
    else if ((elements > 1) || always_array) {
        reply_ints = int32ForBytes(elements * element_size);
    }

    xGLXSingleReply reply = {
        length: bswap_32(cast(uint)reply_ints),
        type: X_Reply,
        sequenceNumber: bswap_16(cast(ushort)client.sequence),
        size: bswap_32(cast(uint)elements),
        retval: bswap_32(cast(uint)retval),
    };

    /* Single element goes in reply padding; don't leak uninitialized data. */
    if (elements == 1) {
        cast(void) memcpy(&reply.pad3, data, element_size);
    }
    WriteToClient(client, xGLXSingleReply.sizeof, &reply);

    if (reply_ints != 0) {
        WriteToClient(client, cast(int)(reply_ints * 4), data);
    }
}

private int get_decode_index(const(__glXDispatchInfo)* dispatch_info, uint opcode)
{
    int remaining_bits = void;
    int next_remain = void;
    const(int_fast16_t*) tree = dispatch_info.dispatch_tree;
    int_fast16_t index = void;

    remaining_bits = dispatch_info.bits;
    if (opcode >= (1U << remaining_bits)) {
        return -1;
    }

    index = 0;
    for ( /* empty */ ; remaining_bits > 0; remaining_bits = next_remain) {
        uint mask = void;
        uint child_index = void;

        /* Calculate the slice of bits used by this node.
         *
         * If remaining_bits = 8 and tree[index] = 3, the mask of just the
         * remaining bits is 0x00ff and the mask for the remaining bits after
         * this node is 0x001f.  By taking 0x00ff & ~0x001f, we get 0x00e0.
         * This masks the 3 bits that we would want for this node.
         */

        next_remain = cast(int)(remaining_bits - tree[index]);
        mask = ((1 << remaining_bits) - 1) & ~((1 << next_remain) - 1);

        /* Using the mask, calculate the index of the opcode in the node.
         * With that index, fetch the index of the next node.
         */

        child_index = (opcode & mask) >> next_remain;
        index = tree[index + 1 + child_index];

        /* If the next node is an empty leaf, the opcode is for a non-existent
         * function.  We're done.
         *
         * If the next node is a non-empty leaf, look up the function pointer
         * and return it.
         */

        if (index == EMPTY_LEAF) {
            return -1;
        }
        else if (mixin(IS_LEAF_INDEX!("index"))) {
            uint func_index = void;

            /* The value stored in the tree for a leaf node is the base of
             * the function pointers for that leaf node.  The offset for the
             * function for a particular opcode is the remaining bits in the
             * opcode.
             */

            func_index = cast(uint)-index;
            func_index += opcode & ((1 << next_remain) - 1);
            return func_index;
        }
    }

    /* We should *never* get here!!!
     */
    return -1;
}

void* __glXGetProtocolDecodeFunction(const(__glXDispatchInfo)* dispatch_info, int opcode, int swapped_version)
{
    const(int) func_index = get_decode_index(dispatch_info, opcode);

    return (func_index < 0)
        ? null
        : cast(void*) dispatch_info.
        dispatch_functions[func_index][swapped_version];
}

int __glXGetProtocolSizeData(const(__glXDispatchInfo)* dispatch_info, int opcode, __GLXrenderSizeData* data)
{
    if (dispatch_info.size_table !is null) {
        const(int) func_index = get_decode_index(dispatch_info, opcode);

        if ((func_index >= 0)
            && (dispatch_info.size_table[func_index][0] != 0)) {
            const(int) var_offset = cast(const int)dispatch_info.size_table[func_index][1];

            data.bytes = cast(int)dispatch_info.size_table[func_index][0];
            data.varsize = (var_offset != ~0)
                ? dispatch_info.size_func_table[var_offset]
                : null;

            return 0;
        }
    }

    return -1;
}
