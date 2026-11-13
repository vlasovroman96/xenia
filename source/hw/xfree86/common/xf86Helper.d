module hw.xfree86.common.xf86Helper;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
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
 * Authors: Dirk Hohndel <hohndel@XFree86.Org>
 *          David Dawes <dawes@XFree86.Org>
 *          ... and others
 *
 * This file includes the helper functions that the server provides for
 * different drivers.
 */
import build.xlibre_server;

import core.sys.posix.sys.stat;
import core.sys.posix.unistd;
import composite.compext;

//import x11.X;

import dix.dix_priv;
import dix.input_priv;
import ddc;
import mi.mi_priv;
import os.log_priv;
import os.osdep;
import xf86Mode;

import os.os;
import common.servermd;
import dix.pixmap;
import dix.property;
import dix.gc;
import hw.xfree86.loader.loaderProcs;
import xf86_priv;
import hw.xfree86.common.xf86Priv;
import hw.xfree86.os_support.xf86_OSlib;
import mi.micmap;
import xf86Bus;
import hw.xfree86.common.xf86Xinput;
// import xf86InPriv;
// import xf86Config;
import xf86Module_priv;
import xf86Globals;
import hw.xfree86.common.xf86Option;
import hw.xfree86.parser.Flags;
import os.log;
import externs.strings;
import std.conv;
import externs.gnu;
import x11.Xosdefs;
import xf86Init;
import hw.xfree86.common.edid;
import dix.window;

public import common.xlibre_ptrtypes;
public import hw.xfree86.common.xf86str;
public import xf86Opt_priv;
public import core.stdc.stdarg;
import hw.xfree86.modes.displaymode;
//public import externs.X11.extensions._randr;
import os.log;
import xf86Globals;
import common.math;
// import dix.events;
// import xf86Configure;

// import os.inputthread;

/* General parameters */
// bool  xorgHWAccess;

// DevPrivateKeyRec xf86ScreenKeyRec;
enum GPU_SCREEN_OFFSET = 256;

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

/* For xf86GetClocks */
static if (CSRG_BASED || HasVersion!"__GNU__") {
version = HAS_SETPRIORITY;
import core.sys.posix.sys.resource;
}

private int xf86ScrnInfoPrivateCount = 0;

/* Add a pointer to a new DriverRec to xf86DriverList */

void xf86AddDriver(DriverPtr driver, void* module_, int flags)
{
    /* Don't add null entries */
    if (!driver)
        return;

    if (xf86DriverList is null)
        xf86NumDrivers = 0;

    xf86NumDrivers++;
    xf86DriverList = cast(DriverPtr*)XNFreallocarray(xf86DriverList,
                                     xf86NumDrivers, DriverPtr.sizeof);
    xf86DriverList[xf86NumDrivers - 1] = cast(DriverPtr)XNFalloc(DriverRec.sizeof);
    *xf86DriverList[xf86NumDrivers - 1] = *driver;
    xf86DriverList[xf86NumDrivers - 1].module_ = module_;
    xf86DriverList[xf86NumDrivers - 1].refCount = 0;
}

void xf86DeleteDriver(int drvIndex)
{
    if (xf86DriverList[drvIndex]
        && (!xf86DriverHasEntities(xf86DriverList[drvIndex]))) {
        if (xf86DriverList[drvIndex].module_)
            UnloadModule(cast(module_desc*)xf86DriverList[drvIndex].module_);
        free(xf86DriverList[drvIndex]);
        xf86DriverList[drvIndex] = null;
    }
}

/* Add a pointer to a new InputDriverRec to xf86InputDriverList */

void xf86AddInputDriver(InputDriverPtr driver, void* module_, int flags)
{
    /* Don't add null entries */
    if (!driver)
        return;

    if (xf86InputDriverList is null)
        xf86NumInputDrivers = 0;

    xf86NumInputDrivers++;
    xf86InputDriverList = cast(InputDriverPtr*)XNFreallocarray(xf86InputDriverList,
                                          xf86NumInputDrivers,
                                          InputDriverPtr.sizeof);
    xf86InputDriverList[xf86NumInputDrivers - 1] =
        cast(InputDriverRec*)XNFalloc(InputDriverRec.sizeof);
    *xf86InputDriverList[xf86NumInputDrivers - 1] = *driver;
    xf86InputDriverList[xf86NumInputDrivers - 1].module_ = module_;
}

InputDriverPtr xf86LookupInputDriver(const(char)* name)
{
    int i = void;

    for (i = 0; i < xf86NumInputDrivers; i++) {
        if (xf86InputDriverList[i] && xf86InputDriverList[i].driverName &&
            xf86NameCmp(name, xf86InputDriverList[i].driverName) == 0)
            return xf86InputDriverList[i];
    }
    return null;
}

InputInfoPtr xf86LookupInput(const(char)* name)
{
    InputInfoPtr p = void;

    for (p = xf86InputDevs; p !is null; p = p.next) {
        if (strcmp(name, p.name) == 0)
            return p;
    }

    return null;
}

/* Allocate a new ScrnInfoRec in xf86Screens */

ScrnInfoPtr xf86AllocateScreen(DriverPtr drv, int flags)
{
    int i = void;
    ScrnInfoPtr pScrn = void;

    if (flags & XF86_ALLOCATE_GPU_SCREEN) {
        if (xf86GPUScreens is null)
            xf86NumGPUScreens = 0;
        i = xf86NumGPUScreens++;
        xf86GPUScreens = cast(ScrnInfoPtr*)XNFreallocarray(xf86GPUScreens, xf86NumGPUScreens,
                                         ScrnInfoPtr.sizeof);
        xf86GPUScreens[i] = cast(ScrnInfoPtr)XNFcallocarray(1, ScrnInfoRec.sizeof);
        pScrn = xf86GPUScreens[i];
        pScrn.scrnIndex = i + GPU_SCREEN_OFFSET;      /* Changes when a screen is removed */
        pScrn.is_gpu = True;
    } else {
        if (xf86Screens is null)
            xf86NumScreens = 0;

        i = xf86NumScreens++;
        xf86Screens = cast(ScrnInfoPtr*)XNFreallocarray(xf86Screens, xf86NumScreens,
                                      ScrnInfoPtr.sizeof);
        xf86Screens[i] = cast(ScrnInfoPtr)XNFcallocarray(1, ScrnInfoRec.sizeof);
        pScrn = xf86Screens[i];

        pScrn.scrnIndex = i;      /* Changes when a screen is removed */
    }

    pScrn.origIndex = pScrn.scrnIndex;      /* This never changes */
    pScrn.privates = cast(DevUnion*)XNFcallocarray(xf86ScrnInfoPrivateCount, DevUnion.sizeof);
    /*
     * EnableDisableFBAccess now gets initialized in InitOutput()
     * pScrn->EnableDisableFBAccess = xf86EnableDisableFBAccess;
     */

    pScrn.drv = drv;
    drv.refCount++;
    pScrn.module_ = DuplicateModule(cast(module_desc*)drv.module_, null);

    pScrn.DriverFunc = drv.driverFunc;

    return pScrn;
}

/*
 * Remove an entry from xf86Screens.  Ideally it should free all allocated
 * data.  To do this properly may require a driver hook.
 */

void xf86DeleteScreen(ScrnInfoPtr pScrn)
{
    int i = void;
    int scrnIndex = void;
    Bool is_gpu = False;

    if (!pScrn)
        return;

    if (pScrn.is_gpu) {
        /* First check if the screen is valid */
        if (xf86NumGPUScreens == 0 || xf86GPUScreens is null)
            return;
        is_gpu = True;
    } else {
        /* First check if the screen is valid */
        if (xf86NumScreens == 0 || xf86Screens is null)
            return;
    }

    scrnIndex = pScrn.scrnIndex;
    /* If a FreeScreen function is defined, call it here */
    if (pScrn.FreeScreen !is null)
        pScrn.FreeScreen(pScrn);

    while (pScrn.modes)
        xf86DeleteMode(&pScrn.modes, pScrn.modes);

    while (pScrn.modePool)
        xf86DeleteMode(&pScrn.modePool, pScrn.modePool);

    xf86OptionListFree(cast(_InputOption*)pScrn.options);

    if (pScrn.module_)
        UnloadModule(cast(module_desc*)pScrn.module_);

    if (pScrn.drv)
        pScrn.drv.refCount--;

    free(pScrn.privates);

    xf86ClearEntityListForScreen(pScrn);

    free(pScrn);

    /* Move the other entries down, updating their scrnIndex fields */

    if (is_gpu) {
        xf86NumGPUScreens--;
        scrnIndex -= GPU_SCREEN_OFFSET;
        for (i = scrnIndex; i < xf86NumGPUScreens; i++) {
            xf86GPUScreens[i] = xf86GPUScreens[i + 1];
            xf86GPUScreens[i].scrnIndex = i + GPU_SCREEN_OFFSET;
            /* Also need to take care of the screen layout settings */
        }
    }
    else {
        xf86NumScreens--;

        for (i = scrnIndex; i < xf86NumScreens; i++) {
            xf86Screens[i] = xf86Screens[i + 1];
            xf86Screens[i].scrnIndex = i;
            /* Also need to take care of the screen layout settings */
        }
    }
}

/*
 * Allocate a private in ScrnInfoRec.
 */

int xf86AllocateScrnInfoPrivateIndex()
{
    int idx = void, i = void;
    ScrnInfoPtr pScr = void;
    DevUnion* nprivs = void;

    idx = xf86ScrnInfoPrivateCount++;
    for (i = 0; i < xf86NumScreens; i++) {
        pScr = xf86Screens[i];
        nprivs = cast(DevUnion*)XNFreallocarray(pScr.privates,
                                 xf86ScrnInfoPrivateCount, DevUnion.sizeof);
        /* Zero the new private */
        memset(&nprivs[idx], 0, DevUnion.sizeof);
        pScr.privates = nprivs;
    }
    for (i = 0; i < xf86NumGPUScreens; i++) {
        pScr = xf86GPUScreens[i];
        nprivs = cast(DevUnion*)XNFreallocarray(pScr.privates,
                                 xf86ScrnInfoPrivateCount, DevUnion.sizeof);
        /* Zero the new private */
        memset(&nprivs[idx], 0, DevUnion.sizeof);
        pScr.privates = nprivs;
    }
    return idx;
}

private Bool xf86AddPixFormat(ScrnInfoPtr pScrn, int depth, int bpp, int pad)
{
    int i = void;

    if (pScrn.numFormats >= MAXFORMATS)
        return False;

    if (bpp <= 0) {
        if (depth == 1)
            bpp = 1;
        else if (depth <= 8)
            bpp = 8;
        else if (depth <= 16)
            bpp = 16;
        else if (depth <= 32)
            bpp = 32;
        else
            return False;
    }
    if (pad <= 0)
        pad = BITMAP_SCANLINE_PAD;

    i = pScrn.numFormats++;
    pScrn.formats[i].depth = cast(ubyte)depth;
    pScrn.formats[i].bitsPerPixel = cast(ubyte)bpp;
    pScrn.formats[i].scanlinePad = cast(ubyte)pad;
    return True;
}

/*
 * Set the depth we are using based on (in the following order of preference):
 *  - values given on the command line
 *  - values given in the config file
 *  - values provided by the driver
 *  - an overall default when nothing else is given
 *
 * Also find a Display subsection matching the depth/bpp found.
 *
 * Sets the following ScrnInfoRec fields:
 *     bitsPerPixel, depth, display, imageByteOrder,
 *     bitmapScanlinePad, bitmapScanlineUnit, bitmapBitOrder, numFormats,
 *     formats, fbFormat.
 */

/* Can the screen handle 32 bpp pixmaps */
enum string DO_PIX32(string f) = `((` ~ f ~ ` & Support32bppFb) || 
		     ((` ~ f ~ ` & Support24bppFb) && (` ~ f ~ ` & SupportConvert32to24)))`;

enum GLOBAL_DEFAULT_DEPTH = 24;


Bool xf86SetDepthBpp(ScrnInfoPtr scrp, int depth, int dummy, int fbbpp, int depth24flags)
{
    int i = void;
    DispPtr disp = void;

    scrp.bitsPerPixel = -1;
    scrp.depth = -1;
    scrp.bitsPerPixelFrom = X_DEFAULT;
    scrp.depthFrom = X_DEFAULT;

    if (xf86FbBpp > 0) {
        if (xf86FbBpp == 24) /* lol no */
            xf86FbBpp = 32;
        scrp.bitsPerPixel = xf86FbBpp;
        scrp.bitsPerPixelFrom = X_CMDLINE;
    }

    if (xf86Depth > 0) {
        scrp.depth = xf86Depth;
        scrp.depthFrom = X_CMDLINE;
    }

    if (xf86FbBpp < 0 && xf86Depth < 0) {
        if (scrp.confScreen.defaultfbbpp > 0) {
            scrp.bitsPerPixel = scrp.confScreen.defaultfbbpp;
            scrp.bitsPerPixelFrom = X_CONFIG;
        }
        if (scrp.confScreen.defaultdepth > 0) {
            scrp.depth = scrp.confScreen.defaultdepth;
            scrp.depthFrom = X_CONFIG;
        }

        if (scrp.confScreen.defaultfbbpp <= 0 &&
            scrp.confScreen.defaultdepth <= 0) {
            /*
             * Check for DefaultDepth and DefaultFbBpp options in the
             * Device sections.
             */
            GDevPtr device = void;
            Bool found = False;

            for (i = 0; i < scrp.numEntities; i++) {
                device = xf86GetDevFromEntity(scrp.entityList[i],
                                              scrp.entityInstanceList[i]);
                if (device && device.options) {
                    if (xf86FindOption(cast(_InputOption*)device.options, "DefaultDepth")) {
                        scrp.depth = xf86SetIntOption(cast(_InputOption*)device.options,
                                                       "DefaultDepth", -1);
                        scrp.depthFrom = X_CONFIG;
                        found = True;
                    }
                    if (xf86FindOption(cast(_InputOption*)device.options, "DefaultFbBpp")) {
                        scrp.bitsPerPixel = xf86SetIntOption(cast(_InputOption*)device.options,
                                                              "DefaultFbBpp",
                                                              -1);
                        scrp.bitsPerPixelFrom = X_CONFIG;
                        found = True;
                    }
                }
                if (found)
                    break;
            }
        }
    }

    /* If none of these is set, pick a default */
    if (scrp.bitsPerPixel < 0 && scrp.depth < 0) {
        if (fbbpp > 0 || depth > 0) {
            if (fbbpp > 0)
                scrp.bitsPerPixel = fbbpp;
            if (depth > 0)
                scrp.depth = depth;
        }
        else {
            scrp.depth = GLOBAL_DEFAULT_DEPTH;
        }
    }

    /* If any are not given, determine a default for the others */

    if (scrp.bitsPerPixel < 0) {
        /* The depth must be set */
        if (scrp.depth > -1) {
            if (scrp.depth == 1)
                scrp.bitsPerPixel = 1;
            else if (scrp.depth <= 4)
                scrp.bitsPerPixel = 4;
            else if (scrp.depth <= 8)
                scrp.bitsPerPixel = 8;
            else if (scrp.depth <= 16)
                scrp.bitsPerPixel = 16;
            else if (scrp.depth <= 24 && mixin(DO_PIX32!(`depth24flags`))) {
                scrp.bitsPerPixel = 32;
            }
            else if (scrp.depth <= 32)
                scrp.bitsPerPixel = 32;
            else {
                xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                           "No bpp for depth (%d)\n", scrp.depth);
                return False;
            }
        }
        else {
            xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                       "xf86SetDepthBpp: internal error: depth and fbbpp"
                       ~ " are both not set\n");
            return False;
        }
        if (scrp.bitsPerPixel < 0) {
            if ((depth24flags & (Support24bppFb | Support32bppFb)) ==
                     NoDepth24Support)
                xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                           "Driver can't support depth 24\n");
            else
                xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                           "Can't find fbbpp for depth 24\n");
            return False;
        }
        scrp.bitsPerPixelFrom = X_PROBED;
    }

    if (scrp.depth <= 0) {
        /* bitsPerPixel is already set */
        switch (scrp.bitsPerPixel) {
        case 32:
            scrp.depth = 24;
            break;
        default:
            /* 1, 4, 8, 16 and 24 */
            scrp.depth = scrp.bitsPerPixel;
            break;
        }
        scrp.depthFrom = X_PROBED;
    }

    /* Sanity checks */
    if (scrp.depth < 1 || scrp.depth > 32) {
        xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                   "Specified depth (%d) is not in the range 1-32\n",
                   scrp.depth);
        return False;
    }
    switch (scrp.bitsPerPixel) {
    case 1:
    case 4:
    case 8:
    case 16:
    case 32:
        break;
    default:
        xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                   "Specified fbbpp (%d) is not a permitted value\n",
                   scrp.bitsPerPixel);
        return False;
    }
    if (scrp.depth > scrp.bitsPerPixel) {
        xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                   "Specified depth (%d) is greater than the fbbpp (%d)\n",
                   scrp.depth, scrp.bitsPerPixel);
        return False;
    }

    /*
     * Find the Display subsection matching the depth/fbbpp and initialise
     * scrp->display with it.
     */
    for (i = 0; i < scrp.confScreen.numdisplays; i++) {
        disp = scrp.confScreen.displays[i];
        if ((disp.depth == scrp.depth && disp.fbbpp == scrp.bitsPerPixel)
            || (disp.depth == scrp.depth && disp.fbbpp <= 0)
            || (disp.fbbpp == scrp.bitsPerPixel && disp.depth <= 0)) {
            scrp.display = disp;
            break;
        }
    }

    /*
     * If an exact match can't be found, see if there is one with no
     * depth or fbbpp specified.
     */
    if (i == scrp.confScreen.numdisplays) {
        for (i = 0; i < scrp.confScreen.numdisplays; i++) {
            disp = scrp.confScreen.displays[i];
            if (disp.depth <= 0 && disp.fbbpp <= 0) {
                scrp.display = disp;
                break;
            }
        }
    }

    /*
     * If all else fails, create a default one.
     */
    if (i == scrp.confScreen.numdisplays) {
        scrp.confScreen.numdisplays++;
        scrp.confScreen.displays =
            cast(DispPtr*)XNFreallocarray(scrp.confScreen.displays,
                            scrp.confScreen.numdisplays, DispPtr.sizeof);
        xf86DrvMsg(scrp.scrnIndex, X_INFO,
                   "Creating default Display subsection in Screen section\n"
                   ~ "\t\"%s\" for depth/fbbpp %d/%d\n",
                   scrp.confScreen.id, scrp.depth, scrp.bitsPerPixel);
        scrp.confScreen.displays[i] = cast(DispPtr)XNFcallocarray(1, DispRec.sizeof);
        memset(scrp.confScreen.displays[i], 0, DispRec.sizeof);
        scrp.confScreen.displays[i].blackColour.red = -1;
        scrp.confScreen.displays[i].blackColour.green = -1;
        scrp.confScreen.displays[i].blackColour.blue = -1;
        scrp.confScreen.displays[i].whiteColour.red = -1;
        scrp.confScreen.displays[i].whiteColour.green = -1;
        scrp.confScreen.displays[i].whiteColour.blue = -1;
        scrp.confScreen.displays[i].defaultVisual = -1;
        scrp.confScreen.displays[i].modes = cast(const(char)**)XNFalloc((char*).sizeof);
        scrp.confScreen.displays[i].modes[0] = null;
        scrp.confScreen.displays[i].depth = depth;
        scrp.confScreen.displays[i].fbbpp = fbbpp;
        scrp.display = scrp.confScreen.displays[i];
    }

    /*
     * Setup defaults for the display-wide attributes the framebuffer will
     * need.  These defaults should eventually be set globally, and not
     * dependent on the screens.
     */
    scrp.imageByteOrder = IMAGE_BYTE_ORDER;
    scrp.bitmapScanlinePad = BITMAP_SCANLINE_PAD;
    if (scrp.depth < 8) {
        /* Planar modes need these settings */
        scrp.bitmapScanlineUnit = 8;
        scrp.bitmapBitOrder = MSBFirst;
    }
    else {
        scrp.bitmapScanlineUnit = BITMAP_SCANLINE_UNIT;
        scrp.bitmapBitOrder = BITMAP_BIT_ORDER;
    }

    /*
     * If an unusual depth is required, add it to scrp->formats.  The formats
     * for the common depths are handled globally in InitOutput
     */
    switch (scrp.depth) {
    case 1:
    case 4:
    case 8:
    case 15:
    case 16:
    case 24:
        /* Common depths.  Nothing to do for them */
        break;
    default:
        if (!xf86AddPixFormat(scrp, scrp.depth, 0, 0)) {
            xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                       "Can't add pixmap format for depth %d\n", scrp.depth);
            return False;
        }
    }

    /* Initialise the framebuffer format for this screen */
    scrp.fbFormat.depth = cast(ubyte)scrp.depth;
    scrp.fbFormat.bitsPerPixel = cast(ubyte)scrp.bitsPerPixel;
    scrp.fbFormat.scanlinePad = cast(ubyte)BITMAP_SCANLINE_PAD;

    return True;
}

/*
 * Print out the selected depth and bpp.
 */
void xf86PrintDepthBpp(ScrnInfoPtr scrp)
{
    xf86DrvMsg(scrp.scrnIndex, scrp.depthFrom, "Depth %d, ", scrp.depth);
    LogMessageVerb(scrp.bitsPerPixelFrom, 1, "framebuffer bpp %d\n", scrp.bitsPerPixel);
}

/*
 * xf86SetWeight sets scrp->weight, scrp->mask, scrp->offset, and for depths
 * greater than MAX_PSEUDO_DEPTH also scrp->rgbBits.
 */
Bool xf86SetWeight(ScrnInfoPtr scrp, rgb weight, rgb mask)
{
    MessageType weightFrom = X_DEFAULT;

    scrp.weight.red = 0;
    scrp.weight.green = 0;
    scrp.weight.blue = 0;

    if (xf86Weight.red > 0 && xf86Weight.green > 0 && xf86Weight.blue > 0) {
        scrp.weight = xf86Weight;
        weightFrom = X_CMDLINE;
    }
    else if (scrp.display.weight.red > 0 && scrp.display.weight.green > 0
             && scrp.display.weight.blue > 0) {
        scrp.weight = scrp.display.weight;
        weightFrom = X_CONFIG;
    }
    else if (weight.red > 0 && weight.green > 0 && weight.blue > 0) {
        scrp.weight = weight;
    }
    else {
        switch (scrp.depth) {
        case 1:
        case 4:
        case 8:
            scrp.weight.red = scrp.weight.green =
                scrp.weight.blue = scrp.rgbBits;
            break;
        case 15:
            scrp.weight.red = scrp.weight.green = scrp.weight.blue = 5;
            break;
        case 16:
            scrp.weight.red = scrp.weight.blue = 5;
            scrp.weight.green = 6;
            break;
        case 18:
            scrp.weight.red = scrp.weight.green = scrp.weight.blue = 6;
            break;
        case 24:
            scrp.weight.red = scrp.weight.green = scrp.weight.blue = 8;
            break;
        case 30:
            scrp.weight.red = scrp.weight.green = scrp.weight.blue = 10;
            break;
        default: break;}
    }

    if (scrp.weight.red)
        xf86DrvMsg(scrp.scrnIndex, weightFrom, "RGB weight %d%d%d\n",
                   cast(int) scrp.weight.red, cast(int) scrp.weight.green,
                   cast(int) scrp.weight.blue);

    if (scrp.depth > MAX_PSEUDO_DEPTH &&
        (scrp.depth != scrp.weight.red + scrp.weight.green +
         scrp.weight.blue)) {
        xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                   "Weight given (%d%d%d) is inconsistent with the "
                   ~ "depth (%d)\n",
                   cast(int) scrp.weight.red, cast(int) scrp.weight.green,
                   cast(int) scrp.weight.blue, scrp.depth);
        return False;
    }
    if (scrp.depth > MAX_PSEUDO_DEPTH && scrp.weight.red) {
        /*
         * XXX Does this even mean anything for TrueColor visuals?
         * If not, we shouldn't even be setting it here.  However, this
         * matches the behaviour of 3.x versions of XFree86.
         */
        scrp.rgbBits = cast(int)scrp.weight.red;
        if (scrp.weight.green > scrp.rgbBits)
            scrp.rgbBits = cast(int)scrp.weight.green;
        if (scrp.weight.blue > scrp.rgbBits)
            scrp.rgbBits = cast(int)scrp.weight.blue;
    }

    /* Set the mask and offsets */
    if (mask.red == 0 || mask.green == 0 || mask.blue == 0) {
        /* Default to a setting common to PC hardware */
        scrp.offset.red = scrp.weight.green + scrp.weight.blue;
        scrp.offset.green = scrp.weight.blue;
        scrp.offset.blue = 0;
        scrp.mask.red = ((1 << scrp.weight.red) - 1) << scrp.offset.red;
        scrp.mask.green = ((1 << scrp.weight.green) - 1)
            << scrp.offset.green;
        scrp.mask.blue = (1 << scrp.weight.blue) - 1;
    }
    else {
        /* Initialise to the values passed */
        scrp.mask.red = mask.red;
        scrp.mask.green = mask.green;
        scrp.mask.blue = mask.blue;
        scrp.offset.red = ffs(cast(int)mask.red) - 1;
        scrp.offset.green = ffs(cast(int)mask.green) - 1;
        scrp.offset.blue = ffs(cast(int)mask.blue) - 1;
    }
    return True;
}

Bool xf86SetDefaultVisual(ScrnInfoPtr scrp, int visual)
{
    MessageType visualFrom = X_DEFAULT;

    if (defaultColorVisualClass >= 0) {
        scrp.defaultVisual = defaultColorVisualClass;
        visualFrom = X_CMDLINE;
    }
    else if (scrp.display.defaultVisual >= 0) {
        scrp.defaultVisual = scrp.display.defaultVisual;
        visualFrom = X_CONFIG;
    }
    else if (visual >= 0) {
        scrp.defaultVisual = visual;
    }
    else {
        if (scrp.depth == 1)
            scrp.defaultVisual = StaticGray;
        else if (scrp.depth == 4)
            scrp.defaultVisual = StaticColor;
        else if (scrp.depth <= MAX_PSEUDO_DEPTH)
            scrp.defaultVisual = PseudoColor;
        else
            scrp.defaultVisual = TrueColor;
    }
    switch (scrp.defaultVisual) {
    case StaticGray:
    case GrayScale:
    case StaticColor:
    case PseudoColor:
    case TrueColor:
    case DirectColor:
        xf86DrvMsg(scrp.scrnIndex, visualFrom, "Default visual is %s\n",
                   xf86VisualNames[scrp.defaultVisual]);
        return True;
    default:

        xf86DrvMsg(scrp.scrnIndex, X_ERROR,
                   "Invalid default visual class (%d)\n", scrp.defaultVisual);
        return False;
    }
}

enum string TEST_GAMMA(string g) = `
	(` ~ g ~ `).red > GAMMA_ZERO || (` ~ g ~ `).green > GAMMA_ZERO || (` ~ g ~ `).blue > GAMMA_ZERO`;

enum string SET_GAMMA(string g) = `
	(` ~ g ~ `) > GAMMA_ZERO ? (` ~ g ~ `) : 1.0`;

Bool xf86SetGamma(ScrnInfoPtr scrp, Gamma gamma)
{
    MessageType from = X_DEFAULT;

// version (none) {
    xf86MonPtr DDC = cast(xf86MonPtr) (scrp.monitor.DDC);
// }
    if (mixin(TEST_GAMMA!(`xf86Gamma`))) {
        from = X_CMDLINE;
        scrp.gamma.red = mixin(SET_GAMMA!(`xf86Gamma.red`));
        scrp.gamma.green = mixin(SET_GAMMA!(`xf86Gamma.green`));
        scrp.gamma.blue = mixin(SET_GAMMA!(`xf86Gamma.blue`));
    }
    else if (mixin(TEST_GAMMA!(`scrp.monitor.gamma`))) {
        from = X_CONFIG;
        scrp.gamma.red = mixin(SET_GAMMA!(`scrp.monitor.gamma.red`));
        scrp.gamma.green = mixin(SET_GAMMA!(`scrp.monitor.gamma.green`));
        scrp.gamma.blue = mixin(SET_GAMMA!(`scrp.monitor.gamma.blue`));
version (none) {
}    }
    else if (DDC && DDC.features.gamma > GAMMA_ZERO) {
        from = X_PROBED;
        scrp.gamma.red = mixin(SET_GAMMA!(`DDC.features.gamma`));
        scrp.gamma.green = mixin(SET_GAMMA!(`DDC.features.gamma`));
        scrp.gamma.blue = mixin(SET_GAMMA!(`DDC.features.gamma`));
        /* EDID structure version 2 gives optional separate red, green & blue
         * gamma values in bytes 0x57-0x59 */
//! #endif
    }
    else if(mixin(TEST_GAMMA!"gamma")) {
        scrp.gamma.red = mixin(SET_GAMMA!(`gamma.red`));
        scrp.gamma.green = mixin(SET_GAMMA!(`gamma.green`));
        scrp.gamma.blue = mixin(SET_GAMMA!(`gamma.blue`));
    }
    else {
        scrp.gamma.red = 1.0;
        scrp.gamma.green = 1.0;
        scrp.gamma.blue = 1.0;
    }

    xf86DrvMsg(scrp.scrnIndex, from,
               "Using gamma correction (%.1f, %.1f, %.1f)\n",
               scrp.gamma.red, scrp.gamma.green, scrp.gamma.blue);

    return True;
}

/*
 * Set the DPI from the command line option.  XXX should allow it to be
 * calculated from the widthmm/heightmm values.
 */

enum MMPERINCH = 25.4;

void xf86SetDpi(ScrnInfoPtr pScrn, int x, int y)
{
    MessageType from = X_DEFAULT;
    xf86MonPtr DDC = cast(xf86MonPtr) (pScrn.monitor.DDC);
    int ddcWidthmm = void, ddcHeightmm = void;
    int widthErr = void, heightErr = void;

    /* XXX Maybe there is no need for widthmm/heightmm in ScrnInfoRec */
    pScrn.widthmm = pScrn.monitor.widthmm;
    pScrn.heightmm = pScrn.monitor.heightmm;

    if (DDC && (DDC.features.hsize > 0 && DDC.features.vsize > 0)) {
        /* DDC gives display size in mm for individual modes,
         * but cm for monitor
         */
        ddcWidthmm = DDC.features.hsize * 10;  /* 10mm in 1cm */
        ddcHeightmm = DDC.features.vsize * 10; /* 10mm in 1cm */
    }
    else {
        ddcWidthmm = ddcHeightmm = 0;
    }

    if (monitorResolution > 0) {
        pScrn.xDpi = monitorResolution;
        pScrn.yDpi = monitorResolution;
        from = X_CMDLINE;
    }
    else if (pScrn.widthmm > 0 || pScrn.heightmm > 0) {
        from = X_CONFIG;
        if (pScrn.widthmm > 0) {
            pScrn.xDpi =
                cast(int) (cast(double) pScrn.virtualX * MMPERINCH / pScrn.widthmm);
        }
        if (pScrn.heightmm > 0) {
            pScrn.yDpi =
                cast(int) (cast(double) pScrn.virtualY * MMPERINCH / pScrn.heightmm);
        }
        if (pScrn.xDpi > 0 && pScrn.yDpi <= 0)
            pScrn.yDpi = pScrn.xDpi;
        if (pScrn.yDpi > 0 && pScrn.xDpi <= 0)
            pScrn.xDpi = pScrn.yDpi;
        xf86DrvMsg(pScrn.scrnIndex, from, "Display dimensions: (%d, %d) mm\n",
                   pScrn.widthmm, pScrn.heightmm);

        /* Warn if config and probe disagree about display size */
        if (ddcWidthmm && ddcHeightmm) {
            if (pScrn.widthmm > 0) {
                widthErr = abs(ddcWidthmm - pScrn.widthmm);
            }
            else {
                widthErr = 0;
            }
            if (pScrn.heightmm > 0) {
                heightErr = abs(ddcHeightmm - pScrn.heightmm);
            }
            else {
                heightErr = 0;
            }
            if (widthErr > 10 || heightErr > 10) {
                /* Should include config file name for monitor here */
                xf86DrvMsg(pScrn.scrnIndex, X_WARNING,
                           "Probed monitor is %dx%d mm, using Displaysize %dx%d mm\n",
                           ddcWidthmm, ddcHeightmm, pScrn.widthmm,
                           pScrn.heightmm);
            }
        }
    }
    else if (ddcWidthmm && ddcHeightmm) {
        from = X_PROBED;
        xf86DrvMsg(pScrn.scrnIndex, from, "Display dimensions: (%d, %d) mm\n",
                   ddcWidthmm, ddcHeightmm);
        pScrn.widthmm = ddcWidthmm;
        pScrn.heightmm = ddcHeightmm;
        if (pScrn.widthmm > 0) {
            pScrn.xDpi =
                cast(int) (cast(double) pScrn.virtualX * MMPERINCH / pScrn.widthmm);
        }
        if (pScrn.heightmm > 0) {
            pScrn.yDpi =
                cast(int) (cast(double) pScrn.virtualY * MMPERINCH / pScrn.heightmm);
        }
        if (pScrn.xDpi > 0 && pScrn.yDpi <= 0)
            pScrn.yDpi = pScrn.xDpi;
        if (pScrn.yDpi > 0 && pScrn.xDpi <= 0)
            pScrn.xDpi = pScrn.yDpi;
    }
    else {
        if (x > 0)
            pScrn.xDpi = x;
        else
            pScrn.xDpi = DEFAULT_DPI;
        if (y > 0)
            pScrn.yDpi = y;
        else
            pScrn.yDpi = DEFAULT_DPI;
    }
    xf86DrvMsg(pScrn.scrnIndex, from, "DPI set to (%d, %d)\n",
               pScrn.xDpi, pScrn.yDpi);
}

void xf86SetBlackWhitePixels(ScreenPtr pScreen)
{
    if (xf86FlipPixels) {
        pScreen.whitePixel = 0;
        pScreen.blackPixel = 1;
    }
    else {
        pScreen.whitePixel = 1;
        pScreen.blackPixel = 0;
    }
}

/*
 * Function to enable/disable access to the frame buffer
 *
 * This is used when VT switching and when entering/leaving DGA direct mode.
 *
 * This has been rewritten again to eliminate the saved pixmap.  The
 * devPrivate field in the screen pixmap is set to NULL to catch code
 * accidentally referencing the frame buffer while the X server is not
 * supposed to touch it.
 *
 * Here, we exchange the pixmap private data, rather than the pixmaps
 * themselves to avoid having to find and change any references to the screen
 * pixmap such as GC's, window privates etc.  This also means that this code
 * does not need to know exactly how the pixmap pixels are accessed.  Further,
 * this exchange is >not< done through the screen's ModifyPixmapHeader()
 * vector.  This means the called frame buffer code layers can determine
 * whether they are switched in or out by keeping track of the root pixmap's
 * private data, and therefore don't need to access pScrnInfo->vtSema.
 */
void xf86EnableDisableFBAccess(ScrnInfoPtr pScrnInfo, Bool enable)
{
    ScreenPtr pScreen = pScrnInfo.pScreen;

    if (enable) {
        /*
         * Restore all of the clip lists on the screen
         */
        if (!xf86Resetting)
            SetRootClip(pScreen, ROOT_CLIP_FULL);

    }
    else {
        /*
         * Empty all of the clip lists on the screen
         */
        SetRootClip(pScreen, ROOT_CLIP_NONE);
    }
}

/* Print driver messages in the standard format of
   (<type>) <screen name>(<screen index>): <message> */
void xf86VDrvMsgVerb(int scrnIndex, MessageType type, int verb, const(char)* format, va_list args)
{
    /* Prefix the scrnIndex name to the format string. */
    if (scrnIndex >= 0 && scrnIndex < xf86NumScreens &&
        xf86Screens[scrnIndex].name)
        LogHdrMessageVerb(type, verb, format, args, "%s(%d): ",
                          xf86Screens[scrnIndex].name, scrnIndex);
    else if (scrnIndex >= GPU_SCREEN_OFFSET &&
             scrnIndex < GPU_SCREEN_OFFSET + xf86NumGPUScreens &&
             xf86GPUScreens[scrnIndex - GPU_SCREEN_OFFSET].name)
        LogHdrMessageVerb(type, verb, format, args, "%s(G%d): ",
                          xf86GPUScreens[scrnIndex - GPU_SCREEN_OFFSET].name, scrnIndex - GPU_SCREEN_OFFSET);
    else
        LogVMessageVerb(type, verb, format, args);
}

/* Print driver messages, with verbose level specified directly */
void xf86DrvMsgVerb(int scrnIndex, MessageType type, int verb, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    xf86VDrvMsgVerb(scrnIndex, type, verb, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Print driver messages, with verbose level of 1 (default) */
void xf86DrvMsg(int scrnIndex, MessageType type, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    xf86VDrvMsgVerb(scrnIndex, type, 1, format, ap);
    core.stdc.stdarg.va_end(ap);
}

private void xf86VIDrvMsgVerb(InputInfoPtr dev, MessageType type, int verb, const(char)* format, va_list args);

/* Print input driver messages in the standard format of
   (<type>) <driver>: <device name>: <message> */
private void xf86VIDrvMsgVerb(InputInfoPtr dev, MessageType type, int verb, const(char)* format, va_list args)
{
    const(char)* driverName = null;
    const(char)* deviceName = null;

    /* Prefix driver and device names to formatted message. */
    if (dev) {
        deviceName = dev.name;
        if (dev.drv)
            driverName = dev.drv.driverName;
    }

    LogHdrMessageVerb(type, verb, format, args, "%s: %s: ", driverName,
                      deviceName);
}

/* Print input driver message, with verbose level specified directly */
void xf86IDrvMsgVerb(InputInfoPtr dev, MessageType type, int verb, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    xf86VIDrvMsgVerb(dev, type, verb, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Print input driver messages, with verbose level of 1 (default) */
void xf86IDrvMsg(InputInfoPtr dev, MessageType type, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    xf86VIDrvMsgVerb(dev, type, 1, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Just like ErrorF, but with the verbose level checked */
void xf86ErrorFVerb(int verb, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    if (xf86Verbose >= verb || xf86LogVerbose >= verb)
        LogVMessageVerb(X_NONE, verb, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Like xf86ErrorFVerb, but with an implied verbose level of 1 */
void xf86ErrorF(const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    if (xf86Verbose >= 1 || xf86LogVerbose >= 1)
        LogVMessageVerb(X_NONE, 1, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Note temporarily modifies the passed in buffer! */
private void xf86_mkdir_p(char* path)
{
    char* sep = path;

    while ((sep = strchr(sep + 1, '/')) !is null) {
        *sep = 0;
        cast(void)mkdir(path, octal!"0777");
        *sep = '/';
    }
    cast(void)mkdir(path, octal!"0777");
}

void xf86LogInit()
{
    char* env = void, lf = null;
    char[PATH_MAX] buf = void;

enum LOGSUFFIX = ".log";
enum LOGOLDSUFFIX = ".old";

    /* Get the log file name */
    if (xf86LogFileFrom == X_DEFAULT) {
        /* When not running as root, we won't be able to write to /var/log */
        if (geteuid() != 0) {
            if ((env = getenv("XDG_STATE_HOME")) !is null)
                snprintf(buf.ptr, buf.sizeof, "%s/%s", env,
                         DEFAULT_XDG_STATE_HOME_LOGDIR.ptr);
            else if ((env = getenv("HOME")) !is null)
                snprintf(buf.ptr, buf.sizeof, "%s/%s/%s", env,
                         DEFAULT_XDG_STATE_HOME.ptr, DEFAULT_XDG_STATE_HOME_LOGDIR.ptr);

            if (env !is null) {
                xf86_mkdir_p(buf.ptr);
                strlcat(buf.ptr, "/" ~DEFAULT_LOGPREFIX, buf.sizeof);
                xf86LogFile = buf.ptr;
            }
        }
        /* Append the display number and ".log" */
        if (asprintf(&lf, "%s%%s" ~LOGSUFFIX, xf86LogFile) == -1)
            FatalError("Cannot allocate space for the log file name\n");
        xf86LogFile = lf;
    }

    xf86LogFile = LogInit(xf86LogFile, LOGOLDSUFFIX);
    xf86LogFileWasOpened = True;

    xf86SetVerbosity(xf86Verbose);
    xf86SetLogVerbosity(xf86LogVerbose);

    free(lf);
}

void xf86CloseLog(ExitCode error)
{
    LogClose(error);
}

/*
 * Drivers can use these for using their own SymTabRecs.
 */

const(char)* xf86TokenToString(SymTabPtr table, int token)
{
    int i = void;

    for (i = 0; table[i].token >= 0 && table[i].token != token; i++){}

    if (table[i].token < 0)
        return null;
    else
        return table[i].name;
}

int xf86StringToToken(SymTabPtr table, const(char)* string)
{
    int i = void;

    if (string is null)
        return -1;

    for (i = 0; table[i].token >= 0 && xf86NameCmp(string, table[i].name); i++){}

    return table[i].token;
}

/*
 * helper to display the clocks found on a card
 */
void xf86ShowClocks(ScrnInfoPtr scrp, MessageType from)
{
    int j = void;

    xf86DrvMsg(scrp.scrnIndex, from, "Pixel clocks available:");
    for (j = 0; j < scrp.numClocks; j++) {
        if ((j % 4) == 0) {
            xf86ErrorF("\n");
            xf86DrvMsg(scrp.scrnIndex, from, "pixel clocks:");
        }
        xf86ErrorF(" %7.3f", cast(double) scrp.clock[j] / 1000.0);
    }
    xf86ErrorF("\n");
}

/*
 * This prints out the driver identify message, including the names of
 * the supported chipsets.
 *
 * XXX This makes assumptions about the line width, etc.  Maybe we could
 * use a more general "pretty print" function for messages.
 */
void xf86PrintChipsets(const(char)* drvname, const(char)* drvmsg, SymTabPtr chips)
{
    int len = void, i = void;

    len = cast(int)(6 + strlen(drvname) + 2 + strlen(drvmsg) + 2);
    LogMessageVerb(X_INFO, 1, "%s: %s:", drvname, drvmsg);
    for (i = 0; chips[i].name !is null; i++) {
        if (i != 0) {
            xf86ErrorF(",");
            len++;
        }
        if (len + 2 + strlen(chips[i].name) < 78) {
            xf86ErrorF(" ");
            len++;
        }
        else {
            xf86ErrorF("\n\t");
            len = 8;
        }
        xf86ErrorF("%s", chips[i].name);
        len += strlen(chips[i].name);
    }
    xf86ErrorF("\n");
}

int xf86MatchDevice(const(char)* drivername, GDevPtr** sectlist)
{
    GDevPtr gdp = void; GDevPtr* pgdp = null;
    confScreenPtr screensecptr = void;
    int i = void, j = void, k = void;

    if (sectlist)
        *sectlist = null;

    /*
     * This can happen when running Xorg -showopts and a module like ati
     * or vmware tries to load its submodules when xf86ConfigLayout is empty
     */
    if (!xf86ConfigLayout.screens)
        return 0;

    /*
     * This is a very important function that matches the device sections
     * as they show up in the config file with the drivers that the server
     * loads at run time.
     *
     * ChipProbe can call
     * int xf86MatchDevice(char * drivername, GDevPtr ** sectlist)
     * with its driver name. The function allocates an array of GDevPtr and
     * returns this via sectlist and returns the number of elements in
     * this list as return value. 0 means none found, -1 means fatal error.
     *
     * It can figure out which of the Device sections to use for which card
     * (using things like the Card statement, etc). For single headed servers
     * there will of course be just one such Device section.
     */
    i = 0;

    /*
     * first we need to loop over all the Screens sections to get to all
     * 'active' device sections
     */
    for (j = 0; xf86ConfigLayout.screens[j].screen !is null; j++) {
        screensecptr = xf86ConfigLayout.screens[j].screen;
        if ((screensecptr.device !is null)
            && (screensecptr.device.driver !is null)
            && (xf86NameCmp(screensecptr.device.driver, drivername) == 0)
            && (!screensecptr.device.claimed)) {
            /*
             * we have a matching driver that wasn't claimed, yet
             */
            pgdp = cast(GDevPtr*) XNFreallocarray(pgdp, i + 2, GDevPtr.sizeof);
            pgdp[i++] = screensecptr.device;
        }
        for (k = 0; k < screensecptr.num_gpu_devices; k++) {
            if ((screensecptr.gpu_devices[k].driver !is null)
            && (xf86NameCmp(screensecptr.gpu_devices[k].driver, drivername) == 0)
                && (!screensecptr.gpu_devices[k].claimed)) {
                /*
                 * we have a matching driver that wasn't claimed, yet
                 */
                pgdp = cast(GDevPtr*)XNFrealloc(pgdp, (i + 2) * GDevPtr.sizeof);
                pgdp[i++] = screensecptr.gpu_devices[k];
            }
        }
    }

    /* Then handle the inactive devices */
    j = 0;
    while (xf86ConfigLayout.inactives[j].identifier) {
        gdp = &xf86ConfigLayout.inactives[j];
        if (gdp.driver && !gdp.claimed &&
            !xf86NameCmp(gdp.driver, drivername)) {
            /* we have a matching driver that wasn't claimed yet */
            pgdp = cast(GDevPtr*) XNFreallocarray(pgdp, i + 2, GDevPtr.sizeof);
            pgdp[i++] = gdp;
        }
        j++;
    }

    /*
     * make the array NULL terminated and return its address
     */
    if (i)
        pgdp[i] = null;

    if (sectlist)
        *sectlist = pgdp;
    else
        free(pgdp);
    return i;
}

const(char)* xf86GetVisualName(int visual)
{
    if (visual < 0 || visual > DirectColor)
        return null;

    return xf86VisualNames[visual];
}

int xf86GetVerbosity()
{
    return max(xf86Verbose, xf86LogVerbose);
}

Gamma xf86GetGamma()
{
    return xf86Gamma;
}

Bool xf86ServerIsExiting()
{
    return (dispatchException & DE_TERMINATE) == DE_TERMINATE;
}

Bool xf86ServerIsOnlyDetecting()
{
    return xf86DoConfigure;
}

Bool xf86GetAllowMouseOpenFail()
{
    return xf86Info.allowMouseOpenFail;
}

CARD32 xf86GetModuleVersion(void* module_)
{
    return cast(CARD32) LoaderGetModuleVersion(cast(module_desc*)module_);
}

void* xf86LoadDrvSubModule(DriverPtr drv, const(char)* name)
{
    void* ret = void;
    int errmaj = 0, errmin = 0;

    ret = LoadSubModule(drv.module_, name, null, null, null, null,
                        &errmaj, &errmin);
    if (!ret)
        LoaderErrorMsg(null, name, errmaj, errmin);
    return ret;
}

void* xf86LoadSubModule(ScrnInfoPtr pScrn, const(char)* name)
{
    void* ret = void;
    int errmaj = 0, errmin = 0;

    ret = LoadSubModule(pScrn.module_, name, null, null, null, null,
                        &errmaj, &errmin);
    if (!ret)
        LoaderErrorMsg(pScrn.name, name, errmaj, errmin);
    return ret;
}

/*
 * xf86LoadOneModule loads a single module.
 */
void* xf86LoadOneModule(const(char)* name, void* opt)
{
    int errmaj = void;
    char* Name = void;
    void* mod = void;

    if (!name)
        return null;

    /* Normalise the module name */
    Name = xf86NormalizeName(name);

    /* Skip empty names */
    if (Name is null)
        return null;
    if (*Name == '\0') {
        free(Name);
        return null;
    }

    mod = LoadModule(Name, opt, null, &errmaj);
    if (!mod)
        LoaderErrorMsg(null, Name, errmaj, 0);
    free(Name);
    return mod;
}

void xf86UnloadSubModule(void* mod)
{
    UnloadSubModule(cast(module_desc*)mod);
}

Bool xf86LoaderCheckSymbol(const(char)* name)
{
    return LoaderSymbol(name) !is null;
}

enum BSOpts {
    OPTION_BACKING_STORE
}
alias OPTION_BACKING_STORE = BSOpts.OPTION_BACKING_STORE;


private const(OptionInfoRec)[2] BSOptions = [
    {OPTION_BACKING_STORE, "BackingStore", OPTV_BOOLEAN, {0}, False},
    {-1, null, OPTV_NONE, {0}, False}
];

void xf86SetBackingStore(ScreenPtr pScreen)
{
    Bool useBS = False;
    MessageType from = X_DEFAULT;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    OptionInfoPtr options = void;

    options = cast(OptionInfoRec*)XNFalloc(BSOptions.sizeof);
    cast(void) memcpy(options, BSOptions.ptr, BSOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, options);

    /* check for commandline option here */
    if (xf86bsEnableFlag) {
        from = X_CMDLINE;
        useBS = True;
    }
    else if (xf86bsDisableFlag) {
        from = X_CMDLINE;
        useBS = False;
    }
    else {
        if (xf86GetOptValBool(options, OPTION_BACKING_STORE, &useBS))
            from = X_CONFIG;
static if(COMPOSITE) {
        if (from != X_CONFIG)
            useBS = xf86ReturnOptValBool(options, OPTION_BACKING_STORE,
                                         !noCompositeExtension);
}
    }
    free(options);
    pScreen.backingStoreSupport = useBS ? WhenMapped : NotUseful;
    if (serverGeneration == 1)
        xf86DrvMsg(pScreen.myNum, from, "Backing store %s\n",
                   useBS ? "enabled".ptr : "disabled".ptr);
}

enum SMOpts {
    OPTION_SILKEN_MOUSE
}
alias OPTION_SILKEN_MOUSE = SMOpts.OPTION_SILKEN_MOUSE;


private const(OptionInfoRec)[2] SMOptions = [
    {OPTION_SILKEN_MOUSE, "SilkenMouse", OPTV_BOOLEAN, {0}, False},
    {-1, null, OPTV_NONE, {0}, False}
];

void xf86SetSilkenMouse(ScreenPtr pScreen)
{
    Bool useSM = True;
    MessageType from = X_DEFAULT;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    OptionInfoPtr options = void;

    options = cast(OptionInfoRec*)XNFalloc(SMOptions.sizeof);
    cast(void) memcpy(options, SMOptions.ptr, SMOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, options);

    /* check for commandline option here */
    /* disable if screen shares resources */
    /* TODO VGA arb disable silken mouse */
    if (xf86silkenMouseDisableFlag) {
        from = X_CMDLINE;
        useSM = False;
    }
    else {
        if (xf86GetOptValBool(options, OPTION_SILKEN_MOUSE, &useSM))
            from = X_CONFIG;
    }
    free(options);
    /*
     * Use silken mouse if requested and if we have threaded input
     */
    pScrn.silkenMouse = useSM && InputThreadEnable;
    if (serverGeneration == 1)
        xf86DrvMsg(pScreen.myNum, from, "Silken mouse %s\n",
                   pScrn.silkenMouse ? "enabled".ptr : "disabled".ptr);
}

private void xf86ConfigFbEntityInactive(EntityInfoPtr pEnt, EntityProc init, EntityProc enter, EntityProc leave, void* private_)
{
    ScrnInfoPtr pScrn = void;

    if ((pScrn = xf86FindScreenForEntity(pEnt.index)) !is null)
        xf86RemoveEntityFromScreen(pScrn, pEnt.index);
}

ScrnInfoPtr xf86ConfigFbEntity(ScrnInfoPtr pScrn, int scrnFlag, int entityIndex, EntityProc init, EntityProc enter, EntityProc leave, void* private_)
{
    EntityInfoPtr pEnt = xf86GetEntityInfo(entityIndex);

    if (init || enter || leave)
        FatalError("Legacy entity access functions are unsupported\n");

    if (!pEnt)
        return pScrn;

    if (!(pEnt.location.type == BUS_NONE)) {
        free(pEnt);
        return pScrn;
    }

    if (!pEnt.active) {
        xf86ConfigFbEntityInactive(pEnt, init, enter, leave, private_);
        free(pEnt);
        return pScrn;
    }

    if (!pScrn)
        pScrn = xf86AllocateScreen(pEnt.driver, scrnFlag);
    xf86AddEntityToScreen(pScrn, entityIndex);

    free(pEnt);
    return pScrn;
}

Bool xf86IsUnblank(int mode)
{
    switch (mode) {
    case SCREEN_SAVER_OFF:
    case SCREEN_SAVER_FORCER:
        return True;
    case SCREEN_SAVER_ON:
    case SCREEN_SAVER_CYCLE:
        return False;
    default:
        LogMessageVerb(X_WARNING, 0, "Unexpected save screen mode: %d\n", mode);
        return True;
    }
}

void xf86MotionHistoryAllocate(InputInfoPtr pInfo)
{
    AllocateMotionHistory(pInfo.dev);
}

ScrnInfoPtr xf86ScreenToScrn(ScreenPtr pScreen)
{
    if (pScreen.isGPU) {
        assert(pScreen.myNum - GPU_SCREEN_OFFSET < xf86NumGPUScreens);
        return xf86GPUScreens[pScreen.myNum - GPU_SCREEN_OFFSET];
    } else {
        assert(pScreen.myNum < xf86NumScreens);
        return xf86Screens[pScreen.myNum];
    }
}

ScreenPtr xf86ScrnToScreen(ScrnInfoPtr pScrn)
{
    if (pScrn.is_gpu) {
        assert(pScrn.scrnIndex - GPU_SCREEN_OFFSET < screenInfo.numGPUScreens);
        return screenInfo.gpuscreens[pScrn.scrnIndex - GPU_SCREEN_OFFSET];
    } else {
        assert(pScrn.scrnIndex < screenInfo.numScreens);
        return screenInfo.screens[pScrn.scrnIndex];
    }
}

void xf86AddInputEventDrainCallback(CallbackProcPtr callback, void* param)
{
    mieqAddCallbackOnDrained(callback, param);
}

void xf86RemoveInputEventDrainCallback(CallbackProcPtr callback, void* param)
{
    mieqRemoveCallbackOnDrained(callback, param);
}
