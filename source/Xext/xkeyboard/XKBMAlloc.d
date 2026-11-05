module xkb.XKBMAlloc;
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
//import x11.keysym;

import os.log_priv;
import xkb.xkbsrv_priv;

import common.misc;
import dix.inputstr;
import xkb.xkbstr;
import externs.X11.extensions.XKB;

// import externs.X11.extensions.XKB;
enum XkbNumRequiredTypes = 4;
// enum XkbLastRequiredType = 3;
/***====================================================================***/

int XkbAllocClientMap(XkbDescPtr xkb, uint which, uint nTotalTypes)
{
    XkbClientMapPtr map = void;

    if ((xkb is null) ||
        ((nTotalTypes > 0) && (nTotalTypes < XkbNumRequiredTypes)))
        return BadValue;
    if ((which & XkbKeySymsMask) &&
        ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
         (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
         (xkb.max_key_code < xkb.min_key_code))) {
        DebugF("bad keycode (%d,%d) in XkbAllocClientMap\n",
               xkb.min_key_code, xkb.max_key_code);
        return BadValue;
    }

    if (xkb.map is null) {
        map = cast(XkbClientMapRec*) calloc(1, XkbClientMapRec.sizeof);
        if (map is null)
            return BadAlloc;
        xkb.map = map;
    }
    else
        map = xkb.map;

    if ((which & XkbKeyTypesMask) && (nTotalTypes > 0)) {
        if (map.types is null) {
            map.types = cast(_XkbKeyType*)calloc(nTotalTypes, XkbKeyTypeRec.sizeof);
            if (map.types is null)
                return BadAlloc;
            map.num_types = 0;
            map.size_types = cast(ubyte)nTotalTypes;
        }
        else if (map.size_types < nTotalTypes) {
            XkbKeyTypeRec* prev_types = map.types;

            map.types =
                cast(XkbKeyTypeRec*) reallocarray(map.types, nTotalTypes, XkbKeyTypeRec.sizeof);
            if (map.types is null) {
                free(prev_types);
                map.num_types = map.size_types = cast(ubyte)0;
                return BadAlloc;
            }
            map.size_types = cast(ubyte)nTotalTypes;
            memset(&map.types[map.num_types], 0,
                   ((map.size_types -
                     map.num_types) * XkbKeyTypeRec.sizeof));
        }
    }
    if (which & XkbKeySymsMask) {
        int nKeys = mixin(XkbNumKeys!("xkb"));

        if (map.syms is null) {
            map.size_syms = cast(ushort)((nKeys * 15) / 10);
            map.syms = cast(uint*)calloc(map.size_syms, KeySym.sizeof);
            if (!map.syms) {
                map.size_syms = 0;
                return BadAlloc;
            }
            map.num_syms = 1;
            map.syms[0] = NoSymbol;
        }
        if (map.key_sym_map is null) {
            map.key_sym_map = cast(_XkbSymMapRec*)calloc(MAP_LENGTH, XkbSymMapRec.sizeof);
            if (map.key_sym_map is null)
                return BadAlloc;
        }
    }
    if (which & XkbModifierMapMask) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadMatch;
        if (map.modmap is null) {
            map.modmap = cast(ubyte*)calloc(MAP_LENGTH, ubyte.sizeof);
            if (map.modmap is null)
                return BadAlloc;
        }
    }
    return Success;
}

int XkbAllocServerMap(XkbDescPtr xkb, uint which, uint nNewActions)
{
    int i = void;
    XkbServerMapPtr map = void;

    if (xkb is null)
        return BadMatch;
    if (xkb.server is null) {
        map = cast(XkbServerMapRec*) calloc(1, XkbServerMapRec.sizeof);
        if (map is null)
            return BadAlloc;
        for (i = 0; i < XkbNumVirtualMods; i++) {
            map.vmods[i] = XkbNoModifierMask;
        }
        xkb.server = map;
    }
    else
        map = xkb.server;
    if (which & XkbExplicitComponentsMask) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadMatch;
        if (map.explicit is null) {
            map.explicit =  cast(ubyte*)calloc(MAP_LENGTH, ubyte.sizeof);
            if (map.explicit is null)
                return BadAlloc;
        }
    }
    if (which & XkbKeyActionsMask) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadMatch;
        if (nNewActions < 1)
            nNewActions = 1;
        if (map.acts is null) {
            map.acts = cast(_XkbAction*)calloc((nNewActions + 1), XkbAction.sizeof);
            if (map.acts is null)
                return BadAlloc;
            map.num_acts = 1;
            map.size_acts = cast(ushort)cast(ushort)(nNewActions + 1);
        }
        else if ((map.size_acts - map.num_acts) < nNewActions) {
            uint need = void;
            XkbAction* prev_acts = map.acts;

            need = map.num_acts + nNewActions;
            map.acts = cast(XkbAction*) reallocarray(map.acts, need, XkbAction.sizeof);
            if (map.acts is null) {
                free(prev_acts);
                map.num_acts = map.size_acts = cast(ushort)0;
                return BadAlloc;
            }
            map.size_acts = cast(ushort)need;
            memset(&map.acts[map.num_acts], 0,
                   ((map.size_acts - map.num_acts) * XkbAction.sizeof));
        }
        if (map.key_acts is null) {
            map.key_acts = cast(ushort*)calloc(MAP_LENGTH, ushort.sizeof);
            if (map.key_acts is null)
                return BadAlloc;
        }
    }
    if (which & XkbKeyBehaviorsMask) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadMatch;
        if (map.behaviors is null) {
            map.behaviors =  cast(_XkbBehavior*)calloc(MAP_LENGTH, XkbBehavior.sizeof);
            if (map.behaviors is null)
                return BadAlloc;
        }
    }
    if (which & XkbVirtualModMapMask) {
        if ((!mixin(XkbIsLegalKeycode!("xkb.min_key_code"))) ||
            (!mixin(XkbIsLegalKeycode!("xkb.max_key_code"))) ||
            (xkb.max_key_code < xkb.min_key_code))
            return BadMatch;
        if (map.vmodmap is null) {
            map.vmodmap =  cast(ushort*)calloc(MAP_LENGTH, ushort.sizeof);
            if (map.vmodmap is null)
                return BadAlloc;
        }
    }
    return Success;
}

/***====================================================================***/

private Status XkbCopyKeyType(XkbKeyTypePtr from, XkbKeyTypePtr into)
{
    if ((!from) || (!into))
        return BadMatch;
    free(into.map);
    into.map =   cast(_XkbKTMapEntry*)null;
    free(into.preserve);
    into.preserve =   cast(_XkbMods*)null;
    free(into.level_names);
    into.level_names =   cast(uint*)null;
    *into = *from;
    if ((from.map) && (into.map_count > 0)) {
        into.map =   cast(_XkbKTMapEntry*)calloc(into.map_count, XkbKTMapEntryRec.sizeof);
        if (!into.map)
            return BadAlloc;
        memcpy(into.map, from.map,
               into.map_count * XkbKTMapEntryRec.sizeof);
    }
    if ((from.preserve) && (into.map_count > 0)) {
        into.preserve =   cast(_XkbMods*)calloc(into.map_count, XkbModsRec.sizeof);
        if (!into.preserve)
            return BadAlloc;
        memcpy(into.preserve, from.preserve,
               into.map_count * XkbModsRec.sizeof);
    }
    if ((from.level_names) && (into.num_levels > 0)) {
        into.level_names =   cast(uint*)calloc(into.num_levels, Atom.sizeof);
        if (!into.level_names)
            return BadAlloc;
        memcpy(into.level_names, from.level_names,
               into.num_levels * Atom.sizeof);
    }
    return Success;
}

int XkbCopyKeyTypes(XkbKeyTypePtr from, XkbKeyTypePtr into, int num_types)
{
    int i = void, rtrn = void;

    if ((!from) || (!into) || (num_types < 0))
        return BadMatch;
    for (i = 0; i < num_types; i++) {
        if ((rtrn = XkbCopyKeyType(from++, into++)) != Success)
            return rtrn;
    }
    return Success;
}

int XkbResizeKeyType(XkbDescPtr xkb, int type_ndx, int map_count, Bool want_preserve, int new_num_lvls)
{
    XkbKeyTypePtr type = void;
    KeyCode[XkbMaxKeyCount] matchingKeys = void; KeyCode nMatchingKeys = void;

    if ((type_ndx < 0) || (type_ndx >= xkb.map.num_types) || (map_count < 0)
        || (new_num_lvls < 1))
        return BadValue;
    switch (type_ndx) {
    case XkbOneLevelIndex:
        if (new_num_lvls != 1)
            return BadMatch;
        break;
    case XkbTwoLevelIndex:
    case XkbAlphabeticIndex:
    case XkbKeypadIndex:
        if (new_num_lvls != 2)
            return BadMatch;
        break;
    default: break;}
    type = &xkb.map.types[type_ndx];
    if (map_count == 0) {
        free(type.map);
        type.map = null;
        free(type.preserve);
        type.preserve = cast(_XkbMods*)null;
        type.map_count = cast(ubyte)cast(ubyte*)0;
    }
    else {
        XkbKTMapEntryRec* prev_map = type.map;

        if ((map_count > type.map_count) || (type.map is null))
            type.map =
                cast(XkbKTMapEntryRec*) reallocarray(type.map, map_count, XkbKTMapEntryRec.sizeof);
        if (!type.map) {
            free(prev_map);
            return BadAlloc;
        }
        if (want_preserve) {
            XkbModsRec* prev_preserve = type.preserve;

            if ((map_count > type.map_count) || (type.preserve is null)) {
                type.preserve = cast(_XkbMods*)reallocarray(type.preserve,
                                              map_count, XkbModsRec.sizeof);
            }
            if (!type.preserve) {
                free(prev_preserve);
                return BadAlloc;
            }
        }
        else {
            free(type.preserve);
            type.preserve = cast(_XkbMods*)null;
        }
        type.map_count = cast(ubyte)cast(ubyte*)map_count;
    }

    if ((new_num_lvls > type.num_levels) || (type.level_names is null)) {
        Atom* prev_level_names = type.level_names;

        type.level_names = cast(uint*)reallocarray(type.level_names,
                                         new_num_lvls, Atom.sizeof);
        if (!type.level_names) {
            free(prev_level_names);
            return BadAlloc;
        }
    }
    /*
     * Here's the theory:
     *    If the width of the type changed, we might have to resize the symbol
     * maps for any keys that use the type for one or more groups.  This is
     * expensive, so we'll try to cull out any keys that are obviously okay:
     * In any case:
     *    - keys that have a group width <= the old width are okay (because
     *      they could not possibly have been associated with the old type)
     * If the key type increased in size:
     *    - keys that already have a group width >= to the new width are okay
     *    + keys that have a group width >= the old width but < the new width
     *      might have to be enlarged.
     * If the key type decreased in size:
     *    - keys that have a group width > the old width don't have to be
     *      resized (because they must have some other wider type associated
     *      with some group).
     *    + keys that have a group width == the old width might have to be
     *      shrunk.
     * The possibilities marked with '+' require us to examine the key types
     * associated with each group for the key.
     */
    memset(matchingKeys.ptr, 0, XkbMaxKeyCount * KeyCode.sizeof);
    nMatchingKeys = 0;
    if (new_num_lvls > type.num_levels) {
        int nTotal = void;
        KeySym* newSyms = void;
        int width = void, match = void, nResize = void;
        int i = void, g = void, nSyms = void;

        nResize = 0;
        for (nTotal = 1, i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
            width = mixin(XkbKeyGroupsWidth!("xkb", "i"));
            if (width < type.num_levels || width >= new_num_lvls) {
                nTotal += mixin(XkbKeyNumSyms!("xkb","i"));
                continue;
            }
            for (match = 0, g = mixin(XkbKeyNumGroups!("xkb", "i")) - 1;
                 (g >= 0) && (!match); g--) {
                if (mixin(XkbKeyKeyTypeIndex!("xkb", "i", "g")) == type_ndx) {
                    matchingKeys[nMatchingKeys++] = cast(ubyte)i;
                    match = 1;
                }
            }
            if (!match)
                nTotal += mixin(XkbKeyNumSyms!("xkb", "i"));
            else {
                nTotal += mixin(XkbKeyNumGroups!("xkb", "i")) * new_num_lvls;
                nResize++;
            }
        }
        if (nResize > 0) {
            int nextMatch = void;

            xkb.map.size_syms = cast(short)((nTotal * 15) / 10);
            newSyms = cast(KeySym*) calloc(xkb.map.size_syms, KeySym.sizeof);
            if (newSyms is null)
                return BadAlloc;
            nextMatch = 0;
            nSyms = 1;
            for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
                if (matchingKeys[nextMatch] == i) {
                    KeySym* pOld = void;

                    nextMatch++;
                    width = mixin(XkbKeyGroupsWidth!("xkb", "i"));
                    pOld = mixin(XkbKeySymsPtr!("xkb", "i"));
                    for (g = mixin(XkbKeyNumGroups!("xkb", "i")) - 1; g >= 0; g--) {
                        memcpy(&newSyms[nSyms + (new_num_lvls * g)],
                               &pOld[width * g], width * KeySym.sizeof);
                    }
                    xkb.map.key_sym_map[i].offset = cast(ushort)nSyms;
                    nSyms += mixin(XkbKeyNumGroups!("xkb", "i")) * new_num_lvls;
                }
                else {
                    memcpy(&newSyms[nSyms], mixin(XkbKeySymsPtr!("xkb", "i")),
                           mixin(XkbKeyNumSyms!("xkb", "i")) * KeySym.sizeof);
                    xkb.map.key_sym_map[i].offset = cast(ushort)nSyms;
                    nSyms += mixin(XkbKeyNumSyms!("xkb", "i"));
                }
            }
            type.num_levels = cast(ubyte)new_num_lvls;
            free(xkb.map.syms);
            xkb.map.syms = cast(uint*)newSyms;
            xkb.map.num_syms = cast(ushort)nSyms;
            return Success;
        }
    }
    else if (new_num_lvls < type.num_levels) {
        int width = void, match = void;
        int g = void, i = void;

        for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
            width = mixin(XkbKeyGroupsWidth!("xkb", "i"));
            if (width < type.num_levels)
                continue;
            for (match = 0, g = mixin(XkbKeyNumGroups!("xkb", "i")) - 1;
                 (g >= 0) && (!match); g--) {
                if (mixin(XkbKeyKeyTypeIndex!("xkb", "i", "g")) == type_ndx) {
                    matchingKeys[nMatchingKeys++] = cast(ubyte)i;
                    match = 1;
                }
            }
        }
    }
    if (nMatchingKeys > 0) {
        int key = void, firstClear = void;
        int i = void, g = void;

        if (new_num_lvls > type.num_levels)
            firstClear = type.num_levels;
        else
            firstClear = new_num_lvls;
        for (i = 0; i < nMatchingKeys; i++) {
            KeySym* pSyms = void;
            int width = void, nClear = void;

            key = matchingKeys[i];
            width = mixin(XkbKeyGroupsWidth!("xkb", "key"));
            nClear = width - firstClear;
            pSyms = mixin(XkbKeySymsPtr!("xkb", "key"));
            for (g = mixin(XkbKeyNumGroups!("xkb", "key")) - 1; g >= 0; g--) {
                if (mixin(XkbKeyKeyTypeIndex!("xkb", "key", "g")) == type_ndx) {
                    if (nClear > 0)
                        memset(&pSyms[g * width + firstClear], 0,
                               nClear * KeySym.sizeof);
                }
            }
        }
    }
    type.num_levels = cast(ubyte)new_num_lvls;
    return Success;
}

KeySym* XkbResizeKeySyms(XkbDescPtr xkb, int key, int needed)
{
    int i = void, nSyms = void, nKeySyms = void;
    uint nOldSyms = void;
    KeySym* newSyms = void;

    if (needed == 0) {
        xkb.map.key_sym_map[key].offset = 0;
        return xkb.map.syms;
    }
    nOldSyms = mixin(XkbKeyNumSyms!("xkb", "key"));
    if (nOldSyms >= cast(uint) needed) {
        return mixin(XkbKeySymsPtr!("xkb", "key"));
    }
    if (xkb.map.size_syms - xkb.map.num_syms >= cast(uint) needed) {
        if (nOldSyms > 0) {
            memcpy(&xkb.map.syms[xkb.map.num_syms], mixin(XkbKeySymsPtr!("xkb", "key")),
                   nOldSyms * KeySym.sizeof);
        }
        if ((needed - nOldSyms) > 0) {
            memset(&xkb.map.
                   syms[xkb.map.num_syms + mixin(XkbKeyNumSyms!("xkb", "key"))], 0,
                   (needed - nOldSyms) * KeySym.sizeof);
        }
        xkb.map.key_sym_map[key].offset = xkb.map.num_syms;
        xkb.map.num_syms += needed;
        return &xkb.map.syms[xkb.map.key_sym_map[key].offset];
    }
    xkb.map.size_syms += (needed > 32 ? needed : 32);
    newSyms = cast(KeySym*) calloc(xkb.map.size_syms, KeySym.sizeof);
    if (newSyms is null)
        return null;
    newSyms[0] = NoSymbol;
    nSyms = 1;
    for (i = xkb.min_key_code; i <= cast(int) xkb.max_key_code; i++) {
        int nCopy = void;

        nCopy = nKeySyms = mixin(XkbKeyNumSyms!("xkb", "i"));
        if ((nKeySyms == 0) && (i != key))
            continue;
        if (i == key)
            nKeySyms = needed;
        if (nCopy != 0)
            memcpy(&newSyms[nSyms], mixin(XkbKeySymsPtr!("xkb", "i")),
                   nCopy * KeySym.sizeof);
        if (nKeySyms > nCopy)
            memset(&newSyms[nSyms + nCopy], 0,
                   (nKeySyms - nCopy) * KeySym.sizeof);
        xkb.map.key_sym_map[i].offset = cast(ushort)nSyms;
        nSyms += nKeySyms;
    }
    free(xkb.map.syms);
    xkb.map.syms = cast(uint*)newSyms;
    xkb.map.num_syms = cast(ushort)nSyms;
    return &xkb.map.syms[xkb.map.key_sym_map[key].offset];
}

private uint _ExtendRange(uint old_flags, uint flag, KeyCode newKC, KeyCode* old_min, ubyte* old_num)
{
    if ((old_flags & flag) == 0) {
        old_flags |= flag;
        *old_min = newKC;
        *old_num = 1;
    }
    else {
        int last = (*old_min) + (*old_num) - 1;

        if (newKC < *old_min) {
            *old_min = newKC;
            *old_num = cast(ubyte)((last - newKC) + 1);
        }
        else if (newKC > last) {
            *old_num = cast(ubyte)((newKC - (*old_min)) + 1);
        }
    }
    return old_flags;
}

int XkbChangeKeycodeRange(XkbDescPtr xkb, int minKC, int maxKC, XkbChangesPtr changes)
{
    int tmp = void;

    if ((!xkb) || (minKC < XkbMinLegalKeyCode) || (maxKC > XkbMaxLegalKeyCode))
        return BadValue;
    if (minKC > maxKC)
        return BadMatch;
    if (minKC < xkb.min_key_code) {
        if (changes)
            changes.map.min_key_code = cast(ubyte)minKC;
        tmp = xkb.min_key_code - minKC;
        if (xkb.map) {
            if (xkb.map.key_sym_map) {
                memset(cast(char*) &xkb.map.key_sym_map[minKC], 0,
                       tmp * XkbSymMapRec.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeySymsMask, cast(ubyte)minKC,
                                                        &changes.map.
                                                        first_key_sym,
                                                        &changes.map.
                                                        num_key_syms);
                }
            }
            if (xkb.map.modmap) {
                memset(cast(char*) &xkb.map.modmap[minKC], 0, tmp);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbModifierMapMask,
                                                        cast(ubyte)minKC,
                                                        &changes.map.
                                                        first_modmap_key,
                                                        &changes.map.
                                                        num_modmap_keys);
                }
            }
        }
        if (xkb.server) {
            if (xkb.server.behaviors) {
                memset(cast(char*) &xkb.server.behaviors[minKC], 0,
                       tmp * XkbBehavior.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeyBehaviorsMask,
                                                        cast(ubyte)minKC,
                                                        &changes.map.
                                                        first_key_behavior,
                                                        &changes.map.
                                                        num_key_behaviors);
                }
            }
            if (xkb.server.key_acts) {
                memset(cast(char*) &xkb.server.key_acts[minKC], 0,
                       tmp * ushort.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeyActionsMask,
                                                        cast(ubyte)minKC,
                                                        &changes.map.
                                                        first_key_act,
                                                        &changes.map.
                                                        num_key_acts);
                }
            }
            if (xkb.server.vmodmap) {
                memset(cast(char*) &xkb.server.vmodmap[minKC], 0,
                       tmp * ushort.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbVirtualModMapMask,
                                                        cast(ubyte)minKC,
                                                        &changes.map.
                                                        first_modmap_key,
                                                        &changes.map.
                                                        num_vmodmap_keys);
                }
            }
        }
        if ((xkb.names) && (xkb.names.keys)) {
            memset(cast(char*) &xkb.names.keys[minKC], 0,
                   tmp * XkbKeyNameRec.sizeof);
            if (changes) {
                changes.names.changed = cast(ushort)_ExtendRange(changes.names.changed,
                                                      XkbKeyNamesMask, cast(ubyte)minKC,
                                                      &changes.names.first_key,
                                                      &changes.names.num_keys);
            }
        }
        xkb.min_key_code = cast(ubyte)minKC;
    }
    if (maxKC > xkb.max_key_code) {
        if (changes)
            changes.map.max_key_code = cast(ubyte)maxKC;
        tmp = MAP_LENGTH - xkb.max_key_code;
        if (xkb.map) {
            if (xkb.map.key_sym_map) {
                memset(cast(char*) &xkb.map.key_sym_map[xkb.max_key_code], 0,
                       tmp * XkbSymMapRec.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeySymsMask, cast(ubyte)maxKC,
                                                        &changes.map.
                                                        first_key_sym,
                                                        &changes.map.
                                                        num_key_syms);
                }
            }
            if (xkb.map.modmap) {
                memset(cast(char*) &xkb.map.modmap[xkb.max_key_code], 0, tmp);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbModifierMapMask,
                                                        cast(ubyte)maxKC,
                                                        &changes.map.
                                                        first_modmap_key,
                                                        &changes.map.
                                                        num_modmap_keys);
                }
            }
        }
        if (xkb.server) {
            if (xkb.server.behaviors) {
                memset(cast(char*) &xkb.server.behaviors[xkb.max_key_code], 0,
                       tmp * XkbBehavior.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeyBehaviorsMask,
                                                        cast(ubyte)maxKC,
                                                        &changes.map.
                                                        first_key_behavior,
                                                        &changes.map.
                                                        num_key_behaviors);
                }
            }
            if (xkb.server.key_acts) {
                memset(cast(char*) &xkb.server.key_acts[xkb.max_key_code], 0,
                       tmp * ushort.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbKeyActionsMask,
                                                        cast(ubyte)maxKC,
                                                        &changes.map.
                                                        first_key_act,
                                                        &changes.map.
                                                        num_key_acts);
                }
            }
            if (xkb.server.vmodmap) {
                memset(cast(char*) &xkb.server.vmodmap[xkb.max_key_code], 0,
                       tmp * ushort.sizeof);
                if (changes) {
                    changes.map.changed = cast(ushort)_ExtendRange(changes.map.changed,
                                                        XkbVirtualModMapMask,
                                                        cast(ubyte)maxKC,
                                                        &changes.map.
                                                        first_modmap_key,
                                                        &changes.map.
                                                        num_vmodmap_keys);
                }
            }
        }
        if ((xkb.names) && (xkb.names.keys)) {
            memset(cast(char*) &xkb.names.keys[xkb.max_key_code], 0,
                   tmp * XkbKeyNameRec.sizeof);
            if (changes) {
                changes.names.changed = cast(ushort)_ExtendRange(changes.names.changed,
                                                      XkbKeyNamesMask, cast(ubyte)maxKC,
                                                      &changes.names.first_key,
                                                      &changes.names.num_keys);
            }
        }
        xkb.max_key_code = cast(ubyte)maxKC;
    }
    return Success;
}

XkbAction* XkbResizeKeyActions(XkbDescPtr xkb, int key, int needed)
{
    int i = void, nActs = void;
    XkbAction* newActs = void;

    if (needed <= 0) {
        xkb.server.key_acts[key] = 0;
        return null;
    }
    if (mixin(XkbKeyHasActions!("xkb", "key")) &&
        (mixin(XkbKeyNumSyms!("xkb", "key")) >= cast(uint) needed))
        return mixin(XkbKeyActionsPtr!("xkb", "key"));
    if (xkb.server.size_acts - xkb.server.num_acts >= cast(uint) needed) {
        xkb.server.key_acts[key] = xkb.server.num_acts;
        xkb.server.num_acts += needed;
        return &xkb.server.acts[xkb.server.key_acts[key]];
    }
    xkb.server.size_acts = cast(ushort)(xkb.server.num_acts + needed + 8);
    newActs = cast(XkbAction*) calloc(xkb.server.size_acts, XkbAction.sizeof);
    if (newActs is null)
        return null;
    newActs[0].type = XkbSA_NoAction;
    nActs = 1;
    for (i = xkb.min_key_code; i <= cast(int) xkb.max_key_code; i++) {
        int nKeyActs = void, nCopy = void;

        if ((xkb.server.key_acts[i] == 0) && (i != key))
            continue;

        nCopy = nKeyActs = mixin(XkbKeyNumActions!("xkb", "i"));
        if (i == key) {
            nKeyActs = needed;
            if (needed < nCopy)
                nCopy = needed;
        }

        if (nCopy > 0)
            memcpy(&newActs[nActs], mixin(XkbKeyActionsPtr!("xkb", "i")),
                   nCopy * XkbAction.sizeof);
        if (nCopy < nKeyActs)
            memset(&newActs[nActs + nCopy], 0,
                   (nKeyActs - nCopy) * XkbAction.sizeof);
        xkb.server.key_acts[i] =cast(ushort) nActs;
        nActs += nKeyActs;
    }
    free(xkb.server.acts);
    xkb.server.acts = newActs;
    xkb.server.num_acts = cast(ushort)nActs;
    return &newActs[xkb.server.key_acts[key]];
}

void XkbFreeClientMap(XkbDescPtr xkb, uint what, Bool freeMap)
{
    XkbClientMapPtr map = void;

    if ((xkb is null) || (xkb.map is null))
        return;
    if (freeMap)
        what = XkbAllClientInfoMask;
    map = xkb.map;
    if (what & XkbKeyTypesMask) {
        if (map.types !is null) {
            if (map.num_types > 0) {
                int i = void;
                XkbKeyTypePtr type = void;

                for (i = 0, type = map.types; i < map.num_types; i++, type++) {
                    free(type.map);
                    type.map = null;
                    free(type.preserve);
                    type.preserve = cast(_XkbMods*)null;
                    type.map_count = cast(ubyte)cast(ubyte*)0;
                    free(type.level_names);
                    type.level_names = cast(uint*)null;
                }
            }
            free(map.types);
            map.num_types = map.size_types = cast(ubyte)0;
            map.types = null;
        }
    }
    if (what & XkbKeySymsMask) {
        free(map.key_sym_map);
        map.key_sym_map = cast(_XkbSymMapRec*)null;
        if (map.syms !is null) {
            free(map.syms);
            map.size_syms = map.num_syms = 0;
            map.syms = cast(uint*)null;
        }
    }
    if ((what & XkbModifierMapMask) && (map.modmap !is null)) {
        free(map.modmap);
        map.modmap = cast(ubyte*)null;
    }
    if (freeMap) {
        free(xkb.map);
        xkb.map = null;
    }
    return;
}

void XkbFreeServerMap(XkbDescPtr xkb, uint what, Bool freeMap)
{
    XkbServerMapPtr map = void;

    if ((xkb is null) || (xkb.server is null))
        return;
    if (freeMap)
        what = XkbAllServerInfoMask;
    map = xkb.server;
    if ((what & XkbExplicitComponentsMask) && (map.explicit !is null)) {
        free(map.explicit);
        map.explicit =  cast(ubyte*)null;
    }
    if (what & XkbKeyActionsMask) {
        free(map.key_acts);
        map.key_acts = cast(ushort*)null;
        if (map.acts !is null) {
            free(map.acts);
            map.num_acts = map.size_acts = cast(ushort)0;
            map.acts = cast(_XkbAction*)null;
        }
    }
    if ((what & XkbKeyBehaviorsMask) && (map.behaviors !is null)) {
        free(map.behaviors);
        map.behaviors =  cast(_XkbBehavior*)null;
    }
    if ((what & XkbVirtualModMapMask) && (map.vmodmap !is null)) {
        free(map.vmodmap);
        map.vmodmap =  cast(ushort*)null;
    }

    if (freeMap) {
        free(xkb.server);
        xkb.server = null;
    }
    return;
}
