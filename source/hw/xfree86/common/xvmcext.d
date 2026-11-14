module hw.xfree86.common.xvmcext;
@nogc nothrow:
extern(C): __gshared:

 
// //public import externs.X11.extensions.Xv;
public import hw.xfree86.common.xvdix;
import x11.Xmd;
import dix.dixstruct_priv;
import dix.input;
struct XvMCImageIDList {
    int num_xvimages;
    int* xvimage_ids;
}

struct _XvMCSurfaceInfoRec {
    int surface_type_id;
    int chroma_format;
    int color_description;
    ushort max_width;
    ushort max_height;
    ushort subpicture_max_width;
    ushort subpicture_max_height;
    int mc_type;
    int flags;
    XvMCImageIDList* compatible_subpictures;
}alias XvMCSurfaceInfoRec = _XvMCSurfaceInfoRec;
alias XvMCSurfaceInfoPtr = XvMCSurfaceInfoRec*;

struct _XvMCContextRec {
    XID context_id;
    ScreenPtr pScreen;
    int adapt_num;
    int surface_type_id;
    ushort width;
    ushort height;
    CARD32 flags;
    int refcnt;
    void* port_priv;
    void* driver_priv;
}alias XvMCContextRec = _XvMCContextRec;
alias XvMCContextPtr = XvMCContextRec*;

struct _XvMCSurfaceRec {
    XID surface_id;
    int surface_type_id;
    XvMCContextPtr context;
    void* driver_priv;
}alias XvMCSurfaceRec = _XvMCSurfaceRec;
alias XvMCSurfacePtr = XvMCSurfaceRec*;

struct _XvMCSubpictureRec {
    XID subpicture_id;
    int xvimage_id;
    ushort width;
    ushort height;
    int num_palette_entries;
    int entry_bytes;
    char[4] component_order = 0;
    XvMCContextPtr context;
    void* driver_priv;
}alias XvMCSubpictureRec = _XvMCSubpictureRec;
alias XvMCSubpicturePtr = XvMCSubpictureRec*;

alias XvMCCreateContextProcPtr = int function(XvPortPtr port, XvMCContextPtr context, int* num_priv, CARD32** priv);

alias XvMCDestroyContextProcPtr = void function(XvMCContextPtr context);

alias XvMCCreateSurfaceProcPtr = int function(XvMCSurfacePtr surface, int* num_priv, CARD32** priv);

alias XvMCDestroySurfaceProcPtr = void function(XvMCSurfacePtr surface);

alias XvMCCreateSubpictureProcPtr = int function(XvMCSubpicturePtr subpicture, int* num_priv, CARD32** priv);

alias XvMCDestroySubpictureProcPtr = void function(XvMCSubpicturePtr subpicture);

struct _XvMCAdaptorRec {
    XvAdaptorPtr xv_adaptor;
    int num_surfaces;
    XvMCSurfaceInfoPtr* surfaces;
    int num_subpictures;
    XvImagePtr* subpictures;
    XvMCCreateContextProcPtr CreateContext;
    XvMCDestroyContextProcPtr DestroyContext;
    XvMCCreateSurfaceProcPtr CreateSurface;
    XvMCDestroySurfaceProcPtr DestroySurface;
    XvMCCreateSubpictureProcPtr CreateSubpicture;
    XvMCDestroySubpictureProcPtr DestroySubpicture;
}alias XvMCAdaptorRec = _XvMCAdaptorRec;
alias XvMCAdaptorPtr = XvMCAdaptorRec*;

// void  XvMCScreenInit(ScreenPtr pScreen, int num, XvMCAdaptorPtr adapt);

// void  xf86XvMCRegisterDRInfo(ScreenPtr pScreen, const(char)* name, const(char)* busID, int major, int minor, int patchLevel);

                          /* _XVMC_H */
