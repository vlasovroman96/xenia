module print_edid;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1998 by Egbert Eich <Egbert.Eich@Physik.TU-Darmstadt.DE>
 * Copyright 2007 Red Hat, Inc.
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
 *
 * print_edid.c: print out all information retrieved from display device
 */
import build.xorg_config;

import include.misc;
import include.xf86;
import include.xf86_OSproc;;
import xf86DDC_priv;
import edid_priv;
import hw.xfree86.common.xf86Helper;
import interpret_edid;
import xf86EdidModes;
import hw.xfree86.common.edid;

/* display type, analog */
enum DISP_MONO = 0;
enum DISP_RGB = 1;
enum DISP_MULTCOLOR = 2;

/* display color encodings, digital */
enum DISP_YCRCB444 = 0x01;
enum DISP_YCRCB422 = 0x02;

/* DPMS features */
enum string DPMS_STANDBY(string x) = `(` ~ x ~ ` & 0x04)`;
enum string DPMS_SUSPEND(string x) = `(` ~ x ~ ` & 0x02)`;
enum string DPMS_OFF(string x) = `(` ~ x ~ ` & 0x01)`;

/* input voltage level */
enum V070 = 0                  /* 0.700V/0.300V */;
enum V071 = 1                  /* 0.714V/0.286V */;
enum V100 = 2                  /* 1.000V/0.400V */;
enum V007 = 3                  /* 0.700V/0.000V */;

enum string STD_COLOR_SPACE(string x) = `(` ~ x ~ ` & 0x4)`;
enum string GFT_SUPPORTED(string x) = `(` ~ x ~ ` & 0x1)`;

enum EDID_WIDTH =	16;

/* detailed timing misc */
enum string IS_RIGHT_STEREO(string x) = `(` ~ x ~ ` & 0x01)`;
enum string IS_LEFT_STEREO(string x) = `(` ~ x ~ ` & 0x02)`;
enum string IS_4WAY_STEREO(string x) = `(` ~ x ~ ` & 0x03)`;

/* sync characteristics */
enum string SEP_SYNC(string x) = `(` ~ x ~ ` & 0x08)`;
enum string COMP_SYNC(string x) = `(` ~ x ~ ` & 0x04)`;
enum string SYNC_O_GREEN(string x) = `(` ~ x ~ ` & 0x02)`;
enum string SYNC_SERR(string x) = `(` ~ x ~ ` & 0x01)`;

private void print_vendor(int scrnIndex, vendor* c)
{
    xf86DrvMsg(scrnIndex, X_INFO, "Manufacturer: %s  Model: %x  Serial#: %u\n",
               cast(char*) &c.name, c.prod_id, c.serial);
    xf86DrvMsg(scrnIndex, X_INFO, "Year: %u  Week: %u\n", c.year, c.week);
}

private void print_version(int scrnIndex, edid_version* c)
{
    xf86DrvMsg(scrnIndex, X_INFO, "EDID Version: %u.%u\n", c.version_,
               c.revision);
}

private const(char)*[7] digital_interfaces = [
    "undefined",
    "DVI",
    "HDMI-a",
    "HDMI-b",
    "MDDI",
    "DisplayPort",
    "unknown"
];

private void print_input_features(int scrnIndex, disp_features* c, edid_version* v)
{
    if (mixin(DIGITAL!("c.input_type"))) {
        xf86DrvMsg(scrnIndex, X_INFO, "Digital Display Input\n");
        if (v.revision == 2 || v.revision == 3) {
            if (c.input_dfp)
                xf86DrvMsg(scrnIndex, X_INFO, "DFP 1.x compatible TMDS\n");
        }
        else if (v.revision >= 4) {
            int interface_ = c.input_interface;
            int bpc = c.input_bpc;

            if (interface_ > 6)
                interface_ = 6;  /* unknown */
            if (bpc == 0 || bpc == 7)
                xf86DrvMsg(scrnIndex, X_INFO, "Undefined color depth\n");
            else
                xf86DrvMsg(scrnIndex, X_INFO, "%d bits per channel\n",
                           bpc * 2 + 4);
            xf86DrvMsg(scrnIndex, X_INFO, "Digital interface is %s\n",
                       digital_interfaces[interface_]);
        }
    }
    else {
        xf86DrvMsg(scrnIndex, X_INFO, "Analog Display Input,  ");
        xf86ErrorF("Input Voltage Level: ");
        switch (c.input_voltage) {
        case V070:
            xf86ErrorF("0.700/0.300 V\n");
            break;
        case V071:
            xf86ErrorF("0.714/0.286 V\n");
            break;
        case V100:
            xf86ErrorF("1.000/0.400 V\n");
            break;
        case V007:
            xf86ErrorF("0.700/0.700 V\n");
            break;
        default:
            xf86ErrorF("undefined\n");
        }
        if (c.input_setup)
            xf86DrvMsg(scrnIndex, X_INFO, "Signal levels configurable\n");
        xf86DrvMsg(scrnIndex, X_INFO, "Sync:");
        if (mixin(SEP_SYNC!(`c.input_sync`)))
            xf86ErrorF("  Separate");
        if (mixin(COMP_SYNC!(`c.input_sync`)))
            xf86ErrorF("  Composite");
        if (mixin(SYNC_O_GREEN!(`c.input_sync`)))
            xf86ErrorF("  SyncOnGreen");
        if (mixin(SYNC_SERR!(`c.input_sync`)))
            xf86ErrorF("Serration on. "
                       ~ "V.Sync Pulse req. if CompSync or SyncOnGreen\n");
        else
            xf86ErrorF("\n");
    }
}

private void print_dpms_features(int scrnIndex, disp_features* c, edid_version* v)
{
    if (c.dpms) {
        xf86DrvMsg(scrnIndex, X_INFO, "DPMS capabilities:");
        if (mixin(DPMS_STANDBY!(`c.dpms`)))
            xf86ErrorF(" StandBy");
        if (mixin(DPMS_SUSPEND!(`c.dpms`)))
            xf86ErrorF(" Suspend");
        if (mixin(DPMS_OFF!(`c.dpms`)))
            xf86ErrorF(" Off");
    }
    else
        xf86DrvMsg(scrnIndex, X_INFO, "No DPMS capabilities specified");
    if (!c.input_type) {       /* analog */
        switch (c.display_type) {
        case DISP_MONO:
            xf86ErrorF("; Monochrome/GrayScale Display\n");
            break;
        case DISP_RGB:
            xf86ErrorF("; RGB/Color Display\n");
            break;
        case DISP_MULTCOLOR:
            xf86ErrorF("; Non RGB Multicolor Display\n");
            break;
        default:
            xf86ErrorF("\n");
            break;
        }
    }
    else {
        int enc = c.display_type;

        xf86ErrorF("\n");
        xf86DrvMsg(scrnIndex, X_INFO, "Supported color encodings: "
                   ~ "RGB 4:4:4 %s%s\n",
                   enc & DISP_YCRCB444 ? "YCrCb 4:4:4 ".ptr : "",
                   enc & DISP_YCRCB422 ? "YCrCb 4:2:2".ptr : "");
    }

    if (mixin(STD_COLOR_SPACE!(`c.msc`)))
        xf86DrvMsg(scrnIndex, X_INFO,
                   "Default color space is primary color space\n");

    if (mixin(PREFERRED_TIMING_MODE!("c.msc")) || v.revision >= 4) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "First detailed timing is preferred mode\n");
        if (v.revision >= 4)
            xf86DrvMsg(scrnIndex, X_INFO,
                       "Preferred mode is native pixel format and refresh rate\n");
    }
    else if (v.revision == 3) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "First detailed timing not preferred "
                   ~ "mode in violation of standard!\n");
    }

    if (v.revision >= 4) {
        if (mixin(GFT_SUPPORTED!(`c.msc`))) {
            xf86DrvMsg(scrnIndex, X_INFO, "Display is continuous-frequency\n");
        }
    }
    else {
        if (mixin(GFT_SUPPORTED!(`c.msc`)))
            xf86DrvMsg(scrnIndex, X_INFO, "GTF timings supported\n");
    }
}

private void print_whitepoint(int scrnIndex, disp_features* disp)
{
    xf86DrvMsg(scrnIndex, X_INFO, "redX: %.3f redY: %.3f   ",
               disp.redx, disp.redy);
    xf86ErrorF("greenX: %.3f greenY: %.3f\n", disp.greenx, disp.greeny);
    xf86DrvMsg(scrnIndex, X_INFO, "blueX: %.3f blueY: %.3f   ",
               disp.bluex, disp.bluey);
    xf86ErrorF("whiteX: %.3f whiteY: %.3f\n", disp.whitex, disp.whitey);
}

private void print_display(int scrnIndex, disp_features* disp, edid_version* v)
{
    print_input_features(scrnIndex, disp, v);
    if (disp.hsize && disp.vsize) {
        xf86DrvMsg(scrnIndex, X_INFO, "Max Image Size [cm]: ");
        xf86ErrorF("horiz.: %i  ", disp.hsize);
        xf86ErrorF("vert.: %i\n", disp.vsize);
    }
    else if (v.revision >= 4 && (disp.hsize || disp.vsize)) {
        if (disp.hsize)
            xf86DrvMsg(scrnIndex, X_INFO, "Aspect ratio: %.2f (landscape)\n",
                       (disp.hsize + 99) / 100.0);
        if (disp.vsize)
            xf86DrvMsg(scrnIndex, X_INFO, "Aspect ratio: %.2f (portrait)\n",
                       100.0 / cast(float) (disp.vsize + 99));

    }
    else {
        xf86DrvMsg(scrnIndex, X_INFO, "Indeterminate output size\n");
    }

    if (!disp.gamma && v.revision >= 1.4)
        xf86DrvMsg(scrnIndex, X_INFO, "Gamma defined in extension block\n");
    else
        xf86DrvMsg(scrnIndex, X_INFO, "Gamma: %.2f\n", disp.gamma);

    print_dpms_features(scrnIndex, disp, v);
    print_whitepoint(scrnIndex, disp);
}

private void print_established_timings(int scrnIndex, established_timings* t)
{
    ubyte c = void;

    if (t.t1 || t.t2 || t.t_manu)
        xf86DrvMsg(scrnIndex, X_INFO, "Supported established timings:\n");
    c = t.t1;
    if (c & 0x80)
        xf86DrvMsg(scrnIndex, X_INFO, "720x400@70Hz\n");
    if (c & 0x40)
        xf86DrvMsg(scrnIndex, X_INFO, "720x400@88Hz\n");
    if (c & 0x20)
        xf86DrvMsg(scrnIndex, X_INFO, "640x480@60Hz\n");
    if (c & 0x10)
        xf86DrvMsg(scrnIndex, X_INFO, "640x480@67Hz\n");
    if (c & 0x08)
        xf86DrvMsg(scrnIndex, X_INFO, "640x480@72Hz\n");
    if (c & 0x04)
        xf86DrvMsg(scrnIndex, X_INFO, "640x480@75Hz\n");
    if (c & 0x02)
        xf86DrvMsg(scrnIndex, X_INFO, "800x600@56Hz\n");
    if (c & 0x01)
        xf86DrvMsg(scrnIndex, X_INFO, "800x600@60Hz\n");
    c = t.t2;
    if (c & 0x80)
        xf86DrvMsg(scrnIndex, X_INFO, "800x600@72Hz\n");
    if (c & 0x40)
        xf86DrvMsg(scrnIndex, X_INFO, "800x600@75Hz\n");
    if (c & 0x20)
        xf86DrvMsg(scrnIndex, X_INFO, "832x624@75Hz\n");
    if (c & 0x10)
        xf86DrvMsg(scrnIndex, X_INFO, "1024x768@87Hz (interlaced)\n");
    if (c & 0x08)
        xf86DrvMsg(scrnIndex, X_INFO, "1024x768@60Hz\n");
    if (c & 0x04)
        xf86DrvMsg(scrnIndex, X_INFO, "1024x768@70Hz\n");
    if (c & 0x02)
        xf86DrvMsg(scrnIndex, X_INFO, "1024x768@75Hz\n");
    if (c & 0x01)
        xf86DrvMsg(scrnIndex, X_INFO, "1280x1024@75Hz\n");
    c = t.t_manu;
    if (c & 0x80)
        xf86DrvMsg(scrnIndex, X_INFO, "1152x864@75Hz\n");
    xf86DrvMsg(scrnIndex, X_INFO, "Manufacturer's mask: %X\n", c & 0x7F);
}

private void print_std_timings(int scrnIndex, std_timings* t)
{
    int i = void;
    char done = 0;

    for (i = 0; i < STD_TIMINGS; i++) {
        if (t[i].hsize > 256) { /* sanity check */
            if (!done) {
                xf86DrvMsg(scrnIndex, X_INFO, "Supported standard timings:\n");
                done = 1;
            }
            xf86DrvMsg(scrnIndex, X_INFO,
                       "#%i: hsize: %i  vsize %i  refresh: %i  vid: %i\n",
                       i, t[i].hsize, t[i].vsize, t[i].refresh, t[i].id);
        }
    }
}

private void print_cvt_timings(int si, cvt_timings* t)
{
    int i = void;

    for (i = 0; i < 4; i++) {
        if (t[i].height) {
            xf86DrvMsg(si, X_INFO, "%dx%d @ %s%s%s%s%s Hz\n",
                       t[i].width, t[i].height,
                       t[i].rates & 0x10 ? "50,".ptr : "".ptr,
                       t[i].rates & 0x08 ? "60,".ptr : "".ptr,
                       t[i].rates & 0x04 ? "75,".ptr : "".ptr,
                       t[i].rates & 0x02 ? "85,".ptr : "".ptr,
                       t[i].rates & 0x01 ? "60RB".ptr : "".ptr);
        }
        else
            break;
    }
}

private void print_detailed_timings(int scrnIndex, detailed_timings* t)
{

    if (t.clock > 15000000) {  /* sanity check */
        xf86DrvMsg(scrnIndex, X_INFO, "Supported detailed timing:\n");
        xf86DrvMsg(scrnIndex, X_INFO, "clock: %.1f MHz   ",
                   t.clock / 1000000.0);
        xf86ErrorF("Image Size:  %i x %i mm\n", t.h_size, t.v_size);
        xf86DrvMsg(scrnIndex, X_INFO,
                   "h_active: %i  h_sync: %i  h_sync_end %i h_blank_end %i ",
                   t.h_active, t.h_sync_off + t.h_active,
                   t.h_sync_off + t.h_sync_width + t.h_active,
                   t.h_active + t.h_blanking);
        xf86ErrorF("h_border: %i\n", t.h_border);
        xf86DrvMsg(scrnIndex, X_INFO,
                   "v_active: %i  v_sync: %i  v_sync_end %i v_blanking: %i ",
                   t.v_active, t.v_sync_off + t.v_active,
                   t.v_sync_off + t.v_sync_width + t.v_active,
                   t.v_active + t.v_blanking);
        xf86ErrorF("v_border: %i\n", t.v_border);
        if (t.stereo) {
            xf86DrvMsg(scrnIndex, X_INFO, "Stereo: ");
            if (mixin(IS_RIGHT_STEREO!(`t.stereo`))) {
                if (!t.stereo_1)
                    xf86ErrorF("right channel on sync\n");
                else
                    xf86ErrorF("left channel on sync\n");
            }
            else if (mixin(IS_LEFT_STEREO!(`t.stereo`))) {
                if (!t.stereo_1)
                    xf86ErrorF("right channel on even line\n");
                else
                    xf86ErrorF("left channel on evel line\n");
            }
            if (mixin(IS_4WAY_STEREO!(`t.stereo`))) {
                if (!t.stereo_1)
                    xf86ErrorF("4-way interleaved\n");
                else
                    xf86ErrorF("side-by-side interleaved");
            }
        }
    }
}

/* This function handles all detailed patches,
 * including EDID and EDID-extension
 */
struct det_print_parameter {
    xf86MonPtr m;
    int index;
    ddc_quirk_t quirks;
}

private void handle_detailed_print(detailed_monitor_section* det_mon, void* data)
{
    int j = void, scrnIndex = void;
    det_print_parameter* p = void;

    p = cast(det_print_parameter*) data;
    scrnIndex = p.m.scrnIndex;
    xf86DetTimingApplyQuirks(det_mon, p.quirks,
                             p.m.features.hsize, p.m.features.vsize);

    switch (det_mon.type) {
    case DT:
        print_detailed_timings(scrnIndex, &det_mon.section.d_timings);
        break;
    case DS_SERIAL:
        xf86DrvMsg(scrnIndex, X_INFO, "Serial No: %s\n",
                   det_mon.section.serial.ptr);
        break;
    case DS_ASCII_STR:
        xf86DrvMsg(scrnIndex, X_INFO, " %s\n", det_mon.section.ascii_data.ptr);
        break;
    case DS_NAME:
        xf86DrvMsg(scrnIndex, X_INFO, "Monitor name: %s\n",
                   det_mon.section.name.ptr);
        break;
    case DS_RANGES:
    {
        monitor_ranges* r = &det_mon.section.ranges;

        xf86DrvMsg(scrnIndex, X_INFO,
                   "Ranges: V min: %i V max: %i Hz, H min: %i H max: %i kHz,",
                   r.min_v, r.max_v, r.min_h, r.max_h);
        if (r.max_clock_khz != 0) {
            xf86ErrorF(" PixClock max %i kHz\n", r.max_clock_khz);
            if (r.maxwidth)
                xf86DrvMsg(scrnIndex, X_INFO, "Maximum pixel width: %d\n",
                           r.maxwidth);
            xf86DrvMsg(scrnIndex, X_INFO, "Supported aspect ratios:");
            if (r.supported_aspect & SUPPORTED_ASPECT_4_3)
                xf86ErrorF(" 4:3%s",
                           r.preferred_aspect ==
                           PREFERRED_ASPECT_4_3 ? "*".ptr : "".ptr);
            if (r.supported_aspect & SUPPORTED_ASPECT_16_9)
                xf86ErrorF(" 16:9%s",
                           r.preferred_aspect ==
                           PREFERRED_ASPECT_16_9 ? "*".ptr : "".ptr);
            if (r.supported_aspect & SUPPORTED_ASPECT_16_10)
                xf86ErrorF(" 16:10%s",
                           r.preferred_aspect ==
                           PREFERRED_ASPECT_16_10 ? "*".ptr : "".ptr);
            if (r.supported_aspect & SUPPORTED_ASPECT_5_4)
                xf86ErrorF(" 5:4%s",
                           r.preferred_aspect ==
                           PREFERRED_ASPECT_5_4 ? "*".ptr : "".ptr);
            if (r.supported_aspect & SUPPORTED_ASPECT_15_9)
                xf86ErrorF(" 15:9%s",
                           r.preferred_aspect ==
                           PREFERRED_ASPECT_15_9 ? "*".ptr : "".ptr);
            xf86ErrorF("\n");
            xf86DrvMsg(scrnIndex, X_INFO, "Supported blankings:");
            if (r.supported_blanking & CVT_STANDARD)
                xf86ErrorF(" standard");
            if (r.supported_blanking & CVT_REDUCED)
                xf86ErrorF(" reduced");
            xf86ErrorF("\n");
            xf86DrvMsg(scrnIndex, X_INFO, "Supported scalings:");
            if (r.supported_scaling & SCALING_HSHRINK)
                xf86ErrorF(" hshrink");
            if (r.supported_scaling & SCALING_HSTRETCH)
                xf86ErrorF(" hstretch");
            if (r.supported_scaling & SCALING_VSHRINK)
                xf86ErrorF(" vshrink");
            if (r.supported_scaling & SCALING_VSTRETCH)
                xf86ErrorF(" vstretch");
            xf86ErrorF("\n");
            if (r.preferred_refresh)
                xf86DrvMsg(scrnIndex, X_INFO, "Preferred refresh rate: %d\n",
                           r.preferred_refresh);
            else
                xf86DrvMsg(scrnIndex, X_INFO, "Buggy monitor, no preferred "
                           ~ "refresh rate given\n");
        }
        else if (r.max_clock != 0) {
            xf86ErrorF(" PixClock max %i MHz\n", r.max_clock);
        }
        else {
            xf86ErrorF("\n");
        }
        if (r.gtf_2nd_f > 0)
            xf86DrvMsg(scrnIndex, X_INFO, " 2nd GTF parameters: f: %i kHz "
                       ~ "c: %i m: %i k %i j %i\n", r.gtf_2nd_f,
                       r.gtf_2nd_c, r.gtf_2nd_m, r.gtf_2nd_k, r.gtf_2nd_j);
        break;
    }
    case DS_STD_TIMINGS:
        for (j = 0; j < 5; j++)
            xf86DrvMsg(scrnIndex, X_INFO,
                       "#%i: hsize: %i  vsize %i  refresh: %i  "
                       ~ "vid: %i\n", p.index, det_mon.section.std_t[j].hsize,
                       det_mon.section.std_t[j].vsize,
                       det_mon.section.std_t[j].refresh,
                       det_mon.section.std_t[j].id);
        break;
    case DS_WHITE_P:
        for (j = 0; j < 2; j++)
            if (det_mon.section.wp[j].index != 0)
                xf86DrvMsg(scrnIndex, X_INFO,
                           "White point %i: whiteX: %f, whiteY: %f; gamma: %f\n",
                           det_mon.section.wp[j].index,
                           det_mon.section.wp[j].white_x,
                           det_mon.section.wp[j].white_y,
                           det_mon.section.wp[j].white_gamma);
        break;
    case DS_CMD:
        xf86DrvMsg(scrnIndex, X_INFO, "Color management data: (not decoded)\n");
        break;
    case DS_CVT:
        xf86DrvMsg(scrnIndex, X_INFO, "CVT 3-byte-code modes:\n");
        print_cvt_timings(scrnIndex, det_mon.section.cvt.ptr);
        break;
    case DS_EST_III:
        xf86DrvMsg(scrnIndex, X_INFO,
                   "Established timings III: (not decoded)\n");
        break;
    case DS_DUMMY:
    default:
        break;
    }
    if (det_mon.type >= DS_VENDOR && det_mon.type <= DS_VENDOR_MAX) {
        xf86DrvMsg(scrnIndex, X_INFO,
                   "Unknown vendor-specific block %x\n",
                   det_mon.type - DS_VENDOR);
    }

    p.index = p.index + 1;
}

private void print_number_sections(int scrnIndex, int num)
{
    if (num)
        xf86DrvMsg(scrnIndex, X_INFO, "Number of EDID sections to follow: %i\n",
                   num);
}

xf86MonPtr xf86PrintEDID(xf86MonPtr m)
{
    CARD16 i = void, j = void, n = void;
    char[EDID_WIDTH * 2 + 1] buf = void;
    det_print_parameter p = void;

    if (!m)
        return null;

    print_vendor(m.scrnIndex, &m.vendor_);
    print_version(m.scrnIndex, &m.ver);
    print_display(m.scrnIndex, &m.features, &m.ver);
    print_established_timings(m.scrnIndex, &m.timings1);
    print_std_timings(m.scrnIndex, m.timings2.ptr);
    p.m = m;
    p.index = 0;
    p.quirks = xf86DDCDetectQuirks(m.scrnIndex, m, FALSE);
    xf86ForEachDetailedBlock(m, &handle_detailed_print, &p);
    print_number_sections(m.scrnIndex, m.no_sections);

    /* extension block section stuff */

    xf86DrvMsg(m.scrnIndex, X_INFO, "EDID (in hex):\n");

    n = 128;
    if (m.flags & EDID_COMPLETE_RAWDATA)
        n += m.no_sections * 128;

    for (i = 0; i < n; i += j) {
        for (j = 0; j < EDID_WIDTH; ++j) {
            sprintf(&buf[j * 2], "%02x", m.rawData[i + j]);
        }
        xf86DrvMsg(m.scrnIndex, X_INFO, "\t%s\n", buf.ptr);
    }

    return m;
}
