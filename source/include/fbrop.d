module include.fbrop;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 1998 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

 
// //public import x11.Xfuncproto;
import fb.fb;
import fb.fbutil;

struct _mergeRopBits {
    FbBits ca1, cx1, ca2, cx2;
}alias FbMergeRopRec = _mergeRopBits;
alias FbMergeRopPtr = _mergeRopBits*;

// FbMergeRopRec[16] FbMergeRopBits;

enum string FbDeclareMergeRop() = `FbBits _ca1 = void, _cx1 = void, _ca2 = void, _cx2 = void;`;
enum string FbDeclarePrebuiltMergeRop() = `FbBits _cca = void, _ccx = void;`;

enum string FbInitializeMergeRop(string alu,string pm) = `{
    const(FbMergeRopRec)* _bits = void; 
    _bits = &FbMergeRopBits[` ~ alu ~ `]; 
    _ca1 = _bits.ca1 &  ` ~ pm ~ `; 
    _cx1 = _bits.cx1 | ~` ~ pm ~ `; 
    _ca2 = _bits.ca2 &  ` ~ pm ~ `; 
    _cx2 = _bits.cx2 &  ` ~ pm ~ `; 
}`;

enum string FbDestInvarientRop(string alu,string pm) = `((` ~ pm ~ `) == FB_ALLONES && 
				     (((` ~ alu ~ `) >> 1 & 5) == ((` ~ alu ~ `) & 5)))`;

enum string FbDestInvarientMergeRop() = `(_ca1 == 0 && _cx1 == 0)`;

/* AND has higher precedence than XOR */

enum string FbDoMergeRop(string src, string dst) = `
    (((` ~ dst ~ `) & (((` ~ src ~ `) & _ca1) ^ _cx1)) ^ (((` ~ src ~ `) & _ca2) ^ _cx2))`;

enum string FbDoDestInvarientMergeRop(string src) = `(((` ~ src ~ `) & _ca2) ^ _cx2)`;

enum string FbDoMaskMergeRop(string src, string dst, string mask) = `
    (((` ~ dst ~ `) & ((((` ~ src ~ `) & _ca1) ^ _cx1) | ~(` ~ mask ~ `))) ^ ((((` ~ src ~ `) & _ca2) ^ _cx2) & (` ~ mask ~ `)))`;

enum string FbDoLeftMaskByteMergeRop(string dst, string src, string lb, string l) = `{ 
    FbBits __xor = ((` ~ src ~ `) & _ca2) ^ _cx2; `~
    FbDoLeftMaskByteRRop!(dst, lb, l, `((` ~ src ~ `) & _ca1) ^ _cx1`,`__xor`) ~`
}`;

enum string FbDoRightMaskByteMergeRop(string dst, string src, string rb, string r) = `{ 
    FbBits __xor = ((` ~ src ~ `) & _ca2) ^ _cx2; `~
    FbDoRightMaskByteRRop!(dst, rb, r, `((` ~ src ~ `) & _ca1) ^ _cx1`,`__xor`) ~` 
}`;

enum string FbDoRRop(string dst, string and, string xor) = `(((` ~ dst ~ `) & (` ~ and ~ `)) ^ (` ~ xor ~ `))`;

enum string FbDoMaskRRop(string dst, string and, string xor, string mask) = `
    (((` ~ dst ~ `) & ((` ~ and ~ `) | ~(` ~ mask ~ `))) ^ (` ~ xor ~ ` & ` ~ mask ~ `))`;

/*
 * Take a single bit (0 or 1) and generate a full mask
 */
enum string fbFillFromBit(string b,string t) = `(~(cast(` ~ t ~ `) ((` ~ b ~ `) & 1)-1))`;

enum string fbXorT(string rop,string fg,string pm,string t) = `((((` ~ fg ~ `) & ` ~ fbFillFromBit!(`(` ~ rop ~ `) >> 1`,t) ~ `) | 
			      (~(` ~ fg ~ `) & ` ~ fbFillFromBit!(`(` ~ rop ~ `) >> 3`,t) ~ `)) & (` ~ pm ~ `))`;

enum string fbAndT(string rop,string fg,string pm,string t) = `((((` ~ fg ~ `) & ` ~ fbFillFromBit! (`` ~ rop ~ ` ^ (` ~ rop ~ `>>1)`,t) ~ `) | 
			      (~(` ~ fg ~ `) & ` ~ fbFillFromBit!(`(` ~ rop ~ `>>2) ^ (` ~ rop ~ `>>3)`,t) ~ `)) | 
			     ~(` ~ pm ~ `))`;

enum string fbXor(string rop,string fg,string pm) = `` ~ fbXorT!(rop,fg,pm,`FbBits`) ~ ``;

enum string fbAnd(string rop,string fg,string pm) = `` ~ fbAndT!(rop,fg,pm,`FbBits`) ~ ``;

enum string fbXorStip(string rop,string fg,string pm) = `` ~ fbXorT!(rop,fg,pm,`FbStip`) ~ ``;

enum string fbAndStip(string rop,string fg,string pm) = `` ~ fbAndT!(rop,fg,pm,`FbStip`) ~ ``;

/*
 * Stippling operations;
 */

enum string FbStippleRRop(string dst, string b, string fa, string fx, string ba, string bx) = `
    (` ~ FbDoRRop!(dst, fa, fx) ~ ` & ` ~ b ~ `) | (` ~ FbDoRRop!(dst, ba, bx) ~ ` & ~` ~ b ~ `)`;

enum string FbStippleRRopMask(string dst, string b, string fa, string fx, string ba, string bx, string m) = `
    (` ~ FbDoMaskRRop!(dst, fa, fx, m) ~ ` & (` ~ b ~ `)) | (` ~ FbDoMaskRRop!(dst, ba, bx, m) ~ ` & ~(` ~ b ~ `))`;

enum string FbDoLeftMaskByteStippleRRop(string dst, string b, string fa, string fx, string ba, string bx, string lb, string l) = `{ 
    FbBits __xor = ((` ~ fx ~ `) & (` ~ b ~ `)) | ((` ~ bx ~ `) & ~(` ~ b ~ `)); `~
    FbDoLeftMaskByteRRop!(dst, lb, l , `((`~fa~`) & (` ~ b ~ `)) | ((` ~ ba ~ `) & ~(` ~ b ~ `))`, `__xor`)~`; 
}`;

enum string FbDoRightMaskByteStippleRRop(string dst, string b, string fa, string fx, string ba, string bx, string rb, string r) = `{ 
    FbBits __xor = ((` ~ fx ~ `) & (` ~ b ~ `)) | ((` ~ bx ~ `) & ~(` ~ b ~ `)); `~
    FbDoRightMaskByteRRop!(dst, rb, r , `((` ~ fa ~ `) & (` ~ b ~ `)) | ((` ~ ba ~ `) & ~(` ~ b ~ `))`, "__xor")~` 
}`;

enum string FbOpaqueStipple(string b, string fg, string bg) = `(((` ~ fg ~ `) & (` ~ b ~ `)) | ((` ~ bg ~ `) & ~(` ~ b ~ `)))`;

/*
 * Compute rop for using tile code for 1-bit dest stipples; modifies
 * existing rop to flip depending on pixel values
 */
enum string FbStipple1RopPick(string alu,string b) = `(((` ~ alu ~ `) >> (2 - (((` ~ b ~ `) & 1) << 1))) & 3)`;

enum string FbOpaqueStipple1Rop(string alu,string fg,string bg) = `(` ~ FbStipple1RopPick!(alu,fg) ~ ` | 
					   (` ~ FbStipple1RopPick!(alu,bg) ~ ` << 2))`;

enum string FbStipple1Rop(string alu,string fg) = `(` ~ FbStipple1RopPick!(alu,fg) ~ ` | 4)`;


