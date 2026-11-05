module mipolyrect;
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
import build.dix_config;

//import x11.X;
//import x11.Xprotostr;
import region;
import dix.gc;
import dix.pixmap;

void miPolyRectangle(DrawablePtr pDraw, GCPtr pGC, int nrects, xRectangle* pRects)
{
    int i = void;
    xRectangle* pR = pRects;
    xPoint[5] rect = void;
    int bound_tmp = void;

enum string MINBOUND(string dst,string eqn) = `bound_tmp = ` ~ eqn ~ `; 
				if (bound_tmp < -32768) 
				    bound_tmp = -32768; 
				` ~ dst ~ ` = cast(typeof(`~dst~`))bound_tmp;`;

enum string MAXBOUND(string dst,string eqn) = `bound_tmp = ` ~ eqn ~ `; 
				if (bound_tmp > 32767) 
				    bound_tmp = 32767; 
				` ~ dst ~ ` = cast(typeof(`~dst~`))bound_tmp;`;

enum string MAXUBOUND(string dst,string eqn) = `bound_tmp = ` ~ eqn ~ `; 
				if (bound_tmp > 65535) 
				    bound_tmp = 65535; 
				` ~ dst ~ ` = cast(typeof(`~dst~`))bound_tmp;`;

    if (pGC.lineStyle == LineSolid && pGC.joinStyle == JoinMiter &&
        pGC.lineWidth != 0) {
        xRectangle* tmp, t;
        int ntmp;
        int offset1, offset2, offset3;
        int x, y, width, height;

        ntmp = (nrects << 2);
        offset2 = pGC.lineWidth;
        offset1 = offset2 >> 1;
        offset3 = offset2 - offset1;
        tmp = cast(xRectangle*) calloc(ntmp, xRectangle.sizeof);
        if (!tmp)
            return;
        t = tmp;
        for (i = 0; i < nrects; i++) {
            x = pR.x;
            y = pR.y;
            width = pR.width;
            height = pR.height;
            pR++;
            if (width == 0 && height == 0) {
                rect[0].x = cast(short)x;
                rect[0].y = cast(short)y;
                rect[1].x = cast(short)x;
                rect[1].y = cast(short)y;
                (*pGC.ops.Polylines) (pDraw, pGC, CoordModeOrigin, 2, rect.ptr);
            }
            else if (height < offset2 || width < offset1) {
                if (height == 0) {
                    t.x = cast(short)x;
                    t.width = cast(ushort)width;
                }
                else {
                    mixin(MINBOUND!(`t.x`, `x - offset1`));
                        mixin(MAXUBOUND!(`t.width`, `width + offset2`));
                }
                if (width == 0) {
                    t.y = cast(short)y;
                    t.height = cast(ushort)height;
                }
                else {
                    mixin(MINBOUND!(`t.y`, `y - offset1`));
                        mixin(MAXUBOUND!(`t.height`, `height + offset2`));
                }
                t++;
            }
            else {
                mixin(MINBOUND!(`t.x`, `x - offset1`));
                    mixin(MINBOUND!(`t.y`, `y - offset1`));
                    mixin(MAXUBOUND!(`t.width`, `width + offset2`));
                    t.height = cast(ushort)(offset2);
                t++;
                mixin(MINBOUND!(`t.x`, `x - offset1`));
                    mixin(MAXBOUND!(`t.y`, `y + offset3`));;
                t.width = cast(ushort)(offset2);
                t.height = cast(ushort)(height - offset2);
                t++;
                mixin(MAXBOUND!(`t.x`, `x + width - offset1`));
                mixin(MAXBOUND!(`t.y`, `y + offset3`));
                    t.width = cast(ushort)(offset2);
                t.height = cast(ushort)(height - offset2);
                t++;
                mixin(MINBOUND!(`t.x`, `x - offset1`));
                    mixin(MAXBOUND!(`t.y`, `y + height - offset1`));
                    mixin(MAXUBOUND!(`t.width`, `width + offset2`));
                    t.height = cast(ushort)(offset2);
                t++;
            }
        }
        (*pGC.ops.PolyFillRect) (pDraw, pGC, cast(int)(t - tmp), tmp);
        free(cast(void*) tmp);
    }
    else {

        for (i = 0; i < nrects; i++) {
            rect[0].x = pR.x;
            rect[0].y = pR.y;

            mixin(MAXBOUND!(`rect[1].x`, `pR.x + cast(int) pR.width`));
                rect[1].y = rect[0].y;

            rect[2].x = rect[1].x;
            mixin(MAXBOUND!(`rect[2].y`, `pR.y + cast(int) pR.height`));

            rect[3].x = rect[0].x;
            rect[3].y = rect[2].y;

            rect[4].x = rect[0].x;
            rect[4].y = rect[0].y;

            (*pGC.ops.Polylines) (pDraw, pGC, CoordModeOrigin, 5, rect.ptr);
            pR++;
        }
    }
}
