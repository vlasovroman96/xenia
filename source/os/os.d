module os.os;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
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

import build.xlibre_server;
public import core.stdc.stdarg;
public import core.stdc.stdint;
public import core.stdc.stdlib;
public import core.stdc.string;
version (MONOTONIC_CLOCK) {
public import core.stdc.time;
}

// //public import x11.Xfuncproto;

public import common.xlibre_ptrtypes;
public import dix.callback;
public import common.misc;
public import externs.gnu;

import os.connection;
import os.WaitFor;
public import os.string;


/*
 * @brief macro for specifying non-null arguments
 *
 * part of public SDK / driver API
 */
version (_X_ATTRIBUTE_NONNULL_ARG) {} else {
enum string_ = `__attribute__((nonnull(__VA_ARGS__)))`;
}

version (_X_ATTRIBUTE_VPRINTF) {} else {
static if (HasVersion!"__GNUC__" && (__GNUC__ >= 2) && !HasVersion!"__clang__") {
enum string _X_ATTRIBUTE_VPRINTF(string fmt, string firstarg) = `
          __attribute__((__format__(gnu_printf, ` ~ fmt ~ `, ` ~ firstarg ~ `)))`;
} else {
enum string _X_ATTRIBUTE_VPRINTF(string fmt, string firstarg) = `_X_ATTRIBUTE_PRINTF(` ~ fmt ~ `,` ~ firstarg ~ `)`;
}
}

enum SCREEN_SAVER_ON =   0;
enum SCREEN_SAVER_OFF =  1;
enum SCREEN_SAVER_FORCER = 2;
enum SCREEN_SAVER_CYCLE =  3;

enum MAX_REQUEST_SIZE = 65535;

struct _NewClientRec;
alias NewClientPtr = _NewClientRec*;

version (xnfalloc) {} else {
enum string xnfalloc(string size) = `XNFalloc(cast(c_ulong)(` ~ size ~ `))`;
enum string xnfcalloc(string _num, string _size) = `XNFcallocarray((` ~ _num ~ `), (` ~ _size ~ `))`;
enum string xnfrealloc(string ptr, string size) = `XNFrealloc(cast(void*)(` ~ ptr ~ `), cast(c_ulong)(` ~ size ~ `))`;

enum string xstrdup(string s) = `Xstrdup(` ~ s ~ `)`;
enum string xnfstrdup(string s) = `XNFstrdup(` ~ s ~ `)`;
}

public import core.stdc.stdio;
public import core.stdc.stdarg;

// void ReadFdFromClient(ClientPtr client);

// void WriteToClient(ClientPtr, int, const(void)*);

alias NotifyFdProcPtr = void function(int fd, int ready, void* data);

public import os.fd_notify;

// void SetNotifyFd(int fd, NotifyFdProcPtr notify_fd, int mask, void* data);

pragma(inline, true) void RemoveNotifyFd(int fd)
{
    cast(void) SetNotifyFd(fd, null, X_NOTIFY_NONE, null);
}

void IgnoreClient(ClientPtr);

void AttendClient(ClientPtr);

// uint GetTimeInMillis();
// ulong GetTimeInMicros();

// void AdjustWaitForDelay(void* waitTime, int newdelay);

// struct _OsTimerRec;
alias OsTimerPtr = _OsTimerRec*;

alias OsTimerCallback = CARD32 function(OsTimerPtr timer, CARD32 time, void* arg);

enum TimerAbsolute = (1<<0);
enum TimerForceOld = (1<<1);

// OsTimerPtr TimerSet(OsTimerPtr timer, int flags, CARD32 millis, OsTimerCallback func, void* arg);

// void TimerCancel(OsTimerPtr);
// void TimerFree(OsTimerPtr);

// void GiveUp(int);

/*
 * This function malloc(3)s buffer, terminating the server if there is not
 * enough memory.
 */
void* XNFalloc(c_ulong);

/*
 * This function calloc(3)s buffer, terminating the server if there is not
 * enough memory.
 */
void* XNFcalloc(c_ulong);

/*
 * This function calloc(3)s buffer, terminating the server if there is not
 * enough memory or the arguments overflow when multiplied
 */
void* XNFcallocarray(size_t nmemb, size_t size);

/*
 * This function realloc(3)s passed buffer, terminating the server if there is
 * not enough memory.
 */
void* XNFrealloc(void*, c_ulong);

/*
 * This function strdup(3)s passed string. The only difference from the library
 * function that it is safe to pass NULL, as NULL will be returned.
 */
void* Xstrdup(const(char)* s);

/*
 * This function strdup(3)s passed string, terminating the server if there is
 * not enough memory. If NULL is passed to this function, NULL is returned.
 */
// void* XNFstrdup(const(char)* s);

/* Include new X*asprintf API */
public import os.xprintf;

alias OsSigWrapperPtr = int function(int);

void OsRegisterSigWrapper(OsSigWrapperPtr newWrap);

// void PrivsElevated();

// void GetClientFd(ClientPtr);

/* stuff for FlushCallback */
// CallbackListPtr FlushCallback;

void TimeSinceLastInputEvent();

/* Function fallbacks provided by AC_REPLACE_FUNCS in configure.ac */

static if (HAVE_REALLOCARRAY){

alias xreallocarray = reallocarray;
} else {
void* reallocarray(void* optr, size_t nmemb, size_t size);
}

static if (HAVE_STRCASESTR){
enum xstrcasestr = strcasestr;

} else {
void* xstrcasestr(const(char)* s, const(char)* find);
}

static if (HAVE_STRLCPY){} else {
ulong strlcpy(char* dst, const(char)* src, size_t siz);
void strlcat(char* dst, const(char)* src, size_t siz);
}

static if (HAVE_STRNDUP){} else {
// void* strndup(const(char)* str, size_t n);
}

version (HAVE_TIMINGSAFE_MEMCMP) {} else {
    public import os.timingsafe_memcmp; 
// void timingsafe_memcmp(const(void)* b1, const(void)* b2, size_t len);
}

/* Flags for log messages. */
enum MessageType {
    X_PROBED,                   /* Value was probed */
    X_CONFIG,                   /* Value was given in the config file */
    X_DEFAULT,                  /* Value is a default */
    X_CMDLINE,                  /* Value was given on the command line */
    X_NOTICE,                   /* Notice */
    X_ERROR,                    /* Error message */
    X_WARNING,                  /* Warning message */
    X_INFO,                     /* Informational message */
    X_NONE,                     /* No prefix */
    X_NOT_IMPLEMENTED,          /* Not implemented */
    X_DEBUG,                    /* Debug message */
    X_UNKNOWN = -1              /* unknown -- this must always be last */
}
alias X_PROBED = MessageType.X_PROBED;
alias X_CONFIG = MessageType.X_CONFIG;
alias X_DEFAULT = MessageType.X_DEFAULT;
alias X_CMDLINE = MessageType.X_CMDLINE;
alias X_NOTICE = MessageType.X_NOTICE;
alias X_ERROR = MessageType.X_ERROR;
alias X_WARNING = MessageType.X_WARNING;
alias X_INFO = MessageType.X_INFO;
alias X_NONE = MessageType.X_NONE;
alias X_NOT_IMPLEMENTED = MessageType.X_NOT_IMPLEMENTED;
alias X_DEBUG = MessageType.X_DEBUG;
alias X_UNKNOWN = MessageType.X_UNKNOWN;


void _X_ATTRIBUTE_PRINTF();
void _X_ATTRIBUTE_PRINTF();
void _X_ATTRIBUTE_PRINTF();

// void LogHdrMessageVerb(MessageType type, int verb, const(char)* msg_format, va_list msg_args, const(char)* hdr_format, ...);

// void _X_NORETURN;

void _X_ATTRIBUTE_PRINTF();

void xorg_backtrace();

/* should not be used anymore, just for backwards compat with drivers */
// enum string LogVMessageVerbSigSafe(...) = `LogVMessageVerb(__VA_ARGS__)`;
// enum string LogMessageVerbSigSafe(...) = `LogMessageVerb(__VA_ARGS__)`;
// enum string ErrorFSigSafe(...) = `ErrorF(__VA_ARGS__)`;
// enum string VErrorFSigSafe(...) = `VErrorF(__VA_ARGS__)`;
// enum string VErrorF(...) = `LogVMessageVerb(X_NONE, -1, __VA_ARGS__)`;

/* only for backwards compat with drivers that haven't kept up yet
   (xf86-video-intel)

   @todo revise after next stable release
*/
pragma(inline, true) private auto System(const(char)* cmdline)
{
    return system(cmdline);
}

                          /* OS_H */
