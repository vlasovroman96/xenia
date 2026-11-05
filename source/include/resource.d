module include.resource;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1989, 1998  The Open Group

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

Copyright 1987, 1989 by Digital Equipment Corporation, Maynard, Massachusetts.

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

version (RESOURCE_H) {} else {
enum RESOURCE_H = 1;

public import include.xlibre_ptrtypes;

public import dix.callback;
public import common.misc;
public import dix.dixaccess;
import dix.dixstruct_priv;
public import x11.Xprotostr;
public import x11.Xmd;
public import x11.X;
public import x11.Xmd;
public import x11.X;
import x11.Xdefs;
// public import x11.Xdefs;
public import x11.Xprotostr;


/*****************************************************************
 * STUFF FOR RESOURCES
 *****************************************************************/

/* classes for Resource routines */

alias RESTYPE = uint;

enum RC_VANILLA =	(cast(RESTYPE)0);
enum RC_CACHED =	(cast(RESTYPE)1<<31);
enum RC_DRAWABLE =	(cast(RESTYPE)1<<30);
/*  Use class RC_NEVERRETAIN for resources that should not be retained
 *  regardless of the close down mode when the client dies.  (A client's
 *  event selections on objects that it doesn't own are good candidates.)
 *  Extensions can use this too!
 */
enum RC_NEVERRETAIN =	(cast(RESTYPE)1<<29);
enum RC_LASTPREDEF =	RC_NEVERRETAIN;
enum RC_ANY =		(~cast(RESTYPE)0);

/* types for Resource routines */

// prevent namespace clash with Windows
enum X11_RESTYPE_NONE =	(cast(RESTYPE)0);
enum X11_RESTYPE_WINDOW =	(cast(RESTYPE)1|RC_DRAWABLE);
enum X11_RESTYPE_PIXMAP =	(cast(RESTYPE)2|RC_DRAWABLE);
enum X11_RESTYPE_GC =		(cast(RESTYPE)3);
enum X11_RESTYPE_FONT =	(cast(RESTYPE)4);
enum X11_RESTYPE_CURSOR =	(cast(RESTYPE)5);
enum X11_RESTYPE_COLORMAP =	(cast(RESTYPE)6);
enum X11_RESTYPE_CMAPENTRY =	(cast(RESTYPE)7);
enum X11_RESTYPE_OTHERCLIENT =	(cast(RESTYPE)8|RC_NEVERRETAIN);
enum X11_RESTYPE_PASSIVEGRAB =	(cast(RESTYPE)9|RC_NEVERRETAIN);
enum X11_RESTYPE_LASTPREDEF =	(cast(RESTYPE)9);

enum RT_WINDOW =	X11_RESTYPE_WINDOW;
enum RT_PIXMAP =	X11_RESTYPE_PIXMAP;
enum RT_GC =		X11_RESTYPE_GC;
enum RT_FONT =		X11_RESTYPE_FONT;
enum RT_CURSOR =	X11_RESTYPE_CURSOR;
enum RT_COLORMAP =	X11_RESTYPE_COLORMAP;
enum RT_CMAPENTRY =	X11_RESTYPE_CMAPENTRY;
enum RT_OTHERCLIENT =	X11_RESTYPE_OTHERCLIENT;
enum RT_PASSIVEGRAB =	X11_RESTYPE_PASSIVEGRAB;
enum RT_LASTPREDEF =	X11_RESTYPE_LASTPREDEF;
enum RT_NONE =		X11_RESTYPE_NONE;


// uint ResourceClientBits();

enum BAD_RESOURCE = 0xe0000000;

alias DeleteType = int function(void* value, XID id);

alias FindResType = void function(void* value, XID id, void* cdata);

alias FindAllRes = void function(void* value, XID id, RESTYPE type, void* cdata);

alias FindComplexResType = Bool function(void* value, XID id, void* cdata);

/* Structure for estimating resource memory usage. Memory usage
 * consists of space allocated for the resource itself and of
 * references to other resources. Currently the most important use for
 * this structure is to estimate pixmap usage of different resources
 * more accurately. */
struct _ResourceSizeRec {
    /* Size of resource itself. Zero if not implemented. */
    c_ulong resourceSize;
    /* Size attributed to pixmap references from the resource. */
    c_ulong pixmapRefSize;
    /* Number of references to this resource; typically 1 */
    c_ulong refCnt;
}alias ResourceSizeRec = _ResourceSizeRec;
alias ResourceSizePtr = ResourceSizeRec*;

alias SizeType = void function(void* value, XID id, ResourceSizePtr size);

// void CreateNewResourceType(DeleteType deleteFunc, const(char)* name);

alias FindTypeSubResources = void function(void* value, FindAllRes func, void* cdata);

// void GetResourceTypeSizeFunc(RESTYPE);

void SetResourceTypeFindSubResFunc(RESTYPE, FindTypeSubResources);

// void SetResourceTypeSizeFunc(RESTYPE, SizeType);

// void SetResourceTypeErrorValue(RESTYPE, int);

// void CreateNewResourceClass();

// void InitClientResources(ClientPtr);

// void FakeClientID(int);

/* Quartz support on Mac OS X uses the CarbonCore
   framework whose AddResource function conflicts here. */
version (OSX) {
enum AddResource = Darwin_X_AddResource;
}
// int AddResource(cast(uint)XID id, RESTYPE type, void* value);

// void FreeResource(cast(uint)XID, RESTYPE);

// void FreeResourceByType(XID, RESTYPE, Bool);

// void ChangeResourceValue(XID id, RESTYPE rtype, void* value);

// void FindClientResourcesByType(ClientPtr client, RESTYPE type, FindResType func, void* cdata);

// void FindAllClientResources(ClientPtr client, FindAllRes func, void* cdata);

/** @brief Iterate through all subresources of a resource.

    @note The XID argument provided to the FindAllRes function
          may be 0 for subresources that don't have an XID */
// void FindSubResources(void* resource, RESTYPE type, FindAllRes func, void* cdata);

// void FreeClientNeverRetainResources(ClientPtr);

// void FreeClientResources(ClientPtr);

// void FreeAllResources();

// void LegalNewID(XID, ClientPtr);

// void* LookupClientResourceComplex(ClientPtr client, RESTYPE type, FindComplexResType func, void* cdata);

// void dixLookupResourceByType(void** result, XID id, RESTYPE rtype, ClientPtr client, Mask access_mode);

// void dixLookupResourceByClass(void** result, XID id, RESTYPE rclass, ClientPtr client, Mask access_mode);

// RESTYPE lastResourceType;
// RESTYPE TypeMask;

/*
 * @brief allocate a XID (resource ID) for the server itself
 *
 * This is mostly for resource types that don't have their own API yet
 * The XID is allocated within server's ID space and then can be used
 * for registering a resource with it (@see AddResource(cast(uint)))
 *
 * @obsoletes FakeClientID
 * @return XID the newly allocated XID
 */
// XID dixAllocServerXID();

} /* RESOURCE_H */
