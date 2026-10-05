module hw.xfree86.modes.xf86Crtc;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2006 Keith Packard
 * Copyright © 2008 Red Hat, Inc.
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
import build.xlibre_server;

import core.stdc.stddef;
import core.stdc.string;
import core.stdc.stdio;

import dix.dix_priv;
import dix.screen_hooks_priv;
import randr.randrstr_priv;
import xf86Mode;
import randr.rrproperty;
import externs.X11.Xatom;

import edid_priv;
import xf86_priv;
import xf86DDC_priv;
import xf86Config;
import include.xf86Crtc;
import xf86Modes;
import xf86Opt_priv;
import include.xf86Priv;
import xf86RandR12_priv;
//import externs.X11.extensions._render;
// //import externs.X11.extensions.dpmsconst;
//import externs.X11.Xatom;
import include.picturestr;
import include.rrtransform;
import hw.xfree86.common.xf86Helper;;
import externs.attrs;
import externs.gnu;;
import xf86Rotate;
import xf86Option;
import os.log;
import Flags;
import Monitor;
import scan;
import xf86Globals;
import dix.screen_hooks;
import include.optionstr;
import include.xf86Parser;
import interpret_edid;
import externs.X11.extensions.dpmsconst;
import xf86CursorRD;
import xf86EdidModes;
import ddc;
import randr.rrcrtc;


version (XV) {
import xf86xv;
}

enum NO_OUTPUT_DEFAULT_WIDTH = 1024;
enum NO_OUTPUT_DEFAULT_HEIGHT = 768;
/*
 * Initialize xf86CrtcConfig structure
 */

int xf86CrtcConfigPrivateIndex = -1;

void *
sreallocarray(void *ptr, size_t nmemb, size_t size)
{
    void *ret = reallocarray(ptr, nmemb, size);

    if (!ret && nmemb && size)
        FatalError("reallocarray failed\n");

    return ret;
}

void xf86CrtcConfigInit(ScrnInfoPtr scrn, const(xf86CrtcConfigFuncsRec)* funcs)
{
    xf86CrtcConfigPtr config = void;

    if (xf86CrtcConfigPrivateIndex == -1)
        xf86CrtcConfigPrivateIndex = xf86AllocateScrnInfoPrivateIndex();
    config = cast(_xf86CrtcConfig*)XNFcallocarray(1, xf86CrtcConfigRec.sizeof);

    config.funcs = funcs;
    config.compat_output = -1;

    scrn.privates[xf86CrtcConfigPrivateIndex].ptr = config;
}

void xf86CrtcSetSizeRange(ScrnInfoPtr scrn, int minWidth, int minHeight, int maxWidth, int maxHeight)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    config.minWidth = minWidth;
    config.minHeight = minHeight;
    config.maxWidth = maxWidth;
    config.maxHeight = maxHeight;
}

/*
 * Crtc functions
 */
xf86CrtcPtr xf86CrtcCreate(ScrnInfoPtr scrn, const(xf86CrtcFuncsRec)* funcs)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    xf86CrtcPtr crtc = void; xf86CrtcPtr* crtcs = void;

    crtc = cast(xf86CrtcRec*) calloc(1, xf86CrtcRec.sizeof);
    if (!crtc)
        return null;
    crtc.version_ = XF86_CRTC_VERSION;
    crtc.scrn = scrn;
    crtc.funcs = funcs;
static if (RANDR_12_INTERFACE) {
    crtc.randr_crtc = null;
}
    crtc.rotation = RR_Rotate_0;
    crtc.desiredRotation = RR_Rotate_0;
    assumeNoGC(&pixman_transform_init_identity)(&crtc.crtc_to_framebuffer);
    assumeNoGC(&pixman_f_transform_init_identity)(&crtc.f_crtc_to_framebuffer);
    assumeNoGC(&pixman_f_transform_init_identity)(&crtc.f_framebuffer_to_crtc);
    crtc.filter = null;
    crtc.params = null;
    crtc.nparams = 0;
    crtc.filter_width = 0;
    crtc.filter_height = 0;
    crtc.transform_in_use = FALSE;
    crtc.transformPresent = FALSE;
    crtc.desiredTransformPresent = FALSE;
    memset(&crtc.bounds, '\0', typeof(crtc.bounds).sizeof);

    /* Preallocate gamma at a sensible size. */
    crtc.gamma_size = 256;
    crtc.gamma_red = cast(ushort*)calloc(crtc.gamma_size, 3 * CARD16.sizeof);
    if (!crtc.gamma_red) {
        free(crtc);
        return null;
    }
    crtc.gamma_green = crtc.gamma_red + crtc.gamma_size;
    crtc.gamma_blue = crtc.gamma_green + crtc.gamma_size;

    if (xf86_config.crtc)
        crtcs = cast(xf86CrtcPtr*)sreallocarray(xf86_config.crtc,
                             xf86_config.num_crtc + 1, xf86CrtcPtr.sizeof);
    else
        crtcs = cast(xf86CrtcPtr*) calloc(xf86_config.num_crtc + 1, xf86CrtcPtr.sizeof);
    if (!crtcs) {
        free(crtc.gamma_red);
        free(crtc);
        return null;
    }
    xf86_config.crtc = crtcs;
    xf86_config.crtc[xf86_config.num_crtc++] = crtc;
    return crtc;
}

void xf86CrtcDestroy(xf86CrtcPtr crtc)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
    int c = void;

    (*crtc.funcs.destroy) (crtc);
    for (c = 0; c < xf86_config.num_crtc; c++)
        if (xf86_config.crtc[c] == crtc) {
            memmove(&xf86_config.crtc[c],
                    &xf86_config.crtc[c + 1],
                    ((xf86_config.num_crtc - (c + 1)) * (void*).sizeof));
            xf86_config.num_crtc--;
            break;
        }
    free(crtc.params);
    free(crtc.gamma_red);
    free(crtc);
}

/**
 * Return whether any outputs are connected to the specified pipe
 */

Bool xf86CrtcInUse(xf86CrtcPtr crtc)
{
    ScrnInfoPtr pScrn = crtc.scrn;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int o = void;

    for (o = 0; o < xf86_config.num_output; o++)
        if (xf86_config.output[o].crtc == crtc)
            return TRUE;
    return FALSE;
}

/**
 * Return whether the crtc is leased by a client
 */

private Bool xf86CrtcIsLeased(xf86CrtcPtr crtc)
{
    /* If the DIX structure hasn't been created, it can't have been leased */
    if (!crtc.randr_crtc)
        return FALSE;
    return RRCrtcIsLeased(crtc.randr_crtc);
}

/**
 * Return whether the output is leased by a client
 */

private Bool xf86OutputIsLeased(xf86OutputPtr output)
{
    /* If the DIX structure hasn't been created, it can't have been leased */
    if (!output.randr_output)
        return FALSE;
    return RROutputIsLeased(cast(_rrOutput*)output.randr_output);
}

void xf86CrtcSetScreenSubpixelOrder(ScreenPtr pScreen)
{
    int subpixel_order = SubPixelUnknown;
    Bool has_none = FALSE;
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int icrtc = void, o = void;

    for (icrtc = 0; icrtc < xf86_config.num_crtc; icrtc++) {
        xf86CrtcPtr crtc = xf86_config.crtc[icrtc];

        for (o = 0; o < xf86_config.num_output; o++) {
            xf86OutputPtr output = xf86_config.output[o];

            if (output.crtc == crtc) {
                switch (output.subpixel_order) {
                case SubPixelNone:
                    has_none = TRUE;
                    break;
                case SubPixelUnknown:
                    break;
                default:
                    subpixel_order = output.subpixel_order;
                    break;
                }
            }
            if (subpixel_order != SubPixelUnknown)
                break;
        }
        if (subpixel_order != SubPixelUnknown) {
            static const(int)[4] circle = [
                SubPixelHorizontalRGB,
                SubPixelVerticalRGB,
                SubPixelHorizontalBGR,
                SubPixelVerticalBGR,
            ];
            int rotate = void;
            int sc = void;

            for (rotate = 0; rotate < 4; rotate++)
                if (crtc.rotation & (1 << rotate))
                    break;
            for (sc = 0; sc < 4; sc++)
                if (circle[sc] == subpixel_order)
                    break;
            sc = (sc + rotate) & 0x3;
            if ((crtc.rotation & RR_Reflect_X) && !(sc & 1))
                sc ^= 2;
            if ((crtc.rotation & RR_Reflect_Y) && (sc & 1))
                sc ^= 2;
            subpixel_order = circle[sc];
            break;
        }
    }
    if (subpixel_order == SubPixelUnknown && has_none)
        subpixel_order = SubPixelNone;
    PictureSetSubpixelOrder(pScreen, subpixel_order);
}

/**
 * Sets the given video mode on the given crtc
 */
Bool xf86CrtcSetModeTransform(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, RRTransformPtr transform, int x, int y)
{
    ScrnInfoPtr scrn = crtc.scrn;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int i = void;
    Bool ret = FALSE;
    Bool didLock = FALSE;
    DisplayModePtr adjusted_mode = void;
    DisplayModeRec saved_mode = void;
    int saved_x = void, saved_y = void;
    Rotation saved_rotation = void;
    RRTransformRec saved_transform = void;
    Bool saved_transform_present = void;

    crtc.enabled = xf86CrtcInUse(crtc) && !xf86CrtcIsLeased(crtc);

    /* We only hit this if someone explicitly sends a "disabled" modeset. */
    if (!crtc.enabled) {
        /* Check everything for stuff that should be off. */
        xf86DisableUnusedFunctions(scrn);
        return TRUE;
    }

    adjusted_mode = xf86DuplicateMode(mode);

    saved_mode = crtc.mode;
    saved_x = crtc.x;
    saved_y = crtc.y;
    saved_rotation = crtc.rotation;
    if (crtc.transformPresent) {
        RRTransformInit(&saved_transform);
        RRTransformCopy(&saved_transform, &crtc.transform);
    }
    saved_transform_present = crtc.transformPresent;

    /* Update crtc values up front so the driver can rely on them for mode
     * setting.
     */
    crtc.mode = *mode;
    crtc.x = x;
    crtc.y = y;
    crtc.rotation = rotation;
    if (transform) {
        RRTransformCopy(&crtc.transform, transform);
        crtc.transformPresent = TRUE;
    }
    else
        crtc.transformPresent = FALSE;

    if (crtc.funcs.set_mode_major) {
        ret = crtc.funcs.set_mode_major(crtc, mode, rotation, x, y);
        goto done;
    }

    didLock = crtc.funcs.lock(crtc);
    /* Pass our mode to the outputs and the CRTC to give them a chance to
     * adjust it according to limitations or output properties, and also
     * a chance to reject the mode entirely.
     */
    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];

        if (output.crtc != crtc)
            continue;

        if (!output.funcs.mode_fixup(output, mode, adjusted_mode)) {
            goto done;
        }
    }

    if (!crtc.funcs.mode_fixup(crtc, mode, adjusted_mode)) {
        goto done;
    }

    if (!xf86CrtcRotate(crtc))
        goto done;

    /* Prepare the outputs and CRTCs before setting the mode. */
    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];

        if (output.crtc != crtc)
            continue;

        /* Disable the output as the first thing we do. */
        output.funcs.prepare(output);
    }

    crtc.funcs.prepare(crtc);

    /* Set up the DPLL and any output state that needs to adjust or depend
     * on the DPLL.
     */
    crtc.funcs.mode_set(crtc, mode, adjusted_mode, crtc.x, crtc.y);
    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];

        if (output.crtc == crtc)
            output.funcs.mode_set(output, mode, adjusted_mode);
    }

    /* Only upload when needed, to avoid unneeded delays. */
    if (!crtc.active && crtc.funcs.gamma_set)
        crtc.funcs.gamma_set(crtc, crtc.gamma_red, crtc.gamma_green,
                               crtc.gamma_blue, crtc.gamma_size);

    /* Now, enable the clocks, plane, pipe, and outputs that we set up. */
    crtc.funcs.commit(crtc);
    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];

        if (output.crtc == crtc)
            output.funcs.commit(output);
    }

    ret = TRUE;

 done:
    if (ret) {
        crtc.active = TRUE;
        if (scrn.pScreen)
            xf86CrtcSetScreenSubpixelOrder(scrn.pScreen);
        if (scrn.ModeSet)
            scrn.ModeSet(scrn);

        /* Make sure the HW cursor is hidden if it's supposed to be, in case
         * it was hidden while the CRTC was disabled
         */
        if (!xf86_config.cursor_on)
            xf86_hide_cursors(scrn);
    }
    else {
        crtc.x = saved_x;
        crtc.y = saved_y;
        crtc.rotation = saved_rotation;
        crtc.mode = saved_mode;
        if (saved_transform_present)
            RRTransformCopy(&crtc.transform, &saved_transform);
        crtc.transformPresent = saved_transform_present;
    }

    free(cast(void*) adjusted_mode.name);
    free(adjusted_mode);

    if (didLock)
        crtc.funcs.unlock(crtc);

    return ret;
}

/**
 * Sets the given video mode on the given crtc, but without providing
 * a transform
 */
Bool xf86CrtcSetMode(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, int x, int y)
{
    return xf86CrtcSetModeTransform(crtc, mode, rotation, null, x, y);
}

/**
 * Pans the screen, does not change the mode
 */
void xf86CrtcSetOrigin(xf86CrtcPtr crtc, int x, int y)
{
    ScrnInfoPtr scrn = crtc.scrn;

    crtc.x = x;
    crtc.y = y;

    if (xf86CrtcIsLeased(crtc))
        return;

    if (crtc.funcs.set_origin) {
        if (!xf86CrtcRotate(crtc))
            return;
        crtc.funcs.set_origin(crtc, x, y);
        if (scrn.ModeSet)
            scrn.ModeSet(scrn);
    }
    else
        xf86CrtcSetMode(crtc, &crtc.mode, crtc.rotation, x, y);
}

/*
 * Output functions
 */

enum OutputOpts {
    OPTION_PREFERRED_MODE,
    OPTION_ZOOM_MODES,
    OPTION_POSITION,
    OPTION_BELOW,
    OPTION_RIGHT_OF,
    OPTION_ABOVE,
    OPTION_LEFT_OF,
    OPTION_ENABLE,
    OPTION_DISABLE,
    OPTION_MIN_CLOCK,
    OPTION_MAX_CLOCK,
    OPTION_IGNORE,
    OPTION_ROTATE,
    OPTION_PANNING,
    OPTION_PRIMARY,
    OPTION_DEFAULT_MODES,
}
alias OPTION_PREFERRED_MODE = OutputOpts.OPTION_PREFERRED_MODE;
alias OPTION_ZOOM_MODES = OutputOpts.OPTION_ZOOM_MODES;
alias OPTION_POSITION = OutputOpts.OPTION_POSITION;
alias OPTION_BELOW = OutputOpts.OPTION_BELOW;
alias OPTION_RIGHT_OF = OutputOpts.OPTION_RIGHT_OF;
alias OPTION_ABOVE = OutputOpts.OPTION_ABOVE;
alias OPTION_LEFT_OF = OutputOpts.OPTION_LEFT_OF;
alias OPTION_ENABLE = OutputOpts.OPTION_ENABLE;
alias OPTION_DISABLE = OutputOpts.OPTION_DISABLE;
alias OPTION_MIN_CLOCK = OutputOpts.OPTION_MIN_CLOCK;
alias OPTION_MAX_CLOCK = OutputOpts.OPTION_MAX_CLOCK;
alias OPTION_IGNORE = OutputOpts.OPTION_IGNORE;
alias OPTION_ROTATE = OutputOpts.OPTION_ROTATE;
alias OPTION_PANNING = OutputOpts.OPTION_PANNING;
alias OPTION_PRIMARY = OutputOpts.OPTION_PRIMARY;
alias OPTION_DEFAULT_MODES = OutputOpts.OPTION_DEFAULT_MODES;


private OptionInfoRec[18] xf86OutputOptions = [
    {OPTION_PREFERRED_MODE, "PreferredMode", OPTV_STRING, {0}, FALSE},
    {OPTION_ZOOM_MODES, "ZoomModes", OPTV_STRING, {0}, FALSE },
    {OPTION_POSITION, "Position", OPTV_STRING, {0}, FALSE},
    {OPTION_BELOW, "Below", OPTV_STRING, {0}, FALSE},
    {OPTION_RIGHT_OF, "RightOf", OPTV_STRING, {0}, FALSE},
    {OPTION_ABOVE, "Above", OPTV_STRING, {0}, FALSE},
    {OPTION_LEFT_OF, "LeftOf", OPTV_STRING, {0}, FALSE},
    {OPTION_ENABLE, "Enable", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_DISABLE, "Disable", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_MIN_CLOCK, "MinClock", OPTV_FREQ, {0}, FALSE},
    {OPTION_MAX_CLOCK, "MaxClock", OPTV_FREQ, {0}, FALSE},
    {OPTION_IGNORE, "Ignore", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_ROTATE, "Rotate", OPTV_STRING, {0}, FALSE},
    {OPTION_PANNING, "Panning", OPTV_STRING, {0}, FALSE},
    {OPTION_PRIMARY, "Primary", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_DEFAULT_MODES, "DefaultModes", OPTV_BOOLEAN, {0}, FALSE},
    {-1, null, OPTV_NONE, {0}, FALSE},
];

enum {
    OPTION_MODEDEBUG,
    OPTION_PREFER_CLONEMODE,
    OPTION_NO_OUTPUT_INITIAL_SIZE,
}

private OptionInfoRec[5] xf86DeviceOptions = [
    {OPTION_MODEDEBUG, "ModeDebug", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_PREFER_CLONEMODE, "PreferCloneMode", OPTV_BOOLEAN, {0}, FALSE},
    {OPTION_NO_OUTPUT_INITIAL_SIZE, "NoOutputInitialSize", OPTV_STRING, {0}, FALSE},
    {-1, null, OPTV_NONE, {0}, FALSE},
];

private void xf86OutputSetMonitor(xf86OutputPtr output)
{
    if (!output.name)
        return;

    free(output.options);

    output.options = cast(_OptionInfoRec*)XNFalloc(xf86OutputOptions.sizeof);
    memcpy(output.options, xf86OutputOptions.ptr, xf86OutputOptions.sizeof);

    const(char)* monitor = null;
    char* option_name = null;
    if (asprintf(&option_name, "monitor-%s", output.name) != -1)
        monitor = xf86findOptionValue(cast(_InputOption*)output.scrn.options, option_name);

    if (!monitor)
        monitor = output.name;
    else
        xf86MarkOptionUsedByName(cast(_InputOption*)output.scrn.options, option_name);
    free(option_name);
    output.conf_monitor = xf86findMonitor(monitor,
                                           xf86configptr.conf_monitor_lst);
    /*
     * Find the monitor section of the screen and use that
     */
    if (!output.conf_monitor && output.use_screen_monitor)
        output.conf_monitor = xf86findMonitor(output.scrn.monitor.id,
                                               xf86configptr.conf_monitor_lst);
    if (output.conf_monitor) {
        xf86DrvMsg(output.scrn.scrnIndex, X_INFO,
                   "Output %s using monitor section %s\n",
                   output.name, output.conf_monitor.mon_identifier);
        xf86ProcessOptions(output.scrn.scrnIndex,
                           output.conf_monitor.mon_option_lst,
                           output.options);
    }
    else
        xf86DrvMsg(output.scrn.scrnIndex, X_INFO,
                   "Output %s has no monitor section\n", output.name);
}

Bool xf86OutputForceEnabled(xf86OutputPtr output)
{
    Bool enable = void;

    if (xf86GetOptValBool(output.options, OPTION_ENABLE, &enable) && enable)
        return TRUE;
    return FALSE;
}

private Bool xf86OutputEnabled(xf86OutputPtr output, Bool strict)
{
    Bool enable = void, disable = void;

    /* check to see if this output was enabled in the config file */
    if (xf86GetOptValBool(output.options, OPTION_ENABLE, &enable) && enable) {
        xf86DrvMsg(output.scrn.scrnIndex, X_INFO,
                   "Output %s enabled by config file\n", output.name);
        return TRUE;
    }
    /* or if this output was disabled in the config file */
    if (xf86GetOptValBool(output.options, OPTION_DISABLE, &disable) && disable) {
        xf86DrvMsg(output.scrn.scrnIndex, X_INFO,
                   "Output %s disabled by config file\n", output.name);
        return FALSE;
    }

    /* If not, try to only light up the ones we know are connected which are supposed to be on the desktop */
    if (strict) {
        enable = output.status == XF86OutputStatusConnected && !output.non_desktop;
    }
    /* But if that fails, try to light up even outputs we're unsure of */
    else {
        enable = output.status != XF86OutputStatusDisconnected;
    }

    xf86DrvMsg(output.scrn.scrnIndex, X_INFO,
               "Output %s %sconnected\n", output.name, enable ? "".ptr : "dis".ptr);
    return enable;
}

private Bool xf86OutputIgnored(xf86OutputPtr output)
{
    return xf86ReturnOptValBool(output.options, OPTION_IGNORE, FALSE);
}

private const(char)*[4] direction = [
    "normal",
    "left",
    "inverted",
    "right"
];

private Rotation xf86OutputInitialRotation(xf86OutputPtr output)
{
    const(char)* rotate_name = xf86GetOptValString(output.options,
                                                  OPTION_ROTATE);
    int i = void;

    if (!rotate_name) {
        if (output.initial_rotation)
            return output.initial_rotation;
        return RR_Rotate_0;
    }

    for (i = 0; i < 4; i++)
        if (xf86nameCompare(direction[i], rotate_name) == 0)
            return cast(ushort)(1 << i);
    return RR_Rotate_0;
}

xf86OutputPtr xf86OutputCreate(ScrnInfoPtr scrn, const(xf86OutputFuncsRec)* funcs, const(char)* name)
{
    xf86OutputPtr output = void; xf86OutputPtr* outputs = void;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int len = void;
    Bool primary = void;

    if (name)
        len = cast(int)strlen(name) + 1;
    else
        len = 0;

    output = cast(_xf86Output*)calloc(1, ((xf86OutputRec).sizeof + len));
    if (!output)
        return null;
    output.scrn = scrn;
    output.funcs = funcs;
    if (name) {
        output.name = cast(char*) (output + 1);
        strcpy(output.name, name);
    }
    output.subpixel_order = SubPixelUnknown;
    /*
     * Use the old per-screen monitor section for the first output
     */
    output.use_screen_monitor = (xf86_config.num_output == 0);
static if (RANDR_12_INTERFACE) {
    output.randr_output = null;
}
    if (name) {
        xf86OutputSetMonitor(output);
        if (xf86OutputIgnored(output)) {
            free(output);
            return null;
        }
    }

    if (xf86_config.output)
        outputs = cast(_xf86Output**)reallocarray(xf86_config.output,
                               xf86_config.num_output + 1,
                               xf86OutputPtr.sizeof);
    else
        outputs = cast(xf86OutputPtr*) calloc(xf86_config.num_output + 1, xf86OutputPtr.sizeof);
    if (!outputs) {
        free(output);
        return null;
    }

    xf86_config.output = outputs;

    if (xf86GetOptValBool(output.options, OPTION_PRIMARY, &primary) && primary) {
        memmove(xf86_config.output + 1, xf86_config.output,
                xf86_config.num_output * xf86OutputPtr.sizeof);
        xf86_config.output[0] = output;
    }
    else {
        xf86_config.output[xf86_config.num_output] = output;
    }

    xf86_config.num_output++;

    return output;
}

Bool xf86OutputRename(xf86OutputPtr output, const(char)* name)
{
    char* newname = strdup(name);

    if (!newname)
        return FALSE;           /* so sorry... */

    if (output.name && output.name != cast(char*) (output + 1))
        free(output.name);
    output.name = newname;
    xf86OutputSetMonitor(output);
    if (xf86OutputIgnored(output))
        return FALSE;
    return TRUE;
}

void xf86OutputUseScreenMonitor(xf86OutputPtr output, Bool use_screen_monitor)
{
    if (use_screen_monitor != output.use_screen_monitor) {
        output.use_screen_monitor = use_screen_monitor;
        xf86OutputSetMonitor(output);
    }
}

void xf86OutputDestroy(xf86OutputPtr output)
{
    ScrnInfoPtr scrn = output.scrn;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;

    assumeNoGC(output.funcs.destroy) (output);
    while (output.probed_modes)
        xf86DeleteMode(&output.probed_modes, output.probed_modes);
    for (o = 0; o < xf86_config.num_output; o++)
        if (xf86_config.output[o] == output) {
            memmove(&xf86_config.output[o],
                    &xf86_config.output[o + 1],
                    ((xf86_config.num_output - (o + 1)) * (void*).sizeof));
            xf86_config.num_output--;
            break;
        }
    if (output.name && output.name != cast(char*) (output + 1))
        free(output.name);
    free(output);
}

/*
 * installed by xf86CrtcScreenInit() and called by during CreateScreenResources
 */
private void xf86CrtcCreateScreenResources(CallbackListPtr* pcbl, ScreenPtr pScreen, Bool* ret)
{
    xf86RandR12CreateScreenResources(pScreen);
}

/*
 * Clean up config on server reset
 */
private void xf86CrtcCloseScreen(CallbackListPtr* pcbl, ScreenPtr screen, void* unused)
{
    dixScreenUnhookClose(screen, &xf86CrtcCloseScreen);
    dixScreenUnhookPostCreateResources(screen, &xf86CrtcCreateScreenResources);

    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void, c = void;

    /* The randr_output and randr_crtc pointers are already invalid as
     * the DIX resources were freed when the associated resources were
     * freed. Clear them now; referencing through them during the rest
     * of the CloseScreen sequence will not end well.
     */
    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];

        output.randr_output = null;
    }
    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];

        crtc.randr_crtc = null;
    }

    xf86RotateCloseScreen(screen);

    xf86RandR12CloseScreen(screen);

    /* detach any providers */
    if (config.randr_provider) {
        RRProviderDestroy(cast(_rrProvider*)config.randr_provider);
        config.randr_provider = null;
    }
}

/*
 * Called at ScreenInit time to set up
 */
static if (RANDR_13_INTERFACE) {
alias xf86CrtcScreenInitType = int;
}
else {
alias xf86CrtcScreenInitType = Bool;

}

xf86CrtcScreenInitType xf86CrtcScreenInit(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int c = void;

    /* Rotation */
    xf86RandR12Init(screen);

    /* support all rotations if every crtc has the shadow alloc funcs */
    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];

        if (!crtc.funcs.shadow_allocate || !crtc.funcs.shadow_create)
            break;
    }
    if (c == config.num_crtc) {
        xf86RandR12SetRotations(screen, RR_Rotate_0 | RR_Rotate_90 |
                                RR_Rotate_180 | RR_Rotate_270 |
                                RR_Reflect_X | RR_Reflect_Y);
        xf86RandR12SetTransformSupport(screen, TRUE);
    }
    else {
        xf86RandR12SetRotations(screen, RR_Rotate_0);
        xf86RandR12SetTransformSupport(screen, FALSE);
    }

    dixScreenHookClose(screen, &xf86CrtcCloseScreen);
    dixScreenHookPostCreateResources(screen, &xf86CrtcCreateScreenResources);

    /* This might still be marked wrapped from a previous generation */
    config.BlockHandler = null;

static if(XFreeXDGA){
    _xf86_di_dga_init_internal(screen);
}
static if (RANDR_13_INTERFACE) {
    return RANDR_INTERFACE_VERSION;
} else {
    return TRUE;
}
}

private DisplayModePtr xf86DefaultMode(xf86OutputPtr output, int width, int height)
{
    DisplayModePtr target_mode = null;
    DisplayModePtr mode = void;
    int target_diff = 0;
    int target_preferred = 0;
    int mm_height = void;

    mm_height = output.mm_height;
    if (!mm_height)
        mm_height = cast(int)((768 * 25.4) / DEFAULT_DPI);
    /*
     * Pick a mode closest to DEFAULT_DPI
     */
    for (mode = output.probed_modes; mode; mode = mode.next) {
        int dpi = void;
        int preferred = (((mode.type & M_T_PREFERRED) != 0) +
                         ((mode.type & M_T_USERPREF) != 0));
        int diff = void;

        if (xf86ModeWidth(mode, output.initial_rotation) > width ||
            xf86ModeHeight(mode, output.initial_rotation) > height)
            continue;

        /* yes, use VDisplay here, not xf86ModeHeight */
        dpi = (mode.VDisplay * 254) / (mm_height * 10);
        diff = dpi - DEFAULT_DPI;
        diff = diff < 0 ? -diff : diff;
        if (target_mode is null || (preferred > target_preferred) ||
            (preferred == target_preferred && diff < target_diff)) {
            target_mode = mode;
            target_diff = diff;
            target_preferred = preferred;
        }
    }
    return target_mode;
}

private DisplayModePtr xf86ClosestMode(xf86OutputPtr output, DisplayModePtr match, Rotation match_rotation, int width, int height)
{
    DisplayModePtr target_mode = null;
    DisplayModePtr mode = void;
    int target_diff = 0;

    /*
     * Pick a mode closest to the specified mode
     */
    for (mode = output.probed_modes; mode; mode = mode.next) {
        int dx = void, dy = void;
        int diff = void;

        if (xf86ModeWidth(mode, output.initial_rotation) > width ||
            xf86ModeHeight(mode, output.initial_rotation) > height)
            continue;

        /* exact matches are preferred */
        if (output.initial_rotation == match_rotation &&
            xf86ModesEqual(mode, match))
            return mode;

        dx = xf86ModeWidth(match, match_rotation) - xf86ModeWidth(mode,
                                                                  output.
                                                                  initial_rotation);
        dy = xf86ModeHeight(match, match_rotation) - xf86ModeHeight(mode,
                                                                    output.
                                                                    initial_rotation);
        diff = dx * dx + dy * dy;
        if (target_mode is null || diff < target_diff) {
            target_mode = mode;
            target_diff = diff;
        }
    }
    return target_mode;
}

private DisplayModePtr xf86OutputHasPreferredMode(xf86OutputPtr output, int width, int height)
{
    DisplayModePtr mode = void;

    for (mode = output.probed_modes; mode; mode = mode.next) {
        if (xf86ModeWidth(mode, output.initial_rotation) > width ||
            xf86ModeHeight(mode, output.initial_rotation) > height)
            continue;

        if (mode.type & M_T_PREFERRED)
            return mode;
    }
    return null;
}

private DisplayModePtr xf86OutputHasUserPreferredMode(xf86OutputPtr output)
{
    DisplayModePtr mode = void, first = output.probed_modes;

    for (mode = first; mode && mode.next != first; mode = mode.next)
        if (mode.type & M_T_USERPREF)
            return mode;

    return null;
}

private int xf86PickCrtcs(ScrnInfoPtr scrn, xf86CrtcPtr* best_crtcs, DisplayModePtr* modes, int n, int width, int height)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int c = void, o = void;
    xf86OutputPtr output = void;
    xf86CrtcPtr crtc = void;
    xf86CrtcPtr* crtcs = void;
    int best_score = void;
    int score = void;
    int my_score = void;

    if (n == config.num_output)
        return 0;
    output = config.output[n];

    /*
     * Compute score with this output disabled
     */
    best_crtcs[n] = null;
    best_score = xf86PickCrtcs(scrn, best_crtcs, modes, n + 1, width, height);
    if (modes[n] is null)
        return best_score;

    crtcs = cast(xf86CrtcPtr*) calloc(config.num_output, xf86CrtcPtr.sizeof);
    if (!crtcs)
        return best_score;

    my_score = 1;
    /* Score outputs that are known to be connected higher */
    if (output.status == XF86OutputStatusConnected)
        my_score++;
    /* Score outputs with preferred modes higher */
    if (xf86OutputHasPreferredMode(output, width, height))
        my_score++;
    /*
     * Select a crtc for this output and
     * then attempt to configure the remaining
     * outputs
     */
    for (c = 0; c < config.num_crtc; c++) {
        if ((output.possible_crtcs & (1 << c)) == 0)
            continue;

        crtc = config.crtc[c];
        /*
         * Check to see if some other output is
         * using this crtc
         */
        for (o = 0; o < n; o++)
            if (best_crtcs[o] == crtc)
                break;
        if (o < n) {
            /*
             * If the two outputs desire the same mode,
             * see if they can be cloned
             */
            if (xf86ModesEqual(modes[o], modes[n]) &&
                config.output[o].initial_rotation ==
                config.output[n].initial_rotation &&
                config.output[o].initial_x == config.output[n].initial_x &&
                config.output[o].initial_y == config.output[n].initial_y) {
                if ((output.possible_clones & (1 << o)) == 0)
                    continue;   /* nope, try next CRTC */
            }
            else
                continue;       /* different modes, can't clone */
        }
        crtcs[n] = crtc;
        memcpy(crtcs, best_crtcs, n * xf86CrtcPtr.sizeof);
        score =
            my_score + xf86PickCrtcs(scrn, crtcs, modes, n + 1, width, height);
        if (score > best_score) {
            best_score = score;
            memcpy(best_crtcs, crtcs, config.num_output * xf86CrtcPtr.sizeof);
        }
    }
    free(crtcs);
    return best_score;
}

/*
 * Compute the virtual size necessary to place all of the available
 * crtcs in the specified configuration.
 *
 * canGrow indicates that the driver can make the screen larger than its initial
 * configuration.  If FALSE, this function will enlarge the screen to include
 * the largest available mode.
 */

private void xf86DefaultScreenLimits(ScrnInfoPtr scrn, int* widthp, int* heightp, Bool canGrow)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int width = 0, height = 0;
    int o = void;
    int c = void;
    int s = void;

    for (c = 0; c < config.num_crtc; c++) {
        int crtc_width = 0, crtc_height = 0;
        xf86CrtcPtr crtc = config.crtc[c];

        if (crtc.enabled) {
            crtc_width =
                crtc.desiredX + xf86ModeWidth(&crtc.desiredMode,
                                               crtc.desiredRotation);
            crtc_height =
                crtc.desiredY + xf86ModeHeight(&crtc.desiredMode,
                                                crtc.desiredRotation);
        }
        if (!canGrow) {
            for (o = 0; o < config.num_output; o++) {
                xf86OutputPtr output = config.output[o];

                for (s = 0; s < config.num_crtc; s++)
                    if (output.possible_crtcs & (1 << s)) {
                        DisplayModePtr mode = void;

                        for (mode = output.probed_modes; mode;
                             mode = mode.next) {
                            if (mode.HDisplay > crtc_width)
                                crtc_width = mode.HDisplay;
                            if (mode.VDisplay > crtc_width)
                                crtc_width = mode.VDisplay;
                            if (mode.VDisplay > crtc_height)
                                crtc_height = mode.VDisplay;
                            if (mode.HDisplay > crtc_height)
                                crtc_height = mode.HDisplay;
                        }
                    }
            }
        }
        if (crtc_width > width)
            width = crtc_width;
        if (crtc_height > height)
            height = crtc_height;
    }
    if (config.maxWidth && width > config.maxWidth)
        width = config.maxWidth;
    if (config.maxHeight && height > config.maxHeight)
        height = config.maxHeight;
    if (config.minWidth && width < config.minWidth)
        width = config.minWidth;
    if (config.minHeight && height < config.minHeight)
        height = config.minHeight;
    *widthp = width;
    *heightp = height;
}

enum POSITION_UNSET =	-100000;

/*
 * check if the user configured any outputs at all
 * with either a position or a relative setting or a mode.
 */
private Bool xf86UserConfiguredOutputs(ScrnInfoPtr scrn, DisplayModePtr* modes)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;
    Bool user_conf = FALSE;

    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];
        const(char)* position = void;
        const(char)* relative_name = void;
        OutputOpts relation = void;
        int r = void;

        static const(OutputOpts)[4] relations = [
            OPTION_BELOW, OPTION_RIGHT_OF, OPTION_ABOVE, OPTION_LEFT_OF
        ];

        position = xf86GetOptValString(output.options, OPTION_POSITION);
        if (position)
            user_conf = TRUE;

        // relation = .init;
        relative_name = null;
        for (r = 0; r < 4; r++) {
            relation = relations[r];
            relative_name = xf86GetOptValString(output.options, relation);
            if (relative_name)
                break;
        }
        if (relative_name)
            user_conf = TRUE;

        modes[o] = xf86OutputHasUserPreferredMode(output);
        if (modes[o])
            user_conf = TRUE;
    }

    return user_conf;
}

private Bool xf86InitialOutputPositions(ScrnInfoPtr scrn, DisplayModePtr* modes)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;
    int min_x = void, min_y = void;

    /* check for initial right-of heuristic */
    for (o = 0; o < config.num_output; o++)
    {
        xf86OutputPtr output = config.output[o];

        if (output.initial_x || output.initial_y)
            return TRUE;
    }

    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];

        output.initial_x = output.initial_y = POSITION_UNSET;
    }

    /*
     * Loop until all outputs are set
     */
    for (;;) {
        Bool any_set = FALSE;
        Bool keep_going = FALSE;

        for (o = 0; o < config.num_output; o++) {
            static const(OutputOpts)[4] relations = [
                OPTION_BELOW, OPTION_RIGHT_OF, OPTION_ABOVE, OPTION_LEFT_OF
            ];
            xf86OutputPtr output = config.output[o];
            xf86OutputPtr relative = void;
            const(char)* relative_name = void;
            const(char)* position = void;
            OutputOpts relation = void;
            int r = void;

            if (output.initial_x != POSITION_UNSET)
                continue;
            position = xf86GetOptValString(output.options, OPTION_POSITION);
            /*
             * Absolute position wins
             */
            if (position) {
                int x = void, y = void;

                if (sscanf(position, "%d %d", &x, &y) == 2) {
                    output.initial_x = x;
                    output.initial_y = y;
                }
                else {
                    xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                               "Output %s position not of form \"x y\"\n",
                               output.name);
                    output.initial_x = output.initial_y = 0;
                }
                any_set = TRUE;
                continue;
            }
            /*
             * Next comes relative positions
             */
            // relation = void;
            relative_name = null;
            for (r = 0; r < 4; r++) {
                relation = relations[r];
                relative_name = xf86GetOptValString(output.options, relation);
                if (relative_name)
                    break;
            }
            if (relative_name) {
                int or = void;

                relative = null;
                for (or = 0; or < config.num_output; or++) {
                    xf86OutputPtr out_rel = config.output[or];
                    XF86ConfMonitorPtr rel_mon = out_rel.conf_monitor;

                    if (rel_mon) {
                        if (xf86nameCompare(rel_mon.mon_identifier,
                                            relative_name) == 0) {
                            relative = config.output[or];
                            break;
                        }
                    }
                    if (strcmp(out_rel.name, relative_name) == 0) {
                        relative = config.output[or];
                        break;
                    }
                }
                if (!relative) {
                    xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                               "Cannot position output %s relative to unknown output %s\n",
                               output.name, relative_name);
                    output.initial_x = 0;
                    output.initial_y = 0;
                    any_set = TRUE;
                    continue;
                }
                if (!modes[or]) {
                    xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                               "Cannot position output %s relative to output %s without modes\n",
                               output.name, relative_name);
                    output.initial_x = 0;
                    output.initial_y = 0;
                    any_set = TRUE;
                    continue;
                }
                if (relative.initial_x == POSITION_UNSET) {
                    keep_going = TRUE;
                    continue;
                }
                output.initial_x = relative.initial_x;
                output.initial_y = relative.initial_y;
                switch (relation) {
                case OPTION_BELOW:
                    output.initial_y +=
                        xf86ModeHeight(modes[or], relative.initial_rotation);
                    break;
                case OPTION_RIGHT_OF:
                    output.initial_x +=
                        xf86ModeWidth(modes[or], relative.initial_rotation);
                    break;
                case OPTION_ABOVE:
                    if (modes[o])
                        output.initial_y -=
                            xf86ModeHeight(modes[o], output.initial_rotation);
                    break;
                case OPTION_LEFT_OF:
                    if (modes[o])
                        output.initial_x -=
                            xf86ModeWidth(modes[o], output.initial_rotation);
                    break;
                default:
                    break;
                }
                any_set = TRUE;
                continue;
            }

            /* Nothing set, just stick them at 0,0 */
            output.initial_x = 0;
            output.initial_y = 0;
            any_set = TRUE;
        }
        if (!keep_going)
            break;
        if (!any_set) {
            for (o = 0; o < config.num_output; o++) {
                xf86OutputPtr output = config.output[o];

                if (output.initial_x == POSITION_UNSET) {
                    xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                               "Output position loop. Moving %s to 0,0\n",
                               output.name);
                    output.initial_x = output.initial_y = 0;
                    break;
                }
            }
        }
    }

    /*
     * normalize positions
     */
    min_x = 1000000;
    min_y = 1000000;
    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];

        if (output.initial_x < min_x)
            min_x = output.initial_x;
        if (output.initial_y < min_y)
            min_y = output.initial_y;
    }

    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];

        output.initial_x -= min_x;
        output.initial_y -= min_y;
    }
    return TRUE;
}

private void xf86InitialPanning(ScrnInfoPtr scrn)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;

    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];
        const(char)* panning = xf86GetOptValString(output.options, OPTION_PANNING);
        int width = void, height = void, left = void, top = void;
        int track_width = void, track_height = void, track_left = void, track_top = void;
        int[4] brdr = void;

        memset(&output.initialTotalArea, 0, BoxRec.sizeof);
        memset(&output.initialTrackingArea, 0, BoxRec.sizeof);
        memset(output.initialBorder.ptr, 0, 4 * INT16.sizeof);

        if (!panning)
            continue;

        switch (sscanf(panning, "%dx%d+%d+%d/%dx%d+%d+%d/%d/%d/%d/%d",
                       &width, &height, &left, &top,
                       &track_width, &track_height, &track_left, &track_top,
                       &brdr[0], &brdr[1], &brdr[2], &brdr[3])) {
        case 12:
            output.initialBorder[0] = cast(short)brdr[0];
            output.initialBorder[1] = cast(short)brdr[1];
            output.initialBorder[2] = cast(short)brdr[2];
            output.initialBorder[3] = cast(short)brdr[3];
            /* fall through */
            goto case;
        case 8:
            output.initialTrackingArea.x1 = cast(short)(track_left);
            output.initialTrackingArea.y1 = cast(short)(track_top);
            output.initialTrackingArea.x2 = cast(short)(track_left + track_width);
            output.initialTrackingArea.y2 = cast(short)(track_top + track_height);
            /* fall through */
            goto case;
        case 4:
            output.initialTotalArea.x1 = cast(short)left;
            output.initialTotalArea.y1 = cast(short)top;
            /* fall through */
            goto case;
        case 2:
            output.initialTotalArea.x2 = cast(short)(output.initialTotalArea.x1 + width);
            output.initialTotalArea.y2 = cast(short)(output.initialTotalArea.y1 + height);
            break;
        default:
            xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                       "Broken panning specification '%s' for output %s in config file\n",
                       panning, output.name);
        }
    }
}

/** Return - 0 + if a should be earlier, same or later than b in list
 */
private int xf86ModeCompare(DisplayModePtr a, DisplayModePtr b)
{
    int diff = void;

    diff = ((b.type & M_T_PREFERRED) != 0) - ((a.type & M_T_PREFERRED) != 0);
    if (diff)
        return diff;
    diff = b.HDisplay * b.VDisplay - a.HDisplay * a.VDisplay;
    if (diff)
        return diff;
    diff = b.Clock - a.Clock;
    return diff;
}

/**
 * Insertion sort input in-place and return the resulting head
 */
private DisplayModePtr xf86SortModes(DisplayModePtr input)
{
    DisplayModePtr output = null, i = void, o = void, n = void; DisplayModePtr* op = void; DisplayModePtr prev = void;

    /* sort by preferred status and pixel area */
    while (input) {
        i = input;
        input = input.next;
        for (op = &output; ((o = *op) !is null); op = &o.next)
            if (xf86ModeCompare(o, i) > 0)
                break;
        i.next = *op;
        *op = i;
    }
    /* prune identical modes */
    for (o = output; o && (n = o.next) !is null; o = n) {
        if (!strcmp(o.name, n.name) && xf86ModesEqual(o, n)) {
            o.next = n.next;
            free(cast(void*) n.name);
            free(n);
            n = o;
        }
    }
    /* hook up backward links */
    prev = null;
    for (o = output; o; o = o.next) {
        o.prev = prev;
        prev = o;
    }
    return output;
}

private const(char)* preferredMode(ScrnInfoPtr pScrn, xf86OutputPtr output)
{
    const(char)* preferred_mode = null;

    /* Check for a configured preference for a particular mode */
    preferred_mode = xf86GetOptValString(output.options,
                                         OPTION_PREFERRED_MODE);
    if (preferred_mode)
        return preferred_mode;

    if (pScrn.display.modes && *pScrn.display.modes)
        preferred_mode = *pScrn.display.modes;

    return preferred_mode;
}

/** identify a token
 * args
 *   *src     a string with zero or more tokens, e.g. "tok0 tok1",
 *   **token  stores a pointer to the first token character,
 *   *len     stores the token length.
 * return
 *   a pointer into src[] at the token terminating character, or
 *   NULL if no token is found.
 */
private const(char)* gettoken(const(char)* src, const(char)** token, int* len)
{
    const(char)* delim = " \t";
    int skip = void;

    if (!src)
        return null;

    skip = cast(int)strspn(src, delim);
    *token = &src[skip];

    *len = cast(int)strcspn(*token, delim);
    /* Support for backslash escaped delimiters could be implemented
     * here.
     */

    /* (*token)[0] != '\0'  <==>  *len > 0 */
    if (*len > 0)
        return &(*token)[*len];
    else
        return null;
}

/** Check for a user configured zoom mode list, Option "ZoomModes":
 *
 * Section "Monitor"
 *   Identifier "a21inch"
 *   Option "ZoomModes" "1600x1200 1280x1024 1280x1024 640x480"
 * EndSection
 *
 * Each user mode name is searched for independently so the list
 * specification order is free.  An output mode is matched at most
 * once, a mode with an already set M_T_USERDEF type bit is skipped.
 * Thus a repeat mode name specification matches the next output mode
 * with the same name.
 *
 * Ctrl+Alt+Keypad-{Plus,Minus} zooms {in,out} by selecting the
 * {next,previous} M_T_USERDEF mode in the screen modes list, itself
 * sorted toward lower dot area or lower dot clock frequency, see
 *   modes/xf86Crtc.c: xf86SortModes() xf86SetScrnInfoModes(), and
 *   common/xf86Cursor.c: xf86ZoomViewport().
 */
private int processZoomModes(xf86OutputPtr output)
{
    const(char)* zoom_modes = void;
    int count = 0;

    zoom_modes = xf86GetOptValString(output.options, OPTION_ZOOM_MODES);

    if (zoom_modes) {
        const(char)* token = void, next = void;
        int len = void;

        next = gettoken(zoom_modes, &token, &len);
        while (next) {
            DisplayModePtr mode = void;

            for (mode = output.probed_modes; mode; mode = mode.next)
                if (!strncmp(token, mode.name, len)  /* prefix match */
                    && mode.name[len] == '\0'        /* equal length */
                    && !(mode.type & M_T_USERDEF)) { /* no rematch */
                    mode.type |= M_T_USERDEF;
                    break;
                }

            count++;
            next = gettoken(next, &token, &len);
        }
    }

    return count;
}

private void GuessRangeFromModes(MonPtr mon, DisplayModePtr mode)
{
    if (!mon || !mode)
        return;

    mon.nHsync = 1;
    mon.hsync[0].lo = 1024.0;
    mon.hsync[0].hi = 0.0;

    mon.nVrefresh = 1;
    mon.vrefresh[0].lo = 1024.0;
    mon.vrefresh[0].hi = 0.0;

    while (mode) {
        if (!mode.HSync)
            mode.HSync = (cast(float) mode.Clock) / (cast(float) mode.HTotal);

        if (!mode.VRefresh)
            mode.VRefresh = (1000.0 * (cast(float) mode.Clock)) /
                (cast(float) (mode.HTotal * mode.VTotal));

        if (mode.HSync < mon.hsync[0].lo)
            mon.hsync[0].lo = mode.HSync;

        if (mode.HSync > mon.hsync[0].hi)
            mon.hsync[0].hi = mode.HSync;

        if (mode.VRefresh < mon.vrefresh[0].lo)
            mon.vrefresh[0].lo = mode.VRefresh;

        if (mode.VRefresh > mon.vrefresh[0].hi)
            mon.vrefresh[0].hi = mode.VRefresh;

        mode = mode.next;
    }

    /* stretch out the bottom to fit 640x480@60 */
    if (mon.hsync[0].lo > 31.0)
        mon.hsync[0].lo = 31.0;
    if (mon.vrefresh[0].lo > 58.0)
        mon.vrefresh[0].lo = 58.0;
}

enum det_monrec_source {
    sync_config, sync_edid, sync_default
}
alias sync_config = det_monrec_source.sync_config;
alias sync_edid = det_monrec_source.sync_edid;
alias sync_default = det_monrec_source.sync_default;
;

struct det_monrec_parameter {
    MonRec* mon_rec;
    int* max_clock;
    Bool set_hsync;
    Bool set_vrefresh;
    det_monrec_source* sync_source;
};

private void handle_detailed_monrec(detailed_monitor_section* det_mon, void* data)
{
    det_monrec_parameter* p = void;

    p = cast(det_monrec_parameter*) data;

    if (det_mon.type == DS_RANGES) {
        monitor_ranges* ranges = &det_mon.section.ranges;

        if (p.set_hsync && ranges.max_h) {
            p.mon_rec.hsync[p.mon_rec.nHsync].lo = ranges.min_h;
            p.mon_rec.hsync[p.mon_rec.nHsync].hi = ranges.max_h;
            p.mon_rec.nHsync++;
            if (*p.sync_source == sync_default)
                *p.sync_source = sync_edid;
        }
        if (p.set_vrefresh && ranges.max_v) {
            p.mon_rec.vrefresh[p.mon_rec.nVrefresh].lo = ranges.min_v;
            p.mon_rec.vrefresh[p.mon_rec.nVrefresh].hi = ranges.max_v;
            p.mon_rec.nVrefresh++;
            if (*p.sync_source == sync_default)
                *p.sync_source = sync_edid;
        }
        if (ranges.max_clock * 1000 > *p.max_clock)
            *p.max_clock = ranges.max_clock * 1000;
    }
}

void xf86ProbeOutputModes(ScrnInfoPtr scrn, int maxX, int maxY)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;

    /* When canGrow was TRUE in the initial configuration we have to
     * compare against the maximum values so that we don't drop modes.
     * When canGrow was FALSE, the maximum values would have been clamped
     * anyway.
     */
    if (maxX == 0 || maxY == 0) {
        maxX = config.maxWidth;
        maxY = config.maxHeight;
    }

    /* Probe the list of modes for each output. */
    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];
        DisplayModePtr mode = void;
        DisplayModePtr config_modes = null, output_modes = void, default_modes = null;
        const(char)* preferred_mode = void;
        xf86MonPtr edid_monitor = void;
        XF86ConfMonitorPtr conf_monitor = void;
        MonRec mon_rec = void;
        int min_clock = 0;
        int max_clock = 0;
        double clock = void;
        Bool add_default_modes = void;
        Bool debug_modes = config.debug_modes || xf86Initialising;
        det_monrec_source sync_source = sync_default;

        while (output.probed_modes !is null)
            xf86DeleteMode(&output.probed_modes, output.probed_modes);

        /*
         * Check connection status
         */
        output.status = (*output.funcs.detect) (output);

        if (output.status == XF86OutputStatusDisconnected &&
            !xf86ReturnOptValBool(output.options, OPTION_ENABLE, FALSE)) {
            xf86OutputSetEDID(output, null);
            continue;
        }

        memset(&mon_rec, '\0', mon_rec.sizeof);

        conf_monitor = output.conf_monitor;

        if (conf_monitor) {
            int i = void;

            for (i = 0; i < conf_monitor.mon_n_hsync; i++) {
                mon_rec.hsync[mon_rec.nHsync].lo =
                    conf_monitor.mon_hsync[i].lo;
                mon_rec.hsync[mon_rec.nHsync].hi =
                    conf_monitor.mon_hsync[i].hi;
                mon_rec.nHsync++;
                sync_source = sync_config;
            }
            for (i = 0; i < conf_monitor.mon_n_vrefresh; i++) {
                mon_rec.vrefresh[mon_rec.nVrefresh].lo =
                    conf_monitor.mon_vrefresh[i].lo;
                mon_rec.vrefresh[mon_rec.nVrefresh].hi =
                    conf_monitor.mon_vrefresh[i].hi;
                mon_rec.nVrefresh++;
                sync_source = sync_config;
            }
            config_modes = xf86GetMonitorModes(scrn, conf_monitor);
        }

        output_modes = (*output.funcs.get_modes) (output);

        /*
         * If the user has a preference, respect it.
         * Otherwise, don't second-guess the driver.
         */
        if (!xf86GetOptValBool(output.options, OPTION_DEFAULT_MODES,
                               &add_default_modes))
            add_default_modes = (output_modes is null);

        edid_monitor = output.MonInfo;

        if (edid_monitor) {
            det_monrec_parameter p = void;
            cea_data_block* hdmi_db = void;

            /* if display is not continuous-frequency, don't add default modes */
            if (!gtf_supported(edid_monitor))
                add_default_modes = FALSE;

            p.mon_rec = &mon_rec;
            p.max_clock = &max_clock;
            p.set_hsync = mon_rec.nHsync == 0;
            p.set_vrefresh = mon_rec.nVrefresh == 0;
            p.sync_source = &sync_source;

            xf86ForEachDetailedBlock(edid_monitor, &handle_detailed_monrec, &p);

            /* Look at the CEA HDMI vendor block for the max TMDS freq */
            hdmi_db = xf86MonitorFindHDMIBlock(edid_monitor);
            if (hdmi_db && hdmi_db.len >= 7) {
                int tmds_freq = hdmi_db.u.vendor.hdmi.max_tmds_clock * 5000;
                xf86DrvMsg(scrn.scrnIndex, X_PROBED,
                           "HDMI max TMDS frequency %dKHz\n", tmds_freq);
                if (tmds_freq > max_clock)
                    max_clock = tmds_freq;
            }
        }

        if (xf86GetOptValFreq(output.options, OPTION_MIN_CLOCK,
                              OPTUNITS_KHZ, &clock))
            min_clock = cast(int) clock;
        if (xf86GetOptValFreq(output.options, OPTION_MAX_CLOCK,
                              OPTUNITS_KHZ, &clock))
            max_clock = cast(int) clock;

        /* If we still don't have a sync range, guess wildly */
        if (!mon_rec.nHsync || !mon_rec.nVrefresh)
            GuessRangeFromModes(&mon_rec, output_modes);

        /*
         * These limits will end up setting a 1024x768@60Hz mode by default,
         * which seems like a fairly good mode to use when nothing else is
         * specified
         */
        if (mon_rec.nHsync == 0) {
            mon_rec.hsync[0].lo = 31.0;
            mon_rec.hsync[0].hi = 55.0;
            mon_rec.nHsync = 1;
        }
        if (mon_rec.nVrefresh == 0) {
            mon_rec.vrefresh[0].lo = 58.0;
            mon_rec.vrefresh[0].hi = 62.0;
            mon_rec.nVrefresh = 1;
        }

        if (add_default_modes)
            default_modes = xf86GetDefaultModes();

        /*
         * If this is not an RB monitor, remove RB modes from the default
         * pool.  RB modes from the config or the monitor itself are fine.
         */
        if (!mon_rec.reducedblanking)
            xf86ValidateModesReducedBlanking(scrn, default_modes);

        if (sync_source == sync_config) {
            /*
             * Check output and config modes against sync range from config file
             */
            xf86ValidateModesSync(scrn, output_modes, &mon_rec);
            xf86ValidateModesSync(scrn, config_modes, &mon_rec);
        }
        /*
         * Check default modes against sync range
         */
        xf86ValidateModesSync(scrn, default_modes, &mon_rec);
        /*
         * Check default modes against monitor max clock
         */
        if (max_clock) {
            xf86ValidateModesClocks(scrn, default_modes,
                                    &min_clock, &max_clock, 1);
            xf86ValidateModesClocks(scrn, output_modes,
                                    &min_clock, &max_clock, 1);
        }

        output.probed_modes = null;
        output.probed_modes = xf86ModesAdd(output.probed_modes, config_modes);
        output.probed_modes = xf86ModesAdd(output.probed_modes, output_modes);
        output.probed_modes =
            xf86ModesAdd(output.probed_modes, default_modes);

        /*
         * Check all modes against max size, interlace, and doublescan
         */
        if (maxX && maxY)
            xf86ValidateModesSize(scrn, output.probed_modes, maxX, maxY, 0);

        {
            int flags = (output.interlaceAllowed ? V_INTERLACE : 0) |
                (output.doubleScanAllowed ? V_DBLSCAN : 0);
            xf86ValidateModesFlags(scrn, output.probed_modes, flags);
        }

        /*
         * Check all modes against output
         */
        for (mode = output.probed_modes; mode !is null; mode = mode.next)
            if (mode.status == MODE_OK)
                mode.status = cast(ModeStatus)(*output.funcs.mode_valid) (output, mode);

        xf86PruneInvalidModes(scrn, &output.probed_modes, debug_modes);

        output.probed_modes = xf86SortModes(output.probed_modes);

        /* Check for a configured preference for a particular mode */
        preferred_mode = preferredMode(scrn, output);

        if (preferred_mode) {
            for (mode = output.probed_modes; mode; mode = mode.next) {
                if (!strcmp(preferred_mode, mode.name)) {
                    if (mode != output.probed_modes) {
                        if (mode.prev)
                            mode.prev.next = mode.next;
                        if (mode.next)
                            mode.next.prev = mode.prev;
                        mode.next = output.probed_modes;
                        output.probed_modes.prev = mode;
                        mode.prev = null;
                        output.probed_modes = mode;
                    }
                    mode.type |= (M_T_PREFERRED | M_T_USERPREF);
                    break;
                }
            }
        }

        /* Ctrl+Alt+Keypad-{Plus,Minus} zoom mode: M_T_USERDEF mode type */
        processZoomModes(output);

        output.initial_rotation = xf86OutputInitialRotation(output);

        if (debug_modes) {
            if (output.probed_modes !is null) {
                xf86DrvMsg(scrn.scrnIndex, X_INFO,
                           "Printing probed modes for output %s\n",
                           output.name);
            }
            else {
                xf86DrvMsg(scrn.scrnIndex, X_INFO,
                           "No remaining probed modes for output %s\n",
                           output.name);
            }
        }
        for (mode = output.probed_modes; mode !is null; mode = mode.next) {
            /* The code to choose the best mode per pipe later on will require
             * VRefresh to be set.
             */
            mode.VRefresh = xf86ModeVRefresh(mode);
            xf86SetModeCrtc(mode, INTERLACE_HALVE_V);

            if (debug_modes)
                xf86PrintModeline(scrn.scrnIndex, mode);
        }
    }
}

/**
 * Copy one of the output mode lists to the ScrnInfo record
 */

private DisplayModePtr biggestMode(DisplayModePtr a, DisplayModePtr b)
{
    int A = void, B = void;

    if (!a)
        return b;
    if (!b)
        return a;

    A = a.HDisplay * a.VDisplay;
    B = b.HDisplay * b.VDisplay;

    if (A > B)
        return a;

    return b;
}

private xf86OutputPtr SetCompatOutput(xf86CrtcConfigPtr config)
{
    xf86OutputPtr output = null, test = null;
    DisplayModePtr maxmode = null, testmode = void, mode = void;
    int o = void, compat = -1, count = void, mincount = 0;

    if (config.num_output == 0)
        return null;

    /* Look for one that's definitely connected */
    for (o = 0; o < config.num_output; o++) {
        test = config.output[o];
        if (!test.crtc)
            continue;
        if (test.status != XF86OutputStatusConnected)
            continue;
        if (!test.probed_modes)
            continue;

        testmode = mode = test.probed_modes;
        for (count = 0; mode; mode = mode.next, count++)
            testmode = biggestMode(testmode, mode);

        if (!output) {
            output = test;
            compat = o;
            maxmode = testmode;
            mincount = count;
        }
        else if (maxmode == biggestMode(maxmode, testmode)) {
            output = test;
            compat = o;
            maxmode = testmode;
            mincount = count;
        }
        else if ((maxmode.HDisplay == testmode.HDisplay) &&
                 (maxmode.VDisplay == testmode.VDisplay) &&
                 count <= mincount) {
            output = test;
            compat = o;
            maxmode = testmode;
            mincount = count;
        }
    }

    /* If we didn't find one, take anything we can get */
    if (!output) {
        for (o = 0; o < config.num_output; o++) {
            test = config.output[o];
            if (!test.crtc)
                continue;
            if (!test.probed_modes)
                continue;

            if (!output) {
                output = test;
                compat = o;
            }
            else if (test.probed_modes.HDisplay <
                     output.probed_modes.HDisplay) {
                output = test;
                compat = o;
            }
        }
    }

    if (compat >= 0) {
        config.compat_output = compat;
    }
    else if (config.compat_output >= 0 && config.compat_output < config.num_output) {
        /* Don't change the compat output when no valid outputs found */
        output = config.output[config.compat_output];
    }

    /* All outputs are disconnected, select one to fake */
    if (!output && config.num_output) {
        config.compat_output = 0;
        output = config.output[config.compat_output];
    }

    return output;
}

void xf86SetScrnInfoModes(ScrnInfoPtr scrn)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    xf86OutputPtr output = void;
    xf86CrtcPtr crtc = void;
    DisplayModePtr last = void, mode = null;

    output = SetCompatOutput(config);

    if (!output)
        return;                 /* punt */

    crtc = output.crtc;

    /* Clear any existing modes from scrn->modes */
    while (scrn.modes !is null)
        xf86DeleteMode(&scrn.modes, scrn.modes);

    /* Set scrn->modes to the mode list for the 'compat' output */
    scrn.modes = xf86DuplicateModes(scrn, output.probed_modes);

    if (crtc) {
        for (mode = scrn.modes; mode; mode = mode.next)
            if (xf86ModesEqual(mode, &crtc.desiredMode))
                break;
    }

    if (!scrn.modes) {
        scrn.modes = xf86ModesAdd(scrn.modes,
                                   xf86CVTMode(scrn.display.virtualX,
                                               scrn.display.virtualY,
                                               60, 0, 0));
    }

    /* For some reason, scrn->modes is circular, unlike the other mode
     * lists.  How great is that?
     */
    for (last = scrn.modes; last && last.next; last = last.next){}
    last.next = scrn.modes;
    scrn.modes.prev = last;
    if (mode) {
        while (scrn.modes != mode)
            scrn.modes = scrn.modes.next;
    }

    scrn.currentMode = scrn.modes;
static if(XFreeXDGA){
    if (scrn.pScreen)
        _xf86_di_dga_reinit_internal(scrn.pScreen);
}
}

private Bool xf86CollectEnabledOutputs(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, Bool* enabled)
{
    Bool any_enabled = FALSE;
    int o = void;

    /*
     * Don't bother enabling outputs on GPU screens: a client needs to attach
     * it to a source provider before setting a mode that scans out a shared
     * pixmap.
     */
    if (scrn.is_gpu)
        return FALSE;

    for (o = 0; o < config.num_output; o++)
        any_enabled |= enabled[o] = xf86OutputEnabled(config.output[o], TRUE);

    if (!any_enabled) {
        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                   "No outputs definitely connected, trying again...\n");

        for (o = 0; o < config.num_output; o++)
            any_enabled |= enabled[o] =
                xf86OutputEnabled(config.output[o], FALSE);
    }

    return any_enabled;
}

private Bool nextEnabledOutput(xf86CrtcConfigPtr config, Bool* enabled, int* index)
{
    int o = *index;

    for (o++; o < config.num_output; o++) {
        if (enabled[o]) {
            *index = o;
            return TRUE;
        }
    }

    return FALSE;
}

private Bool aspectMatch(float a, float b)
{
    return fabs(1 - (a / b)) < 0.05;
}

private DisplayModePtr nextAspectMode(xf86OutputPtr o, DisplayModePtr last, float aspect)
{
    DisplayModePtr m = null;

    if (!o)
        return null;

    if (!last)
        m = o.probed_modes;
    else
        m = last.next;

    for (; m; m = m.next)
        if (aspectMatch(aspect, cast(float) m.HDisplay / cast(float) m.VDisplay))
            return m;

    return null;
}

private DisplayModePtr bestModeForAspect(xf86CrtcConfigPtr config, Bool* enabled, float aspect)
{
    int o = -1, p = void;
    DisplayModePtr mode = null, test = null, match = null;

    if (!nextEnabledOutput(config, enabled, &o))
        return null;
    while ((mode = nextAspectMode(config.output[o], mode, aspect)) !is null) {
        test = mode;
        for (p = o; nextEnabledOutput(config, enabled, &p);) {
            test = xf86OutputFindClosestMode(config.output[p], mode);
            if (!test)
                break;
            if (test.HDisplay != mode.HDisplay ||
                test.VDisplay != mode.VDisplay) {
                test = null;
                break;
            }
        }

        /* if we didn't match it on all outputs, try the next one */
        if (!test)
            continue;

        /* if it's bigger than the last one, save it */
        if (!match || (test.HDisplay > match.HDisplay))
            match = test;
    }

    /* return the biggest one found */
    return match;
}

private int numEnabledOutputs(xf86CrtcConfigPtr config, Bool* enabled)
{
    int i = 0, p = void;

    for (i = 0, p = -1; nextEnabledOutput(config, enabled, &p); i++) {}

    return i;
}

private Bool xf86TargetRightOf(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, DisplayModePtr* modes, Bool* enabled, int width, int height)
{
    int o = void;
    int w = 0;
    Bool has_tile = FALSE;
    uint configured_outputs = void;

    xf86GetOptValBool(config.options, OPTION_PREFER_CLONEMODE,
                      &scrn.preferClone);
    if (scrn.preferClone)
        return FALSE;

    if (numEnabledOutputs(config, enabled) < 2)
        return FALSE;

    for (o = -1; nextEnabledOutput(config, enabled, &o); ) {
        DisplayModePtr mode = xf86OutputHasPreferredMode(config.output[o], width, height);

        if (!mode)
            return FALSE;

        w += mode.HDisplay;
    }

    if (w > width)
        return FALSE;

    w = 0;
    configured_outputs = 0;

    for (o = -1; nextEnabledOutput(config, enabled, &o); ) {
        DisplayModePtr mode = xf86OutputHasPreferredMode(config.output[o], width, height);

        if (configured_outputs & (1 << o))
            continue;

        if (config.output[o].tile_info.group_id) {
            has_tile = TRUE;
            continue;
        }

        config.output[o].initial_x = w;
        w += mode.HDisplay;

        configured_outputs |= (1 << o);
        modes[o] = mode;
    }

    if (has_tile) {
        for (o = -1; nextEnabledOutput(config, enabled, &o); ) {
            int ht = void, vt = void, ot = void;
            int add_x = void, cur_x = w;
            xf86CrtcTileInfo* tile_info = &config.output[o].tile_info, this_tile = void;
            if (configured_outputs & (1 << o))
                continue;
            if (!tile_info.group_id)
                continue;

            if (tile_info.tile_h_loc != 0 && tile_info.tile_v_loc != 0)
                continue;

            for (ht = 0; ht < tile_info.num_h_tile; ht++) {
                int cur_y = 0;
                add_x = 0;
                for (vt = 0; vt < tile_info.num_v_tile; vt++) {

                    for (ot = -1; nextEnabledOutput(config, enabled, &ot); ) {

                        DisplayModePtr mode = xf86OutputHasPreferredMode(config.output[ot], width, height);
                        if (!config.output[ot].tile_info.group_id)
                            continue;

                        this_tile = &config.output[ot].tile_info;
                        if (this_tile.group_id != tile_info.group_id)
                            continue;

                        if (this_tile.tile_h_loc != ht ||
                            this_tile.tile_v_loc != vt)
                            continue;

                        config.output[ot].initial_x = cur_x;
                        config.output[ot].initial_y = cur_y;

                        if (vt == 0)
                            add_x = this_tile.tile_h_size;
                        cur_y += this_tile.tile_v_size;
                        configured_outputs |= (1 << ot);
                        modes[ot] = mode;
                    }
                }
                cur_x += add_x;
            }
            w = cur_x;
        }
    }
    return TRUE;
}

private Bool xf86TargetPreferred(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, DisplayModePtr* modes, Bool* enabled, int width, int height)
{
    int o = void, p = void;
    int max_pref_width = 0, max_pref_height = 0;
    DisplayModePtr* preferred = void, preferred_match = void;
    Bool ret = FALSE;

    preferred = cast(_DisplayModeRec**)XNFcallocarray(config.num_output, DisplayModePtr.sizeof);
    preferred_match = cast(_DisplayModeRec**)XNFcallocarray(config.num_output, DisplayModePtr.sizeof);

    /* Check if the preferred mode is available on all outputs */
    for (p = -1; nextEnabledOutput(config, enabled, &p);) {
        Rotation r = config.output[p].initial_rotation;
        DisplayModePtr mode = void;

        if ((preferred[p] = xf86OutputHasPreferredMode(config.output[p],
                                                       width, height)) !is null) {
            int pref_width = xf86ModeWidth(preferred[p], r);
            int pref_height = xf86ModeHeight(preferred[p], r);
            Bool all_match = TRUE;

            for (o = -1; nextEnabledOutput(config, enabled, &o);) {
                Bool match = FALSE;
                xf86OutputPtr output = config.output[o];

                if (o == p)
                    continue;

                /*
                 * First see if the preferred mode matches on the next
                 * output as well.  This catches the common case of identical
                 * monitors and makes sure they all have the same timings
                 * and refresh.  If that fails, we fall back to trying to
                 * match just width & height.
                 */
                mode = xf86OutputHasPreferredMode(output, pref_width,
                                                  pref_height);
                if (mode && xf86ModesEqual(mode, preferred[p])) {
                    preferred[o] = mode;
                    match = TRUE;
                }
                else {
                    for (mode = output.probed_modes; mode; mode = mode.next) {
                        Rotation ir = output.initial_rotation;

                        if (xf86ModeWidth(mode, ir) == pref_width &&
                            xf86ModeHeight(mode, ir) == pref_height) {
                            preferred[o] = mode;
                            match = TRUE;
                        }
                    }
                }

                all_match &= match;
            }

            if (all_match &&
                (pref_width * pref_height > max_pref_width * max_pref_height)) {
                for (o = -1; nextEnabledOutput(config, enabled, &o);)
                    preferred_match[o] = preferred[o];
                max_pref_width = pref_width;
                max_pref_height = pref_height;
                ret = TRUE;
            }
        }
    }

    /*
     * If there's no preferred mode, but only one monitor, pick the
     * biggest mode for its aspect ratio or 4:3, assuming one exists.
     */
    if (!ret)
        do {
            float aspect = 0.0;
            DisplayModePtr a = null, b = null;

            if (numEnabledOutputs(config, enabled) != 1)
                break;

            p = -1;
            nextEnabledOutput(config, enabled, &p);
            if (config.output[p].mm_height)
                aspect = cast(float) config.output[p].mm_width /
                    cast(float) config.output[p].mm_height;

            a = bestModeForAspect(config, enabled, 4.0/3.0);
            if (aspect)
                b = bestModeForAspect(config, enabled, aspect);

            preferred_match[p] = biggestMode(a, b);

            if (preferred_match[p])
                ret = TRUE;

        } while (0);

    if (ret) {
        /* oh good, there is a match.  stash the selected modes and return. */
        memcpy(modes, preferred_match,
               config.num_output * DisplayModePtr.sizeof);
    }

    free(preferred);
    free(preferred_match);
    return ret;
}

private Bool xf86TargetAspect(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, DisplayModePtr* modes, Bool* enabled, int width, int height)
{
    int o = void;
    float aspect = 0.0; float* aspects = void;
    xf86OutputPtr output = void;
    Bool ret = FALSE;
    DisplayModePtr guess = null, aspect_guess = null, base_guess = null;

    aspects = cast(float*)XNFcallocarray(config.num_output, float.sizeof);

    /* collect the aspect ratios */
    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        output = config.output[o];
        if (output.mm_height)
            aspects[o] = cast(float) output.mm_width / cast(float) output.mm_height;
        else
            aspects[o] = 4.0 / 3.0;
    }

    /* check that they're all the same */
    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        output = config.output[o];
        if (!aspect) {
            aspect = aspects[o];
        }
        else if (!aspectMatch(aspect, aspects[o])) {
            goto no_aspect_match;
        }
    }

    /* if they're all 4:3, just skip ahead and save effort */
    if (!aspectMatch(aspect, 4.0 / 3.0))
        aspect_guess = bestModeForAspect(config, enabled, aspect);

 no_aspect_match:
    base_guess = bestModeForAspect(config, enabled, 4.0 / 3.0);

    guess = biggestMode(base_guess, aspect_guess);

    if (!guess)
        goto out_;

    /* found a mode that works everywhere, now apply it */
    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        modes[o] = xf86OutputFindClosestMode(config.output[o], guess);
    }
    ret = TRUE;

 out_:
    free(aspects);
    return ret;
}

private Bool xf86TargetFallback(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, DisplayModePtr* modes, Bool* enabled, int width, int height)
{
    DisplayModePtr target_mode = null;
    Rotation target_rotation = RR_Rotate_0;
    DisplayModePtr default_mode = void;
    int default_preferred = void, target_preferred = 0, o = void;

    /* User preferred > preferred > other modes */
    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        default_mode = xf86DefaultMode(config.output[o], width, height);
        if (!default_mode)
            continue;

        default_preferred = (((default_mode.type & M_T_PREFERRED) != 0) +
                             ((default_mode.type & M_T_USERPREF) != 0));

        if (default_preferred > target_preferred || !target_mode) {
            target_mode = default_mode;
            target_preferred = default_preferred;
            target_rotation = config.output[o].initial_rotation;
            config.compat_output = o;
        }
    }

    if (target_mode)
        modes[config.compat_output] = target_mode;

    /* Fill in other output modes */
    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        if (!modes[o])
            modes[o] = xf86ClosestMode(config.output[o], target_mode,
                                       target_rotation, width, height);
    }

    return target_mode !is null;
}

private Bool xf86TargetUserpref(ScrnInfoPtr scrn, xf86CrtcConfigPtr config, DisplayModePtr* modes, Bool* enabled, int width, int height)
{
    int o = void;

    if (xf86UserConfiguredOutputs(scrn, modes))
        return xf86TargetFallback(scrn, config, modes, enabled, width, height);

    for (o = -1; nextEnabledOutput(config, enabled, &o);)
        if (xf86OutputHasUserPreferredMode(config.output[o]))
            return
                xf86TargetFallback(scrn, config, modes, enabled, width, height);

    return FALSE;
}

void xf86AssignNoOutputInitialSize(ScrnInfoPtr scrn, const(OptionInfoRec)* options, int* no_output_width, int* no_output_height)
{
    int width = 0, height = 0;
    const(char)* no_output_size = xf86GetOptValString(options, OPTION_NO_OUTPUT_INITIAL_SIZE);

    *no_output_width = NO_OUTPUT_DEFAULT_WIDTH;
    *no_output_height = NO_OUTPUT_DEFAULT_HEIGHT;

    if (no_output_size is null) {
        return;
    }

    if (sscanf(no_output_size, "%d %d", &width, &height) != 2) {
        xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                   "\"NoOutputInitialSize\" string \"%s\" not of form "
                   ~ "\"width height\"\n", no_output_size);
        return;
    }

    *no_output_width = width;
    *no_output_height = height;
}

/**
 * Construct default screen configuration
 *
 * Given auto-detected (and, eventually, configured) values,
 * construct a usable configuration for the system
 *
 * canGrow indicates that the driver can resize the screen to larger than its
 * initially configured size via the config->funcs->resize hook.  If TRUE, this
 * function will set virtualX and virtualY to match the initial configuration
 * and leave config->max{Width,Height} alone.  If FALSE, it will bloat
 * virtual[XY] to include the largest modes and set config->max{Width,Height}
 * accordingly.
 */

Bool xf86InitialConfiguration(ScrnInfoPtr scrn, Bool canGrow)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void, c = void;
    xf86CrtcPtr* crtcs = void;
    DisplayModePtr* modes = void;
    Bool* enabled = void;
    int width = void, height = void;
    int no_output_width = void, no_output_height = void;
    int i = scrn.scrnIndex;
    Bool have_outputs = TRUE;
    Bool ret = void;
    Bool success = FALSE;

    /* Set up the device options */
    config.options = cast(_OptionInfoRec*)XNFalloc(xf86DeviceOptions.sizeof);
    memcpy(config.options, xf86DeviceOptions.ptr, xf86DeviceOptions.sizeof);
    xf86ProcessOptions(scrn.scrnIndex, cast(_InputOption*)scrn.options, config.options);
    config.debug_modes = xf86ReturnOptValBool(config.options,
                                               OPTION_MODEDEBUG, FALSE);

    if (scrn.display.virtualX && !scrn.is_gpu)
        width = scrn.display.virtualX;
    else
        width = config.maxWidth;
    if (scrn.display.virtualY && !scrn.is_gpu)
        height = scrn.display.virtualY;
    else
        height = config.maxHeight;

    xf86AssignNoOutputInitialSize(scrn, config.options,
                                  &no_output_width, &no_output_height);

    xf86ProbeOutputModes(scrn, width, height);

    crtcs = cast(_xf86Crtc**)XNFcallocarray(config.num_output, xf86CrtcPtr.sizeof);
    modes = cast(_DisplayModeRec**)XNFcallocarray(config.num_output, DisplayModePtr.sizeof);
    enabled = cast(int*)XNFcallocarray(config.num_output, Bool.sizeof);

    ret = xf86CollectEnabledOutputs(scrn, config, enabled);
    if (ret == FALSE && canGrow) {
        if (!scrn.is_gpu)
            xf86DrvMsg(i, X_WARNING,
		       "Unable to find connected outputs - setting %dx%d "
                       ~ "initial framebuffer\n",
                       no_output_width, no_output_height);
        have_outputs = FALSE;
    }
    else {
        if (xf86TargetUserpref(scrn, config, modes, enabled, width, height))
            xf86DrvMsg(i, X_INFO, "Using user preference for initial modes\n");
        else if (xf86TargetRightOf(scrn, config, modes, enabled, width, height))
            xf86DrvMsg(i, X_INFO, "Using spanning desktop for initial modes\n");
        else if (xf86TargetPreferred
                 (scrn, config, modes, enabled, width, height))
            xf86DrvMsg(i, X_INFO, "Using exact sizes for initial modes\n");
        else if (xf86TargetAspect(scrn, config, modes, enabled, width, height))
            xf86DrvMsg(i, X_INFO,
                       "Using fuzzy aspect match for initial modes\n");
        else if (xf86TargetFallback
                 (scrn, config, modes, enabled, width, height))
            xf86DrvMsg(i, X_INFO, "Using sloppy heuristic for initial modes\n");
        else
            xf86DrvMsg(i, X_WARNING, "Unable to find initial modes\n");
    }

    for (o = -1; nextEnabledOutput(config, enabled, &o);) {
        if (!modes[o])
            xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                       "Output %s enabled but has no modes\n",
                       config.output[o].name);
        else
            xf86DrvMsg (scrn.scrnIndex, X_INFO,
                        "Output %s using initial mode %s +%d+%d\n",
                        config.output[o].name, modes[o].name,
                        config.output[o].initial_x,
                        config.output[o].initial_y);
    }

    /*
     * Set the position of each output
     */
    if (!xf86InitialOutputPositions(scrn, modes))
        goto bailout;

    /*
     * Set initial panning of each output
     */
    xf86InitialPanning(scrn);

    /*
     * Assign CRTCs to fit output configuration
     */
    if (have_outputs && !xf86PickCrtcs(scrn, crtcs, modes, 0, width, height))
        goto bailout;

    /* XXX override xf86 common frame computation code */

    if (!scrn.is_gpu) {
        scrn.display.frameX0 = 0;
        scrn.display.frameY0 = 0;
    }

    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];

        crtc.enabled = FALSE;
        memset(&crtc.desiredMode, '\0', typeof(crtc.desiredMode).sizeof);
    }

    /*
     * Set initial configuration
     */
    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];
        DisplayModePtr mode = modes[o];
        xf86CrtcPtr crtc = crtcs[o];

        if (mode && crtc) {
            xf86SaveModeContents(&crtc.desiredMode, mode);
            crtc.desiredRotation = output.initial_rotation;
            crtc.desiredX = output.initial_x;
            crtc.desiredY = output.initial_y;
            crtc.desiredTransformPresent = FALSE;
            crtc.enabled = TRUE;
            memcpy(&crtc.panningTotalArea, &output.initialTotalArea,
                   BoxRec.sizeof);
            memcpy(&crtc.panningTrackingArea, &output.initialTrackingArea,
                   BoxRec.sizeof);
            memcpy(crtc.panningBorder.ptr, output.initialBorder.ptr,
                   4 * INT16.sizeof);
            output.crtc = crtc;
        }
        else {
            output.crtc = null;
        }
    }

    if (scrn.display.virtualX == 0 || scrn.is_gpu) {
        /*
         * Expand virtual size to cover the current config and potential mode
         * switches, if the driver can't enlarge the screen later.
         */
        xf86DefaultScreenLimits(scrn, &width, &height, canGrow);

        if (have_outputs == FALSE) {
            if (width < no_output_width &&
                height < no_output_height) {
                width = no_output_width;
                height = no_output_height;
            }
        }

	if (!scrn.is_gpu) {
            scrn.display.virtualX = width;
            scrn.display.virtualY = height;
	}
    }

    if (width > scrn.virtualX)
        scrn.virtualX = width;
    if (height > scrn.virtualY)
        scrn.virtualY = height;

    /*
     * Make sure the configuration isn't too small.
     */
    if (width < config.minWidth || height < config.minHeight)
        goto bailout;

    /*
     * Limit the crtc config to virtual[XY] if the driver can't grow the
     * desktop.
     */
    if (!canGrow) {
        xf86CrtcSetSizeRange(scrn, config.minWidth, config.minHeight,
                             width, height);
    }

    xf86SetScrnInfoModes(scrn);

    success = TRUE;
 bailout:
    free(crtcs);
    free(modes);
    free(enabled);
    return success;
}

/* Turn a CRTC off, using the DPMS function and disabling the cursor */
private void xf86DisableCrtc(xf86CrtcPtr crtc)
{
    if (xf86CrtcIsLeased(crtc))
        return;

    crtc.funcs.dpms(crtc, DPMSModeOff);
    xf86_crtc_hide_cursor(crtc);
}

/*
 * Check the CRTC we're going to map each output to vs. its current
 * CRTC.  If they don't match, we have to disable the output and the CRTC
 * since the driver will have to re-route things.
 */
private void xf86PrepareOutputs(ScrnInfoPtr scrn)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int o = void;

    for (o = 0; o < config.num_output; o++) {
        xf86OutputPtr output = config.output[o];

        if (xf86OutputIsLeased(output))
            continue;

static if (RANDR_GET_CRTC_INTERFACE) {
        /* Disable outputs that are unused or will be re-routed */
        if (!output.funcs.get_crtc ||
            output.crtc != assumeNoGC(output.funcs.get_crtc) (output) ||
            output.crtc is null)
            assumeNoGC(output.funcs.dpms) (output, DPMSModeOff);
}
else {
    assumeNoGC(output.funcs.dpms) (output, DPMSModeOff);
}
    }
}

private void xf86PrepareCrtcs(ScrnInfoPtr scrn)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int c = void;

    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];
static if (RANDR_GET_CRTC_INTERFACE) {
        xf86OutputPtr output = null;
        uint desired_outputs = 0, current_outputs = 0;
        int o = void;

        if (xf86CrtcIsLeased(crtc))
            continue;

        for (o = 0; o < config.num_output; o++) {
            output = config.output[o];
            if (output.crtc == crtc)
                desired_outputs |= (1 << o);
            /* If we can't tell where it's mapped, force it off */
            if (!output.funcs.get_crtc) {
                desired_outputs = 0;
                break;
            }
            if (assumeNoGC(output.funcs.get_crtc) (output) == crtc)
                current_outputs |= (1 << o);
        }

        /*
         * If mappings are different or the CRTC is unused,
         * we need to disable it
         */
        if (desired_outputs != current_outputs || !desired_outputs)
            xf86DisableCrtc(crtc);
} else {
        if (xf86CrtcIsLeased(crtc))
            continue;

        xf86DisableCrtc(crtc);
}
    }
}

/*
 * Using the desired mode information in each crtc, set
 * modes (used in EnterVT functions, or at server startup)
 */

Bool xf86SetDesiredModes(ScrnInfoPtr scrn)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    xf86CrtcPtr crtc = config.crtc[0];
    int enabled = 0, failed = 0;
    int c = void;

    /* A driver with this hook will take care of this */
    if (!crtc.funcs.set_mode_major) {
        xf86PrepareOutputs(scrn);
        xf86PrepareCrtcs(scrn);
    }

    for (c = 0; c < config.num_crtc; c++) {
        xf86OutputPtr output = null;
        int o = void;
        RRTransformPtr transform = void;

        crtc = config.crtc[c];

        /* Skip disabled CRTCs */
        if (!crtc.enabled)
            continue;

        if (xf86CompatOutput(scrn) && xf86CompatCrtc(scrn) == crtc)
            output = xf86CompatOutput(scrn);
        else {
            for (o = 0; o < config.num_output; o++)
                if (config.output[o].crtc == crtc) {
                    output = config.output[o];
                    break;
                }
        }
        /* paranoia */
        if (!output)
            continue;

        /* Mark that we'll need to re-set the mode for sure */
        memset(&crtc.mode, 0, typeof(crtc.mode).sizeof);
        if (!crtc.desiredMode.CrtcHDisplay) {
            DisplayModePtr mode = xf86OutputFindClosestMode(output, scrn.currentMode);

            if (!mode)
                return FALSE;
            xf86SaveModeContents(&crtc.desiredMode, mode);
            crtc.desiredRotation = RR_Rotate_0;
            crtc.desiredTransformPresent = FALSE;
            crtc.desiredX = 0;
            crtc.desiredY = 0;
        }

        if (crtc.desiredTransformPresent)
            transform = &crtc.desiredTransform;
        else
            transform = null;
        if (xf86CrtcSetModeTransform
            (crtc, &crtc.desiredMode, crtc.desiredRotation, transform,
             crtc.desiredX, crtc.desiredY)) {
            ++enabled;
        } else {
            for (o = 0; o < config.num_output; o++)
                if (config.output[o].crtc == crtc)
                    config.output[o].crtc = null;
            crtc.enabled = FALSE;
            ++failed;
	}
    }

    xf86DisableUnusedFunctions(scrn);
    return enabled != 0 || failed == 0;
}

/**
 * In the current world order, there are lists of modes per output, which may
 * or may not include the mode that was asked to be set by XFree86's mode
 * selection.  Find the closest one, in the following preference order:
 *
 * - Equality
 * - Closer in size to the requested mode, but no larger
 * - Closer in refresh rate to the requested mode.
 */

DisplayModePtr xf86OutputFindClosestMode(xf86OutputPtr output, DisplayModePtr desired)
{
    DisplayModePtr best = null, scan = null;

    for (scan = output.probed_modes; scan !is null; scan = scan.next) {
        /* If there's an exact match, we're done. */
        if (xf86ModesEqual(scan, desired)) {
            best = desired;
            break;
        }

        /* Reject if it's larger than the desired mode. */
        if (scan.HDisplay > desired.HDisplay ||
            scan.VDisplay > desired.VDisplay) {
            continue;
        }

        /*
         * If we haven't picked a best mode yet, use the first
         * one in the size range
         */
        if (best is null) {
            best = scan;
            continue;
        }

        /* Find if it's closer to the right size than the current best
         * option.
         */
        if ((scan.HDisplay > best.HDisplay &&
             scan.VDisplay >= best.VDisplay) ||
            (scan.HDisplay >= best.HDisplay &&
             scan.VDisplay > best.VDisplay)) {
            best = scan;
            continue;
        }

        /* Find if it's still closer to the right refresh than the current
         * best resolution.
         */
        if (scan.HDisplay == best.HDisplay &&
            scan.VDisplay == best.VDisplay &&
            (fabs(scan.VRefresh - desired.VRefresh) <
             fabs(best.VRefresh - desired.VRefresh))) {
            best = scan;
        }
    }
    return best;
}

/**
 * When setting a mode through XFree86-VidModeExtension or XFree86-DGA,
 * take the specified mode and apply it to the crtc connected to the compat
 * output. Then, find similar modes for the other outputs, as with the
 * InitialConfiguration code above. The goal is to clone the desired
 * mode across all outputs that are currently active.
 */

Bool xf86SetSingleMode(ScrnInfoPtr pScrn, DisplayModePtr desired, Rotation rotation)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    Bool ok = TRUE;
    xf86OutputPtr compat_output = void;
    DisplayModePtr compat_mode = null;
    int c = void;

    /*
     * Let the compat output drive the final mode selection
     */
    compat_output = xf86CompatOutput(pScrn);
    if (compat_output)
        compat_mode = xf86OutputFindClosestMode(compat_output, desired);
    if (compat_mode)
        desired = compat_mode;

    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];
        DisplayModePtr crtc_mode = null;
        int o = void;

        if (!crtc.enabled)
            continue;

        for (o = 0; o < config.num_output; o++) {
            xf86OutputPtr output = config.output[o];
            DisplayModePtr output_mode = void;

            /* skip outputs not on this crtc */
            if (output.crtc != crtc)
                continue;

            if (crtc_mode) {
                output_mode = xf86OutputFindClosestMode(output, crtc_mode);
                if (output_mode != crtc_mode)
                    output.crtc = null;
            }
            else
                crtc_mode = xf86OutputFindClosestMode(output, desired);
        }
        if (!crtc_mode) {
            crtc.enabled = FALSE;
            continue;
        }
        if (!xf86CrtcSetModeTransform(crtc, crtc_mode, rotation, null, 0, 0))
            ok = FALSE;
        else {
            xf86SaveModeContents(&crtc.desiredMode, crtc_mode);
            crtc.desiredRotation = rotation;
            crtc.desiredTransformPresent = FALSE;
            crtc.desiredX = 0;
            crtc.desiredY = 0;
        }
    }
    xf86DisableUnusedFunctions(pScrn);
static if (RANDR_12_INTERFACE) {
    xf86RandR12TellChanged(pScrn.pScreen);
}
    return ok;
}

/**
 * Set the DPMS power mode of all outputs and CRTCs.
 *
 * If the new mode is off, it will turn off outputs and then CRTCs.
 * Otherwise, it will affect CRTCs before outputs.
 */
void xf86DPMSSet(ScrnInfoPtr scrn, int mode, int flags)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int i = void;

    if (!scrn.vtSema)
        return;

    if (mode == DPMSModeOff) {
        for (i = 0; i < config.num_output; i++) {
            xf86OutputPtr output = config.output[i];

            if (!xf86OutputIsLeased(output) && output.crtc !is null)
                (*output.funcs.dpms) (output, mode);
        }
    }

    for (i = 0; i < config.num_crtc; i++) {
        xf86CrtcPtr crtc = config.crtc[i];

        if (crtc.enabled)
            (*crtc.funcs.dpms) (crtc, mode);
    }

    if (mode != DPMSModeOff) {
        for (i = 0; i < config.num_output; i++) {
            xf86OutputPtr output = config.output[i];

            if (!xf86OutputIsLeased(output) && output.crtc !is null)
                (*output.funcs.dpms) (output, mode);
        }
    }
}

/**
 * Implement the screensaver by just calling down into the driver DPMS hooks.
 *
 * Even for monitors with no DPMS support, by the definition of our DPMS hooks,
 * the outputs will still get disabled (blanked).
 */
Bool xf86SaveScreen(ScreenPtr pScreen, int mode)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    if (xf86IsUnblank(mode))
        xf86DPMSSet(pScrn, DPMSModeOn, 0);
    else
        xf86DPMSSet(pScrn, DPMSModeOff, 0);

    return TRUE;
}

/**
 * Disable all inactive crtcs and outputs
 */
void xf86DisableUnusedFunctions(ScrnInfoPtr pScrn)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int o = void, c = void;

    for (o = 0; o < xf86_config.num_output; o++) {
        xf86OutputPtr output = xf86_config.output[o];

        if (!output.crtc)
            (*output.funcs.dpms) (output, DPMSModeOff);
    }

    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr crtc = xf86_config.crtc[c];

        if (!crtc.enabled) {
            xf86DisableCrtc(crtc);
            memset(&crtc.mode, 0, typeof(crtc.mode).sizeof);
            xf86RotateDestroy(crtc);
            crtc.active = FALSE;
        }
    }
    if (pScrn.pScreen)
        xf86_crtc_notify(pScrn.pScreen);
    if (pScrn.ModeSet)
        pScrn.ModeSet(pScrn);
    if (pScrn.pScreen) {
        if (pScrn.pScreen.isGPU)
            xf86CursorResetCursor(pScrn.pScreen.current_primary);
        else
            xf86CursorResetCursor(pScrn.pScreen);
    }
}

static if (RANDR_12_INTERFACE) {

enum EDID_ATOM_NAME =		"EDID";

/**
 * Set the RandR EDID property
 */
private void xf86OutputSetEDIDProperty(xf86OutputPtr output, void* data, int data_len)
{
    Atom edid_atom = dixAddAtom(EDID_ATOM_NAME);

    /* This may get called before the RandR resources have been created */
    if (output.randr_output is null)
        return;

    if (data_len != 0) {
        RRChangeOutputProperty(output.randr_output, edid_atom, XA_INTEGER, 8,
                               PropModeReplace, data_len, data, FALSE, TRUE);
    }
    else {
        RRDeleteOutputProperty(output.randr_output, edid_atom);
    }
}

enum TILE_ATOM_NAME =		"TILE";
/* changing this in the future could be tricky as people may hardcode 8 */
enum TILE_PROP_NUM_ITEMS =		8;
private void xf86OutputSetTileProperty(xf86OutputPtr output)
{
    Atom tile_atom = dixAddAtom(TILE_ATOM_NAME);

    /* This may get called before the RandR resources have been created */
    if (output.randr_output is null)
        return;

    if (output.tile_info.group_id != 0) {
        RRChangeOutputProperty(output.randr_output, tile_atom, XA_INTEGER, 32,
                               PropModeReplace, TILE_PROP_NUM_ITEMS, cast(uint*)&output.tile_info, FALSE, TRUE);
    }
    else {
        RRDeleteOutputProperty(output.randr_output, tile_atom);
    }
}

}

/* Pull out a physical size from a detailed timing if available. */
struct det_phySize_parameter {
    xf86OutputPtr output;
    ddc_quirk_t quirks;
    Bool ret;
};

private void handle_detailed_physical_size(detailed_monitor_section* det_mon, void* data)
{
    det_phySize_parameter* p = void;

    p = cast(det_phySize_parameter*) data;

    if (p.ret == TRUE)
        return;

    xf86DetTimingApplyQuirks(det_mon, p.quirks,
                             p.output.MonInfo.features.hsize,
                             p.output.MonInfo.features.vsize);
    if (det_mon.type == DT &&
        det_mon.section.d_timings.h_size != 0 &&
        det_mon.section.d_timings.v_size != 0) {
        /* some sanity checking for aspect ratio:
           assume any h / v (or v / h) > 2.4 to be bogus.
           This would even include cinemascope */
        if (((det_mon.section.d_timings.h_size * 5) <
             (det_mon.section.d_timings.v_size * 12)) &&
            ((det_mon.section.d_timings.v_size * 5) <
             (det_mon.section.d_timings.h_size * 12))) {
            p.output.mm_width = det_mon.section.d_timings.h_size;
            p.output.mm_height = det_mon.section.d_timings.v_size;
            p.ret = TRUE;
        } else
            xf86DrvMsg(p.output.scrn.scrnIndex, X_WARNING,
                       "Output %s: Strange aspect ratio (%i/%i), "
                       ~ "consider adding a quirk\n", p.output.name,
                       det_mon.section.d_timings.h_size,
                       det_mon.section.d_timings.v_size);
    }
}

Bool xf86OutputParseKMSTile(const(char)* tile_data, int tile_length, xf86CrtcTileInfo* tile_info)
{
    int ret = void;

    ret = sscanf(tile_data, "%u:%u:%u:%u:%u:%u:%u:%u",
                 &tile_info.group_id,
                 &tile_info.flags,
                 &tile_info.num_h_tile,
                 &tile_info.num_v_tile,
                 &tile_info.tile_h_loc,
                 &tile_info.tile_v_loc,
                 &tile_info.tile_h_size,
                 &tile_info.tile_v_size);
    if (ret != 8)
        return FALSE;
    return TRUE;
}

void xf86OutputSetTile(xf86OutputPtr output, xf86CrtcTileInfo* tile_info)
{
    if (tile_info)
        output.tile_info = *tile_info;
    else
        memset(&output.tile_info, 0, typeof(output.tile_info).sizeof);
static if (RANDR_12_INTERFACE) {
    xf86OutputSetTileProperty(output);
}
}

/**
 * Set the EDID information for the specified output
 */
void xf86OutputSetEDID(xf86OutputPtr output, xf86MonPtr edid_mon)
{
    ScrnInfoPtr scrn = output.scrn;
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    Bool debug_modes = config.debug_modes || xf86Initialising;

static if (RANDR_12_INTERFACE) {
    int size = void;
}

    free(output.MonInfo);

    output.MonInfo = edid_mon;
    output.mm_width = 0;
    output.mm_height = 0;

    if (debug_modes) {
        xf86DrvMsg(scrn.scrnIndex, X_INFO, "EDID for output %s\n",
                   output.name);
        xf86PrintEDID(edid_mon);
    }

    /* Set the DDC properties for the 'compat' output */
    /* GPU screens don't have a root window */
    if (output == xf86CompatOutput(scrn) && !scrn.is_gpu)
        xf86SetDDCproperties(scrn, edid_mon);

static if (RANDR_12_INTERFACE) {
    /* Set the RandR output properties */
    size = 0;
    if (edid_mon) {
        if (edid_mon.ver.version_ == 1) {
            size = 128;
            if (edid_mon.flags & EDID_COMPLETE_RAWDATA)
                size += edid_mon.no_sections * 128;
        }
        else if (edid_mon.ver.version_ == 2)
            size = 256;
    }
    xf86OutputSetEDIDProperty(output, edid_mon ? edid_mon.rawData : null,
                              size);
}

    if (edid_mon) {

        det_phySize_parameter p = void;

        p.output = output;
        p.quirks = xf86DDCDetectQuirks(scrn.scrnIndex, edid_mon, FALSE);
        p.ret = FALSE;
        xf86ForEachDetailedBlock(edid_mon, &handle_detailed_physical_size, &p);

        /* if no mm size is available from a detailed timing, check the max size field */
        if ((!output.mm_width || !output.mm_height) &&
            (edid_mon.features.hsize && edid_mon.features.vsize)) {
            output.mm_width = edid_mon.features.hsize * 10;
            output.mm_height = edid_mon.features.vsize * 10;
        }
    }
}

/**
 * Return the list of modes supported by the EDID information
 * stored in 'output'
 */
DisplayModePtr xf86OutputGetEDIDModes(xf86OutputPtr output)
{
    ScrnInfoPtr scrn = output.scrn;
    xf86MonPtr edid_mon = output.MonInfo;

    if (!edid_mon)
        return null;
    return xf86DDCGetModes(scrn.scrnIndex, edid_mon);
}

/* maybe we should care about DDC1?  meh. */
xf86MonPtr xf86OutputGetEDID(xf86OutputPtr output, I2CBusPtr pDDCBus)
{
    ScrnInfoPtr scrn = output.scrn;
    xf86MonPtr mon = void;

    mon = xf86DoEEDID(scrn, pDDCBus, TRUE);
    if (mon)
        xf86DDCApplyQuirks(scrn.scrnIndex, mon);

    return mon;
}

private const(char)*[13] _xf86ConnectorNames = [
    "None", "VGA", "DVI-I", "DVI-D",
    "DVI-A", "Composite", "S-Video",
    "Component", "LFP", "Proprietary",
    "HDMI", "DisplayPort",
];

const(char)* xf86ConnectorGetName(xf86ConnectorType connector)
{
    return _xf86ConnectorNames[connector];
}

version (XV) {
private void x86_crtc_box_intersect(BoxPtr dest, BoxPtr a, BoxPtr b)
{
    dest.x1 = a.x1 > b.x1 ? a.x1 : b.x1;
    dest.x2 = a.x2 < b.x2 ? a.x2 : b.x2;
    dest.y1 = a.y1 > b.y1 ? a.y1 : b.y1;
    dest.y2 = a.y2 < b.y2 ? a.y2 : b.y2;

    if (dest.x1 >= dest.x2 || dest.y1 >= dest.y2)
        dest.x1 = dest.x2 = dest.y1 = dest.y2 = 0;
}

private void x86_crtc_box(xf86CrtcPtr crtc, BoxPtr crtc_box)
{
    if (crtc.enabled) {
        crtc_box.x1 = crtc.x;
        crtc_box.x2 = crtc.x + xf86ModeWidth(&crtc.mode, crtc.rotation);
        crtc_box.y1 = crtc.y;
        crtc_box.y2 = crtc.y + xf86ModeHeight(&crtc.mode, crtc.rotation);
    }
    else
        crtc_box.x1 = crtc_box.x2 = crtc_box.y1 = crtc_box.y2 = 0;
}

private int xf86_crtc_box_area(BoxPtr box)
{
    return cast(int) (box.x2 - box.x1) * cast(int) (box.y2 - box.y1);
}

/*
 * Return the crtc covering 'box'. If two crtcs cover a portion of
 * 'box', then prefer 'desired'. If 'desired' is NULL, then prefer the crtc
 * with greater coverage
 */

private xf86CrtcPtr xf86_covering_crtc(ScrnInfoPtr pScrn, BoxPtr box, xf86CrtcPtr desired, BoxPtr crtc_box_ret)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    xf86CrtcPtr crtc = void, best_crtc = void;
    int coverage = void, best_coverage = void;
    int c = void;
    BoxRec crtc_box = void, cover_box = void;

    best_crtc = null;
    best_coverage = 0;
    crtc_box_ret.x1 = 0;
    crtc_box_ret.x2 = 0;
    crtc_box_ret.y1 = 0;
    crtc_box_ret.y2 = 0;
    for (c = 0; c < xf86_config.num_crtc; c++) {
        crtc = xf86_config.crtc[c];
        x86_crtc_box(crtc, &crtc_box);
        x86_crtc_box_intersect(&cover_box, &crtc_box, box);
        coverage = xf86_crtc_box_area(&cover_box);
        if (coverage && crtc == desired) {
            *crtc_box_ret = crtc_box;
            return crtc;
        }
        else if (coverage > best_coverage) {
            *crtc_box_ret = crtc_box;
            best_crtc = crtc;
            best_coverage = coverage;
        }
    }
    return best_crtc;
}

/*
 * For overlay video, compute the relevant CRTC and
 * clip video to that.
 *
 * returning FALSE means there was a memory failure of some kind,
 * not that the video shouldn't be displayed
 */

Bool xf86_crtc_clip_video_helper(ScrnInfoPtr pScrn, xf86CrtcPtr* crtc_ret, xf86CrtcPtr desired_crtc, BoxPtr dst, INT32* xa, INT32* xb, INT32* ya, INT32* yb, RegionPtr reg, INT32 width, INT32 height)
{
    Bool ret = void;
    RegionRec crtc_region_local = void;
    RegionPtr crtc_region = reg;

    if (crtc_ret) {
        BoxRec crtc_box = void;
        xf86CrtcPtr crtc = xf86_covering_crtc(pScrn, dst,
                                              desired_crtc,
                                              &crtc_box);

        if (crtc) {
            RegionInit(&crtc_region_local, &crtc_box, 1);
            crtc_region = &crtc_region_local;
            RegionIntersect(crtc_region, crtc_region, reg);
        }
        *crtc_ret = crtc;
    }

    ret = xf86XVClipVideoHelper(dst, xa, xb, ya, yb,
                                crtc_region, width, height);

    if (crtc_region != reg)
        RegionUninit(&crtc_region_local);

    return ret;
}
}

xf86_crtc_notify_proc_ptr xf86_wrap_crtc_notify(ScreenPtr screen, xf86_crtc_notify_proc_ptr new_)
{
    if (xf86CrtcConfigPrivateIndex != -1) {
        ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
        xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
        xf86_crtc_notify_proc_ptr old = void;

        old = config.xf86_crtc_notify;
        config.xf86_crtc_notify = new_;
        return old;
    }
    return null;
}

void xf86_unwrap_crtc_notify(ScreenPtr screen, xf86_crtc_notify_proc_ptr old)
{
    if (xf86CrtcConfigPrivateIndex != -1) {
        ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
        xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

        config.xf86_crtc_notify = old;
    }
}

void xf86_crtc_notify(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    if (config.xf86_crtc_notify)
        config.xf86_crtc_notify(screen);
}

Bool xf86_crtc_supports_gamma(ScrnInfoPtr pScrn)
{
    if (xf86CrtcConfigPrivateIndex != -1) {
        xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
        xf86CrtcPtr crtc = void;

        /* for multiple drivers loaded we need this */
        if (!xf86_config)
            return FALSE;
        if (xf86_config.num_crtc == 0)
            return FALSE;
        crtc = xf86_config.crtc[0];

        return crtc.funcs.gamma_set !is null;
    }

    return FALSE;
}

void xf86ProviderSetup(ScrnInfoPtr scrn, const(xf86ProviderFuncsRec)* funcs, const(char)* name)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    assert(!xf86_config.name);
    assert(name);

    xf86_config.name = strdup(name);
    xf86_config.provider_funcs = funcs;
static if (RANDR_12_INTERFACE) {
    xf86_config.randr_provider = null;
}
}

void xf86DetachAllCrtc(ScrnInfoPtr scrn)
{
        xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
        int i = void;

        for (i = 0; i < xf86_config.num_crtc; i++) {
            xf86CrtcPtr crtc = xf86_config.crtc[i];

            if (crtc.randr_crtc)
                RRCrtcDetachScanoutPixmap(crtc.randr_crtc);

            /* dpms off */
            xf86DisableCrtc(crtc);
            /* force a reset the next time its used */
            crtc.randr_crtc.mode = null;
            crtc.mode.HDisplay = 0;
            crtc.x = crtc.y = 0;
        }
}
