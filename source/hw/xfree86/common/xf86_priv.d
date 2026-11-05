module xf86_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import os.osdep;
public import hw.xfree86.common.xf86Helper;
public import xf86Configure;
public import xf86Globals;
import hw.xfree86.modes.displaymode;

// Bool xf86DoConfigure;
// Bool xf86DoConfigurePass1;
// Bool xf86ProbeIgnorePrimary;

/*
 * Parameters set ONLY from the command line options
 * The global state of these things is held in xf86InfoRec (when appropriate).
 */
/* globals.c */
// Bool xf86AllowMouseOpenFail;
// Bool xf86AutoBindGPUDisabled;
// Bool xf86VidModeDisabled;
// Bool xf86VidModeAllowNonLocal;
// Bool xf86fpFlag;
// Bool xf86bsEnableFlag;
// Bool xf86bsDisableFlag;
// Bool xf86silkenMouseDisableFlag;
// Bool xf86xkbdirFlag;
// Bool xf86acpiDisableFlag;

// char* xf86LayoutName;
// char* xf86ScreenName;
// char* xf86PointerName;
// char* xf86KeyboardName;

// rgb xf86Weight;

// Bool  xf86FlipPixels;

// Gamma xf86Gamma;

// const(char)* xf86ModulePath;
// MessageType xf86ModPathFrom;

// const(char)* xf86LogFile;
// MessageType xf86LogFileFrom;
// Bool xf86LogFileWasOpened;
// int xf86Verbose;       /* verbosity level */
// int xf86LogVerbose;    /* log file verbosity level */

// int xf86NumDrivers;
// Bool xf86Resetting;
// Bool xf86Initialising;
// const(char)*[1] xf86VisualNames;

/* xf86Cursor.c */
// void xf86LockZoom(ScreenPtr pScreen, int lock);
// void xf86InitViewport(ScrnInfoPtr pScr);
// void xf86ZoomViewport(ScreenPtr pScreen, int zoom);
// void xf86InitOrigins();

/* xf86Events.c */
// InputHandlerProc xf86SetConsoleHandler(InputHandlerProc handler, void* data);
// Bool xf86VTOwner();
// void xf86VTEnter();
// void xf86VTLeave();
// void xf86EnableInputDeviceForVTSwitch(InputInfoPtr pInfo);
// void xf86Wakeup(void* blockData, int err);
// void xf86HandlePMEvents(int fd, void* data);

// int function(int fd, pmEvent* events, int num) xf86PMGetEventFromOs;
// pmWait function(int fd, pmEvent event) xf86PMConfirmEventToOs;

/* xf86Helper.c */
// void xf86DeleteDriver(int drvIndex);
// void xf86DeleteScreen(ScrnInfoPtr pScrn);
// void xf86LogInit();
// void xf86CloseLog(ExitCode error);

/* xf86Init.c */
Bool xf86LoadModules(const(char)** list, void** optlist);
// Bool xf86HasTTYs();

/* xf86Mode.c */
// const(void )* xf86ModeStatusToString(ModeStatus status);

// ModeStatus xf86CheckModeForDriver(ScrnInfoPtr scrp, DisplayModePtr mode, int flags);

/* xf86DefaultModes (auto-generated) */
// const(DisplayModeRec)[1] xf86DefaultModes;
// const(int) xf86NumDefaultModes;
const DisplayModeRec[1] xf86DefaultModes = [
    DisplayModeRec(
        null, null, null,
        MODE_OK, M_T_DEFAULT,

        0,      // Clock
        1280,   // HDisplay
        1281,   // HSyncStart
        1282,   // HSyncEnd
        1602,   // HTotal
        0,      // HSkew

        800,    // VDisplay
        801,    // VSyncStart
        802,    // VSyncEnd
        803,    // VTotal
        0,      // VScan
        0,      // Flags

        -1,     // ClockIndex
        0,      // SynthClock
        0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0,
        false, false,
        0,
        null,
        0,

        0.0,    // HSync
        60.0    // VRefresh
    )
];

const int xf86NumDefaultModes = xf86DefaultModes.length;

/* xf86RandR.c */
Bool xf86RandRInit(ScreenPtr pScreen);

/* xf86Extensions.c */
// void xf86ExtensionInit();

/* xf86Configure.c */
// void DoConfigure(); 
// void DoShowOptions(); 

 /* _XSERVER_XF86_PRIV_H */
