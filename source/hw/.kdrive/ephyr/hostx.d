module hw.kdrive.ephyr.hostx;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Xephyr - A kdrive X server that runs in a host X window.
 *          Authored by Matthew Allum <mallum@o-hand.com>
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
import hw.kdrive.src.kdrive;

// import externs.X11.extensions.XKBstr; 

import core.stdc.stdlib;
import core.stdc.stdio;
import core.sys.posix.unistd;
import core.stdc.string;             /* for memset */
import core.stdc.errno;
import core.stdc.time;

static if(MITSHM){
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.mman;
} /* MITSHM */
import core.sys.posix.sys.time;
// import externs.X11.extensions.XKBstr;
import include.xkbstr;


// workaround for name clash between Xlib and Xserver:
// GL might pull in Xlib.h (why ?), which is definining a type "GC", that's
// conflicting with Xserver's "GC" type.
// enum GC = XlibGC;
//import externs.X11.Xlib;
//import externs.X11.Xutil;
import dix.input_priv;

import hw.kdrive.ephyr.hostx;

version = X_INCLUDE_STRING_H;
// //import x11.Xos_r;
//import x11.keysym;
import externs.xcb.xcb;
import externs.xcb.xproto;
import externs.xcb.xcb_icccm;
import externs.xcb.xcb_aux;
import externs.xcb.shm;
import externs.xcb.xcb_image;
import externs.xcb.shape;
import externs.xcb.xcb_keysyms;
import externs.xcb.randr;
import externs.xcb.xkb;
static if (GLAMOR) {
import externs.xcb.glx;
import epoxy.common;
import Xext.glx.fix;
import glamor.glamor_glx_provider;
import hw.kdrive.ephyr.ephyr_glamor;
import glamor.glamor_priv;

version (XV) {
import hw.kdrive.src.kxv; 
}

}
// import ephyrlog;
import hw.kdrive.ephyr.ephyr;
import externs.xcb.xcbext;


struct EphyrHostWindowAttributes{
    int x, y;
    int width, height;
    int visualid;
} ;

struct EphyrBox{
    int x, y, width, height;
} ;

struct EphyrRect{
    short x1, y1, x2, y2;
} ;

struct EphyrHostVisualInfo{
    VisualID visualid;
    int screen;
    int depth;
    int class_;
    ulong red_mask;
    ulong green_mask;
    ulong blue_mask;
    int colormap_size;
    int bits_per_rgb;
} ;


struct EphyrHostXVars {
    char* server_dpy_name;
    xcb_connection_t* conn;
    int screen;
    xcb_visualtype_t* visual;
    Window winroot;
    xcb_gcontext_t gc;
    xcb_render_pictformat_t argb_format;
    xcb_cursor_t empty_cursor;
    xcb_generic_event_t* saved_event;
    int depth;
    Bool use_sw_cursor;
    Bool use_fullscreen;
    Bool have_shm;
    Bool have_shm_fd_passing;

    int n_screens;
    KdScreenInfo** screens;

    c_long damage_debug_msec;
    Bool size_set_from_configure;
    char* glvnd_vendor;
}

/* memset ( missing> ) instead of below  */
/*static EphyrHostXVars HostX = { "?", 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};*/
private EphyrHostXVars HostX;

private int HostXWantDamageDebug = 0;

Bool EphyrWantResize;

char* ephyrResName = null;
int ephyrResNameFromCmd = 0;
char* ephyrTitle = null;
Bool ephyr_glamor = FALSE;
Bool ephyrNoXV;
Bool ephyr_glamor_skip_present;

Bool hostx_has_extension(xcb_extension_t* extension)
{
    const(xcb_query_extension_reply_t)* rep = void;

    rep = xcb_get_extension_data(HostX.conn, extension);

    return rep && rep.present;
}



enum string host_depth_matches_server(string _vars) = `(HostX.depth == (` ~ _vars ~ `).server_depth)`;

int hostx_want_screen_geometry(KdScreenInfo* screen, int* width, int* height, int* x, int* y)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv && (scrpriv.win_pre_existing != None ||
                    scrpriv.output !is null ||
                    HostX.use_fullscreen == TRUE)) {
        *x = scrpriv.win_x;
        *y = scrpriv.win_y;
        *width = scrpriv.win_width;
        *height = scrpriv.win_height;
        return 1;
    }

    return 0;
}

void hostx_add_screen(KdScreenInfo* screen, c_ulong win_id, int screen_num, Bool use_geometry, const(char)* output)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    int index = HostX.n_screens;

    HostX.n_screens += 1;
    HostX.screens = reallocarray(HostX.screens,
                                 HostX.n_screens, typeof(HostX.screens[0]).sizeof);
    HostX.screens[index] = screen;

    scrpriv.screen = screen;
    scrpriv.win_pre_existing = win_id;
    scrpriv.win_explicit_position = use_geometry;
    scrpriv.output = output;
}

void hostx_set_display_name(char* name)
{
    HostX.server_dpy_name = strdup(name);
}

void hostx_set_screen_number(KdScreenInfo* screen, int number)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv) {
        scrpriv.mynum = number;
        hostx_set_win_title(screen, "");
    }
}

void hostx_set_win_title(KdScreenInfo* screen, const(char)* extra_text)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (!scrpriv)
        return;

    if (ephyrTitle) {
        xcb_icccm_set_wm_name(HostX.conn,
                              scrpriv.win,
                              XCB_ATOM_STRING,
                              8,
                              strlen(ephyrTitle),
                              ephyrTitle);
    } else {
enum BUF_LEN = 256;
        char[BUF_LEN + 1] buf = void;

        memset(buf.ptr, 0, BUF_LEN + 1);
        snprintf(buf.ptr, BUF_LEN, "Xephyr on %s.%d %s",
                 HostX.server_dpy_name ? HostX.server_dpy_name : ":0",
                 scrpriv.mynum, (extra_text !is null) ? extra_text : "");

        xcb_icccm_set_wm_name(HostX.conn,
                              scrpriv.win,
                              XCB_ATOM_STRING,
                              8,
                              strlen(buf.ptr),
                              buf.ptr);
        xcb_flush(HostX.conn);
    }
}

int hostx_want_host_cursor()
{
    return !HostX.use_sw_cursor;
}

void hostx_use_sw_cursor()
{
    HostX.use_sw_cursor = TRUE;
}

xcb_cursor_t hostx_get_empty_cursor()
{
    return HostX.empty_cursor;
}

int hostx_want_preexisting_window(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (scrpriv && scrpriv.win_pre_existing) {
        return 1;
    }
    else {
        return 0;
    }
}

void hostx_get_output_geometry(const(char)* output, int* x, int* y, int* width, int* height)
{
    int i = void, name_len = 0, output_found = FALSE;
    xcb_generic_error_t* error = void;
    xcb_randr_query_version_cookie_t version_c = void;
    xcb_randr_query_version_reply_t* version_r = void;
    xcb_randr_get_screen_resources_cookie_t screen_resources_c = void;
    xcb_randr_get_screen_resources_reply_t* screen_resources_r = void;
    xcb_randr_output_t* randr_outputs = void;
    xcb_randr_get_output_info_cookie_t output_info_c = void;
    xcb_randr_get_output_info_reply_t* output_info_r = void;
    xcb_randr_get_crtc_info_cookie_t crtc_info_c = void;
    xcb_randr_get_crtc_info_reply_t* crtc_info_r = void;

    /* First of all, check for extension */
    if (!hostx_has_extension(&xcb_randr_id))
    {
        fprintf(stderr, "\nHost X server does not support RANDR extension (or it's disabled).\n");
        exit(1);
    }

    /* Check RandR version */
    version_c = xcb_randr_query_version(HostX.conn, 1, 2);
    version_r = xcb_randr_query_version_reply(HostX.conn,
                                              version_c,
                                              &error);

    if (error !is null || version_r is null)
    {
        fprintf(stderr, "\nFailed to get RandR version supported by host X server.\n");
        exit(1);
    }
    else if (version_r.major_version < 1 || version_r.minor_version < 2)
    {
        free(version_r);
        fprintf(stderr, "\nHost X server doesn't support RandR 1.2, needed for -output usage.\n");
        exit(1);
    }

    free(version_r);

    /* Get list of outputs from screen resources */
    screen_resources_c = xcb_randr_get_screen_resources(HostX.conn,
                                                        HostX.winroot);
    screen_resources_r = xcb_randr_get_screen_resources_reply(HostX.conn,
                                                              screen_resources_c,
                                                              null);
    randr_outputs = xcb_randr_get_screen_resources_outputs(screen_resources_r);

    for (i = 0; !output_found && i < screen_resources_r.num_outputs; i++)
    {
        /* Get info on the output */
        output_info_c = xcb_randr_get_output_info(HostX.conn,
                                                  randr_outputs[i],
                                                  XCB_CURRENT_TIME);
        output_info_r = xcb_randr_get_output_info_reply(HostX.conn,
                                                        output_info_c,
                                                        null);

        /* Get output name */
        name_len = xcb_randr_get_output_info_name_length(output_info_r);
        char* name = cast(char*) calloc(1, name_len + 1);
        if (!name)
            continue;
        strncpy(name, cast(char*)xcb_randr_get_output_info_name(output_info_r), name_len);
        name[name_len] = '\0';

        if (!strcmp(name, output))
        {
            output_found = TRUE;

            /* Check if output is connected */
            if (output_info_r.crtc == XCB_NONE)
            {
                free(name);
                free(output_info_r);
                free(screen_resources_r);
                fprintf(stderr, "\nOutput %s is currently disabled (or not connected).\n", output);
                exit(1);
            }

            /* Get CRTC from output info */
            crtc_info_c = xcb_randr_get_crtc_info(HostX.conn,
                                                  output_info_r.crtc,
                                                  XCB_CURRENT_TIME);
            crtc_info_r = xcb_randr_get_crtc_info_reply(HostX.conn,
                                                        crtc_info_c,
                                                        null);

            /* Get CRTC geometry */
            *x = crtc_info_r.x;
            *y = crtc_info_r.y;
            *width = crtc_info_r.width;
            *height = crtc_info_r.height;

            free(crtc_info_r);
        }

        free(name);
        free(output_info_r);
    }

    free(screen_resources_r);

    if (!output_found)
    {
        fprintf(stderr, "\nOutput %s not available in host X server.\n", output);
        exit(1);
    }
}

void hostx_use_fullscreen()
{
    HostX.use_fullscreen = TRUE;
}

int hostx_want_fullscreen()
{
    return HostX.use_fullscreen;
}

private xcb_intern_atom_cookie_t cookie_WINDOW_STATE, cookie_WINDOW_STATE_FULLSCREEN;

private void hostx_set_fullscreen_hint()
{
    xcb_atom_t atom_WINDOW_STATE = void, atom_WINDOW_STATE_FULLSCREEN = void;
    int index = void;
    xcb_intern_atom_reply_t* reply = void;

    reply = xcb_intern_atom_reply(HostX.conn, cookie_WINDOW_STATE, null);
    atom_WINDOW_STATE = reply.atom;
    free(reply);

    reply = xcb_intern_atom_reply(HostX.conn, cookie_WINDOW_STATE_FULLSCREEN,
                                  null);
    atom_WINDOW_STATE_FULLSCREEN = reply.atom;
    free(reply);

    for (index = 0; index < HostX.n_screens; index++) {
        EphyrScrPriv* scrpriv = HostX.screens[index].driver;
        xcb_change_property(HostX.conn,
                            PropModeReplace,
                            scrpriv.win,
                            atom_WINDOW_STATE,
                            XCB_ATOM_ATOM,
                            32,
                            1,
                            &atom_WINDOW_STATE_FULLSCREEN);
    }
}

private void hostx_toggle_damage_debug()
{
    HostXWantDamageDebug ^= 1;
}

void hostx_handle_signal(int signum)
{
    hostx_toggle_damage_debug();
    EPHYR_DBG("Signal caught. Damage Debug:%i\n", HostXWantDamageDebug);
}

void hostx_use_resname(char* name, int fromcmd)
{
    ephyrResName = name;
    ephyrResNameFromCmd = fromcmd;
}

void hostx_set_title(char* title)
{
    ephyrTitle = title;
}

private void hostx_init_shm()
{
    /* Try to get share memory ximages for a little bit more speed */
    if (!hostx_has_extension(&xcb_shm_id) || getenv("XEPHYR_NO_SHM")) {
        HostX.have_shm = FALSE;
    } else {
        xcb_generic_error_t* error = null;
        xcb_shm_query_version_cookie_t cookie = void;
        xcb_shm_query_version_reply_t* reply = void;

        HostX.have_shm = TRUE;
        HostX.have_shm_fd_passing = FALSE;
        cookie = xcb_shm_query_version(HostX.conn);
        reply = xcb_shm_query_version_reply(HostX.conn, cookie, &error);
        if (reply) {
            HostX.have_shm_fd_passing =
                    (reply.major_version == 1 && reply.minor_version >= 2) ||
                    reply.major_version > 1;
            free(reply);
        }
        free(error);
    }
}

private Bool hostx_create_shm_segment(xcb_shm_segment_info_t* shminfo, size_t size)
{
static if(MITSHM){
    shminfo.shmaddr = null;

    if (HostX.have_shm_fd_passing) {
        xcb_generic_error_t* error = null;
        xcb_shm_create_segment_cookie_t cookie = void;
        xcb_shm_create_segment_reply_t* reply = void;

        shminfo.shmseg = xcb_generate_id(HostX.conn);
        cookie = xcb_shm_create_segment(HostX.conn, shminfo.shmseg, size, TRUE);
        reply = xcb_shm_create_segment_reply(HostX.conn, cookie, &error);
        if (reply) {
            int* fds = reply.nfd == 1 ?
                        xcb_shm_create_segment_reply_fds(HostX.conn, reply) : null;
            if (fds) {
                shminfo.shmaddr =
                        cast(ubyte*)mmap(0, size, PROT_READ|PROT_WRITE, MAP_SHARED, fds[0], 0);
                close(fds[0]);
                if (shminfo.shmaddr == MAP_FAILED)
                    shminfo.shmaddr = null;
            }
            if (!shminfo.shmaddr)
                xcb_shm_detach(HostX.conn, shminfo.shmseg);

            free(reply);
        }
        free(error);
    } else {
        shminfo.shmid = shmget(IPC_PRIVATE, size, IPC_CREAT|octal!"0666");
        if (shminfo.shmid != -1) {
            shminfo.shmaddr = shmat(shminfo.shmid, 0, 0);
            if (shminfo.shmaddr == cast(void*)-1) {
                shminfo.shmaddr = null;
            } else {
                xcb_generic_error_t* error = null;
                xcb_void_cookie_t cookie = void;

                shmctl(shminfo.shmid, IPC_RMID, 0);

                shminfo.shmseg = xcb_generate_id(HostX.conn);
                cookie = xcb_shm_attach_checked(HostX.conn, shminfo.shmseg, shminfo.shmid, TRUE);
                error = xcb_request_check(HostX.conn, cookie);

                if (error) {
                    free(error);
                    shmdt(shminfo.shmaddr);
                    shminfo.shmaddr = null;
                }
            }
        }
    }

    return shminfo.shmaddr !is null;
} else {
    return FALSE;
} /* MITSHM */
}

private void hostx_destroy_shm_segment(xcb_shm_segment_info_t* shminfo, size_t size)
{
static if(MITSHM){
    xcb_shm_detach(HostX.conn, shminfo.shmseg);

    if (HostX.have_shm_fd_passing)
        munmap(shminfo.shmaddr, size);
    else
        shmdt(shminfo.shmaddr);

    shminfo.shmaddr = null;
} /* MITSHM */
}

int hostx_init()
{
    uint[2] attrs = void;
    uint attr_mask = 0;
    xcb_pixmap_t cursor_pxm = void;
    xcb_gcontext_t cursor_gc = void;
    ushort red = void, green = void, blue = void;
    uint pixel = void;
    int index = void;
    char* tmpstr = void;
    size_t class_len = void;
    xcb_screen_t* xscreen = void;
    xcb_rectangle_t rect = { 0, 0, 1, 1 };

    attrs[0] =
        XCB_EVENT_MASK_BUTTON_PRESS
        | XCB_EVENT_MASK_BUTTON_RELEASE
        | XCB_EVENT_MASK_POINTER_MOTION
        | XCB_EVENT_MASK_KEY_PRESS
        | XCB_EVENT_MASK_KEY_RELEASE
        | XCB_EVENT_MASK_EXPOSURE
        | XCB_EVENT_MASK_STRUCTURE_NOTIFY;
    attr_mask |= XCB_CW_EVENT_MASK;

    EPHYR_DBG("mark");
static if (GLAMOR) {
    if (ephyr_glamor)
        HostX.conn = ephyr_glamor_connect();
    else
        HostX.conn = xcb_connect(null, &HostX.screen);
}
else {
        HostX.conn = xcb_connect(null, &HostX.screen);

}
    if (!HostX.conn || xcb_connection_has_error(HostX.conn)) {
        fprintf(stderr, "\nXephyr cannot open host display. Is DISPLAY set?\n");
        exit(1);
    }

    xscreen = xcb_aux_get_screen(HostX.conn, HostX.screen);
    HostX.winroot = xscreen.root;
    HostX.gc = xcb_generate_id(HostX.conn);
    HostX.depth = xscreen.root_depth;
    HostX.visual = xcb_aux_find_visual_by_id(xscreen, xscreen.root_visual);

    xcb_create_gc(HostX.conn, HostX.gc, HostX.winroot, 0, null);
    cookie_WINDOW_STATE = xcb_intern_atom(HostX.conn, FALSE,
                                          strlen("_NET_WM_STATE"),
                                          "_NET_WM_STATE");
    cookie_WINDOW_STATE_FULLSCREEN =
        xcb_intern_atom(HostX.conn, FALSE,
                        strlen("_NET_WM_STATE_FULLSCREEN"),
                        "_NET_WM_STATE_FULLSCREEN");

    for (index = 0; index < HostX.n_screens; index++) {
        KdScreenInfo* screen = HostX.screens[index];
        EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

        scrpriv.win = xcb_generate_id(HostX.conn);
        scrpriv.vid = xscreen.root_visual;
        scrpriv.server_depth = HostX.depth;
        scrpriv.ximg = null;
        scrpriv.win_x = 0;
        scrpriv.win_y = 0;

        if (scrpriv.win_pre_existing != XCB_WINDOW_NONE) {
            xcb_get_geometry_reply_t* prewin_geom = void;
            xcb_get_geometry_cookie_t cookie = void;
            xcb_generic_error_t* e = null;

            /* Get screen size from existing window */
            cookie = xcb_get_geometry(HostX.conn,
                                      scrpriv.win_pre_existing);
            prewin_geom = xcb_get_geometry_reply(HostX.conn, cookie, &e);

            if (e) {
                free(e);
                free(prewin_geom);
                fprintf (stderr, "\nXephyr -parent window' does not exist!\n");
                exit (1);
            }

            scrpriv.win_width  = prewin_geom.width;
            scrpriv.win_height = prewin_geom.height;

            free(prewin_geom);

            xcb_create_window(HostX.conn,
                              XCB_COPY_FROM_PARENT,
                              scrpriv.win,
                              scrpriv.win_pre_existing,
                              0,0,
                              scrpriv.win_width,
                              scrpriv.win_height,
                              0,
                              XCB_WINDOW_CLASS_COPY_FROM_PARENT,
                              HostX.visual.visual_id,
                              attr_mask,
                              attrs.ptr);
        }
        else {
            xcb_create_window(HostX.conn,
                              XCB_COPY_FROM_PARENT,
                              scrpriv.win,
                              HostX.winroot,
                              0,0,100,100, /* will resize */
                              0,
                              XCB_WINDOW_CLASS_COPY_FROM_PARENT,
                              HostX.visual.visual_id,
                              attr_mask,
                              attrs.ptr);

            hostx_set_win_title(screen,
                                "(ctrl+shift grabs mouse and keyboard)");

            if (HostX.use_fullscreen) {
                scrpriv.win_width  = xscreen.width_in_pixels;
                scrpriv.win_height = xscreen.height_in_pixels;

                hostx_set_fullscreen_hint();
            }
            else if (scrpriv.output) {
                hostx_get_output_geometry(scrpriv.output,
                                          &scrpriv.win_x,
                                          &scrpriv.win_y,
                                          &scrpriv.win_width,
                                          &scrpriv.win_height);

                HostX.use_fullscreen = TRUE;
                hostx_set_fullscreen_hint();
            }


            tmpstr = getenv("RESOURCE_NAME");
            if (tmpstr && (!ephyrResNameFromCmd))
                ephyrResName = tmpstr;
            class_len = strlen(ephyrResName) + 1 + strlen("Xephyr") + 1;
            char* class_hint = cast(char*) calloc(1, class_len);
            if (class_hint) {
                strcpy(class_hint, ephyrResName);
                strcpy(class_hint + strlen(ephyrResName) + 1, "Xephyr");
                xcb_change_property(HostX.conn,
                                    XCB_PROP_MODE_REPLACE,
                                    scrpriv.win,
                                    XCB_ATOM_WM_CLASS,
                                    XCB_ATOM_STRING,
                                    8,
                                    class_len,
                                    class_hint);
                free(class_hint);
            }
        }
    }

    if (!xcb_aux_parse_color(cast(char*)"red", &red, &green, &blue)) {
        xcb_lookup_color_cookie_t c = xcb_lookup_color(HostX.conn, xscreen.default_colormap, 3, "red");
        xcb_lookup_color_reply_t* reply = xcb_lookup_color_reply(HostX.conn, c, null);
        red = reply.exact_red;
        green = reply.exact_green;
        blue = reply.exact_blue;
        free(reply);
    }

    {
        xcb_alloc_color_cookie_t c = xcb_alloc_color(HostX.conn,
                                                     xscreen.default_colormap,
                                                     red, green, blue);
        xcb_alloc_color_reply_t* r = xcb_alloc_color_reply(HostX.conn, c, null);
        red = r.red;
        green = r.green;
        blue = r.blue;
        pixel = r.pixel;
        free(r);
    }

    xcb_change_gc(HostX.conn, HostX.gc, XCB_GC_FOREGROUND, &pixel);

    cursor_pxm = xcb_generate_id(HostX.conn);
    xcb_create_pixmap(HostX.conn, 1, cursor_pxm, HostX.winroot, 1, 1);
    cursor_gc = xcb_generate_id(HostX.conn);
    pixel = 0;
    xcb_create_gc(HostX.conn, cursor_gc, cursor_pxm,
                  XCB_GC_FOREGROUND, &pixel);
    xcb_poly_fill_rectangle(HostX.conn, cursor_pxm, cursor_gc, 1, &rect);
    xcb_free_gc(HostX.conn, cursor_gc);
    HostX.empty_cursor = xcb_generate_id(HostX.conn);
    xcb_create_cursor(HostX.conn,
                      HostX.empty_cursor,
                      cursor_pxm, cursor_pxm,
                      0,0,0,
                      0,0,0,
                      1,1);
    xcb_free_pixmap(HostX.conn, cursor_pxm);
    if (!hostx_want_host_cursor ()) {
        CursorVisible = TRUE;
        /* Ditch the cursor, we provide our 'own' */
        for (index = 0; index < HostX.n_screens; index++) {
            KdScreenInfo* screen = HostX.screens[index];
            EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

            xcb_change_window_attributes(HostX.conn,
                                         scrpriv.win,
                                         XCB_CW_CURSOR,
                                         &HostX.empty_cursor);
        }
    }

    hostx_init_shm();
    if (HostX.have_shm) {
        /* Really really check we have shm - better way ?*/
        xcb_shm_segment_info_t shminfo = void;
        if (!hostx_create_shm_segment(&shminfo, 1)) {
            fprintf(stderr, "\nXephyr unable to use SHM XImages\n");
            HostX.have_shm = FALSE;
        } else {
            hostx_destroy_shm_segment(&shminfo, 1);
        }
    } else {
        fprintf(stderr, "\nXephyr unable to use SHM XImages\n");
    }

    xcb_flush(HostX.conn);

    /* Setup the pause time between paints when debugging updates */

    HostX.damage_debug_msec = 20000;    /* 1/50 th of a second */

    if (getenv("XEPHYR_PAUSE")) {
        HostX.damage_debug_msec = strtol(getenv("XEPHYR_PAUSE"), null, 0);
        EPHYR_DBG("pause is %li\n", HostX.damage_debug_msec);
    }

    return 1;
}

int hostx_get_depth()
{
    return HostX.depth;
}

int hostx_get_server_depth(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    return scrpriv ? scrpriv.server_depth : 0;
}

int hostx_get_bpp(KdScreenInfo* screen)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (!scrpriv)
        return 0;

    if (mixin(host_depth_matches_server!(`scrpriv`)))
        return HostX.visual.bits_per_rgb_value;
    else
        return scrpriv.server_depth; /*XXX correct ?*/
}

void hostx_get_visual_masks(KdScreenInfo* screen, CARD32* rmsk, CARD32* gmsk, CARD32* bmsk)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    if (!scrpriv)
        return;

    if (mixin(host_depth_matches_server!(`scrpriv`))) {
        *rmsk = HostX.visual.red_mask;
        *gmsk = HostX.visual.green_mask;
        *bmsk = HostX.visual.blue_mask;
    }
    else if (scrpriv.server_depth == 16) {
        /* Assume 16bpp 565 */
        *rmsk = 0xf800;
        *gmsk = 0x07e0;
        *bmsk = 0x001f;
    }
    else {
        *rmsk = 0x0;
        *gmsk = 0x0;
        *bmsk = 0x0;
    }
}

private int hostx_calculate_color_shift(c_ulong mask)
{
    int shift = 1;

    /* count # of bits in mask */
    while ((mask = (mask >> 1)))
        shift++;
    /* cmap entry is an unsigned char so adjust it by size of that */
    shift = shift - ubyte.sizeof * 8;
    if (shift < 0)
        shift = 0;
    return shift;
}

void hostx_set_cmap_entry(ScreenPtr pScreen, ubyte idx, ubyte r, ubyte g, ubyte b)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
/* need to calculate the shifts for RGB because server could be BGR. */
/* XXX Not sure if this is correct for 8 on 16, but this works for 8 on 24.*/
    static int rshift, bshift, gshift = 0;
    static int first_time = 1;

    if (first_time) {
        first_time = 0;
        rshift = hostx_calculate_color_shift(HostX.visual.red_mask);
        gshift = hostx_calculate_color_shift(HostX.visual.green_mask);
        bshift = hostx_calculate_color_shift(HostX.visual.blue_mask);
    }
    scrpriv.cmap[idx] = ((r << rshift) & HostX.visual.red_mask) |
        ((g << gshift) & HostX.visual.green_mask) |
        ((b << bshift) & HostX.visual.blue_mask);
}

/**
 * hostx_screen_init creates the XImage that will contain the front buffer of
 * the ephyr screen, and possibly offscreen memory.
 *
 * @param width width of the screen
 * @param height height of the screen
 * @param buffer_height  height of the rectangle to be allocated.
 *
 * hostx_screen_init() creates an XImage, using MIT-SHM if it's available.
 * buffer_height can be used to create a larger offscreen buffer, which is used
 * by fakexa for storing offscreen pixmap data.
 */
void *
hostx_screen_init(KdScreenInfo* screen,
                  int x, int y,
                  int width, int height, int buffer_height,
                  int* bytes_per_line, int* bits_per_pixel)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    Bool shm_success = FALSE;

    if (!scrpriv) {
        fprintf(stderr, "%s: Error in accessing hostx data\n", __FUNCTION__.ptr);
        exit(1);
    }

    EPHYR_DBG("host_screen=%p x=%d, y=%d, wxh=%dx%d, buffer_height=%d",
              screen, x, y, width, height, buffer_height);

    if (scrpriv.ximg !is null) {
        /* Free up the image data if previously used
         * i.ie called by server reset
         */

        if (HostX.have_shm) {
            xcb_image_destroy(scrpriv.ximg);
            hostx_destroy_shm_segment(&scrpriv.shminfo, scrpriv.shmsize);
        }
        else {
            free(scrpriv.ximg.data);
            scrpriv.ximg.data = null;

            xcb_image_destroy(scrpriv.ximg);
        }
    }

    if (!ephyr_glamor && HostX.have_shm) {
        scrpriv.ximg = xcb_image_create_native(HostX.conn,
                                                width,
                                                buffer_height,
                                                XCB_IMAGE_FORMAT_Z_PIXMAP,
                                                HostX.depth,
                                                null,
                                                ~0,
                                                null);

        scrpriv.shmsize = scrpriv.ximg.stride * buffer_height;
        if (!hostx_create_shm_segment(&scrpriv.shminfo,
                                      scrpriv.shmsize)) {
            EPHYR_DBG
                ("Can't create SHM Segment, falling back to plain XImages");
            HostX.have_shm = FALSE;
            xcb_image_destroy(scrpriv.ximg);
        }
        else {
            EPHYR_DBG("SHM segment created %p", scrpriv.shminfo.shmaddr);
            scrpriv.ximg.data = scrpriv.shminfo.shmaddr;
            shm_success = TRUE;
        }
    }

    if (!ephyr_glamor && !shm_success) {
        EPHYR_DBG("Creating image %dx%d for screen scrpriv=%p\n",
                  width, buffer_height, scrpriv);
        scrpriv.ximg = xcb_image_create_native(HostX.conn,
                                                    width,
                                                    buffer_height,
                                                    XCB_IMAGE_FORMAT_Z_PIXMAP,
                                                    HostX.depth,
                                                    null,
                                                    ~0,
                                                    null);

        /* Match server byte order so that the image can be converted to
         * the native byte order by xcb_image_put() before drawing */
        if (mixin(host_depth_matches_server!(`scrpriv`)))
            scrpriv.ximg.byte_order = IMAGE_BYTE_ORDER;

        scrpriv.ximg.data =
            calloc(scrpriv.ximg.stride, buffer_height);
    }

    if (!HostX.size_set_from_configure)
    {
        uint mask = XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT;
        uint[2] values = [width, height];
        xcb_configure_window(HostX.conn, scrpriv.win, mask, values.ptr);
    }

    if (scrpriv.win_pre_existing == None && !EphyrWantResize) {
        /* Ask the WM to keep our size static */
        xcb_size_hints_t size_hints = {0};
        size_hints.max_width = size_hints.min_width = width;
        size_hints.max_height = size_hints.min_height = height;
        size_hints.flags = (XCB_ICCCM_SIZE_HINT_P_MIN_SIZE |
                            XCB_ICCCM_SIZE_HINT_P_MAX_SIZE);
        xcb_icccm_set_wm_normal_hints(HostX.conn, scrpriv.win,
                                      &size_hints);
    }

version(GLAMOR) {
    if (!ephyr_glamor_skip_present)
        xcb_map_window(HostX.conn, scrpriv.win);
}
else {
    xcb_map_window(HostX.conn, scrpriv.win);

}

    /* Set explicit window position if it was informed in
     * -screen option (WxH+X or WxH+X+Y). Otherwise, accept the
     * position set by WM.
     * The trick here is putting this code after xcb_map_window() call,
     * so these values won't be overridden by WM. */
    if (scrpriv.win_explicit_position)
    {
        uint mask = XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y;
        uint[2] values = [x, y];
        xcb_configure_window(HostX.conn, scrpriv.win, mask, values.ptr);
    }


    xcb_aux_sync(HostX.conn);

    scrpriv.win_width = width;
    scrpriv.win_height = height;
    scrpriv.win_x = x;
    scrpriv.win_y = y;

static if (GLAMOR) {
    if (ephyr_glamor) {
        *bytes_per_line = 0;
        ephyr_glamor_set_window_size(scrpriv.glamor,
                                     scrpriv.win_width, scrpriv.win_height);
        return null;
    } else
    if (mixin(host_depth_matches_server!(`scrpriv`))) {
        *bytes_per_line = scrpriv.ximg.stride;
        *bits_per_pixel = scrpriv.ximg.bpp;

        EPHYR_DBG("Host matches server");
        return scrpriv.ximg.data;
    }
    else {
        int bytes_per_pixel = scrpriv.server_depth >> 3;
        int stride = (width * bytes_per_pixel + 0x3) & ~0x3;

        *bytes_per_line = stride;
        *bits_per_pixel = scrpriv.server_depth;

        EPHYR_DBG("server bpp %i", bytes_per_pixel);
        scrpriv.fb_data = calloc(stride, buffer_height);
        return scrpriv.fb_data;
    }
}
else {
    if (mixin(host_depth_matches_server!(`scrpriv`))) {
        *bytes_per_line = scrpriv.ximg.stride;
        *bits_per_pixel = scrpriv.ximg.bpp;

        EPHYR_DBG("Host matches server");
        return scrpriv.ximg.data;
    }
    else {
        int bytes_per_pixel = scrpriv.server_depth >> 3;
        int stride = (width * bytes_per_pixel + 0x3) & ~0x3;

        *bytes_per_line = stride;
        *bits_per_pixel = scrpriv.server_depth;

        EPHYR_DBG("server bpp %i", bytes_per_pixel);
        scrpriv.fb_data = calloc(stride, buffer_height);
        return scrpriv.fb_data;
    }
}
}



void hostx_paint_rect(KdScreenInfo* screen, int sx, int sy, int dx, int dy, int width, int height, Bool sync)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;

    EPHYR_DBG("painting in screen %d\n", scrpriv.mynum);

static if (GLAMOR) {
    if (ephyr_glamor) {
        BoxRec box = void;
        RegionRec region = void;

        box.x1 = dx;
        box.y1 = dy;
        box.x2 = dx + width;
        box.y2 = dy + height;

        RegionInit(&region, &box, 1);
        ephyr_glamor_damage_redisplay(scrpriv.glamor, &region);
        RegionUninit(&region);
        return;
    }
}

    /*
     *  Copy the image data updated by the shadow layer
     *  on to the window
     */

    if (HostXWantDamageDebug) {
        hostx_paint_debug_rect(screen, dx, dy, width, height);
    }

    /*
     * If the depth of the ephyr server is less than that of the host,
     * the kdrive fb does not point to the ximage data but to a buffer
     * ( fb_data ), we shift the various bits from this onto the XImage
     * so they match the host.
     *
     * Note, This code is pretty new ( and simple ) so may break on
     *       endian issues, 32 bpp host etc.
     *       Not sure if 8bpp case is right either.
     *       ... and it will be slower than the matching depth case.
     */

    if (!mixin(host_depth_matches_server!(`scrpriv`))) {
        int x = void, y = void, idx = void, bytes_per_pixel = (scrpriv.server_depth >> 3);
        int stride = (scrpriv.win_width * bytes_per_pixel + 0x3) & ~0x3;
        ubyte r = void, g = void, b = void;
        c_ulong host_pixel = void;

        EPHYR_DBG("Unmatched host depth scrpriv=%p\n", scrpriv);
        for (y = sy; y < sy + height; y++)
            for (x = sx; x < sx + width; x++) {
                idx = y * stride + x * bytes_per_pixel;

                switch (scrpriv.server_depth) {
                case 16:
                {
                    ushort pixel = *cast(ushort*) (scrpriv.fb_data + idx);

                    r = ((pixel & 0xf800) >> 8);
                    g = ((pixel & 0x07e0) >> 3);
                    b = ((pixel & 0x001f) << 3);

                    host_pixel = (r << 16) | (g << 8) | (b);

                    xcb_image_put_pixel(scrpriv.ximg, x, y, host_pixel);
                    break;
                }
                case 8:
                {
                    ubyte pixel = *cast(ubyte*) (scrpriv.fb_data + idx);
                    xcb_image_put_pixel(scrpriv.ximg, x, y,
                                        scrpriv.cmap[pixel]);
                    break;
                }
                default:
                    break;
                }
            }
    }

    if (HostX.have_shm) {
        xcb_image_shm_put(HostX.conn, scrpriv.win,
                          HostX.gc, scrpriv.ximg,
                          scrpriv.shminfo,
                          sx, sy, dx, dy, width, height, FALSE);
        if (sync)
            xcb_aux_sync(HostX.conn);
    }
    else {
        xcb_image_t* subimg = xcb_image_subimage(scrpriv.ximg, sx, sy,
                                                 width, height, 0, 0, 0);
        xcb_image_t* img = xcb_image_native(HostX.conn, subimg, 1);
        xcb_image_put(HostX.conn, scrpriv.win, HostX.gc, img, dx, dy, 0);
        if (subimg != img)
            xcb_image_destroy(img);
        xcb_image_destroy(subimg);
    }
}

private void hostx_paint_debug_rect(KdScreenInfo* screen, int x, int y, int width, int height)
{
    EphyrScrPriv* scrpriv = cast(EphyrScrPriv*)screen.driver;
    timespec tspec = void;
    xcb_rectangle_t rect = { x: x, y: y, width: width, height: height };
    xcb_void_cookie_t cookie = void;
    xcb_generic_error_t* e = void;

    tspec.tv_sec = HostX.damage_debug_msec / (1000000);
    tspec.tv_nsec = (HostX.damage_debug_msec % 1000000) * 1000;

    EPHYR_DBG("msec: %li tv_sec %li, tv_msec %li",
              HostX.damage_debug_msec, tspec.tv_sec, tspec.tv_nsec);

    /* fprintf(stderr, "Xephyr updating: %i+%i %ix%i\n", x, y, width, height); */

    cookie = xcb_poly_fill_rectangle_checked(HostX.conn, scrpriv.win,
                                             HostX.gc, 1, &rect);
    e = xcb_request_check(HostX.conn, cookie);
    free(e);

    /* nanosleep seems to work better than usleep for me... */
    nanosleep(&tspec, null);
}

Bool hostx_load_keymap(KeySymsPtr keySyms, CARD8* modmap, XkbControlsPtr controls)
{
    int min_keycode = void, max_keycode = void;
    int map_width = void;
    size_t i = void, j = void;
    int keymap_len = void;
    xcb_keysym_t* keymap = void;
    xcb_keycode_t* modifier_map = void;
    xcb_get_keyboard_mapping_cookie_t mapping_c = void;
    xcb_get_keyboard_mapping_reply_t* mapping_r = void;
    xcb_get_modifier_mapping_cookie_t modifier_c = void;
    xcb_get_modifier_mapping_reply_t* modifier_r = void;
    xcb_xkb_use_extension_cookie_t use_c = void;
    xcb_xkb_use_extension_reply_t* use_r = void;
    xcb_xkb_get_controls_cookie_t controls_c = void;
    xcb_xkb_get_controls_reply_t* controls_r = void;

    /* First of all, collect host X server's
     * min_keycode and max_keycode, which are
     * independent from XKB support. */
    min_keycode = xcb_get_setup(HostX.conn).min_keycode;
    max_keycode = xcb_get_setup(HostX.conn).max_keycode;

    EPHYR_DBG("min: %d, max: %d", min_keycode, max_keycode);

    keySyms.minKeyCode = min_keycode;
    keySyms.maxKeyCode = max_keycode;

    /* Check for XKB availability in host X server */
    if (!hostx_has_extension(&xcb_xkb_id)) {
        EPHYR_LOG_ERROR("XKB extension is not supported in host X server.");
        return FALSE;
    }

    use_c = xcb_xkb_use_extension(HostX.conn,
                                  XCB_XKB_MAJOR_VERSION,
                                  XCB_XKB_MINOR_VERSION);
    use_r = xcb_xkb_use_extension_reply(HostX.conn, use_c, null);

    if (!use_r) {
        EPHYR_LOG_ERROR("Couldn't use XKB extension.");
        return FALSE;
    } else if (!use_r.supported) {
        EPHYR_LOG_ERROR("XKB extension is not supported in host X server.");
        free(use_r);
        return FALSE;
    }

    free(use_r);

    /* Send all needed XCB requests at once,
     * and process the replies as needed. */
    mapping_c = xcb_get_keyboard_mapping(HostX.conn,
                                         min_keycode,
                                         max_keycode - min_keycode + 1);
    modifier_c = xcb_get_modifier_mapping(HostX.conn);
    controls_c = xcb_xkb_get_controls(HostX.conn,
                                      XCB_XKB_ID_USE_CORE_KBD);

    mapping_r = xcb_get_keyboard_mapping_reply(HostX.conn,
                                               mapping_c,
                                               null);

    if (!mapping_r) {
        EPHYR_LOG_ERROR("xcb_get_keyboard_mapping_reply() failed.");
        return FALSE;
    }

    map_width = mapping_r.keysyms_per_keycode;
    keymap = xcb_get_keyboard_mapping_keysyms(mapping_r);
    keymap_len = xcb_get_keyboard_mapping_keysyms_length(mapping_r);

    keySyms.mapWidth = map_width;
    keySyms.map = calloc(keymap_len, KeySym.sizeof);

    if (!keySyms.map) {
        EPHYR_LOG_ERROR("Failed to allocate KeySym map.");
        free(mapping_r);
        return FALSE;
    }

    for (i = 0; i < keymap_len; i++) {
        keySyms.map[i] = keymap[i];
    }

    free(mapping_r);

    modifier_r = xcb_get_modifier_mapping_reply(HostX.conn,
                                                modifier_c,
                                                null);

    if (!modifier_r) {
        EPHYR_LOG_ERROR("xcb_get_modifier_mapping_reply() failed.");
        return FALSE;
    }

    modifier_map = xcb_get_modifier_mapping_keycodes(modifier_r);
    memset(modmap, 0, ((CARD8) * MAP_LENGTH).sizeof);

    for (j = 0; j < 8; j++) {
        for (i = 0; i < modifier_r.keycodes_per_modifier; i++) {
            CARD8 keycode = void;

            if ((keycode = modifier_map[j * modifier_r.keycodes_per_modifier + i])) {
                modmap[keycode] |= 1 << j;
            }
        }
    }

    free(modifier_r);

    controls_r = xcb_xkb_get_controls_reply(HostX.conn,
                                            controls_c,
                                            null);

    if (!controls_r) {
        EPHYR_LOG_ERROR("xcb_xkb_get_controls_reply() failed.");
        return FALSE;
    }

    controls.enabled_ctrls = controls_r.enabledControls;

    for (i = 0; i < XkbPerKeyBitArraySize; i++) {
        controls.per_key_repeat[i] = controls_r.perKeyRepeat[i];
    }

    free(controls_r);

    return TRUE;
}

void hostx_size_set_from_configure(Bool ss)
{
    HostX.size_set_from_configure = ss;
}

xcb_connection_t* hostx_get_xcbconn()
{
    return HostX.conn;
}

xcb_generic_event_t* hostx_get_event(Bool queued_only)
{
    xcb_generic_event_t* xev = void;

    if (HostX.saved_event) {
        xev = HostX.saved_event;
        HostX.saved_event = null;
    } else {
        if (queued_only)
            xev = xcb_poll_for_queued_event(HostX.conn);
        else
            xev = xcb_poll_for_event(HostX.conn);
    }
    return xev;
}

Bool hostx_has_queued_event()
{
    if (!HostX.saved_event)
        HostX.saved_event = xcb_poll_for_queued_event(HostX.conn);
    return HostX.saved_event !is null;
}

int hostx_get_screen()
{
    return HostX.screen;
}

int hostx_get_fd()
{
    return xcb_get_file_descriptor(HostX.conn);
}

int hostx_get_window(int a_screen_number)
{
    EphyrScrPriv* scrpriv = void;
    if (a_screen_number < 0 || a_screen_number >= HostX.n_screens) {
        EPHYR_LOG_ERROR("bad screen number:%d\n", a_screen_number);
        return 0;
    }
    scrpriv = HostX.screens[a_screen_number].driver;
    return scrpriv.win;
}

int hostx_get_window_attributes(int a_window, EphyrHostWindowAttributes* a_attrs)
{
    xcb_get_geometry_cookie_t geom_cookie = void;
    xcb_get_window_attributes_cookie_t attr_cookie = void;
    xcb_get_geometry_reply_t* geom_reply = void;
    xcb_get_window_attributes_reply_t* attr_reply = void;

    geom_cookie = xcb_get_geometry(HostX.conn, a_window);
    attr_cookie = xcb_get_window_attributes(HostX.conn, a_window);
    geom_reply = xcb_get_geometry_reply(HostX.conn, geom_cookie, null);
    attr_reply = xcb_get_window_attributes_reply(HostX.conn, attr_cookie, null);

    a_attrs.x = geom_reply.x;
    a_attrs.y = geom_reply.y;
    a_attrs.width = geom_reply.width;
    a_attrs.height = geom_reply.height;
    a_attrs.visualid = attr_reply.visual;

    free(geom_reply);
    free(attr_reply);
    return TRUE;
}

int hostx_get_visuals_info(EphyrHostVisualInfo** a_visuals, int* a_num_entries)
{
    Bool is_ok = FALSE;
    EphyrHostVisualInfo* host_visuals = null;
    int nb_items = 0, i = 0, screen_num = void;
    xcb_screen_iterator_t screens = void;
    xcb_depth_iterator_t depths = void;

    mixin(EPHYR_RETURN_VAL_IF_FAIL!("a_visuals && a_num_entries", "FALSE"));
    EPHYR_LOG("enter\n");

    screens = xcb_setup_roots_iterator(xcb_get_setup(HostX.conn));
    for (screen_num = 0; screens.rem; screen_num++, xcb_screen_next(&screens)) {
        depths = xcb_screen_allowed_depths_iterator(screens.data);
        for (; depths.rem; xcb_depth_next(&depths)) {
            xcb_visualtype_t* visuals = xcb_depth_visuals(depths.data);
            EphyrHostVisualInfo* tmp_visuals = reallocarray(host_visuals,
                             nb_items + depths.data.visuals_len,
                             EphyrHostVisualInfo.sizeof);
            if (!tmp_visuals) {
                goto _;
            }
            host_visuals = tmp_visuals;
            for (i = 0; i < depths.data.visuals_len; i++) {
                host_visuals[nb_items + i].visualid = visuals[i].visual_id;
                host_visuals[nb_items + i].screen = screen_num;
                host_visuals[nb_items + i].depth = depths.data.depth;
                host_visuals[nb_items + i].class_ = visuals[i]._class;
                host_visuals[nb_items + i].red_mask = visuals[i].red_mask;
                host_visuals[nb_items + i].green_mask = visuals[i].green_mask;
                host_visuals[nb_items + i].blue_mask = visuals[i].blue_mask;
                host_visuals[nb_items + i].colormap_size = visuals[i].colormap_entries;
                host_visuals[nb_items + i].bits_per_rgb = visuals[i].bits_per_rgb_value;
            }
            nb_items += depths.data.visuals_len;
        }
    }

    EPHYR_LOG("host advertises %d visuals\n", nb_items);
    *a_visuals = host_visuals;
    *a_num_entries = nb_items;
    host_visuals = null;

    is_ok = TRUE;
_:
    free(host_visuals);
    host_visuals = null;
    EPHYR_LOG("leave\n");
    return is_ok;

}

int hostx_create_window(int a_screen_number, EphyrBox* a_geometry, int a_visual_id, int* a_host_peer)
{
    Bool is_ok = FALSE;
    xcb_window_t win = void;
    int winmask = 0;
    uint[2] attrs = void;
    xcb_screen_t* screen = xcb_aux_get_screen(HostX.conn, hostx_get_screen());
    xcb_visualtype_t* visual = void;
    int depth = 0;
    EphyrScrPriv* scrpriv = HostX.screens[a_screen_number].driver;

    mixin(EPHYR_RETURN_VAL_IF_FAIL!("screen && a_geometry", "FALSE"));

    EPHYR_LOG("enter\n");

    visual = xcb_aux_find_visual_by_id(screen, a_visual_id);
    if (!visual) {
        EPHYR_LOG_ERROR ("argh, could not find a remote visual with id:%d\n",
                         a_visual_id);
        goto _;
    }
    depth = xcb_aux_get_depth_of_visual(screen, a_visual_id);

    winmask = XCB_CW_EVENT_MASK | XCB_CW_COLORMAP;
    attrs[0] = XCB_EVENT_MASK_BUTTON_PRESS
              |XCB_EVENT_MASK_BUTTON_RELEASE
              |XCB_EVENT_MASK_POINTER_MOTION
              |XCB_EVENT_MASK_KEY_PRESS
              |XCB_EVENT_MASK_KEY_RELEASE
              |XCB_EVENT_MASK_EXPOSURE;
    attrs[1] = xcb_generate_id(HostX.conn);
    xcb_create_colormap(HostX.conn,
                        XCB_COLORMAP_ALLOC_NONE,
                        attrs[1],
                        hostx_get_window(a_screen_number),
                        a_visual_id);

    win = xcb_generate_id(HostX.conn);
    xcb_create_window(HostX.conn,
                      depth,
                      win,
                      hostx_get_window (a_screen_number),
                      a_geometry.x, a_geometry.y,
                      a_geometry.width, a_geometry.height, 0,
                      XCB_WINDOW_CLASS_COPY_FROM_PARENT,
                      a_visual_id, winmask, attrs.ptr);

    if (scrpriv.peer_win == XCB_NONE) {
        scrpriv.peer_win = win;
    }
    else {
        EPHYR_LOG_ERROR("multiple peer windows created for same screen\n");
    }
    xcb_flush(HostX.conn);
    xcb_map_window(HostX.conn, win);
    *a_host_peer = win;
    is_ok = TRUE;
 _:
    EPHYR_LOG("leave\n");
    return is_ok;
}

int hostx_destroy_window(int a_win)
{
    xcb_destroy_window(HostX.conn, a_win);
    xcb_flush(HostX.conn);
    return TRUE;
}

int hostx_set_window_geometry(int a_win, EphyrBox* a_geo)
{
    uint mask = XCB_CONFIG_WINDOW_X
                  | XCB_CONFIG_WINDOW_Y
                  | XCB_CONFIG_WINDOW_WIDTH
                  | XCB_CONFIG_WINDOW_HEIGHT;
    uint[4] values = void;

    mixin(EPHYR_RETURN_VAL_IF_FAIL!("a_geo", "FALSE"));

    EPHYR_LOG("enter. x,y,w,h:(%d,%d,%d,%d)\n",
              a_geo.x, a_geo.y, a_geo.width, a_geo.height);

    values[0] = a_geo.x;
    values[1] = a_geo.y;
    values[2] = a_geo.width;
    values[3] = a_geo.height;
    xcb_configure_window(HostX.conn, a_win, mask, values.ptr);

    EPHYR_LOG("leave\n");
    return TRUE;
}

int hostx_set_window_bounding_rectangles(int a_window, EphyrRect* a_rects, int a_num_rects)
{
    Bool is_ok = FALSE;
    int i = 0;
    xcb_rectangle_t* rects = null;

    mixin(EPHYR_RETURN_VAL_IF_FAIL!("a_rects", "FALSE"));

    EPHYR_LOG("enter. num rects:%d\n", a_num_rects);

    rects = cast(xcb_rectangle_t*) calloc(a_num_rects, xcb_rectangle_t.sizeof);
    if (!rects)
        goto _;
    for (i = 0; i < a_num_rects; i++) {
        rects[i].x = a_rects[i].x1;
        rects[i].y = a_rects[i].y1;
        rects[i].width = abs(a_rects[i].x2 - a_rects[i].x1);
        rects[i].height = abs(a_rects[i].y2 - a_rects[i].y1);
        EPHYR_LOG("borders clipped to rect[x:%d,y:%d,w:%d,h:%d]\n",
                  rects[i].x, rects[i].y, rects[i].width, rects[i].height);
    }
    xcb_shape_rectangles(HostX.conn,
                         XCB_SHAPE_SO_SET,
                         XCB_SHAPE_SK_BOUNDING,
                         XCB_CLIP_ORDERING_YX_BANDED,
                         a_window,
                         0, 0,
                         a_num_rects,
                         rects);
    is_ok = TRUE;

_:
    free(rects);
    rects = null;
    EPHYR_LOG("leave\n");
    return is_ok;
}

static if (GLAMOR) {

enum GLX_EXTENSIONS =          3;


enum GLX_VENDOR_NAMES_EXT = 0x20F6;


/**
 * Exchange a protocol request for glXQueryServerString.
 */
private char* __glXQueryServerString(CARD32 name)
{
    xcb_glx_query_server_string_cookie_t cookie = void;
    xcb_glx_query_server_string_reply_t* reply = void;
    uint len = void;
    char* str = void;
    char* buf = void;

    cookie = xcb_glx_query_server_string(HostX.conn, HostX.screen, name);
    reply = xcb_glx_query_server_string_reply(HostX.conn, cookie, null);
    str = xcb_glx_query_server_string_string(reply);

    /* The spec doesn't mention this, but the Xorg server replies with
     * a string already terminated with '\0'. */
    len = xcb_glx_query_server_string_string_length(reply);
    buf = XNFalloc(len);
    memcpy(buf, str, len);
    free(reply);

    return buf;
}

Bool ephyr_glamor_init(ScreenPtr screen)
{
    mixin(KdScreenPriv!("screen"));;
    KdScreenInfo* kd_screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = kd_screen.driver;
    char* hostx_glx_exts = null;
    char* glvnd_vendors = null;
    _Xstrtokparams saveptr = void;

    scrpriv.glamor = ephyr_glamor_screen_init(scrpriv.win, scrpriv.vid);
    ephyr_glamor_set_window_size(scrpriv.glamor,
                                 scrpriv.win_width, scrpriv.win_height);

    if (!glamor_init(screen, GLAMOR_USE_EGL_SCREEN)) {
        FatalError("Failed to initialize glamor\n");
        return FALSE;
    }
    hostx_glx_exts = __glXQueryServerString(GLX_EXTENSIONS);
    if (epoxy_extension_in_string(hostx_glx_exts,"GLX_EXT_libglvnd"))
        glvnd_vendors = __glXQueryServerString(GLX_VENDOR_NAMES_EXT);

    if (glvnd_vendors) {
        HostX.glvnd_vendor = _XStrtok(glvnd_vendors, " ", saveptr);
        glamor_set_glvnd_vendor(screen, HostX.glvnd_vendor);
        free(glvnd_vendors);
    }
    free(hostx_glx_exts);

    GlxPushProvider(&glamor_provider);

version (XV) {
    if (!ephyrNoXV) {
        kd_glamor_xv_init(screen);
    }
} /*XV*/

    return TRUE;
}

private int ephyrSetPixmapVisitWindow(WindowPtr window, void* data)
{
    ScreenPtr screen = window.drawable.pScreen;

    if (screen.GetWindowPixmap(window) == data) {
        screen.SetWindowPixmap(window, screen.GetScreenPixmap(screen));
        return WT_WALKCHILDREN;
    }
    return WT_DONTWALKCHILDREN;
}

Bool ephyr_glamor_create_screen_resources(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* kd_screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = kd_screen.driver;
    PixmapPtr old_screen_pixmap = void, screen_pixmap = void;
    uint tex = void;

    if (!ephyr_glamor)
        return TRUE;

    /* kdrive's fbSetupScreen() told mi to have
     * miCreateScreenResources() (which is called before this) make a
     * scratch pixmap wrapping ephyr-glamor's NULL
     * KdScreenInfo->fb.framebuffer.
     *
     * We want a real (texture-based) screen pixmap at this point.
     * This is what glamor will render into, and we'll then texture
     * _ of that into the host's window to present the results.
     *
     * Thus, delete the current screen pixmap, and put a fresh one in.
     */
    old_screen_pixmap = pScreen.GetScreenPixmap(pScreen);
    dixDestroyPixmap(old_screen_pixmap, 0);

    screen_pixmap = pScreen.CreatePixmap(pScreen,
                                          pScreen.width,
                                          pScreen.height,
                                          pScreen.rootDepth,
                                          GLAMOR_CREATE_NO_LARGE);
    if (!screen_pixmap)
        return FALSE;

    pScreen.SetScreenPixmap(screen_pixmap);
    if (pScreen.root && pScreen.SetWindowPixmap)
        TraverseTree(pScreen.root, &ephyrSetPixmapVisitWindow, old_screen_pixmap);

    /* Tell the GLX code what to GL texture to read from. */
    tex = glamor_get_pixmap_texture(screen_pixmap);
    if (!tex)
        return FALSE;

    ephyr_glamor_set_texture(scrpriv.glamor, tex);

    return TRUE;
}

void ephyr_glamor_enable(ScreenPtr screen)
{
}

void ephyr_glamor_disable(ScreenPtr screen)
{
}

void ephyr_glamor_fini(ScreenPtr screen)
{
    mixin(KdScreenPriv!("screen"));;
    KdScreenInfo* kd_screen = pScreenPriv.screen;
    EphyrScrPriv* scrpriv = kd_screen.driver;

    glamor_fini(screen);
    ephyr_glamor_screen_fini(scrpriv.glamor);
    scrpriv.glamor = null;
}
}
