module dix.screen_hooks;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

import build.dix_config;

//import x11.Xdefs;

import dix.dix_priv;
import dix.screen_hooks_priv;
import os.os;
import include.scrnintstr;
import include.windowstr;

// mixin template DECLARE_HOOK_PROC(string NAME, alias FIELD, alias TYPE) {
    
// }

enum string DECLARE_HOOK_PROC(string NAME, string FIELD, string TYPE) = `
    void dixScreenHook`~NAME~`(ScreenPtr pScreen, `~TYPE~` func) 
    { 
        AddCallback(&pScreen.`~FIELD~`, cast(CallbackProcPtr)func, pScreen); 
    } 
    
    void dixScreenUnhook`~NAME~`(ScreenPtr pScreen, `~TYPE~` func) 
    { 
        DeleteCallback(&pScreen.`~FIELD~`, cast(CallbackProcPtr)func, pScreen); 
    }`;

mixin(DECLARE_HOOK_PROC!(`WindowDestroy`, `hookWindowDestroy`, `XorgScreenWindowDestroyProcPtr`));
mixin(DECLARE_HOOK_PROC!(`WindowPosition`, `hookWindowPosition`, `XorgScreenWindowPositionProcPtr`));
mixin(DECLARE_HOOK_PROC!(`Close`, `hookClose`, `XorgScreenCloseProcPtr`));
mixin(DECLARE_HOOK_PROC!(`PostClose`, `hookPostClose`, `XorgScreenCloseProcPtr`));
mixin(DECLARE_HOOK_PROC!(`PixmapDestroy`, `hookPixmapDestroy`, `XorgScreenPixmapDestroyProcPtr`));
mixin(DECLARE_HOOK_PROC!(`PostCreateResources`, `hookPostCreateResources`,
                  `XorgScreenPostCreateResourcesProcPtr`));
                  pragma(msg, DECLARE_HOOK_PROC!(
    `Close`,
    `hookClose`,
    `XorgScreenCloseProcPtr`
));
// mixin(DECLARE_HOOK_PROC!(``, `hookPostCreateResources`,
// `XorgScreenPostCreateResourcesProcPtr`));

int dixScreenRaiseWindowDestroy(WindowPtr pWin)
{
    if (!pWin)
        return Success;

    ScreenPtr pScreen = pWin.drawable.pScreen;

    CallCallbacks(&pScreen.hookWindowDestroy, pWin);

    return (pScreen.DestroyWindow ? pScreen.DestroyWindow(pWin) : Success);
}

void dixScreenRaiseWindowPosition(WindowPtr pWin, uint x, uint y)
{
    if (!pWin)
        return;

    ScreenPtr pScreen = pWin.drawable.pScreen;

    XorgScreenWindowPositionParamRec param = {
        window: pWin,
        x: x,
        y: y,
    };

    CallCallbacks(&pScreen.hookWindowPosition, &param);

    if (pScreen.PositionWindow)
        pScreen.PositionWindow(pWin, x, y);
}

void dixScreenRaiseClose(ScreenPtr pScreen) {
    if (!pScreen)
        return;

    CallCallbacks(&pScreen.hookClose, null);

    if (pScreen.CloseScreen)
        pScreen.CloseScreen(pScreen);

    CallCallbacks(&pScreen.hookPostClose, null);
}

void dixScreenRaisePixmapDestroy(PixmapPtr pPixmap)
{
    if (!pPixmap)
        return;

    ScreenPtr pScreen = pPixmap.drawable.pScreen;
    CallCallbacks(&pScreen.hookPixmapDestroy, pPixmap);
    /* we must not call the original ScreenRec->DestroyPixmap() here */
}

Bool dixScreenRaiseCreateResources(ScreenPtr pScreen)
{
    if (!pScreen)
        return FALSE;

    if (pScreen.CreateScreenResources) {
        if (!pScreen.CreateScreenResources(pScreen))
            return FALSE;
    }

    Bool ret = TRUE;
    CallCallbacks(&pScreen.hookPostCreateResources, &ret);
    return ret;
}

void dixScreenRaiseUnrealizeWindow(WindowPtr pWin)
{
    if (!pWin)
        return;

    pWin.realized = FALSE;
    if (pWin.drawable.pScreen.UnrealizeWindow)
        pWin.drawable.pScreen.UnrealizeWindow(pWin);
}

Bool dixScreenRaiseDisplayCursor(ScreenPtr pScreen, DeviceIntPtr pDev, CursorPtr pCursor)
{
    /* for now just calling the screen proc, but in the future we'll also handle hide
       counters and animations here, so we don't need fragile proc wrapping anymore */
    if (pScreen && pScreen.DisplayCursor)
        return pScreen.DisplayCursor(pDev, pScreen, pCursor);
    return FALSE;
}
