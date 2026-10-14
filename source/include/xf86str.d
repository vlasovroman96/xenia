module include.xf86str;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;

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
 * This file contains definitions of the public XFree86 data structures/types.
 * Any data structures that video drivers need to access should go here.
 */

 
public import include.xlibre_ptrtypes;
public import include.misc;
// public import include.input;
public import include.scrnintstr;
public import include.pixmapstr;
public import dix.colormapst;
public import include.xf86Module;
public import include.xf86Opt;
public import include.displaymode;
import externs.pciaccess;
import include.xf86Xinput;
public import include.xf86platformBus;
/**
 * Integer type that is of the size of the addressable memory (machine size).
 * On most platforms \c uintptr_t will suffice.  However, on some mixed
 * 32-bit / 64-bit platforms, such as 32-bit binaries on 64-bit PowerPC, this
 * must be 64-bits.
 */
public import core.stdc.inttypes;
version (__powerpc__) {
alias memType = ulong;
} else {
alias memType = uintptr_t;
}

/* Video mode flags */

enum ModeFlags {
    V_PHSYNC = 0x0001,
    V_NHSYNC = 0x0002,
    V_PVSYNC = 0x0004,
    V_NVSYNC = 0x0008,
    V_INTERLACE = 0x0010,
    V_DBLSCAN = 0x0020,
    V_CSYNC = 0x0040,
    V_PCSYNC = 0x0080,
    V_NCSYNC = 0x0100,
    V_HSKEW = 0x0200,           /* hskew provided */
    V_BCAST = 0x0400,
    V_PIXMUX = 0x1000,
    V_DBLCLK = 0x2000,
    V_CLKDIV2 = 0x4000
}
alias V_PHSYNC = ModeFlags.V_PHSYNC;
alias V_NHSYNC = ModeFlags.V_NHSYNC;
alias V_PVSYNC = ModeFlags.V_PVSYNC;
alias V_NVSYNC = ModeFlags.V_NVSYNC;
alias V_INTERLACE = ModeFlags.V_INTERLACE;
alias V_DBLSCAN = ModeFlags.V_DBLSCAN;
alias V_CSYNC = ModeFlags.V_CSYNC;
alias V_PCSYNC = ModeFlags.V_PCSYNC;
alias V_NCSYNC = ModeFlags.V_NCSYNC;
alias V_HSKEW = ModeFlags.V_HSKEW;
alias V_BCAST = ModeFlags.V_BCAST;
alias V_PIXMUX = ModeFlags.V_PIXMUX;
alias V_DBLCLK = ModeFlags.V_DBLCLK;
alias V_CLKDIV2 = ModeFlags.V_CLKDIV2;


enum CrtcAdjustFlags {
    INTERLACE_HALVE_V = 0x0001  /* Halve V values for interlacing */
}
alias INTERLACE_HALVE_V = CrtcAdjustFlags.INTERLACE_HALVE_V;


/* Flags passed to ChipValidMode() */
enum ModeCheckFlags {
    MODECHECK_INITIAL = 0,
    MODECHECK_FINAL = 1
}
alias MODECHECK_INITIAL = ModeCheckFlags.MODECHECK_INITIAL;
alias MODECHECK_FINAL = ModeCheckFlags.MODECHECK_FINAL;


/*
 * The mode sets are, from best to worst: USERDEF, DRIVER, and DEFAULT/BUILTIN.
 * Preferred will bubble a mode to the top within a set.
 */
enum M_T_BUILTIN = 0x01        /* built-in mode */;
enum M_T_CLOCK_C = (0x02 | M_T_BUILTIN)        /* built-in mode - configure clock */;
enum M_T_CRTC_C =  (0x04 | M_T_BUILTIN)        /* built-in mode - configure CRTC  */;
enum M_T_CLOCK_CRTC_C =  (M_T_CLOCK_C | M_T_CRTC_C);
                               /* built-in mode - configure CRTC and clock */
enum M_T_PREFERRED = 0x08      /* preferred mode within a set */;
enum M_T_DEFAULT = 0x10        /* (VESA) default modes */;
enum M_T_USERDEF = 0x20        /* One of the modes from the config file */;
enum M_T_DRIVER =  0x40        /* Supplied by the driver (EDID, etc) */;
enum M_T_USERPREF = 0x80       /* mode preferred by the user config */;

/* The monitor description */

enum MAX_HSYNC = 8;
enum MAX_VREFRESH = 8;

struct range {
    float hi = 0, lo = 0;
}

struct rgb {
    CARD32 red, green, blue;
}

struct Gamma {
    float red = 0, green = 0, blue = 0;
}

/* The permitted gamma range is 1 / GAMMA_MAX <= g <= GAMMA_MAX */
enum GAMMA_MAX =	10.0;
enum GAMMA_MIN =	(1.0 / GAMMA_MAX);
enum GAMMA_ZERO =	(GAMMA_MIN / 100.0);

struct _MonRec {
    const(char)* id;
    const(char)* vendor;
    const(char)* model;
    int nHsync;
    range[MAX_HSYNC] hsync;
    int nVrefresh;
    range[MAX_VREFRESH] vrefresh;
    DisplayModePtr Modes;       /* Start of the monitor's mode list */
    DisplayModePtr Last;        /* End of the monitor's mode list */
    Gamma gamma;                /* Gamma of the monitor */
    int widthmm;
    int heightmm;
    void* options;
    void* DDC;
    Bool reducedblanking;       /* Allow CVT reduced blanking modes? */
    int maxPixClock;            /* in kHz, like mode->Clock */
}alias MonRec = _MonRec;
alias MonPtr = MonRec*;

/* the list of clock ranges */
struct x_ClockRange {
    x_ClockRange* next;
    int minClock;               /* (kHz) */
    int maxClock;               /* (kHz) */
    int clockIndex;             /* -1 for programmable clocks */
    Bool interlaceAllowed;
    Bool doubleScanAllowed;
    int ClockMulFactor;
    int ClockDivFactor;
    int PrivFlags;
}alias ClockRange = x_ClockRange;
alias ClockRangePtr = x_ClockRange*;

/*
 * The driverFunc. xorgDriverFuncOp specifies the action driver should
 * perform. If requested option is not supported function should return
 * FALSE. pointer can be used to pass arguments to the function or
 * to return data to the caller.
 */

/* do not change order */
enum xorgDriverFuncOp {
    RR_GET_INFO,
    RR_SET_CONFIG,
    RR_GET_MODE_MM,
    GET_REQUIRED_HW_INTERFACES = 10,
    SUPPORTS_SERVER_FDS = 11,
}
alias RR_GET_INFO = xorgDriverFuncOp.RR_GET_INFO;
alias RR_SET_CONFIG = xorgDriverFuncOp.RR_SET_CONFIG;
alias RR_GET_MODE_MM = xorgDriverFuncOp.RR_GET_MODE_MM;
alias GET_REQUIRED_HW_INTERFACES = xorgDriverFuncOp.GET_REQUIRED_HW_INTERFACES;
alias SUPPORTS_SERVER_FDS = xorgDriverFuncOp.SUPPORTS_SERVER_FDS;


alias xorgDriverFuncProc = Bool function(ScrnInfoPtr, xorgDriverFuncOp, void *) @nogc nothrow;

/* RR_GET_INFO, RR_SET_CONFIG */
struct xorgRRConfig {
    int rotation;
    int rate;
    int width;
    int height;
}

union _XorgRRRotation {
    short RRRotations;
    xorgRRConfig RRConfig;
}alias xorgRRRotation = _XorgRRRotation;
alias xorgRRRotationPtr = xorgRRRotation*;

/* RR_GET_MODE_MM */
struct _XorgRRModeMM {
    DisplayModePtr mode;
    int virtX;
    int virtY;
    int mmWidth;
    int mmHeight;
}alias xorgRRModeMM = _XorgRRModeMM;
alias xorgRRModeMMPtr = xorgRRModeMM*;

/* GET_REQUIRED_HW_INTERFACES */
enum HW_IO = 1;
enum HW_MMIO = 2;
enum HW_SKIP_CONSOLE = 4;
enum string NEED_IO_ENABLED(string x) = `(` ~ x ~ ` & HW_IO)`;

alias xorgHWFlags = CARD32;

/*
 * The driver list struct.  This contains the information required for each
 * driver before a ScrnInfoRec has been allocated.
 */
// struct _DriverRec;

// struct _SymTabRec;
struct _PciChipsets;

// struct pci_device;
// struct xf86_platform_device;

struct _DriverRec {
    int driverVersion;
    const(char)* driverName;
    void function(int flags) @nogc nothrow Identify;
    Bool function(_DriverRec* drv, int flags) @nogc nothrow Probe;
    const(OptionInfoRec)* function(int chipid, int bustype) @nogc nothrow AvailableOptions;
    void* module_;
    int refCount;
    xorgDriverFuncProc driverFunc;

    const(pci_id_match)* supported_devices;
    Bool function(_DriverRec* drv, int entity_num, pci_device* dev, intptr_t match_data) @nogc nothrow PciProbe;
    Bool function(_DriverRec* drv, int entity_num, int flags, xf86_platform_device* dev, intptr_t match_data) @nogc nothrow platformProbe;
}alias DriverRec = _DriverRec;
alias DriverPtr = _DriverRec*;

/*
 * platform probe flags
 */
enum PLATFORM_PROBE_GPU_SCREEN = 1;

/*
 *  AddDriver flags
 */
enum HaveDriverFuncs = 1;

/*
 * These are the private bus types.  New types can be added here.  Types
 * required for the public interface should be added to include.xf86str.h, with
 * function prototypes added to xf86.h.
 */

/* Tolerate prior #include <linux/input.h> */
static if (HasVersion!"linux" || HasVersion!"__FreeBSD__") {
}

enum BusType {
    BUS_NONE,
    BUS_PCI,
    BUS_SBUS,
    BUS_PLATFORM,
    BUS_USB,
    BUS_last                    /* Keep last */
}
alias BUS_NONE = BusType.BUS_NONE;
alias BUS_PCI = BusType.BUS_PCI;
alias BUS_SBUS = BusType.BUS_SBUS;
alias BUS_PLATFORM = BusType.BUS_PLATFORM;
alias BUS_USB = BusType.BUS_USB;
alias BUS_last = BusType.BUS_last;


struct SbusBusId {
    int fbNum;
}

struct _bus {
    BusType type;
    union _Id {
        pci_device* pci;
        SbusBusId sbus;
        xf86_platform_device* plat;
    }_Id id;
}alias BusRec = _bus;
alias BusPtr = _bus*;

enum DacSpeedIndex {
    DAC_BPP8 = 0,
    DAC_BPP16,
    DAC_BPP24,
    DAC_BPP32,
    MAXDACSPEEDS
}
alias DAC_BPP8 = DacSpeedIndex.DAC_BPP8;
alias DAC_BPP16 = DacSpeedIndex.DAC_BPP16;
alias DAC_BPP24 = DacSpeedIndex.DAC_BPP24;
alias DAC_BPP32 = DacSpeedIndex.DAC_BPP32;
alias MAXDACSPEEDS = DacSpeedIndex.MAXDACSPEEDS;


struct _GDevRec {
    const(char)* identifier;
    const(char)* vendor;
    const(char)* board;
    const(char)* chipset;
    const(char)* ramdac;
    const(char)* driver;
    _confscreenrec* myScreenSection;
    Bool claimed;
    int[MAXDACSPEEDS] dacSpeeds;
    int numclocks;
    int[MAXCLOCKS] clock;
    const(char)* clockchip;
    const(char)* busID;
    Bool active;
    Bool inUse;
    int videoRam;
    c_ulong MemBase;      /* Frame buffer base address */
    c_ulong IOBase;
    int chipID;
    int chipRev;
    void* options;
    int irq;
    int screen;                 /* For multi-CRTC cards */
}alias GDevRec = _GDevRec;
alias GDevPtr = GDevRec*;

struct _DispRec {
    int frameX0;
    int frameY0;
    int virtualX;
    int virtualY;
    int depth;
    int fbbpp;
    rgb weight;
    rgb blackColour;
    rgb whiteColour;
    int defaultVisual;
    const(char)** modes;
    void* options;
}alias DispRec = _DispRec;
alias DispPtr = DispRec*;

struct _confxvportrec {
    const(char)* identifier;
    void* options;
}alias confXvPortRec = _confxvportrec;
alias confXvPortPtr = _confxvportrec*;

struct _confxvadaptrec {
    const(char)* identifier;
    int numports;
    confXvPortPtr ports;
    void* options;
}alias confXvAdaptorRec = _confxvadaptrec;
alias confXvAdaptorPtr = _confxvadaptrec*;

enum MAX_GPUDEVICES = 4;
struct _confscreenrec {
    const(char)* id;
    int screennum;
    int defaultdepth;
    int defaultbpp;
    int defaultfbbpp;
    MonPtr monitor;
    GDevPtr device;
    int numdisplays;
    DispPtr* displays;
    int numxvadaptors;
    confXvAdaptorPtr xvadaptors;
    void* options;

    int num_gpu_devices;
    GDevPtr[MAX_GPUDEVICES] gpu_devices;
}alias confScreenRec = _confscreenrec;
alias confScreenPtr = _confscreenrec*;

enum PositionType {
    PosObsolete = -1,
    PosAbsolute = 0,
    PosRightOf,
    PosLeftOf,
    PosAbove,
    PosBelow,
    PosRelative
}
alias PosObsolete = PositionType.PosObsolete;
alias PosAbsolute = PositionType.PosAbsolute;
alias PosRightOf = PositionType.PosRightOf;
alias PosLeftOf = PositionType.PosLeftOf;
alias PosAbove = PositionType.PosAbove;
alias PosBelow = PositionType.PosBelow;
alias PosRelative = PositionType.PosRelative;


struct _screenlayoutrec {
    confScreenPtr screen;
    const(char)* topname;
    confScreenPtr top;
    const(char)* bottomname;
    confScreenPtr bottom;
    const(char)* leftname;
    confScreenPtr left;
    const(char)* rightname;
    confScreenPtr right;
    PositionType where;
    int x;
    int y;
    const(char)* refname;
    confScreenPtr refscreen;
}alias screenLayoutRec = _screenlayoutrec;
alias screenLayoutPtr = _screenlayoutrec*;

alias InputInfoRec = _InputInfoRec;

struct _serverlayoutrec {
    const(char)* id;
    screenLayoutPtr screens;
    GDevPtr inactives;
    InputInfoRec** inputs;      /* NULL terminated */
    void* options;
}alias serverLayoutRec = _serverlayoutrec;
alias serverLayoutPtr = _serverlayoutrec*;

struct _confdribufferrec {
    int count;
    int size;
    enum _Flags {
        XF86DRI_WC_HINT = 0x0001        /* Placeholder: not implemented */
    }_Flags flags;
}alias confDRIBufferRec = _confdribufferrec;
alias confDRIBufferPtr = _confdribufferrec*;

struct _confdrirec {
    int group;
    int mode;
    int bufs_count;
    confDRIBufferRec* bufs;
}alias confDRIRec = _confdrirec;
alias confDRIPtr = _confdrirec*;

enum NUM_RESERVED_INTS =		4;
enum NUM_RESERVED_POINTERS =		4;
enum NUM_RESERVED_FUNCS =		4;

/* let clients know they can use this */
enum XF86_SCRN_HAS_PREFER_CLONE = 1;

alias funcPointer = void* function();

/* Power management events: so far we only support APM */

enum pmEvent {
    XF86_APM_UNKNOWN = -1,
    XF86_APM_SYS_STANDBY,
    XF86_APM_SYS_SUSPEND,
    XF86_APM_CRITICAL_SUSPEND,
    XF86_APM_USER_STANDBY,
    XF86_APM_USER_SUSPEND,
    XF86_APM_STANDBY_RESUME,
    XF86_APM_NORMAL_RESUME,
    XF86_APM_CRITICAL_RESUME,
    XF86_APM_LOW_BATTERY,
    XF86_APM_POWER_STATUS_CHANGE,
    XF86_APM_UPDATE_TIME,
    XF86_APM_CAPABILITY_CHANGED,
    XF86_APM_STANDBY_FAILED,
    XF86_APM_SUSPEND_FAILED
}
alias XF86_APM_UNKNOWN = pmEvent.XF86_APM_UNKNOWN;
alias XF86_APM_SYS_STANDBY = pmEvent.XF86_APM_SYS_STANDBY;
alias XF86_APM_SYS_SUSPEND = pmEvent.XF86_APM_SYS_SUSPEND;
alias XF86_APM_CRITICAL_SUSPEND = pmEvent.XF86_APM_CRITICAL_SUSPEND;
alias XF86_APM_USER_STANDBY = pmEvent.XF86_APM_USER_STANDBY;
alias XF86_APM_USER_SUSPEND = pmEvent.XF86_APM_USER_SUSPEND;
alias XF86_APM_STANDBY_RESUME = pmEvent.XF86_APM_STANDBY_RESUME;
alias XF86_APM_NORMAL_RESUME = pmEvent.XF86_APM_NORMAL_RESUME;
alias XF86_APM_CRITICAL_RESUME = pmEvent.XF86_APM_CRITICAL_RESUME;
alias XF86_APM_LOW_BATTERY = pmEvent.XF86_APM_LOW_BATTERY;
alias XF86_APM_POWER_STATUS_CHANGE = pmEvent.XF86_APM_POWER_STATUS_CHANGE;
alias XF86_APM_UPDATE_TIME = pmEvent.XF86_APM_UPDATE_TIME;
alias XF86_APM_CAPABILITY_CHANGED = pmEvent.XF86_APM_CAPABILITY_CHANGED;
alias XF86_APM_STANDBY_FAILED = pmEvent.XF86_APM_STANDBY_FAILED;
alias XF86_APM_SUSPEND_FAILED = pmEvent.XF86_APM_SUSPEND_FAILED;


enum pmWait {
    PM_WAIT,
    PM_CONTINUE,
    PM_FAILED,
    PM_NONE
}
alias PM_WAIT = pmWait.PM_WAIT;
alias PM_CONTINUE = pmWait.PM_CONTINUE;
alias PM_FAILED = pmWait.PM_FAILED;
alias PM_NONE = pmWait.PM_NONE;


struct PciChipsets {
    /**
     * Key used to match this device with its name in an array of
     * \c SymTabRec.
     */
    int numChipset;

    /**
     * This value is quirky.  Depending on the driver, it can take on one of
     * three meanings.  In drivers that have exactly one vendor ID (e.g.,
     * radeon, mga, i810) the low 16-bits are the device ID.
     *
     * In drivers that can have multiple vendor IDs (e.g., the glint driver
     * can have either 3dlabs' ID or TI's ID, the i740 driver can have either
     * Intel's ID or Real3D's ID, etc.) the low 16-bits are the device ID and
     * the high 16-bits are the vendor ID.
     *
     * In drivers that don't have a specific vendor (e.g., vga) contains the
     * device ID for either the generic VGA or generic 8514 devices.  This
     * turns out to be the same as the subclass and programming interface
     * value (e.g., the full 24-bit class for the VGA device is 0x030000 (or
     * 0x000101) and for 8514 is 0x030001).
     */
    int PCIid;

/* dummy place holders for drivers to build against old/new servers */
// enum RES_UNDEFINED = NULL;
// enum RES_EXCLUSIVE_VGA = NULL;
// enum RES_SHARED_VGA = NULL;
    void* dummy;
}

/* Entity properties */
alias EntityProc = void function(int entityIndex, void* private_);

struct _entityInfo {
    int index;
    BusRec location;
    int chipset;
    Bool active;
    GDevPtr device;
    DriverPtr driver;
}alias EntityInfoRec = _entityInfo;
alias EntityInfoPtr = _entityInfo*;

/* DGA */

struct _DGAModeRec {
    int num;                    /* A unique identifier for the mode (num > 0) */
    DisplayModePtr mode;
    int flags;                  /* DGA_CONCURRENT_ACCESS, etc... */
    int imageWidth;             /* linear accessible portion (pixels) */
    int imageHeight;
    int pixmapWidth;            /* Xlib accessible portion (pixels) */
    int pixmapHeight;           /* both fields ignored if no concurrent access */
    int bytesPerScanline;
    int byteOrder;              /* MSBFirst, LSBFirst */
    int depth;
    int bitsPerPixel;
    c_ulong red_mask;
    c_ulong green_mask;
    c_ulong blue_mask;
    short visualClass;
    int viewportWidth;
    int viewportHeight;
    int xViewportStep;          /* viewport position granularity */
    int yViewportStep;
    int maxViewportX;           /* max viewport origin */
    int maxViewportY;
    int viewportFlags;          /* types of page flipping possible */
    int offset;                 /* offset into physical memory */
    ubyte* address;     /* server's mapped framebuffer */
    int reserved1;
    int reserved2;
}alias DGAModeRec = _DGAModeRec;
alias DGAModePtr = DGAModeRec*;

struct _DGADeviceRec {
    DGAModePtr mode;
    PixmapPtr pPix;
}alias DGADeviceRec = _DGADeviceRec;
alias DGADevicePtr = DGADeviceRec*;

/*
 * Flags for driver Probe() functions.
 */
enum PROBE_DEFAULT =	  0x00;
enum PROBE_DETECT =	  0x01;
enum PROBE_TRYHARD =	  0x02;

/*
 * Driver entry point types
 */

// alias xf86ProbeProc = ;
// alias xf86PreInitProc = ;
// alias xf86ScreenInitProc = ;
// alias xf86SwitchModeProc = ;
// alias xf86AdjustFrameProc = ;
// alias xf86EnterVTProc = ;
// alias xf86LeaveVTProc = ;
// alias xf86FreeScreenProc = ;
// alias xf86ValidModeProc = ;
// alias xf86EnableDisableFBAccessProc = ;
// alias xf86SetDGAModeProc = ;
// alias xf86ChangeGammaProc = ;
// alias xf86PointerMovedProc = ;
// alias xf86PMEventProc = ;
// alias xf86DPMSSetProc = ;
// alias xf86LoadPaletteProc = ;
// alias xf86SetOverscanProc = ;
// alias xf86ModeSetProc = ;

alias xf86ProbeProc = Bool function(DriverPtr, int) @nogc nothrow;
alias xf86PreInitProc = Bool function(ScrnInfoPtr, int) @nogc nothrow;
alias xf86ScreenInitProc = Bool function(ScreenPtr, int, char **) @nogc nothrow;
alias xf86SwitchModeProc = Bool function(ScrnInfoPtr, DisplayModePtr) @nogc nothrow;
alias xf86AdjustFrameProc = void function(ScrnInfoPtr, int, int) @nogc nothrow;
alias xf86EnterVTProc = Bool function(ScrnInfoPtr) @nogc nothrow;
alias xf86LeaveVTProc = void function(ScrnInfoPtr) @nogc nothrow;
alias xf86FreeScreenProc = void function(ScrnInfoPtr) @nogc nothrow;
alias xf86ValidModeProc = ModeStatus function(ScrnInfoPtr, DisplayModePtr, Bool, int) @nogc nothrow;
alias xf86EnableDisableFBAccessProc = void function(ScrnInfoPtr, Bool) @nogc nothrow;
alias xf86SetDGAModeProc = int function(ScrnInfoPtr, int, DGADevicePtr) @nogc nothrow;
alias xf86ChangeGammaProc = int function(ScrnInfoPtr, Gamma) @nogc nothrow;
alias xf86PointerMovedProc = void function(ScrnInfoPtr, int, int) @nogc nothrow;
alias xf86PMEventProc = Bool function(ScrnInfoPtr, pmEvent, Bool) @nogc nothrow;
alias xf86DPMSSetProc = void function(ScrnInfoPtr, int, int) @nogc nothrow;
alias xf86LoadPaletteProc = void function(ScrnInfoPtr, int, int *, LOCO *, VisualPtr) @nogc nothrow;
alias xf86SetOverscanProc = void function(ScrnInfoPtr, int) @nogc nothrow;
alias xf86ModeSetProc = void function(ScrnInfoPtr) @nogc nothrow;

/*
 * ScrnInfoRec
 *
 * There is one of these for each screen, and it holds all the screen-specific
 * information.  Note: No fields are to be dependent on compile-time defines.
 */
struct _ScrnInfoRec {
    int driverVersion;
    const(char)* driverName;     /* canonical name used in */
    /* the config file */
    ScreenPtr pScreen;          /* Pointer to the ScreenRec */
    int scrnIndex;              /* Number of this screen */
    Bool configured;            /* Is this screen valid */
    int origIndex;              /* initial number assigned to
                                 * this screen before
                                 * finalising the number of
                                 * available screens */

    /* Display-wide screenInfo values needed by this screen */
    int imageByteOrder;
    int bitmapScanlineUnit;
    int bitmapScanlinePad;
    int bitmapBitOrder;
    int numFormats;
    PixmapFormatRec[MAXFORMATS] formats;
    PixmapFormatRec fbFormat;

    int bitsPerPixel;           /* fb bpp */
    int depth;                  /* depth of default visual */
    MessageType depthFrom;      /* set from config? */
    MessageType bitsPerPixelFrom;       /* set from config? */
    rgb weight;                 /* r/g/b weights */
    rgb mask;                   /* rgb masks */
    rgb offset;                 /* rgb offsets */
    int rgbBits;                /* Number of bits in r/g/b */
    Gamma gamma;                /* Gamma of the monitor */
    int defaultVisual;          /* default visual class */
    int virtualX;               /* Virtual width */
    int virtualY;               /* Virtual height */
    int xInc;                   /* Horizontal timing increment */
    int displayWidth;           /* memory pitch */
    int frameX0;                /* viewport position */
    int frameY0;
    int frameX1;
    int frameY1;
    int zoomLocked;             /* Disallow mode changes */
    DisplayModePtr modePool;    /* list of compatible modes */
    DisplayModePtr modes;       /* list of actual modes */
    DisplayModePtr currentMode; /* current mode
                                 * This was previously
                                 * overloaded with the modes
                                 * field, which is a pointer
                                 * into a circular list */
    confScreenPtr confScreen;   /* Screen config info */
    MonPtr monitor;             /* Monitor information */
    DispPtr display;            /* Display information */
    int* entityList;            /* List of device entities */
    int numEntities;
    int widthmm;                /* physical display dimensions
                                 * in mm */
    int heightmm;
    int xDpi;                   /* width DPI */
    int yDpi;                   /* height DPI */
    const(char)* name;           /* Name to prefix messages */
    void* driverPrivate;        /* Driver private area */
    DevUnion* privates;         /* Other privates can hook in
                                 * here */
    DriverPtr drv;              /* xf86DriverList[] entry */
    void* module_;               /* Pointer to module include.head */
    int colorKey;
    int overlayFlags;

    /* Some of these may be moved out of here into the driver private area */

    const(char)* chipset;        /* chipset name */
    const(char)* ramdac;         /* ramdac name */
    const(char)* clockchip;      /* clock name */
    Bool progClock;             /* clock is programmable */
    int numClocks;              /* number of clocks */
    int[MAXCLOCKS] clock;       /* list of clock frequencies */
    int videoRam;               /* amount of video ram (kb) */
    c_ulong memPhysBase;  /* Physical address of FB */
    c_ulong fbOffset;     /* Offset of FB in the above */
    void* options;

    /* Allow screens to be enabled/disabled individually */
    Bool vtSema;

    /* hw cursor moves from input thread */
    Bool silkenMouse;

    /* Storage for clockRanges and adjustFlags for use with the VidMode ext */
    ClockRangePtr clockRanges;
    int adjustFlags;

    /* initial rightof support disable */
    int preferClone;

    Bool is_gpu;
    uint capabilities;

    int* entityInstanceList;
    pci_device* vgaDev;

    /*
     * Driver entry points.
     *
     */

    xf86ProbeProc Probe;
    xf86PreInitProc PreInit;
    xf86ScreenInitProc ScreenInit;
    xf86SwitchModeProc SwitchMode;
    xf86AdjustFrameProc AdjustFrame;
    xf86EnterVTProc EnterVT;
    xf86LeaveVTProc LeaveVT;
    xf86FreeScreenProc FreeScreen;
    xf86ValidModeProc ValidMode;
    xf86EnableDisableFBAccessProc EnableDisableFBAccess;
    xf86SetDGAModeProc SetDGAMode;
    xf86ChangeGammaProc ChangeGamma;
    xf86PointerMovedProc PointerMoved;
    xf86PMEventProc PMEvent;
    xf86DPMSSetProc DPMSSet;
    xf86LoadPaletteProc LoadPalette;
    xf86SetOverscanProc SetOverscan;
    xorgDriverFuncProc DriverFunc;
    xf86ModeSetProc ModeSet;

    int[NUM_RESERVED_INTS] reservedInt;
    void*[NUM_RESERVED_POINTERS] reservedPtr;
    funcPointer[NUM_RESERVED_FUNCS] reservedFuncs;
}

struct _DGAFunctionRec {
    Bool function(ScrnInfoPtr pScrn, char** name, ubyte** mem, int* size, int* offset, int* extra) @nogc nothrow OpenFramebuffer;
    void function(ScrnInfoPtr pScrn) @nogc nothrow CloseFramebuffer;
    Bool function(ScrnInfoPtr pScrn, DGAModePtr pMode) @nogc nothrow SetMode;
    void function(ScrnInfoPtr pScrn, int x, int y, int flags) @nogc nothrow SetViewport;
    int function(ScrnInfoPtr pScrn) @nogc nothrow GetViewport;
    void function(ScrnInfoPtr) @nogc nothrow Sync;
    void function(ScrnInfoPtr pScrn, int x, int y, int w, int h, c_ulong color) @nogc nothrow FillRect;
    void function(ScrnInfoPtr pScrn, int srcx, int srcy, int w, int h, int dstx, int dsty) @nogc nothrow BlitRect;
    void function(ScrnInfoPtr pScrn, int srcx, int srcy, int w, int h, int dstx, int dsty, c_ulong color) @nogc nothrow BlitTransRect;
}alias DGAFunctionRec = _DGAFunctionRec;
alias DGAFunctionPtr = DGAFunctionRec*;

struct _SymTabRec {
    int token;                  /* id of the token */
    const(char)* name;           /* token name */
}alias SymTabRec = _SymTabRec;
alias SymTabPtr = _SymTabRec*;

/* flags for xf86LookupMode */
enum LookupModeFlags {
    LOOKUP_DEFAULT = 0,         /* Use default mode lookup method */
    LOOKUP_BEST_REFRESH,        /* Pick modes with best refresh */
    LOOKUP_CLOSEST_CLOCK,       /* Pick modes with the closest clock */
    LOOKUP_LIST_ORDER,          /* Pick first useful mode in list */
    LOOKUP_CLKDIV2 = 0x0100,    /* Allow half clocks */
    LOOKUP_OPTIONAL_TOLERANCES = 0x0200 /* Allow missing hsync/vrefresh */
}
alias LOOKUP_DEFAULT = LookupModeFlags.LOOKUP_DEFAULT;
alias LOOKUP_BEST_REFRESH = LookupModeFlags.LOOKUP_BEST_REFRESH;
alias LOOKUP_CLOSEST_CLOCK = LookupModeFlags.LOOKUP_CLOSEST_CLOCK;
alias LOOKUP_LIST_ORDER = LookupModeFlags.LOOKUP_LIST_ORDER;
alias LOOKUP_CLKDIV2 = LookupModeFlags.LOOKUP_CLKDIV2;
alias LOOKUP_OPTIONAL_TOLERANCES = LookupModeFlags.LOOKUP_OPTIONAL_TOLERANCES;


enum NoDepth24Support =	0x00;
enum Support24bppFb =		0x01    /* 24bpp framebuffer supported */;
enum Support32bppFb =		0x02    /* 32bpp framebuffer supported */;
enum SupportConvert24to32 =	0x04    /* Can convert 24bpp pixmap to 32bpp */;
enum SupportConvert32to24 =	0x08    /* Can convert 32bpp pixmap to 24bpp */;
enum PreferConvert24to32 =	0x10    /* prefer 24bpp pixmap to 32bpp conv */;
enum PreferConvert32to24 =	0x20    /* prefer 32bpp pixmap to 24bpp conv */;

/* For DPMS */
alias DPMSSetProcPtr = void function(ScrnInfoPtr, int, int);

/* Input handler proc */
alias InputHandlerProc = void function(int fd, void* data);

/* These are used by xf86GetClocks */
enum CLK_REG_SAVE =		-1;
enum CLK_REG_RESTORE =		-2;

/*
 * misc constants
 */
enum INTERLACE_REFRESH_WEIGHT =	1.5;
enum SYNC_TOLERANCE =		0.01    /* 1 percent */;
enum CLOCK_TOLERANCE =		2000    /* Clock matching tolerance (2MHz) */;

enum OVERLAY_8_32_DUALFB =	0x00000001;
enum OVERLAY_8_24_DUALFB =	0x00000002;
enum OVERLAY_8_16_DUALFB =	0x00000004;
enum OVERLAY_8_32_PLANAR =	0x00000008;

/* Values of xf86Info.mouseFlags */
enum MF_CLEAR_DTR =       1;
enum MF_CLEAR_RTS =       2;

                          /* _XF86STR_H */
