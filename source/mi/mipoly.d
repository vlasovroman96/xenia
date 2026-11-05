module mipoly;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/
/*
 *  mipoly.c
 *
 *  Written by Brian Kelleher; June 1986
 */
import build.dix_config;

//import x11.X;
import dix.window;
import dix.gc;
import dix.pixmap;
import miscanfill;
import mipoly;
import region;

enum NUMPTSTOBUFFER = 200;

enum string EVALUATEEDGEEVENODD(string pAET, string pPrevAET, string y) =`
{ 
   if ((`~pAET~`).ymax == (`~y~`)) {          /* leaving this edge */ 
      (`~pPrevAET~`).next = (`~pAET~`).next; 
      (`~pAET~`) = (`~pPrevAET~`).next; 
      if ((`~pAET~`)) 
         (`~pAET~`).back = (`~pPrevAET~`); 
   } 
   else { 
      `~BRESINCRPGONSTRUCT!(`(`~pAET~`).bres`)~`; 
      (`~pPrevAET~`) = (`~pAET~`); 
      (`~pAET~`) = (`~pAET~`).next; 
   } 
}`;

enum string EVALUATEEDGEWINDING(string pAET, string pPrevAET, string y, string fixWAET) =`
{ 
   if ((`~pAET~`).ymax == (`~y~`)) {          /* leaving this edge */ 
      (`~pPrevAET~`).next = (`~pAET~`).next; 
      (`~pAET~`) = (`~pPrevAET~`).next; 
      (`~fixWAET~`) = 1; 
      if ((`~pAET~`)) 
         (`~pAET~`).back = (`~pPrevAET~`); 
   } 
   else { 
      `~BRESINCRPGONSTRUCT!(`(`~pAET~`).bres`)~`; 
      (`~pPrevAET~`) = (`~pAET~`); 
      (`~pAET~`) = (`~pAET~`).next; 
   } 
}`;

struct EdgeTable{
    int ymax;                   /* ymax for the polygon     */
    int ymin;                   /* ymin for the polygon     */
    ScanLineList scanlines;     /* header node              */
} ;

struct _EdgeTableEntry {
    int ymax;                   /* ycoord at which we exit this edge. */
    BRESINFO bres;              /* Bresenham info to run the edge     */
    _EdgeTableEntry *next;       /* next in the list     */
    _EdgeTableEntry *back;       /* for insertion sort   */
    _EdgeTableEntry *nextWETE;   /* for winding num rule */
    int ClockWise;              /* flag for winding number rule       */
}
alias EdgeTableEntry = _EdgeTableEntry;

struct _ScanLineList {
    int scanline;               /* the scanline represented */
    EdgeTableEntry *edgelist;   /* header node              */
    _ScanLineList *next; /* next in the list       */
} 
alias ScanLineList = _ScanLineList;

enum SLLSPERBLOCK = 25;

struct _ScanLineListBlock {
    ScanLineList[SLLSPERBLOCK] SLLs;
    _ScanLineListBlock *next;
} 
alias ScanLineListBlock = _ScanLineListBlock;
/*
 * Insert the given edge into the edge table.  First we must find the correct
 * bucket in the Edge table, then find the right slot in the bucket.  Finally,
 * we can insert it.
 */
private Bool miInsertEdgeInET(EdgeTable* ET, EdgeTableEntry* ETE, int scanline, ScanLineListBlock** SLLBlock, int* iSLLBlock)
{
    EdgeTableEntry* start = void, prev = void;
    ScanLineList* pSLL = void, pPrevSLL = void;
    ScanLineListBlock* tmpSLLBlock = void;

    /*
     * find the right bucket to put the edge into
     */
    pPrevSLL = &ET.scanlines;
    pSLL = pPrevSLL.next;
    while (pSLL && (pSLL.scanline < scanline)) {
        pPrevSLL = pSLL;
        pSLL = pSLL.next;
    }

    /*
     * reassign pSLL (pointer to ScanLineList) if necessary
     */
    if ((!pSLL) || (pSLL.scanline > scanline)) {
        if (*iSLLBlock > SLLSPERBLOCK - 1) {
            tmpSLLBlock = cast(ScanLineListBlock*) cast(ScanLineListBlock*) calloc(1, ScanLineListBlock.sizeof);
            if (!tmpSLLBlock)
                return FALSE;
            (*SLLBlock).next = tmpSLLBlock;
            tmpSLLBlock.next = null;
            *SLLBlock = tmpSLLBlock;
            *iSLLBlock = 0;
        }
        pSLL = &((*SLLBlock).SLLs[(*iSLLBlock)++]);

        pSLL.next = pPrevSLL.next;
        pSLL.edgelist = null;
        pPrevSLL.next = pSLL;
    }
    pSLL.scanline = scanline;

    /*
     * now insert the edge in the right bucket
     */
    prev = null;
    start = pSLL.edgelist;
    while (start && (start.bres.minor < ETE.bres.minor)) {
        prev = start;
        start = start.next;
    }
    ETE.next = start;

    if (prev)
        prev.next = ETE;
    else
        pSLL.edgelist = ETE;
    return TRUE;
}

private void miFreeStorage(ScanLineListBlock* pSLLBlock)
{
    ScanLineListBlock* tmpSLLBlock = void;

    while (pSLLBlock) {
        tmpSLLBlock = pSLLBlock.next;
        free(pSLLBlock);
        pSLLBlock = tmpSLLBlock;
    }
}

/*
 * CreateEdgeTable
 *
 * This routine creates the edge table for scan converting polygons.
 * The Edge Table (ET) looks like:
 *
 * EdgeTable
 *  --------
 * |  ymax  |        ScanLineLists
 * |scanline|-->------------>-------------->...
 *  --------   |scanline|   |scanline|
 *             |edgelist|   |edgelist|
 *             ---------    ---------
 *                 |             |
 *                 |             |
 *                 V             V
 *           list of ETEs   list of ETEs
 *
 * where ETE is an EdgeTableEntry data structure, and there is one ScanLineList
 * per scanline at which an edge is initially entered.
 */

private Bool miCreateETandAET(int count, DDXPointPtr pts, EdgeTable* ET, EdgeTableEntry* AET, EdgeTableEntry* pETEs, ScanLineListBlock* pSLLBlock)
{
    DDXPointPtr top = void, bottom = void;
    DDXPointPtr PrevPt = void, CurrPt = void;
    int iSLLBlock = 0;

    int dy = void;

    if (count < 2)
        return TRUE;

    /*
     *  initialize the Active Edge Table
     */
    AET.next = null;
    AET.back = null;
    AET.nextWETE = null;
    AET.bres.minor = MININT;

    /*
     *  initialize the Edge Table.
     */
    ET.scanlines.next = null;
    ET.ymax = MININT;
    ET.ymin = MAXINT;
    pSLLBlock.next = null;

    PrevPt = &pts[count - 1];

    /*
     *  for each vertex in the array of points.
     *  In this loop we are dealing with two vertices at
     *  a time -- these make up one edge of the polygon.
     */
    while (count--) {
        CurrPt = pts++;

        /*
         *  find out which point is above and which is below.
         */
        if (PrevPt.y > CurrPt.y) {
            bottom = PrevPt, top = CurrPt;
            pETEs.ClockWise = 0;
        }
        else {
            bottom = CurrPt, top = PrevPt;
            pETEs.ClockWise = 1;
        }

        /*
         * don't add horizontal edges to the Edge table.
         */
        if (bottom.y != top.y) {
            pETEs.ymax = bottom.y - 1; /* -1 so we don't get last scanline */

            /*
             *  initialize integer edge algorithm
             */
            dy = bottom.y - top.y;
            mixin(BRESINITPGONSTRUCT!("dy", "top.x", "bottom.x", "pETEs.bres"));

            if (!miInsertEdgeInET(ET, pETEs, top.y, &pSLLBlock, &iSLLBlock)) {
                miFreeStorage(pSLLBlock.next);
                return FALSE;
            }

            ET.ymax = max(ET.ymax, PrevPt.y);
            ET.ymin = min(ET.ymin, PrevPt.y);
            pETEs++;
        }

        PrevPt = CurrPt;
    }
    return TRUE;
}

/*
 * This routine moves EdgeTableEntries from the EdgeTable into the Active Edge
 * Table, leaving them sorted by smaller x coordinate.
 */

private void miloadAET(EdgeTableEntry* AET, EdgeTableEntry* ETEs)
{
    EdgeTableEntry* pPrevAET = void;
    EdgeTableEntry* tmp = void;

    pPrevAET = AET;
    AET = AET.next;
    while (ETEs) {
        while (AET && (AET.bres.minor < ETEs.bres.minor)) {
            pPrevAET = AET;
            AET = AET.next;
        }
        tmp = ETEs.next;
        ETEs.next = AET;
        if (AET)
            AET.back = ETEs;
        ETEs.back = pPrevAET;
        pPrevAET.next = ETEs;
        pPrevAET = ETEs;

        ETEs = tmp;
    }
}

/*
 * computeWAET
 *
 * This routine links the AET by the nextWETE (winding EdgeTableEntry) link for
 * use by the winding number rule.  The final Active Edge Table (AET) might
 * look something like:
 *
 * AET
 * ----------  ---------   ---------
 * |ymax    |  |ymax    |  |ymax    |
 * | ...    |  |...     |  |...     |
 * |next    |->|next    |->|next    |->...
 * |nextWETE|  |nextWETE|  |nextWETE|
 * ---------   ---------   ^--------
 *     |                   |       |
 *     V------------------->       V---> ...
 *
 */
private void micomputeWAET(EdgeTableEntry* AET)
{
    EdgeTableEntry* pWETE = void;
    int inside = 1;
    int isInside = 0;

    AET.nextWETE = null;
    pWETE = AET;
    AET = AET.next;
    while (AET) {
        if (AET.ClockWise)
            isInside++;
        else
            isInside--;

        if ((!inside && !isInside) || (inside && isInside)) {
            pWETE.nextWETE = AET;
            pWETE = AET;
            inside = !inside;
        }
        AET = AET.next;
    }
    pWETE.nextWETE = null;
}

/*
 * Just a simple insertion sort using pointers and back pointers to sort the
 * Active Edge Table.
 */

private int miInsertionSort(EdgeTableEntry* AET)
{
    EdgeTableEntry* pETEchase = void;
    EdgeTableEntry* pETEinsert = void;
    EdgeTableEntry* pETEchaseBackTMP = void;
    int changed = 0;

    AET = AET.next;
    while (AET) {
        pETEinsert = AET;
        pETEchase = AET;
        while (pETEchase.back.bres.minor > AET.bres.minor)
            pETEchase = pETEchase.back;

        AET = AET.next;
        if (pETEchase != pETEinsert) {
            pETEchaseBackTMP = pETEchase.back;
            pETEinsert.back.next = AET;
            if (AET)
                AET.back = pETEinsert.back;
            pETEinsert.next = pETEchase;
            pETEchase.back.next = pETEinsert;
            pETEchase.back = pETEinsert;
            pETEinsert.back = pETEchaseBackTMP;
            changed = 1;
        }
    }
    return changed;
}

/* Find the index of the point with the smallest y */
private int getPolyYBounds(DDXPointPtr pts, int n, int* by, int* ty)
{
    DDXPointPtr ptMin = void;
    int ymin = void, ymax = void;
    DDXPointPtr ptsStart = pts;

    ptMin = pts;
    ymin = ymax = (pts++).y;

    while (--n > 0) {
        if (pts.y < ymin) {
            ptMin = pts;
            ymin = pts.y;
        }
        if (pts.y > ymax)
            ymax = pts.y;

        pts++;
    }

    *by = ymin;
    *ty = ymax;
    return cast(int)(ptMin - ptsStart);
}

/*
 * Written by Brian Kelleher; Dec. 1985.
 *
 * Fill a convex polygon.  If the given polygon is not convex, then the result
 * is undefined.  The algorithm is to order the edges from smallest y to
 * largest by partitioning the array into a left edge list and a right edge
 * list.  The algorithm used to traverse each edge is an extension of
 * Bresenham's line algorithm with y as the major axis.  For a derivation of
 * the algorithm, see the author of this code.
 */
private Bool miFillConvexPoly(DrawablePtr dst, GCPtr pgc, int count, DDXPointPtr ptsIn)
{
    int xl = 0, xr = 0;         /* x vals of left and right edges */
    int dl = 0, dr = 0;         /* decision variables             */
    int ml = 0, m1l = 0;        /* left edge slope and slope+1    */
    int mr = 0, m1r = 0;        /* right edge slope and slope+1   */
    int incr1l = 0, incr2l = 0; /* left edge error increments     */
    int incr1r = 0, incr2r = 0; /* right edge error increments    */
    int dy = void;                     /* delta y                        */
    int y = void;                      /* current scanline               */
    int left = void, right = void;            /* indices to first endpoints     */
    int i = void;                      /* loop counter                   */
    int nextleft = void, nextright = void;    /* indices to second endpoints    */
    DDXPointPtr ptsOut = void, FirstPoint = void;     /* output buffer               */
    int* width = void, FirstWidth = void;    /* output buffer                  */
    int imin = void;                   /* index of smallest vertex (in y) */
    int ymin = void;                   /* y-extents of polygon            */
    int ymax = void;

    /*
     *  find leftx, bottomy, rightx, topy, and the index
     *  of bottomy. Also translate the points.
     */
    imin = getPolyYBounds(ptsIn, count, &ymin, &ymax);

    dy = ymax - ymin + 1;
    if ((count < 3) || (dy < 0))
        return TRUE;
    ptsOut = FirstPoint = cast(xPoint*)calloc(dy, xPoint.sizeof);
    width = FirstWidth = cast(int*) calloc(dy, int.sizeof);
    if (!FirstPoint || !FirstWidth) {
        free(FirstWidth);
        free(FirstPoint);
        return FALSE;
    }

    nextleft = nextright = imin;
    y = ptsIn[nextleft].y;

    /*
     *  loop through all edges of the polygon
     */
    do {
        /*
         *  add a left edge if we need to
         */
        if (ptsIn[nextleft].y == y) {
            left = nextleft;

            /*
             *  find the next edge, considering the end
             *  conditions of the array.
             */
            nextleft++;
            if (nextleft >= count)
                nextleft = 0;

            /*
             *  now compute all of the random information
             *  needed to run the iterative algorithm.
             */
            mixin(BRESINITPGON!("ptsIn[nextleft].y - ptsIn[left].y",
                         "ptsIn[left].x", "ptsIn[nextleft].x",
                         "xl", "dl", "ml", "m1l", "incr1l", "incr2l"));
        }

        /*
         *  add a right edge if we need to
         */
        if (ptsIn[nextright].y == y) {
            right = nextright;

            /*
             *  find the next edge, considering the end
             *  conditions of the array.
             */
            nextright--;
            if (nextright < 0)
                nextright = count - 1;

            /*
             *  now compute all of the random information
             *  needed to run the iterative algorithm.
             */
            mixin(BRESINITPGON!("ptsIn[nextright].y - ptsIn[right].y",
                         "ptsIn[right].x", "ptsIn[nextright].x",
                         "xr", "dr", "mr", "m1r", "incr1r", "incr2r"));
        }

        /*
         *  generate scans to fill while we still have
         *  a right edge as well as a left edge.
         */
        i = min(ptsIn[nextleft].y, ptsIn[nextright].y) - y;
        /* in case we're called with non-convex polygon */
        if (i < 0) {
            free(FirstWidth);
            free(FirstPoint);
            return TRUE;
        }
        while (i-- > 0) {
            ptsOut.y = cast(short)y;

            /*
             *  reverse the edges if necessary
             */
            if (xl < xr) {
                *(width++) = xr - xl;
                (ptsOut++).x = cast(short)xl;
            }
            else {
                *(width++) = xl - xr;
                (ptsOut++).x = cast(short)xr;
            }
            y++;

            /* increment down the edges */
            mixin(BRESINCRPGON!("dl", "xl", "ml", "m1l", "incr1l", "incr2l"));
            mixin(BRESINCRPGON!("dr", "xr", "mr", "m1r", "incr1r", "incr2r"));
        }
    } while (y != ymax);

    /*
     * Finally, fill the <remaining> spans
     */
    (*pgc.ops.FillSpans) (dst, pgc,
                            cast(int)(ptsOut - FirstPoint), FirstPoint, FirstWidth, 1);
    free(FirstWidth);
    free(FirstPoint);
    return TRUE;
}

/*
 * Written by Brian Kelleher;  Oct. 1985
 *
 * Routine to fill a polygon.  Two fill rules are supported: frWINDING and
 * frEVENODD.
 */
private Bool miFillGeneralPoly(DrawablePtr dst, GCPtr pgc, int count, DDXPointPtr ptsIn)
{
    EdgeTableEntry* pAET = void;       /* the Active Edge Table   */
    int y = void;                      /* the current scanline    */
    int nPts = 0;               /* number of pts in buffer */
    EdgeTableEntry* pWETE = void;      /* Winding Edge Table      */
    ScanLineList* pSLL = void;         /* Current ScanLineList    */
    DDXPointPtr ptsOut = void;         /* ptr to output buffers   */
    int* width = void;
    xPoint[NUMPTSTOBUFFER] FirstPoint = void;     /* the output buffers */
    int[NUMPTSTOBUFFER] FirstWidth = void;
    EdgeTableEntry* pPrevAET = void;   /* previous AET entry      */
    EdgeTable ET = void;               /* Edge Table header node  */
    EdgeTableEntry AET = void;         /* Active ET header node   */
    EdgeTableEntry* pETEs = void;      /* Edge Table Entries buff */
    ScanLineListBlock SLLBlock = void; /* header for ScanLineList */
    int fixWAET = 0;

    if (count < 3)
        return TRUE;

    if (((pETEs = cast(EdgeTableEntry*) calloc(count, EdgeTableEntry.sizeof)) is null))
        return FALSE;
    ptsOut = FirstPoint.ptr;
    width = FirstWidth.ptr;
    if (!miCreateETandAET(count, ptsIn, &ET, &AET, pETEs, &SLLBlock)) {
        free(pETEs);
        return FALSE;
    }
    pSLL = ET.scanlines.next;

    if (pgc.fillRule == EvenOddRule) {
        /*
         *  for each scanline
         */
        for (y = ET.ymin; y < ET.ymax; y++) {
            /*
             *  Add a new edge to the active edge table when we
             *  get to the next edge.
             */
            if (pSLL && y == pSLL.scanline) {
                miloadAET(&AET, pSLL.edgelist);
                pSLL = pSLL.next;
            }
            pPrevAET = &AET;
            pAET = AET.next;

            /*
             *  for each active edge
             */
            while (pAET) {
                ptsOut.x = cast(short)pAET.bres.minor;
                ptsOut++.y = cast(short)y;
                *width++ = pAET.next.bres.minor - pAET.bres.minor;
                nPts++;

                /*
                 *  send out the buffer when its full
                 */
                if (nPts == NUMPTSTOBUFFER) {
                    (*pgc.ops.FillSpans) (dst, pgc,
                                            nPts, FirstPoint.ptr, FirstWidth.ptr, 1);
                    ptsOut = FirstPoint.ptr;
                    width = FirstWidth.ptr;
                    nPts = 0;
                }
                if (pAET !is null) { // FIXME: somewhow analyzer still complains
                    mixin(EVALUATEEDGEEVENODD!("pAET", "pPrevAET", "y"));
                    mixin(EVALUATEEDGEEVENODD!("pAET", "pPrevAET", "y"));
                }
            }
            miInsertionSort(&AET);
        }
    }
    else {                      /* default to WindingNumber */

        /*
         *  for each scanline
         */
        for (y = ET.ymin; y < ET.ymax; y++) {
            /*
             *  Add a new edge to the active edge table when we
             *  get to the next edge.
             */
            if (pSLL && y == pSLL.scanline) {
                miloadAET(&AET, pSLL.edgelist);
                micomputeWAET(&AET);
                pSLL = pSLL.next;
            }
            pPrevAET = &AET;
            pAET = AET.next;
            pWETE = pAET;

            /*
             *  for each active edge
             */
            while (pAET) {
                /*
                 *  if the next edge in the active edge table is
                 *  also the next edge in the winding active edge
                 *  table.
                 */
                if (pWETE == pAET) {
                    ptsOut.x = cast(short)pAET.bres.minor;
                    ptsOut++.y = cast(short)y;
                    *width++ = pAET.nextWETE.bres.minor - pAET.bres.minor;
                    nPts++;

                    /*
                     *  send out the buffer
                     */
                    if (nPts == NUMPTSTOBUFFER) {
                        (*pgc.ops.FillSpans) (dst, pgc, nPts, FirstPoint.ptr,
                                                FirstWidth.ptr, 1);
                        ptsOut = FirstPoint.ptr;
                        width = FirstWidth.ptr;
                        nPts = 0;
                    }

                    pWETE = pWETE.nextWETE;
                    while (pWETE != pAET)
                        mixin(EVALUATEEDGEWINDING!("pAET", "pPrevAET", "y", "fixWAET"));
                    pWETE = pWETE.nextWETE;
                }
                mixin(EVALUATEEDGEWINDING!("pAET", "pPrevAET", "y", "fixWAET"));
            }

            /*
             *  reevaluate the Winding active edge table if we
             *  just had to resort it or if we just exited an edge.
             */
            if (miInsertionSort(&AET) || fixWAET) {
                micomputeWAET(&AET);
                fixWAET = 0;
            }
        }
    }

    /*
     *     Get any spans that we missed by buffering
     */
    (*pgc.ops.FillSpans) (dst, pgc, nPts, FirstPoint.ptr, FirstWidth.ptr, 1);
    free(pETEs);
    miFreeStorage(SLLBlock.next);
    return TRUE;
}

/*
 *  Draw polygons.  This routine translates the point by the origin if
 *  pGC->miTranslate is non-zero, and calls to the appropriate routine to
 *  actually scan convert the polygon.
 */
void miFillPolygon(DrawablePtr dst, GCPtr pgc, int shape, int mode, int count, DDXPointPtr pPts)
{
    int i = void;
    int xorg = void, yorg = void;
    DDXPointPtr ppt = void;

    if (count == 0)
        return;

    ppt = pPts;
    if (pgc.miTranslate) {
        xorg = dst.x;
        yorg = dst.y;

        if (mode == CoordModeOrigin) {
            for (i = 0; i < count; i++) {
                ppt.x += xorg;
                ppt++.y += yorg;
            }
        }
        else {
            ppt.x += xorg;
            ppt++.y += yorg;
            for (i = 1; i < count; i++) {
                ppt.x += (ppt - 1).x;
                ppt.y += (ppt - 1).y;
                ppt++;
            }
        }
    }
    else {
        if (mode == CoordModePrevious) {
            ppt++;
            for (i = 1; i < count; i++) {
                ppt.x += (ppt - 1).x;
                ppt.y += (ppt - 1).y;
                ppt++;
            }
        }
    }
    if (shape == Convex)
        miFillConvexPoly(dst, pgc, count, pPts);
    else
        miFillGeneralPoly(dst, pgc, count, pPts);
}
