module hw.xfree86.dri.sarea;
@nogc nothrow:
extern(C): __gshared:
/**
 * \file sarea.h
 * SAREA definitions.
 *
 * \author Kevin E. Martin <kevin@precisioninsight.com>
 * \author Jens Owen <jens@tungstengraphics.com>
 * \author Rickard E. (Rik) Faith <faith@valinux.com>
 */

/*
 * Copyright 1998-1999 Precision Insight, Inc., Cedar Park, Texas.
 * Copyright 2000 VA Linux Systems, Inc.
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sub license, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial portions
 * of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.
 * IN NO EVENT SHALL PRECISION INSIGHT AND/OR ITS SUPPLIERS BE LIABLE FOR
 * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

 
public import externs.libdrm;

/* SAREA area needs to be at least a page */
version (Alpha) {
enum SAREA_MAX = 			0x2000;
} else version (__IA64__) {
enum SAREA_MAX =			0x10000 /* 64kB */;
} else {
/* Intel 830M driver needs at least 8k SAREA */
enum SAREA_MAX =			0x2000;
}

enum SAREA_MAX_DRAWABLES = 		256;

enum SAREA_DRAWABLE_CLAIMED_ENTRY =	0x80000000;

/**
 * SAREA per drawable information.
 *
 * \sa _XF86DRISAREA.
 */
struct _XF86DRISAREADrawable {
    uint stamp;
    uint flags;
}alias XF86DRISAREADrawableRec = _XF86DRISAREADrawable;
alias XF86DRISAREADrawablePtr = _XF86DRISAREADrawable*;

/**
 * SAREA frame information.
 *
 * \sa  _XF86DRISAREA.
 */
struct _XF86DRISAREAFrame {
    uint x;
    uint y;
    uint width;
    uint height;
    uint fullscreen;
}alias XF86DRISAREAFrameRec = _XF86DRISAREAFrame;
alias XF86DRISAREAFramePtr = _XF86DRISAREAFrame*;

/**
 * SAREA definition.
 */
struct _XF86DRISAREA {
    /** first thing is always the DRM locking structure */
    drmLock lock;
    /** \todo Use readers/writer lock for drawable_lock */
    drmLock drawable_lock;
    XF86DRISAREADrawableRec[SAREA_MAX_DRAWABLES] drawableTable;
    XF86DRISAREAFrameRec frame;
    drm_context_t dummy_context;
}alias XF86DRISAREARec = _XF86DRISAREA;
alias XF86DRISAREAPtr = _XF86DRISAREA*;

struct _XF86DRILSAREA {
    drmLock lock;
    drmLock[31] otherLocks;
}alias XF86DRILSAREARec = _XF86DRILSAREA;
alias XF86DRILSAREAPtr = _XF86DRILSAREA*;


