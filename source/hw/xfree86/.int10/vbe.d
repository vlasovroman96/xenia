module vbe;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *                   XFree86 vbe module
 *               Copyright 2000 Egbert Eich
 *
 * The mode query/save/set/restore functions from the vesa driver
 * have been moved here.
 * Copyright (c) 2000 by Conectiva S.A. (http://www.conectiva.com)
 * Authors: Paulo César Pereira de Andrade <pcpa@conectiva.com.br>
 */
import build.xorg_config;

import core.stdc.string;

// //import externs.X11.extensions.dpmsconst;

import hw.xfree86.common.xf86Helper;
import xf86Modes;
import vbe;
import xf86Bus;
import include.vbe;
import xf86int10;

public import ddc;

enum ddc_lvl {
    DDC_UNCHECKED,
    DDC_NONE,
    DDC_1,
    DDC_2,
    DDC_1_2
}
alias DDC_UNCHECKED = ddc_lvl.DDC_UNCHECKED;
alias DDC_NONE = ddc_lvl.DDC_NONE;
alias DDC_1 = ddc_lvl.DDC_1;
alias DDC_2 = ddc_lvl.DDC_2;
alias DDC_1_2 = ddc_lvl.DDC_1_2;


struct _VbeInfoRec {
    xf86Int10InfoPtr pInt10;
    int version_;
    void* memory;
    int real_mode_base;
    int num_pages;
    Bool init_int10;
    ddc_lvl ddc;
    Bool ddc_blank;
}alias vbeInfoRec = _VbeInfoRec;
alias vbeInfoPtr = vbeInfoRec*;

enum string VBE_VERSION_MAJOR(string x) = `*(cast(CARD8*)(&` ~ x ~ `) + 1)`;
enum string VBE_VERSION_MINOR(string x) = `cast(CARD8)(` ~ x ~ `)`;

void  VBEInit(xf86Int10InfoPtr pInt, int entityIndex);
void  VBEExtendedInit(xf86Int10InfoPtr pInt, int entityIndex, int Flags);
void  vbeFree(vbeInfoPtr pVbe);
void  vbeDoEDID(vbeInfoPtr pVbe, void* pDDCModule);

// #pragma pack(1)

struct vbeControllerInfoBlock {
    CARD8[4] VbeSignature;
    CARD16 VbeVersion;
    CARD32 OemStringPtr;
    CARD8[4] Capabilities;
    CARD32 VideoModePtr;
    CARD16 TotalMem;
    CARD16 OemSoftwareRev;
    CARD32 OemVendorNamePtr;
    CARD32 OemProductNamePtr;
    CARD32 OemProductRevPtr;
    CARD8[222] Scratch;
    CARD8[256] OemData;
}alias vbeControllerInfoRec = vbeControllerInfoBlock;
alias vbeControllerInfoPtr = vbeControllerInfoBlock*;

// version (__GNUC__) {
// #pragma pack()                  /* All GCC versions recognise this syntax */
// } else {
// #pragma pack(0)
// //#define __attribute__(a)
// }

alias VbeInfoBlock = _VbeInfoBlock;
alias VbeModeInfoBlock = _VbeModeInfoBlock;
alias VbeCRTCInfoBlock = _VbeCRTCInfoBlock;

/*
 * INT 0
 */

struct _VbeInfoBlock {
    /* VESA 1.2 fields */
    CARD8[4] VESASignature;     /* VESA */
    CARD16 VESAVersion;         /* Higher byte major, lower byte minor */
                                        /*CARD32 */ char* OEMStringPtr;
                                        /* Pointer to OEM string */
    CARD8[4] Capabilities;      /* Capabilities of the video environment */

                                        /*CARD32 */ CARD16* VideoModePtr;
                                        /* pointer to supported Super VGA modes */

    CARD16 TotalMemory;         /* Number of 64kb memory blocks on board */
    /* if not VESA 2, 236 scratch bytes follow (256 bytes total size) */

    /* VESA 2 fields */
    CARD16 OemSoftwareRev;      /* VBE implementation Software revision */
                                        /*CARD32 */ char* OemVendorNamePtr;
                                        /* Pointer to Vendor Name String */
                                                /*CARD32 */ char* OemProductNamePtr;
                                                /* Pointer to Product Name String */
                                        /*CARD32 */ char* OemProductRevPtr;
                                        /* Pointer to Product Revision String */
    CARD8[222] Reserved;        /* Reserved for VBE implementation */
    CARD8[256] OemData;         /* Data Area for OEM Strings */
};

/* Return Super VGA Information */
void * VBEGetVBEInfo(vbeInfoPtr pVbe);
void  VBEFreeVBEInfo(VbeInfoBlock* block);

/*
 * INT 1
 */

struct _VbeModeInfoBlock {
    CARD16 ModeAttributes;      /* mode attributes */
    CARD8 WinAAttributes;       /* window A attributes */
    CARD8 WinBAttributes;       /* window B attributes */
    CARD16 WinGranularity;      /* window granularity */
    CARD16 WinSize;             /* window size */
    CARD16 WinASegment;         /* window A start segment */
    CARD16 WinBSegment;         /* window B start segment */
    CARD32 WinFuncPtr;          /* real mode pointer to window function */
    CARD16 BytesPerScanline;    /* bytes per scanline */

    /* Mandatory information for VBE 1.2 and above */
    CARD16 XResolution;         /* horizontal resolution in pixels or characters */
    CARD16 YResolution;         /* vertical resolution in pixels or characters */
    CARD8 XCharSize;            /* character cell width in pixels */
    CARD8 YCharSize;            /* character cell height in pixels */
    CARD8 NumberOfPlanes;       /* number of memory planes */
    CARD8 BitsPerPixel;         /* bits per pixel */
    CARD8 NumberOfBanks;        /* number of banks */
    CARD8 MemoryModel;          /* memory model type */
    CARD8 BankSize;             /* bank size in KB */
    CARD8 NumberOfImages;       /* number of images */
    CARD8 Reserved;             /* 1 *//* reserved for page function */

    /* Direct color fields (required for direct/6 and YUV/7 memory models) */
    CARD8 RedMaskSize;          /* size of direct color red mask in bits */
    CARD8 RedFieldPosition;     /* bit position of lsb of red mask */
    CARD8 GreenMaskSize;        /* size of direct color green mask in bits */
    CARD8 GreenFieldPosition;   /* bit position of lsb of green mask */
    CARD8 BlueMaskSize;         /* size of direct color blue mask in bits */
    CARD8 BlueFieldPosition;    /* bit position of lsb of blue mask */
    CARD8 RsvdMaskSize;         /* size of direct color reserved mask in bits */
    CARD8 RsvdFieldPosition;    /* bit position of lsb of reserved mask */
    CARD8 DirectColorModeInfo;  /* direct color mode attributes */

    /* Mandatory information for VBE 2.0 and above */
    CARD32 PhysBasePtr;         /* physical address for flat memory frame buffer */
    CARD32 Reserved32;          /* 0 *//* Reserved - always set to 0 */
    CARD16 Reserved16;          /* 0 *//* Reserved - always set to 0 */

    /* Mandatory information for VBE 3.0 and above */
    CARD16 LinBytesPerScanLine; /* bytes per scan line for linear modes */
    CARD8 BnkNumberOfImagePages;        /* number of images for banked modes */
    CARD8 LinNumberOfImagePages;        /* number of images for linear modes */
    CARD8 LinRedMaskSize;       /* size of direct color red mask (linear modes) */
    CARD8 LinRedFieldPosition;  /* bit position of lsb of red mask (linear modes) */
    CARD8 LinGreenMaskSize;     /* size of direct color green mask (linear modes) */
    CARD8 LinGreenFieldPosition;        /* bit position of lsb of green mask (linear modes) */
    CARD8 LinBlueMaskSize;      /* size of direct color blue mask (linear modes) */
    CARD8 LinBlueFieldPosition; /* bit position of lsb of blue mask (linear modes) */
    CARD8 LinRsvdMaskSize;      /* size of direct color reserved mask (linear modes) */
    CARD8 LinRsvdFieldPosition; /* bit position of lsb of reserved mask (linear modes) */
    CARD32 MaxPixelClock;       /* maximum pixel clock (in Hz) for graphics mode */
    CARD8[189] Reserved2;       /* remainder of VbeModeInfoBlock */
};

/* Return VBE Mode Information */
int* VBEGetModeInfo(vbeInfoPtr pVbe, int mode);
int VBEFreeModeInfo(VbeModeInfoBlock* block);

/*
 * INT2
 */

enum CRTC_DBLSCAN =	(1<<0);
enum CRTC_INTERLACE =	(1<<1);
enum CRTC_NHSYNC =	(1<<2);
enum CRTC_NVSYNC =	(1<<3);

struct _VbeCRTCInfoBlock {
    CARD16 HorizontalTotal;     /* Horizontal total in pixels */
    CARD16 HorizontalSyncStart; /* Horizontal sync start in pixels */
    CARD16 HorizontalSyncEnd;   /* Horizontal sync end in pixels */
    CARD16 VerticalTotal;       /* Vertical total in lines */
    CARD16 VerticalSyncStart;   /* Vertical sync start in lines */
    CARD16 VerticalSyncEnd;     /* Vertical sync end in lines */
    CARD8 Flags;                /* Flags (Interlaced, Double Scan etc) */
    CARD32 PixelClock;          /* Pixel clock in units of Hz */
    CARD16 RefreshRate;         /* Refresh rate in units of 0.01 Hz */
    CARD8[40] Reserved;         /* remainder of ModeInfoBlock */
};

/* VbeCRTCInfoBlock is in the VESA 3.0 specs */

int VBESetVBEMode(vbeInfoPtr pVbe, int mode, VbeCRTCInfoBlock* crtc);

/*
 * INT 3
 */

int VBEGetVBEMode(vbeInfoPtr pVbe, int* mode);

/*
 * INT 4
 */

/* Save/Restore Super VGA video state */
/* function values are (values stored in VESAPtr):
 *	0 := query & allocate amount of memory to save state
 *	1 := save state
 *	2 := restore state
 *
 *	function 0 called automatically if function 1 called without
 *	a previous call to function 0.
 */

enum vbeSaveRestoreFunction {
    MODE_QUERY,
    MODE_SAVE,
    MODE_RESTORE
}
alias MODE_QUERY = vbeSaveRestoreFunction.MODE_QUERY;
alias MODE_SAVE = vbeSaveRestoreFunction.MODE_SAVE;
alias MODE_RESTORE = vbeSaveRestoreFunction.MODE_RESTORE;


int VBESaveRestore(vbeInfoPtr pVbe, vbeSaveRestoreFunction function_, void** memory, int* size, int* real_mode_pages);

/*
 * INT 5
 */

int VBEBankSwitch(vbeInfoPtr pVbe, uint iBank, int window);

/*
 * INT 6
 */

enum vbeScanwidthCommand {
    SCANWID_SET,
    SCANWID_GET,
    SCANWID_SET_BYTES,
    SCANWID_GET_MAX
}
alias SCANWID_SET = vbeScanwidthCommand.SCANWID_SET;
alias SCANWID_GET = vbeScanwidthCommand.SCANWID_GET;
alias SCANWID_SET_BYTES = vbeScanwidthCommand.SCANWID_SET_BYTES;
alias SCANWID_GET_MAX = vbeScanwidthCommand.SCANWID_GET_MAX;


enum string VBESetLogicalScanline(string pVbe, string width) = `
	VBESetGetLogicalScanlineLength(` ~ pVbe ~ `, SCANWID_SET, ` ~ width ~ `, 
					null, null, null)`;
enum string VBESetLogicalScanlineBytes(string pVbe, string width) = `
	VBESetGetLogicalScanlineLength(` ~ pVbe ~ `, SCANWID_SET_BYTES, ` ~ width ~ `, 
					null, null, null)`;
enum string VBEGetLogicalScanline(string pVbe, string pixels, string bytes, string max) = `
	VBESetGetLogicalScanlineLength(` ~ pVbe ~ `, SCANWID_GET, 0, 
					` ~ pixels ~ `, ` ~ bytes ~ `, ` ~ max ~ `)`;
enum string VBEGetMaxLogicalScanline(string pVbe, string pixels, string bytes, string max) = `
	VBESetGetLogicalScanlineLength(` ~ pVbe ~ `, SCANWID_GET_MAX, 0, 
					` ~ pixels ~ `, ` ~ bytes ~ `, ` ~ max ~ `)`;
int VBESetGetLogicalScanlineLength(vbeInfoPtr pVbe, vbeScanwidthCommand command, int width, int* pixels, int* bytes, int* max);

/*
 * INT 7
 */

/* 16 bit code */
int VBESetDisplayStart(vbeInfoPtr pVbe, int x, int y, Bool wait_retrace);

/*
 * INT 8
 */

/* if bits is 0, then it is a GET */
int VBESetGetDACPaletteFormat(vbeInfoPtr pVbe, int bits);

/*
 * INT 9
 */

/*
 *  If getting a palette, the data argument is not used. It will return
 * the data.
 *  If setting a palette, it will return the pointer received on success,
 * NULL on failure.
 */
int* VBESetGetPaletteData(vbeInfoPtr pVbe, Bool set, int first, int num, CARD32* data, Bool secondary, Bool wait_retrace);
enum string VBEFreePaletteData(string data) = `free(` ~ data ~ `)`;

/*
 * INT A
 */

struct VBEpmi {
    int seg_tbl;
    int tbl_off;
    int tbl_len;
}

enum string VESAFreeVBEpmi(string pmi) = `free(` ~ pmi ~ `)`;

/* high level helper functions */

struct _vbeModeInfoRec {
    int width;
    int height;
    int bpp;
    int n;
    _vbeModeInfoRec* next;
}alias vbeModeInfoRec = _vbeModeInfoRec;
alias vbeModeInfoPtr = _vbeModeInfoRec*;

struct _VbeSaveRestoreRec {
    CARD8* state;
    CARD8* pstate;
    int statePage;
    int stateSize;
    int stateMode;
}alias vbeSaveRestoreRec = _VbeSaveRestoreRec;
alias vbeSaveRestorePtr = vbeSaveRestoreRec*;

int VBEVesaSaveRestore(vbeInfoPtr pVbe, vbeSaveRestorePtr vbe_sr, vbeSaveRestoreFunction function_);

int VBEGetPixelClock(vbeInfoPtr pVbe, int mode, int Clock);
int VBEDPMSSet(vbeInfoPtr pVbe, int mode);

struct vbePanelID {
    short hsize;
    short vsize;
    short fptype;
    char redbpp = 0;
    char greenbpp = 0;
    char bluebpp = 0;
    char reservedbpp = 0;
    int reserved_offscreen_mem_size;
    int reserved_offscreen_mem_pointer;
    char[14] reserved = 0;
}

int VBEInterpretPanelID(ScrnInfoPtr pScrn, vbePanelID* data);
vbePanelID* VBEReadPanelID(vbeInfoPtr pVbe);


enum string VERSION(string x) = `VBE_VERSION_MAJOR(` ~ x ~ `),VBE_VERSION_MINOR(` ~ x ~ `)`;

static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
enum string B_O16(string x) = `(` ~ x ~ `)`;
enum string B_O32(string x) = `(` ~ x ~ `)`;
} else {
enum string B_O16(string x) = `((((` ~ x ~ `) & 0xff) << 8) | (((` ~ x ~ `) & 0xff) >> 8))`;
enum string B_O32(string x) = `((((` ~ x ~ `) & 0xff) << 24) | (((` ~ x ~ `) & 0xff00) << 8) 
                  | (((` ~ x ~ `) & 0xff0000) >> 8) | (((` ~ x ~ `) & 0xff000000) >> 24))`;
}
enum string L_ADD(string x) = `(` ~ B_O32!(x) ~ ` & 0xffff) + ((` ~ B_O32!(x) ~ ` >> 12) & 0xffff00)`;

enum string FARP(string p) = `((cast(uint)(` ~ p ~ ` & 0xffff0000) >> 12) | (` ~ p ~ ` & 0xffff))`;
enum string R16(string v) = `((` ~ v ~ `) & 0xffff)`;

private ubyte* vbeReadEDID(vbeInfoPtr pVbe);


private const(char)[5] vbeVersionString = "VBE2";

vbeInfoPtr VBEInit(xf86Int10InfoPtr pInt, int entityIndex)
{
    return VBEExtendedInit(pInt, entityIndex, 0);
}

vbeInfoPtr VBEExtendedInit(xf86Int10InfoPtr pInt, int entityIndex, int Flags)
{
    int RealOff = void;
    void* page = null;
    ScrnInfoPtr pScrn = xf86FindScreenForEntity(entityIndex);
    vbeControllerInfoPtr vbe = null;
    Bool init_int10 = FALSE;
    vbeInfoPtr vip = null;
    int screen = void;

    if (!pScrn)
        return null;
    screen = pScrn.scrnIndex;

    if (!pInt) {
        if (!xf86LoadSubModule(pScrn, "int10"))
            goto error;

        xf86DrvMsg(screen, X_INFO, "initializing int10\n");
        pInt = xf86ExtendedInitInt10(entityIndex, Flags);
        if (!pInt)
            goto error;
        init_int10 = TRUE;
    }

    page = xf86Int10AllocPages(pInt, 1, &RealOff);
    if (!page)
        goto error;
    vbe = cast(vbeControllerInfoPtr) page;
    memcpy(vbe.VbeSignature, vbeVersionString.ptr, 4);

    pInt.ax = 0x4F00;
    pInt.es = SEG_ADDR(RealOff);
    pInt.di = SEG_OFF(RealOff);
    pInt.num = 0x10;

    xf86ExecX86int10(pInt);

    if ((pInt.ax & 0xff) != 0x4f) {
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA BIOS not detected\n");
        goto error;
    }

    switch (pInt.ax & 0xff00) {
    case 0:
        xf86DrvMsg(screen, X_INFO, "VESA BIOS detected\n");
        break;
    case 0x100:
        xf86DrvMsg(screen, X_INFO, "VESA BIOS function failed\n");
        goto error;
    case 0x200:
        xf86DrvMsg(screen, X_INFO, "VESA BIOS not supported\n");
        goto error;
    case 0x300:
        xf86DrvMsg(screen, X_INFO, "VESA BIOS not supported in current mode\n");
        goto error;
    default:
        xf86DrvMsg(screen, X_INFO, "Invalid\n");
        goto error;
    }

    xf86DrvMsgVerb(screen, X_INFO, 4,
                   "VbeVersion is %d, OemStringPtr is 0x%08lx,\n"
                   ~ "\tOemVendorNamePtr is 0x%08lx, OemProductNamePtr is 0x%08lx,\n"
                   ~ "\tOemProductRevPtr is 0x%08lx\n",
                   vbe.VbeVersion, cast(c_ulong) vbe.OemStringPtr,
                   cast(c_ulong) vbe.OemVendorNamePtr,
                   cast(c_ulong) vbe.OemProductNamePtr,
                   cast(c_ulong) vbe.OemProductRevPtr);

    xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE Version %i.%i\n",
                   mixin(VERSION!(`vbe.VbeVersion`)));
    xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE Total Mem: %i kB\n",
                   vbe.TotalMem * 64);
    xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE OEM: %s\n",
                   cast(CARD8*) xf86int10Addr(pInt, mixin(L_ADD!(`vbe.OemStringPtr`))));

    if (mixin(B_O16!(`vbe.VbeVersion`)) >= 0x200) {
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE OEM Software Rev: %i.%i\n",
                       mixin(VERSION!(`vbe.OemSoftwareRev`)));
        if (vbe.OemVendorNamePtr)
            xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE OEM Vendor: %s\n",
                           cast(CARD8*) xf86int10Addr(pInt,
                                                   mixin(L_ADD!(`vbe.
                                                         OemVendorNamePtr`))));
        if (vbe.OemProductNamePtr)
            xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE OEM Product: %s\n",
                           cast(CARD8*) xf86int10Addr(pInt,
                                                   mixin(L_ADD!(`vbe.
                                                         OemProductNamePtr`))));
        if (vbe.OemProductRevPtr)
            xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE OEM Product Rev: %s\n",
                           cast(CARD8*) xf86int10Addr(pInt,
                                                   mixin(L_ADD!(`vbe.
                                                         OemProductRevPtr`))));
    }
    vip = cast(vbeInfoPtr) XNFalloc(vbeInfoRec.sizeof);
    vip.version_ = mixin(B_O16!(`vbe.VbeVersion`));
    vip.pInt10 = pInt;
    vip.ddc = DDC_UNCHECKED;
    vip.memory = page;
    vip.real_mode_base = RealOff;
    vip.num_pages = 1;
    vip.init_int10 = init_int10;

    return vip;

 error:
    if (page)
        xf86Int10FreePages(pInt, page, 1);
    if (init_int10)
        xf86FreeInt10(pInt);
    return null;
}

void vbeFree(vbeInfoPtr pVbe)
{
    if (!pVbe)
        return;

    xf86Int10FreePages(pVbe.pInt10, pVbe.memory, pVbe.num_pages);
    /* If we have initialized int10 we ought to free it, too */
    if (pVbe.init_int10)
        xf86FreeInt10(pVbe.pInt10);
    free(pVbe);
    return;
}

private Bool vbeProbeDDC(vbeInfoPtr pVbe)
{
    const(char)* ddc_level = void;
    int screen = pVbe.pInt10.pScrn.scrnIndex;

    if (pVbe.ddc == DDC_NONE)
        return FALSE;
    if (pVbe.ddc != DDC_UNCHECKED)
        return TRUE;

    pVbe.pInt10.ax = 0x4F15;
    pVbe.pInt10.bx = 0;
    pVbe.pInt10.cx = 0;
    pVbe.pInt10.es = 0;
    pVbe.pInt10.di = 0;
    pVbe.pInt10.num = 0x10;

    xf86ExecX86int10(pVbe.pInt10);

    if ((pVbe.pInt10.ax & 0xff) != 0x4f) {
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC not supported\n");
        pVbe.ddc = DDC_NONE;
        return FALSE;
    }

    switch ((pVbe.pInt10.ax >> 8) & 0xff) {
    case 0:
        xf86DrvMsg(screen, X_INFO, "VESA VBE DDC supported\n");
        switch (pVbe.pInt10.bx & 0x3) {
        case 0:
            ddc_level = " none";
            pVbe.ddc = DDC_NONE;
            break;
        case 1:
            ddc_level = " 1";
            pVbe.ddc = DDC_1;
            break;
        case 2:
            ddc_level = " 2";
            pVbe.ddc = DDC_2;
            break;
        case 3:
            ddc_level = " 1 + 2";
            pVbe.ddc = DDC_1_2;
            break;
        default:
            ddc_level = "";
            pVbe.ddc = DDC_NONE;
            break;
        }
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC Level%s\n", ddc_level);
        if (pVbe.pInt10.bx & 0x4) {
            xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC Screen blanked"
                           ~ "for data transfer\n");
            pVbe.ddc_blank = TRUE;
        }
        else
            pVbe.ddc_blank = FALSE;

        xf86DrvMsgVerb(screen, X_INFO, 3,
                       "VESA VBE DDC transfer in appr. %x sec.\n",
                       (pVbe.pInt10.bx >> 8) & 0xff);
    default: break;}

    return TRUE;
}

enum VBEOpts {
    VBEOPT_NOVBE,
    VBEOPT_NODDC
}
alias VBEOPT_NOVBE = VBEOpts.VBEOPT_NOVBE;
alias VBEOPT_NODDC = VBEOpts.VBEOPT_NODDC;


private const(OptionInfoRec)[4] VBEOptions = [
    {VBEOPT_NOVBE, "NoVBE", OPTV_BOOLEAN, {0}, FALSE},
    {VBEOPT_NODDC, "NoDDC", OPTV_BOOLEAN, {0}, FALSE},
    {-1, null, OPTV_NONE, {0}, FALSE},
];

private ubyte* vbeReadEDID(vbeInfoPtr pVbe)
{
    int RealOff = pVbe.real_mode_base;
    void* page = pVbe.memory;
    ubyte* tmp = null;
    Bool novbe = FALSE;
    Bool noddc = FALSE;
    ScrnInfoPtr pScrn = pVbe.pInt10.pScrn;
    int screen = pScrn.scrnIndex;
    OptionInfoPtr options = void;

    if (!page)
        return null;

    options = XNFalloc(VBEOptions.sizeof);
    cast(void) memcpy(options, VBEOptions.ptr, VBEOptions.sizeof);
    xf86ProcessOptions(screen, pScrn.options, options);
    xf86GetOptValBool(options, VBEOPT_NOVBE, &novbe);
    xf86GetOptValBool(options, VBEOPT_NODDC, &noddc);
    free(options);
    if (novbe || noddc)
        return null;

    if (!vbeProbeDDC(pVbe))
        goto error;

    memset(page, 0, vbeInfoPtr.sizeof);
    strcpy(page, vbeVersionString.ptr);

    pVbe.pInt10.ax = 0x4F15;
    pVbe.pInt10.bx = 0x01;
    pVbe.pInt10.cx = 0;
    pVbe.pInt10.dx = 0;
    pVbe.pInt10.es = SEG_ADDR(RealOff);
    pVbe.pInt10.di = SEG_OFF(RealOff);
    pVbe.pInt10.num = 0x10;

    xf86ExecX86int10(pVbe.pInt10);

    if ((pVbe.pInt10.ax & 0xff) != 0x4f) {
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC invalid\n");
        goto error;
    }
    switch (pVbe.pInt10.ax & 0xff00) {
    case 0x0:
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC read successfully\n");
        tmp = cast(ubyte*) XNFalloc(128);
        memcpy(tmp, page, 128);
        break;
    case 0x100:
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC read failed\n");
        break;
    default:
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE DDC unknown failure %i\n",
                       pVbe.pInt10.ax & 0xff00);
        break;
    }

 error:
    return tmp;
}

xf86MonPtr vbeDoEDID(vbeInfoPtr pVbe, void* unused)
{
    ubyte* DDC_data = null;

    if (!pVbe)
        return null;
    if (pVbe.version_ < 0x102)
        return null;

    DDC_data = vbeReadEDID(pVbe);

    if (!DDC_data)
        return null;

    return xf86InterpretEDID(pVbe.pInt10.pScrn.scrnIndex, DDC_data);
}

enum string GET_UNALIGNED2(string x) = `
            ((*cast(CARD16*)(` ~ x ~ `)) | (*((cast(CARD16*)(` ~ x ~ `) + 1))) << 16)`;

VbeInfoBlock* VBEGetVBEInfo(vbeInfoPtr pVbe)
{
    VbeInfoBlock* block = null;
    int i = void, pStr = void, pModes = void;
    char* str = void;
    CARD16 major = void; CARD16* modes = void;

    memset(pVbe.memory, 0, VbeInfoBlock.sizeof);

    /*
       Input:
       AH    := 4Fh     Super VGA support
       AL    := 00h     Return Super VGA information
       ES:DI := Pointer to buffer

       Output:
       AX    := status
       (All other registers are preserved)
     */

    (cast(char*) pVbe.memory)[0] = 'V';
    (cast(char*) pVbe.memory)[1] = 'B';
    (cast(char*) pVbe.memory)[2] = 'E';
    (cast(char*) pVbe.memory)[3] = '2';

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f00;
    pVbe.pInt10.es = SEG_ADDR(pVbe.real_mode_base);
    pVbe.pInt10.di = SEG_OFF(pVbe.real_mode_base);
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return null;

    block = cast(VbeInfoBlock*) cast(VbeInfoBlock*) calloc(1, VbeInfoBlock.sizeof);
    if (!block)
        return null;
    block.VESASignature[0] = (cast(char*) pVbe.memory)[0];
    block.VESASignature[1] = (cast(char*) pVbe.memory)[1];
    block.VESASignature[2] = (cast(char*) pVbe.memory)[2];
    block.VESASignature[3] = (cast(char*) pVbe.memory)[3];

    block.VESAVersion = *cast(CARD16*) ((cast(char*) pVbe.memory) + 4);
    major = cast(uint) block.VESAVersion >> 8;

    pStr = mixin(GET_UNALIGNED2!(`((cast(char*) pVbe.memory) + 6)`));
    str = xf86int10Addr(pVbe.pInt10, mixin(FARP!(`pStr`)));
    block.OEMStringPtr = strdup(str);

    block.Capabilities[0] = (cast(char*) pVbe.memory)[10];
    block.Capabilities[1] = (cast(char*) pVbe.memory)[11];
    block.Capabilities[2] = (cast(char*) pVbe.memory)[12];
    block.Capabilities[3] = (cast(char*) pVbe.memory)[13];

    pModes = mixin(GET_UNALIGNED2!(`((cast(char*) pVbe.memory) + 14)`));
    modes = xf86int10Addr(pVbe.pInt10, mixin(FARP!(`pModes`)));
    i = 0;
    while (modes[i] != 0xffff)
        i++;
    if (((block.VideoModePtr = calloc(i + 1, CARD16.sizeof)) == 0))
        return null;
    memcpy(block.VideoModePtr, modes, ((CARD16) * i).sizeof);
    block.VideoModePtr[i] = 0xffff;

    block.TotalMemory = *cast(CARD16*) ((cast(char*) pVbe.memory) + 18);

    if (major < 2)
        memcpy(&block.OemSoftwareRev, (cast(char*) pVbe.memory) + 20, 236);
    else {
        block.OemSoftwareRev = *cast(CARD16*) ((cast(char*) pVbe.memory) + 20);
        pStr = mixin(GET_UNALIGNED2!(`((cast(char*) pVbe.memory) + 22)`));
        str = xf86int10Addr(pVbe.pInt10, mixin(FARP!(`pStr`)));
        block.OemVendorNamePtr = strdup(str);
        pStr = mixin(GET_UNALIGNED2!(`((cast(char*) pVbe.memory) + 26)`));
        str = xf86int10Addr(pVbe.pInt10, mixin(FARP!(`pStr`)));
        block.OemProductNamePtr = strdup(str);
        pStr = mixin(GET_UNALIGNED2!(`((cast(char*) pVbe.memory) + 30)`));
        str = xf86int10Addr(pVbe.pInt10, mixin(FARP!(`pStr`)));
        block.OemProductRevPtr = strdup(str);
        memcpy(&block.Reserved, (cast(char*) pVbe.memory) + 34, 222);
        memcpy(&block.OemData, (cast(char*) pVbe.memory) + 256, 256);
    }

    return block;
}

void VBEFreeVBEInfo(VbeInfoBlock* block)
{
    free(block.OEMStringPtr);
    free(block.VideoModePtr);
    if ((cast(uint) block.VESAVersion >> 8) >= 2) {
        free(block.OemVendorNamePtr);
        free(block.OemProductNamePtr);
        free(block.OemProductRevPtr);
    }
    free(block);
}

Bool VBESetVBEMode(vbeInfoPtr pVbe, int mode, VbeCRTCInfoBlock* block)
{
    /*
       Input:
       AH    := 4Fh     Super VGA support
       AL    := 02h     Set Super VGA video mode
       BX    := Video mode
       D0-D8  := Mode number
       D9-D10 := Reserved (must be 0)
       D11    := 0 Use current default refresh rate
       := 1 Use user specified CRTC values for refresh rate
       D12-13   Reserved for VBE/AF (must be 0)
       D14    := 0 Use windowed frame buffer model
       := 1 Use linear/flat frame buffer model
       D15    := 0 Clear video memory
       := 1 Don't clear video memory
       ES:DI := Pointer to VbeCRTCInfoBlock structure

       Output: AX = Status
       (All other registers are preserved)
     */
    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f02;
    pVbe.pInt10.bx = mode;
    if (block) {
        pVbe.pInt10.bx |= 1 << 11;
        memcpy(pVbe.memory, block, VbeCRTCInfoBlock.sizeof);
        pVbe.pInt10.es = SEG_ADDR(pVbe.real_mode_base);
        pVbe.pInt10.di = SEG_OFF(pVbe.real_mode_base);
    }
    else
        pVbe.pInt10.bx &= ~(1 << 11);

    xf86ExecX86int10(pVbe.pInt10);

    return (mixin(R16!(`pVbe.pInt10.ax`)) == 0x4f);
}

Bool VBEGetVBEMode(vbeInfoPtr pVbe, int* mode)
{
    /*
       Input:
       AH := 4Fh        Super VGA support
       AL := 03h        Return current video mode

       Output:
       AX := Status
       BX := Current video mode
       (All other registers are preserved)
     */
    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f03;

    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) == 0x4f) {
        *mode = mixin(R16!(`pVbe.pInt10.bx`));

        return TRUE;
    }

    return FALSE;
}

VbeModeInfoBlock* VBEGetModeInfo(vbeInfoPtr pVbe, int mode)
{
    memset(pVbe.memory, 0, VbeModeInfoBlock.sizeof);

    /*
       Input:
       AH    := 4Fh     Super VGA support
       AL    := 01h     Return Super VGA mode information
       CX    :=         Super VGA video mode
       (mode number must be one of those returned by Function 0)
       ES:DI := Pointer to buffer

       Output:
       AX    := status
       (All other registers are preserved)
     */
    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f01;
    pVbe.pInt10.cx = mode;
    pVbe.pInt10.es = SEG_ADDR(pVbe.real_mode_base);
    pVbe.pInt10.di = SEG_OFF(pVbe.real_mode_base);
    xf86ExecX86int10(pVbe.pInt10);
    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return null;

    VbeModeInfoBlock* block = cast(VbeModeInfoBlock*) cast(VbeModeInfoBlock*) calloc(1, VbeModeInfoBlock.sizeof);
    if (block)
        memcpy(block, pVbe.memory, typeof(*block).sizeof);

    return block;
}

void VBEFreeModeInfo(VbeModeInfoBlock* block)
{
    free(block);
}

Bool VBESaveRestore(vbeInfoPtr pVbe, vbeSaveRestoreFunction function_, void** memory, int* size, int* real_mode_pages)
{
    /*
       Input:
       AH    := 4Fh     Super VGA support
       AL    := 04h     Save/restore Super VGA video state
       DL    := 00h     Return save/restore state buffer size
       CX    := Requested states
       D0 = Save/restore video hardware state
       D1 = Save/restore video BIOS data state
       D2 = Save/restore video DAC state
       D3 = Save/restore Super VGA state

       Output:
       AX = Status
       BX = Number of 64-byte blocks to hold the state buffer
       (All other registers are preserved)

       Input:
       AH    := 4Fh     Super VGA support
       AL    := 04h     Save/restore Super VGA video state
       DL    := 01h     Save Super VGA video state
       CX    := Requested states (see above)
       ES:BX := Pointer to buffer

       Output:
       AX    := Status
       (All other registers are preserved)

       Input:
       AH    := 4Fh     Super VGA support
       AL    := 04h     Save/restore Super VGA video state
       DL    := 02h     Restore Super VGA video state
       CX    := Requested states (see above)
       ES:BX := Pointer to buffer

       Output:
       AX     := Status
       (All other registers are preserved)
     */

    if ((pVbe.version_ & 0xff00) > 0x100) {
        int screen = pVbe.pInt10.pScrn.scrnIndex;

        if (function_ == MODE_QUERY || (function_ == MODE_SAVE && !*memory)) {
            /* Query amount of memory to save state */

            pVbe.pInt10.num = 0x10;
            pVbe.pInt10.ax = 0x4f04;
            pVbe.pInt10.dx = 0;
            pVbe.pInt10.cx = 0x000f;
            xf86ExecX86int10(pVbe.pInt10);
            if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
                return FALSE;

            if (function_ == MODE_SAVE) {
                int npages = (mixin(R16!(`pVbe.pInt10.bx`)) * 64) / 4096 + 1;

                if ((*memory = xf86Int10AllocPages(pVbe.pInt10, npages,
                                                   real_mode_pages)) is null) {
                    xf86DrvMsg(screen, X_ERROR,
                               "Cannot allocate memory to save SVGA state.\n");
                    return FALSE;
                }
            }
            *size = pVbe.pInt10.bx * 64;
        }

        /* Save/Restore Super VGA state */
        if (function_ != MODE_QUERY) {

            if (!*memory)
                return FALSE;
            pVbe.pInt10.num = 0x10;
            pVbe.pInt10.ax = 0x4f04;
            switch (function_) {
            case MODE_SAVE:
                pVbe.pInt10.dx = 1;
                break;
            case MODE_RESTORE:
                pVbe.pInt10.dx = 2;
                break;
            case MODE_QUERY:
                return FALSE;
            default: break;}
            pVbe.pInt10.cx = 0x000f;

            pVbe.pInt10.es = SEG_ADDR(*real_mode_pages);
            pVbe.pInt10.bx = SEG_OFF(*real_mode_pages);
            xf86ExecX86int10(pVbe.pInt10);
            return (mixin(R16!(`pVbe.pInt10.ax`)) == 0x4f);

        }
    }
    return TRUE;
}

Bool VBEBankSwitch(vbeInfoPtr pVbe, uint iBank, int window)
{
    /*
       Input:
       AH    := 4Fh     Super VGA support
       AL    := 05h

       Output:
     */
    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f05;
    pVbe.pInt10.bx = window;
    pVbe.pInt10.dx = iBank;
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return FALSE;

    return TRUE;
}

Bool VBESetGetLogicalScanlineLength(vbeInfoPtr pVbe, vbeScanwidthCommand command, int width, int* pixels, int* bytes, int* max)
{
    if (command < SCANWID_SET || command > SCANWID_GET_MAX)
        return FALSE;

    /*
       Input:
       AX := 4F06h VBE Set/Get Logical Scan Line Length
       BL := 00h Set Scan Line Length in Pixels
       := 01h Get Scan Line Length
       := 02h Set Scan Line Length in Bytes
       := 03h Get Maximum Scan Line Length
       CX := If BL=00h Desired Width in Pixels
       If BL=02h Desired Width in Bytes
       (Ignored for Get Functions)

       Output:
       AX := VBE Return Status
       BX := Bytes Per Scan Line
       CX := Actual Pixels Per Scan Line
       (truncated to nearest complete pixel)
       DX := Maximum Number of Scan Lines
     */

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f06;
    pVbe.pInt10.bx = command;
    if (command == SCANWID_SET || command == SCANWID_SET_BYTES)
        pVbe.pInt10.cx = width;
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return FALSE;

    if (command == SCANWID_GET || command == SCANWID_GET_MAX) {
        if (pixels)
            *pixels = mixin(R16!(`pVbe.pInt10.cx`));
        if (bytes)
            *bytes = mixin(R16!(`pVbe.pInt10.bx`));
        if (max)
            *max = mixin(R16!(`pVbe.pInt10.dx`));
    }

    return TRUE;
}

Bool VBESetDisplayStart(vbeInfoPtr pVbe, int x, int y, Bool wait_retrace)
{
    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f07;
    pVbe.pInt10.bx = wait_retrace ? 0x80 : 0x00;
    pVbe.pInt10.cx = x;
    pVbe.pInt10.dx = y;
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return FALSE;

    return TRUE;
}

int VBESetGetDACPaletteFormat(vbeInfoPtr pVbe, int bits)
{
    /*
       Input:
       AX := 4F08h VBE Set/Get Palette Format
       BL := 00h Set DAC Palette Format
       := 01h Get DAC Palette Format
       BH := Desired bits of color per primary
       (Set DAC Palette Format only)

       Output:
       AX := VBE Return Status
       BH := Current number of bits of color per primary
     */

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f08;
    if (!bits)
        pVbe.pInt10.bx = 0x01;
    else
        pVbe.pInt10.bx = (bits & 0x00ff) << 8;
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return 0;

    return (bits != 0 ? bits : (pVbe.pInt10.bx >> 8) & 0x00ff);
}

CARD32* VBESetGetPaletteData(vbeInfoPtr pVbe, Bool set, int first, int num, CARD32* data, Bool secondary, Bool wait_retrace)
{
    /*
       Input:
       (16-bit)
       AX    := 4F09h VBE Load/Unload Palette Data
       BL    := 00h Set Palette Data
       := 01h Get Palette Data
       := 02h Set Secondary Palette Data
       := 03h Get Secondary Palette Data
       := 80h Set Palette Data during Vertical Retrace
       CX    := Number of palette registers to update (to a maximum of 256)
       DX    := First of the palette registers to update (start)
       ES:DI := Table of palette values (see below for format)

       Output:
       AX    := VBE Return Status

       Input:
       (32-bit)
       BL     := 00h Set Palette Data
       := 80h Set Palette Data during Vertical Retrace
       CX     := Number of palette registers to update (to a maximum of 256)
       DX     := First of the palette registers to update (start)
       ES:EDI := Table of palette values (see below for format)
       DS     := Selector for memory mapped registers
     */

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f09;
    if (!secondary)
        pVbe.pInt10.bx = set && wait_retrace ? 0x80 : set ? 0 : 1;
    else
        pVbe.pInt10.bx = set ? 2 : 3;
    pVbe.pInt10.cx = num;
    pVbe.pInt10.dx = first;
    pVbe.pInt10.es = SEG_ADDR(pVbe.real_mode_base);
    pVbe.pInt10.di = SEG_OFF(pVbe.real_mode_base);
    if (set)
        memcpy(pVbe.memory, data, num * CARD32.sizeof);
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return null;

    if (set)
        return data;

    if (((data = calloc(num, CARD32.sizeof)) == 0))
        return null;
    memcpy(data, pVbe.memory, num * CARD32.sizeof);

    return data;
}

void VBEVesaSaveRestore(vbeInfoPtr pVbe, vbeSaveRestorePtr vbe_sr, vbeSaveRestoreFunction function_)
{
    Bool SaveSucc = FALSE;

    if (VBE_VERSION_MAJOR(pVbe.version_) > 1
        && (function_ == MODE_SAVE || vbe_sr.pstate)) {
        if (function_ == MODE_RESTORE)
            memcpy(vbe_sr.state, vbe_sr.pstate, vbe_sr.stateSize);
        ErrorF("VBESaveRestore\n");
        if ((VBESaveRestore(pVbe, function_,
                            cast(void*) &vbe_sr.state,
                            &vbe_sr.stateSize, &vbe_sr.statePage))) {
            if (function_ == MODE_SAVE) {
                SaveSucc = TRUE;
                vbe_sr.stateMode = -1; /* invalidate */
                /* don't rely on the memory not being touched */
                if (vbe_sr.pstate is null)
                    vbe_sr.pstate = calloc(1, vbe_sr.stateSize);
                assert(vbe_sr.pstate);
                memcpy(vbe_sr.pstate, vbe_sr.state, vbe_sr.stateSize);
            }
            ErrorF("VBESaveRestore done with success\n");
            return;
        }
        ErrorF("VBESaveRestore done\n");
    }

    if (function_ == MODE_SAVE && !SaveSucc)
        cast(void) VBEGetVBEMode(pVbe, &vbe_sr.stateMode);

    if (function_ == MODE_RESTORE && vbe_sr.stateMode != -1)
        VBESetVBEMode(pVbe, vbe_sr.stateMode, null);

}

int VBEGetPixelClock(vbeInfoPtr pVbe, int mode, int clock)
{
    /*
       Input:
       AX := 4F0Bh VBE Get Pixel Clock
       BL := 00h Get Pixel Clock
       ECX := pixel clock in units of Hz
       DX := mode number

       Output:
       AX := VBE Return Status
       ECX := Closest pixel clock
     */

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f0b;
    pVbe.pInt10.bx = 0x00;
    pVbe.pInt10.cx = clock;
    pVbe.pInt10.dx = mode;
    xf86ExecX86int10(pVbe.pInt10);

    if (mixin(R16!(`pVbe.pInt10.ax`)) != 0x4f)
        return 0;

    return pVbe.pInt10.cx;
}

Bool VBEDPMSSet(vbeInfoPtr pVbe, int mode)
{
    /*
       Input:
       AX := 4F10h DPMS
       BL := 01h Set Display Power State
       BH := requested power state

       Output:
       AX := VBE Return Status
     */

    pVbe.pInt10.num = 0x10;
    pVbe.pInt10.ax = 0x4f10;
    pVbe.pInt10.bx = 0x01;
    switch (mode) {
    case DPMSModeOn:
        break;
    case DPMSModeStandby:
        pVbe.pInt10.bx |= 0x100;
        break;
    case DPMSModeSuspend:
        pVbe.pInt10.bx |= 0x200;
        break;
    case DPMSModeOff:
        pVbe.pInt10.bx |= 0x400;
        break;
    default: break;}
    xf86ExecX86int10(pVbe.pInt10);
    return (mixin(R16!(`pVbe.pInt10.ax`)) == 0x4f);
}

void VBEInterpretPanelID(ScrnInfoPtr pScrn, vbePanelID* data)
{
    DisplayModePtr mode = void;
    const(float) PANEL_HZ = 60.0;

    if (!data)
        return;

    xf86DrvMsg(pScrn.scrnIndex, X_INFO, "PanelID returned panel resolution %dx%d\n",
               data.hsize, data.vsize);

    if (pScrn.monitor.nHsync || pScrn.monitor.nVrefresh)
        return;

    if (data.hsize < 320 || data.vsize < 240) {
        xf86DrvMsg(pScrn.scrnIndex, X_INFO, "...which I refuse to believe\n");
        return;
    }

    mode = xf86CVTMode(data.hsize, data.vsize, PANEL_HZ, 1, 0);

    pScrn.monitor.nHsync = 1;
    pScrn.monitor.hsync[0].lo = 29.37;
    pScrn.monitor.hsync[0].hi = cast(float) mode.Clock / cast(float) mode.HTotal;
    pScrn.monitor.nVrefresh = 1;
    pScrn.monitor.vrefresh[0].lo = 56.0;
    pScrn.monitor.vrefresh[0].hi =
        cast(float) mode.Clock * 1000.0 / cast(float) mode.HTotal /
        cast(float) mode.VTotal;

    if (pScrn.monitor.vrefresh[0].hi < 59.47)
        pScrn.monitor.vrefresh[0].hi = 59.47;

    free(mode);
}

vbePanelID* VBEReadPanelID(vbeInfoPtr pVbe)
{
    int RealOff = pVbe.real_mode_base;
    void* page = pVbe.memory;
    void* tmp = null;
    int screen = pVbe.pInt10.pScrn.scrnIndex;

    pVbe.pInt10.ax = 0x4F11;
    pVbe.pInt10.bx = 0x01;
    pVbe.pInt10.cx = 0;
    pVbe.pInt10.dx = 0;
    pVbe.pInt10.es = SEG_ADDR(RealOff);
    pVbe.pInt10.di = SEG_OFF(RealOff);
    pVbe.pInt10.num = 0x10;

    xf86ExecX86int10(pVbe.pInt10);

    if ((pVbe.pInt10.ax & 0xff) != 0x4f) {
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE PanelID invalid\n");
        goto error;
    }

    switch (pVbe.pInt10.ax & 0xff00) {
    case 0x0:
        xf86DrvMsgVerb(screen, X_INFO, 3,
                       "VESA VBE PanelID read successfully\n");
        tmp = XNFalloc(32);
        memcpy(tmp, page, 32);
        break;
    case 0x100:
        xf86DrvMsgVerb(screen, X_INFO, 3, "VESA VBE PanelID read failed\n");
        break;
    default:
        xf86DrvMsgVerb(screen, X_INFO, 3,
                       "VESA VBE PanelID unknown failure %i\n",
                       pVbe.pInt10.ax & 0xff00);
        break;
    }

 error:
    return tmp;
}
