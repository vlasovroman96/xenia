module hw.kdrive.ephyr.ephyr_glamor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

/** @file ephyr_glamor.c
 *
 * Glamor support and EGL setup.
 */
import build.dix_config;

version = MESA_EGL_NO_X11_HEADERS;
version = EGL_NO_X11;

import core.stdc.stdlib;
import core.stdc.stdint;
import externs.xcb.xcb;
import externs.xcb.xcb_aux;
import externs.pixman;
import glamor.glamor_context;
import glamor.glamor_egl;
import glamor.glamor_priv;
import hw.kdrive.ephyr.ephyr;
import hw.kdrive.ephyr.ephyr_glamor;
import include.os;
import hw.kdrive.ephyr.ephyr;
import hw.kdrive.src.kdrive;



enum EGL_NO_DISPLAY = cast(EGLDisplay)null;

/* until we need geometry shaders GL3.1 should suffice. */
/* Xephyr has its own copy of this for build reasons */
// enum GLAMOR_GL_CORE_VER_MAJOR = 3;
// enum GLAMOR_GL_CORE_VER_MINOR = 1;
/** @{
 *
 * global state for Xephyr with glamor, all of which is arguably a bug.
 */
Bool ephyr_glamor_gles2;
Bool ephyr_glamor_skip_present;
/** @} */

/**
 * Per-screen state for Xephyr withimport glamor.glamor_
 */
struct ephyr_glamor {
    EGLDisplay dpy;
    EGLContext ctx;
    xcb_window_t win;
    EGLSurface egl_win;

    GLuint tex;

    GLuint texture_shader;
    GLuint texture_shader_position_loc;
    GLuint texture_shader_texcoord_loc;

    /* Size of the window that we're rendering to. */
    uint width, height;

    GLuint vao, vbo;
}

private void glamor_egl_make_current(glamor_context* glamor_ctx)
{
    /* There's only a single global dispatch table in Mesa.  EGL, GLX,
     * and AIGLX's direct dispatch table manipulation don't talk to
     * each other.  We need to set the context to NULL first to avoid
     * EGL's no-op context change fast path when switching back to
     * EGL.
     */
    eglMakeCurrent(glamor_ctx.display, EGL_NO_SURFACE,
                   EGL_NO_SURFACE, EGL_NO_CONTEXT);

    if (!eglMakeCurrent(glamor_ctx.display,
                        glamor_ctx.surface, glamor_ctx.surface,
                        glamor_ctx.ctx)) {
        FatalError("Failed to make EGL context current\n");
    }
}

private void ephyr_glamor_egl_screen_init(ScreenPtr screen, glamor_context* glamor_ctx)
{
    mixin(KdScreenPriv!("screen"));;
    KdScreenInfo* kd_screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)kd_screen.driver;
    ephyr_glamor* ephyr_glamor = scrpriv.glamor;

    glamor_enable_dri3(screen);
    glamor_ctx.display = ephyr_glamor.dpy;
    glamor_ctx.ctx = ephyr_glamor.ctx;
    glamor_ctx.surface = ephyr_glamor.egl_win;
    glamor_ctx.make_current = &glamor_egl_make_current;
}

private GLuint ephyr_glamor_build_glsl_prog(GLuint vs, GLuint fs)
{
    GLint ok = void;
    GLuint prog = void;

    prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);

    glLinkProgram(prog);
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok) {
        GLint size = void;

        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &size);
        GLchar* info = cast(GLchar*) calloc(1, size);

        glGetProgramInfoLog(prog, size, null, info);
        ErrorF("Failed to link: %s\n", info);
        FatalError("GLSL link failure\n");
    }

    return prog;
}

private void ephyr_glamor_setup_texturing_shader(ephyr_glamor* glamor)
{
    const(char)* vs_source = "attribute vec2 texcoord;\n"
        ~ "attribute vec2 position;\n"
        ~ "varying vec2 t;\n"
        ~ "\n"
        ~ "void main()\n"
        ~ "{\n"
        ~ "    t = texcoord;\n"
        ~ "    gl_Position = vec4(position, 0, 1);\n"
        ~ "}\n";

    const(char)* fs_source = "#ifdef GL_ES\n"
        ~ "precision mediump float;\n"
        ~ "#endif\n"
        ~ "\n"
        ~ "varying vec2 t;\n"
        ~ "uniform sampler2D s; /* initially 0 */\n"
        ~ "\n"
        ~ "void main()\n"
        ~ "{\n"
        ~ "    gl_FragColor = texture2D(s, t);\n"
        ~ "}\n";

    GLuint fs = void, vs = void, prog = void;

    vs = glamor_compile_glsl_prog(GL_VERTEX_SHADER, vs_source);
    fs = glamor_compile_glsl_prog(GL_FRAGMENT_SHADER, fs_source);
    prog = ephyr_glamor_build_glsl_prog(vs, fs);

   glamor.texture_shader = prog;
   glamor.texture_shader_position_loc = glGetAttribLocation(prog, "position");
    assert(glamor.texture_shader_position_loc != -1);
   glamor.texture_shader_texcoord_loc = glGetAttribLocation(prog, "texcoord");
    assert(glamor.texture_shader_texcoord_loc != -1);
}

enum EGL_PLATFORM_XCB_EXT = 0x31DC;


import core.sys.posix.dlfcn;
enum RTLD_DEFAULT = NULL;


/* (loud booing)
 *
 * keeping this as a static variable is bad form, we _could_ have zaphod heads
 * on different displays (for example). but other bits of Xephyr are already
 * broken for that case, and fixing that would entail fixing the rest of the
 * contortions with hostx.c anyway, so this works for now.
 */
private EGLDisplay edpy = EGL_NO_DISPLAY;

xcb_connection_t* ephyr_glamor_connect()
{
    int major = 0, minor = 0;

    /*
     * Try pure xcb first. If that doesn't work but we can find XOpenDisplay,
     * fall back to xlib. This lets us potentially not load libX11 at all, if
     * the EGL is also pure xcb.
     */

    if (epoxy_has_egl_extension(EGL_NO_DISPLAY, "EGL_EXT_platform_xcb")) {
        xcb_connection_t* conn = xcb_connect(null, null);
        EGLDisplay dpy = glamor_egl_get_display(EGL_PLATFORM_XCB_EXT, conn);

        if (dpy == EGL_NO_DISPLAY) {
            xcb_disconnect(conn);
            return null;
        }

        edpy = dpy;
        eglInitialize(dpy, &major, &minor);
        return conn;
    }

    if (epoxy_has_egl_extension(EGL_NO_DISPLAY, "EGL_EXT_platform_X11") ||
        epoxy_has_egl_extension(EGL_NO_DISPLAY, "EGL_KHR_platform_X11")) {
        void* lib = null;
        xcb_connection_t* ret = null;
        void* function(void*) @nogc nothrow x_open_display = cast(void* function(void*)@nogc nothrow) (cast(void*) dlsym(RTLD_DEFAULT, "XOpenDisplay"));
        xcb_connection_t* function(void*)@nogc nothrow x_get_xcb_connection = cast(xcb_connection_t* function(void*)@nogc nothrow) (cast(void*) dlsym(RTLD_DEFAULT, "XGetXCBConnection"));

        if (x_open_display is null)
            return null;

        if (x_get_xcb_connection is null) {
            lib = dlopen("libX11-xcb.so.1", RTLD_LOCAL | RTLD_LAZY);
            x_get_xcb_connection =
                cast(xcb_connection_t* function(void*)@nogc nothrow) (cast(void*) dlsym(lib, "XGetXCBConnection"));
        }
        EGLDisplay dpy; 
        void* xdpy;

        if (x_get_xcb_connection is null)
            goto out_;
        xdpy =  x_open_display(null);
        dpy =  glamor_egl_get_display(EGL_PLATFORM_X11_KHR, xdpy);;
        if (dpy == EGL_NO_DISPLAY)
            goto out_;

        edpy = dpy;
        eglInitialize(dpy, &major, &minor);
        ret = x_get_xcb_connection(xdpy);
out_:
        if (lib)
            dlclose(lib);

        return ret;
    }

    return null;
}

void ephyr_glamor_set_texture(ephyr_glamor* glamor, uint tex)
{
   glamor.tex = tex;
}

private void ephyr_glamor_set_vertices(ephyr_glamor* glamor)
{
    glVertexAttribPointer(glamor.texture_shader_position_loc,
                          2, GL_FLOAT, FALSE, 0, cast(void*) 0);
    glVertexAttribPointer(glamor.texture_shader_texcoord_loc,
                          2, GL_FLOAT, FALSE, 0, cast(void*) (float.sizeof * 8));

    glEnableVertexAttribArray(glamor.texture_shader_position_loc);
    glEnableVertexAttribArray(glamor.texture_shader_texcoord_loc);
}

void ephyr_glamor_damage_redisplay(ephyr_glamor* glamor, pixman_region16* damage)
{
    GLint old_vao = void;

    /* Skip presenting the output in this mode.  Presentation is
     * expensive, and if we're just running the X Test suite headless,
     * nobody's watching.
     */
    if (ephyr_glamor_skip_present)
        return;

    eglMakeCurrent(glamor.dpy, glamor.egl_win, glamor.egl_win, glamor.ctx);

    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &old_vao);
    glBindVertexArray(glamor.vao);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glUseProgram(glamor.texture_shader);
    glViewport(0, 0, glamor.width, glamor.height);
    if (!ephyr_glamor_gles2)
        glDisable(GL_COLOR_LOGIC_OP);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, glamor.tex);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glBindVertexArray(old_vao);

    eglSwapBuffers(glamor.dpy, glamor.egl_win);
}

ephyr_glamor* ephyr_glamor_screen_init(xcb_window_t win, xcb_visualid_t vid)
{
    static const(float)[17] position = [
        -1, -1,
         1, -1,
         1,  1,
        -1,  1,
        0, 1,
        1, 1,
        1, 0,
        0, 0,
    ];
    GLint old_vao = void;

    EGLContext ctx = void;
    ephyr_glamor* glamor = void;
    EGLSurface egl_win = void;

    glamor = cast(ephyr_glamor*) cast(ephyr_glamor*) calloc(1, ephyr_glamor.sizeof);
    if (!glamor) {
        FatalError("calloc");
        return null;
    }

    const(EGLint)[5] config_attribs = [
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_NATIVE_VISUAL_ID, vid,
        EGL_NONE,
    ];
    EGLConfig config = EGL_NO_CONFIG_KHR;
    int num_configs = 0;

    /* (loud booing (see above)) */
    glamor.dpy = edpy;

    eglChooseConfig(glamor.dpy, config_attribs.ptr, &config, 1, &num_configs);
    if (num_configs != 1)
        FatalError("Unable to find an EGLConfig for vid %#x\n", vid);

    egl_win = eglCreatePlatformWindowSurfaceEXT(glamor.dpy, config,
                                                &win, null);

    if (ephyr_glamor_gles2)
        eglBindAPI(EGL_OPENGL_ES_API);
    else
        eglBindAPI(EGL_OPENGL_API);

    EGLint[5] context_attribs = void;
    int i = 0;
    context_attribs[i++] = EGL_CONTEXT_MAJOR_VERSION;
    context_attribs[i++] = ephyr_glamor_gles2 ? 2 : 3;
    context_attribs[i++] = EGL_CONTEXT_MINOR_VERSION;
    context_attribs[i++] = ephyr_glamor_gles2 ? 0 : 1;
    context_attribs[i++] = EGL_NONE;

    ctx = eglCreateContext(glamor.dpy, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT,
                           context_attribs.ptr);

    if (ctx is null)
        FatalError("eglCreateContext failed\n");

    if (!eglMakeCurrent(glamor.dpy, egl_win, egl_win, ctx))
        FatalError("eglMakeCurrent failed\n");

   glamor.ctx = ctx;
   glamor.win = win;
   glamor.egl_win = egl_win;
    ephyr_glamor_setup_texturing_shader(glamor);

    glGenVertexArrays(1, &glamor.vao);
    glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &old_vao);
    glBindVertexArray(glamor.vao);

    glGenBuffers(1, &glamor.vbo);

    glBindBuffer(GL_ARRAY_BUFFER,glamor.vbo);
    glBufferData(GL_ARRAY_BUFFER, position.sizeof, position.ptr, GL_STATIC_DRAW);

    ephyr_glamor_set_vertices(glamor);
    glBindVertexArray(old_vao);

    glamor_egl_screen_init2 = &ephyr_glamor_egl_screen_init;

    return glamor;
}

void ephyr_glamor_screen_fini(ephyr_glamor* glamor)
{
    eglMakeCurrent(glamor.dpy,
                   EGL_NO_SURFACE, EGL_NO_SURFACE,
                   EGL_NO_CONTEXT);
    eglDestroyContext(glamor.dpy,glamor.ctx);
    eglDestroySurface(glamor.dpy,glamor.egl_win);

    free(glamor);
}

void ephyr_glamor_set_window_size(ephyr_glamor* glamor, uint width, uint height)
{
    if (!glamor)
        return;

   glamor.width = width;
   glamor.height = height;
}
