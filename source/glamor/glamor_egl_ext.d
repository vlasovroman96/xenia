module glamor.glamor_egl_ext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2008 Tungsten Graphics, Inc., Cedar Park, Texas.
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/* Extensions used by Glamor, copied from Mesa's eglmesaext.h, */

 
/* Define needed tokens from EGL_EXT_image_dma_buf_import extension
 * here to avoid having to add ifdefs everywhere.*/
version (EGL_EXT_image_dma_buf_import) {} else {
// enum EGL_LINUX_DMA_BUF_EXT =					0x3270;
// enum EGL_LINUX_DRM_FOURCC_EXT =				0x3271;
// enum EGL_DMA_BUF_PLANE0_FD_EXT =				0x3272;
// enum EGL_DMA_BUF_PLANE0_OFFSET_EXT =				0x3273;
// enum EGL_DMA_BUF_PLANE0_PITCH_EXT =				0x3274;
// enum EGL_DMA_BUF_PLANE1_FD_EXT =				0x3275;
// enum EGL_DMA_BUF_PLANE1_OFFSET_EXT =				0x3276;
// enum EGL_DMA_BUF_PLANE1_PITCH_EXT =				0x3277;
// enum EGL_DMA_BUF_PLANE2_FD_EXT =				0x3278;
// enum EGL_DMA_BUF_PLANE2_OFFSET_EXT =				0x3279;
// enum EGL_DMA_BUF_PLANE2_PITCH_EXT =				0x327A;
}

/* Define tokens from EGL_EXT_image_dma_buf_import_modifiers */
version (EGL_EXT_image_dma_buf_import_modifiers) {} else {
enum EGL_EXT_image_dma_buf_import_modifiers = 1;
// enum EGL_DMA_BUF_PLANE3_FD_EXT =         0x3440;
// enum EGL_DMA_BUF_PLANE3_OFFSET_EXT =     0x3441;
// enum EGL_DMA_BUF_PLANE3_PITCH_EXT =      0x3442;
// enum EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT = 0x3443;
// enum EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT = 0x3444;
// enum EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT = 0x3445;
// enum EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT = 0x3446;
// enum EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT = 0x3447;
// enum EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT = 0x3448;
// enum EGL_DMA_BUF_PLANE3_MODIFIER_LO_EXT = 0x3449;
// enum EGL_DMA_BUF_PLANE3_MODIFIER_HI_EXT = 0x344A;


}

 /* GLAMOR_EGL_EXT_H */
