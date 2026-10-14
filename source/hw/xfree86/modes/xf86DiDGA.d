module xf86DiDGA;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.xorg_config;

import include.xf86DDC;

import include.xf86;
import include.xf86_OSproc;;
import include.dgaproc;
import hw.xfree86.common.dgaproc_priv;
import include.xf86Crtc;
import xf86Modes;
import include.gcstruct;
import include.scrnintstr;
import include.windowstr;
import hw.xfree86.common.xf86Helper;
import xf86DGA;
public import include.edid;
public import include.randrstr;
public import xf86Modes;
public import xf86Cursor;
public import include.xf86i2c;
public import dix.damage;
public import include.picturestr;
import include.rrtransform;
import include.xf86Parser;
import include.xf86Cursor;
import include.scrintstr;
import hw.xfree86.modes.xf86Crtc;

private Bool xf86_dga_get_modes(ScreenPtr pScreen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    DGAModePtr modes = void, mode = void;
    DisplayModePtr display_mode = void;
    int bpp = scrn.bitsPerPixel >> 3;
    int num = void;

    num = 0;
    display_mode = scrn.modes;
    while (display_mode) {
        num++;
        display_mode = display_mode.next;
        if (display_mode == scrn.modes)
            break;
    }

    if (!num)
        return FALSE;

    modes = cast(_DGAModeRec*)calloc(num, DGAModeRec.sizeof);
    if (!modes)
        return FALSE;

    num = 0;
    display_mode = scrn.modes;
    while (display_mode) {
        mode = modes + num++;

        mode.mode = display_mode;
        mode.flags = DGA_CONCURRENT_ACCESS;
        if (display_mode.Flags & V_DBLSCAN)
            mode.flags |= DGA_DOUBLESCAN;
        if (display_mode.Flags & V_INTERLACE)
            mode.flags |= DGA_INTERLACED;
        mode.byteOrder = scrn.imageByteOrder;
        mode.depth = scrn.depth;
        mode.bitsPerPixel = scrn.bitsPerPixel;
        mode.red_mask = scrn.mask.red;
        mode.green_mask = scrn.mask.green;
        mode.blue_mask = scrn.mask.blue;
        mode.visualClass = (bpp == 1) ? PseudoColor : TrueColor;
        mode.viewportWidth = display_mode.HDisplay;
        mode.viewportHeight = display_mode.VDisplay;
        mode.xViewportStep = (bpp == 3) ? 2 : 1;
        mode.yViewportStep = 1;
        mode.viewportFlags = DGA_FLIP_RETRACE;
        mode.offset = 0;
        mode.address = null;
        mode.imageWidth = mode.viewportWidth;
        mode.imageHeight = mode.viewportHeight;
        mode.bytesPerScanline = (mode.imageWidth * scrn.bitsPerPixel) >> 3;
        mode.pixmapWidth = mode.imageWidth;
        mode.pixmapHeight = mode.imageHeight;
        mode.maxViewportX = 0;
        mode.maxViewportY = 0;

        display_mode = display_mode.next;
        if (display_mode == scrn.modes)
            break;
    }
    free(xf86_config.dga_modes);
    xf86_config.dga_nmode = num;
    xf86_config.dga_modes = modes;
    return TRUE;
}

private Bool xf86_dga_set_mode(ScrnInfoPtr scrn, DGAModePtr display_mode)
{
    ScreenPtr pScreen = scrn.pScreen;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    if (!display_mode) {
        if (xf86_config.dga_save_mode) {
            xf86SwitchMode(pScreen, xf86_config.dga_save_mode);
            xf86_config.dga_save_mode = null;
        }
    }
    else {
        if (!xf86_config.dga_save_mode) {
            xf86_config.dga_save_mode = scrn.currentMode;
            xf86SwitchMode(pScreen, display_mode.mode);
        }
    }
    return TRUE;
}

private int xf86_dga_get_viewport(ScrnInfoPtr scrn)
{
    return 0;
}

private void xf86_dga_set_viewport(ScrnInfoPtr scrn, int x, int y, int flags)
{
    scrn.AdjustFrame(scrn, x, y);
}

private Bool xf86_dga_open_framebuffer(ScrnInfoPtr scrn, char** name, ubyte** mem, int* size, int* offset, int* flags)
{
    return FALSE;
}

private void xf86_dga_close_framebuffer(ScrnInfoPtr scrn)
{
}

private DGAFunctionRec xf86_dga_funcs = {
    &xf86_dga_open_framebuffer,
    &xf86_dga_close_framebuffer,
    &xf86_dga_set_mode,
    &xf86_dga_set_viewport,
    &xf86_dga_get_viewport,
    null,
    null,
    null,
    null
};

Bool xf86DiDGAReInit(ScreenPtr pScreen)
{
    return TRUE;
}

Bool _xf86_di_dga_reinit_internal(ScreenPtr pScreen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    if (!DGAScreenAvailable(pScreen))
        return TRUE;

    if (!xf86_dga_get_modes(pScreen))
        return FALSE;

    return DGAReInitModes(pScreen, xf86_config.dga_modes,
                          xf86_config.dga_nmode);
}

Bool xf86DiDGAInit(ScreenPtr pScreen, c_ulong dga_address)
{
    return TRUE;
}

Bool _xf86_di_dga_init_internal(ScreenPtr pScreen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    xf86_config.dga_flags = 0;
    xf86_config.dga_address = 0;
    xf86_config.dga_width = 0;
    xf86_config.dga_height = 0;
    xf86_config.dga_stride = 0;

    if (!xf86_dga_get_modes(pScreen))
        return FALSE;

    return DGAInit(pScreen, &xf86_dga_funcs, xf86_config.dga_modes,
                   xf86_config.dga_nmode);
}
