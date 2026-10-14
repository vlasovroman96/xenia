module include.micmap;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
 
//public import x11.X;
//public import x11.Xdefs;
// //public import x11.Xfuncproto;

public import dix.colormap;
public import include.privates;
public import include.screenint;
public import mi.micmap;

DevPrivateKeyRec micmapScrPrivateKeyRec;

enum micmapScrPrivateKey = (&micmapScrPrivateKeyRec);

// void  miListInstalledColormaps(ScreenPtr pScreen, Colormap* pmaps);
// void  miInstallColormap(ColormapPtr pmap);
// void  miUninstallColormap(ColormapPtr pmap);
// void  miResolveColor(ushort*, ushort*, ushort*, VisualPtr);
// void  miInitializeColormap(ColormapPtr);
// void  miCreateDefColormap(ScreenPtr);
// void  miClearVisualTypes();
// void  miSetVisualTypes(int, int, int, int);
// void  miSetPixmapDepths();
// void  miSetVisualTypesAndMasks(int depth, int visuals, int bitsPerRGB, int preferredCVC, Pixel redMask, Pixel greenMask, Pixel blueMask);
// void  miGetDefaultVisualMask(int);
// void  miInitVisuals(VisualPtr*, DepthPtr*, int*, int*, int*, VisualID*, c_ulong, int, int);

enum MAX_PSEUDO_DEPTH =	10;

enum StaticColorMask =	(1 << StaticColor);
enum PseudoColorMask =	(1 << PseudoColor);
enum TrueColorMask =	(1 << TrueColor);
enum DirectColorMask =	(1 << DirectColor);

                          /* _MICMAP_H_ */
