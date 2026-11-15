module Xext.xselinux_label;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

import externs.selinux.label;

import dix.registry_priv;

import Xext.xselinuxint;
import Xext.xselinux_label;
import stdc = core.stdc.stdlib, core.stdc.errno;
import cerrno = core.stdc.errno;
import externs.attrs;
import dix.resource;
import registry;

import os.log;

/* selection and property atom cache */
struct SELinuxAtomRec {
    SELinuxObjectRec prp;
    SELinuxObjectRec sel;
}

/* dynamic array */
struct SELinuxArrayRec {
    uint size;
    void** array;
}

/* labeling handle */
private selabel_handle* label_hnd;

/* Array of object classes indexed by resource type */
SELinuxArrayRec arr_types;

/* Array of event SIDs indexed by event type */
SELinuxArrayRec arr_events;

/* Array of property and selection SID structures */
SELinuxArrayRec arr_atoms;

/*
 * Dynamic array helpers
 */
private void* SELinuxArrayGet(SELinuxArrayRec* rec, uint key)
{
    return (rec.size > key) ? rec.array[key] : null;
}

private int SELinuxArraySet(SELinuxArrayRec* rec, uint key, void* val)
{
    if (key >= rec.size) {
        /* Need to increase size of array */
        rec.array = cast(void**) reallocarray(rec.array, key + 1, val.sizeof);        
        if (!rec.array)
            return False;
        memset(rec.array + rec.size, 0, (key - rec.size + 1) * val.sizeof);
        rec.size = key + 1;
    }

    rec.array[key] = val;
    return True;
}

private void SELinuxArrayFree(SELinuxArrayRec* rec, int free_elements)
{
    if (free_elements) {
        uint i = rec.size;

        while (i) {
            stdc.free(rec.array[--i]);
        }
    }

    stdc.free(rec.array);
    rec.size = 0;
    rec.array = null;
}

/*
 * Looks up a name in the selection or property mappings
 */
private int SELinuxAtomToSIDLookup(Atom atom, SELinuxObjectRec* obj, int map, int polymap)
{
    const(char)* name = atomMgr.nameForAtom(atom);
    char* ctx = void;
    int rc = Success;

    obj.poly = 1;

    /* Look in the mappings of names to contexts */
    if (selabel_lookup_raw_d(label_hnd, &ctx, name, map) == 0) {
        obj.poly = 0;
    }
    else if (cerrno.errno() != cerrno.ENOENT) {
        ErrorF("SELinux: a property label lookup failed!\n");
        return BadValue;
    }
    else if (selabel_lookup_raw_d(label_hnd, &ctx, name, polymap) < 0) {
        ErrorF("SELinux: a property label lookup failed!\n");
        return BadValue;
    }

    /* Get a SID for context */
    if (avc_context_to_sid_raw_d(ctx, &obj.sid) < 0) {
        ErrorF("SELinux: a context_to_SID_raw call failed!\n");
        rc = BadAlloc;
    }

    freecon_d(ctx);
    return rc;
}

/*
 * Looks up the SID corresponding to the given property or selection atom
 */
int SELinuxAtomToSID(Atom atom, int prop, SELinuxObjectRec** obj_rtn)
{
    SELinuxAtomRec* rec = void;
    SELinuxObjectRec* obj = void;
    int rc = void, map = void, polymap = void;

    rec = cast(SELinuxAtomRec*)SELinuxArrayGet(&arr_atoms, cast(uint)atom);
    if (!rec) {
        rec = cast(SELinuxAtomRec*) cast(SELinuxAtomRec*) stdc.calloc(1, SELinuxAtomRec.sizeof);
        if (!rec) {
            return BadAlloc;
        }
        if (!SELinuxArraySet(&arr_atoms, cast(uint)atom, rec)) {
            stdc.free(rec);
            return BadAlloc;
        }
    }

    if (prop) {
        obj = &rec.prp;
        map = SELABEL_X_PROP;
        polymap = SELABEL_X_POLYPROP;
    }
    else {
        obj = &rec.sel;
        map = SELABEL_X_SELN;
        polymap = SELABEL_X_POLYSELN;
    }

    if (!obj.sid) {
        rc = SELinuxAtomToSIDLookup(atom, obj, map, polymap);
        if (rc != Success) {
            goto out_;
        }
    }

    *obj_rtn = obj;
    rc = Success;
 out_:
    return rc;
}

/*
 * Looks up a SID for a selection/subject pair
 */
int SELinuxSelectionToSID(Atom selection, SELinuxSubjectRec* subj, security_id_t* sid_rtn, int* poly_rtn)
{
    int rc = void;
    SELinuxObjectRec* obj = void;
    security_id_t tsid = void;

    /* Get the default context and polyinstantiation bit */
    rc = SELinuxAtomToSID(selection, 0, &obj);
    if (rc != Success) {
        return rc;
    }

    /* Check for an override context next */
    if (subj.sel_use_sid) {
        tsid = subj.sel_use_sid;
        goto out_;
    }

    tsid = obj.sid;

    /* Polyinstantiate if necessary to obtain the final SID */
    if (obj.poly && avc_compute_member_d(subj.sid, obj.sid,
                                        SECCLASS_X_SELECTION, &tsid) < 0) {
        ErrorF("SELinux: a compute_member call failed!\n");
        return BadValue;
    }
 out_:
    *sid_rtn = tsid;
    if (poly_rtn) {
        *poly_rtn = obj.poly;
    }
    return Success;
}

/*
 * Looks up a SID for a property/subject pair
 */
int SELinuxPropertyToSID(Atom property, SELinuxSubjectRec* subj, security_id_t* sid_rtn, int* poly_rtn)
{
    int rc = void;
    SELinuxObjectRec* obj = void;
    security_id_t tsid = void, tsid2 = void;

    /* Get the default context and polyinstantiation bit */
    rc = SELinuxAtomToSID(property, 1, &obj);
    if (rc != Success) {
        return rc;
    }

    /* Check for an override context next */
    if (subj.prp_use_sid) {
        tsid = subj.prp_use_sid;
        goto out_;
    }

    /* Perform a transition */
    if (avc_compute_create_d(subj.sid, obj.sid, SECCLASS_X_PROPERTY, &tsid) < 0) {
        ErrorF("SELinux: a compute_create call failed!\n");
        return BadValue;
    }

    /* Polyinstantiate if necessary to obtain the final SID */
    if (obj.poly) {
        tsid2 = tsid;
        if (avc_compute_member_d(subj.sid, tsid2,
                               SECCLASS_X_PROPERTY, &tsid) < 0) {
            ErrorF("SELinux: a compute_member call failed!\n");
            return BadValue;
        }
    }
 out_:
    *sid_rtn = tsid;
    if (poly_rtn) {
        *poly_rtn = obj.poly;
    }
    return Success;
}

/*
 * Looks up the SID corresponding to the given event type
 */
int SELinuxEventToSID(uint type, security_id_t sid_of_window, SELinuxObjectRec* sid_return)
{
    const(char)* name = LookupEventName(type);
    security_id_t sid = void;
    char* ctx = void;

    type &= 127;

    sid = cast(security_id_t)SELinuxArrayGet(&arr_events, type);
    if (!sid) {
        /* Look in the mappings of event names to contexts */
        if (selabel_lookup_raw_d(label_hnd, &ctx, name, SELABEL_X_EVENT) < 0) {
            ErrorF("SELinux: an event label lookup failed!\n");
            return BadValue;
        }
        /* Get a SID for context */
        if (avc_context_to_sid_raw_d(ctx, &sid) < 0) {
            ErrorF("SELinux: a context_to_SID_raw call failed!\n");
            freecon_d(ctx);
            return BadAlloc;
        }
        freecon_d(ctx);
        /* Cache the SID value */
        if (!SELinuxArraySet(&arr_events, type, sid)) {
            return BadAlloc;
        }
    }

    /* Perform a transition to obtain the final SID */
    if (avc_compute_create_d(sid_of_window, sid, SECCLASS_X_EVENT,
                           &sid_return.sid) < 0) {
        ErrorF("SELinux: a compute_create call failed!\n");
        return BadValue;
    }

    return Success;
}

int SELinuxExtensionToSID(const(char)* name, security_id_t* sid_rtn)
{
    char* ctx = void;

    /* Look in the mappings of extension names to contexts */
    if (selabel_lookup_raw_d(label_hnd, &ctx, name, SELABEL_X_EXT) < 0) {
        ErrorF("SELinux: a property label lookup failed!\n");
        return BadValue;
    }
    /* Get a SID for context */
    if (avc_context_to_sid_raw_d(ctx, sid_rtn) < 0) {
        ErrorF("SELinux: a context_to_SID_raw call failed!\n");
        freecon_d(ctx);
        return BadAlloc;
    }
    freecon_d(ctx);
    return Success;
}

/*
 * Returns the object class corresponding to the given resource type.
 */
security_class_t SELinuxTypeToClass(RESTYPE type)
{
    void* tmp = void;

    tmp = SELinuxArrayGet(&arr_types, type & TypeMask);
    if (!tmp) {
        c_ulong class_ = SECCLASS_X_RESOURCE;

        if (type & RC_DRAWABLE) {
            class_ = SECCLASS_X_DRAWABLE;
        } else if (type == X11_RESTYPE_GC) {
            class_ = SECCLASS_X_GC;
        } else if (type == X11_RESTYPE_FONT) {
            class_ = SECCLASS_X_FONT;
        } else if (type == X11_RESTYPE_CURSOR) {
            class_ = SECCLASS_X_CURSOR;
        } else if (type == X11_RESTYPE_COLORMAP) {
            class_ = SECCLASS_X_COLORMAP;
        } else {
            /* Need to do a string lookup */
            const(char)* str = LookupResourceName(type);

            if (!strcmp(str, "PICTURE")) {
                class_ = SECCLASS_X_DRAWABLE;
            } else if (!strcmp(str, "GLYPHSET")) {
                class_ = SECCLASS_X_FONT;
            }
        }

        tmp = cast(void*)
        SELinuxArraySet(&arr_types, type & TypeMask, tmp);
    }

    return cast(security_class_t) cast(c_ulong) tmp;
}

char* SELinuxDefaultClientLabel()
{
    char* ctx = void;

    if (selabel_lookup_raw_d(label_hnd, &ctx, "remote", SELABEL_X_CLIENT) < 0) {
        FatalError("SELinux: failed to look up remote-client context\n");
    }

    return ctx;
}

void SELinuxLabelInit()
{
    selinux_opt selabel_option = { SELABEL_OPT_VALIDATE, cast(char*) 1 };

    label_hnd = selabel_open_d(SELABEL_CTX_X, &selabel_option, 1);
    if (!label_hnd) {
        FatalError("SELinux: Failed to open x_contexts mapping in policy\n");
    }
}

void SELinuxLabelReset()
{
    selabel_close_d(label_hnd);
    label_hnd = null;

    /* Free local state */
    SELinuxArrayFree(&arr_types, 0);
    SELinuxArrayFree(&arr_events, 0);
    SELinuxArrayFree(&arr_atoms, 1);
}
