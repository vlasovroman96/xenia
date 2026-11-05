module miext.sync.misyncfd;
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

import dix.input_priv;

import include.scrnintstr;
import miext.sync.misync_priv;
// import miext.sync.misync_priv;
import miext.sync.misyncfd;
import include.pixmapstr;
import mi.misyncfd;
import miext.sync.misync;


private DevPrivateKeyRec syncFdScreenPrivateKey;

struct _SyncFdScreenPrivate {
    SyncFdScreenFuncsRec funcs;
}alias SyncFdScreenPrivateRec = _SyncFdScreenPrivate;
alias SyncFdScreenPrivatePtr = _SyncFdScreenPrivate*;

pragma(inline, true) private SyncFdScreenPrivatePtr sync_fd_screen_priv(ScreenPtr pScreen)
{
    if (!dixPrivateKeyRegistered(&syncFdScreenPrivateKey))
        return null;
    return cast(SyncFdScreenPrivatePtr)dixLookupPrivate(&pScreen.devPrivates, &syncFdScreenPrivateKey);
}

int miSyncInitFenceFromFD(DrawablePtr pDraw, SyncFence* pFence, int fd, BOOL initially_triggered)

{
    SyncFdScreenPrivatePtr priv = sync_fd_screen_priv(pDraw.pScreen);

    if (!priv)
        return BadMatch;

    return (*priv.funcs.CreateFenceFromFd)(pDraw.pScreen, pFence, fd, initially_triggered);
}

int miSyncFDFromFence(DrawablePtr pDraw, SyncFence* pFence)
{
    SyncFdScreenPrivatePtr priv = sync_fd_screen_priv(pDraw.pScreen);

    if (!priv)
        return -1;

    return (*priv.funcs.GetFenceFd)(pDraw.pScreen, pFence);
}

Bool miSyncFdScreenInit(ScreenPtr pScreen, const(SyncFdScreenFuncsRec)* funcs)
{
    SyncFdScreenPrivatePtr priv = void;

    /* Check to see if we've already been initialized */
    if (sync_fd_screen_priv(pScreen) !is null)
        return FALSE;

    if (!miSyncSetup(pScreen))
        return FALSE;

    if (!dixPrivateKeyRegistered(&syncFdScreenPrivateKey)) {
        if (!dixRegisterPrivateKey(&syncFdScreenPrivateKey, PRIVATE_SCREEN, 0))
            return FALSE;
    }

    priv = cast(SyncFdScreenPrivateRec*) calloc(1, SyncFdScreenPrivateRec.sizeof);
    if (!priv)
        return FALSE;

    /* Will require version checks when there are multiple versions
     * of the funcs structure
     */

    priv.funcs = *funcs;

    dixSetPrivate(&pScreen.devPrivates, &syncFdScreenPrivateKey, priv);

    return TRUE;
}
