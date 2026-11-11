module glamor.glamor_rects;
@nogc nothrow:
extern(C): __gshared:
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

import os.bug_priv;

import glamor.glamor_priv;
import glamor.glamor_program;
import glamor.glamor_transform;
import glamor.glamor;
import fb.fb;
import common.math;

private const(glamor_facet) glamor_facet_polyfillrect_130 = {
    name: "poly_fill_rect",
    version_: 130,
    source_name: "size",
    vs_vars: "in vec2 primitive;\n"
               ~ "in vec2 size;\n",
    vs_exec: ("       vec2 pos = size * vec2(gl_VertexID&1, (gl_VertexID&2)>>1);\n"
               ~ GLAMOR_POS!("gl_Position", "(primitive.xy + pos)")),
};

private const(glamor_facet) glamor_facet_polyfillrect_120 = {
    name: "poly_fill_rect",
    vs_vars: "attribute vec2 primitive;\n",
    vs_exec: ("        vec2 pos = vec2(0,0);\n"
               ~ GLAMOR_POS!("gl_Position", "primitive.xy")),
};

private Bool glamor_poly_fill_rect_gl(DrawablePtr drawable, GCPtr gc, int nrect, xRectangle* prect)
{
    ScreenPtr screen = drawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    PixmapPtr pixmap = glamor_get_drawable_pixmap(drawable);
    glamor_pixmap_private* pixmap_priv = void;
    glamor_program* prog = void;
    int off_x = void, off_y = void;
    GLshort* v = void;
    char* vbo_offset = void;
    int box_index = void;
    Bool ret = FALSE;
    BoxRec bounds = glamor_no_rendering_bounds();

    pixmap_priv = glamor_get_pixmap_private(pixmap);
    if (!GLAMOR_PIXMAP_PRIV_HAS_FBO(pixmap_priv))
        goto bail;

    glamor_make_current(glamor_priv);

    if (nrect < 100) {
        bounds = glamor_start_rendering_bounds();
        for (int i = 0; i < nrect; i++)
            glamor_bounds_union_rect(&bounds, &prect[i]);
    }

    if (glamor_glsl_has_ints(glamor_priv)) {
        prog = glamor_use_program_fill(drawable, gc,
                                       &glamor_priv.poly_fill_rect_program,
                                       &glamor_facet_polyfillrect_130);

        if (!prog)
            goto bail;

        /* Set up the vertex buffers for the points */

        v = cast(short*)glamor_get_vbo_space(drawable.pScreen, cast(uint)(nrect * xRectangle.sizeof), &vbo_offset);

        glEnableVertexAttribArray(GLAMOR_VERTEX_POS);
        glVertexAttribDivisor(GLAMOR_VERTEX_POS, 1);
        glVertexAttribPointer(GLAMOR_VERTEX_POS, 2, GL_SHORT, GL_FALSE,
                              4 * short.sizeof, vbo_offset);

        glEnableVertexAttribArray(GLAMOR_VERTEX_SOURCE);
        glVertexAttribDivisor(GLAMOR_VERTEX_SOURCE, 1);
        glVertexAttribPointer(GLAMOR_VERTEX_SOURCE, 2, GL_UNSIGNED_SHORT, GL_FALSE,
                              4 * short.sizeof, vbo_offset + 2 * short.sizeof);

        memcpy(v, prect, nrect * xRectangle.sizeof);

        glamor_put_vbo_space(screen);
    } else {
        int n = void;

        prog = glamor_use_program_fill(drawable, gc,
                                       &glamor_priv.poly_fill_rect_program,
                                       &glamor_facet_polyfillrect_120);

        if (!prog)
            goto bail;

        /* Set up the vertex buffers for the points */

        v = cast(short*)glamor_get_vbo_space(drawable.pScreen, cast(uint)(nrect * 8 * short.sizeof), &vbo_offset);

        glEnableVertexAttribArray(GLAMOR_VERTEX_POS);
        glVertexAttribPointer(GLAMOR_VERTEX_POS, 2, GL_SHORT, GL_FALSE,
                              2 * short.sizeof, vbo_offset);

        for (n = 0; n < nrect; n++) {
            v[0] = cast(short)prect.x;                v[1] = cast(short)prect.y;
            v[2] = cast(short)prect.x;                v[3] = cast(short)(prect.y + prect.height);
            v[4] = cast(short)(prect.x + prect.width); v[5] = cast(short)(prect.y + prect.height);
            v[6] = cast(short)(prect.x + prect.width); v[7] = cast(short)prect.y;
            prect++;
            v += 8;
        }

        glamor_put_vbo_space(screen);
    }

    glEnable(GL_SCISSOR_TEST);

    mixin(BUG_RETURN_VAL!("!pixmap_priv", "FALSE"));

    mixin(glamor_pixmap_loop!("pixmap_priv", "box_index", q{
        int nbox = RegionNumRects(gc.pCompositeClip);
        BoxPtr box = RegionRects(gc.pCompositeClip);

        if (!glamor_set_destination_drawable(drawable, box_index, TRUE, FALSE,
                                             prog.matrix_uniform, &off_x, &off_y))
            goto bail;

        while (nbox--) {
            BoxRec scissor = {
                x1: cast(short)max(box.x1, bounds.x1 + drawable.x),
                y1: cast(short)max(box.y1, bounds.y1 + drawable.y),
                x2: cast(short)min(box.x2, bounds.x2 + drawable.x),
                y2: cast(short)min(box.y2, bounds.y2 + drawable.y),
            };

            box++;

            if (scissor.x1 >= scissor.x2 || scissor.y1 >= scissor.y2)
                continue;

            glScissor(scissor.x1 + off_x,
                      scissor.y1 + off_y,
                      scissor.x2 - scissor.x1,
                      scissor.y2 - scissor.y1);
            if (glamor_glsl_has_ints(glamor_priv))
                glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, nrect);
            else {
                glamor_glDrawArrays_GL_QUADS(glamor_priv, nrect);
            }
        }
    }));

    ret = TRUE;

bail:
    glDisable(GL_SCISSOR_TEST);
    if (glamor_glsl_has_ints(glamor_priv)) {
        glVertexAttribDivisor(GLAMOR_VERTEX_SOURCE, 0);
        glDisableVertexAttribArray(GLAMOR_VERTEX_SOURCE);
        glVertexAttribDivisor(GLAMOR_VERTEX_POS, 0);
    }
    glDisableVertexAttribArray(GLAMOR_VERTEX_POS);

    return ret;
}

private void glamor_poly_fill_rect_bail(DrawablePtr drawable, GCPtr gc, int nrect, xRectangle* prect)
{
    // glamor_fallback("to %p (%c)\n", drawable,
                    // glamor_get_drawable_location(drawable));
    if (glamor_prepare_access(drawable, GLAMOR_ACCESS_RW) &&
        glamor_prepare_access_gc(gc)) {
        fbPolyFillRect(drawable, gc, nrect, prect);
    }
    glamor_finish_access_gc(gc);
    glamor_finish_access(drawable);
}

void glamor_poly_fill_rect(DrawablePtr drawable, GCPtr gc, int nrect, xRectangle* prect)
{
    if (glamor_poly_fill_rect_gl(drawable, gc, nrect, prect))
        return;
    glamor_poly_fill_rect_bail(drawable, gc, nrect, prect);
}
