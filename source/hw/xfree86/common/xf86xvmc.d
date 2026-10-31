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

import include.misc;
import include.xf86;
import include.xf86_OSproc;;

//import x11.X;
//import x11.Xproto;

import dix.screen_hooks_priv;

import include.scrnintstr;
import include.resource;
import dix.dixstruct_priv;

import hw.xfree86.common.xf86xvpriv;
import include.xf86xvmc;
// import hw.xfree86.common.xf86sbusBus_priv;;
// import hw.xfree86.os_support.bus.xf86Sbus_priv;
import include.xf86sbusBus;
import externs.linux.fbio;
import xf86platformBus_priv;
import xf86Globals;
import hw.xfree86.common.xf86Xinput;
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
import Xext.xvmc;


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
