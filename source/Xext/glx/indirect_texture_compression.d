module glx.indirect_texture_compression;
@nogc nothrow:
extern(C): __gshared:
/*
 * (C) Copyright IBM Corporation 2005, 2006
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

import dix.request_priv;

import glx.glxserver;
import glx.glxext;
import glx.singlesize;
import glx.unpack;
import glx.indirect_size_get;
import glx.indirect_dispatch;
//  import Xext.glx.fix;
import Xext.glx.fix;
 import glx.glxcmds;
import core.stdc.config: c_long, c_ulong;
import os.io;



int __glXDisp_GetCompressedTexImage(__GLXclientStateRec* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "8"));

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = *cast(GLenum*) (pc + 0);
        const(GLint) level = *cast(GLint*) (pc + 4);
        GLint compsize = 0;
        char* answer = null; char[200] answerBuffer = void;
        xGLXSingleReply reply = { 0, };

        glGetTexLevelParameteriv(target, level, GL_TEXTURE_COMPRESSED_IMAGE_SIZE,
                                 &compsize);

        if (compsize != 0) {
            PFNGLGETCOMPRESSEDTEXIMAGEARBPROC GetCompressedTexImageARB = cast(PFNGLGETCOMPRESSEDTEXIMAGEARBPROC)__glGetProcAddress("glGetCompressedTexImageARB");
            mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
            __glXClearErrorOccured();
            GetCompressedTexImageARB(target, level, answer);
        }

        if (__glXErrorOccured()) {
            mixin(__GLX_BEGIN_REPLY!("0"));
            mixin(__GLX_SEND_HEADER!());
        }
        else {
            mixin(__GLX_BEGIN_REPLY!("compsize"));
            (cast(xGLXGetTexImageReply*) &reply).width = compsize;
            mixin(__GLX_SEND_HEADER!());
            mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
        }

        error = Success;
    }

    return error;
}

int __glXDispSwap_GetCompressedTexImage(__GLXclientStateRec* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_32(req.contextTag), &error);
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "8"));

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = cast(GLenum) bswap_32(*cast(int*) (pc + 0));
        const(GLint) level = cast(GLint) bswap_32(*cast(int*) (pc + 4));
        GLint compsize = 0;
        char* answer = null; char[200] answerBuffer = void;
        xGLXSingleReply reply = { 0, };

        glGetTexLevelParameteriv(target, level, GL_TEXTURE_COMPRESSED_IMAGE_SIZE,
                                 &compsize);

        if (compsize != 0) {
            PFNGLGETCOMPRESSEDTEXIMAGEARBPROC GetCompressedTexImageARB = cast(PFNGLGETCOMPRESSEDTEXIMAGEARBPROC)__glGetProcAddress("glGetCompressedTexImageARB");
            mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
            __glXClearErrorOccured();
            GetCompressedTexImageARB(target, level, answer);
        }

        if (__glXErrorOccured()) {
            mixin(__GLX_BEGIN_REPLY!("0"));
            mixin(__GLX_SEND_HEADER!());
        }
        else {
            mixin(__GLX_BEGIN_REPLY!("compsize"));
            (cast(xGLXGetTexImageReply*) &reply).width = compsize;
            mixin(__GLX_SEND_HEADER!());
            mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
        }

        error = Success;
    }

    return error;
}
