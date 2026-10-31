module glamor.glamor_xv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Red Hat
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
 *
 * Authors:
 *      Dave Airlie <airlied@redhat.com>
 *
 * some code is derived from the xf86-video-ati radeon driver, mainly
 * the calculations.
 */

/** @file glamor_xv.c
 *
 * Xv acceleration implementation
 */
import build.dix_config;

import core.stdc.assert_;

import dix.dix_priv;
import os.bug_priv;

import glamor.glamor_priv;
import glamor.glamor_transform;
import glamor.glamor_transfer;
import externs.X11.extensions.Xv;
import glamor.glamor;
import glamor.glamor_pixmap;


// //import externs.X11.extensions.Xv;
import include.fourcc;
/* Reference color space transform data */
struct REF_TRANSFORM {
    float RefLuma = 0;
    float RefRCb = 0;
    float RefRCr = 0;
    float RefGCb = 0;
    float RefGCr = 0;
    float RefBCb = 0;
    float RefBCr = 0;
}

enum string RTFSaturation(string a) = `(1.0 + ((` ~ a ~ `)*1.0)/1000.0)`;
enum string RTFBrightness(string a) = `(((` ~ a ~ `)*1.0)/2000.0)`;
enum string RTFIntensity(string a) = `(((` ~ a ~ `)*1.0)/2000.0)`;
enum string RTFContrast(string a) = `(1.0 + ((` ~ a ~ `)*1.0)/1000.0)`;
enum string RTFHue(string a) = `(((` ~ a ~ `)*3.1416)/1000.0)`;

private const(glamor_facet) glamor_facet_xv_planar_2 = {
    name: "xv_planar_2",

    source_name: "v_texcoord0",
    vs_vars: ("in vec2 position;\n"
                ~ "in vec2 v_texcoord0;\n"
                ~ "out vec2 tcs;\n"),
    vs_exec: (GLAMOR_POS!("gl_Position", "position")~
                "        tcs = v_texcoord0;\n"),

    fs_vars: ("uniform sampler2D y_sampler;\n"
                ~ "uniform sampler2D u_sampler;\n"
                ~ "uniform vec4 offsetyco;\n"
                ~ "uniform vec4 ucogamma;\n"
                ~ "uniform vec4 vco;\n"
                ~ "in vec2 tcs;\n"),
    fs_exec: (
                "        float sample;\n"
                ~ "        vec2 sample_uv;\n"
                ~ "        vec4 temp1;\n"
                ~ "        sample = texture(y_sampler, tcs).w;\n"
                ~ "        temp1.xyz = offsetyco.www * vec3(sample) + offsetyco.xyz;\n"
                ~ "        sample_uv = texture(u_sampler, tcs).xy;\n"
                ~ "        temp1.xyz = ucogamma.xyz * vec3(sample_uv.x) + temp1.xyz;\n"
                ~ "        temp1.xyz = clamp(vco.xyz * vec3(sample_uv.y) + temp1.xyz, 0.0, 1.0);\n"
                ~ "        temp1.w = 1.0;\n"
                ~ "        frag_color = temp1;\n"
                ),
};

private const(glamor_facet) glamor_facet_xv_planar_3 = {
    name: "xv_planar_3",

    source_name: "v_texcoord0",
    vs_vars: ("in vec2 position;\n"
                ~ "in vec2 v_texcoord0;\n"
                ~ "out vec2 tcs;\n"),
    vs_exec: (GLAMOR_POS!("gl_Position", "position")~
                "        tcs = v_texcoord0;\n"),

    fs_vars: ("uniform sampler2D y_sampler;\n"
                ~ "uniform sampler2D u_sampler;\n"
                ~ "uniform sampler2D v_sampler;\n"
                ~ "uniform vec4 offsetyco;\n"
                ~ "uniform vec4 ucogamma;\n"
                ~ "uniform vec4 vco;\n"
                ~ "in vec2 tcs;\n"),
    fs_exec: (
                "        float sample;\n"
                ~ "        vec4 temp1;\n"
                ~ "        sample = texture(y_sampler, tcs).w;\n"
                ~ "        temp1.xyz = offsetyco.www * vec3(sample) + offsetyco.xyz;\n"
                ~ "        sample = texture(u_sampler, tcs).w;\n"
                ~ "        temp1.xyz = ucogamma.xyz * vec3(sample) + temp1.xyz;\n"
                ~ "        sample = texture(v_sampler, tcs).w;\n"
                ~ "        temp1.xyz = clamp(vco.xyz * vec3(sample) + temp1.xyz, 0.0, 1.0);\n"
                ~ "        temp1.w = 1.0;\n"
                ~ "        frag_color = temp1;\n"
                ),
};

private const(glamor_facet) glamor_facet_xv_uyvy = {
    name: "xv_uyvy",

    source_name: "v_texcoord0",
    vs_vars: ("in vec2 position;\n"
                ~ "in vec2 v_texcoord0;\n"
                ~ "out vec2 tcs;\n"),
    vs_exec: (GLAMOR_POS!("gl_Position", "position")~
                "        tcs = v_texcoord0;\n"),

    fs_vars: ("#ifdef GL_ES\n"
                ~ "precision highp float;\n"
                ~ "#endif\n"
                ~ "uniform sampler2D sampler;\n"
                ~ "uniform vec2 texelSize;\n"
                ~ "uniform vec4 offsetyco;\n"
                ~ "uniform vec4 ucogamma;\n"
                ~ "uniform vec4 vco;\n"
                ~ "in vec2 tcs;\n"
                ),
    fs_exec: (
                "        vec4 temp1;\n"
                ~ "        vec2 xy = texture(sampler, tcs.st).xy;\n"
                ~ "        vec2 prev_xy = texture(sampler, vec2(tcs.s - texelSize.x, tcs.t)).xy;\n"
                ~ "        vec2 next_xy = texture(sampler, vec2(tcs.s + texelSize.x, tcs.t)).xy;\n"
                ~ "\n"
                ~ "        vec3 sample_yuv;\n"
                ~ "        int odd = int(mod(tcs.x / texelSize.x, 2.0));\n"
                ~ "        int even = 1 - odd;\n"
                ~ "        sample_yuv.yxz = float(even)*vec3(xy, next_xy.x) + float(odd)*vec3(prev_xy.x, xy.yx);\n"
                ~ "\n"
                ~ "        temp1.xyz = offsetyco.www * vec3(sample_yuv.x) + offsetyco.xyz;\n"
                ~ "        temp1.xyz = ucogamma.xyz * vec3(sample_yuv.y) + temp1.xyz;\n"
                ~ "        temp1.xyz = clamp(vco.xyz * vec3(sample_yuv.z) + temp1.xyz, 0.0, 1.0);\n"
                ~ "        temp1.w = 1.0;\n"
                ~ "        frag_color = temp1;\n"
                ),
};

private const(glamor_facet) glamor_facet_xv_rgb_raw = {
    name: "xv_rgb",

    source_name: "v_texcoord0",
    vs_vars: ("in vec2 position;\n"
                ~ "in vec2 v_texcoord0;\n"
                ~ "out vec2 tcs;\n"),
    vs_exec: (GLAMOR_POS!("gl_Position", "position")~
                "        tcs = v_texcoord0;\n"),

    fs_vars: ("uniform sampler2D sampler;\n"
                ~ "in vec2 tcs;\n"),
    fs_exec: (
                "        frag_color = texture2D(sampler, tcs);\n"
                ),
};

XvAttributeRec[6] glamor_xv_attributes = [
    {XvSettable | XvGettable, -1000, 1000, cast(char*)"XV_BRIGHTNESS"},
    {XvSettable | XvGettable, -1000, 1000, cast(char*)"XV_CONTRAST"},
    {XvSettable | XvGettable, -1000, 1000, cast(char*)"XV_SATURATION"},
    {XvSettable | XvGettable, -1000, 1000, cast(char*)"XV_HUE"},
    {XvSettable | XvGettable, 0, 1, cast(char*)"XV_COLORSPACE"},
    {0, 0, 0, null}
];
int glamor_xv_num_attributes = glamor_xv_attributes.length - 1;
alias Atom = x11.X.Atom;

Atom glamorBrightness, glamorContrast, glamorSaturation, glamorHue, glamorColorspace, glamorGamma;

XvImageRec[7] glamor_xv_images = [
    XVIMAGE_YV12,
    XVIMAGE_I420,
    XVIMAGE_NV12,
    XVIMAGE_UYVY,
    XVIMAGE_RGB32,
    XVIMAGE_RGB565,
];
int glamor_xv_num_images = glamor_xv_images.length;

private void glamor_init_xv_shader(ScreenPtr screen, glamor_port_private* port_priv, int id)
{
    GLint sampler_loc = void;
    const(glamor_facet)* glamor_facet_xv_planar = null;

    switch (id) {
    case FOURCC_YV12:
    case FOURCC_I420:
        glamor_facet_xv_planar = &glamor_facet_xv_planar_3;
        break;
    case FOURCC_NV12:
        glamor_facet_xv_planar = &glamor_facet_xv_planar_2;
        break;
    case FOURCC_UYVY:
        glamor_facet_xv_planar = &glamor_facet_xv_uyvy;
        break;
    case FOURCC_RGBA32:
    case FOURCC_RGB565:
        glamor_facet_xv_planar = &glamor_facet_xv_rgb_raw;
        break;
    default:
        break;
    }

    glamor_build_program(screen,
                         &port_priv.xv_prog,
                         glamor_facet_xv_planar, null, null, null);

    glUseProgram(port_priv.xv_prog.prog);

    switch (id) {
    case FOURCC_YV12:
    case FOURCC_I420:
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "y_sampler");
        glUniform1i(sampler_loc, 0);
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "u_sampler");
        glUniform1i(sampler_loc, 1);
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "v_sampler");
        glUniform1i(sampler_loc, 2);
        break;
    case FOURCC_NV12:
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "y_sampler");
        glUniform1i(sampler_loc, 0);
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "u_sampler");
        glUniform1i(sampler_loc, 1);
        break;
    case FOURCC_UYVY:
    case FOURCC_RGBA32:
    case FOURCC_RGB565:
        sampler_loc = glGetUniformLocation(port_priv.xv_prog.prog, "sampler");
        glUniform1i(sampler_loc, 0);
        break;
    default:
        break;
    }

}

enum string ClipValue(string v,string min,string max) = `((` ~ v ~ `) < (` ~ min ~ `) ? (` ~ min ~ `) : (` ~ v ~ `) > (` ~ max ~ `) ? (` ~ max ~ `) : (` ~ v ~ `))`;

void glamor_xv_stop_video(glamor_port_private* port_priv)
{
}

private void glamor_xv_free_port_data(glamor_port_private* port_priv)
{
    int i = void;

    for (i = 0; i < 3; i++) {
        if (port_priv.src_pix[i]) {
            glamor_destroy_pixmap(port_priv.src_pix[i]);
            port_priv.src_pix[i] = null;
        }
    }
    RegionUninit(&port_priv.clip);
    RegionNull(&port_priv.clip);
}

int glamor_xv_set_port_attribute(glamor_port_private* port_priv, Atom attribute, INT32 value)
{
    if (attribute == glamorBrightness)
        port_priv.brightness = cast(int)mixin(ClipValue!(`value`, `-1000`, `1000`));
    else if (attribute == glamorHue)
        port_priv.hue = cast(int)mixin(ClipValue!(`value`, `-1000`, `1000`));
    else if (attribute == glamorContrast)
        port_priv.contrast = cast(int)mixin(ClipValue!(`value`, `-1000`, `1000`));
    else if (attribute == glamorSaturation)
        port_priv.saturation = cast(int)mixin(ClipValue!(`value`, `-1000`, `1000`));
    else if (attribute == glamorGamma)
        port_priv.gamma = cast(int)mixin(ClipValue!(`value`, `100`, `10000`));
    else if (attribute == glamorColorspace)
        port_priv.transform_index = cast(int)mixin(ClipValue!(`value`, `0`, `1`));
    else
        return BadMatch;
    return Success;
}

int glamor_xv_get_port_attribute(glamor_port_private* port_priv, Atom attribute, INT32* value)
{
    if (attribute == glamorBrightness)
        *value = port_priv.brightness;
    else if (attribute == glamorHue)
        *value = port_priv.hue;
    else if (attribute == glamorContrast)
        *value = port_priv.contrast;
    else if (attribute == glamorSaturation)
        *value = port_priv.saturation;
    else if (attribute == glamorGamma)
        *value = port_priv.gamma;
    else if (attribute == glamorColorspace)
        *value = port_priv.transform_index;
    else
        return BadMatch;

    return Success;
}

int glamor_xv_query_image_attributes(int id, ushort* w, ushort* h, int* pitches, int* offsets)
{
    int size = 0, tmp = void;

    if (offsets)
        offsets[0] = 0;
    switch (id) {
    case FOURCC_YV12:
    case FOURCC_I420:
        *w = cast(ushort)mixin(ALIGN!("*w", "2")) ;
        *h = cast(ushort)mixin(ALIGN!("*h", "2")) ;
        size = mixin(ALIGN!("*w", "4")) ;
        if (pitches)
            pitches[0] = size;
        size *= *h;
        if (offsets)
            offsets[1] = size;
        tmp = mixin(ALIGN!("*w >> 1", "4")) ;
        if (pitches)
            pitches[1] = pitches[2] = tmp;
        tmp *= (*h >> 1);
        size += tmp;
        if (offsets)
            offsets[2] = size;
        size += tmp;
        break;
    case FOURCC_NV12:
        *w = cast(ushort)mixin(ALIGN!("*w", "2")) ;
        *h = cast(ushort)mixin(ALIGN!("*h", "2")) ;
        size = mixin(ALIGN!("*w", "4")) ;
        if (pitches)
            pitches[0] = size;
        size *= *h;
        if (offsets)
            offsets[1] = size;
        tmp = mixin(ALIGN!("*w", "4")) ;
        if (pitches)
            pitches[1] = tmp;
        tmp *= (*h >> 1);
        size += tmp;
        break;
    case FOURCC_RGBA32:
        size = *w * 4;
        if(pitches)
            pitches[0] = size;
        if(offsets)
            offsets[0] = 0;
        size *= *h;
        break;
    case FOURCC_UYVY:
        /* UYVU is single-plane really, all transformation is processed inside a shader */
        size = mixin(ALIGN!("*w", "2"))  * 2;
        if (pitches)
            pitches[0] = size;
        if (offsets)
            offsets[0] = 0;
        size *= *h;
        break;
    case FOURCC_RGB565:
        size = *w * 2;
        if (pitches)
            pitches[0] = size;
        if (offsets)
            offsets[0] = 0;
        size *= *h;
        break;
    default: break;}
    return size;
}

/* Parameters for ITU-R BT.601 and ITU-R BT.709 colour spaces
   note the difference to the parameters used in overlay are due
   to 10bit vs. float calcs */
private REF_TRANSFORM[2] trans = [
    {1.1643, 0.0, 1.5960, -0.3918, -0.8129, 2.0172, 0.0},       /* BT.601 */
    {1.1643, 0.0, 1.7927, -0.2132, -0.5329, 2.1124, 0.0}        /* BT.709 */
];

void glamor_xv_render(glamor_port_private* port_priv, int id)
{
    ScreenPtr screen = port_priv.pPixmap.drawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    PixmapPtr pixmap = port_priv.pPixmap;
    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);
    glamor_pixmap_private*[3] src_pixmap_priv = void;
    BoxPtr box = REGION_RECTS(&port_priv.clip);
    int nBox = REGION_NUM_RECTS(&port_priv.clip);
    GLfloat[3] src_xscale = void, src_yscale = void;
    int i = void;
    const(float) Loff = -0.0627;
    const(float) Coff = -0.502;
    float uvcosf = void, uvsinf = void;
    float yco = void;
    float[3] uco = void, vco = void, off = void;
    float bright = void, cont = void, gamma = void;
    int ref_ = port_priv.transform_index;
    GLint uloc = void;
    GLfloat* v = void;
    char* vbo_offset = void;
    int dst_box_index = void;

    if (!port_priv.xv_prog.prog)
        glamor_init_xv_shader(screen, port_priv, id);

    cont = mixin(RTFContrast!(`port_priv.contrast`));
    bright = mixin(RTFBrightness!(`port_priv.brightness`));
    gamma = cast(float) port_priv.gamma / 1000.0;
    uvcosf = mixin(RTFSaturation!(`port_priv.saturation`)) * cos(mixin(RTFHue!(`port_priv.hue`)));
    uvsinf = mixin(RTFSaturation!(`port_priv.saturation`)) * sin(mixin(RTFHue!(`port_priv.hue`)));
/* overlay video also does pre-gamma contrast/sat adjust, should we? */

    yco = trans[ref_].RefLuma * cont;
    uco[0] = -trans[ref_].RefRCr * uvsinf;
    uco[1] = trans[ref_].RefGCb * uvcosf - trans[ref_].RefGCr * uvsinf;
    uco[2] = trans[ref_].RefBCb * uvcosf;
    vco[0] = trans[ref_].RefRCr * uvcosf;
    vco[1] = trans[ref_].RefGCb * uvsinf + trans[ref_].RefGCr * uvcosf;
    vco[2] = trans[ref_].RefBCb * uvsinf;
    off[0] = Loff * yco + Coff * (uco[0] + vco[0]) + bright;
    off[1] = Loff * yco + Coff * (uco[1] + vco[1]) + bright;
    off[2] = Loff * yco + Coff * (uco[2] + vco[2]) + bright;
    gamma = 1.0;

    glamor_set_alu(&pixmap.drawable, GXcopy);

    for (i = 0; i < 3; i++) {
        if (port_priv.src_pix[i]) {
            src_pixmap_priv[i] =
                glamor_get_pixmap_private(port_priv.src_pix[i]);
            mixin(pixmap_priv_get_scale!("src_pixmap_priv[i]", "&src_xscale[i]",
                                  "&src_yscale[i]"));
        } else {
           src_pixmap_priv[i] = null;
        }
    }
    glamor_make_current(glamor_priv);
    glUseProgram(port_priv.xv_prog.prog);

    uloc = glGetUniformLocation(port_priv.xv_prog.prog, "offsetyco");
    glUniform4f(uloc, off[0], off[1], off[2], yco);
    uloc = glGetUniformLocation(port_priv.xv_prog.prog, "ucogamma");
    glUniform4f(uloc, uco[0], uco[1], uco[2], gamma);
    uloc = glGetUniformLocation(port_priv.xv_prog.prog, "vco");
    glUniform4f(uloc, vco[0], vco[1], vco[2], 0);

    switch (id) {
    case FOURCC_YV12:
    case FOURCC_I420:
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[0].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[1].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[2].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        break;
    case FOURCC_NV12:
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[0].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[1].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        break;
    case FOURCC_UYVY:
        uloc = glGetUniformLocation(port_priv.xv_prog.prog, "texelSize");
        glUniform2f(uloc, 1.0 / port_priv.w, 1.0 / port_priv.h);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[0].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        break;
    case FOURCC_RGBA32:
    case FOURCC_RGB565:
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, src_pixmap_priv[0].fbo.tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        break;
    default:
        break;
    }

    glEnableVertexAttribArray(GLAMOR_VERTEX_POS);
    glEnableVertexAttribArray(GLAMOR_VERTEX_SOURCE);

    glEnable(GL_SCISSOR_TEST);

    v = cast(float*)glamor_get_vbo_space(screen, cast(uint)(3 * 4 * GLfloat.sizeof), &vbo_offset);

    /* Set up a single primitive covering the area being drawn.  We'll
     * clip it to port_priv->clip using GL scissors instead of just
     * emitting a GL_QUAD per box, because this way we hopefully avoid
     * diagonal tearing between the two triangles used to rasterize a
     * GL_QUAD.
     */
    i = 0;
    v[i++] = port_priv.drw_x;
    v[i++] = port_priv.drw_y;

    v[i++] = port_priv.drw_x + port_priv.dst_w * 2;
    v[i++] = port_priv.drw_y;

    v[i++] = port_priv.drw_x;
    v[i++] = port_priv.drw_y + port_priv.dst_h * 2;

    v[i++] = mixin(t_from_x_coord_x!("src_xscale[0]", "port_priv.src_x"));
    v[i++] = mixin(t_from_x_coord_y!("src_yscale[0]", "port_priv.src_y"));

    v[i++] = mixin(t_from_x_coord_x!("src_xscale[0]", "port_priv.src_x +
                              port_priv.src_w * 2"));
    v[i++] = mixin(t_from_x_coord_y!("src_yscale[0]", "port_priv.src_y"));

    v[i++] = mixin(t_from_x_coord_x!("src_xscale[0]", "port_priv.src_x"));
    v[i++] = mixin(t_from_x_coord_y!("src_yscale[0]", "port_priv.src_y +
                              port_priv.src_h * 2"));

    glVertexAttribPointer(GLAMOR_VERTEX_POS, 2,
                          GL_FLOAT, GL_FALSE,
                          2 * float.sizeof, vbo_offset);

    glVertexAttribPointer(GLAMOR_VERTEX_SOURCE, 2,
                          GL_FLOAT, GL_FALSE,
                          2 * float.sizeof, vbo_offset + 6 * GLfloat.sizeof);

    glamor_put_vbo_space(screen);

    /* Now draw our big triangle, clipped to each of the clip boxes. */
    mixin(BUG_RETURN!("!pixmap_priv"));
    mixin(glamor_pixmap_loop!("pixmap_priv", "dst_box_index", q{
        int dst_off_x = void, dst_off_y = void;

        glamor_set_destination_drawable(port_priv.pDraw,
                                        dst_box_index,
                                        FALSE, FALSE,
                                        port_priv.xv_prog.matrix_uniform,
                                        &dst_off_x, &dst_off_y);

        for (i = 0; i < nBox; i++) {
            int dstx = void, dsty = void, dstw = void, dsth = void;

            dstx = box[i].x1 + dst_off_x;
            dsty = box[i].y1 + dst_off_y;
            dstw = box[i].x2 - box[i].x1;
            dsth = box[i].y2 - box[i].y1;

            glScissor(dstx, dsty, dstw, dsth);
            glDrawArrays(GL_TRIANGLE_FAN, 0, 3);
        }
    }));
    glDisable(GL_SCISSOR_TEST);

    glDisableVertexAttribArray(GLAMOR_VERTEX_POS);
    glDisableVertexAttribArray(GLAMOR_VERTEX_SOURCE);

    DamageDamageRegion(port_priv.pDraw, &port_priv.clip);
}

private Bool glamor_xv_can_reuse_port(glamor_port_private* port_priv, int id, short w, short h)
{
    int ret = TRUE;

    if (port_priv.prev_fmt != id)
        ret = FALSE;

    if (w != port_priv.src_pix_w || h != port_priv.src_pix_h)
        ret = FALSE;

    if (!port_priv.src_pix[0])
        ret = FALSE;

    port_priv.prev_fmt = id;

    return ret;
}

int glamor_xv_put_image(glamor_port_private* port_priv, DrawablePtr pDrawable, short src_x, short src_y, short drw_x, short drw_y, short src_w, short src_h, short drw_w, short drw_h, int id, ubyte* buf, short width, short height, Bool sync, RegionPtr clipBoxes)
{
    ScreenPtr pScreen = pDrawable.pScreen;
    int srcPitch = void, srcPitch2 = void;
    int top = void, nlines = void;
    int s2offset = void, s3offset = void, tmp = void;
    BoxRec full_box = void, half_box = void;

    s2offset = s3offset = srcPitch2 = 0;

    if (!glamor_xv_can_reuse_port(port_priv, id, width, height)) {
        int i = void;

        glamor_xv_free_port_data(port_priv);

        if (port_priv.xv_prog.prog) {
            glDeleteProgram(port_priv.xv_prog.prog);
            port_priv.xv_prog.prog = 0;
        }

        for (i = 0; i < 3; i++)
            if (port_priv.src_pix[i])
                glamor_destroy_pixmap(port_priv.src_pix[i]);

        switch (id) {
        case FOURCC_YV12:
        case FOURCC_I420:
            port_priv.src_pix[0] =
                glamor_create_pixmap(pScreen, width, height, 8,
                                     GLAMOR_CREATE_FBO_NO_FBO);

            port_priv.src_pix[1] =
                glamor_create_pixmap(pScreen, width >> 1, height >> 1, 8,
                                     GLAMOR_CREATE_FBO_NO_FBO);
            port_priv.src_pix[2] =
                glamor_create_pixmap(pScreen, width >> 1, height >> 1, 8,
                                     GLAMOR_CREATE_FBO_NO_FBO);
            if (!port_priv.src_pix[1] || !port_priv.src_pix[2])
                return BadAlloc;
            break;
        case FOURCC_NV12:
            port_priv.src_pix[0] =
                glamor_create_pixmap(pScreen, width, height, 8,
                                     GLAMOR_CREATE_FBO_NO_FBO);
            port_priv.src_pix[1] =
                glamor_create_pixmap(pScreen, width >> 1, height >> 1, 16,
                                     GLAMOR_CREATE_FBO_NO_FBO |
                                     GLAMOR_CREATE_FORMAT_CBCR);
            port_priv.src_pix[2] = null;

            if (!port_priv.src_pix[1])
                return BadAlloc;
            break;
        case FOURCC_RGBA32:
            port_priv.src_pix[0] =
            glamor_create_pixmap(pScreen, width, height, 32,
                                     GLAMOR_CREATE_FBO_NO_FBO);
            port_priv.src_pix[1] = null;
            port_priv.src_pix[2] = null;
            break;
        case FOURCC_RGB565:
            port_priv.src_pix[0] =
            glamor_create_pixmap(pScreen, width, height, 16,
                                     GLAMOR_CREATE_FBO_NO_FBO);
            port_priv.src_pix[1] = null;
            port_priv.src_pix[2] = null;
            break;
        case FOURCC_UYVY:
            port_priv.src_pix[0] =
                glamor_create_pixmap(pScreen, width, height, 32,
                                     GLAMOR_CREATE_FBO_NO_FBO |
                                     GLAMOR_CREATE_FORMAT_CBCR);
            port_priv.src_pix[1] = null;
            port_priv.src_pix[2] = null;
            break;
        default:
            return BadMatch;
        }

        port_priv.src_pix_w = width;
        port_priv.src_pix_h = height;

        if (!port_priv.src_pix[0])
            return BadAlloc;
    }

    top = (src_y) & ~1;
    nlines = (src_y + src_h) - top;

    switch (id) {
    case FOURCC_YV12:
    case FOURCC_I420:
        srcPitch = mixin(ALIGN!("width", "4")) ;
        srcPitch2 = mixin(ALIGN!("width >> 1", "4")) ;
        s2offset = srcPitch * height;
        s3offset = s2offset + (srcPitch2 * ((height + 1) >> 1));
        s2offset += ((top >> 1) * srcPitch2);
        s3offset += ((top >> 1) * srcPitch2);
        if (id == FOURCC_YV12) {
            tmp = s2offset;
            s2offset = s3offset;
            s3offset = tmp;
        }

        full_box.x1 = 0;
        full_box.y1 = 0;
        full_box.x2 = cast(short)width;
        full_box.y2 = cast(short)nlines;

        half_box.x1 = cast(short)0;
        half_box.y1 = cast(short)0;
        half_box.x2 = cast(short)width >> 1;
        half_box.y2 = cast(short)(nlines + 1) >> 1;

        glamor_upload_boxes(&port_priv.src_pix[0].drawable, &full_box, 1,
                            0, 0, 0, 0,
                            buf + (top * srcPitch), srcPitch);

        glamor_upload_boxes(&port_priv.src_pix[1].drawable, &half_box, 1,
                            0, 0, 0, 0,
                            buf + s2offset, srcPitch2);

        glamor_upload_boxes(&port_priv.src_pix[2].drawable, &half_box, 1,
                            0, 0, 0, 0,
                            buf + s3offset, srcPitch2);
        break;
    case FOURCC_NV12:
        srcPitch = mixin(ALIGN!("width", "4")) ;
        s2offset = srcPitch * height;
        s2offset += ((top >> 1) * srcPitch);

        full_box.x1 = cast(short)0;
        full_box.y1 = cast(short)0;
        full_box.x2 = cast(short)width;
        full_box.y2 = cast(short)nlines;

        half_box.x1 = cast(short)0;
        half_box.y1 = cast(short)0;
        half_box.x2 = cast(short)width;
        half_box.y2 = cast(short)(nlines + 1) >> 1;

        glamor_upload_boxes(&port_priv.src_pix[0].drawable, &full_box, 1,
                            0, 0, 0, 0,
                            buf + (top * srcPitch), srcPitch);

        glamor_upload_boxes(&port_priv.src_pix[1].drawable, &half_box, 1,
                            0, 0, 0, 0,
                            buf + s2offset, srcPitch);
        break;
    case FOURCC_UYVY:
        srcPitch = mixin(ALIGN!("width", "2"))  * 2;
        full_box.x1 = 0;
        full_box.y1 = 0;
        full_box.x2 = width;
        full_box.y2 = height;
        glamor_upload_boxes(&port_priv.src_pix[0].drawable, &full_box, 1,
                            0, 0, 0, 0,
                            buf, srcPitch);
        break;
    case FOURCC_RGB565:
        srcPitch = width * 2;
        full_box.x1 = 0;
        full_box.y1 = 0;
        full_box.x2 = width;
        full_box.y2 = height;
        glamor_upload_boxes(&port_priv.src_pix[0].drawable, &full_box, 1,
                            0, 0, 0, 0,
                            buf, srcPitch);
        break;
    case FOURCC_RGBA32:
        srcPitch = width * 4;
        full_box.x1 = 0;
        full_box.y1 = 0;
        full_box.x2 = width;
        full_box.y2 = height;
        glamor_upload_boxes(&port_priv.src_pix[0].drawable, &full_box, 1,
                            0, 0, 0, 0,
                            buf, srcPitch);
        break;
    default:
        return BadMatch;
    }

    if (pDrawable.type == DRAWABLE_WINDOW)
        port_priv.pPixmap = pScreen.GetWindowPixmap(cast(WindowPtr) pDrawable);
    else
        port_priv.pPixmap = cast(PixmapPtr) pDrawable;

    RegionCopy(&port_priv.clip, clipBoxes);

    port_priv.src_x = src_x;
    port_priv.src_y = src_y - top;
    port_priv.src_w = src_w;
    port_priv.src_h = src_h;
    port_priv.dst_w = drw_w;
    port_priv.dst_h = drw_h;
    port_priv.drw_x = drw_x;
    port_priv.drw_y = drw_y;
    port_priv.w = width;
    port_priv.h = height;
    port_priv.pDraw = pDrawable;
    glamor_xv_render(port_priv, id);
    return Success;
}

void glamor_xv_init_port(glamor_port_private* port_priv)
{
    port_priv.brightness = 0;
    port_priv.contrast = 0;
    port_priv.saturation = 0;
    port_priv.hue = 0;
    port_priv.gamma = 1000;
    port_priv.transform_index = 0;

    mixin(REGION_NULL!("pScreen", "&port_priv.clip"));
}

void glamor_xv_core_init(ScreenPtr screen)
{
    glamorBrightness = dixAddAtom("XV_BRIGHTNESS");
    glamorContrast = dixAddAtom("XV_CONTRAST");
    glamorSaturation = dixAddAtom("XV_SATURATION");
    glamorHue = dixAddAtom("XV_HUE");
    glamorGamma = dixAddAtom("XV_GAMMA");
    glamorColorspace = dixAddAtom("XV_COLORSPACE");
}
