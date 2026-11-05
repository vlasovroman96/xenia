module xkb.xkbgeom_priv;
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

 
//public import x11.Xdefs;

public import xkb.xkbsrv_priv;
import xkb.xkbstr;
// import externs.X11.extensions.XKBgeom;



struct _XkbProperty {
    char* name;
    char* value;
}alias XkbPropertyRec = _XkbProperty;
alias XkbPropertyPtr = _XkbProperty*;

struct _XkbColor {
    uint pixel;
    char* spec;
}alias XkbColorRec = _XkbColor;
alias XkbColorPtr = _XkbColor*;

struct _XkbPoint {
    short x;
    short y;
}alias XkbPointRec = _XkbPoint;
alias XkbPointPtr = _XkbPoint*;

struct _XkbBounds {
    short x1, y1;
    short x2, y2;
}alias XkbBoundsRec = _XkbBounds;
alias XkbBoundsPtr = _XkbBounds*;

struct _XkbOutline {
    ushort num_points;
    ushort sz_points;
    ushort corner_radius;
    XkbPointPtr points;
}alias XkbOutlineRec = _XkbOutline;
alias XkbOutlinePtr = _XkbOutline*;

struct _XkbShape {
    Atom name;
    ushort num_outlines;
    ushort sz_outlines;
    XkbOutlinePtr outlines;
    XkbOutlinePtr approx;
    XkbOutlinePtr primary;
    XkbBoundsRec bounds;
}alias XkbShapeRec = _XkbShape;
alias XkbShapePtr = _XkbShape*;

enum string	XkbOutlineIndex(string s,string o) = `(cast(int)((` ~ o ~ `)-&(` ~ s ~ `).outlines[0]))`;

struct _XkbShapeDoodad {
    Atom name;
    ubyte type;
    ubyte priority;
    short top;
    short left;
    short angle;
    ushort color_ndx;
    ushort shape_ndx;
}alias XkbShapeDoodadRec = _XkbShapeDoodad;
alias XkbShapeDoodadPtr = _XkbShapeDoodad*;

enum string	XkbShapeDoodadColor(string g,string d) = `(&(` ~ g ~ `).colors[(` ~ d ~ `).color_ndx])`;
enum string	XkbShapeDoodadShape(string g,string d) = `(&(` ~ g ~ `).shapes[(` ~ d ~ `).shape_ndx])`;

struct _XkbTextDoodad {
    Atom name;
    ubyte type;
    ubyte priority;
    short top;
    short left;
    short angle;
    short width;
    short height;
    ushort color_ndx;
    char* text;
    char* font;
}alias XkbTextDoodadRec = _XkbTextDoodad;
alias XkbTextDoodadPtr = _XkbTextDoodad*;

enum string	XkbTextDoodadColor(string g,string d) = `(&(` ~ g ~ `).colors[(` ~ d ~ `).color_ndx])`;

struct _XkbIndicatorDoodad {
    Atom name;
    ubyte type;
    ubyte priority;
    short top;
    short left;
    short angle;
    ushort shape_ndx;
    ushort on_color_ndx;
    ushort off_color_ndx;
}alias XkbIndicatorDoodadRec = _XkbIndicatorDoodad;
alias XkbIndicatorDoodadPtr = _XkbIndicatorDoodad*;

enum string	XkbIndicatorDoodadShape(string g,string d) = `(&(` ~ g ~ `).shapes[(` ~ d ~ `).shape_ndx])`;
enum string	XkbIndicatorDoodadOnColor(string g,string d) = `(&(` ~ g ~ `).colors[(` ~ d ~ `).on_color_ndx])`;
enum string	XkbIndicatorDoodadOffColor(string g,string d) = `(&(` ~ g ~ `).colors[(` ~ d ~ `).off_color_ndx])`;

struct _XkbLogoDoodad {
    Atom name;
    ubyte type;
    ubyte priority;
    short top;
    short left;
    short angle;
    ushort color_ndx;
    ushort shape_ndx;
    char* logo_name;
}alias XkbLogoDoodadRec = _XkbLogoDoodad;
alias XkbLogoDoodadPtr = _XkbLogoDoodad*;

enum string	XkbLogoDoodadColor(string g,string d) = `(&(` ~ g ~ `).colors[(` ~ d ~ `).color_ndx])`;
enum string	XkbLogoDoodadShape(string g,string d) = `(&(` ~ g ~ `).shapes[(` ~ d ~ `).shape_ndx])`;

struct _XkbAnyDoodad {
    Atom name;
    ubyte type;
    ubyte priority;
    short top;
    short left;
    short angle;
}alias XkbAnyDoodadRec = _XkbAnyDoodad;
alias XkbAnyDoodadPtr = _XkbAnyDoodad*;

union _XkbDoodad {
    XkbAnyDoodadRec any;
    XkbShapeDoodadRec shape;
    XkbTextDoodadRec text;
    XkbIndicatorDoodadRec indicator;
    XkbLogoDoodadRec logo;
}
alias XkbDoodadRec = _XkbDoodad;
alias XkbDoodadPtr = _XkbDoodad*;

enum	XkbUnknownDoodad =	0;
enum	XkbOutlineDoodad =	1;
enum	XkbSolidDoodad =		2;
enum	XkbTextDoodad =		3;
enum	XkbIndicatorDoodad =	4;
enum	XkbLogoDoodad =		5;

struct _XkbKey {
    XkbKeyNameRec name;
    short gap;
    ubyte shape_ndx;
    ubyte color_ndx;
}alias XkbKeyRec = _XkbKey;
alias XkbKeyPtr = _XkbKey*;

enum string	XkbKeyShape(string g,string k) = `(&(` ~ g ~ `).shapes[(` ~ k ~ `).shape_ndx])`;
enum string	XkbKeyColor(string g,string k) = `(&(` ~ g ~ `).colors[(` ~ k ~ `).color_ndx])`;

struct _XkbRow {
    short top;
    short left;
    ushort num_keys;
    ushort sz_keys;
    int vertical;
    XkbKeyPtr keys;
    XkbBoundsRec bounds;
}alias XkbRowRec = _XkbRow;
alias XkbRowPtr = _XkbRow*;

struct _XkbSection {
    Atom name;
    ubyte priority;
    short top;
    short left;
    ushort width;
    ushort height;
    short angle;
    ushort num_rows;
    ushort num_doodads;
    ushort num_overlays;
    ushort sz_rows;
    ushort sz_doodads;
    ushort sz_overlays;
    XkbRowPtr rows;
    XkbDoodadPtr doodads;
    XkbBoundsRec bounds;
    _XkbOverlay* overlays;
}alias XkbSectionRec = _XkbSection;
alias XkbSectionPtr = _XkbSection*;

struct _XkbOverlayKey {
    XkbKeyNameRec over;
    XkbKeyNameRec under;
}alias XkbOverlayKeyRec = _XkbOverlayKey;
alias XkbOverlayKeyPtr = _XkbOverlayKey*;

struct _XkbOverlayRow {
    ushort row_under;
    ushort num_keys;
    ushort sz_keys;
    XkbOverlayKeyPtr keys;
}alias XkbOverlayRowRec = _XkbOverlayRow;
alias XkbOverlayRowPtr = _XkbOverlayRow*;

struct _XkbOverlay {
    Atom name;
    XkbSectionPtr section_under;
    ushort num_rows;
    ushort sz_rows;
    XkbOverlayRowPtr rows;
    XkbBoundsPtr bounds;
}alias XkbOverlayRec = _XkbOverlay;
alias XkbOverlayPtr = _XkbOverlay*;

// struct XkbGeometryRec {
//     Atom name;
//     ushort width_mm;
//     ushort height_mm;
//     char* label_font;
//     XkbColorPtr label_color;
//     XkbColorPtr base_color;
//     ushort sz_properties;
//     ushort sz_colors;
//     ushort sz_shapes;
//     ushort sz_sections;
//     ushort sz_doodads;
//     ushort sz_key_aliases;
//     ushort num_properties;
//     ushort num_colors;
//     ushort num_shapes;
//     ushort num_sections;
//     ushort num_doodads;
//     ushort num_key_aliases;
//     XkbPropertyPtr properties;
//     XkbColorPtr colors;
//     XkbShapePtr shapes;
//     XkbSectionPtr sections;
//     XkbDoodadPtr doodads;
//     XkbKeyAliasPtr key_aliases;
// }

enum string	XkbGeomColorIndex(string g,string c) = `(cast(int)((` ~ c ~ `)-&(` ~ g ~ `).colors[0]))`;

enum	XkbGeomPropertiesMask =	(1<<0);
enum	XkbGeomColorsMask =	(1<<1);
enum	XkbGeomShapesMask =	(1<<2);
enum	XkbGeomSectionsMask =	(1<<3);
enum	XkbGeomDoodadsMask =	(1<<4);
enum	XkbGeomKeyAliasesMask =	(1<<5);
enum	XkbGeomAllMask =		(0x3f);

struct _XkbGeometrySizes {
    uint which;
    ushort num_properties;
    ushort num_colors;
    ushort num_shapes;
    ushort num_sections;
    ushort num_doodads;
    ushort num_key_aliases;
}alias XkbGeometrySizesRec = _XkbGeometrySizes;
alias XkbGeometrySizesPtr = _XkbGeometrySizes*;

/**
 * Specifies which items should be cleared in an XKB geometry array
 * when the array is reallocated.
 */
enum XkbGeomClearance {
    XKB_GEOM_CLEAR_NONE,        /* Don't clear any items, just reallocate.   */
    XKB_GEOM_CLEAR_EXCESS,      /* Clear new extra items after reallocation. */
    XKB_GEOM_CLEAR_ALL          /* Clear all items after reallocation.       */
}
alias XKB_GEOM_CLEAR_NONE = XkbGeomClearance.XKB_GEOM_CLEAR_NONE;
alias XKB_GEOM_CLEAR_EXCESS = XkbGeomClearance.XKB_GEOM_CLEAR_EXCESS;
alias XKB_GEOM_CLEAR_ALL = XkbGeomClearance.XKB_GEOM_CLEAR_ALL;


// XkbPropertyPtr XkbAddGeomProperty(XkbGeometryPtr, char*, char*);

// XkbKeyAliasPtr XkbAddGeomKeyAlias(XkbGeometryPtr, char*, char*);

// XkbColorPtr XkbAddGeomColor(XkbGeometryPtr, char*, uint);

// XkbOutlinePtr XkbAddGeomOutline(XkbShapePtr, int);

// XkbShapePtr XkbAddGeomShape(XkbGeometryPtr, Atom, int);

// XkbKeyPtr XkbAddGeomKey(XkbRowPtr);

// XkbRowPtr XkbAddGeomRow(XkbSectionPtr, int);

// XkbSectionPtr XkbAddGeomSection(XkbGeometryPtr, Atom, int, int, int);

// XkbOverlayPtr XkbAddGeomOverlay(XkbSectionPtr, Atom, int);

// XkbOverlayRowPtr XkbAddGeomOverlayRow(XkbOverlayPtr, int, int);

// XkbOverlayKeyPtr XkbAddGeomOverlayKey(XkbOverlayPtr, XkbOverlayRowPtr, char*, char*);

// XkbDoodadPtr XkbAddGeomDoodad(XkbGeometryPtr, XkbSectionPtr, Atom);

void XkbFreeGeomKeyAliases(XkbGeometryPtr, int, int, Bool);

void XkbFreeGeomColors(XkbGeometryPtr, int, int, Bool);

void XkbFreeGeomDoodads(XkbDoodadPtr, int, Bool);

void XkbFreeGeomProperties(XkbGeometryPtr, int, int, Bool);

void XkbFreeGeomKeys(XkbRowPtr, int, int, Bool);

void XkbFreeGeomRows(XkbSectionPtr, int, int, Bool);

void XkbFreeGeomSections(XkbGeometryPtr, int, int, Bool);

void XkbFreeGeomPoints(XkbOutlinePtr, int, int, Bool);

void XkbFreeGeomOutlines(XkbShapePtr, int, int, Bool);

void XkbFreeGeomShapes(XkbGeometryPtr, int, int, Bool);

// void XkbFreeGeometry(XkbGeometryPtr, uint, Bool);

// Bool XkbGeomRealloc(void**, int, int, int, XkbGeomClearance);

// Status XkbAllocGeometry(XkbDescPtr, XkbGeometrySizesPtr);

                          /* _XKBGEOM_H_ */
