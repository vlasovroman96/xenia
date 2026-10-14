module miext.damage.damage_;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2003 Keith Packard
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

import core.stdc.stdlib;

import dix.screen_hooks_priv;
import include.mipict;
import os.osdep;

import    x11.X;
import    include.scrnintstr;
import    include.windowstr;
import    externs.X11.fonts.font;
import    include.dixfontstr;
import    externs.X11.fonts.fontstruct;
import    externs.X11.fonts.libxfont2;
import    include.mi;
import    include.regionstr;
import    dix.globals;
import    include.gcstruct;
import    dix.damage;
import    dix.damage;
import    render.glyphstr_priv;
import render.mipict;
import externs.attrs;
import Xext.xf86bigfont;
import dix.screen_hooks;
// import miext.rootless.rootlessCommon;


enum string wrap(string priv, string real_, string mem, string func) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ func ~ `; 
}`;

enum string unwrap(string priv, string real_, string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

enum string BOX_SAME(string a,string b) = `
    ((` ~ a ~ `).x1 == (` ~ b ~ `).x1 && 
     (` ~ a ~ `).y1 == (` ~ b ~ `).y1 && 
     (` ~ a ~ `).x2 == (` ~ b ~ `).x2 && 
     (` ~ a ~ `).y2 == (` ~ b ~ `).y2)`;

enum DAMAGE_VALIDATE_ENABLE = 0;
enum DAMAGE_DEBUG_ENABLE = 0;
static if (DAMAGE_DEBUG_ENABLE) {
enum string DAMAGE_DEBUG(string x) = `ErrorF x = void;`;
} else {
//#define DAMAGE_DEBUG(x)
}

enum string getPixmapDamageRef(string pPixmap) = `(cast(DamagePtr*) 
    dixLookupPrivateAddr(&(` ~ pPixmap ~ `).devPrivates, damagePixPrivateKey))`;

enum string pixmapDamage(string pPixmap) = `damagePixPriv(` ~ pPixmap ~ `)`;

private DevPrivateKeyRec damageScrPrivateKeyRec;

enum damageScrPrivateKey = (&damageScrPrivateKeyRec);
private DevPrivateKeyRec damagePixPrivateKeyRec;

enum damagePixPrivateKey = (&damagePixPrivateKeyRec);
private DevPrivateKeyRec damageGCPrivateKeyRec;

enum damageGCPrivateKey = (&damageGCPrivateKeyRec);
private DevPrivateKeyRec damageWinPrivateKeyRec;

enum damageWinPrivateKey = (&damageWinPrivateKeyRec);

private DamagePtr* getDrawableDamageRef(DrawablePtr pDrawable)
{
    PixmapPtr pPixmap = void;

    if (mixin(WindowDrawable!("pDrawable.type"))) {
        ScreenPtr pScreen = pDrawable.pScreen;

        pPixmap = null;
        bool cond = pScreen.GetWindowPixmap !is null;
// static if(ROOTLESS_WORKAROUND) {
        // cond = cond && (cast(WindowPtr) pDrawable).viewable;
// }

        if (cond)
            pPixmap = (*pScreen.GetWindowPixmap) (cast(WindowPtr) pDrawable);

        if (!pPixmap) {
            mixin(damageScrPriv!("pScreen"));

            return &pScrPriv.pScreenDamage;
        }
    }
    else
        pPixmap = cast(PixmapPtr) pDrawable;
    return mixin(getPixmapDamageRef!(`pPixmap`));
}

enum string getDrawableDamage(string pDrawable) = `(*getDrawableDamageRef (` ~ pDrawable ~ `))`;
enum string getWindowDamage(string pWin) = `` ~ getDrawableDamage!(`&(` ~ pWin ~ `).drawable`) ~ ``;

enum string drawableDamage(string pDrawable) = `
    DamagePtr pDamage = ` ~ getDrawableDamage!(pDrawable) ~ `;`;

enum string windowDamage(string pWin) = `` ~ drawableDamage!(`&(` ~ pWin ~ `).drawable`) ~ ``;

enum string winDamageRef(string pWindow) = `
    DamagePtr* pPrev = cast(DamagePtr*) 
	dixLookupPrivateAddr(&(` ~ pWindow ~ `).devPrivates, damageWinPrivateKey);`;

// #if DAMAGE_DEBUG_ENABLE
// private void _damageRegionAppend(DrawablePtr pDrawable, RegionPtr pRegion, Bool clip, int subWindowMode, const(char)* where);
// enum string damageRegionAppend(string d,string r,string c,string m) = `_damageRegionAppend(` ~ d ~ `,` ~ r ~ `,` ~ c ~ `,` ~ m ~ `,__FUNCTION__.ptr)`;
// } else {
void damageRegionAppend(DrawablePtr pDrawable, RegionPtr pRegion, Bool clip, int subWindowMode)
// #endif
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(damageScrPriv!("pScreen"));
    mixin(drawableDamage!(`pDrawable`));
    DamagePtr pNext = void;
    RegionRec clippedRec = void;
    RegionPtr pDamageRegion = void;
    RegionRec pixClip = void;
    int draw_x = void, draw_y = void;

    int screen_x = 0, screen_y = 0;

    /* short circuit for empty regions */
    if (!RegionNotEmpty(pRegion))
        return;

    /*
     * When drawing to a pixmap which is storing window contents,
     * the region presented is in pixmap relative coordinates which
     * need to be converted to screen relative coordinates
     */
    if (pDrawable.type != DRAWABLE_WINDOW) {
        screen_x = (cast(PixmapPtr) pDrawable).screen_x - pDrawable.x;
        screen_y = (cast(PixmapPtr) pDrawable).screen_y - pDrawable.y;
    }
    if (screen_x || screen_y)
        RegionTranslate(pRegion, screen_x, screen_y);

    if (pDrawable.type == DRAWABLE_WINDOW &&
        (cast(WindowPtr) (pDrawable)).backingStore == NotUseful) {
        if (subWindowMode == ClipByChildren) {
            RegionIntersect(pRegion, pRegion,
                            &(cast(WindowPtr) (pDrawable)).clipList);
        }
        else if (subWindowMode == IncludeInferiors) {
            RegionPtr pTempRegion = NotClippedByChildren(cast(WindowPtr) (pDrawable));
            RegionIntersect(pRegion, pRegion, pTempRegion);
            RegionDestroy(pTempRegion);
        }
        /* If subWindowMode is set to an invalid value, don't perform
         * any drawable-based clipping. */
    }

    RegionNull(&clippedRec);
    for (; pDamage; pDamage = pNext) {
        pNext = pDamage.pNext;
        /*
         * Check for internal damage and don't send events
         */
        if (pScrPriv.internalLevel > 0 && !pDamage.isInternal) {
            // DAMAGE_DEBUG(("non internal damage, skipping at %d\n",
                        //   pScrPriv.internalLevel));
            continue;
        }
        /*
         * Check for unrealized windows
         */
        if (pDamage.pDrawable.type == DRAWABLE_WINDOW &&
            !(cast(WindowPtr) (pDamage.pDrawable)).realized) {
            continue;
        }

        draw_x = pDamage.pDrawable.x;
        draw_y = pDamage.pDrawable.y;
        /*
         * Need to move everyone to screen coordinates
         * XXX what about off-screen pixmaps with non-zero x/y?
         */
        if (!mixin(WindowDrawable!("pDamage.pDrawable.type"))) {
            draw_x += (cast(PixmapPtr) pDamage.pDrawable).screen_x;
            draw_y += (cast(PixmapPtr) pDamage.pDrawable).screen_y;
        }

        /*
         * Clip against border or pixmap bounds
         */

        pDamageRegion = pRegion;
        if (clip || pDamage.pDrawable != pDrawable) {
            pDamageRegion = &clippedRec;
            if (pDamage.pDrawable.type == DRAWABLE_WINDOW) {
                RegionIntersect(pDamageRegion, pRegion,
                                &(cast(WindowPtr) (pDamage.pDrawable)).
                                borderClip);
            }
            else {
                BoxRec box = void;

                box.x1 = cast(short)(draw_x);
                box.y1 = cast(short)(draw_y);
                box.x2 = cast(short)(draw_x + pDamage.pDrawable.width);
                box.y2 = cast(short)(draw_y + pDamage.pDrawable.height);
                RegionInit(&pixClip, &box, 1);
                RegionIntersect(pDamageRegion, pRegion, &pixClip);
                RegionUninit(&pixClip);
            }
            /*
             * Short circuit empty results
             */
            if (!RegionNotEmpty(pDamageRegion))
                continue;
        }

        // DAMAGE_DEBUG(("%s %d x %d +%d +%d (target 0x%lx monitor 0x%lx)\n",
        //               where,
        //               pDamageRegion.extents.x2 - pDamageRegion.extents.x1,
        //               pDamageRegion.extents.y2 - pDamageRegion.extents.y1,
        //               pDamageRegion.extents.x1, pDamageRegion.extents.y1,
        //               pDrawable.id, pDamage.pDrawable.id));

        /*
         * Move region to target coordinate space
         */
        if (draw_x || draw_y)
            RegionTranslate(pDamageRegion, -draw_x, -draw_y);

        /* Store damage region if needed after submission. */
        if (pDamage.reportAfter)
            RegionUnion(&pDamage.pendingDamage,
                        &pDamage.pendingDamage, pDamageRegion);

        /* Report damage now, if desired. */
        if (!pDamage.reportAfter) {
            if (pDamage.damageReport)
                DamageReportDamage(pDamage, pDamageRegion);
            else
                RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
        }

        /*
         * translate original region back
         */
        if (pDamageRegion == pRegion && (draw_x || draw_y))
            RegionTranslate(pDamageRegion, draw_x, draw_y);
    }
    if (screen_x || screen_y)
        RegionTranslate(pRegion, -screen_x, -screen_y);

    RegionUninit(&clippedRec);
}

private void damageRegionProcessPending(DrawablePtr pDrawable)
{
    mixin(drawableDamage!(`pDrawable`));

    for (; pDamage !is null; pDamage = pDamage.pNext) {
        if (pDamage.reportAfter) {
            /* It's possible that there is only interest in postRendering reporting. */
            if (pDamage.damageReport)
                DamageReportDamage(pDamage, &pDamage.pendingDamage);
            else
                RegionUnion(&pDamage.damage, &pDamage.damage,
                            &pDamage.pendingDamage);
        }

        if (pDamage.reportAfter)
            RegionEmpty(&pDamage.pendingDamage);
    }

}

// #if DAMAGE_DEBUG_ENABLE
// enum string damageDamageBox(string d,string b,string m) = `_damageDamageBox(` ~ d ~ `,` ~ b ~ `,` ~ m ~ `,__FUNCTION__.ptr)`;
// private void _damageDamageBox(DrawablePtr pDrawable, BoxPtr pBox, int subWindowMode, const(char)* where);
// } else {
private void damageDamageBox(DrawablePtr pDrawable, BoxPtr pBox, int subWindowMode)
// #endif
{
    RegionRec region = void;

    RegionInit(&region, pBox, 1);
static if (DAMAGE_DEBUG_ENABLE) {
    _damageRegionAppend(pDrawable, &region, TRUE, subWindowMode, __FUNC__);
} else {
    damageRegionAppend(pDrawable, &region, TRUE, subWindowMode);
}
    RegionUninit(&region);
}









private GCFuncs damageGCFuncs = {
    &damageValidateGC, &damageChangeGC, &damageCopyGC, &damageDestroyGC,
    &damageChangeClip, &damageDestroyClip, &damageCopyClip
};

// private GCOps damageGCOps;

private Bool damageCreateGC(GCPtr pGC)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(damageScrPriv!("pScreen"));
    mixin(damageGCPriv!("pGC"));
    Bool ret = void;

    mixin(unwrap!(`pScrPriv`, `pScreen`, `CreateGC`));
    if ((ret = (*pScreen.CreateGC) (pGC)) != 0) {
        pGCPriv.ops = null;
        pGCPriv.funcs = pGC.funcs;
        pGC.funcs = &damageGCFuncs;
    }
    mixin(wrap!(`pScrPriv`, `pScreen`, `CreateGC`, `&damageCreateGC`));

    return ret;
}

enum string DAMAGE_GC_OP_PROLOGUE(string pGC, string pDrawable) =
    damageGCPriv!(pGC)~`  
    const(GCFuncs)* oldFuncs = ` ~ pGC ~ `.funcs; 
    ` ~ unwrap!(`pGCPriv`, pGC, `funcs`) ~ `  
    ` ~ unwrap!(`pGCPriv`, pGC, `ops`);

enum string DAMAGE_GC_OP_EPILOGUE(string pGC, string pDrawable) = `
    ` ~ wrap!(`pGCPriv`, pGC, `funcs`, `oldFuncs`) ~ ` 
    ` ~ wrap!(`pGCPriv`, pGC, `ops`, `&damageGCOps`);

enum string DAMAGE_GC_FUNC_PROLOGUE(string pGC) = 
    damageGCPriv!(pGC)~`
    ` ~ unwrap!(`pGCPriv`, pGC, `funcs`)~` 
    if (pGCPriv.ops) ` ~ 
        unwrap!(`pGCPriv`, pGC, `ops`);

enum string DAMAGE_GC_FUNC_EPILOGUE(string pGC) = `
    ` ~ wrap!(`pGCPriv`, pGC, `funcs`, `&damageGCFuncs`)
     ~ `  if (pGCPriv.ops)
    ` ~     wrap!(`pGCPriv`, pGC, `ops`, `&damageGCOps`);

private void damageValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDrawable)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.ValidateGC) (pGC, changes, pDrawable);
    pGCPriv.ops = pGC.ops; /* just so it's not NULL */
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGC`));
}

private void damageDestroyGC(GCPtr pGC)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.DestroyGC) (pGC);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGC`));
}

private void damageChangeGC(GCPtr pGC, c_ulong mask)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.ChangeGC) (pGC, mask);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGC`));
}

private void damageCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGCDst`));
    (*pGCDst.funcs.CopyGC) (pGCSrc, mask, pGCDst);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGCDst`));
}

private void damageChangeClip(GCPtr pGC, int type, void* pvalue, int nrects)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.ChangeClip) (pGC, type, pvalue, nrects);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGC`));
}

private void damageCopyClip(GCPtr pgcDst, GCPtr pgcSrc)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pgcDst`));
    (*pgcDst.funcs.CopyClip) (pgcDst, pgcSrc);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pgcDst`));
}

private void damageDestroyClip(GCPtr pGC)
{
    mixin(DAMAGE_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.DestroyClip) (pGC);
    mixin(DAMAGE_GC_FUNC_EPILOGUE!(`pGC`));
}

enum string TRIM_BOX(string box, string pGC) = `if (` ~ pGC ~ `.pCompositeClip) { 
    BoxPtr extents = &` ~ pGC ~ `.pCompositeClip.extents;
    if(` ~ box ~ `.x1 < extents.x1) ` ~ box ~ `.x1 = extents.x1; 
    if(` ~ box ~ `.x2 > extents.x2) ` ~ box ~ `.x2 = extents.x2; 
    if(` ~ box ~ `.y1 < extents.y1) ` ~ box ~ `.y1 = extents.y1; 
    if(` ~ box ~ `.y2 > extents.y2) ` ~ box ~ `.y2 = extents.y2; 
    }`;

enum string TRANSLATE_BOX(string box, string pDrawable) = `{ 
    ` ~ box ~ `.x1 += ` ~ pDrawable ~ `.x; 
    ` ~ box ~ `.x2 += ` ~ pDrawable ~ `.x; 
    ` ~ box ~ `.y1 += ` ~ pDrawable ~ `.y; 
    ` ~ box ~ `.y2 += ` ~ pDrawable ~ `.y; 
    }`;

enum string TRIM_AND_TRANSLATE_BOX(string box, string pDrawable, string pGC) = `{ 
    ` ~ TRANSLATE_BOX!(box, pDrawable) ~ `; 
    ` ~ TRIM_BOX!(box, pGC) ~ `; 
    }`;

enum string BOX_NOT_EMPTY(string box) = `
    (((` ~ box ~ `.x2 - ` ~ box ~ `.x1) > 0) && ((` ~ box ~ `.y2 - ` ~ box ~ `.y1) > 0))`;

enum string checkGCDamage(string d,string g) = `(` ~ getDrawableDamage!(d) ~ ` && 
				 (!` ~ g ~ `.pCompositeClip ||
				  RegionNotEmpty(` ~ g ~ `.pCompositeClip)))`;

enum string TRIM_PICTURE_BOX(string box, string pDst) = `{ 
    BoxPtr extents = &` ~ pDst ~ `.pCompositeClip.extents;
    if(` ~ box ~ `.x1 < extents.x1) ` ~ box ~ `.x1 = extents.x1; 
    if(` ~ box ~ `.x2 > extents.x2) ` ~ box ~ `.x2 = extents.x2; 
    if(` ~ box ~ `.y1 < extents.y1) ` ~ box ~ `.y1 = extents.y1; 
    if(` ~ box ~ `.y2 > extents.y2) ` ~ box ~ `.y2 = extents.y2; 
    }`;

enum string checkPictureDamage(string p) = `(` ~ getDrawableDamage!(`` ~ p ~ `.pDrawable`) ~ ` && 
				 RegionNotEmpty(` ~ p ~ `.pCompositeClip))`;

private void damageComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(damageScrPriv!("pScreen"));

    if (mixin(checkPictureDamage!(`pDst`))) {
        BoxRec box = void;

        box.x1 = cast(short)(xDst + pDst.pDrawable.x);
        box.y1 = cast(short)(yDst + pDst.pDrawable.y);
        box.x2 = cast(short)(box.x1 + width);
        box.y2 = cast(short)(box.y1 + height);
        mixin(TRIM_PICTURE_BOX!(`box`, `pDst`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDst.pDrawable, &box, pDst.subWindowMode);
    }
    /*
     * Validating a source picture bound to a window may trigger other
     * composite operations. Do it before unwrapping to make sure damage
     * is reported correctly.
     */
    if (pSrc.pDrawable && mixin(WindowDrawable!("pSrc.pDrawable.type")))
        miCompositeSourceValidate(pSrc);
    if (pMask && pMask.pDrawable && mixin(WindowDrawable!("pMask.pDrawable.type")))
        miCompositeSourceValidate(pMask);
    mixin(unwrap!(`pScrPriv`, `ps`, `Composite`));
    (*ps.Composite) (op,
                      pSrc,
                      pMask,
                      pDst,
                      xSrc, ySrc, xMask, yMask, xDst, yDst, width, height);
    damageRegionProcessPending(pDst.pDrawable);
    mixin(wrap!(`pScrPriv`, `ps`, `Composite`, `&damageComposite`));
}

private void damageGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(damageScrPriv!("pScreen"));

    if (mixin(checkPictureDamage!(`pDst`))) {
        int nlistTmp = nlist;
        GlyphListPtr listTmp = list;
        GlyphPtr* glyphsTmp = glyphs;
        int x = void, y = void;
        int n = void;
        GlyphPtr glyph = void;
        BoxRec box = void;
        int x1 = void, y1 = void, x2 = void, y2 = void;

        box.x1 = 32767;
        box.y1 = 32767;
        box.x2 = -32767;
        box.y2 = -32767;
        x = pDst.pDrawable.x;
        y = pDst.pDrawable.y;
        while (nlistTmp--) {
            x += listTmp.xOff;
            y += listTmp.yOff;
            n = listTmp.len;
            while (n--) {
                glyph = *glyphsTmp++;
                x1 = x - glyph.info.x;
                y1 = y - glyph.info.y;
                x2 = x1 + glyph.info.width;
                y2 = y1 + glyph.info.height;
                if (x1 < box.x1)
                    box.x1 = cast(short)x1;
                if (y1 < box.y1)
                    box.y1 = cast(short)y1;
                if (x2 > box.x2)
                    box.x2 = cast(short)x2;
                if (y2 > box.y2)
                    box.y2 = cast(short)y2;
                x += glyph.info.xOff;
                y += glyph.info.yOff;
            }
            listTmp++;
        }
        mixin(TRIM_PICTURE_BOX!(`box`, `pDst`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDst.pDrawable, &box, pDst.subWindowMode);
    }
    mixin(unwrap!(`pScrPriv`, `ps`, `Glyphs`));
    (*ps.Glyphs) (op, pSrc, pDst, maskFormat, xSrc, ySrc, nlist, list, glyphs);
    damageRegionProcessPending(pDst.pDrawable);
    mixin(wrap!(`pScrPriv`, `ps`, `Glyphs`, `&damageGlyphs`));
}

private void damageAddTraps(PicturePtr pPicture, INT16 x_off, INT16 y_off, int ntrap, xTrap* traps)
{
    ScreenPtr pScreen = pPicture.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(damageScrPriv!("pScreen"));

    if (mixin(checkPictureDamage!(`pPicture`))) {
        BoxRec box = void;
        int i = void;
        int x = void, y = void;
        xTrap* t = traps;

        box.x1 = 32767;
        box.y1 = 32767;
        box.x2 = -32767;
        box.y2 = -32767;
        x = pPicture.pDrawable.x + x_off;
        y = pPicture.pDrawable.y + y_off;
        for (i = 0; i < ntrap; i++) {
            pixman_fixed_t l = cast(pixman_fixed_t)min(t.top.l, t.bot.l);
            pixman_fixed_t r = cast(pixman_fixed_t)max(t.top.r, t.bot.r);
            int x1 = x + mixin(pixman_fixed_to_int!("l"));
            int x2 = x + mixin(pixman_fixed_to_int!(pixman_fixed_ceil!(`r`)));
            int y1 = y + mixin(pixman_fixed_to_int!("t.top.y"));
            int y2 = y + mixin(pixman_fixed_to_int!(pixman_fixed_ceil!(`t.bot.y`)));

            if (x1 < box.x1)
                box.x1 = cast(short)x1;
            if (x2 > box.x2)
                box.x2 = cast(short)x2;
            if (y1 < box.y1)
                box.y1 = cast(short)y1;
            if (y2 > box.y2)
                box.y2 = cast(short)y2;
        }
        mixin(TRIM_PICTURE_BOX!(`box`, `pPicture`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pPicture.pDrawable, &box, pPicture.subWindowMode);
    }
    mixin(unwrap!(`pScrPriv`, `ps`, `AddTraps`));
    (*ps.AddTraps) (pPicture, x_off, y_off, ntrap, traps);
    damageRegionProcessPending(pPicture.pDrawable);
    mixin(wrap!(`pScrPriv`, `ps`, `AddTraps`, `&damageAddTraps`));
}

/**********************************************************/

private void damageFillSpans(DrawablePtr pDrawable, GCPtr pGC, int npt, DDXPointPtr ppt, int* pwidth, int fSorted)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (npt && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        int nptTmp = npt;
        DDXPointPtr pptTmp = ppt;
        int* pwidthTmp = pwidth;
        BoxRec box = void;

        box.x1 = cast(short)pptTmp.x;
        box.x2 = cast(short)(box.x1 + *pwidthTmp);
        box.y2 = box.y1 = cast(short)pptTmp.y;

        while (--nptTmp) {
            pptTmp++;
            pwidthTmp++;
            if (box.x1 > pptTmp.x)
                box.x1 = cast(short)(pptTmp.x);
            if (box.x2 < (pptTmp.x + *pwidthTmp))
                box.x2 = cast(short)(pptTmp.x + *pwidthTmp);
            if (box.y1 > pptTmp.y)
                box.y1 = cast(short)(pptTmp.y);
            else if (box.y2 < pptTmp.y)
                box.y2 = cast(short)(pptTmp.y);
        }

        box.y2++;

        if (!pGC.miTranslate) {
            mixin(TRANSLATE_BOX!(`box`, `pDrawable`));
        }
        mixin(TRIM_BOX!(`box`, `pGC`));

        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }

    (*pGC.ops.FillSpans) (pDrawable, pGC, npt, ppt, pwidth, fSorted);

    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damageSetSpans(DrawablePtr pDrawable, GCPtr pGC, char* pcharsrc, DDXPointPtr ppt, int* pwidth, int npt, int fSorted)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (npt && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        DDXPointPtr pptTmp = ppt;
        int* pwidthTmp = pwidth;
        int nptTmp = npt;
        BoxRec box = void;

        box.x1 = cast(short)pptTmp.x;
        box.x2 = cast(short)(box.x1 + *pwidthTmp);
        box.y2 = box.y1 = cast(short)pptTmp.y;

        while (--nptTmp) {
            pptTmp++;
            pwidthTmp++;
            if (box.x1 > pptTmp.x)
                box.x1 = cast(short)(pptTmp.x);
            if (box.x2 < (pptTmp.x + *pwidthTmp))
                box.x2 = cast(short)(pptTmp.x + *pwidthTmp);
            if (box.y1 > pptTmp.y)
                box.y1 = cast(short)(pptTmp.y);
            else if (box.y2 < pptTmp.y)
                box.y2 = cast(short)(pptTmp.y);
        }

        box.y2++;

        if (!pGC.miTranslate) {
            mixin(TRANSLATE_BOX!(`box`, `pDrawable`));
        }
        mixin(TRIM_BOX!(`box`, `pGC`));

        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.SetSpans) (pDrawable, pGC, pcharsrc, ppt, pwidth, npt, fSorted);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePutImage(DrawablePtr pDrawable, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pImage)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    if (mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;

        box.x1 = cast(short)(x + pDrawable.x);
        box.x2 = cast(short)(box.x1 + w);
        box.y1 = cast(short)(y + pDrawable.y);
        box.y2 = cast(short)(box.y1 + h);

        mixin(TRIM_BOX!(`box`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PutImage) (pDrawable, pGC, depth, x, y, w, h,
                           leftPad, format, pImage);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private RegionPtr damageCopyArea(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty)
{
    RegionPtr ret = void;

    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDst`));

    if (mixin(checkGCDamage!(`pDst`, `pGC`))) {
        BoxRec box = void;

        box.x1 = cast(short)(dstx + pDst.x);
        box.x2 = cast(short)(box.x1 + width);
        box.y1 = cast(short)(dsty + pDst.y);
        box.y2 = cast(short)(box.y1 + height);

        mixin(TRIM_BOX!(`box`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDst, &box, pGC.subWindowMode);
    }

    ret = (*pGC.ops.CopyArea) (pSrc, pDst,
                                 pGC, srcx, srcy, width, height, dstx, dsty);
    damageRegionProcessPending(pDst);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDst`));
    return ret;
}

private RegionPtr damageCopyPlane(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty, c_ulong bitPlane)
{
    RegionPtr ret = void;

    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDst`));

    if (mixin(checkGCDamage!(`pDst`, `pGC`))) {
        BoxRec box = void;

        box.x1 = cast(short)(dstx + pDst.x);
        box.x2 = cast(short)(box.x1 + width);
        box.y1 = cast(short)(dsty + pDst.y);
        box.y2 = cast(short)(box.y1 + height);

        mixin(TRIM_BOX!(`box`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDst, &box, pGC.subWindowMode);
    }

    ret = (*pGC.ops.CopyPlane) (pSrc, pDst,
                                  pGC, srcx, srcy, width, height, dstx, dsty,
                                  bitPlane);
    damageRegionProcessPending(pDst);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDst`));
    return ret;
}

private void damagePolyPoint(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, xPoint* ppt)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (npt && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;
        int nptTmp = npt;
        xPoint* pptTmp = ppt;

        box.x2 = box.x1 = pptTmp.x;
        box.y2 = box.y1 = pptTmp.y;

        /* this could be slow if the points were spread out */

        if (mode == CoordModePrevious) {
            int x = box.x1;
            int y = box.y1;

            while (--nptTmp) {
                pptTmp++;
                x += pptTmp.x;
                y += pptTmp.y;
                if (box.x1 > x)
                    box.x1 = cast(short)x;
                else if (box.x2 < x)
                    box.x2 = cast(short)x;
                if (box.y1 > y)
                    box.y1 = cast(short)y;
                else if (box.y2 < y)
                    box.y2 = cast(short)y;
            }
        }
        else {
            while (--nptTmp) {
                pptTmp++;
                if (box.x1 > pptTmp.x)
                    box.x1 = pptTmp.x;
                else if (box.x2 < pptTmp.x)
                    box.x2 = pptTmp.x;
                if (box.y1 > pptTmp.y)
                    box.y1 = pptTmp.y;
                else if (box.y2 < pptTmp.y)
                    box.y2 = pptTmp.y;
            }
        }

        box.x2++;
        box.y2++;

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PolyPoint) (pDrawable, pGC, mode, npt, ppt);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolylines(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ppt)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (npt && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        int nptTmp = npt;
        DDXPointPtr pptTmp = ppt;
        BoxRec box = void;
        int extra = pGC.lineWidth >> 1;

        box.x2 = box.x1 = pptTmp.x;
        box.y2 = box.y1 = pptTmp.y;

        if (nptTmp > 1) {
            if (pGC.joinStyle == JoinMiter)
                extra = 6 * pGC.lineWidth;
            else if (pGC.capStyle == CapProjecting)
                extra = pGC.lineWidth;
        }

        if (mode == CoordModePrevious) {
            int x = box.x1;
            int y = box.y1;

            while (--nptTmp) {
                pptTmp++;
                x += pptTmp.x;
                y += pptTmp.y;
                if (box.x1 > x)
                    box.x1 = cast(short)x;
                else if (box.x2 < x)
                    box.x2 = cast(short)x;
                if (box.y1 > y)
                    box.y1 = cast(short)y;
                else if (box.y2 < y)
                    box.y2 = cast(short)y;
            }
        }
        else {
            while (--nptTmp) {
                pptTmp++;
                if (box.x1 > pptTmp.x)
                    box.x1 = pptTmp.x;
                else if (box.x2 < pptTmp.x)
                    box.x2 = pptTmp.x;
                if (box.y1 > pptTmp.y)
                    box.y1 = pptTmp.y;
                else if (box.y2 < pptTmp.y)
                    box.y2 = pptTmp.y;
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

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.Polylines) (pDrawable, pGC, mode, npt, ppt);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolySegment(DrawablePtr pDrawable, GCPtr pGC, int nSeg, xSegment* pSeg)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (nSeg && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;
        int extra = pGC.lineWidth;
        int nsegTmp = nSeg;
        xSegment* pSegTmp = pSeg;

        if (pGC.capStyle != CapProjecting)
            extra >>= 1;

        if (pSegTmp.x2 > pSegTmp.x1) {
            box.x1 = pSegTmp.x1;
            box.x2 = pSegTmp.x2;
        }
        else {
            box.x2 = pSegTmp.x1;
            box.x1 = pSegTmp.x2;
        }

        if (pSegTmp.y2 > pSegTmp.y1) {
            box.y1 = pSegTmp.y1;
            box.y2 = pSegTmp.y2;
        }
        else {
            box.y2 = pSegTmp.y1;
            box.y1 = pSegTmp.y2;
        }

        while (--nsegTmp) {
            pSegTmp++;
            if (pSegTmp.x2 > pSegTmp.x1) {
                if (pSegTmp.x1 < box.x1)
                    box.x1 = pSegTmp.x1;
                if (pSegTmp.x2 > box.x2)
                    box.x2 = pSegTmp.x2;
            }
            else {
                if (pSegTmp.x2 < box.x1)
                    box.x1 = pSegTmp.x2;
                if (pSegTmp.x1 > box.x2)
                    box.x2 = pSegTmp.x1;
            }
            if (pSegTmp.y2 > pSegTmp.y1) {
                if (pSegTmp.y1 < box.y1)
                    box.y1 = pSegTmp.y1;
                if (pSegTmp.y2 > box.y2)
                    box.y2 = pSegTmp.y2;
            }
            else {
                if (pSegTmp.y2 < box.y1)
                    box.y1 = pSegTmp.y2;
                if (pSegTmp.y1 > box.y2)
                    box.y2 = pSegTmp.y1;
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

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PolySegment) (pDrawable, pGC, nSeg, pSeg);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolyRectangle(DrawablePtr pDrawable, GCPtr pGC, int nRects, xRectangle* pRects)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (nRects && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;
        int offset1 = void, offset2 = void, offset3 = void;
        int nRectsTmp = nRects;
        xRectangle* pRectsTmp = pRects;

        offset2 = pGC.lineWidth;
        if (!offset2)
            offset2 = 1;
        offset1 = offset2 >> 1;
        offset3 = offset2 - offset1;

        while (nRectsTmp--) {
            box.x1 = cast(short)(pRectsTmp.x - offset1);
            box.y1 = cast(short)(pRectsTmp.y - offset1);
            box.x2 = cast(short)(box.x1 + pRectsTmp.width + offset2);
            box.y2 = cast(short)(box.y1 + offset2);
            mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
            if (mixin(BOX_NOT_EMPTY!(`box`)))
                damageDamageBox(pDrawable, &box, pGC.subWindowMode);

            box.x1 = cast(short)(pRectsTmp.x - offset1);
            box.y1 = cast(short)(pRectsTmp.y + offset3);
            box.x2 = cast(short)(box.x1 + offset2);
            box.y2 = cast(short)(box.y1 + pRectsTmp.height - offset2);
            mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
            if (mixin(BOX_NOT_EMPTY!(`box`)))
                damageDamageBox(pDrawable, &box, pGC.subWindowMode);

            box.x1 = cast(short)(pRectsTmp.x + pRectsTmp.width - offset1);
            box.y1 = cast(short)(pRectsTmp.y + offset3);
            box.x2 = cast(short)(box.x1 + offset2);
            box.y2 = cast(short)(box.y1 + pRectsTmp.height - offset2);
            mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
            if (mixin(BOX_NOT_EMPTY!(`box`)))
                damageDamageBox(pDrawable, &box, pGC.subWindowMode);

            box.x1 = cast(short)(pRectsTmp.x - offset1);
            box.y1 = cast(short)(pRectsTmp.y + pRectsTmp.height - offset1);
            box.x2 = cast(short)(box.x1 + pRectsTmp.width + offset2);
            box.y2 = cast(short)(box.y1 + offset2);
            mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
            if (mixin(BOX_NOT_EMPTY!(`box`)))
                damageDamageBox(pDrawable, &box, pGC.subWindowMode);

            pRectsTmp++;
        }
    }
    (*pGC.ops.PolyRectangle) (pDrawable, pGC, nRects, pRects);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolyArc(DrawablePtr pDrawable, GCPtr pGC, int nArcs, xArc* pArcs)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (nArcs && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        int extra = pGC.lineWidth >> 1;
        BoxRec box = void;
        int nArcsTmp = nArcs;
        xArc* pArcsTmp = pArcs;

        box.x1 = cast(short)(pArcsTmp.x);
        box.x2 = cast(short)(box.x1 + pArcsTmp.width);
        box.y1 = cast(short)(pArcsTmp.y);
        box.y2 = cast(short)(box.y1 + pArcsTmp.height);

        while (--nArcsTmp) {
            pArcsTmp++;
            if (box.x1 > pArcsTmp.x)
                box.x1 = cast(short)(pArcsTmp.x);
            if (box.x2 < (pArcsTmp.x + pArcsTmp.width))
                box.x2 = cast(short)(pArcsTmp.x + pArcsTmp.width);
            if (box.y1 > pArcsTmp.y)
                box.y1 = cast(short)(pArcsTmp.y);
            if (box.y2 < (pArcsTmp.y + pArcsTmp.height))
                box.y2 = cast(short)(pArcsTmp.y + pArcsTmp.height);
        }

        if (extra) {
            box.x1 -= extra;
            box.x2 += extra;
            box.y1 -= extra;
            box.y2 += extra;
        }

        box.x2++;
        box.y2++;

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PolyArc) (pDrawable, pGC, nArcs, pArcs);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damageFillPolygon(DrawablePtr pDrawable, GCPtr pGC, int shape, int mode, int npt, DDXPointPtr ppt)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (npt > 2 && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        DDXPointPtr pptTmp = ppt;
        int nptTmp = npt;
        BoxRec box = void;

        box.x2 = box.x1 = cast(short)pptTmp.x;
        box.y2 = box.y1 = cast(short)pptTmp.y;

        if (mode != CoordModeOrigin) {
            int x = box.x1;
            int y = box.y1;

            while (--nptTmp) {
                pptTmp++;
                x += pptTmp.x;
                y += pptTmp.y;
                if (box.x1 > x)
                    box.x1 = cast(short)x;
                else if (box.x2 < x)
                    box.x2 = cast(short)x;
                if (box.y1 > y)
                    box.y1 = cast(short)y;
                else if (box.y2 < y)
                    box.y2 = cast(short)y;
            }
        }
        else {
            while (--nptTmp) {
                pptTmp++;
                if (box.x1 > pptTmp.x)
                    box.x1 = cast(short)pptTmp.x;
                else if (box.x2 < pptTmp.x)
                    box.x2 = cast(short)pptTmp.x;
                if (box.y1 > pptTmp.y)
                    box.y1 = cast(short)pptTmp.y;
                else if (box.y2 < pptTmp.y)
                    box.y2 = cast(short)pptTmp.y;
            }
        }

        box.x2++;
        box.y2++;

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }

    (*pGC.ops.FillPolygon) (pDrawable, pGC, shape, mode, npt, ppt);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolyFillRect(DrawablePtr pDrawable, GCPtr pGC, int nRects, xRectangle* pRects)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    if (nRects && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;
        xRectangle* pRectsTmp = pRects;
        int nRectsTmp = nRects;

        box.x1 = cast(short)(pRectsTmp.x);
        box.x2 = cast(short)(box.x1 + pRectsTmp.width);
        box.y1 = cast(short)(pRectsTmp.y);
        box.y2 = cast(short)(box.y1 + pRectsTmp.height);

        while (--nRectsTmp) {
            pRectsTmp++;
            if (box.x1 > pRectsTmp.x)
                box.x1 = cast(short)(pRectsTmp.x);
            if (box.x2 < (pRectsTmp.x + pRectsTmp.width))
                box.x2 = cast(short)(pRectsTmp.x + pRectsTmp.width);
            if (box.y1 > pRectsTmp.y)
                box.y1 = cast(short)(pRectsTmp.y);
            if (box.y2 < (pRectsTmp.y + pRectsTmp.height))
                box.y2 = cast(short)(pRectsTmp.y + pRectsTmp.height);
        }

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PolyFillRect) (pDrawable, pGC, nRects, pRects);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolyFillArc(DrawablePtr pDrawable, GCPtr pGC, int nArcs, xArc* pArcs)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));

    if (nArcs && mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;
        int nArcsTmp = nArcs;
        xArc* pArcsTmp = pArcs;

        box.x1 = cast(short)(pArcsTmp.x);
        box.x2 = cast(short)(box.x1 + pArcsTmp.width);
        box.y1 = cast(short)(pArcsTmp.y);
        box.y2 = cast(short)(box.y1 + pArcsTmp.height);

        while (--nArcsTmp) {
            pArcsTmp++;
            if (box.x1 > pArcsTmp.x)
                box.x1 = cast(short)(pArcsTmp.x);
            if (box.x2 < (pArcsTmp.x + pArcsTmp.width))
                box.x2 = cast(short)(pArcsTmp.x + pArcsTmp.width);
            if (box.y1 > pArcsTmp.y)
                box.y1 = cast(short)(pArcsTmp.y);
            if (box.y2 < (pArcsTmp.y + pArcsTmp.height))
                box.y2 = cast(short)(pArcsTmp.y + pArcsTmp.height);
        }

        mixin(TRIM_AND_TRANSLATE_BOX!(`box`, `pDrawable`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PolyFillArc) (pDrawable, pGC, nArcs, pArcs);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

/*
 * general Poly/Image text function.  Extract glyph information,
 * compute bounding box and remove cursor if it is overlapped.
 */

private void damageDamageChars(DrawablePtr pDrawable, FontPtr font, int x, int y, uint n, CharInfoPtr* charinfo, Bool imageblt, int subWindowMode)
{
    ExtentInfoRec extents = void;
    BoxRec box = void;

    assumeNoGC(&xfont2_query_glyph_extents)(font, charinfo, n, &extents);
    if (imageblt) {
        if (extents.overallWidth > extents.overallRight)
            extents.overallRight = extents.overallWidth;
        if (extents.overallWidth < extents.overallLeft)
            extents.overallLeft = extents.overallWidth;
        if (extents.overallLeft > 0)
            extents.overallLeft = 0;
        if (extents.fontAscent > extents.overallAscent)
            extents.overallAscent = extents.fontAscent;
        if (extents.fontDescent > extents.overallDescent)
            extents.overallDescent = extents.fontDescent;
    }
    box.x1 = cast(short)(x + extents.overallLeft);
    box.y1 = cast(short)(y - extents.overallAscent);
    box.x2 = cast(short)(x + extents.overallRight);
    box.y2 = cast(short)(y + extents.overallDescent);
    damageDamageBox(pDrawable, &box, subWindowMode);
}

/*
 * values for textType:
 */
enum TT_POLY8 =   0;
enum TT_IMAGE8 =  1;
enum TT_POLY16 =  2;
enum TT_IMAGE16 = 3;

private void damageText(DrawablePtr pDrawable, GCPtr pGC, int x, int y, c_ulong count, char* chars, FontEncoding fontEncoding, Bool textType)
{
    CharInfoPtr* charinfo = void;
    c_ulong i = void;
    uint n = void;
    Bool imageblt = void;

    imageblt = (textType == TT_IMAGE8) || (textType == TT_IMAGE16);

    if (!mixin(checkGCDamage!(`pDrawable`, `pGC`)))
        return;

    charinfo = cast(CharInfoPtr*) calloc(count, CharInfoPtr.sizeof);
    if (!charinfo)
        return;

    GetGlyphs(pGC.font, count, cast(ubyte*) chars,
              fontEncoding, &i, charinfo);
    n = cast(uint) i;

    if (n != 0) {
        damageDamageChars(pDrawable, pGC.font, x + pDrawable.x,
                          y + pDrawable.y, n, charinfo, imageblt,
                          pGC.subWindowMode);
    }
    free(charinfo);
}

private int damagePolyText8(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int count, char* chars)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageText(pDrawable, pGC, x, y, cast(c_ulong) count, chars, Linear8Bit,
               TT_POLY8);
    x = (*pGC.ops.PolyText8) (pDrawable, pGC, x, y, count, chars);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
    return x;
}

private int damagePolyText16(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageText(pDrawable, pGC, x, y, cast(c_ulong) count, cast(char*) chars,
               mixin(FONTLASTROW!("pGC.font")) == 0 ? Linear16Bit : TwoD16Bit,
               TT_POLY16);
    x = (*pGC.ops.PolyText16) (pDrawable, pGC, x, y, count, chars);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
    return x;
}

private void damageImageText8(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int count, char* chars)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageText(pDrawable, pGC, x, y, cast(c_ulong) count, chars, Linear8Bit,
               TT_IMAGE8);
    (*pGC.ops.ImageText8) (pDrawable, pGC, x, y, count, chars);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damageImageText16(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageText(pDrawable, pGC, x, y, cast(c_ulong) count, cast(char*) chars,
               mixin(FONTLASTROW!("pGC.font")) == 0 ? Linear16Bit : TwoD16Bit,
               TT_IMAGE16);
    (*pGC.ops.ImageText16) (pDrawable, pGC, x, y, count, chars);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damageImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageDamageChars(pDrawable, pGC.font, x + pDrawable.x, y + pDrawable.y,
                      nglyph, ppci, TRUE, pGC.subWindowMode);
    (*pGC.ops.ImageGlyphBlt) (pDrawable, pGC, x, y, nglyph, ppci, pglyphBase);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    damageDamageChars(pDrawable, pGC.font, x + pDrawable.x, y + pDrawable.y,
                      nglyph, ppci, FALSE, pGC.subWindowMode);
    (*pGC.ops.PolyGlyphBlt) (pDrawable, pGC, x, y, nglyph, ppci, pglyphBase);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damagePushPixels(GCPtr pGC, PixmapPtr pBitMap, DrawablePtr pDrawable, int dx, int dy, int xOrg, int yOrg)
{
    mixin(DAMAGE_GC_OP_PROLOGUE!(`pGC`, `pDrawable`));
    if (mixin(checkGCDamage!(`pDrawable`, `pGC`))) {
        BoxRec box = void;

        box.x1 = cast(short)(xOrg);
        box.y1 = cast(short)(yOrg);

        if (!pGC.miTranslate) {
            box.x1 += pDrawable.x;
            box.y1 += pDrawable.y;
        }

        box.x2 = cast(short)(box.x1 + dx);
        box.y2 = cast(short)(box.y1 + dy);

        mixin(TRIM_BOX!(`box`, `pGC`));
        if (mixin(BOX_NOT_EMPTY!(`box`)))
            damageDamageBox(pDrawable, &box, pGC.subWindowMode);
    }
    (*pGC.ops.PushPixels) (pGC, pBitMap, pDrawable, dx, dy, xOrg, yOrg);
    damageRegionProcessPending(pDrawable);
    mixin(DAMAGE_GC_OP_EPILOGUE!(`pGC`, `pDrawable`));
}

private void damageRemoveDamage(DamagePtr* pPrev, DamagePtr pDamage)
{
    while (*pPrev) {
        if (*pPrev == pDamage) {
            *pPrev = pDamage.pNext;
            return;
        }
        pPrev = &(*pPrev).pNext;
    }
static if (DAMAGE_VALIDATE_ENABLE) {
    ErrorF("Damage not on list\n");
    OsAbort();
}
}

private void damageInsertDamage(DamagePtr* pPrev, DamagePtr pDamage)
{
static if (DAMAGE_VALIDATE_ENABLE) {
    DamagePtr pOld = void;

    for (pOld = *pPrev; pOld; pOld = pOld.pNext)
        if (pOld == pDamage) {
            ErrorF("Damage already on list\n");
            OsAbort();
        }
}
    pDamage.pNext = *pPrev;
    *pPrev = pDamage;
}

private void damagePixmapDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap)
{
    DamagePtr* pPrev = mixin(getPixmapDamageRef!(`pPixmap`));
    DamagePtr pDamage = void;

    while ((pDamage = *pPrev) !is null) {
        damageRemoveDamage(pPrev, pDamage);
        if (!pDamage.isWindow)
            DamageDestroy(pDamage);
    }
}

private void damageCopyWindow(WindowPtr pWindow, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    ScreenPtr pScreen = pWindow.drawable.pScreen;

    mixin(damageScrPriv!("pScreen"));

    if (mixin(getWindowDamage!(`pWindow`))) {
        int dx = pWindow.drawable.x - ptOldOrg.x;
        int dy = pWindow.drawable.y - ptOldOrg.y;

        /*
         * The region comes in source relative, but the damage occurs
         * at the destination location.  Translate back and forth.
         */
        RegionTranslate(prgnSrc, dx, dy);
        damageRegionAppend(&pWindow.drawable, prgnSrc, FALSE, -1);
        RegionTranslate(prgnSrc, -dx, -dy);
    }
    mixin(unwrap!(`pScrPriv`, `pScreen`, `CopyWindow`));
    (*pScreen.CopyWindow) (pWindow, ptOldOrg, prgnSrc);
    damageRegionProcessPending(&pWindow.drawable);
    mixin(wrap!(`pScrPriv`, `pScreen`, `CopyWindow`, `&damageCopyWindow`));
}

private GCOps damageGCOps = {
    &damageFillSpans, &damageSetSpans,
    &damagePutImage, &damageCopyArea,
    &damageCopyPlane, &damagePolyPoint,
    &damagePolylines, &damagePolySegment,
    &damagePolyRectangle, &damagePolyArc,
    &damageFillPolygon, &damagePolyFillRect,
    &damagePolyFillArc, &damagePolyText8,
    &damagePolyText16, &damageImageText8,
    &damageImageText16, &damageImageGlyphBlt,
    &damagePolyGlyphBlt, &damagePushPixels,
};

private void damageSetWindowPixmap(WindowPtr pWindow, PixmapPtr pPixmap)
{
    DamagePtr pDamage = void;
    ScreenPtr pScreen = pWindow.drawable.pScreen;

    mixin(damageScrPriv!("pScreen"));

    if ((pDamage = mixin(damageGetWinPriv!("pWindow"))) !is null) {
        PixmapPtr pOldPixmap = (*pScreen.GetWindowPixmap) (pWindow);
        DamagePtr* pPrev = mixin(getPixmapDamageRef!(`pOldPixmap`));

        while (pDamage) {
            damageRemoveDamage(pPrev, pDamage);
            pDamage = pDamage.pNextWin;
        }
    }
    mixin(unwrap!(`pScrPriv`, `pScreen`, `SetWindowPixmap`));
    (*pScreen.SetWindowPixmap) (pWindow, pPixmap);
    mixin(wrap!(`pScrPriv`, `pScreen`, `SetWindowPixmap`, `&damageSetWindowPixmap`));
    if ((pDamage = mixin(damageGetWinPriv!("pWindow"))) !is null) {
        DamagePtr* pPrev = mixin(getPixmapDamageRef!(`pPixmap`));

        while (pDamage) {
            damageInsertDamage(pPrev, pDamage);
            pDamage = pDamage.pNextWin;
        }
    }
}

private void damageWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWindow)
{
    DamagePtr pDamage = void;

    while ((pDamage = mixin(damageGetWinPriv!("pWindow"))) !is null) {
        DamageDestroy(pDamage);
    }
}

private void damageCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookPostClose(pScreen, &damageCloseScreen);
    dixScreenUnhookWindowDestroy(pScreen, &damageWindowDestroy);
    dixScreenUnhookPixmapDestroy(pScreen, &damagePixmapDestroy);

    mixin(damageScrPriv!("pScreen"));
    if (!pScrPriv)
        return;

    mixin(unwrap!(`pScrPriv`, `pScreen`, `CreateGC`));
    mixin(unwrap!(`pScrPriv`, `pScreen`, `CopyWindow`));

    dixSetPrivate(&pScreen.devPrivates, damageScrPrivateKey, null);
    free(pScrPriv);
}

/**
 * Default implementations of the damage management functions.
 */
void miDamageCreate(DamagePtr pDamage)
{
}

/*
 * We only wrap into the GC when there's a registered listener.  For windows,
 * damage includes damage to children.  So if there's a GC validated against
 * a subwindow and we then register a damage on the parent, we need to bump
 * the serial numbers of the children to re-trigger validation.
 *
 * Since we can't know if a GC has been validated against one of the affected
 * children, just bump them all to be safe.
 */
private int damageRegisterVisit(WindowPtr pWin, void* data)
{
    pWin.drawable.serialNumber = NEXT_SERIAL_NUMBER;
    return WT_WALKCHILDREN;
}

void miDamageRegister(DrawablePtr pDrawable, DamagePtr pDamage)
{
    if (pDrawable.type == DRAWABLE_WINDOW)
        TraverseTree(cast(WindowPtr)pDrawable, &damageRegisterVisit, null);
    else
        pDrawable.serialNumber = NEXT_SERIAL_NUMBER;
}

void miDamageUnregister(DrawablePtr pDrawable, DamagePtr pDamage)
{
    if (pDrawable.type == DRAWABLE_WINDOW)
        TraverseTree(cast(WindowPtr)pDrawable, &damageRegisterVisit, null);
    else
        pDrawable.serialNumber = NEXT_SERIAL_NUMBER;
}

void miDamageDestroy(DamagePtr pDamage)
{
}

/**
 * Public functions for consumption outside this file.
 */

Bool DamageSetup(ScreenPtr pScreen)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));

    const(DamageScreenFuncsRec) miFuncs = {
        &miDamageCreate, &miDamageRegister, &miDamageUnregister, &miDamageDestroy
    };

    if (!dixRegisterPrivateKey(&damageScrPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (dixLookupPrivate(&pScreen.devPrivates, damageScrPrivateKey))
        return TRUE;

    if (!dixRegisterPrivateKey
        (&damageGCPrivateKeyRec, PRIVATE_GC, DamageGCPrivRec.sizeof))
        return FALSE;

    if (!dixRegisterPrivateKey(&damagePixPrivateKeyRec, PRIVATE_PIXMAP, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&damageWinPrivateKeyRec, PRIVATE_WINDOW, 0))
        return FALSE;

    DamageScrPrivPtr pScrPriv = cast(DamageScrPrivRec*) calloc(1, DamageScrPrivRec.sizeof);
    if (!pScrPriv)
        return FALSE;

    pScrPriv.internalLevel = 0;
    pScrPriv.pScreenDamage = null;

    dixScreenHookPostClose(pScreen, &damageCloseScreen);
    dixScreenHookWindowDestroy(pScreen, &damageWindowDestroy);
    dixScreenHookPixmapDestroy(pScreen, &damagePixmapDestroy);

    mixin(wrap!(`pScrPriv`, `pScreen`, `CreateGC`, `&damageCreateGC`));
    mixin(wrap!(`pScrPriv`, `pScreen`, `SetWindowPixmap`, `&damageSetWindowPixmap`));
    mixin(wrap!(`pScrPriv`, `pScreen`, `CopyWindow`, `&damageCopyWindow`));
    if (ps) {
        mixin(wrap!(`pScrPriv`, `ps`, `Glyphs`, `&damageGlyphs`));
        mixin(wrap!(`pScrPriv`, `ps`, `Composite`, `&damageComposite`));
        mixin(wrap!(`pScrPriv`, `ps`, `AddTraps`, `&damageAddTraps`));
    }

    pScrPriv.funcs = miFuncs;

    dixSetPrivate(&pScreen.devPrivates, damageScrPrivateKey, pScrPriv);
    return TRUE;
}

DamagePtr DamageCreate(DamageReportFunc damageReport, DamageDestroyFunc damageDestroy, DamageReportLevel damageLevel, Bool isInternal, ScreenPtr pScreen, void* closure)
{
    mixin(damageScrPriv!("pScreen"));
    DamagePtr pDamage = void;

    pDamage = cast(DamageRec*) calloc(1, DamageRec.sizeof);
    if (!pDamage)
        return null;
    pDamage.pNext = null;
    pDamage.pNextWin = null;
    RegionNull(&pDamage.damage);
    RegionNull(&pDamage.pendingDamage);

    pDamage.damageLevel = damageLevel;
    pDamage.isInternal = isInternal;
    pDamage.closure = closure;
    pDamage.isWindow = FALSE;
    pDamage.pDrawable = null;
    pDamage.reportAfter = FALSE;

    pDamage.damageReport = damageReport;
    pDamage.damageDestroy = damageDestroy;
    pDamage.pScreen = pScreen;

    if (pScrPriv && pScrPriv.funcs.Create)
        pScrPriv.funcs.Create (pDamage);

    return pDamage;
}

void DamageRegister(DrawablePtr pDrawable, DamagePtr pDamage)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(damageScrPriv!("pScreen"));

static if (DAMAGE_VALIDATE_ENABLE) {
    if (pDrawable.pScreen != pDamage.pScreen) {
        ErrorF("DamageRegister called with mismatched screens\n");
        OsAbort();
    }
}

    if (pDrawable.type == DRAWABLE_WINDOW) {
        WindowPtr pWindow = cast(WindowPtr) pDrawable;

        mixin(winDamageRef!(`pWindow`));

static if (DAMAGE_VALIDATE_ENABLE) {
        DamagePtr pOld = void;

        for (pOld = *pPrev; pOld; pOld = pOld.pNextWin)
            if (pOld == pDamage) {
                ErrorF("Damage already on window list\n");
                OsAbort();
            }
}
        pDamage.pNextWin = *pPrev;
        *pPrev = pDamage;
        pDamage.isWindow = TRUE;
    }
    else
        pDamage.isWindow = FALSE;
    pDamage.pDrawable = pDrawable;
    damageInsertDamage(getDrawableDamageRef(pDrawable), pDamage);
    if (pScrPriv && pScrPriv.funcs.Register)
        pScrPriv.funcs.Register (pDrawable, pDamage);
}

void DamageDrawInternal(ScreenPtr pScreen, Bool enable)
{
    mixin(damageScrPriv!("pScreen"));

    pScrPriv.internalLevel += enable ? 1 : -1;
}

void DamageUnregister(DamagePtr pDamage)
{
    DrawablePtr pDrawable = pDamage.pDrawable;
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(damageScrPriv!("pScreen"));

    if (pScrPriv && pScrPriv.funcs.Unregister)
        pScrPriv.funcs.Unregister (pDrawable, pDamage);

    if (pDrawable.type == DRAWABLE_WINDOW) {
        WindowPtr pWindow = cast(WindowPtr) pDrawable;

        mixin(winDamageRef!(`pWindow`));
static if (DAMAGE_VALIDATE_ENABLE) {
        int found = 0;
}

        while (*pPrev) {
            if (*pPrev == pDamage) {
                *pPrev = pDamage.pNextWin;
static if (DAMAGE_VALIDATE_ENABLE) {
                found = 1;
}
                break;
            }
            pPrev = &(*pPrev).pNextWin;
        }
static if (DAMAGE_VALIDATE_ENABLE) {
        if (!found) {
            ErrorF("Damage not on window list\n");
            OsAbort();
        }
}
    }
    pDamage.pDrawable = null;
    damageRemoveDamage(getDrawableDamageRef(pDrawable), pDamage);
}

void DamageDestroy(DamagePtr pDamage)
{
    ScreenPtr pScreen = pDamage.pScreen;

    mixin(damageScrPriv!("pScreen"));

    if (pDamage.pDrawable)
        DamageUnregister(pDamage);

    if (pDamage.damageDestroy)
        (*pDamage.damageDestroy) (pDamage, pDamage.closure);

    if (pScrPriv && pScrPriv.funcs.Destroy)
        pScrPriv.funcs.Destroy (pDamage);

    RegionUninit(&pDamage.damage);
    RegionUninit(&pDamage.pendingDamage);
    free(pDamage);
}

Bool DamageSubtract(DamagePtr pDamage, RegionPtr pRegion)
{
    RegionPtr pClip = void;
    RegionRec pixmapClip = void;
    DrawablePtr pDrawable = pDamage.pDrawable;

    RegionSubtract(&pDamage.damage, &pDamage.damage, pRegion);
    if (pDrawable) {
        if (pDrawable.type == DRAWABLE_WINDOW)
            pClip = &(cast(WindowPtr) pDrawable).borderClip;
        else {
            BoxRec box = void;

            box.x1 = cast(short)(pDrawable.x);
            box.y1 = cast(short)(pDrawable.y);
            box.x2 = cast(short)(pDrawable.x + pDrawable.width);
            box.y2 = cast(short)(pDrawable.y + pDrawable.height);
            RegionInit(&pixmapClip, &box, 1);
            pClip = &pixmapClip;
        }
        RegionTranslate(&pDamage.damage, pDrawable.x, pDrawable.y);
        RegionIntersect(&pDamage.damage, &pDamage.damage, pClip);
        RegionTranslate(&pDamage.damage, -pDrawable.x, -pDrawable.y);
        if (pDrawable.type != DRAWABLE_WINDOW)
            RegionUninit(&pixmapClip);
    }
    return RegionNotEmpty(&pDamage.damage);
}

void DamageEmpty(DamagePtr pDamage)
{
    RegionEmpty(&pDamage.damage);
}

RegionPtr DamageRegion(DamagePtr pDamage)
{
    return &pDamage.damage;
}

RegionPtr DamagePendingRegion(DamagePtr pDamage)
{
    return &pDamage.pendingDamage;
}

void DamageRegionAppend(DrawablePtr pDrawable, RegionPtr pRegion)
{
    damageRegionAppend(pDrawable, pRegion, FALSE, -1);
}

void DamageRegionProcessPending(DrawablePtr pDrawable)
{
    damageRegionProcessPending(pDrawable);
}

/* This call is very odd, i'm leaving it intact for API sake, but please don't use it. */
void DamageDamageRegion(DrawablePtr pDrawable, RegionPtr pRegion)
{
    damageRegionAppend(pDrawable, pRegion, FALSE, -1);

    /* Go back and report this damage for DamagePtrs with reportAfter set, since
     * this call isn't part of an in-progress drawing op in the call chain and
     * the DDX probably just wants to know about it right away.
     */
    damageRegionProcessPending(pDrawable);
}

void DamageSetReportAfterOp(DamagePtr pDamage, Bool reportAfter)
{
    pDamage.reportAfter = reportAfter;
}

DamageScreenFuncsPtr DamageGetScreenFuncs(ScreenPtr pScreen)
{
    mixin(damageScrPriv!("pScreen"));
    return &pScrPriv.funcs;
}

void DamageReportDamage(DamagePtr pDamage, RegionPtr pDamageRegion)
{
    BoxRec tmpBox = void;
    RegionRec tmpRegion = void;
    Bool was_empty = void;

    switch (pDamage.damageLevel) {
    case DamageReportRawRegion:
        RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
        (*pDamage.damageReport) (pDamage, pDamageRegion, pDamage.closure);
        break;
    case DamageReportDeltaRegion:
        RegionNull(&tmpRegion);
        RegionSubtract(&tmpRegion, pDamageRegion, &pDamage.damage);
        if (RegionNotEmpty(&tmpRegion)) {
            RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
            (*pDamage.damageReport) (pDamage, &tmpRegion, pDamage.closure);
        }
        RegionUninit(&tmpRegion);
        break;
    case DamageReportBoundingBox:
        tmpBox = *RegionExtents(&pDamage.damage);
        RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
        if (!mixin(BOX_SAME!(`&tmpBox`, `RegionExtents(&pDamage.damage)`))) {
            (*pDamage.damageReport) (pDamage, &pDamage.damage,
                                      pDamage.closure);
        }
        break;
    case DamageReportNonEmpty:
        was_empty = !RegionNotEmpty(&pDamage.damage);
        RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
        if (was_empty && RegionNotEmpty(&pDamage.damage)) {
            (*pDamage.damageReport) (pDamage, &pDamage.damage,
                                      pDamage.closure);
        }
        break;
    case DamageReportNone:
        RegionUnion(&pDamage.damage, &pDamage.damage, pDamageRegion);
        break;
    default: break;}
}
