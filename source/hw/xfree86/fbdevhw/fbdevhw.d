module fbdevhw;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
import build.xorg_config;

import core.sys.posix.fcntl;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.unistd;
import externs.glob;

import core.sys.posix.sys.stat;
import core.sys.posix.sys.mman;
import core.sys.posix.sys.ioctl;

version (HAVE_SYS_SYSMACROS_H) {
import sys.sysmacros;
}
version (HAVE_SYS_MKDEV_H) {
import sys.mkdev;          /* for minor() on Solaris */
}

import include.xf86;
import xf86Modes;
import include.xf86_OSproc;;

/* pci stuff */
import include.xf86Pci;

import xf86cmap;
import build.xlibre_server;

import include.fbdevhw;
import hw.xfree86.fbdevhw.fbpriv;
import hw.xfree86.common.xf86Helper;
// //import externs.X11.extensions.dpmsconst;
import externs.sys.sysmacros;
import externs.attrs;
import externs.X11.extensions.dpmsproto;
import hw.xfree86.modes.displaymode;

int getpagesize() {
    return cast(int)sysconf(_SC_PAGESIZE);
} 
    

auto PAGE_MASK() =>               (~(getpagesize() - 1));

private XF86ModuleVersionInfo fbdevHWVersRec = {
    modname: "fbdevhw",
    vendor: MODULEVENDORSTRING,
    _modinfo1_: MODINFOSTRING1,
    _modinfo2_: MODINFOSTRING2,
    xf86version: XORG_VERSION_CURRENT,
    majorversion: 0,
    minorversion: 0,
    patchlevel: 2,
    abiclass: ABI_CLASS_VIDEODRV,
    abiversion: ABI_VIDEODRV_VERSION,
};

export XF86ModuleData fbdevhwModuleData = {
    vers: &fbdevHWVersRec
};

/* -------------------------------------------------------------------- */
/* our private data, and two functions to allocate/free this            */

enum string FBDEVHWPTRLVAL(string p) = `(` ~ p ~ `).privates[fbdevHWPrivateIndex].ptr`;
enum string FBDEVHWPTR(string p) = `(cast(fbdevHWPtr)(` ~ FBDEVHWPTRLVAL!(p) ~ `))`;

private int fbdevHWPrivateIndex = -1;

struct _FbdevHWRec {
    /* framebuffer device: filename (/dev/fb*), handle, more */
    char* device;
    int fd;
    void* fbmem;
    uint fbmem_len;
    uint fboff;
    char* mmio;
    uint mmio_len;

    /* current hardware state */
    fb_fix_screeninfo fix;
    fb_var_screeninfo var;

    /* saved video mode */
    fb_var_screeninfo saved_var;
    uint saved_accel;

    /* buildin video mode */
    DisplayModeRec buildin;

    /* disable non-fatal unsupported ioctls */
    CARD32 unsupported_ioctls;
}alias fbdevHWRec = _FbdevHWRec;
alias fbdevHWPtr = fbdevHWRec*;

enum {
    FBIOBLANK_UNSUPPORTED = 0,
}

private Bool fbdevHWGetRec(ScrnInfoPtr pScrn)
{
    if (fbdevHWPrivateIndex < 0)
        fbdevHWPrivateIndex = xf86AllocateScrnInfoPrivateIndex();

    if (mixin(FBDEVHWPTR!(`pScrn`)) !is null)
        return TRUE;

    mixin(FBDEVHWPTRLVAL!(`pScrn`)) = XNFcallocarray(1, fbdevHWRec.sizeof);
    return TRUE;
}

/* -------------------------------------------------------------------- */
/* some helpers for printing debug information                          */

version (DEBUG) {
private void print_fbdev_mode(const(char)* txt, fb_var_screeninfo* var)
{
    ErrorF("fbdev %s mode:\t%d   %d %d %d %d   %d %d %d %d   %d %d:%d:%d\n",
           txt, var.pixclock,
           var.xres, var.right_margin, var.hsync_len, var.left_margin,
           var.yres, var.lower_margin, var.vsync_len, var.upper_margin,
           var.bits_per_pixel,
           var.red.length, var.green.length, var.blue.length);
}

private void print_xfree_mode(const(char)* txt, DisplayModePtr mode)
{
    ErrorF("xfree %s mode:\t%d   %d %d %d %d   %d %d %d %d\n",
           txt, mode.Clock,
           mode.HDisplay, mode.HSyncStart, mode.HSyncEnd, mode.HTotal,
           mode.VDisplay, mode.VSyncStart, mode.VSyncEnd, mode.VTotal);
}
}

/* -------------------------------------------------------------------- */
/* Convert timings between the XFree and the Frame Buffer Device        */

private void xfree2fbdev_fblayout(ScrnInfoPtr pScrn, fb_var_screeninfo* var)
{
    var.xres_virtual = pScrn.displayWidth ? pScrn.displayWidth :
        pScrn.virtualX;
    var.yres_virtual = pScrn.virtualY;
    var.bits_per_pixel = pScrn.bitsPerPixel;
    if (pScrn.defaultVisual == TrueColor ||
        pScrn.defaultVisual == DirectColor) {
        var.red.length = cast(uint)pScrn.weight.red;
        var.green.length = cast(uint)pScrn.weight.green;
        var.blue.length = cast(uint)pScrn.weight.blue;
    }
    else {
        var.red.length = 8;
        var.green.length = 8;
        var.blue.length = 8;
    }
}

private void xfree2fbdev_timing(DisplayModePtr mode, fb_var_screeninfo* var)
{
    var.xres = mode.HDisplay;
    var.yres = mode.VDisplay;
    if (var.xres_virtual < var.xres)
        var.xres_virtual = var.xres;
    if (var.yres_virtual < var.yres)
        var.yres_virtual = var.yres;
    var.xoffset = var.yoffset = 0;
    var.pixclock = mode.Clock ? 1000000000 / mode.Clock : 0;
    var.right_margin = mode.HSyncStart - mode.HDisplay;
    var.hsync_len = mode.HSyncEnd - mode.HSyncStart;
    var.left_margin = mode.HTotal - mode.HSyncEnd;
    var.lower_margin = mode.VSyncStart - mode.VDisplay;
    var.vsync_len = mode.VSyncEnd - mode.VSyncStart;
    var.upper_margin = mode.VTotal - mode.VSyncEnd;
    var.sync = 0;
    if (mode.Flags & V_PHSYNC)
        var.sync |= FB_SYNC_HOR_HIGH_ACT;
    if (mode.Flags & V_PVSYNC)
        var.sync |= FB_SYNC_VERT_HIGH_ACT;
    if (mode.Flags & V_PCSYNC)
        var.sync |= FB_SYNC_COMP_HIGH_ACT;
    if (mode.Flags & V_BCAST)
        var.sync |= FB_SYNC_BROADCAST;
    if (mode.Flags & V_INTERLACE)
        var.vmode = FB_VMODE_INTERLACED;
    else if (mode.Flags & V_DBLSCAN)
        var.vmode = FB_VMODE_DOUBLE;
    else
        var.vmode = FB_VMODE_NONINTERLACED;
}

private Bool fbdev_modes_equal(fb_var_screeninfo* set, fb_var_screeninfo* req)
{
    return (set.xres_virtual >= req.xres_virtual &&
            set.yres_virtual >= req.yres_virtual &&
            set.bits_per_pixel == req.bits_per_pixel &&
            set.red.length == req.red.length &&
            set.green.length == req.green.length &&
            set.blue.length == req.blue.length &&
            set.xres == req.xres && set.yres == req.yres &&
            set.right_margin == req.right_margin &&
            set.hsync_len == req.hsync_len &&
            set.left_margin == req.left_margin &&
            set.lower_margin == req.lower_margin &&
            set.vsync_len == req.vsync_len &&
            set.upper_margin == req.upper_margin &&
            set.sync == req.sync && set.vmode == req.vmode);
}

private void fbdev2xfree_timing(fb_var_screeninfo* var, DisplayModePtr mode)
{
    mode.Clock = var.pixclock ? 1000000000 / var.pixclock : 0;
    mode.HDisplay = var.xres;
    mode.HSyncStart = mode.HDisplay + var.right_margin;
    mode.HSyncEnd = mode.HSyncStart + var.hsync_len;
    mode.HTotal = mode.HSyncEnd + var.left_margin;
    mode.VDisplay = var.yres;
    mode.VSyncStart = mode.VDisplay + var.lower_margin;
    mode.VSyncEnd = mode.VSyncStart + var.vsync_len;
    mode.VTotal = mode.VSyncEnd + var.upper_margin;
    mode.Flags = 0;
    mode.Flags |= var.sync & FB_SYNC_HOR_HIGH_ACT ? V_PHSYNC : V_NHSYNC;
    mode.Flags |= var.sync & FB_SYNC_VERT_HIGH_ACT ? V_PVSYNC : V_NVSYNC;
    mode.Flags |= var.sync & FB_SYNC_COMP_HIGH_ACT ? V_PCSYNC : V_NCSYNC;
    if (var.sync & FB_SYNC_BROADCAST)
        mode.Flags |= V_BCAST;
    if ((var.vmode & FB_VMODE_MASK) == FB_VMODE_INTERLACED)
        mode.Flags |= V_INTERLACE;
    else if ((var.vmode & FB_VMODE_MASK) == FB_VMODE_DOUBLE)
        mode.Flags |= V_DBLSCAN;
    mode.SynthClock = mode.Clock;
    mode.CrtcHDisplay = mode.HDisplay;
    mode.CrtcHSyncStart = mode.HSyncStart;
    mode.CrtcHSyncEnd = mode.HSyncEnd;
    mode.CrtcHTotal = mode.HTotal;
    mode.CrtcVDisplay = mode.VDisplay;
    mode.CrtcVSyncStart = mode.VSyncStart;
    mode.CrtcVSyncEnd = mode.VSyncEnd;
    mode.CrtcVTotal = mode.VTotal;
    mode.CrtcHAdjusted = FALSE;
    mode.CrtcVAdjusted = FALSE;
}

/* -------------------------------------------------------------------- */
/* open correct framebuffer device                                      */


/* Wrapper around open() that also get the framebuffer name */
private int fbdev_open_device(int scrnIndex, const(char)* dev, char** namep)
{
    fprintf(stderr, "LOL");
    int fd = dev ? open(dev, O_RDWR) : -1;
    

    if (!namep) {
        return fd;
    }

    fprintf(stderr,
    "fbdev_open_device(%s): open -> fd=%d errno=%d\n",
    dev ? dev : "(null)", fd, errno);

    if (fd == -1) {
        return -1;
    }

    fb_fix_screeninfo fix = void;

    fprintf(stderr,
    "FBIOGET_FSCREENINFO: fd=%d request=%#lx fix.sizeof=%zu\n",
    fd,
    cast(ulong) FBIOGET_FSCREENINFO,
    fb_fix_screeninfo.sizeof);

    if (ioctl(fd, FBIOGET_FSCREENINFO, cast(void*) (&fix)) == -1) {
        *namep = null;
        xf86DrvMsg(scrnIndex, X_ERROR,
                   "Not using framebuffer device %s: FBIOGET_FSCREENINFO: %s\n", dev, strerror(errno));
        close(fd);
        return -1;
    }
    *namep = cast(char*)malloc(16);
    if (*namep) {
        strncpy(*namep, fix.id.ptr, 16);
    }
    return fd;
}

private int fbdev_check_user_devices(int scrnIndex, const(char)* dev, char** namep)
{
    int fd = void;

    /* try argument (from XF86Config) first */
    if (dev) {
        fd = fbdev_open_device(scrnIndex, dev, namep);
    } else {
        /* second: environment variable */
        dev = getenv("FRAMEBUFFER");
        fd = fbdev_open_device(scrnIndex, dev, namep);
    }

    if (dev && fd == -1) {
        xf86DrvMsg(scrnIndex, X_ERROR,
                   "Could not use the explicitly provided framebuffer: %s\n", dev);
    }
    return fd;
}

/**
 * Try to find the framebuffer device for a given PCI device
 * This probe works in the following way:
 *
 * 1. If we have device passed by the user, we store it's minor number.
 * We then look through the framebuffers associated to the pPci pci device.
 * If we find one that has the same minor as the one passed by the user, we
 * open the filename passed by the user and return an fd to it.
 * Otherwise, we return -1;
 *
 * 2. If we don't have a device passed by the user,
 * we look through the framebuffers associated to the pPci pci device.
 * If we find one that is valid, we return an fd to it.
 * Otherwise, we return -1;
 */
private int fbdev_open_pci(int scrnIndex, pci_device* pPci, const(char)* device, char** namep)
{
    /*
     * We really don't care what pci slot we claim when using the fbdev driver
     * However, due to how the probe interface is designed,
     * we have to be careful to not claim the wrong pci slot.
     */
    char[PATH_MAX] pattern = void;
    int fd = void;
    int fbdev_minor = -1;

    fd = fbdev_check_user_devices(scrnIndex, device, namep);

    int tfd = void;
    snprintf(pattern.ptr, pattern.sizeof,
             "/sys/bus/pci/devices/%04x:%02x:%02x.%d",
             pPci.domain, pPci.bus, pPci.dev, pPci.func);
    tfd = open(pattern.ptr, O_RDONLY);
    if (tfd == -1) {
        xf86DrvMsg(scrnIndex, X_WARNING,
                   "Sysfs interface cannot be used."
                   ~ "Pci probe for framebuffer devices cannot function properly.\n");
        if (fd != -1) {
            xf86DrvMsg(scrnIndex, X_WARNING,
                       "Using device: %s without further checks\n", device);
            return fd;
        }
        xf86DrvMsg(scrnIndex, X_ERROR, "Unable to find a valid framebuffer device\n");
        return -1;
    }
    close(tfd);

    if (fd != -1) {
        stat_t res = void;
        if (fstat(fd, &res) == 0) {
            fbdev_minor = minor(res.st_rdev);
        }
        close(fd);
        fd = -1;
        if (namep) {
            free(*namep);
            *namep = null;
        }
    }

enum string FBDEV_CHECK_PCI_GLOB(string glob_pattern) = `
{ 
        glob_t res = void; 
        snprintf(pattern.ptr, pattern.sizeof, 
                 "/sys/bus/pci/devices/%04x:%02x:%02x.%d/`~glob_pattern~`/dev", 
                 pPci.domain, pPci.bus, pPci.dev, pPci.func); 
        if (!assumeNoGC(&glob)(pattern.ptr, GLOB_NOSORT | GLOB_NOESCAPE, null, &res)) { 
            char[PATH_MAX] filename = "/dev/"; 
            for (int i = 0; i < res.gl_pathc; i++) { 
                int maj = void, min = -1; 
                FILE* f = fopen(res.gl_pathv[i], "r"); 
                if (f) { 
                    cast(void)!fscanf(f, "%d:%d", &maj, &min); 
                    fclose(f); 
                } 
                if (fbdev_minor != -1) { 
                    if (fbdev_minor != min) { 
                        continue; 
                    } 
                    /* We have determined the the device the user gave us matches this pci device */ 
                    /* However, the name could be different than /dev/fb* */ 
                    /* Since we already have a filename from the user, use that instead of guessing */ 
                    return fbdev_check_user_devices(scrnIndex, device, namep); 
                } 
                char* src = strstr(res.gl_pathv[i], "graphics") + (("graphics/").sizeof - 1); /* Has to match */ 
                char* dst = filename.ptr + (("/dev/").sizeof - 1); 
                while (*src != '/') { 
                    *dst++ = *src++; 
                } 
                *dst = '\0'; 
                fd = fbdev_open_device(scrnIndex, filename.ptr, namep); 
                if (fd != -1) { 
                    return fd; 
                } 
            } 
        } 
        assumeNoGC(&globfree)(&res); 
    }`;

    mixin(FBDEV_CHECK_PCI_GLOB!(`graphics/fb*`));
    mixin(FBDEV_CHECK_PCI_GLOB!(`graphics:fb*`));
    mixin(FBDEV_CHECK_PCI_GLOB!(`*/graphics/fb*`));
    mixin(FBDEV_CHECK_PCI_GLOB!(`*/graphics:fb*`));

    xf86DrvMsg(scrnIndex, X_ERROR, "Unable to find a valid framebuffer device\n");
    return -1;
}

private int fbdev_open(int scrnIndex, const(char)* dev, char** namep)
{
    fprintf(stderr,
    "fbdev_open: dev=%s namep=%p\n",
    dev ? dev : "(null)", namep);
    int fd = void;

    fd = fbdev_check_user_devices(scrnIndex, dev, namep);

    if (fd != -1) {
        /* fbdev was provided by the user and not guessed, just return it */
        return fd;
    }

    /* try the default device symlink */
    dev = "/dev/fb";
    fd = fbdev_open_device(scrnIndex, dev, namep);

    /* last tries, framebuffers 0 through 31 */
    char[10] devbuf = "/dev/fbxx";
    for (int i = 0; i <= 31 && fd == -1; i++) {
        snprintf(devbuf.ptr, devbuf.sizeof,
                 "/dev/fb%d", i);
        fd = fbdev_open_device(scrnIndex, devbuf.ptr, namep);
    }

    if (fd == -1) {
        xf86DrvMsg(scrnIndex, X_ERROR, "Unable to find a valid framebuffer device\n");
    }

    return fd;
}

/* -------------------------------------------------------------------- */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
export Bool fbdevHWProbe(pci_device* pPci, const(char)* device, char** namep)
{
    fprintf(stderr,
    "fbdevHWProbe: pPci=%p device=%s namep=%p\n",
    pPci,
    device ? device : "(null)",
    namep);
    int fd = void;

    if (pPci)
        fd = fbdev_open_pci(-1, pPci, device, namep);
    else
        fd = fbdev_open(-1, device, namep);

    if (-1 == fd)
        return FALSE;
    close(fd);
    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWInit(ScrnInfoPtr pScrn, pci_device* pPci, const(char)* device)
{
    fbdevHWPtr fPtr = void;

    fbdevHWGetRec(pScrn);
    fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    /* open device */
    if (pPci)
        fPtr.fd = fbdev_open_pci(pScrn.scrnIndex, pPci, device, null);
    else
        fPtr.fd = fbdev_open(pScrn.scrnIndex, device, null);
    if (-1 == fPtr.fd) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "Failed to open framebuffer device, consult warnings"
                   ~ " and/or errors above for possible reasons\n"
                   ~ "\t(you may have to look at the server log to see"
                   ~ " warnings)\n");
        return FALSE;
    }

    /* get current fb device settings */
    if (-1 == ioctl(fPtr.fd, FBIOGET_FSCREENINFO, cast(void*) (&fPtr.fix))) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "ioctl FBIOGET_FSCREENINFO: %s\n", strerror(errno));
        return FALSE;
    }
    if (-1 == ioctl(fPtr.fd, FBIOGET_VSCREENINFO, cast(void*) (&fPtr.var))) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "ioctl FBIOGET_VSCREENINFO: %s\n", strerror(errno));
        return FALSE;
    }

    /* we can use the current settings as "buildin mode" */
    fbdev2xfree_timing(&fPtr.var, &fPtr.buildin);
    fPtr.buildin.name = "current";
    fPtr.buildin.next = &fPtr.buildin;
    fPtr.buildin.prev = &fPtr.buildin;
    fPtr.buildin.type |= M_T_BUILTIN;

    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
char* fbdevHWGetName(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    return fPtr.fix.id.ptr;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetDepth(ScrnInfoPtr pScrn, int* fbbpp)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (fbbpp)
        *fbbpp = fPtr.var.bits_per_pixel;

    if (fPtr.fix.visual == FB_VISUAL_TRUECOLOR ||
        fPtr.fix.visual == FB_VISUAL_DIRECTCOLOR)
        return fPtr.var.red.length + fPtr.var.green.length +
            fPtr.var.blue.length;
    else
        return fPtr.var.bits_per_pixel;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetLineLength(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (fPtr.fix.line_length)
        return fPtr.fix.line_length;
    else
        return fPtr.var.xres_virtual * fPtr.var.bits_per_pixel / 8;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetType(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    return fPtr.fix.type;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWGetVidmem(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    return fPtr.fix.smem_len;
}

private Bool fbdevHWSetMode(ScrnInfoPtr pScrn, DisplayModePtr mode, Bool check)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));
    fb_var_screeninfo req_var = fPtr.var, set_var = void;

    xfree2fbdev_fblayout(pScrn, &req_var);
    xfree2fbdev_timing(mode, &req_var);

version (DEBUG) {
    print_xfree_mode("init", mode);
    print_fbdev_mode("init", &req_var);
}

    set_var = req_var;

    if (check)
        set_var.activate = FB_ACTIVATE_TEST;

    if (0 != ioctl(fPtr.fd, FBIOPUT_VSCREENINFO, cast(void*) (&set_var))) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "FBIOPUT_VSCREENINFO: %s\n", strerror(errno));
        return FALSE;
    }

    if (!fbdev_modes_equal(&set_var, &req_var)) {
        if (!check)
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "FBIOPUT_VSCREENINFO succeeded but modified " ~ "mode\n");
version (DEBUG) {
        print_fbdev_mode("returned", &set_var);
}
        return FALSE;
    }

    if (!check)
        fPtr.var = set_var;

    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWSetVideoModes(ScrnInfoPtr pScrn)
{
    const(char)** modename = void;
    DisplayModePtr mode = void, this_ = void, last = pScrn.modes;

    if (null == pScrn.display.modes)
        return;

    pScrn.virtualX = pScrn.display.virtualX;
    pScrn.virtualY = pScrn.display.virtualY;

    for (modename = pScrn.display.modes; *modename !is null; modename++) {
        for (mode = pScrn.monitor.Modes; mode !is null; mode = mode.next) {
            if (0 == strcmp(mode.name, *modename)) {
                if (fbdevHWSetMode(pScrn, mode, TRUE))
                    break;

                xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                           "\tmode \"%s\" test failed\n", *modename);
            }
        }

        if (null == mode) {
            xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                       "\tmode \"%s\" not found\n", *modename);
            continue;
        }

        xf86DrvMsg(pScrn.scrnIndex, X_INFO, "\tmode \"%s\" ok\n", *modename);

        if (pScrn.virtualX < mode.HDisplay)
            pScrn.virtualX = mode.HDisplay;
        if (pScrn.virtualY < mode.VDisplay)
            pScrn.virtualY = mode.VDisplay;

        if (null == pScrn.modes) {
            this_ = pScrn.modes = xf86DuplicateMode(mode);
            this_.next = this_;
            this_.prev = this_;
        }
        else {
            this_ = xf86DuplicateMode(mode);
            this_.next = pScrn.modes;
            this_.prev = last;
            last.next = this_;
            pScrn.modes.prev = this_;
        }
        last = this_;
    }
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWUseBuildinMode(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    pScrn.modes = &fPtr.buildin;
    pScrn.virtualX = pScrn.display.virtualX;
    pScrn.virtualY = pScrn.display.virtualY;
    if (pScrn.virtualX < fPtr.buildin.HDisplay)
        pScrn.virtualX = fPtr.buildin.HDisplay;
    if (pScrn.virtualY < fPtr.buildin.VDisplay)
        pScrn.virtualY = fPtr.buildin.VDisplay;
}

/* -------------------------------------------------------------------- */

private void calculateFbmem_len(fbdevHWPtr fPtr)
{
    fPtr.fboff = cast(uint)(cast(c_ulong) fPtr.fix.smem_start & ~PAGE_MASK);
    fPtr.fbmem_len = (fPtr.fboff + fPtr.fix.smem_len + ~PAGE_MASK) &
        PAGE_MASK;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void* fbdevHWMapVidmem(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (null == fPtr.fbmem) {
        calculateFbmem_len(fPtr);
        fPtr.fbmem = mmap(null, fPtr.fbmem_len, PROT_READ | PROT_WRITE,
                           MAP_SHARED, fPtr.fd, 0);
        if (-1 == cast(c_long) fPtr.fbmem) {
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "mmap fbmem: %s\n", strerror(errno));
            fPtr.fbmem = null;
        }
        else {
            /* Perhaps we'd better add fboff to fbmem and return 0 in
               fbdevHWLinearOffset()? Of course we then need to mask
               //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
               fPtr->fbmem with PAGE_MASK in fbdevHWUnmapVidmem() as
               well. [geert] */
        }
    }
    pScrn.memPhysBase =
        cast(c_ulong) fPtr.fix.smem_start & cast(c_ulong) (PAGE_MASK);
    pScrn.fbOffset =
        cast(c_ulong) fPtr.fix.smem_start & cast(c_ulong) (~PAGE_MASK);
    return fPtr.fbmem;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int fbdevHWLinearOffset(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    return fPtr.fboff;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWUnmapVidmem(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (null != fPtr.fbmem) {
        if (-1 == munmap(fPtr.fbmem, fPtr.fbmem_len))
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "munmap fbmem: %s\n", strerror(errno));
        fPtr.fbmem = null;
    }
    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void* fbdevHWMapMMIO(ScrnInfoPtr pScrn)
{
    uint mmio_off = void;

    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (null == fPtr.mmio) {
        /* tell the kernel not to use accels to speed up console scrolling */
        fPtr.saved_accel = fPtr.var.accel_flags;
        fPtr.var.accel_flags = 0;
        if (0 != ioctl(fPtr.fd, FBIOPUT_VSCREENINFO, cast(void*) (&fPtr.var))) {
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "FBIOPUT_VSCREENINFO: %s\n", strerror(errno));
            return null;
        }
        mmio_off = cast(uint)(cast(c_ulong) fPtr.fix.mmio_start & ~PAGE_MASK);
        fPtr.mmio_len = (mmio_off + fPtr.fix.mmio_len + ~PAGE_MASK) &
            PAGE_MASK;
        if (null == fPtr.fbmem)
            calculateFbmem_len(fPtr);
        fPtr.mmio = cast(char*)mmap(null, fPtr.mmio_len, PROT_READ | PROT_WRITE,
                          MAP_SHARED, fPtr.fd, fPtr.fbmem_len);
        if (-1 == cast(c_long) fPtr.mmio) {
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "mmap mmio: %s\n", strerror(errno));
            fPtr.mmio = null;
        }
        else
            fPtr.mmio += mmio_off;
    }
    return fPtr.mmio;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWUnmapMMIO(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (null != fPtr.mmio) {
        if (-1 ==
            munmap(cast(void*) (cast(c_ulong) fPtr.mmio & PAGE_MASK),
                   fPtr.mmio_len))
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR, "munmap mmio: %s\n",
                       strerror(errno));
        fPtr.mmio = null;
        fPtr.var.accel_flags = fPtr.saved_accel;
        if (0 != ioctl(fPtr.fd, FBIOPUT_VSCREENINFO, cast(void*) (&fPtr.var))) {
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "FBIOPUT_VSCREENINFO: %s\n", strerror(errno));
            return FALSE;
        }
    }
    return TRUE;
}

/* -------------------------------------------------------------------- */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWModeInit(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    pScrn.vtSema = TRUE;

    /* set */
    if (!fbdevHWSetMode(pScrn, mode, FALSE))
        return FALSE;

    /* read back */
    if (0 != ioctl(fPtr.fd, FBIOGET_FSCREENINFO, cast(void*) (&fPtr.fix))) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "FBIOGET_FSCREENINFO: %s\n", strerror(errno));
        return FALSE;
    }
    if (0 != ioctl(fPtr.fd, FBIOGET_VSCREENINFO, cast(void*) (&fPtr.var))) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "FBIOGET_VSCREENINFO: %s\n", strerror(errno));
        return FALSE;
    }

    if (pScrn.defaultVisual == TrueColor ||
        pScrn.defaultVisual == DirectColor) {
        /* XXX: This is a hack, but it should be a NOP for all the setups that
         * worked before and actually seems to fix some others...
         */
        pScrn.offset.red = fPtr.var.red.offset;
        pScrn.offset.green = fPtr.var.green.offset;
        pScrn.offset.blue = fPtr.var.blue.offset;
        pScrn.mask.red =
            ((1 << fPtr.var.red.length) - 1) << fPtr.var.red.offset;
        pScrn.mask.green =
            ((1 << fPtr.var.green.length) - 1) << fPtr.var.green.offset;
        pScrn.mask.blue =
            ((1 << fPtr.var.blue.length) - 1) << fPtr.var.blue.offset;
    }

    return TRUE;
}

/* -------------------------------------------------------------------- */
/* video mode save/restore                                              */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWSave(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (0 != ioctl(fPtr.fd, FBIOGET_VSCREENINFO, cast(void*) (&fPtr.saved_var)))
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "FBIOGET_VSCREENINFO: %s\n", strerror(errno));
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWRestore(ScrnInfoPtr pScrn)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (0 != ioctl(fPtr.fd, FBIOPUT_VSCREENINFO, cast(void*) (&fPtr.saved_var)))
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "FBIOPUT_VSCREENINFO: %s\n", strerror(errno));
}

/* -------------------------------------------------------------------- */
/* callback for xf86HandleColormaps                                     */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWLoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));
    fb_cmap cmap = void;
    ushort red = void, green = void, blue = void;
    int i = void;

    cmap.len = 1;
    cmap.red = &red;
    cmap.green = &green;
    cmap.blue = &blue;
    cmap.transp = null;
    for (i = 0; i < numColors; i++) {
        cmap.start = indices[i];
        red = cast(short)((colors[indices[i]].red << 8) | colors[indices[i]].red);
        green = cast(short)((colors[indices[i]].green << 8) | colors[indices[i]].green);
        blue = cast(short)((colors[indices[i]].blue << 8) | colors[indices[i]].blue);
        if (-1 == ioctl(fPtr.fd, FBIOPUTCMAP, cast(void*) &cmap))
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "FBIOPUTCMAP: %s\n", strerror(errno));
    }
}

/* -------------------------------------------------------------------- */
/* these can be hooked directly into ScrnInfoRec                        */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
ModeStatus fbdevHWValidMode(ScrnInfoPtr pScrn, DisplayModePtr mode, Bool verbose, int flags)
{
    if (!fbdevHWSetMode(pScrn, mode, TRUE))
        return MODE_BAD;

    return MODE_OK;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    if (!fbdevHWSetMode(pScrn, mode, FALSE))
        return FALSE;

    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWAdjustFrame(ScrnInfoPtr pScrn, int x, int y)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));

    if (x < 0 || x + fPtr.var.xres > fPtr.var.xres_virtual ||
        y < 0 || y + fPtr.var.yres > fPtr.var.yres_virtual)
        return;

    fPtr.var.xoffset = x;
    fPtr.var.yoffset = y;
    if (-1 == ioctl(fPtr.fd, FBIOPAN_DISPLAY, cast(void*) &fPtr.var))
        xf86DrvMsgVerb(pScrn.scrnIndex, X_WARNING, 5,
                       "FBIOPAN_DISPLAY: %s\n", strerror(errno));
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWEnterVT(ScrnInfoPtr pScrn)
{
    if (!fbdevHWModeInit(pScrn, pScrn.currentMode))
        return FALSE;
    fbdevHWAdjustFrame(pScrn, pScrn.frameX0, pScrn.frameY0);
    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWLeaveVT(ScrnInfoPtr pScrn)
{
    fbdevHWRestore(pScrn);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void fbdevHWDPMSSet(ScrnInfoPtr pScrn, int mode, int flags)
{
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));
    c_ulong fbmode = void;

    if (!pScrn.vtSema)
        return;

    if (fPtr.unsupported_ioctls & (1 << FBIOBLANK_UNSUPPORTED))
        return;

    switch (mode) {
    case DPMSModeOn:
        fbmode = 0;
        break;
    case DPMSModeStandby:
        fbmode = 2;
        break;
    case DPMSModeSuspend:
        fbmode = 3;
        break;
    case DPMSModeOff:
        fbmode = 4;
        break;
    default:
        return;
    }

RETRY:
    if (-1 == ioctl(fPtr.fd, FBIOBLANK, cast(void*) fbmode)) {
        switch (errno) {
        case EAGAIN:
            xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                       "FBIOBLANK: %s\n", strerror(errno));
	    break;
        case EINTR:
        case ERESTART:
            goto RETRY;
        default:
            fPtr.unsupported_ioctls |= (1 << FBIOBLANK_UNSUPPORTED);
            xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                       "FBIOBLANK: %s (Screen blanking not supported "
                       ~ "by kernel - disabling)\n", strerror(errno));
        }
    }
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool fbdevHWSaveScreen(ScreenPtr pScreen, int mode)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    fbdevHWPtr fPtr = mixin(FBDEVHWPTR!(`pScrn`));
    c_ulong unblank = void;

    if (!pScrn.vtSema)
        return TRUE;

    if (fPtr.unsupported_ioctls & (1 << FBIOBLANK_UNSUPPORTED))
        return FALSE;

    unblank = xf86IsUnblank(mode);

RETRY:
    if (-1 == ioctl(fPtr.fd, FBIOBLANK, cast(void*) (1 - unblank))) {
        switch (errno) {
        case EAGAIN:
            xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                       "FBIOBLANK: %s\n", strerror(errno));
            break;
        case EINTR:
        case ERESTART:
            goto RETRY;
        default:
            fPtr.unsupported_ioctls |= (1 << FBIOBLANK_UNSUPPORTED);
            xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                       "FBIOBLANK: %s (Screen blanking not supported "
                       ~ "by kernel - disabling)\n", strerror(errno));
        }
        return FALSE;
    }

    return TRUE;
}

xf86SwitchModeProc fbdevHWSwitchModeWeak()
{
    return &fbdevHWSwitchMode;
}

xf86AdjustFrameProc fbdevHWAdjustFrameWeak()
{
    return &fbdevHWAdjustFrame;
}

xf86LeaveVTProc fbdevHWLeaveVTWeak()
{
    return &fbdevHWLeaveVT;
}

xf86ValidModeProc fbdevHWValidModeWeak()
{
    return &fbdevHWValidMode;
}

xf86DPMSSetProc fbdevHWDPMSSetWeak()
{
    return &fbdevHWDPMSSet;
}

xf86LoadPaletteProc fbdevHWLoadPaletteWeak()
{
    return &fbdevHWLoadPalette;
}
