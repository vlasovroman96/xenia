module include.xf86;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

/*
 * This file contains declarations for public XFree86 functions and variables,
 * and definitions of public macros.
 *
 * "public" means available to video drivers.
 */

import build.xlibre_server;

public import include.xlibre_ptrtypes;
public import include.xf86str;
public import include.xf86Opt;
public import core.stdc.stdarg;
//public import externs.X11.extensions._randr;
import include.xf86Xinput;
import os.log;
import xf86Globals;
// import dix.events;
// import xf86Configure;

// import os.inputthread;

/* General parameters */
// bool  xorgHWAccess;

// DevPrivateKeyRec xf86ScreenKeyRec;

enum xf86ScreenKey = (&xf86ScreenKeyRec);

// ScrnInfoPtr *xf86Screens;      /* List of pointers to ScrnInfoRecs */
// ubyte[256] byte_reversed;

enum string XF86SCRNINFO(string p) = `xf86ScreenToScrn(` ~ p ~ `)`;

/* Compatibility functions for pre-input-thread drivers */
pragma(inline, true) private int xf86BlockSIGIO() { input_lock(); return 0; }
pragma(inline, true) private void xf86UnblockSIGIO(int wasset) { input_unlock(); }
/* PCI related */
static if(XSERVER_LIBPCIACCESS){
public import externs.pciaccess;
void  xf86CheckPciSlot(const(pci_device)*);
void  xf86ClaimPciSlot(pci_device*, DriverPtr drvp, int chipset, GDevPtr dev, Bool active);
void  xf86UnclaimPciSlot(pci_device*, GDevPtr dev);
void  xf86ParsePciBusString(const(char)* busID, int* bus, int* device, int* func);
void  xf86IsPrimaryPci(pci_device* pPci);
void  xf86CheckPciMemBase(pci_device* pPci, memType base);
// pci_device* xf86GetPciInfoForEntity(int entityIndex);
void  xf86MatchPciInstances(const(char)* driverName, int vendorID, SymTabPtr chipsets, PciChipsets* PCIchipsets, GDevPtr* devList, int numDevs, DriverPtr drvp, int** foundEntities);
// void  xf86ConfigPciEntity(ScrnInfoPtr pScrn, int scrnFlag, int entityIndex, PciChipsets* p_chip, void* dummy, EntityProc init, EntityProc enter, EntityProc leave, void* private_);
}

/* xf86Bus.c */

// void  xf86ClaimFbSlot(DriverPtr drvp, int chipset, GDevPtr dev, Bool active);
void  xf86ClaimNoSlot(DriverPtr drvp, int chipset, GDevPtr dev, Bool active);
// void  xf86AddEntityToScreen(ScrnInfoPtr pScrn, int entityIndex);
// void  xf86SetEntityInstanceForScreen(ScrnInfoPtr pScrn, int entityIndex, int instance);
// void  xf86GetNumEntityInstances(int entityIndex);
// void  xf86GetDevFromEntity(int entityIndex, int instance);
// void  xf86GetEntityInfo(int entityIndex);

enum string xf86SetLastScrnFlag(string e, string s) = `do { } while (0)`;

// void  xf86IsEntityShared(int entityIndex);
// void  xf86SetEntityShared(int entityIndex);
// void  xf86IsEntitySharable(int entityIndex);
// void  xf86SetEntitySharable(int entityIndex);
// void  xf86IsPrimInitDone(int entityIndex);
// void  xf86SetPrimInitDone(int entityIndex);
void  xf86ClearPrimInitDone(int entityIndex);
// void  xf86AllocateEntityPrivateIndex();
// void * xf86GetEntityPrivate(int entityIndex, int privIndex);

/* xf86Configure.c */
// void  xf86AddBusDeviceToConfigure(const(char)* driver, BusType bus, void* busData, int chipset);

/* xf86Cursor.c */

// void  xf86SetViewport(ScreenPtr pScreen, int x, int y);
// void  xf86SwitchMode(ScreenPtr pScreen, DisplayModePtr mode);
// void * xf86GetPointerScreenFuncs();
// void  xf86ReconfigureLayout();

/* xf86DPMS.c */

void  xf86DPMSInit(ScreenPtr pScreen, DPMSSetProcPtr set, int flags);

/* xf86DGA.c */

static if(XFreeXDGA){
// void  DGAInit(ScreenPtr pScreen, DGAFunctionPtr funcs, DGAModePtr modes, int num);
// void  DGAReInitModes(ScreenPtr pScreen, DGAModePtr modes, int num);
xf86SetDGAModeProc xf86SetDGAMode;
}

/* xf86Events.c */

alias InputInfoPtr = _InputInfoRec*;

void  SetTimeSinceLastInputEvent();
// void * xf86AddGeneralHandler(int fd, InputHandlerProc proc, void* data);
// void  xf86RemoveGeneralHandler(void* handler);

/* xf86Helper.c */

// void  xf86AddDriver(DriverPtr driver, void* module_, int flags);
// void  xf86AllocateScreen(DriverPtr drv, int flags);
// void  xf86AllocateScrnInfoPrivateIndex();
// void  xf86SetDepthBpp(ScrnInfoPtr scrp, int depth, int bpp, int fbbpp, int depth24flags);
// void  xf86PrintDepthBpp(ScrnInfoPtr scrp);
// void  xf86SetWeight(ScrnInfoPtr scrp, rgb weight, rgb mask);
// void  xf86SetDefaultVisual(ScrnInfoPtr scrp, int visual);
// void  xf86SetGamma(ScrnInfoPtr scrp, Gamma newGamma);
// void  xf86SetDpi(ScrnInfoPtr pScrn, int x, int y);
// void  xf86SetBlackWhitePixels(ScreenPtr pScreen);
// void  xf86EnableDisableFBAccess(ScrnInfoPtr pScrn, Bool enable);
// void  xf86VDrvMsgVerb(int scrnIndex, MessageType type, int verb, const(char)* format, va_list args);
// void  xf86DrvMsgVerb(int scrnIndex, MessageType type, int verb, const(char)* format, ...);
void  _X_ATTRIBUTE_PRINTF();
void  _X_ATTRIBUTE_PRINTF();
void  _X_ATTRIBUTE_PRINTF();
const(void )* xf86TokenToString(SymTabPtr table, int token);
void  xf86StringToToken(SymTabPtr table, const(char)* string);
void  xf86ShowClocks(ScrnInfoPtr scrp, MessageType from);
// void  xf86PrintChipsets(const(char)* drvname, const(char)* drvmsg, SymTabPtr chips);
// void  xf86MatchDevice(const(char)* drivername, GDevPtr** driversectlist);
const(void )* xf86GetVisualName(int visual);
void  xf86GetVerbosity();
void  xf86GetGamma();
void  xf86ServerIsExiting();
void  xf86ServerIsOnlyDetecting();
void  xf86GetAllowMouseOpenFail();
void  xorgGetVersion();
void  xf86GetModuleVersion(void* module_);
void * xf86LoadDrvSubModule(DriverPtr drv, const(char)* name);
// void * xf86LoadSubModule(ScrnInfoPtr pScrn, const(char)* name);
// void * xf86LoadOneModule(const(char)* name, void* optlist);
void  xf86UnloadSubModule(void* mod);
// void  xf86LoaderCheckSymbol(const(char)* name);
// void  xf86SetBackingStore(ScreenPtr pScreen);
// void  xf86SetSilkenMouse(ScreenPtr pScreen);
// void  xf86ConfigFbEntity(ScrnInfoPtr pScrn, int scrnFlag, int entityIndex, EntityProc init, EntityProc enter, EntityProc leave, void* private_);

// void  xf86IsUnblank(int mode);

/* xf86Init.c */

// void  xf86GetPixFormat(ScrnInfoPtr pScrn, int depth);
void  xf86GetBppFromDepth(ScrnInfoPtr pScrn, int depth);

/* xf86Mode.c */

// void  xf86CheckModeForMonitor(DisplayModePtr mode, MonPtr monitor);
void  xf86ValidateModes(ScrnInfoPtr scrp, DisplayModePtr availModes, const(char)** modeNames, ClockRangePtr clockRanges, int* linePitches, int minPitch, int maxPitch, int minHeight, int maxHeight, int pitchInc, int virtualX, int virtualY, int apertureSize, LookupModeFlags strategy);
// void  xf86DeleteMode(DisplayModePtr* modeList, DisplayModePtr mode);
void  xf86PruneDriverModes(ScrnInfoPtr scrp);
// void  xf86SetCrtcForModes(ScrnInfoPtr scrp, int adjustFlags);
void  xf86PrintModes(ScrnInfoPtr scrp);

/* xf86Option.c */

// void  xf86CollectOptions(ScrnInfoPtr pScrn, XF86OptionPtr extraOpts);

/* convert ScreenPtr to ScrnInfoPtr */
// void  xf86ScreenToScrn(ScreenPtr pScreen);
/* convert ScrnInfoPtr to ScreenPtr */
// void  xf86ScrnToScreen(ScrnInfoPtr pScrn);

enum XF86_HAS_SCRN_CONV = 1 /* define for drivers to use in api compat */;

enum XF86_SCRN_INTERFACE = 1 /* define for drivers to use in api compat */;

/* flags passed to xf86 allocate screen */
enum XF86_ALLOCATE_GPU_SCREEN = 1;

/* only for backwards (source) compatibility */
alias xf86MsgVerb = LogMessageVerb;
enum string xf86Msg(string type, string arg) = `LogMessageVerb(` ~ type ~ `, 1, `~arg~`)`;

/*
 * retrieve file descriptor to opened console device.
 * only for some legacy keyboard drivers (xf86-input-keyboard)
 */
int xf86GetConsoleFd();

                          /* _XF86_H */
