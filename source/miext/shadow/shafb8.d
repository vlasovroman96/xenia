module shafb8.c;
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
import include.shadow;
import fb.fb;
import    miext.shadow.c2p_core;


    /*
     *  Perform a full C2P step on 32 8-bit pixels, stored in 8 32-bit words
     *  containing
     *    - 32 8-bit chunky pixels on input
     *    - permutated planar data (1 plane per 32-bit word) on output
     */

private void c2p_32x8(CARD32* d)
{
    transp8(d, 16, 4);
    transp8(d, 8, 2);
    transp8(d, 4, 1);
    transp8(d, 2, 4);
    transp8(d, 1, 2);
}


    /*
     *  Store a full block of permutated planar data after c2p conversion
     */

pragma(inline, true) private void store_afb8(void* dst, uint stride, const(CARD32)* d)
{
    CARD8* p = cast(ubyte*)dst;

    *cast(CARD32*)p = d[7]; p += stride;
    *cast(CARD32*)p = d[5]; p += stride;
    *cast(CARD32*)p = d[3]; p += stride;
    *cast(CARD32*)p = d[1]; p += stride;
    *cast(CARD32*)p = d[6]; p += stride;
    *cast(CARD32*)p = d[4]; p += stride;
    *cast(CARD32*)p = d[2]; p += stride;
    *cast(CARD32*)p = d[0]; p += stride;
}


void shadowUpdateAfb8(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBase = void;
    CARD32* shaLine = void, sha = void;
    FbStride shaStride = void;
    int scrLine = void;
    int shaBpp = void, shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void;
    int i = void, n = void;
    CARD32* win = void;
    CARD32 off = void, winStride = void;
    union _D {
        CARD8[32] bytes = void;
        CARD32[8] words = void;
    }_D d = void;

        mixin(fbGetDrawable!("(&pShadow.drawable)", "shaBase", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));
    if (FbBits.sizeof != CARD32.sizeof)
        shaStride = cast(int)(shaStride * FbBits.sizeof / CARD32.sizeof);

    while (nbox--) {
        x = pbox.x1;
        y = pbox.y1;
        w = pbox.x2 - pbox.x1;
        h = pbox.y2 - pbox.y1;

        scrLine = x & -32;
        shaLine = cast(CARD32*)shaBase + y * shaStride + scrLine / CARD32.sizeof;

        off = scrLine / 8;              /* byte offset in bitplane scanline */
        n = ((x & 31) + w + 31) / 32;   /* number of c2p units in scanline */

        while (h--) {
            sha = shaLine;
            win = cast(CARD32*) (*pBuf.window) (pScreen,
                                              y,
                                              off,
                                              SHADOW_WINDOW_WRITE,
                                              &winStride,
                                              pBuf.closure);
            if (!win)
                return;
            for (i = 0; i < n; i++) {
                memcpy(d.bytes.ptr, sha, typeof(d.bytes).sizeof);
                c2p_32x8(d.words.ptr);
                store_afb8(win++, cast(uint)winStride, d.words.ptr);
                sha += cast(ulong)((d.bytes).sizeof / typeof(*sha).sizeof);
            }
            shaLine += shaStride;
            y++;
        }
        pbox++;
    }
}
