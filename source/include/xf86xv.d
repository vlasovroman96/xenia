module include.xf86xv;
@nogc nothrow:
extern(C): __gshared:

/*
 * Copyright (c) 1998-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

 
public import include.xlibre_ptrtypes;
public import include.xvdix;
public import hw.xfree86.common.xf86str;
import xf86Bus;

enum VIDEO_OVERLAID_IMAGES =			0x00000004;
enum VIDEO_OVERLAID_STILLS =			0x00000008;
/*
 * Usage of VIDEO_CLIP_TO_VIEWPORT is not recommended.
 * It can make reput behaviour inconsistent.
 */
enum VIDEO_CLIP_TO_VIEWPORT =			0x00000010;

alias XF86ImageRec = XvImageRec;
alias XF86ImagePtr = XvImageRec*;

struct _XF86SurfaceRec {
    ScrnInfoPtr pScrn;
    int id;
    ushort width, height;
    int* pitches;               /* bytes */
    int* offsets;               /* in bytes from start of framebuffer */
    DevUnion devPrivate;
}alias XF86SurfaceRec = _XF86SurfaceRec;
alias XF86SurfacePtr = XF86SurfaceRec*;

alias PutVideoFuncPtr = int function(ScrnInfoPtr pScrn, short vid_x, short vid_y, short drw_x, short drw_y, short vid_w, short vid_h, short drw_w, short drw_h, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias PutStillFuncPtr = int function(ScrnInfoPtr pScrn, short vid_x, short vid_y, short drw_x, short drw_y, short vid_w, short vid_h, short drw_w, short drw_h, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias GetVideoFuncPtr = int function(ScrnInfoPtr pScrn, short vid_x, short vid_y, short drw_x, short drw_y, short vid_w, short vid_h, short drw_w, short drw_h, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias GetStillFuncPtr = int function(ScrnInfoPtr pScrn, short vid_x, short vid_y, short drw_x, short drw_y, short vid_w, short vid_h, short drw_w, short drw_h, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias StopVideoFuncPtr = void function(ScrnInfoPtr pScrn, void* data, Bool Exit);
alias SetPortAttributeFuncPtr = int function(ScrnInfoPtr pScrn, Atom attribute, INT32 value, void* data);
alias GetPortAttributeFuncPtr = int function(ScrnInfoPtr pScrn, Atom attribute, INT32* value, void* data);
alias QueryBestSizeFuncPtr = void function(ScrnInfoPtr pScrn, Bool motion, short vid_w, short vid_h, short drw_w, short drw_h, uint* p_w, uint* p_h, void* data);
alias PutImageFuncPtr = int function(ScrnInfoPtr pScrn, short src_x, short src_y, short drw_x, short drw_y, short src_w, short src_h, short drw_w, short drw_h, int image, ubyte* buf, short width, short height, Bool Sync, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias ReputImageFuncPtr = int function(ScrnInfoPtr pScrn, short src_x, short src_y, short drw_x, short drw_y, short src_w, short src_h, short drw_w, short drw_h, RegionPtr clipBoxes, void* data, DrawablePtr pDraw);
alias QueryImageAttributesFuncPtr = int function(ScrnInfoPtr pScrn, int image, ushort* width, ushort* height, int* pitches, int* offsets);

enum XvStatus {
    XV_OFF,
    XV_PENDING,
    XV_ON
}
alias XV_OFF = XvStatus.XV_OFF;
alias XV_PENDING = XvStatus.XV_PENDING;
alias XV_ON = XvStatus.XV_ON;


/*** this is what the driver needs to fill out ***/

struct _XF86VideoEncodingRec {
    int id;
    const(char)* name;
    ushort width, height;
    XvRationalRec rate;
}alias XF86VideoEncodingRec = _XF86VideoEncodingRec;
alias XF86VideoEncodingPtr = XF86VideoEncodingRec*;

struct _XF86VideoFormatRec {
    char depth = 0;
    short class_;
}alias XF86VideoFormatRec = _XF86VideoFormatRec;
alias XF86VideoFormatPtr = XF86VideoFormatRec*;

alias XF86AttributeRec = XvAttributeRec;
alias XF86AttributePtr = XvAttributeRec*;

struct _XF86VideoAdaptorRec {
    uint type;
    int flags;
    const(char)* name;
    int nEncodings;
    XF86VideoEncodingPtr pEncodings;
    int nFormats;
    XF86VideoFormatPtr pFormats;
    int nPorts;
    DevUnion* pPortPrivates;
    int nAttributes;
    XF86AttributePtr pAttributes;
    int nImages;
    XF86ImagePtr pImages;
    PutVideoFuncPtr PutVideo;
    PutStillFuncPtr PutStill;
    GetVideoFuncPtr GetVideo;
    GetStillFuncPtr GetStill;
    StopVideoFuncPtr StopVideo;
    SetPortAttributeFuncPtr SetPortAttribute;
    GetPortAttributeFuncPtr GetPortAttribute;
    QueryBestSizeFuncPtr QueryBestSize;
    PutImageFuncPtr PutImage;
    ReputImageFuncPtr ReputImage;       /* image/still */
    QueryImageAttributesFuncPtr QueryImageAttributes;
}alias XF86VideoAdaptorRec = _XF86VideoAdaptorRec;
alias XF86VideoAdaptorPtr = XF86VideoAdaptorRec*;

struct _XF86OffscreenImageRec {
    XF86ImagePtr image;
    int flags;
    int function(ScrnInfoPtr pScrn, int id, ushort width, ushort height, XF86SurfacePtr surface) alloc_surface;
    int function(XF86SurfacePtr surface) free_surface;
    int function(XF86SurfacePtr surface, short vid_x, short vid_y, short drw_x, short drw_y, short vid_w, short vid_h, short drw_w, short drw_h, RegionPtr clipBoxes) display;
    int function(XF86SurfacePtr surface) stop;
    int function(ScrnInfoPtr pScrn, Atom attr, INT32* value) getAttribute;
    int function(ScrnInfoPtr pScrn, Atom attr, INT32 value) setAttribute;
    int max_width;
    int max_height;
    int num_attributes;
    XF86AttributePtr attributes;
}alias XF86OffscreenImageRec = _XF86OffscreenImageRec;
alias XF86OffscreenImagePtr = XF86OffscreenImageRec*;

void  xf86XVScreenInit(ScreenPtr pScreen, XF86VideoAdaptorPtr* Adaptors, int num);

alias xf86XVInitGenericAdaptorPtr = int function(ScrnInfoPtr pScrn, XF86VideoAdaptorPtr** Adaptors);

void  xf86XVRegisterGenericAdaptorDriver(xf86XVInitGenericAdaptorPtr InitFunc);

void  xf86XVListGenericAdaptors(ScrnInfoPtr pScrn, XF86VideoAdaptorPtr** Adaptors);

void  xf86XVRegisterOffscreenImages(ScreenPtr pScreen, XF86OffscreenImagePtr images, int num);

void  xf86XVQueryOffscreenImages(ScreenPtr pScreen, int* num);

void  xf86XVAllocateVideoAdaptorRec(ScrnInfoPtr pScrn);

void  xf86XVFreeVideoAdaptorRec(XF86VideoAdaptorPtr ptr);

void  xf86XVFillKeyHelper(ScreenPtr pScreen, CARD32 key, RegionPtr clipboxes);

void  xf86XVFillKeyHelperDrawable(DrawablePtr pDraw, CARD32 key, RegionPtr clipboxes);

void  xf86XVClipVideoHelper(BoxPtr dst, INT32* xa, INT32* xb, INT32* ya, INT32* yb, RegionPtr reg, INT32 width, INT32 height);

void  xf86XVCopyYUV12ToPacked(const(void)* srcy, const(void)* srcv, const(void)* srcu, void* dst, int srcPitchy, int srcPitchuv, int dstPitch, int h, int w);

void  xf86XVCopyPacked(const(void)* src, void* dst, int srcPitch, int dstPitch, int h, int w);

                          /* _XF86XV_H_ */
