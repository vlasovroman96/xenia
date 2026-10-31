/* THIS IS A GENERATED FILE
 *
 * Do not change! Changing this file implies a protocol change!
 */
 extern(C): @nogc: nothrow:
import dix.atom;
import os.log;;

import externs.X11.Xatom;

void MakePredeclaredAtoms()
{
    // if (MakeAtom("mandatory", 9, 1) != XA_mandatory)
    //     FatalError("Adding builtin atom");
    if (MakeAtom("PRIMARY", 7, 1) != XA_PRIMARY)
        FatalError("Adding builtin atom");
    if (MakeAtom("SECONDARY", 9, 1) != XA_SECONDARY)
        FatalError("Adding builtin atom");
    if (MakeAtom("ARC", 3, 1) != XA_ARC)
        FatalError("Adding builtin atom");
    if (MakeAtom("ATOM", 4, 1) != XA_ATOM)
        FatalError("Adding builtin atom");
    if (MakeAtom("BITMAP", 6, 1) != XA_BITMAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("CARDINAL", 8, 1) != XA_CARDINAL)
        FatalError("Adding builtin atom");
    if (MakeAtom("COLORMAP", 8, 1) != XA_COLORMAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("CURSOR", 6, 1) != XA_CURSOR)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER0", 11, 1) != XA_CUT_BUFFER0)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER1", 11, 1) != XA_CUT_BUFFER1)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER2", 11, 1) != XA_CUT_BUFFER2)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER3", 11, 1) != XA_CUT_BUFFER3)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER4", 11, 1) != XA_CUT_BUFFER4)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER5", 11, 1) != XA_CUT_BUFFER5)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER6", 11, 1) != XA_CUT_BUFFER6)
        FatalError("Adding builtin atom");
    if (MakeAtom("CUT_BUFFER7", 11, 1) != XA_CUT_BUFFER7)
        FatalError("Adding builtin atom");
    if (MakeAtom("DRAWABLE", 8, 1) != XA_DRAWABLE)
        FatalError("Adding builtin atom");
    if (MakeAtom("FONT", 4, 1) != XA_FONT)
        FatalError("Adding builtin atom");
    if (MakeAtom("INTEGER", 7, 1) != XA_INTEGER)
        FatalError("Adding builtin atom");
    if (MakeAtom("PIXMAP", 6, 1) != XA_PIXMAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("POINT", 5, 1) != XA_POINT)
        FatalError("Adding builtin atom");
    if (MakeAtom("RECTANGLE", 9, 1) != XA_RECTANGLE)
        FatalError("Adding builtin atom");
    if (MakeAtom("RESOURCE_MANAGER", 16, 1) != XA_RESOURCE_MANAGER)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_COLOR_MAP", 13, 1) != XA_RGB_COLOR_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_BEST_MAP", 12, 1) != XA_RGB_BEST_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_BLUE_MAP", 12, 1) != XA_RGB_BLUE_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_DEFAULT_MAP", 15, 1) != XA_RGB_DEFAULT_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_GRAY_MAP", 12, 1) != XA_RGB_GRAY_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_GREEN_MAP", 13, 1) != XA_RGB_GREEN_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("RGB_RED_MAP", 11, 1) != XA_RGB_RED_MAP)
        FatalError("Adding builtin atom");
    if (MakeAtom("STRING", 6, 1) != XA_STRING)
        FatalError("Adding builtin atom");
    if (MakeAtom("VISUALID", 8, 1) != XA_VISUALID)
        FatalError("Adding builtin atom");
    if (MakeAtom("WINDOW", 6, 1) != XA_WINDOW)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_COMMAND", 10, 1) != XA_WM_COMMAND)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_HINTS", 8, 1) != XA_WM_HINTS)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_CLIENT_MACHINE", 17, 1) != XA_WM_CLIENT_MACHINE)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_ICON_NAME", 12, 1) != XA_WM_ICON_NAME)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_ICON_SIZE", 12, 1) != XA_WM_ICON_SIZE)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_NAME", 7, 1) != XA_WM_NAME)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_NORMAL_HINTS", 15, 1) != XA_WM_NORMAL_HINTS)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_SIZE_HINTS", 13, 1) != XA_WM_SIZE_HINTS)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_ZOOM_HINTS", 13, 1) != XA_WM_ZOOM_HINTS)
        FatalError("Adding builtin atom");
    if (MakeAtom("MIN_SPACE", 9, 1) != XA_MIN_SPACE)
        FatalError("Adding builtin atom");
    if (MakeAtom("NORM_SPACE", 10, 1) != XA_NORM_SPACE)
        FatalError("Adding builtin atom");
    if (MakeAtom("MAX_SPACE", 9, 1) != XA_MAX_SPACE)
        FatalError("Adding builtin atom");
    if (MakeAtom("END_SPACE", 9, 1) != XA_END_SPACE)
        FatalError("Adding builtin atom");
    if (MakeAtom("SUPERSCRIPT_X", 13, 1) != XA_SUPERSCRIPT_X)
        FatalError("Adding builtin atom");
    if (MakeAtom("SUPERSCRIPT_Y", 13, 1) != XA_SUPERSCRIPT_Y)
        FatalError("Adding builtin atom");
    if (MakeAtom("SUBSCRIPT_X", 11, 1) != XA_SUBSCRIPT_X)
        FatalError("Adding builtin atom");
    if (MakeAtom("SUBSCRIPT_Y", 11, 1) != XA_SUBSCRIPT_Y)
        FatalError("Adding builtin atom");
    if (MakeAtom("UNDERLINE_POSITION", 18, 1) != XA_UNDERLINE_POSITION)
        FatalError("Adding builtin atom");
    if (MakeAtom("UNDERLINE_THICKNESS", 19, 1) != XA_UNDERLINE_THICKNESS)
        FatalError("Adding builtin atom");
    if (MakeAtom("STRIKEOUT_ASCENT", 16, 1) != XA_STRIKEOUT_ASCENT)
        FatalError("Adding builtin atom");
    if (MakeAtom("STRIKEOUT_DESCENT", 17, 1) != XA_STRIKEOUT_DESCENT)
        FatalError("Adding builtin atom");
    if (MakeAtom("ITALIC_ANGLE", 12, 1) != XA_ITALIC_ANGLE)
        FatalError("Adding builtin atom");
    if (MakeAtom("X_HEIGHT", 8, 1) != XA_X_HEIGHT)
        FatalError("Adding builtin atom");
    if (MakeAtom("QUAD_WIDTH", 10, 1) != XA_QUAD_WIDTH)
        FatalError("Adding builtin atom");
    if (MakeAtom("WEIGHT", 6, 1) != XA_WEIGHT)
        FatalError("Adding builtin atom");
    if (MakeAtom("POINT_SIZE", 10, 1) != XA_POINT_SIZE)
        FatalError("Adding builtin atom");
    if (MakeAtom("RESOLUTION", 10, 1) != XA_RESOLUTION)
        FatalError("Adding builtin atom");
    if (MakeAtom("COPYRIGHT", 9, 1) != XA_COPYRIGHT)
        FatalError("Adding builtin atom");
    if (MakeAtom("NOTICE", 6, 1) != XA_NOTICE)
        FatalError("Adding builtin atom");
    if (MakeAtom("FONT_NAME", 9, 1) != XA_FONT_NAME)
        FatalError("Adding builtin atom");
    if (MakeAtom("FAMILY_NAME", 11, 1) != XA_FAMILY_NAME)
        FatalError("Adding builtin atom");
    if (MakeAtom("FULL_NAME", 9, 1) != XA_FULL_NAME)
        FatalError("Adding builtin atom");
    if (MakeAtom("CAP_HEIGHT", 10, 1) != XA_CAP_HEIGHT)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_CLASS", 8, 1) != XA_WM_CLASS)
        FatalError("Adding builtin atom");
    if (MakeAtom("WM_TRANSIENT_FOR", 16, 1) != XA_WM_TRANSIENT_FOR)
        FatalError("Adding builtin atom");
}
