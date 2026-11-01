module miindex;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2001 Keith Packard, member of The XFree86 Project, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import dix.colormap_priv;
import dix.colormap;

import include.mipict;

import include.scrnintstr;
import include.gcstruct;
import include.pixmapstr;
import include.windowstr;
import include.picturestr;
import externs.X11.extensions.renderproto;
import render.picture;


enum NUM_CUBE_LEVELS =	4;
enum NUM_GRAY_LEVELS =	13;

private Bool miBuildRenderColormap(ColormapPtr pColormap, Pixel* pixels, int* nump)
{
    int r = void, g = void, b = void;
    ushort red = void, green = void, blue = void;
    Pixel pixel = void;
    Bool[MI_MAX_INDEXED] used = void;
    int needed = void;
    int policy = void;
    int cube = void, gray = void;
    int i = void, n = void;

    if (pColormap.mid != pColormap.pScreen.defColormap) {
        policy = PictureCmapPolicyAll;
    }
    else {
        int avail = pColormap.pVisual.ColormapEntries;

        policy = PictureCmapPolicy;
        if (policy == PictureCmapPolicyDefault) {
            if (avail >= 256 &&
                (pColormap.pVisual.class_ | DynamicClass) == PseudoColor)
                policy = PictureCmapPolicyColor;
            else if (avail >= 64)
                policy = PictureCmapPolicyGray;
            else
                policy = PictureCmapPolicyMono;
        }
    }
    /*
     * Make sure enough cells are free for the chosen policy
     */
    for (;;) {
        switch (policy) {
        case PictureCmapPolicyAll:
            needed = 0;
            break;
        case PictureCmapPolicyColor:
            needed = 71;
            break;
        case PictureCmapPolicyGray:
            needed = 11;
            break;
        case PictureCmapPolicyMono:
        default:
            needed = 0;
            break;
        }
        if (needed <= pColormap.freeRed)
            break;
        policy--;
    }

    /*
     * Compute size of cube and gray ramps
     */
    cube = gray = 0;
    switch (policy) {
    case PictureCmapPolicyAll:
        /*
         * Allocate as big a cube as possible
         */
        if ((pColormap.pVisual.class_ | DynamicClass) == PseudoColor) {
            for (cube = 1;
                 cube * cube * cube < pColormap.pVisual.ColormapEntries;
                 cube++){}
            cube--;
            if (cube == 1)
                cube = 0;
        }
        else
            cube = 0;
        /*
         * Figure out how many gray levels to use so that they
         * line up neatly with the cube
         */
        if (cube) {
            needed = pColormap.pVisual.ColormapEntries - (cube * cube * cube);
            /* levels to fill in with */
            gray = needed / (cube - 1);
            /* total levels */
            gray = (gray + 1) * (cube - 1) + 1;
        }
        else
            gray = pColormap.pVisual.ColormapEntries;
        break;

    case PictureCmapPolicyColor:
        cube = NUM_CUBE_LEVELS;
        /* fall through ... */
        goto case;
    case PictureCmapPolicyGray:
        gray = NUM_GRAY_LEVELS;
        break;
    case PictureCmapPolicyMono:
    default:
        gray = 2;
        break;
    }

    memset(used.ptr, '\0', pColormap.pVisual.ColormapEntries * Bool.sizeof);
    for (r = 0; r < cube; r++)
        for (g = 0; g < cube; g++)
            for (b = 0; b < cube; b++) {
                pixel = 0;
                red = cast(ushort)((r * 65535 + (cube - 1) / 2) / (cube - 1));
                green = cast(ushort)((g * 65535 + (cube - 1) / 2) / (cube - 1));
                blue = cast(ushort)((b * 65535 + (cube - 1) / 2) / (cube - 1));
                if (AllocColor(pColormap, &red, &green,
                               &blue, &pixel, 0) != Success)
                    return FALSE;
                used[pixel] = TRUE;
            }
    for (g = 0; g < gray; g++) {
        pixel = 0;
        red = green = blue = cast(ubyte)((g * 65535 + (gray - 1) / 2) / (gray - 1));
        if (AllocColor(pColormap, &red, &green, &blue, &pixel, 0) != Success)
            return FALSE;
        used[pixel] = TRUE;
    }
    n = 0;
    for (i = 0; i < pColormap.pVisual.ColormapEntries; i++)
        if (used[i])
            pixels[n++] = i;

    *nump = n;

    return TRUE;
}

/* 0 <= red, green, blue < 32 */
private Pixel FindBestColor(miIndexedPtr pIndexed, Pixel* pixels, int num, int red, int green, int blue)
{
    Pixel best = pixels[0];
    int bestDist = 1 << 30;
    int dist = void;
    int dr = void, dg = void, db = void;

    while (num--) {
        Pixel pixel = *pixels++;
        CARD32 v = pIndexed.rgba[pixel];

        dr = ((v >> 19) & 0x1f);
        dg = ((v >> 11) & 0x1f);
        db = ((v >> 3) & 0x1f);
        dr = dr - red;
        dg = dg - green;
        db = db - blue;
        dist = dr * dr + dg * dg + db * db;
        if (dist < bestDist) {
            bestDist = dist;
            best = pixel;
        }
    }
    return best;
}

/* 0 <= gray < 32768 */
Pixel FindBestGray(miIndexedPtr pIndexed, Pixel* pixels, int num, int gray)
{
    Pixel best = pixels[0];
    int bestDist = 1 << 30;
    int dist = void;
    int dr = void;
    int r = void;

    while (num--) {
        Pixel pixel = *pixels++;
        CARD32 v = pIndexed.rgba[pixel];

        r = v & 0xff;
        r = r | (r << 8);
        dr = gray - (r >> 1);
        dist = dr * dr;
        if (dist < bestDist) {
            bestDist = dist;
            best = pixel;
        }
    }
    return best;
}

Bool miInitIndexed(ScreenPtr pScreen, PictFormatPtr pFormat)
{
    ColormapPtr pColormap = pFormat.index.pColormap;
    VisualPtr pVisual = pColormap.pVisual;
    Pixel[MI_MAX_INDEXED] pixels = void;
    xrgb[MI_MAX_INDEXED] rgb = void;
    int num = void;
    int i = void;
    Pixel p = void, r = void, g = void, b = void;

    if (pVisual.ColormapEntries > MI_MAX_INDEXED)
        return FALSE;

    if (pVisual.class_ & DynamicClass) {
        if (!miBuildRenderColormap(pColormap, pixels.ptr, &num))
            return FALSE;
    }
    else {
        num = pVisual.ColormapEntries;
        for (p = 0; p < num; p++)
            pixels[p] = p;
    }

    miIndexedPtr pIndexed = cast(miIndexedRec*) calloc(1, miIndexedRec.sizeof);
    if (!pIndexed)
        return FALSE;

    pFormat.index.nvalues = num;
    pFormat.index.pValues = cast(xIndexValue*)calloc(num, xIndexValue.sizeof);
    if (!pFormat.index.pValues) {
        free(pIndexed);
        return FALSE;
    }

    /*
     * Build mapping from pixel value to ARGB
     */
    QueryColors(pColormap, num, pixels.ptr, rgb.ptr, serverClient);
    for (i = 0; i < num; i++) {
        p = pixels[i];
        pFormat.index.pValues[i].pixel = p;
        pFormat.index.pValues[i].red = rgb[i].red;
        pFormat.index.pValues[i].green = rgb[i].green;
        pFormat.index.pValues[i].blue = rgb[i].blue;
        pFormat.index.pValues[i].alpha = 0xffff;
        pIndexed.rgba[p] = (0xff000000 |
                             ((rgb[i].red & 0xff00) << 8) |
                             ((rgb[i].green & 0xff00)) |
                             ((rgb[i].blue & 0xff00) >> 8));
    }

    /*
     * Build mapping from RGB to pixel value.  This could probably be
     * done a bit quicker...
     */
    switch (pVisual.class_ | DynamicClass) {
    case GrayScale:
        pIndexed.color = FALSE;
        for (r = 0; r < 32768; r++)
            pIndexed.ent[r] = cast(ubyte)FindBestGray(pIndexed, pixels.ptr, num, cast(int)r);
        break;
    case PseudoColor:
        pIndexed.color = TRUE;
        p = 0;
        for (r = 0; r < 32; r++)
            for (g = 0; g < 32; g++)
                for (b = 0; b < 32; b++) {
                    pIndexed.ent[p] = cast(ubyte)FindBestColor(pIndexed, pixels.ptr, num,
                                                     cast(int)r, cast(int)g, cast(int)b);
                    p++;
                }
        break;
    default: break;}
    pFormat.index.devPrivate = pIndexed;
    return TRUE;
}

void miCloseIndexed(ScreenPtr pScreen, PictFormatPtr pFormat)
{
    free(pFormat.index.devPrivate);
    pFormat.index.devPrivate = null;
    free(pFormat.index.pValues);
    pFormat.index.pValues = null;
}

void miUpdateIndexed(ScreenPtr pScreen, PictFormatPtr pFormat, int ndef, xColorItem* pdef)
{
    miIndexedPtr pIndexed = cast(_miIndexed*)pFormat.index.devPrivate;

    if (pIndexed) {
        while (ndef--) {
            pIndexed.rgba[pdef.pixel] = (0xff000000 |
                                           ((pdef.red & 0xff00) << 8) |
                                           ((pdef.green & 0xff00)) |
                                           ((pdef.blue & 0xff00) >> 8));
            pdef++;
        }
    }
}
