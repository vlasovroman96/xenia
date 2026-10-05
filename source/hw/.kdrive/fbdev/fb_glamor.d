module hw.kdrive.fbdev.fb_glamor;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026 stefan11111 <stefan11111@shitposting.expert>
 */

import config.kdrive_config;

////import x11.Xfuncproto;

import include.scrnintstr;

import include.glamor;
import glamor.glamor_egl;

import hw.kdrive.fbdev.fbdev;

version (XV) {
import hw.kdrive.src.kxv; 
}

static if (WITH_LIBDRM) {
import externs.libdrm;
}

import core.stdc.errno;

Bool fbdevInitAccel(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    FbScreenConf* config = screen.card.closure;

    if (config.fbdev_dri_path) {
        scrpriv.dri_fd = open(config.fbdev_dri_path, O_RDWR);
        if (scrpriv.dri_fd >= 0) {
static if (WITH_LIBDRM) {
            if (config.fbdev_drm_master) {
                drmSetMaster(scrpriv.dri_fd);
            } else {
                drmDropMaster(scrpriv.dri_fd);
            }
}
        } else {
            LogMessage(X_WARNING, "Could not open %s: %s\n", config.fbdev_dri_path, strerror(errno));
        }
    } else {
        scrpriv.dri_fd = -1;
    }

    if (scrpriv.dri_fd >= 0) {
        config.fbdev_auto_dri3 = FALSE;
    }

    glamor_egl_conf_t glamor_egl_conf = {
                                         screen: pScreen,
                                         glvnd_vendor: config.fbdev_glvnd_provider,
                                         fd: scrpriv.dri_fd,
                                         auto_dri: config.fbdev_auto_dri3,
                                         llvmpipe_allowed: TRUE,
                                         force_glamor: TRUE,
                                         es_disallowed: !config.es_allowed,
                                         force_es: config.force_es,
                                        };

    if (!glamor_egl_init_internal(&glamor_egl_conf, null)) {
        return FALSE;
    }

    if (config.fbdev_auto_dri3) {
        scrpriv.dri_fd = glamor_egl_get_fd(pScreen);
    }

    const(char)* renderer = cast(const(char)*)glGetString(GL_RENDERER);

    int flags = GLAMOR_USE_EGL_SCREEN;
    if (!config.fbGlamorAllowed) {
        flags |= GLAMOR_NO_RENDER_ACCEL;
    } else if (!config.fbForceGlamor){
        if (!renderer ||
            strstr(renderer, "softpipe") ||
            strstr(renderer, "llvmpipe")) {
            flags |= GLAMOR_NO_RENDER_ACCEL;
        }
    }

    if (scrpriv.dri_fd < 0 ||
        flags & GLAMOR_NO_RENDER_ACCEL) {
        flags |= GLAMOR_NO_DRI3;
    }

    if (!glamor_init(pScreen, flags)) {
        return FALSE;
    }

version (XV) {
    /* X-Video needs glamor render accel */
    if (config.fbXVAllowed && !(flags & GLAMOR_NO_RENDER_ACCEL)) {
        kd_glamor_xv_init(pScreen);
    }
}

    return TRUE;
}

void fbdevEnableAccel(ScreenPtr pScreen)
{
static if (WITH_LIBDRM) {
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    FbScreenConf* config = screen.card.closure;

    if (config.fbdev_drm_master && scrpriv.dri_fd >= 0) {
        drmSetMaster(scrpriv.dri_fd);
    }
}
}

void fbdevDisableAccel(ScreenPtr pScreen)
{
static if (WITH_LIBDRM) {
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;
    FbScreenConf* config = screen.card.closure;

    if (config.fbdev_drm_master && scrpriv.dri_fd >= 0) {
        drmDropMaster(scrpriv.dri_fd);
    }
}
}

void fbdevFiniAccel(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    FbdevScrPriv* scrpriv = screen.driver;

    if (scrpriv.dri_fd >= 0) {
        close(scrpriv.dri_fd);
    }
}
