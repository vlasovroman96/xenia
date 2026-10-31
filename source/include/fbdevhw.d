module include.fbdevhw;
@nogc nothrow:
extern(C): __gshared:

 
public import include.xf86str;
import externs.pciaccess;
public import build.dix_config;
import hw.xfree86.modes.displaymode;

enum FBDEVHW_PACKED_PIXELS =		0       /* Packed Pixels        */;
enum FBDEVHW_INTERLEAVED_PLANES =	2       /* Interleaved planes   */;
enum FBDEVHW_TEXT =			3       /* Text/attributes      */;
enum FBDEVHW_VGA_PLANES =		4       /* EGA/VGA planes       */;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWProbe(pci_device* pPci, const(char)* device, char** namep);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWInit(ScrnInfoPtr pScrn, pci_device* pPci, const(char)* device);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int* fbdevHWGetName(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetDepth(ScrnInfoPtr pScrn, int* fbbpp);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetLineLength(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetType(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetVidmem(ScrnInfoPtr pScrn);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int* fbdevHWMapVidmem(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWLinearOffset(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWUnmapVidmem(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int* fbdevHWMapMMIO(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWUnmapMMIO(ScrnInfoPtr pScrn);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWSetVideoModes(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWUseBuildinMode(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWModeInit(ScrnInfoPtr pScrn, DisplayModePtr mode);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWSave(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWRestore(ScrnInfoPtr pScrn);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWLoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWValidMode(ScrnInfoPtr pScrn, DisplayModePtr mode, Bool verbose, int flags);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWAdjustFrame(ScrnInfoPtr pScrn, int x, int y);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWEnterVT(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWLeaveVT(ScrnInfoPtr pScrn);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWDPMSSet(ScrnInfoPtr pScrn, int mode, int flags);

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWSaveScreen(ScreenPtr pScreen, int mode);

xf86SwitchModeProc *fbdevHWSwitchModeWeak();
xf86AdjustFrameProc *fbdevHWAdjustFrameWeak();
xf86LeaveVTProc *fbdevHWLeaveVTWeak();
xf86ValidModeProc *fbdevHWValidModeWeak();
xf86DPMSSetProc *fbdevHWDPMSSetWeak();
xf86LoadPaletteProc *fbdevHWLoadPaletteWeak();


