module edid_priv;
@nogc nothrow:
extern(C): __gshared:
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

 
import hw.xfree86.common.edid;

/* read complete EDID record */
enum EDID1_LEN = 128;

/* header: 0x00 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0x00  */
enum HEADER_SECTION = 0;
enum HEADER_LENGTH = 8;

/* vendor section */
enum VENDOR_SECTION = (HEADER_SECTION + HEADER_LENGTH);
enum V_MANUFACTURER = 0;
enum V_PROD_ID = (V_MANUFACTURER + 2);
enum V_SERIAL = (V_PROD_ID + 2);
enum V_WEEK = (V_SERIAL + 4);
enum V_YEAR = (V_WEEK + 1);
enum VENDOR_LENGTH = (V_YEAR + 1);

/* EDID version */
enum VERSION_SECTION = (VENDOR_SECTION + VENDOR_LENGTH);
enum V_VERSION = 0;
enum V_REVISION = (V_VERSION + 1);
enum VERSION_LENGTH = (V_REVISION + 1);

/* display information */
enum DISPLAY_SECTION = (VERSION_SECTION + VERSION_LENGTH);
enum D_INPUT = 0;
enum D_HSIZE = (D_INPUT + 1);
enum D_VSIZE = (D_HSIZE + 1);
enum D_GAMMA = (D_VSIZE + 1);
enum FEAT_S = (D_GAMMA + 1);
enum D_RG_LOW = (FEAT_S + 1);
enum D_BW_LOW = (D_RG_LOW + 1);
enum D_REDX = (D_BW_LOW + 1);
enum D_REDY = (D_REDX + 1);
enum D_GREENX = (D_REDY + 1);
enum D_GREENY = (D_GREENX + 1);
enum D_BLUEX = (D_GREENY + 1);
enum D_BLUEY = (D_BLUEX + 1);
enum D_WHITEX = (D_BLUEY + 1);
enum D_WHITEY = (D_WHITEX + 1);
enum DISPLAY_LENGTH = (D_WHITEY + 1);

/* supported VESA and other standard timings */
enum ESTABLISHED_TIMING_SECTION = (DISPLAY_SECTION + DISPLAY_LENGTH);
enum E_T1 = 0;
enum E_T2 = (E_T1 + 1);
enum E_TMANU = (E_T2 + 1);
enum E_TIMING_LENGTH = (E_TMANU + 1);

/* non predefined standard timings supported by display */
enum STD_TIMING_SECTION = (ESTABLISHED_TIMING_SECTION + E_TIMING_LENGTH);
enum STD_TIMING_INFO_LEN = 2;
enum STD_TIMING_INFO_NUM = STD_TIMINGS;
enum STD_TIMING_LENGTH = (STD_TIMING_INFO_LEN * STD_TIMING_INFO_NUM);

/* detailed timing info of non standard timings */
enum DET_TIMING_SECTION = (STD_TIMING_SECTION + STD_TIMING_LENGTH);
enum DET_TIMING_INFO_LEN = 18;
enum MONITOR_DESC_LEN = DET_TIMING_INFO_LEN;
enum DET_TIMING_INFO_NUM = DET_TIMINGS;
enum DET_TIMING_LENGTH = (DET_TIMING_INFO_LEN * DET_TIMING_INFO_NUM);

/* number of EDID sections to follow */
enum NO_EDID = (DET_TIMING_SECTION + DET_TIMING_LENGTH);
/* one byte checksum */
enum CHECKSUM = (NO_EDID + 1);

static if ((CHECKSUM != (EDID1_LEN - 1))) {
static assert(0, "EDID1 length != 128!");
}

enum string SECTION(string x,string y) = `cast(ubyte*)(` ~ x ~ ` + ` ~ y ~ `)`;
enum string GET_ARRAY(string y) = `(cast(ubyte*)(c + ` ~ y ~ `))`;
enum string GET(string y) = `*cast(ubyte*)(c + ` ~ y ~ `)`;

/* extract information from vendor section */
enum string _PROD_ID(string x) = `` ~ x ~ `[0] + (` ~ x ~ `[1] << 8)`;
enum string _SERIAL_NO(string x) = `` ~ x ~ `[0] + (` ~ x ~ `[1] << 8) + (` ~ x ~ `[2] << 16) + (` ~ x ~ `[3] << 24)`;
enum string _YEAR(string x) = `(` ~ x ~ ` & 0xFF) + 1990`;
enum string _L1(string x) = `((` ~ x ~ `[0] & 0x7C) >> 2) + cast(char)'@'`;
enum string _L2(string x) = `((` ~ x ~ `[0] & 0x03) << 3) + ((` ~ x ~ `[1] & 0xE0) >> 5) + cast(char)'@'`;
enum string _L3(string x) = `(` ~ x ~ `[1] & 0x1F) + cast(char)'@'`;

/* extract information from display section */
enum string _INPUT_TYPE(string x) = `((` ~ x ~ ` & 0x80) >> 7)`;
enum string _INPUT_VOLTAGE(string x) = `((` ~ x ~ ` & 0x60) >> 5)`;
enum string _SETUP(string x) = `((` ~ x ~ ` & 0x10) >> 4)`;
enum string _SYNC(string x) = `(` ~ x ~ `  & 0x0F)`;
enum string _DFP(string x) = `(` ~ x ~ ` & 0x01)`;
enum string _BPC(string x) = `((` ~ x ~ ` & 0x70) >> 4)`;
enum string _DIGITAL_INTERFACE(string x) = `(` ~ x ~ ` & 0x0F)`;
enum string _GAMMA(string x) = `(` ~ x ~ ` == 0xff ? 0.0 : ((` ~ x ~ ` + 100.0)/100.0))`;
enum string _DPMS(string x) = `((` ~ x ~ ` & 0xE0) >> 5)`;
enum string _DISPLAY_TYPE(string x) = `((` ~ x ~ ` & 0x18) >> 3)`;
enum string _MSC(string x) = `(` ~ x ~ ` & 0x7)`;

/* color characteristics */
enum string CC_L(string x,string y) = `((` ~ x ~ ` & (0x03 << ` ~ y ~ `)) >> ` ~ y ~ `)`;
enum string CC_H(string x) = `(` ~ x ~ ` << 2)`;
enum string I_CC(string x,string y,string z) = `` ~ CC_H!(y) ~ ` | ` ~ CC_L!(x,z) ~ ``;
enum string F_CC(string x) = `((` ~ x ~ `)/1024.0)`;

/* extract information from established timing section */
enum string _VALID_TIMING(string x) = `!(((` ~ x ~ `[0] == 0x01) && (` ~ x ~ `[1] == 0x01)) 
                        || ((` ~ x ~ `[0] == 0x00) && (` ~ x ~ `[1] == 0x00)) 
                        || ((` ~ x ~ `[0] == 0x20) && (` ~ x ~ `[1] == 0x20)) )`;
enum string _HSIZE1(string x) = `((` ~ x ~ `[0] + 31) * 8)`;
enum string RATIO(string x) = `((` ~ x ~ `[1] & 0xC0) >> 6)`;
enum RATIO1_1 = 0;
/* EDID Ver. 1.3 redefined this */
enum RATIO16_10 = RATIO1_1;
enum RATIO4_3 = 1;
enum RATIO5_4 = 2;
enum RATIO16_9 = 3;
enum string _VSIZE1(string x,string y,string r) = `switch(` ~ RATIO!(x) ~ `){ 
  case RATIO1_1: ` ~ y ~ ` =  ((v.version_ > 1 || v.revision > 2) 
		       ? (` ~ _HSIZE1!(x) ~ ` * 10) / 16 : ` ~ _HSIZE1!(x) ~ `); break; 
  case RATIO4_3: ` ~ y ~ ` = ` ~ _HSIZE1!(x) ~ ` * 3 / 4; break; 
  case RATIO5_4: ` ~ y ~ ` = ` ~ _HSIZE1!(x) ~ ` * 4 / 5; break; 
  case RATIO16_9: ` ~ y ~ ` = ` ~ _HSIZE1!(x) ~ ` * 9 / 16; break; 
  default: break;}`;
enum string _REFRESH_R(string x) = `(` ~ x ~ `[1] & 0x3F) + 60`;
enum _ID_LOW(string x) =  `(`~x ~ `[0])`;
enum ID_LOW = _ID_LOW!"c";
enum string _ID_HIGH(string x) = `(` ~ x ~ `[1] << 8)`;
enum ID_HIGH = _ID_HIGH!("c");
enum STD_TIMING_ID =`
   (`~ID_LOW~` | `~ID_HIGH~`)`;
enum string _NEXT_STD_TIMING(string x) = `(` ~ x ~ ` = (` ~ x ~ ` + STD_TIMING_INFO_LEN));`;

/* EDID Ver. >= 1.2 */
/**
 * Returns true if the pointer is the start of a monitor descriptor block
 * instead of a detailed timing descriptor.
 *
 * Checking the reserved pad fields for zeroes fails on some monitors with
 * broken empty ASCII strings.  Only the first two bytes are reliable.
 */
enum string _IS_MONITOR_DESC(string x) = `(` ~ x ~ `[0] == 0 && ` ~ x ~ `[1] == 0)`;
enum string _PIXEL_CLOCK(string x) = `(` ~ x ~ `[0] + (` ~ x ~ `[1] << 8)) * 10000`;
enum PIXEL_CLOCK = _PIXEL_CLOCK!("c");
enum string _H_ACTIVE(string x) = `(` ~ x ~ `[2] + ((` ~ x ~ `[4] & 0xF0) << 4))`;
enum H_ACTIVE = _H_ACTIVE!("c");
enum string _H_BLANK(string x) = `(` ~ x ~ `[3] + ((` ~ x ~ `[4] & 0x0F) << 8))`;
enum H_BLANK = _H_BLANK!("c");
enum string _V_ACTIVE(string x) = `(` ~ x ~ `[5] + ((` ~ x ~ `[7] & 0xF0) << 4))`;
enum V_ACTIVE = _V_ACTIVE!("c");
enum string _V_BLANK(string x) = `(` ~ x ~ `[6] + ((` ~ x ~ `[7] & 0x0F) << 8))`;
enum V_BLANK = _V_BLANK!("c");
enum string _H_SYNC_OFF(string x) = `(` ~ x ~ `[8] + ((` ~ x ~ `[11] & 0xC0) << 2))`;
enum H_SYNC_OFF = _H_SYNC_OFF!("c");
enum string _H_SYNC_WIDTH(string x) = `(` ~ x ~ `[9] + ((` ~ x ~ `[11] & 0x30) << 4))`;
enum H_SYNC_WIDTH = _H_SYNC_WIDTH!("c");
enum string _V_SYNC_OFF(string x) = `((` ~ x ~ `[10] >> 4) + ((` ~ x ~ `[11] & 0x0C) << 2))`;
enum V_SYNC_OFF = _V_SYNC_OFF!("c");
enum string _V_SYNC_WIDTH(string x) = `((` ~ x ~ `[10] & 0x0F) + ((` ~ x ~ `[11] & 0x03) << 4))`;
enum V_SYNC_WIDTH = _V_SYNC_WIDTH!("c");
enum string _H_SIZE(string x) = `(` ~ x ~ `[12] + ((` ~ x ~ `[14] & 0xF0) << 4))`;
enum H_SIZE = _H_SIZE!("c");
enum string _V_SIZE(string x) = `(` ~ x ~ `[13] + ((` ~ x ~ `[14] & 0x0F) << 8))`;
enum V_SIZE = _V_SIZE!("c");
enum string _H_BORDER(string x) = `(` ~ x ~ `[15])`;
enum H_BORDER = _H_BORDER!("c");
enum string _V_BORDER(string x) = `(` ~ x ~ `[16])`;
enum V_BORDER = _V_BORDER!("c");
enum string _INTERLACED(string x) = `((` ~ x ~ `[17] & 0x80) >> 7)`;
enum INTERLACED = _INTERLACED!("c");
enum string _STEREO(string x) = `((` ~ x ~ `[17] & 0x60) >> 5)`;
enum STEREO = _STEREO!("c");
enum string _STEREO1(string x) = `(` ~ x ~ `[17] & 0x1)`;
enum STEREO1 = _STEREO!("c");
enum string _SYNC_T(string x) = `((` ~ x ~ `[17] & 0x18) >> 3)`;
enum SYNC_T = _SYNC_T!("c");
enum string _MISC(string x) = `((` ~ x ~ `[17] & 0x06) >> 1)`;
enum MISC = _MISC!("c");

enum string _MONITOR_DESC_TYPE(string x) = `` ~ x ~ `[3]`;
enum SERIAL_NUMBER = 0xFF;
enum ASCII_STR = 0xFE;
enum MONITOR_RANGES = 0xFD;
enum string _MIN_V_OFFSET(string x) = `((!!(` ~ x ~ `[4] & 0x01)) * 255)`;
enum string _MAX_V_OFFSET(string x) = `((!!(` ~ x ~ `[4] & 0x02)) * 255)`;
enum string _MIN_H_OFFSET(string x) = `((!!(` ~ x ~ `[4] & 0x04)) * 255)`;
enum string _MAX_H_OFFSET(string x) = `((!!(` ~ x ~ `[4] & 0x08)) * 255)`;
enum string _MIN_V(string x) = `(` ~ x ~ `[5])`;
enum string MIN_V =`(`~_MIN_V!("c")~` + `~_MIN_V_OFFSET!("c")~`)`;
enum string _MAX_V(string x) = `` ~ x ~ `[6]`;
enum string  MAX_V = `(`~_MAX_V!("c")~` + `~_MAX_V_OFFSET!("c")~`)`;
enum string _MIN_H(string x) = `` ~ x ~ `[7]`;
enum string   MIN_H = `(`~_MIN_H!("c")~` + `~_MIN_H_OFFSET!("c")~`)`;
enum string _MAX_H(string x) = `` ~ x ~ `[8]`;
enum string   MAX_H = `(`~_MAX_H!("c")~` + `~_MAX_H_OFFSET!("c")~`)`;
enum string _MAX_CLOCK(string x) = `` ~ x ~ `[9]`;
enum string MAX_CLOCK = _MAX_CLOCK!("c");
enum string _HAVE_2ND_GTF(string x) = `(` ~ x ~ `[10] == 0x02)`;
enum string HAVE_2ND_GTF = _HAVE_2ND_GTF!("c");
enum string _F_2ND_GTF(string x) = `(` ~ x ~ `[12] * 2)`;
enum string F_2ND_GTF = _F_2ND_GTF!("c");
enum string _C_2ND_GTF(string x) = `(` ~ x ~ `[13] / 2)`;
enum string C_2ND_GTF = _C_2ND_GTF!("c");
enum string _M_2ND_GTF(string x) = `(` ~ x ~ `[14] + (` ~ x ~ `[15] << 8))`;
enum string M_2ND_GTF = _M_2ND_GTF!("c");
enum string _K_2ND_GTF(string x) = `(` ~ x ~ `[16])`;
enum K_2ND_GTF = _K_2ND_GTF!("c");
enum string _J_2ND_GTF(string x) = `(` ~ x ~ `[17] / 2)`;
enum J_2ND_GTF = _J_2ND_GTF!("c");
enum string _HAVE_CVT(string x) = `(` ~ x ~ `[10] == 0x04)`;
enum HAVE_CVT = _HAVE_CVT!("c");
enum string _MAX_CLOCK_KHZ(string x) = `(` ~ x ~ `[12] >> 2)`;
enum string MAX_CLOCK_KHZ = `((`~MAX_CLOCK~`) * 10000) - ((`~_MAX_CLOCK_KHZ!("c")~`) * 250)`;
enum string _MAXWIDTH(string x) = `((` ~ x ~ `[13] == 0 ? 0 : ` ~ x ~ `[13] + ((` ~ x ~ `[12] & 0x03) << 8)) * 8)`;
enum MAXWIDTH = _MAXWIDTH!("c");
enum string _SUPPORTED_ASPECT(string x) = `` ~ x ~ `[14]`;
enum SUPPORTED_ASPECT = _SUPPORTED_ASPECT!("c");
enum  SUPPORTED_ASPECT_4_3 =   0x80;
enum  SUPPORTED_ASPECT_16_9 =  0x40;
enum  SUPPORTED_ASPECT_16_10 = 0x20;
enum  SUPPORTED_ASPECT_5_4 =   0x10;
enum  SUPPORTED_ASPECT_15_9 =  0x08;
enum string _PREFERRED_ASPECT(string x) = `((` ~ x ~ `[15] & 0xe0) >> 5)`;
enum string PREFERRED_ASPECT = _PREFERRED_ASPECT!("c");
enum  PREFERRED_ASPECT_4_3 =   0;
enum  PREFERRED_ASPECT_16_9 =  1;
enum  PREFERRED_ASPECT_16_10 = 2;
enum  PREFERRED_ASPECT_5_4 =   3;
enum  PREFERRED_ASPECT_15_9 =  4;
enum string _SUPPORTED_BLANKING(string x) = `((` ~ x ~ `[15] & 0x18) >> 3)`;
enum SUPPORTED_BLANKING = _SUPPORTED_BLANKING!("c");
enum  CVT_STANDARD = 0x01;
enum  CVT_REDUCED =  0x02;
enum string _SUPPORTED_SCALING(string x) = `((` ~ x ~ `[16] & 0xf0) >> 4)`;
enum SUPPORTED_SCALING = _SUPPORTED_SCALING!("c");
enum  SCALING_HSHRINK =  0x08;
enum  SCALING_HSTRETCH = 0x04;
enum  SCALING_VSHRINK =  0x02;
enum  SCALING_VSTRETCH = 0x01;
enum string _PREFERRED_REFRESH(string x) = `` ~ x ~ `[17]`;
enum PREFERRED_REFRESH = _PREFERRED_REFRESH!("c");

enum MONITOR_NAME = 0xFC;
enum ADD_COLOR_POINT = 0xFB;
enum string WHITEX() = F_CC!(I_CC!((GET!(D_BW_LOW)),(GET!(D_WHITEX)),`2`));
enum string WHITEY() = F_CC!(I_CC!((GET!(D_BW_LOW)),(GET!(D_WHITEY)),`0`));
enum string _WHITEX_ADD(string x,string y) = `` ~ F_CC!(I_CC!(`((*(` ~ x ~ ` + ` ~ y ~ `)))`,`(*(` ~ x ~ ` + ` ~ y ~ ` + 1))`,`2`)) ~ ``;
enum string _WHITEY_ADD(string x,string y) = `` ~ F_CC!(I_CC!(`((*(` ~ x ~ ` + ` ~ y ~ `)))`,`(*(` ~ x ~ ` + ` ~ y ~ ` + 2))`,`0`)) ~ ``;
enum string _WHITE_INDEX1(string x) = `` ~ x ~ `[5]`;
enum WHITE_INDEX1 = _WHITE_INDEX1!("c");
enum string _WHITE_INDEX2(string x) = `` ~ x ~ `[10]`;
enum WHITE_INDEX2 = _WHITE_INDEX2!("c");
enum WHITEX1 = _WHITEX_ADD!("c","6");
enum WHITEY1 = _WHITEY_ADD!("c","6");
enum WHITEX2 = _WHITEX_ADD!("c","12");
enum WHITEY2 = _WHITEY_ADD!("c","12");
enum string _WHITE_GAMMA1(string x) = _GAMMA!(x ~ `[9]`);
enum WHITE_GAMMA1 = _WHITE_GAMMA1!("c");
enum string _WHITE_GAMMA2(string x) = _GAMMA!(x ~ `[14]`);
enum WHITE_GAMMA2 = _WHITE_GAMMA2!("c");
enum ADD_STD_TIMINGS = 0xFA;
enum COLOR_MANAGEMENT_DATA = 0xF9;
enum CVT_3BYTE_DATA = 0xF8;
enum ADD_EST_TIMINGS = 0xF7;
enum ADD_DUMMY = 0x10;

enum string _NEXT_DT_MD_SECTION(string x) = `(` ~ x ~ ` = (` ~ x ~ ` + DET_TIMING_INFO_LEN))`;

/* Msc stuff EDID Ver > 1.1 */
enum string CVT_SUPPORTED(string x) = `(` ~ x ~ ` & 0x1)`;

struct cea_speaker_block {
    ubyte FLR;/*:1 !!*/
    ubyte LFE;/*:1 !!*/
    ubyte FC;/*:1 !!*/
    ubyte RLR;/*:1 !!*/
    ubyte RC;/*:1 !!*/
    ubyte FLRC;/*:1 !!*/
    ubyte RLRC;/*:1 !!*/
    ubyte FLRW;/*:1 !!*/
    ubyte FLRH;/*:1 !!*/
    ubyte TC;/*:1 !!*/
    ubyte FCH;/*:1 !!*/
    ubyte Resv;/*:5 !!*/
    ubyte ResvByte;
}

struct cea_vendor_block_hdmi {
    ubyte portB;/*:4 !!*/
    ubyte portA;/*:4 !!*/
    ubyte portD;/*:4 !!*/
    ubyte portC;/*:4 !!*/
    ubyte support_flags;
    ubyte max_tmds_clock;
    ubyte latency_present;
    ubyte video_latency;
    ubyte audio_latency;
    ubyte interlaced_video_latency;
    ubyte interlaced_audio_latency;
}

struct cea_vendor_block {
    ubyte[3] ieee_id;
    union  {
        cea_vendor_block_hdmi hdmi;
        /* any other vendor blocks we know about */
    };
}

struct cea_video_block {
    ubyte video_code;
}

struct cea_audio_block_descriptor {
    ubyte[3] audio_code;
}

struct cea_audio_block {
    cea_audio_block_descriptor[10] descriptor;
}

struct cea_data_block {
    ubyte len;/*:5 !!*/
    ubyte tag;/*:3 !!*/
    union _U {
        cea_video_block video;
        cea_audio_block audio;
        cea_vendor_block vendor;
        cea_speaker_block speaker;
    }_U u;
}

 /* _XFREE86_EDID_PRIV_H_ */
