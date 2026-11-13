module dix.resource_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;

public import dix.callback;
import dix.resource;
import build.xlibre_server;

enum RESOURCE_AND_CLIENT_COUNT = 29;

enum string SameClient(string obj,string client) = `
        CLIENT_BITS(` ~ obj ~ `.resource) == (` ~ client ~ `).clientAsMask`;

/*
 * Resource IDs having that bit set still belonging to some client,
 * but are server-internal, thus invisible to clients.
 */
enum SERVER_BIT =           cast(Mask)0x40000000;       /* use illegal bit */;

/* client field */
@property uint RESOURCE_CLIENT_MASK() => ((((1u << ResourceClientBits())) - 1) << CLIENTOFFSET);

@property auto CLIENTOFFSET() => (RESOURCE_AND_CLIENT_COUNT - ResourceClientBits());

@property auto CLIENT_BITS(T)(T id) {
        return id & RESOURCE_CLIENT_MASK;
}

@property uint RESOURCE_ID_MASK() => ((1u << CLIENTOFFSET) - 1);

/*
 * @brief retrieve client that owns given window
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * @param WindowPtr to the window whose client shall be retrieved
 * @return pointer to ClientRec structure or NULL
 */
ClientPtr dixClientForWindow(WindowPtr pWin);

/*
 * @brief retrieve client that owns given grab
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * @param GrabPtr to the grab whose owning client shall be retrieved
 * @return pointer to ClientRec structure or NULL
 */
ClientPtr dixClientForGrab(GrabPtr pGrab);

/*
 * @brief retrieve client that owns InputClients
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * @param GrabPtr to the InputClients whose owning client shall be retrieved
 * @return pointer to ClientRec structure or NULL
 */
ClientPtr dixClientForInputClients(InputClientsPtr pInputClients);

/*
 * @brief retrieve client that owns OtherClients
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * @param GrabPtr to the OtherClients whose owning client shall be retrieved
 * @return pointer to ClientRec structure or NULL
 */
ClientPtr dixClientForOtherClients(OtherClientsPtr pOtherClients);

/*
 * @brief extract client ID from XID
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * This ID is frequently used as table index, eg. for client or resource lookup.
 *
 * @param XID the ID of the resource whose client is retrieved
 * @return index of the client (within client or resource table)
 */
pragma(inline, true) ushort dixClientIdForXID(XID xid) {
    return cast(ushort)((CLIENT_BITS(xid) >> CLIENTOFFSET));
}

/*
 * @brief retrieve client pointer from XID
 *
 * XIDs carry the ID of the client who created/owns the resource in upper bits.
 * (every client so is assigned a range of XIDs it may use for resource creation)
 *
 * @param XID the ID of the resource whose client is retrieved
 * @return pointer to ClientRec structure or NULL
 */
pragma(inline, true) ClientPtr dixClientForXID(XID xid) {
    const(int) idx = dixClientIdForXID(xid);
    if (idx < MAXCLIENTS)
        return clients[idx];
    return null;
}

/*
 * @brief check whether resource is owned by server
 *
 * @param XID the ID of the resource to check
 * @return True if resource is server owned
 */
pragma(inline, true) Bool dixResouceIsServerOwned(XID xid) {
    return (dixClientForXID(xid) == serverClient);
}

/*
 * @brief hash a XID for using as hashtable index
 *
 * @param id the XID to hash
 * @param numBits number of bits in the resulting hash (>=0)
 * @result the computed hash value
 *
 * @note This function is really only for handling
 * INITHASHSIZE..MAXHASHSIZE bit hashes, but will handle any number
 * of bits by either masking numBits lower bits of the ID or by
 * providing at most MAXHASHSIZE hashes.
 */
// int HashResourceID(XID id, uint numBits);

/*
 * @brief scan for free XIDs for client
 *
 * @param pClient the client to scan
 * @param count maximum size of items to return
 * @param pids pointer to XID where to return found free XIDs
 * @result number of free XIDs
 */
// uint GetXIDList(ClientPtr pClient, uint count, XID* pids);

/*
 * @brief retrieve a range of free XIDs for given client
 *
 * @param client the client to scan
 * @param server True if scanning for free server XIDs
 * @param minp pointer to result buffer: minimum XID of found range
 * @param maxp pointer to result buffer: maximum XID of found range
 */
// void GetXIDRange(int client, Bool server, XID* minp, XID* maxp);

/* Resource state callback */
// CallbackListPtr ResourceStateCallback;

enum ResourceState {
    ResourceStateAdding,
    ResourceStateFreeing
}
alias ResourceStateAdding = ResourceState.ResourceStateAdding;
alias ResourceStateFreeing = ResourceState.ResourceStateFreeing;


struct ResourceStateInfoRec {
    ResourceState state;
    XID id;
    RESTYPE type;
    void* value;
}

 /* _XSERVER_DIX_RESOURCE_PRIV_H */
