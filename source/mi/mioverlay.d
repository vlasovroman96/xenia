module mioverlay;
@nogc nothrow:
extern(C): __gshared:

import build.dix_config;

//import x11.X;
//import x11.Xmd;
// //import externs.X11.extensions.shapeproto;

import dix.cursor_priv;
import dix.dix_priv;
import dix.screen_hooks_priv;
import dix.screensaver_priv;
import dix.window_priv;
import mi.mi_priv;

import include.scrnintstr;
import include.validate;
import include.windowstr;
import dix.gc;
import region;
import dix.privates;
import mioverlay;
import migc;

import mioverlay;
import dix.screen_hooks;
import dix.events;
import externs.X11.extensions.shapeconst;
import mi.mivaltree;
import dix.window;

alias miOverlayTransFunc = void function(ScreenPtr, int, BoxPtr);
alias miOverlayInOverlayFunc = Bool function(WindowPtr);

void  miInitOverlay(ScreenPtr pScreen, miOverlayInOverlayFunc inOverlay, miOverlayTransFunc trans);

void  miOverlayGetPrivateClips(WindowPtr pWin, RegionPtr* borderClip, RegionPtr* clipList);

void  miOverlayCollectUnderlayRegions(WindowPtr, RegionPtr*);
void  miOverlayComputeCompositeClip(GCPtr, WindowPtr);
void  miOverlayCopyUnderlay(ScreenPtr);
void  miOverlaySetRootClip(ScreenPtr, Bool);

struct _MiOverlayValDataRec {
    RegionRec exposed;
    RegionRec borderExposed;
    RegionPtr borderVisible;
    xPoint oldAbsCorner;
}alias miOverlayValDataRec = _MiOverlayValDataRec;
alias miOverlayValDataPtr = miOverlayValDataRec*;

struct _TreeRec {
    WindowPtr pWin;
    _TreeRec* parent;
    _TreeRec* firstChild;
    _TreeRec* lastChild;
    _TreeRec* prevSib;
    _TreeRec* nextSib;
    RegionRec borderClip;
    RegionRec clipList;
    uint visibility;
    miOverlayValDataPtr valdata;
}alias miOverlayTreeRec = _TreeRec;
alias miOverlayTreePtr = _TreeRec*;

struct _MiOverlayWindowRec {
    miOverlayTreePtr tree;
}alias miOverlayWindowRec = _MiOverlayWindowRec;
alias miOverlayWindowPtr = miOverlayWindowRec*;

struct _MiOverlayScreenRec {
    CreateWindowProcPtr CreateWindow;
    DestroyWindowProcPtr DestroyWindow;
    UnrealizeWindowProcPtr UnrealizeWindow;
    RealizeWindowProcPtr RealizeWindow;
    miOverlayTransFunc MakeTransparent;
    miOverlayInOverlayFunc InOverlay;
    Bool underlayMarked;
    Bool copyUnderlay;
}alias miOverlayScreenRec = _MiOverlayScreenRec;
alias miOverlayScreenPtr = miOverlayScreenRec*;

private DevPrivateKeyRec miOverlayWindowKeyRec;

enum miOverlayWindowKey = (&miOverlayWindowKeyRec);
private DevPrivateKeyRec miOverlayScreenKeyRec;

enum miOverlayScreenKey = (&miOverlayScreenKeyRec);


























enum string MIOVERLAY_GET_SCREEN_PRIVATE(string pScreen) = `(cast(miOverlayScreenPtr) 
	dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, miOverlayScreenKey))`;
enum string MIOVERLAY_GET_WINDOW_PRIVATE(string pWin) = `(cast(miOverlayWindowPtr) 
	dixLookupPrivate(&(` ~ pWin ~ `).devPrivates, miOverlayWindowKey))`;
enum string MIOVERLAY_GET_WINDOW_TREE(string pWin) = `
	(` ~ MIOVERLAY_GET_WINDOW_PRIVATE!(pWin) ~ `.tree)`;

enum string IN_UNDERLAY(string w) = MIOVERLAY_GET_WINDOW_TREE!(w);
enum string IN_OVERLAY(string w) = `!` ~ MIOVERLAY_GET_WINDOW_TREE!(w);

enum string MARK_OVERLAY(string w) = `miMarkWindow(`~w~`)`;
enum string MARK_UNDERLAY(string w) = `MarkUnderlayWindow(`~w~`)`;

enum string HasParentRelativeBorder(string w) = `(!(` ~ w ~ `).borderIsPixel && 
                                    `~HasBorder!(w)~` && 
                                    (` ~ w ~ `).backgroundState == ParentRelative)`;

Bool miInitOverlay(ScreenPtr pScreen, miOverlayInOverlayFunc inOverlayFunc, miOverlayTransFunc transFunc)
{
    miOverlayScreenPtr pScreenPriv = void;

    if (!inOverlayFunc || !transFunc)
        return FALSE;

    if (!dixRegisterPrivateKey
        (&miOverlayWindowKeyRec, PRIVATE_WINDOW, miOverlayWindowRec.sizeof))
        return FALSE;

    if (!dixRegisterPrivateKey(&miOverlayScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (((pScreenPriv = cast(miOverlayScreenRec*) calloc(1, miOverlayScreenRec.sizeof)) is null))
        return FALSE;

    dixSetPrivate(&pScreen.devPrivates, miOverlayScreenKey, pScreenPriv);
    dixScreenHookClose(pScreen, &miOverlayCloseScreen);

    pScreenPriv.InOverlay = inOverlayFunc;
    pScreenPriv.MakeTransparent = transFunc;
    pScreenPriv.underlayMarked = FALSE;

    pScreenPriv.CreateWindow = pScreen.CreateWindow;
    pScreenPriv.DestroyWindow = pScreen.DestroyWindow;
    pScreenPriv.UnrealizeWindow = pScreen.UnrealizeWindow;
    pScreenPriv.RealizeWindow = pScreen.RealizeWindow;

    pScreen.CreateWindow = &miOverlayCreateWindow;
    pScreen.DestroyWindow = &miOverlayDestroyWindow;
    pScreen.UnrealizeWindow = &miOverlayUnrealizeWindow;
    pScreen.RealizeWindow = &miOverlayRealizeWindow;

    pScreen.ReparentWindow = &miOverlayReparentWindow;
    pScreen.RestackWindow = &miOverlayRestackWindow;
    pScreen.MarkOverlappedWindows = &miOverlayMarkOverlappedWindows;
    pScreen.MarkUnrealizedWindow = &miOverlayMarkUnrealizedWindow;
    pScreen.ValidateTree = &miOverlayValidateTree;
    pScreen.HandleExposures = &miOverlayHandleExposures;
    pScreen.MoveWindow = &miOverlayMoveWindow;
    pScreen.WindowExposures = &miOverlayWindowExposures;
    pScreen.ResizeWindow = &miOverlayResizeWindow;
    pScreen.MarkWindow = &miOverlayMarkWindow;
    pScreen.ClearToBackground = &miOverlayClearToBackground;
    pScreen.SetShape = &miOverlaySetShape;
    pScreen.ChangeBorderWidth = &miOverlayChangeBorderWidth;

    return TRUE;
}

private void miOverlayCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookClose(pScreen, &miOverlayCloseScreen);

    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    if (!pScreenPriv)
        return;

    pScreen.CreateWindow = pScreenPriv.CreateWindow;
    pScreen.DestroyWindow = pScreenPriv.DestroyWindow;
    pScreen.UnrealizeWindow = pScreenPriv.UnrealizeWindow;
    pScreen.RealizeWindow = pScreenPriv.RealizeWindow;

    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, miOverlayScreenKey, null);
}

private Bool miOverlayCreateWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    miOverlayWindowPtr pWinPriv = mixin(MIOVERLAY_GET_WINDOW_PRIVATE!(`pWin`));
    miOverlayTreePtr pTree = null;
    Bool result = TRUE;

    pWinPriv.tree = null;

    if (!pWin.parent || !((*pScreenPriv.InOverlay) (pWin))) {
        if (((pTree = cast(miOverlayTreePtr) cast(miOverlayTreeRec*) calloc(1, miOverlayTreeRec.sizeof)) is null))
            return FALSE;
    }

    if (pScreenPriv.CreateWindow) {
        pScreen.CreateWindow = pScreenPriv.CreateWindow;
        result = (*pScreen.CreateWindow) (pWin);
        pScreen.CreateWindow = &miOverlayCreateWindow;
    }

    if (pTree) {
        if (result) {
            pTree.pWin = pWin;
            pTree.visibility = VisibilityNotViewable;
            pWinPriv.tree = pTree;
            if (pWin.parent) {
                RegionNull(&(pTree.borderClip));
                RegionNull(&(pTree.clipList));
                RebuildTree(pWin);
            }
            else {
                BoxRec fullBox = void;

                fullBox.x1 = 0;
                fullBox.y1 = 0;
                fullBox.x2 = pScreen.width;
                fullBox.y2 = pScreen.height;
                RegionInit(&(pTree.borderClip), &fullBox, 1);
                RegionInit(&(pTree.clipList), &fullBox, 1);
            }
        }
        else
            free(pTree);
    }

    return TRUE;
}

private Bool miOverlayDestroyWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    Bool result = TRUE;

    if (pTree) {
        if (pTree.prevSib)
            pTree.prevSib.nextSib = pTree.nextSib;
        else if (pTree.parent)
            pTree.parent.firstChild = pTree.nextSib;

        if (pTree.nextSib)
            pTree.nextSib.prevSib = pTree.prevSib;
        else if (pTree.parent)
            pTree.parent.lastChild = pTree.prevSib;

        RegionUninit(&(pTree.borderClip));
        RegionUninit(&(pTree.clipList));
        free(pTree);
    }

    if (pScreenPriv.DestroyWindow) {
        pScreen.DestroyWindow = pScreenPriv.DestroyWindow;
        result = (*pScreen.DestroyWindow) (pWin);
        pScreen.DestroyWindow = &miOverlayDestroyWindow;
    }

    return result;
}

private Bool miOverlayUnrealizeWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    Bool result = TRUE;

    if (pTree)
        pTree.visibility = VisibilityNotViewable;

    if (pScreenPriv.UnrealizeWindow) {
        pScreen.UnrealizeWindow = pScreenPriv.UnrealizeWindow;
        result = (*pScreen.UnrealizeWindow) (pWin);
        pScreen.UnrealizeWindow = &miOverlayUnrealizeWindow;
    }

    return result;
}

private Bool miOverlayRealizeWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    Bool result = TRUE;

    if (pScreenPriv.RealizeWindow) {
        pScreen.RealizeWindow = pScreenPriv.RealizeWindow;
        result = (*pScreen.RealizeWindow) (pWin);
        pScreen.RealizeWindow = &miOverlayRealizeWindow;
    }

    /* we only need to catch the root window realization */

    if (result && !pWin.parent && !((*pScreenPriv.InOverlay) (pWin))) {
        BoxRec box = void;

        box.x1 = box.y1 = 0;
        box.x2 = pWin.drawable.width;
        box.y2 = pWin.drawable.height;
        (*pScreenPriv.MakeTransparent) (pScreen, 1, &box);
    }

    return result;
}

private void miOverlayReparentWindow(WindowPtr pWin, WindowPtr pPriorParent)
{
    if (mixin(IN_UNDERLAY!(`pWin`)) || HasUnderlayChildren(pWin)) {
        /* This could probably be more optimal */
        RebuildTree(pWin.drawable.pScreen.root.firstChild);
    }
}

private void miOverlayRestackWindow(WindowPtr pWin, WindowPtr oldNextSib)
{
    if (mixin(IN_UNDERLAY!(`pWin`)) || HasUnderlayChildren(pWin)) {
        /* This could probably be more optimal */
        RebuildTree(pWin);
    }
}

private Bool miOverlayMarkOverlappedWindows(WindowPtr pWin, WindowPtr pFirst, WindowPtr* pLayerWin)
{
    WindowPtr pChild = void, pLast = void;
    Bool overMarked = void, underMarked = void, doUnderlay = void, markAll = void;
    miOverlayTreePtr pTree = null, tLast = void, tChild = void;
    BoxPtr box = void;

    overMarked = underMarked = markAll = FALSE;

    if (pLayerWin)
        *pLayerWin = pWin;      /* hah! */

    doUnderlay = (mixin(IN_UNDERLAY!(`pWin`)) || HasUnderlayChildren(pWin));

    box = RegionExtents(&pWin.borderSize);

    if ((pChild = pFirst) !is null) {
        pLast = pChild.parent.lastChild;
        while (1) {
            if (pChild == pWin)
                markAll = TRUE;

            if (doUnderlay && mixin(IN_UNDERLAY!(`pChild`)))
                pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));

            if (pChild.viewable) {
                if (RegionBroken(&pChild.winSize))
                    SetWinSize(pChild);
                if (RegionBroken(&pChild.borderSize))
                    SetBorderSize(pChild);

                if (markAll || RegionContainsRect(&pChild.borderSize, box)) {
                    mixin(MARK_OVERLAY!(`pChild`)~`;`);
                    overMarked = TRUE;
                    if (doUnderlay && mixin(IN_UNDERLAY!(`pChild`))) {
                        mixin(MARK_UNDERLAY!(`pChild`)~`;`);
                        underMarked = TRUE;
                    }
                    if (pChild.firstChild) {
                        pChild = pChild.firstChild;
                        continue;
                    }
                }
            }
            while (!pChild.nextSib && (pChild != pLast)) {
                pChild = pChild.parent;
                if (doUnderlay && mixin(IN_UNDERLAY!(`pChild`)))
                    pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));
            }

            if (pChild == pWin)
                markAll = FALSE;

            if (pChild == pLast)
                break;

            pChild = pChild.nextSib;
        }
        if (overMarked)
            mixin(MARK_OVERLAY!(`pWin.parent`)~`;`);
    }

    if (doUnderlay && !pTree) {
        if (((pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`))) is null)) {
            pChild = pWin.lastChild;
            while (1) {
                if ((pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`))) !is null)
                    break;

                if (pChild.lastChild) {
                    pChild = pChild.lastChild;
                    continue;
                }

                while (!pChild.prevSib)
                    pChild = pChild.parent;

                pChild = pChild.prevSib;
            }
        }
    }

    if (pTree && pTree.nextSib) {
        tChild = pTree.parent.lastChild;
        tLast = pTree.nextSib;

        while (1) {
            if (tChild.pWin.viewable) {
                if (RegionBroken(&tChild.pWin.winSize))
                    SetWinSize(tChild.pWin);
                if (RegionBroken(&tChild.pWin.borderSize))
                    SetBorderSize(tChild.pWin);

                if (RegionContainsRect(&(tChild.pWin.borderSize), box)) {
                    mixin(MARK_UNDERLAY!(`tChild.pWin`)~`;`);
                    underMarked = TRUE;
                }
            }

            if (tChild.lastChild) {
                tChild = tChild.lastChild;
                continue;
            }

            while (!tChild.prevSib && (tChild != tLast))
                tChild = tChild.parent;

            if (tChild == tLast)
                break;

            tChild = tChild.prevSib;
        }
    }

    if (underMarked) {
        ScreenPtr pScreen = pWin.drawable.pScreen;

        mixin(MARK_UNDERLAY!(`pTree.parent.pWin`)~`;`);
        mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`)).underlayMarked = TRUE;
    }

    return underMarked || overMarked;
}

private void miOverlayComputeClips(WindowPtr pParent, RegionPtr universe, VTKind kind, RegionPtr exposed)
{
    ScreenPtr pScreen = pParent.drawable.pScreen;
    int oldVis = void, newVis = void, dx = void, dy = void;
    BoxRec borderSize = void;
    RegionPtr borderVisible = void;
    RegionRec childUniverse = void, childUnion = void;
    miOverlayTreePtr tParent = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pParent`));
    miOverlayTreePtr tChild = void;
    Bool overlap = void;

    borderSize.x1 = cast(short)(pParent.drawable.x - mixin(wBorderWidth!("pParent")));
    borderSize.y1 = cast(short)(pParent.drawable.y - mixin(wBorderWidth!("pParent")));
    dx = cast(int) pParent.drawable.x + cast(int) pParent.drawable.width +
        mixin(wBorderWidth!("pParent"));
    if (dx > 32767)
        dx = 32767;
    borderSize.x2 = cast(short)dx;
    dy = cast(int) pParent.drawable.y + cast(int) pParent.drawable.height +
        mixin(wBorderWidth!("pParent"));
    if (dy > 32767)
        dy = 32767;
    borderSize.y2 = cast(short)dy;

    oldVis = tParent.visibility;
    switch (RegionContainsRect(universe, &borderSize)) {
    case rgnIN:
        newVis = VisibilityUnobscured;
        break;
    case rgnPART:
        newVis = VisibilityPartiallyObscured;
        {
            RegionPtr pBounding = void;

            if ((pBounding = mixin(wBoundingShape!("pParent"))) !is null) {
                switch (miShapedWindowIn(universe, pBounding,
                                         &borderSize,
                                         pParent.drawable.x,
                                         pParent.drawable.y)) {
                case rgnIN:
                    newVis = VisibilityUnobscured;
                    break;
                case rgnOUT:
                    newVis = VisibilityFullyObscured;
                    break;
                default: break;}
            }
        }
        break;
    default:
        newVis = VisibilityFullyObscured;
        break;
    }
    tParent.visibility = newVis;

    dx = pParent.drawable.x - tParent.valdata.oldAbsCorner.x;
    dy = pParent.drawable.y - tParent.valdata.oldAbsCorner.y;

    switch (kind) {
    case VTMap:
    case VTStack:
    case VTUnmap:
        break;
    case VTMove:
        if ((oldVis == newVis) &&
            ((oldVis == VisibilityFullyObscured) ||
             (oldVis == VisibilityUnobscured))) {
            tChild = tParent;
            while (1) {
                if (tChild.pWin.viewable) {
                    if (tChild.visibility != VisibilityFullyObscured) {
                        RegionTranslate(&tChild.borderClip, dx, dy);
                        RegionTranslate(&tChild.clipList, dx, dy);

                        tChild.pWin.drawable.serialNumber =
                            NEXT_SERIAL_NUMBER;
                        if (pScreen.ClipNotify)
                            (*pScreen.ClipNotify) (tChild.pWin, dx, dy);
                    }
                    if (tChild.valdata) {
                        RegionNull(&tChild.valdata.borderExposed);
                        if (mixin(HasParentRelativeBorder!(`tChild.pWin`))) {
                            RegionSubtract(&tChild.valdata.borderExposed,
                                           &tChild.borderClip,
                                           &tChild.pWin.winSize);
                        }
                        RegionNull(&tChild.valdata.exposed);
                    }
                    if (tChild.firstChild) {
                        tChild = tChild.firstChild;
                        continue;
                    }
                }
                while (!tChild.nextSib && (tChild != tParent))
                    tChild = tChild.parent;
                if (tChild == tParent)
                    break;
                tChild = tChild.nextSib;
            }
            return;
        }
        /* fall through */
        goto default;
    default:
        if (dx || dy) {
            RegionTranslate(&tParent.borderClip, dx, dy);
            RegionTranslate(&tParent.clipList, dx, dy);
        }
        break;
    case VTBroken:
        RegionEmpty(&tParent.borderClip);
        RegionEmpty(&tParent.clipList);
        break;
    }

    borderVisible = tParent.valdata.borderVisible;
    RegionNull(&tParent.valdata.borderExposed);
    RegionNull(&tParent.valdata.exposed);

    if (mixin(HasBorder!("pParent"))) {
        if (borderVisible) {
            RegionSubtract(exposed, universe, borderVisible);
            RegionDestroy(borderVisible);
        }
        else
            RegionSubtract(exposed, universe, &tParent.borderClip);

        if (mixin(HasParentRelativeBorder!(`pParent`)) && (dx || dy))
            RegionSubtract(&tParent.valdata.borderExposed,
                           universe, &pParent.winSize);
        else
            RegionSubtract(&tParent.valdata.borderExposed,
                           exposed, &pParent.winSize);

        RegionCopy(&tParent.borderClip, universe);
        RegionIntersect(universe, universe, &pParent.winSize);
    }
    else
        RegionCopy(&tParent.borderClip, universe);

    if ((tChild = tParent.firstChild) !is null && pParent.mapped) {
        RegionNull(&childUniverse);
        RegionNull(&childUnion);

        for (; tChild; tChild = tChild.nextSib) {
            if (tChild.pWin.viewable)
                RegionAppend(&childUnion, &tChild.pWin.borderSize);
        }

        RegionValidate(&childUnion, &overlap);

        for (tChild = tParent.firstChild; tChild; tChild = tChild.nextSib) {
            if (tChild.pWin.viewable) {
                if (tChild.valdata) {
                    RegionIntersect(&childUniverse, universe,
                                    &tChild.pWin.borderSize);
                    miOverlayComputeClips(tChild.pWin, &childUniverse,
                                          kind, exposed);
                }
                if (overlap)
                    RegionSubtract(universe, universe,
                                   &tChild.pWin.borderSize);
            }
        }
        if (!overlap)
            RegionSubtract(universe, universe, &childUnion);
        RegionUninit(&childUnion);
        RegionUninit(&childUniverse);
    }

    if (oldVis == VisibilityFullyObscured || oldVis == VisibilityNotViewable) {
        RegionCopy(&tParent.valdata.exposed, universe);
    }
    else if (newVis != VisibilityFullyObscured &&
             newVis != VisibilityNotViewable) {
        RegionSubtract(&tParent.valdata.exposed,
                       universe, &tParent.clipList);
    }

    /* HACK ALERT - copying contents of regions, instead of regions */
    {
        RegionRec tmp = void;

        tmp = tParent.clipList;
        tParent.clipList = *universe;
        *universe = tmp;
    }

    pParent.drawable.serialNumber = NEXT_SERIAL_NUMBER;

    if (pScreen.ClipNotify)
        (*pScreen.ClipNotify) (pParent, dx, dy);
}

private void miOverlayMarkWindow(WindowPtr pWin)
{
    miOverlayTreePtr pTree = null;
    WindowPtr pChild = void, pGrandChild = void;

    miMarkWindow(pWin);

    /* look for UnmapValdata among immediate children */

    if (((pChild = pWin.firstChild) is null))
        return;

    for (; pChild; pChild = pChild.nextSib) {
        if (pChild.valdata == UnmapValData) {
            if (mixin(IN_UNDERLAY!(`pChild`))) {
                pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));
                pTree.valdata = cast(miOverlayValDataPtr) UnmapValData;
                continue;
            }
            else {
                if (((pGrandChild = pChild.firstChild) is null))
                    continue;

                while (1) {
                    if (mixin(IN_UNDERLAY!(`pGrandChild`))) {
                        pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pGrandChild`));
                        pTree.valdata = cast(miOverlayValDataPtr) UnmapValData;
                    }
                    else if (pGrandChild.firstChild) {
                        pGrandChild = pGrandChild.firstChild;
                        continue;
                    }

                    while (!pGrandChild.nextSib && (pGrandChild != pChild))
                        pGrandChild = pGrandChild.parent;

                    if (pChild == pGrandChild)
                        break;

                    pGrandChild = pGrandChild.nextSib;
                }
            }
        }
    }

    if (pTree) {
        mixin(MARK_UNDERLAY!(`pTree.parent.pWin`)~`;`);
        mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pWin.drawable.pScreen`)).underlayMarked =
            TRUE;
    }
}

private void miOverlayMarkUnrealizedWindow(WindowPtr pChild, WindowPtr pWin, Bool fromConfigure)
{
    if ((pChild != pWin) || fromConfigure) {
        miOverlayTreePtr pTree = void;

        RegionEmpty(&pChild.clipList);
        if (pChild.drawable.pScreen.ClipNotify)
            (*pChild.drawable.pScreen.ClipNotify) (pChild, 0, 0);
        RegionEmpty(&pChild.borderClip);
        if ((pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`))) !is null) {
            if (pTree.valdata != cast(miOverlayValDataPtr) UnmapValData) {
                RegionEmpty(&pTree.clipList);
                RegionEmpty(&pTree.borderClip);
            }
        }
    }
}

private int miOverlayValidateTree(WindowPtr pParent, WindowPtr pChild, VTKind kind)
{
    ScreenPtr pScreen = pParent.drawable.pScreen;
    miOverlayScreenPtr pPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    RegionRec totalClip = void, childClip = void, exposed = void;
    miOverlayTreePtr tParent = void, tChild = void, tWin = void;
    Bool overlap = void;
    WindowPtr newParent = void;

    if (!pPriv.underlayMarked)
        goto SKIP_UNDERLAY;

    if (!pChild)
        pChild = pParent.firstChild;

    RegionNull(&totalClip);
    RegionNull(&childClip);
    RegionNull(&exposed);

    newParent = pParent;

    while (mixin(IN_OVERLAY!(`newParent`)))
        newParent = newParent.parent;

    tParent = mixin(MIOVERLAY_GET_WINDOW_TREE!(`newParent`));

    if (mixin(IN_UNDERLAY!(`pChild`)))
        tChild = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));
    else
        tChild = tParent.firstChild;

    if (RegionBroken(&tParent.clipList) && !RegionBroken(&tParent.borderClip)) {
        kind = VTBroken;
        RegionCopy(&totalClip, &tParent.borderClip);
        RegionIntersect(&totalClip, &totalClip, &tParent.pWin.winSize);

        for (tWin = tParent.firstChild; tWin != tChild; tWin = tWin.nextSib) {
            if (tWin.pWin.viewable)
                RegionSubtract(&totalClip, &totalClip, &tWin.pWin.borderSize);
        }
        RegionEmpty(&tParent.clipList);
    }
    else {
        for (tWin = tChild; tWin; tWin = tWin.nextSib) {
            if (tWin.valdata)
                RegionAppend(&totalClip, &tWin.borderClip);
        }
        RegionValidate(&totalClip, &overlap);
    }

    if (kind != VTStack)
        RegionUnion(&totalClip, &totalClip, &tParent.clipList);

    for (tWin = tChild; tWin; tWin = tWin.nextSib) {
        if (tWin.valdata) {
            if (tWin.pWin.viewable) {
                RegionIntersect(&childClip, &totalClip,
                                &tWin.pWin.borderSize);
                miOverlayComputeClips(tWin.pWin, &childClip, kind, &exposed);
                RegionSubtract(&totalClip, &totalClip, &tWin.pWin.borderSize);
            }
            else {              /* Means we are unmapping */
                RegionEmpty(&tWin.clipList);
                RegionEmpty(&tWin.borderClip);
                tWin.valdata = null;
            }
        }
    }

    RegionUninit(&childClip);

    if (!((*pPriv.InOverlay) (newParent))) {
        RegionNull(&tParent.valdata.exposed);
        RegionNull(&tParent.valdata.borderExposed);
    }

    switch (kind) {
    case VTStack:
        break;
    default:
        if (!((*pPriv.InOverlay) (newParent)))
            RegionSubtract(&tParent.valdata.exposed, &totalClip,
                           &tParent.clipList);
        /* fall through */
        goto case;
    case VTMap:
        RegionCopy(&tParent.clipList, &totalClip);
        if (!((*pPriv.InOverlay) (newParent)))
            newParent.drawable.serialNumber = NEXT_SERIAL_NUMBER;
        break;
    }

    RegionUninit(&totalClip);
    RegionUninit(&exposed);

 SKIP_UNDERLAY:

    miValidateTree(pParent, pChild, kind);

    return 1;
}

private void miOverlayHandleExposures(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    WindowPtr pChild = void;
    ValidatePtr val = void;
    WindowExposuresProcPtr WindowExposures = void;

    WindowExposures = pWin.drawable.pScreen.WindowExposures;
    if (pPriv.underlayMarked) {
        miOverlayTreePtr pTree = void;
        miOverlayValDataPtr mival = void;

        pChild = pWin;
        while (mixin(IN_OVERLAY!(`pChild`)))
            pChild = pChild.parent;

        pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));

        while (1) {
            if ((mival = pTree.valdata) is null) {
                if (!((*pPriv.InOverlay) (pTree.pWin))) {
                    if (RegionNotEmpty(&mival.borderExposed)) {
                        pScreen.PaintWindow(pTree.pWin, &mival.borderExposed,
                                             PW_BORDER);
                    }
                    RegionUninit(&mival.borderExposed);

                    (*WindowExposures) (pTree.pWin, &mival.exposed);
                    RegionUninit(&mival.exposed);
                }
                free(mival);
                pTree.valdata = null;
                if (pTree.firstChild) {
                    pTree = pTree.firstChild;
                    continue;
                }
            }
            while (!pTree.nextSib && (pTree.pWin != pChild))
                pTree = pTree.parent;
            if (pTree.pWin == pChild)
                break;
            pTree = pTree.nextSib;
        }
        pPriv.underlayMarked = FALSE;
    }

    pChild = pWin;
    while (1) {
        if ((val = pChild.valdata)is null) {
            if (!((*pPriv.InOverlay) (pChild))) {
                RegionUnion(&val.after.exposed, &val.after.exposed,
                            &val.after.borderExposed);

                if (RegionNotEmpty(&val.after.exposed)) {
                    (*(mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`)).MakeTransparent))
                        (pScreen, RegionNumRects(&val.after.exposed),
                         RegionRects(&val.after.exposed));
                }
            }
            else {
                if (RegionNotEmpty(&val.after.borderExposed)) {
                    pScreen.PaintWindow(pChild, &val.after.borderExposed,
                                         PW_BORDER);
                }
                (*WindowExposures) (pChild, &val.after.exposed);
            }
            RegionUninit(&val.after.borderExposed);
            RegionUninit(&val.after.exposed);
            free(val);
            pChild.valdata = null;
            if (pChild.firstChild) {
                pChild = pChild.firstChild;
                continue;
            }
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            break;
        pChild = pChild.nextSib;
    }
}

private void miOverlayMoveWindow(WindowPtr pWin, int x, int y, WindowPtr pNextSib, VTKind kind)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    WindowPtr pParent = void, windowToValidate = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    short bw = void;
    RegionRec overReg = void, underReg = void;
    xPoint oldpt = void;

    if (((pParent = pWin.parent) is null))
        return;
    bw = mixin(wBorderWidth!("pWin"));

    oldpt.x = pWin.drawable.x;
    oldpt.y = pWin.drawable.y;
    if (WasViewable) {
        RegionNull(&overReg);
        RegionNull(&underReg);
        if (pTree) {
            RegionCopy(&overReg, &pWin.borderClip);
            RegionCopy(&underReg, &pTree.borderClip);
        }
        else {
            RegionCopy(&overReg, &pWin.borderClip);
            CollectUnderlayChildrenRegions(pWin, &underReg);
        }
        (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);
    }
    pWin.origin.x = cast(short)(x + cast(int) bw);
    pWin.origin.y = cast(short)(y + cast(int) bw);
    x = pWin.drawable.x = cast(short)(pParent.drawable.x + x + cast(int) bw);
    y = pWin.drawable.y = cast(short)(pParent.drawable.y + y + cast(int) bw);

    SetWinSize(pWin);
    SetBorderSize(pWin);

    (*pScreen.PositionWindow) (pWin, x, y);

    windowToValidate = MoveWindowInStack(pWin, pNextSib);

    ResizeChildrenWinSize(pWin, x - oldpt.x, y - oldpt.y, 0, 0);

    if (WasViewable) {
        miOverlayScreenPtr pPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));

        (*pScreen.MarkOverlappedWindows) (pWin, windowToValidate, null);

        (*pScreen.ValidateTree) (pWin.parent, NullWindow, kind);
        if (RegionNotEmpty(&underReg)) {
            pPriv.copyUnderlay = TRUE;
            (*pWin.drawable.pScreen.CopyWindow) (pWin, oldpt, &underReg);
        }
        RegionUninit(&underReg);
        if (RegionNotEmpty(&overReg)) {
            pPriv.copyUnderlay = FALSE;
            (*pWin.drawable.pScreen.CopyWindow) (pWin, oldpt, &overReg);
        }
        RegionUninit(&overReg);
        (*pScreen.HandleExposures) (pWin.parent);

        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (pWin.parent, NullWindow, kind);
    }
    if (pWin.realized)
        WindowsRestructured();
}

enum RECTLIMIT = 25;


private void miOverlayWindowExposures(WindowPtr pWin, RegionPtr prgn)
{
    RegionPtr exposures = prgn;
    ScreenPtr pScreen = pWin.drawable.pScreen;

    if (prgn && !RegionNil(prgn)) {
        RegionRec expRec = void;
        int clientInterested = cast(int)((pWin.eventMask | mixin(wOtherEventMasks!("pWin"))) & ExposureMask);
        if (clientInterested && (RegionNumRects(prgn) > RECTLIMIT)) {
            miOverlayScreenPtr pPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
            BoxRec box = void;

            box = *RegionExtents(prgn);
            exposures = &expRec;
            RegionInit(exposures, &box, 1);
            RegionReset(prgn, &box);
            /* This is the only reason why we are replacing mi's version
               of this file */

            if (!((*pPriv.InOverlay) (pWin))) {
                miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

                RegionIntersect(prgn, prgn, &pTree.clipList);
            }
            else
                RegionIntersect(prgn, prgn, &pWin.clipList);
        }
        pScreen.PaintWindow(pWin, prgn, PW_BACKGROUND);
        if (clientInterested)
            miSendExposures(pWin, exposures,
                            pWin.drawable.x, pWin.drawable.y);
        if (exposures == &expRec)
            RegionUninit(exposures);
        RegionEmpty(prgn);
    }
}

struct miOverlayTwoRegions {
    RegionPtr over;
    RegionPtr under;
}

private int miOverlayRecomputeExposures(WindowPtr pWin, void* value)
{
    miOverlayTwoRegions* pValid = cast(miOverlayTwoRegions*) value;
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    if (pWin.valdata) {
        /*
         * compute exposed regions of this window
         */
        RegionSubtract(&pWin.valdata.after.exposed,
                       &pWin.clipList, pValid.over);
        /*
         * compute exposed regions of the border
         */
        RegionSubtract(&pWin.valdata.after.borderExposed,
                       &pWin.borderClip, &pWin.winSize);
        RegionSubtract(&pWin.valdata.after.borderExposed,
                       &pWin.valdata.after.borderExposed, pValid.over);
    }

    if (pTree && pTree.valdata) {
        RegionSubtract(&pTree.valdata.exposed,
                       &pTree.clipList, pValid.under);
        RegionSubtract(&pTree.valdata.borderExposed,
                       &pTree.borderClip, &pWin.winSize);
        RegionSubtract(&pTree.valdata.borderExposed,
                       &pTree.valdata.borderExposed, pValid.under);
    }
    else if (!pWin.valdata)
        return WT_NOMATCH;

    return WT_WALKCHILDREN;
}

private void miOverlayResizeWindow(WindowPtr pWin, int x, int y, uint w, uint h, WindowPtr pSib)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    WindowPtr pParent = void;
    miOverlayTreePtr tChild = void, pTree = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    ushort width = pWin.drawable.width;
    ushort height = pWin.drawable.height;
    short oldx = pWin.drawable.x;
    short oldy = pWin.drawable.y;
    int bw = mixin(wBorderWidth!("pWin"));
    short dw = void, dh = void;
    xPoint oldpt = void;
    RegionPtr oldRegion = null, oldRegion2 = null;
    WindowPtr pFirstChange = void;
    WindowPtr pChild = void;
    RegionPtr[StaticGravity + 1] gravitate = void;
    RegionPtr[StaticGravity + 1] gravitate2 = void;
    uint g = void;
    int nx = void, ny = void;                 /* destination x,y */
    int newx = void, newy = void;             /* new inner window position */
    RegionPtr pRegion = null;
    RegionPtr destClip = void, destClip2 = void;
    RegionPtr oldWinClip = null, oldWinClip2 = null;
    RegionPtr borderVisible = NullRegion;
    RegionPtr borderVisible2 = NullRegion;
    Bool shrunk = FALSE;        /* shrunk in an inner dimension */
    Bool moved = FALSE;         /* window position changed */
    Bool doUnderlay = void;

    /* if this is a root window, can't be resized */
    if (((pParent = pWin.parent) is null))
        return;

    pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    doUnderlay = ((pTree) || HasUnderlayChildren(pWin));
    newx = pParent.drawable.x + x + bw;
    newy = pParent.drawable.y + y + bw;
    if (WasViewable) {
        /*
         * save the visible region of the window
         */
        oldRegion = RegionCreate(NullBox, 1);
        RegionCopy(oldRegion, &pWin.winSize);
        if (doUnderlay) {
            oldRegion2 = RegionCreate(NullBox, 1);
            RegionCopy(oldRegion2, &pWin.winSize);
        }

        /*
         * categorize child windows into regions to be moved
         */
        for (g = 0; g <= StaticGravity; g++)
            gravitate[g] = gravitate2[g] = null;
        for (pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
            g = pChild.winGravity;
            if (g != UnmapGravity) {
                if (!gravitate[g])
                    gravitate[g] = RegionCreate(NullBox, 1);
                RegionUnion(gravitate[g], gravitate[g], &pChild.borderClip);

                if (doUnderlay) {
                    if (!gravitate2[g])
                        gravitate2[g] = RegionCreate(NullBox, 0);

                    if ((tChild = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`))) !is null) {
                        RegionUnion(gravitate2[g],
                                    gravitate2[g], &tChild.borderClip);
                    }
                    else
                        CollectUnderlayChildrenRegions(pChild, gravitate2[g]);
                }
            }
            else {
                UnmapWindow(pChild, TRUE);
            }
        }
        (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);

        oldWinClip = oldWinClip2 = null;
        if (pWin.bitGravity != ForgetGravity) {
            oldWinClip = RegionCreate(NullBox, 1);
            RegionCopy(oldWinClip, &pWin.clipList);
            if (pTree) {
                oldWinClip2 = RegionCreate(NullBox, 1);
                RegionCopy(oldWinClip2, &pTree.clipList);
            }
        }
        /*
         * if the window is changing size, borderExposed
         * can't be computed correctly without some help.
         */
        if (pWin.drawable.height > h || pWin.drawable.width > w)
            shrunk = TRUE;

        if (newx != oldx || newy != oldy)
            moved = TRUE;

        if ((pWin.drawable.height != h || pWin.drawable.width != w) &&
            mixin(HasBorder!("pWin"))) {
            borderVisible = RegionCreate(NullBox, 1);
            if (pTree)
                borderVisible2 = RegionCreate(NullBox, 1);
            /* for tiled borders, we punt and draw the whole thing */
            if (pWin.borderIsPixel || !moved) {
                if (shrunk || moved)
                    RegionSubtract(borderVisible,
                                   &pWin.borderClip, &pWin.winSize);
                else
                    RegionCopy(borderVisible, &pWin.borderClip);
                if (pTree) {
                    if (shrunk || moved)
                        RegionSubtract(borderVisible,
                                       &pTree.borderClip, &pWin.winSize);
                    else
                        RegionCopy(borderVisible, &pTree.borderClip);
                }
            }
        }
    }
    pWin.origin.x = cast(short)(x + bw);
    pWin.origin.y = cast(short)(y + bw);
    pWin.drawable.height = cast(ushort)h;
    pWin.drawable.width = cast(ushort)w;

    x = pWin.drawable.x = cast(short)newx;
    y = pWin.drawable.y = cast(short)newy;

    SetWinSize(pWin);
    SetBorderSize(pWin);

    dw = cast(short)(cast(int) w - cast(int) width);
    dh = cast(short)(cast(int) h - cast(int) height);
    ResizeChildrenWinSize(pWin, x - oldx, y - oldy, dw, dh);

    /* let the hardware adjust background and border pixmaps, if any */
    (*pScreen.PositionWindow) (pWin, x, y);

    pFirstChange = MoveWindowInStack(pWin, pSib);

    if (WasViewable) {
        pRegion = RegionCreate(NullBox, 1);

        (*pScreen.MarkOverlappedWindows) (pWin, pFirstChange, null);

        pWin.valdata.before.resized = TRUE;
        pWin.valdata.before.borderVisible = borderVisible;
        if (pTree)
            pTree.valdata.borderVisible = borderVisible2;

        (*pScreen.ValidateTree) (pWin.parent, pFirstChange, VTOther);
        /*
         * the entire window is trashed unless bitGravity
         * recovers portions of it
         */
        RegionCopy(&pWin.valdata.after.exposed, &pWin.clipList);
        if (pTree)
            RegionCopy(&pTree.valdata.exposed, &pTree.clipList);
    }

    GravityTranslate(x, y, oldx, oldy, dw, dh, pWin.bitGravity, &nx, &ny);

    if (WasViewable) {
        miOverlayScreenPtr pPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
        miOverlayTwoRegions TwoRegions = void;

        /* avoid the border */
        if (mixin(HasBorder!("pWin"))) {
            int offx = void, offy = void, dx = void, dy = void;

            /* kruft to avoid double translates for each gravity */
            offx = 0;
            offy = 0;
            for (g = 0; g <= StaticGravity; g++) {
                if (!gravitate[g] && !gravitate2[g])
                    continue;

                /* align winSize to gravitate[g].
                 * winSize is in new coordinates,
                 * gravitate[g] is still in old coordinates */
                GravityTranslate(x, y, oldx, oldy, dw, dh, g, &nx, &ny);

                dx = (oldx - nx) - offx;
                dy = (oldy - ny) - offy;
                if (dx || dy) {
                    RegionTranslate(&pWin.winSize, dx, dy);
                    offx += dx;
                    offy += dy;
                }
                if (gravitate[g])
                    RegionIntersect(gravitate[g], gravitate[g], &pWin.winSize);
                if (gravitate2[g])
                    RegionIntersect(gravitate2[g], gravitate2[g],
                                    &pWin.winSize);
            }
            /* get winSize back where it belongs */
            if (offx || offy)
                RegionTranslate(&pWin.winSize, -offx, -offy);
        }
        /*
         * add screen bits to the appropriate bucket
         */

        if (oldWinClip2) {
            RegionCopy(pRegion, oldWinClip2);
            RegionTranslate(pRegion, nx - oldx, ny - oldy);
            RegionIntersect(oldWinClip2, pRegion, &pTree.clipList);

            for (g = pWin.bitGravity + 1; g <= StaticGravity; g++) {
                if (gravitate2[g])
                    RegionSubtract(oldWinClip2, oldWinClip2, gravitate2[g]);
            }
            RegionTranslate(oldWinClip2, oldx - nx, oldy - ny);
            g = pWin.bitGravity;
            if (!gravitate2[g])
                gravitate2[g] = oldWinClip2;
            else {
                RegionUnion(gravitate2[g], gravitate2[g], oldWinClip2);
                RegionDestroy(oldWinClip2);
            }
        }

        if (oldWinClip) {
            /*
             * clip to new clipList
             */
            RegionCopy(pRegion, oldWinClip);
            RegionTranslate(pRegion, nx - oldx, ny - oldy);
            RegionIntersect(oldWinClip, pRegion, &pWin.clipList);
            /*
             * don't step on any gravity bits which will be copied after this
             * region.  Note -- this assumes that the regions will be copied
             * in gravity order.
             */
            for (g = pWin.bitGravity + 1; g <= StaticGravity; g++) {
                if (gravitate[g])
                    RegionSubtract(oldWinClip, oldWinClip, gravitate[g]);
            }
            RegionTranslate(oldWinClip, oldx - nx, oldy - ny);
            g = pWin.bitGravity;
            if (!gravitate[g])
                gravitate[g] = oldWinClip;
            else {
                RegionUnion(gravitate[g], gravitate[g], oldWinClip);
                RegionDestroy(oldWinClip);
            }
        }

        /*
         * move the bits on the screen
         */

        destClip = destClip2 = null;

        for (g = 0; g <= StaticGravity; g++) {
            if (!gravitate[g] && !gravitate2[g])
                continue;

            GravityTranslate(x, y, oldx, oldy, dw, dh, g, &nx, &ny);

            oldpt.x = cast(short)(oldx + (x - nx));
            oldpt.y = cast(short)(oldy + (y - ny));

            /* Note that gravitate[g] is *translated* by CopyWindow */

            /* only copy the remaining useful bits */

            if (gravitate[g])
                RegionIntersect(gravitate[g], gravitate[g], oldRegion);
            if (gravitate2[g])
                RegionIntersect(gravitate2[g], gravitate2[g], oldRegion2);

            /* clip to not overwrite already copied areas */

            if (destClip && gravitate[g]) {
                RegionTranslate(destClip, oldpt.x - x, oldpt.y - y);
                RegionSubtract(gravitate[g], gravitate[g], destClip);
                RegionTranslate(destClip, x - oldpt.x, y - oldpt.y);
            }
            if (destClip2 && gravitate2[g]) {
                RegionTranslate(destClip2, oldpt.x - x, oldpt.y - y);
                RegionSubtract(gravitate2[g], gravitate2[g], destClip2);
                RegionTranslate(destClip2, x - oldpt.x, y - oldpt.y);
            }

            /* and move those bits */

            if (oldpt.x != x || oldpt.y != y) {
                if (gravitate2[g]) {
                    pPriv.copyUnderlay = TRUE;
                    (*pScreen.CopyWindow) (pWin, oldpt, gravitate2[g]);
                }
                if (gravitate[g]) {
                    pPriv.copyUnderlay = FALSE;
                    (*pScreen.CopyWindow) (pWin, oldpt, gravitate[g]);
                }
            }

            /* remove any overwritten bits from the remaining useful bits */

            if (gravitate[g])
                RegionSubtract(oldRegion, oldRegion, gravitate[g]);
            if (gravitate2[g])
                RegionSubtract(oldRegion2, oldRegion2, gravitate2[g]);

            /*
             * recompute exposed regions of child windows
             */

            for (pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
                if (pChild.winGravity != g)
                    continue;

                TwoRegions.over = gravitate[g];
                TwoRegions.under = gravitate2[g];

                TraverseTree(pChild, &miOverlayRecomputeExposures,
                             cast(void*) (&TwoRegions));
            }

            /*
             * remove the successfully copied regions of the
             * window from its exposed region
             */

            if (g == pWin.bitGravity) {
                if (gravitate[g])
                    RegionSubtract(&pWin.valdata.after.exposed,
                                   &pWin.valdata.after.exposed, gravitate[g]);
                if (gravitate2[g] && pTree)
                    RegionSubtract(&pTree.valdata.exposed,
                                   &pTree.valdata.exposed, gravitate2[g]);
            }
            if (gravitate[g]) {
                if (!destClip)
                    destClip = gravitate[g];
                else {
                    RegionUnion(destClip, destClip, gravitate[g]);
                    RegionDestroy(gravitate[g]);
                }
            }
            if (gravitate2[g]) {
                if (!destClip2)
                    destClip2 = gravitate2[g];
                else {
                    RegionUnion(destClip2, destClip2, gravitate2[g]);
                    RegionDestroy(gravitate2[g]);
                }
            }
        }

        RegionDestroy(pRegion);
        RegionDestroy(oldRegion);
        if (doUnderlay)
            RegionDestroy(oldRegion2);
        if (destClip)
            RegionDestroy(destClip);
        if (destClip2)
            RegionDestroy(destClip2);
        (*pScreen.HandleExposures) (pWin.parent);
        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (pWin.parent, pFirstChange, VTOther);
    }
    if (pWin.realized)
        WindowsRestructured();
}

private void miOverlaySetShape(WindowPtr pWin, int kind)
{
    Bool WasViewable = cast(Bool) (pWin.viewable);
    ScreenPtr pScreen = pWin.drawable.pScreen;

    if (kind != ShapeInput) {
        if (WasViewable) {
            (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);

            if (mixin(HasBorder!("pWin"))) {
                RegionPtr borderVisible = void;

                borderVisible = RegionCreate(NullBox, 1);
                RegionSubtract(borderVisible,
                               &pWin.borderClip, &pWin.winSize);
                pWin.valdata.before.borderVisible = borderVisible;
                pWin.valdata.before.resized = TRUE;
                if (mixin(IN_UNDERLAY!(`pWin`))) {
                    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
                    RegionPtr borderVisible2 = void;

                    borderVisible2 = RegionCreate(null, 1);
                    RegionSubtract(borderVisible2,
                                   &pTree.borderClip, &pWin.winSize);
                    pTree.valdata.borderVisible = borderVisible2;
                }
            }
        }

        SetWinSize(pWin);
        SetBorderSize(pWin);

        ResizeChildrenWinSize(pWin, 0, 0, 0, 0);

        if (WasViewable) {
            (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);
            (*pScreen.ValidateTree) (pWin.parent, NullWindow, VTOther);
            (*pScreen.HandleExposures) (pWin.parent);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pWin.parent, NullWindow,
                                              VTOther);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
    CheckCursorConfinement(pWin);
}

private void miOverlayChangeBorderWidth(WindowPtr pWin, uint width)
{
    int oldwidth = void;
    ScreenPtr pScreen = void;
    Bool WasViewable = cast(Bool) (pWin.viewable);
    Bool HadBorder = void;

    oldwidth = mixin(wBorderWidth!("pWin"));
    if (oldwidth == width)
        return;
    HadBorder = mixin(HasBorder!("pWin"));
    pScreen = pWin.drawable.pScreen;
    if (WasViewable && (width < oldwidth))
        (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);

    pWin.borderWidth = cast(ushort)width;
    SetBorderSize(pWin);

    if (WasViewable) {
        if (width > oldwidth) {
            (*pScreen.MarkOverlappedWindows) (pWin, pWin, null);

            if (HadBorder) {
                RegionPtr borderVisible = void;

                borderVisible = RegionCreate(null, 1);
                RegionSubtract(borderVisible,
                               &pWin.borderClip, &pWin.winSize);
                pWin.valdata.before.borderVisible = borderVisible;
                if (mixin(IN_UNDERLAY!(`pWin`))) {
                    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
                    RegionPtr borderVisible2 = void;

                    borderVisible2 = RegionCreate(null, 1);
                    RegionSubtract(borderVisible2,
                                   &pTree.borderClip, &pWin.winSize);
                    pTree.valdata.borderVisible = borderVisible2;
                }
            }
        }
        (*pScreen.ValidateTree) (pWin.parent, pWin, VTOther);
        (*pScreen.HandleExposures) (pWin.parent);

        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (pWin.parent, pWin, VTOther);
    }
    if (pWin.realized)
        WindowsRestructured();
}

/*  We need this as an addition since the xf86 common code doesn't
    know about the second tree which is static to this file.  */

void miOverlaySetRootClip(ScreenPtr pScreen, Bool enable)
{
    WindowPtr pRoot = pScreen.root;
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pRoot`));

    mixin(MARK_UNDERLAY!(`pRoot`)~`;`);

    if (enable) {
        BoxRec box = void;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pScreen.width;
        box.y2 = pScreen.height;

        RegionReset(&pTree.borderClip, &box);
    }
    else
        RegionEmpty(&pTree.borderClip);

    RegionBreak(&pTree.clipList);
}

private void miOverlayClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    BoxRec box = void;
    RegionRec reg = void;
    ScreenPtr pScreen = pWin.drawable.pScreen;
    miOverlayScreenPtr pScreenPriv = mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`));
    RegionPtr clipList = void;
    BoxPtr extents = void;
    int x1 = void, y1 = void, x2 = void, y2 = void;

    x1 = pWin.drawable.x + x;
    y1 = pWin.drawable.y + y;
    if (w)
        x2 = x1 + cast(int) w;
    else
        x2 = x1 + cast(int) pWin.drawable.width - cast(int) x;
    if (h)
        y2 = y1 + h;
    else
        y2 = y1 + cast(int) pWin.drawable.height - cast(int) y;

    clipList = ((*pScreenPriv.InOverlay) (pWin)) ? &pWin.clipList :
        &pTree.clipList;

    extents = RegionExtents(clipList);

    if (x1 < extents.x1)
        x1 = extents.x1;
    if (x2 > extents.x2)
        x2 = extents.x2;
    if (y1 < extents.y1)
        y1 = extents.y1;
    if (y2 > extents.y2)
        y2 = extents.y2;

    if (x2 <= x1 || y2 <= y1)
        x2 = x1 = y2 = y1 = 0;

    box.x1 = cast(short)x1;
    box.x2 = cast(short)x2;
    box.y1 = cast(short)y1;
    box.y2 = cast(short)y2;

    RegionInit(&reg, &box, 1);

    RegionIntersect(&reg, &reg, clipList);
    if (generateExposures)
        (*pScreen.WindowExposures) (pWin, &reg);
    else if (pWin.backgroundState != None)
        pScreen.PaintWindow(pWin, &reg, PW_BACKGROUND);
    RegionUninit(&reg);
}

/****************************************************************/

/* not used */
Bool miOverlayGetPrivateClips(WindowPtr pWin, RegionPtr* borderClip, RegionPtr* clipList)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    if (pTree) {
        *borderClip = &(pTree.borderClip);
        *clipList = &(pTree.clipList);
        return TRUE;
    }

    *borderClip = *clipList = null;

    return FALSE;
}

Bool miOverlayCopyUnderlay(ScreenPtr pScreen)
{
    return mixin(MIOVERLAY_GET_SCREEN_PRIVATE!(`pScreen`)).copyUnderlay;
}

void miOverlayComputeCompositeClip(GCPtr pGC, WindowPtr pWin)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));
    RegionPtr pregWin = void;
    Bool freeTmpClip = void, freeCompClip = void;

    if (!pTree) {
        miComputeCompositeClip(pGC, &pWin.drawable);
        return;
    }

    if (pGC.subWindowMode == IncludeInferiors) {
        pregWin = RegionCreate(NullBox, 1);
        freeTmpClip = TRUE;
        if (pWin.parent || (screenIsSaved != SCREEN_SAVER_ON) ||
            !HasSaverWindow(pGC.pScreen)) {
            RegionIntersect(pregWin, &pTree.borderClip, &pWin.winSize);
        }
    }
    else {
        pregWin = &pTree.clipList;
        freeTmpClip = FALSE;
    }
    freeCompClip = pGC.freeCompClip;
    if (!pGC.clientClip) {
        if (freeCompClip)
            RegionDestroy(pGC.pCompositeClip);
        pGC.pCompositeClip = pregWin;
        pGC.freeCompClip = freeTmpClip;
    }
    else {
        RegionTranslate(pGC.clientClip,
                        pWin.drawable.x + pGC.clipOrg.x,
                        pWin.drawable.y + pGC.clipOrg.y);

        if (freeCompClip) {
            RegionIntersect(pGC.pCompositeClip, pregWin, pGC.clientClip);
            if (freeTmpClip)
                RegionDestroy(pregWin);
        }
        else if (freeTmpClip) {
            RegionIntersect(pregWin, pregWin, pGC.clientClip);
            pGC.pCompositeClip = pregWin;
        }
        else {
            pGC.pCompositeClip = RegionCreate(NullBox, 0);
            RegionIntersect(pGC.pCompositeClip, pregWin, pGC.clientClip);
        }
        pGC.freeCompClip = TRUE;
        RegionTranslate(pGC.clientClip,
                        -(pWin.drawable.x + pGC.clipOrg.x),
                        -(pWin.drawable.y + pGC.clipOrg.y));
    }
}

Bool miOverlayCollectUnderlayRegions(WindowPtr pWin, RegionPtr* region)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    if (pTree) {
        *region = &pTree.borderClip;
        return FALSE;
    }

    *region = RegionCreate(NullBox, 0);

    CollectUnderlayChildrenRegions(pWin, *region);

    return TRUE;
}

private miOverlayTreePtr DoLeaf(WindowPtr pWin, miOverlayTreePtr parent, miOverlayTreePtr prevSib)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    pTree.parent = parent;
    pTree.firstChild = null;
    pTree.lastChild = null;
    pTree.prevSib = prevSib;
    pTree.nextSib = null;

    if (prevSib)
        prevSib.nextSib = pTree;

    if (!parent.firstChild)
        parent.firstChild = parent.lastChild = pTree;
    else if (parent.lastChild == prevSib)
        parent.lastChild = pTree;

    return pTree;
}

private void RebuildTree(WindowPtr pWin)
{
    miOverlayTreePtr parent = void, prevSib = void, tChild = void;
    WindowPtr pChild = void;

    prevSib = tChild = null;

    pWin = pWin.parent;

    while (mixin(IN_OVERLAY!(`pWin`)))
        pWin = pWin.parent;

    parent = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    pChild = pWin.firstChild;
    parent.firstChild = parent.lastChild = null;

    while (1) {
        if (mixin(IN_UNDERLAY!(`pChild`)))
            prevSib = tChild = DoLeaf(pChild, parent, prevSib);

        if (pChild.firstChild) {
            if (mixin(IN_UNDERLAY!(`pChild`))) {
                parent = tChild;
                prevSib = null;
            }
            pChild = pChild.firstChild;
            continue;
        }

        while (!pChild.nextSib) {
            pChild = pChild.parent;
            if (pChild == pWin)
                return;
            if (mixin(IN_UNDERLAY!(`pChild`))) {
                prevSib = tChild = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`));
                parent = tChild.parent;
            }
        }

        pChild = pChild.nextSib;
    }
}

private Bool HasUnderlayChildren(WindowPtr pWin)
{
    WindowPtr pChild = void;

    if (((pChild = pWin.firstChild)is null))
        return FALSE;

    while (1) {
        if (mixin(IN_UNDERLAY!(`pChild`)))
            return TRUE;

        if (pChild.firstChild) {
            pChild = pChild.firstChild;
            continue;
        }

        while (!pChild.nextSib && (pWin != pChild))
            pChild = pChild.parent;

        if (pChild == pWin)
            break;

        pChild = pChild.nextSib;
    }

    return FALSE;
}

private Bool CollectUnderlayChildrenRegions(WindowPtr pWin, RegionPtr pReg)
{
    WindowPtr pChild = void;
    miOverlayTreePtr pTree = void;
    Bool hasUnderlay = void;

    if (((pChild = pWin.firstChild) is null))
        return FALSE;

    hasUnderlay = FALSE;

    while (1) {
        if ((pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pChild`)))!is null) {
            RegionAppend(pReg, &pTree.borderClip);
            hasUnderlay = TRUE;
        }
        else if (pChild.firstChild) {
            pChild = pChild.firstChild;
            continue;
        }

        while (!pChild.nextSib && (pWin != pChild))
            pChild = pChild.parent;

        if (pChild == pWin)
            break;

        pChild = pChild.nextSib;
    }

    if (hasUnderlay) {
        Bool overlap = void;

        RegionValidate(pReg, &overlap);
    }

    return hasUnderlay;
}

private void MarkUnderlayWindow(WindowPtr pWin)
{
    miOverlayTreePtr pTree = mixin(MIOVERLAY_GET_WINDOW_TREE!(`pWin`));

    if (pTree.valdata)
        return;
    pTree.valdata =
        cast(miOverlayValDataPtr) XNFalloc(miOverlayValDataRec.sizeof);
    pTree.valdata.oldAbsCorner.x = pWin.drawable.x;
    pTree.valdata.oldAbsCorner.y = pWin.drawable.y;
    pTree.valdata.borderVisible = NullRegion;
}
