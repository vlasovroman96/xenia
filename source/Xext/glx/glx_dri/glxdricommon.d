module glx.glx_dri.glxdricommon;
@nogc nothrow:
extern(C): __gshared:
/*
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

import core.stdc.ctype;
import core.stdc.stdint;
import core.stdc.errno;
import core.sys.posix.dlfcn;
import core.sys.posix.sys.time;
// import externs.gl;
import externs.glxtokens;
import externs.internal.dri_interface;
import composite.compext;

import miext.extinit_priv;

import os.os;
import glx.glxserver;
import glx.glxext;
import glx.glxcontext;
import glx.glxscreens;
import glx.glx_dri.glxdricommon;
import glx.glxscreens_h;
 import Xext.glx.fix;
 import externs.attrs;
import externs.internal.dri_interface;
import glamor.glamor_glx_provider;
import Xext.glx.fix;
import os.log;
import externs.gnu;
import os.utils;

struct __GLXDRIconfig {
    __GLXconfig config;
    __DRIconfig *driConfig;
};

enum string __ATTRIB(string attrib, string field) = `
     _AttribMap(` ~ attrib ~ `, __GLXconfig.`~field~`.offsetof )`;

struct _AttribMap {
    uint attrib, offset;
}
private const(_AttribMap)[39] attribMap = [
    mixin(__ATTRIB!(`__DRI_ATTRIB_BUFFER_SIZE`, `rgbBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_LEVEL`, `level`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_RED_SIZE`, `redBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_GREEN_SIZE`, `greenBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_BLUE_SIZE`, `blueBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ALPHA_SIZE`, `alphaBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_DEPTH_SIZE`, `depthBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_STENCIL_SIZE`, `stencilBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ACCUM_RED_SIZE`, `accumRedBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ACCUM_GREEN_SIZE`, `accumGreenBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ACCUM_BLUE_SIZE`, `accumBlueBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ACCUM_ALPHA_SIZE`, `accumAlphaBits`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_SAMPLE_BUFFERS`, `sampleBuffers`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_SAMPLES`, `samples`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_DOUBLE_BUFFER`, `doubleBufferMode`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_STEREO`, `stereoMode`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_AUX_BUFFERS`, `numAuxBuffers`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_TYPE`, `transparentPixel`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_INDEX_VALUE`, `transparentPixel`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_RED_VALUE`, `transparentRed`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_GREEN_VALUE`, `transparentGreen`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_BLUE_VALUE`, `transparentBlue`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_TRANSPARENT_ALPHA_VALUE`, `transparentAlpha`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_RED_MASK`, `redMask`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_GREEN_MASK`, `greenMask`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_BLUE_MASK`, `blueMask`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_ALPHA_MASK`, `alphaMask`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_MAX_PBUFFER_WIDTH`, `maxPbufferWidth`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_MAX_PBUFFER_HEIGHT`, `maxPbufferHeight`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_MAX_PBUFFER_PIXELS`, `maxPbufferPixels`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_OPTIMAL_PBUFFER_WIDTH`, `optimalPbufferWidth`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_OPTIMAL_PBUFFER_HEIGHT`, `optimalPbufferHeight`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_SWAP_METHOD`, `swapMethod`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_BIND_TO_TEXTURE_RGB`, `bindToTextureRgb`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_BIND_TO_TEXTURE_RGBA`, `bindToTextureRgba`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_BIND_TO_MIPMAP_TEXTURE`, `bindToMipmapTexture`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_YINVERTED`, `yInverted`)),
        mixin(__ATTRIB!(`__DRI_ATTRIB_FRAMEBUFFER_SRGB_CAPABLE`, `sRGBCapable`)),
        ];

private void setScalar(__GLXconfig* config, uint attrib, uint value)
{
    int i = void;

    for (i = 0; i < attribMap.length; i++)
        if (attribMap[i].attrib == attrib) {
            *cast(uint*) (cast(char*) config + attribMap[i].offset) = value;
            return;
        }
}

private Bool render_type_is_pbuffer_only(uint renderType)
{
    /* The GL_ARB_color_buffer_float spec says:
     *
     *     "Note that floating point rendering is only supported for
     *     GLXPbuffer drawables.  The GLX_DRAWABLE_TYPE attribute of the
     *     GLXFBConfig must have the GLX_PBUFFER_BIT bit set and the
     *     GLX_RENDER_TYPE attribute must have the GLX_RGBA_FLOAT_BIT set."
     */
    return !!(renderType & (__DRI_ATTRIB_UNSIGNED_FLOAT_BIT
                            | __DRI_ATTRIB_FLOAT_BIT));
}

private int server_has_depth(int depth)
{
    int i = void;
    for (i = 0; i < screenInfo.numPixmapFormats; i++)
        if (screenInfo.formats[i].depth == depth)
            return 1;
    return 0;
}

private __GLXconfig* createModeFromConfig(__DRIcoreExtension* core, __DRIconfig* driConfig, uint visualType, GLboolean duplicateForComp)
{
    __GLXDRIconfig* config = void;
    GLint renderType = 0;
    uint attrib = void, value = void, drawableType = GLX_PBUFFER_BIT;
    int i = void;


    config = cast(__GLXDRIconfig*) calloc(1, (*config).sizeof);
    if (!config)
        return null;

    config.driConfig = driConfig;

    i = 0;
    while (assumeNoGC(core.indexConfigAttrib)(driConfig, i++, &attrib, &value)) {
        switch (attrib) {
        case __DRI_ATTRIB_RENDER_TYPE:
            if (value & __DRI_ATTRIB_RGBA_BIT)
                renderType |= GLX_RGBA_BIT;
            if (value & __DRI_ATTRIB_COLOR_INDEX_BIT)
                renderType |= GLX_COLOR_INDEX_BIT;
            if (value & __DRI_ATTRIB_FLOAT_BIT)
                renderType |= GLX_RGBA_FLOAT_BIT_ARB;
            if (value & __DRI_ATTRIB_UNSIGNED_FLOAT_BIT)
                renderType |= GLX_RGBA_UNSIGNED_FLOAT_BIT_EXT;
            break;
        case __DRI_ATTRIB_CONFIG_CAVEAT:
            if (value & __DRI_ATTRIB_NON_CONFORMANT_CONFIG)
                config.config.visualRating = GLX_NON_CONFORMANT_CONFIG;
            else if (value & __DRI_ATTRIB_SLOW_BIT)
                config.config.visualRating = GLX_SLOW_CONFIG;
            else
                config.config.visualRating = GLX_NONE;
            break;
        case __DRI_ATTRIB_BIND_TO_TEXTURE_TARGETS:
            config.config.bindToTextureTargets = 0;
            if (value & __DRI_ATTRIB_TEXTURE_1D_BIT)
                config.config.bindToTextureTargets |= GLX_TEXTURE_1D_BIT_EXT;
            if (value & __DRI_ATTRIB_TEXTURE_2D_BIT)
                config.config.bindToTextureTargets |= GLX_TEXTURE_2D_BIT_EXT;
            if (value & __DRI_ATTRIB_TEXTURE_RECTANGLE_BIT)
                config.config.bindToTextureTargets |=
                    GLX_TEXTURE_RECTANGLE_BIT_EXT;
            break;
        case __DRI_ATTRIB_SWAP_METHOD:
            /* Workaround for broken dri drivers */
            if (value != GLX_SWAP_UNDEFINED_OML &&
                value != GLX_SWAP_COPY_OML &&
                value != GLX_SWAP_EXCHANGE_OML)
                value = GLX_SWAP_UNDEFINED_OML;
            /* Fall through. */
            goto default;
        default:
            setScalar(&config.config, attrib, value);
            break;
        }
    }

    if (!render_type_is_pbuffer_only(renderType))
        drawableType |= GLX_WINDOW_BIT | GLX_PIXMAP_BIT;

    /* Make sure we don't advertise things the server isn't configured for */
    if ((drawableType & (GLX_PBUFFER_BIT | GLX_PIXMAP_BIT)) &&
        !server_has_depth(config.config.rgbBits)) {
        drawableType &= ~(GLX_PBUFFER_BIT | GLX_PIXMAP_BIT);
        if (!drawableType) {
            free(config);
            return null;
        }
    }

    config.config.next = null;
    config.config.visualType = visualType;
    config.config.renderType = renderType;
    config.config.drawableType = drawableType;
    config.config.yInverted = GL_TRUE;

    if (!noCompositeExtension) {
        /*
        * Here we decide what fbconfigs will be duplicated for compositing.
        * fgbconfigs marked with duplicatedForConf will be reserved for
        * compositing visuals.
        * It might look strange to do this decision this late when translation
        * from a __DRIConfig is already done, but using the __DRIConfig
        * accessor function becomes worse both with respect to code complexity
        * and CPU usage.
        */
        if (duplicateForComp &&
            (render_type_is_pbuffer_only(renderType) ||
            config.config.rgbBits != 32 ||
            config.config.redBits != 8 ||
            config.config.greenBits != 8 ||
            config.config.blueBits != 8 ||
            config.config.visualRating != GLX_NONE ||
            config.config.sampleBuffers != 0)) {
            free(config);
            return null;
        }

        config.config.duplicatedForComp = duplicateForComp;
    }

    return &config.config;
}

__GLXconfig* glxConvertConfigs(__DRIcoreExtension* core, __DRIconfig** configs)
{
    __GLXconfig head = void; __GLXconfig* tail = void;
    int i = void;

    tail = &head;
    head.next = null;

    for (i = 0; configs[i]; i++) {
        tail.next = createModeFromConfig(core, configs[i], GLX_TRUE_COLOR,
                                          GL_FALSE);
        if (tail.next is null)
            break;
        tail = tail.next;
    }

    for (i = 0; configs[i]; i++) {
        tail.next = createModeFromConfig(core, configs[i], GLX_DIRECT_COLOR,
                                          GL_FALSE);
        if (tail.next is null)
            break;

        tail = tail.next;
    }

    if (!noCompositeExtension) {
        /* Duplicate fbconfigs for use with compositing visuals */
        for (i = 0; configs[i]; i++) {
            tail.next = createModeFromConfig(core, configs[i], GLX_TRUE_COLOR,
                                            GL_TRUE);
            if (tail.next is null)
                continue;

            tail = tail.next;
        }
    }

    return head.next;
}

enum dri_driver_path = DRI_DRIVER_PATH;

/* Temporary define to allow building without a dri_interface.h from
 * updated Mesa.  Some day when we don't care about Mesa that old any
 * more this can be removed.
 */
enum __DRI_DRIVER_GET_EXTENSIONS = "__driDriverGetExtensions";


void* glxProbeDriver(const(char)* driverName, void** coreExt, const(char)* coreName, int coreVersion, void** renderExt, const(char)* renderName, int renderVersion)
{
    void* driver = void;
    char[PATH_MAX] filename = void;
    char* get_extensions_name = void;
    __DRIextension** extensions = null;
    const(char)* path = null;

    /* Search in LIBGL_DRIVERS_PATH if we're not setuid. */
    if (!PrivsElevated())
        path = getenv("LIBGL_DRIVERS_PATH");

    if (!path)
        path = dri_driver_path;

    do {
        const(char)* next = void;
        int path_len = void;

        next = strchr(path, ':');
        if (next) {
            path_len = cast(int)(next - path);
            next++;
        } else {
            path_len = cast(int)strlen(path);
            next = null;
        }

        snprintf(filename.ptr, filename.sizeof, "%.*s/%s_dri.so", path_len, path,
                 driverName);

        driver = dlopen(filename.ptr, RTLD_LAZY | RTLD_LOCAL);
        if (driver !is null)
            break;

        LogMessage(X_ERROR, "AIGLX error: dlopen of %s failed (%s)\n",
                   filename.ptr, dlerror());

        path = next;
    } while (path);

    if (driver is null) {
        LogMessage(X_ERROR, "AIGLX error: unable to load driver %s\n",
                  driverName);
        goto cleanup_failure;
    }

    if (asprintf(&get_extensions_name, "%s_%s".ptr,
                 __DRI_DRIVER_GET_EXTENSIONS.ptr, driverName) != -1) {
        __DRIextension** function() @nogc nothrow get_extensions = void;

        for (uint i = 0; i < strlen(get_extensions_name); i++) {
            /* Replace all non-alphanumeric characters with underscore,
             * since they are not allowed in C symbol names. That fixes up
             * symbol name for drivers with '-drm' suffix
             */
            if (!isalnum(cast(ubyte)get_extensions_name[i]))
                get_extensions_name[i] = '_';
        }

        get_extensions = cast(__DRIextensionRec** function() @nogc nothrow )dlsym(driver, get_extensions_name);
        if (get_extensions)
            extensions = get_extensions();
        free(get_extensions_name);
    }

    if (!extensions)
        extensions = cast(__DRIextensionRec**)dlsym(driver, __DRI_DRIVER_EXTENSIONS);
    if (extensions is null) {
        LogMessage(X_ERROR, "AIGLX error: %s exports no extensions (%s)\n",
                   driverName, dlerror());
        goto cleanup_failure;
    }

    for (uint i = 0; extensions[i]; i++) {
        if (strcmp(extensions[i].name, coreName) == 0 &&
            extensions[i].version_ >= coreVersion) {
            *coreExt = cast(void*) extensions[i];
        }

        if (strcmp(extensions[i].name, renderName) == 0 &&
            extensions[i].version_ >= renderVersion) {
            *renderExt = cast(void*) extensions[i];
        }
    }

    if (*coreExt is null || *renderExt is null) {
        LogMessage(X_ERROR,
                   "AIGLX error: %s does not export required DRI extension\n",
                   driverName);
        goto cleanup_failure;
    }
    return driver;

 cleanup_failure:
    if (driver)
        dlclose(driver);
    *coreExt = *renderExt = null;
    return null;
}
