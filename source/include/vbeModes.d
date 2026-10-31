module include.vbeModes;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2002 David Dawes
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
 * THE AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the author(s) shall
 * not be used in advertising or otherwise to promote the sale, use or other
 * dealings in this Software without prior written authorization from
 * the author(s).
 *
 * Authors: David Dawes <dawes@xfree86.org>
 *
 */
 
//public import x11.Xdefs;
// //public import x11.Xfuncproto;
import include.vbe;
import hw.xfree86.modes.displaymode;
/*
 * This is intended to be stored in the DisplayModeRec's private area.
 * It includes all the information necessary to VBE information.
 */
struct VbeModeInfoData {
    int mode;
    VbeModeInfoBlock* data;
    VbeCRTCInfoBlock* block;
}

enum V_DEPTH_1 =	0x001;
enum V_DEPTH_4 =	0x002;
enum V_DEPTH_8 =	0x004;
enum V_DEPTH_15 =	0x008;
enum V_DEPTH_16 =	0x010;
enum V_DEPTH_24_24 =	0x020;
enum V_DEPTH_24_32 =	0x040;
enum V_DEPTH_24 =	(V_DEPTH_24_24 | V_DEPTH_24_32);
enum V_DEPTH_30 =	0x080;
enum V_DEPTH_32 =	0x100;

enum string VBE_MODE_SUPPORTED(string m) = `(((` ~ m ~ `).ModeAttributes & 0x01) != 0)`;
enum string VBE_MODE_COLOR(string m) = `(((` ~ m ~ `).ModeAttributes & 0x08) != 0)`;
enum string VBE_MODE_GRAPHICS(string m) = `(((` ~ m ~ `).ModeAttributes & 0x10) != 0)`;
enum string VBE_MODE_VGA(string m) = `(((` ~ m ~ `).ModeAttributes & 0x40) == 0)`;
enum string VBE_MODE_LINEAR(string m) = `(((` ~ m ~ `).ModeAttributes & 0x80) != 0 && 
				 ((` ~ m ~ `).PhysBasePtr != 0))`;

enum string VBE_MODE_USABLE(string m, string f) = `(` ~ VBE_MODE_SUPPORTED!(m) ~ ` || 
				 (` ~ f ~ ` & V_MODETYPE_BAD)) && 
				` ~ VBE_MODE_GRAPHICS!(m) ~ ` && 
				(` ~ VBE_MODE_VGA!(m) ~ ` || ` ~ VBE_MODE_LINEAR!(m) ~ `)`;

enum V_MODETYPE_VBE =		0x01;
enum V_MODETYPE_VGA =		0x02;
enum V_MODETYPE_BAD =		0x04;

void  VBEFindSupportedDepths(vbeInfoPtr pVbe, VbeInfoBlock* vbe, int* flags24, int modeTypes);
void  VBEGetModePool(ScrnInfoPtr pScrn, vbeInfoPtr pVbe, VbeInfoBlock* vbe, int modeTypes);
void  VBESetModeNames(DisplayModePtr pMode);
void  VBESetModeParameters(ScrnInfoPtr pScrn, vbeInfoPtr pVbe);

/*
 * Note: These are alternatives to the standard helpers.  They should
 * usually just wrap the standard helpers.
 */
void  VBEValidateModes(ScrnInfoPtr scrp, DisplayModePtr availModes, const(char)** modeNames, ClockRangePtr clockRanges, int* linePitches, int minPitch, int maxPitch, int pitchInc, int minHeight, int maxHeight, int virtualX, int virtualY, int apertureSize, LookupModeFlags strategy);
void  VBEPrintModes(ScrnInfoPtr scrp);

                          /* VBE_MODES_H */
