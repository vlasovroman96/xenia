module include.xf86Crtc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
 * Copyright © 2011 Aaron Plattner
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
 */
import build.xlibre_server;
 
public import include.edid;
public import include.randrstr;
public import xf86Modes;
public import xf86Cursor;
public import include.xf86i2c;
public import include.damage;
public import include.picturestr;
import include.rrtransform;
import include.xf86Parser;
import include.xf86Cursor;
import include.scrintstr;
import hw.xfree86.modes.xf86Crtc;


/* Compat definitions for older X Servers. */
// enum M_T_PREFERRED =	0x08;

// enum M_T_DRIVER =	0x40;

// enum M_T_USERPREF =	0x80;

// enum HARDWARE_CURSOR_ARGB =				0x00004000;


alias xf86CrtcRec = _xf86Crtc;
alias xf86CrtcPtr = _xf86Crtc*;
alias xf86OutputRec = _xf86Output;
alias xf86OutputPtr = _xf86Output*;
alias xf86LeaseRec = _xf86Lease;
alias xf86LeasePtr = _xf86Lease*;

/* define a standard for connector types */
enum xf86ConnectorType {
    XF86ConnectorNone,
    XF86ConnectorVGA,
    XF86ConnectorDVI_I,
    XF86ConnectorDVI_D,
    XF86ConnectorDVI_A,
    XF86ConnectorComposite,
    XF86ConnectorSvideo,
    XF86ConnectorComponent,
    XF86ConnectorLFP,
    XF86ConnectorProprietary,
    XF86ConnectorHDMI,
    XF86ConnectorDisplayPort,
}
alias XF86ConnectorNone = xf86ConnectorType.XF86ConnectorNone;
alias XF86ConnectorVGA = xf86ConnectorType.XF86ConnectorVGA;
alias XF86ConnectorDVI_I = xf86ConnectorType.XF86ConnectorDVI_I;
alias XF86ConnectorDVI_D = xf86ConnectorType.XF86ConnectorDVI_D;
alias XF86ConnectorDVI_A = xf86ConnectorType.XF86ConnectorDVI_A;
alias XF86ConnectorComposite = xf86ConnectorType.XF86ConnectorComposite;
alias XF86ConnectorSvideo = xf86ConnectorType.XF86ConnectorSvideo;
alias XF86ConnectorComponent = xf86ConnectorType.XF86ConnectorComponent;
alias XF86ConnectorLFP = xf86ConnectorType.XF86ConnectorLFP;
alias XF86ConnectorProprietary = xf86ConnectorType.XF86ConnectorProprietary;
alias XF86ConnectorHDMI = xf86ConnectorType.XF86ConnectorHDMI;
alias XF86ConnectorDisplayPort = xf86ConnectorType.XF86ConnectorDisplayPort;


enum xf86OutputStatus {
    XF86OutputStatusConnected,
    XF86OutputStatusDisconnected,
    XF86OutputStatusUnknown
}
alias XF86OutputStatusConnected = xf86OutputStatus.XF86OutputStatusConnected;
alias XF86OutputStatusDisconnected = xf86OutputStatus.XF86OutputStatusDisconnected;
alias XF86OutputStatusUnknown = xf86OutputStatus.XF86OutputStatusUnknown;


enum xf86DriverTransforms {
    XF86DriverTransformNone = 0,
    XF86DriverTransformOutput = 1 << 0,
    XF86DriverTransformCursorImage = 1 << 1,
    XF86DriverTransformCursorPosition = 1 << 2,
}
alias XF86DriverTransformNone = xf86DriverTransforms.XF86DriverTransformNone;
alias XF86DriverTransformOutput = xf86DriverTransforms.XF86DriverTransformOutput;
alias XF86DriverTransformCursorImage = xf86DriverTransforms.XF86DriverTransformCursorImage;
alias XF86DriverTransformCursorPosition = xf86DriverTransforms.XF86DriverTransformCursorPosition;



struct xf86CrtcTileInfo {
    uint group_id;
    uint flags;
    uint num_h_tile;
    uint num_v_tile;
    uint tile_h_loc;
    uint tile_v_loc;
    uint tile_h_size;
    uint tile_v_size;
}

struct _xf86CrtcFuncs {
   /**
    * Turns the crtc on/off, or sets intermediate power levels if available.
    *
    * Unsupported intermediate modes drop to the lower power setting.  If the
    * mode is DPMSModeOff, the crtc must be disabled sufficiently for it to
    * be safe to call mode_set.
    */
    void function(xf86CrtcPtr crtc, int mode) @nogc nothrow dpms;

   /**
    * Saves the crtc's state for restoration on VT switch.
    */
    void function(xf86CrtcPtr crtc) @nogc nothrow save;

   /**
    * Restore's the crtc's state at VT switch.
    */
    void function(xf86CrtcPtr crtc) @nogc nothrow restore;

    /**
     * Lock CRTC prior to mode setting, mostly for DRI.
     * Returns whether unlock is needed
     */
    Bool function(xf86CrtcPtr crtc) @nogc nothrow lock;

    /**
     * Unlock CRTC after mode setting, mostly for DRI
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow unlock;

    /**
     * Callback to adjust the mode to be set in the CRTC.
     *
     * This allows a CRTC to adjust the clock or even the entire set of
     * timings, which is used for panels with fixed timings or for
     * buses with clock limitations.
     */
    Bool function(xf86CrtcPtr crtc, DisplayModePtr mode, DisplayModePtr adjusted_mode) @nogc nothrow mode_fixup;

    /**
     * Prepare CRTC for an upcoming mode set.
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow prepare;

    /**
     * Callback for setting up a video mode after fixups have been made.
     */
    void function(xf86CrtcPtr crtc, DisplayModePtr mode, DisplayModePtr adjusted_mode, int x, int y) @nogc nothrow mode_set;

    /**
     * Commit mode changes to a CRTC
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow commit;

    /* Set the color ramps for the CRTC to the given values. */
    void function(xf86CrtcPtr crtc, CARD16* red, CARD16* green, CARD16* blue, int size) @nogc nothrow gamma_set;

    /**
     * Allocate the shadow area, delay the pixmap creation until needed
     */
    void* function(xf86CrtcPtr crtc, int width, int height) @nogc nothrow shadow_allocate;

    /**
     * Create shadow pixmap for rotation support
     */
    PixmapPtr function(xf86CrtcPtr crtc, void* data, int width, int height) @nogc nothrow shadow_create;

    /**
     * Destroy shadow pixmap
     */
    void function(xf86CrtcPtr crtc, PixmapPtr pPixmap, void* data) @nogc nothrow shadow_destroy;

    /**
     * Set cursor colors
     */
    void function(xf86CrtcPtr crtc, int bg, int fg) @nogc nothrow set_cursor_colors;

    /**
     * Set cursor position
     */
    void function(xf86CrtcPtr crtc, int x, int y) @nogc nothrow set_cursor_position;

    /**
     * Show cursor
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow show_cursor;
    Bool function(xf86CrtcPtr crtc) @nogc nothrow show_cursor_check;

    /**
     * Hide cursor
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow hide_cursor;

    /**
     * Load monochrome image
     */
    void function(xf86CrtcPtr crtc, CARD8* image) @nogc nothrow load_cursor_image;
    Bool function(xf86CrtcPtr crtc, CARD8* image) @nogc nothrow load_cursor_image_check;

    /**
     * Load ARGB image
     */
    void function(xf86CrtcPtr crtc, CARD32* image) @nogc nothrow load_cursor_argb;
    Bool function(xf86CrtcPtr crtc, CARD32* image) @nogc nothrow load_cursor_argb_check;

    /**
     * Clean up driver-specific bits of the crtc
     */
    void function(xf86CrtcPtr crtc) @nogc nothrow destroy;

    /**
     * Less fine-grained mode setting entry point for kernel modesetting
     */
    Bool function(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, int x, int y) @nogc nothrow set_mode_major;

    /**
     * Callback for panning. Doesn't change the mode.
     * Added in ABI version 2
     */
    void function(xf86CrtcPtr crtc, int x, int y) @nogc nothrow set_origin;

    /**
     */
    Bool function(xf86CrtcPtr crtc, PixmapPtr pixmap) @nogc nothrow set_scanout_pixmap;

}alias xf86CrtcFuncsRec = _xf86CrtcFuncs;
alias xf86CrtcFuncsPtr = _xf86CrtcFuncs*;

enum XF86_CRTC_VERSION = 8;

struct _xf86Crtc {
    /**
     * ABI versioning
     */
    int version_;

    /**
     * Associated ScrnInfo
     */
    ScrnInfoPtr scrn;

    /**
     * Desired state of this CRTC
     *
     * Set when this CRTC should be driving one or more outputs
     */
    Bool enabled;

    /**
     * Active mode
     *
     * This reflects the mode as set in the CRTC currently
     * It will be cleared when the VT is not active or
     * during server startup
     */
    DisplayModeRec mode;
    Rotation rotation;
    PixmapPtr rotatedPixmap;
    void* rotatedData;

    /**
     * Position on screen
     *
     * Locates this CRTC within the frame buffer
     */
    int x, y;

    /**
     * Desired mode
     *
     * This is set to the requested mode, independent of
     * whether the VT is active. In particular, it receives
     * the startup configured mode and saves the active mode
     * on VT switch.
     */
    DisplayModeRec desiredMode;
    Rotation desiredRotation;
    int desiredX, desiredY;

    /** crtc-specific functions */
    const(xf86CrtcFuncsRec)* funcs;

    /**
     * Driver private
     *
     * Holds driver-private information
     */
    void* driver_private;

// static if (RANDR_12_INTERFACE) {
    /**
     * RandR crtc
     *
     * When RandR 1.2 is available, this
     * points at the associated crtc object
     */
    RRCrtcPtr randr_crtc;
// } else {
//     void* randr_crtc;
// }

    /**
     * Current cursor is ARGB
     */
    Bool cursor_argb;
    /**
     * Track whether cursor is within CRTC range
     */
    Bool cursor_in_range;
    /**
     * Track state of cursor associated with this CRTC
     */
    Bool cursor_shown;

    /**
     * Current transformation matrix
     */
    PictTransform crtc_to_framebuffer;
    /* framebuffer_to_crtc was removed in ABI 2 */
    pixman_f_transform f_crtc_to_framebuffer;      /* ABI 2 */
    pixman_f_transform f_framebuffer_to_crtc;      /* ABI 2 */
    PictFilterPtr filter;       /* ABI 2 */
    XFixed* params;             /* ABI 2 */
    int nparams;                /* ABI 2 */
    int filter_width;           /* ABI 2 */
    int filter_height;          /* ABI 2 */
    Bool transform_in_use;
    RRTransformRec transform;   /* ABI 2 */
    Bool transformPresent;      /* ABI 2 */
    RRTransformRec desiredTransform;    /* ABI 2 */
    Bool desiredTransformPresent;       /* ABI 2 */
    /**
     * Bounding box in screen space
     */
    BoxRec bounds;
    /**
     * Panning:
     * TotalArea: total panning area, larger than CRTC's size
     * TrackingArea: Area of the pointer for which the CRTC is panned
     * border: Borders of the displayed CRTC area which induces panning if the pointer reaches them
     * Added in ABI version 2
     */
    BoxRec panningTotalArea;
    BoxRec panningTrackingArea;
    INT16[4] panningBorder;

    /**
     * Current gamma, especially useful after initial config.
     * Added in ABI version 3
     */
    CARD16* gamma_red;
    CARD16* gamma_green;
    CARD16* gamma_blue;
    int gamma_size;

    /**
     * Actual state of this CRTC
     *
     * Set to TRUE after modesetting, set to FALSE if no outputs are connected
     * Added in ABI version 3
     */
    Bool active;
    /**
     * Clear the shadow
     */
    Bool shadowClear;

    /**
     * Indicates that the driver is handling some or all transforms:
     *
     * XF86DriverTransformOutput: The driver handles the output transform, so
     * the shadow surface should be disabled.  The driver writes this field
     * before calling xf86CrtcRotate to indicate that it is handling the
     * transform (including rotation and reflection).
     *
     * XF86DriverTransformCursorImage: Setting this flag causes the server to
     * pass the untransformed cursor image to the driver hook.
     *
     * XF86DriverTransformCursorPosition: Setting this flag causes the server
     * to pass the untransformed cursor position to the driver hook.
     *
     * Added in ABI version 4, changed to xf86DriverTransforms in ABI version 7
     */
    xf86DriverTransforms driverIsPerformingTransform;

    /* Added in ABI version 5
     */
    PixmapPtr current_scanout;

    /* Added in ABI version 6
     */
    PixmapPtr current_scanout_back;
}

struct _xf86OutputFuncs {
    /**
     * Called to allow the output a chance to create properties after the
     * RandR objects have been created.
     */
    void function(xf86OutputPtr output) @nogc nothrow create_resources;

    /**
     * Turns the output on/off, or sets intermediate power levels if available.
     *
     * Unsupported intermediate modes drop to the lower power setting.  If the
     * mode is DPMSModeOff, the output must be disabled, as the DPLL may be
     * disabled afterwards.
     */
    void function(xf86OutputPtr output, int mode) @nogc nothrow dpms;

    /**
     * Saves the output's state for restoration on VT switch.
     */
    void function(xf86OutputPtr output) @nogc nothrow save;

    /**
     * Restore's the output's state at VT switch.
     */
    void function(xf86OutputPtr output) @nogc nothrow restore;

    /**
     * Callback for testing a video mode for a given output.
     *
     * This function should only check for cases where a mode can't be supported
     * on the output specifically, and not represent generic CRTC limitations.
     *
     * \return MODE_OK if the mode is valid, or another MODE_* otherwise.
     */
    int function(xf86OutputPtr output, DisplayModePtr pMode) @nogc nothrow mode_valid;

    /**
     * Callback to adjust the mode to be set in the CRTC.
     *
     * This allows an output to adjust the clock or even the entire set of
     * timings, which is used for panels with fixed timings or for
     * buses with clock limitations.
     */
    Bool function(xf86OutputPtr output, DisplayModePtr mode, DisplayModePtr adjusted_mode) @nogc nothrow mode_fixup;

    /**
     * Callback for preparing mode changes on an output
     */
    void function(xf86OutputPtr output) @nogc nothrow prepare;

    /**
     * Callback for committing mode changes on an output
     */
    void function(xf86OutputPtr output) @nogc nothrow commit;

    /**
     * Callback for setting up a video mode after fixups have been made.
     *
     * This is only called while the output is disabled.  The dpms callback
     * must be all that's necessary for the output, to turn the output on
     * after this function is called.
     */
    void function(xf86OutputPtr output, DisplayModePtr mode, DisplayModePtr adjusted_mode) @nogc nothrow mode_set;

    /**
     * Probe for a connected output, and return detect_status.
     */
     xf86OutputStatus function(xf86OutputPtr output) @nogc nothrow detect;

    /**
     * Query the device for the modes it provides.
     *
     * This function may also update MonInfo, mm_width, and mm_height.
     *
     * \return singly-linked list of modes or NULL if no modes found.
     */
     DisplayModePtr function(xf86OutputPtr output) @nogc nothrow get_modes;

// static if (RANDR_12_INTERFACE) {
    /**
     * Callback when an output's property has changed.
     */
    Bool function(xf86OutputPtr output, Atom property, RRPropertyValuePtr value) set_property;
// }
// static if (RANDR_13_INTERFACE) {
    /**
     * Callback to get an updated property value
     */
    Bool function(xf86OutputPtr output, Atom property) get_property;
// }
// static if (RANDR_GET_CRTC_INTERFACE) {
    /**
     * Callback to get current CRTC for a given output
     */
     xf86CrtcPtr function(xf86OutputPtr output) get_crtc;
// }
    /**
     * Clean up driver-specific bits of the output
     */
    void function(xf86OutputPtr output) destroy;
}alias xf86OutputFuncsRec = _xf86OutputFuncs;
alias xf86OutputFuncsPtr = _xf86OutputFuncs*;

enum XF86_OUTPUT_VERSION = 3;

struct _xf86Output {
    /**
     * ABI versioning
     */
    int version_;

    /**
     * Associated ScrnInfo
     */
    ScrnInfoPtr scrn;

    /**
     * Currently connected crtc (if any)
     *
     * If this output is not in use, this field will be NULL.
     */
    xf86CrtcPtr crtc;

    /**
     * Possible CRTCs for this output as a mask of crtc indices
     */
    CARD32 possible_crtcs;

    /**
     * Possible outputs to share the same CRTC as a mask of output indices
     */
    CARD32 possible_clones;

    /**
     * Whether this output can support interlaced modes
     */
    Bool interlaceAllowed;

    /**
     * Whether this output can support double scan modes
     */
    Bool doubleScanAllowed;

    /**
     * List of available modes on this output.
     *
     * This should be the list from get_modes(), plus perhaps additional
     * compatible modes added later.
     */
    DisplayModePtr probed_modes;

    /**
     * Options parsed from the related monitor section
     */
    OptionInfoPtr options;

    /**
     * Configured monitor section
     */
    XF86ConfMonitorPtr conf_monitor;

    /**
     * Desired initial position
     */
    int initial_x, initial_y;

    /**
     * Desired initial rotation
     */
    Rotation initial_rotation;

    /**
     * Current connection status
     *
     * This indicates whether a monitor is known to be connected
     * to this output or not, or whether there is no way to tell
     */
    xf86OutputStatus status;

    /** EDID monitor information */
    xf86MonPtr MonInfo;

    /** subpixel order */
    int subpixel_order;

    /** Physical size of the currently attached output device. */
    int mm_width, mm_height;

    /** Output name */
    char* name;

    /** output-specific functions */
    const(xf86OutputFuncsRec)* funcs;

    /** driver private information */
    void* driver_private;

    /** Whether to use the old per-screen Monitor config section */
    Bool use_screen_monitor;

    /** For pre-init, whether the output should be excluded from the
     * desktop when there are other viable outputs to use
     */
    Bool non_desktop;

static if (RANDR_12_INTERFACE) {
    /**
     * RandR 1.2 output structure.
     *
     * When RandR 1.2 is available, this points at the associated
     * RandR output structure and is created when this output is created
     */
    RROutputPtr randr_output;
} else {
    void* randr_output;
}
    /**
     * Desired initial panning
     * Added in ABI version 2
     */
    BoxRec initialTotalArea;
    BoxRec initialTrackingArea;
    INT16[4] initialBorder;

    xf86CrtcTileInfo tile_info;
}

struct _xf86ProviderFuncs {
    /**
     * Called to allow the provider a chance to create properties after the
     * RandR objects have been created.
     */
    void function(ScrnInfoPtr scrn) create_resources;

    /**
     * Callback when an provider's property has changed.
     */
    Bool function(ScrnInfoPtr scrn, Atom property, RRPropertyValuePtr value) set_property;

    /**
     * Callback to get an updated property value
     */
    Bool function(ScrnInfoPtr provider, Atom property) get_property;

}alias xf86ProviderFuncsRec = _xf86ProviderFuncs;
alias xf86ProviderFuncsPtr = _xf86ProviderFuncs*;

enum XF86_LEASE_VERSION =      1;

struct _xf86Lease {
    /**
     * ABI versioning
     */
    int version_;

    /**
     * Associated ScrnInfo
     */
    ScrnInfoPtr scrn;

    /**
     * Driver private
     */
    void* driver_private;

    /**
     * RandR lease
     */
    RRLeasePtr randr_lease;

    /*
     * Contents of the lease
     */

    /**
     * Number of leased CRTCs
     */
    int num_crtc;

    /**
     * Number of leased outputs
     */
    int num_output;

    /**
     * Array of pointers to leased CRTCs
     */
    RRCrtcPtr* crtcs;

    /**
     * Array of pointers to leased outputs
     */
    RROutputPtr* outputs;
}

struct _xf86CrtcConfigFuncs {
    /**
     * Requests that the driver resize the screen.
     *
     * The driver is responsible for updating scrn->virtualX and scrn->virtualY.
     * If the requested size cannot be set, the driver should leave those values
     * alone and return FALSE.
     *
     * A naive driver that cannot reallocate the screen may simply change
     * virtual[XY].  A more advanced driver will want to also change the
     * devPrivate.ptr and devKind of the screen pixmap, update any offscreen
     * pixmaps it may have moved, and change pScrn->displayWidth.
     */
    Bool function(ScrnInfoPtr scrn, int width, int height) resize;

    /**
     * Requests that the driver create a lease
     */
    int function(RRLeasePtr lease, int* fd) create_lease;

    /**
     * Ask the driver to terminate a lease, freeing all
     * driver resources
     */
    void function(RRLeasePtr lease) terminate_lease;
}alias xf86CrtcConfigFuncsRec = _xf86CrtcConfigFuncs;
alias xf86CrtcConfigFuncsPtr = _xf86CrtcConfigFuncs*;

/*
 * The driver calls this when it detects that a lease
 * has been terminated
 */
void  xf86CrtcLeaseTerminated(RRLeasePtr lease);

void  xf86CrtcLeaseStarted(RRLeasePtr lease);

alias xf86_crtc_notify_proc_ptr = void function(ScreenPtr pScreen);

struct _xf86CrtcConfig {
    int num_output;
    xf86OutputPtr* output;
    /**
     * compat_output is used whenever we deal
     * with legacy code that only understands a single
     * output. pScrn->modes will be loaded from this output,
     * adjust frame will whack this output, etc.
     */
    int compat_output;

    int num_crtc;
    xf86CrtcPtr* crtc;

    int minWidth, minHeight;
    int maxWidth, maxHeight;

    /* For crtc-based rotation */
    DamagePtr rotation_damage;
    Bool rotation_damage_registered;

    /* DGA */
    uint dga_flags;
    c_ulong dga_address;
    DGAModePtr dga_modes;
    int dga_nmode;
    int dga_width, dga_height, dga_stride;
    DisplayModePtr dga_save_mode;

    const(xf86CrtcConfigFuncsRec)* funcs;

    CreateScreenResourcesProcPtr CreateScreenResources;

    void* _dummy1; // required in place of a removed field for ABI compatibility

    /* Cursor information */
    xf86CursorInfoPtr cursor_info;
    CursorPtr cursor;
    CARD8* cursor_image;
    Bool cursor_on;
    CARD32 cursor_fg, cursor_bg;

    /**
     * Options parsed from the related device section
     */
    OptionInfoPtr options;

    Bool debug_modes;

    /* wrap screen BlockHandler for rotation */
    ScreenBlockHandlerProcPtr BlockHandler;

    /* callback when crtc configuration changes */
    xf86_crtc_notify_proc_ptr xf86_crtc_notify;

    char* name;
    const(xf86ProviderFuncsRec)* provider_funcs;
static if (RANDR_12_INTERFACE) {
    RRProviderPtr randr_provider;
} else {
    void* randr_provider;
}
}alias xf86CrtcConfigRec = _xf86CrtcConfig;
alias xf86CrtcConfigPtr = _xf86CrtcConfig*;

// int  xf86CrtcConfigPrivateIndex;

enum string XF86_CRTC_CONFIG_PTR(string p) = `(cast(xf86CrtcConfigPtr) ((` ~ p ~ `).privates[xf86CrtcConfigPrivateIndex].ptr))`;

auto xf86CompatOutput(ScrnInfoPtr pScrn)
{
    xf86CrtcConfigPtr config = void;

    if (xf86CrtcConfigPrivateIndex == -1)
        return null;
    config = mixin(XF86_CRTC_CONFIG_PTR!(`pScrn`));
    if ((config is null) || (config.compat_output < 0))
        return null;
    return config.output[config.compat_output];
}

auto xf86CompatCrtc(ScrnInfoPtr pScrn)
{
    xf86OutputPtr compat_output = xf86CompatOutput(pScrn);

    if (!compat_output)
        return null;
    return compat_output.crtc;
}

auto xf86CompatRRCrtc(ScrnInfoPtr pScrn)
{
    xf86CrtcPtr compat_crtc = xf86CompatCrtc(pScrn);

    if (!compat_crtc)
        return null;
    return compat_crtc.randr_crtc;
}

/*
 * Initialize xf86CrtcConfig structure
 */

// void  xf86CrtcConfigInit(ScrnInfoPtr scrn, const(xf86CrtcConfigFuncsRec)* funcs);

// void  xf86CrtcSetSizeRange(ScrnInfoPtr scrn, int minWidth, int minHeight, int maxWidth, int maxHeight);

/*
 * Crtc functions
 */
// void  xf86CrtcCreate(ScrnInfoPtr scrn, const(xf86CrtcFuncsRec)* funcs);

// void  xf86CrtcDestroy(xf86CrtcPtr crtc);

/**
 * Sets the given video mode on the given crtc
 */

// void  xf86CrtcSetModeTransform(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, RRTransformPtr transform, int x, int y);

void  xf86CrtcSetMode(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, int x, int y);

// void  xf86CrtcSetOrigin(xf86CrtcPtr crtc, int x, int y);

/*
 * Assign crtc rotation during mode set
 */
// void  xf86CrtcRotate(xf86CrtcPtr crtc);

// void  xf86RotateCrtcRedisplay(xf86CrtcPtr crtc, PixmapPtr dst_pixmap, DrawableRec* src_drawable, RegionPtr region, Bool transform_src);

/*
 * Clean up any rotation data, used when a crtc is turned off
 * as well as when rotation is disabled.
 */
// void  xf86RotateDestroy(xf86CrtcPtr crtc);

/*
 * free shadow memory allocated for all crtcs
 */
void  xf86RotateFreeShadow(ScrnInfoPtr pScrn);

/*
 * Clean up rotation during CloseScreen
 */
// void  xf86RotateCloseScreen(ScreenPtr pScreen);

/**
 * Return whether any output is assigned to the crtc
 */
// void  xf86CrtcInUse(xf86CrtcPtr crtc);

/*
 * Output functions
 */
// void  xf86OutputCreate(ScrnInfoPtr scrn, const(xf86OutputFuncsRec)* funcs, const(char)* name);

void  xf86OutputUseScreenMonitor(xf86OutputPtr output, Bool use_screen_monitor);

void  xf86OutputRename(xf86OutputPtr output, const(char)* name);

// void  xf86OutputDestroy(xf86OutputPtr output);

// void  xf86ProbeOutputModes(ScrnInfoPtr pScrn, int maxX, int maxY);

// void  xf86SetScrnInfoModes(ScrnInfoPtr pScrn);

static if (RANDR_13_INTERFACE) {
alias ScreenInitRetType =	int;
} else {
alias ScreenInitRetType =	Bool;
}

// void  xf86CrtcScreenInit(ScreenPtr pScreen);

void  xf86AssignNoOutputInitialSize(ScrnInfoPtr scrn, const(OptionInfoRec)* options, int* no_output_width, int* no_output_height);

// void  xf86InitialConfiguration(ScrnInfoPtr pScrn, Bool canGrow);

// void  xf86DPMSSet(ScrnInfoPtr pScrn, int PowerManagementMode, int flags);

// void  xf86SaveScreen(ScreenPtr pScreen, int mode);

// void  xf86DisableUnusedFunctions(ScrnInfoPtr pScrn);

// void  xf86OutputFindClosestMode(xf86OutputPtr output, DisplayModePtr desired);

// void  xf86SetSingleMode(ScrnInfoPtr pScrn, DisplayModePtr desired, Rotation rotation);

/**
 * Set the EDID information for the specified output
 */
// void  xf86OutputSetEDID(xf86OutputPtr output, xf86MonPtr edid_mon);

/**
 * Set the TILE information for the specified output
 */
// void  xf86OutputSetTile(xf86OutputPtr output, xf86CrtcTileInfo* tile_info);

// void  xf86OutputParseKMSTile(const(char)* tile_data, int tile_length, xf86CrtcTileInfo* tile_info);

/**
 * Return the list of modes supported by the EDID information
 * stored in 'output'
 */
void  xf86OutputGetEDIDModes(xf86OutputPtr output);

void  xf86OutputGetEDID(xf86OutputPtr output, I2CBusPtr pDDCBus);

/**
 * Initialize dga for this screen
 */

static if(XFreeXDGA){
void  xf86DiDGAInit(ScreenPtr pScreen, c_ulong dga_address);

/* this is the real function, used only internally */
Bool _xf86_di_dga_init_internal(ScreenPtr pScreen);

/**
 * Re-initialize dga for this screen (as when the set of modes changes)
 */

void  xf86DiDGAReInit(ScreenPtr pScreen);
}

/* This is the real function, used only internally */
Bool _xf86_di_dga_reinit_internal(ScreenPtr pScreen);

/*
 * Set the subpixel order reported for the screen using
 * the information from the outputs
 */

// void  xf86CrtcSetScreenSubpixelOrder(ScreenPtr pScreen);

/*
 * Get a standard string name for a connector type
 */
const(void )* xf86ConnectorGetName(xf86ConnectorType connector);

/*
 * Using the desired mode information in each crtc, set
 * modes (used in EnterVT functions, or at server startup)
 */

void  xf86SetDesiredModes(ScrnInfoPtr pScrn);

/**
 * Initialize the CRTC-based cursor code. CRTC function vectors must
 * contain relevant cursor setting functions.
 *
 * Driver should call this from ScreenInit function
 */
void  xf86_cursors_init(ScreenPtr screen, int max_width, int max_height, int flags);

/**
 * Superseded by xf86CursorResetCursor, which is getting called
 * automatically when necessary.
 */
private void xf86_reload_cursors(ScreenPtr screen) {}

/**
 * Called from EnterVT to turn the cursors back on
 */
void  xf86_show_cursors(ScrnInfoPtr scrn);

/**
 * Called by the driver to turn a single crtc's cursor off
 */
void  xf86_crtc_hide_cursor(xf86CrtcPtr crtc);

/**
 * Called by the driver to turn a single crtc's cursor on
 */
void  xf86_crtc_show_cursor(xf86CrtcPtr crtc);

/**
 * Called by the driver to turn cursors off
 */
void  xf86_hide_cursors(ScrnInfoPtr scrn);

/**
 * Clean up CRTC-based cursor code. Driver must call this at CloseScreen time.
 */
void  xf86_cursors_fini(ScreenPtr screen);

version (XV) {
/*
 * For overlay video, compute the relevant CRTC and
 * clip video to that.
 * wraps xf86XVClipVideoHelper()
 */

void  xf86_crtc_clip_video_helper(ScrnInfoPtr pScrn, xf86CrtcPtr* crtc_ret, xf86CrtcPtr desired_crtc, BoxPtr dst, INT32* xa, INT32* xb, INT32* ya, INT32* yb, RegionPtr reg, INT32 width, INT32 height);
}

// void  xf86_wrap_crtc_notify(ScreenPtr pScreen, xf86_crtc_notify_proc_ptr new_);

// void  xf86_unwrap_crtc_notify(ScreenPtr pScreen, xf86_crtc_notify_proc_ptr old);

// void  xf86_crtc_notify(ScreenPtr pScreen);

/**
 * Gamma
 */

// void  xf86_crtc_supports_gamma(ScrnInfoPtr pScrn);

// void  xf86ProviderSetup(ScrnInfoPtr scrn, const(xf86ProviderFuncsRec)* funcs, const(char)* name);

void  xf86DetachAllCrtc(ScrnInfoPtr scrn);

// Bool xf86OutputForceEnabled(xf86OutputPtr output);
                          /* _XF86CRTC_H_ */
