module test.touch;
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

import core.stdc.stdint;

import dix.atom_priv;
import dix.input_priv;

import dix.inputstr;// import assert;
import dix.scrnintstr;
import test.tests_common;
import test.tests;


private void free_device(DeviceIntPtr dev)
{
    free(dev.name);
    free(dev.last.scroll); /* sigh, allocated but not freed by the valuator functions */
    for (int i = 0; i < dev.last.num_touches; i++)
         valuator_mask_free(&dev.last.touches[i].valuators);

    free(dev.last.touches); /* sigh, allocated but not freed by the valuator functions */
    FreeDeviceClass(XIValuatorClass, cast(void**)&dev.valuator);
    FreeDeviceClass(XITouchClass, cast(void**)&dev.touch);
}

private void touch_grow_queue()
{
    DeviceIntRec dev = void;
    SpriteInfoRec sprite = void;
    size_t size = void, new_size = void;
    int i = void;
    ScreenRec screen = void;
    Atom[2] labels = 0;

    screenInfo.screens[0] = &screen;

    memset(&dev, 0, dev.sizeof);
    dev.type = MASTER_POINTER;  /* claim it's a master to stop ptracccel */
    dev.name = XNFstrdup("test device");
    dev.id = 2;

    InitValuatorClassDeviceStruct(&dev, 2, labels.ptr, 10, Absolute);
    InitTouchClassDeviceStruct(&dev, 5, XIDirectTouch, 2);

    memset(&sprite, 0, sprite.sizeof);
    dev.spriteInfo = &sprite;

    inputInfo.devices = &dev;

    size = 5;

    assert(dev.last.touches);
    for (i = 0; i < size; i++) {
        dev.last.touches[i].active = True;
        dev.last.touches[i].ddx_id = i;
        dev.last.touches[i].client_id = i * 2;
    }

    /* no more space, should've reallocated and succeeded */
    assert(TouchBeginDDXTouch(&dev, 1234) !is null);

    new_size = size + size / 2 + 1;
    assert(dev.last.num_touches == new_size);

    /* make sure we haven't touched those */
    for (i = 0; i < size; i++) {
        DDXTouchPointInfoPtr t = &dev.last.touches[i];

        assert(t.active == True);
        assert(t.ddx_id == i);
        assert(t.client_id == i * 2);
    }

    assert(dev.last.touches[size].active == True);
    assert(dev.last.touches[size].ddx_id == 1234);
    assert(dev.last.touches[size].client_id == 1);

    /* make sure those are zero-initialized */
    for (i = size + 1; i < new_size; i++) {
        DDXTouchPointInfoPtr t = &dev.last.touches[i];

        assert(t.active == False);
        assert(t.client_id == 0);
        assert(t.ddx_id == 0);
    }

    free_device(&dev);
}

private void touch_find_ddxid()
{
    DeviceIntRec dev = void;
    SpriteInfoRec sprite = void;
    DDXTouchPointInfoPtr ti = void, ti2 = void;
    int size = 5;
    int i = void;
    Atom[2] labels = 0;
    ScreenRec screen = void;

    screenInfo.screens[0] = &screen;

    memset(&dev, 0, dev.sizeof);
    dev.type = MASTER_POINTER;  /* claim it's a master to stop ptracccel */
    dev.name = XNFstrdup("test device");
    dev.id = 2;

    InitValuatorClassDeviceStruct(&dev, 2, labels.ptr, 10, Absolute);
    InitTouchClassDeviceStruct(&dev, 5, XIDirectTouch, 2);

    memset(&sprite, 0, sprite.sizeof);
    dev.spriteInfo = &sprite;

    inputInfo.devices = &dev;
    assert(dev.last.touches);

    dev.last.touches[0].active = True;
    dev.last.touches[0].ddx_id = 10;
    dev.last.touches[0].client_id = 20;

    /* existing */
    ti = TouchFindByDDXID(&dev, 10, False);
    assert(ti == &dev.last.touches[0]);

    /* non-existing */
    ti = TouchFindByDDXID(&dev, 20, False);
    assert(ti is null);

    /* Non-active */
    dev.last.touches[0].active = False;
    ti = TouchFindByDDXID(&dev, 10, False);
    assert(ti is null);

    /* create on number 2 */
    dev.last.touches[0].active = True;

    ti = TouchFindByDDXID(&dev, 20, True);
    assert(ti == &dev.last.touches[1]);
    assert(ti.active);
    assert(ti.ddx_id == 20);

    /* set all to active */
    for (i = 0; i < size; i++)
        dev.last.touches[i].active = True;

    /* Try to create more, succeed */
    ti = TouchFindByDDXID(&dev, 30, True);
    assert(ti !is null);
    ti2 = TouchFindByDDXID(&dev, 30, True);
    assert(ti == ti2);
    /* make sure we have resized */
    assert(dev.last.num_touches == 8); /* EQ grows from 5 to 8 */

    /* stop one touchpoint, try to create, succeed */
    dev.last.touches[2].active = False;
    ti = TouchFindByDDXID(&dev, 35, True);
    assert(ti == &dev.last.touches[2]);
    ti = TouchFindByDDXID(&dev, 40, True);
    assert(ti == &dev.last.touches[size+1]);

    free_device(&dev);
}

private void touch_begin_ddxtouch()
{
    DeviceIntRec dev = void;
    SpriteInfoRec sprite = void;
    DDXTouchPointInfoPtr ti = void;
    int ddx_id = 123;
    uint last_client_id = 0;
    Atom[2] labels = 0;
    ScreenRec screen = void;

    screenInfo.screens[0] = &screen;

    memset(&dev, 0, dev.sizeof);
    dev.type = MASTER_POINTER;  /* claim it's a master to stop ptracccel */
    dev.name = XNFstrdup("test device");
    dev.id = 2;
    inputInfo.devices = &dev;

    InitValuatorClassDeviceStruct(&dev, 2, labels.ptr, 10, Absolute);
    InitTouchClassDeviceStruct(&dev, 5, XIDirectTouch, 2);

    memset(&sprite, 0, sprite.sizeof);
    dev.spriteInfo = &sprite;

    assert(dev.last.touches);
    ti = TouchBeginDDXTouch(&dev, ddx_id);
    assert(ti);
    assert(ti.ddx_id == ddx_id);
    /* client_id == ddx_id can happen in real life, but not in this test */
    assert(ti.client_id != ddx_id);
    assert(ti.active);
    assert(ti.client_id > last_client_id);
    assert(ti.emulate_pointer);
    last_client_id = ti.client_id;

    ddx_id += 10;
    ti = TouchBeginDDXTouch(&dev, ddx_id);
    assert(ti);
    assert(ti.ddx_id == ddx_id);
    /* client_id == ddx_id can happen in real life, but not in this test */
    assert(ti.client_id != ddx_id);
    assert(ti.active);
    assert(ti.client_id > last_client_id);
    assert(!ti.emulate_pointer);
    last_client_id = ti.client_id;

    free_device(&dev);
}

private void touch_begin_touch()
{
    DeviceIntRec dev = void;
    TouchPointInfoPtr ti = void;
    int touchid = 12434;
    int sourceid = 23;
    SpriteInfoRec sprite = void;
    ScreenRec screen = void;
    Atom[2] labels = 0;

    screenInfo.screens[0] = &screen;

    memset(&dev, 0, dev.sizeof);
    dev.type = MASTER_POINTER;  /* claim it's a master to stop ptracccel */
    dev.name = XNFstrdup("test device");
    dev.id = 2;

    ti = TouchBeginTouch(&dev, sourceid, touchid, True);
    assert(!ti);

    InitValuatorClassDeviceStruct(&dev, 2, labels.ptr, 10, Absolute);
    InitTouchClassDeviceStruct(&dev, 5, XIDirectTouch, 2);

    memset(&sprite, 0, sprite.sizeof);
    dev.spriteInfo = &sprite;

    ti = TouchBeginTouch(&dev, sourceid, touchid, True);
    assert(ti);
    assert(ti.client_id == touchid);
    assert(ti.active);
    assert(ti.sourceid == sourceid);
    assert(ti.emulate_pointer);

    assert(dev.touch.num_touches == 5);

    free_device(&dev);
}

private void touch_init()
{
    DeviceIntRec dev = void;
    Atom[2] labels = 0;
    int rc = void;
    SpriteInfoRec sprite = void;
    ScreenRec screen = void;

    screenInfo.screens[0] = &screen;

    memset(&dev, 0, dev.sizeof);
    dev.type = MASTER_POINTER;  /* claim it's a master to stop ptracccel */
    dev.name = XNFstrdup("test device");

    memset(&sprite, 0, sprite.sizeof);
    dev.spriteInfo = &sprite;

    InitAtoms();
    rc = InitTouchClassDeviceStruct(&dev, 1, XIDirectTouch, 2);
    assert(rc == False);

    InitValuatorClassDeviceStruct(&dev, 2, labels.ptr, 10, Absolute);
    rc = InitTouchClassDeviceStruct(&dev, 1, XIDirectTouch, 2);
    assert(rc == True);
    assert(dev.touch);

    free_device(&dev);
}

const(testfunc_t)* touch_test()
{
    static const(testfunc_t)[7] testfuncs = [
        touch_grow_queue,
        touch_find_ddxid,
        touch_begin_ddxtouch,
        touch_init,
        touch_begin_touch,
        null,
    ];
    return testfuncs;
}
