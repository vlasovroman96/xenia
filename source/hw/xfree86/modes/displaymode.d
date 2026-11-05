module hw.xfree86.modes.displaymode;
@nogc nothrow:
extern(C): __gshared:
 
public import dix.scrnintstr;

enum MAXCLOCKS =   128;

/* These are possible return values for xf86CheckMode() and ValidMode() */
enum ModeStatus {
    MODE_OK = 0,                /* Mode OK */
    MODE_HSYNC,                 /* hsync out of range */
    MODE_VSYNC,                 /* vsync out of range */
    MODE_H_ILLEGAL,             /* mode has illegal horizontal timings */
    MODE_V_ILLEGAL,             /* mode has illegal horizontal timings */
    MODE_BAD_WIDTH,             /* requires an unsupported linepitch */
    MODE_NOMODE,                /* no mode with a matching name */
    MODE_NO_INTERLACE,          /* interlaced mode not supported */
    MODE_NO_DBLESCAN,           /* doublescan mode not supported */
    MODE_NO_VSCAN,              /* multiscan mode not supported */
    MODE_MEM,                   /* insufficient video memory */
    MODE_VIRTUAL_X,             /* mode width too large for specified virtual size */
    MODE_VIRTUAL_Y,             /* mode height too large for specified virtual size */
    MODE_MEM_VIRT,              /* insufficient video memory given virtual size */
    MODE_NOCLOCK,               /* no fixed clock available */
    MODE_CLOCK_HIGH,            /* clock required is too high */
    MODE_CLOCK_LOW,             /* clock required is too low */
    MODE_CLOCK_RANGE,           /* clock/mode isn't in a ClockRange */
    MODE_BAD_HVALUE,            /* horizontal timing was out of range */
    MODE_BAD_VVALUE,            /* vertical timing was out of range */
    MODE_BAD_VSCAN,             /* VScan value out of range */
    MODE_HSYNC_NARROW,          /* horizontal sync too narrow */
    MODE_HSYNC_WIDE,            /* horizontal sync too wide */
    MODE_HBLANK_NARROW,         /* horizontal blanking too narrow */
    MODE_HBLANK_WIDE,           /* horizontal blanking too wide */
    MODE_VSYNC_NARROW,          /* vertical sync too narrow */
    MODE_VSYNC_WIDE,            /* vertical sync too wide */
    MODE_VBLANK_NARROW,         /* vertical blanking too narrow */
    MODE_VBLANK_WIDE,           /* vertical blanking too wide */
    MODE_PANEL,                 /* exceeds panel dimensions */
    MODE_INTERLACE_WIDTH,       /* width too large for interlaced mode */
    MODE_ONE_WIDTH,             /* only one width is supported */
    MODE_ONE_HEIGHT,            /* only one height is supported */
    MODE_ONE_SIZE,              /* only one resolution is supported */
    MODE_NO_REDUCED,            /* monitor doesn't accept reduced blanking */
    MODE_BANDWIDTH,             /* mode requires too much memory bandwidth */
    MODE_DUPLICATE,             /* mode is duplicated */
    MODE_BAD = -2,              /* unspecified reason */
    MODE_ERROR = -1             /* error condition */
}
alias MODE_OK = ModeStatus.MODE_OK;
alias MODE_HSYNC = ModeStatus.MODE_HSYNC;
alias MODE_VSYNC = ModeStatus.MODE_VSYNC;
alias MODE_H_ILLEGAL = ModeStatus.MODE_H_ILLEGAL;
alias MODE_V_ILLEGAL = ModeStatus.MODE_V_ILLEGAL;
alias MODE_BAD_WIDTH = ModeStatus.MODE_BAD_WIDTH;
alias MODE_NOMODE = ModeStatus.MODE_NOMODE;
alias MODE_NO_INTERLACE = ModeStatus.MODE_NO_INTERLACE;
alias MODE_NO_DBLESCAN = ModeStatus.MODE_NO_DBLESCAN;
alias MODE_NO_VSCAN = ModeStatus.MODE_NO_VSCAN;
alias MODE_MEM = ModeStatus.MODE_MEM;
alias MODE_VIRTUAL_X = ModeStatus.MODE_VIRTUAL_X;
alias MODE_VIRTUAL_Y = ModeStatus.MODE_VIRTUAL_Y;
alias MODE_MEM_VIRT = ModeStatus.MODE_MEM_VIRT;
alias MODE_NOCLOCK = ModeStatus.MODE_NOCLOCK;
alias MODE_CLOCK_HIGH = ModeStatus.MODE_CLOCK_HIGH;
alias MODE_CLOCK_LOW = ModeStatus.MODE_CLOCK_LOW;
alias MODE_CLOCK_RANGE = ModeStatus.MODE_CLOCK_RANGE;
alias MODE_BAD_HVALUE = ModeStatus.MODE_BAD_HVALUE;
alias MODE_BAD_VVALUE = ModeStatus.MODE_BAD_VVALUE;
alias MODE_BAD_VSCAN = ModeStatus.MODE_BAD_VSCAN;
alias MODE_HSYNC_NARROW = ModeStatus.MODE_HSYNC_NARROW;
alias MODE_HSYNC_WIDE = ModeStatus.MODE_HSYNC_WIDE;
alias MODE_HBLANK_NARROW = ModeStatus.MODE_HBLANK_NARROW;
alias MODE_HBLANK_WIDE = ModeStatus.MODE_HBLANK_WIDE;
alias MODE_VSYNC_NARROW = ModeStatus.MODE_VSYNC_NARROW;
alias MODE_VSYNC_WIDE = ModeStatus.MODE_VSYNC_WIDE;
alias MODE_VBLANK_NARROW = ModeStatus.MODE_VBLANK_NARROW;
alias MODE_VBLANK_WIDE = ModeStatus.MODE_VBLANK_WIDE;
alias MODE_PANEL = ModeStatus.MODE_PANEL;
alias MODE_INTERLACE_WIDTH = ModeStatus.MODE_INTERLACE_WIDTH;
alias MODE_ONE_WIDTH = ModeStatus.MODE_ONE_WIDTH;
alias MODE_ONE_HEIGHT = ModeStatus.MODE_ONE_HEIGHT;
alias MODE_ONE_SIZE = ModeStatus.MODE_ONE_SIZE;
alias MODE_NO_REDUCED = ModeStatus.MODE_NO_REDUCED;
alias MODE_BANDWIDTH = ModeStatus.MODE_BANDWIDTH;
alias MODE_DUPLICATE = ModeStatus.MODE_DUPLICATE;
alias MODE_BAD = ModeStatus.MODE_BAD;
alias MODE_ERROR = ModeStatus.MODE_ERROR;


/* Video mode */
struct _DisplayModeRec {
    _DisplayModeRec* prev;
    _DisplayModeRec* next;
    const(char)* name;           /* identifier for the mode */
    ModeStatus status;
    int type;

    /* These are the values that the user sees/provides */
    int Clock;                  /* pixel clock freq (kHz) */
    int HDisplay;               /* horizontal timing */
    int HSyncStart;
    int HSyncEnd;
    int HTotal;
    int HSkew;
    int VDisplay;               /* vertical timing */
    int VSyncStart;
    int VSyncEnd;
    int VTotal;
    int VScan;
    int Flags;

    /* These are the values the hardware uses */
    int ClockIndex;
    int SynthClock;             /* Actual clock freq to
                                 * be programmed  (kHz) */
    int CrtcHDisplay;
    int CrtcHBlankStart;
    int CrtcHSyncStart;
    int CrtcHSyncEnd;
    int CrtcHBlankEnd;
    int CrtcHTotal;
    int CrtcHSkew;
    int CrtcVDisplay;
    int CrtcVBlankStart;
    int CrtcVSyncStart;
    int CrtcVSyncEnd;
    int CrtcVBlankEnd;
    int CrtcVTotal;
    Bool CrtcHAdjusted;
    Bool CrtcVAdjusted;
    int PrivSize;
    INT32* Private;
    int PrivFlags;

    float HSync = 0, VRefresh = 0;
}alias DisplayModeRec = _DisplayModeRec;
alias DisplayModePtr = _DisplayModeRec*;


