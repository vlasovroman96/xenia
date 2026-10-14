module dix.colormap;
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
import x11.Xmd;

enum DynamicClass =  1;

alias Pixel = CARD32;
import build.xlibre_server;
import Xext.panoramiXsrv;
//import x11.X;
//import x11.Xproto;
// //import stdbool;
import core.stdc.stdio;
import core.stdc.string;
import externs.strings;

import include.extinit;
import dix.colormap_priv;
import dix.dix_priv;
import dix.resource_priv;
import dix.window_priv;
import os.osdep;
import os.bug_priv;

import include.misc;
import include.dix;
import include.dixstruct;
import include.os;
import include.scrnintstr;
import include.resource;
import include.windowstr;
import include.privates;
import Xext.xace;
import os.osinit;
import std.conv;
import dix.events;

enum REDMAP = 0;
enum GREENMAP = 1;
enum BLUEMAP = 2;
enum PSEUDOMAP = 3;

enum AllocPrivate = (-1);
enum AllocTemporary = (-2);

alias ColorCompareProcPtr = int function(EntryPtr, xrgb*);
/* LOCO -- a local color for a PseudoColor cell. DirectColor maps always
 * use the first value (called red) in the structure.  What channel they
 * are really talking about depends on which map they are in. */
 struct LOCO {
    ushort red, green, blue;
}

































enum string NUMRED(string vis) = `((` ~ vis ~ `.redMask >> ` ~ vis ~ `.offsetRed) + 1)`;
enum string NUMGREEN(string vis) = `((` ~ vis ~ `.greenMask >> ` ~ vis ~ `.offsetGreen) + 1)`;
enum string NUMBLUE(string vis) = `((` ~ vis ~ `.blueMask >> ` ~ vis ~ `.offsetBlue) + 1)`;
enum string ALPHAMASK(string vis) = `((` ~ vis ~ `).nplanes < 32 ? 0 : 
			 cast(CARD32) ~((` ~ vis ~ `).redMask|(` ~ vis ~ `).greenMask|(` ~ vis ~ `).blueMask))`;
enum string RGBMASK(string vis) = `(` ~ vis ~ `.redMask | ` ~ vis ~ `.greenMask | ` ~ vis ~ `.blueMask | ` ~ ALPHAMASK!(vis) ~ `)`;

/* GetNextBitsOrBreak(bits, mask, base)  --
 * (Suggestion: First read the macro, then read this explanation.
 *
 * Either generate the next value to OR in to a pixel or break out of this
 * while loop
 *
 * This macro is used when we're trying to generate all 2^n combinations of
 * bits in mask.  What we're doing here is counting in binary, except that
 * the bits we use to count may not be contiguous.  This macro will be
 * called 2^n times, returning a different value in bits each time. Then
 * it will cause us to break out of a surrounding loop. (It will always be
 * called from within a while loop.)
 * On call: mask is the value we want to find all the combinations for
 * base has 1 bit set where the least significant bit of mask is set
 *
 * For example,if mask is 01010, base should be 0010 and we count like this:
 * 00010 (see this isn't so hard),
 *     then we add base to bits and get 0100. (bits & ~mask) is (0100 & 0100) so
 *      we add that to bits getting (0100 + 0100) =
 * 01000 for our next value.
 *      then we add 0010 to get
 * 01010 and we're done (easy as 1, 2, 3)
 */
enum string GetNextBitsOrBreak(string bits, string mask, string base) = `
	    if((` ~ bits ~ `) == (` ~ mask ~ `)) 		
		break;		 		
	    (` ~ bits ~ `) += (` ~ base ~ `);		 	
	    while((` ~ bits ~ `) & ~(` ~ mask ~ `))		
		(` ~ bits ~ `) += ((` ~ bits ~ `) & ~(` ~ mask ~ `));`;

struct colorResource {
    Colormap mid;
    int client;
}

/* Invariants:
 * refcnt == 0 means entry is empty
 * refcnt > 0 means entry is useable by many clients, so it can't be changed
 * refcnt == AllocPrivate means entry owned by one client only
 * fShared should only be set if refcnt == AllocPrivate, and only in red map
 */

/**
 * Create and initialize the color map
 *
 * \param mid    resource to use for this colormap
 * \param alloc  1 iff all entries are allocated writable
 */
int dixCreateColormap(Colormap mid, ScreenPtr pScreen, VisualPtr pVisual, ColormapPtr* ppcmap, int alloc, ClientPtr pClient)
{
    if (!pClient)
        return BadMatch;

    const(int) clientIndex = pClient.index;
    const(int) class_ = pVisual.class_;

    if (!(class_ & DynamicClass) && (alloc != AllocNone) &&
        (pClient != serverClient))
        return BadMatch;

    int size = pVisual.ColormapEntries;
    c_ulong sizebytes = (size * Entry.sizeof) +
        (LimitClients * (Pixel*).sizeof) + (LimitClients * int.sizeof);
    if ((class_ | DynamicClass) == DirectColor)
        sizebytes *= 3;
    sizebytes += ColormapRec.sizeof;

    ColormapPtr pmap = void;
    if (mid == pScreen.defColormap) {
        pmap = cast(ColormapPtr)calloc(1, sizebytes);
        if (!pmap)
            return BadAlloc;
        if (!dixAllocatePrivates(&pmap.devPrivates, PRIVATE_COLORMAP)) {
            free(pmap);
            return BadAlloc;
        }
    }
    else {
        pmap = cast(ColormapPtr)_dixAllocateObjectWithPrivates(cast(uint)sizebytes, cast(uint)sizebytes,
                                              ColormapRec.devPrivates.offsetof,
                                              PRIVATE_COLORMAP);
        if (!pmap)
            return BadAlloc;
    }
    pmap.red = cast(EntryPtr) (cast(char*) pmap + ColormapRec.sizeof);
    sizebytes = size * Entry.sizeof;
    pmap.clientPixelsRed = cast(Pixel**) (cast(char*) pmap.red + sizebytes);
    pmap.numPixelsRed = cast(int*) (cast(char*) pmap.clientPixelsRed +
                                  (LimitClients * (Pixel*).sizeof));
    pmap.mid = mid;
    pmap.flags = 0;            /* start out with all flags clear */
    if (mid == pScreen.defColormap)
        pmap.flags |= CM_IsDefault;
    pmap.pScreen = pScreen;
    pmap.pVisual = pVisual;
    pmap.class_ = class_;
    if ((class_ | DynamicClass) == DirectColor)
        size = cast(int)mixin(NUMRED!(`pVisual`));
    pmap.freeRed = size;
    memset(cast(char*) pmap.red, 0, cast(int) sizebytes);
    memset(cast(char*) pmap.numPixelsRed, 0, LimitClients * int.sizeof);
    for (Pixel** pptr = &pmap.clientPixelsRed[LimitClients];
         --pptr >= pmap.clientPixelsRed;)
        *pptr = cast(Pixel*) null;
    if (alloc == AllocAll) {
        if (class_ & DynamicClass)
            pmap.flags |= CM_AllAllocated;
        for (EntryPtr pent = &pmap.red[size - 1]; pent >= pmap.red; pent--)
            pent.refcnt = AllocPrivate;
        pmap.freeRed = 0;
        Pixel* ppix = cast(Pixel*) calloc(size, Pixel.sizeof);
        if (!ppix) {
            free(pmap);
            return BadAlloc;
        }
        pmap.clientPixelsRed[clientIndex] = ppix;
        for (int i = 0; i < size; i++)
            ppix[i] = i;
        pmap.numPixelsRed[clientIndex] = size;
    }

    if ((class_ | DynamicClass) == DirectColor) {
        pmap.freeGreen = cast(int)mixin(NUMGREEN!(`pVisual`));
        pmap.green = cast(EntryPtr) (cast(char*) pmap.numPixelsRed +
                                  (LimitClients * int.sizeof));
        pmap.clientPixelsGreen = cast(Pixel**) (cast(char*) pmap.green + sizebytes);
        pmap.numPixelsGreen = cast(int*) (cast(char*) pmap.clientPixelsGreen +
                                        (LimitClients * (Pixel*).sizeof));
        pmap.freeBlue = cast(int)mixin(NUMBLUE!(`pVisual`));
        pmap.blue = cast(EntryPtr) (cast(char*) pmap.numPixelsGreen +
                                 (LimitClients * int.sizeof));
        pmap.clientPixelsBlue = cast(Pixel**) (cast(char*) pmap.blue + sizebytes);
        pmap.numPixelsBlue = cast(int*) (cast(char*) pmap.clientPixelsBlue +
                                       (LimitClients * (Pixel*).sizeof));

        memset(cast(char*) pmap.green, 0, cast(int) sizebytes);
        memset(cast(char*) pmap.blue, 0, cast(int) sizebytes);

        memmove(cast(char*) pmap.clientPixelsGreen,
                cast(char*) pmap.clientPixelsRed, LimitClients * (Pixel*).sizeof);
        memmove(cast(char*) pmap.clientPixelsBlue,
                cast(char*) pmap.clientPixelsRed, LimitClients * (Pixel*).sizeof);
        memset(cast(char*) pmap.numPixelsGreen, 0, LimitClients * int.sizeof);
        memset(cast(char*) pmap.numPixelsBlue, 0, LimitClients * int.sizeof);

        /* If every cell is allocated, mark its refcnt */
        if (alloc == AllocAll) {
            size = pmap.freeGreen;
            for (EntryPtr pent = &pmap.green[size - 1]; pent >= pmap.green; pent--)
                pent.refcnt = AllocPrivate;
            pmap.freeGreen = 0;
            Pixel* ppix = cast(Pixel*) calloc(size, Pixel.sizeof);
            if (!ppix) {
                free(pmap.clientPixelsRed[clientIndex]);
                free(pmap);
                return BadAlloc;
            }
            pmap.clientPixelsGreen[clientIndex] = ppix;
            for (int i = 0; i < size; i++)
                ppix[i] = i;
            pmap.numPixelsGreen[clientIndex] = size;

            size = pmap.freeBlue;
            for (EntryPtr pent = &pmap.blue[size - 1]; pent >= pmap.blue; pent--)
                pent.refcnt = AllocPrivate;
            pmap.freeBlue = 0;
            ppix = cast(Pixel*) calloc(size, Pixel.sizeof);
            if (!ppix) {
                free(pmap.clientPixelsGreen[clientIndex]);
                free(pmap.clientPixelsRed[clientIndex]);
                free(pmap);
                return BadAlloc;
            }
            pmap.clientPixelsBlue[clientIndex] = ppix;
            for (int i = 0; i < size; i++)
                ppix[i] = i;
            pmap.numPixelsBlue[clientIndex] = size;
        }
    }
    pmap.flags |= CM_BeingCreated;

    if (!AddResource(cast(uint)mid, X11_RESTYPE_COLORMAP, cast(void*) pmap))
        return BadAlloc;

    /*
     * Security creation/labeling check
     */
    {
        int access = XaceHookResourceAccess(pClient, mid, X11_RESTYPE_COLORMAP,
                 pmap, X11_RESTYPE_NONE, null, DixCreateAccess);
        if (access != Success) {
            FreeResource(cast(uint)mid, X11_RESTYPE_NONE);
            return access;
        }
    }

    /* If the device wants a chance to initialize the colormap in any way,
     * this is it.  In specific, if this is a Static colormap, this is the
     * time to fill in the colormap's values */
    if (!(*pScreen.CreateColormap) (pmap)) {
        FreeResource(cast(uint)mid, X11_RESTYPE_NONE);
        return BadAlloc;
    }
    pmap.flags &= ~CM_BeingCreated;
    *ppcmap = pmap;
    return Success;
}

/**
 *
 * \param value  must conform to DeleteType
 */
int FreeColormap(void* value, XID mid)
{
    ColormapPtr pmap = cast(ColormapPtr) value;

    if (!dixResouceIsServerOwned(mid)) {
        (*pmap.pScreen.UninstallColormap) (pmap);
        WalkTree(pmap.pScreen, cast(VisitWindowProcPtr) &TellNoMap, cast(void*) &mid);
    }

    /* This is the device's chance to undo anything it needs to, especially
     * to free any storage it allocated */
    (*pmap.pScreen.DestroyColormap) (pmap);

    if (pmap.clientPixelsRed) {
        for (int i = 0; i < LimitClients; i++)
            free(pmap.clientPixelsRed[i]);
    }

    if ((pmap.class_ == PseudoColor) || (pmap.class_ == GrayScale)) {
        for (EntryPtr pent = &pmap.red[pmap.pVisual.ColormapEntries - 1];
             pent >= pmap.red; pent--) {
            if (pent.fShared) {
                if (--pent.co.shco.red.refcnt == 0)
                    free(pent.co.shco.red);
                if (--pent.co.shco.green.refcnt == 0)
                    free(pent.co.shco.green);
                if (--pent.co.shco.blue.refcnt == 0)
                    free(pent.co.shco.blue);
            }
        }
    }
    if ((pmap.class_ | DynamicClass) == DirectColor) {
        for (int i = 0; i < LimitClients; i++) {
            free(pmap.clientPixelsGreen[i]);
            free(pmap.clientPixelsBlue[i]);
        }
    }

    if (pmap.flags & CM_IsDefault) {
        dixFreePrivates(pmap.devPrivates, PRIVATE_COLORMAP);
        free(pmap);
    }
    else
        mixin(dixFreeObjectWithPrivatesM!("pmap", "PRIVATE_COLORMAP"));
    return Success;
}

/* Tell window that pmid has disappeared */
private int TellNoMap(WindowPtr pwin, Colormap* pmid)
{
    if (mixin(wColormap!("pwin")) == *pmid) {
        /* This should be call to DeliverEvent */
        xEvent xE;
        // pragma(msg, typeof(xE.u.colormap.window).stringof);
// pragma(msg, typeof(pwin.drawable.id).stringof);
            xE.u.colormap.window = cast(uint)pwin.drawable.id;
            xE.u.colormap.colormap = None;
            xE.u.colormap.new_ = true;
            xE.u.colormap.state = ColormapUninstalled;
            xE.u.u.type = ColormapNotify;
static if(XINERAMA){
        if (noPanoramiXExtension || !pwin.drawable.pScreen.myNum)
            DeliverEvents(pwin, &xE, 1, cast(WindowPtr) null);

}
else { /* XINERAMA */
            DeliverEvents(pwin, &xE, 1, cast(WindowPtr) null);
}
        if (pwin.optional) {
            pwin.optional.colormap = None;
            CheckWindowOptionalNeed(pwin);
        }
    }

    return WT_WALKCHILDREN;
}

/* Tell window that pmid got uninstalled */
int TellLostMap(WindowPtr pwin, void* value)
{
    Colormap* pmid = cast(Colormap*) value;

static if(XINERAMA){
    if (!noPanoramiXExtension && pwin.drawable.pScreen.myNum)
        return WT_STOPWALKING;
} /* XINERAMA */
    if (mixin(wColormap!("pwin")) == *pmid) {
        /* This should be call to DeliverEvent */
        // xEvent xE = {
        //     u:colormap:window: cast(uint)pWin.drawable.id,
        //     u:colormap:colormap: *pmid,
        //     u:colormap:new: FALSE,
        //     u:colormap:state: ColormapUninstalled
        // };
        xEvent xE;
            xE.u.colormap.window = cast(uint)pwin.drawable.id;
            xE.u.colormap.colormap = cast(uint)*pmid;
            xE.u.colormap.new_ = false;
            xE.u.colormap.state = ColormapUninstalled;
            // xE.u.u.type = ColormapNotify;
            xE.u.u.type = ColormapNotify;
        DeliverEvents(pwin, &xE, 1, cast(WindowPtr) null);
    }

    return WT_WALKCHILDREN;
}

/* Tell window that pmid got installed */
int TellGainedMap(WindowPtr pwin, void* value)
{
    Colormap* pmid = cast(Colormap*) value;

static if(XINERAMA){
    if (!noPanoramiXExtension && pwin.drawable.pScreen.myNum)
        return WT_STOPWALKING;
} /* XINERAMA */
    if (mixin(wColormap!("pwin")) == *pmid) {
        /* This should be call to DeliverEvent */
        xEvent xE;
            xE.u.colormap.window = cast(uint)pwin.drawable.id;
            xE.u.colormap.colormap = cast(uint)*pmid;
            xE.u.colormap.new_ = false;
            xE.u.colormap.state = ColormapInstalled;
            // xE.u.u.type = ColormapNotify;
            xE.u.u.type = ColormapNotify;
        xE.u.u.type = ColormapNotify;
        DeliverEvents(pwin, &xE, 1, cast(WindowPtr) null);
    }

    return WT_WALKCHILDREN;
}

int CopyColormapAndFree(Colormap mid, ColormapPtr pSrc, int client)
{
    ColormapPtr pmap = cast(ColormapPtr) null;

    ScreenPtr pScreen = pSrc.pScreen;
    VisualPtr pVisual = pSrc.pVisual;

    const(int) alloc = ((pSrc.flags & CM_AllAllocated) && dixClientIdForXID(pSrc.mid) == client) ?
        AllocAll : AllocNone;
    const(int) size = pVisual.ColormapEntries;

    /* If the create returns non-0, it failed */
    {
        const(int) result = dixCreateColormap(mid, pScreen, pVisual, &pmap, alloc, clients[client]);
        if (result != Success)
            return result;
    }
    if (alloc == AllocAll) {
        memmove(cast(char*) pmap.red, cast(char*) pSrc.red, size * Entry.sizeof);
        if ((pmap.class_ | DynamicClass) == DirectColor) {
            memmove(cast(char*) pmap.green, cast(char*) pSrc.green,
                    size * Entry.sizeof);
            memmove(cast(char*) pmap.blue, cast(char*) pSrc.blue,
                    size * Entry.sizeof);
        }
        pSrc.flags &= ~CM_AllAllocated;
        FreePixels(pSrc, client);
        doUpdateColors(pmap);
        return Success;
    }

    CopyFree(REDMAP, client, pSrc, pmap);
    if ((pmap.class_ | DynamicClass) == DirectColor) {
        CopyFree(GREENMAP, client, pSrc, pmap);
        CopyFree(BLUEMAP, client, pSrc, pmap);
    }
    if (pmap.class_ & DynamicClass)
        doUpdateColors(pmap);
    /* XXX should worry about removing any X11_RESTYPE_CMAPENTRY resource */
    return Success;
}

/* Helper routine for freeing large numbers of cells from a map */
private void CopyFree(int channel, int client, ColormapPtr pmapSrc, ColormapPtr pmapDst)
{
    int npix = void;
    EntryPtr pentSrcFirst = void, pentDstFirst = void;
    Pixel* ppix = void;

    switch (channel) {
    default:         /* so compiler can see that everything gets initialized */
    case REDMAP:
        ppix = (pmapSrc.clientPixelsRed)[client];
        npix = (pmapSrc.numPixelsRed)[client];
        pentSrcFirst = pmapSrc.red;
        pentDstFirst = pmapDst.red;
        break;
    case GREENMAP:
        ppix = (pmapSrc.clientPixelsGreen)[client];
        npix = (pmapSrc.numPixelsGreen)[client];
        pentSrcFirst = pmapSrc.green;
        pentDstFirst = pmapDst.green;
        break;
    case BLUEMAP:
        ppix = (pmapSrc.clientPixelsBlue)[client];
        npix = (pmapSrc.numPixelsBlue)[client];
        pentSrcFirst = pmapSrc.blue;
        pentDstFirst = pmapDst.blue;
        break;
    }

    int nalloc = 0;
    if (pmapSrc.class_ & DynamicClass) {
        for (int z = npix; --z >= 0; ppix++) {
            /* Copy entries */
            EntryPtr pentSrc = pentSrcFirst + *ppix;
            EntryPtr pentDst = pentDstFirst + *ppix;
            if (pentDst.refcnt > 0) {
                pentDst.refcnt++;
            }
            else {
                *pentDst = *pentSrc;
                nalloc++;
                if (pentSrc.refcnt > 0)
                    pentDst.refcnt = 1;
                else
                    pentSrc.fShared = FALSE;
            }
            FreeCell(pmapSrc, *ppix, channel);
        }
    }

    /* Note that FreeCell has already fixed pmapSrc->free{Color} */
    switch (channel) {
    case REDMAP:
        pmapDst.freeRed -= nalloc;
        (pmapDst.clientPixelsRed)[client] = (pmapSrc.clientPixelsRed)[client];
        (pmapSrc.clientPixelsRed)[client] = cast(Pixel*) null;
        (pmapDst.numPixelsRed)[client] = (pmapSrc.numPixelsRed)[client];
        (pmapSrc.numPixelsRed)[client] = 0;
        break;
    case GREENMAP:
        pmapDst.freeGreen -= nalloc;
        (pmapDst.clientPixelsGreen)[client] =
            (pmapSrc.clientPixelsGreen)[client];
        (pmapSrc.clientPixelsGreen)[client] = cast(Pixel*) null;
        (pmapDst.numPixelsGreen)[client] = (pmapSrc.numPixelsGreen)[client];
        (pmapSrc.numPixelsGreen)[client] = 0;
        break;
    case BLUEMAP:
        pmapDst.freeBlue -= nalloc;
        pmapDst.clientPixelsBlue[client] = pmapSrc.clientPixelsBlue[client];
        pmapSrc.clientPixelsBlue[client] = cast(Pixel*) null;
        pmapDst.numPixelsBlue[client] = pmapSrc.numPixelsBlue[client];
        pmapSrc.numPixelsBlue[client] = 0;
        break;
    default: break;}
}

/* Free the ith entry in a color map.  Must handle freeing of
 * colors allocated through AllocColorPlanes */
private void FreeCell(ColormapPtr pmap, Pixel i, int channel)
{
    EntryPtr pent = void;
    int* pCount = void;

    switch (channel) {
    default:         /* so compiler can see that everything gets initialized */
    case PSEUDOMAP:
    case REDMAP:
        pent = cast(EntryPtr) &pmap.red[i];
        pCount = &pmap.freeRed;
        break;
    case GREENMAP:
        pent = cast(EntryPtr) &pmap.green[i];
        pCount = &pmap.freeGreen;
        break;
    case BLUEMAP:
        pent = cast(EntryPtr) &pmap.blue[i];
        pCount = &pmap.freeBlue;
        break;
    }
    /* If it's not privately allocated and it's not time to free it, just
     * decrement the count */
    if (pent.refcnt > 1)
        pent.refcnt--;
    else {
        /* If the color type is shared, find the sharedcolor. If decremented
         * refcnt is 0, free the shared cell. */
        if (pent.fShared) {
            if (--pent.co.shco.red.refcnt == 0)
                free(pent.co.shco.red);
            if (--pent.co.shco.green.refcnt == 0)
                free(pent.co.shco.green);
            if (--pent.co.shco.blue.refcnt == 0)
                free(pent.co.shco.blue);
            pent.fShared = FALSE;
        }
        pent.refcnt = 0;
        *pCount += 1;
    }
}

private void doUpdateColors(ColormapPtr pmap)
{
    VisualPtr pVisual = pmap.pVisual;
    int size = pVisual.ColormapEntries;
    xColorItem* defs = cast(xColorItem*) calloc(size, xColorItem.sizeof);
    if (!defs)
        return;

    int n = 0;
    xColorItem* pdef = defs;
    if (pmap.class_ == DirectColor) {
        for (int i = 0; i < size; i++) {
            if (!pmap.red[i].refcnt &&
                !pmap.green[i].refcnt && !pmap.blue[i].refcnt)
                continue;
            pdef.pixel = (cast(Pixel) i << pVisual.offsetRed) |
                (cast(Pixel) i << pVisual.offsetGreen) |
                (cast(Pixel) i << pVisual.offsetBlue);
            pdef.red = pmap.red[i].co.local.red;
            pdef.green = pmap.green[i].co.local.green;
            pdef.blue = pmap.blue[i].co.local.blue;
            pdef.flags =cast(ubyte)( DoRed | DoGreen | DoBlue);
            pdef++;
            n++;
        }
    }
    else {
        int i = 0;
        for (EntryPtr pent = pmap.red; i < size; i++, pent++) {
            if (!pent.refcnt)
                continue;
            pdef.pixel = i;
            if (pent.fShared) {
                pdef.red = pent.co.shco.red.color;
                pdef.green = pent.co.shco.green.color;
                pdef.blue = pent.co.shco.blue.color;
            }
            else {
                pdef.red = pent.co.local.red;
                pdef.green = pent.co.local.green;
                pdef.blue = pent.co.local.blue;
            }
            pdef.flags =cast(ubyte)( DoRed | DoGreen | DoBlue);
            pdef++;
            n++;
        }
    }
    if (n)
        (*pmap.pScreen.StoreColors) (pmap, n, defs);
    free(defs);
}

/* Tries to find a color in pmap that exactly matches the one requested in prgb
 * if it can't it allocates one.
 * Starts looking at pentFirst + *pPixel, so if you want a specific pixel,
 * load *pPixel with that value, otherwise set it to 0
 */
private int FindColor(ColormapPtr pmap, EntryPtr pentFirst, int size, xrgb* prgb, Pixel* pPixel, int channel, int client, ColorCompareProcPtr comp)
{
    Pixel pixel = *pPixel;
    if (pixel >= size)
        pixel = 0;

    Pixel Free = 0;
    /* see if there is a match, and also look for a free entry */
    bool foundFree = FALSE;
    int count = void;
    EntryPtr pent = void;
    xColorItem def = void;
    for (pent = pentFirst + pixel, count = size; --count >= 0;) {
        if (pent.refcnt > 0) {
            if ((*comp) (pent, prgb)) {
                if (client >= 0)
                    pent.refcnt++;
                *pPixel = pixel;
                switch (channel) {
                case REDMAP:
                    *pPixel <<= pmap.pVisual.offsetRed;
                goto case PSEUDOMAP;
                case PSEUDOMAP:
                    break;
                case GREENMAP:
                    *pPixel <<= pmap.pVisual.offsetGreen;
                    break;
                case BLUEMAP:
                    *pPixel <<= pmap.pVisual.offsetBlue;
                    break;
                default: break;}
                goto gotit;
            }
        }
        else if (!foundFree && pent.refcnt == 0) {
            Free = pixel;
            foundFree = TRUE;
            /* If we're initializing the colormap, then we are looking for
             * the first free cell we can find, not to minimize the number
             * of entries we use.  So don't look any further. */
            if (pmap.flags & CM_BeingCreated)
                break;
        }
        pixel++;
        if (pixel >= size) {
            pent = pentFirst;
            pixel = 0;
        }
        else
            pent++;
    }

    /* If we got here, we didn't find a match.  If we also didn't find
     * a free entry, we're out of luck.  Otherwise, we'll usurp a free
     * entry and fill it in */
    if (!foundFree)
        return BadAlloc;
    pent = pentFirst + Free;
    pent.fShared = FALSE;
    pent.refcnt = (client >= 0) ? 1 : AllocTemporary;

    switch (channel) {
    case PSEUDOMAP:
        pent.co.local.red = prgb.red;
        pent.co.local.green = prgb.green;
        pent.co.local.blue = prgb.blue;
        def.red = prgb.red;
        def.green = prgb.green;
        def.blue = prgb.blue;
        def.flags = cast(ubyte)(DoRed | DoGreen | DoBlue);
        if (client >= 0)
            pmap.freeRed--;
        def.pixel = Free;
        break;

    case REDMAP:
        pent.co.local.red = prgb.red;
        def.red = prgb.red;
        def.green = pmap.green[0].co.local.green;
        def.blue = pmap.blue[0].co.local.blue;
        def.flags = cast(ubyte)DoRed;
        if (client >= 0)
            pmap.freeRed--;
        def.pixel = Free << pmap.pVisual.offsetRed;
        break;

    case GREENMAP:
        pent.co.local.green = prgb.green;
        def.red = pmap.red[0].co.local.red;
        def.green = prgb.green;
        def.blue = pmap.blue[0].co.local.blue;
        def.flags = cast(ubyte)DoGreen;
        if (client >= 0)
            pmap.freeGreen--;
        def.pixel = Free << pmap.pVisual.offsetGreen;
        break;

    case BLUEMAP:
        pent.co.local.blue = prgb.blue;
        def.red = pmap.red[0].co.local.red;
        def.green = pmap.green[0].co.local.green;
        def.blue = prgb.blue;
        def.flags = cast(ubyte)DoBlue;
        if (client >= 0)
            pmap.freeBlue--;
        def.pixel = Free << pmap.pVisual.offsetBlue;
        break;
    default: break;}
    (*pmap.pScreen.StoreColors) (pmap, 1, &def);
    pixel = Free;
    *pPixel = def.pixel;

 gotit:
    if (pmap.flags & CM_BeingCreated || client == -1)
        return Success;

    /* Now remember the pixel, for freeing later */
    int* nump = void;
    Pixel** pixp = null;
    switch (channel) {
    case PSEUDOMAP:
    case REDMAP:
        nump = pmap.numPixelsRed;
        pixp = pmap.clientPixelsRed;
        break;

    case GREENMAP:
        nump = pmap.numPixelsGreen;
        pixp = pmap.clientPixelsGreen;
        break;

    case BLUEMAP:
        nump = pmap.numPixelsBlue;
        pixp = pmap.clientPixelsBlue;
        break;
    default: break;}

    int npix = nump[client];
    Pixel* ppix = cast(Pixel*) reallocarray(pixp[client], npix + 1, Pixel.sizeof);
    if (!ppix) {
        pent.refcnt--;
        if (!pent.fShared)
            switch (channel) {
            case PSEUDOMAP:
            case REDMAP:
                pmap.freeRed++;
                break;
            case GREENMAP:
                pmap.freeGreen++;
                break;
            case BLUEMAP:
                pmap.freeBlue++;
                break;
            default: break;}
        return BadAlloc;
    }
    ppix[npix] = pixel;
    pixp[client] = ppix;
    nump[client]++;

    return Success;
}

/* Get a read-only color from a ColorMap (probably slow for large maps)
 * Returns by changing the value in pred, pgreen, pblue and pPix
 */
int AllocColor(ColormapPtr pmap, ushort* pred, ushort* pgreen, ushort* pblue, Pixel* pPix, int client)
{
    VisualPtr pVisual = pmap.pVisual;
    (*pmap.pScreen.ResolveColor) (pred, pgreen, pblue, pVisual);
    xrgb rgb;
        rgb.red = *pred,
        rgb.green = *pgreen,
        rgb.blue = *pblue;
    // };

    int class_ = pmap.class_;
    int entries = pVisual.ColormapEntries;

    /* If the colormap is being created, then we want to be able to change
     * the colormap, even if it's a static type. Otherwise, we'd never be
     * able to initialize static colormaps
     */
    if (pmap.flags & CM_BeingCreated)
        class_ |= DynamicClass;

    /* If this is one of the static storage classes, and we're not initializing
     * it, the best we can do is to find the closest color entry to the
     * requested one and return that.
     */
    int npix = void;
    Pixel pixR = void, pixG = void, pixB = void;
    Pixel* ppix = void;
    switch (class_) {
    case StaticColor:
    case StaticGray:
        /* Look up all three components in the same pmap */
        *pPix = pixR = FindBestPixel(pmap.red, entries, &rgb, PSEUDOMAP);
        *pred = pmap.red[pixR].co.local.red;
        *pgreen = pmap.red[pixR].co.local.green;
        *pblue = pmap.red[pixR].co.local.blue;
        npix = pmap.numPixelsRed[client];
        ppix = cast(uint*)reallocarray(pmap.clientPixelsRed[client],
                            npix + 1, Pixel.sizeof);
        if (!ppix)
            return BadAlloc;
        ppix[npix] = pixR;
        pmap.clientPixelsRed[client] = ppix;
        pmap.numPixelsRed[client]++;
        break;

    case TrueColor:
        /* Look up each component in its own map, then OR them together */
        pixR = FindBestPixel(pmap.red,cast(int) mixin(NUMRED!(`pVisual`)), &rgb, REDMAP);
        pixG = FindBestPixel(pmap.green, cast(int)mixin(NUMGREEN!(`pVisual`)), &rgb, GREENMAP);
        pixB = FindBestPixel(pmap.blue, cast(int)mixin(NUMBLUE!(`pVisual`)), &rgb, BLUEMAP);
        *pPix = (pixR << pVisual.offsetRed) |
            (pixG << pVisual.offsetGreen) |
            (pixB << pVisual.offsetBlue) | mixin(ALPHAMASK!(`pVisual`));

        *pred = pmap.red[pixR].co.local.red;
        *pgreen = pmap.green[pixG].co.local.green;
        *pblue = pmap.blue[pixB].co.local.blue;
        npix = pmap.numPixelsRed[client];
        ppix = cast(uint*)reallocarray(pmap.clientPixelsRed[client],
                            npix + 1, Pixel.sizeof);
        if (!ppix)
            return BadAlloc;
        ppix[npix] = pixR;
        pmap.clientPixelsRed[client] = ppix;
        npix = pmap.numPixelsGreen[client];
        ppix = cast(uint*)reallocarray(pmap.clientPixelsGreen[client],
                            npix + 1, Pixel.sizeof);
        if (!ppix)
            return BadAlloc;
        ppix[npix] = pixG;
        pmap.clientPixelsGreen[client] = ppix;
        npix = pmap.numPixelsBlue[client];
        ppix = cast(uint*)reallocarray(pmap.clientPixelsBlue[client],
                            npix + 1, Pixel.sizeof);
        if (!ppix)
            return BadAlloc;
        ppix[npix] = pixB;
        pmap.clientPixelsBlue[client] = ppix;
        pmap.numPixelsRed[client]++;
        pmap.numPixelsGreen[client]++;
        pmap.numPixelsBlue[client]++;
        break;

    case GrayScale:
    case PseudoColor:
        if (pmap.mid != pmap.pScreen.defColormap &&
            pmap.pVisual.vid == pmap.pScreen.rootVisual) {
            ColormapPtr prootmap = void;

            dixLookupResourceByType(cast(void**) &prootmap,
                                    cast(uint)pmap.pScreen.defColormap, X11_RESTYPE_COLORMAP,
                                    clients[client], DixReadAccess);

            if (pmap.class_ == prootmap.class_)
                FindColorInRootCmap(prootmap, prootmap.red, entries, &rgb,
                                    pPix, PSEUDOMAP, &AllComp);
        }
        if (FindColor(pmap, pmap.red, entries, &rgb, pPix, PSEUDOMAP,
                      client, &AllComp) != Success)
            return BadAlloc;
        break;

    case DirectColor:
        if (pmap.mid != pmap.pScreen.defColormap &&
            pmap.pVisual.vid == pmap.pScreen.rootVisual) {
            ColormapPtr prootmap = void;

            dixLookupResourceByType(cast(void**) &prootmap,
                                    cast(uint)pmap.pScreen.defColormap, X11_RESTYPE_COLORMAP,
                                    clients[client], DixReadAccess);

            if (pmap.class_ == prootmap.class_) {
                pixR = (*pPix & pVisual.redMask) >> pVisual.offsetRed;
                FindColorInRootCmap(prootmap, prootmap.red, entries, &rgb,
                                    &pixR, REDMAP, &RedComp);
                pixG = (*pPix & pVisual.greenMask) >> pVisual.offsetGreen;
                FindColorInRootCmap(prootmap, prootmap.green, entries, &rgb,
                                    &pixG, GREENMAP, &GreenComp);
                pixB = (*pPix & pVisual.blueMask) >> pVisual.offsetBlue;
                FindColorInRootCmap(prootmap, prootmap.blue, entries, &rgb,
                                    &pixB, BLUEMAP, &BlueComp);
                *pPix = pixR | pixG | pixB;
            }
        }

        pixR = (*pPix & pVisual.redMask) >> pVisual.offsetRed;
        if (FindColor(pmap, pmap.red, cast(int)mixin(NUMRED!(`pVisual`)), &rgb, &pixR, REDMAP,
                      client, &RedComp) != Success)
            return BadAlloc;
        pixG = (*pPix & pVisual.greenMask) >> pVisual.offsetGreen;
        if (FindColor(pmap, pmap.green, cast(int)mixin(NUMGREEN!(`pVisual`)), &rgb, &pixG,
                      GREENMAP, client, &GreenComp) != Success) {
            cast(void) FreeCo(pmap, client, REDMAP, 1, &pixR, cast(Pixel) 0);
            return BadAlloc;
        }
        pixB = (*pPix & pVisual.blueMask) >> pVisual.offsetBlue;
        if (FindColor(pmap, pmap.blue, cast(int)mixin(NUMBLUE!(`pVisual`)), &rgb, &pixB, BLUEMAP,
                      client, &BlueComp) != Success) {
            cast(void) FreeCo(pmap, client, GREENMAP, 1, &pixG, cast(Pixel) 0);
            cast(void) FreeCo(pmap, client, REDMAP, 1, &pixR, cast(Pixel) 0);
            return BadAlloc;
        }
        *pPix = pixR | pixG | pixB | mixin(ALPHAMASK!(`pVisual`));

        break;
    default: break;}

    /* if this is the client's first pixel in this colormap, tell the
     * resource manager that the client has pixels in this colormap which
     * should be freed when the client dies */
    if ((pmap.numPixelsRed[client] == 1) &&
        (dixClientIdForXID(pmap.mid) != client) && !(pmap.flags & CM_BeingCreated)) {

        colorResource* pcr = cast(colorResource*) cast(colorResource*) calloc(1, colorResource.sizeof);
        if (!pcr) {
            cast(void) FreeColors(pmap, client, 1, pPix, cast(Pixel) 0);
            return BadAlloc;
        }
        pcr.mid = pmap.mid;
        pcr.client = client;
        if (!AddResource(cast(uint)FakeClientID(client), X11_RESTYPE_CMAPENTRY, cast(void*) pcr))
            return BadAlloc;
    }
    return Success;
}

/*
 * FakeAllocColor -- fake an AllocColor request by
 * returning a free pixel if available, otherwise returning
 * the closest matching pixel.  This is used by the mi
 * software sprite code to recolor cursors.  A nice side-effect
 * is that this routine will never return failure.
 */

void FakeAllocColor(ColormapPtr pmap, xColorItem* item)
{
    VisualPtr pVisual = pmap.pVisual;

    xrgb rgb = {
        red: item.red,
        green: item.green,
        blue: item.blue
    };
    (*pmap.pScreen.ResolveColor) (&rgb.red, &rgb.green, &rgb.blue, pVisual);

    int class_ = pmap.class_;
    int entries = pVisual.ColormapEntries;

    switch (class_) {
    case GrayScale:
    case PseudoColor:
    {
        Pixel temp = 0;
        item.pixel = 0;
        if (FindColor(pmap, pmap.red, entries, &rgb, &temp, PSEUDOMAP,
                      -1, &AllComp) == Success) {
            item.pixel = temp;
            break;
        }
        /* fall through ... */
    } goto case StaticColor;
    case StaticColor:
    goto case StaticColor;
    case StaticGray:
        item.pixel = FindBestPixel(pmap.red, entries, &rgb, PSEUDOMAP);
        break;

    case DirectColor:
    {
        /* Look up each component in its own map, then OR them together */
        Pixel pixR = (item.pixel & pVisual.redMask) >> pVisual.offsetRed;
        Pixel pixG = (item.pixel & pVisual.greenMask) >> pVisual.offsetGreen;
        Pixel pixB = (item.pixel & pVisual.blueMask) >> pVisual.offsetBlue;
        if (FindColor(pmap, pmap.red, cast(int)mixin(NUMRED!(`pVisual`)), &rgb, &pixR, REDMAP,
                      -1, &RedComp) != Success)
            pixR = FindBestPixel(pmap.red, cast(int)mixin(NUMRED!(`pVisual`)), &rgb, REDMAP)
                << pVisual.offsetRed;
        if (FindColor(pmap, pmap.green, cast(int)mixin(NUMGREEN!(`pVisual`)), &rgb, &pixG,
                      GREENMAP, -1, &GreenComp) != Success)
            pixG = FindBestPixel(pmap.green, cast(int)mixin(NUMGREEN!(`pVisual`)), &rgb,
                                 GREENMAP) << pVisual.offsetGreen;
        if (FindColor(pmap, pmap.blue, cast(int)mixin(NUMBLUE!(`pVisual`)), &rgb, &pixB, BLUEMAP,
                      -1, &BlueComp) != Success)
            pixB = FindBestPixel(pmap.blue, cast(int)mixin(NUMBLUE!(`pVisual`)), &rgb, BLUEMAP)
                << pVisual.offsetBlue;
        item.pixel = pixR | pixG | pixB;
        break;
    }

    case TrueColor:
    {
        /* Look up each component in its own map, then OR them together */
        Pixel pixR = FindBestPixel(pmap.red, cast(int)mixin(NUMRED!(`pVisual`)), &rgb, REDMAP);
        Pixel pixG = FindBestPixel(pmap.green, cast(int)mixin(NUMGREEN!(`pVisual`)), &rgb, GREENMAP);
        Pixel pixB = FindBestPixel(pmap.blue, cast(int)mixin(NUMBLUE!(`pVisual`)), &rgb, BLUEMAP);
        item.pixel = (pixR << pVisual.offsetRed) |
            (pixG << pVisual.offsetGreen) | (pixB << pVisual.offsetBlue);
        break;
    }
    default: break;}
}

/* free a pixel value obtained from FakeAllocColor */
void FakeFreeColor(ColormapPtr pmap, Pixel pixel)
{
    switch (pmap.class_) {
    case GrayScale:
    case PseudoColor:
        if (pmap.red[pixel].refcnt == AllocTemporary)
            pmap.red[pixel].refcnt = 0;
        break;
    case DirectColor:
    {
        VisualPtr pVisual = pmap.pVisual;
        Pixel pixR = (pixel & pVisual.redMask) >> pVisual.offsetRed;
        Pixel pixG = (pixel & pVisual.greenMask) >> pVisual.offsetGreen;
        Pixel pixB = (pixel & pVisual.blueMask) >> pVisual.offsetBlue;
        if (pmap.red[pixR].refcnt == AllocTemporary)
            pmap.red[pixR].refcnt = 0;
        if (pmap.green[pixG].refcnt == AllocTemporary)
            pmap.green[pixG].refcnt = 0;
        if (pmap.blue[pixB].refcnt == AllocTemporary)
            pmap.blue[pixB].refcnt = 0;
        break;
    }
    default: break;}
}

alias BigNumUpper = ushort;
alias BigNumLower = c_ulong;

enum BIGNUMLOWERBITS =	24;
enum BIGNUMUPPERBITS =	16;
enum BIGNUMLOWER = (1 << BIGNUMLOWERBITS);
enum BIGNUMUPPER = (1 << BIGNUMUPPERBITS);
enum string UPPERPART(string i) = `((` ~ i ~ `) >> BIGNUMLOWERBITS)`;
enum string LOWERPART(string i) = `((` ~ i ~ `) & (BIGNUMLOWER - 1))`;

struct _bignum {
    BigNumUpper upper;
    BigNumLower lower;
}alias BigNumRec = _bignum;
alias BigNumPtr = _bignum*;

enum string BigNumGreater(string x,string y) = `(((` ~ x ~ `).upper > (` ~ y ~ `).upper) ||
			    ((` ~ x ~ `).upper == (` ~ y ~ `).upper && (` ~ x ~ `).lower > (` ~ y ~ `).lower))`;

enum string UnsignedToBigNum(string u,string r) = `(((` ~ r ~ `).upper = cast(ushort)` ~ UPPERPART!(u) ~ `), 
				 ((` ~ r ~ `).lower = ` ~ LOWERPART!(u) ~ `));`;

enum string MaxBigNum(string r) = `(((` ~ r ~ `).upper = BIGNUMUPPER-1), 
				 ((` ~ r ~ `).lower = BIGNUMLOWER-1));`;

private void BigNumAdd(BigNumPtr x, BigNumPtr y, BigNumPtr r)
{
    BigNumLower carry = 0;
    BigNumLower lower = x.lower + y.lower;
    if (lower >= BIGNUMLOWER) {
        lower -= BIGNUMLOWER;
        carry = 1;
    }
    r.lower = lower;
    r.upper = cast(ushort)(x.upper + y.upper + carry);
}

private Pixel FindBestPixel(EntryPtr pentFirst, int size, xrgb* prgb, int channel)
{
    EntryPtr pent = void;
    Pixel pixel = void;
    Pixel final_ = 0;

    BigNumRec minval = void;
    mixin(MaxBigNum!(`&minval`));
    /* look for the minimal difference */
    for (pent = pentFirst, pixel = 0; pixel < size; pent++, pixel++) {
        c_long dr = 0;
        c_long dg = 0;
        c_long db = 0;
        switch (channel) {
        case PSEUDOMAP:
            dg = cast(c_long) pent.co.local.green - prgb.green;
            db = cast(c_long) pent.co.local.blue - prgb.blue;
            /* fallthrough */
        goto case;
        case REDMAP:
            dr = cast(c_long) pent.co.local.red - prgb.red;
            break;
        case GREENMAP:
            dg = cast(c_long) pent.co.local.green - prgb.green;
            break;
        case BLUEMAP:
            db = cast(c_long) pent.co.local.blue - prgb.blue;
            break;
        default: break;}
        c_ulong sq = dr * dr;
        BigNumRec sum = void;
        mixin(UnsignedToBigNum!(`sq`, `&sum`));
        sq = dg * dg;
        BigNumRec temp = void;
        mixin(UnsignedToBigNum!(`sq`, `&temp`));
        BigNumAdd(&sum, &temp, &sum);
        sq = db * db;
        mixin(UnsignedToBigNum!(`sq`, `&temp`));
        BigNumAdd(&sum, &temp, &sum);
        if (mixin(BigNumGreater!(`&minval`, `&sum`))) {
            final_ = pixel;
            minval = sum;
        }
    }
    return final_;
}

private void FindColorInRootCmap(ColormapPtr pmap, EntryPtr pentFirst, int size, xrgb* prgb, Pixel* pPixel, int channel, ColorCompareProcPtr comp)
{
    EntryPtr pent = void;
    Pixel pixel = void;
    int count = void;

    if ((pixel = *pPixel) >= size)
        pixel = 0;
    for (pent = pentFirst + pixel, count = size; --count >= 0; pent++, pixel++) {
        if (pent.refcnt > 0 && (*comp) (pent, prgb)) {
            switch (channel) {
            case REDMAP:
                pixel <<= pmap.pVisual.offsetRed;
                break;
            case GREENMAP:
                pixel <<= pmap.pVisual.offsetGreen;
                break;
            case BLUEMAP:
                pixel <<= pmap.pVisual.offsetBlue;
                break;
            default:           /* PSEUDOMAP */
                break;
            }
            *pPixel = pixel;
        }
    }
}

/* Comparison functions -- passed to FindColor to determine if an
 * entry is already the color we're looking for or not */
private int AllComp(EntryPtr pent, xrgb* prgb)
{
    if ((pent.co.local.red == prgb.red) &&
        (pent.co.local.green == prgb.green) &&
        (pent.co.local.blue == prgb.blue))
        return 1;
    return 0;
}

private int RedComp(EntryPtr pent, xrgb* prgb)
{
    if (pent.co.local.red == prgb.red)
        return 1;
    return 0;
}

private int GreenComp(EntryPtr pent, xrgb* prgb)
{
    if (pent.co.local.green == prgb.green)
        return 1;
    return 0;
}

private int BlueComp(EntryPtr pent, xrgb* prgb)
{
    if (pent.co.local.blue == prgb.blue)
        return 1;
    return 0;
}

/* Read the color value of a cell */

int QueryColors(ColormapPtr pmap, int count, Pixel* ppixIn, xrgb* prgbList, ClientPtr client)
{
    int errVal = Success;

    VisualPtr pVisual = pmap.pVisual;
    if ((pmap.class_ | DynamicClass) == DirectColor) {
        int numred = cast(int)mixin(NUMRED!(`pVisual`));
        int numgreen = cast(int)mixin(NUMGREEN!(`pVisual`));
        int numblue = cast(int)mixin(NUMBLUE!(`pVisual`));
        Pixel rgbbad = cast(int)~mixin(RGBMASK!(`pVisual`));
        Pixel* ppix = void;
        xrgb* prgb = void;
        for (ppix = ppixIn, prgb = prgbList; --count >= 0; ppix++, prgb++) {
            Pixel pixel = *ppix;
            if (pixel & rgbbad) {
                client.errorValue = cast(uint)pixel;
                errVal = BadValue;
                continue;
            }
            Pixel i = (pixel & pVisual.redMask) >> pVisual.offsetRed;
            if (i >= numred) {
                client.errorValue = cast(uint)pixel;
                errVal = BadValue;
                continue;
            }
            prgb.red = pmap.red[i].co.local.red;
            i = (pixel & pVisual.greenMask) >> pVisual.offsetGreen;
            if (i >= numgreen) {
                client.errorValue = cast(uint)pixel;
                errVal = BadValue;
                continue;
            }
            prgb.green = pmap.green[i].co.local.green;
            i = (pixel & pVisual.blueMask) >> pVisual.offsetBlue;
            if (i >= numblue) {
                client.errorValue = cast(uint)pixel;
                errVal = BadValue;
                continue;
            }
            prgb.blue = pmap.blue[i].co.local.blue;
        }
    }
    else {
        Pixel* ppix = void;
        xrgb* prgb = void;
        for (ppix = ppixIn, prgb = prgbList; --count >= 0; ppix++, prgb++) {
            Pixel pixel = *ppix;
            if (pixel >= pVisual.ColormapEntries) {
                client.errorValue = cast(uint)pixel;
                errVal = BadValue;
            }
            else {
                EntryPtr pent = cast(EntryPtr) &pmap.red[pixel];
                if (pent.fShared) {
                    prgb.red = pent.co.shco.red.color;
                    prgb.green = pent.co.shco.green.color;
                    prgb.blue = pent.co.shco.blue.color;
                }
                else {
                    prgb.red = pent.co.local.red;
                    prgb.green = pent.co.local.green;
                    prgb.blue = pent.co.local.blue;
                }
            }
        }
    }
    return errVal;
}

private void FreePixels(ColormapPtr pmap, int client)
{
    int class_ = pmap.class_;
    Pixel* ppixStart = pmap.clientPixelsRed[client];
    if (class_ & DynamicClass) {
        int n = pmap.numPixelsRed[client];
        for (Pixel* ppix = ppixStart; --n >= 0;) {
            FreeCell(pmap, *ppix, REDMAP);
            ppix++;
        }
    }

    free(ppixStart);
    pmap.clientPixelsRed[client] = cast(Pixel*) null;
    pmap.numPixelsRed[client] = 0;
    if ((class_ | DynamicClass) == DirectColor) {
        ppixStart = pmap.clientPixelsGreen[client];
        if (class_ & DynamicClass) {
            int n = pmap.numPixelsGreen[client];
            for (Pixel* ppix = ppixStart; --n >= 0;)
                FreeCell(pmap, *ppix++, GREENMAP);
        }
        free(ppixStart);
        pmap.clientPixelsGreen[client] = cast(Pixel*) null;
        pmap.numPixelsGreen[client] = 0;

        ppixStart = pmap.clientPixelsBlue[client];
        if (class_ & DynamicClass) {
            int n = pmap.numPixelsBlue[client];
            for (Pixel* ppix = ppixStart; --n >= 0;)
                FreeCell(pmap, *ppix++, BLUEMAP);
        }
        free(ppixStart);
        pmap.clientPixelsBlue[client] = cast(Pixel*) null;
        pmap.numPixelsBlue[client] = 0;
    }
}

/**
 * Frees all of a client's colors and cells.
 *
 *  \param value  must conform to DeleteType
 *  \unused fakeid
 */
int FreeClientPixels(void* value, XID fakeid)
{
    cast(void) fakeid;
    void* pmap = void;
    colorResource* pcr = cast(colorResource*)value;

    int rc = dixLookupResourceByType(&pmap, pcr.mid, X11_RESTYPE_COLORMAP, serverClient,
                                 DixRemoveAccess);
    if (rc == Success)
        FreePixels(cast(ColormapPtr) pmap, pcr.client);
    free(pcr);
    return Success;
}

int AllocColorCells(ClientPtr pClient, ColormapPtr pmap, int colors, int planes, Bool contig, Pixel* ppix, Pixel* masks)
{
    const(int) client = pClient.index;

    int class_ = pmap.class_;
    if (!(class_ & DynamicClass))
        return BadAlloc;        /* Shouldn't try on this type */

    int oldcount = pmap.numPixelsRed[client];
    if (pmap.class_ == DirectColor)
        oldcount += pmap.numPixelsGreen[client] + pmap.numPixelsBlue[client];

    colorResource* pcr = cast(colorResource*) null;
    if (!oldcount && (dixClientIdForXID(pmap.mid) != client)) {
        pcr = cast(colorResource*) cast(colorResource*) calloc(1, colorResource.sizeof);
        if (!pcr)
            return BadAlloc;
    }

    int ok = void;
    if (pmap.class_ == DirectColor) {
        Pixel rmask = void, gmask = void, bmask = void;
        ok = AllocDirect(client, pmap, colors, planes, planes, planes,
                         contig, ppix, &rmask, &gmask, &bmask);
        if (ok == Success) {
            for (int r = 1, g = 1, b = 1, n = planes; --n >= 0; r += r, g += g, b += b) {
                while (!(rmask & r))
                    r += r;
                while (!(gmask & g))
                    g += g;
                while (!(bmask & b))
                    b += b;
                *masks++ = r | g | b;
            }
        }
    }
    else {
        Pixel rmask = void; Pixel* ppixFirst = void;
        ok = AllocPseudo(client, pmap, colors, planes, contig, ppix, &rmask,
                         &ppixFirst);
        if (ok == Success) {
            for (int r = 1, n = planes; --n >= 0; r += r) {
                while (!(rmask & r))
                    r += r;
                *masks++ = r;
            }
        }
    }

    /* if this is the client's first pixels in this colormap, tell the
     * resource manager that the client has pixels in this colormap which
     * should be freed when the client dies */
    if ((ok == Success) && pcr) {
        pcr.mid = pmap.mid;
        pcr.client = client;
        if (!AddResource(cast(uint)FakeClientID(client), X11_RESTYPE_CMAPENTRY, cast(void*) pcr))
            ok = BadAlloc;
    }
    else
        free(pcr);

    return ok;
}

int AllocColorPlanes(int client, ColormapPtr pmap, int colors, int r, int g, int b, Bool contig, Pixel* pixels, Pixel* prmask, Pixel* pgmask, Pixel* pbmask)
{
    colorResource* pcr = cast(colorResource*) null;

    int class_ = pmap.class_;
    if (!(class_ & DynamicClass))
        return BadAlloc;        /* Shouldn't try on this type */
    int oldcount = pmap.numPixelsRed[client];
    if (class_ == DirectColor)
        oldcount += pmap.numPixelsGreen[client] + pmap.numPixelsBlue[client];
    if (!oldcount && (dixClientIdForXID(pmap.mid) != client)) {
        pcr = cast(colorResource*) cast(colorResource*) calloc(1, colorResource.sizeof);
        if (!pcr)
            return BadAlloc;
    }

    int ok = void;
    if (class_ == DirectColor) {
        ok = AllocDirect(client, pmap, colors, r, g, b, contig, pixels,
                         prmask, pgmask, pbmask);
    }
    else {
        /* Allocate the proper pixels */
        /* XXX This is sort of bad, because of contig is set, we force all
         * r + g + b bits to be contiguous.  Should only force contiguity
         * per mask
         */
        Pixel mask = void; Pixel* ppixFirst = void;
        ok = AllocPseudo(client, pmap, colors, r + g + b, contig, pixels,
                         &mask, &ppixFirst);

        if (ok == Success) {
            /* now split that mask into three */
            *prmask = *pgmask = *pbmask = 0;
            Pixel shift = 1;
            for (int i = r; --i >= 0; shift += shift) {
                while (!(mask & shift))
                    shift += shift;
                *prmask |= shift;
            }
            for (int i = g; --i >= 0; shift += shift) {
                while (!(mask & shift))
                    shift += shift;
                *pgmask |= shift;
            }
            for (int i = b; --i >= 0; shift += shift) {
                while (!(mask & shift))
                    shift += shift;
                *pbmask |= shift;
            }

            /* set up the shared color cells */
            if (!AllocShared(pmap, pixels, colors, r, g, b,
                             *prmask, *pgmask, *pbmask, ppixFirst)) {
                cast(void) FreeColors(pmap, client, colors, pixels, mask);
                ok = BadAlloc;
            }
        }
    }

    /* if this is the client's first pixels in this colormap, tell the
     * resource manager that the client has pixels in this colormap which
     * should be freed when the client dies */
    if ((ok == Success) && pcr) {
        pcr.mid = pmap.mid;
        pcr.client = client;
        if (!AddResource(cast(uint)FakeClientID(client), X11_RESTYPE_CMAPENTRY, cast(void*) pcr))
            ok = BadAlloc;
    }
    else
        free(pcr);

    return ok;
}

private int AllocDirect(int client, ColormapPtr pmap, int c, int r, int g, int b, Bool contig, Pixel* pixels, Pixel* prmask, Pixel* pgmask, Pixel* pbmask)
{

    int npixR = c << r;
    int npixG = c << g;
    int npixB = c << b;
    if ((r >= 32) || (g >= 32) || (b >= 32) ||
        (npixR > pmap.freeRed) || (npixR < c) ||
        (npixG > pmap.freeGreen) || (npixG < c) ||
        (npixB > pmap.freeBlue) || (npixB < c))
        return BadAlloc;

    /* start out with empty pixels */
    for (Pixel* p = pixels; p < pixels + c; p++)
        *p = 0;

    Pixel* ppixRed = cast(Pixel*) calloc(npixR, Pixel.sizeof);
    Pixel* ppixGreen = cast(Pixel*) calloc(npixG, Pixel.sizeof);
    Pixel* ppixBlue = cast(Pixel*) calloc(npixB, Pixel.sizeof);
    if (!ppixRed || !ppixGreen || !ppixBlue) {
        free(ppixBlue);
        free(ppixGreen);
        free(ppixRed);
        return BadAlloc;
    }

    Bool okR = AllocCP(pmap, pmap.red, c, r, contig, ppixRed, prmask);
    Bool okG = AllocCP(pmap, pmap.green, c, g, contig, ppixGreen, pgmask);
    Bool okB = AllocCP(pmap, pmap.blue, c, b, contig, ppixBlue, pbmask);

    Pixel* rpix = null, gpix = null, bpix = null;

    if (okR && okG && okB) {
        rpix = cast(uint*)reallocarray(pmap.clientPixelsRed[client],
                            pmap.numPixelsRed[client] + (c << r),
                            Pixel.sizeof);
        if (rpix)
            pmap.clientPixelsRed[client] = rpix;
        gpix = cast(uint*)reallocarray(pmap.clientPixelsGreen[client],
                            pmap.numPixelsGreen[client] + (c << g),
                            Pixel.sizeof);
        if (gpix)
            pmap.clientPixelsGreen[client] = gpix;
        bpix = cast(uint*)reallocarray(pmap.clientPixelsBlue[client],
                            pmap.numPixelsBlue[client] + (c << b),
                            Pixel.sizeof);
        if (bpix)
            pmap.clientPixelsBlue[client] = bpix;
    }

    if (!okR || !okG || !okB || !rpix || !gpix || !bpix) {
        if (okR) {
            Pixel* ppix = ppixRed;
            for (int npix = npixR; --npix >= 0; ppix++)
                pmap.red[*ppix].refcnt = 0;
        }
        if (okG) {
            Pixel* ppix = ppixGreen;
            for (int npix = npixG; --npix >= 0; ppix++)
                pmap.green[*ppix].refcnt = 0;
        }
        if (okB) {
            Pixel* ppix = ppixBlue;
            for (int npix = npixB; --npix >= 0; ppix++)
                pmap.blue[*ppix].refcnt = 0;
        }
        free(ppixBlue);
        free(ppixGreen);
        free(ppixRed);
        return BadAlloc;
    }

    *prmask <<= pmap.pVisual.offsetRed;
    *pgmask <<= pmap.pVisual.offsetGreen;
    *pbmask <<= pmap.pVisual.offsetBlue;

    Pixel* ppix = rpix + pmap.numPixelsRed[client];
    for (Pixel* pDst = pixels, p = ppixRed; p < ppixRed + npixR; p++) {
        *ppix++ = *p;
        if (p < ppixRed + c)
            *pDst++ |= *p << pmap.pVisual.offsetRed;
    }
    pmap.numPixelsRed[client] += npixR;
    pmap.freeRed -= npixR;

    ppix = gpix + pmap.numPixelsGreen[client];
    for (Pixel* pDst = pixels, p = ppixGreen; p < ppixGreen + npixG; p++) {
        *ppix++ = *p;
        if (p < ppixGreen + c)
            *pDst++ |= *p << pmap.pVisual.offsetGreen;
    }
    pmap.numPixelsGreen[client] += npixG;
    pmap.freeGreen -= npixG;

    ppix = bpix + pmap.numPixelsBlue[client];
    for (Pixel* pDst = pixels, p = ppixBlue; p < ppixBlue + npixB; p++) {
        *ppix++ = *p;
        if (p < ppixBlue + c)
            *pDst++ |= *p << pmap.pVisual.offsetBlue;
    }
    pmap.numPixelsBlue[client] += npixB;
    pmap.freeBlue -= npixB;

    for (Pixel* pDst = pixels; pDst < pixels + c; pDst++)
        *pDst |= mixin(ALPHAMASK!(`pmap.pVisual`));

    free(ppixBlue);
    free(ppixGreen);
    free(ppixRed);

    return Success;
}

private int AllocPseudo(int client, ColormapPtr pmap, int c, int r, Bool contig, Pixel* pixels, Pixel* pmask, Pixel** pppixFirst)
{
    int npix = c << r;
    if ((r >= 32) || (npix > pmap.freeRed) || (npix < c))
        return BadAlloc;

    Pixel* ppixTemp = void;
    if (((ppixTemp = cast(Pixel*) calloc(npix, Pixel.sizeof)) is null))
        return BadAlloc;

    Bool ok = AllocCP(pmap, pmap.red, c, r, contig, ppixTemp, pmask);
    if (ok) {

        /* all the allocated pixels are added to the client pixel list,
         * but only the unique ones are returned to the client */
        Pixel* ppix = cast(uint*)reallocarray(pmap.clientPixelsRed[client],
                            pmap.numPixelsRed[client] + npix, Pixel.sizeof);
        if (!ppix) {
            for (Pixel* p = ppixTemp; p < ppixTemp + npix; p++)
                pmap.red[*p].refcnt = 0;
            free(ppixTemp);
            return BadAlloc;
        }
        pmap.clientPixelsRed[client] = ppix;
        ppix += pmap.numPixelsRed[client];
        *pppixFirst = ppix;
        Pixel* pDst = pixels;
        for (Pixel* p = ppixTemp; p < ppixTemp + npix; p++) {
            *ppix++ = *p;
            if (p < ppixTemp + c)
                *pDst++ = *p;
        }
        pmap.numPixelsRed[client] += npix;
        pmap.freeRed -= npix;
    }
    free(ppixTemp);
    return ok ? Success : BadAlloc;
}

/* Allocates count << planes pixels from colormap pmap for client. If
 * contig, then the plane mask is made of consecutive bits.  Returns
 * all count << pixels in the array pixels. The first count of those
 * pixels are the unique pixels.  *pMask has the mask to Or with the
 * unique pixels to get the rest of them.
 *
 * Returns True iff all pixels could be allocated
 * All cells allocated will have refcnt set to AllocPrivate and shared to FALSE
 * (see AllocShared for why we care)
 */
private Bool AllocCP(ColormapPtr pmap, EntryPtr pentFirst, int count, int planes, Bool contig, Pixel* pixels, Pixel* pMask)
{
    int dplanes = pmap.pVisual.nplanes;

    /* Easy case.  Allocate pixels only */
    if (planes == 0) {
        /* allocate writable entries */
        Pixel* ppix = pixels;
        EntryPtr ent = pentFirst;
        Pixel pixel = 0;
        while (--count >= 0) {
            /* Just find count unallocated cells */
            while (ent.refcnt) {
                ent++;
                pixel++;
            }
            ent.refcnt = AllocPrivate;
            *ppix++ = pixel;
            ent.fShared = FALSE;
        }
        *pMask = 0;
        return TRUE;
    }
    else if (planes > dplanes) {
        return FALSE;
    }

    /* General case count pixels * 2 ^ planes cells to be allocated */

    /* make room for new pixels */
    EntryPtr ent = pentFirst;

    /* first try for contiguous planes, since it's fastest */
    Pixel base = void, mask = void;
    for (mask = ((cast(Pixel) 1) << planes) - 1, base = 1, dplanes -= (planes - 1);
         --dplanes >= 0; mask += mask, base += base) {
        Pixel* ppix = pixels;
        int found = 0;
        Pixel pixel = 0;
        Pixel entries = pmap.pVisual.ColormapEntries - mask;
        while (pixel < entries) {
            Pixel save = pixel;
            Pixel maxp = pixel + mask + base;
            /* check if all are free */
            while (pixel != maxp && ent[pixel].refcnt == 0)
                pixel += base;
            if (pixel == maxp) {
                /* this one works */
                *ppix++ = save;
                found++;
                if (found == count) {
                    /* found enough, allocate them all */
                    while (--count >= 0) {
                        pixel = pixels[count];
                        maxp = pixel + mask;
                        while (1) {
                            ent[pixel].refcnt = AllocPrivate;
                            ent[pixel].fShared = FALSE;
                            if (pixel == maxp)
                                break;
                            pixel += base;
                            *ppix++ = pixel;
                        }
                    }
                    *pMask = mask;
                    return TRUE;
                }
            }
            pixel = save + 1;
            if (pixel & mask)
                pixel += mask;
        }
    }

    dplanes = pmap.pVisual.nplanes;
    if (contig || planes == 1 || dplanes < 3)
        return FALSE;

    /* this will be very slow for large maps, need a better algorithm */

    /*
       we can generate the smallest and largest numbers that fits in dplanes
       bits and contain exactly planes bits set as follows. First, we need to
       check that it is possible to generate such a mask at all.
       (Non-contiguous masks need one more bit than contiguous masks). Then
       the smallest such mask consists of the rightmost planes-1 bits set, then
       a zero, then a one in position planes + 1. The formula is
       (3 << (planes-1)) -1
       The largest such masks consists of the leftmost planes-1 bits set, then
       a zero, then a one bit in position dplanes-planes-1. If dplanes is
       smaller than 32 (the number of bits in a word) then the formula is:
       (1<<dplanes) - (1<<(dplanes-planes+1) + (1<<dplanes-planes-1)
       If dplanes = 32, then we can't calculate (1<<dplanes) and we have
       to use:
       ( (1<<(planes-1)) - 1) << (dplanes-planes+1) + (1<<(dplanes-planes-1))

       << Thank you, Loretta>>>

     */

    Pixel finalmask = ((((cast(Pixel) 1) << (planes - 1)) - 1) << (dplanes - planes + 1)) +
        ((cast(Pixel) 1) << (dplanes - planes - 1));
    for (mask = ((cast(Pixel) 3) << (planes - 1)) - 1; mask <= finalmask; mask++) {
        /* next 3 magic statements count number of ones (HAKMEM #169) */
        Pixel pixel = (mask >> 1) & octal!"033333333333";
        pixel = cast(uint)(mask - pixel - ((pixel >> 1) & octal!"033333333333"));
        if ((((pixel + (pixel >> 3)) & octal!"030707070707") % octal!"077") != planes)
            continue;
        Pixel* ppix = pixels;
        int found = 0;
        Pixel entries = pmap.pVisual.ColormapEntries - mask;
        base = mixin(lowbit!mask);
        for (pixel = 0; pixel < entries; pixel++) {
            if (pixel & mask)
                continue;
            Pixel maxp = 0;
            /* check if all are free */
            while (ent[pixel + maxp].refcnt == 0) {
                mixin(GetNextBitsOrBreak!(`maxp`, `mask`, `base`));
            }
            if ((maxp < mask) || (ent[pixel + mask].refcnt != 0))
                continue;
            /* this one works */
            *ppix++ = pixel;
            found++;
            if (found < count)
                continue;
            /* found enough, allocate them all */
            while (--count >= 0) {
                pixel = (pixels)[count];
                maxp = 0;
                while (1) {
                    ent[pixel + maxp].refcnt = AllocPrivate;
                    ent[pixel + maxp].fShared = FALSE;
                    mixin(GetNextBitsOrBreak!(`maxp`, `mask`, `base`));
                    *ppix++ = pixel + maxp;
                }
            }

            *pMask = mask;
            return TRUE;
        }
    }
    return FALSE;
}

/**
 *
 *  \param ppixFirst  First of the client's new pixels
 */
private Bool AllocShared(ColormapPtr pmap, Pixel* ppix, int c, int r, int g, int b, Pixel rmask, Pixel gmask, Pixel bmask, Pixel* ppixFirst)
{
    int npixClientNew = c << (r + g + b);
    int npixShared = (c << r) + (c << g) + (c << b);

    SHAREDCOLOR** psharedList = cast(SHAREDCOLOR**) calloc(npixShared, (SHAREDCOLOR*).sizeof);
    if (!psharedList)
        return FALSE;

    SHAREDCOLOR** ppshared = psharedList;
    for (int z = npixShared; --z >= 0;) {
        if (((ppshared[z] = cast(SHAREDCOLOR*) calloc(1, SHAREDCOLOR.sizeof)) is null)) {
            for (z++; z < npixShared; z++)
                free(ppshared[z]);
            free(psharedList);
            return FALSE;
        }
    }

    int npix = void;
    Pixel* pptr = void;
    for (pptr = ppix, npix = c; --npix >= 0; pptr++) {
        Pixel basemask = ~(gmask | bmask);
        Pixel common = *pptr & basemask;
        SHAREDCOLOR* pshared = null;
        if (rmask) {
            Pixel bits = 0;
            Pixel base = mixin(lowbit!rmask);
            while (1) {
                pshared = *ppshared++;
                pshared.refcnt = cast(short)(1 << (g + b));
                int z = npixClientNew;
                for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                    if ((*cptr & basemask) == (common | bits)) {
                        pmap.red[*cptr].fShared = TRUE;
                        pmap.red[*cptr].co.shco.red = pshared;
                    }
                }
                mixin(GetNextBitsOrBreak!(`bits`, `rmask`, `base`));
            }
        }
        else {
            pshared = *ppshared++;
            pshared.refcnt = cast(short)(1 << (g + b));
            int z = npixClientNew;
            for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                if ((*cptr & basemask) == common) {
                    pmap.red[*cptr].fShared = TRUE;
                    pmap.red[*cptr].co.shco.red = pshared;
                }
            }
        }
        basemask = ~(rmask | bmask);
        common = *pptr & basemask;
        if (gmask) {
            Pixel bits = 0;
            Pixel base = mixin(lowbit!gmask);
            while (1) {
                pshared = *ppshared++;
                pshared.refcnt = cast(short)(1 << (r + b));
                int z = npixClientNew;
                for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                    if ((*cptr & basemask) == (common | bits)) {
                        pmap.red[*cptr].co.shco.green = pshared;
                    }
                }
                mixin(GetNextBitsOrBreak!(`bits`, `gmask`, `base`));
            }
        }
        else {
            pshared = *ppshared++;
            pshared.refcnt = cast(short)(1 << (g + b));
            int z = npixClientNew;
            for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                if ((*cptr & basemask) == common) {
                    pmap.red[*cptr].co.shco.green = pshared;
                }
            }
        }
        basemask = ~(rmask | gmask);
        common = *pptr & basemask;
        if (bmask) {
            Pixel bits = 0;
            Pixel base = mixin(lowbit!bmask);
            while (1) {
                pshared = *ppshared++;
                pshared.refcnt = cast(short)(1 << (r + g));
                int z = npixClientNew;
                for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                    if ((*cptr & basemask) == (common | bits)) {
                        pmap.red[*cptr].co.shco.blue = pshared;
                    }
                }
                mixin(GetNextBitsOrBreak!(`bits`, `bmask`, `base`));
            }
        }
        else {
            pshared = *ppshared++;
            pshared.refcnt = cast(short)(1 << (g + b));
            int z = npixClientNew;
            for (Pixel* cptr = ppixFirst; --z >= 0; cptr++) {
                if ((*cptr & basemask) == common) {
                    pmap.red[*cptr].co.shco.blue = pshared;
                }
            }
        }
    }
    free(psharedList);
    return TRUE;
}

/** FreeColors
 * Free colors and/or cells (probably slow for large numbers)
 */
int FreeColors(ColormapPtr pmap, int client, int count, Pixel* pixels, Pixel mask)
{
    int result = Success;
    int class_ = pmap.class_;

    if (pmap.flags & CM_AllAllocated)
        return BadAccess;

    Pixel rmask = 0;
    if ((class_ | DynamicClass) == DirectColor) {
        rmask = mask & mixin(RGBMASK!(`pmap.pVisual`));
        result = FreeCo(pmap, client, REDMAP, count, pixels,
                        mask & pmap.pVisual.redMask);
        /* If any of the three calls fails, we must report that, if more
         * than one fails, it's ok that we report the last one */
        int rval = FreeCo(pmap, client, GREENMAP, count, pixels,
                      mask & pmap.pVisual.greenMask);
        if (rval != Success)
            result = rval;
        rval = FreeCo(pmap, client, BLUEMAP, count, pixels,
                      mask & pmap.pVisual.blueMask);
        if (rval != Success)
            result = rval;
    }
    else {
        rmask = mask & (((cast(Pixel) 1) << pmap.pVisual.nplanes) - 1);
        result = FreeCo(pmap, client, PSEUDOMAP, count, pixels, rmask);
    }
    if ((mask != rmask) && count) {
        clients[client].errorValue = *pixels | mask;
        result = BadValue;
    }
    /* XXX should worry about removing any X11_RESTYPE_CMAPENTRY resource */
    return result;
}

/**
 * Helper for FreeColors -- frees all combinations of *newpixels and mask bits
 * which the client has allocated in channel colormap cells of pmap.
 * doesn't change newpixels if it doesn't need to
 *
 *  \param pmap   which colormap head
 *  \param color  which sub-map, eg, RED, BLUE, PSEUDO
 *  \param npixIn number of pixels passed in
 *  \param ppixIn number of base pixels
 *  \param mask   mask client gave us
 */
private int FreeCo(ColormapPtr pmap, int client, int color, int npixIn, Pixel* ppixIn, Pixel mask)
{
    Pixel* ppixClient = void;
    int npixClient = void;
    Pixel cmask = void, rgbbad = void;
    int errVal = Success;
    int offset = void, numents = void;

    if (npixIn == 0)
        return errVal;

    Pixel bits = 0;
    int zapped = 0;
    Pixel base = mixin(lowbit!mask);

    switch (color) {
    case REDMAP:
        cmask = cast(uint)pmap.pVisual.redMask;
        rgbbad = cast(uint)~mixin(RGBMASK!(`pmap.pVisual`));
        offset = pmap.pVisual.offsetRed;
        numents = cast(int)(cmask >> offset) + 1;
        ppixClient = pmap.clientPixelsRed[client];
        npixClient = pmap.numPixelsRed[client];
        break;
    case GREENMAP:
        cmask = cast(uint)pmap.pVisual.greenMask;
        rgbbad = cast(uint)~mixin(RGBMASK!(`pmap.pVisual`));
        offset = pmap.pVisual.offsetGreen;
        numents = cast(int)(cmask >> offset) + 1;
        ppixClient = pmap.clientPixelsGreen[client];
        npixClient = pmap.numPixelsGreen[client];
        break;
    case BLUEMAP:
        cmask = cast(uint)pmap.pVisual.blueMask;
        rgbbad = cast(uint)~mixin(RGBMASK!(`pmap.pVisual`));
        offset = pmap.pVisual.offsetBlue;
        numents = cast(int)(cmask >> offset) + 1;
        ppixClient = pmap.clientPixelsBlue[client];
        npixClient = pmap.numPixelsBlue[client];
        break;
    default:        /* so compiler can see that everything gets initialized */
    case PSEUDOMAP:
        cmask = ~(cast(Pixel) 0);
        rgbbad = 0;
        offset = 0;
        numents = cast(int)pmap.pVisual.ColormapEntries;
        ppixClient = pmap.clientPixelsRed[client];
        npixClient = pmap.numPixelsRed[client];
        break;
    }

    /* zap all pixels which match */
    while (1) {
        /* go through pixel list */
        Pixel* pptr = ppixIn;
        for (int n = npixIn; --n >= 0; pptr++) {
            Pixel pixTest = ((*pptr | bits) & cmask) >> offset;
            if ((pixTest >= numents) || (*pptr & rgbbad)) {
                clients[client].errorValue = *pptr | bits;
                errVal = BadValue;
                continue;
            }

            /* find match in client list */
            int npix = void;
            Pixel* cptr = void;
            for (cptr = ppixClient, npix = npixClient;
                 --npix >= 0 && *cptr != pixTest; cptr++){}

            if (npix >= 0) {
                if (pmap.class_ & DynamicClass) {
                    FreeCell(pmap, pixTest, color);
                }
                *cptr = ~(cast(Pixel) 0);
                zapped++;
            }
            else
                errVal = BadAccess;
        }
        /* generate next bits value */
        mixin(GetNextBitsOrBreak!(`bits`, `mask`, `base`));
    }

    /* delete freed pixels from client pixel list */
    if (zapped) {
        int npixNew = npixClient - zapped;
        if (npixNew) {
            /* Since the list can only get smaller, we can do a copy in
             * place and then realloc to a smaller size */
            Pixel* pptr = ppixClient;
            Pixel* cptr = ppixClient;

            /* If we have all the new pixels, we don't have to examine the
             * rest of the old ones */
            for (int npix = 0; npix < npixNew; cptr++) {
                if (*cptr != ~(cast(Pixel) 0)) {
                    *pptr++ = *cptr;
                    npix++;
                }
            }
            pptr = cast(Pixel*) reallocarray(ppixClient, npixNew, Pixel.sizeof);
            if (pptr)
                ppixClient = pptr;
            npixClient = npixNew;
        }
        else {
            npixClient = 0;
            free(ppixClient);
            ppixClient = cast(Pixel*) null;
        }
        switch (color) {
        case PSEUDOMAP:
        case REDMAP:
            pmap.clientPixelsRed[client] = ppixClient;
            pmap.numPixelsRed[client] = npixClient;
            break;
        case GREENMAP:
            pmap.clientPixelsGreen[client] = ppixClient;
            pmap.numPixelsGreen[client] = npixClient;
            break;
        case BLUEMAP:
            pmap.clientPixelsBlue[client] = ppixClient;
            pmap.numPixelsBlue[client] = npixClient;
            break;
        default: break;}
    }
    return errVal;
}

/* Redefine color values */
int StoreColors(ColormapPtr pmap, int count, xColorItem* defs, ClientPtr client)
{
    int errVal = Success;

    int class_ = pmap.class_;
    if (!(class_ & DynamicClass) && !(pmap.flags & CM_BeingCreated)) {
        return BadAccess;
    }

    VisualPtr pVisual = pmap.pVisual;

    int idef = 0;
    if ((class_ | DynamicClass) == DirectColor) {
        int numred = cast(int)mixin(NUMRED!(`pVisual`));
        int numgreen = cast(int)mixin(NUMGREEN!(`pVisual`));
        int numblue = cast(int)mixin(NUMBLUE!(`pVisual`));
        Pixel rgbbad = cast(int)~mixin(RGBMASK!(`pVisual`));
        int n = 0;
        for (xColorItem* pdef = defs; n < count; pdef++, n++) {
            bool ok = TRUE;

            (*pmap.pScreen.ResolveColor)
                (&pdef.red, &pdef.green, &pdef.blue, pmap.pVisual);

            if (pdef.pixel & rgbbad) {
                errVal = BadValue;
                client.errorValue = cast(uint)pdef.pixel;
                continue;
            }
            Pixel pix = (pdef.pixel & pVisual.redMask) >> pVisual.offsetRed;
            if (pix >= numred) {
                errVal = BadValue;
                ok = FALSE;
            }
            else if (pmap.red[pix].refcnt != AllocPrivate) {
                errVal = BadAccess;
                ok = FALSE;
            }
            else if (pdef.flags & DoRed) {
                pmap.red[pix].co.local.red = pdef.red;
            }
            else {
                pdef.red = pmap.red[pix].co.local.red;
            }

            pix = (pdef.pixel & pVisual.greenMask) >> pVisual.offsetGreen;
            if (pix >= numgreen) {
                errVal = BadValue;
                ok = FALSE;
            }
            else if (pmap.green[pix].refcnt != AllocPrivate) {
                errVal = BadAccess;
                ok = FALSE;
            }
            else if (pdef.flags & DoGreen) {
                pmap.green[pix].co.local.green = pdef.green;
            }
            else {
                pdef.green = pmap.green[pix].co.local.green;
            }

            pix = (pdef.pixel & pVisual.blueMask) >> pVisual.offsetBlue;
            if (pix >= numblue) {
                errVal = BadValue;
                ok = FALSE;
            }
            else if (pmap.blue[pix].refcnt != AllocPrivate) {
                errVal = BadAccess;
                ok = FALSE;
            }
            else if (pdef.flags & DoBlue) {
                pmap.blue[pix].co.local.blue = pdef.blue;
            }
            else {
                pdef.blue = pmap.blue[pix].co.local.blue;
            }
            /* If this is an o.k. entry, then it gets added to the list
             * to be sent to the hardware.  If not, skip it.  Once we've
             * skipped one, we have to copy all the others.
             */
            if (ok) {
                if (idef != n)
                    defs[idef] = defs[n];
                idef++;
            }
            else
                client.errorValue = cast(uint)pdef.pixel;
        }
    }
    else {
        int n = 0;
        for (xColorItem* pdef = defs; n < count; pdef++, n++) {
            bool ok = TRUE;

            if (pdef.pixel >= pVisual.ColormapEntries) {
                client.errorValue = cast(uint)pdef.pixel;
                errVal = BadValue;
                ok = FALSE;
            }
            else if (pmap.red[pdef.pixel].refcnt != AllocPrivate) {
                errVal = BadAccess;
                ok = FALSE;
            }

            /* If this is an o.k. entry, then it gets added to the list
             * to be sent to the hardware.  If not, skip it.  Once we've
             * skipped one, we have to copy all the others.
             */
            if (ok) {
                if (idef != n)
                    defs[idef] = defs[n];
                idef++;
            }
            else
                continue;

            (*pmap.pScreen.ResolveColor)
                (&pdef.red, &pdef.green, &pdef.blue, pmap.pVisual);

            EntryPtr pent = &pmap.red[pdef.pixel];

            if (pdef.flags & DoRed) {
                if (pent.fShared) {
                    pent.co.shco.red.color = pdef.red;
                    if (pent.co.shco.red.refcnt > 1)
                        ok = FALSE;
                }
                else
                    pent.co.local.red = pdef.red;
            }
            else {
                if (pent.fShared)
                    pdef.red = pent.co.shco.red.color;
                else
                    pdef.red = pent.co.local.red;
            }
            if (pdef.flags & DoGreen) {
                if (pent.fShared) {
                    pent.co.shco.green.color = pdef.green;
                    if (pent.co.shco.green.refcnt > 1)
                        ok = FALSE;
                }
                else
                    pent.co.local.green = pdef.green;
            }
            else {
                if (pent.fShared)
                    pdef.green = pent.co.shco.green.color;
                else
                    pdef.green = pent.co.local.green;
            }
            if (pdef.flags & DoBlue) {
                if (pent.fShared) {
                    pent.co.shco.blue.color = pdef.blue;
                    if (pent.co.shco.blue.refcnt > 1)
                        ok = FALSE;
                }
                else
                    pent.co.local.blue = pdef.blue;
            }
            else {
                if (pent.fShared)
                    pdef.blue = pent.co.shco.blue.color;
                else
                    pdef.blue = pent.co.local.blue;
            }

            if (!ok) {
                /* have to run through the colormap and change anybody who
                 * shares this value */
                SHAREDCOLOR* pred = pent.co.shco.red;
                SHAREDCOLOR* pgreen = pent.co.shco.green;
                SHAREDCOLOR* pblue = pent.co.shco.blue;
                int ChgRed = pdef.flags & DoRed;
                int ChgGreen = pdef.flags & DoGreen;
                int ChgBlue = pdef.flags & DoBlue;
                EntryPtr pentLast = pmap.red + pVisual.ColormapEntries;

                for (EntryPtr pentT = pmap.red; pentT < pentLast; pentT++) {
                    if (pentT.fShared && (pentT != pent)) {
                        xColorItem defChg = void;

                        /* There are, alas, devices in this world too dumb
                         * to read their own hardware colormaps.  Sick, but
                         * true.  So we're going to be really nice and load
                         * the xColorItem with the proper value for all the
                         * fields.  We will only set the flags for those
                         * fields that actually change.  Smart devices can
                         * arrange to change only those fields.  Dumb devices
                         * can rest assured that we have provided for them,
                         * and can change all three fields */

                        defChg.flags = 0;
                        if (ChgRed && pentT.co.shco.red == pred) {
                            defChg.flags |= cast(ubyte)DoRed;
                        }
                        if (ChgGreen && pentT.co.shco.green == pgreen) {
                            defChg.flags |= cast(ubyte)DoGreen;
                        }
                        if (ChgBlue && pentT.co.shco.blue == pblue) {
                            defChg.flags |= cast(ubyte)DoBlue;
                        }
                        if (defChg.flags != 0) {
                            defChg.pixel = cast(uint)(pentT - pmap.red);
                            defChg.red = pentT.co.shco.red.color;
                            defChg.green = pentT.co.shco.green.color;
                            defChg.blue = pentT.co.shco.blue.color;
                            (*pmap.pScreen.StoreColors) (pmap, 1, &defChg);
                        }
                    }
                }

            }
        }
    }
    /* Note that we use idef, the count of acceptable entries, and not
     * count, the count of proposed entries */
    if (idef != 0)
        (*pmap.pScreen.StoreColors) (pmap, idef, defs);
    return errVal;
}

int IsMapInstalled(Colormap map, WindowPtr pWin)
{
    Colormap* pmaps = void;
    int nummaps = void, found = void;

    pmaps = cast(Colormap*) calloc(pWin.drawable.pScreen.maxInstalledCmaps,
                   Colormap.sizeof);
    if (!pmaps)
        return FALSE;
    nummaps = (*pWin.drawable.pScreen.ListInstalledColormaps)
        (pWin.drawable.pScreen, pmaps);
    found = FALSE;
    for (int imap = 0; imap < nummaps; imap++) {
        if (pmaps[imap] == map) {
            found = TRUE;
            break;
        }
    }
    free(pmaps);
    return found;
}

struct colormap_lookup_data {
    ScreenPtr pScreen;
    VisualPtr visuals;
}

private void _colormap_find_resource(void* value, XID id, void* cdata)
{
    cast(void) id;
    colormap_lookup_data* cmap_data = cast(colormap_lookup_data*)cdata;
    VisualPtr visuals = cmap_data.visuals;
    ScreenPtr pScreen = cmap_data.pScreen;
    ColormapPtr cmap = cast(ColormapPtr)value;

    if (pScreen != cmap.pScreen)
        return;

    int j = cast(int)(cmap.pVisual - pScreen.visuals);
    cmap.pVisual = &visuals[j];
}

/* something has realloced the visuals, instead of breaking
   ABI fix it up here - glx and composite did this wrong */
Bool ResizeVisualArray(ScreenPtr pScreen, int new_visual_count, DepthPtr depth)
{
    int first_new_vid = depth.numVids;
    int first_new_visual = pScreen.numVisuals;

    XID* vids = cast(uint*)reallocarray(depth.vids, depth.numVids + new_visual_count,
                        XID.sizeof);
    if (!vids)
        return FALSE;

    /* its realloced now no going back if we fail the next one */
    depth.vids = vids;

    int numVisuals = pScreen.numVisuals + new_visual_count;
    VisualPtr visuals = cast(VisualRec*) reallocarray(pScreen.visuals, numVisuals, VisualRec.sizeof);
    if (!visuals) {
        return FALSE;
    }

    colormap_lookup_data cdata = {
        visuals: visuals,
        pScreen: pScreen,
    };
    FindClientResourcesByType(serverClient, X11_RESTYPE_COLORMAP,
                              &_colormap_find_resource, &cdata);

    pScreen.visuals = visuals;

    for (int i = 0; i < new_visual_count; i++) {
        XID vid = dixAllocServerXID();
        pScreen.visuals[first_new_visual + i].vid = vid;
        vids[first_new_vid + i] = vid;
    }

    depth.numVids += new_visual_count;
    pScreen.numVisuals += new_visual_count;

    return TRUE;
}
