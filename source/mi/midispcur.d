module mi.midispcur;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * midispcur.c
 *
 * machine independent cursor display routines
 */

/*

Copyright 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.
*/

import build.dix_config;

//import   x11.X;

import   dix.dix_priv;
import   dix.gc_priv;
import   dix.screen_hooks_priv;
import   dix.screenint_priv;

import   include.misc;
import   include.input;
import   dix.cursor;
import include.windowstr;
import include.regionstr;
import include.dixstruct;
import   include.scrnintstr;
import   include.servermd;
import   include.mipointer;
import   mi.misprite;
import   include.gcstruct;
import   include.picturestr;
import include.inputstr;
import dix.screen_hooks;
import render.picture;
import dix.gc;
import externs.X11.extensions.render_;
import dix.events;
import dix.devices;
import dix.gc;

/* per-screen private data */
private DevPrivateKeyRec miDCScreenKeyRec;

enum miDCScreenKey = (&miDCScreenKeyRec);

private DevScreenPrivateKeyRec miDCDeviceKeyRec;

enum miDCDeviceKey = (&miDCDeviceKeyRec);



/* per device private data */
struct _MiDCBufferRec {
    GCPtr pSourceGC, pMaskGC;
    GCPtr pSaveGC, pRestoreGC;
    PixmapPtr pSave;
    PicturePtr pRootPicture;
}alias miDCBufferRec = _MiDCBufferRec;
alias miDCBufferPtr = miDCBufferRec*;

enum string miGetDCDevice(string dev, string screen) = `
 ((DevHasCursor(` ~ dev ~ `)) ? 
  cast(miDCBufferPtr)dixLookupScreenPrivate(&` ~ dev ~ `.devPrivates, miDCDeviceKey, ` ~ screen ~ `) : 
  cast(miDCBufferPtr)dixLookupScreenPrivate(&GetMaster(` ~ dev ~ `, MASTER_POINTER).devPrivates, miDCDeviceKey, ` ~ screen ~ `))`;

/*
 * The core pointer buffer will point to the index of the virtual pointer
 * in the pCursorBuffers array.
 */
struct _MiDCScreenRec {
    PixmapPtr sourceBits;       /* source bits */
    PixmapPtr maskBits;         /* mask bits */
    PicturePtr pPicture;
    CursorPtr pCursor;
}alias miDCScreenRec = _MiDCScreenRec;
alias miDCScreenPtr = miDCScreenRec*;

enum string miGetDCScreen(string s) = `(cast(miDCScreenPtr)(dixLookupPrivate(&(` ~ s ~ `).devPrivates, miDCScreenKey)))`;

Bool miDCInitialize(ScreenPtr pScreen, miPointerScreenFuncPtr screenFuncs)
{
    miDCScreenPtr pScreenPriv = void;

    if (!dixRegisterPrivateKey(&miDCScreenKeyRec, PRIVATE_SCREEN, 0) ||
        !dixRegisterScreenPrivateKey(&miDCDeviceKeyRec, pScreen, PRIVATE_DEVICE,
                                     0))
        return FALSE;

    pScreenPriv = cast(miDCScreenRec*) calloc(1, miDCScreenRec.sizeof);
    if (!pScreenPriv)
        return FALSE;

    dixScreenHookPostClose(pScreen, &miDCCloseScreen);
    dixSetPrivate(&pScreen.devPrivates, miDCScreenKey, pScreenPriv);

    if (!miSpriteInitialize(pScreen, screenFuncs)) {
        free(cast(void*) pScreenPriv);
        return FALSE;
    }
    return TRUE;
}

private void miDCSwitchScreenCursor(ScreenPtr pScreen, CursorPtr pCursor, PixmapPtr sourceBits, PixmapPtr maskBits, PicturePtr pPicture)
{
    miDCScreenPtr pScreenPriv = cast(_MiDCScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miDCScreenKey);
    if (!pScreenPriv)
        return;

    dixDestroyPixmap(pScreenPriv.sourceBits, 0);
    pScreenPriv.sourceBits = sourceBits;

    if (pScreenPriv.maskBits)
    dixDestroyPixmap(pScreenPriv.maskBits, 0);
    pScreenPriv.maskBits = maskBits;

    if (pScreenPriv.pPicture)
        FreePicture(pScreenPriv.pPicture, 0);
    pScreenPriv.pPicture = pPicture;

    pScreenPriv.pCursor = pCursor;
}

private void miDCCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookPostClose(pScreen, &miDCCloseScreen);

    miDCScreenPtr pScreenPriv = void;
    pScreenPriv = cast(miDCScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                   miDCScreenKey);
    miDCSwitchScreenCursor(pScreen, null, null, null, null);
    free(cast(void*) pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, miDCScreenKey, null); /* clear it, just for sure */
}

bool miDCRealizeCursor(ScreenPtr pScreen, CursorPtr pCursor)
{
    return TRUE;
}

enum string EnsurePicture(string picture,string draw,string win) = `(` ~ picture ~ ` || miDCMakePicture(&` ~ picture ~ `,` ~ draw ~ `,` ~ win ~ `))`;

private PicturePtr miDCMakePicture(PicturePtr* ppPicture, DrawablePtr pDraw, WindowPtr pWin)
{
    PictFormatPtr pFormat = void;
    XID subwindow_mode = IncludeInferiors;
    PicturePtr pPicture = void;
    int error = void;

    pFormat = PictureWindowFormat(pWin);
    if (!pFormat)
        return null;
    pPicture = CreatePicture(0, pDraw, pFormat,
                             CPSubwindowMode, &subwindow_mode,
                             serverClient, &error);
    *ppPicture = pPicture;
    return pPicture;
}

private Bool miDCRealize(ScreenPtr pScreen, CursorPtr pCursor)
{
    miDCScreenPtr pScreenPriv = cast(_MiDCScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miDCScreenKey);
    GCPtr pGC = void;
    ChangeGCVal gcvals = void;
    PixmapPtr sourceBits = void, maskBits = void;

    if (pScreenPriv.pCursor == pCursor)
        return TRUE;

    if (pCursor.bits.argb) {
        PixmapPtr pPixmap = void;
        PictFormatPtr pFormat = void;
        int error = void;
        PicturePtr pPicture = void;

        pFormat = PictureMatchFormat(pScreen, 32, PIXMAN_a8r8g8b8);
        if (!pFormat)
            return FALSE;

        pPixmap = (*pScreen.CreatePixmap) (pScreen, pCursor.bits.width,
                                            pCursor.bits.height, 32,
                                            CREATE_PIXMAP_USAGE_SCRATCH);
        if (!pPixmap)
            return FALSE;

        pGC = GetScratchGC(32, pScreen);
        if (!pGC) {
            dixDestroyPixmap(pPixmap, 0);
            return FALSE;
        }
        ValidateGC(&pPixmap.drawable, pGC);
        (*pGC.ops.PutImage) (&pPixmap.drawable, pGC, 32,
                               0, 0, pCursor.bits.width,
                               pCursor.bits.height,
                               0, ZPixmap, cast(char*) pCursor.bits.argb);
        FreeScratchGC(pGC);
        pPicture = CreatePicture(0, &pPixmap.drawable,
                                 pFormat, 0, null, serverClient, &error);
        dixDestroyPixmap(pPixmap, 0);
        if (!pPicture)
            return FALSE;

        miDCSwitchScreenCursor(pScreen, pCursor, null, null, pPicture);
        return TRUE;
    }

    sourceBits = (*pScreen.CreatePixmap) (pScreen, pCursor.bits.width,
                                           pCursor.bits.height, 1, 0);
    if (!sourceBits)
        return FALSE;

    maskBits = (*pScreen.CreatePixmap) (pScreen, pCursor.bits.width,
                                         pCursor.bits.height, 1, 0);
    if (!maskBits) {
        dixDestroyPixmap(sourceBits, 0);
        return FALSE;
    }

    /* create the two sets of bits, clipping as appropriate */

    pGC = GetScratchGC(1, pScreen);
    if (!pGC) {
        dixDestroyPixmap(sourceBits, 0);
        dixDestroyPixmap(maskBits, 0);
        return FALSE;
    }

    ValidateGC(cast(DrawablePtr) sourceBits, pGC);
    (*pGC.ops.PutImage) (cast(DrawablePtr) sourceBits, pGC, 1,
                           0, 0, pCursor.bits.width, pCursor.bits.height,
                           0, XYPixmap, cast(char*) pCursor.bits.source);
    gcvals.val = GXand;
    ChangeGC(null, pGC, cast(uint)GCFunction, &gcvals);
    ValidateGC(cast(DrawablePtr) sourceBits, pGC);
    (*pGC.ops.PutImage) (cast(DrawablePtr) sourceBits, pGC, 1,
                           0, 0, pCursor.bits.width, pCursor.bits.height,
                           0, XYPixmap, cast(char*) pCursor.bits.mask);

    /* mask bits -- pCursor->mask & ~pCursor->source */
    gcvals.val = GXcopy;
    ChangeGC(null, pGC,cast(uint) GCFunction, &gcvals);
    ValidateGC(cast(DrawablePtr) maskBits, pGC);
    (*pGC.ops.PutImage) (cast(DrawablePtr) maskBits, pGC, 1,
                           0, 0, pCursor.bits.width, pCursor.bits.height,
                           0, XYPixmap, cast(char*) pCursor.bits.mask);
    gcvals.val = GXandInverted;
    ChangeGC(null, pGC, cast(uint)GCFunction, &gcvals);
    ValidateGC(cast(DrawablePtr) maskBits, pGC);
    (*pGC.ops.PutImage) (cast(DrawablePtr) maskBits, pGC, 1,
                           0, 0, pCursor.bits.width, pCursor.bits.height,
                           0, XYPixmap, cast(char*) pCursor.bits.source);
    FreeScratchGC(pGC);

    miDCSwitchScreenCursor(pScreen, pCursor, sourceBits, maskBits, null);
    return TRUE;
}

bool miDCUnrealizeCursor(ScreenPtr pScreen, CursorPtr pCursor)
{
    miDCScreenPtr pScreenPriv = cast(_MiDCScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miDCScreenKey);

    if (pCursor == pScreenPriv.pCursor)
        miDCSwitchScreenCursor(pScreen, null, null, null, null);
    return TRUE;
}

private void miDCPutBits(DrawablePtr pDrawable, GCPtr sourceGC, GCPtr maskGC, int x_org, int y_org, uint w, uint h, c_ulong source, c_ulong mask)
{
    miDCScreenPtr pScreenPriv = cast(_MiDCScreenRec*)dixLookupPrivate(&pDrawable.pScreen.devPrivates, miDCScreenKey);
    ChangeGCVal gcval = void;
    int x = void, y = void;

    if (sourceGC.fgPixel != source) {
        gcval.val = cast(uint)source;
        ChangeGC(null, sourceGC, cast(uint)GCForeground, &gcval);
    }
    if (sourceGC.serialNumber != pDrawable.serialNumber)
        ValidateGC(pDrawable, sourceGC);

    if (sourceGC.miTranslate) {
        x = pDrawable.x + x_org;
        y = pDrawable.y + y_org;
    }
    else {
        x = x_org;
        y = y_org;
    }

    (*sourceGC.ops.PushPixels) (sourceGC, pScreenPriv.sourceBits, pDrawable, w, h,
                                  x, y);
    if (maskGC.fgPixel != mask) {
        gcval.val = cast(uint)mask;
        ChangeGC(null, maskGC, cast(uint)GCForeground, &gcval);
    }
    if (maskGC.serialNumber != pDrawable.serialNumber)
        ValidateGC(pDrawable, maskGC);

    if (maskGC.miTranslate) {
        x = pDrawable.x + x_org;
        y = pDrawable.y + y_org;
    }
    else {
        x = x_org;
        y = y_org;
    }

    (*maskGC.ops.PushPixels) (maskGC, pScreenPriv.maskBits, pDrawable, w, h, x, y);
}

private GCPtr miDCMakeGC(WindowPtr pWin)
{
    GCPtr pGC = void;
    int status = void;
    XID[2] gcvals = void;

    gcvals[0] = IncludeInferiors;
    gcvals[1] = FALSE;
    pGC = CreateGC(cast(DrawablePtr) pWin,
                   cast(uint)(GCSubwindowMode | GCGraphicsExposures), gcvals.ptr, &status,
                   cast(XID) 0, serverClient);
    return pGC;
}

bool miDCPutUpCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, int x, int y, c_ulong source, c_ulong mask)
{
    miDCScreenPtr pScreenPriv = cast(_MiDCScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miDCScreenKey);
    miDCBufferPtr pBuffer = void;
    WindowPtr pWin = void;

    if (!miDCRealize(pScreen, pCursor))
        return FALSE;

    pWin = pScreen.root;
    pBuffer = mixin(miGetDCDevice!(`pDev`, `pScreen`));

    if (pScreenPriv.pPicture) {
        if (!mixin(EnsurePicture!(`pBuffer.pRootPicture`, `&pWin.drawable`, `pWin`)))
            return FALSE;
        CompositePicture(PictOpOver,
                         pScreenPriv.pPicture,
                         null,
                         pBuffer.pRootPicture,
                         0, 0, 0, 0,
                         cast(short)x, cast(short)y, pCursor.bits.width, pCursor.bits.height);
    }
    else
    {
        miDCPutBits(cast(DrawablePtr) pWin,
                    pBuffer.pSourceGC, pBuffer.pMaskGC,
                    x, y, pCursor.bits.width, pCursor.bits.height,
                    source, mask);
    }
    return TRUE;
}

bool miDCSaveUnderCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, int w, int h)
{
    miDCBufferPtr pBuffer = void;
    PixmapPtr pSave = void;
    WindowPtr pWin = void;
    GCPtr pGC = void;

    pBuffer = mixin(miGetDCDevice!(`pDev`, `pScreen`));

    pSave = pBuffer.pSave;
    pWin = pScreen.root;
    if (!pSave || pSave.drawable.width < w || pSave.drawable.height < h) {
        dixDestroyPixmap(pSave, 0);
        pBuffer.pSave = pSave =
            (*pScreen.CreatePixmap) (pScreen, w, h, pScreen.rootDepth, 0);
        if (!pSave)
            return FALSE;
    }

    pGC = pBuffer.pSaveGC;
    if (pSave.drawable.serialNumber != pGC.serialNumber)
        ValidateGC(cast(DrawablePtr) pSave, pGC);
    cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pWin, cast(DrawablePtr) pSave, pGC,
                           x, y, w, h, 0, 0);
    return TRUE;
}

bool miDCRestoreUnderCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, int w, int h)
{
    miDCBufferPtr pBuffer = void;
    PixmapPtr pSave = void;
    WindowPtr pWin = void;
    GCPtr pGC = void;

    pBuffer = mixin(miGetDCDevice!(`pDev`, `pScreen`));
    pSave = pBuffer.pSave;

    pWin = pScreen.root;
    if (!pSave)
        return FALSE;

    pGC = pBuffer.pRestoreGC;
    if (pWin.drawable.serialNumber != pGC.serialNumber)
        ValidateGC(cast(DrawablePtr) pWin, pGC);
    cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pSave, cast(DrawablePtr) pWin, pGC,
                           0, 0, w, h, x, y);
    return TRUE;
}

bool miDCDeviceInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    miDCBufferPtr pBuffer = void;

    if (!DevHasCursor(pDev))
        return TRUE;

    mixin(DIX_FOR_EACH_SCREEN!q{
        WindowPtr pWin;
        pBuffer = cast(miDCBufferRec*) calloc(1, miDCBufferRec.sizeof);
        if (!pBuffer)
            goto failure;

        dixSetScreenPrivate(&pDev.devPrivates, miDCDeviceKey, walkScreen,
                            pBuffer);
        pWin = walkScreen.root;
        pBuffer.pSourceGC = miDCMakeGC(pWin);
        if (!pBuffer.pSourceGC)
            goto failure;

        pBuffer.pMaskGC = miDCMakeGC(pWin);
        if (!pBuffer.pMaskGC)
            goto failure;

        pBuffer.pSaveGC = miDCMakeGC(pWin);
        if (!pBuffer.pSaveGC)
            goto failure;

        pBuffer.pRestoreGC = miDCMakeGC(pWin);
        if (!pBuffer.pRestoreGC)
            goto failure;

        pBuffer.pRootPicture = null;

        /* (re)allocated lazily depending on the cursor size */
        pBuffer.pSave = null;

        continue;

failure:
        miDCDeviceCleanup(pDev, walkScreen);
        return FALSE;
    });

    return TRUE;
}

void miDCDeviceCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    if (!DevHasCursor(pDev))
        return;

    mixin(DIX_FOR_EACH_SCREEN!q{
        miDCBufferPtr pBuffer = mixin(miGetDCDevice!(`pDev`, `walkScreen`));
        if (!pBuffer)
            continue;

        if (pBuffer.pSourceGC)
            FreeGC(pBuffer.pSourceGC, cast(GContext) 0);
        if (pBuffer.pMaskGC)
            FreeGC(pBuffer.pMaskGC, cast(GContext) 0);
        if (pBuffer.pSaveGC)
            FreeGC(pBuffer.pSaveGC, cast(GContext) 0);
        if (pBuffer.pRestoreGC)
            FreeGC(pBuffer.pRestoreGC, cast(GContext) 0);

        /* If a pRootPicture was allocated for a root window, it
         * is freed when that root window is destroyed, so don't
         * free it again here. */

        dixDestroyPixmap(pBuffer.pSave, 0);
        free(pBuffer);
        dixSetScreenPrivate(&pDev.devPrivates, miDCDeviceKey, walkScreen, null);
    });
}
