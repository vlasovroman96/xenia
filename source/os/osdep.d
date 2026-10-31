module os.osdep;
@nogc nothrow:
extern(C): __gshared:

// template HasVersion(string versionId) {
// 	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
// }
import core.stdc.config: c_long, c_ulong;
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
version (_OSDEP_H_) {} else {
enum _OSDEP_H_ = 1;

public import build.dix_config;

//public import x11.Xdefs;

import include.xlibre_ptrtypes;
import x11.Xmd;
public import core.stdc.limits;
public import core.stdc.signal;
public import core.stdc.stddef;
import externs.gnu;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import os.WaitFor;
import dix.resource;
import os.timingsafe_memcmp;
import std.conv;
public import os.utils;

//public import x11.X;
//public import x11.Xmd;
//public import x11.Xdefs;

/*
 * return the least significant bit in x which is set
 *
 * This works on 1's complement and 2's complement machines.
 * If you care about the extra instruction on 2's complement
 * machines, change to ((x) & (-(x)))
 */
enum string lowbit(alias x) = `((` ~ x.stringof ~ `) & (~(` ~ x.stringof ~ `) + 1))`;

version (__has_builtin) {} else {
enum string __has_builtin(string x) = `0     /* Compatibility with older compilers */`;
}

enum MILLI_PER_MIN = (1000 * 60);
enum MILLI_PER_SECOND = (1000);

public import os.ospoll;

ospoll* server_poll;

// Bool listen_to_client(ClientPtr client);

Bool NewOutputPending;

/* for platforms lacking arc4random_buf() libc function */
version (HAVE_ARC4RANDOM_BUF) {} else {
pragma(inline, true) void arc4random_buf(void* buf, size_t nbytes)
{
    int fd = open("/dev/urandom", O_RDONLY);
    read(fd, buf, nbytes);
    close(fd);
}
} /* HAVE_ARC4RANDOM_BUF */

/* OsTimer functions */
// void TimerInit();

/* must be exported for backwards compatibility with legacy nvidia390,
 * not for use in maintained drivers
 */
// Bool TimerForce(OsTimerPtr);

// static if (HasVersion!"Windows" && ! HasVersion!"Cygwin") {
//public import externs.X11.Xwinsock;

// alias sigset_t = _sigset_t;

// const(char)* Win32TempDir();

pragma(inline, true) void Fclose(void* f) { fclose(cast(FILE*)f); }
// pragma(inline, true) void* Fopen(const(char)* a, const(char)* b) { return cast(void*)fopen(a,b); }

// } else { /* WIN32 */

void* Popen(const(char)*, const(char)*);
// void* Fopen(const(char)*, const(char)*);

int Pclose(void* f);

// } /* WIN32 */

/* clone fd so it gets out of our select mask */
int os_move_fd(int fd);

/* set signal mask - either on current thread or whole process,
   depending on whether multithreading is used */
// int xthread_sigmask(int how, const(sigset_t)* set, sigset_t* oldest);

alias OsSigHandlerPtr = void function(int sig);

/* install signal handler */
// OsSigHandlerPtr OsSignal(int sig, OsSigHandlerPtr handler);

// void OsInit();

void  OsBlockSignals();

void  OsReleaseSignals();

void OsResetSignals();
void OsAbort();
void AbortServer();

void MakeClientGrabPervious(ClientPtr client);
void MakeClientGrabImpervious(ClientPtr client);

int OnlyListenToOneClient(ClientPtr client);

void ListenToAllClients();

/* allow DDX to force using another clock */
void ForceClockId(clockid_t forced_clockid);

// Bool WaitForSomething(Bool clients_are_ready);
void CloseDownConnection(ClientPtr client);

// int LimitClients;
// Bool PartialNetwork;

Bool CoreDump;
// Bool NoListenAll;

/*
 * This function reallocarray(3)s passed buffer, terminating the server if
 * there is not enough memory or the arguments overflow when multiplied.
 */
void* XNFreallocarray(void* ptr, size_t nmemb, size_t size);

// static if mixin((__has_builtin!(`__builtin_popcountl`)) {)
// enum Ones = __builtin_popcountl;
// } else {
/*
 * Count the number of bits set to 1 in a 32-bit word.
 * Algorithm from MIT AI Lab Memo 239: "HAKMEM", ITEM 169.
 * https://dspace.mit.edu/handle/1721.1/6086
 */
pragma(inline, true) int Ones(c_ulong mask)
{
    c_ulong y = void;

    y = (mask >> 1) & octal!"033333333333";
    y = mask - y - ((y >> 1) & octal!"033333333333");
    return (((y + (y >> 3)) & octal!"030707070707") % octal!"077");
}
}

/* static assert for protocol structure sizes */
// version (__size_assert) {} else {
// enum string __size_assert(string what, string howmuch) = `
//   alias _size_wrong_ = char[( !!(` ~ what ~ `.sizeof == ` ~ howmuch ~ `) )*2-1];`;
// }

/*
 * like strlen(), but checking for NULL and return 0 in this case
 */
pragma(inline, true) size_t x_safe_strlen(const(char)* str) {
    return (str ? strlen(str) : 0);
}

enum ExitCode {
    EXIT_NO_ERROR = 0,
    EXIT_ERR_ABORT = 1,
    EXIT_ERR_CONFIGURE = 2,
    EXIT_ERR_DRIVERS = 3,
}
alias EXIT_NO_ERROR = ExitCode.EXIT_NO_ERROR;
alias EXIT_ERR_ABORT = ExitCode.EXIT_ERR_ABORT;
alias EXIT_ERR_CONFIGURE = ExitCode.EXIT_ERR_CONFIGURE;
alias EXIT_ERR_DRIVERS = ExitCode.EXIT_ERR_DRIVERS;


// sig_atomic_t inSignalContext;


/* run timers that are expired at timestamp `now` */
void DoTimers(CARD32 now);
                   /* _OSDEP_H_ */
