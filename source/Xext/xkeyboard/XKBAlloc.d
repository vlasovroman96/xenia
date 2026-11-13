module xkb.XKBAlloc;
@nogc nothrow:
extern(C): __gshared:
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

import build.dix_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
import core.stdc.string;

import xkb.xkbsrv_priv;

import dix.inputstr;
import xkb.xkbgeom_priv;
import os.os;
import xkb.xkbstr;

import xkb.xkbsrv_priv;
import xkb.xkbstr;
// import xkb.xkbstr;
import externs.X11.extensions.XKB;
// import externs.X11.extensions.XKBgeom;
import xkb.XKBGAlloc;


/***===================================================================***/

/*ARGSUSED*/ int XkbAllocCompatMap(XkbDescPtr xkb, uint which, uint nSI)
{
    XkbCompatMapPtr compat = void;
    XkbSymInterpretRec* prev_interpret = void;

    if (!xkb)
        return BadMatch;
    if (xkb.compat) {
        if (xkb.compat.size_si >= nSI)
            return Success;
        compat = xkb.compat;
        compat.size_si = cast(ushort)nSI;
        if (compat.sym_interpret is null)
            compat.num_si = 0;
        prev_interpret = compat.sym_interpret;
        compat.sym_interpret = cast(_XkbSymInterpretRec*)reallocarray(compat.sym_interpret,
                                             nSI, XkbSymInterpretRec.sizeof);
        if (compat.sym_interpret is null) {
            free(prev_interpret);
            compat.size_si = compat.num_si = 0;
            return BadAlloc;
        }
        if (compat.num_si != 0) {
            memset(&compat.sym_interpret[compat.num_si], 0,
                   (compat.size_si -
                    compat.num_si) * XkbSymInterpretRec.sizeof);
        }
        return Success;
    }
    compat = cast(XkbCompatMapRec*) calloc(1, XkbCompatMapRec.sizeof);
    if (compat is null)
        return BadAlloc;
    if (nSI > 0) {
        compat.sym_interpret = cast(_XkbSymInterpretRec*)calloc(nSI, XkbSymInterpretRec.sizeof);
        if (!compat.sym_interpret) {
            free(compat);
            return BadAlloc;
        }
    }
    compat.size_si = cast(ushort)nSI;
    compat.num_si = 0;
    memset(cast(char*) &compat.groups[0], 0,
           XkbNumKbdGroups * XkbModsRec.sizeof);
    xkb.compat = compat;
    return Success;
}

void XkbFreeCompatMap(XkbDescPtr xkb, uint which, Bool freeMap)
{
    XkbCompatMapPtr compat = void;

    if ((xkb is null) || (xkb.compat is null))
        return;
    compat = xkb.compat;
    if (freeMap)
        which = XkbAllCompatMask;
    if (which & XkbGroupCompatMask)
        memset(cast(char*) &compat.groups[0], 0,
               XkbNumKbdGroups * XkbModsRec.sizeof);
    if (which & XkbSymInterpMask) {
        if ((compat.sym_interpret) && (compat.size_si > 0))
            free(compat.sym_interpret);
        compat.size_si = compat.num_si = 0;
        compat.sym_interpret = null;
    }
    if (freeMap) {
        free(compat);
        xkb.compat = null;
    }
    return;
}

/***===================================================================***/

int XkbAllocNames(XkbDescPtr xkb, uint which, int nTotalRG, int nTotalAliases)
{
    XkbNamesPtr names = void;

    if (xkb is null)
        return BadMatch;
    if (xkb.names is null) {
        xkb.names = cast(XkbNamesRec*) calloc(1, XkbNamesRec.sizeof);
        if (xkb.names is null)
            return BadAlloc;
    }
    names = xkb.names;
    if ((which & XkbKTLevelNamesMask) && (xkb.map !is null) &&
        (xkb.map.types !is null)) {
        int i = void;
        XkbKeyTypePtr type = void;

        type = xkb.map.types;
        for (i = 0; i < xkb.map.num_types; i++, type++) {
            if (type.level_names is null) {
                type.level_names = cast(uint*)cast(ulong*)calloc(type.num_levels, Atom.sizeof);
                if (type.level_names is null)
                    return BadAlloc;
            }
        }
    }
    if ((which & XkbKeyNamesMask) && (names.keys is null)) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadValue;
        names.keys = cast(_XkbKeyNameRec*)calloc((xkb.max_key_code + 1), XkbKeyNameRec.sizeof);
        if (names.keys is null)
            return BadAlloc;
    }
    if ((which & XkbKeyAliasesMask) && (nTotalAliases > 0)) {
        if (names.key_aliases is null) {
            names.key_aliases = cast(_XkbKeyAliasRec*)calloc(nTotalAliases, XkbKeyAliasRec.sizeof);
        }
        else if (nTotalAliases > names.num_key_aliases) {
            XkbKeyAliasRec* prev_aliases = names.key_aliases;

            names.key_aliases = cast(_XkbKeyAliasRec*)reallocarray(names.key_aliases,
                                              nTotalAliases,
                                              XkbKeyAliasRec.sizeof);
            if (names.key_aliases !is null) {
                memset(&names.key_aliases[names.num_key_aliases], 0,
                       (nTotalAliases -
                        names.num_key_aliases) * XkbKeyAliasRec.sizeof);
            }
            else {
                free(prev_aliases);
            }
        }
        if (names.key_aliases is null) {
            names.num_key_aliases = cast(ubyte)0;
            return BadAlloc;
        }
        names.num_key_aliases = cast(ubyte)nTotalAliases;
    }
    if ((which & XkbRGNamesMask) && (nTotalRG > 0)) {
        if (names.radio_groups is null) {
            names.radio_groups = cast(uint*)calloc(nTotalRG, Atom.sizeof);
        }
        else if (nTotalRG > names.num_rg) {
            Atom* prev_radio_groups = names.radio_groups;

            names.radio_groups = cast(uint*)reallocarray(names.radio_groups,
                                               nTotalRG, Atom.sizeof);
            if (names.radio_groups !is null) {
                memset(&names.radio_groups[names.num_rg], 0,
                       (nTotalRG - names.num_rg) * Atom.sizeof);
            }
            else {
                free(prev_radio_groups);
            }
        }
        if (names.radio_groups is null) {
            names.num_rg = cast(ushort)0;
            return BadAlloc;
        }
        names.num_rg = cast(ushort)nTotalRG;
    }
    return Success;
}

void XkbFreeNames(XkbDescPtr xkb, uint which, Bool freeMap)
{
    XkbNamesPtr names = void;

    if ((xkb is null) || (xkb.names is null))
        return;
    names = xkb.names;
    if (freeMap)
        which = XkbAllNamesMask;
    if (which & XkbKTLevelNamesMask) {
        XkbClientMapPtr map = xkb.map;

        if ((map !is null) && (map.types !is null)) {
            int i = void;
            XkbKeyTypePtr type = void;

            type = map.types;
            for (i = 0; i < map.num_types; i++, type++) {
                free(type.level_names);
                type.level_names = cast(uint*)null;
            }
        }
    }
    if ((which & XkbKeyNamesMask) && (names.keys !is null)) {
        free(names.keys);
        names.keys = null;
        names.num_keys = 0;
    }
    if ((which & XkbKeyAliasesMask) && (names.key_aliases)) {
        free(names.key_aliases);
        names.key_aliases = null;
        names.num_key_aliases = cast(ubyte)0;
    }
    if ((which & XkbRGNamesMask) && (names.radio_groups)) {
        free(names.radio_groups);
        names.radio_groups = null;
        names.num_rg = cast(ushort)0;
    }
    if (freeMap) {
        free(names);
        xkb.names = null;
    }
    return;
}

/***===================================================================***/

 /*ARGSUSED*/ int XkbAllocControls(XkbDescPtr xkb, uint which)
{
    if (xkb is null)
        return BadMatch;

    if (xkb.ctrls is null) {
        xkb.ctrls = cast(XkbControlsRec*) calloc(1, XkbControlsRec.sizeof);
        if (!xkb.ctrls)
            return BadAlloc;
    }
    return Success;
}

 /*ARGSUSED*/ private void XkbFreeControls(XkbDescPtr xkb, uint which, Bool freeMap)
{
    if (freeMap && (xkb !is null) && (xkb.ctrls !is null)) {
        free(xkb.ctrls);
        xkb.ctrls = null;
    }
    return;
}

/***===================================================================***/

int XkbAllocIndicatorMaps(XkbDescPtr xkb)
{
    if (xkb is null)
        return BadMatch;
    if (xkb.indicators is null) {
        xkb.indicators = cast(XkbIndicatorRec*) calloc(1, XkbIndicatorRec.sizeof);
        if (!xkb.indicators)
            return BadAlloc;
    }
    return Success;
}

private void XkbFreeIndicatorMaps(XkbDescPtr xkb)
{
    if ((xkb !is null) && (xkb.indicators !is null)) {
        free(xkb.indicators);
        xkb.indicators = null;
    }
    return;
}

/***====================================================================***/

XkbDescRec* XkbAllocKeyboard()
{
    XkbDescRec* xkb = void;

    xkb = cast(XkbDescRec*) cast(XkbDescRec*) calloc(1, XkbDescRec.sizeof);
    if (xkb)
        xkb.device_spec = XkbUseCoreKbd;
    return xkb;
}

void XkbFreeKeyboard(XkbDescPtr xkb, uint which, Bool freeAll)
{
    if (xkb is null)
        return;
    if (freeAll)
        which = XkbAllComponentsMask;
    if (which & XkbClientMapMask)
        XkbFreeClientMap(xkb, XkbAllClientInfoMask, TRUE);
    if (which & XkbServerMapMask)
        XkbFreeServerMap(xkb, XkbAllServerInfoMask, TRUE);
    if (which & XkbCompatMapMask)
        XkbFreeCompatMap(xkb, XkbAllCompatMask, TRUE);
    if (which & XkbIndicatorMapMask)
        XkbFreeIndicatorMaps(xkb);
    if (which & XkbNamesMask)
        XkbFreeNames(xkb, XkbAllNamesMask, TRUE);
    if ((which & XkbGeometryMask) && (xkb.geom !is null)) {
        XkbFreeGeometry(xkb.geom, XkbGeomAllMask, TRUE);
        /* PERHAPS BONGHITS etc */
        xkb.geom = null;
    }
    if (which & XkbControlsMask)
        XkbFreeControls(xkb, XkbAllControlsMask, TRUE);
    if (freeAll)
        free(xkb);
    return;
}

/***====================================================================***/

void XkbFreeComponentNames(XkbComponentNamesPtr names, Bool freeNames)
{
    if (names) {
        free(names.keycodes);
        free(names.types);
        free(names.compat);
        free(names.symbols);
        free(names.geometry);
        memset(names, 0, XkbComponentNamesRec.sizeof);
    }
    if (freeNames)
        free(names);
}
