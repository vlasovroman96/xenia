module miwindow;
@nogc nothrow:
extern(C): __gshared:

/***********************************************************

Copyright 1987, 1998  The Open Group

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

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/
import build.dix_config;

//import x11.X;
// //import externs.X11.extensions.shapeconst;

import dix.cursor_priv;
import dix.dix_priv;
import dix.input_priv;
import dix.window_priv;
import region;
import mi.mi_priv;

import include.windowstr;
import dix.scrnintstr;
import dix.pixmap;
import dix.inputstr;import dix.screen_hooks;
import dix.events;
import externs.X11.extensions.shapeconst;
import dix.window;

void miClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures)
{
    BoxRec box = void;
    RegionRec reg = void;
    BoxPtr extents = void;
    int x1 = void, y1 = void, x2 = void, y2 = void;

    /* compute everything using ints to avoid overflow */

    x1 = pWin.drawable.x + x;
    y1 = pWin.drawable.y + y;
    if (w)
        x2 = x1 + cast(int) w;
    else
        x2 = x1 + cast(int) pWin.drawable.width - cast(int) x;
    if (h)
        y2 = y1 + h;
    else
        y2 = y1 + cast(int) pWin.drawable.height - cast(int) y;

    extents = &pWin.clipList.extents;

    /* clip the resulting rectangle to the window clipList extents.  This
     * makes sure that the result will fit in a box, given that the
     * screen is < 32768 on a side.
     */

    if (x1 < extents.x1)
        x1 = extents.x1;
    if (x2 > extents.x2)
        x2 = extents.x2;
    if (y1 < extents.y1)
        y1 = extents.y1;
    if (y2 > extents.y2)
        y2 = extents.y2;

    if (x2 <= x1 || y2 <= y1) {
        x2 = x1 = 0;
        y2 = y1 = 0;
    }

    box.x1 = cast(short)x1;
    box.x2 = cast(short)x2;
    box.y1 = cast(short)y1;
    box.y2 = cast(short)y2;

    RegionInit(&reg, &box, 1);

    RegionIntersect(&reg, &reg, &pWin.clipList);
    if (generateExposures)
        (*pWin.drawable.pScreen.WindowExposures) (pWin, &reg);
    else if (pWin.backgroundState != None)
        pWin.drawable.pScreen.PaintWindow(pWin, &reg, PW_BACKGROUND);
    RegionUninit(&reg);
}

void miMarkWindow(WindowPtr pWin)
{
    if (pWin.valdata)
        return;

    ValidatePtr val = cast(ValidatePtr) cast(MiValidateRec*) calloc(1, MiValidateRec.sizeof);
    if (!val)
        return;

    val.before.oldAbsCorner.x = pWin.drawable.x;
    val.before.oldAbsCorner.y = pWin.drawable.y;
    val.before.borderVisible = NullRegion;
    val.before.resized = FALSE;
    pWin.valdata = val;
}

Bool miMarkOverlappedWindows(WindowPtr pWin, WindowPtr pFirst, WindowPtr* ppLayerWin)
{
    BoxPtr box = void;
    WindowPtr pChild = void, pLast = void;
    Bool anyMarked = FALSE;
    MarkWindowProcPtr MarkWindow = pWin.drawable.pScreen.MarkWindow;

    /* single layered systems are easy */
    if (ppLayerWin)
        *ppLayerWin = pWin;

    if (pWin == pFirst) {
        /* Blindly mark pWin and all of its inferiors.   This is a slight
         * overkill if there are mapped windows that outside pWin's border,
         * but it's better than wasting time on RectIn checks.
         */
        pChild = pWin;
        while (1) {
            if (pChild.viewable) {
                if (RegionBroken(&pChild.winSize))
                    SetWinSize(pChild);
                if (RegionBroken(&pChild.borderSize))
                    SetBorderSize(pChild);
                (*MarkWindow) (pChild);
                if (pChild.firstChild) {
                    pChild = pChild.firstChild;
                    continue;
                }
            }
            while (!pChild.nextSib && (pChild != pWin))
                pChild = pChild.parent;
            if (pChild == pWin)
                break;
            pChild = pChild.nextSib;
        }
        anyMarked = TRUE;
        pFirst = pFirst.nextSib;
    }
    if ((pChild = pFirst) !is null) {
        box = RegionExtents(&pWin.borderSize);
        pLast = pChild.parent.lastChild;
        while (1) {
            if (pChild.viewable) {
                if (RegionBroken(&pChild.winSize))
                    SetWinSize(pChild);
                if (RegionBroken(&pChild.borderSize))
                    SetBorderSize(pChild);
                if (RegionContainsRect(&pChild.borderSize, box)) {
                    (*MarkWindow) (pChild);
                    anyMarked = TRUE;
                    if (pChild.firstChild) {
                        pChild = pChild.firstChild;
                        continue;
                    }
                }
            }
            while (!pChild.nextSib && (pChild != pLast))
                pChild = pChild.parent;
            if (pChild == pLast)
                break;
            pChild = pChild.nextSib;
        }
    }
    if (anyMarked)
        (*MarkWindow) (pWin.parent);
    return anyMarked;
}

/*****
 *  miHandleValidateExposures(pWin)
 *    starting at pWin, draw background in any windows that have exposure
 *    regions, translate the regions, restore any backing store,
 *    and then send any regions still exposed to the client
 *****/
void miHandleValidateExposures(WindowPtr pWin)
{
    WindowPtr pChild = void;
    ValidatePtr val = void;
    WindowExposuresProcPtr WindowExposures = void;

    pChild = pWin;
    WindowExposures = pChild.drawable.pScreen.WindowExposures;
    while (1) {
        if ((val = pChild.valdata)!is null) {
            if (RegionNotEmpty(&val.after.borderExposed))
                pWin.drawable.pScreen.PaintWindow(pChild,
                                                    &val.after.borderExposed,
                                                    PW_BORDER);
            RegionUninit(&val.after.borderExposed);
            (*WindowExposures) (pChild, &val.after.exposed);
            RegionUninit(&val.after.exposed);
            free(val);
            pChild.valdata = null;
            if (pChild.firstChild) {
                pChild = pChild.firstChild;
                continue;
            }
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            break;
        pChild = pChild.nextSib;
    }
}

void miMoveWindow(WindowPtr pWin, int x, int y, WindowPtr pNextSib, VTKind kind)
{
    WindowPtr pParent = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    short bw = void;
    RegionPtr oldRegion = null;
    xPoint oldpt = void;
    Bool anyMarked = FALSE;
    ScreenPtr pScreen = void;
    WindowPtr windowToValidate = void;
    WindowPtr pLayerWin = void;

    /* if this is a root window, can't be moved */
    if (((pParent = pWin.parent) is null))
        return;
    pScreen = pWin.drawable.pScreen;
    bw = mixin(wBorderWidth!("pWin"));

    oldpt.x = pWin.drawable.x;
    oldpt.y = pWin.drawable.y;
    if (WasViewable) {
        oldRegion = RegionCreate(NullBox, 1);
        RegionCopy(oldRegion, &pWin.borderClip);
        anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pWin, &pLayerWin);
    }
    pWin.origin.x = cast(short)(x + cast(int) bw);
    pWin.origin.y = cast(short)(y + cast(int) bw);
    x = pWin.drawable.x = cast(short)(pParent.drawable.x + x + cast(int) bw);
    y = pWin.drawable.y = cast(short)(pParent.drawable.y + y + cast(int) bw);

    SetWinSize(pWin);
    SetBorderSize(pWin);

    dixScreenRaiseWindowPosition(pWin, x, y);

    windowToValidate = MoveWindowInStack(pWin, pNextSib);

    ResizeChildrenWinSize(pWin, x - oldpt.x, y - oldpt.y, 0, 0);

    if (WasViewable) {
        if (pLayerWin == pWin)
            anyMarked |= (*pScreen.MarkOverlappedWindows)
                (pWin, windowToValidate, null);
        else
            anyMarked |= (*pScreen.MarkOverlappedWindows)
                (pWin, pLayerWin, null);

        if (anyMarked) {
            (*pScreen.ValidateTree) (pLayerWin.parent, NullWindow, kind);
            (*pWin.drawable.pScreen.CopyWindow) (pWin, oldpt, oldRegion);
            RegionDestroy(oldRegion);
            /* XXX need to retile border if ParentRelative origin */
            (*pScreen.HandleExposures) (pLayerWin.parent);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pLayerWin.parent, null, kind);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
}

/*
 * pValid is a region of the screen which has been
 * successfully copied -- recomputed exposed regions for affected windows
 */

private int miRecomputeExposures(WindowPtr pWin, void* value)
{                               /* must conform to VisitWindowProcPtr */
    RegionPtr pValid = cast(RegionPtr) value;

    if (pWin.valdata) {
        /*
         * Redirected windows are not affected by parent window
         * gravity manipulations, so don't recompute their
         * exposed areas here.
         */
        if (pWin.redirectDraw != RedirectDrawNone)
            return WT_DONTWALKCHILDREN;
        /*
         * compute exposed regions of this window
         */
        RegionSubtract(&pWin.valdata.after.exposed, &pWin.clipList, pValid);
        /*
         * compute exposed regions of the border
         */
        RegionSubtract(&pWin.valdata.after.borderExposed,
                       &pWin.borderClip, &pWin.winSize);
        RegionSubtract(&pWin.valdata.after.borderExposed,
                       &pWin.valdata.after.borderExposed, pValid);
        return WT_WALKCHILDREN;
    }
    return WT_NOMATCH;
}

void miResizeWindow(WindowPtr pWin, int x, int y, uint w, uint h, WindowPtr pSib)
{
    WindowPtr pParent = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    ushort width = pWin.drawable.width, height = pWin.drawable.height;
    short oldx = pWin.drawable.x, oldy = pWin.drawable.y;
    int bw = mixin(wBorderWidth!("pWin"));
    short dw = void, dh = void;
    xPoint oldpt = void;
    RegionPtr oldRegion = null;
    Bool anyMarked = FALSE;
    ScreenPtr pScreen = void;
    WindowPtr pFirstChange = void;
    WindowPtr pChild = void;
    RegionPtr[StaticGravity + 1] gravitate = void;
    uint g = void;
    int nx = void, ny = void;                 /* destination x,y */
    int newx = void, newy = void;             /* new inner window position */
    RegionPtr pRegion = null;
    RegionPtr destClip = void;         /* portions of destination already written */
    RegionPtr oldWinClip = null;        /* old clip list for window */
    RegionPtr borderVisible = NullRegion;       /* visible area of the border */
    Bool shrunk = FALSE;        /* shrunk in an inner dimension */
    Bool moved = FALSE;         /* window position changed */
    WindowPtr pLayerWin = void;

    /* if this is a root window, can't be resized */
    if (((pParent = pWin.parent) is null))
        return;

    pScreen = pWin.drawable.pScreen;
    newx = pParent.drawable.x + x + bw;
    newy = pParent.drawable.y + y + bw;
    if (WasViewable) {
        anyMarked = FALSE;
        /*
         * save the visible region of the window
         */
        oldRegion = RegionCreate(NullBox, 1);
        RegionCopy(oldRegion, &pWin.winSize);

        /*
         * categorize child windows into regions to be moved
         */
        for (g = 0; g <= StaticGravity; g++)
            gravitate[g] = cast(RegionPtr) null;
        for (pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
            g = pChild.winGravity;
            if (g != UnmapGravity) {
                if (!gravitate[g])
                    gravitate[g] = RegionCreate(NullBox, 1);
                RegionUnion(gravitate[g], gravitate[g], &pChild.borderClip);
            }
            else {
                UnmapWindow(pChild, TRUE);
                anyMarked = TRUE;
            }
        }
        anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin, pWin, &pLayerWin);

        oldWinClip = null;
        if (pWin.bitGravity != ForgetGravity) {
            oldWinClip = RegionCreate(NullBox, 1);
            RegionCopy(oldWinClip, &pWin.clipList);
        }
        /*
         * if the window is changing size, borderExposed
         * can't be computed correctly without some help.
         */
        if (pWin.drawable.height > h || pWin.drawable.width > w)
            shrunk = TRUE;

        if (newx != oldx || newy != oldy)
            moved = TRUE;

        if ((pWin.drawable.height != h || pWin.drawable.width != w) &&
            mixin(HasBorder!("pWin"))) {
            borderVisible = RegionCreate(NullBox, 1);
            /* for tiled borders, we punt and draw the whole thing */
            if (pWin.borderIsPixel || !moved) {
                if (shrunk || moved)
                    RegionSubtract(borderVisible,
                                   &pWin.borderClip, &pWin.winSize);
                else
                    RegionCopy(borderVisible, &pWin.borderClip);
            }
        }
    }
    pWin.origin.x = cast(short)(x + bw);
    pWin.origin.y = cast(short)(y + bw);
    pWin.drawable.height = cast(ushort)h;
    pWin.drawable.width = cast(ushort)w;

    x = pWin.drawable.x = cast(short)newx;
    y = pWin.drawable.y = cast(short)newy;

    SetWinSize(pWin);
    SetBorderSize(pWin);

    dw = cast(short)(cast(int) w - cast(int) width);
    dh = cast(short)(cast(int) h - cast(int) height);
    ResizeChildrenWinSize(pWin, x - oldx, y - oldy, dw, dh);

    /* let the hardware adjust background and border pixmaps, if any */
    dixScreenRaiseWindowPosition(pWin, x, y);

    pFirstChange = MoveWindowInStack(pWin, pSib);

    if (WasViewable) {
        pRegion = RegionCreate(NullBox, 1);

        if (pLayerWin == pWin)
            anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin, pFirstChange,
                                                            null);
        else
            anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin, pLayerWin,
                                                            null);

        if (pWin.valdata) {
            pWin.valdata.before.resized = TRUE;
            pWin.valdata.before.borderVisible = borderVisible;
        }

        if (anyMarked)
            (*pScreen.ValidateTree) (pLayerWin.parent, pFirstChange, VTOther);
        /*
         * the entire window is trashed unless bitGravity
         * recovers portions of it
         */
        RegionCopy(&pWin.valdata.after.exposed, &pWin.clipList);
    }

    GravityTranslate(x, y, oldx, oldy, dw, dh, pWin.bitGravity, &nx, &ny);

    if (WasViewable) {
        /* avoid the border */
        if (mixin(HasBorder!("pWin"))) {
            int offx = void, offy = void, dx = void, dy = void;

            /* kruft to avoid double translates for each gravity */
            offx = 0;
            offy = 0;
            for (g = 0; g <= StaticGravity; g++) {
                if (!gravitate[g])
                    continue;

                /* align winSize to gravitate[g].
                 * winSize is in new coordinates,
                 * gravitate[g] is still in old coordinates */
                GravityTranslate(x, y, oldx, oldy, dw, dh, g, &nx, &ny);

                dx = (oldx - nx) - offx;
                dy = (oldy - ny) - offy;
                if (dx || dy) {
                    RegionTranslate(&pWin.winSize, dx, dy);
                    offx += dx;
                    offy += dy;
                }
                RegionIntersect(gravitate[g], gravitate[g], &pWin.winSize);
            }
            /* get winSize back where it belongs */
            if (offx || offy)
                RegionTranslate(&pWin.winSize, -offx, -offy);
        }
        /*
         * add screen bits to the appropriate bucket
         */

        if (oldWinClip) {
            /*
             * clip to new clipList
             */
            RegionCopy(pRegion, oldWinClip);
            RegionTranslate(pRegion, nx - oldx, ny - oldy);
            RegionIntersect(oldWinClip, pRegion, &pWin.clipList);
            /*
             * don't step on any gravity bits which will be copied after this
             * region.  Note -- this assumes that the regions will be copied
             * in gravity order.
             */
            for (g = pWin.bitGravity + 1; g <= StaticGravity; g++) {
                if (gravitate[g])
                    RegionSubtract(oldWinClip, oldWinClip, gravitate[g]);
            }
            RegionTranslate(oldWinClip, oldx - nx, oldy - ny);
            g = pWin.bitGravity;
            if (!gravitate[g])
                gravitate[g] = oldWinClip;
            else {
                RegionUnion(gravitate[g], gravitate[g], oldWinClip);
                RegionDestroy(oldWinClip);
            }
        }

        /*
         * move the bits on the screen
         */

        destClip = null;

        for (g = 0; g <= StaticGravity; g++) {
            if (!gravitate[g])
                continue;

            GravityTranslate(x, y, oldx, oldy, dw, dh, g, &nx, &ny);

            oldpt.x = cast(short)(oldx + (x - nx));
            oldpt.y = cast(short)(oldy + (y - ny));

            /* Note that gravitate[g] is *translated* by CopyWindow */

            /* only copy the remaining useful bits */

            RegionIntersect(gravitate[g], gravitate[g], oldRegion);

            /* clip to not overwrite already copied areas */

            if (destClip) {
                RegionTranslate(destClip, oldpt.x - x, oldpt.y - y);
                RegionSubtract(gravitate[g], gravitate[g], destClip);
                RegionTranslate(destClip, x - oldpt.x, y - oldpt.y);
            }

            /* and move those bits */

            if (oldpt.x != x || oldpt.y != y || pWin.redirectDraw) {
                (*pWin.drawable.pScreen.CopyWindow) (pWin, oldpt,
                                                       gravitate[g]);
            }

            /* remove any overwritten bits from the remaining useful bits */

            RegionSubtract(oldRegion, oldRegion, gravitate[g]);

            /*
             * recompute exposed regions of child windows
             */

            for (pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
                if (pChild.winGravity != g)
                    continue;
                RegionIntersect(pRegion, &pChild.borderClip, gravitate[g]);
                TraverseTree(pChild, &miRecomputeExposures, cast(void*) pRegion);
            }

            /*
             * remove the successfully copied regions of the
             * window from its exposed region
             */

            if (g == pWin.bitGravity)
                RegionSubtract(&pWin.valdata.after.exposed,
                               &pWin.valdata.after.exposed, gravitate[g]);
            if (!destClip)
                destClip = gravitate[g];
            else {
                RegionUnion(destClip, destClip, gravitate[g]);
                RegionDestroy(gravitate[g]);
            }
        }

        RegionDestroy(oldRegion);
        RegionDestroy(pRegion);
        if (destClip)
            RegionDestroy(destClip);
        if (anyMarked) {
            (*pScreen.HandleExposures) (pLayerWin.parent);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pLayerWin.parent, pFirstChange,
                                              VTOther);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
}

WindowPtr miGetLayerWindow(WindowPtr pWin)
{
    return pWin.firstChild;
}

/******
 *
 * miSetShape
 *    The border/window shape has changed.  Recompute winSize/borderSize
 *    and send appropriate exposure events
 */

void miSetShape(WindowPtr pWin, int kind)
{
    Bool WasViewable = cast(Bool) (pWin.viewable);
    ScreenPtr pScreen = pWin.drawable.pScreen;
    Bool anyMarked = FALSE;
    WindowPtr pLayerWin = void;

    if (kind != ShapeInput) {
        if (WasViewable) {
            anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pWin,
                                                           &pLayerWin);
            if (pWin.valdata) {
                if (mixin(HasBorder!("pWin"))) {
                    RegionPtr borderVisible = void;

                    borderVisible = RegionCreate(NullBox, 1);
                    RegionSubtract(borderVisible,
                                   &pWin.borderClip, &pWin.winSize);
                    pWin.valdata.before.borderVisible = borderVisible;
                }
                pWin.valdata.before.resized = TRUE;
            }
        }

        SetWinSize(pWin);
        SetBorderSize(pWin);

        ResizeChildrenWinSize(pWin, 0, 0, 0, 0);

        if (WasViewable) {
            anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);

            if (anyMarked) {
                (*pScreen.ValidateTree) (pLayerWin.parent, NullWindow,
                                          VTOther);
                (*pScreen.HandleExposures) (pLayerWin.parent);
                if (pScreen.PostValidateTree)
                    (*pScreen.PostValidateTree) (pLayerWin.parent, null,
                                                  VTOther);
            }
        }
    }
    if (pWin.realized)
        WindowsRestructured();
    CheckCursorConfinement(pWin);
}

/* Keeps the same inside(!) origin */

void miChangeBorderWidth(WindowPtr pWin, uint width)
{
    int oldwidth = void;
    Bool anyMarked = FALSE;
    ScreenPtr pScreen = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    Bool HadBorder = void;
    WindowPtr pLayerWin = void;

    oldwidth = mixin(wBorderWidth!("pWin"));
    if (oldwidth == width)
        return;
    HadBorder = mixin(HasBorder!("pWin"));
    pScreen = pWin.drawable.pScreen;
    if (WasViewable && width < oldwidth)
        anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pWin, &pLayerWin);

    pWin.borderWidth = cast(ushort)width;
    SetBorderSize(pWin);

    if (WasViewable) {
        if (width > oldwidth) {
            anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pWin,
                                                           &pLayerWin);
            /*
             * save the old border visible region to correctly compute
             * borderExposed.
             */
            if (pWin.valdata && HadBorder) {
                RegionPtr borderVisible = void;

                borderVisible = RegionCreate(null, 1);
                RegionSubtract(borderVisible,
                               &pWin.borderClip, &pWin.winSize);
                pWin.valdata.before.borderVisible = borderVisible;
            }
        }

        if (anyMarked) {
            (*pScreen.ValidateTree) (pLayerWin.parent, pLayerWin, VTOther);
            (*pScreen.HandleExposures) (pLayerWin.parent);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pLayerWin.parent, pLayerWin,
                                              VTOther);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
}

void miMarkUnrealizedWindow(WindowPtr pChild, WindowPtr pWin, Bool fromConfigure)
{
    if ((pChild != pWin) || fromConfigure) {
        RegionEmpty(&pChild.clipList);
        if (pChild.drawable.pScreen.ClipNotify)
            (*pChild.drawable.pScreen.ClipNotify) (pChild, 0, 0);
        RegionEmpty(&pChild.borderClip);
    }
}

WindowPtr miSpriteTrace(SpritePtr pSprite, int x, int y)
{
    WindowPtr pWin = void;
    BoxRec box = void;

    pWin = DeepestSpriteWin(pSprite).firstChild;
    while (pWin) {
        if ((pWin.mapped) &&
            (x >= pWin.drawable.x - mixin(wBorderWidth!("pWin"))) &&
            (x < pWin.drawable.x + cast(int) pWin.drawable.width +
             mixin(wBorderWidth!("pWin"))) &&
            (y >= pWin.drawable.y - mixin(wBorderWidth!("pWin"))) &&
            (y < pWin.drawable.y + cast(int) pWin.drawable.height +
             mixin(wBorderWidth!("pWin")))
            /* When a window is shaped, a further check
             * is made to see if the point is inside
             * borderSize
             */
            && (!mixin(wBoundingShape!("pWin")) || PointInBorderSize(pWin, x, y))
            && (!mixin(wInputShape!("pWin")) ||
                RegionContainsPoint(mixin(wInputShape!("pWin")),
                                    x - pWin.drawable.x,
                                    y - pWin.drawable.y, &box))
            /* In rootless mode windows may be offscreen, even when
             * they're in X's stack. (E.g. if the native window system
             * implements some form of virtual desktop system).
             */
            && !pWin.unhittable) {
            if (pSprite.spriteTraceGood >= pSprite.spriteTraceSize) {
                WindowPtr* newTrace = void;
                int newSize = pSprite.spriteTraceSize + 10;

                newTrace = cast(_Window**)reallocarray(pSprite.spriteTrace,
                                        newSize,
                                        WindowPtr.sizeof);
                if (!newTrace)
                    return DeepestSpriteWin(pSprite);
                pSprite.spriteTraceSize = newSize;
                pSprite.spriteTrace = newTrace;
            }
            pSprite.spriteTrace[pSprite.spriteTraceGood++] = pWin;
            pWin = pWin.firstChild;
        }
        else
            pWin = pWin.nextSib;
    }
    return DeepestSpriteWin(pSprite);
}

/**
 * Traversed from the root window to the window at the position x/y. While
 * traversing, it sets up the traversal history in the spriteTrace array.
 * After completing, the spriteTrace history is set in the following way:
 *   spriteTrace[0] ... root window
 *   spriteTrace[1] ... top level window that encloses x/y
 *       ...
 *   spriteTrace[spriteTraceGood - 1] ... window at x/y
 *
 * @returns the window at the given coordinates.
 */
WindowPtr miXYToWindow(ScreenPtr pScreen, SpritePtr pSprite, int x, int y)
{
    pSprite.spriteTraceGood = 1;       /* root window still there */
    return miSpriteTrace(pSprite, x, y);
}
