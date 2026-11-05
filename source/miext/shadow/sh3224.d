module sh3224.c;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
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

import include.shadow;
import fb.fb;
import fb.fballpriv;
import common.servermd;

enum string Get8(string a) = `(cast(CARD32) `~READ!(a)~`)`;

static if (BITMAP_BIT_ORDER == MSBFirst) {
enum string Get24(string a) = `((` ~ Get8!(a) ~ ` << 16) | (` ~ Get8!(`(` ~ a ~ `)+1`) ~ ` << 8) | ` ~ Get8!(`(` ~ a ~ `)+2`) ~ `)`;
enum string Put24(string a, string p) = `(
    ` ~ WRITE!((a ~ `+0`), `cast(CARD8)(` ~ p ~ ` >> 16)`) ~ `;
    ` ~ WRITE!((a ~ `+1`), `cast(CARD8)(` ~ p ~ ` >> 8)`) ~ `;
    ` ~ WRITE!((a ~ `+2`), `cast(CARD8)(` ~ p ~ `)`) ~ `;
`;

} else {
enum string Get24(string a) = `(` ~ Get8!(a) ~ ` | (` ~ Get8!(`(` ~ a ~ `)+1`) ~ ` << 8) | (` ~ Get8!(`(` ~ a ~ `)+2`) ~ `<<16))`;
enum string Put24(string a,string p) = `

    (`~WRITE!(
        (a ~ `+0`),
        `cast(CARD8) (` ~ p ~ `)`)~`
    ); 
    (`~WRITE!(
        (a ~ `+1`),
        `cast(CARD8) ((` ~ p ~ `) >> 8)`)~
    `);
    (`~WRITE!(
        (a~`+2`),
        `cast(CARD8) ((` ~ p ~ `) >> 16)`)~
    `);`;
}

private void sh24_32BltLine(CARD8* srcLine, CARD8* dstLine, int width)
{
    CARD32* src = void;
    CARD8* dst = void;
    int w = void;
    CARD32 pixel = void;

    src = cast(CARD32*) srcLine;
    dst = dstLine;
    w = width;

    while ((cast(c_long)dst & 3) && w) {
	w--;
	pixel = mixin(READ!("src++"));
	mixin(Put24!(`dst`, `pixel`));
	dst += 3;
    }
    /* Do four aligned pixels at a time */
    while (w >= 4) {
	CARD32 s0 = void, s1 = void;

	s0 = mixin(READ!("src++"));
	s1 = mixin(READ!("src++"));
static if (BITMAP_BIT_ORDER == LSBFirst) {
	mixin(WRITE!("cast(CARD32*) dst", "(s0 & 0xffffff) | (s1 << 24)")~";");
} else {
	mixin(WRITE!("cast(CARD32*) dst", "(s0 << 8) | ((s1 & 0xffffff) >> 16)")~";");
}
	s0 = mixin(READ!("src++"));
static if (BITMAP_BIT_ORDER == LSBFirst) {
	mixin(WRITE!("cast(CARD32*) (dst + 4)",
	      "((s1 & 0xffffff) >> 8) | (s0 << 16)")~";");
} else {
	mixin(WRITE!("cast(CARD32*) (dst + 4)",
	      "(s1 << 16) | ((s0 & 0xffffff) >> 8)")~";");
}
	s1 = mixin(READ!("src++"));
static if (BITMAP_BIT_ORDER == LSBFirst) {
	mixin(WRITE!("cast(CARD32*) (dst + 8)",
	      "((s0 & 0xffffff) >> 16) | (s1 << 8)")~";");
} else {
	mixin(WRITE!("cast(CARD32*) (dst + 8)", "(s0 << 24) | (s1 & 0xffffff)")~";");
}
	dst += 12;
	w -= 4;
    }
    while (w--) {
	pixel = mixin(READ!("src++"));
	mixin(Put24!(`dst`, `pixel`));
	dst += 3;
    }
}

void shadowUpdate32to24(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbStride shaStride = void;
    int shaBpp = void;
    int shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void;
    CARD32 winSize = void;
    FbBits* shaBase = void, shaLine = void;
    CARD8* winBase = null, winLine = void;

    mixin(fbGetDrawable!("(&pShadow.drawable)", "shaBase", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));

    /* just get the initial window base + stride */
    winBase = cast(ubyte*)(*pBuf.window)(pScreen, 0, 0, SHADOW_WINDOW_WRITE,
			      &winSize, pBuf.closure);

    while (nbox--) {
        x = pbox.x1;
        y = pbox.y1;
        w = pbox.x2 - pbox.x1;
        h = pbox.y2 - pbox.y1;

	winLine = winBase + y * winSize + (x * 3);
        shaLine = shaBase + y * shaStride + ((x * shaBpp) >> FB_SHIFT);

        while (h--) {
	    sh24_32BltLine(cast(CARD8*)shaLine, cast(CARD8*)winLine, w);
	    winLine += winSize;
            shaLine += shaStride;
        }
        pbox++;
    }
}
