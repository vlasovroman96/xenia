module common.xserver_properties;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software")
 * to deal in the software without restriction, including without limitation
 * on the rights to use, copy, modify, merge, publish, distribute, sub
 * license, and/or sell copies of the Software, and to permit persons to whom
 * them Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/* Properties managed by the server. */

 
/* Type for a 4 byte float. Storage format IEEE 754 in client's default
 * byte-ordering. */
enum XATOM_FLOAT = "FLOAT";

/* STRING. Seat name of this display */
enum SEAT_ATOM_NAME = "Xorg_Seat";

/* BOOL. 0 - device disabled, 1 - device enabled */
enum XI_PROP_ENABLED =      "Device Enabled";
/* BOOL. If present, device is a virtual XTEST device */
enum XI_PROP_XTEST_DEVICE =  "XTEST Device";

/* CARD32, 2 values, vendor, product.
 * This property is set by the driver and may not be available for some
 * drivers. Read-Only */
enum XI_PROP_PRODUCT_ID = "Device Product ID";

/* Coordinate transformation matrix for absolute input devices
 * FLOAT, 9 values in row-major order, coordinates in 0..1 range:
 * [c0 c1 c2]   [x]
 * [c3 c4 c5] * [y]
 * [c6 c7 c8]   [1] */
enum XI_PROP_TRANSFORM = "Coordinate Transformation Matrix";

/* STRING. Device node path of device */
enum XI_PROP_DEVICE_NODE = "Device Node";

/* Pointer acceleration properties */
/* INTEGER of any format */
enum ACCEL_PROP_PROFILE_NUMBER = "Device Accel Profile";
/* FLOAT, format 32 */
enum ACCEL_PROP_CONSTANT_DECELERATION = "Device Accel Constant Deceleration";
/* FLOAT, format 32 */
enum ACCEL_PROP_ADAPTIVE_DECELERATION = "Device Accel Adaptive Deceleration";
/* FLOAT, format 32 */
enum ACCEL_PROP_VELOCITY_SCALING = "Device Accel Velocity Scaling";

/* Axis labels */
enum AXIS_LABEL_PROP = "Axis Labels";

enum AXIS_LABEL_PROP_REL_X =           "Rel X";
enum AXIS_LABEL_PROP_REL_Y =           "Rel Y";
enum AXIS_LABEL_PROP_REL_Z =           "Rel Z";
enum AXIS_LABEL_PROP_REL_RX =          "Rel Rotary X";
enum AXIS_LABEL_PROP_REL_RY =          "Rel Rotary Y";
enum AXIS_LABEL_PROP_REL_RZ =          "Rel Rotary Z";
enum AXIS_LABEL_PROP_REL_HWHEEL =      "Rel Horiz Wheel";
enum AXIS_LABEL_PROP_REL_DIAL =        "Rel Dial";
enum AXIS_LABEL_PROP_REL_WHEEL =       "Rel Vert Wheel";
enum AXIS_LABEL_PROP_REL_MISC =        "Rel Misc";
enum AXIS_LABEL_PROP_REL_VSCROLL =     "Rel Vert Scroll";
enum AXIS_LABEL_PROP_REL_HSCROLL =     "Rel Horiz Scroll";

/*
 * Absolute axes
 */

enum AXIS_LABEL_PROP_ABS_X =           "Abs X";
enum AXIS_LABEL_PROP_ABS_Y =           "Abs Y";
enum AXIS_LABEL_PROP_ABS_Z =           "Abs Z";
enum AXIS_LABEL_PROP_ABS_RX =          "Abs Rotary X";
enum AXIS_LABEL_PROP_ABS_RY =          "Abs Rotary Y";
enum AXIS_LABEL_PROP_ABS_RZ =          "Abs Rotary Z";
enum AXIS_LABEL_PROP_ABS_THROTTLE =    "Abs Throttle";
enum AXIS_LABEL_PROP_ABS_RUDDER =      "Abs Rudder";
enum AXIS_LABEL_PROP_ABS_WHEEL =       "Abs Wheel";
enum AXIS_LABEL_PROP_ABS_GAS =         "Abs Gas";
enum AXIS_LABEL_PROP_ABS_BRAKE =       "Abs Brake";
enum AXIS_LABEL_PROP_ABS_HAT0X =       "Abs Hat 0 X";
enum AXIS_LABEL_PROP_ABS_HAT0Y =       "Abs Hat 0 Y";
enum AXIS_LABEL_PROP_ABS_HAT1X =       "Abs Hat 1 X";
enum AXIS_LABEL_PROP_ABS_HAT1Y =       "Abs Hat 1 Y";
enum AXIS_LABEL_PROP_ABS_HAT2X =       "Abs Hat 2 X";
enum AXIS_LABEL_PROP_ABS_HAT2Y =       "Abs Hat 2 Y";
enum AXIS_LABEL_PROP_ABS_HAT3X =       "Abs Hat 3 X";
enum AXIS_LABEL_PROP_ABS_HAT3Y =       "Abs Hat 3 Y";
enum AXIS_LABEL_PROP_ABS_PRESSURE =    "Abs Pressure";
enum AXIS_LABEL_PROP_ABS_DISTANCE =    "Abs Distance";
enum AXIS_LABEL_PROP_ABS_TILT_X =      "Abs Tilt X";
enum AXIS_LABEL_PROP_ABS_TILT_Y =      "Abs Tilt Y";
enum AXIS_LABEL_PROP_ABS_TOOL_WIDTH =  "Abs Tool Width";
enum AXIS_LABEL_PROP_ABS_VOLUME =      "Abs Volume";
enum AXIS_LABEL_PROP_ABS_MT_TOUCH_MAJOR = "Abs MT Touch Major";
enum AXIS_LABEL_PROP_ABS_MT_TOUCH_MINOR = "Abs MT Touch Minor";
enum AXIS_LABEL_PROP_ABS_MT_WIDTH_MAJOR = "Abs MT Width Major";
enum AXIS_LABEL_PROP_ABS_MT_WIDTH_MINOR = "Abs MT Width Minor";
enum AXIS_LABEL_PROP_ABS_MT_ORIENTATION = "Abs MT Orientation";
enum AXIS_LABEL_PROP_ABS_MT_POSITION_X =  "Abs MT Position X";
enum AXIS_LABEL_PROP_ABS_MT_POSITION_Y =  "Abs MT Position Y";
enum AXIS_LABEL_PROP_ABS_MT_TOOL_TYPE =   "Abs MT Tool Type";
enum AXIS_LABEL_PROP_ABS_MT_BLOB_ID =     "Abs MT Blob ID";
enum AXIS_LABEL_PROP_ABS_MT_TRACKING_ID = "Abs MT Tracking ID";
enum AXIS_LABEL_PROP_ABS_MT_PRESSURE =    "Abs MT Pressure";
enum AXIS_LABEL_PROP_ABS_MT_DISTANCE =    "Abs MT Distance";
enum AXIS_LABEL_PROP_ABS_MT_TOOL_X =      "Abs MT Tool X";
enum AXIS_LABEL_PROP_ABS_MT_TOOL_Y =      "Abs MT Tool Y";
enum AXIS_LABEL_PROP_ABS_MISC =        "Abs Misc";

/* Button names */
enum BTN_LABEL_PROP = "Button Labels";

/* Default label */
enum BTN_LABEL_PROP_BTN_UNKNOWN =      "Button Unknown";
/* Wheel buttons */
enum BTN_LABEL_PROP_BTN_WHEEL_UP =     "Button Wheel Up";
enum BTN_LABEL_PROP_BTN_WHEEL_DOWN =   "Button Wheel Down";
enum BTN_LABEL_PROP_BTN_HWHEEL_LEFT =  "Button Horiz Wheel Left";
enum BTN_LABEL_PROP_BTN_HWHEEL_RIGHT = "Button Horiz Wheel Right";

/* The following are from linux/input.h */
enum BTN_LABEL_PROP_BTN_0 =            "Button 0";
enum BTN_LABEL_PROP_BTN_1 =            "Button 1";
enum BTN_LABEL_PROP_BTN_2 =            "Button 2";
enum BTN_LABEL_PROP_BTN_3 =            "Button 3";
enum BTN_LABEL_PROP_BTN_4 =            "Button 4";
enum BTN_LABEL_PROP_BTN_5 =            "Button 5";
enum BTN_LABEL_PROP_BTN_6 =            "Button 6";
enum BTN_LABEL_PROP_BTN_7 =            "Button 7";
enum BTN_LABEL_PROP_BTN_8 =            "Button 8";
enum BTN_LABEL_PROP_BTN_9 =            "Button 9";

enum BTN_LABEL_PROP_BTN_LEFT =         "Button Left";
enum BTN_LABEL_PROP_BTN_RIGHT =        "Button Right";
enum BTN_LABEL_PROP_BTN_MIDDLE =       "Button Middle";
enum BTN_LABEL_PROP_BTN_SIDE =         "Button Side";
enum BTN_LABEL_PROP_BTN_EXTRA =        "Button Extra";
enum BTN_LABEL_PROP_BTN_FORWARD =      "Button Forward";
enum BTN_LABEL_PROP_BTN_BACK =         "Button Back";
enum BTN_LABEL_PROP_BTN_TASK =         "Button Task";

enum BTN_LABEL_PROP_BTN_TRIGGER =      "Button Trigger";
enum BTN_LABEL_PROP_BTN_THUMB =        "Button Thumb";
enum BTN_LABEL_PROP_BTN_THUMB2 =       "Button Thumb2";
enum BTN_LABEL_PROP_BTN_TOP =          "Button Top";
enum BTN_LABEL_PROP_BTN_TOP2 =         "Button Top2";
enum BTN_LABEL_PROP_BTN_PINKIE =       "Button Pinkie";
enum BTN_LABEL_PROP_BTN_BASE =         "Button Base";
enum BTN_LABEL_PROP_BTN_BASE2 =        "Button Base2";
enum BTN_LABEL_PROP_BTN_BASE3 =        "Button Base3";
enum BTN_LABEL_PROP_BTN_BASE4 =        "Button Base4";
enum BTN_LABEL_PROP_BTN_BASE5 =        "Button Base5";
enum BTN_LABEL_PROP_BTN_BASE6 =        "Button Base6";
enum BTN_LABEL_PROP_BTN_DEAD =         "Button Dead";

enum BTN_LABEL_PROP_BTN_A =            "Button A";
enum BTN_LABEL_PROP_BTN_B =            "Button B";
enum BTN_LABEL_PROP_BTN_C =            "Button C";
enum BTN_LABEL_PROP_BTN_X =            "Button X";
enum BTN_LABEL_PROP_BTN_Y =            "Button Y";
enum BTN_LABEL_PROP_BTN_Z =            "Button Z";
enum BTN_LABEL_PROP_BTN_TL =           "Button T Left";
enum BTN_LABEL_PROP_BTN_TR =           "Button T Right";
enum BTN_LABEL_PROP_BTN_TL2 =          "Button T Left2";
enum BTN_LABEL_PROP_BTN_TR2 =          "Button T Right2";
enum BTN_LABEL_PROP_BTN_SELECT =       "Button Select";
enum BTN_LABEL_PROP_BTN_START =        "Button Start";
enum BTN_LABEL_PROP_BTN_MODE =         "Button Mode";
enum BTN_LABEL_PROP_BTN_THUMBL =       "Button Thumb Left";
enum BTN_LABEL_PROP_BTN_THUMBR =       "Button Thumb Right";

enum BTN_LABEL_PROP_BTN_TOOL_PEN =             "Button Tool Pen";
enum BTN_LABEL_PROP_BTN_TOOL_RUBBER =          "Button Tool Rubber";
enum BTN_LABEL_PROP_BTN_TOOL_BRUSH =           "Button Tool Brush";
enum BTN_LABEL_PROP_BTN_TOOL_PENCIL =          "Button Tool Pencil";
enum BTN_LABEL_PROP_BTN_TOOL_AIRBRUSH =        "Button Tool Airbrush";
enum BTN_LABEL_PROP_BTN_TOOL_FINGER =          "Button Tool Finger";
enum BTN_LABEL_PROP_BTN_TOOL_MOUSE =           "Button Tool Mouse";
enum BTN_LABEL_PROP_BTN_TOOL_LENS =            "Button Tool Lens";
enum BTN_LABEL_PROP_BTN_TOUCH =                "Button Touch";
enum BTN_LABEL_PROP_BTN_STYLUS =               "Button Stylus";
enum BTN_LABEL_PROP_BTN_STYLUS2 =              "Button Stylus2";
enum BTN_LABEL_PROP_BTN_TOOL_DOUBLETAP =       "Button Tool Doubletap";
enum BTN_LABEL_PROP_BTN_TOOL_TRIPLETAP =       "Button Tool Tripletap";

enum BTN_LABEL_PROP_BTN_GEAR_DOWN =            "Button Gear down";
enum BTN_LABEL_PROP_BTN_GEAR_UP =              "Button Gear up";


