module fbblt;
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

import core.stdc.string;
import fb.fb;
import fb.fbutil;
import build.xorg_config;
import fb.fbrop;

static if (FB_ACCESS_WRAPPER) {

enum string MEMCPY_WRAPPED(string dst, string src, string size) = `{                       
        size_t _i = void;                                                    
        CARD8* _dst = cast(CARD8*)(` ~ dst ~ `), _src = cast(CARD8*)(` ~ src ~ `);           
        for(_i = 0; _i < ` ~ size ~ `; _i++) {                                
            WRITE(_dst +_i, READ(_src + _i));                         
        }
    }                                                             
`;

enum string MEMSET_WRAPPED(string dst, string val, string size) = `do {                       
    size_t _i = void;                                                    
    CARD8* _dst = cast(CARD8*)(` ~ dst ~ `);                                  
    for(_i = 0; _i < ` ~ size ~ `; _i++) {                                
        WRITE(_dst +_i, (` ~ val ~ `));                                   
    }                                                             
} while(0)`;

} else {

enum string MEMCPY_WRAPPED(string dst, string src, string size) = `memcpy((` ~ dst ~ `), (` ~ src ~ `), (` ~ size ~ `));`;
enum string MEMSET_WRAPPED(string dst, string val, string size) = `memset((` ~ dst ~ `), (` ~ val ~ `), (` ~ size ~ `));`;

} /* FB_ACCESS_WRAPPER */

enum string FbStipStrideToBitsStride(string s) = `(((` ~ s ~ `) >> (FB_SHIFT - FB_STIP_SHIFT)))`;

enum string InitializeShifts(string sx,string dx,string ls,string rs) = `{ 
    if (` ~ sx ~ ` != ` ~ dx ~ `) { 
	if (` ~ sx ~ ` > ` ~ dx ~ `) { 
	    ` ~ ls ~ ` = ` ~ sx ~ ` - ` ~ dx ~ `; 
	    ` ~ rs ~ ` = FB_UNIT - ` ~ ls ~ `; 
	} else { 
	    ` ~ rs ~ ` = ` ~ dx ~ ` - ` ~ sx ~ `; 
	    ` ~ ls ~ ` = FB_UNIT - ` ~ rs ~ `; 
	} 
    } 
}`;

void fbBlt(FbBits* srcLine, FbStride srcStride, int srcX, FbBits* dstLine, FbStride dstStride, int dstX, int width, int height, int alu, FbBits pm, int bpp, Bool reverse, Bool upsidedown)
{
    FbBits* src = void, dst = void;
    int leftShift = void, rightShift = void;
    FbBits startmask = void, endmask = void;
    FbBits bits = void, bits1 = void;
    int n = void, nmiddle = void;
    Bool destInvarient = void;
    int startbyte = void, endbyte = void;

    mixin(FbDeclareMergeRop!());

    if (alu == GXcopy && pm == FB_ALLONES &&
        !(srcX & 7) && !(dstX & 7) && !(width & 7))
    {
        CARD8* src_byte = cast(CARD8*) srcLine + (srcX >> 3);
        CARD8* dst_byte = cast(CARD8*) dstLine + (dstX >> 3);
        FbStride src_byte_stride = srcStride << (FB_SHIFT - 3);
        FbStride dst_byte_stride = dstStride << (FB_SHIFT - 3);
        int width_byte = (width >> 3);

        /* Make sure there's no overlap; we can't use memcpy in that
         * case as it's not well defined, so fall through to the
         * general code
         */
        if (src_byte + width_byte <= dst_byte ||
            dst_byte + width_byte <= src_byte)
        {
            int i = void;

            if (!upsidedown)
                for (i = 0; i < height; i++)
                    mixin(MEMCPY_WRAPPED!(`dst_byte + i * dst_byte_stride`,
                                   `src_byte + i * src_byte_stride`,
                                   `width_byte`));
            else
                for (i = height - 1; i >= 0; i--)
                    mixin(MEMCPY_WRAPPED!(`dst_byte + i * dst_byte_stride`,
                                   `src_byte + i * src_byte_stride`,
                                   `width_byte`));

            return;
        }
    }

    mixin(FbInitializeMergeRop!("alu", "pm"));
    destInvarient = mixin(FbDestInvarientMergeRop!());
    if (upsidedown) {
        srcLine += (height - 1) * (srcStride);
        dstLine += (height - 1) * (dstStride);
        srcStride = -srcStride;
        dstStride = -dstStride;
    }
    mixin(FbMaskBitsBytes!("dstX", "width", "destInvarient", "startmask", "startbyte",
                    "nmiddle", "endmask", "endbyte"));
    if (reverse) {
        srcLine += ((srcX + width - 1) >> FB_SHIFT) + 1;
        dstLine += ((dstX + width - 1) >> FB_SHIFT) + 1;
        srcX = (srcX + width - 1) & FB_MASK;
        dstX = (dstX + width - 1) & FB_MASK;
    }
    else {
        srcLine += srcX >> FB_SHIFT;
        dstLine += dstX >> FB_SHIFT;
        srcX &= FB_MASK;
        dstX &= FB_MASK;
    }
    if (srcX == dstX) {
        while (height--) {
            src = srcLine;
            srcLine += srcStride;
            dst = dstLine;
            dstLine += dstStride;
            if (reverse) {
                if (endmask) {
                    bits = mixin(READ!("--src"));
                    --dst;
                    mixin(FbDoRightMaskByteMergeRop!("dst", "bits", "endbyte", "endmask"));
                }
                n = nmiddle;
                if (destInvarient) {
                    while (n--)
                        mixin(WRITE!("--dst", FbDoDestInvarientMergeRop!(READ!("--src")))~`;`);
                }
                else {
                    while (n--) {
                        bits = mixin(READ!("--src"));
                        --dst;
                        mixin(WRITE!("dst", FbDoMergeRop!("bits", READ!("dst")))~';');
                    }
                }
                if (startmask) {
                    bits = mixin(READ!("--src"));
                    --dst;
                    pragma(msg, "FbBits.sizeof = ", FbBits.sizeof);
pragma(msg, "FB_SHIFT = ", FB_SHIFT);
                    mixin(FbDoLeftMaskByteMergeRop!("dst", "bits", "startbyte", "startmask"));
                }
            }
            else {
                if (startmask) {
                    bits = mixin(READ!("src++"));
                    pragma(msg, "FbBits.sizeof = ", FbBits.sizeof);
pragma(msg, "FB_SHIFT = ", FB_SHIFT);
                    mixin(FbDoLeftMaskByteMergeRop!("dst", "bits", "startbyte", "startmask"));
                    dst++;
                }
                n = nmiddle;
                if (destInvarient) {
version (none) {
                    // /*
                    //  * This provides some speedup on screen->screen blts
                    //  * over the PCI bus, usually about 10%.  But fb
                    //  * isn't usually used for this operation...
                    //  */
                    // if (_ca2 + 1 == 0 && _cx2 == 0) {
                    //     FbBits t1 = void, t2 = void, t3 = void, t4 = void;

                    //     while (n >= 4) {
                    //         t1 = *src++;
                    //         t2 = *src++;
                    //         t3 = *src++;
                    //         t4 = *src++;
                    //         *dst++ = t1;
                    //         *dst++ = t2;
                    //         *dst++ = t3;
                    //         *dst++ = t4;
                    //         n -= 4;
                    //     }
                    // }
}
                    while (n--)
                        mixin(WRITE!("dst++", FbDoDestInvarientMergeRop!(READ!("src++")))~`;`);
                }
                else {
                    while (n--) {
                        bits = mixin(READ!("src++"));
                        mixin(WRITE!("dst", FbDoMergeRop!("bits", READ!("dst")))~`;`);
                        dst++;
                    }
                }
                if (endmask) {
                    bits = mixin(READ!("src"));
                    mixin(FbDoRightMaskByteMergeRop!("dst", "bits", "endbyte", "endmask"));
                }
            }
        }
    }
    else {
        if (srcX > dstX) {
            leftShift = srcX - dstX;
            rightShift = FB_UNIT - leftShift;
        }
        else {
            rightShift = dstX - srcX;
            leftShift = FB_UNIT - rightShift;
        }
        while (height--) {
            src = srcLine;
            srcLine += srcStride;
            dst = dstLine;
            dstLine += dstStride;

            bits1 = 0;
            if (reverse) {
                if (srcX < dstX)
                    bits1 = mixin(READ!("--src"));
                if (endmask) {
                    bits = mixin(FbScrRight!("bits1", "rightShift"));
                    if (mixin(FbScrRight!("endmask", "leftShift"))) {
                        bits1 = mixin(READ!("--src"));
                        bits |= mixin(FbScrLeft!("bits1", "leftShift"));
                    }
                    --dst;
                    mixin(FbDoRightMaskByteMergeRop!("dst", "bits", "endbyte", "endmask"));
                }
                n = nmiddle;
                if (destInvarient) {
                    while (n--) {
                        bits = mixin(FbScrRight!("bits1", "rightShift"));
                        bits1 = mixin(READ!("--src"));
                        bits |= mixin(FbScrLeft!("bits1", "leftShift"));
                        --dst;
                        mixin(WRITE!("dst", FbDoDestInvarientMergeRop!("bits"))~`;`);
                    }
                }
                else {
                    while (n--) {
                        bits = mixin(FbScrRight!("bits1", "rightShift"));
                        bits1 = mixin(READ!("--src"));
                        bits |= mixin(FbScrLeft!("bits1", "leftShift"));
                        --dst;
                        mixin(WRITE!("dst", FbDoMergeRop!("bits", READ!("dst")))~`;`);
                    }
                }
                if (startmask) {
                    bits = mixin(FbScrRight!("bits1", "rightShift"));
                    if (mixin(FbScrRight!("startmask", "leftShift"))) {
                        bits1 = mixin(READ!("--src"));
                        bits |= mixin(FbScrLeft!("bits1", "leftShift"));
                    }
                    --dst;
                    mixin(FbDoLeftMaskByteMergeRop!("dst", "bits", "startbyte", "startmask"));
                }
            }
            else {
                if (srcX > dstX)
                    bits1 = mixin(READ!("src++"));
                if (startmask) {
                    bits = mixin(FbScrLeft!("bits1", "leftShift"));
                    if (mixin(FbScrLeft!("startmask", "rightShift"))) {
                        bits1 = mixin(READ!("src++"));
                        bits |= mixin(FbScrRight!("bits1", "rightShift"));
                    }
                    mixin(FbDoLeftMaskByteMergeRop!("dst", "bits", "startbyte", "startmask"));
                    dst++;
                }
                n = nmiddle;
                if (destInvarient) {
                    while (n--) {
                        bits = mixin(FbScrLeft!("bits1", "leftShift"));
                        bits1 = mixin(READ!("src++"));
                        bits |= mixin(FbScrRight!("bits1", "rightShift"));
                        mixin(WRITE!("dst", FbDoDestInvarientMergeRop!("bits"))~`;`);
                        dst++;
                    }
                }
                else {
                    while (n--) {
                        bits = mixin(FbScrLeft!("bits1", "leftShift"));
                        bits1 = mixin(READ!("src++"));
                        bits |= mixin(FbScrRight!("bits1", "rightShift"));
                        mixin(WRITE!("dst", FbDoMergeRop!("bits", READ!("dst")))~`;`);
                        dst++;
                    }
                }
                if (endmask) {
                    bits = mixin(FbScrLeft!("bits1", "leftShift"));
                    if (mixin(FbScrLeft!("endmask", "rightShift"))) {
                        bits1 = mixin(READ!("src"));
                        bits |= mixin(FbScrRight!("bits1", "rightShift"));
                    }
                    mixin(FbDoRightMaskByteMergeRop!("dst", "bits", "endbyte", "endmask"));
                }
            }
        }
    }
}

void fbBltStip(FbStip* src, FbStride srcStride, int srcX, FbStip* dst, FbStride dstStride, int dstX, int width, int height, int alu, FbBits pm, int bpp)
{
    fbBlt(cast(FbBits*) src, mixin(FbStipStrideToBitsStride!(`srcStride`)), srcX,
          cast(FbBits*) dst, mixin(FbStipStrideToBitsStride!(`dstStride`)), dstX,
          width, height, alu, pm, bpp, False, False);
}
