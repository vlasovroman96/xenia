module include.xf86DDC;
@nogc nothrow:
extern(C): __gshared:

/* xf86DDC.h
 *
 * This file contains all information to interpret a standard EDIC block
 * transmitted by a display device via DDC (Display Data Channel). So far
 * there is no information to deal with optional EDID blocks.
 * DDC is a Trademark of VESA (Video Electronics Standard Association).
 *
 * Copyright 1998 by Egbert Eich <Egbert.Eich@Physik.TU-Darmstadt.DE>
 */

 
import hw.xfree86.common.edid;
public import include.xf86i2c;
public import include.xf86str;

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


