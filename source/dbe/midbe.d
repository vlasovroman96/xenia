module midbe;
@nogc nothrow:
extern(C): __gshared:
/******************************************************************************
 *
 * Copyright (c) 1994, 1995  Hewlett-Packard Company
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL HEWLETT-PACKARD COMPANY BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the Hewlett-Packard
 * Company shall not be used in advertising or otherwise to promote the
 * sale, use or other dealings in this Software without prior written
 * authorization from the Hewlett-Packard Company.
 *
 *     Machine-independent DBE code
 *
 *****************************************************************************/

import build.dix_config;

//import x11.X;
//import x11.Xproto;
import os.os;
import dix.scrnintstr;
import dix.pixmap;
import dix.extension;
import dix.dixstruct_priv;
import dix.window;
import dbestruct;
import region;
import dix.inputstr;
import midbe;
import Xext.xace;
import dix.dispatch;

import core.stdc.stdio;
import dix.screen_hooks_priv;
import dbe.dbe;
import dix.resource;
import dix.gc;
import externs.X11.extensions.dbe;
import dix.screen_hooks;
/******************************************************************************
 *
 * DBE MI Procedure: miDbeGetVisualInfo
 *
 * Description:
 *
 *     This is the MI function for the DbeGetVisualInfo request.  This function
 *     is called through pDbeScreenPriv->GetVisualInfo.  This function is also
 *     called for the DbeAllocateBackBufferName request at the extension level;
 *     it is called by ProcDbeAllocateBackBufferName() in dbe.c.
 *
 *     If memory allocation fails or we can not get the visual info, this
 *     function returns FALSE.  Otherwise, it returns TRUE for success.
 *
 *****************************************************************************/

private Bool miDbeGetVisualInfo(ScreenPtr pScreen, XdbeScreenVisualInfo* pScrVisInfo)
{
    int i = void, j = void, k = void;
    int count = void;
    DepthPtr pDepth = void;
    XdbeVisualInfo* visInfo = void;

    /* Determine number of visuals for this screen. */
    for (i = 0, count = 0; i < pScreen.numDepths; i++) {
        count += pScreen.allowedDepths[i].numVids;
    }

    /* Allocate an array of XdbeVisualInfo items. */
    if (((visInfo = cast(XdbeVisualInfo*) calloc(count, XdbeVisualInfo.sizeof)) is null)) {
        return FALSE;           /* memory alloc failure */
    }

    for (i = 0, k = 0; i < pScreen.numDepths; i++) {
        /* For each depth of this screen, get visual information. */

        pDepth = &pScreen.allowedDepths[i];

        for (j = 0; j < pDepth.numVids; j++) {
            /* For each visual for this depth of this screen, get visual ID
             * and visual depth.  Since this is MI code, we will always return
             * the same performance level for all visuals (0).  A higher
             * performance level value indicates higher performance.
             */
            visInfo[k].visual = pDepth.vids[j];
            visInfo[k].depth = pDepth.depth;
            visInfo[k].perflevel = 0;
            k++;
        }
    }

    /* Record the number of visuals and point visual_depth to
     * the array of visual info.
     */
    pScrVisInfo.count = count;
    pScrVisInfo.visinfo = visInfo;

    return TRUE;                /* success */
}

/******************************************************************************
 *
 * DBE MI Procedure: miAllocBackBufferName
 *
 * Description:
 *
 *     This is the MI function for the DbeAllocateBackBufferName request.
 *
 *****************************************************************************/

private int miDbeAllocBackBufferName(WindowPtr pWin, XID bufId, int swapAction)
{
    ScreenPtr pScreen = void;
    DbeWindowPrivPtr pDbeWindowPriv = void;
    DbeScreenPrivPtr pDbeScreenPriv = void;
    GCPtr pGC = void;
    xRectangle clearRect = void;
    int rc = void;

    pScreen = pWin.drawable.pScreen;
    pDbeWindowPriv = mixin(DBE_WINDOW_PRIV!("pWin"));

    if (pDbeWindowPriv.nBufferIDs == 0) {
        /* There is no buffer associated with the window.
         * We have to create the window priv priv.  Remember, the window
         * priv was created at the DIX level, so all we need to do is
         * create the priv priv and attach it to the priv.
         */

        pDbeScreenPriv = mixin(DBE_SCREEN_PRIV!("pScreen"));

        /* Get a front pixmap. */
        if (((pDbeWindowPriv.pFrontBuffer =
              (*pScreen.CreatePixmap) (pScreen, pDbeWindowPriv.width,
                                        pDbeWindowPriv.height,
                                        pWin.drawable.depth, 0)) is null)) {
            return BadAlloc;
        }

        /* Get a back pixmap. */
        if (((pDbeWindowPriv.pBackBuffer =
              (*pScreen.CreatePixmap) (pScreen, pDbeWindowPriv.width,
                                        pDbeWindowPriv.height,
                                        pWin.drawable.depth, 0)) is null)) {
            dixDestroyPixmap(pDbeWindowPriv.pFrontBuffer, 0);
            return BadAlloc;
        }

        /* Security creation/labeling check. */
        rc = XaceHookResourceAccess(serverClient, bufId, dbeDrawableResType,
                                    pDbeWindowPriv.pBackBuffer, X11_RESTYPE_WINDOW,
                                    pWin, DixCreateAccess);

        /* Make the back pixmap a DBE drawable resource. */
        if (rc != Success || !AddResource(cast(uint)bufId, dbeDrawableResType,
                                          pDbeWindowPriv.pBackBuffer)) {
            /* free the buffer and the drawable resource */
            FreeResource(cast(uint)bufId, X11_RESTYPE_NONE);
            return (rc == Success) ? BadAlloc : rc;
        }

        /* Clear the back buffer. */
        pGC = GetScratchGC(pWin.drawable.depth, pWin.drawable.pScreen);
        if ((*pDbeScreenPriv.SetupBackgroundPainter) (pWin, pGC)) {
            ValidateGC(cast(DrawablePtr) pDbeWindowPriv.pBackBuffer, pGC);
            clearRect.x = clearRect.y = 0;
            clearRect.width = pDbeWindowPriv.pBackBuffer.drawable.width;
            clearRect.height = pDbeWindowPriv.pBackBuffer.drawable.height;
            (*pGC.ops.PolyFillRect) (cast(DrawablePtr) pDbeWindowPriv.
                                       pBackBuffer, pGC, 1, &clearRect);
        }
        FreeScratchGC(pGC);

    }                           /* if no buffer associated with the window */

    else {
        /* A buffer is already associated with the window.
         * Place the new buffer ID information at the head of the ID list.
         */

        /* Associate the new ID with an existing pixmap. */
        if (!AddResource(cast(uint)bufId, dbeDrawableResType,
                         cast(void*) pDbeWindowPriv.pBackBuffer)) {
            return BadAlloc;
        }

    }

    return Success;
}

/******************************************************************************
 *
 * DBE MI Procedure: miDbeAliasBuffers
 *
 * Description:
 *
 *     This function associates all XIDs of a buffer with the back pixmap
 *     stored in the window priv.
 *
 *****************************************************************************/

private void miDbeAliasBuffers(DbeWindowPrivPtr pDbeWindowPriv)
{
    int i = void;

    for (i = 0; i < pDbeWindowPriv.nBufferIDs; i++) {
        ChangeResourceValue(pDbeWindowPriv.IDs[i], dbeDrawableResType,
                            cast(void*) pDbeWindowPriv.pBackBuffer);
    }
}

/******************************************************************************
 *
 * DBE MI Procedure: miDbeSwapBuffers
 *
 * Description:
 *
 *     This is the MI function for the DbeSwapBuffers request.
 *
 *****************************************************************************/

private int miDbeSwapBuffers(ClientPtr client, int* pNumWindows, DbeSwapInfoPtr swapInfo)
{
    DbeScreenPrivPtr pDbeScreenPriv = void;
    DbeWindowPrivPtr pDbeWindowPriv = void;
    GCPtr pGC = void;
    WindowPtr pWin = void;
    PixmapPtr pTmpBuffer = void;
    xRectangle clearRect = void;

    pWin = swapInfo[0].pWindow;
    pDbeScreenPriv = mixin(DBE_SCREEN_PRIV_FROM_WINDOW!("pWin"));
    pDbeWindowPriv = mixin(DBE_WINDOW_PRIV!("pWin"));
    pGC = GetScratchGC(pWin.drawable.depth, pWin.drawable.pScreen);

    /*
     **********************************************************************
     ** Setup before swap.
     **********************************************************************
     */

    switch (swapInfo[0].swapAction) {
    case XdbeUndefined:
        break;

    case XdbeBackground:
        break;

    case XdbeUntouched:
        ValidateGC(cast(DrawablePtr) pDbeWindowPriv.pFrontBuffer, pGC);
        cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pWin,
                                      cast(DrawablePtr) pDbeWindowPriv.pFrontBuffer,
                                      pGC, 0, 0, pWin.drawable.width,
                                      pWin.drawable.height, 0, 0);
        break;

    case XdbeCopied:
        break;

    default: break;}

    /*
     **********************************************************************
     ** Swap.
     **********************************************************************
     */

    ValidateGC(cast(DrawablePtr) pWin, pGC);
    cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pDbeWindowPriv.pBackBuffer,
                                  cast(DrawablePtr) pWin, pGC, 0, 0,
                                  pWin.drawable.width,
                                  pWin.drawable.height, 0, 0);

    /*
     **********************************************************************
     ** Tasks after swap.
     **********************************************************************
     */

    switch (swapInfo[0].swapAction) {
    case XdbeUndefined:
        break;

    case XdbeBackground:
        if ((*pDbeScreenPriv.SetupBackgroundPainter) (pWin, pGC)) {
            ValidateGC(cast(DrawablePtr) pDbeWindowPriv.pBackBuffer, pGC);
            clearRect.x = 0;
            clearRect.y = 0;
            clearRect.width = pDbeWindowPriv.pBackBuffer.drawable.width;
            clearRect.height = pDbeWindowPriv.pBackBuffer.drawable.height;
            (*pGC.ops.PolyFillRect) (cast(DrawablePtr) pDbeWindowPriv.
                                       pBackBuffer, pGC, 1, &clearRect);
        }
        break;

    case XdbeUntouched:
        /* Swap pixmap pointers. */
        pTmpBuffer = pDbeWindowPriv.pBackBuffer;
        pDbeWindowPriv.pBackBuffer = pDbeWindowPriv.pFrontBuffer;
        pDbeWindowPriv.pFrontBuffer = pTmpBuffer;

        miDbeAliasBuffers(pDbeWindowPriv);

        break;

    case XdbeCopied:
        break;

    default: break;}

    /* Remove the swapped window from the swap information array and decrement
     * pNumWindows to indicate to the DIX level how many windows were actually
     * swapped.
     */

    if (*pNumWindows > 1) {
        /* We were told to swap more than one window, but we only swapped the
         * first one.  Remove the first window in the list by moving the last
         * window to the beginning.
         */
        swapInfo[0].pWindow = swapInfo[*pNumWindows - 1].pWindow;
        swapInfo[0].swapAction = swapInfo[*pNumWindows - 1].swapAction;

        /* Clear the last window information just to be safe. */
        swapInfo[*pNumWindows - 1].pWindow = cast(WindowPtr) null;
        swapInfo[*pNumWindows - 1].swapAction = 0;
    }
    else {
        /* Clear the window information just to be safe. */
        swapInfo[0].pWindow = cast(WindowPtr) null;
        swapInfo[0].swapAction = 0;
    }

    (*pNumWindows)--;

    FreeScratchGC(pGC);

    return Success;
}

/******************************************************************************
 *
 * DBE MI Procedure: miDbeWinPrivDelete
 *
 * Description:
 *
 *     This is the MI function for deleting the dbeWindowPrivResType resource.
 *     This function is invoked indirectly by calling FreeResource(cast(uint)) to free
 *     the resources associated with a DBE buffer ID.  There are 5 ways that
 *     miDbeWinPrivDelete() can be called by FreeResource(cast(uint)).  They are:
 *
 *     - A DBE window is destroyed, in which case the DbeWindowDestroy()
 *       callback is invoked.  It calls FreeResource(cast(uint)) for all DBE buffer IDs.
 *
 *     - miDbeAllocBackBufferName() calls FreeResource(cast(uint)) to clean up resources
 *       after a buffer allocation failure.
 *
 *     - The WindowPosition hook, miDbeWindowPosition(), calls
 *       FreeResource(cast(uint)) when it fails to create buffers of the new size.
 *       FreeResource(cast(uint)) is called for all DBE buffer IDs.
 *
 *     - FreeClientResources() calls FreeResource(cast(uint)) when a client dies or the
 *       the server resets.
 *
 *     When FreeResource(cast(uint)) is called for a DBE buffer ID, the delete function
 *     for the only other type of DBE resource, dbeDrawableResType, is also
 *     invoked.  This delete function (DbeDrawableDelete) is a NOOP to make
 *     resource deletion easier.  It is not guaranteed which delete function is
 *     called first.  Hence, we will let miDbeWinPrivDelete() free all DBE
 *     resources.
 *
 *     This function deletes/frees the following stuff associated with
 *     the window private:
 *
 *     - the ID node in the ID list representing the passed in ID.
 *
 *     In addition, pDbeWindowPriv->nBufferIDs is decremented.
 *
 *     If this function is called for the last/only buffer ID for a window,
 *     these are additionally deleted/freed:
 *
 *     - the front and back pixmaps
 *     - the window priv itself
 *
 *****************************************************************************/

private void miDbeWinPrivDelete(DbeWindowPrivPtr pDbeWindowPriv, XID bufId)
{
    if (pDbeWindowPriv.nBufferIDs != 0) {
        /* We still have at least one more buffer ID associated with this
         * window.
         */
        return;
    }

    /* We have no more buffer IDs associated with this window.  We need to
     * free some stuff.
     */

    /* Destroy the front and back pixmaps. */
    if (pDbeWindowPriv.pFrontBuffer)
         dixDestroyPixmap(pDbeWindowPriv.pFrontBuffer, 0);

    if (pDbeWindowPriv.pBackBuffer)
        dixDestroyPixmap(pDbeWindowPriv.pBackBuffer, 0);
}

/******************************************************************************
 *
 * DBE MI Procedure: miDbeWindowPosition
 *
 * Description:
 *
 *     This function was cloned from miMbxWindowPosition() in mimultibuf.c.
 *     This function resizes the buffer when the window is resized.
 *
 *****************************************************************************/

void miDbeWindowPosition(CallbackListPtr* pcbl, ScreenPtr pScreen, XorgScreenWindowPositionParamRec* param)
{
    DbeScreenPrivPtr pDbeScreenPriv = void;
    DbeWindowPrivPtr pDbeWindowPriv = void;
    int width = void, height = void;
    int dx = void, dy = void, dw = void, dh = void;
    int sourcex = void, sourcey = void;
    int destx = void, desty = void;
    int savewidth = void, saveheight = void;
    PixmapPtr pFrontBuffer = void;
    PixmapPtr pBackBuffer = void;
    Bool clear = void;
    GCPtr pGC = void;
    xRectangle clearRect = void;

    WindowPtr pWin = param.window;
    pDbeScreenPriv = mixin(DBE_SCREEN_PRIV!("pScreen"));

    /*
     **************************************************************************
     ** 5. Do any work necessary after the member routine has been called.
     **************************************************************************
     */

    if (((pDbeWindowPriv = mixin(DBE_WINDOW_PRIV!("pWin"))) is null))
        return;

    if (pDbeWindowPriv.width == pWin.drawable.width &&
        pDbeWindowPriv.height == pWin.drawable.height)
        return;

    width = pWin.drawable.width;
    height = pWin.drawable.height;

    dx = pWin.drawable.x - pDbeWindowPriv.x;
    dy = pWin.drawable.y - pDbeWindowPriv.y;
    dw = width - pDbeWindowPriv.width;
    dh = height - pDbeWindowPriv.height;

    GravityTranslate(0, 0, -dx, -dy, dw, dh, pWin.bitGravity, &destx, &desty);

    clear = ((pDbeWindowPriv.width < cast(ushort) width) ||
             (pDbeWindowPriv.height < cast(ushort) height) ||
             (pWin.bitGravity == ForgetGravity));

    sourcex = 0;
    sourcey = 0;
    savewidth = pDbeWindowPriv.width;
    saveheight = pDbeWindowPriv.height;

    /* Clip rectangle to source and destination. */
    if (destx < 0) {
        savewidth += destx;
        sourcex -= destx;
        destx = 0;
    }

    if (destx + savewidth > width) {
        savewidth = width - destx;
    }

    if (desty < 0) {
        saveheight += desty;
        sourcey -= desty;
        desty = 0;
    }

    if (desty + saveheight > height) {
        saveheight = height - desty;
    }

    pDbeWindowPriv.width = cast(ushort)width;
    pDbeWindowPriv.height = cast(ushort)height;
    pDbeWindowPriv.x = cast(ushort)pWin.drawable.x;
    pDbeWindowPriv.y = cast(ushort)pWin.drawable.y;

    pGC = GetScratchGC(pWin.drawable.depth, pScreen);

    if (clear) {
        if ((*pDbeScreenPriv.SetupBackgroundPainter) (pWin, pGC)) {
            clearRect.x = 0;
            clearRect.y = 0;
            clearRect.width = cast(ushort)width;
            clearRect.height = cast(ushort)height;
        }
        else {
            clear = FALSE;
        }
    }

    /* Create DBE buffer pixmaps equal to size of resized window. */
    pFrontBuffer = (*pScreen.CreatePixmap) (pScreen, width, height,
                                             pWin.drawable.depth, 0);

    pBackBuffer = (*pScreen.CreatePixmap) (pScreen, width, height,
                                            pWin.drawable.depth, 0);

    if (!pFrontBuffer || !pBackBuffer) {
        /* We failed at creating 1 or 2 of the pixmaps. */

        dixDestroyPixmap(pFrontBuffer, 0);
        dixDestroyPixmap(pBackBuffer, 0);

        /* Destroy all buffers for this window. */
        while (pDbeWindowPriv) {
            /* DbeWindowPrivDelete() will free the window private if there no
             * more buffer IDs associated with this window.
             */
            FreeResource(cast(uint)pDbeWindowPriv.IDs[0], X11_RESTYPE_NONE);
            pDbeWindowPriv = mixin(DBE_WINDOW_PRIV!("pWin"));
        }

        FreeScratchGC(pGC);
        return;
    } else {
        /* Clear out the new DBE buffer pixmaps. */

        /* I suppose this could avoid quite a bit of work if
         * it computed the minimal area required.
         */
        ValidateGC(&pFrontBuffer.drawable, pGC);
        if (clear) {
            (*pGC.ops.PolyFillRect) (cast(DrawablePtr) pFrontBuffer, pGC, 1,
                                       &clearRect);
        }
        /* Copy the contents of the old front pixmap to the new one. */
        if (pWin.bitGravity != ForgetGravity) {
            cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pDbeWindowPriv.pFrontBuffer,
                                          cast(DrawablePtr) pFrontBuffer, pGC,
                                          sourcex, sourcey, savewidth, saveheight,
                                          destx, desty);
        }

        ValidateGC(&pBackBuffer.drawable, pGC);
        if (clear) {
            (*pGC.ops.PolyFillRect) (cast(DrawablePtr) pBackBuffer, pGC, 1,
                                       &clearRect);
        }
        /* Copy the contents of the old back pixmap to the new one. */
        if (pWin.bitGravity != ForgetGravity) {
            cast(void) (*pGC.ops.CopyArea) (cast(DrawablePtr) pDbeWindowPriv.pBackBuffer,
                                          cast(DrawablePtr) pBackBuffer, pGC,
                                          sourcex, sourcey, savewidth, saveheight,
                                          destx, desty);
        }

        /* Destroy the old pixmaps, and point the DBE window priv to the new
         * pixmaps.
         */

        dixDestroyPixmap(pDbeWindowPriv.pFrontBuffer, 0);
        dixDestroyPixmap(pDbeWindowPriv.pBackBuffer, 0);

        pDbeWindowPriv.pFrontBuffer = pFrontBuffer;
        pDbeWindowPriv.pBackBuffer = pBackBuffer;

        /* Make sure all XID are associated with the new back pixmap. */
        miDbeAliasBuffers(pDbeWindowPriv);

        FreeScratchGC(pGC);
    }
}

/******************************************************************************
 *
 * DBE MI Procedure: miDbeInit
 *
 * Description:
 *
 *     This is the MI initialization function called by DbeExtensionInit().
 *
 *****************************************************************************/

Bool miDbeInit(ScreenPtr pScreen, DbeScreenPrivPtr pDbeScreenPriv)
{
    dixScreenHookWindowPosition(pScreen, &miDbeWindowPosition);

    /* Initialize the per-screen DBE function pointers. */
    pDbeScreenPriv.GetVisualInfo = &miDbeGetVisualInfo;
    pDbeScreenPriv.AllocBackBufferName = &miDbeAllocBackBufferName;
    pDbeScreenPriv.SwapBuffers = &miDbeSwapBuffers;
    pDbeScreenPriv.WinPrivDelete = &miDbeWinPrivDelete;

    return TRUE;
}
