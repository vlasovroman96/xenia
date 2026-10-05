module include.randrstr;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2000 Compaq Computer Corporation
 * Copyright © 2002 Hewlett-Packard Company
 * Copyright © 2006 Intel Corporation
 * Copyright © 2008 Red Hat, Inc.
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
 
//public import x11.X;
//public import x11.Xproto;

public import include.xlibre_ptrtypes;
public import include.misc;
public import include.os;
public import include.dixstruct;
public import include.resource;
public import include.scrnintstr;
public import include.windowstr;
public import include.pixmapstr;
public import include.extnsionst;
public import include.servermd;
public import randr.rrtransform;
import include.rrtransform;
import include.randrstr;

//public import externs.X11.extensions._randr;
public import externs.X11.extensions.randrproto;
//public import externs.X11.extensions._render;      /* we share subpixel order information */
public import include.picturestr;
// //public import x11.Xfuncproto;

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
    ATOM propertyName;
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
    xorg_list list;
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

    xorg_list leases;

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
