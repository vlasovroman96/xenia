module ddc;
@nogc nothrow:
extern(C): __gshared:
/* xf86DDC.c
 *
 * Copyright 1998,1999 by Egbert Eich <Egbert.Eich@Physik.TU-Darmstadt.DE>
 */

/*
 * A note on terminology.  DDC1 is the original dumb serial protocol, and
 * can only do up to 128 bytes of EDID.  DDC2 is I2C-encapsulated and
 * introduces extension blocks.  EDID is the old display identification
 * block, DisplayID is the new one.
 */
import build.xorg_config;

import ddc;
import os.osdep;

import hw.xfree86.os_support.xf86_OSproc;;
import core.stdc.string;
import edid_priv;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.common.xf86Option;
import interpret_edid;
import hw.xfree86.i2c.xf86i2c;
import dix.events;
import hw.xfree86.parser.Flags;
import hw.xfree86.common.edid;

import hw.xfree86.common.edid;
public import hw.xfree86.common.xf86str;

/* speed up / slow down */
enum xf86ddcSpeed {
    DDC_SLOW,
    DDC_FAST
}
alias DDC_SLOW = xf86ddcSpeed.DDC_SLOW;
alias DDC_FAST = xf86ddcSpeed.DDC_FAST;


alias DDC1SetSpeedProc = void function(ScrnInfoPtr, xf86ddcSpeed);

void  xf86DoEDID_DDC1(ScrnInfoPtr pScrn, DDC1SetSpeedProc DDC1SetSpeed, uint function(ScrnInfoPtr) DDC1Read);

void  xf86DoEDID_DDC2(ScrnInfoPtr pScrn, I2CBusPtr pBus);

// void  xf86DoEEDID(ScrnInfoPtr pScrn, I2CBusPtr pBus, Bool);

void  xf86PrintEDID(xf86MonPtr monPtr);

// void  xf86InterpretEDID(int screenIndex, ubyte* block);

// void  xf86InterpretEEDID(int screenIndex, ubyte* block);

void  xf86SetDDCproperties(ScrnInfoPtr pScreen, xf86MonPtr DDC);

/*
 * parse EDID block and return a newly allocated xf86Monitor
 *
 * the data block will be copied into the structure (actually right after the struct)
 * and thus automatically be freed when the returned struct is freed.
 *
 * @param screenIndex   index of the screen, will be recorded in the xf86Monitor
 * @param block         the EDID block to parse
 * @param size          size of the EDID block (128 or larger for extended types)
 * @return              newly allocated xf86MonRec or NULL on failure
 */
xf86MonPtr xf86ParseEDID(ScrnInfoPtr pScreen, ubyte* block, size_t size);


enum RETRIES = 4;

enum HEADER = 6;
enum BITS_PER_BYTE = 9;
enum NUM = BITS_PER_BYTE*EDID1_LEN;

enum DDCOpts {
    DDCOPT_NODDC1,
    DDCOPT_NODDC2,
    DDCOPT_NODDC
}
alias DDCOPT_NODDC1 = DDCOpts.DDCOPT_NODDC1;
alias DDCOPT_NODDC2 = DDCOpts.DDCOPT_NODDC2;
alias DDCOPT_NODDC = DDCOpts.DDCOPT_NODDC;


private const(OptionInfoRec)[5] DDCOptions = [
    {DDCOPT_NODDC1, "NoDDC1", OPTV_BOOLEAN, {0}, False},
    {DDCOPT_NODDC2, "NoDDC2", OPTV_BOOLEAN, {0}, False},
    {DDCOPT_NODDC, "NoDDC", OPTV_BOOLEAN, {0}, False},
    {-1, null, OPTV_NONE, {0}, False},
];

/* DDC1 */

private int find_start(uint* ptr)
{
    uint[9] comp = void, test = void;
    int i = void, j = void;

    if (!ptr)
        return -1;

    for (i = 0; i < 9; i++) {
        comp[i] = *(ptr++);
        test[i] = 1;
    }
    for (i = 0; i < 127; i++) {
        for (j = 0; j < 9; j++) {
            test[j] = test[j] & !(comp[j] ^ *(ptr++));
        }
    }
    for (i = 0; i < 9; i++)
        if (test[i])
            return i + 1;
    return -1;
}

private ubyte* find_header(ubyte* block)
{
    ubyte* ptr = void, head_ptr = void, end = void;
    ubyte[8] header = [ 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00 ];

    ptr = block;
    end = block + EDID1_LEN;
    while (ptr < end) {
        int i = void;

        head_ptr = ptr;
        for (i = 0; i < 8; i++) {
            if (header[i] != *(head_ptr++))
                break;
            if (head_ptr == end)
                head_ptr = block;
        }
        if (i == 8)
            break;
        ptr++;
    }
    if (ptr == end)
        return null;
    return ptr;
}

private ubyte* resort(ubyte* s_block)
{
    ubyte* d_ptr = void, d_end = void, s_ptr = void, s_end = void;
    ubyte tmp = void;

    s_ptr = find_header(s_block);
    if (!s_ptr)
        return null;
    s_end = s_block + EDID1_LEN;

    ubyte* d_new = cast(ubyte*) calloc(1, EDID1_LEN);
    if (!d_new)
        return null;
    d_end = d_new + EDID1_LEN;

    for (d_ptr = d_new; d_ptr < d_end; d_ptr++) {
        tmp = *(s_ptr++);
        *d_ptr = tmp;
        if (s_ptr == s_end)
            s_ptr = s_block;
    }
    free(s_block);
    return d_new;
}

private int DDC_checksum(const(ubyte)* block, int len)
{
    int i = void, result = 0;
    int not_null = 0;

    for (i = 0; i < len; i++) {
        not_null |= block[i];
        result += block[i];
    }

version (DEBUG) {
    if (result & 0xFF)
        ErrorF("DDC checksum not correct\n");
    if (!not_null)
        ErrorF("DDC read all Null\n");
}

    /* catch the trivial case where all bytes are 0 */
    if (!not_null)
        return 1;

    return result & 0xFF;
}

private ubyte* GetEDID_DDC1(uint* s_ptr)
{
    ubyte* d_block = void, d_pos = void;
    uint* s_pos = void, s_end = void;
    int s_start = void;
    int i = void, j = void;

    s_start = find_start(s_ptr);
    if (s_start == -1)
        return null;
    s_end = s_ptr + NUM;
    s_pos = s_ptr + s_start;
    d_block = cast(ubyte*) calloc(1, EDID1_LEN);
    if (!d_block)
        return null;
    d_pos = d_block;
    for (i = 0; i < EDID1_LEN; i++) {
        for (j = 0; j < 8; j++) {
            *d_pos <<= 1;
            if (*s_pos) {
                *d_pos |= 0x01;
            }
            s_pos++;
            if (s_pos == s_end)
                s_pos = s_ptr;
        }{}
        s_pos++;
        if (s_pos == s_end)
            s_pos = s_ptr;
        d_pos++;
    }
    free(s_ptr);
    if (d_block && DDC_checksum(d_block, EDID1_LEN)) {
        free(d_block);
        return null;
    }
    return (resort(d_block));
}

/* fetch entire EDID record; DDC bit needs to be masked */
private uint* FetchEDID_DDC1(ScrnInfoPtr pScrn, uint function(ScrnInfoPtr) @nogc nothrow read_DDC)
{
    int count = NUM;
    uint* ptr = void, xp = void;

    ptr = xp = cast(uint*) calloc(NUM, int.sizeof);

    if (!ptr)
        return null;
    do {
        /* wait for next retrace */
        *xp = read_DDC(pScrn);
        xp++;
    } while (--count);
    return ptr;
}

/* test if DDC1  return 0 if not */
private Bool TestDDC1(ScrnInfoPtr pScrn, uint function(ScrnInfoPtr) @nogc nothrow read_DDC)
{
    int old = void, count = void;

    old = read_DDC(pScrn);
    count = HEADER * BITS_PER_BYTE;
    do {
        /* wait for next retrace */
        if (old != read_DDC(pScrn))
            break;
    } while (count--);
    return count;
}

/*
 * read EDID record , pass it to callback function to interpret.
 * callback function will store it for further use by calling
 * function; it will also decide if we need to reread it
 */
private ubyte* EDIDRead_DDC1(ScrnInfoPtr pScrn, DDC1SetSpeedProc DDCSpeed, uint function(ScrnInfoPtr) @nogc nothrow read_DDC)
{
    ubyte* EDID_block = null;
    int count = RETRIES;

    if (!read_DDC) {
        xf86DrvMsg(pScrn.scrnIndex, X_PROBED,
                   "chipset doesn't support DDC1\n");
        return null;
    }{}

    if (TestDDC1(pScrn, read_DDC) == -1) {
        xf86DrvMsg(pScrn.scrnIndex, X_PROBED, "No DDC signal\n");
        return null;
    }{}

    if (DDCSpeed)
        DDCSpeed(pScrn, DDC_FAST);
    do {
        EDID_block = GetEDID_DDC1(FetchEDID_DDC1(pScrn, read_DDC));
        count--;
    } while (!EDID_block && count);
    if (DDCSpeed)
        DDCSpeed(pScrn, DDC_SLOW);

    return EDID_block;
}

/**
 * Attempts to probe the monitor for EDID information, if NoDDC and NoDDC1 are
 * unset.  EDID information blocks are interpreted and the results returned in
 * an xf86MonPtr.
 *
 * This function does not affect the list of modes used by drivers -- it is up
 * to the driver to decide policy on what to do with EDID information.
 *
 * @return pointer to a new xf86MonPtr containing the EDID information.
 * @return NULL if no monitor attached or failure to interpret the EDID.
 */
xf86MonPtr xf86DoEDID_DDC1(ScrnInfoPtr pScrn, DDC1SetSpeedProc DDC1SetSpeed, uint function(ScrnInfoPtr) @nogc nothrow DDC1Read)
{
    ubyte* EDID_block = null;
    xf86MonPtr tmp = null;

    /* Default DDC and DDC1 to enabled. */
    Bool noddc = False, noddc1 = False;
    OptionInfoPtr options = void;

    options = cast(_OptionInfoRec*)XNFalloc(DDCOptions.sizeof);
    cast(void) memcpy(options, DDCOptions.ptr, DDCOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, options);

    xf86GetOptValBool(options, DDCOPT_NODDC, &noddc);
    xf86GetOptValBool(options, DDCOPT_NODDC1, &noddc1);
    free(options);

    if (noddc || noddc1)
        return null;

    OsBlockSignals();
    EDID_block = EDIDRead_DDC1(pScrn, DDC1SetSpeed, DDC1Read);
    OsReleaseSignals();

    if (EDID_block) {
        tmp = xf86InterpretEDID(pScrn.scrnIndex, EDID_block);
    }
    else {
version (DEBUG) {
        ErrorF("No EDID block returned\n");
    }
    }
version(DEBUG) {
    if (!tmp)
        ErrorF("Cannot interpret EDID block\n");
}
    return tmp;
}

/* DDC2 */

private I2CDevPtr DDC2MakeDevice(I2CBusPtr pBus, int address, const(char)* name)
{
    I2CDevPtr dev = null;

    if (((dev = xf86I2CFindDev(pBus, cast(short)address)) is null)) {
        dev = xf86CreateI2CDevRec();
        dev.DevName = name;
        dev.SlaveAddr = cast(short)address;
        dev.ByteTimeout = 2200;        /* VESA DDC spec 3 p. 43 (+10 %) */
        dev.StartTimeout = 550;
        dev.BitTimeout = 40;
        dev.AcknTimeout = 40;

        dev.pI2CBus = pBus;
        if (!xf86I2CDevInit(dev)) {
            xf86DrvMsg(pBus.scrnIndex, X_PROBED, "No DDC2 device\n");
            return null;
        }
    }

    return dev;
}

private I2CDevPtr DDC2Init(I2CBusPtr pBus)
{
    I2CDevPtr dev = null;

    /*
     * Slow down the bus so that older monitors don't
     * miss things.
     */
    pBus.RiseFallTime = 20;

    dev = DDC2MakeDevice(pBus, 0x00A0, "ddc2");
    if (xf86I2CProbeAddress(pBus, 0x0060))
        DDC2MakeDevice(pBus, 0x0060, "E-EDID segment register");

    return dev;
}

/* Mmmm, smell the hacks */
private void EEDIDStop(I2CDevPtr d)
{
}

/* block is the EDID block number.  a segment is two blocks. */
private Bool DDC2Read(I2CDevPtr dev, int block, ubyte* R_Buffer)
{
    ubyte[1] W_Buffer = void;
    int i = void, segment = void;
    I2CDevPtr seg = void;
    extern(C) void function(I2CDevPtr) @nogc nothrow stop = void;

    for (i = 0; i < RETRIES; i++) {
        /* Stop bits reset the segment pointer to 0, so be careful here. */
        segment = block >> 1;
        if (segment) {
            Bool b = void;

            if (((seg = xf86I2CFindDev(dev.pI2CBus, 0x0060)) is null))
                return False;

            W_Buffer[0] = cast(ubyte)segment;

            stop = dev.pI2CBus.I2CStop;
            dev.pI2CBus.I2CStop = &EEDIDStop;

            b = xf86I2CWriteRead(seg, W_Buffer.ptr, 1, null, 0);

            dev.pI2CBus.I2CStop = stop;
            if (!b) {
                dev.pI2CBus.I2CStop(dev);
                continue;
            }
        }

        W_Buffer[0] = (block & 0x01) * EDID1_LEN;

        if (xf86I2CWriteRead(dev, W_Buffer.ptr, 1, R_Buffer, EDID1_LEN)) {
            if (!DDC_checksum(R_Buffer, EDID1_LEN))
                return True;
        }
    }

    return False;
}

/**
 * Attempts to probe the monitor for EDID information, if NoDDC and NoDDC2 are
 * unset.  EDID information blocks are interpreted and the results returned in
 * an xf86MonPtr.  Unlike xf86DoEDID_DDC[12](), this function will return
 * the complete EDID data, including all extension blocks, if the 'complete'
 * parameter is True;
 *
 * This function does not affect the list of modes used by drivers -- it is up
 * to the driver to decide policy on what to do with EDID information.
 *
 * @return pointer to a new xf86MonPtr containing the EDID information.
 * @return NULL if no monitor attached or failure to interpret the EDID.
 */
xf86MonPtr xf86DoEEDID(ScrnInfoPtr pScrn, I2CBusPtr pBus, Bool complete)
{
    ubyte* EDID_block = null;
    xf86MonPtr tmp = null;
    I2CDevPtr dev = null;

    /* Default DDC and DDC2 to enabled. */
    Bool noddc = False, noddc2 = False;
    OptionInfoPtr options = cast(OptionInfoPtr) calloc(1, DDCOptions.sizeof);
    if (!options)
        return null;
    memcpy(options, DDCOptions.ptr, DDCOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, options);

    xf86GetOptValBool(options, DDCOPT_NODDC, &noddc);
    xf86GetOptValBool(options, DDCOPT_NODDC2, &noddc2);
    free(options);

    if (noddc || noddc2)
        return null;

    if (((dev = DDC2Init(pBus)) is null))
        return null;

    EDID_block = cast(ubyte*) calloc(1, EDID1_LEN);
    if (!EDID_block)
        return null;

    if (DDC2Read(dev, 0, EDID_block)) {
        int i = void, n = EDID_block[0x7e];

        if (complete && n) {
            EDID_block = cast(ubyte*)reallocarray(EDID_block, 1 + n, EDID1_LEN);

            for (i = 0; i < n; i++)
                DDC2Read(dev, i + 1, EDID_block + (EDID1_LEN * (1 + i)));
        }

        tmp = xf86InterpretEEDID(pScrn.scrnIndex, EDID_block);
    }

    if (tmp && complete)
        tmp.flags |= MONITOR_EDID_COMPLETE_RAWDATA;

    return tmp;
}

/**
 * Attempts to probe the monitor for EDID information, if NoDDC and NoDDC2 are
 * unset.  EDID information blocks are interpreted and the results returned in
 * an xf86MonPtr.
 *
 * This function does not affect the list of modes used by drivers -- it is up
 * to the driver to decide policy on what to do with EDID information.
 *
 * @return pointer to a new xf86MonPtr containing the EDID information.
 * @return NULL if no monitor attached or failure to interpret the EDID.
 */
xf86MonPtr xf86DoEDID_DDC2(ScrnInfoPtr pScrn, I2CBusPtr pBus)
{
    return xf86DoEEDID(pScrn, pBus, False);
}
