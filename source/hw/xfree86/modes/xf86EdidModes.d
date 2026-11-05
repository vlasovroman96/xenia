module xf86EdidModes;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2006 Luc Verhaegen.
 * Copyright 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sub license,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the
 * next paragraph) shall be included in all copies or substantial portions
 * of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * @file This file covers code to convert a xf86MonPtr containing EDID-probed
 * information into a list of modes, including applying monitor-specific
 * quirks to fix broken EDID data.
 */
import build.xorg_config;

import xf86DDC_priv;
//import externs.X11.Xatom;
import dix.property;
import hw.xfree86.common.xf86Crtc;
import core.stdc.string;
import core.stdc.math;
import edid_priv;
import interpret_edid;
import hw.xfree86.common.edid;
import xf86gtf;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.modes.displaymode;

private void handle_detailed_rblank(detailed_monitor_section* det_mon, void* data)
{
    if (det_mon.type == DS_RANGES)
        if (det_mon.section.ranges.supported_blanking & CVT_REDUCED)
            *cast(Bool*) data = TRUE;
}

private Bool xf86MonitorSupportsReducedBlanking(xf86MonPtr DDC)
{
    /* EDID 1.4 explicitly defines RB support */
    if (DDC.ver.revision >= 4) {
        Bool ret = FALSE;

        xf86ForEachDetailedBlock(DDC, &handle_detailed_rblank, &ret);
        return ret;
    }

    /* For anything older, assume digital means RB support. Boo. */
    if (DDC.features.input_type)
        return TRUE;

    return FALSE;
}

private Bool quirk_prefer_large_60(int scrnIndex, xf86MonPtr DDC_)
{
    /* Belinea 10 15 55 */
    if (memcmp(DDC_.vendor_.name.ptr, "MAX".ptr, 4) == 0 &&
        ((DDC_.vendor_.prod_id == 1516) || (DDC_.vendor_.prod_id == 0x77e)))
        return TRUE;

    /* Acer AL1706 */
    if (memcmp(DDC_.vendor_.name.ptr, "ACR".ptr, 4) == 0 && DDC_.vendor_.prod_id == 44358)
        return TRUE;

    /* Bug #10814: Samsung SyncMaster 225BW */
    if (memcmp(DDC_.vendor_.name.ptr, "SAM".ptr, 4) == 0 && DDC_.vendor_.prod_id == 596)
        return TRUE;

    /* Bug #10545: Samsung SyncMaster 226BW */
    if (memcmp(DDC_.vendor_.name.ptr, "SAM".ptr, 4) == 0 && DDC_.vendor_.prod_id == 638)
        return TRUE;

    /* Acer F51 */
    if (memcmp(DDC_.vendor_.name.ptr, "API".ptr, 4) == 0 &&
        DDC_.vendor_.prod_id == 0x7602)
        return TRUE;

    return FALSE;
}

private Bool quirk_prefer_large_75(int scrnIndex, xf86MonPtr DDC)
{
    /* Bug #11603: Funai Electronics PM36B */
    if (memcmp(DDC.vendor_.name.ptr, "FCM".ptr, 4) == 0 && DDC.vendor_.prod_id == 13600)
        return TRUE;

    return FALSE;
}

private Bool quirk_detailed_h_in_cm(int scrnIndex, xf86MonPtr DDC)
{
    /* Bug #11603: Funai Electronics PM36B */
    if (memcmp(DDC.vendor_.name.ptr, "FCM".ptr, 4) == 0 && DDC.vendor_.prod_id == 13600)
        return TRUE;

    return FALSE;
}

private Bool quirk_detailed_v_in_cm(int scrnIndex, xf86MonPtr DDC)
{
    /* Bug #11603: Funai Electronics PM36B */
    if (memcmp(DDC.vendor_.name.ptr, "FCM".ptr, 4) == 0 && DDC.vendor_.prod_id == 13600)
        return TRUE;

    /* Bug #21000: LGPhilipsLCD LP154W01-TLAJ */
    if (memcmp(DDC.vendor_.name.ptr, "LPL".ptr, 4) == 0 && DDC.vendor_.prod_id == 47360)
        return TRUE;

    /* Bug #10304: LGPhilipsLCD LP154W01-A5 */
    if (memcmp(DDC.vendor_.name.ptr, "LPL".ptr, 4) == 0 && DDC.vendor_.prod_id == 0)
        return TRUE;

    /* Bug #24482: LGPhilipsLCD LP154W01-TLA1 */
    if (memcmp(DDC.vendor_.name.ptr, "LPL".ptr, 4) == 0 &&
        DDC.vendor_.prod_id == 0x2a00)
        return TRUE;

    /* Bug #28414: HP Compaq NC8430 LP154W01-TLA8 */
    if (memcmp(DDC.vendor_.name.ptr, "LPL".ptr, 4) == 0 && DDC.vendor_.prod_id == 5750)
        return TRUE;

    /* Bug #21750: Samsung Syncmaster 2333HD */
    if (memcmp(DDC.vendor_.name.ptr, "SAM".ptr, 4) == 0 && DDC.vendor_.prod_id == 1157)
        return TRUE;

    return FALSE;
}

private Bool quirk_detailed_use_maximum_size(int scrnIndex, xf86MonPtr DDC)
{
    /* ADA 1024x600 7" display */
    if (memcmp(DDC.vendor_.name.ptr, "ADA".ptr, 4) == 0 &&
        DDC.vendor_.prod_id == 4)
        return TRUE;

    /* Bug #21324: Iiyama Vision Master 450 */
    if (memcmp(DDC.vendor_.name.ptr, "IVM".ptr, 4) == 0 && DDC.vendor_.prod_id == 6400)
        return TRUE;

    /* Bug #41141: Acer Aspire One */
    if (memcmp(DDC.vendor_.name.ptr, "LGD".ptr, 4) == 0 &&
        DDC.vendor_.prod_id == 0x7f01)
        return TRUE;

    /* Sony Vaio Pro 13 */
    if (memcmp(DDC.vendor_.name.ptr, "MEI".ptr, 4) == 0 &&
        DDC.vendor_.prod_id == 0x96a2)
        return TRUE;

    return FALSE;
}

private Bool quirk_135_clock_too_high(int scrnIndex, xf86MonPtr DDC)
{
    /* Envision Peripherals, Inc. EN-7100e.  See bug #9550. */
    if (memcmp(DDC.vendor_.name.ptr, "EPI".ptr, 4) == 0 && DDC.vendor_.prod_id == 59264)
        return TRUE;

    return FALSE;
}

private Bool quirk_first_detailed_preferred(int scrnIndex, xf86MonPtr DDC)
{
    /* Philips 107p5 CRT. Reported on xorg@ with pastebin. */
    if (memcmp(DDC.vendor_.name.ptr, "PHL".ptr, 4) == 0 && DDC.vendor_.prod_id == 57364)
        return TRUE;

    /* Proview AY765C 17" LCD. See bug #15160 */
    if (memcmp(DDC.vendor_.name.ptr, "PTS".ptr, 4) == 0 && DDC.vendor_.prod_id == 765)
        return TRUE;

    /* ACR of some sort RH #284231 */
    if (memcmp(DDC.vendor_.name.ptr, "ACR".ptr, 4) == 0 && DDC.vendor_.prod_id == 2423)
        return TRUE;

    /* Peacock Ergovision 19.  See rh#492359 */
    if (memcmp(DDC.vendor_.name.ptr, "PEA".ptr, 4) == 0 && DDC.vendor_.prod_id == 9003)
        return TRUE;

    return FALSE;
}

private Bool quirk_detailed_sync_pp(int scrnIndex, xf86MonPtr DDC)
{
    /* Bug #12439: Samsung SyncMaster 205BW */
    if (memcmp(DDC.vendor_.name.ptr, "SAM".ptr, 4) == 0 && DDC.vendor_.prod_id == 541)
        return TRUE;
    return FALSE;
}

/* This should probably be made more generic */
private Bool quirk_dvi_single_link(int scrnIndex, xf86MonPtr DDC)
{
    /* Red Hat bug #453106: Apple 23" Cinema Display */
    if (memcmp(DDC.vendor_.name.ptr, "APL".ptr, 4) == 0 &&
        DDC.vendor_.prod_id == 0x921c)
        return TRUE;
    return FALSE;
}

struct ddc_quirk_map_t {
    Bool function(int scrnIndex, xf86MonPtr DDC) @nogc nothrow detect;
    ddc_quirk_t quirk;
    const(char)* description;
}

private const(ddc_quirk_map_t)[11] ddc_quirks = [
    {
     &quirk_prefer_large_60, DDC_QUIRK_PREFER_LARGE_60,
     "Detailed timing is not preferred, use largest mode at 60Hz"},
    {
     &quirk_135_clock_too_high, DDC_QUIRK_135_CLOCK_TOO_HIGH,
     "Recommended 135MHz pixel clock is too high"},
    {
     &quirk_prefer_large_75, DDC_QUIRK_PREFER_LARGE_75,
     "Detailed timing is not preferred, use largest mode at 75Hz"},
    {
     &quirk_detailed_h_in_cm, DDC_QUIRK_DETAILED_H_IN_CM,
     "Detailed timings give horizontal size in cm."},
    {
     &quirk_detailed_v_in_cm, DDC_QUIRK_DETAILED_V_IN_CM,
     "Detailed timings give vertical size in cm."},
    {
     &quirk_detailed_use_maximum_size, DDC_QUIRK_DETAILED_USE_MAXIMUM_SIZE,
     "Use maximum size instead of detailed timing sizes."},
    {
     &quirk_first_detailed_preferred, DDC_QUIRK_FIRST_DETAILED_PREFERRED,
     "First detailed timing was not marked as preferred."},
    {
     &quirk_detailed_sync_pp, DDC_QUIRK_DETAILED_SYNC_PP,
     "Use +hsync +vsync for detailed timing."},
    {
     &quirk_dvi_single_link, DDC_QUIRK_DVI_SINGLE_LINK,
     "Forcing maximum pixel clock to single DVI link."},
    {
     null, DDC_QUIRK_NONE,
     "No known quirks"},
];

/*
 * These more or less come from the DMT spec.  The 720x400 modes are
 * inferred from historical 80x25 practice.  The 640x480@67 and 832x624@75
 * modes are old-school Mac modes.  The EDID spec says the 1152x864@75 mode
 * should be 1152x870, again for the Mac, but instead we use the x864 DMT
 * mode.
 *
 * The DMT modes have been fact-checked; the rest are mild guesses.
 */
enum MODEPREFIX = "NULL, NULL, NULL, 0, M_T_DRIVER";
enum MODESUFFIX = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,FALSE,FALSE,0,NULL,0,0.0,0.0";

alias M_T_DRIVER = hw.xfree86.common.xf86Crtc.M_T_DRIVER;

// private const(DisplayModeRec)[17] DDCEstablishedModes = [
//     {mixin(MODEPREFIX), 40000, 800, 840, 968, 1056, 0, 600, 601, 605, 628, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},        /* 800x600@60Hz */
//     {mixin(MODEPREFIX), 36000, 800, 824, 896, 1024, 0, 600, 601, 603, 625, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},        /* 800x600@56Hz */
//     {mixin(MODEPREFIX), 31500, 640, 656, 720, 840, 0, 480, 481, 484, 500, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX}, /* 640x480@75Hz */
//     {mixin(MODEPREFIX), 31500, 640, 664, 704, 832, 0, 480, 489, 492, 520, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX}, /* 640x480@72Hz */
//     {mixin(MODEPREFIX), 30240, 640, 704, 768, 864, 0, 480, 483, 486, 525, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX}, /* 640x480@67Hz */
//     {mixin(MODEPREFIX), 25175, 640, 656, 752, 800, 0, 480, 490, 492, 525, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX}, /* 640x480@60Hz */
//     {mixin(MODEPREFIX), 35500, 720, 738, 846, 900, 0, 400, 421, 423, 449, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX}, /* 720x400@88Hz */
//     {mixin(MODEPREFIX), 28320, 720, 738, 846, 900, 0, 400, 412, 414, 449, 0, V_NHSYNC | V_PVSYNC, MODESUFFIX}, /* 720x400@70Hz */
//     {mixin(MODEPREFIX), 135000, 1280, 1296, 1440, 1688, 0, 1024, 1025, 1028, 1066, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},        /* 1280x1024@75Hz */
//     {mixin(MODEPREFIX), 78750, 1024, 1040, 1136, 1312, 0, 768, 769, 772, 800, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},     /* 1024x768@75Hz */
//     {mixin(MODEPREFIX), 75000, 1024, 1048, 1184, 1328, 0, 768, 771, 777, 806, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX},     /* 1024x768@70Hz */
//     {mixin(MODEPREFIX), 65000, 1024, 1048, 1184, 1344, 0, 768, 771, 777, 806, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX},     /* 1024x768@60Hz */
//     {mixin(MODEPREFIX), 44900, 1024, 1032, 1208, 1264, 0, 768, 768, 772, 817, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE, MODESUFFIX},       /* 1024x768@43Hz */
//     {mixin(MODEPREFIX), 57284, 832, 864, 928, 1152, 0, 624, 625, 628, 667, 0, V_NHSYNC | V_NVSYNC, MODESUFFIX},        /* 832x624@75Hz */
//     {mixin(MODEPREFIX), 49500, 800, 816, 896, 1056, 0, 600, 601, 604, 625, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},        /* 800x600@75Hz */
//     {mixin(MODEPREFIX), 50000, 800, 856, 976, 1040, 0, 600, 637, 643, 666, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},        /* 800x600@72Hz */
//     {mixin(MODEPREFIX), 108000, 1152, 1216, 1344, 1600, 0, 864, 865, 868, 900, 0, V_PHSYNC | V_PVSYNC, MODESUFFIX},    /* 1152x864@75Hz */
// ];

private const(DisplayModeRec)[17] DDCEstablishedModes = [
    { type: M_T_DRIVER, Clock: 40000, HDisplay: 800, HSyncStart: 840, HSyncEnd: 968, HTotal: 1056, VDisplay: 600, VSyncStart: 601, VSyncEnd: 605, VTotal: 628, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 800x600@60Hz */
    { type: M_T_DRIVER, Clock: 36000, HDisplay: 800, HSyncStart: 824, HSyncEnd: 896, HTotal: 1024, VDisplay: 600, VSyncStart: 601, VSyncEnd: 603, VTotal: 625, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 800x600@56Hz */
    { type: M_T_DRIVER, Clock: 31500, HDisplay: 640, HSyncStart: 656, HSyncEnd: 720, HTotal: 840,  VDisplay: 480, VSyncStart: 481, VSyncEnd: 484, VTotal: 500, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 640x480@75Hz */
    { type: M_T_DRIVER, Clock: 31500, HDisplay: 640, HSyncStart: 664, HSyncEnd: 704, HTotal: 832,  VDisplay: 480, VSyncStart: 489, VSyncEnd: 492, VTotal: 520, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 640x480@72Hz */
    { type: M_T_DRIVER, Clock: 30240, HDisplay: 640, HSyncStart: 704, HSyncEnd: 768, HTotal: 864,  VDisplay: 480, VSyncStart: 483, VSyncEnd: 486, VTotal: 525, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 640x480@67Hz */
    { type: M_T_DRIVER, Clock: 25175, HDisplay: 640, HSyncStart: 656, HSyncEnd: 752, HTotal: 800,  VDisplay: 480, VSyncStart: 490, VSyncEnd: 492, VTotal: 525, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 640x480@60Hz */
    { type: M_T_DRIVER, Clock: 35500, HDisplay: 720, HSyncStart: 738, HSyncEnd: 846, HTotal: 900,  VDisplay: 400, VSyncStart: 421, VSyncEnd: 423, VTotal: 449, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 720x400@88Hz */
    { type: M_T_DRIVER, Clock: 28320, HDisplay: 720, HSyncStart: 738, HSyncEnd: 846, HTotal: 900,  VDisplay: 400, VSyncStart: 412, VSyncEnd: 414, VTotal: 449, Flags: V_NHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 720x400@70Hz */
    { type: M_T_DRIVER, Clock: 135000, HDisplay: 1280, HSyncStart: 1296, HSyncEnd: 1440, HTotal: 1688, VDisplay: 1024, VSyncStart: 1025, VSyncEnd: 1028, VTotal: 1066, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 1280x1024@75Hz */
    { type: M_T_DRIVER, Clock: 78750, HDisplay: 1024, HSyncStart: 1040, HSyncEnd: 1136, HTotal: 1312, VDisplay: 768, VSyncStart: 769, VSyncEnd: 772, VTotal: 800, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 1024x768@75Hz */
    { type: M_T_DRIVER, Clock: 75000, HDisplay: 1024, HSyncStart: 1048, HSyncEnd: 1184, HTotal: 1328, VDisplay: 768, VSyncStart: 771, VSyncEnd: 777, VTotal: 806, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 1024x768@70Hz */
    { type: M_T_DRIVER, Clock: 65000, HDisplay: 1024, HSyncStart: 1048, HSyncEnd: 1184, HTotal: 1344, VDisplay: 768, VSyncStart: 771, VSyncEnd: 777, VTotal: 806, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 1024x768@60Hz */
    { type: M_T_DRIVER, Clock: 44900, HDisplay: 1024, HSyncStart: 1032, HSyncEnd: 1208, HTotal: 1264, VDisplay: 768, VSyncStart: 768, VSyncEnd: 772, VTotal: 817, Flags: V_PHSYNC | V_PVSYNC | V_INTERLACE, HSync: 0.0, VRefresh: 0.0 }, /* 1024x768@43Hz */
    { type: M_T_DRIVER, Clock: 57284, HDisplay: 832, HSyncStart: 864, HSyncEnd: 928, HTotal: 1152, VDisplay: 624, VSyncStart: 625, VSyncEnd: 628, VTotal: 667, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 832x624@75Hz */
    { type: M_T_DRIVER, Clock: 49500, HDisplay: 800, HSyncStart: 816, HSyncEnd: 896, HTotal: 1056, VDisplay: 600, VSyncStart: 601, VSyncEnd: 604, VTotal: 625, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 800x600@75Hz */
    { type: M_T_DRIVER, Clock: 50000, HDisplay: 800, HSyncStart: 856, HSyncEnd: 976, HTotal: 1040, VDisplay: 600, VSyncStart: 637, VSyncEnd: 643, VTotal: 666, Flags: V_PHSYNC | V_PVSYNC, HSync: 0.0, VRefresh: 0.0 }, /* 800x600@72Hz */
    { type: M_T_DRIVER, Clock: 100000, HDisplay: 1152, HSyncStart: 1184, HSyncEnd: 1280, HTotal: 1456, VDisplay: 870, VSyncStart: 873, VSyncEnd: 876, VTotal: 915, Flags: V_NHSYNC | V_NVSYNC, HSync: 0.0, VRefresh: 0.0 } /* 1152x870@75Hz */
];

private DisplayModePtr DDCModesFromEstablished(int scrnIndex, established_timings* timing, ddc_quirk_t quirks)
{
    DisplayModePtr Modes = null, Mode = null;
    CARD32 bits = (timing.t1) | (timing.t2 << 8) |
        ((timing.t_manu & 0x80) << 9);
    int i = void;

    for (i = 0; i < 17; i++) {
        if (bits & (0x01 << i)) {
            Mode = xf86DuplicateMode(cast(_DisplayModeRec*)&DDCEstablishedModes[i]);
            Modes = xf86ModesAdd(Modes, Mode);
        }
    }

    return Modes;
}

/* Autogenerated from the DMT spec */
private const(DisplayModeRec)[81] DMTModes = [
    {type: M_T_DRIVER, Clock:31500, HDisplay: 640, HSyncStart:672,  736, 832, 0, 350, 382, 385, 445, 0, V_PHSYNC | V_NVSYNC}, /* 640x350@85Hz */
    {type: M_T_DRIVER, Clock:31500, HDisplay: 640, HSyncStart:672,  736, 832, 0, 400, 401, 404, 445, 0, V_NHSYNC | V_PVSYNC}, /* 640x400@85Hz */
    {type: M_T_DRIVER, Clock:35500, HDisplay: 720, HSyncStart:756,  828, 936, 0, 400, 401, 404, 446, 0, V_NHSYNC | V_PVSYNC}, /* 720x400@85Hz */
    {type: M_T_DRIVER, Clock:25175, HDisplay: 640, HSyncStart:656,  752, 800, 0, 480, 490, 492, 525, 0, V_NHSYNC | V_NVSYNC}, /* 640x480@60Hz */
    {type: M_T_DRIVER, Clock:31500, HDisplay: 640, HSyncStart:664,  704, 832, 0, 480, 489, 492, 520, 0, V_NHSYNC | V_NVSYNC}, /* 640x480@72Hz */
    {type: M_T_DRIVER, Clock:31500, HDisplay: 640, HSyncStart:656,  720, 840, 0, 480, 481, 484, 500, 0, V_NHSYNC | V_NVSYNC}, /* 640x480@75Hz */
    {type: M_T_DRIVER, Clock:36000, HDisplay: 640, HSyncStart:696,  752, 832, 0, 480, 481, 484, 509, 0, V_NHSYNC | V_NVSYNC}, /* 640x480@85Hz */
    {type: M_T_DRIVER, Clock:36000, HDisplay: 800, HSyncStart:824,  896, 1024, 0, 600, 601, 603, 625, 0, V_PHSYNC | V_PVSYNC},        /* 800x600@56Hz */
    {type: M_T_DRIVER, Clock:40000, HDisplay: 800, HSyncStart:840,  968, 1056, 0, 600, 601, 605, 628, 0, V_PHSYNC | V_PVSYNC},        /* 800x600@60Hz */
    {type: M_T_DRIVER, Clock:50000, HDisplay: 800, HSyncStart:856,  976, 1040, 0, 600, 637, 643, 666, 0, V_PHSYNC | V_PVSYNC},        /* 800x600@72Hz */
    {type: M_T_DRIVER, Clock:49500, HDisplay: 800, HSyncStart:816,  896, 1056, 0, 600, 601, 604, 625, 0, V_PHSYNC | V_PVSYNC},        /* 800x600@75Hz */
    {type: M_T_DRIVER, Clock:56250, HDisplay: 800, HSyncStart:832,  896, 1048, 0, 600, 601, 604, 631, 0, V_PHSYNC | V_PVSYNC},        /* 800x600@85Hz */
    {type: M_T_DRIVER, Clock:73250, HDisplay: 800, HSyncStart:848,  880, 960, 0, 600, 603, 607, 636, 0, V_PHSYNC | V_NVSYNC}, /* 800x600@120Hz RB */
    {type: M_T_DRIVER, Clock:33750, HDisplay: 848, HSyncStart:864,  976, 1088, 0, 480, 486, 494, 517, 0, V_PHSYNC | V_PVSYNC},        /* 848x480@60Hz */
    {type: M_T_DRIVER, Clock:44900, HDisplay: 1024, HSyncStart:1032,  1208, 1264, 0, 768, 768, 772, 817, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE},       /* 1024x768@43Hz (interlaced) */
    {type: M_T_DRIVER, Clock:65000, HDisplay: 1024, HSyncStart:1048,  1184, 1344, 0, 768, 771, 777, 806, 0, V_NHSYNC | V_NVSYNC},     /* 1024x768@60Hz */
    {type: M_T_DRIVER, Clock:75000, HDisplay: 1024, HSyncStart:1048,  1184, 1328, 0, 768, 771, 777, 806, 0, V_NHSYNC | V_NVSYNC},     /* 1024x768@70Hz */
    {type: M_T_DRIVER, Clock:78750, HDisplay: 1024, HSyncStart:1040,  1136, 1312, 0, 768, 769, 772, 800, 0, V_PHSYNC | V_PVSYNC},     /* 1024x768@75Hz */
    {type: M_T_DRIVER, Clock:94500, HDisplay: 1024, HSyncStart:1072,  1168, 1376, 0, 768, 769, 772, 808, 0, V_PHSYNC | V_PVSYNC},     /* 1024x768@85Hz */
    {type: M_T_DRIVER, Clock:115500, HDisplay: 1024, HSyncStart:1072,  1104, 1184, 0, 768, 771, 775, 813, 0, V_PHSYNC | V_NVSYNC},    /* 1024x768@120Hz RB */
    {type: M_T_DRIVER, Clock:108000, HDisplay: 1152, HSyncStart:1216,  1344, 1600, 0, 864, 865, 868, 900, 0, V_PHSYNC | V_PVSYNC},    /* 1152x864@75Hz */
    {type: M_T_DRIVER, Clock:68250, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 768, 771, 778, 790, 0, V_PHSYNC | V_NVSYNC},     /* 1280x768@60Hz RB */
    {type: M_T_DRIVER, Clock:79500, HDisplay: 1280, HSyncStart:1344,  1472, 1664, 0, 768, 771, 778, 798, 0, V_NHSYNC | V_PVSYNC},     /* 1280x768@60Hz */
    {type: M_T_DRIVER, Clock:102250, HDisplay: 1280, HSyncStart:1360,  1488, 1696, 0, 768, 771, 778, 805, 0, V_NHSYNC | V_PVSYNC},    /* 1280x768@75Hz */
    {type: M_T_DRIVER, Clock:117500, HDisplay: 1280, HSyncStart:1360,  1496, 1712, 0, 768, 771, 778, 809, 0, V_NHSYNC | V_PVSYNC},    /* 1280x768@85Hz */
    {type: M_T_DRIVER, Clock:140250, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 768, 771, 778, 813, 0, V_PHSYNC | V_NVSYNC},    /* 1280x768@120Hz RB */
    {type: M_T_DRIVER, Clock:71000, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 800, 803, 809, 823, 0, V_PHSYNC | V_NVSYNC},     /* 1280x800@60Hz RB */
    {type: M_T_DRIVER, Clock:83500, HDisplay: 1280, HSyncStart:1352,  1480, 1680, 0, 800, 803, 809, 831, 0, V_NHSYNC | V_PVSYNC},     /* 1280x800@60Hz */
    {type: M_T_DRIVER, Clock:106500, HDisplay: 1280, HSyncStart:1360,  1488, 1696, 0, 800, 803, 809, 838, 0, V_NHSYNC | V_PVSYNC},    /* 1280x800@75Hz */
    {type: M_T_DRIVER, Clock:122500, HDisplay: 1280, HSyncStart:1360,  1496, 1712, 0, 800, 803, 809, 843, 0, V_NHSYNC | V_PVSYNC},    /* 1280x800@85Hz */
    {type: M_T_DRIVER, Clock:146250, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 800, 803, 809, 847, 0, V_PHSYNC | V_NVSYNC},    /* 1280x800@120Hz RB */
    {type: M_T_DRIVER, Clock:108000, HDisplay: 1280, HSyncStart:1376,  1488, 1800, 0, 960, 961, 964, 1000, 0, V_PHSYNC | V_PVSYNC},   /* 1280x960@60Hz */
    {type: M_T_DRIVER, Clock:148500, HDisplay: 1280, HSyncStart:1344,  1504, 1728, 0, 960, 961, 964, 1011, 0, V_PHSYNC | V_PVSYNC},   /* 1280x960@85Hz */
    {type: M_T_DRIVER, Clock:175500, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 960, 963, 967, 1017, 0, V_PHSYNC | V_NVSYNC},   /* 1280x960@120Hz RB */
    {type: M_T_DRIVER, Clock:108000, HDisplay: 1280, HSyncStart:1328,  1440, 1688, 0, 1024, 1025, 1028, 1066, 0, V_PHSYNC | V_PVSYNC},        /* 1280x1024@60Hz */
    {type: M_T_DRIVER, Clock:135000, HDisplay: 1280, HSyncStart:1296,  1440, 1688, 0, 1024, 1025, 1028, 1066, 0, V_PHSYNC | V_PVSYNC},        /* 1280x1024@75Hz */
    {type: M_T_DRIVER, Clock:157500, HDisplay: 1280, HSyncStart:1344,  1504, 1728, 0, 1024, 1025, 1028, 1072, 0, V_PHSYNC | V_PVSYNC},        /* 1280x1024@85Hz */
    {type: M_T_DRIVER, Clock:187250, HDisplay: 1280, HSyncStart:1328,  1360, 1440, 0, 1024, 1027, 1034, 1084, 0, V_PHSYNC | V_NVSYNC},        /* 1280x1024@120Hz RB */
    {type: M_T_DRIVER, Clock:85500, HDisplay: 1360, HSyncStart:1424,  1536, 1792, 0, 768, 771, 777, 795, 0, V_PHSYNC | V_PVSYNC},     /* 1360x768@60Hz */
    {type: M_T_DRIVER, Clock:148250, HDisplay: 1360, HSyncStart:1408,  1440, 1520, 0, 768, 771, 776, 813, 0, V_PHSYNC | V_NVSYNC},    /* 1360x768@120Hz RB */
    {type: M_T_DRIVER, Clock:101000, HDisplay: 1400, HSyncStart:1448,  1480, 1560, 0, 1050, 1053, 1057, 1080, 0, V_PHSYNC | V_NVSYNC},        /* 1400x1050@60Hz RB */
    {type: M_T_DRIVER, Clock:121750, HDisplay: 1400, HSyncStart:1488,  1632, 1864, 0, 1050, 1053, 1057, 1089, 0, V_NHSYNC | V_PVSYNC},        /* 1400x1050@60Hz */
    {type: M_T_DRIVER, Clock:156000, HDisplay: 1400, HSyncStart:1504,  1648, 1896, 0, 1050, 1053, 1057, 1099, 0, V_NHSYNC | V_PVSYNC},        /* 1400x1050@75Hz */
    {type: M_T_DRIVER, Clock:179500, HDisplay: 1400, HSyncStart:1504,  1656, 1912, 0, 1050, 1053, 1057, 1105, 0, V_NHSYNC | V_PVSYNC},        /* 1400x1050@85Hz */
    {type: M_T_DRIVER, Clock:208000, HDisplay: 1400, HSyncStart:1448,  1480, 1560, 0, 1050, 1053, 1057, 1112, 0, V_PHSYNC | V_NVSYNC},        /* 1400x1050@120Hz RB */
    {type: M_T_DRIVER, Clock:88750, HDisplay: 1440, HSyncStart:1488,  1520, 1600, 0, 900, 903, 909, 926, 0, V_PHSYNC | V_NVSYNC},     /* 1440x900@60Hz RB */
    {type: M_T_DRIVER, Clock:106500, HDisplay: 1440, HSyncStart:1520,  1672, 1904, 0, 900, 903, 909, 934, 0, V_NHSYNC | V_PVSYNC},    /* 1440x900@60Hz */
    {type: M_T_DRIVER, Clock:136750, HDisplay: 1440, HSyncStart:1536,  1688, 1936, 0, 900, 903, 909, 942, 0, V_NHSYNC | V_PVSYNC},    /* 1440x900@75Hz */
    {type: M_T_DRIVER, Clock:157000, HDisplay: 1440, HSyncStart:1544,  1696, 1952, 0, 900, 903, 909, 948, 0, V_NHSYNC | V_PVSYNC},    /* 1440x900@85Hz */
    {type: M_T_DRIVER, Clock:182750, HDisplay: 1440, HSyncStart:1488,  1520, 1600, 0, 900, 903, 909, 953, 0, V_PHSYNC | V_NVSYNC},    /* 1440x900@120Hz RB */
    {type: M_T_DRIVER, Clock:162000, HDisplay: 1600, HSyncStart:1664,  1856, 2160, 0, 1200, 1201, 1204, 1250, 0, V_PHSYNC | V_PVSYNC},        /* 1600x1200@60Hz */
    {type: M_T_DRIVER, Clock:175500, HDisplay: 1600, HSyncStart:1664,  1856, 2160, 0, 1200, 1201, 1204, 1250, 0, V_PHSYNC | V_PVSYNC},        /* 1600x1200@65Hz */
    {type: M_T_DRIVER, Clock:189000, HDisplay: 1600, HSyncStart:1664,  1856, 2160, 0, 1200, 1201, 1204, 1250, 0, V_PHSYNC | V_PVSYNC},        /* 1600x1200@70Hz */
    {type: M_T_DRIVER, Clock:202500, HDisplay: 1600, HSyncStart:1664,  1856, 2160, 0, 1200, 1201, 1204, 1250, 0, V_PHSYNC | V_PVSYNC},        /* 1600x1200@75Hz */
    {type: M_T_DRIVER, Clock:229500, HDisplay: 1600, HSyncStart:1664,  1856, 2160, 0, 1200, 1201, 1204, 1250, 0, V_PHSYNC | V_PVSYNC},        /* 1600x1200@85Hz */
    {type: M_T_DRIVER, Clock:268250, HDisplay: 1600, HSyncStart:1648,  1680, 1760, 0, 1200, 1203, 1207, 1271, 0, V_PHSYNC | V_NVSYNC},        /* 1600x1200@120Hz RB */
    {type: M_T_DRIVER, Clock:119000, HDisplay: 1680, HSyncStart:1728,  1760, 1840, 0, 1050, 1053, 1059, 1080, 0, V_PHSYNC | V_NVSYNC},        /* 1680x1050@60Hz RB */
    {type: M_T_DRIVER, Clock:146250, HDisplay: 1680, HSyncStart:1784,  1960, 2240, 0, 1050, 1053, 1059, 1089, 0, V_NHSYNC | V_PVSYNC},        /* 1680x1050@60Hz */
    {type: M_T_DRIVER, Clock:187000, HDisplay: 1680, HSyncStart:1800,  1976, 2272, 0, 1050, 1053, 1059, 1099, 0, V_NHSYNC | V_PVSYNC},        /* 1680x1050@75Hz */
    {type: M_T_DRIVER, Clock:214750, HDisplay: 1680, HSyncStart:1808,  1984, 2288, 0, 1050, 1053, 1059, 1105, 0, V_NHSYNC | V_PVSYNC},        /* 1680x1050@85Hz */
    {type: M_T_DRIVER, Clock:245500, HDisplay: 1680, HSyncStart:1728,  1760, 1840, 0, 1050, 1053, 1059, 1112, 0, V_PHSYNC | V_NVSYNC},        /* 1680x1050@120Hz RB */
    {type: M_T_DRIVER, Clock:204750, HDisplay: 1792, HSyncStart:1920,  2120, 2448, 0, 1344, 1345, 1348, 1394, 0, V_NHSYNC | V_PVSYNC},        /* 1792x1344@60Hz */
    {type: M_T_DRIVER, Clock:261000, HDisplay: 1792, HSyncStart:1888,  2104, 2456, 0, 1344, 1345, 1348, 1417, 0, V_NHSYNC | V_PVSYNC},        /* 1792x1344@75Hz */
    {type: M_T_DRIVER, Clock:333250, HDisplay: 1792, HSyncStart:1840,  1872, 1952, 0, 1344, 1347, 1351, 1423, 0, V_PHSYNC | V_NVSYNC},        /* 1792x1344@120Hz RB */
    {type: M_T_DRIVER, Clock:218250, HDisplay: 1856, HSyncStart:1952,  2176, 2528, 0, 1392, 1393, 1396, 1439, 0, V_NHSYNC | V_PVSYNC},        /* 1856x1392@60Hz */
    {type: M_T_DRIVER, Clock:288000, HDisplay: 1856, HSyncStart:1984,  2208, 2560, 0, 1392, 1393, 1396, 1500, 0, V_NHSYNC | V_PVSYNC},        /* 1856x1392@75Hz */
    {type: M_T_DRIVER, Clock:356500, HDisplay: 1856, HSyncStart:1904,  1936, 2016, 0, 1392, 1395, 1399, 1474, 0, V_PHSYNC | V_NVSYNC},        /* 1856x1392@120Hz RB */
    {type: M_T_DRIVER, Clock:154000, HDisplay: 1920, HSyncStart:1968,  2000, 2080, 0, 1200, 1203, 1209, 1235, 0, V_PHSYNC | V_NVSYNC},        /* 1920x1200@60Hz RB */
    {type: M_T_DRIVER, Clock:193250, HDisplay: 1920, HSyncStart:2056,  2256, 2592, 0, 1200, 1203, 1209, 1245, 0, V_NHSYNC | V_PVSYNC},        /* 1920x1200@60Hz */
    {type: M_T_DRIVER, Clock:245250, HDisplay: 1920, HSyncStart:2056,  2264, 2608, 0, 1200, 1203, 1209, 1255, 0, V_NHSYNC | V_PVSYNC},        /* 1920x1200@75Hz */
    {type: M_T_DRIVER, Clock:281250, HDisplay: 1920, HSyncStart:2064,  2272, 2624, 0, 1200, 1203, 1209, 1262, 0, V_NHSYNC | V_PVSYNC},        /* 1920x1200@85Hz */
    {type: M_T_DRIVER, Clock:317000, HDisplay: 1920, HSyncStart:1968,  2000, 2080, 0, 1200, 1203, 1209, 1271, 0, V_PHSYNC | V_NVSYNC},        /* 1920x1200@120Hz RB */
    {type: M_T_DRIVER, Clock:234000, HDisplay: 1920, HSyncStart:2048,  2256, 2600, 0, 1440, 1441, 1444, 1500, 0, V_NHSYNC | V_PVSYNC},        /* 1920x1440@60Hz */
    {type: M_T_DRIVER, Clock:297000, HDisplay: 1920, HSyncStart:2064,  2288, 2640, 0, 1440, 1441, 1444, 1500, 0, V_NHSYNC | V_PVSYNC},        /* 1920x1440@75Hz */
    {type: M_T_DRIVER, Clock:380500, HDisplay: 1920, HSyncStart:1968,  2000, 2080, 0, 1440, 1443, 1447, 1525, 0, V_PHSYNC | V_NVSYNC},        /* 1920x1440@120Hz RB */
    {type: M_T_DRIVER, Clock:268500, HDisplay: 2560, HSyncStart:2608,  2640, 2720, 0, 1600, 1603, 1609, 1646, 0, V_PHSYNC | V_NVSYNC},        /* 2560x1600@60Hz RB */
    {type: M_T_DRIVER, Clock:348500, HDisplay: 2560, HSyncStart:2752,  3032, 3504, 0, 1600, 1603, 1609, 1658, 0, V_NHSYNC | V_PVSYNC},        /* 2560x1600@60Hz */
    {type: M_T_DRIVER, Clock:443250, HDisplay: 2560, HSyncStart:2768,  3048, 3536, 0, 1600, 1603, 1609, 1672, 0, V_NHSYNC | V_PVSYNC},        /* 2560x1600@75Hz */
    {type: M_T_DRIVER, Clock:505250, HDisplay: 2560, HSyncStart:2768,  3048, 3536, 0, 1600, 1603, 1609, 1682, 0, V_NHSYNC | V_PVSYNC},        /* 2560x1600@85Hz */
    {type: M_T_DRIVER, Clock:552750, HDisplay: 2560, HSyncStart:2608,  2640, 2720, 0, 1600, 1603, 1609, 1694, 0, V_PHSYNC | V_NVSYNC},        /* 2560x1600@120Hz RB */
];

enum LEVEL_DMT = 0;
enum LEVEL_GTF = 1;
enum LEVEL_CVT = 2;

private int MonitorStandardTimingLevel(xf86MonPtr DDC)
{
    if (DDC.ver.revision >= 2) {
        if (DDC.ver.revision >= 4 && mixin(CVT_SUPPORTED!("DDC.features.msc"))) {
            return LEVEL_CVT;
        }
        return LEVEL_GTF;
    }
    return LEVEL_DMT;
}

private int ModeRefresh(const(DisplayModeRec)* mode)
{
    return cast(int) (xf86ModeVRefresh(mode) + 0.5);
}

/*
 * If rb is not set, then we'll not consider reduced-blanking modes as
 * part of the DMT pool.  For the 'standard' EDID mode descriptor there's
 * no way to specify whether the mode should be RB or not.
 */
private DisplayModePtr FindDMTMode(int hsize, int vsize, int refresh, Bool rb)
{
    int i = void;
    const(DisplayModeRec)* ret = void;

    for (i = 0; i < DMTModes.length; i++) {
        ret = &DMTModes[i];

        if (!rb && xf86ModeIsReduced(ret))
            continue;

        if (ret.HDisplay == hsize &&
            ret.VDisplay == vsize && refresh == ModeRefresh(ret))
            return xf86DuplicateMode(cast(_DisplayModeRec*)ret);
    }

    return null;
}

/*
 * Appendix B of the EDID 1.4 spec defines the right thing to do here.
 * If the timing given here matches a mode defined in the VESA DMT standard,
 * we _must_ use that.  If the device supports CVT modes, then we should
 * generate a CVT timing.  If both of the above fail, use GTF.
 *
 * There are some wrinkles here.  EDID 1.1 and 1.0 sinks can't really
 * "support" GTF, since it wasn't a standard yet; so if they ask for a
 * timing in this section that isn't defined in DMT, returning a GTF mode
 * may not actually be valid.  EDID 1.3 sinks often report support for
 * some CVT modes, but they are not required to support CVT timings for
 * modes in the standard timing descriptor, so we should _not_ treat them
 * as CVT-compliant (unless specified in an extension block I suppose).
 *
 * EDID 1.4 requires that all sink devices support both GTF and CVT timings
 * for modes in this section, but does say that CVT is preferred.
 */
private DisplayModePtr DDCModesFromStandardTiming(DisplayModePtr pool, std_timings* timing, ddc_quirk_t quirks, int timing_level, Bool rb)
{
    DisplayModePtr Modes = null, Mode = null;
    int i = void, hsize = void, vsize = void, refresh = void;

    for (i = 0; i < STD_TIMINGS; i++) {
        DisplayModePtr p = null;
        hsize = timing[i].hsize;
        vsize = timing[i].vsize;
        refresh = timing[i].refresh;

        /* HDTV hack, part one */
        if (refresh == 60 &&
            ((hsize == 1360 && vsize == 765) ||
             (hsize == 1368 && vsize == 769))) {
            hsize = 1366;
            vsize = 768;
        }

        /* If we already have a detailed timing for this size, don't add more */
        for (p = pool; p; p = p.next) {
            if (p.HDisplay == hsize && p.VDisplay == vsize &&
                refresh == round(xf86ModeVRefresh(p)))
                break;
        }
        if (p)
            continue;

        /* HDTV hack, because you can't say 1366 */
        if (refresh == 60 && hsize == 1366 && vsize == 768) {
            Mode = xf86CVTMode(1366, 768, 60, FALSE, FALSE);
            Mode.HDisplay = 1366;
            Mode.HSyncStart--;
            Mode.HSyncEnd--;
        }
        else if (hsize && vsize && refresh) {
            Mode = FindDMTMode(hsize, vsize, refresh, rb);

            if (!Mode) {
                if (timing_level == LEVEL_CVT)
                    /* pass rb here too? */
                    Mode = xf86CVTMode(hsize, vsize, refresh, FALSE, FALSE);
                else if (timing_level == LEVEL_GTF)
                    Mode = xf86GTFMode(hsize, vsize, refresh, FALSE, FALSE);
            }

        }

        if (Mode) {
            Mode.type = M_T_DRIVER;
            Modes = xf86ModesAdd(Modes, Mode);
        }
        Mode = null;
    }

    return Modes;
}

private void DDCModeDoInterlaceQuirks(DisplayModePtr mode)
{
    /*
     * EDID is delightfully ambiguous about how interlaced modes are to be
     * encoded.  X's internal representation is of frame height, but some
     * HDTV detailed timings are encoded as field height.
     *
     * The format list here is from CEA, in frame size.  Technically we
     * should be checking refresh rate too.  Whatever.
     */
    struct _Cea_interlaced {
        int w = void, h = void;
    }static const(_Cea_interlaced)[8] cea_interlaced = [
        {1920, 1080},
        {720, 480},
        {1440, 480},
        {2880, 480},
        {720, 576},
        {1440, 576},
        {2880, 576},
    ];
    int i = void;

    for (i = 0; i < cea_interlaced.length; i++) {
        if ((mode.HDisplay == cea_interlaced[i].w) &&
            (mode.VDisplay == cea_interlaced[i].h / 2)) {
            mode.VDisplay *= 2;
            mode.VSyncStart *= 2;
            mode.VSyncEnd *= 2;
            mode.VTotal *= 2;
            mode.VTotal |= 1;
        }
    }

    mode.Flags |= V_INTERLACE;
}

/*
 *
 */
private DisplayModePtr DDCModeFromDetailedTiming(int scrnIndex, detailed_timings* timing, Bool preferred, ddc_quirk_t quirks)
{
    DisplayModePtr Mode = void;

    /*
     * Refuse to create modes that are insufficiently large.  64 is a random
     * number, maybe the spec says something about what the minimum is.  In
     * particular I see this frequently with _old_ EDID, 1.0 or so, so maybe
     * our parser is just being too aggressive there.
     */
    if (timing.h_active < 64 || timing.v_active < 64) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "%s: Ignoring tiny %dx%d mode\n", __FUNCTION__.ptr,
                   timing.h_active, timing.v_active);
        return null;
    }

    /* We don't do stereo */
    if (timing.stereo) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "%s: Ignoring: We don't handle stereo.\n", __FUNCTION__.ptr);
        return null;
    }

    /* We only do separate sync currently */
    if (timing.sync != 0x03) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "%s: %dx%d Warning: We only handle separate"
                   ~ " sync.\n", __FUNCTION__.ptr, timing.h_active, timing.v_active);
    }

    Mode = cast(_DisplayModeRec*)XNFcallocarray(1, DisplayModeRec.sizeof);

    Mode.type = M_T_DRIVER;
    if (preferred)
        Mode.type |= M_T_PREFERRED;

    if ((quirks & DDC_QUIRK_135_CLOCK_TOO_HIGH) && timing.clock == 135000000)
        Mode.Clock = 108880;
    else
        Mode.Clock = cast(int)(timing.clock / 1000.0);

    Mode.HDisplay = timing.h_active;
    Mode.HSyncStart = timing.h_active + timing.h_sync_off;
    Mode.HSyncEnd = Mode.HSyncStart + timing.h_sync_width;
    Mode.HTotal = timing.h_active + timing.h_blanking;

    Mode.VDisplay = timing.v_active;
    Mode.VSyncStart = timing.v_active + timing.v_sync_off;
    Mode.VSyncEnd = Mode.VSyncStart + timing.v_sync_width;
    Mode.VTotal = timing.v_active + timing.v_blanking;

    /* perform basic check on the detail timing */
    if (Mode.HSyncEnd > Mode.HTotal || Mode.VSyncEnd > Mode.VTotal) {
        free(Mode);
        return null;
    }

    /* We ignore h/v_size and h/v_border for now. */

    if (timing.interlaced)
        DDCModeDoInterlaceQuirks(Mode);

    if (quirks & DDC_QUIRK_DETAILED_SYNC_PP)
        Mode.Flags |= V_PVSYNC | V_PHSYNC;
    else {
        if (timing.misc & 0x02)
            Mode.Flags |= V_PVSYNC;
        else
            Mode.Flags |= V_NVSYNC;

        if (timing.misc & 0x01)
            Mode.Flags |= V_PHSYNC;
        else
            Mode.Flags |= V_NHSYNC;
    }

    xf86SetModeDefaultName(Mode);

    return Mode;
}

private DisplayModePtr DDCModesFromCVT(int scrnIndex, cvt_timings* t)
{
    DisplayModePtr modes = null;
    int i = void;

    for (i = 0; i < 4; i++) {
        if (t[i].height) {
            if (t[i].rates & 0x10)
                modes = xf86ModesAdd(modes,
                                     xf86CVTMode(t[i].width, t[i].height, 50, 0,
                                                 0));
            if (t[i].rates & 0x08)
                modes = xf86ModesAdd(modes,
                                     xf86CVTMode(t[i].width, t[i].height, 60, 0,
                                                 0));
            if (t[i].rates & 0x04)
                modes = xf86ModesAdd(modes,
                                     xf86CVTMode(t[i].width, t[i].height, 75, 0,
                                                 0));
            if (t[i].rates & 0x02)
                modes = xf86ModesAdd(modes,
                                     xf86CVTMode(t[i].width, t[i].height, 85, 0,
                                                 0));
            if (t[i].rates & 0x01)
                modes = xf86ModesAdd(modes,
                                     xf86CVTMode(t[i].width, t[i].height, 60, 1,
                                                 0));
        }
        else
            break;
    }

    return modes;
}

struct _EstIIIModes {
    short w;
    short h;
    short r;
    short rb;
}private const(_EstIIIModes)[49] EstIIIModes = [
        /* byte 6 */
    {640, 350, 85, 0},
    {640, 400, 85, 0},
    {720, 400, 85, 0},
    {640, 480, 85, 0},
    {848, 480, 60, 0},
    {800, 600, 85, 0},
    {1024, 768, 85, 0},
    {1152, 864, 75, 0},
        /* byte 7 */
    {1280, 768, 60, 1},
    {1280, 768, 60, 0},
    {1280, 768, 75, 0},
    {1280, 768, 85, 0},
    {1280, 960, 60, 0},
    {1280, 960, 85, 0},
    {1280, 1024, 60, 0},
    {1280, 1024, 85, 0},
        /* byte 8 */
    {1360, 768, 60, 0},
    {1440, 900, 60, 1},
    {1440, 900, 60, 0},
    {1440, 900, 75, 0},
    {1440, 900, 85, 0},
    {1400, 1050, 60, 1},
    {1400, 1050, 60, 0},
    {1400, 1050, 75, 0},
        /* byte 9 */
    {1400, 1050, 85, 0},
    {1680, 1050, 60, 1},
    {1680, 1050, 60, 0},
    {1680, 1050, 75, 0},
    {1680, 1050, 85, 0},
    {1600, 1200, 60, 0},
    {1600, 1200, 65, 0},
    {1600, 1200, 70, 0},
        /* byte 10 */
    {1600, 1200, 75, 0},
    {1600, 1200, 85, 0},
    {1792, 1344, 60, 0},
    {1792, 1344, 75, 0},
    {1856, 1392, 60, 0},
    {1856, 1392, 75, 0},
    {1920, 1200, 60, 1},
    {1920, 1200, 60, 0},
        /* byte 11 */
    {1920, 1200, 75, 0},
    {1920, 1200, 85, 0},
    {1920, 1440, 60, 0},
    {1920, 1440, 75, 0},
        /* fill up last byte */
    {0,0,0,0},
    {0,0,0,0},
    {0,0,0,0},
    {0,0,0,0},
];

private DisplayModePtr DDCModesFromEstIII(ubyte* est)
{
    DisplayModePtr modes = null;
    int i = void, j = void, m = void;

    for (i = 0; i < 6; i++) {
        for (j = 7; j >= 0; j--) {
            if (est[i] & (1 << j)) {
                m = (i * 8) + (7 - j);
                if (EstIIIModes[m].w)
                    modes = xf86ModesAdd(modes,
                                     FindDMTMode(EstIIIModes[m].w,
                                                 EstIIIModes[m].h,
                                                 EstIIIModes[m].r,
                                                 EstIIIModes[m].rb));
            }
        }
    }

    return modes;
}

/*
 * This is only valid when the sink claims to be continuous-frequency
 * but does not supply a detailed range descriptor.  Such sinks are
 * arguably broken.  Currently the mode validation code isn't aware of
 * this; the non-RANDR code even punts the decision of optional sync
 * range checking to the driver.  Loss.
 */
private void DDCGuessRangesFromModes(int scrnIndex, MonPtr Monitor, DisplayModePtr Modes)
{
    DisplayModePtr Mode = Modes;

    if (!Monitor || !Modes)
        return;

    /* set up the ranges for scanning through the modes */
    Monitor.nHsync = 1;
    Monitor.hsync[0].lo = 1024.0;
    Monitor.hsync[0].hi = 0.0;

    Monitor.nVrefresh = 1;
    Monitor.vrefresh[0].lo = 1024.0;
    Monitor.vrefresh[0].hi = 0.0;

    while (Mode) {
        if (!Mode.HSync)
            Mode.HSync = (cast(float) Mode.Clock) / (cast(float) Mode.HTotal);

        if (!Mode.VRefresh)
            Mode.VRefresh = (1000.0 * (cast(float) Mode.Clock)) /
                (cast(float) (Mode.HTotal * Mode.VTotal));

        if (Mode.HSync < Monitor.hsync[0].lo)
            Monitor.hsync[0].lo = Mode.HSync;

        if (Mode.HSync > Monitor.hsync[0].hi)
            Monitor.hsync[0].hi = Mode.HSync;

        if (Mode.VRefresh < Monitor.vrefresh[0].lo)
            Monitor.vrefresh[0].lo = Mode.VRefresh;

        if (Mode.VRefresh > Monitor.vrefresh[0].hi)
            Monitor.vrefresh[0].hi = Mode.VRefresh;

        Mode = Mode.next;
    }
}

ddc_quirk_t xf86DDCDetectQuirks(int scrnIndex, xf86MonPtr DDC, Bool verbose)
{
    ddc_quirk_t quirks = void;
    int i = void;

    quirks = DDC_QUIRK_NONE;
    for (i = 0; ddc_quirks[i].detect; i++) {
        if (ddc_quirks[i].detect(scrnIndex, DDC)) {
            if (verbose) {
                xf86DrvMsg(scrnIndex, X_INFO, "    EDID quirk: %s\n",
                           ddc_quirks[i].description);
            }
            quirks |= ddc_quirks[i].quirk;
        }
    }

    return quirks;
}

void xf86DetTimingApplyQuirks(detailed_monitor_section* det_mon, ddc_quirk_t quirks, int hsize, int vsize)
{
    if (det_mon.type != DT)
        return;

    if (quirks & DDC_QUIRK_DETAILED_H_IN_CM)
        det_mon.section.d_timings.h_size *= 10;

    if (quirks & DDC_QUIRK_DETAILED_V_IN_CM)
        det_mon.section.d_timings.v_size *= 10;

    if (quirks & DDC_QUIRK_DETAILED_USE_MAXIMUM_SIZE) {
        det_mon.section.d_timings.h_size = 10 * hsize;
        det_mon.section.d_timings.v_size = 10 * vsize;
    }
}

/**
 * Applies monitor-specific quirks to the decoded EDID information.
 *
 * Note that some quirks applying to the mode list are still implemented in
 * xf86DDCGetModes.
 */
void xf86DDCApplyQuirks(int scrnIndex, xf86MonPtr DDC)
{
    ddc_quirk_t quirks = xf86DDCDetectQuirks(scrnIndex, DDC, FALSE);
    int i = void;

    for (i = 0; i < DET_TIMINGS; i++) {
        xf86DetTimingApplyQuirks(DDC.det_mon.ptr + i, quirks,
                                 DDC.features.hsize, DDC.features.vsize);
    }
}

/**
 * Walks the modes list, finding the mode with the largest area which is
 * closest to the target refresh rate, and marks it as the only preferred mode.
*/
private void xf86DDCSetPreferredRefresh(int scrnIndex, DisplayModePtr modes, float target_refresh)
{
    DisplayModePtr mode = void, best = modes;

    for (mode = modes; mode; mode = mode.next) {
        mode.type &= ~M_T_PREFERRED;

        if (mode == best)
            continue;

        if (mode.HDisplay * mode.VDisplay > best.HDisplay * best.VDisplay) {
            best = mode;
            continue;
        }
        if (mode.HDisplay * mode.VDisplay == best.HDisplay * best.VDisplay) {
            double mode_refresh = xf86ModeVRefresh(mode);
            double best_refresh = xf86ModeVRefresh(best);
            double mode_dist = fabs(mode_refresh - target_refresh);
            double best_dist = fabs(best_refresh - target_refresh);

            if (mode_dist < best_dist) {
                best = mode;
                continue;
            }
        }
    }
    if (best)
        best.type |= M_T_PREFERRED;
}

enum CEA_VIDEO_MODES_NUM =  64;
private const(DisplayModeRec)[CEA_VIDEO_MODES_NUM] CEAVideoModes = [
    {type: M_T_DRIVER, 25175, 640, 656, 752, 800, 0, 480, 490, 492, 525, 0, V_NHSYNC | V_NVSYNC}, /* VIC 1:640x480@60Hz */
    {type: M_T_DRIVER, 27000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC}, /* VIC 2:720x480@60Hz */
    {type: M_T_DRIVER, 27000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC}, /* VIC 3:720x480@60Hz */
    {type: M_T_DRIVER, 74250, 1280, 1390, 1430, 1650, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},     /* VIC 4: 1280x720@60Hz */
    {type: M_T_DRIVER, 74250, 1920, 2008, 2052, 2200, 0, 1080, 1084, 1094, 1125, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE},   /* VIC 5:1920x1080i@60Hz */
    {type: M_T_DRIVER, 27000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 6:1440x480i@60Hz */
    {type: M_T_DRIVER, 27000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 7:1440x480i@60Hz */
    {type: M_T_DRIVER, 27000, 1440, 1478, 1602, 1716, 0, 240, 244, 247, 262, 0, V_NHSYNC | V_NVSYNC},     /* VIC 8:1440x240@60Hz */
    {type: M_T_DRIVER, 27000, 1440, 1478, 1602, 1716, 0, 240, 244, 247, 262, 0, V_NHSYNC | V_NVSYNC},     /* VIC 9:1440x240@60Hz */
    {type: M_T_DRIVER, 54000, 2880, 2956, 3204, 3432, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 10:2880x480i@60Hz */
    {type: M_T_DRIVER, 54000, 2880, 2956, 3204, 3432, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 11:2880x480i@60Hz */
    {type: M_T_DRIVER, 54000, 2880, 2956, 3204, 3432, 0, 240, 244, 247, 262, 0, V_NHSYNC | V_NVSYNC},     /* VIC 12:2880x240@60Hz */
    {type: M_T_DRIVER, 54000, 2880, 2956, 3204, 3432, 0, 240, 244, 247, 262, 0, V_NHSYNC | V_NVSYNC},     /* VIC 13:2880x240@60Hz */
    {type: M_T_DRIVER, 54000, 1440, 1472, 1596, 1716, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},     /* VIC 14:1440x480@60Hz */
    {type: M_T_DRIVER, 54000, 1440, 1472, 1596, 1716, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},     /* VIC 15:1440x480@60Hz */
    {type: M_T_DRIVER, 148500, 1920, 2008, 2052, 2200, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC},        /* VIC 16:1920x1080@60Hz */
    {type: M_T_DRIVER, 27000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC}, /* VIC 17:720x576@50Hz */
    {type: M_T_DRIVER, 27000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC}, /* VIC 18:720x576@50Hz */
    {type: M_T_DRIVER, 74250, 1280, 1720, 1760, 1980, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},     /* VIC 19: 1280x720@50Hz */
    {type: M_T_DRIVER, 74250, 1920, 2448, 2492, 2640, 0, 1080, 1084, 1094, 1125, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE},   /* VIC 20:1920x1080i@50Hz */
    {type: M_T_DRIVER, 27000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 21:1440x576i@50Hz */
    {type: M_T_DRIVER, 27000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 22:1440x576i@50Hz */
    {type: M_T_DRIVER, 27000, 1440, 1464, 1590, 1728, 0, 288, 290, 293, 312, 0, V_NHSYNC | V_NVSYNC},     /* VIC 23:1440x288@50Hz */
    {type: M_T_DRIVER, 27000, 1440, 1464, 1590, 1728, 0, 288, 290, 293, 312, 0, V_NHSYNC | V_NVSYNC},     /* VIC 24:1440x288@50Hz */
    {type: M_T_DRIVER, 54000, 2880, 2928, 3180, 3456, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 25:2880x576i@50Hz */
    {type: M_T_DRIVER, 54000, 2880, 2928, 3180, 3456, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 26:2880x576i@50Hz */
    {type: M_T_DRIVER, 54000, 2880, 2928, 3180, 3456, 0, 288, 290, 293, 312, 0, V_NHSYNC | V_NVSYNC},     /* VIC 27:2880x288@50Hz */
    {type: M_T_DRIVER, 54000, 2880, 2928, 3180, 3456, 0, 288, 290, 293, 312, 0, V_NHSYNC | V_NVSYNC},     /* VIC 28:2880x288@50Hz */
    {type: M_T_DRIVER, 54000, 1440, 1464, 1592, 1728, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},     /* VIC 29:1440x576@50Hz */
    {type: M_T_DRIVER, 54000, 1440, 1464, 1592, 1728, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},     /* VIC 30:1440x576@50Hz */
    {type: M_T_DRIVER, 148500, 1920, 2448, 2492, 2640, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC},        /* VIC 31:1920x1080@50Hz */
    {type: M_T_DRIVER, 74250, 1920, 2558, 2602, 2750, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC}, /* VIC 32:1920x1080@24Hz */
    {type: M_T_DRIVER, 74250, 1920, 2448, 2492, 2640, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC}, /* VIC 33:1920x1080@25Hz */
    {type: M_T_DRIVER, 74250, 1920, 2008, 2052, 2200, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC}, /* VIC 34:1920x1080@30Hz */
    {type: M_T_DRIVER, 108000, 2880, 2944, 3192, 3432, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},    /* VIC 35:2880x480@60Hz */
    {type: M_T_DRIVER, 108000, 2880, 2944, 3192, 3432, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},    /* VIC 36:2880x480@60Hz */
    {type: M_T_DRIVER, 108000, 2880, 2928, 3184, 3456, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},    /* VIC 37:2880x576@50Hz */
    {type: M_T_DRIVER, 108000, 2880, 2928, 3184, 3456, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},    /* VIC 38:2880x576@50Hz */
    {type: M_T_DRIVER, 72000, 1920, 1952, 2120, 2304, 0, 1080, 1126, 1136, 1250, 0, V_PHSYNC | V_NVSYNC | V_INTERLACE},   /* VIC 39:1920x1080i@50Hz */
    {type: M_T_DRIVER, 148500, 1920, 2448, 2492, 2640, 0, 1080, 1084, 1094, 1125, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE},  /* VIC 40:1920x1080i@100Hz */
    {type: M_T_DRIVER, 148500, 1280, 1720, 1760, 1980, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},    /* VIC 41:1280x720@100Hz */
    {type: M_T_DRIVER, 54000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC}, /* VIC 42:720x576@100Hz */
    {type: M_T_DRIVER, 54000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC}, /* VIC 43:720x576@100Hz */
    {type: M_T_DRIVER, 54000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC},     /* VIC 44:1440x576i@100Hz */
    {type: M_T_DRIVER, 54000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC},     /* VIC 45:1440x576i@100Hz */
    {type: M_T_DRIVER, 148500, 1920, 2008, 2052, 2200, 0, 1080, 1084, 1094, 1125, 0, V_PHSYNC | V_PVSYNC | V_INTERLACE},  /* VIC 46:1920x1080i@120Hz */
    {type: M_T_DRIVER, 148500, 1280, 1390, 1430, 1650, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},    /* VIC 47:1280x720@120Hz */
    {type: M_T_DRIVER, 54000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC}, /* VIC 48:720x480@120Hz */
    {type: M_T_DRIVER, 54000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC}, /* VIC 49:720x480@120Hz */
    {type: M_T_DRIVER, 54000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 50:1440x480i@120Hz */
    {type: M_T_DRIVER, 54000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},       /* VIC 51:1440x480i@120Hz */
    {type: M_T_DRIVER, 108000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},        /* VIC 52:720x576@200Hz */
    {type: M_T_DRIVER, 108000, 720, 732, 796, 864, 0, 576, 581, 586, 625, 0, V_NHSYNC | V_NVSYNC},        /* VIC 53:720x576@200Hz */
    {type: M_T_DRIVER, 108000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},      /* VIC 54:1440x576i@200Hz */
    {type: M_T_DRIVER, 108000, 1440, 1464, 1590, 1728, 0, 576, 580, 586, 625, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},      /* VIC 55:1440x576i@200Hz */
    {type: M_T_DRIVER, 108000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},        /* VIC 56:720x480@240Hz */
    {type: M_T_DRIVER, 108000, 720, 736, 798, 858, 0, 480, 489, 495, 525, 0, V_NHSYNC | V_NVSYNC},        /* VIC 57:720x480@240Hz */
    {type: M_T_DRIVER, 108000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},      /* VIC 58:1440x480i@240 */
    {type: M_T_DRIVER, 108000, 1440, 1478, 1602, 1716, 0, 480, 488, 494, 525, 0, V_NHSYNC | V_NVSYNC | V_INTERLACE},      /* VIC 59:1440x480i@240 */
    {type: M_T_DRIVER, 59400, 1280, 3040, 3080, 3300, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},     /* VIC 60: 1280x720@24Hz */
    {type: M_T_DRIVER, 74250, 1280, 3700, 3740, 3960, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},     /* VIC 61: 1280x720@25Hz */
    {type: M_T_DRIVER, 74250, 1280, 3040, 3080, 3300, 0, 720, 725, 730, 750, 0, V_PHSYNC | V_PVSYNC},     /* VIC 62: 1280x720@30Hz */
    {type: M_T_DRIVER, 297000, 1920, 2008, 2052, 2200, 0, 1080, 1084, 1089, 1125, 0, V_PHSYNC | V_PVSYNC},        /* VIC 63: 1920x1080@120Hz */
    {type: M_T_DRIVER, 297000, 1920, 2448, 2492, 2640, 0, 1080, 1084, 1094, 1125, 0, V_PHSYNC | V_PVSYNC},        /* VIC 64:1920x1080@100Hz */
];

/* chose mode line by cea short video descriptor*/
private void handle_cea_svd(cea_video_block* video, void* data)
{
    DisplayModePtr Mode = void;
    DisplayModePtr* Modes = cast(DisplayModePtr*) data;
    int vid = void;

    vid = video.video_code & 0x7f;
    if (vid >= 1 && vid <= CEA_VIDEO_MODES_NUM) {
        Mode = xf86DuplicateMode(cast(_DisplayModeRec*)(CEAVideoModes.ptr + (vid - 1)));
        *Modes = xf86ModesAdd(*Modes, Mode);
    }
}

private DisplayModePtr DDCModesFromCEAExtension(int scrnIndex, xf86MonPtr mon_ptr)
{
    DisplayModePtr Modes = null;

    xf86ForEachVideoBlock(mon_ptr, &handle_cea_svd, &Modes);

    return Modes;
}

struct det_modes_parameter {
    xf86MonPtr DDC;
    ddc_quirk_t quirks;
    DisplayModePtr Modes;
    Bool rb;
    Bool preferred;
    int timing_level;
}

private void handle_detailed_modes(detailed_monitor_section* det_mon, void* data)
{
    DisplayModePtr Mode = void;
    det_modes_parameter* p = cast(det_modes_parameter*) data;

    xf86DetTimingApplyQuirks(det_mon, p.quirks,
                             p.DDC.features.hsize, p.DDC.features.vsize);

    switch (det_mon.type) {
    case DT:
        Mode = DDCModeFromDetailedTiming(p.DDC.scrnIndex,
                                         &det_mon.section.d_timings,
                                         p.preferred, p.quirks);
        p.preferred = FALSE;
        p.Modes = xf86ModesAdd(p.Modes, Mode);
        break;
    case DS_STD_TIMINGS:
        Mode = DDCModesFromStandardTiming(p.Modes,
                                          det_mon.section.std_t.ptr,
                                          p.quirks, p.timing_level, p.rb);
        p.Modes = xf86ModesAdd(p.Modes, Mode);
        break;
    case DS_CVT:
        Mode = DDCModesFromCVT(p.DDC.scrnIndex, det_mon.section.cvt.ptr);
        p.Modes = xf86ModesAdd(p.Modes, Mode);
        break;
    case DS_EST_III:
        Mode = DDCModesFromEstIII(det_mon.section.est_iii.ptr);
        p.Modes = xf86ModesAdd(p.Modes, Mode);
        break;
    default:
        break;
    }
}

DisplayModePtr xf86DDCGetModes(int scrnIndex, xf86MonPtr DDC)
{
    DisplayModePtr Modes = null, Mode = void;
    ddc_quirk_t quirks = void;
    Bool preferred = void, rb = void;
    int timing_level = void;
    det_modes_parameter p = void;

    xf86DrvMsg(scrnIndex, X_INFO, "EDID vendor \"%s\", prod id %d\n",
               DDC.vendor_.name.ptr, DDC.vendor_.prod_id);

    quirks = xf86DDCDetectQuirks(scrnIndex, DDC, TRUE);

    preferred = mixin(PREFERRED_TIMING_MODE!("DDC.features.msc"));
    if (DDC.ver.revision >= 4)
        preferred = TRUE;
    if (quirks & DDC_QUIRK_FIRST_DETAILED_PREFERRED)
        preferred = TRUE;
    if (quirks & (DDC_QUIRK_PREFER_LARGE_60 | DDC_QUIRK_PREFER_LARGE_75))
        preferred = FALSE;

    rb = xf86MonitorSupportsReducedBlanking(DDC);

    timing_level = MonitorStandardTimingLevel(DDC);

    p.quirks = quirks;
    p.DDC = DDC;
    p.Modes = Modes;
    p.rb = rb;
    p.preferred = preferred;
    p.timing_level = timing_level;
    xf86ForEachDetailedBlock(DDC, &handle_detailed_modes, &p);
    Modes = p.Modes;

    /* Add cea-extension mode timings */
    Mode = DDCModesFromCEAExtension(scrnIndex, DDC);
    Modes = xf86ModesAdd(Modes, Mode);

    /* Add established timings */
    Mode = DDCModesFromEstablished(scrnIndex, &DDC.timings1, quirks);
    Modes = xf86ModesAdd(Modes, Mode);

    /* Add standard timings */
    Mode = DDCModesFromStandardTiming(Modes, DDC.timings2.ptr, quirks,
                                      timing_level, rb);
    Modes = xf86ModesAdd(Modes, Mode);

    if (quirks & DDC_QUIRK_PREFER_LARGE_60)
        xf86DDCSetPreferredRefresh(scrnIndex, Modes, 60);

    if (quirks & DDC_QUIRK_PREFER_LARGE_75)
        xf86DDCSetPreferredRefresh(scrnIndex, Modes, 75);

    Modes = xf86PruneDuplicateModes(Modes);

    return Modes;
}

struct det_mon_parameter {
    MonPtr Monitor;
    ddc_quirk_t quirks;
    Bool have_hsync;
    Bool have_vrefresh;
    Bool have_maxpixclock;
}

private void handle_detailed_monset(detailed_monitor_section* det_mon, void* data)
{
    int clock = void;
    det_mon_parameter* p = cast(det_mon_parameter*) data;
    int scrnIndex = (cast(xf86MonPtr) (p.Monitor.DDC)).scrnIndex;

    switch (det_mon.type) {
    case DS_RANGES:
        if (!p.have_hsync) {
            if (!p.Monitor.nHsync)
                xf86DrvMsg(scrnIndex, X_INFO,
                           "Using EDID range info for horizontal sync\n");
            p.Monitor.hsync[p.Monitor.nHsync].lo =
                det_mon.section.ranges.min_h;
            p.Monitor.hsync[p.Monitor.nHsync].hi =
                det_mon.section.ranges.max_h;
            p.Monitor.nHsync++;
        }
        else {
            xf86DrvMsg(scrnIndex, X_INFO,
                       "Using hsync ranges from config file\n");
        }

        if (!p.have_vrefresh) {
            if (!p.Monitor.nVrefresh)
                xf86DrvMsg(scrnIndex, X_INFO,
                           "Using EDID range info for vertical refresh\n");
            p.Monitor.vrefresh[p.Monitor.nVrefresh].lo =
                det_mon.section.ranges.min_v;
            p.Monitor.vrefresh[p.Monitor.nVrefresh].hi =
                det_mon.section.ranges.max_v;
            p.Monitor.nVrefresh++;
        }
        else {
            xf86DrvMsg(scrnIndex, X_INFO,
                       "Using vrefresh ranges from config file\n");
        }

        clock = det_mon.section.ranges.max_clock * 1000;
        if (p.quirks & DDC_QUIRK_DVI_SINGLE_LINK)
            clock = min(clock, 165000);
        if (!p.have_maxpixclock && clock > p.Monitor.maxPixClock)
            p.Monitor.maxPixClock = clock;

        break;
    default:
        break;
    }
}

/*
 * Fill out MonPtr with xf86MonPtr information.
 */
void xf86EdidMonitorSet(int scrnIndex, MonPtr Monitor, xf86MonPtr DDC)
{
    DisplayModePtr Modes = null, Mode = void;
    det_mon_parameter p = void;

    if (!Monitor || !DDC)
        return;

    Monitor.DDC = DDC;

    if (Monitor.widthmm <= 0 || Monitor.heightmm <= 0) {
        Monitor.widthmm = 10 * DDC.features.hsize;
        Monitor.heightmm = 10 * DDC.features.vsize;
    }

    Monitor.reducedblanking = xf86MonitorSupportsReducedBlanking(DDC);

    Modes = xf86DDCGetModes(scrnIndex, DDC);

    /* Go through the detailed monitor sections */
    p.Monitor = Monitor;
    p.quirks = xf86DDCDetectQuirks(scrnIndex, cast(_Xf86Monitor*)Monitor.DDC, FALSE);
    p.have_hsync = (Monitor.nHsync != 0);
    p.have_vrefresh = (Monitor.nVrefresh != 0);
    p.have_maxpixclock = (Monitor.maxPixClock != 0);
    xf86ForEachDetailedBlock(DDC, &handle_detailed_monset, &p);

    if (Modes) {
        /* Print Modes */
        xf86DrvMsg(scrnIndex, X_INFO, "Printing DDC gathered Modelines:\n");

        Mode = Modes;
        while (Mode) {
            xf86PrintModeline(scrnIndex, Mode);
            Mode = Mode.next;
        }

        /* Do we still need ranges to be filled in? */
        if (!Monitor.nHsync || !Monitor.nVrefresh)
            DDCGuessRangesFromModes(scrnIndex, Monitor, Modes);

        /* add to MonPtr */
        if (Monitor.Modes) {
            Monitor.Last.next = Modes;
            Modes.prev = Monitor.Last;
        }
        else {
            Monitor.Modes = Modes;
        }

        Monitor.Modes = xf86PruneDuplicateModes(Monitor.Modes);

        /* Update pointer to last mode */
        for (Mode = Monitor.Modes; Mode && Mode.next; Mode = Mode.next) {}
        Monitor.Last = Mode;
    }
}
