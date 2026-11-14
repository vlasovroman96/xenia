/* THIS IS A GENERATED FILE
 *
 * Do not change! Changing this file implies a protocol change!
 */
 extern(C): @nogc: nothrow:
import dix.atom;
import os.log;;

import externs.X11.Xatom;
import dix.globals;

void MakePredeclaredAtoms()
{
    // if (atomMgr.makeAtom("mandatory", 9, 1) != XA_mandatory)
    //     FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("PRIMARY", 7, 1) != XA_PRIMARY)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("SECONDARY", 9, 1) != XA_SECONDARY)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("ARC", 3, 1) != XA_ARC)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("ATOM", 4, 1) != XA_ATOM)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("BITMAP", 6, 1) != XA_BITMAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CARDINAL", 8, 1) != XA_CARDINAL)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("COLORMAP", 8, 1) != XA_COLORMAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CURSOR", 6, 1) != XA_CURSOR)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER0", 11, 1) != XA_CUT_BUFFER0)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER1", 11, 1) != XA_CUT_BUFFER1)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER2", 11, 1) != XA_CUT_BUFFER2)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER3", 11, 1) != XA_CUT_BUFFER3)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER4", 11, 1) != XA_CUT_BUFFER4)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER5", 11, 1) != XA_CUT_BUFFER5)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER6", 11, 1) != XA_CUT_BUFFER6)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CUT_BUFFER7", 11, 1) != XA_CUT_BUFFER7)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("DRAWABLE", 8, 1) != XA_DRAWABLE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("FONT", 4, 1) != XA_FONT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("INTEGER", 7, 1) != XA_INTEGER)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("PIXMAP", 6, 1) != XA_PIXMAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("POINT", 5, 1) != XA_POINT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RECTANGLE", 9, 1) != XA_RECTANGLE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RESOURCE_MANAGER", 16, 1) != XA_RESOURCE_MANAGER)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_COLOR_MAP", 13, 1) != XA_RGB_COLOR_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_BEST_MAP", 12, 1) != XA_RGB_BEST_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_BLUE_MAP", 12, 1) != XA_RGB_BLUE_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_DEFAULT_MAP", 15, 1) != XA_RGB_DEFAULT_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_GRAY_MAP", 12, 1) != XA_RGB_GRAY_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_GREEN_MAP", 13, 1) != XA_RGB_GREEN_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RGB_RED_MAP", 11, 1) != XA_RGB_RED_MAP)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("STRING", 6, 1) != XA_STRING)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("VISUALID", 8, 1) != XA_VISUALID)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WINDOW", 6, 1) != XA_WINDOW)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_COMMAND", 10, 1) != XA_WM_COMMAND)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_HINTS", 8, 1) != XA_WM_HINTS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_CLIENT_MACHINE", 17, 1) != XA_WM_CLIENT_MACHINE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_ICON_NAME", 12, 1) != XA_WM_ICON_NAME)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_ICON_SIZE", 12, 1) != XA_WM_ICON_SIZE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_NAME", 7, 1) != XA_WM_NAME)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_NORMAL_HINTS", 15, 1) != XA_WM_NORMAL_HINTS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_SIZE_HINTS", 13, 1) != XA_WM_SIZE_HINTS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_ZOOM_HINTS", 13, 1) != XA_WM_ZOOM_HINTS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("MIN_SPACE", 9, 1) != XA_MIN_SPACE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("NORM_SPACE", 10, 1) != XA_NORM_SPACE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("MAX_SPACE", 9, 1) != XA_MAX_SPACE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("END_SPACE", 9, 1) != XA_END_SPACE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("SUPERSCRIPT_X", 13, 1) != XA_SUPERSCRIPT_X)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("SUPERSCRIPT_Y", 13, 1) != XA_SUPERSCRIPT_Y)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("SUBSCRIPT_X", 11, 1) != XA_SUBSCRIPT_X)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("SUBSCRIPT_Y", 11, 1) != XA_SUBSCRIPT_Y)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("UNDERLINE_POSITION", 18, 1) != XA_UNDERLINE_POSITION)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("UNDERLINE_THICKNESS", 19, 1) != XA_UNDERLINE_THICKNESS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("STRIKEOUT_ASCENT", 16, 1) != XA_STRIKEOUT_ASCENT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("STRIKEOUT_DESCENT", 17, 1) != XA_STRIKEOUT_DESCENT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("ITALIC_ANGLE", 12, 1) != XA_ITALIC_ANGLE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("X_HEIGHT", 8, 1) != XA_X_HEIGHT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("QUAD_WIDTH", 10, 1) != XA_QUAD_WIDTH)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WEIGHT", 6, 1) != XA_WEIGHT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("POINT_SIZE", 10, 1) != XA_POINT_SIZE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("RESOLUTION", 10, 1) != XA_RESOLUTION)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("COPYRIGHT", 9, 1) != XA_COPYRIGHT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("NOTICE", 6, 1) != XA_NOTICE)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("FONT_NAME", 9, 1) != XA_FONT_NAME)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("FAMILY_NAME", 11, 1) != XA_FAMILY_NAME)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("FULL_NAME", 9, 1) != XA_FULL_NAME)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("CAP_HEIGHT", 10, 1) != XA_CAP_HEIGHT)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_CLASS", 8, 1) != XA_WM_CLASS)
        FatalError("Adding builtin atom");
    if (atomMgr.makeAtom("WM_TRANSIENT_FOR", 16, 1) != XA_WM_TRANSIENT_FOR)
        FatalError("Adding builtin atom");
}
