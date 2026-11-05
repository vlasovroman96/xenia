module mi.miscrinit;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1990, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

import build.xlibre_server;


//import x11.X;
// //import externs.X11.extensions.shm;

import include.shmint;
import mi.mi_priv;

import include.servermd;
import common.misc;
import include.scrnintstr;
import dix.pixmap;
import mi.miline;
import dix.dixutils;
import mi.mivaltree;


/* We use this structure to propagate some information from miScreenInit to
 * miCreateScreenResources.  miScreenInit allocates the structure, fills it
 * in, and puts it into pScreen->devPrivate.  miCreateScreenResources
 * extracts the info and frees the structure.  We could've accomplished the
 * same thing by adding fields to the screen structure, but they would have
 * ended up being redundant, and would have exposed this mi implementation
 * detail to the whole server.
 */

struct _MiScreenInitParmsRec {
    void* pbits;                /* pointer to framebuffer */
    int width;                  /* delta to add to a framebuffer addr to move one row down */
    int xsize;
    int ysize;
}alias miScreenInitParmsRec = _MiScreenInitParmsRec;
alias miScreenInitParmsPtr = miScreenInitParmsRec*;

enum DEFAULTZEROLINEBIAS = (OCTANT2 | OCTANT3 | OCTANT4 | OCTANT5);

/* this plugs into pScreen->ModifyPixmapHeader */
Bool miModifyPixmapHeader(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
    if (!pPixmap)
        return FALSE;

    /*
     * If all arguments are specified, reinitialize everything (including
     * validated state).
     */
    if ((width > 0) && (height > 0) && (depth > 0) && (bitsPerPixel > 0) &&
        (devKind > 0) && pPixData) {
        pPixmap.drawable.depth = cast(ubyte)depth;
        pPixmap.drawable.bitsPerPixel = cast(ubyte)bitsPerPixel;
        pPixmap.drawable.id = 0;
        pPixmap.drawable.x = 0;
        pPixmap.drawable.y = 0;
        pPixmap.drawable.width = cast(ushort)width;
        pPixmap.drawable.height = cast(ushort)height;
        pPixmap.devKind = devKind;
        pPixmap.refcnt = 1;
        pPixmap.devPrivate.ptr = pPixData;
    }
    else {
        /*
         * Only modify specified fields, keeping all others intact.
         */

        if (width > 0)
            pPixmap.drawable.width = cast(ushort)width;

        if (height > 0)
            pPixmap.drawable.height = cast(ushort)height;

        if (depth > 0)
            pPixmap.drawable.depth = cast(ubyte)depth;

        if (bitsPerPixel > 0)
            pPixmap.drawable.bitsPerPixel = cast(ubyte)bitsPerPixel;
        else if ((bitsPerPixel < 0) && (depth > 0))
            pPixmap.drawable.bitsPerPixel = cast(ubyte)mixin(BitsPerPixel!("depth"));

        /*
         * CAVEAT:  Non-SI DDXen may use devKind and devPrivate fields for
         *          other purposes.
         */
        if (devKind > 0)
            pPixmap.devKind = devKind;
        else if ((devKind < 0) && ((width > 0) || (depth > 0)))
            pPixmap.devKind = PixmapBytePad(pPixmap.drawable.width,
                                             pPixmap.drawable.depth);

        if (pPixData)
            pPixmap.devPrivate.ptr = pPixData;
    }
    pPixmap.drawable.serialNumber = NEXT_SERIAL_NUMBER;
    return TRUE;
}

private Bool miCloseScreen(ScreenPtr pScreen)
{
    dixDestroyPixmap(cast(PixmapPtr) pScreen.devPrivate, 0);
    return TRUE;
}

private Bool miSaveScreen(ScreenPtr pScreen, int on)
{
    return TRUE;
}

void miSourceValidate(DrawablePtr pDrawable, int x, int y, int w, int h, uint subWindowMode)
{
}


/* With the introduction of pixmap privates, the "screen pixmap" can no
 * longer be created in miScreenInit, since all the modules that could
 * possibly ask for pixmap private space have not been initialized at
 * that time.  pScreen->CreateScreenResources is called after all
 * possible private-requesting modules have been inited; we create the
 * screen pixmap here.
 */
Bool miCreateScreenResources(ScreenPtr pScreen)
{
    miScreenInitParmsPtr pScrInitParms = void;
    void* value = void;

    pScrInitParms = cast(miScreenInitParmsPtr) pScreen.devPrivate;

    /* if width is non-zero, pScreen->devPrivate will be a pixmap
     * else it will just take the value pbits
     */
    if (pScrInitParms.width) {
        PixmapPtr pPixmap = void;

        /* create a pixmap with no data, then redirect it to point to
         * the screen
         */
        pPixmap =
            (*pScreen.CreatePixmap) (pScreen, 0, 0, pScreen.rootDepth, 0);
        if (!pPixmap)
            return FALSE;

        if (!(*pScreen.ModifyPixmapHeader) (pPixmap, pScrInitParms.xsize,
                                             pScrInitParms.ysize,
                                             pScreen.rootDepth,
                                             mixin(BitsPerPixel!("pScreen.rootDepth")),
                                             PixmapBytePad(pScrInitParms.width,
                                                           pScreen.rootDepth),
                                             pScrInitParms.pbits))
            return FALSE;
        value = cast(void*) pPixmap;
    }
    else {
        value = pScrInitParms.pbits;
    }
    free(pScreen.devPrivate);  /* freeing miScreenInitParmsRec */
    pScreen.devPrivate = value;        /* pPixmap or pbits */
    return TRUE;
}

private Bool miScreenDevPrivateInit(ScreenPtr pScreen, int width, void* pbits, int xsize, int ysize)
{
    /* Stash pbits and width in a short-lived miScreenInitParmsRec attached
     * to the screen, until CreateScreenResources can put them in the
     * screen pixmap.
     */
    miScreenInitParmsPtr pScrInitParms = cast(miScreenInitParmsRec*) calloc(1, miScreenInitParmsRec.sizeof);
    if (!pScrInitParms)
        return FALSE;
    pScrInitParms.pbits = pbits;
    pScrInitParms.width = width;
    pScrInitParms.xsize = xsize;
    pScrInitParms.ysize = ysize;
    pScreen.devPrivate = cast(void*) pScrInitParms;
    return TRUE;
}

private PixmapPtr miGetScreenPixmap(ScreenPtr pScreen)
{
    return cast(PixmapPtr) (pScreen.devPrivate);
}

private void miSetScreenPixmap(PixmapPtr pPix)
{
    if (pPix)
        pPix.drawable.pScreen.devPrivate = cast(void*) pPix;
}

Bool miScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int rootDepth, int numDepths, DepthRec* depths, VisualID rootVisual, int numVisuals, VisualRec* visuals)
{
    pScreen.width = cast(short)xsize;
    pScreen.height = cast(short)ysize;
    pScreen.mmWidth = cast(short)((xsize * 254 + dpix * 5) / (dpix * 10));
    pScreen.mmHeight = cast(short)((ysize * 254 + dpiy * 5) / (dpiy * 10));
    pScreen.numDepths = cast(short)numDepths;
    pScreen.rootDepth = cast(ubyte)rootDepth;
    pScreen.allowedDepths = depths;
    pScreen.rootVisual = rootVisual;
    /* defColormap */
    pScreen.minInstalledCmaps = 1;
    pScreen.maxInstalledCmaps = 1;
    pScreen.backingStoreSupport = NotUseful;
    pScreen.saveUnderSupport = NotUseful;
    /* whitePixel, blackPixel */
    pScreen.ModifyPixmapHeader = &miModifyPixmapHeader;
    pScreen.CreateScreenResources = &miCreateScreenResources;
    pScreen.GetScreenPixmap = &miGetScreenPixmap;
    pScreen.SetScreenPixmap = &miSetScreenPixmap;
    pScreen.numVisuals = cast(short)numVisuals;
    pScreen.visuals = visuals;
    if (width) {
static if(CONFIG_MITSHM){
        ShmRegisterFbFuncs(pScreen);
} /* CONFIG_MITSHM */
        pScreen.CloseScreen = &miCloseScreen;
    }
    /* else CloseScreen */
    /* QueryBestSize */
    pScreen.SaveScreen = &miSaveScreen;
    /* GetImage, GetSpans */
    pScreen.SourceValidate = &miSourceValidate;
    /* CreateWindow, DestroyWindow, PositionWindow, ChangeWindowAttributes */
    /* RealizeWindow, UnrealizeWindow */
    pScreen.ValidateTree = &miValidateTree;
    pScreen.PostValidateTree = cast(PostValidateTreeProcPtr) 0;
    pScreen.WindowExposures = &miWindowExposures;
    /* CopyWindow */
    pScreen.ClearToBackground = &miClearToBackground;
    pScreen.ClipNotify = cast(ClipNotifyProcPtr) 0;
    pScreen.RestackWindow = cast(RestackWindowProcPtr) 0;
    pScreen.PaintWindow = &miPaintWindow;
    /* CreatePixmap, DestroyPixmap */
    /* RealizeFont, UnrealizeFont */
    /* CreateGC */
    /* CreateColormap, DestroyColormap, InstallColormap, UninstallColormap */
    /* ListInstalledColormaps, StoreColors, ResolveColor */
    /* BitmapToRegion */
    pScreen.BlockHandler = cast(ScreenBlockHandlerProcPtr) &NoopDDA;
    pScreen.WakeupHandler = cast(ScreenWakeupHandlerProcPtr) &NoopDDA;
    pScreen.MarkWindow = &miMarkWindow;
    pScreen.MarkOverlappedWindows = &miMarkOverlappedWindows;
    pScreen.MoveWindow = &miMoveWindow;
    pScreen.ResizeWindow = &miResizeWindow;
    pScreen.GetLayerWindow = &miGetLayerWindow;
    pScreen.HandleExposures = &miHandleValidateExposures;
    pScreen.ReparentWindow = cast(ReparentWindowProcPtr) 0;
    pScreen.ChangeBorderWidth = &miChangeBorderWidth;
    pScreen.SetShape = &miSetShape;
    pScreen.MarkUnrealizedWindow = &miMarkUnrealizedWindow;
    pScreen.XYToWindow = &miXYToWindow;

    miSetZeroLineBias(pScreen, DEFAULTZEROLINEBIAS);

    return miScreenDevPrivateInit(pScreen, width, pbits, xsize, ysize);
}

// DevPrivateKeyRec miZeroLineScreenKeyRec;

void miSetZeroLineBias(ScreenPtr pScreen, uint bias)
{
    if (!dixRegisterPrivateKey(&miZeroLineScreenKeyRec, PRIVATE_SCREEN, 0))
        return;

    dixSetPrivate(&pScreen.devPrivates, miZeroLineScreenKey,
                  cast(c_ulong*) cast(c_ulong) bias);
}

void miScreenClose(ScreenPtr pScreen)
{
    if (pScreen.devPrivate) {
        free(pScreen.devPrivate);
        pScreen.devPrivate = null;
    }
}
