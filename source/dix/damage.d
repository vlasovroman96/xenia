module dix.damage;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2003 Keith Packard
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
 
public import dix.gc;
public import dix.privates;
public import dix.picturestr;
import dix.pixmap;
import region;
import dix.scrintstr;
public import miext.damage.damage_;

enum DamageReportLevel : ubyte {
    RawRegion,
    DeltaRegion,
    BoundingBox,
    NonEmpty,
    None
}

alias DamageReportFunc = void function(DamagePtr pDamage, RegionPtr pRegion, void* closure);
alias DamageDestroyFunc = void function(DamagePtr pDamage, void* closure);

struct DamageRec {
    DamagePtr pNext;
    DamagePtr pNextWin;
    RegionRec damage;

    DamageReportLevel damageLevel;
    Bool isInternal;
    void* closure;
    Bool isWindow;
    DrawablePtr pDrawable;

    DamageReportFunc damageReport;
    DamageDestroyFunc damageDestroy;

    Bool reportAfter;
    RegionRec pendingDamage;    /* will be flushed post submission at the latest */
    ScreenPtr pScreen;
}
alias DamagePtr = DamageRec*;
