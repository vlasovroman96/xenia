module xf86Configure;
@nogc nothrow:
extern(C): __gshared:

// template HasVersion(string versionId) {
// 	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
// }
/*
 * Copyright 2000-2002 by Alan Hourihane, Flint Mountain, North Wales.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Alan Hourihane not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Alan Hourihane makes no representations
 * about the suitability of this software for any purpose.  It is provided
 * "as is" without express or implied warranty.
 *
 * ALAN HOURIHANE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL ALAN HOURIHANE BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 * Author:  Alan Hourihane, alanh@fairlite.demon.co.uk
 *
 */
import build.xorg_config;
import xf86pciBus;
import build.xlibre_server;;
import core.stdc.errno;

import os.ddx_priv;
import os.osdep;
import os.serverlock;

import xf86_priv;
import xf86Bus;
import xf86Config;
import hw.xfree86.os_support.xf86_OSlib;
import include.xf86Priv;
version = IN_XSERVER;
import Configint;
import xf86DDC_priv;
static if ((HasVersion!"__sparc__" || HasVersion!"__sparc") && !HasVersion!"__OpenBSD__") {
import xf86Bus;
import hw.xfree86.os_support.bus.xf86Sbus_priv;
}
import common.misc;
import hw.xfree86.loader.loaderProcs;
import xf86Parser_priv;
import externs.pciaccess;
import xf86Globals;
import externs.attrs;
import core.sys.posix.fcntl;
import read;
import externs.gnu;
import core.sys.posix.unistd ;
import hw.xfree86.parser.Flags;
import os.log;
import xf86Globals;
import hw.xfree86.common.edid;
import interpret_edid;
import Monitor;
import Screen;
import hw.xfree86.modes.displaymode;



struct _DevToConfig {
    GDevRec GDev;
    pci_device* pVideo;
static if ((HasVersion!"__sparc__" || HasVersion!"__sparc") && !HasVersion!"__OpenBSD__") {
    sbusDevicePtr sVideo;
}
    int iDriver;
}alias DevToConfigRec = _DevToConfig;
alias DevToConfigPtr = _DevToConfig*;

DevToConfigPtr DevToConfig = null;
int nDevToConfig = 0, CurrentDriver;

xf86MonPtr ConfiguredMonitor;
Bool xf86DoConfigurePass1 = TRUE;
Bool foundMouse = FALSE;

static if   (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__" || HasVersion!"__DragonFly__") {
const(char)* DFLT_MOUSE_DEV = "/dev/sysmouse";
const(char)* DFLT_MOUSE_PROTO = "auto";
} else version (linux) {
const(char)* DFLT_MOUSE_DEV = "/dev/input/mice";
const(char)* DFLT_MOUSE_PROTO = "auto";
} else version (WSCONS_SUPPORT) {
const(char)* DFLT_MOUSE_DEV = "/dev/wsmouse";
const(char)* DFLT_MOUSE_PROTO = "wsmouse";
} else {
const(char)* DFLT_MOUSE_DEV = "/dev/mouse";
const(char)* DFLT_MOUSE_PROTO = "auto";
}

/*
 * This is called by the driver, either through xf86Match???Instances() or
 * directly.  We allocate a GDevRec and fill it in as much as we can, letting
 * the caller fill in the rest and/or change it as it sees fit.
 */
GDevPtr xf86AddBusDeviceToConfigure(const(char)* driver, BusType bus, void* busData, int chipset)
{
    int ret = void, i = void, j = void;
    char* lower_driver = void;

    if (!xf86DoConfigure || !xf86DoConfigurePass1)
        return null;

    /* Check for duplicates */
    for (i = 0; i < nDevToConfig; i++) {
        switch (bus) {
static if(XSERVER_LIBPCIACCESS){
        case BUS_PCI:
            ret = xf86PciConfigure(busData, DevToConfig[i].pVideo);
            break;
}
static if ((HasVersion!"__sparc__" || HasVersion!"__sparc") && !HasVersion!"__OpenBSD__") {
        case BUS_SBUS:
            ret = xf86SbusConfigure(busData, DevToConfig[i].sVideo);
            break;
}
        default:
            return null;
        }
        if (ret == 0)
            goto out_;
    }

    /* Allocate new structure occurrence */
    i = nDevToConfig++;
    DevToConfig =
        cast(DevToConfigRec*) XNFreallocarray(DevToConfig, nDevToConfig, DevToConfigRec.sizeof);
    memset(DevToConfig + i, 0, DevToConfigRec.sizeof);

    DevToConfig[i].GDev.chipID =
        DevToConfig[i].GDev.chipRev = DevToConfig[i].GDev.irq = -1;

    DevToConfig[i].iDriver = CurrentDriver;

    /* Fill in what we know, converting the driver name to lower case */
    lower_driver = cast(char*)XNFalloc(strlen(driver) + 1);
    for (j = 0; ((lower_driver[j] = cast(char)tolower(cast(ubyte)driver[j])) != 0); j++){}
    DevToConfig[i].GDev.driver = lower_driver;

    switch (bus) {
static if(XSERVER_LIBPCIACCESS){
    case BUS_PCI:
	DevToConfig[i].pVideo = cast(pci_device*)busData;
        xf86PciConfigureNewDev(busData, DevToConfig[i].pVideo,
                               &DevToConfig[i].GDev, &chipset);
        break;
}
static if ((HasVersion!"__sparc__" || HasVersion!"__sparc") && !HasVersion!"__OpenBSD__") {
    case BUS_SBUS:
	DevToConfig[i].sVideo = busData;
        xf86SbusConfigureNewDev(busData, DevToConfig[i].sVideo,
                                &DevToConfig[i].GDev);
        break;
}
    default:
        break;
    }

    /* Get driver's available options */
    if (xf86DriverList[CurrentDriver].AvailableOptions)
        DevToConfig[i].GDev.options = cast(OptionInfoPtr)
            assumeNoGC(xf86DriverList[CurrentDriver].AvailableOptions) (chipset, bus);

    return &DevToConfig[i].GDev;

 out_:
    return null;
}

XF86ConfInputPtr configureInputSection()
{
    XF86ConfInputPtr mouse = null;

    mixin(parsePrologue!("XF86ConfInputPtr", "XF86ConfInputRec"));

    ptr.inp_identifier = cast(char*)XNFstrdup("Keyboard0");
    ptr.inp_driver = cast(char*)XNFstrdup("kbd");
    ptr.list.next = null;

    /* Crude mechanism to auto-detect mouse (os dependent) */
    {
        int fd = void;

        fd = open(DFLT_MOUSE_DEV, 0);
        if (fd != -1) {
            foundMouse = TRUE;
            close(fd);
        }
    }

    if (((mouse = cast(XF86ConfInputRec*) calloc(1, XF86ConfInputRec.sizeof)) is null))
        return null;

    mouse.inp_identifier = cast(char*)XNFstrdup("Mouse0");
    mouse.inp_driver = cast(char*)XNFstrdup("mouse");
    mouse.inp_option_lst =
        xf86addNewOption(mouse.inp_option_lst, cast(char*)XNFstrdup("Protocol"),
                         cast(char*)XNFstrdup(DFLT_MOUSE_PROTO));
    mouse.inp_option_lst =
        xf86addNewOption(mouse.inp_option_lst, cast(char*)XNFstrdup("Device"),
                         cast(char*)XNFstrdup(DFLT_MOUSE_DEV));
    mouse.inp_option_lst =
        xf86addNewOption(mouse.inp_option_lst, cast(char*)XNFstrdup("ZAxisMapping"),
                         cast(char*)XNFstrdup("4 5 6 7"));
    ptr = cast(XF86ConfInputPtr) xf86addListItem(cast(glp) ptr, cast(glp) mouse);
    return ptr;
}

XF86ConfScreenPtr configureScreenSection(int screennum)
{
    int i = void;
    int[6] depths = [ 1, 4, 8, 15, 16, 24 /*, 32 */  ];
    char* tmp = void;
    mixin(parsePrologue!("XF86ConfScreenPtr", "XF86ConfScreenRec"));

    XNFasprintf(&tmp, "Screen%d", screennum);
    ptr.scrn_identifier = tmp;
    XNFasprintf(&tmp, "Monitor%d", screennum);
    ptr.scrn_monitor_str = tmp;
    XNFasprintf(&tmp, "Card%d", screennum);
    ptr.scrn_device_str = tmp;

    for (i = 0; i < depths.length; i++) {
        XF86ConfDisplayPtr conf_display = cast(XF86ConfDisplayRec*) calloc(1, XF86ConfDisplayRec.sizeof);
        if (!conf_display)
            continue;
        conf_display.disp_depth = depths[i];
        conf_display.disp_black.red = conf_display.disp_white.red = -1;
        conf_display.disp_black.green = conf_display.disp_white.green = -1;
        conf_display.disp_black.blue = conf_display.disp_white.blue = -1;
        ptr.scrn_display_lst = cast(XF86ConfDisplayPtr) xf86addListItem(cast(glp) ptr.
                                                                     scrn_display_lst,
                                                                     cast(glp)
                                                                     conf_display);
    }

    return ptr;
}

const(char)* optionTypeToString(OptionValueType type)
{
    switch (type) {
    case OPTV_NONE:
        return "";
    case OPTV_INTEGER:
        return "<i>";
    case OPTV_STRING:
        return "<str>";
    case OPTV_ANYSTR:
        return "[<str>]";
    case OPTV_REAL:
        return "<f>";
    case OPTV_BOOLEAN:
        return "[<bool>]";
    case OPTV_FREQ:
        return "<freq>";
    case OPTV_PERCENT:
        return "<percent>";
    default:
        return "";
    }
}

XF86ConfDevicePtr configureDeviceSection(int screennum)
{
    OptionInfoPtr p = void;
    int i = 0;
    char* identifier = void;

    mixin(parsePrologue!("XF86ConfDevicePtr", "XF86ConfDeviceRec"));

    /* Move device info to parser structure */
   if (asprintf(&identifier, "Card%d", screennum) == -1)
        identifier = null;
    ptr.dev_identifier = identifier;
    ptr.dev_chipset = DevToConfig[screennum].GDev.chipset;
    ptr.dev_busid = DevToConfig[screennum].GDev.busID;
    ptr.dev_driver = DevToConfig[screennum].GDev.driver;
    ptr.dev_ramdac = DevToConfig[screennum].GDev.ramdac;
    for (i = 0; i < MAXDACSPEEDS; i++)
        ptr.dev_dacSpeeds[i] = DevToConfig[screennum].GDev.dacSpeeds[i];
    ptr.dev_videoram = DevToConfig[screennum].GDev.videoRam;
    ptr.dev_mem_base = DevToConfig[screennum].GDev.MemBase;
    ptr.dev_io_base = DevToConfig[screennum].GDev.IOBase;
    ptr.dev_clockchip = DevToConfig[screennum].GDev.clockchip;
    for (i = 0; (i < MAXCLOCKS) && (i < DevToConfig[screennum].GDev.numclocks);
         i++)
        ptr.dev_clock[i] = DevToConfig[screennum].GDev.clock[i];
    ptr.dev_clocks = i;
    ptr.dev_chipid = DevToConfig[screennum].GDev.chipID;
    ptr.dev_chiprev = DevToConfig[screennum].GDev.chipRev;
    ptr.dev_irq = DevToConfig[screennum].GDev.irq;

    /* Make sure older drivers don't segv */
    if (DevToConfig[screennum].GDev.options) {
        /* Fill in the available driver options for people to use */
        const(char)* descrip = "        ### Available Driver options are:-\n"
            ~ "        ### Values: <i>: integer, <f>: float, "
            ~ "<bool>: \"True\"/\"False\",\n"
            ~ "        ### <string>: \"String\", <freq>: \"<f> Hz/kHz/MHz\",\n"
            ~ "        ### <percent>: \"<f>%\"\n"
            ~ "        ### [arg]: arg optional\n";
        ptr.dev_comment = cast(char*)XNFstrdup(descrip);
        if (ptr.dev_comment) {
            for (p = cast(_OptionInfoRec*)DevToConfig[screennum].GDev.options; p.name !is null; p++) {
                char* p_e = void;
                const(char)* prefix = "        #Option     ";
                const(char)* middle = " \t# ";
                const(char)* suffix = "\n";
                const(char)* opttype = optionTypeToString(p.type);
                char* optname = void;
                int len = cast(int)(strlen(ptr.dev_comment) + strlen(prefix) +
                    strlen(middle) + strlen(suffix) + 1);

                if (asprintf(&optname, "\"%s\"", p.name) == -1)
                    break;

                len += max(20, strlen(optname));
                len += strlen(opttype);

                ptr.dev_comment = cast(char*)realloc(ptr.dev_comment, len);
                if (!ptr.dev_comment) {
                    free(optname);
                    break;
                }
                p_e = ptr.dev_comment + strlen(ptr.dev_comment);
                sprintf(p_e, "%s%-20s%s%s%s", prefix, optname, middle,
                        opttype, suffix);
                free(optname);
            }
        }
    }

    return ptr;
}

XF86ConfLayoutPtr configureLayoutSection()
{
    int scrnum = 0;

    mixin(parsePrologue!("XF86ConfLayoutPtr", "XF86ConfLayoutRec"));

    ptr.lay_identifier = "X.org Configured";

    {
        XF86ConfInputrefPtr iptr = cast(XF86ConfInputrefRec*) calloc(1, XF86ConfInputrefRec.sizeof);
        assert(iptr);
        iptr.list.next = null;
        iptr.iref_option_lst = null;
        iptr.iref_inputdev_str = cast(char*)XNFstrdup("Mouse0");
        iptr.iref_option_lst =
            xf86addNewOption(iptr.iref_option_lst, cast(char*)XNFstrdup("CorePointer"),
                             null);
        ptr.lay_input_lst = cast(XF86ConfInputrefPtr)
            xf86addListItem(cast(glp) ptr.lay_input_lst, cast(glp) iptr);
    }

    {
        XF86ConfInputrefPtr iptr = cast(XF86ConfInputrefRec*) calloc(1, XF86ConfInputrefRec.sizeof);
        assert(iptr);
        iptr.list.next = null;
        iptr.iref_option_lst = null;
        iptr.iref_inputdev_str = cast(char*)XNFstrdup("Keyboard0");
        iptr.iref_option_lst =
            xf86addNewOption(iptr.iref_option_lst, cast(char*)XNFstrdup("CoreKeyboard"),
                             null);
        ptr.lay_input_lst = cast(XF86ConfInputrefPtr)
            xf86addListItem(cast(glp) ptr.lay_input_lst, cast(glp) iptr);
    }

    for (scrnum = 0; scrnum < nDevToConfig; scrnum++) {
        char* tmp = void;

        XF86ConfAdjacencyPtr aptr = cast(XF86ConfAdjacencyRec*) calloc(1, XF86ConfAdjacencyRec.sizeof);
        assert(aptr);
        aptr.list.next = null;
        aptr.adj_x = 0;
        aptr.adj_y = 0;
        aptr.adj_scrnum = scrnum;
        XNFasprintf(&tmp, "Screen%d", scrnum);
        aptr.adj_screen_str = tmp;
        if (scrnum == 0) {
            aptr.adj_where = CONF_ADJ_ABSOLUTE;
            aptr.adj_refscreen = null;
        }
        else {
            aptr.adj_where = CONF_ADJ_RIGHTOF;
            XNFasprintf(&tmp, "Screen%d", scrnum - 1);
            aptr.adj_refscreen = tmp;
        }
        ptr.lay_adjacency_lst =
            cast(XF86ConfAdjacencyPtr) xf86addListItem(cast(glp) ptr.lay_adjacency_lst,
                                                   cast(glp) aptr);
    }

    return ptr;
}

XF86ConfFlagsPtr configureFlagsSection()
{
    mixin(parsePrologue!("XF86ConfFlagsPtr", "XF86ConfFlagsRec"));

    return ptr;
}

XF86ConfModulePtr configureModuleSection()
{
    const(char)** elist = void, el = void;

    mixin(parsePrologue!("XF86ConfModulePtr", "XF86ConfModuleRec"));

    elist = LoaderListDir("extensions", null);
    if (elist) {
        for (el = elist; *el; el++) {
            XF86LoadPtr module_ = cast(XF86LoadRec*) calloc(1, XF86LoadRec.sizeof);
            if (!module_)
                return ptr;
            module_.load_name = *el;
            ptr.mod_load_lst = cast(XF86LoadPtr) xf86addListItem(cast(glp) ptr.
                                                              mod_load_lst,
                                                              cast(glp) module_);
        }
        free(elist);
    }

    return ptr;
}

XF86ConfFilesPtr configureFilesSection()
{
    mixin(parsePrologue!("XF86ConfFilesPtr", "XF86ConfFilesRec"));

    if (xf86ModulePath)
        ptr.file_modulepath = cast(char*)XNFstrdup(xf86ModulePath);
    if (defaultFontPath)
        ptr.file_fontpath = cast(char*)XNFstrdup(defaultFontPath);

    return ptr;
}

XF86ConfMonitorPtr configureMonitorSection(int screennum)
{
    char* tmp = void;
    mixin(parsePrologue!("XF86ConfMonitorPtr", "XF86ConfMonitorRec"));

    XNFasprintf(&tmp, "Monitor%d", screennum);
    ptr.mon_identifier = tmp;
    ptr.mon_vendor = cast(char*)XNFstrdup("Monitor Vendor");
    ptr.mon_modelname = cast(char*)XNFstrdup("Monitor Model");

    return ptr;
}

/* Initialize Configure Monitor from Detailed Timing Block */
void handle_detailed_input(detailed_monitor_section* det_mon, void* data)
{
    XF86ConfMonitorPtr ptr = cast(XF86ConfMonitorPtr) data;

    switch (det_mon.type) {
    case DS_NAME:
        ptr.mon_modelname = cast(char*)realloc(ptr.mon_modelname,
                                     strlen(cast(char*) (det_mon.section.name)) +
                                     1);
        assert(ptr.mon_modelname);
        strcpy(ptr.mon_modelname, cast(char*) (det_mon.section.name));
        break;
    case DS_RANGES:
        ptr.mon_hsync[ptr.mon_n_hsync].lo = det_mon.section.ranges.min_h;
        ptr.mon_hsync[ptr.mon_n_hsync].hi = det_mon.section.ranges.max_h;
        ptr.mon_n_vrefresh = 1;
        ptr.mon_vrefresh[ptr.mon_n_hsync].lo = det_mon.section.ranges.min_v;
        ptr.mon_vrefresh[ptr.mon_n_hsync].hi = det_mon.section.ranges.max_v;
        ptr.mon_n_hsync++;
        goto default;
    default:
        break;
    }
}

XF86ConfMonitorPtr configureDDCMonitorSection(int screennum)
{
    int len = void, mon_width = void, mon_height = void;

enum displaySizeMaxLen = 80;
    char[displaySizeMaxLen] displaySize_string = void;
    int displaySizeLen = void;
    char* tmp = void;

    mixin(parsePrologue!("XF86ConfMonitorPtr", "XF86ConfMonitorRec"));

    XNFasprintf(&tmp, "Monitor%d", screennum);
    ptr.mon_identifier = tmp;
    ptr.mon_vendor = cast(char*)XNFstrdup(ConfiguredMonitor.vendor_.name.ptr);
    XNFasprintf(&ptr.mon_modelname, "%x", ConfiguredMonitor.vendor_.prod_id);

    /* features in centimetres, we want millimetres */
    mon_width = 10 * ConfiguredMonitor.features.hsize;
    mon_height = 10 * ConfiguredMonitor.features.vsize;

version (CONFIGURE_DISPLAYSIZE) {
    ptr.mon_width = mon_width;
    ptr.mon_height = mon_height;
} else {
    if (mon_width && mon_height) {
        /* when values available add DisplaySize option AS A COMMENT */

        displaySizeLen = snprintf(displaySize_string.ptr, displaySizeMaxLen,
                                  "\t#DisplaySize\t%5d %5d\t# mm\n",
                                  mon_width, mon_height);

        if (displaySizeLen > 0 && displaySizeLen < displaySizeMaxLen) {
            if (ptr.mon_comment) {
                len = cast(int)strlen(ptr.mon_comment);
            }
            else {
                len = 0;
            }
            if ((ptr.mon_comment =
                 cast(char*)realloc(ptr.mon_comment,
                         len + strlen(displaySize_string.ptr) + 1)) !is null) {
                strcpy(ptr.mon_comment + len, displaySize_string.ptr);
            }
        }
    }
}                          /* def CONFIGURE_DISPLAYSIZE */

    xf86ForEachDetailedBlock(ConfiguredMonitor, &handle_detailed_input, ptr);

    if (ConfiguredMonitor.features.dpms) {
        ptr.mon_option_lst =
            xf86addNewOption(ptr.mon_option_lst, cast(char*)XNFstrdup("DPMS"), null);
    }

    return ptr;
}

int is_fallback(const(char)* s)
{
    /* later entries are less preferred */
    const(char)*[5] fallback = [ "modesetting".ptr, "fbdev".ptr, "vesa".ptr,  "wsfb".ptr, null ];
    int i = void;

    for (i = 0; fallback[i]; i++)
	if (strstr(s, fallback[i]))
	    return i;

    return -1;
}

int driver_sort(const(void)* _l, const(void)* _r)
{
    const(char)* l = *cast(const(char)**)_l;
    const(char)* r = *cast(const(char)**)_r;
    int left = is_fallback(l);
    int right = is_fallback(r);

    /* neither is a fallback, asciibetize */
    if (left == -1 && right == -1)
	return strcmp(l, r);

    /* left is a fallback, right is not */
    if (left >= 0 && right == -1)
	return 1;

    /* right is a fallback, left is not */
    if (right >= 0 && left == -1)
	return -1;

    /* both are fallbacks, decide which is worse */
    return left - right;
}

void fixup_video_driver_list(const(char)** drivers)
{
    const(char)** end = void;

    /* walk to the end of the list */
    for (end = drivers; *end && **end; end++){}

    qsort(drivers, end - drivers, (const(char)*).sizeof, &driver_sort);
}

const(char)** GenerateDriverList()
{
    const(char)** ret = void;
    static const(char)*[2] patlist = [ "(.*)_drv\\.so", null ];
    ret = LoaderListDir("drivers", patlist.ptr);

    /* fix up the probe order for video drivers */
    if (ret !is null)
        fixup_video_driver_list(ret);

    return ret;
}

void DoConfigure()
{
    int i = void, j = void, screennum = -1;
    const(char)* home = null;
    char[PATH_MAX] filename = void;
    const(char)* addslash = "";
    XF86ConfigPtr xf86config = null;
    const(char)** vlist = void, vl = void;
    int* dev2screen = void;

    vlist = GenerateDriverList();

    if (!vlist) {
        ErrorF("Missing output drivers.  Configuration failed.\n");
        goto bail;
    }

    ErrorF("List of video drivers:\n");
    for (vl = vlist; *vl; vl++)
        ErrorF("\t%s\n", *vl);

    /* Load all the drivers that were found. */
    xf86LoadModules(vlist, null);

    free(vlist);

    xorgHWAccess = cast(bool)xf86EnableIO();

    /* Create XF86Config file structure */
    xf86config = cast(XF86ConfigRec*) calloc(1, XF86ConfigRec.sizeof);

    /* Call all of the probe functions, reporting the results. */
    for (CurrentDriver = 0; CurrentDriver < xf86NumDrivers; CurrentDriver++) {
        Bool found_screen = void;
        DriverRec* drv = xf86DriverList[CurrentDriver];

        fprintf(stderr, "LOL");
        found_screen = xf86CallDriverProbe(drv, TRUE);
        if (found_screen && drv.Identify) {
            assumeNoGC(drv.Identify) (0);
        }
    }

    if (nDevToConfig <= 0) {
        ErrorF("No devices to configure.  Configuration failed.\n");
        goto bail;
    }

    /* Add device, monitor and screen sections for detected devices */
    for (screennum = 0; screennum < nDevToConfig; screennum++) {
        XF86ConfDevicePtr device_ptr = void;
        XF86ConfMonitorPtr monitor_ptr = void;
        XF86ConfScreenPtr screen_ptr = void;

        assert(xf86config);
        device_ptr = configureDeviceSection(screennum);
        xf86config.conf_device_lst = cast(XF86ConfDevicePtr) xf86addListItem(cast(glp)
                                                                          xf86config.
                                                                          conf_device_lst,
                                                                          cast(glp)
                                                                          device_ptr);
        monitor_ptr = configureMonitorSection(screennum);
        xf86config.conf_monitor_lst = cast(XF86ConfMonitorPtr) xf86addListItem(cast(glp) xf86config.conf_monitor_lst, cast(glp) monitor_ptr);
        screen_ptr = configureScreenSection(screennum);
        xf86config.conf_screen_lst = cast(XF86ConfScreenPtr) xf86addListItem(cast(glp)
                                                                          xf86config.
                                                                          conf_screen_lst,
                                                                          cast(glp)
                                                                          screen_ptr);
    }

    xf86config.conf_files = configureFilesSection();
    xf86config.conf_modules = configureModuleSection();
    xf86config.conf_flags = configureFlagsSection();
    xf86config.conf_videoadaptor_lst = null;
    xf86config.conf_modes_lst = null;
    xf86config.conf_vendor_lst = null;
    xf86config.conf_dri = null;
    xf86config.conf_input_lst = configureInputSection();
    xf86config.conf_layout_lst = configureLayoutSection();

    home = getenv("HOME");
    if ((home is null) || (home[0] == '\0')) {
        home = "/";
    }
    else {
        /* Determine if trailing slash is present or needed */
        int l = cast(int)strlen(home);

        if (home[l - 1] != '/') {
            addslash = "/";
        }
    }

    snprintf(filename.ptr, filename.sizeof, "%s%s" ~XF86CONFIGFILE ~ ".new",
             home, addslash);

    if (xf86writeConfigFile(filename.ptr, xf86config) == 0) {
        LogMessageVerb(X_ERROR, 1, "Unable to write config file: \"%s\": %s\n",
                       filename.ptr, strerror(errno));
        goto bail;
    }

    xf86DoConfigurePass1 = FALSE;
    /* Try to get DDC information filled in */
    xf86ConfigFile = filename.ptr;
    if (xf86HandleConfigFile(FALSE) != _ConfigStatus.CONFIG_OK) {
        goto bail;
    }

    xf86DoConfigurePass1 = FALSE;

    dev2screen = cast(int*)XNFcallocarray(nDevToConfig, int.sizeof);

    {
        Bool* driverProbed = cast(Bool*)XNFcallocarray(xf86NumDrivers, Bool.sizeof);

        for (screennum = 0; screennum < nDevToConfig; screennum++) {
            int k = void, l = void, n = void, oldNumScreens = void;

            i = DevToConfig[screennum].iDriver;

            if (driverProbed[i])
                continue;
            driverProbed[i] = TRUE;

            oldNumScreens = xf86NumScreens;

            xf86CallDriverProbe(xf86DriverList[i], FALSE);

            /* reorder */
            k = screennum > 0 ? screennum : 1;
            for (l = oldNumScreens; l < xf86NumScreens; l++) {
                /* is screen primary? */
                Bool primary = FALSE;

                for (n = 0; n < xf86Screens[l].numEntities; n++) {
                    if (xf86IsEntityPrimary(xf86Screens[l].entityList[n])) {
                        dev2screen[0] = l;
                        primary = TRUE;
                        break;
                    }
                }
                if (primary)
                    continue;
                /* not primary: assign it to next device of same driver */
                /*
                 * NOTE: we assume that devices in DevToConfig
                 * and xf86Screens[] have the same order except
                 * for the primary device which always comes first.
                 */
                for (; k < nDevToConfig; k++) {
                    if (DevToConfig[k].iDriver == i) {
                        dev2screen[k++] = l;
                        break;
                    }
                }
            }
        }
        free(driverProbed);
    }

    if (nDevToConfig != xf86NumScreens) {
        ErrorF("Number of created screens does not match number of detected"
               ~ " devices.\n  Configuration failed.\n");
        goto bail;
    }

    for (j = 0; j < xf86NumScreens; j++) {
        xf86Screens[j].scrnIndex = j;
    }

    xf86freeMonitorList(xf86config.conf_monitor_lst);
    xf86config.conf_monitor_lst = null;
    xf86freeScreenList(xf86config.conf_screen_lst);
    xf86config.conf_screen_lst = null;
    for (j = 0; j < xf86NumScreens; j++) {
        XF86ConfMonitorPtr monitor_ptr = void;
        XF86ConfScreenPtr screen_ptr = void;

        ConfiguredMonitor = null;

        if ((xf86Screens[dev2screen[j]].PreInit) !is null &&
            (xf86Screens[dev2screen[j]].PreInit) (xf86Screens[dev2screen[j]],
                                                    PROBE_DETECT) &&
            ConfiguredMonitor) {
            monitor_ptr = configureDDCMonitorSection(j);
        }
        else {
            monitor_ptr = configureMonitorSection(j);
        }
        screen_ptr = configureScreenSection(j);

        xf86config.conf_monitor_lst = cast(XF86ConfMonitorPtr) xf86addListItem(cast(glp) xf86config.conf_monitor_lst, cast(glp) monitor_ptr);
        xf86config.conf_screen_lst = cast(XF86ConfScreenPtr) xf86addListItem(cast(glp)
                                                                          xf86config.
                                                                          conf_screen_lst,
                                                                          cast(glp)
                                                                          screen_ptr);
    }

    if (xf86writeConfigFile(filename.ptr, xf86config) == 0) {
        LogMessageVerb(X_ERROR, 1, "Unable to write config file: \"%s\": %s\n",
                       filename.ptr, strerror(errno));
        goto bail;
    }

    ErrorF("\n");

    if (!foundMouse) {
        ErrorF("\n" ~__XSERVERNAME__ ~ " is not able to detect your mouse.\n"
               ~ "Edit the file and correct the Device.\n");
    }
    else {
        ErrorF("\n" ~__XSERVERNAME__ ~ " detected your mouse at device %s.\n"
               ~ "Please check your config if the mouse is still not\n"
               ~ "operational, as by default "~ __XSERVERNAME__
               ~" tries to autodetect\n" ~ "the protocol.\n", DFLT_MOUSE_DEV);
    }

    if (xf86NumScreens > 1) {
        ErrorF("\n"~ __XSERVERNAME__
               ~ " has configured a multihead system, please check your config.\n");
    }

    ErrorF("\nYour %s file is %s\n\n", XF86CONFIGFILE.ptr, filename.ptr);
    ErrorF("To test the server, run 'X -config %s'\n\n", filename.ptr);

 bail:
    UnlockServer();
    ddxGiveUp(EXIT_ERR_CONFIGURE);
    fflush(stderr);
    exit(0);
}

/* Xorg -showopts:
 *   For each driver module installed, print out the list
 *   of options and their argument types, then exit
 *
 * Author:  Marcus Schaefer, ms@suse.de
 */

void DoShowOptions()
{
    int i = 0;
    const(char)** vlist = null;
    char* pSymbol = null;
    XF86ModuleData* initData = null;

    if (((vlist = GenerateDriverList()) is null)) {
        ErrorF("Missing output drivers\n");
        goto bail;
    }
    xf86LoadModules(vlist, null);
    free(vlist);
    for (i = 0; i < xf86NumDrivers; i++) {
        if (xf86DriverList[i].AvailableOptions) {
            const(OptionInfoRec)* pOption = assumeNoGC(xf86DriverList[i].AvailableOptions) (0, 0);
            if (!pOption) {
                ErrorF("(EE) Couldn't read option table for %s driver\n",
                       xf86DriverList[i].driverName);
                continue;
            }
            XNFasprintf(&pSymbol, "%sModuleData",
                        xf86DriverList[i].driverName);
            initData = cast(XF86ModuleData*)LoaderSymbol(pSymbol);
            if (initData) {
                XF86ModuleVersionInfo* vers = initData.vers;
                const(OptionInfoRec)* p = void;

                ErrorF("Driver[%d]:%s[%s] {\n",
                       i, xf86DriverList[i].driverName, vers.vendor);
                for (p = pOption; p.name !is null; p++) {
                    ErrorF("\t%s:%s\n", p.name, optionTypeToString(p.type));
                }
                ErrorF("}\n");
            }
        }
    }
 bail:
    UnlockServer();
    ddxGiveUp(EXIT_ERR_DRIVERS);
    fflush(stderr);
    exit(0);
}
