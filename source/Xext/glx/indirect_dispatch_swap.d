module glx.indirect_dispatch_swap;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

import glx.glxserver;
import glx.indirect_size;
import glx.indirect_size_get;
import glx.indirect_dispatch;
import glx.indirect_util;
import common.misc;
import glx.singlesize;
//  import Xext.glx.fix;
import Xext.glx.fix;
import glx.glxext;
import glx.glxcmds;


enum string __GLX_PAD(string x) = `(((` ~ x ~ `) + 3) & ~3)`;

// struct __GLXpixel3DHeader {
//     __GLX_PIXEL_3D_HDR;
// }
alias _GLXpixel3DHeader = __GLX_PIXEL_3D_HDR;

// GLboolean __glXErrorOccured();
// void __glXClearErrorOccured();

private const(uint)[2] dummy_answer_swap = [ 0, 0 ];

private GLsizei bswap_CARD32(const(void)* src)
{
    union _X {
        uint dst = void;
        GLsizei ret = void;
    }_X x = void;

    x.dst = bswap_32(*cast(uint*) src);
    return x.ret;
}

private GLshort bswap_CARD16(const(void)* src)
{
    union _X {
        ushort dst = void;
        GLshort ret = void;
    }_X x = void;

    x.dst = bswap_16(*cast(ushort*) src);
    return x.ret;
}

private GLenum bswap_ENUM(const(void)* src)
{
    union _X {
        uint dst = void;
        GLenum ret = void;
    }_X x = void;

    x.dst = bswap_32(*cast(uint*) src);
    return x.ret;
}

private GLdouble bswap_FLOAT64(const(void)* src)
{
    union _X {
        ulong dst = void;
        GLdouble ret = void;
    }_X x = void;

    x.dst = bswap_64(*cast(ulong*) src);
    return x.ret;
}

private GLfloat bswap_FLOAT32(const(void)* src)
{
    union _X {
        uint dst = void;
        GLfloat ret = void;
    }_X x = void;

    x.dst = bswap_32(*cast(uint*) src);
    return x.ret;
}

private void* bswap_16_array(ushort* src, uint count)
{
    uint i = void;

    for (i = 0; i < count; i++) {
        ushort temp = bswap_16(src[i]);

        src[i] = temp;
    }

    return src;
}

private void* bswap_32_array(uint* src, uint count)
{
    uint i = void;

    for (i = 0; i < count; i++) {
        uint temp = bswap_32(src[i]);

        src[i] = temp;
    }

    return src;
}

private void* bswap_64_array(ulong* src, uint count)
{
    uint i = void;

    for (i = 0; i < count; i++) {
        ulong temp = bswap_64(src[i]);

        src[i] = temp;
    }

    return src;
}

int __glXDispSwap_NewList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glNewList(cast(GLuint) bswap_CARD32(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
        error = Success;
    }

    return error;
}

int __glXDispSwap_EndList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glEndList();
        error = Success;
    }

    return error;
}

void __glXDispSwap_CallList(GLbyte* pc)
{
    glCallList(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_CallLists(GLbyte* pc)
{
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);
    const(GLenum) type = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLvoid)* lists = void;

    switch (type) {
    case GL_BYTE:
    case GL_UNSIGNED_BYTE:
    case GL_2_BYTES:
    case GL_3_BYTES:
    case GL_4_BYTES:
        lists = cast(const(GLvoid)*) (pc + 8);
        break;
    case GL_SHORT:
    case GL_UNSIGNED_SHORT:
        lists = cast(const(GLvoid)*) bswap_16_array(cast(ushort*) (pc + 8), n);
        break;
    case GL_INT:
    case GL_UNSIGNED_INT:
    case GL_FLOAT:
        lists = cast(const(GLvoid)*) bswap_32_array(cast(uint*) (pc + 8), n);
        break;
    default:
        return;
    }

    glCallLists(n, type, lists);
}

int __glXDispSwap_DeleteLists(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glDeleteLists(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(GLsizei) bswap_CARD32(pc + 4));
        error = Success;
    }

    return error;
}

int __glXDispSwap_GenLists(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLuint retval = void;

        retval = glGenLists(cast(GLsizei) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_ListBase(GLbyte* pc)
{
    glListBase(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_Begin(GLbyte* pc)
{
    glBegin(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_Bitmap(GLbyte* pc)
{
    const(GLubyte*) bitmap = cast(const(GLubyte*)) (cast(const(GLubyte)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glBitmap(cast(GLsizei) bswap_CARD32(pc + 20),
             cast(GLsizei) bswap_CARD32(pc + 24),
             cast(GLfloat) bswap_FLOAT32(pc + 28),
             cast(GLfloat) bswap_FLOAT32(pc + 32),
             cast(GLfloat) bswap_FLOAT32(pc + 36),
             cast(GLfloat) bswap_FLOAT32(pc + 40), bitmap);
}

void __glXDispSwap_Color3bv(GLbyte* pc)
{
    glColor3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDispSwap_Color3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glColor3dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_Color3fv(GLbyte* pc)
{
    glColor3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Color3iv(GLbyte* pc)
{
    glColor3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Color3sv(GLbyte* pc)
{
    glColor3sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_Color3ubv(GLbyte* pc)
{
    glColor3ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDispSwap_Color3uiv(GLbyte* pc)
{
    glColor3uiv(cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Color3usv(GLbyte* pc)
{
    glColor3usv(cast(const(GLushort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_Color4bv(GLbyte* pc)
{
    glColor4bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDispSwap_Color4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glColor4dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 4));
}

void __glXDispSwap_Color4fv(GLbyte* pc)
{
    glColor4fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_Color4iv(GLbyte* pc)
{
    glColor4iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_Color4sv(GLbyte* pc)
{
    glColor4sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 4));
}

void __glXDispSwap_Color4ubv(GLbyte* pc)
{
    glColor4ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDispSwap_Color4uiv(GLbyte* pc)
{
    glColor4uiv(cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_Color4usv(GLbyte* pc)
{
    glColor4usv(cast(const(GLushort)*) bswap_16_array(cast(ushort*) (pc + 0), 4));
}

void __glXDispSwap_EdgeFlagv(GLbyte* pc)
{
    glEdgeFlagv(cast(const(GLboolean)*) (pc + 0));
}

void __glXDispSwap_End(GLbyte* pc)
{
    glEnd();
}

void __glXDispSwap_Indexdv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glIndexdv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 1));
}

void __glXDispSwap_Indexfv(GLbyte* pc)
{
    glIndexfv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_Indexiv(GLbyte* pc)
{
    glIndexiv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_Indexsv(GLbyte* pc)
{
    glIndexsv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 1));
}

void __glXDispSwap_Normal3bv(GLbyte* pc)
{
    glNormal3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDispSwap_Normal3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glNormal3dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_Normal3fv(GLbyte* pc)
{
    glNormal3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Normal3iv(GLbyte* pc)
{
    glNormal3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Normal3sv(GLbyte* pc)
{
    glNormal3sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_RasterPos2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glRasterPos2dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 2));
}

void __glXDispSwap_RasterPos2fv(GLbyte* pc)
{
    glRasterPos2fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_RasterPos2iv(GLbyte* pc)
{
    glRasterPos2iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_RasterPos2sv(GLbyte* pc)
{
    glRasterPos2sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 2));
}

void __glXDispSwap_RasterPos3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glRasterPos3dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_RasterPos3fv(GLbyte* pc)
{
    glRasterPos3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_RasterPos3iv(GLbyte* pc)
{
    glRasterPos3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_RasterPos3sv(GLbyte* pc)
{
    glRasterPos3sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_RasterPos4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRasterPos4dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 4));
}

void __glXDispSwap_RasterPos4fv(GLbyte* pc)
{
    glRasterPos4fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_RasterPos4iv(GLbyte* pc)
{
    glRasterPos4iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_RasterPos4sv(GLbyte* pc)
{
    glRasterPos4sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 4));
}

void __glXDispSwap_Rectdv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRectdv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 2),
             cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 16), 2));
}

void __glXDispSwap_Rectfv(GLbyte* pc)
{
    glRectfv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 2),
             cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8), 2));
}

void __glXDispSwap_Rectiv(GLbyte* pc)
{
    glRectiv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 2),
             cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8), 2));
}

void __glXDispSwap_Rectsv(GLbyte* pc)
{
    glRectsv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 2),
             cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4), 2));
}

void __glXDispSwap_TexCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glTexCoord1dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 1));
}

void __glXDispSwap_TexCoord1fv(GLbyte* pc)
{
    glTexCoord1fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_TexCoord1iv(GLbyte* pc)
{
    glTexCoord1iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_TexCoord1sv(GLbyte* pc)
{
    glTexCoord1sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 1));
}

void __glXDispSwap_TexCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glTexCoord2dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 2));
}

void __glXDispSwap_TexCoord2fv(GLbyte* pc)
{
    glTexCoord2fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_TexCoord2iv(GLbyte* pc)
{
    glTexCoord2iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_TexCoord2sv(GLbyte* pc)
{
    glTexCoord2sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 2));
}

void __glXDispSwap_TexCoord3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glTexCoord3dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_TexCoord3fv(GLbyte* pc)
{
    glTexCoord3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_TexCoord3iv(GLbyte* pc)
{
    glTexCoord3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_TexCoord3sv(GLbyte* pc)
{
    glTexCoord3sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_TexCoord4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glTexCoord4dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 4));
}

void __glXDispSwap_TexCoord4fv(GLbyte* pc)
{
    glTexCoord4fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_TexCoord4iv(GLbyte* pc)
{
    glTexCoord4iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_TexCoord4sv(GLbyte* pc)
{
    glTexCoord4sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 4));
}

void __glXDispSwap_Vertex2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glVertex2dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 2));
}

void __glXDispSwap_Vertex2fv(GLbyte* pc)
{
    glVertex2fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_Vertex2iv(GLbyte* pc)
{
    glVertex2iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_Vertex2sv(GLbyte* pc)
{
    glVertex2sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 2));
}

void __glXDispSwap_Vertex3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glVertex3dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_Vertex3fv(GLbyte* pc)
{
    glVertex3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Vertex3iv(GLbyte* pc)
{
    glVertex3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_Vertex3sv(GLbyte* pc)
{
    glVertex3sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_Vertex4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glVertex4dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 4));
}

void __glXDispSwap_Vertex4fv(GLbyte* pc)
{
    glVertex4fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_Vertex4iv(GLbyte* pc)
{
    glVertex4iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 4));
}

void __glXDispSwap_Vertex4sv(GLbyte* pc)
{
    glVertex4sv(cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 0), 4));
}

void __glXDispSwap_ClipPlane(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    glClipPlane(cast(GLenum) bswap_ENUM(pc + 32),
                cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 4));
}

void __glXDispSwap_ColorMaterial(GLbyte* pc)
{
    glColorMaterial(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_CullFace(GLbyte* pc)
{
    glCullFace(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_Fogf(GLbyte* pc)
{
    glFogf(cast(GLenum) bswap_ENUM(pc + 0), cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_Fogfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                         __glFogfv_size(pname));

    glFogfv(pname, params);
}

void __glXDispSwap_Fogi(GLbyte* pc)
{
    glFogi(cast(GLenum) bswap_ENUM(pc + 0), cast(GLint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_Fogiv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                       __glFogiv_size(pname));

    glFogiv(pname, params);
}

void __glXDispSwap_FrontFace(GLbyte* pc)
{
    glFrontFace(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_Hint(GLbyte* pc)
{
    glHint(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_Lightf(GLbyte* pc)
{
    glLightf(cast(GLenum) bswap_ENUM(pc + 0),
             cast(GLenum) bswap_ENUM(pc + 4), cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_Lightfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glLightfv_size(pname));

    glLightfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_Lighti(GLbyte* pc)
{
    glLighti(cast(GLenum) bswap_ENUM(pc + 0),
             cast(GLenum) bswap_ENUM(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_Lightiv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glLightiv_size(pname));

    glLightiv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_LightModelf(GLbyte* pc)
{
    glLightModelf(cast(GLenum) bswap_ENUM(pc + 0), cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_LightModelfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                         __glLightModelfv_size(pname));

    glLightModelfv(pname, params);
}

void __glXDispSwap_LightModeli(GLbyte* pc)
{
    glLightModeli(cast(GLenum) bswap_ENUM(pc + 0), cast(GLint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_LightModeliv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                       __glLightModeliv_size(pname));

    glLightModeliv(pname, params);
}

void __glXDispSwap_LineStipple(GLbyte* pc)
{
    glLineStipple(cast(GLint) bswap_CARD32(pc + 0),
                  cast(GLushort) bswap_CARD16(pc + 4));
}

void __glXDispSwap_LineWidth(GLbyte* pc)
{
    glLineWidth(cast(GLfloat) bswap_FLOAT32(pc + 0));
}

void __glXDispSwap_Materialf(GLbyte* pc)
{
    glMaterialf(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLenum) bswap_ENUM(pc + 4), cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_Materialfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glMaterialfv_size(pname));

    glMaterialfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_Materiali(GLbyte* pc)
{
    glMateriali(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLenum) bswap_ENUM(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_Materialiv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glMaterialiv_size(pname));

    glMaterialiv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_PointSize(GLbyte* pc)
{
    glPointSize(cast(GLfloat) bswap_FLOAT32(pc + 0));
}

void __glXDispSwap_PolygonMode(GLbyte* pc)
{
    glPolygonMode(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_PolygonStipple(GLbyte* pc)
{
    const(GLubyte*) mask = cast(const(GLubyte*)) (cast(const(GLubyte)*) ((pc + 20)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glPolygonStipple(mask);
}

void __glXDispSwap_Scissor(GLbyte* pc)
{
    glScissor(cast(GLint) bswap_CARD32(pc + 0),
              cast(GLint) bswap_CARD32(pc + 4),
              cast(GLsizei) bswap_CARD32(pc + 8), cast(GLsizei) bswap_CARD32(pc + 12));
}

void __glXDispSwap_ShadeModel(GLbyte* pc)
{
    glShadeModel(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_TexParameterf(GLbyte* pc)
{
    glTexParameterf(cast(GLenum) bswap_ENUM(pc + 0),
                    cast(GLenum) bswap_ENUM(pc + 4),
                    cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_TexParameterfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glTexParameterfv_size(pname));

    glTexParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexParameteri(GLbyte* pc)
{
    glTexParameteri(cast(GLenum) bswap_ENUM(pc + 0),
                    cast(GLenum) bswap_ENUM(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_TexParameteriv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glTexParameteriv_size(pname));

    glTexParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexImage1D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 52)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexImage1D(cast(GLenum) bswap_ENUM(pc + 20),
                 cast(GLint) bswap_CARD32(pc + 24),
                 cast(GLint) bswap_CARD32(pc + 28),
                 cast(GLsizei) bswap_CARD32(pc + 32),
                 cast(GLint) bswap_CARD32(pc + 40),
                 cast(GLenum) bswap_ENUM(pc + 44),
                 cast(GLenum) bswap_ENUM(pc + 48), pixels);
}

void __glXDispSwap_TexImage2D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 52)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexImage2D(cast(GLenum) bswap_ENUM(pc + 20),
                 cast(GLint) bswap_CARD32(pc + 24),
                 cast(GLint) bswap_CARD32(pc + 28),
                 cast(GLsizei) bswap_CARD32(pc + 32),
                 cast(GLsizei) bswap_CARD32(pc + 36),
                 cast(GLint) bswap_CARD32(pc + 40),
                 cast(GLenum) bswap_ENUM(pc + 44),
                 cast(GLenum) bswap_ENUM(pc + 48), pixels);
}

void __glXDispSwap_TexEnvf(GLbyte* pc)
{
    glTexEnvf(cast(GLenum) bswap_ENUM(pc + 0),
              cast(GLenum) bswap_ENUM(pc + 4), cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_TexEnvfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glTexEnvfv_size(pname));

    glTexEnvfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexEnvi(GLbyte* pc)
{
    glTexEnvi(cast(GLenum) bswap_ENUM(pc + 0),
              cast(GLenum) bswap_ENUM(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_TexEnviv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glTexEnviv_size(pname));

    glTexEnviv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexGend(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glTexGend(cast(GLenum) bswap_ENUM(pc + 8),
              cast(GLenum) bswap_ENUM(pc + 12), cast(GLdouble) bswap_FLOAT64(pc + 0));
}

void __glXDispSwap_TexGendv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLdouble)* params = void;

version (__GLX_ALIGN64) {
    const(GLuint) compsize = __glTexGendv_size(pname);
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(compsize * 8)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    params =
        cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 8),
                                          __glTexGendv_size(pname));

    glTexGendv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexGenf(GLbyte* pc)
{
    glTexGenf(cast(GLenum) bswap_ENUM(pc + 0),
              cast(GLenum) bswap_ENUM(pc + 4), cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_TexGenfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glTexGenfv_size(pname));

    glTexGenfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_TexGeni(GLbyte* pc)
{
    glTexGeni(cast(GLenum) bswap_ENUM(pc + 0),
              cast(GLenum) bswap_ENUM(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_TexGeniv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glTexGeniv_size(pname));

    glTexGeniv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_InitNames(GLbyte* pc)
{
    glInitNames();
}

void __glXDispSwap_LoadName(GLbyte* pc)
{
    glLoadName(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_PassThrough(GLbyte* pc)
{
    glPassThrough(cast(GLfloat) bswap_FLOAT32(pc + 0));
}

void __glXDispSwap_PopName(GLbyte* pc)
{
    glPopName();
}

void __glXDispSwap_PushName(GLbyte* pc)
{
    glPushName(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_DrawBuffer(GLbyte* pc)
{
    glDrawBuffer(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_Clear(GLbyte* pc)
{
    glClear(cast(GLbitfield) bswap_CARD32(pc + 0));
}

void __glXDispSwap_ClearAccum(GLbyte* pc)
{
    glClearAccum(cast(GLfloat) bswap_FLOAT32(pc + 0),
                 cast(GLfloat) bswap_FLOAT32(pc + 4),
                 cast(GLfloat) bswap_FLOAT32(pc + 8),
                 cast(GLfloat) bswap_FLOAT32(pc + 12));
}

void __glXDispSwap_ClearIndex(GLbyte* pc)
{
    glClearIndex(cast(GLfloat) bswap_FLOAT32(pc + 0));
}

void __glXDispSwap_ClearColor(GLbyte* pc)
{
    glClearColor(cast(GLclampf) bswap_FLOAT32(pc + 0),
                 cast(GLclampf) bswap_FLOAT32(pc + 4),
                 cast(GLclampf) bswap_FLOAT32(pc + 8),
                 cast(GLclampf) bswap_FLOAT32(pc + 12));
}

void __glXDispSwap_ClearStencil(GLbyte* pc)
{
    glClearStencil(cast(GLint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_ClearDepth(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glClearDepth(cast(GLclampd) bswap_FLOAT64(pc + 0));
}

void __glXDispSwap_StencilMask(GLbyte* pc)
{
    glStencilMask(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_ColorMask(GLbyte* pc)
{
    glColorMask(*cast(GLboolean*) (pc + 0),
                *cast(GLboolean*) (pc + 1),
                *cast(GLboolean*) (pc + 2), *cast(GLboolean*) (pc + 3));
}

void __glXDispSwap_DepthMask(GLbyte* pc)
{
    glDepthMask(*cast(GLboolean*) (pc + 0));
}

void __glXDispSwap_IndexMask(GLbyte* pc)
{
    glIndexMask(cast(GLuint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_Accum(GLbyte* pc)
{
    glAccum(cast(GLenum) bswap_ENUM(pc + 0), cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_Disable(GLbyte* pc)
{
    glDisable(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_Enable(GLbyte* pc)
{
    glEnable(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_PopAttrib(GLbyte* pc)
{
    glPopAttrib();
}

void __glXDispSwap_PushAttrib(GLbyte* pc)
{
    glPushAttrib(cast(GLbitfield) bswap_CARD32(pc + 0));
}

void __glXDispSwap_MapGrid1d(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    glMapGrid1d(cast(GLint) bswap_CARD32(pc + 16),
                cast(GLdouble) bswap_FLOAT64(pc + 0),
                cast(GLdouble) bswap_FLOAT64(pc + 8));
}

void __glXDispSwap_MapGrid1f(GLbyte* pc)
{
    glMapGrid1f(cast(GLint) bswap_CARD32(pc + 0),
                cast(GLfloat) bswap_FLOAT32(pc + 4),
                cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_MapGrid2d(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    glMapGrid2d(cast(GLint) bswap_CARD32(pc + 32),
                cast(GLdouble) bswap_FLOAT64(pc + 0),
                cast(GLdouble) bswap_FLOAT64(pc + 8),
                cast(GLint) bswap_CARD32(pc + 36),
                cast(GLdouble) bswap_FLOAT64(pc + 16),
                cast(GLdouble) bswap_FLOAT64(pc + 24));
}

void __glXDispSwap_MapGrid2f(GLbyte* pc)
{
    glMapGrid2f(cast(GLint) bswap_CARD32(pc + 0),
                cast(GLfloat) bswap_FLOAT32(pc + 4),
                cast(GLfloat) bswap_FLOAT32(pc + 8),
                cast(GLint) bswap_CARD32(pc + 12),
                cast(GLfloat) bswap_FLOAT32(pc + 16),
                cast(GLfloat) bswap_FLOAT32(pc + 20));
}

void __glXDispSwap_EvalCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glEvalCoord1dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 1));
}

void __glXDispSwap_EvalCoord1fv(GLbyte* pc)
{
    glEvalCoord1fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_EvalCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glEvalCoord2dv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 2));
}

void __glXDispSwap_EvalCoord2fv(GLbyte* pc)
{
    glEvalCoord2fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 2));
}

void __glXDispSwap_EvalMesh1(GLbyte* pc)
{
    glEvalMesh1(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLint) bswap_CARD32(pc + 4), cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_EvalPoint1(GLbyte* pc)
{
    glEvalPoint1(cast(GLint) bswap_CARD32(pc + 0));
}

void __glXDispSwap_EvalMesh2(GLbyte* pc)
{
    glEvalMesh2(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLint) bswap_CARD32(pc + 4),
                cast(GLint) bswap_CARD32(pc + 8),
                cast(GLint) bswap_CARD32(pc + 12), cast(GLint) bswap_CARD32(pc + 16));
}

void __glXDispSwap_EvalPoint2(GLbyte* pc)
{
    glEvalPoint2(cast(GLint) bswap_CARD32(pc + 0), cast(GLint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_AlphaFunc(GLbyte* pc)
{
    glAlphaFunc(cast(GLenum) bswap_ENUM(pc + 0), cast(GLclampf) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_BlendFunc(GLbyte* pc)
{
    glBlendFunc(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_LogicOp(GLbyte* pc)
{
    glLogicOp(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_StencilFunc(GLbyte* pc)
{
    glStencilFunc(cast(GLenum) bswap_ENUM(pc + 0),
                  cast(GLint) bswap_CARD32(pc + 4), cast(GLuint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_StencilOp(GLbyte* pc)
{
    glStencilOp(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLenum) bswap_ENUM(pc + 4), cast(GLenum) bswap_ENUM(pc + 8));
}

void __glXDispSwap_DepthFunc(GLbyte* pc)
{
    glDepthFunc(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_PixelZoom(GLbyte* pc)
{
    glPixelZoom(cast(GLfloat) bswap_FLOAT32(pc + 0),
                cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_PixelTransferf(GLbyte* pc)
{
    glPixelTransferf(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_PixelTransferi(GLbyte* pc)
{
    glPixelTransferi(cast(GLenum) bswap_ENUM(pc + 0), cast(GLint) bswap_CARD32(pc + 4));
}

int __glXDispSwap_PixelStoref(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glPixelStoref(cast(GLenum) bswap_ENUM(pc + 0),
                      cast(GLfloat) bswap_FLOAT32(pc + 4));
        error = Success;
    }

    return error;
}

int __glXDispSwap_PixelStorei(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glPixelStorei(cast(GLenum) bswap_ENUM(pc + 0),
                      cast(GLint) bswap_CARD32(pc + 4));
        error = Success;
    }

    return error;
}

void __glXDispSwap_PixelMapfv(GLbyte* pc)
{
    const(GLsizei) mapsize = cast(GLsizei) bswap_CARD32(pc + 4);

    glPixelMapfv(cast(GLenum) bswap_ENUM(pc + 0),
                 mapsize,
                 cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8), 0));
}

void __glXDispSwap_PixelMapuiv(GLbyte* pc)
{
    const(GLsizei) mapsize = cast(GLsizei) bswap_CARD32(pc + 4);

    glPixelMapuiv(cast(GLenum) bswap_ENUM(pc + 0),
                  mapsize,
                  cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 8), 0));
}

void __glXDispSwap_PixelMapusv(GLbyte* pc)
{
    const(GLsizei) mapsize = cast(GLsizei) bswap_CARD32(pc + 4);

    glPixelMapusv(cast(GLenum) bswap_ENUM(pc + 0),
                  mapsize,
                  cast(const(GLushort)*) bswap_16_array(cast(ushort*) (pc + 8), 0));
}

void __glXDispSwap_ReadBuffer(GLbyte* pc)
{
    glReadBuffer(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_CopyPixels(GLbyte* pc)
{
    glCopyPixels(cast(GLint) bswap_CARD32(pc + 0),
                 cast(GLint) bswap_CARD32(pc + 4),
                 cast(GLsizei) bswap_CARD32(pc + 8),
                 cast(GLsizei) bswap_CARD32(pc + 12), cast(GLenum) bswap_ENUM(pc + 16));
}

void __glXDispSwap_DrawPixels(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 36)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glDrawPixels(cast(GLsizei) bswap_CARD32(pc + 20),
                 cast(GLsizei) bswap_CARD32(pc + 24),
                 cast(GLenum) bswap_ENUM(pc + 28),
                 cast(GLenum) bswap_ENUM(pc + 32), pixels);
}

int __glXDispSwap_GetBooleanv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetBooleanv_size(pname);
        GLboolean[200] answerBuffer = void;
        GLboolean* params = cast(ubyte*)__glXGetAnswerBuffer(cl, compsize, answerBuffer.ptr,
                                 answerBuffer.sizeof, 1);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetBooleanv(pname, params);
        __glXSendReplySwap(cl.client, params, compsize, 1, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetClipPlane(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] equation = void;

        glGetClipPlane(cast(GLenum) bswap_ENUM(pc + 0), equation.ptr);
        cast(void) bswap_64_array(cast(ulong*) equation, 4);
        __glXSendReplySwap(cl.client, equation.ptr, 4, 8, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetDoublev(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetDoublev_size(pname);
        GLdouble[200] answerBuffer = void;
        GLdouble* params = cast(GLdouble*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetDoublev(pname, params);
        cast(void) bswap_64_array(cast(ulong*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetError(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLenum retval = void;

        retval = glGetError();
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetFloatv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetFloatv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetFloatv(pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetIntegerv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetIntegerv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetIntegerv(pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetLightfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetLightfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetLightfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetLightiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetLightiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetLightiv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMapdv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = cast(GLenum) bswap_ENUM(pc + 0);
        const(GLenum) query = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMapdv_size(target, query);
        GLdouble[200] answerBuffer = void;
        GLdouble* v = cast(GLdouble*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapdv(target, query, v);
        cast(void) bswap_64_array(cast(ulong*) v, compsize);
        __glXSendReplySwap(cl.client, v, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMapfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = cast(GLenum) bswap_ENUM(pc + 0);
        const(GLenum) query = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMapfv_size(target, query);
        GLfloat[200] answerBuffer = void;
        GLfloat* v = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapfv(target, query, v);
        cast(void) bswap_32_array(cast(uint*) v, compsize);
        __glXSendReplySwap(cl.client, v, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMapiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = cast(GLenum) bswap_ENUM(pc + 0);
        const(GLenum) query = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMapiv_size(target, query);
        GLint[200] answerBuffer = void;
        GLint* v = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapiv(target, query, v);
        cast(void) bswap_32_array(cast(uint*) v, compsize);
        __glXSendReplySwap(cl.client, v, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMaterialfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMaterialfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMaterialfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMaterialiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMaterialiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMaterialiv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetPixelMapfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetPixelMapfv_size(map);
        GLfloat[200] answerBuffer = void;
        GLfloat* values = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapfv(map, values);
        cast(void) bswap_32_array(cast(uint*) values, compsize);
        __glXSendReplySwap(cl.client, values, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetPixelMapuiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetPixelMapuiv_size(map);
        GLuint[200] answerBuffer = void;
        GLuint* values = cast(GLuint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapuiv(map, values);
        cast(void) bswap_32_array(cast(uint*) values, compsize);
        __glXSendReplySwap(cl.client, values, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetPixelMapusv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = cast(GLenum) bswap_ENUM(pc + 0);

        const(GLuint) compsize = __glGetPixelMapusv_size(map);
        GLushort[200] answerBuffer = void;
        GLushort* values = cast(GLushort*)__glXGetAnswerBuffer(cl, compsize * 2, answerBuffer.ptr,
                                 answerBuffer.sizeof, 2);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapusv(map, values);
        cast(void) bswap_16_array(cast(ushort*) values, compsize);
        __glXSendReplySwap(cl.client, values, compsize, 2, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexEnvfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexEnvfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexEnvfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexEnviv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexEnviv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexEnviv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexGendv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexGendv_size(pname);
        GLdouble[200] answerBuffer = void;
        GLdouble* params = cast(GLdouble*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGendv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_64_array(cast(ulong*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexGenfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexGenfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGenfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexGeniv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexGeniv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGeniv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetTexParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexLevelParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 8);

        const(GLuint) compsize = __glGetTexLevelParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexLevelParameterfv(cast(GLenum) bswap_ENUM(pc + 0),
                                 cast(GLint) bswap_CARD32(pc + 4), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetTexLevelParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 8);

        const(GLuint) compsize = __glGetTexLevelParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexLevelParameteriv(cast(GLenum) bswap_ENUM(pc + 0),
                                 cast(GLint) bswap_CARD32(pc + 4), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsEnabled(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsEnabled(cast(GLenum) bswap_ENUM(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsList(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_DepthRange(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glDepthRange(cast(GLclampd) bswap_FLOAT64(pc + 0),
                 cast(GLclampd) bswap_FLOAT64(pc + 8));
}

void __glXDispSwap_Frustum(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 48);
        pc -= 4;
    }
}

    glFrustum(cast(GLdouble) bswap_FLOAT64(pc + 0),
              cast(GLdouble) bswap_FLOAT64(pc + 8),
              cast(GLdouble) bswap_FLOAT64(pc + 16),
              cast(GLdouble) bswap_FLOAT64(pc + 24),
              cast(GLdouble) bswap_FLOAT64(pc + 32),
              cast(GLdouble) bswap_FLOAT64(pc + 40));
}

void __glXDispSwap_LoadIdentity(GLbyte* pc)
{
    glLoadIdentity();
}

void __glXDispSwap_LoadMatrixf(GLbyte* pc)
{
    glLoadMatrixf(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 16));
}

void __glXDispSwap_LoadMatrixd(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 128);
        pc -= 4;
    }
}

    glLoadMatrixd(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 16));
}

void __glXDispSwap_MatrixMode(GLbyte* pc)
{
    glMatrixMode(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_MultMatrixf(GLbyte* pc)
{
    glMultMatrixf(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 16));
}

void __glXDispSwap_MultMatrixd(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 128);
        pc -= 4;
    }
}

    glMultMatrixd(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 16));
}

void __glXDispSwap_Ortho(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 48);
        pc -= 4;
    }
}

    glOrtho(cast(GLdouble) bswap_FLOAT64(pc + 0),
            cast(GLdouble) bswap_FLOAT64(pc + 8),
            cast(GLdouble) bswap_FLOAT64(pc + 16),
            cast(GLdouble) bswap_FLOAT64(pc + 24),
            cast(GLdouble) bswap_FLOAT64(pc + 32),
            cast(GLdouble) bswap_FLOAT64(pc + 40));
}

void __glXDispSwap_PopMatrix(GLbyte* pc)
{
    glPopMatrix();
}

void __glXDispSwap_PushMatrix(GLbyte* pc)
{
    glPushMatrix();
}

void __glXDispSwap_Rotated(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRotated(cast(GLdouble) bswap_FLOAT64(pc + 0),
              cast(GLdouble) bswap_FLOAT64(pc + 8),
              cast(GLdouble) bswap_FLOAT64(pc + 16),
              cast(GLdouble) bswap_FLOAT64(pc + 24));
}

void __glXDispSwap_Rotatef(GLbyte* pc)
{
    glRotatef(cast(GLfloat) bswap_FLOAT32(pc + 0),
              cast(GLfloat) bswap_FLOAT32(pc + 4),
              cast(GLfloat) bswap_FLOAT32(pc + 8),
              cast(GLfloat) bswap_FLOAT32(pc + 12));
}

void __glXDispSwap_Scaled(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glScaled(cast(GLdouble) bswap_FLOAT64(pc + 0),
             cast(GLdouble) bswap_FLOAT64(pc + 8),
             cast(GLdouble) bswap_FLOAT64(pc + 16));
}

void __glXDispSwap_Scalef(GLbyte* pc)
{
    glScalef(cast(GLfloat) bswap_FLOAT32(pc + 0),
             cast(GLfloat) bswap_FLOAT32(pc + 4), cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_Translated(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glTranslated(cast(GLdouble) bswap_FLOAT64(pc + 0),
                 cast(GLdouble) bswap_FLOAT64(pc + 8),
                 cast(GLdouble) bswap_FLOAT64(pc + 16));
}

void __glXDispSwap_Translatef(GLbyte* pc)
{
    glTranslatef(cast(GLfloat) bswap_FLOAT32(pc + 0),
                 cast(GLfloat) bswap_FLOAT32(pc + 4),
                 cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_Viewport(GLbyte* pc)
{
    glViewport(cast(GLint) bswap_CARD32(pc + 0),
               cast(GLint) bswap_CARD32(pc + 4),
               cast(GLsizei) bswap_CARD32(pc + 8), cast(GLsizei) bswap_CARD32(pc + 12));
}

void __glXDispSwap_BindTexture(GLbyte* pc)
{
    glBindTexture(cast(GLenum) bswap_ENUM(pc + 0), cast(GLuint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_Indexubv(GLbyte* pc)
{
    glIndexubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDispSwap_PolygonOffset(GLbyte* pc)
{
    glPolygonOffset(cast(GLfloat) bswap_FLOAT32(pc + 0),
                    cast(GLfloat) bswap_FLOAT32(pc + 4));
}

int __glXDispSwap_AreTexturesResident(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLboolean retval = void;
        GLboolean[200] answerBuffer = void;
        GLboolean* residences = cast(GLboolean*)__glXGetAnswerBuffer(cl, n, answerBuffer.ptr, answerBuffer.sizeof, 1);

        if (residences is null)
            return BadAlloc;
        retval =
            glAreTexturesResident(n,
                                  cast(const(GLuint)*)
                                  bswap_32_array(cast(uint*) (pc + 4), 0),
                                  residences);
        __glXSendReplySwap(cl.client, residences, n, 1, GL_TRUE, retval);
        error = Success;
    }

    return error;
}

int __glXDispSwap_AreTexturesResidentEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLboolean retval = void;
        GLboolean[200] answerBuffer = void;
        GLboolean* residences = cast(ubyte*)__glXGetAnswerBuffer(cl, n, answerBuffer.ptr, answerBuffer.sizeof, 1);

        if (residences is null)
            return BadAlloc;
        retval =
            glAreTexturesResident(n,
                                  cast(const(GLuint)*)
                                  bswap_32_array(cast(uint*) (pc + 4), 0),
                                  residences);
        __glXSendReplySwap(cl.client, residences, n, 1, GL_TRUE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_CopyTexImage1D(GLbyte* pc)
{
    glCopyTexImage1D(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLint) bswap_CARD32(pc + 4),
                     cast(GLenum) bswap_ENUM(pc + 8),
                     cast(GLint) bswap_CARD32(pc + 12),
                     cast(GLint) bswap_CARD32(pc + 16),
                     cast(GLsizei) bswap_CARD32(pc + 20),
                     cast(GLint) bswap_CARD32(pc + 24));
}

void __glXDispSwap_CopyTexImage2D(GLbyte* pc)
{
    glCopyTexImage2D(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLint) bswap_CARD32(pc + 4),
                     cast(GLenum) bswap_ENUM(pc + 8),
                     cast(GLint) bswap_CARD32(pc + 12),
                     cast(GLint) bswap_CARD32(pc + 16),
                     cast(GLsizei) bswap_CARD32(pc + 20),
                     cast(GLsizei) bswap_CARD32(pc + 24),
                     cast(GLint) bswap_CARD32(pc + 28));
}

void __glXDispSwap_CopyTexSubImage1D(GLbyte* pc)
{
    glCopyTexSubImage1D(cast(GLenum) bswap_ENUM(pc + 0),
                        cast(GLint) bswap_CARD32(pc + 4),
                        cast(GLint) bswap_CARD32(pc + 8),
                        cast(GLint) bswap_CARD32(pc + 12),
                        cast(GLint) bswap_CARD32(pc + 16),
                        cast(GLsizei) bswap_CARD32(pc + 20));
}

void __glXDispSwap_CopyTexSubImage2D(GLbyte* pc)
{
    glCopyTexSubImage2D(cast(GLenum) bswap_ENUM(pc + 0),
                        cast(GLint) bswap_CARD32(pc + 4),
                        cast(GLint) bswap_CARD32(pc + 8),
                        cast(GLint) bswap_CARD32(pc + 12),
                        cast(GLint) bswap_CARD32(pc + 16),
                        cast(GLint) bswap_CARD32(pc + 20),
                        cast(GLsizei) bswap_CARD32(pc + 24),
                        cast(GLsizei) bswap_CARD32(pc + 28));
}

int __glXDispSwap_DeleteTextures(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        glDeleteTextures(n,
                         cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         0));
        error = Success;
    }

    return error;
}

int __glXDispSwap_DeleteTexturesEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        glDeleteTextures(n,
                         cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         0));
        error = Success;
    }

    return error;
}

int __glXDispSwap_GenTextures(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* textures = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (textures is null)
            return BadAlloc;
        glGenTextures(n, textures);
        cast(void) bswap_32_array(cast(uint*) textures, n);
        __glXSendReplySwap(cl.client, textures, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GenTexturesEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* textures = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (textures is null)
            return BadAlloc;
        glGenTextures(n, textures);
        cast(void) bswap_32_array(cast(uint*) textures, n);
        __glXSendReplySwap(cl.client, textures, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsTexture(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsTexture(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsTextureEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsTexture(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_PrioritizeTextures(GLbyte* pc)
{
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

    glPrioritizeTextures(n,
                         cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         0),
                         cast(const(GLclampf)*)
                         bswap_32_array(cast(uint*) (pc + 4), 0));
}

void __glXDispSwap_TexSubImage1D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 56)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexSubImage1D(cast(GLenum) bswap_ENUM(pc + 20),
                    cast(GLint) bswap_CARD32(pc + 24),
                    cast(GLint) bswap_CARD32(pc + 28),
                    cast(GLsizei) bswap_CARD32(pc + 36),
                    cast(GLenum) bswap_ENUM(pc + 44),
                    cast(GLenum) bswap_ENUM(pc + 48), pixels);
}

void __glXDispSwap_TexSubImage2D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 56)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexSubImage2D(cast(GLenum) bswap_ENUM(pc + 20),
                    cast(GLint) bswap_CARD32(pc + 24),
                    cast(GLint) bswap_CARD32(pc + 28),
                    cast(GLint) bswap_CARD32(pc + 32),
                    cast(GLsizei) bswap_CARD32(pc + 36),
                    cast(GLsizei) bswap_CARD32(pc + 40),
                    cast(GLenum) bswap_ENUM(pc + 44),
                    cast(GLenum) bswap_ENUM(pc + 48), pixels);
}

void __glXDispSwap_BlendColor(GLbyte* pc)
{
    glBlendColor(cast(GLclampf) bswap_FLOAT32(pc + 0),
                 cast(GLclampf) bswap_FLOAT32(pc + 4),
                 cast(GLclampf) bswap_FLOAT32(pc + 8),
                 cast(GLclampf) bswap_FLOAT32(pc + 12));
}

void __glXDispSwap_BlendEquation(GLbyte* pc)
{
    glBlendEquation(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_ColorTable(GLbyte* pc)
{
    const(GLvoid*) table = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 40)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glColorTable(cast(GLenum) bswap_ENUM(pc + 20),
                 cast(GLenum) bswap_ENUM(pc + 24),
                 cast(GLsizei) bswap_CARD32(pc + 28),
                 cast(GLenum) bswap_ENUM(pc + 32),
                 cast(GLenum) bswap_ENUM(pc + 36), table);
}

void __glXDispSwap_ColorTableParameterfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glColorTableParameterfv_size(pname));

    glColorTableParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_ColorTableParameteriv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glColorTableParameteriv_size(pname));

    glColorTableParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_CopyColorTable(GLbyte* pc)
{
    glCopyColorTable(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLenum) bswap_ENUM(pc + 4),
                     cast(GLint) bswap_CARD32(pc + 8),
                     cast(GLint) bswap_CARD32(pc + 12),
                     cast(GLsizei) bswap_CARD32(pc + 16));
}

int __glXDispSwap_GetColorTableParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetColorTableParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetColorTableParameterfvSGI(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetColorTableParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetColorTableParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetColorTableParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetColorTableParameterivSGI(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetColorTableParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

void __glXDispSwap_ColorSubTable(GLbyte* pc)
{
    const(GLvoid*) data = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 40)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glColorSubTable(cast(GLenum) bswap_ENUM(pc + 20),
                    cast(GLsizei) bswap_CARD32(pc + 24),
                    cast(GLsizei) bswap_CARD32(pc + 28),
                    cast(GLenum) bswap_ENUM(pc + 32),
                    cast(GLenum) bswap_ENUM(pc + 36), data);
}

void __glXDispSwap_CopyColorSubTable(GLbyte* pc)
{
    glCopyColorSubTable(cast(GLenum) bswap_ENUM(pc + 0),
                        cast(GLsizei) bswap_CARD32(pc + 4),
                        cast(GLint) bswap_CARD32(pc + 8),
                        cast(GLint) bswap_CARD32(pc + 12),
                        cast(GLsizei) bswap_CARD32(pc + 16));
}

void __glXDispSwap_ConvolutionFilter1D(GLbyte* pc)
{
    const(GLvoid*) image = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glConvolutionFilter1D(cast(GLenum) bswap_ENUM(pc + 20),
                          cast(GLenum) bswap_ENUM(pc + 24),
                          cast(GLsizei) bswap_CARD32(pc + 28),
                          cast(GLenum) bswap_ENUM(pc + 36),
                          cast(GLenum) bswap_ENUM(pc + 40), image);
}

void __glXDispSwap_ConvolutionFilter2D(GLbyte* pc)
{
    const(GLvoid*) image = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glConvolutionFilter2D(cast(GLenum) bswap_ENUM(pc + 20),
                          cast(GLenum) bswap_ENUM(pc + 24),
                          cast(GLsizei) bswap_CARD32(pc + 28),
                          cast(GLsizei) bswap_CARD32(pc + 32),
                          cast(GLenum) bswap_ENUM(pc + 36),
                          cast(GLenum) bswap_ENUM(pc + 40), image);
}

void __glXDispSwap_ConvolutionParameterf(GLbyte* pc)
{
    glConvolutionParameterf(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLenum) bswap_ENUM(pc + 4),
                            cast(GLfloat) bswap_FLOAT32(pc + 8));
}

void __glXDispSwap_ConvolutionParameterfv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                         __glConvolutionParameterfv_size
                                         (pname));

    glConvolutionParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_ConvolutionParameteri(GLbyte* pc)
{
    glConvolutionParameteri(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLenum) bswap_ENUM(pc + 4),
                            cast(GLint) bswap_CARD32(pc + 8));
}

void __glXDispSwap_ConvolutionParameteriv(GLbyte* pc)
{
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 8),
                                       __glConvolutionParameteriv_size(pname));

    glConvolutionParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
}

void __glXDispSwap_CopyConvolutionFilter1D(GLbyte* pc)
{
    glCopyConvolutionFilter1D(cast(GLenum) bswap_ENUM(pc + 0),
                              cast(GLenum) bswap_ENUM(pc + 4),
                              cast(GLint) bswap_CARD32(pc + 8),
                              cast(GLint) bswap_CARD32(pc + 12),
                              cast(GLsizei) bswap_CARD32(pc + 16));
}

void __glXDispSwap_CopyConvolutionFilter2D(GLbyte* pc)
{
    glCopyConvolutionFilter2D(cast(GLenum) bswap_ENUM(pc + 0),
                              cast(GLenum) bswap_ENUM(pc + 4),
                              cast(GLint) bswap_CARD32(pc + 8),
                              cast(GLint) bswap_CARD32(pc + 12),
                              cast(GLsizei) bswap_CARD32(pc + 16),
                              cast(GLsizei) bswap_CARD32(pc + 20));
}

int __glXDispSwap_GetConvolutionParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetConvolutionParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetConvolutionParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetConvolutionParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetHistogramParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetHistogramParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetHistogramParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetHistogramParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetHistogramParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetHistogramParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetHistogramParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetHistogramParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMinmaxParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMinmaxParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(GLfloat*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameterfv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMinmaxParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetMinmaxParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameteriv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

void __glXDispSwap_Histogram(GLbyte* pc)
{
    glHistogram(cast(GLenum) bswap_ENUM(pc + 0),
                cast(GLsizei) bswap_CARD32(pc + 4),
                cast(GLenum) bswap_ENUM(pc + 8), *cast(GLboolean*) (pc + 12));
}

void __glXDispSwap_Minmax(GLbyte* pc)
{
    glMinmax(cast(GLenum) bswap_ENUM(pc + 0),
             cast(GLenum) bswap_ENUM(pc + 4), *cast(GLboolean*) (pc + 8));
}

void __glXDispSwap_ResetHistogram(GLbyte* pc)
{
    glResetHistogram(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_ResetMinmax(GLbyte* pc)
{
    glResetMinmax(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_TexImage3D(GLbyte* pc)
{
    const(CARD32) ptr_is_null = *cast(CARD32*) (pc + 76);
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((ptr_is_null != 0) ? null : (pc + 80)));
    __GLXpixel3DHeader* hdr = cast(__GLXpixel3DHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT,
                  cast(GLint) bswap_CARD32(&hdr.imageHeight));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_IMAGES,
                  cast(GLint) bswap_CARD32(&hdr.skipImages));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexImage3D(cast(GLenum) bswap_ENUM(pc + 36),
                 cast(GLint) bswap_CARD32(pc + 40),
                 cast(GLint) bswap_CARD32(pc + 44),
                 cast(GLsizei) bswap_CARD32(pc + 48),
                 cast(GLsizei) bswap_CARD32(pc + 52),
                 cast(GLsizei) bswap_CARD32(pc + 56),
                 cast(GLint) bswap_CARD32(pc + 64),
                 cast(GLenum) bswap_ENUM(pc + 68),
                 cast(GLenum) bswap_ENUM(pc + 72), pixels);
}

void __glXDispSwap_TexSubImage3D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 88)));
    __GLXpixel3DHeader* hdr = cast(__GLXpixel3DHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) bswap_CARD32(&hdr.rowLength));
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT,
                  cast(GLint) bswap_CARD32(&hdr.imageHeight));
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) bswap_CARD32(&hdr.skipRows));
    glPixelStorei(GL_UNPACK_SKIP_IMAGES,
                  cast(GLint) bswap_CARD32(&hdr.skipImages));
    glPixelStorei(GL_UNPACK_SKIP_PIXELS,
                  cast(GLint) bswap_CARD32(&hdr.skipPixels));
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) bswap_CARD32(&hdr.alignment));

    glTexSubImage3D(cast(GLenum) bswap_ENUM(pc + 36),
                    cast(GLint) bswap_CARD32(pc + 40),
                    cast(GLint) bswap_CARD32(pc + 44),
                    cast(GLint) bswap_CARD32(pc + 48),
                    cast(GLint) bswap_CARD32(pc + 52),
                    cast(GLsizei) bswap_CARD32(pc + 60),
                    cast(GLsizei) bswap_CARD32(pc + 64),
                    cast(GLsizei) bswap_CARD32(pc + 68),
                    cast(GLenum) bswap_ENUM(pc + 76),
                    cast(GLenum) bswap_ENUM(pc + 80), pixels);
}

void __glXDispSwap_CopyTexSubImage3D(GLbyte* pc)
{
    glCopyTexSubImage3D(cast(GLenum) bswap_ENUM(pc + 0),
                        cast(GLint) bswap_CARD32(pc + 4),
                        cast(GLint) bswap_CARD32(pc + 8),
                        cast(GLint) bswap_CARD32(pc + 12),
                        cast(GLint) bswap_CARD32(pc + 16),
                        cast(GLint) bswap_CARD32(pc + 20),
                        cast(GLint) bswap_CARD32(pc + 24),
                        cast(GLsizei) bswap_CARD32(pc + 28),
                        cast(GLsizei) bswap_CARD32(pc + 32));
}

void __glXDispSwap_ActiveTexture(GLbyte* pc)
{
    glActiveTextureARB(cast(GLenum) bswap_ENUM(pc + 0));
}

void __glXDispSwap_MultiTexCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    glMultiTexCoord1dvARB(cast(GLenum) bswap_ENUM(pc + 8),
                          cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0),
                                                         1));
}

void __glXDispSwap_MultiTexCoord1fvARB(GLbyte* pc)
{
    glMultiTexCoord1fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLfloat)*)
                          bswap_32_array(cast(uint*) (pc + 4), 1));
}

void __glXDispSwap_MultiTexCoord1iv(GLbyte* pc)
{
    glMultiTexCoord1ivARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         1));
}

void __glXDispSwap_MultiTexCoord1sv(GLbyte* pc)
{
    glMultiTexCoord1svARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                           1));
}

void __glXDispSwap_MultiTexCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    glMultiTexCoord2dvARB(cast(GLenum) bswap_ENUM(pc + 16),
                          cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0),
                                                            2));
}

void __glXDispSwap_MultiTexCoord2fvARB(GLbyte* pc)
{
    glMultiTexCoord2fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLfloat)*)
                          bswap_32_array(cast(uint*) (pc + 4), 2));
}

void __glXDispSwap_MultiTexCoord2iv(GLbyte* pc)
{
    glMultiTexCoord2ivARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         2));
}

void __glXDispSwap_MultiTexCoord2sv(GLbyte* pc)
{
    glMultiTexCoord2svARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                           2));
}

void __glXDispSwap_MultiTexCoord3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    glMultiTexCoord3dvARB(cast(GLenum) bswap_ENUM(pc + 24),
                          cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0),
                                                            3));
}

void __glXDispSwap_MultiTexCoord3fvARB(GLbyte* pc)
{
    glMultiTexCoord3fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLfloat)*)
                          bswap_32_array(cast(uint*) (pc + 4), 3));
}

void __glXDispSwap_MultiTexCoord3iv(GLbyte* pc)
{
    glMultiTexCoord3ivARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         3));
}

void __glXDispSwap_MultiTexCoord3sv(GLbyte* pc)
{
    glMultiTexCoord3svARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                           3));
}

void __glXDispSwap_MultiTexCoord4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    glMultiTexCoord4dvARB(cast(GLenum) bswap_ENUM(pc + 32),
                          cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0),
                                                            4));
}

void __glXDispSwap_MultiTexCoord4fvARB(GLbyte* pc)
{
    glMultiTexCoord4fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLfloat)*)
                          bswap_32_array(cast(uint*) (pc + 4), 4));
}

void __glXDispSwap_MultiTexCoord4iv(GLbyte* pc)
{
    glMultiTexCoord4ivARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                         4));
}

void __glXDispSwap_MultiTexCoord4sv(GLbyte* pc)
{
    glMultiTexCoord4svARB(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                           4));
}

void __glXDispSwap_CompressedTexImage1D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE1DPROC CompressedTexImage1D = cast(PFNGLCOMPRESSEDTEXIMAGE1DPROC)__glGetProcAddress("glCompressedTexImage1D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 20);

    CompressedTexImage1D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLint) bswap_CARD32(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLsizei) bswap_CARD32(pc + 12),
                         cast(GLint) bswap_CARD32(pc + 16),
                         imageSize, cast(const(GLvoid)*) (pc + 24));
}

void __glXDispSwap_CompressedTexImage2D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE2DPROC CompressedTexImage2D = cast(PFNGLCOMPRESSEDTEXIMAGE2DPROC)__glGetProcAddress("glCompressedTexImage2D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 24);

    CompressedTexImage2D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLint) bswap_CARD32(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLsizei) bswap_CARD32(pc + 12),
                         cast(GLsizei) bswap_CARD32(pc + 16),
                         cast(GLint) bswap_CARD32(pc + 20),
                         imageSize, cast(const(GLvoid)*) (pc + 28));
}

void __glXDispSwap_CompressedTexImage3D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE3DPROC CompressedTexImage3D = cast(PFNGLCOMPRESSEDTEXIMAGE3DPROC)__glGetProcAddress("glCompressedTexImage3D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 28);

    CompressedTexImage3D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLint) bswap_CARD32(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLsizei) bswap_CARD32(pc + 12),
                         cast(GLsizei) bswap_CARD32(pc + 16),
                         cast(GLsizei) bswap_CARD32(pc + 20),
                         cast(GLint) bswap_CARD32(pc + 24),
                         imageSize, cast(const(GLvoid)*) (pc + 32));
}

void __glXDispSwap_CompressedTexSubImage1D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE1DPROC CompressedTexSubImage1D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE1DPROC)__glGetProcAddress("glCompressedTexSubImage1D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 20);

    CompressedTexSubImage1D(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLint) bswap_CARD32(pc + 4),
                            cast(GLint) bswap_CARD32(pc + 8),
                            cast(GLsizei) bswap_CARD32(pc + 12),
                            cast(GLenum) bswap_ENUM(pc + 16),
                            imageSize, cast(const(GLvoid)*) (pc + 24));
}

void __glXDispSwap_CompressedTexSubImage2D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE2DPROC CompressedTexSubImage2D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE2DPROC)__glGetProcAddress("glCompressedTexSubImage2D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 28);

    CompressedTexSubImage2D(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLint) bswap_CARD32(pc + 4),
                            cast(GLint) bswap_CARD32(pc + 8),
                            cast(GLint) bswap_CARD32(pc + 12),
                            cast(GLsizei) bswap_CARD32(pc + 16),
                            cast(GLsizei) bswap_CARD32(pc + 20),
                            cast(GLenum) bswap_ENUM(pc + 24),
                            imageSize, cast(const(GLvoid)*) (pc + 32));
}

void __glXDispSwap_CompressedTexSubImage3D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE3DPROC CompressedTexSubImage3D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE3DPROC)__glGetProcAddress("glCompressedTexSubImage3D");
    const(GLsizei) imageSize = cast(GLsizei) bswap_CARD32(pc + 36);

    CompressedTexSubImage3D(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLint) bswap_CARD32(pc + 4),
                            cast(GLint) bswap_CARD32(pc + 8),
                            cast(GLint) bswap_CARD32(pc + 12),
                            cast(GLint) bswap_CARD32(pc + 16),
                            cast(GLsizei) bswap_CARD32(pc + 20),
                            cast(GLsizei) bswap_CARD32(pc + 24),
                            cast(GLsizei) bswap_CARD32(pc + 28),
                            cast(GLenum) bswap_ENUM(pc + 32),
                            imageSize, cast(const(GLvoid)*) (pc + 40));
}

void __glXDispSwap_SampleCoverage(GLbyte* pc)
{
    PFNGLSAMPLECOVERAGEPROC SampleCoverage = cast(PFNGLSAMPLECOVERAGEPROC)__glGetProcAddress("glSampleCoverage");
    SampleCoverage(cast(GLclampf) bswap_FLOAT32(pc + 0), *cast(GLboolean*) (pc + 4));
}

void __glXDispSwap_BlendFuncSeparate(GLbyte* pc)
{
    PFNGLBLENDFUNCSEPARATEPROC BlendFuncSeparate = cast(PFNGLBLENDFUNCSEPARATEPROC)__glGetProcAddress("glBlendFuncSeparate");
    BlendFuncSeparate(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4),
                      cast(GLenum) bswap_ENUM(pc + 8),
                      cast(GLenum) bswap_ENUM(pc + 12));
}

void __glXDispSwap_FogCoorddv(GLbyte* pc)
{
    PFNGLFOGCOORDDVPROC FogCoorddv = cast(PFNGLFOGCOORDDVPROC)__glGetProcAddress("glFogCoorddv");

version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    FogCoorddv(cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 0), 1));
}

void __glXDispSwap_PointParameterf(GLbyte* pc)
{
    PFNGLPOINTPARAMETERFPROC PointParameterf = cast(PFNGLPOINTPARAMETERFPROC)__glGetProcAddress("glPointParameterf");
    PointParameterf(cast(GLenum) bswap_ENUM(pc + 0),
                    cast(GLfloat) bswap_FLOAT32(pc + 4));
}

void __glXDispSwap_PointParameterfv(GLbyte* pc)
{
    PFNGLPOINTPARAMETERFVPROC PointParameterfv = cast(PFNGLPOINTPARAMETERFVPROC)__glGetProcAddress("glPointParameterfv");
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLfloat)* params = void;

    params =
        cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                         __glPointParameterfv_size(pname));

    PointParameterfv(pname, params);
}

void __glXDispSwap_PointParameteri(GLbyte* pc)
{
    PFNGLPOINTPARAMETERIPROC PointParameteri = cast(PFNGLPOINTPARAMETERIPROC)__glGetProcAddress("glPointParameteri");
    PointParameteri(cast(GLenum) bswap_ENUM(pc + 0), cast(GLint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_PointParameteriv(GLbyte* pc)
{
    PFNGLPOINTPARAMETERIVPROC PointParameteriv = cast(PFNGLPOINTPARAMETERIVPROC)__glGetProcAddress("glPointParameteriv");
    const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 0);
    const(GLint)* params = void;

    params =
        cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4),
                                       __glPointParameteriv_size(pname));

    PointParameteriv(pname, params);
}

void __glXDispSwap_SecondaryColor3bv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3BVPROC SecondaryColor3bv = cast(PFNGLSECONDARYCOLOR3BVPROC)__glGetProcAddress("glSecondaryColor3bv");
    SecondaryColor3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDispSwap_SecondaryColor3dv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3DVPROC SecondaryColor3dv = cast(PFNGLSECONDARYCOLOR3DVPROC)__glGetProcAddress("glSecondaryColor3dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    SecondaryColor3dv(cast(const(GLdouble)*)
                      bswap_64_array(cast(ulong*) (pc + 0), 3));
}

void __glXDispSwap_SecondaryColor3iv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3IVPROC SecondaryColor3iv = cast(PFNGLSECONDARYCOLOR3IVPROC)__glGetProcAddress("glSecondaryColor3iv");
    SecondaryColor3iv(cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_SecondaryColor3sv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3SVPROC SecondaryColor3sv = cast(PFNGLSECONDARYCOLOR3SVPROC)__glGetProcAddress("glSecondaryColor3sv");
    SecondaryColor3sv(cast(const(GLshort)*)
                      bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_SecondaryColor3ubv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3UBVPROC SecondaryColor3ubv = cast(PFNGLSECONDARYCOLOR3UBVPROC)__glGetProcAddress("glSecondaryColor3ubv");
    SecondaryColor3ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDispSwap_SecondaryColor3uiv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3UIVPROC SecondaryColor3uiv = cast(PFNGLSECONDARYCOLOR3UIVPROC)__glGetProcAddress("glSecondaryColor3uiv");
    SecondaryColor3uiv(cast(const(GLuint)*)
                       bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_SecondaryColor3usv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3USVPROC SecondaryColor3usv = cast(PFNGLSECONDARYCOLOR3USVPROC)__glGetProcAddress("glSecondaryColor3usv");
    SecondaryColor3usv(cast(const(GLushort)*)
                       bswap_16_array(cast(ushort*) (pc + 0), 3));
}

void __glXDispSwap_WindowPos3fv(GLbyte* pc)
{
    PFNGLWINDOWPOS3FVPROC WindowPos3fv = cast(PFNGLWINDOWPOS3FVPROC)__glGetProcAddress("glWindowPos3fv");

    WindowPos3fv(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_BeginQuery(GLbyte* pc)
{
    PFNGLBEGINQUERYPROC BeginQuery = cast(PFNGLBEGINQUERYPROC)__glGetProcAddress("glBeginQuery");

    BeginQuery(cast(GLenum) bswap_ENUM(pc + 0), cast(GLuint) bswap_CARD32(pc + 4));
}

int __glXDispSwap_DeleteQueries(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLDELETEQUERIESPROC DeleteQueries = cast(PFNGLDELETEQUERIESPROC)__glGetProcAddress("glDeleteQueries");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        DeleteQueries(n,
                      cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                      0));
        error = Success;
    }

    return error;
}

void __glXDispSwap_EndQuery(GLbyte* pc)
{
    PFNGLENDQUERYPROC EndQuery = cast(PFNGLENDQUERYPROC)__glGetProcAddress("glEndQuery");

    EndQuery(cast(GLenum) bswap_ENUM(pc + 0));
}

int __glXDispSwap_GenQueries(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENQUERIESPROC GenQueries = cast(PFNGLGENQUERIESPROC)__glGetProcAddress("glGenQueries");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* ids = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);
        if (ids is null)
            return BadAlloc;

        GenQueries(n, ids);
        cast(void) bswap_32_array(cast(uint*) ids, n);
        __glXSendReplySwap(cl.client, ids, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetQueryObjectiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYOBJECTIVPROC GetQueryObjectiv = cast(PFNGLGETQUERYOBJECTIVPROC)__glGetProcAddress("glGetQueryObjectiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetQueryObjectiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryObjectiv(cast(GLuint) bswap_CARD32(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetQueryObjectuiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYOBJECTUIVPROC GetQueryObjectuiv = cast(PFNGLGETQUERYOBJECTUIVPROC)__glGetProcAddress("glGetQueryObjectuiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetQueryObjectuiv_size(pname);
        GLuint[200] answerBuffer = void;
        GLuint* params = cast(GLuint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryObjectuiv(cast(GLuint) bswap_CARD32(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetQueryiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYIVPROC GetQueryiv = cast(PFNGLGETQUERYIVPROC)__glGetProcAddress("glGetQueryiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetQueryiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryiv(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsQuery(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISQUERYPROC IsQuery = cast(PFNGLISQUERYPROC)__glGetProcAddress("glIsQuery");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsQuery(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_BlendEquationSeparate(GLbyte* pc)
{
    PFNGLBLENDEQUATIONSEPARATEPROC BlendEquationSeparate = cast(PFNGLBLENDEQUATIONSEPARATEPROC)__glGetProcAddress("glBlendEquationSeparate");
    BlendEquationSeparate(cast(GLenum) bswap_ENUM(pc + 0),
                          cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_DrawBuffers(GLbyte* pc)
{
    PFNGLDRAWBUFFERSPROC DrawBuffers = cast(PFNGLDRAWBUFFERSPROC)__glGetProcAddress("glDrawBuffers");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

    DrawBuffers(n, cast(const(GLenum)*) bswap_32_array(cast(uint*) (pc + 4), 0));
}

void __glXDispSwap_VertexAttrib1dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1DVPROC VertexAttrib1dv = cast(PFNGLVERTEXATTRIB1DVPROC)__glGetProcAddress("glVertexAttrib1dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    VertexAttrib1dv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                      1));
}

void __glXDispSwap_VertexAttrib1sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1SVPROC VertexAttrib1sv = cast(PFNGLVERTEXATTRIB1SVPROC)__glGetProcAddress("glVertexAttrib1sv");
    VertexAttrib1sv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4), 1));
}

void __glXDispSwap_VertexAttrib2dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2DVPROC VertexAttrib2dv = cast(PFNGLVERTEXATTRIB2DVPROC)__glGetProcAddress("glVertexAttrib2dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    VertexAttrib2dv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                      2));
}

void __glXDispSwap_VertexAttrib2sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2SVPROC VertexAttrib2sv = cast(PFNGLVERTEXATTRIB2SVPROC)__glGetProcAddress("glVertexAttrib2sv");
    VertexAttrib2sv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4), 2));
}

void __glXDispSwap_VertexAttrib3dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3DVPROC VertexAttrib3dv = cast(PFNGLVERTEXATTRIB3DVPROC)__glGetProcAddress("glVertexAttrib3dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    VertexAttrib3dv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                      3));
}

void __glXDispSwap_VertexAttrib3sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3SVPROC VertexAttrib3sv = cast(PFNGLVERTEXATTRIB3SVPROC)__glGetProcAddress("glVertexAttrib3sv");
    VertexAttrib3sv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4), 3));
}

void __glXDispSwap_VertexAttrib4Nbv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NBVPROC VertexAttrib4Nbv = cast(PFNGLVERTEXATTRIB4NBVPROC)__glGetProcAddress("glVertexAttrib4Nbv");
    VertexAttrib4Nbv(cast(GLuint) bswap_CARD32(pc + 0), cast(const(GLbyte)*) (pc + 4));
}

void __glXDispSwap_VertexAttrib4Niv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NIVPROC VertexAttrib4Niv = cast(PFNGLVERTEXATTRIB4NIVPROC)__glGetProcAddress("glVertexAttrib4Niv");
    VertexAttrib4Niv(cast(GLuint) bswap_CARD32(pc + 0),
                     cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4), 4));
}

void __glXDispSwap_VertexAttrib4Nsv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NSVPROC VertexAttrib4Nsv = cast(PFNGLVERTEXATTRIB4NSVPROC)__glGetProcAddress("glVertexAttrib4Nsv");
    VertexAttrib4Nsv(cast(GLuint) bswap_CARD32(pc + 0),
                     cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                      4));
}

void __glXDispSwap_VertexAttrib4Nubv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUBVPROC VertexAttrib4Nubv = cast(PFNGLVERTEXATTRIB4NUBVPROC)__glGetProcAddress("glVertexAttrib4Nubv");
    VertexAttrib4Nubv(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLubyte)*) (pc + 4));
}

void __glXDispSwap_VertexAttrib4Nuiv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUIVPROC VertexAttrib4Nuiv = cast(PFNGLVERTEXATTRIB4NUIVPROC)__glGetProcAddress("glVertexAttrib4Nuiv");
    VertexAttrib4Nuiv(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                      4));
}

void __glXDispSwap_VertexAttrib4Nusv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUSVPROC VertexAttrib4Nusv = cast(PFNGLVERTEXATTRIB4NUSVPROC)__glGetProcAddress("glVertexAttrib4Nusv");
    VertexAttrib4Nusv(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLushort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                        4));
}

void __glXDispSwap_VertexAttrib4bv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4BVPROC VertexAttrib4bv = cast(PFNGLVERTEXATTRIB4BVPROC)__glGetProcAddress("glVertexAttrib4bv");
    VertexAttrib4bv(cast(GLuint) bswap_CARD32(pc + 0), cast(const(GLbyte)*) (pc + 4));
}

void __glXDispSwap_VertexAttrib4dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4DVPROC VertexAttrib4dv = cast(PFNGLVERTEXATTRIB4DVPROC)__glGetProcAddress("glVertexAttrib4dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    VertexAttrib4dv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                      4));
}

void __glXDispSwap_VertexAttrib4iv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4IVPROC VertexAttrib4iv = cast(PFNGLVERTEXATTRIB4IVPROC)__glGetProcAddress("glVertexAttrib4iv");
    VertexAttrib4iv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLint)*) bswap_32_array(cast(uint*) (pc + 4), 4));
}

void __glXDispSwap_VertexAttrib4sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4SVPROC VertexAttrib4sv = cast(PFNGLVERTEXATTRIB4SVPROC)__glGetProcAddress("glVertexAttrib4sv");
    VertexAttrib4sv(cast(GLuint) bswap_CARD32(pc + 0),
                    cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4), 4));
}

void __glXDispSwap_VertexAttrib4ubv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UBVPROC VertexAttrib4ubv = cast(PFNGLVERTEXATTRIB4UBVPROC)__glGetProcAddress("glVertexAttrib4ubv");
    VertexAttrib4ubv(cast(GLuint) bswap_CARD32(pc + 0), cast(const(GLubyte)*) (pc + 4));
}

void __glXDispSwap_VertexAttrib4uiv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UIVPROC VertexAttrib4uiv = cast(PFNGLVERTEXATTRIB4UIVPROC)__glGetProcAddress("glVertexAttrib4uiv");
    VertexAttrib4uiv(cast(GLuint) bswap_CARD32(pc + 0),
                     cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4), 4));
}

void __glXDispSwap_VertexAttrib4usv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4USVPROC VertexAttrib4usv = cast(PFNGLVERTEXATTRIB4USVPROC)__glGetProcAddress("glVertexAttrib4usv");
    VertexAttrib4usv(cast(GLuint) bswap_CARD32(pc + 0),
                     cast(const(GLushort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                       4));
}

void __glXDispSwap_ClampColor(GLbyte* pc)
{
    PFNGLCLAMPCOLORPROC ClampColor = cast(PFNGLCLAMPCOLORPROC)__glGetProcAddress("glClampColor");

    ClampColor(cast(GLenum) bswap_ENUM(pc + 0), cast(GLenum) bswap_ENUM(pc + 4));
}

void __glXDispSwap_BindProgramARB(GLbyte* pc)
{
    PFNGLBINDPROGRAMARBPROC BindProgramARB = cast(PFNGLBINDPROGRAMARBPROC)__glGetProcAddress("glBindProgramARB");
    BindProgramARB(cast(GLenum) bswap_ENUM(pc + 0), cast(GLuint) bswap_CARD32(pc + 4));
}

int __glXDispSwap_DeleteProgramsARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLDELETEPROGRAMSARBPROC DeleteProgramsARB = cast(PFNGLDELETEPROGRAMSARBPROC)__glGetProcAddress("glDeleteProgramsARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        DeleteProgramsARB(n,
                          cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                          0));
        error = Success;
    }

    return error;
}

int __glXDispSwap_GenProgramsARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENPROGRAMSARBPROC GenProgramsARB = cast(PFNGLGENPROGRAMSARBPROC)__glGetProcAddress("glGenProgramsARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* programs = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);
        if (programs is null)
            return BadAlloc;

        GenProgramsARB(n, programs);
        cast(void) bswap_32_array(cast(uint*) programs, n);
        __glXSendReplySwap(cl.client, programs, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetProgramEnvParameterdvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMENVPARAMETERDVARBPROC GetProgramEnvParameterdvARB = cast(PFNGLGETPROGRAMENVPARAMETERDVARBPROC)__glGetProcAddress("glGetProgramEnvParameterdvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] params = void;

        GetProgramEnvParameterdvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                    cast(GLuint) bswap_CARD32(pc + 4), params.ptr);
        cast(void) bswap_64_array(cast(ulong*) params, 4);
        __glXSendReplySwap(cl.client, params.ptr, 4, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetProgramEnvParameterfvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMENVPARAMETERFVARBPROC GetProgramEnvParameterfvARB = cast(PFNGLGETPROGRAMENVPARAMETERFVARBPROC)__glGetProcAddress("glGetProgramEnvParameterfvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLfloat[4] params = void;

        GetProgramEnvParameterfvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                    cast(GLuint) bswap_CARD32(pc + 4), params.ptr);
        cast(void) bswap_32_array(cast(uint*) params, 4);
        __glXSendReplySwap(cl.client, params.ptr, 4, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetProgramLocalParameterdvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMLOCALPARAMETERDVARBPROC GetProgramLocalParameterdvARB = cast(PFNGLGETPROGRAMLOCALPARAMETERDVARBPROC)__glGetProcAddress("glGetProgramLocalParameterdvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] params = void;

        GetProgramLocalParameterdvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                      cast(GLuint) bswap_CARD32(pc + 4), params.ptr);
        cast(void) bswap_64_array(cast(ulong*) params, 4);
        __glXSendReplySwap(cl.client, params.ptr, 4, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetProgramLocalParameterfvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMLOCALPARAMETERFVARBPROC GetProgramLocalParameterfvARB = cast(PFNGLGETPROGRAMLOCALPARAMETERFVARBPROC)__glGetProcAddress("glGetProgramLocalParameterfvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLfloat[4] params = void;

        GetProgramLocalParameterfvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                      cast(GLuint) bswap_CARD32(pc + 4), params.ptr);
        cast(void) bswap_32_array(cast(uint*) params, 4);
        __glXSendReplySwap(cl.client, params.ptr, 4, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetProgramivARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMIVARBPROC GetProgramivARB = cast(PFNGLGETPROGRAMIVARBPROC)__glGetProcAddress("glGetProgramivARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = cast(GLenum) bswap_ENUM(pc + 4);

        const(GLuint) compsize = __glGetProgramivARB_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(GLint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetProgramivARB(cast(GLenum) bswap_ENUM(pc + 0), pname, params);
        cast(void) bswap_32_array(cast(uint*) params, compsize);
        __glXSendReplySwap(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsProgramARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISPROGRAMARBPROC IsProgramARB = cast(PFNGLISPROGRAMARBPROC)__glGetProcAddress("glIsProgramARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsProgramARB(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_ProgramEnvParameter4dvARB(GLbyte* pc)
{
    PFNGLPROGRAMENVPARAMETER4DVARBPROC ProgramEnvParameter4dvARB = cast(PFNGLPROGRAMENVPARAMETER4DVARBPROC)__glGetProcAddress("glProgramEnvParameter4dvARB");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    ProgramEnvParameter4dvARB(cast(GLenum) bswap_ENUM(pc + 0),
                              cast(GLuint) bswap_CARD32(pc + 4),
                              cast(const(GLdouble)*)
                              bswap_64_array(cast(ulong*) (pc + 8), 4));
}

void __glXDispSwap_ProgramEnvParameter4fvARB(GLbyte* pc)
{
    PFNGLPROGRAMENVPARAMETER4FVARBPROC ProgramEnvParameter4fvARB = cast(PFNGLPROGRAMENVPARAMETER4FVARBPROC)__glGetProcAddress("glProgramEnvParameter4fvARB");
    ProgramEnvParameter4fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                              cast(GLuint) bswap_CARD32(pc + 4),
                              cast(const(GLfloat)*)
                              bswap_32_array(cast(uint*) (pc + 8), 4));
}

void __glXDispSwap_ProgramLocalParameter4dvARB(GLbyte* pc)
{
    PFNGLPROGRAMLOCALPARAMETER4DVARBPROC ProgramLocalParameter4dvARB = cast(PFNGLPROGRAMLOCALPARAMETER4DVARBPROC)__glGetProcAddress("glProgramLocalParameter4dvARB");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    ProgramLocalParameter4dvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                cast(GLuint) bswap_CARD32(pc + 4),
                                cast(const(GLdouble)*)
                                bswap_64_array(cast(ulong*) (pc + 8), 4));
}

void __glXDispSwap_ProgramLocalParameter4fvARB(GLbyte* pc)
{
    PFNGLPROGRAMLOCALPARAMETER4FVARBPROC ProgramLocalParameter4fvARB = cast(PFNGLPROGRAMLOCALPARAMETER4FVARBPROC)__glGetProcAddress("glProgramLocalParameter4fvARB");
    ProgramLocalParameter4fvARB(cast(GLenum) bswap_ENUM(pc + 0),
                                cast(GLuint) bswap_CARD32(pc + 4),
                                cast(const(GLfloat)*)
                                bswap_32_array(cast(uint*) (pc + 8), 4));
}

void __glXDispSwap_ProgramStringARB(GLbyte* pc)
{
    PFNGLPROGRAMSTRINGARBPROC ProgramStringARB = cast(PFNGLPROGRAMSTRINGARBPROC)__glGetProcAddress("glProgramStringARB");
    const(GLsizei) len = cast(GLsizei) bswap_CARD32(pc + 8);

    ProgramStringARB(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLenum) bswap_ENUM(pc + 4),
                     len, cast(const(GLvoid)*) (pc + 12));
}

void __glXDispSwap_VertexAttrib1fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1FVARBPROC VertexAttrib1fvARB = cast(PFNGLVERTEXATTRIB1FVARBPROC)__glGetProcAddress("glVertexAttrib1fvARB");
    VertexAttrib1fvARB(cast(GLuint) bswap_CARD32(pc + 0),
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                        1));
}

void __glXDispSwap_VertexAttrib2fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2FVARBPROC VertexAttrib2fvARB = cast(PFNGLVERTEXATTRIB2FVARBPROC)__glGetProcAddress("glVertexAttrib2fvARB");
    VertexAttrib2fvARB(cast(GLuint) bswap_CARD32(pc + 0),
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                        2));
}

void __glXDispSwap_VertexAttrib3fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3FVARBPROC VertexAttrib3fvARB = cast(PFNGLVERTEXATTRIB3FVARBPROC)__glGetProcAddress("glVertexAttrib3fvARB");
    VertexAttrib3fvARB(cast(GLuint) bswap_CARD32(pc + 0),
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                        3));
}

void __glXDispSwap_VertexAttrib4fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4FVARBPROC VertexAttrib4fvARB = cast(PFNGLVERTEXATTRIB4FVARBPROC)__glGetProcAddress("glVertexAttrib4fvARB");
    VertexAttrib4fvARB(cast(GLuint) bswap_CARD32(pc + 0),
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                        4));
}

void __glXDispSwap_BindFramebuffer(GLbyte* pc)
{
    PFNGLBINDFRAMEBUFFERPROC BindFramebuffer = cast(PFNGLBINDFRAMEBUFFERPROC)__glGetProcAddress("glBindFramebuffer");
    BindFramebuffer(cast(GLenum) bswap_ENUM(pc + 0), cast(GLuint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_BindRenderbuffer(GLbyte* pc)
{
    PFNGLBINDRENDERBUFFERPROC BindRenderbuffer = cast(PFNGLBINDRENDERBUFFERPROC)__glGetProcAddress("glBindRenderbuffer");
    BindRenderbuffer(cast(GLenum) bswap_ENUM(pc + 0),
                     cast(GLuint) bswap_CARD32(pc + 4));
}

void __glXDispSwap_BlitFramebuffer(GLbyte* pc)
{
    PFNGLBLITFRAMEBUFFERPROC BlitFramebuffer = cast(PFNGLBLITFRAMEBUFFERPROC)__glGetProcAddress("glBlitFramebuffer");
    BlitFramebuffer(cast(GLint) bswap_CARD32(pc + 0), cast(GLint) bswap_CARD32(pc + 4),
                    cast(GLint) bswap_CARD32(pc + 8), cast(GLint) bswap_CARD32(pc + 12),
                    cast(GLint) bswap_CARD32(pc + 16),
                    cast(GLint) bswap_CARD32(pc + 20),
                    cast(GLint) bswap_CARD32(pc + 24),
                    cast(GLint) bswap_CARD32(pc + 28),
                    cast(GLbitfield) bswap_CARD32(pc + 32),
                    cast(GLenum) bswap_ENUM(pc + 36));
}

int __glXDispSwap_CheckFramebufferStatus(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLCHECKFRAMEBUFFERSTATUSPROC CheckFramebufferStatus = cast(PFNGLCHECKFRAMEBUFFERSTATUSPROC)__glGetProcAddress("glCheckFramebufferStatus");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLenum retval = void;

        retval = CheckFramebufferStatus(cast(GLenum) bswap_ENUM(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_DeleteFramebuffers(GLbyte* pc)
{
    PFNGLDELETEFRAMEBUFFERSPROC DeleteFramebuffers = cast(PFNGLDELETEFRAMEBUFFERSPROC)__glGetProcAddress("glDeleteFramebuffers");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

    DeleteFramebuffers(n,
                       cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                       0));
}

void __glXDispSwap_DeleteRenderbuffers(GLbyte* pc)
{
    PFNGLDELETERENDERBUFFERSPROC DeleteRenderbuffers = cast(PFNGLDELETERENDERBUFFERSPROC)__glGetProcAddress("glDeleteRenderbuffers");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

    DeleteRenderbuffers(n,
                        cast(const(GLuint)*) bswap_32_array(cast(uint*) (pc + 4),
                                                        0));
}

void __glXDispSwap_FramebufferRenderbuffer(GLbyte* pc)
{
    PFNGLFRAMEBUFFERRENDERBUFFERPROC FramebufferRenderbuffer = cast(PFNGLFRAMEBUFFERRENDERBUFFERPROC)__glGetProcAddress("glFramebufferRenderbuffer");
    FramebufferRenderbuffer(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLenum) bswap_ENUM(pc + 4),
                            cast(GLenum) bswap_ENUM(pc + 8),
                            cast(GLuint) bswap_CARD32(pc + 12));
}

void __glXDispSwap_FramebufferTexture1D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE1DPROC FramebufferTexture1D = cast(PFNGLFRAMEBUFFERTEXTURE1DPROC)__glGetProcAddress("glFramebufferTexture1D");
    FramebufferTexture1D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLenum) bswap_ENUM(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLuint) bswap_CARD32(pc + 12),
                         cast(GLint) bswap_CARD32(pc + 16));
}

void __glXDispSwap_FramebufferTexture2D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE2DPROC FramebufferTexture2D = cast(PFNGLFRAMEBUFFERTEXTURE2DPROC)__glGetProcAddress("glFramebufferTexture2D");
    FramebufferTexture2D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLenum) bswap_ENUM(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLuint) bswap_CARD32(pc + 12),
                         cast(GLint) bswap_CARD32(pc + 16));
}

void __glXDispSwap_FramebufferTexture3D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE3DPROC FramebufferTexture3D = cast(PFNGLFRAMEBUFFERTEXTURE3DPROC)__glGetProcAddress("glFramebufferTexture3D");
    FramebufferTexture3D(cast(GLenum) bswap_ENUM(pc + 0),
                         cast(GLenum) bswap_ENUM(pc + 4),
                         cast(GLenum) bswap_ENUM(pc + 8),
                         cast(GLuint) bswap_CARD32(pc + 12),
                         cast(GLint) bswap_CARD32(pc + 16),
                         cast(GLint) bswap_CARD32(pc + 20));
}

void __glXDispSwap_FramebufferTextureLayer(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURELAYERPROC FramebufferTextureLayer = cast(PFNGLFRAMEBUFFERTEXTURELAYERPROC)__glGetProcAddress("glFramebufferTextureLayer");
    FramebufferTextureLayer(cast(GLenum) bswap_ENUM(pc + 0),
                            cast(GLenum) bswap_ENUM(pc + 4),
                            cast(GLuint) bswap_CARD32(pc + 8),
                            cast(GLint) bswap_CARD32(pc + 12),
                            cast(GLint) bswap_CARD32(pc + 16));
}

int __glXDispSwap_GenFramebuffers(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENFRAMEBUFFERSPROC GenFramebuffers = cast(PFNGLGENFRAMEBUFFERSPROC)__glGetProcAddress("glGenFramebuffers");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* framebuffers = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (framebuffers is null)
            return BadAlloc;

        GenFramebuffers(n, framebuffers);
        cast(void) bswap_32_array(cast(uint*) framebuffers, n);
        __glXSendReplySwap(cl.client, framebuffers, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GenRenderbuffers(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENRENDERBUFFERSPROC GenRenderbuffers = cast(PFNGLGENRENDERBUFFERSPROC)__glGetProcAddress("glGenRenderbuffers");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* renderbuffers = cast(GLuint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (renderbuffers is null)
            return BadAlloc;

        GenRenderbuffers(n, renderbuffers);
        cast(void) bswap_32_array(cast(uint*) renderbuffers, n);
        __glXSendReplySwap(cl.client, renderbuffers, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

void __glXDispSwap_GenerateMipmap(GLbyte* pc)
{
    PFNGLGENERATEMIPMAPPROC GenerateMipmap = cast(PFNGLGENERATEMIPMAPPROC)__glGetProcAddress("glGenerateMipmap");
    GenerateMipmap(cast(GLenum) bswap_ENUM(pc + 0));
}

int __glXDispSwap_GetFramebufferAttachmentParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC GetFramebufferAttachmentParameteriv = cast(PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC)__glGetProcAddress("glGetFramebufferAttachmentParameteriv");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLint[1] params = void;

        GetFramebufferAttachmentParameteriv(cast(GLenum) bswap_ENUM(pc + 0),
                                            cast(GLenum) bswap_ENUM(pc + 4),
                                            cast(GLenum) bswap_ENUM(pc + 8),
                                            params.ptr);
        cast(void) bswap_32_array(cast(uint*) params, 1);
        __glXSendReplySwap(cl.client, params.ptr, 1, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_GetRenderbufferParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETRENDERBUFFERPARAMETERIVPROC GetRenderbufferParameteriv = cast(PFNGLGETRENDERBUFFERPARAMETERIVPROC)__glGetProcAddress("glGetRenderbufferParameteriv");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLint[1] params = void;

        GetRenderbufferParameteriv(cast(GLenum) bswap_ENUM(pc + 0),
                                   cast(GLenum) bswap_ENUM(pc + 4), params.ptr);
        cast(void) bswap_32_array(cast(uint*) params, 1);
        __glXSendReplySwap(cl.client, params.ptr, 1, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsFramebuffer(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISFRAMEBUFFERPROC IsFramebuffer = cast(PFNGLISFRAMEBUFFERPROC)__glGetProcAddress("glIsFramebuffer");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsFramebuffer(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDispSwap_IsRenderbuffer(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISRENDERBUFFERPROC IsRenderbuffer = cast(PFNGLISRENDERBUFFERPROC)__glGetProcAddress("glIsRenderbuffer");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, bswap_CARD32(&req.contextTag), &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsRenderbuffer(cast(GLuint) bswap_CARD32(pc + 0));
        __glXSendReplySwap(cl.client, dummy_answer_swap.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDispSwap_RenderbufferStorage(GLbyte* pc)
{
    PFNGLRENDERBUFFERSTORAGEPROC RenderbufferStorage = cast(PFNGLRENDERBUFFERSTORAGEPROC)__glGetProcAddress("glRenderbufferStorage");
    RenderbufferStorage(cast(GLenum) bswap_ENUM(pc + 0),
                        cast(GLenum) bswap_ENUM(pc + 4),
                        cast(GLsizei) bswap_CARD32(pc + 8),
                        cast(GLsizei) bswap_CARD32(pc + 12));
}

void __glXDispSwap_RenderbufferStorageMultisample(GLbyte* pc)
{
    PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC RenderbufferStorageMultisample = cast(PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC)__glGetProcAddress("glRenderbufferStorageMultisample");
    RenderbufferStorageMultisample(cast(GLenum) bswap_ENUM(pc + 0),
                                   cast(GLsizei) bswap_CARD32(pc + 4),
                                   cast(GLenum) bswap_ENUM(pc + 8),
                                   cast(GLsizei) bswap_CARD32(pc + 12),
                                   cast(GLsizei) bswap_CARD32(pc + 16));
}

void __glXDispSwap_SecondaryColor3fvEXT(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3FVEXTPROC SecondaryColor3fvEXT = cast(PFNGLSECONDARYCOLOR3FVEXTPROC)__glGetProcAddress("glSecondaryColor3fvEXT");
    SecondaryColor3fvEXT(cast(const(GLfloat)*)
                         bswap_32_array(cast(uint*) (pc + 0), 3));
}

void __glXDispSwap_FogCoordfvEXT(GLbyte* pc)
{
    PFNGLFOGCOORDFVEXTPROC FogCoordfvEXT = cast(PFNGLFOGCOORDFVEXTPROC)__glGetProcAddress("glFogCoordfvEXT");
    FogCoordfvEXT(cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 0), 1));
}

void __glXDispSwap_VertexAttrib1dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1DVNVPROC VertexAttrib1dvNV = cast(PFNGLVERTEXATTRIB1DVNVPROC)__glGetProcAddress("glVertexAttrib1dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    VertexAttrib1dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                        1));
}

void __glXDispSwap_VertexAttrib1fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1FVNVPROC VertexAttrib1fvNV = cast(PFNGLVERTEXATTRIB1FVNVPROC)__glGetProcAddress("glVertexAttrib1fvNV");
    VertexAttrib1fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                       1));
}

void __glXDispSwap_VertexAttrib1svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1SVNVPROC VertexAttrib1svNV = cast(PFNGLVERTEXATTRIB1SVNVPROC)__glGetProcAddress("glVertexAttrib1svNV");
    VertexAttrib1svNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                       1));
}

void __glXDispSwap_VertexAttrib2dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2DVNVPROC VertexAttrib2dvNV = cast(PFNGLVERTEXATTRIB2DVNVPROC)__glGetProcAddress("glVertexAttrib2dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    VertexAttrib2dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                        2));
}

void __glXDispSwap_VertexAttrib2fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2FVNVPROC VertexAttrib2fvNV = cast(PFNGLVERTEXATTRIB2FVNVPROC)__glGetProcAddress("glVertexAttrib2fvNV");
    VertexAttrib2fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                       2));
}

void __glXDispSwap_VertexAttrib2svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2SVNVPROC VertexAttrib2svNV = cast(PFNGLVERTEXATTRIB2SVNVPROC)__glGetProcAddress("glVertexAttrib2svNV");
    VertexAttrib2svNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                       2));
}

void __glXDispSwap_VertexAttrib3dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3DVNVPROC VertexAttrib3dvNV = cast(PFNGLVERTEXATTRIB3DVNVPROC)__glGetProcAddress("glVertexAttrib3dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    VertexAttrib3dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                        3));
}

void __glXDispSwap_VertexAttrib3fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3FVNVPROC VertexAttrib3fvNV = cast(PFNGLVERTEXATTRIB3FVNVPROC)__glGetProcAddress("glVertexAttrib3fvNV");
    VertexAttrib3fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                       3));
}

void __glXDispSwap_VertexAttrib3svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3SVNVPROC VertexAttrib3svNV = cast(PFNGLVERTEXATTRIB3SVNVPROC)__glGetProcAddress("glVertexAttrib3svNV");
    VertexAttrib3svNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                       3));
}

void __glXDispSwap_VertexAttrib4dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4DVNVPROC VertexAttrib4dvNV = cast(PFNGLVERTEXATTRIB4DVNVPROC)__glGetProcAddress("glVertexAttrib4dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    VertexAttrib4dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 4),
                                                        4));
}

void __glXDispSwap_VertexAttrib4fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4FVNVPROC VertexAttrib4fvNV = cast(PFNGLVERTEXATTRIB4FVNVPROC)__glGetProcAddress("glVertexAttrib4fvNV");
    VertexAttrib4fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 4),
                                                       4));
}

void __glXDispSwap_VertexAttrib4svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4SVNVPROC VertexAttrib4svNV = cast(PFNGLVERTEXATTRIB4SVNVPROC)__glGetProcAddress("glVertexAttrib4svNV");
    VertexAttrib4svNV(cast(GLuint) bswap_CARD32(pc + 0),
                      cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 4),
                                                       4));
}

void __glXDispSwap_VertexAttrib4ubvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UBVNVPROC VertexAttrib4ubvNV = cast(PFNGLVERTEXATTRIB4UBVNVPROC)__glGetProcAddress("glVertexAttrib4ubvNV");
    VertexAttrib4ubvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       cast(const(GLubyte)*) (pc + 4));
}

void __glXDispSwap_VertexAttribs1dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1DVNVPROC VertexAttribs1dvNV = cast(PFNGLVERTEXATTRIBS1DVNVPROC)__glGetProcAddress("glVertexAttribs1dvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 8)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs1dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 8),
                                                         0));
}

void __glXDispSwap_VertexAttribs1fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1FVNVPROC VertexAttribs1fvNV = cast(PFNGLVERTEXATTRIBS1FVNVPROC)__glGetProcAddress("glVertexAttribs1fvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs1fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs1svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1SVNVPROC VertexAttribs1svNV = cast(PFNGLVERTEXATTRIBS1SVNVPROC)__glGetProcAddress("glVertexAttribs1svNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs1svNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs2dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2DVNVPROC VertexAttribs2dvNV = cast(PFNGLVERTEXATTRIBS2DVNVPROC)__glGetProcAddress("glVertexAttribs2dvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 16)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs2dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 8),
                                                         0));
}

void __glXDispSwap_VertexAttribs2fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2FVNVPROC VertexAttribs2fvNV = cast(PFNGLVERTEXATTRIBS2FVNVPROC)__glGetProcAddress("glVertexAttribs2fvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs2fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs2svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2SVNVPROC VertexAttribs2svNV = cast(PFNGLVERTEXATTRIBS2SVNVPROC)__glGetProcAddress("glVertexAttribs2svNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs2svNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs3dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3DVNVPROC VertexAttribs3dvNV = cast(PFNGLVERTEXATTRIBS3DVNVPROC)__glGetProcAddress("glVertexAttribs3dvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 24)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs3dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 8),
                                                         0));
}

void __glXDispSwap_VertexAttribs3fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3FVNVPROC VertexAttribs3fvNV = cast(PFNGLVERTEXATTRIBS3FVNVPROC)__glGetProcAddress("glVertexAttribs3fvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs3fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs3svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3SVNVPROC VertexAttribs3svNV = cast(PFNGLVERTEXATTRIBS3SVNVPROC)__glGetProcAddress("glVertexAttribs3svNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs3svNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs4dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4DVNVPROC VertexAttribs4dvNV = cast(PFNGLVERTEXATTRIBS4DVNVPROC)__glGetProcAddress("glVertexAttribs4dvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 32)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs4dvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLdouble)*) bswap_64_array(cast(ulong*) (pc + 8),
                                                         0));
}

void __glXDispSwap_VertexAttribs4fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4FVNVPROC VertexAttribs4fvNV = cast(PFNGLVERTEXATTRIBS4FVNVPROC)__glGetProcAddress("glVertexAttribs4fvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs4fvNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLfloat)*) bswap_32_array(cast(uint*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs4svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4SVNVPROC VertexAttribs4svNV = cast(PFNGLVERTEXATTRIBS4SVNVPROC)__glGetProcAddress("glVertexAttribs4svNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs4svNV(cast(GLuint) bswap_CARD32(pc + 0),
                       n,
                       cast(const(GLshort)*) bswap_16_array(cast(ushort*) (pc + 8),
                                                        0));
}

void __glXDispSwap_VertexAttribs4ubvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4UBVNVPROC VertexAttribs4ubvNV = cast(PFNGLVERTEXATTRIBS4UBVNVPROC)__glGetProcAddress("glVertexAttribs4ubvNV");
    const(GLsizei) n = cast(GLsizei) bswap_CARD32(pc + 4);

    VertexAttribs4ubvNV(cast(GLuint) bswap_CARD32(pc + 0),
                        n, cast(const(GLubyte)*) (pc + 8));
}

void __glXDispSwap_ActiveStencilFaceEXT(GLbyte* pc)
{
    PFNGLACTIVESTENCILFACEEXTPROC ActiveStencilFaceEXT = cast(PFNGLACTIVESTENCILFACEEXTPROC)__glGetProcAddress("glActiveStencilFaceEXT");
    ActiveStencilFaceEXT(cast(GLenum) bswap_ENUM(pc + 0));
}
