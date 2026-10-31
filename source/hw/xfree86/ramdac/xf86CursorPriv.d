module hw.xfree86.ramdac.xf86CursorPriv;
@nogc nothrow:
extern(C): __gshared:
 
public import build.xorg_config;

public import include.xf86Cursor;
public import include.mipointrst;
public import include.mipointer;
import hw.xfree86.modes.displaymode;

struct _Xf86CursorScreenRec {
    Bool SWCursor;
    Bool isUp;
    Bool showTransparent;
    short HotX;
    short HotY;
    short x;
    short y;
    CursorPtr CurrentCursor, CursorToRestore;
    xf86CursorInfoPtr CursorInfoPtr;
    CloseScreenProcPtr CloseScreen;
    RecolorCursorProcPtr RecolorCursor;
    InstallColormapProcPtr InstallColormap;
    QueryBestSizeProcPtr QueryBestSize;
    miPointerSpriteFuncPtr spriteFuncs;
    Bool PalettedCursor;
    ColormapPtr pInstalledMap;
    Bool function(ScrnInfoPtr, DisplayModePtr) @nogc nothrow SwitchMode;
    xf86EnableDisableFBAccessProc EnableDisableFBAccess;
    CursorPtr SavedCursor;

    /* Number of requests to force HW cursor */
    int ForceHWCursorCount;
    Bool HWCursorForced;

    void* transparentData;
}alias xf86CursorScreenRec = _Xf86CursorScreenRec;
alias xf86CursorScreenPtr = xf86CursorScreenRec*;

Bool xf86SetCursor(ScreenPtr pScreen, CursorPtr pCurs, int x, int y);
void xf86SetTransparentCursor(ScreenPtr pScreen);
void xf86MoveCursor(ScreenPtr pScreen, int x, int y);
void xf86RecolorCursor(ScreenPtr pScreen, CursorPtr pCurs, Bool displayed);
Bool xf86InitHardwareCursor(ScreenPtr pScreen, xf86CursorInfoPtr infoPtr);

Bool xf86CheckHWCursor(ScreenPtr pScreen, CursorPtr cursor, xf86CursorInfoPtr infoPtr);
// export DevPrivateKeyRec xf86CursorScreenKeyRec;

// DevScreenPrivateKeyRec xf86ScreenCursorBitsKeyRec;

                          /* _XF86CURSORPRIV_H */
