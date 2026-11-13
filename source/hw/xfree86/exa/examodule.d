module hw.xfree86.exa.examodule;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2006 Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Authors:
 *    Eric Anholt <anholt@FreeBSD.org>
 *
 */
import build.xorg_config;
import build.xlibre_server;

import core.stdc.string;

import dix.screen_hooks;

import exa.exa_priv;

import hw.xfree86.common.xf86str;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.common.xf86Option;
import hw.xfree86.parser.Flags;
import exa.exa_offscreen;

struct _ExaXorgScreenPrivRec {
    xf86EnableDisableFBAccessProc* SavedEnableDisableFBAccess;
    OptionInfoPtr options;
}alias ExaXorgScreenPrivRec = _ExaXorgScreenPrivRec;
alias ExaXorgScreenPrivPtr = _ExaXorgScreenPrivRec*;

private DevPrivateKeyRec exaXorgScreenPrivateKeyRec;

enum exaXorgScreenPrivateKey = (&exaXorgScreenPrivateKeyRec);

enum EXAOpts {
    EXAOPT_MIGRATION_HEURISTIC,
    EXAOPT_NO_COMPOSITE,
    EXAOPT_NO_UTS,
    EXAOPT_NO_DFS,
    EXAOPT_OPTIMIZE_MIGRATION
}
alias EXAOPT_MIGRATION_HEURISTIC = EXAOpts.EXAOPT_MIGRATION_HEURISTIC;
alias EXAOPT_NO_COMPOSITE = EXAOpts.EXAOPT_NO_COMPOSITE;
alias EXAOPT_NO_UTS = EXAOpts.EXAOPT_NO_UTS;
alias EXAOPT_NO_DFS = EXAOpts.EXAOPT_NO_DFS;
alias EXAOPT_OPTIMIZE_MIGRATION = EXAOpts.EXAOPT_OPTIMIZE_MIGRATION;


private const(OptionInfoRec)[6] EXAOptions = [
    {EXAOPT_MIGRATION_HEURISTIC, "MigrationHeuristic",
     OPTV_ANYSTR, {0}, False},
    {EXAOPT_NO_COMPOSITE, "EXANoComposite",
     OPTV_BOOLEAN, {0}, False},
    {EXAOPT_NO_UTS, "EXANoUploadToScreen",
     OPTV_BOOLEAN, {0}, False},
    {EXAOPT_NO_DFS, "EXANoDownloadFromScreen",
     OPTV_BOOLEAN, {0}, False},
    {EXAOPT_OPTIMIZE_MIGRATION, "EXAOptimizeMigration",
     OPTV_BOOLEAN, {0}, False},
    {-1, null,
     OPTV_NONE, {0}, False}
];

private void exaXorgCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    ExaXorgScreenPrivPtr pScreenPriv = cast(ExaXorgScreenPrivPtr)
        dixLookupPrivate(&pScreen.devPrivates, exaXorgScreenPrivateKey);

    dixScreenUnhookClose(pScreen, &exaXorgCloseScreen);

    if (!pScrn)
        return;

    pScrn.EnableDisableFBAccess = *pScreenPriv.SavedEnableDisableFBAccess;

    free(pScreenPriv.options);
    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, exaXorgScreenPrivateKey, null);
}

private void exaXorgEnableDisableFBAccess(ScrnInfoPtr pScrn, Bool enable)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    ExaXorgScreenPrivPtr pScreenPriv = cast(ExaXorgScreenPrivPtr)
        dixLookupPrivate(&pScreen.devPrivates, exaXorgScreenPrivateKey);

    if (!enable)
        exaEnableDisableFBAccess(pScreen, enable);

    if (pScreenPriv.SavedEnableDisableFBAccess !is null)
        (*pScreenPriv.SavedEnableDisableFBAccess)(pScrn, enable);

    if (enable)
        exaEnableDisableFBAccess(pScreen, enable);
}

/**
 * This will be called during exaDriverInit, giving us the chance to set options
 * and hook in our EnableDisableFBAccess.
 */
void exaDDXDriverInit(ScreenPtr pScreen)
{
    mixin(ExaScreenPriv!("pScreen"));
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    ExaXorgScreenPrivPtr pScreenPriv = void;

    if (!dixRegisterPrivateKey(&exaXorgScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return;

    pScreenPriv = cast(ExaXorgScreenPrivRec*) calloc(1, ExaXorgScreenPrivRec.sizeof);
    if (pScreenPriv is null)
        return;

    pScreenPriv.options = cast(_OptionInfoRec*)XNFalloc(EXAOptions.sizeof);
    memcpy(pScreenPriv.options, EXAOptions.ptr, EXAOptions.sizeof);
    xf86ProcessOptions(pScrn.scrnIndex, cast(_InputOption*)pScrn.options, pScreenPriv.options);

    if (pExaScr.info.flags & EXA_OFFSCREEN_PIXMAPS) {
        if (!(pExaScr.info.flags & EXA_HANDLES_PIXMAPS) &&
            pExaScr.info.offScreenBase < pExaScr.info.memorySize) {
            const(char)* heuristicName = void;

            heuristicName = xf86GetOptValString(pScreenPriv.options,
                                                EXAOPT_MIGRATION_HEURISTIC);
            if (heuristicName !is null) {
                if (strcmp(heuristicName, "greedy") == 0)
                    pExaScr.migration = ExaMigrationGreedy;
                else if (strcmp(heuristicName, "always") == 0)
                    pExaScr.migration = ExaMigrationAlways;
                else if (strcmp(heuristicName, "smart") == 0)
                    pExaScr.migration = ExaMigrationSmart;
                else {
                    xf86DrvMsg(pScreen.myNum, X_WARNING,
                               "EXA: unknown migration heuristic %s\n",
                               heuristicName);
                }
            }
        }

        pExaScr.optimize_migration =
            xf86ReturnOptValBool(pScreenPriv.options,
                                 EXAOPT_OPTIMIZE_MIGRATION, True);
    }

    if (xf86ReturnOptValBool(pScreenPriv.options, EXAOPT_NO_COMPOSITE, False)) {
        xf86DrvMsg(pScreen.myNum, X_CONFIG,
                   "EXA: Disabling Composite operation "
                   ~ "(RENDER acceleration)\n");
        pExaScr.info.CheckComposite = null;
        pExaScr.info.PrepareComposite = null;
    }

    if (xf86ReturnOptValBool(pScreenPriv.options, EXAOPT_NO_UTS, False)) {
        xf86DrvMsg(pScreen.myNum, X_CONFIG, "EXA: Disabling UploadToScreen\n");
        pExaScr.info.UploadToScreen = null;
    }

    if (xf86ReturnOptValBool(pScreenPriv.options, EXAOPT_NO_DFS, False)) {
        xf86DrvMsg(pScreen.myNum, X_CONFIG,
                   "EXA: Disabling DownloadFromScreen\n");
        pExaScr.info.DownloadFromScreen = null;
    }

    dixSetPrivate(&pScreen.devPrivates, exaXorgScreenPrivateKey, pScreenPriv);

    pScreenPriv.SavedEnableDisableFBAccess = &pScrn.EnableDisableFBAccess;
    pScrn.EnableDisableFBAccess = &exaXorgEnableDisableFBAccess;

    dixScreenHookClose(pScreen, &exaXorgCloseScreen);
}

private XF86ModuleVersionInfo exaVersRec = {
    modname: "exa",
    vendor: MODULEVENDORSTRING,
    _modinfo1_: MODINFOSTRING1,
    _modinfo2_: MODINFOSTRING2,
    xf86version: XORG_VERSION_CURRENT,
    majorversion: EXA_VERSION_MAJOR,
    minorversion: EXA_VERSION_MINOR,
    patchlevel: EXA_VERSION_RELEASE,
    abiclass: ABI_CLASS_VIDEODRV,
    abiversion: ABI_VIDEODRV_VERSION,
};

XF86ModuleData exaModuleData = {
    vers: &exaVersRec
};
