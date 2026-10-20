module hw.xfree86.common.xf86xvpriv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2003 by The XFree86 Project, Inc.
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

 
public import include.xf86xv;
public import include.privates;
import include.xf86str;
import include.scrnintstr;

/*** These are DDX layer privates ***/

struct _XF86XVScreenRec {
    ClipNotifyProcPtr ClipNotify;
    WindowExposuresProcPtr WindowExposures;
    PostValidateTreeProcPtr PostValidateTree;
    void function(ScrnInfoPtr, int, int) @nogc nothrow AdjustFrame;
    Bool function(ScrnInfoPtr) @nogc nothrow EnterVT;
    void function(ScrnInfoPtr) @nogc nothrow LeaveVT;
    xf86ModeSetProc ModeSet;
}alias XF86XVScreenRec = _XF86XVScreenRec;
alias XF86XVScreenPtr = XF86XVScreenRec*;

struct _XvAdaptorRecPrivate {
    int flags;
    PutVideoFuncPtr PutVideo;
    PutStillFuncPtr PutStill;
    GetVideoFuncPtr GetVideo;
    GetStillFuncPtr GetStill;
    StopVideoFuncPtr StopVideo;
    SetPortAttributeFuncPtr SetPortAttribute;
    GetPortAttributeFuncPtr GetPortAttribute;
    QueryBestSizeFuncPtr QueryBestSize;
    PutImageFuncPtr PutImage;
    ReputImageFuncPtr ReputImage;
    QueryImageAttributesFuncPtr QueryImageAttributes;
}alias XvAdaptorRecPrivate = _XvAdaptorRecPrivate;
alias XvAdaptorRecPrivatePtr = XvAdaptorRecPrivate*;

struct _XvPortRecPrivate {
    ScrnInfoPtr pScrn;
    DrawablePtr pDraw;
    ubyte type;
    uint subWindowMode;
    RegionPtr clientClip;
    RegionPtr ckeyFilled;
    RegionPtr pCompositeClip;
    Bool FreeCompositeClip;
    XvAdaptorRecPrivatePtr AdaptorRec;
    XvStatus isOn;
    Bool clipChanged;
    int vid_x, vid_y, vid_w, vid_h;
    int drw_x, drw_y, drw_w, drw_h;
    DevUnion DevPriv;
}alias XvPortRecPrivate = _XvPortRecPrivate;
alias XvPortRecPrivatePtr = XvPortRecPrivate*;

struct _XF86XVWindowRec {
    XvPortRecPrivatePtr PortRec;
    _XF86XVWindowRec* next;
}alias XF86XVWindowRec = _XF86XVWindowRec;
alias XF86XVWindowPtr = _XF86XVWindowRec*;

                          /* _XF86XVPRIV_H_ */
