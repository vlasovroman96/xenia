module glamor.glamor_trapezoid;
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
 *    Junyan He <junyan.he@linux.intel.com>
 *
 */

/** @file glamor_trapezoid.c
 *
 * Trapezoid acceleration implementation
 */
import build.dix_config;

import mi.mipict;

import glamor.glamor_priv;
import fb.fbpict;
import externs.X11.extensions.renderproto;
import render.picture;;
import glamor.glamor;
import externs.attrs;
import mirect;
import mitrap;
import mitri;
import fb.fb;
import dix.picture;


/**
 * Creates an appropriate picture for temp mask use.
 */
private PicturePtr glamor_create_mask_picture(ScreenPtr screen, PicturePtr dst, PictFormatPtr pict_format, CARD16 width, CARD16 height)
{
    PixmapPtr pixmap = void;
    PicturePtr picture = void;
    int error = void;

    if (!pict_format) {
        if (dst.polyEdge == PolyEdgeSharp)
            pict_format = PictureMatchFormat(screen, 1, PIXMAN_a1);
        else
            pict_format = PictureMatchFormat(screen, 8, PIXMAN_a8);
        if (!pict_format)
            return null;
    }

    pixmap = glamor_create_pixmap(screen, 0, 0,
                                  pict_format.depth,
                                  GLAMOR_CREATE_PIXMAP_CPU);

    if (!pixmap)
        return null;
    picture = CreatePicture(0, &pixmap.drawable, pict_format,
                            0, null, serverClient, &error);
    glamor_destroy_pixmap(pixmap);
    return picture;
}

/**
 * glamor_trapezoids will generate trapezoid mask accumulating in
 * system memory.
 */
void glamor_trapezoids(CARD8 op, PicturePtr src, PicturePtr dst, PictFormatPtr mask_format, INT16 x_src, INT16 y_src, int ntrap, xTrapezoid* traps)
{
    ScreenPtr screen = dst.pDrawable.pScreen;
    BoxRec bounds = void;
    PicturePtr picture = void;
    INT16 x_dst = void, y_dst = void;
    INT16 x_rel = void, y_rel = void;
    int width = void, height = void, stride = void;
    PixmapPtr pixmap = void;
    pixman_image_t* image = null;

    /* If a mask format wasn't provided, we get to choose, but behavior should
     * be as if there was no temporary mask the traps were accumulated into.
     */
    if (!mask_format) {
        if (dst.polyEdge == PolyEdgeSharp)
            mask_format = PictureMatchFormat(screen, 1, PIXMAN_a1);
        else
            mask_format = PictureMatchFormat(screen, 8, PIXMAN_a8);
        for (; ntrap; ntrap--, traps++)
            glamor_trapezoids(op, src, dst, mask_format, x_src,
                              y_src, 1, traps);
        return;
    }

    miTrapezoidBounds(ntrap, traps, &bounds);

    if (bounds.y1 >= bounds.y2 || bounds.x1 >= bounds.x2)
        return;

    x_dst = cast(short)traps[0].left.p1.x >> 16;
    y_dst = cast(short)traps[0].left.p1.y >> 16;

    width = bounds.x2 - bounds.x1;
    height = bounds.y2 - bounds.y1;
    stride = PixmapBytePad(cast(ushort)width, mask_format.depth);

    picture = glamor_create_mask_picture(screen, dst, mask_format,
                                         cast(ushort)width, cast(ushort)height);
    if (!picture)
        return;

    image = assumeNoGC(&pixman_image_create_bits)(picture.format,
                                     width, height, null, stride);
    if (!image) {
        FreePicture(picture, 0);
        return;
    }

    for (; ntrap; ntrap--, traps++)
        assumeNoGC(&pixman_rasterize_trapezoid)(image,
                                   cast(pixman_trapezoid_t*) traps,
                                   -bounds.x1, -bounds.y1);

    pixmap = glamor_get_drawable_pixmap(picture.pDrawable);

    screen.ModifyPixmapHeader(pixmap, width, height,
                               mask_format.depth,
                               mixin(BitsPerPixel!("mask_format.depth")),
                               PixmapBytePad(width,
                                             mask_format.depth),
                               assumeNoGC(&pixman_image_get_data)(image));

    x_rel = cast(short)(bounds.x1 + x_src - x_dst);
    y_rel = cast(short)(bounds.y1 + y_src - y_dst);

    CompositePicture(op, src, picture, dst,
                     x_rel, y_rel,
                     0, 0,
                     cast(short)bounds.x1, cast(short)bounds.y1,
                     cast(ushort)(bounds.x2 - bounds.x1), cast(short)(bounds.y2 - bounds.y1));

    if (image)
        assumeNoGC(&pixman_image_unref)(image);

    FreePicture(picture, 0);
}
