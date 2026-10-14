module dix.dixfonts;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************************
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

************************************************************************/
/* The panoramix components contained the following notice */
/*
Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
DIGITAL EQUIPMENT CORPORATION BE LIABLE FOR ANY CLAIM, DAMAGES, INCLUDING,
BUT NOT LIMITED TO CONSEQUENTIAL OR INCIDENTAL DAMAGES, OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Digital Equipment Corporation
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization from Digital
Equipment Corporation.

******************************************************************/

import build.xlibre_server;
import Xext.panoramiXsrv;
import core.stdc.stddef;
//import x11.X;
//import x11.Xmd;
//import x11.Xproto;
// //import externs.X11.fonts.font;
// //import externs.X11.fonts.fontstruct;
import externs.X11.fonts.libxfont2;

import dix.dix_priv;
import dix.gc_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.screenint_priv;
import dix.server_priv;
import dix.swaprep;
import include.extinit;
import include.gcstruct;
import os.auth;
import os.log_priv;

import include.scrnintstr;
import include.resource;
import include.dixstruct;
import dix.cursor;
import include.misc;
import include.opaque;
import include.dixfontstr;
import include.dixfont;
import Xext.xace;
import os.utils;
import dix.dixutils;
import externs.attrs;
import os.io;
import dix.gc;
import os.log;
import externs.gnu;
import os.connection;
import os.WaitFor;
alias ClientPtr = include.dixstruct.ClientPtr;

// static if (XF86BIGFONT) {
import Xext.xf86bigfontsrv;
// }

enum XLFDMAXFONTNAMELEN =      256;
struct list_font_state {
    char[XLFDMAXFONTNAMELEN] pattern = 0;
    int patlen;
    int current_fpe;
    int max_names;
    Bool list_started;
    void* private_;
}

struct open_font_closure {
    ClientPtr client;
    short current_fpe;
    short num_fpes;
    FontPathElementPtr* fpe_list;
    Mask flags;

    /* XXX -- get these from request buffer instead? */
    const(char)* origFontName;
    int origFontNameLen;
    XID fontid;
    char* fontname;
    int fnamelen;
    FontPtr non_cachable_font;
}

struct list_fonts_with_info_closure {
    ClientPtr client;
    int num_fpes;
    FontPathElementPtr* fpe_list;
    xListFontsWithInfoReply* reply;
    int length;
    list_font_state current;
    list_font_state saved;
    int savedNumFonts;
    Bool haveSaved;
    char* savedName;
}

struct list_fonts_closure {
    ClientPtr client;
    int num_fpes;
    FontPathElementPtr* fpe_list;
    FontNamesPtr names;
    list_font_state current;
    list_font_state saved;
    Bool haveSaved;
    char* savedName;
    int savedNameLen;
}

struct poly_text_closure {
    ClientPtr client;
    DrawablePtr pDraw;
    GCPtr pGC;
    ubyte* pElt;
    ubyte* endReq;
    ubyte* data;
    int xorg;
    int yorg;
    CARD8 reqType;
    XID did;
    int err;
}

struct image_text_closure {
    ClientPtr client;
    DrawablePtr pDraw;
    GCPtr pGC;
    BYTE nChars;
    ubyte* data;
    int xorg;
    int yorg;
    CARD8 reqType;
    XID did;
}

// FontPtr defaultFont;

private FontPathElementPtr* font_path_elements = cast(FontPathElementPtr*) 0;
private int num_fpes = 0;
private xfont2_fpe_funcs_rec** fpe_functions;
private int num_fpe_types = 0;

private int num_slept_fpes = 0;
private int size_slept_fpes = 0;
private FontPathElementPtr* slept_fpes = cast(FontPathElementPtr*) 0;
private xfont2_pattern_cache_ptr patternCache;

private int FontToXError(int err)
{
    switch (err) {
    case Successful:
        return Success;
    case AllocError:
        return BadAlloc;
    case BadFontName:
        return BadName;
    case BadFontPath:
    case BadFontFormat:        /* is there something better? */
    case BadCharRange:
        return BadValue;
    default:
        return err;
    }
}

private int LoadGlyphs(ClientPtr client, FontPtr pfont, uint nchars, int item_size, ubyte* data) @nogc nothrow
{
    if (fpe_functions[pfont.fpe.type].load_glyphs)
        return assumeNoGC(fpe_functions[pfont.fpe.type].load_glyphs)
            (client, pfont, 0, nchars, item_size, data);
    else
        return Successful;
}

void GetGlyphs(FontPtr font, c_ulong count, ubyte* chars, FontEncoding fontEncoding, c_ulong* glyphcount, CharInfoPtr* glyphs)          /* RETURN */
{
    assumeNoGC(font.get_glyphs) (font, count, chars, fontEncoding, glyphcount, glyphs);
}

/*
 * adding RT_FONT / X11_RESTYPE_FONT prevents conflict with default cursor font
 */
Bool SetDefaultFont(const(char)* defaultfontname)
{
    int err = void;
    FontPtr pf = void;
    XID fid = void;

    fid = dixAllocServerXID();
    err = OpenFont(serverClient, fid, FontLoadAll | FontOpenSync,
                   cast(uint) strlen(defaultfontname), defaultfontname);
    if (err != Success)
        return FALSE;
    err = dixLookupResourceByType(cast(void**) &pf, fid, X11_RESTYPE_FONT, serverClient,
                                  DixReadAccess);
    if (err != Success)
        return FALSE;
    defaultFont = pf;
    return TRUE;
}

/*
 * note that the font wakeup queue is not refcounted.  this is because
 * an fpe needs to be added when it's inited, and removed when it's finally
 * freed, in order to handle any data that isn't requested, like FS events.
 *
 * since the only thing that should call these routines is the renderer's
 * init_fpe() and free_fpe(), there shouldn't be any problem in using
 * freed data.
 */
private void QueueFontWakeup(FontPathElementPtr fpe)
{
    FontPathElementPtr* new_ = void;

    for (int i = 0; i < num_slept_fpes; i++) {
        if (slept_fpes[i] == fpe) {
            return;
        }
    }
    if (num_slept_fpes == size_slept_fpes) {
        new_ = cast(FontPathElementPtr*)reallocarray(slept_fpes, size_slept_fpes + 4,
                           FontPathElementPtr.sizeof);
        if (!new_)
            return;
        slept_fpes = new_;
        size_slept_fpes += 4;
    }
    slept_fpes[num_slept_fpes] = fpe;
    num_slept_fpes++;
}

private void RemoveFontWakeup(FontPathElementPtr fpe)
{
    for (int i = 0; i < num_slept_fpes; i++) {
        if (slept_fpes[i] == fpe) {
            for (int j = i; j < num_slept_fpes; j++) {
                slept_fpes[j] = slept_fpes[j + 1];
            }
            num_slept_fpes--;
            return;
        }
    }
}

private void FontWakeup(void* data, int count)
{
    FontPathElementPtr fpe = void;

    if (count < 0)
        return;
    /* wake up any fpe's that may be waiting for information */
    for (int i = 0; i < num_slept_fpes; i++) {
        fpe = slept_fpes[i];
        assumeNoGC(fpe_functions[fpe.type].wakeup_fpe) (fpe);
    }
}

/* XXX -- these two funcs may want to be broken into macros */
private void UseFPE(FontPathElementPtr fpe)
{
    fpe.refcount++;
}

private void FreeFPE(FontPathElementPtr fpe)
{
    fpe.refcount--;
    if (fpe.refcount == 0) {
        assumeNoGC(fpe_functions[fpe.type].free_fpe) (fpe);
        free(cast(void*) fpe.name);
        free(fpe);
    }
}

private Bool doOpenFont(ClientPtr client, open_font_closure* c)
{
    FontPtr pfont = NullFont;
    FontPathElementPtr fpe = null;
    int err = Successful;
    char* alias_ = void, newname = void;
    int newlen = void;
    int aliascount = 20;

    /*
     * Decide at runtime what FontFormat to use.
     */
    Mask FontFormat = ((screenInfo.imageByteOrder == LSBFirst) ?
         BitmapFormatByteOrderLSB : BitmapFormatByteOrderMSB) |
        ((screenInfo.bitmapBitOrder == LSBFirst) ?
         BitmapFormatBitOrderLSB : BitmapFormatBitOrderMSB) |
        BitmapFormatImageRectMin; 
static if(GLYPHPADBYTES == 1)
        FontFormat |= BitmapFormatScanlinePad8 ;
static if(GLYPHPADBYTES == 2)
        FontFormat |= BitmapFormatScanlinePad16 ;
static if(GLYPHPADBYTES == 4)
        FontFormat |= BitmapFormatScanlinePad32 ;
static if(GLYPHPADBYTES == 8)
        FontFormat |= BitmapFormatScanlinePad64 ;
        FontFormat |= BitmapFormatScanlineUnit8;

    if (client.clientGone) {
        if (c.current_fpe < c.num_fpes) {
            fpe = c.fpe_list[c.current_fpe];
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
        }
        err = Successful;
        goto bail;
    }
    while (c.current_fpe < c.num_fpes) {
        fpe = c.fpe_list[c.current_fpe];
        err = assumeNoGC(fpe_functions[fpe.type].open_font)
            (cast(void*) client, fpe, c.flags,
             c.fontname, c.fnamelen, cast(uint)FontFormat,
             cast(uint)(BitmapFormatMaskByte |
             BitmapFormatMaskBit |
             BitmapFormatMaskImageRectangle |
             BitmapFormatMaskScanLinePad |
             BitmapFormatMaskScanLineUnit),
             c.fontid, &pfont, &alias_,
             c.non_cachable_font && c.non_cachable_font.fpe == fpe ?
             c.non_cachable_font : cast(FontPtr) 0);

        if (err == FontNameAlias && alias_) {
            newlen = cast(int)strlen(alias_);
            newname = cast(char*) realloc(cast(char*) c.fontname, newlen);
            if (!newname) {
                err = AllocError;
                break;
            }
            memcpy(newname, alias_, newlen);
            c.fontname = newname;
            c.fnamelen = newlen;
            c.current_fpe = 0;
            if (--aliascount <= 0) {
                /* We've tried resolving this alias 20 times, we're
                 * probably stuck in an infinite loop of aliases pointing
                 * to each other - time to take emergency exit!
                 */
                err = BadImplementation;
                break;
            }
            continue;
        }
        if (err == BadFontName) {
            c.current_fpe++;
            continue;
        }
        if (err == Suspended) {
            if (!ClientIsAsleep(client))
                ClientSleep(client, cast(ClientSleepProcPtr) &doOpenFont, c);
            return TRUE;
        }
        break;
    }

    if (err != Successful)
        goto bail;
    if (!pfont) {
        err = BadFontName;
        goto bail;
    }
    /* check values for firstCol, lastCol, firstRow, and lastRow */
    if (pfont.info.firstCol > pfont.info.lastCol ||
        pfont.info.firstRow > pfont.info.lastRow ||
        pfont.info.lastCol - pfont.info.firstCol > 255) {
        err = AllocError;
        goto bail;
    }
    if (!pfont.fpe)
        pfont.fpe = fpe;
    pfont.refcnt++;
    if (pfont.refcnt == 1) {
        UseFPE(pfont.fpe);
        mixin(DIX_FOR_EACH_SCREEN!q{
            if (walkScreen.RealizeFont) {
                if (!(*walkScreen.RealizeFont) (walkScreen, pfont)) {
                    CloseFont(pfont, cast(Font) 0);
                    err = AllocError;
                    goto bail;
                }
            }
        });
    }
    if (!AddResource(cast(uint)c.fontid, X11_RESTYPE_FONT, cast(void*) pfont)) {
        err = AllocError;
        goto bail;
    }
    if (patternCache && pfont != c.non_cachable_font)
        assumeNoGC(&xfont2_cache_font_pattern)(patternCache, c.origFontName, c.origFontNameLen,
                                  pfont);
 bail:
    if (err != Successful && c.client != serverClient) {
        SendErrorToClient(c.client, X_OpenFont, 0,
                          c.fontid, cast(ubyte)FontToXError(err));
    }
    ClientWakeup(c.client);
    for (int i = 0; i < c.num_fpes; i++) {
        FreeFPE(c.fpe_list[i]);
    }
    free(c.fpe_list);
    free(cast(void*) c.fontname);
    free(c);
    return TRUE;
}

int OpenFont(ClientPtr client, XID fid, Mask flags, uint lenfname, const(char)* pfontname)
{
    FontPtr cached = cast(FontPtr) 0;

    if (!lenfname || lenfname > XLFDMAXFONTNAMELEN)
        return BadName;
    if (patternCache) {

        /*
         ** Check name cache.  If we find a cached version of this font that
         ** is cachable, immediately satisfy the request with it.  If we find
         ** a cached version of this font that is non-cachable, we do not
         ** satisfy the request with it.  Instead, we pass the FontPtr to the
         ** FPE's open_font code (the fontfile FPE in turn passes the
         ** information to the rasterizer; the fserve FPE ignores it).
         **
         ** Presumably, the font is marked non-cachable because the FPE has
         ** put some licensing restrictions on it.  If the FPE, using
         ** whatever logic it relies on, determines that it is willing to
         ** share this existing font with the client, then it has the option
         ** to return the FontPtr we passed it as the newly-opened font.
         ** This allows the FPE to exercise its licensing logic without
         ** having to create another instance of a font that already exists.
         */

        cached = assumeNoGC(&xfont2_find_cached_font_pattern)(patternCache, pfontname, lenfname);
        if (cached && cached.info.cachable) {
            if (!AddResource(cast(uint)fid, X11_RESTYPE_FONT, cast(void*) cached))
                return BadAlloc;
            cached.refcnt++;
            return Success;
        }
    }
    open_font_closure* c = cast(open_font_closure*) calloc(1, open_font_closure.sizeof);
    if (!c)
        return BadAlloc;
    c.fontname = cast(char*)calloc(1, lenfname);
    c.origFontName = pfontname;
    c.origFontNameLen = lenfname;
    if (!c.fontname) {
        free(c);
        return BadAlloc;
    }
    /*
     * copy the current FPE list, so that if it gets changed by another client
     * while we're blocking, the request still appears atomic
     */
    c.fpe_list = cast(FontPathElementPtr*)calloc(num_fpes, FontPathElementPtr.sizeof);
    if (!c.fpe_list) {
        free(cast(void*) c.fontname);
        free(c);
        return BadAlloc;
    }
    memcpy(c.fontname, pfontname, lenfname);
    for (int i = 0; i < num_fpes; i++) {
        c.fpe_list[i] = font_path_elements[i];
        UseFPE(c.fpe_list[i]);
    }
    c.client = client;
    c.fontid = fid;
    c.current_fpe = 0;
    c.num_fpes = cast(ushort)num_fpes;
    c.fnamelen = lenfname;
    c.flags = flags;
    c.non_cachable_font = cached;

    cast(void) doOpenFont(client, c);
    return Success;
}

/**
 * Decrement font's ref count, and free storage if ref count equals zero
 *
 *  \param value must conform to DeleteType
 */
int CloseFont(void* value, XID fid)
{
    FontPathElementPtr fpe = void;
    FontPtr pfont = cast(FontPtr) value;

    if (pfont == NullFont)
        return Success;
    if (--pfont.refcnt == 0) {
        if (patternCache)
            assumeNoGC(&xfont2_remove_cached_font_pattern)(patternCache, pfont);
        /*
         * since the last reference is gone, ask each screen to free any
         * storage it may have allocated locally for it.
         */
        mixin(DIX_FOR_EACH_SCREEN!q{
            if (walkScreen.UnrealizeFont)
                walkScreen.UnrealizeFont(walkScreen, pfont);
        });
        if (pfont == defaultFont)
            defaultFont = null;
// static if (XF86BIGFONT) {
        XF86BigfontFreeFontShm(pfont);
// }
        fpe = pfont.fpe;
        assumeNoGC(fpe_functions[fpe.type].close_font) (fpe, pfont);
        FreeFPE(fpe);
    }
    return Success;
}

/***====================================================================***/

/**
 * Sets up pReply as the correct QueryFontReply for pFont with the first
 * nProtoCCIStructs char infos.
 *
 *  \param pReply caller must allocate this storage
  */
void QueryFont(FontPtr pFont, xQueryFontReply* pReply, int nProtoCCIStructs)
{
    FontPropPtr pFP = void;
    int i = void;
    xFontProp* prFP = void;
    xCharInfo* prCI = void;
    xCharInfo*[256] charInfos = void;
    ubyte[512] chars = void;
    int ninfos = void;
    c_ulong ncols = void;
    c_ulong count = void;

    /* pr->length set in dispatch */
    pReply.minCharOrByte2 = pFont.info.firstCol;
    pReply.defaultChar = pFont.info.defaultCh;
    pReply.maxCharOrByte2 = pFont.info.lastCol;
    pReply.drawDirection = cast(ubyte)pFont.info.drawDirection;
    pReply.allCharsExist = cast(ubyte)pFont.info.allExist;
    pReply.minByte1 = cast(ubyte)pFont.info.firstRow;
    pReply.maxByte1 = cast(ubyte)pFont.info.lastRow;
    pReply.fontAscent = pFont.info.fontAscent;
    pReply.fontDescent = pFont.info.fontDescent;

    pReply.minBounds = pFont.info.ink_minbounds;
    pReply.maxBounds = pFont.info.ink_maxbounds;

    pReply.nFontProps = cast(ushort)pFont.info.nprops;
    pReply.nCharInfos = nProtoCCIStructs;

    for (i = 0, pFP = pFont.info.props, prFP = cast(xFontProp*) (&pReply[1]);
         i < pFont.info.nprops; i++, pFP++, prFP++) {
        prFP.name = cast(uint)pFP.name;
        prFP.value = cast(uint)pFP.value;
    }

    ninfos = 0;
    ncols = cast(c_ulong) (pFont.info.lastCol - pFont.info.firstCol + 1);
    prCI = cast(xCharInfo*) (prFP);
    for (int r = pFont.info.firstRow;
         ninfos < nProtoCCIStructs && r <= cast(int) pFont.info.lastRow; r++) {
        i = 0;
        for (int c = pFont.info.firstCol; c <= cast(int) pFont.info.lastCol; c++) {
            chars[i++] = cast(ubyte)r;
            chars[i++] = cast(ubyte)c;
        }
        assumeNoGC(pFont.get_metrics) (pFont, ncols, chars.ptr,
                               TwoD16Bit, &count, charInfos.ptr);
        for (int j = 0; j < cast(int) count && ninfos < nProtoCCIStructs; j++) {
            *prCI = *charInfos[j];
            prCI++;
            ninfos++;
        }
    }
    return;
}

private Bool doListFontsAndAliases(ClientPtr client, list_fonts_closure* c)
{
    FontPathElementPtr fpe = void;
    int err = Successful;
    FontNamesPtr names = null;
    char* name = void, resolved = null;
    int namelen = void, resolvedlen = void;
    int aliascount = 0;
    xListFontsReply reply;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    if (client.clientGone) {
        if (c.current.current_fpe < c.num_fpes) {
            fpe = c.fpe_list[c.current.current_fpe];
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
        }
        err = Successful;
        goto bail;
    }

    if (!c.current.patlen)
        goto finish;

    while (c.current.current_fpe < c.num_fpes) {
        fpe = c.fpe_list[c.current.current_fpe];
        err = Successful;

        if (!fpe_functions[fpe.type].start_list_fonts_and_aliases) {
            /* This FPE doesn't support/require list_fonts_and_aliases */

            err = assumeNoGC(fpe_functions[fpe.type].list_fonts)
                (cast(void*) c.client, fpe, c.current.pattern.ptr,
                 c.current.patlen, c.current.max_names - c.names.nnames,
                 c.names);

            if (err == Suspended) {
                if (!ClientIsAsleep(client))
                    ClientSleep(client,
                                cast(ClientSleepProcPtr) &doListFontsAndAliases, c);
                return TRUE;
            }

            err = BadFontName;
        }
        else {
            /* Start of list_fonts_and_aliases functionality.  Modeled
               after list_fonts_with_info in that it resolves aliases,
               except that the information collected from FPEs is just
               names, not font info.  Each list_next_font_or_alias()
               returns either a name into name/namelen or an alias into
               name/namelen and its target name into resolved/resolvedlen.
               The code at this level then resolves the alias by polling
               the FPEs.  */

            if (!c.current.list_started) {
                err = assumeNoGC(fpe_functions[fpe.type].start_list_fonts_and_aliases)
                    (cast(void*) c.client, fpe, c.current.pattern.ptr,
                     c.current.patlen, c.current.max_names - c.names.nnames,
                     &c.current.private_);
                if (err == Suspended) {
                    if (!ClientIsAsleep(client))
                        ClientSleep(client,
                                    cast(ClientSleepProcPtr) &doListFontsAndAliases,
                                    c);
                    return TRUE;
                }
                if (err == Successful)
                    c.current.list_started = TRUE;
            }
            if (err == Successful) {
                char* tmpname = void;

                name = null;
                err = assumeNoGC(fpe_functions[fpe.type].list_next_font_or_alias)
                    (cast(void*) c.client, fpe, &name, &namelen, &tmpname,
                     &resolvedlen, c.current.private_);
                if (err == Suspended) {
                    if (!ClientIsAsleep(client))
                        ClientSleep(client,
                                    cast(ClientSleepProcPtr) &doListFontsAndAliases,
                                    c);
                    return TRUE;
                }
                if (err == FontNameAlias) {
                    free(resolved);
                    resolved = cast(char*)XNFalloc(resolvedlen + 1);
                    memcpy(resolved, tmpname, resolvedlen + 1);
                }
            }

            if (err == Successful) {
                if (c.haveSaved) {
                    if (c.savedName)
                        assumeNoGC(&xfont2_add_font_names_name)(c.names, c.savedName,
                                                c.savedNameLen);
                }
                else
                    assumeNoGC(&xfont2_add_font_names_name)(c.names, name, namelen);
            }

            /*
             * When we get an alias back, save our state and reset back to
             * the start of the FPE looking for the specified name.  As
             * soon as a real font is found for the alias, pop back to the
             * old state
             */
            else if (err == FontNameAlias) {
                char[XLFDMAXFONTNAMELEN] tmp_pattern = void;

                /*
                 * when an alias recurses, we need to give
                 * the last FPE a chance to clean up; so we call
                 * it again, and assume that the error returned
                 * is BadFontName, indicating the alias resolution
                 * is complete.
                 */
                memcpy(tmp_pattern.ptr, resolved, resolvedlen);
                if (c.haveSaved) {
                    char* tmpname = void;
                    int tmpnamelen = void;

                    tmpname = null;
                    assumeNoGC(fpe_functions[fpe.type].list_next_font_or_alias)
                        (cast(void*) c.client, fpe, &tmpname, &tmpnamelen,
                         &tmpname, &tmpnamelen, c.current.private_);
                    if (--aliascount <= 0) {
                        err = BadFontName;
                        goto ContBadFontName;
                    }
                }
                else {
                    c.saved = c.current;
                    c.haveSaved = TRUE;
                    free(c.savedName);
                    c.savedName = cast(char*)calloc(1, namelen + 1);
                    if (c.savedName)
                        memcpy(c.savedName, name, namelen + 1);
                    c.savedNameLen = namelen;
                    aliascount = 20;
                }
                memcpy(c.current.pattern.ptr, tmp_pattern.ptr, resolvedlen);
                c.current.patlen = resolvedlen;
                c.current.max_names = c.names.nnames + 1;
                c.current.current_fpe = -1;
                c.current.private_ = null;
                err = BadFontName;
            }
        }
        /*
         * At the end of this FPE, step to the next.  If we've finished
         * processing an alias, pop state back. If we've collected enough
         * font names, quit.
         */
        if (err == BadFontName) {
 ContBadFontName:{}
            c.current.list_started = FALSE;
            c.current.current_fpe++;
            err = Successful;
            if (c.haveSaved) {
                if (c.names.nnames == c.current.max_names ||
                    c.current.current_fpe == c.num_fpes) {
                    c.haveSaved = FALSE;
                    c.current = c.saved;
                    /* Give the saved namelist a chance to clean itself up */
                    continue;
                }
            }
            if (c.names.nnames == c.current.max_names)
                break;
        }
    }

    /*
     * send the reply
     */
    if (err != Successful) {
        SendErrorToClient(client, X_ListFonts, 0, 0, cast(ubyte)FontToXError(err));
        goto bail;
    }

 finish:

    names = c.names;
    client = c.client;
    reply.nFonts = cast(ushort)names.nnames;


    for (int i = 0; i < names.nnames; i++) {
        if (names.length[i] > 255)
            reply.nFonts--;
        else {
            /* write a pascal string */
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)names.length[i]);
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)names.names[i], names.length[i]);
        }
    }

    if (rpcbuf.error) {
        SendErrorToClient(client, X_ListFonts, 0, 0, BadAlloc);
        goto bail;
    }

    if (client.swapped) {
        swaps(&reply.nFonts);
    }

    mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf") ~ `;`);

 bail:
    ClientWakeup(client);
    for (int i = 0; i < c.num_fpes; i++)
        FreeFPE(c.fpe_list[i]);
    free(c.fpe_list);
    free(c.savedName);
    assumeNoGC(&xfont2_free_font_names)(names);
    free(c);
    free(resolved);
    return TRUE;
}

int ListFonts(ClientPtr client, ubyte* pattern, uint length, uint max_names)
{
    int access = void;
    list_fonts_closure* c = void;

    /*
     * The right error to return here would be BadName, however the
     * specification does not allow for a Name error on this request.
     * Perhaps a better solution would be to return a nil list, i.e.
     * a list containing zero fontnames.
     */
    if (length > XLFDMAXFONTNAMELEN)
        return BadAlloc;

    access = dixCallServerAccessCallback(client, DixGetAttrAccess);
    if (access != Success)
        return access;

    if (((c = cast(list_fonts_closure*) calloc(1, (*c).sizeof)) is null))
        return BadAlloc;
    c.fpe_list = cast(_FontPathElement**)calloc(num_fpes, FontPathElementPtr.sizeof);
    if (!c.fpe_list) {
        free(c);
        return BadAlloc;
    }
    c.names = assumeNoGC(&xfont2_make_font_names_record)(max_names < 100 ? max_names : 100);
    if (!c.names) {
        free(c.fpe_list);
        free(c);
        return BadAlloc;
    }
    memmove(c.current.pattern.ptr, pattern, length);
    for (int i = 0; i < num_fpes; i++) {
        c.fpe_list[i] = font_path_elements[i];
        UseFPE(c.fpe_list[i]);
    }
    c.client = client;
    c.num_fpes = num_fpes;
    c.current.patlen = length;
    c.current.current_fpe = 0;
    c.current.max_names = max_names;
    c.current.list_started = FALSE;
    c.current.private_ = null;
    c.haveSaved = FALSE;
    c.savedName = null;
    doListFontsAndAliases(client, c);
    return Success;
}

private int doListFontsWithInfo(ClientPtr client, list_fonts_with_info_closure* c)
{
    FontPathElementPtr fpe = void;
    int err = Successful;
    char* name = void;
    int namelen = 0;
    int numFonts = void;
    FontInfoRec fontInfo = void; FontInfoRec* pFontInfo = void;
    int length = void;
    xFontProp* pFP = void;
    int aliascount = 0;

    xListFontsWithInfoReply reply = { 0 };
    if (client.clientGone) {
        if (c.current.current_fpe < c.num_fpes) {
            fpe = c.fpe_list[c.current.current_fpe];
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
        }
        err = Successful;
        goto bail;
    }
    if (!c.current.patlen)
        goto finish;
    while (c.current.current_fpe < c.num_fpes) {
        fpe = c.fpe_list[c.current.current_fpe];
        err = Successful;
        if (!c.current.list_started) {
            err = assumeNoGC(fpe_functions[fpe.type].start_list_fonts_with_info)
                (client, fpe, c.current.pattern.ptr, c.current.patlen,
                 c.current.max_names, &c.current.private_);
            if (err == Suspended) {
                if (!ClientIsAsleep(client))
                    ClientSleep(client,
                                cast(ClientSleepProcPtr) &doListFontsWithInfo, c);
                return TRUE;
            }
            if (err == Successful)
                c.current.list_started = TRUE;
        }
        if (err == Successful) {
            name = null;
            pFontInfo = &fontInfo;
            err = assumeNoGC(fpe_functions[fpe.type].list_next_font_with_info)
                (client, fpe, &name, &namelen, &pFontInfo,
                 &numFonts, c.current.private_);
            if (err == Suspended) {
                if (!ClientIsAsleep(client))
                    ClientSleep(client,
                                cast(ClientSleepProcPtr) &doListFontsWithInfo, c);
                return TRUE;
            }
        }
        /*
         * When we get an alias back, save our state and reset back to the
         * start of the FPE looking for the specified name.  As soon as a real
         * font is found for the alias, pop back to the old state
         */
        if (err == FontNameAlias) {
            /*
             * when an alias recurses, we need to give
             * the last FPE a chance to clean up; so we call
             * it again, and assume that the error returned
             * is BadFontName, indicating the alias resolution
             * is complete.
             */
            if (c.haveSaved) {
                char* tmpname = void;
                int tmpnamelen = void;
                FontInfoPtr tmpFontInfo = void;

                tmpname = null;
                tmpFontInfo = &fontInfo;
                assumeNoGC(fpe_functions[fpe.type].list_next_font_with_info)
                    (client, fpe, &tmpname, &tmpnamelen, &tmpFontInfo,
                     &numFonts, c.current.private_);
                if (--aliascount <= 0) {
                    err = BadFontName;
                    goto ContBadFontName;
                }
            }
            else {
                c.saved = c.current;
                c.haveSaved = TRUE;
                c.savedNumFonts = numFonts;
                free(c.savedName);
                c.savedName = cast(char*)XNFalloc(namelen + 1);
                memcpy(c.savedName, name, namelen + 1);
                aliascount = 20;
            }
            memmove(c.current.pattern.ptr, name, namelen);
            c.current.patlen = namelen;
            c.current.max_names = 1;
            c.current.current_fpe = 0;
            c.current.private_ = null;
            c.current.list_started = FALSE;
        }
        /*
         * At the end of this FPE, step to the next.  If we've finished
         * processing an alias, pop state back.  If we've sent enough font
         * names, quit.  Always wait for BadFontName to let the FPE
         * have a chance to clean up.
         */
        else if (err == BadFontName) {
 ContBadFontName:{}
            c.current.list_started = FALSE;
            c.current.current_fpe++;
            err = Successful;
            if (c.haveSaved) {
                if (c.current.max_names == 0 ||
                    c.current.current_fpe == c.num_fpes) {
                    c.haveSaved = FALSE;
                    c.saved.max_names -= (1 - c.current.max_names);
                    c.current = c.saved;
                }
            }
            else if (c.current.max_names == 0)
                break;
        }
        else if (err == Successful) {
            length = cast(int)((xListFontsWithInfoReply).sizeof + pFontInfo.nprops * xFontProp.sizeof);
            xListFontsWithInfoReply* _reply = c.reply;
            if (c.length < length) {
                _reply = cast(xListFontsWithInfoReply*) realloc(c.reply, length);
                if (!_reply) {
                    err = AllocError;
                    break;
                }
                memset(cast(char*) _reply + c.length, 0, length - c.length);
                c.reply = _reply;
                c.length = length;
            }
            if (c.haveSaved) {
                numFonts = c.savedNumFonts;
                name = c.savedName;
                namelen = cast(int)strlen(name);
            }
            _reply.type = X_Reply;
            _reply.length =
                mixin(X_REPLY_HEADER_UNITS!("xListFontsWithInfoReply"))
                + bytes_to_int32(pFontInfo.nprops*(xFontProp).sizeof+namelen);
            _reply.sequenceNumber = cast(ushort)client.sequence;
            _reply.nameLength = cast(ubyte)namelen;
            _reply.minBounds = pFontInfo.ink_minbounds;
            _reply.maxBounds = pFontInfo.ink_maxbounds;
            _reply.minCharOrByte2 = pFontInfo.firstCol;
            _reply.maxCharOrByte2 = pFontInfo.lastCol;
            _reply.defaultChar = pFontInfo.defaultCh;
            _reply.nFontProps = cast(ushort)pFontInfo.nprops;
            _reply.drawDirection = cast(ubyte)pFontInfo.drawDirection;
            _reply.minByte1 = cast(ubyte)pFontInfo.firstRow;
            _reply.maxByte1 = cast(ubyte)pFontInfo.lastRow;
            _reply.allCharsExist = cast(ubyte)pFontInfo.allExist;
            _reply.fontAscent = pFontInfo.fontAscent;
            _reply.fontDescent = pFontInfo.fontDescent;
            _reply.nReplies = numFonts;
            pFP = cast(xFontProp*) (_reply + 1);
            for (int i = 0; i < pFontInfo.nprops; i++) {
                pFP.name = cast(uint)pFontInfo.props[i].name;
                pFP.value = cast(uint)pFontInfo.props[i].value;
                pFP++;
            }
            if (client.swapped) {
                swaps(&_reply.sequenceNumber);
                swapl(&_reply.length);
                uint nprops = _reply.nFontProps;

                /* from SwapInfo() */
                swaps(&_reply.minCharOrByte2);
                swaps(&_reply.maxCharOrByte2);
                swaps(&_reply.defaultChar);
                swaps(&_reply.nFontProps);
                swaps(&_reply.fontAscent);
                swaps(&_reply.fontDescent);
                swapl(&_reply.nReplies);

                /* from SwapCharInfo */
                swaps(&_reply.minBounds.leftSideBearing);
                swaps(&_reply.minBounds.rightSideBearing);
                swaps(&_reply.minBounds.characterWidth);
                swaps(&_reply.minBounds.ascent);
                swaps(&_reply.minBounds.descent);
                swaps(&_reply.minBounds.attributes);

                /* from SwapCharInfo */
                swaps(&_reply.maxBounds.leftSideBearing);
                swaps(&_reply.maxBounds.rightSideBearing);
                swaps(&_reply.maxBounds.characterWidth);
                swaps(&_reply.maxBounds.ascent);
                swaps(&_reply.maxBounds.descent);
                swaps(&_reply.maxBounds.attributes);

                char* pby = cast(char*) &_reply[1];
                /* Font properties are an atom and either an int32 or a CARD32, so
                 * they are always 2 4 byte values */
                for (uint i = 0; i < nprops; i++) {
                    swapl(cast(int*) pby);
                    pby += 4;
                    swapl(cast(int*) pby);
                    pby += 4;
                }
            }
            WriteToClient(client, length, _reply);
            WriteToClient(client, namelen, name);
            if (pFontInfo == &fontInfo) {
                free(fontInfo.props);
                free(fontInfo.isStringProp);
            }
            --c.current.max_names;
        }
    }
 finish: 
    /* finish it the replies series sending an empty _reply */
    mixin(X_SEND_REPLY_SIMPLE!("client", "reply")~`;`);
 bail:
    ClientWakeup(client);
    for (int i = 0; i < c.num_fpes; i++)
        FreeFPE(c.fpe_list[i]);
    free(c.reply);
    free(c.fpe_list);
    free(c.savedName);
    free(c);
    return TRUE;
}

int StartListFontsWithInfo(ClientPtr client, int length, ubyte* pattern, int max_names)
{
    int access = void;
    list_fonts_with_info_closure* c = void;

    /*
     * The right error to return here would be BadName, however the
     * specification does not allow for a Name error on this request.
     * Perhaps a better solution would be to return a nil list, i.e.
     * a list containing zero fontnames.
     */
    if (length > XLFDMAXFONTNAMELEN)
        return BadAlloc;

    access = dixCallServerAccessCallback(client, DixGetAttrAccess);
    if (access != Success)
        return access;

    if (((c = cast(list_fonts_with_info_closure*) calloc(1, (*c).sizeof)) is null))
        goto badAlloc;
    c.fpe_list = cast(_FontPathElement**)calloc(num_fpes, FontPathElementPtr.sizeof);
    if (!c.fpe_list) {
        free(c);
        goto badAlloc;
    }
    memmove(c.current.pattern.ptr, pattern, length);
    for (int i = 0; i < num_fpes; i++) {
        c.fpe_list[i] = font_path_elements[i];
        UseFPE(c.fpe_list[i]);
    }
    c.client = client;
    c.num_fpes = num_fpes;
    c.reply = null;
    c.length = 0;
    c.current.patlen = length;
    c.current.current_fpe = 0;
    c.current.max_names = max_names;
    c.current.list_started = FALSE;
    c.current.private_ = null;
    c.savedNumFonts = 0;
    c.haveSaved = FALSE;
    c.savedName = null;
    doListFontsWithInfo(client, c);
    return Success;
 badAlloc:
    return BadAlloc;
}

enum TextEltHeader = 2;
enum FontShiftSize = 5;
private ChangeGCVal[1] clearGC = [ {ptr: NullPixmap} ];

enum clearGCmask = (GCClipMask);

private int doPolyText(ClientPtr client, poly_text_closure* c)
{
    FontPtr pFont = c.pGC.font, oldpFont = void;
    int err = Success, lgerr = void;   /* err is in X error, not font error, space */
    enum _Client_state { NEVER_SLEPT, START_SLEEP, SLEEPING }
    _Client_state client_state = _Client_state.NEVER_SLEPT;
    FontPathElementPtr fpe = void;
    GCPtr origGC = null;
    int itemSize = c.reqType == X_PolyText8 ? 1 : 2;

    if (client.clientGone) {
        fpe = c.pGC.font.fpe;
        assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);

        if (ClientIsAsleep(client)) {
            /* Client has died, but we cannot bail out right now.  We
               need to clean up after the work we did when going to
               sleep.  Setting the drawable pointer to 0 makes this
               happen without any attempts to render or perform other
               unnecessary activities.  */
            c.pDraw = cast(DrawablePtr) 0;
        }
        else {
            err = Success;
            goto bail;
        }
    }

    /* Make sure our drawable hasn't disappeared while we slept. */
    if (ClientIsAsleep(client) && c.pDraw) {
        DrawablePtr pDraw = void;

        dixLookupDrawable(&pDraw, c.did, client, 0, DixWriteAccess);
        if (c.pDraw != pDraw) {
            /* Our drawable has disappeared.  Treat like client died... ask
               the FPE code to clean up after client and avoid further
               rendering while we clean up after ourself.  */
            fpe = c.pGC.font.fpe;
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
            c.pDraw = cast(DrawablePtr) 0;
        }
    }

    client_state = ClientIsAsleep(client) ? _Client_state.SLEEPING : _Client_state.NEVER_SLEPT;

    while (c.endReq - c.pElt > TextEltHeader) {
        if (*c.pElt == FontChange) {
            Font fid = void;

            if (c.endReq - c.pElt < FontShiftSize) {
                err = BadLength;
                goto bail;
            }

            oldpFont = pFont;

            fid = (cast(Font) *(c.pElt + 4))       /* big-endian */
                |(cast(Font) *(c.pElt + 3)) << 8
                | (cast(Font) *(c.pElt + 2)) << 16 | (cast(Font) *(c.pElt + 1)) << 24;
            err = dixLookupResourceByType(cast(void**) &pFont, fid, X11_RESTYPE_FONT,
                                          client, DixUseAccess);
            if (err != Success) {
                /* restore pFont for step 4 (described below) */
                pFont = oldpFont;

                /* If we're in START_SLEEP mode, the following step
                   shortens the request...  in the unlikely event that
                   the fid somehow becomes valid before we come through
                   again to actually execute the polytext, which would
                   then mess up our refcounting scheme badly.  */
                c.err = err;
                c.endReq = c.pElt;

                goto bail;
            }

            /* Step 3 (described below) on our new font */
            if (client_state == _Client_state.START_SLEEP)
                pFont.refcnt++;
            else {
                if (pFont != c.pGC.font && c.pDraw) {
                    ChangeGCVal val = void;

                    val.ptr = pFont;
                    ChangeGC(null, c.pGC, cast(uint)GCFont, &val);
                    ValidateGC(c.pDraw, c.pGC);
                }

                /* Undo the refcnt++ we performed when going to sleep */
                if (client_state == _Client_state.SLEEPING)
                    cast(void) CloseFont(c.pGC.font, cast(Font) 0);
            }
            c.pElt += FontShiftSize;
        }
        else {                  /* print a string */

            ubyte* pNextElt = void;

            pNextElt = c.pElt + TextEltHeader + (*c.pElt) * itemSize;
            if (pNextElt > c.endReq) {
                err = BadLength;
                goto bail;
            }
            if (client_state == _Client_state.START_SLEEP) {
                c.pElt = pNextElt;
                continue;
            }
            if (c.pDraw) {
                lgerr = LoadGlyphs(client, c.pGC.font, *c.pElt, itemSize,
                                   c.pElt + TextEltHeader);
            }
            else
                lgerr = Successful;

            if (lgerr == Suspended) {
                if (!ClientIsAsleep(client)) {
                    int len = void;
                    GCPtr pGC = void;

                    /*  We're putting the client to sleep.  We need to do a few things
                       to ensure successful and atomic-appearing execution of the
                       remainder of the request.  First, copy the remainder of the
                       request into a safe calloc'd area.  Second, create a scratch GC
                       to use for the remainder of the request.  Third, mark all fonts
                       referenced in the remainder of the request to prevent their
                       deallocation.  Fourth, make the original GC look like the
                       request has completed...  set its font to the final font value
                       from this request.  These GC manipulations are for the unlikely
                       (but possible) event that some other client is using the GC.
                       Steps 3 and 4 are performed by running this procedure through
                       the remainder of the request in a special no-render mode
                       indicated by client_state = START_SLEEP.  */

                    /* Step 1 */
                    /* Allocate a calloc'd closure structure to replace
                       the local one we were passed */
                    poly_text_closure* new_closure = cast(poly_text_closure*) calloc(1, poly_text_closure.sizeof);
                    if (!new_closure) {
                        err = BadAlloc;
                        goto bail;
                    }
                    *new_closure = *c;

                    len = cast(int)(new_closure.endReq - new_closure.pElt);
                    new_closure.data = cast(ubyte*)calloc(1, len);
                    if (!new_closure.data) {
                        free(new_closure);
                        err = BadAlloc;
                        goto bail;
                    }
                    memcpy(new_closure.data, new_closure.pElt, len);
                    new_closure.pElt = new_closure.data;
                    new_closure.endReq = new_closure.pElt + len;

                    /* Step 2 */

                    pGC =
                        GetScratchGC(new_closure.pGC.depth,
                                     new_closure.pGC.pScreen);
                    if (!pGC) {
                        free(new_closure.data);
                        free(new_closure);
                        err = BadAlloc;
                        goto bail;
                    }
                    if ((err = CopyGC(new_closure.pGC, pGC, cast(uint)(GCFunction |
                                      GCPlaneMask | GCForeground |
                                      GCBackground | GCFillStyle |
                                      GCTile | GCStipple |
                                      GCTileStipXOrigin |
                                      GCTileStipYOrigin | GCFont |
                                      GCSubwindowMode | GCClipXOrigin |
                                      GCClipYOrigin | GCClipMask))) != Success) {
                        FreeScratchGC(pGC);
                        free(new_closure.data);
                        free(new_closure);
                        err = BadAlloc;
                        goto bail;
                    }
                    c = new_closure;
                    origGC = c.pGC;
                    c.pGC = pGC;
                    ValidateGC(c.pDraw, c.pGC);

                    ClientSleep(client, cast(ClientSleepProcPtr) &doPolyText, c);

                    /* Set up to perform steps 3 and 4 */
                    client_state = _Client_state.START_SLEEP;
                    continue;   /* on to steps 3 and 4 */
                }
                return TRUE;
            }
            else if (lgerr != Successful) {
                err = FontToXError(lgerr);
                goto bail;
            }
            if (c.pDraw) {
                c.xorg += *(cast(INT8*) (c.pElt + 1));   /* must be signed */
                if (c.reqType == X_PolyText8)
                    c.xorg =
                        (*c.pGC.ops.PolyText8) (c.pDraw, c.pGC, c.xorg,
                                                   c.yorg, *c.pElt,
                                                   cast(char*) (c.pElt +
                                                             TextEltHeader));
                else
                    c.xorg =
                        (*c.pGC.ops.PolyText16) (c.pDraw, c.pGC, c.xorg,
                                                    c.yorg, *c.pElt,
                                                    cast(ushort*) (c.
                                                                        pElt +
                                                                        TextEltHeader));
            }
            c.pElt = pNextElt;
        }
    }

 bail:
    if (client_state == _Client_state.START_SLEEP) {
        /* Step 4 */
        if (origGC && (pFont != origGC.font)) {
            ChangeGCVal val = void;

            val.ptr = pFont;
            ChangeGC(null, origGC, cast(uint)GCFont, &val);
            ValidateGC(c.pDraw, origGC);
        }

        /* restore pElt pointer for execution of remainder of the request */
        c.pElt = c.data;
        return TRUE;
    }

    if (c.err != Success)
        err = c.err;
    if (err != Success && c.client != serverClient) {
static if(XINERAMA){
        if (noPanoramiXExtension || !c.pGC.pScreen.myNum)
            SendErrorToClient(c.client, c.reqType, 0, 0, cast(ubyte)err);
} /* XINERAMA */
else {
            SendErrorToClient(c.client, c.reqType, 0, 0, cast(ubyte)err);
}
    }
    if (ClientIsAsleep(client)) {
        ClientWakeup(c.client);
        ChangeGC(null, c.pGC, clearGCmask, clearGC.ptr);

        /* Unreference the font from the scratch GC */
        CloseFont(c.pGC.font, cast(Font) 0);
        c.pGC.font = NullFont;

        FreeScratchGC(c.pGC);
        free(c.data);

        /* if compiler/ananylzer warns here, it's a false alarm:
           here `c` points to a calloc()ed chunk, not the on-stack struct
           from PolyText(). */
        free(c);
    }
    return TRUE;
}

int PolyText(ClientPtr client, DrawablePtr pDraw, GCPtr pGC, ubyte* pElt, ubyte* endReq, int xorg, int yorg, int reqType, XID did)
{
    poly_text_closure local_closure = {
        client: client,
        pDraw: pDraw,
        pGC: pGC,
        pElt: pElt,
        endReq: endReq,
        xorg: xorg,
        yorg: cast(ubyte)yorg,
        reqType: cast(ubyte)reqType,
        did: did,
        err: Success
    };

    cast(void) doPolyText(client, &local_closure);
    return Success;
}

private int doImageText(ClientPtr client, image_text_closure* c)
{
    int err = Success, lgerr = void;   /* err is in X error, not font error, space */
    FontPathElementPtr fpe = void;
    int itemSize = c.reqType == X_ImageText8 ? 1 : 2;

    if (client.clientGone) {
        fpe = c.pGC.font.fpe;
        assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
        err = Success;
        goto bail;
    }

    /* Make sure our drawable hasn't disappeared while we slept. */
    if (ClientIsAsleep(client) && c.pDraw) {
        DrawablePtr pDraw = void;

        dixLookupDrawable(&pDraw, c.did, client, 0, DixWriteAccess);
        if (c.pDraw != pDraw) {
            /* Our drawable has disappeared.  Treat like client died... ask
               the FPE code to clean up after client. */
            fpe = c.pGC.font.fpe;
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
            err = Success;
            goto bail;
        }
    }

    lgerr = LoadGlyphs(client, c.pGC.font, c.nChars, itemSize, c.data);
    if (lgerr == Suspended) {
        if (!ClientIsAsleep(client)) {
            GCPtr pGC = void;
            ubyte* data = void;
            image_text_closure* old_closure = null;

            /* We're putting the client to sleep.  We need to
               save some state.  Similar problem to that handled
               in doPolyText, but much simpler because the
               request structure is much simpler. */

            image_text_closure* new_closure = cast(image_text_closure*) calloc(1, image_text_closure.sizeof);
            if (!new_closure) {
                err = BadAlloc;
                goto bail;
            }
            old_closure = c;
            *new_closure = *c;
            c = new_closure;

            data = cast(ubyte*) calloc(c.nChars, itemSize);
            if (!data) {
                free(c);
                c = old_closure;
                err = BadAlloc;
                goto bail;
            }
            memcpy(data, c.data, c.nChars * itemSize);
            c.data = data;

            pGC = GetScratchGC(c.pGC.depth, c.pGC.pScreen);
            if (!pGC) {
                free(c.data);
                free(c);
                c = old_closure;
                err = BadAlloc;
                goto bail;
            }
            if ((err = CopyGC(c.pGC, pGC, cast(uint)(GCFunction | GCPlaneMask |
                              GCForeground | GCBackground | GCFillStyle |
                              GCTile | GCStipple | GCTileStipXOrigin |
                              GCTileStipYOrigin | GCFont |
                              GCSubwindowMode | GCClipXOrigin |
                              GCClipYOrigin | GCClipMask))) != Success) {
                FreeScratchGC(pGC);
                free(c.data);
                free(c);
                c = old_closure;
                err = BadAlloc;
                goto bail;
            }
            c.pGC = pGC;
            ValidateGC(c.pDraw, c.pGC);

            ClientSleep(client, cast(ClientSleepProcPtr) &doImageText, c);
        }
        return TRUE;
    }
    else if (lgerr != Successful) {
        err = FontToXError(lgerr);
        goto bail;
    }
    if (c.pDraw) {
        if (c.reqType == X_ImageText8)
            (*c.pGC.ops.ImageText8) (c.pDraw, c.pGC, c.xorg, c.yorg,
                                        c.nChars, cast(char*) c.data);
        else
            (*c.pGC.ops.ImageText16) (c.pDraw, c.pGC, c.xorg, c.yorg,
                                         c.nChars, cast(ushort*) c.data);
    }

 bail:

    if (err != Success && c.client != serverClient) {
        SendErrorToClient(c.client, c.reqType, 0, 0, cast(ubyte)err);
    }
    if (ClientIsAsleep(client)) {
        ClientWakeup(c.client);
        ChangeGC(null, c.pGC, clearGCmask, clearGC.ptr);

        /* Unreference the font from the scratch GC */
        CloseFont(c.pGC.font, cast(Font) 0);
        c.pGC.font = NullFont;

        FreeScratchGC(c.pGC);
        free(c.data);
        /* if compiler/ananylzer warns here, it's a false alarm:
           here `c` points to a calloc()ed chunk, not the on-stack struct
           from PolyText(). */
        free(c);
    }
    return TRUE;
}

int ImageText(ClientPtr client, DrawablePtr pDraw, GCPtr pGC, int nChars, ubyte* data, int xorg, int yorg, int reqType, XID did)
{
    image_text_closure local_closure = void;

    local_closure.client = client;
    local_closure.pDraw = pDraw;
    local_closure.pGC = pGC;
    local_closure.nChars = cast(ubyte)nChars;
    local_closure.data = data;
    local_closure.xorg = cast(ubyte)xorg;
    local_closure.yorg = cast(ubyte)yorg;
    local_closure.reqType = cast(ubyte)reqType;
    local_closure.did = did;

    cast(void) doImageText(client, &local_closure);
    return Success;
}

/* does the necessary magic to figure out the fpe type */
private int DetermineFPEType(const(char)* pathname)
{
    for (int i = 0; i < num_fpe_types; i++) {
        if (assumeNoGC(fpe_functions[i].name_check) (pathname))
            return i;
    }
    return -1;
}

private void FreeFontPath(FontPathElementPtr* list, int n, Bool force)
{
    for (int i = 0; i < n; i++) {
        if (force) {
            /* Sanity check that all refcounts will be 0 by the time
               we get to the end of the list. */
            int found = 1;      /* the first reference is us */

            for (int j = i + 1; j < n; j++) {
                if (list[j] == list[i])
                    found++;
            }
            if (list[i].refcount != found) {
                list[i].refcount = found;      /* ensure it will get freed */
            }
        }
        FreeFPE(list[i]);
    }
    free(list);
}

private FontPathElementPtr find_existing_fpe(FontPathElementPtr* list, int num, ubyte* name, int len)
{
    FontPathElementPtr fpe = void;

    for (int i = 0; i < num; i++) {
        fpe = list[i];
        if (fpe.name_length == len && memcmp(name, fpe.name, len) == 0)
            return fpe;
    }
    return cast(FontPathElementPtr) 0;
}

private int SetFontPathElements(int npaths, ubyte* paths, int* bad, Bool persist)
{
    int i = void, err = 0;
    int valid_paths = 0;
    uint len = void;
    ubyte* cp = paths;
    FontPathElementPtr fpe = null; FontPathElementPtr* fplist = void;

    fplist = cast(FontPathElementPtr*) calloc(npaths, FontPathElementPtr.sizeof);
    if (!fplist) {
        *bad = 0;
        return BadAlloc;
    }
    for (i = 0; i < num_fpe_types; i++) {
        if (fpe_functions[i].set_path_hook)
            assumeNoGC(fpe_functions[i].set_path_hook) ();
    }
    for (i = 0; i < npaths; i++) {
        len = cast(uint) (*cp++);

        if (len == 0) {
            if (persist)
                ErrorF
                    ("[dix] Removing empty element from the valid list of fontpaths\n");
            err = BadValue;
        }
        else {
            /* if it's already in our active list, just reset it */
            /*
             * note that this can miss FPE's in limbo -- may be worth catching
             * them, though it'd muck up refcounting
             */
            fpe = find_existing_fpe(font_path_elements, num_fpes, cp, len);
            if (fpe) {
                err = assumeNoGC(fpe_functions[fpe.type].reset_fpe) (fpe);
                if (err == Successful) {
                    UseFPE(fpe);        /* since it'll be decref'd later when freed
                                         * from the old list */
                }
                else
                    fpe = null;
            }
            /* if error or can't do it, act like it's a new one */
            if (!fpe) {
                fpe = cast(FontPathElementRec*) calloc(1, FontPathElementRec.sizeof);
                if (!fpe) {
                    err = BadAlloc;
                    goto bail;
                }
                char* name = cast(char*) calloc(1, len + 1);
                if (!name) {
                    free(fpe);
                    err = BadAlloc;
                    goto bail;
                }
                fpe.refcount = 1;

                strncpy(name, cast(char*) cp, cast(int) len);
                name[len] = '\0';
                fpe.name = name;
                fpe.name_length = len;
                fpe.type = DetermineFPEType(fpe.name);
                if (fpe.type == -1)
                    err = BadValue;
                else
                    err = assumeNoGC(fpe_functions[fpe.type].init_fpe) (fpe);
                if (err != Successful) {
                    if (persist) {
                        DebugF
                            ("[dix] Could not init font path element %s, removing from list!\n",
                             fpe.name);
                    }
                    free(cast(void*) fpe.name);
                    free(fpe);
                }
            }
        }
        if (err != Successful) {
            if (!persist)
                goto bail;
        }
        else {
            fplist[valid_paths++] = fpe;
        }
        cp += len;
    }

    FreeFontPath(font_path_elements, num_fpes, FALSE);
    font_path_elements = fplist;
    if (patternCache)
        assumeNoGC(&xfont2_empty_font_pattern_cache)(patternCache);
    num_fpes = valid_paths;

    return Success;
 bail:
    *bad = i;
    while (--valid_paths >= 0)
        FreeFPE(fplist[valid_paths]);
    free(fplist);
    return FontToXError(err);
}

int SetFontPath(ClientPtr client, int npaths, ubyte* paths)
{
    int err = dixCallServerAccessCallback(client, DixManageAccess);

    if (err != Success)
        return err;

    if (npaths == 0) {
        if (SetDefaultFontPath(defaultFontPath) != Success)
            return BadValue;
    }
    else {
        int bad = void;

        err = SetFontPathElements(npaths, paths, &bad, FALSE);
        if (err != Success)
            client.errorValue = cast(uint)bad;
    }
    return err;
}

int SetDefaultFontPath(const(char)* path)
{
    const(char)* start = void, end = void;
    char* temp_path = void;
    ubyte* cp = void, pp = void, nump = void, newpath = void;
    int num = 1, len = void, err = void, size = 0, bad = void;

    /* ensure temp_path contains "built-ins" */
    start = path;
    while (1) {
        start = strstr(start, "built-ins");
        if (start is null)
            break;
        end = start + strlen("built-ins");
        if ((start == path || start[-1] == ',') && (!*end || *end == ','))
            break;
        start = end;
    }
    if (!start) {
        if (asprintf(&temp_path, "%s%sbuilt-ins".ptr, path, *path ? ",".ptr : "".ptr)
            == -1)
            temp_path = null;
    }
    else {
        temp_path = strdup(path);
    }
    if (!temp_path)
        return BadAlloc;

    /* get enough for string, plus values -- use up commas */
    len = cast(int)(strlen(temp_path) + 1);
    nump = cp = newpath = cast(ubyte*) calloc(1, len);
    if (!newpath) {
        free(temp_path);
        return BadAlloc;
    }
    pp = cast(ubyte*) temp_path;
    cp++;
    while (*pp) {
        if (*pp == ',') {
            *nump = cast(ubyte) size;
            nump = cp++;
            pp++;
            num++;
            size = 0;
        }
        else {
            *cp++ = *pp++;
            size++;
        }
    }
    *nump = cast(ubyte) size;

    err = SetFontPathElements(num, newpath, &bad, TRUE);

    free(newpath);
    free(temp_path);

    return err;
}

void DeleteClientFontStuff(ClientPtr client)
{
    FontPathElementPtr fpe = void;

    for (int i = 0; i < num_fpes; i++) {
        fpe = font_path_elements[i];
        if (fpe_functions[fpe.type].client_died)
            assumeNoGC(fpe_functions[fpe.type].client_died) (cast(void*) client, fpe);
    }
}

int FillFontPath(x_rpcbuf_t* rpcbuf)
{
    for (int i = 0; i < num_fpes; i++) {
        FontPathElementPtr fpe = font_path_elements[i];
        /* write a pascal-string */
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)fpe.name_length);
        x_rpcbuf_write_CARD8s(rpcbuf, cast(CARD8*)fpe.name, fpe.name_length);
    }
    return num_fpes;
}

private int register_fpe_funcs(xfont2_fpe_funcs_rec* funcs)
{
    xfont2_fpe_funcs_rec** new_ = void;

    /* grow the list */
    new_ = cast(xfont2_fpe_funcs_ptr*) reallocarray(fpe_functions, num_fpe_types + 1, xfont2_fpe_funcs_ptr.sizeof);
    if (!new_)
        return -1;
    fpe_functions = new_;

    fpe_functions[num_fpe_types] = funcs;

    return num_fpe_types++;
}

private c_ulong get_server_generation()
{
    return serverGeneration;
}

private void* get_server_client()
{
    return serverClient;
}

private int get_default_point_size()
{
    return 120;
}

private FontResolutionPtr get_client_resolutions(int* num)
{
    static _FontResolution res;
    ScreenPtr masterScreen = dixGetMasterScreen();

    res.x_resolution = cast(ushort)((masterScreen.width * 25.4) / masterScreen.mmWidth);
    /*
     * XXX - we'll want this as long as bitmap instances are prevalent
     so that we can match them from scalable fonts
     */
    if (res.x_resolution < 88)
        res.x_resolution = 75;
    else
        res.x_resolution = 100;
    res.y_resolution = cast(ushort)((masterScreen.height * 25.4) / masterScreen.mmHeight);
    if (res.y_resolution < 88)
        res.y_resolution = 75;
    else
        res.y_resolution = 100;
    res.point_size = 120;
    *num = 1;
    return &res;
}

void FreeFonts()
{
    if (patternCache) {
        assumeNoGC(&xfont2_free_font_pattern_cache)(patternCache);
        patternCache = null;
    }
    FreeFontPath(font_path_elements, num_fpes, TRUE);
    font_path_elements = null;
    num_fpes = 0;
    free(fpe_functions);
    num_fpe_types = 0;
    fpe_functions = null;
}

/* convenience functions for FS interface */

private FontPtr find_old_font(XID id)
{
    void* pFont = void;

    dixLookupResourceByType(&pFont, id, X11_RESTYPE_NONE, serverClient, DixReadAccess);
    return cast(FontPtr) pFont;
}

private Font get_new_font_client_id()
{
    return dixAllocServerXID();
}

private int store_font_Client_font(FontPtr pfont, Font id)
{
    return AddResource(cast(uint)id, X11_RESTYPE_NONE, cast(void*) pfont);
}

private void delete_font_client_id(Font id)
{
    FreeResource(cast(uint)id, X11_RESTYPE_NONE);
}

private int _client_auth_generation(ClientPtr client)
{
    return 0;
}

private int fs_handlers_installed = 0;
private x_server_generation_t last_server_gen;

private void fs_block_handler(void* blockData, void* timeout)
{
    alias FnType = extern(C) void function(void*); 

    FontBlockHandlerProcPtr block_handler = cast(FontBlockHandlerProcPtr)blockData;

    assumeNoGC(block_handler)(timeout);
}

struct fs_fd_entry {
    xorg_list entry;
    int fd;
    void* data;
    FontFdHandlerProcPtr handler;
}

private void fs_fd_handler(int fd, int ready, void* data)
{
    fs_fd_entry* entry = cast(fs_fd_entry*) data;

    assumeNoGC(entry.handler)(fd, entry.data);
}

private xorg_list fs_fd_list;

private int add_fs_fd(int fd, FontFdHandlerProcPtr handler, void* data)
{
    fs_fd_entry* entry = cast(fs_fd_entry*) cast(fs_fd_entry*) calloc(1, fs_fd_entry.sizeof);

    if (!entry)
        return FALSE;

    entry.fd = fd;
    entry.data = data;
    entry.handler = handler;
    if (!SetNotifyFd(fd, &fs_fd_handler, X_NOTIFY_READ, entry)) {
        free(entry);
        return FALSE;
    }
    xorg_list_add(&entry.entry, &fs_fd_list);
    return TRUE;
}

private void remove_fs_fd(int fd)
{
    fs_fd_entry* entry = void, temp = void;

    mixin(xorg_list_for_each_entry_safe!("entry", "temp", "&fs_fd_list", "entry", q{
        if (entry.fd == fd) {
            xorg_list_del(&entry.entry);
            free(entry);
            break;
        }
    }));
    RemoveNotifyFd(fd);
}

private void adjust_fs_wait_for_delay(void* wt, c_ulong newdelay)
{
    AdjustWaitForDelay(wt, cast(int)newdelay);
}

private int _init_fs_handlers(FontPathElementPtr fpe, FontBlockHandlerProcPtr block_handler)
{
    /* if server has reset, make sure the b&w handlers are reinstalled */
    if (last_server_gen < serverGeneration) {
        last_server_gen = serverGeneration;
        fs_handlers_installed = 0;
    }
    if (fs_handlers_installed == 0) {
        if (!RegisterBlockAndWakeupHandlers(&fs_block_handler,
                                            &FontWakeup, block_handler))
            return AllocError;
        xorg_list_init(&fs_fd_list);
        fs_handlers_installed++;
    }
    QueueFontWakeup(fpe);
    return Successful;
}

private void _remove_fs_handlers(FontPathElementPtr fpe, FontBlockHandlerProcPtr block_handler, Bool all)
{
    if (all) {
        /* remove the handlers if no one else is using them */
        if (--fs_handlers_installed == 0) {
            RemoveBlockAndWakeupHandlers(&fs_block_handler, &FontWakeup,
                                         cast(void*) block_handler);
        }
    }
    RemoveFontWakeup(fpe);
}

private uint wrap_time_in_millis()
{
    return cast(uint)GetTimeInMillis();
}

private void verrorf(const(char)* f, va_list args)
{
    LogVMessageVerb(X_NONE, -1, f, args);
}

private xfont2_client_funcs_rec xfont2_client_funcs = {
    XFONT2_CLIENT_FUNCS_VERSION,
    client_auth_generation: &_client_auth_generation,
    client_signal: &dixClientSignal,
    delete_font_client_id: &delete_font_client_id,
    verrorf: &verrorf,
    find_old_font: &find_old_font,
    get_client_resolutions: &get_client_resolutions,
    get_default_point_size: &get_default_point_size,
    get_new_font_client_id: &get_new_font_client_id,
    get_time_in_millis: &wrap_time_in_millis,
    init_fs_handlers: &_init_fs_handlers,
    register_fpe_funcs: &register_fpe_funcs,
    remove_fs_handlers: &_remove_fs_handlers,
    get_server_client: &get_server_client,
    set_font_authorizations: &set_font_authorizations,
    store_font_client_font: &store_font_Client_font,
    make_atom: &MakeAtom,
    valid_atom: &ValidAtom,
    name_for_atom: &NameForAtom,
    get_server_generation: &get_server_generation,
    add_fs_fd: &add_fs_fd,
    remove_fs_fd: &remove_fs_fd,
    adjust_fs_wait_for_delay: &adjust_fs_wait_for_delay,
};

xfont2_pattern_cache_ptr fontPatternCache;

void InitFonts()
{
    if (fontPatternCache)
	assumeNoGC(&xfont2_free_font_pattern_cache)(fontPatternCache);
    fontPatternCache = assumeNoGC(&xfont2_make_font_pattern_cache)();
    assumeNoGC(&xfont2_init)(&xfont2_client_funcs);
}
