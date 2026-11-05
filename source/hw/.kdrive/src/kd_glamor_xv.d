module hw.kdrive.src.kd_glamor_xv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2014 Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

import config.kdrive_config;

import hw.kdrive.src.kdrive;
import hw.kdrive.src.kxv; 
import glamor.glamor_priv;

// //import externs.X11.extensions.Xv;
import hw.xfree86.common.fourcc;

enum NUM_FORMATS = 4;

private KdVideoFormatRec[NUM_FORMATS] Formats = [
    {15, TrueColor}, {16, TrueColor}, {24, TrueColor}, {30, TrueColor}
];

private void kd_glamor_xv_stop_video(KdScreenInfo* screen, void* data, Bool cleanup)
{
    if (!cleanup)
        return;

    glamor_xv_stop_video(data);
}

private int kd_glamor_xv_set_port_attribute(KdScreenInfo* screen, Atom attribute, int value, void* data)
{
    return glamor_xv_set_port_attribute(data, attribute, cast(INT32)value);
}

private int kd_glamor_xv_get_port_attribute(KdScreenInfo* screen, Atom attribute, int* value, void* data)
{
    return glamor_xv_get_port_attribute(data, attribute, cast(INT32*)value);
}

private void kd_glamor_xv_query_best_size(KdScreenInfo* screen, Bool motion, short vid_w, short vid_h, short drw_w, short drw_h, uint* p_w, uint* p_h, void* data)
{
    *p_w = drw_w;
    *p_h = drw_h;
}

private int kd_glamor_xv_query_image_attributes(KdScreenInfo* screen, int id, ushort* w, ushort* h, int* pitches, int* offsets)
{
    return glamor_xv_query_image_attributes(id, w, h, pitches, offsets);
}

private int kd_glamor_xv_put_image(KdScreenInfo* screen, DrawablePtr pDrawable, short src_x, short src_y, short drw_x, short drw_y, short src_w, short src_h, short drw_w, short drw_h, int id, ubyte* buf, short width, short height, Bool sync, RegionPtr clipBoxes, void* data)
{
    return glamor_xv_put_image(data, pDrawable,
                               src_x, src_y,
                               drw_x, drw_y,
                               src_w, src_h,
                               drw_w, drw_h,
                               id, buf, width, height, sync, clipBoxes);
}

void kd_glamor_xv_init(ScreenPtr screen)
{
    KdVideoAdaptorRec* adaptor = void;
    glamor_port_private* port_privates = void;
    int i = void;
    GLint max_size = 0;
    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_size);
    if (max_size <= 0) {
        /* from glamor_xf86_xv.c */
        max_size = 8192;
    }

    KdVideoEncodingRec encoding = {
        0,
        "XV_IMAGE",
        max_size, max_size,
        {1, 1}
    };

    glamor_xv_core_init(screen);

    adaptor = XNFcallocarray(1, typeof(*adaptor).sizeof);

    adaptor.name = "GLAMOR Textured Video";
    adaptor.type = XvWindowMask | XvInputMask | XvImageMask;
    adaptor.flags = 0;
    adaptor.nEncodings = 1;
    adaptor.pEncodings = &encoding;

    adaptor.pFormats = Formats;
    adaptor.nFormats = NUM_FORMATS;

    adaptor.nPorts = 16; /* Some absurd number */
    port_privates = XNFcallocarray(adaptor.nPorts,
                              glamor_port_private.sizeof);
    adaptor.pPortPrivates = XNFcallocarray(adaptor.nPorts,
                                       (glamor_port_private*).sizeof);
    for (i = 0; i < adaptor.nPorts; i++) {
        adaptor.pPortPrivates[i].ptr = &port_privates[i];
        glamor_xv_init_port(&port_privates[i]);
    }

    adaptor.pAttributes = glamor_xv_attributes;
    adaptor.nAttributes = glamor_xv_num_attributes;

    adaptor.pImages = glamor_xv_images;
    adaptor.nImages = glamor_xv_num_images;

    adaptor.StopVideo = kd_glamor_xv_stop_video;
    adaptor.SetPortAttribute = kd_glamor_xv_set_port_attribute;
    adaptor.GetPortAttribute = kd_glamor_xv_get_port_attribute;
    adaptor.QueryBestSize = kd_glamor_xv_query_best_size;
    adaptor.PutImage = kd_glamor_xv_put_image;
    adaptor.QueryImageAttributes = kd_glamor_xv_query_image_attributes;

    KdXVScreenInit(screen, adaptor, 1);
}
