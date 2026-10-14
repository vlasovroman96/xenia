module render.picture;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright © 2000 SuSE, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of SuSE not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  SuSE makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * SuSE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL SuSE
 * BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Author:  Keith Packard, SuSE, Inc.
 */

import build.dix_config;

import dix.colormap_priv;
import dix.screen_hooks_priv;
import include.extinit;
import os.osdep;
import os.log;
import include.misc;
import include.scrnintstr;
import include.os;
import include.regionstr;
import include.validate;
import include.windowstr;
import include.input;
import include.resource;
import dix.cursor;
import include.dixstruct;
import include.gcstruct;
import include.servermd;
import render.picturestr_priv;
import render.glyphstr_priv;
import Xext.xace;
import externs.X11.extensions.renderproto;
import x11.Xdefs;
import dix.resource;
import dix.screen_hooks;
import dix.colormap;
import region;
import build.xlibre_server;

static if(XINERAMA){
import Xext.panoramiXsrv;
} /* XINERAMA */

DevPrivateKeyRec PictureScreenPrivateKeyRec;
DevPrivateKeyRec PictureWindowPrivateKeyRec;
RESTYPE PictureType;
RESTYPE PictFormatType;
RESTYPE GlyphSetType;
int PictureCmapPolicy = PictureCmapPolicyDefault;

// PIXMAN_FORMAT(bpp,type,a,r,g,b)	(((bpp) << 24) |  \
// 					 ((type) << 16) | \
// 					 ((a) << 12) |	  \
// 					 ((r) << 8) |	  \
// 					 ((g) << 4) |	  \
// 					 ((b)))

PictFormatPtr PictureWindowFormat(WindowPtr pWindow)
{
    ScreenPtr pScreen = pWindow.drawable.pScreen;
    return PictureMatchVisual(pScreen, pWindow.drawable.depth,
                              WindowGetVisual(pWindow));
}

enum string MaskT(string n) = `((1 << (`~n~`)) - 1)`;

private void picture_window_destructor(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWindow)
{
    PicturePtr pPicture = void;

    while ((pPicture = mixin(GetPictureWindow!("pWindow"))) !is null) {
        mixin(SetPictureWindow!("pWindow", "pPicture.pNext"));
        if (pPicture.id)
            FreeResource(cast(uint)pPicture.id, PictureType);
        FreePicture(cast(void*) pPicture, pPicture.id);
    }
}

private void PictureScreenClose(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    int n = void;

    PictureResetFilters(pScreen);
    for (n = 0; n < ps.nformats; n++)
        if (ps.formats[n].type == PictTypeIndexed)
            (*ps.CloseIndexed) (pScreen, &ps.formats[n]);
    GlyphUninit(pScreen);
    mixin(SetPictureScreen!("pScreen", "null"));
    free(ps.formats);
    free(ps);
    dixScreenUnhookPostClose(pScreen, &PictureScreenClose);
}

private void PictureStoreColors(ColormapPtr pColormap, int ndef, xColorItem* pdef)
{
    ScreenPtr pScreen = pColormap.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    pScreen.StoreColors = ps.StoreColors;
    (*pScreen.StoreColors) (pColormap, ndef, pdef);
    ps.StoreColors = pScreen.StoreColors;
    pScreen.StoreColors = &PictureStoreColors;

    if (pColormap.class_ == PseudoColor || pColormap.class_ == GrayScale) {
        PictFormatPtr format = ps.formats;
        int nformats = ps.nformats;

        while (nformats--) {
            if (format.type == PictTypeIndexed &&
                format.index.pColormap == pColormap) {
                (*ps.UpdateIndexed) (pScreen, format, ndef, pdef);
                break;
            }
            format++;
        }
    }
}

private int visualDepth(ScreenPtr pScreen, VisualPtr pVisual)
{
    int d = void, v = void;
    DepthPtr pDepth = void;

    for (d = 0; d < pScreen.numDepths; d++) {
        pDepth = &pScreen.allowedDepths[d];
        for (v = 0; v < pDepth.numVids; v++)
            if (pDepth.vids[v] == pVisual.vid)
                return pDepth.depth;
    }
    return 0;
}

struct _formatInit {
    CARD32 format;
    CARD8 depth;
}alias FormatInitRec = _formatInit;
alias FormatInitPtr = _formatInit*;

private void addFormat(FormatInitRec* formats, int* nformat, CARD32 format, CARD8 depth)
{
    int n = void;

    for (n = 0; n < *nformat; n++)
        if (formats[n].format == format && formats[n].depth == depth)
            return;
    formats[*nformat].format = format;
    formats[*nformat].depth = depth;
    ++*nformat;
}

// enum string Mask(string n) = `((1 << (` ~ n ~ `)) - 1)`;

private PictFormatPtr PictureCreateDefaultFormats(ScreenPtr pScreen, int* nformatp)
{
    int nformats = 0, f = void;
    PictFormatPtr pFormats = void;
    FormatInitRec[1024] formats = void;
    CARD32 format = void;
    CARD8 depth = void;
    VisualPtr pVisual = void;
    int v = void;
    int bpp = void;
    int type = void;
    int r = void, g = void, b = void;
    int d = void;
    DepthPtr pDepth = void;

    nformats = 0;
    /* formats required by protocol */
    formats[nformats].format = PIXMAN_a1;
    formats[nformats].depth = 1;
    nformats++;
    formats[nformats].format = mixin(PIXMAN_FORMAT!(BitsPerPixel!("8"),
                                           "PIXMAN_TYPE_A", "8", "0", "0", "0"));
    formats[nformats].depth = 8;
    nformats++;
    formats[nformats].format = PIXMAN_a8r8g8b8;
    formats[nformats].depth = 32;
    nformats++;
    formats[nformats].format = PIXMAN_x8r8g8b8;
    formats[nformats].depth = 32;
    nformats++;
    formats[nformats].format = PIXMAN_b8g8r8a8;
    formats[nformats].depth = 32;
    nformats++;
    formats[nformats].format = PIXMAN_b8g8r8x8;
    formats[nformats].depth = 32;
    nformats++;

    /* now look through the depths and visuals adding other formats */
    for (v = 0; v < pScreen.numVisuals; v++) {
        pVisual = &pScreen.visuals[v];
        depth = cast(ubyte)visualDepth(pScreen, pVisual);
        if (!depth)
            continue;
        bpp = mixin(BitsPerPixel!("depth"));
        switch (pVisual.class_) {
        case DirectColor:
        case TrueColor:
            r = Ones(pVisual.redMask);
            g = Ones(pVisual.greenMask);
            b = Ones(pVisual.blueMask);
            type = PIXMAN_TYPE_OTHER;
            /*
             * Current rendering code supports only three direct formats,
             * fields must be packed together at the bottom of the pixel
             */
            if (pVisual.offsetBlue == 0 &&
                pVisual.offsetGreen == b && pVisual.offsetRed == b + g) {
                type = PIXMAN_TYPE_ARGB;
            }
            else if (pVisual.offsetRed == 0 &&
                     pVisual.offsetGreen == r &&
                     pVisual.offsetBlue == r + g) {
                type = PIXMAN_TYPE_ABGR;
            }
            else if (pVisual.offsetRed == pVisual.offsetGreen - r &&
                     pVisual.offsetGreen == pVisual.offsetBlue - g &&
                     pVisual.offsetBlue == bpp - b) {
                type = PIXMAN_TYPE_BGRA;
            }
            if (type != PIXMAN_TYPE_OTHER) {
                format = PIXMAN_FORMAT(bpp, type, 0, r, g, b);
                addFormat(formats.ptr, &nformats, format, depth);
            }
            break;
        case StaticColor:
        case PseudoColor:
            format = mixin(PICT_VISFORMAT!("bpp", "PIXMAN_TYPE_COLOR", "v"));
            addFormat(formats.ptr, &nformats, format, depth);
            break;
        case StaticGray:
        case GrayScale:
            format = mixin(PICT_VISFORMAT!("bpp", "PIXMAN_TYPE_GRAY", "v"));
            addFormat(formats.ptr, &nformats, format, depth);
            break;
        default: break;}
    }
    /*
     * Walk supported depths and add useful Direct formats
     */
    for (d = 0; d < pScreen.numDepths; d++) {
        pDepth = &pScreen.allowedDepths[d];
        bpp = mixin(BitsPerPixel!("pDepth.depth"));
        format = 0;
        switch (bpp) {
        case 16:
            /* depth 12 formats */
            if (pDepth.depth >= 12) {
                addFormat(formats.ptr, &nformats, PIXMAN_x4r4g4b4, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_x4b4g4r4, pDepth.depth);
            }
            /* depth 15 formats */
            if (pDepth.depth >= 15) {
                addFormat(formats.ptr, &nformats, PIXMAN_x1r5g5b5, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_x1b5g5r5, pDepth.depth);
            }
            /* depth 16 formats */
            if (pDepth.depth >= 16) {
                addFormat(formats.ptr, &nformats, PIXMAN_a1r5g5b5, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_a1b5g5r5, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_r5g6b5, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_b5g6r5, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_a4r4g4b4, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_a4b4g4r4, pDepth.depth);
            }
            break;
        case 32:
            if (pDepth.depth >= 24) {
                addFormat(formats.ptr, &nformats, PIXMAN_x8r8g8b8, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_x8b8g8r8, pDepth.depth);
            }
            if (pDepth.depth >= 30) {
                addFormat(formats.ptr, &nformats, PIXMAN_a2r10g10b10, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_x2r10g10b10, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_a2b10g10r10, pDepth.depth);
                addFormat(formats.ptr, &nformats, PIXMAN_x2b10g10r10, pDepth.depth);
            }
            break;
        default: break;}
    }

    pFormats = cast(_PictFormat*)calloc(nformats, PictFormatRec.sizeof);
    if (!pFormats)
        return null;
    for (f = 0; f < nformats; f++) {
        pFormats[f].id = cast(uint)dixAllocServerXID();
        pFormats[f].depth = formats[f].depth;
        format = formats[f].format;
        pFormats[f].format = format;
        switch (PIXMAN_FORMAT_TYPE(format)) {
        case PIXMAN_TYPE_ARGB:
            pFormats[f].type = PictTypeDirect;

            pFormats[f].direct.alphaMask = cast(ushort)mixin(MaskT!(PIXMAN_FORMAT_A!("format")));

            if (pFormats[f].direct.alphaMask)
                pFormats[f].direct.alpha = cast(ushort)cast(ushort)(mixin(PIXMAN_FORMAT_R!("format")) +
                                            mixin(PIXMAN_FORMAT_G!("format")) +
                                            mixin(PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.redMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.red = cast(ushort)(mixin(PIXMAN_FORMAT_G!("format")) +
                                      mixin(PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.greenMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_G!("format")));

            pFormats[f].direct.green = cast(ushort)mixin(PIXMAN_FORMAT_B!("format"));

            pFormats[f].direct.blueMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.blue = cast(ushort)0;
            break;

        case PIXMAN_TYPE_ABGR:
            pFormats[f].type = PictTypeDirect;

            pFormats[f].direct.alphaMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_A!("format")));

            if (pFormats[f].direct.alphaMask)
                pFormats[f].direct.alpha = cast(ushort)(mixin(PIXMAN_FORMAT_B!("format")) +
                                            mixin(PIXMAN_FORMAT_G!("format")) +
                                            mixin(PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.blueMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.blue = cast(ushort)(mixin(PIXMAN_FORMAT_G!("format")) +
                                       mixin(PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.greenMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_G!("format")));

            pFormats[f].direct.green = cast(ushort)mixin(PIXMAN_FORMAT_R!("format"));

            pFormats[f].direct.redMask = cast(ushort)mixin(MaskT! (PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.red = cast(ushort)0;
            break;

        case PIXMAN_TYPE_BGRA:
            pFormats[f].type = PictTypeDirect;

            pFormats[f].direct.blueMask = cast(ushort) mixin(MaskT! (PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.blue = cast(ushort)
                (mixin(PIXMAN_FORMAT_BPP!("format")) - mixin(PIXMAN_FORMAT_B!("format")));

            pFormats[f].direct.greenMask = cast(ushort) mixin(MaskT! (PIXMAN_FORMAT_G!("format")));

            pFormats[f].direct.green = cast(ushort)
                (mixin(PIXMAN_FORMAT_BPP!("format")) - mixin(PIXMAN_FORMAT_B!("format")) -
                 mixin(PIXMAN_FORMAT_G!("format")));

            pFormats[f].direct.redMask = cast(ushort) mixin(MaskT! (PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.red = cast(ushort)
                (mixin(PIXMAN_FORMAT_BPP!("format")) - mixin(PIXMAN_FORMAT_B!("format")) -
                 mixin(PIXMAN_FORMAT_G!("format")) - mixin(PIXMAN_FORMAT_R!("format")));

            pFormats[f].direct.alphaMask = cast(ushort) mixin(MaskT! (PIXMAN_FORMAT_A!("format")));

            pFormats[f].direct.alpha = 0;
            break;

        case PIXMAN_TYPE_A:
            pFormats[f].type = PictTypeDirect;

            pFormats[f].direct.alpha = cast(ushort) 0;
            pFormats[f].direct.alphaMask = cast(ushort) mixin(MaskT! (`PIXMAN_FORMAT_A(format)`));

            /* remaining fields already set to zero */
            break;

        case PIXMAN_TYPE_COLOR:
        case PIXMAN_TYPE_GRAY:
            pFormats[f].type = PictTypeIndexed;
            pFormats[f].index.vid =
                pScreen.visuals[PIXMAN_FORMAT_VIS(format)].vid;
            break;
        default: break;}
    }
    *nformatp = nformats;
    return pFormats;
}

private VisualPtr PictureFindVisual(ScreenPtr pScreen, VisualID visual)
{
    int i = void;
    VisualPtr pVisual = void;

    for (i = 0, pVisual = pScreen.visuals;
         i < pScreen.numVisuals; i++, pVisual++) {
        if (pVisual.vid == visual)
            return pVisual;
    }
    return null;
}

private Bool PictureInitIndexedFormat(ScreenPtr pScreen, PictFormatPtr format)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));

    if (format.type != PictTypeIndexed || format.index.pColormap)
        return TRUE;

    if (format.index.vid == pScreen.rootVisual) {
        dixLookupResourceByType(cast(void**) &format.index.pColormap,
                                cast(uint)pScreen.defColormap, X11_RESTYPE_COLORMAP,
                                serverClient, DixGetAttrAccess);
    }
    else {
        VisualPtr pVisual = PictureFindVisual(pScreen, format.index.vid);

        if (pVisual is null)
            return FALSE;

        if (dixCreateColormap(dixAllocServerXID(), pScreen, pVisual,
                              &format.index.pColormap, AllocNone, null)
            != Success)
            return FALSE;
    }
    if (!ps.InitIndexed(pScreen, format))
        return FALSE;
    return TRUE;
}

private Bool PictureInitIndexedFormats(ScreenPtr pScreen)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));
    PictFormatPtr format = void;
    int nformat = void;

    if (!ps)
        return FALSE;
    format = ps.formats;
    nformat = ps.nformats;
    while (nformat--)
        if (!PictureInitIndexedFormat(pScreen, format++))
            return FALSE;
    return TRUE;
}

Bool PictureFinishInit()
{
    for (uint walkScreenIdx = 0; walkScreenIdx < screenInfo.numScreens; walkScreenIdx++) {
        ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx];
        if (!PictureInitIndexedFormats(walkScreen))
            return FALSE;
        cast(void) AnimCurInit(walkScreen);
    }

    return TRUE;
}

Bool PictureSetSubpixelOrder(ScreenPtr pScreen, int subpixel)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));

    if (!ps)
        return FALSE;
    ps.subpixel = subpixel;
    return TRUE;

}

int PictureGetSubpixelOrder(ScreenPtr pScreen)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));

    if (!ps)
        return SubPixelUnknown;
    return ps.subpixel;
}

PictFormatPtr PictureMatchVisual(ScreenPtr pScreen, int depth, VisualPtr pVisual)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));
    PictFormatPtr format = void;
    int nformat = void;
    int type = void;

    if (!ps)
        return null;
    format = ps.formats;
    nformat = ps.nformats;
    switch (pVisual.class_) {
    case StaticGray:
    case GrayScale:
    case StaticColor:
    case PseudoColor:
        type = PictTypeIndexed;
        break;
    case TrueColor:
    case DirectColor:
        type = PictTypeDirect;
        break;
    default:
        return null;
    }
    while (nformat--) {
        if (format.depth == depth && format.type == type) {
            if (type == PictTypeIndexed) {
                if (format.index.vid == pVisual.vid)
                    return format;
            }
            else {
                if (cast(c_ulong)format.direct.redMask <<
                        format.direct.red == pVisual.redMask &&
                    cast(c_ulong)format.direct.greenMask <<
                        format.direct.green == pVisual.greenMask &&
                    cast(c_ulong)format.direct.blueMask <<
                        format.direct.blue == pVisual.blueMask) {
                    return format;
                }
            }
        }
        format++;
    }
    return null;
}

PictFormatPtr PictureMatchFormat(ScreenPtr pScreen, int depth, CARD32 f)
{
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));
    PictFormatPtr format = void;
    int nformat = void;

    if (!ps)
        return null;
    format = ps.formats;
    nformat = ps.nformats;
    while (nformat--) {
        if (format.depth == depth && format.format == (f & 0xffffff))
            return format;
        format++;
    }
    return null;
}

int PictureParseCmapPolicy(const(char)* name)
{
    if (strcmp(name, "default") == 0)
        return PictureCmapPolicyDefault;
    else if (strcmp(name, "mono") == 0)
        return PictureCmapPolicyMono;
    else if (strcmp(name, "gray") == 0)
        return PictureCmapPolicyGray;
    else if (strcmp(name, "color") == 0)
        return PictureCmapPolicyColor;
    else if (strcmp(name, "all") == 0)
        return PictureCmapPolicyAll;
    else
        return PictureCmapPolicyInvalid;
}

/** @see GetDefaultBytes */
private void GetPictureBytes(void* value, XID id, ResourceSizePtr size)
{
    PicturePtr picture = cast(PicturePtr)value;

    /* Currently only pixmap bytes are reported to clients. */
    size.resourceSize = 0;

    size.refCnt = picture.refcnt;

    /* Calculate pixmap reference sizes. */
    size.pixmapRefSize = 0;
    if (picture.pDrawable && (picture.pDrawable.type == DRAWABLE_PIXMAP))
    {
        SizeType pixmapSizeFunc = GetResourceTypeSizeFunc(X11_RESTYPE_PIXMAP);
        ResourceSizeRec pixmapSize = { 0, 0, 0 };
        PixmapPtr pixmap = cast(PixmapPtr)picture.pDrawable;
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
}

private int FreePictFormat(void* pPictFormat, XID pid)
{
    return Success;
}

private bool picture_resources_initialized = false;

Bool PictureInit(ScreenPtr pScreen, PictFormatPtr formats, int nformats)
{
    int n = void;
    CARD32 type = void, a = void, r = void, g = void, b = void;

    if (!picture_resources_initialized)
    {
        PictureType = CreateNewResourceType(&FreePicture, "PICTURE");
        if (!PictureType)
            return FALSE;
        SetResourceTypeSizeFunc(PictureType, &GetPictureBytes);
        PictFormatType = CreateNewResourceType(&FreePictFormat, "PICTFORMAT");
        if (!PictFormatType)
            return FALSE;
        GlyphSetType = CreateNewResourceType(&FreeGlyphSet, "GLYPHSET");
        if (!GlyphSetType)
            return FALSE;
        picture_resources_initialized = true;
    }
    if (!dixRegisterPrivateKey(&PictureScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&PictureWindowPrivateKeyRec, PRIVATE_WINDOW, 0))
        return FALSE;

    if (!formats) {
        formats = PictureCreateDefaultFormats(pScreen, &nformats);
        if (!formats)
            return FALSE;
    }
    for (n = 0; n < nformats; n++) {
        if (!AddResource
            (formats[n].id, PictFormatType, cast(void*) (formats + n))) {
            int i = void;
            for (i = 0; i < n; i++)
                FreeResource(cast(uint)formats[i].id, X11_RESTYPE_NONE);
            free(formats);
            return FALSE;
        }
        if (formats[n].type == PictTypeIndexed) {
            VisualPtr pVisual = PictureFindVisual(pScreen, formats[n].index.vid);
            if ((pVisual.class_ | DynamicClass) == PseudoColor)
                type = PIXMAN_TYPE_COLOR;
            else
                type = PIXMAN_TYPE_GRAY;
            a = r = g = b = 0;
        }
        else {
            if ((formats[n].direct.redMask |
                 formats[n].direct.blueMask | formats[n].direct.greenMask) == 0)
                type = PIXMAN_TYPE_A;
            else if (formats[n].direct.red > formats[n].direct.blue)
                type = PIXMAN_TYPE_ARGB;
            else if (formats[n].direct.red == 0)
                type = PIXMAN_TYPE_ABGR;
            else
                type = PIXMAN_TYPE_BGRA;
            a = Ones(formats[n].direct.alphaMask);
            r = Ones(formats[n].direct.redMask);
            g = Ones(formats[n].direct.greenMask);
            b = Ones(formats[n].direct.blueMask);
        }
        formats[n].format = PIXMAN_FORMAT(0, type, a, r, g, b);
    }
    PictureScreenPtr ps = cast(PictureScreenRec*) calloc(1, PictureScreenRec.sizeof);
    if (!ps) {
        free(formats);
        return FALSE;
    }
    mixin(SetPictureScreen!("pScreen", "ps"));

    ps.formats = formats;
    ps.fallback = formats;
    ps.nformats = nformats;

    ps.filters = null;
    ps.nfilters = 0;
    ps.filterAliases = null;
    ps.nfilterAliases = 0;

    ps.subpixel = SubPixelUnknown;

    ps.StoreColors = pScreen.StoreColors;
    pScreen.StoreColors = &PictureStoreColors;

    dixScreenHookWindowDestroy(pScreen, &picture_window_destructor);
    dixScreenHookPostClose(pScreen, &PictureScreenClose);

    if (!PictureSetDefaultFilters(pScreen)) {
        PictureResetFilters(pScreen);
        mixin(SetPictureScreen!("pScreen", "null"));
        free(formats);
        free(ps);
        return FALSE;
    }

    return TRUE;
}

private void SetPictureToDefaults(PicturePtr pPicture)
{
    pPicture.refcnt = 1;
    pPicture.repeat = 0;
    pPicture.graphicsExposures = FALSE;
    pPicture.subWindowMode = ClipByChildren;
    pPicture.polyEdge = PolyEdgeSharp;
    pPicture.polyMode = PolyModePrecise;
    pPicture.freeCompClip = FALSE;
    pPicture.componentAlpha = FALSE;
    pPicture.repeatType = RepeatNone;

    pPicture.alphaMap = null;
    pPicture.alphaOrigin.x = 0;
    pPicture.alphaOrigin.y = 0;

    pPicture.clipOrigin.x = 0;
    pPicture.clipOrigin.y = 0;
    pPicture.clientClip = null;

    pPicture.transform = null;

    pPicture.filter = PictureGetFilterId(FilterNearest, -1, TRUE);
    pPicture.filter_params = null;
    pPicture.filter_nparams = 0;

    pPicture.serialNumber = GC_CHANGE_SERIAL_BIT;
    pPicture.stateChanges = -1;
    pPicture.pSourcePict = null;
}

PicturePtr CreatePicture(Picture pid, DrawablePtr pDrawable, PictFormatPtr pFormat, Mask vmask, XID* vlist, ClientPtr client, int* error)
{
    PicturePtr pPicture = void;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDrawable.pScreen"));

    pPicture = cast(_Picture*)mixin(dixAllocateScreenObjectWithPrivates!("pDrawable.pScreen",
                                                   "PictureRec", "PRIVATE_PICTURE"));
    if (!pPicture) {
        *error = BadAlloc;
        return null;
    }

    pPicture.id = cast(uint)pid;
    pPicture.pDrawable = pDrawable;
    pPicture.pFormat = pFormat;
    pPicture.format = cast(pixman_format_code_t)(pFormat.format | (pDrawable.bitsPerPixel << 24));

    /* security creation/labeling check */
    *error = XaceHookResourceAccess(client, pid, PictureType, pPicture,
                      X11_RESTYPE_PIXMAP, pDrawable, DixCreateAccess | DixSetAttrAccess);
    if (*error != Success)
        goto out_;

    if (pDrawable.type == DRAWABLE_PIXMAP) {
        ++(cast(PixmapPtr) pDrawable).refcnt;
        pPicture.pNext = null;
    }
    else {
        pPicture.pNext = mixin(GetPictureWindow!("(cast(WindowPtr) pDrawable)"));
        mixin(SetPictureWindow!("(cast(WindowPtr) pDrawable)", "pPicture"));
    }

    SetPictureToDefaults(pPicture);

    if (vmask)
        *error = ChangePicture(pPicture, vmask, vlist, null, client);
    else
        *error = Success;
    if (*error == Success)
        *error = (*ps.CreatePicture) (pPicture);
 out_:
    if (*error != Success) {
        FreePicture(pPicture, cast(XID) 0);
        pPicture = null;
    }
    return pPicture;
}

private CARD32 xRenderColorToCard32(xRenderColor c)
{
    return
        (cast(uint)c.alpha >> 8 << 24) |
        (cast(uint)c.red >> 8 << 16) |
        (cast(uint)c.green & 0xff00) |
        (cast(uint)c.blue >> 8);
}

private void initGradient(SourcePictPtr pGradient, int stopCount, XFixed* stopPoints, xRenderColor* stopColors, int* error)
{
    int i = void;
    XFixed dpos = void;

    if (stopCount <= 0) {
        *error = BadValue;
        return;
    }

    dpos = -1;
    for (i = 0; i < stopCount; ++i) {
        if (stopPoints[i] < dpos || stopPoints[i] > (1 << 16)) {
            *error = BadValue;
            return;
        }
        dpos = stopPoints[i];
    }

    pGradient.gradient.stops = cast(_PictGradientStop*)calloc(stopCount, PictGradientStop.sizeof);
    if (!pGradient.gradient.stops) {
        *error = BadAlloc;
        return;
    }

    pGradient.gradient.nstops = stopCount;

    for (i = 0; i < stopCount; ++i) {
        pGradient.gradient.stops[i].x = stopPoints[i];
        pGradient.gradient.stops[i].color = stopColors[i];
    }
}

private PicturePtr createSourcePicture()
{
    PicturePtr pPicture = void;

    pPicture = cast(PicturePtr)mixin(dixAllocateScreenObjectWithPrivates!("null", "PictureRec",
                                                   "PRIVATE_PICTURE"));
    if (!pPicture)
	return null;

    pPicture.pDrawable = null;
    pPicture.pFormat = null;
    pPicture.pNext = null;
    pPicture.format = PIXMAN_a8r8g8b8;

    SetPictureToDefaults(pPicture);
    return pPicture;
}

PicturePtr CreateSolidPicture(Picture pid, xRenderColor* color, int* error)
{
    PicturePtr pPicture = void;

    pPicture = createSourcePicture();
    if (!pPicture) {
        *error = BadAlloc;
        return null;
    }

    pPicture.id = cast(uint)pid;
    pPicture.pSourcePict = cast(SourcePict*) calloc(1, SourcePict.sizeof);
    if (!pPicture.pSourcePict) {
        *error = BadAlloc;
        free(pPicture);
        return null;
    }
    pPicture.pSourcePict.type = SourcePictTypeSolidFill;
    pPicture.pSourcePict.solidFill.color = xRenderColorToCard32(*color);
    memcpy(&pPicture.pSourcePict.solidFill.fullcolor, color, typeof(*color).sizeof);
    return pPicture;
}

PicturePtr CreateLinearGradientPicture(Picture pid, xPointFixed* p1, xPointFixed* p2, int nStops, XFixed* stops, xRenderColor* colors, int* error)
{
    PicturePtr pPicture = void;

    if (nStops < 1) {
        *error = BadValue;
        return null;
    }

    pPicture = createSourcePicture();
    if (!pPicture) {
        *error = BadAlloc;
        return null;
    }

    pPicture.id = cast(uint)pid;
    pPicture.pSourcePict = cast(SourcePict*) calloc(1, SourcePict.sizeof);
    if (!pPicture.pSourcePict) {
        *error = BadAlloc;
        free(pPicture);
        return null;
    }

    pPicture.pSourcePict.linear.type = SourcePictTypeLinear;
    pPicture.pSourcePict.linear.p1 = *p1;
    pPicture.pSourcePict.linear.p2 = *p2;

    initGradient(pPicture.pSourcePict, nStops, stops, colors, error);
    if (*error) {
        free(pPicture.pSourcePict);
        free(pPicture);
        return null;
    }
    return pPicture;
}

PicturePtr CreateRadialGradientPicture(Picture pid, xPointFixed* inner, xPointFixed* outer, XFixed innerRadius, XFixed outerRadius, int nStops, XFixed* stops, xRenderColor* colors, int* error)
{
    PicturePtr pPicture = void;
    PictRadialGradient* radial = void;

    if (nStops < 1) {
        *error = BadValue;
        return null;
    }

    pPicture = createSourcePicture();
    if (!pPicture) {
        *error = BadAlloc;
        return null;
    }

    pPicture.id = cast(uint)pid;
    pPicture.pSourcePict = cast(SourcePict*) calloc(1, SourcePict.sizeof);
    if (!pPicture.pSourcePict) {
        *error = BadAlloc;
        free(pPicture);
        return null;
    }
    radial = &pPicture.pSourcePict.radial;

    radial.type = SourcePictTypeRadial;
    radial.c1.x = cast(int)inner.x;
    radial.c1.y = cast(int)inner.y;
    radial.c1.radius = innerRadius;
    radial.c2.x = cast(int)outer.x;
    radial.c2.y = cast(int)outer.y;
    radial.c2.radius = outerRadius;

    initGradient(pPicture.pSourcePict, nStops, stops, colors, error);
    if (*error) {
        free(pPicture.pSourcePict);
        free(pPicture);
        return null;
    }
    return pPicture;
}

PicturePtr CreateConicalGradientPicture(Picture pid, xPointFixed* center, XFixed angle, int nStops, XFixed* stops, xRenderColor* colors, int* error)
{
    PicturePtr pPicture = void;

    if (nStops < 1) {
        *error = BadValue;
        return null;
    }

    pPicture = createSourcePicture();
    if (!pPicture) {
        *error = BadAlloc;
        return null;
    }

    pPicture.id = cast(uint)pid;
    pPicture.pSourcePict = cast(SourcePict*) calloc(1, SourcePict.sizeof);
    if (!pPicture.pSourcePict) {
        *error = BadAlloc;
        free(pPicture);
        return null;
    }

    pPicture.pSourcePict.conical.type = SourcePictTypeConical;
    pPicture.pSourcePict.conical.center = *center;
    pPicture.pSourcePict.conical.angle = angle;

    initGradient(pPicture.pSourcePict, nStops, stops, colors, error);
    if (*error) {
        free(pPicture.pSourcePict);
        free(pPicture);
        return null;
    }
    return pPicture;
}

private int cpAlphaMap(void** result, XID id, ScreenPtr screen, ClientPtr client, Mask mode)
{
static if(XINERAMA){
    if (!noPanoramiXExtension) {
        PanoramiXRes* res = void;
        int err = dixLookupResourceByType(cast(void**)&res, id, XRT_PICTURE,
                                          client, mode);
        if (err != Success)
            return err;
        if (screen is null)
            LogMessage(X_WARNING, "cpAlphaMap() screen == NULL\n");
        else
            id = res.info[screen.myNum].id;
    }
} /* XINERAMA */
    return dixLookupResourceByType(result, id, PictureType, client, mode);
}

private int cpClipMask(void** result, XID id, ScreenPtr screen, ClientPtr client, Mask mode)
{
static if(XINERAMA){
    if (!noPanoramiXExtension) {
        PanoramiXRes* res = void;
        int err = dixLookupResourceByType(cast(void**)&res, id, XRT_PIXMAP,
                                          client, mode);
        if (err != Success)
            return err;
        id = res.info[screen.myNum].id;
    }
} /* XINERAMA */
    return dixLookupResourceByType(result, id, X11_RESTYPE_PIXMAP, client, mode);
}

enum string NEXT_VAL(string _type) = `(vlist ? cast(` ~ _type ~ `) (*vlist)++ : cast(`~_type~`) ulist++.val)`;

enum string NEXT_PTR(string _type) = `(cast(`~_type~`) ulist++.ptr)`;

int ChangePicture(PicturePtr pPicture, Mask vmask, XID* vlist, DevUnion* ulist, ClientPtr client)
{
    ScreenPtr pScreen = pPicture.pDrawable ? pPicture.pDrawable.pScreen : null;
    PictureScreenPtr ps = pScreen ? mixin(GetPictureScreen!("pScreen")) : null;
    BITS32 index2 = void;
    int error = 0;
    BITS32 maskQ = void;

    pPicture.serialNumber |= GC_CHANGE_SERIAL_BIT;
    maskQ = cast(uint)vmask;
    while (vmask && !error) {
        index2 = cast(BITS32) mixin(lowbit!vmask);
        vmask &= ~index2;
        pPicture.stateChanges |= index2;
        switch (index2) {
        case CPRepeat:
        {
            uint newr = void;
            newr = mixin(NEXT_VAL!(`uint`));

            if (newr <= RepeatReflect) {
                pPicture.repeat = (newr != RepeatNone);
                pPicture.repeatType = newr;
            }
            else {
                client.errorValue = cast(uint)newr;
                error = BadValue;
            }
        }
            break;
        case CPAlphaMap:
        {
            PicturePtr pAlpha = void;

            if (vlist) {
                Picture pid = mixin(NEXT_VAL!(`Picture`));

                if (pid == None)
                    pAlpha = null;
                else {
                    error = cpAlphaMap(cast(void**) &pAlpha, pid, pScreen,
                                       client, DixReadAccess);
                    if (error != Success) {
                        client.errorValue = cast(uint)pid;
                        break;
                    }
                    if (pAlpha.pDrawable is null ||
                        pAlpha.pDrawable.type != DRAWABLE_PIXMAP) {
                        client.errorValue = cast(uint)pid;
                        error = BadMatch;
                        break;
                    }
                }
            }
            else
                pAlpha = mixin(NEXT_PTR!(`PicturePtr`));
            if (!error) {
                if (pAlpha && pAlpha.pDrawable.type == DRAWABLE_PIXMAP)
                    pAlpha.refcnt++;
                if (pPicture.alphaMap)
                    FreePicture(cast(void*) pPicture.alphaMap, cast(XID) 0);
                pPicture.alphaMap = pAlpha;
            }
        }
            break;
        case CPAlphaXOrigin:
            pPicture.alphaOrigin.x = mixin(NEXT_VAL!(`INT16`));

            break;
        case CPAlphaYOrigin:
            pPicture.alphaOrigin.y = mixin(NEXT_VAL!(`INT16`));

            break;
        case CPClipXOrigin:
            pPicture.clipOrigin.x = mixin(NEXT_VAL!(`INT16`));

            break;
        case CPClipYOrigin:
            pPicture.clipOrigin.y = mixin(NEXT_VAL!(`INT16`));

            break;
        case CPClipMask:
        {
            Pixmap pid = void;
            PixmapPtr pPixmap = void;
            int clipType = void;

            if (!pScreen)
                return BadDrawable;

            if (vlist) {
                pid = mixin(NEXT_VAL!(`Pixmap`));
                if (pid == None) {
                    clipType = CT_NONE;
                    pPixmap = NullPixmap;
                }
                else {
                    clipType = CT_PIXMAP;
                    error = cpClipMask(cast(void**) &pPixmap, pid, pScreen,
                                       client, DixReadAccess);
                    if (error != Success) {
                        client.errorValue = cast(uint)pid;
                        break;
                    }
                }
            }
            else {
                pPixmap = mixin(NEXT_PTR!(`PixmapPtr`));

                if (pPixmap)
                    clipType = CT_PIXMAP;
                else
                    clipType = CT_NONE;
            }

            if (pPixmap) {
                if ((pPixmap.drawable.depth != 1) ||
                    (pPixmap.drawable.pScreen != pScreen)) {
                    error = BadMatch;
                    break;
                }
                else {
                    clipType = CT_PIXMAP;
                    pPixmap.refcnt++;
                }
            }
            error = (*ps.ChangePictureClip) (pPicture, clipType,
                                              cast(void*) pPixmap, 0);
            break;
        }
        case CPGraphicsExposure:
        {
            uint newe = void;
            newe = mixin(NEXT_VAL!(`uint`));

            if (newe <= xTrue)
                pPicture.graphicsExposures = newe;
            else {
                client.errorValue = cast(uint)newe;
                error = BadValue;
            }
        }
            break;
        case CPSubwindowMode:
        {
            uint news = void;
            news = mixin(NEXT_VAL!(`uint`));

            if (news == ClipByChildren || news == IncludeInferiors)
                pPicture.subWindowMode = news;
            else {
                client.errorValue = cast(uint)news;
                error = BadValue;
            }
        }
            break;
        case CPPolyEdge:
        {
            uint newe = void;
            newe = mixin(NEXT_VAL!(`uint`));

            if (newe == PolyEdgeSharp || newe == PolyEdgeSmooth)
                pPicture.polyEdge = newe;
            else {
                client.errorValue = cast(uint)newe;
                error = BadValue;
            }
        }
            break;
        case CPPolyMode:
        {
            uint newm = void;
            newm = mixin(NEXT_VAL!(`uint`));

            if (newm == PolyModePrecise || newm == PolyModeImprecise)
                pPicture.polyMode = newm;
            else {
                client.errorValue = cast(uint)newm;
                error = BadValue;
            }
        }
            break;
        case CPDither:
            cast(void) mixin(NEXT_VAL!(`Atom`));      /* unimplemented */

            break;
        case CPComponentAlpha:
        {
            uint newca = void;

            newca = mixin(NEXT_VAL!(`uint`));

            if (newca <= xTrue)
                pPicture.componentAlpha = newca;
            else {
                client.errorValue = cast(uint)newca;
                error = BadValue;
            }
        }
            break;
        default:
            client.errorValue = cast(uint)maskQ;
            error = BadValue;
            break;
        }
    }
    if (ps)
        (*ps.ChangePicture) (pPicture, maskQ);
    return error;
}

int SetPictureClipRects(PicturePtr pPicture, int xOrigin, int yOrigin, int nRect, xRectangle* rects)
{
    ScreenPtr pScreen = pPicture.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    RegionPtr clientClip = void;
    int result = void;

    clientClip = RegionFromRects(nRect, rects, CT_UNSORTED);
    if (!clientClip)
        return BadAlloc;
    result = (*ps.ChangePictureClip) (pPicture, CT_REGION,
                                       cast(void*) clientClip, 0);
    if (result == Success) {
        pPicture.clipOrigin.x = cast(short)xOrigin;
        pPicture.clipOrigin.y = cast(short)yOrigin;
        pPicture.stateChanges |= CPClipXOrigin | CPClipYOrigin | CPClipMask;
        pPicture.serialNumber |= GC_CHANGE_SERIAL_BIT;
    }
    return result;
}

int SetPictureClipRegion(PicturePtr pPicture, int xOrigin, int yOrigin, RegionPtr pRegion)
{
    ScreenPtr pScreen = pPicture.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    RegionPtr clientClip = void;
    int result = void;
    int type = void;

    if (pRegion) {
        type = CT_REGION;
        clientClip = RegionCreate(RegionExtents(pRegion),
                                  RegionNumRects(pRegion));
        if (!clientClip)
            return BadAlloc;
        if (!RegionCopy(clientClip, pRegion)) {
            RegionDestroy(clientClip);
            return BadAlloc;
        }
    }
    else {
        type = CT_NONE;
        clientClip = null;
    }

    result = (*ps.ChangePictureClip) (pPicture, type, cast(void*) clientClip, 0);
    if (result == Success) {
        pPicture.clipOrigin.x = cast(short)xOrigin;
        pPicture.clipOrigin.y = cast(short)yOrigin;
        pPicture.stateChanges |= CPClipXOrigin | CPClipYOrigin | CPClipMask;
        pPicture.serialNumber |= GC_CHANGE_SERIAL_BIT;
    }
    return result;
}

private Bool transformIsIdentity(PictTransform* t)
{
    return ((t.matrix[0][0] == t.matrix[1][1]) &&
            (t.matrix[0][0] == t.matrix[2][2]) &&
            (t.matrix[0][0] != 0) &&
            (t.matrix[0][1] == 0) &&
            (t.matrix[0][2] == 0) &&
            (t.matrix[1][0] == 0) &&
            (t.matrix[1][2] == 0) &&
            (t.matrix[2][0] == 0) && (t.matrix[2][1] == 0));
}

int SetPictureTransform(PicturePtr pPicture, PictTransform* transform)
{
    if (transform && transformIsIdentity(transform))
        transform = null;

    if (transform) {
        if (!pPicture.transform) {
            pPicture.transform = cast(PictTransform*) calloc(1, PictTransform.sizeof);
            if (!pPicture.transform)
                return BadAlloc;
        }
        *pPicture.transform = *transform;
    }
    else {
        free(pPicture.transform);
        pPicture.transform = null;
    }
    pPicture.serialNumber |= GC_CHANGE_SERIAL_BIT;

    if (pPicture.pDrawable !is null) {
        int result = void;
        PictureScreenPtr ps = mixin(GetPictureScreen!("pPicture.pDrawable.pScreen"));

        result = (*ps.ChangePictureTransform) (pPicture, transform);

        return result;
    }

    return Success;
}

private void ValidateOnePicture(PicturePtr pPicture)
{
    if (pPicture.pDrawable &&
        pPicture.serialNumber != pPicture.pDrawable.serialNumber) {
        PictureScreenPtr ps = mixin(GetPictureScreen!("pPicture.pDrawable.pScreen"));

        (*ps.ValidatePicture) (pPicture, pPicture.stateChanges);
        pPicture.stateChanges = 0;
        pPicture.serialNumber = pPicture.pDrawable.serialNumber;
    }
}

void ValidatePicture(PicturePtr pPicture)
{
    ValidateOnePicture(pPicture);
    if (pPicture.alphaMap)
        ValidateOnePicture(pPicture.alphaMap);
}

int FreePicture(void* value, XID pid)
{
    PicturePtr pPicture = cast(PicturePtr) value;

    if (--pPicture.refcnt == 0) {
        free(pPicture.transform);
        free(pPicture.filter_params);

        if (pPicture.pSourcePict) {
            if (pPicture.pSourcePict.type != SourcePictTypeSolidFill)
                free(pPicture.pSourcePict.linear.stops);

            free(pPicture.pSourcePict);
        }

        if (pPicture.pDrawable) {
            ScreenPtr pScreen = pPicture.pDrawable.pScreen;
            PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

            if (pPicture.alphaMap)
                FreePicture(cast(void*) pPicture.alphaMap, cast(XID) 0);
            (*ps.DestroyPicture) (pPicture);
            (*ps.DestroyPictureClip) (pPicture);
            if (pPicture.pDrawable.type == DRAWABLE_WINDOW) {
                WindowPtr pWindow = cast(WindowPtr) pPicture.pDrawable;
                PicturePtr* pPrev = void;

                for (pPrev = cast(PicturePtr*) dixLookupPrivateAddr
                     (&pWindow.devPrivates, &PictureWindowPrivateKeyRec);
                     *pPrev; pPrev = &(*pPrev).pNext) {
                    if (*pPrev == pPicture) {
                        *pPrev = pPicture.pNext;
                        break;
                    }
                }
            }
            else if (pPicture.pDrawable.type == DRAWABLE_PIXMAP) {
                dixDestroyPixmap(cast(PixmapPtr) pPicture.pDrawable, 0);
            }
        }
        mixin(dixFreeObjectWithPrivatesM!("pPicture", "PRIVATE_PICTURE"));
    }
    return Success;
}

/**
 * ReduceCompositeOp is used to choose simpler ops for cases where alpha
 * channels are always one and so math on the alpha channel per pixel becomes
 * unnecessary.  It may also avoid destination reads sometimes if apps aren't
 * being careful to avoid these cases.
 */
private CARD8 ReduceCompositeOp(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, CARD16 width, CARD16 height)
{
    Bool no_src_alpha = void, no_dst_alpha = void;

    /* Sampling off the edge of a RepeatNone picture introduces alpha
     * even if the picture itself doesn't have alpha. We don't try to
     * detect every case where we don't sample off the edge, just the
     * simplest case where there is no transform on the source
     * picture.
     */
    no_src_alpha = PIXMAN_FORMAT_COLOR(pSrc.format) &&
        PIXMAN_FORMAT_A(pSrc.format) == 0 &&
        (pSrc.repeatType != RepeatNone ||
         (!pSrc.transform &&
          xSrc >= 0 && ySrc >= 0 &&
          xSrc + width <= pSrc.pDrawable.width &&
          ySrc + height <= pSrc.pDrawable.height)) &&
        pSrc.alphaMap is null && pMask is null;
    no_dst_alpha = PIXMAN_FORMAT_COLOR(pDst.format) &&
        PIXMAN_FORMAT_A(pDst.format) == 0 && pDst.alphaMap is null;

    /* TODO, maybe: Conjoint and Disjoint op reductions? */

    /* Deal with simplifications where the source alpha is always 1. */
    if (no_src_alpha) {
        switch (op) {
        case PictOpOver:
            op = PictOpSrc;
            break;
        case PictOpInReverse:
            op = PictOpDst;
            break;
        case PictOpOutReverse:
            op = PictOpClear;
            break;
        case PictOpAtop:
            op = PictOpIn;
            break;
        case PictOpAtopReverse:
            op = PictOpOverReverse;
            break;
        case PictOpXor:
            op = PictOpOut;
            break;
        default:
            break;
        }
    }

    /* Deal with simplifications when the destination alpha is always 1 */
    if (no_dst_alpha) {
        switch (op) {
        case PictOpOverReverse:
            op = PictOpDst;
            break;
        case PictOpIn:
            op = PictOpSrc;
            break;
        case PictOpOut:
            op = PictOpClear;
            break;
        case PictOpAtop:
            op = PictOpOver;
            break;
        case PictOpXor:
            op = PictOpOutReverse;
            break;
        default:
            break;
        }
    }

    /* Reduce some con/disjoint ops to the basic names. */
    switch (op) {
    case PictOpDisjointClear:
    case PictOpConjointClear:
        op = PictOpClear;
        break;
    case PictOpDisjointSrc:
    case PictOpConjointSrc:
        op = PictOpSrc;
        break;
    case PictOpDisjointDst:
    case PictOpConjointDst:
        op = PictOpDst;
        break;
    default:
        break;
    }

    return op;
}

void CompositePicture(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    ValidatePicture(pSrc);
    if (pMask)
        ValidatePicture(pMask);
    ValidatePicture(pDst);

    op = ReduceCompositeOp(op, pSrc, pMask, pDst, xSrc, ySrc, width, height);
    if (op == PictOpDst)
        return;

    (*ps.Composite) (op,
                      pSrc,
                      pMask,
                      pDst,
                      xSrc, ySrc, xMask, yMask, xDst, yDst, width, height);
}

void CompositeRects(CARD8 op, PicturePtr pDst, xRenderColor* color, int nRect, xRectangle* rects)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    ValidatePicture(pDst);
    (*ps.CompositeRects) (op, pDst, color, nRect, rects);
}

void CompositeTrapezoids(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntrap, xTrapezoid* traps)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    ValidatePicture(pSrc);
    ValidatePicture(pDst);
    (*ps.Trapezoids) (op, pSrc, pDst, maskFormat, xSrc, ySrc, ntrap, traps);
}

void CompositeTriangles(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntriangles, xTriangle* triangles)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    ValidatePicture(pSrc);
    ValidatePicture(pDst);
    (*ps.Triangles) (op, pSrc, pDst, maskFormat, xSrc, ySrc, ntriangles,
                      triangles);
}

void CompositeTriStrip(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int npoints, xPointFixed* points)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    if (npoints < 3)
        return;

    ValidatePicture(pSrc);
    ValidatePicture(pDst);
    (*ps.TriStrip) (op, pSrc, pDst, maskFormat, xSrc, ySrc, npoints, points);
}

void CompositeTriFan(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int npoints, xPointFixed* points)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    if (npoints < 3)
        return;

    ValidatePicture(pSrc);
    ValidatePicture(pDst);
    (*ps.TriFan) (op, pSrc, pDst, maskFormat, xSrc, ySrc, npoints, points);
}

void AddTraps(PicturePtr pPicture, INT16 xOff, INT16 yOff, int ntrap, xTrap* traps)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pPicture.pDrawable.pScreen"));

    ValidatePicture(pPicture);
    (*ps.AddTraps) (pPicture, xOff, yOff, ntrap, traps);
}
