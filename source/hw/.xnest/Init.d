module Init;
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

import core.stdc.stddef;
//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;
// //import externs.X11.fonts.fontstruct;
// //import externs.X11.fonts.libxfont2;

import dix.screenint_priv;
import mi.mi_priv;
import miext.extinit_priv;
import os.ddx_priv;
import os.log_priv;
import os.osdep;

import include.screenint;
import include.input;
import include.misc;
import include.scrnintstr;
import include.windowstr;
import include.servermd;
import include.dixfontstr;

import xnest_xcb;

import Display;
import Screen;
import Pointer;
import Keyboard;
import Handlers;
import include.events;
import Init;
import Args;
import Drawable;
import XNGC;
import build.xlibre_server;
import XNFont;
static if(DPMSExtension) {
import Xext.dpmsproc;
}

Bool xnestDoFullGeneration = TRUE;

/* Xnest doesn't support GLX yet, so we don't link it, but still have
   satisfy DIX's symbol requirements */
static if (GLXEXT) {
void GlxExtensionInit()
{
}

Bool noGlxExtension = FALSE;
}

void InitOutput(int argc, char** argv)
{
    int i = void;

    xnestOpenDisplay(argc, argv);

    screenInfo.imageByteOrder = xnestUpstreamInfo.setup.image_byte_order;
    screenInfo.bitmapScanlineUnit = xnestUpstreamInfo.setup.bitmap_format_scanline_unit;
    screenInfo.bitmapScanlinePad = xnestUpstreamInfo.setup.bitmap_format_scanline_pad;
    screenInfo.bitmapBitOrder = xnestUpstreamInfo.setup.bitmap_format_bit_order;
    screenInfo.numPixmapFormats = 0;

    xcb_format_t* fmt = xcb_setup_pixmap_formats(xnestUpstreamInfo.setup);
    const(xcb_format_t)* fmtend = fmt + xcb_setup_pixmap_formats_length(xnestUpstreamInfo.setup);
    for(; fmt != fmtend; ++fmt) {
        xcb_depth_iterator_t depth_iter = void;
        for (depth_iter = xcb_screen_allowed_depths_iterator(xnestUpstreamInfo.screenInfo);
             depth_iter.rem;
             xcb_depth_next(&depth_iter))
        {
            if ((fmt.depth == 1) ||
                (fmt.depth == depth_iter.data.depth)) {
                screenInfo.formats[screenInfo.numPixmapFormats].depth =
                    fmt.depth;
                screenInfo.formats[screenInfo.numPixmapFormats].bitsPerPixel =
                    fmt.bits_per_pixel;
                screenInfo.formats[screenInfo.numPixmapFormats].scanlinePad =
                    fmt.scanline_pad;
                screenInfo.numPixmapFormats++;
                break;
            }
        }
    }

    xnestFontPrivateIndex = xfont2_allocate_font_private_index();

    if (!xnestNumScreens)
        xnestNumScreens = 1;

    for (i = 0; i < xnestNumScreens; i++)
        AddScreen(xnestOpenScreen, argc, argv);

    xnestNumScreens = screenInfo.numScreens;

    xnestDoFullGeneration = FALSE;
}

private void xnestNotifyConnection(int fd, int ready, void* data)
{
    xnestCollectEvents();
}

void InitInput(int argc, char** argv)
{
    int rc = void;

    rc = AllocDevicePair(serverClient, "Xnest",
                         &xnestPointerDevice,
                         &xnestKeyboardDevice,
                         xnestPointerProc, xnestKeyboardProc, FALSE);

    if (rc != Success)
        FatalError("Failed to init Xnest default devices.\n");

    mieqInit();

    SetNotifyFd(xcb_get_file_descriptor(xnestUpstreamInfo.conn),
                &xnestNotifyConnection,
                X_NOTIFY_READ,
                null);

    RegisterBlockAndWakeupHandlers(xnestBlockHandler, xnestWakeupHandler, null);
}

void CloseInput()
{
    mieqFini();
}

void ddxGiveUp(ExitCode error)
{
    xnestDoFullGeneration = TRUE;
    xnestCloseDisplay();
}

void OsVendorInit()
{
    return;
}

void OsVendorFatalError(const(char)* f, va_list args)
{
    return;
}

static if (INPUTTHREAD) {
/** This function is called in Xserver/os/inputthread.c when starting
    the input thread. */
void ddxInputThreadInit()
{
}
}
