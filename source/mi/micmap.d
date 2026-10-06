module mi.micmap;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 1987, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * This is based on cfbcmap.c.  The functions here are useful independently
 * of cfb, which is the reason for including them here.  How "mi" these
 * are may be debatable.
 */

import build.dix_config;

//import x11.X;
//import x11.Xproto;

import dix.colormap_priv;
import mi.mi_priv;
import os.bug_priv;
import os.osdep;

import include.scrnintstr;
import include.resource;
import include.globals;
import mi.micmap;
import dix.resource;
import dix.colormap;

enum MIN_TRUE_DEPTH =  6;

enum StaticGrayMask =  (1 << StaticGray);
enum GrayScaleMask =   (1 << GrayScale);

enum ALL_VISUALS =     (StaticGrayMask|GrayScaleMask|StaticColorMask|
                         PseudoColorMask|TrueColorMask|DirectColorMask);
enum LARGE_VISUALS =   (TrueColorMask|DirectColorMask);
enum SMALL_VISUALS =   (StaticGrayMask|GrayScaleMask|StaticColorMask|PseudoColorMask);

// DevPrivateKeyRec micmapScrPrivateKeyRec;

int miListInstalledColormaps(ScreenPtr pScreen, Colormap* pmaps)
{
    if (GetInstalledmiColormap(pScreen)) {
        *pmaps = GetInstalledmiColormap(pScreen).mid;
        return 1;
    }
    return 0;
}

void miInstallColormap(ColormapPtr pmap)
{
    ColormapPtr oldpmap = GetInstalledmiColormap(pmap.pScreen);

    if (pmap != oldpmap) {
        /* Uninstall pInstalledMap. No hardware changes required, just
         * notify all interested parties. */
        if (oldpmap != cast(ColormapPtr) None)
            WalkTree(pmap.pScreen, &TellLostMap, cast(char*) &oldpmap.mid);
        /* Install pmap */
        SetInstalledmiColormap(pmap.pScreen, pmap);
        WalkTree(pmap.pScreen, &TellGainedMap, cast(char*) &pmap.mid);

    }
}

void miUninstallColormap(ColormapPtr pmap)
{
    ColormapPtr curpmap = GetInstalledmiColormap(pmap.pScreen);

    if (pmap == curpmap) {
        if (pmap.mid != pmap.pScreen.defColormap) {
            dixLookupResourceByType(cast(void**) &curpmap,
                                    cast(uint)pmap.pScreen.defColormap,
                                    X11_RESTYPE_COLORMAP, serverClient, DixUseAccess);
            (*pmap.pScreen.InstallColormap) (curpmap);
        }
    }
}

void miResolveColor(ushort* pred, ushort* pgreen, ushort* pblue, VisualPtr pVisual)
{
    int shift = 16 - pVisual.bitsPerRGBValue;
    uint lim = (1 << pVisual.bitsPerRGBValue) - 1;

    if ((pVisual.class_ | DynamicClass) == GrayScale) {
        /* rescale to gray then rgb bits */
        *pred = (30L * *pred + 59L * *pgreen + 11L * *pblue) / 100;
        *pblue = *pgreen = *pred = cast(ushort)(((*pred >> shift) * 65535) / lim);
    }
    else {
        /* rescale to rgb bits */
        *pred = cast(ushort)(((*pred >> shift) * 65535) / lim);
        *pgreen = cast(ushort)(((*pgreen >> shift) * 65535) / lim);
        *pblue = cast(ushort)(((*pblue >> shift) * 65535) / lim);
    }
}

Bool miInitializeColormap(ColormapPtr pmap)
{
    uint i = void;
    VisualPtr pVisual = void;
    uint lim = void, maxent = void, shift = void;

    pVisual = pmap.pVisual;
    lim = (1 << pVisual.bitsPerRGBValue) - 1;
    shift = 16 - pVisual.bitsPerRGBValue;
    maxent = pVisual.ColormapEntries - 1;
    if (pVisual.class_ == TrueColor) {
        uint limr = void, limg = void, limb = void;

        limr = cast(uint)(pVisual.redMask >> pVisual.offsetRed);
        limg = cast(uint)(pVisual.greenMask >> pVisual.offsetGreen);
        limb = cast(uint)(pVisual.blueMask >> pVisual.offsetBlue);
        for (i = 0; i <= maxent; i++) {
            /* rescale to [0..65535] then rgb bits */
            pmap.red[i].co.local.red =
                cast(ushort)(((((i * 65535) / limr) >> shift) * 65535) / lim);
            pmap.green[i].co.local.green =
                cast(ushort)(((((i * 65535) / limg) >> shift) * 65535) / lim);
            pmap.blue[i].co.local.blue =
                cast(ushort)(((((i * 65535) / limb) >> shift) * 65535) / lim);
        }
    }
    else if (pVisual.class_ == StaticColor) {
        uint limr = void, limg = void, limb = void;

        limr = cast(uint)(pVisual.redMask >> pVisual.offsetRed);
        limg = cast(uint)(pVisual.greenMask >> pVisual.offsetGreen);
        limb = cast(uint)(pVisual.blueMask >> pVisual.offsetBlue);
        for (i = 0; i <= maxent; i++) {
            /* rescale to [0..65535] then rgb bits */
            pmap.red[i].co.local.red = cast(short)
                (((((((i & pVisual.redMask) >> pVisual.offsetRed)
                    * 65535) / limr) >> shift) * 65535) / lim);
            pmap.red[i].co.local.green = cast(short)
                (((((((i & pVisual.greenMask) >> pVisual.offsetGreen)
                   * 65535) / limg) >> shift) * 65535) / lim);
            pmap.red[i].co.local.blue = cast(short)
                (((((((i & pVisual.blueMask) >> pVisual.offsetBlue)
                    * 65535) / limb) >> shift) * 65535) / lim);
        }
    }
    else if (pVisual.class_ == StaticGray) {
        for (i = 0; i <= maxent; i++) {
            /* rescale to [0..65535] then rgb bits */
            pmap.red[i].co.local.red = cast(ushort)(((((i * 65535) / maxent) >> shift)
                                         * 65535) / lim);
            pmap.red[i].co.local.green = cast(ushort)(pmap.red[i].co.local.red);
            pmap.red[i].co.local.blue = cast(ushort)(pmap.red[i].co.local.red);
        }
    }
    return TRUE;
}

/* When simulating DirectColor on PseudoColor hardware, multiple
   entries of the colormap must be updated
 */

enum string AddElement(string mask) = `{ 
    pixel = red | green | blue; 
    for (i = 0; i < nresult; i++) 
  	if (outdefs[i].pixel == pixel) 
    	    break; 
    if (i == nresult) 
    { 
   	nresult++; 
	outdefs[i].pixel = pixel; 
	outdefs[i].flags = 0; 
    } 
    outdefs[i].flags |= (` ~ mask ~ `); 
    outdefs[i].red = pmap.red[red >> pVisual.offsetRed].co.local.red; 
    outdefs[i].green = pmap.green[green >> pVisual.offsetGreen].co.local.green; 
    outdefs[i].blue = pmap.blue[blue >> pVisual.offsetBlue].co.local.blue; 
}`;

int miExpandDirectColors(ColormapPtr pmap, int ndef, xColorItem* indefs, xColorItem* outdefs)
{
    int red = void, green = void, blue = void;
    int maxred = void, maxgreen = void, maxblue = void;
    int stepred = void, stepgreen = void, stepblue = void;
    VisualPtr pVisual = void;
    int pixel = void;
    int nresult = void;
    int i = void;

    pVisual = pmap.pVisual;

    stepred = 1 << pVisual.offsetRed;
    stepgreen = 1 << pVisual.offsetGreen;
    stepblue = 1 << pVisual.offsetBlue;
    maxred = cast(int)pVisual.redMask;
    maxgreen = cast(int)pVisual.greenMask;
    maxblue = cast(int)pVisual.blueMask;
    nresult = 0;
    for (; ndef--; indefs++) {
        if (indefs.flags & DoRed) {
            red = cast(int)(indefs.pixel & pVisual.redMask);
            for (green = 0; green <= maxgreen; green += stepgreen) {
                for (blue = 0; blue <= maxblue; blue += stepblue) {
                    mixin(AddElement!("DoRed"));
                }
            }
        }
        if (indefs.flags & DoGreen) {
            green = cast(int)(indefs.pixel & pVisual.greenMask);
            for (red = 0; red <= maxred; red += stepred) {
                for (blue = 0; blue <= maxblue; blue += stepblue) {
                    mixin(AddElement!("DoGreen"));
                }
            }
        }
        if (indefs.flags & DoBlue) {
            blue = cast(int)(indefs.pixel & pVisual.blueMask);
            for (red = 0; red <= maxred; red += stepred) {
                for (green = 0; green <= maxgreen; green += stepgreen) {
                    mixin(AddElement!("DoBlue"));
                }
            }
        }
    }
    return nresult;
}

Bool miCreateDefColormap(ScreenPtr pScreen)
{
    ushort zero = 0, ones = 0xFFFF;
    Pixel wp = void, bp = void;
    VisualPtr pVisual = void;
    ColormapPtr cmap = void;
    int alloctype = void;

    if (!dixRegisterPrivateKey(&micmapScrPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    for (pVisual = pScreen.visuals;
         pVisual.vid != pScreen.rootVisual; pVisual++){}

    if (pScreen.rootDepth == 1 || (pVisual.class_ & DynamicClass))
        alloctype = AllocNone;
    else
        alloctype = AllocAll;

    if (dixCreateColormap(cast(uint)pScreen.defColormap, pScreen, pVisual, &cmap,
                          alloctype, serverClient) != Success)
        return FALSE;

    if (pScreen.rootDepth > 1) {
        wp = cast(uint)pScreen.whitePixel;
        bp = cast(uint)pScreen.blackPixel;
        if ((AllocColor(cmap, &ones, &ones, &ones, &wp, 0) !=
             Success) ||
            (AllocColor(cmap, &zero, &zero, &zero, &bp, 0) != Success))
            return FALSE;
        pScreen.whitePixel = wp;
        pScreen.blackPixel = bp;
    }

    (*pScreen.InstallColormap) (cmap);
    return TRUE;
}

/*
 * Default true color bitmasks, should be overridden by
 * driver
 */

enum string _RZ(string d) = `((` ~ d ~ ` + 2) / 3)`;
enum string _RS(string d) = `0`;
enum string _RM(string d) = `((1U << ` ~ _RZ!(d) ~ `) - 1)`;
enum string _GZ(string d) = `((` ~ d ~ ` - ` ~ _RZ!(d) ~ ` + 1) / 2)`;
enum string _GS(string d) = _RZ!(d);
enum string _GM(string d) = `(((1U << ` ~ _GZ!(d) ~ `) - 1) << ` ~ _GS!(d) ~ `)`;
enum string _BZ(string d) = `(` ~ d ~ ` - ` ~ _RZ!(d) ~ ` - ` ~ _GZ!(d) ~ `)`;
enum string _BS(string d) = `(` ~ _RZ!(d) ~ ` + ` ~ _GZ!(d) ~ `)`;
enum string _BM(string d) = `(((1U << ` ~ _BZ!(d) ~ `) - 1) << ` ~ _BS!(d) ~ `)`;
enum string _CE(string d) = `(1U << ` ~ _RZ!(d) ~ `)`;

struct _miVisuals {
    _miVisuals* next;
    int depth;
    int bitsPerRGB;
    int visuals;
    int count;
    int preferredCVC;
    Pixel redMask, greenMask, blueMask;
}alias miVisualsRec = _miVisuals;
alias miVisualsPtr = _miVisuals*;

private int[6] miVisualPriority = [
    PseudoColor, GrayScale, StaticColor, TrueColor, DirectColor, StaticGray
];

enum NUM_PRIORITY =	6;

private miVisualsPtr miVisuals;

void miClearVisualTypes()
{
    miVisualsPtr v = void;

    while ((v = miVisuals) !is null) {
        miVisuals = v.next;
        free(v);
    }
}

Bool miSetVisualTypesAndMasks(int depth, int visuals, int bitsPerRGB, int preferredCVC, Pixel redMask, Pixel greenMask, Pixel blueMask)
{
    miVisualsPtr* prev = void; miVisualsPtr v = void;

    miVisualsPtr new_ = cast(miVisualsPtr) calloc(1, (_miVisuals).sizeof);
    if (!new_)
        return FALSE;
    if (!redMask || !greenMask || !blueMask) {
        redMask = mixin(_RM!(`depth`));
        greenMask = mixin(_GM!(`depth`));
        blueMask = mixin(_BM!(`depth`));
    }
    new_.next = null;
    new_.depth = depth;
    new_.visuals = visuals;
    new_.bitsPerRGB = bitsPerRGB;
    new_.preferredCVC = preferredCVC;
    new_.redMask = redMask;
    new_.greenMask = greenMask;
    new_.blueMask = blueMask;
    new_.count = Ones(visuals);
    for (prev = &miVisuals; ((v = *prev) !is null); prev = &v.next){}
    *prev = new_;
    return TRUE;
}

Bool miSetVisualTypes(int depth, int visuals, int bitsPerRGB, int preferredCVC)
{
    return miSetVisualTypesAndMasks(depth, visuals, bitsPerRGB,
                                    preferredCVC, 0, 0, 0);
}

int miGetDefaultVisualMask(int depth)
{
    if (depth > MAX_PSEUDO_DEPTH)
        return LARGE_VISUALS;
    else if (depth >= MIN_TRUE_DEPTH)
        return ALL_VISUALS;
    else if (depth == 1)
        return StaticGrayMask;
    else
        return SMALL_VISUALS;
}

private Bool miVisualTypesSet(int depth)
{
    miVisualsPtr visuals = void;

    for (visuals = miVisuals; visuals; visuals = visuals.next)
        if (visuals.depth == depth)
            return TRUE;
    return FALSE;
}

Bool miSetPixmapDepths()
{
    int d = void, f = void;

    /* Add any unlisted depths from the pixmap formats */
    for (f = 0; f < screenInfo.numPixmapFormats; f++) {
        d = screenInfo.formats[f].depth;
        if (!miVisualTypesSet(d)) {
            if (!miSetVisualTypes(d, 0, 0, -1))
                return FALSE;
        }
    }
    return TRUE;
}

/*
 * Distance to least significant one bit
 */
private int maskShift(Pixel p)
{
    int s = void;

    if (!p)
        return 0;
    s = 0;
    while (!(p & 1)) {
        s++;
        p >>= 1;
    }
    return s;
}

/*
 * Given a list of formats for a screen, create a list
 * of visuals and depths for the screen which correspond to
 * the set which can be used with this version of cfb.
 */

Bool miInitVisuals(VisualPtr* visualp, DepthPtr* depthp, int* nvisualp, int* ndepthp, int* rootDepthp, VisualID* defaultVisp, c_ulong sizes, int bitsPerRGB, int preferredVis)
{
    int i = void, j = 0, k = void;
    int f = void;
    miVisualsPtr visuals = void, nextVisuals = void;

    /* none specified, we'll guess from pixmap formats */
    if (!miVisuals) {
        for (f = 0; f < screenInfo.numPixmapFormats; f++) {
            int d = screenInfo.formats[f].depth;
            int b = screenInfo.formats[f].bitsPerPixel;
            int vtype = ((sizes & (1 << (b - 1))) ? miGetDefaultVisualMask(d) : 0);
            if (!miSetVisualTypes(d, vtype, bitsPerRGB, -1))
                return FALSE;
        }
    }

    int nvisual = 0;
    int ndepth = 0;
    for (visuals = miVisuals; visuals; visuals = nextVisuals) {
        nextVisuals = visuals.next;
        ndepth++;
        nvisual += visuals.count;
    }

    DepthPtr depth = cast(DepthPtr) calloc(ndepth, DepthRec.sizeof);
    VisualPtr visual = cast(VisualPtr) calloc(nvisual, VisualRec.sizeof);
    int* preferredCVCs = cast(int*) calloc(ndepth, int.sizeof);
    if (!depth || !visual || !preferredCVCs) {
        free(depth);
        free(visual);
        free(preferredCVCs);
        return FALSE;
    }
    *depthp = depth;
    *visualp = visual;
    *ndepthp = ndepth;
    *nvisualp = nvisual;

    int* prefp = preferredCVCs;
    for (visuals = miVisuals; visuals; visuals = nextVisuals) {
        int d = visuals.depth;
        int vtype = visuals.visuals;
        int nvtype = visuals.count;

        nextVisuals = visuals.next;
        VisualID* vid = null;
        *prefp = visuals.preferredCVC;
        prefp++;
        if (nvtype) {
            vid = cast(VisualID*) calloc(nvtype, VisualID.sizeof);
            if (!vid) {
                free(depth);
                free(visual);
                free(preferredCVCs);
                return FALSE;
            }
        }
        depth.depth = cast(ubyte)d;
        depth.numVids = cast(short)nvtype;
        depth.vids = vid;
        for (i = 0; i < NUM_PRIORITY; i++) {
            if (!(vtype & (1 << miVisualPriority[i])))
                continue;
            visual.class_ = cast(short)miVisualPriority[i];
            visual.bitsPerRGBValue = cast(short)visuals.bitsPerRGB;
            visual.ColormapEntries = cast(short)(1 << d);
            visual.nplanes = cast(short)d;
            visual.vid = dixAllocServerXID();
            if (vid)
                *vid = visual.vid;
            else
                mixin(BUG_WARN!("vid is null"));

            switch (visual.class_) {
            case PseudoColor:
            case GrayScale:
            case StaticGray:
                visual.redMask = 0;
                visual.greenMask = 0;
                visual.blueMask = 0;
                visual.offsetRed = 0;
                visual.offsetGreen = 0;
                visual.offsetBlue = 0;
                break;
            case DirectColor, TrueColor:
                visual.ColormapEntries = cast(short)mixin(_CE!(`d`));
                /* fall through */
                goto case;
            case StaticColor:
                visual.redMask = visuals.redMask;
                visual.greenMask = visuals.greenMask;
                visual.blueMask = visuals.blueMask;
                visual.offsetRed = maskShift(visuals.redMask);
                visual.offsetGreen = maskShift(visuals.greenMask);
                visual.offsetBlue = maskShift(visuals.blueMask);
            goto default;
            default: break;}
            vid++;
            visual++;
        }
        depth++;
        free(visuals);
    }
    miVisuals = null;
    visual = *visualp;
    depth = *depthp;

    /*
     * if we did not supplyied by a preferred visual class
     * check if there is a preferred class in one of the depth
     * structures - if there is, we want to start looking for the
     * default visual/depth from that depth.
     */
    int first_depth = 0;
    if (preferredVis < 0 && defaultColorVisualClass < 0) {
        for (i = 0; i < ndepth; i++) {
            if (preferredCVCs[i] >= 0) {
                first_depth = i;
                break;
            }
        }
    }

    for (i = first_depth; i < ndepth; i++) {
        int prefColorVisualClass = -1;

        if (defaultColorVisualClass >= 0)
            prefColorVisualClass = defaultColorVisualClass;
        else if (preferredVis >= 0)
            prefColorVisualClass = preferredVis;
        else if (preferredCVCs[i] >= 0)
            prefColorVisualClass = preferredCVCs[i];

        if (*rootDepthp && *rootDepthp != depth[i].depth)
            continue;

        for (j = 0; j < depth[i].numVids; j++) {
            for (k = 0; k < nvisual; k++)
                if (visual[k].vid == depth[i].vids[j])
                    break;
            if (k == nvisual)
                continue;
            if (prefColorVisualClass < 0 ||
                visual[k].class_ == prefColorVisualClass)
                break;
        }
        if (j != depth[i].numVids)
            break;
    }
    if (i == ndepth) {
        i = 0;
        j = 0;
    }
    *rootDepthp = depth[i].depth;
    *defaultVisp = depth[i].vids[j];
    free(preferredCVCs);

    return TRUE;
}
