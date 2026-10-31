module include.vidmodestr;
@nogc nothrow:
extern(C): __gshared:
 
public import hw.xfree86.modes.displaymode;
import build.xlibre_server;

enum VidModeSelectMode {
    VIDMODE_H_DISPLAY,
    VIDMODE_H_SYNCSTART,
    VIDMODE_H_SYNCEND,
    VIDMODE_H_TOTAL,
    VIDMODE_H_SKEW,
    VIDMODE_V_DISPLAY,
    VIDMODE_V_SYNCSTART,
    VIDMODE_V_SYNCEND,
    VIDMODE_V_TOTAL,
    VIDMODE_FLAGS,
    VIDMODE_CLOCK
}
alias VIDMODE_H_DISPLAY = VidModeSelectMode.VIDMODE_H_DISPLAY;
alias VIDMODE_H_SYNCSTART = VidModeSelectMode.VIDMODE_H_SYNCSTART;
alias VIDMODE_H_SYNCEND = VidModeSelectMode.VIDMODE_H_SYNCEND;
alias VIDMODE_H_TOTAL = VidModeSelectMode.VIDMODE_H_TOTAL;
alias VIDMODE_H_SKEW = VidModeSelectMode.VIDMODE_H_SKEW;
alias VIDMODE_V_DISPLAY = VidModeSelectMode.VIDMODE_V_DISPLAY;
alias VIDMODE_V_SYNCSTART = VidModeSelectMode.VIDMODE_V_SYNCSTART;
alias VIDMODE_V_SYNCEND = VidModeSelectMode.VIDMODE_V_SYNCEND;
alias VIDMODE_V_TOTAL = VidModeSelectMode.VIDMODE_V_TOTAL;
alias VIDMODE_FLAGS = VidModeSelectMode.VIDMODE_FLAGS;
alias VIDMODE_CLOCK = VidModeSelectMode.VIDMODE_CLOCK;


enum VidModeSelectMonitor {
    VIDMODE_MON_VENDOR,
    VIDMODE_MON_MODEL,
    VIDMODE_MON_NHSYNC,
    VIDMODE_MON_NVREFRESH,
    VIDMODE_MON_HSYNC_LO,
    VIDMODE_MON_HSYNC_HI,
    VIDMODE_MON_VREFRESH_LO,
    VIDMODE_MON_VREFRESH_HI
}
alias VIDMODE_MON_VENDOR = VidModeSelectMonitor.VIDMODE_MON_VENDOR;
alias VIDMODE_MON_MODEL = VidModeSelectMonitor.VIDMODE_MON_MODEL;
alias VIDMODE_MON_NHSYNC = VidModeSelectMonitor.VIDMODE_MON_NHSYNC;
alias VIDMODE_MON_NVREFRESH = VidModeSelectMonitor.VIDMODE_MON_NVREFRESH;
alias VIDMODE_MON_HSYNC_LO = VidModeSelectMonitor.VIDMODE_MON_HSYNC_LO;
alias VIDMODE_MON_HSYNC_HI = VidModeSelectMonitor.VIDMODE_MON_HSYNC_HI;
alias VIDMODE_MON_VREFRESH_LO = VidModeSelectMonitor.VIDMODE_MON_VREFRESH_LO;
alias VIDMODE_MON_VREFRESH_HI = VidModeSelectMonitor.VIDMODE_MON_VREFRESH_HI;


union vidMonitorValue {
    const(void)* ptr;
    int i;
    float f;
}

alias VidModeExtensionInitProcPtr = x11.Xdefs.Bool function(ScreenPtr pScreen);
alias VidModeGetMonitorValueProcPtr = vidMonitorValue function(ScreenPtr pScreen, int valtyp, int indx);
alias VidModeGetEnabledProcPtr = Bool function();
alias VidModeGetAllowNonLocalProcPtr = Bool function();
alias VidModeGetCurrentModelineProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock);
alias VidModeGetFirstModelineProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock);
alias VidModeGetNextModelineProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock);
alias VidModeDeleteModelineProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeZoomViewportProcPtr = Bool function(ScreenPtr pScreen, int zoom);
alias VidModeGetViewPortProcPtr = Bool function(ScreenPtr pScreen, int* x, int* y);
alias VidModeSetViewPortProcPtr = Bool function(ScreenPtr pScreen, int x, int y);
alias VidModeSwitchModeProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeLockZoomProcPtr = Bool function(ScreenPtr pScreen, Bool lock);
alias VidModeGetNumOfClocksProcPtr = int function(ScreenPtr pScreen, Bool* progClock);
alias VidModeGetClocksProcPtr = Bool function(ScreenPtr pScreen, int* Clocks);
alias VidModeCheckModeForMonitorProcPtr = ModeStatus function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeCheckModeForDriverProcPtr = ModeStatus function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeSetCrtcForModeProcPtr = void function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeAddModelineProcPtr = Bool function(ScreenPtr pScreen, DisplayModePtr mode);
alias VidModeGetDotClockProcPtr = int function(ScreenPtr pScreen, int Clock);
alias VidModeGetNumOfModesProcPtr = int function(ScreenPtr pScreen);
alias VidModeSetGammaProcPtr = Bool function(ScreenPtr pScreen, float red, float green, float blue);
alias VidModeGetGammaProcPtr = Bool function(ScreenPtr pScreen, float* red, float* green, float* blue);
alias VidModeSetGammaRampProcPtr = Bool function(ScreenPtr pScreen, int size, CARD16* red, CARD16* green, CARD16* blue);
alias VidModeGetGammaRampProcPtr = Bool function(ScreenPtr pScreen, int size, CARD16* red, CARD16* green, CARD16* blue);
alias VidModeGetGammaRampSizeProcPtr = int function(ScreenPtr pScreen);

struct _VidModeRec {
    DisplayModePtr First;
    DisplayModePtr Next;
    int Flags;

    VidModeExtensionInitProcPtr ExtensionInit;
    VidModeGetMonitorValueProcPtr GetMonitorValue;
    VidModeGetCurrentModelineProcPtr GetCurrentModeline;
    VidModeGetFirstModelineProcPtr GetFirstModeline;
    VidModeGetNextModelineProcPtr GetNextModeline;
    VidModeDeleteModelineProcPtr DeleteModeline;
    VidModeZoomViewportProcPtr ZoomViewport;
    VidModeGetViewPortProcPtr GetViewPort;
    VidModeSetViewPortProcPtr SetViewPort;
    VidModeSwitchModeProcPtr SwitchMode;
    VidModeLockZoomProcPtr LockZoom;
    VidModeGetNumOfClocksProcPtr GetNumOfClocks;
    VidModeGetClocksProcPtr GetClocks;
    VidModeCheckModeForMonitorProcPtr CheckModeForMonitor;
    VidModeCheckModeForDriverProcPtr CheckModeForDriver;
    VidModeSetCrtcForModeProcPtr SetCrtcForMode;
    VidModeAddModelineProcPtr AddModeline;
    VidModeGetDotClockProcPtr GetDotClock;
    VidModeGetNumOfModesProcPtr GetNumOfModes;
    VidModeSetGammaProcPtr SetGamma;
    VidModeGetGammaProcPtr GetGamma;
    VidModeSetGammaRampProcPtr SetGammaRamp;
    VidModeGetGammaRampProcPtr GetGammaRamp;
    VidModeGetGammaRampSizeProcPtr GetGammaRampSize;
}alias VidModeRec = _VidModeRec;
alias VidModePtr = VidModeRec*;

static if(XF86VIDMODE){
void VidModeAddExtension(Bool allow_non_local);
VidModePtr VidModeGetPtr(ScreenPtr pScreen);
VidModePtr VidModeInit(ScreenPtr pScreen);
} /* XF86VIDMODE */


