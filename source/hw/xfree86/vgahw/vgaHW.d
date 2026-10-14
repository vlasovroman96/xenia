module hw.xfree86.vgahw.vgaHW;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright 1991-1999 by The XFree86 Project, Inc.
 *
 * Loosely based on code bearing the following copyright:
 *
 *   Copyright 1990,91 by Thomas Roell, Dinkelscherben, Germany.
 *
 */
import build.xorg_config;

import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.unistd;

//import x11.X;

import include.vgaHW;
import os.log_priv;

import include.misc;
import xf86_priv;
import include.xf86_OSproc;;
import xf86Opt_priv;
import include.xf86Priv;
import hw.xfree86.utils.compiler;
import xf86cmap;
import hw.xfree86.os_support.bus.Pci;
import hw.xfree86.common.xf86Helper;
import externs.X11.extensions.dpmsconst;
import xf86Globals;
import xf86Option;
import xf86pciBus;
import include.optionstr;
import include.xf86cmap;
import dix.events;



enum SAVE_FONT1 = 1;


/*
 * These used to be OS-specific, which made this module have an undesirable
 * OS dependency.  Define them by default for all platforms.
 */
 

enum SAVE_TEXT = 1;

enum SAVE_FONT2 = 1;


/* bytes per plane to save for text */
enum TEXT_AMOUNT = 16384;

/* bytes per plane to save for font data */
enum FONT_AMOUNT = (8*8192);

version (none) {
/* Override all of these for now */
enum SAVE_FONT1 = 1;
enum SAVE_FONT2 = 1;
enum SAVE_TEST = 1;
enum FONT_AMOUNT = 65536;
enum TEXT_AMOUNT = 65536;
}

/* DAC indices for white and black */
enum WHITE_VALUE = 0x3F;
enum BLACK_VALUE = 0x00;
enum OVERSCAN_VALUE = 0x01;

/* Use a private definition of this here */
enum string VGAHWPTRLVAL(string p) = `(` ~ p ~ `).privates[vgaHWPrivateIndex].ptr`;
enum string VGAHWPTR(string p) = `(cast(vgaHWPtr)(` ~ VGAHWPTRLVAL!(p) ~ `))`;

private int vgaHWPrivateIndex = -1;

enum DAC_TEST_MASK = 0x3F;

version (NEED_SAVED_CMAP) {
/* This default colourmap is used only when it can't be read from the VGA */

private CARD8[768] defaultDAC = [
    0, 0, 0, 0, 0, 42, 0, 42, 0, 0, 42, 42,
    42, 0, 0, 42, 0, 42, 42, 21, 0, 42, 42, 42,
    21, 21, 21, 21, 21, 63, 21, 63, 21, 21, 63, 63,
    63, 21, 21, 63, 21, 63, 63, 63, 21, 63, 63, 63,
    0, 0, 0, 5, 5, 5, 8, 8, 8, 11, 11, 11,
    14, 14, 14, 17, 17, 17, 20, 20, 20, 24, 24, 24,
    28, 28, 28, 32, 32, 32, 36, 36, 36, 40, 40, 40,
    45, 45, 45, 50, 50, 50, 56, 56, 56, 63, 63, 63,
    0, 0, 63, 16, 0, 63, 31, 0, 63, 47, 0, 63,
    63, 0, 63, 63, 0, 47, 63, 0, 31, 63, 0, 16,
    63, 0, 0, 63, 16, 0, 63, 31, 0, 63, 47, 0,
    63, 63, 0, 47, 63, 0, 31, 63, 0, 16, 63, 0,
    0, 63, 0, 0, 63, 16, 0, 63, 31, 0, 63, 47,
    0, 63, 63, 0, 47, 63, 0, 31, 63, 0, 16, 63,
    31, 31, 63, 39, 31, 63, 47, 31, 63, 55, 31, 63,
    63, 31, 63, 63, 31, 55, 63, 31, 47, 63, 31, 39,
    63, 31, 31, 63, 39, 31, 63, 47, 31, 63, 55, 31,
    63, 63, 31, 55, 63, 31, 47, 63, 31, 39, 63, 31,
    31, 63, 31, 31, 63, 39, 31, 63, 47, 31, 63, 55,
    31, 63, 63, 31, 55, 63, 31, 47, 63, 31, 39, 63,
    45, 45, 63, 49, 45, 63, 54, 45, 63, 58, 45, 63,
    63, 45, 63, 63, 45, 58, 63, 45, 54, 63, 45, 49,
    63, 45, 45, 63, 49, 45, 63, 54, 45, 63, 58, 45,
    63, 63, 45, 58, 63, 45, 54, 63, 45, 49, 63, 45,
    45, 63, 45, 45, 63, 49, 45, 63, 54, 45, 63, 58,
    45, 63, 63, 45, 58, 63, 45, 54, 63, 45, 49, 63,
    0, 0, 28, 7, 0, 28, 14, 0, 28, 21, 0, 28,
    28, 0, 28, 28, 0, 21, 28, 0, 14, 28, 0, 7,
    28, 0, 0, 28, 7, 0, 28, 14, 0, 28, 21, 0,
    28, 28, 0, 21, 28, 0, 14, 28, 0, 7, 28, 0,
    0, 28, 0, 0, 28, 7, 0, 28, 14, 0, 28, 21,
    0, 28, 28, 0, 21, 28, 0, 14, 28, 0, 7, 28,
    14, 14, 28, 17, 14, 28, 21, 14, 28, 24, 14, 28,
    28, 14, 28, 28, 14, 24, 28, 14, 21, 28, 14, 17,
    28, 14, 14, 28, 17, 14, 28, 21, 14, 28, 24, 14,
    28, 28, 14, 24, 28, 14, 21, 28, 14, 17, 28, 14,
    14, 28, 14, 14, 28, 17, 14, 28, 21, 14, 28, 24,
    14, 28, 28, 14, 24, 28, 14, 21, 28, 14, 17, 28,
    20, 20, 28, 22, 20, 28, 24, 20, 28, 26, 20, 28,
    28, 20, 28, 28, 20, 26, 28, 20, 24, 28, 20, 22,
    28, 20, 20, 28, 22, 20, 28, 24, 20, 28, 26, 20,
    28, 28, 20, 26, 28, 20, 24, 28, 20, 22, 28, 20,
    20, 28, 20, 20, 28, 22, 20, 28, 24, 20, 28, 26,
    20, 28, 28, 20, 26, 28, 20, 24, 28, 20, 22, 28,
    0, 0, 16, 4, 0, 16, 8, 0, 16, 12, 0, 16,
    16, 0, 16, 16, 0, 12, 16, 0, 8, 16, 0, 4,
    16, 0, 0, 16, 4, 0, 16, 8, 0, 16, 12, 0,
    16, 16, 0, 12, 16, 0, 8, 16, 0, 4, 16, 0,
    0, 16, 0, 0, 16, 4, 0, 16, 8, 0, 16, 12,
    0, 16, 16, 0, 12, 16, 0, 8, 16, 0, 4, 16,
    8, 8, 16, 10, 8, 16, 12, 8, 16, 14, 8, 16,
    16, 8, 16, 16, 8, 14, 16, 8, 12, 16, 8, 10,
    16, 8, 8, 16, 10, 8, 16, 12, 8, 16, 14, 8,
    16, 16, 8, 14, 16, 8, 12, 16, 8, 10, 16, 8,
    8, 16, 8, 8, 16, 10, 8, 16, 12, 8, 16, 14,
    8, 16, 16, 8, 14, 16, 8, 12, 16, 8, 10, 16,
    11, 11, 16, 12, 11, 16, 13, 11, 16, 15, 11, 16,
    16, 11, 16, 16, 11, 15, 16, 11, 13, 16, 11, 12,
    16, 11, 11, 16, 12, 11, 16, 13, 11, 16, 15, 11,
    16, 16, 11, 15, 16, 11, 13, 16, 11, 12, 16, 11,
    11, 16, 11, 11, 16, 12, 11, 16, 13, 11, 16, 15,
    11, 16, 16, 11, 15, 16, 11, 13, 16, 11, 12, 16,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];
}                          /* NEED_SAVED_CMAP */
enum string slowbcopy_tobus(string src, string dst, string count) = `xf86SlowBcopy(cast(ubyte*)(`~src~`),cast(ubyte*)(`~dst~`),(`~count~`));`;
enum string slowbcopy_frombus(string src, string dst, string count) = `xf86SlowBcopy(cast(ubyte*)(`~src~`),cast(ubyte*)(`~dst~`),(`~count~`));`;
/*
 * Standard VGA versions of the register access functions.
 */
private void stdWriteCrtc(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    pci_io_write8(hwp.io, hwp.IOBase + VGA_CRTC_INDEX_OFFSET, index);
    pci_io_write8(hwp.io, hwp.IOBase + VGA_CRTC_DATA_OFFSET, value);
}

private CARD8 stdReadCrtc(vgaHWPtr hwp, CARD8 index)
{
    pci_io_write8(hwp.io, hwp.IOBase + VGA_CRTC_INDEX_OFFSET, index);
    return pci_io_read8(hwp.io, hwp.IOBase + VGA_CRTC_DATA_OFFSET);
}

private void stdWriteGr(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_GRAPH_INDEX, index);
    pci_io_write8(hwp.io, VGA_GRAPH_DATA, value);
}

private CARD8 stdReadGr(vgaHWPtr hwp, CARD8 index)
{
    pci_io_write8(hwp.io, VGA_GRAPH_INDEX, index);
    return pci_io_read8(hwp.io, VGA_GRAPH_DATA);
}

private void stdWriteSeq(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_SEQ_INDEX, index);
    pci_io_write8(hwp.io, VGA_SEQ_DATA, value);
}

private CARD8 stdReadSeq(vgaHWPtr hwp, CARD8 index)
{
    pci_io_write8(hwp.io, VGA_SEQ_INDEX, index);
    return pci_io_read8(hwp.io, VGA_SEQ_DATA);
}

private CARD8 stdReadST00(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_IN_STAT_0);
}

private CARD8 stdReadST01(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, hwp.IOBase + VGA_IN_STAT_1_OFFSET);
}

private CARD8 stdReadFCR(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_FEATURE_R);
}

private void stdWriteFCR(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, hwp.IOBase + VGA_FEATURE_W_OFFSET, value);
}

private void stdWriteAttr(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    if (hwp.paletteEnabled)
        index &= ~0x20;
    else
        index |= 0x20;

    cast(void) pci_io_read8(hwp.io, hwp.IOBase + VGA_IN_STAT_1_OFFSET);
    pci_io_write8(hwp.io, VGA_ATTR_INDEX, index);
    pci_io_write8(hwp.io, VGA_ATTR_DATA_W, value);
}

private CARD8 stdReadAttr(vgaHWPtr hwp, CARD8 index)
{
    if (hwp.paletteEnabled)
        index &= ~0x20;
    else
        index |= 0x20;

    cast(void) pci_io_read8(hwp.io, hwp.IOBase + VGA_IN_STAT_1_OFFSET);
    pci_io_write8(hwp.io, VGA_ATTR_INDEX, index);
    return pci_io_read8(hwp.io, VGA_ATTR_DATA_R);
}

private void stdWriteMiscOut(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_MISC_OUT_W, value);
}

private CARD8 stdReadMiscOut(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_MISC_OUT_R);
}

private void stdEnablePalette(vgaHWPtr hwp)
{
    cast(void) pci_io_read8(hwp.io, hwp.IOBase + VGA_IN_STAT_1_OFFSET);
    pci_io_write8(hwp.io, VGA_ATTR_INDEX, 0x00);
    hwp.paletteEnabled = TRUE;
}

private void stdDisablePalette(vgaHWPtr hwp)
{
    cast(void) pci_io_read8(hwp.io, hwp.IOBase + VGA_IN_STAT_1_OFFSET);
    pci_io_write8(hwp.io, VGA_ATTR_INDEX, 0x20);
    hwp.paletteEnabled = FALSE;
}

private void stdWriteDacMask(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_DAC_MASK, value);
}

private CARD8 stdReadDacMask(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_DAC_MASK);
}

private void stdWriteDacReadAddr(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_DAC_READ_ADDR, value);
}

private void stdWriteDacWriteAddr(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_DAC_WRITE_ADDR, value);
}

private void stdWriteDacData(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_DAC_DATA, value);
}

private CARD8 stdReadDacData(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_DAC_DATA);
}

private CARD8 stdReadEnable(vgaHWPtr hwp)
{
    return pci_io_read8(hwp.io, VGA_ENABLE);
}

private void stdWriteEnable(vgaHWPtr hwp, CARD8 value)
{
    pci_io_write8(hwp.io, VGA_ENABLE, value);
}

void vgaHWSetStdFuncs(vgaHWPtr hwp)
{
    hwp.writeCrtc = &stdWriteCrtc;
    hwp.readCrtc = &stdReadCrtc;
    hwp.writeGr = &stdWriteGr;
    hwp.readGr = &stdReadGr;
    hwp.readST00 = &stdReadST00;
    hwp.readST01 = &stdReadST01;
    hwp.readFCR = &stdReadFCR;
    hwp.writeFCR = &stdWriteFCR;
    hwp.writeAttr = &stdWriteAttr;
    hwp.readAttr = &stdReadAttr;
    hwp.writeSeq = &stdWriteSeq;
    hwp.readSeq = &stdReadSeq;
    hwp.writeMiscOut = &stdWriteMiscOut;
    hwp.readMiscOut = &stdReadMiscOut;
    hwp.enablePalette = &stdEnablePalette;
    hwp.disablePalette = &stdDisablePalette;
    hwp.writeDacMask = &stdWriteDacMask;
    hwp.readDacMask = &stdReadDacMask;
    hwp.writeDacWriteAddr = &stdWriteDacWriteAddr;
    hwp.writeDacReadAddr = &stdWriteDacReadAddr;
    hwp.writeDacData = &stdWriteDacData;
    hwp.readDacData = &stdReadDacData;
    hwp.readEnable = &stdReadEnable;
    hwp.writeEnable = &stdWriteEnable;

    hwp.io = pci_legacy_open_io(hwp.dev, 0, 64 * 1024);
}

/*
 * MMIO versions of the register access functions.  These require
 * hwp->MemBase to be set in such a way that when the standard VGA port
 * address is added the correct memory address results.
 */

enum string minb(string p) = `MMIO_IN8(hwp.MMIOBase, (hwp.MMIOOffset + (` ~ p ~ `)))`;
enum string moutb(string p,string v) = `MMIO_OUT8(hwp.MMIOBase, (hwp.MMIOOffset + (` ~ p ~ `)),(` ~ v ~ `))`;

private void mmioWriteCrtc(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    mixin(moutb!(`hwp.IOBase + VGA_CRTC_INDEX_OFFSET`, `index`) ~`;`);
    mixin(moutb!(`hwp.IOBase + VGA_CRTC_DATA_OFFSET`, `value`) ~`;`);
}

private CARD8 mmioReadCrtc(vgaHWPtr hwp, CARD8 index)
{
    mixin(moutb!(`hwp.IOBase + VGA_CRTC_INDEX_OFFSET`, `index`) ~`;`);
    return mixin(minb!(`hwp.IOBase + VGA_CRTC_DATA_OFFSET`));
}

private void mmioWriteGr(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    mixin(moutb!(`VGA_GRAPH_INDEX`, `index`) ~`;`);
    mixin(moutb!(`VGA_GRAPH_DATA`, `value`) ~`;`);
}

private CARD8 mmioReadGr(vgaHWPtr hwp, CARD8 index)
{
    mixin(moutb!(`VGA_GRAPH_INDEX`, `index`) ~`;`);
    return mixin(minb!(`VGA_GRAPH_DATA`));
}

private void mmioWriteSeq(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    mixin(moutb!(`VGA_SEQ_INDEX`, `index`) ~`;`);
    mixin(moutb!(`VGA_SEQ_DATA`, `value`) ~`;`);
}

private CARD8 mmioReadSeq(vgaHWPtr hwp, CARD8 index)
{
    mixin(moutb!(`VGA_SEQ_INDEX`, `index`) ~`;`);
    return mixin(minb!(`VGA_SEQ_DATA`));
}

private CARD8 mmioReadST00(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_IN_STAT_0`));
}

private CARD8 mmioReadST01(vgaHWPtr hwp)
{
    return mixin(minb!(`hwp.IOBase + VGA_IN_STAT_1_OFFSET`));
}

private CARD8 mmioReadFCR(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_FEATURE_R`));
}

private void mmioWriteFCR(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`hwp.IOBase + VGA_FEATURE_W_OFFSET`, `value`) ~`;`);
}

private void mmioWriteAttr(vgaHWPtr hwp, CARD8 index, CARD8 value)
{
    if (hwp.paletteEnabled)
        index &= ~0x20;
    else
        index |= 0x20;

    cast(void) mixin(minb!(`hwp.IOBase + VGA_IN_STAT_1_OFFSET`));
    mixin(moutb!(`VGA_ATTR_INDEX`, `index`) ~`;`);
    mixin(moutb!(`VGA_ATTR_DATA_W`, `value`) ~`;`);
}

private CARD8 mmioReadAttr(vgaHWPtr hwp, CARD8 index)
{
    if (hwp.paletteEnabled)
        index &= ~0x20;
    else
        index |= 0x20;

    cast(void) mixin(minb!(`hwp.IOBase + VGA_IN_STAT_1_OFFSET`));
    mixin(moutb!(`VGA_ATTR_INDEX`, `index`) ~`;`);
    return mixin(minb!(`VGA_ATTR_DATA_R`));
}

private void mmioWriteMiscOut(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_MISC_OUT_W`, `value`) ~`;`);
}

private CARD8 mmioReadMiscOut(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_MISC_OUT_R`));
}

private void mmioEnablePalette(vgaHWPtr hwp)
{
    cast(void) mixin(minb!(`hwp.IOBase + VGA_IN_STAT_1_OFFSET`));
    mixin(moutb!(`VGA_ATTR_INDEX`, `0x00`) ~`;`);
    hwp.paletteEnabled = TRUE;
}

private void mmioDisablePalette(vgaHWPtr hwp)
{
    cast(void) mixin(minb!(`hwp.IOBase + VGA_IN_STAT_1_OFFSET`));
    mixin(moutb!(`VGA_ATTR_INDEX`, `0x20`) ~`;`);
    hwp.paletteEnabled = FALSE;
}

private void mmioWriteDacMask(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_DAC_MASK`, `value`) ~`;`);
}

private CARD8 mmioReadDacMask(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_DAC_MASK`));
}

private void mmioWriteDacReadAddr(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_DAC_READ_ADDR`, `value`) ~`;`);
}

private void mmioWriteDacWriteAddr(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_DAC_WRITE_ADDR`, `value`) ~`;`);
}

private void mmioWriteDacData(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_DAC_DATA`, `value`) ~`;`);
}

private CARD8 mmioReadDacData(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_DAC_DATA`));
}

private CARD8 mmioReadEnable(vgaHWPtr hwp)
{
    return mixin(minb!(`VGA_ENABLE`));
}

private void mmioWriteEnable(vgaHWPtr hwp, CARD8 value)
{
    mixin(moutb!(`VGA_ENABLE`, `value`) ~`;`);
}

void vgaHWSetMmioFuncs(vgaHWPtr hwp, CARD8* base, int offset)
{
    hwp.writeCrtc = &mmioWriteCrtc;
    hwp.readCrtc = &mmioReadCrtc;
    hwp.writeGr = &mmioWriteGr;
    hwp.readGr = &mmioReadGr;
    hwp.readST00 = &mmioReadST00;
    hwp.readST01 = &mmioReadST01;
    hwp.readFCR = &mmioReadFCR;
    hwp.writeFCR = &mmioWriteFCR;
    hwp.writeAttr = &mmioWriteAttr;
    hwp.readAttr = &mmioReadAttr;
    hwp.writeSeq = &mmioWriteSeq;
    hwp.readSeq = &mmioReadSeq;
    hwp.writeMiscOut = &mmioWriteMiscOut;
    hwp.readMiscOut = &mmioReadMiscOut;
    hwp.enablePalette = &mmioEnablePalette;
    hwp.disablePalette = &mmioDisablePalette;
    hwp.writeDacMask = &mmioWriteDacMask;
    hwp.readDacMask = &mmioReadDacMask;
    hwp.writeDacWriteAddr = &mmioWriteDacWriteAddr;
    hwp.writeDacReadAddr = &mmioWriteDacReadAddr;
    hwp.writeDacData = &mmioWriteDacData;
    hwp.readDacData = &mmioReadDacData;
    hwp.MMIOBase = base;
    hwp.MMIOOffset = offset;
    hwp.readEnable = &mmioReadEnable;
    hwp.writeEnable = &mmioWriteEnable;
}

/*
 * vgaHWProtect --
 *	Protect VGA registers and memory from corruption during loads.
 */

void vgaHWProtect(ScrnInfoPtr pScrn, Bool on)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));

    ubyte tmp = void;

    if (pScrn.vtSema) {
        if (on) {
            /*
             * Turn off screen and disable sequencer.
             */
            tmp = hwp.readSeq(hwp, 0x01);

            vgaHWSeqReset(hwp, TRUE);   /* start synchronous reset */
            hwp.writeSeq(hwp, 0x01, tmp | 0x20);       /* disable the display */

            hwp.enablePalette(hwp);
        }
        else {
            /*
             * Re-enable sequencer, then turn on screen.
             */

            tmp = hwp.readSeq(hwp, 0x01);

            hwp.writeSeq(hwp, 0x01, tmp & ~0x20);      /* re-enable display */
            vgaHWSeqReset(hwp, FALSE);  /* clear synchronousreset */

            hwp.disablePalette(hwp);
        }
    }
}

/*
 * vgaHWBlankScreen -- blank the screen.
 */

void vgaHWBlankScreen(ScrnInfoPtr pScrn, Bool on)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));
    ubyte scrn = void;

    scrn = hwp.readSeq(hwp, 0x01);

    if (on) {
        scrn &= ~0x20;          /* enable screen */
    }
    else {
        scrn |= 0x20;           /* blank screen */
    }

    vgaHWSeqReset(hwp, TRUE);
    hwp.writeSeq(hwp, 0x01, scrn);     /* change mode */
    vgaHWSeqReset(hwp, FALSE);
}

/*
 * vgaHWSaveScreen -- blank the screen.
 */

Bool vgaHWSaveScreen(ScreenPtr pScreen, int mode)
{
    ScrnInfoPtr pScrn = null;
    Bool on = void;

    if (pScreen !is null)
        pScrn = xf86ScreenToScrn(pScreen);

    on = xf86IsUnblank(mode);

version (none) {
    if (on)
        SetTimeSinceLastInputEvent();
}

    if ((pScrn !is null) && pScrn.vtSema) {
        vgaHWBlankScreen(pScrn, on);
    }
    return TRUE;
}

/*
 * vgaHWDPMSSet -- Sets VESA Display Power Management Signaling (DPMS) Mode
 *
 * This generic VGA function can only set the Off and On modes.  If the
 * Standby and Suspend modes are to be supported, a chip specific replacement
 * for this function must be written.
 */

void vgaHWDPMSSet(ScrnInfoPtr pScrn, int PowerManagementMode, int flags)
{
    ubyte seq1 = 0, crtc17 = 0;
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));

    if (!pScrn.vtSema)
        return;

    switch (PowerManagementMode) {
    case DPMSModeOn:
        /* Screen: On; HSync: On, VSync: On */
        seq1 = 0x00;
        crtc17 = 0x80;
        break;
    case DPMSModeStandby:
        /* Screen: Off; HSync: Off, VSync: On -- Not Supported */
        seq1 = 0x20;
        crtc17 = 0x80;
        break;
    case DPMSModeSuspend:
        /* Screen: Off; HSync: On, VSync: Off -- Not Supported */
        seq1 = 0x20;
        crtc17 = 0x80;
        break;
    case DPMSModeOff:
        /* Screen: Off; HSync: Off, VSync: Off */
        seq1 = 0x20;
        crtc17 = 0x00;
        break;
    default: break;}
    hwp.writeSeq(hwp, 0x00, 0x01);     /* Synchronous Reset */
    seq1 |= hwp.readSeq(hwp, 0x01) & ~0x20;
    hwp.writeSeq(hwp, 0x01, seq1);
    crtc17 |= hwp.readCrtc(hwp, 0x17) & ~0x80;
    usleep(10000);
    hwp.writeCrtc(hwp, 0x17, crtc17);
    hwp.writeSeq(hwp, 0x00, 0x03);     /* End Reset */
}

/*
 * vgaHWSeqReset
 *      perform a sequencer reset.
 */

void vgaHWSeqReset(vgaHWPtr hwp, Bool start)
{
    if (start)
        hwp.writeSeq(hwp, 0x00, 0x01); /* Synchronous Reset */
    else
        hwp.writeSeq(hwp, 0x00, 0x03); /* End Reset */
}

void vgaHWRestoreFonts(ScrnInfoPtr pScrnInfo, vgaRegPtr restore)
{
static if (SAVE_TEXT || SAVE_FONT1 || SAVE_FONT2) {
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    int savedIOBase = void;
    ubyte miscOut = void, attr10 = void, gr1 = void, gr3 = void, gr4 = void, gr5 = void, gr6 = void, gr8 = void, seq2 = void, seq4 = void;
    Bool doMap = FALSE;

    /* If nothing to do, return now */
    if (!hwp.FontInfo1 && !hwp.FontInfo2 && !hwp.TextInfo)
        return;

    if (hwp.Base is null) {
        doMap = TRUE;
        if (!vgaHWMapMem(pScrnInfo)) {
            xf86DrvMsg(pScrnInfo.scrnIndex, X_ERROR,
                       "vgaHWRestoreFonts: vgaHWMapMem() failed\n");
            return;
        }
    }

    /* save the registers that are needed here */
    miscOut = hwp.readMiscOut(hwp);
    attr10 = hwp.readAttr(hwp, 0x10);
    gr1 = hwp.readGr(hwp, 0x01);
    gr3 = hwp.readGr(hwp, 0x03);
    gr4 = hwp.readGr(hwp, 0x04);
    gr5 = hwp.readGr(hwp, 0x05);
    gr6 = hwp.readGr(hwp, 0x06);
    gr8 = hwp.readGr(hwp, 0x08);
    seq2 = hwp.readSeq(hwp, 0x02);
    seq4 = hwp.readSeq(hwp, 0x04);

    /* save hwp->IOBase and temporarily set it for colour mode */
    savedIOBase = hwp.IOBase;
    hwp.IOBase = VGA_IOBASE_COLOR;

    /* Force into colour mode */
    hwp.writeMiscOut(hwp, miscOut | 0x01);

    vgaHWBlankScreen(pScrnInfo, FALSE);

    /*
     * here we temporarily switch to 16 colour planar mode, to simply
     * copy the font-info and saved text.
     *
     * BUG ALERT: The (S)VGA's segment-select register MUST be set correctly!
     */
version (none) {
    hwp.writeAttr(hwp, 0x10, 0x01);    /* graphics mode */
}

    hwp.writeSeq(hwp, 0x04, 0x06);     /* enable plane graphics */
    hwp.writeGr(hwp, 0x05, 0x00);      /* write mode 0, read mode 0 */
    hwp.writeGr(hwp, 0x06, 0x05);      /* set graphics */

    if (pScrnInfo.depth == 4) {
        /* GJA */
        hwp.writeGr(hwp, 0x03, 0x00);  /* don't rotate, write unmodified */
        hwp.writeGr(hwp, 0x08, 0xFF);  /* write all bits in a byte */
        hwp.writeGr(hwp, 0x01, 0x00);  /* all planes come from CPU */
    }

static if (SAVE_FONT1) {
    if (hwp.FontInfo1) {
        hwp.writeSeq(hwp, 0x02, 0x04); /* write to plane 2 */
        hwp.writeGr(hwp, 0x04, 0x02);  /* read plane 2 */
        mixin(slowbcopy_tobus!("hwp.FontInfo1", "hwp.Base", "FONT_AMOUNT"));
    }
}

static if (SAVE_FONT2) {
    if (hwp.FontInfo2) {
        hwp.writeSeq(hwp, 0x02, 0x08); /* write to plane 3 */
        hwp.writeGr(hwp, 0x04, 0x03);  /* read plane 3 */
        mixin(slowbcopy_tobus!("hwp.FontInfo2", "hwp.Base", "FONT_AMOUNT"));
    }
}

static if (SAVE_TEXT) {
    if (hwp.TextInfo) {
        hwp.writeSeq(hwp, 0x02, 0x01); /* write to plane 0 */
        hwp.writeGr(hwp, 0x04, 0x00);  /* read plane 0 */
        mixin(slowbcopy_tobus!("hwp.TextInfo", "hwp.Base", "TEXT_AMOUNT"));
        hwp.writeSeq(hwp, 0x02, 0x02); /* write to plane 1 */
        hwp.writeGr(hwp, 0x04, 0x01);  /* read plane 1 */
        mixin(slowbcopy_tobus!("cast(ubyte*) hwp.TextInfo + TEXT_AMOUNT", "hwp.Base", "TEXT_AMOUNT"));
    }
}

    vgaHWBlankScreen(pScrnInfo, TRUE);

    /* restore the registers that were changed */
    hwp.writeMiscOut(hwp, miscOut);
    hwp.writeAttr(hwp, 0x10, attr10);
    hwp.writeGr(hwp, 0x01, gr1);
    hwp.writeGr(hwp, 0x03, gr3);
    hwp.writeGr(hwp, 0x04, gr4);
    hwp.writeGr(hwp, 0x05, gr5);
    hwp.writeGr(hwp, 0x06, gr6);
    hwp.writeGr(hwp, 0x08, gr8);
    hwp.writeSeq(hwp, 0x02, seq2);
    hwp.writeSeq(hwp, 0x04, seq4);
    hwp.IOBase = savedIOBase;

    if (doMap)
        vgaHWUnmapMem(pScrnInfo);

}                          /* SAVE_TEXT || SAVE_FONT1 || SAVE_FONT2 */
}

private void vgaHWRestoreMode(ScrnInfoPtr pScrnInfo, vgaRegPtr restore)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    int i = void;

    if (restore.MiscOutReg & 0x01)
        hwp.IOBase = VGA_IOBASE_COLOR;
    else
        hwp.IOBase = VGA_IOBASE_MONO;

    hwp.writeMiscOut(hwp, restore.MiscOutReg);

    for (i = 1; i < restore.numSequencer; i++)
        hwp.writeSeq(hwp, cast(ubyte)i, restore.Sequencer[i]);

    /* Ensure CRTC registers 0-7 are unlocked by clearing bit 7 of CRTC[17] */
    hwp.writeCrtc(hwp, 17, restore.CRTC[17] & ~0x80);

    for (i = 0; i < restore.numCRTC; i++)
        hwp.writeCrtc(hwp, cast(ubyte)i, restore.CRTC[i]);

    for (i = 0; i < restore.numGraphics; i++)
        hwp.writeGr(hwp, cast(ubyte)i, restore.Graphics[i]);

    hwp.enablePalette(hwp);
    for (i = 0; i < restore.numAttribute; i++)
        hwp.writeAttr(hwp, cast(ubyte)i, restore.Attribute[i]);
    hwp.disablePalette(hwp);
}

private void vgaHWRestoreColormap(ScrnInfoPtr pScrnInfo, vgaRegPtr restore)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    int i = void;

version (none) {
    hwp.enablePalette(hwp);
}

    hwp.writeDacMask(hwp, 0xFF);
    hwp.writeDacWriteAddr(hwp, 0x00);
    for (i = 0; i < 768; i++) {
        hwp.writeDacData(hwp, restore.DAC[i]);
        mixin(DACDelay!("hwp"));
    }

    hwp.disablePalette(hwp);
}

/*
 * vgaHWRestore --
 *      restore the VGA state
 */

void vgaHWRestore(ScrnInfoPtr pScrnInfo, vgaRegPtr restore, int flags)
{
    if (flags & VGA_SR_MODE)
        vgaHWRestoreMode(pScrnInfo, restore);

    if (flags & VGA_SR_FONTS)
        vgaHWRestoreFonts(pScrnInfo, restore);

    if (flags & VGA_SR_CMAP)
        vgaHWRestoreColormap(pScrnInfo, restore);
}

void vgaHWSaveFonts(ScrnInfoPtr pScrnInfo, vgaRegPtr save)
{
static if  (SAVE_TEXT || SAVE_FONT1 || SAVE_FONT2) {
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    int savedIOBase = void;
    ubyte miscOut = void, attr10 = void, gr4 = void, gr5 = void, gr6 = void, seq2 = void, seq4 = void;
    Bool doMap = FALSE;

    if (hwp.Base is null) {
        doMap = TRUE;
        if (!vgaHWMapMem(pScrnInfo)) {
            xf86DrvMsg(pScrnInfo.scrnIndex, X_ERROR,
                       "vgaHWSaveFonts: vgaHWMapMem() failed\n");
            return;
        }
    }

    /* If in graphics mode, don't save anything */
    attr10 = hwp.readAttr(hwp, 0x10);
    if (attr10 & 0x01)
        return;

    /* save the registers that are needed here */
    miscOut = hwp.readMiscOut(hwp);
    gr4 = hwp.readGr(hwp, 0x04);
    gr5 = hwp.readGr(hwp, 0x05);
    gr6 = hwp.readGr(hwp, 0x06);
    seq2 = hwp.readSeq(hwp, 0x02);
    seq4 = hwp.readSeq(hwp, 0x04);

    /* save hwp->IOBase and temporarily set it for colour mode */
    savedIOBase = hwp.IOBase;
    hwp.IOBase = VGA_IOBASE_COLOR;

    /* Force into colour mode */
    hwp.writeMiscOut(hwp, miscOut | 0x01);

    vgaHWBlankScreen(pScrnInfo, FALSE);

    /*
     * get the character sets, and text screen if required
     */
    /*
     * Here we temporarily switch to 16 colour planar mode, to simply
     * copy the font-info
     *
     * BUG ALERT: The (S)VGA's segment-select register MUST be set correctly!
     */
version (none) {
    hwp.writeAttr(hwp, 0x10, 0x01);    /* graphics mode */
}

    hwp.writeSeq(hwp, 0x04, 0x06);     /* enable plane graphics */
    hwp.writeGr(hwp, 0x05, 0x00);      /* write mode 0, read mode 0 */
    hwp.writeGr(hwp, 0x06, 0x05);      /* set graphics */

static if (SAVE_FONT1) {
    if (hwp.FontInfo1 || (hwp.FontInfo1 = calloc(1, FONT_AMOUNT)) !is null) {
        hwp.writeSeq(hwp, 0x02, 0x04); /* write to plane 2 */
        hwp.writeGr(hwp, 0x04, 0x02);  /* read plane 2 */
        mixin(slowbcopy_frombus!("hwp.Base", "hwp.FontInfo1", "FONT_AMOUNT"));
    }
}                          /* SAVE_FONT1 */
static if (SAVE_FONT2) {
    if (hwp.FontInfo2 || (hwp.FontInfo2 = calloc(1, FONT_AMOUNT))!is null) {
        hwp.writeSeq(hwp, 0x02, 0x08); /* write to plane 3 */
        hwp.writeGr(hwp, 0x04, 0x03);  /* read plane 3 */
        mixin(slowbcopy_frombus!("hwp.Base", "hwp.FontInfo2", "FONT_AMOUNT"));
    }
}                          /* SAVE_FONT2 */
static if (SAVE_TEXT) {
    if (hwp.TextInfo || (hwp.TextInfo = calloc(2, TEXT_AMOUNT))!is null) {
        hwp.writeSeq(hwp, 0x02, 0x01); /* write to plane 0 */
        hwp.writeGr(hwp, 0x04, 0x00);  /* read plane 0 */
        mixin(slowbcopy_frombus!("hwp.Base", "hwp.TextInfo", "TEXT_AMOUNT"));
        hwp.writeSeq(hwp, 0x02, 0x02); /* write to plane 1 */
        hwp.writeGr(hwp, 0x04, 0x01);  /* read plane 1 */
        mixin(slowbcopy_frombus!("hwp.Base", "cast(ubyte*) hwp.TextInfo + TEXT_AMOUNT", "TEXT_AMOUNT"));
    }
}                          /* SAVE_TEXT */

    /* Restore clobbered registers */
    hwp.writeAttr(hwp, 0x10, attr10);
    hwp.writeSeq(hwp, 0x02, seq2);
    hwp.writeSeq(hwp, 0x04, seq4);
    hwp.writeGr(hwp, 0x04, gr4);
    hwp.writeGr(hwp, 0x05, gr5);
    hwp.writeGr(hwp, 0x06, gr6);
    hwp.writeMiscOut(hwp, miscOut);
    hwp.IOBase = savedIOBase;

    vgaHWBlankScreen(pScrnInfo, TRUE);

    if (doMap)
        vgaHWUnmapMem(pScrnInfo);

}                          /* SAVE_TEXT || SAVE_FONT1 || SAVE_FONT2 */
}

private void vgaHWSaveMode(ScrnInfoPtr pScrnInfo, vgaRegPtr save)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    int i = void;

    save.MiscOutReg = hwp.readMiscOut(hwp);
    if (save.MiscOutReg & 0x01)
        hwp.IOBase = VGA_IOBASE_COLOR;
    else
        hwp.IOBase = VGA_IOBASE_MONO;

    for (i = 0; i < save.numCRTC; i++) {
        save.CRTC[i] = hwp.readCrtc(hwp, cast(ubyte)i);
        DebugF("CRTC[0x%02x] = 0x%02x\n", i, save.CRTC[i]);
    }

    hwp.enablePalette(hwp);
    for (i = 0; i < save.numAttribute; i++) {
        save.Attribute[i] = hwp.readAttr(hwp, cast(ubyte)i);
        DebugF("Attribute[0x%02x] = 0x%02x\n", i, save.Attribute[i]);
    }
    hwp.disablePalette(hwp);

    for (i = 0; i < save.numGraphics; i++) {
        save.Graphics[i] = hwp.readGr(hwp, cast(ubyte)i);
        DebugF("Graphics[0x%02x] = 0x%02x\n", i, save.Graphics[i]);
    }

    for (i = 1; i < save.numSequencer; i++) {
        save.Sequencer[i] = hwp.readSeq(hwp, cast(ubyte)i);
        DebugF("Sequencer[0x%02x] = 0x%02x\n", i, save.Sequencer[i]);
    }
}

private void vgaHWSaveColormap(ScrnInfoPtr pScrnInfo, vgaRegPtr save)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    Bool readError = FALSE;
    int i = void;

version (NEED_SAVED_CMAP) {
    /*
     * Some ET4000 chips from 1991 have a HW bug that prevents the reading
     * of the color lookup table.  Mask rev 9042EAI is known to have this bug.
     *
     * If the colourmap is not readable, we set the saved map to a default
     * map (taken from Ferraro's "Programmer's Guide to the EGA and VGA
     * Cards" 2nd ed).
     */

    /* Only save it once */
    if (hwp.cmapSaved)
        return;

version (none) {
    hwp.enablePalette(hwp);
}

    hwp.writeDacMask(hwp, 0xFF);

    /*
     * check if we can read the lookup table
     */
    hwp.writeDacReadAddr(hwp, 0x00);
    for (i = 0; i < 6; i++) {
        save.DAC[i] = hwp.readDacData(hwp);
        switch (i % 3) {
        case 0:
            DebugF("DAC[0x%02x] = 0x%02x, ", i / 3, save.DAC[i]);
            break;
        case 1:
            DebugF("0x%02x, ", save.DAC[i]);
            break;
        case 2:
            DebugF("0x%02x\n", save.DAC[i]);
        default: break;}
    }

    /*
     * Check if we can read the palette -
     * use foreground color to prevent flashing.
     */
    hwp.writeDacWriteAddr(hwp, 0x01);
    for (i = 3; i < 6; i++)
        hwp.writeDacData(hwp, ~save.DAC[i] & DAC_TEST_MASK);
    hwp.writeDacReadAddr(hwp, 0x01);
    for (i = 3; i < 6; i++) {
        if (hwp.readDacData(hwp) != (~save.DAC[i] & DAC_TEST_MASK))
            readError = TRUE;
    }
    hwp.writeDacWriteAddr(hwp, 0x01);
    for (i = 3; i < 6; i++)
        hwp.writeDacData(hwp, save.DAC[i]);

    if (readError) {
        /*
         * save the default lookup table
         */
        memmove(save.DAC, defaultDAC.ptr, 768);
        xf86DrvMsg(pScrnInfo.scrnIndex, X_WARNING,
                   "Cannot read colourmap from VGA.  Will restore with default\n");
    }
    else {
        /* save the colourmap */
        hwp.writeDacReadAddr(hwp, 0x02);
        for (i = 6; i < 768; i++) {
            save.DAC[i] = hwp.readDacData(hwp);
            mixin(DACDelay!("hwp"));
            switch (i % 3) {
            case 0:
                DebugF("DAC[0x%02x] = 0x%02x, ", i / 3, save.DAC[i]);
                break;
            case 1:
                DebugF("0x%02x, ", save.DAC[i]);
                break;
            case 2:
                DebugF("0x%02x\n", save.DAC[i]);
            default: break;}
        }
    }

    hwp.disablePalette(hwp);
    hwp.cmapSaved = TRUE;
}
}

/*
 * vgaHWSave --
 *      save the current VGA state
 */

void vgaHWSave(ScrnInfoPtr pScrnInfo, vgaRegPtr save, int flags)
{
    if (save is null)
        return;

    if (flags & VGA_SR_CMAP)
        vgaHWSaveColormap(pScrnInfo, save);

    if (flags & VGA_SR_MODE)
        vgaHWSaveMode(pScrnInfo, save);

    if (flags & VGA_SR_FONTS)
        vgaHWSaveFonts(pScrnInfo, save);
}

/*
 * vgaHWInit --
 *      Handle the initialization, etc. of a screen.
 *      Return FALSE on failure.
 */

Bool vgaHWInit(ScrnInfoPtr pScrnInfo, DisplayModePtr mode)
{
    uint i = void;
    vgaHWPtr hwp = void;
    vgaRegPtr regp = void;
    int depth = pScrnInfo.depth;

    /*
     * make sure the vgaHWRec is allocated
     */
    if (!vgaHWGetHWRec(pScrnInfo))
        return FALSE;
    hwp = mixin(VGAHWPTR!(`pScrnInfo`));
    regp = &hwp.ModeReg;

    /*
     * compute correct Hsync & Vsync polarity
     */
    if ((mode.Flags & (V_PHSYNC | V_NHSYNC))
        && (mode.Flags & (V_PVSYNC | V_NVSYNC))) {
        regp.MiscOutReg = 0x23;
        if (mode.Flags & V_NHSYNC)
            regp.MiscOutReg |= 0x40;
        if (mode.Flags & V_NVSYNC)
            regp.MiscOutReg |= 0x80;
    }
    else {
        int VDisplay = mode.VDisplay;

        if (mode.Flags & V_DBLSCAN)
            VDisplay *= 2;
        if (mode.VScan > 1)
            VDisplay *= mode.VScan;
        if (VDisplay < 400)
            regp.MiscOutReg = 0xA3;    /* +hsync -vsync */
        else if (VDisplay < 480)
            regp.MiscOutReg = 0x63;    /* -hsync +vsync */
        else if (VDisplay < 768)
            regp.MiscOutReg = 0xE3;    /* -hsync -vsync */
        else
            regp.MiscOutReg = 0x23;    /* +hsync +vsync */
    }

    regp.MiscOutReg |= (mode.ClockIndex & 0x03) << 2;

    /*
     * Time Sequencer
     */
    if (depth == 4)
        regp.Sequencer[0] = 0x02;
    else
        regp.Sequencer[0] = 0x00;
    if (mode.Flags & V_CLKDIV2)
        regp.Sequencer[1] = 0x09;
    else
        regp.Sequencer[1] = 0x01;
    if (depth == 1)
        regp.Sequencer[2] = 1 << BIT_PLANE;
    else
        regp.Sequencer[2] = 0x0F;
    regp.Sequencer[3] = 0x00;  /* Font select */
    if (depth < 8)
        regp.Sequencer[4] = 0x06;      /* Misc */
    else
        regp.Sequencer[4] = 0x0E;      /* Misc */

    /*
     * CRTC Controller
     */
    regp.CRTC[0] = cast(ubyte)((mode.CrtcHTotal >> 3) - 5);
    regp.CRTC[1] = cast(ubyte)((mode.CrtcHDisplay >> 3) - 1);
    regp.CRTC[2] = cast(ubyte)((mode.CrtcHBlankStart >> 3) - 1);
    regp.CRTC[3] = cast(ubyte)((((mode.CrtcHBlankEnd >> 3) - 1) & 0x1F) | 0x80);
    i = (((mode.CrtcHSkew << 2) + 0x10) & ~0x1F);
    if (i < 0x80)
        regp.CRTC[3] |= i;
    regp.CRTC[4] = cast(ubyte)((mode.CrtcHSyncStart >> 3));
    regp.CRTC[5] = cast(ubyte)(((((mode.CrtcHBlankEnd >> 3) - 1) & 0x20) << 2))
        | (((mode.CrtcHSyncEnd >> 3)) & 0x1F);
    regp.CRTC[6] = cast(ubyte)((mode.CrtcVTotal - 2) & 0xFF);
    regp.CRTC[7] = cast(ubyte)((((mode.CrtcVTotal - 2) & 0x100) >> 8))
        | (((mode.CrtcVDisplay - 1) & 0x100) >> 7)
        | ((mode.CrtcVSyncStart & 0x100) >> 6)
        | (((mode.CrtcVBlankStart - 1) & 0x100) >> 5)
        | 0x10 | (((mode.CrtcVTotal - 2) & 0x200) >> 4)
        | (((mode.CrtcVDisplay - 1) & 0x200) >> 3)
        | ((mode.CrtcVSyncStart & 0x200) >> 2);
    regp.CRTC[8] = cast(ubyte)(0x00);
    regp.CRTC[9] = cast(ubyte)((((mode.CrtcVBlankStart - 1) & 0x200) >> 4) | 0x40);
    if (mode.Flags & V_DBLSCAN)
        regp.CRTC[9] |= cast(ubyte)(0x80);
    if (mode.VScan >= cast(ubyte)(32))
        regp.CRTC[9] |= cast(ubyte)(0x1F);
    else if (mode.VScan > 1)
        regp.CRTC[9] |= cast(ubyte)(mode.VScan - 1);
    regp.CRTC[10] = cast(ubyte)(0x00);
    regp.CRTC[11] = cast(ubyte)(0x00);
    regp.CRTC[12] = cast(ubyte)(0x00);
    regp.CRTC[13] = cast(ubyte)(0x00);
    regp.CRTC[14] = cast(ubyte)(0x00);
    regp.CRTC[15] = cast(ubyte)(0x00);
    regp.CRTC[16] = cast(ubyte)(mode.CrtcVSyncStart & 0xFF);
    regp.CRTC[17] = cast(ubyte)((mode.CrtcVSyncEnd & 0x0F) | 0x20);
    regp.CRTC[18] = cast(ubyte)((mode.CrtcVDisplay - 1) & 0xFF);
    regp.CRTC[19] = cast(ubyte)(pScrnInfo.displayWidth >> 4);       /* just a guess */
    regp.CRTC[20] = cast(ubyte)(0x00);
    regp.CRTC[21] = cast(ubyte)((mode.CrtcVBlankStart - 1) & 0xFF);
    regp.CRTC[22] = cast(ubyte)((mode.CrtcVBlankEnd - 1) & 0xFF);
    if (depth < 8)
        regp.CRTC[23] = cast(ubyte)(0xE3);
    else
        regp.CRTC[23] = cast(ubyte)(0xC3);
    regp.CRTC[24] = cast(ubyte)(0xFF);

    vgaHWHBlankKGA(mode, regp, 0, KGA_FIX_OVERSCAN | KGA_ENABLE_ON_ZERO);
    vgaHWVBlankKGA(mode, regp, 0, KGA_FIX_OVERSCAN | KGA_ENABLE_ON_ZERO);

    /*
     * Theory resumes here....
     */

    /*
     * Graphics Display Controller
     */
    regp.Graphics[0] = 0x00;
    regp.Graphics[1] = 0x00;
    regp.Graphics[2] = 0x00;
    regp.Graphics[3] = 0x00;
    if (depth == 1) {
        regp.Graphics[4] = BIT_PLANE;
        regp.Graphics[5] = 0x00;
    }
    else {
        regp.Graphics[4] = 0x00;
        if (depth == 4)
            regp.Graphics[5] = 0x02;
        else
            regp.Graphics[5] = 0x40;
    }
    regp.Graphics[6] = 0x05;   /* only map 64k VGA memory !!!! */
    regp.Graphics[7] = 0x0F;
    regp.Graphics[8] = 0xFF;

    if (depth == 1) {
        /* Initialise the Mono map according to which bit-plane gets used */

        for (i = 0; i < 16; i++)
            if (((i & (1 << BIT_PLANE)) != 0) != xf86FlipPixels)
                regp.Attribute[i] = WHITE_VALUE;
            else
                regp.Attribute[i] = BLACK_VALUE;

        regp.Attribute[16] = 0x01;     /* -VGA2- *//* wrong for the ET4000 */
        if (!hwp.ShowOverscan)
            regp.Attribute[OVERSCAN] = OVERSCAN_VALUE; /* -VGA2- */
    }
    else {
        regp.Attribute[0] = 0x00;      /* standard colormap translation */
        regp.Attribute[1] = 0x01;
        regp.Attribute[2] = 0x02;
        regp.Attribute[3] = 0x03;
        regp.Attribute[4] = 0x04;
        regp.Attribute[5] = 0x05;
        regp.Attribute[6] = 0x06;
        regp.Attribute[7] = 0x07;
        regp.Attribute[8] = 0x08;
        regp.Attribute[9] = 0x09;
        regp.Attribute[10] = 0x0A;
        regp.Attribute[11] = 0x0B;
        regp.Attribute[12] = 0x0C;
        regp.Attribute[13] = 0x0D;
        regp.Attribute[14] = 0x0E;
        regp.Attribute[15] = 0x0F;
        if (depth == 4)
            regp.Attribute[16] = 0x81; /* wrong for the ET4000 */
        else
            regp.Attribute[16] = 0x41; /* wrong for the ET4000 */
        /* Attribute[17] (overscan) initialised in vgaHWGetHWRec() */
    }
    regp.Attribute[18] = 0x0F;
    regp.Attribute[19] = 0x00;
    regp.Attribute[20] = 0x00;

    return TRUE;
}

    /*
     * OK, so much for theory.  Now, let's deal with the >real< world...
     *
     * The above CRTC settings are precise in theory, except that many, if not
     * most, VGA clones fail to reset the blanking signal when the character or
     * line counter reaches [HV]Total.  In this case, the signal is only
     * unblanked when the counter reaches [HV]BlankEnd (mod 64, 128 or 256 as
     * the case may be) at the start of the >next< scanline or frame, which
     * means only part of the screen shows.  This affects how null overscans
     * are to be implemented on such adapters.
     *
     * Henceforth, VGA cores that implement this broken, but unfortunately
     * common, behaviour are to be designated as KGA's, in honour of Koen
     * Gadeyne, whose zeal to eliminate overscans (read: fury) set in motion
     * a series of events that led to the discovery of this problem.
     *
     * Some VGA's are KGA's only in the horizontal, or only in the vertical,
     * some in both, others in neither.  Don't let anyone tell you there is
     * such a thing as a VGA "standard"...  And, thank the Creator for the fact
     * that Hilbert spaces are not yet implemented in this industry.
     *
     * The following implements a trick suggested by David Dawes.  This sets
     * [HV]BlankEnd to zero if the blanking interval does not already contain a
     * 0-point, and decrements it by one otherwise.  In the latter case, this
     * will produce a left and/or top overscan which the colourmap code will
     * (still) need to ensure is as close to black as possible.  This will make
     * the behaviour consistent across all chipsets, while allowing all
     * chipsets to display the entire screen.  Non-KGA drivers can ignore the
     * following in their own copy of this code.
     *
     * --  TSI @ UQV,  1998.08.21
     */

alias CARD32 = x11.Xmd.CARD32;

CARD32 vgaHWHBlankKGA(DisplayModePtr mode, vgaRegPtr regp, int nBits, uint Flags)
{
    int nExtBits = (nBits < 6) ? 0 : nBits - 6;
    CARD32 ExtBits = void;
    CARD32 ExtBitMask = ((1 << nExtBits) - 1) << 6;

    regp.CRTC[3] = (regp.CRTC[3] & ~0x1F)
        | (((mode.CrtcHBlankEnd >> 3) - 1) & 0x1F);
    regp.CRTC[5] = (regp.CRTC[5] & ~0x80)
        | ((((mode.CrtcHBlankEnd >> 3) - 1) & 0x20) << 2);
    ExtBits = ((mode.CrtcHBlankEnd >> 3) - 1) & ExtBitMask;

    /* First the horizontal case */
    if ((Flags & KGA_FIX_OVERSCAN)
        && ((mode.CrtcHBlankEnd >> 3) == (mode.CrtcHTotal >> 3))) {
        int i = cast(int)((regp.CRTC[3] & 0x1F)
            | ((regp.CRTC[5] & 0x80) >> 2)
            | ExtBits);

        if (Flags & KGA_ENABLE_ON_ZERO) {
            if ((i-- > (((mode.CrtcHBlankStart >> 3) - 1)
                        & (0x3F | ExtBitMask)))
                && (mode.CrtcHBlankEnd == mode.CrtcHTotal))
                i = 0;
        }
        else if (Flags & KGA_BE_TOT_DEC)
            i--;
        regp.CRTC[3] = (regp.CRTC[3] & ~0x1F) | (i & 0x1F);
        regp.CRTC[5] = (regp.CRTC[5] & ~0x80) | ((i << 2) & 0x80);
        ExtBits = i & ExtBitMask;
    }
    return ExtBits >> 6;
}

    /*
     * The vertical case is a little trickier.  Some VGA's ignore bit 0x80 of
     * CRTC[22].  Also, in some cases, a zero CRTC[22] will still blank the
     * very first scanline in a double- or multi-scanned mode.  This last case
     * needs further investigation.
     */
CARD32 vgaHWVBlankKGA(DisplayModePtr mode, vgaRegPtr regp, int nBits, uint Flags)
{
    CARD32 ExtBits = void;
    CARD32 nExtBits = (nBits < 8) ? 0 : (nBits - 8);
    CARD32 ExtBitMask = ((1 << nExtBits) - 1) << 8;

    /* If width is not known nBits should be 0. In this
     * case BitMask is set to 0 so we can check for it. */
    CARD32 BitMask = (nBits < 7) ? 0 : ((1 << nExtBits) - 1);
    int VBlankStart = (mode.CrtcVBlankStart - 1) & 0xFF;

    regp.CRTC[22] = (mode.CrtcVBlankEnd - 1) & 0xFF;
    ExtBits = (mode.CrtcVBlankEnd - 1) & ExtBitMask;

    if ((Flags & KGA_FIX_OVERSCAN)
        && (mode.CrtcVBlankEnd == mode.CrtcVTotal))
        /* Null top overscan */
    {
        int i = cast(int)(regp.CRTC[22] | ExtBits);

        if (Flags & KGA_ENABLE_ON_ZERO) {
            if (((BitMask && ((i & BitMask) > (VBlankStart & BitMask)))
                 || ((i > VBlankStart) &&       /* 8-bit case */
                     ((i & 0x7F) > (VBlankStart & 0x7F)))) &&   /* 7-bit case */
                !(regp.CRTC[9] & 0x9F))        /* 1 scanline/row */
                i = 0;
            else
                i = (i - 1);
        }
        else if (Flags & KGA_BE_TOT_DEC)
            i = (i - 1);

        regp.CRTC[22] = i & 0xFF;
        ExtBits = i & 0xFF00;
    }
    return ExtBits >> 8;
}

/*
 * these are some more hardware specific helpers, formerly in vga.c
 */
private void vgaHWGetHWRecPrivate()
{
    if (vgaHWPrivateIndex < 0)
        vgaHWPrivateIndex = xf86AllocateScrnInfoPrivateIndex();
    return;
}

private void vgaHWFreeRegs(vgaRegPtr regp)
{
    free(regp.CRTC);

    regp.CRTC = regp.Sequencer = regp.Graphics = regp.Attribute = null;

    regp.numCRTC =
        regp.numSequencer = regp.numGraphics = regp.numAttribute = 0;
}

private Bool vgaHWAllocRegs(vgaRegPtr regp)
{
    ubyte* buf = void;

    if ((regp.numCRTC + regp.numSequencer + regp.numGraphics +
         regp.numAttribute) == 0)
        return FALSE;

    buf = cast(ubyte*) calloc(regp.numCRTC +
                 regp.numSequencer +
                 regp.numGraphics + regp.numAttribute, 1);
    if (!buf)
        return FALSE;

    regp.CRTC = buf;
    regp.Sequencer = regp.CRTC + regp.numCRTC;
    regp.Graphics = regp.Sequencer + regp.numSequencer;
    regp.Attribute = regp.Graphics + regp.numGraphics;

    return TRUE;
}

Bool vgaHWAllocDefaultRegs(vgaRegPtr regp)
{
    regp.numCRTC = VGA_NUM_CRTC;
    regp.numSequencer = VGA_NUM_SEQ;
    regp.numGraphics = VGA_NUM_GFX;
    regp.numAttribute = VGA_NUM_ATTR;

    return vgaHWAllocRegs(regp);
}

Bool vgaHWCopyReg(vgaRegPtr dst, vgaRegPtr src)
{
    vgaHWFreeRegs(dst);

    memcpy(dst, src, vgaRegRec.sizeof);

    if (!vgaHWAllocRegs(dst))
        return FALSE;

    memcpy(dst.CRTC, src.CRTC, src.numCRTC);
    memcpy(dst.Sequencer, src.Sequencer, src.numSequencer);
    memcpy(dst.Graphics, src.Graphics, src.numGraphics);
    memcpy(dst.Attribute, src.Attribute, src.numAttribute);

    return TRUE;
}

Bool vgaHWGetHWRec(ScrnInfoPtr scrp)
{
    vgaRegPtr regp = void;
    vgaHWPtr hwp = void;
    int i = void;

    /*
     * Let's make sure that the private exists and allocate one.
     */
    vgaHWGetHWRecPrivate();
    /*
     * New privates are always set to NULL, so we can check if the allocation
     * has already been done.
     */
    if (mixin(VGAHWPTR!(`scrp`)))
        return TRUE;
    hwp = cast(_vgaHWRec*)XNFcallocarray(1, vgaHWRec.sizeof);
    mixin(VGAHWPTRLVAL!(`scrp`)) = hwp;

    regp = &hwp.ModeReg;

    if ((!vgaHWAllocDefaultRegs(&mixin(VGAHWPTR!(`scrp`)).SavedReg)) ||
        (!vgaHWAllocDefaultRegs(&mixin(VGAHWPTR!(`scrp`)).ModeReg))) {
        free(hwp);
        return FALSE;
    }

    if (scrp.bitsPerPixel == 1) {
        rgb blackColour = scrp.display.blackColour, whiteColour = scrp.display.whiteColour;

        if (blackColour.red > 0x3F)
            blackColour.red = 0x3F;
        if (blackColour.green > 0x3F)
            blackColour.green = 0x3F;
        if (blackColour.blue > 0x3F)
            blackColour.blue = 0x3F;

        if (whiteColour.red > 0x3F)
            whiteColour.red = 0x3F;
        if (whiteColour.green > 0x3F)
            whiteColour.green = 0x3F;
        if (whiteColour.blue > 0x3F)
            whiteColour.blue = 0x3F;

        if ((blackColour.red == whiteColour.red) &&
            (blackColour.green == whiteColour.green) &&
            (blackColour.blue == whiteColour.blue)) {
            blackColour.red ^= 0x3F;
            blackColour.green ^= 0x3F;
            blackColour.blue ^= 0x3F;
        }

        /*
         * initialize default colormap for monochrome
         */
        for (i = 0; i < 3; i++)
            regp.DAC[i] = 0x00;
        for (i = 3; i < 768; i++)
            regp.DAC[i] = 0x3F;
        i = BLACK_VALUE * 3;
        regp.DAC[i++] = cast(ubyte)blackColour.red;
        regp.DAC[i++] = cast(ubyte)blackColour.green;
        regp.DAC[i] = cast(ubyte)blackColour.blue;
        i = WHITE_VALUE * 3;
        regp.DAC[i++] = cast(ubyte)whiteColour.red;
        regp.DAC[i++] = cast(ubyte)whiteColour.green;
        regp.DAC[i] = cast(ubyte)whiteColour.blue;
        i = OVERSCAN_VALUE * 3;
        regp.DAC[i++] = 0x00;
        regp.DAC[i++] = 0x00;
        regp.DAC[i] = 0x00;
    }
    else {
        /* Set all colours to black */
        for (i = 0; i < 768; i++)
            regp.DAC[i] = 0x00;
        /* ... and the overscan */
        if (scrp.depth >= 4)
            regp.Attribute[OVERSCAN] = 0xFF;
    }
    if (xf86FindOption(cast(_InputOption*)scrp.confScreen.options, "ShowOverscan")) {
        xf86MarkOptionUsedByName(cast(_InputOption*)scrp.confScreen.options, "ShowOverscan");
        xf86DrvMsg(scrp.scrnIndex, X_CONFIG, "Showing overscan area\n");
        regp.DAC[765] = 0x3F;
        regp.DAC[766] = 0x00;
        regp.DAC[767] = 0x3F;
        regp.Attribute[OVERSCAN] = 0xFF;
        hwp.ShowOverscan = TRUE;
    }
    else
        hwp.ShowOverscan = FALSE;

    hwp.paletteEnabled = FALSE;
    hwp.cmapSaved = FALSE;
    hwp.MapSize = 0;
    hwp.pScrn = scrp;

    hwp.dev = xf86GetPciInfoForEntity(scrp.entityList[0]);

    return TRUE;
}

void vgaHWFreeHWRec(ScrnInfoPtr scrp)
{
    if (vgaHWPrivateIndex >= 0) {
        vgaHWPtr hwp = mixin(VGAHWPTR!(`scrp`));

        if (!hwp)
            return;

        pci_device_close_io(hwp.dev, hwp.io);

        free(hwp.FontInfo1);
        free(hwp.FontInfo2);
        free(hwp.TextInfo);

        vgaHWFreeRegs(&hwp.ModeReg);
        vgaHWFreeRegs(&hwp.SavedReg);

        free(hwp);
        mixin(VGAHWPTRLVAL!(`scrp`)) = null;
    }
}

Bool vgaHWMapMem(ScrnInfoPtr scrp)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`scrp`));

    if (hwp.Base)
        return TRUE;

    /* If not set, initialise with the defaults */
    if (hwp.MapSize == 0)
        hwp.MapSize = VGA_DEFAULT_MEM_SIZE;
    if (hwp.MapPhys == 0)
        hwp.MapPhys = VGA_DEFAULT_PHYS_ADDR;

    /*
     * Map as VIDMEM_MMIO_32BIT because WC
     * is bad when there is page flipping.
     * XXX This is not correct but we do it
     * for now.
     */
    DebugF("Mapping VGAMem\n");
    pci_device_map_legacy(hwp.dev, hwp.MapPhys, hwp.MapSize,
                          PCI_DEV_MAP_FLAG_WRITABLE, &hwp.Base);
    return hwp.Base !is null;
}

void vgaHWUnmapMem(ScrnInfoPtr scrp)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`scrp`));

    if (hwp.Base is null)
        return;

    DebugF("Unmapping VGAMem\n");
    pci_device_unmap_legacy(hwp.dev, hwp.Base, hwp.MapSize);
    hwp.Base = null;
}

int vgaHWGetIndex()
{
    return vgaHWPrivateIndex;
}

void vgaHWGetIOBase(vgaHWPtr hwp)
{
    hwp.IOBase = (hwp.readMiscOut(hwp) & 0x01) ?
        VGA_IOBASE_COLOR : VGA_IOBASE_MONO;
    xf86DrvMsgVerb(hwp.pScrn.scrnIndex, X_INFO, 3,
                   "vgaHWGetIOBase: hwp->IOBase is 0x%04x\n", hwp.IOBase);
}

void vgaHWLock(vgaHWPtr hwp)
{
    /* Protect CRTC[0-7] */
    hwp.writeCrtc(hwp, 0X11, hwp.readCrtc(hwp, 0X11) | 0x80);
}

void vgaHWUnlock(vgaHWPtr hwp)
{
    /* Unprotect CRTC[0-7] */
    hwp.writeCrtc(hwp, 0X11, hwp.readCrtc(hwp, 0X11) & ~0x80);
}

void vgaHWEnable(vgaHWPtr hwp)
{
    hwp.writeEnable(hwp, hwp.readEnable(hwp) | 0x01);
}

private void vgaHWLoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));
    int i = void, index = void;

    for (i = 0; i < numColors; i++) {
        index = indices[i];
        hwp.writeDacWriteAddr(hwp, cast(ubyte)index);
        mixin(DACDelay!("hwp"));
        hwp.writeDacData(hwp, cast(ubyte)colors[index].red);
        mixin(DACDelay!("hwp"));
        hwp.writeDacData(hwp, cast(ubyte)colors[index].green);
        mixin(DACDelay!("hwp"));
        hwp.writeDacData(hwp, cast(ubyte)colors[index].blue);
        mixin(DACDelay!("hwp"));
    }

    /* This shouldn't be necessary, but we'll play safe. */
    hwp.disablePalette(hwp);
}

private void vgaHWSetOverscan(ScrnInfoPtr pScrn, int overscan)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));

    if (overscan < 0 || overscan > 255)
        return;

    hwp.enablePalette(hwp);
    hwp.writeAttr(hwp, OVERSCAN, cast(ubyte)overscan);

version (DEBUGOVERSCAN) {
    {
        int ov = hwp.readAttr(hwp, OVERSCAN);
        int red = void, green = void, blue = void;

        hwp.writeDacReadAddr(hwp, ov);
        red = hwp.readDacData(hwp);
        green = hwp.readDacData(hwp);
        blue = hwp.readDacData(hwp);
        ErrorF("Overscan index is 0x%02x, colours are #%02x%02x%02x\n",
               ov, red, green, blue);
    }
}

    hwp.disablePalette(hwp);
}

Bool vgaHWHandleColormaps(ScreenPtr pScreen)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    if (pScrn.depth > 1 && pScrn.depth <= 8) {
        return xf86HandleColormaps(pScreen, 1 << pScrn.depth,
                                   pScrn.rgbBits, &vgaHWLoadPalette,
                                   pScrn.depth > 4 ? &vgaHWSetOverscan : null,
                                   CMAP_RELOAD_ON_MODE_SWITCH);
    }
    return TRUE;
}

/* ----------------------- DDC support ------------------------*/
/*
 * Adjust v_active, v_blank, v_sync, v_sync_end, v_blank_end, v_total
 * to read out EDID at a faster rate. Allowed maximum is 25kHz with
 * 20 usec v_sync active. Set positive v_sync polarity, turn off lightpen
 * readback, enable access to cr00-cr07.
 */

/* vertical timings */
enum DISPLAY_END = 0x04;
enum BLANK_START = DISPLAY_END;
enum SYNC_START = BLANK_START;
enum SYNC_END = 0x09;
enum BLANK_END = SYNC_END;
enum V_TOTAL = BLANK_END;
/* this function doesn't have to be reentrant for our purposes */
struct _vgaDdcSave {
    ubyte cr03;
    ubyte cr06;
    ubyte cr07;
    ubyte cr09;
    ubyte cr10;
    ubyte cr11;
    ubyte cr12;
    ubyte cr15;
    ubyte cr16;
    ubyte msr;
}

void vgaHWddc1SetSpeed(ScrnInfoPtr pScrn, xf86ddcSpeed speed)
{
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));
    ubyte tmp = void;
    _vgaDdcSave* save = void;

    switch (speed) {
    case DDC_FAST:

        if (hwp.ddc !is null)
            break;
        hwp.ddc = XNFcallocarray(1, _vgaDdcSave.sizeof);
        save = cast(_vgaDdcSave*) hwp.ddc;
        /* Lightpen register disable - allow access to cr10 & 11; just in case */
        save.cr03 = hwp.readCrtc(hwp, 0x03);
        hwp.writeCrtc(hwp, 0x03, (save.cr03 | 0x80));
        save.cr12 = hwp.readCrtc(hwp, 0x12);
        hwp.writeCrtc(hwp, 0x12, DISPLAY_END);
        save.cr15 = hwp.readCrtc(hwp, 0x15);
        hwp.writeCrtc(hwp, 0x15, BLANK_START);
        save.cr10 = hwp.readCrtc(hwp, 0x10);
        hwp.writeCrtc(hwp, 0x10, SYNC_START);
        save.cr11 = hwp.readCrtc(hwp, 0X11);
        /* unprotect group 1 registers; just in case ... */
        hwp.writeCrtc(hwp, 0X11, ((save.cr11 & 0x70) | SYNC_END));
        save.cr16 = hwp.readCrtc(hwp, 0x16);
        hwp.writeCrtc(hwp, 0x16, BLANK_END);
        save.cr06 = hwp.readCrtc(hwp, 0x06);
        hwp.writeCrtc(hwp, 0x06, V_TOTAL);
        /* all values have less than 8 bit - mask out 9th and 10th bits */
        save.cr09 = hwp.readCrtc(hwp, 0x09);
        hwp.writeCrtc(hwp, 0x09, (save.cr09 & 0xDF));
        save.cr07 = hwp.readCrtc(hwp, 0x07);
        hwp.writeCrtc(hwp, 0x07, (save.cr07 & 0x10));
        /* vsync polarity negative & ensure a 25MHz clock */
        save.msr = hwp.readMiscOut(hwp);
        hwp.writeMiscOut(hwp, ((save.msr & 0xF3) | 0x80));
        break;
    case DDC_SLOW:
        if (hwp.ddc is null)
            break;
        save = cast(_vgaDdcSave*) hwp.ddc;
        hwp.writeMiscOut(hwp, save.msr);
        hwp.writeCrtc(hwp, 0x07, save.cr07);
        tmp = hwp.readCrtc(hwp, 0x09);
        hwp.writeCrtc(hwp, 0x09, ((save.cr09 & 0x20) | (tmp & 0xDF)));
        hwp.writeCrtc(hwp, 0x06, save.cr06);
        hwp.writeCrtc(hwp, 0x16, save.cr16);
        hwp.writeCrtc(hwp, 0X11, save.cr11);
        hwp.writeCrtc(hwp, 0x10, save.cr10);
        hwp.writeCrtc(hwp, 0x15, save.cr15);
        hwp.writeCrtc(hwp, 0x12, save.cr12);
        hwp.writeCrtc(hwp, 0x03, save.cr03);
        free(save);
        hwp.ddc = null;
        break;
    default:
        break;
    }
}

DDC1SetSpeedProc vgaHWddc1SetSpeedWeak()
{
    return &vgaHWddc1SetSpeed;
}

/*
 * xf86GetClocks -- get the dot-clocks via a BIG BAD hack ...
 */
void xf86GetClocks(ScrnInfoPtr pScrn, int num, Bool function(ScrnInfoPtr, int) @nogc nothrow ClockFunc, void function(ScrnInfoPtr, Bool) @nogc nothrow ProtectRegs, void function(ScrnInfoPtr, Bool) @nogc nothrow BlankScreen, c_ulong vertsyncreg, int maskval, int knownclkindex, int knownclkvalue)
{
    int status = cast(int)vertsyncreg;
    c_ulong i = void, cnt = void, rcnt = void, sync = void;
    vgaHWPtr hwp = mixin(VGAHWPTR!(`pScrn`));

    /* First save registers that get written on */
    (*ClockFunc) (pScrn, CLK_REG_SAVE);

    if (num > MAXCLOCKS)
        num = MAXCLOCKS;

    for (i = 0; i < num; i++) {
        if (ProtectRegs)
            (*ProtectRegs) (pScrn, TRUE);
        if (!(*ClockFunc) (pScrn, cast(int)i)) {
            pScrn.clock[i] = -1;
            continue;
        }
        if (ProtectRegs)
            (*ProtectRegs) (pScrn, FALSE);
        if (BlankScreen)
            (*BlankScreen) (pScrn, FALSE);

        usleep(50000);          /* let VCO stabilise */

        cnt = 0;
        sync = 200000;

        while ((pci_io_read8(hwp.io, status) & maskval) == 0x00)
            if (sync-- == 0)
                goto finish;
        /* Something appears to be happening, so reset sync count */
        sync = 200000;
        while ((pci_io_read8(hwp.io, status) & maskval) == maskval)
            if (sync-- == 0)
                goto finish;
        /* Something appears to be happening, so reset sync count */
        sync = 200000;
        while ((pci_io_read8(hwp.io, status) & maskval) == 0x00)
            if (sync-- == 0)
                goto finish;

        for (rcnt = 0; rcnt < 5; rcnt++) {
            while (!(pci_io_read8(hwp.io, status) & maskval))
                cnt++;
            while ((pci_io_read8(hwp.io, status) & maskval))
                cnt++;
        }

 finish:
        pScrn.clock[i] = cnt ? cast(int)cnt : -1;
        if (BlankScreen)
            (*BlankScreen) (pScrn, TRUE);
    }

    for (i = 0; i < num; i++) {
        if (i != knownclkindex) {
            if (pScrn.clock[i] == -1) {
                pScrn.clock[i] = 0;
            }
            else {
                pScrn.clock[i] = cast(int) (0.5 +
                                         ((cast(float) knownclkvalue) *
                                          pScrn.clock[knownclkindex]) /
                                         (pScrn.clock[i]));
                /* Round to nearest 10KHz */
                pScrn.clock[i] += 5;
                pScrn.clock[i] /= 10;
                pScrn.clock[i] *= 10;
            }
        }
    }

    pScrn.clock[knownclkindex] = knownclkvalue;
    pScrn.numClocks = num;

    /* Restore registers that were written on */
    (*ClockFunc) (pScrn, CLK_REG_RESTORE);
}
