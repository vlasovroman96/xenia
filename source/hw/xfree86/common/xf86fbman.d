module xf86fbman;
@nogc nothrow:
extern(C): __gshared:

/*
 * Copyright (c) 1998-2001 by The XFree86 Project, Inc.
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
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
import build.xorg_config;

//import x11.X;

import dix.screen_hooks_priv;

//import x11.X;

import os.log_priv;
import region;

import dix.scrnintstr;
import xf86DGA;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.modes.xf86Crtc;
import xf86cmap;
import dix.resource;
import dix.dixutils;
import dix.screen_hooks;
import xf86Bus;

public import dix.scrnintstr;
public import region;
import xf86Bus;

enum FAVOR_AREA_THEN_WIDTH =		0;
enum FAVOR_AREA_THEN_HEIGHT =		1;
enum FAVOR_WIDTH_THEN_AREA =		2;
enum FAVOR_HEIGHT_THEN_AREA =		3;

enum PRIORITY_LOW =			0;
enum PRIORITY_NORMAL =			1;
enum PRIORITY_EXTREME =		2;

struct _FBArea {
    ScreenPtr pScreen;
    BoxRec box;
    int granularity;
    void function(_FBArea*, _FBArea*) @nogc nothrow MoveAreaCallback;
    void function(_FBArea*) @nogc nothrow RemoveAreaCallback;
    DevUnion devPrivate;
}alias FBArea = _FBArea;
alias FBAreaPtr = _FBArea*;

struct _FBLinear {
    ScreenPtr pScreen;
    int size;
    int offset;
    int granularity;
    void function(_FBLinear*, _FBLinear*) @nogc nothrow MoveLinearCallback;
    void function(_FBLinear*) @nogc nothrow RemoveLinearCallback;
    DevUnion devPrivate;
}alias FBLinear = _FBLinear;
alias FBLinearPtr = _FBLinear*;

alias MoveAreaCallbackProcPtr = void function(FBAreaPtr, FBAreaPtr) @nogc nothrow;
alias RemoveAreaCallbackProcPtr = void function(FBAreaPtr) @nogc nothrow;

alias MoveLinearCallbackProcPtr = void function(FBLinearPtr, FBLinearPtr) @nogc nothrow;
alias RemoveLinearCallbackProcPtr = void function(FBLinearPtr) @nogc nothrow;

void  xf86InitFBManager(ScreenPtr pScreen, BoxPtr FullBox);

void  xf86InitFBManagerLinear(ScreenPtr pScreen, int offset, int size);

void  xf86AllocateOffscreenArea(ScreenPtr pScreen, int w, int h, int granularity, MoveAreaCallbackProcPtr moveCB, RemoveAreaCallbackProcPtr removeCB, void* privData);

void  xf86AllocateOffscreenLinear(ScreenPtr pScreen, int length, int granularity, MoveLinearCallbackProcPtr moveCB, RemoveLinearCallbackProcPtr removeCB, void* privData);

void  xf86FreeOffscreenArea(FBAreaPtr area);
void  xf86FreeOffscreenLinear(FBLinearPtr area);

void  xf86ResizeOffscreenArea(FBAreaPtr resize, int w, int h);

void  xf86ResizeOffscreenLinear(FBLinearPtr resize, int size);

void  xf86PurgeUnlockedOffscreenAreas(ScreenPtr pScreen);

void  xf86QueryLargestOffscreenArea(ScreenPtr pScreen, int* width, int* height, int granularity, int preferences, int priority);

void  xf86QueryLargestOffscreenLinear(ScreenPtr pScreen, int* size, int granularity, int priority);

struct _FBManagerFuncs {
    FBAreaPtr function(ScreenPtr pScreen, int w, int h, int granularity, MoveAreaCallbackProcPtr moveCB, RemoveAreaCallbackProcPtr removeCB, void* privData) @nogc nothrow AllocateOffscreenArea;
    void function(FBAreaPtr area) @nogc nothrow FreeOffscreenArea;
    Bool function(FBAreaPtr area, int w, int h) @nogc nothrow ResizeOffscreenArea;
    Bool function(ScreenPtr pScreen, int* width, int* height, int granularity, int preferences, int priority) @nogc nothrow QueryLargestOffscreenArea;
/* linear functions */
     FBLinearPtr function(ScreenPtr pScreen, int size, int granularity, MoveLinearCallbackProcPtr moveCB, RemoveLinearCallbackProcPtr removeCB, void* privData) @nogc nothrow AllocateOffscreenLinear;
    void function(FBLinearPtr area) @nogc nothrow FreeOffscreenLinear;
    Bool function(FBLinearPtr area, int size) @nogc nothrow ResizeOffscreenLinear;
    Bool function(ScreenPtr pScreen, int* size, int granularity, int priority) @nogc nothrow QueryLargestOffscreenLinear;
    Bool function(ScreenPtr) @nogc nothrow PurgeOffscreenAreas;
}alias FBManagerFuncs = _FBManagerFuncs;
alias FBManagerFuncsPtr = FBManagerFuncs*;

private DevPrivateKeyRec xf86FBManagerKeyRec;
private DevPrivateKey xf86FBManagerKey;

private Bool xf86RegisterOffscreenManager(ScreenPtr pScreen, FBManagerFuncsPtr funcs)
{

    xf86FBManagerKey = &xf86FBManagerKeyRec;

    if (!dixRegisterPrivateKey(&xf86FBManagerKeyRec, PRIVATE_SCREEN, 0))
        return False;

    dixSetPrivate(&pScreen.devPrivates, xf86FBManagerKey, funcs);

    return True;
}

FBAreaPtr xf86AllocateOffscreenArea(ScreenPtr pScreen, int w, int h, int gran, MoveAreaCallbackProcPtr moveCB, RemoveAreaCallbackProcPtr removeCB, void* privData)
{
    FBManagerFuncsPtr funcs = void;

    if (xf86FBManagerKey is null)
        return null;
    if (((funcs = cast(FBManagerFuncsPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                       xf86FBManagerKey)) is null))
        return null;

    return (*funcs.AllocateOffscreenArea) (pScreen, w, h, gran, moveCB,
                                            removeCB, privData);
}

FBLinearPtr xf86AllocateOffscreenLinear(ScreenPtr pScreen, int length, int gran, MoveLinearCallbackProcPtr moveCB, RemoveLinearCallbackProcPtr removeCB, void* privData)
{
    FBManagerFuncsPtr funcs = void;

    if (xf86FBManagerKey is null)
        return null;
    if (((funcs = cast(FBManagerFuncsPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                       xf86FBManagerKey)) is null))
        return null;

    return (*funcs.AllocateOffscreenLinear) (pScreen, length, gran, moveCB,
                                              removeCB, privData);
}

void xf86FreeOffscreenArea(FBAreaPtr area)
{
    FBManagerFuncsPtr funcs = void;

    if (!area)
        return;

    if (xf86FBManagerKey is null)
        return;
    if (
        ((funcs =
         cast(FBManagerFuncsPtr) dixLookupPrivate(&area.pScreen.devPrivates,
                                              xf86FBManagerKey)) is null))
        return;

    (*funcs.FreeOffscreenArea) (area);

    return;
}

void xf86FreeOffscreenLinear(FBLinearPtr linear)
{
    FBManagerFuncsPtr funcs = void;

    if (!linear)
        return;

    if (xf86FBManagerKey is null)
        return;
    if (
        ((funcs =
         cast(FBManagerFuncsPtr) dixLookupPrivate(&linear.pScreen.devPrivates,
                                              xf86FBManagerKey)) is null))
        return;

    (*funcs.FreeOffscreenLinear) (linear);

    return;
}

Bool xf86ResizeOffscreenArea(FBAreaPtr resize, int w, int h)
{
    FBManagerFuncsPtr funcs = void;

    if (!resize)
        return False;

    if (xf86FBManagerKey is null)
        return False;
    if (
        ((funcs =
         cast(FBManagerFuncsPtr) dixLookupPrivate(&resize.pScreen.devPrivates,
                                              xf86FBManagerKey)) is null))
        return False;

    return (*funcs.ResizeOffscreenArea) (resize, w, h);
}

Bool xf86ResizeOffscreenLinear(FBLinearPtr resize, int size)
{
    FBManagerFuncsPtr funcs = void;

    if (!resize)
        return False;

    if (xf86FBManagerKey is null)
        return False;
    if (
        ((funcs =
         cast(FBManagerFuncsPtr) dixLookupPrivate(&resize.pScreen.devPrivates,
                                              xf86FBManagerKey)) is null))
        return False;

    return (*funcs.ResizeOffscreenLinear) (resize, size);
}

Bool xf86QueryLargestOffscreenArea(ScreenPtr pScreen, int* w, int* h, int gran, int preferences, int severity)
{
    FBManagerFuncsPtr funcs = void;

    *w = 0;
    *h = 0;

    if (xf86FBManagerKey is null)
        return False;
    if (((funcs = cast(FBManagerFuncsPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                       xf86FBManagerKey)) is null))
        return False;

    return (*funcs.QueryLargestOffscreenArea) (pScreen, w, h, gran,
                                                preferences, severity);
}

Bool xf86QueryLargestOffscreenLinear(ScreenPtr pScreen, int* size, int gran, int severity)
{
    FBManagerFuncsPtr funcs = void;

    *size = 0;

    if (xf86FBManagerKey is null)
        return False;
    if (((funcs = cast(FBManagerFuncsPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                       xf86FBManagerKey)) is null))
        return False;

    return (*funcs.QueryLargestOffscreenLinear) (pScreen, size, gran,
                                                  severity);
}

Bool xf86PurgeUnlockedOffscreenAreas(ScreenPtr pScreen)
{
    FBManagerFuncsPtr funcs = void;

    if (xf86FBManagerKey is null)
        return False;
    if (((funcs = cast(FBManagerFuncsPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                       xf86FBManagerKey)) is null))
        return False;

    return (*funcs.PurgeOffscreenAreas) (pScreen);
}

/************************************************************\

   Below is a specific implementation of an offscreen manager.

\************************************************************/

private DevPrivateKeyRec xf86FBScreenKeyRec;

enum xf86FBScreenKey = (&xf86FBScreenKeyRec);

struct _FBLink {
    FBArea area;
    _FBLink* next;
}alias FBLink = _FBLink;
alias FBLinkPtr = _FBLink*;

struct _FBLinearLink {
    FBLinear linear;
    int free;                   /* need to add free here as FBLinear is publicly accessible */
    FBAreaPtr area;             /* only used if allocation came from XY area */
    _FBLinearLink* next;
}alias FBLinearLink = _FBLinearLink;
alias FBLinearLinkPtr = _FBLinearLink*;

struct _FBManager {
    ScreenPtr pScreen;
    RegionPtr InitialBoxes;
    RegionPtr FreeBoxes;
    FBLinkPtr UsedAreas;
    int NumUsedAreas;
    FBLinearLinkPtr LinearAreas;
    DevUnion* devPrivates;
}alias FBManager = _FBManager;
alias FBManagerPtr = FBManager*;

private FBAreaPtr AllocateArea(FBManagerPtr offman, int w, int h, int granularity, MoveAreaCallbackProcPtr moveCB, RemoveAreaCallbackProcPtr removeCB, void* privData)
{
    ScreenPtr pScreen = offman.pScreen;
    FBLinkPtr link = null;
    FBAreaPtr area = null;
    RegionRec NewReg = void;
    int i = void, x = 0, num = void;
    BoxPtr boxp = void;

    if (granularity <= 1)
        granularity = 0;

    boxp = RegionRects(offman.FreeBoxes);
    num = RegionNumRects(offman.FreeBoxes);

    /* look through the free boxes */
    for (i = 0; i < num; i++, boxp++) {
        x = boxp.x1;
        if (granularity > 1)
            x = ((x + granularity - 1) / granularity) * granularity;

        if (((boxp.y2 - boxp.y1) < h) || ((boxp.x2 - x) < w))
            continue;

        link = cast(FBLink*) calloc(1, FBLink.sizeof);
        if (!link)
            return null;

        area = &(link.area);
        link.next = offman.UsedAreas;
        offman.UsedAreas = link;
        offman.NumUsedAreas++;
        break;
    }

    /* try to boot a removable one out if we are not expendable ourselves */
    if (!area && !removeCB) {
        link = offman.UsedAreas;

        while (link) {
            if (!link.area.RemoveAreaCallback) {
                link = link.next;
                continue;
            }

            boxp = &(link.area.box);
            x = boxp.x1;
            if (granularity > 1)
                x = ((x + granularity - 1) / granularity) * granularity;

            if (((boxp.y2 - boxp.y1) < h) || ((boxp.x2 - x) < w)) {
                link = link.next;
                continue;
            }

            /* bye, bye */
            (*link.area.RemoveAreaCallback) (&link.area);
            RegionInit(&NewReg, &(link.area.box), 1);
            RegionUnion(offman.FreeBoxes, offman.FreeBoxes, &NewReg);
            RegionUninit(&NewReg);

            area = &(link.area);
            break;
        }
    }

    if (area) {
        area.pScreen = pScreen;
        area.granularity = granularity;
        area.box.x1 = cast(short)(x);
        area.box.x2 = cast(short)(x + w);
        area.box.y1 = cast(short)(boxp.y1);
        area.box.y2 = cast(short)(boxp.y1 + h);
        area.MoveAreaCallback = moveCB;
        area.RemoveAreaCallback = removeCB;
        area.devPrivate.ptr = privData;

        RegionInit(&NewReg, &(area.box), 1);
        RegionSubtract(offman.FreeBoxes, offman.FreeBoxes, &NewReg);
        RegionUninit(&NewReg);
    }

    return area;
}

private FBAreaPtr localAllocateOffscreenArea(ScreenPtr pScreen, int w, int h, int gran, MoveAreaCallbackProcPtr moveCB, RemoveAreaCallbackProcPtr removeCB, void* privData)
{
    FBManagerPtr offman = void;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    return AllocateArea(offman, w, h, gran, moveCB, removeCB, privData);
}

private void localFreeOffscreenArea(FBAreaPtr area)
{
    FBManagerPtr offman = void;
    FBLinkPtr pLink = void, pLinkPrev = null;
    RegionRec FreedRegion = void;
    ScreenPtr pScreen = void;

    pScreen = area.pScreen;
    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    pLink = offman.UsedAreas;
    if (!pLink)
        return;

    while (&(pLink.area) != area) {
        pLinkPrev = pLink;
        pLink = pLink.next;
        if (!pLink)
            return;
    }

    /* put the area back into the pool */
    RegionInit(&FreedRegion, &(pLink.area.box), 1);
    RegionUnion(offman.FreeBoxes, offman.FreeBoxes, &FreedRegion);
    RegionUninit(&FreedRegion);

    if (pLinkPrev)
        pLinkPrev.next = pLink.next;
    else
        offman.UsedAreas = pLink.next;

    free(pLink);
    offman.NumUsedAreas--;
}

private Bool localResizeOffscreenArea(FBAreaPtr resize, int w, int h)
{
    FBManagerPtr offman = void;
    ScreenPtr pScreen = void;
    BoxRec OrigArea = void;
    RegionRec FreedReg = void;
    FBAreaPtr area = null;
    FBLinkPtr pLink = void, newLink = void, pLinkPrev = null;

    pScreen = resize.pScreen;
    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    /* find this link */
    if (((pLink = offman.UsedAreas) is null))
        return False;

    while (&(pLink.area) != resize) {
        pLinkPrev = pLink;
        pLink = pLink.next;
        if (!pLink)
            return False;
    }

    OrigArea.x1 = resize.box.x1;
    OrigArea.x2 = resize.box.x2;
    OrigArea.y1 = resize.box.y1;
    OrigArea.y2 = resize.box.y2;

    /* if it's smaller, this is easy */

    if ((w <= (resize.box.x2 - resize.box.x1)) &&
        (h <= (resize.box.y2 - resize.box.y1))) {
        RegionRec NewReg = void;

        resize.box.x2 = cast(short)(resize.box.x1 + w);
        resize.box.y2 = cast(short)(resize.box.y1 + h);

        if ((resize.box.y2 == OrigArea.y2) && (resize.box.x2 == OrigArea.x2))
            return True;

        RegionInit(&FreedReg, &OrigArea, 1);
        RegionInit(&NewReg, &(resize.box), 1);
        RegionSubtract(&FreedReg, &FreedReg, &NewReg);
        RegionUnion(offman.FreeBoxes, offman.FreeBoxes, &FreedReg);
        RegionUninit(&FreedReg);
        RegionUninit(&NewReg);

        return True;
    }

    /* otherwise we remove the old region */

    RegionInit(&FreedReg, &OrigArea, 1);
    RegionUnion(offman.FreeBoxes, offman.FreeBoxes, &FreedReg);

    /* remove the old link */
    if (pLinkPrev)
        pLinkPrev.next = pLink.next;
    else
        offman.UsedAreas = pLink.next;

    /* and try to add a new one */

    if ((area = AllocateArea(offman, w, h, resize.granularity,
                             resize.MoveAreaCallback,
                             resize.RemoveAreaCallback,
                             resize.devPrivate.ptr)) !is null) {

        /* copy data over to our link and replace the new with old */
        memcpy(resize, area, FBArea.sizeof);

        pLinkPrev = null;
        newLink = offman.UsedAreas;

        while (&(newLink.area) != area) {
            pLinkPrev = newLink;
            newLink = newLink.next;
        }

        if (pLinkPrev)
            pLinkPrev.next = newLink.next;
        else
            offman.UsedAreas = newLink.next;

        pLink.next = offman.UsedAreas;
        offman.UsedAreas = pLink;

        free(newLink);

        /* AllocateArea added one but we really only exchanged one */
        offman.NumUsedAreas--;
    }
    else {
        /* reinstate the old region */
        RegionSubtract(offman.FreeBoxes, offman.FreeBoxes, &FreedReg);
        RegionUninit(&FreedReg);

        pLink.next = offman.UsedAreas;
        offman.UsedAreas = pLink;
        return False;
    }

    RegionUninit(&FreedReg);

    return True;
}

private Bool localQueryLargestOffscreenArea(ScreenPtr pScreen, int* width, int* height, int granularity, int preferences, int severity)
{
    FBManagerPtr offman = void;
    RegionPtr newRegion = null;
    BoxPtr pbox = void;
    int nbox = void;
    int x = void, w = void, h = void, area = void, oldArea = void;

    *width = *height = oldArea = 0;

    if (granularity <= 1)
        granularity = 0;

    if ((preferences < 0) || (preferences > 3))
        return False;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    if (severity < 0)
        severity = 0;
    if (severity > 2)
        severity = 2;

    switch (severity) {
    case 2:
        if (offman.NumUsedAreas) {
            FBLinkPtr pLink = void;
            RegionRec tmpRegion = void;

            newRegion = RegionCreate(null, 1);
            RegionCopy(newRegion, offman.InitialBoxes);
            pLink = offman.UsedAreas;

            while (pLink) {
                if (!pLink.area.RemoveAreaCallback) {
                    RegionInit(&tmpRegion, &(pLink.area.box), 1);
                    RegionSubtract(newRegion, newRegion, &tmpRegion);
                    RegionUninit(&tmpRegion);
                }
                pLink = pLink.next;
            }

            nbox = RegionNumRects(newRegion);
            pbox = RegionRects(newRegion);
            break;
        }
        goto case 1;
    case 1:
        if (offman.NumUsedAreas) {
            FBLinkPtr pLink = void;
            RegionRec tmpRegion = void;

            newRegion = RegionCreate(null, 1);
            RegionCopy(newRegion, offman.FreeBoxes);
            pLink = offman.UsedAreas;

            while (pLink) {
                if (pLink.area.RemoveAreaCallback) {
                    RegionInit(&tmpRegion, &(pLink.area.box), 1);
                    RegionAppend(newRegion, &tmpRegion);
                    RegionUninit(&tmpRegion);
                }
                pLink = pLink.next;
            }

            nbox = RegionNumRects(newRegion);
            pbox = RegionRects(newRegion);
            break;
        }
        goto default;
    default:
        nbox = RegionNumRects(offman.FreeBoxes);
        pbox = RegionRects(offman.FreeBoxes);
        break;
    }

    while (nbox--) {
        x = pbox.x1;
        if (granularity > 1)
            x = ((x + granularity - 1) / granularity) * granularity;

        w = pbox.x2 - x;
        h = pbox.y2 - pbox.y1;
        area = w * h;

        if (w > 0) {
            Bool gotIt = False;

            switch (preferences) {
            case FAVOR_AREA_THEN_WIDTH:
                if ((area > oldArea) || ((area == oldArea) && (w > *width)))
                    gotIt = True;
                break;
            case FAVOR_AREA_THEN_HEIGHT:
                if ((area > oldArea) || ((area == oldArea) && (h > *height)))
                    gotIt = True;
                break;
            case FAVOR_WIDTH_THEN_AREA:
                if ((w > *width) || ((w == *width) && (area > oldArea)))
                    gotIt = True;
                break;
            case FAVOR_HEIGHT_THEN_AREA:
                if ((h > *height) || ((h == *height) && (area > oldArea)))
                    gotIt = True;
                break;
            default: break;}
            if (gotIt) {
                *width = w;
                *height = h;
                oldArea = area;
            }
        }
        pbox++;
    }

    if (newRegion)
        RegionDestroy(newRegion);

    return True;
}

private Bool localPurgeUnlockedOffscreenAreas(ScreenPtr pScreen)
{
    FBManagerPtr offman = void;
    FBLinkPtr pLink = void, tmp = void, pPrev = null;
    RegionRec FreedRegion = void;
    Bool anyUsed = False;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    pLink = offman.UsedAreas;
    if (!pLink)
        return True;

    while (pLink) {
        if (pLink.area.RemoveAreaCallback) {
            (*pLink.area.RemoveAreaCallback) (&pLink.area);

            RegionInit(&FreedRegion, &(pLink.area.box), 1);
            RegionAppend(offman.FreeBoxes, &FreedRegion);
            RegionUninit(&FreedRegion);

            if (pPrev)
                pPrev.next = pLink.next;
            else
                offman.UsedAreas = pLink.next;

            tmp = pLink;
            pLink = pLink.next;
            free(tmp);
            offman.NumUsedAreas--;
            anyUsed = True;
        }
        else {
            pPrev = pLink;
            pLink = pLink.next;
        }
    }

    if (anyUsed) {
        RegionValidate(offman.FreeBoxes, &anyUsed);
    }

    return True;
}

private void LinearMoveCBWrapper(FBAreaPtr from, FBAreaPtr to)
{
    /* this will never get called */
}

private void LinearRemoveCBWrapper(FBAreaPtr area)
{
    FBManagerPtr offman = void;
    FBLinearLinkPtr pLink = void, pLinkPrev = null;
    ScreenPtr pScreen = area.pScreen;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    pLink = offman.LinearAreas;
    if (!pLink)
        return;

    while (pLink.area != area) {
        pLinkPrev = pLink;
        pLink = pLink.next;
        if (!pLink)
            return;
    }

    /* give the user the callback it is expecting */
    (*pLink.linear.RemoveLinearCallback) (&(pLink.linear));

    if (pLinkPrev)
        pLinkPrev.next = pLink.next;
    else
        offman.LinearAreas = pLink.next;

    free(pLink);
}

private void DumpDebug(FBLinearLinkPtr pLink)
{
version (DEBUG) {
    if (!pLink)
        ErrorF("MMmm, PLINK IS NULL!\n");

    while (pLink) {
        ErrorF("  Offset:%08x, Size:%08x, %s,%s\n",
               pLink.linear.offset,
               pLink.linear.size,
               pLink.free ? "Free" : "Used", pLink.area ? "Area" : "Linear");

        pLink = pLink.next;
    }
}
}

private FBLinearPtr AllocateLinear(FBManagerPtr offman, int size, int granularity, void* privData)
{
    ScreenPtr pScreen = offman.pScreen;
    FBLinearLinkPtr linear = null;
    int offset = void, end = void;

    if (size <= 0)
        return null;

    if (!offman.LinearAreas)
        return null;

    linear = offman.LinearAreas;
    while (linear) {
        /* Make sure we get a free area that's not an XY fallback case */
        if (!linear.area && linear.free) {
            offset = linear.linear.offset;
            if (granularity > 1)
                offset =
                    ((offset + granularity - 1) / granularity) * granularity;
            end = offset + size;
            if (end <= (linear.linear.offset + linear.linear.size))
                break;
        }
        linear = linear.next;
    }
    if (!linear)
        return null;

    /* break left */
    if (offset > linear.linear.offset) {
        FBLinearLinkPtr newlink = cast(FBLinearLink*) calloc(1, FBLinearLink.sizeof);
        if (!newlink)
            return null;
        newlink.area = null;
        newlink.linear.offset = offset;
        newlink.linear.size =
            linear.linear.size - (offset - linear.linear.offset);
        newlink.free = 1;
        newlink.next = linear.next;
        linear.linear.size -= newlink.linear.size;
        linear.next = newlink;
        linear = newlink;
    }

    /* break right */
    if (size < linear.linear.size) {
        FBLinearLinkPtr newlink = cast(FBLinearLink*) calloc(1, FBLinearLink.sizeof);
        if (!newlink)
            return null;
        newlink.area = null;
        newlink.linear.offset = offset + size;
        newlink.linear.size = linear.linear.size - size;
        newlink.free = 1;
        newlink.next = linear.next;
        linear.linear.size = size;
        linear.next = newlink;
    }

    /* p = middle block */
    linear.linear.granularity = granularity;
    linear.free = 0;
    linear.linear.pScreen = pScreen;
    linear.linear.MoveLinearCallback = null;
    linear.linear.RemoveLinearCallback = null;
    linear.linear.devPrivate.ptr = null;

    DumpDebug(offman.LinearAreas);

    return &(linear.linear);
}

private FBLinearPtr localAllocateOffscreenLinear(ScreenPtr pScreen, int length, int gran, MoveLinearCallbackProcPtr moveCB, RemoveLinearCallbackProcPtr removeCB, void* privData)
{
    FBManagerPtr offman = void;
    FBLinearLinkPtr link = void;
    FBAreaPtr area = void;
    FBLinearPtr linear = null;
    BoxPtr extents = void;
    int w = void, h = void, pitch = void;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);

    /* Try to allocate from linear memory first...... */
    DebugF("ALLOCATING LINEAR\n");
    if ((linear = AllocateLinear(offman, length, gran, privData)) !is null)
        return linear;

    DebugF("NOPE, ALLOCATING AREA\n");

    if (((link = cast(FBLinearLink*) calloc(1, FBLinearLink.sizeof)) is null))
        return null;

    /* No linear available, so try and pinch some from the XY areas */
    extents = RegionExtents(offman.InitialBoxes);
    pitch = extents.x2 - extents.x1;

    if (gran > 1) {
        if (gran > pitch) {
            /* we can't match the specified alignment with XY allocations */
            free(link);
            return null;
        }

        if (pitch % gran) {
            /* pitch and granularity aren't a perfect match, let's allocate
             * a bit more so we can align later on
             */
            length += gran - 1;
        }
    }

    if (length < pitch) {       /* special case */
        w = length;
        h = 1;
    }
    else {
        w = pitch;
        h = (length + pitch - 1) / pitch;
    }

    if ((area = localAllocateOffscreenArea(pScreen, w, h, gran,
                                           moveCB ? &LinearMoveCBWrapper : null,
                                           removeCB ? &LinearRemoveCBWrapper :
                                           null, privData)) !is null) {
        link.area = area;
        link.free = 0;
        link.next = offman.LinearAreas;
        offman.LinearAreas = link;
        linear = &(link.linear);
        linear.pScreen = pScreen;
        linear.size = h * w;
        linear.offset = (pitch * area.box.y1) + area.box.x1;
        if (gran > 1)
            linear.offset = ((linear.offset + gran - 1) / gran) * gran;
        linear.granularity = gran;
        linear.MoveLinearCallback = moveCB;
        linear.RemoveLinearCallback = removeCB;
        linear.devPrivate.ptr = privData;
    }
    else
        free(link);

    DumpDebug(offman.LinearAreas);

    return linear;
}

private void localFreeOffscreenLinear(FBLinearPtr linear)
{
    FBManagerPtr offman = void;
    FBLinearLinkPtr pLink = void, pLinkPrev = null;
    ScreenPtr pScreen = linear.pScreen;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    pLink = offman.LinearAreas;
    if (!pLink)
        return;

    while (&(pLink.linear) != linear) {
        pLinkPrev = pLink;
        pLink = pLink.next;
        if (!pLink)
            return;
    }

    if (pLink.area) {          /* really an XY area */
        DebugF("FREEING AREA\n");
        localFreeOffscreenArea(pLink.area);
        if (pLinkPrev)
            pLinkPrev.next = pLink.next;
        else
            offman.LinearAreas = pLink.next;
        free(pLink);
        DumpDebug(offman.LinearAreas);
        return;
    }

    pLink.free = 1;

    if (pLink.next && pLink.next.free) {
        FBLinearLinkPtr p = pLink.next;

        pLink.linear.size += p.linear.size;
        pLink.next = p.next;
        free(p);
    }

    if (pLinkPrev) {
        if (pLinkPrev.next && pLinkPrev.next.free && !pLinkPrev.area) {
            FBLinearLinkPtr p = pLinkPrev.next;

            pLinkPrev.linear.size += p.linear.size;
            pLinkPrev.next = p.next;
            free(p);
        }
    }

    DebugF("FREEING LINEAR\n");
    DumpDebug(offman.LinearAreas);
}

private Bool localResizeOffscreenLinear(FBLinearPtr resize, int length)
{
    FBManagerPtr offman = void;
    FBLinearLinkPtr pLink = void;
    ScreenPtr pScreen = resize.pScreen;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    pLink = offman.LinearAreas;
    if (!pLink)
        return False;

    while (&(pLink.linear) != resize) {
        pLink = pLink.next;
        if (!pLink)
            return False;
    }

    /* This could actually be a lot smarter and try to move allocations
       from XY to linear when available.  For now if it was XY, we keep
       it XY */

    if (pLink.area) {          /* really an XY area */
        BoxPtr extents = void;
        int pitch = void, w = void, h = void;

        extents = RegionExtents(offman.InitialBoxes);
        pitch = extents.x2 - extents.x1;

        if (length < pitch) {   /* special case */
            w = length;
            h = 1;
        }
        else {
            w = pitch;
            h = (length + pitch - 1) / pitch;
        }

        if (localResizeOffscreenArea(pLink.area, w, h)) {
            resize.size = h * w;
            resize.offset =
                (pitch * pLink.area.box.y1) + pLink.area.box.x1;
            return True;
        }
    }
    else {
        /* TODO!!!! resize the linear area */
    }

    return False;
}

private Bool localQueryLargestOffscreenLinear(ScreenPtr pScreen, int* size, int gran, int priority)
{
    FBManagerPtr offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                          xf86FBScreenKey);
    FBLinearLinkPtr pLink = void;
    FBLinearLinkPtr pLinkRet = void;

    *size = 0;

    pLink = offman.LinearAreas;

    if (pLink && !pLink.area) {
        pLinkRet = pLink;
        while (pLink) {
            if (pLink.free) {
                if (pLink.linear.size > pLinkRet.linear.size)
                    pLinkRet = pLink;
            }
            pLink = pLink.next;
        }

        if (pLinkRet.free) {
            *size = pLinkRet.linear.size;
            return True;
        }
    }
    else {
        int w = void, h = void;

        if (localQueryLargestOffscreenArea(pScreen, &w, &h, gran,
                                           FAVOR_WIDTH_THEN_AREA, priority)) {
            BoxPtr extents = void;

            extents = RegionExtents(offman.InitialBoxes);
            if ((extents.x2 - extents.x1) == w)
                *size = w * h;
            return True;
        }
    }

    return False;
}

private FBManagerFuncs xf86FBManFuncs = {
    &localAllocateOffscreenArea,
    &localFreeOffscreenArea,
    &localResizeOffscreenArea,
    &localQueryLargestOffscreenArea,
    &localAllocateOffscreenLinear,
    &localFreeOffscreenLinear,
    &localResizeOffscreenLinear,
    &localQueryLargestOffscreenLinear,
    &localPurgeUnlockedOffscreenAreas
};

private void xf86FBCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    FBLinkPtr pLink = void, tmp = void;
    FBLinearLinkPtr pLinearLink = void, tmp2 = void;
    FBManagerPtr offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                          xf86FBScreenKey);

    dixScreenUnhookClose(pScreen, &xf86FBCloseScreen);

    if (!offman)
        return;

    pLink = offman.UsedAreas;
    while (pLink) {
        tmp = pLink;
        pLink = pLink.next;
        free(tmp);
    }

    pLinearLink = offman.LinearAreas;
    while (pLinearLink) {
        tmp2 = pLinearLink;
        pLinearLink = pLinearLink.next;
        free(tmp2);
    }

    RegionDestroy(offman.InitialBoxes);
    RegionDestroy(offman.FreeBoxes);

    free(offman.devPrivates);
    free(offman);
    dixSetPrivate(&pScreen.devPrivates, xf86FBScreenKey, null);
}



Bool xf86InitFBManager(ScreenPtr pScreen, BoxPtr FullBox)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    RegionRec ScreenRegion = void;
    RegionRec FullRegion = void;
    BoxRec ScreenBox = void;
    Bool ret = void;

    ScreenBox.x1 = 0;
    ScreenBox.y1 = 0;
    ScreenBox.x2 = cast(short)pScrn.virtualX;
    ScreenBox.y2 = cast(short)pScrn.virtualY;

    if ((FullBox.x1 > ScreenBox.x1) || (FullBox.y1 > ScreenBox.y1) ||
        (FullBox.x2 < ScreenBox.x2) || (FullBox.y2 < ScreenBox.y2)) {
        return False;
    }

    if (FullBox.y2 < FullBox.y1)
        return False;
    if (FullBox.x2 < FullBox.x1)
        return False;

    RegionInit(&ScreenRegion, &ScreenBox, 1);
    RegionInit(&FullRegion, FullBox, 1);

    RegionSubtract(&FullRegion, &FullRegion, &ScreenRegion);

    ret = xf86InitFBManagerRegion(pScreen, &FullRegion);

    RegionUninit(&ScreenRegion);
    RegionUninit(&FullRegion);

    return ret;
}

private Bool xf86InitFBManagerRegion(ScreenPtr pScreen, RegionPtr FullRegion)
{

    if (RegionNil(FullRegion))
        return False;

    if (!dixRegisterPrivateKey(&xf86FBScreenKeyRec, PRIVATE_SCREEN, 0))
        return False;

    if (!xf86RegisterOffscreenManager(pScreen, &xf86FBManFuncs))
        return False;

    FBManagerPtr offman = cast(FBManager*) calloc(1, FBManager.sizeof);
    if (!offman)
        return False;

    dixSetPrivate(&pScreen.devPrivates, xf86FBScreenKey, offman);
    dixScreenHookClose(pScreen, &xf86FBCloseScreen);

    offman.InitialBoxes = RegionCreate(null, 1);
    offman.FreeBoxes = RegionCreate(null, 1);

    RegionCopy(offman.InitialBoxes, FullRegion);
    RegionCopy(offman.FreeBoxes, FullRegion);

    offman.pScreen = pScreen;
    offman.UsedAreas = null;
    offman.LinearAreas = null;
    offman.NumUsedAreas = 0;
    offman.devPrivates = null;

    return True;
}

Bool xf86InitFBManagerLinear(ScreenPtr pScreen, int offset, int size)
{
    FBManagerPtr offman = void;
    FBLinearLinkPtr link = void;
    FBLinearPtr linear = void;

    if (size <= 0)
        return False;

    /* we expect people to have called the Area setup first for pixmap cache */
    if (!dixLookupPrivate(&pScreen.devPrivates, xf86FBScreenKey))
        return False;

    offman = cast(FBManagerPtr) dixLookupPrivate(&pScreen.devPrivates,
                                             xf86FBScreenKey);
    offman.LinearAreas = cast(FBLinearLink*) calloc(1, FBLinearLink.sizeof);
    if (!offman.LinearAreas)
        return False;

    link = offman.LinearAreas;
    link.area = null;
    link.next = null;
    link.free = 1;
    linear = &(link.linear);
    linear.pScreen = pScreen;
    linear.size = size;
    linear.offset = offset;
    linear.granularity = 0;
    linear.MoveLinearCallback = null;
    linear.RemoveLinearCallback = null;
    linear.devPrivate.ptr = null;

    return True;
}
