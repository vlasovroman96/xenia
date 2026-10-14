module include.pixmapstr;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

 
public import include.pixmap;
public import include.screenint;
public import include.regionstr;
public import include.privates;
public import dix.damage;
// //public import externs.X11.extensions._randr;
public import include.picturestr;

struct _Drawable {
    ubyte type;         /* DRAWABLE_<type> */
    ubyte class_;        /* specific to type */
    ubyte depth;
    ubyte bitsPerPixel;
    XID id;                     /* resource id */
    short x;                    /* window: screen absolute, pixmap: 0 */
    short y;                    /* window: screen absolute, pixmap: 0 */
    ushort width;
    ushort height;
    ScreenPtr pScreen;
    c_ulong serialNumber;
}

alias DrawableRec = _Drawable;
alias DrawablePtr = DrawableRec*;

/*
 * PIXMAP -- device dependent
 */

struct _Pixmap {
    DrawableRec drawable;
    PrivateRec* devPrivates;
    int refcnt;
    int devKind;                /* This is the pitch of the pixmap, typically width*bpp/8. */
    DevUnion devPrivate;        /* When !NULL, devPrivate.ptr points to the raw pixel data. */
    short screen_x;
    short screen_y;
    uint usage_hint;        /* see CREATE_PIXMAP_USAGE_* */

    PixmapPtr primary_pixmap;    /* pointer to primary copy of pixmap for pixmap sharing */
}

alias PixmapRec = _Pixmap;


struct _PixmapDirtyUpdate {
    DrawablePtr src;            /* Root window / shared pixmap */
    PixmapPtr secondary_dst;    /* Shared / scanout pixmap */
    int x, y;
    DamagePtr damage;
    xorg_list ent;
    int dst_x, dst_y;
    Rotation rotation;
    PictTransform transform;
    pixman_f_transform f_transform, f_inverse;
}

alias PixmapDirtyUpdateRec = _PixmapDirtyUpdate;
alias PixmapDirtyUpdatePtr = PixmapDirtyUpdateRec*;

pragma(inline, true) void PixmapRegionInit(RegionPtr region, PixmapPtr pixmap)
{
    BoxRec box = {
        x2: cast(short)pixmap.drawable.width,
        y2: cast(short)pixmap.drawable.height,
    };
    RegionInit(region, &box, 1);
}

                          /* PIXMAPSTRUCT_H */
