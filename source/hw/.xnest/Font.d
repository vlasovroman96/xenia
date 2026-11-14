module Font;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/
import build.xorg_config;

import core.stdc.stddef;
//import x11.X;
//import externs.X11.Xatom;
//import x11.Xdefs;
//import x11.Xproto;
// //import externs.X11.fonts.font;
// //import externs.X11.fonts.fontstruct;
// //import externs.X11.fonts.libxfont2;

import dix.dix_priv;

import region;
import dix.dixfonts;
import dix.scrnintstr;

import xnest_xcb;


import Display;
import XNFont;

int xnestFontPrivateIndex;

Bool xnestRealizeFont(ScreenPtr pScreen, FontPtr pFont)
{
    int nprops = void;
    FontPropPtr props = void;
    int i = void;
    const(char)* name = void;

    xfont2_font_set_private(pFont, xnestFontPrivateIndex, null);

    Atom name_atom = dixAddAtom("FONT");
    Atom value_atom = 0L;

    nprops = pFont.info.nprops;
    props = pFont.info.props;

    for (i = 0; i < nprops; i++)
        if (props[i].name == name_atom) {
            value_atom = props[i].value;
            break;
        }

    if (!value_atom)
        return False;

    name = atomMgr.nameForAtom(value_atom);

    if (!name)
        return False;

    xnestPrivFont* priv = cast(xnestPrivFont*) cast(xnestPrivFont*) calloc(1, xnestPrivFont.sizeof);
    xfont2_font_set_private(pFont, xnestFontPrivateIndex, priv);

    priv.font_id = xcb_generate_id(xnestUpstreamInfo.conn);
    xcb_open_font(xnestUpstreamInfo.conn, priv.font_id, strlen(name), name);

    xcb_generic_error_t* err = null;
    priv.font_reply = xcb_query_font_reply(
        xnestUpstreamInfo.conn,
        xcb_query_font(xnestUpstreamInfo.conn, priv.font_id),
        &err);
    if (err) {
        ErrorF("failed to query font \"%s\": %d", name, err.error_code);
        free(err);
        return False;
    }
    if (!priv.font_reply) {
        ErrorF("failed to query font \"%s\": no reply", name);
        return False;
    }
    priv.chars_len = xcb_query_font_char_infos_length(priv.font_reply);
    priv.chars = xcb_query_font_char_infos(priv.font_reply);

    return True;
}

Bool xnestUnrealizeFont(ScreenPtr pScreen, FontPtr pFont)
{
    if (xnestFontPriv(pFont)) {
        xcb_close_font(xnestUpstreamInfo.conn, xnestFontPriv(pFont).font_id);
        free(xnestFontPriv(pFont));
        xfont2_font_set_private(pFont, xnestFontPrivateIndex, null);
    }
    return True;
}
