module shpacked.c;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2000 Keith Packard
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

import core.stdc.stdlib;

import    x11.X;
import    include.scrnintstr;
import    include.windowstr;
import    externs.X11.fonts.font;
import    dix.dixfonts;
import    externs.X11.fonts.fontstruct;
import    include.regionstr;
import    dix.globals;
import    dix.gc;
import include.shadow;
import fb.fb;
public import fb.fballpriv;


void shadowUpdatePacked(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBase = void, shaLine = void, sha = void;
    FbStride shaStride = void;
    int scrBase = void, scrLine = void, scr = void;
    int shaBpp = void;
    int shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void, width = void;
    int i = void;
    FbBits* winBase = null, win = void;
    CARD32 winSize = void;

        mixin(fbGetDrawable!("(&pShadow.drawable)", "shaBase", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));
    while (nbox--) {
        x = pbox.x1 * shaBpp;
        y = pbox.y1;
        w = (pbox.x2 - pbox.x1) * shaBpp;
        h = pbox.y2 - pbox.y1;

        scrLine = (x >> FB_SHIFT);
        shaLine = shaBase + y * shaStride + (x >> FB_SHIFT);

        x &= FB_MASK;
        w = (w + x + FB_MASK) >> FB_SHIFT;

        while (h--) {
            winSize = 0;
            scrBase = 0;
            width = w;
            scr = scrLine;
            sha = shaLine;
            while (width) {
                /* how much remains in this window */
                i = cast(int)(scrBase + winSize - scr);
                if (i <= 0 || scr < scrBase) {
                    winBase = cast(FbBits*) (*pBuf.window) (pScreen,
                                                          y,
                                                          cast(uint)(scr * FbBits.sizeof),
                                                          SHADOW_WINDOW_WRITE,
                                                          &winSize,
                                                          pBuf.closure);
                    if (!winBase)
                        return;
                    scrBase = scr;
                    winSize /= FbBits.sizeof;
                    i = cast(int)winSize;
                }
                win = winBase + (scr - scrBase);
                if (i > width)
                    i = width;
                width -= i;
                scr += i;
                memcpy(win, sha, i * FbBits.sizeof);
                sha += i;
            }
            shaLine += shaStride;
            y++;
        }
        pbox++;
    }
}
