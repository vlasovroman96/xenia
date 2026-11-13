module fbgetsp;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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
import fb.fballpriv;

void fbGetSpans(DrawablePtr pDrawable, int wMax, xPoint* ppt, int* pwidth, int nspans, char* pchardstStart)
{
    FbBits* src = void, dst = void;
    FbStride srcStride = void;
    int srcBpp = void;
    int srcXoff = void, srcYoff = void;
    int xoff = void;

    /*
     * XFree86 DDX empties the root borderClip when the VT is
     * switched away; this checks for that case
     */
    if (!mixin(fbDrawableEnabled!("pDrawable")))
        return;

    mixin(fbGetDrawable!("pDrawable", "src", "srcStride", "srcBpp", "srcXoff", "srcYoff"));

    while (nspans--) {
        xoff = cast(int) ((cast(c_long) pchardstStart) & (FB_MASK >> 3));
        dst = cast(FbBits*) (pchardstStart - xoff);
        xoff <<= 3;
        fbBlt(src + (ppt.y + srcYoff) * srcStride, srcStride,
              (ppt.x + srcXoff) * srcBpp,
              dst,
              1,
              xoff,
              *pwidth * srcBpp, 1, GXcopy, FB_ALLONES, srcBpp, False, False);
        pchardstStart += PixmapBytePad(*pwidth, pDrawable.depth);
        ppt++;
        pwidth++;
    }

    mixin(fbFinishAccess!("pDrawable"));
}
