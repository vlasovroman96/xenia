module mi.miline;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1994, 1998  The Open Group

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

*/

 
public import include.scrintstr;
public import include.privates;

/*
 * Public definitions used for configuring basic pixelization aspects
 * of the sample implementation line-drawing routines provided in
 * {mfb,mi,cfb*} at run-time.
 */

enum XDECREASING =	4;
enum YDECREASING =	2;
enum YMAJOR =		1;

enum OCTANT1 =		(1 << (YDECREASING));
enum OCTANT2 =		(1 << (YDECREASING|YMAJOR));
enum OCTANT3 =		(1 << (XDECREASING|YDECREASING|YMAJOR));
enum OCTANT4 =		(1 << (XDECREASING|YDECREASING));
enum OCTANT5 =		(1 << (XDECREASING));
enum OCTANT6 =		(1 << (XDECREASING|YMAJOR));
enum OCTANT7 =		(1 << (YMAJOR));
enum OCTANT8 =		(1 << (0));

/*
 * Devices can configure the rendering of routines in mi, mfb, and cfb*
 * by specifying a thin line bias to be applied to a particular screen
 * using the following function.  The bias parameter is an OR'ing of
 * the appropriate OCTANT constants defined above to indicate which
 * octants to bias a line to prefer an axial step when the Bresenham
 * error term is exactly zero.  The octants are mapped as follows:
 *
 *   \    |    /
 *    \ 3 | 2 /
 *     \  |  /
 *    4 \ | / 1
 *       \|/
 *   -----------
 *       /|\
 *    5 / | \ 8
 *     /  |  \
 *    / 6 | 7 \
 *   /    |    \
 *
 * For more information, see "Ambiguities in Incremental Line Rastering,"
 * Jack E. Bresenham, IEEE CG&A, May 1987.
 */

void  miSetZeroLineBias(ScreenPtr, uint);

/*
 * Private definitions needed for drawing thin (zero width) lines
 * Used by the mi, mfb, and all cfb* components.
 */

enum X_AXIS =	0;
enum Y_AXIS =	1;

enum OUT_LEFT =  0x08;
enum OUT_RIGHT = 0x04;
enum OUT_ABOVE = 0x02;
enum OUT_BELOW = 0x01;

enum string OUTCODES(string _result, string _x, string _y, string _pbox) = `
    if	    ( (` ~ _x ~ `) <  (` ~ _pbox ~ `).x1) (` ~ _result ~ `) |= OUT_LEFT; 
    else if ( (` ~ _x ~ `) >= (` ~ _pbox ~ `).x2) (` ~ _result ~ `) |= OUT_RIGHT; 
    if	    ( (` ~ _y ~ `) <  (` ~ _pbox ~ `).y1) (` ~ _result ~ `) |= OUT_ABOVE; 
    else if ( (` ~ _y ~ `) >= (` ~ _pbox ~ `).y2) (` ~ _result ~ `) |= OUT_BELOW;`;

enum string MIOUTCODES(string outcode, string x, string y, string xmin, string ymin, string xmax, string ymax) = `
{
     if (` ~ x ~ ` < ` ~ xmin ~ `) ` ~ outcode ~ ` |= OUT_LEFT;
     if (` ~ x ~ ` > ` ~ xmax ~ `) ` ~ outcode ~ ` |= OUT_RIGHT;
     if (` ~ y ~ ` < ` ~ ymin ~ `) ` ~ outcode ~ ` |= OUT_ABOVE;
     if (` ~ y ~ ` > ` ~ ymax ~ `) ` ~ outcode ~ ` |= OUT_BELOW;
}`;

enum string miGetZeroLineBias(string _pScreen) = `(cast(c_ulong) cast(c_ulong*)
    dixLookupPrivate(&(` ~ _pScreen ~ `).devPrivates, miZeroLineScreenKey))`;

enum string CalcLineDeltas(string _x1,string _y1,string _x2,string _y2,string _adx,string _ady,string _sx,string _sy,string _SX,string _SY,string _octant) = `
    (` ~ _octant ~ `) = 0;				
    (` ~ _sx ~ `) = (` ~ _SX ~ `);				
    if (((` ~ _adx ~ `) = (` ~ _x2 ~ `) - (` ~ _x1 ~ `)) < 0) {		
	(` ~ _adx ~ `) = -(` ~ _adx ~ `);			
	(` ~ _sx ~ ` = -(` ~ _sx ~ `));				
	(` ~ _octant ~ `) |= XDECREASING;		
    }						
    (` ~ _sy ~ `) = (` ~ _SY ~ `);				
    if (((` ~ _ady ~ `) = (` ~ _y2 ~ `) - (` ~ _y1 ~ `)) < 0) {		
	(` ~ _ady ~ `) = -(` ~ _ady ~ `);			
	(` ~ _sy ~ ` = -(` ~ _sy ~ `));				
	(` ~ _octant ~ `) |= YDECREASING;		
    }`;

enum string SetYMajorOctant(string _octant) = `((` ~ _octant ~ `) |= YMAJOR);`;

enum string FIXUP_ERROR(string _e, string _octant, string _bias) = `
    (` ~ _e ~ `) -= (((` ~ _bias ~ `) >> (` ~ _octant ~ `)) & 1);`;

DevPrivateKeyRec miZeroLineScreenKeyRec;

enum miZeroLineScreenKey = (&miZeroLineScreenKeyRec);

// void  miZeroClipLine(int, int, int, int, int*, int*, int*, int*, uint, uint, int*, int*, int, uint, int, int);

                          /* MILINE_H */
