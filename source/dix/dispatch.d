module dix.dispatch;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

Copyright 1987, 1989, 1998  The Open Group

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

Copyright 1987, 1989 by Digital Equipment Corporation, Maynard, Massachusetts.

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

********************************************************/

/* The panoramix components contained the following notice */
/*****************************************************************

Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
DIGITAL EQUIPMENT CORPORATION BE LIABLE FOR ANY CLAIM, DAMAGES, INCLUDING,
BUT NOT LIMITED TO CONSEQUENTIAL OR INCIDENTAL DAMAGES, OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Digital Equipment Corporation
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization from Digital
Equipment Corporation.

******************************************************************/

/* XSERVER_DTRACE additions:
 * Copyright (c) 2005-2006, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import build.xlibre_server;
import config.version_config;
import Xext.panoramiXsrv;
import core.stdc.stddef;
// //import externs.X11.fonts.fontstruct;
// //import externs.X11.fonts.libxfont2;

import dix.client_priv;
import dix.colormap_priv;
import dix.cursor_priv;
import dix.dix_priv;
import dix.extension_priv;
import dix.input_priv;
import dix.gc_priv;
import dix.registry_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.screenint_priv;
import dix.screensaver_priv;
import dix.selection_priv;
import dix.server_priv;
import dix.settings_priv;
import dix.window_priv;
import include.resource;
import miext.extinit_priv;
import os.auth;
import os.client_priv;
import os.ddx_priv;
import os.osdep;
import os.probes_priv;
import os.screensaver;

import include.windowstr;
import include.dixfontstr;
import include.gcstruct;
import include.cursor;
import include.scrnintstr;
import include.servermd;
import include.extnsionst;
import include.dixfont;
import dix.dispatch;
import dix.swaprep;
import dix.swapreq;
import include.privates;
import Xext.xace;
import include.inputstr;
import include.xkbsrv;
import xfixes.xfixesint;
import dix.dixstruct_priv;
import os.log;
// import os.utils;
import dix.dix_priv;
import dix.extension;
import dix.dixutils;
import externs.X11.fonts.fontstruct;
import externs.X11.fonts.libxfont2;
import dix.gc;
import externs.attrs;
import os.access;
import dix.colormap;
import os.osinit;
import os.io;
import dix.events;
import Xext.xf86bigfont;
import os.WaitFor;
import disconnect;
import dix.dixfonts;
import xf86Events;


import externs.libdbus;

alias INT32_MAX = core.stdc.stdint.INT32_MAX;

alias StartListFontsWithInfoFn = extern(C) int function(
    ClientPtr client,
    int len,
    ubyte* stuff,
    int maxLength
) @nogc nothrow;

enum mskcnt = ((MAXCLIENTS + 31) / 32);
enum string BITMASK(string i) = `(1U << ((` ~ i ~ `) & 31))`;
enum string MASKIDX(string i) = `((` ~ i ~ `) >> 5)`;
enum string MASKWORD(string buf, string i) = buf ~ `[` ~ MASKIDX!(i) ~ `]`;
enum string BITSET(string buf, string i) = MASKWORD!(buf, i) ~ ` |= ` ~ BITMASK!(i)~`;`;
enum string BITCLEAR(string buf, string i) = MASKWORD!(buf, i) ~ ` &= ~` ~ BITMASK!(i)~`;`;
enum string GETBIT(string buf, string i) = `(` ~ MASKWORD!(buf,i) ~ ` & ` ~ BITMASK!(i) ~ `)`;

xConnSetupPrefix connSetupPrefix;

PaddingInfo[33] PixmapWidthPaddingInfo;

private ClientPtr grabClient;
private ClientPtr currentClient; /* Client for the request currently being dispatched */

enum GrabNone = 0;
enum GrabActive = 1;
private int grabState = GrabNone;
private c_long[mskcnt] grabWaiters;
CallbackListPtr ServerGrabCallback = null;
// HWEventQueuePtr[2] checkForInput;
int connBlockScreenStart;



private int nextFreeClientID;    /* always MIN free client ID */

private int nClients;            /* number of authorized clients */

CallbackListPtr ClientStateCallback = null;
CallbackListPtr ServerAccessCallback = null;
CallbackListPtr ClientAccessCallback = null;

OsTimerPtr dispatchExceptionTimer;

/* dispatchException & isItTimeToYield must be declared volatile since they
 * are modified by signal handlers - otherwise optimizer may assume it doesn't
 * need to actually check value in memory when used and may miss changes from
 * signal handlers.
 */
/*volatile*/ char dispatchException = 0;
/*volatile*/ char isItTimeToYield = 0;

enum string SAME_SCREENS(string a, string b) = `(
    (` ~ a ~ `.pScreen == ` ~ b ~ `.pScreen))`;

ClientPtr GetCurrentClient()
{
    if (in_input_thread()) {
        static Bool warned;

        if (!warned) {
            ErrorF("[dix] Error GetCurrentClient called from input-thread\n");
            warned = TRUE;
        }

        return null;
    }

    return currentClient;
}

void UpdateCurrentTime()
{
    /* To avoid time running backwards, we must call GetTimeInMillis before
     * calling ProcessInputEvents.
     */
    TimeStamp systime = {
        months: currentTime.months,
        milliseconds: GetTimeInMillis(),
    };
    if (systime.milliseconds < currentTime.milliseconds)
        systime.months++;
    if (InputCheckPending())
        ProcessInputEvents();
    if (CompareTimeStamps(systime, currentTime) == LATER)
        currentTime = systime;
}

/* Like UpdateCurrentTime, but can't call ProcessInputEvents */
void UpdateCurrentTimeIf()
{
    TimeStamp systime = {
        months: currentTime.months,
        milliseconds: GetTimeInMillis(),
    };
    if (systime.milliseconds < currentTime.milliseconds)
        systime.months++;
    if (CompareTimeStamps(systime, currentTime) == LATER)
        currentTime = systime;
}

/* in milliseconds */
enum SMART_SCHEDULE_DEFAULT_INTERVAL =	5;
enum SMART_SCHEDULE_MAX_SLICE =	15;

static if (HAVE_SETITIMER) {
Bool SmartScheduleSignalEnable = TRUE;
}

c_long SmartScheduleSlice = SMART_SCHEDULE_DEFAULT_INTERVAL;
c_long SmartScheduleInterval = SMART_SCHEDULE_DEFAULT_INTERVAL;
c_long SmartScheduleMaxSlice = SMART_SCHEDULE_MAX_SLICE;
// c_long SmartScheduleTime;
int SmartScheduleLatencyLimited = 0;
private ClientPtr SmartLastClient;
private int[SMART_MAX_PRIORITY - SMART_MIN_PRIORITY + 1] SmartLastIndex;

version (SMART_DEBUG) {
c_long SmartLastPrint;
}



private xorg_list ready_clients;
private xorg_list saved_ready_clients;
xorg_list output_pending_clients;

private void init_client_ready()
{
    xorg_list_init(&ready_clients);
    xorg_list_init(&saved_ready_clients);
    xorg_list_init(&output_pending_clients);
}

Bool clients_are_ready()
{
    return !xorg_list_is_empty(&ready_clients);
}

/* Client has requests queued or data on the network */
void mark_client_ready(ClientPtr client)
{
    if (xorg_list_is_empty(&client.ready))
        xorg_list_append(&client.ready, &ready_clients);
}

/*
 * Client has requests queued or data on the network, but awaits a
 * server grab release
 */
void mark_client_saved_ready(ClientPtr client)
{
    if (xorg_list_is_empty(&client.ready))
        xorg_list_append(&client.ready, &saved_ready_clients);
}

/* Client has no requests queued and no data on network */
void mark_client_not_ready(ClientPtr client)
{
    xorg_list_del(&client.ready);
}

private void mark_client_grab(ClientPtr grab)
{
    ClientPtr client = void, tmp = void;

    mixin(xorg_list_for_each_entry_safe!("client", "tmp", "&ready_clients", "ready", q{
        if (client != grab) {
            xorg_list_del(&client.ready);
            xorg_list_append(&client.ready, &saved_ready_clients);
        }
    }));
}

private void mark_client_ungrab()
{
    ClientPtr client = void, tmp = void;

    mixin(xorg_list_for_each_entry_safe!("client", "tmp", "&saved_ready_clients", "ready", q{
        xorg_list_del(&client.ready);
        xorg_list_append(&client.ready, &ready_clients);
    }));
}

private ClientPtr SmartScheduleClient()
{
    ClientPtr pClient = void, best = null;
    c_long now = SmartScheduleTime;
    int nready = 0;
    int bestRobin = 0;
    c_long idle = 2 * SmartScheduleSlice;

    mixin(xorg_list_for_each_entry!("pClient", "&ready_clients", "ready", q{
        nready++;
        if ((now - pClient.smart_stop_tick) >= idle) {
            if (pClient.smart_priority < 0)
                pClient.smart_priority++;
        }

        int robin = (pClient.index -
             SmartLastIndex[pClient.smart_priority -
                            SMART_MIN_PRIORITY]) & 0xff;

        if (!best ||
            pClient.priority > best.priority ||
            (pClient.priority == best.priority &&
             (pClient.smart_priority > best.smart_priority ||
              (pClient.smart_priority == best.smart_priority && robin > bestRobin))))
        {
            best = pClient;
            bestRobin = robin;
        }
version (SMART_DEBUG) {
        if ((now - SmartLastPrint) >= 5000)
            fprintf(stderr, " %2d: %3d", pClient.index, pClient.smart_priority);
}
    }));
version (SMART_DEBUG) {
    if ((now - SmartLastPrint) >= 5000) {
        fprintf(stderr, " use %2d\n", best.index);
        SmartLastPrint = now;
    }
}
    SmartLastIndex[best.smart_priority - SMART_MIN_PRIORITY] = best.index;
    /*
     * Set current client pointer
     */
    if (SmartLastClient != best) {
        best.smart_start_tick = cast(int)now;
        SmartLastClient = best;
    }
    /*
     * Adjust slice
     */
    if (nready == 1 && SmartScheduleLatencyLimited == 0) {
        /*
         * If it's been a long time since another client
         * has run, bump the slice up to get maximal
         * performance from a single client
         */
        if ((now - best.smart_start_tick) > 1000 &&
            SmartScheduleSlice < SmartScheduleMaxSlice) {
            SmartScheduleSlice += SmartScheduleInterval;
        }
    }
    else {
        SmartScheduleSlice = SmartScheduleInterval;
    }
    return best;
}

private CARD32 DispatchExceptionCallback(OsTimerPtr timer, CARD32 time, void* arg)
{
    dispatchException |= dispatchExceptionAtReset;

    /* Don't re-arm the timer */
    return 0;
}

private void CancelDispatchExceptionTimer()
{
    TimerFree(dispatchExceptionTimer);
    dispatchExceptionTimer = null;
}

private void SetDispatchExceptionTimer()
{
    /* The timer delay is only for terminate, not reset */
    if (!(dispatchExceptionAtReset & DE_TERMINATE)) {
        dispatchException |= dispatchExceptionAtReset;
        return;
    }

    CancelDispatchExceptionTimer();

    if (terminateDelay == 0)
        dispatchException |= dispatchExceptionAtReset;
    else
        dispatchExceptionTimer = TimerSet(dispatchExceptionTimer,
                                          0, terminateDelay * 1000 /* msec */,
                                          &DispatchExceptionCallback,
                                          null);
}

private Bool ShouldDisconnectRemainingClients()
{
    for (int i = 1; i < currentMaxClients; i++) {
        if (clients[i]) {
            if (!XFixesShouldDisconnectClient(clients[i]))
                return FALSE;
        }
    }

    /* All remaining clients can be safely ignored */
    return TRUE;
}

void EnableLimitedSchedulingLatency()
{
    ++SmartScheduleLatencyLimited;
    SmartScheduleSlice = SmartScheduleInterval;
}

void DisableLimitedSchedulingLatency()
{
    --SmartScheduleLatencyLimited;

    /* protect against bugs */
    if (SmartScheduleLatencyLimited < 0)
        SmartScheduleLatencyLimited = 0;
}

void Dispatch()
{
    nextFreeClientID = 1;
    nClients = 0;

    SmartScheduleSlice = SmartScheduleInterval;
    init_client_ready();

    while (!dispatchException) {
        if (InputCheckPending()) {
            ProcessInputEvents();
            FlushIfCriticalOutputPending();
        }

        if (!WaitForSomething(clients_are_ready()))
            continue;

        /*****************
         *  Handle events in round robin fashion, doing input between
         *  each round
         *****************/

        if (!dispatchException && clients_are_ready()) {
            ClientPtr client = SmartScheduleClient();

            isItTimeToYield = FALSE;

            c_long start_tick = SmartScheduleTime;
            while (!isItTimeToYield) {
                if (InputCheckPending())
                    ProcessInputEvents();

                FlushIfCriticalOutputPending();
                if ((SmartScheduleTime - start_tick) >= SmartScheduleSlice)
                {
                    /* Penalize clients which consume ticks */
                    if (client.smart_priority > SMART_MIN_PRIORITY)
                        client.smart_priority--;
                    break;
                }

                /* now, finally, deal with client requests */
                c_long read_result = ReadRequestFromClient(client);
                if (read_result == 0)
                    break;
                else if (read_result == -1) {
                    CloseDownClient(client);
                    break;
                }

                client.sequence++;
                client.majorOp = (cast(xReq*) client.requestBuffer).reqType;
                client.minorOp = 0;
                if (client.majorOp >= EXTENSION_BASE) {
                    ExtensionEntry* ext = GetExtensionEntry(client.majorOp);

                    if (ext)
                        client.minorOp = cast(ubyte)ext.MinorOpcode(client);
                }
version (XSERVER_DTRACE) {
                if (XSERVER_REQUEST_START_ENABLED())
                    XSERVER_REQUEST_START(LookupMajorName(client.majorOp),
                                          client.majorOp,
                                          (cast(xReq*) client.requestBuffer).length,
                                          client.index,
                                          client.requestBuffer);
}
                int result = void;
                if (read_result < 0 || read_result > (maxBigRequestSize << 2))
                    result = BadLength;
                else {
                    result = Success;
                    /* On extension requests, call the extension dispatch hook */
                    if ((client.majorOp >= EXTENSION_BASE) && ExtensionDispatchCallback) {
                        ExtensionEntry* ext = GetExtensionEntry(client.majorOp);
                        if (ext) {
                            ExtensionAccessCallbackParam erec = { client, ext, DixUseAccess, Success };
                            CallCallbacks(&ExtensionDispatchCallback, &erec);
                            result = erec.status;
                        }
                    }
                    if (result == Success) {
                        currentClient = client;
                        result =
                            (*client.requestVector[client.majorOp]) (client);
                        currentClient = null;
                    }
                }
                if (!SmartScheduleSignalEnable)
                    SmartScheduleTime = GetTimeInMillis();

version (XSERVER_DTRACE) {
                if (XSERVER_REQUEST_DONE_ENABLED())
                    XSERVER_REQUEST_DONE(LookupMajorName(client.majorOp),
                                         client.majorOp, client.sequence,
                                         client.index, result);
}

                if (client.noClientException != Success) {
                    CloseDownClient(client);
                    break;
                }
                else if (result != Success) {
                    SendErrorToClient(client, client.majorOp,
                                      client.minorOp,
                                      client.errorValue, cast(ubyte)result);
                    break;
                }
            }
            FlushAllOutput();
            if (client == SmartLastClient)
                client.smart_stop_tick = cast(int)SmartScheduleTime;
        }
        dispatchException &= ~DE_PRIORITYCHANGE;
    }
    ddxBeforeReset();
    KillAllClients();
    SmartScheduleLatencyLimited = 0;
    ResetOsBuffers();
}

Bool CreateConnectionBlock()
{
    xConnSetup setup = void;
    xWindowRoot root = void;
    xDepth depth = void;
    xVisualType visual = void;
    xPixmapFormat format = void;
    c_ulong vid = void;
    int paddingforint32 = void, lenofblock = void, sizesofar = 0;
    char* pBuf = void;
    const(char)[7] VendorString = "Xenia";

    memset(&setup, 0, xConnSetup.sizeof);
    /* Leave off the ridBase and ridMask, these must be sent with
       connection */

    setup.release = VENDOR_RELEASE;
    /*
     * per-server image and bitmap parameters are defined in Xmd.h
     */
    setup.imageByteOrder = cast(ubyte)screenInfo.imageByteOrder;

    setup.bitmapScanlineUnit = cast(ubyte)screenInfo.bitmapScanlineUnit;
    setup.bitmapScanlinePad = cast(ubyte)screenInfo.bitmapScanlinePad;

    setup.bitmapBitOrder = cast(ubyte)screenInfo.bitmapBitOrder;
    setup.motionBufferSize = NumMotionEvents();
    setup.numRoots = cast(ubyte)screenInfo.numScreens;
    setup.nbytesVendor = cast(ushort)strlen(VendorString.ptr);
    setup.numFormats = cast(ubyte)screenInfo.numPixmapFormats;
    setup.maxRequestSize = MAX_REQUEST_SIZE;
    QueryMinMaxKeyCodes(&setup.minKeyCode, &setup.maxKeyCode);

    lenofblock = cast(int)((xConnSetup).sizeof +
        pad_to_int32(setup.nbytesVendor) +
        cast(uint)(setup.numFormats * xPixmapFormat.sizeof) +
        cast(uint)(setup.numRoots * xWindowRoot.sizeof));
    ConnectionInfo = cast(char*)calloc(1, lenofblock);
    if (!ConnectionInfo)
        return FALSE;

    memcpy(ConnectionInfo, &setup, xConnSetup.sizeof);
    sizesofar = xConnSetup.sizeof;
    pBuf = ConnectionInfo + xConnSetup.sizeof;

    memcpy(pBuf, VendorString.ptr, cast(size_t) setup.nbytesVendor);
    sizesofar += setup.nbytesVendor;
    pBuf += setup.nbytesVendor;
    paddingforint32 = padding_for_int32(setup.nbytesVendor);
    sizesofar += paddingforint32;
    while (--paddingforint32 >= 0)
        *pBuf++ = 0;

    memset(&format, 0, xPixmapFormat.sizeof);
    for (int i = 0; i < screenInfo.numPixmapFormats; i++) {
        format.depth = screenInfo.formats[i].depth;
        format.bitsPerPixel = screenInfo.formats[i].bitsPerPixel;
        format.scanLinePad = screenInfo.formats[i].scanlinePad;
        memcpy(pBuf, &format, xPixmapFormat.sizeof);
        pBuf += xPixmapFormat.sizeof;
        sizesofar += xPixmapFormat.sizeof;
    }

    connBlockScreenStart = sizesofar;
    memset(&depth, 0, xDepth.sizeof);
    memset(&visual, 0, xVisualType.sizeof);

    mixin(DIX_FOR_EACH_SCREEN!q{
        DepthPtr pDepth = void;
        VisualPtr pVisual = void;

        root.windowId = cast(uint)walkScreen.root.drawable.id;
        root.defaultColormap = cast(uint)walkScreen.defColormap;
        root.whitePixel = cast(uint)walkScreen.whitePixel;
        root.blackPixel = cast(uint)walkScreen.blackPixel;
        root.currentInputMask = 0;      /* filled in when sent */
        root.pixWidth = walkScreen.width;
        root.pixHeight = walkScreen.height;
        root.mmWidth = walkScreen.mmWidth;
        root.mmHeight = walkScreen.mmHeight;
        root.minInstalledMaps = walkScreen.minInstalledCmaps;
        root.maxInstalledMaps = walkScreen.maxInstalledCmaps;
        root.rootVisualID = cast(uint)walkScreen.rootVisual;
        root.backingStore = walkScreen.backingStoreSupport;
        root.saveUnders = FALSE;
        root.rootDepth = cast(ubyte)walkScreen.rootDepth;
        root.nDepths = cast(ubyte)walkScreen.numDepths;
        memcpy(pBuf, &root, xWindowRoot.sizeof);
        sizesofar += xWindowRoot.sizeof;
        pBuf += xWindowRoot.sizeof;

        pDepth = walkScreen.allowedDepths;
        for (int j = 0; j < walkScreen.numDepths; j++, pDepth++) {
            lenofblock += ((xDepth).sizeof +
                (pDepth.numVids * xVisualType.sizeof));
            pBuf = cast(char*) realloc(ConnectionInfo, lenofblock);
            if (!pBuf) {
                free(ConnectionInfo);
                return FALSE;
            }
            ConnectionInfo = pBuf;
            pBuf += sizesofar;
            depth.depth = pDepth.depth;
            depth.nVisuals = pDepth.numVids;
            memcpy(pBuf, &depth, xDepth.sizeof);
            pBuf += xDepth.sizeof;
            sizesofar += xDepth.sizeof;
            for (int k = 0; k < pDepth.numVids; k++) {
                vid = pDepth.vids[k];
                for (pVisual = walkScreen.visuals;
                     pVisual.vid != vid; pVisual++){}
                visual.visualID = cast(uint)vid;
                visual.class_ = cast(ubyte)pVisual.class_;
                visual.bitsPerRGB = cast(ubyte)pVisual.bitsPerRGBValue;
                visual.colormapEntries = pVisual.ColormapEntries;
                visual.redMask = cast(uint)pVisual.redMask;
                visual.greenMask = cast(uint)pVisual.greenMask;
                visual.blueMask = cast(uint)pVisual.blueMask;
                memcpy(pBuf, &visual, xVisualType.sizeof);
                pBuf += xVisualType.sizeof;
                sizesofar += xVisualType.sizeof;
            }
        }
    });
    connSetupPrefix.success = xTrue;
    connSetupPrefix.length = cast(ushort)(lenofblock / 4);
    connSetupPrefix.majorVersion = X_PROTOCOL;
    connSetupPrefix.minorVersion = X_PROTOCOL_REVISION;
    return TRUE;
}

int DoCreateWindowReq(ClientPtr client, xCreateWindowReq* stuff, XID* xids)
{
    mixin(LEGAL_NEW_RESOURCE!("stuff.wid", "client"));

    WindowPtr pParent = void;
    int rc = dixLookupWindow(&pParent, stuff.parent, client, DixAddAccess);
    if (rc != Success)
        return rc;
    if (!stuff.width || !stuff.height) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }
    WindowPtr pWin = dixCreateWindow(stuff.wid, pParent, stuff.x,
                        stuff.y, stuff.width, stuff.height,
                        stuff.borderWidth, stuff.class_,
                        stuff.mask, cast(XID*) xids,
                        cast(int) stuff.depth, client, stuff.visual, &rc);
    if (pWin) {
        Mask mask = pWin.eventMask;

        pWin.eventMask = 0;    /* subterfuge in case AddResource fails */
        if (!AddResource(cast(uint)stuff.wid, X11_RESTYPE_WINDOW, cast(void*) pWin))
            return BadAlloc;
        pWin.eventMask = mask;
    }
    return rc;
}

int ProcCreateWindow(ClientPtr client)
{
    mixin(REQUEST!xCreateWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateWindowReq);

    int len = cast(int)(client.req_len - bytes_to_int32(xCreateWindowReq.sizeof));
    if (Ones(stuff.mask) != len)
        return BadLength;

    return DoCreateWindowReq(client, stuff, cast(XID*)&stuff[1]);
}

int ProcChangeWindowAttributes(ClientPtr client)
{
    mixin(REQUEST!xChangeWindowAttributesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeWindowAttributesReq);
    Mask access_mode = (stuff.valueMask & CWEventMask) ? DixReceiveAccess : 0;
    access_mode |= (stuff.valueMask & ~CWEventMask) ? DixSetAttrAccess : 0;

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, access_mode);
    if (rc != Success)
        return rc;
    int len = cast(int)(client.req_len - bytes_to_int32(xChangeWindowAttributesReq.sizeof));
    if (len != Ones(stuff.valueMask))
        return BadLength;
    return ChangeWindowAttributes(pWin,
                                  stuff.valueMask, cast(XID*) &stuff[1], client);
}

int ProcDestroyWindow(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.id, client, DixDestroyAccess);
    if (rc != Success)
        return rc;
    if (pWin.parent) {
        rc = dixLookupWindow(&pWin, pWin.parent.drawable.id, client,
                             DixRemoveAccess);
        if (rc != Success)
            return rc;
        FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
    }
    return Success;
}

int ProcDestroySubwindows(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.id, client, DixRemoveAccess);
    if (rc != Success)
        return rc;
    DestroySubwindows(pWin, client);
    return Success;
}

int ProcChangeSaveSet(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xChangeSaveSetReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeSaveSetReq);

    if (client.swapped)
        swapl(&stuff.window);

    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixManageAccess);
    if (rc != Success)
        return rc;
    if (client.clientAsMask == (CLIENT_BITS(pWin.drawable.id)))
        return BadMatch;
    if ((stuff.mode == SetModeInsert) || (stuff.mode == SetModeDelete))
        return AlterSaveSetForClient(client, pWin, stuff.mode, FALSE, TRUE);
    client.errorValue = cast(uint)stuff.mode;
    return BadValue;
}

int ProcReparentWindow(ClientPtr client)
{
    mixin(REQUEST!xReparentWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xReparentWindowReq);

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixManageAccess);
    if (rc != Success)
        return rc;

    WindowPtr pParent = void;
    rc = dixLookupWindow(&pParent, stuff.parent, client, DixAddAccess);
    if (rc != Success)
        return rc;
    if (!mixin(SAME_SCREENS!(`pWin.drawable`, `pParent.drawable`)))
        return BadMatch;
    if ((pWin.backgroundState == ParentRelative) &&
        (pParent.drawable.depth != pWin.drawable.depth))
        return BadMatch;
    if ((pWin.drawable.class_ != InputOnly) &&
        (pParent.drawable.class_ == InputOnly))
        return BadMatch;
    return ReparentWindow(pWin, pParent,
                          cast(short) stuff.x, cast(short) stuff.y, client);
}

int ProcMapWindow(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.id, client, DixShowAccess);
    if (rc != Success)
        return rc;
    MapWindow(pWin, client);
    /* update cache to say it is mapped */
    return Success;
}

int ProcMapSubwindows(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.id, client, DixListAccess);
    if (rc != Success)
        return rc;
    MapSubwindows(pWin, client);
    /* update cache to say it is mapped */
    return Success;
}

int ProcUnmapWindow(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.id, client, DixHideAccess);
    if (rc != Success)
        return rc;
    UnmapWindow(pWin, FALSE);
    /* update cache to say it is mapped */
    return Success;
}

int ProcUnmapSubwindows(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.id, client, DixListAccess);
    if (rc != Success)
        return rc;
    UnmapSubwindows(pWin);
    return Success;
}

int ProcConfigureWindow(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xConfigureWindowReq);
    int len = void, rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xConfigureWindowReq);
    rc = dixLookupWindow(&pWin, stuff.window, client,
                         DixManageAccess | DixSetAttrAccess);
    if (rc != Success)
        return rc;
    len = cast(int)(client.req_len - bytes_to_int32(xConfigureWindowReq.sizeof));
    if (Ones(cast(Mask) stuff.mask) != len)
        return BadLength;
    return ConfigureWindow(pWin, cast(Mask) stuff.mask, cast(XID*) &stuff[1], client);
}

int ProcCirculateWindow(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xCirculateWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCirculateWindowReq);

    if (client.swapped)
        swapl(&stuff.window);

    int rc = void;

    if ((stuff.direction != RaiseLowest) && (stuff.direction != LowerHighest)) {
        client.errorValue = cast(uint)stuff.direction;
        return BadValue;
    }
    rc = dixLookupWindow(&pWin, stuff.window, client, DixManageAccess);
    if (rc != Success)
        return rc;
    CirculateWindow(pWin, cast(int) stuff.direction, client);
    return Success;
}

int ProcGetGeometry(ClientPtr client)
{
    DrawablePtr pDraw = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupDrawable(&pDraw, stuff.id, client, M_ANY, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xGetGeometryReply reply = {
        root: cast(uint)pDraw.pScreen.root.drawable.id,
        depth: pDraw.depth,
        width: pDraw.width,
        height: pDraw.height,
    };

    if (mixin(WindowDrawable!("pDraw.type"))) {
        WindowPtr pWin = cast(WindowPtr) pDraw;

        reply.x = cast(short)(pWin.origin.x - mixin(wBorderWidth!("pWin")));
        reply.y = cast(short)(pWin.origin.y - mixin(wBorderWidth!("pWin")));
        reply.borderWidth = pWin.borderWidth;
    }

    if (client.swapped) {
        swapl(&reply.root);
        swaps(&reply.x);
        swaps(&reply.y);
        swaps(&reply.width);
        swaps(&reply.height);
        swaps(&reply.borderWidth);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcQueryTree(ClientPtr client)
{
    int rc = void;
    WindowPtr pWin = void, pHead = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupWindow(&pWin, stuff.id, client, DixListAccess);
    if (rc != Success)
        return rc;

    pHead = RealChildHead(pWin);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    CARD32 numChildren = 0;
    for (WindowPtr pChild = pWin.lastChild; pChild != pHead; pChild = pChild.prevSib) {
        x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pChild.drawable.id);
        numChildren++;
    }

    xQueryTreeReply reply = {
        root: cast(uint)pWin.drawable.pScreen.root.drawable.id,
        parent: cast(uint)((pWin.parent) ? pWin.parent.drawable.id : cast(Window) None),
        nChildren: cast(ushort)numChildren,
    };

    if (client.swapped) {
        swapl(&reply.root);
        swapl(&reply.parent);
        swaps(&reply.nChildren);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcInternAtom(ClientPtr client)
{
    Atom atom = void;
    char* tchar = void;

    mixin(REQUEST!xInternAtomReq);
    mixin(REQUEST_AT_LEAST_SIZE!xInternAtomReq);
    if (client.swapped)
        swaps(&stuff.nbytes);

    mixin(REQUEST_FIXED_SIZE!("xInternAtomReq", "stuff.nbytes"));
    if ((stuff.onlyIfExists != xTrue) && (stuff.onlyIfExists != xFalse)) {
        client.errorValue = cast(uint)stuff.onlyIfExists;
        return BadValue;
    }
    tchar = cast(char*) &stuff[1];
    atom = MakeAtom(tchar, stuff.nbytes, !stuff.onlyIfExists);
    if (atom == BAD_RESOURCE)
        return BadAlloc;

    xInternAtomReply reply = {
        atom: cast(uint)atom
    };

    if (client.swapped) {
        swapl(&reply.atom);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcGetAtomName(ClientPtr client)
{
    const(char)* str = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    if (((str = NameForAtom(stuff.id)) is null)) {
        client.errorValue = cast(uint)stuff.id;
        return BadAtom;
    }

    const(int) len = cast(int)strlen(str);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)str, len);

    xGetAtomNameReply reply = {
        nameLength: cast(ushort)len
    };

    if (client.swapped) {
        swaps(&reply.nameLength);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcGrabServer(ClientPtr client)
{
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xReq);
    if (grabState != GrabNone && client != grabClient) {
        ResetCurrentRequest(client);
        client.sequence--;
        mixin(BITSET!(`grabWaiters`, `client.index`));
        IgnoreClient(client);
        return Success;
    }
    rc = OnlyListenToOneClient(client);
    if (rc != Success)
        return rc;
    grabState = GrabActive;
    grabClient = client;
    mark_client_grab(client);

    if (ServerGrabCallback) {
        ServerGrabInfoRec grabinfo = void;

        grabinfo.client = client;
        grabinfo.grabstate = SERVER_GRABBED;
        CallCallbacks(&ServerGrabCallback, cast(void*) &grabinfo);
    }

    return Success;
}

private void UngrabServer(ClientPtr client)
{
    int i = void;

    grabState = GrabNone;
    grabClient = null;
    ListenToAllClients();
    mark_client_ungrab();
    for (i = mskcnt; --i >= 0 && !grabWaiters[i];){}
    if (i >= 0) {
        i <<= 5;
        while (!mixin(GETBIT!(`grabWaiters`, `i`)))
            i++;
        mixin(BITCLEAR!(`grabWaiters`, `i`));
        AttendClient(clients[i]);
    }

    if (ServerGrabCallback) {
        ServerGrabInfoRec grabinfo = void;

        grabinfo.client = client;
        grabinfo.grabstate = SERVER_UNGRABBED;
        CallCallbacks(&ServerGrabCallback, cast(void*) &grabinfo);
    }
}

int ProcUngrabServer(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);
    UngrabServer(client);
    return Success;
}

int ProcTranslateCoords(ClientPtr client)
{
    mixin(REQUEST!xTranslateCoordsReq);

    WindowPtr pWin = void, pDst = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xTranslateCoordsReq);
    rc = dixLookupWindow(&pWin, stuff.srcWid, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;
    rc = dixLookupWindow(&pDst, stuff.dstWid, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xTranslateCoordsReply reply = { 0 };
    if (!mixin(SAME_SCREENS!(`pWin.drawable`, `pDst.drawable`))) {
        reply.sameScreen = xFalse;
        reply.child = None;
        reply.dstX = reply.dstY = 0;
    }
    else {
        INT16 x = void, y = void;

        reply.sameScreen = xTrue;
        reply.child = None;
        /* computing absolute coordinates -- adjust to destination later */
        x = cast(ushort)(pWin.drawable.x + stuff.srcX);
        y = cast(ushort)(pWin.drawable.y + stuff.srcY);
        pWin = pDst.firstChild;
        while (pWin) {
            BoxRec box = void;

            if ((pWin.mapped) &&
                (x >= pWin.drawable.x - mixin(wBorderWidth!("pWin"))) &&
                (x < pWin.drawable.x + cast(int) pWin.drawable.width +
                 mixin(wBorderWidth!("pWin"))) &&
                (y >= pWin.drawable.y - mixin(wBorderWidth!("pWin"))) &&
                (y < pWin.drawable.y + cast(int) pWin.drawable.height +
                 mixin(wBorderWidth!("pWin")))
                /* When a window is shaped, a further check
                 * is made to see if the point is inside
                 * borderSize
                 */
                && (!mixin(wBoundingShape!("pWin")) ||
                    RegionContainsPoint(&pWin.borderSize, x, y, &box))

                && (!mixin(wInputShape!("pWin")) ||
                    RegionContainsPoint(mixin(wInputShape!("pWin")),
                                        x - pWin.drawable.x,
                                        y - pWin.drawable.y, &box))
                ) {
                reply.child = cast(uint)pWin.drawable.id;
                pWin = cast(WindowPtr) null;
            }
            else
                pWin = pWin.nextSib;
        }
        /* adjust to destination coordinates */
        reply.dstX = cast(ushort)(x - pDst.drawable.x);
        reply.dstY = cast(ushort)(y - pDst.drawable.y);
    }

    if (client.swapped) {
        swapl(&reply.child);
        swaps(&reply.dstX);
        swaps(&reply.dstY);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcOpenFont(ClientPtr client)
{
    int err = void;

    mixin(REQUEST!xOpenFontReq);

    mixin(REQUEST_FIXED_SIZE!("xOpenFontReq", "stuff.nbytes"));
    client.errorValue = cast(uint)stuff.fid;
    mixin(LEGAL_NEW_RESOURCE!("stuff.fid", "client"));
    err = OpenFont(client, stuff.fid, cast(Mask) 0,
                   stuff.nbytes, cast(char*) &stuff[1]);
    if (err == Success) {
        return Success;
    }
    else
        return err;
}

int ProcCloseFont(ClientPtr client)
{
    FontPtr pFont = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pFont, stuff.id, X11_RESTYPE_FONT,
                                 client, DixDestroyAccess);
    if (rc == Success) {
        FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.id;
        return rc;
    }
}

int ProcQueryFont(ClientPtr client)
{
    xQueryFontReply* reply = void;
    FontPtr pFont = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupFontable(&pFont, stuff.id, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    {
        xCharInfo* pmax = mixin(FONTINKMAX!("pFont"));
        xCharInfo* pmin = mixin(FONTINKMIN!("pFont"));
        int nprotoxcistructs = void;
        int rlength = void;

        nprotoxcistructs = (pmax.rightSideBearing == pmin.rightSideBearing &&
                            pmax.leftSideBearing == pmin.leftSideBearing &&
                            pmax.descent == pmin.descent &&
                            pmax.ascent == pmin.ascent &&
                            pmax.characterWidth == pmin.characterWidth) ?
            0 : mixin(N2dChars!("pFont"));

        rlength = cast(uint)((xQueryFontReply).sizeof +
            mixin(FONTINFONPROPS!(FONTCHARSET!(`pFont`))) * (xFontProp).sizeof +
            (nprotoxcistructs * xCharInfo.sizeof));
        reply = cast(xQueryFontReply*) calloc(1, rlength);
        if (!reply) {
            return BadAlloc;
        }

        reply.type = X_Reply;
        reply.length = bytes_to_int32(rlength - xGenericReply.sizeof);
        reply.sequenceNumber = cast(ushort)client.sequence;
        QueryFont(pFont, reply, nprotoxcistructs);

        if (client.swapped) {
            SwapFont(reply, TRUE);
        }

        WriteToClient(client, rlength, reply);
        free(reply);
        return Success;
    }
}

int ProcQueryTextExtents(ClientPtr client)
{
    FontPtr pFont = void;
    ExtentInfoRec info = void;
    c_ulong length = void;
    int rc = void;

    mixin(REQUEST!xQueryTextExtentsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xQueryTextExtentsReq);

    if (client.swapped)
        swapl(&stuff.fid);

    rc = dixLookupFontable(&pFont, stuff.fid, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    length = client.req_len - bytes_to_int32(xQueryTextExtentsReq.sizeof);
    length = length << 1;
    if (stuff.oddLength) {
        if (length == 0)
            return BadLength;
        length--;
    }
    if (!assumeNoGC(&xfont2_query_text_extents)(pFont, length, cast(ubyte*) &stuff[1], &info))
        return BadAlloc;

    xQueryTextExtentsReply reply = {
        drawDirection: cast(ubyte)info.drawDirection,
        fontAscent: cast(short)info.fontAscent,
        fontDescent: cast(short)info.fontDescent,
        overallAscent: cast(short)info.overallAscent,
        overallDescent: cast(short)info.overallDescent,
        overallWidth: info.overallWidth,
        overallLeft: info.overallLeft,
        overallRight: info.overallRight
    };

    if (client.swapped) {
        swaps(&reply.fontAscent);
        swaps(&reply.fontDescent);
        swaps(&reply.overallAscent);
        swaps(&reply.overallDescent);
        swapl(&reply.overallWidth);
        swapl(&reply.overallLeft);
        swapl(&reply.overallRight);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcListFonts(ClientPtr client)
{
    mixin(REQUEST!xListFontsReq);

    mixin(REQUEST_FIXED_SIZE!("xListFontsReq", "stuff.nbytes"));

    return ListFonts(client, cast(ubyte*) &stuff[1], stuff.nbytes,
                     stuff.maxNames);
}

int ProcListFontsWithInfo(ClientPtr client)
{
    mixin(REQUEST!xListFontsWithInfoReq);

    mixin(REQUEST_FIXED_SIZE!("xListFontsWithInfoReq", "stuff.nbytes"));

    return dix.dixfonts.StartListFontsWithInfo(client, stuff.nbytes,
                                  cast(ubyte*) &stuff[1], stuff.maxNames);
}

/**
 *
 *  \param value must conform to DeleteType
 */
int dixDestroyPixmap(void* value, XID pid)
{
    PixmapPtr pPixmap = cast(PixmapPtr) value;
    if (pPixmap && pPixmap.refcnt == 1)
        dixScreenRaisePixmapDestroy(pPixmap);
    if (pPixmap && pPixmap.drawable.pScreen && pPixmap.drawable.pScreen.DestroyPixmap)
        return pPixmap.drawable.pScreen.DestroyPixmap(pPixmap);
    return TRUE;
}

int ProcCreatePixmap(ClientPtr client)
{
    PixmapPtr pMap = void;
    DrawablePtr pDraw = void;

    mixin(REQUEST!xCreatePixmapReq);
    DepthPtr pDepth = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCreatePixmapReq);
    client.errorValue = cast(uint)stuff.pid;
    mixin(LEGAL_NEW_RESOURCE!("stuff.pid", "client"));

    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, M_ANY,
                           DixGetAttrAccess);
    if (rc != Success)
        return rc;

    if (!stuff.width || !stuff.height) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }
    if (stuff.width > 32767 || stuff.height > 32767) {
        /* It is allowed to try and allocate a pixmap which is larger than
         * 32767 in either dimension. However, all of the framebuffer code
         * is buggy and does not reliably draw to such big pixmaps, basically
         * because the Region data structure operates with signed shorts
         * for the rectangles in it.
         *
         * Furthermore, several places in the X server computes the
         * size in bytes of the pixmap and tries to store it in an
         * integer. This integer can overflow and cause the allocated size
         * to be much smaller.
         *
         * So, such big pixmaps are rejected here with a BadAlloc
         */
        return BadAlloc;
    }
    if (stuff.depth != 1) {
        pDepth = pDraw.pScreen.allowedDepths;
        for (int i = 0; i < pDraw.pScreen.numDepths; i++, pDepth++)
            if (pDepth.depth == stuff.depth)
                goto CreatePmap;
        client.errorValue = cast(uint)stuff.depth;
        return BadValue;
    }
 CreatePmap:
    pMap = cast(PixmapPtr) (*pDraw.pScreen.CreatePixmap)
        (pDraw.pScreen, stuff.width, stuff.height, stuff.depth, 0);
    if (pMap) {
        pMap.drawable.serialNumber = NEXT_SERIAL_NUMBER;
        pMap.drawable.id = stuff.pid;
        /* security creation/labeling check */
        rc = XaceHookResourceAccess(client, stuff.pid, X11_RESTYPE_PIXMAP,
                      pMap, X11_RESTYPE_NONE, null, DixCreateAccess);
        if (rc != Success) {
            dixDestroyPixmap(pMap, 0);
            return rc;
        }
        if (AddResource(cast(uint)stuff.pid, X11_RESTYPE_PIXMAP, cast(void*) pMap))
            return Success;
    }
    return BadAlloc;
}

int ProcFreePixmap(ClientPtr client)
{
    PixmapPtr pMap = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pMap, stuff.id, X11_RESTYPE_PIXMAP,
                                 client, DixDestroyAccess);
    if (rc == Success) {
        FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.id;
        return rc;
    }
}

int ProcCreateGC(ClientPtr client)
{
    int error = void, rc = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;
    uint len = void;

    mixin(REQUEST!xCreateGCReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCreateGCReq);
    client.errorValue = cast(uint)stuff.gc;
    mixin(LEGAL_NEW_RESOURCE!("stuff.gc", "client"));
    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, 0,
                           DixGetAttrAccess);
    if (rc != Success)
        return rc;

    len = cast(int)(client.req_len - bytes_to_int32(xCreateGCReq.sizeof));
    if (len != Ones(stuff.mask))
        return BadLength;
    pGC = cast(GCPtr) CreateGC(pDraw, stuff.mask, cast(XID*) &stuff[1], &error,
                          stuff.gc, client);
    if (error != Success)
        return error;
    if (!AddResource(cast(uint)stuff.gc, X11_RESTYPE_GC, cast(void*) pGC))
        return BadAlloc;
    return Success;
}

int ProcChangeGC(ClientPtr client)
{
    GCPtr pGC = void;
    int result = void;
    uint len = void;

    mixin(REQUEST!xChangeGCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeGCReq);

    result = dixLookupGC(&pGC, stuff.gc, client, DixSetAttrAccess);
    if (result != Success)
        return result;

    len = cast(int)(client.req_len - bytes_to_int32(xChangeGCReq.sizeof));
    if (len != Ones(stuff.mask))
        return BadLength;

    return ChangeGCXIDs(client, pGC, stuff.mask, cast(CARD32*) &stuff[1]);
}

int ProcCopyGC(ClientPtr client)
{
    GCPtr dstGC = void;
    GCPtr pGC = void;
    int result = void;

    mixin(REQUEST!xCopyGCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCopyGCReq);

    result = dixLookupGC(&pGC, stuff.srcGC, client, DixGetAttrAccess);
    if (result != Success)
        return result;
    result = dixLookupGC(&dstGC, stuff.dstGC, client, DixSetAttrAccess);
    if (result != Success)
        return result;
    if ((dstGC.pScreen != pGC.pScreen) || (dstGC.depth != pGC.depth))
        return BadMatch;
    if (stuff.mask & ~GCAllBits) {
        client.errorValue = cast(uint)stuff.mask;
        return BadValue;
    }
    return CopyGC(pGC, dstGC, stuff.mask);
}

int ProcSetDashes(ClientPtr client)
{
    GCPtr pGC = void;
    int result = void;

    mixin(REQUEST!xSetDashesReq);

    mixin(REQUEST_FIXED_SIZE!("xSetDashesReq", "stuff.nDashes"));
    if (stuff.nDashes == 0) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }

    result = dixLookupGC(&pGC, stuff.gc, client, DixSetAttrAccess);
    if (result != Success)
        return result;

    /* If there's an error, either there's no sensible errorValue,
     * or there was a dash segment of 0. */
    client.errorValue = cast(uint)0;
    return SetDashes(pGC, stuff.dashOffset, stuff.nDashes,
                     cast(ubyte*) &stuff[1]);
}

int ProcSetClipRectangles(ClientPtr client)
{
    int result = void;
    GCPtr pGC = void;

    mixin(REQUEST!xSetClipRectanglesReq);

    mixin(REQUEST_AT_LEAST_SIZE!xSetClipRectanglesReq);
    if ((stuff.ordering != Unsorted) && (stuff.ordering != YSorted) &&
        (stuff.ordering != YXSorted) && (stuff.ordering != YXBanded)) {
        client.errorValue = cast(uint)stuff.ordering;
        return BadValue;
    }
    result = dixLookupGC(&pGC, stuff.gc, client, DixSetAttrAccess);
    if (result != Success)
        return result;

    size_t nr = ((client.req_len << 2)) - xSetClipRectanglesReq.sizeof;
    if (nr & 4)
        return BadLength;
    nr >>= 3;
    return SetClipRects(pGC, stuff.xOrigin, stuff.yOrigin,
                        nr, cast(xRectangle*) &stuff[1], stuff.ordering);
}

int ProcFreeGC(ClientPtr client)
{
    GCPtr pGC = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupGC(&pGC, stuff.id, client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
    return Success;
}

int ProcClearToBackground(ClientPtr client)
{
    mixin(REQUEST!xClearAreaReq);
    WindowPtr pWin = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xClearAreaReq);
    rc = dixLookupWindow(&pWin, stuff.window, client, DixWriteAccess);
    if (rc != Success)
        return rc;
    if (pWin.drawable.class_ == InputOnly) {
        client.errorValue = cast(uint)stuff.window;
        return BadMatch;
    }
    if ((stuff.exposures != xTrue) && (stuff.exposures != xFalse)) {
        client.errorValue = cast(uint)stuff.exposures;
        return BadValue;
    }
    (*pWin.drawable.pScreen.ClearToBackground) (pWin, stuff.x, stuff.y,
                                                  stuff.width, stuff.height,
                                                  cast(Bool) stuff.exposures);
    return Success;
}

/* send GraphicsExpose events, or a NoExpose event, based on the region */
void SendGraphicsExpose(ClientPtr client, RegionPtr pRgn, XID drawable, CARD8 major, CARD16 minor)
{
    if (pRgn && !RegionNil(pRgn)) {
        xEvent* pEvent = void;
        xEvent* pe = void;
        BoxPtr pBox = void;
        int numRects = void;

        numRects = RegionNumRects(pRgn);
        pBox = RegionRects(pRgn);
        if (((pEvent = cast(xEvent*) calloc(numRects, xEvent.sizeof)) is null))
            return;
        pe = pEvent;

        for (int i = 1; i <= numRects; i++, pe++, pBox++) {
            pe.u.u.type = GraphicsExpose;
            pe.u.graphicsExposure.drawable = cast(uint)drawable;
            pe.u.graphicsExposure.x = pBox.x1;
            pe.u.graphicsExposure.y = pBox.y1;
            pe.u.graphicsExposure.width = cast(ushort)(pBox.x2 - pBox.x1);
            pe.u.graphicsExposure.height = cast(ushort)(pBox.y2 - pBox.y1);
            pe.u.graphicsExposure.count = cast(ushort)(numRects - i);
            pe.u.graphicsExposure.majorEvent = major;
            pe.u.graphicsExposure.minorEvent = minor;
        }
        /* GraphicsExpose is a "critical event", which TryClientEvents
         * handles specially. */
        TryClientEvents(client, null, pEvent, numRects,
                        cast(Mask) 0, NoEventMask, NullGrab);
        free(pEvent);
    }
    else {
        // xEvent event = {
        //     u:noExposure:drawable: drawable,
        //     u:noExposure:majorEvent: major,
        //     u:noExposure:minorEvent: minor
        // };
        xEvent event;
            event.u.noExposure.drawable = cast(uint)drawable;
            event.u.noExposure.majorEvent = major;
            event.u.noExposure.minorEvent = minor;        
        event.u.u.type = NoExpose;
        WriteEventsToClient(client, 1, &event);
    }
}

int ProcCopyArea(ClientPtr client)
{
    DrawablePtr pDst = void;
    DrawablePtr pSrc = void;
    GCPtr pGC = void;

    mixin(REQUEST!xCopyAreaReq);
    RegionPtr pRgn = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCopyAreaReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.dstDrawable", "pDst", "DixWriteAccess"));
    if (stuff.dstDrawable != stuff.srcDrawable) {
        rc = dixLookupDrawable(&pSrc, stuff.srcDrawable, client, 0,
                               DixReadAccess);
        if (rc != Success)
            return rc;
        if ((pDst.pScreen != pSrc.pScreen) || (pDst.depth != pSrc.depth)) {
            client.errorValue = cast(uint)stuff.dstDrawable;
            return BadMatch;
        }
    }
    else
        pSrc = pDst;

    pRgn = (*pGC.ops.CopyArea) (pSrc, pDst, pGC, stuff.srcX, stuff.srcY,
                                  stuff.width, stuff.height,
                                  stuff.dstX, stuff.dstY);
    if (pGC.graphicsExposures) {
        SendGraphicsExpose(client, pRgn, stuff.dstDrawable, X_CopyArea, 0);
        if (pRgn)
            RegionDestroy(pRgn);
    }

    return Success;
}

int ProcCopyPlane(ClientPtr client)
{
    DrawablePtr psrcDraw = void, pdstDraw = void;
    GCPtr pGC = void;

    mixin(REQUEST!xCopyPlaneReq);
    RegionPtr pRgn = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCopyPlaneReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.dstDrawable", "pdstDraw", "DixWriteAccess"));
    if (stuff.dstDrawable != stuff.srcDrawable) {
        rc = dixLookupDrawable(&psrcDraw, stuff.srcDrawable, client, 0,
                               DixReadAccess);
        if (rc != Success)
            return rc;

        if (pdstDraw.pScreen != psrcDraw.pScreen) {
            client.errorValue = cast(uint)stuff.dstDrawable;
            return BadMatch;
        }
    }
    else
        psrcDraw = pdstDraw;

    /* Check to see if stuff->bitPlane has exactly ONE good bit set */
    if (stuff.bitPlane == 0 || (stuff.bitPlane & (stuff.bitPlane - 1)) ||
        (stuff.bitPlane > (1L << (psrcDraw.depth - 1)))) {
        client.errorValue = cast(uint)stuff.bitPlane;
        return BadValue;
    }

    pRgn =
        (*pGC.ops.CopyPlane) (psrcDraw, pdstDraw, pGC, stuff.srcX,
                                stuff.srcY, stuff.width, stuff.height,
                                stuff.dstX, stuff.dstY, stuff.bitPlane);
    if (pGC.graphicsExposures) {
        SendGraphicsExpose(client, pRgn, stuff.dstDrawable, X_CopyPlane, 0);
        if (pRgn)
            RegionDestroy(pRgn);
    }
    return Success;
}

int ProcPolyPoint(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int npoint = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    if ((stuff.coordMode != CoordModeOrigin) &&
        (stuff.coordMode != CoordModePrevious)) {
        client.errorValue = cast(uint)stuff.coordMode;
        return BadValue;
    }
    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    npoint = cast(int)bytes_to_int32(((client.req_len << 2)) - xPolyPointReq.sizeof);
    if (npoint)
        (*pGC.ops.PolyPoint) (pDraw, pGC, stuff.coordMode, npoint,
                                cast(xPoint*) &stuff[1]);
    return Success;
}

int ProcPolyLine(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int npoint = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    if ((stuff.coordMode != CoordModeOrigin) &&
        (stuff.coordMode != CoordModePrevious)) {
        client.errorValue = cast(uint)stuff.coordMode;
        return BadValue;
    }
    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    npoint = cast(int)bytes_to_int32(((client.req_len << 2)) - xPolyLineReq.sizeof);
    if (npoint > 1)
        (*pGC.ops.Polylines) (pDraw, pGC, stuff.coordMode, npoint,
                                cast(DDXPointPtr) &stuff[1]);
    return Success;
}

int ProcPolySegment(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int nsegs = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    nsegs = cast(int)(((client.req_len << 2)) - xPolySegmentReq.sizeof);
    if (nsegs & 4)
        return BadLength;
    nsegs >>= 3;
    if (nsegs)
        (*pGC.ops.PolySegment) (pDraw, pGC, nsegs, cast(xSegment*) &stuff[1]);
    return Success;
}

int ProcPolyRectangle(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int nrects = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    nrects = cast(int)((client.req_len << 2) - xPolyRectangleReq.sizeof);
    if (nrects & 4)
        return BadLength;
    nrects >>= 3;
    if (nrects)
        (*pGC.ops.PolyRectangle) (pDraw, pGC,
                                    nrects, cast(xRectangle*) &stuff[1]);
    return Success;
}

int ProcPolyArc(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int narcs = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    narcs = cast(int)((client.req_len << 2) - xPolyArcReq.sizeof);
    if (narcs % xArc.sizeof)
        return BadLength;
    narcs /= xArc.sizeof;
    if (narcs)
        (*pGC.ops.PolyArc) (pDraw, pGC, narcs, cast(xArc*) &stuff[1]);
    return Success;
}

int ProcFillPoly(ClientPtr client)
{
    int things = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(REQUEST!xFillPolyReq);

    mixin(REQUEST_AT_LEAST_SIZE!xFillPolyReq);
    if ((stuff.shape != Complex) && (stuff.shape != Nonconvex) &&
        (stuff.shape != Convex)) {
        client.errorValue = cast(uint)stuff.shape;
        return BadValue;
    }
    if ((stuff.coordMode != CoordModeOrigin) &&
        (stuff.coordMode != CoordModePrevious)) {
        client.errorValue = cast(uint)stuff.coordMode;
        return BadValue;
    }

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    things = cast(int)bytes_to_int32(((client.req_len << 2)) - xFillPolyReq.sizeof);
    if (things)
        (*pGC.ops.FillPolygon) (pDraw, pGC, stuff.shape,
                                  stuff.coordMode, things,
                                  cast(DDXPointPtr) &stuff[1]);
    return Success;
}

int ProcPolyFillRectangle(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int things = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    things = cast(int)((client.req_len << 2)) - cast(int)xPolyFillRectangleReq.sizeof;
    if (things & 4)
        return BadLength;
    things >>= 3;

    if (things)
        (*pGC.ops.PolyFillRect) (pDraw, pGC, things,
                                   cast(xRectangle*) &stuff[1]);
    return Success;
}

int ProcPolyFillArc(ClientPtr client)
{
    mixin(REQUEST!xPolyPointReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        mixin(SwapRestS!("stuff"));
    }

    int narcs = void;
    GCPtr pGC = void;
    DrawablePtr pDraw = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    narcs = cast(int)((client.req_len << 2)) - cast(int)xPolyFillArcReq.sizeof;
    if (narcs % xArc.sizeof)
        return BadLength;
    narcs /= xArc.sizeof;
    if (narcs)
        (*pGC.ops.PolyFillArc) (pDraw, pGC, narcs, cast(xArc*) &stuff[1]);
    return Success;
}

// version (MATCH_CLIENT_ENDIAN) {

// int ServerOrder()
// {
//     int whichbyte = 1;

//     if (*(cast(char*) &whichbyte))
//         return LSBFirst;
//     return MSBFirst;
// }

// enum string ClientOrder(string client) = `((` ~ client ~ `).swapped ? !ServerOrder() : ServerOrder())`;

// void ReformatImage(char* base, int nbytes, int bpp, int order)
// {
//     switch (bpp) {
//     case 1:                    /* yuck */
//         if (BITMAP_BIT_ORDER != order)
//             BitOrderInvert(cast(ubyte*) base, nbytes);
// static if (IMAGE_BYTE_ORDER != BITMAP_BIT_ORDER && BITMAP_SCANLINE_UNIT != 8) {
//         ReformatImage(base, nbytes, BITMAP_SCANLINE_UNIT, order);
// }
//         break;
//     case 4:
//         break;                  /* yuck */
//     case 8:
//         break;
//     case 16:
//         if (IMAGE_BYTE_ORDER != order)
//             TwoByteSwap(cast(ubyte*) base, nbytes);
//         break;
//     case 32:
//         if (IMAGE_BYTE_ORDER != order)
//             FourByteSwap(cast(ubyte*) base, nbytes);
//         break;
//     default: break;}
// }
// } else {
// //#define ReformatImage(b,n,bpp,o)
// }

/* 64-bit server notes: the protocol restricts padding of images to
 * 8-, 16-, or 32-bits. We would like to have 64-bits for the server
 * to use internally. Removes need for internal alignment checking.
 * All of the PutImage functions could be changed individually, but
 * as currently written, they call other routines which require things
 * to be 64-bit padded on scanlines, so we changed things here.
 * If an image would be padded differently for 64- versus 32-, then
 * copy each scanline to a 64-bit padded scanline.
 * Also, we need to make sure that the image is aligned on a 64-bit
 * boundary, even if the scanlines are padded to our satisfaction.
 */
int ProcPutImage(ClientPtr client)
{
    GCPtr pGC = void;
    DrawablePtr pDraw = void;
    c_long length = void;                /* length of scanline server padded */
    c_long lengthProto = void;           /* length of scanline protocol padded */
    char* tmpImage = void;

    mixin(REQUEST!xPutImageReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPutImageReq);
    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    if (stuff.format == XYBitmap) {
        if ((stuff.depth != 1) ||
            (stuff.leftPad >= cast(uint) screenInfo.bitmapScanlinePad))
            return BadMatch;
        length = mixin(BitmapBytePad!("stuff.width + stuff.leftPad"));
    }
    else if (stuff.format == XYPixmap) {
        if ((pDraw.depth != stuff.depth) ||
            (stuff.leftPad >= cast(uint) screenInfo.bitmapScanlinePad))
            return BadMatch;
        length = mixin(BitmapBytePad!("stuff.width + stuff.leftPad"));
        length *= stuff.depth;
    }
    else if (stuff.format == ZPixmap) {
        if ((pDraw.depth != stuff.depth) || (stuff.leftPad != 0))
            return BadMatch;
        length = PixmapBytePad(stuff.width, stuff.depth);
    }
    else {
        client.errorValue = cast(uint)stuff.format;
        return BadValue;
    }

    tmpImage = cast(char*) &stuff[1];
    lengthProto = length;

    if (stuff.height != 0 && lengthProto >= (INT32_MAX / stuff.height))
        return BadLength;

    if ((bytes_to_int32(lengthProto * stuff.height) +
         bytes_to_int32(xPutImageReq.sizeof)) != client.req_len)
        return BadLength;

    // ReformatImage(tmpImage, lengthProto * stuff.height,
    //               stuff.format == ZPixmap ? BitsPerPixel(stuff.depth) : 1,
    //               mixin(ClientOrder!(`client`)));

    (*pGC.ops.PutImage) (pDraw, pGC, stuff.depth, stuff.dstX, stuff.dstY,
                           stuff.width, stuff.height,
                           stuff.leftPad, stuff.format, tmpImage);

    return Success;
}

/* size of buffer to use with GetImage, measured in bytes. There's obviously
 * a trade-off between the amount of heap used and the number of times the
 * ddx routine has to be called.
 */
enum IMAGE_BUFSIZE =                (64*1024);

private int DoGetImage(ClientPtr client, int format, Drawable drawable, int x, int y, int width, int height, Mask planemask)
{
    DrawablePtr pDraw = void, pBoundingDraw = void;
    int linesPerBuf = void, rc = void;
    int linesDone = void;

    /* coordinates relative to the bounding drawable */
    int relx = void, rely = void;
    c_long widthBytesLine = void, length = void;
    Mask plane = 0;
    RegionPtr pVisibleRegion = null;

    if ((format != XYPixmap) && (format != ZPixmap)) {
        client.errorValue = cast(uint)format;
        return BadValue;
    }
    rc = dixLookupDrawable(&pDraw, drawable, client, 0, DixReadAccess);
    if (rc != Success)
        return rc;

    xGetImageReply reply = { 0 };

    relx = x;
    rely = y;

    if (pDraw.type == DRAWABLE_WINDOW) {
        WindowPtr pWin = cast(WindowPtr) pDraw;

        /* "If the drawable is a window, the window must be viewable ... or a
         * BadMatch error results" */
        if (!pWin.viewable)
            return BadMatch;

        /* If the drawable is a window, the rectangle must be contained within
         * its bounds (including the border). */
        if (x < -mixin(wBorderWidth!"pWin")||
            x + width > mixin(wBorderWidth!"pWin")+ cast(int) pDraw.width ||
            y < -mixin(wBorderWidth!"pWin")||
            y + height > mixin(wBorderWidth!"pWin")+ cast(int) pDraw.height)
            return BadMatch;

        relx += pDraw.x;
        rely += pDraw.y;

        if (pDraw.pScreen.GetWindowPixmap) {
            PixmapPtr pPix = (*pDraw.pScreen.GetWindowPixmap) (pWin);

            pBoundingDraw = &pPix.drawable;
            relx -= pPix.screen_x;
            rely -= pPix.screen_y;
        }
        else {
            pBoundingDraw = cast(DrawablePtr) pDraw.pScreen.root;
        }

        reply.visual = cast(uint)mixin(wVisual!("pWin"));
    }
    else {
        pBoundingDraw = pDraw;
        reply.visual = None;
    }

    /* "If the drawable is a pixmap, the given rectangle must be wholly
     *  contained within the pixmap, or a BadMatch error results.  If the
     *  drawable is a window [...] it must be the case that if there were no
     *  inferiors or overlapping windows, the specified rectangle of the window
     *  would be fully visible on the screen and wholly contained within the
     *  outside edges of the window, or a BadMatch error results."
     *
     * We relax the window case slightly to mean that the rectangle must exist
     * within the bounds of the window's backing pixmap.  In particular, this
     * means that a GetImage request may succeed or fail with BadMatch depending
     * on whether any of its ancestor windows are redirected.  */
    if (relx < 0 || relx + width > cast(int) pBoundingDraw.width ||
        rely < 0 || rely + height > cast(int) pBoundingDraw.height)
        return BadMatch;

    reply.depth = pDraw.depth;
    if (format == ZPixmap) {
        widthBytesLine = PixmapBytePad(width, pDraw.depth);
        length = widthBytesLine * height;
    }
    else {
        widthBytesLine = mixin(BitmapBytePad!("width"));
        plane = (cast(Mask) 1) << (pDraw.depth - 1);
        /* only planes asked for */
        length = widthBytesLine * height *
            Ones(planemask & (plane | (plane - 1)));
    }

    reply.length = bytes_to_int32(length);

    if (widthBytesLine == 0 || height == 0)
        linesPerBuf = 0;
    else if (widthBytesLine >= IMAGE_BUFSIZE)
        linesPerBuf = 1;
    else {
        linesPerBuf = IMAGE_BUFSIZE / widthBytesLine;
        if (linesPerBuf > height)
            linesPerBuf = height;
    }
    length = linesPerBuf * widthBytesLine;
    if (linesPerBuf < height) {
        /* we have to make sure intermediate buffers don't need padding */
        while ((linesPerBuf > 1) &&
               (length & ((1L << LOG2_BYTES_PER_SCANLINE_PAD) - 1))) {
            linesPerBuf--;
            length -= widthBytesLine;
        }
        while (length & ((1L << LOG2_BYTES_PER_SCANLINE_PAD) - 1)) {
            linesPerBuf++;
            length += widthBytesLine;
        }
    }

    if (pDraw.type == DRAWABLE_WINDOW) {
        pVisibleRegion = &(cast(WindowPtr) pDraw).borderClip;
        pDraw.pScreen.SourceValidate(pDraw, x, y, width, height,
                                       IncludeInferiors);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (linesPerBuf == 0) {
        /* nothing to do */
    }
    else if (format == ZPixmap) {
        linesDone = 0;
        while (height - linesDone > 0) {
            size_t nlines = min(linesPerBuf, height - linesDone);

            char* pBuf = cast(char*)x_rpcbuf_reserve(&rpcbuf, (nlines * widthBytesLine));
            if (!pBuf) {
                x_rpcbuf_clear(&rpcbuf);
                return BadAlloc;
            }

            (*pDraw.pScreen.GetImage) (pDraw,
                                         x,
                                         y + linesDone,
                                         width,
                                         cast(int)nlines,
                                         format, planemask, cast(char*) pBuf);
            if (pVisibleRegion)
                XaceCensorImage(client, pVisibleRegion, widthBytesLine,
                                pDraw, x, y + linesDone, width,
                                cast(int)nlines, format, pBuf);

            /* Note that we DO NOT byte swap here */
            // ReformatImage(pBuf, cast(int) (nlines * widthBytesLine),
            //               BitsPerPixel(pDraw.depth), mixin(ClientOrder!(`client`)));

            linesDone += nlines;
        }
    }
    else {                      /* XYPixmap */

        for (; plane; plane >>= 1) {
            if (planemask & plane) {
                linesDone = 0;
                while (height - linesDone > 0) {
                    size_t nlines = min(linesPerBuf, height - linesDone);

                    char* pBuf = cast(char*)x_rpcbuf_reserve(&rpcbuf, (nlines * widthBytesLine));
                    if (!pBuf) {
                        x_rpcbuf_clear(&rpcbuf);
                        return BadAlloc;
                    }

                    (*pDraw.pScreen.GetImage) (pDraw,
                                                 x,
                                                 y + linesDone,
                                                 width,
                                                 cast(int)nlines,
                                                 format, plane, cast(char*) pBuf);
                    if (pVisibleRegion)
                        XaceCensorImage(client, pVisibleRegion,
                                        widthBytesLine,
                                        pDraw, x, y + linesDone, width,
                                        cast(int)nlines, format, pBuf);

                    /* Note that we DO NOT byte swap here */
                    // ReformatImage(pBuf, cast(int) (nlines * widthBytesLine),
                    //               1, mixin(ClientOrder!(`client`)));

                    linesDone += nlines;
                }
            }
        }
    }

    if (client.swapped) {
        swapl(&reply.visual);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcGetImage(ClientPtr client)
{
    mixin(REQUEST!xGetImageReq);

    mixin(REQUEST_AT_LEAST_SIZE!xGetImageReq);

    return DoGetImage(client, stuff.format, stuff.drawable,
                      stuff.x, stuff.y,
                      cast(int) stuff.width, cast(int) stuff.height,
                      stuff.planeMask);
}

int ProcPolyText(ClientPtr client)
{
    mixin(REQUEST!xPolyTextReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPolyTextReq);

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.gc);
        swaps(&stuff.x);
        swaps(&stuff.y);
    }

    DrawablePtr pDraw = void;
    GCPtr pGC = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));

    return PolyText(client,
                   pDraw,
                   pGC,
                   cast(ubyte*) &stuff[1],
                   (cast(ubyte*) stuff) + ((client.req_len << 2)),
                   stuff.x, stuff.y, stuff.reqType, stuff.drawable);
}

int ProcImageText8(ClientPtr client)
{
    DrawablePtr pDraw = void;
    GCPtr pGC = void;

    mixin(REQUEST!xImageTextReq);

    mixin(REQUEST_FIXED_SIZE!("xImageTextReq", "stuff.nChars"));
    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));

    return ImageText(client,
                    pDraw,
                    pGC,
                    stuff.nChars,
                    cast(ubyte*) &stuff[1],
                    stuff.x, stuff.y, stuff.reqType, stuff.drawable);
}

int ProcImageText16(ClientPtr client)
{
    DrawablePtr pDraw = void;
    GCPtr pGC = void;

    mixin(REQUEST!xImageTextReq);

   mixin(REQUEST_FIXED_SIZE!("xImageTextReq", "stuff.nChars << 1"));
    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));

    return ImageText(client,
                    pDraw,
                    pGC,
                    stuff.nChars,
                    cast(ubyte*) &stuff[1],
                    stuff.x, stuff.y, stuff.reqType, stuff.drawable);
}

int ProcCreateColormap(ClientPtr client)
{
    VisualPtr pVisual = void;
    ColormapPtr pmap = void;
    Colormap mid = void;
    WindowPtr pWin = void;
    ScreenPtr pScreen = void;

    mixin(REQUEST!xCreateColormapReq);
    int i = void, result = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCreateColormapReq);

    if ((stuff.alloc != AllocNone) && (stuff.alloc != AllocAll)) {
        client.errorValue = cast(uint)stuff.alloc;
        return BadValue;
    }
    mid = stuff.mid;
    mixin(LEGAL_NEW_RESOURCE!("mid", "client"));
    result = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (result != Success)
        return result;

    pScreen = pWin.drawable.pScreen;
    for (i = 0, pVisual = pScreen.visuals;
         i < pScreen.numVisuals; i++, pVisual++) {
        if (pVisual.vid != stuff.visual)
            continue;
        return dixCreateColormap(mid, pScreen, pVisual, &pmap,
                                 cast(int) stuff.alloc, client);
    }
    client.errorValue = cast(uint)stuff.visual;
    return BadMatch;
}

int ProcFreeColormap(ClientPtr client)
{
    ColormapPtr pmap = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pmap, stuff.id, X11_RESTYPE_COLORMAP,
                                 client, DixDestroyAccess);
    if (rc == Success) {
        /* Freeing a default colormap is a no-op */
        if (!(pmap.flags & CM_IsDefault))
            FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.id;
        return rc;
    }
}

int ProcCopyColormapAndFree(ClientPtr client)
{
    Colormap mid = void;
    ColormapPtr pSrcMap = void;

    mixin(REQUEST!xCopyColormapAndFreeReq);
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCopyColormapAndFreeReq);
    mid = stuff.mid;
    mixin(LEGAL_NEW_RESOURCE!("mid", "client"));
    rc = dixLookupResourceByType(cast(void**) &pSrcMap, stuff.srcCmap,
                                 X11_RESTYPE_COLORMAP, client,
                                 DixReadAccess | DixRemoveAccess);
    if (rc == Success)
        return CopyColormapAndFree(mid, pSrcMap, client.index);
    client.errorValue = cast(uint)stuff.srcCmap;
    return rc;
}

int ProcInstallColormap(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.id, X11_RESTYPE_COLORMAP,
                                 client, DixInstallAccess);
    if (rc != Success)
        goto out_;

    rc = dixCallScreenAccessCallback(client, pcmp.pScreen, DixSetAttrAccess);
    if (rc != Success) {
        if (rc == BadValue)
            rc = BadColor;
        goto out_;
    }

    (*(pcmp.pScreen.InstallColormap)) (pcmp);
    return Success;

 out_:
    client.errorValue = cast(uint)stuff.id;
    return rc;
}

int ProcUninstallColormap(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.id, X11_RESTYPE_COLORMAP,
                                 client, DixUninstallAccess);
    if (rc != Success)
        goto out_;

    rc = dixCallScreenAccessCallback(client, pcmp.pScreen, DixSetAttrAccess);
    if (rc != Success) {
        if (rc == BadValue)
            rc = BadColor;
        goto out_;
    }

    if (pcmp.mid != pcmp.pScreen.defColormap)
        (*(pcmp.pScreen.UninstallColormap)) (pcmp);
    return Success;

 out_:
    client.errorValue = cast(uint)stuff.id;
    return rc;
}

int ProcListInstalledColormaps(ClientPtr client)
{
    int rc = void;
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupWindow(&pWin, stuff.id, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    rc = dixCallScreenAccessCallback(client, pWin.drawable.pScreen, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    Colormap* cm = cast(Colormap*) calloc(pWin.drawable.pScreen.maxInstalledCmaps,
                          Colormap.sizeof);
    if (!cm)
        return BadAlloc;

    ScreenPtr pScreen = pWin.drawable.pScreen;
    const(int) nummaps = pScreen.ListInstalledColormaps(pScreen, cm);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, cm, nummaps); /* Colormap is an XID, thus CARD32  */
    free(cm);

    xListInstalledColormapsReply reply = {
        nColormaps: cast(ushort)nummaps,
    };

    if (client.swapped) {
        swaps(&reply.nColormaps);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int dixAllocColor(ClientPtr client, Colormap cmap, CARD16* red, CARD16* green, CARD16* blue, CARD32* pixel)
{
    ColormapPtr pmap = void;
    int rc = dixLookupResourceByType(cast(void**) &pmap,
                                     cmap,
                                     X11_RESTYPE_COLORMAP,
                                     client,
                                     DixAddAccess);
    if (rc != Success)
        return rc;

    return AllocColor(pmap, red, green, blue, pixel, client.index);
}

int ProcAllocColor(ClientPtr client)
{
    mixin(REQUEST!xAllocColorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorReq);

    if (client.swapped) {
        swapl(&stuff.cmap);
        swaps(&stuff.red);
        swaps(&stuff.green);
        swaps(&stuff.blue);
    }

    xAllocColorReply reply = {
        red: stuff.red,
        green: stuff.green,
        blue: stuff.blue,
    };

    int rc = dixAllocColor(client, stuff.cmap,
                           &reply.red, &reply.green, &reply.blue, &reply.pixel);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }

    if (client.swapped) {
        swaps(&reply.red);
        swaps(&reply.green);
        swaps(&reply.blue);
        swapl(&reply.pixel);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcAllocNamedColor(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xAllocNamedColorReq);

    mixin(REQUEST_FIXED_SIZE!("xAllocNamedColorReq", "stuff.nbytes"));
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixAddAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }

    xAllocNamedColorReply reply = { 0 };

    if (!dixLookupBuiltinColor
            (cast(char*) &stuff[1], stuff.nbytes,
             &reply.exactRed, &reply.exactGreen, &reply.exactBlue))
        return BadName;

    reply.screenRed = reply.exactRed;
    reply.screenGreen = reply.exactGreen;
    reply.screenBlue = reply.exactBlue;

    if ((rc = AllocColor(pcmp,
                         &reply.screenRed,
                         &reply.screenGreen,
                         &reply.screenBlue,
                         &reply.pixel,
                         client.index)) != 0)
        return rc;

    if (client.swapped) {
        swapl(&reply.pixel);
        swaps(&reply.exactRed);
        swaps(&reply.exactGreen);
        swaps(&reply.exactBlue);
        swaps(&reply.screenRed);
        swaps(&reply.screenGreen);
        swaps(&reply.screenBlue);
    }

static if(XINERAMA){
    if (noPanoramiXExtension || !pcmp.pScreen.myNum)
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    return Success;
} else {
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
} /* XINERAMA */
}

int ProcAllocColorCells(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xAllocColorCellsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorCellsReq);
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixAddAccess);
    if (rc == Success) {
        int npixels = void, nmasks = void;
        c_long length = void;
        Pixel* pmasks = void;

        npixels = stuff.colors;
        if (!npixels) {
            client.errorValue = cast(uint)npixels;
            return BadValue;
        }
        if (stuff.contiguous != xTrue && stuff.contiguous != xFalse) {
            client.errorValue = cast(uint)stuff.contiguous;
            return BadValue;
        }
        nmasks = stuff.planes;
        length = (cast(c_long) npixels + cast(c_long) nmasks) * Pixel.sizeof;

        x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

        Pixel* ppixels = cast(uint*)x_rpcbuf_reserve(&rpcbuf, length);
        if (!ppixels)
            return BadAlloc;
        pmasks = ppixels + npixels;

        if ((rc = AllocColorCells(client, pcmp, npixels, nmasks,
                                  cast(Bool) stuff.contiguous, ppixels, pmasks)) != 0) {
            x_rpcbuf_clear(&rpcbuf);
            return rc;
        }
static if(XINERAMA){
        if (noPanoramiXExtension || !pcmp.pScreen.myNum) /* XINERAMA */
        {
            xAllocColorCellsReply reply = {
                nPixels: cast(ushort)npixels,
                nMasks: cast(ushort)nmasks
            };
            if (client.swapped) {
                swaps(&reply.nPixels);
                swaps(&reply.nMasks);
                SwapLongs(ppixels, length / 4);
            }

            return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
        }
}

        else {
             xAllocColorCellsReply reply = {
                nPixels: cast(ushort)npixels,
                nMasks: cast(ushort)nmasks
            };
            if (client.swapped) {
                swaps(&reply.nPixels);
                swaps(&reply.nMasks);
                SwapLongs(ppixels, length / 4);
            }

            return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
        }
        x_rpcbuf_clear(&rpcbuf);
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcAllocColorPlanes(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xAllocColorPlanesReq);

    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorPlanesReq);
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixAddAccess);
    if (rc == Success) {
        int npixels = void;
        c_long length = void;

        npixels = stuff.colors;
        if (!npixels) {
            client.errorValue = cast(uint)npixels;
            return BadValue;
        }
        if (stuff.contiguous != xTrue && stuff.contiguous != xFalse) {
            client.errorValue = cast(uint)stuff.contiguous;
            return BadValue;
        }

        xAllocColorPlanesReply reply = {
            nPixels: cast(ushort)npixels
        };
        length = cast(c_long) npixels *Pixel.sizeof;

        x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
        Pixel* ppixels = cast(uint*)x_rpcbuf_reserve(&rpcbuf, length);
        if (!ppixels)
            return BadAlloc;
        if ((rc = AllocColorPlanes(client.index, pcmp, npixels,
                                   cast(int) stuff.red, cast(int) stuff.green,
                                   cast(int) stuff.blue, cast(Bool) stuff.contiguous,
                                   ppixels, &reply.redMask, &reply.greenMask,
                                   &reply.blueMask)) != 0) {
            x_rpcbuf_clear(&rpcbuf);
            return rc;
        }

        if (client.swapped) {
            SwapLongs(ppixels, length / 4);
            swaps(&reply.nPixels);
            swapl(&reply.redMask);
            swapl(&reply.greenMask);
            swapl(&reply.blueMask);
        }

static if(XINERAMA){
        if (noPanoramiXExtension || !pcmp.pScreen.myNum) /* XINERAMA */
        {
            return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
        }
}
else {
            return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
        x_rpcbuf_clear(&rpcbuf);
        return Success;

    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcFreeColors(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xFreeColorsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xFreeColorsReq);
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixRemoveAccess);
    if (rc == Success) {
        int count = void;

        if (pcmp.flags & CM_AllAllocated)
            return BadAccess;
        count = cast(int)bytes_to_int32(((client.req_len << 2)) - xFreeColorsReq.sizeof);
        return FreeColors(pcmp, client.index, count,
                          cast(Pixel*) &stuff[1], cast(Pixel) stuff.planeMask);
    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcStoreColors(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xStoreColorsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xStoreColorsReq);
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixWriteAccess);
    if (rc == Success) {
        int count = void;

        count = cast(int)((client.req_len << 2) - cast(uint)xStoreColorsReq.sizeof);
        if (count % xColorItem.sizeof)
            return BadLength;
        count /= xColorItem.sizeof;
        return StoreColors(pcmp, count, cast(xColorItem*) &stuff[1], client);
    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcStoreNamedColor(ClientPtr client)
{
    ColormapPtr pcmp = void;
    int rc = void;

    mixin(REQUEST!xStoreNamedColorReq);

    mixin(REQUEST_FIXED_SIZE!("xStoreNamedColorReq", "stuff.nbytes"));
    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixWriteAccess);
    if (rc == Success) {
        xColorItem def = void;

        if (dixLookupBuiltinColor(cast(char*) &stuff[1],
                                  stuff.nbytes,
                                  &def.red,
                                  &def.green,
                                  &def.blue)) {
            def.flags = stuff.flags;
            def.pixel = stuff.pixel;
            return StoreColors(pcmp, 1, &def, client);
        }
        return BadName;
    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcQueryColors(ClientPtr client)
{
    mixin(REQUEST!xQueryColorsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xQueryColorsReq);

    if (client.swapped) {
        swapl(&stuff.cmap);
        mixin(SwapRestL!("stuff"));
    }

    ColormapPtr pcmp = void;
    int rc = void;

    rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixReadAccess);
    if (rc == Success) {
        int count = void;
        count =
            cast(int)bytes_to_int32(((client.req_len << 2)) - xQueryColorsReq.sizeof);

        x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
        xrgb* prgbs = cast(xrgb*)x_rpcbuf_reserve(&rpcbuf, count * xrgb.sizeof);
        if (!prgbs && count)
            return BadAlloc;
        if ((rc =
             QueryColors(pcmp, count, cast(Pixel*) &stuff[1], prgbs, client)) != 0) {
            x_rpcbuf_clear(&rpcbuf);
            return rc;
        }

        xQueryColorsReply reply = {
            nColors: cast(ushort)count
        };

        if (client.swapped) {
            swaps(&reply.nColors);
            SwapShorts(cast(short*)prgbs, count * 4); // xrgb = 4 shorts
        }

        return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
    }
    else {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }
}

int ProcLookupColor(ClientPtr client)
{
    mixin(REQUEST!xLookupColorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xLookupColorReq);

    if (client.swapped) {
        swapl(&stuff.cmap);
        swaps(&stuff.nbytes);
    }

    mixin(REQUEST_FIXED_SIZE!("xLookupColorReq", "stuff.nbytes"));

    ColormapPtr pcmp = void;
    int rc = dixLookupResourceByType(cast(void**) &pcmp, stuff.cmap, X11_RESTYPE_COLORMAP,
                                 client, DixReadAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.cmap;
        return rc;
    }

    CARD16 exactRed = void, exactGreen = void, exactBlue = void;
    if (!dixLookupBuiltinColor(cast(char*) &stuff[1],
                               stuff.nbytes,
                               &exactRed,
                               &exactGreen,
                               &exactBlue))
        return BadName;

    xLookupColorReply reply = {
        exactRed: exactRed,
        exactGreen: exactGreen,
        exactBlue: exactBlue,
        screenRed: exactRed,
        screenGreen: exactGreen,
        screenBlue: exactBlue
    };

    pcmp.pScreen.ResolveColor(&reply.screenRed,
                                &reply.screenGreen,
                                &reply.screenBlue,
                                pcmp.pVisual);

    if (client.swapped) {
        swaps(&reply.exactRed);
        swaps(&reply.exactGreen);
        swaps(&reply.exactBlue);
        swaps(&reply.screenRed);
        swaps(&reply.screenGreen);
        swaps(&reply.screenBlue);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcCreateCursor(ClientPtr client)
{
    CursorPtr pCursor = void;
    PixmapPtr src = void;
    PixmapPtr msk = void;
    ubyte* srcbits = void;
    ushort width = void, height = void;
    c_long n = void;
    CursorMetricRec cm = void;
    int rc = void;

    mixin(REQUEST!xCreateCursorReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCreateCursorReq);
    mixin(LEGAL_NEW_RESOURCE!("stuff.cid", "client"));

    rc = dixLookupResourceByType(cast(void**) &src, stuff.source, X11_RESTYPE_PIXMAP,
                                 client, DixReadAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.source;
        return rc;
    }

    if (src.drawable.depth != 1)
        return (BadMatch);

    /* Find and validate cursor mask pixmap, if one is provided */
    if (stuff.mask != None) {
        rc = dixLookupResourceByType(cast(void**) &msk, stuff.mask, X11_RESTYPE_PIXMAP,
                                     client, DixReadAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.mask;
            return rc;
        }

        if (src.drawable.width != msk.drawable.width
            || src.drawable.height != msk.drawable.height
            || src.drawable.depth != 1 || msk.drawable.depth != 1)
            return BadMatch;
    }
    else
        msk = null;

    width = src.drawable.width;
    height = src.drawable.height;

    if (stuff.x > width || stuff.y > height)
        return BadMatch;

    srcbits = cast(ubyte*) calloc(mixin(BitmapBytePad!("width")), height);
    if (!srcbits)
        return BadAlloc;
    n = mixin(BitmapBytePad!("width")) * height;

    ubyte* mskbits = cast(ubyte*) calloc(1, n);
    if (!mskbits) {
        free(srcbits);
        return BadAlloc;
    }

    (*src.drawable.pScreen.GetImage) (cast(DrawablePtr) src, 0, 0, width, height,
                                        XYPixmap, 1, cast(char*) srcbits);
    if (msk == cast(PixmapPtr) null) {
        ubyte* bits = mskbits;

        while (--n >= 0)
            *bits++ = ubyte.max;
    }
    else {
        /* zeroing the (pad) bits helps some ddx cursor handling */
        memset(cast(char*) mskbits, 0, n);
        (*msk.drawable.pScreen.GetImage) (cast(DrawablePtr) msk, 0, 0, width,
                                            height, XYPixmap, 1,
                                            cast(char*) mskbits);
    }
    cm.width = width;
    cm.height = height;
    cm.xhot = stuff.x;
    cm.yhot = stuff.y;
    rc = AllocARGBCursor(srcbits, mskbits, null, &cm,
                         stuff.foreRed, stuff.foreGreen, stuff.foreBlue,
                         stuff.backRed, stuff.backGreen, stuff.backBlue,
                         &pCursor, client, stuff.cid);

    if (rc != Success)
        goto bail;
    if (!AddResource(cast(uint)stuff.cid, X11_RESTYPE_CURSOR, cast(void*) pCursor)) {
        rc = BadAlloc;
        goto bail;
    }

    return Success;
 bail:
    free(srcbits);
    free(mskbits);
    return rc;
}

int ProcCreateGlyphCursor(ClientPtr client)
{
    mixin(REQUEST!xCreateGlyphCursorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateGlyphCursorReq);

    if (client.swapped) {
        swapl(&stuff.cid);
        swapl(&stuff.source);
        swapl(&stuff.mask);
        swaps(&stuff.sourceChar);
        swaps(&stuff.maskChar);
        swaps(&stuff.foreRed);
        swaps(&stuff.foreGreen);
        swaps(&stuff.foreBlue);
        swaps(&stuff.backRed);
        swaps(&stuff.backGreen);
        swaps(&stuff.backBlue);
    }

    CursorPtr pCursor = void;
    int res = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.cid", "client"));

    res = AllocGlyphCursor(stuff.source, stuff.sourceChar,
                           stuff.mask, stuff.maskChar,
                           stuff.foreRed, stuff.foreGreen, stuff.foreBlue,
                           stuff.backRed, stuff.backGreen, stuff.backBlue,
                           &pCursor, client, stuff.cid);
    if (res != Success)
        return res;
    if (AddResource(cast(uint)stuff.cid, X11_RESTYPE_CURSOR, cast(void*) pCursor))
        return Success;
    return BadAlloc;
}

int ProcFreeCursor(ClientPtr client)
{
    CursorPtr pCursor = void;
    int rc = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    rc = dixLookupResourceByType(cast(void**) &pCursor, stuff.id, X11_RESTYPE_CURSOR,
                                 client, DixDestroyAccess);
    if (rc == Success) {
        if (pCursor == rootCursor) {
            client.errorValue = cast(uint)stuff.id;
            return BadCursor;
        }
        FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.id;
        return rc;
    }
}

int ProcQueryBestSize(ClientPtr client)
{
    DrawablePtr pDraw = void;
    ScreenPtr pScreen = void;
    int rc = void;

    mixin(REQUEST!xQueryBestSizeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xQueryBestSizeReq);

    if ((stuff.class_ != CursorShape) &&
        (stuff.class_ != TileShape) && (stuff.class_ != StippleShape)) {
        client.errorValue = cast(uint)stuff.class_;
        return BadValue;
    }

    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, M_ANY,
                           DixGetAttrAccess);
    if (rc != Success)
        return rc;
    if (stuff.class_ != CursorShape && pDraw.type == UNDRAWABLE_WINDOW)
        return BadMatch;
    pScreen = pDraw.pScreen;
    rc = dixCallScreenAccessCallback(client, pScreen, DixGetAttrAccess);
    if (rc != Success)
        return rc;
    (*pScreen.QueryBestSize) (stuff.class_, &stuff.width,
                               &stuff.height, pScreen);

    xQueryBestSizeReply reply = {
        width: stuff.width,
        height: stuff.height
    };

    if (client.swapped) {
        swaps(&reply.width);
        swaps(&reply.height);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcSetScreenSaver(ClientPtr client)
{
    mixin(REQUEST!xSetScreenSaverReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetScreenSaverReq);

    if (client.swapped) {
        swaps(&stuff.timeout);
        swaps(&stuff.interval);
    }

    int blankingOption = void, exposureOption = void;

    mixin(DIX_FOR_EACH_SCREEN!q{
        int rc = dixCallScreensaverAccessCallback(client, walkScreen, DixSetAttrAccess);
        if (rc != Success)
            return rc;
    });

    blankingOption = stuff.preferBlank;
    if ((blankingOption != DontPreferBlanking) &&
        (blankingOption != PreferBlanking) &&
        (blankingOption != DefaultBlanking)) {
        client.errorValue = cast(uint)blankingOption;
        return BadValue;
    }
    exposureOption = stuff.allowExpose;
    if ((exposureOption != DontAllowExposures) &&
        (exposureOption != AllowExposures) &&
        (exposureOption != DefaultExposures)) {
        client.errorValue = cast(uint)exposureOption;
        return BadValue;
    }
    if (stuff.timeout < -1) {
        client.errorValue = cast(uint)stuff.timeout;
        return BadValue;
    }
    if (stuff.interval < -1) {
        client.errorValue = cast(uint)stuff.interval;
        return BadValue;
    }

    if (blankingOption == DefaultBlanking)
        ScreenSaverBlanking = defaultScreenSaverBlanking;
    else
        ScreenSaverBlanking = blankingOption;
    if (exposureOption == DefaultExposures)
        ScreenSaverAllowExposures = defaultScreenSaverAllowExposures;
    else
        ScreenSaverAllowExposures = exposureOption;

    if (stuff.timeout >= 0)
        ScreenSaverTime = stuff.timeout * MILLI_PER_SECOND;
    else
        ScreenSaverTime = defaultScreenSaverTime;
    if (stuff.interval >= 0)
        ScreenSaverInterval = stuff.interval * MILLI_PER_SECOND;
    else
        ScreenSaverInterval = defaultScreenSaverInterval;

    SetScreenSaverTimer();
    return Success;
}

int ProcGetScreenSaver(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    mixin(DIX_FOR_EACH_SCREEN!q{
        int rc = dixCallScreensaverAccessCallback(client, walkScreen, DixGetAttrAccess);
        if (rc != Success)
            return rc;
    });

    xGetScreenSaverReply reply = {
        timeout: cast(ushort)(ScreenSaverTime / MILLI_PER_SECOND),
        interval: cast(ushort)(ScreenSaverInterval / MILLI_PER_SECOND),
        preferBlanking: cast(ubyte)ScreenSaverBlanking,
        allowExposures: cast(ubyte)ScreenSaverAllowExposures
    };

    if (client.swapped) {
        swaps(&reply.timeout);
        swaps(&reply.interval);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcChangeHosts(ClientPtr client)
{
    mixin(REQUEST!xChangeHostsReq);

    mixin(REQUEST_FIXED_SIZE!("xChangeHostsReq", "stuff.hostLength"));

    if (stuff.mode == HostInsert)
        return AddHost(client, cast(int) stuff.hostFamily,
                       stuff.hostLength, cast(void*) &stuff[1]);
    if (stuff.mode == HostDelete)
        return RemoveHost(client, cast(int) stuff.hostFamily,
                          stuff.hostLength, cast(void*) &stuff[1]);
    client.errorValue = cast(uint)stuff.mode;
    return BadValue;
}

int ProcListHosts(ClientPtr client)
{
    int len = void, nHosts = void, result = void;
    BOOL enabled = void;
    void* pdata = void;

    /* mixin(REQUEST!xListHostsReq); */

    mixin(REQUEST_AT_LEAST_SIZE!xListHostsReq);

    /* untrusted clients can't list hosts */
    result = dixCallServerAccessCallback(client, DixReadAccess);
    if (result != Success)
        return result;

    result = GetHosts(&pdata, &nHosts, &len, &enabled);
    if (result != Success)
        return result;

    xListHostsReply reply = {
        enabled: cast(ubyte)enabled,
        nHosts: cast(ushort)nHosts
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (client.swapped) {
        char* bufT = cast(char*) pdata;
        char* endbuf = bufT + len;

        while (bufT < endbuf) {
            xHostEntry* host = cast(xHostEntry*) bufT;
            int l1 = host.length;
            swaps(&host.length);
            bufT += ((xHostEntry).sizeof + pad_to_int32(l1));
        }

        swaps(&reply.nHosts);
    }

    x_rpcbuf_write_CARD8s(&rpcbuf, cast(ubyte*)pdata, len);
    free(pdata);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcChangeAccessControl(ClientPtr client)
{
    mixin(REQUEST!xSetAccessControlReq);

    mixin(REQUEST_AT_LEAST_SIZE!xSetAccessControlReq);
    if ((stuff.mode != EnableAccess) && (stuff.mode != DisableAccess)) {
        client.errorValue = cast(uint)stuff.mode;
        return BadValue;
    }
    return ChangeAccessControl(client, stuff.mode == EnableAccess);
}

/*********************
 * CloseDownRetainedResources
 *
 *    Find all clients that are gone and have terminated in RetainTemporary
 *    and destroy their resources.
 *********************/

private void CloseDownRetainedResources()
{
    ClientPtr client = void;

    for (int i = 1; i < currentMaxClients; i++) {
        client = clients[i];
        if (client && (client.closeDownMode == RetainTemporary)
            && (client.clientGone))
            CloseDownClient(client);
    }
}

int ProcKillClient(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    ClientPtr killclient = void;
    int rc = void;

    if (stuff.id == AllTemporary) {
        CloseDownRetainedResources();
        return Success;
    }

    rc = dixLookupResourceOwner(&killclient, stuff.id, client, DixDestroyAccess);
    if (rc == Success) {
        CloseDownClient(killclient);
        if (client == killclient) {
            /* force yield and return Success, so that Dispatch()
             * doesn't try to touch client
             */
            isItTimeToYield = TRUE;
        }
        return Success;
    }
    else
        return rc;
}

int ProcSetFontPath(ClientPtr client)
{
    ubyte* ptr = void;
    c_ulong nbytes = void, total = void;
    c_long nfonts = void;
    int n = void;

    mixin(REQUEST!xSetFontPathReq);

    mixin(REQUEST_AT_LEAST_SIZE!xSetFontPathReq);

    nbytes = ((client.req_len << 2)) - xSetFontPathReq.sizeof;
    total = nbytes;
    ptr = cast(ubyte*) &stuff[1];
    nfonts = stuff.nFonts;
    while (--nfonts >= 0) {
        if ((total == 0) || (total < (n = (*ptr + 1))))
            return BadLength;
        total -= n;
        ptr += n;
    }
    if (total >= 4)
        return BadLength;
    return SetFontPath(client, stuff.nFonts, cast(ubyte*) &stuff[1]);
}

int ProcGetFontPath(ClientPtr client)
{
    /* REQUEST (xReq); */
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    int rc = dixCallServerAccessCallback(client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    xGetFontPathReply reply = {
        nPaths: cast(ushort)FillFontPath(&rpcbuf)
    };

    if (client.swapped) {
        swaps(&reply.nPaths);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcChangeCloseDownMode(ClientPtr client)
{
    int rc = void;

    mixin(REQUEST!xSetCloseDownModeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetCloseDownModeReq);

    rc = dixCallClientAccessCallback(client, client, DixManageAccess);
    if (rc != Success)
        return rc;

    if ((stuff.mode == AllTemporary) ||
        (stuff.mode == RetainPermanent) || (stuff.mode == RetainTemporary)) {
        client.closeDownMode = stuff.mode;
        return Success;
    }
    else {
        client.errorValue = cast(uint)stuff.mode;
        return BadValue;
    }
}

int ProcForceScreenSaver(ClientPtr client)
{
    int rc = void;

    mixin(REQUEST!xForceScreenSaverReq);

    mixin(REQUEST_AT_LEAST_SIZE!xForceScreenSaverReq);

    if ((stuff.mode != ScreenSaverReset) && (stuff.mode != ScreenSaverActive)) {
        client.errorValue = cast(uint)stuff.mode;
        return BadValue;
    }
    rc = dixSaveScreens(client, SCREEN_SAVER_FORCER, cast(int) stuff.mode);
    if (rc != Success)
        return rc;
    return Success;
}

int ProcNoOperation(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xReq);

    /* noop -- don't do anything */
    return Success;
}

/**********************
 * CloseDownClient
 *
 *  Client can either mark his resources destroy or retain.  If retained and
 *  then killed again, the client is really destroyed.
 *********************/

char dispatchExceptionAtReset = 0;
int terminateDelay = 0;

void CloseDownClient(ClientPtr client)
{
    Bool really_close_down = client.clientGone ||
        client.closeDownMode == DestroyAll;

    if (!client.clientGone) {
        /* ungrab server if grabbing client dies */
        if (grabState != GrabNone && grabClient == client) {
            UngrabServer(client);
        }
        mixin(BITCLEAR!(`grabWaiters`, `client.index`));
        DeleteClientFromAnySelections(client);
        ReleaseActiveGrabs(client);
        DeleteClientFontStuff(client);
        if (!really_close_down) {
            /*  This frees resources that should never be retained
             *  no matter what the close down mode is.  Actually we
             *  could do this unconditionally, but it's probably
             *  better not to traverse all the client's resources
             *  twice (once here, once a few lines down in
             *  FreeClientResources) in the common case of
             *  really_close_down == TRUE.
             */
            FreeClientNeverRetainResources(client);
            client.clientState = ClientStateRetained;
            if (ClientStateCallback) {
                NewClientInfoRec clientinfo = void;

                clientinfo.client = client;
                clientinfo.prefix = cast(xConnSetupPrefix*) null;
                clientinfo.setup = cast(xConnSetup*) null;
                CallCallbacks((&ClientStateCallback), cast(void*) &clientinfo);
            }
        }
        client.clientGone = TRUE;      /* so events aren't sent to client */
        if (ClientIsAsleep(client))
            dixClientSignal(client);
        ProcessWorkQueueZombies();
        CloseDownConnection(client);
        output_pending_clear(client);
        mark_client_not_ready(client);

        /* If the client made it to the Running stage, nClients has
         * been incremented on its behalf, so we need to decrement it
         * now.  If it hasn't gotten to Running, nClients has *not*
         * been incremented, so *don't* decrement it.
         */
        if (client.clientState != ClientStateInitial) {
            --nClients;
        }
    }

    if (really_close_down) {
        if (client.clientState == ClientStateRunning && nClients == 0)
            SetDispatchExceptionTimer();

        client.clientState = ClientStateGone;
        if (ClientStateCallback) {
            NewClientInfoRec clientinfo = void;

            clientinfo.client = client;
            clientinfo.prefix = cast(xConnSetupPrefix*) null;
            clientinfo.setup = cast(xConnSetup*) null;
            CallCallbacks((&ClientStateCallback), cast(void*) &clientinfo);
        }
        TouchListenerGone(client.clientAsMask);
        GestureListenerGone(client.clientAsMask);
        FreeClientResources(client);
        CallCallbacks(&ClientDestroyCallback, client);
        /* Disable client ID tracking. This must be done after
         * ClientStateCallback. */
        ReleaseClientIds(client);
version (XSERVER_DTRACE) {
        XSERVER_CLIENT_DISCONNECT(client.index);
}
        if (client.index < nextFreeClientID)
            nextFreeClientID = client.index;
        clients[client.index] = null;
        SmartLastClient = null;
        mixin(dixFreeObjectWithPrivatesM!("client", "PRIVATE_CLIENT"));

        while (!clients[currentMaxClients - 1])
            currentMaxClients--;
    }

    if (ShouldDisconnectRemainingClients())
        SetDispatchExceptionTimer();
}

private void KillAllClients()
{
    for (int i = 1; i < currentMaxClients; i++)
        if (clients[i]) {
            /* Make sure Retained clients are released. */
            clients[i].closeDownMode = DestroyAll;
            CloseDownClient(clients[i]);
        }
}

void InitClient(ClientPtr client, int i, void* ospriv)
{
    client.index = cast(ushort)i;
    xorg_list_init(&client.ready);
    xorg_list_init(&client.output_pending);
    client.clientAsMask = (cast(Mask) i) << CLIENTOFFSET;
    client.closeDownMode = i ? DestroyAll : RetainPermanent;
    client.requestVector = InitialVector.ptr;
    client.osPrivate = ospriv;
    QueryMinMaxKeyCodes(&client.minKC, &client.maxKC);
    client.smart_start_tick = cast(int)SmartScheduleTime;
    client.smart_stop_tick = cast(int)SmartScheduleTime;
    client.clientIds = null;
}

/************************
 * int NextAvailableClient(ospriv)
 *
 * OS dependent portion can't assign client id's because of CloseDownModes.
 * Returns NULL if there are no free clients.
 *************************/

ClientPtr NextAvailableClient(void* ospriv)
{
    int i = void;
    ClientPtr client = void;
    xReq data = void;

    i = nextFreeClientID;
    if (i == LimitClients)
        return cast(ClientPtr) null;
    clients[i] = client =
        mixin(dixAllocateObjectWithPrivates!("ClientRec", "PRIVATE_CLIENT"));
    if (!client)
        return cast(ClientPtr) null;
    InitClient(client, i, ospriv);
    if (!InitClientResources(client)) {
        mixin(dixFreeObjectWithPrivatesM!("client", "PRIVATE_CLIENT"));
        return cast(ClientPtr) null;
    }
    data.reqType = 1;
    data.length = cast(ushort)bytes_to_int32(sz_xReq + sz_xConnClientPrefix);
    if (!InsertFakeRequest(client, cast(char*) &data, sz_xReq)) {
        FreeClientResources(client);
        mixin(dixFreeObjectWithPrivatesM!("client", "PRIVATE_CLIENT"));
        return cast(ClientPtr) null;
    }
    if (i == currentMaxClients)
        currentMaxClients++;
    while ((nextFreeClientID < LimitClients) && clients[nextFreeClientID])
        nextFreeClientID++;

    /* Enable client ID tracking. This must be done before
     * ClientStateCallback. */
    ReserveClientIds(client);

    if (ClientStateCallback) {
        NewClientInfoRec clientinfo = void;

        clientinfo.client = client;
        clientinfo.prefix = cast(xConnSetupPrefix*) null;
        clientinfo.setup = cast(xConnSetup*) null;
        CallCallbacks((&ClientStateCallback), cast(void*) &clientinfo);
    }
    return client;
}

int ProcInitialConnection(ClientPtr client)
{
    mixin(REQUEST!xReq);
    xConnClientPrefix* prefix = void;
    int whichbyte = 1;
    char order = void;

    prefix = cast(xConnClientPrefix*) (cast(char*)stuff + sz_xReq);
    order = prefix.byteOrder;
    if (order != 'l' && order != 'B' && order != 'r' && order != 'R')
        return client.noClientException = -1;
    if (((*cast(char*) &whichbyte) && (order == 'B' || order == 'R')) ||
        (!(*cast(char*) &whichbyte) && (order == 'l' || order == 'r'))) {
        client.swapped = TRUE;
        SwapConnClientPrefix(prefix);
    }
    stuff.reqType = 2;
    stuff.length += bytes_to_int32(prefix.nbytesAuthProto) +
        bytes_to_int32(prefix.nbytesAuthString);
    if (client.swapped) {
        swaps(&stuff.length);
    }
    if (order == 'r' || order == 'R') {
        client.local = FALSE;
    }
    ResetCurrentRequest(client);
    return Success;
}

private int SendConnSetup(ClientPtr client, const(char)* reason)
{
    xWindowRoot* root = void;
    int numScreens = void;
    char* lConnectionInfo = void;
    xConnSetupPrefix* lconnSetupPrefix = void;

    if (reason) {
        xConnSetupPrefix csp = void;

        csp.success = xFalse;
        csp.lengthReason = cast(ubyte)strlen(reason);
        csp.length = cast(ushort)bytes_to_int32(csp.lengthReason);
        csp.majorVersion = X_PROTOCOL;
        csp.minorVersion = X_PROTOCOL_REVISION;
        if (client.swapped)
            WriteSConnSetupPrefix(client, &csp);
        else
            WriteToClient(client, sz_xConnSetupPrefix, &csp);
        WriteToClient(client, cast(int) csp.lengthReason, reason);
        return client.noClientException = -1;
    }

    numScreens = screenInfo.numScreens;
    lConnectionInfo = ConnectionInfo;
    lconnSetupPrefix = &connSetupPrefix;

    /* We're about to start speaking X protocol back to the client by
     * sending the connection setup info.  This means the authorization
     * step is complete, and we can count the client as an
     * authorized one.
     */
    nClients++;

    client.requestVector = client.swapped ? SwappedProcVector.ptr : ProcVector.ptr;
    client.sequence = 0;
    (cast(xConnSetup*) lConnectionInfo).ridBase = cast(uint)client.clientAsMask;
    (cast(xConnSetup*) lConnectionInfo).ridMask = RESOURCE_ID_MASK;
version (MATCH_CLIENT_ENDIAN) {
    (cast(xConnSetup*) lConnectionInfo).imageByteOrder = mixin(ClientOrder!(`client`));
    (cast(xConnSetup*) lConnectionInfo).bitmapBitOrder = mixin(ClientOrder!(`client`));
}
    /* fill in the "currentInputMask" */
    root = cast(xWindowRoot*) (lConnectionInfo + connBlockScreenStart);
static if(XINERAMA){
    if (noPanoramiXExtension)
        numScreens = screenInfo.numScreens;
    else
        numScreens = (cast(xConnSetup*) ConnectionInfo).numRoots;
} /* XINERAMA */

    for (uint walkScreenIdx = 0; walkScreenIdx < numScreens; walkScreenIdx++) {
        ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx];
        xDepth* pDepth = void;
        WindowPtr pRoot = walkScreen.root;

        root.currentInputMask = cast(uint)(pRoot.eventMask | mixin(wOtherEventMasks!("pRoot")));
        pDepth = cast(xDepth*) (root + 1);
        for (uint j = 0; j < root.nDepths; j++) {
            pDepth = cast(xDepth*) ((cast(char*) (pDepth + 1)) +
                                 pDepth.nVisuals * xVisualType.sizeof);
        }
        root = cast(xWindowRoot*) pDepth;
    }

    if (client.swapped) {
        WriteSConnSetupPrefix(client, lconnSetupPrefix);
        WriteSConnectionInfo(client,
                             cast(c_ulong) (lconnSetupPrefix.length << 2),
                             lConnectionInfo);
    }
    else {
        WriteToClient(client, xConnSetupPrefix.sizeof, lconnSetupPrefix);
        WriteToClient(client, cast(int) (lconnSetupPrefix.length << 2),
		      lConnectionInfo);
    }
    client.clientState = ClientStateRunning;
    if (ClientStateCallback) {
        NewClientInfoRec clientinfo = void;

        clientinfo.client = client;
        clientinfo.prefix = lconnSetupPrefix;
        clientinfo.setup = cast(xConnSetup*) lConnectionInfo;
        CallCallbacks((&ClientStateCallback), cast(void*) &clientinfo);
    }
    CancelDispatchExceptionTimer();
    return Success;
}

int ProcEstablishConnection(ClientPtr client)
{
    const(char)* reason = void;
    xConnClientPrefix* prefix = void;

    mixin(REQUEST!xReq);

    prefix = cast(xConnClientPrefix*) (cast(char*) stuff + sz_xReq);

    if (client.swapped && !dixSettingAllowByteSwappedClients) {
        reason = "Prohibited client endianness, see the Xserver man page ";
    } else if (((client.req_len << 2)) != sz_xReq + sz_xConnClientPrefix +
            pad_to_int32(prefix.nbytesAuthProto) +
            pad_to_int32(prefix.nbytesAuthString))
        reason = "Bad length";
    else if ((prefix.majorVersion != X_PROTOCOL) ||
        (prefix.minorVersion != X_PROTOCOL_REVISION))
        reason = "Protocol version mismatch";
    else {
        char* auth_proto = cast(char*) prefix + sz_xConnClientPrefix;
        char* auth_string = auth_proto + pad_to_int32(prefix.nbytesAuthProto);
        reason = ClientAuthorized(client,
                                  cast(ushort) prefix.nbytesAuthProto,
                                  auth_proto,
                                  cast(ushort) prefix.nbytesAuthString,
                                  auth_string);
    }

    return (SendConnSetup(client, reason));
}

void SendErrorToClient(ClientPtr client, CARD8 majorCode, CARD16 minorCode, XID resId, BYTE errorCode)
{
    xError reply = {
        type: X_Error,
        errorCode: errorCode,
        resourceID: cast(uint)resId,
        minorCode: minorCode,
        majorCode: majorCode
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &reply);
}

void dixMarkClientException(ClientPtr client)
{
    client.noClientException = -1;
}

/*
 * This array encodes the answer to the question "what is the log base 2
 * of the number of pixels that fit in a scanline pad unit?"
 * Note that ~0 is an invalid entry (mostly for the benefit of the reader).
 */
private const(int)[4][6] answer = [
    /* pad   pad   pad     pad */
    /*  8     16    32    64 */

    [3, 4, 5, 6],               /* 1 bit per pixel */
    [1, 2, 3, 4],               /* 4 bits per pixel */
    [0, 1, 2, 3],               /* 8 bits per pixel */
    [~0, 0, 1, 2],              /* 16 bits per pixel */
    [~0, ~0, 0, 1],             /* 24 bits per pixel */
    [~0, ~0, 0, 1]              /* 32 bits per pixel */
];

/*
 * This array gives the answer to the question "what is the first index for
 * the answer array above given the number of bits per pixel?"
 * Note that ~0 is an invalid entry (mostly for the benefit of the reader).
 */
private const(int)[33] indexForBitsPerPixel = [
    ~0, 0, ~0, ~0,              /* 1 bit per pixel */
    1, ~0, ~0, ~0,              /* 4 bits per pixel */
    2, ~0, ~0, ~0,              /* 8 bits per pixel */
    ~0, ~0, ~0, ~0,
    3, ~0, ~0, ~0,              /* 16 bits per pixel */
    ~0, ~0, ~0, ~0,
    4, ~0, ~0, ~0,              /* 24 bits per pixel */
    ~0, ~0, ~0, ~0,
    5                           /* 32 bits per pixel */
];

/*
 * This array gives the bytesperPixel value for cases where the number
 * of bits per pixel is a multiple of 8 but not a power of 2.
 */
private const(int)[33] answerBytesPerPixel = [
    ~0, 0, ~0, ~0,              /* 1 bit per pixel */
    0, ~0, ~0, ~0,              /* 4 bits per pixel */
    0, ~0, ~0, ~0,              /* 8 bits per pixel */
    ~0, ~0, ~0, ~0,
    0, ~0, ~0, ~0,              /* 16 bits per pixel */
    ~0, ~0, ~0, ~0,
    3, ~0, ~0, ~0,              /* 24 bits per pixel */
    ~0, ~0, ~0, ~0,
    0                           /* 32 bits per pixel */
];

/*
 * This array gives the answer to the question "what is the second index for
 * the answer array above given the number of bits per scanline pad unit?"
 * Note that ~0 is an invalid entry (mostly for the benefit of the reader).
 */
private const(int)[65] indexForScanlinePad = [
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    0, ~0, ~0, ~0,              /* 8 bits per scanline pad unit */
    ~0, ~0, ~0, ~0,
    1, ~0, ~0, ~0,              /* 16 bits per scanline pad unit */
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    2, ~0, ~0, ~0,              /* 32 bits per scanline pad unit */
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    ~0, ~0, ~0, ~0,
    3                           /* 64 bits per scanline pad unit */
];

/*
	grow the array of screenRecs if necessary.
	call the device-supplied initialization procedure
with its screen number, a pointer to its ScreenRec, argc, and argv.
	return the number of successfully installed screens.

*/

private int init_screen(ScreenPtr pScreen, int i, Bool gpu)
{
    int scanlinepad = void, depth = void, bitsPerPixel = void, j = void, k = void;

    dixInitScreenSpecificPrivates(pScreen);

    if (!dixAllocatePrivates(&pScreen.devPrivates, PRIVATE_SCREEN)) {
        return -1;
    }
    pScreen.myNum = i;
    if (gpu) {
        pScreen.myNum += GPU_SCREEN_OFFSET;
        pScreen.isGPU = TRUE;
    }
    pScreen.totalPixmapSize = 0;       /* computed in CreateScratchPixmapForScreen */
    pScreen.ClipNotify = null;    /* for R4 ddx compatibility */
    pScreen.CreateScreenResources = null;

    xorg_list_init(&pScreen.pixmap_dirty_list);
    xorg_list_init(&pScreen.secondary_list);

    /*
     * This loop gets run once for every Screen that gets added,
     * but that's ok.  If the ddx layer initializes the formats
     * one at a time calling AddScreen() after each, then each
     * iteration will make it a little more accurate.  Worst case
     * we do this loop N * numPixmapFormats where N is # of screens.
     * Anyway, this must be called after InitOutput and before the
     * screen init routine is called.
     */
    for (int format = 0; format < screenInfo.numPixmapFormats; format++) {
        depth = screenInfo.formats[format].depth;
        bitsPerPixel = screenInfo.formats[format].bitsPerPixel;
        scanlinepad = screenInfo.formats[format].scanlinePad;
        j = indexForBitsPerPixel[bitsPerPixel];
        k = indexForScanlinePad[scanlinepad];
        PixmapWidthPaddingInfo[depth].padPixelsLog2 = answer[j][k];
        PixmapWidthPaddingInfo[depth].padRoundUp =
            (scanlinepad / bitsPerPixel) - 1;
        j = indexForBitsPerPixel[8];    /* bits per byte */
        PixmapWidthPaddingInfo[depth].padBytesLog2 = answer[j][k];
        PixmapWidthPaddingInfo[depth].bitsPerPixel = bitsPerPixel;
        if (answerBytesPerPixel[bitsPerPixel]) {
            PixmapWidthPaddingInfo[depth].notPower2 = 1;
            PixmapWidthPaddingInfo[depth].bytesPerPixel =
                answerBytesPerPixel[bitsPerPixel];
        }
        else {
            PixmapWidthPaddingInfo[depth].notPower2 = 0;
        }
    }
    return 0;
}

int AddScreen(Bool function(ScreenPtr, int, char**) @nogc nothrow pfnInit, int argc, char** argv)
{

    int i = void;
    ScreenPtr pScreen = void;
    Bool ret = void;

    i = screenInfo.numScreens;
    if (i == MAXSCREENS)
        return -1;

    pScreen = cast(ScreenPtr) cast(ScreenRec*) calloc(1, ScreenRec.sizeof);
    if (!pScreen)
        return -1;

    ret = init_screen(pScreen, i, FALSE);
    if (ret != 0) {
        free(pScreen);
        return ret;
    }
    /* This is where screen specific stuff gets initialized.  Load the
       screen structure, call the hardware, whatever.
       This is also where the default colormap should be allocated and
       also pixel values for blackPixel, whitePixel, and the cursor
       Note that InitScreen is NOT allowed to modify argc, argv, or
       any of the strings pointed to by argv.  They may be passed to
       multiple screens.
     */
    screenInfo.screens[i] = pScreen;
    screenInfo.numScreens++;
    if (!(*pfnInit) (pScreen, argc, argv)) {
        dixFreeScreenSpecificPrivates(pScreen);
        dixFreePrivates(pScreen.devPrivates, PRIVATE_SCREEN);
        free(pScreen);
        screenInfo.numScreens--;
        return -1;
    }

    update_desktop_dimensions();

    return i;
}

int AddGPUScreen(Bool function(ScreenPtr, int, char**) @nogc nothrow pfnInit, int argc, char** argv)
{
    int i = void;
    ScreenPtr pScreen = void;
    Bool ret = void;

    i = screenInfo.numGPUScreens;
    if (i == MAXGPUSCREENS)
        return -1;

    pScreen = cast(ScreenPtr) cast(ScreenRec*) calloc(1, ScreenRec.sizeof);
    if (!pScreen)
        return -1;

    ret = init_screen(pScreen, i, TRUE);
    if (ret != 0) {
        free(pScreen);
        return ret;
    }

    /* This is where screen specific stuff gets initialized.  Load the
       screen structure, call the hardware, whatever.
       This is also where the default colormap should be allocated and
       also pixel values for blackPixel, whitePixel, and the cursor
       Note that InitScreen is NOT allowed to modify argc, argv, or
       any of the strings pointed to by argv.  They may be passed to
       multiple screens.
     */
    screenInfo.gpuscreens[i] = pScreen;
    screenInfo.numGPUScreens++;
    if (!(*pfnInit) (pScreen, argc, argv)) {
        dixFreePrivates(pScreen.devPrivates, PRIVATE_SCREEN);
        free(pScreen);
        screenInfo.numGPUScreens--;
        return -1;
    }

    update_desktop_dimensions();

    return i;
}

void RemoveGPUScreen(ScreenPtr pScreen)
{
    int idx = void;
    if (!pScreen.isGPU)
        return;

    idx = pScreen.myNum - GPU_SCREEN_OFFSET;
    for (int j = idx; j < screenInfo.numGPUScreens - 1; j++) {
        screenInfo.gpuscreens[j] = screenInfo.gpuscreens[j + 1];
        screenInfo.gpuscreens[j].myNum = j + GPU_SCREEN_OFFSET;
    }
    screenInfo.numGPUScreens--;

    /* this gets freed later in the resource list, but without
     * the screen existing it causes crashes - so remove it here */
    if (pScreen.defColormap)
        FreeResource(cast(uint)pScreen.defColormap, X11_RESTYPE_COLORMAP);
    free(pScreen);

}

void AttachUnboundGPU(ScreenPtr pScreen, ScreenPtr new_)
{
    assert(new_.isGPU);
    assert(!new_.current_primary);
    xorg_list_add(&new_.secondary_head, &pScreen.secondary_list);
    new_.current_primary = pScreen;
}

void DetachUnboundGPU(ScreenPtr secondary)
{
    assert(secondary.isGPU);
    assert(!secondary.is_output_secondary);
    assert(!secondary.is_offload_secondary);
    xorg_list_del(&secondary.secondary_head);
    secondary.current_primary = null;
}

void AttachOutputGPU(ScreenPtr pScreen, ScreenPtr new_)
{
    assert(new_.isGPU);
    assert(!new_.is_output_secondary);
    assert(new_.current_primary == pScreen);
    new_.is_output_secondary = TRUE;
    new_.current_primary.output_secondarys++;
}

void DetachOutputGPU(ScreenPtr secondary)
{
    assert(secondary.isGPU);
    assert(secondary.is_output_secondary);
    secondary.current_primary.output_secondarys--;
    secondary.is_output_secondary = FALSE;
}

void AttachOffloadGPU(ScreenPtr pScreen, ScreenPtr new_)
{
    assert(new_.isGPU);
    assert(!new_.is_offload_secondary);
    assert(new_.current_primary == pScreen);
    new_.is_offload_secondary = TRUE;
}

void DetachOffloadGPU(ScreenPtr secondary)
{
    assert(secondary.isGPU);
    assert(secondary.is_offload_secondary);
    secondary.is_offload_secondary = FALSE;
}

