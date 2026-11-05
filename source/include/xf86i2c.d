module include.xf86i2c;
@nogc nothrow:
extern(C): __gshared:
/*
 *  Copyright (C) 1998 Itai Nahshon, Michael Schimek
 */

 
public import region;
public import hw.xfree86.common.xf86Helper;
import hw.xfree86.i2c.xf86i2c;
import xf86Bus;

alias I2CByte = ubyte;
alias I2CSlaveAddr = ushort;

alias I2CBusPtr = _I2CBusRec*;
alias I2CDevPtr = _I2CDevRec*;

/* I2C masters have to register themselves */

struct _I2CBusRec {
    const(char)* BusName;
    int scrnIndex;
    ScrnInfoPtr pScrn;

    void function(I2CBusPtr b, int usec) @nogc nothrow I2CUDelay;

    void function(I2CBusPtr b, int scl, int sda) @nogc nothrow I2CPutBits;
    void function(I2CBusPtr b, int* scl, int* sda) @nogc nothrow I2CGetBits;

    /* Look at the generic routines to see how these functions should behave. */

    Bool function(I2CBusPtr b, int timeout) @nogc nothrow I2CStart;
    Bool function(I2CDevPtr d, I2CSlaveAddr) @nogc nothrow I2CAddress;
    void function(I2CDevPtr d) @nogc nothrow I2CStop;
    Bool function(I2CDevPtr d, I2CByte data) @nogc nothrow I2CPutByte;
    Bool function(I2CDevPtr d, I2CByte* data, Bool) @nogc nothrow I2CGetByte;

    DevUnion DriverPrivate;

    int HoldTime;               /* 1 / bus clock frequency, 5 or 2 usec */

    int BitTimeout;             /* usec */
    int ByteTimeout;            /* usec */
    int AcknTimeout;            /* usec */
    int StartTimeout;           /* usec */
    int RiseFallTime;           /* usec */

    I2CDevPtr FirstDev;
    I2CBusPtr NextBus;
    Bool function(I2CDevPtr d, I2CByte* WriteBuffer, int nWrite, I2CByte* ReadBuffer, int nRead) @nogc nothrow I2CWriteRead;
}

alias I2CBusRec = _I2CBusRec;

alias CreateI2CBusRec =		xf86CreateI2CBusRec;
void  xf86CreateI2CBusRec();

alias DestroyI2CBusRec =	xf86DestroyI2CBusRec;
void  xf86DestroyI2CBusRec(I2CBusPtr pI2CBus, Bool unalloc, Bool devs_too);
alias I2CBusInit =		xf86I2CBusInit;
void  xf86I2CBusInit(I2CBusPtr pI2CBus);

void  xf86I2CFindBus(int scrnIndex, const(char)* name);
void  xf86I2CGetScreenBuses(int scrnIndex, I2CBusPtr** pppI2CBus);

/* I2C slave devices */

struct _I2CDevRec {
    const(char)* DevName;

    int BitTimeout;             /* usec */
    int ByteTimeout;            /* usec */
    int AcknTimeout;            /* usec */
    int StartTimeout;           /* usec */

    I2CSlaveAddr SlaveAddr;
    I2CBusPtr pI2CBus;
    I2CDevPtr NextDev;
    DevUnion DriverPrivate;
}

alias I2CDevRec = _I2CDevRec;

alias CreateI2CDevRec =		xf86CreateI2CDevRec;
// void  xf86CreateI2CDevRec();
void  xf86DestroyI2CDevRec(I2CDevPtr pI2CDev, Bool unalloc);

alias I2CDevInit =		xf86I2CDevInit;
// void  xf86I2CDevInit(I2CDevPtr pI2CDev);
// void  xf86I2CFindDev(I2CBusPtr, I2CSlaveAddr);

/* See descriptions of these functions in xf86i2c.c */

alias I2CProbeAddress =		xf86I2CProbeAddress;
// void  xf86I2CProbeAddress(I2CBusPtr pI2CBus, I2CSlaveAddr);

alias		I2C_WriteRead = xf86I2CWriteRead;
// void  xf86I2CWriteRead(I2CDevPtr d, I2CByte* WriteBuffer, int nWrite, I2CByte* ReadBuffer, int nRead);
enum string 	xf86I2CRead(string d, string rb, string nr) = `xf86I2CWriteRead(` ~ d ~ `, null, 0, ` ~ rb ~ `, ` ~ nr ~ `)`;

void  xf86I2CReadByte(I2CDevPtr d, I2CByte subaddr, I2CByte* pbyte);
void  xf86I2CReadBytes(I2CDevPtr d, I2CByte subaddr, I2CByte* pbyte, int n);
enum string 	xf86I2CWrite(string d, string wb, string nw) = `xf86I2CWriteRead(` ~ d ~ `, ` ~ wb ~ `, ` ~ nw ~ `, null, 0)`;
void  xf86I2CWriteByte(I2CDevPtr d, I2CByte subaddr, I2CByte byte_);
void  xf86I2CWriteVec(I2CDevPtr d, I2CByte* vec, int nValues);

 /*_XF86I2C_H */
