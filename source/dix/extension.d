module dix.extension;
@nogc nothrow:
extern(C): __gshared:
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

//import x11.X;
//import x11.Xproto;

import dix.dix_priv;
import dix.extension_priv;
import dix.registry_priv;
import dix.request_priv;
import tables;

import common.misc;
import dix.dixstruct_priv;
import dix.gc;
import dix.scrnintstr;
import dix.dispatch;
import dix.privates;
import Xext.xace;
import os.log;
import externs.attrs;

enum LAST_ERROR = 255;

CallbackListPtr ExtensionAccessCallback = null;
CallbackListPtr ExtensionDispatchCallback = null;

struct _ExtensionEntry {
    int index;
    @nogc nothrow void function(_ExtensionEntry*) CloseDown;
    const(char)* name;           /* extension name */
    int base;                   /* base request number */
    int eventBase;
    int eventLast;
    int errorBase;
    int errorLast;
    void* extPrivate;
    @nogc nothrow ushort function(ClientPtr) MinorOpcode;
    PrivateRec* devPrivates;
}

alias ExtensionEntry = _ExtensionEntry;

/*
 * The arguments may be different for extension event swapping functions.
 * Deal with this by casting when initializing the event's EventSwapVector[]
 * entries.
 */
alias EventSwapPtr = void function(xEvent*, xEvent*);

// EventSwapPtr[128] EventSwapVector;

// noreturn NotImplemented(xEvent*, xEvent*);

// int* AddExtension(const(char)*, int, int, int function(ClientPtr), int function(ClientPtr), void function(_ExtensionEntry*), ushort function(ClientPtr));

// int* CheckExtension(const(char)* extname);
// int* GetExtensionEntry(int major);


private ExtensionEntry** extensions = cast(ExtensionEntry**) null;

int lastEvent = EXTENSION_EVENT_BASE;
private int lastError = FirstExtensionError;
private uint NumExtensions = RESERVED_EXTENSIONS;

struct _ReservedExt { const(char)* name; int id; }
private _ReservedExt[35] reservedExt = [
    { "BIG-REQUESTS",               EXTENSION_MAJOR_BIG_REQUESTS },
    { "Apple-WM",                   EXTENSION_MAJOR_APPLE_WM },
    { "Apple-DRI",                  EXTENSION_MAJOR_APPLE_DRI },
    { "Composite",                  EXTENSION_MAJOR_COMPOSITE },
    { "DAMAGE",                     EXTENSION_MAJOR_DAMAGE },
    { "DOUBLE-BUFFER",              EXTENSION_MAJOR_DOUBLE_BUFFER },
    { "DPMS",                       EXTENSION_MAJOR_DPMS },
    { "DRI2",                       EXTENSION_MAJOR_DRI2 },
    { "DRI3",                       EXTENSION_MAJOR_DRI3 },
    { "Generic Event Extension",    EXTENSION_MAJOR_GENERIC_EVENT },
    { "GLX",                        EXTENSION_MAJOR_GLX },
    { "MIT-SCREEN-SAVER",           EXTENSION_MAJOR_MIT_SCREEN_SAVER },
    { "NAMESPACE",                  EXTENSION_MAJOR_NAMESPACE },
    { "Present",                    EXTENSION_MAJOR_PRESENT },
    { "RANDR",                      EXTENSION_MAJOR_RANDR },
    { "RECORD",                     EXTENSION_MAJOR_RECORD },
    { "RENDER",                     EXTENSION_MAJOR_RENDER },
    { "SECURITY",                   EXTENSION_MAJOR_SECURITY },
    { "SELinux",                    EXTENSION_MAJOR_SELINUX },
    { "SHAPE",                      EXTENSION_MAJOR_SHAPE },
    { "MIT-SHM",                    EXTENSION_MAJOR_SHM },
    { "SYNC",                       EXTENSION_MAJOR_SYNC },
    { "Windows-DRI",                EXTENSION_MAJOR_WINDOWS_DRI },
    { "XFIXES",                     EXTENSION_MAJOR_XFIXES },
    // { "XFree86-Bigfont",            EXTENSION_MAJOR_XF86_BIGFONT },
    { "XFree86-DGA",                EXTENSION_MAJOR_XF86_DGA },
    { "XFree86-DRI",                EXTENSION_MAJOR_XF86_DRI },
    { "XFree86-VidModeExtension",   EXTENSION_MAJOR_XF86_VIDMODE },
    { "XC-MISC",                    EXTENSION_MAJOR_XC_MISC },
    { "XInputExtension",            EXTENSION_MAJOR_XINPUT },
    { "XINERAMA",                   EXTENSION_MAJOR_XINERAMA },
    { "XKEYBOARD",                  EXTENSION_MAJOR_XKEYBOARD },
    { "X-Resource",                 EXTENSION_MAJOR_XRESOURCE },
    { "XTEST",                      EXTENSION_MAJOR_XTEST },
    { "XVideo",                     EXTENSION_MAJOR_XVIDEO },
    { "XVideo-MotionCompensation",  EXTENSION_MAJOR_XVMC }
];

// pragma(msg, ARRAY_SIZE!("reservedExt.ptr"));
// pragma(msg, reservedExt.length);

private int checkReserved(const(char)* name)
{
    for (int i = 0; i< reservedExt.length; i++) {
        if (strcmp(name, reservedExt[i].name) == 0) {
            if (reservedExt[i].id < (RESERVED_EXTENSIONS + EXTENSION_BASE))
                return reservedExt[i].id;
            FatalError("BUG: RESERVED_EXTENSIONS too small for %d\n", reservedExt[i].id);
        }
    }
    return -1;
}

ExtensionEntry* AddExtension(const(char)* name, int NumEvents, int NumErrors, int function(ClientPtr c1) @nogc nothrow MainProc, int function(ClientPtr c2) @nogc nothrow SwappedMainProc , void function(ExtensionEntry* e) CloseDownProc, ushort function(ClientPtr c3) MinorOpcodeProc )
{
    if (!extensions)
        extensions = cast(ExtensionEntry**) calloc(NumExtensions, (ExtensionEntry*).sizeof);
    if (!extensions)
        return null;

    if (!MainProc || !SwappedMainProc || !MinorOpcodeProc)
        return (cast(ExtensionEntry*) null);
    if ((lastEvent + NumEvents > MAXEVENTS) ||
        cast(uint) (lastError + NumErrors > LAST_ERROR)) {
        LogMessage(X_ERROR, "Not enabling extension %s: maximum number of "
                   ~ "events or errors exceeded.\n", name);
        return (cast(ExtensionEntry*) null);
    }
    int i;
    ExtensionEntry* ext = cast(ExtensionEntry*) cast(ExtensionEntry*) calloc(1, ExtensionEntry.sizeof);
    if (!ext)
        return null;
    if (!dixAllocatePrivates(&ext.devPrivates, PRIVATE_EXTENSION))
        goto badalloc;
    ext.name = strdup(name);
    if (!ext.name)
        goto badalloc;

    i = checkReserved(ext.name);
    if (i == -1) {
        i = NumExtensions;
        ExtensionEntry** newexts = cast(ExtensionEntry**)reallocarray(extensions, i + 1, (ExtensionEntry*).sizeof);
        if (!newexts)
            goto badalloc;

        NumExtensions++;
        extensions = newexts;
    } else {
        i = i - EXTENSION_BASE;
    }

    extensions[i] = ext;
    ext.index = i;
    ext.base = i + EXTENSION_BASE;
    ext.CloseDown = assumeNoGC(CloseDownProc);
    ext.MinorOpcode = assumeNoGC(MinorOpcodeProc);
    ProcVector[i + EXTENSION_BASE] = MainProc;
    SwappedProcVector[i + EXTENSION_BASE] = SwappedMainProc;
    if (NumEvents) {
        ext.eventBase = lastEvent;
        ext.eventLast = lastEvent + NumEvents;
        lastEvent += NumEvents;
    }
    else {
        ext.eventBase = 0;
        ext.eventLast = 0;
    }
    if (NumErrors) {
        ext.errorBase = lastError;
        ext.errorLast = lastError + NumErrors;
        lastError += NumErrors;
    }
    else {
        ext.errorBase = 0;
        ext.errorLast = 0;
    }

static if (X_REGISTRY_REQUEST) {
    RegisterExtensionNames(ext);
}
    return ext;

badalloc:
    if (ext) {
        free(cast(char*)ext.name);
        dixFreePrivates(ext.devPrivates, PRIVATE_EXTENSION);
        free(ext);
    }
    return null;
}

/*
 * CheckExtension returns the extensions[] entry for the requested
 * extension name.  Maybe this could just return a Bool instead?
 */
ExtensionEntry* CheckExtension(const(char)* extname)
{
    if (!extensions)
        return null;

    for (int i = 0; i < NumExtensions; i++) {
        if (extensions[i] &&
            extensions[i].name &&
            strcmp(extensions[i].name, extname) == 0) {
            return extensions[i];
        }
    }
    return null;
}

/*
 * Added as part of Xace.
 */
ExtensionEntry* GetExtensionEntry(int major)
{
    if ((major < EXTENSION_BASE) || !extensions)
        return null;
    major -= EXTENSION_BASE;
    if (major >= NumExtensions)
        return null;
    return extensions[major];
}

extern(C)
ushort StandardMinorOpcode(ClientPtr client)
{
    return (cast(xReq*) client.requestBuffer).data;
}

void CloseDownExtensions()
{
    if (!extensions)
        return;

    for (int i = NumExtensions - 1; i >= 0; i--) {
        if (!extensions[i])
            continue;
        if (extensions[i].CloseDown)
            extensions[i].CloseDown(extensions[i]);
        NumExtensions = i;
        free(cast(void*) extensions[i].name);
        dixFreePrivates(extensions[i].devPrivates, PRIVATE_EXTENSION);
        free(extensions[i]);
        extensions[i] = null;
    }
    free(extensions);
    extensions = cast(ExtensionEntry**) null;
    NumExtensions = RESERVED_EXTENSIONS;
    lastEvent = EXTENSION_EVENT_BASE;
    lastError = FirstExtensionError;
}

private Bool ExtensionAvailable(ClientPtr client, ExtensionEntry* ext)
{
    if (!ext)
        return FALSE;

    ExtensionAccessCallbackParam rec = { client, ext, DixGetAttrAccess, Success };
    CallCallbacks(&ExtensionAccessCallback, &rec);
    if (rec.status != Success)
        return FALSE;

    if (!ext.base)
        return FALSE;
    return TRUE;
}

int ProcQueryExtension(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xQueryExtensionReq);
    mixin(X_REQUEST_FIELD_CARD16!"nbytes");
    mixin(REQUEST_FIXED_SIZE!("xQueryExtensionReq", "stuff.nbytes"));

    xQueryExtensionReply reply = { 0 };

    if (NumExtensions && extensions) {
        char[PATH_MAX] extname = 0;
        strncpy(extname.ptr, cast(char*) &stuff[1], min(stuff.nbytes, extname.length - 1));
        ExtensionEntry* extEntry = CheckExtension(extname.ptr);

        if (extEntry && ExtensionAvailable(client, extEntry)) {
            reply.present = cast(ubyte)xTrue;
            reply.major_opcode = cast(ubyte)extEntry.base;
            reply.first_event = cast(ubyte)extEntry.eventBase;
            reply.first_error = cast(ubyte)extEntry.errorBase;
        }
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcListExtensions(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    xListExtensionsReply reply = { 0 };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (NumExtensions && extensions) {
        for (int i = 0; i < NumExtensions; i++) {
            if (!ExtensionAvailable(client, extensions[i]))
                continue;

            int len = cast(int)strlen(extensions[i].name);

            reply.nExtensions++;

            /* write a pascal string */
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)len);
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)extensions[i].name, len);
        }
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
