module shplanar.c;
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
import    region;
import    dix.globals;
import    dix.gc;
import include.shadow;
import fb.fb;

public import fb.fballpriv;


/*
 * 32 4-bit pixels per write
 */

enum PL_SHIFT =    7;
enum PL_UNIT =	    (1 << PL_SHIFT);
enum PL_MASK =	    (PL_UNIT - 1);

/*
 *  32->8 conversion:
 *
 *      7 6 5 4 3 2 1 0
 *      A B C D E F G H
 *
 *      3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1
 *      1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
 * m    . . . H . . . G . . . F . . . E . . . D . . . C . . . B . . . A
 * m1   G . . . F . . . E . . . D . . . C . . . B . . . A . . . . . . .	    m << (7 - (p))
 * m2   . H . . . G . . . F . . . E . . . D . . . C . . . B . . . A . .	    (m >> (p)) << 2
 * m3   G               E               C               A                   m1 & 0x80808080
 * m4     H               F               D               B                 m2 & 0x40404040
 * m5   G H             E F             C D             A B                 m3 | m4
 * m6   G H             E F             C D     G H     A B     E F         m5 | (m5 >> 20)
 * m7   G H             E F             C D     G H     A B C D E F G H     m6 | (m6 >> 10)
 */

version (none) {
enum string GetBits(string p,string o,string d) = `{
    m = sha[` ~ o ~ `]; 
    m1 = m << (7 - (` ~ p ~ `)); 
    m2 = (m >> (` ~ p ~ `)) << 2; 
    m3 = m1 & 0x80808080; 
    m4 = m2 & 0x40404040; 
    m5 = m3 | m4; 
    m6 = m5 | (m5 >> 20); 
    ` ~ d ~ ` = cast(ubyte)(m6 | (m6 >> 10)); 
}`;
} else {
enum string GetBits(string p,string o,string d) = `{
    m = sha[` ~ o ~ `]; 
    m5 = ((m << (7 - (` ~ p ~ `))) & 0x80808080) | (((m >> (` ~ p ~ `)) << 2) & 0x40404040); 
    m6 = m5 | (m5 >> 20); 
    ` ~ d ~ ` = cast(ubyte)(m6 | (m6 >> 10)); 
}`;
}

void shadowUpdatePlanar4(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    CARD32* shaBase = void, shaLine = void, sha = void;
    FbStride shaStride = void;
    int scrBase = void, scrLine = void, scr = void;
    int shaBpp = void;
    int shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void, width = void;
    int i = void;
    CARD32* winBase = null, win = void;
    CARD32 winSize = void;
    int plane = void;
    CARD32 m = void, m5 = void, m6 = void;
    CARD8 s1 = void, s2 = void, s3 = void, s4 = void;

        mixin(fbGetStipDrawable!("(&pShadow.drawable)", "shaBase", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));
    while (nbox--) {
        x = (pbox.x1) * shaBpp;
        y = (pbox.y1);
        w = (pbox.x2 - pbox.x1) * shaBpp;
        h = pbox.y2 - pbox.y1;

        w = (w + (x & PL_MASK) + PL_MASK) >> PL_SHIFT;
        x &= ~PL_MASK;

        scrLine = (x >> PL_SHIFT);
        shaLine = shaBase + y * shaStride + (x >> FB_SHIFT);

        while (h--) {
            for (plane = 0; plane < 4; plane++) {
                width = w;
                scr = scrLine;
                sha = shaLine;
                winSize = 0;
                scrBase = 0;
                while (width) {
                    /* how much remains in this window */
                    i = cast(int)(scrBase + winSize - scr);
                    if (i <= 0 || scr < scrBase) {
                        winBase = cast(CARD32*) (*pBuf.window) (pScreen,
                                                              y,
                                                              (scr << 4) |
                                                              (plane),
                                                              SHADOW_WINDOW_WRITE,
                                                              &winSize,
                                                              pBuf.closure);
                        if (!winBase)
                            return;
                        winSize >>= 2;
                        scrBase = scr;
                        i = cast(int)winSize;
                    }
                    win = winBase + (scr - scrBase);
                    if (i > width)
                        i = width;
                    width -= i;
                    scr += i;

                    while (i--) {
                        mixin(GetBits!(`plane`, `0`, `s1`));
                        mixin(GetBits!(`plane`, `1`, `s2`));
                        mixin(GetBits!(`plane`, `2`, `s3`));
                        mixin(GetBits!(`plane`, `3`, `s4`));
                        *win++ = s1 | (s2 << 8) | (s3 << 16) | (s4 << 24);
                        sha += 4;
                    }
                }
            }
            shaLine += shaStride;
            y++;
        }
        pbox++;
    }
}
