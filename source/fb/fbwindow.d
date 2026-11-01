module fb.fbwindow;
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
import build.xorg_config;

import core.stdc.stdlib;

import fb.fb_priv;
import externs.attrs;
import fb.fbgc;
import mi.micopy;

Bool fbCreateWindow(WindowPtr pWin)
{
    dixSetPrivate(&pWin.devPrivates, mixin(fbGetWinPrivateKey!("pWin")),
                  mixin(fbGetScreenPixmap!("pWin.drawable.pScreen")));
    return TRUE;
}

Bool fbDestroyWindow(WindowPtr pWin)
{
    return TRUE;
}

Bool fbRealizeWindow(WindowPtr pWindow)
{
    return TRUE;
}

Bool fbPositionWindow(WindowPtr pWin, int x, int y)
{
    return TRUE;
}

Bool fbUnrealizeWindow(WindowPtr pWindow)
{
    return TRUE;
}

void fbCopyWindowProc(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure)
{
    FbBits* src = void;
    FbStride srcStride = void;
    int srcBpp = void;
    int srcXoff = void, srcYoff = void;
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;

    mixin(fbGetDrawable!("pSrcDrawable", "src", "srcStride", "srcBpp", "srcXoff", "srcYoff"));
    mixin(fbGetDrawable!("pDstDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    while (nbox--) {
        fbBlt(src + (pbox.y1 + dy + srcYoff) * srcStride,
              srcStride,
              (pbox.x1 + dx + srcXoff) * srcBpp,
              dst + (pbox.y1 + dstYoff) * dstStride,
              dstStride,
              (pbox.x1 + dstXoff) * dstBpp,
              (pbox.x2 - pbox.x1) * dstBpp,
              (pbox.y2 - pbox.y1),
              GXcopy, FB_ALLONES, dstBpp, reverse, upsidedown);
        pbox++;
    }

    mixin(fbFinishAccess!("pDstDrawable"));
    mixin(fbFinishAccess!("pSrcDrawable"));
}

void fbCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    RegionRec rgnDst = void;
    int dx = void, dy = void;

    PixmapPtr pPixmap = mixin(fbGetWindowPixmap!("pWin"));
    DrawablePtr pDrawable = &pPixmap.drawable;

    dx = ptOldOrg.x - pWin.drawable.x;
    dy = ptOldOrg.y - pWin.drawable.y;
    RegionTranslate(prgnSrc, -dx, -dy);

    RegionNull(&rgnDst);

    RegionIntersect(&rgnDst, &pWin.borderClip, prgnSrc);

    if (pPixmap.screen_x || pPixmap.screen_y)
        RegionTranslate(&rgnDst, -pPixmap.screen_x, -pPixmap.screen_y);

    miCopyRegion(pDrawable, pDrawable,
                 null, &rgnDst, dx, dy, &fbCopyWindowProc, 0, null);

    RegionUninit(&rgnDst);
    fbValidateDrawable(&pWin.drawable);
}

private void fbFixupWindowPixmap(DrawablePtr pDrawable, PixmapPtr* ppPixmap)
{
    PixmapPtr pPixmap = *ppPixmap;

    if (mixin(FbEvenTile!("pPixmap.drawable.width * pPixmap.drawable.bitsPerPixel")))
        fbPadPixmap(pPixmap);
}

Bool fbChangeWindowAttributes(WindowPtr pWin, c_ulong mask)
{
    if (mask & CWBackPixmap) {
        if (pWin.backgroundState == BackgroundPixmap)
            fbFixupWindowPixmap(&pWin.drawable, &pWin.background.pixmap);
    }
    if (mask & CWBorderPixmap) {
        if (pWin.borderIsPixel == FALSE)
            fbFixupWindowPixmap(&pWin.drawable, &pWin.border.pixmap);
    }
    return TRUE;
}

void fbFillRegionSolid(DrawablePtr pDrawable, RegionPtr pRegion, FbBits and, FbBits xor)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    int n = RegionNumRects(pRegion);
    BoxPtr pbox = RegionRects(pRegion);

static if (FB_ACCESS_WRAPPER) {} else {
    int try_mmx = 0;

    if (!and)
        try_mmx = 1;
}

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    while (n--) {
static if (FB_ACCESS_WRAPPER) {} else {
        if (!try_mmx || !assumeNoGC(&pixman_fill)(cast(uint*) dst, dstStride, dstBpp,
                                     pbox.x1 + dstXoff, pbox.y1 + dstYoff,
                                     (pbox.x2 - pbox.x1),
                                     (pbox.y2 - pbox.y1), cast(uint)xor)) {
//! #endif
            fbSolid(dst + (pbox.y1 + dstYoff) * dstStride,
                    dstStride,
                    (pbox.x1 + dstXoff) * dstBpp,
                    dstBpp,
                    (pbox.x2 - pbox.x1) * dstBpp,
                    pbox.y2 - pbox.y1, and, cast(uint)xor);

static if (FB_ACCESS_WRAPPER) {} else {}
        }
}
        fbValidateDrawable(pDrawable);
        pbox++;
    }

    mixin(fbFinishAccess!("pDrawable"));
}
