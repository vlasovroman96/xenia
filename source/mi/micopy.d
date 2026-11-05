module mi.micopy;
@nogc nothrow:
extern(C): __gshared:
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

import dix.scrnintstr;
import dix.gc;
import dix.pixmap;
import include.windowstr;
// import mi.micopy;
import mi.miexpose;
import dix.window;

enum string miGetCompositeClip(string pGC) = `((` ~ pGC ~ `).pCompositeClip)`;

alias miCopyProc = void function(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pDstBox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure) @nogc nothrow;


void miCopyRegion(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, RegionPtr pDstRegion, int dx, int dy, miCopyProc copyProc, Pixel bitPlane, void* closure)
{
    int careful = void;
    Bool reverse = void;
    Bool upsidedown = void;
    BoxPtr pbox = void;
    int nbox = void;
    BoxPtr pboxNew1 = void, pboxNew2 = void, pboxBase = void, pboxNext = void, pboxTmp = void;

    pbox = RegionRects(pDstRegion);
    nbox = RegionNumRects(pDstRegion);

    /* XXX we have to err on the side of safety when both are windows,
     * because we don't know if IncludeInferiors is being used.
     */
    careful = ((pSrcDrawable == pDstDrawable) ||
               ((pSrcDrawable.type == DRAWABLE_WINDOW) &&
                (pDstDrawable.type == DRAWABLE_WINDOW)));

    pboxNew1 = null;
    pboxNew2 = null;
    if (careful && dy < 0) {
        upsidedown = TRUE;

        if (nbox > 1) {
            /* keep ordering in each band, reverse order of bands */
            pboxNew1 = cast(pixman_box16*)calloc(nbox, BoxRec.sizeof);
            if (!pboxNew1)
                return;
            pboxBase = pboxNext = pbox + nbox - 1;
            while (pboxBase >= pbox) {
                while ((pboxNext >= pbox) && (pboxBase.y1 == pboxNext.y1))
                    pboxNext--;
                pboxTmp = pboxNext + 1;
                while (pboxTmp <= pboxBase) {
                    *pboxNew1++ = *pboxTmp++;
                }
                pboxBase = pboxNext;
            }
            pboxNew1 -= nbox;
            pbox = pboxNew1;
        }
    }
    else {
        /* walk source top to bottom */
        upsidedown = FALSE;
    }

    if (careful && dx < 0) {
        /* walk source right to left */
        if (dy <= 0)
            reverse = TRUE;
        else
            reverse = FALSE;

        if (nbox > 1) {
            /* reverse order of rects in each band */
            pboxNew2 = cast(pixman_box16*)calloc(nbox, BoxRec.sizeof);
            if (!pboxNew2) {
                free(pboxNew1);
                return;
            }
            pboxBase = pboxNext = pbox;
            while (pboxBase < pbox + nbox) {
                while ((pboxNext < pbox + nbox) &&
                       (pboxNext.y1 == pboxBase.y1))
                    pboxNext++;
                pboxTmp = pboxNext;
                while (pboxTmp != pboxBase) {
                    *pboxNew2++ = *--pboxTmp;
                }
                pboxBase = pboxNext;
            }
            pboxNew2 -= nbox;
            pbox = pboxNew2;
        }
    }
    else {
        /* walk source left to right */
        reverse = FALSE;
    }

    (*copyProc) (pSrcDrawable,
                 pDstDrawable,
                 pGC,
                 pbox, nbox, dx, dy, reverse, upsidedown, bitPlane, closure);

    free(pboxNew1);
    free(pboxNew2);
}

RegionPtr miDoCopy(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int xIn, int yIn, int widthSrc, int heightSrc, int xOut, int yOut, miCopyProc copyProc, Pixel bitPlane, void* closure)
{
    RegionPtr prgnSrcClip = null;       /* may be a new region, or just a copy */
    Bool freeSrcClip = FALSE;
    RegionPtr prgnExposed = null;
    RegionRec rgnDst = void;
    int dx = void;
    int dy = void;
    int numRects = void;
    int box_x1 = void;
    int box_y1 = void;
    int box_x2 = void;
    int box_y2 = void;
    Bool fastSrc = FALSE;       /* for fast clipping with pixmap source */
    Bool fastDst = FALSE;       /* for fast clipping with one rect dest */
    Bool fastExpose = FALSE;    /* for fast exposures with pixmap source */

    /* Short cut for unmapped windows */

    if (pDstDrawable.type == DRAWABLE_WINDOW &&
        !(cast(WindowPtr) pDstDrawable).realized) {
        return null;
    }

    (*pSrcDrawable.pScreen.SourceValidate) (pSrcDrawable, xIn, yIn,
                                              widthSrc, heightSrc,
                                              pGC.subWindowMode);

    /* Compute source clip region */
    if (pSrcDrawable.type == DRAWABLE_PIXMAP) {
        if ((pSrcDrawable == pDstDrawable) && (!pGC.clientClip))
            prgnSrcClip = mixin(miGetCompositeClip!("pGC"));
        else
            fastSrc = TRUE;
    }
    else {
        if (pGC.subWindowMode == IncludeInferiors) {
            /*
             * XFree86 DDX empties the border clip when the
             * VT is inactive, make sure the region isn't empty
             */
            if (!(cast(WindowPtr) pSrcDrawable).parent &&
                RegionNotEmpty(&(cast(WindowPtr) pSrcDrawable).borderClip)) {
                /*
                 * special case bitblt from root window in
                 * IncludeInferiors mode; just like from a pixmap
                 */
                fastSrc = TRUE;
            }
            else if ((pSrcDrawable == pDstDrawable) && (!pGC.clientClip)) {
                prgnSrcClip = mixin(miGetCompositeClip!("pGC"));
            }
            else {
                prgnSrcClip = NotClippedByChildren(cast(WindowPtr) pSrcDrawable);
                freeSrcClip = TRUE;
            }
        }
        else {
            prgnSrcClip = &(cast(WindowPtr) pSrcDrawable).clipList;
        }
    }

    xIn += pSrcDrawable.x;
    yIn += pSrcDrawable.y;

    xOut += pDstDrawable.x;
    yOut += pDstDrawable.y;

    box_x1 = xIn;
    box_y1 = yIn;
    box_x2 = xIn + widthSrc;
    box_y2 = yIn + heightSrc;

    dx = xIn - xOut;
    dy = yIn - yOut;

    /* Don't create a source region if we are doing a fast clip */
    if (fastSrc) {
        RegionPtr cclip = void;

        fastExpose = TRUE;
        /*
         * clip the source; if regions extend beyond the source size,
         * make sure exposure events get sent
         */
        if (box_x1 < pSrcDrawable.x) {
            box_x1 = pSrcDrawable.x;
            fastExpose = FALSE;
        }
        if (box_y1 < pSrcDrawable.y) {
            box_y1 = pSrcDrawable.y;
            fastExpose = FALSE;
        }
        if (box_x2 > pSrcDrawable.x + cast(int) pSrcDrawable.width) {
            box_x2 = pSrcDrawable.x + cast(int) pSrcDrawable.width;
            fastExpose = FALSE;
        }
        if (box_y2 > pSrcDrawable.y + cast(int) pSrcDrawable.height) {
            box_y2 = pSrcDrawable.y + cast(int) pSrcDrawable.height;
            fastExpose = FALSE;
        }

        /* Translate and clip the dst to the destination composite clip */
        box_x1 -= dx;
        box_x2 -= dx;
        box_y1 -= dy;
        box_y2 -= dy;

        /* If the destination composite clip is one rectangle we can
           do the clip directly.  Otherwise we have to create a full
           blown region and call intersect */

        cclip = mixin(miGetCompositeClip!("pGC"));
        if (RegionNumRects(cclip) == 1) {
            BoxPtr pBox = RegionRects(cclip);

            if (box_x1 < pBox.x1)
                box_x1 = pBox.x1;
            if (box_x2 > pBox.x2)
                box_x2 = pBox.x2;
            if (box_y1 < pBox.y1)
                box_y1 = pBox.y1;
            if (box_y2 > pBox.y2)
                box_y2 = pBox.y2;
            fastDst = TRUE;
        }
    }

    /* Check to see if the region is empty */
    if (box_x1 >= box_x2 || box_y1 >= box_y2) {
        RegionNull(&rgnDst);
    }
    else {
        BoxRec box = void;

        box.x1 = cast(short)box_x1;
        box.y1 = cast(short)box_y1;
        box.x2 = cast(short)box_x2;
        box.y2 = cast(short)box_y2;
        RegionInit(&rgnDst, &box, 1);
    }

    /* Clip against complex source if needed */
    if (!fastSrc) {
        RegionIntersect(&rgnDst, &rgnDst, prgnSrcClip);
        RegionTranslate(&rgnDst, -dx, -dy);
    }

    /* Clip against complex dest if needed */
    if (!fastDst) {
        RegionIntersect(&rgnDst, &rgnDst, mixin(miGetCompositeClip!("pGC")));
    }

    /* Do bit blitting */
    numRects = RegionNumRects(&rgnDst);
    if (numRects && widthSrc && heightSrc)
        miCopyRegion(pSrcDrawable, pDstDrawable, pGC,
                     &rgnDst, dx, dy, copyProc, bitPlane, closure);

    /* Pixmap sources generate a NoExposed (we return NULL to do this) */
    if (!fastExpose && pGC.fExpose)
        prgnExposed = miHandleExposures(pSrcDrawable, pDstDrawable, pGC,
                                        xIn - pSrcDrawable.x,
                                        yIn - pSrcDrawable.y,
                                        widthSrc, heightSrc,
                                        xOut - pDstDrawable.x,
                                        yOut - pDstDrawable.y);
    RegionUninit(&rgnDst);
    if (freeSrcClip)
        RegionDestroy(prgnSrcClip);
    return prgnExposed;
}
