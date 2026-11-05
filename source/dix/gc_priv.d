module dix.gc_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 * Copyright © 1987, 1998  The Open Group
 */
 
public import dix.gc;

enum GCAllBits = ((1 << (GCLastBit + 1)) - 1);

// int ChangeGCXIDs(ClientPtr client, GCPtr pGC, BITS32 mask, CARD32* pval);

// GCPtr CreateGC(DrawablePtr pDrawable, BITS32 mask, XID* pval, int* pStatus, XID gcid, ClientPtr client);

// int CopyGC(GCPtr pgcSrc, GCPtr pgcDst, BITS32 mask);

// int FreeGC(void* pGC, XID gid);

// void FreeGCperDepth(ScreenPtr pScreen);

// Bool CreateGCperDepth(ScreenPtr pScreen);

// Bool CreateDefaultStipple(ScreenPtr pScreen);

// int SetDashes(GCPtr pGC, uint offset, uint ndash, ubyte* pdash);

// int VerifyRectOrder(int nrects, xRectangle* prects, int ordering);

// int SetClipRects(GCPtr pGC, INT16 xOrigin, INT16 yOrigin, size_t nrects, xRectangle* prects, BYTE ordering);

 /* _XSERVER_DIX_GC_PRIV_H */
