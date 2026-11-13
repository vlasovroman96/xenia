module fbbltone;
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

import build.dix_config;

import fb.fb;
import fb.fbutil;
import fb.fbrop;

/*
 * Stipple masks are independent of bit/byte order as long
 * as bitorder == byteorder.  FB doesn't handle the case
 * where these differ
 */
enum string BitsMask(string x,string w) = `((FB_ALLONES << ((` ~ x ~ `) & FB_MASK)) & 
			 (FB_ALLONES >> ((FB_UNIT - ((` ~ x ~ `) + (` ~ w ~ `))) & FB_MASK)))`;

enum string Mask(string x,string w) = `` ~ BitsMask!(`(` ~ x ~ `)*(` ~ w ~ `)`,`(` ~ w ~ `)`) ~ ``;

enum string SelMask(string b,string n,string w) = `((((` ~ b ~ `) >> ` ~ n ~ `) & 1) * ` ~ Mask!(n,w) ~ `)`;

enum string C1(string b,string w) = `
    (` ~ SelMask!(b,`0`,w) ~ `)`;

enum string C2(string b,string w) = `
    (` ~ SelMask!(b,`0`,w) ~ ` | 
     ` ~ SelMask!(b,`1`,w) ~ `)`;

enum string C4(string b,string w) = `
    (` ~ SelMask!(b,`0`,w) ~ ` | 
     ` ~ SelMask!(b,`1`,w) ~ ` | 
     ` ~ SelMask!(b,`2`,w) ~ ` | 
     ` ~ SelMask!(b,`3`,w) ~ `)`;

enum string C8(string b,string w) = `
    (` ~ SelMask!(b,`0`,w) ~ ` | 
     ` ~ SelMask!(b,`1`,w) ~ ` | 
     ` ~ SelMask!(b,`2`,w) ~ ` | 
     ` ~ SelMask!(b,`3`,w) ~ ` | 
     ` ~ SelMask!(b,`4`,w) ~ ` | 
     ` ~ SelMask!(b,`5`,w) ~ ` | 
     ` ~ SelMask!(b,`6`,w) ~ ` | 
     ` ~ SelMask!(b,`7`,w) ~ `)`;

private const(FbBits)[256] fbStipple8Bits = [
    mixin(C8!(`0`, `4`)), mixin(C8!(`1`, `4`)), mixin(C8!(`2`, `4`)), mixin(C8!(`3`, `4`)), mixin(C8!(`4`, `4`)), mixin(C8!(`5`, `4`)),
    mixin(C8!(`6`, `4`)), mixin(C8!(`7`, `4`)), mixin(C8!(`8`, `4`)), mixin(C8!(`9`, `4`)), mixin(C8!(`10`, `4`)), mixin(C8!(`11`, `4`)),
    mixin(C8!(`12`, `4`)), mixin(C8!(`13`, `4`)), mixin(C8!(`14`, `4`)), mixin(C8!(`15`, `4`)), mixin(C8!(`16`, `4`)), mixin(C8!(`17`, `4`)),
    mixin(C8!(`18`, `4`)), mixin(C8!(`19`, `4`)), mixin(C8!(`20`, `4`)), mixin(C8!(`21`, `4`)), mixin(C8!(`22`, `4`)), mixin(C8!(`23`, `4`)),
    mixin(C8!(`24`, `4`)), mixin(C8!(`25`, `4`)), mixin(C8!(`26`, `4`)), mixin(C8!(`27`, `4`)), mixin(C8!(`28`, `4`)), mixin(C8!(`29`, `4`)),
    mixin(C8!(`30`, `4`)), mixin(C8!(`31`, `4`)), mixin(C8!(`32`, `4`)), mixin(C8!(`33`, `4`)), mixin(C8!(`34`, `4`)), mixin(C8!(`35`, `4`)),
    mixin(C8!(`36`, `4`)), mixin(C8!(`37`, `4`)), mixin(C8!(`38`, `4`)), mixin(C8!(`39`, `4`)), mixin(C8!(`40`, `4`)), mixin(C8!(`41`, `4`)),
    mixin(C8!(`42`, `4`)), mixin(C8!(`43`, `4`)), mixin(C8!(`44`, `4`)), mixin(C8!(`45`, `4`)), mixin(C8!(`46`, `4`)), mixin(C8!(`47`, `4`)),
    mixin(C8!(`48`, `4`)), mixin(C8!(`49`, `4`)), mixin(C8!(`50`, `4`)), mixin(C8!(`51`, `4`)), mixin(C8!(`52`, `4`)), mixin(C8!(`53`, `4`)),
    mixin(C8!(`54`, `4`)), mixin(C8!(`55`, `4`)), mixin(C8!(`56`, `4`)), mixin(C8!(`57`, `4`)), mixin(C8!(`58`, `4`)), mixin(C8!(`59`, `4`)),
    mixin(C8!(`60`, `4`)), mixin(C8!(`61`, `4`)), mixin(C8!(`62`, `4`)), mixin(C8!(`63`, `4`)), mixin(C8!(`64`, `4`)), mixin(C8!(`65`, `4`)),
    mixin(C8!(`66`, `4`)), mixin(C8!(`67`, `4`)), mixin(C8!(`68`, `4`)), mixin(C8!(`69`, `4`)), mixin(C8!(`70`, `4`)), mixin(C8!(`71`, `4`)),
    mixin(C8!(`72`, `4`)), mixin(C8!(`73`, `4`)), mixin(C8!(`74`, `4`)), mixin(C8!(`75`, `4`)), mixin(C8!(`76`, `4`)), mixin(C8!(`77`, `4`)),
    mixin(C8!(`78`, `4`)), mixin(C8!(`79`, `4`)), mixin(C8!(`80`, `4`)), mixin(C8!(`81`, `4`)), mixin(C8!(`82`, `4`)), mixin(C8!(`83`, `4`)),
    mixin(C8!(`84`, `4`)), mixin(C8!(`85`, `4`)), mixin(C8!(`86`, `4`)), mixin(C8!(`87`, `4`)), mixin(C8!(`88`, `4`)), mixin(C8!(`89`, `4`)),
    mixin(C8!(`90`, `4`)), mixin(C8!(`91`, `4`)), mixin(C8!(`92`, `4`)), mixin(C8!(`93`, `4`)), mixin(C8!(`94`, `4`)), mixin(C8!(`95`, `4`)),
    mixin(C8!(`96`, `4`)), mixin(C8!(`97`, `4`)), mixin(C8!(`98`, `4`)), mixin(C8!(`99`, `4`)), mixin(C8!(`100`, `4`)), mixin(C8!(`101`, `4`)),
    mixin(C8!(`102`, `4`)), mixin(C8!(`103`, `4`)), mixin(C8!(`104`, `4`)), mixin(C8!(`105`, `4`)), mixin(C8!(`106`, `4`)), mixin(C8!(`107`, `4`)),
    mixin(C8!(`108`, `4`)), mixin(C8!(`109`, `4`)), mixin(C8!(`110`, `4`)), mixin(C8!(`111`, `4`)), mixin(C8!(`112`, `4`)), mixin(C8!(`113`, `4`)),
    mixin(C8!(`114`, `4`)), mixin(C8!(`115`, `4`)), mixin(C8!(`116`, `4`)), mixin(C8!(`117`, `4`)), mixin(C8!(`118`, `4`)), mixin(C8!(`119`, `4`)),
    mixin(C8!(`120`, `4`)), mixin(C8!(`121`, `4`)), mixin(C8!(`122`, `4`)), mixin(C8!(`123`, `4`)), mixin(C8!(`124`, `4`)), mixin(C8!(`125`, `4`)),
    mixin(C8!(`126`, `4`)), mixin(C8!(`127`, `4`)), mixin(C8!(`128`, `4`)), mixin(C8!(`129`, `4`)), mixin(C8!(`130`, `4`)), mixin(C8!(`131`, `4`)),
    mixin(C8!(`132`, `4`)), mixin(C8!(`133`, `4`)), mixin(C8!(`134`, `4`)), mixin(C8!(`135`, `4`)), mixin(C8!(`136`, `4`)), mixin(C8!(`137`, `4`)),
    mixin(C8!(`138`, `4`)), mixin(C8!(`139`, `4`)), mixin(C8!(`140`, `4`)), mixin(C8!(`141`, `4`)), mixin(C8!(`142`, `4`)), mixin(C8!(`143`, `4`)),
    mixin(C8!(`144`, `4`)), mixin(C8!(`145`, `4`)), mixin(C8!(`146`, `4`)), mixin(C8!(`147`, `4`)), mixin(C8!(`148`, `4`)), mixin(C8!(`149`, `4`)),
    mixin(C8!(`150`, `4`)), mixin(C8!(`151`, `4`)), mixin(C8!(`152`, `4`)), mixin(C8!(`153`, `4`)), mixin(C8!(`154`, `4`)), mixin(C8!(`155`, `4`)),
    mixin(C8!(`156`, `4`)), mixin(C8!(`157`, `4`)), mixin(C8!(`158`, `4`)), mixin(C8!(`159`, `4`)), mixin(C8!(`160`, `4`)), mixin(C8!(`161`, `4`)),
    mixin(C8!(`162`, `4`)), mixin(C8!(`163`, `4`)), mixin(C8!(`164`, `4`)), mixin(C8!(`165`, `4`)), mixin(C8!(`166`, `4`)), mixin(C8!(`167`, `4`)),
    mixin(C8!(`168`, `4`)), mixin(C8!(`169`, `4`)), mixin(C8!(`170`, `4`)), mixin(C8!(`171`, `4`)), mixin(C8!(`172`, `4`)), mixin(C8!(`173`, `4`)),
    mixin(C8!(`174`, `4`)), mixin(C8!(`175`, `4`)), mixin(C8!(`176`, `4`)), mixin(C8!(`177`, `4`)), mixin(C8!(`178`, `4`)), mixin(C8!(`179`, `4`)),
    mixin(C8!(`180`, `4`)), mixin(C8!(`181`, `4`)), mixin(C8!(`182`, `4`)), mixin(C8!(`183`, `4`)), mixin(C8!(`184`, `4`)), mixin(C8!(`185`, `4`)),
    mixin(C8!(`186`, `4`)), mixin(C8!(`187`, `4`)), mixin(C8!(`188`, `4`)), mixin(C8!(`189`, `4`)), mixin(C8!(`190`, `4`)), mixin(C8!(`191`, `4`)),
    mixin(C8!(`192`, `4`)), mixin(C8!(`193`, `4`)), mixin(C8!(`194`, `4`)), mixin(C8!(`195`, `4`)), mixin(C8!(`196`, `4`)), mixin(C8!(`197`, `4`)),
    mixin(C8!(`198`, `4`)), mixin(C8!(`199`, `4`)), mixin(C8!(`200`, `4`)), mixin(C8!(`201`, `4`)), mixin(C8!(`202`, `4`)), mixin(C8!(`203`, `4`)),
    mixin(C8!(`204`, `4`)), mixin(C8!(`205`, `4`)), mixin(C8!(`206`, `4`)), mixin(C8!(`207`, `4`)), mixin(C8!(`208`, `4`)), mixin(C8!(`209`, `4`)),
    mixin(C8!(`210`, `4`)), mixin(C8!(`211`, `4`)), mixin(C8!(`212`, `4`)), mixin(C8!(`213`, `4`)), mixin(C8!(`214`, `4`)), mixin(C8!(`215`, `4`)),
    mixin(C8!(`216`, `4`)), mixin(C8!(`217`, `4`)), mixin(C8!(`218`, `4`)), mixin(C8!(`219`, `4`)), mixin(C8!(`220`, `4`)), mixin(C8!(`221`, `4`)),
    mixin(C8!(`222`, `4`)), mixin(C8!(`223`, `4`)), mixin(C8!(`224`, `4`)), mixin(C8!(`225`, `4`)), mixin(C8!(`226`, `4`)), mixin(C8!(`227`, `4`)),
    mixin(C8!(`228`, `4`)), mixin(C8!(`229`, `4`)), mixin(C8!(`230`, `4`)), mixin(C8!(`231`, `4`)), mixin(C8!(`232`, `4`)), mixin(C8!(`233`, `4`)),
    mixin(C8!(`234`, `4`)), mixin(C8!(`235`, `4`)), mixin(C8!(`236`, `4`)), mixin(C8!(`237`, `4`)), mixin(C8!(`238`, `4`)), mixin(C8!(`239`, `4`)),
    mixin(C8!(`240`, `4`)), mixin(C8!(`241`, `4`)), mixin(C8!(`242`, `4`)), mixin(C8!(`243`, `4`)), mixin(C8!(`244`, `4`)), mixin(C8!(`245`, `4`)),
    mixin(C8!(`246`, `4`)), mixin(C8!(`247`, `4`)), mixin(C8!(`248`, `4`)), mixin(C8!(`249`, `4`)), mixin(C8!(`250`, `4`)), mixin(C8!(`251`, `4`)),
    mixin(C8!(`252`, `4`)), mixin(C8!(`253`, `4`)), mixin(C8!(`254`, `4`)), mixin(C8!(`255`, `4`)),
];

private const(FbBits)[16] fbStipple4Bits = [
    mixin(C4!(`0`, `8`)), mixin(C4!(`1`, `8`)), mixin(C4!(`2`, `8`)), mixin(C4!(`3`, `8`)), mixin(C4!(`4`, `8`)), mixin(C4!(`5`, `8`)),
    mixin(C4!(`6`, `8`)), mixin(C4!(`7`, `8`)), mixin(C4!(`8`, `8`)), mixin(C4!(`9`, `8`)), mixin(C4!(`10`, `8`)), mixin(C4!(`11`, `8`)),
    mixin(C4!(`12`, `8`)), mixin(C4!(`13`, `8`)), mixin(C4!(`14`, `8`)), mixin(C4!(`15`, `8`)),
];

private const(FbBits)[4] fbStipple2Bits = [
    mixin(C2!(`0`, `16`)), mixin(C2!(`1`, `16`)), mixin(C2!(`2`, `16`)), mixin(C2!(`3`, `16`)),
];

private const(FbBits)[2] fbStipple1Bits = [
    mixin(C1!(`0`, `32`)), mixin(C1!(`1`, `32`)),
];

version (__clang__) {
/* shift overflow is intentional */
// #pragma clang diagnostic ignored "-Wshift-overflow"
}

/*
 *  Example: srcX = 13 dstX = 8	(FB unit 32 dstBpp 8)
 *
 *	**** **** **** **** **** **** **** ****
 *			^
 *	********  ********  ********  ********
 *		  ^
 *  leftShift = 12
 *  rightShift = 20
 *
 *  Example: srcX = 0 dstX = 8 (FB unit 32 dstBpp 8)
 *
 *	**** **** **** **** **** **** **** ****
 *	^		
 *	********  ********  ********  ********
 *		  ^
 *
 *  leftShift = 24
 *  rightShift = 8
 */

enum string LoadBits = q{
    if (leftShift) { 
        bitsRight = (src < srcEnd ? mixin(READ!("src++")) : 0); 
        bits = (mixin(FbStipLeft!("bitsLeft", "leftShift")) | 
                mixin(FbStipRight!("bitsRight", "rightShift"))); 
        bitsLeft = bitsRight; 
    } else {
        bits = (src < srcEnd ? mixin(READ!("src++")) : 0); 
    }
};

void fbBltOne(FbStip* src, FbStride srcStride, int srcX, FbBits* dst, FbStride dstStride, int dstX, int dstBpp, int width, int height, FbBits fgand, FbBits fgxor, FbBits bgand, FbBits bgxor)
{
    const(FbBits)* fbBits = void;
    FbBits* srcEnd = void;
    int pixelsPerDst = void;           /* dst pixels per FbBits */
    int unitsPerSrc = void;            /* src patterns per FbStip */
    int leftShift = void, rightShift = void;  /* align source with dest */
    FbBits startmask = void, endmask = void;  /* dest scanline masks */
    FbStip bits = 0, bitsLeft = void, bitsRight = void;       /* source bits */
    FbStip left = void;
    FbBits mask = void;
    int nDst = void;                   /* dest longwords (w.o. end) */
    int w = void;
    int n = void, nmiddle = void;
    int dstS = void;                   /* stipple-relative dst X coordinate */
    Bool copy = void;                  /* accelerate dest-invariant */
    Bool transparent = void;           /* accelerate 0 nop */
    int srcinc = void;                 /* source units consumed */
    Bool endNeedsLoad = False;  /* need load for endmask */
    int startbyte = void, endbyte = void;

    /*
     * Do not read past the end of the buffer!
     */
    srcEnd = src + height * srcStride;

    /*
     * Number of destination units in FbBits == number of stipple pixels
     * used each time
     */
    pixelsPerDst = FB_UNIT / dstBpp;

    /*
     * Number of source stipple patterns in FbStip
     */
    unitsPerSrc = FB_STIP_UNIT / pixelsPerDst;

    copy = False;
    transparent = False;
    if (bgand == 0 && fgand == 0)
        copy = True;
    else if (bgand == FB_ALLONES && bgxor == 0)
        transparent = True;

    /*
     * Adjust source and dest to nearest FbBits boundary
     */
    src += srcX >> FB_STIP_SHIFT;
    dst += dstX >> FB_SHIFT;
    srcX &= FB_STIP_MASK;
    dstX &= FB_MASK;

    mixin(FbMaskBitsBytes!("dstX", "width", "copy",
                    "startmask", "startbyte", "nmiddle", "endmask", "endbyte"));

    /*
     * Compute effective dest alignment requirement for
     * source -- must align source to dest unit boundary
     */
    dstS = dstX / dstBpp;
    /*
     * Compute shift constants for effective alignment
     */
    if (srcX >= dstS) {
        leftShift = srcX - dstS;
        rightShift = FB_STIP_UNIT - leftShift;
    }
    else {
        rightShift = dstS - srcX;
        leftShift = FB_STIP_UNIT - rightShift;
    }
    /*
     * Get pointer to stipple mask array for this depth
     */
    fbBits = null;                 /* unused */
    switch (pixelsPerDst) {
    case 8:
        fbBits = fbStipple8Bits.ptr;
        break;
    case 4:
        fbBits = fbStipple4Bits.ptr;
        break;
    case 2:
        fbBits = fbStipple2Bits.ptr;
        break;
    case 1:
        fbBits = fbStipple1Bits.ptr;
        break;
    default:
        return;
    }

    /*
     * Compute total number of destination words written, but
     * don't count endmask
     */
    nDst = nmiddle;
    if (startmask)
        nDst++;

    dstStride -= nDst;

    /*
     * Compute total number of source words consumed
     */

    srcinc = (nDst + unitsPerSrc - 1) / unitsPerSrc;

    if (srcX > dstS)
        srcinc++;
    if (endmask) {
        endNeedsLoad = nDst % unitsPerSrc == 0;
        if (endNeedsLoad)
            srcinc++;
    }

    srcStride -= srcinc;

    /*
     * Copy rectangle
     */
    while (height--) {
        w = nDst;               /* total units across scanline */
        n = unitsPerSrc;        /* units avail in single stipple */
        if (n > w)
            n = w;

        bitsLeft = 0;
        if (srcX > dstS)
            bitsLeft = mixin(READ!("src++"));
        if (n) {
            /*
             * Load first set of stipple bits
             */
            mixin(LoadBits);

            /*
             * Consume stipple bits for startmask
             */
            if (startmask) {
                mask = fbBits[mixin(FbLeftStipBits!("bits", "pixelsPerDst"))];
                if (mask || !transparent)
                    mixin(FbDoLeftMaskByteStippleRRop!("dst", "mask",
                                                "fgand", "fgxor", "bgand", "bgxor",
                                                "startbyte", "startmask"));
                bits = mixin(FbStipLeft!("bits", "pixelsPerDst"));
                dst++;
                n--;
                w--;
            }
            /*
             * Consume stipple bits across scanline
             */
            for (;;) {
                w -= n;
                if (copy) {
                    while (n--) {
                        mask = fbBits[mixin(FbLeftStipBits!("bits", "pixelsPerDst"))];
                        mixin(WRITE!("dst", FbOpaqueStipple!("mask", "fgxor", "bgxor"))~`;`);
                        dst++;
                        bits = mixin(FbStipLeft!("bits", "pixelsPerDst"));
                    }
                }
                else {
                    while (n--) {
                        left = mixin(FbLeftStipBits!("bits", "pixelsPerDst"));
                        if (left || !transparent) {
                            mask = fbBits[left];
                            mixin(WRITE!("dst", FbStippleRRop!(READ!("dst"), "mask", "fgand",
                                                     "fgxor", "bgand", "bgxor"))~";");
                        }
                        dst++;
                        bits = mixin(FbStipLeft!("bits", "pixelsPerDst"));
                    }
                }
                if (!w)
                    break;
                /*
                 * Load another set and reset number of available units
                 */
                mixin(LoadBits);
                n = unitsPerSrc;
                if (n > w)
                    n = w;
            }
        }
        /*
         * Consume stipple bits for endmask
         */
        if (endmask) {
            if (endNeedsLoad) {
                mixin(LoadBits);
            }
            mask = fbBits[mixin(FbLeftStipBits!("bits", "pixelsPerDst"))];
            if (mask || !transparent)
                mixin(FbDoRightMaskByteStippleRRop!("dst", "mask", "fgand", "fgxor",
                                             "bgand", "bgxor", "endbyte", "endmask"));
        }
        dst += dstStride;
        src += srcStride;
    }
}

/*
 * Not very efficient, but simple -- copy a single plane
 * from an N bit image to a 1 bit image
 */

void fbBltPlane(FbBits* src, FbStride srcStride, int srcX, int srcBpp, FbStip* dst, FbStride dstStride, int dstX, int width, int height, FbStip fgand, FbStip fgxor, FbStip bgand, FbStip bgxor, Pixel planeMask)
{
    FbBits* s = void;
    FbBits pm = void;
    FbBits srcMask = void;
    FbBits srcMaskFirst = void;
    FbBits srcMask0 = 0;
    FbBits srcBits = void;

    FbStip dstBits = void;
    FbStip* d = void;
    FbStip dstMask = void;
    FbStip dstMaskFirst = void;
    FbStip dstUnion = void;
    int w = void;
    int wt = void;

    if (!width)
        return;

    src += srcX >> FB_SHIFT;
    srcX &= FB_MASK;

    dst += dstX >> FB_STIP_SHIFT;
    dstX &= FB_STIP_MASK;

    w = width / srcBpp;

    pm = fbReplicatePixel(planeMask, srcBpp);
    srcMaskFirst = pm & mixin(FbBitsMask!("srcX", "srcBpp"));
    srcMask0 = pm & mixin(FbBitsMask!("0", "srcBpp"));

    dstMaskFirst = mixin(FbStipMask!("dstX", "1"));
    while (height--) {
        d = dst;
        dst += dstStride;
        s = src;
        src += srcStride;

        srcMask = srcMaskFirst;
        srcBits = mixin(READ!("s++"));

        dstMask = dstMaskFirst;
        dstUnion = 0;
        dstBits = 0;

        wt = w;

        while (wt--) {
            if (!srcMask) {
                srcBits = mixin(READ!("s++"));
                srcMask = srcMask0;
            }
            if (!dstMask) {
                mixin(WRITE!("d", FbStippleRRopMask!(READ!("d"), "dstBits",
                                           "fgand", "fgxor", "bgand", "bgxor",
                                           "dstUnion"))~`;`);
                d++;
                dstMask = mixin(FbStipMask!("0", "1"));
                dstUnion = 0;
                dstBits = 0;
            }
            if (srcBits & srcMask)
                dstBits |= dstMask;
            dstUnion |= dstMask;
            if (srcBpp == FB_UNIT)
                srcMask = 0;
            else
                srcMask = mixin(FbScrRight!("srcMask", "srcBpp"));
            dstMask = mixin(FbStipRight!("dstMask", "1"));
        }
        if (dstUnion)
            mixin(WRITE!("d", FbStippleRRopMask!(READ!("d"), "dstBits",
                                       "fgand", "fgxor", "bgand", "bgxor", "dstUnion"))~`;`);
    }
}
