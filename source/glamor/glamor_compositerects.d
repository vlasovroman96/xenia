module glamor.glamor_compositerects;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2009 Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *
 * Authors:
 * 	Zhigang Gong <zhigang.gong@linux.intel.com>
 *
 * 	original author is Chris Wilson at sna.
 *
 */
import build.dix_config;

import include.mipict;

import glamor.glamor_priv;
import dix.damage;
import externs.X11.extensions.renderproto;
import externs.attrs;
import exa.exa_render;
import render.mipict;
import glamor.glamor;
import render.picture;
import mirect;
import mitrap;
import mitri;



/** @file glamor_compositerects.
 *
 * compositeRects acceleration implementation
 */

private short bound(short a, ushort b)
{
    int v = cast(int) a + cast(int) b;

    if (v > MAXSHORT)
        return MAXSHORT;
    return cast(short)v;
}

private Bool _pixman_region_init_clipped_rectangles(pixman_region16_t* region, uint num_rects, xRectangle* rects, int tx, int ty, BoxPtr extents)
{
    pixman_box16_t[64] stack_boxes = void; pixman_box16_t* boxes = stack_boxes.ptr;
    pixman_bool_t ret = void;
    uint i = void, j = void;

    if (num_rects > mixin(ARRAY_SIZE!("stack_boxes"))) {
        boxes = cast(pixman_box16_t*) calloc(num_rects, pixman_box16_t.sizeof);
        if (boxes is null)
            return FALSE;
    }

    for (i = j = 0; i < num_rects; i++) {
        boxes[j].x1 = cast(short)(rects[i].x + tx);
        if (boxes[j].x1 < extents.x1)
            boxes[j].x1 = extents.x1;

        boxes[j].y1 = cast(short)(rects[i].y + ty);
        if (boxes[j].y1 < extents.y1)
            boxes[j].y1 = extents.y1;

        boxes[j].x2 = bound(cast(short)(rects[i].x + tx), rects[i].width);
        if (boxes[j].x2 > extents.x2)
            boxes[j].x2 = extents.x2;

        boxes[j].y2 = bound(cast(short)(rects[i].y + ty), rects[i].height);
        if (boxes[j].y2 > extents.y2)
            boxes[j].y2 = extents.y2;

        if (boxes[j].x2 > boxes[j].x1 && boxes[j].y2 > boxes[j].y1)
            j++;
    }

    ret = FALSE;
    if (j)
        ret = assumeNoGC(&pixman_region_init_rects)(region, boxes, j);

    if (boxes != stack_boxes.ptr)
        free(boxes);

    // //DEBUGF("%s: nrects=%d, region=(%d, %d), (%d, %d) x %d\n",
    //        __FUNCTION__.ptr, num_rects,
    //        region.extents.x1, region.extents.y1,
    //        region.extents.x2, region.extents.y2, j);
    return ret;
}

void glamor_composite_rectangles(CARD8 op, PicturePtr dst, xRenderColor* color, int num_rects, xRectangle* rects)
{
    PixmapPtr pixmap = void;
    glamor_pixmap_private* priv = void;
    pixman_region16_t region = void;
    pixman_box16_t* boxes = void;
    int num_boxes = void;
    PicturePtr source = null;
    Bool need_free_region = FALSE;

    // //DEBUGF("%s(op=%d, %08x x %d [(%d, %d)x(%d, %d) ...])\n",
    //        __FUNCTION__.ptr, op,
    //        (color.alpha >> 8 << 24) |
    //        (color.red >> 8 << 16) |
    //        (color.green >> 8 << 8) |
    //        (color.blue >> 8 << 0),
    //        num_rects, rects[0].x, rects[0].y, rects[0].width, rects[0].height);

    if (!num_rects)
        return;

    if (RegionNil(dst.pCompositeClip)) {
        //DEBUGF("%s: empty clip, skipping\n", __FUNCTION__.ptr);
        return;
    }

    if ((color.red | color.green | color.blue | color.alpha) <= 0x00ff) {
        switch (op) {
        case PictOpOver:
        case PictOpOutReverse:
        case PictOpAdd:
            return;
        case PictOpInReverse:
        case PictOpSrc:
            op = PictOpClear;
            break;
        case PictOpAtopReverse:
            op = PictOpOut;
            break;
        case PictOpXor:
            op = PictOpOverReverse;
            break;
        default: break;}
    }
    if (color.alpha <= 0x00ff) {
        switch (op) {
        case PictOpOver:
        case PictOpOutReverse:
            return;
        case PictOpInReverse:
            op = PictOpClear;
            break;
        case PictOpAtopReverse:
            op = PictOpOut;
            break;
        case PictOpXor:
            op = PictOpOverReverse;
            break;
        default: break;}
    }
    else if (color.alpha >= 0xff00) {
        switch (op) {
        case PictOpOver:
            op = PictOpSrc;
            break;
        case PictOpInReverse:
            return;
        case PictOpOutReverse:
            op = PictOpClear;
            break;
        case PictOpAtopReverse:
            op = PictOpOverReverse;
            break;
        case PictOpXor:
            op = PictOpOut;
            break;
        default: break;}
    }
    // //DEBUGF("%s: converted to op %d\n", __FUNCTION__.ptr, op);

    if (!_pixman_region_init_clipped_rectangles(&region,
                                                num_rects, rects,
                                                dst.pDrawable.x,
                                                dst.pDrawable.y,
                                                &dst.pCompositeClip.extents))
    {
        // //DEBUGF("%s: allocation failed for region\n", __FUNCTION__.ptr);
        return;
    }

    pixmap = glamor_get_drawable_pixmap(dst.pDrawable);
    priv = glamor_get_pixmap_private(pixmap);

    if (!GLAMOR_PIXMAP_PRIV_HAS_FBO(priv))
        goto fallback;
    if (dst.alphaMap) {
        // //DEBUGF("%s: fallback, dst has an alpha-map\n", __FUNCTION__.ptr);
        goto fallback;
    }

    need_free_region = TRUE;

    // //DEBUGF("%s: drawable extents (%d, %d),(%d, %d) x %d\n",
        //    __FUNCTION__.ptr,
        //    RegionExtents(&region).x1, RegionExtents(&region).y1,
        //    RegionExtents(&region).x2, RegionExtents(&region).y2,
        //    RegionNumRects(&region));

    if (dst.pCompositeClip.data &&
        (!assumeNoGC(&pixman_region_intersect)(&region, &region, dst.pCompositeClip) ||
         RegionNil(&region))) {
        //DEBUGF("%s: zero-intersection between rectangles and clip\n",
            //    __FUNCTION__.ptr);
        assumeNoGC(&pixman_region_fini)(&region);
        return;
    }

    //DEBUGF("%s: clipped extents (%d, %d),(%d, %d) x %d\n",
        //    __FUNCTION__.ptr,
        //    RegionExtents(&region).x1, RegionExtents(&region).y1,
        //    RegionExtents(&region).x2, RegionExtents(&region).y2,
        //    RegionNumRects(&region));

    boxes = assumeNoGC(&pixman_region_rectangles)(&region, &num_boxes);
    if (op == PictOpSrc || op == PictOpClear) {
        CARD32 pixel = void;

        assumeNoGC(&pixman_region_translate)(&region, -dst.pDrawable.x, -dst.pDrawable.y);

        //DEBUGF("%s: drawable extents (%d, %d),(%d, %d)\n",
            //    __FUNCTION__.ptr, dst_x, dst_y,
            //    RegionExtents(&region).x1, RegionExtents(&region).y1,
            //    RegionExtents(&region).x2, RegionExtents(&region).y2);

        if (op == PictOpClear)
            pixel = 0;
        else
            miRenderColorToPixel(dst.pFormat, color, &pixel);
        glamor_solid_boxes(dst.pDrawable, boxes, num_boxes, pixel);

        goto done;
    }
    else {
        if (_X_LIKELY(glamor_pixmap_priv_is_small(priv))) {
            int error = void;

            source = CreateSolidPicture(0, color, &error);
            if (!source)
                goto done;
            if (glamor_composite_clipped_region(op, source,
                                                null, dst,
                                                null, null, pixmap,
                                                &region, 0, 0, 0, 0, 0, 0))
                goto done;
        }
    }
 fallback:
    miCompositeRects(op, dst, color, num_rects, rects);
 done:
    /* XXX xserver-1.8: CompositeRects is not tracked by Damage, so we must
     * manually append the damaged regions ourselves.
     */
    DamageRegionAppend(&pixmap.drawable, &region);
    DamageRegionProcessPending(&pixmap.drawable);

    if (need_free_region)
        assumeNoGC(&pixman_region_fini)(&region);
    if (source)
        FreePicture(source, 0);
    return;
}
