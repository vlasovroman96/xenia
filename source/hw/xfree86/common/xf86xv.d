module xf86xv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * XFree86 Xv DDX written by Mark Vojkovich (markv@valinux.com)
 */
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
import build.xorg_config;

//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.Xv;
// //import externs.X11.extensions.Xvproto;
import region;

import dix.screen_hooks_priv;
import include.extinit;
import Xext.xvdix_priv;

import include.misc;
import include.xf86;
import include.xf86_OSproc;;
import include.scrnintstr;
import include.regionstr;
import include.windowstr;
import include.pixmapstr;
import include.validate;
import include.resource;
import include.gcstruct;
import include.dixstruct;
import include.xvdix;
import hw.xfree86.common.xf86xvpriv;

// import hw.xfree86.common.xf86sbusBus_priv;;
import hw.xfree86.os_support.bus.xf86Sbus_priv;
import include.xf86sbusBus;
import externs.linux.fbio;
import xf86platformBus_priv;
import xf86Globals;
import xf86Xinput;
import os.log;
import xf86pciBus;
import xf86Option;
import drm_platform;
import core.stdc.string;
import externs.gnu;
import Flags;
import hw.xfree86.common.xf86Helper;
import dix.events;
import include.optionstr;
// import Sbus.c;
import os.log_priv;
import dix.screen_hooks;
import Xext.xvmain;
import externs.X11.extensions.Xv;
import dix.screen_hooks;
import dix.resource;
/* XvAdaptorRec fields */














/* ScreenRec fields */






enum PostValidateTreeUndefined = (cast(PostValidateTreeProcPtr)(-1));

/* ScrnInfoRec functions */






/* misc */



private DevPrivateKeyRec XF86XVWindowKeyRec;

enum XF86XVWindowKey = (&XF86XVWindowKeyRec);

/** xf86xv.c XF86XVScreenPtr screen private */
private DevPrivateKeyRec XF86XVScreenPrivateKey;

private c_ulong PortResource = 0;

enum string GET_XV_SCREEN(string pScreen) = `
    (cast(XvScreenPtr)dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, XvGetScreenKey()))`;

enum string GET_XF86XV_SCREEN(string pScreen) = `
    (cast(XF86XVScreenPtr)(dixGetPrivate(&` ~ pScreen ~ `.devPrivates, &XF86XVScreenPrivateKey)))`;

enum string GET_XF86XV_WINDOW(string pWin) = `
    (cast(XF86XVWindowPtr)dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, XF86XVWindowKey))`;

private xf86XVInitGenericAdaptorPtr* GenDrivers = null;
private int NumGenDrivers = 0;

int xf86XVRegisterGenericAdaptorDriver(xf86XVInitGenericAdaptorPtr InitFunc)
{
    xf86XVInitGenericAdaptorPtr* newdrivers = void;

    newdrivers = cast(xf86XVInitGenericAdaptorPtr*)reallocarray(GenDrivers, 1 + NumGenDrivers,
                              xf86XVInitGenericAdaptorPtr.sizeof);
    if (!newdrivers)
        return 0;
    GenDrivers = newdrivers;

    GenDrivers[NumGenDrivers++] = InitFunc;

    return 1;
}

int xf86XVListGenericAdaptors(ScrnInfoPtr pScrn, XF86VideoAdaptorPtr** adaptors)
{
    int i = void, j = void, n = void, num = void;
    XF86VideoAdaptorPtr* DrivAdap = void, new_ = void;

    num = 0;
    *adaptors = null;
    /*
     * The v4l driver registers itself first, but can use surfaces registered
     * by other drivers.  So, call the v4l driver last.
     */
    for (i = NumGenDrivers; --i >= 0;) {
        DrivAdap = null;
        n = (*GenDrivers[i]) (pScrn, &DrivAdap);
        if (0 == n)
            continue;
        new_ = cast(XF86VideoAdaptorPtr*) reallocarray(*adaptors, num + n, XF86VideoAdaptorPtr.sizeof);
        if (null == new_)
            continue;
        *adaptors = new_;
        for (j = 0; j < n; j++, num++)
            (*adaptors)[num] = DrivAdap[j];
    }
    return num;
}

/****************  Offscreen surface stuff *******************/

struct OffscreenImageRec {
    XF86OffscreenImagePtr images;
    int num;
}

private DevPrivateKeyRec OffscreenPrivateKeyRec;

enum OffscreenPrivateKey = (&OffscreenPrivateKeyRec);
enum string GetOffscreenImage(string pScreen) = `(cast(OffscreenImageRec*) dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, OffscreenPrivateKey))`;

Bool xf86XVRegisterOffscreenImages(ScreenPtr pScreen, XF86OffscreenImagePtr images, int num)
{
    OffscreenImageRec* OffscreenImage = void;

    /* This function may be called before xf86XVScreenInit, so there's
     * no better place than this to call dixRegisterPrivateKey to ensure we
     * have space reserved. After the first call it is a no-op. */
    if (!dixRegisterPrivateKey
        (OffscreenPrivateKey, PRIVATE_SCREEN, OffscreenImageRec.sizeof) ||
        ((OffscreenImage = mixin(GetOffscreenImage!(`pScreen`))) is null))
        /* Every X.org driver assumes this function always succeeds, so
         * just die on allocation failure. */
        FatalError
            ("Could not allocate private storage for XV offscreen images.\n");

    OffscreenImage.num = num;
    OffscreenImage.images = images;
    return TRUE;
}

XF86OffscreenImagePtr xf86XVQueryOffscreenImages(ScreenPtr pScreen, int* num)
{
    OffscreenImageRec* OffscreenImage = mixin(GetOffscreenImage!(`pScreen`));

    *num = OffscreenImage.num;
    return OffscreenImage.images;
}

XF86VideoAdaptorPtr xf86XVAllocateVideoAdaptorRec(ScrnInfoPtr pScrn)
{
    return cast(XF86VideoAdaptorRec*) calloc(1, XF86VideoAdaptorRec.sizeof);
}

void xf86XVFreeVideoAdaptorRec(XF86VideoAdaptorPtr ptr)
{
    free(ptr);
}

Bool xf86XVScreenInit(ScreenPtr pScreen, XF86VideoAdaptorPtr* adaptors, int num)
{
    ScrnInfoPtr pScrn = void;
    XF86XVScreenPtr ScreenPriv = void;

    if (num <= 0 || noXvExtension)
        return FALSE;

    if (Success != XvScreenInit(pScreen))
        return FALSE;

    if (!dixRegisterPrivateKey(&XF86XVWindowKeyRec, PRIVATE_WINDOW, 0))
        return FALSE;
    if (!dixRegisterPrivateKey(&XF86XVScreenPrivateKey, PRIVATE_SCREEN, 0))
        return FALSE;

    PortResource = XvGetRTPort();

    ScreenPriv = cast(XF86XVScreenRec*) calloc(1, XF86XVScreenRec.sizeof);
    dixSetPrivate(&pScreen.devPrivates, &XF86XVScreenPrivateKey, ScreenPriv);

    if (!ScreenPriv)
        return FALSE;

    pScrn = xf86ScreenToScrn(pScreen);

    dixScreenHookWindowDestroy(pScreen, &xf86XVWindowDestroy);
    dixScreenHookClose(pScreen, &xf86XVCloseScreen);

    ScreenPriv.WindowExposures = pScreen.WindowExposures;
    ScreenPriv.PostValidateTree = PostValidateTreeUndefined;
    ScreenPriv.ClipNotify = pScreen.ClipNotify;
    ScreenPriv.EnterVT = pScrn.EnterVT;
    ScreenPriv.LeaveVT = pScrn.LeaveVT;
    ScreenPriv.AdjustFrame = pScrn.AdjustFrame;
    ScreenPriv.ModeSet = pScrn.ModeSet;

    pScreen.WindowExposures = &xf86XVWindowExposures;
    pScreen.ClipNotify = &xf86XVClipNotify;
    pScrn.EnterVT = &xf86XVEnterVT;
    pScrn.LeaveVT = &xf86XVLeaveVT;
    if (pScrn.AdjustFrame)
        pScrn.AdjustFrame = &xf86XVAdjustFrame;
    pScrn.ModeSet = &xf86XVModeSet;

    if (!xf86XVInitAdaptors(pScreen, adaptors, num))
        return FALSE;

    return TRUE;
}

private void xf86XVFreeAdaptor(XvAdaptorPtr pAdaptor)
{
    int i = void;

    if (pAdaptor.pPorts) {
        XvPortPtr pPort = pAdaptor.pPorts;
        XvPortRecPrivatePtr pPriv = void;

        for (i = 0; i < pAdaptor.nPorts; i++, pPort++) {
            pPriv = cast(XvPortRecPrivatePtr) pPort.devPriv.ptr;
            if (pPriv) {
                if (pPriv.clientClip)
                    RegionDestroy(pPriv.clientClip);
                if (pPriv.pCompositeClip && pPriv.FreeCompositeClip)
                    RegionDestroy(pPriv.pCompositeClip);
                if (pPriv.ckeyFilled)
                    RegionDestroy(pPriv.ckeyFilled);
                free(pPriv);
            }
        }
    }

    XvFreeAdaptor(pAdaptor);
}

private Bool xf86XVInitAdaptors(ScreenPtr pScreen, XF86VideoAdaptorPtr* infoPtr, int number)
{
    XvScreenPtr pxvs = mixin(GET_XV_SCREEN!(`pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    XF86VideoAdaptorPtr adaptorPtr = void;
    XvAdaptorPtr pAdaptor = void, pa = void;
    XvAdaptorRecPrivatePtr adaptorPriv = void;
    int na = void, numAdaptor = void;
    XvPortRecPrivatePtr portPriv = void;
    XvPortPtr pPort = void, pp = void;
    int numPort = void;
    XF86VideoFormatPtr formatPtr = void;
    XvFormatPtr pFormat = void, pf = void;
    int numFormat = void, totFormat = void;
    XF86VideoEncodingPtr encodingPtr = void;
    XvEncodingPtr pEncode = void, pe = void;
    int numVisuals = void;
    VisualPtr pVisual = void;
    int i = void;

    pxvs.nAdaptors = 0;
    pxvs.pAdaptors = null;

    if (((pAdaptor = cast(XvAdaptorRec*)calloc(number, XvAdaptorRec.sizeof)) is null))
        return FALSE;

    for (pa = pAdaptor, na = 0, numAdaptor = 0; na < number; na++, adaptorPtr++) {
        adaptorPtr = infoPtr[na];

        if (!adaptorPtr.StopVideo || !adaptorPtr.SetPortAttribute ||
            !adaptorPtr.GetPortAttribute || !adaptorPtr.QueryBestSize)
            continue;

        /* client libs expect at least one encoding */
        if (!adaptorPtr.nEncodings || !adaptorPtr.pEncodings)
            continue;

        pa.type = cast(ubyte)adaptorPtr.type;

        if (!adaptorPtr.PutVideo && !adaptorPtr.GetVideo)
            pa.type &= ~XvVideoMask;

        if (!adaptorPtr.PutStill && !adaptorPtr.GetStill)
            pa.type &= ~XvStillMask;

        if (!adaptorPtr.PutImage || !adaptorPtr.QueryImageAttributes)
            pa.type &= ~XvImageMask;

        if (!adaptorPtr.PutVideo && !adaptorPtr.PutImage &&
            !adaptorPtr.PutStill)
            pa.type &= ~XvInputMask;

        if (!adaptorPtr.GetVideo && !adaptorPtr.GetStill)
            pa.type &= ~XvOutputMask;

        if (!(adaptorPtr.type & (XvPixmapMask | XvWindowMask)))
            continue;
        if (!(adaptorPtr.type & (XvImageMask | XvVideoMask | XvStillMask)))
            continue;

        pa.pScreen = pScreen;
        pa.ddPutVideo = &xf86XVPutVideo;
        pa.ddPutStill = &xf86XVPutStill;
        pa.ddGetVideo = &xf86XVGetVideo;
        pa.ddGetStill = &xf86XVGetStill;
        pa.ddStopVideo = &xf86XVStopVideo;
        pa.ddPutImage = &xf86XVPutImage;
        pa.ddSetPortAttribute = &xf86XVSetPortAttribute;
        pa.ddGetPortAttribute = &xf86XVGetPortAttribute;
        pa.ddQueryBestSize = &xf86XVQueryBestSize;
        pa.ddQueryImageAttributes = &xf86XVQueryImageAttributes;
        pa.name = strdup(adaptorPtr.name);

        if (adaptorPtr.nEncodings &&
            (pEncode = cast(XvEncodingRec*)calloc(adaptorPtr.nEncodings, XvEncodingRec.sizeof) )!is null) {

            for (pe = pEncode, encodingPtr = adaptorPtr.pEncodings, i = 0;
                 i < adaptorPtr.nEncodings; pe++, i++, encodingPtr++) {
                pe.id = encodingPtr.id;
                pe.pScreen = pScreen;
                pe.name = strdup(encodingPtr.name);
                pe.width = encodingPtr.width;
                pe.height = encodingPtr.height;
                pe.rate.numerator = encodingPtr.rate.numerator;
                pe.rate.denominator = encodingPtr.rate.denominator;
            }
            pa.nEncodings = adaptorPtr.nEncodings;
            pa.pEncodings = pEncode;
        }

        if (adaptorPtr.nImages &&
            (pa.pImages = cast(_XvImageRec*)calloc(adaptorPtr.nImages, XvImageRec.sizeof) )!is null) {
            memcpy(pa.pImages, adaptorPtr.pImages,
                   adaptorPtr.nImages * XvImageRec.sizeof);
            pa.nImages = adaptorPtr.nImages;
        }

        if (adaptorPtr.nAttributes &&
            (pa.pAttributes = cast(_XvAttributeRec*)calloc(adaptorPtr.nAttributes,
                                      XvAttributeRec.sizeof))!is null) {
            memcpy(pa.pAttributes, adaptorPtr.pAttributes,
                   adaptorPtr.nAttributes * XvAttributeRec.sizeof);

            for (i = 0; i < adaptorPtr.nAttributes; i++) {
                pa.pAttributes[i].name =
                    strdup(adaptorPtr.pAttributes[i].name);
            }

            pa.nAttributes = adaptorPtr.nAttributes;
        }

        totFormat = adaptorPtr.nFormats;

        if (((pFormat = cast(_XvFormatRec*)calloc(totFormat, XvFormatRec.sizeof)) ) !is null) {
            xf86XVFreeAdaptor(pa);
            continue;
        }
        for (pf = pFormat, i = 0, numFormat = 0, formatPtr =
             adaptorPtr.pFormats; i < adaptorPtr.nFormats; i++, formatPtr++) {
            numVisuals = pScreen.numVisuals;
            pVisual = pScreen.visuals;

            while (numVisuals--) {
                if ((pVisual.class_ == formatPtr.class_) &&
                    (pVisual.nplanes == formatPtr.depth)) {

                    if (numFormat >= totFormat) {
                        void* moreSpace = void;

                        totFormat *= 2;
                        moreSpace = reallocarray(pFormat, totFormat,
                                                 XvFormatRec.sizeof);
                        if (!moreSpace)
                            break;
                        pFormat = cast(_XvFormatRec*)moreSpace;
                        pf = pFormat + numFormat;
                    }

                    pf.visual = pVisual.vid;
                    pf.depth = formatPtr.depth;

                    pf++;
                    numFormat++;
                }
                pVisual++;
            }
        }
        pa.nFormats = numFormat;
        pa.pFormats = pFormat;
        if (!numFormat) {
            xf86XVFreeAdaptor(pa);
            continue;
        }

        if (((adaptorPriv = cast(XvAdaptorRecPrivate*) calloc(1, XvAdaptorRecPrivate.sizeof)) is null)) {
            xf86XVFreeAdaptor(pa);
            continue;
        }

        adaptorPriv.flags = adaptorPtr.flags;
        adaptorPriv.PutVideo = adaptorPtr.PutVideo;
        adaptorPriv.PutStill = adaptorPtr.PutStill;
        adaptorPriv.GetVideo = adaptorPtr.GetVideo;
        adaptorPriv.GetStill = adaptorPtr.GetStill;
        adaptorPriv.StopVideo = adaptorPtr.StopVideo;
        adaptorPriv.SetPortAttribute = adaptorPtr.SetPortAttribute;
        adaptorPriv.GetPortAttribute = adaptorPtr.GetPortAttribute;
        adaptorPriv.QueryBestSize = adaptorPtr.QueryBestSize;
        adaptorPriv.QueryImageAttributes = adaptorPtr.QueryImageAttributes;
        adaptorPriv.PutImage = adaptorPtr.PutImage;
        adaptorPriv.ReputImage = adaptorPtr.ReputImage;       /* image/still */

        pa.devPriv.ptr = cast(void*) adaptorPriv;

        if (((pPort = cast(_XvPortRec*)calloc(adaptorPtr.nPorts, XvPortRec.sizeof)) is null)) {
            xf86XVFreeAdaptor(pa);
            continue;
        }
        for (pp = pPort, i = 0, numPort = 0; i < adaptorPtr.nPorts; i++) {

            if (((pp.id = dixAllocServerXID()) == 0))
                continue;

            if (((portPriv = cast(XvPortRecPrivate*) calloc(1, XvPortRecPrivate.sizeof)) is null))
                continue;

            if (!AddResource(cast(uint)pp.id, cast(uint)PortResource, pp)) {
                free(portPriv);
                continue;
            }

            pp.pAdaptor = pa;
            pp.pNotify = cast(XvPortNotifyPtr) null;
            pp.pDraw = cast(DrawablePtr) null;
            pp.client = cast(ClientPtr) null;
            pp.grab.client = cast(ClientPtr) null;
            pp.time = currentTime;
            pp.devPriv.ptr = portPriv;

            portPriv.pScrn = pScrn;
            portPriv.AdaptorRec = adaptorPriv;
            portPriv.DevPriv.ptr = adaptorPtr.pPortPrivates[i].ptr;

            pp++;
            numPort++;
        }
        pa.nPorts = numPort;
        pa.pPorts = pPort;
        if (!numPort) {
            xf86XVFreeAdaptor(pa);
            continue;
        }

        pa.base_id = pPort.id;

        pa++;
        numAdaptor++;
    }

    if (numAdaptor) {
        pxvs.nAdaptors = numAdaptor;
        pxvs.pAdaptors = pAdaptor;
    }
    else {
        free(pAdaptor);
        return FALSE;
    }

    return TRUE;
}

/* Video should be clipped to the intersection of the window cliplist
   and the client cliplist specified in the GC for which the video was
   initialized.  When we need to reclip a window, the GC that started
   the video may not even be around anymore.  That's why we save the
   client clip from the GC when the video is initialized.  We then
   use xf86XVUpdateCompositeClip to calculate the new composite clip
   when we need it.  This is different from what DEC did.  They saved
   the GC and used its clip list when they needed to reclip the window,
   even if the client clip was different from the one the video was
   initialized with.  If the original GC was destroyed, they had to stop
   the video.  I like the new method better (MArk).

   This function only works for windows.  Will need to rewrite when
   (if) we support pixmap rendering.
*/

private void xf86XVUpdateCompositeClip(XvPortRecPrivatePtr portPriv)
{
    RegionPtr pregWin = void, pCompositeClip = void;
    WindowPtr pWin = void;
    Bool freeCompClip = FALSE;

    if (portPriv.pCompositeClip)
        return;

    pWin = cast(WindowPtr) portPriv.pDraw;

    /* get window clip list */
    if (portPriv.subWindowMode == IncludeInferiors) {
        pregWin = NotClippedByChildren(pWin);
        freeCompClip = TRUE;
    }
    else
        pregWin = &pWin.clipList;

    if (!portPriv.clientClip) {
        portPriv.pCompositeClip = pregWin;
        portPriv.FreeCompositeClip = freeCompClip;
        return;
    }

    pCompositeClip = RegionCreate(NullBox, 1);
    RegionCopy(pCompositeClip, portPriv.clientClip);
    RegionTranslate(pCompositeClip, portPriv.pDraw.x, portPriv.pDraw.y);
    RegionIntersect(pCompositeClip, pregWin, pCompositeClip);

    portPriv.pCompositeClip = pCompositeClip;
    portPriv.FreeCompositeClip = TRUE;

    if (freeCompClip) {
        RegionDestroy(pregWin);
    }
}

/* Save the current clientClip and update the CompositeClip whenever
   we have a fresh GC */

private void xf86XVCopyClip(XvPortRecPrivatePtr portPriv, GCPtr pGC)
{
    /* copy the new clip if it exists */
    if (pGC.clientClip) {
        if (!portPriv.clientClip)
            portPriv.clientClip = RegionCreate(NullBox, 1);
        /* Note: this is in window coordinates */
        RegionCopy(portPriv.clientClip, pGC.clientClip);
        RegionTranslate(portPriv.clientClip, pGC.clipOrg.x, pGC.clipOrg.y);
    }
    else if (portPriv.clientClip) {    /* free the old clientClip */
        RegionDestroy(portPriv.clientClip);
        portPriv.clientClip = null;
    }

    /* get rid of the old clip list */
    if (portPriv.pCompositeClip && portPriv.FreeCompositeClip) {
        RegionDestroy(portPriv.pCompositeClip);
    }

    portPriv.pCompositeClip = pGC.pCompositeClip;
    portPriv.FreeCompositeClip = FALSE;
    portPriv.subWindowMode = pGC.subWindowMode;
}

private void xf86XVCopyCompositeClip(XvPortRecPrivatePtr portPriv, GCPtr pGC, DrawablePtr pDraw)
{
    if (!portPriv.clientClip)
        portPriv.clientClip = RegionCreate(NullBox, 1);
    /* Keep the original GC composite clip around for ReputImage */
    RegionCopy(portPriv.clientClip, pGC.pCompositeClip);
    RegionTranslate(portPriv.clientClip, -pDraw.x, -pDraw.y);

    /* get rid of the old clip list */
    if (portPriv.pCompositeClip && portPriv.FreeCompositeClip)
        RegionDestroy(portPriv.pCompositeClip);

    portPriv.pCompositeClip = pGC.pCompositeClip;
    portPriv.FreeCompositeClip = FALSE;
    portPriv.subWindowMode = pGC.subWindowMode;
}

private int xf86XVRegetVideo(XvPortRecPrivatePtr portPriv)
{
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    xf86XVUpdateCompositeClip(portPriv);

    /* translate the video region to the screen */
    WinBox.x1 = cast(short)(portPriv.pDraw.x + portPriv.drw_x);
    WinBox.y1 = cast(short)(portPriv.pDraw.y + portPriv.drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + portPriv.drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + portPriv.drw_h);

    /* clip to the window composite clip */
    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, portPriv.pCompositeClip);

    /* that's all if it's totally obscured */
    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto CLIP_VIDEO_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.GetVideo) (portPriv.pScrn,
                                             cast(short)portPriv.vid_x, cast(short)portPriv.vid_y,
                                             WinBox.x1, WinBox.y1,
                                             cast(short)portPriv.vid_w, cast(short)portPriv.vid_h,
                                             cast(short)portPriv.drw_w, cast(short)portPriv.drw_h,
                                             &ClipRegion, portPriv.DevPriv.ptr,
                                             portPriv.pDraw);

    if (ret == Success)
        portPriv.isOn = XV_ON;

 CLIP_VIDEO_BAILOUT:

    if ((clippedAway || (ret != Success)) && portPriv.isOn == XV_ON) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    /* This clip was copied and only good for one shot */
    if (!portPriv.FreeCompositeClip)
        portPriv.pCompositeClip = null;

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

private int xf86XVReputVideo(XvPortRecPrivatePtr portPriv)
{
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    xf86XVUpdateCompositeClip(portPriv);

    /* translate the video region to the screen */
    WinBox.x1 = cast(short)(portPriv.pDraw.x + portPriv.drw_x);
    WinBox.y1 = cast(short)(portPriv.pDraw.y + portPriv.drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + portPriv.drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + portPriv.drw_h);

    /* clip to the window composite clip */
    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, portPriv.pCompositeClip);

    /* clip and translate to the viewport */
    if (portPriv.AdaptorRec.flags & VIDEO_CLIP_TO_VIEWPORT) {
        RegionRec VPReg = void;
        BoxRec VPBox = void;

        VPBox.x1 = cast(short)(portPriv.pScrn.frameX0);
        VPBox.y1 = cast(short)(portPriv.pScrn.frameY0);
        VPBox.x2 = cast(short)(portPriv.pScrn.frameX1 + 1);
        VPBox.y2 = cast(short)(portPriv.pScrn.frameY1 + 1);

        RegionInit(&VPReg, &VPBox, 1);
        RegionIntersect(&ClipRegion, &ClipRegion, &VPReg);
        RegionUninit(&VPReg);
    }

    /* that's all if it's totally obscured */
    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto CLIP_VIDEO_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.PutVideo) (portPriv.pScrn,
                                             cast(short)portPriv.vid_x, cast(short)portPriv.vid_y,
                                             WinBox.x1, WinBox.y1,
                                             cast(short)portPriv.vid_w, cast(short)portPriv.vid_h,
                                             cast(short)portPriv.drw_w, cast(short)portPriv.drw_h,
                                             &ClipRegion, portPriv.DevPriv.ptr,
                                             portPriv.pDraw);

    if (ret == Success)
        portPriv.isOn = XV_ON;

 CLIP_VIDEO_BAILOUT:

    if ((clippedAway || (ret != Success)) && (portPriv.isOn == XV_ON)) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    /* This clip was copied and only good for one shot */
    if (!portPriv.FreeCompositeClip)
        portPriv.pCompositeClip = null;

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

/* Reput image/still */
private int xf86XVReputImage(XvPortRecPrivatePtr portPriv)
{
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    xf86XVUpdateCompositeClip(portPriv);

    /* the clip can get smaller over time */
    RegionCopy(portPriv.clientClip, portPriv.pCompositeClip);
    RegionTranslate(portPriv.clientClip,
                    -portPriv.pDraw.x, -portPriv.pDraw.y);

    /* translate the video region to the screen */
    WinBox.x1 = cast(short)(portPriv.pDraw.x + portPriv.drw_x);
    WinBox.y1 = cast(short)(portPriv.pDraw.y + portPriv.drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + portPriv.drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + portPriv.drw_h);

    /* clip to the window composite clip */
    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, portPriv.pCompositeClip);

    /* clip and translate to the viewport */
    if (portPriv.AdaptorRec.flags & VIDEO_CLIP_TO_VIEWPORT) {
        RegionRec VPReg = void;
        BoxRec VPBox = void;

        VPBox.x1 = cast(short)(portPriv.pScrn.frameX0);
        VPBox.y1 = cast(short)(portPriv.pScrn.frameY0);
        VPBox.x2 = cast(short)(portPriv.pScrn.frameX1 + 1);
        VPBox.y2 = cast(short)(portPriv.pScrn.frameY1 + 1);

        RegionInit(&VPReg, &VPBox, 1);
        RegionIntersect(&ClipRegion, &ClipRegion, &VPReg);
        RegionUninit(&VPReg);
    }

    /* that's all if it's totally obscured */
    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto CLIP_VIDEO_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.ReputImage) (portPriv.pScrn,
                                               cast(short)portPriv.vid_x, cast(short)portPriv.vid_y,
                                               WinBox.x1, WinBox.y1,
                                               cast(short)portPriv.vid_w, cast(short)portPriv.vid_h,
                                               cast(short)portPriv.drw_w, cast(short)portPriv.drw_h,
                                               &ClipRegion,
                                               portPriv.DevPriv.ptr,
                                               portPriv.pDraw);

    portPriv.isOn = (ret == Success) ? XV_ON : XV_OFF;

 CLIP_VIDEO_BAILOUT:

    if ((clippedAway || (ret != Success)) && (portPriv.isOn == XV_ON)) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    /* This clip was copied and only good for one shot */
    if (!portPriv.FreeCompositeClip)
        portPriv.pCompositeClip = null;

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

private int xf86XVReputAllVideo(WindowPtr pWin, void* data)
{
    XF86XVWindowPtr WinPriv = mixin(GET_XF86XV_WINDOW!(`pWin`));

    while (WinPriv) {
        if (WinPriv.PortRec.type == XvInputMask)
            xf86XVReputVideo(WinPriv.PortRec);
        else
            xf86XVRegetVideo(WinPriv.PortRec);
        WinPriv = WinPriv.next;
    }

    return WT_WALKCHILDREN;
}

private int xf86XVEnlistPortInWindow(WindowPtr pWin, XvPortRecPrivatePtr portPriv)
{
    XF86XVWindowPtr winPriv = void, PrivRoot = void;

    winPriv = PrivRoot = mixin(GET_XF86XV_WINDOW!(`pWin`));

    /* Enlist our port in the window private */
    while (winPriv) {
        if (winPriv.PortRec == portPriv)       /* we're already listed */
            break;
        winPriv = winPriv.next;
    }

    if (!winPriv) {
        winPriv = cast(XF86XVWindowRec*) calloc(1, XF86XVWindowRec.sizeof);
        if (!winPriv)
            return BadAlloc;
        winPriv.PortRec = portPriv;
        winPriv.next = PrivRoot;
        dixSetPrivate(&pWin.devPrivates, XF86XVWindowKey, winPriv);
    }

    portPriv.pDraw = cast(DrawablePtr) pWin;

    return Success;
}

private void xf86XVRemovePortFromWindow(WindowPtr pWin, XvPortRecPrivatePtr portPriv)
{
    XF86XVWindowPtr winPriv = void, prevPriv = null;

    winPriv = mixin(GET_XF86XV_WINDOW!(`pWin`));

    while (winPriv) {
        if (winPriv.PortRec == portPriv) {
            if (prevPriv)
                prevPriv.next = winPriv.next;
            else
                dixSetPrivate(&pWin.devPrivates, XF86XVWindowKey,
                              winPriv.next);
            free(winPriv);
            break;
        }
        prevPriv = winPriv;
        winPriv = winPriv.next;
    }
    portPriv.pDraw = null;
    if (portPriv.ckeyFilled) {
        RegionDestroy(portPriv.ckeyFilled);
        portPriv.ckeyFilled = null;
    }
    portPriv.clipChanged = FALSE;
}

private void xf86XVReputOrStopPort(XvPortRecPrivatePtr pPriv, WindowPtr pWin, Bool visible)
{
    if (!visible) {
        if (pPriv.isOn == XV_ON) {
            (*pPriv.AdaptorRec.StopVideo) (pPriv.pScrn, pPriv.DevPriv.ptr,
                                             FALSE);
            pPriv.isOn = XV_PENDING;
        }

        if (!pPriv.type)       /* overlaid still/image */
            xf86XVRemovePortFromWindow(pWin, pPriv);

        return;
    }

    switch (pPriv.type) {
    case XvInputMask:
        xf86XVReputVideo(pPriv);
        break;
    case XvOutputMask:
        xf86XVRegetVideo(pPriv);
        break;
    default:                   /* overlaid still/image */
        if (pPriv.AdaptorRec.ReputImage)
            xf86XVReputImage(pPriv);
        break;
    }
}

private void xf86XVReputOrStopAllPorts(ScrnInfoPtr pScrn, Bool onlyChanged)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    XvScreenPtr pxvs = mixin(GET_XV_SCREEN!(`pScreen`));
    XvAdaptorPtr pa = void;
    int c = void, i = void;

    for (c = pxvs.nAdaptors, pa = pxvs.pAdaptors; c > 0; c--, pa++) {
        XvPortPtr pPort = pa.pPorts;

        for (i = pa.nPorts; i > 0; i--, pPort++) {
            XvPortRecPrivatePtr pPriv = cast(XvPortRecPrivatePtr) pPort.devPriv.ptr;
            WindowPtr pWin = cast(WindowPtr) pPriv.pDraw;
            Bool visible = void;

            if (pPriv.isOn == XV_OFF || !pWin)
                continue;

            if (onlyChanged && !pPriv.clipChanged)
                continue;

            visible = pWin.visibility == VisibilityUnobscured ||
                pWin.visibility == VisibilityPartiallyObscured;

            /*
             * Stop and remove still/images if
             * ReputImage isn't supported.
             */
            if (!pPriv.type && !pPriv.AdaptorRec.ReputImage)
                visible = FALSE;

            xf86XVReputOrStopPort(pPriv, pWin, visible);

            pPriv.clipChanged = FALSE;
        }
    }
}

/****  ScreenRec fields ****/

private void xf86XVWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWin)
{
    XF86XVWindowPtr tmp = void, WinPriv = mixin(GET_XF86XV_WINDOW!(`pWin`));

    while (WinPriv) {
        XvPortRecPrivatePtr pPriv = WinPriv.PortRec;

        if (pPriv.isOn > XV_OFF) {
            (*pPriv.AdaptorRec.StopVideo) (pPriv.pScrn, pPriv.DevPriv.ptr,
                                             TRUE);
            pPriv.isOn = XV_OFF;
        }

        pPriv.pDraw = null;
        tmp = WinPriv;
        WinPriv = WinPriv.next;
        free(tmp);
    }

    dixSetPrivate(&pWin.devPrivates, XF86XVWindowKey, null);
}

private void xf86XVPostValidateTree(WindowPtr pWin, WindowPtr pLayerWin, VTKind kind)
{
    ScreenPtr pScreen = void;
    XF86XVScreenPtr ScreenPriv = void;
    ScrnInfoPtr pScrn = void;

    if (pWin)
        pScreen = pWin.drawable.pScreen;
    else
        pScreen = pLayerWin.drawable.pScreen;

    ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    pScrn = xf86ScreenToScrn(pScreen);

    xf86XVReputOrStopAllPorts(pScrn, TRUE);

    pScreen.PostValidateTree = ScreenPriv.PostValidateTree;
    if (pScreen.PostValidateTree) {
        (*pScreen.PostValidateTree) (pWin, pLayerWin, kind);
    }
    ScreenPriv.PostValidateTree = PostValidateTreeUndefined;
}

private void xf86XVWindowExposures(WindowPtr pWin, RegionPtr reg1)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    XF86XVWindowPtr WinPriv = mixin(GET_XF86XV_WINDOW!(`pWin`));
    XvPortRecPrivatePtr pPriv = void;
    Bool AreasExposed = void;

    AreasExposed = (WinPriv && reg1 && RegionNotEmpty(reg1));

    pScreen.WindowExposures = ScreenPriv.WindowExposures;
    (*pScreen.WindowExposures) (pWin, reg1);
    pScreen.WindowExposures = &xf86XVWindowExposures;

    /* filter out XClearWindow/Area */
    if (!pWin.valdata)
        return;

    while (WinPriv) {
        Bool visible = TRUE;

        pPriv = WinPriv.PortRec;

        /*
         * Stop and remove still/images if areas were exposed and
         * ReputImage isn't supported.
         */
        if (!pPriv.type && !pPriv.AdaptorRec.ReputImage)
            visible = !AreasExposed;

        /*
         * Subtract exposed areas from overlaid image to match textured video
         * behavior.
         */
        if (!pPriv.type && pPriv.clientClip)
            RegionSubtract(pPriv.clientClip, pPriv.clientClip, reg1);

        if (visible && pPriv.ckeyFilled) {
            RegionRec tmp = void;

            RegionNull(&tmp);
            RegionCopy(&tmp, reg1);
            RegionTranslate(&tmp, pWin.drawable.x, pWin.drawable.y);
            RegionSubtract(pPriv.ckeyFilled, pPriv.ckeyFilled, &tmp);
        }

        WinPriv = WinPriv.next;
        xf86XVReputOrStopPort(pPriv, pWin, visible);

        pPriv.clipChanged = FALSE;
    }
}

private void xf86XVClipNotify(WindowPtr pWin, int dx, int dy)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    XF86XVWindowPtr WinPriv = mixin(GET_XF86XV_WINDOW!(`pWin`));
    XvPortRecPrivatePtr pPriv = void;

    while (WinPriv) {
        pPriv = WinPriv.PortRec;

        if (pPriv.pCompositeClip && pPriv.FreeCompositeClip)
            RegionDestroy(pPriv.pCompositeClip);

        pPriv.pCompositeClip = null;

        pPriv.clipChanged = TRUE;

        if (ScreenPriv.PostValidateTree == PostValidateTreeUndefined) {
            ScreenPriv.PostValidateTree = pScreen.PostValidateTree;
            pScreen.PostValidateTree = &xf86XVPostValidateTree;
        }

        WinPriv = WinPriv.next;
    }

    if (ScreenPriv.ClipNotify) {
        pScreen.ClipNotify = ScreenPriv.ClipNotify;
        (*pScreen.ClipNotify) (pWin, dx, dy);
        pScreen.ClipNotify = &xf86XVClipNotify;
    }
}

/**** Required XvScreenRec fields ****/

private void xf86XVCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    XvScreenPtr pxvs = mixin(GET_XV_SCREEN!(`pScreen`));
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    XvAdaptorPtr pa = void;
    int c = void;

    if (!ScreenPriv)
        return;

    dixScreenUnhookWindowDestroy(pScreen, &xf86XVWindowDestroy);
    dixScreenUnhookClose(pScreen, &xf86XVCloseScreen);

    pScreen.WindowExposures = ScreenPriv.WindowExposures;
    pScreen.ClipNotify = ScreenPriv.ClipNotify;

    pScrn.EnterVT = ScreenPriv.EnterVT;
    pScrn.LeaveVT = ScreenPriv.LeaveVT;
    pScrn.AdjustFrame = ScreenPriv.AdjustFrame;
    pScrn.ModeSet = ScreenPriv.ModeSet;

    for (c = 0, pa = pxvs.pAdaptors; c < pxvs.nAdaptors; c++, pa++) {
        xf86XVFreeAdaptor(pa);
    }

    free(pxvs.pAdaptors);
    free(ScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &XF86XVScreenPrivateKey, null);
}

/**** ScrnInfoRec fields ****/

private Bool xf86XVEnterVT(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    Bool ret = void;

    pScrn.EnterVT = ScreenPriv.EnterVT;
    ret = (*ScreenPriv.EnterVT) (pScrn);
    ScreenPriv.EnterVT = pScrn.EnterVT;
    pScrn.EnterVT = &xf86XVEnterVT;

    if (ret)
        WalkTree(pScreen, &xf86XVReputAllVideo, null);

    return ret;
}

private void xf86XVLeaveVT(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    XvScreenPtr pxvs = mixin(GET_XV_SCREEN!(`pScreen`));
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));
    XvAdaptorPtr pAdaptor = void;
    XvPortPtr pPort = void;
    XvPortRecPrivatePtr pPriv = void;
    int i = void, j = void;

    for (i = 0; i < pxvs.nAdaptors; i++) {
        pAdaptor = &pxvs.pAdaptors[i];
        for (j = 0; j < pAdaptor.nPorts; j++) {
            pPort = &pAdaptor.pPorts[j];
            pPriv = cast(XvPortRecPrivatePtr) pPort.devPriv.ptr;
            if (pPriv.isOn > XV_OFF) {

                (*pPriv.AdaptorRec.StopVideo) (pPriv.pScrn,
                                                 pPriv.DevPriv.ptr, TRUE);
                pPriv.isOn = XV_OFF;

                if (pPriv.pCompositeClip && pPriv.FreeCompositeClip)
                    RegionDestroy(pPriv.pCompositeClip);

                pPriv.pCompositeClip = null;

                if (!pPriv.type && pPriv.pDraw) {     /* still */
                    xf86XVRemovePortFromWindow(cast(WindowPtr) pPriv.pDraw, pPriv);
                }
            }
        }
    }

    pScrn.LeaveVT = ScreenPriv.LeaveVT;
    (*ScreenPriv.LeaveVT) (pScrn);
    ScreenPriv.LeaveVT = pScrn.LeaveVT;
    pScrn.LeaveVT = &xf86XVLeaveVT;
}

private void xf86XVAdjustFrame(ScrnInfoPtr pScrn, int x, int y)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    XF86XVScreenPtr ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));

    if (ScreenPriv.AdjustFrame) {
        pScrn.AdjustFrame = ScreenPriv.AdjustFrame;
        (*pScrn.AdjustFrame) (pScrn, x, y);
        pScrn.AdjustFrame = &xf86XVAdjustFrame;
    }

    xf86XVReputOrStopAllPorts(pScrn, FALSE);
}

private void xf86XVModeSet(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    XF86XVScreenPtr ScreenPriv = void;

    /* Can be called before pScrn->pScreen is set */
    if (!pScreen)
        return;

    ScreenPriv = mixin(GET_XF86XV_SCREEN!(`pScreen`));

    if (ScreenPriv.ModeSet) {
        pScrn.ModeSet = ScreenPriv.ModeSet;
        (*pScrn.ModeSet) (pScrn);
        pScrn.ModeSet = &xf86XVModeSet;
    }

    xf86XVReputOrStopAllPorts(pScrn, FALSE);
}

/**** XvAdaptorRec fields ****/

private int xf86XVPutVideo(DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);
    int result = void;

    /* No dumping video to pixmaps... For now anyhow */
    if (pDraw.type != DRAWABLE_WINDOW) {
        pPort.pDraw = cast(DrawablePtr) null;
        return BadAlloc;
    }

    /* If we are changing windows, unregister our port in the old window */
    if (portPriv.pDraw && (portPriv.pDraw != pDraw))
        xf86XVRemovePortFromWindow(cast(WindowPtr) (portPriv.pDraw), portPriv);

    /* Register our port with the new window */
    result = xf86XVEnlistPortInWindow(cast(WindowPtr) pDraw, portPriv);
    if (result != Success)
        return result;

    portPriv.type = cast(ubyte)XvInputMask;

    /* save a copy of these parameters */
    portPriv.vid_x = vid_x;
    portPriv.vid_y = vid_y;
    portPriv.vid_w = vid_w;
    portPriv.vid_h = vid_h;
    portPriv.drw_x = drw_x;
    portPriv.drw_y = drw_y;
    portPriv.drw_w = drw_w;
    portPriv.drw_h = drw_h;

    /* make sure we have the most recent copy of the clientClip */
    xf86XVCopyClip(portPriv, pGC);

    /* To indicate to the DI layer that we were successful */
    pPort.pDraw = pDraw;

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    return (xf86XVReputVideo(portPriv));
}

private int xf86XVPutStill(DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    if (pDraw.type != DRAWABLE_WINDOW)
        return BadAlloc;

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    WinBox.x1 = cast(short)(pDraw.x + drw_x);
    WinBox.y1 = cast(short)(pDraw.y + drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + drw_h);

    xf86XVCopyCompositeClip(portPriv, pGC, pDraw);

    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, pGC.pCompositeClip);

    if (portPriv.AdaptorRec.flags & VIDEO_CLIP_TO_VIEWPORT) {
        RegionRec VPReg = void;
        BoxRec VPBox = void;

        VPBox.x1 = cast(short)(portPriv.pScrn.frameX0);
        VPBox.y1 = cast(short)(portPriv.pScrn.frameY0);
        VPBox.x2 = cast(short)(portPriv.pScrn.frameX1 + 1);
        VPBox.y2 = cast(short)(portPriv.pScrn.frameY1 + 1);

        RegionInit(&VPReg, &VPBox, 1);
        RegionIntersect(&ClipRegion, &ClipRegion, &VPReg);
        RegionUninit(&VPReg);
    }

    if (portPriv.pDraw) {
        xf86XVRemovePortFromWindow(cast(WindowPtr) (portPriv.pDraw), portPriv);
    }

    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto PUT_STILL_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.PutStill) (portPriv.pScrn,
                                             vid_x, vid_y, WinBox.x1, WinBox.y1,
                                             vid_w, vid_h, drw_w, drw_h,
                                             &ClipRegion, portPriv.DevPriv.ptr,
                                             pDraw);

    if ((ret == Success) &&
        (portPriv.AdaptorRec.flags & VIDEO_OVERLAID_STILLS)) {

        xf86XVEnlistPortInWindow(cast(WindowPtr) pDraw, portPriv);
        portPriv.isOn = XV_ON;
        portPriv.vid_x = vid_x;
        portPriv.vid_y = vid_y;
        portPriv.vid_w = vid_w;
        portPriv.vid_h = vid_h;
        portPriv.drw_x = drw_x;
        portPriv.drw_y = drw_y;
        portPriv.drw_w = drw_w;
        portPriv.drw_h = drw_h;
        portPriv.type = 0;     /* no mask means it's transient and should
                                   not be reput once it's removed */
        pPort.pDraw = pDraw;   /* make sure we can get stop requests */
    }

 PUT_STILL_BAILOUT:

    if ((clippedAway || (ret != Success)) && (portPriv.isOn == XV_ON)) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    /* This clip was copied and only good for one shot */
    if (!portPriv.FreeCompositeClip)
        portPriv.pCompositeClip = null;

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

private int xf86XVGetVideo(DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);
    int result = void;

    /* No pixmaps... For now anyhow */
    if (pDraw.type != DRAWABLE_WINDOW) {
        pPort.pDraw = cast(DrawablePtr) null;
        return BadAlloc;
    }

    /* If we are changing windows, unregister our port in the old window */
    if (portPriv.pDraw && (portPriv.pDraw != pDraw))
        xf86XVRemovePortFromWindow(cast(WindowPtr) (portPriv.pDraw), portPriv);

    /* Register our port with the new window */
    result = xf86XVEnlistPortInWindow(cast(WindowPtr) pDraw, portPriv);
    if (result != Success)
        return result;

    portPriv.type = cast(ubyte)XvOutputMask;

    /* save a copy of these parameters */
    portPriv.vid_x = vid_x;
    portPriv.vid_y = vid_y;
    portPriv.vid_w = vid_w;
    portPriv.vid_h = vid_h;
    portPriv.drw_x = drw_x;
    portPriv.drw_y = drw_y;
    portPriv.drw_w = drw_w;
    portPriv.drw_h = drw_h;

    /* make sure we have the most recent copy of the clientClip */
    xf86XVCopyClip(portPriv, pGC);

    /* To indicate to the DI layer that we were successful */
    pPort.pDraw = pDraw;

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    return (xf86XVRegetVideo(portPriv));
}

private int xf86XVGetStill(DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    if (pDraw.type != DRAWABLE_WINDOW)
        return BadAlloc;

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    WinBox.x1 = cast(short)(pDraw.x + drw_x);
    WinBox.y1 = cast(short)(pDraw.y + drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + drw_h);

    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, pGC.pCompositeClip);

    if (portPriv.pDraw) {
        xf86XVRemovePortFromWindow(cast(WindowPtr) (portPriv.pDraw), portPriv);
    }

    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto GET_STILL_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.GetStill) (portPriv.pScrn,
                                             vid_x, vid_y, WinBox.x1, WinBox.y1,
                                             vid_w, vid_h, drw_w, drw_h,
                                             &ClipRegion, portPriv.DevPriv.ptr,
                                             pDraw);

 GET_STILL_BAILOUT:

    if ((clippedAway || (ret != Success)) && (portPriv.isOn == XV_ON)) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

private int xf86XVStopVideo(XvPortPtr pPort, DrawablePtr pDraw)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    if (pDraw.type != DRAWABLE_WINDOW)
        return BadAlloc;

    xf86XVRemovePortFromWindow(cast(WindowPtr) pDraw, portPriv);

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    /* Must free resources. */

    if (portPriv.isOn > XV_OFF) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, TRUE);
        portPriv.isOn = XV_OFF;
    }

    return Success;
}

private int xf86XVSetPortAttribute(XvPortPtr pPort, Atom attribute, INT32 value)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    return ((*portPriv.AdaptorRec.SetPortAttribute) (portPriv.pScrn,
                                                       attribute, value,
                                                       portPriv.DevPriv.ptr));
}

private int xf86XVGetPortAttribute(XvPortPtr pPort, Atom attribute, INT32* p_value)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    return ((*portPriv.AdaptorRec.GetPortAttribute) (portPriv.pScrn,
                                                       attribute, p_value,
                                                       portPriv.DevPriv.ptr));
}

private int xf86XVQueryBestSize(XvPortPtr pPort, CARD8 motion, CARD16 vid_w, CARD16 vid_h, CARD16 drw_w, CARD16 drw_h, uint* p_w, uint* p_h)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    (*portPriv.AdaptorRec.QueryBestSize) (portPriv.pScrn,
                                            cast(Bool) motion, vid_w, vid_h, drw_w,
                                            drw_h, p_w, p_h,
                                            portPriv.DevPriv.ptr);

    return Success;
}

private int xf86XVPutImage(DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 src_x, INT16 src_y, CARD16 src_w, CARD16 src_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h, XvImagePtr format, ubyte* data, Bool sync, CARD16 width, CARD16 height)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);
    RegionRec WinRegion = void;
    RegionRec ClipRegion = void;
    BoxRec WinBox = void;
    int ret = Success;
    Bool clippedAway = FALSE;

    if (pDraw.type != DRAWABLE_WINDOW)
        return BadAlloc;

    if (!portPriv.pScrn.vtSema)
        return Success;         /* Success ? */

    xf86XVCopyCompositeClip(portPriv, pGC, pDraw);

    WinBox.x1 = cast(short)(pDraw.x + drw_x);
    WinBox.y1 = cast(short)(pDraw.y + drw_y);
    WinBox.x2 = cast(short)(WinBox.x1 + drw_w);
    WinBox.y2 = cast(short)(WinBox.y1 + drw_h);

    RegionInit(&WinRegion, &WinBox, 1);
    RegionNull(&ClipRegion);
    RegionIntersect(&ClipRegion, &WinRegion, pGC.pCompositeClip);

    if (portPriv.AdaptorRec.flags & VIDEO_CLIP_TO_VIEWPORT) {
        RegionRec VPReg = void;
        BoxRec VPBox = void;

        VPBox.x1 = cast(short)(portPriv.pScrn.frameX0);
        VPBox.y1 = cast(short)(portPriv.pScrn.frameY0);
        VPBox.x2 = cast(short)(portPriv.pScrn.frameX1 + 1);
        VPBox.y2 = cast(short)(portPriv.pScrn.frameY1 + 1);

        RegionInit(&VPReg, &VPBox, 1);
        RegionIntersect(&ClipRegion, &ClipRegion, &VPReg);
        RegionUninit(&VPReg);
    }

    /* If we are changing windows, unregister our port in the old window */
    if (portPriv.pDraw && (portPriv.pDraw != pDraw))
        xf86XVRemovePortFromWindow(cast(WindowPtr) (portPriv.pDraw), portPriv);

    /* Register our port with the new window */
    ret = xf86XVEnlistPortInWindow(cast(WindowPtr) pDraw, portPriv);
    if (ret != Success)
        goto PUT_IMAGE_BAILOUT;

    if (!RegionNotEmpty(&ClipRegion)) {
        clippedAway = TRUE;
        goto PUT_IMAGE_BAILOUT;
    }

    ret = (*portPriv.AdaptorRec.PutImage) (portPriv.pScrn,
                                             src_x, src_y, WinBox.x1, WinBox.y1,
                                             src_w, src_h, drw_w, drw_h,
                                             format.id, data, width, height,
                                             sync, &ClipRegion,
                                             portPriv.DevPriv.ptr, pDraw);

    if ((ret == Success) &&
        (portPriv.AdaptorRec.flags & VIDEO_OVERLAID_IMAGES)) {

        portPriv.isOn = XV_ON;
        portPriv.vid_x = src_x;
        portPriv.vid_y = src_y;
        portPriv.vid_w = src_w;
        portPriv.vid_h = src_h;
        portPriv.drw_x = drw_x;
        portPriv.drw_y = drw_y;
        portPriv.drw_w = drw_w;
        portPriv.drw_h = drw_h;
        portPriv.type = 0;     /* no mask means it's transient and should
                                   not be reput once it's removed */
        pPort.pDraw = pDraw;   /* make sure we can get stop requests */
    }

 PUT_IMAGE_BAILOUT:

    if ((clippedAway || (ret != Success)) && (portPriv.isOn == XV_ON)) {
        (*portPriv.AdaptorRec.StopVideo) (portPriv.pScrn,
                                            portPriv.DevPriv.ptr, FALSE);
        portPriv.isOn = XV_PENDING;
    }

    /* This clip was copied and only good for one shot */
    if (!portPriv.FreeCompositeClip)
        portPriv.pCompositeClip = null;

    RegionUninit(&WinRegion);
    RegionUninit(&ClipRegion);

    return ret;
}

private int xf86XVQueryImageAttributes(XvPortPtr pPort, XvImagePtr format, CARD16* width, CARD16* height, int* pitches, int* offsets)
{
    XvPortRecPrivatePtr portPriv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    return (*portPriv.AdaptorRec.QueryImageAttributes) (portPriv.pScrn,
                                                          format.id, width,
                                                          height, pitches,
                                                          offsets);
}

void xf86XVFillKeyHelperDrawable(DrawablePtr pDraw, CARD32 key, RegionPtr fillboxes)
{
    ScreenPtr pScreen = pDraw.pScreen;

    if (!xf86ScreenToScrn(pScreen).vtSema)
        return;

    XvFillColorKey(pDraw, key, fillboxes);
}

void xf86XVFillKeyHelper(ScreenPtr pScreen, CARD32 key, RegionPtr fillboxes)
{
    xf86XVFillKeyHelperDrawable(&pScreen.root.drawable, key, fillboxes);
}

/* xf86XVClipVideoHelper -

   Takes the dst box in standard X BoxRec form (top and left
   edges inclusive, bottom and right exclusive).  The new dst
   box is returned.  The source boundaries are given (x1, y1
   inclusive, x2, y2 exclusive) and returned are the new source
   boundaries in 16.16 fixed point.
*/

Bool xf86XVClipVideoHelper(BoxPtr dst, INT32* xa, INT32* xb, INT32* ya, INT32* yb, RegionPtr reg, INT32 width, INT32 height)
{
    double xsw = void, xdw = void, ysw = void, ydw = void;
    INT32 delta = void;
    BoxPtr extents = RegionExtents(reg);
    int diff = void;

    xsw = (*xb - *xa) << 16;
    xdw = dst.x2 - dst.x1;
    ysw = (*yb - *ya) << 16;
    ydw = dst.y2 - dst.y1;

    *xa <<= 16;
    *xb <<= 16;
    *ya <<= 16;
    *yb <<= 16;

    diff = extents.x1 - dst.x1;
    if (diff > 0) {
        dst.x1 = extents.x1;
        *xa += (diff * xsw) / xdw;
    }
    diff = dst.x2 - extents.x2;
    if (diff > 0) {
        dst.x2 = extents.x2;
        *xb -= (diff * xsw) / xdw;
    }
    diff = extents.y1 - dst.y1;
    if (diff > 0) {
        dst.y1 = extents.y1;
        *ya += (diff * ysw) / ydw;
    }
    diff = dst.y2 - extents.y2;
    if (diff > 0) {
        dst.y2 = extents.y2;
        *yb -= (diff * ysw) / ydw;
    }

    if (*xa < 0) {
        diff = cast(int)((((-*xa) * xdw) + xsw - 1) / xsw);
        dst.x1 += diff;
        *xa += (diff * xsw) / xdw;
    }
    delta = *xb - (width << 16);
    if (delta > 0) {
        diff = cast(int)(((delta * xdw) + xsw - 1) / xsw);
        dst.x2 -= diff;
        *xb -= (diff * xsw) / xdw;
    }
    if (*xa >= *xb)
        return FALSE;

    if (*ya < 0) {
        diff = cast(int)((((-*ya) * ydw) + ysw - 1) / ysw);
        dst.y1 += diff;
        *ya += (diff * ysw) / ydw;
    }
    delta = *yb - (height << 16);
    if (delta > 0) {
        diff = cast(int)(((delta * ydw) + ysw - 1) / ysw);
        dst.y2 -= diff;
        *yb -= (diff * ysw) / ydw;
    }
    if (*ya >= *yb)
        return FALSE;

    if ((dst.x1 > extents.x1) || (dst.x2 < extents.x2) ||
        (dst.y1 > extents.y1) || (dst.y2 < extents.y2)) {
        RegionRec clipReg = void;

        RegionInit(&clipReg, dst, 1);
        RegionIntersect(reg, reg, &clipReg);
        RegionUninit(&clipReg);
    }
    return TRUE;
}

void xf86XVCopyYUV12ToPacked(const(void)* srcy, const(void)* srcv, const(void)* srcu, void* dst, int srcPitchy, int srcPitchuv, int dstPitch, int h, int w)
{
    CARD32* Dst = void;
    const(CARD8)* Y = void, U = void, V = void;
    int i = void, j = void;

    w >>= 1;

    for (j = 0; j < h; j++) {
        Dst = cast(uint*)dst;
        Y = cast(const(ubyte)*)srcy;
        V = cast(const(ubyte)*)srcv;
        U = cast(const(ubyte)*)srcu;
        i = w;
        while (i >= 4) {
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
            Dst[0] = Y[0] | (Y[1] << 16) | (U[0] << 8) | (V[0] << 24);
            Dst[1] = Y[2] | (Y[3] << 16) | (U[1] << 8) | (V[1] << 24);
            Dst[2] = Y[4] | (Y[5] << 16) | (U[2] << 8) | (V[2] << 24);
            Dst[3] = Y[6] | (Y[7] << 16) | (U[3] << 8) | (V[3] << 24);
} else {
            /* This assumes a little-endian framebuffer */
            Dst[0] = (Y[0] << 24) | (Y[1] << 8) | (U[0] << 16) | V[0];
            Dst[1] = (Y[2] << 24) | (Y[3] << 8) | (U[1] << 16) | V[1];
            Dst[2] = (Y[4] << 24) | (Y[5] << 8) | (U[2] << 16) | V[2];
            Dst[3] = (Y[6] << 24) | (Y[7] << 8) | (U[3] << 16) | V[3];
}
            Dst += 4;
            Y += 8;
            V += 4;
            U += 4;
            i -= 4;
        }

        while (i--) {
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
            Dst[0] = Y[0] | (Y[1] << 16) | (U[0] << 8) | (V[0] << 24);
} else {
            /* This assumes a little-endian framebuffer */
            Dst[0] = (Y[0] << 24) | (Y[1] << 8) | (U[0] << 16) | V[0];
}
            Dst++;
            Y += 2;
            V++;
            U++;
        }

        dst = cast(CARD8*) dst + dstPitch;
        srcy = cast(const(CARD8)*) srcy + srcPitchy;
        if (j & 1) {
            srcu = cast(const(CARD8)*) srcu + srcPitchuv;
            srcv = cast(const(CARD8)*) srcv + srcPitchuv;
        }
    }
}

void xf86XVCopyPacked(const(void)* src, void* dst, int srcPitch, int dstPitch, int h, int w)
{
    const(CARD32)* Src = void;
    CARD32* Dst = void;
    int i = void;

    w >>= 1;
    while (--h >= 0) {
        do {
            Dst = cast(uint*)dst;
            Src = cast(const(uint)*)src;
            i = w;
            while (i >= 4) {
                Dst[0] = Src[0];
                Dst[1] = Src[1];
                Dst[2] = Src[2];
                Dst[3] = Src[3];
                Dst += 4;
                Src += 4;
                i -= 4;
            }
            if (!i)
                break;
            Dst[0] = Src[0];
            if (i == 1)
                break;
            Dst[1] = Src[1];
            if (i == 2)
                break;
            Dst[2] = Src[2];
        } while (0);

        src = cast(const(CARD8)*) src + srcPitch;
        dst = cast(CARD8*) dst + dstPitch;
    }
}
