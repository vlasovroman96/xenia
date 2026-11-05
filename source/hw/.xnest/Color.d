module Color;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/
import build.xorg_config;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import externs.xcb.xcb;

import dix.colormap_priv;
import os.osdep;
import dix.window_priv;

import dix.scrnintstr;
import dix.window;
import dix.resource;

import xnest_xcb;


import Display;
import Screen;
import Color;
import XNWindow;
import Args;

import externs.xcb.xcb_icccm;

DevPrivateKeyRec xnestColormapPrivateKeyRec;

private DevPrivateKeyRec cmapScrPrivateKeyRec;

enum cmapScrPrivateKey = (&cmapScrPrivateKeyRec);

enum string GetInstalledColormap(string s) = `(cast(ColormapPtr) dixLookupPrivate(&(` ~ s ~ `).devPrivates, cmapScrPrivateKey))`;
enum string SetInstalledColormap(string s,string c) = `(dixSetPrivate(&(` ~ s ~ `).devPrivates, cmapScrPrivateKey, ` ~ c ~ `))`;

private Bool load_colormap(ColormapPtr pCmap, int ncolors, uint* colors)
{
    xcb_generic_error_t* err = null;
    xcb_query_colors_reply_t* reply = xcb_query_colors_reply(
        xnestUpstreamInfo.conn,
        xcb_query_colors(
            xnestUpstreamInfo.conn,
            xnestColormap(pCmap),
            ncolors,
            colors),
        &err);

    if (!reply) {
        LogMessage(X_WARNING, "load_colormap(): missing reply for QueryColors request\n");
        free(colors);
        return FALSE;
    }

    if (xcb_query_colors_colors_length(reply) != ncolors) {
        LogMessage(X_WARNING, "load_colormap(): received wrong number of entries: %d - expected %d\n",
            xcb_query_colors_colors_length(reply), ncolors);
        free(reply);
        free(colors);
        return FALSE;
    }

    xcb_rgb_t* rgb = xcb_query_colors_colors(reply);
    for (int i = 0; i < ncolors; i++) {
        pCmap.red[i].co.local.red = rgb[i].red;
        pCmap.green[i].co.local.green = rgb[i].green;
        pCmap.blue[i].co.local.blue = rgb[i].blue;
    }

    free(colors);
    free(reply);
    return TRUE;
}

Bool xnestCreateColormap(ColormapPtr pCmap)
{
    VisualPtr pVisual = pCmap.pVisual;
    int ncolors = pVisual.ColormapEntries;

    const(uint) cmap = xcb_generate_id(xnestUpstreamInfo.conn);
    xnestColormapPriv(pCmap).colormap = cmap;

    xcb_create_colormap(xnestUpstreamInfo.conn,
                        (pVisual.class_ & DynamicClass) ? XCB_COLORMAP_ALLOC_ALL : XCB_COLORMAP_ALLOC_NONE,
                        cmap,
                        xnestDefaultWindows[pCmap.pScreen.myNum],
                        xnest_visual_map_to_upstream(pVisual.vid));

    switch (pVisual.class_) {
    case StaticGray:           /* read only */
    case StaticColor:          /* read only */
    {
        uint* colors = cast(uint*) malloc(ncolors * uint.sizeof);
        for (int i = 0; i < ncolors; i++)
            colors[i] = i;
        return load_colormap(pCmap, ncolors, colors);
    }
    break;

    case TrueColor:            /* read only */
    {
        uint* colors = cast(uint*) malloc(ncolors * uint.sizeof);
        Pixel red = 0, redInc = mixin(lowbit!pVisual.redMask);
        Pixel green = 0, greenInc = mixin(lowbit!pVisual.greenMask);
        Pixel blue = 0, blueInc = mixin(lowbit!pVisual.blueMask);

        for (int i = 0; i < ncolors; i++) {
            colors[i] = red | green | blue;
            red += redInc;
            if (red > pVisual.redMask)
                red = 0L;
            green += greenInc;
            if (green > pVisual.greenMask)
                green = 0L;
            blue += blueInc;
            if (blue > pVisual.blueMask)
                blue = 0L;
        }
        return load_colormap(pCmap, ncolors, colors);
    }
    break;

    case GrayScale:            /* read and write */
        break;

    case PseudoColor:          /* read and write */
        break;

    case DirectColor:          /* read and write */
        break;
    default: break;}

    return TRUE;
}

void xnestDestroyColormap(ColormapPtr pCmap)
{
    xcb_free_colormap(xnestUpstreamInfo.conn, xnestColormap(pCmap));
}

enum SEARCH_PREDICATE = 
  `(xnestWindow(pWin) != XCB_WINDOW_NONE && mixin(wColormap!("pWin")) == icws->cmapIDs[i]);`;

private int xnestCountInstalledColormapWindows(WindowPtr pWin, void* ptr)
{
    xnestInstalledColormapWindows* icws = cast(xnestInstalledColormapWindows*) ptr;
    int i = void;

    for (i = 0; i < icws.numCmapIDs; i++)
        if (SEARCH_PREDICATE) {
            icws.numWindows++;
            return WT_DONTWALKCHILDREN;
        }

    return WT_WALKCHILDREN;
}

private int xnestGetInstalledColormapWindows(WindowPtr pWin, void* ptr)
{
    xnestInstalledColormapWindows* icws = cast(xnestInstalledColormapWindows*) ptr;
    int i = void;

    for (i = 0; i < icws.numCmapIDs; i++)
        if (SEARCH_PREDICATE) {
            icws.windows[icws.index++] = xnestWindow(pWin);
            return WT_DONTWALKCHILDREN;
        }

    return WT_WALKCHILDREN;
}

private xcb_window_t* xnestOldInstalledColormapWindows = null;
private int xnestNumOldInstalledColormapWindows = 0;

private Bool xnestSameInstalledColormapWindows(xcb_window_t* windows, int numWindows)
{
    if (xnestNumOldInstalledColormapWindows != numWindows)
        return FALSE;

    if (xnestOldInstalledColormapWindows == windows)
        return TRUE;

    if (xnestOldInstalledColormapWindows is null || windows is null)
        return FALSE;

    if (memcmp(xnestOldInstalledColormapWindows, windows,
               numWindows * xcb_window_t.sizeof))
        return FALSE;

    return TRUE;
}

void xnestSetInstalledColormapWindows(ScreenPtr pScreen)
{
    xnestInstalledColormapWindows icws = void;
    int numWindows = void;

    if (((icws.cmapIDs = calloc(pScreen.maxInstalledCmaps, Colormap.sizeof)) == 0))
        return;
    icws.numCmapIDs = xnestListInstalledColormaps(pScreen, icws.cmapIDs);
    icws.numWindows = 0;
    WalkTree(pScreen, &xnestCountInstalledColormapWindows, cast(void*) &icws);
    if (icws.numWindows) {
        icws.windows = calloc(icws.numWindows + 1, xcb_window_t.sizeof);
        icws.index = 0;
        WalkTree(pScreen, &xnestGetInstalledColormapWindows, cast(void*) &icws);
        icws.windows[icws.numWindows] = xnestDefaultWindows[pScreen.myNum];
        numWindows = icws.numWindows + 1;
    }
    else {
        icws.windows = null;
        numWindows = 0;
    }

    free(icws.cmapIDs);

    if (!xnestSameInstalledColormapWindows(icws.windows, icws.numWindows)) {
        free(xnestOldInstalledColormapWindows);

        xnest_wm_colormap_windows(xnestUpstreamInfo.conn,
                                  xnestDefaultWindows[pScreen.myNum],
                                  icws.windows,
                                  numWindows);

        xnestOldInstalledColormapWindows = icws.windows;
        xnestNumOldInstalledColormapWindows = icws.numWindows;

version (DUMB_WINDOW_MANAGERS) {
        /*
           This code is for dumb window managers.
           This will only work with default local visual colormaps.
         */
        if (icws.numWindows) {
            WindowPtr pWin = void;
            ColormapPtr pCmap = void;

            pWin = xnestWindowPtr(icws.windows[0]);

            if (xnest_visual_map_to_upstream(mixin(wVisual!("pWin"))) ==
                xnest_visual_map_to_upstream(pScreen.rootVisual))
                dixLookupResourceByType(cast(void**) &pCmap, mixin(wColormap!("pWin")),
                                        X11_RESTYPE_COLORMAP, serverClient,
                                        DixUseAccess);
            else
                dixLookupResourceByType(cast(void**) &pCmap,
                                        pScreen.defColormap, X11_RESTYPE_COLORMAP,
                                        serverClient, DixUseAccess);

            uint cmap = xnestColormap(pCmap);
            xcb_change_window_attributes(xnestUpstreamInfo.conn,
                                         xnestDefaultWindows[pScreen.myNum],
                                         XCB_CW_COLORMAP,
                                         &cmap);
        }
}                          /* DUMB_WINDOW_MANAGERS */
    }
    else
        free(icws.windows);
}

void xnestSetScreenSaverColormapWindow(ScreenPtr pScreen)
{
    free(xnestOldInstalledColormapWindows);

    xnest_wm_colormap_windows(xnestUpstreamInfo.conn,
                              xnestDefaultWindows[pScreen.myNum],
                              &xnestScreenSaverWindows[pScreen.myNum],
                              1);

    xnestOldInstalledColormapWindows = null;
    xnestNumOldInstalledColormapWindows = 0;

    xnestDirectUninstallColormaps(pScreen);
}

void xnestDirectInstallColormaps(ScreenPtr pScreen)
{
    int i = void, n = void;
    Colormap[MAXCMAPS] pCmapIDs = void;

    if (!xnestDoDirectColormaps)
        return;

    n = (*pScreen.ListInstalledColormaps) (pScreen, pCmapIDs.ptr);

    for (i = 0; i < n; i++) {
        ColormapPtr pCmap = void;

        dixLookupResourceByType(cast(void**) &pCmap, pCmapIDs[i], X11_RESTYPE_COLORMAP,
                                serverClient, DixInstallAccess);
        if (pCmap)
            xcb_install_colormap(xnestUpstreamInfo.conn, xnestColormap(pCmap));
    }
}

void xnestDirectUninstallColormaps(ScreenPtr pScreen)
{
    int i = void, n = void;
    Colormap[MAXCMAPS] pCmapIDs = void;

    if (!xnestDoDirectColormaps)
        return;

    n = (*pScreen.ListInstalledColormaps) (pScreen, pCmapIDs.ptr);

    for (i = 0; i < n; i++) {
        ColormapPtr pCmap = void;

        dixLookupResourceByType(cast(void**) &pCmap, pCmapIDs[i], X11_RESTYPE_COLORMAP,
                                serverClient, DixUninstallAccess);
        if (pCmap)
            xcb_uninstall_colormap(xnestUpstreamInfo.conn, xnestColormap(pCmap));
    }
}

void xnestInstallColormap(ColormapPtr pCmap)
{
    ColormapPtr pOldCmap = mixin(GetInstalledColormap!(`pCmap.pScreen`));

    if (pCmap != pOldCmap) {
        xnestDirectUninstallColormaps(pCmap.pScreen);

        /* Uninstall pInstalledMap. Notify all interested parties. */
        if (pOldCmap != cast(ColormapPtr) XCB_COLORMAP_NONE)
            WalkTree(pCmap.pScreen, TellLostMap, cast(void*) &pOldCmap.mid);

        mixin(SetInstalledColormap!(`pCmap.pScreen`, `pCmap`));
        WalkTree(pCmap.pScreen, TellGainedMap, cast(void*) &pCmap.mid);

        xnestSetInstalledColormapWindows(pCmap.pScreen);
        xnestDirectInstallColormaps(pCmap.pScreen);
    }
}

void xnestUninstallColormap(ColormapPtr pCmap)
{
    ColormapPtr pCurCmap = mixin(GetInstalledColormap!(`pCmap.pScreen`));

    if (pCmap == pCurCmap) {
        if (pCmap.mid != pCmap.pScreen.defColormap) {
            dixLookupResourceByType(cast(void**) &pCurCmap,
                                    pCmap.pScreen.defColormap,
                                    X11_RESTYPE_COLORMAP,
                                    serverClient, DixInstallAccess);
            (*pCmap.pScreen.InstallColormap) (pCurCmap);
        }
    }
}

private Bool xnestInstalledDefaultColormap = FALSE;

int xnestListInstalledColormaps(ScreenPtr pScreen, Colormap* pCmapIDs)
{
    if (xnestInstalledDefaultColormap) {
        *pCmapIDs = mixin(GetInstalledColormap!(`pScreen`)).mid;
        return 1;
    }
    else
        return 0;
}

void xnestStoreColors(ColormapPtr pCmap, int nColors, xColorItem* pColors)
{
    if (pCmap.pVisual.class_ & DynamicClass)
        xcb_store_colors(xnestUpstreamInfo.conn,
                         xnestColormap(pCmap),
                         nColors,
                         cast(xcb_coloritem_t*) pColors);
}

void xnestResolveColor(ushort* pRed, ushort* pGreen, ushort* pBlue, VisualPtr pVisual)
{
    int shift = void;
    uint lim = void;

    shift = 16 - pVisual.bitsPerRGBValue;
    lim = (1 << pVisual.bitsPerRGBValue) - 1;

    if ((pVisual.class_ == PseudoColor) || (pVisual.class_ == DirectColor)) {
        /* rescale to rgb bits */
        *pRed = ((*pRed >> shift) * 65535) / lim;
        *pGreen = ((*pGreen >> shift) * 65535) / lim;
        *pBlue = ((*pBlue >> shift) * 65535) / lim;
    }
    else if (pVisual.class_ == GrayScale) {
        /* rescale to gray then rgb bits */
        *pRed = (30L * *pRed + 59L * *pGreen + 11L * *pBlue) / 100;
        *pBlue = *pGreen = *pRed = ((*pRed >> shift) * 65535) / lim;
    }
    else if (pVisual.class_ == StaticGray) {
        uint limg = void;

        limg = pVisual.ColormapEntries - 1;
        /* rescale to gray then [0..limg] then [0..65535] then rgb bits */
        *pRed = (30L * *pRed + 59L * *pGreen + 11L * *pBlue) / 100;
        *pRed = ((((*pRed * (limg + 1))) >> 16) * 65535) / limg;
        *pBlue = *pGreen = *pRed = ((*pRed >> shift) * 65535) / lim;
    }
    else {
        uint limr = void, limg = void, limb = void;

        limr = pVisual.redMask >> pVisual.offsetRed;
        limg = pVisual.greenMask >> pVisual.offsetGreen;
        limb = pVisual.blueMask >> pVisual.offsetBlue;
        /* rescale to [0..limN] then [0..65535] then rgb bits */
        *pRed = ((((((*pRed * (limr + 1)) >> 16) *
                    65535) / limr) >> shift) * 65535) / lim;
        *pGreen = ((((((*pGreen * (limg + 1)) >> 16) *
                      65535) / limg) >> shift) * 65535) / lim;
        *pBlue = ((((((*pBlue * (limb + 1)) >> 16) *
                     65535) / limb) >> shift) * 65535) / lim;
    }
}

Bool xnestCreateDefaultColormap(ScreenPtr pScreen)
{
    VisualPtr pVisual = void;
    ColormapPtr pCmap = void;
    ushort zero = 0, ones = 0xFFFF;
    Pixel wp = void, bp = void;

    if (!dixRegisterPrivateKey(&cmapScrPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    for (pVisual = pScreen.visuals;
         pVisual.vid != pScreen.rootVisual; pVisual++){}

    if (dixCreateColormap(pScreen.defColormap, pScreen, pVisual, &pCmap,
                       (pVisual.class_ & DynamicClass) ? AllocNone : AllocAll,
                       serverClient)
        != Success)
        return FALSE;

    wp = pScreen.whitePixel;
    bp = pScreen.blackPixel;
    if ((AllocColor(pCmap, &ones, &ones, &ones, &wp, 0) !=
         Success) ||
        (AllocColor(pCmap, &zero, &zero, &zero, &bp, 0) != Success))
        return FALSE;
    pScreen.whitePixel = wp;
    pScreen.blackPixel = bp;
    (*pScreen.InstallColormap) (pCmap);

    xnestInstalledDefaultColormap = TRUE;

    return TRUE;
}
