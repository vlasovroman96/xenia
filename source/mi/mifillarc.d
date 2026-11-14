module mifillarc;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1989, 1998  The Open Group

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

Author:  Bob Scheifler, MIT X Consortium

********************************************************/

import build.dix_config;

import core.stdc.math;
//import x11.X;
//import x11.Xprotostr;
import region;
import dix.gc;
import dix.pixmap;
import mifillarc;
import mizerarc;
import mi.miarc;
import os.string;
import core.stdc.stdint;
import core.sys.posix.unistd;
import   core.stdc.stdio;
import core.stdc.stdlib;
import dix.globals;
import os.os;

enum QUADRANT = (90 * 64);
enum HALFCIRCLE = (180 * 64);
enum QUADRANT3 = (270 * 64);

enum M_PI =	3.14159265358979323846;

struct _miFillArc {
    int xorg, yorg;
    int y;
    int dx, dy;
    int e;
    int ym, yk, xm, xk;
}

enum string MIFILLARCSETUP =   `
    (x) = 0; 
    y = info.y; 
    e = info.e; 
    xk = info.xk; 
    xm = info.xm; 
    yk = info.yk; 
    ym = info.ym; 
    dx = info.dx; 
    dy = info.dy; 
    xorg = info.xorg; 
    yorg = info.yorg;
`;

enum string MIARCSLICESTEP(string edge) =`
    (`~edge~`).x -= (`~edge~`).stepx; 
    (`~edge~`).e -= (`~edge~`).dx; 
    if ((`~edge~`).e <= 0) 
    { 
	(`~edge~`).x -= (`~edge~`).deltax; 
	(`~edge~`).e += (`~edge~`).dy; 
    }
    `;

enum string miFillSliceUpper(string slice) =`
		((y >= (`~slice~`).min_top_y) && (y <= (`~slice~`).max_top_y))`;
        
enum string MIARCSLICELOWER(string xl, string xr, string slice, string slw) =`
    (`~xl~`) = xorg - x; 
    (`~xr~`) = (`~xl~`) + (slw) - 1; 
    if (!(`~slice~`).edge1_top && ((`~slice~`).edge1.x > (`~xl~`))) 
	    (`~xl~`) = (`~slice~`).edge1.x; 
    if (!(`~slice~`).edge2_top && ((`~slice~`).edge2.x < (`~xr~`))) 
	    (`~xr~`) = (`~slice~`).edge2.x;
    `;

enum string MIARCSLICEUPPER(string xl, string xr, string slice, string slw) =`
    (`~xl~`) = cast(short)(xorg - x); 
    (`~xr~`) = cast(short)((`~xl~`) + (slw) - 1); 
    if ((`~slice~`).edge1_top && ((`~slice~`).edge1.x < (`~xr~`))) 
	(`~xr~`) = cast(short)((`~slice~`).edge1.x); 
    if ((`~slice~`).edge2_top && ((`~slice~`).edge2.x > (`~xl~`))) 
	(`~xl~`) = cast(short)((`~slice~`).edge2.x);
    `;

enum string miFillSliceLower(string slice) =`
		((y >= (`~slice~`).min_bot_y) && (y <= (`~slice~`).max_bot_y))`;

enum string miFillArcEmpty(string arc) = `
(
    (` ~ arc ~ `).angle2 != 0 ||
    !(` ~ arc ~ `).width ||
    !(` ~ arc ~ `).height ||
    ((` ~ arc ~ `).width == 1 && (` ~ arc ~ `).height & 1)
)
`;
enum string miCanFillArc(string arc) =` (((`~arc~`).width == (`~arc~`).height) || 
			   (((`~arc~`).width <= 800) && ((`~arc~`).height <= 800)))`;

alias miFillArcRec = _miFillArc;

struct _miFillArcD {
    int xorg, yorg;
    int y;
    int dx, dy;
    double e;
    double ym, yk, xm, xk;
}

alias miFillArcDRec = _miFillArcD;

struct _miSliceEdge {
    int x;
    int stepx;
    int deltax;
    int e;
    int dy;
    int dx;
}
alias miSliceEdgeRec = _miSliceEdge;
alias miSliceEdgePtr = miSliceEdgeRec;

struct _miArcSlice {
    miSliceEdgeRec edge1, edge2;
    int min_top_y, max_top_y;
    int min_bot_y, max_bot_y;
    Bool edge1_top, edge2_top;
    Bool flip_top, flip_bot;
}

alias miArcSliceRec = _miArcSlice;


enum string Dsin(string d) = `sin(cast(double)` ~ d ~ `*(M_PI/11520.0))`;
enum string Dcos(string d) = `cos(cast(double)` ~ d ~ `*(M_PI/11520.0))`;

private void miFillArcSetup(xArc* arc, miFillArcRec* info)
{
    info.y = arc.height >> 1;
    info.dy = arc.height & 1;
    info.yorg = arc.y + info.y;
    info.dx = arc.width & 1;
    info.xorg = arc.x + (arc.width >> 1) + info.dx;
    info.dx = 1 - info.dx;
    if (arc.width == arc.height) {
        /* (2x - 2xorg)^2 = d^2 - (2y - 2yorg)^2 */
        /* even: xorg = yorg = 0   odd:  xorg = .5, yorg = -.5 */
        info.ym = 8;
        info.xm = 8;
        info.yk = info.y << 3;
        if (!info.dx) {
            info.xk = 0;
            info.e = -1;
        }
        else {
            info.y++;
            info.yk += 4;
            info.xk = -4;
            info.e = -(info.y << 3);
        }
    }
    else {
        /* h^2 * (2x - 2xorg)^2 = w^2 * h^2 - w^2 * (2y - 2yorg)^2 */
        /* even: xorg = yorg = 0   odd:  xorg = .5, yorg = -.5 */
        info.ym = (arc.width * arc.width) << 3;
        info.xm = (arc.height * arc.height) << 3;
        info.yk = info.y * info.ym;
        if (!info.dy)
            info.yk -= info.ym >> 1;
        if (!info.dx) {
            info.xk = 0;
            info.e = -(info.xm >> 3);
        }
        else {
            info.y++;
            info.yk += info.ym;
            info.xk = -(info.xm >> 1);
            info.e = info.xk - info.yk;
        }
    }
}

private void miFillArcDSetup(xArc* arc, miFillArcDRec* info)
{
    /* h^2 * (2x - 2xorg)^2 = w^2 * h^2 - w^2 * (2y - 2yorg)^2 */
    /* even: xorg = yorg = 0   odd:  xorg = .5, yorg = -.5 */
    info.y = arc.height >> 1;
    info.dy = arc.height & 1;
    info.yorg = arc.y + info.y;
    info.dx = arc.width & 1;
    info.xorg = arc.x + (arc.width >> 1) + info.dx;
    info.dx = 1 - info.dx;
    info.ym = (cast(double) arc.width) * (arc.width * 8);
    info.xm = (cast(double) arc.height) * (arc.height * 8);
    info.yk = info.y * info.ym;
    if (!info.dy)
        info.yk -= info.ym / 2.0;
    if (!info.dx) {
        info.xk = 0;
        info.e = -(info.xm / 8.0);
    }
    else {
        info.y++;
        info.yk += info.ym;
        info.xk = -info.xm / 2.0;
        info.e = info.xk - info.yk;
    }
}

private void miGetArcEdge(xArc* arc, miSliceEdgePtr edge, int k, Bool top, Bool left)
{
    int xady = void, y = void;

    y = arc.height >> 1;
    if (!(arc.width & 1))
        y++;
    if (!top) {
        y = -y;
        if (arc.height & 1)
            y--;
    }
    xady = k + y * edge.dx;
    if (xady <= 0)
        edge.x = -((-xady) / edge.dy + 1);
    else
        edge.x = (xady - 1) / edge.dy;
    edge.e = xady - edge.x * edge.dy;
    if ((top && (edge.dx < 0)) || (!top && (edge.dx > 0)))
        edge.e = edge.dy - edge.e + 1;
    if (left)
        edge.x++;
    edge.x += arc.x + (arc.width >> 1);
    if (edge.dx > 0) {
        edge.deltax = 1;
        edge.stepx = edge.dx / edge.dy;
        edge.dx = edge.dx % edge.dy;
    }
    else {
        edge.deltax = -1;
        edge.stepx = -((-edge.dx) / edge.dy);
        edge.dx = (-edge.dx) % edge.dy;
    }
    if (!top) {
        edge.deltax = -edge.deltax;
        edge.stepx = -edge.stepx;
    }
}

private void miEllipseAngleToSlope(int angle, int width, int height, int* dxp, int* dyp, double* d_dxp, double* d_dyp)
{
    int dx = void, dy = void;
    double d_dx = void, d_dy = void, scale = void;
    Bool negative_dx = void, negative_dy = void;

    switch (angle) {
    case 0:
        *dxp = -1;
        *dyp = 0;
        if (d_dxp) {
            *d_dxp = width / 2.0;
            *d_dyp = 0;
        }
        break;
    case QUADRANT:
        *dxp = 0;
        *dyp = 1;
        if (d_dxp) {
            *d_dxp = 0;
            *d_dyp = -height / 2.0;
        }
        break;
    case HALFCIRCLE:
        *dxp = 1;
        *dyp = 0;
        if (d_dxp) {
            *d_dxp = -width / 2.0;
            *d_dyp = 0;
        }
        break;
    case QUADRANT3:
        *dxp = 0;
        *dyp = -1;
        if (d_dxp) {
            *d_dxp = 0;
            *d_dyp = height / 2.0;
        }
        break;
    default:
        d_dx = mixin(Dcos!(`angle`)) * width;
        d_dy = mixin(Dsin!(`angle`)) * height;
        if (d_dxp) {
            *d_dxp = d_dx / 2.0;
            *d_dyp = -d_dy / 2.0;
        }
        negative_dx = False;
        if (d_dx < 0.0) {
            d_dx = -d_dx;
            negative_dx = True;
        }
        negative_dy = False;
        if (d_dy < 0.0) {
            d_dy = -d_dy;
            negative_dy = True;
        }
        scale = d_dx;
        if (d_dy > d_dx)
            scale = d_dy;
        dx = cast(int)floor((d_dx * 32768) / scale + 0.5);
        if (negative_dx)
            dx = -dx;
        *dxp = dx;
        dy = cast(int)floor((d_dy * 32768) / scale + 0.5);
        if (negative_dy)
            dy = -dy;
        *dyp = dy;
        break;
    }
}

private void miGetPieEdge(xArc* arc, int angle, miSliceEdgePtr edge, Bool top, Bool left)
{
    int k = void;
    int dx = void, dy = void;

    miEllipseAngleToSlope(angle, arc.width, arc.height, &dx, &dy, null, null);

    if (dy == 0) {
        edge.x = left ? -65536 : 65536;
        edge.stepx = 0;
        edge.e = 0;
        edge.dx = -1;
        return;
    }
    if (dx == 0) {
        edge.x = arc.x + (arc.width >> 1);
        if (left && (arc.width & 1))
            edge.x++;
        else if (!left && !(arc.width & 1))
            edge.x--;
        edge.stepx = 0;
        edge.e = 0;
        edge.dx = -1;
        return;
    }
    if (dy < 0) {
        dx = -dx;
        dy = -dy;
    }
    k = (arc.height & 1) ? dx : 0;
    if (arc.width & 1)
        k += dy;
    edge.dx = dx << 1;
    edge.dy = dy << 1;
    miGetArcEdge(arc, edge, k, top, left);
}

private void miFillArcSliceSetup(xArc* arc, miArcSliceRec* slice, GCPtr pGC)
{
    int angle1 = void, angle2 = void;

    angle1 = arc.angle1;
    if (arc.angle2 < 0) {
        angle2 = angle1;
        angle1 += arc.angle2;
    }
    else
        angle2 = angle1 + arc.angle2;
    while (angle1 < 0)
        angle1 += FULLCIRCLE;
    while (angle1 >= FULLCIRCLE)
        angle1 -= FULLCIRCLE;
    while (angle2 < 0)
        angle2 += FULLCIRCLE;
    while (angle2 >= FULLCIRCLE)
        angle2 -= FULLCIRCLE;
    slice.min_top_y = 0;
    slice.max_top_y = arc.height >> 1;
    slice.min_bot_y = 1 - (arc.height & 1);
    slice.max_bot_y = slice.max_top_y - 1;
    slice.flip_top = False;
    slice.flip_bot = False;
    if (pGC.arcMode == ArcPieSlice) {
        slice.edge1_top = (angle1 < HALFCIRCLE);
        slice.edge2_top = (angle2 <= HALFCIRCLE);
        if ((angle2 == 0) || (angle1 == HALFCIRCLE)) {
            if (angle2 ? slice.edge2_top : slice.edge1_top)
                slice.min_top_y = slice.min_bot_y;
            else
                slice.min_top_y = arc.height;
            slice.min_bot_y = 0;
        }
        else if ((angle1 == 0) || (angle2 == HALFCIRCLE)) {
            slice.min_top_y = slice.min_bot_y;
            if (angle1 ? slice.edge1_top : slice.edge2_top)
                slice.min_bot_y = arc.height;
            else
                slice.min_bot_y = 0;
        }
        else if (slice.edge1_top == slice.edge2_top) {
            if (angle2 < angle1) {
                slice.flip_top = slice.edge1_top;
                slice.flip_bot = !slice.edge1_top;
            }
            else if (slice.edge1_top) {
                slice.min_top_y = 1;
                slice.min_bot_y = arc.height;
            }
            else {
                slice.min_bot_y = 0;
                slice.min_top_y = arc.height;
            }
        }
        miGetPieEdge(arc, angle1, slice.edge1,
                     slice.edge1_top, !slice.edge1_top);
        miGetPieEdge(arc, angle2, slice.edge2,
                     slice.edge2_top, slice.edge2_top);
    }
    else {
        double w2 = void, h2 = void, x1 = void, y1 = void, x2 = void, y2 = void, dx = void, dy = void, scale = void;
        int signdx = void, signdy = void, y = void, k = void;
        Bool isInt1 = True, isInt2 = True;

        w2 = cast(double) arc.width / 2.0;
        h2 = cast(double) arc.height / 2.0;
        if ((angle1 == 0) || (angle1 == HALFCIRCLE)) {
            x1 = angle1 ? -w2 : w2;
            y1 = 0.0;
        }
        else if ((angle1 == QUADRANT) || (angle1 == QUADRANT3)) {
            x1 = 0.0;
            y1 = (angle1 == QUADRANT) ? h2 : -h2;
        }
        else {
            isInt1 = False;
            x1 = mixin(Dcos!(`angle1`)) * w2;
            y1 = mixin(Dsin!(`angle1`)) * h2;
        }
        if ((angle2 == 0) || (angle2 == HALFCIRCLE)) {
            x2 = angle2 ? -w2 : w2;
            y2 = 0.0;
        }
        else if ((angle2 == QUADRANT) || (angle2 == QUADRANT3)) {
            x2 = 0.0;
            y2 = (angle2 == QUADRANT) ? h2 : -h2;
        }
        else {
            isInt2 = False;
            x2 = mixin(Dcos!(`angle2`)) * w2;
            y2 = mixin(Dsin!(`angle2`)) * h2;
        }
        dx = x2 - x1;
        dy = y2 - y1;
        if (arc.height & 1) {
            y1 -= 0.5;
            y2 -= 0.5;
        }
        if (arc.width & 1) {
            x1 += 0.5;
            x2 += 0.5;
        }
        if (dy < 0.0) {
            dy = -dy;
            signdy = -1;
        }
        else
            signdy = 1;
        if (dx < 0.0) {
            dx = -dx;
            signdx = -1;
        }
        else
            signdx = 1;
        if (isInt1 && isInt2) {
            slice.edge1.dx = cast(int)dx * 2;
            slice.edge1.dy = cast(int)dy * 2;
        }
        else {
            scale = (dx > dy) ? dx : dy;
            slice.edge1.dx = cast(int)floor((dx * 32768) / scale + .5);
            slice.edge1.dy = cast(int)floor((dy * 32768) / scale + .5);
        }
        if (!slice.edge1.dy) {
            if (signdx < 0) {
                y = cast(int)floor(y1 + 1.0);
                if (y >= 0) {
                    slice.min_top_y = y;
                    slice.min_bot_y = arc.height;
                }
                else {
                    slice.max_bot_y = -y - (arc.height & 1);
                }
            }
            else {
                y = cast(int)floor(y1);
                if (y >= 0)
                    slice.max_top_y = y;
                else {
                    slice.min_top_y = arc.height;
                    slice.min_bot_y = -y - (arc.height & 1);
                }
            }
            slice.edge1_top = True;
            slice.edge1.x = 65536;
            slice.edge1.stepx = 0;
            slice.edge1.e = 0;
            slice.edge1.dx = -1;
            slice.edge2 = slice.edge1;
            slice.edge2_top = False;
        }
        else if (!slice.edge1.dx) {
            if (signdy < 0)
                x1 -= 1.0;
            slice.edge1.x = cast(int)ceil(x1);
            slice.edge1_top = signdy < 0;
            slice.edge1.x += arc.x + (arc.width >> 1);
            slice.edge1.stepx = 0;
            slice.edge1.e = 0;
            slice.edge1.dx = -1;
            slice.edge2_top = !slice.edge1_top;
            slice.edge2 = slice.edge1;
        }
        else {
            if (signdx < 0)
                slice.edge1.dx = -slice.edge1.dx;
            if (signdy < 0)
                slice.edge1.dx = -slice.edge1.dx;
            k = cast(int)ceil(((x1 + x2) * slice.edge1.dy -
                      (y1 + y2) * slice.edge1.dx) / 2.0);
            slice.edge2.dx = slice.edge1.dx;
            slice.edge2.dy = slice.edge1.dy;
            slice.edge1_top = signdy < 0;
            slice.edge2_top = !slice.edge1_top;
            miGetArcEdge(arc, slice.edge1, k,
                         slice.edge1_top, !slice.edge1_top);
            miGetArcEdge(arc, slice.edge2, k,
                         slice.edge2_top, slice.edge2_top);
        }
    }
}

enum string ADDSPANS() = `
    pts.x = cast(short)(xorg - x); 
    pts.y = cast(short)(yorg - y); 
    *wids = slw; 
    pts++; 
    wids++; 
    if (mixin(miFillArcLower!("slw"))) 
    { 
	pts.x = cast(short)(xorg - x); 
	pts.y = cast(short)(yorg + y + dy); 
	pts++; 
	*wids++ = slw; 
    }`;

enum string miFillArcLower(string slw) =` (((y + dy) != 0) && (((`~slw~`) > 1) || (e != xk)))`;

private int miFillEllipseI(DrawablePtr pDraw, GCPtr pGC, xArc* arc, xPoint* points, int* widths)
{
    int x = void, y = void, e = void;
    int yk = void, xk = void, ym = void, xm = void, dx = void, dy = void, xorg = void, yorg = void;
    int slw = void;
    miFillArcRec info = void;
    xPoint* pts = void;
    int* wids = void;

    miFillArcSetup(arc, &info);
    mixin(MIFILLARCSETUP);
    if (pGC.miTranslate) {
        xorg += pDraw.x;
        yorg += pDraw.y;
    }
    pts = points;
    wids = widths;
    while (y > 0) {
        mixin(MIFILLARCSTEP!("slw"));
        mixin(ADDSPANS!());
    }
    return cast(int)(pts - points);
}

private int miFillEllipseD(DrawablePtr pDraw, GCPtr pGC, xArc* arc, xPoint* points, int* widths)
{
    int x = void, y = void;
    int xorg = void, yorg = void, dx = void, dy = void, slw = void;
    double e = void, yk = void, xk = void, ym = void, xm = void;
    miFillArcDRec info = void;
    xPoint* pts = void;
    int* wids = void;

    miFillArcDSetup(arc, &info);
    mixin(MIFILLARCSETUP);
    if (pGC.miTranslate) {
        xorg += pDraw.x;
        yorg += pDraw.y;
    }
    pts = points;
    wids = widths;
    while (y > 0) {
        mixin(MIFILLARCSTEP!("slw"));
        mixin(ADDSPANS!());
    }
    return cast(int)(pts - points);
}

enum string ADDSPAN(string l,string r) = `
    if (` ~ r ~ ` >= ` ~ l ~ `) 
    { 
	pts.x = cast(short)(` ~ l ~ `); 
	pts.y = cast(short)(ya); 
	pts++; 
	*wids++ = ` ~ r ~ ` - ` ~ l ~ ` + 1; 
    }`;

enum string ADDSLICESPANS(string flip) = `
    if (!` ~ flip ~ `) 
    { 
	` ~ ADDSPAN!(`xl`, `xr`) ~ `; 
    } 
    else 
    { 
	xc = xorg - x; 
	` ~ ADDSPAN!(`xc`, `xr`) ~ `; 
	xc += slw - 1; 
	` ~ ADDSPAN!(`xl`, `xc`) ~ `; 
    }`;

private int miFillArcSliceI(DrawablePtr pDraw, GCPtr pGC, xArc* arc, xPoint* points, int* widths)
{
    int yk = void, xk = void, ym = void, xm = void, dx = void, dy = void, xorg = void, yorg = void, slw = void;
    int x = void, y = void, e = void;
    miFillArcRec info = void;
    miArcSliceRec slice = void;
    int ya = void, xl = void, xr = void, xc = void;
    xPoint* pts = void;
    int* wids = void;

    miFillArcSetup(arc, &info);
    miFillArcSliceSetup(arc, &slice, pGC);
    mixin(MIFILLARCSETUP);
    slw = arc.height;
    if (slice.flip_top || slice.flip_bot)
        slw += (arc.height >> 1) + 1;
    if (pGC.miTranslate) {
        xorg += pDraw.x;
        yorg += pDraw.y;
        slice.edge1.x += pDraw.x;
        slice.edge2.x += pDraw.x;
    }
    pts = points;
    wids = widths;
    while (y > 0) {
        mixin(MIFILLARCSTEP!("slw"));
        mixin(MIARCSLICESTEP!("slice.edge1"));
        mixin(MIARCSLICESTEP!("slice.edge2"));
        if (mixin(miFillSliceUpper!("slice"))) {
            ya = yorg - y;
            mixin(MIARCSLICEUPPER!("xl", "xr", "slice", "slw"));
            mixin(ADDSLICESPANS!(`slice.flip_top`));
        }
        if (mixin(miFillSliceLower!("slice"))) {
            ya = yorg + y + dy;
            mixin(MIARCSLICELOWER!("xl", "xr", "slice", "slw"));
            mixin(ADDSLICESPANS!(`slice.flip_bot`));
        }
    }
    return cast(int)(pts - points);
}

private int miFillArcSliceD(DrawablePtr pDraw, GCPtr pGC, xArc* arc, xPoint* points, int* widths)
{
    int x = void, y = void;
    int dx = void, dy = void, xorg = void, yorg = void, slw = void;
    double e = void, yk = void, xk = void, ym = void, xm = void;
    miFillArcDRec info = void;
    miArcSliceRec slice = void;
    int ya = void, xl = void, xr = void, xc = void;
    xPoint* pts = void;
    int* wids = void;

    miFillArcDSetup(arc, &info);
    miFillArcSliceSetup(arc, &slice, pGC);
    mixin(MIFILLARCSETUP);;
    slw = arc.height;
    if (slice.flip_top || slice.flip_bot)
        slw += (arc.height >> 1) + 1;
    if (pGC.miTranslate) {
        xorg += pDraw.x;
        yorg += pDraw.y;
        slice.edge1.x += pDraw.x;
        slice.edge2.x += pDraw.x;
    }
    pts = points;
    wids = widths;
    while (y > 0) {
        mixin(MIFILLARCSTEP!("slw"));
        mixin(MIARCSLICESTEP!("slice.edge1"));
        mixin(MIARCSLICESTEP!("slice.edge2"));
        if (mixin(miFillSliceUpper!("slice"))) {
            ya = yorg - y;
            mixin(MIARCSLICEUPPER!("xl", "xr", "slice", "slw"));
            mixin(ADDSLICESPANS!(`slice.flip_top`));
        }
        if (mixin(miFillSliceLower!("slice"))) {
            ya = yorg + y + dy;
            mixin(MIARCSLICELOWER!("xl", "xr", "slice", "slw"));
            mixin(ADDSLICESPANS!(`slice.flip_bot`));
        }
    }
    return cast(int)(pts - points);
}

/* MIPOLYFILLARC -- The public entry for the PolyFillArc request.
 * Since we don't have to worry about overlapping segments, we can just
 * fill each arc as it comes.
 */

/* Limit the number of spans in a single draw request to avoid integer
 * overflow in the computation of the span buffer size.
 */
enum MAX_SPANS_PER_LOOP =      (4 * 1024 * 1024);

void miPolyFillArc(DrawablePtr pDraw, GCPtr pGC, int narcs_all, xArc* parcs)
{
    while (narcs_all > 0) {
        int narcs = void;
        int i = void;
        xArc* arc = void;
        int nspans = 0;
        xPoint* pts = void, points = void;
        int* wids = void, widths = void;
        int n = void;

        for (narcs = cast(int)0, arc = parcs; narcs < narcs_all; narcs++, arc++) {
            if (narcs && nspans + arc.height > MAX_SPANS_PER_LOOP)
                break;
            nspans += arc.height;

            /* A pie-slice arc may add another pile of spans */
            if (pGC.arcMode == ArcPieSlice &&
                (-FULLCIRCLE < arc.angle2 && arc.angle2 < FULLCIRCLE))
                nspans += (arc.height + 1) >> 1;
        }

        pts = points = cast(xPoint*)calloc(1, ((xPoint).sizeof * nspans +
                               int.sizeof * nspans));
        if (points) {
            wids = widths = cast(int*) (points + nspans);

            for (i = 0, arc = parcs; i < narcs; arc++, i++) {
                if (mixin(miFillArcEmpty!("arc")))
                    continue;
                if ((arc.angle2 >= FULLCIRCLE) || (arc.angle2 <= -FULLCIRCLE))
                {
                    if (mixin(miCanFillArc!("arc")))
                        n = miFillEllipseI(pDraw, pGC, arc, pts, wids);
                    else
                        n = miFillEllipseD(pDraw, pGC, arc, pts, wids);
                }
                else
                {
                    if (mixin(miCanFillArc!("arc")))
                        n = miFillArcSliceI(pDraw, pGC, arc, pts, wids);
                    else
                        n = miFillArcSliceD(pDraw, pGC, arc, pts, wids);
                }
                pts += n;
                wids += n;
            }
            nspans = cast(int)(pts - points);
            if (nspans)
                (*pGC.ops.FillSpans) (pDraw, pGC, nspans, points,
                                        widths, False);
            free (points);
        }
        parcs += narcs;
        narcs_all -= narcs;
    }
}
