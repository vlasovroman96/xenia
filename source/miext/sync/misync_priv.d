module miext.sync.misync_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2010 NVIDIA Corporation
 */
 
public import mi.misync;

import dix.privates;
import dix.pixmap;


// DevPrivateKeyRec miSyncScreenPrivateKey;
import miext.sync.misync;

struct _syncScreenPriv {
    /* Wrappable sync-specific screen functions */
    SyncScreenFuncsRec funcs;
}alias SyncScreenPrivRec = _syncScreenPriv;
alias SyncScreenPrivPtr = _syncScreenPriv*;

enum string SYNC_SCREEN_PRIV(string pScreen) = `
    cast(SyncScreenPrivPtr) dixLookupPrivate(&` ~ pScreen ~ `.devPrivates, 
                                         &miSyncScreenPrivateKey)`;

// Bool miSyncFenceCheckTriggered(SyncFence* pFence);
// void miSyncFenceSetTriggered(SyncFence* pFence);
// void miSyncFenceReset(SyncFence* pFence);
// void miSyncFenceAddTrigger(SyncTrigger* pTrigger);
// void miSyncFenceDeleteTrigger(SyncTrigger* pTrigger);
int miSyncInitFenceFromFD(DrawablePtr pDraw, SyncFence* pFence, int fd, BOOL initially_triggered);
int miSyncFDFromFence(DrawablePtr pDraw, SyncFence* pFence);

 /* _XSERVER_MISYNC_PRIV_H */
