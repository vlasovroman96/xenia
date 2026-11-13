module xf86VGAarbiterPriv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 2009 Tiago Vignatti
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 */
 
public import hw.xfree86.os_support.xf86_OSproc;;
public import externs.X11.extensions.renderproto;
public import dix.scrnintstr;
public import dix.scrintstr;
public import dix.gc;
public import dix.pixmap;
public import dix.window;
public import hw.xfree86.common.xf86str;
public import mi.mipointer;
public import dix.picturestr;
import externs.pciaccess;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.modes.displaymode;
import dix.colormap_priv;
import dix.picture;

enum string WRAP_SCREEN(string x,string y) = `{pScreenPriv.` ~ x ~ ` = pScreen.` ~ x ~ `; pScreen.` ~ x ~ ` = &` ~ y ~ `;}`;

enum string UNWRAP_SCREEN(string x) = `{pScreen.` ~ x ~ ` = pScreenPriv.` ~ x ~ `;}`;

enum string SCREEN_PRIV() = `(cast(VGAarbiterScreenPtr) dixLookupPrivate(&(pScreen).devPrivates, &VGAarbiterScreenKeyRec))`;

enum string SCREEN_PROLOG(string x) = `{(pScreen.` ~ x ~ ` = ` ~ SCREEN_PRIV!() ~ `.` ~ x ~ `);}`;

enum string SCREEN_EPILOG(string x,string y) = `{                 
        ` ~ SCREEN_PRIV!() ~ `.` ~ x ~ ` = pScreen.` ~ x ~ `;          
        pScreen.` ~ x ~ ` = &` ~ y ~ `;                         
    }`;

enum string WRAP_PICT(string x,string y) = `if (ps) {pScreenPriv.` ~ x ~ ` = ps.` ~ x ~ `;
    ps.` ~ x ~ ` = &` ~ y ~ `;}`;

enum string UNWRAP_PICT(string x) = `if (ps) {ps.` ~ x ~ ` = pScreenPriv.` ~ x ~ `;}`;

enum string PICTURE_PROLOGUE(string field) = `{ps.` ~ field ~ ` = 
    (cast(VGAarbiterScreenPtr)dixLookupPrivate(&(pScreen).devPrivates, 
    &VGAarbiterScreenKeyRec)).` ~ field ~ `;}`;

enum string PICTURE_EPILOGUE(string field, string wrap) = `{ps.` ~ field ~ ` = &` ~ wrap ~ `;}`;

enum string WRAP_SCREEN_INFO(string x,string y) = `{pScreenPriv.` ~ x ~ ` = pScrn.` ~ x ~ `; pScrn.` ~ x ~ ` = &` ~ y ~ `;}`;

enum string UNWRAP_SCREEN_INFO(string x) = `{pScrn.` ~ x ~ ` = pScreenPriv.` ~ x ~ `;}`;

enum SPRITE_PROLOG = `                                          
    miPointerScreenPtr PointPriv;                               
    VGAarbiterScreenPtr pScreenPriv;                            
    input_lock();                                               
    PointPriv = cast(_MiPointerScreenRec*)dixLookupPrivate(&pScreen.devPrivates,         
                                 miPointerScreenKey);           
    pScreenPriv = cast(_VGAarbiterScreen*)dixLookupPrivate(&(pScreen).devPrivates,     
                                   &VGAarbiterScreenKeyRec);    
    PointPriv.spriteFuncs = pScreenPriv.miSprite;`       
;
enum SPRITE_EPILOG =  `                                 
    pScreenPriv.miSprite = PointPriv.spriteFuncs;     
    PointPriv.spriteFuncs  = &VGAarbiterSpriteFuncs;   
    input_unlock();`;

enum WRAP_SPRITE = `
pScreenPriv.miSprite = PointPriv.spriteFuncs;
    	PointPriv.spriteFuncs  = &VGAarbiterSpriteFuncs; 		
`;

enum UNWRAP_SPRITE = `{PointPriv.spriteFuncs = pScreenPriv.miSprite;}`;

enum string GC_WRAP(string x) = `pGCPriv.wrapOps = (` ~ x ~ `).ops;
    pGCPriv.wrapFuncs = (` ~ x ~ `).funcs; (` ~ x ~ `).ops = &VGAarbiterGCOps;
    (` ~ x ~ `).funcs = &VGAarbiterGCFuncs;`;

enum string GC_UNWRAP(string x) = `VGAarbiterGCPtr pGCPriv = cast(VGAarbiterGCPtr)dixLookupPrivate(&(` ~ x ~ `).devPrivates, &VGAarbiterGCKeyRec);
    (` ~ x ~ `).ops = pGCPriv.wrapOps; (` ~ x ~ `).funcs = pGCPriv.wrapFuncs;`;

pragma(inline, true) void VGAGet(ScreenPtr pScreen)
{
    pci_device_vgaarb_set_target(xf86ScreenToScrn(pScreen).vgaDev);
    pci_device_vgaarb_lock();
}

pragma(inline, true) void VGAPut()
{
    pci_device_vgaarb_unlock();
}

struct _VGAarbiterScreen {
    CreateGCProcPtr CreateGC;
    CloseScreenProcPtr CloseScreen;
    ScreenBlockHandlerProcPtr BlockHandler;
    ScreenWakeupHandlerProcPtr WakeupHandler;
    GetImageProcPtr GetImage;
    GetSpansProcPtr GetSpans;
    SourceValidateProcPtr SourceValidate;
    CopyWindowProcPtr CopyWindow;
    ClearToBackgroundProcPtr ClearToBackground;
    CreatePixmapProcPtr CreatePixmap;
    SaveScreenProcPtr SaveScreen;
    /* Colormap */
    StoreColorsProcPtr StoreColors;
    /* Cursor */
    DisplayCursorProcPtr DisplayCursor;
    RealizeCursorProcPtr RealizeCursor;
    UnrealizeCursorProcPtr UnrealizeCursor;
    RecolorCursorProcPtr RecolorCursor;
    SetCursorPositionProcPtr SetCursorPosition;
    void function(ScrnInfoPtr, int, int) @nogc nothrow AdjustFrame;
    Bool function(ScrnInfoPtr, DisplayModePtr) @nogc nothrow SwitchMode;
    Bool function(ScrnInfoPtr) @nogc nothrow EnterVT;
    void function(ScrnInfoPtr) @nogc nothrow LeaveVT;
    void function(ScrnInfoPtr) @nogc nothrow FreeScreen;
    miPointerSpriteFuncPtr miSprite;
    CompositeProcPtr Composite;
    GlyphsProcPtr Glyphs;
    CompositeRectsProcPtr CompositeRects;
}alias VGAarbiterScreenRec = _VGAarbiterScreen;
alias VGAarbiterScreenPtr = _VGAarbiterScreen*;

struct _VGAarbiterGC {
    const(GCOps)* wrapOps;
    const(GCFuncs)* wrapFuncs;
}alias VGAarbiterGCRec = _VGAarbiterGC;
alias VGAarbiterGCPtr = _VGAarbiterGC*;

/* Screen funcs */
private void VGAarbiterBlockHandler(ScreenPtr pScreen, void* pTimeout);
private void VGAarbiterWakeupHandler(ScreenPtr pScreen, int result);
private Bool VGAarbiterCloseScreen(ScreenPtr pScreen);
private void VGAarbiterGetImage(DrawablePtr pDrawable, int sx, int sy, int w, int h, uint format, c_ulong planemask, char* pdstLine);
private void VGAarbiterGetSpans(DrawablePtr pDrawable, int wMax, DDXPointPtr ppt, int* pwidth, int nspans, char* pdstStart);
private void VGAarbiterSourceValidate(DrawablePtr pDrawable, int x, int y, int width, int height, uint subWindowMode);
private void VGAarbiterCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc);
private void VGAarbiterClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures);
private PixmapPtr VGAarbiterCreatePixmap(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint);
private Bool VGAarbiterCreateGC(GCPtr pGC);
private Bool VGAarbiterSaveScreen(ScreenPtr pScreen, Bool unblank);
private void VGAarbiterStoreColors(ColormapPtr pmap, int ndef, xColorItem* pdefs);
private void VGAarbiterRecolorCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs, Bool displayed);
private Bool VGAarbiterRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor);
private Bool VGAarbiterUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor);
private Bool VGAarbiterDisplayCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor);
private Bool VGAarbiterSetCursorPosition(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, Bool generateEvent);
private void VGAarbiterAdjustFrame(ScrnInfoPtr pScrn, int x, int y);
private Bool VGAarbiterSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode);
private Bool VGAarbiterEnterVT(ScrnInfoPtr pScrn);
private void VGAarbiterLeaveVT(ScrnInfoPtr pScrn);
private void VGAarbiterFreeScreen(ScrnInfoPtr pScrn);

/* GC funcs */
private void VGAarbiterValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDraw);
private void VGAarbiterChangeGC(GCPtr pGC, c_ulong mask);
private void VGAarbiterCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst);
private void VGAarbiterDestroyGC(GCPtr pGC);
private void VGAarbiterChangeClip(GCPtr pGC, int type, void* pvalue, int nrects);
private void VGAarbiterDestroyClip(GCPtr pGC);
private void VGAarbiterCopyClip(GCPtr pgcDst, GCPtr pgcSrc);

/* GC ops */
private void VGAarbiterFillSpans(DrawablePtr pDraw, GCPtr pGC, int nInit, DDXPointPtr pptInit, int* pwidthInit, int fSorted);
private void VGAarbiterSetSpans(DrawablePtr pDraw, GCPtr pGC, char* pcharsrc, DDXPointPtr ppt, int* pwidth, int nspans, int fSorted);
private void VGAarbiterPutImage(DrawablePtr pDraw, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pImage);
private RegionPtr VGAarbiterCopyArea(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty);
private RegionPtr VGAarbiterCopyPlane(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty, c_ulong bitPlane);
private void VGAarbiterPolyPoint(DrawablePtr pDraw, GCPtr pGC, int mode, int npt, xPoint* pptInit);
private void VGAarbiterPolylines(DrawablePtr pDraw, GCPtr pGC, int mode, int npt, DDXPointPtr pptInit);
private void VGAarbiterPolySegment(DrawablePtr pDraw, GCPtr pGC, int nseg, xSegment* pSeg);
private void VGAarbiterPolyRectangle(DrawablePtr pDraw, GCPtr pGC, int nRectsInit, xRectangle* pRectsInit);
private void VGAarbiterPolyArc(DrawablePtr pDraw, GCPtr pGC, int narcs, xArc* parcs);
private void VGAarbiterFillPolygon(DrawablePtr pDraw, GCPtr pGC, int shape, int mode, int count, DDXPointPtr ptsIn);
private void VGAarbiterPolyFillRect(DrawablePtr pDraw, GCPtr pGC, int nrectFill, xRectangle* prectInit);
private void VGAarbiterPolyFillArc(DrawablePtr pDraw, GCPtr pGC, int narcs, xArc* parcs);
private int VGAarbiterPolyText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars);
private int VGAarbiterPolyText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars);
private void VGAarbiterImageText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars);
private void VGAarbiterImageText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars);
private void VGAarbiterImageGlyphBlt(DrawablePtr pDraw, GCPtr pGC, int xInit, int yInit, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);
private void VGAarbiterPolyGlyphBlt(DrawablePtr pDraw, GCPtr pGC, int xInit, int yInit, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);
private void VGAarbiterPushPixels(GCPtr pGC, PixmapPtr pBitMap, DrawablePtr pDraw, int dx, int dy, int xOrg, int yOrg);

/* miSpriteFuncs */
private Bool VGAarbiterSpriteRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur);
private Bool VGAarbiterSpriteUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur);
private void VGAarbiterSpriteSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur, int x, int y);
private void VGAarbiterSpriteMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y);
private Bool VGAarbiterDeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen);
private void VGAarbiterDeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen);

private void VGAarbiterComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height);
private void VGAarbiterGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs);
private void VGAarbiterCompositeRects(CARD8 op, PicturePtr pDst, xRenderColor* color, int nRect, xRectangle* rects);

 /* XSERVER_XFREE86_XF86VGAARBITERPRIV_H */
