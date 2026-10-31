module glx.xfont;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008)
 * Copyright (C) 1991-2000 Silicon Graphics, Inc. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice including the dates of first publication and
 * either this permission notice or a reference to
 * http://oss.sgi.com/projects/FreeB/
 * shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * SILICON GRAPHICS, INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of Silicon Graphics, Inc.
 * shall not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization from
 * Silicon Graphics, Inc.
 */

import build.dix_config;

import dix.dix_priv;

import glx.glxserver;
import glx.glxutil;
import glx.unpack;
import glx.indirect_dispatch;
// import externs.gl;
import include.pixmapstr;
import include.windowstr;
import dix.dixfonts;
 import Xext.glx.fix;
import fb.fbglyph;
import externs.attrs;
import glx.glxext;
import Xext.xf86bigfont;


/*
** Make a single GL bitmap from a single X glyph
*/
private int __glXMakeBitmapFromGlyph(FontPtr font, CharInfoPtr pci)
{
    int i = void, j = void;
    int widthPadded = void;            /* width of glyph in bytes, as padded by X */
    int allocBytes = void;             /* bytes to allocate to store bitmap */
    int w = void;                      /* width of glyph in bits */
    int h = void;                      /* height of glyph */
    ubyte* pglyph = void;
    ubyte* p = void;
    ubyte* allocbuf = void;

enum __GL_CHAR_BUF_SIZE = 2048;
    ubyte[__GL_CHAR_BUF_SIZE] buf = void;

    w = mixin(GLYPHWIDTHPIXELS!("pci"));
    h = mixin(GLYPHHEIGHTPIXELS!("pci"));
    widthPadded = mixin(GLYPHWIDTHBYTESPADDED!("pci"));

    /*
     ** Use the local buf if possible, otherwise calloc.
     */
    allocBytes = widthPadded * h;
    if (allocBytes <= __GL_CHAR_BUF_SIZE) {
        p = buf.ptr;
        allocbuf = null;
    }
    else {
        p = cast(ubyte*) calloc(1, allocBytes);
        if (!p)
            return BadAlloc;
        allocbuf = p;
    }

    /*
     ** We have to reverse the picture, top to bottom
     */

    pglyph = mixin(FONTGLYPHBITS!(FONTGLYPHS!("font"), "pci")) + (h - 1) * widthPadded;
    for (j = 0; j < h; j++) {
        for (i = 0; i < widthPadded; i++) {
            p[i] = pglyph[i];
        }
        pglyph -= widthPadded;
        p += widthPadded;
    }
    glBitmap(w, h, -pci.metrics.leftSideBearing, pci.metrics.descent,
             pci.metrics.characterWidth, 0, allocbuf ? allocbuf : buf.ptr);

    free(allocbuf);
    return Success;
}

/*
** Create a GL bitmap for each character in the X font.  The bitmap is stored
** in a display list.
*/

private int MakeBitmapsFromFont(FontPtr pFont, int first, int count, int list_base)
{
    c_ulong i = void, nglyphs = void;
    CARD8[2] chs = void;               /* the font index we are going after */
    CharInfoPtr pci = void;
    int rv = void;                     /* return value */
    int encoding = (mixin(FONTLASTROW!("pFont")) == 0) ? Linear16Bit : TwoD16Bit;

    glPixelStorei(GL_UNPACK_SWAP_BYTES, FALSE);
    glPixelStorei(GL_UNPACK_LSB_FIRST, BITMAP_BIT_ORDER == LSBFirst);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, GLYPHPADBYTES);
    for (i = 0; i < count; i++) {
        chs[0] = cast(ubyte)((first + i) >> 8);      /* high byte is first byte */
        chs[1] = cast(ubyte)(first + i);

        assumeNoGC(pFont.get_glyphs) (pFont, 1, chs.ptr, cast(FontEncoding) encoding,
                              &nglyphs, &pci);

        /*
         ** Define a display list containing just a glBitmap() call.
         */
        glNewList(cast(uint)(list_base + i), GL_COMPILE);
        if (nglyphs) {
            rv = __glXMakeBitmapFromGlyph(pFont, pci);
            if (rv) {
                return rv;
            }
        }
        glEndList();
    }
    return Success;
}

/************************************************************************/

int __glXDisp_UseXFont(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXUseXFontReq* req = void;
    FontPtr pFont = void;
    GLuint currentListIndex = void;
    __GLXcontext* cx = void;
    int error = void;

    req = cast(xGLXUseXFontReq*) pc;
    cx = __glXForceCurrent(cl, req.contextTag, &error);
    if (!cx) {
        return error;
    }

    glGetIntegerv(GL_LIST_INDEX, cast(GLint*) &currentListIndex);
    if (currentListIndex != 0) {
        /*
         ** A display list is currently being made.  It is an error
         ** to try to make a font during another lists construction.
         */
        client.errorValue = cast(uint)cx.id;
        return __glXError(GLXBadContextState);
    }

    /*
     ** Font can actually be either the ID of a font or the ID of a GC
     ** containing a font.
     */

    error = dixLookupFontable(&pFont, req.font, client, DixReadAccess);
    if (error != Success)
        return error;

    return MakeBitmapsFromFont(pFont, req.first, req.count, req.listBase);
}
