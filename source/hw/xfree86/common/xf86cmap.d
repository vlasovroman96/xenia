module xf86cmap;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 1998-2001 by The XFree86 Project, Inc.
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

import core.stdc.math;
//import x11.X;
//import x11.Xproto;

import common.misc;

import dix.colormap_priv;
import dix.screen_hooks_priv;
import mi.mi_priv;

import dix.scrnintstr;

import hw.xfree86.os_support.xf86_OSproc;;
import hw.xfree86.common.xf86str;
import mi.micmap;
import xf86RandR12_priv;
import hw.xfree86.common.xf86Crtc;
import dix.privates;
import dix.screen_hooks;
import build.xlibre_server;

static if(XFreeXDGA){
//import externs.X11.extensions.xf86dgaproto;
import hw.xfree86.common.dgaproc_priv;
}

import xf86cmap;
import xf86DGA;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.modes.xf86Crtc;
import dix.resource;
import dix.dixutils;
import hw.xfree86.modes.displaymode;

public import common.xlibre_ptrtypes;

enum CMAP_PALETTED_TRUECOLOR =		0x0000001;
enum CMAP_RELOAD_ON_MODE_SWITCH =	0x0000002;
enum CMAP_LOAD_EVEN_IF_OFFSCREEN =	0x0000004;

// void  xf86HandleColormaps(ScreenPtr pScreen, int maxCol, int sigRGBbits, xf86LoadPaletteProc* loadPalette, xf86SetOverscanProc* setOverscan, uint flags);

// void  xf86ColormapAllocatePrivates(ScrnInfoPtr pScrn);

// void  xf86ChangeGamma(ScreenPtr pScreen, Gamma newGamma);

// void  xf86ChangeGammaRamp(ScreenPtr pScreen, int size, ushort* red, ushort* green, ushort* blue);

// void  xf86GetGammaRampSize(ScreenPtr pScreen);

// void  xf86GetGammaRamp(ScreenPtr pScreen, int size, ushort* red, ushort* green, ushort* blue);

enum string SCREEN_PROLOGUE(string pScreen, string field) = `((` ~ pScreen ~ `).` ~ field ~ ` = 
    (cast(CMapScreenPtr)dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, CMapScreenKey)).` ~ field ~ `)`;
enum string SCREEN_EPILOGUE(string pScreen, string field, string wrapper) = `
    ((` ~ pScreen ~ `).` ~ field ~ ` = ` ~ wrapper ~ `)`;

enum string LOAD_PALETTE(string pmap) = `
    ((` ~ pmap ~ ` == GetInstalledmiColormap(` ~ pmap ~ `.pScreen)) && 
     ((pScreenPriv.flags & CMAP_LOAD_EVEN_IF_OFFSCREEN) || 
      xf86ScreenToScrn(` ~ pmap ~ `.pScreen).vtSema || pScreenPriv.isDGAmode))`;

struct _CMapLink {
    ColormapPtr cmap;
    _CMapLink* next;
}alias CMapLink = _CMapLink;
alias CMapLinkPtr = _CMapLink*;

struct _CMapScreenRec {
    CreateColormapProcPtr CreateColormap;
    DestroyColormapProcPtr DestroyColormap;
    InstallColormapProcPtr InstallColormap;
    StoreColorsProcPtr StoreColors;
    Bool function(ScrnInfoPtr) @nogc nothrow EnterVT;
    Bool function(ScrnInfoPtr, DisplayModePtr) @nogc nothrow SwitchMode;
    int function(ScrnInfoPtr, int, DGADevicePtr) @nogc nothrow SetDGAMode;
    xf86ChangeGammaProc* ChangeGamma;
    int maxColors;
    int sigRGBbits;
    int gammaElements;
    LOCO* gamma;
    int* PreAllocIndices;
    CMapLinkPtr maps;
    uint flags;
    Bool isDGAmode;
}alias CMapScreenRec = _CMapScreenRec;
alias CMapScreenPtr = CMapScreenRec*;

struct _CMapColormapRec {
    int numColors;
    LOCO* colors;
    Bool recalculate;
    int overscan;
}alias CMapColormapRec = _CMapColormapRec;
alias CMapColormapPtr = CMapColormapRec*;

private DevPrivateKeyRec CMapScreenKeyRec;

@property bool DGAScreenKeyRegistered()
{
    return cast(bool)dixPrivateKeyRegistered(&DGAScreenKeyRec);
}
enum CMapScreenKey = (&CMapScreenKeyRec);
private DevPrivateKeyRec CMapColormapKeyRec;

enum CMapColormapKey = (&CMapColormapKeyRec);

enum string CMapScreenKeyRegistered = `dixPrivateKeyRegistered(&CMapScreenKeyRec)`;








static if(XFreeXDGA){

}








Bool xf86ColormapAllocatePrivates(ScrnInfoPtr pScrn)
{
    if (!dixRegisterPrivateKey(&CMapScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&CMapColormapKeyRec, PRIVATE_COLORMAP, 0))
        return FALSE;
    return TRUE;
}

Bool xf86HandleColormaps(ScreenPtr pScreen, int maxColors, int sigRGBbits, xf86LoadPaletteProc loadPalette, xf86SetOverscanProc setOverscan, uint flags)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    ColormapPtr pDefMap = null;
    CMapScreenPtr pScreenPriv = void;
    LOCO* gamma = void;
    int* indices = void;
    int elements = void;

    if (!maxColors || !sigRGBbits ||
        (!loadPalette && !xf86_crtc_supports_gamma(pScrn)))
        return FALSE;

    elements = 1 << sigRGBbits;

    if (((gamma = cast(LOCO*) calloc(elements, LOCO.sizeof)) is null))
        return FALSE;

    if (((indices = cast(int*) calloc(maxColors, int.sizeof)) is null)) {
        free(gamma);
        return FALSE;
    }

    if (((pScreenPriv = cast(CMapScreenRec*) calloc(1, CMapScreenRec.sizeof)) is null)) {
        free(gamma);
        free(indices);
        return FALSE;
    }

    dixSetPrivate(&pScreen.devPrivates, &CMapScreenKeyRec, pScreenPriv);
    dixScreenHookClose(pScreen, &CMapCloseScreen);

    pScreenPriv.CreateColormap = pScreen.CreateColormap;
    pScreenPriv.DestroyColormap = pScreen.DestroyColormap;
    pScreenPriv.InstallColormap = pScreen.InstallColormap;
    pScreenPriv.StoreColors = pScreen.StoreColors;
    pScreen.CreateColormap = &CMapCreateColormap;
    pScreen.DestroyColormap = &CMapDestroyColormap;
    pScreen.InstallColormap = &CMapInstallColormap;
    pScreen.StoreColors = &CMapStoreColors;

    pScrn.LoadPalette = loadPalette;
    pScrn.SetOverscan = setOverscan;
    pScreenPriv.maxColors = maxColors;
    pScreenPriv.sigRGBbits = sigRGBbits;
    pScreenPriv.gammaElements = elements;
    pScreenPriv.gamma = gamma;
    pScreenPriv.PreAllocIndices = indices;
    pScreenPriv.maps = null;
    pScreenPriv.flags = flags;
    pScreenPriv.isDGAmode = FALSE;

    pScreenPriv.EnterVT = pScrn.EnterVT;
    pScreenPriv.SwitchMode = pScrn.SwitchMode;
    pScreenPriv.SetDGAMode = pScrn.SetDGAMode;
    pScreenPriv.ChangeGamma = &pScrn.ChangeGamma;

    if (!(flags & CMAP_LOAD_EVEN_IF_OFFSCREEN)) {
        pScrn.EnterVT = &CMapEnterVT;
        if ((flags & CMAP_RELOAD_ON_MODE_SWITCH) && pScrn.SwitchMode)
            pScrn.SwitchMode = &CMapSwitchMode;
    }
static if(XFreeXDGA){
    pScrn.SetDGAMode = &CMapSetDGAMode;
}
    pScrn.ChangeGamma = &CMapChangeGamma;

    ComputeGamma(pScrn, pScreenPriv);

    /* get the default map */
    dixLookupResourceByType(cast(void**) &pDefMap, cast(uint)pScreen.defColormap,
                            X11_RESTYPE_COLORMAP, serverClient, DixInstallAccess);

    if (!CMapAllocateColormapPrivate(pDefMap)) {
        CMapCloseScreen(null, pScreen, null);
        return FALSE;
    }

    if (xf86_crtc_supports_gamma(pScrn)) {
        pScrn.LoadPalette = &xf86RandR12LoadPalette;

        if (!xf86RandR12InitGamma(pScrn, elements)) {
            CMapCloseScreen(null, pScreen, null);
            return FALSE;
        }
    }

    /* Force the initial map to be loaded */
    SetInstalledmiColormap(pScreen, null);
    CMapInstallColormap(pDefMap);
    return TRUE;
}

/**** Screen functions ****/

private Bool CMapColormapUseMax(VisualPtr pVisual, CMapScreenPtr pScreenPriv)
{
    if (pVisual.nplanes > 16)
        return TRUE;
    return ((1 << pVisual.nplanes) > pScreenPriv.maxColors);
}

private Bool CMapAllocateColormapPrivate(ColormapPtr pmap)
{
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pmap.pScreen.devPrivates,
                                         CMapScreenKey);
    CMapColormapPtr pColPriv = void;
    int numColors = void;
    LOCO* colors = void;

    if (CMapColormapUseMax(pmap.pVisual, pScreenPriv))
        numColors = pmap.pVisual.ColormapEntries;
    else
        numColors = 1 << pmap.pVisual.nplanes;

    if (((colors = cast(LOCO*) calloc(numColors, LOCO.sizeof)) is null))
        return FALSE;

    if (((pColPriv = cast(CMapColormapRec*) calloc(1, CMapColormapRec.sizeof)) is null)) {
        free(colors);
        return FALSE;
    }

    dixSetPrivate(&pmap.devPrivates, CMapColormapKey, pColPriv);

    pColPriv.numColors = numColors;
    pColPriv.colors = colors;
    pColPriv.recalculate = TRUE;
    pColPriv.overscan = -1;

    /* add map to list */
    CMapLinkPtr pLink = cast(CMapLink*) calloc(1, CMapLink.sizeof);
    if (pLink) {
        pLink.cmap = pmap;
        pLink.next = pScreenPriv.maps;
        pScreenPriv.maps = pLink;
    }

    return TRUE;
}

private Bool CMapCreateColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);
    Bool ret = FALSE;

    pScreen.CreateColormap = pScreenPriv.CreateColormap;
    if ((*pScreen.CreateColormap) (pmap)) {
        if (CMapAllocateColormapPrivate(pmap))
            ret = TRUE;
    }
    pScreen.CreateColormap = &CMapCreateColormap;

    return ret;
}

private void CMapDestroyColormap(ColormapPtr cmap)
{
    ScreenPtr pScreen = cmap.pScreen;
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);
    CMapColormapPtr pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&cmap.devPrivates, CMapColormapKey);
    CMapLinkPtr prevLink = null, pLink = pScreenPriv.maps;

    if (pColPriv) {
        free(pColPriv.colors);
        free(pColPriv);
    }

    /* remove map from list */
    while (pLink) {
        if (pLink.cmap == cmap) {
            if (prevLink)
                prevLink.next = pLink.next;
            else
                pScreenPriv.maps = pLink.next;
            free(pLink);
            break;
        }
        prevLink = pLink;
        pLink = pLink.next;
    }

    if (pScreenPriv.DestroyColormap) {
        pScreen.DestroyColormap = pScreenPriv.DestroyColormap;
        (*pScreen.DestroyColormap) (cmap);
        pScreen.DestroyColormap = &CMapDestroyColormap;
    }
}

private void CMapStoreColors(ColormapPtr pmap, int ndef, xColorItem* pdefs)
{
    ScreenPtr pScreen = pmap.pScreen;
    VisualPtr pVisual = pmap.pVisual;
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);
    int* indices = pScreenPriv.PreAllocIndices;
    int num = ndef;

    /* At the moment this isn't necessary since there's nobody below us */
    pScreen.StoreColors = pScreenPriv.StoreColors;
    (*pScreen.StoreColors) (pmap, ndef, pdefs);
    pScreen.StoreColors = &CMapStoreColors;

    /* should never get here for these */
    if ((pVisual.class_ == TrueColor) ||
        (pVisual.class_ == StaticColor) || (pVisual.class_ == StaticGray))
        return;

    if (pVisual.class_ == DirectColor) {
        CMapColormapPtr pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&pmap.devPrivates,
                                               CMapColormapKey);
        int i = void;

        if (CMapColormapUseMax(pVisual, pScreenPriv)) {
            int index = void;

            num = 0;
            while (ndef--) {
                if (pdefs[ndef].flags & DoRed) {
                    index = cast(int)((pdefs[ndef].pixel & pVisual.redMask) >>
                        pVisual.offsetRed);
                    i = num;
                    while (i--)
                        if (indices[i] == index)
                            break;
                    if (i == -1)
                        indices[num++] = index;
                }
                if (pdefs[ndef].flags & DoGreen) {
                    index = cast(int)((pdefs[ndef].pixel & pVisual.greenMask) >>
                        pVisual.offsetGreen);
                    i = num;
                    while (i--)
                        if (indices[i] == index)
                            break;
                    if (i == -1)
                        indices[num++] = index;
                }
                if (pdefs[ndef].flags & DoBlue) {
                    index = cast(int)((pdefs[ndef].pixel & pVisual.blueMask) >>
                        pVisual.offsetBlue);
                    i = num;
                    while (i--)
                        if (indices[i] == index)
                            break;
                    if (i == -1)
                        indices[num++] = index;
                }
            }

        }
        else {
            /* not really as overkill as it seems */
            num = pColPriv.numColors;
            for (i = 0; i < pColPriv.numColors; i++)
                indices[i] = i;
        }
    }
    else {
        while (ndef--)
            indices[ndef] = cast(int)pdefs[ndef].pixel;
    }

    CMapRefreshColors(pmap, num, indices);
}

private void CMapInstallColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);

    if (pmap == GetInstalledmiColormap(pmap.pScreen))
        return;

    pScreen.InstallColormap = pScreenPriv.InstallColormap;
    (*pScreen.InstallColormap) (pmap);
    pScreen.InstallColormap = &CMapInstallColormap;

    /* Important. We let the lower layers, namely DGA,
       overwrite the choice of Colormap to install */
    if (GetInstalledmiColormap(pmap.pScreen))
        pmap = GetInstalledmiColormap(pmap.pScreen);

    if (!(pScreenPriv.flags & CMAP_PALETTED_TRUECOLOR) &&
        (pmap.pVisual.class_ == TrueColor) &&
        CMapColormapUseMax(pmap.pVisual, pScreenPriv))
        return;

    if (mixin(LOAD_PALETTE!(`pmap`)))
        CMapReinstallMap(pmap);
}

/**** ScrnInfoRec functions ****/

private Bool CMapEnterVT(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    Bool ret = void;
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);

    pScrn.EnterVT = pScreenPriv.EnterVT;
    ret = (*pScreenPriv.EnterVT) (pScrn);
    pScreenPriv.EnterVT = pScrn.EnterVT;
    pScrn.EnterVT = &CMapEnterVT;
    if (ret) {
        if (GetInstalledmiColormap(pScreen))
            CMapReinstallMap(GetInstalledmiColormap(pScreen));
        return TRUE;
    }
    return FALSE;
}

private Bool CMapSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);

    if ((*pScreenPriv.SwitchMode) (pScrn, mode)) {
        if (GetInstalledmiColormap(pScreen))
            CMapReinstallMap(GetInstalledmiColormap(pScreen));
        return TRUE;
    }
    return FALSE;
}

static if(XFreeXDGA){
private int CMapSetDGAMode(ScrnInfoPtr pScrn, int num, DGADevicePtr dev)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);
    int ret = void;

    ret = (*pScreenPriv.SetDGAMode) (pScrn, num, dev);

    pScreenPriv.isDGAmode = DGAActive(pScrn.scrnIndex);

    if (!pScreenPriv.isDGAmode && GetInstalledmiColormap(pScreen)
        && xf86ScreenToScrn(pScreen).vtSema)
        CMapReinstallMap(GetInstalledmiColormap(pScreen));

    return ret;
}
}

/**** Utilities ****/

private void CMapReinstallMap(ColormapPtr pmap)
{
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pmap.pScreen.devPrivates,
                                         CMapScreenKey);
    CMapColormapPtr cmapPriv = cast(CMapColormapPtr) dixLookupPrivate(&pmap.devPrivates, CMapColormapKey);
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pmap.pScreen);
    int i = cmapPriv.numColors;
    int* indices = pScreenPriv.PreAllocIndices;

    while (i--)
        indices[i] = i;

    if (cmapPriv.recalculate)
        CMapRefreshColors(pmap, cmapPriv.numColors, indices);
    else {
        (*pScrn.LoadPalette) (pScrn, cmapPriv.numColors,
                               indices, cmapPriv.colors, pmap.pVisual);
        if (pScrn.SetOverscan) {
version (DEBUGOVERSCAN) {
            ErrorF("SetOverscan() called from CMapReinstallMap\n");
}
            pScrn.SetOverscan(pScrn, cmapPriv.overscan);
        }
    }

    cmapPriv.recalculate = FALSE;
}

private void CMapRefreshColors(ColormapPtr pmap, int defs, int* indices)
{
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pmap.pScreen.devPrivates,
                                         CMapScreenKey);
    CMapColormapPtr pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&pmap.devPrivates, CMapColormapKey);
    VisualPtr pVisual = pmap.pVisual;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pmap.pScreen);
    int numColors = void, i = void;
    LOCO* gamma = void, colors = void;
    EntryPtr entry = void;
    int reds = void, greens = void, blues = void, maxValue = void, index = void, shift = void;

    numColors = pColPriv.numColors;
    shift = 16 - pScreenPriv.sigRGBbits;
    maxValue = (1 << pScreenPriv.sigRGBbits) - 1;
    gamma = pScreenPriv.gamma;
    colors = pColPriv.colors;

    reds = cast(int)(pVisual.redMask >> pVisual.offsetRed);
    greens = cast(int)(pVisual.greenMask >> pVisual.offsetGreen);
    blues = cast(int)(pVisual.blueMask >> pVisual.offsetBlue);

    switch (pVisual.class_) {
    case StaticGray:
        for (i = 0; i < numColors; i++) {
            index = (i + 1) * maxValue / numColors;
            colors[i].red = gamma[index].red;
            colors[i].green = gamma[index].green;
            colors[i].blue = gamma[index].blue;
        }
        break;
    case TrueColor:
        if (CMapColormapUseMax(pVisual, pScreenPriv)) {
            for (i = 0; i <= reds; i++)
                colors[i].red = gamma[i * maxValue / reds].red;
            for (i = 0; i <= greens; i++)
                colors[i].green = gamma[i * maxValue / greens].green;
            for (i = 0; i <= blues; i++)
                colors[i].blue = gamma[i * maxValue / blues].blue;
            break;
        }
        for (i = 0; i < numColors; i++) {
            colors[i].red = gamma[((i >> pVisual.offsetRed) & reds) *
                                  maxValue / reds].red;
            colors[i].green = gamma[((i >> pVisual.offsetGreen) & greens) *
                                    maxValue / greens].green;
            colors[i].blue = gamma[((i >> pVisual.offsetBlue) & blues) *
                                   maxValue / blues].blue;
        }
        break;
    case StaticColor:
    case PseudoColor:
    case GrayScale:
        for (i = 0; i < defs; i++) {
            index = indices[i];
            entry = cast(EntryPtr) &pmap.red[index];

            if (entry.fShared) {
                colors[index].red =
                    gamma[entry.co.shco.red.color >> shift].red;
                colors[index].green =
                    gamma[entry.co.shco.green.color >> shift].green;
                colors[index].blue =
                    gamma[entry.co.shco.blue.color >> shift].blue;
            }
            else {
                colors[index].red = gamma[entry.co.local.red >> shift].red;
                colors[index].green =
                    gamma[entry.co.local.green >> shift].green;
                colors[index].blue = gamma[entry.co.local.blue >> shift].blue;
            }
        }
        break;
    case DirectColor:
        if (CMapColormapUseMax(pVisual, pScreenPriv)) {
            for (i = 0; i < defs; i++) {
                index = indices[i];
                if (index <= reds)
                    colors[index].red =
                        gamma[pmap.red[index].co.local.red >> shift].red;
                if (index <= greens)
                    colors[index].green =
                        gamma[pmap.green[index].co.local.green >> shift].green;
                if (index <= blues)
                    colors[index].blue =
                        gamma[pmap.blue[index].co.local.blue >> shift].blue;

            }
            break;
        }
        for (i = 0; i < defs; i++) {
            index = indices[i];

            colors[index].red = gamma[pmap.red[(index >> pVisual.
                                                 offsetRed) & reds].co.local.
                                      red >> shift].red;
            colors[index].green =
                gamma[pmap.green[(index >> pVisual.offsetGreen) & greens].co.
                      local.green >> shift].green;
            colors[index].blue =
                gamma[pmap.blue[(index >> pVisual.offsetBlue) & blues].co.
                      local.blue >> shift].blue;
        }
        break;
    default: break;}

    if (mixin(LOAD_PALETTE!(`pmap`)))
        (*pScrn.LoadPalette) (pScrn, defs, indices, colors, pmap.pVisual);

    if (pScrn.SetOverscan)
        CMapSetOverscan(pmap, defs, indices);

}

private Bool CMapCompareColors(LOCO* color1, LOCO* color2)
{
    /* return TRUE if the color1 is "closer" to black than color2 */
version (DEBUGOVERSCAN) {
    ErrorF("#%02x%02x%02x vs #%02x%02x%02x (%d vs %d)\n",
           color1.red, color1.green, color1.blue,
           color2.red, color2.green, color2.blue,
           color1.red + color1.green + color1.blue,
           color2.red + color2.green + color2.blue);
}
    return (color1.red + color1.green + color1.blue <
            color2.red + color2.green + color2.blue);
}

private void CMapSetOverscan(ColormapPtr pmap, int defs, int* indices)
{
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pmap.pScreen.devPrivates,
                                         CMapScreenKey);
    CMapColormapPtr pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&pmap.devPrivates, CMapColormapKey);
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pmap.pScreen);
    VisualPtr pVisual = pmap.pVisual;
    int i = void;
    LOCO* colors = void;
    int index = void;
    Bool newOverscan = FALSE;
    int overscan = void, tmpOverscan = void;

    colors = pColPriv.colors;
    overscan = pColPriv.overscan;

    /*
     * Search for a new overscan index in the following cases:
     *
     *   - The index hasn't yet been initialised.  In this case search
     *     for an index that is black or a close match to black.
     *
     *   - The colour of the old index is changed.  In this case search
     *     all indices for a black or close match to black.
     *
     *   - The colour of the old index wasn't black.  In this case only
     *     search the indices that were changed for a better match to black.
     */

    switch (pVisual.class_) {
    case StaticGray:
    case TrueColor:
        /* Should only come here once.  Initialise the overscan index to 0 */
        overscan = 0;
        newOverscan = TRUE;
        break;
    case StaticColor:
        /*
         * Only come here once, but search for the overscan in the same way
         * as for the other cases.
         */
    case DirectColor:
    case PseudoColor:
    case GrayScale:
        if (overscan < 0 || overscan > pScreenPriv.maxColors - 1) {
            /* Uninitialised */
            newOverscan = TRUE;
        }
        else {
            /* Check if the overscan was changed */
            for (i = 0; i < defs; i++) {
                index = indices[i];
                if (index == overscan) {
                    newOverscan = TRUE;
                    break;
                }
            }
        }
        if (newOverscan) {
            /* The overscan is either uninitialised or it has been changed */

            if (overscan < 0 || overscan > pScreenPriv.maxColors - 1)
                tmpOverscan = pScreenPriv.maxColors - 1;
            else
                tmpOverscan = overscan;

            /* search all entries for a close match to black */
            for (i = pScreenPriv.maxColors - 1; i >= 0; i--) {
                if (colors[i].red == 0 && colors[i].green == 0 &&
                    colors[i].blue == 0) {
                    overscan = i;
version (DEBUGOVERSCAN) {
                    ErrorF("Black found at index 0x%02x\n", i);
}
                    break;
                }
                else {
version (DEBUGOVERSCAN) {
                    ErrorF("0x%02x: ", i);
}
                    if (CMapCompareColors(&colors[i], &colors[tmpOverscan])) {
                        tmpOverscan = i;
version (DEBUGOVERSCAN) {
                        ErrorF("possible \"Black\" at index 0x%02x\n", i);
}
                    }
                }
            }
            if (i < 0)
                overscan = tmpOverscan;
        }
        else {
            /* Check of the old overscan wasn't black */
            if (colors[overscan].red != 0 || colors[overscan].green != 0 ||
                colors[overscan].blue != 0) {
                int oldOverscan = tmpOverscan = overscan;

                /* See of there is now a better match */
                for (i = 0; i < defs; i++) {
                    index = indices[i];
                    if (colors[index].red == 0 && colors[index].green == 0 &&
                        colors[index].blue == 0) {
                        overscan = index;
version (DEBUGOVERSCAN) {
                        ErrorF("Black found at index 0x%02x\n", index);
}
                        break;
                    }
                    else {
version (DEBUGOVERSCAN) {
                        ErrorF("0x%02x: ", index);
}
                        if (CMapCompareColors(&colors[index],
                                              &colors[tmpOverscan])) {
                            tmpOverscan = index;
version (DEBUGOVERSCAN) {
                            ErrorF("possible \"Black\" at index 0x%02x\n",
                                   index);
}
                        }
                    }
                }
                if (i == defs)
                    overscan = tmpOverscan;
                if (overscan != oldOverscan)
                    newOverscan = TRUE;
            }
        }
        break;
    default: break;}
    if (newOverscan) {
        pColPriv.overscan = overscan;
        if (mixin(LOAD_PALETTE!(`pmap`))) {
version (DEBUGOVERSCAN) {
            ErrorF("SetOverscan() called from CmapSetOverscan\n");
}
            pScrn.SetOverscan(pScrn, overscan);
        }
    }
}

private void CMapCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    CMapScreenPtr pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates, CMapScreenKey);
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    if (!pScrn)
        return;

    dixScreenUnhookClose(pScreen, &CMapCloseScreen);

    pScreen.CreateColormap = pScreenPriv.CreateColormap;
    pScreen.DestroyColormap = pScreenPriv.DestroyColormap;
    pScreen.InstallColormap = pScreenPriv.InstallColormap;
    pScreen.StoreColors = pScreenPriv.StoreColors;

    pScrn.EnterVT = pScreenPriv.EnterVT;
    pScrn.SwitchMode = pScreenPriv.SwitchMode;
    pScrn.SetDGAMode = pScreenPriv.SetDGAMode;
    pScrn.ChangeGamma = *pScreenPriv.ChangeGamma;

    free(pScreenPriv.gamma);
    free(pScreenPriv.PreAllocIndices);
    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &CMapScreenKeyRec, null);
}

private void ComputeGamma(ScrnInfoPtr pScrn, CMapScreenPtr priv)
{
    int elements = priv.gammaElements - 1;
    double RedGamma = void, GreenGamma = void, BlueGamma = void;
    int i = void;

version (DONT_CHECK_GAMMA) {} else {
    /* This check is to catch drivers that are not initialising pScrn->gamma */
    if (pScrn.gamma.red < GAMMA_MIN || pScrn.gamma.red > GAMMA_MAX ||
        pScrn.gamma.green < GAMMA_MIN || pScrn.gamma.green > GAMMA_MAX ||
        pScrn.gamma.blue < GAMMA_MIN || pScrn.gamma.blue > GAMMA_MAX) {

        xf86DrvMsgVerb(pScrn.scrnIndex, X_WARNING, 0,
                       "The %s driver didn't call xf86SetGamma() to initialise\n"
                       ~ "\tthe gamma values.\n", pScrn.driverName);
        xf86DrvMsgVerb(pScrn.scrnIndex, X_WARNING, 0,
                       "PLEASE FIX THE `%s' DRIVER!\n",
                       pScrn.driverName);
        pScrn.gamma.red = 1.0;
        pScrn.gamma.green = 1.0;
        pScrn.gamma.blue = 1.0;
    }
}

    RedGamma = 1.0 / cast(double) pScrn.gamma.red;
    GreenGamma = 1.0 / cast(double) pScrn.gamma.green;
    BlueGamma = 1.0 / cast(double) pScrn.gamma.blue;

    for (i = 0; i <= elements; i++) {
        if (RedGamma == 1.0)
            priv.gamma[i].red = cast(ushort)i;
        else
            priv.gamma[i].red = cast(CARD16) (pow(cast(double) i / cast(double) elements,
                                               RedGamma) * cast(double) elements +
                                           0.5);

        if (GreenGamma == 1.0)
            priv.gamma[i].green = cast(ushort)i;
        else
            priv.gamma[i].green = cast(CARD16) (pow(cast(double) i / cast(double) elements,
                                                 GreenGamma) *
                                             cast(double) elements + 0.5);

        if (BlueGamma == 1.0)
            priv.gamma[i].blue = cast(ushort)i;
        else
            priv.gamma[i].blue = cast(CARD16) (pow(cast(double) i / cast(double) elements,
                                                BlueGamma) * cast(double) elements +
                                            0.5);
    }
}

int CMapChangeGamma(ScrnInfoPtr pScrn, Gamma gamma)
{
    int ret = Success;
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    CMapColormapPtr pColPriv = void;
    CMapScreenPtr pScreenPriv = void;
    CMapLinkPtr pLink = void;

    /* Is this sufficient checking ? */
    if (!mixin(CMapScreenKeyRegistered))
        return BadImplementation;

    pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                   CMapScreenKey);
    if (!pScreenPriv)
        return BadImplementation;

    if (gamma.red < GAMMA_MIN || gamma.red > GAMMA_MAX ||
        gamma.green < GAMMA_MIN || gamma.green > GAMMA_MAX ||
        gamma.blue < GAMMA_MIN || gamma.blue > GAMMA_MAX)
        return BadValue;

    pScrn.gamma.red = gamma.red;
    pScrn.gamma.green = gamma.green;
    pScrn.gamma.blue = gamma.blue;

    ComputeGamma(pScrn, pScreenPriv);

    /* mark all colormaps on this screen */
    pLink = pScreenPriv.maps;
    while (pLink) {
        pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&pLink.cmap.devPrivates,
                                                      CMapColormapKey);
        pColPriv.recalculate = TRUE;
        pLink = pLink.next;
    }

    if (GetInstalledmiColormap(pScreen) &&
        ((pScreenPriv.flags & CMAP_LOAD_EVEN_IF_OFFSCREEN) ||
         pScrn.vtSema || pScreenPriv.isDGAmode)) {
        ColormapPtr pMap = GetInstalledmiColormap(pScreen);

        if (!(pScreenPriv.flags & CMAP_PALETTED_TRUECOLOR) &&
            (pMap.pVisual.class_ == TrueColor) &&
            CMapColormapUseMax(pMap.pVisual, pScreenPriv)) {

            /* if the current map doesn't have a palette look
               for another map to change the gamma on. */

            pLink = pScreenPriv.maps;
            while (pLink) {
                if (pLink.cmap.pVisual.class_ == PseudoColor)
                    break;
                pLink = pLink.next;
            }

            if (pLink) {
                /* need to trick CMapRefreshColors() into thinking
                   this is the currently installed map */
                SetInstalledmiColormap(pScreen, pLink.cmap);
                CMapReinstallMap(pLink.cmap);
                SetInstalledmiColormap(pScreen, pMap);
            }
        }
        else
            CMapReinstallMap(pMap);
    }

    pScrn.ChangeGamma = *pScreenPriv.ChangeGamma;
    if (pScrn.ChangeGamma)
        ret = pScrn.ChangeGamma(pScrn, gamma);
    pScrn.ChangeGamma = &CMapChangeGamma;

    return ret;
}

private void ComputeGammaRamp(CMapScreenPtr priv, ushort* red, ushort* green, ushort* blue)
{
    int elements = priv.gammaElements;
    LOCO* entry = priv.gamma;
    int shift = 16 - priv.sigRGBbits;

    while (elements--) {
        entry.red = *(red++) >> shift;
        entry.green = *(green++) >> shift;
        entry.blue = *(blue++) >> shift;
        entry++;
    }
}

int xf86ChangeGammaRamp(ScreenPtr pScreen, int size, ushort* red, ushort* green, ushort* blue)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    CMapColormapPtr pColPriv = void;
    CMapScreenPtr pScreenPriv = void;
    CMapLinkPtr pLink = void;

    if (!mixin(CMapScreenKeyRegistered))
        return BadImplementation;

    pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                   CMapScreenKey);
    if (!pScreenPriv)
        return BadImplementation;

    if (pScreenPriv.gammaElements != size)
        return BadValue;

    ComputeGammaRamp(pScreenPriv, red, green, blue);

    /* mark all colormaps on this screen */
    pLink = pScreenPriv.maps;
    while (pLink) {
        pColPriv = cast(CMapColormapPtr) dixLookupPrivate(&pLink.cmap.devPrivates,
                                                      CMapColormapKey);
        pColPriv.recalculate = TRUE;
        pLink = pLink.next;
    }

    if (GetInstalledmiColormap(pScreen) &&
        ((pScreenPriv.flags & CMAP_LOAD_EVEN_IF_OFFSCREEN) ||
         pScrn.vtSema || pScreenPriv.isDGAmode)) {
        ColormapPtr pMap = GetInstalledmiColormap(pScreen);

        if (!(pScreenPriv.flags & CMAP_PALETTED_TRUECOLOR) &&
            (pMap.pVisual.class_ == TrueColor) &&
            CMapColormapUseMax(pMap.pVisual, pScreenPriv)) {

            /* if the current map doesn't have a palette look
               for another map to change the gamma on. */

            pLink = pScreenPriv.maps;
            while (pLink) {
                if (pLink.cmap.pVisual.class_ == PseudoColor)
                    break;
                pLink = pLink.next;
            }

            if (pLink) {
                /* need to trick CMapRefreshColors() into thinking
                   this is the currently installed map */
                SetInstalledmiColormap(pScreen, pLink.cmap);
                CMapReinstallMap(pLink.cmap);
                SetInstalledmiColormap(pScreen, pMap);
            }
        }
        else
            CMapReinstallMap(pMap);
    }

    return Success;
}

int xf86GetGammaRampSize(ScreenPtr pScreen)
{
    CMapScreenPtr pScreenPriv = void;

    if (!mixin(CMapScreenKeyRegistered))
        return 0;

    pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                   CMapScreenKey);
    if (!pScreenPriv)
        return 0;

    return pScreenPriv.gammaElements;
}

int xf86GetGammaRamp(ScreenPtr pScreen, int size, ushort* red, ushort* green, ushort* blue)
{
    CMapScreenPtr pScreenPriv = void;
    LOCO* entry = void;
    int shift = void, sigbits = void;

    if (!mixin(CMapScreenKeyRegistered))
        return BadImplementation;

    pScreenPriv = cast(CMapScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                   CMapScreenKey);
    if (!pScreenPriv)
        return BadImplementation;

    if (size > pScreenPriv.gammaElements)
        return BadValue;

    entry = pScreenPriv.gamma;
    sigbits = pScreenPriv.sigRGBbits;

    while (size--) {
        *red = cast(ushort)(entry.red << (16 - sigbits));
        *green = cast(ushort)(entry.green << (16 - sigbits));
        *blue = cast(ushort)(entry.blue << (16 - sigbits));
        shift = sigbits;
        while (shift < 16) {
            *red |= *red >> shift;
            *green |= *green >> shift;
            *blue |= *blue >> shift;
            shift += sigbits;
        }
        red++;
        green++;
        blue++;
        entry++;
    }

    return Success;
}

int xf86ChangeGamma(ScreenPtr pScreen, Gamma gamma)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    if (pScrn.ChangeGamma)
        return (*pScrn.ChangeGamma) (pScrn, gamma);

    return BadImplementation;
}
