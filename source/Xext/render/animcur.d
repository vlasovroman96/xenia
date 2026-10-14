module animcur;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2002 Keith Packard, member of The XFree86 Project, Inc.
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

/*
 * Animated cursors for X.  Not specific to Render in any way, but
 * stuck there because Render has the other cool cursor extension.
 * Besides, everyone has Render.
 *
 * Implemented as a simple layer over the core cursor code; it
 * creates composite cursors out of a set of static cursors and
 * delta times between each image.
 */

import build.dix_config;

//import x11.X;
//import x11.Xmd;

import dix.cursor_priv;
import dix.input_priv;
import dix.screen_hooks_priv;

import include.servermd;
import include.scrnintstr;
import include.dixstruct;
import dix.cursor;
import include.dixfontstr;
import include.opaque;
import render.picturestr_priv;
import include.inputstr;
import Xext.xace;
import dix.screen_hooks;
import os.WaitFor;
import dix.events;

struct AnimCurElt {
    CursorPtr pCursor;          /* cursor to show */
    CARD32 delay;               /* in ms */
}

struct _AnimCur {
    int nelt;                   /* number of elements in the elts array */
    AnimCurElt* elts;           /* actually allocated right after the structure */
    OsTimerPtr timer;
}alias AnimCurRec = _AnimCur;
alias AnimCurPtr = _AnimCur*;

struct _AnimScrPriv {
    CursorLimitsProcPtr CursorLimits;
    DisplayCursorProcPtr DisplayCursor;
    SetCursorPositionProcPtr SetCursorPosition;
    RealizeCursorProcPtr RealizeCursor;
    UnrealizeCursorProcPtr UnrealizeCursor;
    RecolorCursorProcPtr RecolorCursor;
}alias AnimCurScreenRec = _AnimScrPriv;
alias AnimCurScreenPtr = _AnimScrPriv*;

private enum ubyte[4] empty = [0, 0, 0, 0];

private CursorBits animCursorBits = {
    empty.ptr, empty.ptr, 2, 1, 1, 0, 0, 1
};

private DevPrivateKeyRec AnimCurScreenPrivateKeyRec;

enum string IsAnimCur(string c) = `((` ~ c ~ `) && ((` ~ c ~ `).bits == &animCursorBits))`;
enum string GetAnimCur(string c) = `(cast(AnimCurPtr) (((cast(char*)(` ~ c ~ `) + CURSOR_REC_SIZE))))`;
enum string GetAnimCurScreen(string s) = `(cast(AnimCurScreenPtr)dixLookupPrivate(&(` ~ s ~ `).devPrivates, &AnimCurScreenPrivateKeyRec))`;

enum string Wrap(string as,string s,string elt,string func) = `(((` ~ as ~ `).` ~ elt ~ ` = (` ~ s ~ `).` ~ elt ~ `), (` ~ s ~ `).` ~ elt ~ ` = ` ~ func ~ `);`;
enum string Unwrap(string as,string s,string elt) = `((` ~ s ~ `).` ~ elt ~ ` = (` ~ as ~ `).` ~ elt ~ `);`;

private void AnimCurScreenClose(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));

    dixScreenUnhookClose(pScreen, &AnimCurScreenClose);

    mixin(Unwrap!(`as`, `pScreen`, `CursorLimits`));
    mixin(Unwrap!(`as`, `pScreen`, `DisplayCursor`));
    mixin(Unwrap!(`as`, `pScreen`, `SetCursorPosition`));
    mixin(Unwrap!(`as`, `pScreen`, `RealizeCursor`));
    mixin(Unwrap!(`as`, `pScreen`, `UnrealizeCursor`));
    mixin(Unwrap!(`as`, `pScreen`, `RecolorCursor`));
}

private void AnimCurCursorLimits(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, BoxPtr pHotBox, BoxPtr pTopLeftBox)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));

    mixin(Unwrap!(`as`, `pScreen`, `CursorLimits`));
    if (mixin(IsAnimCur!(`pCursor`))) {
        AnimCurPtr ac = mixin(GetAnimCur!(`pCursor`));

        (*pScreen.CursorLimits) (pDev, pScreen, ac.elts[0].pCursor,
                                  pHotBox, pTopLeftBox);
    }
    else {
        (*pScreen.CursorLimits) (pDev, pScreen, pCursor, pHotBox, pTopLeftBox);
    }
    mixin(Wrap!(`as`, `pScreen`, `CursorLimits`, `&AnimCurCursorLimits`));
}

/*
 * The cursor animation timer has expired, go display any relevant cursor changes
 * and compute a new timeout value
 */

private CARD32 AnimCurTimerNotify(OsTimerPtr timer, CARD32 now, void* arg)
{
    DeviceIntPtr dev = cast(DeviceIntPtr)arg;
    ScreenPtr pScreen = dev.spriteInfo.anim.pScreen;
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));

    AnimCurPtr ac = mixin(GetAnimCur!(`dev.spriteInfo.sprite.current`));
    int elt = (dev.spriteInfo.anim.elt + 1) % ac.nelt;
    DisplayCursorProcPtr DisplayCursor = pScreen.DisplayCursor;

    /*
     * Not a simple Unwrap/Wrap as this isn't called along the DisplayCursor
     * wrapper chain.
     */
    pScreen.DisplayCursor = as.DisplayCursor;
    cast(void) (*pScreen.DisplayCursor) (dev, pScreen, ac.elts[elt].pCursor);
    as.DisplayCursor = pScreen.DisplayCursor;
    pScreen.DisplayCursor = DisplayCursor;

    dev.spriteInfo.anim.elt = elt;
    dev.spriteInfo.anim.pCursor = ac.elts[elt].pCursor;

    return ac.elts[elt].delay;
}

private void AnimCurCancelTimer(DeviceIntPtr pDev)
{
    CursorPtr cur = pDev.spriteInfo.sprite ?
                    pDev.spriteInfo.sprite.current : null;

    if (mixin(IsAnimCur!(`cur`)))
        TimerCancel(mixin(GetAnimCur!(`cur`)).timer);
}

private Bool AnimCurDisplayCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));
    Bool ret = TRUE;


    if (InputDevIsFloating(pDev))
        return FALSE;

    mixin(Unwrap!(`as`, `pScreen`, `DisplayCursor`));
    if (mixin(IsAnimCur!(`pCursor`))) {
        if (pCursor != pDev.spriteInfo.sprite.current) {
            AnimCurPtr ac = mixin(GetAnimCur!(`pCursor`));

            AnimCurCancelTimer(pDev);
            ret = (*pScreen.DisplayCursor) (pDev, pScreen,
                                             ac.elts[0].pCursor);

            if (ret) {
                pDev.spriteInfo.anim.elt = 0;
                pDev.spriteInfo.anim.pCursor = pCursor;
                pDev.spriteInfo.anim.pScreen = pScreen;

                ac.timer = TimerSet(ac.timer, 0, ac.elts[0].delay,
                                     &AnimCurTimerNotify, pDev);
            }
        }
    }
    else {
        AnimCurCancelTimer(pDev);
        pDev.spriteInfo.anim.pCursor = null;
        pDev.spriteInfo.anim.pScreen = null;
        ret = (*pScreen.DisplayCursor) (pDev, pScreen, pCursor);
    }
    mixin(Wrap!(`as`, `pScreen`, `DisplayCursor`, `&AnimCurDisplayCursor`));
    return ret;
}

private Bool AnimCurSetCursorPosition(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, Bool generateEvent)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));
    Bool ret = void;

    mixin(Unwrap!(`as`, `pScreen`, `SetCursorPosition`));
    if (pDev.spriteInfo.anim.pCursor) {
        pDev.spriteInfo.anim.pScreen = pScreen;
    }
    ret = (*pScreen.SetCursorPosition) (pDev, pScreen, x, y, generateEvent);
    mixin(Wrap!(`as`, `pScreen`, `SetCursorPosition`, `&AnimCurSetCursorPosition`));
    return ret;
}

private Bool AnimCurRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));
    Bool ret = void;

    mixin(Unwrap!(`as`, `pScreen`, `RealizeCursor`));
    if (mixin(IsAnimCur!(`pCursor`)))
        ret = TRUE;
    else
        ret = (*pScreen.RealizeCursor) (pDev, pScreen, pCursor);
    mixin(Wrap!(`as`, `pScreen`, `RealizeCursor`, `&AnimCurRealizeCursor`));
    return ret;
}

private Bool AnimCurUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));
    Bool ret = void;

    mixin(Unwrap!(`as`, `pScreen`, `UnrealizeCursor`));
    if (mixin(IsAnimCur!(`pCursor`))) {
        AnimCurPtr ac = mixin(GetAnimCur!(`pCursor`));
        int i = void;

        if (pScreen.myNum == 0)
            for (i = 0; i < ac.nelt; i++)
                FreeCursor(ac.elts[i].pCursor, 0);
        ret = TRUE;
    }
    else
        ret = (*pScreen.UnrealizeCursor) (pDev, pScreen, pCursor);
    mixin(Wrap!(`as`, `pScreen`, `UnrealizeCursor`, `&AnimCurUnrealizeCursor`));
    return ret;
}

private void AnimCurRecolorCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, Bool displayed)
{
    AnimCurScreenPtr as = mixin(GetAnimCurScreen!(`pScreen`));

    mixin(Unwrap!(`as`, `pScreen`, `RecolorCursor`));
    if (mixin(IsAnimCur!(`pCursor`))) {
        AnimCurPtr ac = mixin(GetAnimCur!(`pCursor`));
        int i = void;

        for (i = 0; i < ac.nelt; i++)
            (*pScreen.RecolorCursor) (pDev, pScreen, ac.elts[i].pCursor,
                                       displayed &&
                                       pDev.spriteInfo.anim.elt == i);
    }
    else
        (*pScreen.RecolorCursor) (pDev, pScreen, pCursor, displayed);
    mixin(Wrap!(`as`, `pScreen`, `RecolorCursor`, `&AnimCurRecolorCursor`));
}

Bool AnimCurInit(ScreenPtr pScreen)
{
    AnimCurScreenPtr as = void;

    if (!dixRegisterPrivateKey(&AnimCurScreenPrivateKeyRec, PRIVATE_SCREEN,
                               AnimCurScreenRec.sizeof))
        return FALSE;

    as = mixin(GetAnimCurScreen!(`pScreen`));

    dixScreenHookClose(pScreen, &AnimCurScreenClose);

    mixin(Wrap!(`as`, `pScreen`, `CursorLimits`, `&AnimCurCursorLimits`));
    mixin(Wrap!(`as`, `pScreen`, `DisplayCursor`, `&AnimCurDisplayCursor`));
    mixin(Wrap!(`as`, `pScreen`, `SetCursorPosition`, `&AnimCurSetCursorPosition`));
    mixin(Wrap!(`as`, `pScreen`, `RealizeCursor`, `&AnimCurRealizeCursor`));
    mixin(Wrap!(`as`, `pScreen`, `UnrealizeCursor`, `&AnimCurUnrealizeCursor`));
    mixin(Wrap!(`as`, `pScreen`, `RecolorCursor`, `&AnimCurRecolorCursor`));
    return TRUE;
}

int AnimCursorCreate(CursorPtr* cursors, CARD32* deltas, int ncursor, CursorPtr* ppCursor, ClientPtr client, XID cid)
{
    if (ncursor <= 0)
        return BadValue;

    CursorPtr pCursor = void;
    int rc = BadAlloc, i = void;
    AnimCurPtr ac = void;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!mixin(GetAnimCurScreen!(`walkScreen`)))
            return BadImplementation;
    });

    for (i = 0; i < ncursor; i++)
        if (mixin(IsAnimCur!(`cursors[i]`)))
            return BadMatch;

    pCursor = cast(CursorPtr) calloc(CURSOR_REC_SIZE +
                                 ((AnimCurRec).sizeof +
                                 ncursor * AnimCurElt.sizeof), 1);
    if (!pCursor)
        return rc;
    mixin(dixInitPrivates!("pCursor", "pCursor + 1", "PRIVATE_CURSOR"));
    pCursor.bits = &animCursorBits;
    pCursor.refcnt = 1;

    pCursor.foreRed = cursors[0].foreRed;
    pCursor.foreGreen = cursors[0].foreGreen;
    pCursor.foreBlue = cursors[0].foreBlue;

    pCursor.backRed = cursors[0].backRed;
    pCursor.backGreen = cursors[0].backGreen;
    pCursor.backBlue = cursors[0].backBlue;

    pCursor.id = cid;

    ac = mixin(GetAnimCur!(`pCursor`));
    ac.timer = TimerSet(null, 0, 0, &AnimCurTimerNotify, null);

    /* security creation/labeling check */
    if (ac.timer)
        rc = XaceHookResourceAccess(client, cid, X11_RESTYPE_CURSOR, pCursor,
                      X11_RESTYPE_NONE, null, DixCreateAccess);

    if (rc != Success) {
        TimerFree(ac.timer);
        mixin(dixFiniPrivates!("pCursor", "PRIVATE_CURSOR"));
        free(pCursor);
        return rc;
    }

    /*
     * Fill in the AnimCurRec
     */
    animCursorBits.refcnt++;
    ac.nelt = ncursor;
    ac.elts = cast(AnimCurElt*) (ac + 1);

    for (i = 0; i < ncursor; i++) {
        ac.elts[i].pCursor = RefCursor(cursors[i]);
        ac.elts[i].delay = deltas[i];
    }

    *ppCursor = pCursor;
    return Success;
}
