module glamor.glamor_egl;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright © 2010 Intel Corporation.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including
 * the next paragraph) shall be included in all copies or substantial
 * portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Authors:
 *    Zhigang Gong <zhigang.gong@linux.intel.com>
 *
 */
import build.dix_config;
import glx.glxext;

import externs.drm;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.stat;
alias stat = core.sys.posix.sys.stat.stat_t;
import core.stdc.errno;
import externs.sys.sysmacros;
import glx.vndext;
import dix.dixutils;
import build.xlibre_server;
import include.randrstr;
import include.dri3;
import dri3.dri3;
import dix.gc;
import core.sys.posix.stdlib : getenv, setenv, unsetenv;

version (HAVE_SYS_SYSMACROS_H) {
import sys.sysmacros; /* for major() & minor() */
import core.sys.linux.sys.s;

}
import glamor.glamor;
import glx.glxext;

enum EGL_NO_DISPLAY = cast(EGLDisplay)null;
version (HAVE_SYS_MKDEV_H) {
import sys.mkdev;          /* for major() & minor() on Solaris */
}

static if (WITH_LIBDRM) {
import externs.libdrm;
// import drm.drm_fourcc;
}

version = EGL_DISPLAY_NO_X_MESA;

static if (GLAMOR_HAS_GBM) {
import externs.libdrm;
}

import dix.screen_hooks_priv;
import glamor.glamor_priv;
import os.bug_priv;

import include.glamor;
import glamor.glamor_egl;
import glamor.glamor_egl_ext;
import glamor.glamor_egl_priv;
import glamor.glamor_glx_provider;
import dri3.dri3;
// import hw.kdrive.ephyr.ephyr_glamor;
import Xext.glx.fix;
import dix.screen_hooks;
import core.sys.posix.fcntl;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.unistd;
import externs.glob;
/**
 * EGLDeviceEXT's are internally stored as a globals.
 * As such, when multiple screens query the same device,
 * they end up with the same exact pointer value for the device.
 *
 * Then, per the spec, eglGetPlatformDisplayEXT returns the
 * same EGLDisplay handle.
 *
 * This is a problem, because on teardown, each screen
 * destroys it's EGLDevice, and since it can be shared by
 * multiple screens, we risk destroying the display from under it.
 *
 * See: https://github.com/X11Libre/xserver/pull/2721
 */

alias drm_magic_t = uint;

struct FreeDisplayList {
    EGLDisplay dpy;
    FreeDisplayList* next;
}

struct glamor_egl_conf_t{
    void* server_private; /* Data the X server might want to map to a screen */

    /* Either Optional 1 or 2 must be non-NULL */

    /* Optional 1 pointer to a screen */
    ScreenPtr screen;

    /* Optional 2 pointer to a server-allocated glamor_egl_priv_t, that the server maps to a screen */
    glamor_egl_priv_t *glamor_egl_priv;

    /* Optional 2 function that maps a glamor_egl_priv_t to each screen*/
    glamor_egl_priv_t* function(ScreenPtr screen) @nogc nothrow GLAMOR_EGL_PRIV_PROC ;

    char *glvnd_vendor; /* glvnd vendor library or driver name */
    int fd; /* /dev/dri/cardxx */

    int auto_dri; /* If glamor should try to automatically enable DRI3 support */

    int dmabuf_forced; /* If glamor should not use dynamic logic and only listen to the config below */
    int dmabuf_capable; /* If glamor should use dmabufs when using direct rendering (dri) */

    int llvmpipe_allowed; /* If glamor render accel should initialize on llvmpipe */
    int force_glamor; /* If glamor should initialize even on softpipe/llvmpipe */

    int es_disallowed; /* If using GLES contexts is forbidden */
    int force_es; /* If glamor should only use GLES contexts */
};

FreeDisplayList* freeDisplayList = null;

void glamor_egl_add_display_to_list(EGLDisplay dpy)
{
    if (dpy == EGL_NO_DISPLAY) {
        return;
    }

    FreeDisplayList** ptr = &freeDisplayList;
    while (*ptr) {
        ptr = &(*ptr).next;
    }

    *ptr = cast(FreeDisplayList*)XNFalloc(typeof(**ptr).sizeof);
    (*ptr).dpy = dpy;
    (*ptr).next = null;
}

EGLDisplay
glamor_egl_get_display2(EGLint type, void *native, bool platform_fallback)
{
    /* In practise any EGL 1.5 implementation would support the EXT extension */
    if (epoxy_has_egl_extension(null, "EGL_EXT_platform_base")) {
        PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplayEXT =
            cast(PFNEGLGETPLATFORMDISPLAYEXTPROC) eglGetProcAddress("eglGetPlatformDisplayEXT");
        if (getPlatformDisplayEXT)
            return getPlatformDisplayEXT(type, native, null);
    }

    /* Welp, everything is awful. */
    return platform_fallback ? eglGetDisplay(native) : null;
}

EGLDisplay
glamor_egl_get_display(EGLint type, void *native)
{
    return glamor_egl_get_display2(type, native, true);
}

void glamor_egl_destroy_display(EGLDisplay dpy)
{
    int num_found = 0;

    if (dpy == EGL_NO_DISPLAY) {
        return;
    }

    FreeDisplayList** ptr = &freeDisplayList;
    while (*ptr) {
        if ((*ptr).dpy == dpy) {
            num_found++;
            if (num_found == 1) {
                /* We found it once, remove it from the list */
                *ptr = (*ptr).next;
                continue;
            } else {
                /* We found it more than once, stop searching */
                break;
            }
        }
        ptr = &(*ptr).next;
    }

    if (num_found == 1) {
        eglTerminate(dpy);
    }
}

DevPrivateKeyRec glamor_egl_screen_private_key;

pragma(inline, true) Bool glamor_egl_init_screen_private(ScreenPtr screen)
{
    if (!dixRegisterPrivateKey(&glamor_egl_screen_private_key, PRIVATE_SCREEN, glamor_egl_priv_t.sizeof)) {
        LogMessage(X_ERROR,
                   "glamor%d: Failed to allocate screen private\n",
                   screen.myNum);
        return FALSE;
    }

    return TRUE;
}

glamor_egl_priv_t* _glamor_egl_get_screen_private(ScreenPtr screen)
{
    return cast(glamor_egl_priv_t*)dixLookupPrivate(&screen.devPrivates, &glamor_egl_screen_private_key);
}

/**
 * Hack to not break xf86 drivers.
 *
 * We actually want this to be a regular dixprivate,
 * just like the regular glamor is.
 *
 * However, this risks breaking drivers.
 *
 * See: https://gitlab.freedesktop.org/xorg/xserver/-/merge_requests/309
 */

glamor_egl_priv_t* function(ScreenPtr screen) glamor_egl_get_screen_private = &_glamor_egl_get_screen_private;

void glamor_egl_make_current(glamor_context* glamor_ctx)
{
    /* There's only a single global dispatch table in Mesa.  EGL, GLX,
     * and AIGLX's direct dispatch table manipulation don't talk to
     * each other.  We need to set the context to NULL first to avoid
     * EGL's no-op context change fast path when switching back to
     * EGL.
     */
    eglMakeCurrent(glamor_ctx.display, externs.epoxydefs.externs.epoxydefs.EGL_NO_SURFACE,
                   externs.epoxydefs.externs.epoxydefs.EGL_NO_SURFACE, externs.epoxydefs.EGL_NO_CONTEXT);

    if (!eglMakeCurrent(glamor_ctx.display,
                        glamor_ctx.surface, glamor_ctx.surface,
                        glamor_ctx.ctx)) {
        FatalError("Failed to make EGL context current\n");
    }
}

public enum DRM_IOCTL_GEM_FLINK = 0xc008640a;

static if (GLAMOR_HAS_GBM && WITH_LIBDRM) {
int glamor_get_flink_name(int fd, int handle, int* name)
{
    drm_gem_flink flink = void;

    flink.handle = handle;
    if (ioctl(fd, DRM_IOCTL_GEM_FLINK, &flink) < 0) {

	/*
	 * Assume non-GEM kernels have names identical to the handle
	 */
	if (errno == ENODEV) {
	    *name = handle;
	    return TRUE;
	} else {
	    return FALSE;
	}
    }
    *name = flink.name;
    return TRUE;
}
}

static if (GLAMOR_HAS_GBM) {
Bool glamor_create_texture_from_image(ScreenPtr screen, EGLImageKHR image, GLuint* texture)
{
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);

    glamor_make_current(glamor_priv);

    glGenTextures(1, texture);
    glBindTexture(GL_TEXTURE_2D, *texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, image);
    glBindTexture(GL_TEXTURE_2D, 0);

    return TRUE;
}
}

gbm_device* glamor_egl_get_gbm_device(ScreenPtr screen)
{
static if (GLAMOR_HAS_GBM) {
    return glamor_egl_get_screen_private(screen).gbm;
} else {
    return null;
}
}

static if (GLAMOR_HAS_GBM) {
void glamor_egl_set_pixmap_image(PixmapPtr pixmap, EGLImageKHR image, Bool used_modifiers)
{
    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);
    EGLImageKHR old = void;

    mixin(BUG_RETURN!("!pixmap_priv"));

    old = pixmap_priv.image;
    if (old) {
        ScreenPtr screen = pixmap.drawable.pScreen;
        glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);

        eglDestroyImageKHR(glamor_egl.display, old);
    }
    pixmap_priv.image = image;
    pixmap_priv.used_modifiers = used_modifiers;
}
}

Bool glamor_egl_create_textured_pixmap(PixmapPtr pixmap, int handle, int stride)
{
static if (WITH_LIBDRM) {
    ScreenPtr screen = pixmap.drawable.pScreen;
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);
    int ret = void, fd = void;

    /* GBM doesn't have an import path from handles, so we make a
     * dma-buf fd from it and then go through that.
     */
    ret = drmPrimeHandleToFD(glamor_egl.fd, handle, O_CLOEXEC, &fd);
    if (ret) {
        LogMessage(X_ERROR,
                   "Failed to make prime FD for handle: %d\n", errno);
        return FALSE;
    }

    if (!glamor_back_pixmap_from_fd(pixmap, fd,
                                    pixmap.drawable.width,
                                    pixmap.drawable.height,
                                    cast(ushort)stride,
                                    pixmap.drawable.depth,
                                    pixmap.drawable.bitsPerPixel)) {
        LogMessage(X_ERROR,
                   "Failed to make import prime FD as pixmap: %d\n", errno);
        close(fd);
        return FALSE;
    }

    close(fd);
    return TRUE;
} else {
    return FALSE;
}
}

Bool glamor_egl_create_textured_pixmap_from_gbm_bo(PixmapPtr pixmap, gbm_bo* bo, Bool used_modifiers)
{
static if (GLAMOR_HAS_GBM) {
    ScreenPtr screen = pixmap.drawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    glamor_egl_priv_t* glamor_egl = void;
    EGLImageKHR image = null;//EGL_NO_IMAGE_KHR is null here
    GLuint texture = void;
    Bool ret = FALSE;

    glamor_egl = glamor_egl_get_screen_private(screen);
static if (GBM_BO_FD_FOR_PLANE) {
    ulong modifier = gbm_bo_get_modifier(bo);
    const(int) num_planes = gbm_bo_get_plane_count(bo);
    int[GBM_MAX_PLANES] fds = void;
    int plane = void;
    int attr_num = 0;
    EGLint[64] img_attrs = 0;
    enum PlaneAttrs {
        PLANE_FD,
        PLANE_OFFSET,
        PLANE_PITCH,
        PLANE_MODIFIER_LO,
        PLANE_MODIFIER_HI,
        NUM_PLANE_ATTRS
    }
alias PLANE_FD = PlaneAttrs.PLANE_FD;
alias PLANE_OFFSET = PlaneAttrs.PLANE_OFFSET;
alias PLANE_PITCH = PlaneAttrs.PLANE_PITCH;
alias PLANE_MODIFIER_LO = PlaneAttrs.PLANE_MODIFIER_LO;
alias PLANE_MODIFIER_HI = PlaneAttrs.PLANE_MODIFIER_HI;
alias NUM_PLANE_ATTRS = PlaneAttrs.NUM_PLANE_ATTRS;

    static const(EGLint)[NUM_PLANE_ATTRS][5] planeAttrs = [
        [
            EGL_DMA_BUF_PLANE0_FD_EXT,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT,
            EGL_DMA_BUF_PLANE0_PITCH_EXT,
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT,
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT,
        ],
        [
            EGL_DMA_BUF_PLANE1_FD_EXT,
            EGL_DMA_BUF_PLANE1_OFFSET_EXT,
            EGL_DMA_BUF_PLANE1_PITCH_EXT,
            EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT,
            EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT,
        ],
        [
            EGL_DMA_BUF_PLANE2_FD_EXT,
            EGL_DMA_BUF_PLANE2_OFFSET_EXT,
            EGL_DMA_BUF_PLANE2_PITCH_EXT,
            EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT,
            EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT,
        ],
        [
            EGL_DMA_BUF_PLANE3_FD_EXT,
            EGL_DMA_BUF_PLANE3_OFFSET_EXT,
            EGL_DMA_BUF_PLANE3_PITCH_EXT,
            EGL_DMA_BUF_PLANE3_MODIFIER_LO_EXT,
            EGL_DMA_BUF_PLANE3_MODIFIER_HI_EXT,
        ],
    ];

    for (plane = 0; plane < num_planes; plane++) fds[plane] = -1;
}

    glamor_make_current(glamor_priv);

    if (glamor_egl.fast_gbm_import) {
        image = eglCreateImageKHR(glamor_egl.display,
                                  externs.epoxydefs.EGL_NO_CONTEXT,
                                  EGL_NATIVE_PIXMAP_KHR, bo, null);
    }
static if (GBM_BO_FD_FOR_PLANE) {
    if (image == null &&
        glamor_egl.dmabuf_capable) {
enum string ADD_ATTR(string attrs, string num, string attr) = `  {                                                      
            assert(((` ~ num ~ `) + 1) < (`~attrs~`.sizeof / typeof((` ~ attrs ~ `)[0]).sizeof)); 
            (` ~ attrs ~ `)[(` ~ num ~ `)++] = (` ~ attr ~ `);                                  
        } `;
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `EGL_WIDTH`));
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `gbm_bo_get_width(bo)`));
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `EGL_HEIGHT`));
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `gbm_bo_get_height(bo)`));
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `EGL_LINUX_DRM_FOURCC_EXT`));
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `gbm_bo_get_format(bo)`));

        for (plane = 0; plane < num_planes; plane++) {
            fds[plane] = gbm_bo_get_fd_for_plane(bo, plane);
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `planeAttrs[plane][PLANE_FD]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `fds[plane]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `planeAttrs[plane][PLANE_OFFSET]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `gbm_bo_get_offset(bo, plane)`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `planeAttrs[plane][PLANE_PITCH]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `gbm_bo_get_stride_for_plane(bo, plane)`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `planeAttrs[plane][PLANE_MODIFIER_LO]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `cast(uint)(modifier & 0xFFFFFFFFUL)`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `planeAttrs[plane][PLANE_MODIFIER_HI]`));
            mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `cast(uint)(modifier >> 32UL)`));
        }
        mixin(ADD_ATTR!(`img_attrs`, `attr_num`, `EGL_NONE`));
        image = eglCreateImageKHR(glamor_egl.display,
                                  externs.epoxydefs.EGL_NO_CONTEXT,
                                  EGL_LINUX_DMA_BUF_EXT,
                                  null,
                                  img_attrs.ptr);

        if (image != null) {
            glamor_egl.fast_gbm_import = FALSE;
        }

        for (plane = 0; plane < num_planes; plane++) {
            close(fds[plane]);
            fds[plane] = -1;
        }
    }
}

    if (image == null) {
        glamor_set_pixmap_type(pixmap, GLAMOR_DRM_ONLY);
        goto done;
    }
    glamor_create_texture_from_image(screen, image, &texture);
    glamor_set_pixmap_type(pixmap, GLAMOR_TEXTURE_DRM);
    glamor_set_pixmap_texture(pixmap, texture);
    glamor_egl_set_pixmap_image(pixmap, image, used_modifiers);
    ret = TRUE;

 done:
    return ret;
} else {
    return FALSE;
}
}

static if (GLAMOR_HAS_GBM && WITH_LIBDRM) {
void glamor_get_name_from_bo(int gbm_fd, gbm_bo* bo, int* name)
{
    gbm_bo_handle handle = void;

    handle = gbm_bo_get_handle(bo);
    if (!glamor_get_flink_name(gbm_fd, handle.u32, name))
        *name = -1;
}
}

static if (GLAMOR_HAS_GBM) {
Bool glamor_make_pixmap_exportable(PixmapPtr pixmap, Bool modifiers_ok)
{
    ScreenPtr screen = pixmap.drawable.pScreen;
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);
    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);
    uint width = pixmap.drawable.width;
    uint height = pixmap.drawable.height;
    uint format = void;
    gbm_bo* bo = null;
    Bool used_modifiers = FALSE;
    PixmapPtr exported = void;
    GCPtr scratch_gc = void;

    mixin(BUG_RETURN_VAL!("!pixmap_priv", "FALSE"));

    if (pixmap_priv.image &&
        (modifiers_ok || !pixmap_priv.used_modifiers))
        return TRUE;

    switch (pixmap.drawable.depth) {
    case 30:
        format = GBM_FORMAT_ARGB2101010;
        break;
    case 32:
    case 24:
        format = GBM_FORMAT_ARGB8888;
        break;
    case 16:
        format = GBM_FORMAT_RGB565;
        break;
    case 15:
        format = GBM_FORMAT_ARGB1555;
        break;
    case 8:
        format = GBM_FORMAT_R8;
        break;
    default:
        LogMessage(X_ERROR,
                   "Failed to make %d depth, %dbpp pixmap exportable\n",
                   pixmap.drawable.depth, pixmap.drawable.bitsPerPixel);
        return FALSE;
    }

static if (GBM_BO_WITH_MODIFIERS) {
    if (modifiers_ok && glamor_egl.dmabuf_capable) {
        uint num_modifiers = void;
        ulong* modifiers = null;

        if (!glamor_get_modifiers(screen, format, &num_modifiers, &modifiers)) {
            return FALSE;
        }

        if (num_modifiers > 0) {
static if (GBM_BO_WITH_MODIFIERS2) {
            /* TODO: Is scanout ever used? If so, where? */
            bo = gbm_bo_create_with_modifiers2(glamor_egl.gbm, width, height,
                                               format, modifiers, num_modifiers,
                                               GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT);
            if (!bo) {
                /* something failed, try again without GBM_BO_USE_SCANOUT */
                /* maybe scanout does work, but modifiers aren't supported */
                /* we handle this case on the fallback path */
                bo = gbm_bo_create_with_modifiers2(glamor_egl.gbm, width, height,
                                                   format, modifiers, num_modifiers,
                                                   GBM_BO_USE_RENDERING);
version (none) {
                if (bo) {
                    /* TODO: scanout failed, but regular buffer succeeded, maybe log something? */
                }
}
            }
} else {
            bo = gbm_bo_create_with_modifiers(glamor_egl.gbm, width, height,
                                              format, modifiers, num_modifiers);
}
        }
        if (bo)
            used_modifiers = TRUE;
        free(modifiers);
    }
}

    if (!bo)
    {
version(GBM_HAVE_BO_USE_LINEAR) { 
    bo = gbm_bo_create(glamor_egl.gbm, width, height, format,
                (pixmap.usage_hint == CREATE_PIXMAP_USAGE_SHARED ?
                 GBM_BO_USE_LINEAR : 0) |GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT);
}

else {
        bo = gbm_bo_create(glamor_egl.gbm, width, height, format,
                GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT);
}
        if (!bo) {

version(GBM_BO_USE_LINEAR) {
                /* something failed, try again without GBM_BO_USE_SCANOUT */
            bo = gbm_bo_create(glamor_egl.gbm, width, height, format,
                    (pixmap.usage_hint == CREATE_PIXMAP_USAGE_SHARED ?
                     GBM_BO_USE_LINEAR : 0) |
                     GBM_BO_USE_RENDERING);
}
else {
                bo = gbm_bo_create(glamor_egl.gbm, width, height, format,
                     GBM_BO_USE_RENDERING);
}
            if (bo) {
                /* TODO: scanout failed, but regular buffer succeeded, maybe log something? */
            }
}
        }

    if (!bo) {
        LogMessage(X_ERROR,
                   "Failed to make %dx%dx%dbpp GBM bo\n",
                   width, height, pixmap.drawable.bitsPerPixel);
        return FALSE;
    }

    exported = screen.CreatePixmap(screen, 0, 0, pixmap.drawable.depth, 0);
    screen.ModifyPixmapHeader(exported, width, height, 0, 0,
                               gbm_bo_get_stride(bo), null);
    if (!glamor_egl_create_textured_pixmap_from_gbm_bo(exported, bo,
                                                       used_modifiers)) {
        LogMessage(X_ERROR,
                   "Failed to make %dx%dx%dbpp pixmap from GBM bo\n",
                   width, height, pixmap.drawable.bitsPerPixel);
        dixDestroyPixmap(exported, 0);
        gbm_bo_destroy(bo);
        return FALSE;
    }
    gbm_bo_destroy(bo);

    scratch_gc = GetScratchGC(pixmap.drawable.depth, screen);
    ValidateGC(&pixmap.drawable, scratch_gc);
    cast(void) scratch_gc.ops.CopyArea(&pixmap.drawable, &exported.drawable,
                              scratch_gc,
                              0, 0, width, height, 0, 0);
    FreeScratchGC(scratch_gc);

    /* Now, swap the tex/gbm/EGLImage/etc. of the exported pixmap into
     * the original pixmap struct.
     */
    glamor_egl_exchange_buffers(pixmap, exported);

    /* Swap the devKind into the original pixmap, reflecting the bo's stride */
    screen.ModifyPixmapHeader(pixmap, 0, 0, 0, 0, exported.devKind, null);

    dixDestroyPixmap(exported, 0);

    return TRUE;
}
}

static if (GLAMOR_HAS_GBM) {
gbm_bo* glamor_gbm_bo_from_pixmap_internal(ScreenPtr screen, PixmapPtr pixmap)
{
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);
    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);

    mixin(BUG_RETURN_VAL!("!pixmap_priv", "null"));

    if (!pixmap_priv.image)
        return null;

    return gbm_bo_import(glamor_egl.gbm, GBM_BO_IMPORT_EGL_IMAGE,
                         pixmap_priv.image, GBM_BO_USE_RENDERING);
}
}

gbm_bo* glamor_gbm_bo_from_pixmap(ScreenPtr screen, PixmapPtr pixmap)
{
static if (GLAMOR_HAS_GBM) {
    if (!glamor_make_pixmap_exportable(pixmap, TRUE))
        return null;

    return glamor_gbm_bo_from_pixmap_internal(screen, pixmap);
} else {
    return null;
}
}

int glamor_egl_fds_from_pixmap(ScreenPtr screen, PixmapPtr pixmap, int* fds, uint* strides, uint* offsets, ulong* modifier)
{
static if (GLAMOR_HAS_GBM && WITH_LIBDRM) {
    gbm_bo* bo = void;
    int num_fds = void;
static if (GBM_BO_WITH_MODIFIERS) {
static if (GBM_BO_FD_FOR_PLANE) {} else {
    int first_handle = void;
}
    int i = void;
}

    if (!glamor_make_pixmap_exportable(pixmap, TRUE))
        return 0;

    bo = glamor_gbm_bo_from_pixmap_internal(screen, pixmap);
    if (!bo)
        return 0;

static if (GBM_BO_WITH_MODIFIERS) {
    num_fds = gbm_bo_get_plane_count(bo);
    for (i = 0; i < num_fds; i++) {
static if (GBM_BO_FD_FOR_PLANE) {
        fds[i] = gbm_bo_get_fd_for_plane(bo, i);
} else {
        gbm_bo_handle plane_handle = gbm_bo_get_handle_for_plane(bo, i);

        if (i == 0)
            first_handle = plane_handle.s32;

        /* If all planes point to the same object as the first plane, i.e. they
         * all have the same handle, we can fall back to the non-planar
         * gbm_bo_get_fd without losing information. If they point to different
         * objects we are out of luck and need to give up.
         */
	if (first_handle == plane_handle.s32)
            fds[i] = gbm_bo_get_fd(bo);
        else
            fds[i] = -1;
}
        if (fds[i] == -1) {
            while (--i >= 0)
                close(fds[i]);
            return 0;
        }
        strides[i] = gbm_bo_get_stride_for_plane(bo, i);
        offsets[i] = gbm_bo_get_offset(bo, i);
    }
    *modifier = gbm_bo_get_modifier(bo);
} else {
    num_fds = 1;
    fds[0] = gbm_bo_get_fd(bo);
    if (fds[0] == -1)
        return 0;
    strides[0] = gbm_bo_get_stride(bo);
    offsets[0] = 0;
    *modifier = DRM_FORMAT_MOD_INVALID;
}

    gbm_bo_destroy(bo);
    return num_fds;
} else {
    return 0;
}
}

int glamor_egl_fd_from_pixmap(ScreenPtr screen, PixmapPtr pixmap, CARD16* stride, CARD32* size)
{
static if (GLAMOR_HAS_GBM) {
    gbm_bo* bo = void;
    int fd = void;

    if (!glamor_make_pixmap_exportable(pixmap, FALSE))
        return -1;

    bo = glamor_gbm_bo_from_pixmap_internal(screen, pixmap);
    if (!bo)
        return -1;

    fd = gbm_bo_get_fd(bo);
    *stride = cast(ushort)gbm_bo_get_stride(bo);
    *size = *stride * gbm_bo_get_height(bo);
    gbm_bo_destroy(bo);

    return fd;
} else {
    return -1;
}
}

int glamor_egl_fd_name_from_pixmap(ScreenPtr screen, PixmapPtr pixmap, CARD16* stride, CARD32* size)
{
static if (GLAMOR_HAS_GBM && WITH_LIBDRM) {
    glamor_egl_priv_t* glamor_egl = void;
    gbm_bo* bo = void;
    int fd = -1;

    glamor_egl = glamor_egl_get_screen_private(screen);

    if (!glamor_make_pixmap_exportable(pixmap, FALSE))
        goto failure;

    bo = glamor_gbm_bo_from_pixmap_internal(screen, pixmap);
    if (!bo)
        goto failure;

    pixmap.devKind = gbm_bo_get_stride(bo);

    glamor_get_name_from_bo(glamor_egl.fd, bo, &fd);
    *stride = cast(ushort)pixmap.devKind;
    *size = pixmap.devKind * gbm_bo_get_height(bo);

    gbm_bo_destroy(bo);
 failure:
    return fd;
} else {
    return -1;
}
}

static if (GLAMOR_HAS_GBM) {
bool gbm_format_for_depth(CARD8 depth, uint* format)
{
    switch (depth) {
    case 15:
        *format = GBM_FORMAT_ARGB1555;
        return true;
    case 16:
        *format = GBM_FORMAT_RGB565;
        return true;
    case 24:
        *format = GBM_FORMAT_XRGB8888;
        return true;
    case 30:
        *format = GBM_FORMAT_ARGB2101010;
        return true;
    case 32:
        *format = GBM_FORMAT_ARGB8888;
        return true;
    default:
        ErrorF("unexpected depth: %d\n", depth);
        return false;
    }
}
}

Bool glamor_back_pixmap_from_fd(PixmapPtr pixmap, int fd, CARD16 width, CARD16 height, CARD16 stride, CARD8 depth, CARD8 bpp)
{
static if (GLAMOR_HAS_GBM) {
    ScreenPtr screen = pixmap.drawable.pScreen;
    glamor_egl_priv_t* glamor_egl = void;
    gbm_bo* bo = void;
    gbm_import_fd_data import_data = { 0 };
    Bool ret = void;

    glamor_egl = glamor_egl_get_screen_private(screen);

    if (!gbm_format_for_depth(depth, &import_data.format) ||
        width == 0 || height == 0)
        return FALSE;

    import_data.fd = fd;
    import_data.width = width;
    import_data.height = height;
    import_data.stride = stride;
    bo = gbm_bo_import(glamor_egl.gbm, GBM_BO_IMPORT_FD, &import_data,
                       GBM_BO_USE_RENDERING);
    if (!bo)
        return FALSE;

    screen.ModifyPixmapHeader(pixmap, width, height, 0, 0, stride, null);

    ret = glamor_egl_create_textured_pixmap_from_gbm_bo(pixmap, bo, FALSE);
    gbm_bo_destroy(bo);
    return ret;
} else {
    return FALSE;
}
}

PixmapPtr glamor_pixmap_from_fds(ScreenPtr screen, CARD8 num_fds, const(int)* fds, CARD16 width, CARD16 height, const(CARD32)* strides, const(CARD32)* offsets, CARD8 depth, CARD8 bpp, ulong modifier)
{
static if (WITH_LIBDRM) {
    PixmapPtr pixmap = void;
    glamor_egl_priv_t* glamor_egl = void;
    Bool ret = FALSE;
    int i = void;

    glamor_egl = glamor_egl_get_screen_private(screen);

    pixmap = screen.CreatePixmap(screen, 0, 0, depth, 0);

    if (glamor_egl.dmabuf_capable && modifier != DRM_FORMAT_MOD_INVALID) {
        gbm_import_fd_modifier_data import_data = { 0 };
        gbm_bo* bo = void;

        if (!gbm_format_for_depth(depth, &import_data.format) ||
            width == 0 || height == 0)
            goto error;

        import_data.width = width;
        import_data.height = height;
        import_data.num_fds = num_fds;
        import_data.modifier = modifier;
        for (i = 0; i < num_fds; i++) {
            import_data.fds[i] = fds[i];
            import_data.strides[i] = strides[i];
            import_data.offsets[i] = offsets[i];
        }
        bo = gbm_bo_import(glamor_egl.gbm, GBM_BO_IMPORT_FD_MODIFIER, &import_data,
                           GBM_BO_USE_RENDERING);
        if (bo) {
            screen.ModifyPixmapHeader(pixmap, width, height, 0, 0, strides[0], null);
            ret = glamor_egl_create_textured_pixmap_from_gbm_bo(pixmap, bo, TRUE);
            gbm_bo_destroy(bo);
        }
    } else
    {
        if (num_fds == 1) {
            ret = glamor_back_pixmap_from_fd(pixmap, fds[0], width, height,
                                             cast(ushort)strides[0], depth, bpp);
        }
    }

error:
    if (ret == FALSE) {
        dixDestroyPixmap(pixmap, 0);
        return null;
    }
    return pixmap;
}
else
    return null;
}

PixmapPtr glamor_pixmap_from_fd(ScreenPtr screen, int fd, CARD16 width, CARD16 height, CARD16 stride, CARD8 depth, CARD8 bpp)
{
static if (GLAMOR_HAS_GBM) {
    PixmapPtr pixmap = void;
    Bool ret = void;

    pixmap = screen.CreatePixmap(screen, 0, 0, depth, 0);

    ret = glamor_back_pixmap_from_fd(pixmap, fd, width, height,
                                     stride, depth, bpp);

    if (ret == FALSE) {
        dixDestroyPixmap(pixmap, 0);
        return null;
    }
    return pixmap;
} else {
    return null;
}
}

Bool glamor_get_formats_internal(glamor_egl_priv_t* glamor_egl, CARD32* num_formats, CARD32** formats)
{
static if (GLAMOR_HAS_EGL_QUERY_DMABUF) {
    EGLint num = void;
} else {
    cast(void)glamor_egl;
}

    /* Explicitly zero the count and formats as the caller may ignore the return value */
    *num_formats = 0;
    *formats = null;
static if (GLAMOR_HAS_EGL_QUERY_DMABUF) {
    if (!glamor_egl.dmabuf_capable)
        return TRUE;

    if (!eglQueryDmaBufFormatsEXT(glamor_egl.display, 0, null, &num))
        return FALSE;

    if (num == 0)
        return TRUE;

    *formats = cast(CARD32*)calloc(num, CARD32.sizeof);
    if (*formats is null)
        return FALSE;

    if (!eglQueryDmaBufFormatsEXT(glamor_egl.display, num,
                                  cast(EGLint*) *formats, &num)) {
        free(*formats);
        *formats = null;
        return FALSE;
    }

    *num_formats = num;
}
    return TRUE;
}

Bool glamor_get_formats(ScreenPtr screen, CARD32* num_formats, CARD32** formats)
{
    glamor_egl_priv_t* glamor_egl = void;
    glamor_egl = glamor_egl_get_screen_private(screen);
    return glamor_get_formats_internal(glamor_egl, num_formats, formats);
}

void glamor_filter_modifiers(uint* num_modifiers, ulong** modifiers, EGLBoolean* external_only, int linear_only)
{
    uint write_pos = 0;
    for (uint i = 0; i < *num_modifiers; i++) {
        if (external_only[i]) {
            continue;
        }

version(WITH_LIBDRM) {
            if (linear_only &&
            ((*modifiers)[i] != DRM_FORMAT_MOD_LINEAR) &&
            ((*modifiers)[i] != DRM_FORMAT_MOD_INVALID))
        {
            continue;
        }
}
else {
        if (linear_only &&
            (*modifiers)[i] != 0) /* DRM_FORMAT_MOD_LINEAR */
        {
            continue;
        }
}

        (*modifiers)[write_pos++] = (*modifiers)[i];
    }

    if (write_pos == 0) {
        *num_modifiers = 0;
        free(*modifiers);
        *modifiers = null;
    } else if (write_pos != *num_modifiers) {
        *num_modifiers = write_pos;
        ulong* filtered_modifiers = cast(ulong*) realloc(*modifiers, write_pos * typeof(*modifiers).sizeof);
        if (filtered_modifiers !is null) {
            *modifiers = filtered_modifiers;
        }
    }
}

Bool glamor_get_modifiers_internal(glamor_egl_priv_t* glamor_egl, uint format, uint* num_modifiers, ulong** modifiers)
{
static if (GLAMOR_HAS_EGL_QUERY_DMABUF) {
    EGLBoolean* external_only = void;
    EGLint num = void;
} else {
    cast(void)glamor_egl;
}

    /* Explicitly zero the count and modifiers as the caller may ignore the return value */
    *num_modifiers = 0;
    *modifiers = null;
static if (GLAMOR_HAS_EGL_QUERY_DMABUF) {
    if (!glamor_egl.dmabuf_capable)
        return FALSE;

    if (!eglQueryDmaBufModifiersEXT(glamor_egl.display, format, 0, null,
                                    null, &num))
        return FALSE;

    if (num == 0)
        return TRUE;

    *modifiers = cast(ulong*)calloc(num, ulong.sizeof);
    if (*modifiers is null)
        return FALSE;

    external_only = cast(EGLBoolean*) calloc(num, EGLBoolean.sizeof);
    if (!external_only) {
        free(*modifiers);
        *modifiers = null;
        return FALSE;
    }

    if (!eglQueryDmaBufModifiersEXT(glamor_egl.display, format, num,
                                    cast(EGLuint64KHR*) *modifiers, external_only, &num)) {
        free(external_only);
        free(*modifiers);
        *modifiers = null;
        return FALSE;
    }

    *num_modifiers = num;
    glamor_filter_modifiers(num_modifiers, modifiers, external_only, glamor_egl.linear_only);
    free(external_only);


    if (num && *num_modifiers == 0) {
        /**
         * The api explicitly told us what the supported modifiers are,
         * but we can't use any of them for our purposes
         */
        return FALSE;
    }
}
    return TRUE;
}

Bool glamor_get_modifiers(ScreenPtr screen, uint format, uint* num_modifiers, ulong** modifiers)
{
    glamor_egl_priv_t* glamor_egl = void;
    glamor_egl = glamor_egl_get_screen_private(screen);
    return glamor_get_modifiers_internal(glamor_egl, format, num_modifiers, modifiers);
}

const(char)* glamor_egl_get_driver_name(ScreenPtr screen)
{
static if (GLAMOR_HAS_EGL_QUERY_DRIVER) {
    glamor_egl_priv_t* glamor_egl = void;

    glamor_egl = glamor_egl_get_screen_private(screen);

    if (epoxy_has_egl_extension(glamor_egl.display, "EGL_MESA_query_driver"))
        return eglGetDisplayDriverName(glamor_egl.display);
}

    return null;
}

static if (GLAMOR_HAS_GBM) {
void glamor_egl_pixmap_destroy(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pixmap)
{
    ScreenPtr screen = pixmap.drawable.pScreen;
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);

    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);

    mixin(BUG_RETURN!("!pixmap_priv"));

    if (pixmap_priv.image) {
        eglDestroyImageKHR(glamor_egl.display, pixmap_priv.image);
        pixmap_priv.image = null;
    }
}
}

void glamor_egl_exchange_buffers(PixmapPtr front, PixmapPtr back)
{
static if (GLAMOR_HAS_GBM) {
    EGLImageKHR temp_img = void;
    Bool temp_mod = void;
    glamor_pixmap_private* front_priv = glamor_get_pixmap_private(front);
    glamor_pixmap_private* back_priv = glamor_get_pixmap_private(back);
}

    glamor_pixmap_exchange_fbos(front, back);

static if (GLAMOR_HAS_GBM) {
    temp_img = back_priv.image;
    temp_mod = back_priv.used_modifiers;
    mixin(BUG_RETURN!("!back_priv"));
    back_priv.image = front_priv.image;
    back_priv.used_modifiers = front_priv.used_modifiers;
    mixin(BUG_RETURN!("!front_priv"));
    front_priv.image = temp_img;
    front_priv.used_modifiers = temp_mod;
}

    glamor_set_pixmap_type(front, GLAMOR_TEXTURE_DRM);
    glamor_set_pixmap_type(back, GLAMOR_TEXTURE_DRM);
}



void glamor_egl_close_screen(CallbackListPtr* pcbl, ScreenPtr screen, void* unused)
{
    glamor_egl_priv_t* glamor_egl = void;
static if (GLAMOR_HAS_GBM) {
    glamor_pixmap_private* pixmap_priv = void;
    PixmapPtr screen_pixmap = void;
}

    glamor_egl = glamor_egl_get_screen_private(screen);
static if (GLAMOR_HAS_GBM) {
    screen_pixmap = screen.GetScreenPixmap(screen);

    pixmap_priv = glamor_get_pixmap_private(screen_pixmap);

    if (pixmap_priv && pixmap_priv.image) {
        eglDestroyImageKHR(glamor_egl.display, pixmap_priv.image);
        pixmap_priv.image = null;
    }
}

    glamor_egl_pre_close_screen_cleanup(glamor_egl);

    dixScreenUnhookClose(screen, &glamor_egl_close_screen);
static if (GLAMOR_HAS_GBM) {
    dixScreenUnhookPixmapDestroy(screen, &glamor_egl_pixmap_destroy);
}
}

void glamor_egl_post_close_screen(CallbackListPtr* pcbl, ScreenPtr screen, void* unused)
{
static if (GLAMOR_HAS_GBM) {
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);

    if (glamor_egl.gbm)
        gbm_device_destroy(glamor_egl.gbm);
}

    dixScreenUnhookPostClose(screen, &glamor_egl_post_close_screen);
}

static if(DRI3){
int glamor_dri3_open_client(ClientPtr client, ScreenPtr screen, RRProviderPtr provider, int* fdp)
{
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);
    int fd = void;
    drm_magic_t magic = void;

    fd = open(glamor_egl.device_path, O_RDWR|O_CLOEXEC);
    if (fd < 0)
        return BadAlloc;

    /* Before FD passing in the X protocol with DRI3 (and increased
     * security of rendering with per-process address spaces on the
     * GPU), the kernel had to come up with a way to have the server
     * decide which clients got to access the GPU, which was done by
     * each client getting a unique (magic) number from the kernel,
     * passing it to the server, and the server then telling the
     * kernel which clients were authenticated for using the device.
     *
     * Now that we have FD passing, the server can just set up the
     * authentication on its own and hand the prepared FD off to the
     * client.
     */
    if (drmGetMagic(fd, &magic) < 0) {
        if (errno == EACCES) {
            /* Assume that we're on a render node, and the fd is
             * already as authenticated as it should be.
             */
            *fdp = fd;
            return Success;
        } else {
            close(fd);
            return BadMatch;
        }
    }

    if (drmAuthMagic(glamor_egl.fd, magic) < 0) {
        close(fd);
        return BadMatch;
    }

    *fdp = fd;
    return Success;
}

const(dri3_screen_info_rec) glamor_dri3_info = {
    version_: 2,
    open_client: &glamor_dri3_open_client,
    pixmap_from_fds: &glamor_pixmap_from_fds,
    fd_from_pixmap: &glamor_egl_fd_from_pixmap,
    fds_from_pixmap: &glamor_egl_fds_from_pixmap,
    get_formats: &glamor_get_formats,
    get_modifiers: &glamor_get_modifiers,
    get_drawable_modifiers: &glamor_get_drawable_modifiers,
};
} /* DRI3 */

pragma(inline, true) void glamor_egl_set_glvnd_vendor(ScreenPtr screen)
{
    const(char)* vendor = void;
    const(char)* renderer = void;

    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);

    /* Should we make sure the vendor is valid? (nvidia, mesa, ???) */
    if (glamor_egl.exact_glvnd_vendor) {
        glamor_set_glvnd_vendor(screen, glamor_egl.glvnd_vendor);
        return;
    }

static if (GLAMOR_HAS_GBM) {
    if (glamor_egl.fd >= 0) {
        const(char)* gbm_backend_name = void;
        gbm_backend_name = gbm_device_get_backend_name(glamor_egl.gbm);
        if (gbm_backend_name) {
            if (!strncmp(gbm_backend_name, "nvidia", (("nvidia").sizeof - 1))) {
                 glamor_set_glvnd_vendor(screen, "nvidia");
                 return;
            } else if (!strcmp(gbm_backend_name, "drm")) {
                 /* Mesa uses "drm" as the gbm backend name */
                 glamor_set_glvnd_vendor(screen, "mesa");
                 return;
            }
        }
    }
}

    vendor = cast(const(char)*)glGetString(GL_VENDOR);
    renderer = cast(const(char)*)glGetString(GL_RENDERER);

    if (!glamor_egl.glvnd_vendor) {
        if (renderer && strstr(renderer, "NVIDIA")) {
            glamor_set_glvnd_vendor(screen, "nvidia");
        } else if (vendor && strstr(vendor, "NVIDIA")) {
            glamor_set_glvnd_vendor(screen, "nvidia");
        } else {
            glamor_set_glvnd_vendor(screen, "mesa");
        }
    } else {
        if (strstr(glamor_egl.glvnd_vendor, "nvidia")) {
            glamor_set_glvnd_vendor(screen, "nvidia");
        } else {
            glamor_set_glvnd_vendor(screen, "mesa");
        }
    }
}

void glamor_egl_screen_init(ScreenPtr screen, glamor_context* glamor_ctx)
{
    glamor_egl_priv_t* glamor_egl = glamor_egl_get_screen_private(screen);
static if(DRI3){
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
}
static if (GLXEXT) {
    static Bool vendor_initialized = FALSE;
}

    dixScreenHookClose(screen, &glamor_egl_close_screen);
    dixScreenHookPostClose(screen, &glamor_egl_post_close_screen);
static if (GLAMOR_HAS_GBM) {
    dixScreenHookPixmapDestroy(screen, &glamor_egl_pixmap_destroy);
}

    glamor_ctx.ctx = glamor_egl.context;
    glamor_ctx.display = glamor_egl.display;

    glamor_ctx.make_current = &glamor_egl_make_current;

    glamor_egl_set_glvnd_vendor(screen);
static if(DRI3){
    if (glamor_egl.fd >= 0) {
        /* Tell the core that we have the interfaces for import/export
         * of pixmaps.
         */
        glamor_enable_dri3(screen);

        /* If the driver wants to do its own auth dance (e.g. Xwayland
         * on pre-3.15 kernels that don't have render nodes and thus
         * has the wayland compositor as a master), then it needs us
         * to stay out of the way and let it init DRI3 on its own.
         */
        if (!(glamor_priv.flags & GLAMOR_NO_DRI3)) {
            /* To do DRI3 device FD generation, we need to open a new fd
             * to the same device we were handed in originally.
             */
            glamor_egl.device_path = drmGetRenderDeviceNameFromFd(glamor_egl.fd);
            if (!glamor_egl.device_path)
                glamor_egl.device_path = drmGetDeviceNameFromFd2(glamor_egl.fd);

            if (!dri3_screen_init(screen, &glamor_dri3_info)) {
                LogMessage(X_ERROR,
                           "Failed to initialize DRI3.\n");
            }
        }
    }
}
static if (GLXEXT) {
    if (!vendor_initialized) {
        GlxPushProvider(&glamor_provider);
        xorgGlxCreateVendor();
        vendor_initialized = TRUE;
    }
}
}

Bool glamor_query_devices_ext(EGLDeviceEXT** devices, EGLint* num_devices)
{
    EGLint max_devices = 0;

    *devices = null;
    *num_devices = 0;

    if (!epoxy_has_egl_extension(null, "EGL_EXT_device_base") &&
        !(epoxy_has_egl_extension(null, "EGL_EXT_device_query") &&
          epoxy_has_egl_extension(null, "EGL_EXT_device_enumeration"))) {
        return FALSE;
    }

    if (!eglQueryDevicesEXT(0, null, &max_devices) || max_devices < 1) {
         return FALSE;
    }

    *devices = cast(void**)calloc(max_devices, typeof(**devices).sizeof);
    if (*devices is null) {
         return FALSE;
    }

    if (!eglQueryDevicesEXT(max_devices, *devices, num_devices) || *num_devices < 1) {
         free(*devices);
         *devices = null;
         *num_devices = 0;
         return FALSE;
    }

    if (*num_devices < max_devices) {
         /* Shouldn't happen */
         void* tmp = realloc(*devices, *num_devices * typeof(**devices).sizeof);
         if (tmp) {
             *devices = cast(void**)tmp;
         }
    }

    return TRUE;
}

pragma(inline, true) Bool glamor_egl_fd_is_render_node(int fd)
{
    stat buf = void;
    if(fstat(fd, &buf) < 0) {
        close(fd);
        return FALSE;
    }

    return (major(buf.st_rdev) != 0) && (minor(buf.st_rdev) >= 128);
}

pragma(inline, true) int glamor_egl_render_node_from_fd(int fd)
{
static if (WITH_LIBDRM) {
    const(char)* render_name = void;

    render_name = drmGetRenderDeviceNameFromFd(fd);
    if (!render_name) {
        return -1;
    }

    return open(render_name, O_RDWR);
} else {
    return -1;
}
}

pragma(inline, true) int glamor_egl_device_get_fd(EGLDeviceEXT device)
{
    const(char)* dev_file = eglQueryDeviceStringEXT(device, EGL_DRM_DEVICE_FILE_EXT);
    if (!dev_file) {
        return FALSE;
    }

    return open(dev_file, O_RDWR);
}

pragma(inline, true) int glamor_egl_device_get_matching_fd(EGLDeviceEXT device, int fd)
{
    int card_fd = glamor_egl_device_get_fd(device);
    if (glamor_egl_fd_is_render_node(fd)) {
        int render_fd = glamor_egl_render_node_from_fd(card_fd);
        close(card_fd);
        return render_fd;
    }

    return card_fd;
}

pragma(inline, true) Bool glamor_egl_device_matches_fd(EGLDeviceEXT device, int fd)
{
    int dev_fd = glamor_egl_device_get_matching_fd(device, fd);
    if (dev_fd < 0) {
        return FALSE;
    }

    /**
     * From https://pubs.opengroup.org/onlinepubs/009696699/basedefs/sys/stat.h.html
     *
     * The st_ino and st_dev fields taken together uniquely identify the file within the system.
     */
    stat stat1 = void, stat2 = void;
    if(fstat(dev_fd, &stat2) < 0) {
        close(dev_fd);
        return FALSE;
    }

    close(dev_fd);

    if(fstat(fd, &stat1) < 0) {
        return FALSE;
    }

    return (stat1.st_dev == stat2.st_dev) && (stat1.st_ino == stat2.st_ino);
}

pragma(inline, true) const(char)* glamor_egl_device_get_name(EGLDeviceEXT device)
{
/**
 * For some reason, this isn't part of the epoxy headers.
 * It is part of EGL/eglext.h, but we can't include that
 * alongside the epoxy headers.
 *
 * See: https://registry.khronos.org/EGL/extensions/EXT/EGL_EXT_device_persistent_id.txt
 * for the spec where this is defined
 */
enum EGL_DRIVER_NAME_EXT = 0x335E;


/**
 * Same for this one
 *
 * See: https://registry.khronos.org/EGL/extensions/EXT/EGL_EXT_device_query_name.txt
 * for the spec where this is defined
 */
enum EGL_RENDERER_EXT = 0x335F;


    const(char)* dev_ext = eglQueryDeviceStringEXT(device, EGL_EXTENSIONS);

    const(char)* driver_name = epoxy_extension_in_string(dev_ext, "EGL_EXT_device_persistent_id") ?
                              eglQueryDeviceStringEXT(device, EGL_DRIVER_NAME_EXT) : null;

    if (driver_name) {
        return driver_name;
    }

    /* This might seem like overkill, but it's actually needed for the nvidia 470 driver */
    if (epoxy_extension_in_string(dev_ext, "EGL_EXT_device_query_name")) {
        const(char)* egl_renderer = eglQueryDeviceStringEXT(device, EGL_RENDERER_EXT);
        if (egl_renderer) {
            return strstr(egl_renderer, "NVIDIA") ? "nvidia" : "mesa";
        }
        const(char)* egl_vendor = eglQueryDeviceStringEXT(device, EGL_VENDOR);
        if (egl_vendor) {
            return strstr(egl_vendor, "NVIDIA") ? "nvidia" : "mesa";
        }
    }

    return null;
}

/**
 * Find the desired EGLDevice for our config.
 *
 * If strict == 2, we are looking for EGLDevices with names and,
 * if a glvnd vendor was passed, an exact match between the
 * device's name, and the desired vendor.
 *
 * If strict == 1, we are looking for EGLDevices with names and,
 * if a glvnd vendor was passed, a match between the gl vendor library
 * provider and the desired vendor's library.
 *
 * If strict == 0, we accept all devices, even those with no names.
 *
 * Regardless of success/failure, and regardless of strictness level,
 * we save the statically allocated string with the EGLDevice's name
 * in *driver_name, even if that name is NULL.
 */
pragma(inline, true) Bool glamor_egl_device_matches_config(EGLDeviceEXT device, glamor_egl_priv_t* glamor_egl, int strict, const(char)** driver_name)
{
    *driver_name = glamor_egl_device_get_name(device);

    /**
     * If the fd passed to glamor is a render node,
     * it is safe to pick a device that doesn't match it.
     */
    if (strict <= 0 && glamor_egl.fd >= 0 &&
        glamor_egl_fd_is_render_node(glamor_egl.fd)) {
        return TRUE;
    }

    /**
     * If we're trying to do direct rendering,
     * we can't have a mismatch between the gpu and the device we pick
     *
     * If not, we don't have any strict requirements for out device
     */
    if (glamor_egl.fd >= 0 &&
        !glamor_egl_device_matches_fd(device, glamor_egl.fd)) {
        return FALSE;
    }

    /* We have no further requirements, mark this as valid */
    if (strict <= 0) {
        return TRUE;
    }

    /* From here on, strict >= 1, we want the device to have a name */
    if (*driver_name is null) {
        return FALSE;
    }

    /* No glvnd vendor was requested, we have no further requirements */
    if (!glamor_egl.glvnd_vendor) {
        return TRUE;
    }

    /**
     * A glvnd vendor was requested.
     * Check for an exact match between the driver name and the requested
     * vendor.
     *
     * We're looking for _driver_ names, not library names here.
     * If we find an exact match, that's the most we ask.
     */
    if (!strcmp(*driver_name, glamor_egl.glvnd_vendor)) {
        return TRUE;
    }

    /* We don't have an exact driver name match, reject this device is strict == 2 */
    if (strict >= 2) {
        return FALSE;
    }

    /**
     * Here, strict == 1
     * We're looking for a glvnd library name match.
     *
     * This is not specific to nvidia,
     * but I don't know of any gl library vendors
     * other than mesa and nvidia
     */
    Bool device_is_nvidia = !!strstr(*driver_name, "nvidia");
    Bool config_is_nvidia = !!strstr(glamor_egl.glvnd_vendor, "nvidia");

    return device_is_nvidia == config_is_nvidia;
}

void glamor_egl_pre_close_screen_cleanup(glamor_egl_priv_t* glamor_egl)
{
    if (!glamor_egl) {
        return;
    }

    if (glamor_egl.display != EGL_NO_DISPLAY) {
        if (glamor_egl.context != externs.epoxydefs.EGL_NO_CONTEXT) {
            eglDestroyContext(glamor_egl.display, glamor_egl.context);
            glamor_egl.context = externs.epoxydefs.EGL_NO_CONTEXT;
        }

        eglMakeCurrent(glamor_egl.display,
                       externs.epoxydefs.EGL_NO_SURFACE, externs.epoxydefs.EGL_NO_SURFACE, externs.epoxydefs.EGL_NO_CONTEXT);
        /*
         * Force the next glamor_make_current call to update the context
         * (on hot unplug another GPU may still be using glamor)
         */
        lastGLContext = null;
        glamor_egl_destroy_display(glamor_egl.display);
        glamor_egl.display = EGL_NO_DISPLAY;
    }

    free(glamor_egl.device_path);
    free(glamor_egl.glvnd_vendor);
}

void glamor_egl_cleanup(glamor_egl_priv_t* glamor_egl)
{
    if (!glamor_egl) {
        return;
    }

    glamor_egl_pre_close_screen_cleanup(glamor_egl);

static if (GLAMOR_HAS_GBM) {
    if (glamor_egl.gbm)
        gbm_device_destroy(glamor_egl.gbm);
}
}

void glamor_egl_cleanup_screen(ScreenPtr screen)
{
    /* Only clean up stuff if we set it up to begin with */
    if (screen && (glamor_egl_screen_init2 is &glamor_egl_screen_init)) {
        glamor_egl_cleanup(glamor_egl_get_screen_private(screen));
    }
}

void glamor_egl_chose_configs(EGLDisplay display, const(EGLint)* attrib_list, EGLConfig** configs, EGLint* num_configs)
{
    EGLint max_configs = 0;
    *configs = null;
    *num_configs = 0;
    if (!eglChooseConfig(display, attrib_list, null, 0, &max_configs) || max_configs == 0) {
        return;
    }
    *configs = cast(void**)calloc(max_configs, EGLConfig.sizeof);
    if (*configs is null) {
        return;
    }
    if (!eglChooseConfig(display, attrib_list, *configs, max_configs, num_configs) || *num_configs == 0) {
        free(*configs);
        *configs = null;
        *num_configs = 0;
    }
    if (*num_configs < max_configs) {
        /* Shouldn't happen */
        void* tmp = realloc(*configs, *num_configs * EGLConfig.sizeof);
        if (tmp) {
            *configs = cast(void**)tmp;
        }
    }
}
EGLContext glamor_egl_create_context(EGLDisplay display, const(EGLint)* config_attrib_list, const(EGLint)** ctx_attrib_lists, int num_attr_lists)
{
    EGLConfig* configs = null;
    EGLint num_configs = 0;
    EGLContext ctx = externs.epoxydefs.EGL_NO_CONTEXT;
    /* Try creating a no-config context, maybe we can skip all the config stuff */
    /* if (epoxy_has_egl_extension(display, "EGL_KHR_no_config_context")) */
    for (int j = 0; j < num_attr_lists; j++) {
        ctx = eglCreateContext(display, externs.epoxydefs.EGL_NO_CONFIG_KHR,
                               externs.epoxydefs.EGL_NO_CONTEXT, ctx_attrib_lists[j]);
        if (ctx != externs.epoxydefs.EGL_NO_CONTEXT) {
            return ctx;
        }
    }
    glamor_egl_chose_configs(display, config_attrib_list,
                             &configs, &num_configs);
    for (int i = 0; i < num_configs; i++) {
        for (int j = 0; j < num_attr_lists; j++) {
            ctx = eglCreateContext(display, configs[i],
                                   externs.epoxydefs.EGL_NO_CONTEXT, ctx_attrib_lists[j]);
            if (ctx != externs.epoxydefs.EGL_NO_CONTEXT) {
                free(configs);
                return ctx;
            }
        }
    }
    free(configs);
    return externs.epoxydefs.EGL_NO_CONTEXT;
}

Bool glamor_egl_try_big_gl_api(glamor_egl_priv_t* glamor_egl)
{
    static const(EGLint)[7] config_attribs_core = [
        EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR,
        EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
        EGL_CONTEXT_MAJOR_VERSION_KHR,
        GLAMOR_GL_CORE_VER_MAJOR,
        EGL_CONTEXT_MINOR_VERSION_KHR,
        GLAMOR_GL_CORE_VER_MINOR,
     /* EGL_CONTEXT_PRIORITY_LEVEL_IMG, EGL_CONTEXT_PRIORITY_HIGH_IMG, */
        EGL_NONE
    ];
    static const(EGLint)[1] config_attribs = [
        EGL_NONE
    ];

    static const(EGLint)*[2] ctx_attrib_lists = [ config_attribs_core.ptr, config_attribs.ptr ];

    static const(EGLint)[7] config_attrib_list = [
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_CONFORMANT, EGL_OPENGL_BIT,
        EGL_SURFACE_TYPE, externs.epoxydefs.EGL_DONT_CARE, /* EGL_STREAM_BIT_KHR */
        EGL_NONE
    ];

    if (!eglBindAPI(EGL_OPENGL_API)) {
        LogMessage(X_ERROR, "glamor: Failed to bind GL API.\n");
        return FALSE;
    }

    glamor_egl.context = glamor_egl_create_context(glamor_egl.display,
                                                    config_attrib_list.ptr,
                                                    ctx_attrib_lists.ptr,
                                                    mixin(ARRAY_SIZE!("ctx_attrib_lists")));

    if (glamor_egl.context == externs.epoxydefs.EGL_NO_CONTEXT) {
        LogMessage(X_ERROR, "Failed to create GL context\n");
        return FALSE;
    }

    if (!eglMakeCurrent(glamor_egl.display,
                        externs.epoxydefs.EGL_NO_SURFACE, externs.epoxydefs.EGL_NO_SURFACE, glamor_egl.context)) {
        LogMessage(X_ERROR, "Failed to make GL context current\n");

        eglDestroyContext(glamor_egl.display, glamor_egl.context);
        glamor_egl.context = externs.epoxydefs.EGL_NO_CONTEXT;
        return FALSE;
    }
    if (epoxy_gl_version() < 21) {
        LogMessage(X_INFO, "glamor: Ignoring GL < 2.1, falling back to GLES.\n");

        eglDestroyContext(glamor_egl.display, glamor_egl.context);
        glamor_egl.context = externs.epoxydefs.EGL_NO_CONTEXT;
        return FALSE;
    }

    LogMessage(X_INFO,
        "glamor: Using OpenGL %d.%d context.\n",
        epoxy_gl_version() / 10,
        epoxy_gl_version() % 10);

    return TRUE;
}

Bool glamor_egl_try_gles_api(glamor_egl_priv_t* glamor_egl)
{
    static const(EGLint)[3] config_attribs = [
        EGL_CONTEXT_CLIENT_VERSION, 2,
     /* EGL_CONTEXT_PRIORITY_LEVEL_IMG, EGL_CONTEXT_PRIORITY_HIGH_IMG, */
        EGL_NONE
    ];

    static const(EGLint)*[1] ctx_attrib_lists = [ config_attribs.ptr ];

    static const(EGLint)[7] config_attrib_list = [
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_CONFORMANT, EGL_OPENGL_ES2_BIT,
        EGL_SURFACE_TYPE, externs.epoxydefs.EGL_DONT_CARE, /* EGL_STREAM_BIT_KHR */
        EGL_NONE
    ];


    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        LogMessage(X_ERROR, "glamor: Failed to bind GLES API.\n");
        return FALSE;
    }

    glamor_egl.context = glamor_egl_create_context(glamor_egl.display,
                                                    config_attrib_list.ptr,
                                                    ctx_attrib_lists.ptr,
                                                    mixin(ARRAY_SIZE!("ctx_attrib_lists")));

    if (glamor_egl.context == externs.epoxydefs.EGL_NO_CONTEXT) {
        LogMessage(X_ERROR, "Failed to create GLES context\n");
        return FALSE;
    }
    if (!eglMakeCurrent(glamor_egl.display,
                        externs.epoxydefs.EGL_NO_SURFACE, externs.epoxydefs.EGL_NO_SURFACE, glamor_egl.context)) {
        eglDestroyContext(glamor_egl.display, glamor_egl.context);
        glamor_egl.display = externs.epoxydefs.EGL_NO_CONTEXT;
        LogMessage(X_ERROR, "Failed to make GLES context current\n");
        return FALSE;
    }

    LogMessage(X_INFO,
               "glamor: Using OpenGL ES %d.%d context.\n",
               epoxy_gl_version() / 10,
               epoxy_gl_version() % 10);

    return TRUE;
}

static if (GLAMOR_HAS_GBM) {
pragma(inline, true) gbm_device* gbm_create_device_by_name(int fd, const(char)* name)
{
    gbm_device* ret = null;
    const(char)* old_backend = getenv("GBM_BACKEND");
    setenv("GBM_BACKEND", name, 1);
    ret = gbm_create_device(fd);
    unsetenv("GBM_BACKEND");
    if (old_backend) {
        setenv("GBM_BACKEND", old_backend, 1);
    }
    return ret;
}
}

Bool glamor_egl_init_display(glamor_egl_priv_t* glamor_egl, int* dri_fd)
{
    EGLDeviceEXT* devices = null;
    EGLint num_devices = 0;
    const(char)* driver_name = null;
    /**
     * If the user didn't give us a GL driver/library name,
     * we populate it with what we queried
     */
enum string GLAMOR_EGL_TRY_PLATFORM(string platform, string native, string platform_fallback) = `
    glamor_egl.display = glamor_egl_get_display2(`~platform~`, `~native~`, `~platform_fallback~`); 
    glamor_egl_add_display_to_list(glamor_egl.display); 
    if (glamor_egl.display == EGL_NO_DISPLAY) { 
        //LogMessage(X_ERROR, "glamor: eglGetDisplay(`~platform~`, `~native~`) failedn"); 
    } else { 
        if (eglInitialize(glamor_egl.display, null, null)) { 
            if (!glamor_egl.glvnd_vendor && driver_name) { 
                glamor_egl.glvnd_vendor = strdup(driver_name); 
            } 
            //LogMessage(X_INFO, "glamor: eglInitialize() succeeded on " #platform "n"); 
            if (dri_fd && `~platform~` == EGL_PLATFORM_DEVICE_EXT) { 
                *dri_fd = glamor_egl_device_get_fd(`~native~`); 
            } 
            free(devices); 
            return TRUE; 
        } 
        //LogMessage(X_ERROR, "glamor: eglInitialize() failed on " #platform "n"); 
        glamor_egl_destroy_display(glamor_egl.display); 
        glamor_egl.display = EGL_NO_DISPLAY; 
    }`;

static if (GLAMOR_HAS_GBM) {
    if (glamor_egl.fd >= 0) {
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_GBM_KHR`, `glamor_egl.gbm`, `FALSE`));
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_GBM_MESA`, `glamor_egl.gbm`, `TRUE`));
    }
}

    if (glamor_query_devices_ext(&devices, &num_devices)) {
enum string GLAMOR_EGL_TRY_PLATFORM_DEVICE(string strict) = `
        for (uint i = 0; i < num_devices; i++) { 
            if (glamor_egl_device_matches_config(devices[i], glamor_egl, ` ~ strict ~ `, &driver_name)) { 
                ` ~ GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_DEVICE_EXT`, `devices[i]`, `TRUE`) ~ `; 
            } 
        }`;

        mixin(GLAMOR_EGL_TRY_PLATFORM_DEVICE!(`2`));
        mixin(GLAMOR_EGL_TRY_PLATFORM_DEVICE!(`1`));
        mixin(GLAMOR_EGL_TRY_PLATFORM_DEVICE!(`0`));

    }
    driver_name = null;

    /**
     * We only try these falbacks if we don't have an fd passed, since we
     * have to do some guessing anyway to find the desired gpu.
     *
     * Trying these in multi-card setups risks a screen driven by one card
     * being mapped a, EGLDisplay backed by a different card, which can break.
     *
     * We actualy can specify the device using EGL_EXT_explicit_device:
     * https://registry.khronos.org/EGL/extensions/EXT/EGL_EXT_explicit_device.txt
     *
     * However, it doesn't seem worth it to implement this fallback, given
     * we're already trying the device platform, and the extension is
     * relatively new (2022), which means that it will be missing on a lot of cards.
     */
    if (glamor_egl.fd < 0) {
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_SURFACELESS_MESA`, `externs.epoxydefs.EGL_DEFAULT_DISPLAY`, `FALSE`));

        /**
         * From https://registry.khronos.org/EGL/extensions/KHR/EGL_KHR_platform_gbm.txt
         *
         * If <native_display> is externs.epoxydefs.EGL_DEFAULT_DISPLAY,
         * then the resultant EGLDisplay will be backed by some
         * implementation-chosen GBM device.
         */
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_GBM_KHR`, `externs.epoxydefs.EGL_DEFAULT_DISPLAY`, `FALSE`));
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_GBM_MESA`, `externs.epoxydefs.EGL_DEFAULT_DISPLAY`, `FALSE`));

        /**
         * According to https://registry.khronos.org/EGL/extensions/EXT/EGL_EXT_platform_device.txt :
         *
         * When <platform> is EGL_PLATFORM_DEVICE_EXT, <native_display> must
         * be an EGLDeviceEXT object.  Platform-specific extensions may
         * define other valid values for <platform>.
         *
         * As far as I know, this is the relevant standard, and it has not been superceeded in this regard.
         * However, some vendors do allow passing externs.epoxydefs.EGL_DEFAULT_DISPLAY as the <native_display> argument.
         * So, while this is incorrect according to the standard, it doesn't hurt, and it actually does
         * something with some vendors (notably intel from my testing).
         */
        mixin(GLAMOR_EGL_TRY_PLATFORM!(`EGL_PLATFORM_DEVICE_EXT`, `externs.epoxydefs.EGL_DEFAULT_DISPLAY`, `TRUE`));
    }

    free(devices);
    return FALSE;
}

int glamor_egl_get_fd(ScreenPtr screen)
{
    return glamor_egl_get_screen_private(screen).fd;
}

Bool glamor_egl_init_internal(glamor_egl_conf_t* glamor_egl_conf, int* caps)
{
    const(GLubyte)* renderer = void;
    glamor_egl_priv_t* glamor_egl = null;
    int* dri_fd = null;

    if (caps) {
        *caps = GLAMOR_EGL_CAP_NONE;
    }
    Bool found = FALSE;
    CARD32* formats = null;
    CARD32 num_formats = 0;

    if (glamor_egl_conf.GLAMOR_EGL_PRIV_PROC) {
        glamor_egl_get_screen_private = glamor_egl_conf.GLAMOR_EGL_PRIV_PROC;
        glamor_egl = glamor_egl_conf.glamor_egl_priv;
    } else {
        if (!glamor_egl_conf.screen ||
            !glamor_egl_init_screen_private(glamor_egl_conf.screen)) {
            goto error;
        }
        glamor_egl = glamor_egl_get_screen_private(glamor_egl_conf.screen);
    }

    memset(glamor_egl, 0, typeof(*glamor_egl).sizeof);

    if (glamor_egl_conf.glvnd_vendor) {
        glamor_egl.glvnd_vendor = glamor_egl_conf.glvnd_vendor;
        glamor_egl.exact_glvnd_vendor = TRUE;
    }
    glamor_egl.fd = glamor_egl_conf.fd;

static if (GLAMOR_HAS_GBM) {
    if (glamor_egl.fd >= 0) {
        glamor_egl.gbm = gbm_create_device(glamor_egl.fd);
        if (!glamor_egl.gbm) {
            glamor_egl.gbm = gbm_create_device_by_name(glamor_egl.fd, "dumb");
        }

        if (glamor_egl.gbm is null) {
            ErrorF("couldn't create gbm device\n");
            glamor_egl.fd = -1;
        }

        const(char)* gbm_backend = glamor_egl.gbm ?
                                  gbm_device_get_backend_name(glamor_egl.gbm) : null;
        if (gbm_backend && !strcmp(gbm_backend, "dumb")) {
            glamor_egl.linear_only = TRUE;
        }
    }
}

    if (glamor_egl_conf.auto_dri && glamor_egl.fd < 0) {
        dri_fd = &glamor_egl.fd;
    }

    if (!glamor_egl_init_display(glamor_egl, dri_fd)) {
        goto error;
    }

static if (GLAMOR_HAS_GBM) {
    if (!glamor_egl.gbm && glamor_egl.fd >= 0 &&
        glamor_egl_conf.auto_dri) {
        glamor_egl.gbm = gbm_create_device(glamor_egl.fd);
        if (!glamor_egl.gbm) {
            glamor_egl.gbm = gbm_create_device_by_name(glamor_egl.fd, "dumb");
        }

        if (glamor_egl.gbm is null) {
            ErrorF("couldn't create gbm device\n");
            glamor_egl.fd = -1;
        }

        const(char)* gbm_backend = glamor_egl.gbm ?
                                  gbm_device_get_backend_name(glamor_egl.gbm) : null;
        if (gbm_backend && !strcmp(gbm_backend, "dumb")) {
            glamor_egl.linear_only = TRUE;
        }
    }
}

enum string GLAMOR_CHECK_EGL_EXTENSION(string EXT) = `
	if (!epoxy_has_egl_extension(glamor_egl.display, "EGL_`~EXT~`")) {  
		ErrorF("EGL_`~EXT~` required.\n");  
		goto error;  
	}`;

    mixin(GLAMOR_CHECK_EGL_EXTENSION!(`KHR_surfaceless_context`));

    if (!glamor_egl_conf.force_es) {
        if(!glamor_egl_try_big_gl_api(glamor_egl))
            goto error;
    }

    if (glamor_egl.context == externs.epoxydefs.EGL_NO_CONTEXT && !glamor_egl_conf.es_disallowed) {
        if(!glamor_egl_try_gles_api(glamor_egl))
            goto error;
    }

    if (glamor_egl.context == externs.epoxydefs.EGL_NO_CONTEXT) {
        LogMessage(X_ERROR,
                   "glamor: Failed to create GL or GLES2 contexts\n");
        goto error;
    }

    renderer = glGetString(GL_RENDERER);

    if (!glamor_egl_conf.force_glamor) {
        if (!renderer) {
            LogMessage(X_ERROR,
                       "glGetString() returned NULL, your GL is broken\n");
            goto error;
        }
        if (strstr(cast(const(char)*)renderer, "softpipe")) {
            LogMessage(X_INFO,
                       "Refusing to try glamor on softpipe\n");
            goto error;
        }
        if (!strncmp("llvmpipe", cast(const(char)*)renderer, (("llvmpipe").sizeof - 1))) {
            if (glamor_egl_conf.llvmpipe_allowed)
                LogMessage(X_INFO,
                           "Allowing glamor on llvmpipe for PRIME\n");
            else {
                LogMessage(X_INFO,
                           "Refusing to try glamor on llvmpipe\n");
                 goto error;
            }
        }
    }

    /*
     * Force the next glamor_make_current call to set the right context
     * (in case of multiple GPUs using glamor)
     */
    lastGLContext = null;

    /* XXX From here on, glamor initalization should not fail completely XXX */

    if (glamor_egl.fd < 0) {
        goto glamor_no_dri;
    }

    if (!epoxy_has_gl_extension("GL_OES_EGL_image")) {
        LogMessage(X_ERROR,
                   "glamor dri acceleration requires GL_OES_EGL_image\n");
        goto glamor_no_dri;
    }

static if (GBM_BO_WITH_MODIFIERS) {
    if (epoxy_has_egl_extension(glamor_egl.display,
                                "EGL_EXT_image_dma_buf_import") &&
        epoxy_has_egl_extension(glamor_egl.display,
                                "EGL_EXT_image_dma_buf_import_modifiers")) {

        if (glamor_egl_conf.dmabuf_forced)
            glamor_egl.dmabuf_capable = glamor_egl_conf.dmabuf_capable;
        else if (!renderer)
            glamor_egl.dmabuf_capable = FALSE;
        else if (strstr(cast(const(char)*)renderer, "Intel"))
            glamor_egl.dmabuf_capable = TRUE;
        else if (strstr(cast(const(char)*)renderer, "zink"))
            glamor_egl.dmabuf_capable = TRUE;
        else if (strstr(cast(const(char)*)renderer, "NVIDIA"))
            glamor_egl.dmabuf_capable = TRUE;
        else if (strstr(cast(const(char)*)renderer, "radeonsi"))
            glamor_egl.dmabuf_capable = TRUE;
        else
            glamor_egl.dmabuf_capable = FALSE;
    }
}

static if (GLAMOR_HAS_GBM) {
    glamor_egl.fast_gbm_import = renderer && !strstr(cast(const(char)*)renderer, "NVIDIA");
}

    /* Check if at least one combination of format + modifier is supported */
    if (!glamor_get_formats_internal(glamor_egl, &num_formats, &formats)) {
        goto glamor_no_dri;
    }

    if (num_formats == 0) {
        found = TRUE;
    }

    for (uint i = 0; i < num_formats; i++) {
        ulong* modifiers = null;
        uint num_modifiers = 0;
        if (glamor_get_modifiers_internal(glamor_egl, cast(uint)formats[i],
                                          &num_modifiers, &modifiers)) {
            found = TRUE;
            free(modifiers);
            break;
        }
    }
    free(formats);

    if (!found) {
        LogMessage(X_ERROR,
                   "glamor: No combination of format + modifier is supported\n");
        goto glamor_no_dri;
    }

    if (caps) {
        *caps |= GLAMOR_EGL_DEFAULT_CAPS;
    }

    LogMessage(X_INFO, "glamor dri X acceleration enabled on %s\n",
               renderer);
    return TRUE;

error:
    LogMessage(X_ERROR, "glamor X acceleration failed to initialize\n");
    glamor_egl_cleanup(glamor_egl);
    return FALSE;

glamor_no_dri:
    glamor_egl.fd = -1;

    LogMessage(X_WARNING, "glamor X acceleration enabled without dri support on %s\n",
               renderer);
    return TRUE;
}
