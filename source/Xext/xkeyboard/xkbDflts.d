module xkb.xkbDflts;
@nogc nothrow:
extern(C): __gshared:
version (DEFAULT_H) {} else {
enum DEFAULT_H = 1;

public import dix.dix_priv;
import externs.X11.extensions.XKB;

import x11.keysymdef;
import xkb.xkbstr;
import xkb.xkbstr;


alias  DPYTYPE =	char *;
enum NUM_KEYS =	1;

enum	vmod_NumLock =	0;
enum	vmod_Alt =	1;
enum	vmod_LevelThree =	2;
enum	vmod_AltGr =	3;
enum	vmod_ScrollLock =	4;

enum	vmod_NumLockMask =	(1<<0);
enum	vmod_AltMask =	(1<<1);
enum	vmod_LevelThreeMask =	(1<<2);
enum	vmod_AltGrMask =	(1<<3);
enum	vmod_ScrollLockMask =	(1<<4);

/* types name is "default" */
Atom[1] lnames_ONE_LEVEL = [None];

enum XkbKTMapEntryRec[1] map_TWO_LEVEL = [
    {1, 1, {ShiftMask, ShiftMask, 0}}
];

Atom[2] lnames_TWO_LEVEL;

enum XkbKTMapEntryRec[2] map_ALPHABETIC = [
    {1, 1, {ShiftMask, ShiftMask, 0}},
    {1, 0, {LockMask, LockMask, 0}}
];

XkbModsRec[2] preserve_ALPHABETIC = [
    {0, 0, 0},
    {LockMask, LockMask, 0}
];

Atom[2] lnames_ALPHABETIC;

enum XkbKTMapEntryRec[2] map_KEYPAD = [
    {1, 1, {ShiftMask, ShiftMask, 0}},
    {0, 1, {0, 0, vmod_NumLockMask}}
];

Atom[2] lnames_KEYPAD;

enum XkbKTMapEntryRec[1] map_PC_BREAK = [
    {1, 1, {ControlMask, ControlMask, 0}}
];

Atom[2] lnames_PC_BREAK;

enum XkbKTMapEntryRec[1] map_PC_SYSRQ = [
    {0, 1, {0, 0, vmod_AltMask}}
];

Atom[2] lnames_PC_SYSRQ;

enum XkbKTMapEntryRec[1] map_CTRL_ALT = [
    {0, 1, {ControlMask, ControlMask, vmod_AltMask}}
];

Atom[2] lnames_CTRL_ALT;

enum XkbKTMapEntryRec[3] map_THREE_LEVEL = [
    {1, 1, {ShiftMask, ShiftMask, 0}},
    {0, 2, {0, 0, vmod_LevelThreeMask}},
    {0, 2, {ShiftMask, ShiftMask, vmod_LevelThreeMask}}
];

Atom[3] lnames_THREE_LEVEL;

enum XkbKTMapEntryRec[1] map_SHIFT_ALT = [
    {0, 1, {ShiftMask, ShiftMask, vmod_AltMask}}
];

Atom[2] lnames_SHIFT_ALT;

XkbKeyTypeRec[9] dflt_types = [
    {
     {0, 0, 0},
     1,
     0, null, null,
     None, lnames_ONE_LEVEL.ptr},
    {
     {ShiftMask, ShiftMask, 0},
     2,
     1, map_TWO_LEVEL.ptr, null,
     None, lnames_TWO_LEVEL.ptr},
    {
     {ShiftMask | LockMask, ShiftMask | LockMask, 0},
     2,
     2, map_ALPHABETIC.ptr, preserve_ALPHABETIC.ptr,
     None, lnames_ALPHABETIC.ptr},
    {
     {ShiftMask, ShiftMask, vmod_NumLockMask},
     2,
     2, map_KEYPAD.ptr, null,
     None, lnames_KEYPAD.ptr},
    {
     {ControlMask, ControlMask, 0},
     2,
     1, map_PC_BREAK.ptr, null,
     None, lnames_PC_BREAK.ptr},
    {
     {0, 0, vmod_AltMask},
     2,
     1, map_PC_SYSRQ.ptr, null,
     None, lnames_PC_SYSRQ.ptr},
    {
     {ControlMask, ControlMask, vmod_AltMask},
     2,
     1, map_CTRL_ALT.ptr, null,
     None, lnames_CTRL_ALT.ptr},
    {
     {ShiftMask, ShiftMask, vmod_LevelThreeMask},
     3,
     3, map_THREE_LEVEL.ptr, null,
     None, lnames_THREE_LEVEL.ptr},
    {
     {ShiftMask, ShiftMask, vmod_AltMask},
     2,
     1, map_SHIFT_ALT.ptr, null,
     None, lnames_SHIFT_ALT.ptr}
];

enum num_dflt_types = dflt_types.length;

void initTypeNames(DPYTYPE dpy)
{
    dflt_types[0].name = dixAddAtom("ONE_LEVEL");
    lnames_ONE_LEVEL[0] = dixAddAtom("Any");
    dflt_types[1].name = dixAddAtom("TWO_LEVEL");
    lnames_TWO_LEVEL[0] = dixAddAtom("Base");
    lnames_TWO_LEVEL[1] = dixAddAtom("Shift");
    dflt_types[2].name = dixAddAtom("ALPHABETIC");
    lnames_ALPHABETIC[0] = dixAddAtom("Base");
    lnames_ALPHABETIC[1] = dixAddAtom("Caps");
    dflt_types[3].name = dixAddAtom("KEYPAD");
    lnames_KEYPAD[0] = dixAddAtom("Base");
    lnames_KEYPAD[1] = dixAddAtom("Number");
    dflt_types[4].name = dixAddAtom("PC_BREAK");
    lnames_PC_BREAK[0] = dixAddAtom("Base");
    lnames_PC_BREAK[1] = dixAddAtom("Control");
    dflt_types[5].name = dixAddAtom("PC_SYSRQ");
    lnames_PC_SYSRQ[0] = dixAddAtom("Base");
    lnames_PC_SYSRQ[1] = dixAddAtom("Alt");
    dflt_types[6].name = dixAddAtom("CTRL+ALT");
    lnames_CTRL_ALT[0] = dixAddAtom("Base");
    lnames_CTRL_ALT[1] = dixAddAtom("Ctrl+Alt");
    dflt_types[7].name = dixAddAtom("THREE_LEVEL");
    lnames_THREE_LEVEL[0] = dixAddAtom("Base");
    lnames_THREE_LEVEL[1] = dixAddAtom("Shift");
    lnames_THREE_LEVEL[2] = dixAddAtom("Level3");
    dflt_types[8].name = dixAddAtom("SHIFT+ALT");
    lnames_SHIFT_ALT[0] = dixAddAtom("Base");
    lnames_SHIFT_ALT[1] = dixAddAtom("Shift+Alt");
}

/* compat name is "default" */
XkbSymInterpretRec[69] dfltSI = [
    {XK_ISO_Level2_Latch, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_Exactly, ShiftMask,
     255,
     {XkbSA_LatchMods, [0x03, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Eisu_Shift, 0x0000,
     XkbSI_Exactly, LockMask,
     255,
     {XkbSA_NoAction, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Eisu_toggle, 0x0000,
     XkbSI_Exactly, LockMask,
     255,
     {XkbSA_NoAction, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Kana_Shift, 0x0000,
     XkbSI_Exactly, LockMask,
     255,
     {XkbSA_NoAction, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Kana_Lock, 0x0000,
     XkbSI_Exactly, LockMask,
     255,
     {XkbSA_NoAction, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Shift_Lock, 0x0000,
     XkbSI_AnyOf, ShiftMask | LockMask,
     255,
     {XkbSA_LockMods, [0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Num_Lock, 0x0000,
     XkbSI_AnyOf, 0xff,
     0,
     {XkbSA_LockMods, [0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]}},
    {XK_Alt_L, 0x0000,
     XkbSI_AnyOf, 0xff,
     1,
     {XkbSA_SetMods, [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Alt_R, 0x0000,
     XkbSI_AnyOf, 0xff,
     1,
     {XkbSA_SetMods, [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Scroll_Lock, 0x0000,
     XkbSI_AnyOf, 0xff,
     4,
     {XkbSA_LockMods, [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Lock, 0x0000,
     XkbSI_AnyOf, 0xff,
     255,
     {XkbSA_ISOLock, [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Level3_Shift, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOf, 0xff,
     2,
     {XkbSA_SetMods, [0x01, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00]}},
    {XK_ISO_Level3_Latch, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOf, 0xff,
     2,
     {XkbSA_LatchMods, [0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00]}},
    {XK_Mode_switch, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOfOrNone, 0xff,
     3,
     {XkbSA_SetGroup, [0x05, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_1, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_End, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_2, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_Down, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_3, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_Next, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]}},
    {XK_KP_4, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Left, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_6, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Right, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_7, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_Home, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_8, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_Up, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_9, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_Prior, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_MovePtr, [0x00, 0x00, 0x01, 0xff, 0xff, 0x00, 0x00]}},
    {XK_KP_5, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Begin, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_F1, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Divide, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_F2, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Multiply, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_F3, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Subtract, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x04, 0x01, 0x03, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Separator, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Add, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_0, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Insert, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Decimal, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_KP_Delete, 0x0001,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Button_Dflt, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Button1, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Button2, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Button3, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_DblClick_Dflt, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_DblClick1, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_DblClick2, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_DblClick3, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_PtrBtn, [0x00, 0x02, 0x03, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Drag_Dflt, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Drag1, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Drag2, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_Drag3, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockPtrBtn, [0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_EnableKeys, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockControls, [0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00]}},
    {XK_Pointer_Accelerate, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockControls, [0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00]}},
    {XK_Pointer_DfltBtnNext, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00]}},
    {XK_Pointer_DfltBtnPrev, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_SetPtrDflt, [0x00, 0x01, 0xff, 0x00, 0x00, 0x00, 0x00]}},
    {XK_AccessX_Enable, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockControls, [0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00]}},
    {XK_Terminate_Server, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_Terminate, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Group_Latch, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOfOrNone, 0xff,
     3,
     {XkbSA_LatchGroup, [0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Next_Group, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOfOrNone, 0xff,
     3,
     {XkbSA_LockGroup, [0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Prev_Group, 0x0000,
     XkbSI_LevelOneOnly | XkbSI_AnyOfOrNone, 0xff,
     3,
     {XkbSA_LockGroup, [0x00, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_First_Group, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockGroup, [0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {XK_ISO_Last_Group, 0x0000,
     XkbSI_AnyOfOrNone, 0xff,
     255,
     {XkbSA_LockGroup, [0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00]}},
    {NoSymbol, 0x0000,
     XkbSI_Exactly, LockMask,
     255,
     {XkbSA_LockMods, [0x00, 0x02, 0x02, 0x00, 0x00, 0x00, 0x00]}},
    {NoSymbol, 0x0000,
     XkbSI_AnyOf, 0xff,
     255,
     {XkbSA_SetMods, [0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]}}
];

enum num_dfltSI = dfltSI.length;

XkbCompatMapRec compatMap = {
    sym_interpret: dfltSI.ptr,
    groups: [
        XkbModsRec(0, 0, 0),
        XkbModsRec(0, 0, vmod_AltGrMask),
        XkbModsRec(0, 0, vmod_AltGrMask),
        XkbModsRec(0, 0, vmod_AltGrMask)
    ],
    num_si: num_dfltSI,
    size_si: num_dfltSI
};

void initIndicatorNames(DPYTYPE dpy, XkbDescPtr xkb)
{
    xkb.names.indicators[0] = dixAddAtom("Caps Lock");
    xkb.names.indicators[1] = dixAddAtom("Num Lock");
    xkb.names.indicators[2] = dixAddAtom("Shift Lock");
    xkb.names.indicators[3] = dixAddAtom("Mouse Keys");
    xkb.names.indicators[4] = dixAddAtom("Scroll Lock");
    xkb.names.indicators[5] = dixAddAtom("Group 2");
}
}                          /* DEFAULT_H */
