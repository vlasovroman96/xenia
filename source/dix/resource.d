module dix.resource;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

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

/*	Routines to manage various kinds of resources:
 *
 *	CreateNewResourceType, CreateNewResourceClass, InitClientResources,
 *	FakeClientID, AddResource, FreeResource, FreeClientResources,
 *	FreeAllResources, LookupIDByType, LookupIDByClass, GetXIDRange
 */

/*
 *      A resource ID is a 32 bit quantity, the upper 2 bits of which are
 *	off-limits for client-visible resources.  The next 8 bits are
 *      used as client ID, and the low 22 bits come from the client.
 *	A resource ID is "hashed" by extracting and xoring subfields
 *      (varying with the size of the hash table).
 *
 *      It is sometimes necessary for the server to create an ID that looks
 *      like it belongs to a client.  This ID, however,  must not be one
 *      the client actually can create, or we have the potential for conflict.
 *      The 31st bit of the ID is reserved for the server's use for this
 *      purpose.  By setting dixClientIdForXID(id) to the client, the SERVER_BIT to
 *      1, and an otherwise arbitrary ID in the low 22 bits, we can create a
 *      resource "owned" by the client.
 */

import build.xlibre_server;

//import x11.X;

import dix.colormap_priv;
import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.gc_priv;
import dix.registry_priv;
import dix.resource_priv;
import include.extinit;
import os.osdep;
import os.probes_priv;
import os.osinit;
import dix.dixfonts;

import Xext.panoramiX;
import Xext.panoramiXsrv;

import dix.dixutils;
import include.misc;
import include.os;
import include.resource;
import include.dixstruct;
import include.opaque;
import include.windowstr;
import include.dixfont;
import dix.colormap;
import include.inputstr;
import include.cursor;
import Xext.xace;
import core.stdc.assert_;
import include.gcstruct;
import os.log;
import dix.cursor;
import dix.gc;
import registry;

version (XSERVER_DTRACE) {

enum string TypeNameString(string t) = `LookupResourceName(` ~ t ~ `)`;
}



enum SERVER_MINID = 32;

enum INITBUCKETS = 64;
enum INITHASHSIZE = 6;
enum MAXHASHSIZE = 16;

struct _Resource {
    _Resource* next;
    XID id;
    RESTYPE type;
    void* value;
}alias ResourceRec = _Resource;
alias ResourcePtr = _Resource*;

struct ClientResourceRec {
    ResourcePtr* resources;
    int elements;
    int buckets;
    int hashsize;               /* log(2)(buckets) */
    XID fakeID;
    XID endFakeID;
}

RESTYPE lastResourceType;
private RESTYPE lastResourceClass;
RESTYPE TypeMask;

struct ResourceType {
    DeleteType deleteFunc;
    SizeType sizeFunc;
    FindTypeSubResources findSubResFunc;
    int errorValue;
}

/**
 * Used by all resources that don't specify a function to calculate
 * resource size. Currently this is used for all resources with
 * insignificant memory usage.
 *
 * @see GetResourceTypeSizeFunc, SetResourceTypeSizeFunc
 *
 * @param[in] value Pointer to resource object.
 *
 * @param[in] id Resource ID for the object.
 *
 * @param[out] size Fill all fields to zero to indicate that size of
 *                  resource can't be determined.
 */
private void GetDefaultBytes(void* value, XID id, ResourceSizePtr size)
{
    size.resourceSize = 0;
    size.pixmapRefSize = 0;
    size.refCnt = 1;
}

/**
 * Used by all resources that don't specify a function to iterate
 * through subresources. Currently this is used for all resources with
 * insignificant memory usage.
 *
 * @see FindSubResources, SetResourceTypeFindSubResFunc
 *
 * @param[in] value Pointer to resource object.
 *
 * @param[in] func Function to call for each subresource.

 * @param[out] cdata Pointer to opaque data.
 */
private void DefaultFindSubRes(void* value, FindAllRes func, void* cdata)
{
    /* do nothing */
}

/**
 * Calculate drawable size in bytes. Reference counting is not taken
 * into account.
 *
 * @param[in] drawable Pointer to a drawable.
 *
 * @return Estimate of total memory usage for the drawable.
 */
private c_ulong GetDrawableBytes(DrawablePtr drawable)
{
    int bytes = 0;

    if (drawable)
    {
        int bytesPerPixel = drawable.bitsPerPixel >> 3;
        int numberOfPixels = drawable.width * drawable.height;
        bytes = numberOfPixels * bytesPerPixel;
    }

    return bytes;
}

/**
 * Calculate pixmap size in bytes. Reference counting is taken into
 * account. Any extra data attached by extensions and drivers is not
 * taken into account. The purpose of this function is to estimate
 * memory usage that can be attributed to single reference of the
 * pixmap.
 *
 * @param[in] value Pointer to a pixmap.
 *
 * @param[in] id Resource ID of pixmap. If the pixmap hasn't been
 *               added as resource, just pass value->drawable.id.
 *
 * @param[out] size Estimate of memory usage attributed to a single
 *                  pixmap reference.
 */
private void GetPixmapBytes(void* value, XID id, ResourceSizePtr size)
{
    PixmapPtr pixmap = cast(PixmapPtr)value;

    size.resourceSize = 0;
    size.pixmapRefSize = 0;
    size.refCnt = pixmap.refcnt;

    if (pixmap && pixmap.refcnt)
    {
        DrawablePtr drawable = &pixmap.drawable;
        size.resourceSize = GetDrawableBytes(drawable);
        size.pixmapRefSize = size.resourceSize / pixmap.refcnt;
    }
}

/**
 * Calculate window size in bytes. The purpose of this function is to
 * estimate memory usage that can be attributed to all pixmap
 * references of the window.
 *
 * @param[in] value Pointer to a window.
 *
 * @param[in] id Resource ID of window.
 *
 * @param[out] size Estimate of memory usage attributed to a all
 *                  pixmap references of a window.
 */
private void GetWindowBytes(void* value, XID id, ResourceSizePtr size)
{
    SizeType pixmapSizeFunc = GetResourceTypeSizeFunc(X11_RESTYPE_PIXMAP);
    ResourceSizeRec pixmapSize = { 0, 0, 0 };
    WindowPtr window = cast(WindowPtr)value;

    /* Currently only pixmap bytes are reported to clients. */
    size.resourceSize = 0;

    /* Calculate pixmap reference sizes. */
    size.pixmapRefSize = 0;

    size.refCnt = 1;

    if (window.backgroundState == BackgroundPixmap)
    {
        PixmapPtr pixmap = window.background.pixmap;
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
    if (window.border.pixmap && !window.borderIsPixel)
    {
        PixmapPtr pixmap = window.border.pixmap;
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
}

/**
 * Iterate through subresources of a window. The purpose of this
 * function is to gather accurate information on what resources
 * a resource uses.
 *
 * @note Currently only sub-pixmaps are iterated
 *
 * @param[in] value  Pointer to a window
 *
 * @param[in] func   Function to call with each subresource
 *
 * @param[out] cdata Pointer to opaque data
 */
private void FindWindowSubRes(void* value, FindAllRes func, void* cdata)
{
    WindowPtr window = cast(WindowPtr)value;

    /* Currently only pixmap subresources are reported to clients. */

    if (window.backgroundState == BackgroundPixmap)
    {
        PixmapPtr pixmap = window.background.pixmap;
        func(window.background.pixmap, pixmap.drawable.id, X11_RESTYPE_PIXMAP, cdata);
    }
    if (window.border.pixmap && !window.borderIsPixel)
    {
        PixmapPtr pixmap = window.border.pixmap;
        func(window.background.pixmap, pixmap.drawable.id, X11_RESTYPE_PIXMAP, cdata);
    }
}

/**
 * Calculate graphics context size in bytes. The purpose of this
 * function is to estimate memory usage that can be attributed to all
 * pixmap references of the graphics context.
 *
 * @param[in] value Pointer to a graphics context.
 *
 * @param[in] id    Resource ID of graphics context.
 *
 * @param[out] size Estimate of memory usage attributed to a all
 *                  pixmap references of a graphics context.
 */
private void GetGcBytes(void* value, XID id, ResourceSizePtr size)
{
    SizeType pixmapSizeFunc = GetResourceTypeSizeFunc(X11_RESTYPE_PIXMAP);
    ResourceSizeRec pixmapSize = { 0, 0, 0 };
    GCPtr gc = cast(GCPtr)value;

    /* Currently only pixmap bytes are reported to clients. */
    size.resourceSize = 0;

    /* Calculate pixmap reference sizes. */
    size.pixmapRefSize = 0;

    size.refCnt = 1;
    if (gc.stipple)
    {
        PixmapPtr pixmap = gc.stipple;
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
    if (gc.tile.pixmap && !gc.tileIsPixel)
    {
        PixmapPtr pixmap = gc.tile.pixmap;
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
}

/**
 * Iterate through subresources of a graphics context. The purpose of
 * this function is to gather accurate information on what resources a
 * resource uses.
 *
 * @note Currently only sub-pixmaps are iterated
 *
 * @param[in] value  Pointer to a window
 *
 * @param[in] func   Function to call with each subresource
 *
 * @param[out] cdata Pointer to opaque data
 */
private void FindGCSubRes(void* value, FindAllRes func, void* cdata)
{
    GCPtr gc = cast(GCPtr)value;

    /* Currently only pixmap subresources are reported to clients. */

    if (gc.stipple)
    {
        PixmapPtr pixmap = gc.stipple;
        func(pixmap, pixmap.drawable.id, X11_RESTYPE_PIXMAP, cdata);
    }
    if (gc.tile.pixmap && !gc.tileIsPixel)
    {
        PixmapPtr pixmap = gc.tile.pixmap;
        func(pixmap, pixmap.drawable.id, X11_RESTYPE_PIXMAP, cdata);
    }
}

private ResourceType* resourceTypes;

private const(ResourceType)[11] predefTypes = [
    X11_RESTYPE_NONE & (RC_LASTPREDEF - 1): {
                                       deleteFunc: cast(DeleteType) null,
                                       sizeFunc: &GetDefaultBytes,
                                       findSubResFunc: &DefaultFindSubRes,
                                       errorValue: BadValue,
                                       },
    X11_RESTYPE_WINDOW & (RC_LASTPREDEF - 1): {
                                         deleteFunc: &DeleteWindow,
                                         sizeFunc: &GetWindowBytes,
                                         findSubResFunc: &FindWindowSubRes,
                                         errorValue: BadWindow,
                                         },
    X11_RESTYPE_PIXMAP & (RC_LASTPREDEF - 1): {
                                         deleteFunc: &dixDestroyPixmap,
                                         sizeFunc: &GetPixmapBytes,
                                         findSubResFunc: &DefaultFindSubRes,
                                         errorValue: BadPixmap,
                                         },
    X11_RESTYPE_GC & (RC_LASTPREDEF - 1): {
                                     deleteFunc: &FreeGC,
                                     sizeFunc: &GetGcBytes,
                                     findSubResFunc: &FindGCSubRes,
                                     errorValue: BadGC,
                                     },
    X11_RESTYPE_FONT & (RC_LASTPREDEF - 1): {
                                       deleteFunc: &CloseFont,
                                       sizeFunc: &GetDefaultBytes,
                                       findSubResFunc: &DefaultFindSubRes,
                                       errorValue: BadFont,
                                       },
    X11_RESTYPE_CURSOR & (RC_LASTPREDEF - 1): {
                                         deleteFunc: &FreeCursor,
                                         sizeFunc: &GetDefaultBytes,
                                         findSubResFunc: &DefaultFindSubRes,
                                         errorValue: BadCursor,
                                         },
    X11_RESTYPE_COLORMAP & (RC_LASTPREDEF - 1): {
                                           deleteFunc: &FreeColormap,
                                           sizeFunc: &GetDefaultBytes,
                                           findSubResFunc: &DefaultFindSubRes,
                                           errorValue: BadColor,
                                           },
    X11_RESTYPE_CMAPENTRY & (RC_LASTPREDEF - 1): {
                                            deleteFunc: &FreeClientPixels,
                                            sizeFunc: &GetDefaultBytes,
                                            findSubResFunc: &DefaultFindSubRes,
                                            errorValue: BadColor,
                                            },
    X11_RESTYPE_OTHERCLIENT & (RC_LASTPREDEF - 1): {
                                              deleteFunc: &OtherClientGone,
                                              sizeFunc: &GetDefaultBytes,
                                              findSubResFunc: &DefaultFindSubRes,
                                              errorValue: BadValue,
                                              },
    X11_RESTYPE_PASSIVEGRAB & (RC_LASTPREDEF - 1): {
                                              deleteFunc: &DeletePassiveGrab,
                                              sizeFunc: &GetDefaultBytes,
                                              findSubResFunc: &DefaultFindSubRes,
                                              errorValue: BadValue,
                                              },
];

CallbackListPtr ResourceStateCallback;

pragma(inline, true) private void CallResourceStateCallback(ResourceState state, ResourceRec* res)
{
    if (ResourceStateCallback) {
        ResourceStateInfoRec rsi = { state, res.id, res.type, res.value };
        CallCallbacks(&ResourceStateCallback, &rsi);
    }
}

RESTYPE CreateNewResourceType(DeleteType deleteFunc, const(char)* name)
{
    RESTYPE next = lastResourceType + 1;
    ResourceType* types = void;

    if (next & lastResourceClass)
        return 0;
    types = cast(ResourceType*)reallocarray(resourceTypes, next + 1, typeof(*resourceTypes).sizeof);
    if (!types)
        return 0;

    lastResourceType = next;
    resourceTypes = types;
    resourceTypes[next].deleteFunc = deleteFunc;
    resourceTypes[next].sizeFunc = &GetDefaultBytes;
    resourceTypes[next].findSubResFunc = &DefaultFindSubRes;
    resourceTypes[next].errorValue = BadValue;

static if (X_REGISTRY_RESOURCE) {
    /* Called even if name is NULL, to remove any previous entry */
    RegisterResourceName(next, name);
}

    return next;
}

/**
 * Get the function used to calculate resource size. Extensions and
 * drivers need to be able to determine the current size calculation
 * function if they want to wrap or override it.
 *
 * @param[in] type     Resource type used in size calculations.
 *
 * @return Function to calculate the size of a single
 *                     resource.
 */
SizeType GetResourceTypeSizeFunc(RESTYPE type)
{
    return resourceTypes[type & TypeMask].sizeFunc;
}

/**
 * Override the default function that calculates resource size. For
 * example, video driver knows better how to calculate pixmap memory
 * usage and can therefore wrap or override size calculation for
 * X11_RESTYPE_PIXMAP.
 *
 * @param[in] type     Resource type used in size calculations.
 *
 * @param[in] sizeFunc Function to calculate the size of a single
 *                     resource.
 */
void SetResourceTypeSizeFunc(RESTYPE type, SizeType sizeFunc)
{
    resourceTypes[type & TypeMask].sizeFunc = sizeFunc;
}

/**
 * Provide a function for iterating the subresources of a resource.
 * This allows for example more accurate accounting of the (memory)
 * resources consumed by a resource.
 *
 * @see FindSubResources
 *
 * @param[in] type     Resource type used in size calculations.
 *
 * @param[in] sizeFunc Function to calculate the size of a single
 *                     resource.
 */
void SetResourceTypeFindSubResFunc(RESTYPE type, FindTypeSubResources findFunc)
{
    resourceTypes[type & TypeMask].findSubResFunc = findFunc;
}

void SetResourceTypeErrorValue(RESTYPE type, int errorValue)
{
    resourceTypes[type & TypeMask].errorValue = errorValue;
}

RESTYPE CreateNewResourceClass()
{
    RESTYPE next = lastResourceClass >> 1;

    if (next & lastResourceType)
        return 0;
    lastResourceClass = next;
    TypeMask = next - 1;
    return next;
}

private ClientResourceRec[MAXCLIENTS] clientTable;

private uint ilog2(int val)
{
    int bits = void;

    if (val <= 0)
	return 0;
    for (bits = 0; val != 0; bits++)
	val >>= 1;
    return bits - 1;
}

/*****************
 * ResourceClientBits
 *    Returns the client bit offset in the client + resources ID field
 *****************/

uint ResourceClientBits()
{
    // Объявляем переменные без инициализации '= 0' (в D они всё равно занулятся по умолчанию)
    // Но теперь компилятор не будет пытаться вычислить функцию в CTFE
    static uint cache_ilog2;
    static uint cache_limit;

    if (LimitClients != cache_limit) {
        cache_limit = LimitClients;
        cache_ilog2 = ilog2(LimitClients);
    }

    return cache_ilog2;
}

/*****************
 * InitClientResources
 *    When a new client is created, call this to allocate space
 *    in resource table
 *****************/

Bool InitClientResources(ClientPtr client)
{
    int i = void;

    if (client == serverClient) {
        lastResourceType = X11_RESTYPE_LASTPREDEF;
        lastResourceClass = RC_LASTPREDEF;
        TypeMask = RC_LASTPREDEF - 1;
        free(resourceTypes);
        resourceTypes = cast(ResourceType*) calloc(1, predefTypes.sizeof);
        if (!resourceTypes)
            return FALSE;
        memcpy(resourceTypes, predefTypes.ptr, predefTypes.sizeof);
    }
    clientTable[i = client.index].resources =
        cast(_Resource**)calloc(INITBUCKETS, ResourcePtr.sizeof);
    if (!clientTable[i].resources)
        return FALSE;
    clientTable[i].buckets = INITBUCKETS;
    clientTable[i].elements = 0;
    clientTable[i].hashsize = INITHASHSIZE;
    /* Many IDs allocated from the server client are visible to clients,
     * so we don't use the SERVER_BIT for them, but we have to start
     * past the magic value constants used in the protocol.  For normal
     * clients, we can start from zero, with SERVER_BIT set.
     */
    clientTable[i].fakeID = client.clientAsMask |
        (client.index ? SERVER_BIT : SERVER_MINID);
    clientTable[i].endFakeID = (clientTable[i].fakeID | RESOURCE_ID_MASK) + 1;
    for (int j = 0; j < INITBUCKETS; j++) {
        clientTable[i].resources[j] = null;
    }
    return TRUE;
}

int HashResourceID(XID id, uint numBits)
{
    static XID mask;

    if (!mask)
        mask = RESOURCE_ID_MASK;
    id &= mask;
    if (numBits < 9)
        return cast(int)((id ^ (id >> numBits) ^ (id >> (numBits<<1))) & ~((~0U) << numBits));
    return cast(int)((id ^ (id >> numBits)) & ~((~0U) << numBits));
}

private XID AvailableID(int client, XID id, XID maxid, XID goodid)
{
    ResourcePtr res = void;

    if ((goodid >= id) && (goodid <= maxid))
        return goodid;
    for (; id <= maxid; id++) {
        res = clientTable[client].resources[HashResourceID(id, clientTable[client].hashsize)];
        while (res && (res.id != id))
            res = res.next;
        if (!res)
            return id;
    }
    return 0;
}

void GetXIDRange(int client, Bool server, XID* minp, XID* maxp)
{
    XID id = void, maxid = void;
    XID goodid = void;

    id = cast(Mask) client << CLIENTOFFSET;
    if (server)
        id |= client ? SERVER_BIT : SERVER_MINID;
    maxid = id | RESOURCE_ID_MASK;
    goodid = 0;
    ResourcePtr* resp = clientTable[client].resources;
    for (int i = clientTable[client].buckets; --i >= 0;) {
        for (ResourcePtr res = *resp++; res; res = res.next) {
            if ((res.id < id) || (res.id > maxid))
                continue;

            bool searchLeft = (res.id - id) >= (maxid - res.id);

            if (searchLeft){
                goodid = AvailableID(client, id, res.id - 1, goodid);
            }
            else{
                goodid = AvailableID(client, res.id + 1, maxid, goodid);
            }
            if (goodid == 0)
                maxid = res.id - 1;
            else
                id = res.id + 1;
        }
    }
    if (id > maxid)
        id = maxid = 0;
    *minp = id;
    *maxp = maxid;
}

/**
 *  GetXIDList is called by the XC-MISC extension's MiscGetXIDList function.
 *  This function tries to find count unused XIDs for the given client.  It
 *  puts the IDs in the array pids and returns the number found, which should
 *  almost always be the number requested.
 *
 *  The circumstances that lead to a call to this function are very rare.
 *  Xlib must run out of IDs while trying to generate a request that wants
 *  multiple ID's, like the Multi-buffering CreateImageBuffers request.
 *
 *  No rocket science in the implementation; just iterate over all
 *  possible IDs for the given client and pick the first count IDs
 *  that aren't in use.  A more efficient algorithm could probably be
 *  invented, but this will be used so rarely that this should suffice.
 */

uint GetXIDList(ClientPtr pClient, uint count, XID* pids)
{
    uint found = 0;
    XID rc = void, id = pClient.clientAsMask;
    XID maxid = void;
    void* val = void;

    maxid = id | RESOURCE_ID_MASK;
    while ((found < count) && (id <= maxid)) {
        rc = dixLookupResourceByClass(&val, id, RC_ANY, serverClient,
                                      DixGetAttrAccess);
        if (rc == BadValue) {
            pids[found++] = id;
        }
        id++;
    }
    return found;
}

/*
 * Return the next usable fake client ID.
 *
 * Normally this is just the next one in line, but if we've used the last
 * in the range, we need to find a new range of safe IDs to avoid
 * over-running another client.
 */

XID FakeClientID(int client)
{
    XID id = void, maxid = void;

    id = clientTable[client].fakeID++;

    // extra paranoid protection, because many places expect 0 as
    // sign for resource not existing
    if (!id)
        return FakeClientID(client);

    if (id != clientTable[client].endFakeID)
        return id;
    GetXIDRange(client, TRUE, &id, &maxid);
    if (!id) {
        if (!client)
            FatalError("FakeClientID: server internal ids exhausted\n");
        dixMarkClientException(clients[client]);
        id = (cast(Mask) client << CLIENTOFFSET) | (SERVER_BIT * 3);
        maxid = id | RESOURCE_ID_MASK;
    }
    clientTable[client].fakeID = id + 1;
    clientTable[client].endFakeID = maxid + 1;

    if (!id)
        return FakeClientID(client);

    return id;
}

Bool AddResource(XID id, RESTYPE type, void* value)
{
    int client = void;
    ClientResourceRec* rrec = void;
    ResourcePtr* head = void;

version (XSERVER_DTRACE) {
    XSERVER_RESOURCE_ALLOC(id, type, value, mixin(TypeNameString!(`type`)));
}
    client = dixClientIdForXID(id);
    rrec = &clientTable[client];
    if (!rrec.buckets) {
        ErrorF("[dix] AddResource(cast(uint)%lx, %x, %lx), client=%d \n",
               cast(c_ulong) id, type, cast(c_ulong) value, client);
        FatalError("client not in use\n");
    }
    if ((rrec.elements >= 4 * rrec.buckets) && (rrec.hashsize < MAXHASHSIZE))
        RebuildTable(client);
    head = &rrec.resources[HashResourceID(id, clientTable[client].hashsize)];
    ResourcePtr res = cast(ResourceRec*) calloc(1, ResourceRec.sizeof);
    if (!res) {
        (*resourceTypes[type & TypeMask].deleteFunc) (value, id);
        return FALSE;
    }
    res.next = *head;
    res.id = id;
    res.type = type;
    res.value = value;
    *head = res;
    rrec.elements++;
    CallResourceStateCallback(ResourceStateAdding, res);
    return TRUE;
}

private void RebuildTable(int client)
{
    int j = void;
    ResourcePtr** tails = void; ResourcePtr* resources = void;

    /*
     * For now, preserve insertion order, since some ddx layers depend
     * on resources being free in the opposite order they are added.
     */

    j = 2 * clientTable[client].buckets;
    tails =  cast(ResourcePtr**) calloc(j, (ResourcePtr*).sizeof);
    if (!tails)
        return;
    resources =  cast(ResourcePtr*) calloc(j, ResourcePtr.sizeof);
    if (!resources) {
        free(tails);
        return;
    }
    for ({ResourcePtr* rptr = resources; ResourcePtr** tptr = tails;} --j >= 0; rptr++, tptr++) {
        *rptr = null;
        *tptr = rptr;
    }
    clientTable[client].hashsize++;
    j = clientTable[client].buckets;
    for ({ResourcePtr* rptr = clientTable[client].resources; ResourcePtr** tptr = void;} --j >= 0; rptr++) {
        for (ResourcePtr res = *rptr, next = void; res; res = next) {
            next = res.next;
            res.next = null;
            tptr = &tails[HashResourceID(res.id, clientTable[client].hashsize)];
            **tptr = res;
            *tptr = &res.next;
        }
    }
    free(tails);
    clientTable[client].buckets *= 2;
    free(clientTable[client].resources);
    clientTable[client].resources = resources;
}

private void doFreeResource(ResourcePtr res, Bool skip)
{
    CallResourceStateCallback(ResourceStateFreeing, res);

    if (!skip)
        resourceTypes[res.type & TypeMask].deleteFunc(res.value, res.id);

    free(res);
}

void FreeResource(XID id, RESTYPE skipDeleteFuncType)
{
    int cid = void;
    ResourcePtr res = void;
    ResourcePtr* prev = void, head = void;
    int* eltptr = void;
    int elements = void;

    if (((cid = dixClientIdForXID(id)) < LimitClients) && clientTable[cid].buckets) {
        head = &clientTable[cid].resources[HashResourceID(id, clientTable[cid].hashsize)];
        eltptr = &clientTable[cid].elements;

        prev = head;
        while ((res = *prev) !is null) {
            if (res.id == id) {
                RESTYPE rtype = res.type;

version (XSERVER_DTRACE) {
                XSERVER_RESOURCE_FREE(res.id, res.type,
                                      res.value, mixin(TypeNameString!(`res.type`)));
}
                *prev = res.next;
                elements = --*eltptr;

                doFreeResource(res, rtype == skipDeleteFuncType);

                if (*eltptr != elements)
                    prev = head;        /* prev may no longer be valid */
            }
            else
                prev = &res.next;
        }
    }
}

void FreeResourceByType(XID id, RESTYPE type, Bool skipFree)
{
    int cid = void;
    ResourcePtr res = void;
    ResourcePtr* prev = void, head = void;

    if (((cid = dixClientIdForXID(id)) < LimitClients) && clientTable[cid].buckets) {
        head = &clientTable[cid].resources[HashResourceID(id, clientTable[cid].hashsize)];

        prev = head;
        while ((res = *prev) !is null) {
            if (res.id == id && res.type == type) {
version (XSERVER_DTRACE) {
                XSERVER_RESOURCE_FREE(res.id, res.type,
                                      res.value, mixin(TypeNameString!(`res.type`)));
}
                *prev = res.next;
                clientTable[cid].elements--;

                doFreeResource(res, skipFree);

                break;
            }
            else
                prev = &res.next;
        }
    }
}

/*
 * Change the value associated with a resource id.  Caller
 * is responsible for "doing the right thing" with the old
 * data
 */

Bool ChangeResourceValue(XID id, RESTYPE rtype, void* value)
{
    int cid = void;

    if (((cid = dixClientIdForXID(id)) < LimitClients) && clientTable[cid].buckets) {
        for (ResourcePtr res = clientTable[cid].resources[HashResourceID(id, clientTable[cid].hashsize)];
            res; res = res.next)
            if ((res.id == id) && (res.type == rtype)) {
                res.value = value;
                return TRUE;
            }
    }
    return FALSE;
}

/* Note: if func adds or deletes resources, then func can get called
 * more than once for some resources.  If func adds new resources,
 * func might or might not get called for them.  func cannot both
 * add and delete an equal number of resources!
 */

void FindClientResourcesByType(ClientPtr client, RESTYPE type, FindResType func, void* cdata)
{
    ResourcePtr* resources = void;
    int elements = void;
    int* eltptr = void;

    if (!client)
        client = serverClient;

    resources = clientTable[client.index].resources;
    eltptr = &clientTable[client.index].elements;
    for (int i = 0; i < clientTable[client.index].buckets; i++) {
        for (ResourcePtr this_ = resources[i], next = void; this_; this_ = next) {
            next = this_.next;
            if (!type || this_.type == type) {
                elements = *eltptr;
                (*func) (this_.value, this_.id, cdata);
                if (*eltptr != elements)
                    next = resources[i];        /* start over */
            }
        }
    }
}

void FindSubResources(void* resource, RESTYPE type, FindAllRes func, void* cdata)
{
    ResourceType rtype = resourceTypes[type & TypeMask];
    rtype.findSubResFunc(resource, func, cdata);
}

void FindAllClientResources(ClientPtr client, FindAllRes func, void* cdata)
{
    ResourcePtr* resources = void;
    int elements = void;
    int* eltptr = void;

    if (!client)
        client = serverClient;

    resources = clientTable[client.index].resources;
    eltptr = &clientTable[client.index].elements;
    for (int i = 0; i < clientTable[client.index].buckets; i++) {
        for (ResourcePtr this_ = resources[i], next = void; this_; this_ = next) {
            next = this_.next;
            elements = *eltptr;
            (*func) (this_.value, this_.id, this_.type, cdata);
            if (*eltptr != elements)
                next = resources[i];    /* start over */
        }
    }
}

void* LookupClientResourceComplex(ClientPtr client, RESTYPE type, FindComplexResType func, void* cdata)
{
    ResourcePtr* resources = void;
    void* value = void;

    if (!client)
        client = serverClient;

    resources = clientTable[client.index].resources;
    for (int i = 0; i < clientTable[client.index].buckets; i++) {
        for (ResourcePtr this_ = resources[i], next = void; this_; this_ = next) {
            next = this_.next;
            if (!type || this_.type == type) {
                /* workaround func freeing the type as DRI1 does */
                value = this_.value;
                if ((*func) (value, this_.id, cdata))
                    return value;
            }
        }
    }
    return null;
}

void FreeClientNeverRetainResources(ClientPtr client)
{
    ResourcePtr* resources = void;
    ResourcePtr this_ = void;
    ResourcePtr* prev = void;
    int elements = void;
    int* eltptr = void;

    if (!client)
        return;

    resources = clientTable[client.index].resources;
    eltptr = &clientTable[client.index].elements;
    for (int j = 0; j < clientTable[client.index].buckets; j++) {
        prev = &resources[j];
        while ((this_ = *prev) !is null) {
            RESTYPE rtype = this_.type;

            if (rtype & RC_NEVERRETAIN) {
version (XSERVER_DTRACE) {
                XSERVER_RESOURCE_FREE(this_.id, this_.type,
                                      this_.value, mixin(TypeNameString!(`this_.type`)));
}
                *prev = this_.next;
                clientTable[client.index].elements--;
                elements = *eltptr;

                doFreeResource(this_, FALSE);

                if (*eltptr != elements)
                    prev = &resources[j];       /* prev may no longer be valid */
            }
            else
                prev = &this_.next;
        }
    }
}

void FreeClientResources(ClientPtr client)
{
    ResourcePtr* resources = void;

    /* This routine shouldn't be called with a null client, but just in
       case ... */

    if (!client)
        return;

    HandleSaveSet(client);

    resources = clientTable[client.index].resources;
    for (int j = 0; j < clientTable[client.index].buckets; j++) {
        /* It may seem silly to update the head of this resource list as
           we delete the members, since the entire list will be deleted any way,
           but there are some resource deletion functions "FreeClientPixels" for
           one which do a LookupID on another resource id (a Colormap id in this
           case), so the resource list must be kept valid up to the point that
           it is deleted, so every time we delete a resource, we must update the
           head, just like in FreeResource. I hope that this doesn't slow down
           mass deletion appreciably. PRH */

        ResourcePtr* head = void;

        head = &resources[j];

        for (ResourcePtr this_ = *head; this_; this_ = *head) {
version (XSERVER_DTRACE) {
            XSERVER_RESOURCE_FREE(this_.id, this_.type,
                                  this_.value, mixin(TypeNameString!(`this_.type`)));
}
            *head = this_.next;
            clientTable[client.index].elements--;

            doFreeResource(this_, FALSE);
        }
    }
    free(clientTable[client.index].resources);
    clientTable[client.index].resources = null;
    clientTable[client.index].buckets = 0;
}

void FreeAllResources()
{
    for (int i = currentMaxClients; --i >= 0;) {
        if (clientTable[i].buckets)
            FreeClientResources(clients[i]);
    }
}

Bool LegalNewID(XID id, ClientPtr client)
{
    void* val = void;
    int rc = void;

static if(XINERAMA){
    XID minid = void, maxid = void;

    if (!noPanoramiXExtension) {
        minid = client.clientAsMask | (client.index ?
                                        SERVER_BIT : SERVER_MINID);
        maxid = (clientTable[client.index].fakeID | RESOURCE_ID_MASK) + 1;
        if ((id >= minid) && (id <= maxid))
            return TRUE;
    }
} /* XINERAMA */
    if (client.clientAsMask == (id & ~RESOURCE_ID_MASK)) {
        rc = dixLookupResourceByClass(&val, id, RC_ANY, serverClient,
                                      DixGetAttrAccess);
        return rc == BadValue;
    }
    return FALSE;
}

int dixLookupResourceByType(void** result, XID id, RESTYPE rtype, ClientPtr client, Mask mode)
{
    int cid = dixClientIdForXID(id);
    ResourcePtr res = null;

    *result = null;
    if ((rtype & TypeMask) > lastResourceType)
        return BadImplementation;

    if ((cid < LimitClients) && clientTable[cid].buckets) {
        res = clientTable[cid].resources[HashResourceID(id, clientTable[cid].hashsize)];

        for (; res; res = res.next)
            if (res.id == id && res.type == rtype)
                break;
    }
    if (client) {
        client.errorValue = cast(uint)id;
    }
    if (!res)
        return resourceTypes[rtype & TypeMask].errorValue;

    if (client) {
        cid = XaceHookResourceAccess(client, id, res.type,
                       res.value, X11_RESTYPE_NONE, null, mode);
        if (cid == BadValue)
            return resourceTypes[rtype & TypeMask].errorValue;
        if (cid != Success)
            return cid;
    }

    *result = res.value;
    return Success;
}

int dixLookupResourceByClass(void** result, XID id, RESTYPE rclass, ClientPtr client, Mask mode)
{
    int cid = dixClientIdForXID(id);
    ResourcePtr res = null;

    *result = null;

    if ((cid < LimitClients) && clientTable[cid].buckets) {
        res = clientTable[cid].resources[HashResourceID(id, clientTable[cid].hashsize)];

        for (; res; res = res.next)
            if (res.id == id && (res.type & rclass))
                break;
    }
    if (client) {
        client.errorValue = cast(uint)id;
    }
    if (!res)
        return BadValue;

    if (client) {
        cid = XaceHookResourceAccess(client, id, res.type,
                       res.value, X11_RESTYPE_NONE, null, mode);
        if (cid != Success)
            return cid;
    }

    *result = res.value;
    return Success;
}

/* new API - try not to call FakeClientID() directly anymore */
XID dixAllocServerXID()
{
    return FakeClientID(0);
}
