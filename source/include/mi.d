module include.mi;
@nogc nothrow:
extern(C): __gshared:
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

 
//public import x11.X;
// //public import externs.X11.fonts.font;

public import include.regionstr;
public import include.validate;
public import include.window;
public import include.gc;
public import include.input;
public import include.cursor;
public import include.privates;
public import dix.colormap;
public import include.events;
import include.mistruct;
import externs.X11.fonts.fontstruct;
public import mi.micopy; 
public import mi.miexpose;
import mi.miscrinit;

alias MiBits =	CARD32;

alias miDashPtr = _miDash*;

enum EVEN_DASH =	0;
enum ODD_DASH =	~0;

/* miarc.c */

void  miPolyArc(DrawablePtr, GCPtr, int, xArc*);

/* micopy.c  */

enum string miGetCompositeClip(string pGC) = `((` ~ pGC ~ `).pCompositeClip)`;

alias miCopyProc = void function(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pDstBox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure) @nogc nothrow;

void  miCopyRegion(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, RegionPtr pDstRegion, int dx, int dy, miCopyProc copyProc, Pixel bitPlane, void* closure) @nogc nothrow;

// void  miDoCopy(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int xIn, int yIn, int widthSrc, int heightSrc, int xOut, int yOut, miCopyProc copyProc, Pixel bitplane, void* closure);

/* mieq.c */

version (INPUT_H) {} else {
alias DevicePtr = _DeviceRec*;
}

/* miexpose.c */

// void  miHandleExposures(DrawablePtr, DrawablePtr, GCPtr, int, int, int, int, int, int);

// void  miClearDrawable(DrawablePtr, GCPtr);

/* miglblt.c */

void  miPolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

void  miImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

/* mipoly.c */

void  miFillPolygon(DrawablePtr, GCPtr, int, int, int, DDXPointPtr);

/* mipolypnt.c */

void  miPolyPoint(DrawablePtr, GCPtr, int, int, xPoint*);

/* mipolyrect.c */

void  miPolyRectangle(DrawablePtr, GCPtr, int, xRectangle*);

/* mipolyseg.c */

void  miPolySegment(DrawablePtr, GCPtr, int, xSegment*);

/* mipolytext.c */

int  miPolyText8(DrawablePtr, GCPtr, int, int, int, char*);

int  miPolyText16(DrawablePtr, GCPtr, int, int, int, ushort*);

void  miImageText8(DrawablePtr, GCPtr, int, int, int, char*);

void  miImageText16(DrawablePtr, GCPtr, int, int, int, ushort*);

/* mipushpxl.c */

void  miPushPixels(GCPtr, PixmapPtr, DrawablePtr, int, int, int, int);

/* miscrinit.c */
void  miModifyPixmapHeader(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

// void  miScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int rootDepth, int numDepths, DepthPtr depths, VisualID rootVisual, int numVisuals, VisualPtr visuals);

/* mivaltree.c */

void  miWideLine(DrawablePtr, GCPtr, int, int, DDXPointPtr);

void  miWideDash(DrawablePtr, GCPtr, int, int, DDXPointPtr);

void  miPolylines(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr pPts);

/* mizerarc.c */

// void  miZeroPolyArc(DrawablePtr, GCPtr, int, xArc*);

void  miZeroLine(DrawablePtr dst, GCPtr gc, int mode, int nptInit, xPoint* pptInit);
void  miZeroDashLine(DrawablePtr dst, GCPtr pgc, int mode, int nptInit, xPoint* pptInit);

void  miPolyFillArc(DrawablePtr, GCPtr, int, xArc*);

                          /* MI_H */
