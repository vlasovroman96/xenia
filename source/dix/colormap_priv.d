module dix.colormap_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;
//public import x11.Xproto;

public import dix.screenint_priv;
public import dix.colormap;
public import dix.colormap;
public import include.dix;
public import include.window;

/* Values for the flags field of a colormap. These should have 1 bit set
 * and not overlap */
enum CM_IsDefault = 1;
enum CM_AllAllocated = 2;
enum CM_BeingCreated = 4;

/* Shared color -- the color is used by AllocColorPlanes */
struct SHAREDCOLOR {
    ushort color;
    short refcnt;
}

/* SHCO -- a shared color for a PseudoColor cell. Used with AllocColorPlanes.
 * DirectColor maps always use the first value (called red) in the structure.
 * What channel they are really talking about depends on which map they
 * are in. */
struct SHCO {
    SHAREDCOLOR* red, green, blue;
}

/* color map entry */
struct _CMEntry {
    union _Co {
        LOCO local;
        SHCO shco;
    }_Co co;
    short refcnt;
    Bool fShared;
}alias Entry = _CMEntry;
alias EntryPtr = _CMEntry*;

/* COLORMAPs can be used for either Direct or Pseudo color.  PseudoColor
 * only needs one cell table, we arbitrarily pick red.  We keep track
 * of that table with freeRed, numPixelsRed, and clientPixelsRed */

struct _ColormapRec {
    VisualPtr pVisual;
    short class_;                /* PseudoColor or DirectColor */
    XID mid;                    /* client's name for colormap */
    ScreenPtr pScreen;          /* screen map is associated with */
    short flags;                /* 1 = CM_IsDefault
                                 * 2 = CM_AllAllocated */
    int freeRed;
    int freeGreen;
    int freeBlue;
    int* numPixelsRed;
    int* numPixelsGreen;
    int* numPixelsBlue;
    Pixel** clientPixelsRed;
    Pixel** clientPixelsGreen;
    Pixel** clientPixelsBlue;
    Entry* red;
    Entry* green;
    Entry* blue;
    PrivateRec* devPrivates;
}

alias ColormapRec = _ColormapRec;

// int dixCreateColormap(Colormap mid, ScreenPtr pScreen, VisualPtr pVisual, ColormapPtr* ppcmap, int alloc, ClientPtr client);

/* should only be called via resource type's destructor */
// int FreeColormap(void* pmap, XID mid);

// int TellLostMap(WindowPtr pwin, void* value);

// int TellGainedMap(WindowPtr pwin, void* value);

// int CopyColormapAndFree(Colormap mid, ColormapPtr pSrc, int client);

// void  AllocColor(ColormapPtr pmap, ushort* pred, ushort* pgreen, ushort* pblue, Pixel* pPix, int client);

// void FakeAllocColor(ColormapPtr pmap, xColorItem* item);

// void FakeFreeColor(ColormapPtr pmap, Pixel pixel);

// int QueryColors(ColormapPtr pmap, int count, Pixel* ppixIn, xrgb* prgbList, ClientPtr client);

/* should only be called via resource type's destructor */
// int FreeClientPixels(void* pcr, XID fakeid);

// int AllocColorCells(ClientPtr pClient, ColormapPtr pmap, int colors, int planes, Bool contig, Pixel* ppix, Pixel* masks);

// int AllocColorPlanes(int client, ColormapPtr pmap, int colors, int r, int g, int b, Bool contig, Pixel* pixels, Pixel* prmask, Pixel* pgmask, Pixel* pbmask);

// int FreeColors(ColormapPtr pmap, int client, int count, Pixel* pixels, Pixel mask);

// int StoreColors(ColormapPtr pmap, int count, xColorItem* defs, ClientPtr client);

// int IsMapInstalled(Colormap map, WindowPtr pWin);

/* only exported for glx, but should not be used by external drivers */
// Bool ResizeVisualArray(ScreenPtr pScreen, int new_vis_count, DepthPtr depth);

 /* _XSERVER_DIX_COLORMAP_PRIV_H */
