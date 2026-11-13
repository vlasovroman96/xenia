module test_xkb;
@nogc nothrow:
extern(C): __gshared:
/**
 * Copyright © 2009 Red Hat, Inc.
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice (including the next
 *  paragraph) shall be included in all copies or substantial portions of the
 *  Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

/* Test relies on assert() */
import build.dix_config;

import config.xkb_config;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.unistd;
import core.stdc.math;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
//import externs.X11.Xatom;

import xkb.xkbsrv_priv;

import dix.inputstr;
import xkb.xkbgeom_priv;
// //import externs.X11.extensions.XKMformat;
import core.stdc.assert_;

import test.tests_common;
import test.tests;


/**
 * Initialize an empty XkbRMLVOSet.
 * Call XkbGetRulesDflts to obtain the default ruleset.
 * Compare obtained ruleset with the built-in defaults.
 *
 * Result: RMLVO defaults are the same as obtained.
 */
private void xkb_get_rules_test()
{
    XkbRMLVOSet rmlvo = { null };
    XkbGetRulesDflts(&rmlvo);

    assert(rmlvo.rules);
    assert(rmlvo.model);
    assert(rmlvo.layout);
    assert(rmlvo.variant);
    assert(rmlvo.options);
    assert(strcmp(rmlvo.rules, XKB_DFLT_RULES) == 0);
    assert(strcmp(rmlvo.model, XKB_DFLT_MODEL) == 0);
    assert(strcmp(rmlvo.layout, XKB_DFLT_LAYOUT) == 0);
    assert(strcmp(rmlvo.variant, XKB_DFLT_VARIANT) == 0);
    assert(strcmp(rmlvo.options, XKB_DFLT_OPTIONS) == 0);

    XkbFreeRMLVOSet(&rmlvo, False);
}

/**
 * Initialize an random XkbRMLVOSet.
 * Call XkbGetRulesDflts to obtain the default ruleset.
 * Compare obtained ruleset with the built-in defaults.
 * Result: RMLVO defaults are the same as obtained.
 */
private void xkb_set_rules_test()
{
    XkbRMLVOSet rmlvo = void;
    XkbRMLVOSet rmlvo_new = { null };

    XkbInitRules(&rmlvo, "test-rules", "test-model", "test-layout",
                         "test-variant", "test-options");
    assert(rmlvo.rules);
    assert(rmlvo.model);
    assert(rmlvo.layout);
    assert(rmlvo.variant);
    assert(rmlvo.options);

    XkbSetRulesDflts(&rmlvo);
    XkbGetRulesDflts(&rmlvo_new);

    /* XkbGetRulesDflts strdups the values */
    assert(rmlvo.rules != rmlvo_new.rules);
    assert(rmlvo.model != rmlvo_new.model);
    assert(rmlvo.layout != rmlvo_new.layout);
    assert(rmlvo.variant != rmlvo_new.variant);
    assert(rmlvo.options != rmlvo_new.options);

    assert(strcmp(rmlvo.rules, rmlvo_new.rules) == 0);
    assert(strcmp(rmlvo.model, rmlvo_new.model) == 0);
    assert(strcmp(rmlvo.layout, rmlvo_new.layout) == 0);
    assert(strcmp(rmlvo.variant, rmlvo_new.variant) == 0);
    assert(strcmp(rmlvo.options, rmlvo_new.options) == 0);

    XkbFreeRMLVOSet(&rmlvo, False);
    XkbFreeRMLVOSet(&rmlvo_new, False);
}

/**
 * Get the default RMLVO set.
 * Set the default RMLVO set.
 * Get the default RMLVO set.
 * Repeat the last two steps.
 *
 * Result: RMLVO set obtained is the same as previously set.
 */
private void xkb_set_get_rules_test()
{
/* This test failed before XkbGetRulesDftlts changed to strdup.
   We test this twice because the first time using XkbGetRulesDflts we obtain
   the built-in defaults. The unexpected free isn't triggered until the second
   XkbSetRulesDefaults.
 */
    XkbRMLVOSet rmlvo = { null };
    XkbRMLVOSet rmlvo_backup = void;

    XkbGetRulesDflts(&rmlvo);

    /* pass 1 */
    XkbSetRulesDflts(&rmlvo);
    XkbFreeRMLVOSet(&rmlvo, False);
    XkbGetRulesDflts(&rmlvo);

    /* Make a backup copy */
    rmlvo_backup.rules = strdup(rmlvo.rules);
    rmlvo_backup.layout = strdup(rmlvo.layout);
    rmlvo_backup.model = strdup(rmlvo.model);
    rmlvo_backup.variant = strdup(rmlvo.variant);
    rmlvo_backup.options = strdup(rmlvo.options);

    /* pass 2 */
    XkbSetRulesDflts(&rmlvo);

    /* This test is iffy, because strictly we may be comparing against already
     * freed memory */
    assert(rmlvo.rules);
    assert(rmlvo.model);
    assert(rmlvo.layout);
    assert(rmlvo.variant);
    assert(rmlvo.options);
    assert(rmlvo_backup.rules);
    assert(rmlvo_backup.model);
    assert(rmlvo_backup.layout);
    assert(rmlvo_backup.variant);
    assert(rmlvo_backup.options);

    assert(strcmp(rmlvo.rules, rmlvo_backup.rules) == 0);
    assert(strcmp(rmlvo.model, rmlvo_backup.model) == 0);
    assert(strcmp(rmlvo.layout, rmlvo_backup.layout) == 0);
    assert(strcmp(rmlvo.variant, rmlvo_backup.variant) == 0);
    assert(strcmp(rmlvo.options, rmlvo_backup.options) == 0);

    XkbFreeRMLVOSet(&rmlvo, False);
    XkbGetRulesDflts(&rmlvo);
    assert(strcmp(rmlvo.rules, rmlvo_backup.rules) == 0);
    assert(strcmp(rmlvo.model, rmlvo_backup.model) == 0);
    assert(strcmp(rmlvo.layout, rmlvo_backup.layout) == 0);
    assert(strcmp(rmlvo.variant, rmlvo_backup.variant) == 0);
    assert(strcmp(rmlvo.options, rmlvo_backup.options) == 0);

    XkbFreeRMLVOSet(&rmlvo, False);
    XkbFreeRMLVOSet(&rmlvo_backup, False);
}

const(testfunc_t)* xkb_test()
{
    static const(testfunc_t)[5] testfuncs = [
        xkb_set_get_rules_test,
        xkb_get_rules_test,
        xkb_set_rules_test,
        null,
    ];
    return testfuncs;
}
