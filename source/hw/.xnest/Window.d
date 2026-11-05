module Window;
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

import externs.xcb.xcb;
import externs.xcb.shape;
import externs.xcb.xcb_aux;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import dix.window_priv;
import region;
import mi.mi_priv;

import dix.gc;
import dix.window;
import dix.pixmap;
import dix.scrnintstr;

import xnest_xcb;


import Display;
import Screen;
import XNGC;
import Drawable;
import Color;
import dix.events;
import Args;

DevPrivateKeyRec xnestWindowPrivateKeyRec;

private int xnestFindWindowMatch(WindowPtr pWin, void* ptr)
{
    xnestWindowMatch* wm = cast(xnestWindowMatch*) ptr;

    if (wm.window == xnestWindow(pWin)) {
        wm.pWin = pWin;
        return WT_STOPWALKING;
    }
    else
        return WT_WALKCHILDREN;
}

WindowPtr xnestWindowPtr(xcb_window_t window)
{
    xnestWindowMatch wm = void;
    int i = void;

    wm.pWin = NullWindow;
    wm.window = window;

    for (i = 0; i < xnestNumScreens; i++) {
        ScreenPtr walkScreen = screenInfo.screens[i];
        WalkTree(walkScreen, &xnestFindWindowMatch, cast(void*) &wm);
        if (wm.pWin)
            break;
    }

    return wm.pWin;
}

Bool xnestCreateWindow(WindowPtr pWin)
{
    c_ulong mask = void;
    xcb_params_cw_t attributes = { 0 };
    uint visual = CopyFromParent; /* 0L */
    ColormapPtr pCmap = void;

    if (pWin.drawable.class_ == InputOnly) {
        mask = 0L;
        visual = CopyFromParent;
    }
    else {
        mask = XCB_CW_EVENT_MASK | XCB_CW_BACKING_STORE;
        attributes.event_mask = XCB_EVENT_MASK_EXPOSURE;
        attributes.backing_store = XCB_BACKING_STORE_NOT_USEFUL;

        if (pWin.parent) {
            if (pWin.optional &&
                pWin.optional.visual != mixin(wVisual!("pWin.parent"))) {
                visual = xnest_visual_map_to_upstream(mixin(wVisual!("pWin")));
                mask |= XCB_CW_COLORMAP;
                if (pWin.optional.colormap) {
                    dixLookupResourceByType(cast(void**) &pCmap, mixin(wColormap!("pWin")),
                                            X11_RESTYPE_COLORMAP, serverClient,
                                            DixUseAccess);
                    attributes.colormap = xnestColormap(pCmap);
                }
                else
                    attributes.colormap = xnest_upstream_visual_to_cmap(visual);
            }
            else
                visual = CopyFromParent;
        }
        else {                  /* root windows have their own colormaps at creation time */
            visual = xnest_visual_map_to_upstream(mixin(wVisual!("pWin")));
            dixLookupResourceByType(cast(void**) &pCmap, mixin(wColormap!("pWin")),
                                    X11_RESTYPE_COLORMAP, serverClient, DixUseAccess);
            mask |= XCB_CW_COLORMAP;
            attributes.colormap = xnestColormap(pCmap);
        }
    }

    xnestWindowPriv(pWin).window = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_aux_create_window(xnestUpstreamInfo.conn,
                          pWin.drawable.depth,
                          xnestWindowPriv(pWin).window,
                          xnestWindowParent(pWin),
                          pWin.origin.x - mixin(wBorderWidth!("pWin")),
                          pWin.origin.y - mixin(wBorderWidth!("pWin")),
                          pWin.drawable.width,
                          pWin.drawable.height,
                          pWin.borderWidth,
                          pWin.drawable.class_,
                          visual,
                          mask,
                          &attributes);

    xnestWindowPriv(pWin).parent = xnestWindowParent(pWin);
    xnestWindowPriv(pWin).x = pWin.origin.x - mixin(wBorderWidth!("pWin"));
    xnestWindowPriv(pWin).y = pWin.origin.y - mixin(wBorderWidth!("pWin"));
    xnestWindowPriv(pWin).width = pWin.drawable.width;
    xnestWindowPriv(pWin).height = pWin.drawable.height;
    xnestWindowPriv(pWin).border_width = pWin.borderWidth;
    xnestWindowPriv(pWin).sibling_above = XCB_WINDOW_NONE;
    if (pWin.nextSib)
        xnestWindowPriv(pWin.nextSib).sibling_above = xnestWindow(pWin);
    xnestWindowPriv(pWin).bounding_shape = RegionCreate(null, 1);
    xnestWindowPriv(pWin).clip_shape = RegionCreate(null, 1);

    if (!pWin.parent)          /* only the root window will have the right colormap */
        xnestSetInstalledColormapWindows(pWin.drawable.pScreen);

    return TRUE;
}

Bool xnestDestroyWindow(WindowPtr pWin)
{
    if (pWin.nextSib)
        xnestWindowPriv(pWin.nextSib).sibling_above =
            xnestWindowPriv(pWin).sibling_above;
    RegionDestroy(xnestWindowPriv(pWin).bounding_shape);
    RegionDestroy(xnestWindowPriv(pWin).clip_shape);
    xcb_destroy_window(xnestUpstreamInfo.conn, xnestWindow(pWin));
    xnestWindowPriv(pWin).window = XCB_WINDOW_NONE;

    if (pWin.optional && pWin.optional.colormap && pWin.parent)
        xnestSetInstalledColormapWindows(pWin.drawable.pScreen);

    return TRUE;
}

Bool xnestPositionWindow(WindowPtr pWin, int x, int y)
{
    xnestConfigureWindow(pWin,
                         XCB_CONFIG_WINDOW_SIBLING | 
                         XCB_CONFIG_WINDOW_X | 
                         XCB_CONFIG_WINDOW_Y | 
                         XCB_CONFIG_WINDOW_WIDTH | 
                         XCB_CONFIG_WINDOW_HEIGHT | 
                         XCB_CONFIG_WINDOW_BORDER_WIDTH);

    return TRUE;
}

void xnestConfigureWindow(WindowPtr pWin, uint mask)
{
    uint valuemask = void;
    xcb_params_configure_window_t values = void;

    if (mask & XCB_CONFIG_WINDOW_SIBLING  &&
        xnestWindowPriv(pWin).parent != xnestWindowParent(pWin)) {

        xcb_reparent_window(
            xnestUpstreamInfo.conn,
            xnestWindow(pWin),
            xnestWindowParent(pWin),
            pWin.origin.x - mixin(wBorderWidth!("pWin")),
            pWin.origin.y - mixin(wBorderWidth!("pWin")));

        xnestWindowPriv(pWin).parent = xnestWindowParent(pWin);
        xnestWindowPriv(pWin).x = pWin.origin.x - mixin(wBorderWidth!("pWin"));
        xnestWindowPriv(pWin).y = pWin.origin.y - mixin(wBorderWidth!("pWin"));
        xnestWindowPriv(pWin).sibling_above = XCB_WINDOW_NONE;
        if (pWin.nextSib)
            xnestWindowPriv(pWin.nextSib).sibling_above = xnestWindow(pWin);
    }

    valuemask = 0;

    if (mask & XCB_CONFIG_WINDOW_X &&
        xnestWindowPriv(pWin).x != pWin.origin.x - mixin(wBorderWidth!("pWin"))) {
        valuemask |= XCB_CONFIG_WINDOW_X;
        values.x =
            xnestWindowPriv(pWin).x = pWin.origin.x - mixin(wBorderWidth!("pWin"));
    }

    if (mask & XCB_CONFIG_WINDOW_Y &&
        xnestWindowPriv(pWin).y != pWin.origin.y - mixin(wBorderWidth!("pWin"))) {
        valuemask |= XCB_CONFIG_WINDOW_Y;
        values.y =
            xnestWindowPriv(pWin).y = pWin.origin.y - mixin(wBorderWidth!("pWin"));
    }

    if (mask & XCB_CONFIG_WINDOW_WIDTH && xnestWindowPriv(pWin).width != pWin.drawable.width) {
        valuemask |= XCB_CONFIG_WINDOW_WIDTH;
        values.width = xnestWindowPriv(pWin).width = pWin.drawable.width;
    }

    if (mask & XCB_CONFIG_WINDOW_HEIGHT &&
        xnestWindowPriv(pWin).height != pWin.drawable.height) {
        valuemask |= XCB_CONFIG_WINDOW_HEIGHT;
        values.height = xnestWindowPriv(pWin).height = pWin.drawable.height;
    }

    if (mask & XCB_CONFIG_WINDOW_BORDER_WIDTH &&
        xnestWindowPriv(pWin).border_width != pWin.borderWidth) {
        valuemask |= XCB_CONFIG_WINDOW_BORDER_WIDTH;
        values.border_width =
            xnestWindowPriv(pWin).border_width = pWin.borderWidth;
    }

    xcb_aux_configure_window(xnestUpstreamInfo.conn, xnestWindow(pWin), valuemask, &values);

    if (mask & XCB_CONFIG_WINDOW_SIBLING &&
        xnestWindowPriv(pWin).sibling_above != xnestWindowSiblingAbove(pWin)) {
        WindowPtr pSib = void;

        /* find the top sibling */
        for (pSib = pWin; pSib.prevSib != NullWindow; pSib = pSib.prevSib){}

        /* the top sibling */
        valuemask = XCB_CONFIG_WINDOW_STACK_MODE;
        values.stack_mode = Above;

        xcb_aux_configure_window(xnestUpstreamInfo.conn, xnestWindow(pSib), valuemask, &values);
        xnestWindowPriv(pSib).sibling_above = XCB_WINDOW_NONE;

        /* the rest of siblings */
        for (pSib = pSib.nextSib; pSib != NullWindow; pSib = pSib.nextSib) {
            valuemask = XCB_CONFIG_WINDOW_SIBLING | XCB_CONFIG_WINDOW_STACK_MODE;
            values.sibling = xnestWindowSiblingAbove(pSib);
            values.stack_mode = Below;
            xcb_aux_configure_window(xnestUpstreamInfo.conn, xnestWindow(pSib), valuemask, &values);
            xnestWindowPriv(pSib).sibling_above =
                xnestWindowSiblingAbove(pSib);
        }
    }
}

Bool xnestChangeWindowAttributes(WindowPtr pWin, c_ulong mask)
{
    xcb_params_cw_t attributes = void;

    if (mask & XCB_CW_BACK_PIXMAP)
        switch (pWin.backgroundState) {
        case XCB_BACK_PIXMAP_NONE:
            attributes.back_pixmap = XCB_PIXMAP_NONE;
            break;

        case XCB_BACK_PIXMAP_PARENT_RELATIVE:
            attributes.back_pixmap = ParentRelative;
            break;

        case BackgroundPixmap:
            attributes.back_pixmap = xnestPixmap(pWin.background.pixmap);
            break;

        case BackgroundPixel:
            mask &= ~XCB_CW_BACK_PIXMAP;
            break;
        default: break;}

    if (mask & XCB_CW_BACK_PIXEL) {
        if (pWin.backgroundState == BackgroundPixel)
            attributes.back_pixel = xnestPixel(pWin.background.pixel);
        else
            mask &= ~XCB_CW_BACK_PIXEL;
    }

    if (mask & XCB_CW_BORDER_PIXMAP) {
        if (pWin.borderIsPixel)
            mask &= ~XCB_CW_BORDER_PIXMAP;
        else
            attributes.border_pixmap = xnestPixmap(pWin.border.pixmap);
    }

    if (mask & XCB_CW_BORDER_PIXEL) {
        if (pWin.borderIsPixel)
            attributes.border_pixel = xnestPixel(pWin.border.pixel);
        else
            mask &= ~XCB_CW_BORDER_PIXEL;
    }

    if (mask & XCB_CW_BIT_GRAVITY)
        attributes.bit_gravity = pWin.bitGravity;

    if (mask & XCB_CW_WIN_GRAVITY)    /* dix does this for us */
        mask &= ~XCB_CW_WIN_GRAVITY;

    if (mask & XCB_CW_BACKING_STORE)  /* this is really not useful */
        mask &= ~XCB_CW_BACKING_STORE;

    if (mask & XCB_CW_BACKING_PLANES) /* this is really not useful */
        mask &= ~XCB_CW_BACKING_PLANES;

    if (mask & XCB_CW_BACKING_PIXEL)  /* this is really not useful */
        mask &= ~XCB_CW_BACKING_PIXEL;

    if (mask & XCB_CW_OVERRIDE_REDIRECT)
        attributes.override_redirect = pWin.overrideRedirect;

    if (mask & XCB_CW_SAVE_UNDER)     /* this is really not useful */
        mask &= ~XCB_CW_SAVE_UNDER;

    if (mask & XCB_CW_EVENT_MASK)     /* events are handled elsewhere */
        mask &= ~XCB_CW_EVENT_MASK;

    if (mask & XCB_CW_DONT_PROPAGATE) /* events are handled elsewhere */
        mask &= ~XCB_CW_DONT_PROPAGATE;

    if (mask & XCB_CW_COLORMAP) {
        ColormapPtr pCmap = void;

        dixLookupResourceByType(cast(void**) &pCmap, mixin(wColormap!("pWin")),
                                X11_RESTYPE_COLORMAP, serverClient, DixUseAccess);

        attributes.colormap = xnestColormap(pCmap);

        xnestSetInstalledColormapWindows(pWin.drawable.pScreen);
    }

    if (mask & XCB_CW_CURSOR)        /* this is handled in cursor code */
        mask &= ~XCB_CW_CURSOR;

    if (mask) {
        xcb_aux_change_window_attributes(xnestUpstreamInfo.conn,
                                         xnestWindow(pWin),
                                         mask,
                                         &attributes);
    }
    return TRUE;
}

Bool xnestRealizeWindow(WindowPtr pWin)
{
    xnestConfigureWindow(pWin, XCB_CONFIG_WINDOW_SIBLING);
    xnestShapeWindow(pWin);
    xcb_map_window(xnestUpstreamInfo.conn, xnestWindow(pWin));

    return TRUE;
}

Bool xnestUnrealizeWindow(WindowPtr pWin)
{
    xcb_unmap_window(xnestUpstreamInfo.conn, xnestWindow(pWin));
    return TRUE;
}

void xnestCopyWindow(WindowPtr pWin, xPoint oldOrigin, RegionPtr oldRegion)
{
}

void xnestClipNotify(WindowPtr pWin, int dx, int dy)
{
    xnestConfigureWindow(pWin, XCB_CONFIG_WINDOW_SIBLING);
    xnestShapeWindow(pWin);
}

void xnestSetShape(WindowPtr pWin, int kind)
{
    xnestShapeWindow(pWin);
    miSetShape(pWin, kind);
}

private Bool xnestRegionEqual(RegionPtr pReg1, RegionPtr pReg2)
{
    BoxPtr pBox1 = void, pBox2 = void;
    uint n1 = void, n2 = void;

    if (pReg1 == pReg2)
        return TRUE;

    if (pReg1 == NullRegion || pReg2 == NullRegion)
        return FALSE;

    pBox1 = RegionRects(pReg1);
    n1 = RegionNumRects(pReg1);

    pBox2 = RegionRects(pReg2);
    n2 = RegionNumRects(pReg2);

    if (n1 != n2)
        return FALSE;

    if (pBox1 == pBox2)
        return TRUE;

    if (memcmp(pBox1, pBox2, n1 * BoxRec.sizeof))
        return FALSE;

    return TRUE;
}

void xnestShapeWindow(WindowPtr pWin)
{
    if (!xnestRegionEqual(xnestWindowPriv(pWin).bounding_shape,
                          mixin(wBoundingShape!("pWin")))) {

        if (mixin(wBoundingShape!("pWin"))) {
            RegionCopy(xnestWindowPriv(pWin).bounding_shape,
                       mixin(wBoundingShape!("pWin")));

            const(int) num_rects = RegionNumRects(xnestWindowPriv(pWin).bounding_shape);
            const(BoxPtr) pBox = RegionRects(xnestWindowPriv(pWin).bounding_shape);
            xcb_rectangle_t* rects = cast(xcb_rectangle_t*) calloc(num_rects, xcb_rectangle_t.sizeof);

            for (int i = 0; i < num_rects; i++) {
                rects[i].x = pBox[i].x1;
                rects[i].y = pBox[i].y1;
                rects[i].width = pBox[i].x2 - pBox[i].x1;
                rects[i].height = pBox[i].y2 - pBox[i].y1;
            }

            xcb_shape_rectangles(xnestUpstreamInfo.conn, XCB_SHAPE_SO_SET,
                                 XCB_SHAPE_SK_BOUNDING, XCB_CLIP_ORDERING_YX_BANDED,
                                 xnestWindow(pWin), 0, 0, num_rects, rects);
            free(rects);
        }
        else {
            RegionEmpty(xnestWindowPriv(pWin).bounding_shape);
            xcb_shape_mask(xnestUpstreamInfo.conn, XCB_SHAPE_SO_SET,
                           XCB_SHAPE_SK_BOUNDING, xnestWindow(pWin),
                           0, 0, XCB_PIXMAP_NONE);
        }
    }

    if (!xnestRegionEqual(xnestWindowPriv(pWin).clip_shape, mixin(wClipShape!("pWin")))) {

        if (mixin(wClipShape!("pWin"))) {
            RegionCopy(xnestWindowPriv(pWin).clip_shape, mixin(wClipShape!("pWin")));

            const(int) num_rects = RegionNumRects(xnestWindowPriv(pWin).clip_shape);
            const(BoxPtr) pBox = RegionRects(xnestWindowPriv(pWin).clip_shape);
            xcb_rectangle_t* rects = cast(xcb_rectangle_t*) calloc(num_rects, xcb_rectangle_t.sizeof);

            for (int i = 0; i < num_rects; i++) {
                rects[i].x = pBox[i].x1;
                rects[i].y = pBox[i].y1;
                rects[i].width = pBox[i].x2 - pBox[i].x1;
                rects[i].height = pBox[i].y2 - pBox[i].y1;
            }

            xcb_shape_rectangles(xnestUpstreamInfo.conn, XCB_SHAPE_SO_SET,
                                 XCB_SHAPE_SK_CLIP, XCB_CLIP_ORDERING_YX_BANDED,
                                 xnestWindow(pWin), 0, 0, num_rects, rects);
            free(rects);
        }
        else {
            RegionEmpty(xnestWindowPriv(pWin).clip_shape);
            xcb_shape_mask(xnestUpstreamInfo.conn, XCB_SHAPE_SO_SET,
                           XCB_SHAPE_SK_CLIP, xnestWindow(pWin), 0, 0, XCB_PIXMAP_NONE);
        }
    }
}

void xnest_screen_ClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures)
{
    xcb_clear_area(xnestUpstreamInfo.conn,
                   generateExposures,
                   xnestWindow(pWin),
                   x, y, w, h);
}
