module fbtrap;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2004 Keith Packard
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

import fb.fbpict_priv;
import include.mipict;

import include.fb;

import include.picturestr;
import dix.damage;
import externs.attrs;
import render.mipict;
import fb.fbpict;

void fbAddTraps(PicturePtr pPicture, INT16 x_off, INT16 y_off, int ntrap, xTrap* traps)
{
    pixman_image_t* image = void;
    int dst_xoff = void, dst_yoff = void;

    if (((image = image_from_pict(pPicture, FALSE, &dst_xoff, &dst_yoff)) is null))
        return;

    assumeNoGC(&pixman_add_traps)(image, cast(short)(x_off + dst_xoff), cast(short)(y_off + dst_yoff),
                     ntrap, cast(pixman_trap_t*) traps);

    free_pixman_pict(pPicture, image);
}

void fbRasterizeTrapezoid(PicturePtr pPicture, xTrapezoid* trap, int x_off, int y_off)
{
    pixman_image_t* image = void;
    int dst_xoff = void, dst_yoff = void;

    if (((image = image_from_pict(pPicture, FALSE, &dst_xoff, &dst_yoff)) is null))
        return;

    assumeNoGC(&pixman_rasterize_trapezoid)(image, cast(pixman_trapezoid_t*) trap,
                               x_off + dst_xoff, y_off + dst_yoff);

    free_pixman_pict(pPicture, image);
}

void fbAddTriangles(PicturePtr pPicture, INT16 x_off, INT16 y_off, int ntri, xTriangle* tris)
{
    pixman_image_t* image = void;
    int dst_xoff = void, dst_yoff = void;

    if (((image = image_from_pict(pPicture, FALSE, &dst_xoff, &dst_yoff)) is null))
        return;

    assumeNoGC(&pixman_add_triangles)(image,
                         dst_xoff + x_off, dst_yoff + y_off,
                         ntri, cast(pixman_triangle_t*) tris);

    free_pixman_pict(pPicture, image);
}

alias CompositeShapesFunc = void function(pixman_op_t op, pixman_image_t* src, pixman_image_t* dst, pixman_format_code_t mask_format, int x_src, int y_src, int x_dst, int y_dst, int n_shapes, const(ubyte)* shapes);

private void fbShapes(CompositeShapesFunc composite, pixman_op_t op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, short xSrc, short ySrc, int nshapes, int shape_size, const(ubyte)* shapes)
{
    pixman_image_t* src = void, dst = void;
    int src_xoff = void, src_yoff = void;
    int dst_xoff = void, dst_yoff = void;

    miCompositeSourceValidate(pSrc);

    src = image_from_pict(pSrc, FALSE, &src_xoff, &src_yoff);
    dst = image_from_pict(pDst, TRUE, &dst_xoff, &dst_yoff);

    if (src && dst) {
        pixman_format_code_t format = void;

        DamageRegionAppend(pDst.pDrawable, pDst.pCompositeClip);

        if (!maskFormat) {
            int i = void;

            if (pDst.polyEdge == PolyEdgeSharp)
                format = PIXMAN_a1;
            else
                format = PIXMAN_a8;

            for (i = 0; i < nshapes; ++i) {
                composite(op, src, dst, format,
                          xSrc + src_xoff,
                          ySrc + src_yoff,
                          dst_xoff, dst_yoff, 1, shapes + i * shape_size);
            }
        }
        else {
            switch (PIXMAN_FORMAT_A(maskFormat.format)) {
            case 1:
                format = PIXMAN_a1;
                break;

            case 4:
                format = PIXMAN_a4;
                break;

            default:
            case 8:
                format = PIXMAN_a8;
                break;
            }

            composite(op, src, dst, format,
                      xSrc + src_xoff,
                      ySrc + src_yoff, dst_xoff, dst_yoff, nshapes, shapes);
        }

        DamageRegionProcessPending(pDst.pDrawable);
    }

    free_pixman_pict(pSrc, src);
    free_pixman_pict(pDst, dst);
}

void fbTrapezoids(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntrap, xTrapezoid* traps)
{
    xSrc -= (traps[0].left.p1.x >> 16);
    ySrc -= (traps[0].left.p1.y >> 16);

    fbShapes(cast(CompositeShapesFunc) &pixman_composite_trapezoids,
             cast(pixman_op_t)op, pSrc, pDst, maskFormat,
             xSrc, ySrc, ntrap, xTrapezoid.sizeof, cast(const(ubyte)*) traps);
}

void fbTriangles(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntris, xTriangle* tris)
{
    xSrc -= (tris[0].p1.x >> 16);
    ySrc -= (tris[0].p1.y >> 16);

    fbShapes(cast(CompositeShapesFunc) &pixman_composite_triangles,
             cast(pixman_op_t)op, pSrc, pDst, maskFormat,
             xSrc, ySrc, ntris, xTriangle.sizeof, cast(const(ubyte)*) tris);
}
