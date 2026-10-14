module mi.mipointer;
@nogc nothrow:
extern(C): __gshared:
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

/**
 * @file
 * This file contains functions to move the pointer on the screen and/or
 * restrict its movement. These functions are divided into two sets:
 * Screen-specific functions that are used as function pointers from other
 * parts of the server (and end up heavily wrapped by e.g. animcur and
 * xfixes):
 *      miPointerConstrainCursor
 *      miPointerCursorLimits
 *      miPointerDisplayCursor
 *      miPointerRealizeCursor
 *      miPointerUnrealizeCursor
 *      miPointerSetCursorPosition
 *      miRecolorCursor
 *      miPointerDeviceInitialize
 *      miPointerDeviceCleanup
 * If wrapped, these are the last element in the wrapping chain. They may
 * call into sprite-specific code through further function pointers though.
 *
 * The second type of functions are those that are directly called by the
 * DIX, DDX and some drivers.
 */

import build.dix_config;

//import   x11.X;
//import   x11.Xmd;
//import   x11.Xproto;

import   dix.cursor_priv;
import   dix.dix_priv;
import   dix.input_priv;
import   dix.inpututils_priv;
import   dix.screen_hooks_priv;
import   include.extinit;
import   mi.mi_priv;
import   mi.mipointer_priv;
import os.inputthread;

import   include.misc;
import include.windowstr;
import   include.pixmapstr;
import   include.scrnintstr;
import   include.mipointrst;
import   dix.cursor;
import include.dixstruct;
import   include.inputstr;
import   include.eventstr;
import dix.screen_hooks;
import dix.events;
import dix.devices;
import dix.enterleave;
import dix.inpututils;
import os.log;



struct _MiPointerRec {
    ScreenPtr pScreen;          /* current screen */
    ScreenPtr pSpriteScreen;    /* screen containing current sprite */
    CursorPtr pCursor;          /* current cursor */
    CursorPtr pSpriteCursor;    /* cursor on screen */
    BoxRec limits;              /* current constraints */
    Bool confined;              /* pointer can't change screens */
    int x, y;                   /* hot spot location */
    int devx, devy;             /* sprite position */
    Bool generateEvent;         /* generate an event during warping? */
}alias miPointerRec = _MiPointerRec;
alias miPointerPtr = miPointerRec*;

// DevPrivateKeyRec miPointerScreenKeyRec;

enum string GetScreenPrivate(string s) = `(cast(miPointerScreenPtr) 
    dixLookupPrivate(&(` ~ s ~ `).devPrivates, miPointerScreenKey))`;
enum string SetupScreen(string s) = `miPointerScreenPtr pScreenPriv = ` ~ GetScreenPrivate!(s) ~ `;`;

// DevPrivateKeyRec miPointerPrivKeyRec;

enum string MIPOINTER(string dev) = `
    (InputDevIsFloating(` ~ dev ~ `) ? 
        cast(miPointerPtr)dixLookupPrivate(&(` ~ dev ~ `).devPrivates, miPointerPrivKey): 
        cast(miPointerPtr)dixLookupPrivate(&(GetMaster(` ~ dev ~ `, MASTER_POINTER)).devPrivates, miPointerPrivKey))`;













private InternalEvent* mipointermove_events;   /* for WarpPointer MotionNotifies */



Bool miPointerInitialize(ScreenPtr pScreen, miPointerSpriteFuncPtr spriteFuncs, miPointerScreenFuncPtr screenFuncs, Bool waitForUpdate)
{
    miPointerScreenPtr pScreenPriv = void;

    if (!dixRegisterPrivateKey(&miPointerScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&miPointerPrivKeyRec, PRIVATE_DEVICE, 0))
        return FALSE;

    pScreenPriv = cast(miPointerScreenRec*) calloc(1, miPointerScreenRec.sizeof);
    if (!pScreenPriv)
        return FALSE;
    pScreenPriv.spriteFuncs = spriteFuncs;
    pScreenPriv.screenFuncs = screenFuncs;
    pScreenPriv.waitForUpdate = waitForUpdate;
    pScreenPriv.showTransparent = FALSE;
    dixScreenHookPostClose(pScreen, &miPointerCloseScreen);
    dixSetPrivate(&pScreen.devPrivates, miPointerScreenKey, pScreenPriv);
    /*
     * set up screen cursor method table
     */
    pScreen.ConstrainCursor = &miPointerConstrainCursor;
    pScreen.CursorLimits = &miPointerCursorLimits;
    pScreen.DisplayCursor = &miPointerDisplayCursor;
    pScreen.RealizeCursor = &miPointerRealizeCursor;
    pScreen.UnrealizeCursor = &miPointerUnrealizeCursor;
    pScreen.SetCursorPosition = &miPointerSetCursorPosition;
    pScreen.RecolorCursor = &miRecolorCursor;
    pScreen.DeviceCursorInitialize = &miPointerDeviceInitialize;
    pScreen.DeviceCursorCleanup = &miPointerDeviceCleanup;

    mipointermove_events = null;
    return TRUE;
}

/**
 * Destroy screen-specific information.
 *
 * @param pScreen The actual screen pointer
 */
private void miPointerCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    mixin(SetupScreen!(`pScreen`));

    dixScreenUnhookPostClose(pScreen, &miPointerCloseScreen);
    free(cast(void*) pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, miPointerScreenKey, null);
    FreeEventList(mipointermove_events, GetMaximumEventsNum());
    mipointermove_events = null;
}

/*
 * DIX/DDX interface routines
 */

private Bool miPointerRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    mixin(SetupScreen!(`pScreen`));
    return (*pScreenPriv.spriteFuncs.RealizeCursor) (pDev, pScreen, pCursor);
}

private Bool miPointerUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    mixin(SetupScreen!(`pScreen`));
    return (*pScreenPriv.spriteFuncs.UnrealizeCursor) (pDev, pScreen,
                                                         pCursor);
}

private Bool miPointerDisplayCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    miPointerPtr pPointer = void;

    /* return for keyboards */
    if (!IsPointerDevice(pDev))
        return FALSE;

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return FALSE;

    pPointer.pCursor = pCursor;
    pPointer.pScreen = pScreen;
    miPointerUpdateSprite(pDev);
    return TRUE;
}

/**
 * Set up the constraints for the given device. This function does not
 * actually constrain the cursor but merely copies the given box to the
 * internal constraint storage.
 *
 * @param pDev The device to constrain to the box
 * @param pBox The rectangle to constrain the cursor to
 * @param pScreen Used for copying screen confinement
 */
private void miPointerConstrainCursor(DeviceIntPtr pDev, ScreenPtr pScreen, BoxPtr pBox)
{
    miPointerPtr pPointer = void;

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return;

    pPointer.limits = *pBox;
    pPointer.confined = PointerConfinedToScreen(pDev);
}

/**
 * Should calculate the box for the given cursor, based on screen and the
 * confinement given. But we assume that whatever box is passed in is valid
 * anyway.
 *
 * @param pDev The device to calculate the cursor limits for
 * @param pScreen The screen the confinement happens on
 * @param pCursor The screen the confinement happens on
 * @param pHotBox The confinement box for the cursor
 * @param[out] pTopLeftBox The new confinement box, always *pHotBox.
 */
private void miPointerCursorLimits(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, BoxPtr pHotBox, BoxPtr pTopLeftBox)
{
    *pTopLeftBox = *pHotBox;
}

/**
 * Set the device's cursor position to the x/y position on the given screen.
 * Generates and event if required.
 *
 * This function is called from:
 *    - sprite init code to place onto initial position
 *    - the various WarpPointer implementations (core, XI, Xinerama,…)
 *    - during the cursor update path in CheckMotion
 *    - in the Xinerama part of NewCurrentScreen
 *    - when a RandR/RandR1.2 mode was applied (it may have moved the pointer, so
 *      it's set back to the original pos)
 *
 * @param pDev The device to move
 * @param pScreen The screen the device is on
 * @param x The x coordinate in per-screen coordinates
 * @param y The y coordinate in per-screen coordinates
 * @param generateEvent True if the pointer movement should generate an
 * event.
 *
 * @return TRUE in all cases
 */
private Bool miPointerSetCursorPosition(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, Bool generateEvent)
{
    mixin(SetupScreen!(`pScreen`));
    miPointerPtr pPointer = mixin(MIPOINTER!(`pDev`));

    if (!pPointer)
        return TRUE;

    pPointer.generateEvent = generateEvent;

    if (pScreen.ConstrainCursorHarder)
        pScreen.ConstrainCursorHarder(pDev, pScreen, Absolute, &x, &y);

    /* device dependent - must pend signal and call miPointerWarpCursor */
    (*pScreenPriv.screenFuncs.WarpCursor) (pDev, pScreen, x, y);
    if (!generateEvent)
        miPointerUpdateSprite(pDev);
    return TRUE;
}

private void miRecolorCursor(DeviceIntPtr pDev, ScreenPtr pScr, CursorPtr pCurs, Bool displayed)
{
    /*
     * This is guaranteed to correct any color-dependent state which may have
     * been bound up in private state created by RealizeCursor
     */
    pScr.UnrealizeCursor(pDev, pScr, pCurs);
    pScr.RealizeCursor(pDev, pScr, pCurs);
    if (displayed)
        pScr.DisplayCursor(pDev, pScr, pCurs);
}

/**
 * Set up sprite information for the device.
 * This function will be called once for each device after it is initialized
 * in the DIX.
 *
 * @param pDev The newly created device
 * @param pScreen The initial sprite scree.
 */
private Bool miPointerDeviceInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    mixin(SetupScreen!(`pScreen`));

    miPointerPtr pPointer = cast(miPointerRec*) calloc(1, miPointerRec.sizeof);
    if (!pPointer)
        return FALSE;

    pPointer.pScreen = null;
    pPointer.pSpriteScreen = null;
    pPointer.pCursor = null;
    pPointer.pSpriteCursor = null;
    pPointer.limits.x1 = 0;
    pPointer.limits.x2 = 32767;
    pPointer.limits.y1 = 0;
    pPointer.limits.y2 = 32767;
    pPointer.confined = FALSE;
    pPointer.x = 0;
    pPointer.y = 0;
    pPointer.generateEvent = FALSE;

    if (!((*pScreenPriv.spriteFuncs.DeviceCursorInitialize) (pDev, pScreen))) {
        free(pPointer);
        return FALSE;
    }

    dixSetPrivate(&pDev.devPrivates, miPointerPrivKey, pPointer);
    return TRUE;
}

/**
 * Clean up after device.
 * This function will be called once before the device is freed in the DIX
 *
 * @param pDev The device to be removed from the server
 * @param pScreen Current screen of the device
 */
private void miPointerDeviceCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    mixin(SetupScreen!(`pScreen`));

    if (!InputDevIsMaster(pDev) && !InputDevIsFloating(pDev))
        return;

    (*pScreenPriv.spriteFuncs.DeviceCursorCleanup) (pDev, pScreen);
    free(dixLookupPrivate(&pDev.devPrivates, miPointerPrivKey));
    dixSetPrivate(&pDev.devPrivates, miPointerPrivKey, null);
}

/**
 * Warp the pointer to the given position on the given screen. May generate
 * an event, depending on whether we're coming from miPointerSetPosition.
 *
 * Once signals are ignored, the WarpCursor function can call this
 *
 * @param pDev The device to warp
 * @param pScreen Screen to warp on
 * @param x The x coordinate in per-screen coordinates
 * @param y The y coordinate in per-screen coordinates
 */

void miPointerWarpCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    miPointerPtr pPointer = void;
    BOOL changedScreen = FALSE;

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return;

    if (pPointer.pScreen != pScreen) {
        mieqSwitchScreen(pDev, pScreen, TRUE);
        changedScreen = TRUE;
    }

    if (pPointer.generateEvent)
        miPointerMove(pDev, pScreen, x, y);
    else
        miPointerMoveNoEvent(pDev, pScreen, x, y);

    /* Don't call USFS if we use Xinerama, otherwise the root window is
     * updated to the second screen, and we never receive any events.
     * (FDO bug #18668) */
version(XINERAMA) {
if (changedScreen && noPanoramiXExtension) {
                DeviceIntPtr master = GetMaster(pDev, MASTER_POINTER);
                /* Hack for CVE-2023-5380: if we're moving
                * screens PointerWindows[] keeps referring to the
                * old window. If that gets destroyed we have a UAF
                * bug later. Only happens when jumping from a window
                * to the root window on the other screen.
                * Enter/Leave events are incorrect for that case but
                * too niche to fix.
                */
                LeaveWindow(pDev);
                if (master)
                    LeaveWindow(master);
                UpdateSpriteForScreen(pDev, pScreen);
        }

}
else {
    if (changedScreen) {
            DeviceIntPtr master = GetMaster(pDev, MASTER_POINTER);
            /* Hack for CVE-2023-5380: if we're moving
             * screens PointerWindows[] keeps referring to the
             * old window. If that gets destroyed we have a UAF
             * bug later. Only happens when jumping from a window
             * to the root window on the other screen.
             * Enter/Leave events are incorrect for that case but
             * too niche to fix.
             */
            LeaveWindow(pDev);
            if (master)
                LeaveWindow(master);
            UpdateSpriteForScreen(pDev, pScreen);
    }
}
}

/**
 * Synchronize the sprite with the cursor.
 *
 * @param pDev The device to sync
 */
void miPointerUpdateSprite(DeviceIntPtr pDev)
{
    ScreenPtr pScreen = void;
    miPointerScreenPtr pScreenPriv = void;
    CursorPtr pCursor = void;
    int x = void, y = void, devx = void, devy = void;
    miPointerPtr pPointer = void;

    if (!pDev || !pDev.coreEvents)
        return;

    pPointer = mixin(MIPOINTER!(`pDev`));

    if (!pPointer)
        return;

    pScreen = pPointer.pScreen;
    if (!pScreen)
        return;

    x = pPointer.x;
    y = pPointer.y;
    devx = pPointer.devx;
    devy = pPointer.devy;

    pScreenPriv = mixin(GetScreenPrivate!(`pScreen`));
    /*
     * if the cursor has switched screens, disable the sprite
     * on the old screen
     */
    if (pScreen !is pPointer.pSpriteScreen) {
        if (pPointer.pSpriteScreen) {
            miPointerScreenPtr pOldPriv = void;

            pOldPriv = mixin(GetScreenPrivate!(`pPointer.pSpriteScreen`));
            if (pPointer.pCursor) {
                (*pOldPriv.spriteFuncs.SetCursor)
                    (pDev, pPointer.pSpriteScreen, NullCursor, 0, 0);
            }
            (*pOldPriv.screenFuncs.CrossScreen) (pPointer.pSpriteScreen,
                                                   FALSE);
        }
        (*pScreenPriv.screenFuncs.CrossScreen) (pScreen, TRUE);
        (*pScreenPriv.spriteFuncs.SetCursor)
            (pDev, pScreen, pPointer.pCursor, x, y);
        pPointer.devx = x;
        pPointer.devy = y;
        pPointer.pSpriteCursor = pPointer.pCursor;
        pPointer.pSpriteScreen = pScreen;
    }
    /*
     * if the cursor has changed, display the new one
     */
    else if (pPointer.pCursor !is pPointer.pSpriteCursor) {
        pCursor = pPointer.pCursor;
        if (!pCursor ||
            (pCursor.bits.emptyMask && !pScreenPriv.showTransparent))
            pCursor = NullCursor;
        (*pScreenPriv.spriteFuncs.SetCursor) (pDev, pScreen, pCursor, x, y);

        pPointer.devx = x;
        pPointer.devy = y;
        pPointer.pSpriteCursor = pPointer.pCursor;
    }
    else if (x != devx || y != devy) {
        pPointer.devx = x;
        pPointer.devy = y;
        if (pPointer.pCursor && !pPointer.pCursor.bits.emptyMask)
            (*pScreenPriv.spriteFuncs.MoveCursor) (pDev, pScreen, x, y);
    }
}

/**
 * Invalidate the current sprite and force it to be reloaded on next cursor setting
 * operation
 *
 * @param pDev The device to invalidate the sprite fore
 */
void miPointerInvalidateSprite(DeviceIntPtr pDev)
{
    miPointerPtr pPointer = void;

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return;

    pPointer.pSpriteCursor = cast(CursorPtr) 1;
}

/**
 * Set the device to the coordinates on the given screen.
 *
 * @param pDev The device to move
 * @param screen_no Index of the screen to move to
 * @param x The x coordinate in per-screen coordinates
 * @param y The y coordinate in per-screen coordinates
 */
void miPointerSetScreen(DeviceIntPtr pDev, int screen_no, int x, int y)
{
    ScreenPtr pScreen = void;
    miPointerPtr pPointer = void;

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return;

    pScreen = screenInfo.screens[screen_no];
    mieqSwitchScreen(pDev, pScreen, FALSE);
    NewCurrentScreen(pDev, pScreen, x, y);

    pPointer.limits.x2 = pScreen.width;
    pPointer.limits.y2 = pScreen.height;
}

/**
 * @return The current screen of the given device or NULL.
 */
ScreenPtr miPointerGetScreen(DeviceIntPtr pDev)
{
    miPointerPtr pPointer = mixin(MIPOINTER!(`pDev`));

    return (pPointer) ? pPointer.pScreen : null;
}

/* Controls whether the cursor image should be updated immediately when
   moved (FALSE) or if something else will be responsible for updating
   it later (TRUE).  Returns current setting.
   Caller is responsible for calling OsBlockSignal first.
*/
Bool miPointerSetWaitForUpdate(ScreenPtr pScreen, Bool wait)
{
    mixin(SetupScreen!(`pScreen`));
    Bool prevWait = pScreenPriv.waitForUpdate;

    pScreenPriv.waitForUpdate = wait;
    return prevWait;
}

/* Move the pointer on the current screen,  and update the sprite. */
private void miPointerMoveNoEvent(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    miPointerPtr pPointer = void;

    mixin(SetupScreen!(`pScreen`));

    pPointer = mixin(MIPOINTER!(`pDev`));
    if (!pPointer)
        return;

    /* Hack: We mustn't call into ->MoveCursor for anything but the
     * VCP, as this may cause a non-HW rendered cursor to be rendered while
     * not holding the input lock. This would race with building the command
     * buffer for other rendering.
     */
    if (GetMaster(pDev, MASTER_POINTER) == inputInfo.pointer
        &&!pScreenPriv.waitForUpdate && pScreen == pPointer.pSpriteScreen) {
        pPointer.devx = x;
        pPointer.devy = y;
        if (pPointer.pCursor && !pPointer.pCursor.bits.emptyMask)
            (*pScreenPriv.spriteFuncs.MoveCursor) (pDev, pScreen, x, y);
    }

    pPointer.x = x;
    pPointer.y = y;
    pPointer.pScreen = pScreen;
}

/**
 * Set the devices' cursor position to the given x/y position.
 *
 * This function is called during the pointer update path in
 * GetPointerEvents and friends (and the same in the xwin DDX).
 *
 * The coordinates provided are always absolute. The parameter mode whether
 * it was relative or absolute movement that landed us at those coordinates.
 *
 * If the cursor was constrained by a barrier, ET_Barrier* events may be
 * generated and appended to the InternalEvent list provided.
 *
 * @param pDev The device to move
 * @param mode Movement mode (Absolute or Relative)
 * @param[in,out] screenx The x coordinate in desktop coordinates
 * @param[in,out] screeny The y coordinate in desktop coordinates
 * @param[in,out] nevents The number of events in events (before/after)
 * @param[in,out] events The list of events before/after being constrained
 */
ScreenPtr miPointerSetPosition(DeviceIntPtr pDev, int mode, double* screenx, double* screeny, int* nevents, InternalEvent* events)
{
    miPointerScreenPtr pScreenPriv = void;
    ScreenPtr pScreen = void;
    ScreenPtr newScreen = void;
    int x = void, y = void;
    Bool switch_screen = FALSE;
    Bool should_constrain_barriers = FALSE;
    int i = void;

    miPointerPtr pPointer = void;

    pPointer = mixin(MIPOINTER!(`pDev`));
    pScreen = pPointer.pScreen;

    x = cast(int)floor(*screenx);
    y = cast(int)floor(*screeny);

    switch_screen = !point_on_screen(pScreen, x, y);

    /* Switch to per-screen coordinates for CursorOffScreen and
     * Pointer->limits */
    x -= pScreen.x;
    y -= pScreen.y;

    should_constrain_barriers = (mode == Relative);

    if (should_constrain_barriers) {
        /* coordinates after clamped to a barrier */
        int constrained_x = void, constrained_y = void;
        int current_x = void, current_y = void; /* current position in per-screen coord */

        current_x = mixin(MIPOINTER!(`pDev`)).x - pScreen.x;
        current_y = mixin(MIPOINTER!(`pDev`)).y - pScreen.y;

        input_constrain_cursor(pDev, pScreen,
                               current_x, current_y, x, y,
                               &constrained_x, &constrained_y,
                               nevents, events);

        x = constrained_x;
        y = constrained_y;
    }

    if (switch_screen) {
        pScreenPriv = mixin(GetScreenPrivate!(`pScreen`));
        if (!pPointer.confined) {
            newScreen = pScreen;
            (*pScreenPriv.screenFuncs.CursorOffScreen) (&newScreen, &x, &y);
            if (newScreen != pScreen) {
                pScreen = newScreen;
                mieqSwitchScreen(pDev, pScreen, FALSE);
                /* Smash the confine to the new screen */
                pPointer.limits.x2 = pScreen.width;
                pPointer.limits.y2 = pScreen.height;
            }
        }
    }
    /* Constrain the sprite to the current limits. */
    if (x < pPointer.limits.x1)
        x = pPointer.limits.x1;
    if (x >= pPointer.limits.x2)
        x = pPointer.limits.x2 - 1;
    if (y < pPointer.limits.y1)
        y = pPointer.limits.y1;
    if (y >= pPointer.limits.y2)
        y = pPointer.limits.y2 - 1;

    if (pScreen.ConstrainCursorHarder)
        pScreen.ConstrainCursorHarder(pDev, pScreen, mode, &x, &y);

    if (pPointer.x != x || pPointer.y != y || pPointer.pScreen != pScreen)
        miPointerMoveNoEvent(pDev, pScreen, x, y);

    /* check if we generated any barrier events and if so, update root x/y
     * to the fully constrained coords */
    if (should_constrain_barriers) {
        for (i = 0; i < *nevents; i++) {
            if (events[i].any.type == ET_BarrierHit ||
                events[i].any.type == ET_BarrierLeave) {
                events[i].barrier_event.root_x = x;
                events[i].barrier_event.root_y = y;
            }
        }
    }

    /* Convert to desktop coordinates again */
    x += pScreen.x;
    y += pScreen.y;

    /* In the event we actually change screen or we get confined, we just
     * drop the float component on the floor
     * FIXME: only drop remainder for ConstrainCursorHarder, not for screen
     * crossings */
    if (x != floor(*screenx))
        *screenx = x;
    if (y != floor(*screeny))
        *screeny = y;

    return pScreen;
}

/**
 * Get the current position of the device in desktop coordinates.
 *
 * @param x Return value for the current x coordinate in desktop coordinates.
 * @param y Return value for the current y coordinate in desktop coordinates.
 */
void miPointerGetPosition(DeviceIntPtr pDev, int* x, int* y)
{
    miPointerPtr pPointer = mixin(MIPOINTER!(`pDev`));
    if (pPointer) {
        *x = pPointer.x;
        *y = pPointer.y;
    }
    else {
        *x = 0;
        *y = 0;
    }
}

/**
 * Move the device's pointer to the x/y coordinates on the given screen.
 * This function generates and enqueues pointer events.
 *
 * @param pDev The device to move
 * @param pScreen The screen the device is on
 * @param x The x coordinate in per-screen coordinates
 * @param y The y coordinate in per-screen coordinates
 */
void miPointerMove(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    int i = void, nevents = void;
    int[2] valuators = void;
    ValuatorMask mask = void;

    miPointerMoveNoEvent(pDev, pScreen, x, y);

    /* generate motion notify */
    valuators[0] = x;
    valuators[1] = y;

    if (!mipointermove_events) {
        mipointermove_events = InitEventList(GetMaximumEventsNum());

        if (!mipointermove_events) {
            FatalError("Could not allocate event store.\n");
            return;
        }
    }

    valuator_mask_set_range(&mask, 0, 2, valuators.ptr);
    nevents = GetPointerEvents(mipointermove_events, pDev, MotionNotify, 0,
                               POINTER_SCREEN | POINTER_ABSOLUTE |
                               POINTER_NORAW, &mask);

    input_lock();
    for (i = 0; i < nevents; i++)
        mieqEnqueue(pDev, &mipointermove_events[i]);
    input_unlock();
}
