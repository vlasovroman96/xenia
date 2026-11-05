module hw.xfree86.fbdevhw.fbdevhwstub;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import hw.xfree86.common.xf86Helper;
import xf86cmap;
import externs.pciaccess;
import os.log;

/* Stubs for the static server on platforms that don't support fbdev */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWProbe(pci_device* pPci, const(char)* device, char** namep)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWInit(ScrnInfoPtr pScrn, pci_device* pPci, const(char)* device)
{
    LogMessageVerb(X_ERROR, 1, "fbdevhw is not available on this platform\n");
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
char* fbdevHWGetName(ScrnInfoPtr pScrn)
{
    return null;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetDepth(ScrnInfoPtr pScrn, int* fbbpp)
{
    return -1;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetLineLength(ScrnInfoPtr pScrn)
{
    return -1;                  /* Should cause something spectacular... */
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetType(ScrnInfoPtr pScrn)
{
    return -1;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetVidmem(ScrnInfoPtr pScrn)
{
    return -1;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWSetVideoModes(ScrnInfoPtr pScrn)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWUseBuildinMode(ScrnInfoPtr pScrn)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void* fbdevHWMapVidmem(ScrnInfoPtr pScrn)
{
    return null;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWLinearOffset(ScrnInfoPtr pScrn)
{
    return 0;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWUnmapVidmem(ScrnInfoPtr pScrn)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void* fbdevHWMapMMIO(ScrnInfoPtr pScrn)
{
    return null;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWUnmapMMIO(ScrnInfoPtr pScrn)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWModeInit(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWSave(ScrnInfoPtr pScrn)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWRestore(ScrnInfoPtr pScrn)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWLoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
ModeStatus fbdevHWValidMode(ScrnInfoPtr pScrn, DisplayModePtr mode, Bool verbose, int flags)
{
    return MODE_ERROR;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWAdjustFrame(ScrnInfoPtr pScrn, int x, int y)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWEnterVT(ScrnInfoPtr pScrn)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWLeaveVT(ScrnInfoPtr pScrn)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWDPMSSet(ScrnInfoPtr pScrn, int mode, int flags)
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWSaveScreen(ScreenPtr pScreen, int mode)
{
    return FALSE;
}

xf86SwitchModeProc fbdevHWSwitchModeWeak()
{
    return &fbdevHWSwitchMode;
}

xf86AdjustFrameProc fbdevHWAdjustFrameWeak()
{
    return &fbdevHWAdjustFrame;
}

xf86LeaveVTProc fbdevHWLeaveVTWeak()
{
    return &fbdevHWLeaveVT;
}

xf86ValidModeProc fbdevHWValidModeWeak()
{
    return &fbdevHWValidMode;
}

xf86DPMSSetProc fbdevHWDPMSSetWeak()
{
    return &fbdevHWDPMSSet;
}

xf86LoadPaletteProc fbdevHWLoadPaletteWeak()
{
    return &fbdevHWLoadPalette;
}
