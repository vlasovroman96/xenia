module GC;
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

import core.stdc.stdint;

// //import externs.X11.fonts.fontstruct;
//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import externs.xcb.xcb;
import externs.xcb.xcb_aux;

import include.regionstr;

import include.windowstr;
import dix.pixmap;
import include.scrnintstr;
import midash;
import dix.gc;

import xnest_xcb;
import hw.xnest.GCOps;


// import Display;
// import XNGC;
// module hw.xnest.GCOps;
// import Drawable;
// import XNFont;
// import Color;

DevPrivateKeyRec xnestGCPrivateKeyRec;

private GCFuncs xnestFuncs = {
    &xnestValidateGC,
    &xnestChangeGC,
    &xnestCopyGC,
    &xnestDestroyGC,
    &xnestChangeClip,
    &xnestDestroyClip,
    &xnestCopyClip,
};

private GCOps xnestOps = {
    &xnestFillSpans,
    &xnestSetSpans,
    &xnestPutImage,
    &xnestCopyArea,
    &xnestCopyPlane,
    &xnestPolyPoint,
    &xnestPolylines,
    &xnestPolySegment,
    &xnestPolyRectangle,
    &xnestPolyArc,
    &xnestFillPolygon,
    &xnestPolyFillRect,
    &xnestPolyFillArc,
    &xnestPolyText8,
    &xnestPolyText16,
    &xnestImageText8,
    &xnestImageText16,
    &xnestImageGlyphBlt,
    &xnestPolyGlyphBlt,
    &xnestPushPixels
};

Bool xnestCreateGC(GCPtr pGC)
{
    pGC.funcs = &xnestFuncs;
    pGC.ops = &xnestOps;

    pGC.miTranslate = 1;

    xnestGCPriv(pGC).gc = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_create_gc(xnestUpstreamInfo.conn,
                  xnestGCPriv(pGC).gc,
                  xnestDefaultDrawables[pGC.depth],
                  0,
                  null);

    return TRUE;
}

void xnestValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDrawable)
{
}

void xnestChangeGC(GCPtr pGC, c_ulong mask)
{
    xcb_params_gc_t values = void;

    if (mask & GCFunction)
        values.function_ = pGC.alu;

    if (mask & GCPlaneMask)
        values.plane_mask = pGC.planemask;

    if (mask & GCForeground)
        values.foreground = xnestPixel(pGC.fgPixel);

    if (mask & GCBackground)
        values.background = xnestPixel(pGC.bgPixel);

    if (mask & GCLineWidth)
        values.line_width = pGC.lineWidth;

    if (mask & GCLineStyle)
        values.line_style = pGC.lineStyle;

    if (mask & GCCapStyle)
        values.cap_style = pGC.capStyle;

    if (mask & GCJoinStyle)
        values.join_style = pGC.joinStyle;

    if (mask & GCFillStyle)
        values.fill_style = pGC.fillStyle;

    if (mask & GCFillRule)
        values.fill_rule = pGC.fillRule;

    if (mask & GCTile) {
        if (pGC.tileIsPixel)
            mask &= ~GCTile;
        else
            values.tile = xnestPixmap(pGC.tile.pixmap);
    }

    if (mask & GCStipple)
        values.stipple = xnestPixmap(pGC.stipple);

    if (mask & GCTileStipXOrigin)
        values.tile_stipple_origin_x = pGC.patOrg.x;

    if (mask & GCTileStipYOrigin)
        values.tile_stipple_origin_y = pGC.patOrg.y;

    if (mask & GCFont)
        values.font = xnestFontPriv(pGC.font).font_id;

    if (mask & GCSubwindowMode)
        values.subwindow_mode = pGC.subWindowMode;

    if (mask & GCGraphicsExposures)
        values.graphics_exposures = pGC.graphicsExposures;

    if (mask & GCClipXOrigin)
        values.clip_originX = pGC.clipOrg.x;

    if (mask & GCClipYOrigin)
        values.clip_originY = pGC.clipOrg.y;

    if (mask & GCClipMask)      /* this is handled in change clip */
        mask &= ~GCClipMask;

    if (mask & GCDashOffset)
        values.dash_offset = pGC.dashOffset;

    if (mask & GCDashList) {
        mask &= ~GCDashList;
        xcb_set_dashes(xnestUpstreamInfo.conn,
                       xnest_upstream_gc(pGC),
                       pGC.dashOffset,
                       pGC.numInDashList,
                       cast(ubyte*) pGC.dash);
    }

    if (mask & GCArcMode)
        values.arc_mode = pGC.arcMode;

    if (mask)
        xcb_aux_change_gc(xnestUpstreamInfo.conn,
                          xnest_upstream_gc(pGC),
                          mask,
                          &values);
}

void xnestCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst)
{
    xcb_copy_gc(xnestUpstreamInfo.conn,
                xnestGC(pGCSrc),
                xnestGC(pGCDst),
                mask);
}

void xnestDestroyGC(GCPtr pGC)
{
    xcb_free_gc(xnestUpstreamInfo.conn, xnestGC(pGC));
}

void xnestChangeClip(GCPtr pGC, int type, void* pValue, int nRects)
{
    xnestDestroyClip(pGC);

    switch (type) {
    case CT_NONE:
        {
            uint pixmap = XCB_PIXMAP_NONE;
            xcb_change_gc(xnestUpstreamInfo.conn,
                          xnest_upstream_gc(pGC),
                          XCB_GC_CLIP_MASK,
                          &pixmap);
        }
        pValue = null;
        break;

    case CT_REGION:
        {
            nRects = RegionNumRects(cast(RegionPtr) pValue);
            xcb_rectangle_t* rects = cast(xcb_rectangle_t*) calloc(nRects, xcb_rectangle_t.sizeof);
            if (rects is null) {
                ErrorF("xnestChangeClip: memory alloc failure");
                return;
            }
            BoxPtr pBox = RegionRects(cast(RegionPtr) pValue);
            for (int i = nRects; i-- > 0;)
                rects[i] = xcb_rectangle_t (
                    x = pBox[i].x1,
                    y = pBox[i].y1,
                    width = pBox[i].x2 - pBox[i].x1,
                    height = pBox[i].y2 - pBox[i].y1,
                );
            xcb_set_clip_rectangles(
                xnestUpstreamInfo.conn,
                XCB_CLIP_ORDERING_UNSORTED,
                xnest_upstream_gc(pGC),
                0,
                0,
                nRects,
                rects);

            free(rects);
        }
        break;

    case CT_PIXMAP:
        {
            uint val = xnestPixmap(cast(PixmapPtr) pValue);
            xcb_change_gc(xnestUpstreamInfo.conn,
                          xnest_upstream_gc(pGC),
                          XCB_GC_CLIP_MASK,
                          &val);
        }
        /*
         * Need to change into region, so subsequent uses are with
         * current pixmap contents.
         */
        pGC.clientClip = (*pGC.pScreen.BitmapToRegion) (cast(PixmapPtr) pValue);
        dixDestroyPixmap(cast(PixmapPtr) pValue, 0);
        pValue = pGC.clientClip;
        break;

    case CT_UNSORTED:
        xcb_set_clip_rectangles(
            xnestUpstreamInfo.conn,
            XCB_CLIP_ORDERING_UNSORTED,
            xnest_upstream_gc(pGC),
            pGC.clipOrg.x, pGC.clipOrg.y,
            nRects,
            cast(xcb_rectangle_t*)pValue);
        break;

    case CT_YSORTED:
        xcb_set_clip_rectangles(
            xnestUpstreamInfo.conn,
            XCB_CLIP_ORDERING_Y_SORTED,
            xnest_upstream_gc(pGC),
            pGC.clipOrg.x,
            pGC.clipOrg.y,
            nRects,
            cast(xcb_rectangle_t*)pValue);
        break;

    case CT_YXSORTED:
        xcb_set_clip_rectangles(
            xnestUpstreamInfo.conn,
            XCB_CLIP_ORDERING_YX_SORTED,
            xnest_upstream_gc(pGC),
            pGC.clipOrg.x,
            pGC.clipOrg.y,
            nRects,
            cast(xcb_rectangle_t*)pValue);

        break;

    case CT_YXBANDED:
        xcb_set_clip_rectangles(
            xnestUpstreamInfo.conn,
            XCB_CLIP_ORDERING_YX_BANDED,
            xnest_upstream_gc(pGC),
            pGC.clipOrg.x,
            pGC.clipOrg.y,
            nRects,
            cast(xcb_rectangle_t*)pValue);
        break;
    default: break;}

    switch (type) {
    default:
        break;

    case CT_UNSORTED:
    case CT_YSORTED:
    case CT_YXSORTED:
    case CT_YXBANDED:
        /* server clip representation is a region */
        pGC.clientClip = RegionFromRects(nRects, cast(xRectangle*) pValue, type);
        free(pValue);
        pValue = pGC.clientClip;
        break;
    }

    pGC.clientClip = pValue;
}

void xnestDestroyClip(GCPtr pGC)
{
    if (pGC.clientClip) {
        RegionDestroy(pGC.clientClip);
        uint val = XCB_PIXMAP_NONE;
        xcb_change_gc(xnestUpstreamInfo.conn,
                      xnest_upstream_gc(pGC),
                      XCB_GC_CLIP_MASK,
                      &val);
        pGC.clientClip = null;
    }
}

void xnestCopyClip(GCPtr pGCDst, GCPtr pGCSrc)
{
    if (pGCSrc.clientClip) {
        RegionPtr pRgn = RegionCreate(null, 1);
        RegionCopy(pRgn, pGCSrc.clientClip);
        xnestChangeClip(pGCDst, CT_REGION, pRgn, 0);
    } else {
        xnestDestroyClip(pGCDst);
    }
}
