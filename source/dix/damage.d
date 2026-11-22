module dix.damage;
@nogc nothrow:
extern(C): __gshared:

/* 
 * SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright © 2003 Keith Packard
 *
 * See COPYING for the full license texts.
 */
//TODO: the best variant is move this module ti miext/damage.d
import x11.Xmd;
import dix.pixmap;
//FIXME: Do import privatly
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
