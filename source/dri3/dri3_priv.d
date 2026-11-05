module dri3.dri3_priv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

 
//public import x11.X;
public import include.scrnintstr;
public import common.misc;
public import common.list;
public import include.windowstr;
public import dix.dixstruct_priv;
public import include.randrstr;
public import dri3.dri3;

DevPrivateKeyRec dri3_screen_private_key;

RESTYPE dri3_syncobj_type;

struct dri3_dmabuf_format {
    uint format;
    uint num_modifiers;
    ulong* modifiers;
}alias dri3_dmabuf_format_rec = dri3_dmabuf_format;
alias dri3_dmabuf_format_ptr = dri3_dmabuf_format*;

struct dri3_screen_priv_ {
    ConfigNotifyProcPtr ConfigNotify;

    Bool formats_cached;
    CARD32 num_formats;
    dri3_dmabuf_format_ptr formats;

    const(dri3_screen_info_rec)* info;
}alias dri3_screen_priv_rec = dri3_screen_priv_;
alias dri3_screen_priv_ptr = dri3_screen_priv_*;

enum string wrap(string priv,string real_,string mem,string func) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ func ~ `; 
}`;

enum string unwrap(string priv,string real_,string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

enum string VERIFY_DRI3_SYNCOBJ(string id, string ptr, string a) = `
    do {
        int rc = dixLookupResourceByType(cast(void**)&(` ~ ptr ~ `), ` ~ id ~ `,
                                         dri3_syncobj_type, client, ` ~ a ~ `);
        if (rc != Success) {
            client.errorValue = cast(uint)` ~ id ~ `;
            return rc;
        }
    } while (0);`;

pragma(inline, true) dri3_screen_priv_ptr dri3_screen_priv(ScreenPtr screen)
{
    return cast(dri3_screen_priv_ptr)dixLookupPrivate(&(screen).devPrivates, &dri3_screen_private_key);
}

int proc_dri3_dispatch(ClientPtr client);

/* DDX interface */

int dri3_open(ClientPtr client, ScreenPtr screen, RRProviderPtr provider, int* fd);

int dri3_pixmap_from_fds(PixmapPtr* ppixmap, ScreenPtr screen, CARD8 num_fds, const(int)* fds, CARD16 width, CARD16 height, const(CARD32)* strides, const(CARD32)* offsets, CARD8 depth, CARD8 bpp, CARD64 modifier);

int dri3_fd_from_pixmap(PixmapPtr pixmap, CARD16* stride, CARD32* size);

int dri3_fds_from_pixmap(PixmapPtr pixmap, int* fds, uint* strides, uint* offsets, ulong* modifier);

int dri3_get_supported_modifiers(ScreenPtr screen, DrawablePtr drawable, CARD8 depth, CARD8 bpp, CARD32* num_drawable_modifiers, CARD64** drawable_modifiers, CARD32* num_screen_modifiers, CARD64** screen_modifiers);

int dri3_import_syncobj(ClientPtr client, ScreenPtr screen, XID id, int fd);

int dri3_send_open_reply(ClientPtr client, int fd);

uint drm_format_for_depth(uint depth, uint bpp);

 /* _DRI3PRIV_H_ */
