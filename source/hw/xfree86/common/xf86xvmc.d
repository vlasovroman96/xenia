module xf86xvmc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2001-2003 by The XFree86 Project, Inc.
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

import hw.xfree86.os_support.xf86_OSproc;;

//import x11.X;
//import x11.Xproto;

import dix.screen_hooks_priv;

import dix.scrnintstr;
import dix.dixstruct_priv;

import hw.xfree86.common.xf86xvpriv;
import xf86xvmc;
// import hw.xfree86.common.xf86sbusBus_priv;;
// import hw.xfree86.os_support.bus.xf86Sbus_priv;
// import xf86sbusBus;
import externs.linux.fbio;
import xf86platformBus_priv;
import xf86Globals;
import hw.xfree86.common.xf86Xinput;
import os.log;
import xf86pciBus;
import hw.xfree86.common.xf86Option;
import drm_platform;
import core.stdc.string;
import externs.gnu;
import hw.xfree86.common.xf86Helper;
import dix.events;
// import Sbus.c;
import os.log_priv;
import dix.screen_hooks;
import Xext.xvmain;
import externs.X11.extensions.Xv;
import dix.screen_hooks;
import dix.resource;
import Xext.xvmc;

public import common.xlibre_ptrtypes;
public import hw.xfree86.common.xvmcext;
public import xf86xv;

struct XF86MCImageIDList {
    int num_xvimages;
    int* xvimage_ids;           /* reference the subpictures in the XF86MCAdaptorRec */
}

struct _XF86MCSurfaceInfoRec {
    int surface_type_id;        /* Driver generated.  Must be unique on the port */
    int chroma_format;
    int color_description;      /* no longer used */
    ushort max_width;
    ushort max_height;
    ushort subpicture_max_width;
    ushort subpicture_max_height;
    int mc_type;
    int flags;
    XF86MCImageIDList* compatible_subpictures;  /* can be null, if none */
}alias XF86MCSurfaceInfoRec = _XF86MCSurfaceInfoRec;
alias XF86MCSurfaceInfoPtr = XF86MCSurfaceInfoRec*;

/*
   xf86XvMCCreateContextProc

   DIX will fill everything out in the context except the driver_priv.
   The port_priv holds the private data specified for the port when
   Xv was initialized by the driver.
   The driver may store whatever it wants in driver_priv and edit
   the width, height and flags.  If the driver wants to return something
   to the client it can allocate space in priv and specify the number
   of 32 bit words in num_priv.  This must be dynamically allocated
   space because DIX will free it after it passes it to the client.
*/

alias xf86XvMCCreateContextProcPtr = int function(ScrnInfoPtr pScrn, XvMCContextPtr context, int* num_priv, CARD32** priv);

alias xf86XvMCDestroyContextProcPtr = void function(ScrnInfoPtr pScrn, XvMCContextPtr context);

/*
   xf86XvMCCreateSurfaceProc

   DIX will fill everything out in the surface except the driver_priv.
   The driver may store whatever it wants in driver_priv.  The driver
   may pass data back to the client in the same manner as the
   xf86XvMCCreateContextProc.
*/

alias xf86XvMCCreateSurfaceProcPtr = int function(ScrnInfoPtr pScrn, XvMCSurfacePtr surface, int* num_priv, CARD32** priv);

alias xf86XvMCDestroySurfaceProcPtr = void function(ScrnInfoPtr pScrn, XvMCSurfacePtr surface);

/*
   xf86XvMCCreateSubpictureProc

   DIX will fill everything out in the subpicture except the driver_priv,
   num_palette_entries, entry_bytes and component_order.  The driver may
   store whatever it wants in driver_priv and edit the width and height.
   If it is a paletted subpicture the driver needs to fill out the
   num_palette_entries, entry_bytes and component_order.  These are
   not communicated to the client until the time the surface is
   created.

   The driver may pass data back to the client in the same manner as the
   xf86XvMCCreateContextProc.
*/

alias xf86XvMCCreateSubpictureProcPtr = int function(ScrnInfoPtr pScrn, XvMCSubpicturePtr subpicture, int* num_priv, CARD32** priv);

alias xf86XvMCDestroySubpictureProcPtr = void function(ScrnInfoPtr pScrn, XvMCSubpicturePtr subpicture);

struct _XF86MCAdaptorRec {
    const(char)* name;
    int num_surfaces;
    XF86MCSurfaceInfoPtr* surfaces;
    int num_subpictures;
    XF86ImagePtr* subpictures;
    xf86XvMCCreateContextProcPtr CreateContext;
    xf86XvMCDestroyContextProcPtr DestroyContext;
    xf86XvMCCreateSurfaceProcPtr CreateSurface;
    xf86XvMCDestroySurfaceProcPtr DestroySurface;
    xf86XvMCCreateSubpictureProcPtr CreateSubpicture;
    xf86XvMCDestroySubpictureProcPtr DestroySubpicture;
}alias XF86MCAdaptorRec = _XF86MCAdaptorRec;
alias XF86MCAdaptorPtr = XF86MCAdaptorRec*;

/*
   xf86XvMCScreenInit

   Unlike Xv, the adaptor data is not copied from this structure.
   This structure's data is used so it must stick around for the
   life of the server.  Note that it's an array of pointers not
   an array of structures.
*/

void  xf86XvMCScreenInit(ScreenPtr pScreen, int num_adaptors, XF86MCAdaptorPtr* adaptors);

XF86MCAdaptorPtr xf86XvMCCreateAdaptorRec();
void  xf86XvMCDestroyAdaptorRec(XF86MCAdaptorPtr adaptor);

                          /* _XF86XVMC_H */


struct _Xf86XvMCScreenRec {
    int num_adaptors;
    XF86MCAdaptorPtr* adaptors;
    XvMCAdaptorPtr dixinfo;
}alias xf86XvMCScreenRec = _Xf86XvMCScreenRec;
alias xf86XvMCScreenPtr = xf86XvMCScreenRec*;

private DevPrivateKeyRec XF86XvMCScreenKeyRec;

enum XF86XvMCScreenKey = (&XF86XvMCScreenKeyRec);

enum string XF86XVMC_GET_PRIVATE(string pScreen) = `cast(xf86XvMCScreenPtr) 
    dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, XF86XvMCScreenKey)`;

private int xf86XvMCCreateContext(XvPortPtr pPort, XvMCContextPtr pContext, int* num_priv, CARD32** priv)
{
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    pContext.port_priv = cast(XvPortRecPrivatePtr) (pPort.devPriv.ptr);

    return (*pScreenPriv.adaptors[pContext.adapt_num].CreateContext) (pScrn,
                                                                         pContext,
                                                                         num_priv,
                                                                         priv);
}

private void xf86XvMCDestroyContext(XvMCContextPtr pContext)
{
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    (*pScreenPriv.adaptors[pContext.adapt_num].DestroyContext) (pScrn,
                                                                   pContext);
}

private int xf86XvMCCreateSurface(XvMCSurfacePtr pSurface, int* num_priv, CARD32** priv)
{
    XvMCContextPtr pContext = pSurface.context;
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    return (*pScreenPriv.adaptors[pContext.adapt_num].CreateSurface) (pScrn,
                                                                         pSurface,
                                                                         num_priv,
                                                                         priv);
}

private void xf86XvMCDestroySurface(XvMCSurfacePtr pSurface)
{
    XvMCContextPtr pContext = pSurface.context;
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    (*pScreenPriv.adaptors[pContext.adapt_num].DestroySurface) (pScrn,
                                                                   pSurface);
}

private int xf86XvMCCreateSubpicture(XvMCSubpicturePtr pSubpicture, int* num_priv, CARD32** priv)
{
    XvMCContextPtr pContext = pSubpicture.context;
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    return (*pScreenPriv.adaptors[pContext.adapt_num].
            CreateSubpicture) (pScrn, pSubpicture, num_priv, priv);
}

private void xf86XvMCDestroySubpicture(XvMCSubpicturePtr pSubpicture)
{
    XvMCContextPtr pContext = pSubpicture.context;
    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pContext.pScreen`));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pContext.pScreen);

    (*pScreenPriv.adaptors[pContext.adapt_num].DestroySubpicture) (pScrn,
                                                                      pSubpicture);
}

private void xf86XvMCCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookClose(pScreen, &xf86XvMCCloseScreen);

    xf86XvMCScreenPtr pScreenPriv = mixin(XF86XVMC_GET_PRIVATE!(`pScreen`));
    if (!pScreenPriv)
        return;

    free(pScreenPriv.dixinfo);
    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, XF86XvMCScreenKey, null);
}

Bool xf86XvMCScreenInit(ScreenPtr pScreen, int num_adaptors, XF86MCAdaptorPtr* adaptors)
{
    XvMCAdaptorPtr pAdapt = void;
    xf86XvMCScreenPtr pScreenPriv = void;
    XvScreenPtr pxvs = cast(XvScreenPtr)dixLookupPrivate(&pScreen.devPrivates, XvGetScreenKey());
    int i = void, j = void;

    if (noXvExtension)
        return FALSE;

    if (((pAdapt = cast(XvMCAdaptorRec*)calloc(num_adaptors, XvMCAdaptorRec.sizeof)) is null))
        return FALSE;

    if (!dixRegisterPrivateKey(&XF86XvMCScreenKeyRec, PRIVATE_SCREEN, 0)) {
        free(pAdapt);
        return FALSE;
    }

    if (((pScreenPriv = cast(xf86XvMCScreenRec*) calloc(1, xf86XvMCScreenRec.sizeof)) is null)) {
        free(pAdapt);
        return FALSE;
    }

    dixSetPrivate(&pScreen.devPrivates, XF86XvMCScreenKey, pScreenPriv);
    dixScreenHookClose(pScreen, &xf86XvMCCloseScreen);

    pScreenPriv.num_adaptors = num_adaptors;
    pScreenPriv.adaptors = adaptors;
    pScreenPriv.dixinfo = pAdapt;

    for (i = 0; i < num_adaptors; i++) {
        pAdapt[i].xv_adaptor = null;
        for (j = 0; j < pxvs.nAdaptors; j++) {
            if (!strcmp((*adaptors).name, pxvs.pAdaptors[j].name)) {
                pAdapt[i].xv_adaptor = &(pxvs.pAdaptors[j]);
                break;
            }
        }
        if (!pAdapt[i].xv_adaptor) {
            /* no adaptor by that name */
            pScreenPriv.dixinfo = null;
            free(pAdapt);
            return FALSE;
        }
        pAdapt[i].num_surfaces = (*adaptors).num_surfaces;
        pAdapt[i].surfaces = cast(XvMCSurfaceInfoPtr*) ((*adaptors).surfaces);
        pAdapt[i].num_subpictures = (*adaptors).num_subpictures;
        pAdapt[i].subpictures = cast(XvImagePtr*) ((*adaptors).subpictures);
        pAdapt[i].CreateContext = &xf86XvMCCreateContext;
        pAdapt[i].DestroyContext = &xf86XvMCDestroyContext;
        pAdapt[i].CreateSurface = &xf86XvMCCreateSurface;
        pAdapt[i].DestroySurface = &xf86XvMCDestroySurface;
        pAdapt[i].CreateSubpicture = &xf86XvMCCreateSubpicture;
        pAdapt[i].DestroySubpicture = &xf86XvMCDestroySubpicture;
        adaptors++;
    }

    if (Success != XvMCScreenInit(pScreen, num_adaptors, pAdapt))
        return FALSE;

    return TRUE;
}

XF86MCAdaptorPtr xf86XvMCCreateAdaptorRec()
{
    return cast(XF86MCAdaptorRec*) calloc(1, XF86MCAdaptorRec.sizeof);
}

void xf86XvMCDestroyAdaptorRec(XF86MCAdaptorPtr adaptor)
{
    free(adaptor);
}
