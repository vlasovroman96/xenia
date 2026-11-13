module glx.single2swap;
@nogc nothrow:
extern(C): __gshared:
/*
 * SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008)
 * Copyright (C) 1991-2000 Silicon Graphics, Inc. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice including the dates of first publication and
 * either this permission notice or a reference to
 * http://oss.sgi.com/projects/FreeB/
 * shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * SILICON GRAPHICS, INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of Silicon Graphics, Inc.
 * shall not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization from
 * Silicon Graphics, Inc.
 */

import build.dix_config;

import dix.dix_priv;
import dix.request_priv;

import glx.glxserver;
import glx.glxutil;
import glx.glxext;
import glx.indirect_dispatch;
import glx.unpack;
// import Xext.glx.fix;
import Xext.glx.fix;
import glx.glxcmds;
import os.io;
import glx.single2;
import common.swap;

int __glXDispSwap_FeedbackBuffer(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    GLsizei size = void;
    GLenum type = void;
    __GLXcontext* cx = void;
    int error = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "8"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    pc += __GLX_SINGLE_HDR_SIZE;
    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    size = *cast(GLsizei*) (pc + 0);
    type = *cast(GLenum*) (pc + 4);
    if (cx.feedbackBufSize < size) {
        cx.feedbackBuf = cast(float*)reallocarray(cx.feedbackBuf,
                                       cast(size_t) size, __GLX_SIZE_FLOAT32);
        if (!cx.feedbackBuf) {
            cl.client.errorValue = cast(uint)size;
            return BadAlloc;
        }
        cx.feedbackBufSize = size;
    }
    glFeedbackBuffer(size, type, cx.feedbackBuf);
    return Success;
}

int __glXDispSwap_SelectBuffer(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    __GLXcontext* cx = void;
    GLsizei size = void;
    int error = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "4"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    pc += __GLX_SINGLE_HDR_SIZE;
    swapl(cast(CARD32*)(pc + 0));
    size = *cast(GLsizei*) (pc + 0);
    if (cx.selectBufSize < size) {
        cx.selectBuf = cast(uint*)reallocarray(cx.selectBuf,
                                     cast(size_t) size, __GLX_SIZE_CARD32);
        if (!cx.selectBuf) {
            cl.client.errorValue = cast(uint)size;
            return BadAlloc;
        }
        cx.selectBufSize = size;
    }
    glSelectBuffer(size, cx.selectBuf);
    return Success;
}

int __glXDispSwap_RenderMode(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    __GLXcontext* cx = void;
    GLint nitems = 0, retBytes = 0, retval = void, newModeCheck = void;
    GLubyte* retBuffer = null;
    GLenum newMode = void;

    mixin(__GLX_DECLARE_SWAP_VARIABLES);;
    mixin(__GLX_DECLARE_SWAP_ARRAY_VARIABLES);;
    int error = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "4"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    pc += __GLX_SINGLE_HDR_SIZE;
    swapl(cast(CARD32*)pc);
    newMode = *cast(GLenum*) pc;
    retval = glRenderMode(newMode);

    /* Check that render mode worked */
    glGetIntegerv(GL_RENDER_MODE, &newModeCheck);
    if (newModeCheck != newMode) {
        /* Render mode change failed.  Bail */
        newMode = newModeCheck;
        goto noChangeAllowed;
    }

    /*
     ** Render mode might have still failed if we get here.  But in this
     ** case we can't really tell, nor does it matter.  If it did fail, it
     ** will return 0, and thus we won't send any data across the wire.
     */

    switch (cx.renderMode) {
    case GL_RENDER:
        cx.renderMode = newMode;
        break;
    case GL_FEEDBACK:
        if (retval < 0) {
            /* Overflow happened. Copy the entire buffer */
            nitems = cx.feedbackBufSize;
        }
        else {
            nitems = retval;
        }
        retBytes = nitems * __GLX_SIZE_FLOAT32;
        retBuffer = cast(GLubyte*) cx.feedbackBuf;
        mixin(__GLX_SWAP_FLOAT_ARRAY!("cast(GLbyte*) retBuffer", "nitems"));
        cx.renderMode = newMode;
        break;
    case GL_SELECT:
        if (retval < 0) {
            /* Overflow happened.  Copy the entire buffer */
            nitems = cx.selectBufSize;
        }
        else {
            GLuint* bp = cx.selectBuf;
            GLint i = void;

            /*
             ** Figure out how many bytes of data need to be sent.  Parse
             ** the selection buffer to determine this fact as the
             ** return value is the number of hits, not the number of
             ** items in the buffer.
             */
            nitems = 0;
            i = retval;
            while (--i >= 0) {
                GLuint n = void;

                /* Parse select data for this hit */
                n = *bp;
                bp += 3 + n;
            }
            nitems = cast(int)(bp - cx.selectBuf);
        }
        retBytes = nitems * __GLX_SIZE_CARD32;
        retBuffer = cast(GLubyte*) cx.selectBuf;
        SwapLongs(cast(CARD32*)retBuffer, nitems);
        cx.renderMode = newMode;
        break;
    default: break;}

    /*
     ** First reply is the number of elements returned in the feedback or
     ** selection array, as per the API for glRenderMode itself.
     */
 noChangeAllowed:{}
    xGLXRenderModeReply reply = {
        type: X_Reply,
        sequenceNumber: cast(ushort)client.sequence,
        length: nitems,
        retval: retval,
        size: nitems,
        newMode: newMode
    };
    swaps(&reply.sequenceNumber);
    swapl(&reply.length);
    swapl(&reply.retval);
    swapl(&reply.size);
    swapl(&reply.newMode);
    WriteToClient(client, xGLXRenderModeReply.sizeof, &reply);
    if (retBytes) {
        WriteToClient(client, retBytes, retBuffer);
    }
    return Success;
}

int __glXDispSwap_Flush(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    __GLXcontext* cx = void;
    int error = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXSingleReq);

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    glFlush();
    return Success;
}

int __glXDispSwap_Finish(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    __GLXcontext* cx = void;
    int error = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXSingleReq);

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    /* Do a local glFinish */
    glFinish();

    /* Send empty reply packet to indicate finish is finished */
    xGLXSingleReply reply = { 0 };
    mixin(__GLX_BEGIN_REPLY!("0"));
    mixin(__GLX_PUT_RETVAL!("0"));
    mixin(__GLX_SWAP_REPLY_HEADER!());
    mixin(__GLX_SEND_HEADER!());

    return Success;
}

int __glXDispSwap_GetString(__GLXclientState* cl, GLbyte* pc)
{
    return DoGetString(cl, pc, GL_TRUE);
}
