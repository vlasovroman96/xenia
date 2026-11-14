module Xext.xselinux_hooks;
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

/*
 * Portions of this code copyright (c) 2005 by Trusted Computer Solutions, Inc.
 * All rights reserved.
 */

import build.dix_config;

import core.stdc.errno;
import core.sys.posix.sys.socket;
import core.stdc.stdio;
import core.stdc.stdarg;
import stdctypes = core.sys.posix.sys.types;
// import libaudit;
//import externs.X11.Xatom;
// //import x11.Xfuncproto;

import dix.client_priv;
import dix.devices_priv;
import dix.dix_priv;
import dix.extension_priv;
import dix.input_priv;
import dix.registry_priv;
import dix.resource_priv;
import dix.screenint_priv;
import dix.screensaver_priv;
import dix.selection_priv;
import dix.server_priv;
import os.client_priv;

import registry;
import dix.inputstr;
import dix.scrnintstr;
import dix.window;
import Xext.xacestr;
version = _XSELINUX_NEED_FLASK_MAP;
import Xext.xselinuxint;
import externs.attrs;
import os.log;
import os.access;
import externs.selinux.selinux_;
import externs.libaudit;
import externs.X11.Xatom;
import dix.property;
import dix.dixutils;
import dix.extension;
import os.os;
import Xext.xselinux_ext;
import Xext.xselinux;
import os.connection;
import dix.events;
public import Xext.xselinuxint;

import stdc = core.stdc.errno;

import stdarg = core.stdc.stdarg;

/* structure passed to auditing callback */
struct SELinuxAuditRec {
    ClientPtr client;           /* client */
    DeviceIntPtr dev;           /* device */
    char* command;              /* client's executable path */
    uint id;                /* resource id, if any */
    int restype;                /* resource type, if any */
    int event;                  /* event type, if any */
    Atom property;              /* property name, if any */
    Atom selection;             /* selection name, if any */
    char* extension;            /* extension name, if any */
}

/* private state keys */
// DevPrivateKeyRec subjectKeyRec;
// DevPrivateKeyRec objectKeyRec;
// DevPrivateKeyRec dataKeyRec;

/* audit file descriptor */
private int audit_fd;

/* atoms for window label properties */
private Atom atom_ctx;
private Atom atom_client_ctx;

/* The unlabeled SID */
private security_id_t unlabeled_sid;

/* forward declarations */


/* "true" pointer value for use as callback data */
private void* truep = cast(void*) 1;

/*
 * Performs an SELinux permission check.
 */
private int SELinuxDoCheck(SELinuxSubjectRec* subj, SELinuxObjectRec* obj, security_class_t class_, Mask mode, SELinuxAuditRec* auditdata)
{
    /* serverClient requests OK */
    if (subj.privileged) {
        return Success;
    }

    auditdata.command = subj.command.ptr;
    stdc.errno() = 0;

    if (assumeNoGC(&avc_has_perm)(subj.sid, obj.sid, class_, cast(uint)mode, &subj.aeref,
                     auditdata) < 0) {
        if (mode == DixUnknownAccess) {
            return Success;     /* DixUnknownAccess requests OK ... for now */
        }
        if (stdc.errno() == stdc.EACCES) {
            return BadAccess;
        }
        ErrorF("SELinux: avc_has_perm: unexpected error %d\n", stdc.errno);
        return BadValue;
    }

    return Success;
}

/*
 * Labels a newly connected client.
 */
private void SELinuxLabelClient(ClientPtr client)
{
    int fd = GetClientFd(client);
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    char* ctx = void;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&client.devPrivates, objectKey);

    /* Try to get a context from the socket */
    if (fd < 0 || getpeercon_raw_d(fd, &ctx) < 0) {
        /* Otherwise, fall back to a default context */
        ctx = SELinuxDefaultClientLabel();
    }

    /* For local clients, try and determine the executable name */
    if (ClientIsLocal(client)) {
        /* Get cached command name if CLIENTIDS is enabled. */
        const(char)* cmdname = GetClientCmdName(client);
        Bool cached = (cmdname !is null);

        /* If CLIENTIDS is disabled, figure out the command name from
         * scratch. */
        if (!cmdname) {
            stdctypes.pid_t pid = DetermineClientPid(client);
            if (pid != -1) {
                DetermineClientCmd(pid, &cmdname, null);
            }
        }

        if (!cmdname) {
            goto finish;
        }

        strncpy(subj.command.ptr, cmdname, COMMAND_LEN - 1);

        if (!cached) {
            core.stdc.stdlib.free(cast(void*) cmdname);     /* const char * */
        }
    }

 finish:
    /* Get a SID from the context */
    if (avc_context_to_sid_raw_d(ctx, &subj.sid) < 0) {
        FatalError("SELinux: client %d: context_to_sid_raw(%s) failed\n",
                   client.index, ctx);
    }

    obj.sid = subj.sid;
    freecon_d(ctx);
}

/*
 * Labels initial server objects.
 */
private void SELinuxLabelInitial()
{
    ScreenAccessCallbackParam srec = void;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    char* ctx = void;
    void* unused = void;

    /* Do the serverClient */
    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&serverClient.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&serverClient.devPrivates, objectKey);
    subj.privileged = 1;

    /* Use the context of the X server process for the serverClient */
    if (getcon_raw_d(&ctx) < 0) {
        FatalError("SELinux: couldn't get context of X server process\n");
    }

    /* Get a SID from the context */
    if (avc_context_to_sid_raw_d(ctx, &subj.sid) < 0) {
        FatalError("SELinux: serverClient: context_to_sid(%s) failed\n", ctx);
    }

    obj.sid = subj.sid;
    freecon_d(ctx);

    srec.client = serverClient;
    srec.access_mode = DixCreateAccess;
    srec.status = Success;

    mixin(DIX_FOR_EACH_SCREEN!q{
        /* Do the screen object */
        srec.screen = walkScreen;
        SELinuxScreen(null, null, &srec);

        /* Do the default colormap */
        dixLookupResourceByType(&unused, walkScreen.defColormap,
                                X11_RESTYPE_COLORMAP, serverClient, DixCreateAccess);
    });
}

/*
 * Labels new resource objects.
 */
private int SELinuxLabelResource(XaceResourceAccessRec* rec, SELinuxSubjectRec* subj, SELinuxObjectRec* obj, security_class_t class_)
{
    int offset = void;
    security_id_t tsid = void;

    /* Check for a create context */
    if (rec.rtype & RC_DRAWABLE && subj.win_create_sid) {
        obj.sid = subj.win_create_sid;
        return Success;
    }

    if (rec.parent) {
        offset = dixLookupPrivateOffset(rec.ptype);
    }

    if (rec.parent && offset >= 0) {
        /* Use the SID of the parent object in the labeling operation */
        PrivateRec** privatePtr = mixin(DEVPRIV_AT!("rec.parent", "offset"));
        SELinuxObjectRec* pobj = cast(SELinuxObjectRec*)dixLookupPrivate(privatePtr, objectKey);

        tsid = pobj.sid;
    }
    else {
        /* Use the SID of the subject */
        tsid = subj.sid;
    }

    /* Perform a transition to obtain the final SID */
    if (avc_compute_create_d(subj.sid, tsid, class_, &obj.sid) < 0) {
        ErrorF("SELinux: a compute_create call failed!\n");
        return BadValue;
    }

    return Success;
}

/*
 * Libselinux Callbacks
 */

private int SELinuxAudit(void* auditdata, security_class_t class_, char* msgbuf, size_t msgbufsize)
{
    SELinuxAuditRec* audit = cast(SELinuxAuditRec*)auditdata;
    ClientPtr client = audit.client;
    char[16] idNum = void;
    const(char)* propertyName = void, selectionName = void;
    int major = -1, minor = -1;

    if (client) {
        mixin(REQUEST!xReq);
        if (stuff) {
            major = client.majorOp;
            minor = client.minorOp;
        }
    }
    if (audit.id) {
        snprintf(idNum.ptr, 16, "%x", audit.id);
    }

    propertyName = audit.property ? atomMgr.nameForAtom(audit.property) : null;
    selectionName = audit.selection ? atomMgr.nameForAtom(audit.selection) : null;

    return snprintf(msgbuf, msgbufsize,
                    "%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s".ptr,
                    (major >= 0) ? "request=".ptr : "".ptr,
                    (major >= 0) ? LookupRequestName(major, minor) : "".ptr,
                    audit.command ? " comm=".ptr : "".ptr,
                    audit.command ? audit.command : "".ptr,
                    audit.dev ? " xdevice=\"".ptr : "".ptr,
                    audit.dev ? audit.dev.name : "".ptr,
                    audit.dev ? "\"".ptr : "".ptr,
                    audit.id ? " resid=".ptr : "".ptr,
                    audit.id ? idNum.ptr : "".ptr,
                    audit.restype ? " restype=".ptr : "".ptr,
                    audit.restype ? LookupResourceName(audit.restype) : "".ptr,
                    audit.event ? " event=".ptr : "".ptr,
                    audit.event ? LookupEventName(audit.event & 127) : "".ptr,
                    audit.property ? " property=".ptr : "".ptr,
                    audit.property ? propertyName : "".ptr,
                    audit.selection ? " selection=".ptr : "".ptr,
                    audit.selection ? selectionName : "".ptr,
                    audit.extension ? " extension=".ptr : "".ptr,
                    audit.extension ? audit.extension : "");
}

static int
SELinuxLog(int type, const char *fmt, ...);

private int SELinuxLog(int type, const(char)* fmt, ...)
{
    va_list ap = void;
    char[MAX_AUDIT_MESSAGE_LENGTH] buf = void;
    int aut = void;

    switch (type) {
    case SELINUX_ERROR:
        aut = AUDIT_USER_SELINUX_ERR;
        break;
    case SELINUX_AVC:
        aut = AUDIT_USER_AVC;
        break;
    default:
        /* Do not generate an audit event, just log normally. */
        aut = -1;
        break;
    }

    core.stdc.stdarg.va_start(ap, fmt);
    vsnprintf(buf.ptr, MAX_AUDIT_MESSAGE_LENGTH, fmt, ap);
    core.stdc.stdarg.va_end(ap);

    if (aut != -1) {
        cast(void) audit_log_user_avc_message_d(audit_fd, aut, buf.ptr, null, null, null, 0);
    }
    LogMessageVerb(X_WARNING, 0, "%s", buf.ptr);
    return 0;
}

private int SELinuxPolicyLoad(int seqno)
{
    LogMessage(X_INFO, "SELinux: PolicyLoad (%d) detected, remapping security classes\n", seqno);

    if (selinux_set_mapping_d(map.ptr) < 0) {
        if (stdc.errno == stdc.EINVAL) {
            ErrorF("SELinux: Invalid object class mapping\n");
        } else {
            ErrorF("SELinux: Failed to set up security class mapping\n");
        }
    }

    return 0;
}

/*
 * XACE Callbacks
 */

private void SELinuxDevice(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    DeviceAccessCallbackParam* rec = cast(DeviceAccessCallbackParam*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client,dev: rec.dev };
    security_class_t cls = void;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.dev.devPrivates, objectKey);

    /* If this is a new object that needs labeling, do it now */
    if (rec.access_mode & DixCreateAccess) {
        SELinuxSubjectRec* dsubj = void;

        dsubj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.dev.devPrivates, subjectKey);

        if (subj.dev_create_sid) {
            /* Label the device with the create context */
            obj.sid = subj.dev_create_sid;
            dsubj.sid = subj.dev_create_sid;
        }
        else {
            /* Label the device directly with the process SID */
            obj.sid = subj.sid;
            dsubj.sid = subj.sid;
        }
    }

    cls = IsPointerDevice(rec.dev) ? SECCLASS_X_POINTER : SECCLASS_X_KEYBOARD;
    int rc = SELinuxDoCheck(subj, obj, cls, rec.access_mode, &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }
}

private void SELinuxSend(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceSendAccessRec* rec = cast(XaceSendAccessRec*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void; SELinuxObjectRec ev_sid = void;
    SELinuxAuditRec auditdata = {client: rec.client,dev: rec.dev };
    security_class_t class_ = void;
    int i = void, type = void;

    if (rec.dev) {
        subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.dev.devPrivates, subjectKey);
    } else {
        subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    }

    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.pWin.devPrivates, objectKey);

    /* Check send permission on window */
    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_DRAWABLE, DixSendAccess,
                        &auditdata);
    if (rc != Success) {
        goto err;
    }

    /* Check send permission on specific event types */
    for (i = 0; i < rec.count; i++) {
        type = rec.events[i].u.u.type;
        class_ = (type & 128) ? SECCLASS_X_FAKEEVENT : SECCLASS_X_EVENT;

        rc = SELinuxEventToSID(type, obj.sid, &ev_sid);
        if (rc != Success)
            goto err;

        auditdata.event = type;
        rc = SELinuxDoCheck(subj, &ev_sid, class_, DixSendAccess, &auditdata);
        if (rc != Success) {
            goto err;
        }
    }
    return;
 err:
    rec.status = rc;
}

private void SELinuxReceive(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceReceiveAccessRec* rec = cast(XaceReceiveAccessRec*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void; SELinuxObjectRec ev_sid = void;
    SELinuxAuditRec auditdata = {client: null };
    security_class_t class_ = void;
    int i = void, type = void;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.pWin.devPrivates, objectKey);

    /* Check receive permission on window */
    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_DRAWABLE, DixReceiveAccess,
                        &auditdata);
    if (rc != Success) {
        goto err;
    }

    /* Check receive permission on specific event types */
    for (i = 0; i < rec.count; i++) {
        type = rec.events[i].u.u.type;
        class_ = (type & 128) ? SECCLASS_X_FAKEEVENT : SECCLASS_X_EVENT;

        rc = SELinuxEventToSID(type, obj.sid, &ev_sid);
        if (rc != Success) {
            goto err;
        }

        auditdata.event = type;
        rc = SELinuxDoCheck(subj, &ev_sid, class_, DixReceiveAccess, &auditdata);
        if (rc != Success) {
            goto err;
        }
    }
    return;
 err:
    rec.status = rc;
}

private void SELinuxExtension(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ExtensionAccessCallbackParam* rec = cast(ExtensionAccessCallbackParam*)calldata;
    SELinuxSubjectRec* subj = void, serv = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client };

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.ext.devPrivates, objectKey);

    /* If this is a new object that needs labeling, do it now */
    /* XXX there should be a separate callback for this */
    if (obj.sid is null) {
        security_id_t sid = void;

        serv = cast(SELinuxSubjectRec*)dixLookupPrivate(&serverClient.devPrivates, subjectKey);
        int rc = SELinuxExtensionToSID(rec.ext.name, &sid);
        if (rc != Success) {
            rec.status = rc;
            return;
        }

        /* Perform a transition to obtain the final SID */
        if (avc_compute_create_d(serv.sid, sid, SECCLASS_X_EXTENSION,
                               &obj.sid) < 0) {
            ErrorF("SELinux: a SID transition call failed!\n");
            rec.status = BadValue;
            return;
        }
    }

    /* Perform the security check */
    auditdata.extension = cast(char*) rec.ext.name;
    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_EXTENSION, rec.access_mode,
                        &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }
}

private void SELinuxSelection(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceSelectionAccessRec* rec = cast(XaceSelectionAccessRec*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void, data = void;
    Selection* pSel = *rec.ppSel;
    Atom name = pSel.selection;
    Mask access_mode = rec.access_mode;
    SELinuxAuditRec auditdata = {client: rec.client,selection: name };
    security_id_t tsid = void;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pSel.devPrivates, objectKey);

    /* If this is a new object that needs labeling, do it now */
    if (access_mode & DixCreateAccess) {
        int rc = SELinuxSelectionToSID(name, subj, &obj.sid, &obj.poly);
        if (rc != Success)
            obj.sid = unlabeled_sid;
        access_mode = DixSetAttrAccess;
    }
    /* If this is a polyinstantiated object, find the right instance */
    else if (obj.poly) {
        int rc = SELinuxSelectionToSID(name, subj, &tsid, null);
        if (rc != Success) {
            rec.status = rc;
            return;
        }
        while (pSel.selection != name || obj.sid != tsid) {
            if ((pSel = pSel.next) is null) {
                break;
            }
            obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pSel.devPrivates, objectKey);
        }

        if (pSel) {
            *rec.ppSel = pSel;
        } else {
            rec.status = BadMatch;
            return;
        }
    }

    /* Perform the security check */
    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_SELECTION, access_mode,
                        &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }

    /* Label the content (advisory only) */
    if (access_mode & DixSetAttrAccess) {
        data = cast(SELinuxObjectRec*)dixLookupPrivate(&pSel.devPrivates, dataKey);
        if (subj.sel_create_sid) {
            data.sid = subj.sel_create_sid;
        } else {
            data.sid = obj.sid;
        }
    }
}

private void SELinuxProperty(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XacePropertyAccessRec* rec = cast(XacePropertyAccessRec*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void, data = void;
    PropertyPtr pProp = *rec.ppProp;
    Atom name = pProp.propertyName;
    SELinuxAuditRec auditdata = {client: rec.client,property: name };
    security_id_t tsid = void;

    /* Don't care about the new content check */
    if (rec.access_mode & DixPostAccess) {
        return;
    }

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pProp.devPrivates, objectKey);

    /* If this is a new object that needs labeling, do it now */
    if (rec.access_mode & DixCreateAccess) {
        int rc = SELinuxPropertyToSID(name, subj, &obj.sid, &obj.poly);
        if (rc != Success) {
            rec.status = rc;
            return;
        }
    }
    /* If this is a polyinstantiated object, find the right instance */
    else if (obj.poly) {
        int rc = SELinuxPropertyToSID(name, subj, &tsid, null);
        if (rc != Success) {
            rec.status = rc;
            return;
        }
        while (pProp.propertyName != name || obj.sid != tsid) {
            if ((pProp = pProp.next) is null) {
                break;
            }
            obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pProp.devPrivates, objectKey);
        }

        if (pProp) {
            *rec.ppProp = pProp;
        } else {
            rec.status = BadMatch;
            return;
        }
    }

    /* Perform the security check */
    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_PROPERTY, rec.access_mode,
                        &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }

    /* Label the content (advisory only) */
    if (rec.access_mode & DixWriteAccess) {
        data = cast(SELinuxObjectRec*)dixLookupPrivate(&pProp.devPrivates, dataKey);
        if (subj.prp_create_sid) {
            data.sid = subj.prp_create_sid;
        } else {
            data.sid = obj.sid;
        }
    }
}

private void SELinuxResource(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    XaceResourceAccessRec* rec = cast(XaceResourceAccessRec*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client };
    Mask access_mode = rec.access_mode;
    PrivateRec** privatePtr = void;
    security_class_t class_ = void;
    int offset = void;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);

    /* Determine if the resource object has a devPrivates field */
    offset = dixLookupPrivateOffset(rec.rtype);
    if (offset < 0) {
        /* No: use the SID of the owning client */
        class_ = SECCLASS_X_RESOURCE;
        ClientPtr owner = dixClientForXID(rec.id);
        if (!owner) {
            return;
        }
        privatePtr = &owner.devPrivates;
        obj = cast(SELinuxObjectRec*)dixLookupPrivate(privatePtr, objectKey);
    }
    else {
        /* Yes: use the SID from the resource object itself */
        class_ = SELinuxTypeToClass(rec.rtype);
        privatePtr = mixin(DEVPRIV_AT!("rec.res", "offset"));
        obj = cast(SELinuxObjectRec*)dixLookupPrivate(privatePtr, objectKey);
    }

    /* If this is a new object that needs labeling, do it now */
    if (access_mode & DixCreateAccess && offset >= 0) {
        int rc = SELinuxLabelResource(rec, subj, obj, class_);
        if (rc != Success) {
            rec.status = rc;
            return;
        }
    }

    /* Collapse generic resource permissions down to read/write */
    if (class_ == SECCLASS_X_RESOURCE) {
        access_mode = ! !(rec.access_mode & SELinuxReadMask);  /* rd */
        access_mode |= ! !(rec.access_mode & ~SELinuxReadMask) << 1;   /* wr */
    }

    /* Perform the security check */
    auditdata.restype = rec.rtype;
    auditdata.id = cast(uint)rec.id;
    int rc = SELinuxDoCheck(subj, obj, class_, access_mode, &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }

    /* Perform the background none check on windows */
    if (access_mode & DixCreateAccess && rec.rtype == X11_RESTYPE_WINDOW) {
        rc = SELinuxDoCheck(subj, obj, class_, DixBlendAccess, &auditdata);
        if (rc != Success) {
            (cast(WindowPtr) rec.res).forcedBG = True;
        }
    }
}

private void SELinuxScreen(CallbackListPtr* pcbl, void* is_saver, void* calldata)
{
    ScreenAccessCallbackParam* rec = cast(ScreenAccessCallbackParam*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client };
    Mask access_mode = rec.access_mode;

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.screen.devPrivates, objectKey);

    /* If this is a new object that needs labeling, do it now */
    if (access_mode & DixCreateAccess) {
        /* Perform a transition to obtain the final SID */
        if (avc_compute_create_d(subj.sid, subj.sid, SECCLASS_X_SCREEN,
                               &obj.sid) < 0) {
            ErrorF("SELinux: a compute_create call failed!\n");
            rec.status = BadValue;
            return;
        }
    }

    if (is_saver) {
        access_mode <<= 2;
    }

    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_SCREEN, access_mode, &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }
}

private void SELinuxClient(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ClientAccessCallbackParam* rec = cast(ClientAccessCallbackParam* )calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client };

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&rec.target.devPrivates, objectKey);

    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_CLIENT, rec.access_mode,
                        &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }
}

private void SELinuxServer(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ServerAccessCallbackParam* rec = cast(ServerAccessCallbackParam*)calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    SELinuxAuditRec auditdata = {client: rec.client };

    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&rec.client.devPrivates, subjectKey);
    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&serverClient.devPrivates, objectKey);

    int rc = SELinuxDoCheck(subj, obj, SECCLASS_X_SERVER, rec.access_mode,
                        &auditdata);
    if (rc != Success) {
        rec.status = rc;
    }
}

/*
 * DIX Callbacks
 */

private void SELinuxClientState(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    NewClientInfoRec* pci = cast(NewClientInfoRec*)calldata;

    switch (pci.client.clientState) {
    case ClientStateInitial:
        SELinuxLabelClient(pci.client);
        break;

    default:
        break;
    }
}

private void SELinuxResourceState(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ResourceStateInfoRec* rec = cast(ResourceStateInfoRec* )calldata;
    SELinuxSubjectRec* subj = void;
    SELinuxObjectRec* obj = void;
    WindowPtr pWin = void;

    if (rec.type != X11_RESTYPE_WINDOW) {
        return;
    }
    if (rec.state != ResourceStateAdding) {
        return;
    }

    pWin = cast(WindowPtr) rec.value;
    subj = cast(SELinuxSubjectRec*)dixLookupPrivate(&dixClientForWindow(pWin).devPrivates, subjectKey);

    if (subj.sid) {
        char* ctx = void;
        int rc = assumeNoGC(&avc_sid_to_context_raw)(subj.sid, &ctx);

        if (rc < 0) {
            FatalError("SELinux: Failed to get security context!\n");
        }
        rc = dixChangeWindowProperty(serverClient,
                                     pWin, atom_client_ctx, XA_STRING, 8,
                                     PropModeReplace, strlen(ctx), ctx, False);
        if (rc != Success) {
            FatalError("SELinux: Failed to set label property on window!\n");
        }
        freecon_d(ctx);
    }
    else
        FatalError("SELinux: Unexpected unlabeled client found\n");

    obj = cast(SELinuxObjectRec*)dixLookupPrivate(&pWin.devPrivates, objectKey);

    if (obj.sid) {
        char* ctx = void;
        int rc = assumeNoGC(&avc_sid_to_context_raw)(obj.sid, &ctx);

        if (rc < 0) {
            FatalError("SELinux: Failed to get security context!\n");
        }
        rc = dixChangeWindowProperty(serverClient,
                                     pWin, atom_ctx, XA_STRING, 8,
                                     PropModeReplace, strlen(ctx), ctx, False);
        if (rc != Success) {
            FatalError("SELinux: Failed to set label property on window!\n");
        }
        freecon_d(ctx);
    } else {
        FatalError("SELinux: Unexpected unlabeled window found\n");
    }
}

private int netlink_fd;

private void SELinuxNetlinkNotify(int fd, int ready, void* data)
{
    avc_netlink_check_nb_d();
}

void SELinuxFlaskReset()
{
    /* Unregister callbacks */
    DeleteCallback(&ClientStateCallback, &SELinuxClientState, null);
    DeleteCallback(&ResourceStateCallback, &SELinuxResourceState, null);
    DeleteCallback(&ExtensionAccessCallback, &SELinuxExtension, null);
    DeleteCallback(&ExtensionDispatchCallback, &SELinuxExtension, null);
    DeleteCallback(&ServerAccessCallback, &SELinuxServer, null);
    DeleteCallback(&ClientAccessCallback, &SELinuxClient, null);
    DeleteCallback(&DeviceAccessCallback, &SELinuxDevice, null);
    DeleteCallback(&ScreenSaverAccessCallback, &SELinuxScreen, truep);
    DeleteCallback(&ScreenAccessCallback, &SELinuxScreen, null);

    XaceDeleteCallback(XACE_RESOURCE_ACCESS, &SELinuxResource, null);
    XaceDeleteCallback(XACE_PROPERTY_ACCESS, &SELinuxProperty, null);
    XaceDeleteCallback(XACE_SEND_ACCESS, &SELinuxSend, null);
    XaceDeleteCallback(XACE_RECEIVE_ACCESS, &SELinuxReceive, null);
    XaceDeleteCallback(XACE_SELECTION_ACCESS, &SELinuxSelection, null);

    /* Tear down SELinux stuff */
    audit_close_d(audit_fd);
    avc_netlink_release_fd_d();
    RemoveNotifyFd(netlink_fd);

    avc_destroy_d();
}

void SELinuxFlaskInit()
{
    selinux_opt avc_option = { AVC_OPT_SETENFORCE, cast(char*) 0 };
    char* ctx = void;
    int ret = True;

    switch (selinuxEnforcingState) {
    case SELINUX_MODE_ENFORCING:
        LogMessage(X_INFO, "SELinux: Configured in enforcing mode\n");
        avc_option.value = cast(char*) 1;
        break;
    case SELINUX_MODE_PERMISSIVE:
        LogMessage(X_INFO, "SELinux: Configured in permissive mode\n");
        avc_option.value = cast(char*) 0;
        break;
    default:
        avc_option.type = AVC_OPT_UNUSED;
        break;
    }

    /* Set up SELinux stuff */
    selinux_set_callback_d(SELINUX_CB_LOG, selinux_callback ( func_log: &SELinuxLog ));
    selinux_set_callback_d(SELINUX_CB_AUDIT,selinux_callback ( func_audit: &SELinuxAudit ));
    selinux_set_callback_d(SELINUX_CB_POLICYLOAD, selinux_callback ( func_policyload: &SELinuxPolicyLoad ));

    if (selinux_set_mapping_d(map.ptr) < 0) {
        if (stdc.errno == stdc.EINVAL) {
            ErrorF
                ("SELinux: Invalid object class mapping, disabling SELinux support.\n");
            return;
        }
        FatalError("SELinux: Failed to set up security class mapping\n");
    }

    if (avc_open_d(cast(avc_init_args*)&avc_option, 1) < 0) {
        FatalError("SELinux: Couldn't initialize SELinux userspace AVC\n");
    }

    if (security_get_initial_context_raw_d("unlabeled", &ctx) < 0) {
        FatalError("SELinux: Failed to look up unlabeled context\n");
    }
    if (avc_context_to_sid_raw_d(ctx, &unlabeled_sid) < 0) {
        FatalError("SELinux: a context_to_SID call failed!\n");
    }
    freecon_d(ctx);

    /* Prepare for auditing */
    audit_fd = audit_open_d();
    if (audit_fd < 0) {
        FatalError("SELinux: Failed to open the system audit log\n");
    }

    /* Allocate private storage */
    if (!dixRegisterPrivateKey
        (subjectKey, PRIVATE_XSELINUX, SELinuxSubjectRec.sizeof) ||
        !dixRegisterPrivateKey(objectKey, PRIVATE_XSELINUX,
                               SELinuxObjectRec.sizeof) ||
        !dixRegisterPrivateKey(dataKey, PRIVATE_XSELINUX,
                               SELinuxObjectRec.sizeof))
    {
        FatalError("SELinux: Failed to allocate private storage.\n");
    }

    /* Create atoms for doing window labeling */
    atom_ctx = dixAddAtom("_SELINUX_CONTEXT");
    if (atom_ctx == BAD_RESOURCE) {
        FatalError("SELinux: Failed to create atom\n");
    }
    atom_client_ctx = dixAddAtom("_SELINUX_CLIENT_CONTEXT");
    if (atom_client_ctx == BAD_RESOURCE) {
        FatalError("SELinux: Failed to create atom\n");
    }
    netlink_fd = avc_netlink_acquire_fd_d();
    SetNotifyFd(netlink_fd, &SELinuxNetlinkNotify, X_NOTIFY_READ, null);

    /* Register callbacks */
    ret &= AddCallback(&ClientStateCallback, &SELinuxClientState, null);
    ret &= AddCallback(&ResourceStateCallback, &SELinuxResourceState, null);
    ret &= AddCallback(&ExtensionAccessCallback, &SELinuxExtension, null);
    ret &= AddCallback(&ExtensionDispatchCallback, &SELinuxExtension, null);
    ret &= AddCallback(&ServerAccessCallback, &SELinuxServer, null);
    ret &= AddCallback(&ClientAccessCallback, &SELinuxClient, null);
    ret &= AddCallback(&DeviceAccessCallback, &SELinuxDevice, null);
    ret &= AddCallback(&ScreenSaverAccessCallback, &SELinuxScreen, truep);
    ret &= AddCallback(&ScreenAccessCallback, &SELinuxScreen, null);

    ret &= XaceRegisterCallback(XACE_RESOURCE_ACCESS, &SELinuxResource, null);
    ret &= XaceRegisterCallback(XACE_PROPERTY_ACCESS, &SELinuxProperty, null);
    ret &= XaceRegisterCallback(XACE_SEND_ACCESS, &SELinuxSend, null);
    ret &= XaceRegisterCallback(XACE_RECEIVE_ACCESS, &SELinuxReceive, null);
    ret &= XaceRegisterCallback(XACE_SELECTION_ACCESS, &SELinuxSelection, null);
    if (!ret) {
        FatalError("SELinux: Failed to register one or more callbacks\n");
    }

    /* Label objects that were created before we could register ourself */
    SELinuxLabelInitial();
}
