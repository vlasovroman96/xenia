module include.xvdix;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************
Copyright 1991 by Digital Equipment Corporation, Maynard, Massachusetts,
and the Massachusetts Institute of Technology, Cambridge, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital or MIT not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

 
/*
** File:
**
**   xvdix.h --- Xv device independent header file
**
** Author:
**
**   David Carver (Digital Workstation Engineering/Project Athena)
**
** Revisions:
**
**   29.08.91 Carver
**     - removed UnrealizeWindow wrapper unrealizing windows no longer
**       preempts video
**
**   11.06.91 Carver
**     - changed SetPortControl to SetPortAttribute
**     - changed GetPortControl to GetPortAttribute
**     - changed QueryBestSize
**
**   15.05.91 Carver
**     - version 2.0 upgrade
**
**   24.01.91 Carver
**     - version 1.4 upgrade
**
*/
import dix.timestamp;
public import include.scrnintstr;
// //public import externs.X11.extensions.Xvproto;

struct _XvRationalRec {
    int numerator;
    int denominator;
}alias XvRationalRec = _XvRationalRec;
alias XvRationalPtr = XvRationalRec*;

struct _XvFormatRec {
    char depth = 0;
    c_ulong visual;
}alias XvFormatRec = _XvFormatRec;
alias XvFormatPtr = XvFormatRec*;

struct _XvGrabRec {
    c_ulong id;
    ClientPtr client;
}alias XvGrabRec = _XvGrabRec;
alias XvGrabPtr = XvGrabRec*;

struct _XvPortNotifyRec {
    _XvPortNotifyRec *next;
    ClientPtr client;
    ulong id;
}
alias XvPortNotifyRec = _XvPortNotifyRec;

alias XvPortNotifyPtr = _XvPortNotifyRec*;

struct _XvEncodingRec {
    int id;
    ScreenPtr pScreen;
    char* name;
    ushort width, height;
    XvRationalRec rate;
}alias XvEncodingRec = _XvEncodingRec;
alias XvEncodingPtr = XvEncodingRec*;

struct _XvAttributeRec {
    int flags;
    int min_value;
    int max_value;
    char* name;
}alias XvAttributeRec = _XvAttributeRec;
alias XvAttributePtr = _XvAttributeRec*;

struct _XvImageRec {
    int id;
    int type;
    int byte_order;
    char[16] guid = 0;
    int bits_per_pixel;
    int format;
    int num_planes;

    /* for RGB formats only */
    int depth;
    uint red_mask;
    uint green_mask;
    uint blue_mask;

    /* for YUV formats only */
    uint y_sample_bits;
    uint u_sample_bits;
    uint v_sample_bits;
    uint horz_y_period;
    uint horz_u_period;
    uint horz_v_period;
    uint vert_y_period;
    uint vert_u_period;
    uint vert_v_period;
    char[32] component_order = 0;
    int scanline_order;
}alias XvImageRec = _XvImageRec;
alias XvImagePtr = XvImageRec*;

struct _XvAdaptorRec {
    c_ulong base_id;
    ubyte type;
    char* name;
    int nEncodings;
    XvEncodingPtr pEncodings;
    int nFormats;
    XvFormatPtr pFormats;
    int nAttributes;
    XvAttributePtr pAttributes;
    int nImages;
    XvImagePtr pImages;
    int nPorts;
    _XvPortRec* pPorts;
    ScreenPtr pScreen;
    @nogc nothrow int function(DrawablePtr, _XvPortRec*, GCPtr, INT16, INT16, CARD16, CARD16, INT16, INT16, CARD16, CARD16) ddPutVideo;
    @nogc nothrow int function(DrawablePtr, _XvPortRec*, GCPtr, INT16, INT16, CARD16, CARD16, INT16, INT16, CARD16, CARD16) ddPutStill;
    @nogc nothrow int function(DrawablePtr, _XvPortRec*, GCPtr, INT16, INT16, CARD16, CARD16, INT16, INT16, CARD16, CARD16) ddGetVideo;
    @nogc nothrow int function(DrawablePtr, _XvPortRec*, GCPtr, INT16, INT16, CARD16, CARD16, INT16, INT16, CARD16, CARD16) ddGetStill;
    @nogc nothrow int function(_XvPortRec*, DrawablePtr) ddStopVideo;
    @nogc nothrow int function(_XvPortRec*, Atom, INT32) ddSetPortAttribute;
    @nogc nothrow int function(_XvPortRec*, Atom, INT32*) ddGetPortAttribute;
    @nogc nothrow int function(_XvPortRec*, CARD8, CARD16, CARD16, CARD16, CARD16, uint*, uint*) ddQueryBestSize;
    @nogc nothrow int function(DrawablePtr, _XvPortRec*, GCPtr, INT16, INT16, CARD16, CARD16, INT16, INT16, CARD16, CARD16, XvImagePtr, ubyte*, Bool, CARD16, CARD16) ddPutImage;
    @nogc nothrow int function(_XvPortRec*, XvImagePtr, CARD16*, CARD16*, int*, int*) ddQueryImageAttributes;
    DevUnion devPriv;
}alias XvAdaptorRec = _XvAdaptorRec;
alias XvAdaptorPtr = XvAdaptorRec*;

struct _XvPortRec {
    c_ulong id;
    XvAdaptorPtr pAdaptor;
    XvPortNotifyPtr pNotify;
    DrawablePtr pDraw;
    ClientPtr client;
    XvGrabRec grab;
    TimeStamp time;
    DevUnion devPriv;
}alias XvPortRec = _XvPortRec;
alias XvPortPtr = _XvPortRec*;

struct _XvScreenRec {
    int version_, revision;
    int nAdaptors;
    XvAdaptorPtr pAdaptors;
    void* _dummy1; // required in place of a removed field for ABI compatibility
    void* _dummy2; // required in place of a removed field for ABI compatibility
    void* _dummy3; // required in place of a removed field for ABI compatibility
}alias XvScreenRec = _XvScreenRec;
alias XvScreenPtr = XvScreenRec*;

// void  XvScreenInit(ScreenPtr);
// DevPrivateKey XvGetScreenKey();
// ulong XvGetRTPort();

                          /* XVDIX_H */
