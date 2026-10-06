module glx.glx_dri.glxdriswrast;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2008 George Sapountzis <gsap7@yahoo.gr>
 * Copyright © 2008 Red Hat, Inc
 *
 * Permission to use, copy, modify, distribute, and sell this software
 * and its documentation for any purpose is hereby granted without
 * fee, provided that the above copyright notice appear in all copies
 * and that both that copyright notice and this permission notice
 * appear in supporting documentation, and that the name of the
 * copyright holders not be used in advertising or publicity
 * pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no
 * representations about the suitability of this software for any
 * purpose.  It is provided "as is" without express or implied
 * warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
 * SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
 * SOFTWARE.
 */

import build.dix_config;

import core.stdc.stdint;
import core.stdc.stdio;
import core.stdc.string;
import core.stdc.errno;
import core.sys.posix.sys.time;
import core.sys.posix.dlfcn;

// import externs.gl;
import externs.internal.dri_interface;
import externs.glxtokens;

import include.scrnintstr;
import include.pixmapstr;
import include.gcstruct;
import include.os;

import glx.glxserver;
import glx.glxutil;
import glx.glx_dri.glxdricommon;

import glx.extension_string;
import glx.glxscreens_h;
 import Xext.glx.fix;
 import externs.attrs;
import dix.gc;
import os.log;
import glx.glxext;
import dix.dixutils;

//!! EDX: Duuuude...
alias BadLength = x11.X.BadLength;
alias BadAlloc = x11.X.BadAlloc;
alias BadMatch = x11.X.BadMatch;
alias None = x11.X.None;
alias Success = x11.X.Success;
alias BadValue = x11.X.BadValue;
alias BadImplementation = x11.X.BadImplementation;
alias ZPixmap = x11.X.ZPixmap;
alias IncludeInferiors = x11.X.IncludeInferiors;



struct __GLXDRIscreen {
    __GLXscreen base;
    __DRIscreen* driScreen;
    void* driver;

    __DRIcoreExtension* core;
    __DRIswrastExtension* swrast;
    __DRIcopySubBufferExtension* copySubBuffer;
    __DRItexBufferExtension* texBuffer;
    __DRIconfig** driConfigs;
}

struct __GLXDRIcontext {
    __GLXcontext base;
    __DRIcontext* driContext;
}

struct __GLXDRIdrawable {
    __GLXdrawable base;
    __DRIdrawable* driDrawable;
    __GLXDRIscreen* screen;
}

/* white lie */
glx_func_ptr glXGetProcAddressARB(const(char)*);

// pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIdrawableDestroySW(__GLXdrawable* drawable)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;
    const(__DRIcoreExtension)* core = private_.screen.core;

    assumeNoGC(core.destroyDrawable) (private_.driDrawable);

    __glXDrawableRelease(drawable);

    free(private_);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private GLboolean __glXDRIdrawableSwapBuffersSW(ClientPtr client, __GLXdrawable* drawable)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) drawable;
    const(__DRIcoreExtension)* core = private_.screen.core;

    assumeNoGC(core.swapBuffers) (private_.driDrawable);

    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIdrawableCopySubBufferSW(__GLXdrawable* basePrivate, int x, int y, int w, int h)
{
    __GLXDRIdrawable* private_ = cast(__GLXDRIdrawable*) basePrivate;
    const(__DRIcopySubBufferExtension)* copySubBuffer = private_.screen.copySubBuffer;

    if (copySubBuffer)
        assumeNoGC(copySubBuffer.copySubBuffer) (private_.driDrawable, x, y, w, h);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIcontextDestroySW(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    assumeNoGC(screen.core.destroyContext) (context.driContext);
    __glXContextDestroy(&context.base);
    free(context);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextMakeCurrentSW(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIdrawable* draw = cast(__GLXDRIdrawable*) baseContext.drawPriv;
    __GLXDRIdrawable* read = cast(__GLXDRIdrawable*) baseContext.readPriv;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    return assumeNoGC(screen.core.bindContext) (context.driContext,
                                         draw.driDrawable, read.driDrawable);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextLoseCurrentSW(__GLXcontext* baseContext)
{
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) context.base.pGlxScreen;

    return assumeNoGC(screen.core.unbindContext) (context.driContext);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private int __glXDRIcontextCopySW(__GLXcontext* baseDst, __GLXcontext* baseSrc, c_ulong mask)
{
    __GLXDRIcontext* dst = cast(__GLXDRIcontext*) baseDst;
    __GLXDRIcontext* src = cast(__GLXDRIcontext*) baseSrc;
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) dst.base.pGlxScreen;

    return assumeNoGC(screen.core.copyContext) (dst.driContext,
                                         src.driContext, mask);
}

private int __glXDRIbindTexImage(__GLXcontext* baseContext, int buffer, __GLXdrawable* glxPixmap)
{
    __GLXDRIdrawable* drawable = cast(__GLXDRIdrawable*) glxPixmap;
    const(__DRItexBufferExtension)* texBuffer = drawable.screen.texBuffer;
    __GLXDRIcontext* context = cast(__GLXDRIcontext*) baseContext;

    if (texBuffer is null)
        return Success;

static if (__DRI_TEX_BUFFER_VERSION >= 2) {
    if (texBuffer.base.version_ >= 2 && texBuffer.setTexBuffer2 !is null) {
        assumeNoGC(texBuffer.setTexBuffer2) (context.driContext,
                                     glxPixmap.target,
                                     glxPixmap.format, drawable.driDrawable);
    }
    else
            assumeNoGC(texBuffer.setTexBuffer)(context.driContext,
                                glxPixmap.target, drawable.driDrawable);
}
else {
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

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXcontext* __glXDRIscreenCreateContextSW(__GLXscreen* baseScreen, __GLXconfig* glxConfig, __GLXcontext* baseShareContext, uint num_attribs, const(uint)* attribs, int* error)
{
    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) baseScreen;
    __GLXDRIcontext* context = void, shareContext = void;
    __GLXDRIconfig* config = cast(__GLXDRIconfig*) glxConfig;
    __DRIconfig* driConfig = config ? config.driConfig : null;
    __DRIcoreExtension* core = screen.core;
    __DRIcontext* driShare = void;

    /* DRISWRAST won't support createContextAttribs, so these parameters will
     * never be used.
     */
    cast(void) num_attribs;
    cast(void) attribs;
    cast(void) error;

    shareContext = cast(__GLXDRIcontext*) baseShareContext;
    if (shareContext)
        driShare = shareContext.driContext;
    else
        driShare = null;

    context = cast(__GLXDRIcontext*) calloc(1, (*context).sizeof);
    if (context is null)
        return null;

    context.base.config = glxConfig;
    context.base.destroy = &__glXDRIcontextDestroySW;
    context.base.makeCurrent = &__glXDRIcontextMakeCurrentSW;
    context.base.loseCurrent = &__glXDRIcontextLoseCurrentSW;
    context.base.copy = &__glXDRIcontextCopySW;
    context.base.bindTexImage = &__glXDRIbindTexImage;
    context.base.releaseTexImage = &__glXDRIreleaseTexImage;

    context.driContext =
        assumeNoGC(core.createNewContext) (screen.driScreen, driConfig, driShare,
                                   context);

    return &context.base;
}
// alias XID = x11.X.XID;
alias XID = x11.X.XID;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXdrawable* __glXDRIscreenCreateDrawableSW(ClientPtr client, __GLXscreen* screen, DrawablePtr pDraw, XID drawId, int type, XID glxDrawId, __GLXconfig* glxConfig)
{
    __GLXDRIscreen* driScreen = cast(__GLXDRIscreen*) screen;
    __GLXDRIconfig* config = cast(__GLXDRIconfig*) glxConfig;
    __GLXDRIdrawable* private_ = void;

    private_ = cast(__GLXDRIdrawable*)calloc(1, (*private_).sizeof);
    if (private_ is null)
        return null;

    private_.screen = driScreen;
    if (!__glXDrawableInit(&private_.base, screen,
                           pDraw, type, glxDrawId, glxConfig)) {
        free(private_);
        return null;
    }

    private_.base.destroy = &__glXDRIdrawableDestroySW;
    private_.base.swapBuffers = &__glXDRIdrawableSwapBuffersSW;
    private_.base.copySubBuffer = &__glXDRIdrawableCopySubBufferSW;

    private_.driDrawable =
        assumeNoGC(driScreen.swrast.createNewDrawable) (driScreen.driScreen,
                                                 config.driConfig, private_);

    return &private_.base;
}

private void swrastGetDrawableInfo(__DRIdrawable* draw, int* x, int* y, int* w, int* h, void* loaderPrivate)
{
    __GLXDRIdrawable* drawable = cast(__GLXDRIdrawable*)loaderPrivate;
    DrawablePtr pDraw = drawable.base.pDraw;

    *x = pDraw.x;
    *y = pDraw.y;
    *w = pDraw.width;
    *h = pDraw.height;
}

private void swrastPutImage(__DRIdrawable* draw, int op, int x, int y, int w, int h, char* data, void* loaderPrivate)
{
    __GLXDRIdrawable* drawable = cast(__GLXDRIdrawable*)loaderPrivate;
    DrawablePtr pDraw = drawable.base.pDraw;
    GCPtr gc = void;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    if ((gc = GetScratchGC(pDraw.depth, pDraw.pScreen)) !is null) {
        ValidateGC(pDraw, gc);
        gc.ops.PutImage(pDraw, gc, pDraw.depth, x, y, w, h, 0, ZPixmap,
                          data);
        FreeScratchGC(gc);
    }

    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }
}

private void swrastGetImage(__DRIdrawable* draw, int x, int y, int w, int h, char* data, void* loaderPrivate)
{
    __GLXDRIdrawable* drawable = cast(__GLXDRIdrawable*)loaderPrivate;
    DrawablePtr pDraw = drawable.base.pDraw;
    ScreenPtr pScreen = pDraw.pScreen;
    __GLXcontext* cx = cast(__GLXcontext*)lastGLContext;

    pScreen.SourceValidate(pDraw, x, y, w, h, IncludeInferiors);
    pScreen.GetImage(pDraw, x, y, w, h, ZPixmap, ~0L, data);
    if (cx != lastGLContext) {
        lastGLContext = cx;
        cx.makeCurrent(cx);
    }
}

private const(__DRIswrastLoaderExtension) swrastLoaderExtension = {
    {__DRI_SWRAST_LOADER, 1},
    &swrastGetDrawableInfo,
    &swrastPutImage,
    &swrastGetImage
};

private const(__DRIextension)*[2] loader_extensions_swrast;

static this() {
    loader_extensions_swrast = [
    &swrastLoaderExtension.base,
    null
];
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void initializeExtensionsSW(__GLXscreen* screen)
{
    __DRIextension** extensions = void;
    __GLXDRIscreen* dri = cast(__GLXDRIscreen*)screen;
    int i = void;

    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_MESA_copy_sub_buffer");
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_no_config_context");

    if (dri.swrast.base.version_ >= 3) {
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

    /* these are harmless to enable unconditionally */
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_framebuffer_sRGB");
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_ARB_fbconfig_float");
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_fbconfig_packed_float");
    __glXEnableExtension(screen.glx_enable_bits.ptr, "GLX_EXT_texture_from_pixmap");

    extensions = assumeNoGC(dri.core.getExtensions)(dri.driScreen);

    for (i = 0; extensions[i]; i++) {
        if (strcmp(extensions[i].name, __DRI_COPY_SUB_BUFFER) == 0) {
            dri.copySubBuffer =
                cast(__DRIcopySubBufferExtension*) extensions[i];
        }

        if (strcmp(extensions[i].name, __DRI_TEX_BUFFER) == 0) {
            dri.texBuffer = cast(__DRItexBufferExtension*) extensions[i];
        }

version (__DRI2_FLUSH_CONTROL) {
        if (strcmp(extensions[i].name, __DRI2_FLUSH_CONTROL) == 0) {
            __glXEnableExtension(screen.glx_enable_bits,
                                 "GLX_ARB_context_flush_control");
        }
}

    }
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void __glXDRIscreenDestroySW(__GLXscreen* baseScreen)
{
    int i = void;

    __GLXDRIscreen* screen = cast(__GLXDRIscreen*) baseScreen;

    assumeNoGC(screen.core.destroyScreen) (screen.driScreen);

    dlclose(screen.driver);

    __glXScreenDestroy(baseScreen);

    if (screen.driConfigs) {
        for (i = 0; screen.driConfigs[i] !is null; i++)
            free(cast(__DRIconfig**) screen.driConfigs[i]);
        free(screen.driConfigs);
    }

    free(screen);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private __GLXscreen* __glXDRIscreenProbeSW(ScreenPtr pScreen)
{
    const(char)* driverName = "swrast";
    __GLXDRIscreen* screen = void;

    screen = cast(__GLXDRIscreen*) calloc(1, (*screen).sizeof);
    if (screen is null)
        return null;

    screen.base.destroy = &__glXDRIscreenDestroySW;
    screen.base.createContext = &__glXDRIscreenCreateContextSW;
    screen.base.createDrawable = &__glXDRIscreenCreateDrawableSW;
    screen.base.swapInterval = null;
    screen.base.pScreen = pScreen;

    __glXInitExtensionEnableBits(screen.base.glx_enable_bits.ptr);

    screen.driver = glxProbeDriver(driverName,
                                    cast(void**) &screen.core,
                                    __DRI_CORE, 1,
                                    cast(void**) &screen.swrast,
                                    __DRI_SWRAST, 1);
    if (screen.driver is null) {
        goto handle_error;
    }

    //!FIX THIS HACK
    screen.driScreen =
        assumeNoGC(screen.swrast.createNewScreen) (pScreen.myNum,
                                            cast(__DRIextensionRec**)loader_extensions_swrast.ptr,
                                            &screen.driConfigs, screen);

    if (screen.driScreen is null) {
        LogMessage(X_ERROR, "IGLX error: Calling driver entry point failed\n");
        goto handle_error;
    }

    initializeExtensionsSW(&screen.base);

    screen.base.fbconfigs = glxConvertConfigs(screen.core,
                                               screen.driConfigs);

static if (!HasVersion!"XQUARTZ" && !HasVersion!"Windows") {
    screen.base.glvnd = strdup("mesa");
}
    __glXScreenInit(&screen.base, pScreen);

    __glXsetGetProcAddress(&glXGetProcAddressARB);

    LogMessage(X_INFO, "IGLX: Loaded and initialized %s\n", driverName);

    return &screen.base;

 handle_error:
    if (screen.driver)
        dlclose(screen.driver);

    free(screen);

    LogMessage(X_ERROR, "GLX: could not load software renderer\n");

    return null;
}

__GLXprovider __glXDRISWRastProvider = {
    &__glXDRIscreenProbeSW,
    "DRISWRAST",
    null
};
