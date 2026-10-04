module os.utils;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts,
Copyright 1994 Quarterdeck Office Systems.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital and
Quarterdeck not be used in advertising or publicity pertaining to
distribution of the software without specific, written prior
permission.

DIGITAL AND QUARTERDECK DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS, IN NO EVENT SHALL DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT
OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
OR PERFORMANCE OF THIS SOFTWARE.

*/

import build.dix_config;
import hw.xfree86.i2c.xf86i2c;
import os.access;
import externs.X11.fonts.libxfont2;
import externs.attrs;
import os.osinit;
import os.Xtransutil;
import Xext.xtest;
import render.picture;
version (Cygwin) {
import core.stdc.stdlib;
import core.stdc.signal;
import os.Xtrans;
/*
   Sigh... We really need a prototype for this to know it is stdcall,
   but #include-ing <windows.h> here is not a good idea...
*/
ulong GetTickCount(){}
}

static if (HasVersion!"Windows" && !HasVersion!"Cygwin") {
//import externs.X11.Xwinsock;
}
// //import x11.Xos;
import core.stdc.stdio;
import core.stdc.time;
static if (!HasVersion!"Windows" || !HasVersion!"Windows") {
import core.sys.posix.sys.time;
import core.sys.posix.sys.resource;
}
import include.misc;
//import x11.X;
import os.Xtrans;

import core.sys.posix.libgen;

import include.input;
import include.dixfont;
// //import externs.X11.fonts.libxfont2;
import os.osdep;

static if(build.xlibre_server.XDMCP){
import os.xdmcp;
}

import include.extension;
import core.stdc.signal;
version (Windows) {} else {
import core.sys.posix.sys.wait;
}
static if (!HasVersion!"Windows") {
import core.sys.posix.sys.resource;
}
import core.sys.posix.sys.stat;
import core.stdc.ctype;              /* for isspace */
import core.stdc.stdarg;
import core.stdc.stdlib;             /* for calloc() */

version (Windows) {} else {
import core.sys.posix.netdb;
}

import dix.dix_priv;
import dix.input_priv;
import dix.settings_priv;
import dix.screensaver_priv;
import miext.extinit_priv;
import os.audit_priv;
import os.auth;
import os.bug_priv;
import os.cmdline;
import os.client_priv;
import os.ddx_priv;
import os.log_priv;
import os.osdep;
import os.serverlock;
import os.xhostname;
import present.present_priv;
import Xext.xf86bigfontsrv; /* XF86BigfontCleanup() */
import xkb.xkbsrv_priv;

import include.dixstruct;
// import include.picture;
import mi.miinitext;
import dix.dixstruct_priv;
import Xext.dpmsproc;
import core.sys.posix.fcntl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.sys.posix.stdio;
import build.xlibre_server;
import core.stdc.stdio;
// import core.sys.posix.stdio;
import os.connection;
import x11.Xos;

version = X_INCLUDE_NETDB_H;
// //import x11.Xos_r;

import core.stdc.errno;
import Xext.dpms;
import std.stdio;
import core.stdc.stdio;

alias timeval = core.sys.posix.sys.time.timeval;
alias fopen = core.stdc.stdio.fopen;

// Bool CoreDump;

Bool enableIndirectGLX = FALSE;

static if(XINERAMA){
Bool PanoramiXExtensionDisabledHack = FALSE;
} /* XINERAMA */

sig_atomic_t inSignalContext = FALSE;

version (MONOTONIC_CLOCK) {
private clockid_t clockid;
}

OsSigHandlerPtr OsSignal(int sig, OsSigHandlerPtr handler)
{
static if (HasVersion!"Windows" && !HasVersion!"Cygwin") {
    return signal(sig, handler);
} else {
    sigaction_t act = void, oact = void;

    sigemptyset(&act.sa_mask);
    if (handler != SIG_IGN)
        sigaddset(&act.sa_mask, sig);
    act.sa_flags = 0;
    act.sa_handler = handler;
    if (sigaction(sig, &act, &oact))
        perror("sigaction");
    return assumeNoGC(oact.sa_handler);
}
}

/* Force connections to close and then exit on SIGTERM, SIGINT */

void GiveUp(int sig)
{
    int olderrno = errno;

    dispatchException |= DE_TERMINATE;
    isItTimeToYield = TRUE;
    errno = olderrno;
}

version (MONOTONIC_CLOCK) {
void ForceClockId(clockid_t forced_clockid)
{
    timespec tp = void;

    BUG_RETURN (clockid);

    clockid = forced_clockid;

    if (clock_gettime(clockid, &tp) != 0) {
        FatalError("Forced clock id failed to retrieve current time: %s\n",
                   strerror(errno));
        return;
    }
}
}

static if ((HasVersion!"Windows" && HasVersion!"Windows") || HasVersion!"Cygwin") {
CARD32 GetTimeInMillis()
{
    return GetTickCount();
}
CARD64 GetTimeInMicros()
{
    return cast(CARD64) GetTickCount() * 1000;
}
} else {
CARD32 GetTimeInMillis()
{
    timeval tv = void;

version (MONOTONIC_CLOCK) {
    timespec tp = void;

    if (!clockid) {
version (CLOCK_MONOTONIC_COARSE) {
        if (clock_getres(CLOCK_MONOTONIC_COARSE, &tp) == 0 &&
            (tp.tv_nsec / 1000) <= 1000 &&
            clock_gettime(CLOCK_MONOTONIC_COARSE, &tp) == 0)
            clockid = CLOCK_MONOTONIC_COARSE;
        // else
}
        if (clock_gettime(CLOCK_MONOTONIC, &tp) == 0)
            clockid = CLOCK_MONOTONIC;
        else
            clockid = ~0L;
    }
    if (clockid != ~0L && clock_gettime(clockid, &tp) == 0)
        return (tp.tv_sec * 1000) + (tp.tv_nsec / 1000000L);
}

    X_GETTIMEOFDAY(&tv);
    return cast(uint)((tv.tv_sec * 1000) + (tv.tv_usec / 1000));
}

CARD64 GetTimeInMicros()
{
    timeval tv = void;
version (MONOTONIC_CLOCK) {
    timespec tp = void;
    static clockid_t uclockid;

    if (!uclockid) {
        if (clock_gettime(CLOCK_MONOTONIC, &tp) == 0)
            uclockid = CLOCK_MONOTONIC;
        else
            uclockid = ~0L;
    }
    if (uclockid != ~0L && clock_gettime(uclockid, &tp) == 0)
        return cast(CARD64) tp.tv_sec * cast(CARD64)1000000 + tp.tv_nsec / 1000;
}

    X_GETTIMEOFDAY(&tv);
    return cast(CARD64) tv.tv_sec * cast(CARD64)1000000 + cast(CARD64) tv.tv_usec;
}
}

void UseMsg()
{
    ErrorF("use: X [:<display>] [option]\n");
    ErrorF("-a #                   default pointer acceleration (factor)\n");
    ErrorF("-ac                    disable access control restrictions\n");
    ErrorF("-audit int             set audit trail level\n");
    ErrorF("-auth file             select authorization file\n");
    ErrorF("-br                    create root window with black background\n");
    ErrorF("+bs                    enable any backing store support\n");
    ErrorF("-bs                    disable any backing store support\n");
    ErrorF("+byteswappedclients    Allow clients with endianness different to that of the server\n");
    ErrorF("-byteswappedclients    Prohibit clients with endianness different to that of the server\n");
    ErrorF("-c                     turns off key-click\n");
    ErrorF("c #                    key-click volume (0-100)\n");
    ErrorF("-cc int                default color visual class\n");
    ErrorF("-nocursor              disable the cursor\n");
    ErrorF("-core                  generate core dump on fatal error\n");
    ErrorF("-displayfd fd          file descriptor to write display number to when ready to connect\n");
    ErrorF("-dpi int               screen resolution in dots per inch\n");
static if(DPMSExtension) {
    ErrorF("-dpms                  disables VESA DPMS monitor control\n");
}
    ErrorF
        ("-deferglyphs [none|all|16] defer loading of [no|all|16-bit] glyphs\n");
    ErrorF("-f #                   bell base (0-100)\n");
    ErrorF("-fakescreenfps #       fake screen default fps (1-600)\n");
    ErrorF("-fp string             default font path\n");
    ErrorF("-help                  prints message with these options\n");
    ErrorF("+iglx                  Allow creating indirect GLX contexts\n");
    ErrorF("-iglx                  Prohibit creating indirect GLX contexts (default)\n");
    ErrorF("-I                     ignore all remaining arguments\n");
version (CONFIG_NAMESPACE) {
    ErrorF("-namespace <conf>      Enable NAMESPACE extension with given config file\n");
} /* CONFIG_NAMESPACE */
    LockServerUseMsg();
    ErrorF("-maxclients n          set maximum number of clients (power of two)\n");
    ErrorF("-nolisten string       don't listen on protocol\n");
    ErrorF("-listen string         listen on protocol\n");
    ErrorF("-background [none]     create root window with no background\n");
    ErrorF("-p #                   screen-saver pattern duration (minutes)\n");
    ErrorF("-pn                    accept failure to listen on all ports\n");
    ErrorF("-nopn                  reject failure to listen on all ports\n");
    ErrorF("-r                     turns off auto-repeat\n");
    ErrorF("r                      turns on auto-repeat \n");
    ErrorF("-render [default|mono|gray|color] set render color alloc policy\n");
    ErrorF("-retro                 start with classic stipple and cursor\n");
    ErrorF("-s #                   screen-saver timeout (minutes)\n");
    ErrorF("-seat string           seat to run on\n");
    ErrorF("-t #                   default pointer threshold (pixels/t)\n");
    ErrorF("-terminate [delay]     terminate at server reset (optional delay in sec)\n");
    ErrorF("-tst                   disable testing extensions\n");
    ErrorF("ttyxx                  server started from init on /dev/ttyxx\n");
    ErrorF("v                      video blanking for screen-saver\n");
    ErrorF("-v                     screen-saver without video blanking\n");
    ErrorF("-verbose [n]           verbose startup messages\n");
    ErrorF("-wr                    create root window with white background\n");
    ErrorF("-maxbigreqsize         set maximal bigrequest size \n");
static if(XINERAMA){
    ErrorF("+xinerama              Enable XINERAMA extension\n");
    ErrorF("-xinerama              Disable XINERAMA extension\n");
} /* XINERAMA */
    ErrorF("-dumbSched             Disable smart scheduling and threaded input, enable old behavior\n");
    ErrorF("-schedInterval int     Set scheduler interval in msec\n");
    ErrorF("+extension name        Enable extension\n");
    ErrorF("-extension name        Disable extension\n");
    ListStaticExtensions();
static if(build.dix_config.XDMCP){
    XdmcpUseMsg();
}
    XkbUseMsg();
    ddxUseMsg();
}

/*  This function performs a rudimentary sanity check
 *  on the display name passed in on the command-line,
 *  since this string is used to generate filenames.
 *  It is especially important that the display name
 *  not contain a "/" and not start with a "-".
 *                                            --kvajk
 */
private int VerifyDisplayName(const(char)* d)
{
    uint i = void;
    int period_found = FALSE;
    int after_period = 0;

    if (d == cast(char*) 0)
        return 0;               /*  null  */
    if (*d == '\0')
        return 0;               /*  empty  */
    if (*d == '-')
        return 0;               /*  could be confused for an option  */
    if (*d == '.')
        return 0;               /*  must not equal "." or ".."  */
    if (strchr(d, '/') != cast(char*) 0)
        return 0;               /*  very important!!!  */

    /* Since we run atoi() on the display later, only allow
       for digits, or exception of :0.0 and similar (two decimal points max)
       */
    for (i = 0; i < strlen(d); i++) {
        if (!isdigit(cast(ubyte)d[i])) {
            if (d[i] != '.' || period_found)
                return 0;
            period_found = TRUE;
        } else if (period_found)
            after_period++;

        if (after_period > 2)
            return 0;
    }

    /* don't allow for :0. */
    if (period_found && after_period == 0)
        return 0;

    if (atol(d) > INT_MAX)
        return 0;

    return 1;
}

const(char)*[4] defaultNoListenList = [
// #ifndef LISTEN_TCP
    // "tcp",
// #endif
// #ifndef LISTEN_UNIX
    "unix",
// #endif
// #ifndef LISTEN_LOCAL
    "local",
// #endif
    null
];

/*
 * This function parses the command line. Handles device-independent fields
 * and allows ddx to handle additional fields.  It is not allowed to modify
 * argc or any of the strings pointed to by argv.
 */
void ProcessCommandLine(int argc, char** argv)
{
    int i = void, skip = void;
    int verbosity = 0;

    defaultKeyboardControl.autoRepeat = TRUE;

    PartialNetwork = TRUE;

    for (i = 0; defaultNoListenList[i] !is null; i++) {
        if (_XSERVTransNoListen(defaultNoListenList[i]))
                    ErrorF("Failed to disable listen for %s transport",
                           defaultNoListenList[i]);
    }
    dixSettingSeatId = getenv("XDG_SEAT");

version (CONFIG_SYSLOG) {
    xorgSyslogIdent = getenv("SYSLOG_IDENT");
    if (!xorgSyslogIdent)
        xorgSyslogIdent = strdup(basename(argv[0]));
}

    for (i = 1; i < argc; i++) {
        /* call ddx first, so it can peek/override if it wants */
        if ((skip = ddxProcessArgument(argc, argv, i)) != 0) {
            i += (skip - 1);
        }
        else if (argv[i][0] == ':') {
            /* initialize display */
            display = argv[i];
            explicit_display = TRUE;
            display++;
            if (!VerifyDisplayName(display)) {
                ErrorF("Bad display name: %s\n", display);
                UseMsg();
                FatalError("Bad display name, exiting: %s\n", display);
            }
        }
        else if (strcmp(argv[i], "-a") == 0) {
            if (++i < argc)
                defaultPointerControl.num = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-ac") == 0) {
            defeatAccessControl = TRUE;
        }
        else if (strcmp(argv[i], "-audit") == 0) {
            if (++i < argc)
                auditTrailLevel = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-auth") == 0) {
            if (++i < argc)
                InitAuthorization(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-byteswappedclients") == 0) {
            dixSettingAllowByteSwappedClients = FALSE;
        } else if (strcmp(argv[i], "+byteswappedclients") == 0) {
            dixSettingAllowByteSwappedClients = TRUE;
        }
        else if (strcmp(argv[i], "-br") == 0){}  /* default */
        else if (strcmp(argv[i], "+bs") == 0)
            enableBackingStore = TRUE;
        else if (strcmp(argv[i], "-bs") == 0)
            disableBackingStore = TRUE;
        else if (strcmp(argv[i], "c") == 0) {
            if (++i < argc)
                defaultKeyboardControl.click = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-c") == 0) {
            defaultKeyboardControl.click = 0;
        }
        else if (strcmp(argv[i], "-cc") == 0) {
            if (++i < argc)
                defaultColorVisualClass = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-core") == 0) {
static if (!HasVersion!"Windows" || !HasVersion!"Windows") {
            rlimit core_limit = void;

            getrlimit(RLIMIT_CORE, &core_limit);
            core_limit.rlim_cur = core_limit.rlim_max;
            setrlimit(RLIMIT_CORE, &core_limit);
}
            CoreDump = TRUE;
        }
        else if (strcmp(argv[i], "-nocursor") == 0) {
            EnableCursor = FALSE;
        }
        else if (strcmp(argv[i], "-dpi") == 0) {
            if (++i < argc)
                monitorResolution = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-displayfd") == 0) {
            if (++i < argc) {
                displayfd = atoi(argv[i]);
                DisableServerLock();
            }
            else
                UseMsg();
        }
// static if(DPMSExtension) {
//         if(strcmp(argv[i], "dpms") == 0) {}

//         else if (strcmp(argv[i], "dpms") == 0)
//             DPMSDisabledSwitch = TRUE;
// }
        else if (strcmp(argv[i], "-deferglyphs") == 0) {
            if (++i >= argc || !assumeNoGC(&xfont2_parse_glyph_caching_mode)(argv[i]))
                UseMsg();
        }
        else if (strcmp(argv[i], "-f") == 0) {
            if (++i < argc)
                defaultKeyboardControl.bell = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-fakescreenfps") == 0) {
            if (++i < argc) {
                FakeScreenFps = cast(uint) atoi(argv[i]);
                if (FakeScreenFps < 1 || FakeScreenFps > 600)
                    FatalError("fakescreenfps must be an integer in [1;600] range\n");
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-fp") == 0) {
            if (++i < argc) {
                defaultFontPath = argv[i];
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-help") == 0) {
            UseMsg();
            exit(0);
        }
        else if (strcmp(argv[i], "+iglx") == 0)
            enableIndirectGLX = TRUE;
        else if (strcmp(argv[i], "-iglx") == 0)
            enableIndirectGLX = FALSE;
        else if ((skip = XkbProcessArguments(argc, argv, i)) != 0) {
            if (skip > 0)
                i += skip - 1;
            else
                UseMsg();
        }
// static if( LOCK_SERVER) {
//         if (strcmp && __CYGWIN__) {
//             if (getuid != 0)
//                 ErrorF
//                     ("Warning: the -nolock option can only be used by root\n");
//             else 
//                 DisableServerLock();
//         }
//     }

        else if ( strcmp( argv[i], "-maxclients") == 0)
        {
            if (++i < argc) {
                LimitClients = atoi(argv[i]);
                if (LimitClients != 64 &&
                    LimitClients != 128 &&
                    LimitClients != 256 &&
                    LimitClients != 512 &&
                    LimitClients != 1024 &&
                    LimitClients != 2048) {
                    FatalError("maxclients must be one of 64, 128, 256, 512, 1024 or 2048\n");
                }
            } else
                UseMsg();
        }
        else if (strcmp(argv[i], "-nolisten") == 0) {
            if (++i < argc) {
                if (_XSERVTransNoListen(argv[i]))
                    ErrorF("Failed to disable listen for %s transport",
                           argv[i]);
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-listen") == 0) {
            if (++i < argc) {
                if (_XSERVTransListen(argv[i]))
                    ErrorF("Failed to enable listen for %s transport",
                           argv[i]);
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i],"-noreset") == 0){
            ErrorF("Argument -noreset is removed in XLibre (for more context: https://github.com/orgs/X11Libre/discussions/424 )\n");
        }
        else if(strcmp(argv[i],"-reset") == 0){
            ErrorF("Argument -reset is removed in XLibre (for more context: https://github.com/orgs/X11Libre/discussions/424 )\n");
        }
        else if (strcmp(argv[i], "-p") == 0) {
            if (++i < argc)
                defaultScreenSaverInterval = (cast(CARD32) atoi(argv[i])) *
                    MILLI_PER_MIN;
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-pogo") == 0) {
            dispatchException = DE_TERMINATE;
        }
        else if (strcmp(argv[i], "-pn") == 0)
            PartialNetwork = TRUE;
        else if (strcmp(argv[i], "-nopn") == 0)
            PartialNetwork = FALSE;
        else if (strcmp(argv[i], "r") == 0)
            defaultKeyboardControl.autoRepeat = TRUE;
        else if (strcmp(argv[i], "-r") == 0)
            defaultKeyboardControl.autoRepeat = FALSE;
        else if (strcmp(argv[i], "-retro") == 0)
            party_like_its_1989 = TRUE;
        else if (strcmp(argv[i], "-s") == 0) {
            if (++i < argc)
                defaultScreenSaverTime = (cast(CARD32) atoi(argv[i])) *
                    MILLI_PER_MIN;
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-seat") == 0) {
            if (++i < argc)
                dixSettingSeatId = argv[i];
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-t") == 0) {
            if (++i < argc)
                defaultPointerControl.threshold = atoi(argv[i]);
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-terminate") == 0) {
            dispatchExceptionAtReset = DE_TERMINATE;
            terminateDelay = -1;
            if ((i + 1 < argc) && (isdigit(cast(ubyte)*argv[i + 1])))
               terminateDelay = atoi(argv[++i]);
            terminateDelay = max(0, terminateDelay);
        }
        else if (strcmp(argv[i], "-tst") == 0) {
            noTestExtensions = TRUE;
        }
        else if (strcmp(argv[i], "v") == 0)
            defaultScreenSaverBlanking = PreferBlanking;
        else if (strcmp(argv[i], "-v") == 0)
            defaultScreenSaverBlanking = DontPreferBlanking;
        else if (strcmp(argv[i], "-verbose") == 0) {
            int n = i + 1; /* next argument */
            verbosity++;
            if (n < argc && argv[n] && argv[n][0] != '-') {
                char* end;
                c_long val;

                val = strtol(argv[n], &end, 0);
                if (*end == '\0') {
                    verbosity = cast(int)val;
                    i = n;
                }
            }
            xorgLogVerbosity = verbosity;
        }
        else if (strcmp(argv[i], "-wr") == 0)
            whiteRoot = TRUE;
        else if (strcmp(argv[i], "-background") == 0) {
            if (++i < argc) {
                if (!strcmp(argv[i], "none"))
                    bgNoneRoot = TRUE;
                else
                    UseMsg();
            }
        }
        else if (strcmp(argv[i], "-maxbigreqsize") == 0) {
            if (++i < argc) {
                c_long reqSizeArg = atol(argv[i]);

                /* Request size > 128MB does not make much sense... */
                if (reqSizeArg > 0L && reqSizeArg < 128L) {
                    maxBigRequestSize = (reqSizeArg * 1048576L) - 1L;
                }
                else {
                    UseMsg();
                }
            }
            else {
                UseMsg();
            }
        }
// version (CONFIG_NAMESPACE) {
//         if (strcmp(argv[i], "-namespace") == 0) {
//             if (++i < argc) {
//                 namespaceConfigFile = argv[i];
//                 noNamespaceExtension = FALSE;
//             }
//             else
//                 UseMsg();
//         }
// }
// static if(XINERAMA){
//         if (strcmp(argv[i], "+xinerama") == 0) {
//             noPanoramiXExtension = FALSE;
//         }
//         else if (strcmp (argv[i], "-xinerama") == 0) {
//             noPanoramiXExtension = TRUE;
//         }
//         else if (strcmp(argv[i], "-disablexineramaextension") == 0) {
//             PanoramiXExtensionDisabledHack = TRUE;
//         }
// }// #endif /* XINERAMA */
        else if (strcmp(argv[i], "-I") == 0) {
            /* ignore all remaining arguments */
            break;
        }
        else if (strncmp(argv[i], "tty", 3) == 0) {
            /* init supplies us with this useless information */
        }
// version(XDMCP) {
//         if ((skip = XdmcpOptions(argc, argv, i)) != i) {
//             i = skip - 1;
//         }
// }
        else if (strcmp(argv[i], "-dumbSched") == 0) {
            InputThreadEnable = FALSE;
// version(HAVE_SETITIMER) {
//             SmartScheduleSignalEnable = FALSE;
// }

        }
        else if (strcmp(argv[i], "-schedInterval") == 0) {
            if (++i < argc) {
                SmartScheduleInterval = atoi(argv[i]);
                SmartScheduleSlice = SmartScheduleInterval;
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-schedMax") == 0) {
            if (++i < argc) {
                SmartScheduleMaxSlice = atoi(argv[i]);
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-render") == 0) {
            if (++i < argc) {
                int policy = PictureParseCmapPolicy(argv[i]);

                if (policy != PictureCmapPolicyInvalid)
                    PictureCmapPolicy = policy;
                else
                    UseMsg();
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "+extension") == 0) {
            if (++i < argc) {
                if (!EnableDisableExtension(argv[i], TRUE))
                    EnableDisableExtensionError(argv[i], TRUE);
            }
            else
                UseMsg();
        }
        else if (strcmp(argv[i], "-extension") == 0) {
            if (++i < argc) {
                if (!EnableDisableExtension(argv[i], FALSE))
                    EnableDisableExtensionError(argv[i], FALSE);
            }
            else
                UseMsg();
        }
        
// version(CONFIG_SYSLOG) {
//         if (ProcessCmdLineMultiInt(argc, argv, &i, "-syslogverbose", &xorgSyslogVerbosity))
//         {}
//         // else{}
// }
// // #endif
        else {
            ErrorF("Unrecognized option: %s\n", argv[i]);
            UseMsg();
            FatalError("Unrecognized option: %s\n", argv[i]);
        }
    }
}

/* Implement a simple-minded font authorization scheme.  The authorization
   name is "hp-hostname-1", the contents are simply the host name. */
int
set_font_authorizations(char **authorizations, int *authlen, void *client)
{
enum AUTHORIZATION_NAME = "hp-hostname-1";
    char* result = null;
    char* p = null;

    if (p is null) {
        uint len;

version (HAVE_GETADDRINFO) {
        addrinfo hints; addrinfo* ai = null;
} else {
        hostent* host;

version (XTHREADS_NEEDS_BYNAMEPARAMS) {
        _Xgethostbynameparams hparams;
}
}

        xhostname hn;
        f_xhostname(&hn);

        char* hnameptr = null;
version (HAVE_GETADDRINFO) {
        memset(&hints, 0, hints.sizeof);
        hints.ai_flags = AI_CANONNAME;
        if (getaddrinfo(hn.name, null, &hints, &ai) == 0) {
            hnameptr = ai.ai_canonname;
        }
        else {
            hnameptr = hn.name;
        }
} else {
        host = _XGethostbyname(hn.name.ptr);
        if (host is null)
            hnameptr = hn.name.ptr;
        else
            hnameptr = host.h_name;
}

        len = cast(uint)(strlen(hnameptr) + 1);
        result = cast(char*) calloc(1, len + ((AUTHORIZATION_NAME.length) + 4));
        if (result is null) {
version (HAVE_GETADDRINFO) {
            if (ai) {
                freeaddrinfo(ai);
            }
}
            return 0;
        }

        p = result;
        *p++ = AUTHORIZATION_NAME.sizeof >> 8;
        *p++ = AUTHORIZATION_NAME.sizeof & 0xff;
        *p++ = cast(char)((len) >> 8);
        *p++ = (len & 0xff);

        memcpy(p, AUTHORIZATION_NAME.ptr, AUTHORIZATION_NAME.sizeof);
        p += AUTHORIZATION_NAME.sizeof;
        memcpy(p, hnameptr, len);
        p += len;
version (HAVE_GETADDRINFO) {
        if (ai) {
            freeaddrinfo(ai);
        }
}
    }
    *authlen = cast(int)(p - result);
    *authorizations = result;
    return 1;
}

void SmartScheduleStopTimer()
{
version (HAVE_SETITIMER) {
    itimerval timer = void;

    if (!SmartScheduleSignalEnable)
        return;
    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = 0;
    timer.it_value.tv_sec = 0;
    timer.it_value.tv_usec = 0;
    cast(void) setitimer(ITIMER_REAL, &timer, 0);
}
}

void SmartScheduleStartTimer()
{
version (HAVE_SETITIMER) {
    itimerval timer = void;

    if (!SmartScheduleSignalEnable)
        return;
    timer.it_interval.tv_sec = 0;
    timer.it_interval.tv_usec = SmartScheduleInterval * 1000;
    timer.it_value.tv_sec = 0;
    timer.it_value.tv_usec = SmartScheduleInterval * 1000;
    setitimer(ITIMER_REAL, &timer, 0);
}
}

version (HAVE_SETITIMER) {
private void SmartScheduleTimer(int sig)
{
    SmartScheduleTime += SmartScheduleInterval;
}

private int SmartScheduleEnable()
{
    int ret = 0;
    sigaction act = void;

    if (!SmartScheduleSignalEnable)
        return 0;

    memset(cast(char*) &act, 0, sigaction.sizeof);

    /* Set up the timer signal function */
    act.sa_flags = SA_RESTART;
    act.sa_handler = SmartScheduleTimer;
    sigemptyset(&act.sa_mask);
    sigaddset(&act.sa_mask, SIGALRM);
    ret = sigaction(SIGALRM, &act, 0);
    return ret;
}

private int SmartSchedulePause()
{
    int ret = 0;
    sigaction act = void;

    if (!SmartScheduleSignalEnable)
        return 0;

    memset(cast(char*) &act, 0, sigaction.sizeof);

    act.sa_handler = SIG_IGN;
    sigemptyset(&act.sa_mask);
    ret = sigaction(SIGALRM, &act, 0);
    return ret;
}
}

void SmartScheduleInit()
{
version (HAVE_SETITIMER) {
    if (SmartScheduleEnable() < 0) {
        perror("sigaction for smart scheduler");
        SmartScheduleSignalEnable = FALSE;
    }
}
}

version (HAVE_SIGPROCMASK) {
private sigset_t PreviousSignalMask;
private int BlockedSignalCount;
}

void OsBlockSignals()
{
version (HAVE_SIGPROCMASK) {
    if (BlockedSignalCount++ == 0) {
        sigset_t set = void;

        sigemptyset(&set);
        sigaddset(&set, SIGALRM);
        sigaddset(&set, SIGVTALRM);
version (SIGWINCH) {
        sigaddset(&set, SIGWINCH);
}
        sigaddset(&set, SIGTSTP);
        sigaddset(&set, SIGTTIN);
        sigaddset(&set, SIGTTOU);
        sigaddset(&set, SIGCHLD);
        xthread_sigmask(SIG_BLOCK, &set, &PreviousSignalMask);
    }
}
}

void OsReleaseSignals()
{
version (HAVE_SIGPROCMASK) {
    if (--BlockedSignalCount == 0) {
        xthread_sigmask(SIG_SETMASK, &PreviousSignalMask, 0);
    }
}
}

void OsResetSignals()
{
version (HAVE_SIGPROCMASK) {
    while (BlockedSignalCount > 0)
        OsReleaseSignals();
    input_force_unlock();
}
}

/*
 * Pending signals may interfere with core dumping. Provide a
 * mechanism to block signals when aborting.
 */

void OsAbort()
{
version (OSX) {} else {
    OsBlockSignals();
}
static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
    /* abort() raises SIGABRT, so we have to stop handling that to prevent
     * recursion
     */
    OsSignal(SIGABRT, SIG_DFL);
}
    abort();
}

static if (!HasVersion!"Windows") {
/*
 * "safer" versions of system(3), popen(3) and pclose(3) which give up
 * all privs before running a command.
 *
 * This is based on the code in FreeBSD 2.2 libc.
 *
 * XXX It'd be good to redirect stderr so that it ends up in the log file
 * as well.  As it is now, xkbcomp messages don't end up in the log file.
 */

struct pid {
    pid* next;
    FILE* fp;
    int pid_;
}

private pid* pidlist;

void* Popen(const(char)* command, const(char)* type)
{
    pid* cur = void;
    FILE* iop = void;
    int[2] pdes = void; int pid_ = void;

    if (command is null || type is null)
        return null;

    if ((*type != 'r' && *type != 'w') || type[1])
        return null;

    if ((cur = cast(pid*) calloc(1, pid.sizeof)) is null)
        return null;

    if (pipe(pdes) < 0) {
        free(cur);
        return null;
    }

    /* Ignore the smart scheduler while this is going on */
version (HAVE_SETITIMER) {
    if (SmartSchedulePause() < 0) {
        close(pdes[0]);
        close(pdes[1]);
        free(cur);
        perror("signal");
        return null;
    }
}

    switch (pid_ = fork()) {
    case -1:                   /* error */
        close(pdes[0]);
        close(pdes[1]);
        free(cur);
version (HAVE_SETITIMER) {
        if (SmartScheduleEnable() < 0)
            perror("signal");
}
        return null;
    case 0:                    /* child */
        if (setgid(getgid()) == -1)
            _exit(127);
        if (setuid(getuid()) == -1)
            _exit(127);
        if (*type == 'r') {
            if (pdes[1] != 1) {
                /* stdout */
                dup2(pdes[1], 1);
                close(pdes[1]);
            }
            close(pdes[0]);
        }
        else {
            if (pdes[0] != 0) {
                /* stdin */
                dup2(pdes[0], 0);
                close(pdes[0]);
            }
            close(pdes[1]);
        }
        execl("/bin/sh".ptr, "sh".ptr, "-c".ptr, command, cast(char*) null);
        _exit(127);
    default: break;}

    /* Avoid EINTR during stdio calls */
    OsBlockSignals();

    /* parent */
    if (*type == 'r') {
        iop = fdopen(pdes[0], type);
        close(pdes[1]);
    }
    else {
        iop = fdopen(pdes[1], type);
        close(pdes[0]);
    }

    cur.fp = iop;
    cur.pid_ = pid_;
    cur.next = pidlist;
    pidlist = cur;

    DebugF("Popen: `%s', fp = %p\n", command, iop);

    return cast(void*)iop;
}

/* fopen that drops privileges */
void* Fopen(const(char)* file, const(char)* type)
{
    FILE* iop = void;
    int ruid = void, euid = void;

    ruid = getuid();
    euid = geteuid();

    if (seteuid(ruid) == -1) {
        return null;
    }
    iop = fopen(file, type);

    if (seteuid(euid) == -1) {
        if (iop) {
            fclose(iop);
        }
        return null;
    }
    return cast(void*)iop;
}

int Pclose(void* iop)
{
    pid* cur = void, last = void;
    int pstat = void;
    int pid = void;

    DebugF("Pclose: fp = %p\n", iop);
    fclose(cast(FILE*)iop);

    for (last = null, cur = pidlist; cur; last = cur, cur = cur.next)
        if (cur.fp == iop)
            break;
    if (cur is null)
        return -1;

    do {
        pid = waitpid(cast(int)cur.pid_, &pstat, 0);
    } while (pid == -1 && errno == EINTR);

    if (last is null)
        pidlist = cur.next;
    else
        last.next = cur.next;
    free(cur);

    /* allow EINTR again */
    OsReleaseSignals();

version (HAVE_SETITIMER) {
    if (SmartScheduleEnable() < 0) {
        perror("signal");
        return -1;
    }
}

    return pid == -1 ? -1 : pstat;
}

// int Fclose(void* iop)
// {
//     return fclose(cast(FILE*)iop);
// }

}                          /* !WIN32 */

version (Windows) {

//import externs.X11.Xwindows;

const(char)* Win32TempDir()
{
    static char[PATH_MAX] buffer = 0;

    if (GetTempPath(buffer.sizeof, buffer.ptr)) {
        int len = void;

        buffer[((buffer).ptr - 1).sizeof] = 0;
        len = strlen(buffer.ptr);
        if (len > 0)
            if (buffer[len - 1] == '\\')
                buffer[len - 1] = 0;
        return buffer;
    }
    if (getenv("TEMP") !is null)
        return getenv("TEMP");
    else if (getenv("TMP") !is null)
        return getenv("TMP");
    else
        return "/tmp";
}
}

Bool PrivsElevated()
{
    static Bool privsTested = FALSE;
    static Bool privsElevated = TRUE;

    if (!privsTested) {
version (Windows) {
        privsElevated = FALSE;
} else {
        if ((getuid() != geteuid()) || (getgid() != getegid())) {
            privsElevated = TRUE;
        }
        else {
// static if (HAVE_ISSETUGID) {
//             privsElevated = issetugid();
// } else static if (HAVE_GETRESUID) {
//             uid_t ruid = void, euid = void, suid = void;
//             gid_t rgid = void, egid = void, sgid = void;

//             if ((getresuid(&ruid, &euid, &suid) == 0) &&
//                 (getresgid(&rgid, &egid, &sgid) == 0)) {
//                 privsElevated = (euid != suid) || (egid != sgid);
//             }
//             else {
//                 printf("Failed getresuid or getresgid");
//                 /* Something went wrong, make defensive assumption */
//                 privsElevated = TRUE;
//             }
// } else 
{
            if (getuid() == 0) {
                /* running as root: uid==euid==0 */
                privsElevated = FALSE;
            }
            else {
                /*
                 * If there are saved ID's the process might still be privileged
                 * even though the above test succeeded. If issetugid() and
                 * getresgid() aren't available, test this by trying to set
                 * euid to 0.
                 */
                uint oldeuid = void;

                oldeuid = geteuid();

                if (seteuid(0) != 0) {
                    privsElevated = FALSE;
                }
                else {
                    if (seteuid(oldeuid) != 0) {
                        FatalError("Failed to drop privileges.  Exiting\n");
                    }
                    privsElevated = TRUE;
                }
            }
}
        }
}
        privsTested = TRUE;
    }
    return privsElevated;
}

/*
 * CheckUserParameters: check for long command line arguments and long
 * environment variables.  By default, these checks are only done when
 * the server's euid != ruid.  In 3.3.x, these checks were done in an
 * external wrapper utility.
 */

/* Check args and env only if running setuid (euid == 0 && euid != uid) ? */
version (CHECK_EUID) {} else {
version (Windows) {} else {
enum CHECK_EUID = 1;
} version (Windows) {
enum CHECK_EUID = 0;
}
}

enum MAX_ARG_LENGTH =          128;
enum MAX_ENV_LENGTH =          256;
enum MAX_ENV_PATH_LENGTH =     2048    /* Limit for *PATH and TERMCAP */;

enum string checkPrintable(string c) = `(((` ~ c ~ `) & 0x7f) >= 0x20 && ((` ~ c ~ `) & 0x7f) != 0x7f)`;

enum BadCode {
    NotBad = 0,
    UnsafeArg,
    ArgTooLong,
    UnprintableArg,
    InternalError
}
alias NotBad = BadCode.NotBad;
alias UnsafeArg = BadCode.UnsafeArg;
alias ArgTooLong = BadCode.ArgTooLong;
alias UnprintableArg = BadCode.UnprintableArg;
alias InternalError = BadCode.InternalError;


void CheckUserParameters(int argc, char** argv, char** envp)
{
    BadCode bad = NotBad;
    int i = 0, j = void;
    char* a = null;
    bool chk;

static if (CHECK_EUID) {
    chk = true;
}
// #endif
    if (chk && PrivsElevated())
    {
        /* Check each argv[] */
        for (i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-fp") == 0) {
                i++;            /* continue with next argument. skip the length check */
                if (i >= argc)
                    break;
            }
            else {
                if (strlen(argv[i]) > MAX_ARG_LENGTH) {
                    bad = ArgTooLong;
                    break;
                }
            }
            a = argv[i];
            while (*a) {
                if (mixin(checkPrintable!(`*a`)) == 0) {
                    bad = UnprintableArg;
                    break;
                }
                a++;
            }
            if (bad)
                break;
        }
        if (!bad) {
            /* Check each envp[] */
            for (i = 0; envp[i]; i++) {

                /* Check for bad environment variables and values */
                while (envp[i] && (strncmp(envp[i], "LD", 2) == 0)) {
                    for (j = i; envp[j]; j++) {
                        envp[j] = envp[j + 1];
                    }
                }
                if (envp[i] && (strlen(envp[i]) > MAX_ENV_LENGTH)) {
                    for (j = i; envp[j]; j++) {
                        envp[j] = envp[j + 1];
                    }
                    i--;
                }
            }
        }
    }
    switch (bad) {
    case NotBad:
        return;
    case UnsafeArg:
        ErrorF("Command line argument number %d is unsafe\n", i);
        break;
    case ArgTooLong:
        ErrorF("Command line argument number %d is too long\n", i);
        break;
    case UnprintableArg:
        ErrorF("Command line argument number %d contains unprintable"
               ~ " characters\n", i);
        break;
    case InternalError:
        ErrorF("Internal Error\n");
        break;
    default:
        ErrorF("Unknown error\n");
        break;
    }
    FatalError("X server aborted because of unsafe environment\n");
}

/*
 * CheckUserAuthorization: check if the user is allowed to start the
 * X server.  This usually means some sort of PAM checking, and it is
 * usually only done for setuid servers (uid != euid).
 */

version (USE_PAM) {
import security.pam_appl;
import security.pam_misc;
import core.sys.posix.pwd;
}                          /* USE_PAM */

void CheckUserAuthorization()
{
version (USE_PAM) {
    static pam_conv conv = {
        misc_conv,
        null
    };

    pam_handle_t* pamh = null;
    passwd* pw = void;
    int retval = void;

    if (getuid() != geteuid()) {
        pw = getpwuid(getuid());
        if (pw is null)
            FatalError("getpwuid() failed for uid %d\n", getuid());

        retval = pam_start("xserver", pw.pw_name, &conv, &pamh);
        if (retval != PAM_SUCCESS)
            FatalError("pam_start() failed.\n"
                       ~ "\tMissing or mangled PAM config file or module?\n");

        retval = pam_authenticate(pamh, 0);
        if (retval != PAM_SUCCESS) {
            pam_end(pamh, retval);
            FatalError("PAM authentication failed, cannot start X server.\n"
                       ~ "\tPerhaps you do not have console ownership?\n");
        }

        retval = pam_acct_mgmt(pamh, 0);
        if (retval != PAM_SUCCESS) {
            pam_end(pamh, retval);
            FatalError("PAM authentication failed, cannot start X server.\n"
                       ~ "\tPerhaps you do not have console ownership?\n");
        }

        /* this is not a session, so do not do session management */
        pam_end(pamh, PAM_SUCCESS);
    }
}
}

static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
/* Move a file descriptor out of the way of our select mask; this
 * is useful for file descriptors which will never appear in the
 * select mask to avoid reducing the number of clients that can
 * connect to the server
 */
int os_move_fd(int fd)
{
    int newfd = void;

version (F_DUPFD_CLOEXEC) {
    newfd = fcntl(fd, F_DUPFD_CLOEXEC, MAXCLIENTS);
} else {
    newfd = fcntl(fd, F_DUPFD, build.xlibre_server.MAXCLIENTS);
}
    if (newfd < 0)
        return fd;
version (F_DUPFD_CLOEXEC) {} else {
    fcntl(newfd, F_SETFD, FD_CLOEXEC);
}
    close(fd);
    return newfd;
}
}

void AbortServer()
{
version (XF86BIGFONT) {
    XF86BigfontCleanup();
}
    CloseWellKnownConnections();
    UnlockServer();
    AbortDevices();
    ddxGiveUp(EXIT_ERR_ABORT);
    fflush(core.stdc.stdio.stderr);
    if (CoreDump)
        OsAbort();
    exit(1);
}
