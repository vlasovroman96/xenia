module xkb.xkbtext_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.X;

public import xkb.xkbsrv_priv;
// import externs.X11.extensions.XKBstr;
import xkb.xkbstr;


enum XkbXKMFile =      0;
enum XkbCFile =        1;
enum XkbXKBFile =      2;
enum XkbMessage =      3;

char* XkbIndentText(uint size);
char* XkbAtomText(Atom atm, uint format);
char* XkbKeysymText(KeySym sym, uint format);
char* XkbStringText(char* str, uint format);
char* XkbKeyNameText(char* name, uint format);
char* XkbModIndexText(uint ndx, uint format);
char* XkbModMaskText(uint mask, uint format);
char* XkbVModIndexText(XkbDescPtr xkb, uint ndx, uint format);
char* XkbVModMaskText(XkbDescPtr xkb, uint modMask, uint mask, uint format);
char* XkbConfigText(uint config, uint format);
const(char)* XkbSIMatchText(uint type, uint format);
char* XkbIMWhichStateMaskText(uint use_which, uint format);
char* XkbControlsMaskText(uint ctrls, uint format);
char* XkbGeomFPText(int val, uint format);
char* XkbDoodadTypeText(uint type, uint format);
const(char)* XkbActionTypeText(uint type, uint format);
char* XkbActionText(XkbDescPtr xkb, XkbAction* action, uint format);
char* XkbBehaviorText(XkbDescPtr xkb, XkbBehavior* behavior, uint format);

 /* _XSERVER_XKB_XKBTEXT_PRIV_H */
