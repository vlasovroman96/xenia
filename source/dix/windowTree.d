module dix.windowTree;

@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;

public import dix.window;
import os.log;
import dix.screenint_priv;

void PrintWindowTree()
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        ErrorF("[dix] Dumping windows for screen %d (pixmap %x):\n", walkScreenIdx,
               cast(uint) walkScreen.GetScreenPixmap(walkScreen).drawable.id);
        WindowPtr pWin = walkScreen.root;
        int depth = 1;
        while (pWin) {
            pWin.logInfo(depth);
            if (pWin.firstChild) {
                pWin = pWin.firstChild;
                depth++;
                continue;
            }
            while (pWin && !pWin.nextSib) {
                pWin = pWin.parent;
                depth--;
            }
            if (!pWin)
                break;
            pWin = pWin.nextSib;
        }
    });
}

int TraverseTree(WindowPtr pWin, VisitWindowProc func, void* data)
{
    int result = void;
    WindowPtr pChild = void;

    if (((pChild = pWin) is null))
        return WinTreeWalking.NoMatch;
    while (1) {
        result = (*func) (pChild, data);
        if (result == WinTreeWalking.Stop)
            return WinTreeWalking.Stop;
        if ((result == WinTreeWalking.ToChild) && pChild.firstChild) {
            pChild = pChild.firstChild;
            continue;
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            break;
        pChild = pChild.nextSib;
    }
    return WinTreeWalking.NoMatch;
}

/*****
 * WalkTree
 *   Walk the window tree, for SCREEN, performing FUNC(pWin, data) on
 *   each window.  If FUNC returns WinTreeWalking.ToChild, traverse the children,
 *   if it returns WinTreeWalking.DontWalkChild, don't.  If it returns WinTreeWalking.Stop,
 *   exit WalkTree.  Does depth-first traverse.
 *****/

int WalkTree(ScreenPtr pScreen, VisitWindowProc func, void* data)
{
    return (TraverseTree(pScreen.root, func, data));
}