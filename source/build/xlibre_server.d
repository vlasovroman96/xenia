module build.xlibre_server;
@nogc nothrow:
extern(C): __gshared:
/* xorg-server.h.in						-*- c -*-
 *
 * This file is the template file for the xorg-server.h file which gets
 * installed as part of the SDK.  The #defines in this file overlap
 * with those from config.h, but only for those options that we want
 * to export to external modules.  Boilerplate autotool #defines such
 * as HAVE_STUFF and PACKAGE_NAME is kept in config.h
 *
 * It is still possible to update config.h.in using autoheader, since
 * autoheader only creates a .h.in file for the first
 * AM_CONFIG_HEADER() line, and thus does not overwrite this file.
 *
 * However, it should be kept in sync with this file.
 */

 import build.dix_config;
version (HAVE_XORG_CONFIG_H) {
static assert(0, "Include xorg-config.h when building the X server");
}

/* Default font path */
enum COMPILEDDEFAULTFONTPATH = "/usr/share/fonts/misc,/usr/share/fonts/TTF,/usr/share/fonts/OTF,/usr/share/fonts/Type1,/usr/share/fonts/100dpi,/usr/share/fonts/75dpi";

/* Support Composite Extension */
enum COMPOSITE = 0;

/* Build DPMS extension */
enum DPMSExtension = 0;

/* Build DRI3 extension */
enum DRI3 = 1;

/* Build GLX extension */
// version = GLXEXT;

/* Support XDM-AUTH*-1 */
enum HASXDMAUTH = 1;

enum GLXEXT = 1;
/* Add a padding for legacy nvidia drivers that support old ABI */
/* Define to 1 if you have the `reallocarray' function. */
enum HAVE_REALLOCARRAY = 0;

/* Define to 1 if you have the `strcasestr' function. */
enum HAVE_STRCASESTR = 0;

/* Define to 1 if you have the `strlcat' function. */
enum HAVE_STRLCAT = 1;

/* Define to 1 if you have the `strlcpy' function. */
enum HAVE_STRLCPY = 0;

/* Define to 1 if you have the `strndup' function. */
enum HAVE_STRNDUP = 0;

/* Support IPv6 for TCP connections */
enum IPv6 = 1;

/* Support MIT-SHM Extension */
enum MITSHM = 1;
enum CONFIG_MITSHM = 1;

/* Internal define for Xinerama */
enum PANORAMIX = 1;
// enum XINERAMA = 1;

/* Support Present extension */
enum PRESENT = 1;

/* Support RANDR extension */
enum RANDR = 1;

/* Support RENDER extension */
enum RENDER = 1;

/* Support X resource extension */
enum RES = 1;

/* Support MIT-SCREEN-SAVER extension */
enum SCREENSAVER = 1;

/* Support SHAPE extension */
enum SHAPE = 1;

/* Define to 1 on systems derived from System V Release 4 */
/* Support UNIX socket connections */
enum UNIXCONN = 1;

/* Support XCMisc extension */
enum XCMISC = 1;

/* Support Xdmcp */
enum XDMCP = 1;

/* Build XFree86 BigFont extension */
/* Support XFree86 Video Mode extension */
enum XF86VIDMODE = 1;

/* Build XDGA support */
enum XFreeXDGA = 1;

/* Support Xinerama extension */
enum XINERAMA = 1;

/* Support X Input extension */
enum XINPUT = 1;

/* XKB default rules */
enum XKB_DFLT_RULES = "evdev";

/* Build DRI extension */
enum XF86DRI = 1;

/* Build DRI2 extension */
enum DRI2 = 1;

/* Build Xorg server */
enum XORGSERVER = 1;

/* Current Xorg version */
enum XORG_VERSION_CURRENT = 12501000;

/* Build Xv Extension */
enum XvExtension = 1;

/* Build XvMC Extension */
enum XvMCExtension = 1;

/* Support XSync extension */
enum XSYNC = 1;

/* Support XTest extension */
enum XTEST = 0;

/* Support Xv Extension */
enum XV = 1;

/* BSD-compliant source */
/* #undef _BSD_SOURCE */

/* POSIX-compliant source */
/* #undef _POSIX_SOURCE */

/* X/Open-compliant source */
/* #undef _XOPEN_SOURCE */

/* Location of configuration file */
enum XCONFIGFILE = "xorg.conf";

/* Name of X server */
enum __XSERVERNAME__ = "Xorg";

/* Building vgahw module */
enum WITH_VGAHW = 1;

/* System is BSD-like */
/* System has PCVT console */
/* System has syscons console */
/* System has wscons console */
/* Loadable XFree86 server awesomeness */
version = XFree86LOADER;

/* Use libpciaccess */
enum XSERVER_LIBPCIACCESS = 1;

/* X Access Control Extension */
enum XACE = 1;

/* Have X server platform bus support */
enum XSERVER_PLATFORM_BUS = 1;
enum PCI_TXT_IDS_PATH = "";


version (_LP64) {
enum _XSERVER64 = 1;
}

/* Have support for X shared memory fence library (xshmfence) */
enum HAVE_XSHMFENCE = 1;
enum SHM_FD_PASSING = 1;
/* Use XTrans FD passing support */
enum XTRANS_SEND_FDS = 0;

/* Ask fontsproto to make font path element names const */
enum FONT_PATH_ELEMENT_NAME_CONST =    1;

/* byte order */
enum X_BYTE_ORDER = X_LITTLE_ENDIAN;

/* maximum number of clients */
enum MAXCLIENTS = 2048;

/* announce server API features */
enum XORG_API_DIX_SCREEN_HOOK_WINDOW_DESTROY = 1;
enum XORG_API_DIX_SCREEN_HOOK_WINDOW_POSITION = 1;
enum XORG_API_DIX_SCREEN_HOOK_CLOSE = 1;
enum XORG_API_DIX_SCREEN_HOOK_PIXMAP_DESTROY = 1;

/* needed for os.h to prevent redefinition of timingsafe_memcmp in drivers */
/* Xserver has xf86ParseEDID() et al (since 25.2) */
enum XLIBRE_API_EDID_PARSE_v1 = 1;

 /* _XORG_SERVER_H_ */
