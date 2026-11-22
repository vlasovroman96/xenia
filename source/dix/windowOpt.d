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

    void dispose() {
        /*
        * everything is peachy.  Delete the optional record
        * and clean up
        */
        FreeCursor(this.cursor, cast(Cursor) 0);

        //TODO: migrate it on common.list interface
        if (this.deviceCursors) {
            DevCursorList pList = void;
            DevCursorList pPrev = void;

            pList = this.deviceCursors;
            while (pList) {
                FreeCursor(pList.cursor, cast(XID) 0);
                pPrev = pList;
                pList = pList.next;
                free(pPrev);
            }
            this.deviceCursors = null;
        }
    }
}
alias WindowOptPtr = WindowOpt*;

// struct WindowOptGetter {
//     RegionPtr function() getClipShape;
//     _OtherClients* function() getOtherClients;
//     Mask function() getOtherEventMasks;
//     _OtherInputMasks* function() getOtherInputMasks;
//     // _OtherClients*  = useDefault!(`otherClients`, null);
//     alias getOtherInputMasks = useDefault!(`inputMasks`, null);
//     alias getPassiveGrabs = useDefault!(`passiveGrabs`, null);
//     alias getBackingBitPlanes = useDefault!(`backingBitPlanes`, ~0L);
//     alias getBackingPixel = useDefault!(`backingPixel`, 0);
//     alias getBoundingShape = useDefault!(`boundingShape`, null);
//     alias getInputShape = useDefault!(`inputShape`, null);

//     auto getDontPropagateMask() => this.optional ? 
//             this.optional.dontPropagateMask : 
//             DontPropagateMasks[this.dontPropagate];
//     auto getCursor() => this.cursorIsNone ? null : getTrackParent!`cursor`;
//     auto getColormap() => this.drawable.class_ == InputOnly ? None : getTrackParent!`colormap`;
//     alias getVisual = getTrackParent!(`visual`);
//     WindowOptPtr opts;

//     this(WindowOptPtr opts) {
//         this.opts = opts;
//     }
// }

// enum WindowOptGettet defaultGetter = {

// }

// auto getter(WindowOptPtr opts) => WindowOptGetter(opts);