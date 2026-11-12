module randr.rrinfo;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2006 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import randr.randrstr_priv;
import randr.rrcrtc;
import dix.resource;
import randr.rroutput;
import randr.rrmode;
import randr.randr;


private RRModePtr RROldModeAdd(RROutputPtr output, RRScreenSizePtr size, int refresh)
{
    ScreenPtr pScreen = output.pScreen;

    mixin(rrScrPriv!("pScreen"));
    xRRModeInfo modeInfo = void;
    char[100] name = void;
    RRModePtr mode = void;
    int i = void;
    RRModePtr* modes = void;

    memset(&modeInfo, '\0', modeInfo.sizeof);
    snprintf(name.ptr, name.sizeof, "%dx%d", size.width, size.height);

    modeInfo.width = size.width;
    modeInfo.height = size.height;
    modeInfo.hTotal = size.width;
    modeInfo.vTotal = size.height;
    modeInfo.dotClock = (cast(CARD32) size.width * cast(CARD32) size.height *
                         cast(CARD32) refresh);
    modeInfo.nameLength = cast(ushort)strlen(name.ptr);
    mode = RRModeGet(&modeInfo, name.ptr);
    if (!mode)
        return null;
    for (i = 0; i < output.numModes; i++)
        if (output.modes[i] == mode) {
            RRModeDestroy(mode);
            return mode;
        }

    if (output.numModes)
        modes = cast(_rrMode**)reallocarray(output.modes,
                             output.numModes + 1, RRModePtr.sizeof);
    else
        modes = cast(RRModePtr*) cast(RRModePtr*) calloc(1, RRModePtr.sizeof);
    if (!modes) {
        RRModeDestroy(mode);
        FreeResource(cast(uint)mode.mode.id, 0);
        return null;
    }
    modes[output.numModes++] = mode;
    output.modes = modes;
    output.changed = TRUE;
    pScrPriv.changed = TRUE;
    pScrPriv.configChanged = TRUE;
    return mode;
}

private void RRScanOldConfig(ScreenPtr pScreen, Rotation rotations)
{
    mixin(rrScrPriv!("pScreen"));
    RROutputPtr output = void;
    RRCrtcPtr crtc = void;
    RRModePtr mode = void, newMode = null;
    int i = void;
    CARD16 minWidth = SHRT_MAX, minHeight = SHRT_MAX;
    CARD16 maxWidth = 0, maxHeight = 0;
    CARD16 width = void, height = void;

    /*
     * First time through, create a crtc and output and hook
     * them together
     */
    if (pScrPriv.numOutputs == 0 && pScrPriv.numCrtcs == 0) {
        crtc = RRCrtcCreate(pScreen, null);
        if (!crtc)
            return;
        output = RROutputCreate(pScreen, "default", 7, null);
        if (!output)
            return;
        RROutputSetCrtcs(output, &crtc, 1);
        RROutputSetConnection(output, RR_Connected);
        RROutputSetSubpixelOrder(output, PictureGetSubpixelOrder(pScreen));
    }

    output = pScrPriv.outputs[0];
    if (!output)
        return;
    crtc = pScrPriv.crtcs[0];
    if (!crtc)
        return;

    /* check rotations */
    if (rotations != crtc.rotations) {
        crtc.rotations = rotations;
        crtc.changed = TRUE;
        pScrPriv.changed = TRUE;
    }

    /* regenerate mode list */
    for (i = 0; i < pScrPriv.nSizes; i++) {
        RRScreenSizePtr size = &pScrPriv.pSizes[i];
        int r = void;

        if (size.nRates) {
            for (r = 0; r < size.nRates; r++) {
                mode = RROldModeAdd(output, size, size.pRates[r].rate);
                if (i == pScrPriv.size &&
                    size.pRates[r].rate == pScrPriv.rate) {
                    newMode = mode;
                }
            }
            free(size.pRates);
        }
        else {
            mode = RROldModeAdd(output, size, 0);
            if (i == pScrPriv.size)
                newMode = mode;
        }
    }
    if (pScrPriv.nSizes)
        free(pScrPriv.pSizes);
    pScrPriv.pSizes = null;
    pScrPriv.nSizes = 0;

    /* find size bounds */
    for (i = 0; i < output.numModes + output.numUserModes; i++) {
        mode = (i < output.numModes ?
                          output.modes[i] :
                          output.userModes[i - output.numModes]);
        width = mode.mode.width;
        height = mode.mode.height;

        if (width < minWidth)
            minWidth = width;
        if (width > maxWidth)
            maxWidth = width;
        if (height < minHeight)
            minHeight = height;
        if (height > maxHeight)
            maxHeight = height;
    }

    RRScreenSetSizeRange(pScreen, minWidth, minHeight, maxWidth, maxHeight);

    /* notice current mode */
    if (newMode)
        RRCrtcNotify(crtc, newMode, 0, 0, pScrPriv.rotation, null, 1, &output);
}

/*
 * Poll the driver for changed information
 */
Bool RRGetInfo(ScreenPtr pScreen, Bool force_query)
{
    mixin(rrScrPriv!("pScreen"));
    Rotation rotations = void;
    int i = void;

    /* Return immediately if we don't need to re-query and we already have the
     * information.
     */
    if (!force_query) {
        if (pScrPriv.numCrtcs != 0 || pScrPriv.numOutputs != 0)
            return TRUE;
    }

    for (i = 0; i < pScrPriv.numOutputs; i++)
        pScrPriv.outputs[i].changed = FALSE;
    for (i = 0; i < pScrPriv.numCrtcs; i++)
        pScrPriv.crtcs[i].changed = FALSE;

    rotations = 0;
    pScrPriv.changed = FALSE;
    pScrPriv.configChanged = FALSE;

    if (!(*pScrPriv.rrGetInfo) (pScreen, &rotations))
        return FALSE;

    if (pScrPriv.nSizes)
        RRScanOldConfig(pScreen, rotations);

    RRTellChanged(pScreen);
    return TRUE;
}

/*
 * Register the range of sizes for the screen
 */
void RRScreenSetSizeRange(ScreenPtr pScreen, CARD16 minWidth, CARD16 minHeight, CARD16 maxWidth, CARD16 maxHeight)
{
    mixin(rrScrPriv!("pScreen"));

    if (!pScrPriv)
        return;
    if (pScrPriv.minWidth == minWidth && pScrPriv.minHeight == minHeight &&
        pScrPriv.maxWidth == maxWidth && pScrPriv.maxHeight == maxHeight) {
        return;
    }

    pScrPriv.minWidth = minWidth;
    pScrPriv.minHeight = minHeight;
    pScrPriv.maxWidth = maxWidth;
    pScrPriv.maxHeight = maxHeight;
    RRSetChanged(pScreen);
    pScrPriv.configChanged = TRUE;
}

private Bool RRScreenSizeMatches(RRScreenSizePtr a, RRScreenSizePtr b)
{
    if (a.width != b.width)
        return FALSE;
    if (a.height != b.height)
        return FALSE;
    if (a.mmWidth != b.mmWidth)
        return FALSE;
    if (a.mmHeight != b.mmHeight)
        return FALSE;
    return TRUE;
}

RRScreenSizePtr RRRegisterSize(ScreenPtr pScreen, short width, short height, short mmWidth, short mmHeight)
{
    mixin(rrScrPriv!("pScreen"));
    int i = void;
    RRScreenSizePtr pNew = void;

    if (!pScrPriv)
        return null;

    RRScreenSize tmp = {
        width: width,
        height: height,
        mmWidth: mmWidth,
        mmHeight: mmHeight,
    };

    for (i = 0; i < pScrPriv.nSizes; i++)
        if (RRScreenSizeMatches(&tmp, &pScrPriv.pSizes[i]))
            return &pScrPriv.pSizes[i];
    pNew = cast(_rrScreenSize*)reallocarray(pScrPriv.pSizes,
                        pScrPriv.nSizes + 1, RRScreenSize.sizeof);
    if (!pNew)
        return null;
    pNew[pScrPriv.nSizes++] = tmp;
    pScrPriv.pSizes = pNew;
    return &pNew[pScrPriv.nSizes - 1];
}

Bool RRRegisterRate(ScreenPtr pScreen, RRScreenSizePtr pSize, int rate)
{
    mixin(rrScrPriv!("pScreen"));
    int i = void;
    RRScreenRatePtr pNew = void, pRate = void;

    if (!pScrPriv)
        return FALSE;

    for (i = 0; i < pSize.nRates; i++)
        if (pSize.pRates[i].rate == rate)
            return TRUE;

    pNew = cast(RRScreenRate*) reallocarray(pSize.pRates, pSize.nRates + 1, RRScreenRate.sizeof);
    if (!pNew)
        return FALSE;
    pRate = &pNew[pSize.nRates++];
    pRate.rate = cast(ushort)rate;
    pSize.pRates = pNew;
    return TRUE;
}

void RRSetCurrentConfig(ScreenPtr pScreen, Rotation rotation, int rate, RRScreenSizePtr pSize)
{
    mixin(rrScrPriv!("pScreen"));

    if (!pScrPriv)
        return;
    pScrPriv.size = cast(int)(pSize - pScrPriv.pSizes);
    pScrPriv.rotation = rotation;
    pScrPriv.rate = rate;
}
