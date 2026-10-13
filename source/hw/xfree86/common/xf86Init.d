module xf86Init;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Loosely based on code bearing the following copyright:
 *
 *   Copyright 1990,91 by Thomas Roell, Dinkelscherben, Germany.
 */
/*
 * Copyright (c) 1992-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
// import build.xorg_config;

import core.stdc.stdlib;
import core.stdc.errno;
import core.sys.posix.sys.stat;
import core.sys.linux.fcntl;
import xf86pciBus;

static if (!HasVersion!"Windows") {
enum HAS_UTSNAME = 1;
import core.sys.posix.sys.utsname;
}
import os.inputthread;
import externs.X11.extensions.dpmsconst;
import Xext.dpms;
//import x11.X;
////import x11.Xmd;
//import x11.Xproto;
//import externs.X11.Xatom;
////import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import config.dbus_core;
import config.hotplug_priv;
import dix.input_priv;
import dix.screenint_priv;
import include.xf86DDC;
import include.xorgVersion;
import mi.mi_priv;
import os.cmdline;
import os.ddx_priv;
import os.log_priv;
import os.osdep;
import randr.randrstr_priv;

import include.servermd;
import include.windowstr;
import include.scrnintstr;
import hw.xfree86.os_support.linux.systemd_logind;
import seatd_libseat;

// import xf86VGAarbiter_priv;
import hw.xfree86.loader.loaderProcs;

import xf86Module_priv;
import xf86_priv;
import include.xf86Priv;
import xf86Config;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;
import xf86cmap;
import mi.mipointer;
import xf86Extensions;
import xf86Xinput;
// import xf86InPriv;
import include.xf86Crtc;
import glx.glxbuiltin : xeniaGlxBuiltinInit;
import include.picturestr;
import xf86Bus;
import include.globals;
import include.xserver_properties;
import os.log;
import externs.attrs;
import xf86Globals;
import dix.property;
import xf86AutoConfig_;
import externs.X11.Xatom;
import xf86VGAarbiter;
import xf86Option;
import core.sys.posix.unistd;
import xf86Events;
import build.xlibre_server;


static if(DPMSExtension) {
//import externs.X11.extensions.dpmsconst;
import Xext.dpmsproc;
}

version (linux) {
import externs.linux.major;
import externs.sys.sysmacros;
}

import std.conv;

import hw.xfree86.common.xf86Helper;
import os.utils;

Bool xf86DoShowOptions = FALSE;

void function() xf86OSPMClose = null;
private Bool xorgHWOpenConsole = FALSE;

/* Common pixmap formats */

private PixmapFormatRec[MAXFORMATS] formats = [
    {1, 1, BITMAP_SCANLINE_PAD},
    {4, 8, BITMAP_SCANLINE_PAD},
    {8, 8, BITMAP_SCANLINE_PAD},
    {15, 16, BITMAP_SCANLINE_PAD},
    {16, 16, BITMAP_SCANLINE_PAD},
    {24, 32, BITMAP_SCANLINE_PAD},
    {32, 32, BITMAP_SCANLINE_PAD},
];

private int numFormats = 7;
private Bool formatsDone = FALSE;


private void xf86PrintBanner()
{
    xf86ErrorFVerb(0, "\nXLibre X Server %d.%d.%d",
                   XORG_VERSION_MAJOR.ptr, XORG_VERSION_MINOR.ptr, XORG_VERSION_PATCH.ptr);
static if (mixin(XORG_VERSION_SNAP) > 0) {
    xf86ErrorFVerb(0, ".%d", mixin(XORG_VERSION_SNAP));
}

static if (mixin(XORG_VERSION_SNAP) >= 900) {
    /* When the minor number is 99, that signifies that the we are making
     * a release candidate for a major version.  (X.0.0)
     * When the patch number is 99, that signifies that the we are making
     * a release candidate for a minor version.  (X.Y.0)
     * When the patch number is < 99, then we are making a release
     * candidate for the next point release.  (X.Y.Z)
     */
static if (XORG_VERSION_MINOR >= 99) {
    xf86ErrorFVerb(0, " (%d.0.0 RC %d)", XORG_VERSION_MAJOR + 1,
                   mixin(XORG_VERSION_SNAP) - 900);
} else static if (XORG_VERSION_PATCH == 99) {
    xf86ErrorFVerb(0, " (%d.%d.0 RC %d)", XORG_VERSION_MAJOR,
                   XORG_VERSION_MINOR + 1, mixin(XORG_VERSION_SNAP) - 900);
} else {
    xf86ErrorFVerb(0, " (%d.%d.%d RC %d)", XORG_VERSION_MAJOR,
                   XORG_VERSION_MINOR, XORG_VERSION_PATCH + 1,
                   mixin(XORG_VERSION_SNAP) - 900);
}
}

version (XORG_CUSTOM_VERSION) {
    xf86ErrorFVerb(0, " (%s)", XORG_CUSTOM_VERSION);
}
    xf86ErrorFVerb(0, "\nX Protocol Version %d, Revision %d\n",
                   X_PROTOCOL, X_PROTOCOL_REVISION);
version (HAS_UTSNAME) {
    {
        utsname name = void;

        /* Linux & BSD state that 0 is success, SysV (including Solaris, HP-UX,
           and Irix) and Single Unix Spec 3 just say that non-negative is success.
           All agree that failure is represented by a negative number.
         */
        if (uname(&name) >= 0) {
            xf86ErrorFVerb(0, "Current Operating System: %s %s %s %s %s\n",
                           name.sysname, name.nodename, name.release,
                           name.version_, name.machine);
version (linux) {
            do {
                int fd = open("/proc/cmdline", O_RDONLY);

                if (fd != -1) {
                    char[82] buf = 0;
                    xf86ErrorFVerb(0, "Kernel command line: ");
                    while (read(fd, buf.ptr, ((buf).ptr-2).sizeof) > 0) {
                        xf86ErrorFVerb(0, "%.80s", buf.ptr);
                        memset(buf.ptr, 0, buf.sizeof);
                    }
                    close(fd);
                }
            } while (0);
}
        }
    }
}
    xf86ErrorFVerb(0, "Current version of pixman: %s\n",
                   assumeNoGC(&pixman_version_string)());
}

Bool xf86HasTTYs()
{
version (linux) {
    stat_t tty0devAttributes = void;
    return (stat("/dev/tty0", &tty0devAttributes) == 0 && major(tty0devAttributes.st_rdev) == TTY_MAJOR);
} else {
    return TRUE;
}
}

private void xf86AutoConfigOutputDevices()
{
    int i = void;

    if (!xf86Info.autoBindGPU)
        return;

    for (i = 0; i < xf86NumGPUScreens; i++) {
        int scrnum = xf86GPUScreens[i].confScreen.screennum;
        RRProviderAutoConfigGpuScreen(xf86ScrnToScreen(xf86GPUScreens[i]),
                                      xf86ScrnToScreen(xf86Screens[scrnum]));
    }
}

private void AddSeatId(CallbackListPtr* pcbl, void* data, void* screen)
{
    ScreenPtr pScreen = cast(ScreenPtr)screen;
    Atom SeatAtom = dixAddAtom(SEAT_ATOM_NAME);
    int err = void;

    err = dixChangeWindowProperty(serverClient, pScreen.root, SeatAtom,
                                  XA_STRING, 8, PropModeReplace,
                                  strlen(cast(char*)data) + 1, data, FALSE);

    if (err != Success)
        xf86DrvMsg(pScreen.myNum, X_WARNING,
                   "Failed to register seat property\n");
}

private void AddVTAtoms(CallbackListPtr* pcbl, void* data, void* screen)
{
enum VT_ATOM_NAME =         "XFree86_VT";
    int err = void, HasVT = 1;
    ScreenPtr pScreen = cast(ScreenPtr)screen;
    Atom VTAtom = dixAddAtom(VT_ATOM_NAME);
    Atom HasVTAtom = dixAddAtom(HAS_VT_ATOM_NAME);

    err = dixChangeWindowProperty(serverClient, pScreen.root, VTAtom,
                                  XA_INTEGER, 32, PropModeReplace, 1,
                                  &xf86Info.vtno, FALSE);

    err |= dixChangeWindowProperty(serverClient, pScreen.root, HasVTAtom,
                                   XA_INTEGER, 32, PropModeReplace, 1,
                                   &HasVT, FALSE);

    if (err != Success)
        xf86DrvMsg(pScreen.myNum, X_WARNING,
                   "Failed to register VT properties\n");
}

private Bool xf86ScreenInit(ScreenPtr pScreen, int argc, char** argv)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    pScrn.pScreen = pScreen;
    return pScrn.ScreenInit (pScreen, argc, argv);
}

private void xf86EnsureRANDR(ScreenPtr pScreen)
{
static if(build.xlibre_server.RANDR){
        if (!dixPrivateKeyRegistered(rrPrivKey) ||
            !mixin(rrGetScrPriv!("pScreen")))
            xf86RandRInit(pScreen);
}
}

/*
 * InitOutput --
 *	Initialize screenInfo for all actually accessible framebuffers.
 *      That includes vt-manager setup, querying all possible devices and
 *      collecting the pixmap formats.
 */
void InitOutput(int argc, char** argv)
{

    int i = void, j = void, k = void, scr_index = void;
    const(char)** modulelist = void;
    void** optionlist = void;
    Bool autoconfig = FALSE;
    Bool sigio_blocked = FALSE;
    Bool want_hw_access = FALSE;
    GDevPtr configured_device = void;

    xf86Initialising = TRUE;

    config_pre_init();


    if (serverGeneration == 1) {
        xf86PrintBanner();

        LogPrintMarkers();

        if (xf86LogFile) {
            time_t t = void;
            const(char)* ct = void;

            t = time(null);
            ct = ctime(&t);
            LogMessageVerb(xf86LogFileFrom, 0, "Log file: \"%s\", Time: %s",
                        xf86LogFile, ct);
        }


        /* Read and parse the config file */
        if (!xf86DoConfigure && !xf86DoShowOptions) {
            switch (xf86HandleConfigFile(FALSE)) {
            case _ConfigStatus.CONFIG_OK:
                break;
            case _ConfigStatus.CONFIG_PARSE_ERROR:
                LogMessageVerb(X_ERROR, 1, "Error parsing the config file\n");
                return;
            case _ConfigStatus.CONFIG_NOFILE:
                autoconfig = TRUE;
                break;
            default: break;}
        }


        /* Initialise the loader */
        LoaderInit();
    // fprintf(stderr, "\nLOL LOADSER\n");


        /* Tell the loader the default module search path */
        LoaderSetPath(null, xf86ModulePath);
    // fprintf(stderr, "\nLOLsdfsdfsds\n");


        xf86Info.ignoreABI = 1;
        if (xf86Info.ignoreABI) {
            LoaderSetIgnoreAbi();
        }
    fprintf(stderr, "\nLOxcvxvxvL\n");


        if (xf86DoShowOptions)
            DoShowOptions();
    // fprintf(stderr, "\nLOwerewfdxL\n");


        dbus_core_init();
    // fprintf(stderr, "\nLOhghjfhL\n");

        seatd_libseat_init(cast(bool)xf86VTKeepTtyIsSet());
    // fprintf(stderr, "\nLqewqecxOL\n");

        systemd_logind_init();
    // fprintf(stderr, "\nLxczfcxvgcvbOL\n");


        /* Do a general bus probe.  This will be a PCI probe for x86 platforms */
        xf86BusProbe();
    // fprintf(stderr, "\nLertetOL\n");


        if (xf86DoConfigure)
            DoConfigure();

        if (autoconfig) {
            if (!xf86AutoConfig()) {
                LogMessageVerb(X_ERROR, 1, "Auto configuration failed\n");
                return;
            }
        }

        xf86OSPMClose = xf86OSPMOpen();

        xf86ExtensionInit();

        /* GLX is implemented in this server; don't load system libglx.so. */
        if (!xeniaGlxBuiltinInit()) {
            LogMessageVerb(X_ERROR, 1,
                           "Failed to initialize built-in GLX\n");
            return;
        }

        /* Load all modules specified explicitly in the config file */
        if ((modulelist = xf86ModulelistFromConfig(&optionlist)) !is null) {
            xf86LoadModules(modulelist, optionlist);
            free(modulelist);
            free(optionlist);
        }


        /* Load all driver modules specified in the config file */
        /* If there aren't any specified in the config file, autoconfig them */
        /* FIXME: Does not handle multiple active screen sections, but I'm not
         * sure if we really want to handle that case*/
        configured_device = xf86ConfigLayout.screens.screen.device;
        if ((!configured_device) || (!configured_device.driver)) {
            if (!autoConfigDevice(configured_device)) {
                LogMessageVerb(X_ERROR, 1, "Automatic driver configuration failed\n");
                return;
            }
            fprintf(stderr, "CONFIG");
        }

        if ((modulelist = xf86DriverlistFromConfig()) !is null) {
            xf86LoadModules(modulelist, null);
            free(modulelist);
            fprintf(stderr, "MODULELIST");

        }


        /* Load all input driver modules specified in the config file. */
        if ((modulelist = xf86InputDriverlistFromConfig())!is null) {
            xf86LoadModules(modulelist, null);
            free(modulelist);
            fprintf(stderr, "INOUTDRIVERLIST");

        }


        /*
         * It is expected that xf86AddDriver()/xf86AddInputDriver will be
         * called for each driver as it is loaded.  Those functions save the
         * module pointers for drivers.
         * XXX Nothing keeps track of them for other modules.
         */
        /* XXX What do we do if not all of these could be loaded? */

        /*
         * At this point, xf86DriverList[] is all filled in with entries for
         * each of the drivers to try and xf86NumDrivers has the number of
         * drivers.  If there are none, return now.
         */

        if (xf86NumDrivers == 0) {
            LogMessageVerb(X_ERROR, 1, "No drivers available.\n");
            return;
        }

        /*
         * Call each of the Identify functions and call the driverFunc to check
         * if HW access is required.  The Identify functions print out some
         * identifying information, and anything else that might be
         * needed at this early stage.
         */

        for (i = 0; i < xf86NumDrivers; i++) {
            xorgHWFlags flags = HW_IO;

            if (xf86DriverList[i].Identify !is null)
                xf86DriverList[i].Identify(0);

            if (xf86DriverList[i].driverFunc !is null)
                (*xf86DriverList[i].driverFunc)(null,
                                              GET_REQUIRED_HW_INTERFACES,
                                              &flags);

            if (mixin(NEED_IO_ENABLED!("flags")))
                want_hw_access = TRUE;

            /* Non-seat0 X servers should not open console */
            if (!(flags & HW_SKIP_CONSOLE) && !mixin(ServerIsNotSeat0!()) && xf86HasTTYs())
                xorgHWOpenConsole = TRUE;
        }


        if (xorgHWOpenConsole) {
            if (!seatd_libseat_controls_session()) {
                xf86OpenConsole();
            }
        } else
            xf86Info.dontVTSwitch = TRUE;


	/* Enable full I/O access */
	if (want_hw_access)
	    xorgHWAccess = xf86EnableIO();

        if (xf86BusConfig(xf86Info.singleDriver) == FALSE)
            return;


        /*
         * Sort the drivers to match the requested ordering.  Using a slow
         * bubble sort.
         */
        for (j = 0; j < xf86NumScreens - 1; j++) {
            for (i = 0; i < xf86NumScreens - j - 1; i++) {
                if (xf86Screens[i + 1].confScreen.screennum <
                    xf86Screens[i].confScreen.screennum) {
                    ScrnInfoPtr tmpScrn = xf86Screens[i + 1];

                    xf86Screens[i + 1] = xf86Screens[i];
                    xf86Screens[i] = tmpScrn;
                }
            }
        }
        /* Fix up the indexes */
        for (i = 0; i < xf86NumScreens; i++) {
            xf86Screens[i].scrnIndex = i;
        }

        /*
         * Call the driver's PreInit()'s to complete initialisation for the first
         * generation.
         */

        for (i = 0; i < xf86NumScreens; i++) {
            xf86VGAarbiterScrnInit(xf86Screens[i]);
            xf86VGAarbiterLock(xf86Screens[i]);
            if (xf86Screens[i].PreInit &&
                xf86Screens[i].PreInit(xf86Screens[i], 0))
                xf86Screens[i].configured = TRUE;
            xf86VGAarbiterUnlock(xf86Screens[i]);
        }
        for (i = 0; i < xf86NumScreens; i++)
            if (!xf86Screens[i].configured)
                xf86DeleteScreen(xf86Screens[i--]);

        for (i = 0; i < xf86NumGPUScreens; i++) {
            xf86VGAarbiterScrnInit(xf86GPUScreens[i]);
            xf86VGAarbiterLock(xf86GPUScreens[i]);
            if (xf86GPUScreens[i].PreInit &&
                xf86GPUScreens[i].PreInit(xf86GPUScreens[i], 0))
                xf86GPUScreens[i].configured = TRUE;
            xf86VGAarbiterUnlock(xf86GPUScreens[i]);
        }
        for (i = 0; i < xf86NumGPUScreens; i++)
            if (!xf86GPUScreens[i].configured)
                xf86DeleteScreen(xf86GPUScreens[i--]);

        /*
         * If no screens left, return now.
         */

        if (xf86NumScreens == 0) {
            LogMessageVerb(X_ERROR, 1,
                           "Screen(s) found, but none have a usable configuration.\n");
            return;
        }

        /* Remove (unload) drivers that are not required */
        for (i = 0; i < xf86NumDrivers; i++)
            if (xf86DriverList[i] && xf86DriverList[i].refCount <= 0)
                xf86DeleteDriver(i);

        /*
         * At this stage we know how many screens there are.
         */

        for (i = 0; i < xf86NumScreens; i++)
            xf86InitViewport(xf86Screens[i]);

        /*
         * Collect all pixmap formats and check for conflicts at the display
         * level.  Should we die here?  Or just delete the offending screens?
         */
        for (i = 0; i < xf86NumScreens; i++) {
            if (xf86Screens[i].imageByteOrder !=
                xf86Screens[0].imageByteOrder)
                FatalError("Inconsistent display bitmapBitOrder.  Exiting\n");
            if (xf86Screens[i].bitmapScanlinePad !=
                xf86Screens[0].bitmapScanlinePad)
                FatalError
                    ("Inconsistent display bitmapScanlinePad.  Exiting\n");
            if (xf86Screens[i].bitmapScanlineUnit !=
                xf86Screens[0].bitmapScanlineUnit)
                FatalError
                    ("Inconsistent display bitmapScanlineUnit.  Exiting\n");
            if (xf86Screens[i].bitmapBitOrder !=
                xf86Screens[0].bitmapBitOrder)
                FatalError("Inconsistent display bitmapBitOrder.  Exiting\n");
        }

        /* Collect additional formats */
        for (i = 0; i < xf86NumScreens; i++) {
            for (j = 0; j < xf86Screens[i].numFormats; j++) {
                for (k = 0;; k++) {
                    if (k >= numFormats) {
                        if (k >= MAXFORMATS)
                            FatalError("Too many pixmap formats!  Exiting\n");
                        formats[k] = xf86Screens[i].formats[j];
                        numFormats++;
                        break;
                    }
                    if (formats[k].depth == xf86Screens[i].formats[j].depth) {
                        if ((formats[k].bitsPerPixel ==
                             xf86Screens[i].formats[j].bitsPerPixel) &&
                            (formats[k].scanlinePad ==
                             xf86Screens[i].formats[j].scanlinePad))
                            break;
                        FatalError("Inconsistent pixmap format for depth %d."
                                   ~ "  Exiting\n", formats[k].depth);
                    }
                }
            }
        }
        formatsDone = TRUE;
    }
    else {
        /*
         * serverGeneration != 1; some OSs have to do things here, too.
         */
        if (xorgHWOpenConsole) {
            if (!seatd_libseat_controls_session()) {
                xf86OpenConsole();
            }
        }

        /*
           should we reopen it here? We need to deal with an already opened
           device. We could leave this to the OS layer. For now we simply
           close it here
         */
        if (xf86OSPMClose)
            xf86OSPMClose();
        if ((xf86OSPMClose = xf86OSPMOpen()) !is null)
            LogMessageVerb(X_INFO, 3, "APM registered successfully\n");

        /* Make sure full I/O access is enabled */
        if (xorgHWAccess)
            xf86EnableIO();
    }

    if (xf86Info.vtno >= 0)
        AddCallback(&RootWindowFinalizeCallback, &AddVTAtoms, null);

    if (dixSettingSeatId)
        AddCallback(&RootWindowFinalizeCallback, &AddSeatId, dixSettingSeatId);

    /*
     * Use the previously collected parts to setup screenInfo
     */

    screenInfo.imageByteOrder = xf86Screens[0].imageByteOrder;
    screenInfo.bitmapScanlinePad = xf86Screens[0].bitmapScanlinePad;
    screenInfo.bitmapScanlineUnit = xf86Screens[0].bitmapScanlineUnit;
    screenInfo.bitmapBitOrder = xf86Screens[0].bitmapBitOrder;
    screenInfo.numPixmapFormats = numFormats;
    for (i = 0; i < numFormats; i++)
        screenInfo.formats[i] = cast(_PixmapFormat)formats[i];

    /* Make sure the server's VT is active */

    if (serverGeneration != 1) {
        xf86Resetting = TRUE;
        /* All screens are in the same state, so just check the first */
        if (!xf86VTOwner()) {
// static if (HAS_USL_VTS) {
            ioctl(xf86Info.consoleFd, VT_RELDISP, VT_ACKACQ);
// }
            input_lock();
            sigio_blocked = TRUE;
        }
    }

    for (i = 0; i < xf86NumScreens; i++)
        if (!xf86ColormapAllocatePrivates(xf86Screens[i]))
            FatalError("Cannot register DDX private keys");

    if (!dixRegisterPrivateKey(&xf86ScreenKeyRec, PRIVATE_SCREEN, 0))
        FatalError("Cannot register DDX private keys");

    for (i = 0; i < xf86NumScreens; i++) {
        xf86VGAarbiterLock(xf86Screens[i]);
        /*
         * Almost everything uses these defaults, and many of those that
         * don't, will wrap them.
         */
        xf86Screens[i].EnableDisableFBAccess = &xf86EnableDisableFBAccess;
static if(build.xlibre_server.XFreeXDGA){
        xf86Screens[i].SetDGAMode = xf86SetDGAMode;
}
        scr_index = AddScreen(&xf86ScreenInit, argc, argv);
        xf86VGAarbiterUnlock(xf86Screens[i]);
        if (scr_index == i) {
            /*
             * Hook in our ScrnInfoRec, and initialise some other pScreen
             * fields.
             */
            dixSetPrivate(&screenInfo.screens[scr_index].devPrivates,
                          xf86ScreenKey, xf86Screens[i]);
            xf86Screens[i].pScreen = screenInfo.screens[scr_index];
            /* The driver should set this, but make sure it is set anyway */
            xf86Screens[i].vtSema = TRUE;
        }
        else {
            /* This shouldn't normally happen */
            FatalError("AddScreen/ScreenInit failed for driver %d\n", i);
        }

        if (PictureGetSubpixelOrder(xf86Screens[i].pScreen) == SubPixelUnknown) {
            xf86MonPtr DDC = cast(xf86MonPtr) (xf86Screens[i].monitor.DDC);

            PictureSetSubpixelOrder(xf86Screens[i].pScreen,
                                    DDC ?
                                    (DDC.features.input_type ?
                                     SubPixelHorizontalRGB : SubPixelNone) :
                                    SubPixelUnknown);
        }

        /*
         * If the driver hasn't set up its own RANDR support, install the
         * fallback support.
         */
        xf86EnsureRANDR(xf86Screens[i].pScreen);
    }

    for (i = 0; i < xf86NumGPUScreens; i++) {
        ScrnInfoPtr pScrn = xf86GPUScreens[i];
        xf86VGAarbiterLock(pScrn);

        /*
         * Almost everything uses these defaults, and many of those that
         * don't, will wrap them.
         */
        pScrn.EnableDisableFBAccess = &xf86EnableDisableFBAccess;
static if(build.xlibre_server.XFreeXDGA){
        pScrn.SetDGAMode = xf86SetDGAMode;
}
        scr_index = AddGPUScreen(&xf86ScreenInit, argc, argv);
        xf86VGAarbiterUnlock(pScrn);
        if (scr_index == i) {
            dixSetPrivate(&screenInfo.gpuscreens[scr_index].devPrivates,
                          xf86ScreenKey, xf86GPUScreens[i]);
            pScrn.pScreen = screenInfo.gpuscreens[scr_index];
            /* The driver should set this, but make sure it is set anyway */
            pScrn.vtSema = TRUE;
        } else {
            FatalError("AddScreen/ScreenInit failed for gpu driver %d %d\n", i, scr_index);
        }
    }

    for (i = 0; i < xf86NumGPUScreens; i++) {
        int scrnum = xf86GPUScreens[i].confScreen.screennum;
        AttachUnboundGPU(xf86Screens[scrnum].pScreen, xf86GPUScreens[i].pScreen);
    }

    xf86AutoConfigOutputDevices();

    xf86VGAarbiterWrapFunctions();
    if (sigio_blocked)
        input_unlock();

    xf86InitOrigins();

    xf86Resetting = FALSE;
    xf86Initialising = FALSE;

    RegisterBlockAndWakeupHandlers(cast(ServerBlockHandlerProcPtr) &NoopDDA, &xf86Wakeup,
                                   null);
}

/**
 * Initialize all supported input devices present and referenced in the
 * xorg.conf.
 */
void InitInput(int argc, char** argv)
{
    InputInfoPtr* pInfo = void;
    DeviceIntPtr dev = void;

    xf86Info.vtRequestsPending = FALSE;

    /* Enable threaded input */
    InputThreadPreInit();

    mieqInit();

    /* Initialize all configured input devices */
    for (pInfo = xf86ConfigLayout.inputs; pInfo && *pInfo; pInfo++) {
        (*pInfo).options =
            xf86AddNewOption((*pInfo).options, "driver", (*pInfo).driver);
        (*pInfo).options =
            xf86AddNewOption((*pInfo).options, "identifier", (*pInfo).name);
        /* If one fails, the others will too */
        if (NewInputDeviceRequest((*pInfo).options, null, &dev) == BadAlloc)
            break;
    }

    config_init();
}

void CloseInput()
{
    config_fini();
    mieqFini();
    /* strictly speaking the below is not related to input, but ... */
    LoaderClose();
}

/*
 * OsVendorInit --
 *      OS/Vendor-specific initialisations.  Called from OsInit(), which
 *      is called by dix before establishing the well known sockets.
 */

void OsVendorInit()
{
    static Bool beenHere = FALSE;

    OsSignal(SIGCHLD, SIG_DFL);   /* Need to wait for child processes */

    if (!beenHere) {
        umask(octal!"022");
        xf86LogInit();
    }

    /* Set stderr to non-blocking. */
version (O_NONBLOCK) {} else {
version (FNDELAY) {
enum O_NONBLOCK = FNDELAY;
} else version (O_NDELAY) {
enum O_NONBLOCK = O_NDELAY;
}

version (O_NONBLOCK) {
    if (!beenHere) {
        if (PrivsElevated()) {
            int status = void;

            status = fcntl(fileno(stderr), F_GETFL, 0);
            if (status != -1) {
                fcntl(fileno(stderr), F_SETFL, status | O_NONBLOCK);
            }
        }
    }
}
}

    beenHere = TRUE;
}

/*
 * ddxGiveUp --
 *      Device dependent cleanup. Called by by dix before normal server death.
 *      On some OSes we must switch the terminal back to normal mode. No error-
 *      checking here, since there should be restored as much as possible.
 */

void ddxGiveUp(ExitCode error)
{
    int i = void;

    if (error == EXIT_ERR_ABORT) {
        input_lock();

        /* try to restore the original video state */
static if(DPMSExtension) {            /* Turn screens back on */
        if (DPMSPowerLevel != DPMSModeOn)
            DPMSSet(serverClient, DPMSModeOn);
}
        if (xf86Screens) {
            for (i = 0; i < xf86NumScreens; i++)
                if (xf86Screens[i].vtSema) {
                    /*
                     * if we are aborting before ScreenInit() has finished we
                     * might not have been wrapped yet. Therefore enable screen
                     * explicitly.
                     */
                    xf86VGAarbiterLock(xf86Screens[i]);
                    (xf86Screens[i].LeaveVT) (xf86Screens[i]);
                    xf86VGAarbiterUnlock(xf86Screens[i]);
                }
        }
    }

    xf86VGAarbiterFini();

    if (xf86OSPMClose)
        xf86OSPMClose();
    xf86OSPMClose = null;

    for (i = 0; i < xf86NumScreens; i++) {
        /*
         * zero all access functions to
         * trap calls when switched away.
         */
        xf86Screens[i].vtSema = FALSE;
    }

    if (xorgHWOpenConsole) {
        if (!seatd_libseat_controls_session()) {
            xf86CloseConsole();
        }
    }

    seatd_libseat_fini();
    systemd_logind_fini();
    dbus_core_fini();

    xf86CloseLog(error);
}

void OsVendorFatalError(const(char)* f, va_list args)
{
    ErrorF("\nPlease consult the XLibre support: https://www.xlibre.net/\n");
    if (xf86LogFile && xf86LogFileWasOpened)
        ErrorF("Please also check the log file at \"%s\" for additional "
               ~ "information.\n", xf86LogFile);
    ErrorF("\n");
}

void xf86SetVerbosity(int verb)
{
    xf86Verbose = verb;
    xorgLogVerbosity = verb;
}

void xf86SetLogVerbosity(int verb)
{
    xf86LogVerbose = verb;
    xorgLogFileVerbosity = verb;
}

private void xf86PrintDefaultModulePath()
{
    ErrorF("%s\n", DEFAULT_MODULE_PATH.ptr);
}

private void xf86PrintDefaultLibraryPath()
{
    ErrorF("%s\n", DEFAULT_LIBRARY_PATH.ptr);
}

private void xf86CheckPrivs(const(char)* option, const(char)* arg)
{
    if (PrivsElevated() && !xf86PathIsSafe(arg)) {
        FatalError("\nInvalid argument for %s - \"%s\"\n"
                    ~ "\tWith elevated privileges %s must specify a relative path\n"
                    ~ "\twithout any \"..\" elements.\n\n", option, arg, option);
    }
}

/*
 * ddxProcessArgument --
 *	Process device-dependent command line args. Returns 0 if argument is
 *      not device dependent, otherwise Count of number of elements of argv
 *      that are part of a device dependent commandline option.
 *
 */

/* ARGSUSED */
int ddxProcessArgument(int argc, char** argv, int i)
{
    /* First the options that are not allowed with elevated privileges */
    if (!strcmp(argv[i], "-modulepath")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (PrivsElevated())
              FatalError("\nInvalid argument -modulepath "
                ~ "with elevated privileges\n");
        xf86ModulePath = argv[i + 1];
        xf86ModPathFrom = X_CMDLINE;
        return 2;
    }
    if (!strcmp(argv[i], "-logfile")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (PrivsElevated())
              FatalError("\nInvalid argument -logfile "
                ~ "with elevated privileges\n");
        xf86LogFile = argv[i + 1];
        xf86LogFileFrom = X_CMDLINE;
        return 2;
    }
    if (!strcmp(argv[i], "-config") || !strcmp(argv[i], "-xf86config")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86CheckPrivs(argv[i], argv[i + 1]);
        xf86ConfigFile = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-configdir")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86CheckPrivs(argv[i], argv[i + 1]);
        xf86ConfigDir = argv[i + 1];
        return 2;
    }
    if (!strcmp(argv[i], "-flipPixels")) {
        xf86FlipPixels = TRUE;
        return 1;
    }
static if(build.xlibre_server.XF86VIDMODE){
    if (!strcmp(argv[i], "-disableVidMode")) {
        xf86VidModeDisabled = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-allowNonLocalXvidtune")) {
        xf86VidModeAllowNonLocal = TRUE;
        return 1;
    }
}
    if (!strcmp(argv[i], "-allowMouseOpenFail")) {
        xf86AllowMouseOpenFail = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-ignoreABI")) {
        LoaderSetIgnoreAbi();
        return 1;
    }
    if (!strcmp(argv[i], "-verbose")) {
        if (++i < argc && argv[i]) {
            char* end = void;
            c_long val = void;

            val = strtol(argv[i], &end, 0);
            if (*end == '\0') {
                xf86SetVerbosity(cast(int)val);
                return 2;
            }
        }
        xf86SetVerbosity(cast(int)++xf86Verbose);
        return 1;
    }
    if (!strcmp(argv[i], "-logverbose")) {
        if (++i < argc && argv[i]) {
            char* end = void;
            c_long val = void;

            val = strtol(argv[i], &end, 0);
            if (*end == '\0') {
                xf86SetLogVerbosity(cast(int)val);
                return 2;
            }
        }
        xf86SetLogVerbosity(cast(int)++xf86LogVerbose);
        return 1;
    }
    if (!strcmp(argv[i], "-quiet")) {
        xf86SetVerbosity(cast(int)-1);
        return 1;
    }
    if (!strcmp(argv[i], "-showconfig") || !strcmp(argv[i], "-version")) {
        xf86PrintBanner();
        exit(0);
    }
    if (!strcmp(argv[i], "-showDefaultModulePath")) {
        xf86PrintDefaultModulePath();
        exit(0);
    }
    if (!strcmp(argv[i], "-showDefaultLibPath")) {
        xf86PrintDefaultLibraryPath();
        exit(0);
    }
    /* Notice the -fp flag, but allow it to pass to the dix layer */
    if (!strcmp(argv[i], "-fp")) {
        xf86fpFlag = TRUE;
        return 0;
    }
    /* Notice the -bs flag, but allow it to pass to the dix layer */
    if (!strcmp(argv[i], "-bs")) {
        xf86bsDisableFlag = TRUE;
        return 0;
    }
    /* Notice the +bs flag, but allow it to pass to the dix layer */
    if (!strcmp(argv[i], "+bs")) {
        xf86bsEnableFlag = TRUE;
        return 0;
    }
    if (!strcmp(argv[i], "-pixmap32") || !strcmp(argv[i], "-pixmap24")) {
        /* silently accept */
        return 1;
    }
    if (!strcmp(argv[i], "-fbbpp")) {
        int bpp = void;

        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (sscanf(argv[++i], "%d", &bpp) == 1) {
            xf86FbBpp = bpp;
            return 2;
        }
        else {
            ErrorF("Invalid fbbpp\n");
            return 0;
        }
    }
    if (!strcmp(argv[i], "-depth")) {
        int depth = void;

        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (sscanf(argv[++i], "%d", &depth) == 1) {
            xf86Depth = depth;
            return 2;
        }
        else {
            ErrorF("Invalid depth\n");
            return 0;
        }
    }
    if (!strcmp(argv[i], "-weight")) {
        int red = void, green = void, blue = void;

        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (sscanf(argv[++i], "%1d%1d%1d", &red, &green, &blue) == 3) {
            xf86Weight.red = red;
            xf86Weight.green = green;
            xf86Weight.blue = blue;
            return 2;
        }
        else {
            ErrorF("Invalid weighting\n");
            return 0;
        }
    }
    if (!strcmp(argv[i], "-gamma") || !strcmp(argv[i], "-rgamma") ||
        !strcmp(argv[i], "-ggamma") || !strcmp(argv[i], "-bgamma")) {
        double gamma = void;

        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (sscanf(argv[++i], "%lf", &gamma) == 1) {
            if (gamma < GAMMA_MIN || gamma > GAMMA_MAX) {
                ErrorF("gamma out of range, only  %.2f <= gamma_value <= %.1f"
                       ~ " is valid\n", GAMMA_MIN, GAMMA_MAX);
                return 0;
            }
            if (!strcmp(argv[i - 1], "-gamma"))
                xf86Gamma.red = xf86Gamma.green = xf86Gamma.blue = gamma;
            else if (!strcmp(argv[i - 1], "-rgamma"))
                xf86Gamma.red = gamma;
            else if (!strcmp(argv[i - 1], "-ggamma"))
                xf86Gamma.green = gamma;
            else if (!strcmp(argv[i - 1], "-bgamma"))
                xf86Gamma.blue = gamma;
            return 2;
        }
    }
    if (!strcmp(argv[i], "-layout")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86LayoutName = argv[++i];
        return 2;
    }
    if (!strcmp(argv[i], "-screen")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86ScreenName = argv[++i];
        return 2;
    }
    if (!strcmp(argv[i], "-pointer")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86PointerName = argv[++i];
        return 2;
    }
    if (!strcmp(argv[i], "-keyboard")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        xf86KeyboardName = argv[++i];
        return 2;
    }
    if (!strcmp(argv[i], "-nosilk")) {
        xf86silkenMouseDisableFlag = TRUE;
        return 1;
    }
static if (HAVE_ACPI) {
    if (!strcmp(argv[i], "-noacpi")) {
        xf86acpiDisableFlag = TRUE;
        return 1;
    }
}
    if (!strcmp(argv[i], "-configure")) {
        if (getuid() != 0 && geteuid() == 0) {
            ErrorF("The '-configure' option can only be used by root.\n");
            exit(1);
        }
        xf86DoConfigure = TRUE;
        xf86AllowMouseOpenFail = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-showopts")) {
        if (getuid() != 0 && geteuid() == 0) {
            ErrorF("The '-showopts' option can only be used by root.\n");
            exit(1);
        }
        xf86DoShowOptions = TRUE;
        return 1;
    }
static if(XSERVER_LIBPCIACCESS){
    if (!strcmp(argv[i], "-isolateDevice")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENTS!("1"));
        if (strncmp(argv[++i], "PCI:", 4)) {
            FatalError("Bus types other than PCI not yet isolable\n");
        }
        xf86PciIsolateDevice(argv[i]);
        return 2;
    }
}
    /* Notice cmdline xkbdir, but pass to dix as well */
    if (!strcmp(argv[i], "-xkbdir")) {
        xf86xkbdirFlag = TRUE;
        return 0;
    }
    if (!strcmp(argv[i], "-novtswitch")) {
        xf86Info.autoVTSwitch = FALSE;
        return 1;
    }
    if (!strcmp(argv[i], "-sharevts")) {
        xf86Info.ShareVTs = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-iglx") || !strcmp(argv[i], "+iglx")) {
        xf86Info.iglxFrom = X_CMDLINE;
        return 0;
    }
    if (!strcmp(argv[i], "-noautoBindGPU")) {
        xf86AutoBindGPUDisabled = TRUE;
        return 1;
    }

    /* OS-specific processing */
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    // //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    return xf86ProcessArgument(argc, argv, i);
}

/*
 * ddxUseMsg --
 *	Print out correct use of device dependent commandline options.
 *      Maybe the user now knows what really to do ...
 */

void ddxUseMsg()
{
    ErrorF("\n");
    ErrorF("\n");
    ErrorF("Device Dependent Usage\n");
    if (!PrivsElevated()) {
        ErrorF("-modulepath paths      specify the module search path\n");
        ErrorF("-logfile file          specify a log file name\n");
        ErrorF("-configure             probe for devices and write an "~
               build.xlibre_server.XCONFIGFILE ~ "\n");
        ErrorF
            ("-showopts              print available options for all installed drivers\n");
    }
    ErrorF
        ("-config file           specify a configuration file, relative to the\n");
    ErrorF("                       " ~build.xlibre_server.XCONFIGFILE
           ~ " search path, only root can use absolute\n");
    ErrorF
        ("-configdir dir         specify a configuration directory, relative to the\n");
    ErrorF("                       " ~XCONFIGDIR
           ~ " search path, only root can use absolute\n");
    ErrorF("-verbose [n]           verbose startup messages\n");
    ErrorF("-logverbose [n]        verbose log messages\n");
    ErrorF("-quiet                 minimal startup messages\n");
    ErrorF("-fbbpp n               set bpp for the framebuffer. Default: 8\n");
    ErrorF("-depth n               set colour depth. Default: 8\n");
    ErrorF
        ("-gamma f               set gamma value (0.1 < f < 10.0) Default: 1.0\n");
    ErrorF("-rgamma f              set gamma value for red phase\n");
    ErrorF("-ggamma f              set gamma value for green phase\n");
    ErrorF("-bgamma f              set gamma value for blue phase\n");
    ErrorF
        ("-weight nnn            set RGB weighting at 16 bpp.  Default: 565\n");
    ErrorF("-layout name           specify the ServerLayout section name\n");
    ErrorF("-screen name           specify the Screen section name\n");
    ErrorF
        ("-keyboard name         specify the core keyboard InputDevice name\n");
    ErrorF
        ("-pointer name          specify the core pointer InputDevice name\n");
    ErrorF("-nosilk                disable Silken Mouse\n");
    ErrorF("-flipPixels            swap default black/white Pixel values\n");
static if(build.xlibre_server.XF86VIDMODE){
    ErrorF("-disableVidMode        disable mode adjustments with xvidtune\n");
    ErrorF
        ("-allowNonLocalXvidtune allow xvidtune to be run as a non-local client\n");
}
    ErrorF
        ("-allowMouseOpenFail    start server even if the mouse can't be initialized\n");
    ErrorF("-ignoreABI             make module ABI mismatches non-fatal\n");
static if(XSERVER_LIBPCIACCESS){
    ErrorF
        ("-isolateDevice bus_id  restrict device resets to bus_id (PCI only)\n");
}
    ErrorF("-version               show the server version\n");
    ErrorF("-showDefaultModulePath show the server default module path\n");
    ErrorF("-showDefaultLibPath    show the server default library path\n");
    ErrorF
        ("-novtswitch            don't automatically switch VT at reset & exit\n");
    ErrorF("-sharevts              share VTs with another X server\n");
    /* OS-specific usage */
    xf86UseMsg();
    ErrorF("\n");
}

/*
 * xf86LoadModules iterates over a list that is being passed in.
 */
Bool xf86LoadModules(const(char)** list, void** optlist)
{
    int errmaj = void;
    void* opt = void;
    int i = void;
    char* name = void;
    Bool failed = FALSE;

    if (!list)
        return TRUE;

    for (i = 0; list[i] !is null; i++) {

        /* Normalise the module name */
        name = xf86NormalizeName(list[i]);

        /* Skip empty names */
        if (name is null || *name == '\0') {
            free(name);
            continue;
        }

        /* Replace obsolete keyboard driver with kbd */
        if (!xf86NameCmp(name, "keyboard")) {
            strcpy(name, "kbd");
        }

        if (optlist)
            opt = optlist[i];
        else
            opt = null;

        if (!LoadModule(name, opt, null, &errmaj)) {
            LoaderErrorMsg(null, name, errmaj, 0);
            failed = TRUE;
        }
        free(name);
    }
    return !failed;
}

/* Pixmap format stuff */

PixmapFormatPtr xf86GetPixFormat(ScrnInfoPtr pScrn, int depth)
{
    int i = void;

    for (i = 0; i < numFormats; i++)
        if (formats[i].depth == depth)
            break;
    if (i != numFormats)
        return cast(_PixmapFormat*)&formats[i];
    else if (!formatsDone) {
        /* Check for screen-specified formats */
        for (i = 0; i < pScrn.numFormats; i++)
            if (pScrn.formats[i].depth == depth)
                break;
        if (i != pScrn.numFormats)
            return cast(_PixmapFormat*)&pScrn.formats[i];
    }
    return null;
}

int xf86GetBppFromDepth(ScrnInfoPtr pScrn, int depth)
{
    PixmapFormatPtr format = void;

    format = xf86GetPixFormat(pScrn, depth);
    if (format)
        return format.bitsPerPixel;
    else
        return 0;
}

static if (INPUTTHREAD) {
/** This function is called in Xserver/os/inputthread.c when starting
    the input thread. */
void ddxInputThreadInit()
{
    xf86OSInputThreadInit();
}
}
