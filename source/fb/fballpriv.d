module fb.fballpriv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 1998 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import fb.fb_priv;
import fb.fb;

private DevPrivateKeyRec fbScreenPrivateKeyRec;

DevPrivateKey fbGetScreenPrivateKey()
{
    return &fbScreenPrivateKeyRec;
}

DevPrivateKey fbGetGCPrivateKey(GCPtr pGC)
{
    return &mixin(fbGetScreenPrivate!("(pGC).pScreen")).gcPrivateKeyRec;
}

Bool fbAllocatePrivates(ScreenPtr pScreen)
{
    FbScreenPrivPtr pScrPriv = void;

    if (!dixRegisterPrivateKey
        (&fbScreenPrivateKeyRec, PRIVATE_SCREEN, FbScreenPrivRec.sizeof))
        return FALSE;

    pScrPriv = mixin(fbGetScreenPrivate!("pScreen"));

    if (!dixRegisterScreenSpecificPrivateKey (pScreen, &pScrPriv.gcPrivateKeyRec, PRIVATE_GC, FbGCPrivRec.sizeof))
        return FALSE;
    if (!dixRegisterScreenSpecificPrivateKey (pScreen, &pScrPriv.winPrivateKeyRec, PRIVATE_WINDOW, 0))
        return FALSE;

    return TRUE;
}
import build.xorg_config;

static if (FB_ACCESS_WRAPPER) {
ReadMemoryProcPtr wfbReadMemory;
WriteMemoryProcPtr wfbWriteMemory;
}
