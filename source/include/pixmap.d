module include.pixmap;
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

 
public import include.misc;
public import include.screenint;
public import include.regionstr;
// //public import externs.X11.extensions._randr;
import include.pixmapstr;
/* types for Drawable */
enum DRAWABLE_WINDOW = 0;
enum DRAWABLE_PIXMAP = 1;
enum UNDRAWABLE_WINDOW = 2;

/* corresponding type masks for dixLookupDrawable() */
enum M_DRAWABLE_WINDOW =	(1<<0);
enum M_DRAWABLE_PIXMAP =	(1<<1);
enum M_UNDRAWABLE_WINDOW =	(1<<2);
enum M_ANY =			(-1);
enum M_WINDOW =	(M_DRAWABLE_WINDOW|M_UNDRAWABLE_WINDOW);
enum M_DRAWABLE =	(M_DRAWABLE_WINDOW|M_DRAWABLE_PIXMAP);
enum M_UNDRAWABLE =	(M_UNDRAWABLE_WINDOW);

/* flags to PaintWindow() */
enum PW_BACKGROUND = 0;
enum PW_BORDER = 1;

enum NullPixmap = cast(PixmapPtr)0;

// alias DrawablePtr = _Drawable*;
alias PixmapPtr = _Pixmap*;

alias PixmapDirtyUpdatePtr = _PixmapDirtyUpdate*;

union PixUnion {
    PixmapPtr pixmap;
    c_ulong pixel;
}

enum string SamePixUnion(string a,string b,string isPixel) = `
    ((` ~ isPixel ~ `) ? (` ~ a ~ `).pixel == (` ~ b ~ `).pixel : (` ~ a ~ `).pixmap == (` ~ b ~ `).pixmap)`;

enum string EqualPixUnion(string as, string a, string bs, string b) = `
    ((` ~ as ~ `) == (` ~ bs ~ `) && (` ~ SamePixUnion! (a, b, as) ~ `))`;

enum string OnScreenDrawable(string type) = `
	(` ~ type ~ ` == DRAWABLE_WINDOW)`;

enum string WindowDrawable(string type) = `
	((` ~ type ~ ` == DRAWABLE_WINDOW) || (` ~ type ~ ` == UNDRAWABLE_WINDOW))`;

// int GetScratchPixmapHeader(ScreenPtr pScreen, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

// int FreeScratchPixmapHeader(PixmapPtr);

int PixmapScreenInit(ScreenPtr);

// int AllocatePixmap(ScreenPtr, int);

// int FreePixmap(PixmapPtr);

// int PixmapShareToSecondary(PixmapPtr pixmap, ScreenPtr secondary);

// int PixmapUnshareSecondaryPixmap(PixmapPtr secondary_pixmap);

enum HAS_DIRTYTRACKING_ROTATION = 1;
enum HAS_DIRTYTRACKING_DRAWABLE_SRC = 1;
// int PixmapStartDirtyTracking(DrawablePtr src, PixmapPtr slave_dst, int x, int y, int dst_x, int dst_y, Rotation rotation);

// int PixmapStopDirtyTracking(DrawablePtr src, PixmapPtr slave_dst);

/* helper function, drivers can do this themselves if they can do it more
   efficiently */
// int PixmapSyncDirtyHelper(PixmapDirtyUpdatePtr dirty);

// int PixmapDirtyCopyArea(PixmapPtr dst, DrawablePtr src, int x, int y, int dst_x, int dst_y, RegionPtr dirty_region);

                          /* PIXMAP_H */
