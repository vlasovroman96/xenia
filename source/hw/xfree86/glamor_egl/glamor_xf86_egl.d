module glamor.glamor_xf86_egl;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026 stefan11111 <stefan11111@shitposting.expert>
 */

import build.dix_config;

version = GLAMOR_FOR_XORG;
import include.xf86;
import include.xf86Priv;

import glamor.glamor;
import glamor.glamor_egl;
import glamor.glamor_egl_priv;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.common.xf86Option;
import externs.gnu;
import os.log;
import xf86Globals;
import hw.xfree86.parser.Flags;

enum {
    GLAMOREGLOPT_RENDERING_API,
    GLAMOREGLOPT_VENDOR_LIBRARY
}

private const(OptionInfoRec)[4] GlamorEGLOptions = [
    { GLAMOREGLOPT_RENDERING_API, "RenderingAPI", OPTV_STRING, {0}, FALSE },
    { GLAMOREGLOPT_VENDOR_LIBRARY, "GlxVendorLibrary", OPTV_STRING, {0}, FALSE },
    { -1, null, OPTV_NONE, {0}, FALSE },
];

private int xf86GlamorEGLPrivateIndex = -1;

pragma(inline, true) private glamor_egl_priv_t* glamor_xf86_egl_get_scrn_private(ScrnInfoPtr scrn)
{
    return cast(glamor_egl_priv_t*)
        scrn.privates[xf86GlamorEGLPrivateIndex].ptr;
}

private glamor_egl_priv_t* glamor_xf86_egl_get_screen_private(ScreenPtr screen)
{
    return glamor_xf86_egl_get_scrn_private(xf86ScreenToScrn(screen));
}

private void glamor_xf86_egl_free_screen(ScrnInfoPtr scrn)
{
    glamor_egl_priv_t* glamor_egl = void;

    alias fnType = extern(C) void function(_ScrnInfoRec*) nothrow @nogc;
    glamor_egl = glamor_xf86_egl_get_scrn_private(scrn);
    if (glamor_egl !is null) {
        scrn.FreeScreen = cast(fnType)glamor_egl.server_private;
        glamor_egl_cleanup(glamor_egl);
        free(glamor_egl);
        scrn.FreeScreen(scrn);
    }
}

private Bool _glamor_egl_init(ScrnInfoPtr scrn, int fd, int* caps)
{
    glamor_egl_priv_t* glamor_egl = void;
    OptionInfoPtr options = void;
    const(char)* api = null;
    const(char)* glvnd_vendor = null;
    glamor_egl_conf_t glamor_egl_conf = {fd: fd};

    glamor_egl = cast(glamor_egl_priv_t*) calloc(1, typeof(*glamor_egl).sizeof);
    if (glamor_egl is null)
        return FALSE;

    glamor_egl_conf.glamor_egl_priv = glamor_egl;

    if (xf86GlamorEGLPrivateIndex == -1)
        xf86GlamorEGLPrivateIndex = xf86AllocateScrnInfoPrivateIndex();

    options = cast(OptionInfoPtr)XNFalloc(GlamorEGLOptions.sizeof);
    memcpy(options, GlamorEGLOptions.ptr, GlamorEGLOptions.sizeof);
    xf86ProcessOptions(scrn.scrnIndex, cast(_InputOption*)scrn.options, options);
    glvnd_vendor = xf86GetOptValString(options, GLAMOREGLOPT_VENDOR_LIBRARY);
    if (glvnd_vendor) {
        glamor_egl_conf.glvnd_vendor = strdup(glvnd_vendor);
        if (!glamor_egl_conf.glvnd_vendor) {
            LogMessage(X_WARNING, "Couldn't set gl vendor to: %s\n", glvnd_vendor);
        }
    }
    api = xf86GetOptValString(options, GLAMOREGLOPT_RENDERING_API);
    if (api && !strncasecmp(api, "es", 2))
        glamor_egl_conf.force_es = TRUE;
    else if (api && !strncasecmp(api, "gl", 2))
        glamor_egl_conf.es_disallowed = TRUE;
    free(options);

    glamor_egl_conf.GLAMOR_EGL_PRIV_PROC = &glamor_xf86_egl_get_screen_private;

    scrn.privates[xf86GlamorEGLPrivateIndex].ptr = glamor_egl;

    if (xf86Info.debug_ !is null) {
        glamor_egl_conf.dmabuf_forced = TRUE;
        glamor_egl_conf.dmabuf_capable = !!strstr(xf86Info.debug_,
                                                   "dmabuf_capable");
    }

    glamor_egl_conf.llvmpipe_allowed = !!scrn.confScreen.num_gpu_devices;

    glamor_egl_conf.server_private = scrn.FreeScreen;

    if (glamor_egl_init_internal(&glamor_egl_conf, caps)) {
        scrn.FreeScreen = &glamor_xf86_egl_free_screen;
        return TRUE;
    }

    free(glamor_egl);
    return FALSE;
}

Bool glamor_egl_init(ScrnInfoPtr scrn, int fd)
{
    int caps = GLAMOR_EGL_CAP_NONE;
    if (_glamor_egl_init(scrn, fd, &caps)) {
        return !!(caps & GLAMOR_EGL_DEFAULT_CAPS);
    }

    return FALSE;
}

Bool glamor_egl_init2(ScrnInfoPtr scrn, int fd, int* caps, int flags)
{
    cast(void)flags;
    return _glamor_egl_init(scrn, fd, caps);
}

/** Stub to retain compatibility with pre-server-1.16 ABI. */
Bool glamor_egl_init_textured_pixmap(ScreenPtr screen)
{
    return TRUE;
}
