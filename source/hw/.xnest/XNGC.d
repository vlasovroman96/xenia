module XNGC;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/

 
//public import x11.Xdefs;

public import dix.gc;
public import include.privates;

struct xnestPrivGC {
    uint gc;
}

DevPrivateKeyRec xnestGCPrivateKeyRec;

enum xnestGCPrivateKey = (&xnestGCPrivateKeyRec);

enum string xnestGCPriv(string pGC) = `(cast(xnestPrivGC*) 
    dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, xnestGCPrivateKey))`;

enum string xnestGC(string pGC) = `(` ~ xnestGCPriv!(pGC) ~ `.gc)`;

Bool xnestCreateGC(GCPtr pGC);
void xnestValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDrawable);
void xnestChangeGC(GCPtr pGC, c_ulong mask);
void xnestCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst);
void xnestDestroyGC(GCPtr pGC);
void xnestChangeClip(GCPtr pGC, int type, void* pValue, int nRects);
void xnestDestroyClip(GCPtr pGC);
void xnestCopyClip(GCPtr pGCDst, GCPtr pGCSrc);

                          /* XNESTGC_H */
