module Display;
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

import core.stdc.string;
import core.stdc.errno;

//import x11.X;
//import x11.Xproto;

import os.client_priv;
import os.osdep;

import include.scrintstr;
import dix.input;
import common.misc;
import include.scrnintstr;
import include.servermd;

import xnest_xcb;


import Display;
import Init;
import Args;

import hw.xnest.icon;
import hw.xnest.screensaver;

enum MAXDEPTH = 32;
enum MAXVISUALSPERDEPTH = 256;

Colormap* xnestDefaultColormaps;
int xnestNumPixmapFormats;
Drawable[MAXDEPTH + 1] xnestDefaultDrawables;
Pixmap xnestIconBitmap;
Pixmap xnestScreenSaverPixmap;
uint xnestBitmapGC;
uint xnestEventMask;

void xnestOpenDisplay(int argc, char** argv)
{
    int i = void;

    if (!xnestDoFullGeneration)
        return;

    xnestCloseDisplay();

    if (!xnest_upstream_setup(xnestDisplayName))
        FatalError("Unable to open display \"%s\".\n", xnestDisplayName);

    if (xnestParentWindow != cast(Window) 0)
        xnestEventMask = XCB_EVENT_MASK_STRUCTURE_NOTIFY;
    else
        xnestEventMask = 0L;

    for (i = 0; i <= MAXDEPTH; i++)
        xnestDefaultDrawables[i] = XCB_WINDOW_NONE;

    xcb_format_t* fmt = xcb_setup_pixmap_formats(xnestUpstreamInfo.setup);
    const(xcb_format_t)* fmtend = fmt + xcb_setup_pixmap_formats_length(xnestUpstreamInfo.setup);
    for(; fmt != fmtend; ++fmt) {
        xcb_depth_iterator_t depth_iter = void;
        for (depth_iter = xcb_screen_allowed_depths_iterator(xnestUpstreamInfo.screenInfo);
             depth_iter.rem;
             xcb_depth_next(&depth_iter))
        {
            if (fmt.depth == 1 || fmt.depth == depth_iter.data.depth) {
                uint pixmap = xcb_generate_id(xnestUpstreamInfo.conn);
                xcb_create_pixmap(xnestUpstreamInfo.conn,
                                  fmt.depth,
                                  pixmap,
                                  xnestUpstreamInfo.screenInfo.root,
                                  1, 1);
                xnestDefaultDrawables[fmt.depth] = pixmap;
            }
        }
    }

    xnestBitmapGC = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_create_gc(xnestUpstreamInfo.conn,
                  xnestBitmapGC,
                  xnestDefaultDrawables[1],
                  0,
                  null);

    if (!(xnestUserGeometry & XCB_CONFIG_WINDOW_X))
        xnestGeometry.x = 0;

    if (!(xnestUserGeometry & XCB_CONFIG_WINDOW_Y))
        xnestGeometry.y = 0;

    if (xnestParentWindow == 0) {
        if (!(xnestUserGeometry & XCB_CONFIG_WINDOW_WIDTH))
            xnestGeometry.width = 3 * xnestUpstreamInfo.screenInfo.width_in_pixels / 4;

        if (!(xnestUserGeometry & XCB_CONFIG_WINDOW_HEIGHT))
            xnestGeometry.height = 3 * xnestUpstreamInfo.screenInfo.height_in_pixels / 4;
    }

    if (!xnestUserBorderWidth)
        xnestBorderWidth = 1;

    xnestIconBitmap =
        xnest_create_bitmap_from_data(xnestUpstreamInfo.conn,
                                      xnestUpstreamInfo.screenInfo.root,
                                      cast(const(char)*) icon_bits, icon_width, icon_height);

    xnestScreenSaverPixmap =
        xnest_create_pixmap_from_bitmap_data(
                                    xnestUpstreamInfo.conn,
                                    xnestUpstreamInfo.screenInfo.root,
                                    cast(const(char)*) screensaver_bits,
                                    screensaver_width,
                                    screensaver_height,
                                    xnestUpstreamInfo.screenInfo.white_pixel,
                                    xnestUpstreamInfo.screenInfo.black_pixel,
                                    xnestUpstreamInfo.screenInfo.root_depth);
}

void xnestCloseDisplay()
{
    if (!xnestDoFullGeneration || !xnestUpstreamInfo.conn)
        return;

    /*
       If xnestDoFullGeneration all x resources will be destroyed upon closing
       the display connection.  There is no need to generate extra protocol.
     */
    free(xnestVisualMap);
    xnestVisualMap = null;
    xnestNumVisualMap = 0;

    xcb_disconnect(xnestUpstreamInfo.conn);
    xnestUpstreamInfo.conn = null;
    xnestUpstreamInfo.screenInfo = null;
    xnestUpstreamInfo.setup = null;
}
