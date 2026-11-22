module stubmain;

/* 
 * SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright 2012 Jon TURNEY
 *
 * See COPYING for the full license texts.
 */

import dix.main;

/*
  A default implementation of main, which can be overridden by the DDX
 */
int main(string[] args) {
    return dix_main(args);
}
