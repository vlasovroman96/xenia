module mi.mi_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;
//public import x11.Xproto;
//public import x11.Xprotostr;

public import dix.screenint_priv;
public import dix.callback;
public import dix.events;
public import dix.gc;
public import mi.micmap;
public import dix.pixmap;
public import region;
public import dix.scrintstr;
public import dix.scrnintstr;
public import include.validate;
public import include.window;
public import mi.miexpose;
import dix.colormap_priv;

pragma(inline, true) void SetInstalledmiColormap(ScreenPtr s, ColormapPtr c) {
    dixSetPrivate(&(s).devPrivates, micmapScrPrivateKey, c);
}

pragma(inline, true) ColormapPtr GetInstalledmiColormap(ScreenPtr s) {
    return cast(ColormapPtr)dixLookupPrivate(&(s).devPrivates, &micmapScrPrivateKeyRec);
}

void miScreenClose(ScreenPtr pScreen);

void miWideArc(DrawablePtr pDraw, GCPtr pGC, int narcs, xArc* parcs);
void miStepDash(int dist, int* pDashIndex, ubyte* pDash, int numInDashList, int* pDashOffset);

Bool mieqInit();
void mieqFini();
void mieqEnqueue(DeviceIntPtr pDev, InternalEvent* e);
void mieqSwitchScreen(DeviceIntPtr pDev, ScreenPtr pScreen, Bool set_dequeue_screen);
void mieqProcessDeviceEvent(DeviceIntPtr dev, InternalEvent* event, ScreenPtr screen);
void mieqProcessInputEvents();
void mieqAddCallbackOnDrained(CallbackProcPtr callback, void* param);
void mieqRemoveCallbackOnDrained(CallbackProcPtr callback, void* param);

/**
 * Custom input event handler. If you need to process input events in some
 * other way than the default path, register an input event handler for the
 * given internal event type.
 */
alias mieqHandler = void function(int screen, InternalEvent* event, DeviceIntPtr dev);
void mieqSetHandler(int event, mieqHandler handler);

// void miSendExposures(WindowPtr pWin, RegionPtr pRgn, int dx, int dy);

// void  miWindowExposures(WindowPtr pWin, RegionPtr prgn);

void miPaintWindow(WindowPtr pWin, RegionPtr prgn, int what);
void miSourceValidate(DrawablePtr pDrawable, int x, int y, int w, int h, uint subWindowMode);

/* only exported for modesetting, not for external drivers (yet) */
// Bool miCreateScreenResources(ScreenPtr pScreen);

// int miShapedWindowIn(RegionPtr universe, RegionPtr bounding, BoxPtr rect, int x, int y);
// int miValidateTree(WindowPtr pParent, WindowPtr pChild, VTKind kind);

void miClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures);
void miMarkWindow(WindowPtr pWin);
Bool miMarkOverlappedWindows(WindowPtr pWin, WindowPtr pFirst, WindowPtr* ppLayerWin);
void miHandleValidateExposures(WindowPtr pWin);
void miMoveWindow(WindowPtr pWin, int x, int y, WindowPtr pNextSib, VTKind kind);
void miResizeWindow(WindowPtr pWin, int x, int y, uint w, uint h, WindowPtr pSib);
WindowPtr miGetLayerWindow(WindowPtr pWin);
void miSetShape(WindowPtr pWin, int kind);
void miChangeBorderWidth(WindowPtr pWin, uint width);
void miMarkUnrealizedWindow(WindowPtr pChild, WindowPtr pWin, Bool fromConfigure);
WindowPtr miSpriteTrace(SpritePtr pSprite, int x, int y);
WindowPtr miXYToWindow(ScreenPtr pScreen, SpritePtr pSprite, int x, int y);

// void  miExpandDirectColors(ColormapPtr, int, xColorItem*, xColorItem*);

union _MiValidate {
    struct BeforeValidate {
        xPoint oldAbsCorner;       /* old window position */
        RegionPtr borderVisible;        /* visible region of border, */
        /* non-null when size changes */
        Bool resized;           /* unclipped winSize has changed */
    }BeforeValidate before;
    struct AfterValidate {
        RegionRec exposed;      /* exposed regions, absolute pos */
        RegionRec borderExposed;
    }AfterValidate after;
}

alias MiValidateRec = _MiValidate;

 /* _XSERVER_MI_PRIV_H */
