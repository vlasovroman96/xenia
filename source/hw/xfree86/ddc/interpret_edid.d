module interpret_edid;
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
 * interpret_edid.c: interpret a primary EDID block
 */
import build.xorg_config;

// //import stdbool;
import core.stdc.stdint;
import core.stdc.string;

import edid_priv;

import common.misc;
import hw.xfree86.os_support.xf86_OSproc;;
import xf86DDC_priv;
import os.log;
import hw.xfree86.common.edid;
import hw.xfree86.common.xf86Helper;


enum EXT_TAG =   0x00;
enum EXT_REV =   0x01;
enum CEA_EXT =   0x02;
enum VTB_EXT =   0x10;
enum DI_EXT =    0x40;
enum LS_EXT =    0x50;
enum MI_EXT =    0x60;

enum CEA_EXT_MIN_DATA_OFFSET = 4;
enum CEA_EXT_MAX_DATA_OFFSET = 127;
enum CEA_EXT_DET_TIMING_NUM = 6;

enum IEEE_ID_HDMI =    0x000C03;
enum CEA_VIDEO_BLK =   2;
enum CEA_VENDOR_BLK =  3;

struct cea_ext_body {
    ubyte tag;
    ubyte rev;
    ubyte dt_offset;
    ubyte flags;
    cea_data_block data_collection;
}















void find_ranges_section(detailed_monitor_section* det, void* ranges)
{
    if (det.type == DS_RANGES && det.section.ranges.max_clock)
        *cast(monitor_ranges**) ranges = &det.section.ranges;
}

void find_max_detailed_clock(detailed_monitor_section* det, void* ret)
{
    if (det.type == DT) {
        *cast(int*) ret = max(*(cast(int*) ret), det.section.d_timings.clock);
    }
}

void handle_edid_quirks(xf86MonPtr m)
{
    monitor_ranges* ranges = null;

    /*
     * max_clock is only encoded in EDID in tens of MHz, so occasionally we
     * find a monitor claiming a max of 160 with a mode requiring 162, or
     * similar.  Strictly we should refuse to round up too far, but let's
     * see how well this works.
     */

    /* Try to find Monitor Range and max clock, then re-set range value */
    xf86ForEachDetailedBlock(m, &find_ranges_section, &ranges);
    if (ranges && ranges.max_clock) {
        int clock = 0;

        xf86ForEachDetailedBlock(m, &find_max_detailed_clock, &clock);
        if (clock && (ranges.max_clock * 1e6 < clock)) {
            LogMessageVerb(X_WARNING, 1, "EDID timing clock %.2f exceeds claimed max "
                           ~ "%dMHz, fixing\n", clock / 1.0e6, ranges.max_clock);
            ranges.max_clock = cast(int)((clock + 999999) / 1e6);
        }
    }
}

struct det_hv_parameter {
    int real_hsize;
    int real_vsize;
    float target_aspect = 0;
}

void handle_detailed_hvsize(detailed_monitor_section* det_mon, void* data)
{
    det_hv_parameter* p = cast(det_hv_parameter*) data;
    float timing_aspect = void;

    if (det_mon.type == DT) {
        detailed_timings* timing = void;

        timing = &det_mon.section.d_timings;

        if (!timing.v_size)
            return;

        timing_aspect = cast(float) timing.h_size / timing.v_size;
        if (fabs(1 - (timing_aspect / p.target_aspect)) < 0.05) {
            p.real_hsize = max(p.real_hsize, timing.h_size);
            p.real_vsize = max(p.real_vsize, timing.v_size);
        }
    }
}

void encode_aspect_ratio(xf86MonPtr m)
{
    /*
     * some monitors encode the aspect ratio instead of the physical size.
     * try to find the largest detailed timing that matches that aspect
     * ratio and use that to fill in the feature section.
     */
    if ((m.features.hsize == 16 && m.features.vsize == 9) ||
        (m.features.hsize == 16 && m.features.vsize == 10) ||
        (m.features.hsize == 4 && m.features.vsize == 3) ||
        (m.features.hsize == 5 && m.features.vsize == 4)) {

        det_hv_parameter p = void;

        p.real_hsize = 0;
        p.real_vsize = 0;
        p.target_aspect = cast(float) m.features.hsize / m.features.vsize;

        xf86ForEachDetailedBlock(m, &handle_detailed_hvsize, &p);

        if (!p.real_hsize || !p.real_vsize) {
            m.features.hsize = m.features.vsize = 0;
        }
        else if ((m.features.hsize * 10 == p.real_hsize) &&
                 (m.features.vsize * 10 == p.real_vsize)) {
            /* exact match is just unlikely, should do a better check though */
            m.features.hsize = m.features.vsize = 0;
        }
        else {
            /* convert mm to cm */
            m.features.hsize = (p.real_hsize + 5) / 10;
            m.features.vsize = (p.real_vsize + 5) / 10;
        }

        LogMessageVerb(X_INFO, 1, "Quirked EDID physical size to %dx%d cm\n",
                       m.features.hsize, m.features.vsize);
    }
}

xf86MonPtr parseEDID(int scrnIndex, ubyte* block, size_t size, bool copy)
{
    xf86MonPtr m = cast(xf86MonPtr) calloc(1, ((xf86Monitor).sizeof + (copy ? size : 0)));
    if (!m)
        return null;

    /* make a copy of the EDID block for later reference */
    if (copy) {
        memcpy(&(m[1]), block, size);
        block = cast(ubyte*)&m[1];
    }

    m.scrnIndex = scrnIndex;
    m.rawData = block;

pragma(msg, SECTION!("VENDOR_SECTION", "block"));
;
    get_vendor_section(mixin(SECTION!("VENDOR_SECTION", "block")), &(m.vendor_));
    pragma(msg, typeof(m));
    pragma(msg, typeof(m.vendor_));
    get_version_section(mixin(SECTION!("VERSION_SECTION", "block")), &((m.ver)));
    if (!validate_version(scrnIndex, &(m.ver)))
        goto error;
    get_display_section(mixin(SECTION!("DISPLAY_SECTION", "block")), &m.features, &m.ver);
    get_established_timing_section(mixin(SECTION!("ESTABLISHED_TIMING_SECTION", "block")),
                                   &m.timings1);
    get_std_timing_section(mixin(SECTION!("STD_TIMING_SECTION", "block")), m.timings2.ptr,
                           &m.ver);
    get_dt_md_section(mixin(SECTION!("DET_TIMING_SECTION", "block")), &m.ver, m.det_mon.ptr);
    m.no_sections = cast(int) *cast(char*) mixin(SECTION!("NO_EDID", "block"));

    handle_edid_quirks(m);
    encode_aspect_ratio(m);

    if (size > 128)
        m.flags |= EDID_COMPLETE_RAWDATA;

    /* possibly add more extended parsing here, eg. HDR information */

    return m;

 error:
    free(m);
    return null;
}

/* new entry point, should be used whenever possible */
xf86MonPtr xf86ParseEDID(ScrnInfoPtr pScrn, ubyte* block, size_t size)
{
    if (!pScrn || !block || !size)
        return null;

    return parseEDID(pScrn.scrnIndex, block, size, true);
}

/* old entry point, deprecated but still needed for backwards compat */
xf86MonPtr xf86InterpretEDID(int scrnIndex, ubyte* block)
{
    if (!block)
        return null;

    return parseEDID(scrnIndex, block, EDID1_LEN, false);
}

int get_cea_detail_timing(ubyte* blk, xf86MonPtr mon, detailed_monitor_section* det_mon)
{
    int dt_num = void;
    int dt_offset = (cast(cea_ext_body*) blk).dt_offset;

    dt_num = 0;

    if (dt_offset < CEA_EXT_MIN_DATA_OFFSET)
        return dt_num;

    for (; dt_offset < (CEA_EXT_MAX_DATA_OFFSET - DET_TIMING_INFO_LEN) &&
         dt_num < CEA_EXT_DET_TIMING_NUM; mixin(_NEXT_DT_MD_SECTION!("dt_offset"))) {

        fetch_detailed_block(blk + dt_offset, &mon.ver, det_mon + dt_num);
        dt_num = dt_num + 1;
    }

    return dt_num;
}

void handle_cea_detail_block(ubyte* ext, xf86MonPtr mon, handle_detailed_fn fn, void* data)
{
    int i = void;
    detailed_monitor_section[CEA_EXT_DET_TIMING_NUM] det_mon = void;
    int det_mon_num = void;

    det_mon_num = get_cea_detail_timing(ext, mon, det_mon.ptr);

    for (i = 0; i < det_mon_num; i++)
        fn(det_mon.ptr + i, data);
}

void xf86ForEachDetailedBlock(xf86MonPtr mon, handle_detailed_fn fn, void* data)
{
    int i = void;
    ubyte* ext = void;

    if (mon is null)
        return;

    for (i = 0; i < DET_TIMINGS; i++)
        fn(mon.det_mon.ptr + i, data);

    for (i = 0; i < mon.no_sections; i++) {
        ext = mon.rawData + EDID1_LEN * (i + 1);
        switch (ext[EXT_TAG]) {
        case CEA_EXT:
            handle_cea_detail_block(ext, mon, fn, data);
            break;
        case VTB_EXT:
        case DI_EXT:
        case LS_EXT:
        case MI_EXT:
            break;
        default: break;}
    }
}

cea_data_block* extract_cea_data_block(ubyte* ext, int data_type)
{
    cea_ext_body* cea = void;
    cea_data_block* data_collection = void;
    cea_data_block* data_end = void;

    cea = cast(cea_ext_body*) ext;

    if (cea.dt_offset <= CEA_EXT_MIN_DATA_OFFSET)
        return null;

    data_collection = &cea.data_collection;
    data_end = cast(cea_data_block*) (cea.dt_offset + ext);

    for (; data_collection < data_end;) {

        if (data_type == data_collection.tag) {
            return data_collection;
        }
        data_collection = cast(cea_data_block*) (cast(void*) (cast(ubyte*) data_collection +
                                    data_collection.len + 1));
    }

    return null;
}

void handle_cea_video_block(ubyte* ext, handle_video_fn fn, void* data)
{
    cea_video_block* video = void;
    cea_video_block* video_end = void;
    cea_data_block* data_collection = void;

    data_collection = extract_cea_data_block(ext, CEA_VIDEO_BLK);
    if (data_collection is null)
        return;

    video = &data_collection.u.video;
    video_end = cast(cea_video_block*)
        (cast(ubyte*) video + data_collection.len);

    for (; video < video_end; video = video + 1) {
        fn(video, data);
    }
}

void xf86ForEachVideoBlock(xf86MonPtr mon, handle_video_fn fn, void* data)
{
    int i = void;
    ubyte* ext = void;

    if (mon is null)
        return;

    for (i = 0; i < mon.no_sections; i++) {
        ext = mon.rawData + EDID1_LEN * (i + 1);
        switch (ext[EXT_TAG]) {
        case CEA_EXT:
            handle_cea_video_block(ext, fn, data);
            break;
        case VTB_EXT:
        case DI_EXT:
        case LS_EXT:
        case MI_EXT:
            break;
        default: break;}
    }
}

Bool cea_db_offsets(ubyte* cea, int* start, int* end)
{
    /* Data block offset in CEA extension block */
    *start = CEA_EXT_MIN_DATA_OFFSET;
    *end = cea[2];
    if (*end == 0)
        *end = CEA_EXT_MAX_DATA_OFFSET;
    if (*end < CEA_EXT_MIN_DATA_OFFSET || *end > CEA_EXT_MAX_DATA_OFFSET)
        return FALSE;
    return TRUE;
}

int cea_db_len(ubyte* db)
{
    return db[0] & 0x1f;
}

int cea_db_tag(ubyte* db)
{
    return db[0] >> 5;
}

alias handle_cea_db_fn = void function(ubyte*, void*);

void cea_for_each_db(xf86MonPtr mon, handle_cea_db_fn fn, void* data)
{
    int i = void;

    if (!mon)
        return;

    if (!(mon.flags & EDID_COMPLETE_RAWDATA))
        return;

    if (!mon.no_sections)
        return;

    if (!mon.rawData)
        return;

    for (i = 0; i < mon.no_sections; i++) {
        int start = void, end = void, offset = void;
        ubyte* ext = void;

        ext = mon.rawData + EDID1_LEN * (i + 1);
        if (ext[EXT_TAG] != CEA_EXT)
            continue;

        if (!cea_db_offsets(ext, &start, &end))
            continue;

        for (offset = start;
             offset < end && offset + cea_db_len(&ext[offset]) < end;
             offset += cea_db_len(&ext[offset]) + 1)
                fn(&ext[offset], data);
    }
}

struct find_hdmi_block_data {
    cea_data_block* hdmi;
}

void find_hdmi_block(ubyte* db, void* data)
{
    find_hdmi_block_data* result = cast(find_hdmi_block_data*)data;
    int oui = void;

    if (cea_db_tag(db) != CEA_VENDOR_BLK)
        return;

    if (cea_db_len(db) < 5)
        return;

    oui = (db[3] << 16) | (db[2] << 8) | db[1];
    if (oui == IEEE_ID_HDMI)
        result.hdmi = cast(cea_data_block*)db;
}

cea_data_block* xf86MonitorFindHDMIBlock(xf86MonPtr mon)
{
    find_hdmi_block_data result = { null };

    cea_for_each_db(mon, &find_hdmi_block, &result);

    return result.hdmi;
}

xf86MonPtr xf86InterpretEEDID(int scrnIndex, ubyte* block)
{
    return xf86InterpretEDID(scrnIndex, block);
}


void get_vendor_section(ubyte* c, vendor* r)
{
    r.name[0] = mixin(_L1!(GET_ARRAY!("V_MANUFACTURER")));
    r.name[1] = mixin(_L2!(GET_ARRAY!("V_MANUFACTURER")));
    r.name[2] = mixin(_L3!(GET_ARRAY!("V_MANUFACTURER")));
    r.name[3] = '\0';

    r.prod_id = mixin(_PROD_ID!(GET_ARRAY!("V_PROD_ID")));
    r.serial = mixin(_SERIAL_NO!(GET_ARRAY!("V_SERIAL")));
    r.week = mixin(_YEAR!(GET!("V_YEAR")));
    r.year = mixin(GET!("V_WEEK")) & 0xFF;
}

void get_version_section(ubyte* c, edid_version* r)
{
    r.version_ = mixin(GET!("V_VERSION"));
    r.revision = mixin(GET!("V_REVISION"));
}

void get_display_section(ubyte* c, disp_features* r, edid_version* v)
{
    r.input_type = mixin(_INPUT_TYPE!(GET!("D_INPUT")));
    if (!mixin(DIGITAL!("r.input_type"))) {
        r.input_voltage = mixin(_INPUT_VOLTAGE!(GET!("D_INPUT")));
        r.input_setup = mixin(_SETUP!(GET!("D_INPUT")));
        r.input_sync = mixin(_SYNC!(GET!("D_INPUT")));
    }
    else if (v.revision == 2 || v.revision == 3) {
        r.input_dfp = mixin(_DFP!(GET!("D_INPUT")));
    }
    else if (v.revision >= 4) {
        r.input_bpc = mixin(_BPC!(GET!("D_INPUT")));
        r.input_interface = mixin(_DIGITAL_INTERFACE!(GET!("D_INPUT")));
    }
    r.hsize = mixin(GET!("D_HSIZE"));
    r.vsize = mixin(GET!("D_VSIZE"));
    r.gamma = mixin(_GAMMA!(GET!("D_GAMMA")));
    r.dpms = mixin(_DPMS!(GET!("FEAT_S")));
    r.display_type = mixin(_DISPLAY_TYPE!(GET!("FEAT_S")));
    r.msc = mixin(_MSC!(GET!("FEAT_S")));
    r.redx = mixin(F_CC!(I_CC!((GET!("D_RG_LOW")),(GET!("D_REDX")),"6")));
    r.redy = mixin(F_CC!(I_CC!((GET!("D_RG_LOW")),(GET!("D_REDY")),"4")));
    r.greenx = mixin(F_CC!(I_CC!((GET!("D_RG_LOW")),(GET!("D_GREENX")),"2")));
    r.greeny = mixin(F_CC!(I_CC!((GET!("D_RG_LOW")),(GET!("D_GREENY")),"0")));
    r.bluex = mixin(F_CC!(I_CC!((GET!("D_BW_LOW")),(GET!("D_BLUEX")),"6")));
    r.bluey = mixin(F_CC!(I_CC!((GET!("D_BW_LOW")),(GET!("D_BLUEY")),"4")));
    r.whitex = mixin(F_CC!(I_CC!((GET!("D_BW_LOW")),(GET!("D_WHITEX")),"2")));
    r.whitey = mixin(F_CC!(I_CC!((GET!("D_BW_LOW")),(GET!("D_WHITEY")),"0")));
}

void get_established_timing_section(ubyte* c, established_timings* r)
{
    r.t1 = mixin(GET!("E_T1"));
    r.t2 = mixin(GET!("E_T2"));
    r.t_manu = mixin(GET!("E_TMANU"));
}

void get_cvt_timing_section(ubyte* c, cvt_timings* r)
{
    int i = void;

    for (i = 0; i < 4; i++) {
        if (c[0] && c[1] && c[2]) {
            r[i].height = (c[0] + ((c[1] & 0xF0) << 8) + 1) * 2;
            switch (c[1] & 0xc0) {
            case 0x00:
                r[i].width = r[i].height * 4 / 3;
                break;
            case 0x40:
                r[i].width = r[i].height * 16 / 9;
                break;
            case 0x80:
                r[i].width = r[i].height * 16 / 10;
                break;
            case 0xc0:
                r[i].width = r[i].height * 15 / 9;
                break;
            default: break;}
            switch (c[2] & 0x60) {
            case 0x00:
                r[i].rate = 50;
                break;
            case 0x20:
                r[i].rate = 60;
                break;
            case 0x40:
                r[i].rate = 75;
                break;
            case 0x60:
                r[i].rate = 85;
                break;
            default: break;}
            r[i].rates = c[2] & 0x1f;
        }
        else {
            return;
        }
        c += 3;
    }
}

void get_std_timing_section(ubyte* c, std_timings* r, edid_version* v)
{
    int i = void;

    for (i = 0; i < STD_TIMINGS; i++) {
        if (mixin(_VALID_TIMING!("c"))) {
            r[i].hsize = mixin(_HSIZE1!("c"));
            mixin(_VSIZE1!("c","r[i].vsize","v"));
            r[i].refresh = mixin(_REFRESH_R!("c"));
            r[i].id = mixin(STD_TIMING_ID);
        }
        else {
            r[i].hsize = r[i].vsize = r[i].refresh = r[i].id = 0;
        }
        mixin(_NEXT_STD_TIMING!("c"));
    }
}

const(ubyte)[18] empty_block;

void fetch_detailed_block(ubyte* c, edid_version* ver, detailed_monitor_section* det_mon)
{
    if (ver.version_ == 1 && ver.revision >= 1 && mixin(_IS_MONITOR_DESC!("c"))) {
        switch (mixin(_MONITOR_DESC_TYPE!("c"))) {
        case SERIAL_NUMBER:
            det_mon.type = DS_SERIAL;
            copy_string(c, det_mon.section.serial.ptr);
            break;
        case ASCII_STR:
            det_mon.type = DS_ASCII_STR;
            copy_string(c, det_mon.section.ascii_data.ptr);
            break;
        case MONITOR_RANGES:
            det_mon.type = DS_RANGES;
            get_monitor_ranges(c, &det_mon.section.ranges);
            break;
        case MONITOR_NAME:
            det_mon.type = DS_NAME;
            copy_string(c, det_mon.section.name.ptr);
            break;
        case ADD_COLOR_POINT:
            det_mon.type = DS_WHITE_P;
            get_whitepoint_section(c, det_mon.section.wp.ptr);
            break;
        case ADD_STD_TIMINGS:
            det_mon.type = DS_STD_TIMINGS;
            get_dst_timing_section(c, det_mon.section.std_t.ptr, ver);
            break;
        case COLOR_MANAGEMENT_DATA:
            det_mon.type = DS_CMD;
            break;
        case CVT_3BYTE_DATA:
            det_mon.type = DS_CVT;
            get_cvt_timing_section(c, det_mon.section.cvt.ptr);
            break;
        case ADD_EST_TIMINGS:
            det_mon.type = DS_EST_III;
            memcpy(det_mon.section.est_iii.ptr, c + 6, 6);
            break;
        case ADD_DUMMY:
            det_mon.type = DS_DUMMY;
            break;
        default:
            det_mon.type = DS_UNKOWN;
            break;
        }
        if (c[3] <= 0x0F && memcmp(c, empty_block.ptr, empty_block.sizeof)) {
            det_mon.type = DS_VENDOR + c[3];
        }
    }
    else {
        det_mon.type = DT;
        get_detailed_timing_section(c, &det_mon.section.d_timings);
    }
}

void get_dt_md_section(ubyte* c, edid_version* ver, detailed_monitor_section* det_mon)
{
    int i = void;

    for (i = 0; i < DET_TIMINGS; i++) {
        fetch_detailed_block(c, ver, det_mon + i);
        mixin(_NEXT_DT_MD_SECTION!("c")~";");
    }
}

void copy_string(ubyte* c, ubyte* s)
{
    int i = void;

    c = c + 5;
    for (i = 0; (i < 13 && *c != 0x0A); i++)
        *(s++) = *(c++);
    *s = 0;
    while (i-- && (*--s == 0x20))
        *s = 0;
}

void get_dst_timing_section(ubyte* c, std_timings* t, edid_version* v)
{
    int j = void;

    c = c + 5;
    for (j = 0; j < 5; j++) {
        t[j].hsize = mixin(_HSIZE1!("c"));
        mixin(_VSIZE1!("c","t[j].vsize","v"));
        t[j].refresh = mixin(_REFRESH_R!("c"));
        t[j].id = mixin(STD_TIMING_ID);
        mixin(_NEXT_STD_TIMING!("c"));
    }
}

void get_monitor_ranges(ubyte* c, monitor_ranges* r)
{
    r.min_v = mixin(MIN_V);
    r.max_v = mixin(MAX_V);
    r.min_h = mixin(MIN_H);
    r.max_h = mixin(MAX_H);
    r.max_clock = 0;
    if (mixin(MAX_CLOCK) != 0xff)      /* is specified? */
        r.max_clock = mixin(MAX_CLOCK) * 10 + 5;

    r.display_range_timing_flags = cast(DR_timing_flags)c[10];

    if (HAVE_2ND_GTF) {
        r.gtf_2nd_f = mixin(F_2ND_GTF);
        r.gtf_2nd_c = mixin(C_2ND_GTF);
        r.gtf_2nd_m = mixin(M_2ND_GTF);
        r.gtf_2nd_k = mixin(K_2ND_GTF);
        r.gtf_2nd_j = mixin(J_2ND_GTF);
    }
    else {
        r.gtf_2nd_f = 0;
    }
    if (HAVE_CVT) {
        r.max_clock_khz = mixin(MAX_CLOCK_KHZ);
        r.max_clock = r.max_clock_khz / 1000;
        r.maxwidth = mixin(MAXWIDTH);
        r.supported_aspect = mixin(SUPPORTED_ASPECT);
        r.preferred_aspect = mixin(PREFERRED_ASPECT);
        r.supported_blanking = mixin(SUPPORTED_BLANKING);
        r.supported_scaling = mixin(SUPPORTED_SCALING);
        r.preferred_refresh = mixin(PREFERRED_REFRESH);
    }
    else {
        r.max_clock_khz = 0;
    }
}

void get_whitepoint_section(ubyte* c, whitePoints* wp)
{
    wp[0].white_x = mixin(WHITEX1);
    wp[0].white_y = mixin(WHITEY1);
    wp[1].white_x = mixin(WHITEX2);
    wp[1].white_y = mixin(WHITEY2);
    wp[0].index = mixin(WHITE_INDEX1);
    wp[1].index = mixin(WHITE_INDEX2);
    wp[0].white_gamma = mixin(WHITE_GAMMA1);
    wp[1].white_gamma = mixin(WHITE_GAMMA2);
}

void get_detailed_timing_section(ubyte* c, detailed_timings* r)
{
    r.clock = mixin(PIXEL_CLOCK);
    r.h_active = mixin(H_ACTIVE);
    r.h_blanking = mixin(H_BLANK);
    r.v_active = mixin(V_ACTIVE);
    r.v_blanking = mixin(V_BLANK);
    r.h_sync_off = mixin(H_SYNC_OFF);
    r.h_sync_width = mixin(H_SYNC_WIDTH);
    r.v_sync_off = mixin(V_SYNC_OFF);
    r.v_sync_width = mixin(V_SYNC_WIDTH);
    r.h_size = mixin(H_SIZE);
    r.v_size = mixin(V_SIZE);
    r.h_border = mixin(H_BORDER);
    r.v_border = mixin(V_BORDER);
    r.interlaced = mixin(INTERLACED);
    r.stereo = mixin(STEREO);
    r.stereo_1 = mixin(STEREO1);
    r.sync = mixin(SYNC_T);
    r.misc = mixin(MISC);
}

enum MAX_EDID_MINOR = 4;

Bool validate_version(int scrnIndex, edid_version* r)
{
    if (r.version_ != 1) {
        xf86DrvMsg(scrnIndex, X_ERROR, "Unknown EDID version %d\n", r.version_);
        return FALSE;
    }

    if (r.revision > MAX_EDID_MINOR)
        xf86DrvMsg(scrnIndex, X_WARNING,
                   "Assuming version 1.%d is compatible with 1.%d\n",
                   r.revision, MAX_EDID_MINOR);

    return TRUE;
}

Bool gtf_supported(xf86MonPtr mon)
{
    int i = void;

    if (!mon)
        return FALSE;

    if ((mon.ver.version_ == 1) && (mon.ver.revision < 4)) {
        if (mon.features.msc & 0x1)
            return TRUE;
    } else {
        for (i = 0; i < DET_TIMINGS; i++) {
            detailed_monitor_section* det_timing_des = &(mon.det_mon[i]);
            if (det_timing_des && (det_timing_des.type == DS_RANGES) && (mon.features.msc & 0x1) &&
                (det_timing_des.section.ranges.display_range_timing_flags == DR_DEFAULT_GTF
                || det_timing_des.section.ranges.display_range_timing_flags == DR_SECONDARY_GTF))
                    return TRUE;
        }
    }

    return FALSE;
}

bool xf86Monitor_gtf_supported(xf86MonPtr monitor)
{
    if (!monitor)
        return false;

    return mixin(GTF_SUPPORTED!("monitor.features.msc"));
}
