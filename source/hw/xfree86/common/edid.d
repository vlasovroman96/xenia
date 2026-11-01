module hw.xfree86.common.edid;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * edid.h: defines to parse an EDID block
 *
 * This file contains all information to interpret a standard EDIC block
 * transmitted by a display device via DDC (Display Data Channel). So far
 * there is no information to deal with optional EDID blocks.
 * DDC is a Trademark of VESA (Video Electronics Standard Association).
 *
 * Copyright 1998 by Egbert Eich <Egbert.Eich@Physik.TU-Darmstadt.DE>
 */

 
// public //import stdbool;
public import core.stdc.stdint;
public import x11.Xmd;
public import x11.Xdefs;

enum STD_TIMINGS = 8;
enum DET_TIMINGS = 4;

/* input type */
enum string DIGITAL(string x) = `` ~ x ~ ``;

/* Msc stuff EDID Ver > 1.1 */
enum string PREFERRED_TIMING_MODE(string x) = `(` ~ x ~ ` & 0x2)`;
enum string GTF_SUPPORTED(string x) = `(` ~ x ~ ` & 0x1)`;

struct vendor {
    char[4] name = 0;
    int prod_id;
    uint serial;
    int week;
    int year;
}

struct edid_version {
    int version_;
    int revision;
}

struct disp_features {
    uint input_type : 1;
    uint input_voltage : 2;
    uint input_setup : 1;
    uint input_sync : 5;
    uint input_dfp : 1;
    uint input_bpc : 3;
    uint input_interface : 4;
    /* 15 bit hole */
    int hsize;
    int vsize;
    float gamma = 0;
    uint dpms : 3;
    uint display_type : 2;
    uint msc : 3;
    float redx = 0;
    float redy = 0;
    float greenx = 0;
    float greeny = 0;
    float bluex = 0;
    float bluey = 0;
    float whitex = 0;
    float whitey = 0;
}

struct established_timings {
    ubyte t1;
    ubyte t2;
    ubyte t_manu;
}

struct std_timings {
    int hsize;
    int vsize;
    int refresh;
    CARD16 id;
}

struct detailed_timings {
    int clock;
    int h_active;
    int h_blanking;
    int v_active;
    int v_blanking;
    int h_sync_off;
    int h_sync_width;
    int v_sync_off;
    int v_sync_width;
    int h_size;
    int v_size;
    int h_border;
    int v_border;
    uint interlaced : 1;
    uint stereo : 2;
    uint sync : 2;
    uint misc : 2;
    uint stereo_1 : 1;
}

enum DT = 0;
enum DS_SERIAL = 0xFF;
enum DS_ASCII_STR = 0xFE;
enum DS_NAME = 0xFC;
enum DS_RANGES = 0xFD;
enum DS_WHITE_P = 0xFB;
enum DS_STD_TIMINGS = 0xFA;
enum DS_CMD = 0xF9;
enum DS_CVT = 0xF8;
enum DS_EST_III = 0xF7;
enum DS_DUMMY = 0x10;
enum DS_UNKOWN = 0x100         /* type is an int */;
enum DS_VENDOR = 0x101;
enum DS_VENDOR_MAX = 0X110;

/*
 * Display range limit Descriptor of EDID version1, reversion 4
 */
enum DR_timing_flags {
	DR_DEFAULT_GTF,
	DR_LIMITS_ONLY,
	DR_SECONDARY_GTF,
	DR_CVT_SUPPORTED = 4,
}
alias DR_DEFAULT_GTF = DR_timing_flags.DR_DEFAULT_GTF;
alias DR_LIMITS_ONLY = DR_timing_flags.DR_LIMITS_ONLY;
alias DR_SECONDARY_GTF = DR_timing_flags.DR_SECONDARY_GTF;
alias DR_CVT_SUPPORTED = DR_timing_flags.DR_CVT_SUPPORTED;


struct monitor_ranges {
    int min_v;
    int max_v;
    int min_h;
    int max_h;
    int max_clock;              /* in mhz */
    int gtf_2nd_f;
    int gtf_2nd_c;
    int gtf_2nd_m;
    int gtf_2nd_k;
    int gtf_2nd_j;
    int max_clock_khz;
    int maxwidth;               /* in pixels */
    char supported_aspect = 0;
    char preferred_aspect = 0;
    char supported_blanking = 0;
    char supported_scaling = 0;
    int preferred_refresh;      /* in hz */
    DR_timing_flags display_range_timing_flags;
}

struct whitePoints {
    int index;
    float white_x = 0;
    float white_y = 0;
    float white_gamma = 0;
}

struct cvt_timings {
    int width;
    int height;
    int rate;
    int rates;
}

/*
 * Be careful when adding new sections; this structure can't grow, it's
 * embedded in the middle of xf86Monitor which is ABI.  Sizes below are
 * in bytes, for ILP32 systems.  If all else fails just copy the section
 * literally like serial and friends.
 */
struct detailed_monitor_section {
    int type;
    union _Section {
        detailed_timings d_timings;      /* 56 */
        ubyte[13] serial;
        ubyte[13] ascii_data;
        ubyte[13] name;
        monitor_ranges ranges;   /* 60 */
        std_timings[5] std_t;    /* 80 */
        whitePoints[2] wp;       /* 32 */
        /* color management data */
        cvt_timings[4] cvt;      /* 64 */
        ubyte[6] est_iii;       /* 6 */
    }_Section section;                  /* max: 80 */
}

/* flags */
enum MONITOR_EDID_COMPLETE_RAWDATA =	0x01;
/* old, don't use */
enum EDID_COMPLETE_RAWDATA =		0x01;

/*
 * For DisplayID devices, only the scrnIndex, flags, and rawData fields
 * are meaningful.  For EDID, they all are.
 */
struct _Xf86Monitor {
    int scrnIndex;
    vendor vendor_;
    edid_version ver;
    disp_features features;
    established_timings timings1;
    std_timings[8] timings2;
    detailed_monitor_section[4] det_mon;
    c_ulong flags;
    int no_sections;
    ubyte* rawData;
}alias xf86Monitor = _Xf86Monitor;
alias xf86MonPtr = xf86Monitor*;

// xf86MonPtr ConfiguredMonitor;

/*
 * check whether monitor supports Generalized Timing Formula
 *
 * @param  monitor the monitor information structure to check
 * @return true if GTF is supported by the monitor
 */
bool xf86Monitor_gtf_supported(xf86MonPtr monitor);

                          /* _EDID_H_ */
