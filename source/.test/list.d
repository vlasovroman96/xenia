module list;
@nogc nothrow:
extern(C): __gshared:
/**
 * Copyright © 2011 Red Hat, Inc.
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

//import externs.X11.Xlib;
import common.list;
import core.stdc.string;
import core.stdc.assert_;
import core.stdc.stdlib;

import test.tests_common;
import test.tests;


struct parent {
    int a;
    XList children;
    int b;
}

struct child {
    int foo;
    int bar;
    XList node;
}

private void test_xorg_list_init()
{
    parent parent = void, tmp = void;

    memset(&parent, 0, parent.sizeof);
    parent.a = 0xa5a5a5;
    parent.b = ~0xa5a5a5;

    tmp = parent;

    xorg_list_init(&parent.children);

    /* test we haven't touched anything else. */
    assert(parent.a == tmp.a);
    assert(parent.b == tmp.b);

    assert(xorg_list_is_empty(&parent.children));
}

private void test_xorg_list_add()
{
    parent parent = { 0 };
    child[3] child = void;
    child* c = void;

    xorg_list_init(&parent.children);

    xorg_list_add(&child[0].node, &parent.children);
    assert(!xorg_list_is_empty(&parent.children));

    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[0], child.sizeof) == 0);

    /* note: xorg_list_add prepends */
    xorg_list_add(&child[1].node, &parent.children);
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[1], child.sizeof) == 0);

    xorg_list_add(&child[2].node, &parent.children);
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[2], child.sizeof) == 0);
}

private void test_xorg_list_append()
{
    parent parent = { 0 };
    child[3] child = void;
    child* c = void;
    int i = void;

    xorg_list_init(&parent.children);

    xorg_list_append(&child[0].node, &parent.children);
    assert(!xorg_list_is_empty(&parent.children));

    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[0], child.sizeof) == 0);
    c = mixin(xorg_list_last_entry!("&parent.children", "child", "node"));

    assert(memcmp(c, &child[0], child.sizeof) == 0);

    xorg_list_append(&child[1].node, &parent.children);
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[0], child.sizeof) == 0);
    c = mixin(xorg_list_last_entry!("&parent.children", "child", "node"));

    assert(memcmp(c, &child[1], child.sizeof) == 0);

    xorg_list_append(&child[2].node, &parent.children);
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[0], child.sizeof) == 0);
    c = mixin(xorg_list_last_entry!("&parent.children", "child", "node"));

    assert(memcmp(c, &child[2], child.sizeof) == 0);

    i = 0;
    mixin(xorg_list_for_each_entry!("c", "&parent.children", "node", q{
        assert(memcmp(c, &child[i++], child.sizeof) == 0);
    }));
}

private void test_xorg_list_del()
{
    parent parent = { 0 };
    child[2] child = void;
    child* c = void;

    xorg_list_init(&parent.children);

    xorg_list_add(&child[0].node, &parent.children);
    assert(!xorg_list_is_empty(&parent.children));

    xorg_list_del(&parent.children);
    assert(xorg_list_is_empty(&parent.children));

    xorg_list_add(&child[0].node, &parent.children);
    xorg_list_del(&child[0].node);
    assert(xorg_list_is_empty(&parent.children));

    xorg_list_add(&child[0].node, &parent.children);
    xorg_list_add(&child[1].node, &parent.children);

    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[1], child.sizeof) == 0);

    /* delete first node */
    xorg_list_del(&child[1].node);
    assert(!xorg_list_is_empty(&parent.children));
    assert(xorg_list_is_empty(&child[1].node));
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[0], child.sizeof) == 0);

    /* delete last node */
    xorg_list_add(&child[1].node, &parent.children);
    xorg_list_del(&child[0].node);
    c = xorg_list_first_entry(&parent.children, child, node);

    assert(memcmp(c, &child[1], child.sizeof) == 0);

    /* delete list head */
    xorg_list_add(&child[0].node, &parent.children);
    xorg_list_del(&parent.children);
    assert(xorg_list_is_empty(&parent.children));
    assert(!xorg_list_is_empty(&child[0].node));
    assert(!xorg_list_is_empty(&child[1].node));
}

private void test_xorg_list_for_each()
{
    parent parent = { 0 };
    child[3] child = void;
    child* c = void;
    int i = 0;

    xorg_list_init(&parent.children);

    xorg_list_add(&child[2].node, &parent.children);
    xorg_list_add(&child[1].node, &parent.children);
    xorg_list_add(&child[0].node, &parent.children);

    mixin(xorg_list_for_each_entry!("c", "&parent.children", "node", q{
        assert(memcmp(c, &child[i], child.sizeof) == 0);
        i++;
    }));

    /* foreach on empty list */
    xorg_list_del(&parent.children);
    assert(xorg_list_is_empty(&parent.children));

    mixin(xorg_list_for_each_entry!("c", "&parent.children", "node", q{
        assert(0);              /* we must not get here */
    }));
}

struct foo {
    char a = 0;
    foo* next;
    char b = 0;
}

private void test_nt_list_init()
{
    foo foo = void;

    foo.a = 10;
    foo.b = 20;
    mixin(nt_list_init!("&foo", "next"));

    assert(foo.a == 10);
    assert(foo.b == 20);
    assert(foo.next is null);
    assert(nt_list_next(&foo, next) is null);
}

private void test_nt_list_append()
{
    int i = void;
    foo* foo = cast(foo*) calloc(10, foo.sizeof);
    foo* item = void;

    for (item = foo, i = 1; i <= 10; i++, item++) {
        assert(item);
        item.a = i;
        item.b = i * 2;
        mixin(nt_list_init!("item", "next"));

        if (item != foo)
            mixin(nt_list_append!("item", "foo", "foo", "next"));
    }

    /* Test using nt_list_next */
    for (item = foo, i = 1; i <= 10; i++, item = nt_list_next(item, next)) {
        assert(item.a == i);
        assert(item.b == i * 2);
    }

    /* Test using nt_list_for_each_entry */
    i = 1;
    mixin(nt_list_for_each_entry!("item", "foo", "next")); {
        assert(item.a == i);
        assert(item.b == i * 2);
        i++;
    }
    assert(i == 11);

    free(foo);
}

private void test_nt_list_insert()
{
    int i = void;
    foo* foo = cast(foo*) calloc(10, foo.sizeof);
    assert(foo);
    foo* item = void;

    foo.a = 1;
    foo.b = 2;
    mixin(nt_list_init!("foo", "next"));

    for (item = &foo[1], i = 10; i > 1; i--, item++) {
        item.a = i;
        item.b = i * 2;
        mixin(nt_list_init!("item", "next"));
        nt_list_insert(item, foo, foo, next);
    }

    /* Test using nt_list_next */
    for (item = foo, i = 1; i <= 10; i++, item = nt_list_next(item, next)) {
        assert(item.a == i);
        assert(item.b == i * 2);
    }

    /* Test using nt_list_for_each_entry */
    i = 1;
    mixin(nt_list_for_each_entry!("item", "foo", "next")); {
        assert(item.a == i);
        assert(item.b == i * 2);
        i++;
    }
    assert(i == 11);

    free(foo);
}

private void test_nt_list_delete()
{
    int i = 1;
    foo* list = cast(foo*) calloc(10, foo.sizeof);
    assert(list);

    foo* foo = list;
    foo* item = void, tmp = void;
    foo* empty_list = foo;

    mixin(nt_list_init!("empty_list", "next"));
    mixin(nt_list_del!("empty_list", "empty_list", "foo", "next"));

    assert(!empty_list);

    for (item = foo, i = 1; i <= 10; i++, item++) {
        item.a = i;
        item.b = i * 2;
        mixin(nt_list_init!("item", "next"));

        if (item != foo)
            mixin(nt_list_append!("item", "foo", "foo", "next"));
    }

    i = 0;
    mixin(nt_list_for_each_entry!("item", "foo", "next")); {
        i++;
    }
    assert(i == 10);

    /* delete last item */
    mixin(nt_list_del!("&foo[9]", "foo", "foo", "next"));

    i = 0;
    mixin(nt_list_for_each_entry!("item", "foo", "next")); {
        assert(item.a != 10);  /* element 10 is gone now */
        i++;
    }
    assert(i == 9);             /* 9 elements left */

    /* delete second item */
    mixin(nt_list_del!("foo.next", "foo", "foo", "next"));

    assert(foo.next.a == 3);

    i = 0;
    mixin(nt_list_for_each_entry!("item", "foo", "next")); {
        assert(item.a != 10);  /* element 10 is gone now */
        assert(item.a != 2);   /* element 2 is gone now */
        i++;
    }
    assert(i == 8);             /* 9 elements left */

    item = foo;
    /* delete first item */
    mixin(nt_list_del!("foo", "foo", "foo", "next"));

    assert(item != foo);
    assert(item.next is null);
    assert(foo.a == 3);
    assert(foo.next.a == 4);

    nt_list_for_each_entry_safe(item, tmp, foo, next); {
        mixin(nt_list_del!("item", "foo", "foo", "next"));
    }

    assert(!foo);
    assert(!item);

    free(list);
}

const(testfunc_t)* list_test()
{
    static const(testfunc_t)[11] testfuncs = [
        test_xorg_list_init,
        test_xorg_list_add,
        test_xorg_list_append,
        test_xorg_list_del,
        test_xorg_list_for_each,

        test_nt_list_init,
        test_nt_list_append,
        test_nt_list_insert,
        test_nt_list_delete,
        null,
    ];
    return testfuncs;
}
