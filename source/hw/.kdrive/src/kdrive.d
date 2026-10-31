module hw.kdrive.src.kdrive;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1999 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;

import core.stdc.stdio;

import config.hotplug_priv;
import dix.dix_priv;
import dix.screenint_priv;
import dix.settings_priv;
import mi.mi_priv;
import os.cmdline;
import os.ddx_priv;
import os.osdep;

import hw.kdrive.src.kdrive;
import include.dixstruct;
import include.privates;

/* workaround for <windows.h> being included somewhere and conflicting with us */
static if(RANDR){
import include.randrstr;
}
import include.glx_extinit;

version (XV) {
import hw.kdrive.src.kxv; 
}

import build.xlibre_server;

static if(DPMSExtension) {
import Xext.dpmsproc;
}

version (HAVE_EXECINFO_H) {
import execinfo;
}


enum KD_MAX_BUTTON =  32;

enum KD_KEYBOARD = 1;
enum KD_MOUSE = 2;
enum KD_TOUCHSCREEN = 3;

enum KD_MAX_PSEUDO_DEPTH = 8;
enum KD_MAX_PSEUDO_SIZE =     (1 << KD_MAX_PSEUDO_DEPTH);

struct KdPrivScreenRec {
    KdScreenInfo *screen;
    KdCardInfo *card;

    Bool enabled;
    Bool closed;
    int bytesPerPixel;

    int dpmsState;

    ColormapPtr pInstalledmap;  /* current colormap */
    xColorItem[KD_MAX_PSEUDO_SIZE] systemPalette;       /* saved windows colors */

    CreateScreenResourcesProcPtr CreateScreenResources;
    CloseScreenProcPtr CloseScreen;
} 

alias KdPrivScreenPtr = KdPrivScreenRec*;

alias Status = int;
struct _KdCardFuncs {
    Bool function(KdCardInfo *) cardinit;    /* detect and map device */
    Bool function(KdScreenInfo *) scrinit;   /* initialize screen information */
    Bool function(ScreenPtr) initScreen;     /* initialize ScreenRec */
    Bool function(ScreenPtr pScreen) finishInitScreen;
    Bool function(ScreenPtr) createRes;      /* create screen resources */
    void function(KdCardInfo *) preserve;    /* save graphics card state */
    Bool function(ScreenPtr) enable; /* set up for rendering */
    Bool function(ScreenPtr, int) dpms;      /* set DPMS screen saver */
    void function(ScreenPtr) disable;        /* turn off rendering */
    void function(KdCardInfo *) restore;     /* restore graphics card state */
    void function(KdScreenInfo *) scrfini;   /* close down screen */
    void function(KdCardInfo *) cardfini;    /* close down */

    Bool function(ScreenPtr) initCursor;     /* detect and map cursor */
    void function(ScreenPtr) enableCursor;   /* enable cursor */
    void function(ScreenPtr) disableCursor;  /* disable cursor */
    void function(ScreenPtr) finiCursor;     /* close down */
    void function(ScreenPtr, int, xColorItem *) recolorCursor;

    Bool function(ScreenPtr) initAccel;
    void function(ScreenPtr) enableAccel;
    void function(ScreenPtr) disableAccel;
    void function(ScreenPtr) finiAccel;

    void function(ScreenPtr, int, xColorItem *) getColors;
    void function(ScreenPtr, int, xColorItem *) putColors;

    void function(ScreenPtr) closeScreen;    /* close ScreenRec */
} 

alias _KdSyncPolarity = int;

enum : _KdSyncPolarity {
    KdSyncNegative, KdSyncPositive
} 

struct _KdPointerMatrix {
    int[3][2] matrix;
} 
alias KdPointerMatrix = _KdPointerMatrix;
;


alias KdSyncPolarity = _KdSyncPolarity;

struct _KdMonitorTiming {
    /* label */
    int horizontal;
    int vertical;
    int rate;
    /* pixel clock */
    int clock;                  /* in KHz */
    /* horizontal timing */
    int hfp;                    /* front porch */
    int hbp;                    /* back porch */
    int hblank;                 /* blanking */
    KdSyncPolarity hpol;        /* polarity */
    /* vertical timing */
    int vfp;                    /* front porch */
    int vbp;                    /* back porch */
    int vblank;                 /* blanking */
    KdSyncPolarity vpol;        /* polarity */
} 

alias KdMonitorTiming = _KdMonitorTiming;

alias KdCardFuncs = _KdCardFuncs;

/* This stub can be safely removed once we can
 * split input and GPU parts in hotplug.h et al. */
import hw.xfree86.os_support.linux.systemd_logind;

struct _KdCardInfo {
    _KdCardFuncs *cfuncs;
    void *closure;
    void *driver;
    _KdScreenInfo *screenList;
    int selected;
    int mynum;
    _KdCardInfo *next;
}

struct _KdPointerDriver {
    const char *name;
    Status function (KdPointerInfo *) Init;
    Status function (KdPointerInfo *) Enable;
    void  function (KdPointerInfo *) Disable;
    void  function (KdPointerInfo *) Fini;
    _KdPointerDriver *next;
} 

alias KdPointerDriver = _KdPointerDriver;

struct _KdKeyboardDriver {
    const char *name;
    Bool function(KdKeyboardInfo *) PreInit;
    Bool function(KdKeyboardInfo *) Init;
    Bool function(KdKeyboardInfo *)Enable;
    void function(KdKeyboardInfo *, int)Leds;
    void function(KdKeyboardInfo *, int, int, int)Bell;
    void function(KdKeyboardInfo *)Disable;
    void function(KdKeyboardInfo *)Fini;
    _KdKeyboardDriver *next;
} 
alias KdKeyboardDriver = _KdKeyboardDriver;


struct _KdKeyboardInfo {
    _KdKeyboardInfo *next;
    DeviceIntPtr dixdev;
    void *closure;
    char *name;
    char *path;
    int inputClass;
    char *xkbRules;
    char *xkbModel;
    char *xkbLayout;
    char *xkbVariant;
    char *xkbOptions;
    int LockLed;

    int minScanCode;
    int maxScanCode;

    int leds;
    int bellPitch;
    int bellDuration;
    InputOption *options;

    KdKeyboardDriver *driver;
    void *driverPrivate;
};

alias KdKeyboardInfo = _KdKeyboardInfo;

alias KdPointerState = int; 

enum : KdPointerState{
    start,
    button_1_pend,
    button_1_down,
    button_2_down,
    button_3_pend,
    button_3_down,
    synth_2_down_13,
    synth_2_down_3,
    synth_2_down_1,
    num_input_states
} ;

struct _KdScreenInfo {
    _KdScreenInfo *next;
    KdCardInfo *card;
    ScreenPtr pScreen;
    void *driver;
    Rotation randr;             /* rotation and reflection */
    int x;
    int y;
    int width;
    int height;
    int rate;
    int width_mm;
    int height_mm;
    int subpixel_order;
    Bool dumb;
    Bool softCursor;
    int mynum;
    xPoint origin;
    KdFrameBuffer fb;
} 
alias KdScreenInfo = _KdScreenInfo;

struct _KdPointerInfo {
    DeviceIntPtr dixdev;
    char *name;
    char *path;
    char *protocol;
    InputOption *options;
    int inputClass;

    CARD8[KD_MAX_BUTTON + 1] map;
    int nButtons;
    int nAxes;

    Bool emulateMiddleButton;
    ulong emulationTimeout;
    int emulationDx, emulationDy;

    Bool timeoutPending;
    KdPointerState mouseState;
    Bool eventHeld;
    struct _heldEvent{
        int type;
        int x;
        int y;
        int z;
        int flags;
        int absrel;
    } ;
    _heldEvent heldEvent;
    ubyte buttonState;
    Bool transformCoordinates;
    int pressureThreshold;

    KdPointerDriver *driver;
    void *driverPrivate;

    _KdPointerInfo *next;
};

alias KdPointerInfo = _KdPointerInfo;

alias KdCardInfo = _KdCardInfo;

struct _KdOsFuncs {
    int function() Init;           /* only called when the X server is started */
    void function() Enable;        /* called when screen is enabled */
    void function() Disable;       /* called when screen is disabled */
    Bool function(KeySym) SpecialKey;
    void function() Fini;
    void function() pollEvents;    /* called when driver shall poll for new events */
    void function(int, int, int) Bell; /* if not NULL called instead of the keyboard driver's function */
}
alias KdOsFuncs = _KdOsFuncs;

struct KdDepths {
    CARD8 depth;
    CARD8 bpp;
}

KdDepths[7] kdDepths = [
    {1, 1},
    {4, 4},
    {8, 8},
    {15, 16},
    {16, 16},
    {24, 32},
    {32, 32}
];

enum KD_DEFAULT_BUTTONS = 5;


enum RR_Rotate_All =	(RR_Rotate_0|RR_Rotate_90|RR_Rotate_180|RR_Rotate_270);
enum RR_Reflect_All =	(RR_Reflect_X|RR_Reflect_Y);

enum KD_BUTTON_1 =	0x01;
enum KD_BUTTON_2 =	0x02;
enum KD_BUTTON_3 =	0x04;
enum KD_BUTTON_4 =	0x08;
enum KD_BUTTON_5 =	0x10;
enum KD_BUTTON_8 =	0x80;
enum KD_POINTER_DESKTOP = 0x40000000;
enum KD_MOUSE_DELTA =	0x80000000;

enum string KdGetScreenPriv(string pScreen) =  `(cast(KdPrivScreenPtr) 
    dixLookupPrivate(&(`~pScreen~`).devPrivates, `~kdScreenPrivateKey~`))`;

enum string KdSetScreenPriv(string pScreen,string v) =`
    dixSetPrivate(&(`~pScreen~`).devPrivates, `~kdScreenPrivateKey~`, `~v~`)`;

enum string KdScreenPriv(string pScreen) = `KdPrivScreenPtr pScreenPriv = ` ~KdGetScreenPriv!(pScreen)~`;`;

DevPrivateKeyRec kdScreenPrivateKeyRec;
enum kdScreenPrivateKey = `(&kdScreenPrivateKeyRec)`;

Bool kdVideoTest;
c_ulong kdVideoTestTime;
Bool kdEmulateMiddleButton;
Bool kdRawPointerCoordinates;
Bool kdDisableZaphod;
Bool kdAllowZap = TRUE;
Bool kdEnabled;
int kdSubpixelOrder;
int kdVirtualTerminal = -1;
Bool kdSwitchPending;
char* kdSwitchCmd;
xPoint kdOrigin;
Bool kdHasPointer = FALSE;
Bool kdHasKbd = FALSE;
const(char)* kdGlobalXkbRules = null;
const(char)* kdGlobalXkbModel = null;
const(char)* kdGlobalXkbLayout = null;
const(char)* kdGlobalXkbVariant = null;
const(char)* kdGlobalXkbOptions = null;

private Bool kdCaughtSignal = FALSE;

/*
 * Carry arguments from InitOutput through driver initialization
 * to KdScreenInit
 */
const(KdOsFuncs)* kdOsFuncs = null;

void KdDisableScreen(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));

    if (!pScreenPriv.enabled)
        return;
    if (!pScreenPriv.closed)
        SetRootClip(pScreen, ROOT_CLIP_NONE);
    KdDisableColormap(pScreen);
    if (!pScreenPriv.screen.dumb && pScreenPriv.card.cfuncs.disableAccel)
        (*pScreenPriv.card.cfuncs.disableAccel) (pScreen);
    if (!pScreenPriv.screen.softCursor &&
        pScreenPriv.card.cfuncs.disableCursor)
        (*pScreenPriv.card.cfuncs.disableCursor) (pScreen);
    if (pScreenPriv.card.cfuncs.dpms)
        (*pScreenPriv.card.cfuncs.dpms) (pScreen, KD_DPMS_NORMAL);
    pScreenPriv.enabled = FALSE;
    if (pScreenPriv.card.cfuncs.disable)
        (*pScreenPriv.card.cfuncs.disable) (pScreen);
}

private void KdDoSwitchCmd(const(char)* reason)
{
    if (kdSwitchCmd) {
        char* command = void;
        int ret = void;

        if (asprintf(&command, "%s %s", kdSwitchCmd, reason) == -1)
            return;

        /* Ignore the return value from system; I'm not sure
         * there's anything more useful to be done when
         * it fails
         */
        ret = system(command);
        cast(void) ret;
        free(command);
    }
}

void KdSuspend(int ddxAbort)
{
    KdCardInfo* card = void;
    KdScreenInfo* screen = void;

    if (kdEnabled) {
        for (card = kdCardInfo; card; card = card.next) {
            for (screen = card.screenList; screen; screen = screen.next)
                if (screen.mynum == card.selected && screen.pScreen)
                    KdDisableScreen(screen.pScreen);
            if (card.driver && card.cfuncs.restore)
                (*card.cfuncs.restore) (card);
        }
        if (!ddxAbort) {
            KdDisableInput();
        }
        KdDoSwitchCmd("suspend");
    }
}

void KdDisableScreens(int ddxAbort)
{
    KdSuspend(ddxAbort);
    if (kdEnabled && (kdOsFuncs.Disable))
        kdOsFuncs.Disable();
    kdEnabled = FALSE;
}

Bool KdEnableScreen(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));

    if (pScreenPriv.enabled)
        return TRUE;
    if (pScreenPriv.card.cfuncs.enable)
        if (!(*pScreenPriv.card.cfuncs.enable) (pScreen))
            return FALSE;
    pScreenPriv.enabled = TRUE;
    pScreenPriv.dpmsState = KD_DPMS_NORMAL;
    pScreenPriv.card.selected = pScreenPriv.screen.mynum;
    if (!pScreenPriv.screen.softCursor &&
        pScreenPriv.card.cfuncs.enableCursor)
        (*pScreenPriv.card.cfuncs.enableCursor) (pScreen);
    if (!pScreenPriv.screen.dumb && pScreenPriv.card.cfuncs.enableAccel)
        (*pScreenPriv.card.cfuncs.enableAccel) (pScreen);
    KdEnableColormap(pScreen);
    SetRootClip(pScreen, ROOT_CLIP_FULL);
    if (pScreenPriv.card.cfuncs.dpms)
        (*pScreenPriv.card.cfuncs.dpms) (pScreen, pScreenPriv.dpmsState);
    return TRUE;
}

void KdResume()
{
    KdCardInfo* card = void;
    KdScreenInfo* screen = void;

    if (kdEnabled) {
        KdDoSwitchCmd("resume");
        for (card = kdCardInfo; card; card = card.next) {
            if (card.cfuncs.preserve)
                (*card.cfuncs.preserve) (card);
            for (screen = card.screenList; screen; screen = screen.next)
                if (screen.mynum == card.selected && screen.pScreen)
                    KdEnableScreen(screen.pScreen);
        }
        KdEnableInput();
        KdReleaseAllKeys();
    }
}

void KdEnableScreens()
{
    if (!kdEnabled) {
        kdEnabled = TRUE;
        if (kdOsFuncs.Enable)
            (*kdOsFuncs.Enable) ();
    }
    KdResume();
}

void KdProcessSwitch()
{
    if (kdEnabled)
        KdDisableScreens(FALSE);
    else
        KdEnableScreens();
}

private void AbortDDX(ExitCode error)
{
    KdDisableScreens(TRUE);
    if (kdOsFuncs) {
        if (kdEnabled && kdOsFuncs.Disable)
            (*kdOsFuncs.Disable) ();
        if (kdOsFuncs.Fini)
            (*kdOsFuncs.Fini) ();
        KdDoSwitchCmd("stop");
    }

    if (kdCaughtSignal)
        OsAbort();
}

void ddxGiveUp(ExitCode error)
{
    AbortDDX(error);
}

Bool kdDumbDriver;
Bool kdSoftCursor;

const(char)* KdParseFindNext(const(char)* cur, const(char)* delim, char* save, char* last)
{
    while (*cur && !strchr(delim, *cur)) {
        *save++ = *cur++;
    }
    *save = 0;
    *last = *cur;
    if (*cur)
        cur++;
    return cur;
}

Rotation KdAddRotation(Rotation a, Rotation b)
{
    Rotation rotate = (a & RR_Rotate_All) * (b & RR_Rotate_All);
    Rotation reflect = (a & RR_Reflect_All) ^ (b & RR_Reflect_All);

    if (rotate > RR_Rotate_270)
        rotate /= (RR_Rotate_270 * RR_Rotate_90);
    return reflect | rotate;
}

Rotation KdSubRotation(Rotation a, Rotation b)
{
    Rotation rotate = (a & RR_Rotate_All) * 16 / (b & RR_Rotate_All);
    Rotation reflect = (a & RR_Reflect_All) ^ (b & RR_Reflect_All);

    if (rotate > RR_Rotate_270)
        rotate /= (RR_Rotate_270 * RR_Rotate_90);
    return reflect | rotate;
}



struct _KdFrameBuffer {
    CARD8 *frameBuffer;
    int depth;
    int bitsPerPixel;
    int pixelStride;
    int byteStride;
    Bool shadow;
    ulong visuals;
    Pixel redMask, greenMask, blueMask;
    void *closure;
}
alias KdFrameBuffer = _KdFrameBuffer;


void KdParseScreen(KdScreenInfo* screen, const(char)* arg)
{
    char delim = void;
    char[1024] save = void;
    int i = void;
    int pixels = void, mm = void;

    screen.dumb = kdDumbDriver;
    screen.softCursor = kdSoftCursor;
    screen.origin = kdOrigin;
    screen.randr = RR_Rotate_0;
    screen.x = 0;
    screen.y = 0;
    screen.width = 0;
    screen.height = 0;
    screen.width_mm = 0;
    screen.height_mm = 0;
    screen.subpixel_order = kdSubpixelOrder;
    screen.rate = 0;
    screen.fb.depth = 0;
    if (!arg)
        return;
    if (strlen(arg) >= save.sizeof)
        return;

    for (i = 0; i < 2; i++) {
        arg = KdParseFindNext(arg, "x/+@XY", save.ptr, &delim);
        if (!save[0])
            return;

        pixels = atoi(save.ptr);
        mm = 0;

        if (delim == '/') {
            arg = KdParseFindNext(arg, "x+@XY", save.ptr, &delim);
            if (!save[0])
                return;
            mm = atoi(save.ptr);
        }

        if (i == 0) {
            screen.width = pixels;
            screen.width_mm = mm;
        }
        else {
            screen.height = pixels;
            screen.height_mm = mm;
        }
        if (delim != 'x' && delim != '+' && delim != '@' &&
            delim != 'X' && delim != 'Y' &&
            (delim != '\0' || i == 0))
            return;
    }

    kdOrigin.x += screen.width;
    kdOrigin.y = 0;
    kdDumbDriver = FALSE;
    kdSoftCursor = FALSE;
    kdSubpixelOrder = SubPixelUnknown;

    if (delim == '+') {
        arg = KdParseFindNext(arg, "+@xXY", save.ptr, &delim);
        if (save[0])
            screen.x = atoi(save.ptr);
    }

    if (delim == '+') {
        arg = KdParseFindNext(arg, "@xXY", save.ptr, &delim);
        if (save[0])
            screen.y = atoi(save.ptr);
    }

    if (delim == '@') {
        arg = KdParseFindNext(arg, "xXY", save.ptr, &delim);
        if (save[0]) {
            int rotate = atoi(save.ptr);

            if (rotate < 45)
                screen.randr = RR_Rotate_0;
            else if (rotate < 135)
                screen.randr = RR_Rotate_90;
            else if (rotate < 225)
                screen.randr = RR_Rotate_180;
            else if (rotate < 315)
                screen.randr = RR_Rotate_270;
            else
                screen.randr = RR_Rotate_0;
        }
    }
    if (delim == 'X') {
        arg = KdParseFindNext(arg, "xY", save.ptr, &delim);
        screen.randr |= RR_Reflect_X;
    }

    if (delim == 'Y') {
        arg = KdParseFindNext(arg, "xY", save.ptr, &delim);
        screen.randr |= RR_Reflect_Y;
    }

    arg = KdParseFindNext(arg, "x/,", save.ptr, &delim);
    if (save[0]) {
        screen.fb.depth = atoi(save.ptr);
        if (delim == '/') {
            arg = KdParseFindNext(arg, "x,", save.ptr, &delim);
            if (save[0])
                screen.fb.bitsPerPixel = atoi(save.ptr);
        }
        else
            screen.fb.bitsPerPixel = 0;
    }

    if (delim == 'x') {
        arg = KdParseFindNext(arg, "x", save.ptr, &delim);
        if (save[0])
            screen.rate = atoi(save.ptr);
    }
}

void KdParseRgba(char* rgba)
{
    if (!strcmp(rgba, "rgb"))
        kdSubpixelOrder = SubPixelHorizontalRGB;
    else if (!strcmp(rgba, "bgr"))
        kdSubpixelOrder = SubPixelHorizontalBGR;
    else if (!strcmp(rgba, "vrgb"))
        kdSubpixelOrder = SubPixelVerticalRGB;
    else if (!strcmp(rgba, "vbgr"))
        kdSubpixelOrder = SubPixelVerticalBGR;
    else if (!strcmp(rgba, "none"))
        kdSubpixelOrder = SubPixelNone;
    else
        kdSubpixelOrder = SubPixelUnknown;
}

void KdUseMsg()
{
    ErrorF("\nTinyX Device Dependent Usage:\n");
    ErrorF
        ("-screen WIDTH[/WIDTHMM]xHEIGHT[/HEIGHTMM][+[-]XOFFSET][+[-]YOFFSET][@ROTATION][X][Y][xDEPTH/BPP[xFREQ]]  Specify screen characteristics\n");
    ErrorF
        ("-rgba rgb/bgr/vrgb/vbgr/none   Specify subpixel ordering for LCD panels\n");
    ErrorF
        ("-mouse driver [,n,options]    Specify the pointer driver and its options (n is the number of buttons)\n");
    ErrorF
        ("-keybd driver [,,options]      Specify the keyboard driver and its options\n");
    ErrorF("-xkb-rules       Set default XkbRules value (can be overridden by -keybd options)\n");
    ErrorF("-xkb-model       Set default XkbModel value (can be overridden by -keybd options)\n");
    ErrorF("-xkb-layout      Set default XkbLayout value (can be overridden by -keybd options)\n");
    ErrorF("-xkb-variant     Set default XkbVariant value (can be overridden by -keybd options)\n");
    ErrorF("-xkb-options     Set default XkbOptions value (can be overridden by -keybd options)\n");
    ErrorF("-zaphod          Disable cursor screen switching\n");
    ErrorF("-2button         Emulate 3 button mouse\n");
    ErrorF("-3button         Disable 3 button mouse emulation\n");
    ErrorF
        ("-rawcoord        Don't transform pointer coordinates on rotation\n");
    ErrorF("-dumb            Disable hardware acceleration\n");
    ErrorF("-softCursor      Force software cursor\n");
    ErrorF("-videoTest       Start the server, pause momentarily and exit\n");
    ErrorF
        ("-origin X,Y      Locates the next screen in the virtual screen (Xinerama)\n");
    ErrorF("-switchCmd       Command to execute on vt switch\n");
    ErrorF("-nozap           Don't terminate server on Ctrl+Alt+Backspace\n");
    ErrorF
        ("vtxx             Use virtual terminal xx instead of the next available\n");
}

int KdProcessArgument(int argc, char** argv, int i)
{
    KdCardInfo* card = void;
    KdScreenInfo* screen = void;

    if (!strcmp(argv[i], "-screen")) {
        char* screen_arg = ((i + 1) < argc && argv[i + 1][0] != '-') ? argv[i + 1] : null;
        card = KdCardInfoLast();
        if (!card) {
            InitCard(0);
            card = KdCardInfoLast();
        }
        if (card) {
            screen = KdScreenInfoAdd(card);
            KdParseScreen(screen, screen_arg);
        } else {
            ErrorF("No matching card found!\n");
        }
        return screen_arg ? 2 : 1;
    }
    if (!strcmp(argv[i], "-zaphod")) {
        kdDisableZaphod = TRUE;
        return 1;
    }

    /* Kept for Compatibility */
    if (!strcmp(argv[i], "-zap")) {
        kdAllowZap = TRUE;
        return 1;
    }

    if (!strcmp(argv[i], "-nozap")) {
        kdAllowZap = FALSE;
        return 1;
    }

    if (!strcmp(argv[i], "-3button")) {
        kdEmulateMiddleButton = FALSE;
        return 1;
    }
    if (!strcmp(argv[i], "-2button")) {
        kdEmulateMiddleButton = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-rawcoord")) {
        kdRawPointerCoordinates = 1;
        return 1;
    }
    if (!strcmp(argv[i], "-dumb")) {
        kdDumbDriver = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-softCursor")) {
        kdSoftCursor = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-videoTest")) {
        kdVideoTest = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-origin")) {
        if ((i + 1) < argc) {
            char* x = argv[i + 1];
            char* y = strchr(x, ',');

            if (x)
                kdOrigin.x = atoi(x);
            else
                kdOrigin.x = 0;
            if (y)
                kdOrigin.y = atoi(y + 1);
            else
                kdOrigin.y = 0;
        }
        else
            UseMsg();
        return 2;
    }
    if (!strcmp(argv[i], "-rgba")) {
        if ((i + 1) < argc)
            KdParseRgba(argv[i + 1]);
        else
            UseMsg();
        return 2;
    }
    if (!strcmp(argv[i], "-switchCmd")) {
        if ((i + 1) < argc)
            kdSwitchCmd = argv[i + 1];
        else
            UseMsg();
        return 2;
    }
    if (!strncmp(argv[i], "vt", 2) &&
        sscanf(argv[i], "vt%2d", &kdVirtualTerminal) == 1) {
        return 1;
    }
    if (!strcmp(argv[i], "-xkb-rules")) {
        if (i + 1 >= argc) {
            UseMsg();
            FatalError("Missing argument for option -xkb-rules.\n");
        }
        kdGlobalXkbRules = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-xkb-model")) {
        if (i + 1 >= argc) {
            UseMsg();
            FatalError("Missing argument for option -xkb-model.\n");
        }
        kdGlobalXkbModel = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-xkb-layout")) {
        if (i + 1 >= argc) {
            UseMsg();
            FatalError("Missing argument for option -xkb-layout.\n");
        }
        kdGlobalXkbLayout = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-xkb-variant")) {
        if (i + 1 >= argc) {
            UseMsg();
            FatalError("Missing argument for option -xkb-variant.\n");
        }
        kdGlobalXkbVariant = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-xkb-options")) {
        if (i + 1 >= argc) {
            UseMsg();
            FatalError("Missing argument for option -xkb-options.\n");
        }
        kdGlobalXkbOptions = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-mouse") || !strcmp(argv[i], "-pointer")) {
        if (i + 1 >= argc)
            UseMsg();
        KdAddConfigPointer(argv[i + 1]);
        kdHasPointer = TRUE;
        return 2;
    }
    if (!strcmp(argv[i], "-keybd")) {
        if (i + 1 >= argc)
            UseMsg();
        KdAddConfigKeyboard(argv[i + 1]);
        kdHasKbd = TRUE;
        return 2;
    }

    return 0;
}

void KdOsInit(const(KdOsFuncs)* pOsFuncs)
{
    kdOsFuncs = pOsFuncs;
    if (pOsFuncs) {
        KdDoSwitchCmd("start");
        if (pOsFuncs.Init)
            (*pOsFuncs.Init) ();
    }
}

private bool KdAllocatePrivates(ScreenPtr pScreen)
{
    KdPrivScreenPtr pScreenPriv = void;

    if (!dixRegisterPrivateKey(&kdScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return false;

    pScreenPriv = calloc(1, typeof(*pScreenPriv).sizeof);
    if (!pScreenPriv)
        return false;
    KdSetScreenPriv(pScreen, pScreenPriv);
    return true;
}

Bool KdCreateScreenResources(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdCardInfo* card = pScreenPriv.card;

    if (!miCreateScreenResources(pScreen))
        return FALSE;

    if (card.cfuncs.createRes)
        return card.cfuncs.createRes(pScreen);

    return TRUE;
}

Bool KdCloseScreen(ScreenPtr pScreen)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    KdCardInfo* card = pScreenPriv.card;
    Bool ret = void;

    if (card.cfuncs.closeScreen)
        (*card.cfuncs.closeScreen)(pScreen);

    pScreenPriv.closed = TRUE;

    ret = fbCloseScreen(pScreen);

    if (pScreenPriv.dpmsState != KD_DPMS_NORMAL)
        (*card.cfuncs.dpms) (pScreen, KD_DPMS_NORMAL);

    if (screen.mynum == card.selected)
        KdDisableScreen(pScreen);

    /*
     * Restore video hardware when last screen is closed
     */
    if (screen == card.screenList) {
        if (kdEnabled && card.cfuncs.restore)
            (*card.cfuncs.restore) (card);
    }

    if (!pScreenPriv.screen.dumb && card.cfuncs.finiAccel)
        (*card.cfuncs.finiAccel) (pScreen);

    if (!pScreenPriv.screen.softCursor && card.cfuncs.finiCursor)
        (*card.cfuncs.finiCursor) (pScreen);

    if (card.cfuncs.scrfini)
        (*card.cfuncs.scrfini) (screen);

    /*
     * Clean up card when last screen is closed, DIX closes them in
     * reverse order, thus we check for when the first in the list is closed
     */
    if (screen == card.screenList) {
        if (card.cfuncs.cardfini)
            (*card.cfuncs.cardfini) (card);
        /*
         * Clean up OS when last card is closed
         */
        if (card == kdCardInfo) {
            if (kdEnabled && (kdOsFuncs.Disable))
                kdOsFuncs.Disable();
            kdEnabled = FALSE;
        }
    }

    pScreenPriv.screen.pScreen = 0;

    free(cast(void*) pScreenPriv);
    return ret;
}

Bool KdSaveScreen(ScreenPtr pScreen, int on)
{
    mixin(KdScreenPriv!("pScreen"));
    int dpmsState = void;

    if (!pScreenPriv.card.cfuncs.dpms)
        return FALSE;

    dpmsState = pScreenPriv.dpmsState;
    switch (on) {
    case SCREEN_SAVER_OFF:
        dpmsState = KD_DPMS_NORMAL;
        break;
    case SCREEN_SAVER_ON:
        if (dpmsState == KD_DPMS_NORMAL)
            dpmsState = KD_DPMS_NORMAL + 1;
        break;
    case SCREEN_SAVER_CYCLE:
        if (dpmsState < KD_DPMS_MAX)
            dpmsState++;
        break;
    case SCREEN_SAVER_FORCER:
        break;
    default: break;}
    if (dpmsState != pScreenPriv.dpmsState) {
        if (pScreenPriv.enabled)
            (*pScreenPriv.card.cfuncs.dpms) (pScreen, dpmsState);
        pScreenPriv.dpmsState = dpmsState;
    }
    return TRUE;
}

private Bool KdCreateWindow(WindowPtr pWin)
{
    if (!pWin.parent) {
        mixin(KdScreenPriv!("pWin.drawable.pScreen"));;

        if (!pScreenPriv.enabled) {
            RegionEmpty(&pWin.borderClip);
            RegionBreak(&pWin.clipList);
        }
    }
    return fbCreateWindow(pWin);
}

void KdSetSubpixelOrder(ScreenPtr pScreen, Rotation randr)
{
    mixin(KdScreenPriv!("pScreen"));
    KdScreenInfo* screen = pScreenPriv.screen;
    int subpixel_order = screen.subpixel_order;
    Rotation subpixel_dir = void;
    int i = void;

    struct _Orders {
        int subpixel_order = void;
        Rotation direction = void;
    }static _Orders[5] orders = [
        {SubPixelHorizontalRGB, RR_Rotate_0},
        {SubPixelHorizontalBGR, RR_Rotate_180},
        {SubPixelVerticalRGB, RR_Rotate_270},
        {SubPixelVerticalBGR, RR_Rotate_90},
    ];

    struct _Reflects {
        int bit = void;
        int normal = void;
        int reflect = void;
    }static _Reflects[5] reflects = [
        {RR_Reflect_X, SubPixelHorizontalRGB, SubPixelHorizontalBGR},
        {RR_Reflect_X, SubPixelHorizontalBGR, SubPixelHorizontalRGB},
        {RR_Reflect_Y, SubPixelVerticalRGB, SubPixelVerticalBGR},
        {RR_Reflect_Y, SubPixelVerticalRGB, SubPixelVerticalRGB},
    ];

    /* map subpixel to direction */
    for (i = 0; i < 4; i++)
        if (orders[i].subpixel_order == subpixel_order)
            break;
    if (i < 4) {
        subpixel_dir =
            KdAddRotation(randr & RR_Rotate_All, orders[i].direction);

        /* map back to subpixel order */
        for (i = 0; i < 4; i++)
            if (orders[i].direction & subpixel_dir) {
                subpixel_order = orders[i].subpixel_order;
                break;
            }
        /* reflect */
        for (i = 0; i < 4; i++)
            if ((randr & reflects[i].bit) &&
                reflects[i].normal == subpixel_order) {
                subpixel_order = reflects[i].reflect;
                break;
            }
    }
    PictureSetSubpixelOrder(pScreen, subpixel_order);
}

/* Pass through AddScreen, which doesn't take any closure */
private KdScreenInfo* kdCurrentScreen;

Bool KdScreenInit(ScreenPtr pScreen, int argc, char** argv)
{
    KdScreenInfo* screen = kdCurrentScreen;
    KdCardInfo* card = screen.card;
    KdPrivScreenPtr pScreenPriv = void;

    /*
     * note that screen->fb is set up for the nominal orientation
     * of the screen; that means if randr is rotated, the values
     * there should reflect a rotated frame buffer (or shadow).
     */
    Bool rotated = (screen.randr & (RR_Rotate_90 | RR_Rotate_270)) != 0;
    int width = void, height = void; int* width_mmp = void, height_mmp = void;

    if (!KdAllocatePrivates(pScreen))
        return FALSE;

    pScreenPriv = KdGetScreenPriv(pScreen);

    if (!rotated) {
        width = screen.width;
        height = screen.height;
        width_mmp = &screen.width_mm;
        height_mmp = &screen.height_mm;
    }
    else {
        width = screen.height;
        height = screen.width;
        width_mmp = &screen.height_mm;
        height_mmp = &screen.width_mm;
    }
    screen.pScreen = pScreen;
    pScreenPriv.screen = screen;
    pScreenPriv.card = card;
    pScreenPriv.bytesPerPixel = screen.fb.bitsPerPixel >> 3;
    pScreenPriv.dpmsState = KD_DPMS_NORMAL;
    pScreen.x = screen.origin.x;
    pScreen.y = screen.origin.y;

    if (!monitorResolution)
        monitorResolution = 75;
    /*
     * This is done in this order so that backing store wraps
     * our GC functions; fbFinishScreenInit initializes MI
     * backing store
     */
    if (!fbSetupScreen(pScreen,
                       screen.fb.frameBuffer,
                       width, height,
                       monitorResolution, monitorResolution,
                       screen.fb.pixelStride, screen.fb.bitsPerPixel)) {
        return FALSE;
    }

    /*
     * Set colormap functions
     */
    pScreen.InstallColormap = KdInstallColormap;
    pScreen.UninstallColormap = KdUninstallColormap;
    pScreen.ListInstalledColormaps = KdListInstalledColormaps;
    pScreen.StoreColors = KdStoreColors;

    pScreen.SaveScreen = KdSaveScreen;
    pScreen.CreateWindow = KdCreateWindow;

    if (!fbFinishScreenInit(pScreen,
                            screen.fb.frameBuffer,
                            width, height,
                            monitorResolution, monitorResolution,
                            screen.fb.pixelStride, screen.fb.bitsPerPixel)) {
        return FALSE;
    }

    /*
     * Fix screen sizes; for some reason mi takes dpi instead of mm.
     * Rounding errors are annoying
     */
    if (*width_mmp)
        pScreen.mmWidth = *width_mmp;
    else
        *width_mmp = pScreen.mmWidth;
    if (*height_mmp)
        pScreen.mmHeight = *height_mmp;
    else
        *height_mmp = pScreen.mmHeight;

    /*
     * Plug in our own block/wakeup handlers.
     * miScreenInit installs NoopDDA in both places
     */
    pScreen.BlockHandler = KdBlockHandler;
    pScreen.WakeupHandler = KdWakeupHandler;

    if (!fbPictureInit(pScreen, 0, 0))
        return FALSE;
    if (card.cfuncs.initScreen)
        if (!(*card.cfuncs.initScreen) (pScreen))
            return FALSE;

    if (!screen.dumb && card.cfuncs.initAccel)
        if (!(*card.cfuncs.initAccel) (pScreen))
            screen.dumb = TRUE;

    if (card.cfuncs.finishInitScreen)
        if (!(*card.cfuncs.finishInitScreen) (pScreen))
            return FALSE;

    pScreen.CloseScreen = KdCloseScreen;
    pScreen.CreateScreenResources = KdCreateScreenResources;

    if (screen.softCursor ||
        !card.cfuncs.initCursor || !(*card.cfuncs.initCursor) (pScreen)) {
        /* Use MI for cursor display and event queueing. */
        screen.softCursor = TRUE;
        miDCInitialize(pScreen, &kdPointerScreenFuncs);
    }

    if (!fbCreateDefColormap(pScreen)) {
        return FALSE;
    }

    KdSetSubpixelOrder(pScreen, screen.randr);

    /*
     * Enable the hardware
     */
    if ((!kdEnabled) && (kdOsFuncs.Enable))
        kdOsFuncs.Enable();
    kdEnabled = TRUE;

    if (screen.mynum == card.selected) {
        if (card.cfuncs.preserve)
            (*card.cfuncs.preserve) (card);
        if (card.cfuncs.enable)
            if (!(*card.cfuncs.enable) (pScreen))
                return FALSE;
        pScreenPriv.enabled = TRUE;
        if (!screen.softCursor && card.cfuncs.enableCursor)
            (*card.cfuncs.enableCursor) (pScreen);
        KdEnableColormap(pScreen);
        if (!screen.dumb && card.cfuncs.enableAccel)
            (*card.cfuncs.enableAccel) (pScreen);
    }

    return TRUE;
}

void KdInitScreen(KdScreenInfo* screen, int argc, char** argv)
{
    KdCardInfo* card = screen.card;

    if (!(*card.cfuncs.scrinit) (screen))
        FatalError("Screen initialization failed!\n");

    if (!card.cfuncs.initAccel)
        screen.dumb = TRUE;
    if (!card.cfuncs.initCursor)
        screen.softCursor = TRUE;
}

private Bool KdSetPixmapFormats()
{
    CARD8[33] depthToBpp = void;       /* depth -> bpp map */
    KdCardInfo* card = void;
    KdScreenInfo* screen = void;
    int i = void;
    int bpp = void;
    PixmapFormatRec* format = void;

    for (i = 1; i <= 32; i++)
        depthToBpp[i] = 0;

    /*
     * Generate mappings between bitsPerPixel and depth,
     * also ensure that all screens comply with protocol
     * restrictions on equivalent formats for the same
     * depth on different screens
     */
    for (card = kdCardInfo; card; card = card.next) {
        for (screen = card.screenList; screen; screen = screen.next) {
            bpp = screen.fb.bitsPerPixel;
            if (bpp == 24)
                bpp = 32;
            if (!depthToBpp[screen.fb.depth])
                depthToBpp[screen.fb.depth] = bpp;
            else if (depthToBpp[screen.fb.depth] != bpp)
                return FALSE;
        }
    }

    /*
     * Fill in additional formats
     */
    for (i = 0; i < kdDepths.length; i++)
        if (!depthToBpp[kdDepths[i].depth])
            depthToBpp[kdDepths[i].depth] = kdDepths[i].bpp;

    screenInfo.imageByteOrder = IMAGE_BYTE_ORDER;
    screenInfo.bitmapScanlineUnit = BITMAP_SCANLINE_UNIT;
    screenInfo.bitmapScanlinePad = BITMAP_SCANLINE_PAD;
    screenInfo.bitmapBitOrder = BITMAP_BIT_ORDER;
    screenInfo.numPixmapFormats = 0;

    for (i = 1; i <= 32; i++) {
        if (depthToBpp[i]) {
            format = &screenInfo.formats[screenInfo.numPixmapFormats++];
            format.depth = i;
            format.bitsPerPixel = depthToBpp[i];
            format.scanlinePad = BITMAP_SCANLINE_PAD;
        }
    }

    return TRUE;
}

private void KdAddScreen(KdScreenInfo* screen, int argc, char** argv)
{
    int i = void;

    /*
     * Fill in fb visual type masks for this screen
     */
    for (i = 0; i < screenInfo.numPixmapFormats; i++) {
        c_ulong visuals = void;
        Pixel rm = void, gm = void, bm = void;

        visuals = 0;
        rm = gm = bm = 0;
        if (screenInfo.formats[i].depth == screen.fb.depth) {
            visuals = screen.fb.visuals;
            rm = screen.fb.redMask;
            gm = screen.fb.greenMask;
            bm = screen.fb.blueMask;
        }
        fbSetVisualTypesAndMasks(screenInfo.formats[i].depth,
                                 visuals, 8, rm, gm, bm);
    }

    kdCurrentScreen = screen;

    AddScreen(&KdScreenInit, argc, argv);
}

version (none) {                           /* This function is not used currently */

int KdDepthToFb(ScreenPtr pScreen, int depth)
{
    mixin(KdScreenPriv!("pScreen"));

    for (fb = 0; fb <= KD_MAX_FB && pScreenPriv.screen.fb.frameBuffer; fb++)
        if (pScreenPriv.screen.fb.depth == depth)
            return fb;
}

}

private int KdSignalWrapper(int signum)
{
    kdCaughtSignal = TRUE;
    return 1;                   /* use generic OS layer cleanup & abort */
}

void KdInitOutput(int argc, char** argv)
{
    KdCardInfo* card = void;
    KdScreenInfo* screen = void;

    if (!kdCardInfo) {
        InitCard(0);
        if (((card = KdCardInfoLast()) == 0))
            FatalError("No matching cards found!\n");
        screen = KdScreenInfoAdd(card);
        KdParseScreen(screen, 0);
    }
    /*
     * Initialize all of the screens for all of the cards
     */
    for (card = kdCardInfo; card; card = card.next) {
        int ret = 1;

        if (card.cfuncs.cardinit)
            ret = (*card.cfuncs.cardinit) (card);
        if (ret) {
            for (screen = card.screenList; screen; screen = screen.next)
                KdInitScreen(screen, argc, argv);
        }
    }

    /*
     * Merge the various pixmap formats together, this can fail
     * when two screens share depth but not bitsPerPixel
     */
    if (!KdSetPixmapFormats())
        return;

    /*
     * Add all of the screens
     */
    for (card = kdCardInfo; card; card = card.next)
        for (screen = card.screenList; screen; screen = screen.next)
            KdAddScreen(screen, argc, argv);

    OsRegisterSigWrapper(&KdSignalWrapper);
    xorgGlxCreateVendor();

static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
    if (dixSettingSeatId) /* Enable input hot-plugging */
        config_pre_init();
}
}

void OsVendorFatalError(const(char)* f, va_list args)
{
}

/* These stubs can be safely removed once we can
 * split input and GPU parts in hotplug.h et al. */
version (CONFIG_UDEV_KMS) {
void NewGPUDeviceRequest(OdevAttributes* attribs)
{
}

void DeleteGPUDeviceRequest(OdevAttributes* attribs)
{
}
}

static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
xf86_platform_device* xf86_find_platform_device_by_devnum(uint major, uint minor)
{
    return null;
}
}

version (SYSTEMD_LOGIND) {
void systemd_logind_vtenter()
{
}

void systemd_logind_release_fd(int major, int minor, int fd)
{
    close(fd);
}
}
