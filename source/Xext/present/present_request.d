module present.present_request;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import dix.dix_priv;
import dix.request_priv;
import dri3.dri3_priv;
import present.present_priv;

import randr.randrstr_priv;
import common.protocol_versions;
import externs.X11.extensions.presentproto;
import xfixes.region;
import Xext.sync;
import randr.rrcrtc;
import build.xlibre_server;
import common.swap;

alias XSyncFence = CARD32;

private int proc_present_query_version(ClientPtr client)
{
    mixin(REQUEST!xPresentQueryVersionReq);
    xPresentQueryVersionReply reply = {
        majorVersion: SERVER_PRESENT_MAJOR_VERSION,
        minorVersion: SERVER_PRESENT_MINOR_VERSION
    };

    mixin(REQUEST_AT_LEAST_SIZE!xPresentQueryVersionReq);
    /* From presentproto:
     *
     * The client sends the highest supported version to the server
     * and the server sends the highest version it supports, but no
     * higher than the requested version.
     */

    if (reply.majorVersion > stuff.majorVersion ||
        reply.minorVersion > stuff.minorVersion) {
        reply.majorVersion = stuff.majorVersion;
        reply.minorVersion = stuff.minorVersion;
    }

    if (client.swapped) {
        swapl(&reply.majorVersion);
        swapl(&reply.minorVersion);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

enum string VERIFY_FENCE_OR_NONE(string fence_ptr, string fence_id, string client, string access) = `{  
        if ((` ~ fence_id ~ `) == None)                                         
            (` ~ fence_ptr ~ `) = null;                                         
        else {                                                          
            int __rc__ = SyncVerifyFence(&` ~ fence_ptr ~ `, ` ~ fence_id ~ `, ` ~ client ~ `, ` ~ access ~ `); 
            if (__rc__ != Success)                                      
                return __rc__;                                          
        }                                                               
    } `;

enum string VERIFY_CRTC_OR_NONE(string crtc_ptr, string crtc_id, string client, string access) = `{     
        if ((` ~ crtc_id ~ `) == None)                                          
            (` ~ crtc_ptr ~ `) = null;                                          
        else {                                                          
            `~VERIFY_RR_CRTC!(crtc_id, crtc_ptr, access)~`;                  
        }                                                               
    }`;

static if(DRI3) {
private int proc_present_pixmap_common(ClientPtr client, 
    Window req_window, Pixmap req_pixmap, 
    CARD32 req_serial, CARD32 req_valid, 
    CARD32 req_update, INT16 req_x_off, 
    INT16 req_y_off, CARD32 req_target_crtc, 
    XSyncFence req_wait_fence, XSyncFence req_idle_fence, 
    dri3_syncobj* acquire_syncobj, dri3_syncobj* release_syncobj, 
    CARD64 req_acquire_point, CARD64 req_release_point, 
    CARD32 req_options, CARD64 req_target_msc, 
    CARD64 req_divisor, CARD64 req_remainder, 
    size_t base_req_size, xPresentNotify* req_notifies)
{
    WindowPtr window = void;
    PixmapPtr pixmap = void;
    RegionPtr valid = null;
    RegionPtr update = null;
    RRCrtcPtr target_crtc = void;
    SyncFence* wait_fence = void;
    SyncFence* idle_fence = void;
    int nnotifies = void;
    present_notify_ptr notifies = null;
    int ret = void;

    ret = dixLookupWindow(&window, req_window, client, DixWriteAccess);
    if (ret != Success)
        return ret;
    ret = dixLookupResourceByType(cast(void**) &pixmap, req_pixmap, X11_RESTYPE_PIXMAP, client, DixReadAccess);
    if (ret != Success)
        return ret;

    if (window.drawable.depth != pixmap.drawable.depth)
        return BadMatch;

    mixin(VERIFY_REGION_OR_NONE!("valid", "req_valid", "client", "DixReadAccess"));
    mixin(VERIFY_REGION_OR_NONE!("update", "req_update", "client", "DixReadAccess"));

    mixin(VERIFY_CRTC_OR_NONE!(`target_crtc`, `req_target_crtc`, `client`, `DixReadAccess`));

    mixin(VERIFY_FENCE_OR_NONE!(`wait_fence`, `req_wait_fence`, `client`, `DixReadAccess`));
    mixin(VERIFY_FENCE_OR_NONE!(`idle_fence`, `req_idle_fence`, `client`, `DixWriteAccess`));

    if (req_options & ~(PresentAllOptions)) {
        client.errorValue = cast(uint)req_options;
        return BadValue;
    }

    /*
     * Check to see if remainder is sane
     */
    if (req_divisor == 0) {
        if (req_remainder != 0) {
            client.errorValue = cast(uint)cast(CARD32)req_remainder;
            return BadValue;
        }
    } else {
        if (req_remainder >= req_divisor) {
            client.errorValue = cast(uint)cast(CARD32)req_remainder;
            return BadValue;
        }
    }

    nnotifies = cast(int)((client.req_len << 2) - base_req_size);
    if (nnotifies % xPresentNotify.sizeof)
        return BadLength;

    nnotifies /= xPresentNotify.sizeof;
    if (nnotifies) {
        ret = present_create_notifies(client, nnotifies, req_notifies, &notifies);
        if (ret != Success)
            return ret;
    }

    ret = present_pixmap(window, pixmap, req_serial,
                valid, update, req_x_off, req_y_off, target_crtc,
                wait_fence, idle_fence,
                acquire_syncobj, release_syncobj,
                req_acquire_point, req_release_point,
                cast(uint)req_options, req_target_msc, req_divisor, req_remainder,
                notifies, nnotifies);

    if (ret != Success)
        present_destroy_notifies(notifies, nnotifies);
    return ret;
}

}
else {
    private int proc_present_pixmap_common(ClientPtr client, 
    Window req_window, Pixmap req_pixmap, 
    CARD32 req_serial, CARD32 req_valid, 
    CARD32 req_update, INT16 req_x_off, 
    INT16 req_y_off, CARD32 req_target_crtc, 
    XSyncFence req_wait_fence, XSyncFence req_idle_fence, 
    CARD32 req_options, CARD64 req_target_msc, 
    CARD64 req_divisor, CARD64 req_remainder, 
    size_t base_req_size, xPresentNotify* req_notifies)
{
    WindowPtr window = void;
    PixmapPtr pixmap = void;
    RegionPtr valid = null;
    RegionPtr update = null;
    RRCrtcPtr target_crtc = void;
    SyncFence* wait_fence = void;
    SyncFence* idle_fence = void;
    int nnotifies = void;
    present_notify_ptr notifies = null;
    int ret = void;

    ret = dixLookupWindow(&window, req_window, client, DixWriteAccess);
    if (ret != Success)
        return ret;
    ret = dixLookupResourceByType(cast(void**) &pixmap, req_pixmap, X11_RESTYPE_PIXMAP, client, DixReadAccess);
    if (ret != Success)
        return ret;

    if (window.drawable.depth != pixmap.drawable.depth)
        return BadMatch;

    mixin(VERIFY_REGION_OR_NONE!("valid", "req_valid", "client", "DixReadAccess"));
    mixin(VERIFY_REGION_OR_NONE!("update", "req_update", "client", "DixReadAccess"));

    mixin(VERIFY_CRTC_OR_NONE!(`target_crtc`, `req_target_crtc`, `client`, `DixReadAccess`));

    mixin(VERIFY_FENCE_OR_NONE!(`wait_fence`, `req_wait_fence`, `client`, `DixReadAccess`));
    mixin(VERIFY_FENCE_OR_NONE!(`idle_fence`, `req_idle_fence`, `client`, `DixWriteAccess`));

    if (req_options & ~(PresentAllOptions)) {
        client.errorValue = cast(uint)req_options;
        return BadValue;
    }

    /*
     * Check to see if remainder is sane
     */
    if (req_divisor == 0) {
        if (req_remainder != 0) {
            client.errorValue = cast(uint)cast(CARD32)req_remainder;
            return BadValue;
        }
    } else {
        if (req_remainder >= req_divisor) {
            client.errorValue = cast(uint)cast(CARD32)req_remainder;
            return BadValue;
        }
    }

    nnotifies = cast(int)((client.req_len << 2) - base_req_size);
    if (nnotifies % xPresentNotify.sizeof)
        return BadLength;

    nnotifies /= xPresentNotify.sizeof;
    if (nnotifies) {
        ret = present_create_notifies(client, nnotifies, req_notifies, &notifies);
        if (ret != Success)
            return ret;
    }

    ret = present_pixmap(window, pixmap, req_serial,
        valid, update, req_x_off, req_y_off, target_crtc,
        wait_fence, idle_fence,
        cast(int)req_options, req_target_msc, req_divisor, req_remainder,
        notifies, nnotifies);

    if (ret != Success)
        present_destroy_notifies(notifies, nnotifies);
    return ret;
}
}

private int proc_present_pixmap(ClientPtr client)
{
    mixin(REQUEST!xPresentPixmapReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentPixmapReq);

    static if(DRI3) {
        return proc_present_pixmap_common(client, stuff.window, stuff.pixmap, stuff.serial,
                                    stuff.valid, stuff.update, stuff.x_off, stuff.y_off,
                                    stuff.target_crtc,
                                    stuff.wait_fence, stuff.idle_fence,
// #ifdef DRI3
                                    null, null, 0, 0,
// #endif /* DRI3 */
                                    stuff.options, stuff.target_msc,
                                    stuff.divisor, stuff.remainder,
                                    xPresentPixmapReq.sizeof,
                                    cast(xPresentNotify*)(stuff + 1));
    }
    else {

        return proc_present_pixmap_common(client, stuff.window, stuff.pixmap, stuff.serial,
                                        stuff.valid, stuff.update, stuff.x_off, stuff.y_off,
                                        stuff.target_crtc,
                                        stuff.wait_fence, stuff.idle_fence,
                                        stuff.options, stuff.target_msc,
                                        stuff.divisor, stuff.remainder,
                                        xPresentPixmapReq.sizeof,
                                        cast(xPresentNotify*)(stuff + 1));
    }
}

private int proc_present_notify_msc(ClientPtr client)
{
    mixin(REQUEST!xPresentNotifyMSCReq);
    WindowPtr window = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xPresentNotifyMSCReq);
    rc = dixLookupWindow(&window, stuff.window, client, DixReadAccess);
    if (rc != Success)
        return rc;

    /*
     * Check to see if remainder is sane
     */
    if (stuff.divisor == 0) {
        if (stuff.remainder != 0) {
            client.errorValue = cast(uint)cast(CARD32) stuff.remainder;
            return BadValue;
        }
    } else {
        if (stuff.remainder >= stuff.divisor) {
            client.errorValue = cast(uint)cast(CARD32) stuff.remainder;
            return BadValue;
        }
    }

    return present_notify_msc(window, stuff.serial,
                              stuff.target_msc, stuff.divisor, stuff.remainder);
}

private int proc_present_select_input(ClientPtr client)
{
    mixin(REQUEST!xPresentSelectInputReq);
    WindowPtr window = void;
    int rc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xPresentSelectInputReq);

    rc = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    if (stuff.eventMask & ~PresentAllEvents) {
        client.errorValue = cast(uint)stuff.eventMask;
        return BadValue;
    }
    return present_select_input(client, stuff.eid, window, stuff.eventMask);
}

private int proc_present_query_capabilities(ClientPtr client)
{
    mixin(REQUEST!xPresentQueryCapabilitiesReq);
    WindowPtr window = void;
    RRCrtcPtr crtc = null;
    int r = void;

    mixin(REQUEST_AT_LEAST_SIZE!xPresentQueryCapabilitiesReq);
    r = dixLookupWindow(&window, stuff.target, client, DixGetAttrAccess);
    switch (r) {
    case Success:
        crtc = present_get_crtc(window);
        break;
    case BadWindow:
        mixin(VERIFY_RR_CRTC!("stuff.target", "crtc", "DixGetAttrAccess"));
        break;
    default:
        return r;
    }

    xPresentQueryCapabilitiesReply reply = {
        capabilities: present_query_capabilities(crtc)
    };

    if (client.swapped) {
        swapl(&reply.capabilities);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

static if(DRI3){
private int proc_present_pixmap_synced(ClientPtr client)
{
    mixin(REQUEST!xPresentPixmapSyncedReq);
    dri3_syncobj* acquire_syncobj = void;
    dri3_syncobj* release_syncobj = void;

    mixin(REQUEST_AT_LEAST_SIZE!xPresentPixmapSyncedReq);
    mixin(VERIFY_DRI3_SYNCOBJ!("stuff.acquire_syncobj", "acquire_syncobj", "DixWriteAccess"));
    mixin(VERIFY_DRI3_SYNCOBJ!("stuff.release_syncobj", "release_syncobj", "DixWriteAccess"));

    if (stuff.acquire_point == 0 || stuff.release_point == 0 ||
        (stuff.acquire_syncobj == stuff.release_syncobj &&
         stuff.acquire_point >= stuff.release_point))
        return BadValue;

    return proc_present_pixmap_common(client, stuff.window, stuff.pixmap, stuff.serial,
                                      stuff.valid, stuff.update, stuff.x_off, stuff.y_off,
                                      stuff.target_crtc,
                                      None, None,
                                      acquire_syncobj, release_syncobj,
                                      stuff.acquire_point, stuff.release_point,
                                      stuff.options, stuff.target_msc,
                                      stuff.divisor, stuff.remainder,
                                      xPresentPixmapSyncedReq.sizeof,
                                      cast(xPresentNotify*)(stuff + 1));
}
} /* DRI3 */

int proc_present_dispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
        case X_PresentQueryVersion:
            return proc_present_query_version(client);
        case X_PresentPixmap:
            return proc_present_pixmap(client);
        case X_PresentNotifyMSC:
            return proc_present_notify_msc(client);
        case X_PresentSelectInput:
            return proc_present_select_input(client);
        case X_PresentQueryCapabilities:
            return proc_present_query_capabilities(client);
static if(DRI3){
        case X_PresentPixmapSynced:
            return proc_present_pixmap_synced(client);
}
    default: break;}

    return BadRequest;
}

private int sproc_present_query_version(ClientPtr client)
{
    mixin(REQUEST!xPresentQueryVersionReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentQueryVersionReq);

    swapl(&stuff.majorVersion);
    swapl(&stuff.minorVersion);
    return proc_present_query_version(client);
}

private int sproc_present_pixmap(ClientPtr client)
{
    mixin(REQUEST!xPresentPixmapReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentPixmapReq);

    swapl(&stuff.window);
    swapl(&stuff.pixmap);
    swapl(&stuff.serial);
    swapl(&stuff.valid);
    swapl(&stuff.update);
    swaps(&stuff.x_off);
    swaps(&stuff.y_off);
    swapl(&stuff.target_crtc);
    swapl(&stuff.wait_fence);
    swapl(&stuff.options);
    swapll(&stuff.target_msc);
    swapll(&stuff.divisor);
    swapll(&stuff.remainder);
    swapl(&stuff.idle_fence);
    return proc_present_pixmap(client);
}

private int sproc_present_notify_msc(ClientPtr client)
{
    mixin(REQUEST!xPresentNotifyMSCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentNotifyMSCReq);

    swapl(&stuff.window);
    swapll(&stuff.target_msc);
    swapll(&stuff.divisor);
    swapll(&stuff.remainder);
    return proc_present_notify_msc(client);
}

private int sproc_present_select_input(ClientPtr client)
{
    mixin(REQUEST!xPresentSelectInputReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentSelectInputReq);

    swapl(&stuff.eid);
    swapl(&stuff.window);
    swapl(&stuff.eventMask);
    return proc_present_select_input(client);
}

private int sproc_present_query_capabilities(ClientPtr client)
{
    mixin(REQUEST!xPresentQueryCapabilitiesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentQueryCapabilitiesReq);
    swapl(&stuff.target);
    return proc_present_query_capabilities(client);
}


static if(DRI3){
private int sproc_present_pixmap_synced(ClientPtr client)
{
    mixin(REQUEST!xPresentPixmapSyncedReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPresentPixmapSyncedReq);

    swapl(&stuff.window);

    swapl(&stuff.pixmap);
    swapl(&stuff.serial);

    swapl(&stuff.valid);
    swapl(&stuff.update);

    swaps(&stuff.x_off);
    swaps(&stuff.y_off);
    swapl(&stuff.target_crtc);

    swapl(&stuff.acquire_syncobj);
    swapl(&stuff.release_syncobj);
    swapll(&stuff.acquire_point);
    swapll(&stuff.release_point);

    swapl(&stuff.options);

    swapll(&stuff.target_msc);
    swapll(&stuff.divisor);
    swapll(&stuff.remainder);
    return proc_present_pixmap_synced(client);
}
} /* DRI3 */

int sproc_present_dispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
        case X_PresentQueryVersion:
            return sproc_present_query_version(client);
        case X_PresentPixmap:
            return sproc_present_pixmap(client);
        case X_PresentNotifyMSC:
            return sproc_present_notify_msc(client);
        case X_PresentSelectInput:
            return sproc_present_select_input(client);
        case X_PresentQueryCapabilities:
            return sproc_present_query_capabilities(client);
static if(DRI3){
        case X_PresentPixmapSynced:
            return sproc_present_pixmap_synced(client);
}
    default: break;}

    return BadRequest;
}
