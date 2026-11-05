module include.vgaHW;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;

/*
 * Copyright (c) 1997,1998 The XFree86 Project, Inc.
 *
 * Loosely based on code bearing the following copyright:
 *
 *   Copyright 1990,91 by Thomas Roell, Dinkelscherben, Germany.
 *
 * Author: Dirk Hohndel
 */

 
//public import x11.X;
public import include.misc;
public import dix.input;
public import include.scrnintstr;

public import include.xf86str;
public import include.xf86Pci;

public import include.xf86DDC;

import hw.xfree86.modes.displaymode;
// //public import externs.X11.extensions.dpmsconst;

void  vgaHWGetIndex();

/*
 * access macro
 */
enum string VGAHWPTR(string p) = `(cast(vgaHWPtr)((` ~ p ~ `).privates[vgaHWGetIndex()].ptr))`;

/* Standard VGA registers */
enum VGA_ATTR_INDEX =		0x3C0;
enum VGA_ATTR_DATA_W =		0x3C0;
enum VGA_ATTR_DATA_R =		0x3C1;
enum VGA_IN_STAT_0 =		0x3C2   /* read */;
enum VGA_MISC_OUT_W =		0x3C2   /* write */;
enum VGA_ENABLE =		0x3C3;
enum VGA_SEQ_INDEX =		0x3C4;
enum VGA_SEQ_DATA =		0x3C5;
enum VGA_DAC_MASK =		0x3C6;
enum VGA_DAC_READ_ADDR =	0x3C7;
enum VGA_DAC_WRITE_ADDR =	0x3C8;
enum VGA_DAC_DATA =		0x3C9;
enum VGA_FEATURE_R =		0x3CA   /* read */;
enum VGA_MISC_OUT_R =		0x3CC   /* read */;
enum VGA_GRAPH_INDEX =		0x3CE;
enum VGA_GRAPH_DATA =		0x3CF;

enum VGA_IOBASE_MONO =		0x3B0;
enum VGA_IOBASE_COLOR =	0x3D0;

enum VGA_CRTC_INDEX_OFFSET =	0x04;
enum VGA_CRTC_DATA_OFFSET =	0x05;
enum VGA_IN_STAT_1_OFFSET =	0x0A    /* read */;
enum VGA_FEATURE_W_OFFSET =	0x0A    /* write */;

/* default number of VGA registers stored internally */
enum VGA_NUM_CRTC = 25;
enum VGA_NUM_SEQ = 5;
enum VGA_NUM_GFX = 9;
enum VGA_NUM_ATTR = 21;

/* Flags for vgaHWSave() and vgaHWRestore() */
enum VGA_SR_MODE =		0x01;
enum VGA_SR_FONTS =		0x02;
enum VGA_SR_CMAP =		0x04;
enum VGA_SR_ALL =		(VGA_SR_MODE | VGA_SR_FONTS | VGA_SR_CMAP);

/* Defaults for the VGA memory window */
enum VGA_DEFAULT_PHYS_ADDR =	0xA0000;
enum VGA_DEFAULT_MEM_SIZE =	(64 * 1024);

/*
 * vgaRegRec contains settings of standard VGA registers.
 */
struct _VgaRegRec {
    ubyte MiscOutReg;   /* */
    ubyte* CRTC;        /* Crtc Controller */
    ubyte* Sequencer;   /* Video Sequencer */
    ubyte* Graphics;    /* Video Graphics */
    ubyte* Attribute;   /* Video Attribute */
    ubyte[768] DAC;     /* Internal Colorlookuptable */
    ubyte numCRTC;      /* number of CRTC registers, def=VGA_NUM_CRTC */
    ubyte numSequencer; /* number of seq registers, def=VGA_NUM_SEQ */
    ubyte numGraphics;  /* number of gfx registers, def=VGA_NUM_GFX */
    ubyte numAttribute; /* number of attr registers, def=VGA_NUM_ATTR */
}alias vgaRegRec = _VgaRegRec;
alias vgaRegPtr = vgaRegRec*;

struct _vgaHWRec {
    void *Base;               /* Address of "VGA" memory */
    int MapSize;                /* Size of "VGA" memory */
    c_ulong MapPhys;      /* phys location of VGA mem */
    int IOBase;                 /* I/O Base address */
    CARD8 *MMIOBase;            /* Pointer to MMIO start */
    int MMIOOffset;             /* base + offset + vgareg
                                   = mmioreg */
    void *FontInfo1;          /* save area for fonts in
                                   plane 2 */
    void *FontInfo2;          /* save area for fonts in
                                   plane 3 */
    void *TextInfo;           /* save area for text */
    vgaRegRec SavedReg;         /* saved registers */
    vgaRegRec ModeReg;          /* register settings for
                                   current mode */
    Bool ShowOverscan;
    Bool paletteEnabled;
    Bool cmapSaved;
    ScrnInfoPtr pScrn;
    vgaHWWriteIndexProcPtr writeCrtc;
    vgaHWReadIndexProcPtr readCrtc;
    vgaHWWriteIndexProcPtr writeGr;
    vgaHWReadIndexProcPtr readGr;
    vgaHWReadProcPtr readST00;
    vgaHWReadProcPtr readST01;
    vgaHWReadProcPtr readFCR;
    vgaHWWriteProcPtr writeFCR;
    vgaHWWriteIndexProcPtr writeAttr;
    vgaHWReadIndexProcPtr readAttr;
    vgaHWWriteIndexProcPtr writeSeq;
    vgaHWReadIndexProcPtr readSeq;
    vgaHWWriteProcPtr writeMiscOut;
    vgaHWReadProcPtr readMiscOut;
    vgaHWMiscProcPtr enablePalette;
    vgaHWMiscProcPtr disablePalette;
    vgaHWWriteProcPtr writeDacMask;
    vgaHWReadProcPtr readDacMask;
    vgaHWWriteProcPtr writeDacWriteAddr;
    vgaHWWriteProcPtr writeDacReadAddr;
    vgaHWWriteProcPtr writeDacData;
    vgaHWReadProcPtr readDacData;
    void *ddc;
    pci_io_handle *io;
    vgaHWReadProcPtr readEnable;
    vgaHWWriteProcPtr writeEnable;
    pci_device *dev;
};

alias vgaHWRec = _vgaHWRec;
alias vgaHWPtr = _vgaHWRec*;

alias vgaHWWriteIndexProcPtr = void function(vgaHWPtr hwp, CARD8 indx, CARD8 value);
alias vgaHWReadIndexProcPtr = CARD8 function(vgaHWPtr hwp, CARD8 indx);
alias vgaHWWriteProcPtr = void function(vgaHWPtr hwp, CARD8 value);
alias vgaHWReadProcPtr = CARD8 function(vgaHWPtr hwp);
alias vgaHWMiscProcPtr = void function(vgaHWPtr hwp);

/*
 * vgaHWRec contains per-screen information required by the vgahw module.
 *
 * Note, the palette referred to by the paletteEnabled, enablePalette and
 * disablePalette is the 16-entry (+overscan) EGA-compatible palette accessed
 * via the first 17 attribute registers and not the main 8-bit palette.
 */
// struct vgaHWRec {
//     void* Base;               /* Address of "VGA" memory */
//     int MapSize;                /* Size of "VGA" memory */
//     c_ulong MapPhys;      /* phys location of VGA mem */
//     int IOBase;                 /* I/O Base address */
//     CARD8* MMIOBase;            /* Pointer to MMIO start */
//     int MMIOOffset;             /* base + offset + vgareg
//                                    = mmioreg */
//     void* FontInfo1;          /* save area for fonts in
//                                    plane 2 */
//     void* FontInfo2;          /* save area for fonts in
//                                    plane 3 */
//     void* TextInfo;           /* save area for text */
//     vgaRegRec SavedReg;         /* saved registers */
//     vgaRegRec ModeReg;          /* register settings for
//                                    current mode */
//     Bool ShowOverscan;
//     Bool paletteEnabled;
//     Bool cmapSaved;
//     ScrnInfoPtr pScrn;
//     vgaHWWriteIndexProcPtr writeCrtc;
//     vgaHWReadIndexProcPtr readCrtc;
//     vgaHWWriteIndexProcPtr writeGr;
//     vgaHWReadIndexProcPtr readGr;
//     vgaHWReadProcPtr readST00;
//     vgaHWReadProcPtr readST01;
//     vgaHWReadProcPtr readFCR;
//     vgaHWWriteProcPtr writeFCR;
//     vgaHWWriteIndexProcPtr writeAttr;
//     vgaHWReadIndexProcPtr readAttr;
//     vgaHWWriteIndexProcPtr writeSeq;
//     vgaHWReadIndexProcPtr readSeq;
//     vgaHWWriteProcPtr writeMiscOut;
//     vgaHWReadProcPtr readMiscOut;
//     vgaHWMiscProcPtr enablePalette;
//     vgaHWMiscProcPtr disablePalette;
//     vgaHWWriteProcPtr writeDacMask;
//     vgaHWReadProcPtr readDacMask;
//     vgaHWWriteProcPtr writeDacWriteAddr;
//     vgaHWWriteProcPtr writeDacReadAddr;
//     vgaHWWriteProcPtr writeDacData;
//     vgaHWReadProcPtr readDacData;
//     void* ddc;
//     pci_io_handle* io;
//     vgaHWReadProcPtr readEnable;
//     vgaHWWriteProcPtr writeEnable;
//     pci_device* dev;
// }

/* Some macros that VGA drivers can use in their ChipProbe() function */
enum OVERSCAN = 0X11           /* Index of OverScan register */;

/* Flags that define how overscan correction should take place */
enum KGA_FIX_OVERSCAN =  1     /* overcan correction required */;
enum KGA_ENABLE_ON_ZERO = 2    /* if possible enable display at beginning */;
                              /* of next scanline/frame                  */
enum KGA_BE_TOT_DEC = 4        /* always fix problem by setting blank end */;
                              /* to total - 1                            */
enum BIT_PLANE = 3             /* Which plane we write to in mono mode */;
enum BITS_PER_GUN = 6;
enum COLORMAP_SIZE = 256;

enum string DACDelay(string hw) = `
	{ 
	    (` ~ hw ~ `).readST01((` ~ hw ~ `)); 
	    (` ~ hw ~ `).readST01((` ~ hw ~ `)); 
	}`;

/* Function Prototypes */

/* vgaHW.c */
void  vgaHWSetStdFuncs(vgaHWPtr hwp);
void  vgaHWSetMmioFuncs(vgaHWPtr hwp, CARD8* base, int offset);
void  vgaHWProtect(ScrnInfoPtr pScrn, Bool on);
void  vgaHWSaveScreen(ScreenPtr pScreen, int mode);
void  vgaHWBlankScreen(ScrnInfoPtr pScrn, Bool on);
void  vgaHWSeqReset(vgaHWPtr hwp, Bool start);
 void vgaHWRestoreFonts(ScrnInfoPtr pScrnInfo, vgaRegPtr restore);
 void vgaHWRestore(ScrnInfoPtr pScrnInfo, vgaRegPtr restore, int flags);
 void vgaHWSaveFonts(ScrnInfoPtr pScrnInfo, vgaRegPtr save);
 void vgaHWSave(ScrnInfoPtr pScrnInfo, vgaRegPtr save, int flags);
void  vgaHWInit(ScrnInfoPtr scrnp, DisplayModePtr mode);
void  vgaHWCopyReg(vgaRegPtr dst, vgaRegPtr src);
void  vgaHWGetHWRec(ScrnInfoPtr scrp);
void  vgaHWFreeHWRec(ScrnInfoPtr scrp);
void  vgaHWMapMem(ScrnInfoPtr scrp);
void  vgaHWUnmapMem(ScrnInfoPtr scrp);
void  vgaHWGetIOBase(vgaHWPtr hwp);
void  vgaHWLock(vgaHWPtr hwp);
void  vgaHWUnlock(vgaHWPtr hwp);
void  vgaHWEnable(vgaHWPtr hwp);
void  vgaHWDPMSSet(ScrnInfoPtr pScrn, int PowerManagementMode, int flags);
void  vgaHWHandleColormaps(ScreenPtr pScreen);
void  vgaHWddc1SetSpeed(ScrnInfoPtr pScrn, xf86ddcSpeed speed);
void  vgaHWHBlankKGA(DisplayModePtr mode, vgaRegPtr regp, int nBits, uint Flags);
void  vgaHWVBlankKGA(DisplayModePtr mode, vgaRegPtr regp, int nBits, uint Flags);
void  vgaHWAllocDefaultRegs(vgaRegPtr regp);

 DDC1SetSpeedProc vgaHWddc1SetSpeedWeak();
void  xf86GetClocks(ScrnInfoPtr pScrn, int num, Bool function(ScrnInfoPtr, int) ClockFunc, void function(ScrnInfoPtr, Bool) ProtectRegs, void function(ScrnInfoPtr, Bool) BlankScreen, c_ulong vertsyncreg, int maskval, int knownclkindex, int knownclkvalue);

                          /* _VGAHW_H */
