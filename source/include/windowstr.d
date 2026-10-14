module include.windowstr;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

 
public import include.xlibre_ptrtypes;
public import include.window;
public import include.pixmapstr;
public import include.regionstr;
public import dix.cursor;
public import include.property;
public import include.resource;           /* for ROOT_WINDOW_ID_BASE */
public import include.dix;
public import include.privates;
public import include.miscstruct;
//public import x11.Xprotostr;
public import include.opaque;
public import include.inputstr;
import mi.mi_priv;



/* used as NULL-terminated list */
struct _DevCursorNode {
    CursorPtr cursor;
    DeviceIntPtr dev;
    _DevCursorNode* next;
}alias DevCursNodeRec = _DevCursorNode;
alias DevCursNodePtr = _DevCursorNode*;
alias DevCursorList = _DevCursorNode*;

struct _WindowOpt {
    CursorPtr cursor;           /* default: window.cursorNone */
    VisualID visual;            /* default: same as parent */
    Colormap colormap;          /* default: same as parent */
    Mask dontPropagateMask;     /* default: window.dontPropagate */
    Mask otherEventMasks;       /* default: 0 */
    _OtherClients* otherClients; /* default: NULL */
    _GrabRec* passiveGrabs;      /* default: NULL */
    CARD32 backingBitPlanes;    /* default: ~0L */
    CARD32 backingPixel;        /* default: 0 */
    RegionPtr boundingShape;    /* default: NULL */
    RegionPtr clipShape;        /* default: NULL */
    RegionPtr inputShape;       /* default: NULL */
    _OtherInputMasks* inputMasks;        /* default: NULL */
    DevCursorList deviceCursors;        /* default: NULL */
}alias WindowOptRec = _WindowOpt;
alias WindowOptPtr = _WindowOpt*;

enum BackgroundPixel =	    2L;
enum BackgroundPixmap =    3L;

/*
 * The redirectDraw field can have one of three values:
 *
 *  RedirectDrawNone
 *	A normal window; painted into the same pixmap as the parent
 *	and clipping parent and siblings to its geometry. These
 *	windows get a clip list equal to the intersection of their
 *	geometry with the parent geometry, minus the geometry
 *	of overlapping None and Clipped siblings.
 *  RedirectDrawAutomatic
 *	A redirected window which clips parent and sibling drawing.
 *	Contents for these windows are manage inside the server.
 *	These windows get an internal clip list equal to their
 *	geometry.
 *  RedirectDrawManual
 *	A redirected window which does not clip parent and sibling
 *	drawing; the window must be represented within the parent
 *	geometry by the client performing the redirection management.
 *	Contents for these windows are managed outside the server.
 *	These windows get an internal clip list equal to their
 *	geometry.
 */

enum RedirectDrawNone =	0;
enum RedirectDrawAutomatic =	1;
enum RedirectDrawManual =	2;

struct _Window {
    DrawableRec drawable;
    PrivateRec* devPrivates;
    WindowPtr parent;           /* ancestor chain */
    WindowPtr nextSib;          /* next lower sibling */
    WindowPtr prevSib;          /* next higher sibling */
    WindowPtr firstChild;       /* top-most child */
    WindowPtr lastChild;        /* bottom-most child */
    RegionRec clipList;         /* clipping rectangle for output */
    RegionRec borderClip;       /* NotClippedByChildren + border */
    _MiValidate* valdata;
    RegionRec winSize;
    RegionRec borderSize;
    xPoint origin;         /* position relative to parent */
    ushort borderWidth;
    ushort deliverableEvents;   /* all masks from all clients */
    Mask eventMask;             /* mask from the creating client */
    PixUnion background;
    PixUnion border;
    WindowOptPtr optional;
    uint backgroundState:2; /* None, Relative, Pixel, Pixmap */
    uint borderIsPixel : 1;
    uint cursorIsNone : 1;    /* else real cursor (might inherit) */
    uint backingStore : 2;
    uint saveUnder : 1;
    uint bitGravity : 4;
    uint winGravity : 4;
    uint overrideRedirect : 1;
    uint visibility : 2;
    uint mapped : 1;
    uint realized : 1;        /* ancestors are all mapped */
    uint viewable : 1;        /* realized && InputOutput */
    uint dontPropagate : 3;   /* index into DontPropagateMasks */
    uint redirectDraw : 2;    /* COMPOSITE rendering redirect */
    uint forcedBG : 1;        /* must have an opaque background */
    uint unhittable : 1;      /* doesn't hit-test, for rootless */
    uint damagedDescendants : 1;      /* some descendants are damaged */
    uint inhibitBGPaint : 1;  /* paint the background? */

    PropertyPtr properties;     /* default: NULL */
}

// void [1] DontPropagateMasks;

enum string wBorderWidth(string w) = `(cast(int) (` ~ w ~ `).borderWidth)`;

pragma(inline, true) private PropertyPtr wUserProps(WindowPtr pWin) { return pWin.properties; }

/* true when w needs a border drawn. */

enum string HasBorder(string w) = `((` ~ w ~ `).borderWidth || `~wClipShape!(w)~ `)`;

enum SCREEN_IS_BLANKED =   0;
enum SCREEN_ISNT_SAVED =   1;
enum SCREEN_IS_TILED =     2;
enum SCREEN_IS_BLACK =	    3;

                          /* WINDOWSTRUCT_H */
