module shrotate.c;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2001 Keith Packard, member of The XFree86 Project, Inc.
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
 * These indicate which way the source (shadow) is scanned when
 * walking the screen in a particular direction
 */

enum LEFT_TO_RIGHT =	1;
enum RIGHT_TO_LEFT =	-1;
enum TOP_TO_BOTTOM =	2;
enum BOTTOM_TO_TOP =	-2;

void shadowUpdateRotatePacked(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    RegionPtr damage = DamageRegion(pBuf.pDamage);
    PixmapPtr pShadow = pBuf.pPixmap;
    int nbox = RegionNumRects(damage);
    BoxPtr pbox = RegionRects(damage);
    FbBits* shaBits = void;
    FbStride shaStride = void;
    int shaBpp = void;
     int shaXoff = void, shaYoff = void;
    int box_x1 = void, box_x2 = void, box_y1 = void, box_y2 = void;
    int sha_x1 = 0, sha_y1 = 0;
    int scr_x1 = 0, scr_x2 = 0, scr_y1 = 0, scr_y2 = 0, scr_w = void, scr_h = void;
    int scr_x = void, scr_y = void;
    int w = void;
    int pixelsPerBits = void;
    int pixelsMask = void;
    FbStride shaStepOverY = 0, shaStepDownY = 0;
    FbStride shaStepOverX = 0, shaStepDownX = 0;
    FbBits* shaLine = void, sha = void;
    int shaHeight = pShadow.drawable.height;
    int shaWidth = pShadow.drawable.width;
    FbBits shaMask = void;
    int shaFirstShift = void, shaShift = void;
    int o_x_dir = void;
    int o_y_dir = void;
    int x_dir = void;
    int y_dir = void;

    mixin(fbGetDrawable!("(&pShadow.drawable)", "shaBits", "shaStride", "shaBpp", "shaXoff",
                  "shaYoff"));
    pixelsPerBits = (((FbBits).sizeof * 8)) / shaBpp;
    pixelsMask = ~(pixelsPerBits - 1);
    shaMask = mixin(FbBitsMask!("FB_UNIT - shaBpp", "shaBpp"));
    /*
     * Compute rotation related constants to walk the shadow
     */
    o_x_dir = LEFT_TO_RIGHT;
    o_y_dir = TOP_TO_BOTTOM;
    if (pBuf.randr & SHADOW_REFLECT_X)
        o_x_dir = -o_x_dir;
    if (pBuf.randr & SHADOW_REFLECT_Y)
        o_y_dir = -o_y_dir;
    switch (pBuf.randr & (SHADOW_ROTATE_ALL)) {
    case SHADOW_ROTATE_0:      /* upper left shadow -> upper left screen */
    default:
        x_dir = o_x_dir;
        y_dir = o_y_dir;
        break;
    case SHADOW_ROTATE_90:     /* upper right shadow -> upper left screen */
        x_dir = o_y_dir;
        y_dir = -o_x_dir;
        break;
    case SHADOW_ROTATE_180:    /* lower right shadow -> upper left screen */
        x_dir = -o_x_dir;
        y_dir = -o_y_dir;
        break;
    case SHADOW_ROTATE_270:    /* lower left shadow -> upper left screen */
        x_dir = -o_y_dir;
        y_dir = o_x_dir;
        break;
    }
    switch (x_dir) {
    case LEFT_TO_RIGHT:
        shaStepOverX = shaBpp;
        shaStepOverY = 0;
        break;
    case TOP_TO_BOTTOM:
        shaStepOverX = 0;
        shaStepOverY = shaStride;
        break;
    case RIGHT_TO_LEFT:
        shaStepOverX = -shaBpp;
        shaStepOverY = 0;
        break;
    case BOTTOM_TO_TOP:
        shaStepOverX = 0;
        shaStepOverY = -shaStride;
        break;
    default: break;}
    switch (y_dir) {
    case TOP_TO_BOTTOM:
        shaStepDownX = 0;
        shaStepDownY = shaStride;
        break;
    case RIGHT_TO_LEFT:
        shaStepDownX = -shaBpp;
        shaStepDownY = 0;
        break;
    case BOTTOM_TO_TOP:
        shaStepDownX = 0;
        shaStepDownY = -shaStride;
        break;
    case LEFT_TO_RIGHT:
        shaStepDownX = shaBpp;
        shaStepDownY = 0;
        break;
    default: break;}

    while (nbox--) {
        box_x1 = pbox.x1;
        box_y1 = pbox.y1;
        box_x2 = pbox.x2;
        box_y2 = pbox.y2;
        pbox++;

        /*
         * Compute screen and shadow locations for this box
         */
        switch (x_dir) {
        case LEFT_TO_RIGHT:
            scr_x1 = box_x1 & pixelsMask;
            scr_x2 = (box_x2 + pixelsPerBits - 1) & pixelsMask;

            sha_x1 = scr_x1;
            break;
        case TOP_TO_BOTTOM:
            scr_x1 = box_y1 & pixelsMask;
            scr_x2 = (box_y2 + pixelsPerBits - 1) & pixelsMask;

            sha_y1 = scr_x1;
            break;
        case RIGHT_TO_LEFT:
            scr_x1 = (shaWidth - box_x2) & pixelsMask;
            scr_x2 = (shaWidth - box_x1 + pixelsPerBits - 1) & pixelsMask;

            sha_x1 = (shaWidth - scr_x1 - 1);
            break;
        case BOTTOM_TO_TOP:
            scr_x1 = (shaHeight - box_y2) & pixelsMask;
            scr_x2 = (shaHeight - box_y1 + pixelsPerBits - 1) & pixelsMask;

            sha_y1 = (shaHeight - scr_x1 - 1);
            break;
        default: break;}
        switch (y_dir) {
        case TOP_TO_BOTTOM:
            scr_y1 = box_y1;
            scr_y2 = box_y2;

            sha_y1 = scr_y1;
            break;
        case RIGHT_TO_LEFT:
            scr_y1 = (shaWidth - box_x2);
            scr_y2 = (shaWidth - box_x1);

            sha_x1 = box_x2 - 1;
            break;
        case BOTTOM_TO_TOP:
            scr_y1 = shaHeight - box_y2;
            scr_y2 = shaHeight - box_y1;

            sha_y1 = box_y2 - 1;
            break;
        case LEFT_TO_RIGHT:
            scr_y1 = box_x1;
            scr_y2 = box_x2;

            sha_x1 = box_x1;
            break;
        default: break;}
        scr_w = ((scr_x2 - scr_x1) * shaBpp) >> FB_SHIFT;
        scr_h = scr_y2 - scr_y1;
        scr_y = scr_y1;

        /* shift amount for first pixel on screen */
        shaFirstShift = FB_UNIT - ((sha_x1 * shaBpp) & FB_MASK) - shaBpp;

        /* pointer to shadow data first placed on screen */
        shaLine = (shaBits +
                   sha_y1 * shaStride + ((sha_x1 * shaBpp) >> FB_SHIFT));

        /*
         * Copy the bits, always write across the physical frame buffer
         * to take advantage of write combining.
         */
        while (scr_h--) {
            int p = void;
            FbBits bits = void;
            FbBits* win = void;
            int i = void;
            CARD32 winSize = void;

            sha = shaLine;
            shaShift = shaFirstShift;
            w = scr_w;
            scr_x = scr_x1 * shaBpp >> FB_SHIFT;

            while (w) {
                /*
                 * Map some of this line
                 */
                win = cast(FbBits*) (*pBuf.window) (pScreen,
                                                  scr_y,
                                                  scr_x << 2,
                                                  SHADOW_WINDOW_WRITE,
                                                  &winSize, pBuf.closure);
                i = cast(int)(winSize >> 2);
                if (i > w)
                    i = w;
                w -= i;
                scr_x += i;
                /*
                 * Copy the portion of the line mapped
                 */
                while (i--) {
                    bits = 0;
                    p = pixelsPerBits;
                    /*
                     * Build one word of output from multiple inputs
                     *
                     * Note that for 90/270 rotations, this will walk
                     * down the shadow hitting each scanline once.
                     * This is probably not very efficient.
                     */
                    while (p--) {
                        bits = mixin(FbScrLeft!("bits", "shaBpp"));
                        bits |= mixin(FbScrRight!("*sha", "shaShift")) & shaMask;

                        shaShift -= shaStepOverX;
                        if (shaShift >= FB_UNIT) {
                            shaShift -= FB_UNIT;
                            sha--;
                        }
                        else if (shaShift < 0) {
                            shaShift += FB_UNIT;
                            sha++;
                        }
                        sha += shaStepOverY;
                    }
                    *win++ = bits;
                }
            }
            scr_y++;
            shaFirstShift -= shaStepDownX;
            if (shaFirstShift >= FB_UNIT) {
                shaFirstShift -= FB_UNIT;
                shaLine--;
            }
            else if (shaFirstShift < 0) {
                shaFirstShift += FB_UNIT;
                shaLine++;
            }
            shaLine += shaStepDownY;
        }
    }
}
