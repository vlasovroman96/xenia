module security;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1996, 1998  The Open Group

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

*/

import build.dix_config;

//import x11.Xmd;
// //import externs.X11.extensions.securproto;
// //import x11.Xfuncproto;

import dix.client_priv;
import dix.devices_priv;
import dix.dix_priv;
import dix.extension_priv;
import dix.registry_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.server_priv;
import miext.extinit_priv;
import os.audit_priv;
import os.auth;
import os.client_priv;
import os.osdep;
import dix.atom;
import dix.scrnintstr;
import dix.inputstr;
import dix.window;
import dix.property;
import dix.privates;
import Xext.xacestr;
import Xext.securitysrv;
import common.protocol_versions;
import externs.X11.extensions.securproto;
import externs.X11.extensions.secur;
import os.log;
import dix.dixutils;
import dix.extension;
import dix.events;
import os.WaitFor;
import registry;
import dix.dispatch;
import common.bytes;
import common.swap;


enum XSecurityAllEventMasks = 1<<0;

Bool noSecurityExtension = FALSE;

/* Extension stuff */
private int SecurityErrorBase;   /* first Security error number */
private int SecurityEventBase;   /* first Security event number */

RESTYPE SecurityAuthorizationResType;   /* resource type for authorizations */
private RESTYPE RTEventClient;

private CallbackListPtr SecurityValidateGroupCallback = null;

/* Private state record */
private DevPrivateKeyRec stateKeyRec;

enum stateKey = (&stateKeyRec);

/* This is what we store as client security state */
struct SecurityStateRec {
    uint haveState : 1;
    uint live : 1;
    uint trustLevel : 2;
    XID authId;
}

/* The only extensions that untrusted clients have access to */
private const(char)*[3] SecurityTrustedExtensions = [
    "XC-MISC",
    "BIG-REQUESTS",
    null
];

/*
 * Access modes that untrusted clients are allowed on trusted objects.
 */
private const(Mask) SecurityResourceMask = DixGetAttrAccess | DixReceiveAccess | DixListPropAccess |
    DixGetPropAccess | DixListAccess;
private const(Mask) SecurityWindowExtraMask = DixRemoveAccess;
private const(Mask) SecurityRootWindowExtraMask = DixReceiveAccess | DixSendAccess | DixAddAccess | DixRemoveAccess;
private const(Mask) SecurityDeviceMask = DixGetAttrAccess | DixReceiveAccess | DixGetFocusAccess |
    DixGrabAccess | DixSetAttrAccess | DixUseAccess;
private const(Mask) SecurityServerMask = DixGetAttrAccess | DixGrabAccess;
private const(Mask) SecurityClientMask = DixGetAttrAccess;

/* SecurityAudit
 *
 * Arguments:
 *	format is the formatting string to be used to interpret the
 *	  remaining arguments.
 *
 * Returns: nothing.
 *
 * Side Effects:
 *	Writes the message to the log file if security logging is on.
 */

private void SecurityAudit(const(char)* format, ...)
{
    va_list args = void;

    if (auditTrailLevel < SECURITY_AUDIT_LEVEL)
        return;
    core.stdc.stdarg.va_start(args, format);
    VAuditF(format, args);
    core.stdc.stdarg.va_end(args);
}                               /* SecurityAudit */

/*
 * Performs a Security permission check.
 */
private int SecurityDoCheck(SecurityStateRec* subj, SecurityStateRec* obj, Mask requested, Mask allowed)
{
    if (!subj.haveState || !obj.haveState)
        return Success;
    if (subj.trustLevel == XSecurityClientTrusted)
        return Success;
    if (obj.trustLevel != XSecurityClientTrusted)
        return Success;
    if ((requested | allowed) == allowed)
        return Success;

    return BadAccess;
}

/*
 * Labels initial server objects.
 */
private void SecurityLabelInitial()
{
    SecurityStateRec* state = void;

    /* Do the serverClient */
    state = cast(SecurityStateRec*)dixLookupPrivate(&serverClient.devPrivates, stateKey);
    state.trustLevel = XSecurityClientTrusted;
    state.haveState = TRUE;
    state.live = FALSE;
}

/*
 * Looks up a request name
 */
pragma(inline, true) private const(char)* SecurityLookupRequestName(ClientPtr client)
{
    return LookupRequestName(client.majorOp, client.minorOp);
}

/* SecurityDeleteAuthorization
 *
 * Arguments:
 *	value is the authorization to delete.
 *	id is its resource ID.
 *
 * Returns: Success.
 *
 * Side Effects:
 *	Frees everything associated with the authorization.
 */

private int SecurityDeleteAuthorization(void* value, XID id)
{
    SecurityAuthorizationPtr pAuth = cast(SecurityAuthorizationPtr) value;
    ushort name_len = void, data_len = void;
    const(char)* name = void;
    char* data = void;
    int status = void;
    int i = void;
    OtherClientsPtr pEventClient = void;

    /* Remove the auth using the os layer auth manager */

    status = AuthorizationFromID(pAuth.id, &name_len, &name, &data_len, &data);
    assert(status);
    status = RemoveAuthorization(name_len, name, data_len, data);
    assert(status);
    cast(void) status;

    /* free the auth timer if there is one */

    if (pAuth.timer)
        TimerFree(pAuth.timer);

    /* send revoke events */

    while ((pEventClient = pAuth.eventClients) !is null) {
        /* send revocation event event */
        xSecurityAuthorizationRevokedEvent are = {
            type: cast(ubyte)(SecurityEventBase + XSecurityAuthorizationRevoked),
            authId: cast(uint)pAuth.id
        };
        WriteEventsToClient(dixClientForOtherClients(pEventClient), 1, cast(xEvent*) &are);
        FreeResource(cast(uint)pEventClient.resource, X11_RESTYPE_NONE);
    }

    /* kill all clients using this auth */

    for (i = 1; i < currentMaxClients; i++)
        if (clients[i]) {
            SecurityStateRec* state = void;

            state = cast(SecurityStateRec*)dixLookupPrivate(&clients[i].devPrivates, stateKey);
            if (state.haveState && state.authId == pAuth.id)
                CloseDownClient(clients[i]);
        }

    SecurityAudit("revoked authorization ID %lu\n", cast(c_ulong)pAuth.id);
    free(pAuth);
    return Success;

}                               /* SecurityDeleteAuthorization */

/* resource delete function for RTEventClient */
private int SecurityDeleteAuthorizationEventClient(void* value, XID id)
{
    OtherClientsPtr pEventClient = void, prev = null;
    SecurityAuthorizationPtr pAuth = cast(SecurityAuthorizationPtr) value;

    for (pEventClient = pAuth.eventClients;
         pEventClient; pEventClient = pEventClient.next) {
        if (pEventClient.resource == id) {
            if (prev)
                prev.next = pEventClient.next;
            else
                pAuth.eventClients = pEventClient.next;
            free(pEventClient);
            return Success;
        }
        prev = pEventClient;
    }
     /*NOTREACHED*/ return -1;  /* make compiler happy */
}                               /* SecurityDeleteAuthorizationEventClient */

/* SecurityComputeAuthorizationTimeout
 *
 * Arguments:
 *	pAuth is the authorization for which we are computing the timeout
 *	seconds is the number of seconds we want to wait
 *
 * Returns:
 *	the number of milliseconds that the auth timer should be set to
 *
 * Side Effects:
 *	Sets pAuth->secondsRemaining to any "overflow" amount of time
 *	that didn't fit in 32 bits worth of milliseconds
 */

private CARD32 SecurityComputeAuthorizationTimeout(SecurityAuthorizationPtr pAuth, uint seconds)
{
    /* maxSecs is the number of full seconds that can be expressed in
     * 32 bits worth of milliseconds
     */
    CARD32 maxSecs = cast(CARD32) (~0) / cast(CARD32) MILLI_PER_SECOND;

    if (seconds > maxSecs) {    /* only come here if we want to wait more than 49 days */
        pAuth.secondsRemaining = cast(int)(seconds - maxSecs);
        return maxSecs * MILLI_PER_SECOND;
    }
    else {                      /* by far the common case */
        pAuth.secondsRemaining = 0;
        return seconds * MILLI_PER_SECOND;
    }
}                               /* SecurityStartAuthorizationTimer */

/* SecurityAuthorizationExpired
 *
 * This function is passed as an argument to TimerSet and gets called from
 * the timer manager in the os layer when its time is up.
 *
 * Arguments:
 *	timer is the timer for this authorization.
 *	time is the current time.
 *	pval is the authorization whose time is up.
 *
 * Returns:
 *	A new time delay in milliseconds if the timer should wait some
 *	more, else zero.
 *
 * Side Effects:
 *	Frees the authorization resource if the timeout period is really
 *	over, otherwise recomputes pAuth->secondsRemaining.
 */

private CARD32 SecurityAuthorizationExpired(OsTimerPtr timer, CARD32 time, void* pval)
{
    SecurityAuthorizationPtr pAuth = cast(SecurityAuthorizationPtr) pval;

    assert(pAuth.timer == timer);

    if (pAuth.secondsRemaining) {
        return SecurityComputeAuthorizationTimeout(pAuth,
                                                   pAuth.secondsRemaining);
    }
    else {
        FreeResource(cast(uint)pAuth.id, X11_RESTYPE_NONE);
        return 0;
    }
}                               /* SecurityAuthorizationExpired */

/* SecurityStartAuthorizationTimer
 *
 * Arguments:
 *	pAuth is the authorization whose timer should be started.
 *
 * Returns: nothing.
 *
 * Side Effects:
 *	A timer is started, set to expire after the timeout period for
 *	this authorization.  When it expires, the function
 *	SecurityAuthorizationExpired will be called.
 */

private void SecurityStartAuthorizationTimer(SecurityAuthorizationPtr pAuth)
{
    pAuth.timer = TimerSet(pAuth.timer, 0,
                            SecurityComputeAuthorizationTimeout(pAuth,
                                                                cast(uint)pAuth.timeout),
                            &SecurityAuthorizationExpired, pAuth);
}                               /* SecurityStartAuthorizationTimer */

/* Proc functions all take a client argument, execute the request in
 * client->requestBuffer, and return a protocol error status.
 */

private int ProcSecurityQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSecurityQueryVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!"majorVersion");
    mixin(X_REQUEST_FIELD_CARD16!"minorVersion");

    xSecurityQueryVersionReply reply = {
        majorVersion: SERVER_SECURITY_MAJOR_VERSION,
        minorVersion: SERVER_SECURITY_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}                               /* ProcSecurityQueryVersion */

private int SecurityEventSelectForAuthorization(SecurityAuthorizationPtr pAuth, ClientPtr client, Mask mask)
{
    OtherClients* pEventClient = void;

    for (pEventClient = pAuth.eventClients;
         pEventClient; pEventClient = pEventClient.next) {
        if (mixin(SameClient!("pEventClient", "client"))) {
            if (mask == 0)
                FreeResource(cast(uint)pEventClient.resource, X11_RESTYPE_NONE);
            else
                pEventClient.mask = mask;
            return Success;
        }
    }

    pEventClient = cast(OtherClients*) cast(OtherClients*) calloc(1, OtherClients.sizeof);
    if (!pEventClient)
        return BadAlloc;
    pEventClient.mask = mask;
    pEventClient.resource = FakeClientID(client.index);
    pEventClient.next = pAuth.eventClients;
    if (!AddResource(cast(uint)pEventClient.resource, RTEventClient, cast(void*) pAuth)) {
        free(pEventClient);
        return BadAlloc;
    }
    pAuth.eventClients = pEventClient;

    return Success;
}                               /* SecurityEventSelectForAuthorization */

private int ProcSecurityGenerateAuthorization(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSecurityGenerateAuthorizationReq);
    mixin(X_REQUEST_FIELD_CARD16!"nbytesAuthProto");
    mixin(X_REQUEST_FIELD_CARD16!"nbytesAuthData");
    mixin(X_REQUEST_FIELD_CARD32!"valueMask");

    int len = void;                    /* request length in CARD32s */
    Bool removeAuth = FALSE;    /* if bailout, call RemoveAuthorization? */
    int err = void;                    /* error to return from this function */
    XID authId = void;                 /* authorization ID assigned by os layer */
    uint trustLevel = void;    /* trust level of new auth */
    XID group = void;                  /* group of new auth */
    CARD32 timeout = void;             /* timeout of new auth */
    CARD32* values = void;             /* list of supplied attributes */
    char* protoname = void;            /* auth proto name sent in request */
    char* protodata = void;            /* auth proto data sent in request */
    uint authdata_len = void;  /* # bytes of generated auth data */
    char* pAuthdata = void;            /* generated auth data */
    Mask eventMask = void;             /* what events on this auth does client want */

    /* check request length */

    len = cast(int)(int32ForBytes(xSecurityGenerateAuthorizationReq.sizeof));
    len += int32ForBytes(stuff.nbytesAuthProto);
    len += int32ForBytes(stuff.nbytesAuthData);
    values = (cast(CARD32*) stuff) + len;
    len += Ones(stuff.valueMask);
    if (client.req_len != len)
        return BadLength;

    if (client.swapped) {
        c_ulong nvalues = ((cast(CARD32*) stuff) + client.req_len) - values;
        SwapLongs(values, nvalues);
    }

    /* check valuemask */
    if (stuff.valueMask & ~XSecurityAllAuthorizationAttributes) {
        client.errorValue = cast(uint)stuff.valueMask;
        return BadValue;
    }

    /* check timeout */
    timeout = 60;
    if (stuff.valueMask & XSecurityTimeout) {
        timeout = *values++;
    }

    /* check trustLevel */
    trustLevel = XSecurityClientUntrusted;
    if (stuff.valueMask & XSecurityTrustLevel) {
        trustLevel = cast(uint)*values++;
        if (trustLevel != XSecurityClientTrusted &&
            trustLevel != XSecurityClientUntrusted) {
            client.errorValue = cast(uint)trustLevel;
            return BadValue;
        }
    }

    /* check group */
    group = None;
    if (stuff.valueMask & XSecurityGroup) {
        group = *values++;
        if (SecurityValidateGroupCallback) {
            SecurityValidateGroupInfoRec vgi = void;

            vgi.group = group;
            vgi.valid = FALSE;
            CallCallbacks(&SecurityValidateGroupCallback, cast(void*) &vgi);

            /* if nobody said they recognized it, it's an error */

            if (!vgi.valid) {
                client.errorValue = cast(uint)group;
                return BadValue;
            }
        }
    }

    /* check event mask */
    eventMask = 0;
    if (stuff.valueMask & XSecurityEventMask) {
        eventMask = *values++;
        if (eventMask & ~(XSecurityAllEventMasks)) {
            client.errorValue = cast(uint)eventMask;
            return BadValue;
        }
    }

    protoname = cast(char*) &stuff[1];
    protodata = protoname + int32ForBytes(stuff.nbytesAuthProto);

    /* call os layer to generate the authorization */

    authId = GenerateAuthorization(stuff.nbytesAuthProto, protoname,
                                   stuff.nbytesAuthData, protodata,
                                   &authdata_len, &pAuthdata);
    if (!authId) {
        return SecurityErrorBase + XSecurityBadAuthorizationProtocol;
    }

    /* now that we've added the auth, remember to remove it if we have to
     * abort the request for some reason (like allocation failure)
     */
    removeAuth = TRUE;

    /* associate additional information with this auth ID */

    SecurityAuthorizationPtr pAuth = cast(SecurityAuthorizationPtr)cast(SecurityAuthorizationRec*) calloc(1, SecurityAuthorizationRec.sizeof);
    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    xSecurityGenerateAuthorizationReply reply = {
        authId: cast(uint)authId,
        dataLength: cast(ushort)authdata_len
    };
    if (!pAuth) {
        err = BadAlloc;
        goto bailout;
    }

    /* fill in the auth fields */

    pAuth.id = authId;
    pAuth.timeout = timeout;
    pAuth.group = group;
    pAuth.trustLevel = trustLevel;
    pAuth.refcnt = 0;          /* the auth was just created; nobody's using it yet */
    pAuth.secondsRemaining = 0;
    pAuth.timer = null;
    pAuth.eventClients = null;

    /* handle event selection */
    if (eventMask) {
        err = SecurityEventSelectForAuthorization(pAuth, client, eventMask);
        if (err != Success)
            goto bailout;
    }

    if (!AddResource(cast(uint)authId, SecurityAuthorizationResType, pAuth)) {
        err = BadAlloc;
        goto bailout;
    }

    /* start the timer ticking */

    if (pAuth.timeout != 0)
        SecurityStartAuthorizationTimer(pAuth);

    /* tell client the auth id and data */

    x_rpcbuf_write_binary_pad(&rpcbuf, pAuthdata, authdata_len);


    SecurityAudit
        ("client %d generated authorization %lu trust %d timeout %lu group %lu events %lu\n",
         client.index, cast(c_ulong)pAuth.id, pAuth.trustLevel, cast(c_ulong)pAuth.timeout,
         cast(c_ulong)pAuth.group, cast(c_ulong)eventMask);

    mixin(X_REPLY_FIELD_CARD32!"authId");
    mixin(X_REPLY_FIELD_CARD16!"dataLength");

    /* the request succeeded; don't call RemoveAuthorization or free pAuth */
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

 bailout:
    if (removeAuth)
        RemoveAuthorization(stuff.nbytesAuthProto, protoname,
                            cast(ushort)authdata_len, pAuthdata);
    free(pAuth);
    return err;

}                               /* ProcSecurityGenerateAuthorization */

private int ProcSecurityRevokeAuthorization(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSecurityRevokeAuthorizationReq);
    mixin(X_REQUEST_FIELD_CARD32!"authId");

    SecurityAuthorizationPtr pAuth = void;

    int rc = dixLookupResourceByType(cast(void**) &pAuth, stuff.authId,
                                 SecurityAuthorizationResType, client,
                                 DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.authId, X11_RESTYPE_NONE);
    return Success;
}                               /* ProcSecurityRevokeAuthorization */

private int ProcSecurityDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_SecurityQueryVersion:
        return ProcSecurityQueryVersion(client);
    case X_SecurityGenerateAuthorization:
        return ProcSecurityGenerateAuthorization(client);
    case X_SecurityRevokeAuthorization:
        return ProcSecurityRevokeAuthorization(client);
    default:
        return BadRequest;
    }
}                               /* ProcSecurityDispatch */

private void SwapSecurityAuthorizationRevokedEvent(xSecurityAuthorizationRevokedEvent* from, xSecurityAuthorizationRevokedEvent* to)
{
    to.type = from.type;
    to.detail = from.detail;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.authId, to.authId);
}

/* SecurityCheckDeviceAccess
 *
 * Arguments:
 *	client is the client attempting to access a device.
 *	dev is the device being accessed.
 *	fromRequest is TRUE if the device access is a direct result of
 *	  the client executing some request and FALSE if it is a
 *	  result of the server trying to send an event (e.g. KeymapNotify)
 *	  to the client.
 * Returns:
 *	TRUE if the device access should be allowed, else FALSE.
 *
 * Side Effects:
 *	An audit message is generated if access is denied.
 */

private void SecurityDevice(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    DeviceAccessCallbackParam* rec = cast(DeviceAccessCallbackParam*)calldata;
    SecurityStateRec* subj = void, obj = void;
    Mask requested = rec.access_mode;
    Mask allowed = SecurityDeviceMask;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
    obj = cast(SecurityStateRec*)dixLookupPrivate(&serverClient.devPrivates, stateKey);

    if (rec.dev != inputInfo.keyboard)
        /* this extension only supports the core keyboard */
        allowed = requested;

    if (SecurityDoCheck(subj, obj, requested, allowed) != Success) {
        SecurityAudit("Security denied client %d keyboard access on request "
                      ~ "%s\n", rec.client.index,
                      SecurityLookupRequestName(rec.client));
        rec.status = BadAccess;
    }
}

/* SecurityResource
 *
 * This function gets plugged into client->CheckAccess and is called from
 * SecurityLookupIDByType/Class to determine if the client can access the
 * resource.
 *
 * Arguments:
 *	client is the client doing the resource access.
 *	id is the resource id.
 *	rtype is its type or class.
 *	access_mode represents the intended use of the resource; see
 *	  resource.h.
 *	res is a pointer to the resource structure for this resource.
 *
 * Returns:
 *	If access is granted, the value of rval that was passed in, else FALSE.
 *
 * Side Effects:
 *	Disallowed resource accesses are audited.
 */

private void SecurityResource(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceResourceAccessRec* rec = cast(XaceResourceAccessRec*)calldata;
    SecurityStateRec* subj = void, obj = void;
    Mask requested = rec.access_mode;
    Mask allowed = SecurityResourceMask;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);

    /* disable background None for untrusted windows */
    if ((requested & DixCreateAccess) && (rec.rtype == X11_RESTYPE_WINDOW))
        if (subj.haveState && subj.trustLevel != XSecurityClientTrusted)
            (cast(WindowPtr) rec.res).forcedBG = TRUE;

    /* additional permissions for specific resource types */
    if (rec.rtype == X11_RESTYPE_WINDOW)
        allowed |= SecurityWindowExtraMask;

    ClientPtr owner = dixClientForXID(rec.id);
    if (!owner)
        goto denied;

    /* special checks for server-owned resources */
    if (dixResouceIsServerOwned(rec.id)) {
        if (rec.rtype & RC_DRAWABLE)
            /* additional operations allowed on root windows */
            allowed |= SecurityRootWindowExtraMask;

        else if (rec.rtype == X11_RESTYPE_COLORMAP)
            /* allow access to default colormaps */
            allowed = requested;

        else
            /* allow read access to other server-owned resources */
            allowed |= DixReadAccess;
    }

    obj = cast(SecurityStateRec* )dixLookupPrivate(&owner.devPrivates, stateKey);
    if (SecurityDoCheck(subj, obj, requested, allowed) == Success)
        return;

denied:
    SecurityAudit("Security: denied client %d access %lx to resource 0x%lx "
                  ~ "of client %d on request %s\n", rec.client.index,
                  cast(c_ulong)requested, cast(c_ulong)rec.id,
                  dixClientIdForXID(rec.id),
                  SecurityLookupRequestName(rec.client));
    rec.status = BadAccess;    /* deny access */
}

private void SecurityExtension(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ExtensionAccessCallbackParam* rec = cast(ExtensionAccessCallbackParam*)calldata;
    SecurityStateRec* subj = void;
    int i = 0;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);

    if (subj.haveState && subj.trustLevel == XSecurityClientTrusted)
        return;

    while (SecurityTrustedExtensions[i])
        if (!strcmp(SecurityTrustedExtensions[i++], rec.ext.name))
            return;

    SecurityAudit("Security: denied client %d access to extension "
                  ~ "%s on request %s\n",
                  rec.client.index, rec.ext.name,
                  SecurityLookupRequestName(rec.client));
    rec.status = BadAccess;
}

private void SecurityServer(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ServerAccessCallbackParam* rec = cast(ServerAccessCallbackParam*)calldata;
    SecurityStateRec* subj = void, obj = void;
    Mask requested = rec.access_mode;
    Mask allowed = SecurityServerMask;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
    obj = cast(SecurityStateRec*)dixLookupPrivate(&serverClient.devPrivates, stateKey);

    if (SecurityDoCheck(subj, obj, requested, allowed) != Success) {
        SecurityAudit("Security: denied client %d access to server "
                      ~ "configuration request %s\n", rec.client.index,
                      SecurityLookupRequestName(rec.client));
        rec.status = BadAccess;
    }
}

private void SecurityClient(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ClientAccessCallbackParam* rec = cast(ClientAccessCallbackParam*)calldata;
    SecurityStateRec* subj = void, obj = void;
    Mask requested = rec.access_mode;
    Mask allowed = SecurityClientMask;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
    obj = cast(SecurityStateRec*)dixLookupPrivate(&rec.target.devPrivates, stateKey);

    if (SecurityDoCheck(subj, obj, requested, allowed) != Success) {
        SecurityAudit("Security: denied client %d access to client %d on "
                      ~ "request %s\n", rec.client.index, rec.target.index,
                      SecurityLookupRequestName(rec.client));
        rec.status = BadAccess;
    }
}

private void SecurityProperty(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XacePropertyAccessRec* rec = cast(XacePropertyAccessRec*)calldata;
    SecurityStateRec* subj = void, obj = void;
    Atom name = (*rec.ppProp).propertyName;
    Mask requested = rec.access_mode;
    Mask allowed = SecurityResourceMask | DixReadAccess;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
    obj = cast(SecurityStateRec*)dixLookupPrivate(&dixClientForWindow(rec.pWin).devPrivates, stateKey);

    if (SecurityDoCheck(subj, obj, requested, allowed) != Success) {
        SecurityAudit("Security: denied client %d access to property %s "
                      ~ "(atom 0x%x) window 0x%lx of client %d on request %s\n",
                      rec.client.index, NameForAtom(name), name,
                      cast(c_ulong)rec.pWin.drawable.id, dixClientForWindow(rec.pWin).index,
                      SecurityLookupRequestName(rec.client));
        rec.status = BadAccess;
    }
}

private void SecuritySend(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceSendAccessRec* rec = cast(XaceSendAccessRec*)calldata;
    SecurityStateRec* subj = void, obj = void;

    if (rec.client) {
        int i = void;

        subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
        obj = cast(SecurityStateRec*)dixLookupPrivate(&dixClientForWindow(rec.pWin).devPrivates, stateKey);

        if (SecurityDoCheck(subj, obj, DixSendAccess, 0) == Success)
            return;

        for (i = 0; i < rec.count; i++)
            if (rec.events[i].u.u.type != UnmapNotify &&
                rec.events[i].u.u.type != ConfigureRequest &&
                rec.events[i].u.u.type != ClientMessage) {

                SecurityAudit("Security: denied client %d from sending event "
                              ~ "of type %s to window 0x%lx of client %d\n",
                              rec.client.index,
                              LookupEventName(rec.events[i].u.u.type),
                              cast(c_ulong)rec.pWin.drawable.id,
                              dixClientForWindow(rec.pWin).index);
                rec.status = BadAccess;
                return;
            }
    }
}

private void SecurityReceive(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceReceiveAccessRec* rec = cast(XaceReceiveAccessRec*)calldata;
    SecurityStateRec* subj = void, obj = void;

    subj = cast(SecurityStateRec*)dixLookupPrivate(&rec.client.devPrivates, stateKey);
    obj = cast(SecurityStateRec*)dixLookupPrivate(&dixClientForWindow(rec.pWin).devPrivates, stateKey);

    if (SecurityDoCheck(subj, obj, DixReceiveAccess, 0) == Success)
        return;

    SecurityAudit("Security: denied client %d from receiving an event "
                  ~ "sent to window 0x%lx of client %d\n",
                  rec.client.index, cast(c_ulong)rec.pWin.drawable.id,
                  dixClientForWindow(rec.pWin).index);
    rec.status = BadAccess;
}

/* SecurityClientStateCallback
 *
 * Arguments:
 *	pcbl is &ClientStateCallback.
 *	nullata is NULL.
 *	calldata is a pointer to a NewClientInfoRec (include/dixstruct.h)
 *	which contains information about client state changes.
 *
 * Returns: nothing.
 *
 * Side Effects:
 *
 * If a new client is connecting, its authorization ID is copied to
 * client->authID.  If this is a generated authorization, its reference
 * count is bumped, its timer is cancelled if it was running, and its
 * trustlevel is copied to TRUSTLEVEL(client).
 *
 * If a client is disconnecting and the client was using a generated
 * authorization, the authorization's reference count is decremented, and
 * if it is now zero, the timer for this authorization is started.
 */

private void SecurityClientState(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    NewClientInfoRec* pci = cast(NewClientInfoRec*)calldata;
    SecurityStateRec* state = void;
    SecurityAuthorizationPtr pAuth = void;

    state = cast(SecurityStateRec*)dixLookupPrivate(&pci.client.devPrivates, stateKey);

    switch (pci.client.clientState) {
    case ClientStateInitial:
        state.trustLevel = XSecurityClientTrusted;
        state.authId = None;
        state.haveState = TRUE;
        state.live = FALSE;
        break;

    case ClientStateRunning:
    {
        state.authId = AuthorizationIDOfClient(pci.client);
        int rc = dixLookupResourceByType(cast(void**) &pAuth, state.authId,
                                     SecurityAuthorizationResType, serverClient,
                                     DixGetAttrAccess);
        if (rc == Success) {
            /* it is a generated authorization */
            pAuth.refcnt++;
            state.live = TRUE;
            if (pAuth.refcnt == 1 && pAuth.timer)
                TimerCancel(pAuth.timer);

            state.trustLevel = pAuth.trustLevel;
        }
        break;
    }
    case ClientStateGone:
    case ClientStateRetained:
    {
        int rc = dixLookupResourceByType(cast(void**) &pAuth, state.authId,
                                     SecurityAuthorizationResType, serverClient,
                                     DixGetAttrAccess);
        if (rc == Success && state.live) {
            /* it is a generated authorization */
            pAuth.refcnt--;
            state.live = FALSE;
            if (pAuth.refcnt == 0)
                SecurityStartAuthorizationTimer(pAuth);
        }
        break;
    }
    default:
        break;
    }
}

/* SecurityResetProc
 *
 * Arguments:
 *	extEntry is the extension information for the security extension.
 *
 * Returns: nothing.
 *
 * Side Effects:
 *	Performs any cleanup needed by Security at server shutdown time.
 */

private void SecurityResetProc(_ExtensionEntry* extEntry)
{
    /* Unregister callbacks */
    DeleteCallback(&ClientStateCallback, &SecurityClientState, null);
    DeleteCallback(&ExtensionAccessCallback, &SecurityExtension, null);
    DeleteCallback(&ExtensionDispatchCallback, &SecurityExtension, null);
    DeleteCallback(&ServerAccessCallback, &SecurityServer, null);
    DeleteCallback(&ClientAccessCallback, &SecurityClient, null);
    DeleteCallback(&DeviceAccessCallback, &SecurityDevice, null);

    XaceDeleteCallback(XACE_RESOURCE_ACCESS, &SecurityResource, null);
    XaceDeleteCallback(XACE_PROPERTY_ACCESS, &SecurityProperty, null);
    XaceDeleteCallback(XACE_SEND_ACCESS, &SecuritySend, null);
    XaceDeleteCallback(XACE_RECEIVE_ACCESS, &SecurityReceive, null);
}

/* SecurityExtensionInit
 *
 * Arguments: none.
 *
 * Returns: nothing.
 *
 * Side Effects:
 *	Enables the Security extension if possible.
 */

void SecurityExtensionInit()
{
    _ExtensionEntry* extEntry = void;
    int ret = TRUE;

    SecurityAuthorizationResType =
        CreateNewResourceType(&SecurityDeleteAuthorization,
                              "SecurityAuthorization");

    RTEventClient =
        CreateNewResourceType(&SecurityDeleteAuthorizationEventClient,
                              "SecurityEventClient");

    if (!SecurityAuthorizationResType || !RTEventClient)
        return;

    RTEventClient |= RC_NEVERRETAIN;

    /* Allocate the private storage */
    if (!dixRegisterPrivateKey
        (stateKey, PRIVATE_CLIENT, SecurityStateRec.sizeof))
        FatalError("SecurityExtensionSetup: Can't allocate client private.\n");

    /* Register callbacks */
    ret &= AddCallback(&ClientStateCallback, &SecurityClientState, null);
    ret &= AddCallback(&ExtensionAccessCallback, &SecurityExtension, null);
    ret &= AddCallback(&ExtensionDispatchCallback, &SecurityExtension, null);
    ret &= AddCallback(&ServerAccessCallback, &SecurityServer, null);
    ret &= AddCallback(&ClientAccessCallback, &SecurityClient, null);
    ret &= AddCallback(&DeviceAccessCallback, &SecurityDevice, null);

    ret &= XaceRegisterCallback(XACE_RESOURCE_ACCESS, &SecurityResource, null);
    ret &= XaceRegisterCallback(XACE_PROPERTY_ACCESS, &SecurityProperty, null);
    ret &= XaceRegisterCallback(XACE_SEND_ACCESS, &SecuritySend, null);
    ret &= XaceRegisterCallback(XACE_RECEIVE_ACCESS, &SecurityReceive, null);

    if (!ret)
        FatalError("SecurityExtensionSetup: Failed to register callbacks\n");

    /* Add extension to server */
    extEntry = AddExtension(SECURITY_EXTENSION_NAME,
                            XSecurityNumberEvents, XSecurityNumberErrors,
                            &ProcSecurityDispatch, &ProcSecurityDispatch,
                            &SecurityResetProc, &StandardMinorOpcode);

    SecurityErrorBase = extEntry.errorBase;
    SecurityEventBase = extEntry.eventBase;

    EventSwapVector[SecurityEventBase + XSecurityAuthorizationRevoked] =
        cast(EventSwapPtr) &SwapSecurityAuthorizationRevokedEvent;

    SetResourceTypeErrorValue(SecurityAuthorizationResType,
                              SecurityErrorBase + XSecurityBadAuthorization);

    /* Label objects that were created before we could register ourself */
    SecurityLabelInitial();
}
