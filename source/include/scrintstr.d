module include.scrintstr;
extern(C): @nogc: nothrow:
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

// #include "xlibre_ptrtypes.h"
// #include "screenint.h"
// #include "regionstr.h"
// #include "colormap.h"
// #include "cursor.h"
// #include "validate.h"
// #include <X11/Xproto.h>
// #include "dix.h"
// #include "privates.h"
// #include <X11/extensions/randr.h>
//  
import include.xlibre_ptrtypes;
import include.screenint;
import include.pixmap;
import include.misc;
import include.input;
import include.cursor;


//import x11.X;
import externs.X11.extensions.randrproto;
import include.validate;

struct _PixmapFormat {
    ubyte depth;
    ubyte bitsPerPixel;
    ubyte scanlinePad;
} 
// alias PixmapFormatRec = _PixmapFormat;

struct _Visual {
    VisualID vid;
    short class_;
    short bitsPerRGBValue;
    short ColormapEntries;
    short nplanes;              /* = log2 (ColormapEntries). This does not
                                 * imply that the screen has this many planes.
                                 * it may have more or fewer */
    ulong redMask, greenMask, blueMask;
    int offsetRed, offsetGreen, offsetBlue;
} 
alias VisualRec = _Visual;

struct _Depth {
    ubyte depth;
    short numVids;
    VisualID *vids;             /* block of visual ids for this depth */
} 
alias DepthRec = _Depth;

struct _ScreenSaverStuff {
    WindowPtr pWindow;
    XID wid;
    char blanked;
    Bool function(	ScreenPtr /*pScreen */ ,
                	int /*xstate */ ,
                    Bool /*force */ )  @nogc nothrow ExternalScreenSaver;
} 
alias ScreenSaverStuffRec = _ScreenSaverStuff;
alias ScreenSaverStuffPtr = ScreenSaverStuffRec*;

enum WindowVRRMode {
    WINDOW_VRR_DISABLED = 0,
    WINDOW_VRR_ENABLED,
}

/*
 *  There is a typedef for each screen function pointer so that code that
 *  needs to declare a screen function pointer (e.g. in a screen private
 *  or as a local variable) can easily do so and retain full type checking.
 */

alias CloseScreenProcPtr = Bool function(ScreenPtr /*pScreen */ )  @nogc nothrow;

alias QueryBestSizeProcPtr = void function(int /*class */ ,
                                      ushort * /*pwidth */ ,
                                      ushort * /*pheight */ ,
                                      ScreenPtr /*pScreen */ )  @nogc nothrow;

alias SaveScreenProcPtr = Bool function(ScreenPtr /*pScreen */ ,
                                   int /*on */ )  @nogc nothrow;

alias GetImageProcPtr = void function(DrawablePtr /*pDrawable */ ,
                                 int /*sx */ ,
                                 int /*sy */ ,
                                 int /*w */ ,
                                 int /*h */ ,
                                 uint /*format */ ,
                                 ulong /*planeMask */ ,
                                 char * /*pdstLine */ )  @nogc nothrow;

alias GetSpansProcPtr = void function(DrawablePtr /*pDrawable */ ,
                                 int /*wMax */ ,
                                 DDXPointPtr /*ppt */ ,
                                 int * /*pwidth */ ,
                                 int /*nspans */ ,
                                 char * /*pdstStart */ )  @nogc nothrow;

alias SourceValidateProcPtr = void function(DrawablePtr /*pDrawable */ ,
                                       int /*x */ ,
                                       int /*y */ ,
                                       int /*width */ ,
                                       int /*height */ ,
                                       uint /*subWindowMode */ )  @nogc nothrow;

alias CreateWindowProcPtr = Bool function(WindowPtr /*pWindow */ )  @nogc nothrow;

alias DestroyWindowProcPtr = Bool function(WindowPtr /*pWindow */ )  @nogc nothrow;

alias PositionWindowProcPtr = Bool function(WindowPtr /*pWindow */ ,
                                       int /*x */ ,
                                       int /*y */ )  @nogc nothrow;

alias ChangeWindowAttributesProcPtr = Bool function(WindowPtr /*pWindow */ ,
                                               ulong /*mask */ )  @nogc nothrow;

alias RealizeWindowProcPtr = Bool function(WindowPtr /*pWindow */ )  @nogc nothrow;

alias UnrealizeWindowProcPtr = Bool function(WindowPtr /*pWindow */ )  @nogc nothrow;

alias RestackWindowProcPtr = void function(WindowPtr /*pWindow */ ,
                                      WindowPtr /*pOldNextSib */ )  @nogc nothrow;

alias ValidateTreeProcPtr = int function(WindowPtr /*pParent */ ,
                                    WindowPtr /*pChild */ ,
                                    VTKind /*kind */ )  @nogc nothrow;

alias PostValidateTreeProcPtr = void function(WindowPtr /*pParent */ ,
                                         WindowPtr /*pChild */ ,
                                         VTKind /*kind */ )  @nogc nothrow;

alias WindowExposuresProcPtr = void function(WindowPtr /*pWindow */ ,
                                        RegionPtr /*prgn */)  @nogc nothrow;

alias PaintWindowProcPtr = void function(WindowPtr /*pWindow*/,
                                    RegionPtr /*pRegion*/,
                                    int /*what*/)  @nogc nothrow;

alias CopyWindowProcPtr = void function(WindowPtr /*pWindow */ ,
                                   xPoint /*ptOldOrg */ ,
                                   RegionPtr /*prgnSrc */ )  @nogc nothrow;

alias ClearToBackgroundProcPtr = void function(WindowPtr /*pWindow */ ,
                                          int /*x */ ,
                                          int /*y */ ,
                                          int /*w */ ,
                                          int /*h */ ,
                                          Bool /*generateExposures */ )  @nogc nothrow;

alias ClipNotifyProcPtr = void function(WindowPtr /*pWindow */ ,
                                   int /*dx */ ,
                                   int /*dy */ )  @nogc nothrow;

alias SetWindowVRRModeProcPtr = void function(WindowPtr pWindow, WindowVRRMode mode)  @nogc nothrow;

/* pixmap will exist only for the duration of the current rendering operation */
enum CREATE_PIXMAP_USAGE_SCRATCH =                     1;
/* pixmap will be the backing pixmap for a redirected window */
enum CREATE_PIXMAP_USAGE_BACKING_PIXMAP =              2;
/* pixmap will contain a glyph */
enum CREATE_PIXMAP_USAGE_GLYPH_PICTURE =               3;
/* pixmap will be shared */
enum CREATE_PIXMAP_USAGE_SHARED =                      4;

alias CreatePixmapProcPtr = PixmapPtr function(ScreenPtr /*pScreen */ ,
                                          int /*width */ ,
                                          int /*height */ ,
                                          int /*depth */ ,
                                          uint /*usage_hint */ ) @nogc nothrow;

alias DestroyPixmapProcPtr = Bool function(PixmapPtr /*pPixmap */ ) @nogc nothrow;

alias RealizeFontProcPtr = Bool function(ScreenPtr /*pScreen */ ,
                                    FontPtr /*pFont */ ) @nogc nothrow;

alias UnrealizeFontProcPtr = Bool function(ScreenPtr /*pScreen */ ,
                                      FontPtr /*pFont */ ) @nogc nothrow;

alias ConstrainCursorProcPtr = void function(DeviceIntPtr /*pDev */ ,
                                        ScreenPtr /*pScreen */ ,
                                        BoxPtr /*pBox */ ) @nogc nothrow;

alias CursorLimitsProcPtr = void function(DeviceIntPtr /* pDev */ ,
                                     ScreenPtr /*pScreen */ ,
                                     CursorPtr /*pCursor */ ,
                                     BoxPtr /*pHotBox */ ,
                                     BoxPtr /*pTopLeftBox */ ) @nogc nothrow;

alias DisplayCursorProcPtr = Bool function(DeviceIntPtr /* pDev */ ,
                                      ScreenPtr /*pScreen */ ,
                                      CursorPtr /*pCursor */ ) @nogc nothrow;

alias RealizeCursorProcPtr = Bool function(DeviceIntPtr /* pDev */ ,
                                      ScreenPtr /*pScreen */ ,
                                      CursorPtr /*pCursor */ ) @nogc nothrow;

alias UnrealizeCursorProcPtr = Bool function(DeviceIntPtr /* pDev */ ,
                                        ScreenPtr /*pScreen */ ,
                                        CursorPtr /*pCursor */ ) @nogc nothrow;

alias RecolorCursorProcPtr = void function(DeviceIntPtr /* pDev */ ,
                                      ScreenPtr /*pScreen */ ,
                                      CursorPtr /*pCursor */ ,
                                      Bool /*displayed */ ) @nogc nothrow;

alias SetCursorPositionProcPtr = Bool function(DeviceIntPtr /* pDev */ ,
                                          ScreenPtr /*pScreen */ ,
                                          int /*x */ ,
                                          int /*y */ ,
                                          Bool /*generateEvent */ ) @nogc nothrow;

alias CursorWarpedToProcPtr = void function(DeviceIntPtr /* pDev */ ,
                                       ScreenPtr /*pScreen */ ,
                                       ClientPtr /*pClient */ ,
                                       WindowPtr /*pWindow */ ,
                                       SpritePtr /*pSprite */ ,
                                       int /*x */ ,
                                       int /*y */ ) @nogc nothrow;

alias CursorConfinedToProcPtr = void function(DeviceIntPtr /* pDev */ ,
                                         ScreenPtr /*pScreen */ ,
                                         WindowPtr /*pWindow */ ) @nogc nothrow;

alias CreateGCProcPtr = Bool function(GCPtr /*pGC */ ) @nogc nothrow;

alias CreateColormapProcPtr = Bool function(ColormapPtr /*pColormap */ ) @nogc nothrow;

alias DestroyColormapProcPtr = void function(ColormapPtr /*pColormap */ ) @nogc nothrow;

alias InstallColormapProcPtr = void function(ColormapPtr /*pColormap */ ) @nogc nothrow;

alias UninstallColormapProcPtr = void function(ColormapPtr /*pColormap */ ) @nogc nothrow;

// alias ListInstalledColormapsProcPtr = void function(ScreenPtr /*pScreen */ ,
//                                               XID * /*pmaps */ ) @nogc nothrow;

alias StoreColorsProcPtr = void function(ColormapPtr /*pColormap */ ,
                                    int /*ndef */ ,
                                    xColorItem * /*pdef */ ) @nogc nothrow;

alias ResolveColorProcPtr = void function(ushort * /*pred */ ,
                                     ushort * /*pgreen */ ,
                                     ushort * /*pblue */ ,
                                     VisualPtr /*pVisual */ ) @nogc nothrow;

alias BitmapToRegionProcPtr = pixman_region16* function(PixmapPtr /*pPix */ ) @nogc nothrow;

alias ScreenBlockHandlerProcPtr = void function(ScreenPtr pScreen,
                                           void *timeout) @nogc nothrow;

/* result has three possible values:
 * < 0 - error
 * = 0 - timeout
 * > 0 - activity
 */
alias ScreenWakeupHandlerProcPtr = void function(ScreenPtr pScreen,
                                            int result) @nogc nothrow;

alias CreateScreenResourcesProcPtr = Bool function(ScreenPtr /*pScreen */ ) @nogc nothrow;

alias ModifyPixmapHeaderProcPtr = Bool function(PixmapPtr pPixmap,
                                           int width,
                                           int height,
                                           int depth,
                                           int bitsPerPixel,
                                           int devKind,
                                           void *pPixData) @nogc nothrow;

alias GetWindowPixmapProcPtr = PixmapPtr function(WindowPtr /*pWin */ ) @nogc nothrow;

alias SetWindowPixmapProcPtr = void function(WindowPtr /*pWin */ ,
                                        PixmapPtr /*pPix */ ) @nogc nothrow;

alias GetScreenPixmapProcPtr = PixmapPtr function(ScreenPtr /*pScreen */ ) @nogc nothrow;

alias SetScreenPixmapProcPtr = void function(PixmapPtr /*pPix */ ) @nogc nothrow;

alias MarkWindowProcPtr = void function(WindowPtr /*pWin */ ) @nogc nothrow;

alias MarkOverlappedWindowsProcPtr = Bool function(WindowPtr /*parent */ ,
                                              WindowPtr /*firstChild */ ,
                                              WindowPtr * /*pLayerWin */ ) @nogc nothrow;

alias ConfigNotifyProcPtr = int function(WindowPtr /*pWin */ ,
                                    int /*x */ ,
                                    int /*y */ ,
                                    int /*w */ ,
                                    int /*h */ ,
                                    int /*bw */ ,
                                    WindowPtr /*pSib */ ) @nogc nothrow;

alias MoveWindowProcPtr = void function(WindowPtr /*pWin */ ,
                                   int /*x */ ,
                                   int /*y */ ,
                                   WindowPtr /*pSib */ ,
                                   VTKind /*kind */ ) @nogc nothrow;

alias ResizeWindowProcPtr = void function(WindowPtr /*pWin */ ,
                                     int /*x */ ,
                                     int /*y */ ,
                                     uint /*w */ ,
                                     uint /*h*/ ,
                                     WindowPtr/*pSib */
    ) @nogc nothrow;

alias GetLayerWindowProcPtr = WindowPtr function(WindowPtr   /*pWin */
    ) @nogc nothrow;

alias HandleExposuresProcPtr = void function(WindowPtr /*pWin */ ) @nogc nothrow;

alias ReparentWindowProcPtr = void function(WindowPtr /*pWin */ ,
                                       WindowPtr /*pPriorParent */ ) @nogc nothrow;

alias SetShapeProcPtr = void function(WindowPtr /*pWin */ ,
                                 int /* kind */ ) @nogc nothrow;

alias ChangeBorderWidthProcPtr = void function(WindowPtr /*pWin */ ,
                                          uint /*width */ ) @nogc nothrow;

alias MarkUnrealizedWindowProcPtr = void function(WindowPtr /*pChild */ ,
                                             WindowPtr /*pWin */ ,
                                             Bool /*fromConfigure */ ) @nogc nothrow;

alias DeviceCursorInitializeProcPtr = Bool function(DeviceIntPtr /* pDev */ ,
                                               ScreenPtr /* pScreen */ ) @nogc nothrow;

alias DeviceCursorCleanupProcPtr = void function(DeviceIntPtr /* pDev */ ,
                                            ScreenPtr /* pScreen */ ) @nogc nothrow;

alias ConstrainCursorHarderProcPtr = void function(DeviceIntPtr, ScreenPtr, int,
                                              int *, int *) @nogc nothrow;


alias SharePixmapBackingProcPtr = Bool function(PixmapPtr, ScreenPtr, void **) @nogc nothrow;

alias SetSharedPixmapBackingProcPtr = Bool function(PixmapPtr, void *) @nogc nothrow;

enum HAS_SYNC_SHARED_PIXMAP = 1;
/* The SyncSharedPixmap hook has two purposes:
 *
 * 1. If the primary driver has it, the secondary driver can use it to
 * synchronize the shared pixmap contents with the screen pixmap.
 * 2. If the secondary driver has it, the primary driver can expect the secondary
 * driver to call the primary screen's SyncSharedPixmap hook, so the primary
 * driver doesn't have to synchronize the shared pixmap contents itself,
 * e.g. from the BlockHandler.
 *
 * A driver must only set the hook if it handles both cases correctly.
 *
 * The argument is the secondary screen's pixmap_dirty_list entry, the hook is
 * responsible for finding the corresponding entry in the primary screen's
 * pixmap_dirty_list.
 */
alias SyncSharedPixmapProcPtr = void function(PixmapDirtyUpdatePtr);

alias StartPixmapTrackingProcPtr = Bool function(DrawablePtr, PixmapPtr,
                                           int x, int y,
                                           int dst_x, int dst_y,
                                           Rotation rotation);

alias PresentSharedPixmapProcPtr = Bool function(PixmapPtr);

alias RequestSharedPixmapNotifyDamageProcPtr = Bool function(PixmapPtr);

alias StopPixmapTrackingProcPtr = Bool function(DrawablePtr, PixmapPtr);

alias StopFlippingPixmapTrackingProcPtr = Bool function(DrawablePtr,
                                                  PixmapPtr, PixmapPtr);

alias SharedPixmapNotifyDamageProcPtr = Bool function(PixmapPtr);

alias ReplaceScanoutPixmapProcPtr = Bool function(DrawablePtr, PixmapPtr, Bool);

alias XYToWindowProcPtr = WindowPtr function(ScreenPtr pScreen,
                                       SpritePtr pSprite, int x, int y);

alias NameWindowPixmapProcPtr = int function(WindowPtr, PixmapPtr, CARD32);

alias DPMSProcPtr = void function(ScreenPtr pScreen, int level);

/* Wrapping Screen procedures

   There are a few modules in the X server which dynamically add and
    remove themselves from various screen procedure call chains.

    For example, the BlockHandler is dynamically modified by:

     * xf86Rotate
     * miSprite
     * composite
     * render (for animated cursors)

    Correctly manipulating this chain is complicated by the fact that
    the chain is constructed through a sequence of screen private
    structures, each holding the next screen->proc pointer.

    To add a module include.to a screen->proc chain is fairly simple; just save
    the current screen->proc value in the module include.screen private
    and store the module's function in the screen->proc location.

    Removing a screen proc is a bit trickier. It seems like all you
    need to do is set the screen->proc pointer back to the value saved
    in your screen private. However, if some other module include.has come
    along and wrapped on top of you, then the right place to store the
    previous screen->proc value is actually in the wrapping module's
    screen private structure(!). Of course, you have no idea what
    other module include.may have wrapped on top, nor could you poke inside
    its screen private in any case.

    To make this work, we restrict the unwrapping process to happen
    during the invocation of the screen proc itself, and then we
    require the screen proc to take some care when manipulating the
    screen proc functions pointers.

    The requirements are:

     1) The screen proc must set the screen->proc pointer back to the
        value saved in its screen private before calling outside its
        module.

     2a) If the screen proc wants to be remove itself from the chain,
         it must not manipulate screen->proc pointer again before
         returning.

     2b) If the screen proc wants to remain in the chain, it must:

       2b.1) Re-fetch the screen->proc pointer and store that in
             its screen private. This ensures that any changes
             to the chain will be preserved.

       2b.2) Set screen->proc back to itself

    One key requirement here is that these steps must wrap not just
    any invocation of the nested screen->proc value, but must nest
    essentially any calls outside the current module. This ensures
    that other modules can reliably manipulate screen->proc wrapping
    using these same rules.

    For example, the animated cursor code in render has two macros,
    Wrap and Unwrap.

        #define Unwrap(as,s,elt)    ((s)->elt = (as)->elt)

    Unwrap takes the screen private (as), the screen (s) and the
    member name (elt), and restores screen->proc to that saved in the
    screen private.

        #define Wrap(as,s,elt,func) (((as)->elt = (s)->elt), (s)->elt = func)

    Wrap takes the screen private (as), the screen (s), the member
    name (elt) and the wrapping function (func). It saves the
    current screen->proc value in the screen private, and then sets the
    screen->proc to the local wrapping function.

    Within each of these functions, there's a pretty simple pattern:

        Unwrap(as, pScreen, UnrealizeCursor);

        // Do local stuff, including possibly calling down through
        // pScreen->UnrealizeCursor

        Wrap(as, pScreen, UnrealizeCursor, AnimCurUnrealizeCursor);

    The wrapping block handler is a bit different; it does the Unwrap,
    the local operations, and then only re-Wraps if the hook is still
    required. Unwrap occurs at the top of each function, just after
    entry, and Wrap occurs at the bottom of each function, just
    before returning.

    DestroyWindow() should NOT be wrapped anymore
    use dixScreenHookWindowDestroy() instead.
 */

template _SCREEN_HOOK_TYPE(NAME, FUNCTYPE, ARRSIZE) {
	struct _NAME {
		FUNCTYPE func;
		void* arg;
	}

	_NAME[ARRSIZE] NAME;
}

struct _Screen {
    int myNum;                  /* index of this instance in Screens[] */
    ATOM id;
    short x, y, width, height;
    short mmWidth, mmHeight;
    short numDepths;
    ubyte rootDepth;
    DepthPtr allowedDepths;
    ulong rootVisual;
    ulong defColormap;
    short minInstalledCmaps, maxInstalledCmaps;
    char backingStoreSupport, saveUnderSupport;
    ulong whitePixel, blackPixel;
    GCPtr[MAXFORMATS + 1] GCperDepth;
    /* next field is a stipple to use as default in a GC.  we don't build
     * default tiles of all depths because they are likely to be of a color
     * different from the default fg pixel, so we don't win anything by
     * building a standard one.
     */
    PixmapPtr defaultStipple;
    void *devPrivate;
    short numVisuals;
    VisualPtr visuals;
    WindowPtr root;
    ScreenSaverStuffRec screensaver;

    DevPrivateSetRec[PRIVATE_LAST]    screenSpecificPrivates;

    /* Random screen procedures */

    CloseScreenProcPtr CloseScreen;
    QueryBestSizeProcPtr QueryBestSize;
    SaveScreenProcPtr SaveScreen;
    GetImageProcPtr GetImage;
    GetSpansProcPtr GetSpans;
    SourceValidateProcPtr SourceValidate;

    /* Window Procedures */

    CreateWindowProcPtr CreateWindow;
    DestroyWindowProcPtr DestroyWindow;
    PositionWindowProcPtr PositionWindow;
    ChangeWindowAttributesProcPtr ChangeWindowAttributes;
    RealizeWindowProcPtr RealizeWindow;
    UnrealizeWindowProcPtr UnrealizeWindow;
    ValidateTreeProcPtr ValidateTree;
    PostValidateTreeProcPtr PostValidateTree;
    WindowExposuresProcPtr WindowExposures;
    CopyWindowProcPtr CopyWindow;
    ClearToBackgroundProcPtr ClearToBackground;
    ClipNotifyProcPtr ClipNotify;
    RestackWindowProcPtr RestackWindow;
    PaintWindowProcPtr PaintWindow;

    /* Pixmap procedures */

    CreatePixmapProcPtr CreatePixmap;
    DestroyPixmapProcPtr DestroyPixmap;

    /* Font procedures */

    RealizeFontProcPtr RealizeFont;
    UnrealizeFontProcPtr UnrealizeFont;

    /* Cursor Procedures */

    ConstrainCursorProcPtr ConstrainCursor;
    ConstrainCursorHarderProcPtr ConstrainCursorHarder;
    CursorLimitsProcPtr CursorLimits;
    DisplayCursorProcPtr DisplayCursor;
    RealizeCursorProcPtr RealizeCursor;
    UnrealizeCursorProcPtr UnrealizeCursor;
    RecolorCursorProcPtr RecolorCursor;
    SetCursorPositionProcPtr SetCursorPosition;
    CursorWarpedToProcPtr CursorWarpedTo;
    CursorConfinedToProcPtr CursorConfinedTo;

    /* GC procedures */

    CreateGCProcPtr CreateGC;

    /* Colormap procedures */

    CreateColormapProcPtr CreateColormap;
    DestroyColormapProcPtr DestroyColormap;
    InstallColormapProcPtr InstallColormap;
    UninstallColormapProcPtr UninstallColormap;
    ListInstalledColormapsProcPtr ListInstalledColormaps;
    StoreColorsProcPtr StoreColors;
    ResolveColorProcPtr ResolveColor;

    /* Region procedures */

    BitmapToRegionProcPtr BitmapToRegion;

    /* os layer procedures */

    ScreenBlockHandlerProcPtr BlockHandler;
    ScreenWakeupHandlerProcPtr WakeupHandler;

    /* anybody can get a piece of this array */
    PrivateRec *devPrivates;

    CreateScreenResourcesProcPtr CreateScreenResources;
    ModifyPixmapHeaderProcPtr ModifyPixmapHeader;

    GetWindowPixmapProcPtr GetWindowPixmap;
    SetWindowPixmapProcPtr SetWindowPixmap;
    GetScreenPixmapProcPtr GetScreenPixmap;
    SetScreenPixmapProcPtr SetScreenPixmap;
    NameWindowPixmapProcPtr NameWindowPixmap;

// #ifdef CONFIG_LEGACY_NVIDIA_PADDING
//     /* This field is used by the 470 and 390 proprietary nvidia DDX driver, and should always be NULL */
    void* reserved_for_nvidia_470_and_390;
// #endif

    uint totalPixmapSize;

    MarkWindowProcPtr MarkWindow;
    MarkOverlappedWindowsProcPtr MarkOverlappedWindows;
    ConfigNotifyProcPtr ConfigNotify;
    MoveWindowProcPtr MoveWindow;
    ResizeWindowProcPtr ResizeWindow;
    GetLayerWindowProcPtr GetLayerWindow;
    HandleExposuresProcPtr HandleExposures;
    ReparentWindowProcPtr ReparentWindow;

    SetShapeProcPtr SetShape;

    ChangeBorderWidthProcPtr ChangeBorderWidth;
    MarkUnrealizedWindowProcPtr MarkUnrealizedWindow;

    /* Device cursor procedures */
    DeviceCursorInitializeProcPtr DeviceCursorInitialize;
    DeviceCursorCleanupProcPtr DeviceCursorCleanup;

    /* set it in driver side if X server can copy the framebuffer content.
     * Meant to be used together with '-background none' option, avoiding
     * malicious users to steal framebuffer's content if that would be the
     * default */
    Bool canDoBGNoneRoot;

    Bool isGPU;

    /* Info on this screen's secondarys (if any) */
    xorg_list secondary_list;
    xorg_list secondary_head;
    int output_secondarys;
    /* Info for when this screen is a secondary */
    ScreenPtr current_primary;
    Bool is_output_secondary;
    Bool is_offload_secondary;

    SharePixmapBackingProcPtr SharePixmapBacking;
    SetSharedPixmapBackingProcPtr SetSharedPixmapBacking;

    StartPixmapTrackingProcPtr StartPixmapTracking;
    StopPixmapTrackingProcPtr StopPixmapTracking;
    SyncSharedPixmapProcPtr SyncSharedPixmap;

    SharedPixmapNotifyDamageProcPtr SharedPixmapNotifyDamage;
    RequestSharedPixmapNotifyDamageProcPtr RequestSharedPixmapNotifyDamage;
    PresentSharedPixmapProcPtr PresentSharedPixmap;
    StopFlippingPixmapTrackingProcPtr StopFlippingPixmapTracking;

    xorg_list pixmap_dirty_list;

    ReplaceScanoutPixmapProcPtr ReplaceScanoutPixmap;
    XYToWindowProcPtr XYToWindow;
    DPMSProcPtr DPMS;

    /* ===== below here is PRIVATE ==== drivers MUST NEVER touch it ===== */

    /* additional window destructors (replaces wrapping DestroyWindow).
       should NOT be touched outside of DIX core */
    CallbackListPtr hookWindowDestroy;

    /* additional window position notify hooks (replaces wrapping PositionWindow)
       should NOT be touched outside of DIX core */
    CallbackListPtr hookWindowPosition;

    /* additional screen close notify hooks (replaces wrapping CloseScreen)
       should NOT be touched outside of DIX core */
    CallbackListPtr hookClose;

    /* additional pixmap destroy notify hooks (replaces wrapping DestroyPixmap)
       should NOT be touched outside of DIX core */
    CallbackListPtr hookPixmapDestroy;

    /* hooks run right after SUCCESSFUL Creatv fueScreenResources
       should NOT be touched outside of DIX core */
    CallbackListPtr hookPostCreateResources;

    SetWindowVRRModeProcPtr SetWindowVRRMode;

    /* additional screen post-close notify hooks (replaces wrapping CloseScreen)
       should NOT be touched outside of DIX core */
    CallbackListPtr hookPostClose;
} 
alias ScreenRec = _Screen;

RegionPtr BitmapToRegion(ScreenPtr _pScreen, PixmapPtr pPix)
{
    return (*(_pScreen).BitmapToRegion) (pPix);        /* no mi version?! */
}

struct _ScreenInfo {
    int imageByteOrder;
    int bitmapScanlineUnit;
    int bitmapScanlinePad;
    int bitmapBitOrder;
    int numPixmapFormats;
    _PixmapFormat[MAXFORMATS] formats;
    int numScreens;
    ScreenPtr[MAXSCREENS] screens;
    int numGPUScreens;
    ScreenPtr[MAXGPUSCREENS] gpuscreens;
    int x;                      /* origin */
    int y;                      /* origin */
    int width;                  /* total width of all screens together */
    int height;                 /* total height of all screens together */
}
alias ScreenInfo = _ScreenInfo;

// ScreenInfo screenInfo;
