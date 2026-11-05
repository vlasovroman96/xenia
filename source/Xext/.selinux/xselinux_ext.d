module Xext.xselinux_ext;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Author: Eamon Walsh <ewalsh@tycho.nsa.gov>

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
this permission notice appear in supporting documentation.  This permission
notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

********************************************************/

import build.dix_config;

import dix.dix_priv;
import dix.property_priv;
import dix.request_priv;
import dix.selection_priv;
import miext.extinit_priv;

import dix.inputstr;import include.windowstr;
import dix.property;
import Xext.xselinuxint;
import Xext.xselinux;
import externs.attrs;
import dix.dixutils;
import os.log;
import dix.extension;
import dix.devices;


enum SELINUX_MODE_DISABLED = false;

alias calloc = core.stdc.stdlib.calloc;
alias free = core.stdc.stdlib.free;
alias CheckContextFn = extern(C) int function(const(char)*) @nogc nothrow;
alias FreeConnFn = extern(C) void function(const(char)*) @nogc nothrow;
alias GetBooleanActiveFn = extern(C) bool function(const(char)*) @nogc nothrow;
alias IsSeLinuxEnabledFn = extern(C) bool function() @nogc nothrow;

enum CTX_DEV = SELinuxSubjectRec.dev_create_sid.offsetof;
enum CTX_WIN = SELinuxSubjectRec.win_create_sid.offsetof;
enum CTX_PRP = SELinuxSubjectRec.prp_create_sid.offsetof;
enum CTX_SEL = SELinuxSubjectRec.sel_create_sid.offsetof;
enum USE_PRP = SELinuxSubjectRec.prp_use_sid.offsetof;
enum USE_SEL = SELinuxSubjectRec.sel_use_sid.offsetof;

struct SELinuxListItemRec {
    char* octx;
    char* dctx;
    CARD32 octx_len;
    CARD32 dctx_len;
    CARD32 id;
}

Bool noSELinuxExtension = FALSE;
int selinuxEnforcingState = SELINUX_MODE_DEFAULT;

/*
 * Extension Dispatch
 */

private char* SELinuxCopyContext(char* ptr, uint len)
{
    char* copy = cast(char*) calloc(1, len + 1);
    if (!copy) {
        return null;
    }
    strncpy(copy, ptr, len);
    copy[len] = '\0';
    return copy;
}

private int ProcSELinuxQueryVersion(ClientPtr client)
{
    SELinuxQueryVersionReply reply = {
        server_major: SELINUX_MAJOR_VERSION,
        server_minor: SELINUX_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!"server_major");
    mixin(X_REPLY_FIELD_CARD16!"server_minor");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int SELinuxSendContextReply(ClientPtr client, security_id_t sid)
{
    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    // auto dd = &assumeNoGC(&avc_sid_to_context_raw);

    import externs.attrs;
    int len = 0;
    if (sid) {
        char* ctx = void;
        if (assumeNoGC(&avc_sid_to_context_raw)(sid, &ctx) < 0) {
            return BadValue;
        }
        len = cast(uint)(strlen(ctx) + 1);
        x_rpcbuf_write_string_0t_pad(&rpcbuf, ctx);
        assumeNoGC(&externs.selinux.avc.free)(ctx);
    }

    SELinuxGetContextReply reply = {
        context_len: len
    };

    mixin(X_REPLY_FIELD_CARD32!"context_len");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcSELinuxSetCreateContext(ClientPtr client, uint offset)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!SELinuxSetCreateContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"context_len");
    mixin(REQUEST_FIXED_SIZE!(SELinuxSetCreateContextReq, "stuff.context_len"));

    PrivateRec** privPtr = &client.devPrivates;
    security_id_t* pSid = void;
    char* ctx = null;
    char* ptr = void;

    if (stuff.context_len > 0) {
        ctx = SELinuxCopyContext(cast(char*) (stuff + 1), cast(uint)stuff.context_len);
        if (!ctx) {
            return BadAlloc;
        }
    }

    ptr = cast(char*)dixLookupPrivate(privPtr, subjectKey);
    pSid = cast(security_id_t*) (ptr + offset);
    *pSid = null;

    int rc = Success;
    if (stuff.context_len > 0) {
       
        if (assumeNoGC(cast(CheckContextFn)&security_check_context_raw)(ctx) < 0 ||
            avc_context_to_sid_raw_d(ctx, pSid) < 0)
        {
            rc = BadValue;
        }
    }

    free(ctx);
    return rc;
}

private int ProcSELinuxGetCreateContext(ClientPtr client, uint offset)
{
    security_id_t* pSid = void;
    char* ptr = void;

    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetCreateContextReq);

    if (offset == CTX_DEV) {
        ptr = cast(char*)dixLookupPrivate(&serverClient.devPrivates, subjectKey);
    } else {
        ptr = cast(char*)dixLookupPrivate(&client.devPrivates, subjectKey);
    }

    pSid = cast(security_id_t*) (ptr + offset);
    return SELinuxSendContextReply(client, *pSid);
}

private int ProcSELinuxSetDeviceContext(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!SELinuxSetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD32!"context_len");

    mixin(REQUEST_FIXED_SIZE!(SELinuxSetContextReq, "stuff.context_len"));

    char* ctx = void;
    security_id_t sid = void;
    DeviceIntPtr dev = void;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;

    if (stuff.context_len < 1) {
        return BadLength;
    }

    ctx = SELinuxCopyContext(cast(char*) (stuff + 1), cast(uint)stuff.context_len);
    if (!ctx) {
        return BadAlloc;
    }

    int rc = dixLookupDevice(&dev, cast(int)stuff.id, client, DixManageAccess);
    if (rc != Success) {
        goto out_;
    }

    if (assumeNoGC(cast(CheckContextFn)&security_check_context_raw)(ctx) < 0 ||
        avc_context_to_sid_raw_d(ctx, &sid) < 0) {
        rc = BadValue;
        goto out_;
    }

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&dev.devPrivates, subjectKey);
    subj.sid = sid;
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&dev.devPrivates, objectKey);
    obj.sid = sid;

    rc = Success;
 out_:
    free(ctx);
    return rc;
}

private int ProcSELinuxGetDeviceContext(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    DeviceIntPtr dev = void;
    SELinuxSubjectRec* subj = void;

    int rc = dixLookupDevice(&dev, cast(int)stuff.id, client, DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&dev.devPrivates, subjectKey);
    return SELinuxSendContextReply(client, subj.sid);
}

private int ProcSELinuxGetDrawableContext(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    DrawablePtr pDraw = void;
    PrivateRec** privatePtr = void;
    SELinuxObjectRec* obj = void;

    int rc = dixLookupDrawable(&pDraw, stuff.id, client, 0, DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    if (pDraw.type == DRAWABLE_PIXMAP) {
        privatePtr = &(cast(PixmapPtr) pDraw).devPrivates;
    } else {
        privatePtr = &(cast(WindowPtr) pDraw).devPrivates;
    }

    obj = cast(SELinuxObjectRec*)dixLookupPrivate(privatePtr, objectKey);
    return SELinuxSendContextReply(client, obj.sid);
}

private int ProcSELinuxGetPropertyContext(ClientPtr client, void* privKey)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetPropertyContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"property");

    WindowPtr pWin = void;
    PropertyPtr pProp = void;
    SELinuxObjectRec* obj = void;

    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetPropAccess);
    if (rc != Success) {
        return rc;
    }

    rc = dixLookupProperty(&pProp, pWin, stuff.property, client,
                           DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pProp.devPrivates, cast(_DevPrivateKeyRec*)privKey);
    return SELinuxSendContextReply(client, obj.sid);
}

private int ProcSELinuxGetSelectionContext(ClientPtr client, void* privKey)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    Selection* pSel = void;
    SELinuxObjectRec* obj = void;

    int rc = dixLookupSelection(&pSel, stuff.id, client, DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pSel.devPrivates, cast(_DevPrivateKeyRec*)privKey);
    return SELinuxSendContextReply(client, obj.sid);
}

private int ProcSELinuxGetClientContext(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    ClientPtr target = void;
    SELinuxSubjectRec* subj = void;

    int rc = dixLookupResourceOwner(&target, stuff.id, client, DixGetAttrAccess);
    if (rc != Success) {
        return rc;
    }

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&target.devPrivates, subjectKey);
    return SELinuxSendContextReply(client, subj.sid);
}

private int SELinuxPopulateItem(SELinuxListItemRec* i, PrivateRec** privPtr, CARD32 id, int* size)
{
    SELinuxObjectRec* obj = cast(SELinuxObjectRec*)dixLookupPrivate(privPtr, objectKey);
    SELinuxObjectRec* data = cast(SELinuxObjectRec*)dixLookupPrivate(privPtr, dataKey);

    if (!i) {
        return BadValue;
    }
    if (assumeNoGC(&avc_sid_to_context_raw)(obj.sid, &i.octx) < 0) {
        return BadValue;
    }
    if (assumeNoGC(&avc_sid_to_context_raw)(data.sid, &i.dctx) < 0) {
        return BadValue;
    }

    i.id = id;
    i.octx_len = bytes_to_int32(strlen(i.octx) + 1);
    i.dctx_len = bytes_to_int32(strlen(i.dctx) + 1);

    *size += i.octx_len + i.dctx_len + 3;
    return Success;
}

private void SELinuxFreeItems(SELinuxListItemRec* items, int count)
{
    int k = void;

    if (!items) {
        return;
    }
        
    for (k = 0; k < count; k++) {
        assumeNoGC(cast(FreeConnFn)&freecon_d)(items[k].octx);
        assumeNoGC(cast(FreeConnFn)&freecon_d)(items[k].dctx);
    }
    free(items);
}

private int SELinuxSendItemsToClient(ClientPtr client, SELinuxListItemRec* items, int size, int count)
{
    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    /* Fill in the buffer */
    for (int k = 0; k < count; k++) {
        x_rpcbuf_write_CARD32(&rpcbuf, items[k].id);
        x_rpcbuf_write_CARD32(&rpcbuf, items[k].octx_len * 4);
        x_rpcbuf_write_CARD32(&rpcbuf, items[k].dctx_len * 4);
        x_rpcbuf_write_string_0t_pad(&rpcbuf, items[k].octx);
        x_rpcbuf_write_string_0t_pad(&rpcbuf, items[k].dctx);
    }

    /* Send reply to client */
    SELinuxListItemsReply reply = {
        count: count
    };

    mixin(X_REPLY_FIELD_CARD32!"count");

    SELinuxFreeItems(items, count);
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcSELinuxListProperties(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    WindowPtr pWin = void;
    PropertyPtr pProp = void;
    SELinuxListItemRec* items = void;
    int count = void, size = void, i = void;
    CARD32 id = void;

    int rc = dixLookupWindow(&pWin, stuff.id, client, DixListPropAccess);
    if (rc != Success) {
        return rc;
    }

    /* Count the number of properties and allocate items */
    count = 0;
    for (pProp = pWin.properties; pProp; pProp = pProp.next) {
        count++;
    }
    items = cast(SELinuxListItemRec*) calloc(count, SELinuxListItemRec.sizeof);
    if (count && !items) {
        return BadAlloc;
    }

    /* Fill in the items and calculate size */
    i = 0;
    size = 0;
    for (pProp = pWin.properties; pProp; pProp = pProp.next) {
        id = pProp.propertyName;
        rc = SELinuxPopulateItem(items + i, &pProp.devPrivates, id, &size);
        if (rc != Success) {
            SELinuxFreeItems(items, count);
            return rc;
        }
        i++;
    }

    return SELinuxSendItemsToClient(client, items, size, count);
}

private int ProcSELinuxListSelections(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!SELinuxGetCreateContextReq);

    Selection* pSel = void;
    SELinuxListItemRec* items = void;
    int count = void, size = void, i = void;
    CARD32 id = void;

    /* Count the number of selections and allocate items */
    count = 0;
    for (pSel = CurrentSelections; pSel; pSel = pSel.next) {
        count++;
    }
    if (count == 0) {
        return SELinuxSendItemsToClient(client, null, 0, 0);
    }
    items = cast(SELinuxListItemRec*) calloc(count, SELinuxListItemRec.sizeof);
    if (!items) {
        return BadAlloc;
    }

    /* Fill in the items and calculate size */
    i = 0;
    size = 0;
    for (pSel = CurrentSelections; pSel; pSel = pSel.next) {
        id = cast(uint)pSel.selection;
        int rc = SELinuxPopulateItem(items + i, &pSel.devPrivates, id, &size);
        if (rc != Success) {
            SELinuxFreeItems(items, count);
            return rc;
        }
        i++;
    }

    return SELinuxSendItemsToClient(client, items, size, count);
}

private int ProcSELinuxDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_SELinuxQueryVersion:
        return ProcSELinuxQueryVersion(client);
    case X_SELinuxSetDeviceCreateContext:
        return ProcSELinuxSetCreateContext(client, CTX_DEV);
    case X_SELinuxGetDeviceCreateContext:
        return ProcSELinuxGetCreateContext(client, CTX_DEV);
    case X_SELinuxSetDeviceContext:
        return ProcSELinuxSetDeviceContext(client);
    case X_SELinuxGetDeviceContext:
        return ProcSELinuxGetDeviceContext(client);
    case X_SELinuxSetDrawableCreateContext:
        return ProcSELinuxSetCreateContext(client, CTX_WIN);
    case X_SELinuxGetDrawableCreateContext:
        return ProcSELinuxGetCreateContext(client, CTX_WIN);
    case X_SELinuxGetDrawableContext:
        return ProcSELinuxGetDrawableContext(client);
    case X_SELinuxSetPropertyCreateContext:
        return ProcSELinuxSetCreateContext(client, CTX_PRP);
    case X_SELinuxGetPropertyCreateContext:
        return ProcSELinuxGetCreateContext(client, CTX_PRP);
    case X_SELinuxSetPropertyUseContext:
        return ProcSELinuxSetCreateContext(client, USE_PRP);
    case X_SELinuxGetPropertyUseContext:
        return ProcSELinuxGetCreateContext(client, USE_PRP);
    case X_SELinuxGetPropertyContext:
        return ProcSELinuxGetPropertyContext(client, objectKey);
    case X_SELinuxGetPropertyDataContext:
        return ProcSELinuxGetPropertyContext(client, dataKey);
    case X_SELinuxListProperties:
        return ProcSELinuxListProperties(client);
    case X_SELinuxSetSelectionCreateContext:
        return ProcSELinuxSetCreateContext(client, CTX_SEL);
    case X_SELinuxGetSelectionCreateContext:
        return ProcSELinuxGetCreateContext(client, CTX_SEL);
    case X_SELinuxSetSelectionUseContext:
        return ProcSELinuxSetCreateContext(client, USE_SEL);
    case X_SELinuxGetSelectionUseContext:
        return ProcSELinuxGetCreateContext(client, USE_SEL);
    case X_SELinuxGetSelectionContext:
        return ProcSELinuxGetSelectionContext(client, objectKey);
    case X_SELinuxGetSelectionDataContext:
        return ProcSELinuxGetSelectionContext(client, dataKey);
    case X_SELinuxListSelections:
        return ProcSELinuxListSelections(client);
    case X_SELinuxGetClientContext:
        return ProcSELinuxGetClientContext(client);
    default:
        return BadRequest;
    }
}

/*
 * Extension Setup / Teardown
 */

private void SELinuxResetProc(ExtensionEntry* extEntry)
{
    SELinuxFlaskReset();
    SELinuxLabelReset();
}

void SELinuxExtensionInit()
{
    /* Check SELinux mode on system, configuration file, and boolean */
    if (!assumeNoGC(cast(IsSeLinuxEnabledFn)(&is_selinux_enabled))()) {
        LogMessage(X_INFO, "SELinux: Disabled on system\n");
        return;
    }
    if (selinuxEnforcingState == SELINUX_MODE_DISABLED) {
        LogMessage(X_INFO, "SELinux: Disabled in configuration file\n");
        return;
    }
    if (!assumeNoGC(cast(GetBooleanActiveFn)&security_get_boolean_active)("xserver_object_manager")) {
        LogMessage(X_INFO, "SELinux: Disabled by boolean\n");
        return;
    }

    /* Set up XACE hooks */
    SELinuxLabelInit();
    SELinuxFlaskInit();

    /* Add extension to server */
    AddExtension(SELINUX_EXTENSION_NAME, SELinuxNumberEvents,
                 SELinuxNumberErrors, &ProcSELinuxDispatch,
                 &ProcSELinuxDispatch, &SELinuxResetProc, &StandardMinorOpcode);
}
