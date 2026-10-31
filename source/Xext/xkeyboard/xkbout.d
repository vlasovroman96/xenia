module xkb.xkbout;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
 Copyright (c) 1994 by Silicon Graphics Computer Systems, Inc.

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
import core.stdc.ctype;
import core.stdc.stdlib;
// //import x11.Xfuncs;
//import x11.X;
//import x11.keysym;
//import x11.Xproto;
import externs.X11.extensions.XKM;
import dix.atom;
import xkb.xkbfmisc_priv;
import xkb.xkbout_priv;
import xkb.xkbsrv_priv;
import xkb.xkbtext_priv;

import include.misc;
import include.inputstr;
import include.xkbsrv;
import xkb.xkbgeom_priv;
import externs.X11.extensions.XKB;
// import externs.X11.extensions.XKBgeom;
import include.xkbstr;
import xkb.XKBMAlloc;

alias XkbNumRequiredTypes = xkb.XKBMAlloc.XkbNumRequiredTypes;

enum	VMOD_HIDE_VALUE =	0;
enum	VMOD_SHOW_VALUE =	1;
enum	VMOD_COMMENT_VALUE = 2;

private Bool WriteXKBVModDecl(FILE* file, XkbDescPtr xkb, int showValue)
{
    int i = void, nMods = void;
    Atom* vmodNames = void;

    if (xkb is null)
        return FALSE;
    if (xkb.names !is null)
        vmodNames = xkb.names.vmods.ptr;
    else
        vmodNames = null;

    for (i = nMods = 0; i < XkbNumVirtualMods; i++) {
        if ((vmodNames !is null) && (vmodNames[i] != None)) {
            if (nMods == 0)
                fprintf(file, "    virtual_modifiers ");
            else
                fprintf(file, ",");
            fprintf(file, "%s", XkbAtomText(vmodNames[i], XkbXKBFile));
            if ((showValue != VMOD_HIDE_VALUE) &&
                (xkb.server) && (xkb.server.vmods[i] != XkbNoModifierMask)) {
                if (showValue == VMOD_COMMENT_VALUE) {
                    fprintf(file, "/* = %s */",
                            XkbModMaskText(xkb.server.vmods[i], XkbXKBFile));
                }
                else {
                    fprintf(file, "= %s",
                            XkbModMaskText(xkb.server.vmods[i], XkbXKBFile));
                }
            }
            nMods++;
        }
    }
    if (nMods > 0)
        fprintf(file, ";\n\n");
    return TRUE;
}

/***====================================================================***/

private Bool WriteXKBAction(FILE* file, XkbDescPtr xkb, XkbAnyAction* action)
{
    fprintf(file, "%s", XkbActionText(xkb, cast(XkbAction*) action, XkbXKBFile));
    return TRUE;
}

/***====================================================================***/

Bool XkbWriteXKBKeycodes(FILE* file, XkbDescPtr xkb, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv)
{
    Atom kcName = void;
    uint i = void;
    const(char)* alternate = void;

    if ((!xkb) || (!xkb.names) || (!xkb.names.keys)) {
        //_XkbLibError(_XkbErrMissingNames, "XkbWriteXKBKeycodes", 0);
        return FALSE;
    }
    kcName = xkb.names.keycodes;
    if (kcName != None)
        fprintf(file, "xkb_keycodes \"%s\" {\n",
                XkbAtomText(kcName, XkbXKBFile));
    else
        fprintf(file, "xkb_keycodes {\n");
    fprintf(file, "    minimum = %d;\n", xkb.min_key_code);
    fprintf(file, "    maximum = %d;\n", xkb.max_key_code);
    for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
        if (xkb.names.keys[i].name[0] != '\0') {
            if (XkbFindKeycodeByName(xkb, xkb.names.keys[i].name.ptr, TRUE) != i)
                alternate = "alternate ";
            else
                alternate = "";
            fprintf(file, "    %s%6s = %d;\n", alternate,
                    XkbKeyNameText(xkb.names.keys[i].name.ptr, XkbXKBFile), i);
        }
    }
    if (xkb.indicators !is null) {
        for (i = 0; i < XkbNumIndicators; i++) {
            const(char)* type = void;

            if (xkb.indicators.phys_indicators & (1 << i))
                type = "    ";
            else
                type = "    virtual ";
            if (xkb.names.indicators[i] != None) {
                fprintf(file, "%sindicator %d = \"%s\";\n", type, i + 1,
                        XkbAtomText(xkb.names.indicators[i], XkbXKBFile));
            }
        }
    }
    if (xkb.names.key_aliases !is null) {
        XkbKeyAliasPtr pAl = void;

        pAl = xkb.names.key_aliases;
        for (i = 0; i < xkb.names.num_key_aliases; i++, pAl++) {
            fprintf(file, "    alias %6s = %6s;\n",
                    XkbKeyNameText(pAl.alias_.ptr, XkbXKBFile),
                    XkbKeyNameText(pAl.real_.ptr, XkbXKBFile));
        }
    }
    if (addOn)
        (*addOn) (file, xkb, topLevel, showImplicit, XkmKeyNamesIndex, priv);
    fprintf(file, "};\n\n");
    return TRUE;
}

Bool XkbWriteXKBKeyTypes(FILE* file, XkbDescPtr xkb, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv)
{
    uint i = void, n = void;
    XkbKeyTypePtr type = void;
    XkbKTMapEntryPtr entry = void;

    if ((!xkb) || (!xkb.map) || (!xkb.map.types)) {
        //_XkbLibError(_XkbErrMissingTypes, "XkbWriteXKBKeyTypes", 0);
        return FALSE;
    }
    if (xkb.map.num_types < XkbNumRequiredTypes) {
        //_XkbLibError(_XkbErrMissingReqTypes, "XkbWriteXKBKeyTypes", 0);
        return 0;
    }
    if ((xkb.names is null) || (xkb.names.types == None))
        fprintf(file, "xkb_types {\n\n");
    else
        fprintf(file, "xkb_types \"%s\" {\n\n",
                XkbAtomText(xkb.names.types, XkbXKBFile));
    WriteXKBVModDecl(file, xkb,
                     (showImplicit ? VMOD_COMMENT_VALUE : VMOD_HIDE_VALUE));

    type = xkb.map.types;
    for (i = 0; i < xkb.map.num_types; i++, type++) {
        fprintf(file, "    type \"%s\" {\n",
                XkbAtomText(type.name, XkbXKBFile));
        fprintf(file, "        modifiers= %s;\n",
                XkbVModMaskText(xkb, type.mods.real_mods, type.mods.vmods,
                                XkbXKBFile));
        entry = type.map;
        for (n = 0; n < type.map_count; n++, entry++) {
            char* str = void;

            str = XkbVModMaskText(xkb, entry.mods.real_mods, entry.mods.vmods,
                                  XkbXKBFile);
            fprintf(file, "        map[%s]= Level%d;\n", str, entry.level + 1);
            if ((type.preserve) && ((type.preserve[n].real_mods) ||
                                     (type.preserve[n].vmods))) {
                fprintf(file, "        preserve[%s]= ", str);
                fprintf(file, "%s;\n", XkbVModMaskText(xkb,
                                                       type.preserve[n].
                                                       real_mods,
                                                       type.preserve[n].vmods,
                                                       XkbXKBFile));
            }
        }
        if (type.level_names !is null) {
            Atom* name = type.level_names;

            for (n = 0; n < type.num_levels; n++, name++) {
                if ((*name) == None)
                    continue;
                fprintf(file, "        level_name[Level%d]= \"%s\";\n", n + 1,
                        XkbAtomText(*name, XkbXKBFile));
            }
        }
        fprintf(file, "    };\n");
    }
    if (addOn)
        (*addOn) (file, xkb, topLevel, showImplicit, XkmTypesIndex, priv);
    fprintf(file, "};\n\n");
    return TRUE;
}

private Bool WriteXKBIndicatorMap(FILE* file, XkbDescPtr xkb, Atom name, XkbIndicatorMapPtr led, XkbFileAddOnFunc addOn, void* priv)
{

    fprintf(file, "    indicator \"%s\" {\n", NameForAtom(name));
    if (led.flags & XkbIM_NoExplicit)
        fprintf(file, "        !allowExplicit;\n");
    if (led.flags & XkbIM_LEDDrivesKB)
        fprintf(file, "        indicatorDrivesKeyboard;\n");
    if (led.which_groups != 0) {
        if (led.which_groups != XkbIM_UseEffective) {
            fprintf(file, "        whichGroupState= %s;\n",
                    XkbIMWhichStateMaskText(led.which_groups, XkbXKBFile));
        }
        fprintf(file, "        groups= 0x%02x;\n", led.groups);
    }
    if (led.which_mods != 0) {
        if (led.which_mods != XkbIM_UseEffective) {
            fprintf(file, "        whichModState= %s;\n",
                    XkbIMWhichStateMaskText(led.which_mods, XkbXKBFile));
        }
        fprintf(file, "        modifiers= %s;\n",
                XkbVModMaskText(xkb,
                                led.mods.real_mods, led.mods.vmods,
                                XkbXKBFile));
    }
    if (led.ctrls != 0) {
        fprintf(file, "        controls= %s;\n",
                XkbControlsMaskText(led.ctrls, XkbXKBFile));
    }
    if (addOn)
        (*addOn) (file, xkb, FALSE, TRUE, XkmIndicatorsIndex, priv);
    fprintf(file, "    };\n");
    return TRUE;
}

Bool XkbWriteXKBCompatMap(FILE* file, XkbDescPtr xkb, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv)
{
    uint i = void;
    XkbSymInterpretPtr interp = void;

    if ((!xkb) || (!xkb.compat) || (!xkb.compat.sym_interpret)) {
        //_XkbLibError(_XkbErrMissingCompatMap, "XkbWriteXKBCompatMap", 0);
        return FALSE;
    }
    if ((xkb.names is null) || (xkb.names.compat == None))
        fprintf(file, "xkb_compatibility {\n\n");
    else
        fprintf(file, "xkb_compatibility \"%s\" {\n\n",
                XkbAtomText(xkb.names.compat, XkbXKBFile));
    WriteXKBVModDecl(file, xkb,
                     (showImplicit ? VMOD_COMMENT_VALUE : VMOD_HIDE_VALUE));

    fprintf(file, "    interpret.useModMapMods= AnyLevel;\n");
    fprintf(file, "    interpret.repeat= FALSE;\n");
    fprintf(file, "    interpret.locking= FALSE;\n");
    interp = xkb.compat.sym_interpret;
    for (i = 0; i < xkb.compat.num_si; i++, interp++) {
        fprintf(file, "    interpret %s+%s(%s) {\n",
                ((interp.sym == NoSymbol) ? "Any" :
                 XkbKeysymText(interp.sym, XkbXKBFile)),
                XkbSIMatchText(interp.match, XkbXKBFile),
                XkbModMaskText(interp.mods, XkbXKBFile));
        if (interp.virtual_mod != XkbNoModifier) {
            fprintf(file, "        virtualModifier= %s;\n",
                    XkbVModIndexText(xkb, interp.virtual_mod, XkbXKBFile));
        }
        if (interp.match & XkbSI_LevelOneOnly)
            fprintf(file, "        useModMapMods=level1;\n");
        if (interp.flags & XkbSI_LockingKey)
            fprintf(file, "        locking= TRUE;\n");
        if (interp.flags & XkbSI_AutoRepeat)
            fprintf(file, "        repeat= TRUE;\n");
        fprintf(file, "        action= ");
        WriteXKBAction(file, xkb, &interp.act);
        fprintf(file, ";\n");
        fprintf(file, "    };\n");
    }
    for (i = 0; i < XkbNumKbdGroups; i++) {
        XkbModsPtr gc = void;

        gc = &xkb.compat.groups[i];
        if ((gc.real_mods == 0) && (gc.vmods == 0))
            continue;
        fprintf(file, "    group %d = %s;\n", i + 1, XkbVModMaskText(xkb,
                                                                     gc.
                                                                     real_mods,
                                                                     gc.vmods,
                                                                     XkbXKBFile));
    }
    if (xkb.indicators) {
        for (i = 0; i < XkbNumIndicators; i++) {
            XkbIndicatorMapPtr map = &xkb.indicators.maps[i];

            if ((map.flags != 0) || (map.which_groups != 0) ||
                (map.groups != 0) || (map.which_mods != 0) ||
                (map.mods.real_mods != 0) || (map.mods.vmods != 0) ||
                (map.ctrls != 0)) {
                WriteXKBIndicatorMap(file, xkb, xkb.names.indicators[i], map,
                                     addOn, priv);
            }
        }
    }
    if (addOn)
        (*addOn) (file, xkb, topLevel, showImplicit, XkmCompatMapIndex, priv);
    fprintf(file, "};\n\n");
    return TRUE;
}

Bool XkbWriteXKBSymbols(FILE* file, XkbDescPtr xkb, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv)
{
    uint i = void, tmp = void;
    XkbClientMapPtr map = void;
    XkbServerMapPtr srv = void;
    Bool showActions = void;

    if (!xkb) {
        //_XkbLibError(_XkbErrMissingSymbols, "XkbWriteXKBSymbols", 0);
        return FALSE;
    }

    map = xkb.map;
    if ((!map) || (!map.syms) || (!map.key_sym_map)) {
        //_XkbLibError(_XkbErrMissingSymbols, "XkbWriteXKBSymbols", 0);
        return FALSE;
    }
    if ((!xkb.names) || (!xkb.names.keys)) {
        //_XkbLibError(_XkbErrMissingNames, "XkbWriteXKBSymbols", 0);
        return FALSE;
    }
    if ((xkb.names is null) || (xkb.names.symbols == None))
        fprintf(file, "xkb_symbols {\n\n");
    else
        fprintf(file, "xkb_symbols \"%s\" {\n\n",
                XkbAtomText(xkb.names.symbols, XkbXKBFile));
    for (tmp = i = 0; i < XkbNumKbdGroups; i++) {
        if (xkb.names.groups[i] != None) {
            fprintf(file, "    name[group%d]=\"%s\";\n", i + 1,
                    XkbAtomText(xkb.names.groups[i], XkbXKBFile));
            tmp++;
        }
    }
    if (tmp > 0)
        fprintf(file, "\n");
    srv = xkb.server;
    for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
        Bool simple = void;

        if (cast(int) mixin(XkbKeyNumSyms!("xkb", "i")) < 1)
            continue;
        if (XkbFindKeycodeByName(xkb, xkb.names.keys[i].name.ptr, TRUE) != i)
            continue;
        simple = TRUE;
        fprintf(file, "    key %6s {",
                XkbKeyNameText(xkb.names.keys[i].name.ptr, XkbXKBFile));
        if (srv.explicit) {
            if (((srv.explicit[i] & XkbExplicitKeyTypesMask) != 0) ||
                (showImplicit)) {
                int typeNdx = void, g = void;
                Bool multi = void;
                const(char)* comment = "  ";

                if ((srv.explicit[i] & XkbExplicitKeyTypesMask) == 0)
                    comment = "//";
                multi = FALSE;
                typeNdx = mixin(XkbKeyKeyTypeIndex!("xkb", "i", "0"));
                for (g = 1; (g < mixin(XkbKeyNumGroups!("xkb", "i"))) && (!multi); g++) {
                    if (mixin(XkbKeyKeyTypeIndex!("xkb", "i", "g")) != typeNdx)
                        multi = TRUE;
                }
                if (multi) {
                    for (g = 0; g < mixin(XkbKeyNumGroups!("xkb", "i")); g++) {
                        typeNdx = mixin(XkbKeyKeyTypeIndex!("xkb", "i", "g"));
                        if (srv.explicit[i] & (1 << g)) {
                            fprintf(file, "\n%s      type[group%d]= \"%s\",",
                                    comment, g + 1,
                                    XkbAtomText(map.types[typeNdx].name,
                                                XkbXKBFile));
                        }
                        else if (showImplicit) {
                            fprintf(file, "\n//      type[group%d]= \"%s\",",
                                    g + 1, XkbAtomText(map.types[typeNdx].name,
                                                       XkbXKBFile));
                        }
                    }
                }
                else {
                    fprintf(file, "\n%s      type= \"%s\",", comment,
                            XkbAtomText(map.types[typeNdx].name, XkbXKBFile));
                }
                simple = FALSE;
            }
            if (((srv.explicit[i] & XkbExplicitAutoRepeatMask) != 0) &&
                (xkb.ctrls !is null)) {
                if (xkb.ctrls.per_key_repeat[i / 8] & (1 << (i % 8)))
                    fprintf(file, "\n        repeat= Yes,");
                else
                    fprintf(file, "\n        repeat= No,");
                simple = FALSE;
            }
            if ((xkb.server !is null) && (xkb.server.vmodmap !is null) &&
                (xkb.server.vmodmap[i] != 0)) {
                if ((srv.explicit[i] & XkbExplicitVModMapMask) != 0) {
                    fprintf(file, "\n        virtualMods= %s,",
                            XkbVModMaskText(xkb, 0,
                                            xkb.server.vmodmap[i],
                                            XkbXKBFile));
                }
                else if (showImplicit) {
                    fprintf(file, "\n//      virtualMods= %s,",
                            XkbVModMaskText(xkb, 0,
                                            xkb.server.vmodmap[i],
                                            XkbXKBFile));
                }
            }
        }
        switch (mixin(XkbOutOfRangeGroupAction!(XkbKeyGroupInfo!("xkb", "i")))) {
        case XkbClampIntoRange:
            fprintf(file, "\n        groupsClamp,");
            break;
        case XkbRedirectIntoRange:
            fprintf(file, "\n        groupsRedirect= Group%d,",
                    mixin(XkbOutOfRangeGroupNumber!(XkbKeyGroupInfo!("xkb", "i"))) + 1);
            break;
        default: break;}
        if (srv.behaviors !is null) {
            uint type = void;

            type = srv.behaviors[i].type & XkbKB_OpMask;

            if (type != XkbKB_Default) {
                simple = FALSE;
                fprintf(file, "\n        %s,",
                        XkbBehaviorText(xkb, &srv.behaviors[i], XkbXKBFile));
            }
        }
        if ((srv.explicit is null) || showImplicit ||
            ((srv.explicit[i] & XkbExplicitInterpretMask) != 0))
            showActions = mixin(XkbKeyHasActions!("xkb", "i"));
        else
            showActions = FALSE;

        if ((cast(uint) mixin(XkbKeyNumGroups!("xkb", "i")) > 1) || showActions)
            simple = FALSE;
        if (simple) {
            KeySym* syms = void;
            uint s = void;

            syms = mixin(XkbKeySymsPtr!("xkb", "i"));
            fprintf(file, "         [ ");
            for (s = 0; s < mixin(XkbKeyGroupWidth!("xkb", "i", "XkbGroup1Index")); s++) {
                if (s != 0)
                    fprintf(file, ", ");
                fprintf(file, "%15s", XkbKeysymText(*syms++, XkbXKBFile));
            }
            fprintf(file, " ] };\n");
        }
        else {
            uint g = void, s = void;
            KeySym* syms = void;
            XkbAction* acts = void;

            syms = mixin(XkbKeySymsPtr!("xkb", "i"));
            acts = mixin(XkbKeyActionsPtr!("xkb", "i"));
            for (g = 0; g < mixin(XkbKeyNumGroups!("xkb", "i")); g++) {
                if (g != 0)
                    fprintf(file, ",");
                fprintf(file, "\n        symbols[Group%d]= [ ", g + 1);
                for (s = 0; s < mixin(XkbKeyGroupWidth!("xkb", "i", "g")); s++) {
                    if (s != 0)
                        fprintf(file, ", ");
                    fprintf(file, "%15s", XkbKeysymText(syms[s], XkbXKBFile));
                }
                fprintf(file, " ]");
                syms += mixin(XkbKeyGroupsWidth!("xkb", "i"));
                if (showActions) {
                    fprintf(file, ",\n        actions[Group%d]= [ ", g + 1);
                    for (s = 0; s < mixin(XkbKeyGroupWidth!("xkb", "i", "g")); s++) {
                        if (s != 0)
                            fprintf(file, ", ");
                        WriteXKBAction(file, xkb, cast(XkbAnyAction*) &acts[s]);
                    }
                    fprintf(file, " ]");
                    acts += mixin(XkbKeyGroupsWidth!("xkb", "i"));
                }
            }
            fprintf(file, "\n    };\n");
        }
    }
    if (map && map.modmap) {
        for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
            if (map.modmap[i] != 0) {
                int n = void, bit = void;

                for (bit = 1, n = 0; n < XkbNumModifiers; n++, bit <<= 1) {
                    if (map.modmap[i] & bit) {
                        char[5] buf = void;

                        memcpy(buf.ptr, xkb.names.keys[i].name.ptr, 4);
                        buf[4] = '\0';
                        fprintf(file, "    modifier_map %s { <%s> };\n",
                                XkbModIndexText(n, XkbXKBFile), buf.ptr);
                    }
                }
            }
        }
    }
    if (addOn)
        (*addOn) (file, xkb, topLevel, showImplicit, XkmSymbolsIndex, priv);
    fprintf(file, "};\n\n");
    return TRUE;
}

private Bool WriteXKBOutline(FILE* file, XkbShapePtr shape, XkbOutlinePtr outline, int lastRadius, int first, int indent)
{
    int i = void;
    XkbPointPtr pt = void;
    char* iStr = void;

    fprintf(file, "%s", iStr = XkbIndentText(first));
    if (first != indent)
        iStr = XkbIndentText(indent);
    if (outline.corner_radius != lastRadius) {
        fprintf(file, "corner= %s,",
                XkbGeomFPText(outline.corner_radius, XkbMessage));
        if (shape !is null) {
            fprintf(file, "\n%s", iStr);
        }
    }
    if (shape) {
        if (outline == shape.approx)
            fprintf(file, "approx= ");
        else if (outline == shape.primary)
            fprintf(file, "primary= ");
    }
    fprintf(file, "{");
    for (pt = outline.points, i = 0; i < outline.num_points; i++, pt++) {
        if (i == 0)
            fprintf(file, " ");
        else if ((i % 4) == 0)
            fprintf(file, ",\n%s  ", iStr);
        else
            fprintf(file, ", ");
        fprintf(file, "[ %3s, %3s ]", XkbGeomFPText(pt.x, XkbXKBFile),
                XkbGeomFPText(pt.y, XkbXKBFile));
    }
    fprintf(file, " }");
    return TRUE;
}

private Bool WriteXKBDoodad(FILE* file, uint indent, XkbGeometryPtr geom, XkbDoodadPtr doodad)
{
    char* i_str = void;
    XkbShapePtr shape = void;
    XkbColorPtr color = void;

    i_str = XkbIndentText(indent);
    fprintf(file, "%s%s \"%s\" {\n", i_str,
            XkbDoodadTypeText(doodad.any.type, XkbMessage),
            XkbAtomText(doodad.any.name, XkbMessage));
    fprintf(file, "%s    top=      %s;\n", i_str,
            XkbGeomFPText(doodad.any.top, XkbXKBFile));
    fprintf(file, "%s    left=     %s;\n", i_str,
            XkbGeomFPText(doodad.any.left, XkbXKBFile));
    fprintf(file, "%s    priority= %d;\n", i_str, doodad.any.priority);
    switch (doodad.any.type) {
    case XkbOutlineDoodad:
    case XkbSolidDoodad:
        if (doodad.shape.angle != 0) {
            fprintf(file, "%s    angle=  %s;\n", i_str,
                    XkbGeomFPText(doodad.shape.angle, XkbXKBFile));
        }
        if (doodad.shape.color_ndx != 0) {
            fprintf(file, "%s    color= \"%s\";\n", i_str,
                    mixin(XkbShapeDoodadColor!("geom", "&doodad.shape")).spec);
        }
        shape = mixin(XkbShapeDoodadShape!("geom", "&doodad.shape"));
        fprintf(file, "%s    shape= \"%s\";\n", i_str,
                XkbAtomText(shape.name, XkbXKBFile));
        break;
    case XkbTextDoodad:
        if (doodad.text.angle != 0) {
            fprintf(file, "%s    angle=  %s;\n", i_str,
                    XkbGeomFPText(doodad.text.angle, XkbXKBFile));
        }
        if (doodad.text.width != 0) {
            fprintf(file, "%s    width=  %s;\n", i_str,
                    XkbGeomFPText(doodad.text.width, XkbXKBFile));

        }
        if (doodad.text.height != 0) {
            fprintf(file, "%s    height=  %s;\n", i_str,
                    XkbGeomFPText(doodad.text.height, XkbXKBFile));

        }
        if (doodad.text.color_ndx != 0) {
            color = mixin(XkbTextDoodadColor!("geom", "&doodad.text"));
            fprintf(file, "%s    color= \"%s\";\n", i_str,
                    XkbStringText(color.spec, XkbXKBFile));
        }
        fprintf(file, "%s    XFont= \"%s\";\n", i_str,
                XkbStringText(doodad.text.font, XkbXKBFile));
        fprintf(file, "%s    text=  \"%s\";\n", i_str,
                XkbStringText(doodad.text.text, XkbXKBFile));
        break;
    case XkbIndicatorDoodad:
        shape = mixin(XkbIndicatorDoodadShape!("geom", "&doodad.indicator"));
        color = mixin(XkbIndicatorDoodadOnColor!("geom", "&doodad.indicator"));
        fprintf(file, "%s    onColor= \"%s\";\n", i_str,
                XkbStringText(color.spec, XkbXKBFile));
        color = mixin(XkbIndicatorDoodadOffColor!("geom", "&doodad.indicator"));
        fprintf(file, "%s    offColor= \"%s\";\n", i_str,
                XkbStringText(color.spec, XkbXKBFile));
        fprintf(file, "%s    shape= \"%s\";\n", i_str,
                XkbAtomText(shape.name, XkbXKBFile));
        break;
    case XkbLogoDoodad:
        fprintf(file, "%s    logoName= \"%s\";\n", i_str,
                XkbStringText(doodad.logo.logo_name, XkbXKBFile));
        if (doodad.shape.angle != 0) {
            fprintf(file, "%s    angle=  %s;\n", i_str,
                    XkbGeomFPText(doodad.logo.angle, XkbXKBFile));
        }
        if (doodad.shape.color_ndx != 0) {
            fprintf(file, "%s    color= \"%s\";\n", i_str,
                    mixin(XkbLogoDoodadColor!("geom", "&doodad.logo")).spec);
        }
        shape = mixin(XkbLogoDoodadShape!("geom", "&doodad.logo"));
        fprintf(file, "%s    shape= \"%s\";\n", i_str,
                XkbAtomText(shape.name, XkbXKBFile));
        break;
    default: break;}
    fprintf(file, "%s};\n", i_str);
    return TRUE;
}

 /*ARGSUSED*/ private Bool WriteXKBOverlay(FILE* file, uint indent, XkbGeometryPtr geom, XkbOverlayPtr ol)
{
    char* i_str = void;
    int r = void, k = void, nOut = void;
    XkbOverlayRowPtr row = void;
    XkbOverlayKeyPtr key = void;

    i_str = XkbIndentText(indent);
    if (ol.name != None) {
        fprintf(file, "%soverlay \"%s\" {\n", i_str,
                XkbAtomText(ol.name, XkbMessage));
    }
    else
        fprintf(file, "%soverlay {\n", i_str);
    for (nOut = r = 0, row = ol.rows; r < ol.num_rows; r++, row++) {
        for (k = 0, key = row.keys; k < row.num_keys; k++, key++) {
            char* over = void, under = void;

            over = XkbKeyNameText(key.over.name.ptr, XkbXKBFile);
            under = XkbKeyNameText(key.under.name.ptr, XkbXKBFile);
            if (nOut == 0)
                fprintf(file, "%s    %6s=%6s", i_str, under, over);
            else if ((nOut % 4) == 0)
                fprintf(file, ",\n%s    %6s=%6s", i_str, under, over);
            else
                fprintf(file, ", %6s=%6s", under, over);
            nOut++;
        }
    }
    fprintf(file, "\n%s};\n", i_str);
    return TRUE;
}

private Bool WriteXKBSection(FILE* file, XkbSectionPtr s, XkbGeometryPtr geom)
{
    int i = void;
    XkbRowPtr row = void;
    int dfltKeyColor = 0;

    fprintf(file, "    section \"%s\" {\n", XkbAtomText(s.name, XkbXKBFile));
    if (s.rows && (s.rows.num_keys > 0)) {
        dfltKeyColor = s.rows.keys[0].color_ndx;
        fprintf(file, "        key.color= \"%s\";\n",
                XkbStringText(geom.colors[dfltKeyColor].spec, XkbXKBFile));
    }
    fprintf(file, "        priority=  %d;\n", s.priority);
    fprintf(file, "        top=       %s;\n",
            XkbGeomFPText(s.top, XkbXKBFile));
    fprintf(file, "        left=      %s;\n",
            XkbGeomFPText(s.left, XkbXKBFile));
    fprintf(file, "        width=     %s;\n",
            XkbGeomFPText(s.width, XkbXKBFile));
    fprintf(file, "        height=    %s;\n",
            XkbGeomFPText(s.height, XkbXKBFile));
    if (s.angle != 0) {
        fprintf(file, "        angle=  %s;\n",
                XkbGeomFPText(s.angle, XkbXKBFile));
    }
    for (i = 0, row = s.rows; i < s.num_rows; i++, row++) {
        fprintf(file, "        row {\n");
        fprintf(file, "            top=  %s;\n",
                XkbGeomFPText(row.top, XkbXKBFile));
        fprintf(file, "            left= %s;\n",
                XkbGeomFPText(row.left, XkbXKBFile));
        if (row.vertical)
            fprintf(file, "            vertical;\n");
        if (row.num_keys > 0) {
            int k = void;
            XkbKeyPtr key = void;
            int forceNL = 0;
            int nThisLine = 0;

            fprintf(file, "            keys {\n");
            for (k = 0, key = row.keys; k < row.num_keys; k++, key++) {
                XkbShapePtr shape = void;

                if (key.color_ndx != dfltKeyColor)
                    forceNL = 1;
                if (k == 0) {
                    fprintf(file, "                ");
                    nThisLine = 0;
                }
                else if (((nThisLine % 2) == 1) || (forceNL)) {
                    fprintf(file, ",\n                ");
                    forceNL = nThisLine = 0;
                }
                else {
                    fprintf(file, ", ");
                    nThisLine++;
                }
                shape = mixin(XkbKeyShape!("geom", "key"));
                fprintf(file, "{ %6s, \"%s\", %3s",
                        XkbKeyNameText(key.name.name.ptr, XkbXKBFile),
                        XkbAtomText(shape.name, XkbXKBFile),
                        XkbGeomFPText(key.gap, XkbXKBFile));
                if (key.color_ndx != dfltKeyColor) {
                    fprintf(file, ", color=\"%s\"",
                            mixin(XkbKeyColor!("geom", "key")).spec);
                    forceNL = 1;
                }
                fprintf(file, " }");
            }
            fprintf(file, "\n            };\n");
        }
        fprintf(file, "        };\n");
    }
    if (s.doodads !is null) {
        XkbDoodadPtr doodad = void;

        for (i = 0, doodad = s.doodads; i < s.num_doodads; i++, doodad++) {
            WriteXKBDoodad(file, 8, geom, doodad);
        }
    }
    if (s.overlays !is null) {
        XkbOverlayPtr ol = void;

        for (i = 0, ol = s.overlays; i < s.num_overlays; i++, ol++) {
            WriteXKBOverlay(file, 8, geom, ol);
        }
    }
    fprintf(file, "    }; // End of \"%s\" section\n\n",
            XkbAtomText(s.name, XkbXKBFile));
    return TRUE;
}

Bool XkbWriteXKBGeometry(FILE* file, XkbDescPtr xkb, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv)
{
    uint i = void, n = void;
    XkbGeometryPtr geom = void;

    if ((!xkb) || (!xkb.geom)) {
        //_XkbLibError(_XkbErrMissingGeometry, "XkbWriteXKBGeometry", 0);
        return FALSE;
    }
    geom = xkb.geom;
    if (geom.name == None)
        fprintf(file, "xkb_geometry {\n\n");
    else
        fprintf(file, "xkb_geometry \"%s\" {\n\n",
                XkbAtomText(geom.name, XkbXKBFile));
    fprintf(file, "    width=       %s;\n",
            XkbGeomFPText(geom.width_mm, XkbXKBFile));
    fprintf(file, "    height=      %s;\n\n",
            XkbGeomFPText(geom.height_mm, XkbXKBFile));

    if (geom.key_aliases !is null) {
        XkbKeyAliasPtr pAl = void;

        pAl = geom.key_aliases;
        for (i = 0; i < geom.num_key_aliases; i++, pAl++) {
            fprintf(file, "    alias %6s = %6s;\n",
                    XkbKeyNameText(pAl.alias_.ptr, XkbXKBFile),
                    XkbKeyNameText(pAl.real_.ptr, XkbXKBFile));
        }
        fprintf(file, "\n");
    }

    if (geom.base_color !is null)
        fprintf(file, "    baseColor=   \"%s\";\n",
                XkbStringText(geom.base_color.spec, XkbXKBFile));
    if (geom.label_color !is null)
        fprintf(file, "    labelColor=  \"%s\";\n",
                XkbStringText(geom.label_color.spec, XkbXKBFile));
    if (geom.label_font !is null)
        fprintf(file, "    xfont=       \"%s\";\n",
                XkbStringText(geom.label_font, XkbXKBFile));
    if ((geom.num_colors > 0) && (showImplicit)) {
        XkbColorPtr color = void;

        for (color = geom.colors, i = 0; i < geom.num_colors; i++, color++) {
            fprintf(file, "//     color[%d]= \"%s\"\n", i,
                    XkbStringText(color.spec, XkbXKBFile));
        }
        fprintf(file, "\n");
    }
    if (geom.num_properties > 0) {
        XkbPropertyPtr prop = void;

        for (prop = geom.properties, i = 0; i < geom.num_properties;
             i++, prop++) {
            fprintf(file, "    %s= \"%s\";\n", prop.name,
                    XkbStringText(prop.value, XkbXKBFile));
        }
        fprintf(file, "\n");
    }
    if (geom.num_shapes > 0) {
        XkbShapePtr shape = void;
        XkbOutlinePtr outline = void;
        int lastR = void;

        for (shape = geom.shapes, i = 0; i < geom.num_shapes; i++, shape++) {
            lastR = 0;
            fprintf(file, "    shape \"%s\" {",
                    XkbAtomText(shape.name, XkbXKBFile));
            outline = shape.outlines;
            if (shape.num_outlines > 1) {
                for (n = 0; n < shape.num_outlines; n++, outline++) {
                    if (n == 0)
                        fprintf(file, "\n");
                    else
                        fprintf(file, ",\n");
                    WriteXKBOutline(file, shape, outline, lastR, 8, 8);
                    lastR = outline.corner_radius;
                }
                fprintf(file, "\n    };\n");
            }
            else {
                WriteXKBOutline(file, null, outline, lastR, 1, 8);
                fprintf(file, " };\n");
            }
        }
    }
    if (geom.num_sections > 0) {
        XkbSectionPtr section = void;

        for (section = geom.sections, i = 0; i < geom.num_sections;
             i++, section++) {
            WriteXKBSection(file, section, geom);
        }
    }
    if (geom.num_doodads > 0) {
        XkbDoodadPtr doodad = void;

        for (i = 0, doodad = geom.doodads; i < geom.num_doodads;
             i++, doodad++) {
            WriteXKBDoodad(file, 4, geom, doodad);
        }
    }
    if (addOn)
        (*addOn) (file, xkb, topLevel, showImplicit, XkmGeometryIndex, priv);
    fprintf(file, "};\n\n");
    return TRUE;
}
