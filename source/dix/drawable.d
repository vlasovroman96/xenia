module dix.drawable;

@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;

import x11.Xdefs;
import dix.scrintstr;

/* types for Drawable */
enum DRAWABLE_WINDOW = 0;
enum DRAWABLE_PIXMAP = 1;
enum UNDRAWABLE_WINDOW = 2;

/* corresponding type masks for dixLookupDrawable() */
enum M_DRAWABLE_WINDOW =	(1<<0);
enum M_DRAWABLE_PIXMAP =	(1<<1);
enum M_UNDRAWABLE_WINDOW =	(1<<2);
enum M_ANY =			(-1);
enum M_WINDOW =	(M_DRAWABLE_WINDOW|M_UNDRAWABLE_WINDOW);
enum M_DRAWABLE =	(M_DRAWABLE_WINDOW|M_DRAWABLE_PIXMAP);
enum M_UNDRAWABLE =	(M_UNDRAWABLE_WINDOW);

struct _Drawable {
    ubyte type;         /* DRAWABLE_<type> */
    ubyte class_;        /* specific to type */
    ubyte depth;
    ubyte bitsPerPixel;
    XID id;                     /* resource id */
    short x;                    /* window: screen absolute, pixmap: 0 */
    short y;                    /* window: screen absolute, pixmap: 0 */
    ushort width;
    ushort height;
    ScreenPtr pScreen;
    c_ulong serialNumber;
}

alias DrawableRec = _Drawable;
alias DrawablePtr = DrawableRec*;
