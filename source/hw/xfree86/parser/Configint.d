module Configint;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright (c) 1997  Metro Link Incorporated
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Metro Link shall not be
 * used in advertising or otherwise to promote the sale, use or other dealings
 * in this Software without prior written authorization from Metro Link.
 *
 */
/*
 * Copyright (c) 1997-2002 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

/*
 * These definitions are used through out the configuration file parser, but
 * they should not be visible outside of the parser.
 */
 
public import build.xorg_config;

public import core.stdc.stdio;
public import core.stdc.string;
public import core.stdc.stdarg;
public import core.stdc.stddef;
public import hw.xfree86.parser.xf86Parser;

enum ParserNumType { PARSE_DECIMAL, PARSE_OCTAL, PARSE_HEX }
alias PARSE_DECIMAL = ParserNumType.PARSE_DECIMAL;
alias PARSE_OCTAL = ParserNumType.PARSE_OCTAL;
alias PARSE_HEX = ParserNumType.PARSE_HEX;


struct _LexRec {
    int num;                    /* returned number */
    char* str;                  /* private copy of the return-string */
    double realnum = 0;             /* returned number as a real */
    ParserNumType numType;      /* used to enforce correct number formatting */
}alias LexRec = _LexRec;
alias LexPtr = LexRec*;

// LexRec xf86_lex_val;

// enum TRUE = 1;


// enum FALSE = 0;


public import configProcs;
public import core.stdc.stdlib;

enum string TestFree(string a) = `if (` ~ a ~ `) { free (cast(void*) ` ~ a ~ `); ` ~ a ~ ` = null; }`;

enum string parsePrologue(string typeptr,string typerec) = typeptr ~` ptr = void; 
if( (ptr=cast(`~typeptr~`)calloc(1,` ~ typerec ~ `.sizeof)) is null ) { return null; }`;

enum string HANDLE_RETURN(string f,string func) = `
if ((ptr.` ~ f ~ `=` ~ func ~ `) is null)
{
	CLEANUP (ptr);
	return null;
}`;

enum string HANDLE_LIST(string field,string func,string type) = `
{
`~type~` p = (` ~ func ~ `) ();
if (p is null)
{
	CLEANUP (ptr);
	return null;
}
else
{
	ptr.` ~ field ~ ` = cast(`~type~`) xf86addListItem (cast(glp) ptr.` ~ field ~ `, cast(glp) p);
}
}`;

enum string ErrorP(Args...) = `{ 
		return null; 
		   } `;

/*
 * These are defines for error messages to promote consistency.
 * Error messages are preceded by the line number, section and file name,
 * so these messages should be about the specific keyword and syntax in error.
 * To help limit namespace pollution, end each with _MSG.
 * Limit messages to 70 characters if possible.
 */

enum BAD_OPTION_MSG = 
"The Option keyword requires 1 or 2 quoted strings to follow it.";
enum INVALID_KEYWORD_MSG = 
"\"%s\" is not a valid keyword in this section.";
enum INVALID_SECTION_MSG = 
"\"%s\" is not a valid section name.";
enum UNEXPECTED_EOF_MSG = 
"Unexpected EOF. Missing EndSection keyword?";
enum QUOTE_MSG = 
"The %s keyword requires a quoted string to follow it.";
enum NUMBER_MSG = 
"The %s keyword requires a number to follow it.";
enum POSITIVE_INT_MSG = 
"The %s keyword requires a positive integer to follow it.";
enum BOOL_MSG = 
"The %s keyword requires a boolean to follow it.";
enum ZAXISMAPPING_MSG = 
"The ZAxisMapping keyword requires 2 positive numbers or X or Y to follow it.";
enum DACSPEED_MSG = 
"The DacSpeed keyword must be followed by a list of up to %d numbers.";
enum DISPLAYSIZE_MSG = 
"The DisplaySize keyword must be followed by the width and height in mm.";
enum HORIZSYNC_MSG = 
"The HorizSync keyword must be followed by a list of numbers or ranges.";
enum VERTREFRESH_MSG = 
"The VertRefresh keyword must be followed by a list of numbers or ranges.";
enum VIEWPORT_MSG = 
"The Viewport keyword must be followed by an X and Y value.";
enum VIRTUAL_MSG = 
"The Virtual keyword must be followed by a width and height value.";
enum WEIGHT_MSG = 
"The Weight keyword must be followed by red, green and blue values.";
enum BLACK_MSG = 
"The Black keyword must be followed by red, green and blue values.";
enum WHITE_MSG = 
"The White keyword must be followed by red, green and blue values.";
enum SCREEN_MSG = 
"The Screen keyword must be followed by an optional number, a screen name\n" ~
"in quotes, and optional position/layout information.";
enum INVALID_SCR_MSG = 
"Invalid Screen line.";
enum INPUTDEV_MSG = 
"The InputDevice keyword must be followed by an input device name in quotes.";
enum INACTIVE_MSG = 
"The Inactive keyword must be followed by a Device name in quotes.";
enum UNDEFINED_SCREEN_MSG = 
"Undefined Screen \"%s\" referenced by ServerLayout \"%s\".";
enum UNDEFINED_MODES_MSG = 
"Undefined Modes Section \"%s\" referenced by Monitor \"%s\".";
enum UNDEFINED_DEVICE_MSG = 
"Undefined Device \"%s\" referenced by Screen \"%s\".";
enum UNDEFINED_ADAPTOR_MSG = 
"Undefined VideoAdaptor \"%s\" referenced by Screen \"%s\".";
enum ADAPTOR_REF_TWICE_MSG = 
"VideoAdaptor \"%s\" already referenced by Screen \"%s\".";
enum UNDEFINED_DEVICE_LAY_MSG = 
"Undefined Device \"%s\" referenced by ServerLayout \"%s\".";
enum UNDEFINED_INPUT_MSG = 
"Undefined InputDevice \"%s\" referenced by ServerLayout \"%s\".";
enum NO_IDENT_MSG = 
"This section must have an Identifier line.";
enum ONLY_ONE_MSG = 
"This section must have only one of either %s line.";
enum UNDEFINED_INPUTDRIVER_MSG = 
"InputDevice section \"%s\" must have a Driver line.";
enum INVALID_GAMMA_MSG = 
"gamma correction value(s) expected\n either one value or three r/g/b values.";
enum GROUP_MSG = 
"The Group keyword must be followed by either a group name in quotes or\n" 
~ "a numerical group id.";
enum MULTIPLE_MSG = 
"Multiple \"%s\" lines.";
enum MUST_BE_OCTAL_MSG = 
"The number \"%d\" given in this section must be in octal (0xxx) format.";
enum GPU_DEVICE_TOO_MANY = 
"More than %d GPU devices defined.";
enum CLOCKS_TOO_MANY = 
"More than %d Clocks defined.";

/* Warning messages */
enum OBSOLETE_MSG = 
"Ignoring obsolete keyword \"%s\".";

                          /* _Configint_h_ */
