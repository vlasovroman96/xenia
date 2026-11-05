module include.xf86Parser;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright (c) 1997  Metro Link Incorporated
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Metro Link shall not be
 * used in advertising or otherwise to promote the sale, use or other dealings
 * in this Software without prior written authorization from Metro Link.
 *
 */
/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

/*
 * This file contains the external interfaces for the XFree86 configuration
 * file parser.
 */
 
public import x11.Xdefs;
public import include.xf86Optrec;
public import common.list;

public import core.sys.posix.sys.types;
public import externs.regex;
import hw.xfree86.parser.Flags;

version = HAVE_PARSER_DECLS;

struct _XF86ConfFilesRec {
    char* file_logfile;
    char* file_modulepath;
    char* file_fontpath;
    char* file_comment;
    char* file_xkbdir;
}alias XF86ConfFilesRec = _XF86ConfFilesRec;
alias XF86ConfFilesPtr = XF86ConfFilesRec*;

/* Values for load_type */
enum XF86_LOAD_MODULE =	0;
enum XF86_LOAD_DRIVER =	1;
enum XF86_DISABLE_MODULE =	2;

struct _XF86LoadRec {
    GenericListRec list;
    int load_type;
    const(char)* load_name;
    XF86OptionPtr load_opt;
    char* load_comment;
    int ignore;
}alias XF86LoadRec = _XF86LoadRec;
alias XF86LoadPtr = XF86LoadRec*;

struct _XF86ConfModuleRec {
    XF86LoadPtr mod_load_lst;
    XF86LoadPtr mod_disable_lst;
    char* mod_comment;
}alias XF86ConfModuleRec = _XF86ConfModuleRec;
alias XF86ConfModulePtr = XF86ConfModuleRec*;

enum CONF_IMPLICIT_KEYBOARD =	"Implicit Core Keyboard";

enum CONF_IMPLICIT_POINTER =	"Implicit Core Pointer";

enum XF86CONF_PHSYNC =    0x0001;
enum XF86CONF_NHSYNC =    0x0002;
enum XF86CONF_PVSYNC =    0x0004;
enum XF86CONF_NVSYNC =    0x0008;
enum XF86CONF_INTERLACE = 0x0010;
enum XF86CONF_DBLSCAN =   0x0020;
enum XF86CONF_CSYNC =     0x0040;
enum XF86CONF_PCSYNC =    0x0080;
enum XF86CONF_NCSYNC =    0x0100;
enum XF86CONF_HSKEW =     0x0200       /* hskew provided */;
enum XF86CONF_BCAST =     0x0400;
enum XF86CONF_VSCAN =     0x1000;

struct _XF86ConfModeLineRec {
    GenericListRec list;
    const(char)* ml_identifier;
    int ml_clock;
    int ml_hdisplay;
    int ml_hsyncstart;
    int ml_hsyncend;
    int ml_htotal;
    int ml_vdisplay;
    int ml_vsyncstart;
    int ml_vsyncend;
    int ml_vtotal;
    int ml_vscan;
    int ml_flags;
    int ml_hskew;
    char* ml_comment;
}alias XF86ConfModeLineRec = _XF86ConfModeLineRec;
alias XF86ConfModeLinePtr = XF86ConfModeLineRec*;

struct _XF86ConfVideoPortRec {
    GenericListRec list;
    const(char)* vp_identifier;
    XF86OptionPtr vp_option_lst;
    char* vp_comment;
}alias XF86ConfVideoPortRec = _XF86ConfVideoPortRec;
alias XF86ConfVideoPortPtr = XF86ConfVideoPortRec*;

struct _XF86ConfVideoAdaptorRec {
    GenericListRec list;
    const(char)* va_identifier;
    const(char)* va_vendor;
    const(char)* va_board;
    const(char)* va_busid;
    const(char)* va_driver;
    XF86OptionPtr va_option_lst;
    XF86ConfVideoPortPtr va_port_lst;
    const(char)* va_fwdref;
    char* va_comment;
}alias XF86ConfVideoAdaptorRec = _XF86ConfVideoAdaptorRec;
alias XF86ConfVideoAdaptorPtr = XF86ConfVideoAdaptorRec*;

enum CONF_MAX_HSYNC = 8;
enum CONF_MAX_VREFRESH = 8;

struct parser_range {
    float hi = 0, lo = 0;
}

struct parser_rgb {
    int red, green, blue;
}

struct _XF86ConfModesRec {
    GenericListRec list;
    const(char)* modes_identifier;
    XF86ConfModeLinePtr mon_modeline_lst;
    char* modes_comment;
}alias XF86ConfModesRec = _XF86ConfModesRec;
alias XF86ConfModesPtr = XF86ConfModesRec*;

struct _XF86ConfModesLinkRec {
    GenericListRec list;
    const(char)* ml_modes_str;
    XF86ConfModesPtr ml_modes;
}alias XF86ConfModesLinkRec = _XF86ConfModesLinkRec;
alias XF86ConfModesLinkPtr = XF86ConfModesLinkRec*;

struct _XF86ConfMonitorRec {
    GenericListRec list;
    const(char)* mon_identifier;
    const(char)* mon_vendor;
    char* mon_modelname;
    int mon_width;              /* in mm */
    int mon_height;             /* in mm */
    XF86ConfModeLinePtr mon_modeline_lst;
    int mon_n_hsync;
    parser_range[CONF_MAX_HSYNC] mon_hsync;
    int mon_n_vrefresh;
    parser_range[CONF_MAX_VREFRESH] mon_vrefresh;
    float mon_gamma_red = 0;
    float mon_gamma_green = 0;
    float mon_gamma_blue = 0;
    XF86OptionPtr mon_option_lst;
    XF86ConfModesLinkPtr mon_modes_sect_lst;
    char* mon_comment;
}alias XF86ConfMonitorRec = _XF86ConfMonitorRec;
alias XF86ConfMonitorPtr = XF86ConfMonitorRec*;

enum CONF_MAXDACSPEEDS = 4;
enum CONF_MAXCLOCKS =    128;

struct _XF86ConfDeviceRec {
    GenericListRec list;
    const(char)* dev_identifier;
    const(char)* dev_vendor;
    const(char)* dev_board;
    const(char)* dev_chipset;
    const(char)* dev_busid;
    const(char)* dev_card;
    const(char)* dev_driver;
    const(char)* dev_ramdac;
    int[CONF_MAXDACSPEEDS] dev_dacSpeeds;
    int dev_videoram;
    c_ulong dev_mem_base;
    c_ulong dev_io_base;
    const(char)* dev_clockchip;
    int dev_clocks;
    int[CONF_MAXCLOCKS] dev_clock;
    int dev_chipid;
    int dev_chiprev;
    int dev_irq;
    int dev_screen;
    XF86OptionPtr dev_option_lst;
    char* dev_comment;
    char* match_seat;
}alias XF86ConfDeviceRec = _XF86ConfDeviceRec;
alias XF86ConfDevicePtr = XF86ConfDeviceRec*;

struct _XF86ModeRec {
    GenericListRec list;
    const(char)* mode_name;
}alias XF86ModeRec = _XF86ModeRec;
alias XF86ModePtr = XF86ModeRec*;

struct _XF86ConfDisplayRec {
    GenericListRec list;
    int disp_frameX0;
    int disp_frameY0;
    int disp_virtualX;
    int disp_virtualY;
    int disp_depth;
    int disp_bpp;
    const(char)* disp_visual;
    parser_rgb disp_weight;
    parser_rgb disp_black;
    parser_rgb disp_white;
    XF86ModePtr disp_mode_lst;
    XF86OptionPtr disp_option_lst;
    char* disp_comment;
}alias XF86ConfDisplayRec = _XF86ConfDisplayRec;
alias XF86ConfDisplayPtr = XF86ConfDisplayRec*;

struct _XF86ConfFlagsRec {
    XF86OptionPtr flg_option_lst;
    char* flg_comment;
}alias XF86ConfFlagsRec = _XF86ConfFlagsRec;
alias XF86ConfFlagsPtr = XF86ConfFlagsRec*;

struct _XF86ConfAdaptorLinkRec {
    GenericListRec list;
    const(char)* al_adaptor_str;
    XF86ConfVideoAdaptorPtr al_adaptor;
}alias XF86ConfAdaptorLinkRec = _XF86ConfAdaptorLinkRec;
alias XF86ConfAdaptorLinkPtr = XF86ConfAdaptorLinkRec*;

enum CONF_MAXGPUDEVICES = 4;
struct _XF86ConfScreenRec {
    GenericListRec list;
    const(char)* scrn_identifier;
    const(char)* scrn_obso_driver;
    int scrn_defaultdepth;
    int scrn_defaultbpp;
    int scrn_defaultfbbpp;
    const(char)* scrn_monitor_str;
    XF86ConfMonitorPtr scrn_monitor;
    const(char)* scrn_device_str;
    XF86ConfDevicePtr scrn_device;
    XF86ConfAdaptorLinkPtr scrn_adaptor_lst;
    XF86ConfDisplayPtr scrn_display_lst;
    XF86OptionPtr scrn_option_lst;
    char* scrn_comment;
    int scrn_virtualX, scrn_virtualY;
    char* match_seat;

    int num_gpu_devices;
    const(char)*[CONF_MAXGPUDEVICES] scrn_gpu_device_str;
    XF86ConfDevicePtr[CONF_MAXGPUDEVICES] scrn_gpu_devices;
}alias XF86ConfScreenRec = _XF86ConfScreenRec;
alias XF86ConfScreenPtr = XF86ConfScreenRec*;

struct _XF86ConfInputRec {
    GenericListRec list;
    char* inp_identifier;
    char* inp_driver;
    XF86OptionPtr inp_option_lst;
    char* inp_comment;
}alias XF86ConfInputRec = _XF86ConfInputRec;
alias XF86ConfInputPtr = XF86ConfInputRec*;

struct _XF86ConfInputrefRec {
    GenericListRec list;
    XF86ConfInputPtr iref_inputdev;
    char* iref_inputdev_str;
    XF86OptionPtr iref_option_lst;
}alias XF86ConfInputrefRec = _XF86ConfInputrefRec;
alias XF86ConfInputrefPtr = XF86ConfInputrefRec*;

struct xf86TriState {
    Bool set;
    Bool val;
}

struct xf86MatchGroup {
    xorg_list entry;
    xorg_list patterns;
    Bool is_negated;
}

enum xf86MatchMode {
    MATCH_IS_INVALID,
    MATCH_EXACT,
    MATCH_EXACT_NOCASE,
    MATCH_AS_SUBSTRING,
    MATCH_AS_SUBSTRING_NOCASE,
    MATCH_AS_FILENAME,
    MATCH_AS_PATHNAME,
    MATCH_SUBSTRINGS_SEQUENCE,
    MATCH_REGEX
}
alias MATCH_IS_INVALID = xf86MatchMode.MATCH_IS_INVALID;
alias MATCH_EXACT = xf86MatchMode.MATCH_EXACT;
alias MATCH_EXACT_NOCASE = xf86MatchMode.MATCH_EXACT_NOCASE;
alias MATCH_AS_SUBSTRING = xf86MatchMode.MATCH_AS_SUBSTRING;
alias MATCH_AS_SUBSTRING_NOCASE = xf86MatchMode.MATCH_AS_SUBSTRING_NOCASE;
alias MATCH_AS_FILENAME = xf86MatchMode.MATCH_AS_FILENAME;
alias MATCH_AS_PATHNAME = xf86MatchMode.MATCH_AS_PATHNAME;
alias MATCH_SUBSTRINGS_SEQUENCE = xf86MatchMode.MATCH_SUBSTRINGS_SEQUENCE;
alias MATCH_REGEX = xf86MatchMode.MATCH_REGEX;


struct xf86MatchPattern {
    xorg_list entry;
    xf86MatchMode mode;
    Bool is_negated;
    char* str;
    regex_t* regex;
}

struct _XF86ConfInputClassRec {
    GenericListRec list;
    char* identifier;
    char* driver;
    xorg_list match_product;
    xorg_list match_vendor;
    xorg_list match_device;
    xorg_list match_os;
    xorg_list match_pnpid;
    xorg_list match_usbid;
    xorg_list match_driver;
    xorg_list match_tag;
    xorg_list match_layout;
    xf86TriState is_keyboard;
    xf86TriState is_pointer;
    xf86TriState is_joystick;
    xf86TriState is_tablet;
    xf86TriState is_tablet_pad;
    xf86TriState is_touchpad;
    xf86TriState is_touchscreen;
    XF86OptionPtr option_lst;
    char* comment;
}alias XF86ConfInputClassRec = _XF86ConfInputClassRec;
alias XF86ConfInputClassPtr = XF86ConfInputClassRec*;

struct _XF86ConfOutputClassRec {
    GenericListRec list;
    char* identifier;
    char* driver;
    char* modules;
    char* modulepath;
    xorg_list match_driver;
    xorg_list match_layout;
    XF86OptionPtr option_lst;
    char* comment;
}alias XF86ConfOutputClassRec = _XF86ConfOutputClassRec;
alias XF86ConfOutputClassPtr = XF86ConfOutputClassRec*;

/* Values for adj_where */
enum CONF_ADJ_OBSOLETE =	-1;
enum CONF_ADJ_ABSOLUTE =	0;
enum CONF_ADJ_RIGHTOF =	1;
enum CONF_ADJ_LEFTOF =		2;
enum CONF_ADJ_ABOVE =		3;
enum CONF_ADJ_BELOW =		4;
enum CONF_ADJ_RELATIVE =	5;

struct _XF86ConfAdjacencyRec {
    GenericListRec list;
    int adj_scrnum;
    XF86ConfScreenPtr adj_screen;
    const(char)* adj_screen_str;
    XF86ConfScreenPtr adj_top;
    const(char)* adj_top_str;
    XF86ConfScreenPtr adj_bottom;
    const(char)* adj_bottom_str;
    XF86ConfScreenPtr adj_left;
    const(char)* adj_left_str;
    XF86ConfScreenPtr adj_right;
    const(char)* adj_right_str;
    int adj_where;
    int adj_x;
    int adj_y;
    const(char)* adj_refscreen;
}alias XF86ConfAdjacencyRec = _XF86ConfAdjacencyRec;
alias XF86ConfAdjacencyPtr = XF86ConfAdjacencyRec*;

struct _XF86ConfInactiveRec {
    GenericListRec list;
    const(char)* inactive_device_str;
    XF86ConfDevicePtr inactive_device;
}alias XF86ConfInactiveRec = _XF86ConfInactiveRec;
alias XF86ConfInactivePtr = XF86ConfInactiveRec*;

struct _XF86ConfLayoutRec {
    GenericListRec list;
    const(char)* lay_identifier;
    XF86ConfAdjacencyPtr lay_adjacency_lst;
    XF86ConfInactivePtr lay_inactive_lst;
    XF86ConfInputrefPtr lay_input_lst;
    XF86OptionPtr lay_option_lst;
    char* match_seat;
    char* lay_comment;
}alias XF86ConfLayoutRec = _XF86ConfLayoutRec;
alias XF86ConfLayoutPtr = XF86ConfLayoutRec*;

struct _XF86ConfVendSubRec {
    GenericListRec list;
    const(char)* vs_name;
    const(char)* vs_identifier;
    XF86OptionPtr vs_option_lst;
    char* vs_comment;
}alias XF86ConfVendSubRec = _XF86ConfVendSubRec;
alias XF86ConfVendSubPtr = XF86ConfVendSubRec*;

struct _XF86ConfVendorRec {
    GenericListRec list;
    const(char)* vnd_identifier;
    XF86OptionPtr vnd_option_lst;
    XF86ConfVendSubPtr vnd_sub_lst;
    char* vnd_comment;
}alias XF86ConfVendorRec = _XF86ConfVendorRec;
alias XF86ConfVendorPtr = XF86ConfVendorRec*;

struct _XF86ConfDRIRec {
    const(char)* dri_group_name;
    int dri_group;
    int dri_mode;
    char* dri_comment;
}alias XF86ConfDRIRec = _XF86ConfDRIRec;
alias XF86ConfDRIPtr = XF86ConfDRIRec*;

struct _XF86ConfExtensionsRec {
    XF86OptionPtr ext_option_lst;
    char* extensions_comment;
}alias XF86ConfExtensionsRec = _XF86ConfExtensionsRec;
alias XF86ConfExtensionsPtr = XF86ConfExtensionsRec*;

struct _XF86ConfigRec {
    XF86ConfFilesPtr conf_files;
    XF86ConfModulePtr conf_modules;
    XF86ConfFlagsPtr conf_flags;
    XF86ConfVideoAdaptorPtr conf_videoadaptor_lst;
    XF86ConfModesPtr conf_modes_lst;
    XF86ConfMonitorPtr conf_monitor_lst;
    XF86ConfDevicePtr conf_device_lst;
    XF86ConfScreenPtr conf_screen_lst;
    XF86ConfInputPtr conf_input_lst;
    XF86ConfInputClassPtr conf_inputclass_lst;
    XF86ConfOutputClassPtr conf_outputclass_lst;
    XF86ConfLayoutPtr conf_layout_lst;
    XF86ConfVendorPtr conf_vendor_lst;
    XF86ConfDRIPtr conf_dri;
    XF86ConfExtensionsPtr conf_extensions;
    char* conf_comment;
}alias XF86ConfigRec = _XF86ConfigRec;
alias XF86ConfigPtr = XF86ConfigRec*;

struct _Xf86ConfigSymTabRec {
    int token;                  /* id of the token */
    const(char)* name;           /* pointer to the LOWERCASED name */
}alias xf86ConfigSymTabRec = _Xf86ConfigSymTabRec;
alias xf86ConfigSymTabPtr = xf86ConfigSymTabRec*;

/*
 * prototypes for public functions
 */
// void  xf86findDevice(const(char)* ident, XF86ConfDevicePtr p);
// void  xf86findLayout(const(char)* name, XF86ConfLayoutPtr list);
// void  xf86findMonitor(const(char)* ident, XF86ConfMonitorPtr p);
// void  xf86findModes(const(char)* ident, XF86ConfModesPtr p);
void  xf86findModeLine(const(char)* ident, XF86ConfModeLinePtr p);
// void  xf86findScreen(const(char)* ident, XF86ConfScreenPtr p);
// void  xf86findInput(const(char)* ident, XF86ConfInputPtr p);
// void  xf86findInputByDriver(const(char)* driver, XF86ConfInputPtr p);
// void  xf86findVideoAdaptor(const(char)* ident, XF86ConfVideoAdaptorPtr p);
// void  xf86addListItem(GenericListPtr head, GenericListPtr c_new);
// void  xf86itemNotSublist(GenericListPtr list_1, GenericListPtr list_2);
void  xf86pathIsAbsolute(const(char)* path);
// void  xf86pathIsSafe(const(char)* path);
// void * xf86addComment(char* cur, const(char)* add);
// void  xf86getBoolValue(Bool* val, const(char)* str);

                          /* _xf86Parser_h_ */
