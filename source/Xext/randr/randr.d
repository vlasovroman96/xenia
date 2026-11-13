module randr.randr;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2000 Compaq Computer Corporation
 * Copyright © 2002 Hewlett-Packard Company
 * Copyright © 2006 Intel Corporation
 * Copyright © 2017 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 *
 * Author:  Jim Gettys, Hewlett-Packard Company, Inc.
 *	    Keith Packard, Intel Corporation
 */

import build.xlibre_server;
import Xext.panoramiXsrv;

//import stdbool;

import dix.screen_hooks_priv;
import dix.screenint_priv;
import miext.extinit_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import dix.screen_hooks;
import dix.resource;
import dix.dixutils;
import dix.extension;
import os.io;
import dix.events;
import dix.timestamp;
import dix.window;

public import common.xlibre_ptrtypes;
public import os.os;
public import dix.dixstruct_priv;
public import dix.scrnintstr;
public import dix.pixmap;
public import dix.extension;
public import common.servermd;
public import randr.rrtransform;
import dix.timestamp;

//public import externs.X11.extensions._randr;
public import externs.X11.extensions.randrproto;
//public import externs.X11.extensions._render;      /* we share subpixel order information */
public import dix.picturestr;
// //public import x11.Xfuncproto;
import common.swap;

/* required for ABI compatibility for now */
enum RANDR_10_INTERFACE = 1;
enum RANDR_12_INTERFACE = 1;
enum RANDR_13_INTERFACE = 1    /* requires RANDR_12_INTERFACE */;
enum RANDR_GET_CRTC_INTERFACE = 1;

enum RANDR_INTERFACE_VERSION = 0x0104;

alias RRMode = XID;
alias RROutput = XID;
alias RRCrtc = XID;
alias RRProvider = XID;
alias RRLease = XID;

/*
 * Modeline for a monitor. Name follows directly after this struct
 */

enum string RRModeName(string pMode) = `(cast(char*) (` ~ pMode ~ ` + 1))`;
alias RRModeRec = _rrMode;
alias RRModePtr = _rrMode*;
alias RRPropertyValueRec = _rrPropertyValue;
alias RRPropertyValuePtr = _rrPropertyValue*;
alias RRPropertyRec = _rrProperty;
alias RRPropertyPtr = _rrProperty*;
alias RRCrtcRec = _rrCrtc;
alias RRCrtcPtr = _rrCrtc*;
alias RROutputRec = _rrOutput;
alias RROutputPtr = _rrOutput*;
alias RRProviderRec = _rrProvider;
alias RRProviderPtr = _rrProvider*;
alias RRMonitorRec = _rrMonitor;
alias RRMonitorPtr = _rrMonitor*;
alias RRLeaseRec = _rrLease;
alias RRLeasePtr = _rrLease*;

struct _rrMode {
    int refcnt;
    xRRModeInfo mode;
    char* name;
    ScreenPtr userScreen;
}

struct _rrPropertyValue {
    Atom type;                  /* ignored by server */
    short format;               /* format of data for swapping - 8,16,32 */
    c_long size;                  /* size of data in (format/8) bytes */
    void* data;                 /* private to client */
}

struct _rrProperty {
    RRPropertyPtr next;
    Atom propertyName;
    Bool is_pending;
    Bool range;
    Bool immutable_;
    int num_valid;
    INT32* valid_values;
    RRPropertyValueRec current, pending;
}

struct _rrCrtc {
    RRCrtc id;
    ScreenPtr pScreen;
    RRModePtr mode;
    int x, y;
    Rotation rotation;
    Rotation rotations;
    Bool changed;
    int numOutputs;
    RROutputPtr* outputs;
    int gammaSize;
    CARD16* gammaRed;
    CARD16* gammaBlue;
    CARD16* gammaGreen;
    void* devPrivate;
    Bool transforms;
    RRTransformRec client_pending_transform;
    RRTransformRec client_current_transform;
    PictTransform transform;
    pixman_f_transform f_transform;
    pixman_f_transform f_inverse;

    PixmapPtr scanout_pixmap;
    PixmapPtr scanout_pixmap_back;
}

struct _rrOutput {
    RROutput id;
    ScreenPtr pScreen;
    char* name;
    int nameLength;
    CARD8 connection;
    CARD8 subpixelOrder;
    int mmWidth;
    int mmHeight;
    RRCrtcPtr crtc;
    int numCrtcs;
    RRCrtcPtr* crtcs;
    int numClones;
    RROutputPtr* clones;
    int numModes;
    int numPreferred;
    RRModePtr* modes;
    int numUserModes;
    RRModePtr* userModes;
    Bool changed;
    Bool nonDesktop;
    RRPropertyPtr properties;
    Bool pendingProperties;
    void* devPrivate;
}

struct _rrProvider {
    RRProvider id;
    ScreenPtr pScreen;
    uint capabilities;
    char* name;
    int nameLength;
    RRPropertyPtr properties;
    Bool pendingProperties;
    Bool changed;
    _rrProvider* offload_sink;
    _rrProvider* output_source;
}

struct _rrMonitorGeometry {
    BoxRec box;
    CARD32 mmWidth;
    CARD32 mmHeight;
}alias RRMonitorGeometryRec = _rrMonitorGeometry;
alias RRMonitorGeometryPtr = _rrMonitorGeometry*;

struct _rrMonitor {
    Atom name;
    ScreenPtr pScreen;
    int numOutputs;
    RROutput* outputs;
    Bool primary;
    Bool automatic;
    RRMonitorGeometryRec geometry;
}

enum RRLeaseState { RRLeaseCreating, RRLeaseRunning, RRLeaseTerminating }
alias RRLeaseCreating = RRLeaseState.RRLeaseCreating;
alias RRLeaseRunning = RRLeaseState.RRLeaseRunning;
alias RRLeaseTerminating = RRLeaseState.RRLeaseTerminating;


struct _rrLease {
    XList list;
    ScreenPtr screen;
    RRLease id;
    RRLeaseState state;
    void* devPrivate;
    int numCrtcs;
    RRCrtcPtr* crtcs;
    int numOutputs;
    RROutputPtr* outputs;
}

static if (RANDR_12_INTERFACE) {
alias RRScreenSetSizeProcPtr = Bool function(ScreenPtr pScreen, CARD16 width, CARD16 height, CARD32 mmWidth, CARD32 mmHeight);

alias RRCrtcSetProcPtr = Bool function(ScreenPtr pScreen, RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, int numOutputs, RROutputPtr* outputs);

alias RRCrtcGetProcPtr = void function(ScreenPtr pScreen, RRCrtcPtr crtc, xRRGetCrtcInfoReply* rep);

alias RRCrtcSetGammaProcPtr = Bool function(ScreenPtr pScreen, RRCrtcPtr crtc);

alias RRCrtcGetGammaProcPtr = Bool function(ScreenPtr pScreen, RRCrtcPtr crtc);

alias RROutputSetPropertyProcPtr = Bool function(ScreenPtr pScreen, RROutputPtr output, Atom property, RRPropertyValuePtr value);

alias RROutputValidateModeProcPtr = Bool function(ScreenPtr pScreen, RROutputPtr output, RRModePtr mode);

alias RRModeDestroyProcPtr = void function(ScreenPtr pScreen, RRModePtr mode);

}

static if (RANDR_13_INTERFACE) {
alias RROutputGetPropertyProcPtr = Bool function(ScreenPtr pScreen, RROutputPtr output, Atom property);
alias RRGetPanningProcPtr = Bool function(ScreenPtr pScrn, RRCrtcPtr crtc, BoxPtr totalArea, BoxPtr trackingArea, INT16* border);
alias RRSetPanningProcPtr = Bool function(ScreenPtr pScrn, RRCrtcPtr crtc, BoxPtr totalArea, BoxPtr trackingArea, INT16* border);

}                          /* RANDR_13_INTERFACE */

alias RRProviderGetPropertyProcPtr = Bool function(ScreenPtr pScreen, RRProviderPtr provider, Atom property);
alias RRProviderSetPropertyProcPtr = Bool function(ScreenPtr pScreen, RRProviderPtr provider, Atom property, RRPropertyValuePtr value);

alias RRGetInfoProcPtr = Bool function(ScreenPtr pScreen, Rotation* rotations);
alias RRCloseScreenProcPtr = Bool function(ScreenPtr pScreen);

alias RRProviderSetOutputSourceProcPtr = Bool function(ScreenPtr pScreen, RRProviderPtr provider, RRProviderPtr output_source);

alias RRProviderSetOffloadSinkProcPtr = Bool function(ScreenPtr pScreen, RRProviderPtr provider, RRProviderPtr offload_sink);


alias RRProviderDestroyProcPtr = void function(ScreenPtr pScreen, RRProviderPtr provider);

/* Additions for 1.6 */

alias RRCreateLeaseProcPtr = int function(ScreenPtr screen, RRLeasePtr lease, int* fd);

alias RRTerminateLeaseProcPtr = void function(ScreenPtr screen, RRLeasePtr lease);

alias RRRequestLeaseProcPtr = int function(ClientPtr client, ScreenPtr screen, RRLeasePtr lease);

alias RRGetLeaseProcPtr = void function(ClientPtr client, ScreenPtr screen, RRLeasePtr* lease, int* fd);

/* These are for 1.0 compatibility */

struct _rrRefresh {
    CARD16 rate;
    RRModePtr mode;
}alias RRScreenRate = _rrRefresh;
alias RRScreenRatePtr = _rrRefresh*;

struct _rrScreenSize {
    int id;
    short width, height;
    short mmWidth, mmHeight;
    int nRates;
    RRScreenRatePtr pRates;
}alias RRScreenSize = _rrScreenSize;
alias RRScreenSizePtr = _rrScreenSize*;

alias RRSetConfigProcPtr = Bool function(ScreenPtr pScreen, Rotation rotation, int rate, RRScreenSizePtr pSize);

alias RRCrtcSetScanoutPixmapProcPtr = Bool function(RRCrtcPtr crtc, PixmapPtr pixmap);

alias RRStartFlippingPixmapTrackingProcPtr = Bool function(RRCrtcPtr, DrawablePtr, PixmapPtr, PixmapPtr, int x, int y, int dst_x, int dst_y, Rotation rotation);

alias RREnableSharedPixmapFlippingProcPtr = Bool function(RRCrtcPtr, PixmapPtr front, PixmapPtr back);

alias RRDisableSharedPixmapFlippingProcPtr = void function(RRCrtcPtr);


struct _rrScrPriv {
    /*
     * 'public' part of the structure; DDXen fill this in
     * as they initialize
     */
    RRSetConfigProcPtr rrSetConfig;
    RRGetInfoProcPtr rrGetInfo;
static if (RANDR_12_INTERFACE) {
    RRScreenSetSizeProcPtr rrScreenSetSize;
    RRCrtcSetProcPtr rrCrtcSet;
    RRCrtcSetGammaProcPtr rrCrtcSetGamma;
    RRCrtcGetGammaProcPtr rrCrtcGetGamma;
    RROutputSetPropertyProcPtr rrOutputSetProperty;
    RROutputValidateModeProcPtr rrOutputValidateMode;
    RRModeDestroyProcPtr rrModeDestroy;
}
static if (RANDR_13_INTERFACE) {
    RROutputGetPropertyProcPtr rrOutputGetProperty;
    RRGetPanningProcPtr rrGetPanning;
    RRSetPanningProcPtr rrSetPanning;
}
    /* TODO #if RANDR_15_INTERFACE */
    RRCrtcSetScanoutPixmapProcPtr rrCrtcSetScanoutPixmap;

    RRStartFlippingPixmapTrackingProcPtr rrStartFlippingPixmapTracking;
    RREnableSharedPixmapFlippingProcPtr rrEnableSharedPixmapFlipping;
    RRDisableSharedPixmapFlippingProcPtr rrDisableSharedPixmapFlipping;

    RRProviderSetOutputSourceProcPtr rrProviderSetOutputSource;
    RRProviderSetOffloadSinkProcPtr rrProviderSetOffloadSink;
    RRProviderGetPropertyProcPtr rrProviderGetProperty;
    RRProviderSetPropertyProcPtr rrProviderSetProperty;

    RRCreateLeaseProcPtr rrCreateLease;
    RRTerminateLeaseProcPtr rrTerminateLease;

    /*
     * Private part of the structure; not considered part of the ABI
     */
    TimeStamp lastSetTime;      /* last changed by client */
    TimeStamp lastConfigTime;   /* possible configs changed */
    RRCloseScreenProcPtr CloseScreen;

    Bool changed;               /* some config changed */
    Bool configChanged;         /* configuration changed */
    Bool layoutChanged;         /* screen layout changed */
    Bool resourcesChanged;      /* screen resources change */
    Bool leasesChanged;         /* leases change */

    CARD16 minWidth, minHeight;
    CARD16 maxWidth, maxHeight;
    CARD16 width, height;       /* last known screen size */
    CARD16 mmWidth, mmHeight;   /* last known screen size */

    int numOutputs;
    RROutputPtr* outputs;
    RROutputPtr primaryOutput;

    int numCrtcs;
    RRCrtcPtr* crtcs;

    /* Last known pointer position */
    RRCrtcPtr pointerCrtc;

    /*
     * Configuration information
     */
    Rotation rotations;
    CARD16 reqWidth, reqHeight;

    int nSizes;
    RRScreenSizePtr pSizes;

    Rotation rotation;
    int rate;
    int size;

    Bool discontiguous;

    RRProviderPtr provider;

    RRProviderDestroyProcPtr rrProviderDestroy;

    int numMonitors;
    RRMonitorPtr* monitors;

    XList leases;

    RRRequestLeaseProcPtr rrRequestLease;
    RRGetLeaseProcPtr rrGetLease;

static if (RANDR_12_INTERFACE) {
    RRCrtcGetProcPtr rrCrtcGet;
}
}alias rrScrPrivRec = _rrScrPriv;
alias rrScrPrivPtr = _rrScrPriv*;

DevPrivateKeyRec rrPrivKeyRec;

enum rrPrivKey = (&rrPrivKeyRec);

enum string rrGetScrPriv(string pScr) = `(cast(rrScrPrivPtr)dixLookupPrivate(&(` ~ pScr ~ `).devPrivates, rrPrivKey))`;
enum string rrScrPriv(string pScr) = `rrScrPrivPtr pScrPriv = ` ~ rrGetScrPriv!(pScr) ~ `;`;
enum string SetRRScreen(string s,string p) = `dixSetPrivate(&(` ~ s ~ `).devPrivates, rrPrivKey, ` ~ p ~ `);`;

/*
 * each window has a list of clients requesting
 * RRNotify events.  Each client has a resource
 * for each window it selects RRNotify input for,
 * this resource is used to delete the RRNotifyRec
 * entry from the per-window queue.
 */

alias RREventPtr = _RREvent*;

struct _RREvent {
    RREventPtr next;
    ClientPtr client;
    WindowPtr window;
    XID clientResource;
    int mask;
}
alias RREventRec = _RREvent;
// alias RREventPtr = RREventRec*;

struct _RRTimes {
    TimeStamp setTime;
    TimeStamp configTime;
}alias RRTimesRec = _RRTimes;
alias RRTimesPtr = _RRTimes*;

struct _RRClient {
    int major_version;
    int minor_version;
/*  RRTimesRec	times[0]; */
}alias RRClientRec = _RRClient;
alias RRClientPtr = _RRClient*;

static if (RANDR_12_INTERFACE) {
/*
 * Set the range of sizes for the screen
 */
// void  RRScreenSetSizeRange(ScreenPtr pScreen, CARD16 minWidth, CARD16 minHeight, CARD16 maxWidth, CARD16 maxHeight);
}

/* rrscreen.c */
/*
 * Notify the extension that the screen size has been changed.
 * The driver is responsible for calling this whenever it has changed
 * the size of the screen
 */
void  RRScreenSizeNotify(ScreenPtr pScreen);

/*
 * Request that the screen be resized
 */
void  RRScreenSizeSet(ScreenPtr pScreen, CARD16 width, CARD16 height, CARD32 mmWidth, CARD32 mmHeight);

/*
 * Send ConfigureNotify event to root window when 'something' happens
 */
void  RRSendConfigNotify(ScreenPtr pScreen);

/* randr.c */
/* set a screen change on the primary screen */
// void  RRSetChanged(ScreenPtr pScreen);

/*
 * Send all pending events
 */
// void  RRTellChanged(ScreenPtr pScreen);

/*
 * Poll the driver for changed information
 */
// void  RRGetInfo(ScreenPtr pScreen, Bool force_query);

// void  RRScreenInit(ScreenPtr pScreen);

// void  RRFirstOutput(ScreenPtr pScreen);

/*
 * This is the old interface, deprecated but left
 * around for compatibility
 */

/*
 * Then, register the specific size with the screen
 */

// void  RRRegisterSize(ScreenPtr pScreen, short width, short height, short mmWidth, short mmHeight);

// void  RRRegisterRate(ScreenPtr pScreen, RRScreenSizePtr pSize, int rate);

/*
 * Finally, set the current configuration of the screen
 */

// void  RRSetCurrentConfig(ScreenPtr pScreen, Rotation rotation, int rate, RRScreenSizePtr pSize);

/* rrcrtc.c */

/*
 * Create a CRTC
 */
// void  RRCrtcCreate(ScreenPtr pScreen, void* devPrivate);

/*
 * Set the allowed rotations on a CRTC
 */
// void  RRCrtcSetRotations(RRCrtcPtr crtc, Rotation rotations);

/*
 * Notify the extension that the Crtc has been reconfigured,
 * the driver calls this whenever it has updated the mode
 */
// void  RRCrtcNotify(RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, RRTransformPtr transform, int numOutputs, RROutputPtr* outputs);

/*
 * Request that the Crtc be reconfigured
 */
// void  RRCrtcSet(RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, int numOutput, RROutputPtr* outputs);

/*
 * Request that the Crtc gamma be changed
 */

// void  RRCrtcGammaSet(RRCrtcPtr crtc, CARD16* red, CARD16* green, CARD16* blue);

/*
 * Set the size of the gamma table at server startup time
 */

// void  RRCrtcGammaSetSize(RRCrtcPtr crtc, int size);

/* rrmode.c */
/*
 * Find, and if necessary, create a mode
 */

// void  RRModeGet(xRRModeInfo* modeInfo, const(char)* name);

/*
 * Destroy a mode.
 */

// void  RRModeDestroy(RRModePtr mode);

/* rroutput.c */

/*
 * Notify the output of some change. configChanged indicates whether
 * any external configuration (mode list, clones, connected status)
 * has changed, or whether the change was strictly internal
 * (which crtc is in use)
 */
// void  RROutputChanged(RROutputPtr output, Bool configChanged);

/*
 * Create an output
 */

// void  RROutputCreate(ScreenPtr pScreen, const(char)* name, int nameLength, void* devPrivate);

/*
 * Notify extension that output parameters have been changed
 */
// void  RROutputSetClones(RROutputPtr output, RROutputPtr* clones, int numClones);

// void  RROutputSetModes(RROutputPtr output, RRModePtr* modes, int numModes, int numPreferred);

// void  RROutputSetCrtcs(RROutputPtr output, RRCrtcPtr* crtcs, int numCrtcs);

// void  RROutputSetConnection(RROutputPtr output, CARD8 connection);

// void  RROutputSetPhysicalSize(RROutputPtr output, int mmWidth, int mmHeight);

void  RROutputDestroy(RROutputPtr output);

// void  RRDeleteOutputProperty(RROutputPtr output, Atom property);

// void  RRPostPendingProperties(RROutputPtr output);

// void  RRChangeOutputProperty(RROutputPtr output, Atom property, Atom type, int format, int mode, c_ulong len, const(void)* value, Bool sendevent, Bool pending);

// void  RRConfigureOutputProperty(RROutputPtr output, Atom property, Bool pending, Bool range, Bool immutable_, int num_values, const(INT32)* values);

/* rrprovider.c */
enum PRIME_SYNC_PROP =         "PRIME Synchronization";


/* *just* for backwards compat with legacy proprietary NVidia driver */

// RESTYPE  RRCrtcType;      /* X resource type: Randr CRTC */
// RESTYPE  RRModeType;      /* X resource type: Randr MODE */
// RESTYPE  RROutputType;    /* X resource type: Randr OUTPUT */

/*
 * Set non-desktop property on given output. This flag should be TRUE on
 * outputs where usual desktops shouldn't expand onto (eg. head displays,
 * additional display bars in various handhelds, etc)
 */
void  RROutputSetNonDesktop(RROutputPtr output, Bool non_desktop);

/*
 * Return the area of the frame buffer scanned out by the crtc,
 * taking into account the current mode and rotation
 *
 * @param crtc    the CRTC to query
 * @param width   return buffer for width value
 * @param height  return buffer for height value
 */
// void  RRCrtcGetScanoutSize(RRCrtcPtr crtc, int* width, int* height);

/*
 * Retrieve CRTCs current transform
 *
 * @param crtc    the CRTC to query
 * @return        pointer to CRTCs current transform
 */
// void  RRCrtcGetTransform(RRCrtcPtr crtc);

/*
 * Detach and free a scanout pixmap
 *
 * @param crtc    the CRTC to act on
 */
// void  RRCrtcDetachScanoutPixmap(RRCrtcPtr crtc);

/*
 * Create / allocate new provider structure
 *
 * @param pScreen the screen the provider belongs to
 * @param name    name of the provider (counted string)
 * @param nameLen size of the provider name
 * @return new provider structure, or NULL on failure
 */
// void  RRProviderCreate(ScreenPtr pScreen, const(char)* name, int nameLen);

/*
 * Set provider capabilities field
 *
 * @param provider      the provider whose capabilities are to be set
 * @param capabilities  the new capabilities
 */
// void  RRProviderSetCapabilities(RRProviderPtr provider, uint capabilities);

/*
 * Check whether client is operating on recent enough protocol version
 * to know about refresh rates. This has influence on reply packet formats
 *
 * @param pClient the client to check
 * @return TRUE if client using recent enough protocol version
 */
// void  RRClientKnowsRates(ClientPtr pClient);

/*
 * Set filter on transform structure
 */
// void  RRTransformSetFilter(RRTransformPtr dst, PictFilterPtr filter, XFixed* params, int nparams, int width, int height);

/*
 * Set whether transforms are allowed on a CRTC
 *
 * @param crtc the CRTC to set the flag on
 * @param transforms TRUE if transforms are allowed
 */
// void  RRCrtcSetTransformSupport(RRCrtcPtr crtc, Bool transforms);

/*
 * Set subpixel order on given output
 *
 * @param output  the output to set subpixel order on
 * @param order   subpixel order value to set
 */
// void  RROutputSetSubpixelOrder(RROutputPtr output, int order);

/*
 * Retrieve output property value
 *
 * @param output  the output to query
 * @param property Atom ID of the property to retrieve
 * @param pending  retrieve pending instead of current value
 * @return pointer to property value or NULL (if not found)
 */
// void  RRGetOutputProperty(RROutputPtr output, Atom property, Bool pending);

                          /* _RANDRSTR_H_ */

/*

randr extension implementation structure

Query state:
    ProcRRGetScreenInfo/ProcRRGetScreenResources
	RRGetInfo

	    • Request configuration from driver, either 1.0 or 1.2 style
	    • These functions only record state changes, all
	      other actions are pended until RRTellChanged is called

	    ->rrGetInfo
	    1.0:
		RRRegisterSize
		RRRegisterRate
		RRSetCurrentConfig
	    1.2:
		RRScreenSetSizeRange
		RROutputSetCrtcs
		RRModeGet
		RROutputSetModes
		RROutputSetConnection
		RROutputSetSubpixelOrder
		RROutputSetClones
		RRCrtcNotify

	• Must delay scanning configuration until after ->rrGetInfo returns
	  because some drivers will call SetCurrentConfig in the middle
	  of the ->rrGetInfo operation.

	1.0:

	    • Scan old configuration, mirror to new structures

	    RRScanOldConfig
		RRCrtcCreate
		RROutputCreate
		RROutputSetCrtcs
		RROutputSetConnection
		RROutputSetSubpixelOrder
		RROldModeAdd	• This adds modes one-at-a-time
		    RRModeGet
		RRCrtcNotify

	• send events, reset pointer if necessary

	RRTellChanged
	    WalkTree (sending events)

	    • when layout has changed:
		RRPointerScreenConfigured
		RRSendConfigNotify

Asynchronous state setting (1.2 only)
    When setting state asynchronously, the driver invokes the
    ->rrGetInfo function and then calls RRTellChanged to flush
    the changes to the clients and reset pointer if necessary

Set state

    ProcRRSetScreenConfig
	RRCrtcSet
	    1.2:
		->rrCrtcSet
		    RRCrtcNotify
	    1.0:
		->rrSetConfig
		RRCrtcNotify
	    RRTellChanged
 */


/* From render.h */
// enum SubPixelUnknown = 0;


Bool noRRExtension = FALSE;

version = RR_VALIDATE;
private int RRNScreens;

enum string wrap(string priv,string real_,string mem,string func) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ func ~ `; 
}`;

enum string unwrap(string priv,string real_,string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

int RREventBase;
int RRErrorBase;
RESTYPE RRClientType, RREventType;      /* resource types for event masks */
// DevPrivateKeyRec RRClientPrivateKeyRec;

// DevPrivateKeyRec rrPrivKeyRec;

private void RRClientCallback(CallbackListPtr* list, void* closure, void* data)
{
    NewClientInfoRec* clientinfo = cast(NewClientInfoRec*) data;
    ClientPtr pClient = clientinfo.client;

    mixin(rrClientPriv!("pClient"));
    RRTimesPtr pTimes = cast(RRTimesPtr) (pRRClient + 1);

    pRRClient.major_version = 0;
    pRRClient.minor_version = 0;

    mixin(DIX_FOR_EACH_SCREEN!q{
        mixin(rrScrPriv!("walkScreen"));
        if (pScrPriv) {
            pTimes[walkScreenIdx].setTime = pScrPriv.lastSetTime;
            pTimes[walkScreenIdx].configTime = pScrPriv.lastConfigTime;
        }
    });
}

private void RRCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    mixin(rrScrPriv!("pScreen"));
    int j = void;

    dixScreenUnhookClose(pScreen, &RRCloseScreen);

    foreach(lease; pScrPriv.leases.byEntriesSafe!RRLeasePtr)
        RRTerminateLease(lease);
    for (j = pScrPriv.numCrtcs - 1; j >= 0; j--)
        RRCrtcDestroy(pScrPriv.crtcs[j]);
    for (j = pScrPriv.numOutputs - 1; j >= 0; j--)
        RROutputDestroy(pScrPriv.outputs[j]);

    if (pScrPriv.provider)
        RRProviderDestroy(pScrPriv.provider);

    RRMonitorClose(pScreen);

    free(pScrPriv.crtcs);
    free(pScrPriv.outputs);
    free(pScrPriv);
    RRNScreens -= 1;            /* ok, one fewer screen with RandR running */
}

private void SRRScreenChangeNotifyEvent(xRRScreenChangeNotifyEvent* from, xRRScreenChangeNotifyEvent* to)
{
    to.type = from.type;
    to.rotation = from.rotation;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.configTimestamp, to.configTimestamp);
    cpswapl(from.root, to.root);
    cpswapl(from.window, to.window);
    cpswaps(from.sizeID, to.sizeID);
    cpswaps(from.subpixelOrder, to.subpixelOrder);
    cpswaps(from.widthInPixels, to.widthInPixels);
    cpswaps(from.heightInPixels, to.heightInPixels);
    cpswaps(from.widthInMillimeters, to.widthInMillimeters);
    cpswaps(from.heightInMillimeters, to.heightInMillimeters);
}

private void SRRCrtcChangeNotifyEvent(xRRCrtcChangeNotifyEvent* from, xRRCrtcChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.crtc, to.crtc);
    cpswapl(from.mode, to.mode);
    cpswaps(from.rotation, to.rotation);
    /* pad1 */
    cpswaps(from.x, to.x);
    cpswaps(from.y, to.y);
    cpswaps(from.width, to.width);
    cpswaps(from.height, to.height);
}

private void SRROutputChangeNotifyEvent(xRROutputChangeNotifyEvent* from, xRROutputChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.configTimestamp, to.configTimestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.output, to.output);
    cpswapl(from.crtc, to.crtc);
    cpswapl(from.mode, to.mode);
    cpswaps(from.rotation, to.rotation);
    to.connection = from.connection;
    to.subpixelOrder = from.subpixelOrder;
}

private void SRROutputPropertyNotifyEvent(xRROutputPropertyNotifyEvent* from, xRROutputPropertyNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.output, to.output);
    cpswapl(from.atom, to.atom);
    cpswapl(from.timestamp, to.timestamp);
    to.state = from.state;
    /* pad1 */
    /* pad2 */
    /* pad3 */
    /* pad4 */
}

private void SRRProviderChangeNotifyEvent(xRRProviderChangeNotifyEvent* from, xRRProviderChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.provider, to.provider);
}

private void SRRProviderPropertyNotifyEvent(xRRProviderPropertyNotifyEvent* from, xRRProviderPropertyNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.provider, to.provider);
    cpswapl(from.atom, to.atom);
    cpswapl(from.timestamp, to.timestamp);
    to.state = from.state;
    /* pad1 */
    /* pad2 */
    /* pad3 */
    /* pad4 */
}

private void SRRResourceChangeNotifyEvent(xRRResourceChangeNotifyEvent* from, xRRResourceChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
}

private void SRRLeaseNotifyEvent(xRRLeaseNotifyEvent* from, xRRLeaseNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.lease, to.lease);
    to.created = from.created;
}

private void SRRNotifyEvent(xEvent* from, xEvent* to)
{
    switch (from.u.u.detail) {
    case RRNotify_CrtcChange:
        SRRCrtcChangeNotifyEvent(cast(xRRCrtcChangeNotifyEvent*) from,
                                 cast(xRRCrtcChangeNotifyEvent*) to);
        break;
    case RRNotify_OutputChange:
        SRROutputChangeNotifyEvent(cast(xRROutputChangeNotifyEvent*) from,
                                   cast(xRROutputChangeNotifyEvent*) to);
        break;
    case RRNotify_OutputProperty:
        SRROutputPropertyNotifyEvent(cast(xRROutputPropertyNotifyEvent*) from,
                                     cast(xRROutputPropertyNotifyEvent*) to);
        break;
    case RRNotify_ProviderChange:
        SRRProviderChangeNotifyEvent(cast(xRRProviderChangeNotifyEvent*) from,
                                   cast(xRRProviderChangeNotifyEvent*) to);
        break;
    case RRNotify_ProviderProperty:
        SRRProviderPropertyNotifyEvent(cast(xRRProviderPropertyNotifyEvent*) from,
                                       cast(xRRProviderPropertyNotifyEvent*) to);
        break;
    case RRNotify_ResourceChange:
        SRRResourceChangeNotifyEvent(cast(xRRResourceChangeNotifyEvent*) from,
                                   cast(xRRResourceChangeNotifyEvent*) to);
        break;
    case RRNotify_Lease:
        SRRLeaseNotifyEvent(cast(xRRLeaseNotifyEvent*) from,
                            cast(xRRLeaseNotifyEvent*) to);
        break;
    default:
        break;
    }
}

private bool initialized = false;

Bool RRInit()
{
    /* prevent double init attempts */
    if (initialized)
        return TRUE;

    if (!RRModeInit())
        return FALSE;
    if (!RRCrtcInit())
        return FALSE;
    if (!RROutputInit())
        return FALSE;
    if (!RRProviderInit())
        return FALSE;
    if (!RRLeaseInit())
        return FALSE;

    if (!dixRegisterPrivateKey(&rrPrivKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    initialized = true;
    return TRUE;
}

Bool RRScreenInit(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;

    if (!RRInit())
        return FALSE;

    pScrPriv = cast(rrScrPrivPtr) cast(rrScrPrivRec*) calloc(1, rrScrPrivRec.sizeof);
    if (!pScrPriv)
        return FALSE;

    mixin(SetRRScreen!("pScreen", "pScrPriv"));

    /*
     * Calling function best set these function vectors
     */
    pScrPriv.maxWidth = pScrPriv.minWidth = pScreen.width;
    pScrPriv.maxHeight = pScrPriv.minHeight = pScreen.height;

    pScrPriv.width = pScreen.width;
    pScrPriv.height = pScreen.height;
    pScrPriv.mmWidth = pScreen.mmWidth;
    pScrPriv.mmHeight = pScreen.mmHeight;
    pScrPriv.rotations = RR_Rotate_0;
    pScrPriv.reqWidth = pScreen.width;
    pScrPriv.reqHeight = pScreen.height;
    pScrPriv.rotation = RR_Rotate_0;

    /*
     * This value doesn't really matter -- any client must call
     * GetScreenInfo before reading it which will automatically update
     * the time
     */
    pScrPriv.lastSetTime = currentTime;
    pScrPriv.lastConfigTime = currentTime;

    dixScreenHookClose(pScreen, &RRCloseScreen);

    pScreen.ConstrainCursorHarder = &RRConstrainCursorHarder;
    pScreen.ReplaceScanoutPixmap = &RRReplaceScanoutPixmap;

    pScrPriv.leases.initList();

    RRMonitorInit(pScreen);

    RRNScreens += 1;            /* keep count of screens that implement randr */
    return TRUE;
}

 /*ARGSUSED*/ private int RRFreeClient(void* data, XID id)
{
    RREventPtr pRREvent = void;
    WindowPtr pWin = void;
    RREventPtr* pHead = void; RREventPtr pCur = void, pPrev = void;

    pRREvent = cast(RREventPtr) data;
    pWin = pRREvent.window;
    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixDestroyAccess);
    if (pHead) {
        pPrev = null;
        for (pCur = *pHead; pCur && pCur != pRREvent; pCur = pCur.next)
            pPrev = pCur;
        if (pCur) {
            if (pPrev)
                pPrev.next = pRREvent.next;
            else
                *pHead = pRREvent.next;
        }
    }
    free(cast(void*) pRREvent);
    return 1;
}

 /*ARGSUSED*/ private int RRFreeEvents(void* data, XID id)
{
    RREventPtr* pHead = void; RREventPtr pCur = void, pNext = void;

    pHead = cast(RREventPtr*) data;
    for (pCur = *pHead; pCur; pCur = pNext) {
        pNext = pCur.next;
        FreeResource(cast(uint)pCur.clientResource, RRClientType);
        free(cast(void*) pCur);
    }
    free(cast(void*) pHead);
    return 1;
}

void RRExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (RRNScreens == 0)
        return;

    if (!dixRegisterPrivateKey(&RRClientPrivateKeyRec, PRIVATE_CLIENT,
                               cast(uint)((RRClientRec).sizeof +
                               screenInfo.numScreens * RRTimesRec.sizeof)))
        return;
    if (!AddCallback(&ClientStateCallback, &RRClientCallback, null))
        return;

    RRClientType = CreateNewResourceType(&RRFreeClient, "RandRClient");
    if (!RRClientType)
        return;
    RREventType = CreateNewResourceType(&RRFreeEvents, "RandREvent");
    if (!RREventType)
        return;
    extEntry = AddExtension(RANDR_NAME, RRNumberEvents, RRNumberErrors,
                            &ProcRRDispatch, &ProcRRDispatch,
                            null, &StandardMinorOpcode);
    if (!extEntry)
        return;
    RRErrorBase = extEntry.errorBase;
    RREventBase = extEntry.eventBase;
    EventSwapVector[RREventBase + RRScreenChangeNotify] = cast(EventSwapPtr)
        &SRRScreenChangeNotifyEvent;
    EventSwapVector[RREventBase + RRNotify] = cast(EventSwapPtr)
        &SRRNotifyEvent;

    RRModeInitErrorValue();
    RRCrtcInitErrorValue();
    RROutputInitErrorValue();
    RRProviderInitErrorValue();
static if(XINERAMA){
    RRXineramaExtensionInit();
} /* XINERAMA */
}

void RRResourcesChanged(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    pScrPriv.resourcesChanged = TRUE;

    RRSetChanged(pScreen);
}

private void RRDeliverResourceEvent(ClientPtr client, WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(rrScrPriv!("pScreen"));

    xRRResourceChangeNotifyEvent re = {
        type: cast(ubyte)(RRNotify + RREventBase),
        subCode: RRNotify_ResourceChange,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        window: cast(uint)pWin.drawable.id
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &re);
}

private int TellChanged(WindowPtr pWin, void* value)
{
    RREventPtr* pHead = void; RREventPtr pRREvent = void;
    ClientPtr client = void;
    ScreenPtr pScreen = pWin.drawable.pScreen;
    rrScrPrivPtr pSecondaryScrPriv = void;

    mixin(rrScrPriv!("pScreen"));
    int i = void;

    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixReadAccess);
    if (!pHead)
        return WT_WALKCHILDREN;

    for (pRREvent = *pHead; pRREvent; pRREvent = pRREvent.next) {
        client = pRREvent.client;
        if (client == serverClient || client.clientGone)
            continue;

        if (pRREvent.mask & RRScreenChangeNotifyMask)
            RRDeliverScreenEvent(client, pWin, pScreen);

        if (pRREvent.mask & RRCrtcChangeNotifyMask) {
            for (i = 0; i < pScrPriv.numCrtcs; i++) {
                RRCrtcPtr crtc = pScrPriv.crtcs[i];

                if (crtc.changed)
                    RRDeliverCrtcEvent(client, pWin, crtc);
            }

            foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
                if (!iter.is_output_secondary)
                    continue;

                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                for (i = 0; i < pSecondaryScrPriv.numCrtcs; i++) {
                    RRCrtcPtr crtc = pSecondaryScrPriv.crtcs[i];

                    if (crtc.changed)
                        RRDeliverCrtcEvent(client, pWin, crtc);
                }
            }
        }

        if (pRREvent.mask & RROutputChangeNotifyMask) {
            for (i = 0; i < pScrPriv.numOutputs; i++) {
                RROutputPtr output = pScrPriv.outputs[i];

                if (output.changed)
                    RRDeliverOutputEvent(client, pWin, output);
            }

            foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
                if (!iter.is_output_secondary)
                    continue;

                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                for (i = 0; i < pSecondaryScrPriv.numOutputs; i++) {
                    RROutputPtr output = pSecondaryScrPriv.outputs[i];

                    if (output.changed)
                        RRDeliverOutputEvent(client, pWin, output);
                }
            }
        }

        if (pRREvent.mask & RRProviderChangeNotifyMask) {
            foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                if (pSecondaryScrPriv.provider.changed)
                    RRDeliverProviderEvent(client, pWin, pSecondaryScrPriv.provider);
            }
        }

        if (pRREvent.mask & RRResourceChangeNotifyMask) {
            if (pScrPriv.resourcesChanged) {
                RRDeliverResourceEvent(client, pWin);
            }
        }

        if (pRREvent.mask & RRLeaseNotifyMask) {
            if (pScrPriv.leasesChanged) {
                RRDeliverLeaseEvent(client, pWin);
            }
        }
    }
    return WT_WALKCHILDREN;
}

void RRSetChanged(ScreenPtr pScreen)
{
    /* set changed bits on the primary screen only */
    ScreenPtr primary = void;
    mixin(rrScrPriv!("pScreen"));
    rrScrPrivPtr primarysp = void;

    if (pScreen.isGPU) {
        primary = pScreen.current_primary;
        if (!primary)
            return;
        primarysp = mixin(rrGetScrPriv!("primary"));
    }
    else {
        primary = pScreen;
        primarysp = pScrPriv;
    }

    primarysp.changed = TRUE;
}

/*
 * Something changed; send events and adjust pointer position
 */
void RRTellChanged(ScreenPtr pScreen)
{
    ScreenPtr primary = void;
    mixin(rrScrPriv!("pScreen"));
    rrScrPrivPtr primarysp = void;
    int i = void;
    rrScrPrivPtr pSecondaryScrPriv = void;

    if (pScreen.isGPU) {
        primary = pScreen.current_primary;
        if (!primary)
            return;
        primarysp = mixin(rrGetScrPriv!("primary"));
    }
    else {
        primary = pScreen;
        primarysp = pScrPriv;
    }

    /* If there's no root window yet, can't send events */
    if (!primary.root)
        return;

    foreach(iter; primary.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));

        if (!iter.is_output_secondary)
            continue;

        if (CompareTimeStamps(primarysp.lastSetTime,
                              pSecondaryScrPriv.lastSetTime) == EARLIER) {
            primarysp.lastSetTime = pSecondaryScrPriv.lastSetTime;
        }
    }

    if (primarysp.changed) {
        UpdateCurrentTimeIf();
        if (primarysp.configChanged) {
            primarysp.lastConfigTime = currentTime;
            primarysp.configChanged = FALSE;
        }
        pScrPriv.changed = FALSE;
        primarysp.changed = FALSE;

        WalkTree(primary, &TellChanged, cast(void*) primary);

        primarysp.resourcesChanged = FALSE;

        for (i = 0; i < pScrPriv.numOutputs; i++)
            pScrPriv.outputs[i].changed = FALSE;
        for (i = 0; i < pScrPriv.numCrtcs; i++)
            pScrPriv.crtcs[i].changed = FALSE;

        foreach(iter; primary.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
            pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
            pSecondaryScrPriv.provider.changed = FALSE;
            if (iter.is_output_secondary) {
                for (i = 0; i < pSecondaryScrPriv.numOutputs; i++)
                    pSecondaryScrPriv.outputs[i].changed = FALSE;
                for (i = 0; i < pSecondaryScrPriv.numCrtcs; i++)
                    pSecondaryScrPriv.crtcs[i].changed = FALSE;
            }
        }

        if (primarysp.layoutChanged) {
            pScrPriv.layoutChanged = FALSE;
            RRPointerScreenConfigured(primary);
            RRSendConfigNotify(primary);
        }
    }
}

/*
 * Return the first output which is connected to an active CRTC
 * Used in emulating 1.0 behaviour
 */
RROutputPtr RRFirstOutput(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    RROutputPtr output = void;
    int i = void, j = void;

    if (!pScrPriv)
        return null;

    if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc)
        return pScrPriv.primaryOutput;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        for (j = 0; j < pScrPriv.numOutputs; j++) {
            output = pScrPriv.outputs[j];
            if (output.crtc == crtc)
                return output;
        }
    }
    return null;
}

RRCrtcPtr RRFirstEnabledCrtc(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    RROutputPtr output = void;
    int i = void, j = void;

    if (!pScrPriv)
        return null;

    if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc &&
        pScrPriv.primaryOutput.pScreen == pScreen)
        return pScrPriv.primaryOutput.crtc;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        for (j = 0; j < pScrPriv.numOutputs; j++) {
            output = pScrPriv.outputs[j];
            if (output.crtc == crtc && crtc.mode)
                return crtc;
        }
    }
    return null;
}


CARD16 RRVerticalRefresh(xRRModeInfo* mode)
{
    CARD32 refresh = void;
    CARD32 dots = mode.hTotal * mode.vTotal;

    if (!dots)
        return 0;
    refresh = (mode.dotClock + dots / 2) / dots;
    if (refresh > 0xffff)
        refresh = 0xffff;
    return cast(CARD16) refresh;
}
