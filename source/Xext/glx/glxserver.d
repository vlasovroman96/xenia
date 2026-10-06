module glx.glxserver;
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

//public import x11.X;
//public import x11.Xproto;
import build.dix_config;
public import x11.Xmd;
public import include.misc;
public import include.dixstruct;
public import include.pixmapstr;
public import include.gcstruct;
public import include.extnsionst;
public import include.resource;
public import include.scrnintstr;

// public //import externs.GL.gl;
// public //import externs.GL.glext;
public import externs.glxproto;

// enum GLX_CONTEXT_OPENGL_NO_ERROR_ARB = 0x31B3;


/*
** GLX resources.
*/
// alias GLXContextID = XID;
// alias GLXDrawable = XID;

alias __GLXclientState = __GLXclientStateRec;



public import glx.glxscreens;
public import glx.glxdrawable;
public import glx.glxcontext;
public import include.glx_extinit;
import glx.glxscreens_h;
 import Xext.glx.fix;


__GLXscreen* glxGetScreen(ScreenPtr pScreen);
// __GLXclientState* glxGetClient(ClientPtr pClient);

/************************************************************************/

void __glXScreenInitVisuals(__GLXscreen* screen);

/*
** The last context used (from the server's perspective) is cached.
*/
// __GLXcontext* __glXForceCurrent(__GLXclientState*, GLXContextTag, int*);

// int __glXError(int error);

/************************************************************************/

enum {
    GLX_MINIMAL_VISUALS,
    GLX_TYPICAL_VISUALS,
    GLX_ALL_VISUALS
}

// void glxSuspendClients();
// void glxResumeClients();

alias glx_func_ptr = void function();
alias glx_gpa_proc = glx_func_ptr function(const(char)*);
// void __glXsetGetProcAddress(glx_gpa_proc get_proc_address);
// void* __glGetProcAddress(const(char)*);
alias CARD32 = x11.Xmd.CARD32;

void __glXsendSwapEvent(__GLXdrawable* drawable, int type, CARD64 ust, CARD64 msc, CARD32 sbc);

static if (PRESENT) {
// void __glXregisterPresentCompleteNotify();
}

/*
** State kept per client.
*/
struct __GLXclientStateRec {
    /*
     ** Buffer for returned data.
     */
    GLbyte* returnBuf;
    GLint returnBufSize;

    /* Back pointer to X client record */
    ClientPtr client;

    char* GLClientextensions;
}

/************************************************************************/

/*
** Dispatch tables.
*/
alias __GLXdispatchRenderProcPtr = void function(GLbyte*);
alias __GLXdispatchSingleProcPtr = int function(__GLXclientState*, GLbyte*);
alias __GLXdispatchVendorPrivProcPtr = int function(__GLXclientState*, GLbyte*);

/*
 * Tables for computing the size of each rendering command.
 */
alias gl_proto_size_func = int function(const(GLbyte)*, Bool, int);

struct __GLXrenderSizeData {
    int bytes;
    gl_proto_size_func varsize;
}

/************************************************************************/

/*
** X resources.
*/
// RESTYPE __glXContextRes;
RESTYPE __glXClientRes;
// RESTYPE __glXDrawableRes;

/************************************************************************/

/*
 * Routines for computing the size of variably-sized rendering commands.
 */

auto safe_add(int a, int b)
{
    if (a < 0 || b < 0)
        return -1;

    if (INT_MAX - a < b)
        return -1;

    return a + b;
}

auto safe_mul(int a, int b)
{
    if (a < 0 || b < 0)
        return -1;

    if (a == 0 || b == 0)
        return 0;

    if (a > INT_MAX / b)
        return -1;

    return a * b;
}

auto safe_pad(int a)
{
    int ret = void;

    if (a < 0)
        return -1;

    if ((ret = safe_add(a, 3)) < 0)
        return -1;

    return ret & cast(GLuint)~3;
}

int __glXTypeSize(GLenum enm);
int __glXImageSize(GLenum format, GLenum type, GLenum target, GLsizei w, GLsizei h, GLsizei d, GLint imageHeight, GLint rowLength, GLint skipImages, GLint skipRows, GLint alignment);

// uint glxMajorVersion;
// uint glxMinorVersion;

// int __glXEventBase;

                          /* !__GLX_server_h__ */
