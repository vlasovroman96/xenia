module mitrap;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2002 Keith Packard, member of The XFree86 Project, Inc.
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

import mi.mipict;

import include.scrnintstr;
import dix.gc;
import include.pixmapstr;
import include.windowstr;
import include.servermd;
import dix.picturestr;
import externs.X11.extensions.renderproto;
import externs.attrs;
import dix.picture;


private XFixed miLineFixedX(xLineFixed* l, XFixed y, Bool ceil)
{
    XFixed dx = cast(int)(l.p2.x - l.p1.x);
    XFixed_32_32 ex = cast(XFixed_32_32) (y - l.p1.y) * dx;
    XFixed dy = cast(int)(l.p2.y - l.p1.y);

    if (ceil)
        ex += (dy - 1);
    return cast(int)(l.p1.x + cast(XFixed) (ex / dy));
}

void miTrapezoidBounds(int ntrap, xTrapezoid* traps, BoxPtr box)
{
    box.y1 = MAXSHORT;
    box.y2 = MINSHORT;
    box.x1 = MAXSHORT;
    box.x2 = MINSHORT;
    for (; ntrap; ntrap--, traps++) {
        INT16 x1 = void, y1 = void, x2 = void, y2 = void;

        if (!mixin(xTrapezoidValid!("traps")))
            continue;
        y1 = cast(short)mixin(xFixedToInt!("traps.top"));
        if (y1 < box.y1)
            box.y1 = y1;

        y2 = cast(short)mixin(xFixedToInt!(xFixedCeil!("traps.bottom")));
        if (y2 > box.y2)
            box.y2 = y2;

        x1 = cast(short)mixin(xFixedToInt!("min(miLineFixedX(&traps.left, cast(int)traps.top, FALSE),
                             miLineFixedX(&traps.left, cast(int)traps.bottom, FALSE))"));
        if (x1 < box.x1)
            box.x1 = x1;

        x2 = cast(short)mixin(xFixedToInt!(xFixedCeil!
                         ("max
                          (miLineFixedX(&traps.right, cast(int)traps.top, TRUE),
                           miLineFixedX(&traps.right, cast(int)traps.bottom, TRUE))")));
        if (x2 > box.x2)
            box.x2 = x2;
    }
}
