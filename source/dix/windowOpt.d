module dix.windowOpt;

// ? No need more imports here O_o
import dix.devCursor;

struct WindowOpt {
    CursorPtr cursor;           /* default: window.cursorNone */
    VisualID visual;            /* default: same as parent */
    Colormap colormap;          /* default: same as parent */
    Mask dontPropagateMask;     /* default: window.dontPropagate */
    Mask otherEventMasks;       /* default: 0 */
    _OtherClients* otherClients; /* default: NULL */
    _GrabRec* passiveGrabs;      /* default: NULL */
    CARD32 backingBitPlanes = ~0;    /* default: ~0L */
    CARD32 backingPixel;        /* default: 0 */
    RegionPtr boundingShape;    /* default: NULL */
    RegionPtr clipShape;        /* default: NULL */
    RegionPtr inputShape;       /* default: NULL */
    _OtherInputMasks* inputMasks;        /* default: NULL */
    DevCursorList deviceCursors;        /* default: NULL */

@nogc: nothrow:
    void initByWindow(WindowPtr win, bool isWindowRoot = false) {
        this.otherEventMasks = 0;
        this.otherClients = null;
        this.passiveGrabs = null;
        this.backingBitPlanes = ~0;
        this.backingPixel = 0;
        this.boundingShape = null;
        this.clipShape = null;
        this.inputShape = null;
        this.inputMasks = null;
        this.deviceCursors = null;

        if(isWindowRoot) {
            this.colormap = cast(uint)win.drawable.pScreen.defColormap;
            this.visual = cast(uint)win.drawable.pScreen.rootVisual;
            // XXX : setted by MakeRootWindow
            // pWin.cursorIsNone = False;
            // this.cursor = RefCursor(rootCursor);

        }
        else {
            this.dontPropagateMask = DontPropagateMasks[win.dontPropagate];
            auto parentOptional = FindWindowWithOptional(win).optional;
            this.visual = parentOptional.visual;

            if (!win.cursorIsNone) {
                this.cursor = RefCursor(parentOptional.cursor);
            }
            else {
                this.cursor = null;
            }

            this.colormap = parentOptional.colormap;
        }
    }
}
alias WindowOptPtr = WindowOpt*;