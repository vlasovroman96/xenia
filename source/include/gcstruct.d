module include.gcstruct;
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

 
//public import x11.Xprotostr;

public import dix.gc;
public import include.pixmap;
public import include.regionstr;
public import include.scrintstr;
public import include.privates;

import legacyXf = externs.X11.fonts.font;
import legacyXfs = externs.X11.fonts.fontstruct;

// alias xSegment = x11.Xprotostr.xSegment;
// alias xRectangle = x11.Xprotostr.xRectangle;
// alias xArc = x11.Xprotostr.xArc;

version (_XTYPEDEF_CHARINFOPTR) {} else {
alias CharInfoPtr = legacyXfs._CharInfo*;  /* also in fonts/include/font.h */
// version = _XTYPEDEF_CHARINFOPTR;
}

/*
 * functions which modify the state of the GC
 */

struct GCFuncs {
    void function(GCPtr, c_ulong, DrawablePtr) @nogc nothrow ValidateGC;

    void function(GCPtr, c_ulong) @nogc nothrow ChangeGC;

    void function(GCPtr, c_ulong, GCPtr) @nogc nothrow CopyGC;

    void function(GCPtr) @nogc nothrow DestroyGC;

    void function(GCPtr pGC, int type, void* pvalue, int nrects) @nogc nothrow ChangeClip;

    void function(GCPtr) @nogc nothrow DestroyClip;

    void function(GCPtr, GCPtr) @nogc nothrow CopyClip;
}

/*
 * graphics operations invoked through a GC
 */

struct _GCOps {
    void function(DrawablePtr, GCPtr, int, DDXPointPtr, int*, int) @nogc nothrow FillSpans;

    void function(DrawablePtr, GCPtr, char*, DDXPointPtr, int*, int, int) @nogc nothrow SetSpans;

    void function(DrawablePtr, GCPtr, int, int, int, int, int, int, int, char*) @nogc nothrow PutImage ;

    RegionPtr function(DrawablePtr, DrawablePtr, GCPtr, int, int, int, int, int, int) @nogc nothrow CopyArea;

    RegionPtr function(DrawablePtr, DrawablePtr, GCPtr, int, int, int, int, int, int, c_ulong) @nogc nothrow CopyPlane;
    void function(DrawablePtr, GCPtr, int, int, DDXPointPtr) @nogc nothrow PolyPoint;

    void function(DrawablePtr, GCPtr, int, int, DDXPointPtr) @nogc nothrow Polylines;

    void function(DrawablePtr, GCPtr, int, xSegment*) @nogc nothrow PolySegment;

    void function(DrawablePtr, GCPtr, int, xRectangle*) @nogc nothrow PolyRectangle;

    void function(DrawablePtr, GCPtr, int, xArc*) @nogc nothrow PolyArc;

    void function(DrawablePtr, GCPtr, int, int, int, DDXPointPtr) @nogc nothrow FillPolygon;

    void function(DrawablePtr, GCPtr, int, xRectangle*) @nogc nothrow PolyFillRect;

    void function(DrawablePtr, GCPtr, int, xArc*) @nogc nothrow PolyFillArc;

    int function(DrawablePtr, GCPtr, int, int, int, char*) @nogc nothrow PolyText8;

    int function(DrawablePtr, GCPtr, int, int, int, ushort*) @nogc nothrow PolyText16;

    void function(DrawablePtr, GCPtr, int, int, int, char*) @nogc nothrow ImageText8;

    void function(DrawablePtr, GCPtr, int, int, int, ushort*) @nogc nothrow ImageText16;

    void function(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase) @nogc nothrow ImageGlyphBlt;

    void function(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase) @nogc nothrow PolyGlyphBlt;

    void function(GCPtr, PixmapPtr, DrawablePtr, int, int, int, int) @nogc nothrow PushPixels;
}

/* there is padding in the bit fields because the Sun compiler doesn't
 * force alignment to 32-bit boundaries.  losers.
 */
struct _GC {
    ScreenPtr pScreen;
    ubyte depth;
    ubyte alu;
    ushort lineWidth;
    ushort dashOffset;
    ushort numInDashList;
    ubyte* dash;
    uint lineStyle : 2;
    uint capStyle : 2;
    uint joinStyle : 2;
    uint fillStyle : 2;
    uint fillRule : 1;
    uint arcMode : 1;
    uint subWindowMode : 1;
    uint graphicsExposures : 1;
    uint miTranslate : 1; /* should mi things translate? */
    uint tileIsPixel : 1; /* tile is solid pixel */
    uint fExpose : 1;     /* Call exposure handling */
    uint freeCompClip : 1;        /* Free composite clip */
    uint scratch_inuse : 1;       /* is this GC in a pool for reuse? */
    uint unused : 15;     /* see comment above */
    uint planemask;
    uint fgPixel;
    uint bgPixel;
    /*
     * alas -- both tile and stipple must be here as they
     * are independently specifiable
     */
    PixUnion tile;
    PixmapPtr stipple;
    xPoint patOrg;         /* origin for (tile, stipple) */
    xPoint clipOrg;
    legacyXfs._Font* font;
    RegionPtr clientClip;
    uint stateChanges; /* masked with GC_<kind> */
    uint serialNumber;
    const(GCFuncs)* funcs;
    const(_GCOps)* ops;
    PrivateRec* devPrivates;
    RegionPtr pCompositeClip;
}

alias GCRec = _GC;
                          /* GCSTRUCT_H */
