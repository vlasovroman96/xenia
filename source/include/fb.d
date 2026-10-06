module include.fb;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
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

 
//public import x11.X;
public import pixman;
import build.xorg_config;
public import include.scrnintstr;
public import include.pixmap;
public import include.pixmapstr;
public import include.regionstr;
public import include.gcstruct;
public import include.colormap;
public import include.miscstruct;
public import include.servermd;
public import include.windowstr;
public import include.privates;
public import include.mi;
public import include.mi;
import include.servermd;

public import migc;
public import include.picturestr;
import fb.fballpriv;
import include.fb;
public import fb.fbcmap_mi;
public import fb.fbwindow;


static if (FB_ACCESS_WRAPPER) {

public import wfbrename;
enum string FBPREFIX(string x) = `wfb##x`;
enum string WRITE(string ptr, string val) = `((*wfbWriteMemory)((` ~ ptr ~ `), (` ~ val ~ `), typeof(*(` ~ ptr ~ `)).sizeof))`;
enum string READ(string ptr) = `((*wfbReadMemory)((` ~ ptr ~ `), typeof(*(` ~ ptr ~ `)).sizeof))`;

} else {

enum string FBPREFIX(string x) = `fb##x`;
enum string WRITE(string ptr, string val) = `
	(*(` ~ ptr ~ `) = (` ~ val ~ `))`
;
enum string READ(string ptr) = `(*(` ~ ptr ~ `))`;

}

/*
 * This single define controls the basic size of data manipulated
 * by this software; it must be log2(sizeof (FbBits) * 8)
 */

enum FB_SHIFT =    LOG2_BITMAP_PAD;
// static if (FB_SHIFT == 5) {
alias FbBits = CARD32;
// } else {
// static assert(0, "Unsupported FB_SHIFT");
// }
// static if (LOG2_BITMAP_PAD == FB_SHIFT) {
alias FbStip = FbBits;
// }


enum FB_UNIT =	    (1 << FB_SHIFT);
enum FB_MASK =	    (FB_UNIT - 1);
enum FB_ALLONES =  (cast(FbBits) -1);
static if (GLYPHPADBYTES != 4) {
static assert(0, "GLYPHPADBYTES must be 4");
}
enum FB_STIP_SHIFT =	LOG2_BITMAP_PAD;
enum FB_STIP_UNIT =	(1 << FB_STIP_SHIFT);
enum FB_STIP_MASK =	(FB_STIP_UNIT - 1);
enum FB_STIP_ALLONES =	(cast(FbStip) -1);
enum string FbFullMask(string n) = `((` ~ n ~ `) == FB_UNIT ? FB_ALLONES : (((cast(FbBits) 1) << ` ~ n ~ `) - 1))`;



alias FbStride = int;

public import include.fbrop;

static if (BITMAP_BIT_ORDER == LSBFirst) {
enum string FbScrLeft(string x,string n) = `((` ~ x ~ `) >> (` ~ n ~ `))`;
enum string FbScrRight(string x,string n) = `((` ~ x ~ `) << (` ~ n ~ `))`;
enum string FbLeftStipBits(string x,string n) = `((` ~ x ~ `) & (((cast(FbStip) 1) << (` ~ n ~ `)) - 1))`;
enum string FbStipMoveLsb(string x,string s,string n) = `(`~FbStipRight !(x,`(` ~ s ~ `)-(` ~ n ~ `)`)~`)`;
enum FbPatternOffsetBits =	0;
} else {
enum string FbScrLeft(string x,string n) = `((` ~ x ~ `) << (` ~ n ~ `))`;
enum string FbScrRight(string x,string n) = `((` ~ x ~ `) >> (` ~ n ~ `))`;
enum string FbLeftStipBits(string x,string n) = `((` ~ x ~ `) >> (FB_STIP_UNIT - (` ~ n ~ `)))`;
enum string FbStipMoveLsb(string x,string s,string n) = `(` ~ x ~ `)`;
enum FbPatternOffsetBits =	((FbBits).sizeof - 1);
}

public import include.micoord;

enum string FbStipLeft(string x,string n) = `` ~ FbScrLeft!(x,n) ~ ``;
enum string FbStipRight(string x,string n) = `` ~ FbScrRight!(x,n) ~ ``;

enum string FbRotLeft(string x,string n) = `` ~ FbScrLeft!(x,n) ~ ` | (` ~ n ~ ` ? ` ~ FbScrRight!(x,`FB_UNIT-` ~ n ~ ``) ~ ` : 0)`;

enum string FbLeftMask(string x) = `( ((` ~ x ~ `) & FB_MASK) ? 
			     ` ~ FbScrRight!(`FB_ALLONES`,`(` ~ x ~ `) & FB_MASK`) ~ ` : 0)`;
enum string FbRightMask(string x) = `( ((FB_UNIT - (` ~ x ~ `)) & FB_MASK) ? 
			     ` ~ FbScrLeft!(`FB_ALLONES`,`(FB_UNIT - (` ~ x ~ `)) & FB_MASK`) ~ ` : 0)`;

enum string FbLeftStipMask(string x) = `( ((` ~ x ~ `) & FB_STIP_MASK) ? 
			     ` ~ FbStipRight!(`FB_STIP_ALLONES`,`(` ~ x ~ `) & FB_STIP_MASK`) ~ ` : 0)`;
enum string FbRightStipMask(string x) = `( ((FB_STIP_UNIT - (` ~ x ~ `)) & FB_STIP_MASK) ? 
			     ` ~ FbScrLeft!(`FB_STIP_ALLONES`,`(FB_STIP_UNIT - (` ~ x ~ `)) & FB_STIP_MASK`) ~ ` : 0)`;

enum string FbBitsMask(string x,string w) = `(` ~ FbScrRight!(`FB_ALLONES`,`(` ~ x ~ `) & FB_MASK`) ~ ` & 
			 ` ~ FbScrLeft!(`FB_ALLONES`,`(FB_UNIT - ((` ~ x ~ `) + (` ~ w ~ `))) & FB_MASK`) ~ `)`;

enum string FbStipMask(string x,string w) = `(` ~ FbStipRight!(`FB_STIP_ALLONES`,`(` ~ x ~ `) & FB_STIP_MASK`) ~ ` & 
			 ` ~ FbStipLeft!(`FB_STIP_ALLONES`,`(FB_STIP_UNIT - ((` ~ x ~ `)+(` ~ w ~ `))) & FB_STIP_MASK`) ~ `)`;

enum FbByteMaskInvalid =   0x10;

enum string FbPatternOffset(string o,string t) = `(` ~ o ~ ` ^ (FbPatternOffsetBits & ~(` ~ t ~ `.sizeof - 1)))`;

enum string FbPtrOffset(string p,string o,string t) = `(cast(`~t~`*) ((` ~ p ~ `) + (` ~ o ~ `)))`;
enum string FbSelectPatternPart(string xor,string o,string t) = `cast(ubyte)((` ~ xor ~ `) >> (` ~ FbPatternOffset! (o,t) ~ ` << 3))`;
enum string FbStorePart(string dst,string off,string t,string xor) = WRITE!(FbPtrOffset!(dst,off,t), 
					 FbSelectPart!(xor, off, t));
version (FbSelectPart) {} else {
enum string FbSelectPart(string x,string o,string t) = `` ~ FbSelectPatternPart!(x,o,t) ~ ``;
}

enum string FbMaskBitsBytes(string x,string w,string copy,string l,string lb,string n,string r,string rb) = `{ 
    ` ~ n ~ ` = (` ~ w ~ `); 
    ` ~ lb ~ ` = 0; 
    ` ~ rb ~ ` = 0; 
    ` ~ r ~ ` = ` ~ FbRightMask!(`(` ~ x ~ `)+` ~ n ) ~ `; 
    if (` ~ r ~ `) { 
	/* compute right byte length */ 
	if (`~copy~` && (((` ~ x ~ `) + ` ~ n ~ `) & 7) == 0) { 
	    ` ~ rb ~ ` = (((` ~ x ~ `) + ` ~ n ~ `) & FB_MASK) >> 3; 
	} else { 
	    ` ~ rb ~ ` = FbByteMaskInvalid; 
	} 
    } 
    ` ~ l ~ ` = ` ~ FbLeftMask!(x) ~ `; 
    if (` ~ l ~ `) { 
	/* compute left byte length */ 
	if (`~copy~` && ((` ~ x ~ `) & 7) == 0) { 
	    ` ~ lb ~ ` = ((` ~ x ~ `) & FB_MASK) >> 3; 
	} else { 
	    ` ~ lb ~ ` = FbByteMaskInvalid; 
	} 
	/* subtract out the portion painted by leftMask */ 
	` ~ n ~ ` -= FB_UNIT - ((` ~ x ~ `) & FB_MASK); 
	if (` ~ n ~ ` < 0) { 
	    if (` ~ lb ~ ` != FbByteMaskInvalid) { 
		if (` ~ rb ~ ` == FbByteMaskInvalid) { 
		    ` ~ lb ~ ` = FbByteMaskInvalid; 
		} else if (` ~ rb ~ `) { 
		    ` ~ lb ~ ` |= (` ~ rb ~ ` - ` ~ lb ~ `) << (FB_SHIFT - 3); 
		    ` ~ rb ~ ` = 0; 
		} 
	    } 
	    ` ~ n ~ ` = 0; 
	    ` ~ l ~ ` &= ` ~ r ~ `; 
	    ` ~ r ~ ` = 0; 
	}
    } 
    ` ~ n ~ ` >>= FB_SHIFT; 
}`;

pragma(msg, "FbBits.sizeof = ", FbBits.sizeof);
pragma(msg, "FB_SHIFT = ", FB_SHIFT);
enum string FbDoLeftMaskByteRRop(string dst,string lb,string l,string and,string xor) = `{ 
    switch (` ~ lb ~ `) { 
    case (((FbBits).sizeof - 3)) | (1 << (FB_SHIFT - 3)): 
	` ~ FbStorePart!(dst,`((FbBits).sizeof - 3)`,`CARD8`,xor) ~ `; 
	break; 
    case (((FbBits).sizeof - 3)) | (2 << (FB_SHIFT - 3)): 
	` ~ FbStorePart!(dst,`((FbBits).sizeof - 3)`,`CARD8`,xor) ~ `; 
	` ~ FbStorePart!(dst,`((FbBits).sizeof - 2)`,`CARD8`,xor) ~ `; 
	break; 
    case (((FbBits).sizeof - 2)) | (1 << (FB_SHIFT - 3)): 
	` ~ FbStorePart!(dst,`((FbBits).sizeof - 2)`,`CARD8`,xor) ~ `; 
	break; 
    // case ((FbBits).sizeof - 3): 
	// ` ~ FbStorePart!(dst,`((FbBits).sizeof - 3)`,`CARD8`,xor) ~ `;
	// goto case  ((FbBits).sizeof - 2);
    // case ((FbBits).sizeof - 2): 
	// ` ~ FbStorePart!(dst,`((FbBits).sizeof - 2)`,`CARD16`,xor) ~ `; 
	// break; 
    // case ((FbBits).sizeof - 1): 
	// ` ~ FbStorePart!(dst,`((FbBits).sizeof - 1)`,`CARD8`,xor) ~ `; 
	// break; 
    default: 
	` ~ WRITE!(dst, FbDoMaskRRop!(READ!(dst), and, xor, l)) ~ `; 
	break; 
    } 
}`;

enum string FbDoRightMaskByteRRop(string dst,string rb,string r,string and,string xor) = ` 
    switch (` ~ rb ~ `) { 
    case 1: 
	` ~ FbStorePart!(dst,`0`,`CARD8`,xor) ~ `; 
	break; 
    case 2: 
	` ~ FbStorePart!(dst,`0`,`CARD16`,xor) ~ `; 
	break; 
    case 3: 
	` ~ FbStorePart!(dst,`0`,`CARD16`,xor) ~ `; 
	` ~ FbStorePart!(dst,`2`,`CARD8`,xor) ~ `; 
	break; 
    default: 
	` ~ WRITE!(dst, FbDoMaskRRop!(READ!(dst), and , xor, r)) ~ `;
    } 
`;

/* Framebuffer access wrapper */
alias ReadMemoryProcPtr = FbBits function(const(void)* src, int size);
alias WriteMemoryProcPtr = void function(void* dst, FbBits value, int size);
alias SetupWrapProcPtr = void function(ReadMemoryProcPtr* pRead, WriteMemoryProcPtr* pWrite, DrawablePtr pDraw);
alias FinishWrapProcPtr = void function(DrawablePtr pDraw);

static if (FB_ACCESS_WRAPPER) {

enum string fbPrepareAccess(string pDraw) = 
	fbGetScreenPrivate!(pDraw~`.pScreen`)~`.setupWrap( 
		&wfbReadMemory, 
		&wfbWriteMemory, `~pDraw ~ `)`;

enum string fbFinishAccess(string pDraw) = `
	mixin(fbGetScreenPrivate!("(` ~ pDraw ~ `).pScreen")).finishWrap(` ~ pDraw ~ `);`;

} else {

enum string fbPrepareAccess(string pDraw) = "";

enum string fbFinishAccess(string pDraw) = ``;

}

// DevPrivateKey
// fbGetScreenPrivateKey();

/* private field of a screen */
struct _FbScreenPrivRec {
static if (FB_ACCESS_WRAPPER) {
    SetupWrapProcPtr setupWrap;   /* driver hook to set pixmap access wrapping */
    FinishWrapProcPtr finishWrap; /* driver hook to clean up pixmap access wrapping */
}
    DevPrivateKeyRec gcPrivateKeyRec;
    DevPrivateKeyRec winPrivateKeyRec;
}alias FbScreenPrivRec = _FbScreenPrivRec;
alias FbScreenPrivPtr = FbScreenPrivRec*;

enum string fbGetScreenPrivate(string pScreen) = `(cast(FbScreenPrivPtr) 
				     dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, fbGetScreenPrivateKey()))`;

/* private field of GC */
struct _FbGCPrivRec {
    FbBits and, xor;            /* reduced rop values */
    FbBits bgand, bgxor;        /* for stipples */
    FbBits fg, bg, pm;          /* expanded and filled */
    uint dashLength;    /* total of all dash elements */
}alias FbGCPrivRec = _FbGCPrivRec;
alias FbGCPrivPtr = FbGCPrivRec*;

enum string fbGetCompositeClip(string pGC) = `((` ~ pGC ~ `).pCompositeClip)`;

enum string fbGetWinPrivateKey(string pWin) = `(&` ~ fbGetScreenPrivate!(`(cast(DrawablePtr) (` ~ pWin ~ `)).pScreen`) ~ `.winPrivateKeyRec)`;

enum string fbGetWindowPixmap(string pWin) = `(cast(PixmapPtr)
				 dixLookupPrivate(&(cast(WindowPtr)(` ~ pWin ~ `)).devPrivates, ` ~ fbGetWinPrivateKey!(pWin) ~ `))`;

enum string __fbPixDrawableX(string pPix) = `((` ~ pPix ~ `).drawable.x)`;
enum string __fbPixDrawableY(string pPix) = `((` ~ pPix ~ `).drawable.y)`;

enum string __fbPixOffXWin(string pPix) = `(` ~ __fbPixDrawableX!(pPix) ~ ` - (` ~ pPix ~ `).screen_x)`;
enum string __fbPixOffYWin(string pPix) = `(` ~ __fbPixDrawableY!(pPix) ~ ` - (` ~ pPix ~ `).screen_y)`;
enum string __fbPixOffXPix(string pPix) = `(` ~ __fbPixDrawableX!(pPix) ~ `)`;
enum string __fbPixOffYPix(string pPix) = `(` ~ __fbPixDrawableY!(pPix) ~ `)`;

enum string fbGetDrawablePixmap(string pDrawable, string pixmap, string xoff, string yoff) = `{			
    if ((` ~ pDrawable ~ `).type != DRAWABLE_PIXMAP) { 				
	(` ~ pixmap ~ `) = ` ~ fbGetWindowPixmap!(pDrawable) ~ `;				
	(` ~ xoff ~ `) = ` ~ __fbPixOffXWin!(pixmap) ~ `; 					
	(` ~ yoff ~ `) = ` ~ __fbPixOffYWin!(pixmap) ~ `; 					
    } else { 									
	(` ~ pixmap ~ `) = cast(PixmapPtr) (` ~ pDrawable ~ `);					
	(` ~ xoff ~ `) = ` ~ __fbPixOffXPix!(pixmap) ~ `; 					
	(` ~ yoff ~ `) = ` ~ __fbPixOffYPix!(pixmap) ~ `; 					
    }`~ 										
    fbPrepareAccess!(pDrawable)~`; 						
}`;

enum string fbGetPixmapBitsData(string pixmap, string pointer, string stride, string bpp) = `{			
    (` ~ pointer ~ `) = cast(FbBits*) (` ~ pixmap ~ `).devPrivate.ptr; 			       	
    (` ~ stride ~ `) = cast(int)(` ~ pixmap ~ `.devKind / FbBits.sizeof); cast(void)(` ~ stride ~ `);	
    (` ~ bpp ~ `) = (` ~ pixmap ~ `).drawable.bitsPerPixel;  cast(void)(` ~ bpp ~ `); 			
}`;

enum string fbGetPixmapStipData(string pixmap, string pointer, string stride, string bpp) = `{			
    (` ~ pointer ~ `) = cast(FbStip*) (` ~ pixmap ~ `).devPrivate.ptr; 			       	
    (` ~ stride ~ `) = (cast(int)(` ~ pixmap ~ `.devKind / FbStip.sizeof)); cast(void)(` ~ stride ~ `);	
    (` ~ bpp ~ `) = (` ~ pixmap ~ `).drawable.bitsPerPixel;  cast(void)(` ~ bpp ~ `); 			
}`;

enum string fbGetDrawable(string pDrawable, string pointer, string stride, string bpp, string xoff, string yoff) = `{ 		
    PixmapPtr _pPix = void; 								
    ` ~ fbGetDrawablePixmap!(pDrawable, `_pPix`, xoff, yoff) ~ `; 				
    ` ~ fbGetPixmapBitsData!(`_pPix`, pointer, stride, bpp) ~ `;				
}`;

enum string fbGetStipDrawable(string pDrawable, string pointer, string stride, string bpp, string xoff, string yoff) = `{ 	
    PixmapPtr _pPix = void; 								
    ` ~ fbGetDrawablePixmap!(pDrawable, `_pPix`, xoff, yoff) ~ `;				
    ` ~ fbGetPixmapStipData!(`_pPix`, pointer, stride, bpp) ~ `;				
}`;

/*
 * XFree86 empties the root BorderClip when the VT is inactive,
 * here's a macro which uses that to disable GetImage and GetSpans
 */

enum string fbWindowEnabled(string pWin) = `
    RegionNotEmpty(&(` ~ pWin ~ `).borderClip)`;

enum string fbDrawableEnabled(string pDrawable) = `
    ((` ~ pDrawable ~ `).type == DRAWABLE_PIXMAP ? 
     TRUE : ` ~ fbWindowEnabled!(`cast(WindowPtr) ` ~ pDrawable ~ ``) ~ `)`;

enum string FbPowerOfTwo(string w) = `(((` ~ w ~ `) & ((` ~ w ~ `) - 1)) == 0)`;
/*
 * Accelerated tiles are power of 2 width <= FB_UNIT
 */
enum string FbEvenTile(string w) = `((` ~ w ~ `) <= FB_UNIT && ` ~ FbPowerOfTwo!(w) ~ `)`;

/*
 * fbarc.c
 */

void fbPolyArc(DrawablePtr pDrawable, GCPtr pGC, int narcs, xArc* parcs);

/*
 * fb.fbbits;.c
 */

// void fbBresSolid8(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbBresDash8(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbDots8(FbBits* dst, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* pts, int npt, int xorg, int yorg, int xoff, int yoff, FbBits and, FbBits xor);

// void fbArc8(FbBits* dst, FbStride dstStride, int dstBpp, xArc* arc, int dx, int dy, FbBits and, FbBits xor);

// extern(C) void fbGlyph8(FbBits* dstLine, FbStride dstStride, int dstBpp, FbStip* stipple, FbBits fg, int height, int shift);

// void fbPolyline8(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ptsOrig);

// void fbPolySegment8(DrawablePtr pDrawable, GCPtr pGC, int nseg, xSegment* pseg);

// void fbBresSolid16(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbBresDash16(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbDots16(FbBits* dst, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* pts, int npt, int xorg, int yorg, int xoff, int yoff, FbBits and, FbBits xor);

// void fbArc16(FbBits* dst, FbStride dstStride, int dstBpp, xArc* arc, int dx, int dy, FbBits and, FbBits xor);

// void fbGlyph16(FbBits* dstLine, FbStride dstStride, int dstBpp, FbStip* stipple, FbBits fg, int height, int shift);

// void fbPolyline16(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ptsOrig);

// void fbPolySegment16(DrawablePtr pDrawable, GCPtr pGC, int nseg, xSegment* pseg);

// void fbBresSolid32(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbBresDash32(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x, int y, int e, int e1, int e3, int len);

// void fbDots32(FbBits* dst, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* pts, int npt, int xorg, int yorg, int xoff, int yoff, FbBits and, FbBits xor);

// void fbArc32(FbBits* dst, FbStride dstStride, int dstBpp, xArc* arc, int dx, int dy, FbBits and, FbBits xor);

// void fbGlyph32(FbBits* dstLine, FbStride dstStride, int dstBpp, FbStip* stipple, FbBits fg, int height, int shift);
// void fbPolyline32(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ptsOrig);

// void fbPolySegment32(DrawablePtr pDrawable, GCPtr pGC, int nseg, xSegment* pseg);

/*
 * fbblt.c
 */
void fbBlt(FbBits* src, FbStride srcStride, int srcX, FbBits* dst, FbStride dstStride, int dstX, int width, int height, int alu, FbBits pm, int bpp, Bool reverse, Bool upsidedown);

void fbBltStip(FbStip* src, FbStride srcStride, int srcX, FbStip* dst, FbStride dstStride, int dstX, int width, int height, int alu, FbBits pm, int bpp);

/*
 * fbbltone.c
 */
void fbBltOne(FbStip* src, FbStride srcStride, int srcX, FbBits* dst, FbStride dstStride, int dstX, int dstBpp, int width, int height, FbBits fgand, FbBits fbxor, FbBits bgand, FbBits bgxor);

void fbBltPlane(FbBits* src, FbStride srcStride, int srcX, int srcBpp, FbStip* dst, FbStride dstStride, int dstX, int width, int height, FbStip fgand, FbStip fgxor, FbStip bgand, FbStip bgxor, Pixel planeMask);

/*
 * fbcmap_mi.c
 */
void fbInstallColormap(ColormapPtr pmap);

void fbUninstallColormap(ColormapPtr pmap);

// void fbResolveColor(ushort* pred, ushort* pgreen, ushort* pblue, VisualPtr pVisual);

// void fbInitializeColormap(ColormapPtr pmap);

// void mfbCreateColormap(ColormapPtr pmap);

void fbExpandDirectColors(ColormapPtr pmap, int ndef, xColorItem* indefs, xColorItem* outdefs);

void fbCreateDefColormap(ScreenPtr pScreen);

void fbClearVisualTypes();

void fbSetVisualTypes(int depth, int visuals, int bitsPerRGB);

void fbSetVisualTypesAndMasks(int depth, int visuals, int bitsPerRGB, Pixel redMask, Pixel greenMask, Pixel blueMask);

// void fbInitVisuals(VisualPtr* visualp, DepthPtr* depthp, int* nvisualp, int* ndepthp, int* rootDepthp, VisualID* defaultVisp, c_ulong sizes, int bitsPerRGB);

/*
 * fbcopy.c
 */

void fbCopyNtoN(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

void fbCopy1toN(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

void* fbCopyNto1(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

RegionPtr fbCopyArea(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int xIn, int yIn, int widthSrc, int heightSrc, int xOut, int yOut);

RegionPtr fbCopyPlane(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int xIn, int yIn, int widthSrc, int heightSrc, int xOut, int yOut, c_ulong bitplane);

/*
 * fbfill.c
 */
// void fbFill(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int width, int height);

void fbSolidBoxClipped(DrawablePtr pDrawable, RegionPtr pClip, int xa, int ya, int xb, int yb, FbBits and, FbBits xor);

/*
 * fbfillrect.c
 */
void fbPolyFillRect(DrawablePtr pDrawable, GCPtr pGC, int nrectInit, xRectangle* prectInit);

/*
 * fbfillsp.c
 */
void fbFillSpans(DrawablePtr pDrawable, GCPtr pGC, int nInit, DDXPointPtr pptInit, int* pwidthInit, int fSorted);

/*
 * fbgc.c
 */

// void fbCreateGC(GCPtr pGC);

// void fbPadPixmap(PixmapPtr pPixmap);

// void fbValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDrawable);

/*
 * fbgetsp.c
 */
void fbGetSpans(DrawablePtr pDrawable, int wMax, DDXPointPtr ppt, int* pwidth, int nspans, char* pchardstStart);

/*
 * fbglyph.c
 */

void fbPolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

void fbImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

/*
 * fbimage.c
 */

void fbPutImage(DrawablePtr pDrawable, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pImage);

void fbPutZImage(DrawablePtr pDrawable, RegionPtr pClip, int alu, FbBits pm, int x, int y, int width, int height, FbStip* src, FbStride srcStride);

void fbPutXYImage(DrawablePtr pDrawable, RegionPtr pClip, FbBits fg, FbBits bg, FbBits pm, int alu, Bool opaque, int x, int y, int width, int height, FbStip* src, FbStride srcStride, int srcX);

void fbGetImage(DrawablePtr pDrawable, int x, int y, int w, int h, uint format, c_ulong planeMask, char* d);
/*
 * fbline.c
 */

void fbPolyLine(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ppt);

void fbFixCoordModePrevious(int npt, DDXPointPtr ppt);

void fbPolySegment(DrawablePtr pDrawable, GCPtr pGC, int nseg, xSegment* pseg);

/*
 * fbpict.c
 */

void fbPictureInit(ScreenPtr pScreen, PictFormatPtr formats, int nformats);

void fbDestroyGlyphCache();

/*
 * fbpixmap.c
 */

// void fbCreatePixmap(ScreenPtr pScreen, int width, int height, int depth, uint usage_hint);

// void fbDestroyPixmap(PixmapPtr pPixmap);

// void fbPixmapToRegion(PixmapPtr pPix);

/*
 * fbpoint.c
 */

void fbPolyPoint(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, xPoint* pptInit);

/*
 * fbpush.c
 */

// void fbPushImage(DrawablePtr pDrawable, GCPtr pGC, FbStip* src, FbStride srcStride, int srcX, int x, int y, int width, int height);

void fbPushPixels(GCPtr pGC, PixmapPtr pBitmap, DrawablePtr pDrawable, int dx, int dy, int xOrg, int yOrg);

/*
 * fbscreen.c
 */

void fbCloseScreen(ScreenPtr pScreen);

void fbRealizeFont(ScreenPtr pScreen, FontPtr pFont);

void fbUnrealizeFont(ScreenPtr pScreen, FontPtr pFont);

void fbQueryBestSize(int class_, ushort* width, ushort* height, ScreenPtr pScreen);

int _fbGetWindowPixmap(WindowPtr pWindow);

// int _fbSetWindowPixmap(WindowPtr pWindow, PixmapPtr pPixmap);

int fbSetupScreen(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp);        /* bits per pixel of frame buffer */

static if (FB_ACCESS_WRAPPER) {
int wfbFinishScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp, SetupWrapProcPtr setupWrap, FinishWrapProcPtr finishWrap);

int wfbScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp, SetupWrapProcPtr setupWrap, FinishWrapProcPtr finishWrap);
}

int fbFinishScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp);

int fbScreenInit(ScreenPtr pScreen, void* pbits, int xsize, int ysize, int dpix, int dpiy, int width, int bpp);

/*
 * fbseg.c
 */
alias FbBres = extern(C) void(
    DrawablePtr pDrawable,
    GCPtr pGC,
    int dashOffset,
    int signdx,
    int signdy,
    int axis, 
    int x, 
    int y, 
    int e, 
    int e1, 
    int e3, 
    int len
) nothrow @nogc;

void fbSegment(DrawablePtr pDrawable, GCPtr pGC, int xa, int ya, int xb, int yb, Bool drawLast, int* dashOffset);

/*
 * fbsetsp.c
 */

void fbSetSpans(DrawablePtr pDrawable, GCPtr pGC, char* src, DDXPointPtr ppt, int* pwidth, int nspans, int fSorted);

/*
 * fbsolid.c
 */

void fbSolid(FbBits* dst, FbStride dstStride, int dstX, int bpp, int width, int height, FbBits and, FbBits xor);

/*
 * fbtile.c
 */

void fbEvenTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileHeight, int alu, FbBits pm, int xRot, int yRot);

void fbOddTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileWidth, int tileHeight, int alu, FbBits pm, int bpp, int xRot, int yRot);

void fbTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileWidth, int tileHeight, int alu, FbBits pm, int bpp, int xRot, int yRot);

/*
 * fbutil.c
 */
// void fbReplicatePixel(Pixel p, int bpp);

static if (FB_ACCESS_WRAPPER) {
ReadMemoryProcPtr wfbReadMemory;
WriteMemoryProcPtr wfbWriteMemory;
}

/*
 * fbwindow.c
 */

int fbCreateWindow(WindowPtr pWin);

int fbDestroyWindow(WindowPtr pWin);

int fbRealizeWindow(WindowPtr pWindow);

int fbPositionWindow(WindowPtr pWin, int x, int y);

int fbUnrealizeWindow(WindowPtr pWindow);

// int fbCopyWindowProc(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

void fbCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc);

int fbChangeWindowAttributes(WindowPtr pWin, c_ulong mask);

int fbFillRegionSolid(DrawablePtr pDrawable, RegionPtr pRegion, FbBits and, FbBits xor);

// pixman_image* image_from_pict(PicturePtr pict, Bool has_clip, int* xoff, int* yoff);

// int free_pixman_pict(PicturePtr, pixman_image_t*);

                          /* _FB_H_ */
