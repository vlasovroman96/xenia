module dix.gc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

import core.stdc.assert_;
//import x11.X;
//import x11.Xmd;
//import x11.Xproto;
import dix.dixfonts;

import dix.gc_priv;
import os.osdep;

import dix.gc;
import dix.pixmap;
import dix.scrnintstr;
import dix.dixstruct_priv;
import dix.privates;
import Xext.xace;
import dix.dixutils;
import dix.resource;
import os.log;

//public import x11.Xprotostr;

public import dix.gc;
public import region;
public import dix.scrintstr;

import legacyXf = externs.X11.fonts.font;
import legacyXfs = externs.X11.fonts.fontstruct;

// alias xSegment = x11.Xprotostr.xSegment;
// alias xRectangle = x11.Xprotostr.xRectangle;
// alias xArc = x11.Xprotostr.xArc;

version (_XTYPEDEF_CHARINFOPTR) {} else {
alias CharInfoPtr = legacyXfs._CharInfo*;  /* also in fonts/include/font.h */
// version = _XTYPEDEF_CHARINFOPTR;
}

/*
 * functions which modify the state of the GC
 */

struct GCFuncs {
    void function(GCPtr, c_ulong, DrawablePtr) @nogc nothrow ValidateGC;

    void function(GCPtr, c_ulong) @nogc nothrow ChangeGC;

    void function(GCPtr, c_ulong, GCPtr) @nogc nothrow CopyGC;

    void function(GCPtr) @nogc nothrow DestroyGC;

    void function(GCPtr pGC, int type, void* pvalue, int nrects) @nogc nothrow ChangeClip;

    void function(GCPtr) @nogc nothrow DestroyClip;

    void function(GCPtr, GCPtr) @nogc nothrow CopyClip;
}

/*
 * graphics operations invoked through a GC
 */

struct _GCOps {
    void function(DrawablePtr, GCPtr, int, xPoint*, int*, int) @nogc nothrow FillSpans;

    void function(DrawablePtr, GCPtr, char*, xPoint*, int*, int, int) @nogc nothrow SetSpans;

    void function(DrawablePtr, GCPtr, int, int, int, int, int, int, int, char*) @nogc nothrow PutImage ;

    RegionPtr function(DrawablePtr, DrawablePtr, GCPtr, int, int, int, int, int, int) @nogc nothrow CopyArea;

    RegionPtr function(DrawablePtr, DrawablePtr, GCPtr, int, int, int, int, int, int, c_ulong) @nogc nothrow CopyPlane;
    void function(DrawablePtr, GCPtr, int, int, xPoint*) @nogc nothrow PolyPoint;

    void function(DrawablePtr, GCPtr, int, int, xPoint*) @nogc nothrow Polylines;

    void function(DrawablePtr, GCPtr, int, xSegment*) @nogc nothrow PolySegment;

    void function(DrawablePtr, GCPtr, int, xRectangle*) @nogc nothrow PolyRectangle;

    void function(DrawablePtr, GCPtr, int, xArc*) @nogc nothrow PolyArc;

    void function(DrawablePtr, GCPtr, int, int, int, xPoint*) @nogc nothrow FillPolygon;

    void function(DrawablePtr, GCPtr, int, xRectangle*) @nogc nothrow PolyFillRect;

    void function(DrawablePtr, GCPtr, int, xArc*) @nogc nothrow PolyFillArc;

    int function(DrawablePtr, GCPtr, int, int, int, char*) @nogc nothrow PolyText8;

    int function(DrawablePtr, GCPtr, int, int, int, ushort*) @nogc nothrow PolyText16;

    void function(DrawablePtr, GCPtr, int, int, int, char*) @nogc nothrow ImageText8;

    void function(DrawablePtr, GCPtr, int, int, int, ushort*) @nogc nothrow ImageText16;

    void function(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase) @nogc nothrow ImageGlyphBlt;

    void function(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase) @nogc nothrow PolyGlyphBlt;

    void function(GCPtr, PixmapPtr, DrawablePtr, int, int, int, int) @nogc nothrow PushPixels;
}

/* there is padding in the bit fields because the Sun compiler doesn't
 * force alignment to 32-bit boundaries.  losers.
 */
struct _GC {
    ScreenPtr pScreen;
    ubyte depth;
    ubyte alu;
    ushort lineWidth;
    ushort dashOffset;
    ushort numInDashList;
    ubyte* dash;
    uint lineStyle : 2;
    uint capStyle : 2;
    uint joinStyle : 2;
    uint fillStyle : 2;
    uint fillRule : 1;
    uint arcMode : 1;
    uint subWindowMode : 1;
    uint graphicsExposures : 1;
    uint miTranslate : 1; /* should mi things translate? */
    uint tileIsPixel : 1; /* tile is solid pixel */
    uint fExpose : 1;     /* Call exposure handling */
    uint freeCompClip : 1;        /* Free composite clip */
    uint scratch_inuse : 1;       /* is this GC in a pool for reuse? */
    uint unused : 15;     /* see comment above */
    uint planemask;
    uint fgPixel;
    uint bgPixel;
    /*
     * alas -- both tile and stipple must be here as they
     * are independently specifiable
     */
    PixUnion tile;
    PixmapPtr stipple;
    xPoint patOrg;         /* origin for (tile, stipple) */
    xPoint clipOrg;
    legacyXfs._Font* font;
    RegionPtr clientClip;
    uint stateChanges; /* masked with GC_<kind> */
    uint serialNumber;
    const(GCFuncs)* funcs;
    const(_GCOps)* ops;
    PrivateRec* devPrivates;
    RegionPtr pCompositeClip;
}

alias GCRec = _GC;

/* clientClipType field in GC */
enum CT_NONE =			0;
enum CT_PIXMAP =		1;
enum CT_REGION =		2;
enum CT_UNSORTED =		6;
enum CT_YSORTED =		10;
enum CT_YXSORTED =		14;
enum CT_YXBANDED =		18;

enum ulong GC_CHANGE_SERIAL_BIT =        1<<31;

enum DRAWABLE_SERIAL_BITS =        (~(GC_CHANGE_SERIAL_BIT));

enum MAX_SERIAL_NUM =     (1L<<28);

@property auto NEXT_SERIAL_NUMBER() { return ((++globalSerialNumber) > MAX_SERIAL_NUM ? 
	    (globalSerialNumber  = 1): globalSerialNumber);
};

struct _GCInterest;
alias GCInterestPtr = _GCInterest*;
alias GCPtr = _GC*;
alias GCOpsPtr = _GCOps*;
alias GCOps = _GCOps;

// void ValidateGC(DrawablePtr, GCPtr);

union _ChangeGCVal {
    CARD32 val;
    void* ptr;
}alias ChangeGCVal = _ChangeGCVal;
alias ChangeGCValPtr = ChangeGCVal*;

FontPtr defaultFont;



private ubyte[2] DefaultDash = [ 4, 4 ];

void ValidateGC(DrawablePtr pDraw, GCPtr pGC)
{
    (*pGC.funcs.ValidateGC) (pGC, pGC.stateChanges, pDraw);
    pGC.stateChanges = 0;
    pGC.serialNumber = cast(uint)pDraw.serialNumber;
}

/*
 * ChangeGC/ChangeGCXIDs:
 *
 * The client performing the gc change must be passed so that access
 * checks can be performed on any tiles, stipples, or fonts that are
 * specified.  ddxen can call this too; they should normally pass
 * NULL for the client since any access checking should have
 * already been done at a higher level.
 *
 * If you have any XIDs, you must use ChangeGCXIDs:
 *
 *     CARD32 v[2];
 *     v[0] = FillTiled;
 *     v[1] = pid;
 *     ChangeGCXIDs(client, pGC, GCFillStyle|GCTile, v);
 *
 * However, if you need to pass a pointer to a pixmap or font, you must
 * use ChangeGC:
 *
 *     ChangeGCVal v[2];
 *     v[0].val = FillTiled;
 *     v[1].ptr = pPixmap;
 *     ChangeGC(client, pGC, GCFillStyle|GCTile, v);
 *
 * If you have neither XIDs nor pointers, you can use either function,
 * but ChangeGC will do less work.
 *
 *     ChangeGCVal v[2];
 *     v[0].val = foreground;
 *     v[1].val = background;
 *     ChangeGC(client, pGC, GCForeground|GCBackground, v);
 */

enum string NEXTVAL(string _type, string _var) = `{ 
	` ~ _var ~ ` = cast(` ~ _type ~ `)(pUnion.val); pUnion++; 
    }`;

enum string NEXT_PTR(string _type, string _var) = `{ 
    ` ~ _var ~ ` = cast(`~_type~`)pUnion.ptr; pUnion++; }`;

int ChangeGC(ClientPtr client, GCPtr pGC, BITS32 mask, ChangeGCValPtr pUnion)
{
    BITS32 index2 = void;
    int error = 0;
    PixmapPtr pPixmap = void;
    BITS32 maskQ = void;

    assert(pUnion);
    pGC.serialNumber |= GC_CHANGE_SERIAL_BIT;

    maskQ = mask;               /* save these for when we walk the GCque */
    while (mask && !error) {
        index2 = cast(BITS32) mixin(lowbit!mask);
        mask &= ~index2;
        pGC.stateChanges |= index2;
        switch (cast(long)index2) {
        case GCFunction:
        {
            CARD8 newalu = void;
            mixin(NEXTVAL!(`CARD8`, `newalu`));

            if (newalu <= GXset)
                pGC.alu = newalu;
            else {
                if (client)
                    client.errorValue = cast(uint)newalu;
                error = BadValue;
            }
            break;
        }
        case GCPlaneMask:
            mixin(NEXTVAL!("uint", "pGC.planemask"));

            break;
        case GCForeground:
            mixin(NEXTVAL!("uint", "pGC.fgPixel"));

            /*
             * this is for CreateGC
             */
            if (!pGC.tileIsPixel && !pGC.tile.pixmap) {
                pGC.tileIsPixel = TRUE;
                pGC.tile.pixel = pGC.fgPixel;
            }
            break;
        case GCBackground:
            mixin(NEXTVAL!("uint", "pGC.bgPixel"));

            break;
        case GCLineWidth:      /* ??? line width is a CARD16 */
            mixin(NEXTVAL!(`CARD16`, `pGC.lineWidth`));

            break;
        case GCLineStyle:
        {
            uint newlinestyle = void;
            mixin(NEXTVAL!("uint", "newlinestyle"));

            if (newlinestyle <= LineDoubleDash)
                pGC.lineStyle = newlinestyle;
            else {
                if (client)
                    client.errorValue = cast(uint)newlinestyle;
                error = BadValue;
            }
            break;
        }
        case GCCapStyle:
        {
            uint newcapstyle = void;
            mixin(NEXTVAL!("uint", "newcapstyle"));

            if (newcapstyle <= CapProjecting)
                pGC.capStyle = newcapstyle;
            else {
                if (client)
                    client.errorValue = cast(uint)newcapstyle;
                error = BadValue;
            }
            break;
        }
        case GCJoinStyle:
        {
            uint newjoinstyle = void;
            mixin(NEXTVAL!("uint", "newjoinstyle"));

            if (newjoinstyle <= JoinBevel)
                pGC.joinStyle = newjoinstyle;
            else {
                if (client)
                    client.errorValue = cast(uint)newjoinstyle;
                error = BadValue;
            }
            break;
        }
        case GCFillStyle:
        {
            uint newfillstyle = void;
            mixin(NEXTVAL!("uint", "newfillstyle"));

            if (newfillstyle <= FillOpaqueStippled)
                pGC.fillStyle = newfillstyle;
            else {
                if (client)
                    client.errorValue = cast(uint)newfillstyle;
                error = BadValue;
            }
            break;
        }
        case GCFillRule:
        {
            uint newfillrule = void;
            mixin(NEXTVAL!("uint", "newfillrule"));

            if (newfillrule <= WindingRule)
                pGC.fillRule = newfillrule;
            else {
                if (client)
                    client.errorValue = cast(uint)newfillrule;
                error = BadValue;
            }
            break;
        }
        case GCTile:
            mixin(NEXT_PTR!(`PixmapPtr`, `pPixmap`));

            if ((pPixmap.drawable.depth != pGC.depth) ||
                (pPixmap.drawable.pScreen != pGC.pScreen)) {
                error = BadMatch;
            }
            else {
                pPixmap.refcnt++;
                if (!pGC.tileIsPixel)
                    dixDestroyPixmap(pGC.tile.pixmap, 0);
                pGC.tileIsPixel = FALSE;
                pGC.tile.pixmap = pPixmap;
            }
            break;
        case GCStipple:
            mixin(NEXT_PTR!(`PixmapPtr`, `pPixmap`));

            if (pPixmap && ((pPixmap.drawable.depth != 1) ||
                            (pPixmap.drawable.pScreen != pGC.pScreen)))
            {
                error = BadMatch;
            }
            else {
                if (pPixmap)
                    pPixmap.refcnt++;
                if (pGC.stipple)
                    dixDestroyPixmap(pGC.stipple, 0);
                pGC.stipple = pPixmap;
            }
            break;
        case GCTileStipXOrigin:
            mixin(NEXTVAL!(`INT16`, `pGC.patOrg.x`));

            break;
        case GCTileStipYOrigin:
            mixin(NEXTVAL!(`INT16`, `pGC.patOrg.y`));

            break;
        case GCFont:
        {
            FontPtr pFont = void;
            mixin(NEXT_PTR!(`FontPtr`, `pFont`));

            pFont.refcnt++;
            if (pGC.font)
                CloseFont(pGC.font, cast(Font) 0);
            pGC.font = pFont;
            break;
        }
        case GCSubwindowMode:
        {
            uint newclipmode = void;
            mixin(NEXTVAL!("uint", "newclipmode"));

            if (newclipmode <= IncludeInferiors)
                pGC.subWindowMode = newclipmode;
            else {
                if (client)
                    client.errorValue = cast(uint)newclipmode;
                error = BadValue;
            }
            break;
        }
        case GCGraphicsExposures:
        {
            uint newge = void;
            mixin(NEXTVAL!("uint", "newge"));

            if (newge <= xTrue)
                pGC.graphicsExposures = newge;
            else {
                if (client)
                    client.errorValue = cast(uint)newge;
                error = BadValue;
            }
            break;
        }
        case GCClipXOrigin:
            mixin(NEXTVAL!(`INT16`, `pGC.clipOrg.x`));

            break;
        case GCClipYOrigin:
            mixin(NEXTVAL!(`INT16`, `pGC.clipOrg.y`));

            break;
        case GCClipMask:
            mixin(NEXT_PTR!(`PixmapPtr`, `pPixmap`));

            if (pPixmap) {
                if ((pPixmap.drawable.depth != 1) ||
                    (pPixmap.drawable.pScreen != pGC.pScreen)) {
                    error = BadMatch;
                    break;
                }
                pPixmap.refcnt++;
            }
            (*pGC.funcs.ChangeClip) (pGC, pPixmap ? CT_PIXMAP : CT_NONE,
                                       cast(void*) pPixmap, 0);
            break;
        case GCDashOffset:
            mixin(NEXTVAL!(`INT16`, `pGC.dashOffset`));

            break;
        case GCDashList:
        {
            CARD8 newdash = void;
            mixin(NEXTVAL!(`CARD8`, `newdash`));

            if (newdash == 4) {
                if (pGC.dash != DefaultDash.ptr) {
                    free(pGC.dash);
                    pGC.numInDashList = 2;
                    pGC.dash = DefaultDash.ptr;
                }
            }
            else if (newdash != 0) {
                ubyte* dash = cast(ubyte*) calloc(2, ubyte.sizeof);
                if (dash) {
                    if (pGC.dash != DefaultDash.ptr)
                        free(pGC.dash);
                    pGC.numInDashList = 2;
                    pGC.dash = dash;
                    dash[0] = newdash;
                    dash[1] = newdash;
                }
                else
                    error = BadAlloc;
            }
            else {
                if (client)
                    client.errorValue = cast(uint)newdash;
                error = BadValue;
            }
            break;
        }
        case GCArcMode:
        {
            uint newarcmode = void;
            mixin(NEXTVAL!("uint", "newarcmode"));

            if (newarcmode <= ArcPieSlice)
                pGC.arcMode = newarcmode;
            else {
                if (client)
                    client.errorValue = cast(uint)newarcmode;
                error = BadValue;
            }
            break;
        }
        default:
            if (client)
                client.errorValue = cast(uint)maskQ;
            error = BadValue;
            break;
        }
    }                           /* end while mask && !error */

    if (pGC.fillStyle == FillTiled && pGC.tileIsPixel) {
        if (!CreateDefaultTile(pGC)) {
            pGC.fillStyle = FillSolid;
            error = BadAlloc;
        }
    }
    (*pGC.funcs.ChangeGC) (pGC, maskQ);
    return error;
}

struct _Xidfields {
    BITS32 mask;
    RESTYPE type;
    Mask access_mode;
}private const(_Xidfields)[5] xidfields = [
    {GCTile,     X11_RESTYPE_PIXMAP, DixReadAccess},
    {GCStipple,  X11_RESTYPE_PIXMAP, DixReadAccess},
    {GCFont,     X11_RESTYPE_FONT,   DixUseAccess},
    {GCClipMask, X11_RESTYPE_PIXMAP, DixReadAccess},
];

int ChangeGCXIDs(ClientPtr client, GCPtr pGC, BITS32 mask, CARD32* pC32)
{
    ChangeGCVal[GCLastBit + 1] vals = void;

    if (mask & ~GCAllBits) {
        client.errorValue = cast(uint)mask;
        return BadValue;
    }
    for (int i = Ones(mask); i--;)
        vals[i].val = pC32[i];
    for (int i = 0; i < xidfields.length; ++i) {
        int offset = void, rc = void;
        XID id = void;

        if (!(mask & xidfields[i].mask))
            continue;
        offset = Ones(mask & (xidfields[i].mask - 1));
        if (xidfields[i].mask == GCClipMask && vals[offset].val == None) {
            vals[offset].ptr = NullPixmap;
            continue;
        }
        /* save the id, since dixLookupResourceByType overwrites &vals[offset] */
        id = vals[offset].val;
        rc = dixLookupResourceByType(&vals[offset].ptr, id,
                                     xidfields[i].type, client,
                                     xidfields[i].access_mode);
        if (rc != Success) {
            client.errorValue = cast(uint)id;
            return rc;
        }
    }
    return ChangeGC(client, pGC, mask, vals.ptr);
}

private GCPtr NewGCObject(ScreenPtr pScreen, int depth)
{
    GCPtr pGC = void;

    pGC = cast(_GC*)mixin(dixAllocateScreenObjectWithPrivates!("pScreen", "GCRec", "PRIVATE_GC"));
    if (!pGC) {
        return cast(GCPtr) null;
    }

    pGC.pScreen = pScreen;
    pGC.depth = cast(ubyte)depth;
    pGC.alu = GXcopy;          /* dst <- src */
    pGC.planemask = ~0;
    pGC.serialNumber = 0;
    pGC.funcs = null;
    pGC.fgPixel = 0;
    pGC.bgPixel = 1;
    pGC.lineWidth = 0;
    pGC.lineStyle = LineSolid;
    pGC.capStyle = CapButt;
    pGC.joinStyle = JoinMiter;
    pGC.fillStyle = FillSolid;
    pGC.fillRule = EvenOddRule;
    pGC.arcMode = ArcPieSlice;
    pGC.tile.pixel = 0;
    pGC.tile.pixmap = NullPixmap;

    pGC.tileIsPixel = TRUE;
    pGC.patOrg.x = 0;
    pGC.patOrg.y = 0;
    pGC.subWindowMode = ClipByChildren;
    pGC.graphicsExposures = TRUE;
    pGC.clipOrg.x = 0;
    pGC.clipOrg.y = 0;
    pGC.clientClip = null;
    pGC.numInDashList = 2;
    pGC.dash = DefaultDash.ptr;
    pGC.dashOffset = 0;

    /* use the default font and stipple */
    pGC.font = defaultFont;
    if (pGC.font)              /* necessary, because open of default font could fail */
        pGC.font.refcnt++;
    pGC.stipple = pGC.pScreen.defaultStipple;
    if (pGC.stipple)
        pGC.stipple.refcnt++;

    /* this is not a scratch GC */
    pGC.scratch_inuse = FALSE;
    return pGC;
}

/* CreateGC(pDrawable, mask, pval, pStatus)
   creates a default GC for the given drawable, using mask to fill
   in any non-default values.
   Returns a pointer to the new GC on success, NULL otherwise.
   returns status of non-default fields in pStatus
BUG:
   should check for failure to create default tile

*/
GCPtr CreateGC(DrawablePtr pDrawable, BITS32 mask, XID* pval, int* pStatus, XID gcid, ClientPtr client)
{
    GCPtr pGC = void;

    pGC = NewGCObject(pDrawable.pScreen, pDrawable.depth);
    if (!pGC) {
        *pStatus = BadAlloc;
        return cast(GCPtr) null;
    }

    pGC.serialNumber = cast(uint)GC_CHANGE_SERIAL_BIT;
    if (mask & GCForeground) {
        /*
         * magic special case -- ChangeGC checks for this condition
         * and snags the Foreground value to create a pseudo default-tile
         */
        pGC.tileIsPixel = FALSE;
    }
    else {
        pGC.tileIsPixel = TRUE;
    }

    /* security creation/labeling check */
    *pStatus = XaceHookResourceAccess(client, gcid, X11_RESTYPE_GC, pGC,
                        X11_RESTYPE_NONE, null, DixCreateAccess | DixSetAttrAccess);
    if (*pStatus != Success)
        goto out_;

    pGC.stateChanges = GCAllBits;
    if (!(*pGC.pScreen.CreateGC) (pGC))
        *pStatus = BadAlloc;
    else if (mask)
        *pStatus = ChangeGCXIDs(client, pGC, mask, pval);
    else
        *pStatus = Success;

 out_:
    if (*pStatus != Success) {
        if (!pGC.tileIsPixel && !pGC.tile.pixmap)
            pGC.tileIsPixel = TRUE;    /* undo special case */
        FreeGC(pGC, cast(XID) 0);
        pGC = cast(GCPtr) null;
    }

    return pGC;
}

private Bool CreateDefaultTile(GCPtr pGC)
{
    ChangeGCVal[3] tmpval = void;
    PixmapPtr pTile = void;
    GCPtr pgcScratch = void;
    xRectangle rect = void;
    CARD16 w = void, h = void;

    w = 1;
    h = 1;
    (*pGC.pScreen.QueryBestSize) (TileShape, &w, &h, pGC.pScreen);
    pTile = cast(PixmapPtr)
        (*pGC.pScreen.CreatePixmap) (pGC.pScreen, w, h, pGC.depth, 0);
    pgcScratch = GetScratchGC(pGC.depth, pGC.pScreen);
    if (!pTile || !pgcScratch) {
        dixDestroyPixmap(pTile, 0);
        if (pgcScratch)
            FreeScratchGC(pgcScratch);
        return FALSE;
    }
    tmpval[0].val = cast(uint)GXcopy;
    tmpval[1].val = cast(uint)pGC.tile.pixel;
    tmpval[2].val = FillSolid;
    cast(void) ChangeGC(null, pgcScratch,
                    cast(uint)(GCFunction | GCForeground | GCFillStyle), tmpval.ptr);
    ValidateGC(cast(DrawablePtr) pTile, pgcScratch);
    rect.x = 0;
    rect.y = 0;
    rect.width = w;
    rect.height = h;
    (*pgcScratch.ops.PolyFillRect) (cast(DrawablePtr) pTile, pgcScratch, 1,
                                      &rect);
    /* Always remember to free the scratch graphics context after use. */
    FreeScratchGC(pgcScratch);

    pGC.tileIsPixel = FALSE;
    pGC.tile.pixmap = pTile;
    return TRUE;
}

int CopyGC(GCPtr pgcSrc, GCPtr pgcDst, BITS32 mask)
{
    BITS32 index2 = void;
    BITS32 maskQ = void;
    int error = 0;

    if (pgcSrc == pgcDst)
        return Success;
    pgcDst.serialNumber |= GC_CHANGE_SERIAL_BIT;
    pgcDst.stateChanges |= mask;
    maskQ = mask;
    while (cast(long)mask) {
        index2 = cast(BITS32) mixin(lowbit!mask);
        mask &= ~index2;
        switch (cast(long)index2) {
        case GCFunction:
            pgcDst.alu = pgcSrc.alu;
            break;
        case GCPlaneMask:
            pgcDst.planemask = pgcSrc.planemask;
            break;
        case GCForeground:
            pgcDst.fgPixel = pgcSrc.fgPixel;
            break;
        case GCBackground:
            pgcDst.bgPixel = pgcSrc.bgPixel;
            break;
        case GCLineWidth:
            pgcDst.lineWidth = pgcSrc.lineWidth;
            break;
        case GCLineStyle:
            pgcDst.lineStyle = pgcSrc.lineStyle;
            break;
        case GCCapStyle:
            pgcDst.capStyle = pgcSrc.capStyle;
            break;
        case GCJoinStyle:
            pgcDst.joinStyle = pgcSrc.joinStyle;
            break;
        case GCFillStyle:
            pgcDst.fillStyle = pgcSrc.fillStyle;
            break;
        case GCFillRule:
            pgcDst.fillRule = pgcSrc.fillRule;
            break;
        case GCTile:
        {
            if (mixin(EqualPixUnion!("pgcDst.tileIsPixel",
                              "pgcDst.tile",
                              "pgcSrc.tileIsPixel", "pgcSrc.tile"))) {
                break;
            }
            if (!pgcDst.tileIsPixel)
                dixDestroyPixmap(pgcDst.tile.pixmap, 0);
            pgcDst.tileIsPixel = pgcSrc.tileIsPixel;
            pgcDst.tile = pgcSrc.tile;
            if (!pgcDst.tileIsPixel)
                pgcDst.tile.pixmap.refcnt++;
            break;
        }
        case GCStipple:
        {
            if (pgcDst.stipple == pgcSrc.stipple)
                break;
            if (pgcDst.stipple)
                dixDestroyPixmap(pgcDst.stipple, 0);
            pgcDst.stipple = pgcSrc.stipple;
            if (pgcDst.stipple)
                pgcDst.stipple.refcnt++;
            break;
        }
        case GCTileStipXOrigin:
            pgcDst.patOrg.x = pgcSrc.patOrg.x;
            break;
        case GCTileStipYOrigin:
            pgcDst.patOrg.y = pgcSrc.patOrg.y;
            break;
        case GCFont:
            if (pgcDst.font == pgcSrc.font)
                break;
            if (pgcDst.font)
                CloseFont(pgcDst.font, cast(Font) 0);
            if ((pgcDst.font = pgcSrc.font) != NullFont)
                (pgcDst.font).refcnt++;
            break;
        case GCSubwindowMode:
            pgcDst.subWindowMode = pgcSrc.subWindowMode;
            break;
        case GCGraphicsExposures:
            pgcDst.graphicsExposures = pgcSrc.graphicsExposures;
            break;
        case GCClipXOrigin:
            pgcDst.clipOrg.x = pgcSrc.clipOrg.x;
            break;
        case GCClipYOrigin:
            pgcDst.clipOrg.y = pgcSrc.clipOrg.y;
            break;
        case GCClipMask:
            (*pgcDst.funcs.CopyClip) (pgcDst, pgcSrc);
            break;
        case GCDashOffset:
            pgcDst.dashOffset = pgcSrc.dashOffset;
            break;
        case GCDashList:
            if (pgcSrc.dash == DefaultDash.ptr) {
                if (pgcDst.dash != DefaultDash.ptr) {
                    free(pgcDst.dash);
                    pgcDst.numInDashList = pgcSrc.numInDashList;
                    pgcDst.dash = pgcSrc.dash;
                }
            }
            else {
                ubyte* dash = cast(ubyte*) calloc(pgcSrc.numInDashList, ubyte.sizeof);
                if (dash) {
                    if (pgcDst.dash != DefaultDash.ptr)
                        free(pgcDst.dash);
                    pgcDst.numInDashList = pgcSrc.numInDashList;
                    pgcDst.dash = dash;
                    for (uint i = 0; i < pgcSrc.numInDashList; i++)
                        dash[i] = pgcSrc.dash[i];
                }
                else
                    error = BadAlloc;
            }
            break;
        case GCArcMode:
            pgcDst.arcMode = pgcSrc.arcMode;
            break;
        default:
            FatalError("CopyGC: Unhandled mask!\n");
        }
    }
    if (pgcDst.fillStyle == FillTiled && pgcDst.tileIsPixel) {
        if (!CreateDefaultTile(pgcDst)) {
            pgcDst.fillStyle = FillSolid;
            error = BadAlloc;
        }
    }
    (*pgcDst.funcs.CopyGC) (pgcSrc, maskQ, pgcDst);
    return error;
}

/**
 * does the diX part of freeing the characteristics in the GC.
 *
 *  \param value  must conform to DeleteType
 */
int FreeGC(void* value, XID gid)
{
    GCPtr pGC = cast(GCPtr) value;
    if (!pGC)
        return BadMatch;

    CloseFont(pGC.font, cast(Font) 0);
    if (pGC.funcs)
        (*pGC.funcs.DestroyClip) (pGC);

    if (!pGC.tileIsPixel)
        dixDestroyPixmap(pGC.tile.pixmap, 0);
    if (pGC.stipple)
        dixDestroyPixmap(pGC.stipple, 0);

    if (pGC.funcs)
        (*pGC.funcs.DestroyGC) (pGC);
    if (pGC.dash != DefaultDash.ptr)
        free(pGC.dash);
    mixin(dixFreeObjectWithPrivatesM!("pGC", "PRIVATE_GC"));
    return Success;
}

/* CreateScratchGC(pScreen, depth)
    like CreateGC, but doesn't do the default tile or stipple,
since we can't create them without already having a GC.  any code
using the tile or stipple has to set them explicitly anyway,
since the state of the scratch gc is unknown.  This is OK
because ChangeGC() has to be able to deal with NULL tiles and
stipples anyway (in case the CreateGC() call has provided a
value for them -- we can't set the default tile until the
client-supplied attributes are installed, since the fgPixel
is what fills the default tile.  (maybe this comment should
go with CreateGC() or ChangeGC().)
*/

private GCPtr CreateScratchGC(ScreenPtr pScreen, uint depth)
{
    GCPtr pGC = void;

    pGC = NewGCObject(pScreen, depth);
    if (!pGC)
        return cast(GCPtr) null;

    pGC.stateChanges = GCAllBits;
    if (!(*pScreen.CreateGC) (pGC)) {
        FreeGC(pGC, cast(XID) 0);
        pGC = cast(GCPtr) null;
    }
    else
        pGC.graphicsExposures = FALSE;
    return pGC;
}

void FreeGCperDepth(ScreenPtr pScreen)
{
    GCPtr* ppGC = void;

    if (!pScreen)
        return;

    ppGC = cast(GCPtr*)pScreen.GCperDepth;

    for (int i = 0; i <= pScreen.numDepths; i++) {
        cast(void) FreeGC(ppGC[i], cast(XID) 0);
        ppGC[i] = null;
    }
}

Bool CreateGCperDepth(ScreenPtr pScreen)
{
    DepthPtr pDepth = void;
    GCPtr* ppGC = void;

    ppGC = cast(GCPtr*)&pScreen.GCperDepth;
    /* do depth 1 separately because it's not included in list */
    if (((ppGC[0] = CreateScratchGC(pScreen, 1)) is null))
        return FALSE;
    /* Make sure we don't overflow GCperDepth[] */
    if (pScreen.numDepths > MAXFORMATS)
        return FALSE;

    pDepth = pScreen.allowedDepths;
    for (int i = 0; i < pScreen.numDepths; i++, pDepth++) {
        if (((ppGC[i + 1] = CreateScratchGC(pScreen, pDepth.depth)) is null)) {
            for (; i >= 0; i--)
                cast(void) FreeGC(ppGC[i], cast(XID) 0);
            return FALSE;
        }
    }
    return TRUE;
}

Bool CreateDefaultStipple(ScreenPtr pScreen)
{
    ChangeGCVal[3] tmpval = void;
    xRectangle rect = void;
    CARD16 w = void, h = void;
    GCPtr pgcScratch = void;

    w = 16;
    h = 16;
    (*pScreen.QueryBestSize) (StippleShape, &w, &h, pScreen);
    if (((pScreen.defaultStipple = pScreen.CreatePixmap(pScreen, w, h, 1, 0)) is null))
        return FALSE;
    /* fill stipple with 1 */
    tmpval[0].val = GXcopy;
    tmpval[1].val = 1;
    tmpval[2].val = FillSolid;
    pgcScratch = GetScratchGC(1, pScreen);
    if (!pgcScratch) {
        dixDestroyPixmap(pScreen.defaultStipple, 0);
        return FALSE;
    }
    cast(void) ChangeGC(null, pgcScratch,
                    cast(uint)(GCFunction | GCForeground | GCFillStyle), tmpval.ptr);
    ValidateGC(cast(DrawablePtr) pScreen.defaultStipple, pgcScratch);
    rect.x = 0;
    rect.y = 0;
    rect.width = w;
    rect.height = h;
    (*pgcScratch.ops.PolyFillRect) (cast(DrawablePtr) pScreen.defaultStipple,
                                      pgcScratch, 1, &rect);
    FreeScratchGC(pgcScratch);
    return TRUE;
}

int SetDashes(GCPtr pGC, uint offset, uint ndash, ubyte* pdash)
{
    c_long i = void;
    ubyte* p = void, indash = void;
    BITS32 maskQ = 0;

    i = ndash;
    p = pdash;
    while (i--) {
        if (!*p++) {
            /* dash segment must be > 0 */
            return BadValue;
        }
    }

    if (ndash & 1)
        p = cast(ubyte*) calloc(2 * ndash, ubyte.sizeof);
    else
        p = cast(ubyte*) calloc(ndash, ubyte.sizeof);
    if (!p)
        return BadAlloc;

    pGC.serialNumber |= GC_CHANGE_SERIAL_BIT;
    if (offset != pGC.dashOffset) {
        pGC.dashOffset = cast(ushort)offset;
        pGC.stateChanges |= GCDashOffset;
        maskQ |= GCDashOffset;
    }

    if (pGC.dash != DefaultDash.ptr)
        free(pGC.dash);
    pGC.numInDashList = cast(ushort)ndash;
    pGC.dash = p;
    if (ndash & 1) {
        pGC.numInDashList += ndash;
        indash = pdash;
        i = ndash;
        while (i--)
            *p++ = *indash++;
    }
    while (ndash--)
        *p++ = *pdash++;
    pGC.stateChanges |= GCDashList;
    maskQ |= GCDashList;

    if (pGC.funcs.ChangeGC)
        (*pGC.funcs.ChangeGC) (pGC, maskQ);
    return Success;
}

int VerifyRectOrder(int nrects, xRectangle* prects, int ordering)
{
    xRectangle* prectP = void, prectN = void;
    int i = void;

    switch (ordering) {
    case Unsorted:
        return CT_UNSORTED;
    case YSorted:
        if (nrects > 1) {
            for (i = 1, prectP = prects, prectN = prects + 1;
                 i < nrects; i++, prectP++, prectN++)
                if (prectN.y < prectP.y)
                    return -1;
        }
        return CT_YSORTED;
    case YXSorted:
        if (nrects > 1) {
            for (i = 1, prectP = prects, prectN = prects + 1;
                 i < nrects; i++, prectP++, prectN++)
                if ((prectN.y < prectP.y) ||
                    ((prectN.y == prectP.y) && (prectN.x < prectP.x)))
                    return -1;
        }
        return CT_YXSORTED;
    case YXBanded:
        if (nrects > 1) {
            for (i = 1, prectP = prects, prectN = prects + 1;
                 i < nrects; i++, prectP++, prectN++)
                if ((prectN.y != prectP.y &&
                     prectN.y < prectP.y + cast(int) prectP.height) ||
                    ((prectN.y == prectP.y) &&
                     (prectN.height != prectP.height ||
                      prectN.x < prectP.x + cast(int) prectP.width)))
                    return -1;
        }
        return CT_YXBANDED;
    default: break;}
    return -1;
}

int SetClipRects(GCPtr pGC, INT16 xOrigin, INT16 yOrigin, size_t nrects, xRectangle* prects, BYTE ordering)
{
    int newct = void, size = void;

    newct = VerifyRectOrder(cast(int)nrects, prects, ordering);
    if (newct < 0)
        return BadMatch;
    size = cast(int)(nrects * xRectangle.sizeof);

    xRectangle* prectsNew = cast(xRectangle*) calloc(1, size);
    if (!prectsNew && size)
        return BadAlloc;

    pGC.serialNumber |= GC_CHANGE_SERIAL_BIT;
    pGC.clipOrg.x = xOrigin;
    pGC.stateChanges |= GCClipXOrigin;

    pGC.clipOrg.y = yOrigin;
    pGC.stateChanges |= GCClipYOrigin;

    if (size && prectsNew)
        memmove(cast(char*) prectsNew, cast(char*) prects, size);
    (*pGC.funcs.ChangeClip) (pGC, newct, cast(void*) prectsNew, cast(int)nrects);
    if (pGC.funcs.ChangeGC)
        (*pGC.funcs.ChangeGC) (pGC,
                                 GCClipXOrigin | GCClipYOrigin | GCClipMask);
    return Success;
}

/*
   sets reasonable defaults
   if we can get a pre-allocated one, use it and mark it as used.
   if we can't, create one out of whole cloth (The Velveteen GC -- if
   you use it often enough it will become real.)
*/
GCPtr GetScratchGC(uint depth, ScreenPtr pScreen)
{
    GCPtr pGC = void;

    for (int i = 0; i <= pScreen.numDepths; i++) {
        pGC = pScreen.GCperDepth[i];
        if (pGC && pGC.depth == depth && !pGC.scratch_inuse) {
            pGC.scratch_inuse = TRUE;

            pGC.alu = GXcopy;
            pGC.planemask = ~0;
            pGC.serialNumber = 0;
            pGC.fgPixel = 0;
            pGC.bgPixel = 1;
            pGC.lineWidth = 0;
            pGC.lineStyle = LineSolid;
            pGC.capStyle = CapButt;
            pGC.joinStyle = JoinMiter;
            pGC.fillStyle = FillSolid;
            pGC.fillRule = EvenOddRule;
            pGC.arcMode = ArcChord;
            pGC.patOrg.x = 0;
            pGC.patOrg.y = 0;
            pGC.subWindowMode = ClipByChildren;
            pGC.graphicsExposures = FALSE;
            pGC.clipOrg.x = 0;
            pGC.clipOrg.y = 0;
            if (pGC.clientClip)
                (*pGC.funcs.ChangeClip) (pGC, CT_NONE, null, 0);
            pGC.stateChanges = GCAllBits;
            return pGC;
        }
    }
    /* if we make it this far, need to roll our own */
    return CreateScratchGC(pScreen, depth);
}

/*
   if the gc to free is in the table of pre-existing ones,
mark it as available.
   if not, free it for real
*/
void FreeScratchGC(GCPtr pGC)
{
    if (pGC.scratch_inuse)
        pGC.scratch_inuse = FALSE;
    else
        FreeGC(pGC, cast(GContext) 0);
}
