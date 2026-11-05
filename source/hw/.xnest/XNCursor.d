module XNCursor;
@nogc nothrow:
extern(C): __gshared:
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

public import include.mipointrst;
import mi.mipointer;

struct _XnestCursorFuncRec {
    miPointerSpriteFuncPtr spriteFuncs;
}alias xnestCursorFuncRec = _XnestCursorFuncRec;
alias xnestCursorFuncPtr = xnestCursorFuncRec*;

// stores xnestCursorFuncRec in screen
DevPrivateKeyRec xnestScreenCursorFuncKeyRec;

xnestCursorFuncRec xnestCursorFuncs;

struct xnestPrivCursor {
    Cursor cursor;
}

// stores xnestPrivCursor per screen's cursor
DevScreenPrivateKeyRec xnestScreenCursorPrivKeyRec;

enum string xnestGetCursorPriv(string pCursor, string pScreen) = `(cast(xnestPrivCursor*) 
    dixLookupScreenPrivate(&(` ~ pCursor ~ `).devPrivates, 
                           &xnestScreenCursorPrivKeyRec, ` ~ pScreen ~ `))`;

enum string xnestSetCursorPriv(string pCursor, string pScreen, string v) = `
    dixSetScreenPrivate(&(` ~ pCursor ~ `).devPrivates, 
                        &xnestScreenCursorPrivKeyRec, ` ~ pScreen ~ `, ` ~ v ~ `)`;

enum string xnestCursor(string pCursor, string pScreen) = `
  (` ~ xnestGetCursorPriv!(pCursor, pScreen) ~ `.cursor)`;

Bool xnestRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor);
Bool xnestUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor);
void xnestRecolorCursor(ScreenPtr pScreen, CursorPtr pCursor, Bool displayed);
void xnestSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, int x, int y);
void xnestMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y);
Bool xnestDeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen);
void xnestDeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen);
                          /* XNESTCURSOR_H */
