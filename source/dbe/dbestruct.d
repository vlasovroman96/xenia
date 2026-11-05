module dbestruct;
@nogc nothrow:
extern(C): __gshared:
/******************************************************************************
 *
 * Copyright (c) 1994, 1995  Hewlett-Packard Company
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL HEWLETT-PACKARD COMPANY BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
 * THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the Hewlett-Packard
 * Company shall not be used in advertising or otherwise to promote the
 * sale, use or other dealings in this Software without prior written
 * authorization from the Hewlett-Packard Company.
 *
 *     Header file for DIX-related DBE
 *
 *****************************************************************************/

 
//public import x11.Xmd;
// //public import externs.X11.extensions.dbeproto;

public import include.windowstr;
public import dix.privates;

struct XdbeVisualInfo {
    VisualID visual;            /* one visual ID that supports double-buffering */
    int depth;                  /* depth of visual in bits                      */
    int perflevel;              /* performance level of visual                  */
}

struct XdbeScreenVisualInfo {
    int count;                  /* number of items in visual_depth   */
    XdbeVisualInfo* visinfo;    /* list of visuals & depths for scrn */
}

/* DEFINES */

enum string DBE_SCREEN_PRIV(string pScreen) = `(cast(DbeScreenPrivPtr) 
    dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, &dbeScreenPrivKeyRec))`;

enum string DBE_SCREEN_PRIV_FROM_DRAWABLE(string pDrawable) = `
    ` ~ DBE_SCREEN_PRIV!(`(` ~ pDrawable ~ `).pScreen`) ~ ``;

enum string DBE_SCREEN_PRIV_FROM_WINDOW_PRIV(string pDbeWindowPriv) = `
    ` ~ DBE_SCREEN_PRIV!(`(` ~ pDbeWindowPriv ~ `).pWindow.drawable.pScreen`) ~ ``;

enum string DBE_SCREEN_PRIV_FROM_WINDOW(string pWindow) = `
    ` ~ DBE_SCREEN_PRIV!(`(` ~ pWindow ~ `).drawable.pScreen`) ~ ``;

enum string DBE_SCREEN_PRIV_FROM_PIXMAP(string pPixmap) = `
    ` ~ DBE_SCREEN_PRIV!(`(` ~ pPixmap ~ `).drawable.pScreen`) ~ ``;

enum string DBE_SCREEN_PRIV_FROM_GC(string pGC) = `
    ` ~ DBE_SCREEN_PRIV!(`(` ~ pGC ~ `).pScreen`) ~ ``;

enum string DBE_WINDOW_PRIV(string pWin) = `(cast(DbeWindowPrivPtr) 
    dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, &dbeWindowPrivKeyRec))`;

/* Initial size of the buffer ID array in the window priv. */
enum DBE_INIT_MAX_IDS =	2;

/* Reallocation increment for the buffer ID array. */
enum DBE_INCR_MAX_IDS =	4;

/* Marker for free elements in the buffer ID array. */
enum DBE_FREE_ID_ELEMENT =	0;

/* TYPEDEFS */

/* Record used to pass swap information between DIX and DDX swapping
 * procedures.
 */
struct _DbeSwapInfoRec {
    WindowPtr pWindow;
    ubyte swapAction;

}alias DbeSwapInfoRec = _DbeSwapInfoRec;
alias DbeSwapInfoPtr = _DbeSwapInfoRec*;

/*
 ******************************************************************************
 ** Per-window data
 ******************************************************************************
 */

struct _DbeWindowPrivRec {
    /* A pointer to the window with which the DBE window private (buffer) is
     * associated.
     */
    WindowPtr pWindow;

    /* Last known swap action for this buffer.  Legal values for this field
     * are XdbeUndefined, XdbeBackground, XdbeUntouched, and XdbeCopied.
     */
    ubyte swapAction;

    /* Last known buffer size.
     */
    ushort width, height;

    /* Coordinates used for static gravity when the window is positioned.
     */
    short x, y;

    /* Number of XIDs associated with this buffer.
     */
    int nBufferIDs;

    /* Capacity of the current buffer ID array, IDs. */
    int maxAvailableIDs;

    /* Pointer to the array of buffer IDs.  This initially points to initIDs.
     * When the static limit of the initIDs array is reached, the array is
     * reallocated and this pointer is set to the new array instead of initIDs.
     */
    XID* IDs;

    /* Initial array of buffer IDs.  We are defining the XID array within the
     * window priv to optimize for data locality.  In most cases, only one
     * buffer will be associated with a window.  Having the array declared
     * here can prevent us from accessing the data in another memory page,
     * possibly resulting in a page swap and loss of performance.  Initially we
     * will use this array to store buffer IDs.  For situations where we have
     * more IDs than can fit in this static array, we will allocate a larger
     * array to use, possibly suffering a performance loss.
     */
    XID[DBE_INIT_MAX_IDS] initIDs;

    /* Pointer to a drawable that contains the contents of the back buffer.
     */
    PixmapPtr pBackBuffer;

    /* Pointer to a drawable that contains the contents of the front buffer.
     * This pointer is only used for the XdbeUntouched swap action.  For that
     * swap action, we need to copy the front buffer (window) contents into
     * this drawable, copy the contents of current back buffer drawable (the
     * back buffer) into the window, swap the front and back drawable pointers,
     * and then swap the drawable/resource associations in the resource
     * database.
     */
    PixmapPtr pFrontBuffer;

    /* Device-specific private information.
     */
    PrivateRec* devPrivates;

}alias DbeWindowPrivRec = _DbeWindowPrivRec;
alias DbeWindowPrivPtr = _DbeWindowPrivRec*;

/*
 ******************************************************************************
 ** Per-screen data
 ******************************************************************************
 */

struct _DbeScreenPrivRec {
    /* Per-screen DIX routines */
    @nogc nothrow Bool function(WindowPtr, GCPtr) SetupBackgroundPainter;

    /* Per-screen DDX routines */
@nogc nothrow     Bool function(ScreenPtr, XdbeScreenVisualInfo*) GetVisualInfo;
    @nogc nothrow int function(WindowPtr, XID, int) AllocBackBufferName;
    @nogc nothrow int function(ClientPtr, int*, DbeSwapInfoPtr) SwapBuffers;
    @nogc nothrow void function(DbeWindowPrivPtr, XID) WinPrivDelete;
}alias DbeScreenPrivRec = _DbeScreenPrivRec;
alias DbeScreenPrivPtr = _DbeScreenPrivRec*;

                          /* DBE_STRUCT_H */
