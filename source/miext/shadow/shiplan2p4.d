module shiplan2p4.c;
@nogc nothrow:
extern(C): __gshared:
/*
 *  Copyright © 2013 Geert Uytterhoeven
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice (including the next
 *  paragraph) shall be included in all copies or substantial portions of the
 *  Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 *
 *  Based on shpacked.c, which is Copyright © 2000 Keith Packard
 */

import build.dix_config;

import core.stdc.stdlib;

import    x11.X;
import    dix.scrnintstr;
import    include.windowstr;
import    externs.X11.fonts.font;
import    dix.dixfonts;
import    externs.X11.fonts.fontstruct;
import    region;
import    dix.globals;
import    dix.gc;
import miext.shadow.shadow;
import fb.fb;
import    miext.shadow.c2p_core;


    /*
     *  Perform a full C2P step on 16 4-bit pixels, stored in 2 32-bit words
     *  containing
     *    - 16 4-bit chunky pixels on input
     *    - permutated planar data (2 planes per 32-bit word) on output
     */

private void c2p_16x4(CARD32* d)
{
    transp2(d, 8);
    transp2(d, 2);
    transp2x(d, 1);
    transp2(d, 16);
    transp2(d, 4);
    transp2(d, 1);
}


    /*
     *  Store a full block of iplan2p4 data after c2p conversion
     */

pragma(inline, true) private void store_iplan2p4(void* dst, const(CARD32)* d)
{
    CARD32* p = cast(uint*)dst;

    *p++ = d[0];
    *p++ = d[1];
}


void shadowUpdateIplan2p4(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBase = void;
    CARD16* shaLine = void, sha = void;
    FbStride shaStride = void;
    int scrLine = void;
     int shaBpp = void, shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void;
    int i = void, n = void;
    CARD16* win = void;
     CARD32 winSize = void;
    union _D {
        CARD8[8] bytes = void;
        CARD32[2] words = void;
    }_D d = void;

        mixin(fbGetDrawable!("(&pShadow.drawable)", "shaBase", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));
    shaStride *= FbBits.sizeof / CARD16.sizeof;

    while (nbox--) {
        x = pbox.x1;
        y = pbox.y1;
        w = pbox.x2 - pbox.x1;
        h = pbox.y2 - pbox.y1;

        scrLine = (x & -16) / 2;
        shaLine = cast(CARD16*)shaBase + y * shaStride + scrLine / CARD16.sizeof;

        n = ((x & 15) + w + 15) / 16;   /* number of c2p units in scanline */

        while (h--) {
            sha = shaLine;
            win = cast(CARD16*) (*pBuf.window) (pScreen,
                                              y,
                                              scrLine,
                                              SHADOW_WINDOW_WRITE,
                                              &winSize,
                                              pBuf.closure);
            if (!win)
                return;
            for (i = 0; i < n; i++) {
                memcpy(d.bytes.ptr, sha, typeof(d.bytes).sizeof);
                c2p_16x4(d.words.ptr);
                store_iplan2p4(win, d.words.ptr);
                sha += cast(ulong)((d.bytes).sizeof / typeof(*sha).sizeof);
                win += cast(ulong)((d.bytes).sizeof / typeof(*win).sizeof);
            }
            shaLine += shaStride;
            y++;
        }
        pbox++;
    }
}
