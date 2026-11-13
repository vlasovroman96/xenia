module miwideline;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1988, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

Copyright 1989 by Digital Equipment Corporation, Maynard, Massachusetts.

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
*/

/* Author:  Keith Packard, MIT X Consortium */

/*
 * Mostly integer wideline code.  Uses a technique similar to
 * bresenham zero-width lines, except walks an X edge
 */

import build.dix_config;

import core.stdc.stdio;
version (_XOPEN_SOURCE) {
import core.stdc.math;
} else {
// version = _XOPEN_SOURCE;           /* to get prototype for hypot on some systems */
import core.stdc.math;
}
//import x11.X;

import mi.mi_priv;
import os.osdep;

import dix.window;
import region;
import miwideline;
import dix.gc;
import mi.mifpoly;
import mizerline;

enum string MILINESETPIXEL(string pDrawable, string pGC, string pixel, string oldPixel) =
`{ 
    (`~oldPixel~`) = (`~pGC~`).fgPixel; 
    if ((`~pixel~`) != (`~oldPixel~`)) { 
        ChangeGCVal gcval; 
        gcval.val = cast(uint)(`~pixel~`); 
        ChangeGC (null, (`~pGC~`), cast(uint)GCForeground, &gcval); 
        ValidateGC ((`~pDrawable~`), (`~pGC~`)); 
    }
}`;

enum string MILINERESETPIXEL(string pDrawable, string pGC, string pixel, string oldPixel) =
`{ 
    if ((`~pixel~`) != (`~oldPixel~`)) { 
        ChangeGCVal gcval; 
        gcval.val = cast(uint)(`~oldPixel~`); 
        ChangeGC (null, (`~pGC~`), cast(uint)GCForeground, &gcval); 
        ValidateGC ((`~pDrawable~`), (`~pGC~`)); 
    } 
}`;

struct _PolyEdge {
    int height;                 /* number of scanlines to process */
    int x;                      /* starting x coordinate */
    int stepx;                  /* fixed integral dx */
    int signdx;                 /* variable dx sign */
    int e;                      /* initial error term */
    int dy;
    int dx;
}

alias PolyEdgeRec = _PolyEdge;
alias PolyEdgePtr = PolyEdgeRec*;

enum SQSECANT = 108.856472512142;       /* 1/sin^2(11/2) - miter limit constant */

/*
 * types for general polygon routines
 */

struct _PolyVertex {
    double x, y;
} 
alias PolyVertexRec = _PolyVertex;
alias PolyVertexPtr = _PolyVertex*;

struct _PolySlope {
    int dx, dy;
    double k;                   /* x0 * dy - y0 * dx */
} 
alias PolySlopeRec = _PolySlope;
alias PolySlopePtr = _PolySlope*;

/*
 * Line face description for caps/joins
 */

struct _LineFace {
    double xa, ya;
    int dx, dy;
    int x, y;
    double k;
} 
alias LineFaceRec = _LineFace;
alias LineFacePtr = LineFaceRec*;

struct Spans {
    int count;                  /* number of spans                  */
    xPoint* points;         /* pointer to list of start points  */
    int* widths;                /* pointer to list of widths        */
}

struct SpanGroup {
    int size;                   /* Total number of *Spans allocated     */
    int count;                  /* Number of *Spans actually in group   */
    Spans* group;               /* List of Spans                        */
    int ymin, ymax;             /* Min, max y values encountered        */
}

/* Rops which must use span groups */
enum string miSpansCarefulRop(string rop) = `(((` ~ rop ~ `) & 0xc) == 0x8 || ((` ~ rop ~ `) & 0x3) == 0x2)`;
enum string miSpansEasyRop(string rop) = `(!` ~ miSpansCarefulRop!(rop) ~ `)`;

/*

These routines maintain lists of Spans, in order to implement the
``touch-each-pixel-once'' rules of wide lines and arcs.

Written by Joel McCormack, Summer 1989.

*/

private void miInitSpanGroup(SpanGroup* spanGroup)
{
    spanGroup.size = 0;
    spanGroup.count = 0;
    spanGroup.group = null;
    spanGroup.ymin = SHRT_MAX;
    spanGroup.ymax = SHRT_MIN;
}                               /* InitSpanGroup */

enum string YMIN(string spans) = `(` ~ spans ~ `.points[0].y)`;
enum string YMAX(string spans) = `(` ~ spans ~ `.points[` ~ spans ~ `.count-1].y)`;

private void miSubtractSpans(SpanGroup* spanGroup, Spans* sub)
{
    int i = void, subCount = void, spansCount = void;
    int ymin = void, ymax = void, xmin = void, xmax = void;
    Spans* spans = void;
    xPoint* subPt = void, spansPt = void;
    int* subWid = void, spansWid = void;
    int extra = void;

    ymin = mixin(YMIN!(`sub`));
    ymax = mixin(YMAX!(`sub`));
    spans = spanGroup.group;
    for (i = spanGroup.count; i; i--, spans++) {
        if (mixin(YMIN!(`spans`)) <= ymax && ymin <= mixin(YMAX!(`spans`))) {
            subCount = sub.count;
            subPt = sub.points;
            subWid = sub.widths;
            spansCount = spans.count;
            spansPt = spans.points;
            spansWid = spans.widths;
            extra = 0;
            for (;;) {
                while (spansCount && spansPt.y < subPt.y) {
                    spansPt++;
                    spansWid++;
                    spansCount--;
                }
                if (!spansCount)
                    break;
                while (subCount && subPt.y < spansPt.y) {
                    subPt++;
                    subWid++;
                    subCount--;
                }
                if (!subCount)
                    break;
                if (subPt.y == spansPt.y) {
                    xmin = subPt.x;
                    xmax = xmin + *subWid;
                    if (xmin >= spansPt.x + *spansWid || spansPt.x >= xmax) {
                        {}
                    }
                    else if (xmin <= spansPt.x) {
                        if (xmax >= spansPt.x + *spansWid) {
                            memmove(spansPt, spansPt + 1,
                                    ((*spansPt).sizeof * (spansCount - 1)));
                            memmove(spansWid, spansWid + 1,
                                    ((*spansWid).sizeof * (spansCount - 1)));
                            spansPt--;
                            spansWid--;
                            spans.count--;
                            extra++;
                        }
                        else {
                            *spansWid = *spansWid - (xmax - spansPt.x);
                            spansPt.x = cast(short)xmax;
                        }
                    }
                    else {
                        if (xmax >= spansPt.x + *spansWid) {
                            *spansWid = xmin - spansPt.x;
                        }
                        else {
                            if (!extra) {
                                xPoint* newPt = void;
                                int* newwid = void;

enum EXTRA = 8;
                                newPt = cast(xPoint*)reallocarray(spans.points,
                                                     spans.count + EXTRA,
                                                     xPoint.sizeof);
                                if (!newPt)
                                    break;
                                spansPt = newPt + (spansPt - spans.points);
                                spans.points = newPt;
                                newwid = cast(int*)reallocarray(spans.widths,
                                                      spans.count + EXTRA,
                                                      int.sizeof);
                                if (!newwid)
                                    break;
                                spansWid = newwid + (spansWid - spans.widths);
                                spans.widths = newwid;
                                extra = EXTRA;
                            }
                            memmove(spansPt + 1, spansPt,
                                    ((*spansPt).sizeof * (spansCount)));
                            memmove(spansWid + 1, spansWid,
                                    ((*spansWid).sizeof * (spansCount)));
                            spans.count++;
                            extra--;
                            *spansWid = xmin - spansPt.x;
                            spansWid++;
                            spansPt++;
                            *spansWid = *spansWid - (xmax - spansPt.x);
                            spansPt.x = cast(short)xmax;
                        }
                    }
                }
                spansPt++;
                spansWid++;
                spansCount--;
            }
        }
    }
}

private void miAppendSpans(SpanGroup* spanGroup, SpanGroup* otherGroup, Spans* spans)
{
    int ymin = void, ymax = void;
    int spansCount = void;

    spansCount = spans.count;
    if (spansCount > 0) {
        if (spanGroup.size == spanGroup.count) {
            spanGroup.size = (spanGroup.size + 8) * 2;
            spanGroup.group = cast(Spans*)XNFreallocarray(spanGroup.group,
                                               Spans.sizeof, spanGroup.size);
        }

        spanGroup.group[spanGroup.count] = *spans;
        (spanGroup.count)++;
        ymin = spans.points[0].y;
        if (ymin < spanGroup.ymin)
            spanGroup.ymin = ymin;
        ymax = spans.points[spansCount - 1].y;
        if (ymax > spanGroup.ymax)
            spanGroup.ymax = ymax;
        if (otherGroup && otherGroup.ymin < ymax && ymin < otherGroup.ymax) {
            miSubtractSpans(otherGroup, spans);
        }
    }
    else {
        free(spans.points);
        free(spans.widths);
    }
}                               /* AppendSpans */

private void miFreeSpanGroup(SpanGroup* spanGroup)
{
    free(spanGroup.group);
}

private void QuickSortSpansX(xPoint* points, int* widths, int numSpans)
{
    int x = void;
    int i = void, j = void, m = void;
    xPoint* r = void;

/* Always called with numSpans > 1 */
/* Sorts only by x, as all y should be the same */

enum string ExchangeSpans(string a, string b) = `
{							    
    xPoint tpt = void;				    
    int tw = void;				    
							    
    tpt = points[` ~ a ~ `]; points[` ~ a ~ `] = points[` ~ b ~ `]; points[` ~ b ~ `] = tpt;    
    tw = widths[` ~ a ~ `]; widths[` ~ a ~ `] = widths[` ~ b ~ `]; widths[` ~ b ~ `] = tw;  
}`;

    do {
        if (numSpans < 9) {
            /* Do insertion sort */
            int xprev;

            xprev = points[0].x;
            i = 1;
            do {                /* while i != numSpans */
                x = points[i].x;
                if (xprev > x) {
                    /* points[i] is out of order.  Move into proper location. */
                    xPoint tpt;
                    int tw, k;

                    for (j = 0; x >= points[j].x; j++) {
                    }
                    tpt = points[i];
                    tw = widths[i];
                    for (k = i; k != j; k--) {
                        points[k] = points[k - 1];
                        widths[k] = widths[k - 1];
                    }
                    points[j] = tpt;
                    widths[j] = tw;
                    x = points[i].x;
                }               /* if out of order */
                xprev = x;
                i++;
            } while (i != numSpans);
            return;
        }

        /* Choose partition element, stick in location 0 */
        m = numSpans / 2;
        if (points[m].x > points[0].x)
            mixin(ExchangeSpans!(`m`, `0`));
        if (points[m].x > points[numSpans - 1].x)
            mixin(ExchangeSpans!(`m`, `numSpans - 1`));
        if (points[m].x > points[0].x)
            mixin(ExchangeSpans!(`m`, `0`));
        x = points[0].x;

        /* Partition array */
        i = 0;
        j = numSpans;
        do {
            r = &(points[i]);
            do {
                r++;
                i++;
            } while (i != numSpans && r.x < x);
            r = &(points[j]);
            do {
                r--;
                j--;
            } while (x < r.x);
            if (i < j)
                mixin(ExchangeSpans!(`i`, `j`));
        } while (i < j);

        /* Move partition element back to middle */
        mixin(ExchangeSpans!(`0`, `j`));

        /* Recurse */
        if (numSpans - j - 1 > 1)
            QuickSortSpansX(&points[j + 1], &widths[j + 1], numSpans - j - 1);
        numSpans = j;
    } while (numSpans > 1);
}                               /* QuickSortSpans */

private int UniquifySpansX(Spans* spans, xPoint* newPoints, int* newWidths)
{
    int newx1 = void, newx2 = void, oldpt = void, i = void, y = void;
    xPoint* oldPoints = void;
    int* oldWidths = void;
    int* startNewWidths = void;

/* Always called with numSpans > 1 */
/* Uniquify the spans, and stash them into newPoints and newWidths.  Return the
   number of unique spans. */

    startNewWidths = newWidths;

    oldPoints = spans.points;
    oldWidths = spans.widths;

    y = oldPoints.y;
    newx1 = oldPoints.x;
    newx2 = newx1 + *oldWidths;

    for (i = spans.count - 1; i != 0; i--) {
        oldPoints++;
        oldWidths++;
        oldpt = oldPoints.x;
        if (oldpt > newx2) {
            /* Write current span, start a new one */
            newPoints.x = cast(short)newx1;
            newPoints.y = cast(short)y;
            *newWidths = newx2 - newx1;
            newPoints++;
            newWidths++;
            newx1 = oldpt;
            newx2 = oldpt + *oldWidths;
        }
        else {
            /* extend current span, if old extends beyond new */
            oldpt = oldpt + *oldWidths;
            if (oldpt > newx2)
                newx2 = oldpt;
        }
    }                           /* for */

    /* Write final span */
    newPoints.x = cast(short)newx1;
    *newWidths = newx2 - newx1;
    newPoints.y = cast(short)y;

    return cast(int)((newWidths - startNewWidths) + 1);
}                               /* UniquifySpansX */

private void miDisposeSpanGroup(SpanGroup* spanGroup)
{
    int i = void;
    Spans* spans = void;

    for (i = 0; i < spanGroup.count; i++) {
        spans = spanGroup.group + i;
        free(spans.points);
        free(spans.widths);
    }
}

private void miFillUniqueSpanGroup(DrawablePtr pDraw, GCPtr pGC, SpanGroup* spanGroup)
{
    int i = void;
    Spans* spans = void;
    Spans* yspans = void;
    int* ysizes = void;
    int ymin = void, ylength = void;

    /* Outgoing spans for one big call to FillSpans */
    xPoint* points = void;
    int* widths = void;
    int count = void;

    if (spanGroup.count == 0)
        return;

    if (spanGroup.count == 1) {
        /* Already should be sorted, unique */
        spans = spanGroup.group;
        (*pGC.ops.FillSpans)
            (pDraw, pGC, spans.count, spans.points, spans.widths, True);
        free(spans.points);
        free(spans.widths);
    }
    else {
        /* Yuck.  Gross.  Radix sort into y buckets, then sort x and uniquify */
        /* This seems to be the fastest thing to do.  I've tried sorting on
           both x and y at the same time rather than creating into all those
           y buckets, but it was somewhat slower. */

        ymin = spanGroup.ymin;
        ylength = spanGroup.ymax - ymin + 1;

        /* Allocate Spans for y buckets */
        yspans = cast(Spans*) calloc(ylength, Spans.sizeof);
        ysizes = cast(int*) calloc(ylength, int.sizeof);

        if (!yspans || !ysizes) {
            free(yspans);
            free(ysizes);
            miDisposeSpanGroup(spanGroup);
            return;
        }

        for (i = 0; i != ylength; i++) {
            ysizes[i] = 0;
            yspans[i].count = 0;
            yspans[i].points = null;
            yspans[i].widths = null;
        }

        /* Go through every single span and put it into the correct bucket */
        count = 0;
        for (i = 0, spans = spanGroup.group;
             i != spanGroup.count; i++, spans++) {
            int index = void;
            int j = void;

            for (j = 0, points = spans.points, widths = spans.widths;
                 j != spans.count; j++, points++, widths++) {
                index = points.y - ymin;
                if (index >= 0 && index < ylength) {
                    Spans* newspans = &(yspans[index]);

                    if (newspans.count == ysizes[index]) {
                        xPoint* newpoints = void;
                        int* newwidths = void;

                        ysizes[index] = (ysizes[index] + 8) * 2;
                        newpoints = cast(xPoint*)reallocarray(newspans.points,
                                                 ysizes[index],
                                                 xPoint.sizeof);
                        newwidths = cast(int*)reallocarray(newspans.widths,
                                                 ysizes[index], int.sizeof);
                        if (!newpoints || !newwidths) {
                            for (i = 0; i < ylength; i++) {
                                free(yspans[i].points);
                                free(yspans[i].widths);
                            }
                            free(yspans);
                            free(ysizes);
                            free(newpoints);
                            free(newwidths);
                            miDisposeSpanGroup(spanGroup);
                            return;
                        }
                        newspans.points = newpoints;
                        newspans.widths = newwidths;
                    }
                    newspans.points[newspans.count] = *points;
                    newspans.widths[newspans.count] = *widths;
                    (newspans.count)++;
                }               /* if y value of span in range */
            }                   /* for j through spans */
            count += spans.count;
            free(spans.points);
            spans.points = null;
            free(spans.widths);
            spans.widths = null;
        }                       /* for i thorough Spans */

        /* Now sort by x and uniquify each bucket into the final array */
        points = cast(xPoint*)calloc(count, xPoint.sizeof);
        widths = cast(int*) calloc(count, int.sizeof);
        if (!points || !widths) {
            for (i = 0; i < ylength; i++) {
                free(yspans[i].points);
                free(yspans[i].widths);
            }
            free(yspans);
            free(ysizes);
            free(points);
            free(widths);
            return;
        }
        count = 0;
        for (i = 0; i != ylength; i++) {
            int ycount = yspans[i].count;

            if (ycount > 0) {
                if (ycount > 1) {
                    QuickSortSpansX(yspans[i].points, yspans[i].widths, ycount);
                    count += UniquifySpansX
                        (&(yspans[i]), &(points[count]), &(widths[count]));
                }
                else {
                    points[count] = yspans[i].points[0];
                    widths[count] = yspans[i].widths[0];
                    count++;
                }
                free(yspans[i].points);
                free(yspans[i].widths);
            }
        }

        (*pGC.ops.FillSpans) (pDraw, pGC, count, points, widths, True);
        free(points);
        free(widths);
        free(yspans);
        free(ysizes);           /* use (DE)xalloc for these? */
    }

    spanGroup.count = 0;
    spanGroup.ymin = SHRT_MAX;
    spanGroup.ymax = SHRT_MIN;
}

private Bool InitSpans(Spans* spans, size_t nspans)
{
    spans.points = cast(xPoint*)calloc(nspans, typeof(*spans.points).sizeof);
    if (!spans.points)
        return False;
    spans.widths = cast(int*)calloc(nspans, typeof(*spans.widths).sizeof);
    if (!spans.widths) {
        free(spans.points);
        return False;
    }
    return True;
}

/*
 * interface data to span-merging polygon filler
 */

struct _SpanData {
    SpanGroup fgGroup, bgGroup;
}alias SpanDataRec = _SpanData;
alias SpanDataPtr = _SpanData*;

private void AppendSpanGroup(GCPtr pGC, c_ulong pixel, Spans* spanPtr, SpanDataPtr spanData)
{
    SpanGroup* group = void, othergroup = null;

    if (pixel == pGC.fgPixel) {
        group = &spanData.fgGroup;
        if (pGC.lineStyle == LineDoubleDash)
            othergroup = &spanData.bgGroup;
    }
    else {
        group = &spanData.bgGroup;
        othergroup = &spanData.fgGroup;
    }
    miAppendSpans(group, othergroup, spanPtr);
}



/*
 * spans-based polygon filler
 */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void fillSpans(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, Spans* spans, SpanDataPtr spanData)
{
    if (!spanData) {
        ChangeGCVal oldPixel = void, tmpPixel = void;

        oldPixel.val = pGC.fgPixel;
        if (pixel != oldPixel.val) {
            tmpPixel.val = cast(uint) pixel;
            ChangeGC(null, pGC, cast(uint)GCForeground, &tmpPixel);
            ValidateGC(pDrawable, pGC);
        }
        (*pGC.ops.FillSpans) (pDrawable, pGC, spans.count, spans.points,
                                spans.widths, True);
        free(spans.widths);
        free(spans.points);
        if (pixel != oldPixel.val) {
            ChangeGC(null, pGC, cast(uint)GCForeground, &oldPixel);
            ValidateGC(pDrawable, pGC);
        }
    }
    else
        AppendSpanGroup(pGC, pixel, spans, spanData);
}

private void miFillPolyHelper(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, int y, int overall_height, PolyEdgePtr left, PolyEdgePtr right, int left_count, int right_count)
{
    int left_x = 0, left_e = 0;
    int left_stepx = 0;
    int left_signdx = 0;
    int left_dy = 0, left_dx = 0;

    int right_x = 0, right_e = 0;
    int right_stepx = 0;
    int right_signdx = 0;
    int right_dy = 0, right_dx = 0;

    int height = 0;
    int left_height = 0, right_height = 0;

    xPoint* ppt = void;
    int* pwidth = void;
    int xorg = void;
    Spans spanRec = void;

    if (!InitSpans(&spanRec, overall_height))
        return;
    ppt = spanRec.points;
    pwidth = spanRec.widths;

    xorg = 0;
    if (pGC.miTranslate) {
        y += pDrawable.y;
        xorg = pDrawable.x;
    }
    while ((left_count || left_height) && (right_count || right_height)) {
        if (!left_height && left_count) {
            left_height = left.height;
            left_x = left.x;
            left_stepx = left.stepx;
            left_signdx = left.signdx;
            left_e = left.e;
            left_dy = left.dy;
            left_dx = left.dx;
            --left_count;
            ++left;
        }

        if (!right_height && right_count) {
            right_height = right.height;
            right_x = right.x;
            right_stepx = right.stepx;
            right_signdx = right.signdx;
            right_e = right.e;
            right_dy = right.dy;
            right_dx = right.dx;
            --right_count;
            ++right;
        }

        height = left_height;
        if (height > right_height)
            height = right_height;

        left_height -= height;
        right_height -= height;

        while (--height >= 0) {
            if (right_x >= left_x) {
                ppt.y = cast(short)(y);
                ppt.x = cast(short)(left_x + xorg);
                ppt++;
                *pwidth++ = right_x - left_x + 1;
            }
            y++;

            left_x += left_stepx;
            left_e += left_dx;
            if (left_e > 0) {
                left_x += left_signdx;
                left_e -= left_dy;
            }

            right_x += right_stepx;
            right_e += right_dx;
            if (right_e > 0) {
                right_x += right_signdx;
                right_e -= right_dy;
            }
        }
    }
    spanRec.count = cast(int)(ppt - spanRec.points);
    fillSpans(pDrawable, pGC, pixel, &spanRec, spanData);
}

private void miFillRectPolyHelper(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, int x, int y, int w, int h)
{
    xPoint* ppt = void;
    int* pwidth = void;
    ChangeGCVal oldPixel = void, tmpPixel = void;
    Spans spanRec = void;
    xRectangle rect = void;

    if (!spanData) {
        rect.x = cast(short)x;
        rect.y = cast(short)y;
        rect.width = cast(ushort)w;
        rect.height = cast(ushort)h;
        oldPixel.val = pGC.fgPixel;
        if (pixel != oldPixel.val) {
            tmpPixel.val = cast(uint) pixel;
            ChangeGC(null, pGC, cast(uint)GCForeground, &tmpPixel);
            ValidateGC(pDrawable, pGC);
        }
        (*pGC.ops.PolyFillRect) (pDrawable, pGC, 1, &rect);
        if (pixel != oldPixel.val) {
            ChangeGC(null, pGC, cast(uint)GCForeground, &oldPixel);
            ValidateGC(pDrawable, pGC);
        }
    }
    else {
        if (!InitSpans(&spanRec, h))
            return;
        ppt = spanRec.points;
        pwidth = spanRec.widths;

        if (pGC.miTranslate) {
            y += pDrawable.y;
            x += pDrawable.x;
        }
        while (h--) {
            ppt.x = cast(short)x;
            ppt.y = cast(short)y;
            ppt++;
            *pwidth++ = w;
            y++;
        }
        spanRec.count = cast(int)(ppt - spanRec.points);
        AppendSpanGroup(pGC, pixel, &spanRec, spanData);
    }
}

private int miPolyBuildEdge(double x0, double y0, double k, int dx, int dy, int xi, int yi, int left, PolyEdgePtr edge)
{
    int x = void, y = void, e = void;
    int xady = void;

    if (dy < 0) {
        dy = -dy;
        dx = -dx;
        k = -k;
    }

version (NOTDEF) {
    {
        double realk = void, kerror = void;

        realk = x0 * dy - y0 * dx;
        kerror = fabs(realk - k);
        if (kerror > .1)
            printf("realk: %g k: %g\n", realk, k);
    }
}
    y = ICEIL(y0);
    xady = ICEIL(k) + y * dx;

    if (xady <= 0)
        x = -(-xady / dy) - 1;
    else
        x = (xady - 1) / dy;

    e = xady - x * dy;

    if (dx >= 0) {
        edge.signdx = 1;
        edge.stepx = dx / dy;
        edge.dx = dx % dy;
    }
    else {
        edge.signdx = -1;
        edge.stepx = -(-dx / dy);
        edge.dx = -dx % dy;
        e = dy - e + 1;
    }
    edge.dy = dy;
    edge.x = x + left + xi;
    edge.e = e - dy;           /* bias to compare against 0 instead of dy */
    return y + yi;
}

enum string StepAround(string v, string incr, string max) = `(((` ~ v ~ `) + (` ~ incr ~ `) < 0) ? (` ~ max ~ ` - 1) : ((` ~ v ~ `) + (` ~ incr ~ `) == ` ~ max ~ `) ? 0 : ((` ~ v ~ `) + (` ~ incr ~ `)))`;

private int miPolyBuildPoly(PolyVertexPtr vertices, PolySlopePtr slopes, int count, int xi, int yi, PolyEdgePtr left, PolyEdgePtr right, int* pnleft, int* pnright, int* h)
{
    int top = void, bottom = void;
    double miny = void, maxy = void;
    int i = void;
    int j = void;
    int clockwise = void;
    int slopeoff = void;
    int s = void;
    int nright = void, nleft = void;
    int y = void, lasty = 0, bottomy = void, topy = 0;

    /* find the top of the polygon */
    maxy = miny = vertices[0].y;
    bottom = top = 0;
    for (i = 1; i < count; i++) {
        if (vertices[i].y < miny) {
            top = i;
            miny = vertices[i].y;
        }
        if (vertices[i].y >= maxy) {
            bottom = i;
            maxy = vertices[i].y;
        }
    }
    clockwise = 1;
    slopeoff = 0;

    i = top;
    j = mixin(StepAround!(`top`, `-1`, `count`));

    if (cast(long) slopes[j].dy * slopes[i].dx >
        cast(long) slopes[i].dy * slopes[j].dx) {
        clockwise = -1;
        slopeoff = -1;
    }

    bottomy = ICEIL(maxy) + yi;

    nright = 0;

    s = mixin(StepAround!(`top`, `slopeoff`, `count`));
    i = top;
    while (i != bottom) {
        if (slopes[s].dy != 0) {
            y = miPolyBuildEdge(vertices[i].x, vertices[i].y,
                                slopes[s].k,
                                slopes[s].dx, slopes[s].dy,
                                xi, yi, 0, &right[nright]);
            if (nright != 0)
                right[nright - 1].height = y - lasty;
            else
                topy = y;
            nright++;
            lasty = y;
        }

        i = mixin(StepAround!(`i`, `clockwise`, `count`));
        s = mixin(StepAround!(`s`, `clockwise`, `count`));
    }
    if (nright != 0)
        right[nright - 1].height = bottomy - lasty;

    if (slopeoff == 0)
        slopeoff = -1;
    else
        slopeoff = 0;

    nleft = 0;
    s = mixin(StepAround!(`top`, `slopeoff`, `count`));
    i = top;
    while (i != bottom) {
        if (slopes[s].dy != 0) {
            y = miPolyBuildEdge(vertices[i].x, vertices[i].y,
                                slopes[s].k,
                                slopes[s].dx, slopes[s].dy, xi, yi, 1,
                                &left[nleft]);

            if (nleft != 0)
                left[nleft - 1].height = y - lasty;
            nleft++;
            lasty = y;
        }
        i = mixin(StepAround!(`i`, `-clockwise`, `count`));
        s = mixin(StepAround!(`s`, `-clockwise`, `count`));
    }
    if (nleft != 0)
        left[nleft - 1].height = bottomy - lasty;
    *pnleft = nleft;
    *pnright = nright;
    *h = bottomy - topy;
    return topy;
}

private void miLineOnePoint(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, int x, int y)
{
    xPoint pt = void;
    int wid = void;
    c_ulong oldPixel = void;

    mixin(MILINESETPIXEL!("pDrawable", "pGC", "pixel", "oldPixel"));
    if (pGC.fillStyle == FillSolid) {
        pt.x = cast(short)x;
        pt.y = cast(short)y;
        (*pGC.ops.PolyPoint) (pDrawable, pGC, CoordModeOrigin, 1, &pt);
    }
    else {
        wid = 1;
        if (pGC.miTranslate) {
            x += pDrawable.x;
            y += pDrawable.y;
        }
        pt.x = cast(short)x;
        pt.y = cast(short)y;
        (*pGC.ops.FillSpans) (pDrawable, pGC, 1, &pt, &wid, True);
    }
    mixin(MILINERESETPIXEL!("pDrawable", "pGC", "pixel", "oldPixel"));
}

private void miLineJoin(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, LineFacePtr pLeft, LineFacePtr pRight)
{
    double mx = 0, my = 0;
    double denom = 0.0;
    PolyVertexRec[4] vertices = void;
    PolySlopeRec[4] slopes = void;
    int edgecount = void;
    PolyEdgeRec[4] left = void, right = void;
    int nleft = void, nright = void;
    int y = void, height = void;
    int swapslopes = void;
    int joinStyle = pGC.joinStyle;
    int lw = pGC.lineWidth;

    if (lw == 1 && !spanData) {
        /* See if one of the lines will draw the joining pixel */
        if (pLeft.dx > 0 || (pLeft.dx == 0 && pLeft.dy > 0))
            return;
        if (pRight.dx > 0 || (pRight.dx == 0 && pRight.dy > 0))
            return;
        if (joinStyle != JoinRound) {
            denom =
                -pLeft.dx * cast(double) pRight.dy +
                pRight.dx * cast(double) pLeft.dy;
            if (denom == 0)
                return;         /* no join to draw */
        }
        if (joinStyle != JoinMiter) {
            miLineOnePoint(pDrawable, pGC, pixel, spanData, pLeft.x, pLeft.y);
            return;
        }
    }
    else {
        if (joinStyle == JoinRound) {
            miLineArc(pDrawable, pGC, pixel, spanData,
                      pLeft, pRight, cast(double) 0.0, cast(double) 0.0, True);
            return;
        }
        denom =
            -pLeft.dx * cast(double) pRight.dy + pRight.dx * cast(double) pLeft.dy;
        if (denom == 0.0)
            return;             /* no join to draw */
    }

    swapslopes = 0;
    if (denom > 0) {
        pLeft.xa = -pLeft.xa;
        pLeft.ya = -pLeft.ya;
        pLeft.dx = -pLeft.dx;
        pLeft.dy = -pLeft.dy;
    }
    else {
        swapslopes = 1;
        pRight.xa = -pRight.xa;
        pRight.ya = -pRight.ya;
        pRight.dx = -pRight.dx;
        pRight.dy = -pRight.dy;
    }

    vertices[0].x = pRight.xa;
    vertices[0].y = pRight.ya;
    slopes[0].dx = -pRight.dy;
    slopes[0].dy = pRight.dx;
    slopes[0].k = 0;

    vertices[1].x = 0;
    vertices[1].y = 0;
    slopes[1].dx = pLeft.dy;
    slopes[1].dy = -pLeft.dx;
    slopes[1].k = 0;

    vertices[2].x = pLeft.xa;
    vertices[2].y = pLeft.ya;

    if (joinStyle == JoinMiter) {
        my = (pLeft.dy * (pRight.xa * pRight.dy - pRight.ya * pRight.dx) -
              pRight.dy * (pLeft.xa * pLeft.dy - pLeft.ya * pLeft.dx)) /
            denom;
        if (pLeft.dy != 0) {
            mx = pLeft.xa + (my - pLeft.ya) *
                cast(double) pLeft.dx / cast(double) pLeft.dy;
        }
        else {
            mx = pRight.xa + (my - pRight.ya) *
                cast(double) pRight.dx / cast(double) pRight.dy;
        }
        /* check miter limit */
        if ((mx * mx + my * my) * 4 > SQSECANT * lw * lw)
            joinStyle = JoinBevel;
    }

    if (joinStyle == JoinMiter) {
        slopes[2].dx = pLeft.dx;
        slopes[2].dy = pLeft.dy;
        slopes[2].k = pLeft.k;
        if (swapslopes) {
            slopes[2].dx = -slopes[2].dx;
            slopes[2].dy = -slopes[2].dy;
            slopes[2].k = -slopes[2].k;
        }
        vertices[3].x = mx;
        vertices[3].y = my;
        slopes[3].dx = pRight.dx;
        slopes[3].dy = pRight.dy;
        slopes[3].k = pRight.k;
        if (swapslopes) {
            slopes[3].dx = -slopes[3].dx;
            slopes[3].dy = -slopes[3].dy;
            slopes[3].k = -slopes[3].k;
        }
        edgecount = 4;
    }
    else {
        double scale = void, dx = void, dy = void, adx = void, ady = void;

        adx = dx = pRight.xa - pLeft.xa;
        ady = dy = pRight.ya - pLeft.ya;
        if (adx < 0)
            adx = -adx;
        if (ady < 0)
            ady = -ady;
        scale = ady;
        if (adx > ady)
            scale = adx;
        slopes[2].dx = cast(int)((dx * 65536) / scale);
        slopes[2].dy = cast(int)((dy * 65536) / scale);
        slopes[2].k = ((pLeft.xa + pRight.xa) * slopes[2].dy -
                       (pLeft.ya + pRight.ya) * slopes[2].dx) / 2.0;
        edgecount = 3;
    }

    y = miPolyBuildPoly(vertices.ptr, slopes.ptr, edgecount, pLeft.x, pLeft.y,
                        left.ptr, right.ptr, &nleft, &nright, &height);
    miFillPolyHelper(pDrawable, pGC, pixel, spanData, y, height, left.ptr, right.ptr,
                     nleft, nright);
}

private int miLineArcI(DrawablePtr pDraw, GCPtr pGC, int xorg, int yorg, xPoint* points, int* widths)
{
    xPoint* tpts = void, bpts = void;
    int* twids = void, bwids = void;
    int x = void, y = void, e = void, ex = void, slw = void;

    tpts = points;
    twids = widths;
    if (pGC.miTranslate) {
        xorg += pDraw.x;
        yorg += pDraw.y;
    }
    slw = pGC.lineWidth;
    if (slw == 1) {
        tpts.x = cast(short)xorg;
        tpts.y = cast(short)yorg;
        *twids = 1;
        return 1;
    }
    bpts = tpts + slw;
    bwids = twids + slw;
    y = (slw >> 1) + 1;
    if (slw & 1)
        e = -((y << 2) + 3);
    else
        e = -(y << 3);
    ex = -4;
    x = 0;
    while (y) {
        e += (y << 3) - 4;
        while (e >= 0) {
            x++;
            e += (ex = -((x << 3) + 4));
        }
        y--;
        slw = (x << 1) + 1;
        if ((e == ex) && (slw > 1))
            slw--;
        tpts.x = cast(short)(xorg - x);
        tpts.y = cast(short)(yorg - y);
        tpts++;
        *twids++ = slw;
        if ((y != 0) && ((slw > 1) || (e != ex))) {
            bpts--;
            bpts.x = cast(short)(xorg - x);
            bpts.y = cast(short)(yorg + y);
            *--bwids = slw;
        }
    }
    return pGC.lineWidth;
}

enum string CLIPSTEPEDGE(string edgey,string edge,string edgeleft) = `
    if (ybase == ` ~ edgey ~ `) 
    { 
	if (` ~ edgeleft ~ `) 
	{ 
	    if (` ~ edge ~ `.x > xcl) 
		xcl = ` ~ edge ~ `.x; 
	} 
	else 
	{ 
	    if (` ~ edge ~ `.x < xcr) 
		xcr = ` ~ edge ~ `.x; 
	} 
	` ~ edgey ~ `++; 
	` ~ edge ~ `.x += ` ~ edge ~ `.stepx; 
	` ~ edge ~ `.e += ` ~ edge ~ `.dx; 
	if (` ~ edge ~ `.e > 0) 
	{ 
	    ` ~ edge ~ `.x += ` ~ edge ~ `.signdx; 
	    ` ~ edge ~ `.e -= ` ~ edge ~ `.dy; 
	} 
    }`;

private int miLineArcD(DrawablePtr pDraw, GCPtr pGC, double xorg, double yorg, xPoint* points, int* widths, PolyEdgePtr edge1, int edgey1, Bool edgeleft1, PolyEdgePtr edge2, int edgey2, Bool edgeleft2)
{
    xPoint* pts = void;
    int* wids = void;
    double radius = void, x0 = void, y0 = void, el = void, er = void, yk = void, xlk = void, xrk = void, k = void;
    int xbase = void, ybase = void, y = void, boty = void, xl = void, xr = void, xcl = void, xcr = void;
    int ymin = void, ymax = void;
    Bool edge1IsMin = void, edge2IsMin = void;
    int ymin1 = void, ymin2 = void;

    pts = points;
    wids = widths;
    xbase = cast(int)floor(xorg);
    x0 = xorg - xbase;
    ybase = ICEIL(yorg);
    y0 = yorg - ybase;
    if (pGC.miTranslate) {
        xbase += pDraw.x;
        ybase += pDraw.y;
        edge1.x += pDraw.x;
        edge2.x += pDraw.x;
        edgey1 += pDraw.y;
        edgey2 += pDraw.y;
    }
    xlk = x0 + x0 + 1.0;
    xrk = x0 + x0 - 1.0;
    yk = y0 + y0 - 1.0;
    radius = (cast(double) pGC.lineWidth) / 2.0;
    y = cast(int)floor(radius - y0 + 1.0);
    ybase -= y;
    ymin = ybase;
    ymax = 65536;
    edge1IsMin = False;
    ymin1 = edgey1;
    if (edge1.dy >= 0) {
        if (!edge1.dy) {
            if (edgeleft1)
                edge1IsMin = True;
            else
                ymax = edgey1;
            edgey1 = 65536;
        }
        else {
            if ((edge1.signdx < 0) == edgeleft1)
                edge1IsMin = True;
        }
    }
    edge2IsMin = False;
    ymin2 = edgey2;
    if (edge2.dy >= 0) {
        if (!edge2.dy) {
            if (edgeleft2)
                edge2IsMin = True;
            else
                ymax = edgey2;
            edgey2 = 65536;
        }
        else {
            if ((edge2.signdx < 0) == edgeleft2)
                edge2IsMin = True;
        }
    }
    if (edge1IsMin) {
        ymin = ymin1;
        if (edge2IsMin && ymin1 > ymin2)
            ymin = ymin2;
    }
    else if (edge2IsMin)
        ymin = ymin2;
    el = radius * radius - ((y + y0) * (y + y0)) - (x0 * x0);
    er = el + xrk;
    xl = 1;
    xr = 0;
    if (x0 < 0.5) {
        xl = 0;
        el -= xlk;
    }
    boty = (y0 < -0.5) ? 1 : 0;
    if (ybase + y - boty > ymax)
        boty = ymax - ybase - y;
    while (y > boty) {
        k = (y << 1) + yk;
        er += k;
        while (er > 0.0) {
            xr++;
            er += xrk - (xr << 1);
        }
        el += k;
        while (el >= 0.0) {
            xl--;
            el += (xl << 1) - xlk;
        }
        y--;
        ybase++;
        if (ybase < ymin)
            continue;
        xcl = xl + xbase;
        xcr = xr + xbase;
        mixin(CLIPSTEPEDGE!(`edgey1`, `edge1`, `edgeleft1`));
        mixin(CLIPSTEPEDGE!(`edgey2`, `edge2`, `edgeleft2`));
        if (xcr >= xcl) {
            pts.x = cast(short)xcl;
            pts.y = cast(short)ybase;
            pts++;
            *wids++ = xcr - xcl + 1;
        }
    }
    er = xrk - (xr << 1) - er;
    el = (xl << 1) - xlk - el;
    boty = cast(int)floor(-y0 - radius + 1.0);
    if (ybase + y - boty > ymax)
        boty = ymax - ybase - y;
    while (y > boty) {
        k = (y << 1) + yk;
        er -= k;
        while ((er >= 0.0) && (xr >= 0)) {
            xr--;
            er += xrk - (xr << 1);
        }
        el -= k;
        while ((el > 0.0) && (xl <= 0)) {
            xl++;
            el += (xl << 1) - xlk;
        }
        y--;
        ybase++;
        if (ybase < ymin)
            continue;
        xcl = xl + xbase;
        xcr = xr + xbase;
        mixin(CLIPSTEPEDGE!(`edgey1`, `edge1`, `edgeleft1`));
        mixin(CLIPSTEPEDGE!(`edgey2`, `edge2`, `edgeleft2`));
        if (xcr >= xcl) {
            pts.x = cast(short)xcl;
            pts.y = cast(short)ybase;
            pts++;
            *wids++ = xcr - xcl + 1;
        }
    }
    return cast(int)(pts - points);
}

private int miRoundJoinFace(LineFacePtr face, PolyEdgePtr edge, Bool* leftEdge)
{
    int y = void;
    int dx = void, dy = void;
    double xa = void, ya = void;
    Bool left = void;

    dx = -face.dy;
    dy = face.dx;
    xa = face.xa;
    ya = face.ya;
    left = 1;
    if (ya > 0) {
        ya = 0.0;
        xa = 0.0;
    }
    if (dy < 0 || (dy == 0 && dx > 0)) {
        dx = -dx;
        dy = -dy;
        left = !left;
    }
    if (dx == 0 && dy == 0)
        dy = 1;
    if (dy == 0) {
        y = ICEIL(face.ya) + face.y;
        edge.x = -32767;
        edge.stepx = 0;
        edge.signdx = 0;
        edge.e = -1;
        edge.dy = 0;
        edge.dx = 0;
        edge.height = 0;
    }
    else {
        y = miPolyBuildEdge(xa, ya, 0.0, dx, dy, face.x, face.y, !left, edge);
        edge.height = 32767;
    }
    *leftEdge = !left;
    return y;
}

private void miRoundJoinClip(LineFacePtr pLeft, LineFacePtr pRight, PolyEdgePtr edge1, PolyEdgePtr edge2, int* y1, int* y2, Bool* left1, Bool* left2)
{
    double denom = void;

    denom = -pLeft.dx * cast(double) pRight.dy + pRight.dx * cast(double) pLeft.dy;

    if (denom >= 0) {
        pLeft.xa = -pLeft.xa;
        pLeft.ya = -pLeft.ya;
    }
    else {
        pRight.xa = -pRight.xa;
        pRight.ya = -pRight.ya;
    }
    *y1 = miRoundJoinFace(pLeft, edge1, left1);
    *y2 = miRoundJoinFace(pRight, edge2, left2);
}

private int miRoundCapClip(LineFacePtr face, Bool isInt, PolyEdgePtr edge, Bool* leftEdge)
{
    int y = void;
    int dx = void, dy = void;
    double xa = void, ya = void, k = void;
    Bool left = void;

    dx = -face.dy;
    dy = face.dx;
    xa = face.xa;
    ya = face.ya;
    k = 0.0;
    if (!isInt)
        k = face.k;
    left = 1;
    if (dy < 0 || (dy == 0 && dx > 0)) {
        dx = -dx;
        dy = -dy;
        xa = -xa;
        ya = -ya;
        left = !left;
    }
    if (dx == 0 && dy == 0)
        dy = 1;
    if (dy == 0) {
        y = ICEIL(face.ya) + face.y;
        edge.x = -32767;
        edge.stepx = 0;
        edge.signdx = 0;
        edge.e = -1;
        edge.dy = 0;
        edge.dx = 0;
        edge.height = 0;
    }
    else {
        y = miPolyBuildEdge(xa, ya, k, dx, dy, face.x, face.y, !left, edge);
        edge.height = 32767;
    }
    *leftEdge = !left;
    return y;
}

private void miLineArc(DrawablePtr pDraw, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, LineFacePtr leftFace, LineFacePtr rightFace, double xorg, double yorg, Bool isInt)
{
    int xorgi = 0, yorgi = 0;
    Spans spanRec = void;
    int n = void;
    PolyEdgeRec edge1 = { 0 }, edge2 = { 0 };
    int edgey1 = void, edgey2 = void;
    Bool edgeleft1 = void, edgeleft2 = void;

    if (isInt) {
        xorgi = leftFace ? leftFace.x : rightFace.x;
        yorgi = leftFace ? leftFace.y : rightFace.y;
    }
    edgey1 = 65536;
    edgey2 = 65536;
    edge1.x = 0;                /* not used, keep memory checkers happy */
    edge1.dy = -1;
    edge2.x = 0;                /* not used, keep memory checkers happy */
    edge2.dy = -1;
    edgeleft1 = False;
    edgeleft2 = False;
    if ((pGC.lineStyle != LineSolid || pGC.lineWidth > 2) &&
        ((pGC.capStyle == CapRound && pGC.joinStyle != JoinRound) ||
         (pGC.joinStyle == JoinRound && pGC.capStyle == CapButt))) {
        if (isInt) {
            xorg = cast(double) xorgi;
            yorg = cast(double) yorgi;
        }
        if (leftFace && rightFace) {
            miRoundJoinClip(leftFace, rightFace, &edge1, &edge2,
                            &edgey1, &edgey2, &edgeleft1, &edgeleft2);
        }
        else if (leftFace) {
            edgey1 = miRoundCapClip(leftFace, isInt, &edge1, &edgeleft1);
        }
        else if (rightFace) {
            edgey2 = miRoundCapClip(rightFace, isInt, &edge2, &edgeleft2);
        }
        isInt = False;
    }
    if (!InitSpans(&spanRec, pGC.lineWidth))
        return;
    if (isInt)
        n = miLineArcI(pDraw, pGC, xorgi, yorgi, spanRec.points,
                       spanRec.widths);
    else
        n = miLineArcD(pDraw, pGC, xorg, yorg, spanRec.points, spanRec.widths,
                       &edge1, edgey1, edgeleft1, &edge2, edgey2, edgeleft2);
    spanRec.count = n;
    fillSpans(pDraw, pGC, pixel, &spanRec, spanData);
}

private void miLineProjectingCap(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, LineFacePtr face, Bool isLeft, double xorg, double yorg, Bool isInt)
{
    int xorgi = 0, yorgi = 0;
    int lw = void;
    PolyEdgeRec[4] lefts = void, rights = void;
    int lefty = void, righty = void, topy = void, bottomy = void;
    PolyEdgePtr left = void, right = void;
    PolyEdgePtr top = void, bottom = void;
    double xa = void, ya = void;
    double k = void;
    double xap = void, yap = void;
    int dx = void, dy = void;
    double projectXoff = void, projectYoff = void;
    double maxy = void;
    int finaly = void;

    if (isInt) {
        xorgi = face.x;
        yorgi = face.y;
    }
    lw = pGC.lineWidth;
    dx = face.dx;
    dy = face.dy;
    k = face.k;
    if (dy == 0) {
        lefts[0].height = lw;
        lefts[0].x = xorgi;
        if (isLeft)
            lefts[0].x -= (lw >> 1);
        lefts[0].stepx = 0;
        lefts[0].signdx = 1;
        lefts[0].e = -lw;
        lefts[0].dx = 0;
        lefts[0].dy = lw;
        rights[0].height = lw;
        rights[0].x = xorgi;
        if (!isLeft)
            rights[0].x += ((lw + 1) >> 1);
        rights[0].stepx = 0;
        rights[0].signdx = 1;
        rights[0].e = -lw;
        rights[0].dx = 0;
        rights[0].dy = lw;
        miFillPolyHelper(pDrawable, pGC, pixel, spanData, yorgi - (lw >> 1), lw,
                         lefts.ptr, rights.ptr, 1, 1);
    }
    else if (dx == 0) {
        if (dy < 0) {
            dy = -dy;
            isLeft = !isLeft;
        }
        topy = yorgi;
        bottomy = yorgi + dy;
        if (isLeft)
            topy -= (lw >> 1);
        else
            bottomy += (lw >> 1);
        lefts[0].height = bottomy - topy;
        lefts[0].x = xorgi - (lw >> 1);
        lefts[0].stepx = 0;
        lefts[0].signdx = 1;
        lefts[0].e = -dy;
        lefts[0].dx = dx;
        lefts[0].dy = dy;

        rights[0].height = bottomy - topy;
        rights[0].x = lefts[0].x + (lw - 1);
        rights[0].stepx = 0;
        rights[0].signdx = 1;
        rights[0].e = -dy;
        rights[0].dx = dx;
        rights[0].dy = dy;
        miFillPolyHelper(pDrawable, pGC, pixel, spanData, topy, bottomy - topy,
                         lefts.ptr, rights.ptr, 1, 1);
    }
    else {
        xa = face.xa;
        ya = face.ya;
        projectXoff = -ya;
        projectYoff = xa;
        if (dx < 0) {
            right = &rights[1];
            left = &lefts[0];
            top = &rights[0];
            bottom = &lefts[1];
        }
        else {
            right = &rights[0];
            left = &lefts[1];
            top = &lefts[0];
            bottom = &rights[1];
        }
        if (isLeft) {
            righty = miPolyBuildEdge(xa, ya, k, dx, dy, xorgi, yorgi, 0, right);

            xa = -xa;
            ya = -ya;
            k = -k;
            lefty = miPolyBuildEdge(xa - projectXoff, ya - projectYoff,
                                    k, dx, dy, xorgi, yorgi, 1, left);
            if (dx > 0) {
                ya = -ya;
                xa = -xa;
            }
            xap = xa - projectXoff;
            yap = ya - projectYoff;
            topy = miPolyBuildEdge(xap, yap, xap * dx + yap * dy,
                                   -dy, dx, xorgi, yorgi, dx > 0, top);
            bottomy = miPolyBuildEdge(xa, ya,
                                      0.0, -dy, dx, xorgi, yorgi, dx < 0,
                                      bottom);
            maxy = -ya;
        }
        else {
            righty = miPolyBuildEdge(xa - projectXoff, ya - projectYoff,
                                     k, dx, dy, xorgi, yorgi, 0, right);

            xa = -xa;
            ya = -ya;
            k = -k;
            lefty = miPolyBuildEdge(xa, ya, k, dx, dy, xorgi, yorgi, 1, left);
            if (dx > 0) {
                ya = -ya;
                xa = -xa;
            }
            xap = xa - projectXoff;
            yap = ya - projectYoff;
            topy =
                miPolyBuildEdge(xa, ya, 0.0, -dy, dx, xorgi, xorgi, dx > 0,
                                top);
            bottomy =
                miPolyBuildEdge(xap, yap, xap * dx + yap * dy, -dy, dx, xorgi,
                                xorgi, dx < 0, bottom);
            maxy = -ya + projectYoff;
        }
        finaly = ICEIL(maxy) + yorgi;
        if (dx < 0) {
            left.height = bottomy - lefty;
            right.height = finaly - righty;
            top.height = righty - topy;
        }
        else {
            right.height = bottomy - righty;
            left.height = finaly - lefty;
            top.height = lefty - topy;
        }
        bottom.height = finaly - bottomy;
        miFillPolyHelper(pDrawable, pGC, pixel, spanData, topy,
                         bottom.height + bottomy - topy, lefts.ptr, rights.ptr, 2, 2);
    }
}

private void miWideSegment(DrawablePtr pDrawable, GCPtr pGC, c_ulong pixel, SpanDataPtr spanData, int x1, int y1, int x2, int y2, Bool projectLeft, Bool projectRight, LineFacePtr leftFace, LineFacePtr rightFace)
{
    double l = void, L = void, r = void;
    double xa = void, ya = void;
    double projectXoff = 0.0, projectYoff = 0.0;
    double k = void;
    double maxy = void;
    int x = void, y = void;
    int dx = void, dy = void;
    int finaly = void;
    PolyEdgePtr left = void, right = void;
    PolyEdgePtr top = void, bottom = void;
    int lefty = void, righty = void, topy = void, bottomy = void;
    int signdx = void;
    PolyEdgeRec[4] lefts = void, rights = void;
    LineFacePtr tface = void;
    int lw = pGC.lineWidth;

    /* draw top-to-bottom always */
    if (y2 < y1 || (y2 == y1 && x2 < x1)) {
        x = x1;
        x1 = x2;
        x2 = x;

        y = y1;
        y1 = y2;
        y2 = y;

        x = projectLeft;
        projectLeft = projectRight;
        projectRight = x;

        tface = leftFace;
        leftFace = rightFace;
        rightFace = tface;
    }

    dy = y2 - y1;
    signdx = 1;
    dx = x2 - x1;
    if (dx < 0)
        signdx = -1;

    leftFace.x = x1;
    leftFace.y = y1;
    leftFace.dx = dx;
    leftFace.dy = dy;

    rightFace.x = x2;
    rightFace.y = y2;
    rightFace.dx = -dx;
    rightFace.dy = -dy;

    if (dy == 0) {
        rightFace.xa = 0;
        rightFace.ya = cast(double) lw / 2.0;
        rightFace.k = -cast(double) (lw * dx) / 2.0;
        leftFace.xa = 0;
        leftFace.ya = -rightFace.ya;
        leftFace.k = rightFace.k;
        x = x1;
        if (projectLeft)
            x -= (lw >> 1);
        y = y1 - (lw >> 1);
        dx = x2 - x;
        if (projectRight)
            dx += ((lw + 1) >> 1);
        dy = lw;
        miFillRectPolyHelper(pDrawable, pGC, pixel, spanData, x, y, dx, dy);
    }
    else if (dx == 0) {
        leftFace.xa = cast(double) lw / 2.0;
        leftFace.ya = 0;
        leftFace.k = cast(double) (lw * dy) / 2.0;
        rightFace.xa = -leftFace.xa;
        rightFace.ya = 0;
        rightFace.k = leftFace.k;
        y = y1;
        if (projectLeft)
            y -= lw >> 1;
        x = x1 - (lw >> 1);
        dy = y2 - y;
        if (projectRight)
            dy += ((lw + 1) >> 1);
        dx = lw;
        miFillRectPolyHelper(pDrawable, pGC, pixel, spanData, x, y, dx, dy);
    }
    else {
        l = (cast(double) lw) / 2.0;
        L = hypot(cast(double) dx, cast(double) dy);

        if (dx < 0) {
            right = &rights[1];
            left = &lefts[0];
            top = &rights[0];
            bottom = &lefts[1];
        }
        else {
            right = &rights[0];
            left = &lefts[1];
            top = &lefts[0];
            bottom = &rights[1];
        }
        r = l / L;

        /* coord of upper bound at integral y */
        ya = -r * dx;
        xa = r * dy;

        if (projectLeft | projectRight) {
            projectXoff = -ya;
            projectYoff = xa;
        }

        /* xa * dy - ya * dx */
        k = l * L;

        leftFace.xa = xa;
        leftFace.ya = ya;
        leftFace.k = k;
        rightFace.xa = -xa;
        rightFace.ya = -ya;
        rightFace.k = k;

        if (projectLeft)
            righty = miPolyBuildEdge(xa - projectXoff, ya - projectYoff,
                                     k, dx, dy, x1, y1, 0, right);
        else
            righty = miPolyBuildEdge(xa, ya, k, dx, dy, x1, y1, 0, right);

        /* coord of lower bound at integral y */
        ya = -ya;
        xa = -xa;

        /* xa * dy - ya * dx */
        k = -k;

        if (projectLeft)
            lefty = miPolyBuildEdge(xa - projectXoff, ya - projectYoff,
                                    k, dx, dy, x1, y1, 1, left);
        else
            lefty = miPolyBuildEdge(xa, ya, k, dx, dy, x1, y1, 1, left);

        /* coord of top face at integral y */

        if (signdx > 0) {
            ya = -ya;
            xa = -xa;
        }

        if (projectLeft) {
            double xap = xa - projectXoff;
            double yap = ya - projectYoff;

            topy = miPolyBuildEdge(xap, yap, xap * dx + yap * dy,
                                   -dy, dx, x1, y1, dx > 0, top);
        }
        else
            topy = miPolyBuildEdge(xa, ya, 0.0, -dy, dx, x1, y1, dx > 0, top);

        /* coord of bottom face at integral y */

        if (projectRight) {
            double xap = xa + projectXoff;
            double yap = ya + projectYoff;

            bottomy = miPolyBuildEdge(xap, yap, xap * dx + yap * dy,
                                      -dy, dx, x2, y2, dx < 0, bottom);
            maxy = -ya + projectYoff;
        }
        else {
            bottomy = miPolyBuildEdge(xa, ya,
                                      0.0, -dy, dx, x2, y2, dx < 0, bottom);
            maxy = -ya;
        }

        finaly = ICEIL(maxy) + y2;

        if (dx < 0) {
            left.height = bottomy - lefty;
            right.height = finaly - righty;
            top.height = righty - topy;
        }
        else {
            right.height = bottomy - righty;
            left.height = finaly - lefty;
            top.height = lefty - topy;
        }
        bottom.height = finaly - bottomy;
        miFillPolyHelper(pDrawable, pGC, pixel, spanData, topy,
                         bottom.height + bottomy - topy, lefts.ptr, rights.ptr, 2, 2);
    }
}

private SpanDataPtr miSetupSpanData(GCPtr pGC, SpanDataPtr spanData, int npt)
{
    if ((npt < 3 && pGC.capStyle != CapRound) || mixin(miSpansEasyRop!(`pGC.alu`)))
        return cast(SpanDataPtr) null;
    if (pGC.lineStyle == LineDoubleDash)
        miInitSpanGroup(&spanData.bgGroup);
    miInitSpanGroup(&spanData.fgGroup);
    return spanData;
}

private void miCleanupSpanData(DrawablePtr pDrawable, GCPtr pGC, SpanDataPtr spanData)
{
    if (pGC.lineStyle == LineDoubleDash) {
        ChangeGCVal oldPixel = void, pixel = void;

        pixel.val = pGC.bgPixel;
        oldPixel.val = pGC.fgPixel;
        if (pixel.val != oldPixel.val) {
            ChangeGC(null, pGC, cast(uint)GCForeground, &pixel);
            ValidateGC(pDrawable, pGC);
        }
        miFillUniqueSpanGroup(pDrawable, pGC, &spanData.bgGroup);
        miFreeSpanGroup(&spanData.bgGroup);
        if (pixel.val != oldPixel.val) {
            ChangeGC(null, pGC, cast(uint)GCForeground, &oldPixel);
            ValidateGC(pDrawable, pGC);
        }
    }
    miFillUniqueSpanGroup(pDrawable, pGC, &spanData.fgGroup);
    miFreeSpanGroup(&spanData.fgGroup);
}

void miWideLine(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, xPoint* pPts)
{
    int x1 = void, y1 = void, x2 = void, y2 = void;
    SpanDataRec spanDataRec = void;
    SpanDataPtr spanData = void;
    c_long pixel = void;
    Bool projectLeft = void, projectRight = void;
    LineFaceRec leftFace = { 0 }, rightFace = { 0 }, prevRightFace = void;
    LineFaceRec firstFace = void;
    int first = void;
    Bool somethingDrawn = False;
    Bool selfJoin = void;

    spanData = miSetupSpanData(pGC, &spanDataRec, npt);
    pixel = pGC.fgPixel;
    x2 = pPts.x;
    y2 = pPts.y;
    first = True;
    selfJoin = False;
    if (npt > 1) {
        if (mode == CoordModePrevious) {
            int nptTmp = void;
            xPoint* pPtsTmp = void;

            x1 = x2;
            y1 = y2;
            nptTmp = npt;
            pPtsTmp = pPts + 1;
            while (--nptTmp) {
                x1 += pPtsTmp.x;
                y1 += pPtsTmp.y;
                ++pPtsTmp;
            }
            if (x2 == x1 && y2 == y1)
                selfJoin = True;
        }
        else if (x2 == pPts[npt - 1].x && y2 == pPts[npt - 1].y) {
            selfJoin = True;
        }
    }
    projectLeft = pGC.capStyle == CapProjecting && !selfJoin;
    projectRight = False;
    while (--npt) {
        x1 = x2;
        y1 = y2;
        ++pPts;
        x2 = pPts.x;
        y2 = pPts.y;
        if (mode == CoordModePrevious) {
            x2 += x1;
            y2 += y1;
        }
        if (x1 != x2 || y1 != y2) {
            somethingDrawn = True;
            if (npt == 1 && pGC.capStyle == CapProjecting && !selfJoin)
                projectRight = True;
            miWideSegment(pDrawable, pGC, pixel, spanData, x1, y1, x2, y2,
                          projectLeft, projectRight, &leftFace, &rightFace);
            if (first) {
                if (selfJoin)
                    firstFace = leftFace;
                else if (pGC.capStyle == CapRound) {
                    if (pGC.lineWidth == 1 && !spanData)
                        miLineOnePoint(pDrawable, pGC, pixel, spanData, x1, y1);
                    else
                        miLineArc(pDrawable, pGC, pixel, spanData,
                                  &leftFace, cast(LineFacePtr) null,
                                  cast(double) 0.0, cast(double) 0.0, True);
                }
            }
            else {
                miLineJoin(pDrawable, pGC, pixel, spanData, &leftFace,
                           &prevRightFace);
            }
            prevRightFace = rightFace;
            first = False;
            projectLeft = False;
        }
        if (npt == 1 && somethingDrawn) {
            if (selfJoin)
                miLineJoin(pDrawable, pGC, pixel, spanData, &firstFace,
                           &rightFace);
            else if (pGC.capStyle == CapRound) {
                if (pGC.lineWidth == 1 && !spanData)
                    miLineOnePoint(pDrawable, pGC, pixel, spanData, x2, y2);
                else
                    miLineArc(pDrawable, pGC, pixel, spanData,
                              cast(LineFacePtr) null, &rightFace,
                              cast(double) 0.0, cast(double) 0.0, True);
            }
        }
    }
    /* handle crock where all points are coincedent */
    if (!somethingDrawn) {
        projectLeft = pGC.capStyle == CapProjecting;
        miWideSegment(pDrawable, pGC, pixel, spanData,
                      x2, y2, x2, y2, projectLeft, projectLeft,
                      &leftFace, &rightFace);
        if (pGC.capStyle == CapRound) {
            miLineArc(pDrawable, pGC, pixel, spanData,
                      &leftFace, cast(LineFacePtr) null,
                      cast(double) 0.0, cast(double) 0.0, True);
            rightFace.dx = -1;  /* sleezy hack to make it work */
            miLineArc(pDrawable, pGC, pixel, spanData,
                      cast(LineFacePtr) null, &rightFace,
                      cast(double) 0.0, cast(double) 0.0, True);
        }
    }
    if (spanData)
        miCleanupSpanData(pDrawable, pGC, spanData);
}

enum V_TOP =	    0;
enum V_RIGHT =	    1;
enum V_BOTTOM =    2;
enum V_LEFT =	    3;

private void miWideDashSegment(DrawablePtr pDrawable, GCPtr pGC, SpanDataPtr spanData, int* pDashOffset, int* pDashIndex, int x1, int y1, int x2, int y2, Bool projectLeft, Bool projectRight, LineFacePtr leftFace, LineFacePtr rightFace)
{
    int dashIndex = void, dashRemain = void;
    ubyte* pDash = void;
    double L = void, l = void;
    double k = void;
    PolyVertexRec[4] vertices = void;
    PolyVertexRec saveRight = void, saveBottom = void;
    PolySlopeRec[4] slopes = void;
    PolyEdgeRec[4] left = void, right = void;
    LineFaceRec lcapFace = void, rcapFace = void;
    int nleft = void, nright = void;
    int h = void;
    int y = void;
    int dy = void, dx = void;
    c_ulong pixel = void;
    double LRemain = void;
    double r = void;
    double rdx = void, rdy = void;
    double dashDx = void, dashDy = void;
    double saveK = 0.0;
    Bool first = True;
    double lcenterx = void, lcentery = void, rcenterx = 0.0, rcentery = 0.0;
    c_ulong fgPixel = void, bgPixel = void;

    dx = x2 - x1;
    dy = y2 - y1;
    dashIndex = *pDashIndex;
    pDash = pGC.dash;
    dashRemain = pDash[dashIndex] - *pDashOffset;
    fgPixel = pGC.fgPixel;
    bgPixel = pGC.bgPixel;
    if (pGC.fillStyle == FillOpaqueStippled || pGC.fillStyle == FillTiled) {
        bgPixel = fgPixel;
    }

    l = (cast(double) pGC.lineWidth) / 2.0;
    if (dx == 0) {
        L = dy;
        rdx = 0;
        rdy = l;
        if (dy < 0) {
            L = -dy;
            rdy = -l;
        }
    }
    else if (dy == 0) {
        L = dx;
        rdx = l;
        rdy = 0;
        if (dx < 0) {
            L = -dx;
            rdx = -l;
        }
    }
    else {
        L = hypot(cast(double) dx, cast(double) dy);
        r = l / L;

        rdx = r * dx;
        rdy = r * dy;
    }
    k = l * L;
    LRemain = L;
    /* All position comments are relative to a line with dx and dy > 0,
     * but the code does not depend on this */
    /* top */
    slopes[V_TOP].dx = dx;
    slopes[V_TOP].dy = dy;
    slopes[V_TOP].k = k;
    /* right */
    slopes[V_RIGHT].dx = -dy;
    slopes[V_RIGHT].dy = dx;
    slopes[V_RIGHT].k = 0;
    /* bottom */
    slopes[V_BOTTOM].dx = -dx;
    slopes[V_BOTTOM].dy = -dy;
    slopes[V_BOTTOM].k = k;
    /* left */
    slopes[V_LEFT].dx = dy;
    slopes[V_LEFT].dy = -dx;
    slopes[V_LEFT].k = 0;

    /* preload the start coordinates */
    vertices[V_RIGHT].x = vertices[V_TOP].x = rdy;
    vertices[V_RIGHT].y = vertices[V_TOP].y = -rdx;

    vertices[V_BOTTOM].x = vertices[V_LEFT].x = -rdy;
    vertices[V_BOTTOM].y = vertices[V_LEFT].y = rdx;

    if (projectLeft) {
        vertices[V_TOP].x -= rdx;
        vertices[V_TOP].y -= rdy;

        vertices[V_LEFT].x -= rdx;
        vertices[V_LEFT].y -= rdy;

        slopes[V_LEFT].k = rdx * dx + rdy * dy;
    }

    lcenterx = x1;
    lcentery = y1;

    if (pGC.capStyle == CapRound) {
        lcapFace.dx = dx;
        lcapFace.dy = dy;
        lcapFace.x = x1;
        lcapFace.y = y1;

        rcapFace.dx = -dx;
        rcapFace.dy = -dy;
        rcapFace.x = x1;
        rcapFace.y = y1;
    }
    while (LRemain > dashRemain) {
        dashDx = (dashRemain * dx) / L;
        dashDy = (dashRemain * dy) / L;

        rcenterx = lcenterx + dashDx;
        rcentery = lcentery + dashDy;

        vertices[V_RIGHT].x += dashDx;
        vertices[V_RIGHT].y += dashDy;

        vertices[V_BOTTOM].x += dashDx;
        vertices[V_BOTTOM].y += dashDy;

        slopes[V_RIGHT].k = vertices[V_RIGHT].x * dx + vertices[V_RIGHT].y * dy;

        if (pGC.lineStyle == LineDoubleDash || !(dashIndex & 1)) {
            if (pGC.lineStyle == LineOnOffDash &&
                pGC.capStyle == CapProjecting) {
                saveRight = vertices[V_RIGHT];
                saveBottom = vertices[V_BOTTOM];
                saveK = slopes[V_RIGHT].k;

                if (!first) {
                    vertices[V_TOP].x -= rdx;
                    vertices[V_TOP].y -= rdy;

                    vertices[V_LEFT].x -= rdx;
                    vertices[V_LEFT].y -= rdy;

                    slopes[V_LEFT].k = vertices[V_LEFT].x *
                        slopes[V_LEFT].dy -
                        vertices[V_LEFT].y * slopes[V_LEFT].dx;
                }

                vertices[V_RIGHT].x += rdx;
                vertices[V_RIGHT].y += rdy;

                vertices[V_BOTTOM].x += rdx;
                vertices[V_BOTTOM].y += rdy;

                slopes[V_RIGHT].k = vertices[V_RIGHT].x *
                    slopes[V_RIGHT].dy -
                    vertices[V_RIGHT].y * slopes[V_RIGHT].dx;
            }
            y = miPolyBuildPoly(vertices.ptr, slopes.ptr, 4, x1, y1,
                                left.ptr, right.ptr, &nleft, &nright, &h);
            pixel = (dashIndex & 1) ? bgPixel : fgPixel;
            miFillPolyHelper(pDrawable, pGC, pixel, spanData, y, h, left.ptr, right.ptr,
                             nleft, nright);

            if (pGC.lineStyle == LineOnOffDash) {
                switch (pGC.capStyle) {
                case CapProjecting:
                    vertices[V_BOTTOM] = saveBottom;
                    vertices[V_RIGHT] = saveRight;
                    slopes[V_RIGHT].k = saveK;
                    break;
                case CapRound:
                    if (!first) {
                        if (dx < 0) {
                            lcapFace.xa = -vertices[V_LEFT].x;
                            lcapFace.ya = -vertices[V_LEFT].y;
                            lcapFace.k = slopes[V_LEFT].k;
                        }
                        else {
                            lcapFace.xa = vertices[V_TOP].x;
                            lcapFace.ya = vertices[V_TOP].y;
                            lcapFace.k = -slopes[V_LEFT].k;
                        }
                        miLineArc(pDrawable, pGC, pixel, spanData,
                                  &lcapFace, cast(LineFacePtr) null,
                                  lcenterx, lcentery, False);
                    }
                    if (dx < 0) {
                        rcapFace.xa = vertices[V_BOTTOM].x;
                        rcapFace.ya = vertices[V_BOTTOM].y;
                        rcapFace.k = slopes[V_RIGHT].k;
                    }
                    else {
                        rcapFace.xa = -vertices[V_RIGHT].x;
                        rcapFace.ya = -vertices[V_RIGHT].y;
                        rcapFace.k = -slopes[V_RIGHT].k;
                    }
                    miLineArc(pDrawable, pGC, pixel, spanData,
                              cast(LineFacePtr) null, &rcapFace,
                              rcenterx, rcentery, False);
                    break;
                default: break;}
            }
        }
        LRemain -= dashRemain;
        ++dashIndex;
        if (dashIndex == pGC.numInDashList)
            dashIndex = 0;
        dashRemain = pDash[dashIndex];

        lcenterx = rcenterx;
        lcentery = rcentery;

        vertices[V_TOP] = vertices[V_RIGHT];
        vertices[V_LEFT] = vertices[V_BOTTOM];
        slopes[V_LEFT].k = -slopes[V_RIGHT].k;
        first = False;
    }

    if (pGC.lineStyle == LineDoubleDash || !(dashIndex & 1)) {
        vertices[V_TOP].x -= dx;
        vertices[V_TOP].y -= dy;

        vertices[V_LEFT].x -= dx;
        vertices[V_LEFT].y -= dy;

        vertices[V_RIGHT].x = rdy;
        vertices[V_RIGHT].y = -rdx;

        vertices[V_BOTTOM].x = -rdy;
        vertices[V_BOTTOM].y = rdx;

        if (projectRight) {
            vertices[V_RIGHT].x += rdx;
            vertices[V_RIGHT].y += rdy;

            vertices[V_BOTTOM].x += rdx;
            vertices[V_BOTTOM].y += rdy;
            slopes[V_RIGHT].k = vertices[V_RIGHT].x *
                slopes[V_RIGHT].dy - vertices[V_RIGHT].y * slopes[V_RIGHT].dx;
        }
        else
            slopes[V_RIGHT].k = 0;

        if (!first && pGC.lineStyle == LineOnOffDash &&
            pGC.capStyle == CapProjecting) {
            vertices[V_TOP].x -= rdx;
            vertices[V_TOP].y -= rdy;

            vertices[V_LEFT].x -= rdx;
            vertices[V_LEFT].y -= rdy;
            slopes[V_LEFT].k = vertices[V_LEFT].x *
                slopes[V_LEFT].dy - vertices[V_LEFT].y * slopes[V_LEFT].dx;
        }
        else
            slopes[V_LEFT].k += dx * dx + dy * dy;

        y = miPolyBuildPoly(vertices.ptr, slopes.ptr, 4, x2, y2,
                            left.ptr, right.ptr, &nleft, &nright, &h);

        pixel = (dashIndex & 1) ? pGC.bgPixel : pGC.fgPixel;
        miFillPolyHelper(pDrawable, pGC, pixel, spanData, y, h, left.ptr, right.ptr,
                         nleft, nright);
        if (!first && pGC.lineStyle == LineOnOffDash &&
            pGC.capStyle == CapRound) {
            lcapFace.x = x2;
            lcapFace.y = y2;
            if (dx < 0) {
                lcapFace.xa = -vertices[V_LEFT].x;
                lcapFace.ya = -vertices[V_LEFT].y;
                lcapFace.k = slopes[V_LEFT].k;
            }
            else {
                lcapFace.xa = vertices[V_TOP].x;
                lcapFace.ya = vertices[V_TOP].y;
                lcapFace.k = -slopes[V_LEFT].k;
            }
            miLineArc(pDrawable, pGC, pixel, spanData,
                      &lcapFace, cast(LineFacePtr) null, rcenterx, rcentery, False);
        }
    }
    dashRemain = cast(int)((cast(double) dashRemain) - LRemain);
    if (dashRemain == 0) {
        dashIndex++;
        if (dashIndex == pGC.numInDashList)
            dashIndex = 0;
        dashRemain = pDash[dashIndex];
    }

    leftFace.x = x1;
    leftFace.y = y1;
    leftFace.dx = dx;
    leftFace.dy = dy;
    leftFace.xa = rdy;
    leftFace.ya = -rdx;
    leftFace.k = k;

    rightFace.x = x2;
    rightFace.y = y2;
    rightFace.dx = -dx;
    rightFace.dy = -dy;
    rightFace.xa = -rdy;
    rightFace.ya = rdx;
    rightFace.k = k;

    *pDashIndex = dashIndex;
    *pDashOffset = pDash[dashIndex] - dashRemain;
}

void miWideDash(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, xPoint* pPts)
{
    int x1 = void, y1 = void, x2 = void, y2 = void;
    c_ulong pixel = void;
    Bool projectLeft = void, projectRight = void;
    LineFaceRec leftFace = void, rightFace = void, prevRightFace = void;
    LineFaceRec firstFace = void;
    int first = void;
    int dashIndex = void, dashOffset = void;
    int prevDashIndex = void;
    SpanDataRec spanDataRec = void;
    SpanDataPtr spanData = void;
    Bool somethingDrawn = False;
    Bool selfJoin = void;
    Bool endIsFg = False, startIsFg = False;
    Bool firstIsFg = False, prevIsFg = False;

version (none) {
    /* XXX backward compatibility */
    if (pGC.lineWidth == 0) {
        miZeroDashLine(pDrawable, pGC, mode, npt, pPts);
        return;
    }
}
    if (pGC.lineStyle == LineDoubleDash &&
        (pGC.fillStyle == FillOpaqueStippled || pGC.fillStyle == FillTiled)) {
        miWideLine(pDrawable, pGC, mode, npt, pPts);
        return;
    }
    if (npt == 0)
        return;
    spanData = miSetupSpanData(pGC, &spanDataRec, npt);
    x2 = pPts.x;
    y2 = pPts.y;
    first = True;
    selfJoin = False;
    if (mode == CoordModePrevious) {
        int nptTmp = void;
        xPoint* pPtsTmp = void;

        x1 = x2;
        y1 = y2;
        nptTmp = npt;
        pPtsTmp = pPts + 1;
        while (--nptTmp) {
            x1 += pPtsTmp.x;
            y1 += pPtsTmp.y;
            ++pPtsTmp;
        }
        if (x2 == x1 && y2 == y1)
            selfJoin = True;
    }
    else if (x2 == pPts[npt - 1].x && y2 == pPts[npt - 1].y) {
        selfJoin = True;
    }
    projectLeft = pGC.capStyle == CapProjecting && !selfJoin;
    projectRight = False;
    dashIndex = 0;
    dashOffset = 0;
    miStepDash(cast(int) pGC.dashOffset, &dashIndex,
               pGC.dash, cast(int) pGC.numInDashList, &dashOffset);
    while (--npt) {
        x1 = x2;
        y1 = y2;
        ++pPts;
        x2 = pPts.x;
        y2 = pPts.y;
        if (mode == CoordModePrevious) {
            x2 += x1;
            y2 += y1;
        }
        if (x1 != x2 || y1 != y2) {
            somethingDrawn = True;
            if (npt == 1 && pGC.capStyle == CapProjecting &&
                (!selfJoin || !firstIsFg))
                projectRight = True;
            prevDashIndex = dashIndex;
            miWideDashSegment(pDrawable, pGC, spanData, &dashOffset, &dashIndex,
                              x1, y1, x2, y2,
                              projectLeft, projectRight, &leftFace, &rightFace);
            startIsFg = !(prevDashIndex & 1);
            endIsFg = (dashIndex & 1) ^ (dashOffset != 0);
            if (pGC.lineStyle == LineDoubleDash || startIsFg) {
                pixel = startIsFg ? pGC.fgPixel : pGC.bgPixel;
                if (first || (pGC.lineStyle == LineOnOffDash && !prevIsFg)) {
                    if (first && selfJoin) {
                        firstFace = leftFace;
                        firstIsFg = startIsFg;
                    }
                    else if (pGC.capStyle == CapRound)
                        miLineArc(pDrawable, pGC, pixel, spanData,
                                  &leftFace, cast(LineFacePtr) null,
                                  cast(double) 0.0, cast(double) 0.0, True);
                }
                else {
                    miLineJoin(pDrawable, pGC, pixel, spanData, &leftFace,
                               &prevRightFace);
                }
            }
            prevRightFace = rightFace;
            prevIsFg = endIsFg;
            first = False;
            projectLeft = False;
        }
        if (npt == 1 && somethingDrawn) {
            if (pGC.lineStyle == LineDoubleDash || endIsFg) {
                pixel = endIsFg ? pGC.fgPixel : pGC.bgPixel;
                if (selfJoin && (pGC.lineStyle == LineDoubleDash || firstIsFg)) {
                    miLineJoin(pDrawable, pGC, pixel, spanData, &firstFace,
                               &rightFace);
                }
                else {
                    if (pGC.capStyle == CapRound)
                        miLineArc(pDrawable, pGC, pixel, spanData,
                                  cast(LineFacePtr) null, &rightFace,
                                  cast(double) 0.0, cast(double) 0.0, True);
                }
            }
            else {
                /* glue a cap to the start of the line if
                 * we're OnOffDash and ended on odd dash
                 */
                if (selfJoin && firstIsFg) {
                    pixel = pGC.fgPixel;
                    if (pGC.capStyle == CapProjecting)
                        miLineProjectingCap(pDrawable, pGC, pixel, spanData,
                                            &firstFace, True,
                                            cast(double) 0.0, cast(double) 0.0, True);
                    else if (pGC.capStyle == CapRound)
                        miLineArc(pDrawable, pGC, pixel, spanData,
                                  &firstFace, cast(LineFacePtr) null,
                                  cast(double) 0.0, cast(double) 0.0, True);
                }
            }
        }
    }
    /* handle crock where all points are coincident */
    if (!somethingDrawn &&
        (pGC.lineStyle == LineDoubleDash || !(dashIndex & 1))) {
        /* not the same as endIsFg computation above */
        pixel = (dashIndex & 1) ? pGC.bgPixel : pGC.fgPixel;
        switch (pGC.capStyle) {
        case CapRound:
            miLineArc(pDrawable, pGC, pixel, spanData,
                      cast(LineFacePtr) null, cast(LineFacePtr) null,
                      cast(double) x2, cast(double) y2, False);
            break;
        case CapProjecting:
            x1 = pGC.lineWidth;
            miFillRectPolyHelper(pDrawable, pGC, pixel, spanData,
                                 x2 - (x1 >> 1), y2 - (x1 >> 1), x1, x1);
            break;
        default: break;}
    }
    if (spanData)
        miCleanupSpanData(pDrawable, pGC, spanData);
}

void miPolylines(DrawablePtr drawable, GCPtr gc, int mode, int n, xPoint* points)
{
    if (gc.lineWidth == 0) {
        if (gc.lineStyle == LineSolid)
            miZeroLine(drawable, gc, mode, n, points);
        else
            miZeroDashLine(drawable, gc, mode, n, points);
    } else {
        if (gc.lineStyle == LineSolid)
            miWideLine(drawable, gc, mode, n, points);
        else
            miWideDash(drawable, gc, mode, n, points);
    }
}
