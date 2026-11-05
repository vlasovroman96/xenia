module glx.indirect_dispatch;
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
 import Xext.glx.fix;
import glx.glxext; 
import glx.glxcmds;
import glx.indirect_size_get;
alias CARD32 = x11.Xmd.CARD32;
alias BOOL = x11.Xmd.BOOL;


// enum string __GLX_PAD(string x) = `(((` ~ x ~ `) + 3) & ~3)`;

enum __GLX_PIXEL_3D_HDR =`	
    BOOL	swapBytes;	
    BOOL	lsbFirst;	
    CARD8	reserved0;	
    CARD8	reserved1;	
    CARD32	rowLength;	
    CARD32	imageHeight;	
    CARD32	imageDepth;	
    CARD32	skipRows;	
    CARD32	skipImages;	
    CARD32	skipVolumes;	
    CARD32	skipPixels;	
    CARD32	alignment;`;

struct __GLXpixel3DHeader {
    mixin(__GLX_PIXEL_3D_HDR);
}

// alias _GLXpixel3DHeader = __GLX_PIXEL_3D_HDR;

// GLboolean __glXErrorOccured();
// void __glXClearErrorOccured();

private const(uint)[2] dummy_answer = [ 0, 0 ];

int __glXDisp_NewList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glNewList(*cast(GLuint*) (pc + 0), *cast(GLenum*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_EndList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glEndList();
        error = Success;
    }

    return error;
}

void __glXDisp_CallList(GLbyte* pc)
{
    glCallList(*cast(GLuint*) (pc + 0));
}

void __glXDisp_CallLists(GLbyte* pc)
{
    const(GLsizei) n = *cast(GLsizei*) (pc + 0);
    const(GLenum) type = *cast(GLenum*) (pc + 4);
    const(GLvoid)* lists = cast(const(GLvoid)*) (pc + 8);

    lists = cast(const(GLvoid)*) (pc + 8);

    glCallLists(n, type, lists);
}

int __glXDisp_DeleteLists(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glDeleteLists(*cast(GLuint*) (pc + 0), *cast(GLsizei*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_GenLists(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLuint retval = void;

        retval = glGenLists(*cast(GLsizei*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_ListBase(GLbyte* pc)
{
    glListBase(*cast(GLuint*) (pc + 0));
}

void __glXDisp_Begin(GLbyte* pc)
{
    glBegin(*cast(GLenum*) (pc + 0));
}

void __glXDisp_Bitmap(GLbyte* pc)
{
    const(GLubyte*) bitmap = cast(const(GLubyte*)) (cast(const(GLubyte)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glBitmap(*cast(GLsizei*) (pc + 20),
             *cast(GLsizei*) (pc + 24),
             *cast(GLfloat*) (pc + 28),
             *cast(GLfloat*) (pc + 32),
             *cast(GLfloat*) (pc + 36), *cast(GLfloat*) (pc + 40), bitmap);
}

void __glXDisp_Color3bv(GLbyte* pc)
{
    glColor3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDisp_Color3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glColor3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Color3fv(GLbyte* pc)
{
    glColor3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Color3iv(GLbyte* pc)
{
    glColor3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Color3sv(GLbyte* pc)
{
    glColor3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Color3ubv(GLbyte* pc)
{
    glColor3ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDisp_Color3uiv(GLbyte* pc)
{
    glColor3uiv(cast(const(GLuint)*) (pc + 0));
}

void __glXDisp_Color3usv(GLbyte* pc)
{
    glColor3usv(cast(const(GLushort)*) (pc + 0));
}

void __glXDisp_Color4bv(GLbyte* pc)
{
    glColor4bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDisp_Color4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glColor4dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Color4fv(GLbyte* pc)
{
    glColor4fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Color4iv(GLbyte* pc)
{
    glColor4iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Color4sv(GLbyte* pc)
{
    glColor4sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Color4ubv(GLbyte* pc)
{
    glColor4ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDisp_Color4uiv(GLbyte* pc)
{
    glColor4uiv(cast(const(GLuint)*) (pc + 0));
}

void __glXDisp_Color4usv(GLbyte* pc)
{
    glColor4usv(cast(const(GLushort)*) (pc + 0));
}

void __glXDisp_EdgeFlagv(GLbyte* pc)
{
    glEdgeFlagv(cast(const(GLboolean)*) (pc + 0));
}

void __glXDisp_End(GLbyte* pc)
{
    glEnd();
}

void __glXDisp_Indexdv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glIndexdv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Indexfv(GLbyte* pc)
{
    glIndexfv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Indexiv(GLbyte* pc)
{
    glIndexiv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Indexsv(GLbyte* pc)
{
    glIndexsv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Normal3bv(GLbyte* pc)
{
    glNormal3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDisp_Normal3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glNormal3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Normal3fv(GLbyte* pc)
{
    glNormal3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Normal3iv(GLbyte* pc)
{
    glNormal3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Normal3sv(GLbyte* pc)
{
    glNormal3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_RasterPos2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glRasterPos2dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_RasterPos2fv(GLbyte* pc)
{
    glRasterPos2fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_RasterPos2iv(GLbyte* pc)
{
    glRasterPos2iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_RasterPos2sv(GLbyte* pc)
{
    glRasterPos2sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_RasterPos3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glRasterPos3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_RasterPos3fv(GLbyte* pc)
{
    glRasterPos3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_RasterPos3iv(GLbyte* pc)
{
    glRasterPos3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_RasterPos3sv(GLbyte* pc)
{
    glRasterPos3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_RasterPos4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRasterPos4dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_RasterPos4fv(GLbyte* pc)
{
    glRasterPos4fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_RasterPos4iv(GLbyte* pc)
{
    glRasterPos4iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_RasterPos4sv(GLbyte* pc)
{
    glRasterPos4sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Rectdv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRectdv(cast(const(GLdouble)*) (pc + 0), cast(const(GLdouble)*) (pc + 16));
}

void __glXDisp_Rectfv(GLbyte* pc)
{
    glRectfv(cast(const(GLfloat)*) (pc + 0), cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_Rectiv(GLbyte* pc)
{
    glRectiv(cast(const(GLint)*) (pc + 0), cast(const(GLint)*) (pc + 8));
}

void __glXDisp_Rectsv(GLbyte* pc)
{
    glRectsv(cast(const(GLshort)*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_TexCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glTexCoord1dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_TexCoord1fv(GLbyte* pc)
{
    glTexCoord1fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_TexCoord1iv(GLbyte* pc)
{
    glTexCoord1iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_TexCoord1sv(GLbyte* pc)
{
    glTexCoord1sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_TexCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glTexCoord2dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_TexCoord2fv(GLbyte* pc)
{
    glTexCoord2fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_TexCoord2iv(GLbyte* pc)
{
    glTexCoord2iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_TexCoord2sv(GLbyte* pc)
{
    glTexCoord2sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_TexCoord3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glTexCoord3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_TexCoord3fv(GLbyte* pc)
{
    glTexCoord3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_TexCoord3iv(GLbyte* pc)
{
    glTexCoord3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_TexCoord3sv(GLbyte* pc)
{
    glTexCoord3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_TexCoord4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glTexCoord4dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_TexCoord4fv(GLbyte* pc)
{
    glTexCoord4fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_TexCoord4iv(GLbyte* pc)
{
    glTexCoord4iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_TexCoord4sv(GLbyte* pc)
{
    glTexCoord4sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Vertex2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glVertex2dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Vertex2fv(GLbyte* pc)
{
    glVertex2fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Vertex2iv(GLbyte* pc)
{
    glVertex2iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Vertex2sv(GLbyte* pc)
{
    glVertex2sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Vertex3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glVertex3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Vertex3fv(GLbyte* pc)
{
    glVertex3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Vertex3iv(GLbyte* pc)
{
    glVertex3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Vertex3sv(GLbyte* pc)
{
    glVertex3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_Vertex4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glVertex4dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Vertex4fv(GLbyte* pc)
{
    glVertex4fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_Vertex4iv(GLbyte* pc)
{
    glVertex4iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_Vertex4sv(GLbyte* pc)
{
    glVertex4sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_ClipPlane(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    glClipPlane(*cast(GLenum*) (pc + 32), cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_ColorMaterial(GLbyte* pc)
{
    glColorMaterial(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_CullFace(GLbyte* pc)
{
    glCullFace(*cast(GLenum*) (pc + 0));
}

void __glXDisp_Fogf(GLbyte* pc)
{
    glFogf(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_Fogfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 4);

    glFogfv(pname, params);
}

void __glXDisp_Fogi(GLbyte* pc)
{
    glFogi(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4));
}

void __glXDisp_Fogiv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 4);

    glFogiv(pname, params);
}

void __glXDisp_FrontFace(GLbyte* pc)
{
    glFrontFace(*cast(GLenum*) (pc + 0));
}

void __glXDisp_Hint(GLbyte* pc)
{
    glHint(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_Lightf(GLbyte* pc)
{
    glLightf(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_Lightfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glLightfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_Lighti(GLbyte* pc)
{
    glLighti(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_Lightiv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glLightiv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_LightModelf(GLbyte* pc)
{
    glLightModelf(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_LightModelfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 4);

    glLightModelfv(pname, params);
}

void __glXDisp_LightModeli(GLbyte* pc)
{
    glLightModeli(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4));
}

void __glXDisp_LightModeliv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 4);

    glLightModeliv(pname, params);
}

void __glXDisp_LineStipple(GLbyte* pc)
{
    glLineStipple(*cast(GLint*) (pc + 0), *cast(GLushort*) (pc + 4));
}

void __glXDisp_LineWidth(GLbyte* pc)
{
    glLineWidth(*cast(GLfloat*) (pc + 0));
}

void __glXDisp_Materialf(GLbyte* pc)
{
    glMaterialf(*cast(GLenum*) (pc + 0),
                *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_Materialfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glMaterialfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_Materiali(GLbyte* pc)
{
    glMateriali(*cast(GLenum*) (pc + 0),
                *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_Materialiv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glMaterialiv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_PointSize(GLbyte* pc)
{
    glPointSize(*cast(GLfloat*) (pc + 0));
}

void __glXDisp_PolygonMode(GLbyte* pc)
{
    glPolygonMode(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_PolygonStipple(GLbyte* pc)
{
    const(GLubyte*) mask = cast(const(GLubyte*)) (cast(const(GLubyte)*) ((pc + 20)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glPolygonStipple(mask);
}

void __glXDisp_Scissor(GLbyte* pc)
{
    glScissor(*cast(GLint*) (pc + 0),
              *cast(GLint*) (pc + 4),
              *cast(GLsizei*) (pc + 8), *cast(GLsizei*) (pc + 12));
}

void __glXDisp_ShadeModel(GLbyte* pc)
{
    glShadeModel(*cast(GLenum*) (pc + 0));
}

void __glXDisp_TexParameterf(GLbyte* pc)
{
    glTexParameterf(*cast(GLenum*) (pc + 0),
                    *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_TexParameterfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glTexParameterfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexParameteri(GLbyte* pc)
{
    glTexParameteri(*cast(GLenum*) (pc + 0),
                    *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_TexParameteriv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glTexParameteriv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexImage1D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 52)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexImage1D(*cast(GLenum*) (pc + 20),
                 *cast(GLint*) (pc + 24),
                 *cast(GLint*) (pc + 28),
                 *cast(GLsizei*) (pc + 32),
                 *cast(GLint*) (pc + 40),
                 *cast(GLenum*) (pc + 44), *cast(GLenum*) (pc + 48), pixels);
}

void __glXDisp_TexImage2D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 52)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexImage2D(*cast(GLenum*) (pc + 20),
                 *cast(GLint*) (pc + 24),
                 *cast(GLint*) (pc + 28),
                 *cast(GLsizei*) (pc + 32),
                 *cast(GLsizei*) (pc + 36),
                 *cast(GLint*) (pc + 40),
                 *cast(GLenum*) (pc + 44), *cast(GLenum*) (pc + 48), pixels);
}

void __glXDisp_TexEnvf(GLbyte* pc)
{
    glTexEnvf(*cast(GLenum*) (pc + 0),
              *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_TexEnvfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glTexEnvfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexEnvi(GLbyte* pc)
{
    glTexEnvi(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_TexEnviv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glTexEnviv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexGend(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glTexGend(*cast(GLenum*) (pc + 8),
              *cast(GLenum*) (pc + 12), *cast(GLdouble*) (pc + 0));
}

void __glXDisp_TexGendv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLdouble)* params = void;

version (__GLX_ALIGN64) {
    const(GLuint) compsize = __glTexGendv_size(pname);
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(compsize * 8)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    params = cast(const(GLdouble)*) (pc + 8);

    glTexGendv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexGenf(GLbyte* pc)
{
    glTexGenf(*cast(GLenum*) (pc + 0),
              *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_TexGenfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glTexGenfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_TexGeni(GLbyte* pc)
{
    glTexGeni(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_TexGeniv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glTexGeniv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_InitNames(GLbyte* pc)
{
    glInitNames();
}

void __glXDisp_LoadName(GLbyte* pc)
{
    glLoadName(*cast(GLuint*) (pc + 0));
}

void __glXDisp_PassThrough(GLbyte* pc)
{
    glPassThrough(*cast(GLfloat*) (pc + 0));
}

void __glXDisp_PopName(GLbyte* pc)
{
    glPopName();
}

void __glXDisp_PushName(GLbyte* pc)
{
    glPushName(*cast(GLuint*) (pc + 0));
}

void __glXDisp_DrawBuffer(GLbyte* pc)
{
    glDrawBuffer(*cast(GLenum*) (pc + 0));
}

void __glXDisp_Clear(GLbyte* pc)
{
    glClear(*cast(GLbitfield*) (pc + 0));
}

void __glXDisp_ClearAccum(GLbyte* pc)
{
    glClearAccum(*cast(GLfloat*) (pc + 0),
                 *cast(GLfloat*) (pc + 4),
                 *cast(GLfloat*) (pc + 8), *cast(GLfloat*) (pc + 12));
}

void __glXDisp_ClearIndex(GLbyte* pc)
{
    glClearIndex(*cast(GLfloat*) (pc + 0));
}

void __glXDisp_ClearColor(GLbyte* pc)
{
    glClearColor(*cast(GLclampf*) (pc + 0),
                 *cast(GLclampf*) (pc + 4),
                 *cast(GLclampf*) (pc + 8), *cast(GLclampf*) (pc + 12));
}

void __glXDisp_ClearStencil(GLbyte* pc)
{
    glClearStencil(*cast(GLint*) (pc + 0));
}

void __glXDisp_ClearDepth(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glClearDepth(*cast(GLclampd*) (pc + 0));
}

void __glXDisp_StencilMask(GLbyte* pc)
{
    glStencilMask(*cast(GLuint*) (pc + 0));
}

void __glXDisp_ColorMask(GLbyte* pc)
{
    glColorMask(*cast(GLboolean*) (pc + 0),
                *cast(GLboolean*) (pc + 1),
                *cast(GLboolean*) (pc + 2), *cast(GLboolean*) (pc + 3));
}

void __glXDisp_DepthMask(GLbyte* pc)
{
    glDepthMask(*cast(GLboolean*) (pc + 0));
}

void __glXDisp_IndexMask(GLbyte* pc)
{
    glIndexMask(*cast(GLuint*) (pc + 0));
}

void __glXDisp_Accum(GLbyte* pc)
{
    glAccum(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_Disable(GLbyte* pc)
{
    glDisable(*cast(GLenum*) (pc + 0));
}

void __glXDisp_Enable(GLbyte* pc)
{
    glEnable(*cast(GLenum*) (pc + 0));
}

void __glXDisp_PopAttrib(GLbyte* pc)
{
    glPopAttrib();
}

void __glXDisp_PushAttrib(GLbyte* pc)
{
    glPushAttrib(*cast(GLbitfield*) (pc + 0));
}

void __glXDisp_MapGrid1d(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    glMapGrid1d(*cast(GLint*) (pc + 16),
                *cast(GLdouble*) (pc + 0), *cast(GLdouble*) (pc + 8));
}

void __glXDisp_MapGrid1f(GLbyte* pc)
{
    glMapGrid1f(*cast(GLint*) (pc + 0),
                *cast(GLfloat*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_MapGrid2d(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    glMapGrid2d(*cast(GLint*) (pc + 32),
                *cast(GLdouble*) (pc + 0),
                *cast(GLdouble*) (pc + 8),
                *cast(GLint*) (pc + 36),
                *cast(GLdouble*) (pc + 16), *cast(GLdouble*) (pc + 24));
}

void __glXDisp_MapGrid2f(GLbyte* pc)
{
    glMapGrid2f(*cast(GLint*) (pc + 0),
                *cast(GLfloat*) (pc + 4),
                *cast(GLfloat*) (pc + 8),
                *cast(GLint*) (pc + 12),
                *cast(GLfloat*) (pc + 16), *cast(GLfloat*) (pc + 20));
}

void __glXDisp_EvalCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    glEvalCoord1dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_EvalCoord1fv(GLbyte* pc)
{
    glEvalCoord1fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_EvalCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glEvalCoord2dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_EvalCoord2fv(GLbyte* pc)
{
    glEvalCoord2fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_EvalMesh1(GLbyte* pc)
{
    glEvalMesh1(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_EvalPoint1(GLbyte* pc)
{
    glEvalPoint1(*cast(GLint*) (pc + 0));
}

void __glXDisp_EvalMesh2(GLbyte* pc)
{
    glEvalMesh2(*cast(GLenum*) (pc + 0),
                *cast(GLint*) (pc + 4),
                *cast(GLint*) (pc + 8),
                *cast(GLint*) (pc + 12), *cast(GLint*) (pc + 16));
}

void __glXDisp_EvalPoint2(GLbyte* pc)
{
    glEvalPoint2(*cast(GLint*) (pc + 0), *cast(GLint*) (pc + 4));
}

void __glXDisp_AlphaFunc(GLbyte* pc)
{
    glAlphaFunc(*cast(GLenum*) (pc + 0), *cast(GLclampf*) (pc + 4));
}

void __glXDisp_BlendFunc(GLbyte* pc)
{
    glBlendFunc(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_LogicOp(GLbyte* pc)
{
    glLogicOp(*cast(GLenum*) (pc + 0));
}

void __glXDisp_StencilFunc(GLbyte* pc)
{
    glStencilFunc(*cast(GLenum*) (pc + 0),
                  *cast(GLint*) (pc + 4), *cast(GLuint*) (pc + 8));
}

void __glXDisp_StencilOp(GLbyte* pc)
{
    glStencilOp(*cast(GLenum*) (pc + 0),
                *cast(GLenum*) (pc + 4), *cast(GLenum*) (pc + 8));
}

void __glXDisp_DepthFunc(GLbyte* pc)
{
    glDepthFunc(*cast(GLenum*) (pc + 0));
}

void __glXDisp_PixelZoom(GLbyte* pc)
{
    glPixelZoom(*cast(GLfloat*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_PixelTransferf(GLbyte* pc)
{
    glPixelTransferf(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_PixelTransferi(GLbyte* pc)
{
    glPixelTransferi(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4));
}

int __glXDisp_PixelStoref(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glPixelStoref(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_PixelStorei(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        glPixelStorei(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4));
        error = Success;
    }

    return error;
}

void __glXDisp_PixelMapfv(GLbyte* pc)
{
    const(GLsizei) mapsize = *cast(GLsizei*) (pc + 4);

    glPixelMapfv(*cast(GLenum*) (pc + 0), mapsize, cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_PixelMapuiv(GLbyte* pc)
{
    const(GLsizei) mapsize = *cast(GLsizei*) (pc + 4);

    glPixelMapuiv(*cast(GLenum*) (pc + 0), mapsize, cast(const(GLuint)*) (pc + 8));
}

void __glXDisp_PixelMapusv(GLbyte* pc)
{
    const(GLsizei) mapsize = *cast(GLsizei*) (pc + 4);

    glPixelMapusv(*cast(GLenum*) (pc + 0), mapsize, cast(const(GLushort)*) (pc + 8));
}

void __glXDisp_ReadBuffer(GLbyte* pc)
{
    glReadBuffer(*cast(GLenum*) (pc + 0));
}

void __glXDisp_CopyPixels(GLbyte* pc)
{
    glCopyPixels(*cast(GLint*) (pc + 0),
                 *cast(GLint*) (pc + 4),
                 *cast(GLsizei*) (pc + 8),
                 *cast(GLsizei*) (pc + 12), *cast(GLenum*) (pc + 16));
}

void __glXDisp_DrawPixels(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 36)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glDrawPixels(*cast(GLsizei*) (pc + 20),
                 *cast(GLsizei*) (pc + 24),
                 *cast(GLenum*) (pc + 28), *cast(GLenum*) (pc + 32), pixels);
}

int __glXDisp_GetBooleanv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetBooleanv_size(pname);
        GLboolean[200] answerBuffer = void;
        GLboolean* params = cast(ubyte*)__glXGetAnswerBuffer(cl, compsize, answerBuffer.ptr,
                                 answerBuffer.sizeof, 1);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetBooleanv(pname, params);
        __glXSendReply(cl.client, params, compsize, 1, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetClipPlane(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] equation = void;

        glGetClipPlane(*cast(GLenum*) (pc + 0), equation.ptr);
        __glXSendReply(cl.client, equation.ptr, 4, 8, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetDoublev(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetDoublev_size(pname);
        GLdouble[200] answerBuffer = void;
        GLdouble* params = cast(double*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetDoublev(pname, params);
        __glXSendReply(cl.client, params, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetError(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLenum retval = void;

        retval = glGetError();
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDisp_GetFloatv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetFloatv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetFloatv(pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetIntegerv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetIntegerv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetIntegerv(pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetLightfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetLightfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetLightfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetLightiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetLightiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetLightiv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMapdv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = *cast(GLenum*) (pc + 0);
        const(GLenum) query = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMapdv_size(target, query);
        GLdouble[200] answerBuffer = void;
        GLdouble* v = cast(double*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapdv(target, query, v);
        __glXSendReply(cl.client, v, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMapfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = *cast(GLenum*) (pc + 0);
        const(GLenum) query = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMapfv_size(target, query);
        GLfloat[200] answerBuffer = void;
        GLfloat* v = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapfv(target, query, v);
        __glXSendReply(cl.client, v, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMapiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) target = *cast(GLenum*) (pc + 0);
        const(GLenum) query = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMapiv_size(target, query);
        GLint[200] answerBuffer = void;
        GLint* v = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (v is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMapiv(target, query, v);
        __glXSendReply(cl.client, v, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMaterialfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMaterialfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMaterialfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMaterialiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMaterialiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMaterialiv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetPixelMapfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetPixelMapfv_size(map);
        GLfloat[200] answerBuffer = void;
        GLfloat* values = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapfv(map, values);
        __glXSendReply(cl.client, values, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetPixelMapuiv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetPixelMapuiv_size(map);
        GLuint[200] answerBuffer = void;
        GLuint* values = cast(uint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapuiv(map, values);
        __glXSendReply(cl.client, values, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetPixelMapusv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) map = *cast(GLenum*) (pc + 0);

        const(GLuint) compsize = __glGetPixelMapusv_size(map);
        GLushort[200] answerBuffer = void;
        GLushort* values = cast(ushort*)__glXGetAnswerBuffer(cl, compsize * 2, answerBuffer.ptr,
                                 answerBuffer.sizeof, 2);

        if (values is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetPixelMapusv(map, values);
        __glXSendReply(cl.client, values, compsize, 2, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexEnvfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexEnvfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexEnvfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexEnviv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexEnviv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexEnviv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexGendv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexGendv_size(pname);
        GLdouble[200] answerBuffer = void;
        GLdouble* params = cast(double*)__glXGetAnswerBuffer(cl, compsize * 8, answerBuffer.ptr,
                                 answerBuffer.sizeof, 8);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGendv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexGenfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexGenfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGenfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexGeniv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexGeniv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexGeniv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetTexParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexLevelParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 8);

        const(GLuint) compsize = __glGetTexLevelParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexLevelParameterfv(*cast(GLenum*) (pc + 0),
                                 *cast(GLint*) (pc + 4), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetTexLevelParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 8);

        const(GLuint) compsize = __glGetTexLevelParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetTexLevelParameteriv(*cast(GLenum*) (pc + 0),
                                 *cast(GLint*) (pc + 4), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_IsEnabled(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsEnabled(*cast(GLenum*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDisp_IsList(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsList(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_DepthRange(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 16);
        pc -= 4;
    }
}

    glDepthRange(*cast(GLclampd*) (pc + 0), *cast(GLclampd*) (pc + 8));
}

void __glXDisp_Frustum(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 48);
        pc -= 4;
    }
}

    glFrustum(*cast(GLdouble*) (pc + 0),
              *cast(GLdouble*) (pc + 8),
              *cast(GLdouble*) (pc + 16),
              *cast(GLdouble*) (pc + 24),
              *cast(GLdouble*) (pc + 32), *cast(GLdouble*) (pc + 40));
}

void __glXDisp_LoadIdentity(GLbyte* pc)
{
    glLoadIdentity();
}

void __glXDisp_LoadMatrixf(GLbyte* pc)
{
    glLoadMatrixf(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_LoadMatrixd(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 128);
        pc -= 4;
    }
}

    glLoadMatrixd(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_MatrixMode(GLbyte* pc)
{
    glMatrixMode(*cast(GLenum*) (pc + 0));
}

void __glXDisp_MultMatrixf(GLbyte* pc)
{
    glMultMatrixf(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_MultMatrixd(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 128);
        pc -= 4;
    }
}

    glMultMatrixd(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_Ortho(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 48);
        pc -= 4;
    }
}

    glOrtho(*cast(GLdouble*) (pc + 0),
            *cast(GLdouble*) (pc + 8),
            *cast(GLdouble*) (pc + 16),
            *cast(GLdouble*) (pc + 24),
            *cast(GLdouble*) (pc + 32), *cast(GLdouble*) (pc + 40));
}

void __glXDisp_PopMatrix(GLbyte* pc)
{
    glPopMatrix();
}

void __glXDisp_PushMatrix(GLbyte* pc)
{
    glPushMatrix();
}

void __glXDisp_Rotated(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 32);
        pc -= 4;
    }
}

    glRotated(*cast(GLdouble*) (pc + 0),
              *cast(GLdouble*) (pc + 8),
              *cast(GLdouble*) (pc + 16), *cast(GLdouble*) (pc + 24));
}

void __glXDisp_Rotatef(GLbyte* pc)
{
    glRotatef(*cast(GLfloat*) (pc + 0),
              *cast(GLfloat*) (pc + 4),
              *cast(GLfloat*) (pc + 8), *cast(GLfloat*) (pc + 12));
}

void __glXDisp_Scaled(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glScaled(*cast(GLdouble*) (pc + 0),
             *cast(GLdouble*) (pc + 8), *cast(GLdouble*) (pc + 16));
}

void __glXDisp_Scalef(GLbyte* pc)
{
    glScalef(*cast(GLfloat*) (pc + 0),
             *cast(GLfloat*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_Translated(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    glTranslated(*cast(GLdouble*) (pc + 0),
                 *cast(GLdouble*) (pc + 8), *cast(GLdouble*) (pc + 16));
}

void __glXDisp_Translatef(GLbyte* pc)
{
    glTranslatef(*cast(GLfloat*) (pc + 0),
                 *cast(GLfloat*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_Viewport(GLbyte* pc)
{
    glViewport(*cast(GLint*) (pc + 0),
               *cast(GLint*) (pc + 4),
               *cast(GLsizei*) (pc + 8), *cast(GLsizei*) (pc + 12));
}

void __glXDisp_BindTexture(GLbyte* pc)
{
    glBindTexture(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4));
}

void __glXDisp_Indexubv(GLbyte* pc)
{
    glIndexubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDisp_PolygonOffset(GLbyte* pc)
{
    glPolygonOffset(*cast(GLfloat*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

int __glXDisp_AreTexturesResident(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLboolean retval = void;
        GLboolean[200] answerBuffer = void;
        GLboolean* residences = cast(ubyte*)__glXGetAnswerBuffer(cl, n, answerBuffer.ptr, answerBuffer.sizeof, 1);

        if (residences is null)
            return BadAlloc;
        retval =
            glAreTexturesResident(n, cast(const(GLuint)*) (pc + 4), residences);
        __glXSendReply(cl.client, residences, n, 1, GL_TRUE, retval);
        error = Success;
    }

    return error;
}

int __glXDisp_AreTexturesResidentEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLboolean retval = void;
        GLboolean[200] answerBuffer = void;
        GLboolean* residences = cast(ubyte*)__glXGetAnswerBuffer(cl, n, answerBuffer.ptr, answerBuffer.sizeof, 1);

        if (residences is null)
            return BadAlloc;
        retval =
            glAreTexturesResident(n, cast(const(GLuint)*) (pc + 4), residences);
        __glXSendReply(cl.client, residences, n, 1, GL_TRUE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_CopyTexImage1D(GLbyte* pc)
{
    glCopyTexImage1D(*cast(GLenum*) (pc + 0),
                     *cast(GLint*) (pc + 4),
                     *cast(GLenum*) (pc + 8),
                     *cast(GLint*) (pc + 12),
                     *cast(GLint*) (pc + 16),
                     *cast(GLsizei*) (pc + 20), *cast(GLint*) (pc + 24));
}

void __glXDisp_CopyTexImage2D(GLbyte* pc)
{
    glCopyTexImage2D(*cast(GLenum*) (pc + 0),
                     *cast(GLint*) (pc + 4),
                     *cast(GLenum*) (pc + 8),
                     *cast(GLint*) (pc + 12),
                     *cast(GLint*) (pc + 16),
                     *cast(GLsizei*) (pc + 20),
                     *cast(GLsizei*) (pc + 24), *cast(GLint*) (pc + 28));
}

void __glXDisp_CopyTexSubImage1D(GLbyte* pc)
{
    glCopyTexSubImage1D(*cast(GLenum*) (pc + 0),
                        *cast(GLint*) (pc + 4),
                        *cast(GLint*) (pc + 8),
                        *cast(GLint*) (pc + 12),
                        *cast(GLint*) (pc + 16), *cast(GLsizei*) (pc + 20));
}

void __glXDisp_CopyTexSubImage2D(GLbyte* pc)
{
    glCopyTexSubImage2D(*cast(GLenum*) (pc + 0),
                        *cast(GLint*) (pc + 4),
                        *cast(GLint*) (pc + 8),
                        *cast(GLint*) (pc + 12),
                        *cast(GLint*) (pc + 16),
                        *cast(GLint*) (pc + 20),
                        *cast(GLsizei*) (pc + 24), *cast(GLsizei*) (pc + 28));
}

int __glXDisp_DeleteTextures(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        glDeleteTextures(n, cast(const(GLuint)*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_DeleteTexturesEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        glDeleteTextures(n, cast(const(GLuint)*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_GenTextures(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* textures = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (textures is null)
            return BadAlloc;
        glGenTextures(n, textures);
        __glXSendReply(cl.client, textures, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GenTexturesEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* textures = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (textures is null)
            return BadAlloc;
        glGenTextures(n, textures);
        __glXSendReply(cl.client, textures, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_IsTexture(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsTexture(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDisp_IsTextureEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = glIsTexture(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_PrioritizeTextures(GLbyte* pc)
{
    const(GLsizei) n = *cast(GLsizei*) (pc + 0);

    glPrioritizeTextures(n,
                         cast(const(GLuint)*) (pc + 4),
                         cast(const(GLclampf)*) (pc + 4));
}

void __glXDisp_TexSubImage1D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 56)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexSubImage1D(*cast(GLenum*) (pc + 20),
                    *cast(GLint*) (pc + 24),
                    *cast(GLint*) (pc + 28),
                    *cast(GLsizei*) (pc + 36),
                    *cast(GLenum*) (pc + 44), *cast(GLenum*) (pc + 48), pixels);
}

void __glXDisp_TexSubImage2D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 56)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexSubImage2D(*cast(GLenum*) (pc + 20),
                    *cast(GLint*) (pc + 24),
                    *cast(GLint*) (pc + 28),
                    *cast(GLint*) (pc + 32),
                    *cast(GLsizei*) (pc + 36),
                    *cast(GLsizei*) (pc + 40),
                    *cast(GLenum*) (pc + 44), *cast(GLenum*) (pc + 48), pixels);
}

void __glXDisp_BlendColor(GLbyte* pc)
{
    glBlendColor(*cast(GLclampf*) (pc + 0),
                 *cast(GLclampf*) (pc + 4),
                 *cast(GLclampf*) (pc + 8), *cast(GLclampf*) (pc + 12));
}

void __glXDisp_BlendEquation(GLbyte* pc)
{
    glBlendEquation(*cast(GLenum*) (pc + 0));
}

void __glXDisp_ColorTable(GLbyte* pc)
{
    const(GLvoid*) table = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 40)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glColorTable(*cast(GLenum*) (pc + 20),
                 *cast(GLenum*) (pc + 24),
                 *cast(GLsizei*) (pc + 28),
                 *cast(GLenum*) (pc + 32), *cast(GLenum*) (pc + 36), table);
}

void __glXDisp_ColorTableParameterfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glColorTableParameterfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_ColorTableParameteriv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glColorTableParameteriv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_CopyColorTable(GLbyte* pc)
{
    glCopyColorTable(*cast(GLenum*) (pc + 0),
                     *cast(GLenum*) (pc + 4),
                     *cast(GLint*) (pc + 8),
                     *cast(GLint*) (pc + 12), *cast(GLsizei*) (pc + 16));
}

int __glXDisp_GetColorTableParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetColorTableParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetColorTableParameterfvSGI(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetColorTableParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetColorTableParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetColorTableParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetColorTableParameterivSGI(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetColorTableParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetColorTableParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

void __glXDisp_ColorSubTable(GLbyte* pc)
{
    const(GLvoid*) data = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 40)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glColorSubTable(*cast(GLenum*) (pc + 20),
                    *cast(GLsizei*) (pc + 24),
                    *cast(GLsizei*) (pc + 28),
                    *cast(GLenum*) (pc + 32), *cast(GLenum*) (pc + 36), data);
}

void __glXDisp_CopyColorSubTable(GLbyte* pc)
{
    glCopyColorSubTable(*cast(GLenum*) (pc + 0),
                        *cast(GLsizei*) (pc + 4),
                        *cast(GLint*) (pc + 8),
                        *cast(GLint*) (pc + 12), *cast(GLsizei*) (pc + 16));
}

void __glXDisp_ConvolutionFilter1D(GLbyte* pc)
{
    const(GLvoid*) image = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glConvolutionFilter1D(*cast(GLenum*) (pc + 20),
                          *cast(GLenum*) (pc + 24),
                          *cast(GLsizei*) (pc + 28),
                          *cast(GLenum*) (pc + 36), *cast(GLenum*) (pc + 40), image);
}

void __glXDisp_ConvolutionFilter2D(GLbyte* pc)
{
    const(GLvoid*) image = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 44)));
    __GLXpixelHeader* hdr = cast(__GLXpixelHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glConvolutionFilter2D(*cast(GLenum*) (pc + 20),
                          *cast(GLenum*) (pc + 24),
                          *cast(GLsizei*) (pc + 28),
                          *cast(GLsizei*) (pc + 32),
                          *cast(GLenum*) (pc + 36), *cast(GLenum*) (pc + 40), image);
}

void __glXDisp_ConvolutionParameterf(GLbyte* pc)
{
    glConvolutionParameterf(*cast(GLenum*) (pc + 0),
                            *cast(GLenum*) (pc + 4), *cast(GLfloat*) (pc + 8));
}

void __glXDisp_ConvolutionParameterfv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 8);

    glConvolutionParameterfv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_ConvolutionParameteri(GLbyte* pc)
{
    glConvolutionParameteri(*cast(GLenum*) (pc + 0),
                            *cast(GLenum*) (pc + 4), *cast(GLint*) (pc + 8));
}

void __glXDisp_ConvolutionParameteriv(GLbyte* pc)
{
    const(GLenum) pname = *cast(GLenum*) (pc + 4);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 8);

    glConvolutionParameteriv(*cast(GLenum*) (pc + 0), pname, params);
}

void __glXDisp_CopyConvolutionFilter1D(GLbyte* pc)
{
    glCopyConvolutionFilter1D(*cast(GLenum*) (pc + 0),
                              *cast(GLenum*) (pc + 4),
                              *cast(GLint*) (pc + 8),
                              *cast(GLint*) (pc + 12), *cast(GLsizei*) (pc + 16));
}

void __glXDisp_CopyConvolutionFilter2D(GLbyte* pc)
{
    glCopyConvolutionFilter2D(*cast(GLenum*) (pc + 0),
                              *cast(GLenum*) (pc + 4),
                              *cast(GLint*) (pc + 8),
                              *cast(GLint*) (pc + 12),
                              *cast(GLsizei*) (pc + 16), *cast(GLsizei*) (pc + 20));
}

int __glXDisp_GetConvolutionParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetConvolutionParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetConvolutionParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetConvolutionParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetConvolutionParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetConvolutionParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetHistogramParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetHistogramParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetHistogramParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetHistogramParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetHistogramParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetHistogramParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetHistogramParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetHistogramParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetHistogramParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMinmaxParameterfv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMinmaxParameterfvEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameterfv_size(pname);
        GLfloat[200] answerBuffer = void;
        GLfloat* params = cast(float*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameterfv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMinmaxParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetMinmaxParameterivEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetMinmaxParameteriv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        glGetMinmaxParameteriv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

void __glXDisp_Histogram(GLbyte* pc)
{
    glHistogram(*cast(GLenum*) (pc + 0),
                *cast(GLsizei*) (pc + 4),
                *cast(GLenum*) (pc + 8), *cast(GLboolean*) (pc + 12));
}

void __glXDisp_Minmax(GLbyte* pc)
{
    glMinmax(*cast(GLenum*) (pc + 0),
             *cast(GLenum*) (pc + 4), *cast(GLboolean*) (pc + 8));
}

void __glXDisp_ResetHistogram(GLbyte* pc)
{
    glResetHistogram(*cast(GLenum*) (pc + 0));
}

void __glXDisp_ResetMinmax(GLbyte* pc)
{
    glResetMinmax(*cast(GLenum*) (pc + 0));
}

void __glXDisp_TexImage3D(GLbyte* pc)
{
    const(CARD32) ptr_is_null = *cast(CARD32*) (pc + 76);
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((ptr_is_null != 0) ? null : (pc + 80)));
    __GLXpixel3DHeader* hdr = cast(__GLXpixel3DHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, cast(GLint) hdr.imageHeight);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_IMAGES, cast(GLint) hdr.skipImages);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexImage3D(*cast(GLenum*) (pc + 36),
                 *cast(GLint*) (pc + 40),
                 *cast(GLint*) (pc + 44),
                 *cast(GLsizei*) (pc + 48),
                 *cast(GLsizei*) (pc + 52),
                 *cast(GLsizei*) (pc + 56),
                 *cast(GLint*) (pc + 64),
                 *cast(GLenum*) (pc + 68), *cast(GLenum*) (pc + 72), pixels);
}

void __glXDisp_TexSubImage3D(GLbyte* pc)
{
    const(GLvoid*) pixels = cast(const(GLvoid*)) (cast(const(GLvoid)*) ((pc + 88)));
    __GLXpixel3DHeader* hdr = cast(__GLXpixel3DHeader*) (pc);

    glPixelStorei(GL_UNPACK_SWAP_BYTES, hdr.swapBytes);
    glPixelStorei(GL_UNPACK_LSB_FIRST, hdr.lsbFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, cast(GLint) hdr.rowLength);
    glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, cast(GLint) hdr.imageHeight);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, cast(GLint) hdr.skipRows);
    glPixelStorei(GL_UNPACK_SKIP_IMAGES, cast(GLint) hdr.skipImages);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, cast(GLint) hdr.skipPixels);
    glPixelStorei(GL_UNPACK_ALIGNMENT, cast(GLint) hdr.alignment);

    glTexSubImage3D(*cast(GLenum*) (pc + 36),
                    *cast(GLint*) (pc + 40),
                    *cast(GLint*) (pc + 44),
                    *cast(GLint*) (pc + 48),
                    *cast(GLint*) (pc + 52),
                    *cast(GLsizei*) (pc + 60),
                    *cast(GLsizei*) (pc + 64),
                    *cast(GLsizei*) (pc + 68),
                    *cast(GLenum*) (pc + 76), *cast(GLenum*) (pc + 80), pixels);
}

void __glXDisp_CopyTexSubImage3D(GLbyte* pc)
{
    glCopyTexSubImage3D(*cast(GLenum*) (pc + 0),
                        *cast(GLint*) (pc + 4),
                        *cast(GLint*) (pc + 8),
                        *cast(GLint*) (pc + 12),
                        *cast(GLint*) (pc + 16),
                        *cast(GLint*) (pc + 20),
                        *cast(GLint*) (pc + 24),
                        *cast(GLsizei*) (pc + 28), *cast(GLsizei*) (pc + 32));
}

void __glXDisp_ActiveTexture(GLbyte* pc)
{
    glActiveTextureARB(*cast(GLenum*) (pc + 0));
}

void __glXDisp_MultiTexCoord1dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    glMultiTexCoord1dvARB(*cast(GLenum*) (pc + 8), cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_MultiTexCoord1fvARB(GLbyte* pc)
{
    glMultiTexCoord1fvARB(*cast(GLenum*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_MultiTexCoord1iv(GLbyte* pc)
{
    glMultiTexCoord1ivARB(*cast(GLenum*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_MultiTexCoord1sv(GLbyte* pc)
{
    glMultiTexCoord1svARB(*cast(GLenum*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_MultiTexCoord2dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    glMultiTexCoord2dvARB(*cast(GLenum*) (pc + 16), cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_MultiTexCoord2fvARB(GLbyte* pc)
{
    glMultiTexCoord2fvARB(*cast(GLenum*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_MultiTexCoord2iv(GLbyte* pc)
{
    glMultiTexCoord2ivARB(*cast(GLenum*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_MultiTexCoord2sv(GLbyte* pc)
{
    glMultiTexCoord2svARB(*cast(GLenum*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_MultiTexCoord3dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    glMultiTexCoord3dvARB(*cast(GLenum*) (pc + 24), cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_MultiTexCoord3fvARB(GLbyte* pc)
{
    glMultiTexCoord3fvARB(*cast(GLenum*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_MultiTexCoord3iv(GLbyte* pc)
{
    glMultiTexCoord3ivARB(*cast(GLenum*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_MultiTexCoord3sv(GLbyte* pc)
{
    glMultiTexCoord3svARB(*cast(GLenum*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_MultiTexCoord4dv(GLbyte* pc)
{
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    glMultiTexCoord4dvARB(*cast(GLenum*) (pc + 32), cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_MultiTexCoord4fvARB(GLbyte* pc)
{
    glMultiTexCoord4fvARB(*cast(GLenum*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_MultiTexCoord4iv(GLbyte* pc)
{
    glMultiTexCoord4ivARB(*cast(GLenum*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_MultiTexCoord4sv(GLbyte* pc)
{
    glMultiTexCoord4svARB(*cast(GLenum*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_CompressedTexImage1D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE1DPROC CompressedTexImage1D = cast(PFNGLCOMPRESSEDTEXIMAGE1DPROC)__glGetProcAddress("glCompressedTexImage1D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 20);

    CompressedTexImage1D(*cast(GLenum*) (pc + 0),
                         *cast(GLint*) (pc + 4),
                         *cast(GLenum*) (pc + 8),
                         *cast(GLsizei*) (pc + 12),
                         *cast(GLint*) (pc + 16),
                         imageSize, cast(const(GLvoid)*) (pc + 24));
}

void __glXDisp_CompressedTexImage2D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE2DPROC CompressedTexImage2D = cast(PFNGLCOMPRESSEDTEXIMAGE2DPROC)__glGetProcAddress("glCompressedTexImage2D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 24);

    CompressedTexImage2D(*cast(GLenum*) (pc + 0),
                         *cast(GLint*) (pc + 4),
                         *cast(GLenum*) (pc + 8),
                         *cast(GLsizei*) (pc + 12),
                         *cast(GLsizei*) (pc + 16),
                         *cast(GLint*) (pc + 20),
                         imageSize, cast(const(GLvoid)*) (pc + 28));
}

void __glXDisp_CompressedTexImage3D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXIMAGE3DPROC CompressedTexImage3D = cast(PFNGLCOMPRESSEDTEXIMAGE3DPROC)__glGetProcAddress("glCompressedTexImage3D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 28);

    CompressedTexImage3D(*cast(GLenum*) (pc + 0),
                         *cast(GLint*) (pc + 4),
                         *cast(GLenum*) (pc + 8),
                         *cast(GLsizei*) (pc + 12),
                         *cast(GLsizei*) (pc + 16),
                         *cast(GLsizei*) (pc + 20),
                         *cast(GLint*) (pc + 24),
                         imageSize, cast(const(GLvoid)*) (pc + 32));
}

void __glXDisp_CompressedTexSubImage1D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE1DPROC CompressedTexSubImage1D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE1DPROC)__glGetProcAddress("glCompressedTexSubImage1D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 20);

    CompressedTexSubImage1D(*cast(GLenum*) (pc + 0),
                            *cast(GLint*) (pc + 4),
                            *cast(GLint*) (pc + 8),
                            *cast(GLsizei*) (pc + 12),
                            *cast(GLenum*) (pc + 16),
                            imageSize, cast(const(GLvoid)*) (pc + 24));
}

void __glXDisp_CompressedTexSubImage2D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE2DPROC CompressedTexSubImage2D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE2DPROC)__glGetProcAddress("glCompressedTexSubImage2D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 28);

    CompressedTexSubImage2D(*cast(GLenum*) (pc + 0),
                            *cast(GLint*) (pc + 4),
                            *cast(GLint*) (pc + 8),
                            *cast(GLint*) (pc + 12),
                            *cast(GLsizei*) (pc + 16),
                            *cast(GLsizei*) (pc + 20),
                            *cast(GLenum*) (pc + 24),
                            imageSize, cast(const(GLvoid)*) (pc + 32));
}

void __glXDisp_CompressedTexSubImage3D(GLbyte* pc)
{
    PFNGLCOMPRESSEDTEXSUBIMAGE3DPROC CompressedTexSubImage3D = cast(PFNGLCOMPRESSEDTEXSUBIMAGE3DPROC)__glGetProcAddress("glCompressedTexSubImage3D");
    const(GLsizei) imageSize = *cast(GLsizei*) (pc + 36);

    CompressedTexSubImage3D(*cast(GLenum*) (pc + 0),
                            *cast(GLint*) (pc + 4),
                            *cast(GLint*) (pc + 8),
                            *cast(GLint*) (pc + 12),
                            *cast(GLint*) (pc + 16),
                            *cast(GLsizei*) (pc + 20),
                            *cast(GLsizei*) (pc + 24),
                            *cast(GLsizei*) (pc + 28),
                            *cast(GLenum*) (pc + 32),
                            imageSize, cast(const(GLvoid)*) (pc + 40));
}

void __glXDisp_SampleCoverage(GLbyte* pc)
{
    PFNGLSAMPLECOVERAGEPROC SampleCoverage = cast(PFNGLSAMPLECOVERAGEPROC)__glGetProcAddress("glSampleCoverage");
    SampleCoverage(*cast(GLclampf*) (pc + 0), *cast(GLboolean*) (pc + 4));
}

void __glXDisp_BlendFuncSeparate(GLbyte* pc)
{
    PFNGLBLENDFUNCSEPARATEPROC BlendFuncSeparate = cast(PFNGLBLENDFUNCSEPARATEPROC)__glGetProcAddress("glBlendFuncSeparate");
    BlendFuncSeparate(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                      *cast(GLenum*) (pc + 8), *cast(GLenum*) (pc + 12));
}

void __glXDisp_FogCoorddv(GLbyte* pc)
{
    PFNGLFOGCOORDDVPROC FogCoorddv = cast(PFNGLFOGCOORDDVPROC)__glGetProcAddress("glFogCoorddv");

version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 8);
        pc -= 4;
    }
}

    FogCoorddv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_PointParameterf(GLbyte* pc)
{
    PFNGLPOINTPARAMETERFPROC PointParameterf = cast(PFNGLPOINTPARAMETERFPROC)__glGetProcAddress("glPointParameterf");
    PointParameterf(*cast(GLenum*) (pc + 0), *cast(GLfloat*) (pc + 4));
}

void __glXDisp_PointParameterfv(GLbyte* pc)
{
    PFNGLPOINTPARAMETERFVPROC PointParameterfv = cast(PFNGLPOINTPARAMETERFVPROC)__glGetProcAddress("glPointParameterfv");
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLfloat)* params = void;

    params = cast(const(GLfloat)*) (pc + 4);

    PointParameterfv(pname, params);
}

void __glXDisp_PointParameteri(GLbyte* pc)
{
    PFNGLPOINTPARAMETERIPROC PointParameteri = cast(PFNGLPOINTPARAMETERIPROC)__glGetProcAddress("glPointParameteri");
    PointParameteri(*cast(GLenum*) (pc + 0), *cast(GLint*) (pc + 4));
}

void __glXDisp_PointParameteriv(GLbyte* pc)
{
    PFNGLPOINTPARAMETERIVPROC PointParameteriv = cast(PFNGLPOINTPARAMETERIVPROC)__glGetProcAddress("glPointParameteriv");
    const(GLenum) pname = *cast(GLenum*) (pc + 0);
    const(GLint)* params = void;

    params = cast(const(GLint)*) (pc + 4);

    PointParameteriv(pname, params);
}

void __glXDisp_SecondaryColor3bv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3BVPROC SecondaryColor3bv = cast(PFNGLSECONDARYCOLOR3BVPROC)__glGetProcAddress("glSecondaryColor3bv");
    SecondaryColor3bv(cast(const(GLbyte)*) (pc + 0));
}

void __glXDisp_SecondaryColor3dv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3DVPROC SecondaryColor3dv = cast(PFNGLSECONDARYCOLOR3DVPROC)__glGetProcAddress("glSecondaryColor3dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 24);
        pc -= 4;
    }
}

    SecondaryColor3dv(cast(const(GLdouble)*) (pc + 0));
}

void __glXDisp_SecondaryColor3iv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3IVPROC SecondaryColor3iv = cast(PFNGLSECONDARYCOLOR3IVPROC)__glGetProcAddress("glSecondaryColor3iv");
    SecondaryColor3iv(cast(const(GLint)*) (pc + 0));
}

void __glXDisp_SecondaryColor3sv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3SVPROC SecondaryColor3sv = cast(PFNGLSECONDARYCOLOR3SVPROC)__glGetProcAddress("glSecondaryColor3sv");
    SecondaryColor3sv(cast(const(GLshort)*) (pc + 0));
}

void __glXDisp_SecondaryColor3ubv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3UBVPROC SecondaryColor3ubv = cast(PFNGLSECONDARYCOLOR3UBVPROC)__glGetProcAddress("glSecondaryColor3ubv");
    SecondaryColor3ubv(cast(const(GLubyte)*) (pc + 0));
}

void __glXDisp_SecondaryColor3uiv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3UIVPROC SecondaryColor3uiv = cast(PFNGLSECONDARYCOLOR3UIVPROC)__glGetProcAddress("glSecondaryColor3uiv");
    SecondaryColor3uiv(cast(const(GLuint)*) (pc + 0));
}

void __glXDisp_SecondaryColor3usv(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3USVPROC SecondaryColor3usv = cast(PFNGLSECONDARYCOLOR3USVPROC)__glGetProcAddress("glSecondaryColor3usv");
    SecondaryColor3usv(cast(const(GLushort)*) (pc + 0));
}

void __glXDisp_WindowPos3fv(GLbyte* pc)
{
    PFNGLWINDOWPOS3FVPROC WindowPos3fv = cast(PFNGLWINDOWPOS3FVPROC)__glGetProcAddress("glWindowPos3fv");

    WindowPos3fv(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_BeginQuery(GLbyte* pc)
{
    PFNGLBEGINQUERYPROC BeginQuery = cast(PFNGLBEGINQUERYPROC)__glGetProcAddress("glBeginQuery");

    BeginQuery(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4));
}

int __glXDisp_DeleteQueries(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLDELETEQUERIESPROC DeleteQueries = cast(PFNGLDELETEQUERIESPROC)__glGetProcAddress("glDeleteQueries");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        DeleteQueries(n, cast(const(GLuint)*) (pc + 4));
        error = Success;
    }

    return error;
}

void __glXDisp_EndQuery(GLbyte* pc)
{
    PFNGLENDQUERYPROC EndQuery = cast(PFNGLENDQUERYPROC)__glGetProcAddress("glEndQuery");

    EndQuery(*cast(GLenum*) (pc + 0));
}

int __glXDisp_GenQueries(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENQUERIESPROC GenQueries = cast(PFNGLGENQUERIESPROC)__glGetProcAddress("glGenQueries");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* ids = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (ids is null)
            return BadAlloc;
        GenQueries(n, ids);
        __glXSendReply(cl.client, ids, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetQueryObjectiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYOBJECTIVPROC GetQueryObjectiv = cast(PFNGLGETQUERYOBJECTIVPROC)__glGetProcAddress("glGetQueryObjectiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetQueryObjectiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryObjectiv(*cast(GLuint*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetQueryObjectuiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYOBJECTUIVPROC GetQueryObjectuiv = cast(PFNGLGETQUERYOBJECTUIVPROC)__glGetProcAddress("glGetQueryObjectuiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetQueryObjectuiv_size(pname);
        GLuint[200] answerBuffer = void;
        GLuint* params = cast(uint*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryObjectuiv(*cast(GLuint*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetQueryiv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETQUERYIVPROC GetQueryiv = cast(PFNGLGETQUERYIVPROC)__glGetProcAddress("glGetQueryiv");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetQueryiv_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetQueryiv(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_IsQuery(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISQUERYPROC IsQuery = cast(PFNGLISQUERYPROC)__glGetProcAddress("glIsQuery");
    xGLXSingleReq* req = cast(xGLXSingleReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_SINGLE_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsQuery(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_BlendEquationSeparate(GLbyte* pc)
{
    PFNGLBLENDEQUATIONSEPARATEPROC BlendEquationSeparate = cast(PFNGLBLENDEQUATIONSEPARATEPROC)__glGetProcAddress("glBlendEquationSeparate");
    BlendEquationSeparate(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_DrawBuffers(GLbyte* pc)
{
    PFNGLDRAWBUFFERSPROC DrawBuffers = cast(PFNGLDRAWBUFFERSPROC)__glGetProcAddress("glDrawBuffers");
    const(GLsizei) n = *cast(GLsizei*) (pc + 0);

    DrawBuffers(n, cast(const(GLenum)*) (pc + 4));
}

void __glXDisp_VertexAttrib1dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1DVPROC VertexAttrib1dv = cast(PFNGLVERTEXATTRIB1DVPROC)__glGetProcAddress("glVertexAttrib1dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    VertexAttrib1dv(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib1sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1SVPROC VertexAttrib1sv = cast(PFNGLVERTEXATTRIB1SVPROC)__glGetProcAddress("glVertexAttrib1sv");
    VertexAttrib1sv(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib2dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2DVPROC VertexAttrib2dv = cast(PFNGLVERTEXATTRIB2DVPROC)__glGetProcAddress("glVertexAttrib2dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    VertexAttrib2dv(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib2sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2SVPROC VertexAttrib2sv = cast(PFNGLVERTEXATTRIB2SVPROC)__glGetProcAddress("glVertexAttrib2sv");
    VertexAttrib2sv(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib3dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3DVPROC VertexAttrib3dv = cast(PFNGLVERTEXATTRIB3DVPROC)__glGetProcAddress("glVertexAttrib3dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    VertexAttrib3dv(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib3sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3SVPROC VertexAttrib3sv = cast(PFNGLVERTEXATTRIB3SVPROC)__glGetProcAddress("glVertexAttrib3sv");
    VertexAttrib3sv(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Nbv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NBVPROC VertexAttrib4Nbv = cast(PFNGLVERTEXATTRIB4NBVPROC)__glGetProcAddress("glVertexAttrib4Nbv");
    VertexAttrib4Nbv(*cast(GLuint*) (pc + 0), cast(const(GLbyte)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Niv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NIVPROC VertexAttrib4Niv = cast(PFNGLVERTEXATTRIB4NIVPROC)__glGetProcAddress("glVertexAttrib4Niv");
    VertexAttrib4Niv(*cast(GLuint*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Nsv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NSVPROC VertexAttrib4Nsv = cast(PFNGLVERTEXATTRIB4NSVPROC)__glGetProcAddress("glVertexAttrib4Nsv");
    VertexAttrib4Nsv(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Nubv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUBVPROC VertexAttrib4Nubv = cast(PFNGLVERTEXATTRIB4NUBVPROC)__glGetProcAddress("glVertexAttrib4Nubv");
    VertexAttrib4Nubv(*cast(GLuint*) (pc + 0), cast(const(GLubyte)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Nuiv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUIVPROC VertexAttrib4Nuiv = cast(PFNGLVERTEXATTRIB4NUIVPROC)__glGetProcAddress("glVertexAttrib4Nuiv");
    VertexAttrib4Nuiv(*cast(GLuint*) (pc + 0), cast(const(GLuint)*) (pc + 4));
}

void __glXDisp_VertexAttrib4Nusv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4NUSVPROC VertexAttrib4Nusv = cast(PFNGLVERTEXATTRIB4NUSVPROC)__glGetProcAddress("glVertexAttrib4Nusv");
    VertexAttrib4Nusv(*cast(GLuint*) (pc + 0), cast(const(GLushort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4bv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4BVPROC VertexAttrib4bv = cast(PFNGLVERTEXATTRIB4BVPROC)__glGetProcAddress("glVertexAttrib4bv");
    VertexAttrib4bv(*cast(GLuint*) (pc + 0), cast(const(GLbyte)*) (pc + 4));
}

void __glXDisp_VertexAttrib4dv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4DVPROC VertexAttrib4dv = cast(PFNGLVERTEXATTRIB4DVPROC)__glGetProcAddress("glVertexAttrib4dv");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    VertexAttrib4dv(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib4iv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4IVPROC VertexAttrib4iv = cast(PFNGLVERTEXATTRIB4IVPROC)__glGetProcAddress("glVertexAttrib4iv");
    VertexAttrib4iv(*cast(GLuint*) (pc + 0), cast(const(GLint)*) (pc + 4));
}

void __glXDisp_VertexAttrib4sv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4SVPROC VertexAttrib4sv = cast(PFNGLVERTEXATTRIB4SVPROC)__glGetProcAddress("glVertexAttrib4sv");
    VertexAttrib4sv(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4ubv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UBVPROC VertexAttrib4ubv = cast(PFNGLVERTEXATTRIB4UBVPROC)__glGetProcAddress("glVertexAttrib4ubv");
    VertexAttrib4ubv(*cast(GLuint*) (pc + 0), cast(const(GLubyte)*) (pc + 4));
}

void __glXDisp_VertexAttrib4uiv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UIVPROC VertexAttrib4uiv = cast(PFNGLVERTEXATTRIB4UIVPROC)__glGetProcAddress("glVertexAttrib4uiv");
    VertexAttrib4uiv(*cast(GLuint*) (pc + 0), cast(const(GLuint)*) (pc + 4));
}

void __glXDisp_VertexAttrib4usv(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4USVPROC VertexAttrib4usv = cast(PFNGLVERTEXATTRIB4USVPROC)__glGetProcAddress("glVertexAttrib4usv");
    VertexAttrib4usv(*cast(GLuint*) (pc + 0), cast(const(GLushort)*) (pc + 4));
}

void __glXDisp_ClampColor(GLbyte* pc)
{
    PFNGLCLAMPCOLORPROC ClampColor = cast(PFNGLCLAMPCOLORPROC)__glGetProcAddress("glClampColor");

    ClampColor(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4));
}

void __glXDisp_BindProgramARB(GLbyte* pc)
{
    PFNGLBINDPROGRAMARBPROC BindProgramARB = cast(PFNGLBINDPROGRAMARBPROC)__glGetProcAddress("glBindProgramARB");
    BindProgramARB(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4));
}

int __glXDisp_DeleteProgramsARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLDELETEPROGRAMSARBPROC DeleteProgramsARB = cast(PFNGLDELETEPROGRAMSARBPROC)__glGetProcAddress("glDeleteProgramsARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        DeleteProgramsARB(n, cast(const(GLuint)*) (pc + 4));
        error = Success;
    }

    return error;
}

int __glXDisp_GenProgramsARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENPROGRAMSARBPROC GenProgramsARB = cast(PFNGLGENPROGRAMSARBPROC)__glGetProcAddress("glGenProgramsARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* programs = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (programs is null)
            return BadAlloc;
        GenProgramsARB(n, programs);
        __glXSendReply(cl.client, programs, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetProgramEnvParameterdvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMENVPARAMETERDVARBPROC GetProgramEnvParameterdvARB = cast(PFNGLGETPROGRAMENVPARAMETERDVARBPROC)__glGetProcAddress("glGetProgramEnvParameterdvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] params = void;

        GetProgramEnvParameterdvARB(*cast(GLenum*) (pc + 0),
                                    *cast(GLuint*) (pc + 4), params.ptr);
        __glXSendReply(cl.client, params.ptr, 4, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetProgramEnvParameterfvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMENVPARAMETERFVARBPROC GetProgramEnvParameterfvARB = cast(PFNGLGETPROGRAMENVPARAMETERFVARBPROC)__glGetProcAddress("glGetProgramEnvParameterfvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLfloat[4] params = void;

        GetProgramEnvParameterfvARB(*cast(GLenum*) (pc + 0),
                                    *cast(GLuint*) (pc + 4), params.ptr);
        __glXSendReply(cl.client, params.ptr, 4, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetProgramLocalParameterdvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMLOCALPARAMETERDVARBPROC GetProgramLocalParameterdvARB = cast(PFNGLGETPROGRAMLOCALPARAMETERDVARBPROC)__glGetProcAddress("glGetProgramLocalParameterdvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLdouble[4] params = void;

        GetProgramLocalParameterdvARB(*cast(GLenum*) (pc + 0),
                                      *cast(GLuint*) (pc + 4), params.ptr);
        __glXSendReply(cl.client, params.ptr, 4, 8, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetProgramLocalParameterfvARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMLOCALPARAMETERFVARBPROC GetProgramLocalParameterfvARB = cast(PFNGLGETPROGRAMLOCALPARAMETERFVARBPROC)__glGetProcAddress("glGetProgramLocalParameterfvARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLfloat[4] params = void;

        GetProgramLocalParameterfvARB(*cast(GLenum*) (pc + 0),
                                      *cast(GLuint*) (pc + 4), params.ptr);
        __glXSendReply(cl.client, params.ptr, 4, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetProgramivARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETPROGRAMIVARBPROC GetProgramivARB = cast(PFNGLGETPROGRAMIVARBPROC)__glGetProcAddress("glGetProgramivARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLenum) pname = *cast(GLenum*) (pc + 4);

        const(GLuint) compsize = __glGetProgramivARB_size(pname);
        GLint[200] answerBuffer = void;
        GLint* params = cast(int*)__glXGetAnswerBuffer(cl, compsize * 4, answerBuffer.ptr,
                                 answerBuffer.sizeof, 4);

        if (params is null)
            return BadAlloc;
        __glXClearErrorOccured();

        GetProgramivARB(*cast(GLenum*) (pc + 0), pname, params);
        __glXSendReply(cl.client, params, compsize, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_IsProgramARB(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISPROGRAMARBPROC IsProgramARB = cast(PFNGLISPROGRAMARBPROC)__glGetProcAddress("glIsProgramARB");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsProgramARB(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_ProgramEnvParameter4dvARB(GLbyte* pc)
{
    PFNGLPROGRAMENVPARAMETER4DVARBPROC ProgramEnvParameter4dvARB = cast(PFNGLPROGRAMENVPARAMETER4DVARBPROC)__glGetProcAddress("glProgramEnvParameter4dvARB");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    ProgramEnvParameter4dvARB(*cast(GLenum*) (pc + 0),
                              *cast(GLuint*) (pc + 4),
                              cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_ProgramEnvParameter4fvARB(GLbyte* pc)
{
    PFNGLPROGRAMENVPARAMETER4FVARBPROC ProgramEnvParameter4fvARB = cast(PFNGLPROGRAMENVPARAMETER4FVARBPROC)__glGetProcAddress("glProgramEnvParameter4fvARB");
    ProgramEnvParameter4fvARB(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4),
                              cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_ProgramLocalParameter4dvARB(GLbyte* pc)
{
    PFNGLPROGRAMLOCALPARAMETER4DVARBPROC ProgramLocalParameter4dvARB = cast(PFNGLPROGRAMLOCALPARAMETER4DVARBPROC)__glGetProcAddress("glProgramLocalParameter4dvARB");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 40);
        pc -= 4;
    }
}

    ProgramLocalParameter4dvARB(*cast(GLenum*) (pc + 0),
                                *cast(GLuint*) (pc + 4),
                                cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_ProgramLocalParameter4fvARB(GLbyte* pc)
{
    PFNGLPROGRAMLOCALPARAMETER4FVARBPROC ProgramLocalParameter4fvARB = cast(PFNGLPROGRAMLOCALPARAMETER4FVARBPROC)__glGetProcAddress("glProgramLocalParameter4fvARB");
    ProgramLocalParameter4fvARB(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4),
                                cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_ProgramStringARB(GLbyte* pc)
{
    PFNGLPROGRAMSTRINGARBPROC ProgramStringARB = cast(PFNGLPROGRAMSTRINGARBPROC)__glGetProcAddress("glProgramStringARB");
    const(GLsizei) len = *cast(GLsizei*) (pc + 8);

    ProgramStringARB(*cast(GLenum*) (pc + 0),
                     *cast(GLenum*) (pc + 4), len, cast(const(GLvoid)*) (pc + 12));
}

void __glXDisp_VertexAttrib1fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1FVARBPROC VertexAttrib1fvARB = cast(PFNGLVERTEXATTRIB1FVARBPROC)__glGetProcAddress("glVertexAttrib1fvARB");
    VertexAttrib1fvARB(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib2fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2FVARBPROC VertexAttrib2fvARB = cast(PFNGLVERTEXATTRIB2FVARBPROC)__glGetProcAddress("glVertexAttrib2fvARB");
    VertexAttrib2fvARB(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib3fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3FVARBPROC VertexAttrib3fvARB = cast(PFNGLVERTEXATTRIB3FVARBPROC)__glGetProcAddress("glVertexAttrib3fvARB");
    VertexAttrib3fvARB(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib4fvARB(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4FVARBPROC VertexAttrib4fvARB = cast(PFNGLVERTEXATTRIB4FVARBPROC)__glGetProcAddress("glVertexAttrib4fvARB");
    VertexAttrib4fvARB(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_BindFramebuffer(GLbyte* pc)
{
    PFNGLBINDFRAMEBUFFERPROC BindFramebuffer = cast(PFNGLBINDFRAMEBUFFERPROC)__glGetProcAddress("glBindFramebuffer");
    BindFramebuffer(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4));
}

void __glXDisp_BindRenderbuffer(GLbyte* pc)
{
    PFNGLBINDRENDERBUFFERPROC BindRenderbuffer = cast(PFNGLBINDRENDERBUFFERPROC)__glGetProcAddress("glBindRenderbuffer");
    BindRenderbuffer(*cast(GLenum*) (pc + 0), *cast(GLuint*) (pc + 4));
}

void __glXDisp_BlitFramebuffer(GLbyte* pc)
{
    PFNGLBLITFRAMEBUFFERPROC BlitFramebuffer = cast(PFNGLBLITFRAMEBUFFERPROC)__glGetProcAddress("glBlitFramebuffer");
    BlitFramebuffer(*cast(GLint*) (pc + 0), *cast(GLint*) (pc + 4),
                    *cast(GLint*) (pc + 8), *cast(GLint*) (pc + 12),
                    *cast(GLint*) (pc + 16), *cast(GLint*) (pc + 20),
                    *cast(GLint*) (pc + 24), *cast(GLint*) (pc + 28),
                    *cast(GLbitfield*) (pc + 32), *cast(GLenum*) (pc + 36));
}

int __glXDisp_CheckFramebufferStatus(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLCHECKFRAMEBUFFERSTATUSPROC CheckFramebufferStatus = cast(PFNGLCHECKFRAMEBUFFERSTATUSPROC)__glGetProcAddress("glCheckFramebufferStatus");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLenum retval = void;

        retval = CheckFramebufferStatus(*cast(GLenum*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_DeleteFramebuffers(GLbyte* pc)
{
    PFNGLDELETEFRAMEBUFFERSPROC DeleteFramebuffers = cast(PFNGLDELETEFRAMEBUFFERSPROC)__glGetProcAddress("glDeleteFramebuffers");
    const(GLsizei) n = *cast(GLsizei*) (pc + 0);

    DeleteFramebuffers(n, cast(const(GLuint)*) (pc + 4));
}

void __glXDisp_DeleteRenderbuffers(GLbyte* pc)
{
    PFNGLDELETERENDERBUFFERSPROC DeleteRenderbuffers = cast(PFNGLDELETERENDERBUFFERSPROC)__glGetProcAddress("glDeleteRenderbuffers");
    const(GLsizei) n = *cast(GLsizei*) (pc + 0);

    DeleteRenderbuffers(n, cast(const(GLuint)*) (pc + 4));
}

void __glXDisp_FramebufferRenderbuffer(GLbyte* pc)
{
    PFNGLFRAMEBUFFERRENDERBUFFERPROC FramebufferRenderbuffer = cast(PFNGLFRAMEBUFFERRENDERBUFFERPROC)__glGetProcAddress("glFramebufferRenderbuffer");
    FramebufferRenderbuffer(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                            *cast(GLenum*) (pc + 8), *cast(GLuint*) (pc + 12));
}

void __glXDisp_FramebufferTexture1D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE1DPROC FramebufferTexture1D = cast(PFNGLFRAMEBUFFERTEXTURE1DPROC)__glGetProcAddress("glFramebufferTexture1D");
    FramebufferTexture1D(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                         *cast(GLenum*) (pc + 8), *cast(GLuint*) (pc + 12),
                         *cast(GLint*) (pc + 16));
}

void __glXDisp_FramebufferTexture2D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE2DPROC FramebufferTexture2D = cast(PFNGLFRAMEBUFFERTEXTURE2DPROC)__glGetProcAddress("glFramebufferTexture2D");
    FramebufferTexture2D(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                         *cast(GLenum*) (pc + 8), *cast(GLuint*) (pc + 12),
                         *cast(GLint*) (pc + 16));
}

void __glXDisp_FramebufferTexture3D(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURE3DPROC FramebufferTexture3D = cast(PFNGLFRAMEBUFFERTEXTURE3DPROC)__glGetProcAddress("glFramebufferTexture3D");
    FramebufferTexture3D(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                         *cast(GLenum*) (pc + 8), *cast(GLuint*) (pc + 12),
                         *cast(GLint*) (pc + 16), *cast(GLint*) (pc + 20));
}

void __glXDisp_FramebufferTextureLayer(GLbyte* pc)
{
    PFNGLFRAMEBUFFERTEXTURELAYERPROC FramebufferTextureLayer = cast(PFNGLFRAMEBUFFERTEXTURELAYERPROC)__glGetProcAddress("glFramebufferTextureLayer");
    FramebufferTextureLayer(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                            *cast(GLuint*) (pc + 8), *cast(GLint*) (pc + 12),
                            *cast(GLint*) (pc + 16));
}

int __glXDisp_GenFramebuffers(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENFRAMEBUFFERSPROC GenFramebuffers = cast(PFNGLGENFRAMEBUFFERSPROC)__glGetProcAddress("glGenFramebuffers");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* framebuffers = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (framebuffers is null)
            return BadAlloc;

        GenFramebuffers(n, framebuffers);
        __glXSendReply(cl.client, framebuffers, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GenRenderbuffers(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGENRENDERBUFFERSPROC GenRenderbuffers = cast(PFNGLGENRENDERBUFFERSPROC)__glGetProcAddress("glGenRenderbuffers");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        const(GLsizei) n = *cast(GLsizei*) (pc + 0);

        GLuint[200] answerBuffer = void;
        GLuint* renderbuffers = cast(uint*)__glXGetAnswerBuffer(cl, n * 4, answerBuffer.ptr, answerBuffer.sizeof,
                                 4);

        if (renderbuffers is null)
            return BadAlloc;
        GenRenderbuffers(n, renderbuffers);
        __glXSendReply(cl.client, renderbuffers, n, 4, GL_TRUE, 0);
        error = Success;
    }

    return error;
}

void __glXDisp_GenerateMipmap(GLbyte* pc)
{
    PFNGLGENERATEMIPMAPPROC GenerateMipmap = cast(PFNGLGENERATEMIPMAPPROC)__glGetProcAddress("glGenerateMipmap");
    GenerateMipmap(*cast(GLenum*) (pc + 0));
}

int __glXDisp_GetFramebufferAttachmentParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC GetFramebufferAttachmentParameteriv = cast(PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC)__glGetProcAddress("glGetFramebufferAttachmentParameteriv");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLint[1] params = void;

        GetFramebufferAttachmentParameteriv(*cast(GLenum*) (pc + 0),
                                            *cast(GLenum*) (pc + 4),
                                            *cast(GLenum*) (pc + 8), params.ptr);
        __glXSendReply(cl.client, params.ptr, 1, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_GetRenderbufferParameteriv(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLGETRENDERBUFFERPARAMETERIVPROC GetRenderbufferParameteriv = cast(PFNGLGETRENDERBUFFERPARAMETERIVPROC)__glGetProcAddress("glGetRenderbufferParameteriv");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLint[1] params = void;

        GetRenderbufferParameteriv(*cast(GLenum*) (pc + 0),
                                   *cast(GLenum*) (pc + 4), params.ptr);
        __glXSendReply(cl.client, params.ptr, 1, 4, GL_FALSE, 0);
        error = Success;
    }

    return error;
}

int __glXDisp_IsFramebuffer(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISFRAMEBUFFERPROC IsFramebuffer = cast(PFNGLISFRAMEBUFFERPROC)__glGetProcAddress("glIsFramebuffer");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsFramebuffer(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

int __glXDisp_IsRenderbuffer(__GLXclientState* cl, GLbyte* pc)
{
    PFNGLISRENDERBUFFERPROC IsRenderbuffer = cast(PFNGLISRENDERBUFFERPROC)__glGetProcAddress("glIsRenderbuffer");
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    int error = void;
    __GLXcontext* cx = __glXForceCurrent(cl, req.contextTag, &error);

    pc += __GLX_VENDPRIV_HDR_SIZE;
    if (cx !is null) {
        GLboolean retval = void;

        retval = IsRenderbuffer(*cast(GLuint*) (pc + 0));
        __glXSendReply(cl.client, dummy_answer.ptr, 0, 0, GL_FALSE, retval);
        error = Success;
    }

    return error;
}

void __glXDisp_RenderbufferStorage(GLbyte* pc)
{
    PFNGLRENDERBUFFERSTORAGEPROC RenderbufferStorage = cast(PFNGLRENDERBUFFERSTORAGEPROC)__glGetProcAddress("glRenderbufferStorage");
    RenderbufferStorage(*cast(GLenum*) (pc + 0), *cast(GLenum*) (pc + 4),
                        *cast(GLsizei*) (pc + 8), *cast(GLsizei*) (pc + 12));
}

void __glXDisp_RenderbufferStorageMultisample(GLbyte* pc)
{
    PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC RenderbufferStorageMultisample = cast(PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC)__glGetProcAddress("glRenderbufferStorageMultisample");
    RenderbufferStorageMultisample(*cast(GLenum*) (pc + 0), *cast(GLsizei*) (pc + 4),
                                   *cast(GLenum*) (pc + 8), *cast(GLsizei*) (pc + 12),
                                   *cast(GLsizei*) (pc + 16));
}

void __glXDisp_SecondaryColor3fvEXT(GLbyte* pc)
{
    PFNGLSECONDARYCOLOR3FVEXTPROC SecondaryColor3fvEXT = cast(PFNGLSECONDARYCOLOR3FVEXTPROC)__glGetProcAddress("glSecondaryColor3fvEXT");
    SecondaryColor3fvEXT(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_FogCoordfvEXT(GLbyte* pc)
{
    PFNGLFOGCOORDFVEXTPROC FogCoordfvEXT = cast(PFNGLFOGCOORDFVEXTPROC)__glGetProcAddress("glFogCoordfvEXT");
    FogCoordfvEXT(cast(const(GLfloat)*) (pc + 0));
}

void __glXDisp_VertexAttrib1dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1DVNVPROC VertexAttrib1dvNV = cast(PFNGLVERTEXATTRIB1DVNVPROC)__glGetProcAddress("glVertexAttrib1dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 12);
        pc -= 4;
    }
}

    VertexAttrib1dvNV(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib1fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1FVNVPROC VertexAttrib1fvNV = cast(PFNGLVERTEXATTRIB1FVNVPROC)__glGetProcAddress("glVertexAttrib1fvNV");
    VertexAttrib1fvNV(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib1svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB1SVNVPROC VertexAttrib1svNV = cast(PFNGLVERTEXATTRIB1SVNVPROC)__glGetProcAddress("glVertexAttrib1svNV");
    VertexAttrib1svNV(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib2dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2DVNVPROC VertexAttrib2dvNV = cast(PFNGLVERTEXATTRIB2DVNVPROC)__glGetProcAddress("glVertexAttrib2dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 20);
        pc -= 4;
    }
}

    VertexAttrib2dvNV(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib2fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2FVNVPROC VertexAttrib2fvNV = cast(PFNGLVERTEXATTRIB2FVNVPROC)__glGetProcAddress("glVertexAttrib2fvNV");
    VertexAttrib2fvNV(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib2svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB2SVNVPROC VertexAttrib2svNV = cast(PFNGLVERTEXATTRIB2SVNVPROC)__glGetProcAddress("glVertexAttrib2svNV");
    VertexAttrib2svNV(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib3dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3DVNVPROC VertexAttrib3dvNV = cast(PFNGLVERTEXATTRIB3DVNVPROC)__glGetProcAddress("glVertexAttrib3dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 28);
        pc -= 4;
    }
}

    VertexAttrib3dvNV(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib3fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3FVNVPROC VertexAttrib3fvNV = cast(PFNGLVERTEXATTRIB3FVNVPROC)__glGetProcAddress("glVertexAttrib3fvNV");
    VertexAttrib3fvNV(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib3svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB3SVNVPROC VertexAttrib3svNV = cast(PFNGLVERTEXATTRIB3SVNVPROC)__glGetProcAddress("glVertexAttrib3svNV");
    VertexAttrib3svNV(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4DVNVPROC VertexAttrib4dvNV = cast(PFNGLVERTEXATTRIB4DVNVPROC)__glGetProcAddress("glVertexAttrib4dvNV");
version (__GLX_ALIGN64) {
    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, 36);
        pc -= 4;
    }
}

    VertexAttrib4dvNV(*cast(GLuint*) (pc + 0), cast(const(GLdouble)*) (pc + 4));
}

void __glXDisp_VertexAttrib4fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4FVNVPROC VertexAttrib4fvNV = cast(PFNGLVERTEXATTRIB4FVNVPROC)__glGetProcAddress("glVertexAttrib4fvNV");
    VertexAttrib4fvNV(*cast(GLuint*) (pc + 0), cast(const(GLfloat)*) (pc + 4));
}

void __glXDisp_VertexAttrib4svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4SVNVPROC VertexAttrib4svNV = cast(PFNGLVERTEXATTRIB4SVNVPROC)__glGetProcAddress("glVertexAttrib4svNV");
    VertexAttrib4svNV(*cast(GLuint*) (pc + 0), cast(const(GLshort)*) (pc + 4));
}

void __glXDisp_VertexAttrib4ubvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIB4UBVNVPROC VertexAttrib4ubvNV = cast(PFNGLVERTEXATTRIB4UBVNVPROC)__glGetProcAddress("glVertexAttrib4ubvNV");
    VertexAttrib4ubvNV(*cast(GLuint*) (pc + 0), cast(const(GLubyte)*) (pc + 4));
}

void __glXDisp_VertexAttribs1dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1DVNVPROC VertexAttribs1dvNV = cast(PFNGLVERTEXATTRIBS1DVNVPROC)__glGetProcAddress("glVertexAttribs1dvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 8)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs1dvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_VertexAttribs1fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1FVNVPROC VertexAttribs1fvNV = cast(PFNGLVERTEXATTRIBS1FVNVPROC)__glGetProcAddress("glVertexAttribs1fvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs1fvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_VertexAttribs1svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS1SVNVPROC VertexAttribs1svNV = cast(PFNGLVERTEXATTRIBS1SVNVPROC)__glGetProcAddress("glVertexAttribs1svNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs1svNV(*cast(GLuint*) (pc + 0), n, cast(const(GLshort)*) (pc + 8));
}

void __glXDisp_VertexAttribs2dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2DVNVPROC VertexAttribs2dvNV = cast(PFNGLVERTEXATTRIBS2DVNVPROC)__glGetProcAddress("glVertexAttribs2dvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 16)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs2dvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_VertexAttribs2fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2FVNVPROC VertexAttribs2fvNV = cast(PFNGLVERTEXATTRIBS2FVNVPROC)__glGetProcAddress("glVertexAttribs2fvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs2fvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_VertexAttribs2svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS2SVNVPROC VertexAttribs2svNV = cast(PFNGLVERTEXATTRIBS2SVNVPROC)__glGetProcAddress("glVertexAttribs2svNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs2svNV(*cast(GLuint*) (pc + 0), n, cast(const(GLshort)*) (pc + 8));
}

void __glXDisp_VertexAttribs3dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3DVNVPROC VertexAttribs3dvNV = cast(PFNGLVERTEXATTRIBS3DVNVPROC)__glGetProcAddress("glVertexAttribs3dvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 24)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs3dvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_VertexAttribs3fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3FVNVPROC VertexAttribs3fvNV = cast(PFNGLVERTEXATTRIBS3FVNVPROC)__glGetProcAddress("glVertexAttribs3fvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs3fvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_VertexAttribs3svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS3SVNVPROC VertexAttribs3svNV = cast(PFNGLVERTEXATTRIBS3SVNVPROC)__glGetProcAddress("glVertexAttribs3svNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs3svNV(*cast(GLuint*) (pc + 0), n, cast(const(GLshort)*) (pc + 8));
}

void __glXDisp_VertexAttribs4dvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4DVNVPROC VertexAttribs4dvNV = cast(PFNGLVERTEXATTRIBS4DVNVPROC)__glGetProcAddress("glVertexAttribs4dvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

version (__GLX_ALIGN64) {
    const(GLuint) cmdlen = 12 + mixin(__GLX_PAD!(`(n * 32)`)) - 4;

    if (cast(c_ulong) (pc) & 7) {
        cast(void) memmove(pc - 4, pc, cmdlen);
        pc -= 4;
    }
}

    VertexAttribs4dvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLdouble)*) (pc + 8));
}

void __glXDisp_VertexAttribs4fvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4FVNVPROC VertexAttribs4fvNV = cast(PFNGLVERTEXATTRIBS4FVNVPROC)__glGetProcAddress("glVertexAttribs4fvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs4fvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLfloat)*) (pc + 8));
}

void __glXDisp_VertexAttribs4svNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4SVNVPROC VertexAttribs4svNV = cast(PFNGLVERTEXATTRIBS4SVNVPROC)__glGetProcAddress("glVertexAttribs4svNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs4svNV(*cast(GLuint*) (pc + 0), n, cast(const(GLshort)*) (pc + 8));
}

void __glXDisp_VertexAttribs4ubvNV(GLbyte* pc)
{
    PFNGLVERTEXATTRIBS4UBVNVPROC VertexAttribs4ubvNV = cast(PFNGLVERTEXATTRIBS4UBVNVPROC)__glGetProcAddress("glVertexAttribs4ubvNV");
    const(GLsizei) n = *cast(GLsizei*) (pc + 4);

    VertexAttribs4ubvNV(*cast(GLuint*) (pc + 0), n, cast(const(GLubyte)*) (pc + 8));
}

void __glXDisp_ActiveStencilFaceEXT(GLbyte* pc)
{
    PFNGLACTIVESTENCILFACEEXTPROC ActiveStencilFaceEXT = cast(PFNGLACTIVESTENCILFACEEXTPROC)__glGetProcAddress("glActiveStencilFaceEXT");
    ActiveStencilFaceEXT(*cast(GLenum*) (pc + 0));
}
