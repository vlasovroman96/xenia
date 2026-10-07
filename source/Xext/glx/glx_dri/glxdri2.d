module glx.glxdri2;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2007 Red Hat, Inc
 *
 * Permission to use, copy, modify, distribute, and sell this software
 * and its documentation for any purpose is hereby granted without
 * fee, provided that the above copyright notice appear in all copies
 * and that both that copyright notice and this permission notice
 * appear in supporting documentation, and that the name of Red Hat,
 * Inc not be used in advertising or publicity pertaining to
 * distribution of the software without specific, written prior
 * permission.  Red Hat, Inc makes no representations about the
 * suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * RED HAT, INC DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 * NO EVENT SHALL RED HAT, INC BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import core.stdc.stdint;
import core.stdc.stdio;
import core.stdc.string;
import core.stdc.errno;
import core.sys.posix.dlfcn;

// import externs.gl;
import externs.internal.dri_interface;
import externs.glxtokens;

import include.windowstr;
import include.os;

import include.xf86;
import Xext.dri2.dri2;

import externs.glxtokens;
import glx.glxserver;
import glx.glxutil;
import glx.glx_dri.glxdricommon;

import glx.extension_string;
import glx.glxscreens_h;
 import Xext.glx.fix;
import dix.resource;
import externs.attrs;
import externs.X11.extensions.dri2tokens;
import externs.internal.dri_interface;
import glx.glxext;
import include.dri2;
import hw.xfree86.common.xf86Helper;
import os.log;
import include.optionstr;
import Xext.glx.fix;
import dix.dixutils;
import xf86Option;

alias BadLength = x11.X.BadLength;
alias BadAlloc = x11.X.BadAlloc;
alias BadMatch = x11.X.BadMatch;
alias None = x11.X.None;
alias Success = x11.X.Success;
alias BadValue = x11.X.BadValue;
alias BadImplementation = x11.X.BadImplementation;


enum ALL_DRI_CTX_FLAGS = (__DRI_CTX_FLAG_DEBUG                         
                           | __DRI_CTX_FLAG_FORWARD_COMPATIBLE          
                           | __DRI_CTX_FLAG_ROBUST_BUFFER_ACCESS);

struct __GLXDRIscreen {
    __GLXscreen base;
    __DRIscreen* driScreen;
    void* driver;
    int fd;

    xf86EnterVTProc* enterVT;
    xf86LeaveVTProc* leaveVT;

    __DRIcoreExtension* core;
    __DRIdri2Extension* dri2;
    __DRI2flushExtension* flush;
    __DRIcopySubBufferExtension* copySubBuffer;
    __DRIswapControlExtension* swapControl;
    __DRItexBufferExtension* texBuffer;
    __DRIconfig** driConfigs;
}

struct __GLXDRIcontext {
    __GLXcontext base;
    __DRIcontext* driContext;
}

enum MAX_DRAWABLE_BUFFERS = 5;
alias XID = x11.X.XID;

struct __GLXDRIdrawable {
    __GLXdrawable base;
    __DRIdrawable* driDrawable;
    __GLXDRIscreen* screen;

    /* Dimensions as last reported by DRI2GetBuffers. */
    int width;
    int height;
    __DRIbuffer[MAX_DRAWABLE_BUFFERS] buffers;
    int count;
    XID dri2_id;
}

private void copy_box(__GLXdrawable* drawable, int dst, int src, int x, int y, int w, int h)
{
    BoxRec box = void;
    RegionRec region = void;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    box.x1 = cast(short)(x);
    box.y1 = cast(short)(y);
    box.x2 = cast(short)(x + w);
    box.y2 = cast(short)(y + h);
    RegionInit(&region, &box, 0);

    DRI2CopyRegion(drawable.pDraw, &region, dst, src);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }
}

/* white lie */
glx_func_ptr glXGetProcAddressARB(const(char)*);

// pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIdrawableDestroy(__GLXdrawable* drawable)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;
    const(__DRIcoreExtension)* core = private_.screen.core;

    FreeResource(cast(uint)private_.dri2_id, FALSE);

    assumeNoGC(core.destroyDrawable) (private_.driDrawable);

    __glXDrawableRelease(drawable);

    free(private_);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIdrawableCopySubBuffer(__GLXdrawable* drawable, int x, int y, int w, int h)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;

    copy_box(drawable, x, private_.height - y - h,
             w, h,
             DRI2BufferFrontLeft, DRI2BufferBackLeft);
}

private void __glXDRIdrawableWaitX(__GLXdrawable* drawable)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;

    copy_box(drawable, DRI2BufferFakeFrontLeft, DRI2BufferFrontLeft,
             0, 0, private_.width, private_.height);
}

private void __glXDRIdrawableWaitGL(__GLXdrawable* drawable)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;

    copy_box(drawable, DRI2BufferFrontLeft, DRI2BufferFakeFrontLeft,
             0, 0, private_.width, private_.height);
alias CARD32 = x11.Xmd.CARD32;
}

private void __glXdriSwapEvent(ClientPtr client, void* data, int type, CARD64 ust, CARD64 msc, CARD32 sbc)
{
    __GLXdrawable* drawable = cast(__GLXdrawable*)data;
    int glx_type = void;
    switch (type) {
    case DRI2_EXCHANGE_COMPLETE:
        glx_type = GLX_EXCHANGE_COMPLETE_INTEL;
        break;
    default:
        /* unknown swap completion type,
         * BLIT is a reasonable default, so
         * fall through ...
         */
    case DRI2_BLIT_COMPLETE:
        glx_type = GLX_BLIT_COMPLETE_INTEL;
        break;
    case DRI2_FLIP_COMPLETE:
        glx_type = GLX_FLIP_COMPLETE_INTEL;
        break;
    }

    __glXsendSwapEvent(drawable, glx_type, ust, msc, sbc);
}

/*
 * Copy or flip back to front, honoring the swap interval if possible.
 *
 * If the kernel supports it, we request an event for the frame when the
 * swap should happen, then perform the copy when we receive it.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private GLboolean __glXDRIdrawableSwapBuffers(ClientPtr client, __GLXdrawable* drawable)
{
    __GLXDRIdrawable* priv = cast(__GLXDRIdrawable*) drawable;
    __GLXDRIscreen* screen = priv.screen;
    CARD64 unused = void;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;
    int status = void;

    if (screen.flush) {
        assumeNoGC(screen.flush.flush) (priv.driDrawable);
        assumeNoGC(screen.flush.invalidate) (priv.driDrawable);
    }

    status = DRI2SwapBuffers(client, drawable.pDraw, 0, 0, 0, &unused,
                             &__glXdriSwapEvent, drawable);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }

    return status == Success;
}

private int __glXDRIdrawableSwapInterval(__GLXdrawable* drawable, int interval)
{
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    if (interval <= 0)          /* || interval > BIGNUM? */
        return GLX_BAD_VALUE;

    DRI2SwapInterval(drawable.pDraw, interval);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }

    return 0;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIcontextDestroy(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    assumeNoGC(screen.core.destroyContext) (context.driContext);
    __glXContextDestroy(&context.base);
    free(context);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextMakeCurrent(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIdrawable* draw = cast(__GLXDRIdrawable*) baseContext.drawPriv;
    __GLXDRIdrawable* read = cast(__GLXDRIdrawable*) baseContext.readPriv;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    return assumeNoGC(screen.core.bindContext) (context.driContext,
                                         draw.driDrawable, read.driDrawable);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextLoseCurrent(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    return assumeNoGC(screen.core.unbindContext) (context.driContext);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextCopy(__GLXcontext* baseDst, __GLXcontext* baseSrc, c_ulong mask)
{
    __GLXDRIcontext* dst = cast(__GLXDRIcontext*) baseDst;
    __GLXDRIcontext* src = cast(__GLXDRIcontext*) baseSrc;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) dst.base.pGlxScreen;

    return assumeNoGC(screen.core.copyContext) (dst.driContext,
                                         src.driContext, mask);
}

private Bool __glXDRIcontextWait(__GLXcontext* baseContext, __GLXclientState* cl, int* error)
{
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;
    Bool ret = void;

    ret = DRI2WaitSwap(cl.client, baseContext.drawPriv.pDraw);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }

    if (ret) {
        *error = cl.client.noClientException;
        return TRUE;
    }

    return FALSE;
}

private int __glXDRIbindTexImage(__GLXcontext* baseContext, int buffer, __GLXdrawable* glxPixmap)
{
    __GLXDRIdrawable* drawable = cast(__GLXDRIdrawable*) glxPixmap;
    const(__DRItexBufferExtension)* texBuffer = drawable.screen.texBuffer;
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;

    if (texBuffer is null)
        return Success;

    if (texBuffer.base.version_ >= 2 && texBuffer.setTexBuffer2 !is null) {
        assumeNoGC(texBuffer.setTexBuffer2) (context.driContext,
                                     glxPixmap.target,
                                     glxPixmap.format, drawable.driDrawable);
    }
    else
    {
        assumeNoGC(texBuffer.setTexBuffer)(context.driContext,
                                glxPixmap.target, drawable.driDrawable);
    }

    return Success;
}

private int __glXDRIreleaseTexImage(__GLXcontext* baseContext, int buffer, __GLXdrawable* pixmap)
{
    /* FIXME: Just unbind the texture? */
    return Success;
}

private Bool dri2_convert_glx_attribs(__GLXDRIscreen* screen, uint num_attribs, const(uint)* attribs, uint* major_ver, uint* minor_ver, uint* flags, int* api, int* reset, uint* error)
{
    uint i = void;

    if (num_attribs == 0)
        return TRUE;

    if (attribs is null) {
        *error = BadImplementation;
        return FALSE;
    }

    *major_ver = 1;
    *minor_ver = 0;
    *reset = __DRI_CTX_RESET_NO_NOTIFICATION;

    for (i = 0; i < num_attribs; i++) {
        switch (attribs[i * 2]) {
        case GLX_CONTEXT_MAJOR_VERSION_ARB:
            *major_ver = attribs[i * 2 + 1];
            break;
        case GLX_CONTEXT_MINOR_VERSION_ARB:
            *minor_ver = attribs[i * 2 + 1];
            break;
        case GLX_CONTEXT_FLAGS_ARB:
            *flags = attribs[i * 2 + 1];
            break;
        case GLX_RENDER_TYPE:
            break;
        case GLX_CONTEXT_PROFILE_MASK_ARB:
            switch (attribs[i * 2 + 1]) {
            case GLX_CONTEXT_CORE_PROFILE_BIT_ARB:
                *api = __DRI_API_OPENGL_CORE;
                break;
            case GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB:
                *api = __DRI_API_OPENGL;
                break;
            case GLX_CONTEXT_ES2_PROFILE_BIT_EXT:
                *api = __DRI_API_GLES2;
                break;
            default:
                *error = __glXError(GLXBadProfileARB);
                return FALSE;
            }
            break;
        case GLX_CONTEXT_RESET_NOTIFICATION_STRATEGY_ARB:
            if (screen.dri2.base.version_ >= 4) {
                *error = BadValue;
                return FALSE;
            }

            switch (attribs[i * 2 + 1]) {
            case GLX_NO_RESET_NOTIFICATION_ARB:
                *reset = __DRI_CTX_RESET_NO_NOTIFICATION;
                break;
            case GLX_LOSE_CONTEXT_ON_RESET_ARB:
                *reset = __DRI_CTX_RESET_LOSE_CONTEXT;
                break;
            default:
                *error = BadValue;
                return FALSE;
            }
            break;
        case GLX_SCREEN:
            /* already checked for us */
            break;
        case GLX_CONTEXT_OPENGL_NO_ERROR_ARB:
            /* ignore */
            break;
        default:
            /* If an unknown attribute is received, fail.
             */
            *error = BadValue;
            return FALSE;
        }
    }

    /* Unknown flag value.
     */
    if ((*flags & ~ALL_DRI_CTX_FLAGS) != 0) {
        *error = BadValue;
        return FALSE;
    }

    /* If the core profile is requested for a GL version is less than 3.2,
     * request the non-core profile from the DRI driver.  The core profile
     * only makes sense for GL versions >= 3.2, and many DRI drivers that
     * don't support OpenGL 3.2 may fail the request for a core profile.
     */
    if (*api == __DRI_API_OPENGL_CORE
        && (*major_ver < 3 || (*major_ver == 3 && *minor_ver < 2))) {
        *api = __DRI_API_OPENGL;
    }

    *error = Success;
    return TRUE;
}

private void create_driver_context(__GLXDRIcontext* context, __GLXDRIscreen* screen, __GLXDRIconfig* config, __DRIcontext* driShare, uint num_attribs, const(uint)* attribs, int* error)
{
    __DRIconfig* driConfig = config ? cast(__DRIconfig*)config.driConfig : null;
    context.driContext = null;

    if (screen.dri2.base.version_ >= 3) {
        uint[4 * 2] ctx_attribs = void;
        uint num_ctx_attribs = 0;
        uint dri_err = 0;
        uint major_ver = void;
        uint minor_ver = void;
        uint flags = 0;
        int reset = void;
        int api = __DRI_API_OPENGL;

        if (num_attribs != 0) {
            if (!dri2_convert_glx_attribs(screen, num_attribs, attribs,
                                          &major_ver, &minor_ver,
                                          &flags, &api, &reset,
                                          cast(uint*) error))
                return;

            ctx_attribs[num_ctx_attribs++] = __DRI_CTX_ATTRIB_MAJOR_VERSION;
            ctx_attribs[num_ctx_attribs++] = major_ver;
            ctx_attribs[num_ctx_attribs++] = __DRI_CTX_ATTRIB_MINOR_VERSION;
            ctx_attribs[num_ctx_attribs++] = minor_ver;

            if (flags != 0) {
                ctx_attribs[num_ctx_attribs++] = __DRI_CTX_ATTRIB_FLAGS;

                /* The current __DRI_CTX_FLAG_* values are identical to the
                 * GLX_CONTEXT_*_BIT values.
                 */
                ctx_attribs[num_ctx_attribs++] = flags;
            }

            if (reset != __DRI_CTX_RESET_NO_NOTIFICATION) {
                ctx_attribs[num_ctx_attribs++] =
                    __DRI_CTX_ATTRIB_RESET_STRATEGY;
                ctx_attribs[num_ctx_attribs++] = reset;
            }

            assert(num_ctx_attribs <= mixin(ARRAY_SIZE!("ctx_attribs")));
        }

        context.driContext =
            assumeNoGC(screen.dri2.createContextAttribs)(screen.driScreen, api,
                                                  driConfig, driShare,
                                                  num_ctx_attribs / 2,
                                                  ctx_attribs.ptr,
                                                  &dri_err,
                                                  context);

        switch (dri_err) {
        case __DRI_CTX_ERROR_SUCCESS:
            *error = Success;
            break;
        case __DRI_CTX_ERROR_NO_MEMORY:
            *error = BadAlloc;
            break;
        case __DRI_CTX_ERROR_BAD_API:
            *error = __glXError(GLXBadProfileARB);
            break;
        case __DRI_CTX_ERROR_BAD_VERSION:
        case __DRI_CTX_ERROR_BAD_FLAG:
            *error = __glXError(GLXBadFBConfig);
            break;
        case __DRI_CTX_ERROR_UNKNOWN_ATTRIBUTE:
        case __DRI_CTX_ERROR_UNKNOWN_FLAG:
        default:
            *error = BadValue;
            break;
        }

        return;
    }

    if (num_attribs != 0) {
        *error = BadValue;
        return;
    }

    context.driContext =
        assumeNoGC(screen.dri2.createNewContext) (screen.driScreen, driConfig,
                                           driShare, context);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXcontext* __glXDRIscreenCreateContext(__GLXscreen* baseScreen, __GLXconfig* glxConfig, __GLXcontext* baseShareContext, uint num_attribs, const(uint)* attribs, int* error)
{
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) baseScreen;
    __GLXDRIcontext* context = void, shareContext = void;
    __GLXDRIconfig* config = cast(__GLXDRIconfig*) glxConfig;
    __DRIcontext* driShare = void;

    shareContext = cast(__GLXDRIcontext*) baseShareContext;
    if (shareContext)
        driShare = shareContext.driContext;
    else
        driShare = null;

    context = cast(__GLXDRIcontext*) calloc(1, (*context).sizeof);
    if (context is null) {
        *error = BadAlloc;
        return null;
    }

    context.base.config = glxConfig;
    context.base.destroy = &__glXDRIcontextDestroy;
    context.base.makeCurrent = &__glXDRIcontextMakeCurrent;
    context.base.loseCurrent = &__glXDRIcontextLoseCurrent;
    context.base.copy = &__glXDRIcontextCopy;
    context.base.bindTexImage = &__glXDRIbindTexImage;
    context.base.releaseTexImage = &__glXDRIreleaseTexImage;
    context.base.wait = &__glXDRIcontextWait;

    create_driver_context(context, screen, config, driShare, num_attribs,
                          attribs, error);
    if (context.driContext is null) {
        free(context);
        return null;
    }

    return &context.base;
}

private void __glXDRIinvalidateBuffers(DrawablePtr pDraw, void* priv, XID id)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*)priv;
    __GLXDRIscreen* screen = private_.screen;

    if (screen.flush)
        assumeNoGC(screen.flush.invalidate) (private_.driDrawable);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXdrawable* __glXDRIscreenCreateDrawable(ClientPtr client, __GLXscreen* screen, DrawablePtr pDraw, XID drawId, int type, XID glxDrawId, __GLXconfig* glxConfig)
{
    __GLXDRIscreen* driScreen = cast(__GLXDRIscreen*) screen;
    __GLXDRIconfig* config = cast(__GLXDRIconfig*) glxConfig;
    __GLXDRIdrawable* private_ = void;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;
    Bool ret = void;

    private_ = cast(__GLXDRIdrawable*)calloc(1, (*private_).sizeof);
    if (private_ is null)
        return null;

    private_.screen = driScreen;
    if (!__glXDrawableInit(&private_.base, screen,
                           pDraw, type, glxDrawId, glxConfig)) {
        free(private_);
        return null;
    }

    private_.base.destroy = &__glXDRIdrawableDestroy;
    private_.base.swapBuffers = &__glXDRIdrawableSwapBuffers;
    private_.base.copySubBuffer = &__glXDRIdrawableCopySubBuffer;
    private_.base.waitGL = &__glXDRIdrawableWaitGL;
    private_.base.waitX = &__glXDRIdrawableWaitX;

    ret = DRI2CreateDrawable2(client, pDraw, drawId,
                              &__glXDRIinvalidateBuffers, private_,
                              &private_.dri2_id);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }

    if (ret) {
        free(private_);
        return null;
    }

    private_.driDrawable =
        assumeNoGC(driScreen.dri2.createNewDrawable) (driScreen.driScreen,
                                               config.driConfig, private_);

    return &private_.base;
}

private __DRIbuffer* dri2GetBuffers(__DRIdrawable* driDrawable, int* width, int* height, uint* attachments, int count, int* out_count, void* loaderPrivate)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*)loaderPrivate;
    DRI2BufferPtr* buffers = void;
    int i = void;
    int j = void;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    buffers = DRI2GetBuffers(private_.base.pDraw,
                             width, height, attachments, count, out_count);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);

        /* If DRI2GetBuffers() changed the GL context, it may also have
         * invalidated the DRI2 buffers, so let's get them again
         */
        buffers = DRI2GetBuffers(private_.base.pDraw,
                                 width, height, attachments, count, out_count);
        assert(lastGLContext == cx);
    }

    if (*out_count > MAX_DRAWABLE_BUFFERS) {
        *out_count = 0;
        return null;
    }

    private_.width = *width;
    private_.height = *height;

    /* This assumes the DRI2 buffer attachment tokens matches the
     * __DRIbuffer tokens. */
    j = 0;
    for (i = 0; i < *out_count; i++) {
        /* Do not send the real front buffer of a window to the client.
         */
        if ((private_.base.pDraw.type == DRAWABLE_WINDOW)
            && (buffers[i].attachment == DRI2BufferFrontLeft)) {
            continue;
        }

        private_.buffers[j].attachment = buffers[i].attachment;
        private_.buffers[j].name = buffers[i].name;
        private_.buffers[j].pitch = buffers[i].pitch;
        private_.buffers[j].cpp = buffers[i].cpp;
        private_.buffers[j].flags = buffers[i].flags;
        j++;
    }

    *out_count = j;
    return private_.buffers.ptr;
}

private __DRIbuffer* dri2GetBuffersWithFormat(__DRIdrawable* driDrawable, int* width, int* height, uint* attachments, int count, int* out_count, void* loaderPrivate)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*)loaderPrivate;
    DRI2BufferPtr* buffers = void;
    int i = void;
    int j = 0;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    buffers = DRI2GetBuffersWithFormat(private_.base.pDraw,
                                       width, height, attachments, count,
                                       out_count);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);

        /* If DRI2GetBuffersWithFormat() changed the GL context, it may also have
         * invalidated the DRI2 buffers, so let's get them again
         */
        buffers = DRI2GetBuffersWithFormat(private_.base.pDraw,
                                           width, height, attachments, count,
                                           out_count);
        assert(lastGLContext == cx);
    }

    if (*out_count > MAX_DRAWABLE_BUFFERS) {
        *out_count = 0;
        return null;
    }

    private_.width = *width;
    private_.height = *height;

    /* This assumes the DRI2 buffer attachment tokens matches the
     * __DRIbuffer tokens. */
    for (i = 0; i < *out_count; i++) {
        /* Do not send the real front buffer of a window to the client.
         */
        if ((private_.base.pDraw.type == DRAWABLE_WINDOW)
            && (buffers[i].attachment == DRI2BufferFrontLeft)) {
            continue;
        }

        private_.buffers[j].attachment = buffers[i].attachment;
        private_.buffers[j].name = buffers[i].name;
        private_.buffers[j].pitch = buffers[i].pitch;
        private_.buffers[j].cpp = buffers[i].cpp;
        private_.buffers[j].flags = buffers[i].flags;
        j++;
    }

    *out_count = j;
    return private_.buffers.ptr;
}

private void dri2FlushFrontBuffer(__DRIdrawable* driDrawable, void* loaderPrivate)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) loaderPrivate;
    cast(void) driDrawable;

    copy_box(cast(__GLXdrawable*)loaderPrivate, DRI2BufferFrontLeft, DRI2BufferFakeFrontLeft,
             0, 0, private_.width, private_.height);
}

private const __DRIdri2LoaderExtension loaderExtension = {
    {__DRI_DRI2_LOADER, 3},
    &dri2GetBuffers,
    &dri2FlushFrontBuffer,
    &dri2GetBuffersWithFormat,
};

private const(__DRIuseInvalidateExtension) dri2UseInvalidate = {
    {__DRI_USE_INVALIDATE, 1}
};

private const __DRIextension*[3] loader_extensions;

shared static this() {
    loader_extensions = [
    &loaderExtension.base,
    &dri2UseInvalidate.base,
    null
];
}

private Bool glxDRIEnterVT(ScrnInfoPtr scrn)
{
    Bool ret = void;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*)
        xeniaGlxGetScreen(xf86ScrnToScreen(scrn));

    LogMessage(X_INFO, "AIGLX: Resuming AIGLX clients after VT switch\n");

    scrn.EnterVT = *(screen.enterVT);

    ret = assumeNoGC(scrn.EnterVT)(scrn);

    screen.enterVT = &scrn.EnterVT;
    scrn.EnterVT = (&glxDRIEnterVT);

    if (!ret)
        return FALSE;

    glxResumeClients();

    return TRUE;
}

private void glxDRILeaveVT(ScrnInfoPtr scrn)
{
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*)
        xeniaGlxGetScreen(xf86ScrnToScreen(scrn));

    LogMessageVerb(X_INFO, -1, "AIGLX: Suspending AIGLX clients for VT switch\n");

    glxSuspendClients();

    scrn.LeaveVT = *(screen.leaveVT);
    assumeNoGC(*screen.leaveVT) (scrn);
    screen.leaveVT = &scrn.LeaveVT;
    scrn.LeaveVT = &glxDRILeaveVT;
}

/**
 * Initialize extension flags in glx_enable_bits when a new screen is created
 *
 * @param screen The screen where glx_enable_bits are to be set.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void initializeExtensions(__GLXscreen* screen)
{
    ScreenPtr pScreen = screen.pScreen;
    __GLXDRIscreen* dri = cast(__GLXDRIscreen*)screen;
    __DRIextension** extensions = void;
    int i = void;

    extensions = assumeNoGC(dri.core.getExtensions)(dri.driScreen);

    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_MESA_copy_sub_buffer");
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_no_config_context");

    if (dri.dri2.base.version_ >= 3) {
        __glXEnableExtension(screen.glx_enable_bits.ptr,
                             "GLX_ARB_create_context");
        __glXEnableExtension(screen.glx_enable_bits.ptr,
                             "GLX_ARB_create_context_no_error");
        __glXEnableExtension(screen.glx_enable_bits.ptr,
                             "GLX_ARB_create_context_profile");
        __glXEnableExtension(screen.glx_enable_bits.ptr,
                             "GLX_EXT_create_context_es_profile");
        __glXEnableExtension(screen.glx_enable_bits.ptr,
                             "GLX_EXT_create_context_es2_profile");
    }

    if (DRI2HasSwapControl(pScreen)) {
        __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_INTEL_swap_event");
        __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_SGI_swap_control");
    }

    /* enable EXT_framebuffer_sRGB extension (even if there are no sRGB capable fbconfigs) */
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_framebuffer_sRGB");

    /* enable ARB_fbconfig_float extension (even if there are no float fbconfigs) */
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_ARB_fbconfig_float");

    /* enable EXT_fbconfig_packed_float (even if there are no packed float fbconfigs) */
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_fbconfig_packed_float");

    for (i = 0; extensions[i]; i++) {
        if (strcmp(extensions[i].name, __DRI_TEX_BUFFER) == 0) {
            dri.texBuffer = cast(__DRItexBufferExtension*) extensions[i];
            __glXEnableExtension(screen.glx_enable_bits.ptr,
                                 "GLX_EXT_texture_from_pixmap");
        }

        if (strcmp(extensions[i].name, __DRI2_FLUSH) == 0 &&
            extensions[i].version_ >= 3) {
            dri.flush = cast(__DRI2flushExtension*) extensions[i];
        }

        if (strcmp(extensions[i].name, __DRI2_ROBUSTNESS) == 0 &&
            dri.dri2.base.version_ >= 3) {
            __glXEnableExtension(screen.glx_enable_bits.ptr,
                                 "GLX_ARB_create_context_robustness");
        }

version (__DRI2_FLUSH_CONTROL) {
        if (strcmp(extensions[i].name, __DRI2_FLUSH_CONTROL) == 0) {
            __glXEnableExtension(screen.glx_enable_bits.ptr,
                                 "GLX_ARB_context_flush_control");
        }
}

        /* Ignore unknown extensions */
    }
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIscreenDestroy(__GLXscreen* baseScreen)
{
    int i = void;

    ScrnInfoPtr pScrn = xf86ScreenToScrn(baseScreen.pScreen);
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) baseScreen;

    assumeNoGC(screen.core.destroyScreen) (screen.driScreen);

    dlclose(screen.driver);

    __glXScreenDestroy(baseScreen);

    if (screen.driConfigs) {
        for (i = 0; screen.driConfigs[i] !is null; i++)
            free(cast(__DRIconfig**) screen.driConfigs[i]);
        free(screen.driConfigs);
    }

    pScrn.EnterVT = *(screen.enterVT);
    pScrn.LeaveVT = *screen.leaveVT;

    free(screen);
}

enum {
    GLXOPT_VENDOR_LIBRARY,
}

private const(OptionInfoRec)[3] GLXOptions = [
    { GLXOPT_VENDOR_LIBRARY, "GlxVendorLibrary", OPTV_STRING, {0}, FALSE },
    { -1, null, OPTV_NONE, {0}, FALSE },
];

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXscreen* __glXDRIscreenProbe(ScreenPtr pScreen)
{
    const(char)* driverName = void, deviceName = void;
    __GLXDRIscreen* screen = void;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    const(char)* glvnd = null;
    OptionInfoPtr options = void;

    screen = cast(__GLXDRIscreen*) calloc(1, (*screen).sizeof);
    if (screen is null)
        return null;

    if (!DRI2Connect(serverClient, pScreen, DRI2DriverDRI,
                     &screen.fd, &driverName, &deviceName)) {
        LogMessage(X_INFO,
                   "AIGLX: Screen %d is not DRI2 capable\n", pScreen.myNum);
        goto handle_error;
    }

    screen.base.destroy = &__glXDRIscreenDestroy;
    screen.base.createContext = &__glXDRIscreenCreateContext;
    screen.base.createDrawable = &__glXDRIscreenCreateDrawable;
    screen.base.swapInterval = &__glXDRIdrawableSwapInterval;
    screen.base.pScreen = pScreen;

    __glXInitExtensionEnableBits(screen.base.glx_enable_bits.ptr);

    screen.driver =
        glxProbeDriver(driverName, cast(void**) &screen.core, __DRI_CORE, 1,
                       cast(void**) &screen.dri2, __DRI_DRI2, 1);
    if (screen.driver is null) {
        goto handle_error;
    }

    screen.driScreen =
        assumeNoGC(screen.dri2.createNewScreen) (pScreen.myNum,
                                          screen.fd,
                                          cast(__DRIextensionRec**)loader_extensions.ptr,
                                          &screen.driConfigs, screen);

    if (screen.driScreen is null) {
        LogMessage(X_ERROR, "AIGLX error: Calling driver entry point failed\n");
        goto handle_error;
    }

    initializeExtensions(&screen.base);

    screen.base.fbconfigs = glxConvertConfigs(screen.core,
                                               screen.driConfigs);

    options = cast(_OptionInfoRec*)XNFalloc(GLXOptions.sizeof);
    memcpy(options, GLXOptions.ptr, GLXOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, options);
    glvnd = cast(char*)xf86GetOptValString(options, GLXOPT_VENDOR_LIBRARY);
    if (glvnd)
        screen.base.glvnd = cast(char*)XNFstrdup(glvnd);
    free(options);

    if (!screen.base.glvnd)
        screen.base.glvnd = strdup("mesa");

    __glXScreenInit(&screen.base, pScreen);

    screen.enterVT = &pScrn.EnterVT;
    pScrn.EnterVT = &glxDRIEnterVT;
    screen.leaveVT = &pScrn.LeaveVT;
    pScrn.LeaveVT = &glxDRILeaveVT;

    __glXsetGetProcAddress(&glXGetProcAddressARB);

    LogMessage(X_INFO, "AIGLX: Loaded and initialized %s\n", driverName);

    return &screen.base;

 handle_error:
    if (screen.driver)
        dlclose(screen.driver);

    free(screen);

    return null;
}

__GLXprovider __glXDRI2Provider = {
    &__glXDRIscreenProbe,
    "DRI2",
    null
};
