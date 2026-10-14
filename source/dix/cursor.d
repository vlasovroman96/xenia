module dix.cursor;
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

//import x11.X;
//import x11.Xmd;

import dix.cursor_priv;
import dix.dix_priv;
import dix.screenint_priv;
import os.bug_priv;

import include.servermd;
import include.scrnintstr;
import include.dixstruct;
import dix.cursor;
import include.dixfontstr;
import include.opaque;
import include.inputstr;
import Xext.xace;
import dix.dixfonts;
import dix.events;

struct CursorBits {
    ubyte* source;      /* points to bits */
    ubyte* mask;        /* points to bits */
    Bool emptyMask;             /* all zeros mask */
    ushort width, height, xhot, yhot;   /* metrics */
    int refcnt;                 /* can be shared */
    PrivateRec* devPrivates;    /* set by pScr->RealizeCursor */
    CARD32* argb;               /* full-color alpha blended */
};
alias CursorBitsPtr = CursorBits*;

struct CursorRec {
    CursorBitsPtr bits;
    ushort foreRed, foreGreen, foreBlue;        /* device-independent color */
    ushort backRed, backGreen, backBlue;        /* device-independent color */
    int refcnt;
    PrivateRec* devPrivates;    /* set by pScr->RealizeCursor */
    XID id;
    CARD32 serialNumber;
    Atom name;
}

struct CursorMetricRec {
    ushort width, height, xhot, yhot;
}

struct HotSpot {
    int x, y;
    ScreenPtr pScreen;
}

enum NullCursor = cast(CursorPtr)null;

alias CursorPtr = CursorRec*;
// FUN FACT: If you typedef a pointer type, like the `CursorPtr` above
// then `const CursorPtr` or `CursorPtr const` actually means `struct CursoRec *const`, a constant pointer
// which is probably not what you want(a pointer to constant).
// Maybe better just keep the `*` around, or you have to typedef a separate constPtr type.
alias ConstCursorPtr = CursorRec*;
alias CursorMetricPtr = CursorMetricRec*;

struct _GlyphShare {
    FontPtr font;
    ushort sourceChar;
    ushort maskChar;
    CursorBitsPtr bits;
    _GlyphShare* next;
}alias GlyphShare = _GlyphShare;
alias GlyphSharePtr = _GlyphShare*;

private GlyphSharePtr sharedGlyphs = cast(GlyphSharePtr) null;

private CARD32 cursorSerial;

private void FreeCursorBits(CursorBitsPtr bits)
{
    if (--bits.refcnt > 0)
        return;
    free(bits.source);
    free(bits.mask);
    free(bits.argb);
    mixin(dixFiniPrivates!("bits", "PRIVATE_CURSOR_BITS"));
    if (bits.refcnt == 0) {
        GlyphSharePtr* prev = void; GlyphSharePtr this_ = void;

        for (prev = &sharedGlyphs;
             (this_ = *prev) !is null && (this_.bits != bits); prev = &this_.next){}
        if (this_) {
            *prev = this_.next;
            CloseFont(this_.font, cast(Font) 0);
            free(this_);
        }
        free(bits);
    }
}

/**
 * To be called indirectly by DeleteResource; must use exactly two args.
 *
 *  \param value must conform to DeleteType
 */
int FreeCursor(void* value, XID cid)
{
    if (!value)
        return Success;

    CursorPtr pCurs = cast(CursorPtr) value;
    DeviceIntPtr pDev = null;   /* unused anyway */

    UnrefCursor(pCurs);
    if (CursorRefCount(pCurs) != 0)
        return Success;

    mixin(BUG_WARN!("CursorRefCount(pCurs) < 0"));

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (walkScreen.UnrealizeCursor)
            walkScreen.UnrealizeCursor(pDev, walkScreen, pCurs);
    });

    FreeCursorBits(pCurs.bits);
    mixin(dixFiniPrivates!("pCurs", "PRIVATE_CURSOR"));
    free(pCurs);
    return Success;
}

CursorPtr RefCursor(CursorPtr cursor)
{
    if (cursor)
        cursor.refcnt++;
    return cursor;
}

CursorPtr UnrefCursor(CursorPtr cursor)
{
    if (cursor)
        cursor.refcnt--;
    return cursor;
}

int CursorRefCount(ConstCursorPtr cursor)
{
    return cursor ? cursor.refcnt : 0;
}


/*
 * We check for empty cursors so that we won't have to display them
 */
private void CheckForEmptyMask(CursorBitsPtr bits)
{
    ubyte* msk = bits.mask;
    int n = mixin(BitmapBytePad!("bits.width")) * bits.height;

    bits.emptyMask = FALSE;
    while (n--)
        if (*(msk++) != 0)
            return;
    if (bits.argb) {
        CARD32* argb = bits.argb;

        n = bits.width * bits.height;
        while (n--)
            if (*argb++ & 0xff000000)
                return;
    }
    bits.emptyMask = TRUE;
}

/**
 * realize the cursor for every screen. Do not change the refcnt, this will be
 * changed when ChangeToCursor actually changes the sprite.
 *
 * @return Success if all cursors realize on all screens, BadAlloc if realize
 * failed for a device on a given screen.
 */
private int RealizeCursorAllScreens(CursorPtr pCurs)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        for (DeviceIntPtr pDev = inputInfo.devices; pDev; pDev = pDev.next) {
            if (DevHasCursor(pDev)) {
                if (!(*walkScreen.RealizeCursor) (pDev, walkScreen, pCurs)) {
                    /* Realize failed for device pDev on screen walkScreen.
                     * We have to assume that for all devices before, realize
                     * worked. We need to rollback all devices so far on the
                     * current screen and then all devices on previous
                     * screens.
                     */
                    DeviceIntPtr pDevIt = inputInfo.devices;    /*dev iterator */

                    while (pDevIt && pDevIt != pDev) {
                        if (DevHasCursor(pDevIt) && walkScreen.UnrealizeCursor)
                            walkScreen.UnrealizeCursor(pDevIt, walkScreen, pCurs);
                        pDevIt = pDevIt.next;
                    }
                    while (--walkScreenIdx>= 0) {
                        walkScreen = dixGetScreenPtr(cast(uint)walkScreenIdx);
                        /* now unrealize all devices on previous screens */
                        pDevIt = inputInfo.devices;
                        while (pDevIt) {
                            if (DevHasCursor(pDevIt) && walkScreen.UnrealizeCursor)
                                walkScreen.UnrealizeCursor(pDevIt, walkScreen, pCurs);
                            pDevIt = pDevIt.next;
                        }
                        if (walkScreen.UnrealizeCursor)
                            walkScreen.UnrealizeCursor(pDev, walkScreen, pCurs);
                    }
                    return BadAlloc;
                }
            }
        }
    });

    return Success;
}

/**
 * does nothing about the resource table, just creates the data structure.
 * does not copy the src and mask bits
 *
 *  \param psrcbits  server-defined padding
 *  \param pmaskbits server-defined padding
 *  \param argb      no padding
 */
int AllocARGBCursor(ubyte* psrcbits, ubyte* pmaskbits, CARD32* argb, CursorMetricPtr cm, ushort foreRed, ushort foreGreen, ushort foreBlue, ushort backRed, ushort backGreen, ushort backBlue, CursorPtr* ppCurs, ClientPtr client, XID cid)
{
    *ppCurs = null;

    CursorPtr pCurs = cast(CursorPtr) calloc(CURSOR_REC_SIZE + CURSOR_BITS_SIZE, 1);
    if (!pCurs)
        return BadAlloc;

    CursorBitsPtr bits = cast(CursorBitsPtr) (cast(char*) pCurs + CURSOR_REC_SIZE);
    mixin(dixInitPrivates!("pCurs", "pCurs + 1", "PRIVATE_CURSOR"));
    mixin(dixInitPrivates!("bits", "bits + 1", "PRIVATE_CURSOR_BITS"));
        bits.source = psrcbits;
    bits.mask = pmaskbits;
    bits.argb = argb;
    bits.width = cm.width;
    bits.height = cm.height;
    bits.xhot = cm.xhot;
    bits.yhot = cm.yhot;
    pCurs.refcnt = 1;
    bits.refcnt = -1;
    CheckForEmptyMask(bits);
    pCurs.bits = bits;
    pCurs.serialNumber = ++cursorSerial;
    pCurs.name = None;

    pCurs.foreRed = foreRed;
    pCurs.foreGreen = foreGreen;
    pCurs.foreBlue = foreBlue;

    pCurs.backRed = backRed;
    pCurs.backGreen = backGreen;
    pCurs.backBlue = backBlue;

    pCurs.id = cid;

    /* security creation/labeling check */
    int rc = XaceHookResourceAccess(client, cid, X11_RESTYPE_CURSOR,
                  pCurs, X11_RESTYPE_NONE, null, DixCreateAccess);
    if (rc != Success)
        goto error;

    rc = RealizeCursorAllScreens(pCurs);
    if (rc != Success)
        goto error;

    *ppCurs = pCurs;

    if (argb) {
        size_t size = bits.width * bits.height;

        for (size_t i = 0; i < size; i++) {
            if ((argb[i] & 0xff000000) == 0 && (argb[i] & 0xffffff) != 0) {
                /* ARGB data doesn't seem pre-multiplied, fix it */
                for (size_t j = 0; j < size; j++) {
                    CARD32 a = void, ar = void, ag = void, ab = void;

                    a = argb[j] >> 24;
                    ar = a * ((argb[j] >> 16) & 0xff) / 0xff;
                    ag = a * ((argb[j] >> 8) & 0xff) / 0xff;
                    ab = a * (argb[j] & 0xff) / 0xff;

                    argb[j] = a << 24 | ar << 16 | ag << 8 | ab;
                }

                break;
            }
        }
    }

    return Success;

 error:
    FreeCursorBits(bits);
    mixin(dixFiniPrivates!("pCurs", "PRIVATE_CURSOR"));
    free(pCurs);

    return rc;
}

int AllocGlyphCursor(Font source, ushort sourceChar, Font mask, ushort maskChar, ushort foreRed, ushort foreGreen, ushort foreBlue, ushort backRed, ushort backGreen, ushort backBlue, CursorPtr* ppCurs, ClientPtr client, XID cid)
{
    FontPtr sourcefont = void;
    int rc = dixLookupResourceByType(cast(void**) &sourcefont, source, X11_RESTYPE_FONT,
                                 client, DixUseAccess);
    if ((rc != Success) || (!sourcefont)) {
        client.errorValue = cast(uint)source;
        return rc;
    }

    FontPtr maskfont = void;
    rc = dixLookupResourceByType(cast(void**) &maskfont, mask, X11_RESTYPE_FONT, client,
                                 DixUseAccess);
    if (rc != Success && mask != None) {
        client.errorValue = cast(uint)mask;
        return rc;
    }

    GlyphSharePtr pShare = void;
    if (sourcefont !is maskfont)
        pShare = cast(GlyphSharePtr) null;
    else {
        for (pShare = sharedGlyphs;
             pShare &&
             ((pShare.font !is sourcefont) ||
              (pShare.sourceChar != sourceChar) ||
              (pShare.maskChar != maskChar)); pShare = pShare.next){}
    }

    CursorPtr pCurs = void;
    CursorBitsPtr bits = void;
    if (pShare) {
        pCurs = cast(CursorPtr) calloc(CURSOR_REC_SIZE, 1);
        if (!pCurs)
            return BadAlloc;
        mixin(dixInitPrivates!("pCurs", "pCurs + 1", "PRIVATE_CURSOR"));
        bits = pShare.bits;
        bits.refcnt++;
    }
    else {
        CursorMetricRec cm = void;
        if (!CursorMetricsFromGlyph(sourcefont, sourceChar, &cm)) {
            client.errorValue = cast(uint)sourceChar;
            return BadValue;
        }

        ubyte* mskbits = void;
        if (!maskfont) {
            size_t n = mixin(BitmapBytePad!("cm.width")) * cast(c_long) cm.height;
            mskbits = cast(ubyte*) calloc(1, n);
            if (!mskbits)
                return BadAlloc;
            memset(mskbits, 0xFF, n);
        }
        else {
            if (!CursorMetricsFromGlyph(maskfont, maskChar, &cm)) {
                client.errorValue = cast(uint)maskChar;
                return BadValue;
            }
            if ((rc = ServerBitsFromGlyph(maskfont, maskChar, &cm, &mskbits)) != 0)
                return rc;
        }

        ubyte* srcbits = void;
        if ((rc = ServerBitsFromGlyph(sourcefont, sourceChar, &cm, &srcbits)) != 0) {
            free(mskbits);
            return rc;
        }
        if (sourcefont != maskfont) {
            pCurs = cast(CursorPtr) calloc(CURSOR_REC_SIZE + CURSOR_BITS_SIZE, 1);
            if (pCurs)
                bits = cast(CursorBitsPtr) (cast(char*) pCurs + CURSOR_REC_SIZE);
            else
                bits = cast(CursorBitsPtr) null;
        }
        else {
            pCurs = cast(CursorPtr) calloc(CURSOR_REC_SIZE, 1);
            if (pCurs)
                bits = cast(CursorBitsPtr) calloc(CURSOR_BITS_SIZE, 1);
            else
                bits = cast(CursorBitsPtr) null;
        }
        if (!bits) {
            free(pCurs);
            free(mskbits);
            free(srcbits);
            return BadAlloc;
        }
        mixin(dixInitPrivates!("pCurs", "pCurs + 1", "PRIVATE_CURSOR"));
        mixin(dixInitPrivates!("bits", "bits + 1", "PRIVATE_CURSOR_BITS"));
        bits.source = srcbits;
        bits.mask = mskbits;
        bits.argb = null;
        bits.width = cm.width;
        bits.height = cm.height;
        bits.xhot = cm.xhot;
        bits.yhot = cm.yhot;
        if (sourcefont != maskfont)
            bits.refcnt = -1;
        else {
            bits.refcnt = 1;
            pShare = cast(GlyphShare*) calloc(1, GlyphShare.sizeof);
            if (!pShare) {
                FreeCursorBits(bits);
                return BadAlloc;
            }
            pShare.font = sourcefont;
            sourcefont.refcnt++;
            pShare.sourceChar = sourceChar;
            pShare.maskChar = maskChar;
            pShare.bits = bits;
            pShare.next = sharedGlyphs;
            sharedGlyphs = pShare;
        }
    }

    CheckForEmptyMask(bits);
    pCurs.bits = bits;
    pCurs.refcnt = 1;
    pCurs.serialNumber = ++cursorSerial;
    pCurs.name = None;

    pCurs.foreRed = foreRed;
    pCurs.foreGreen = foreGreen;
    pCurs.foreBlue = foreBlue;

    pCurs.backRed = backRed;
    pCurs.backGreen = backGreen;
    pCurs.backBlue = backBlue;

    pCurs.id = cid;

    /* security creation/labeling check */
    rc = XaceHookResourceAccess(client, cid, X11_RESTYPE_CURSOR,
                  pCurs, X11_RESTYPE_NONE, null, DixCreateAccess);
    if (rc != Success)
        goto error;

    rc = RealizeCursorAllScreens(pCurs);
    if (rc != Success)
        goto error;

    *ppCurs = pCurs;
    return Success;

 error:
    FreeCursorBits(bits);
    mixin(dixFiniPrivates!("pCurs", "PRIVATE_CURSOR"));
    free(pCurs);

    return rc;
}

/** CreateRootCursor
 *
 * look up the name of a font
 * open the font
 * add the font to the resource table
 * make a cursor from the glyphs
 * add the cursor to the resource table
 *************************************************************/

CursorPtr CreateRootCursor()
{
    const(char)[7] defaultCursorFont = "cursor";

    XID fontID = dixAllocServerXID();
    int err = OpenFont(serverClient, fontID, FontLoadAll | FontOpenSync,
                   cast(uint) strlen(defaultCursorFont.ptr), defaultCursorFont.ptr);
    if (err != Success)
        return NullCursor;

    FontPtr cursorfont = void;
    err = dixLookupResourceByType(cast(void**) &cursorfont, fontID, X11_RESTYPE_FONT,
                                  serverClient, DixReadAccess);
    if (err != Success)
        return NullCursor;

    CursorPtr curs = void;
    if (AllocGlyphCursor(fontID, 0, fontID, 1, 0, 0, 0, cast(ushort)~0U, cast(ushort)~0U, cast(ushort)~0U,
                         &curs, serverClient, cast(XID) 0) != Success)
        return NullCursor;

    if (!AddResource(cast(uint)dixAllocServerXID(), X11_RESTYPE_CURSOR, cast(void*) curs))
        return NullCursor;

    return curs;
}
