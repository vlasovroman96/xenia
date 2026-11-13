module Pixmap;
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
import build.xorg_config;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import region;
import dix.pixmap;
import dix.scrnintstr;
import dix.gc;
import common.servermd;
import dix.privates;

import xnest_xcb;


import Display;
import Screen;
import XNPixmap;

DevPrivateKeyRec xnestPixmapPrivateKeyRec;

PixmapPtr xnestCreatePixmap(ScreenPtr pScreen, int width, int height, int depth, uint usage_hint)
{
    PixmapPtr pPixmap = void;

    pPixmap = AllocatePixmap(pScreen, 0);
    if (!pPixmap)
        return NullPixmap;
    pPixmap.drawable.type = DRAWABLE_PIXMAP;
    pPixmap.drawable.depth = depth;
    pPixmap.drawable.bitsPerPixel = depth;
    pPixmap.drawable.width = width;
    pPixmap.drawable.height = height;
    pPixmap.drawable.pScreen = pScreen;
    pPixmap.drawable.serialNumber = NEXT_SERIAL_NUMBER;
    pPixmap.refcnt = 1;
    pPixmap.devKind = PixmapBytePad(width, depth);
    pPixmap.usage_hint = usage_hint;
    if (width && height) {
        uint pixmap = xcb_generate_id(xnestUpstreamInfo.conn);
        xcb_create_pixmap(xnestUpstreamInfo.conn, depth, pixmap,
                          xnestDefaultWindows[pScreen.myNum], width, height);
        xnestPixmapPriv(pPixmap).pixmap = pixmap;
    }
    else
        xnestPixmapPriv(pPixmap).pixmap = 0;

    return pPixmap;
}

Bool xnestDestroyPixmap(PixmapPtr pPixmap)
{
    if (--pPixmap.refcnt)
        return True;
    xcb_free_pixmap(xnestUpstreamInfo.conn, xnestPixmap(pPixmap));
    FreePixmap(pPixmap);
    return True;
}

Bool xnestModifyPixmapHeader(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
  if(!xnestPixmapPriv(pPixmap).pixmap && width > 0 && height > 0) {
        uint pixmap = xcb_generate_id(xnestUpstreamInfo.conn);
        xcb_create_pixmap(xnestUpstreamInfo.conn, depth, pixmap,
                          xnestDefaultWindows[pPixmap.drawable.pScreen.myNum],
                          width, height);
        xnestPixmapPriv(pPixmap).pixmap = pixmap;
  }

  return miModifyPixmapHeader(pPixmap, width, height, depth,
                              bitsPerPixel, devKind, pPixData);
}

RegionPtr xnestPixmapToRegion(PixmapPtr pPixmap)
{
    RegionPtr pReg = void, pTmpReg = void;
    int x = void, y = void;
    c_ulong previousPixel = void, currentPixel = void;
    BoxRec Box = { 0, 0, 0, 0 };
    Bool overlap = void;

    if (pPixmap.drawable.depth != 1) {
        LogMessage(X_WARNING, "xnestPixmapToRegion() depth != 1: %d\n", pPixmap.drawable.depth);
        return null;
    }

    xcb_generic_error_t* err = null;
    xcb_get_image_reply_t* reply = xcb_get_image_reply(
        xnestUpstreamInfo.conn,
        xcb_get_image(
            xnestUpstreamInfo.conn,
            XCB_IMAGE_FORMAT_XY_PIXMAP,
            xnestPixmap(pPixmap),
            0,
            0,
            pPixmap.drawable.width,
            pPixmap.drawable.height,
            ~0),
        &err);

    if (err) {
        //  badMatch may happeen if the upstream window is currently minimized
        if (err.error_code != BadMatch)
            ErrorF("xnestGetImage: received error %d\n", err.error_code);
        free(err);
        return null;
    }

    if (!reply) {
        ErrorF("xnestGetImage: received no reply\n");
        return null;
    }

    pReg = RegionCreate(null, 1);
    pTmpReg = RegionCreate(null, 1);
    if (!pReg || !pTmpReg) {
        free(reply);
        return NullRegion;
    }

    ubyte* image_data = xcb_get_image_data(reply);
    for (y = 0; y < pPixmap.drawable.height; y++) {
        Box.y1 = y;
        Box.y2 = y + 1;
        previousPixel = 0L;
        const(int) line_start = mixin(BitmapBytePad!("pPixmap.drawable.width")) * y;

        for (x = 0; x < pPixmap.drawable.width; x++) {
            currentPixel = ((image_data[line_start + (x/8)]) >> (x % 8)) & 1;
            if (previousPixel != currentPixel) {
                if (previousPixel == 0L) {
                    /* left edge */
                    Box.x1 = x;
                }
                else if (currentPixel == 0L) {
                    /* right edge */
                    Box.x2 = x;
                    RegionReset(pTmpReg, &Box);
                    RegionAppend(pReg, pTmpReg);
                }
                previousPixel = currentPixel;
            }
        }
        if (previousPixel != 0L) {
            /* right edge because of the end of pixmap */
            Box.x2 = pPixmap.drawable.width;
            RegionReset(pTmpReg, &Box);
            RegionAppend(pReg, pTmpReg);
        }
    }

    RegionDestroy(pTmpReg);
    free(reply);

    RegionValidate(pReg, &overlap);

    return pReg;
}
