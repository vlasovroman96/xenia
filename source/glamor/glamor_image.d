module glamor.glamor_image;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2014 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import glamor.glamor_priv;
import glamor.glamor_transfer;
import glamor.glamor_transform;
import glamor.glamor;
import fb.fbutil;
import glamor.glamor_pixmap;
import fb.fb;
import common.bools;

/*
 * PutImage. Only does ZPixmap right now as other formats are quite a bit harder
 */

private Bool glamor_put_image_gl(DrawablePtr drawable, GCPtr gc, int depth, int x, int y, int w, int h, int leftPad, int format, char* bits)
{
    ScreenPtr screen = drawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    PixmapPtr pixmap = glamor_get_drawable_pixmap(drawable);
    glamor_pixmap_private* pixmap_priv = void;
    uint byte_stride = PixmapBytePad(w, drawable.depth);
    RegionRec region = void;
    BoxRec box = void;
    int off_x = void, off_y = void;

    pixmap_priv = glamor_get_pixmap_private(pixmap);

    if (!GLAMOR_PIXMAP_PRIV_HAS_FBO(pixmap_priv))
        return FALSE;

    if (gc.alu != GXcopy)
        goto bail;

    if (!glamor_pm_is_solid(gc.depth, gc.planemask))
        goto bail;

    if (format == XYPixmap && drawable.depth == 1 && leftPad == 0)
        format = ZPixmap;

    if (format != ZPixmap)
        goto bail;

    x += cast(short)drawable.x;
    y += cast(short)drawable.y;
    box.x1 = cast(short)(x);
    box.y1 = cast(short)(y);
    box.x2 = cast(short)(box.x1 + w);
    box.y2 = cast(short)(box.y1 + h);
    RegionInit(&region, &box, 1);
    RegionIntersect(&region, &region, gc.pCompositeClip);

    glamor_get_drawable_deltas(drawable, pixmap, &off_x, &off_y);
    if (off_x || off_y) {
        x += cast(short)off_x;
        y += cast(short)off_y;
        RegionTranslate(&region, off_x, off_y);
    }

    glamor_make_current(glamor_priv);

    glamor_upload_region(drawable, &region, x, y, cast(ubyte*) bits, byte_stride);

    RegionUninit(&region);
    return TRUE;
bail:
    return FALSE;
}

private void glamor_put_image_bail(DrawablePtr drawable, GCPtr gc, int depth, int x, int y, int w, int h, int leftPad, int format, char* bits)
{
    if (glamor_prepare_access_box(drawable, GLAMOR_ACCESS_RW, x, y, w, h))
        fbPutImage(drawable, gc, depth, x, y, w, h, leftPad, format, bits);
    glamor_finish_access(drawable);
}

void glamor_put_image(DrawablePtr drawable, GCPtr gc, int depth, int x, int y, int w, int h, int leftPad, int format, char* bits)
{
    if (glamor_put_image_gl(drawable, gc, depth, x, y, w, h, leftPad, format, bits))
        return;
    glamor_put_image_bail(drawable, gc, depth, x, y, w, h, leftPad, format, bits);
}

private Bool glamor_get_image_gl(DrawablePtr drawable, int x, int y, int w, int h, uint format, c_ulong plane_mask, char* d)
{
    PixmapPtr pixmap = glamor_get_drawable_pixmap(drawable);
    glamor_pixmap_private* pixmap_priv = void;
    uint byte_stride = PixmapBytePad(w, drawable.depth);
    BoxRec box = void;
    int off_x = void, off_y = void;

    pixmap_priv = glamor_get_pixmap_private(pixmap);
    if (!GLAMOR_PIXMAP_PRIV_HAS_FBO(pixmap_priv))
        goto bail;

    if (format != ZPixmap)
        goto bail;

    glamor_get_drawable_deltas(drawable, pixmap, &off_x, &off_y);
    box.x1 = cast(short)(x);
    box.x2 = cast(short)(x + w);
    box.y1 = cast(short)(y);
    box.y2 = cast(short)(y + h);
    glamor_download_boxes(drawable, &box, 1,
                          drawable.x + off_x, drawable.y + off_y,
                          -x, -y,
                          cast(ubyte*) d, byte_stride);

    if (!glamor_pm_is_solid(glamor_drawable_effective_depth(drawable), plane_mask)) {
        FbStip pm = fbReplicatePixel(cast(uint)plane_mask, drawable.bitsPerPixel);
        FbStip* dst = cast(FbStip*) (cast(void*)d);
        uint dstStride = byte_stride / FbStip.sizeof;

        for (int i = 0; i < dstStride * h; i++)
            dst[i] &= pm;
    }

    return TRUE;
bail:
    return FALSE;
}

private void glamor_get_image_bail(DrawablePtr drawable, int x, int y, int w, int h, uint format, c_ulong plane_mask, char* d)
{
    if (glamor_prepare_access_box(drawable, GLAMOR_ACCESS_RO, x, y, w, h))
        fbGetImage(drawable, x, y, w, h, format, plane_mask, d);
    glamor_finish_access(drawable);
}

void glamor_get_image(DrawablePtr drawable, int x, int y, int w, int h, uint format, c_ulong plane_mask, char* d)
{
    if (glamor_get_image_gl(drawable, x, y, w, h, format, plane_mask, d))
        return;
    glamor_get_image_bail(drawable, x, y, w, h, format, plane_mask, d);
}
