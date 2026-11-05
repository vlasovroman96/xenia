module Xext.xres;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
   Copyright (c) 2002  XFree86 Inc
*/

import build.xlibre_server;

import core.stdc.assert_;
import core.stdc.stdio;
import core.stdc.string;
//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.XResproto;

import dix.client_priv;
import dix.dix_priv;
import dix.registry_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.rpcbuf_priv;
import os.client_priv;
import miext.extinit_priv;
import Xext.xace;

import common.misc;
import os.os;
import dix.dixstruct_priv;
import dix.swaprep;
import dix.pixmap;
import dix.window;
import dix.gc;
import common.protocol_versions;
import common.list;
import Xext.hashtable;
import dix.picturestr;
import composite.compint;
import externs.X11.extensions.XResproto;
import os.log;
import dix.extension;
import registry;

Bool noResExtension = FALSE;

/** @brief Holds fragments of responses for ConstructClientIds.
 *
 *  note: there is no consideration for data alignment */
struct FragmentList {
    XList l;
    int bytes;
    /* data follows */
}

enum string FRAGMENT_DATA(string ptr) = `(cast(void*) (cast(char*) (` ~ ptr ~ `) + FragmentList.sizeof))`;

/** @brief Holds structure for the generated response to
           ProcXResQueryClientIds; used by ConstructClientId* -functions */
struct ConstructClientIdCtx {
    int numIds;
    int[MAXCLIENTS] sentClientMasks;
    x_rpcbuf_t rpcbuf;
}

/** @brief Holds the structure for information required to
           generate the response to XResQueryResourceBytes. In addition
           to response it contains information on the query as well,
           as well as some volatile information required by a few
           functions that cannot take that information directly
           via a parameter, as they are called via already-existing
           higher order functions. */
struct ConstructResourceBytesCtx {
    ClientPtr sendClient;
    int numSizes;
    int resultBytes;
    XList response;
    int status;
    c_long numSpecs;
    xXResResourceIdSpec* specs;
    HashTable visitedResources;

    /* Used by AddSubResourceSizeSpec when AddResourceSizeValue is
       handling cross-references */
    HashTable visitedSubResources;

    /* used when ConstructResourceBytesCtx is passed to
       AddResourceSizeValue2 via FindClientResourcesByType */
    RESTYPE resType;

    /* used when ConstructResourceBytesCtx is passed to
       AddResourceSizeValueByResource from ConstructResourceBytesByResource */
    xXResResourceIdSpec* curSpec;

    /** Used when iterating through a single resource's subresources

        @see AddSubResourceSizeSpec */
    xXResResourceSizeValue* sizeValue;
}

/** @brief Allocate and add a sequence of bytes at the end of a fragment list.
           Call DestroyFragments to release the list.

    @param frags A pointer to head of an initialized linked list
    @param bytes Number of bytes to allocate
    @return Returns a pointer to the allocated non-zeroed region
            that is to be filled by the caller. On error (out of memory)
            returns NULL and makes no changes to the list.
*/
private void* AddFragment(XList* frags, int bytes)
{
    FragmentList* f = cast(FragmentList*) calloc(1, ((FragmentList).sizeof + bytes));
    if (!f) {
        return null;
    } else {
        f.bytes = bytes;
        xorg_list_add(&f.l, frags.prev);
        return cast(char*) f + typeof(*f).sizeof;
    }
}

/** @brief Frees a list of fragments. Does not free() root node.

    @param frags The head of the list of fragments
*/
private void DestroyFragments(XList* frags)
{
    FragmentList* it = void, tmp = void;
    if (!xorg_list_is_empty(frags)) {
        mixin(xorg_list_for_each_entry_safe!( "it", "tmp", "frags", "l",q{
            xorg_list_del(&it.l);
            free(it);
        }));
    }
}

private Bool InitConstructResourceBytesCtx(ConstructResourceBytesCtx* ctx, ClientPtr sendClient, c_long numSpecs, xXResResourceIdSpec* specs)
{
    ctx.sendClient = sendClient;
    ctx.numSizes = 0;
    ctx.resultBytes = 0;
    xorg_list_init(&ctx.response);
    ctx.status = Success;
    ctx.numSpecs = numSpecs;
    ctx.specs = specs;
    ctx.visitedResources = ht_create(XID.sizeof, 0,
                                      &ht_resourceid_hash, &ht_resourceid_compare,
                                      null);

    if (!ctx.visitedResources) {
        return FALSE;
    } else {
        return TRUE;
    }
}

private void DestroyConstructResourceBytesCtx(ConstructResourceBytesCtx* ctx)
{
    DestroyFragments(&ctx.response);
    ht_destroy(ctx.visitedResources);
}

private int ProcXResQueryVersion(ClientPtr client)
{
    mixin(REQUEST_AT_LEAST_SIZE!xXResQueryVersionReq);

    xXResQueryVersionReply reply = {
        server_major: SERVER_XRES_MAJOR_VERSION,
        server_minor: SERVER_XRES_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!"server_major");
    mixin(X_REPLY_FIELD_CARD16!"server_minor");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXResQueryClients(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXResQueryClientsReq);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    int num_clients = 0;
    for (int i = 0; i < currentMaxClients; i++) {
        ClientPtr walkClient = clients[i];
        if (walkClient &&
            (dixCallClientAccessCallback(client, walkClient, DixReadAccess) == Success)) {
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)walkClient.clientAsMask); /* resource_base */
            x_rpcbuf_write_CARD32(&rpcbuf, RESOURCE_ID_MASK);         /* resource_mask */
            num_clients++;
        }
    }

    xXResQueryClientsReply reply = {
        num_clients: num_clients
    };

    mixin(X_REPLY_FIELD_CARD32!"num_clients");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private void ResFindAllRes(void* value, XID id, RESTYPE type, void* cdata)
{
    int* counts = cast(int*) cdata;

    counts[(type & TypeMask) - 1]++;
}

private CARD32 resourceTypeAtom(int i)
{
    CARD32 ret = void;

    const(char)* name = LookupResourceName(i);
    if (strcmp(name, XREGISTRY_UNKNOWN)) {
        ret = cast(uint)dixAddAtom(name);
    } else {
        char[40] buf = void;
        snprintf(buf.ptr, buf.sizeof, "Unregistered resource %i", i + 1);
        ret = cast(uint)dixAddAtom(buf.ptr);
    }

    return ret;
}

private int ProcXResQueryClientResources(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXResQueryClientResourcesReq);
    mixin(X_REQUEST_FIELD_CARD32!"xid");

    ClientPtr resClient = dixClientForXID(stuff.xid);

    if ((!resClient) ||
        (dixCallClientAccessCallback(client, resClient, DixReadAccess)
                              != Success)) {
        client.errorValue = cast(uint)stuff.xid;
        return BadValue;
    }

    int* counts = cast(int*) calloc(lastResourceType + 1, int.sizeof);
    if (!counts)
        return BadAlloc;

    FindAllClientResources(resClient, &ResFindAllRes, counts);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    int num_types = 0;
    for (int i = 0; i <= lastResourceType; i++) {
        /* dont report currently unused resource types */
        if (!(counts[i])) {
            continue;
        }

        /* write xXResType */
        x_rpcbuf_write_CARD32(&rpcbuf, resourceTypeAtom(i + 1));
        x_rpcbuf_write_CARD32(&rpcbuf, counts[i]);

        num_types++;
    }

    free(counts);

    xXResQueryClientResourcesReply reply = {
        num_types: num_types
    };

    mixin(X_REPLY_FIELD_CARD32!"num_types");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private void ResFindResourcePixmaps(void* value, XID id, RESTYPE type, void* cdata)
{
    SizeType sizeFunc = GetResourceTypeSizeFunc(type);
    ResourceSizeRec size = { 0, 0, 0 };
    c_ulong* bytes = cast(c_ulong*)cdata;

    sizeFunc(value, id, &size);
    *bytes += size.pixmapRefSize;
}

private int ProcXResQueryClientPixmapBytes(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXResQueryClientPixmapBytesReq);
    mixin(X_REQUEST_FIELD_CARD32!"xid");

    ClientPtr owner = dixClientForXID(stuff.xid);
    if ((!owner) ||
        (dixCallClientAccessCallback(client, owner, DixReadAccess)
                              != Success)) {
        client.errorValue = cast(uint)stuff.xid;
        return BadValue;
    }

    c_ulong bytes = 0;
    FindAllClientResources(owner, &ResFindResourcePixmaps,
                           cast(void*) (&bytes));

    static if(_XSERVER64) {
        xXResQueryClientPixmapBytesReply reply = {
            bytes: cast(uint)bytes,
            bytes_overflow: bytes >> 32
        };
    }
    else {
        xXResQueryClientPixmapBytesReply reply = {
            bytes: cast(uint)bytes,
        };
    }

    mixin(X_REPLY_FIELD_CARD32!"bytes");
    mixin(X_REPLY_FIELD_CARD32!"bytes_overflow");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/** @brief Finds out if a client's information need to be put into the
    response; marks client having been handled, if that is the case.

    @param client   The client to send information about
    @param mask     The request mask (0 to send everything, otherwise a
                    bitmask of X_XRes*Mask)
    @param ctx      The context record that tells which clients and id types
                    have been already handled
    @param sendMask Which id type are we now considering. One of X_XRes*Mask.

    @return Returns TRUE if the client information needs to be on the
            response, otherwise FALSE.
*/
private Bool WillConstructMask(ClientPtr client, CARD32 mask, ConstructClientIdCtx* ctx, int sendMask)
{
    if ((!mask || (mask & sendMask))
        && !(ctx.sentClientMasks[client.index] & sendMask)) {
        ctx.sentClientMasks[client.index] |= sendMask;
        return TRUE;
    } else {
        return FALSE;
    }
}

/** @brief Constructs a response about a single client, based on a certain
           client id spec

    @param sendClient Which client wishes to receive this answer. Used for
                      byte endianness.
    @param client     Which client are we considering.
    @param mask       The client id spec mask indicating which information
                      we want about this client.
    @param ctx        The context record containing the constructed response
                      and information on which clients and masks have been
                      already handled.

    @return Return TRUE if everything went OK, otherwise FALSE which indicates
            a memory allocation problem.
*/
private Bool ConstructClientIdValue(ClientPtr sendClient, ClientPtr client, CARD32 mask, ConstructClientIdCtx* ctx)
{
    if (WillConstructMask(client, mask, ctx, X_XResClientXIDMask)) {
        xXResClientIdValue reply;
    
        reply.spec.client = cast(uint)client.clientAsMask;
        reply.spec.mask = X_XResClientXIDMask;

        /* can't used REPLY_FIELD_*() here, because we're looking at sendClient */
        if (sendClient.swapped) {
            swapl (&reply.spec.mask);
            swapl (&reply.spec.client);
            /* swapl (&reply.length, n); - not required for reply.length = 0 */
        }

        x_rpcbuf_write_CARD8s(&ctx.rpcbuf, cast(CARD8*)&reply, reply.sizeof);
        ++ctx.numIds;
    }
    if (WillConstructMask(client, mask, ctx, X_XResLocalClientPIDMask)) {
        pid_t pid = GetClientPid(client);

        if (pid == -1) {
            return TRUE;
        }

        xXResClientIdValue reply;
    
        reply.spec.client = cast(uint)client.clientAsMask;
        reply.spec.mask = X_XResLocalClientPIDMask;
        reply.length = 4;

        if (sendClient.swapped) {
            swapl (&reply.spec.client);
            swapl (&reply.spec.mask);
            swapl (&reply.length);
        }

        x_rpcbuf_write_CARD8s(&ctx.rpcbuf, cast(CARD8*)&reply, reply.sizeof);
        x_rpcbuf_write_CARD32(&ctx.rpcbuf, pid);

        ++ctx.numIds;
    }

    /* memory allocation errors earlier may return with FALSE */
    return TRUE;
}

/** @brief Constructs a response about all clients, based on a client id specs

    @param client   Which client which we are constructing the response for.
    @param numSpecs Number of client id specs in specs
    @param specs    Client id specs

    @return Return Success if everything went OK, otherwise a Bad* (currently
            BadAlloc or BadValue)
*/
private int ConstructClientIds(ClientPtr client, int numSpecs, xXResClientIdSpec* specs, ConstructClientIdCtx* ctx)
{
    for (int specIdx = 0; specIdx < numSpecs; ++specIdx) {
        if (specs[specIdx].client == 0) {
            for (int c = 0; c < currentMaxClients; ++c) {
                if (clients[c] &&
                    (dixCallClientAccessCallback(client, clients[c], DixReadAccess)
                                          == Success)) {
                    if (!ConstructClientIdValue(client, clients[c],
                                                specs[specIdx].mask, ctx)) {
                        return BadAlloc;
                    }
                }
            }
        } else {
            ClientPtr owner = dixClientForXID(specs[specIdx].client);
            if (owner &&
                (dixCallClientAccessCallback(client, owner, DixReadAccess)
                                      == Success)) {
                if (!ConstructClientIdValue(client, owner,
                                            specs[specIdx].mask, ctx)) {
                    return BadAlloc;
                }
            }
        }
    }

    /* memory allocation errors earlier may return with BadAlloc */
    return Success;
}

/** @brief Response to XResQueryClientIds request introduced in XResProto v1.2

    @param client Which client which we are constructing the response for.

    @return Returns the value returned from ConstructClientIds with the same
            semantics
*/
private int ProcXResQueryClientIds(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXResQueryClientIdsReq);
    mixin(X_REQUEST_FIELD_CARD32!"numSpecs");

    mixin(REQUEST_FIXED_SIZE!("xXResQueryClientIdsReq",
                       "cast(ulong)stuff.numSpecs * xXResClientIdSpec.sizeof"));

    xXResClientIdSpec* specs = cast(xXResClientIdSpec*) (cast(void*) (cast(char*) stuff + xXResQueryClientIdsReq.sizeof));

    if (client.swapped) {
        /* each spec is made of two CARD32's */
        SwapLongs(cast(CARD32*)specs, stuff.numSpecs * 2);
    }

    ConstructClientIdCtx ctx;

    ctx.rpcbuf.swapped = client.swapped;
    ctx.rpcbuf.swapped = TRUE;

    int rc = ConstructClientIds(client, cast(int)stuff.numSpecs, specs, &ctx);
    if (rc == Success) {
        xXResQueryClientIdsReply reply = {
            numIds: ctx.numIds
        };

        mixin(X_REPLY_FIELD_CARD32!"numIds");

        rc = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "ctx.rpcbuf"));
    }

    x_rpcbuf_clear(&ctx.rpcbuf);
    return rc;
}

/** @brief Swaps xXResResourceIdSpec endianness */
private void SwapXResResourceIdSpec(xXResResourceIdSpec* spec)
{
    swapl(&spec.resource);
    swapl(&spec.type);
}

/** @brief Swaps xXResResourceSizeSpec endianness */
private void SwapXResResourceSizeSpec(xXResResourceSizeSpec* size)
{
    SwapXResResourceIdSpec(&size.spec);
    swapl(&size.bytes);
    swapl(&size.refCount);
    swapl(&size.useCount);
}

/** @brief Swaps xXResResourceSizeValue endianness */
private void SwapXResResourceSizeValue(xXResResourceSizeValue* reply)
{
    SwapXResResourceSizeSpec(&reply.size);
    swapl(&reply.numCrossReferences);
}

/** @brief Swaps the response bytes */
private void SwapXResQueryResourceBytes(XList* response)
{
    XList* it = response.next;

    while (it != response) {
        xXResResourceSizeValue* value = cast(xXResResourceSizeValue*)mixin(FRAGMENT_DATA!(`it`));
        it = it.next;
        for (int c = 0; c < value.numCrossReferences; ++c) {
            xXResResourceSizeSpec* spec = cast(xXResResourceSizeSpec*)mixin(FRAGMENT_DATA!(`it`));
            SwapXResResourceSizeSpec(spec);
            it = it.next;
        }
        SwapXResResourceSizeValue(value);
    }
}

/** @brief Adds xXResResourceSizeSpec describing a resource's size into
           the buffer contained in the context. The resource is considered
           to be a subresource.

   @see AddResourceSizeValue

   @param[in] value     The X resource object on which to add information
                        about to the buffer
   @param[in] id        The ID of the X resource
   @param[in] type      The type of the X resource
   @param[in/out] cdata The context object of type ConstructResourceBytesCtx.
                        Void pointer type is used here to satisfy the type
                        FindRes
*/
private void AddSubResourceSizeSpec(void* value, XID id, RESTYPE type, void* cdata)
{
    ConstructResourceBytesCtx* ctx = cast(ConstructResourceBytesCtx*)cdata;

    if (ctx.status == Success) {
        xXResResourceSizeSpec** prevCrossRef = cast(xXResResourceSizeSpec**)ht_find(ctx.visitedSubResources, &value);
        if (!prevCrossRef) {
            Bool ok = TRUE;
            xXResResourceSizeSpec* crossRef = cast(xXResResourceSizeSpec*)AddFragment(&ctx.response, xXResResourceSizeSpec.sizeof);
            ok = ok && crossRef !is null;
            if (ok) {
                xXResResourceSizeSpec** p = void;
                p = cast(xXResResourceSizeSpec**)ht_add(ctx.visitedSubResources, &value);
                if (!p) {
                    ok = FALSE;
                } else {
                    *p = crossRef;
                }
            }
            if (!ok) {
                ctx.status = BadAlloc;
            } else {
                SizeType sizeFunc = GetResourceTypeSizeFunc(type);
                ResourceSizeRec size = { 0, 0, 0 };
                sizeFunc(value, id, &size);

                crossRef.spec.resource = cast(uint)id;
                crossRef.spec.type = resourceTypeAtom(type);
                crossRef.bytes = cast(uint)size.resourceSize;
                crossRef.refCount = cast(uint)size.refCnt;
                crossRef.useCount = 1;

                ++ctx.sizeValue.numCrossReferences;

                ctx.resultBytes += typeof(*crossRef).sizeof;
            }
        } else {
            /* if we have visited the subresource earlier (from current parent
               resource), just increase its use count by one */
            ++(*prevCrossRef).useCount;
        }
    }
}

/** @brief Adds xXResResourceSizeValue describing a resource's size into
           the buffer contained in the context. In addition, the
           subresources are iterated and added as xXResResourceSizeSpec's
           by using AddSubResourceSizeSpec

   @see AddSubResourceSizeSpec

   @param[in] value     The X resource object on which to add information
                        about to the buffer
   @param[in] id        The ID of the X resource
   @param[in] type      The type of the X resource
   @param[in/out] cdata The context object of type ConstructResourceBytesCtx.
                        Void pointer type is used here to satisfy the type
                        FindRes
*/
private void AddResourceSizeValue(void* ptr, XID id, RESTYPE type, void* cdata)
{
    ConstructResourceBytesCtx* ctx = cast(ConstructResourceBytesCtx*)cdata;
    if (ctx.status == Success &&
        !ht_find(ctx.visitedResources, &id)) {
        Bool ok = TRUE;
        HashTable ht = void;
        HtGenericHashSetupRec htSetup = {
            keySize: (void*).sizeof
        };

        /* it doesn't matter that we don't undo the work done here
         * immediately. All but ht_init will be undone at the end
         * of the request and there can happen no failure after
         * ht_init, so we don't need to clean it up here in any
         * special way */

        xXResResourceSizeValue* value = cast(xXResResourceSizeValue*)AddFragment(&ctx.response, xXResResourceSizeValue.sizeof);
        if (!value) {
            ok = FALSE;
        }
        ok = ok && ht_add(ctx.visitedResources, &id);
        if (ok) {
            ht = ht_create(htSetup.keySize,
                           (xXResResourceSizeSpec*).sizeof,
                           &ht_generic_hash, &ht_generic_compare,
                           &htSetup);
            ok = ok && ht;
        }

        if (!ok) {
            ctx.status = BadAlloc;
        } else {
            SizeType sizeFunc = GetResourceTypeSizeFunc(type);
            ResourceSizeRec size = { 0, 0, 0 };

            sizeFunc(ptr, id, &size);

            value.size.spec.resource = cast(uint)id;
            value.size.spec.type = resourceTypeAtom(type);
            value.size.bytes = cast(uint)size.resourceSize;
            value.size.refCount = cast(uint)size.refCnt;
            value.size.useCount = 1;
            value.numCrossReferences = 0;

            ctx.sizeValue = value;
            ctx.visitedSubResources = ht;
            FindSubResources(ptr, type, &AddSubResourceSizeSpec, ctx);
            ctx.visitedSubResources = null;
            ctx.sizeValue = null;

            ctx.resultBytes += typeof(*value).sizeof;
            ++ctx.numSizes;

            ht_destroy(ht);
        }
    }
}

/** @brief A variant of AddResourceSizeValue that passes the resource type
           through the context object to satisfy the type FindResType

   @see AddResourceSizeValue

   @param[in] ptr        The resource
   @param[in] id         The resource ID
   @param[in/out] cdata  The context object that contains the resource type
*/
private void AddResourceSizeValueWithResType(void* ptr, XID id, void* cdata)
{
    ConstructResourceBytesCtx* ctx = cast(ConstructResourceBytesCtx*)cdata;
    AddResourceSizeValue(ptr, id, ctx.resType, cdata);
}

/** @brief Adds the information of a resource into the buffer if it matches
           the match condition.

   @see AddResourceSizeValue

   @param[in] ptr        The resource
   @param[in] id         The resource ID
   @param[in] type       The resource type
   @param[in/out] cdata  The context object as a void pointer to satisfy the
                         type FindAllRes
*/
private void AddResourceSizeValueByResource(void* ptr, XID id, RESTYPE type, void* cdata)
{
    ConstructResourceBytesCtx* ctx = cast(ConstructResourceBytesCtx*)cdata;
    xXResResourceIdSpec* spec = ctx.curSpec;

    if ((!spec.type || spec.type == type) &&
        (!spec.resource || spec.resource == id)) {
        AddResourceSizeValue(ptr, id, type, ctx);
    }
}

/** @brief Add all resources of the client into the result buffer
           disregarding all those specifications that specify the
           resource by its ID. Those are handled by
           ConstructResourceBytesByResource

   @see ConstructResourceBytesByResource

   @param[in] aboutClient  Which client is being considered
   @param[in/out] ctx      The context that contains the resource id
                           specifications as well as the result buffer
*/
private void ConstructClientResourceBytes(ClientPtr aboutClient, ConstructResourceBytesCtx* ctx)
{
    for (int specIdx = 0; specIdx < ctx.numSpecs; ++specIdx) {
        xXResResourceIdSpec* spec = ctx.specs + specIdx;
        if (spec.resource) {
            /* these specs are handled elsewhere */
        } else if (spec.type) {
            ctx.resType = cast(uint)spec.type;
            FindClientResourcesByType(aboutClient, cast(uint)spec.type,
                                      &AddResourceSizeValueWithResType, ctx);
        } else {
            FindAllClientResources(aboutClient, &AddResourceSizeValue, ctx);
        }
    }
}

/** @brief Add the sizes of all such resources that can are specified by
           their ID in the resource id specification. The scan can
           by limited to a client with the aboutClient parameter

   @see ConstructResourceBytesByResource

   @param[in] aboutClient  Which client is being considered. This may be None
                           to mean all clients.
   @param[in/out] ctx      The context that contains the resource id
                           specifications as well as the result buffer. In
                           addition this function uses the curSpec field to
                           keep a pointer to the current resource id
                           specification in it, which can be used by
                           AddResourceSizeValueByResource .
*/
private void ConstructResourceBytesByResource(XID aboutClient, ConstructResourceBytesCtx* ctx)
{
    for (int specIdx = 0; specIdx < ctx.numSpecs; ++specIdx) {
        xXResResourceIdSpec* spec = ctx.specs + specIdx;
        if (spec.resource) {
            ClientPtr client = dixClientForXID(spec.resource);
            if (client && (aboutClient == None || aboutClient == client.index)) {
                ctx.curSpec = spec;
                FindAllClientResources(client,
                                       &AddResourceSizeValueByResource,
                                       ctx);
            }
        }
    }
}

/** @brief Build the resource size response for the given client
           (or all if not specified) per the parameters set up
           in the context object.

  @param[in] aboutClient  Which client to consider or None for all clients
  @param[in/out] ctx      The context object that contains the request as well
                          as the response buffer.
*/
private int ConstructResourceBytes(XID aboutClient, ConstructResourceBytesCtx* ctx)
{
    if (aboutClient) {
        ClientPtr client = dixClientForXID(aboutClient);
        if (!client) {
            ctx.sendClient.errorValue = aboutClient;
            return BadValue;
        }

        ConstructClientResourceBytes(client, ctx);
        ConstructResourceBytesByResource(aboutClient, ctx);
    } else {
        int clientIdx = void;

        ConstructClientResourceBytes(null, ctx);

        for (clientIdx = 0; clientIdx < currentMaxClients; ++clientIdx) {
            ClientPtr client = clients[clientIdx];

            if (client) {
                ConstructClientResourceBytes(client, ctx);
            }
        }

        ConstructResourceBytesByResource(None, ctx);
    }


    return ctx.status;
}

/** @brief Implements the XResQueryResourceBytes of XResProto v1.2 */
private int ProcXResQueryResourceBytes(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXResQueryResourceBytesReq);
    mixin(X_REQUEST_FIELD_CARD32!"numSpecs");

    mixin(REQUEST_FIXED_SIZE!("xXResQueryResourceBytesReq",
                       "(cast(ulong)stuff.numSpecs) * xXResResourceIdSpec.sizeof"));

    if (client.swapped) {
        xXResResourceIdSpec* specs = cast(xXResResourceIdSpec*) (cast(void*) (cast(char*) stuff + typeof(*stuff).sizeof));
        for (int c = 0; c < stuff.numSpecs; ++c)
            SwapXResResourceIdSpec(specs + c);
    }

    ConstructResourceBytesCtx ctx = void;
    if (!InitConstructResourceBytesCtx(&ctx, client,
                                       stuff.numSpecs,
                                       cast(xXResResourceIdSpec*) (cast(char*) stuff +
                                                sz_xXResQueryResourceBytesReq))) {
        return BadAlloc;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    int rc = ConstructResourceBytes(stuff.client, &ctx);

    if (rc == Success) {
        xXResQueryResourceBytesReply reply = {
            numSizes: ctx.numSizes
        };

        mixin(X_REPLY_FIELD_CARD32!"numSizes");

        if (client.swapped) {
            SwapXResQueryResourceBytes(&ctx.response);
        }

        FragmentList* it = void;
        mixin(xorg_list_for_each_entry!("it", "&ctx.response", "l", q{
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(ubyte*)mixin(FRAGMENT_DATA!(`it`)), it.bytes);
        }));

        if (rpcbuf.wpos != ctx.resultBytes)
            LogMessage(X_WARNING, "ProcXResQueryClientIds() rpcbuf size (%ld) context size (%ld)\n",
                       cast(c_ulong)rpcbuf.wpos, cast(c_ulong)ctx.resultBytes);

        rc = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
    }

    DestroyConstructResourceBytesCtx(&ctx);
    return rc;
}

private int ProcResDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_XResQueryVersion:
        return ProcXResQueryVersion(client);
    case X_XResQueryClients:
        return ProcXResQueryClients(client);
    case X_XResQueryClientResources:
        return ProcXResQueryClientResources(client);
    case X_XResQueryClientPixmapBytes:
        return ProcXResQueryClientPixmapBytes(client);
    case X_XResQueryClientIds:
        return ProcXResQueryClientIds(client);
    case X_XResQueryResourceBytes:
        return ProcXResQueryResourceBytes(client);
    default: break;
    }

    return BadRequest;
}

void ResExtensionInit()
{
    cast(void) AddExtension(XRES_NAME, 0, 0,
                        &ProcResDispatch, &ProcResDispatch,
                        null, &StandardMinorOpcode);
}
