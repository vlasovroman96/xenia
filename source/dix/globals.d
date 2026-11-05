module dix.globals;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

import build.xlibre_server;

//import x11.X;
//import x11.Xmd;

import dix.cursor_priv;
import dix.dix_priv;
import dix.server_priv;
import dix.settings_priv;

import include.misc;
import include.windowstr;
import include.scrnintstr;
import dix.input;
import dix.dixfonts;
import dix.dixstruct_priv;
import include.os;
import dix.timestamp;

ScreenInfo screenInfo;

KeybdCtrl defaultKeyboardControl = {
    DEFAULT_KEYBOARD_CLICK,
    DEFAULT_BELL,
    DEFAULT_BELL_PITCH,
    DEFAULT_BELL_DURATION,
    DEFAULT_AUTOREPEAT,
    DEFAULT_AUTOREPEATS,
    DEFAULT_LEDS,
    0
};

PtrCtrl defaultPointerControl = {
    DEFAULT_PTR_NUMERATOR,
    DEFAULT_PTR_DENOMINATOR,
    DEFAULT_PTR_THRESHOLD,
    0
};

ClientPtr[MAXCLIENTS] clients;
ClientPtr serverClient;
int currentMaxClients;          /* current size of clients array */
c_long maxBigRequestSize = MAX_BIG_REQUEST_SIZE;

static c_ulong globalSerialNumber = 0;

/* this is always 1 now, since there's no internal reset anymore */
x_server_generation_t serverGeneration = 1;

/* these next four are initialized in main.c */
CARD32 ScreenSaverTime;
CARD32 ScreenSaverInterval;
int ScreenSaverBlanking;
int ScreenSaverAllowExposures;

/* default time of 10 minutes */
CARD32 defaultScreenSaverTime = (10 * (60 * 1000));
CARD32 defaultScreenSaverInterval = (10 * (60 * 1000));
int defaultScreenSaverBlanking = PreferBlanking;
int defaultScreenSaverAllowExposures = AllowExposures;

static if(SCREENSAVER){
Bool screenSaverSuspended = FALSE;
}

const(char)* defaultFontPath = build.xlibre_server.COMPILEDDEFAULTFONTPATH;
// FontPtr defaultFont;            /* not declared in dix.h to avoid including font.h in
                                //    every compilation of dix code */
CursorPtr rootCursor;
Bool party_like_its_1989 = FALSE;
Bool whiteRoot = FALSE;

TimeStamp currentTime;

int defaultColorVisualClass = -1;
int monitorResolution = 0;

Bool explicit_display = FALSE;
char* ConnectionInfo;
