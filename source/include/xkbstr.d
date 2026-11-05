module include.xkbstr;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/************************************************************
Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.

Permission to use, copy, modify, and distribute this
software and its documentation for any purpose and without
fee is hereby granted, provided that the above copyright
notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting
documentation, and that the name of Silicon Graphics not be
used in advertising or publicity pertaining to distribution
of the software without specific prior written permission.
Silicon Graphics makes no representation about the suitability
of this software for any purpose. It is provided "as is"
without any express or implied warranty.

SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

 
public import x11.Xdefs;
//import x11.X;
import externs.X11.extensions.XKB;
// import externs.X11.extensions.XKBgeom;
import dix.input;
import xkb.xkbgeom_priv;
import include.xkbstr;
// //public import externs.X11.extensions.XKB;

enum string	XkbCharToInt(string v) = `(cast(int) ((` ~ v ~ `) & 0x80 ? ((` ~ v ~ `) | (~0xff)) : ((` ~ v ~ `) & 0x7f)))`;
enum string	XkbIntTo2Chars(string i, string h, string l) = `((` ~ h ~ `) = (` ~ i ~ ` >> 8) & 0xff, (` ~ l ~ `) = (` ~ i ~ `) & 0xff)`;

static if (HasVersion!"WORD64" && HasVersion!"UNSIGNEDBITFIELDS") {
enum string	Xkb2CharsToInt(string h, string l) = `(cast(int) ((` ~ h ~ `) & 0x80 ? 
                              (((` ~ h ~ `) << 8) | (` ~ l ~ `) | (~0xffff)) : 
                              (((` ~ h ~ `) << 8) | (` ~ l ~ `) & 0x7fff))`;
} else {
enum string	Xkb2CharsToInt(string h,string l) = `(cast(short)(((` ~ h ~ `)<<8)|(` ~ l ~ `)))`;
}

        /*
         * Common data structures and access macros
         */

struct _XkbStateRec {
    ubyte group;        /* base + latched + locked */
    /* FIXME: Why are base + latched short and not char?? */
    ushort base_group;  /* physically ... down? */
    ushort latched_group;
    ubyte locked_group;

    ubyte mods;         /* base + latched + locked */
    ubyte base_mods;    /* physically down */
    ubyte latched_mods;
    ubyte locked_mods;

    ubyte compat_state; /* mods + group for core state */

    /* grab mods = all depressed and latched mods, _not_ locked mods */
    ubyte grab_mods;    /* grab mods minus internal mods */
    ubyte compat_grab_mods;     /* grab mods + group for core state,
                                           but not locked groups if
                                           IgnoreGroupLocks set */

    /* effective mods = all mods (depressed, latched, locked) */
    ubyte lookup_mods;  /* effective mods minus internal mods */
    ubyte compat_lookup_mods;   /* effective mods + group */

    ushort ptr_buttons; /* core pointer buttons */
}alias XkbStateRec = _XkbStateRec;
alias XkbStatePtr = _XkbStateRec*;

enum string	XkbStateFieldFromRec(string s) = XkbBuildCoreState!(`(`~s~`).lookup_mods`,`(` ~ s ~ `).group`);
enum string	XkbGrabStateFromRec(string s) = XkbBuildCoreState!(`(` ~ s ~ `).grab_mods`,`(` ~ s ~ `).group`);

struct _XkbMods {
    ubyte mask;         /* effective mods */
    ubyte real_mods;
    ushort vmods;
}alias XkbModsRec = _XkbMods;
alias XkbModsPtr = _XkbMods*;

struct _XkbKTMapEntry {
    Bool active;
    ubyte level;
    XkbModsRec mods;
}alias XkbKTMapEntryRec = _XkbKTMapEntry;
alias XkbKTMapEntryPtr = _XkbKTMapEntry*;

struct _XkbKeyType {
    XkbModsRec mods;
    ubyte num_levels;
    ubyte map_count;
    XkbKTMapEntryPtr map;
    XkbModsPtr preserve;
    Atom name;
    Atom* level_names;
}alias XkbKeyTypeRec = _XkbKeyType;
alias XkbKeyTypePtr = _XkbKeyType*;

enum string	XkbNumGroups(string g) = `((` ~ g ~ `)&0x0f)`;
enum string	XkbOutOfRangeGroupInfo(string g) = `((` ~ g ~ `)&0xf0)`;
enum string	XkbOutOfRangeGroupAction(string g) = `((` ~ g ~ `)&0xc0)`;
enum string	XkbOutOfRangeGroupNumber(string g) = `(((` ~ g ~ `)&0x30)>>4)`;
enum string	XkbSetGroupInfo(string g, string w, string n) = `(((` ~ w ~ `) & 0xc0) | (((` ~ n ~ `) & 3) << 4) | 
                                  ((` ~ g ~ `) & 0x0f))`;
enum string	XkbSetNumGroups(string g,string n) = `(((` ~ g ~ `)&0xf0)|((` ~ n ~ `)&0x0f))`;

        /*
         * Structures and access macros used primarily by the server
         */

struct _XkbBehavior {
    ubyte type;
    ubyte data;
}
alias XkbBehavior = _XkbBehavior;

enum	XkbAnyActionDataSize = 7;
struct XkbAnyAction {
    ubyte type;
    ubyte[XkbAnyActionDataSize] data;
}

struct XkbModAction {
    ubyte type;
    ubyte flags;
    ubyte mask;
    ubyte real_mods;
    /* FIXME: Make this an int. */
    ubyte vmods1;
    ubyte vmods2;
}

enum string	XkbModActionVMods(string a) = `(cast(short) (((` ~ a ~ `).vmods1 << 8) | (` ~ a ~ `).vmods2))`;
enum string	XkbSetModActionVMods(string a,string v) = `
	((` ~ a ~ `).vmods1 = (((` ~ v ~ `) >> 8) & 0xff), 
         (` ~ a ~ `).vmods2 = (` ~ v ~ `) & 0xff)`;

struct XkbGroupAction {
    ubyte type;
    ubyte flags;
    /* FIXME: Make this an int. */
    char group_XXX = 0;
}

enum string	XkbSAGroup(string a) = `(cast(ubyte)` ~ XkbCharToInt!(`(` ~ a ~ `).group_XXX`) ~ `)`;
enum string	XkbSASetGroup(string a,string g) = `((` ~ a ~ `).group_XXX=cast(char)(` ~ g ~ `));`;

struct XkbISOAction {
    ubyte type;
    ubyte flags;
    ubyte mask;
    ubyte real_mods;
    /* FIXME: Make this an int. */
    char group_XXX = 0;
    ubyte affect;
    ubyte vmods1;
    ubyte vmods2;
}

struct XkbPtrAction {
    ubyte type;
    ubyte flags;
    /* FIXME: Make this an int. */
    ubyte high_XXX;
    ubyte low_XXX;
    ubyte high_YYY;
    ubyte low_YYY;
}

enum string	XkbPtrActionX(string a) = `(` ~ Xkb2CharsToInt!(`(` ~ a ~ `).high_XXX`,`(` ~ a ~ `).low_XXX`) ~ `)`;
enum string	XkbPtrActionY(string a) = `(` ~ Xkb2CharsToInt!(`(` ~ a ~ `).high_YYY`,`(` ~ a ~ `).low_YYY`) ~ `)`;
enum string	XkbSetPtrActionX(string a,string x) = `(` ~ XkbIntTo2Chars!(x,`(` ~ a ~ `).high_XXX`,`(` ~ a ~ `).low_XXX`) ~ `)`;
enum string	XkbSetPtrActionY(string a,string y) = `(` ~ XkbIntTo2Chars!(y,`(` ~ a ~ `).high_YYY`,`(` ~ a ~ `).low_YYY`) ~ `)`;

struct XkbPtrBtnAction {
    ubyte type;
    ubyte flags;
    ubyte count;
    ubyte button;
}

struct XkbPtrDfltAction {
    ubyte type;
    ubyte flags;
    ubyte affect;
    char valueXXX = 0;
}

enum string	XkbSAPtrDfltValue(string a) = `(` ~ XkbCharToInt!(`(` ~ a ~ `).valueXXX`) ~ `)`;
enum string	XkbSASetPtrDfltValue(string a, string c) = `((` ~ a ~ `).valueXXX = (` ~ c ~ `) & 0xff)`;

struct XkbSwitchScreenAction {
    ubyte type;
    ubyte flags;
    char screenXXX = 0;
}

enum string	XkbSAScreen(string a) = `(` ~ XkbCharToInt!(`(` ~ a ~ `).screenXXX`) ~ `)`;
enum string	XkbSASetScreen(string a, string s) = `((` ~ a ~ `).screenXXX = (` ~ s ~ `) & 0xff)`;

struct XkbCtrlsAction {
    ubyte type;
    ubyte flags;
    /* FIXME: Make this an int. */
    ubyte ctrls3;
    ubyte ctrls2;
    ubyte ctrls1;
    ubyte ctrls0;
}

enum string	XkbActionSetCtrls(string a, string c) = `((` ~ a ~ `).ctrls3 = ((` ~ c ~ `) >> 24) & 0xff, 
                                 (` ~ a ~ `).ctrls2 = ((` ~ c ~ `) >> 16) & 0xff, 
                                 (` ~ a ~ `).ctrls1 = ((` ~ c ~ `) >> 8) & 0xff, 
                                 (` ~ a ~ `).ctrls0 = (` ~ c ~ `) & 0xff)`;
enum string	XkbActionCtrls(string a) = `(((cast(uint)(` ~ a ~ `).ctrls3)<<24)|
			   ((cast(uint)(` ~ a ~ `).ctrls2)<<16)|
			   ((cast(uint)(` ~ a ~ `).ctrls1)<<8)|
                           (cast(uint) (` ~ a ~ `).ctrls0))`;

struct XkbMessageAction {
    ubyte type;
    ubyte flags;
    ubyte[6] message;
}

struct XkbRedirectKeyAction {
    ubyte type;
    ubyte new_key;
    ubyte mods_mask;
    ubyte mods;
    /* FIXME: Make this an int. */
    ubyte vmods_mask0;
    ubyte vmods_mask1;
    ubyte vmods0;
    ubyte vmods1;
}

enum string	XkbSARedirectVMods(string a) = `(((cast(uint)(` ~ a ~ `).vmods1)<<8)|
					(cast(uint)(` ~ a ~ `).vmods0))`;
/* FIXME: This is blatantly not setting vmods.   Yeesh. */
enum string	XkbSARedirectSetVMods(string a,string m) = `(((` ~ a ~ `).vmods_mask1=(((` ~ m ~ `)>>8)&0xff)),
					 ((` ~ a ~ `).vmods_mask0=((` ~ m ~ `)&0xff)))`;
enum string	XkbSARedirectVModsMask(string a) = `(((cast(uint)(` ~ a ~ `).vmods_mask1)<<8)|
					(cast(uint)(` ~ a ~ `).vmods_mask0))`;
enum string	XkbSARedirectSetVModsMask(string a,string m) = `(((` ~ a ~ `).vmods_mask1=(((` ~ m ~ `)>>8)&0xff)),
					 ((` ~ a ~ `).vmods_mask0=((` ~ m ~ `)&0xff)))`;

struct XkbDeviceBtnAction {
    ubyte type;
    ubyte flags;
    ubyte count;
    ubyte button;
    ubyte device;
}

struct XkbDeviceValuatorAction {
    ubyte type;
    ubyte device;
    ubyte v1_what;
    ubyte v1_ndx;
    ubyte v1_value;
    ubyte v2_what;
    ubyte v2_ndx;
    ubyte v2_value;
}

union _XkbAction {
    XkbAnyAction any;
    XkbModAction mods;
    XkbGroupAction group;
    XkbISOAction iso;
    XkbPtrAction ptr;
    XkbPtrBtnAction btn;
    XkbPtrDfltAction dflt;
    XkbSwitchScreenAction screen;
    XkbCtrlsAction ctrls;
    XkbMessageAction msg;
    XkbRedirectKeyAction redirect;
    XkbDeviceBtnAction devbtn;
    XkbDeviceValuatorAction devval;
    ubyte type;
}
alias XkbAction = _XkbAction;
// alias XkbAction = _XkbAction;


struct _XkbControls {
    ubyte mk_dflt_btn;
    ubyte num_groups;
    ubyte groups_wrap;
    XkbModsRec internal;
    XkbModsRec ignore_lock;
    uint enabled_ctrls;
    ushort repeat_delay;
    ushort repeat_interval;
    ushort slow_keys_delay;
    ushort debounce_delay;
    ushort mk_delay;
    ushort mk_interval;
    ushort mk_time_to_max;
    ushort mk_max_speed;
    short mk_curve;
    ushort ax_options;
    ushort ax_timeout;
    ushort axt_opts_mask;
    ushort axt_opts_values;
    uint axt_ctrls_mask;
    uint axt_ctrls_values;
    ubyte[XkbPerKeyBitArraySize] per_key_repeat;
}alias XkbControlsRec = _XkbControls;
alias XkbControlsPtr = _XkbControls*;

enum string	XkbAX_AnyFeedback(string c) = `((` ~ c ~ `).enabled_ctrls&XkbAccessXFeedbackMask)`;
enum string	XkbAX_NeedOption(string c,string w) = `((` ~ c ~ `).ax_options&(` ~ w ~ `))`;
enum string	XkbAX_NeedFeedback(string c, string w) = `(` ~ XkbAX_AnyFeedback!(`(` ~ c ~ `)`) ~ ` && 
                                  ` ~ XkbAX_NeedOption!(`(` ~ c ~ `)`, `(` ~ w ~ `)`) ~ `)`;

struct _XkbServerMapRec {
    ushort num_acts;
    ushort size_acts;
    XkbAction* acts;

    XkbBehavior* behaviors;
    ushort* key_acts;
static if (HasVersion!"none" || HasVersion!"c_plusplus") {
    /* explicit is a C++ reserved word */
    ubyte* c_explicit;
} else {
    ubyte* explicit;
}
    ubyte[XkbNumVirtualMods] vmods;
    ushort* vmodmap;
}alias XkbServerMapRec = _XkbServerMapRec;
alias XkbServerMapPtr = _XkbServerMapRec*;

enum string	XkbSMKeyActionsPtr(string m, string k) = `(&(` ~ m ~ `).acts[(` ~ m ~ `).key_acts[(` ~ k ~ `)]])`;

        /*
         * Structures and access macros used primarily by clients
         */

struct _XkbSymMapRec {
    ubyte[XkbNumKbdGroups] kt_index;
    ubyte group_info;
    ubyte width;
    ushort offset;
}alias XkbSymMapRec = _XkbSymMapRec;
alias XkbSymMapPtr = _XkbSymMapRec*;

struct _XkbClientMapRec {
    ubyte size_types;
    ubyte num_types;
    XkbKeyTypePtr types;

    ushort size_syms;
    ushort num_syms;
    KeySym* syms;
    XkbSymMapPtr key_sym_map;

    ubyte* modmap;
}alias XkbClientMapRec = _XkbClientMapRec;
alias XkbClientMapPtr = _XkbClientMapRec*;

enum string	XkbCMKeyGroupInfo(string m, string k) = `((` ~ m ~ `).key_sym_map[(` ~ k ~ `)].group_info)`;
enum string	XkbCMKeyNumGroups(string m, string k) = `(` ~ XkbNumGroups!(`(` ~ m ~ `).key_sym_map[(` ~ k ~ `)].group_info`) ~ `)`;
enum string XkbCMKeyGroupWidth(string m, string k, string g) =
    `(` ~ XkbCMKeyType!(
        m,
        k,
        `(` ~ g ~ `)`
    ) ~ `.num_levels)`;
enum string	XkbCMKeyGroupsWidth(string m, string k) = `((` ~ m ~ `).key_sym_map[(` ~ k ~ `)].width)`;
enum string	XkbCMKeyTypeIndex(string m, string k, string g) = `((` ~ m ~ `).key_sym_map[(` ~ k ~ `)].kt_index[(` ~ g ~ `) & 0x3])`;
enum string	XkbCMKeyType(string m, string k, string g) = `(&(` ~ m ~ `).types[` ~ XkbCMKeyTypeIndex!(`(` ~ m ~ `)`, `(` ~ k ~ `)`, `(` ~ g ~ `)`) ~ `])`;
enum string	XkbCMKeyNumSyms(string m, string k) = `(` ~ XkbCMKeyGroupsWidth!(`(` ~ m ~ `)`, `(` ~ k ~ `)`) ~ ` * 
                               ` ~ XkbCMKeyNumGroups!(`(` ~ m ~ `)`, `(` ~ k ~ `)`) ~ `)`;
enum string	XkbCMKeySymsOffset(string m, string k) = `((` ~ m ~ `).key_sym_map[(` ~ k ~ `)].offset)`;
enum string	XkbCMKeySymsPtr(string m, string k) = `(&(` ~ m ~ `).syms[` ~ XkbCMKeySymsOffset!(`(` ~ m ~ `)`, `(` ~ k ~ `)`) ~ `])`;

        /*
         * Compatibility structures and access macros
         */

struct _XkbSymInterpretRec {
    KeySym sym;
    ubyte flags;
    ubyte match;
    ubyte mods;
    ubyte virtual_mod;
    XkbAnyAction act;
}alias XkbSymInterpretRec = _XkbSymInterpretRec;
alias XkbSymInterpretPtr = _XkbSymInterpretRec*;

struct _XkbCompatMapRec {
    XkbSymInterpretPtr sym_interpret;
    XkbModsRec[XkbNumKbdGroups] groups;
    ushort num_si;
    ushort size_si;
}alias XkbCompatMapRec = _XkbCompatMapRec;
alias XkbCompatMapPtr = _XkbCompatMapRec*;

struct _XkbIndicatorMapRec {
    ubyte flags;
    /* FIXME: For some reason, interpretation of groups is wildly
     *        different between which being base/latched/locked. */
    ubyte which_groups;
    ubyte groups;
    ubyte which_mods;
    XkbModsRec mods;
    uint ctrls;
}alias XkbIndicatorMapRec = _XkbIndicatorMapRec;
alias XkbIndicatorMapPtr = _XkbIndicatorMapRec*;

enum string	XkbIM_IsAuto(string i) = `(!((` ~ i ~ `).flags & XkbIM_NoAutomatic) && 
			    (((` ~ i ~ `).which_groups&&(` ~ i ~ `).groups)||
			     ((` ~ i ~ `).which_mods&&(` ~ i ~ `).mods.mask)||
                          (` ~ i ~ `).ctrls))`;
enum string	XkbIM_InUse(string i) = `((` ~ i ~ `).flags || (` ~ i ~ `).which_groups || (` ~ i ~ `).which_mods || 
                         (` ~ i ~ `).ctrls)`;

struct _XkbIndicatorRec {
    c_ulong phys_indicators;
    XkbIndicatorMapRec[XkbNumIndicators] maps;
}alias XkbIndicatorRec = _XkbIndicatorRec;
alias XkbIndicatorPtr = _XkbIndicatorRec*;

struct _XkbKeyNameRec {
    char[XkbKeyNameLength] name = 0;
}alias XkbKeyNameRec = _XkbKeyNameRec;
alias XkbKeyNamePtr = _XkbKeyNameRec*;

struct _XkbKeyAliasRec {
    char[XkbKeyNameLength] real_ = 0;
    char[XkbKeyNameLength] alias_ = 0;
}alias XkbKeyAliasRec = _XkbKeyAliasRec;
alias XkbKeyAliasPtr = _XkbKeyAliasRec*;

        /*
         * Names for everything
         */
struct _XkbNamesRec {
    Atom keycodes;
    Atom geometry;
    Atom symbols;
    Atom types;
    Atom compat;
    Atom[XkbNumVirtualMods] vmods;
    Atom[XkbNumIndicators] indicators;
    Atom[XkbNumKbdGroups] groups;
    XkbKeyNamePtr keys;
    XkbKeyAliasPtr key_aliases;
    Atom* radio_groups;
    Atom phys_symbols;

    ubyte num_keys;
    ubyte num_key_aliases;
    ushort num_rg;
}alias XkbNamesRec = _XkbNamesRec;
alias XkbNamesPtr = _XkbNamesRec*;

struct _XkbGeometry {
	Atom		 name;
	ushort	 width_mm;
	ushort	 height_mm;
	char *		 label_font;
	XkbColorPtr	 label_color;
	XkbColorPtr	 base_color;
	ushort	 sz_properties;
	ushort	 sz_colors;
	ushort	 sz_shapes;
	ushort   sz_sections;
	ushort	 sz_doodads;
	ushort	 sz_key_aliases;
	ushort	 num_properties;
	ushort	 num_colors;
	ushort	 num_shapes;
	ushort	 num_sections;
	ushort	 num_doodads;
	ushort	 num_key_aliases;
	XkbPropertyPtr	 properties;
	XkbColorPtr	 colors;
	XkbShapePtr	 shapes;
	XkbSectionPtr	 sections;
	XkbDoodadPtr	 doodads;
	XkbKeyAliasPtr	 key_aliases;
} 
alias XkbGeometryRec = _XkbGeometry;

alias XkbGeometryPtr = _XkbGeometry*;

        /*
         * Tie it all together into one big keyboard description
         */
struct _XkbDesc {
    uint defined;
    ushort flags;
    ushort device_spec;
    KeyCode min_key_code;
    KeyCode max_key_code;

    XkbControlsPtr ctrls;
    XkbServerMapPtr server;
    XkbClientMapPtr map;
    XkbIndicatorPtr indicators;
    XkbNamesPtr names;
    XkbCompatMapPtr compat;
    XkbGeometryPtr geom;
}alias XkbDescRec = _XkbDesc;
alias XkbDescPtr = _XkbDesc*;

enum string	XkbKeyKeyTypeIndex(string d, string k, string g) = `(` ~ XkbCMKeyTypeIndex!(`(` ~ d ~ `).map`, `(` ~ k ~ `)`, `(` ~ g ~ `)`) ~ `)`;
enum string	XkbKeyKeyType(string d, string k, string g) = `(` ~ XkbCMKeyType!(`(` ~ d ~ `).map`, `(` ~ k ~ `)`, `(` ~ g ~ `)`) ~ `)`;
enum string	XkbKeyGroupWidth(string d, string k, string g) = `(` ~ XkbCMKeyGroupWidth!(`(` ~ d ~ `).map`, `(` ~ k ~ `)`, `(` ~ g ~ `)`) ~ `)`;
enum string	XkbKeyGroupsWidth(string d, string k) = `(` ~ XkbCMKeyGroupsWidth!(`(` ~ d ~ `).map`, `(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeyGroupInfo(string d,string k) = `(` ~ XkbCMKeyGroupInfo!(`(` ~ d ~ `).map`,`(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeyNumGroups(string d,string k) = `(` ~ XkbCMKeyNumGroups!(`(` ~ d ~ `).map`,`(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeyNumSyms(string d,string k) = `(` ~ XkbCMKeyNumSyms!(`(` ~ d ~ `).map`,`(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeySymsPtr(string d,string k) = `(` ~ XkbCMKeySymsPtr!(`(` ~ d ~ `).map`,`(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeySym(string d, string k, string n) = `(` ~ XkbKeySymsPtr!(`(` ~ d ~ `)`, `(` ~ k ~ `)`) ~ `[(` ~ n ~ `)])`;
enum string	XkbKeySymEntry(string d,string k,string sl,string g) = `
    (` ~ XkbKeySym!(`(` ~ d ~ `)`, `(` ~ k ~ `)`, `(` ~ XkbKeyGroupsWidth!(`(` ~ d ~ `)`, `(` ~ k ~ `)`) ~ ` * (` ~ g ~ `)) + (` ~ sl ~ `)`) ~ `)`;
enum string	XkbKeyAction(string d,string k,string n) = `
    (XkbKeyHasActions((` ~ d ~ `), (` ~ k ~ `)) ? & XkbKeyActionsPtr((` ~ d ~ `), (` ~ k ~ `))[(` ~ n ~ `)] : null)`;
enum string	XkbKeyActionEntry(string d,string k,string sl,string g) = `
    (XkbKeyHasActions((` ~ d ~ `), (` ~ k ~ `)) ? 
     ` ~ XkbKeyAction!(`(` ~ d ~ `)`, `(` ~ k ~ `)`, `((` ~ XkbKeyGroupsWidth!(`(` ~ d ~ `)`, `(` ~ k ~ `)`) ~ ` * (` ~ g ~ `)) + (` ~ sl ~ `))`) ~ ` : 
     null)`;

enum string	XkbKeyHasActions(string d, string k) = `(!!(` ~ d ~ `).server.key_acts[(` ~ k ~ `)])`;
enum string	XkbKeyNumActions(string d, string k) = `(` ~ XkbKeyHasActions!(`(` ~ d ~ `)`, `(` ~ k ~ `)`) ~ ` ? 
                                ` ~ XkbKeyNumSyms!(`(` ~ d ~ `)`, `(` ~ k ~ `)`) ~ ` : 1)`;
enum string	XkbKeyActionsPtr(string d, string k) = `(` ~ XkbSMKeyActionsPtr!(`(` ~ d ~ `).server`, `(` ~ k ~ `)`) ~ `)`;
enum string	XkbKeycodeInRange(string d, string k) = `((` ~ k ~ `) >= (` ~ d ~ `).min_key_code && 
				 (` ~ k ~ `) <= (` ~ d ~ `).max_key_code)`;
enum string	XkbNumKeys(string d) = `((` ~ d ~ `).max_key_code-(` ~ d ~ `).min_key_code+1)`;

        /*
         * The following structures can be used to track changes
         * to a keyboard device
         */
struct _XkbMapChanges {
    ushort changed;
    KeyCode min_key_code;
    KeyCode max_key_code;
    ubyte first_type;
    ubyte num_types;
    KeyCode first_key_sym;
    ubyte num_key_syms;
    KeyCode first_key_act;
    ubyte num_key_acts;
    KeyCode first_key_behavior;
    ubyte num_key_behaviors;
    KeyCode first_key_explicit;
    ubyte num_key_explicit;
    KeyCode first_modmap_key;
    ubyte num_modmap_keys;
    KeyCode first_vmodmap_key;
    ubyte num_vmodmap_keys;
    ubyte pad;
    ushort vmods;
}alias XkbMapChangesRec = _XkbMapChanges;
alias XkbMapChangesPtr = _XkbMapChanges*;

struct _XkbControlsChanges {
    uint changed_ctrls;
    uint enabled_ctrls_changes;
    Bool num_groups_changed;
}alias XkbControlsChangesRec = _XkbControlsChanges;
alias XkbControlsChangesPtr = _XkbControlsChanges*;

struct _XkbIndicatorChanges {
    uint state_changes;
    uint map_changes;
}alias XkbIndicatorChangesRec = _XkbIndicatorChanges;
alias XkbIndicatorChangesPtr = _XkbIndicatorChanges*;

struct _XkbNameChanges {
    uint changed;
    ubyte first_type;
    ubyte num_types;
    ubyte first_lvl;
    ubyte num_lvls;
    ubyte num_aliases;
    ubyte num_rg;
    ubyte first_key;
    ubyte num_keys;
    ushort changed_vmods;
    c_ulong changed_indicators;
    ubyte changed_groups;
}alias XkbNameChangesRec = _XkbNameChanges;
alias XkbNameChangesPtr = _XkbNameChanges*;

struct _XkbCompatChanges {
    ubyte changed_groups;
    ushort first_si;
    ushort num_si;
}alias XkbCompatChangesRec = _XkbCompatChanges;
alias XkbCompatChangesPtr = _XkbCompatChanges*;

struct _XkbChanges {
    ushort device_spec;
    ushort state_changes;
    XkbMapChangesRec map;
    XkbControlsChangesRec ctrls;
    XkbIndicatorChangesRec indicators;
    XkbNameChangesRec names;
    XkbCompatChangesRec compat;
}alias XkbChangesRec = _XkbChanges;
alias XkbChangesPtr = _XkbChanges*;

        /*
         * These data structures are used to construct a keymap from
         * a set of components or to list components in the server
         * database.
         */
struct _XkbComponentNames {
    char* keycodes;
    char* types;
    char* compat;
    char* symbols;
    char* geometry;
}alias XkbComponentNamesRec = _XkbComponentNames;
alias XkbComponentNamesPtr = _XkbComponentNames*;

struct _XkbComponentName {
    ushort flags;
    char* name;
}alias XkbComponentNameRec = _XkbComponentName;
alias XkbComponentNamePtr = _XkbComponentName*;

struct _XkbComponentList {
    int num_keymaps;
    int num_keycodes;
    int num_types;
    int num_compat;
    int num_symbols;
    int num_geometry;
    XkbComponentNamePtr keymaps;
    XkbComponentNamePtr keycodes;
    XkbComponentNamePtr types;
    XkbComponentNamePtr compat;
    XkbComponentNamePtr symbols;
    XkbComponentNamePtr geometry;
}alias XkbComponentListRec = _XkbComponentList;
alias XkbComponentListPtr = _XkbComponentList*;

        /*
         * The following data structures describe and track changes to a
         * non-keyboard extension device
         */
struct _XkbDeviceLedInfo {
    ushort led_class;
    ushort led_id;
    uint phys_indicators;
    uint maps_present;
    uint names_present;
    uint state;
    Atom[XkbNumIndicators] names;
    XkbIndicatorMapRec[XkbNumIndicators] maps;
}alias XkbDeviceLedInfoRec = _XkbDeviceLedInfo;
alias XkbDeviceLedInfoPtr = _XkbDeviceLedInfo*;

struct _XkbDeviceInfo {
    char* name;
    Atom type;
    ushort device_spec;
    Bool has_own_state;
    ushort supported;
    ushort unsupported;

    ushort num_btns;
    XkbAction* btn_acts;

    ushort sz_leds;
    ushort num_leds;
    ushort dflt_kbd_fb;
    ushort dflt_led_fb;
    XkbDeviceLedInfoPtr leds;
}alias XkbDeviceInfoRec = _XkbDeviceInfo;
alias XkbDeviceInfoPtr = _XkbDeviceInfo*;

enum string	XkbXI_DevHasBtnActs(string d) = `((` ~ d ~ `).num_btns > 0 && (` ~ d ~ `).btn_acts)`;
enum string	XkbXI_LegalDevBtn(string d,string b) = `(` ~ XkbXI_DevHasBtnActs!(d) ~ ` && (` ~ b ~ `) < (` ~ d ~ `).num_btns)`;
enum string	XkbXI_DevHasLeds(string d) = `((` ~ d ~ `).num_leds > 0 && (` ~ d ~ `).leds)`;

struct _XkbDeviceLedChanges {
    ushort led_class;
    ushort led_id;
    uint defined;       /* names or maps changed */
    _XkbDeviceLedChanges* next;
}alias XkbDeviceLedChangesRec = _XkbDeviceLedChanges;
alias XkbDeviceLedChangesPtr = _XkbDeviceLedChanges*;

struct _XkbDeviceChanges {
    uint changed;
    ushort first_btn;
    ushort num_btns;
    XkbDeviceLedChangesRec leds;
}alias XkbDeviceChangesRec = _XkbDeviceChanges;
alias XkbDeviceChangesPtr = _XkbDeviceChanges*;

                          /* _XKBSTR_H_ */
