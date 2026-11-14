module glamor.glamor_font;
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

import core.stdc.stddef;

import externs.X11.fonts.fontstruct; // libxfont2.h missed to include that
import externs.X11.fonts.libxfont2;

import glamor.glamor_priv;
import glamor.glamor_font;
import dix.dixfonts;
import glamor.glamor;
import externs.attrs;
import fb.fbglyph;
import common.bools;
import core.stdc.stdlib;
import core.stdc.string;

private int glamor_font_private_index;
private int glamor_font_screen_count;

struct glamor_font_t{
    Bool        realized;
    CharInfoPtr default_char;
    CARD8       default_row;
    CARD8       default_col;

    GLuint      texture_id;
    GLuint      row_width;
    CARD16      glyph_width_bytes;
    CARD16      glyph_width_pixels;
    CARD16      glyph_height;

} ;

glamor_font_t* glamor_font_get(ScreenPtr screen, FontPtr font)
{
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);

    glamor_font_t* privates = void;
    glamor_font_t* glamor_font = void;
    int overall_width = void, overall_height = void;
    int num_rows = void;
    int num_cols = void;
    int glyph_width_pixels = void;
    int glyph_width_bytes = void;
    int glyph_height = void;
    int row = void, col = void;
    ubyte[2] c = void;
    CharInfoPtr glyph = void;
    c_ulong count = void;

    if (!glamor_glsl_has_ints(glamor_priv))
        return null;

    privates = cast(glamor_font_t*)mixin(FontGetPrivate!("font", "glamor_font_private_index"));
    if (!privates) {
        privates = cast(glamor_font_t*) calloc(glamor_font_screen_count, glamor_font_t.sizeof);
        if (!privates)
            return null;
        assumeNoGC(&xfont2_font_set_private)(font, glamor_font_private_index, privates);
    }

    glamor_font = &privates[screen.myNum];

    if (glamor_font.realized)
        return glamor_font;

    /* Figure out how many glyphs are in the font */
    num_cols = font.info.lastCol - font.info.firstCol + 1;
    num_rows = font.info.lastRow - font.info.firstRow + 1;

    /* Figure out the size of each glyph */
    glyph_width_pixels = font.info.maxbounds.rightSideBearing - font.info.minbounds.leftSideBearing;
    glyph_height = font.info.maxbounds.ascent + font.info.maxbounds.descent;

    glyph_width_bytes = (glyph_width_pixels + 7) >> 3;

    glamor_font.glyph_width_pixels = cast(ushort)glyph_width_pixels;
    glamor_font.glyph_width_bytes = cast(ushort)glyph_width_bytes;
    glamor_font.glyph_height = cast(ushort)glyph_height;

    /*
     * Layout the font two blocks of columns wide.
     * This avoids a problem with some fonts that are too high to fit.
     */
    glamor_font.row_width = glyph_width_bytes * num_cols;

    if (num_rows > 1) {
       overall_width = glamor_font.row_width * 2;
       overall_height = glyph_height * ((num_rows + 1) / 2);
    } else {
       overall_width = glamor_font.row_width;
       overall_height = glyph_height;
    }

    if (overall_width > glamor_priv.max_fbo_size ||
        overall_height > glamor_priv.max_fbo_size) {
        /* fallback if we don't fit inside a texture */
        return null;
    }
    char* bits = cast(char*) calloc(overall_width, overall_height);
    if (!bits)
        return null;

    /* Check whether the font has a default character */
    c[0] = cast(ubyte)(font.info.lastRow + 1);
    c[1] = cast(ubyte)(font.info.lastCol + 1);
    assumeNoGC(font.get_glyphs)(font, 1, c.ptr, TwoD16Bit, &count, &glyph);

    glamor_font.default_char = count ? glyph : null;
    glamor_font.default_row = font.info.defaultCh >> 8;
    glamor_font.default_col = cast(ubyte)font.info.defaultCh;

    glamor_priv = glamor_get_screen_private(screen);
    glamor_make_current(glamor_priv);

    glGenTextures(1, &glamor_font.texture_id);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, glamor_font.texture_id);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    /* Paint all of the glyphs */
    for (row = 0; row < num_rows; row++) {
        for (col = 0; col < num_cols; col++) {
            c[0] = cast(ubyte)(row + font.info.firstRow);
            c[1] = cast(ubyte)(col + font.info.firstCol);

            assumeNoGC(font.get_glyphs)(font, 1, c.ptr, TwoD16Bit, &count, &glyph);

            if (count) {
                char* dst = void;
                char* src = glyph.bits;
                uint y = void;

                dst = bits;
                /* get offset of start of first row */
                dst += (row / 2) * glyph_height * overall_width;
                /* add offset into second row */
                dst += (row & 1) ? glamor_font.row_width : 0;

                dst += col * glyph_width_bytes;
                for (y = 0; y < mixin(GLYPHHEIGHTPIXELS!("glyph")); y++) {
                    memcpy(dst, src, mixin(GLYPHWIDTHBYTES!("glyph")));
                    dst += overall_width;
                    src += cast(ptrdiff_t)mixin(GLYPHWIDTHBYTESPADDED!("glyph"));
                }
            }
        }
    }

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glamor_priv.suppress_gl_out_of_memory_logging = true;
    glTexImage2D(GL_TEXTURE_2D, 0, GL_R8UI, overall_width, overall_height,
                 0, GL_RED_INTEGER, GL_UNSIGNED_BYTE, bits);
    glamor_priv.suppress_gl_out_of_memory_logging = false;
    if (glGetError() == GL_OUT_OF_MEMORY)
        return null;

    free(bits);

    glamor_font.realized = TRUE;

    return glamor_font;
}

private Bool glamor_realize_font(ScreenPtr screen, FontPtr font)
{
    return TRUE;
}

private Bool glamor_unrealize_font(ScreenPtr screen, FontPtr font)
{
    glamor_screen_private* glamor_priv = void;
    glamor_font_t* privates = cast(glamor_font_t*)mixin(FontGetPrivate!("font", "glamor_font_private_index"));
    glamor_font_t* glamor_font = void;
    int s = void;

    if (!privates)
        return TRUE;

    glamor_font = &privates[screen.myNum];

    if (!glamor_font.realized)
        return TRUE;

    /* Unrealize the font, freeing the allocated texture */
    glamor_font.realized = FALSE;

    glamor_priv = glamor_get_screen_private(screen);
    glamor_make_current(glamor_priv);
    glDeleteTextures(1, &glamor_font.texture_id);

    /* Check to see if all of the screens are  done with this font
     * and free the private when that happens
     */
    for (s = 0; s < glamor_font_screen_count; s++)
        if (privates[s].realized)
            return TRUE;

    free(privates);
    assumeNoGC(&xfont2_font_set_private)(font, glamor_font_private_index, null);
    return TRUE;
}

Bool glamor_font_init(ScreenPtr screen)
{
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);

    if (!glamor_glsl_has_ints(glamor_priv))
        return TRUE;

    glamor_font_private_index = assumeNoGC(&xfont2_allocate_font_private_index)();
    if (glamor_font_private_index == -1)
        return FALSE;
    glamor_font_screen_count = 0;

    if (screen.myNum >= glamor_font_screen_count)
        glamor_font_screen_count = screen.myNum + 1;

    screen.RealizeFont = &glamor_realize_font;
    screen.UnrealizeFont = &glamor_unrealize_font;
    return TRUE;
}
