module xkb.XKBGAlloc;
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
import core.stdc.string;
//import x11.X;
//import x11.Xproto;
import include.misc;
import dix.inputstr;import include.xkbsrv;
import xkb.xkbgeom_priv;
import include.xkbstr;
// import externs.X11.extensions.XKBgeom;
import externs.X11.extensions.XKB;

import externs.gnu;


/***====================================================================***/

private void _XkbFreeGeomLeafElems(Bool freeAll, int first, int count, ushort* num_inout, ushort* sz_inout, char** elems, uint elem_sz)
{
    if ((freeAll) || (*elems is null)) {
        *num_inout = *sz_inout = 0;
        free(*elems);
        *elems = null;
        return;
    }

    if ((first >= (*num_inout)) || (first < 0) || (count < 1))
        return;

    if (first + count >= (*num_inout)) {
        /* truncating the array is easy */
        (*num_inout) = cast(ushort)first;
    }
    else {
        char* ptr = void;
        int extra = void;

        ptr = *elems;
        extra = ((*num_inout) - (first + count)) * elem_sz;
        if (extra > 0)
            memmove(&ptr[first * elem_sz], &ptr[(first + count) * elem_sz],
                    extra);
        (*num_inout) -= count;
    }
    return;
}

alias ContentsClearFunc = void function(char*);

private void _XkbFreeGeomNonLeafElems(Bool freeAll, int first, int count, ushort* num_inout, ushort* sz_inout, char** elems, uint elem_sz, ContentsClearFunc freeFunc)
{
    int i = void;
    char* ptr = void;

    if (freeAll) {
        first = 0;
        count = (*num_inout);
    }
    else if ((first >= (*num_inout)) || (first < 0) || (count < 1))
        return;
    else if (first + count > (*num_inout))
        count = (*num_inout) - first;
    if (*elems is null)
        return;

    if (freeFunc) {
        ptr = *elems;
        ptr += first * elem_sz;
        for (i = 0; i < count; i++) {
            (*freeFunc) (ptr);
            ptr += elem_sz;
        }
    }
    if (freeAll) {
        (*num_inout) = (*sz_inout) = 0;
        free(*elems);
        *elems = null;
    }
    else if (first + count >= (*num_inout))
        *num_inout = cast(ushort)first;
    else {
        i = ((*num_inout) - (first + count)) * elem_sz;
        ptr = *elems;
        memmove(&ptr[first * elem_sz], &ptr[(first + count) * elem_sz], i);
        (*num_inout) -= count;
    }
    return;
}

/***====================================================================***/

private void _XkbClearProperty(char* prop_in)
{
    XkbPropertyPtr prop = cast(XkbPropertyPtr) prop_in;

    free(prop.name);
    prop.name = null;
    free(prop.value);
    prop.value = null;
    return;
}

void XkbFreeGeomProperties(XkbGeometryPtr geom, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &geom.num_properties, &geom.sz_properties,
                             cast(char**) &geom.properties,
                             XkbPropertyRec.sizeof, &_XkbClearProperty);
    return;
}

/***====================================================================***/

void XkbFreeGeomKeyAliases(XkbGeometryPtr geom, int first, int count, Bool freeAll)
{
    _XkbFreeGeomLeafElems(freeAll, first, count,
                          &geom.num_key_aliases, &geom.sz_key_aliases,
                          cast(char**) &geom.key_aliases, XkbKeyAliasRec.sizeof);
    return;
}

/***====================================================================***/

private void _XkbClearColor(char* color_in)
{
    XkbColorPtr color = cast(XkbColorPtr) color_in;

    free(color.spec);
    return;
}

void XkbFreeGeomColors(XkbGeometryPtr geom, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &geom.num_colors, &geom.sz_colors,
                             cast(char**) &geom.colors,
                             XkbColorRec.sizeof, &_XkbClearColor);
    return;
}

/***====================================================================***/

void XkbFreeGeomPoints(XkbOutlinePtr outline, int first, int count, Bool freeAll)
{
    _XkbFreeGeomLeafElems(freeAll, first, count,
                          &outline.num_points, &outline.sz_points,
                          cast(char**) &outline.points, XkbPointRec.sizeof);
    return;
}

/***====================================================================***/

private void _XkbClearOutline(char* outline_in)
{
    XkbOutlinePtr outline = cast(XkbOutlinePtr) outline_in;

    if (outline.points !is null)
        XkbFreeGeomPoints(outline, 0, outline.num_points, TRUE);
    return;
}

void XkbFreeGeomOutlines(XkbShapePtr shape, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &shape.num_outlines, &shape.sz_outlines,
                             cast(char**) &shape.outlines,
                             XkbOutlineRec.sizeof, &_XkbClearOutline);

    return;
}

/***====================================================================***/

private void _XkbClearShape(char* shape_in)
{
    XkbShapePtr shape = cast(XkbShapePtr) shape_in;

    if (shape.outlines)
        XkbFreeGeomOutlines(shape, 0, shape.num_outlines, TRUE);
    return;
}

void XkbFreeGeomShapes(XkbGeometryPtr geom, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &geom.num_shapes, &geom.sz_shapes,
                             cast(char**) &geom.shapes,
                             XkbShapeRec.sizeof, &_XkbClearShape);
    return;
}

/***====================================================================***/

void XkbFreeGeomKeys(XkbRowPtr row, int first, int count, Bool freeAll)
{
    _XkbFreeGeomLeafElems(freeAll, first, count,
                          &row.num_keys, &row.sz_keys,
                          cast(char**) &row.keys, XkbKeyRec.sizeof);
    return;
}

/***====================================================================***/

private void _XkbClearRow(char* row_in)
{
    XkbRowPtr row = cast(XkbRowPtr) row_in;

    if (row.keys !is null)
        XkbFreeGeomKeys(row, 0, row.num_keys, TRUE);
    return;
}

void XkbFreeGeomRows(XkbSectionPtr section, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &section.num_rows, &section.sz_rows,
                             cast(char**) &section.rows,
                             XkbRowRec.sizeof, &_XkbClearRow);
}

/***====================================================================***/

private void _XkbClearSection(char* section_in)
{
    XkbSectionPtr section = cast(XkbSectionPtr) section_in;

    if (section.rows !is null)
        XkbFreeGeomRows(section, 0, section.num_rows, TRUE);
    if (section.doodads !is null) {
        XkbFreeGeomDoodads(section.doodads, section.num_doodads, TRUE);
        section.doodads = null;
    }
    return;
}

void XkbFreeGeomSections(XkbGeometryPtr geom, int first, int count, Bool freeAll)
{
    _XkbFreeGeomNonLeafElems(freeAll, first, count,
                             &geom.num_sections, &geom.sz_sections,
                             cast(char**) &geom.sections,
                             XkbSectionRec.sizeof, &_XkbClearSection);
    return;
}

/***====================================================================***/

private void _XkbClearDoodad(char* doodad_in)
{
    XkbDoodadPtr doodad = cast(XkbDoodadPtr) doodad_in;

    switch (doodad.any.type) {
    case XkbTextDoodad:
    {
        free(doodad.text.text);
        doodad.text.text = null;
        free(doodad.text.font);
        doodad.text.font = null;
    }
        break;
    case XkbLogoDoodad:
    {
        free(doodad.logo.logo_name);
        doodad.logo.logo_name = null;
    }
        break;
    default: break;}
    return;
}

void XkbFreeGeomDoodads(XkbDoodadPtr doodads, int nDoodads, Bool freeAll)
{
    int i = void;
    XkbDoodadPtr doodad = void;

    if (doodads) {
        for (i = 0, doodad = doodads; i < nDoodads; i++, doodad++) {
            _XkbClearDoodad(cast(char*) doodad);
        }
        if (freeAll)
            free(doodads);
    }
    return;
}

void XkbFreeGeometry(XkbGeometryPtr geom, uint which, Bool freeMap)
{
    if (geom is null)
        return;
    if (freeMap)
        which = XkbGeomAllMask;
    if ((which & XkbGeomPropertiesMask) && (geom.properties !is null))
        XkbFreeGeomProperties(geom, 0, geom.num_properties, TRUE);
    if ((which & XkbGeomColorsMask) && (geom.colors !is null))
        XkbFreeGeomColors(geom, 0, geom.num_colors, TRUE);
    if ((which & XkbGeomShapesMask) && (geom.shapes !is null))
        XkbFreeGeomShapes(geom, 0, geom.num_shapes, TRUE);
    if ((which & XkbGeomSectionsMask) && (geom.sections !is null))
        XkbFreeGeomSections(geom, 0, geom.num_sections, TRUE);
    if ((which & XkbGeomDoodadsMask) && (geom.doodads !is null)) {
        XkbFreeGeomDoodads(geom.doodads, geom.num_doodads, TRUE);
        geom.doodads = null;
        geom.num_doodads = geom.sz_doodads = 0;
    }
    if ((which & XkbGeomKeyAliasesMask) && (geom.key_aliases !is null))
        XkbFreeGeomKeyAliases(geom, 0, geom.num_key_aliases, TRUE);
    if (freeMap) {
        free(geom.label_font);
        geom.label_font = null;
        free(geom);
    }
    return;
}

/***====================================================================***/

/**
 * Resize and clear an XKB geometry item array. The array size may
 * grow or shrink unlike in _XkbGeomAlloc.
 *
 * @param buffer[in,out]  buffer to reallocate and clear
 * @param szItems[in]     currently allocated item count for "buffer"
 * @param nrItems[in]     required item count for "buffer"
 * @param itemSize[in]    size of a single item in "buffer"
 * @param clearance[in]   items to clear after reallocation
 *
 * @see _XkbGeomAlloc
 *
 * @return TRUE if reallocation succeeded. Otherwise FALSE is returned
 *         and contents of "buffer" aren't touched.
 */
Bool XkbGeomRealloc(void** buffer, int szItems, int nrItems, int itemSize, XkbGeomClearance clearance)
{
    void* items = void;
    int clearBegin = void;

    /* Check validity of arguments. */
    if (!buffer)
        return FALSE;
    items = *buffer;
    if (!((items && (szItems > 0)) || (!items && !szItems)))
        return FALSE;
    /* Check if there is need to resize. */
    if (nrItems != szItems)
        if (((items = reallocarray(items, nrItems, itemSize)) is null))
            return FALSE;
    /* Clear specified items to zero. */
    switch (clearance) {
    case XKB_GEOM_CLEAR_EXCESS:
        clearBegin = szItems;
        break;
    case XKB_GEOM_CLEAR_ALL:
        clearBegin = 0;
        break;
    case XKB_GEOM_CLEAR_NONE:
    default:
        clearBegin = nrItems;
        break;
    }
    if (items && (clearBegin < nrItems))
        memset(cast(char*) items + (clearBegin * itemSize), 0,
               (nrItems - clearBegin) * itemSize);
    *buffer = items;
    return TRUE;
}

private Status _XkbGeomAlloc(void** old, ushort* num, ushort* total, int num_new, size_t sz_elem)
{
    if (num_new < 1)
        return Success;
    if ((*old) is null)
        *num = *total = 0;

    if ((*num) + num_new <= (*total))
        return Success;

    *total = cast(ushort)((*num) + num_new);

    if (!XkbGeomRealloc(old, *num, *total, cast(uint)sz_elem, XKB_GEOM_CLEAR_EXCESS)) {
        free(*old);
        (*old) = null;
        *total = *num = 0;
        return BadAlloc;
    }

    return Success;
}

enum string	_XkbAllocProps(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).properties,
				&(` ~ g ~ `).num_properties,&(` ~ g ~ `).sz_properties,
				(` ~ n ~ `),XkbPropertyRec.sizeof)`;
enum string	_XkbAllocColors(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).colors,
				&(` ~ g ~ `).num_colors,&(` ~ g ~ `).sz_colors,
				(` ~ n ~ `),XkbColorRec.sizeof)`;
enum string	_XkbAllocShapes(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).shapes,
				&(` ~ g ~ `).num_shapes,&(` ~ g ~ `).sz_shapes,
				(` ~ n ~ `),XkbShapeRec.sizeof)`;
enum string	_XkbAllocSections(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).sections,
				&(` ~ g ~ `).num_sections,&(` ~ g ~ `).sz_sections,
				(` ~ n ~ `),XkbSectionRec.sizeof)`;
enum string	_XkbAllocDoodads(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).doodads,
				&(` ~ g ~ `).num_doodads,&(` ~ g ~ `).sz_doodads,
				(` ~ n ~ `),XkbDoodadRec.sizeof)`;
enum string	_XkbAllocKeyAliases(string g,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ g ~ `).key_aliases,
				&(` ~ g ~ `).num_key_aliases,&(` ~ g ~ `).sz_key_aliases,
				(` ~ n ~ `),XkbKeyAliasRec.sizeof)`;

enum string	_XkbAllocOutlines(string s,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ s ~ `).outlines,
				&(` ~ s ~ `).num_outlines,&(` ~ s ~ `).sz_outlines,
				(` ~ n ~ `),XkbOutlineRec.sizeof)`;
enum string	_XkbAllocRows(string s,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ s ~ `).rows,
				&(` ~ s ~ `).num_rows,&(` ~ s ~ `).sz_rows,
				(` ~ n ~ `),XkbRowRec.sizeof)`;
enum string	_XkbAllocPoints(string o,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ o ~ `).points,
				&(` ~ o ~ `).num_points,&(` ~ o ~ `).sz_points,
				(` ~ n ~ `),XkbPointRec.sizeof)`;
enum string	_XkbAllocKeys(string r,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ r ~ `).keys,
				&(` ~ r ~ `).num_keys,&(` ~ r ~ `).sz_keys,
				(` ~ n ~ `),XkbKeyRec.sizeof)`;
enum string	_XkbAllocOverlays(string s,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ s ~ `).overlays,
				&(` ~ s ~ `).num_overlays,&(` ~ s ~ `).sz_overlays,
				(` ~ n ~ `),XkbOverlayRec.sizeof)`;
enum string	_XkbAllocOverlayRows(string o,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ o ~ `).rows,
				&(` ~ o ~ `).num_rows,&(` ~ o ~ `).sz_rows,
				(` ~ n ~ `),XkbOverlayRowRec.sizeof)`;
enum string	_XkbAllocOverlayKeys(string r,string n) = `_XkbGeomAlloc(cast(void**)&(` ~ r ~ `).keys,
				&(` ~ r ~ `).num_keys,&(` ~ r ~ `).sz_keys,
				(` ~ n ~ `),XkbOverlayKeyRec.sizeof)`;

Status XkbAllocGeometry(XkbDescPtr xkb, XkbGeometrySizesPtr sizes)
{
    XkbGeometryPtr geom = void;
    Status rtrn = void;

    if (xkb.geom is null) {
        xkb.geom = cast(XkbGeometryRec*) calloc(1, XkbGeometryRec.sizeof);
        if (!xkb.geom)
            return BadAlloc;
    }
    geom = xkb.geom;
    if ((sizes.which & XkbGeomPropertiesMask) &&
        ((rtrn = mixin(_XkbAllocProps!(`geom`, `sizes.num_properties`))) != Success)) {
        goto BAIL;
    }
    if ((sizes.which & XkbGeomColorsMask) &&
        ((rtrn = mixin(_XkbAllocColors!(`geom`, `sizes.num_colors`))) != Success)) {
        goto BAIL;
    }
    if ((sizes.which & XkbGeomShapesMask) &&
        ((rtrn = mixin(_XkbAllocShapes!(`geom`, `sizes.num_shapes`))) != Success)) {
        goto BAIL;
    }
    if ((sizes.which & XkbGeomSectionsMask) &&
        ((rtrn = mixin(_XkbAllocSections!(`geom`, `sizes.num_sections`))) != Success)) {
        goto BAIL;
    }
    if ((sizes.which & XkbGeomDoodadsMask) &&
        ((rtrn = mixin(_XkbAllocDoodads!(`geom`, `sizes.num_doodads`))) != Success)) {
        goto BAIL;
    }
    if ((sizes.which & XkbGeomKeyAliasesMask) &&
        ((rtrn =
          mixin(_XkbAllocKeyAliases!(`geom`, `sizes.num_key_aliases`))) != Success)) {
        goto BAIL;
    }
    return Success;
 BAIL:
    XkbFreeGeometry(geom, XkbGeomAllMask, TRUE);
    xkb.geom = null;
    return rtrn;
}

/***====================================================================***/

XkbPropertyPtr XkbAddGeomProperty(XkbGeometryPtr geom, char* name, char* value)
{
    int i = void;
    XkbPropertyPtr prop = void;

    if ((!geom) || (!name) || (!value))
        return null;
    for (i = 0, prop = geom.properties; i < geom.num_properties; i++, prop++) {
        if ((prop.name) && (strcmp(name, prop.name) == 0)) {
            free(prop.value);
            if (((prop.value = strdup(value)) is null))
                return null;
            return prop;
        }
    }
    if ((geom.num_properties >= geom.sz_properties) &&
        (mixin(_XkbAllocProps!(`geom`, `1`)) != Success)) {
        return null;
    }
    prop = &geom.properties[geom.num_properties];
    prop.name = strdup(name);
    if (!prop.name)
        return null;
    prop.value = strdup(value);
    if (!prop.value) {
        free(prop.name);
        prop.name = null;
        return null;
    }
    geom.num_properties++;
    return prop;
}

XkbKeyAliasPtr XkbAddGeomKeyAlias(XkbGeometryPtr geom, char* aliasStr, char* realStr)
{
    int i = void;
    XkbKeyAliasPtr alias_ = void;

    if ((!geom) || (!aliasStr) || (!realStr) || (!aliasStr[0]) || (!realStr[0]))
        return null;
    for (i = 0, alias_ = geom.key_aliases; i < geom.num_key_aliases;
         i++, alias_++) {
        if (strncmp(alias_.alias_.ptr, aliasStr, XkbKeyNameLength) == 0) {
            memset(alias_.real_.ptr, 0, XkbKeyNameLength);
            memcpy(alias_.real_.ptr, realStr, strnlen(realStr, XkbKeyNameLength));
            return alias_;
        }
    }
    if ((geom.num_key_aliases >= geom.sz_key_aliases) &&
        (mixin(_XkbAllocKeyAliases!(`geom`, `1`)) != Success)) {
        return null;
    }
    alias_ = &geom.key_aliases[geom.num_key_aliases];
    memset(alias_, 0, XkbKeyAliasRec.sizeof);
    memcpy(alias_.alias_.ptr, aliasStr, strnlen(aliasStr, XkbKeyNameLength));
    memcpy(alias_.real_.ptr, realStr, strnlen(realStr, XkbKeyNameLength));
    geom.num_key_aliases++;
    return alias_;
}

XkbColorPtr XkbAddGeomColor(XkbGeometryPtr geom, char* spec, uint pixel)
{
    int i = void;
    XkbColorPtr color = void;

    if ((!geom) || (!spec))
        return null;
    for (i = 0, color = geom.colors; i < geom.num_colors; i++, color++) {
        if ((color.spec) && (strcmp(color.spec, spec) == 0)) {
            color.pixel = pixel;
            return color;
        }
    }
    if ((geom.num_colors >= geom.sz_colors) &&
        (mixin(_XkbAllocColors!(`geom`, `1`)) != Success)) {
        return null;
    }
    color = &geom.colors[geom.num_colors];
    color.pixel = pixel;
    color.spec = strdup(spec);
    if (!color.spec)
        return null;
    geom.num_colors++;
    return color;
}

XkbOutlinePtr XkbAddGeomOutline(XkbShapePtr shape, int sz_points)
{
    XkbOutlinePtr outline = void;

    if ((!shape) || (sz_points < 0))
        return null;
    if ((shape.num_outlines >= shape.sz_outlines) &&
        (mixin(_XkbAllocOutlines!(`shape`, `1`)) != Success)) {
        return null;
    }
    outline = &shape.outlines[shape.num_outlines];
    memset(outline, 0, XkbOutlineRec.sizeof);
    if ((sz_points > 0) && (mixin(_XkbAllocPoints!(`outline`, `sz_points`)) != Success))
        return null;
    shape.num_outlines++;
    return outline;
}

XkbShapePtr XkbAddGeomShape(XkbGeometryPtr geom, Atom name, int sz_outlines)
{
    XkbShapePtr shape = void;
    int i = void;

    if ((!geom) || (!name) || (sz_outlines < 0))
        return null;
    if (geom.num_shapes > 0) {
        for (shape = geom.shapes, i = 0; i < geom.num_shapes; i++, shape++) {
            if (name == shape.name)
                return shape;
        }
    }
    if ((geom.num_shapes >= geom.sz_shapes) &&
        (mixin(_XkbAllocShapes!(`geom`, `1`)) != Success))
        return null;
    shape = &geom.shapes[geom.num_shapes];
    memset(shape, 0, XkbShapeRec.sizeof);
    if ((sz_outlines > 0) && (mixin(_XkbAllocOutlines!(`shape`, `sz_outlines`)) != Success))
        return null;
    shape.name = name;
    shape.primary = shape.approx = null;
    geom.num_shapes++;
    return shape;
}

XkbKeyPtr XkbAddGeomKey(XkbRowPtr row)
{
    XkbKeyPtr key = void;

    if (!row)
        return null;
    if ((row.num_keys >= row.sz_keys) && (mixin(_XkbAllocKeys!(`row`, `1`)) != Success))
        return null;
    key = &row.keys[row.num_keys++];
    memset(key, 0, XkbKeyRec.sizeof);
    return key;
}

XkbRowPtr XkbAddGeomRow(XkbSectionPtr section, int sz_keys)
{
    XkbRowPtr row = void;

    if ((!section) || (sz_keys < 0))
        return null;
    if ((section.num_rows >= section.sz_rows) &&
        (mixin(_XkbAllocRows!(`section`, `1`)) != Success))
        return null;
    row = &section.rows[section.num_rows];
    memset(row, 0, XkbRowRec.sizeof);
    if ((sz_keys > 0) && (mixin(_XkbAllocKeys!(`row`, `sz_keys`)) != Success))
        return null;
    section.num_rows++;
    return row;
}

XkbSectionPtr XkbAddGeomSection(XkbGeometryPtr geom, Atom name, int sz_rows, int sz_doodads, int sz_over)
{
    int i = void;
    XkbSectionPtr section = void;

    if ((!geom) || (name == None) || (sz_rows < 0))
        return null;
    for (i = 0, section = geom.sections; i < geom.num_sections;
         i++, section++) {
        if (section.name != name)
            continue;
        if (((sz_rows > 0) && (mixin(_XkbAllocRows!(`section`, `sz_rows`)) != Success)) ||
            ((sz_doodads > 0) &&
             (mixin(_XkbAllocDoodads!(`section`, `sz_doodads`)) != Success)) ||
            ((sz_over > 0) && (mixin(_XkbAllocOverlays!(`section`, `sz_over`)) != Success)))
            return null;
        return section;
    }
    if ((geom.num_sections >= geom.sz_sections) &&
        (mixin(_XkbAllocSections!(`geom`, `1`)) != Success))
        return null;
    section = &geom.sections[geom.num_sections];
    if ((sz_rows > 0) && (mixin(_XkbAllocRows!(`section`, `sz_rows`)) != Success))
        return null;
    if ((sz_doodads > 0) && (mixin(_XkbAllocDoodads!(`section`, `sz_doodads`)) != Success)) {
        if (section.rows) {
            free(section.rows);
            section.rows = null;
            section.sz_rows = section.num_rows = 0;
        }
        return null;
    }
    section.name = name;
    geom.num_sections++;
    return section;
}

XkbDoodadPtr XkbAddGeomDoodad(XkbGeometryPtr geom, XkbSectionPtr section, Atom name)
{
    XkbDoodadPtr old = void, doodad = void;
    int i = void, nDoodads = void;

    if ((!geom) || (name == None))
        return null;
    if ((section !is null) && (section.num_doodads > 0)) {
        old = section.doodads;
        nDoodads = section.num_doodads;
    }
    else {
        old = geom.doodads;
        nDoodads = geom.num_doodads;
    }
    for (i = 0, doodad = old; i < nDoodads; i++, doodad++) {
        if (doodad.any.name == name)
            return doodad;
    }
    if (section) {
        if ((section.num_doodads >= section.sz_doodads) &&
            (mixin(_XkbAllocDoodads!(`section`, `1`)) != Success)) {
            return null;
        }
        doodad = &section.doodads[section.num_doodads++];
    }
    else {
        if ((geom.num_doodads >= geom.sz_doodads) &&
            (mixin(_XkbAllocDoodads!(`geom`, `1`)) != Success))
            return null;
        doodad = &geom.doodads[geom.num_doodads++];
    }
    memset(doodad, 0, XkbDoodadRec.sizeof);
    doodad.any.name = name;
    return doodad;
}

XkbOverlayKeyPtr XkbAddGeomOverlayKey(XkbOverlayPtr overlay, XkbOverlayRowPtr row, char* over, char* under)
{
    int i = void;
    XkbOverlayKeyPtr key = void;
    XkbSectionPtr section = void;
    XkbRowPtr row_under = void;
    Bool found = void;

    if ((!overlay) || (!row) || (!over) || (!under))
        return null;
    section = overlay.section_under;
    if (row.row_under >= section.num_rows)
        return null;
    row_under = &section.rows[row.row_under];
    for (i = 0, found = FALSE; i < row_under.num_keys; i++) {
        if (strncmp(under, row_under.keys[i].name.name.ptr, XkbKeyNameLength) == 0) {
            found = TRUE;
            break;
        }
    }
    if (!found)
        return null;
    if ((row.num_keys >= row.sz_keys) &&
        (mixin(_XkbAllocOverlayKeys!(`row`, `1`)) != Success))
        return null;
    key = &row.keys[row.num_keys];
    memcpy(key.under.name.ptr, under, strnlen(under, XkbKeyNameLength));
    memcpy(key.over.name.ptr, over, strnlen(over, XkbKeyNameLength));
    row.num_keys++;
    return key;
}

XkbOverlayRowPtr XkbAddGeomOverlayRow(XkbOverlayPtr overlay, int row_under, int sz_keys)
{
    int i = void;
    XkbOverlayRowPtr row = void;

    if ((!overlay) || (sz_keys < 0))
        return null;
    if (row_under >= overlay.section_under.num_rows)
        return null;
    for (i = 0; i < overlay.num_rows; i++) {
        if (overlay.rows[i].row_under == row_under) {
            row = &overlay.rows[i];
            if ((row.sz_keys < sz_keys) &&
                (mixin(_XkbAllocOverlayKeys!(`row`, `sz_keys`)) != Success)) {
                return null;
            }
            return &overlay.rows[i];
        }
    }
    if ((overlay.num_rows >= overlay.sz_rows) &&
        (mixin(_XkbAllocOverlayRows!(`overlay`, `1`)) != Success))
        return null;
    row = &overlay.rows[overlay.num_rows];
    memset(row, 0, XkbOverlayRowRec.sizeof);
    if ((sz_keys > 0) && (mixin(_XkbAllocOverlayKeys!(`row`, `sz_keys`)) != Success))
        return null;
    row.row_under = cast(ushort)row_under;
    overlay.num_rows++;
    return row;
}

XkbOverlayPtr XkbAddGeomOverlay(XkbSectionPtr section, Atom name, int sz_rows)
{
    int i = void;
    XkbOverlayPtr overlay = void;

    if ((!section) || (name == None) || (sz_rows == 0))
        return null;

    for (i = 0, overlay = section.overlays; i < section.num_overlays;
         i++, overlay++) {
        if (overlay.name == name) {
            if ((sz_rows > 0) &&
                (mixin(_XkbAllocOverlayRows!(`overlay`, `sz_rows`)) != Success))
                return null;
            return overlay;
        }
    }
    if ((section.num_overlays >= section.sz_overlays) &&
        (mixin(_XkbAllocOverlays!(`section`, `1`)) != Success))
        return null;
    overlay = &section.overlays[section.num_overlays];
    if ((sz_rows > 0) && (mixin(_XkbAllocOverlayRows!(`overlay`, `sz_rows`)) != Success))
        return null;
    overlay.name = name;
    overlay.section_under = section;
    section.num_overlays++;
    return overlay;
}
