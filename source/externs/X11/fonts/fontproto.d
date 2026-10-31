module externs.X11.fonts.fontproto;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright (c) 1999  The XFree86 Project Inc.

All Rights Reserved.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The XFree86 Project
Inc. shall not be used in advertising or otherwise to promote the
sale, use or other dealings in this Software without prior written
authorization from The XFree86 Project Inc..

*/
 
public import externs.X11.fonts.fontstruct;
/* Externally provided functions required by libXfont */
import dix.dixstruct_priv;
import x11.Xos;
// extern struct _Client;
alias ClientPtr = _Client*;

extern void RegisterFPEFunctions(NameCheckFunc name_func, InitFpeFunc init_func, FreeFpeFunc free_func, ResetFpeFunc reset_func, OpenFontFunc open_func, CloseFontFunc close_func, ListFontsFunc list_func, StartLfwiFunc start_lfwi_func, NextLfwiFunc next_lfwi_func, WakeupFpeFunc wakeup_func, ClientDiedFunc client_died, LoadGlyphsFunc load_glyphs, StartLaFunc start_list_alias_func, NextLaFunc next_list_alias_func, SetPathFunc set_path_func);

extern void GetDefaultPointSize();

extern void init_fs_handlers(FontPathElementPtr fpe, BlockHandlerProcPtr block_handler);
extern void remove_fs_handlers(FontPathElementPtr fpe, BlockHandlerProcPtr block_handler, Bool all);

extern void client_auth_generation(ClientPtr client);

 
extern Bool ClientSignal(ClientPtr client);
 /* ___CLIENTSIGNAL_DEFINED___ */

extern void DeleteFontClientID(Font id);
extern void GetNewFontClientID();
extern void StoreFontClientFont(FontPtr pfont, Font id);
extern void FontFileRegisterFpeFunctions();
extern void FontFileCheckRegisterFpeFunctions();

extern Bool XpClientIsBitmapClient(ClientPtr client);
extern Bool XpClientIsPrintClient(ClientPtr client, FontPathElementPtr fpe);
extern void PrinterFontRegisterFpeFunctions();

extern void fs_register_fpe_functions();
extern void check_fs_register_fpe_functions();

/* util/private.c */
extern FontPtr CreateFontRec();
extern void DestroyFontRec(FontPtr font);
extern Bool _FontSetNewPrivate(FontPtr, int, void*);
extern int AllocateFontPrivateIndex();
extern void ResetFontPrivateIndex();

/* Type1/t1funcs.c */
extern void Type1RegisterFontFileFunctions();
extern void CIDRegisterFontFileFunctions();

/* Speedo/spfuncs.c */
extern void SpeedoRegisterFontFileFunctions();

/* FreeType/ftfuncs.c */
extern void FreeTypeRegisterFontFileFunctions();


