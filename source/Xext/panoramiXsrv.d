module Xext.panoramiXsrv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
 
public import build.dix_config;

public import Xext.panoramiX;
public import externs.pixman;
import include.regionstr;
import x11.Xproto;
import include.screenint;
import include.pixmap;
import dix.resource;

// int PanoramiXNumScreens;
// int PanoramiXPixWidth;
// int PanoramiXPixHeight;
// RegionRec PanoramiXScreenRegion;

// exported for nvidia
// export VisualID PanoramiXTranslateVisualID(int screen, VisualID orig);

// void PanoramiXConsolidate();
// Bool PanoramiXCreateConnectionBlock();
// PanoramiXRes* PanoramiXFindIDByScrnum(RESTYPE, XID, int);
// Bool XineramaRegisterConnectionBlockCallback(void function() func);
// int XineramaDeleteResource(void*, XID);

/* only exported for Nvidia legacy. This really shouldn't be used by drivers */
// RESTYPE XRC_DRAWABLE;

// RESTYPE XRT_WINDOW;
// RESTYPE XRT_PIXMAP;
// RESTYPE XRT_GC;
// RESTYPE XRT_COLORMAP;
// RESTYPE XRT_PICTURE;

/*
 * Drivers are allowed to wrap this function.  Each wrapper can decide that the
 * two visuals are unequal, but if they are deemed equal, the wrapper must call
 * down and return FALSE if the wrapped function does.  This ensures that all
 * layers agree that the visuals are equal.  The first visual is always from
 * screen 0.
 */
alias XineramaVisualsEqualProcPtr = Bool function(VisualPtr, ScreenPtr, VisualPtr);

// void XineramaGetImageData(DrawablePtr* pDrawables, int left, int top, int width, int height, uint format, c_ulong planemask, char* data, int pitch, Bool isRoot);

pragma(inline, true) void panoramix_setup_ids(PanoramiXRes* resource, ClientPtr client, XID base_id)
{
    resource.info[0].id = base_id;
    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
        resource.info[walkScreenIdx].id = FakeClientID(client.index);
    }));
}

                          /* _PANORAMIXSRV_H_ */
