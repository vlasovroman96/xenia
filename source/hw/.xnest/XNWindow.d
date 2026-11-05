module XNWindow;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/

 
//public import x11.Xdefs;
public import externs.xcb.xcb;
import region;

struct xnestPrivWin {
    xcb_window_t window;
    xcb_window_t parent;
    int x;
    int y;
    uint width;
    uint height;
    uint border_width;
    xcb_window_t sibling_above;
    RegionPtr bounding_shape;
    RegionPtr clip_shape;
}

struct xnestWindowMatch {
    WindowPtr pWin;
    xcb_window_t window;
}

DevPrivateKeyRec xnestWindowPrivateKeyRec;

enum xnestWindowPrivateKey = (&xnestWindowPrivateKeyRec);

enum string xnestWindowPriv(string pWin) = `(cast(xnestPrivWin*) 
    dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, xnestWindowPrivateKey))`;

enum string xnestWindow(string pWin) = `(` ~ xnestWindowPriv!(pWin) ~ `.window)`;

enum string xnestWindowParent(string pWin) = `
  ((` ~ pWin ~ `).parent ? 
   ` ~ xnestWindow!(`(` ~ pWin ~ `).parent`) ~ ` : 
   xnestDefaultWindows[` ~ pWin ~ `.drawable.pScreen.myNum])`;

enum string xnestWindowSiblingAbove(string pWin) = `
  ((` ~ pWin ~ `).prevSib ? ` ~ xnestWindow!(`(` ~ pWin ~ `).prevSib`) ~ ` : XCB_WINDOW_NONE)`;

enum string xnestWindowSiblingBelow(string pWin) = `
  ((` ~ pWin ~ `).nextSib ? ` ~ xnestWindow!(`(` ~ pWin ~ `).nextSib`) ~ ` : XCB_WINDOW_NONE)`;

WindowPtr xnestWindowPtr(xcb_window_t window);
Bool xnestCreateWindow(WindowPtr pWin);
Bool xnestDestroyWindow(WindowPtr pWin);
Bool xnestPositionWindow(WindowPtr pWin, int x, int y);
void xnestConfigureWindow(WindowPtr pWin, uint mask);
Bool xnestChangeWindowAttributes(WindowPtr pWin, c_ulong mask);
Bool xnestRealizeWindow(WindowPtr pWin);
Bool xnestUnrealizeWindow(WindowPtr pWin);
void xnestCopyWindow(WindowPtr pWin, xPoint oldOrigin, RegionPtr oldRegion);
void xnestClipNotify(WindowPtr pWin, int dx, int dy);
void xnestSetShape(WindowPtr pWin, int kind);
void xnestShapeWindow(WindowPtr pWin);

/* ScreenRec operations */
void xnest_screen_ClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures);

                          /* XNESTWINDOW_H */
