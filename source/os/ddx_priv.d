module os.ddx_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import os.os;
public import os.osdep;

/* callbacks of the DDX, which are called by DIX or OS layer.
   DDX's need to implement these in order to handle DDX specific things.
*/

/* called before server reset */
void ddxBeforeReset();

/* called by ProcessCommandLine, so DDX can catch cmdline args */
int ddxProcessArgument(int argc, char** argv, int i);

/* print DDX specific usage message */
void ddxUseMsg();

void ddxGiveUp(ExitCode error);

void ddxInputThreadInit();

void OsVendorFatalError(const(char)* f, va_list args);
void OsVendorInit();

 /* _XSERVER_OS_DDX_PRIV_H */
