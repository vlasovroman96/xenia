module xnest_xcb;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
// public //import stdbool;
public import externs.xcb.xcb;

public import include.list;
import include.gc;
import include.scrintstr;
import x11.Xprotostr;

struct xnest_event_queue {
    xorg_list entry;
    xcb_generic_event_t* event;
}

struct xnest_upstream_info {
    xcb_connection_t* conn;
    int screenId;
    const(xcb_screen_t)* screenInfo;
    const(xcb_setup_t)* setup;
    xnest_event_queue eventQueue;
}

xnest_upstream_info xnestUpstreamInfo;

/* connect to upstream X server */
bool xnest_upstream_setup(const(char)* displayName);

/* retrieve upstream GC XID for our xserver GC */
uint xnest_upstream_gc(GCPtr pGC);

struct xnest_visual_t {
    xcb_visualtype_t* upstreamVisual;
    xcb_depth_t* upstreamDepth;
    xcb_colormap_t upstreamCMap;
    uint ourXID;
    VisualPtr ourVisual;
}

xnest_visual_t* xnestVisualMap;
int xnestNumVisualMap;

void xnest_wm_colormap_windows(xcb_connection_t* conn, xcb_window_t w, xcb_window_t* windows, int count);

uint xnest_create_bitmap_from_data(xcb_connection_t* conn, uint drawable, const(char)* data, uint width, uint height);

uint xnest_create_pixmap_from_bitmap_data(xcb_connection_t* conn, uint drawable, const(char)* data, uint width, uint height, uint fg, uint bg, ushort depth);

void xnest_set_command(xcb_connection_t* conn, xcb_window_t window, char** argv, int argc);

void xnest_xkb_init(xcb_connection_t* conn);
int xnest_xkb_device_id(xcb_connection_t* conn);

xcb_get_keyboard_mapping_reply_t* xnest_get_keyboard_mapping(xcb_connection_t* conn, int min_keycode, int count);

void xnest_get_pointer_control(xcb_connection_t* conn, int* acc_num, int* acc_den, int* threshold);

xRectangle xnest_get_geometry(xcb_connection_t* conn, uint window);

int xnest_parse_geometry(const(char)* string, xRectangle* geometry);

uint xnest_visual_map_to_upstream(VisualID visual);
uint xnest_upstream_visual_to_cmap(uint visual);
uint xnest_visual_to_upstream_cmap(uint visual);

struct xnestPrivFont {
    xcb_query_font_reply_t* font_reply;
    xcb_font_t font_id;
    xcb_charinfo_t* chars;
    ushort chars_len;
}

int xnest_text_width(xnestPrivFont* font, const(char)* string, int count);
int xnest_text_width_16(xnestPrivFont* font, const(ushort)* string, int count);

 /* __XNEST__XCB_H */
