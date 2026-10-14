module render.filter;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2002 Keith Packard
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

version =  XK_LATIN1;
import x11.keysymdef;

import dix.screenint_priv;

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
import include.picturestr;
import externs.X11.extensions.render_;
import render.picture;

private char** filterNames;
private int nfilterNames;

/*
 * ISO Latin-1 case conversion routine
 *
 * this routine always null-terminates the result, so
 * beware of too-small buffers
 */

private ubyte ISOLatin1ToLower(ubyte source)
{
    ubyte dest = void;

    if ((source >= XK_A) && (source <= XK_Z))
        dest = cast(ubyte)(source + (XK_a - XK_A));
    else if ((source >= XK_Agrave) && (source <= XK_Odiaeresis))
        dest = cast(ubyte)(source + (XK_agrave - XK_Agrave));
    else if ((source >= XK_Ooblique) && (source <= XK_Thorn))
        dest = cast(ubyte)(source + (XK_oslash - XK_Ooblique));
    else
        dest = source;
    return dest;
}

private int CompareISOLatin1Lowered(const(ubyte)* s1, int s1len, const(ubyte)* s2, int s2len)
{
    ubyte c1 = void, c2 = void;

    for (;;) {
        /* note -- compare against zero so that -1 ignores len */
        c1 = s1len-- ? *s1++ : '\0';
        c2 = s2len-- ? *s2++ : '\0';
        if (!c1 ||
            (c1 != c2 &&
             (c1 = ISOLatin1ToLower(c1)) != (c2 = ISOLatin1ToLower(c2))))
            break;
    }
    return cast(int) c1 - cast(int) c2;
}

/*
 * standard but not required filters don't have constant indices
 */

int PictureGetFilterId(const(char)* filter, int len, Bool makeit)
{
    int i = void;
    char** names = void;

    if (len < 0)
        len = cast(uint)strlen(filter);
    for (i = 0; i < nfilterNames; i++)
        if (!CompareISOLatin1Lowered(cast(const(ubyte)*) filterNames[i], -1,
                                     cast(const(ubyte)*) filter, len))
            return i;
    if (!makeit)
        return -1;
    char* name = cast(char*) calloc(1, len + 1);
    if (!name)
        return -1;
    memcpy(name, filter, len);
    name[len] = '\0';
    if (filterNames)
        names = cast(char**)reallocarray(filterNames, nfilterNames + 1, (char*).sizeof);
    else
        names = cast(char**) calloc(1, (char*).sizeof);
    if (!names) {
        free(name);
        return -1;
    }
    filterNames = names;
    i = nfilterNames++;
    filterNames[i] = name;
    return i;
}

private Bool PictureSetDefaultIds()
{
    /* careful here -- this list must match the #define values */

    if (PictureGetFilterId(FilterNearest, -1, TRUE) != PictFilterNearest)
        return FALSE;
    if (PictureGetFilterId(FilterBilinear, -1, TRUE) != PictFilterBilinear)
        return FALSE;

    if (PictureGetFilterId(FilterFast, -1, TRUE) != PictFilterFast)
        return FALSE;
    if (PictureGetFilterId(FilterGood, -1, TRUE) != PictFilterGood)
        return FALSE;
    if (PictureGetFilterId(FilterBest, -1, TRUE) != PictFilterBest)
        return FALSE;

    if (PictureGetFilterId(FilterConvolution, -1, TRUE) !=
        PictFilterConvolution)
        return FALSE;
    return TRUE;
}

char* PictureGetFilterName(int id)
{
    if (0 <= id && id < nfilterNames)
        return filterNames[id];
    else
        return null;
}

private void PictureFreeFilterIds()
{
    int i = void;

    for (i = 0; i < nfilterNames; i++)
        free(filterNames[i]);
    free(filterNames);
    nfilterNames = 0;
    filterNames = null;
}

int PictureAddFilter(ScreenPtr pScreen, const(char)* filter, PictFilterValidateParamsProcPtr ValidateParams, int width, int height)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    int id = PictureGetFilterId(filter, -1, TRUE);
    int i = void;
    PictFilterPtr filters = void;

    if (id < 0)
        return -1;
    /*
     * It's an error to attempt to reregister a filter
     */
    for (i = 0; i < ps.nfilters; i++)
        if (ps.filters[i].id == id)
            return -1;
    if (ps.filters)
        filters =
            cast(PictFilterRec*) reallocarray(ps.filters, ps.nfilters + 1, PictFilterRec.sizeof);
    else
        filters = cast(PictFilterRec*) calloc(1, PictFilterRec.sizeof);
    if (!filters)
        return -1;
    ps.filters = filters;
    i = ps.nfilters++;
    ps.filters[i].name = PictureGetFilterName(id);
    ps.filters[i].id = id;
    ps.filters[i].ValidateParams = ValidateParams;
    ps.filters[i].width = width;
    ps.filters[i].height = height;
    return id;
}

Bool PictureSetFilterAlias(ScreenPtr pScreen, const(char)* filter, const(char)* alias_)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    int filter_id = PictureGetFilterId(filter, -1, FALSE);
    int alias_id = PictureGetFilterId(alias_, -1, TRUE);
    int i = void;

    if (filter_id < 0 || alias_id < 0)
        return FALSE;
    for (i = 0; i < ps.nfilterAliases; i++)
        if (ps.filterAliases[i].alias_id == alias_id)
            break;
    if (i == ps.nfilterAliases) {
        PictFilterAliasPtr aliases = void;

        if (ps.filterAliases)
            aliases = cast(_PictFilterAliasRec*)reallocarray(ps.filterAliases,
                                   ps.nfilterAliases + 1,
                                   PictFilterAliasRec.sizeof);
        else
            aliases = cast(PictFilterAliasRec*) calloc(1, PictFilterAliasRec.sizeof);
        if (!aliases)
            return FALSE;
        ps.filterAliases = aliases;
        ps.filterAliases[i].alias_ = PictureGetFilterName(alias_id);
        ps.filterAliases[i].alias_id = alias_id;
        ps.nfilterAliases++;
    }
    ps.filterAliases[i].filter_id = filter_id;
    return TRUE;
}

PictFilterPtr PictureFindFilter(ScreenPtr pScreen, char* name, int len)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    int id = PictureGetFilterId(name, len, FALSE);
    int i = void;

    if (id < 0)
        return null;
    /* Check for an alias, allow them to recurse */
    for (i = 0; i < ps.nfilterAliases; i++)
        if (ps.filterAliases[i].alias_id == id) {
            id = ps.filterAliases[i].filter_id;
            i = 0;
        }
    /* find the filter */
    for (i = 0; i < ps.nfilters; i++)
        if (ps.filters[i].id == id)
            return &ps.filters[i];
    return null;
}

private Bool convolutionFilterValidateParams(ScreenPtr pScreen, int filter, XFixed* params, int nparams, int* width, int* height)
{
    int w = void, h = void;

    if (nparams < 3)
        return FALSE;

    if (mixin(xFixedFrac!("params[0]")) || mixin(xFixedFrac!("params[1]")))
        return FALSE;

    w = mixin(xFixedToInt!("params[0]"));
    h = mixin(xFixedToInt!("params[1]"));

    nparams -= 2;
    if (w * h > nparams)
        return FALSE;

    *width = w;
    *height = h;
    return TRUE;
}

Bool PictureSetDefaultFilters(ScreenPtr pScreen)
{
    if (!filterNames)
        if (!PictureSetDefaultIds())
            return FALSE;
    if (PictureAddFilter(pScreen, FilterNearest, null, 1, 1) < 0)
        return FALSE;
    if (PictureAddFilter(pScreen, FilterBilinear, null, 2, 2) < 0)
        return FALSE;

    if (!PictureSetFilterAlias(pScreen, FilterNearest, FilterFast))
        return FALSE;
    if (!PictureSetFilterAlias(pScreen, FilterBilinear, FilterGood))
        return FALSE;
    if (!PictureSetFilterAlias(pScreen, FilterBilinear, FilterBest))
        return FALSE;

    if (PictureAddFilter
        (pScreen, FilterConvolution, &convolutionFilterValidateParams, 0, 0) < 0)
        return FALSE;

    return TRUE;
}

void PictureResetFilters(ScreenPtr pScreen)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    free(ps.filters);
    free(ps.filterAliases);

    /* Free the filters when the last screen is closed */
    if (pScreen.myNum == 0)
        PictureFreeFilterIds();
}

int SetPictureFilter(PicturePtr pPicture, char* name, int len, XFixed* params, int nparams)
{
    PictFilterPtr pFilter = void;
    ScreenPtr pScreen = void;

    if (pPicture.pDrawable !is null)
        pScreen = pPicture.pDrawable.pScreen;
    else
        pScreen = dixGetMasterScreen();

    pFilter = PictureFindFilter(pScreen, name, len);

    if (!pFilter)
        return BadName;

    if (pPicture.pDrawable is null) {
        /* For source pictures, the picture isn't tied to a screen.  So, ensure
         * that all screens can handle a filter we set for the picture.
         */
        mixin(DIX_FOR_EACH_SCREEN!q{
            if (!walkScreenIdx)
                continue; // skip the first screen

            PictFilterPtr pScreenFilter = PictureFindFilter(walkScreen, name, len);
            if (!pScreenFilter || pScreenFilter.id != pFilter.id)
                return BadMatch;
        });
    }
    return SetPicturePictFilter(pPicture, pFilter, params, nparams);
}

int SetPicturePictFilter(PicturePtr pPicture, PictFilterPtr pFilter, XFixed* params, int nparams)
{
    ScreenPtr pScreen = void;
    int i = void;

    if (pPicture.pDrawable)
        pScreen = pPicture.pDrawable.pScreen;
    else
        pScreen = dixGetMasterScreen();

    if (pFilter.ValidateParams) {
        int width = void, height = void;

        if (!(*pFilter.ValidateParams)
            (pScreen, pFilter.id, params, nparams, &width, &height))
            return BadMatch;
    }
    else if (nparams)
        return BadMatch;

    if (nparams != pPicture.filter_nparams) {
        XFixed* new_params = cast(XFixed*) calloc(nparams, XFixed.sizeof);

        if (!new_params && nparams)
            return BadAlloc;
        free(pPicture.filter_params);
        pPicture.filter_params = new_params;
        pPicture.filter_nparams = nparams;
    }
    for (i = 0; i < nparams; i++)
        if (pPicture.filter_params)
            pPicture.filter_params[i] = params[i];
    pPicture.filter = pFilter.id;

    if (pPicture.pDrawable) {
        PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
        int result = void;

        result = (*ps.ChangePictureFilter) (pPicture, pPicture.filter,
                                             params, nparams);
        return result;
    }
    return Success;
}
