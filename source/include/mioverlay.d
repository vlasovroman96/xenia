module include.mioverlay;
@nogc nothrow:
extern(C): __gshared:
 
//public import x11.Xdefs;
// //public import x11.Xfuncproto;
import include.scrintstr;
import include.xlibre_ptrtypes;


alias miOverlayTransFunc = void function(ScreenPtr, int, BoxPtr);
alias miOverlayInOverlayFunc = Bool function(WindowPtr);

void  miInitOverlay(ScreenPtr pScreen, miOverlayInOverlayFunc inOverlay, miOverlayTransFunc trans);

void  miOverlayGetPrivateClips(WindowPtr pWin, RegionPtr* borderClip, RegionPtr* clipList);

void  miOverlayCollectUnderlayRegions(WindowPtr, RegionPtr*);
void  miOverlayComputeCompositeClip(GCPtr, WindowPtr);
void  miOverlayCopyUnderlay(ScreenPtr);
void  miOverlaySetRootClip(ScreenPtr, Bool);

                          /* __MIOVERLAY_H */
