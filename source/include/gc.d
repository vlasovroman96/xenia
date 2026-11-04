module include.gc;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

 
//public import x11.X;              /* for GContext, Mask */
//public import x11.Xdefs;          /* for Bool */
//public import x11.Xproto;
public import include.scrintstr;          /* for ScreenPtr */
public import include.pixmap;             /* for DrawablePtr */
import include.gcstruct;

/* clientClipType field in GC */
enum CT_NONE =			0;
enum CT_PIXMAP =		1;
enum CT_REGION =		2;
enum CT_UNSORTED =		6;
enum CT_YSORTED =		10;
enum CT_YXSORTED =		14;
enum CT_YXBANDED =		18;

enum ulong GC_CHANGE_SERIAL_BIT =        1<<31;

enum DRAWABLE_SERIAL_BITS =        (~(GC_CHANGE_SERIAL_BIT));

enum MAX_SERIAL_NUM =     (1L<<28);

@property auto NEXT_SERIAL_NUMBER() { return ((++globalSerialNumber) > MAX_SERIAL_NUM ? 
	    (globalSerialNumber  = 1): globalSerialNumber);
};

struct _GCInterest;
alias GCInterestPtr = _GCInterest*;
alias GCPtr = _GC*;
alias GCOpsPtr = _GCOps*;
alias GCOps = _GCOps;

// void ValidateGC(DrawablePtr, GCPtr);

union _ChangeGCVal {
    CARD32 val;
    void* ptr;
}alias ChangeGCVal = _ChangeGCVal;
alias ChangeGCValPtr = ChangeGCVal*;

// void ChangeGC(ClientPtr, GCPtr, BITS32, ChangeGCValPtr);

// void GetScratchGC(uint, ScreenPtr);

// void FreeScratchGC(GCPtr);

                          /* GC_H */
