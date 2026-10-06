module xf86DGA;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 1995  Jon Tombs
 * Copyright (c) 1995, 1996, 1999  XFree86 Inc
 * Copyright (c) 1998-2002 by The XFree86 Project, Inc.
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
 *
 * Written by Mark Vojkovich
 */

/*
 * This is quite literally just two files glued together:
 * hw/xfree86/common/xf86DGA.c is the first part, and
 * hw/xfree86/dixmods/extmod/xf86dga2.c is the second part.  One day, if
 * someone actually cares about DGA, it'd be nice to clean this up.  But trust
 * me, I am not that person.
 */
import build.xlibre_server;
import Xext.panoramiXsrv;

import core.stdc.string;
//import x11.X;
//import x11.Xproto;
import externs.X11.extensions.xf86dgaproto;

import dix.colormap_priv;
import dix.dix_priv;
import dix.eventconvert;
import dix.exevents_priv;
import dix.request_priv;
import dix.screen_hooks_priv;
import include.extinit;
import mi.mi_priv;

import include.xf86;
import include.xf86str;
import include.xf86Priv;
import include.dgaproc;
import hw.xfree86.common.dgaproc_priv;
import include.pixmapstr;
import include.inputstr;
import include.globals;
import include.servermd;
import mi.micmap;
import include.xkbsrv;
// import xf86Xinput;
import include.eventstr;
import xf86Extensions;
import include.misc;
import include.dixstruct;
import include.extnsionst;
import include.cursor;
import include.scrnintstr;
import dix.swaprep;
import include.dgaproc;
import include.protocol_versions;
import include.events;
import hw.xfree86.common.xf86Helper;
import xf86Globals;
import dix.events;
import os.log;
import dix.colormap;
import os.utils;
import dix.devices;
import dix.extension;
import dix.screen_hooks;
import include.xkbstr;
import include.eventstr;

DevPrivateKeyRec DGAScreenKeyRec;

// @property bool DGAScreenKeyRegistered()
// {
//     return dixPrivateKeyRegistered(&DGAScreenKeyRec);
// }









private ubyte DGAReqCode = 0;
private int DGAErrorBase;
private int DGAEventBase;

enum string DGA_GET_SCREEN_PRIV(string pScreen) = `(cast(DGAScreenPtr) 
    dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, &DGAScreenKeyRec))`;

struct _FakedVisualList {
    Bool free;
    VisualPtr pVisual;
    _FakedVisualList* next;
}

alias FakedVisualList = _FakedVisualList;

struct _DGAScreenRec {
    ScrnInfoPtr pScrn;
    int numModes;
    DGAModePtr modes;
    DestroyColormapProcPtr DestroyColormap;
    InstallColormapProcPtr InstallColormap;
    UninstallColormapProcPtr UninstallColormap;
    DGADevicePtr current;
    DGAFunctionPtr funcs;
    int input;
    ClientPtr client;
    int pixmapMode;
    FakedVisualList* fakedVisuals;
    ColormapPtr dgaColormap;
    ColormapPtr savedColormap;
    Bool grabMouse;
    Bool grabKeyboard;
}alias DGAScreenRec = _DGAScreenRec;
alias DGAScreenPtr = DGAScreenRec*;

Bool DGAInit(ScreenPtr pScreen, DGAFunctionPtr funcs, DGAModePtr modes, int num)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    DGAScreenPtr pScreenPriv = void;
    int i = void;

    if (!funcs || !funcs.SetMode || !funcs.OpenFramebuffer)
        return FALSE;

    if (!modes || num <= 0)
        return FALSE;

    if (!dixRegisterPrivateKey(&DGAScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    if (!pScreenPriv) {
        if (((pScreenPriv = cast(DGAScreenRec*) calloc(1, DGAScreenRec.sizeof)) is null))
            return FALSE;
        dixSetPrivate(&pScreen.devPrivates, &DGAScreenKeyRec, pScreenPriv);
        dixScreenHookClose(pScreen, &DGACloseScreen);
        pScreenPriv.DestroyColormap = pScreen.DestroyColormap;
        pScreen.DestroyColormap = &DGADestroyColormap;
        pScreenPriv.InstallColormap = pScreen.InstallColormap;
        pScreen.InstallColormap = &DGAInstallColormap;
        pScreenPriv.UninstallColormap = pScreen.UninstallColormap;
        pScreen.UninstallColormap = &DGAUninstallColormap;
    }

    pScreenPriv.pScrn = pScrn;
    pScreenPriv.numModes = num;
    pScreenPriv.modes = modes;
    pScreenPriv.current = null;

    pScreenPriv.funcs = funcs;
    pScreenPriv.input = 0;
    pScreenPriv.client = null;
    pScreenPriv.fakedVisuals = null;
    pScreenPriv.dgaColormap = null;
    pScreenPriv.savedColormap = null;
    pScreenPriv.grabMouse = FALSE;
    pScreenPriv.grabKeyboard = FALSE;

    for (i = 0; i < num; i++)
        modes[i].num = i + 1;

static if(XINERAMA){
    if (!noPanoramiXExtension)
        for (i = 0; i < num; i++)
            modes[i].flags &= ~DGA_PIXMAP_AVAILABLE;
} /* XINERAMA */

    return TRUE;
}

/* DGAReInitModes allows the driver to re-initialize
 * the DGA mode list.
 */

Bool DGAReInitModes(ScreenPtr pScreen, DGAModePtr modes, int num)
{
    DGAScreenPtr pScreenPriv = void;
    int i = void;

    /* No DGA? Ignore call (but don't make it look like it failed) */
    if (!DGAScreenKeyRegistered)
        return TRUE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    /* Same as above */
    if (!pScreenPriv)
        return TRUE;

    /* Can't do this while DGA is active */
    if (pScreenPriv.current)
        return FALSE;

    /* Quick sanity check */
    if (!num)
        modes = null;
    else if (!modes)
        num = 0;

    pScreenPriv.numModes = num;
    pScreenPriv.modes = modes;

    /* This practically disables DGA. So be it. */
    if (!num)
        return TRUE;

    for (i = 0; i < num; i++)
        modes[i].num = i + 1;

static if(XINERAMA){
    if (!noPanoramiXExtension)
        for (i = 0; i < num; i++)
            modes[i].flags &= ~DGA_PIXMAP_AVAILABLE;
} /* XINERAMA */

    return TRUE;
}

private void FreeMarkedVisuals(ScreenPtr pScreen)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    FakedVisualList* prev = void, curr = void, tmp = void;

    if (!pScreenPriv.fakedVisuals)
        return;

    prev = null;
    curr = pScreenPriv.fakedVisuals;

    while (curr) {
        if (curr.free) {
            tmp = curr;
            curr = curr.next;
            if (prev)
                prev.next = curr;
            else
                pScreenPriv.fakedVisuals = curr;
            free(tmp.pVisual);
            free(tmp);
        }
        else {
            prev = curr;
            curr = curr.next;
        }
    }
}

private void DGACloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    if (!pScreenPriv)
        return;

    mieqSetHandler(ET_DGAEvent, null);
    pScreenPriv.pScrn.SetDGAMode(pScreenPriv.pScrn, 0, null);
    FreeMarkedVisuals(pScreen);

    dixScreenUnhookClose(pScreen, &DGACloseScreen);
    pScreen.DestroyColormap = pScreenPriv.DestroyColormap;
    pScreen.InstallColormap = pScreenPriv.InstallColormap;
    pScreen.UninstallColormap = pScreenPriv.UninstallColormap;

    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &DGAScreenKeyRec, null);
}

private void DGADestroyColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    VisualPtr pVisual = pmap.pVisual;

    if (pScreenPriv.fakedVisuals) {
        FakedVisualList* curr = pScreenPriv.fakedVisuals;

        while (curr) {
            if (curr.pVisual == pVisual) {
                /* We can't get rid of them yet since FreeColormap
                   still needs the pVisual during the cleanup */
                curr.free = TRUE;
                break;
            }
            curr = curr.next;
        }
    }

    if (pScreenPriv.DestroyColormap) {
        pScreen.DestroyColormap = pScreenPriv.DestroyColormap;
        (*pScreen.DestroyColormap) (pmap);
        pScreen.DestroyColormap = &DGADestroyColormap;
    }
}

private void DGAInstallColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    if (pScreenPriv.current && pScreenPriv.dgaColormap) {
        if (pmap != pScreenPriv.dgaColormap) {
            pScreenPriv.savedColormap = pmap;
            pmap = pScreenPriv.dgaColormap;
        }
    }

    pScreen.InstallColormap = pScreenPriv.InstallColormap;
    (*pScreen.InstallColormap) (pmap);
    pScreen.InstallColormap = &DGAInstallColormap;
}

private void DGAUninstallColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    if (pScreenPriv.current && pScreenPriv.dgaColormap) {
        if (pmap == pScreenPriv.dgaColormap) {
            pScreenPriv.dgaColormap = null;
        }
    }

    pScreen.UninstallColormap = pScreenPriv.UninstallColormap;
    (*pScreen.UninstallColormap) (pmap);
    pScreen.UninstallColormap = &DGAUninstallColormap;
}

int xf86SetDGAMode(ScrnInfoPtr pScrn, int num, DGADevicePtr devRet)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    DGAScreenPtr pScreenPriv = void;
    DGADevicePtr device = void;
    PixmapPtr pPix = null;
    DGAModePtr pMode = null;

    /* First check if DGAInit was successful on this screen */
    if (!DGAScreenKeyRegistered)
        return BadValue;
    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    if (!pScreenPriv)
        return BadValue;

    if (!num) {
        if (pScreenPriv.current) {
            PixmapPtr oldPix = pScreenPriv.current.pPix;

            if (oldPix) {
                if (oldPix.drawable.id)
                    FreeResource(cast(uint)oldPix.drawable.id, X11_RESTYPE_NONE);
                else
                    dixDestroyPixmap(oldPix, 0);
            }
            free(pScreenPriv.current);
            pScreenPriv.current = null;
            pScrn.vtSema = TRUE;
            (*pScreenPriv.funcs.SetMode) (pScrn, null);
            if (pScreenPriv.savedColormap) {
                (*pScreen.InstallColormap) (pScreenPriv.savedColormap);
                pScreenPriv.savedColormap = null;
            }
            pScreenPriv.dgaColormap = null;
            (*pScrn.EnableDisableFBAccess) (pScrn, TRUE);

            FreeMarkedVisuals(pScreen);
        }

        pScreenPriv.grabMouse = FALSE;
        pScreenPriv.grabKeyboard = FALSE;

        return Success;
    }

    if (!pScrn.vtSema && !pScreenPriv.current)        /* Really switched away */
        return BadAlloc;

    if ((num > 0) && (num <= pScreenPriv.numModes))
        pMode = &(pScreenPriv.modes[num - 1]);
    else
        return BadValue;

    if (((device = cast(DGADeviceRec*) calloc(1, DGADeviceRec.sizeof)) is null))
        return BadAlloc;

    if (!pScreenPriv.current) {
        Bool oldVTSema = pScrn.vtSema;

        pScrn.vtSema = FALSE;  /* kludge until we rewrite VT switching */
        (*pScrn.EnableDisableFBAccess) (pScrn, FALSE);
        pScrn.vtSema = oldVTSema;
    }

    if (!(*pScreenPriv.funcs.SetMode) (pScrn, pMode)) {
        free(device);
        return BadAlloc;
    }

    pScrn.currentMode = pMode.mode;

    if (!pScreenPriv.current && !pScreenPriv.input) {
        /* if it's multihead we need to warp the cursor off of
           our screen so it doesn't get trapped  */
    }

    pScrn.vtSema = FALSE;

    if (pScreenPriv.current) {
        PixmapPtr oldPix = pScreenPriv.current.pPix;

        if (oldPix) {
            if (oldPix.drawable.id)
                FreeResource(cast(uint)oldPix.drawable.id, X11_RESTYPE_NONE);
            else
                dixDestroyPixmap(oldPix, 0);
        }
        free(pScreenPriv.current);
        pScreenPriv.current = null;
    }

    if (pMode.flags & DGA_PIXMAP_AVAILABLE) {
        if ((pPix = (*pScreen.CreatePixmap) (pScreen, 0, 0, pMode.depth, 0)) !is null) {
            (*pScreen.ModifyPixmapHeader) (pPix,
                                            pMode.pixmapWidth,
                                            pMode.pixmapHeight, pMode.depth,
                                            pMode.bitsPerPixel,
                                            pMode.bytesPerScanline,
                                            cast(void*) (pMode.address));
        }
    }

    devRet.mode = device.mode = pMode;
    devRet.pPix = device.pPix = pPix;
    pScreenPriv.current = device;
    pScreenPriv.pixmapMode = FALSE;
    pScreenPriv.grabMouse = TRUE;
    pScreenPriv.grabKeyboard = TRUE;

    mieqSetHandler(ET_DGAEvent, &DGAHandleEvent);

    return Success;
}

private Bool DGAChangePixmapMode(int index, int* x, int* y, int mode)
{
    DGAScreenPtr pScreenPriv = void;
    DGADevicePtr pDev = void;
    DGAModePtr pMode = void;
    PixmapPtr pPix = void;

    if (!DGAScreenKeyRegistered)
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (!pScreenPriv || !pScreenPriv.current || !pScreenPriv.current.pPix)
        return FALSE;

    pDev = pScreenPriv.current;
    pPix = pDev.pPix;
    pMode = pDev.mode;

    if (mode) {
        int shift = 2;

        if (*x > (pMode.pixmapWidth - pMode.viewportWidth))
            *x = pMode.pixmapWidth - pMode.viewportWidth;
        if (*y > (pMode.pixmapHeight - pMode.viewportHeight))
            *y = pMode.pixmapHeight - pMode.viewportHeight;

        switch (xf86Screens[index].bitsPerPixel) {
        case 16:
            shift = 1;
            break;
        case 32:
            shift = 0;
            break;
        default:
            break;
        }

        if (BITMAP_SCANLINE_PAD == 64)
            shift++;

        *x = (*x >> shift) << shift;

        pPix.drawable.x = cast(short)*x;
        pPix.drawable.y = cast(short)*y;
        pPix.drawable.width = cast(ushort)pMode.viewportWidth;
        pPix.drawable.height = cast(ushort)pMode.viewportHeight;
    }
    else {
        pPix.drawable.x = cast(short)0;
        pPix.drawable.y = cast(short)0;
        pPix.drawable.width = cast(short)pMode.pixmapWidth;
        pPix.drawable.height = cast(short)pMode.pixmapHeight;
    }
    pPix.drawable.serialNumber = NEXT_SERIAL_NUMBER;
    pScreenPriv.pixmapMode = mode;

    return TRUE;
}

Bool DGAScreenAvailable(ScreenPtr pScreen)
{
    if (!DGAScreenKeyRegistered)
        return FALSE;

    if (mixin(DGA_GET_SCREEN_PRIV!(`pScreen`)))
        return TRUE;
    return FALSE;
}

private Bool DGAAvailable(int index)
{
    ScreenPtr pScreen = void;

    assert(index < MAXSCREENS);
    pScreen = screenInfo.screens[index];
    return DGAScreenAvailable(pScreen);
}

Bool DGAActive(int index)
{
    DGAScreenPtr pScreenPriv = void;

    if (!DGAScreenKeyRegistered)
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (pScreenPriv && pScreenPriv.current)
        return TRUE;

    return FALSE;
}

/* Called by the extension to initialize a mode */

private int DGASetMode(int index, int num, XDGAModePtr mode, PixmapPtr* pPix)
{
    ScrnInfoPtr pScrn = xf86Screens[index];
    DGADeviceRec device = void;
    int ret = void;

    /* We rely on the extension to check that DGA is available */

    ret = (*pScrn.SetDGAMode) (pScrn, num, &device);
    if ((ret == Success) && num) {
        DGACopyModeInfo(device.mode, mode);
        *pPix = device.pPix;
    }

    return ret;
}

/* Called from the extension to let the DDX know which events are requested */

private void DGASelectInput(int index, ClientPtr client, c_long mask)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is available */
    pScreenPriv.client = client;
    pScreenPriv.input = cast(int)mask;
}

private int DGAGetViewportStatus(int index)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is active */

    if (!pScreenPriv.funcs.GetViewport)
        return 0;

    return (*pScreenPriv.funcs.GetViewport) (pScreenPriv.pScrn);
}

private int DGASetViewport(int index, int x, int y, int mode)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (pScreenPriv.funcs.SetViewport)
        (*pScreenPriv.funcs.SetViewport) (pScreenPriv.pScrn, x, y, mode);
    return Success;
}

private int BitsClear(CARD32 data)
{
    int bits = 0;
    CARD32 mask = void;

    for (mask = 1; mask; mask <<= 1) {
        if (!(data & mask))
            bits++;
        else
            break;
    }

    return bits;
}

private int DGACreateColormap(int index, ClientPtr client, int id, int mode, int alloc)
{
    ScreenPtr pScreen = screenInfo.screens[index];
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    FakedVisualList* fvlp = void;
    VisualPtr pVisual = void;
    DGAModePtr pMode = void;
    ColormapPtr pmap = void;

    if (!mode || (mode > pScreenPriv.numModes))
        return BadValue;

    if ((alloc != AllocNone) && (alloc != AllocAll))
        return BadValue;

    pMode = &(pScreenPriv.modes[mode - 1]);

    if (((pVisual = cast(VisualRec*) calloc(1, VisualRec.sizeof)) is null))
        return BadAlloc;

    pVisual.vid = dixAllocServerXID();
    pVisual.class_ = pMode.visualClass;
    pVisual.nplanes = cast(short)(pMode.depth);
    pVisual.ColormapEntries = cast(short)(1 << pMode.depth);
    pVisual.bitsPerRGBValue = cast(short)((pMode.depth + 2) / 3);

    switch (pVisual.class_) {
    case PseudoColor:
    case GrayScale:
    case StaticGray:
        pVisual.bitsPerRGBValue = 8;   /* not quite */
        pVisual.redMask = 0;
        pVisual.greenMask = 0;
        pVisual.blueMask = 0;
        pVisual.offsetRed = 0;
        pVisual.offsetGreen = 0;
        pVisual.offsetBlue = 0;
        break;
    case DirectColor:
    case TrueColor:
        pVisual.ColormapEntries = cast(short)(1 << pVisual.bitsPerRGBValue);
        /* fall through */
    goto case StaticColor;
    case StaticColor:
        pVisual.redMask = pMode.red_mask;
        pVisual.greenMask = pMode.green_mask;
        pVisual.blueMask = pMode.blue_mask;
        pVisual.offsetRed = BitsClear(cast(uint)pVisual.redMask);
        pVisual.offsetGreen = BitsClear(cast(uint)pVisual.greenMask);
        pVisual.offsetBlue = BitsClear(cast(uint)pVisual.blueMask);
        goto default;
    default: break;}

    if (((fvlp = cast(FakedVisualList*) cast(FakedVisualList*) calloc(1, FakedVisualList.sizeof)) is null)) {
        free(pVisual);
        return BadAlloc;
    }

    fvlp.free = FALSE;
    fvlp.pVisual = pVisual;
    fvlp.next = pScreenPriv.fakedVisuals;
    pScreenPriv.fakedVisuals = fvlp;

    mixin(LEGAL_NEW_RESOURCE!("id", "client"));

    return dixCreateColormap(id, pScreen, pVisual, &pmap, alloc, client);
}

/*  Called by the extension to install a colormap on DGA active screens */

private void DGAInstallCmap(ColormapPtr cmap)
{
    ScreenPtr pScreen = cmap.pScreen;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    /* We rely on the extension to check that DGA is active */

    if (!pScreenPriv.dgaColormap)
        pScreenPriv.savedColormap = GetInstalledmiColormap(pScreen);

    pScreenPriv.dgaColormap = cmap;

    (*pScreen.InstallColormap) (cmap);
}

private int DGASync(int index)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is active */

    if (pScreenPriv.funcs.Sync)
        (*pScreenPriv.funcs.Sync) (pScreenPriv.pScrn);

    return Success;
}

private int DGAFillRect(int index, int x, int y, int w, int h, c_ulong color)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is active */

    if (pScreenPriv.funcs.FillRect &&
        (pScreenPriv.current.mode.flags & DGA_FILL_RECT)) {

        (*pScreenPriv.funcs.FillRect) (pScreenPriv.pScrn, x, y, w, h, color);
        return Success;
    }
    return BadMatch;
}

private int DGABlitRect(int index, int srcx, int srcy, int w, int h, int dstx, int dsty)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is active */

    if (pScreenPriv.funcs.BlitRect &&
        (pScreenPriv.current.mode.flags & DGA_BLIT_RECT)) {

        (*pScreenPriv.funcs.BlitRect) (pScreenPriv.pScrn,
                                         srcx, srcy, w, h, dstx, dsty);
        return Success;
    }
    return BadMatch;
}

private int DGABlitTransRect(int index, int srcx, int srcy, int w, int h, int dstx, int dsty, c_ulong color)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is active */

    if (pScreenPriv.funcs.BlitTransRect &&
        (pScreenPriv.current.mode.flags & DGA_BLIT_RECT_TRANS)) {

        (*pScreenPriv.funcs.BlitTransRect) (pScreenPriv.pScrn,
                                              srcx, srcy, w, h, dstx, dsty,
                                              color);
        return Success;
    }
    return BadMatch;
}

private int DGAGetModes(int index)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is available */

    return pScreenPriv.numModes;
}

private int DGAGetModeInfo(int index, XDGAModePtr mode, int num)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is available */

    if ((num <= 0) || (num > pScreenPriv.numModes))
        return BadValue;

    DGACopyModeInfo(&(pScreenPriv.modes[num - 1]), mode);

    return Success;
}

private void DGACopyModeInfo(DGAModePtr mode, XDGAModePtr xmode)
{
    DisplayModePtr dmode = mode.mode;

    xmode.num = mode.num;
    xmode.name = dmode.name;
    xmode.VSync_num = cast(int) (dmode.VRefresh * 1000.0);
    xmode.VSync_den = 1000;
    xmode.flags = mode.flags;
    xmode.imageWidth = mode.imageWidth;
    xmode.imageHeight = mode.imageHeight;
    xmode.pixmapWidth = mode.pixmapWidth;
    xmode.pixmapHeight = mode.pixmapHeight;
    xmode.bytesPerScanline = mode.bytesPerScanline;
    xmode.byteOrder = mode.byteOrder;
    xmode.depth = mode.depth;
    xmode.bitsPerPixel = mode.bitsPerPixel;
    xmode.red_mask = mode.red_mask;
    xmode.green_mask = mode.green_mask;
    xmode.blue_mask = mode.blue_mask;
    xmode.visualClass = mode.visualClass;
    xmode.viewportWidth = mode.viewportWidth;
    xmode.viewportHeight = mode.viewportHeight;
    xmode.xViewportStep = mode.xViewportStep;
    xmode.yViewportStep = mode.yViewportStep;
    xmode.maxViewportX = mode.maxViewportX;
    xmode.maxViewportY = mode.maxViewportY;
    xmode.viewportFlags = mode.viewportFlags;
    xmode.reserved1 = mode.reserved1;
    xmode.reserved2 = mode.reserved2;
    xmode.offset = mode.offset;

    if (dmode.Flags & V_INTERLACE)
        xmode.flags |= DGA_INTERLACED;
    if (dmode.Flags & V_DBLSCAN)
        xmode.flags |= DGA_DOUBLESCAN;
}

Bool DGAVTSwitch()
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        /* Alternatively, this could send events to DGA clients */

        if (DGAScreenKeyRegistered) {
            DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`walkScreen`));
            if (pScreenPriv && pScreenPriv.current)
                return FALSE;
        }
    });

    return TRUE;
}

Bool DGAStealKeyEvent(DeviceIntPtr dev, int index, int key_code, int is_down)
{
    DGAScreenPtr pScreenPriv = void;
    DGAEvent event = void;

    if (!DGAScreenKeyRegistered)        /* no DGA */
        return FALSE;

    if (key_code < 8 || key_code > 255)
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (!pScreenPriv || !pScreenPriv.grabKeyboard)     /* no direct mode */
        return FALSE;

    event = DGAEvent (
        header: ET_Internal,
        type: ET_DGAEvent,
        length: event.sizeof,
        time: GetTimeInMillis(),
        subtype: (is_down ? ET_KeyPress : ET_KeyRelease),
        detail: key_code,
        dx: 0,
        dy: 0
    );
    mieqEnqueue(dev, cast(InternalEvent*) &event);

    return TRUE;
}

Bool DGAStealMotionEvent(DeviceIntPtr dev, int index, int dx, int dy)
{
    DGAScreenPtr pScreenPriv = void;
    DGAEvent event = void;

    if (!DGAScreenKeyRegistered)        /* no DGA */
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (!pScreenPriv || !pScreenPriv.grabMouse)        /* no direct mode */
        return FALSE;

    event = DGAEvent (
        header: ET_Internal,
        type: ET_DGAEvent,
        length: event.sizeof,
        time: GetTimeInMillis(),
        subtype: ET_Motion,
        detail: 0,
        dx: dx,
        dy: dy
    );
    mieqEnqueue(dev, cast(InternalEvent*) &event);
    return TRUE;
}

Bool DGAStealButtonEvent(DeviceIntPtr dev, int index, int button, int is_down)
{
    DGAScreenPtr pScreenPriv = void;
    DGAEvent event = void;

    if (!DGAScreenKeyRegistered)        /* no DGA */
        return FALSE;

    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    if (!pScreenPriv || !pScreenPriv.grabMouse)
        return FALSE;

    event = DGAEvent (
        header: ET_Internal,
        type: ET_DGAEvent,
        length: event.sizeof,
        time: GetTimeInMillis(),
        subtype: (is_down ? ET_ButtonPress : ET_ButtonRelease),
        detail: button,
        dx: 0,
        dy: 0
    );
    mieqEnqueue(dev, cast(InternalEvent*) &event);

    return TRUE;
}

/* We have the power to steal or modify events that are about to get queued */

enum NoSuchEvent = 0x80000000  /* so doesn't match NoEventMask */;
private Mask[8] filters = [
    NoSuchEvent,                /* 0 */
    NoSuchEvent,                /* 1 */
    KeyPressMask,               /* KeyPress */
    KeyReleaseMask,             /* KeyRelease */
    ButtonPressMask,            /* ButtonPress */
    ButtonReleaseMask,          /* ButtonRelease */
    PointerMotionMask,          /* MotionNotify (initial state) */
];
private void DGAProcessKeyboardEvent(ScreenPtr pScreen, _DGAEvent* event, DeviceIntPtr keybd)
{
    KeyClassPtr keyc = keybd.key;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    DeviceIntPtr pointer = GetMaster(keybd, POINTER_OR_FLOAT);
    DeviceEvent ev = {
        header: ET_Internal,
        length: DeviceEvent.sizeof,
        type: cast(EventType)event.subtype,
        root_x: 0,
        root_y: 0,
        corestate: mixin(XkbStateFieldFromRec!("&keyc.xkbInfo.state"))
    };
    ev.detail.key = event.detail,

    ev.corestate |= pointer.button.state;

    UpdateDeviceState(keybd, &ev);

    if (!InputDevIsMaster(keybd))
        return;

    /*
     * Deliver the DGA event
     */
    if (pScreenPriv.client) {
        dgaEvent de = {
        };
            de.u.event.time = cast(uint)event.time,
            de.u.event.dx = cast(short)event.dx,
            de.u.event.dy = cast(short)event.dy,
            de.u.event.screen = cast(short)pScreen.myNum,
            de.u.event.state = cast(ushort)ev.corestate;
        de.u.u.type = cast(ubyte)(DGAEventBase + GetCoreType(ev.type));
        de.u.u.detail = cast(ubyte)event.detail;

        /* If the DGA client has selected input, then deliver based on the usual filter */
        TryClientEvents(pScreenPriv.client, keybd, cast(xEvent*) &de, 1,
                        filters[ev.type], pScreenPriv.input, null);
    }
    else {
        /* If the keyboard is actively grabbed, deliver a grabbed core event */
        if (keybd.deviceGrab.grab && !keybd.deviceGrab.fromPassiveGrab) {
            ev.detail.key = event.detail;
            ev.time = event.time;
            ev.root_x = cast(short)event.dx;
            ev.root_y = cast(short)event.dy;
            ev.corestate = event.state;
            ev.deviceid = keybd.id;
            DeliverGrabbedEvent(cast(InternalEvent*) &ev, keybd, FALSE);
        }
    }
}

private void DGAProcessPointerEvent(ScreenPtr pScreen, _DGAEvent* event, DeviceIntPtr mouse)
{
    ButtonClassPtr butc = mouse.button;
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));
    DeviceIntPtr master = GetMaster(mouse, MASTER_KEYBOARD);
    DeviceEvent ev = {
        header: ET_Internal,
        length: DeviceEvent.sizeof,
        type: cast(EventType)event.subtype,
        corestate: butc ? butc.state : 0
    };
    ev.detail.key = event.detail;

    if (master && master.key)
        ev.corestate |= mixin(XkbStateFieldFromRec!("&master.key.xkbInfo.state"));

    UpdateDeviceState(mouse, &ev);

    if (!InputDevIsMaster(mouse))
        return;

    /*
     * Deliver the DGA event
     */
    if (pScreenPriv.client) {
        int coreEquiv = GetCoreType(ev.type);
        dgaEvent de;
            de.u.event.time = cast(uint)event.time;
            de.u.event.dx = cast(short)event.dx;
            de.u.event.dy = cast(short)event.dy;
            de.u.event.screen = cast(short)pScreen.myNum;
            de.u.event.state = cast(ushort)ev.corestate;
        // };
        de.u.u.type = cast(ubyte)(DGAEventBase + coreEquiv);
        de.u.u.detail = cast(ubyte)event.detail;

        /* If the DGA client has selected input, then deliver based on the usual filter */
        TryClientEvents(pScreenPriv.client, mouse, cast(xEvent*) &de, 1,
                        filters[coreEquiv], pScreenPriv.input, null);
    }
    else {
        /* If the pointer is actively grabbed, deliver a grabbed core event */
        if (mouse.deviceGrab.grab && !mouse.deviceGrab.fromPassiveGrab) {
            ev.detail.button = event.detail;
            ev.time = event.time;
            ev.root_x = cast(short)event.dx;
            ev.root_y = cast(short)event.dy;
            ev.corestate = event.state;
            /* DGA is core only, so valuators.data doesn't actually matter.
             * Mask must be set for EventToCore to create motion events. */
            mixin(SetBit!("ev.valuators.mask", "0"));
            mixin(SetBit!("ev.valuators.mask", "1"));
            DeliverGrabbedEvent(cast(InternalEvent*) &ev, mouse, FALSE);
        }
    }
}

private Bool DGAOpenFramebuffer(int index, char** name, ubyte** mem, int* size, int* offset, int* flags)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is available */

    return (*pScreenPriv.funcs.OpenFramebuffer) (pScreenPriv.pScrn,
                                                   name, mem, size, offset,
                                                   flags);
}

private void DGACloseFramebuffer(int index)
{
    DGAScreenPtr pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`screenInfo.screens[index]`));

    /* We rely on the extension to check that DGA is available */
    if (pScreenPriv.funcs.CloseFramebuffer)
        (*pScreenPriv.funcs.CloseFramebuffer) (pScreenPriv.pScrn);
}

private void DGAHandleEvent(int screen_num, InternalEvent* ev, DeviceIntPtr device)
{
    DGAEvent* event = &ev.dga_event;
    ScreenPtr pScreen = screenInfo.screens[screen_num];
    DGAScreenPtr pScreenPriv = void;

    /* no DGA */
    if (!DGAScreenKeyRegistered || noXFree86DGAExtension)
	return;
    pScreenPriv = mixin(DGA_GET_SCREEN_PRIV!(`pScreen`));

    /* DGA not initialized on this screen */
    if (!pScreenPriv)
        return;

    switch (event.subtype) {
    case KeyPress:
    case KeyRelease:
        DGAProcessKeyboardEvent(pScreen, event, device);
        break;
    case MotionNotify:
    case ButtonPress:
    case ButtonRelease:
        DGAProcessPointerEvent(pScreen, event, device);
        break;
    default:
        break;
    }
}





private DevPrivateKeyRec DGAScreenPrivateKeyRec;

enum DGAScreenPrivateKey = (&DGAScreenPrivateKeyRec);
@property bool DGAScreenKeyRegistered()
{
    return cast(bool)dixPrivateKeyRegistered(&DGAScreenKeyRec);
}
private DevPrivateKeyRec DGAClientPrivateKeyRec;

enum DGAClientPrivateKey = (&DGAClientPrivateKeyRec);
private int DGACallbackRefCount = 0;

/* This holds the client's version information */
struct _DGAPrivRec {
    int major;
    int minor;
}alias DGAPrivRec = _DGAPrivRec;
alias DGAPrivPtr = DGAPrivRec*;

enum string DGA_GETCLIENT(string idx) = `(cast(ClientPtr) 
    dixLookupPrivate(&screenInfo.screens[` ~ idx ~ `].devPrivates, DGAScreenPrivateKey))`;
enum string DGA_SETCLIENT(string idx,string p) = `
    dixSetPrivate(&screenInfo.screens[` ~ idx ~ `].devPrivates, DGAScreenPrivateKey, ` ~ p ~ `);`;

enum string DGA_GETPRIV(string c) = `(cast(DGAPrivPtr) 
    dixLookupPrivate(&(` ~ c ~ `).devPrivates, DGAClientPrivateKey))`;
enum string DGA_SETPRIV(string c,string p) = `
    dixSetPrivate(&(` ~ c ~ `).devPrivates, DGAClientPrivateKey, ` ~ p ~ `);`;

private void XDGAResetProc(ExtensionEntry* extEntry)
{
    DeleteCallback(&ClientStateCallback, &DGAClientStateChange, null);
    DGACallbackRefCount = 0;
}

private int ProcXDGAQueryVersion(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xXDGAQueryVersionReq);

    xXDGAQueryVersionReply reply = {
        majorVersion: SERVER_XDGA_MAJOR_VERSION,
        minorVersion: SERVER_XDGA_MINOR_VERSION
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXDGAOpenFramebuffer(ClientPtr client)
{
    mixin(REQUEST!xXDGAOpenFramebufferReq);
    char* deviceName = void;
    int nameSize = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAOpenFramebufferReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (!DGAAvailable(cast(int)stuff.screen))
        return DGAErrorBase + XF86DGANoDirectVideoMode;

    xXDGAOpenFramebufferReply reply = { 0 };

    if (!DGAOpenFramebuffer(cast(int)stuff.screen, &deviceName,
                            cast(ubyte**) (&reply.mem1),
                            cast(int*) &reply.size,
                            cast(int*) &reply.offset,
                            cast(int*) &reply.extra)) {
        return BadAlloc;
    }

    nameSize = deviceName ? cast(int)(strlen(deviceName) + 1) : 0;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)deviceName, nameSize);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXDGACloseFramebuffer(ClientPtr client)
{
    mixin(REQUEST!xXDGACloseFramebufferReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGACloseFramebufferReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (!DGAAvailable(cast(int)stuff.screen))
        return DGAErrorBase + XF86DGANoDirectVideoMode;

    DGACloseFramebuffer(cast(int)stuff.screen);

    return Success;
}

private int ProcXDGAQueryModes(ClientPtr client)
{
    int num = void;

    mixin(REQUEST!xXDGAQueryModesReq);
    xXDGAModeInfo info = void;
    XDGAModePtr mode = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAQueryModesReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if ((!DGAAvailable(cast(int)stuff.screen)) ||
        (((num = DGAGetModes(cast(int)stuff.screen)) == 0)))
    {
        xXDGAQueryModesReply reply = { 0 };
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }

    if (((mode = cast(XDGAModeRec*)calloc(num, XDGAModeRec.sizeof)) is null))
        return BadAlloc;

    for (int i = 0; i < num; i++)
        DGAGetModeInfo(cast(int)stuff.screen, mode + i, i + 1);

    xXDGAQueryModesReply reply = {
        number: num
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (int i = 0; i < num; i++) {
        size_t size = strlen(mode[i].name) + 1;

        info.byte_order = cast(ubyte)mode[i].byteOrder;
        info.depth = cast(ubyte)mode[i].depth;
        info.num = cast(ushort)(mode[i].num);
        info.bpp = cast(ushort)(mode[i].bitsPerPixel);
        info.name_size = cast(ushort)((size + 3) & ~3L);
        info.vsync_num = mode[i].VSync_num;
        info.vsync_den = mode[i].VSync_den;
        info.flags = mode[i].flags;
        info.image_width = cast(ushort)mode[i].imageWidth;
        info.image_height = cast(ushort)mode[i].imageHeight;
        info.pixmap_width = cast(ushort)mode[i].pixmapWidth;
        info.pixmap_height = cast(ushort)mode[i].pixmapHeight;
        info.bytes_per_scanline = mode[i].bytesPerScanline;
        info.red_mask = cast(uint)mode[i].red_mask;
        info.green_mask = cast(uint)mode[i].green_mask;
        info.blue_mask = cast(uint)mode[i].blue_mask;
        info.visual_class = mode[i].visualClass;
        info.viewport_width = cast(ushort)mode[i].viewportWidth;
        info.viewport_height = cast(ushort)mode[i].viewportHeight;
        info.viewport_xstep = cast(ushort)mode[i].xViewportStep;
        info.viewport_ystep = cast(ushort)mode[i].yViewportStep;
        info.viewport_xmax = cast(ushort)mode[i].maxViewportX;
        info.viewport_ymax = cast(ushort)mode[i].maxViewportY;
        info.viewport_flags = mode[i].viewportFlags;
        info.reserved1 = mode[i].reserved1;
        info.reserved2 = mode[i].reserved2;

        x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)&info, sz_xXDGAModeInfo);
        x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)mode[i].name, size);
    }

    free(mode);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private void DGAClientStateChange(CallbackListPtr* pcbl, void* nulldata, void* calldata)
{
    NewClientInfoRec* pci = cast(NewClientInfoRec*) calldata;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (pci.client && (mixin(DGA_GETCLIENT!(`walkScreenIdx`)) == pci.client)) {
            if ((pci.client.clientState == ClientStateGone) ||
                (pci.client.clientState == ClientStateRetained))
            {
                XDGAModeRec mode = void;
                PixmapPtr pPix = void;

                mixin(DGA_SETCLIENT!(`walkScreenIdx`, `null`));
                DGASelectInput(walkScreenIdx, null, 0);
                DGASetMode(cast(int)walkScreenIdx, 0, &mode, &pPix);

                if (--DGACallbackRefCount == 0)
                    DeleteCallback(&ClientStateCallback, &DGAClientStateChange, null);
            }
            break;
        }
    });
}

private int ProcXDGASetMode(ClientPtr client)
{
    mixin(REQUEST!xXDGASetModeReq);
    XDGAModeRec mode = void;
    xXDGAModeInfo info = void;
    PixmapPtr pPix = void;
    ClientPtr owner = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGASetModeReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;
    owner = mixin(DGA_GETCLIENT!(`stuff.screen`));

    if (!DGAAvailable(cast(int)stuff.screen))
        return DGAErrorBase + XF86DGANoDirectVideoMode;

    if (owner && owner != client)
        return DGAErrorBase + XF86DGANoDirectVideoMode;

    xXDGASetModeReply reply = { 0 };

    if (!stuff.mode) {
        if (owner) {
            if (--DGACallbackRefCount == 0)
                DeleteCallback(&ClientStateCallback, &DGAClientStateChange,
                               null);
        }
        mixin(DGA_SETCLIENT!(`stuff.screen`, `null`));
        DGASelectInput(cast(int)stuff.screen, null, 0);
        DGASetMode(cast(int)stuff.screen, cast(int)0, &mode, &pPix);
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }

    if (Success != DGASetMode(cast(int)stuff.screen, cast(int)stuff.mode, &mode, &pPix))
        return BadValue;

    if (!owner) {
        if (DGACallbackRefCount++ == 0)
            AddCallback(&ClientStateCallback, &DGAClientStateChange, null);
    }

    mixin(DGA_SETCLIENT!(`stuff.screen`, `client`));

    if (pPix) {
        if (AddResource(cast(uint)stuff.pid, X11_RESTYPE_PIXMAP, cast(void*) (pPix))) {
            pPix.drawable.id = cast(int) stuff.pid;
            reply.flags = DGA_PIXMAP_AVAILABLE;
        }
    }

    info.byte_order = cast(ubyte)mode.byteOrder;
    info.depth = cast(ubyte)mode.depth;
    info.num = cast(ushort)mode.num;
    info.bpp = cast(ushort)mode.bitsPerPixel;
    info.name_size = cast(ushort)(((strlen(mode.name) + 1) + 3) & ~3L);
    info.vsync_num = mode.VSync_num;
    info.vsync_den = mode.VSync_den;
    info.flags = mode.flags;
    info.image_width = cast(ushort)mode.imageWidth;
    info.image_height = cast(ushort)mode.imageHeight;
    info.pixmap_width = cast(ushort)mode.pixmapWidth;
    info.pixmap_height = cast(ushort)mode.pixmapHeight;
    info.bytes_per_scanline = mode.bytesPerScanline;
    info.red_mask = cast(uint)mode.red_mask;
    info.green_mask = cast(uint)mode.green_mask;
    info.blue_mask = cast(uint)mode.blue_mask;
    info.visual_class = mode.visualClass;
    info.viewport_width = cast(ushort)mode.viewportWidth;
    info.viewport_height = cast(ushort)mode.viewportHeight;
    info.viewport_xstep = cast(ushort)mode.xViewportStep;
    info.viewport_ystep = cast(ushort)mode.yViewportStep;
    info.viewport_xmax = cast(ushort)mode.maxViewportX;
    info.viewport_ymax = cast(ushort)mode.maxViewportY;
    info.viewport_flags = mode.viewportFlags;
    info.reserved1 = mode.reserved1;
    info.reserved2 = mode.reserved2;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_binary_pad(&rpcbuf, &info, info.sizeof);
    x_rpcbuf_write_string_0t_pad(&rpcbuf, mode.name);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXDGASetViewport(ClientPtr client)
{
    mixin(REQUEST!xXDGASetViewportReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGASetViewportReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    DGASetViewport(cast(int)stuff.screen, stuff.x, stuff.y, cast(int)stuff.flags);

    return Success;
}

private int ProcXDGAInstallColormap(ClientPtr client)
{
    ColormapPtr cmap = void;
    int rc = void;

    mixin(REQUEST!xXDGAInstallColormapReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAInstallColormapReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    rc = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixInstallAccess);
    if (rc != Success)
        return rc;
    DGAInstallCmap(cmap);
    return Success;
}

private int ProcXDGASelectInput(ClientPtr client)
{
    mixin(REQUEST!xXDGASelectInputReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGASelectInputReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) == client)
        DGASelectInput(cast(int)stuff.screen, client, stuff.mask);

    return Success;
}

private int ProcXDGAFillRectangle(ClientPtr client)
{
    mixin(REQUEST!xXDGAFillRectangleReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAFillRectangleReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    if (Success != DGAFillRect(cast(int)stuff.screen, stuff.x, stuff.y,
                               stuff.width, stuff.height, stuff.color))
        return BadMatch;

    return Success;
}

private int ProcXDGACopyArea(ClientPtr client)
{
    mixin(REQUEST!xXDGACopyAreaReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGACopyAreaReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    if (Success != DGABlitRect(cast(int)stuff.screen, stuff.srcx, stuff.srcy,
                               stuff.width, stuff.height, stuff.dstx,
                               stuff.dsty))
        return BadMatch;

    return Success;
}

private int ProcXDGACopyTransparentArea(ClientPtr client)
{
    mixin(REQUEST!xXDGACopyTransparentAreaReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGACopyTransparentAreaReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    if (Success != DGABlitTransRect(cast(int)stuff.screen, stuff.srcx, stuff.srcy,
                                    stuff.width, stuff.height, stuff.dstx,
                                    stuff.dsty, stuff.key))
        return BadMatch;

    return Success;
}

private int ProcXDGAGetViewportStatus(ClientPtr client)
{
    mixin(REQUEST!xXDGAGetViewportStatusReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAGetViewportStatusReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    xXDGAGetViewportStatusReply reply = {
        status: DGAGetViewportStatus(cast(int)stuff.screen)
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXDGASync(ClientPtr client)
{
    mixin(REQUEST!xXDGASyncReq);

    mixin(REQUEST_AT_LEAST_SIZE!xXDGASyncReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    xXDGASyncReply reply = { 0 };
    DGASync(cast(int)stuff.screen);

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXDGASetClientVersion(ClientPtr client)
{
    mixin(REQUEST!xXDGASetClientVersionReq);

    DGAPrivPtr pPriv = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGASetClientVersionReq);
    if ((pPriv = mixin(DGA_GETPRIV!(`client`))) is null) {
        pPriv = cast(DGAPrivRec*) calloc(1, DGAPrivRec.sizeof);
        /* XXX Need to look into freeing this */
        if (!pPriv)
            return BadAlloc;
        mixin(DGA_SETPRIV!(`client`, `pPriv`));
    }
    pPriv.major = stuff.major;
    pPriv.minor = stuff.minor;

    return Success;
}

private int ProcXDGAChangePixmapMode(ClientPtr client)
{
    mixin(REQUEST!xXDGAChangePixmapModeReq);
    int x = void, y = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGAChangePixmapModeReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    x = stuff.x;
    y = stuff.y;

    if (!DGAChangePixmapMode(cast(int)stuff.screen, &x, &y, cast(int)stuff.flags))
        return BadMatch;

    xXDGAChangePixmapModeReply reply = {
        x: cast(ushort)x,
        y: cast(ushort)y
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXDGACreateColormap(ClientPtr client)
{
    mixin(REQUEST!xXDGACreateColormapReq);
    int result = void;

    mixin(REQUEST_AT_LEAST_SIZE!xXDGACreateColormapReq);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (mixin(DGA_GETCLIENT!(`stuff.screen`)) != client)
        return DGAErrorBase + XF86DGADirectNotActivated;

    if (!stuff.mode)
        return BadValue;

    result = DGACreateColormap(cast(int)stuff.screen, client, cast(int)stuff.id,
                               cast(int)stuff.mode, stuff.alloc);
    if (result != Success)
        return result;

    return Success;
}

version (none) {
version = DGA_REQ_DEBUG;
}

version (DGA_REQ_DEBUG) {
private char*[28] dgaMinor = [
    "QueryVersion",
    "GetVideoLL",
    "DirectVideo",
    "GetViewPortSize",
    "SetViewPort",
    "GetVidPage",
    "SetVidPage",
    "InstallColormap",
    "QueryDirectVideo",
    "ViewPortChanged",
    "10",
    "11",
    "QueryModes",
    "SetMode",
    "SetViewport",
    "InstallColormap",
    "SelectInput",
    "FillRectangle",
    "CopyArea",
    "CopyTransparentArea",
    "GetViewportStatus",
    "Sync",
    "OpenFramebuffer",
    "CloseFramebuffer",
    "SetClientVersion",
    "ChangePixmapMode",
    "CreateColormap",
];
}

private int ProcXDGADispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    if (!client.local)
        return DGAErrorBase + XF86DGAClientNotLocal;

version (DGA_REQ_DEBUG) {
    if (stuff.data <= X_XDGACreateColormap)
        fprintf(stderr, "    DGA %s\n", dgaMinor[stuff.data]);
}

    switch (stuff.data) {
        /*
         * DGA2 Protocol
         */
    case X_XDGAQueryVersion:
        return ProcXDGAQueryVersion(client);
    case X_XDGAQueryModes:
        return ProcXDGAQueryModes(client);
    case X_XDGASetMode:
        return ProcXDGASetMode(client);
    case X_XDGAOpenFramebuffer:
        return ProcXDGAOpenFramebuffer(client);
    case X_XDGACloseFramebuffer:
        return ProcXDGACloseFramebuffer(client);
    case X_XDGASetViewport:
        return ProcXDGASetViewport(client);
    case X_XDGAInstallColormap:
        return ProcXDGAInstallColormap(client);
    case X_XDGASelectInput:
        return ProcXDGASelectInput(client);
    case X_XDGAFillRectangle:
        return ProcXDGAFillRectangle(client);
    case X_XDGACopyArea:
        return ProcXDGACopyArea(client);
    case X_XDGACopyTransparentArea:
        return ProcXDGACopyTransparentArea(client);
    case X_XDGAGetViewportStatus:
        return ProcXDGAGetViewportStatus(client);
    case X_XDGASync:
        return ProcXDGASync(client);
    case X_XDGASetClientVersion:
        return ProcXDGASetClientVersion(client);
    case X_XDGAChangePixmapMode:
        return ProcXDGAChangePixmapMode(client);
    case X_XDGACreateColormap:
        return ProcXDGACreateColormap(client);
    default:
        return BadRequest;
    }
}

void XFree86DGAExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (!dixRegisterPrivateKey(&DGAClientPrivateKeyRec, PRIVATE_CLIENT, 0))
        return;

    if (!dixRegisterPrivateKey(&DGAScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return;

    if ((extEntry = AddExtension(XF86DGANAME,
                                 XF86DGANumberEvents,
                                 XF86DGANumberErrors,
                                 &ProcXDGADispatch,
                                 &ProcXDGADispatch,
                                 &XDGAResetProc, &StandardMinorOpcode)) !is null) {
        int i = void;

        DGAReqCode = cast(ubyte) extEntry.base;
        DGAErrorBase = extEntry.errorBase;
        DGAEventBase = extEntry.eventBase;
        for (i = KeyPress; i <= MotionNotify; i++)
            SetCriticalEvent(DGAEventBase + i);
    }
}
