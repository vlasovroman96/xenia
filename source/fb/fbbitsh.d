module fb.fbbitsh;
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
//!HACKED 
enum BITS = 32;
/*
 * This file defines functions for drawing some primitives using
 * underlying datatypes instead of masks
 */
public import fb.fb_priv;

enum string isClipped(string c,string ul,string lr) = `(((` ~ c ~ `) | ((` ~ c ~ `) - (` ~ ul ~ `)) | ((` ~ lr ~ `) - (` ~ c ~ `))) & 0x80008000)`;

enum string __FbMaskBits(string x,string w,string l,string n,string r) = `{ 
    ` ~ n ~ ` = (` ~ w ~ `); 
    ` ~ r ~ ` = FbRightMask((` ~ x ~ `)+` ~ n ~ `); 
    ` ~ l ~ ` = FbLeftMask(` ~ x ~ `); 
    if (` ~ l ~ `) { 
        ` ~ n ~ ` -= FB_UNIT - ((` ~ x ~ `) & FB_MASK); 
        if (` ~ n ~ ` < 0) { 
            ` ~ n ~ ` = 0; 
            ` ~ l ~ ` &= ` ~ r ~ `; 
            ` ~ r ~ ` = 0; 
        } 
    } 
    ` ~ n ~ ` >>= FB_SHIFT; 
}`;

/* Macros for dealing with dashing */

enum FbDashDeclare =   
    "ubyte*       __dash, __firstDash, __lastDash;";

enum string FbDashInit(string pGC,string pPriv,string dashOffset,string dashlen,string even) = `{     
    (` ~ even ~ `) = True;                                          
    __firstDash = (` ~ pGC ~ `).dash;                              
    __lastDash = __firstDash + (` ~ pGC ~ `).numInDashList;        
    (` ~ dashOffset ~ `) %= (` ~ pPriv ~ `).dashLength;                    
                                                            
    __dash = __firstDash;                                   
    while ((` ~ dashOffset ~ `) >= ((` ~ dashlen ~ `) = *__dash))           
    {                                                       
        (` ~ dashOffset ~ `) -= (` ~ dashlen ~ `);                          
        (` ~ even ~ `) = 1-(` ~ even ~ `);                                  
        if (++__dash == __lastDash)                         
            __dash = __firstDash;                           
    }                                                       
    (` ~ dashlen ~ `) -= (` ~ dashOffset ~ `);                              
}`;

enum string FbDashNext(string dashlen) = `{                               
    if (++__dash == __lastDash)                             
        __dash = __firstDash;                               
    (` ~ dashlen ~ `) = *__dash;                                    
}`;

/* as numInDashList is always even, this case can skip a test */

enum string FbDashNextEven(string dashlen) = `{                           
    (` ~ dashlen ~ `) = *++__dash;                                  
}`;

enum string FbDashNextOdd(string dashlen) = `FbDashNext(` ~ dashlen ~ `)`;

enum string FbDashStep(string dashlen,string even) = `{                          
    if (!--(` ~ dashlen ~ `)) {                                     
        ` ~ FbDashNext!(
            dashlen
        ) ~ `;                                
        (` ~ even ~ `) = 1-(` ~ even ~ `);                                  
    }                                                       
}`;

version (BITSSTORE) {
enum string STORE(string b,string x) = `BITSSTORE(` ~ b ~ `,` ~ x ~ `)`;
} else {
enum string STORE(string b,string x) = `WRITE((` ~ b ~ `), (` ~ x ~ `))`;
}

version (BITSRROP) {
enum string RROP(string b,string a,string x) = `BITSRROP(` ~ b ~ `,` ~ a ~ `,` ~ x ~ `)`;
} else {
enum string RROP(string b,string a,string x) = `WRITE((` ~ b ~ `), FbDoRRop (READ(` ~ b ~ `), (` ~ a ~ `), (` ~ x ~ `)))`;
}

version (BITSUNIT) {
enum UNIT = BITSUNIT;
version = USE_SOLID;
} else {
enum UNIT = BITS;
}

/*
 * Define the following before including this file:
 *
 *  BRESSOLID	name of function for drawing a solid segment
 *  BRESDASH	name of function for drawing a dashed segment
 *  DOTS	name of function for drawing dots
 *  ARC		name of function for drawing a solid arc
 *  BITS	type of underlying unit
 */

version (BRESSOLID) {
void BRESSOLID(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    UNIT* bits = void;
    FbStride bitsStride = void;
    FbStride majorStep = void, minorStep = void;
    BITS xor = cast(BITS) pPriv.xor;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    bits =
        (cast(UNIT*) (dst + ((y1 + dstYoff) * dstStride))) + (x1 + dstXoff);
    bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    if (signdy < 0)
        bitsStride = -bitsStride;
    if (axis == X_AXIS) {
        majorStep = signdx;
        minorStep = bitsStride;
    }
    else {
        majorStep = bitsStride;
        minorStep = signdx;
    }
    while (len--) {
        mixin(STORE!(`bits`, `xor`));
        bits += majorStep;
        e += e1;
        if (e >= 0) {
            bits += minorStep;
            e += e3;
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}
}

version (BRESDASH) {
void BRESDASH(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    UNIT* bits = void;
    FbStride bitsStride = void;
    FbStride majorStep = void, minorStep = void;
    BITS xorfg = void, xorbg = void;

    FbDashDeclare;
    int dashlen = void;
    Bool even = void;
    Bool doOdd = void;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    doOdd = pGC.lineStyle == LineDoubleDash;
    xorfg = cast(BITS) pPriv.xor;
    xorbg = cast(BITS) pPriv.bgxor;

    mixin(FbDashInit!(`pGC`, `pPriv`, `dashOffset`, `dashlen`, `even`));

    bits =
        (cast(UNIT*) (dst + ((y1 + dstYoff) * dstStride))) + (x1 + dstXoff);
    bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    if (signdy < 0)
        bitsStride = -bitsStride;
    if (axis == X_AXIS) {
        majorStep = signdx;
        minorStep = bitsStride;
    }
    else {
        majorStep = bitsStride;
        minorStep = signdx;
    }
    if (dashlen >= len)
        dashlen = len;
    if (doOdd) {
        if (!even)
            goto doubleOdd;
        for (;;) {
            len -= dashlen;
            while (dashlen--) {
                mixin(STORE!(`bits`, `xorfg`));
                bits += majorStep;
                if ((e += e1) >= 0) {
                    e += e3;
                    bits += minorStep;
                }
            }
            if (!len)
                break;

            mixin(FbDashNextEven!(`dashlen`));

            if (dashlen >= len)
                dashlen = len;
 doubleOdd:
            len -= dashlen;
            while (dashlen--) {
                mixin(STORE!(`bits`, `xorbg`));
                bits += majorStep;
                if ((e += e1) >= 0) {
                    e += e3;
                    bits += minorStep;
                }
            }
            if (!len)
                break;

            mixin(FbDashNextOdd!(`dashlen`));

            if (dashlen >= len)
                dashlen = len;
        }
    }
    else {
        if (!even)
            goto onOffOdd;
        for (;;) {
            len -= dashlen;
            while (dashlen--) {
                mixin(STORE!(`bits`, `xorfg`));
                bits += majorStep;
                if ((e += e1) >= 0) {
                    e += e3;
                    bits += minorStep;
                }
            }
            if (!len)
                break;

            mixin(FbDashNextEven!(`dashlen`));

            if (dashlen >= len)
                dashlen = len;
 onOffOdd:
            len -= dashlen;
            while (dashlen--) {
                bits += majorStep;
                if ((e += e1) >= 0) {
                    e += e3;
                    bits += minorStep;
                }
            }
            if (!len)
                break;

            mixin(FbDashNextOdd!(`dashlen`));

            if (dashlen >= len)
                dashlen = len;
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}
}

version (DOTS) {
void DOTS(FbBits* dst, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* ptsOrig, int npt, int xorg, int yorg, int xoff, int yoff, FbBits and, FbBits xor)
{
    INT32* pts = cast(INT32*) ptsOrig;
    UNIT* bits = cast(UNIT*) dst;
    UNIT* point = void;
    BITS bxor = cast(BITS) xor;
    BITS band = cast(BITS) and;
    FbStride bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    INT32 ul = void, lr = void;
    INT32 pt = void;

    ul = coordToInt(pBox.x1 - xorg, pBox.y1 - yorg);
    lr = coordToInt(pBox.x2 - xorg - 1, pBox.y2 - yorg - 1);

    bits += bitsStride * (yorg + yoff) + (xorg + xoff);

    if (and == 0) {
        while (npt--) {
            pt = *pts++;
            if (!mixin(isClipped!(`pt`, `ul`, `lr`))) {
                point = bits + intToY(pt) * bitsStride + intToX(pt);
                mixin(STORE!(`point`, `bxor`));
            }
        }
    }
    else {
        while (npt--) {
            pt = *pts++;
            if (!mixin(isClipped!(`pt`, `ul`, `lr`))) {
                point = bits + intToY(pt) * bitsStride + intToX(pt);
                mixin(RROP!(`point`, `band`, `bxor`));
            }
        }
    }
}
}

version (ARC) {

enum string ARCCOPY(string d) = `` ~ STORE!(
    d
,`xorBits`) ~ ``;
enum string ARCRROP(string d) = `` ~ RROP!(
    d
,`andBits`,`xorBits`) ~ ``;

void ARC(FbBits* dst, FbStride dstStride, int dstBpp, xArc* arc, int drawX, int drawY, FbBits and, FbBits xor)
{
    UNIT* bits = void;
    FbStride bitsStride = void;
    miZeroArcRec info = void;
    Bool do360 = void;
    int x = void;
    UNIT* yorgp = void, yorgop = void;
    BITS andBits = void, xorBits = void;
    int yoffset = void, dyoffset = void;
    int y = void, a = void, b = void, d = void, mask = void;
    int k1 = void, k3 = void, dx = void, dy = void;

    bits = cast(UNIT*) dst;
    bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    andBits = cast(BITS) and;
    xorBits = cast(BITS) xor;
    do360 = miZeroArcSetup(arc, &info, True);
    yorgp = bits + ((info.yorg + drawY) * bitsStride);
    yorgop = bits + ((info.yorgo + drawY) * bitsStride);
    info.xorg = (info.xorg + drawX);
    info.xorgo = (info.xorgo + drawX);
    MIARCSETUP();
    yoffset = y ? bitsStride : 0;
    dyoffset = 0;
    mask = info.initialMask;

    if (!(arc.width & 1)) {
        if (andBits == 0) {
            if (mask & 2)
                mixin(ARCCOPY!(`yorgp + info.xorgo`));
            if (mask & 8)
                mixin(ARCCOPY!(`yorgop + info.xorgo`));
        }
        else {
            if (mask & 2)
                mixin(ARCRROP!(`yorgp + info.xorgo`));
            if (mask & 8)
                mixin(ARCRROP!(`yorgop + info.xorgo`));
        }
    }
    if (!info.end.x || !info.end.y) {
        mask = info.end.mask;
        info.end = info.altend;
    }
    if (do360 && (arc.width == arc.height) && !(arc.width & 1)) {
        int xoffset = bitsStride;
        UNIT* yorghb = yorgp + (info.h * bitsStride) + info.xorg;
        UNIT* yorgohb = yorghb - info.h;

        yorgp += info.xorg;
        yorgop += info.xorg;
        yorghb += info.h;
        while (1) {
            if (andBits == 0) {
                mixin(ARCCOPY!(`yorgp + yoffset + x`));
                mixin(ARCCOPY!(`yorgp + yoffset - x`));
                mixin(ARCCOPY!(`yorgop - yoffset - x`));
                mixin(ARCCOPY!(`yorgop - yoffset + x`));
            }
            else {
                mixin(ARCRROP!(`yorgp + yoffset + x`));
                mixin(ARCRROP!(`yorgp + yoffset - x`));
                mixin(ARCRROP!(`yorgop - yoffset - x`));
                mixin(ARCRROP!(`yorgop - yoffset + x`));
            }
            if (a < 0)
                break;
            if (andBits == 0) {
                mixin(ARCCOPY!(`yorghb - xoffset - y`));
                mixin(ARCCOPY!(`yorgohb - xoffset + y`));
                mixin(ARCCOPY!(`yorgohb + xoffset + y`));
                mixin(ARCCOPY!(`yorghb + xoffset - y`));
            }
            else {
                mixin(ARCRROP!(`yorghb - xoffset - y`));
                mixin(ARCRROP!(`yorgohb - xoffset + y`));
                mixin(ARCRROP!(`yorgohb + xoffset + y`));
                mixin(ARCRROP!(`yorghb + xoffset - y`));
            }
            xoffset += bitsStride;
            MIARCCIRCLESTEP(yoffset += bitsStride);
        }
        yorgp -= info.xorg;
        yorgop -= info.xorg;
        x = info.w;
        yoffset = info.h * bitsStride;
    }
    else if (do360) {
        while (y < info.h || x < info.w) {
            MIARCOCTANTSHIFT(dyoffset = bitsStride);
            if (andBits == 0) {
                mixin(ARCCOPY!(`yorgp + yoffset + info.xorg + x`));
                mixin(ARCCOPY!(`yorgp + yoffset + info.xorgo - x`));
                mixin(ARCCOPY!(`yorgop - yoffset + info.xorgo - x`));
                mixin(ARCCOPY!(`yorgop - yoffset + info.xorg + x`));
            }
            else {
                mixin(ARCRROP!(`yorgp + yoffset + info.xorg + x`));
                mixin(ARCRROP!(`yorgp + yoffset + info.xorgo - x`));
                mixin(ARCRROP!(`yorgop - yoffset + info.xorgo - x`));
                mixin(ARCRROP!(`yorgop - yoffset + info.xorg + x`));
            }
            MIARCSTEP(yoffset += dyoffset,
                      yoffset += bitsStride);
        }
    }
    else {
        while (y < info.h || x < info.w) {
            MIARCOCTANTSHIFT(dyoffset = bitsStride);
            if ((x == info.start.x) || (y == info.start.y)) {
                mask = info.start.mask;
                info.start = info.altstart;
            }
            if (andBits == 0) {
                if (mask & 1)
                    mixin(ARCCOPY!(`yorgp + yoffset + info.xorg + x`));
                if (mask & 2)
                    mixin(ARCCOPY!(`yorgp + yoffset + info.xorgo - x`));
                if (mask & 4)
                    mixin(ARCCOPY!(`yorgop - yoffset + info.xorgo - x`));
                if (mask & 8)
                    mixin(ARCCOPY!(`yorgop - yoffset + info.xorg + x`));
            }
            else {
                if (mask & 1)
                    mixin(ARCRROP!(`yorgp + yoffset + info.xorg + x`));
                if (mask & 2)
                    mixin(ARCRROP!(`yorgp + yoffset + info.xorgo - x`));
                if (mask & 4)
                    mixin(ARCRROP!(`yorgop - yoffset + info.xorgo - x`));
                if (mask & 8)
                    mixin(ARCRROP!(`yorgop - yoffset + info.xorg + x`));
            }
            if ((x == info.end.x) || (y == info.end.y)) {
                mask = info.end.mask;
                info.end = info.altend;
            }
            MIARCSTEP(yoffset += dyoffset
                      , yoffset += bitsStride);
        }
    }
    if ((x == info.start.x) || (y == info.start.y))
        mask = info.start.mask;
    if (andBits == 0) {
        if (mask & 1)
            mixin(ARCCOPY!(`yorgp + yoffset + info.xorg + x`));
        if (mask & 4)
            mixin(ARCCOPY!(`yorgop - yoffset + info.xorgo - x`));
        if (arc.height & 1) {
            if (mask & 2)
                mixin(ARCCOPY!(`yorgp + yoffset + info.xorgo - x`));
            if (mask & 8)
                mixin(ARCCOPY!(`yorgop - yoffset + info.xorg + x`));
        }
    }
    else {
        if (mask & 1)
            mixin(ARCRROP!(`yorgp + yoffset + info.xorg + x`));
        if (mask & 4)
            mixin(ARCRROP!(`yorgop - yoffset + info.xorgo - x`));
        if (arc.height & 1) {
            if (mask & 2)
                mixin(ARCRROP!(`yorgp + yoffset + info.xorgo - x`));
            if (mask & 8)
                mixin(ARCRROP!(`yorgop - yoffset + info.xorg + x`));
        }
    }
}

}

version (GLYPH) {
static if (BITMAP_BIT_ORDER == LSBFirst) {
enum string WRITE_ADDR1(string n) = `(` ~ n ~ `)`;
enum string WRITE_ADDR2(string n) = `(` ~ n ~ `)`;
enum string WRITE_ADDR4(string n) = `(` ~ n ~ `)`;
} else {
enum string WRITE_ADDR1(string n) = `((` ~ n ~ `) ^ 3)`;
enum string WRITE_ADDR2(string n) = `((` ~ n ~ `) ^ 2)`;
enum string WRITE_ADDR4(string n) = `((` ~ n ~ `))`;
}

enum string WRITE1(string d,string n,string fg) = `WRITE(` ~ d ~ ` + ` ~ WRITE_ADDR1!(
    n
) ~ `, cast(BITS) (` ~ fg ~ `))`;

version (BITS2) {
enum string WRITE2(string d,string n,string fg) = `WRITE(cast(BITS2*) &((` ~ d ~ `)[` ~ WRITE_ADDR2!(
    n
) ~ `]), cast(BITS2) (` ~ fg ~ `))`;
} else {
enum string WRITE2(string d,string n,string fg) = `(` ~ WRITE1!(
    d
,
n
,
fg
) ~ `, ` ~ WRITE1!(
    d
,`(` ~ n ~ `)+1`,
fg
) ~ `)`;
}

version (BITS4) {
enum string WRITE4(string d,string n,string fg) = `WRITE(cast(BITS4*) &((` ~ d ~ `)[` ~ WRITE_ADDR4!(
    n
) ~ `]), cast(BITS4) (` ~ fg ~ `))`;
} else {
enum string WRITE4(string d,string n,string fg) = `(` ~ WRITE2!(
    d
,
n
,
fg
) ~ `, ` ~ WRITE2!(
    d
,`(` ~ n ~ `)+2`,
fg
) ~ `)`;
}

void GLYPH(FbBits* dstBits, FbStride dstStride, int dstBpp, FbStip* stipple, FbBits fg, int x, int height)
{
    int lshift = void;
    FbStip bits = void;
    BITS* dstLine = void;
    BITS* dst = void;
    int n = void;
    int shift = void;

    dstLine = cast(BITS*) dstBits;
    dstLine += x & ~3;
    dstStride *= (FbBits.sizeof / BITS.sizeof);
    shift = x & 3;
    lshift = 4 - shift;
    while (height--) {
        bits = *stipple++;
        dst = cast(BITS*) dstLine;
        n = lshift;
        while (bits) {
            switch (FbStipMoveLsb(FbLeftStipBits(bits, n), 4, n)) {
            case 0:
                break;
            case 1:
                mixin(WRITE1!(`dst`, `0`, `fg`));
                break;
            case 2:
                mixin(WRITE1!(`dst`, `1`, `fg`));
                break;
            case 3:
                mixin(WRITE2!(`dst`, `0`, `fg`));
                break;
            case 4:
                mixin(WRITE1!(`dst`, `2`, `fg`));
                break;
            case 5:
                mixin(WRITE1!(`dst`, `0`, `fg`));
                mixin(WRITE1!(`dst`, `2`, `fg`));
                break;
            case 6:
                mixin(WRITE1!(`dst`, `1`, `fg`));
                mixin(WRITE1!(`dst`, `2`, `fg`));
                break;
            case 7:
                mixin(WRITE2!(`dst`, `0`, `fg`));
                mixin(WRITE1!(`dst`, `2`, `fg`));
                break;
            case 8:
                mixin(WRITE1!(`dst`, `3`, `fg`));
                break;
            case 9:
                mixin(WRITE1!(`dst`, `0`, `fg`));
                mixin(WRITE1!(`dst`, `3`, `fg`));
                break;
            case 10:
                mixin(WRITE1!(`dst`, `1`, `fg`));
                mixin(WRITE1!(`dst`, `3`, `fg`));
                break;
            case 11:
                mixin(WRITE2!(`dst`, `0`, `fg`));
                mixin(WRITE1!(`dst`, `3`, `fg`));
                break;
            case 12:
                mixin(WRITE2!(`dst`, `2`, `fg`));
                break;
            case 13:
                mixin(WRITE1!(`dst`, `0`, `fg`));
                mixin(WRITE2!(`dst`, `2`, `fg`));
                break;
            case 14:
                mixin(WRITE1!(`dst`, `1`, `fg`));
                mixin(WRITE2!(`dst`, `2`, `fg`));
                break;
            case 15:
                mixin(WRITE4!(`dst`, `0`, `fg`));
                break;
            default: break;}
            bits = FbStipLeft(bits, n);
            n = 4;
            dst += 4;
        }
        dstLine += dstStride;
    }
}

}

version (POLYLINE) {
void POLYLINE(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, xPoint* ptsOrig)
{
    INT32* pts = cast(INT32*) ptsOrig;
    int xoff = pDrawable.x;
    int yoff = pDrawable.y;
    uint bias = miGetZeroLineBias(pDrawable.pScreen);
    BoxPtr pBox = RegionExtents(mixin(fbGetCompositeClip!("pGC")));

    FbBits* dst = void;
    int dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;

    UNIT* bits = void, bitsBase = void;
    FbStride bitsStride = void;
    BITS xor = mixin(fbGetGCPrivate!("pGC")).xor;
    BITS and = mixin(fbGetGCPrivate!("pGC")).and;
    int dashoffset = 0;

    INT32 ul = void, lr = void;
    INT32 pt1 = void, pt2 = void;

    int e = void, e1 = void, e3 = void, len = void;
    int stepmajor = void, stepminor = void;
    int octant = void;

    if (mode == CoordModePrevious)
        fbFixCoordModePrevious(npt, ptsOrig);

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    bitsBase =
        (cast(UNIT*) dst) + (yoff + dstYoff) * bitsStride + (xoff + dstXoff);
    ul = coordToInt(pBox.x1 - xoff, pBox.y1 - yoff);
    lr = coordToInt(pBox.x2 - xoff - 1, pBox.y2 - yoff - 1);

    pt1 = *pts++;
    npt--;
    pt2 = *pts++;
    npt--;
    for (;;) {
        if (mixin(isClipped!(`pt1`, `ul`, `lr`)) | mixin(isClipped!(`pt2`, `ul`, `lr`))) {
            fbSegment(pDrawable, pGC,
                      intToX(pt1) + xoff, intToY(pt1) + yoff,
                      intToX(pt2) + xoff, intToY(pt2) + yoff,
                      npt == 0 && pGC.capStyle != CapNotLast, &dashoffset);
            if (!npt) {
                mixin(fbFinishAccess!("pDrawable"));
                return;
            }
            pt1 = pt2;
            pt2 = *pts++;
            npt--;
        }
        else {
            bits = bitsBase + intToY(pt1) * bitsStride + intToX(pt1);
            for (;;) {
                CalcLineDeltas(intToX(pt1), intToY(pt1),
                               intToX(pt2), intToY(pt2),
                               len, e1, stepmajor, stepminor, 1, bitsStride,
                               octant);
                if (len < e1) {
                    e3 = len;
                    len = e1;
                    e1 = e3;

                    e3 = stepminor;
                    stepminor = stepmajor;
                    stepmajor = e3;
                    SetYMajorOctant(octant);
                }
                e = -len;
                e1 <<= 1;
                e3 = e << 1;
                FIXUP_ERROR(e, octant, bias);
                if (and == 0) {
                    while (len--) {
                        mixin(STORE!(`bits`, `xor`));
                        bits += stepmajor;
                        e += e1;
                        if (e >= 0) {
                            bits += stepminor;
                            e += e3;
                        }
                    }
                }
                else {
                    while (len--) {
                        mixin(RROP!(`bits`, `and`, `xor`));
                        bits += stepmajor;
                        e += e1;
                        if (e >= 0) {
                            bits += stepminor;
                            e += e3;
                        }
                    }
                }
                if (!npt) {
                    if (pGC.capStyle != CapNotLast &&
                        pt2 != *(cast(INT32*) ptsOrig)) {
                        mixin(RROP!(`bits`, `and`, `xor`));
                    }
                    mixin(fbFinishAccess!("pDrawable"));
                    return;
                }
                pt1 = pt2;
                pt2 = *pts++;
                --npt;
                if (mixin(isClipped!(`pt2`, `ul`, `lr`)))
                    break;
            }
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}
}

version (POLYSEGMENT) {
void POLYSEGMENT(DrawablePtr pDrawable, GCPtr pGC, int nseg, xSegment* pseg)
{
    INT32* pts = cast(INT32*) pseg;
    int xoff = pDrawable.x;
    int yoff = pDrawable.y;
    uint bias = miGetZeroLineBias(pDrawable.pScreen);
    BoxPtr pBox = RegionExtents(mixin(fbGetCompositeClip!("pGC")));

    FbBits* dst = void;
    int dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;

    UNIT* bits = void, bitsBase = void;
    FbStride bitsStride = void;
    FbBits xorBits = mixin(fbGetGCPrivate!("pGC")).xor;
    FbBits andBits = mixin(fbGetGCPrivate!("pGC")).and;
    BITS xor = xorBits;
    BITS and = andBits;
    int dashoffset = 0;

    INT32 ul = void, lr = void;
    INT32 pt1 = void, pt2 = void;

    int e = void, e1 = void, e3 = void, len = void;
    int stepmajor = void, stepminor = void;
    int octant = void;
    Bool capNotLast = void;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    bitsStride = dstStride * (FbBits.sizeof / UNIT.sizeof);
    bitsBase =
        (cast(UNIT*) dst) + (yoff + dstYoff) * bitsStride + (xoff + dstXoff);
    ul = coordToInt(pBox.x1 - xoff, pBox.y1 - yoff);
    lr = coordToInt(pBox.x2 - xoff - 1, pBox.y2 - yoff - 1);

    capNotLast = pGC.capStyle == CapNotLast;

    while (nseg--) {
        pt1 = *pts++;
        pt2 = *pts++;
        if (mixin(isClipped!(`pt1`, `ul`, `lr`)) | mixin(isClipped!(`pt2`, `ul`, `lr`))) {
            fbSegment(pDrawable, pGC,
                      intToX(pt1) + xoff, intToY(pt1) + yoff,
                      intToX(pt2) + xoff, intToY(pt2) + yoff,
                      !capNotLast, &dashoffset);
        }
        else {
            CalcLineDeltas(intToX(pt1), intToY(pt1),
                           intToX(pt2), intToY(pt2),
                           len, e1, stepmajor, stepminor, 1, bitsStride,
                           octant);
            if (e1 == 0 && len > 3) {
                int x1 = void, x2 = void;
                FbBits* dstLine = void;
                int dstX = void, width = void;
                FbBits startmask = void, endmask = void;
                int nmiddle = void;

                if (stepmajor < 0) {
                    x1 = intToX(pt2);
                    x2 = intToX(pt1) + 1;
                    if (capNotLast)
                        x1++;
                }
                else {
                    x1 = intToX(pt1);
                    x2 = intToX(pt2);
                    if (!capNotLast)
                        x2++;
                }
                dstX = (x1 + xoff + dstXoff) * (((UNIT) * 8).sizeof);
                width = (x2 - x1) * (((UNIT) * 8).sizeof);

                dstLine = dst + (intToY(pt1) + yoff + dstYoff) * dstStride;
                dstLine += dstX >> FB_SHIFT;
                dstX &= FB_MASK;
                mixin(__FbMaskBits!(`dstX`, `width`, `startmask`, `nmiddle`, `endmask`));
                if (startmask) {
                    WRITE(dstLine,
                          FbDoMaskRRop(READ(dstLine), andBits, xorBits,
                                       startmask));
                    dstLine++;
                }
                if (!andBits)
                    while (nmiddle--)
                        WRITE(dstLine++, xorBits);
                else
                    while (nmiddle--) {
                        WRITE(dstLine,
                              FbDoRRop(READ(dstLine), andBits, xorBits));
                        dstLine++;
                    }
                if (endmask)
                    WRITE(dstLine,
                          FbDoMaskRRop(READ(dstLine), andBits, xorBits,
                                       endmask));
            }
            else {
                bits = bitsBase + intToY(pt1) * bitsStride + intToX(pt1);
                if (len < e1) {
                    e3 = len;
                    len = e1;
                    e1 = e3;

                    e3 = stepminor;
                    stepminor = stepmajor;
                    stepmajor = e3;
                    SetYMajorOctant(octant);
                }
                e = -len;
                e1 <<= 1;
                e3 = e << 1;
                FIXUP_ERROR(e, octant, bias);
                if (!capNotLast)
                    len++;
                if (and == 0) {
                    while (len--) {
                        mixin(STORE!(`bits`, `xor`));
                        bits += stepmajor;
                        e += e1;
                        if (e >= 0) {
                            bits += stepminor;
                            e += e3;
                        }
                    }
                }
                else {
                    while (len--) {
                        mixin(RROP!(`bits`, `and`, `xor`));
                        bits += stepmajor;
                        e += e1;
                        if (e >= 0) {
                            bits += stepminor;
                            e += e3;
                        }
                    }
                }
            }
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}
}

