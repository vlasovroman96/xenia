module mi.misprite;
@nogc nothrow:
extern(C): __gshared:
/*
 * misprite.c
 *
 * machine independent software sprite routines
 */

/*

Copyright 1989, 1998  The Open Group

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
*/

import build.dix_config;

//import   x11.X;
//import   x11.Xproto;
// //import   externs.X11.fonts.font;
// //import   externs.X11.fonts.fontstruct;

import   dix.colormap_priv;
import   dix.dix_priv;
import   dix.screen_hooks_priv;
import   mi.mipointer_priv;

import   include.misc;
import   include.pixmapstr;
import   include.input;
import   include.mi;
import   dix.cursor;
import   include.scrnintstr;
import include.windowstr;
import   include.gcstruct;
import   mi.mipointer;
import   mi.misprite;
import   include.dixfontstr;
import   dix.cursor;
import   include.damage;
import dix.events;
import dix.devices;
import include.input;
import dix.screen_hooks;
import mi.midispcur;

struct _MiCursorInfoRec {
    CursorPtr pCursor;
    int x;                      /* cursor hotspot */
    int y;
    BoxRec saved;               /* saved area from the screen */
    bool isUp;                  /* cursor in frame buffer */
    bool shouldBeUp;            /* cursor should be displayed */
    bool checkPixels;           /* check colormap collision */
    ScreenPtr pScreen;
}alias miCursorInfoRec = _MiCursorInfoRec;
alias miCursorInfoPtr = miCursorInfoRec*;

/*
 * per screen information
 */

struct _MiSpriteScreenRec {
    /* screen procedures */
    SourceValidateProcPtr SourceValidate;

    /* window procedures */
    CopyWindowProcPtr CopyWindow;

    /* colormap procedures */
    InstallColormapProcPtr InstallColormap;
    StoreColorsProcPtr StoreColors;

    /* os layer procedures */
    ScreenBlockHandlerProcPtr BlockHandler;

    xColorItem[2] colors;
    ColormapPtr pInstalledMap;
    ColormapPtr pColormap;
    VisualPtr pVisual;
    DamagePtr pDamage;          /* damage tracking structure */
    Bool damageRegistered;
    int numberOfCursors;
}alias miSpriteScreenRec = _MiSpriteScreenRec;
alias miSpriteScreenPtr = miSpriteScreenRec*;

enum SOURCE_COLOR =	0;
enum MASK_COLOR =	1;

/*
 * Overlap BoxPtr and Box elements
 */
enum string BOX_OVERLAP(string pCbox,string X1,string Y1,string X2,string Y2) = `
 	(((` ~ pCbox ~ `).x1 <= (` ~ X2 ~ `)) && ((` ~ X1 ~ `) <= (` ~ pCbox ~ `).x2) && 
	 ((` ~ pCbox ~ `).y1 <= (` ~ Y2 ~ `)) && ((` ~ Y1 ~ `) <= (` ~ pCbox ~ `).y2))`;

/*
 * Overlap BoxPtr, origins, and rectangle
 */
enum string ORG_OVERLAP(string pCbox,string xorg,string yorg,string x,string y,string w,string h) = `
    ` ~ BOX_OVERLAP!(`(` ~ pCbox ~ `)`,`(` ~ x ~ `)+(` ~ xorg ~ `)`,`(` ~ y ~ `)+(` ~ yorg ~ `)`,`(` ~ x ~ `)+(` ~ xorg ~ `)+(` ~ w ~ `)`,`(` ~ y ~ `)+(` ~ yorg ~ `)+(` ~ h ~ `)`) ~ ``;

/*
 * Overlap BoxPtr, origins and RectPtr
 */
enum string ORGRECT_OVERLAP(string pCbox,string xorg,string yorg,string pRect) = `
    ` ~ ORG_OVERLAP!(`(` ~ pCbox ~ `)`,`(` ~ xorg ~ `)`,`(` ~ yorg ~ `)`,`(` ~ pRect ~ `).x`,`(` ~ pRect ~ `).y`, 
		`cast(int)((` ~ pRect ~ `).width)`, `cast(int)((` ~ pRect ~ `).height)`) ~ ``;
/*
 * Overlap BoxPtr and horizontal span
 */
enum string SPN_OVERLAP(string pCbox,string y,string x,string w) = `` ~ BOX_OVERLAP!(`(` ~ pCbox ~ `)`,`(` ~ x ~ `)`,`(` ~ y ~ `)`,`(` ~ x ~ `)+(` ~ w ~ `)`,`(` ~ y ~ `)`) ~ ``;

enum string LINE_SORT(string x1,string y1,string x2,string y2) = `
{ int _t = void; 
  if (` ~ x1 ~ ` > ` ~ x2 ~ `) { _t = ` ~ x1 ~ `; ` ~ x1 ~ ` = ` ~ x2 ~ `; ` ~ x2 ~ ` = _t; } 
  if (` ~ y1 ~ ` > ` ~ y2 ~ `) { _t = ` ~ y1 ~ `; ` ~ y1 ~ ` = ` ~ y2 ~ `; ` ~ y2 ~ ` = _t; } }`;

enum string LINE_OVERLAP(string pCbox,string x1,string y1,string x2,string y2,string lw2) = `
    ` ~ BOX_OVERLAP!(`(` ~ pCbox ~ `)`, `(` ~ x1 ~ `)-(` ~ lw2 ~ `)`, `(` ~ y1 ~ `)-(` ~ lw2 ~ `)`, `(` ~ x2 ~ `)+(` ~ lw2 ~ `)`, `(` ~ y2 ~ `)+(` ~ lw2 ~ `)`) ~ ``;

enum SPRITE_DEBUG_ENABLE = 0;
static if (SPRITE_DEBUG_ENABLE) {
enum string SPRITE_DEBUG(string x) = `ErrorF x = void;`;
} else {
//#define SPRITE_DEBUG(x)
}

private DevPrivateKeyRec miSpriteScreenKeyRec;
private DevPrivateKeyRec miSpriteDevPrivatesKeyRec;

private miSpriteScreenPtr GetSpriteScreen(ScreenPtr pScreen)
{
    return cast(miSpriteScreenPtr)dixLookupPrivate(&pScreen.devPrivates, &miSpriteScreenKeyRec);
}

private miCursorInfoPtr GetSprite(DeviceIntPtr dev)
{
    if (InputDevIsFloating(dev))
       return cast(miCursorInfoPtr)dixLookupPrivate(&dev.devPrivates, &miSpriteDevPrivatesKeyRec);

    return cast(miCursorInfoPtr)dixLookupPrivate(&(GetMaster(dev, MASTER_POINTER)).devPrivates,
                            &miSpriteDevPrivatesKeyRec);
}

private void miSpriteDisableDamage(ScreenPtr pScreen, miSpriteScreenPtr pScreenPriv)
{
    if (pScreenPriv.damageRegistered) {
        DamageUnregister(pScreenPriv.pDamage);
        pScreenPriv.damageRegistered = 0;
    }
}

private void miSpriteEnableDamage(ScreenPtr pScreen, miSpriteScreenPtr pScreenPriv)
{
    if (!pScreenPriv.damageRegistered) {
        pScreenPriv.damageRegistered = 1;
        DamageRegister(&(pScreen.GetScreenPixmap(pScreen).drawable),
                       pScreenPriv.pDamage);
    }
}

private void miSpriteIsUp(miCursorInfoPtr pDevCursor)
{
    pDevCursor.isUp = TRUE;
}

private void miSpriteIsDown(miCursorInfoPtr pDevCursor)
{
    pDevCursor.isUp = FALSE;
}

/*
 * screen wrappers
 */













enum string SCREEN_PROLOGUE(string pPriv, string pScreen, string field) = `((` ~ pScreen ~ `).` ~ field ~ ` = 
   (` ~ pPriv ~ `).` ~ field ~ `);`;
enum string SCREEN_EPILOGUE(string pPriv, string pScreen, string field) = `
    ((`~pPriv~`).`~field~` = (`~pScreen~`).`~field~`, (`~pScreen~`).`~field~` = &miSprite`~field~`);`;

/*
 * pointer-sprite method table
 */






miPointerSpriteFuncRec miSpritePointerFuncs = {
    &miSpriteRealizeCursor,
    &miSpriteUnrealizeCursor,
    &miSpriteSetCursor,
    &miSpriteMoveCursor,
    &miSpriteDeviceCursorInitialize,
    &miSpriteDeviceCursorCleanup,
};

/*
 * other misc functions
 */





private void miSpriteRegisterBlockHandler(ScreenPtr pScreen, miSpriteScreenPtr pScreenPriv)
{
    if (!pScreenPriv.BlockHandler) {
        pScreenPriv.BlockHandler = pScreen.BlockHandler;
        pScreen.BlockHandler = &miSpriteBlockHandler;
    }
}

private void miSpriteReportDamage(DamagePtr pDamage, RegionPtr pRegion, void* closure)
{
    ScreenPtr pScreen = cast(ScreenPtr)closure;
    miCursorInfoPtr pCursorInfo = void;
    DeviceIntPtr pDev = void;

    for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if (DevHasCursor(pDev)) {
            pCursorInfo = GetSprite(pDev);

            if (pCursorInfo.isUp &&
                pCursorInfo.pScreen == pScreen &&
                RegionContainsRect(pRegion, &pCursorInfo.saved) != rgnOUT) {
                // SPRITE_DEBUG(("Damage remove\n"));
                miSpriteRemoveCursor(pDev, pScreen);
            }
        }
    }
}

/*
 * miSpriteInitialize -- called from device-dependent screen
 * initialization proc after all of the function pointers have
 * been stored in the screen structure.
 */
bool miSpriteInitialize(ScreenPtr pScreen, miPointerScreenFuncPtr screenFuncs)
{
    VisualPtr pVisual = void;

    if (!DamageSetup(pScreen))
        return FALSE;

    if (!dixRegisterPrivateKey(&miSpriteScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterPrivateKey
        (&miSpriteDevPrivatesKeyRec, PRIVATE_DEVICE, miCursorInfoRec.sizeof))
        return FALSE;

    miSpriteScreenPtr pScreenPriv = cast(miSpriteScreenRec*) calloc(1, miSpriteScreenRec.sizeof);
    if (!pScreenPriv)
        return FALSE;

    pScreenPriv.pDamage = DamageCreate(&miSpriteReportDamage,
                                        null,
                                        DamageReportRawRegion,
                                        TRUE, pScreen, pScreen);

    if (!miPointerInitialize(pScreen, &miSpritePointerFuncs, screenFuncs, TRUE)) {
        free(pScreenPriv);
        return FALSE;
    }
    for (pVisual = pScreen.visuals;
         pVisual.vid != pScreen.rootVisual; pVisual++){}
    pScreenPriv.pVisual = pVisual;
    pScreenPriv.SourceValidate = pScreen.SourceValidate;

    pScreenPriv.CopyWindow = pScreen.CopyWindow;

    pScreenPriv.InstallColormap = pScreen.InstallColormap;
    pScreenPriv.StoreColors = pScreen.StoreColors;

    pScreenPriv.BlockHandler = null;

    pScreenPriv.pInstalledMap = null;
    pScreenPriv.pColormap = null;
    pScreenPriv.colors[SOURCE_COLOR].red = 0;
    pScreenPriv.colors[SOURCE_COLOR].green = 0;
    pScreenPriv.colors[SOURCE_COLOR].blue = 0;
    pScreenPriv.colors[MASK_COLOR].red = 0;
    pScreenPriv.colors[MASK_COLOR].green = 0;
    pScreenPriv.colors[MASK_COLOR].blue = 0;
    pScreenPriv.damageRegistered = 0;
    pScreenPriv.numberOfCursors = 0;

    dixSetPrivate(&pScreen.devPrivates, &miSpriteScreenKeyRec, pScreenPriv);

    dixScreenHookClose(pScreen, &miSpriteCloseScreen);
    pScreen.SourceValidate = &miSpriteSourceValidate;

    pScreen.CopyWindow = &miSpriteCopyWindow;
    pScreen.InstallColormap = &miSpriteInstallColormap;
    pScreen.StoreColors = &miSpriteStoreColors;

    return TRUE;
}

/*
 * Screen wrappers
 */

private void miSpriteCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookClose(pScreen, &miSpriteCloseScreen);

    miSpriteScreenPtr pScreenPriv = GetSpriteScreen(pScreen);
    if (!pScreenPriv)
        return;

    pScreen.SourceValidate = pScreenPriv.SourceValidate;
    pScreen.InstallColormap = pScreenPriv.InstallColormap;
    pScreen.StoreColors = pScreenPriv.StoreColors;

    DamageDestroy(pScreenPriv.pDamage);

    dixSetPrivate(&pScreen.devPrivates, &miSpriteScreenKeyRec, null);
    free(pScreenPriv);
}

private void miSpriteSourceValidate(DrawablePtr pDrawable, int x, int y, int width, int height, uint subWindowMode)
{
    ScreenPtr pScreen = pDrawable.pScreen;
    DeviceIntPtr pDev = void;
    miCursorInfoPtr pCursorInfo = void;
    miSpriteScreenPtr pPriv = GetSpriteScreen(pScreen);

    mixin(SCREEN_PROLOGUE!(`pPriv`, `pScreen`, `SourceValidate`));

    if (pDrawable.type == DRAWABLE_WINDOW) {
        for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
            if (DevHasCursor(pDev)) {
                pCursorInfo = GetSprite(pDev);
                if (pCursorInfo.isUp && pCursorInfo.pScreen == pScreen &&
                    mixin(ORG_OVERLAP!(`&pCursorInfo.saved`, `pDrawable.x`, `pDrawable.y`,
                                `x`, `y`, `width`, `height`))) {
                    // SPRITE_DEBUG(("SourceValidate remove\n"));
                    miSpriteRemoveCursor(pDev, pScreen);
                }
            }
        }
    }

    (*pScreen.SourceValidate) (pDrawable, x, y, width, height,
                                subWindowMode);

    mixin(SCREEN_EPILOGUE!(`pPriv`, `pScreen`, `SourceValidate`));
}

private void miSpriteCopyWindow(WindowPtr pWindow, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    ScreenPtr pScreen = pWindow.drawable.pScreen;
    DeviceIntPtr pDev = void;
    miCursorInfoPtr pCursorInfo = void;
    miSpriteScreenPtr pPriv = GetSpriteScreen(pScreen);

    mixin(SCREEN_PROLOGUE!(`pPriv`, `pScreen`, `CopyWindow`));

    for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if (DevHasCursor(pDev)) {
            pCursorInfo = GetSprite(pDev);
            /*
             * Damage will take care of destination check
             */
            if (pCursorInfo.isUp && pCursorInfo.pScreen == pScreen &&
                RegionContainsRect(prgnSrc, &pCursorInfo.saved) != rgnOUT) {
                // SPRITE_DEBUG(("CopyWindow remove\n"));
                miSpriteRemoveCursor(pDev, pScreen);
            }
        }
    }

    (*pScreen.CopyWindow) (pWindow, ptOldOrg, prgnSrc);
    mixin(SCREEN_EPILOGUE!(`pPriv`, `pScreen`, `CopyWindow`));
}

private void miSpriteBlockHandler(ScreenPtr pScreen, void* timeout)
{
    miSpriteScreenPtr pPriv = GetSpriteScreen(pScreen);
    DeviceIntPtr pDev = void;
    miCursorInfoPtr pCursorInfo = void;
    Bool WorkToDo = FALSE;

    mixin(SCREEN_PROLOGUE!(`pPriv`, `pScreen`, `BlockHandler`));

    for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if (DevHasCursor(pDev)) {
            pCursorInfo = GetSprite(pDev);
            if (pCursorInfo && !pCursorInfo.isUp
                && pCursorInfo.pScreen == pScreen && pCursorInfo.shouldBeUp) {
                // SPRITE_DEBUG(("BlockHandler save"));
                miSpriteSaveUnderCursor(pDev, pScreen);
            }
        }
    }
    for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
        if (DevHasCursor(pDev)) {
            pCursorInfo = GetSprite(pDev);
            if (pCursorInfo && !pCursorInfo.isUp &&
                pCursorInfo.pScreen == pScreen && pCursorInfo.shouldBeUp) {
                // SPRITE_DEBUG(("BlockHandler restore\n"));
                miSpriteRestoreCursor(pDev, pScreen);
                if (!pCursorInfo.isUp)
                    WorkToDo = TRUE;
            }
        }
    }

    (*pScreen.BlockHandler) (pScreen, timeout);

    if (WorkToDo)
        mixin(SCREEN_EPILOGUE!(`pPriv`, `pScreen`, `BlockHandler`));
    else
        pPriv.BlockHandler = null;
}

private void miSpriteInstallColormap(ColormapPtr pMap)
{
    ScreenPtr pScreen = pMap.pScreen;
    miSpriteScreenPtr pPriv = GetSpriteScreen(pScreen);

    mixin(SCREEN_PROLOGUE!(`pPriv`, `pScreen`, `InstallColormap`));

    (*pScreen.InstallColormap) (pMap);

    mixin(SCREEN_EPILOGUE!(`pPriv`, `pScreen`, `InstallColormap`));

    /* InstallColormap can be called before devices are initialized. */
    pPriv.pInstalledMap = pMap;
    if (pPriv.pColormap != pMap) {
        DeviceIntPtr pDev = void;
        miCursorInfoPtr pCursorInfo = void;

        for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
            if (DevHasCursor(pDev)) {
                pCursorInfo = GetSprite(pDev);
                pCursorInfo.checkPixels = TRUE;
                if (pCursorInfo.isUp && pCursorInfo.pScreen == pScreen)
                    miSpriteRemoveCursor(pDev, pScreen);
            }
        }

    }
}

private void miSpriteStoreColors(ColormapPtr pMap, int ndef, xColorItem* pdef)
{
    ScreenPtr pScreen = pMap.pScreen;
    miSpriteScreenPtr pPriv = GetSpriteScreen(pScreen);
    int i = void;
    int updated = void;
    VisualPtr pVisual = void;
    DeviceIntPtr pDev = void;
    miCursorInfoPtr pCursorInfo = void;

    mixin(SCREEN_PROLOGUE!(`pPriv`, `pScreen`, `StoreColors`));

    (*pScreen.StoreColors) (pMap, ndef, pdef);

    mixin(SCREEN_EPILOGUE!(`pPriv`, `pScreen`, `StoreColors`));

    if (pPriv.pColormap == pMap) {
        updated = 0;
        pVisual = pMap.pVisual;
        if (pVisual.class_ == DirectColor) {
            /* Direct color - match on any of the subfields */

enum string MaskMatch(string a,string b,string mask) = `(((` ~ a ~ `) & (pVisual.` ~ mask ~ `)) == ((` ~ b ~ `) & (pVisual.` ~ mask ~ `)))`;

enum string UpdateDAC(string dev, string plane,string dac,string mask) = `{
    if (` ~ MaskMatch! (`` ~ dev ~ `.colors[` ~ plane ~ `].pixel`,`pdef[i].pixel`,mask) ~ `) {
	` ~ dev ~ `.colors[` ~ plane ~ `].` ~ dac ~ ` = pdef[i].` ~ dac ~ `; 
	updated = 1; 
    } 
}`;

enum string CheckDirect(string dev, string plane) = `
	    ` ~ UpdateDAC!(dev, plane,`red`,`redMask`) ~ ` 
	    ` ~ UpdateDAC!(dev, plane,`green`,`greenMask`) ~ ` 
	    ` ~ UpdateDAC!(dev, plane,`blue`,`blueMask`) ~ ``;

            for (i = 0; i < ndef; i++) {
                mixin(CheckDirect!(`pPriv`, `SOURCE_COLOR`));
                    mixin(CheckDirect!(`pPriv`, `MASK_COLOR`));
            }
        }
        else {
            /* PseudoColor/GrayScale - match on exact pixel */
            for (i = 0; i < ndef; i++) {
                if (pdef[i].pixel == pPriv.colors[SOURCE_COLOR].pixel) {
                    pPriv.colors[SOURCE_COLOR] = pdef[i];
                    if (++updated == 2)
                        break;
                }
                if (pdef[i].pixel == pPriv.colors[MASK_COLOR].pixel) {
                    pPriv.colors[MASK_COLOR] = pdef[i];
                    if (++updated == 2)
                        break;
                }
            }
        }
        if (updated) {
            for (pDev = inputInfo.devices; pDev; pDev = pDev.next) {
                if (DevHasCursor(pDev)) {
                    pCursorInfo = GetSprite(pDev);
                    pCursorInfo.checkPixels = TRUE;
                    if (pCursorInfo.isUp && pCursorInfo.pScreen == pScreen)
                        miSpriteRemoveCursor(pDev, pScreen);
                }
            }
        }
    }
}

private void miSpriteFindColors(miCursorInfoPtr pDevCursor, ScreenPtr pScreen)
{
    miSpriteScreenPtr pScreenPriv = GetSpriteScreen(pScreen);
    CursorPtr pCursor = void;
    xColorItem* sourceColor = void, maskColor = void;

    pCursor = pDevCursor.pCursor;
    sourceColor = &pScreenPriv.colors[SOURCE_COLOR];
    maskColor = &pScreenPriv.colors[MASK_COLOR];
    if (pScreenPriv.pColormap != pScreenPriv.pInstalledMap ||
        !(pCursor.foreRed == sourceColor.red &&
          pCursor.foreGreen == sourceColor.green &&
          pCursor.foreBlue == sourceColor.blue &&
          pCursor.backRed == maskColor.red &&
          pCursor.backGreen == maskColor.green &&
          pCursor.backBlue == maskColor.blue)) {
        pScreenPriv.pColormap = pScreenPriv.pInstalledMap;
        sourceColor.red = pCursor.foreRed;
        sourceColor.green = pCursor.foreGreen;
        sourceColor.blue = pCursor.foreBlue;
        FakeAllocColor(pScreenPriv.pColormap, sourceColor);
        maskColor.red = pCursor.backRed;
        maskColor.green = pCursor.backGreen;
        maskColor.blue = pCursor.backBlue;
        FakeAllocColor(pScreenPriv.pColormap, maskColor);
        /* "free" the pixels right away, don't let this confuse you */
        FakeFreeColor(pScreenPriv.pColormap, sourceColor.pixel);
        FakeFreeColor(pScreenPriv.pColormap, maskColor.pixel);
    }

    pDevCursor.checkPixels = FALSE;

}

/*
 * miPointer interface routines
 */

enum SPRITE_PAD =  8;

private Bool miSpriteRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    miCursorInfoPtr pCursorInfo = void;

    if (InputDevIsFloating(pDev))
        return FALSE;

    pCursorInfo = GetSprite(pDev);

    if (pCursor is pCursorInfo.pCursor)
        pCursorInfo.checkPixels = TRUE;

    return (!!miDCRealizeCursor(pScreen, pCursor));
}

private Bool miSpriteUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    return (!!miDCUnrealizeCursor(pScreen, pCursor));
}

private void miSpriteSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, int x, int y)
{
    miCursorInfoPtr pPointer = void;
    miSpriteScreenPtr pScreenPriv = void;

    if (InputDevIsFloating(pDev))
        return;

    pPointer = GetSprite(pDev);
    pScreenPriv = GetSpriteScreen(pScreen);

    if (!pCursor) {
        if (pPointer.shouldBeUp)
            --pScreenPriv.numberOfCursors;
        pPointer.shouldBeUp = FALSE;
        if (pPointer.isUp)
            miSpriteRemoveCursor(pDev, pScreen);
        if (pScreenPriv.numberOfCursors == 0)
            miSpriteDisableDamage(pScreen, pScreenPriv);
        pPointer.pCursor = null;
        return;
    }
    if (!pPointer.shouldBeUp)
        pScreenPriv.numberOfCursors++;
    pPointer.shouldBeUp = TRUE;
    if (!pPointer.isUp)
        miSpriteRegisterBlockHandler(pScreen, pScreenPriv);
    if (pPointer.x == x &&
        pPointer.y == y &&
        pPointer.pCursor is pCursor && !pPointer.checkPixels) {
        return;
    }
    pPointer.x = x;
    pPointer.y = y;
    if (pPointer.checkPixels || pPointer.pCursor != pCursor) {
        pPointer.pCursor = pCursor;
        miSpriteFindColors(pPointer, pScreen);
    }
    if (pPointer.isUp) {
        /* TODO: reimplement flicker-free MoveCursor */
        // SPRITE_DEBUG(("SetCursor remove %d\n", pDev.id));
        miSpriteRemoveCursor(pDev, pScreen);
    }

    if (!pPointer.isUp && pPointer.pCursor) {
        // SPRITE_DEBUG(("SetCursor restore %d\n", pDev.id));
        miSpriteSaveUnderCursor(pDev, pScreen);
        miSpriteRestoreCursor(pDev, pScreen);
    }

}

private void miSpriteMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    CursorPtr pCursor = void;

    if (InputDevIsFloating(pDev))
        return;

    pCursor = GetSprite(pDev).pCursor;

    miSpriteSetCursor(pDev, pScreen, pCursor, x, y);
}

private Bool miSpriteDeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    int ret = miDCDeviceInitialize(pDev, pScreen);

    if (ret) {
        miCursorInfoPtr pCursorInfo = void;

        pCursorInfo =
            cast(miCursorInfoPtr)dixLookupPrivate(&pDev.devPrivates, &miSpriteDevPrivatesKeyRec);
        pCursorInfo.pCursor = null;
        pCursorInfo.x = 0;
        pCursorInfo.y = 0;
        pCursorInfo.isUp = FALSE;
        pCursorInfo.shouldBeUp = FALSE;
        pCursorInfo.checkPixels = TRUE;
        pCursorInfo.pScreen = null;
    }

    return ret;
}

private void miSpriteDeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    miCursorInfoPtr pCursorInfo = cast(miCursorInfoPtr)dixLookupPrivate(&pDev.devPrivates, &miSpriteDevPrivatesKeyRec);

    if (DevHasCursor(pDev))
        miDCDeviceCleanup(pDev, pScreen);

    memset(pCursorInfo, 0, miCursorInfoRec.sizeof);
}

/*
 * undraw/draw cursor
 */

private void miSpriteRemoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    miSpriteScreenPtr pScreenPriv = void;
    miCursorInfoPtr pCursorInfo = void;

    if (InputDevIsFloating(pDev))
        return;

    DamageDrawInternal(pScreen, TRUE);
    pScreenPriv = GetSpriteScreen(pScreen);
    pCursorInfo = GetSprite(pDev);

    miSpriteIsDown(pCursorInfo);
    miSpriteRegisterBlockHandler(pScreen, pScreenPriv);
    miSpriteDisableDamage(pScreen, pScreenPriv);
    if (!miDCRestoreUnderCursor(pDev,
                                pScreen,
                                pCursorInfo.saved.x1,
                                pCursorInfo.saved.y1,
                                pCursorInfo.saved.x2 -
                                pCursorInfo.saved.x1,
                                pCursorInfo.saved.y2 -
                                pCursorInfo.saved.y1)) {
        miSpriteIsUp(pCursorInfo);
    }
    miSpriteEnableDamage(pScreen, pScreenPriv);
    DamageDrawInternal(pScreen, FALSE);
}

/*
 * Called from the block handler, saves area under cursor
 * before waiting for something to do.
 */

private void miSpriteSaveUnderCursor(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    miSpriteScreenPtr pScreenPriv = void;
    miCursorInfoPtr pCursorInfo = void;

    if (InputDevIsFloating(pDev))
        return;

    DamageDrawInternal(pScreen, TRUE);
    pScreenPriv = GetSpriteScreen(pScreen);
    pCursorInfo = GetSprite(pDev);

    miSpriteComputeSaved(pDev, pScreen);

    miSpriteDisableDamage(pScreen, pScreenPriv);

    miDCSaveUnderCursor(pDev,
                        pScreen,
                        pCursorInfo.saved.x1,
                        pCursorInfo.saved.y1,
                        pCursorInfo.saved.x2 -
                        pCursorInfo.saved.x1,
                        pCursorInfo.saved.y2 - pCursorInfo.saved.y1);
    // SPRITE_DEBUG(("SaveUnderCursor %d\n", pDev.id));
    miSpriteEnableDamage(pScreen, pScreenPriv);
    DamageDrawInternal(pScreen, FALSE);
}

/*
 * Called from the block handler, restores the cursor
 * before waiting for something to do.
 */

private void miSpriteRestoreCursor(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    miSpriteScreenPtr pScreenPriv = void;
    int x = void, y = void;
    CursorPtr pCursor = void;
    miCursorInfoPtr pCursorInfo = void;

    if (InputDevIsFloating(pDev))
        return;

    DamageDrawInternal(pScreen, TRUE);
    pScreenPriv = GetSpriteScreen(pScreen);
    pCursorInfo = GetSprite(pDev);

    miSpriteComputeSaved(pDev, pScreen);
    pCursor = pCursorInfo.pCursor;

    x = pCursorInfo.x - cast(int) pCursor.bits.xhot;
    y = pCursorInfo.y - cast(int) pCursor.bits.yhot;
    miSpriteDisableDamage(pScreen, pScreenPriv);
    // SPRITE_DEBUG(("RestoreCursor %d\n", pDev.id));
    if (pCursorInfo.checkPixels)
        miSpriteFindColors(pCursorInfo, pScreen);
    if (miDCPutUpCursor(pDev, pScreen,
                        pCursor, x, y,
                        pScreenPriv.colors[SOURCE_COLOR].pixel,
                        pScreenPriv.colors[MASK_COLOR].pixel)) {
        miSpriteIsUp(pCursorInfo);
        pCursorInfo.pScreen = pScreen;
    }
    miSpriteEnableDamage(pScreen, pScreenPriv);
    DamageDrawInternal(pScreen, FALSE);
}

/*
 * compute the desired area of the screen to save
 */

private void miSpriteComputeSaved(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    int x = void, y = void, w = void, h = void;
    int wpad = void, hpad = void;
    CursorPtr pCursor = void;
    miCursorInfoPtr pCursorInfo = void;

    if (InputDevIsFloating(pDev))
        return;

    pCursorInfo = GetSprite(pDev);

    pCursor = pCursorInfo.pCursor;
    x = pCursorInfo.x - cast(int) pCursor.bits.xhot;
    y = pCursorInfo.y - cast(int) pCursor.bits.yhot;
    w = pCursor.bits.width;
    h = pCursor.bits.height;
    wpad = SPRITE_PAD;
    hpad = SPRITE_PAD;
    pCursorInfo.saved.x1 = cast(short)(x - wpad);
    pCursorInfo.saved.y1 = cast(short)(y - hpad);
    pCursorInfo.saved.x2 = cast(short)(pCursorInfo.saved.x1 + w + wpad * 2);
    pCursorInfo.saved.y2 = cast(short)(pCursorInfo.saved.y1 + h + hpad * 2);
}
