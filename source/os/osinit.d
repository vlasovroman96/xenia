module os.osinit;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

import build.dix_config;

import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.signal;
import core.sys.posix.string;
//import x11.X;
// //import x11.Xos;
version (HAVE_DLFCN_H) {
import core.sys.posix.dlfcn;
}
static if (HasVersion!"HAVE_BACKTRACE" && HasVersion!"HAVE_EXECINFO_H") {
import execinfo;
}

import dix.dix_priv;
import os.busfault;
import os.ddx_priv;
import os.log_priv;
import os.osdep;
import os.serverlock;

import os.os;
import dix.dixstruct_priv;
import os.log;
import externs.gnu;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import os.WaitFor;
import dix.resource;
import os.timingsafe_memcmp;
import std.conv;
//public import ext

static if (!HasVersion!"Windows") {
import core.sys.posix.sys.resource;
}

/* The actual user defined max number of clients */
static int LimitClients = DIX_LIMITCLIENTS;

private OsSigWrapperPtr OsSigWrapper = null;

OsSigWrapperPtr OsRegisterSigWrapper(OsSigWrapperPtr newSigWrapper)
{
    OsSigWrapperPtr oldSigWrapper = OsSigWrapper;

    OsSigWrapper = newSigWrapper;

    return oldSigWrapper;
}

/*
 * OsSigHandler --
 *    Catch unexpected signals and exit or continue cleanly.
 */
version (Win32)
{
}
else
{

version (SA_SIGINFO)
{
    static void OsSigHandler(int signo, siginfo_t* sip, void* unused)
    {
        version (RTLD_DI_SETSIGNAL)
        {
            enum SIGNAL_FOR_RTLD_ERROR = SIGQUIT;

            if (signo == SIGNAL_FOR_RTLD_ERROR) {
                const(char)* dlerr = dlerror();

                if (dlerr !is null) {
                    LogMessageVerb(
                        X_ERROR,
                        1,
                        "Dynamic loader error: %s\n",
                        dlerr
                    );
                }
            }
        }

        if (OsSigWrapper !is null) {
            if (OsSigWrapper(signo) == 0)
                return;
        }

        xorg_backtrace();

        if (sip !is null) {
            if (sip.si_code == SI_USER) {
                ErrorF(
                    "Received signal %u sent by process %u, uid %u\n",
                    signo,
                    sip.si_pid,
                    sip.si_uid
                );
            }
            else {
                final switch (signo) {
                    case SIGSEGV:
                    case SIGBUS:
                    case SIGILL:
                    case SIGFPE:
                        ErrorF(
                            "%s at address %p\n",
                            strsignal(signo),
                            sip.si_addr
                        );
                        break;

                    default:
                        break;
                }
            }
        }

        if (signo != SIGQUIT)
            CoreDump = True;

        FatalError(
            "Caught signal %d (%s). Server aborting\n",
            signo,
            strsignal(signo)
        );
    }
}
else
{
    static void OsSigHandler(int signo)
    {
        version (RTLD_DI_SETSIGNAL)
        {
            enum SIGNAL_FOR_RTLD_ERROR = SIGQUIT;

            if (signo == SIGNAL_FOR_RTLD_ERROR) {
                const(char)* dlerr = dlerror();

                if (dlerr !is null) {
                    LogMessageVerb(
                        X_ERROR,
                        1,
                        "Dynamic loader error: %s\n",
                        dlerr
                    );
                }
            }
        }

        if (OsSigWrapper !is null) {
            if (OsSigWrapper(signo) == 0)
                return;
        }

        xorg_backtrace();

        if (signo != SIGQUIT)
            CoreDump = True;

        FatalError(
            "Caught signal %d (%s). Server aborting\n",
            signo,
            strsignal(signo)
        );
    }
}

}

void OsInit()
{
    static Bool been_here = False;

    if (!been_here) {
static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
        sigaction_t act = void, oact = void;
        int i = void;

        int[11] siglist = [ SIGSEGV, SIGQUIT, SIGILL, SIGFPE, SIGBUS,
            SIGABRT,
            SIGSYS,
            SIGXCPU,
            SIGXFSZ,
            0,
// // #ifdef SIGEMT
//             SIGEMT,
// // #endif
            0 /* must be last */
        ];
        sigemptyset(&act.sa_mask);
version (SA_SIGINFO) {
        act.sa_sigaction = OsSigHandler;
        act.sa_flags = SA_SIGINFO;
} else {
        act.sa_handler = &OsSigHandler;
        act.sa_flags = 0;
}
        for (i = 0; siglist[i] != 0; i++) {
            if (sigaction(siglist[i], &act, &oact)) {
                ErrorF("failed to install signal handler for signal %d: %s\n",
                       siglist[i], strerror(errno));
            }
        }
} /* !WIN32 || __CYGWIN__ */
        busfault_init();
        server_poll = ospoll_create();
        if (!server_poll)
            FatalError("failed to allocate poll structure");

static if (HasVersion!"HAVE_BACKTRACE" && HasVersion!"HAVE_EXECINFO_H") {
        /*
         * initialize the backtracer, since the ctor calls dlopen(), which
         * calls malloc(), which isn't signal-safe.
         */
        do {
            void* array = void;

            backtrace(&array, 1);
        } while (0);
}

version (RTLD_DI_SETSIGNAL) {
        /* Tell runtime linker to send a signal we can catch instead of SIGKILL
         * for failures to load libraries/modules at runtime so we can clean up
         * after ourselves.
         */
        {
            int failure_signal = SIGNAL_FOR_RTLD_ERROR;

            dlinfo(RTLD_SELF, RTLD_DI_SETSIGNAL, &failure_signal);
        }
}

static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
        if (getpgrp() == 0)
            setpgid(0, 0);
}
        LockServer();
        been_here = True;
    }
    TimerInit();
    OsVendorInit();
    OsResetSignals();
    /*
     * No log file by default.  OsVendorInit() should call LogInit() with the
     * log file name if logging to a file is desired.
     */
    LogInit(null, null);
    SmartScheduleInit();
}
