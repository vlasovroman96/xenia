module composite.compint;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2006, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
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
 
public import dix.screen_hooks_priv;

public import include.misc;
public import include.scrnintstr;
public import include.os;
public import include.regionstr;
public import include.validate;
public import include.windowstr;
public import include.input;
public import include.resource;
public import dix.cursor;
public import include.dixstruct;
public import include.gcstruct;
public import include.servermd;
public import include.globals;
public import include.picturestr;
public import include.extnsionst;
public import include.privates;
public import composite.compext;
public import  composite.compinit;

// public import mi.mi;
public import dix.damage;
public import xfixes.xfixes;
// //public import externs.X11.extensions.compositeproto;
import composite.compwindow;
public import core.stdc.assert_;

/*
 *  enable this for debugging

    #define COMPOSITE_DEBUG
 */

struct _CompClientWindow {
    _CompClientWindow* next;
    XID id;
    int update;
}alias CompClientWindowRec = _CompClientWindow;
alias CompClientWindowPtr = _CompClientWindow*;

struct _CompWindow {
    RegionRec borderClip;
    DamagePtr damage;           /* for automatic update mode */
    Bool damageRegistered;
    Bool damaged;
    int update;
    CompClientWindowPtr clients;
    int oldx;
    int oldy;
    PixmapPtr pOldPixmap;
    int borderClipX, borderClipY;
}alias CompWindowRec = _CompWindow;
alias CompWindowPtr = _CompWindow*;

enum COMP_ORIGIN_INVALID =	    0x80000000;

struct _CompSubwindows {
    int update;
    CompClientWindowPtr clients;
}alias CompSubwindowsRec = _CompSubwindows;
alias CompSubwindowsPtr = _CompSubwindows*;

enum COMP_INCLUDE_RGB24_VISUAL = 0;



struct _CompOverlayClientRec {
    CompOverlayClientPtr pNext;
    ClientPtr pClient;
    ScreenPtr pScreen;
    XID resource;
}
alias CompOverlayClientRec = _CompOverlayClientRec; 
alias CompOverlayClientPtr = _CompOverlayClientRec*;

struct CompImplicitRedirectException {
    XID parentVisual;
    XID winVisual;
}

struct _CompScreen {
    CopyWindowProcPtr CopyWindow;
    CreateWindowProcPtr CreateWindow;
    RealizeWindowProcPtr RealizeWindow;
    UnrealizeWindowProcPtr UnrealizeWindow;
    ClipNotifyProcPtr ClipNotify;
    /*
     * Called from ConfigureWindow, these
     * three track changes to the offscreen storage
     * geometry
     */
    ConfigNotifyProcPtr ConfigNotify;
    MoveWindowProcPtr MoveWindow;
    ResizeWindowProcPtr ResizeWindow;
    ChangeBorderWidthProcPtr ChangeBorderWidth;
    /*
     * Reparenting has an effect on Subwindows redirect
     */
    ReparentWindowProcPtr ReparentWindow;

    /*
     * Colormaps for new visuals better not get installed
     */
    InstallColormapProcPtr InstallColormap;

    /*
     * Fake backing store via automatic redirection
     */
    ChangeWindowAttributesProcPtr ChangeWindowAttributes;

    Bool pendingScreenUpdate;

    int numAlternateVisuals;
    VisualID* alternateVisuals;
    int numImplicitRedirectExceptions;
    CompImplicitRedirectException* implicitRedirectExceptions;

    WindowPtr pOverlayWin;
    Window overlayWid;
    CompOverlayClientPtr pOverlayClients;

    SourceValidateProcPtr SourceValidate;
}alias CompScreenRec = _CompScreen;
alias CompScreenPtr = _CompScreen*;

// DevPrivateKeyRec CompScreenPrivateKeyRec;

enum CompScreenPrivateKey = (&CompScreenPrivateKeyRec);

// DevPrivateKeyRec CompWindowPrivateKeyRec;

enum CompWindowPrivateKey = (&CompWindowPrivateKeyRec);

// DevPrivateKeyRec CompSubwindowsPrivateKeyRec;

enum CompSubwindowsPrivateKey = (&CompSubwindowsPrivateKeyRec);

enum string GetCompScreen(string s) = `(cast(CompScreenPtr) 
    dixLookupPrivate(&(` ~ s ~ `).devPrivates, CompScreenPrivateKey))`;
enum string GetCompWindow(string w) = `(cast(CompWindowPtr) 
    dixLookupPrivate(&(` ~ w ~ `).devPrivates, CompWindowPrivateKey))`;
enum string GetCompSubwindows(string w) = `(cast(CompSubwindowsPtr) 
    dixLookupPrivate(&(` ~ w ~ `).devPrivates, CompSubwindowsPrivateKey))`;

RESTYPE CompositeClientSubwindowsType;
RESTYPE CompositeClientOverlayType;

/*
 * compalloc.c
 */

Bool compRedirectWindow(ClientPtr pClient, WindowPtr pWin, int update);

void compFreeClientWindow(WindowPtr pWin, XID id);

int compUnredirectWindow(ClientPtr pClient, WindowPtr pWin, int update);

int compRedirectSubwindows(ClientPtr pClient, WindowPtr pWin, int update);

void compFreeClientSubwindows(WindowPtr pWin, XID id);

int compUnredirectSubwindows(ClientPtr pClient, WindowPtr pWin, int update);

int compRedirectOneSubwindow(WindowPtr pParent, WindowPtr pWin);

int compUnredirectOneSubwindow(WindowPtr pParent, WindowPtr pWin);

Bool compAllocPixmap(WindowPtr pWin);

void compSetParentPixmap(WindowPtr pWin);

void compRestoreWindow(WindowPtr pWin, PixmapPtr pPixmap);

Bool compReallocPixmap(WindowPtr pWin, int x, int y, uint w, uint h, int bw);

void compMarkAncestors(WindowPtr pWin);

/*
 * compinit.c
 */

// Bool compScreenInit(ScreenPtr pScreen);

/*
 * compoverlay.c
 */

void compFreeOverlayClient(CompOverlayClientPtr pOcToDel);

CompOverlayClientPtr compFindOverlayClient(ScreenPtr pScreen, ClientPtr pClient);

CompOverlayClientPtr compCreateOverlayClient(ScreenPtr pScreen, ClientPtr pClient);

Bool compCreateOverlayWindow(ScreenPtr pScreen);

void compDestroyOverlayWindow(ScreenPtr pScreen);

/*
 * compwindow.c
 */

version (COMPOSITE_DEBUG) {
void compCheckTree(ScreenPtr pScreen);
} else {
//#define compCheckTree(s)
}

// void compSetPixmap(WindowPtr pWin, PixmapPtr pPixmap, int bw);

// Bool compCheckRedirect(WindowPtr pWin);

// void compWindowPosition(CallbackListPtr* pcbl, ScreenPtr pScreen, XorgScreenWindowPositionParamRec* param);

// Bool compRealizeWindow(WindowPtr pWin);

// Bool compUnrealizeWindow(WindowPtr pWin);

// void compClipNotify(WindowPtr pWin, int dx, int dy);

// void compMoveWindow(WindowPtr pWin, int x, int y, WindowPtr pSib, VTKind kind);

// void compResizeWindow(WindowPtr pWin, int x, int y, uint w, uint h, WindowPtr pSib);

// void compChangeBorderWidth(WindowPtr pWin, uint border_width);

// void compReparentWindow(WindowPtr pWin, WindowPtr pPriorParent);

// Bool compCreateWindow(WindowPtr pWin);

// void compWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWin);

// void compSetRedirectBorderClip(WindowPtr pWin, RegionPtr pRegion);

// RegionPtr compGetRedirectBorderClip(WindowPtr pWin);

// void compCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc);

// void compPaintChildrenToWindow(WindowPtr pWin);

// WindowPtr CompositeRealChildHead(WindowPtr pWin);

// int DeleteWindowNoInputDevices(void* value, XID wid);

// int compConfigNotify(WindowPtr pWin, int x, int y, int w, int h, int bw, WindowPtr pSib);

void PanoramiXCompositeInit();
// void PanoramiXCompositeReset();

                          /* _COMPINT_H_ */
