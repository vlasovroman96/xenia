module miext.shadow.shrotpackYX;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2004 Philip Blundell
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Philip Blundell not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Philip Blundell makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * PHILIP BLUNDELL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL PHILIP BLUNDELL BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

public import    x11.X;
public import    include.scrnintstr;
public import    include.windowstr;
public import    dix.dixfonts;
// public //import    include.mi;
public import    include.regionstr;
public import    dix.globals;
public import    include.gcstruct;
public import include.shadow;
public import    include.fb;

// enum ROTATE = 90;

mixin template SHROTPACK_YX(ushort ROTATE, DATA) {

static if (ROTATE == 270) {

enum string WINSTEPX(string stride) = `(` ~ stride ~ `)`;
enum string WINSTART(string x,string y) = `(((pScreen.height - 1) - ` ~ y ~ `) + (` ~ x ~ ` * winStride))`;
enum string WINSTEPY() = `-1`;

} else static if (ROTATE == 90) {

enum string WINSTEPX(string stride) = `(-` ~ stride ~ `)`;
enum string WINSTEPY() = `1`;
enum string WINSTART(string x,string y) = `(((pScreen.width - 1 - ` ~ x ~ `) * winStride) + ` ~ y ~ `)`;

} else {

static assert(0, "This rotation is not supported here");

}

version (__arm__) {
version = PREFETCH;
}

void FUNC(Data)(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBits = void;
    Data* shaBase = void, shaLine = void, sha = void;
    FbStride shaStride = void, winStride = void;
    int shaBpp = void;
     int shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void;
    Data* winBase = void, win = void, winLine = void;
    CARD32 winSize = void;

    fbGetDrawable(&pShadow.drawable, shaBits, shaStride, shaBpp, shaXoff,
                  shaYoff);
    shaBase = cast(Data*) shaBits;
    shaStride = shaStride * FbBits.sizeof / Data.sizeof;

    winBase = cast(Data*) (*pBuf.window) (pScreen, 0, 0,
                                        SHADOW_WINDOW_WRITE,
                                        &winSize, pBuf.closure);
    winStride = cast(Data*) (*pBuf.window) (pScreen, 1, 0,
                                          SHADOW_WINDOW_WRITE,
                                          &winSize, pBuf.closure) - winBase;

    while (nbox--) {
        x = pbox.x1;
        y = pbox.y1;
        w = (pbox.x2 - pbox.x1);
        h = pbox.y2 - pbox.y1;

        shaLine = shaBase + (y * shaStride) + x;
version (PREFETCH) {
        __builtin_prefetch(shaLine);
}
        winLine = winBase + mixin(WINSTART!(`x`, `y`));

        while (h--) {
            sha = shaLine;
            win = winLine;

            while (sha < (shaLine + w - 16)) {
version (PREFETCH) {
                __builtin_prefetch(sha + shaStride);
}
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));

                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));

                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));

                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
            }

            while (sha < (shaLine + w)) {
                *win = *sha++;
                win += mixin(WINSTEPX!(`winStride`));
            }

            y++;
            shaLine += shaStride;
            winLine += mixin(WINSTEPY!());
        }
        pbox++;
    }                           /*  nbox */
}
}
