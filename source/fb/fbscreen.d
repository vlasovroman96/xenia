module fbscreen;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1998 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import fb.fb_priv;
import os.osdep;
import dix.pixmap;
import dix.resource;
import fb.fbpixmap;
import fb.fbgc;
import dix.dixutils;
import mi.miscrinit;
import fb.fb;
import dix.colormap_priv;
import dix.dixstruct_priv;

Bool fbCloseScreen(ScreenPtr pScreen)
{
    int d = void;
    DepthPtr depths = pScreen.allowedDepths;

    fbDestroyGlyphCache();
    for (d = 0; d < pScreen.numDepths; d++)
        free(depths[d].vids);
    free(depths);
    free(pScreen.visuals);
    if (pScreen.devPrivate)
        FreePixmap(cast(PixmapPtr)pScreen.devPrivate);
    return TRUE;
}

Bool fbRealizeFont(ScreenPtr pScreen, FontPtr pFont)
{
    return TRUE;
}

Bool fbUnrealizeFont(ScreenPtr pScreen, FontPtr pFont)
{
    return TRUE;
}

void fbQueryBestSize(int class_, ushort* width, ushort* height, ScreenPtr pScreen)
{
    ushort w = void;

    switch (class_) {
    case CursorShape:
        if (*width > pScreen.width)
            *width = pScreen.width;
        if (*height > pScreen.height)
            *height = pScreen.height;
        break;
    case TileShape:
    case StippleShape:
        w = *width;
        if ((w & (w - 1)) && w < FB_UNIT) {
            for (w = 1; w < *width; w <<= 1){}
            *width = cast(ubyte)w;
        }
    goto default;
    default: break;}
}

PixmapPtr _fbGetWindowPixmap(WindowPtr pWindow)
{
    return mixin(fbGetWindowPixmap!("pWindow"));
}

void _fbSetWindowPixmap(WindowPtr pWindow, PixmapPtr pPixmap)
{
    dixSetPrivate(&pWindow.devPrivates, mixin(fbGetWinPrivateKey!("pWindow")), pPixmap);
}

Bool fbSetupScreen(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp)
{                               /* bits per pixel for screen */
    if (!fbAllocatePrivates(pScreen))
        return FALSE;
    pScreen.defColormap = dixAllocServerXID();
    if (bpp > 1) {
	/* let CreateDefColormap do whatever it wants for pixels */
	pScreen.blackPixel = pScreen.whitePixel = cast(Pixel) 0;
    }
    pScreen.QueryBestSize = &fbQueryBestSize;
    /* SaveScreen */
    pScreen.GetImage = &fbGetImage;
    pScreen.GetSpans = &fbGetSpans;
    pScreen.CreateWindow = &fbCreateWindow;
    pScreen.DestroyWindow = &fbDestroyWindow;
    pScreen.PositionWindow = &fbPositionWindow;
    pScreen.ChangeWindowAttributes = &fbChangeWindowAttributes;
    pScreen.RealizeWindow = &fbRealizeWindow;
    pScreen.UnrealizeWindow = &fbUnrealizeWindow;
    pScreen.CopyWindow = &fbCopyWindow;
    pScreen.CreatePixmap = &fbCreatePixmap;
    pScreen.DestroyPixmap = &fbDestroyPixmap;
    pScreen.RealizeFont = &fbRealizeFont;
    pScreen.UnrealizeFont = &fbUnrealizeFont;
    pScreen.CreateGC = &fbCreateGC;
    if (bpp == 1) {
	pScreen.CreateColormap = &mfbCreateColormap;
    } else {
	pScreen.CreateColormap = &fbInitializeColormap;
    }

    alias fn1 = extern(C) void function(ColormapPtr) @nogc nothrow;
    alias fn2 = extern(C) void function(ColormapPtr, int, xColorItem*) @nogc nothrow;
    pScreen.DestroyColormap = cast(fn1) &NoopDDA;
    pScreen.InstallColormap = &fbInstallColormap;
    pScreen.UninstallColormap = &fbUninstallColormap;
    pScreen.ListInstalledColormaps = &fbListInstalledColormaps;
    pScreen.StoreColors = cast(fn2) &NoopDDA;
    pScreen.ResolveColor = &fbResolveColor;
    pScreen.BitmapToRegion = &fbPixmapToRegion;

    pScreen.GetWindowPixmap = &_fbGetWindowPixmap;
    pScreen.SetWindowPixmap = &_fbSetWindowPixmap;

    return TRUE;
}


static if(FB_ACCESS_WRAPPER) {
    Bool wfbFinishScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp, SetupWrapProcPtr setupWrap, FinishWrapProcPtr finishWrap) {
        VisualPtr visuals = void;
        DepthPtr depths = void;
        int nvisuals = void;
        int ndepths = void;
        int rootdepth = void;
        VisualID defaultVisual = void;

        int stride = void;

        ysize -= 2;
        stride = (width * bpp) / 8;
        fbSetBits(cast(FbStip*) pbits, stride / FbStip.sizeof, FB_HEAD_BITS);
        pbits = cast(void*) (cast(char*) pbits + stride);
        fbSetBits(cast(FbStip*) (cast(char*) pbits + stride * ysize),
                stride / FbStip.sizeof, FB_TAIL_BITS);
        /* fb requires power-of-two bpp */
        if (Ones(bpp) != 1)
            return FALSE;
        fbGetScreenPrivate(pScreen).setupWrap = setupWrap;
        fbGetScreenPrivate(pScreen).finishWrap = finishWrap;
        rootdepth = 0;
        if (!fbInitVisuals(&visuals, &depths, &nvisuals, &ndepths, &rootdepth,
                        &defaultVisual, (cast(c_ulong) 1 << (bpp - 1)),
                        8))
            return FALSE;
        if (!miScreenInit(pScreen, pbits, xsize, ysize, dpix, dpiy, width,
                        rootdepth, ndepths, depths,
                        defaultVisual, nvisuals, visuals))
            return FALSE;
        /* overwrite miCloseScreen with our own */
        pScreen.CloseScreen = fbCloseScreen;
        return TRUE;
    }
}
else {
    Bool fbFinishScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp) {
        VisualPtr visuals = void;
        DepthPtr depths = void;
        int nvisuals = void;
        int ndepths = void;
        int rootdepth = void;
        VisualID defaultVisual = void;
        /* fb requires power-of-two bpp */
        if (Ones(bpp) != 1)
            return FALSE;
        rootdepth = 0;
        if (!fbInitVisuals(&visuals, &depths, &nvisuals, &ndepths, &rootdepth,
                        &defaultVisual, (cast(c_ulong) 1 << (bpp - 1)),
                        8))
            return FALSE;
        if (!miScreenInit(pScreen, pbits, xsize, ysize, dpix, dpiy, width,
                        rootdepth, ndepths, depths,
                        defaultVisual, nvisuals, visuals))
            return FALSE;
        /* overwrite miCloseScreen with our own */
        pScreen.CloseScreen = &fbCloseScreen;
        return TRUE;
    }
}
import build.xorg_config;

/* dts * (inch/dot) * (25.4 mm / inch) = mm */
static if (FB_ACCESS_WRAPPER) {
    Bool wfbScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp, SetupWrapProcPtr setupWrap, FinishWrapProcPtr finishWrap)
    {
        if (!fbSetupScreen(pScreen, pbits, xsize, ysize, dpix, dpiy, width, bpp))
            return FALSE;
        if (!wfbFinishScreenInit(pScreen, pbits, xsize, ysize, dpix, dpiy,
                                width, bpp, setupWrap, finishWrap))
            return FALSE;
        return TRUE;
    }
} else {
    Bool fbScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp)
    {
        if (!fbSetupScreen(pScreen, pbits, xsize, ysize, dpix, dpiy, width, bpp))
            return FALSE;
        if (!fbFinishScreenInit(pScreen, pbits, xsize, ysize, dpix, dpiy,
                                width, bpp))
            return FALSE;
        return TRUE;
    }
}
