module lnx_agp;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Abstraction of the AGP GART interface.
 *
 * This version is for Linux and Free/Open/NetBSD.
 *
 * Copyright © 2000 VA Linux Systems, Inc.
 * Copyright © 2001 The XFree86 Project, Inc.
 */
import build.xorg_config;

import core.stdc.errno;
//import x11.X;

import hw.xfree86.common.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSlib;

version (linux) {
import externs.c_asm.ioctl;
import externs.linux.agpgart;
} 
static if (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__" || HasVersion!"__NetBSD__" || HasVersion!"__OpenBSD__" || HasVersion!"__DragonFly__") {
import core.sys.posix.sys.ioctl;
import core.sys.posix.unistd;

import sys.agpio;
}

import os.log;
import core.sys.posix.sys.ioctl;

import xf86Events;
import core.sys.posix.unistd;

import xf86Globals;
import hw.xfree86.common.xf86Helper;;
import os.log;
import xf86Globals;
import dix.events;
public import xf86Configure;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.stdc.errno;

import os.log_priv;

import os.os;
import xf86_priv;
import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSproc;;

import os.log;
import xf86Events;
import xf86Globals;
import externs.linux.agpgart;

enum AGPIOC_INFO = 0x40004100;
enum AGPIOC_ACQUIRE = 0x00004101;
enum AGPIOC_RELEASE = 0x00004102;
enum AGPIOC_ALLOCATE = 0x40104106;
enum AGPIOC_DEALLOCATE = 0x40104107;
enum AGPIOC_BIND = 0x40104108;
enum AGPIOC_UNBIND = 0x40084109;

alias TRUE = common.misc.TRUE;

enum AGP_DEVICE =		"/dev/agpgart";

/* AGP page size is independent of the host page size. */
enum AGP_PAGE_SIZE =		4096;

enum AGPGART_MAJOR_VERSION =	0;
enum AGPGART_MINOR_VERSION =	99;

alias FALSE = common.misc.FALSE;

private int gartFd = -1;
private int acquiredScreen = -1;
private Bool initDone = FALSE;

/*
 * Close /dev/agpgart.  This frees all associated memory allocated during
 * this server generation.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86GARTCloseScreen(int screenNum)
{
    if (gartFd != -1) {
        close(gartFd);
        acquiredScreen = -1;
        gartFd = -1;
        initDone = FALSE;
    }
    return TRUE;
}

/*
 * Open /dev/agpgart.  Keep it open until xf86GARTCloseScreen is called.
 */
static Bool
GARTInit(int screenNum)
{
    _agp_info agpinf;

    if (initDone)
        return gartFd != -1;

    initDone = TRUE;

    if (gartFd == -1)
        gartFd = open(AGP_DEVICE, O_RDWR, 0);
    else
        return FALSE;

    if (gartFd == -1) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "GARTInit: Unable to open " ~ AGP_DEVICE ~ " (%s)\n",
                   strerror(errno));
        return FALSE;
    }

    xf86AcquireGART(-1);
    /* Check the kernel driver version. */
    if (ioctl(gartFd, AGPIOC_INFO, &agpinf) != 0) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "GARTInit: AGPIOC_INFO failed (%s)\n", strerror(errno));
        close(gartFd);
        gartFd = -1;
        return FALSE;
    }
    xf86ReleaseGART(-1);

static if(HasVersion!"linux") {
    /* Per Dave Jones, every effort will be made to keep the
     * agpgart interface backwards compatible, so allow all
     * future versions.
     */
     bool cond = (agpinf.version_.major == AGPGART_MAJOR_VERSION &&
            agpinf.version_.minor < AGPGART_MINOR_VERSION);
    static if((AGPGART_MAJOR_VERSION > 0)) {
        cond = cond || agpinf.version_.major < AGPGART_MAJOR_VERSION;
    }
    if (cond) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "GARTInit: Kernel agpgart driver version is not current"
                   ~ " (%d.%d vs %d.%d)\n",
                   agpinf.version_.major, agpinf.version_.minor,
                   AGPGART_MAJOR_VERSION, AGPGART_MINOR_VERSION);
        close(gartFd);
        gartFd = -1;
        return FALSE;
    }
}

    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86AgpGARTSupported()
{
    return GARTInit(-1);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
AgpInfoPtr xf86GetAGPInfo(int screenNum)
{
    _agp_info agpinf = void;
    AgpInfoPtr info = void;

    if (!GARTInit(screenNum))
        return null;

    if ((info = cast(AgpInfo*) calloc(1, AgpInfo.sizeof)) is null) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "xf86GetAGPInfo: Failed to allocate AgpInfo\n");
        return null;
    }

    memset(cast(char*) &agpinf, 0, agpinf.sizeof);

    if (ioctl(gartFd, AGPIOC_INFO, &agpinf) != 0) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "xf86GetAGPInfo: AGPIOC_INFO failed (%s)\n",
                   strerror(errno));
        free(info);
        return null;
    }

    info.bridgeId = agpinf.bridge_id;
    info.agpMode = agpinf.agp_mode;
    info.base = agpinf.aper_base;
    info.size = agpinf.aper_size;
    info.totalPages = agpinf.pg_total;
    info.systemPages = agpinf.pg_system;
    info.usedPages = agpinf.pg_used;

    xf86DrvMsg(screenNum, X_INFO, "Kernel reported %zu total, %zu used\n",
               agpinf.pg_total, agpinf.pg_used);

    return info;
}

/*
 * XXX If multiple screens can acquire the GART, should we have a reference
 * count instead of using acquiredScreen?
 */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86AcquireGART(int screenNum)
{
    if (screenNum != -1 && !GARTInit(screenNum))
        return FALSE;

    if (screenNum == -1 || acquiredScreen != screenNum) {
        if (ioctl(gartFd, AGPIOC_ACQUIRE, 0) != 0) {
            xf86DrvMsg(screenNum, X_WARNING,
                       "xf86AcquireGART: AGPIOC_ACQUIRE failed (%s)\n",
                       strerror(errno));
            return FALSE;
        }
        acquiredScreen = screenNum;
    }
    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86ReleaseGART(int screenNum)
{
    if (screenNum != -1 && !GARTInit(screenNum))
        return FALSE;

    if (acquiredScreen == screenNum) {
        /*
         * The FreeBSD agp driver removes allocations on release.
         * The Linux driver doesn't.  xf86ReleaseGART() is expected
         * to give up access to the GART, but not to remove any
         * allocations.
         */
static if (!HasVersion!"linux") {
        if (screenNum == -1)
        {
            if (ioctl(gartFd, AGPIOC_RELEASE, 0) != 0) {
                xf86DrvMsg(screenNum, X_WARNING,
                           "xf86ReleaseGART: AGPIOC_RELEASE failed (%s)\n",
                           strerror(errno));
                return FALSE;
            }
            acquiredScreen = -1;
        }
        return TRUE;
}
else
        {
            if (ioctl(gartFd, AGPIOC_RELEASE, 0) != 0) {
                xf86DrvMsg(screenNum, X_WARNING,
                           "xf86ReleaseGART: AGPIOC_RELEASE failed (%s)\n",
                           strerror(errno));
                return FALSE;
            }
            acquiredScreen = -1;
        }
        return TRUE;
    }
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86AllocateGARTMemory(int screenNum, c_ulong size, int type, c_ulong* physical)
{
    _agp_allocate alloc = void;
    int pages = void;

    /*
     * Allocates "size" bytes of GART memory (rounds up to the next
     * page multiple) or type "type".  A handle (key) for the allocated
     * memory is returned.  On error, the return value is -1.
     */

    if (!GARTInit(screenNum) || acquiredScreen != screenNum)
        return -1;

    pages = cast(int)(size / AGP_PAGE_SIZE);
    if (size % AGP_PAGE_SIZE != 0)
        pages++;

    /* XXX check for pages == 0? */

    alloc.pg_count = pages;
    alloc.type = type;

    if (ioctl(gartFd, AGPIOC_ALLOCATE, &alloc) != 0) {
        xf86DrvMsg(screenNum, X_WARNING, "xf86AllocateGARTMemory: "
                   ~ "allocation of %d pages failed\n\t(%s)\n", pages,
                   strerror(errno));
        return -1;
    }

    if (physical)
        *physical = alloc.physical;

    return alloc.key;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86DeallocateGARTMemory(int screenNum, int key)
{
    if (!GARTInit(screenNum) || acquiredScreen != screenNum)
        return FALSE;

    if (acquiredScreen != screenNum) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "xf86UnbindGARTMemory: AGP not acquired by this screen\n");
        return FALSE;
    }

version (linux) {
    if (ioctl(gartFd, AGPIOC_DEALLOCATE, cast(int*) cast(uintptr_t) key) != 0) {
//! #else
    if (ioctl(gartFd, AGPIOC_DEALLOCATE, &key) != 0) {
//! #endif
        xf86DrvMsg(screenNum, X_WARNING, "xf86DeAllocateGARTMemory: "~
                   "deallocation gart memory with key %d failed\n\t(%s)\n",
                   key, strerror(errno));
        return FALSE;
    }

    return TRUE;
    }
    assert(0);
}

/* Bind GART memory with "key" at "offset" */
Bool xf86BindGARTMemory(int screenNum, int key, c_ulong offset)
{
    _agp_bind bind = void;
    int pageOffset = void;

    if (!GARTInit(screenNum) || acquiredScreen != screenNum)
        return FALSE;

    if (acquiredScreen != screenNum) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "xf86BindGARTMemory: AGP not acquired by this screen\n");
        return FALSE;
    }

    if (offset % AGP_PAGE_SIZE != 0) {
        xf86DrvMsg(screenNum, X_WARNING, "xf86BindGARTMemory: "
                   ~ "offset (0x%lx) is not page-aligned (%d)\n",
                   offset, AGP_PAGE_SIZE);
        return FALSE;
    }
    pageOffset = cast(int)(offset / AGP_PAGE_SIZE);

    xf86DrvMsgVerb(screenNum, X_INFO, 3,
                   "xf86BindGARTMemory: bind key %d at 0x%08lx "
                   ~ "(pgoffset %d)\n", key, offset, pageOffset);

    bind.pg_start = pageOffset;
    bind.key = key;

    if (ioctl(gartFd, AGPIOC_BIND, &bind) != 0) {
        xf86DrvMsg(screenNum, X_WARNING, "xf86BindGARTMemory: "
                   ~ "binding of gart memory with key %d\n"
                   ~ "\tat offset 0x%lx failed (%s)\n",
                   key, offset, strerror(errno));
        return FALSE;
    }

    return TRUE;
}

/* Unbind GART memory with "key" */
Bool xf86UnbindGARTMemory(int screenNum, int key)
{
    _agp_unbind unbind = void;

    if (!GARTInit(screenNum) || acquiredScreen != screenNum)
        return FALSE;

    if (acquiredScreen != screenNum) {
        xf86DrvMsg(screenNum, X_ERROR,
                   "xf86UnbindGARTMemory: AGP not acquired by this screen\n");
        return FALSE;
    }

    unbind.priority = 0;
    unbind.key = key;

    if (ioctl(gartFd, AGPIOC_UNBIND, &unbind) != 0) {
        xf86DrvMsg(screenNum, X_WARNING, "xf86UnbindGARTMemory: "
                   ~ "unbinding of gart memory with key %d "
                   ~ "failed (%s)\n", key, strerror(errno));
        return FALSE;
    }

    xf86DrvMsgVerb(screenNum, X_INFO, 3,
                   "xf86UnbindGARTMemory: unbind key %d\n", key);

    return TRUE;
}
}
