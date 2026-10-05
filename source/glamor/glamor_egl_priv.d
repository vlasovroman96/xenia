module glamor.glamor_egl_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026 stefan11111 <stefan11111@shitposting.expert>
 */

/**
 * Private definitions to be used by glamor and the xf86 server
 */

 
version = MESA_EGL_NO_X11_HEADERS;
version = EGL_NO_X11;
public import Xext.glx.fix;
// public import Xext.glx.fix;
import include.xf86Crtc;

public import include.scrnintstr;
public import glamor.glamor_egl_ext;

static if (GLAMOR_HAS_GBM) {
public import externs.libdrm;
}

struct glamor_egl_priv_t {
    EGLDisplay display;
    EGLContext context;
    char* device_path;
    char* glvnd_vendor; /* glvnd vendor library name or driver name */
    int exact_glvnd_vendor; /* If the glvnd vendor should be assumed valid with no checks */
    void* server_private;

static if (GLAMOR_HAS_GBM) {
    gbm_device* gbm;
    int fast_gbm_import;
}
    int fd;
    int dmabuf_capable;
    int linear_only; /* When using gbm, this means that only linear buffers can be created */
}

/**
 * Deinitialize an egl context created by glamor egl
 * and free associated resources.
 */
// void glamor_egl_cleanup(glamor_egl_priv_t* glamor_egl);

/**
 * Deinitialize an egl context created by glamor egl
 * and free associated resources.
 */
void glamor_egl_cleanup_screen(ScreenPtr screen);


 /* GLAMOR_EGL_PRIV_H */
