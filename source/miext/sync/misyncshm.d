module miext.sync.misyncshm;;
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

import core.sys.posix.fcntl;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import Xext.xshmfence;

import os.osdep;

import include.scrnintstr;
// import mi.misync_priv;
import miext.sync.misync_priv;
import miext.sync.misyncshm;
import miext.sync.misyncfd;
import dix.pixmap;
import mi.misyncfd;
import miext.sync.misync;


private DevPrivateKeyRec syncShmFencePrivateKey;

struct _SyncShmFencePrivate {
    xshmfence* fence;
    int fd;
}alias SyncShmFencePrivateRec = _SyncShmFencePrivate;
alias SyncShmFencePrivatePtr = _SyncShmFencePrivate*;

enum string SYNC_FENCE_PRIV(string pFence) = `
    cast(SyncShmFencePrivatePtr) dixLookupPrivate(&` ~ pFence ~ `.devPrivates, &syncShmFencePrivateKey)`;

private void miSyncShmFenceSetTriggered(SyncFence* pFence)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    if (pPriv.fence)
        xshmfence_trigger(pPriv.fence);
    miSyncFenceSetTriggered(pFence);
}

private void miSyncShmFenceReset(SyncFence* pFence)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    if (pPriv.fence)
        xshmfence_reset(pPriv.fence);
    miSyncFenceReset(pFence);
}

private Bool miSyncShmFenceCheckTriggered(SyncFence* pFence)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    if (pPriv.fence)
        return xshmfence_query(pPriv.fence);
    else
        return miSyncFenceCheckTriggered(pFence);
}

private void miSyncShmFenceAddTrigger(SyncTrigger* pTrigger)
{
    miSyncFenceAddTrigger(pTrigger);
}

private void miSyncShmFenceDeleteTrigger(SyncTrigger* pTrigger)
{
    miSyncFenceDeleteTrigger(pTrigger);
}

private const(SyncFenceFuncsRec) miSyncShmFenceFuncs = {
    &miSyncShmFenceSetTriggered,
    &miSyncShmFenceReset,
    &miSyncShmFenceCheckTriggered,
    &miSyncShmFenceAddTrigger,
    &miSyncShmFenceDeleteTrigger
};

private void miSyncShmScreenCreateFence(ScreenPtr pScreen, SyncFence* pFence, Bool initially_triggered)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    pPriv.fence = null;
    miSyncScreenCreateFence(pScreen, pFence, initially_triggered);
    pFence.funcs = miSyncShmFenceFuncs;
}

private void miSyncShmScreenDestroyFence(ScreenPtr pScreen, SyncFence* pFence)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    if (pPriv.fence) {
        xshmfence_trigger(pPriv.fence);
        xshmfence_unmap_shm(pPriv.fence);
        close(pPriv.fd);
    }
    miSyncScreenDestroyFence(pScreen, pFence);
}

private int miSyncShmCreateFenceFromFd(ScreenPtr pScreen, SyncFence* pFence, int fd, Bool initially_triggered)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    miSyncInitFence(pScreen, pFence, initially_triggered);

    fd = os_move_fd(fd);
    pPriv.fence = xshmfence_map_shm(fd);
    if (pPriv.fence) {
        pPriv.fd = fd;
        return Success;
    }
    else
        close(fd);
    return BadValue;
}

private int miSyncShmGetFenceFd(ScreenPtr pScreen, SyncFence* pFence)
{
    SyncShmFencePrivatePtr pPriv = mixin(SYNC_FENCE_PRIV!(`pFence`));

    if (!pPriv.fence) {
        pPriv.fd = xshmfence_alloc_shm();
        if (pPriv.fd < 0)
            return -1;
        pPriv.fd = os_move_fd(pPriv.fd);
        pPriv.fence = xshmfence_map_shm(pPriv.fd);
        if (!pPriv.fence) {
            close (pPriv.fd);
            return -1;
        }
    }
    return pPriv.fd;
}

private const(SyncFdScreenFuncsRec) miSyncShmScreenFuncs = {
    version_: SYNC_FD_SCREEN_FUNCS_VERSION,
    CreateFenceFromFd: &miSyncShmCreateFenceFromFd,
    GetFenceFd: &miSyncShmGetFenceFd
};

Bool miSyncShmScreenInit(ScreenPtr pScreen)
{
    SyncScreenFuncsPtr funcs = void;

    if (!miSyncFdScreenInit(pScreen, &miSyncShmScreenFuncs))
        return FALSE;

    if (!dixPrivateKeyRegistered(&syncShmFencePrivateKey)) {
        if (!dixRegisterPrivateKey(&syncShmFencePrivateKey, PRIVATE_SYNC_FENCE,
                                   SyncShmFencePrivateRec.sizeof))
            return FALSE;
    }

    funcs = miSyncGetScreenFuncs(pScreen);

    funcs.CreateFence = &miSyncShmScreenCreateFence;
    funcs.DestroyFence = &miSyncShmScreenDestroyFence;

    return TRUE;
}

