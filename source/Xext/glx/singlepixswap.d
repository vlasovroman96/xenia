module glx.singlepixswap;
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

import glx.glxserver;
import glx.glxext;
import glx.singlesize;
import glx.unpack;
import glx.indirect_dispatch;
import glx.indirect_size_get;
 import Xext.glx.fix;
import core.stdc.config: c_long, c_ulong;
import glx.glxcmds;
import os.io;
import common.swap;


int __glXDispSwap_ReadPixels(__GLXclientState* cl, GLbyte* pc)
{
    GLsizei width = void, height = void;
    GLenum format = void, type = void;
    GLboolean swapBytes = void, lsbFirst = void;
    GLint compsize = void;

    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;
    char* answer = void; char[200] answerBuffer = void;
    xGLXSingleReply reply = { 0, };

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "28"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    pc += __GLX_SINGLE_HDR_SIZE;
    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));
    swapl(cast(CARD32*)(pc + 12));
    swapl(cast(CARD32*)(pc + 16));
    swapl(cast(CARD32*)(pc + 20));

    width = *cast(GLsizei*) (pc + 8);
    height = *cast(GLsizei*) (pc + 12);
    format = *cast(GLenum*) (pc + 16);
    type = *cast(GLenum*) (pc + 20);
    swapBytes = *cast(GLboolean*) (pc + 24);
    lsbFirst = *cast(GLboolean*) (pc + 25);
    compsize = __glReadPixels_size(format, type, width, height);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    glPixelStorei(GL_PACK_LSB_FIRST, lsbFirst);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glReadPixels(*cast(GLint*) (pc + 0), *cast(GLint*) (pc + 4),
                 *cast(GLsizei*) (pc + 8), *cast(GLsizei*) (pc + 12),
                 *cast(GLenum*) (pc + 16), *cast(GLenum*) (pc + 20), answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_HEADER!());
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }
    return Success;
}

int __glXDispSwap_GetTexImage(__GLXclientState* cl, GLbyte* pc)
{
    GLint level = void, compsize = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void;

    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;
    char* answer = void; char[200] answerBuffer = void;
    GLint width = 0, height = 0, depth = 1;
    xGLXSingleReply reply = { 0, };

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "20"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }

    pc += __GLX_SINGLE_HDR_SIZE;
    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));
    swapl(cast(CARD32*)(pc + 12));

    level = *cast(GLint*) (pc + 4);
    format = *cast(GLenum*) (pc + 8);
    type = *cast(GLenum*) (pc + 12);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 16);

    glGetTexLevelParameteriv(target, level, GL_TEXTURE_WIDTH, &width);
    glGetTexLevelParameteriv(target, level, GL_TEXTURE_HEIGHT, &height);
    if (target == GL_TEXTURE_3D) {
        glGetTexLevelParameteriv(target, level, GL_TEXTURE_DEPTH, &depth);
    }
    /*
     * The three queries above might fail if we're in a state where queries
     * are illegal, but then width, height, and depth would still be zero anyway.
     */
    compsize =
        __glGetTexImage_size(target, level, format, type, width, height, depth);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glGetTexImage(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4),
                  *cast(GLenum*) (pc + 8), *cast(GLenum*) (pc + 12), answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        swapl(&width);
        swapl(&height);
        swapl(&depth);
        (cast(xGLXGetTexImageReply*) &reply).width = width;
        (cast(xGLXGetTexImageReply*) &reply).height = height;
        (cast(xGLXGetTexImageReply*) &reply).depth = depth;
        mixin(__GLX_SEND_HEADER!());
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }
    return Success;
}

int __glXDispSwap_GetPolygonStipple(__GLXclientState* cl, GLbyte* pc)
{
    GLboolean lsbFirst = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;
    GLubyte[200] answerBuffer = void;
    char* answer = void;
    xGLXSingleReply reply = { 0, };

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "4"));

    swapl(&(cast(xGLXSingleReq*) pc).contextTag);
    cx = __glXForceCurrent(cl, mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc")), &error);
    if (!cx) {
        return error;
    }
    pc += __GLX_SINGLE_HDR_SIZE;
    lsbFirst = *cast(GLboolean*) (pc + 0);

    glPixelStorei(GL_PACK_LSB_FIRST, lsbFirst);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "128", "1"));

    __glXClearErrorOccured();
    glGetPolygonStipple(cast(GLubyte*) answer);
    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("128"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_HEADER!());
        mixin(__GLX_SEND_BYTE_ARRAY!("128")~";");
    }
    return Success;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int GetSeparableFilter(__GLXclientState* cl, GLbyte* pc, GLXContextTag tag)
{
    GLint compsize = void, compsize2 = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;

    char* answer = void; char[200] answerBuffer = void;
    GLint width = 0, height = 0;
    xGLXSingleReply reply = { 0, };

    cx = __glXForceCurrent(cl, tag, &error);
    if (!cx) {
        return error;
    }

    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));

    format = *cast(GLenum*) (pc + 4);
    type = *cast(GLenum*) (pc + 8);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 12);

    /* target must be SEPARABLE_2D, however I guess we can let the GL
       barf on this one.... */

    glGetConvolutionParameteriv(target, GL_CONVOLUTION_WIDTH, &width);
    glGetConvolutionParameteriv(target, GL_CONVOLUTION_HEIGHT, &height);
    /*
     * The two queries above might fail if we're in a state where queries
     * are illegal, but then width and height would still be zero anyway.
     */
    compsize = __glGetTexImage_size(target, 1, format, type, width, 1, 1);
    compsize2 = __glGetTexImage_size(target, 1, format, type, height, 1, 1);

    if ((compsize = safe_pad(compsize)) < 0)
        return BadLength;
    if ((compsize2 = safe_pad(compsize2)) < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "safe_add(compsize, compsize2)", "1"));
    __glXClearErrorOccured();
    glGetSeparableFilter(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                         *cast(GLenum*) (pc + 8), answer, answer + compsize, null);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize + compsize2"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        swapl(&width);
        swapl(&height);
        (cast(xGLXGetSeparableFilterReply*) &reply).width = width;
        (cast(xGLXGetSeparableFilterReply*) &reply).height = height;
        mixin(__GLX_SEND_VOID_ARRAY!("compsize + compsize2")~";");
    }

    return Success;
}

int __glXDispSwap_GetSeparableFilter(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetSeparableFilter(cl, pc + __GLX_SINGLE_HDR_SIZE, tag);
}

int __glXDispSwap_GetSeparableFilterEXT(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_VENDPRIV_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetSeparableFilter(cl, pc + __GLX_VENDPRIV_HDR_SIZE, tag);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int GetConvolutionFilter(__GLXclientState* cl, GLbyte* pc, GLXContextTag tag)
{
    GLint compsize = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;

    char* answer = void; char[200] answerBuffer = void;
    GLint width = 0, height = 0;
    xGLXSingleReply reply = { 0, };

    cx = __glXForceCurrent(cl, tag, &error);
    if (!cx) {
        return error;
    }

    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));

    format = *cast(GLenum*) (pc + 4);
    type = *cast(GLenum*) (pc + 8);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 12);

    glGetConvolutionParameteriv(target, GL_CONVOLUTION_WIDTH, &width);
    if (target == GL_CONVOLUTION_2D) {
        height = 1;
    }
    else {
        glGetConvolutionParameteriv(target, GL_CONVOLUTION_HEIGHT, &height);
    }
    /*
     * The two queries above might fail if we're in a state where queries
     * are illegal, but then width and height would still be zero anyway.
     */
    compsize = __glGetTexImage_size(target, 1, format, type, width, height, 1);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glGetConvolutionFilter(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                           *cast(GLenum*) (pc + 8), answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        swapl(&width);
        swapl(&height);
        (cast(xGLXGetConvolutionFilterReply*) &reply).width = width;
        (cast(xGLXGetConvolutionFilterReply*) &reply).height = height;
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }

    return Success;
}

int __glXDispSwap_GetConvolutionFilter(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetConvolutionFilter(cl, pc + __GLX_SINGLE_HDR_SIZE, tag);
}

int __glXDispSwap_GetConvolutionFilterEXT(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_VENDPRIV_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetConvolutionFilter(cl, pc + __GLX_VENDPRIV_HDR_SIZE, tag);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int GetHistogram(__GLXclientState* cl, GLbyte* pc, GLXContextTag tag)
{
    GLint compsize = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void, reset = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;

    char* answer = void; char[200] answerBuffer = void;
    GLint width = 0;
    xGLXSingleReply reply = { 0, };

    cx = __glXForceCurrent(cl, tag, &error);
    if (!cx) {
        return error;
    }

    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));

    format = *cast(GLenum*) (pc + 4);
    type = *cast(GLenum*) (pc + 8);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 12);
    reset = *cast(GLboolean*) (pc + 13);

    glGetHistogramParameteriv(target, GL_HISTOGRAM_WIDTH, &width);
    /*
     * The one query above might fail if we're in a state where queries
     * are illegal, but then width would still be zero anyway.
     */
    compsize = __glGetTexImage_size(target, 1, format, type, width, 1, 1);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glGetHistogram(target, reset, format, type, answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        swapl(&width);
        (cast(xGLXGetHistogramReply*) &reply).width = width;
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }

    return Success;
}

int __glXDispSwap_GetHistogram(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetHistogram(cl, pc + __GLX_SINGLE_HDR_SIZE, tag);
}

int __glXDispSwap_GetHistogramEXT(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_VENDPRIV_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetHistogram(cl, pc + __GLX_VENDPRIV_HDR_SIZE, tag);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int GetMinmax(__GLXclientState* cl, GLbyte* pc, GLXContextTag tag)
{
    GLint compsize = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void, reset = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;

    char* answer = void; char[200] answerBuffer = void;
    xGLXSingleReply reply = { 0, };

    cx = __glXForceCurrent(cl, tag, &error);
    if (!cx) {
        return error;
    }

    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));

    format = *cast(GLenum*) (pc + 4);
    type = *cast(GLenum*) (pc + 8);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 12);
    reset = *cast(GLboolean*) (pc + 13);

    compsize = __glGetTexImage_size(target, 1, format, type, 2, 1, 1);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glGetMinmax(target, reset, format, type, answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }

    return Success;
}

int __glXDispSwap_GetMinmax(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetMinmax(cl, pc + __GLX_SINGLE_HDR_SIZE, tag);
}

int __glXDispSwap_GetMinmaxEXT(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_VENDPRIV_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetMinmax(cl, pc + __GLX_VENDPRIV_HDR_SIZE, tag);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int GetColorTable(__GLXclientState* cl, GLbyte* pc, GLXContextTag tag)
{
    GLint compsize = void;
    GLenum format = void, type = void, target = void;
    GLboolean swapBytes = void;
    __GLXcontext* cx = void;
    ClientPtr client = cl.client;
    int error = void;

    char* answer = void; char[200] answerBuffer = void;
    GLint width = 0;
    xGLXSingleReply reply = { 0, };

    cx = __glXForceCurrent(cl, tag, &error);
    if (!cx) {
        return error;
    }

    swapl(cast(CARD32*)(pc + 0));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));

    format = *cast(GLenum*) (pc + 4);
    type = *cast(GLenum*) (pc + 8);
    target = *cast(GLenum*) (pc + 0);
    swapBytes = *cast(GLboolean*) (pc + 12);

    glGetColorTableParameteriv(target, GL_COLOR_TABLE_WIDTH, &width);
    /*
     * The one query above might fail if we're in a state where queries
     * are illegal, but then width would still be zero anyway.
     */
    compsize = __glGetTexImage_size(target, 1, format, type, width, 1, 1);
    if (compsize < 0)
        return BadLength;

    glPixelStorei(GL_PACK_SWAP_BYTES, !swapBytes);
    mixin(__GLX_GET_ANSWER_BUFFER!("answer", "cl", "compsize", "1"));
    __glXClearErrorOccured();
    glGetColorTable(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                    *cast(GLenum*) (pc + 8), answer);

    if (__glXErrorOccured()) {
        mixin(__GLX_BEGIN_REPLY!("0"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
    }
    else {
        mixin(__GLX_BEGIN_REPLY!("compsize"));
        mixin(__GLX_SWAP_REPLY_HEADER!());
        swapl(&width);
        (cast(xGLXGetColorTableReply*) &reply).width = width;
        mixin(__GLX_SEND_VOID_ARRAY!("compsize")~";");
    }

    return Success;
}

int __glXDispSwap_GetColorTable(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_SINGLE_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXSingleReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetColorTable(cl, pc + __GLX_SINGLE_HDR_SIZE, tag);
}

int __glXDispSwap_GetColorTableSGI(__GLXclientState* cl, GLbyte* pc)
{
    const(GLXContextTag) tag = mixin(__GLX_GET_VENDPRIV_CONTEXT_TAG!("pc"));
    ClientPtr client = cl.client;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "16"));
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return GetColorTable(cl, pc + __GLX_VENDPRIV_HDR_SIZE, tag);
}
