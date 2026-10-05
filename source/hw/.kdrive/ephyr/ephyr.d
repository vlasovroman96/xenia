module hw.kdrive.ephyr.ephyr;
@nogc nothrow:
extern(C): __gshared:
/*
 * Xephyr - A kdrive X server that runs in a host X window.
 *          Authored by Matthew Allum <mallum@openedhand.com>
 *
 * Copyright © 2004 Nokia
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Nokia not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission. Nokia makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * NOKIA DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL NOKIA BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;

import externs.xcb.xcb_keysyms;
//import x11.keysym;

import fb.fb_priv;
import mi.mipointer_priv;
import os.client_priv;
import os.osdep;
import os.serverlock;

import hw.kdrive.ephyr.ephyr;
import include.inputstr;
import include.scrnintstr;
// import ephyrlog;

// static if (GLAMOR) {
// import include.glamor;
// }
import hw.kdrive.ephyr.ephyr_glamor;
import hw.kdrive.src.kdrive;
import include.glx_extinit;
import include.xkbsrv;
import include.shadow;
import include.exa_i;
import externs.xcb.xcb_image;
import hw.kdrive.ephyr.ephyr_glamor;
import hw.kdrive.ephyr.hostx;
import hw.kdrive.ephyr.ephyrinit;
import hw.kdrive.src.kinput;
import dix.dixutils;
import hw.kdrive.src.kshadow;
import os.WaitFor;
import miext.shadow.shadow;
import dix.events;
import mi.mipointer;
import os.log;
import hw.kdrive.src.kinput;
import os.connection;

struct EphyrPriv {
    CARD8 *base;
    int bytes_per_line;
} ;

Bool ephyr_glamor;

KdKeyboardInfo* ephyrKbd;
KdPointerInfo* ephyrMouse;
Bool ephyrNoDRI = FALSE;
Bool ephyrNoXV = FALSE;

private int mouseState = 0;
private Rotation ephyrRandr = RR_Rotate_0;

struct _ephyrFakexaPriv {
    ExaDriverPtr exa;
    Bool is_synced;

    /* The following are arguments and other information from Prepare* calls
     * which are stored for use in the inner calls.
     */
    int op;
    PicturePtr pSrcPicture, pMaskPicture, pDstPicture;
    void *[3]saved_ptrs;
    PixmapPtr pDst, pSrc, pMask;
    GCPtr pGC;
} 

alias EphyrFakexaPriv = _ephyrFakexaPriv;

struct _ephyrScrPriv {
    /* ephyr server info */
    Rotation randr;
    Bool shadow;
    DamagePtr pDamage;
    EphyrFakexaPriv *fakexa;

    /* Host X window info */
    xcb_window_t win;
    xcb_window_t win_pre_existing;    /* Set via -parent option like xnest */
    xcb_window_t peer_win;            /* Used for GL; should be at most one */
    xcb_visualid_t vid;
    xcb_image_t *ximg;
    Bool win_explicit_position;
    int win_x, win_y;
    int win_width, win_height;
    int server_depth;
    const char *output;         /* Set via -output option */
    ubyte *fb_data;     /* only used when host bpp != server bpp */
    xcb_shm_segment_info_t shminfo;
    size_t shmsize;

    KdScreenInfo *screen;
    int mynum;                  /* Screen number */
    ulong[256] cmap;

    ScreenBlockHandlerProcPtr   BlockHandler;

    hw.kdrive.ephyr.ephyr_glamor.ephyr_glamor *glamor;
} 

alias EphyrScrPriv = _ephyrScrPriv;

struct _EphyrInputPrivate {
    Bool enabled;
}alias EphyrKbdPrivate = _EphyrInputPrivate;
alias EphyrPointerPrivate = _EphyrInputPrivate;

Bool EphyrWantGrayScale = 0;
Bool EphyrWantResize = 0;

private xcb_mod_mask_t EphyrKeybindToggleHostGrabModMask;
private uint EphyrKeybindToggleHostGrabKey;
private const(char)* EphyrTitleHostGrabKeyComboHint;
private ubyte EphyrTitleHostGrabKeyComboHintLen;
private Bool EphyrHostGrabSet = FALSE;

Bool ephyrInitialize(KdCardInfo* card, EphyrPriv* priv)
{
version (Windows) {} else {
    OsSignal(SIGUSR1, &hostx_handle_signal);
}

    priv.base = null;
    priv.bytes_per_line = 0;
    return TRUE;
}

Bool ephyrCardInit(KdCardInfo* card)
{
    EphyrPriv* priv = cast(EphyrPriv*) cast(EphyrPriv*) calloc(1, EphyrPriv.sizeof);
    if (!priv)
        return FALSE;

    if (!ephyrInitialize(card, priv)) {
        free(priv);
        return FALSE;
    }
    card.driver = priv;

    return TRUE;
}

Bool ephyrScreenInitialize(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    int x = 0, y = 0;
    int width = 640, height = 480;
    CARD32 redMask = void, greenMask = void, blueMask = void;

    if (hostx_want_screen_geometry(screen, &width, &height, &x, &y)
        || !screen.width || !screen.height) {
        screen.width = width;
        screen.height = height;
        screen.x = x;
        screen.y = y;
    }

    if (EphyrWantGrayScale)
        screen.fb.depth = 8;

    if (screen.fb.depth && screen.fb.depth != hostx_get_depth()) {
        if (screen.fb.depth < hostx_get_depth()
            && (screen.fb.depth == 24 || screen.fb.depth == 16
                || screen.fb.depth == 8)) {
            scrpriv.server_depth = screen.fb.depth;
        }
        else
            ErrorF
                ("\nXephyr: requested screen depth not supported, setting to match hosts.\n");
    }

    screen.fb.depth = hostx_get_server_depth(screen);
    screen.rate = 72;

    if (screen.fb.depth <= 8) {
        if (EphyrWantGrayScale)
            screen.fb.visuals = ((1 << StaticGray) | (1 << GrayScale));
        else
            screen.fb.visuals = ((1 << StaticGray) |
                                  (1 << GrayScale) |
                                  (1 << StaticColor) |
                                  (1 << PseudoColor) |
                                  (1 << TrueColor) | (1 << DirectColor));

        screen.fb.redMask = 0x00;
        screen.fb.greenMask = 0x00;
        screen.fb.blueMask = 0x00;
        screen.fb.depth = 8;
        screen.fb.bitsPerPixel = 8;
    }
    else {
        screen.fb.visuals = (1 << TrueColor);

        if (screen.fb.depth <= 15) {
            screen.fb.depth = 15;
            screen.fb.bitsPerPixel = 16;
        }
        else if (screen.fb.depth <= 16) {
            screen.fb.depth = 16;
            screen.fb.bitsPerPixel = 16;
        }
        else if (screen.fb.depth <= 24) {
            screen.fb.depth = 24;
            screen.fb.bitsPerPixel = 32;
        }
        else if (screen.fb.depth <= 30) {
            screen.fb.depth = 30;
            screen.fb.bitsPerPixel = 32;
        }
        else {
            ErrorF("\nXephyr: Unsupported screen depth %d\n", screen.fb.depth);
            return FALSE;
        }

        hostx_get_visual_masks(screen, &redMask, &greenMask, &blueMask);

        screen.fb.redMask = cast(Pixel) redMask;
        screen.fb.greenMask = cast(Pixel) greenMask;
        screen.fb.blueMask = cast(Pixel) blueMask;

    }

    scrpriv.randr = screen.randr;

    return ephyrMapFramebuffer(screen);
}

void* ephyrWindowLinear(ScreenPtr pScreen, CARD32 row, CARD32 offset, int mode, CARD32* size, void* closure)
{
    mixin(KdScreenPriv!("pScreen"));
    EphyrPriv* priv = cast(EphyrPriv*)pScreenPriv.card.driver;

    if (!pScreenPriv.enabled)
        return null;

    *size = priv.bytes_per_line;
    return priv.base + row * priv.bytes_per_line + offset;
}

/**
 * Figure out display buffer size. If fakexa is enabled, allocate a larger
 * buffer so that fakexa has space to put offscreen pixmaps.
 */
int ephyrBufferHeight(KdScreenInfo* screen)
{
    int buffer_height = void;

    if (ephyrFuncs.initAccel is null)
        buffer_height = screen.height;
    else
        buffer_height = 3 * screen.height;
    return buffer_height;
}

Bool ephyrMapFramebuffer(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    EphyrPriv* priv = cast(EphyrPriv*)screen.card.driver;
    KdPointerMatrix m = void;
    int buffer_height = void;

    // EPHYR_LOG("screen->width: %d, screen->height: %d index=%d",
    //           screen.width, screen.height, screen.mynum);

    /*
     * Use the rotation last applied to ourselves (in the Xephyr case the fb
     * coordinate system moves independently of the pointer coordinate system).
     */
    KdComputePointerMatrix(&m, ephyrRandr, screen.width, screen.height);
    KdSetPointerMatrix(&m);

    buffer_height = ephyrBufferHeight(screen);

    priv.base =
        cast(ubyte*)hostx_screen_init(screen, screen.x, screen.y,
                          screen.width, screen.height, buffer_height,
                          &priv.bytes_per_line, &screen.fb.bitsPerPixel);

    if ((scrpriv.randr & RR_Rotate_0) && !(scrpriv.randr & RR_Reflect_All)) {
        scrpriv.shadow = FALSE;

        screen.fb.byteStride = priv.bytes_per_line;
        screen.fb.pixelStride = screen.width;
        screen.fb.frameBuffer = cast(CARD8*) (priv.base);
    }
    else {
        /* Rotated/Reflected so we need to use shadow fb */
        scrpriv.shadow = TRUE;

        // EPHYR_LOG("allocating shadow");

        KdShadowFbAlloc(screen,
                        scrpriv.randr & (RR_Rotate_90 | RR_Rotate_270));
    }

    return TRUE;
}

void ephyrSetScreenSizes(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv.randr & (RR_Rotate_0 | RR_Rotate_180)) {
        pScreen.width = cast(short)screen.width;
        pScreen.height = cast(short)screen.height;
        pScreen.mmWidth = cast(short)screen.width_mm;
        pScreen.mmHeight = cast(short)screen.height_mm;
    }
    else {
        pScreen.width = cast(short)screen.height;
        pScreen.height = cast(short)screen.width;
        pScreen.mmWidth = cast(short)screen.height_mm;
        pScreen.mmHeight = cast(short)screen.width_mm;
    }
}

Bool ephyrUnmapFramebuffer(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv.shadow)
        KdShadowFbFree(screen);

    /* Note, priv->base will get freed when XImage recreated */

    return TRUE;
}

void ephyrShadowUpdate(ScreenPtr pScreen, shadowBufPtr pBuf)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;

    // EPHYR_LOG("slow paint");

    /* FIXME: Slow Rotated/Reflected updates could be much
     * much faster efficiently updating via transforming
     * pBuf->pDamage  regions
     */
    shadowUpdateRotatePacked(pScreen, pBuf);
    hostx_paint_rect(screen, 0, 0, 0, 0, screen.width, screen.height, TRUE);
}

private void ephyrInternalDamageRedisplay(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    RegionPtr pRegion = void;

    if (!scrpriv || !scrpriv.pDamage)
        return;

    pRegion = DamageRegion(scrpriv.pDamage);

    if (RegionNotEmpty(pRegion)) {
        int nbox = void;
        BoxPtr pbox = void;

        if (ephyr_glamor) {
            ephyr_glamor_damage_redisplay(scrpriv.glamor, pRegion);
        } else {
            nbox = RegionNumRects(pRegion);
            pbox = RegionRects(pRegion);

            while (nbox--) {
                hostx_paint_rect(screen,
                                 pbox.x1, pbox.y1,
                                 pbox.x1, pbox.y1,
                                 pbox.x2 - pbox.x1, pbox.y2 - pbox.y1,
                                 nbox == 0);
                pbox++;
            }
        }
        DamageEmpty(scrpriv.pDamage);
    }
}



private Bool ephyrEventWorkProc(ClientPtr client, void* closure)
{
    ephyrXcbProcessEvents(TRUE);
    return TRUE;
}

private void ephyrScreenBlockHandler(ScreenPtr pScreen, void* timeout)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    pScreen.BlockHandler = scrpriv.BlockHandler;
    (*pScreen.BlockHandler)(pScreen, timeout);
    scrpriv.BlockHandler = pScreen.BlockHandler;
    pScreen.BlockHandler = &ephyrScreenBlockHandler;

    if (scrpriv.pDamage)
        ephyrInternalDamageRedisplay(pScreen);

    if (hostx_has_queued_event()) {
        if (!QueueWorkProc(&ephyrEventWorkProc, null, null))
            FatalError("cannot queue event processing in ephyr block handler");
        AdjustWaitForDelay(timeout, 0);
    }
}

Bool ephyrSetInternalDamage(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    PixmapPtr pPixmap = null;

    scrpriv.pDamage = DamageCreate(cast(DamageReportFunc) 0,
                                    cast(DamageDestroyFunc) 0,
                                    DamageReportNone, TRUE, pScreen, pScreen);

    pPixmap = (*pScreen.GetScreenPixmap) (pScreen);

    DamageRegister(&pPixmap.drawable, scrpriv.pDamage);

    return TRUE;
}

void ephyrUnsetInternalDamage(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    DamageDestroy(scrpriv.pDamage);
    scrpriv.pDamage = null;
}

static if(RANDR){
Bool ephyrRandRGetInfo(ScreenPtr pScreen, Rotation* rotations)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    RRScreenSizePtr pSize = void;
    Rotation randr = void;
    int n = 0;

    struct _Sizes {
        int width = void, height = void;
    }_Sizes[16] sizes = [
        {1600, 1200},
        {1400, 1050},
        {1280, 960},
        {1280, 1024},
        {1152, 864},
        {1024, 768},
        {832, 624},
        {800, 600},
        {720, 400},
        {480, 640},
        {640, 480},
        {640, 400},
        {320, 240},
        {240, 320},
        {160, 160},
        {0, 0}
    ];

    EPHYR_LOG("mark");

    *rotations = RR_Rotate_All | RR_Reflect_All;

    if (!hostx_want_preexisting_window(screen)
        && !hostx_want_fullscreen()) {  /* only if no -parent switch */
        while (sizes[n].width != 0 && sizes[n].height != 0) {
            RRRegisterSize(pScreen,
                           sizes[n].width,
                           sizes[n].height,
                           (sizes[n].width * screen.width_mm) / screen.width,
                           (sizes[n].height * screen.height_mm) /
                           screen.height);
            n++;
        }
    }

    pSize = RRRegisterSize(pScreen,
                           screen.width,
                           screen.height, screen.width_mm, screen.height_mm);

    randr = KdSubRotation(scrpriv.randr, screen.randr);

    RRSetCurrentConfig(pScreen, randr, 0, pSize);

    return TRUE;
}

Bool ephyrRandRSetConfig(ScreenPtr pScreen, Rotation randr, int rate, RRScreenSizePtr pSize)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    Bool wasEnabled = pScreenPriv.enabled;
    EphyrScrPriv oldscr = void;
    int oldwidth = void, oldheight = void, oldmmwidth = void, oldmmheight = void;
    Bool oldshadow = void;
    int newwidth = void, newheight = void;

    if (screen.randr & (RR_Rotate_0 | RR_Rotate_180)) {
        newwidth = pSize.width;
        newheight = pSize.height;
    }
    else {
        newwidth = pSize.height;
        newheight = pSize.width;
    }

    if (wasEnabled)
        KdDisableScreen(pScreen);

    oldscr = *scrpriv;

    oldwidth = screen.width;
    oldheight = screen.height;
    oldmmwidth = pScreen.mmWidth;
    oldmmheight = pScreen.mmHeight;
    oldshadow = scrpriv.shadow;

    /*
     * Set new configuration
     */

    /*
     * We need to store the rotation value for pointer coords transformation;
     * though initially the pointer and fb rotation are identical, when we map
     * the fb, the screen will be reinitialized and return into an unrotated
     * state (presumably the HW is taking care of the rotation of the fb), but the
     * pointer still needs to be transformed.
     */
    ephyrRandr = KdAddRotation(screen.randr, randr);
    scrpriv.randr = ephyrRandr;

    ephyrUnmapFramebuffer(screen);

    screen.width = newwidth;
    screen.height = newheight;

    scrpriv.win_width = screen.width;
    scrpriv.win_height = screen.height;
static if (GLAMOR) {
    ephyr_glamor_set_window_size(scrpriv.glamor,
                                 scrpriv.win_width,
                                 scrpriv.win_height);
}

    if (!ephyrMapFramebuffer(screen))
        goto bail4;

    /* FIXME below should go in own call */

    if (oldshadow)
        KdShadowUnset(screen.pScreen);
    else
        ephyrUnsetInternalDamage(screen.pScreen);

    ephyrSetScreenSizes(screen.pScreen);

    if (scrpriv.shadow) {
        if (!KdShadowSet(screen.pScreen,
                         scrpriv.randr, &ephyrShadowUpdate, &ephyrWindowLinear))
            goto bail4;
    }
    else {
static if (GLAMOR) {
        if (ephyr_glamor)
            ephyr_glamor_create_screen_resources(pScreen);
}
        /* Without shadow fb ( non rotated ) we need
         * to use damage to efficiently update display
         * via signal regions what to copy from 'fb'.
         */
        if (!ephyrSetInternalDamage(screen.pScreen))
            goto bail4;
    }

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

    RRGetInfo(pScreen, TRUE);
    RRScreenSizeNotify(pScreen);

    return TRUE;

 bail4:
    EPHYR_LOG("bailed");

    ephyrUnmapFramebuffer(screen);
    *scrpriv = oldscr;
    cast(void) ephyrMapFramebuffer(screen);

    pScreen.width = oldwidth;
    pScreen.height = oldheight;
    pScreen.mmWidth = oldmmwidth;
    pScreen.mmHeight = oldmmheight;

    if (wasEnabled)
        KdEnableScreen(pScreen);
    return FALSE;
}

Bool ephyrRandRInit(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;

    if (!RRScreenInit(pScreen))
        return FALSE;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    pScrPriv.rrGetInfo = ephyrRandRGetInfo;
    pScrPriv.rrSetConfig = ephyrRandRSetConfig;
    return TRUE;
}

private Bool ephyrResizeScreen(ScreenPtr pScreen, int newwidth, int newheight)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    RRScreenSize size = {0};
    Bool ret = void;
    int t = void;

    if (screen.randr & (RR_Rotate_90|RR_Rotate_270)) {
        t = newwidth;
        newwidth = newheight;
        newheight = t;
    }

    if (newwidth == screen.width && newheight == screen.height) {
        return FALSE;
    }

    size.width = newwidth;
    size.height = newheight;

    hostx_size_set_from_configure(TRUE);
    ret = ephyrRandRSetConfig (pScreen, screen.randr, 0, &size);
    hostx_size_set_from_configure(FALSE);
    if (ret) {
        RROutputPtr output = void;

        output = RRFirstOutput(pScreen);
        if (!output)
            return FALSE;
        RROutputSetModes(output, null, 0, 0);
    }

    return ret;
}
}

Bool ephyrCreateColormap(ColormapPtr pmap)
{
    return fbInitializeColormap(pmap);
}

Bool ephyrSetGrabShortcut(const(char*) desc)
{
    if (desc is null || !strcmp(desc, "NULL")) {
        EphyrKeybindToggleHostGrabModMask = cast(xcb_mod_mask_t)0;
        EphyrKeybindToggleHostGrabKey = 0;
        EphyrTitleHostGrabKeyComboHint = null;
        EphyrTitleHostGrabKeyComboHintLen = 0;
    }
    else {
        const(ubyte) fixed_bound = 255;
        cast(void)fixed_bound;
        char[16] buf = void;
        ubyte j = 0;
        for (ubyte i = 0;; ++i) {
            assert(i < fixed_bound);
            const(char) c = desc[i];
            if (c == 0 || (j != 0 && c == '+')) {
                buf[j] = 0;
                if (j == 1) {
                    EphyrKeybindToggleHostGrabKey = buf[0];
                }
                else if (!strcmp(buf.ptr, "ctrl")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_CONTROL;
                }
                else if (!strcmp(buf.ptr, "shift")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_SHIFT;
                }
                else if (!strcmp(buf.ptr, "lock")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_LOCK;
                }
                else if (!strcmp(buf.ptr, "mod1")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_1;
                }
                else if (!strcmp(buf.ptr, "mod2")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_2;
                }
                else if (!strcmp(buf.ptr, "mod3")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_3;
                }
                else if (!strcmp(buf.ptr, "mod4")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_4;
                }
                else if (!strcmp(buf.ptr, "mod5")) {
                    EphyrKeybindToggleHostGrabModMask |= XCB_MOD_MASK_5;
                }
                else {
                    ErrorF("ephyr: -host-grab: "
                        ~ "Unrecognized key: '%s'\n", buf.ptr);
                    return FALSE;
                }
                if (c == 0) break;
                j = 0;
            }
            else {
                buf[j] = c;
                ++j;
                assert(j < buf.sizeof);
            }
        }

        EphyrTitleHostGrabKeyComboHint = desc;
        EphyrTitleHostGrabKeyComboHintLen = cast(ubyte)strlen(desc);
    }

    EphyrHostGrabSet = TRUE;
    return TRUE;
}

private void ephyrPrintGrabShortcut(char* out_, const(size_t) out_size, const(Bool) currently_grabbed)
{
    if (
        (
            EphyrKeybindToggleHostGrabModMask == 0 &&
            EphyrKeybindToggleHostGrabKey == 0
        ) || (
            EphyrTitleHostGrabKeyComboHint is null ||
            EphyrTitleHostGrabKeyComboHintLen == 0
        )
    ) {
        /* grabbing disabled */
        out_[0] = '\0';
        return;
    }

    const(char*) suffix = currently_grabbed
        ? " releases mouse and keyboard)"
        : " grabs mouse and keyboard)";
    const(size_t) suffix_len = strlen(suffix);

    assert(out_size > 1 + EphyrTitleHostGrabKeyComboHintLen + suffix_len + 1);
    assert(out_ !is null);

    out_[0] = '(';
    memcpy(out_ + 1, EphyrTitleHostGrabKeyComboHint, EphyrTitleHostGrabKeyComboHintLen);

    memcpy(out_ + EphyrTitleHostGrabKeyComboHintLen + 1, suffix, suffix_len + 1);
}

private void ephyrUpdateWindowTitle(KdScreenInfo* screen, const(Bool) currently_grabbed)
{
    char[128] title_buf = void;
    ephyrPrintGrabShortcut(title_buf.ptr, title_buf.sizeof, currently_grabbed);
    hostx_set_win_title(screen, title_buf.ptr);
}

Bool ephyrInitScreen(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;

    // EPHYR_LOG("pScreen->myNum:%d\n", pScreen.myNum);
    hostx_set_screen_number(screen, pScreen.myNum);
    if (!EphyrHostGrabSet) {
        ephyrSetGrabShortcut("ctrl+shift");
    }
    ephyrUpdateWindowTitle(screen, FALSE);
    pScreen.CreateColormap = &ephyrCreateColormap;

version (XV) {
    if (!ephyrNoXV) {
        if (!ephyr_glamor && !ephyrInitVideo(pScreen)) {
            EPHYR_LOG_ERROR("failed to initialize xvideo\n");
        }
        else {
            EPHYR_LOG("initialized xvideo okay\n");
        }
    }
} /*XV*/

    return TRUE;
}


Bool ephyrFinishInitScreen(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    /* FIXME: Calling this even if not using shadow.
     * Seems harmless enough. But may be safer elsewhere.
     */
    if (!shadowSetup(pScreen))
        return FALSE;

static if(RANDR){
    if (!ephyrRandRInit(pScreen))
        return FALSE;
}

    scrpriv.BlockHandler = pScreen.BlockHandler;
    pScreen.BlockHandler = &ephyrScreenBlockHandler;

    return TRUE;
}

/**
 * Called by kdrive after calling down the
 * pScreen->CreateScreenResources() chain, this gives us a chance to
 * make any pixmaps after the screen and all extensions have been
 * initialized.
 */
Bool ephyrCreateResources(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    // EPHYR_LOG("mark pScreen=%p mynum=%d shadow=%d",
            //   pScreen, pScreen.myNum, scrpriv.shadow);

    if (scrpriv.shadow)
        return KdShadowSet(pScreen,
                           scrpriv.randr,
                           &ephyrShadowUpdate, &ephyrWindowLinear);
    else {
static if (GLAMOR) {
        if (ephyr_glamor) {
            if (!ephyr_glamor_create_screen_resources(pScreen))
                return FALSE;
        }
}
        return ephyrSetInternalDamage(pScreen);
    }
}

void ephyrScreenFini(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv.shadow) {
        KdShadowFbFree(screen);
    }
    scrpriv.BlockHandler = null;
}

void ephyrCloseScreen(ScreenPtr pScreen)
{
    ephyrUnsetInternalDamage(pScreen);
}

/*
 * Port of Mark McLoughlin's Xnest fix for focus in + modifier bug.
 * See https://bugs.freedesktop.org/show_bug.cgi?id=3030
 */
void ephyrUpdateModifierState(uint state)
{

    DeviceIntPtr pDev = inputInfo.keyboard;
    KeyClassPtr keyc = pDev.key;
    int i = void;
    CARD8 mask = void;
    int xkb_state = void;

    if (!pDev)
        return;

    xkb_state = XkbStateFieldFromRec(&pDev.key.xkbInfo.state);
    state = state & 0xff;

    if (xkb_state == state)
        return;

    for (i = 0, mask = 1; i < 8; i++, mask <<= 1) {
        int key = void;

        /* Modifier is down, but shouldn't be */
        if ((xkb_state & mask) && !(state & mask)) {
            int count = keyc.modifierKeyCount[i];

            for (key = 0; key < MAP_LENGTH; key++)
                if (keyc.xkbInfo.desc.map.modmap[key] & mask) {
                    if (mask == XCB_MOD_MASK_LOCK) {
                        KdEnqueueKeyboardEvent(ephyrKbd, cast(ubyte)key, FALSE);
                        KdEnqueueKeyboardEvent(ephyrKbd, cast(ubyte)key, TRUE);
                    }
                    else if (key_is_down(pDev, key, KEY_PROCESSED))
                        KdEnqueueKeyboardEvent(ephyrKbd, cast(ubyte)key, TRUE);

                    if (--count == 0)
                        break;
                }
        }

        /* Modifier should be down, but isn't */
        if (!(xkb_state & mask) && (state & mask))
            for (key = 0; key < MAP_LENGTH; key++)
                if (keyc.xkbInfo.desc.map.modmap[key] & mask) {
                    KdEnqueueKeyboardEvent(ephyrKbd, cast(ubyte)key, FALSE);
                    if (mask == XCB_MOD_MASK_LOCK)
                        KdEnqueueKeyboardEvent(ephyrKbd, cast(ubyte)key, TRUE);
                    break;
                }
    }
}

private Bool ephyrCursorOffScreen(ScreenPtr* ppScreen, int* x, int* y)
{
    return FALSE;
}

private void ephyrCrossScreen(ScreenPtr pScreen, Bool entering)
{
}

ScreenPtr ephyrCursorScreen = null; /* screen containing the cursor */

private void ephyrWarpCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    input_lock();
    ephyrCursorScreen = pScreen;
    miPointerWarpCursor(inputInfo.pointer, pScreen, x, y);

    input_unlock();
}

miPointerScreenFuncRec ephyrPointerScreenFuncs = {
    &ephyrCursorOffScreen,
    &ephyrCrossScreen,
    &ephyrWarpCursor,
};

private KdScreenInfo* screen_from_window(Window w)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        KdPrivScreenPtr kdscrpriv = mixin(KdGetScreenPriv!("walkScreen"));
        KdScreenInfo* screen = kdscrpriv.screen;
        EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

        if (scrpriv.win == w
            || scrpriv.peer_win == w
            || scrpriv.win_pre_existing == w) {
            return screen;
        }
    });

    return null;
}

//  _X_NORETURN;

private void ephyrProcessErrorEvent(xcb_generic_event_t* xev)
{
    xcb_generic_error_t* e = cast(xcb_generic_error_t*)xev;

    FatalError("X11 error\n"
               ~ "Error code: %hu\n"
               ~ "Sequence number: %hu\n"
               ~ "Major code: %hu\tMinor code: %hu\n"
               ~ "Error value: %u\n",
               e.error_code,
               e.sequence,
               e.major_code, e.minor_code,
               e.resource_id);
}

private void ephyrProcessExpose(xcb_generic_event_t* xev)
{
    xcb_expose_event_t* expose = cast(xcb_expose_event_t*)xev;
    KdScreenInfo* screen = screen_from_window(expose.window);
    if (!screen)
        return;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    /* Wait for the last expose event in a series of cliprects
     * to actually paint our screen.
     */
    if (expose.count != 0)
        return;

    if (scrpriv) {
        hostx_paint_rect(scrpriv.screen, 0, 0, 0, 0,
                         scrpriv.win_width,
                         scrpriv.win_height,
                         TRUE);
    } else {
        assert(0);
        // EPHYR_LOG_ERROR("failed to get host screen\n");
    }
}

private void ephyrProcessMouseMotion(xcb_generic_event_t* xev)
{
    xcb_motion_notify_event_t* motion = cast(xcb_motion_notify_event_t*)xev;
    KdScreenInfo* screen = screen_from_window(motion.event);

    if (!screen)
        return;

    if (!ephyrMouse ||
        !(cast(EphyrPointerPrivate*) ephyrMouse.driverPrivate).enabled) {
        // EPHYR_LOG("skipping mouse motion:%d\n", screen.pScreen.myNum);
        return;
    }

    if (ephyrCursorScreen != screen.pScreen) {
        // EPHYR_LOG("warping mouse cursor. "
        //           ~ "cur_screen:%d, motion_screen:%d\n",
        //           ephyrCursorScreen ? ephyrCursorScreen.myNum : -1, screen.pScreen.myNum);
        ephyrWarpCursor(inputInfo.pointer, screen.pScreen,
                        motion.event_x, motion.event_y);
    }
    else {
        int x = 0, y = 0;

        // EPHYR_LOG("enqueuing mouse motion:%d\n", screen.pScreen.myNum);
        x = motion.event_x;
        y = motion.event_y;
        // EPHYR_LOG("initial (x,y):(%d,%d)\n", x, y);

        /* convert coords into desktop-wide coordinates.
         * fill_pointer_events will convert that back to
         * per-screen coordinates where needed */
        x += screen.pScreen.x;
        y += screen.pScreen.y;

        KdEnqueuePointerEvent(ephyrMouse, mouseState | KD_POINTER_DESKTOP, x, y, 0);
    }
}

private void ephyrProcessButtonPress(xcb_generic_event_t* xev)
{
    xcb_button_press_event_t* button = cast(xcb_button_press_event_t*)xev;

    if (!ephyrMouse ||
        !(cast(EphyrPointerPrivate*) ephyrMouse.driverPrivate).enabled) {
        // EPHYR_LOG("skipping mouse press:%d\n", screen_from_window(button.event).pScreen.myNum);
        return;
    }

    ephyrUpdateModifierState(button.state);
    /* This is a bit hacky. will break for button 5 ( defined as 0x10 )
     * Check KD_BUTTON defines in kdrive.h
     */
    mouseState |= 1 << (button.detail - 1);

    // EPHYR_LOG("enqueuing mouse press:%d\n", screen_from_window(button.event).pScreen.myNum);
    KdEnqueuePointerEvent(ephyrMouse, mouseState | KD_MOUSE_DELTA, 0, 0, 0);
}

private void ephyrProcessButtonRelease(xcb_generic_event_t* xev)
{
    xcb_button_press_event_t* button = cast(xcb_button_press_event_t*)xev;

    if (!ephyrMouse ||
        !(cast(EphyrPointerPrivate*) ephyrMouse.driverPrivate).enabled) {
        return;
    }

    ephyrUpdateModifierState(button.state);
    mouseState &= ~(1 << (button.detail - 1));

    // EPHYR_LOG("enqueuing mouse release:%d\n", screen_from_window(button.event).pScreen.myNum);
    KdEnqueuePointerEvent(ephyrMouse, mouseState | KD_MOUSE_DELTA, 0, 0, 0);
}

/* Xephyr wants ctrl+shift to grab the window, but that conflicts with
   ctrl+alt+shift key combos. Remember the modifier state on key presses and
   releases, if mod1 is pressed, we need ctrl, shift and mod1 released
   before we allow a shift-ctrl grab activation.

   note: a key event contains the mask _before_ the current key takes
   effect, so mod1_was_down will be reset on the first key press after all
   three were released, not on the last release. That'd require some more
   effort.
 */
private int ephyrUpdateGrabModifierState(int state)
{
    static int mod1_was_down = 0;

    if ((state & (XCB_MOD_MASK_CONTROL|XCB_MOD_MASK_SHIFT|XCB_MOD_MASK_1)) == 0)
        mod1_was_down = 0;
    else if (state & XCB_MOD_MASK_1)
        mod1_was_down = 1;

    return mod1_was_down;
}

private void ephyrProcessKeyPress(xcb_generic_event_t* xev)
{
    xcb_key_press_event_t* key = cast(xcb_key_press_event_t*)xev;

    if (!ephyrKbd ||
        !(cast(EphyrKbdPrivate*) ephyrKbd.driverPrivate).enabled) {
        return;
    }

    ephyrUpdateGrabModifierState(key.state);
    ephyrUpdateModifierState(key.state);
    KdEnqueueKeyboardEvent(ephyrKbd, key.detail, FALSE);
}

private void ephyrProcessKeyRelease(xcb_generic_event_t* xev)
{
    xcb_key_release_event_t* key = cast(xcb_key_release_event_t*)xev;
    if (EphyrKeybindToggleHostGrabModMask != 0 ||
        EphyrKeybindToggleHostGrabKey != 0) {

        xcb_connection_t* conn = hostx_get_xcbconn();
        static xcb_key_symbols_t* keysyms;
        static int grabbed_screen = -1;

        if (!keysyms)
            keysyms = xcb_key_symbols_alloc(conn);

        const(int) keysym = xcb_key_symbols_get_keysym(keysyms, key.detail, 0);

        if (
            (
                (key.state & EphyrKeybindToggleHostGrabModMask) ==
                    EphyrKeybindToggleHostGrabModMask
            ) && (
                /* NOTE: mod-key keysyms are > 0xfe00. We do this so when the
                   shortcut is only mod-keys (e.g. ctrl+shift) and the user
                   releases any other key, input doesn't get grabbed */
                (EphyrKeybindToggleHostGrabKey == 0 && keysym > 0xfe00) ||
                keysym == EphyrKeybindToggleHostGrabKey
            )
        ) {
            KdScreenInfo* screen = screen_from_window(key.event);
            assert(screen);
            EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

            if (grabbed_screen != -1) {
                xcb_ungrab_keyboard(conn, XCB_TIME_CURRENT_TIME);
                xcb_ungrab_pointer(conn, XCB_TIME_CURRENT_TIME);
                grabbed_screen = -1;
            }
            else {
                /* Attempt grab */
                xcb_grab_keyboard_cookie_t kbgrabc = xcb_grab_keyboard(conn,
                                      TRUE,
                                      scrpriv.win,
                                      XCB_TIME_CURRENT_TIME,
                                      XCB_GRAB_MODE_ASYNC,
                                      XCB_GRAB_MODE_ASYNC);
                xcb_grab_keyboard_reply_t* kbgrabr = void;
                xcb_grab_pointer_cookie_t pgrabc = xcb_grab_pointer(conn,
                                     TRUE,
                                     scrpriv.win,
                                     0,
                                     XCB_GRAB_MODE_ASYNC,
                                     XCB_GRAB_MODE_ASYNC,
                                     scrpriv.win,
                                     XCB_NONE,
                                     XCB_TIME_CURRENT_TIME);
                xcb_grab_pointer_reply_t* pgrabr = void;
                kbgrabr = xcb_grab_keyboard_reply(conn, kbgrabc, null);
                if (!kbgrabr || kbgrabr.status != XCB_GRAB_STATUS_SUCCESS) {
                    xcb_discard_reply(conn, pgrabc.sequence);
                    xcb_ungrab_pointer(conn, XCB_TIME_CURRENT_TIME);
                } else {
                    pgrabr = xcb_grab_pointer_reply(conn, pgrabc, null);
                    if (!pgrabr || pgrabr.status != XCB_GRAB_STATUS_SUCCESS)
                        {
                            xcb_ungrab_keyboard(conn,
                                                XCB_TIME_CURRENT_TIME);
                        } else {
                        grabbed_screen = scrpriv.mynum;
                    }
                }
            }
            ephyrUpdateWindowTitle(screen, grabbed_screen != -1);
        }
    }

    if (!ephyrKbd ||
        !(cast(EphyrKbdPrivate*) ephyrKbd.driverPrivate).enabled) {
        return;
    }

    /* Still send the release event even if above has happened server
     * will get confused with just an up event.  Maybe it would be
     * better to just block shift+ctrls getting to kdrive all
     * together.
     */
    ephyrUpdateModifierState(key.state);
    KdEnqueueKeyboardEvent(ephyrKbd, key.detail, TRUE);
}

private void ephyrProcessConfigureNotify(xcb_generic_event_t* xev)
{
    xcb_configure_notify_event_t* configure = cast(xcb_configure_notify_event_t*)xev;
    KdScreenInfo* screen = screen_from_window(configure.window);
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (!scrpriv ||
        (scrpriv.win_pre_existing == None && !EphyrWantResize)) {
        return;
    }

static if(RANDR){
    ephyrResizeScreen(screen.pScreen, configure.width, configure.height);
} /* RANDR */
}

private void ephyrXcbProcessEvents(Bool queued_only)
{
    xcb_connection_t* conn = hostx_get_xcbconn();
    xcb_generic_event_t* expose = null, configure = null;

    while (TRUE) {
        xcb_generic_event_t* xev = hostx_get_event(queued_only);

        if (!xev) {
            /* If our XCB connection has died (for example, our window was
             * closed), exit now.
             */
            if (xcb_connection_has_error(conn)) {
                CloseWellKnownConnections();
                UnlockServer();
                exit(1);
            }

            break;
        }

        switch (xev.response_type & 0x7f) {
        case 0:
            ephyrProcessErrorEvent(xev);
            break;

        case XCB_EXPOSE:
            free(expose);
            expose = xev;
            xev = null;
            break;

        case XCB_MOTION_NOTIFY:
            ephyrProcessMouseMotion(xev);
            break;

        case XCB_KEY_PRESS:
            ephyrProcessKeyPress(xev);
            break;

        case XCB_KEY_RELEASE:
            ephyrProcessKeyRelease(xev);
            break;

        case XCB_BUTTON_PRESS:
            ephyrProcessButtonPress(xev);
            break;

        case XCB_BUTTON_RELEASE:
            ephyrProcessButtonRelease(xev);
            break;

        case XCB_CONFIGURE_NOTIFY:
            free(configure);
            configure = xev;
            xev = null;
            break;
        default: break;}

        if (xev) {
            free(xev);
        }
    }

    if (configure) {
        ephyrProcessConfigureNotify(configure);
        free(configure);
    }

    if (expose) {
        ephyrProcessExpose(expose);
        free(expose);
    }
}

private void ephyrXcbNotify(int fd, int ready, void* data)
{
    ephyrXcbProcessEvents(FALSE);
}

void ephyrCardFini(KdCardInfo* card)
{
    EphyrPriv* priv = cast(EphyrPriv*)card.driver;

    free(priv);
}

void ephyrGetColors(ScreenPtr pScreen, int n, xColorItem* pdefs)
{
    /* XXX Not sure if this is right */

    // EPHYR_LOG("mark");

    while (n--) {
        pdefs.red = 0;
        pdefs.green = 0;
        pdefs.blue = 0;
        pdefs++;
    }

}

void ephyrPutColors(ScreenPtr pScreen, int n, xColorItem* pdefs)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    int min = void, max = void, p = void;

    /* XXX Not sure if this is right */

    min = 256;
    max = 0;

    while (n--) {
        p = pdefs.pixel;
        if (p < min)
            min = p;
        if (p > max)
            max = p;

        hostx_set_cmap_entry(pScreen, cast(ubyte)p,
                             pdefs.red >> 8,
                             pdefs.green >> 8, pdefs.blue >> 8);
        pdefs++;
    }
    if (scrpriv.pDamage) {
        BoxRec box = void;
        RegionRec region = void;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pScreen.width;
        box.y2 = pScreen.height;
        RegionInit(&region, &box, 1);
        DamageReportDamage(scrpriv.pDamage, &region);
        RegionUninit(&region);
    }
}

/* Mouse calls */

private Status MouseInit(KdPointerInfo* pi)
{
    pi.driverPrivate = cast(EphyrPointerPrivate*)
        cast(EphyrPointerPrivate*) calloc(1, EphyrPointerPrivate.sizeof);
    if (!pi.driverPrivate)
        return BadAlloc;

    (cast(EphyrPointerPrivate*) pi.driverPrivate).enabled = FALSE;
    pi.nAxes = 3;
    pi.nButtons = 32;
    free(pi.name);
    pi.name = strdup("Xephyr virtual mouse");

    /*
     * Must transform pointer coords since the pointer position
     * relative to the Xephyr window is controlled by the host server and
     * remains constant regardless of any rotation applied to the Xephyr screen.
     */
    pi.transformCoordinates = TRUE;

    ephyrMouse = pi;
    return Success;
}

private Status MouseEnable(KdPointerInfo* pi)
{
    (cast(EphyrPointerPrivate*) pi.driverPrivate).enabled = TRUE;
    SetNotifyFd(hostx_get_fd(), &ephyrXcbNotify, X_NOTIFY_READ, null);
    return Success;
}

private void MouseDisable(KdPointerInfo* pi)
{
    (cast(EphyrPointerPrivate*) pi.driverPrivate).enabled = FALSE;
    RemoveNotifyFd(hostx_get_fd());
    return;
}

private void MouseFini(KdPointerInfo* pi)
{
    free(pi.driverPrivate);
    ephyrMouse = null;
    return;
}

KdPointerDriver EphyrMouseDriver = {
    name: "ephyr",
    Init: &MouseInit,
    Enable: &MouseEnable,
    Disable: &MouseDisable,
    Fini: &MouseFini,
};

/* Keyboard */

private Status EphyrKeyboardInit(KdKeyboardInfo* ki)
{
    KeySymsRec keySyms = void;
    CARD8[MAP_LENGTH] modmap = void;
    XkbControlsRec controls = void;

    ki.driverPrivate = cast(EphyrKbdPrivate*)
        cast(EphyrKbdPrivate*) calloc(1, EphyrKbdPrivate.sizeof);

    if (hostx_load_keymap(&keySyms, modmap.ptr, &controls)) {
        XkbApplyMappingChange(ki.dixdev, &keySyms,
                              keySyms.minKeyCode,
                              cast(ubyte)(keySyms.maxKeyCode - keySyms.minKeyCode + 1),
                              modmap.ptr, serverClient);
        XkbDDXChangeControls(ki.dixdev, &controls, &controls);
        free(keySyms.map);
    }

    ki.minScanCode = keySyms.minKeyCode;
    ki.maxScanCode = keySyms.maxKeyCode;

    if (ki.name !is null) {
        free(ki.name);
    }

    ki.name = strdup("Xephyr virtual keyboard");
    ephyrKbd = ki;
    return Success;
}

private Status EphyrKeyboardEnable(KdKeyboardInfo* ki)
{
    (cast(EphyrKbdPrivate*) ki.driverPrivate).enabled = TRUE;

    return Success;
}

private void EphyrKeyboardDisable(KdKeyboardInfo* ki)
{
    (cast(EphyrKbdPrivate*) ki.driverPrivate).enabled = FALSE;
}

private void EphyrKeyboardFini(KdKeyboardInfo* ki)
{
    free(ki.driverPrivate);
    ephyrKbd = null;
    return;
}

private void EphyrKeyboardLeds(KdKeyboardInfo* ki, int leds)
{
}

private void EphyrKeyboardBell(KdKeyboardInfo* ki, int volume, int frequency, int duration)
{
}

KdKeyboardDriver EphyrKeyboardDriver = {
    name: "ephyr",
    Init: &EphyrKeyboardInit,
    Enable: &EphyrKeyboardEnable,
    Leds: &EphyrKeyboardLeds,
    Bell: &EphyrKeyboardBell,
    Disable: &EphyrKeyboardDisable,
    Fini: &EphyrKeyboardFini,
};
