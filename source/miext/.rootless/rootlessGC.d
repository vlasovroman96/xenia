module rootlessGC.c;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Graphics Context support for generic rootless X server
 */
/*
 * Copyright (c) 2001 Greg Parker. All Rights Reserved.
 * Copyright (c) 2002-2003 Torrey T. Lyons. All Rights Reserved.
 * Copyright (c) 2002 Apple Computer, Inc. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE ABOVE LISTED COPYRIGHT HOLDER(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name(s) of the above copyright
 * holders shall not be used in advertising or otherwise to promote the sale,
 * use or other dealings in this Software without prior written authorization.
 */

import dix-config;

import stdbool;
import core.stdc.stddef;             /* For NULL */
import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;

import os.mathx_priv;

import mi;
import scrnintstr;
import gcstruct;
import pixmapstr;
import windowstr;
import dixfontstr;
import fb;

import rootlessCommon;

// GC functions










GCFuncs rootlessGCFuncs = {
    RootlessValidateGC,
    RootlessChangeGC,
    RootlessCopyGC,
    RootlessDestroyGC,
    RootlessChangeClip,
    RootlessDestroyClip,
    RootlessCopyClip,
};

// GC operations





















private GCOps rootlessGCOps = {
    RootlessFillSpans,
    RootlessSetSpans,
    RootlessPutImage,
    RootlessCopyArea,
    RootlessCopyPlane,
    RootlessPolyPoint,
    RootlessPolylines,
    RootlessPolySegment,
    RootlessPolyRectangle,
    RootlessPolyArc,
    RootlessFillPolygon,
    RootlessPolyFillRect,
    RootlessPolyFillArc,
    RootlessPolyText8,
    RootlessPolyText16,
    RootlessImageText8,
    RootlessImageText16,
    RootlessImageGlyphBlt,
    RootlessPolyGlyphBlt,
    RootlessPushPixels
};

/*
   If ROOTLESS_PROTECT_ALPHA is set, we have to make sure that the alpha
   channel of the on screen windows is always opaque. fb makes this harder
   than it would otherwise be by noticing that a planemask of 0x00ffffff
   includes all bits when depth==24, and so it "optimizes" the planemask to
   0xffffffff. We work around this by temporarily setting depth=bpp while
   changing the GC.

   So the normal situation (in 32 bit mode) is that the planemask is
   0x00ffffff and thus fb leaves the alpha channel alone. The rootless
   implementation is responsible for setting the alpha channel opaque
   initially.

   Unfortunately drawing with a planemask that doesn't have all bits set
   normally causes fb to fall off its fastest paths when blitting and
   filling.  So we try to recognize when we can relax the planemask back to
   0xffffffff, and do that for the duration of the drawing operation,
   setting the alpha channel in fg/bg pixels to opaque at the same time. We
   can do this when drawing op is GXcopy. We can also do this when copying
   from another window since its alpha channel must also be opaque.

   The three macros below are used to implement this. Drawing ops that can
   potentially have their planemask relaxed look like:

   OP {
       GC_SAVE(gc);
       GCOP_UNWRAP(gc);

       ...

       if (canAccelxxx(..) && otherwise-suitable)
            GC_UNSET_PM(gc, dst);

       gc->funcs->OP(gc, ...);

       GC_RESTORE(gc, dst);
       GCOP_WRAP(gc);
   }

 */

enum string GC_SAVE(string pGC) = `
    c_ulong _save_fg = (` ~ pGC ~ `).fgPixel;	
    c_ulong _save_bg = (` ~ pGC ~ `).bgPixel;	
    c_ulong _save_pm = (` ~ pGC ~ `).planemask;	
    Bool _changed = False;`;

enum string GC_RESTORE(string pGC, string pDraw) = `
    do {							
        if (_changed) {						
            uint depth = (` ~ pDraw ~ `).depth;		
            (` ~ pGC ~ `).fgPixel = _save_fg;				
            (` ~ pGC ~ `).bgPixel = _save_bg;				
            (` ~ pGC ~ `).planemask = _save_pm;			
            (` ~ pDraw ~ `).depth = (` ~ pDraw ~ `).bitsPerPixel;		
            VALIDATE_GC((` ~ pGC ~ `), GCForeground | GCBackground |	
                        GCPlaneMask, (` ~ pDraw ~ `));			
            (` ~ pDraw ~ `).depth = depth;				
        }							
    } while (0)`;

enum string GC_UNSET_PM(string pGC, string pDraw) = `
    do {								
        uint mask = RootlessAlphaMask ((` ~ pDraw ~ `).bitsPerPixel);	
        if (((` ~ pGC ~ `).planemask & mask) != mask) {			
            uint depth = (` ~ pDraw ~ `).depth;			
            (` ~ pGC ~ `).fgPixel |= mask;					
            (` ~ pGC ~ `).bgPixel |= mask;					
            (` ~ pGC ~ `).planemask |= mask;					
            (` ~ pDraw ~ `).depth = (` ~ pDraw ~ `).bitsPerPixel;			
            VALIDATE_GC((` ~ pGC ~ `), GCForeground |				
                        GCBackground | GCPlaneMask, (` ~ pDraw ~ `));		
            (` ~ pDraw ~ `).depth = depth;					
            _changed = True;						
        }								
    } while (0)`;

enum string VALIDATE_GC(string pGC, string changes, string pDrawable) = `
    do {								
        (` ~ pGC ~ `).funcs.ValidateGC((` ~ pGC ~ `), (` ~ changes ~ `), (` ~ pDrawable ~ `));		
        if ((cast(WindowPtr) (` ~ pDrawable ~ `)).viewable) {			
            gcrec.originalOps = (` ~ pGC ~ `).ops;				
        }								
    } while(0)`;

private RootlessWindowRec* canAccelBlit(DrawablePtr pDraw, GCPtr pGC)
{
    WindowPtr pTop = void;
    RootlessWindowRec* winRec = void;
    uint pm = void;

    if (pGC.alu != GXcopy)
        return null;

    if (pDraw.type != DRAWABLE_WINDOW)
        return null;

    pm = ~RootlessAlphaMask(pDraw.bitsPerPixel);
    if ((pGC.planemask & pm) != pm)
        return null;

    pTop = TopLevelParent(cast(WindowPtr) pDraw);
    if (pTop is null)
        return null;

    winRec = WINREC(pTop);
    if (winRec is null)
        return null;

    return winRec;
}

pragma(inline, true) private RootlessWindowRec* canAccelFill(DrawablePtr pDraw, GCPtr pGC)
{
    if (pGC.fillStyle != FillSolid)
        return null;

    return canAccelBlit(pDraw, pGC);
}

/*
 * Screen function to create a graphics context
 */
Bool RootlessCreateGC(GCPtr pGC)
{
    RootlessGCRec* gcrec = void;
    RootlessScreenRec* s = void;
    bool result = void;

    SCREEN_UNWRAP(pGC.pScreen, CreateGC);
    s = SCREENREC(pGC.pScreen);
    result = s.CreateGC(pGC);

    gcrec = cast(RootlessGCRec*)
        dixLookupPrivate(&pGC.devPrivates, rootlessGCPrivateKey);
    gcrec.originalOps = null;  // don't wrap ops yet
    gcrec.originalFuncs = pGC.funcs;
    pGC.funcs = &rootlessGCFuncs;

    SCREEN_WRAP(pGC.pScreen, CreateGC);
    return result;
}

/*
 * GC funcs
 *
 * These wrap lower level GC funcs.
 * ValidateGC wraps the GC ops iff dest is viewable.
 * All the others just unwrap and call.
 */

// GCFUNC_UNRAP assumes funcs have been wrapped and
// does not assume ops have been wrapped
enum string GCFUNC_UNWRAP(string pGC) = `
    RootlessGCRec* gcrec = cast(RootlessGCRec*) 
	dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, rootlessGCPrivateKey); 
    (` ~ pGC ~ `).funcs = gcrec.originalFuncs; 
    if (gcrec.originalOps) { 
        (` ~ pGC ~ `).ops = gcrec.originalOps; 
}`;

enum string GCFUNC_WRAP(string pGC) = `
    gcrec.originalFuncs = (` ~ pGC ~ `).funcs; 
    (` ~ pGC ~ `).funcs = &rootlessGCFuncs; 
    if (gcrec.originalOps) { 
        gcrec.originalOps = (` ~ pGC ~ `).ops; 
        (` ~ pGC ~ `).ops = &rootlessGCOps; 
}`;

private void RootlessValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDrawable)
{
    mixin(GCFUNC_UNWRAP!(`pGC`));

    gcrec.originalOps = null;

    if (pDrawable.type == DRAWABLE_WINDOW) {
version (ROOTLESS_PROTECT_ALPHA) {
        uint depth = pDrawable.depth;

        // We force a planemask so fb doesn't overwrite the alpha channel.
        // Left to its own devices, fb will optimize away the planemask.
        pDrawable.depth = pDrawable.bitsPerPixel;
        pGC.planemask &= ~RootlessAlphaMask(pDrawable.bitsPerPixel);
        mixin(VALIDATE_GC!(`pGC`, `changes | GCPlaneMask`, `pDrawable`));
        pDrawable.depth = depth;
} else {
        mixin(VALIDATE_GC!(`pGC`, `changes`, `pDrawable`));
}
    }
    else {
        pGC.funcs.ValidateGC(pGC, changes, pDrawable);
    }

    mixin(GCFUNC_WRAP!(`pGC`));
}

private void RootlessChangeGC(GCPtr pGC, c_ulong mask)
{
    mixin(GCFUNC_UNWRAP!(`pGC`));
    pGC.funcs.ChangeGC(pGC, mask);
    mixin(GCFUNC_WRAP!(`pGC`));
}

private void RootlessCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst)
{
    mixin(GCFUNC_UNWRAP!(`pGCDst`));
    pGCDst.funcs.CopyGC(pGCSrc, mask, pGCDst);
    mixin(GCFUNC_WRAP!(`pGCDst`));
}

private void RootlessDestroyGC(GCPtr pGC)
{
    mixin(GCFUNC_UNWRAP!(`pGC`));
    pGC.funcs.DestroyGC(pGC);
    mixin(GCFUNC_WRAP!(`pGC`));
}

private void RootlessChangeClip(GCPtr pGC, int type, void* pvalue, int nrects)
{
    mixin(GCFUNC_UNWRAP!(`pGC`));
    pGC.funcs.ChangeClip(pGC, type, pvalue, nrects);
    mixin(GCFUNC_WRAP!(`pGC`));
}

private void RootlessDestroyClip(GCPtr pGC)
{
    mixin(GCFUNC_UNWRAP!(`pGC`));
    pGC.funcs.DestroyClip(pGC);
    mixin(GCFUNC_WRAP!(`pGC`));
}

private void RootlessCopyClip(GCPtr pgcDst, GCPtr pgcSrc)
{
    mixin(GCFUNC_UNWRAP!(`pgcDst`));
    pgcDst.funcs.CopyClip(pgcDst, pgcSrc);
    mixin(GCFUNC_WRAP!(`pgcDst`));
}

/*
 * GC ops
 *
 * We can't use shadowfb because shadowfb assumes one pixmap
 * and our root window is a special case.
 * However, much of this code is copied from shadowfb.
 */

// assumes both funcs and ops are wrapped
enum string GCOP_UNWRAP(string pGC) = `
    RootlessGCRec* gcrec = cast(RootlessGCRec*) 
        dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, rootlessGCPrivateKey); 
    const(GCFuncs)* saveFuncs = (` ~ pGC ~ `).funcs; 
    (` ~ pGC ~ `).funcs = gcrec.originalFuncs; 
    (` ~ pGC ~ `).ops = gcrec.originalOps;`;

enum string GCOP_WRAP(string pGC) = `
    gcrec.originalOps = (` ~ pGC ~ `).ops; 
    (` ~ pGC ~ `).funcs = saveFuncs; 
    (` ~ pGC ~ `).ops = &rootlessGCOps;`;

private void RootlessFillSpans(DrawablePtr dst, GCPtr pGC, int nInit, xPoint* pptInit, int* pwidthInit, int sorted)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("fill spans start ");

    if (nInit <= 0) {
        pGC.ops.FillSpans(dst, pGC, nInit, pptInit, pwidthInit, sorted);
    }
    else {
        xPoint* ppt = pptInit;
        int* pwidth = pwidthInit;
        int i = nInit;
        BoxRec box = void;

        box.x1 = ppt.x;
        box.x2 = box.x1 + *pwidth;
        box.y2 = box.y1 = ppt.y;

        while (--i) {
            ppt++;
            pwidth++;
            if (box.x1 > ppt.x)
                box.x1 = ppt.x;
            if (box.x2 < (ppt.x + *pwidth))
                box.x2 = ppt.x + *pwidth;
            if (box.y1 > ppt.y)
                box.y1 = ppt.y;
            else if (box.y2 < ppt.y)
                box.y2 = ppt.y;
        }

        box.y2++;

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.FillSpans(dst, pGC, nInit, pptInit, pwidthInit, sorted);

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("fill spans end\n");
}

private void RootlessSetSpans(DrawablePtr dst, GCPtr pGC, char* pSrc, xPoint* pptInit, int* pwidthInit, int nspans, int sorted)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("set spans start ");

    if (nspans <= 0) {
        pGC.ops.SetSpans(dst, pGC, pSrc, pptInit, pwidthInit, nspans, sorted);
    }
    else {
        xPoint* ppt = pptInit;
        int* pwidth = pwidthInit;
        int i = nspans;
        BoxRec box = void;

        box.x1 = ppt.x;
        box.x2 = box.x1 + *pwidth;
        box.y2 = box.y1 = ppt.y;

        while (--i) {
            ppt++;
            pwidth++;
            if (box.x1 > ppt.x)
                box.x1 = ppt.x;
            if (box.x2 < (ppt.x + *pwidth))
                box.x2 = ppt.x + *pwidth;
            if (box.y1 > ppt.y)
                box.y1 = ppt.y;
            else if (box.y2 < ppt.y)
                box.y2 = ppt.y;
        }

        box.y2++;

        RootlessStartDrawing(cast(WindowPtr) dst);
        pGC.ops.SetSpans(dst, pGC, pSrc, pptInit, pwidthInit, nspans, sorted);

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("set spans end\n");
}

private void RootlessPutImage(DrawablePtr dst, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pBits)
{
    BoxRec box = void;

    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("put image start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PutImage(dst, pGC, depth, x, y, w, h, leftPad, format, pBits);

    box.x1 = x + dst.x;
    box.x2 = box.x1 + w;
    box.y1 = y + dst.y;
    box.y2 = box.y1 + h;

    TRIM_BOX(box, pGC);
    if (BOX_NOT_EMPTY(box))
        RootlessDamageBox(cast(WindowPtr) dst, &box);

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("put image end\n");
}

/* changed area is *dest* rect */
private RegionPtr RootlessCopyArea(DrawablePtr pSrc, DrawablePtr dst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty)
{
    RegionPtr result = void;
    BoxRec box = void;

    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));

    RL_DEBUG_MSG("copy area start (src %p, dst %p)", pSrc, dst);

    if (pSrc.type == DRAWABLE_WINDOW && IsFramedWindow(cast(WindowPtr) pSrc)) {
        /* If both source and dest are windows, and we're doing
           a simple copy operation, we can remove the alpha-protecting
           planemask (since source has opaque alpha as well) */

        if (canAccelBlit(pSrc, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        RootlessStartDrawing(cast(WindowPtr) pSrc);
    }
    RootlessStartDrawing(cast(WindowPtr) dst);
    result = pGC.ops.CopyArea(pSrc, dst, pGC, srcx, srcy, w, h, dstx, dsty);

    box.x1 = dstx + dst.x;
    box.x2 = box.x1 + w;
    box.y1 = dsty + dst.y;
    box.y2 = box.y1 + h;

    TRIM_BOX(box, pGC);
    if (BOX_NOT_EMPTY(box))
        RootlessDamageBox(cast(WindowPtr) dst, &box);

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("copy area end\n");
    return result;
}

/* changed area is *dest* rect */
private RegionPtr RootlessCopyPlane(DrawablePtr pSrc, DrawablePtr dst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty, c_ulong plane)
{
    RegionPtr result = void;
    BoxRec box = void;

    mixin(GCOP_UNWRAP!(`pGC`));

    RL_DEBUG_MSG("copy plane start ");

    if (pSrc.type == DRAWABLE_WINDOW && IsFramedWindow(cast(WindowPtr) pSrc)) {
        RootlessStartDrawing(cast(WindowPtr) pSrc);
    }
    RootlessStartDrawing(cast(WindowPtr) dst);
    result = pGC.ops.CopyPlane(pSrc, dst, pGC, srcx, srcy, w, h,
                                 dstx, dsty, plane);

    box.x1 = dstx + dst.x;
    box.x2 = box.x1 + w;
    box.y1 = dsty + dst.y;
    box.y2 = box.y1 + h;

    TRIM_BOX(box, pGC);
    if (BOX_NOT_EMPTY(box))
        RootlessDamageBox(cast(WindowPtr) dst, &box);

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("copy plane end\n");
    return result;
}

// Options for size of changed area:
//  0 = box per point
//  1 = big box around all points
//  2 = accumulate point in 20 pixel radius
enum ROOTLESS_CHANGED_AREA = 1;
enum string abs(string a) = `((` ~ a ~ `) > 0 ? (` ~ a ~ `) : -(` ~ a ~ `))`;

/* changed area is box around all points */
private void RootlessPolyPoint(DrawablePtr dst, GCPtr pGC, int mode, int npt, xPoint* pptInit)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("polypoint start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PolyPoint(dst, pGC, mode, npt, pptInit);

    if (npt > 0) {
static if (ROOTLESS_CHANGED_AREA==0) {
        // box per point
        BoxRec box = void;

        while (npt) {
            box.x1 = pptInit.x;
            box.y1 = pptInit.y;
            box.x2 = box.x1 + 1;
            box.y2 = box.y1 + 1;

            TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
            if (BOX_NOT_EMPTY(box))
                RootlessDamageBox(cast(WindowPtr) dst, &box);

            npt--;
            pptInit++;
        }

} else static if (ROOTLESS_CHANGED_AREA==1) {
        // one big box
        BoxRec box = void;

        box.x2 = box.x1 = pptInit.x;
        box.y2 = box.y1 = pptInit.y;
        while (--npt) {
            pptInit++;
            if (box.x1 > pptInit.x)
                box.x1 = pptInit.x;
            else if (box.x2 < pptInit.x)
                box.x2 = pptInit.x;
            if (box.y1 > pptInit.y)
                box.y1 = pptInit.y;
            else if (box.y2 < pptInit.y)
                box.y2 = pptInit.y;
        }

        box.x2++;
        box.y2++;

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);

} else static if (ROOTLESS_CHANGED_AREA==2) {
        // clever(?) method: accumulate point in 20-pixel radius
        BoxRec box = void;
        int firstx = void, firsty = void;

        box.x2 = box.x1 = firstx = pptInit.x;
        box.y2 = box.y1 = firsty = pptInit.y;
        while (--npt) {
            pptInit++;
            if (mixin(abs!(`pptInit.x - firstx`)) > 20 || mixin(abs!(`pptInit.y - firsty`)) > 20) {
                box.x2++;
                box.y2++;
                TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
                if (BOX_NOT_EMPTY(box))
                    RootlessDamageBox(cast(WindowPtr) dst, &box);
                box.x2 = box.x1 = firstx = pptInit.x;
                box.y2 = box.y1 = firsty = pptInit.y;
            }
            else {
                if (box.x1 > pptInit.x)
                    box.x1 = pptInit.x;
                else if (box.x2 < pptInit.x)
                    box.x2 = pptInit.x;
                if (box.y1 > pptInit.y)
                    box.y1 = pptInit.y;
                else if (box.y2 < pptInit.y)
                    box.y2 = pptInit.y;
            }
        }
        box.x2++;
        box.y2++;
        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
}                          /* ROOTLESS_CHANGED_AREA */
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("polypoint end\n");
}

/* changed area is box around each line */
private void RootlessPolylines(DrawablePtr dst, GCPtr pGC, int mode, int npt, xPoint* pptInit)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("poly lines start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.Polylines(dst, pGC, mode, npt, pptInit);

    if (npt > 0) {
        BoxRec box = void;
        int extra = pGC.lineWidth >> 1;

        box.x2 = box.x1 = pptInit.x;
        box.y2 = box.y1 = pptInit.y;

        if (npt > 1) {
            if (pGC.joinStyle == JoinMiter)
                extra = 6 * pGC.lineWidth;
            else if (pGC.capStyle == CapProjecting)
                extra = pGC.lineWidth;
        }

        if (mode == CoordModePrevious) {
            int x = box.x1;
            int y = box.y1;

            while (--npt) {
                pptInit++;
                x += pptInit.x;
                y += pptInit.y;
                if (box.x1 > x)
                    box.x1 = x;
                else if (box.x2 < x)
                    box.x2 = x;
                if (box.y1 > y)
                    box.y1 = y;
                else if (box.y2 < y)
                    box.y2 = y;
            }
        }
        else {
            while (--npt) {
                pptInit++;
                if (box.x1 > pptInit.x)
                    box.x1 = pptInit.x;
                else if (box.x2 < pptInit.x)
                    box.x2 = pptInit.x;
                if (box.y1 > pptInit.y)
                    box.y1 = pptInit.y;
                else if (box.y2 < pptInit.y)
                    box.y2 = pptInit.y;
            }
        }

        box.x2++;
        box.y2++;

        if (extra) {
            box.x1 -= extra;
            box.x2 += extra;
            box.y1 -= extra;
            box.y2 += extra;
        }

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("poly lines end\n");
}

/* changed area is box around each line segment */
private void RootlessPolySegment(DrawablePtr dst, GCPtr pGC, int nseg, xSegment* pSeg)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("poly segment start (dst %p)", dst);

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PolySegment(dst, pGC, nseg, pSeg);

    if (nseg > 0) {
        BoxRec box = void;
        int extra = pGC.lineWidth;

        if (pGC.capStyle != CapProjecting)
            extra >>= 1;

        if (pSeg.x2 > pSeg.x1) {
            box.x1 = pSeg.x1;
            box.x2 = pSeg.x2;
        }
        else {
            box.x2 = pSeg.x1;
            box.x1 = pSeg.x2;
        }

        if (pSeg.y2 > pSeg.y1) {
            box.y1 = pSeg.y1;
            box.y2 = pSeg.y2;
        }
        else {
            box.y2 = pSeg.y1;
            box.y1 = pSeg.y2;
        }

        while (--nseg) {
            pSeg++;
            if (pSeg.x2 > pSeg.x1) {
                if (pSeg.x1 < box.x1)
                    box.x1 = pSeg.x1;
                if (pSeg.x2 > box.x2)
                    box.x2 = pSeg.x2;
            }
            else {
                if (pSeg.x2 < box.x1)
                    box.x1 = pSeg.x2;
                if (pSeg.x1 > box.x2)
                    box.x2 = pSeg.x1;
            }
            if (pSeg.y2 > pSeg.y1) {
                if (pSeg.y1 < box.y1)
                    box.y1 = pSeg.y1;
                if (pSeg.y2 > box.y2)
                    box.y2 = pSeg.y2;
            }
            else {
                if (pSeg.y2 < box.y1)
                    box.y1 = pSeg.y2;
                if (pSeg.y1 > box.y2)
                    box.y2 = pSeg.y1;
            }
        }

        box.x2++;
        box.y2++;

        if (extra) {
            box.x1 -= extra;
            box.x2 += extra;
            box.y1 -= extra;
            box.y2 += extra;
        }

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("poly segment end\n");
}

/* changed area is box around each line (not entire rects) */
private void RootlessPolyRectangle(DrawablePtr dst, GCPtr pGC, int nRects, xRectangle* pRects)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("poly rectangle start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PolyRectangle(dst, pGC, nRects, pRects);

    if (nRects > 0) {
        BoxRec box = void;
        int offset1 = void, offset2 = void, offset3 = void;

        offset2 = pGC.lineWidth;
        if (!offset2)
            offset2 = 1;
        offset1 = offset2 >> 1;
        offset3 = offset2 - offset1;

        while (nRects--) {
            box.x1 = pRects.x - offset1;
            box.y1 = pRects.y - offset1;
            box.x2 = box.x1 + pRects.width + offset2;
            box.y2 = box.y1 + offset2;
            TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
            if (BOX_NOT_EMPTY(box))
                RootlessDamageBox(cast(WindowPtr) dst, &box);

            box.x1 = pRects.x - offset1;
            box.y1 = pRects.y + offset3;
            box.x2 = box.x1 + offset2;
            box.y2 = box.y1 + pRects.height - offset2;
            TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
            if (BOX_NOT_EMPTY(box))
                RootlessDamageBox(cast(WindowPtr) dst, &box);

            box.x1 = pRects.x + pRects.width - offset1;
            box.y1 = pRects.y + offset3;
            box.x2 = box.x1 + offset2;
            box.y2 = box.y1 + pRects.height - offset2;
            TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
            if (BOX_NOT_EMPTY(box))
                RootlessDamageBox(cast(WindowPtr) dst, &box);

            box.x1 = pRects.x - offset1;
            box.y1 = pRects.y + pRects.height - offset1;
            box.x2 = box.x1 + pRects.width + offset2;
            box.y2 = box.y1 + offset2;
            TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
            if (BOX_NOT_EMPTY(box))
                RootlessDamageBox(cast(WindowPtr) dst, &box);

            pRects++;
        }
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("poly rectangle end\n");
}

/* changed area is box around each arc (assumes all arcs are 360 degrees) */
private void RootlessPolyArc(DrawablePtr dst, GCPtr pGC, int narcs, xArc* parcs)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("poly arc start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PolyArc(dst, pGC, narcs, parcs);

    if (narcs > 0) {
        int extra = pGC.lineWidth >> 1;
        BoxRec box = void;

        box.x1 = parcs.x;
        box.x2 = box.x1 + parcs.width;
        box.y1 = parcs.y;
        box.y2 = box.y1 + parcs.height;

        /* should I break these up instead ? */

        while (--narcs) {
            parcs++;
            if (box.x1 > parcs.x)
                box.x1 = parcs.x;
            if (box.x2 < (parcs.x + parcs.width))
                box.x2 = parcs.x + parcs.width;
            if (box.y1 > parcs.y)
                box.y1 = parcs.y;
            if (box.y2 < (parcs.y + parcs.height))
                box.y2 = parcs.y + parcs.height;
        }

        if (extra) {
            box.x1 -= extra;
            box.x2 += extra;
            box.y1 -= extra;
            box.y2 += extra;
        }

        box.x2++;
        box.y2++;

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("poly arc end\n");
}

/* changed area is box around each poly */
private void RootlessFillPolygon(DrawablePtr dst, GCPtr pGC, int shape, int mode, int count, xPoint* pptInit)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("fill poly start (dst %p, fillStyle 0x%x)", dst,
                 pGC.fillStyle);

    if (count <= 2) {
        pGC.ops.FillPolygon(dst, pGC, shape, mode, count, pptInit);
    }
    else {
        xPoint* ppt = pptInit;
        int i = count;
        BoxRec box = void;

        box.x2 = box.x1 = ppt.x;
        box.y2 = box.y1 = ppt.y;

        if (mode != CoordModeOrigin) {
            int x = box.x1;
            int y = box.y1;

            while (--i) {
                ppt++;
                x += ppt.x;
                y += ppt.y;
                if (box.x1 > x)
                    box.x1 = x;
                else if (box.x2 < x)
                    box.x2 = x;
                if (box.y1 > y)
                    box.y1 = y;
                else if (box.y2 < y)
                    box.y2 = y;
            }
        }
        else {
            while (--i) {
                ppt++;
                if (box.x1 > ppt.x)
                    box.x1 = ppt.x;
                else if (box.x2 < ppt.x)
                    box.x2 = ppt.x;
                if (box.y1 > ppt.y)
                    box.y1 = ppt.y;
                else if (box.y2 < ppt.y)
                    box.y2 = ppt.y;
            }
        }

        box.x2++;
        box.y2++;

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.FillPolygon(dst, pGC, shape, mode, count, pptInit);

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("fill poly end\n");
}

/* changed area is the rects */
private void RootlessPolyFillRect(DrawablePtr dst, GCPtr pGC, int nRectsInit, xRectangle* pRectsInit)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("fill rect start (dst %p, fillStyle 0x%x)", dst,
                 pGC.fillStyle);

    if (nRectsInit <= 0) {
        pGC.ops.PolyFillRect(dst, pGC, nRectsInit, pRectsInit);
    }
    else {
        BoxRec box = void;
        xRectangle* pRects = pRectsInit;
        int nRects = nRectsInit;

        box.x1 = pRects.x;
        box.x2 = box.x1 + pRects.width;
        box.y1 = pRects.y;
        box.y2 = box.y1 + pRects.height;

        while (--nRects) {
            pRects++;
            if (box.x1 > pRects.x)
                box.x1 = pRects.x;
            if (box.x2 < (pRects.x + pRects.width))
                box.x2 = pRects.x + pRects.width;
            if (box.y1 > pRects.y)
                box.y1 = pRects.y;
            if (box.y2 < (pRects.y + pRects.height))
                box.y2 = pRects.y + pRects.height;
        }

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.PolyFillRect(dst, pGC, nRectsInit, pRectsInit);

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("fill rect end\n");
}

/* changed area is box around each arc (assuming arcs are all 360 degrees) */
private void RootlessPolyFillArc(DrawablePtr dst, GCPtr pGC, int narcsInit, xArc* parcsInit)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("fill arc start ");

    if (narcsInit > 0) {
        BoxRec box = void;
        int narcs = narcsInit;
        xArc* parcs = parcsInit;

        box.x1 = parcs.x;
        box.x2 = box.x1 + parcs.width;
        box.y1 = parcs.y;
        box.y2 = box.y1 + parcs.height;

        /* should I break these up instead ? */

        while (--narcs) {
            parcs++;
            if (box.x1 > parcs.x)
                box.x1 = parcs.x;
            if (box.x2 < (parcs.x + parcs.width))
                box.x2 = parcs.x + parcs.width;
            if (box.y1 > parcs.y)
                box.y1 = parcs.y;
            if (box.y2 < (parcs.y + parcs.height))
                box.y2 = parcs.y + parcs.height;
        }

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.PolyFillArc(dst, pGC, narcsInit, parcsInit);

        TRIM_AND_TRANSLATE_BOX(box, dst, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }
    else {
        pGC.ops.PolyFillArc(dst, pGC, narcsInit, parcsInit);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("fill arc end\n");
}

private void RootlessImageText8(DrawablePtr dst, GCPtr pGC, int x, int y, int count, char* chars)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("imagetext8 start ");

    if (count > 0) {
        int top = void, bot = void, Min = void, Max = void;
        BoxRec box = void;

        top = MAX(FONTMAXBOUNDS(pGC.font, ascent), FONTASCENT(pGC.font));
        bot = MAX(FONTMAXBOUNDS(pGC.font, descent), FONTDESCENT(pGC.font));

        Min = count * FONTMINBOUNDS(pGC.font, characterWidth);
        if (Min > 0)
            Min = 0;
        Max = count * FONTMAXBOUNDS(pGC.font, characterWidth);
        if (Max < 0)
            Max = 0;

        /* ugh */
        box.x1 = dst.x + x + Min + FONTMINBOUNDS(pGC.font, leftSideBearing);
        box.x2 = dst.x + x + Max + FONTMAXBOUNDS(pGC.font, rightSideBearing);

        box.y1 = dst.y + y - top;
        box.y2 = dst.y + y + bot;

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.ImageText8(dst, pGC, x, y, count, chars);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }
    else {
        pGC.ops.ImageText8(dst, pGC, x, y, count, chars);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("imagetext8 end\n");
}

private int RootlessPolyText8(DrawablePtr dst, GCPtr pGC, int x, int y, int count, char* chars)
{
    int width = void;                  // the result, sorta

    mixin(GCOP_UNWRAP!(`pGC`));

    RL_DEBUG_MSG("polytext8 start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    width = pGC.ops.PolyText8(dst, pGC, x, y, count, chars);
    width -= x;

    if (width > 0) {
        BoxRec box = void;

        /* ugh */
        box.x1 = dst.x + x + FONTMINBOUNDS(pGC.font, leftSideBearing);
        box.x2 = dst.x + x + FONTMAXBOUNDS(pGC.font, rightSideBearing);

        if (count > 1) {
            box.x2 += width;
        }

        box.y1 = dst.y + y - FONTMAXBOUNDS(pGC.font, ascent);
        box.y2 = dst.y + y + FONTMAXBOUNDS(pGC.font, descent);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("polytext8 end\n");
    return width + x;
}

private void RootlessImageText16(DrawablePtr dst, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("imagetext16 start ");

    if (count > 0) {
        int top = void, bot = void, Min = void, Max = void;
        BoxRec box = void;

        top = MAX(FONTMAXBOUNDS(pGC.font, ascent), FONTASCENT(pGC.font));
        bot = MAX(FONTMAXBOUNDS(pGC.font, descent), FONTDESCENT(pGC.font));

        Min = count * FONTMINBOUNDS(pGC.font, characterWidth);
        if (Min > 0)
            Min = 0;
        Max = count * FONTMAXBOUNDS(pGC.font, characterWidth);
        if (Max < 0)
            Max = 0;

        /* ugh */
        box.x1 = dst.x + x + Min + FONTMINBOUNDS(pGC.font, leftSideBearing);
        box.x2 = dst.x + x + Max + FONTMAXBOUNDS(pGC.font, rightSideBearing);

        box.y1 = dst.y + y - top;
        box.y2 = dst.y + y + bot;

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.ImageText16(dst, pGC, x, y, count, chars);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }
    else {
        pGC.ops.ImageText16(dst, pGC, x, y, count, chars);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("imagetext16 end\n");
}

private int RootlessPolyText16(DrawablePtr dst, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    int width = void;                  // the result, sorta

    mixin(GCOP_UNWRAP!(`pGC`));

    RL_DEBUG_MSG("polytext16 start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    width = pGC.ops.PolyText16(dst, pGC, x, y, count, chars);
    width -= x;

    if (width > 0) {
        BoxRec box = void;

        /* ugh */
        box.x1 = dst.x + x + FONTMINBOUNDS(pGC.font, leftSideBearing);
        box.x2 = dst.x + x + FONTMAXBOUNDS(pGC.font, rightSideBearing);

        if (count > 1) {
            box.x2 += width;
        }

        box.y1 = dst.y + y - FONTMAXBOUNDS(pGC.font, ascent);
        box.y2 = dst.y + y + FONTMAXBOUNDS(pGC.font, descent);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("polytext16 end\n");
    return width + x;
}

private void RootlessImageGlyphBlt(DrawablePtr dst, GCPtr pGC, int x, int y, uint nglyphInit, CharInfoPtr* ppciInit, void* unused)
{
    mixin(GC_SAVE!(`pGC`));
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("imageglyph start ");

    if (nglyphInit > 0) {
        int top = void, bot = void, width = 0;
        BoxRec box = void;
        uint nglyph = nglyphInit;
        CharInfoPtr* ppci = ppciInit;

        top = MAX(FONTMAXBOUNDS(pGC.font, ascent), FONTASCENT(pGC.font));
        bot = MAX(FONTMAXBOUNDS(pGC.font, descent), FONTDESCENT(pGC.font));

        box.x1 = ppci[0].metrics.leftSideBearing;
        if (box.x1 > 0)
            box.x1 = 0;
        box.x2 = ppci[nglyph - 1].metrics.rightSideBearing -
            ppci[nglyph - 1].metrics.characterWidth;
        if (box.x2 < 0)
            box.x2 = 0;

        box.x2 += dst.x + x;
        box.x1 += dst.x + x;

        while (nglyph--) {
            width += (*ppci).metrics.characterWidth;
            ppci++;
        }

        if (width > 0)
            box.x2 += width;
        else
            box.x1 += width;

        box.y1 = dst.y + y - top;
        box.y2 = dst.y + y + bot;

        RootlessStartDrawing(cast(WindowPtr) dst);

        if (canAccelFill(dst, pGC)) {
            mixin(GC_UNSET_PM!(`pGC`, `dst`));
        }

        pGC.ops.ImageGlyphBlt(dst, pGC, x, y, nglyphInit, ppciInit, unused);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }
    else {
        pGC.ops.ImageGlyphBlt(dst, pGC, x, y, nglyphInit, ppciInit, unused);
    }

    mixin(GC_RESTORE!(`pGC`, `dst`));
    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("imageglyph end\n");
}

private void RootlessPolyGlyphBlt(DrawablePtr dst, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("polyglyph start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PolyGlyphBlt(dst, pGC, x, y, nglyph, ppci, pglyphBase);

    if (nglyph > 0) {
        BoxRec box = void;

        /* ugh */
        box.x1 = dst.x + x + ppci[0].metrics.leftSideBearing;
        box.x2 = dst.x + x + ppci[nglyph - 1].metrics.rightSideBearing;

        if (nglyph > 1) {
            int width = 0;

            while (--nglyph) {
                width += (*ppci).metrics.characterWidth;
                ppci++;
            }

            if (width > 0)
                box.x2 += width;
            else
                box.x1 += width;
        }

        box.y1 = dst.y + y - FONTMAXBOUNDS(pGC.font, ascent);
        box.y2 = dst.y + y + FONTMAXBOUNDS(pGC.font, descent);

        TRIM_BOX(box, pGC);
        if (BOX_NOT_EMPTY(box))
            RootlessDamageBox(cast(WindowPtr) dst, &box);
    }

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("polyglyph end\n");
}

/* changed area is in dest */
private void RootlessPushPixels(GCPtr pGC, PixmapPtr pBitMap, DrawablePtr dst, int dx, int dy, int xOrg, int yOrg)
{
    BoxRec box = void;

    mixin(GCOP_UNWRAP!(`pGC`));
    RL_DEBUG_MSG("push pixels start ");

    RootlessStartDrawing(cast(WindowPtr) dst);
    pGC.ops.PushPixels(pGC, pBitMap, dst, dx, dy, xOrg, yOrg);

    box.x1 = xOrg + dst.x;
    box.x2 = box.x1 + dx;
    box.y1 = yOrg + dst.y;
    box.y2 = box.y1 + dy;

    TRIM_BOX(box, pGC);
    if (BOX_NOT_EMPTY(box))
        RootlessDamageBox(cast(WindowPtr) dst, &box);

    mixin(GCOP_WRAP!(`pGC`));
    RL_DEBUG_MSG("push pixels end\n");
}
