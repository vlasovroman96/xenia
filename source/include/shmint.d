module include.shmint;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2003 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

 
//public import x11.Xmd;
// //public import externs.X11.extensions.shmproto;

public import include.screenint;
public import include.pixmap;
public import include.gc;
import include.damage;
import build.xlibre_server;


enum string XSHM_PUT_IMAGE_ARGS = "
    DrawablePtr,		/* dst */
    GCPtr,		/* pGC */
    int			/* depth */,
    uint	/* format */,
    int			/* w */,
    int			/* h */,
    int			/* sx */,
    int			/* sy */,
    int			/* sw */,
    int			/* sh */,
    int			/* dx */,
    int			/* dy */,
    char *      ";                /* data */

enum XSHM_CREATE_PIXMAP_ARGS = "
    ScreenPtr	/* pScreen */, 
    int		/* width */, 
    int		/* height */,
    int		/* depth */, 
    char *                      /* addr */";

struct _ShmFuncs {
    mixin("PixmapPtr function(" ~ XSHM_CREATE_PIXMAP_ARGS ~ ") @nogc nothrow CreatePixmap;");
    mixin("void function(" ~ XSHM_PUT_IMAGE_ARGS ~ ") @nogc nothrow PutImage;");
}alias ShmFuncs = _ShmFuncs;
alias ShmFuncsPtr = _ShmFuncs*;

static if (XTRANS_SEND_FDS) {
// enum SHM_FD_PASSING =  1;
}

version (SHM_FD_PASSING) {
enum string SHMDESC_IS_FD(string shmdesc) = `((` ~ shmdesc ~ `).is_fd)`;
} else {
enum string SHMDESC_IS_FD(string shmdesc) = `(0)`;
}

void ShmRegisterFuncs(ScreenPtr pScreen, ShmFuncsPtr funcs);
void ShmRegisterFbFuncs(ScreenPtr pScreen);

int ShmCompletionCode;
int BadShmSegCode;

                          /* _SHMINT_H_ */
