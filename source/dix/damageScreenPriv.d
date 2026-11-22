module dix.damageScreenPriv;

@nogc: nothrow:
extern(C):

import dix.pixmap;
import dix.damage;

alias DamageScreenCreateFunc = void function(DamagePtr);
alias DamageScreenRegisterFunc = void function(DrawablePtr, DamagePtr);
alias DamageScreenUnregisterFunc = void function(DrawablePtr, DamagePtr);
alias DamageScreenDestroyFunc = void function(DamagePtr);

struct DamageScreenFuncs {
    DamageScreenCreateFunc Create;
    DamageScreenRegisterFunc Register;
    DamageScreenUnregisterFunc Unregister;
    DamageScreenDestroyFunc Destroy;
}
alias DamageScreenFuncsPtr = DamageScreenFuncs*;

struct DamageScrPrivRec {
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
    DamageScreenFuncs funcs;
}
alias DamageScrPrivPtr = DamageScrPrivRec*;

struct DamageGCPrivRec {
    const(_GCOps)* ops;
    const(GCFuncs)* funcs;
}
alias DamageGCPrivRecPtr = DamageGCPrivRec*;

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
    cast(DamageGCPrivRec*)dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, damageGCPrivateKey)`;

enum string damageGCPriv(string pGC) = `
    DamageGCPrivRecPtr pGCPriv = ` ~ damageGetGCPriv!(pGC) ~ `;`;

enum string damageGetWinPriv(string pWin) = `
    (cast(DamagePtr)dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, damageWinPrivateKey))`;

enum string damageSetWinPriv(string pWin,string d) = `
    dixSetPrivate(&(` ~ pWin ~ `).devPrivates, damageWinPrivateKey, ` ~ d ~ `)`;

                          /* _DAMAGESTR_H_ */