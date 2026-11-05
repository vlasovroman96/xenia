module hw.xfree86.common.xf86Priv;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}

/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
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

/*
 * This file contains definitions of the private XFree86 data structures/types.
 * None of the data structures here should be used by video drivers.
 */

 
public import include.xf86str;
import x11.Xosdefs;

enum DEFAULT_DPI =		96;

enum XF86_GlxVisuals {
    XF86_GlxVisualsMinimal,
    XF86_GlxVisualsTypical,
    XF86_GlxVisualsAll,
}
alias XF86_GlxVisualsMinimal = XF86_GlxVisuals.XF86_GlxVisualsMinimal;
alias XF86_GlxVisualsTypical = XF86_GlxVisuals.XF86_GlxVisualsTypical;
alias XF86_GlxVisualsAll = XF86_GlxVisuals.XF86_GlxVisualsAll;


/*
 * xf86InfoRec contains global parameters which the video drivers never
 * need to access.  Global parameters which the video drivers do need
 * should be individual globals.
 */

struct _Xf86InfoRec {
    int consoleFd;
    int vtno;

    /* event handler part */
    int lastEventTime;
    Bool vtRequestsPending;
version (__sun) {
    int vtPendingNum;
}
    Bool dontVTSwitch;
    Bool autoVTSwitch;
    Bool ShareVTs;
    Bool dontZap;
    Bool dontZoom;

    /* graphics part */
    ScreenPtr currentScreen;
static if (CSRG_BASED || HasVersion!"__FreeBSD_kernel__") {
    int consType;               /* Which console driver? */
}

    /* Other things */
    Bool allowMouseOpenFail;
    Bool vidModeEnabled;        /* VidMode extension enabled */
    Bool vidModeAllowNonLocal;  /* allow non-local VidMode
                                 * connections */
    Bool pmFlag;
    MessageType iglxFrom;
    XF86_GlxVisuals glxVisuals;
    MessageType glxVisualsFrom;

    Bool useDefaultFontPath;
    Bool ignoreABI;

    Bool forceInputDevices;     /* force xorg.conf or built-in input devices */
    Bool autoAddDevices;        /* Whether to succeed NIDR, or ignore. */
    Bool autoEnableDevices;     /* Whether to enable, or let the client
                                 * control. */

    Bool dri2;
    MessageType dri2From;

    Bool autoAddGPU;
    const(char)* debug_;
    Bool autoBindGPU;

    Bool singleDriver;          /* Only the first successfully probed driver adds primary screens,
                                 * others may add GPU secondary screens only */
}alias xf86InfoRec = _Xf86InfoRec;
alias xf86InfoPtr = xf86InfoRec*;

/* ISC's cc can't handle ~ of UL constants, so explicitly type cast them. */
enum XLED1 =   cast(ulong) 0x00000001;
enum XLED2 =   cast(ulong) 0x00000002;
enum XLED3 =   cast(ulong) 0x00000004;
enum XLED4 =	cast(ulong) 0x00000008;
enum XCAPS =   cast(ulong) 0x20000000;
enum XNUM =    cast(ulong) 0x40000000;
enum XSCR =    cast(ulong) 0x80000000;
enum XCOMP =	cast(ulong) 0x00008000;

/* BSD console driver types (consType) */
static if (CSRG_BASED || HasVersion!"__FreeBSD_kernel__") {
enum PCCONS =		   0;
enum CODRV011 =	   1;
enum CODRV01X =	   2;
enum SYSCONS =		   8;
enum PCVT =		  16;
enum WSCONS =		  32;
}

/* Root window property to tell clients whether our VT is currently active.
 * Name chosen to match the "XFree86_VT" property. */
enum HAS_VT_ATOM_NAME = "XFree86_has_VT";

                          /* _XF86PRIVSTR_H */
