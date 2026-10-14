module dix.damage;
@nogc nothrow:
extern(C): __gshared:
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
alias DamagePtr = _damage*;
 
public import include.gcstruct;
public import include.privates;
public import include.picturestr;

struct _damage {
    DamagePtr pNext;
    DamagePtr pNextWin;
    RegionRec damage;

    DamageReportLevel damageLevel;
    Bool isInternal;
    void* closure;
    Bool isWindow;
    DrawablePtr pDrawable;

    DamageReportFunc damageReport;
    DamageDestroyFunc damageDestroy;

    Bool reportAfter;
    RegionRec pendingDamage;    /* will be flushed post submission at the latest */
    ScreenPtr pScreen;
}

struct _damageScreenFuncs {
    DamageScreenCreateFunc Create;
    DamageScreenRegisterFunc Register;
    DamageScreenUnregisterFunc Unregister;
    DamageScreenDestroyFunc Destroy;
}alias DamageScreenFuncsRec = _damageScreenFuncs;
alias DamageScreenFuncsPtr = _damageScreenFuncs*;

import include.regionstr;
import include.screenint;
import include.privates;
public import miext.damage.damage_;
import dix.damage;

// struct _Damage;

enum DamageReportLevel : ubyte {
    DamageReportRawRegion,
    DamageReportDeltaRegion,
    DamageReportBoundingBox,
    DamageReportNonEmpty,
    DamageReportNone
}
alias DamageReportRawRegion = DamageReportLevel.DamageReportRawRegion;
alias DamageReportDeltaRegion = DamageReportLevel.DamageReportDeltaRegion;
alias DamageReportBoundingBox = DamageReportLevel.DamageReportBoundingBox;
alias DamageReportNonEmpty = DamageReportLevel.DamageReportNonEmpty;
alias DamageReportNone = DamageReportLevel.DamageReportNone;

// struct _Region;
// alias RegionPtr = _Region*;
alias DamageReportFunc = void function(DamagePtr pDamage, RegionPtr pRegion, void* closure);
alias DamageDestroyFunc = void function(DamagePtr pDamage, void* closure);

struct _Drawable;
// alias DrawablePtr = _Drawable*;
alias DamageScreenCreateFunc = void function(DamagePtr);
alias DamageScreenRegisterFunc = void function(DrawablePtr, DamagePtr);
alias DamageScreenUnregisterFunc = void function(DrawablePtr, DamagePtr);
alias DamageScreenDestroyFunc = void function(DamagePtr);

alias DamageRec = _damage;

struct _damageScrPriv {
    int internalLevel;

    /*
     * For DDXen which don't provide GetScreenPixmap, this provides
     * a place to hook damage for windows on the screen
     */
    DamagePtr pScreenDamage;

    CopyWindowProcPtr CopyWindow;
    void* _dummy1; // required in place of a removed field for ABI compatibility
    CreateGCProcPtr CreateGC;
    void* _dummy2; // required in place of a removed field for ABI compatibility
    SetWindowPixmapProcPtr SetWindowPixmap;
    void* _dummy3; // required in place of a removed field for ABI compatibility
    CompositeProcPtr Composite;
    GlyphsProcPtr Glyphs;
    AddTrapsProcPtr AddTraps;

    /* Table of wrappable function pointers */
    DamageScreenFuncsRec funcs;
}alias DamageScrPrivRec = _damageScrPriv;
alias DamageScrPrivPtr = _damageScrPriv*;

struct _damageGCPriv {
    const(_GCOps)* ops;
    const(GCFuncs)* funcs;
}alias DamageGCPrivRec = _damageGCPriv;
alias DamageGCPrivPtr = _damageGCPriv*;

/* XXX should move these into damage.c, damageScrPrivateIndex is static */
enum string damageGetScrPriv(string pScr) = `(cast(DamageScrPrivPtr) 
    dixLookupPrivate(&(` ~ pScr ~ `).devPrivates, damageScrPrivateKey))`;

enum string damageScrPriv(string pScr) = `
    DamageScrPrivPtr pScrPriv = ` ~ damageGetScrPriv!(pScr) ~ `;`;

enum string damageGetPixPriv(string pPix) = `
    dixLookupPrivate(&(` ~ pPix ~ `).devPrivates, damagePixPrivateKey)`;

enum string damgeSetPixPriv(string pPix,string v) = `
    dixSetPrivate(&(` ~ pPix ~ `).devPrivates, damagePixPrivateKey, ` ~ v ~ `)`;

enum string damagePixPriv(string pPix) = `
    DamagePtr pDamage = ` ~ damageGetPixPriv!(pPix) ~ `;`;

enum string damageGetGCPriv(string pGC) = `
    cast(_damageGCPriv*)dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, damageGCPrivateKey)`;

enum string damageGCPriv(string pGC) = `
    DamageGCPrivPtr pGCPriv = ` ~ damageGetGCPriv!(pGC) ~ `;`;

enum string damageGetWinPriv(string pWin) = `
    (cast(DamagePtr)dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, damageWinPrivateKey))`;

enum string damageSetWinPriv(string pWin,string d) = `
    dixSetPrivate(&(` ~ pWin ~ `).devPrivates, damageWinPrivateKey, ` ~ d ~ `)`;

                          /* _DAMAGESTR_H_ */
