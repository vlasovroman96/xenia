module glx.indirect_size;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/* DO NOT EDIT - This file generated automatically by glX_proto_size.py (from Mesa) script */

/*
 * (C) Copyright IBM Corporation 2004
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

 //import externs.GL.gl;
 import Xext.glx.fix;

// static if (!HasVersion!"_INDIRECT_SIZE_H_") {
// version = _INDIRECT_SIZE_H_;

/**
 * \file
 * Prototypes for functions used to determine the number of data elements in
 * various GLX protocol messages.
 *
 * \author Ian Romanick <idr@us.ibm.com>
 */

// //public import x11.Xfuncproto;

// version (__GNUC__) {
// enum PURE = __attribute__((pure));
// } else {
// version = PURE;
// }

// static if (HasVersion!"__i386__" && HasVersion!"__GNUC__" && !HasVersion!"Windows") {
// enum FASTCALL = __attribute__((fastcall));
// } else {
// version = FASTCALL;
// }

// GLint __glCallLists_size(GLenum);
// GLint __glFogfv_size(GLenum);
// GLint __glFogiv_size(GLenum);
// GLint __glLightfv_size(GLenum);
// GLint __glLightiv_size(GLenum);
// GLint __glLightModelfv_size(GLenum);
// GLint __glLightModeliv_size(GLenum);
// GLint __glMaterialfv_size(GLenum);
// GLint __glMaterialiv_size(GLenum);
// GLint __glTexParameterfv_size(GLenum);
// GLint __glTexParameteriv_size(GLenum);
// GLint __glTexEnvfv_size(GLenum);
// GLint __glTexEnviv_size(GLenum);
// GLint __glTexGendv_size(GLenum);
// GLint __glTexGenfv_size(GLenum);
// GLint __glTexGeniv_size(GLenum);
// GLint __glMap1d_size(GLenum);
// GLint __glMap1f_size(GLenum);
// GLint __glMap2d_size(GLenum);
// GLint __glMap2f_size(GLenum);
// GLint __glColorTableParameterfv_size(GLenum);
// GLint __glColorTableParameteriv_size(GLenum);
// GLint __glConvolutionParameterfv_size(GLenum);
// GLint __glConvolutionParameteriv_size(GLenum);
// GLint __glPointParameterfv_size(GLenum);
// GLint __glPointParameteriv_size(GLenum);

// } /* !defined( _INDIRECT_SIZE_H_ ) */
