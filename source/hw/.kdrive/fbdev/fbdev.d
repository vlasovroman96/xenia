module hw.kdrive.fbdev.fbdev;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1999 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;

import core.sys.posix.sys.ioctl;
import core.stdc.errno;

import fb.fb_priv;
import os.osdep;

import hw.kdrive.fbdev.fbdev;
import hw.kdrive.src.kdrive;
import hw.xfree86.fbdevhw.fbpriv;

struct _fbdevPriv {
    fb_var_screeninfo var;
    fb_fix_screeninfo fix;
    ushort[256] red;
    ushort[256] green;
    ushort[256] blue;
    int fd;
    char *fb;
    char *fb_base;
} 

struct _fbScreenConf {
const char *fbdevDevicePath;
Bool fbDisableShadow;
bool fbNoAccel;

char *fbdev_glvnd_provider;

char *fbdev_dri_path;
bool fbdev_auto_dri3;
bool fbdev_drm_master;

bool es_allowed;
bool force_es;

bool fbGlamorAllowed;
bool fbForceGlamor;

bool fbXVAllowed;
} 

alias FbScreenConf = _KdScreenInfo;


alias FbdevPriv = _fbdevPriv;

struct _fbdevScrPriv {
    Rotation randr;
    Bool shadow;
version(GLAMOR) {
// #ifdef GLAMOR
    int dri_fd;
// #endif
}
} 

alias FbdevScrPriv = _fbdevScrPriv;

private Bool fbdevInitialize(KdCardInfo* card, FbdevPriv* priv)
{
    c_ulong off = void;
    FbScreenConf* config = card.closure;

    if (config.fbdevDevicePath) {
        priv.fd = open(config.fbdevDevicePath, O_RDWR);
        if (priv.fd < 0) {
            ErrorF("Error opening framebuffer %s: %s\n",
                   config.fbdevDevicePath, strerror(errno));
            return False;
        }
    } else {
        char[10] devbuf = "/dev/fbxx";
        priv.fd = -1;
        for (int i = 0; i < 32 && priv.fd < 0; i++) {
            snprintf(devbuf.ptr, devbuf.sizeof,
                     "/dev/fb%d", i);
            priv.fd = open(devbuf.ptr, O_RDWR);

            if (priv.fd >= 0) {
                fb_fix_screeninfo fix = void;
                memset(&fix, 0, fix.sizeof);
                if (ioctl(priv.fd, FBIOGET_FSCREENINFO, &fix) < 0) {
                    close(priv.fd);
                    priv.fd = -1;
                }
            }
        }
        if (priv.fd < 0) {
            ErrorF("Error opening framebuffers /dev/fb[0-31]\n");
            return False;
        }
    }

    /* quiet valgrind */
    memset(&priv.fix, '\0', typeof(priv.fix).sizeof);
    if (ioctl(priv.fd, FBIOGET_FSCREENINFO, &priv.fix) < 0) {
        perror("Error with /dev/fb ioctl FIOGET_FSCREENINFO");
        close(priv.fd);
        return False;
    }
    /* quiet valgrind */
    memset(&priv.var, '\0', typeof(priv.var).sizeof);
    if (ioctl(priv.fd, FBIOGET_VSCREENINFO, &priv.var) < 0) {
        perror("Error with /dev/fb ioctl FIOGET_VSCREENINFO");
        close(priv.fd);
        return False;
    }

    priv.fb_base = cast(char*) mmap(cast(caddr_t) null,
                                  priv.fix.smem_len,
                                  PROT_READ | PROT_WRITE,
                                  MAP_SHARED, priv.fd, 0);

    if (priv.fb_base == cast(char*) -1) {
        perror("ERROR: mmap framebuffer fails!");
        close(priv.fd);
        return False;
    }
    off = cast(c_ulong) priv.fix.smem_start % cast(c_ulong) getpagesize();
    priv.fb = priv.fb_base + off;
    return True;
}

Bool fbdevCardInit(KdCardInfo* card)
{
    FbdevPriv* priv = void;

    priv = cast(FbdevPriv*) malloc(FbdevPriv.sizeof);
    if (!priv)
        return False;

    if (!fbdevInitialize(card, priv)) {
        free(priv);
        return False;
    }
    card.driver = priv;

    return True;
}

private Pixel fbdevMakeContig(Pixel orig, Pixel others)
{
    Pixel low = void;

    low = mixin(lowbit!orig) >> 1;
    while (low && (others & low) == 0) {
        orig |= low;
        low >>= 1;
    }
    return orig;
}

private Bool fbdevModeSupported(KdScreenInfo* screen, const(KdMonitorTiming)* t)
{
    return True;
}

private void fbdevConvertMonitorTiming(const(KdMonitorTiming)* t, fb_var_screeninfo* var)
{
    memset(var, 0, fb_var_screeninfo.sizeof);

    var.xres = t.horizontal;
    var.yres = t.vertical;
    var.xres_virtual = t.horizontal;
    var.yres_virtual = t.vertical;
    var.xoffset = 0;
    var.yoffset = 0;
    var.pixclock = t.clock ? 1000000000 / t.clock : 0;
    var.left_margin = t.hbp;
    var.right_margin = t.hfp;
    var.upper_margin = t.vbp;
    var.lower_margin = t.vfp;
    var.hsync_len = t.hblank - t.hfp - t.hbp;
    var.vsync_len = t.vblank - t.vfp - t.vbp;

    var.sync = 0;
    var.vmode = 0;

    if (t.hpol == KdSyncPositive)
        var.sync |= FB_SYNC_HOR_HIGH_ACT;
    if (t.vpol == KdSyncPositive)
        var.sync |= FB_SYNC_VERT_HIGH_ACT;
}

private Bool fbdevScreenInitialize(KdScreenInfo* screen, FbdevScrPriv* scrpriv)
{
    FbdevPriv* priv = screen.card.driver;
    Pixel allbits = void;
    int depth = void;
    Bool gray = void;
    fb_var_screeninfo var = void;
    const(KdMonitorTiming)* t = void;
    int k = void;

    k = ioctl(priv.fd, FBIOGET_VSCREENINFO, &var);

    if (!screen.width || !screen.height) {
        if (k >= 0) {
            screen.width = var.xres;
            screen.height = var.yres;
        }
        else {
            screen.width = 1024;
            screen.height = 768;
        }
        screen.rate = 103;     /* FIXME: should get proper value from fb driver */
    }
    if (!screen.fb.depth) {
        if (k >= 0)
            screen.fb.depth = var.bits_per_pixel;
        else
            screen.fb.depth = 16;
    }

    if ((screen.width != var.xres) || (screen.height != var.yres)) {
        t = KdFindMode(screen, &fbdevModeSupported);
        screen.rate = t.rate;
        screen.width = t.horizontal;
        screen.height = t.vertical;

        /* Now try setting the mode */
        if (k < 0 || (t.horizontal != var.xres || t.vertical != var.yres))
            fbdevConvertMonitorTiming(t, &var);
    }

    var.activate = FB_ACTIVATE_NOW;
    var.bits_per_pixel = screen.fb.depth;
    var.nonstd = 0;
    var.grayscale = 0;

    k = ioctl(priv.fd, FBIOPUT_VSCREENINFO, &var);

    if (k < 0) {
        fprintf(stderr, "error: %s\n", strerror(errno));
        return False;
    }

    /* Re-get the "fixed" parameters since they might have changed */
    k = ioctl(priv.fd, FBIOGET_FSCREENINFO, &priv.fix);
    if (k < 0)
        perror("FBIOGET_FSCREENINFO");

    /* Now get the new screeninfo */
    ioctl(priv.fd, FBIOGET_VSCREENINFO, &priv.var);
    depth = priv.var.bits_per_pixel;
    gray = priv.var.grayscale;

    /* Calculate fix.line_length if it's zero */
    if (!priv.fix.line_length)
        priv.fix.line_length = (priv.var.xres_virtual * depth + 7) / 8;

    switch (priv.fix.visual) {
    case FB_VISUAL_MONO01:
    case FB_VISUAL_MONO10:
        screen.fb.visuals = (1 << StaticGray);
        break;
    case FB_VISUAL_PSEUDOCOLOR:
        screen.fb.visuals = (1 << StaticGray);
        if (priv.var.bits_per_pixel == 1) {
            /* Override to monochrome, to have preallocated black/white */
            priv.fix.visual = FB_VISUAL_MONO01;
        } else if (gray) {
            /* could also support GrayScale, but what's the point? */
        } else {
            screen.fb.visuals = ((1 << StaticGray) |
                                  (1 << GrayScale) |
                                  (1 << StaticColor) |
                                  (1 << PseudoColor) |
                                  (1 << TrueColor) | (1 << DirectColor));
        }
        screen.fb.blueMask = 0x00;
        screen.fb.greenMask = 0x00;
        screen.fb.redMask = 0x00;
        break;
    case FB_VISUAL_STATIC_PSEUDOCOLOR:
        if (gray) {
            screen.fb.visuals = (1 << StaticGray);
        }
        else {
            screen.fb.visuals = (1 << StaticColor);
        }
        screen.fb.blueMask = 0x00;
        screen.fb.greenMask = 0x00;
        screen.fb.redMask = 0x00;
        break;
    case FB_VISUAL_TRUECOLOR:
    case FB_VISUAL_DIRECTCOLOR:
        screen.fb.visuals = (1 << TrueColor);
enum string Mask(string o,string l) = `(((1 << ` ~ l ~ `) - 1) << ` ~ o ~ `)`;
        screen.fb.redMask = mixin(Mask! (`priv.var.red.offset`, `priv.var.red.length`));
        screen.fb.greenMask =
            mixin(Mask! (`priv.var.green.offset`, `priv.var.green.length`));
        screen.fb.blueMask =
            mixin(Mask! (`priv.var.blue.offset`, `priv.var.blue.length`));

        /*
         * This is a kludge so that Render will work -- fill in the gaps
         * in the pixel
         */
        screen.fb.redMask = fbdevMakeContig(screen.fb.redMask,
                                             screen.fb.greenMask |
                                             screen.fb.blueMask);

        screen.fb.greenMask = fbdevMakeContig(screen.fb.greenMask,
                                               screen.fb.redMask |
                                               screen.fb.blueMask);

        screen.fb.blueMask = fbdevMakeContig(screen.fb.blueMask,
                                              screen.fb.redMask |
                                              screen.fb.greenMask);

        allbits =
            screen.fb.redMask | screen.fb.greenMask | screen.fb.blueMask;
        depth = 32;
        while (depth && !(allbits & (1 << (depth - 1))))
            depth--;
        break;
    default:
        return False;
        break;
    }
    screen.fb.depth = depth;
    screen.fb.bitsPerPixel = priv.var.bits_per_pixel;

    scrpriv.randr = screen.randr;

    return fbdevMapFramebuffer(screen);
}

Bool fbdevScreenInit(KdScreenInfo* screen)
{
    FbdevScrPriv* scrpriv = void;

    scrpriv = cast(FbdevScrPriv*) cast(FbdevScrPriv*) calloc(1, FbdevScrPriv.sizeof);
    if (!scrpriv)
        return False;
    screen.driver = scrpriv;
    if (!fbdevScreenInitialize(screen, scrpriv)) {
        screen.driver = 0;
        free(scrpriv);
        return False;
    }
    return True;
}

private void* fbdevWindowLinear(ScreenPtr pScreen, CARD32 row, CARD32 offset, int mode, CARD32* size, void* closure)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;

    if (!pScreenPriv.enabled) {
        *size = 0;
        return null;
    }
    *size = priv.fix.line_length;
    return cast(CARD8*) priv.fb + row * priv.fix.line_length + offset;
}

private void* fbdevWindowAfb(ScreenPtr pScreen, CARD32 row, CARD32 offset, int mode, CARD32* size, void* closure)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;

    if (!pScreenPriv.enabled) {
        *size = 0;
        return null;
    }
    /* offset to next plane */
    *size = priv.var.yres_virtual * priv.fix.line_length;
    return cast(CARD8*) priv.fb + row * priv.fix.line_length + offset;
}

Bool fbdevMapFramebuffer(KdScreenInfo* screen)
{
    FbdevScrPriv* scrpriv = screen.driver;
    KdPointerMatrix m = void;
    FbdevPriv* priv = screen.card.driver;
    FbScreenConf* config = screen.card.closure;

    if (!config.fbDisableShadow) {
        scrpriv.shadow = True;
    } else if (scrpriv.randr != RR_Rotate_0 ||
        priv.fix.type != FB_TYPE_PACKED_PIXELS) {
        scrpriv.shadow = True;
    } else {
        scrpriv.shadow = False;
    }

    KdComputePointerMatrix(&m, scrpriv.randr, screen.width, screen.height);

    KdSetPointerMatrix(&m);

    screen.width = priv.var.xres;
    screen.height = priv.var.yres;

    if (scrpriv.shadow) {
        if (!KdShadowFbAlloc(screen,
                             scrpriv.randr & (RR_Rotate_90 | RR_Rotate_270)))
            return False;
    }
    else {
        screen.fb.byteStride = priv.fix.line_length;
        screen.fb.pixelStride = (priv.fix.line_length * 8 /
                                  priv.var.bits_per_pixel);
        screen.fb.frameBuffer = cast(CARD8*) (priv.fb);
    }

    return True;
}

private void fbdevSetScreenSizes(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    FbdevPriv* priv = screen.card.driver;

    if (scrpriv.randr & (RR_Rotate_0 | RR_Rotate_180)) {
        pScreen.width = priv.var.xres;
        pScreen.height = priv.var.yres;
        pScreen.mmWidth = screen.width_mm;
        pScreen.mmHeight = screen.height_mm;
    }
    else {
        pScreen.width = priv.var.yres;
        pScreen.height = priv.var.xres;
        pScreen.mmWidth = screen.height_mm;
        pScreen.mmHeight = screen.width_mm;
    }
}

private Bool fbdevUnmapFramebuffer(KdScreenInfo* screen)
{
    KdShadowFbFree(screen);
    return True;
}

private Bool fbdevSetShadow(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    FbdevPriv* priv = screen.card.driver;
    ShadowUpdateProc update = void;
    ShadowWindowProc window = void;
    int useYX = 0;

version (__arm__) {
    /* Use variant copy routines that always read left to right in the
       shadow framebuffer.  Reading vertical strips is exceptionally
       slow on XScale due to cache effects.  */
    useYX = 1;
}

    window = fbdevWindowLinear;
    update = 0;
    switch (priv.fix.type) {
    case FB_TYPE_PACKED_PIXELS:
        if (scrpriv.randr)
            if (priv.var.bits_per_pixel == 16) {
                switch (scrpriv.randr) {
                case RR_Rotate_90:
                    if (useYX)
                        update = shadowUpdateRotate16_90YX;
                    else
                        update = shadowUpdateRotate16_90;
                    break;
                case RR_Rotate_180:
                    update = shadowUpdateRotate16_180;
                    break;
                case RR_Rotate_270:
                    if (useYX)
                        update = shadowUpdateRotate16_270YX;
                    else
                        update = shadowUpdateRotate16_270;
                    break;
                default:
                    update = shadowUpdateRotate16;
                    break;
                }
            }
            else
                update = shadowUpdateRotatePacked;
        else
            update = shadowUpdatePacked;
        break;

    case FB_TYPE_PLANES:
        window = fbdevWindowAfb;
        switch (priv.var.bits_per_pixel) {
        case 4:
            update = shadowUpdateAfb4;
            break;

        case 8:
            update = shadowUpdateAfb8;
            break;

        default:
            FatalError("Bitplanes with bpp %u are not yet supported\n",
                       priv.var.bits_per_pixel);
        }
        break;

    case FB_TYPE_INTERLEAVED_PLANES:
        if (priv.fix.type_aux == 2) {
            switch (priv.var.bits_per_pixel) {
            case 4:
                update = shadowUpdateIplan2p4;
                break;

            case 8:
                update = shadowUpdateIplan2p8;
                break;

            default:
                FatalError("Atari interleaved bitplanes with bpp %u are not yet supported\n",
                           priv.var.bits_per_pixel);
            }
        } else {
            FatalError("Interleaved bitplanes with interleave %u are not yet supported\n",
                       priv.fix.type_aux);
        }
        break;

    case FB_TYPE_TEXT:
        FatalError("Text frame buffers are not yet supported\n");
        break;

    case FB_TYPE_VGA_PLANES:
        FatalError("VGA planes are not yet supported\n");
        break;

    default:
        FatalError("Unsupported frame buffer type %u\n", priv.fix.type);
        break;
    }

    return KdShadowSet(pScreen, scrpriv.randr, update, window);
}

static if(RANDR){
private Bool fbdevRandRGetInfo(ScreenPtr pScreen, Rotation* rotations)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    RRScreenSizePtr pSize = void;
    Rotation randr = void;
    int n = void;

    *rotations = RR_Rotate_All | RR_Reflect_All;

    for (n = 0; n < pScreen.numDepths; n++)
        if (pScreen.allowedDepths[n].numVids)
            break;
    if (n == pScreen.numDepths)
        return False;

    pSize = RRRegisterSize(pScreen,
                           screen.width,
                           screen.height, screen.width_mm, screen.height_mm);

    randr = KdSubRotation(scrpriv.randr, screen.randr);

    RRSetCurrentConfig(pScreen, randr, 0, pSize);

    return True;
}

private Bool fbdevRandRSetConfig(ScreenPtr pScreen, Rotation randr, int rate, RRScreenSizePtr pSize)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    Bool wasEnabled = pScreenPriv.enabled;
    FbdevScrPriv oldscr = void;
    int oldwidth = void;
    int oldheight = void;
    int oldmmwidth = void;
    int oldmmheight = void;
    int newwidth = void, newheight = void, newmmwidth = void, newmmheight = void;

    if (screen.randr & (RR_Rotate_0 | RR_Rotate_180)) {
        newwidth = pSize.width;
        newheight = pSize.height;
        newmmwidth = pSize.mmWidth;
        newmmheight = pSize.mmHeight;
    }
    else {
        newwidth = pSize.height;
        newheight = pSize.width;
        newmmwidth = pSize.mmHeight;
        newmmheight = pSize.mmWidth;
    }

    if (wasEnabled)
        KdDisableScreen(pScreen);

    oldscr = *scrpriv;

    oldwidth = screen.width;
    oldheight = screen.height;
    oldmmwidth = pScreen.mmWidth;
    oldmmheight = pScreen.mmHeight;

    /*
     * Set new configuration
     */

    scrpriv.randr = KdAddRotation(screen.randr, randr);
    pScreen.width = newwidth;
    pScreen.height = newheight;
    pScreen.mmWidth = newmmwidth;
    pScreen.mmHeight = newmmheight;

    fbdevUnmapFramebuffer(screen);

    if (!fbdevMapFramebuffer(screen))
        goto bail4;

    KdShadowUnset(screen.pScreen);

    if (!fbdevSetShadow(screen.pScreen))
        goto bail4;

    fbdevSetScreenSizes(screen.pScreen);

    /*
     * Set frame buffer mapping
     */
    (*pScreen.ModifyPixmapHeader) (fbGetScreenPixmap(pScreen),
                                    pScreen.width,
                                    pScreen.height,
                                    screen.fb.depth,
                                    screen.fb.bitsPerPixel,
                                    screen.fb.byteStride,
                                    screen.fb.frameBuffer);

    /* set the subpixel order */

    KdSetSubpixelOrder(pScreen, scrpriv.randr);
    if (wasEnabled)
        KdEnableScreen(pScreen);

    return True;

 bail4:
    fbdevUnmapFramebuffer(screen);
    *scrpriv = oldscr;
    cast(void) fbdevMapFramebuffer(screen);
    pScreen.width = oldwidth;
    pScreen.height = oldheight;
    pScreen.mmWidth = oldmmwidth;
    pScreen.mmHeight = oldmmheight;

    if (wasEnabled)
        KdEnableScreen(pScreen);
    return False;
}

private Bool fbdevRandRInit(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;

    if (!RRScreenInit(pScreen))
        return False;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    pScrPriv.rrGetInfo = fbdevRandRGetInfo;
    pScrPriv.rrSetConfig = fbdevRandRSetConfig;
    return True;
}
}

private Bool fbdevCreateColormap(ColormapPtr pmap)
{
    ScreenPtr pScreen = pmap.pScreen;

    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;
    VisualPtr pVisual = void;
    int i = void;
    int nent = void;
    xColorItem* pdefs = void;

    switch (priv.fix.visual) {
    case FB_VISUAL_MONO01:
        pScreen.whitePixel = 0;
        pScreen.blackPixel = 1;
        pmap.red[0].co.local.red = 65535;
        pmap.red[0].co.local.green = 65535;
        pmap.red[0].co.local.blue = 65535;
        pmap.red[1].co.local.red = 0;
        pmap.red[1].co.local.green = 0;
        pmap.red[1].co.local.blue = 0;
        return True;
    case FB_VISUAL_MONO10:
        pScreen.blackPixel = 0;
        pScreen.whitePixel = 1;
        pmap.red[0].co.local.red = 0;
        pmap.red[0].co.local.green = 0;
        pmap.red[0].co.local.blue = 0;
        pmap.red[1].co.local.red = 65535;
        pmap.red[1].co.local.green = 65535;
        pmap.red[1].co.local.blue = 65535;
        return True;
    case FB_VISUAL_STATIC_PSEUDOCOLOR:
        pVisual = pmap.pVisual;
        nent = pVisual.ColormapEntries;
        pdefs = cast(xColorItem*) calloc(nent, xColorItem.sizeof);
        if (!pdefs)
            return False;
        for (i = 0; i < nent; i++)
            pdefs[i].pixel = i;
        fbdevGetColors(pScreen, nent, pdefs);
        for (i = 0; i < nent; i++) {
            pmap.red[i].co.local.red = pdefs[i].red;
            pmap.red[i].co.local.green = pdefs[i].green;
            pmap.red[i].co.local.blue = pdefs[i].blue;
        }
        free(pdefs);
        return True;
    default:
        return fbInitializeColormap(pmap);
    }
}

Bool fbdevInitScreen(ScreenPtr pScreen)
{
    pScreen.CreateColormap = fbdevCreateColormap;
    return True;
}

Bool fbdevFinishInitScreen(ScreenPtr pScreen)
{
    if (!shadowSetup(pScreen))
        return False;

static if(RANDR){
    if (!fbdevRandRInit(pScreen))
        return False;
}

    return True;
}

Bool fbdevCreateResources(ScreenPtr pScreen)
{
    return fbdevSetShadow(pScreen);
}

void fbdevPreserve(KdCardInfo* card)
{
}

private int fbdevUpdateFbColormap(FbdevPriv* priv, int minidx, int maxidx)
{
    fb_cmap cmap = void;

    cmap.start = minidx;
    cmap.len = maxidx - minidx + 1;
    cmap.red = &priv.red[minidx];
    cmap.green = &priv.green[minidx];
    cmap.blue = &priv.blue[minidx];
    cmap.transp = 0;

    return ioctl(priv.fd, FBIOPUTCMAP, &cmap);
}

Bool fbdevEnable(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;

    int k = void;

    priv.var.activate = FB_ACTIVATE_NOW | FB_CHANGE_CMAP_VBL;

    /* display it on the LCD */
    k = ioctl(priv.fd, FBIOPUT_VSCREENINFO, &priv.var);
    if (k < 0) {
        perror("FBIOPUT_VSCREENINFO");
        return False;
    }

    if (priv.fix.visual == FB_VISUAL_DIRECTCOLOR) {
        int i = void;

        for (i = 0;
             i < (1 << priv.var.red.length) ||
             i < (1 << priv.var.green.length) ||
             i < (1 << priv.var.blue.length); i++) {
            priv.red[i] = i * 65535 / ((1 << priv.var.red.length) - 1);
            priv.green[i] = i * 65535 / ((1 << priv.var.green.length) - 1);
            priv.blue[i] = i * 65535 / ((1 << priv.var.blue.length) - 1);
        }

        fbdevUpdateFbColormap(priv, 0, i);
    }
    return True;
}

Bool fbdevDPMS(ScreenPtr pScreen, int mode)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;
    static int oldmode = -1;

    if (mode == oldmode)
        return True;
version (FBIOPUT_POWERMODE) {
    if (ioctl(priv.fd, FBIOPUT_POWERMODE, &mode) >= 0) {
        oldmode = mode;
        return True;
    }
}
version (FBIOBLANK) {
    if (ioctl(priv.fd, FBIOBLANK, mode ? mode + 1 : 0) >= 0) {
        oldmode = mode;
        return True;
    }
}
    return False;
}

void fbdevDisable(ScreenPtr pScreen)
{
}

void fbdevRestore(KdCardInfo* card)
{
}

void fbdevScreenFini(KdScreenInfo* screen)
{
}

void fbdevCardFini(KdCardInfo* card)
{
    FbdevPriv* priv = card.driver;

    munmap(priv.fb_base, priv.fix.smem_len);
    close(priv.fd);
    free(priv);
    card.driver = null;

    free(card.closure);
    card.closure = null;
}

/*
 * Retrieve actual colormap and return selected n entries in pdefs.
 */
void fbdevGetColors(ScreenPtr pScreen, int n, xColorItem* pdefs)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;
    fb_cmap cmap = void;
    int p = void;
    int k = void;
    int min = void, max = void;

    min = 256;
    max = 0;
    for (k = 0; k < n; k++) {
        if (pdefs[k].pixel < min)
            min = pdefs[k].pixel;
        if (pdefs[k].pixel > max)
            max = pdefs[k].pixel;
    }
    cmap.start = min;
    cmap.len = max - min + 1;
    cmap.red = &priv.red[min];
    cmap.green = &priv.green[min];
    cmap.blue = &priv.blue[min];
    cmap.transp = 0;
    k = ioctl(priv.fd, FBIOGETCMAP, &cmap);
    if (k < 0) {
        perror("can't get colormap");
        return;
    }
    while (n--) {
        p = pdefs.pixel;
        pdefs.red = priv.red[p];
        pdefs.green = priv.green[p];
        pdefs.blue = priv.blue[p];
        pdefs++;
    }
}

/*
 * Change colormap by updating n entries described in pdefs.
 */
void fbdevPutColors(ScreenPtr pScreen, int n, xColorItem* pdefs)
{
    mixin(KdScreenPriv!("pScreen"));
    FbdevPriv* priv = pScreenPriv.card.driver;
    int p = void;
    int min = void, max = void;

    min = 256;
    max = 0;
    while (n--) {
        p = pdefs.pixel;
        priv.red[p] = pdefs.red;
        priv.green[p] = pdefs.green;
        priv.blue[p] = pdefs.blue;
        if (p < min)
            min = p;
        if (p > max)
            max = p;
        pdefs++;
    }

    fbdevUpdateFbColormap(priv, min, max);
}
