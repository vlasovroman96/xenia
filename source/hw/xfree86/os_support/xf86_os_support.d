module hw.xfree86.os_support.xf86_os_support;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

/* prototypes for the os-support layer of xfree86 DDX */

 
//public import x11.Xdefs;

public import os.os;
public import dix.dix_priv;
public import build.xlibre_server;
import config.hotplug_priv;
/*
 * This is to prevent re-entrancy to FatalError() when aborting.
 * Anything that can be called as a result of ddxGiveUp() should use this
 * instead of FatalError().
 */

enum string xf86FatalError(string a, string b) = `
	if (dispatchException & DE_TERMINATE) { 
		ErrorF(` ~ a ~ `, ` ~ b ~ `); 
		ErrorF("\n"); 
		return; 
	} else FatalError(` ~ a ~ `, ` ~ b ~ `)`;

alias PMClose = void function();

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86OpenConsole();
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86CloseConsole();

/**
 * @brief get keeptty switch state
 **/
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTKeepTtyIsSet();

Bool xf86VTActivate(int vtno);
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchPending();
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchAway();
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchTo();
void xf86VTRequest(int sig);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86ProcessArgument(int argc, char** argv, int i);
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86UseMsg();
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
PMClose xf86OSPMOpen();
void xf86InitVidMem();

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86OSRingBell(int volume, int pitch, int duration);
void xf86OSInputThreadInit();
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86DeallocateGARTMemory(int screenNum, int key);
// int xf86RemoveSIGIOHandler(int fd);

struct _VidMemInfo {
    Bool initialised;
}alias VidMemInfo = _VidMemInfo;
alias VidMemInfoPtr = VidMemInfo*;

void xf86OSInitVidMem(VidMemInfoPtr);

static if(XSERVER_PLATFORM_BUS){
// struct OdevAttributes;

// void xf86PlatformDeviceProbe(OdevAttributes* attribs);

// void xf86PlatformReprobeDevice(int index, OdevAttributes* attribs);
}

version (__sun) {
char[PATH_MAX] xf86SolarisFbDev = 0;

/* these are only used inside sun-specific os-support */
void xf86VTAcquire(int);
void xf86VTRelease(int);
}

 /* _XSERVER_XF86_OS_SUPPORT */
