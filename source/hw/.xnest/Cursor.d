module Cursor;
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
import build.xorg_config;

import core.stdc.stdint;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import externs.xcb.xcb;
import externs.xcb.xcb_aux;

import include.screenint;
import include.input;
import include.misc;
import dix.cursor;
import include.scrnintstr;
import include.servermd;
import include.mipointrst;

import xnest_xcb;


import Display;
import Screen;
import XNCursor;
import Keyboard;
import Args;

xnestCursorFuncRec xnestCursorFuncs = { null };

Bool xnestRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    uint valuemask = XCB_GC_FUNCTION | XCB_GC_PLANE_MASK | XCB_GC_FOREGROUND
                         | XCB_GC_BACKGROUND | XCB_GC_CLIP_MASK;

    xcb_params_gc_t values = {
        c_function: XCB_GX_COPY,
        plane_mask: cast(uint)~0L,
        foreground: 1L,
    };

    xcb_aux_change_gc(xnestUpstreamInfo.conn, xnestBitmapGC, valuemask, &values);

    const(uint) winId = xnestDefaultWindows[pScreen.myNum];

    const(Pixmap) source = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_create_pixmap(xnestUpstreamInfo.conn, 1, source, winId, pCursor.bits.width, pCursor.bits.height);

    const(Pixmap) mask = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_create_pixmap(xnestUpstreamInfo.conn, 1, mask, winId, pCursor.bits.width, pCursor.bits.height);

    const(int) pixmap_len = mixin(BitmapBytePad!("pCursor.bits.width")) * pCursor.bits.height;

    xcb_put_image(xnestUpstreamInfo.conn,
                  XCB_IMAGE_FORMAT_XY_BITMAP,
                  source,
                  xnestBitmapGC,
                  pCursor.bits.width,
                  pCursor.bits.height,
                  0, // x
                  0, // y
                  0, // left_pad
                  1, // depth
                  pixmap_len,
                  cast(ubyte*) pCursor.bits.source);

    xcb_put_image(xnestUpstreamInfo.conn,
                  XCB_IMAGE_FORMAT_XY_BITMAP,
                  mask,
                  xnestBitmapGC,
                  pCursor.bits.width,
                  pCursor.bits.height,
                  0, // x
                  0, // y
                  0, // left_pad
                  1, // depth
                  pixmap_len,
                  cast(ubyte*) pCursor.bits.mask);

    xnestSetCursorPriv(pCursor, pScreen, cast(xnestPrivCursor*) calloc(1, xnestPrivCursor.sizeof));
    uint cursor = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_create_cursor(xnestUpstreamInfo.conn, cursor, source, mask,
                      pCursor.foreRed, pCursor.foreGreen, pCursor.foreBlue,
                      pCursor.backRed, pCursor.backGreen, pCursor.backBlue,
                      pCursor.bits.xhot, pCursor.bits.yhot);

    xnestCursor(pCursor, pScreen) = cursor;

    xcb_free_pixmap(xnestUpstreamInfo.conn, source);
    xcb_free_pixmap(xnestUpstreamInfo.conn, mask);

    return TRUE;
}

Bool xnestUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    xcb_free_cursor(xnestUpstreamInfo.conn, xnestCursor(pCursor, pScreen));
    free(xnestGetCursorPriv(pCursor, pScreen));
    return TRUE;
}

void xnestRecolorCursor(ScreenPtr pScreen, CursorPtr pCursor, Bool displayed)
{
    xcb_recolor_cursor(xnestUpstreamInfo.conn,
                       xnestCursor(pCursor, pScreen),
                       pCursor.foreRed,
                       pCursor.foreGreen,
                       pCursor.foreBlue,
                       pCursor.backRed,
                       pCursor.backGreen,
                       pCursor.backBlue);
}

void xnestSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, int x, int y)
{
    if (pCursor) {
        uint cursor = xnestCursor(pCursor, pScreen);

        xcb_change_window_attributes(xnestUpstreamInfo.conn,
                                     xnestDefaultWindows[pScreen.myNum],
                                     XCB_CW_CURSOR,
                                     &cursor);
    }
}

void xnestMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
}

Bool xnestDeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    xnestCursorFuncPtr pScreenPriv = void;

    pScreenPriv = cast(xnestCursorFuncPtr)
        dixLookupPrivate(&pScreen.devPrivates, &xnestScreenCursorFuncKeyRec);

    return pScreenPriv.spriteFuncs.DeviceCursorInitialize(pDev, pScreen);
}

void xnestDeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    xnestCursorFuncPtr pScreenPriv = void;

    pScreenPriv = cast(xnestCursorFuncPtr)
        dixLookupPrivate(&pScreen.devPrivates, &xnestScreenCursorFuncKeyRec);

    pScreenPriv.spriteFuncs.DeviceCursorCleanup(pDev, pScreen);
}
