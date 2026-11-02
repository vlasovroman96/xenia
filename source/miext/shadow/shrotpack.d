module miext.shadow.shrotpack;
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

/*
 * Thanks to Daniel Chemko <dchemko@intrinsyc.com> for making the 90 and 180
 * orientations work.
 */
public import core.stdc.stdlib;

public import    x11.X;
public import    include.scrnintstr;
public import    include.windowstr;
public import    externs.X11.fonts.font;
public import    dix.dixfonts;
public import    externs.X11.fonts.fontstruct;
public import    include.regionstr;
public import    dix.globals;
public import    include.gcstruct;
public import include.shadow;

enum DANDEBUG =         0;

// enum ROTATE = 0;

mixin template ROTFUNCS(ushort ROTATE, DATA) {

    static if (ROTATE == 270) {
    enum string SCRLEFT(string x,string y,string w,string h) = `(pScreen.height - ((` ~ y ~ `) + (` ~ h ~ `)))`;
    enum string SCRY(string x,string y,string w,string h) = `(` ~ x ~ `)`;
    enum string SCRWIDTH(string x,string y,string w,string h) = `(` ~ h ~ `)`;
    enum string FIRSTSHA(string x,string y,string w,string h) = `(((` ~ y ~ `) + (` ~ h ~ `) - 1) * shaStride + (` ~ x ~ `))`;
    enum string STEPDOWN(string x,string y,string w,string h) = `((` ~ w ~ `)--)`;
    enum string NEXTY(string x,string y,string w,string h) = `((` ~ x ~ `)++)`;
    enum string SHASTEPX(string stride) = `-(` ~ stride ~ `)`;
    enum string SHASTEPY(string stride) = `(1)`;

    } else static if (ROTATE == 90) {

    enum string SCRLEFT(string x,string y,string w,string h) = `(` ~ y ~ `)`;
    enum string SCRY(string x,string y,string w,string h) = `(pScreen.width - ((` ~ x ~ `) + (` ~ w ~ `)) - 1)`;
    enum string SCRWIDTH(string x,string y,string w,string h) = `(` ~ h ~ `)`;
    enum string FIRSTSHA(string x,string y,string w,string h) = `((` ~ y ~ `) * shaStride + (` ~ x ~ ` + ` ~ w ~ ` - 1))`;
    enum string STEPDOWN(string x,string y,string w,string h) = `((` ~ w ~ `)--)`;
    enum string NEXTY(string x,string y,string w,string h) = `(cast(void)(` ~ x ~ `))`;
    enum string SHASTEPX(string stride) = `(` ~ stride ~ `)`;
    enum string SHASTEPY(string stride) = `(-1)`;

    } else static if (ROTATE == 180) {

    enum string SCRLEFT(string x,string y,string w,string h) = `(pScreen.width - ((` ~ x ~ `) + (` ~ w ~ `)))`;
    enum string SCRY(string x,string y,string w,string h) = `(pScreen.height - ((` ~ y ~ `) + (` ~ h ~ `)) - 1)`;
    enum string SCRWIDTH(string x,string y,string w,string h) = `(` ~ w ~ `)`;
    enum string FIRSTSHA(string x,string y,string w,string h) = `((` ~ y ~ ` + ` ~ h ~ ` - 1) * shaStride + (` ~ x ~ ` + ` ~ w ~ ` - 1))`;
    enum string STEPDOWN(string x,string y,string w,string h) = `((` ~ h ~ `)--)`;
    enum string NEXTY(string x,string y,string w,string h) = `(cast(void)(` ~ y ~ `))`;
    enum string SHASTEPX(string stride) = `(-1)`;
    enum string SHASTEPY(string stride) = `-(` ~ stride ~ `)`;

    } else {

    enum string SCRLEFT(string x,string y,string w,string h) = `(` ~ x ~ `)`;
    enum string SCRY(string x,string y,string w,string h) = `(` ~ y ~ `)`;
    enum string SCRWIDTH(string x,string y,string w,string h) = `(` ~ w ~ `)`;
    enum string FIRSTSHA(string x,string y,string w,string h) = `((` ~ y ~ `) * shaStride + (` ~ x ~ `))`;
    enum string STEPDOWN(string x,string y,string w,string h) = `((` ~ h ~ `)--)`;
    enum string NEXTY(string x,string y,string w,string h) = `((` ~ y ~ `)++)`;
    enum string SHASTEPX(string stride) = `(1)`;
    enum string SHASTEPY(string stride) = `(` ~ stride ~ `)`;

    }

    void FUNC(DATA) (ScreenPtr pScreen, shadowBufPtr pBuf)
{  
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBits = void;
    Data* shaBase = void, shaLine = void, sha = void;
    FbStride shaStride = void;
    int scrBase = void, scrLine = void, scr = void;
    int shaBpp = void;
     int shaXoff = void, shaYoff = void;
    int x = void, y = void, w = void, h = void, width = void;
    int i = void;
    Data* winBase = null, win = void;
    CARD32 winSize = void;

    fbGetDrawable(&pShadow.drawable, shaBits, shaStride, shaBpp, shaXoff,
                  shaYoff);
    shaBase = cast(Data*) shaBits;
    shaStride = shaStride * FbBits.sizeof / Data.sizeof;
static if ((DANDEBUG > 1)) {
    ErrorF
        ("-> Entering Shadow Update:\r\n   |- Origins: pShadow=%x, pScreen=%x, damage=%x\r\n   |- Metrics: shaStride=%d, shaBase=%x, shaBpp=%d\r\n   |                                                     \n",
         pShadow, pScreen, damage, shaStride, shaBase, shaBpp);
}
    while (nbox--) {
        x = pbox.x1;
        y = pbox.y1;
        w = (pbox.x2 - pbox.x1);
        h = pbox.y2 - pbox.y1;

static if ((DANDEBUG > 2)) {
        ErrorF
            ("   |-> Redrawing box - Metrics: X=%d, Y=%d, Width=%d, Height=%d\n",
             x, y, w, h);
}
        scrLine = mixin(SCRLEFT!(`x`, `y`, `w`, `h`));
        shaLine = shaBase + mixin(FIRSTSHA!(`x`, `y`, `w`, `h`));

        while (mixin(STEPDOWN!(`x`, `y`, `w`, `h`))) {
            winSize = 0;
            scrBase = 0;
            width = mixin(SCRWIDTH!(`x`, `y`, `w`, `h`));
            scr = scrLine;
            sha = shaLine;
static if ((DANDEBUG > 3)) {
            ErrorF("   |   |-> StepDown - Metrics: width=%d, scr=%x, sha=%x\n",
                   width, scr, sha);
}
            while (width) {
                /*  how much remains in this window */
                i = scrBase + winSize - scr;
                if (i <= 0 || scr < scrBase) {
                    winBase = cast(Data*) (*pBuf.window) (pScreen,
                                                        mixin(SCRY!(`x`, `y`, `w`, `h`)),
                                                        scr * Data.sizeof,
                                                        SHADOW_WINDOW_WRITE,
                                                        &winSize,
                                                        pBuf.closure);
                    if (!winBase)
                        return;
                    scrBase = scr;
                    winSize /= Data.sizeof;
                    i = winSize;
static if((DANDEBUG > 4)) {
                    ErrorF
                        ("   |   |   |-> Starting New Line - Metrics: winBase=%x, scrBase=%x, winSize=%d\r\n   |   |   |   Xstride=%d, Ystride=%d, w=%d h=%d\n",
                         winBase, scrBase, winSize, mixin(SHASTEPX!(`shaStride`)),
                         mixin(SHASTEPY!(`shaStride`)), w, h);
}
                }
                win = winBase + (scr - scrBase);
                if (i > width)
                    i = width;
                width -= i;
                scr += i;
static if((DANDEBUG > 5)) {
                ErrorF
                    ("   |   |   |-> Writing Line - Metrics: win=%x, sha=%x\n",
                     win, sha);
}
                while (i--) {
static if((DANDEBUG > 6)) {
                    ErrorF
                        ("   |   |   |-> Writing Pixel - Metrics: win=%x, sha=%d, remaining=%d\n",
                         win, sha, i);
}
                    *win++ = *sha;
                    sha += mixin(SHASTEPX!(`shaStride`));
                }               /*  i */
            }                   /*  width */
            shaLine += mixin(SHASTEPY!(`shaStride`));
            mixin(NEXTY!(`x`, `y`, `w`, `h`));
        }                       /*  STEPDOWN */
        pbox++;
    }                           /*  nbox */
}

}

