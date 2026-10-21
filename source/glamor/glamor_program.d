module glamor.glamor_program;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2014 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import x11.Xdefs;
import externs.X11.extensions.render_;


import glamor.glamor_priv;
import glamor.glamor_transform;
import glamor.glamor;
import externs.gnu;
import include.picture;
import glamor.glamor_render;
// import glamor.glamor_program;

alias glamor_program_location = int;

enum : glamor_program_location{
    glamor_program_location_none = 0,
    glamor_program_location_fg = 1,
    glamor_program_location_bg = 2,
    glamor_program_location_fillsamp = 4,
    glamor_program_location_fillpos = 8,
    glamor_program_location_font = 16,
    glamor_program_location_bitplane = 32,
    glamor_program_location_dash = 64,
    glamor_program_location_atlas = 128,
} ;

Bool
glamor_is_component_alpha(PicturePtr mask) {
    if (mask && mask.componentAlpha && mixin(PIXMAN_FORMAT_RGB!("mask.format")))
        return TRUE;
    return FALSE;
}

struct glamor_facet{
    const char                          *name;
    const int                           version_;
    char                                *vs_extensions;
    const char                          *fs_extensions;
    const char                          *vs_vars;
    const char                          *vs_exec;
    const char                          *fs_vars;
    const char                          *fs_exec;
    const glamor_program_location       locations;
    const glamor_program_flag           flags;
    const char                          *source_name;
    glamor_use                          use;
    glamor_use_render                   use_render;
} ;

struct _glamor_program {
    GLint                       prog;
    GLint                       failed;
    GLint                       matrix_uniform;
    GLint                       fg_uniform;
    GLint                       bg_uniform;
    GLint                       fill_size_inv_uniform;
    GLint                       fill_offset_uniform;
    GLint                       font_uniform;
    GLint                       bitplane_uniform;
    GLint                       bitmul_uniform;
    GLint                       dash_uniform;
    GLint                       dash_length_uniform;
    GLint                       atlas_uniform;
    glamor_program_location     locations;
    glamor_program_flag         flags;
    glamor_use                  prim_use;
    glamor_use                  fill_use;
    glamor_program_alpha        alpha;
    glamor_use_render           prim_use_render;
    glamor_use_render           fill_use_render;
};

alias glamor_program = _glamor_program;

alias glamor_program_alpha = int;

enum  : glamor_program_alpha{
    glamor_program_alpha_normal,
    glamor_program_alpha_ca_first,
    glamor_program_alpha_ca_second,
    glamor_program_alpha_dual_blend,
    glamor_program_alpha_dual_blend_gles2,
    glamor_program_alpha_count
};

struct glamor_program_fill{
    glamor_program[4]      progs;
} ;


// alias glamor_program  = _glamor_program;

alias glamor_use = Bool function (DrawablePtr drawable, GCPtr gc, glamor_program *prog, void *arg);

alias glamor_use_render = Bool function (CARD8 op, PicturePtr src, PicturePtr dst, glamor_program *prog);

enum glamor_program_flag{
    glamor_program_flag_none = 0,
} ;

alias glamor_program_source = int;

enum : glamor_program_source {
    glamor_program_source_solid,
    glamor_program_source_picture,
    glamor_program_source_1x1_picture,
    glamor_program_source_count,
} ;

struct glamor_program_render{
    glamor_program[glamor_program_source_count][glamor_program_alpha_count]      progs;
} ;

private Bool use_solid(DrawablePtr drawable, GCPtr gc, glamor_program* prog, void* arg)
{
    return glamor_set_solid(drawable, gc, TRUE, prog.fg_uniform);
}

const(glamor_facet) glamor_fill_solid = {
    name: "solid",
    fs_exec: "       frag_color = fg;\n",
    locations: glamor_program_location_fg,
    use: &use_solid,
};

private Bool use_tile(DrawablePtr drawable, GCPtr gc, glamor_program* prog, void* arg)
{
    return glamor_set_tiled(drawable, gc, prog.fill_offset_uniform, prog.fill_size_inv_uniform);
}

private const(glamor_facet) glamor_fill_tile = {
    name: "tile",
    vs_exec:  "       fill_pos = (fill_offset + primitive.xy + pos) * fill_size_inv;\n",
    fs_exec:  "       frag_color = texture(sampler, fill_pos);\n",
    locations: glamor_program_location_fillsamp | glamor_program_location_fillpos,
    use: &use_tile,
};

private Bool use_stipple(DrawablePtr drawable, GCPtr gc, glamor_program* prog, void* arg)
{
    return glamor_set_stippled(drawable, gc, prog.fg_uniform,
                               prog.fill_offset_uniform,
                               prog.fill_size_inv_uniform);
}

private const(glamor_facet) glamor_fill_stipple = {
    name: "stipple",
    vs_exec:  "       fill_pos = (fill_offset + primitive.xy + pos) * fill_size_inv;\n",
    fs_exec: ("       float a = texture(sampler, fill_pos).w;\n"
                ~ "       if (a == 0.0)\n"
                ~ "               discard;\n"
                ~ "       frag_color = fg;\n"),
    locations: glamor_program_location_fg | glamor_program_location_fillsamp | glamor_program_location_fillpos,
    use: &use_stipple,
};

private Bool use_opaque_stipple(DrawablePtr drawable, GCPtr gc, glamor_program* prog, void* arg)
{
    if (!use_stipple(drawable, gc, prog, arg))
        return FALSE;
    glamor_set_color(drawable, gc.bgPixel, prog.bg_uniform);
    return TRUE;
}

private const(glamor_facet) glamor_fill_opaque_stipple = {
    name: "opaque_stipple",
    vs_exec:  "       fill_pos = (fill_offset + primitive.xy + pos) * fill_size_inv;\n",
    fs_exec: ("       float a = texture(sampler, fill_pos).w;\n"
                ~ "       if (a == 0.0)\n"
                ~ "               frag_color = bg;\n"
                ~ "       else\n"
                ~ "               frag_color = fg;\n"),
    locations: glamor_program_location_fg | glamor_program_location_bg | glamor_program_location_fillsamp | glamor_program_location_fillpos,
    use: &use_opaque_stipple
};

private const(glamor_facet)*[4] glamor_facet_fill = [
    &glamor_fill_solid,
    &glamor_fill_tile,
    &glamor_fill_stipple,
    &glamor_fill_opaque_stipple,
];

struct glamor_location_var {
    glamor_program_location location;
    const(char)* vs_vars;
    const(char)* fs_vars;
}

private glamor_location_var[9] location_vars = [
    {
        location: glamor_program_location_fg,
        fs_vars: "uniform vec4 fg;\n"
    },
    {
        location: glamor_program_location_bg,
        fs_vars: "uniform vec4 bg;\n"
    },
    {
        location: glamor_program_location_fillsamp,
        fs_vars: "uniform sampler2D sampler;\n"
    },
    {
        location: glamor_program_location_fillpos,
        vs_vars: ("uniform vec2 fill_offset;\n"
                    ~ "uniform vec2 fill_size_inv;\n"
                    ~ "out vec2 fill_pos;\n"),
        fs_vars: ("in vec2 fill_pos;\n")
    },
    {
        location: glamor_program_location_font,
        fs_vars: ("#ifdef GL_ES\n"
                    ~ "precision mediump usampler2D;\n"
                    ~ "#endif\n"
                    ~ "uniform usampler2D font;\n"),
    },
    {
        location: glamor_program_location_bitplane,
        fs_vars: ("uniform uvec4 bitplane;\n"
                    ~ "uniform vec4 bitmul;\n"),
    },
    {
        location: glamor_program_location_dash,
        vs_vars: "uniform float dash_length;\n",
        fs_vars: "uniform sampler2D dash;\n",
    },
    {
        location: glamor_program_location_atlas,
        fs_vars: "uniform sampler2D atlas;\n",
    },
];

private char* add_var(char* cur, const(char)* add)
{
    char* new_ = void;

    if (!add)
        return cur;

    new_ = cast(char*)realloc(cur, strlen(cur) + strlen(add) + 1);
    if (!new_) {
        free(cur);
        return null;
    }
    strcat(new_, add);
    return new_;
}

private char* vs_location_vars(glamor_program_location locations)
{
    int l = void;
    char* vars = strdup("");

    for (l = 0; vars && l < mixin(ARRAY_SIZE!("location_vars")); l++)
        if (locations & location_vars[l].location)
            vars = add_var(vars, location_vars[l].vs_vars);
    return vars;
}

private char* fs_location_vars(glamor_program_location locations)
{
    int l = void;
    char* vars = strdup("");

    for (l = 0; vars && l < mixin(ARRAY_SIZE!("location_vars")); l++)
        if (locations & location_vars[l].location)
            vars = add_var(vars, location_vars[l].fs_vars);
    return vars;
}

enum  vs_template = "%s"                                /* version */
    ~ "%s"                                /* exts */
    ~ "%s"                                /* in/out defines */
    ~ "%s"                                /* defines */
    ~ "%s"                                /* prim vs_vars */
    ~ "%s"                                /* fill vs_vars */
    ~ "%s"                                /* location vs_vars */
    ~GLAMOR_DECLARE_MATRIX
    ~ "void main() {\n"
    ~ "%s"                                /* prim vs_exec, outputs 'pos' and gl_Position */
    ~ "%s"                                /* fill vs_exec */
    ~ "}\n";

enum  fs_template = "%s"                                /* version */
    ~ "%s"                                /* exts */
    ~ "%s"                                /* prim fs_extensions */
    ~ "%s"                                /* fill fs_extensions */
    ~GLAMOR_DEFAULT_PRECISION
    ~ "%s"                                /* in/out defines */
    ~ "%s"                                /* defines */
    ~ "%s"                                /* prim fs_vars */
    ~ "%s"                                /* fill fs_vars */
    ~ "%s"                                /* location fs_vars */
    ~ "void main() {\n"
    ~ "%s"                                /* prim fs_exec */
    ~ "%s"                                /* fill fs_exec */
    ~ "%s"                                /* combine */
    ~ "}\n";

private const(char)* str(const(char)* s)
{
    if (!s)
        return "";
    return s;
}

private const(glamor_facet) facet_null_fill = {
    name: ""
};

enum DBG = 0;

private GLint glamor_get_uniform(glamor_program* prog, glamor_program_location location, const(char)* name)
{
    GLint uniform = void;
    if (location && (prog.locations & location) == 0)
        return -2;
    uniform = glGetUniformLocation(prog.prog, name);
static if (DBG) {
    ErrorF("%s uniform %d\n", name, uniform);
}
    return uniform;
}

Bool glamor_build_program(ScreenPtr screen, glamor_program* prog, const(glamor_facet)* prim, const(glamor_facet)* fill, const(char)* combine, const(char)* defines)
{
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);

    glamor_program_location locations = prim.locations;
    glamor_program_flag flags = prim.flags;

    int version_ = prim.version_;
    char* version_string = null;

    char* fs_vars = null;
    char* vs_vars = null;

    char* vs_prog_string = null;
    char* fs_prog_string = null;

    GLint fs_prog = void, vs_prog = void;
    Bool gpu_shader4 = FALSE;

    if (!fill)
        fill = &facet_null_fill;

    locations |= fill.locations;
    flags |= fill.flags;
    version_ = mixin(MAX!("version_", "fill.version_"));

    if (version_ > glamor_priv.glsl_version) {
        if (version_ == 130 && !glamor_priv.use_gpu_shader4)
            goto fail;
        else {
            version_ = 120;
            gpu_shader4 = TRUE;
        }
    }

    if (version_ == 130 && glamor_priv.is_gles && glamor_priv.glsl_version > 110)
        version_ = 300;
    else if (glamor_priv.is_gles)
        version_ = 100;
    else if (!version_)
        version_ = 120;

    vs_vars = vs_location_vars(locations);
    fs_vars = fs_location_vars(locations);

    if (!vs_vars)
        goto fail;
    if (!fs_vars)
        goto fail;

    if (version_) {
        if (asprintf(&version_string, "#version %d %s\n", version_,
                     glamor_priv.is_gles && version_ > 100 ? "es".ptr : "".ptr) < 0)
            version_string = null;
        if (!version_string)
            goto fail;
    }

    if (asprintf(&vs_prog_string,
                 vs_template.ptr,
                 str(version_string),
                 gpu_shader4 ? "#extension GL_EXT_gpu_shader4 : require\n".ptr : "".ptr,
                 version_ < 130 ? GLAMOR_COMPAT_DEFINES_VS.ptr : "".ptr,
                 str(defines),
                 str(prim.vs_vars),
                 str(fill.vs_vars),
                 vs_vars,
                 str(prim.vs_exec),
                 str(fill.vs_exec)) < 0)
        vs_prog_string = null;

    if (asprintf(&fs_prog_string,
                 fs_template.ptr,
                 str(version_string),
                 str(prim.fs_extensions),
                 str(fill.fs_extensions),
                 gpu_shader4 ? "#extension GL_EXT_gpu_shader4 : require\n#define texelFetch texelFetch2D\n#define uint unsigned int\n".ptr : "".ptr,
                 GLAMOR_COMPAT_DEFINES_FS.ptr,
                 str(defines),
                 str(prim.fs_vars),
                 str(fill.fs_vars),
                 fs_vars,
                 str(prim.fs_exec),
                 str(fill.fs_exec),
                 str(combine)) < 0)
        fs_prog_string = null;

    if (!vs_prog_string || !fs_prog_string)
        goto fail;

    prog.prog = glCreateProgram();
static if (DBG) {
    ErrorF("\n\tProgram %d for %s %s\n\tVertex shader:\n\n\t================\n%s\n\n\tFragment Shader:\n\n%s\t================\n",
           prog.prog, prim.name, fill.name, vs_prog_string, fs_prog_string);
}

    prog.flags = flags;
    prog.locations = locations;
    prog.prim_use = prim.use;
    prog.prim_use_render = prim.use_render;
    prog.fill_use = fill.use;
    prog.fill_use_render = fill.use_render;

    vs_prog = glamor_compile_glsl_prog(GL_VERTEX_SHADER, vs_prog_string);
    fs_prog = glamor_compile_glsl_prog(GL_FRAGMENT_SHADER, fs_prog_string);
    glAttachShader(prog.prog, vs_prog);
    glDeleteShader(vs_prog);
    glAttachShader(prog.prog, fs_prog);
    glDeleteShader(fs_prog);
    glBindAttribLocation(prog.prog, GLAMOR_VERTEX_POS, "primitive");

    if (prim.source_name) {
static if (DBG) {
        ErrorF("Bind GLAMOR_VERTEX_SOURCE to %s\n", prim.source_name);
}
        glBindAttribLocation(prog.prog, GLAMOR_VERTEX_SOURCE, prim.source_name);
    }
    if (prog.alpha == glamor_program_alpha_dual_blend) {
        glBindFragDataLocationIndexed(prog.prog, 0, 0, "color0");
        glBindFragDataLocationIndexed(prog.prog, 0, 1, "color1");
    }

    if (!glamor_link_glsl_prog(screen, prog.prog, "%s_%s", prim.name, fill.name))
        goto fail;

    prog.matrix_uniform = glamor_get_uniform(prog, glamor_program_location_none, "v_matrix");
    prog.fg_uniform = glamor_get_uniform(prog, glamor_program_location_fg, "fg");
    prog.bg_uniform = glamor_get_uniform(prog, glamor_program_location_bg, "bg");
    prog.fill_offset_uniform = glamor_get_uniform(prog, glamor_program_location_fillpos, "fill_offset");
    prog.fill_size_inv_uniform = glamor_get_uniform(prog, glamor_program_location_fillpos, "fill_size_inv");
    prog.font_uniform = glamor_get_uniform(prog, glamor_program_location_font, "font");
    prog.bitplane_uniform = glamor_get_uniform(prog, glamor_program_location_bitplane, "bitplane");
    prog.bitmul_uniform = glamor_get_uniform(prog, glamor_program_location_bitplane, "bitmul");
    prog.dash_uniform = glamor_get_uniform(prog, glamor_program_location_dash, "dash");
    prog.dash_length_uniform = glamor_get_uniform(prog, glamor_program_location_dash, "dash_length");
    prog.atlas_uniform = glamor_get_uniform(prog, glamor_program_location_atlas, "atlas");

    free(version_string);
    free(vs_prog_string);
    free(fs_prog_string);
    free(fs_vars);
    free(vs_vars);
    return TRUE;
fail:
    prog.failed = 1;
    if (prog.prog) {
        glDeleteProgram(prog.prog);
        prog.prog = 0;
    }
    free(vs_prog_string);
    free(fs_prog_string);
    free(version_string);
    free(fs_vars);
    free(vs_vars);
    return FALSE;
}

Bool glamor_use_program(DrawablePtr drawable, GCPtr gc, glamor_program* prog, void* arg)
{
    glUseProgram(prog.prog);

    if (prog.prim_use && !prog.prim_use(drawable, gc, prog, arg))
        return FALSE;

    if (prog.fill_use && !prog.fill_use(drawable, gc, prog, arg))
        return FALSE;

    return TRUE;
}

glamor_program* glamor_use_program_fill(DrawablePtr drawable, GCPtr gc, glamor_program_fill* program_fill, const(glamor_facet)* prim)
{
    ScreenPtr screen = drawable.pScreen;
    glamor_program* prog = &program_fill.progs[gc.fillStyle];

    int fill_style = gc.fillStyle;
    const(glamor_facet)* fill = void;

    if (prog.failed)
        return null;

    if (!prog.prog) {
        fill = glamor_facet_fill[fill_style];
        if (!fill)
            return null;

        if (!glamor_build_program(screen, prog, prim, fill, null, null))
            return null;
    }

    if (!glamor_use_program(drawable, gc, prog, null))
        return null;

    return prog;
}

// private blendinfo[14] composite_op_info = [
//     PictOpClear: {0, 0, GL_ZERO, GL_ZERO},
//     PictOpSrc: {0, 0, GL_ONE, GL_ZERO},
//     PictOpDst: {0, 0, GL_ZERO, GL_ONE},
//     PictOpOver: {0, 1, GL_ONE, GL_ONE_MINUS_SRC_ALPHA},
//     PictOpOverReverse: {1, 0, GL_ONE_MINUS_DST_ALPHA, GL_ONE},
//     PictOpIn: {1, 0, GL_DST_ALPHA, GL_ZERO},
//     PictOpInReverse: {0, 1, GL_ZERO, GL_SRC_ALPHA},
//     PictOpOut: {1, 0, GL_ONE_MINUS_DST_ALPHA, GL_ZERO},
//     PictOpOutReverse: {0, 1, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA},
//     PictOpAtop: {1, 1, GL_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA},
//     PictOpAtopReverse: {1, 1, GL_ONE_MINUS_DST_ALPHA, GL_SRC_ALPHA},
//     PictOpXor: {1, 1, GL_ONE_MINUS_DST_ALPHA, GL_ONE_MINUS_SRC_ALPHA},
//     PictOpAdd: {0, 0, GL_ONE, GL_ONE},
// ];

private void glamor_set_blend(CARD8 op, glamor_program_alpha alpha, PicturePtr dst)
{
    glamor_screen_private* glamor_priv = glamor_get_screen_private(dst.pDrawable.pScreen);
    GLenum src_blend = void, dst_blend = void;
    blendinfo* op_info = void;

    switch (alpha) {
    case glamor_program_alpha_ca_first:
        op = PictOpOutReverse;
        break;
    case glamor_program_alpha_ca_second:
        op = PictOpAdd;
        break;
    default:
        break;
    }

    if (!glamor_priv.is_gles)
        glDisable(GL_COLOR_LOGIC_OP);

    if (op == PictOpSrc)
        return;

    op_info = &composite_op_info[op];

    src_blend = op_info.source_blend;
    dst_blend = op_info.dest_blend;

    /* If there's no dst alpha channel, adjust the blend op so that we'll treat
     * it as always 1.
     */
    if (PIXMAN_FORMAT_A(dst.format) == 0 && op_info.dest_alpha) {
        if (src_blend == GL_DST_ALPHA)
            src_blend = GL_ONE;
        else if (src_blend == GL_ONE_MINUS_DST_ALPHA)
            src_blend = GL_ZERO;
    }

    /* Set up the source alpha value for blending in component alpha mode. */
    if (alpha == glamor_program_alpha_dual_blend ||
        alpha == glamor_program_alpha_dual_blend_gles2) {
        switch (dst_blend) {
        case GL_SRC_ALPHA:
            dst_blend = GL_SRC1_COLOR;
            break;
        case GL_ONE_MINUS_SRC_ALPHA:
            dst_blend = GL_ONE_MINUS_SRC1_COLOR;
            break;
        default: break;}
    } else if (alpha != glamor_program_alpha_normal) {
        switch (dst_blend) {
        case GL_SRC_ALPHA:
            dst_blend = GL_SRC_COLOR;
            break;
        case GL_ONE_MINUS_SRC_ALPHA:
            dst_blend = GL_ONE_MINUS_SRC_COLOR;
            break;
        default: break;}
    }

    glEnable(GL_BLEND);
    glBlendFunc(src_blend, dst_blend);
}

private Bool use_source_solid(CARD8 op, PicturePtr src, PicturePtr dst, glamor_program* prog)
{
    PictSolidFill* solid = &src.pSourcePict.solidFill;
    float[4] color = void;

    glamor_get_rgba_from_color(&solid.fullcolor, color.ptr);
    glamor_set_blend(op, prog.alpha, dst);
    glUniform4fv(prog.fg_uniform, 1, color.ptr);

    return TRUE;
}

private const(glamor_facet) glamor_source_solid = {
    name: "render_solid",
    fs_exec: "       vec4 source = fg;\n",
    locations: glamor_program_location_fg,
    use_render: &use_source_solid,
};

private Bool use_source_picture(CARD8 op, PicturePtr src, PicturePtr dst, glamor_program* prog)
{
    glamor_set_blend(op, prog.alpha, dst);

    return glamor_set_texture(cast(PixmapPtr) src.pDrawable,
                              glamor_picture_red_is_alpha(dst),
                              0, 0,
                              prog.fill_offset_uniform,
                              prog.fill_size_inv_uniform);
}

private const(glamor_facet) glamor_source_picture = {
    name: "render_picture",
    vs_exec:  "       fill_pos = (fill_offset + primitive.xy + pos) * fill_size_inv;\n",
    fs_exec:  "       vec4 source = texture(sampler, fill_pos);\n",
    locations: glamor_program_location_fillsamp | glamor_program_location_fillpos,
    use_render: &use_source_picture,
};

private Bool use_source_1x1_picture(CARD8 op, PicturePtr src, PicturePtr dst, glamor_program* prog)
{
    glamor_set_blend(op, prog.alpha, dst);

    return glamor_set_texture_pixmap(cast(PixmapPtr) src.pDrawable,
                                     glamor_picture_red_is_alpha(dst));
}

private const(glamor_facet) glamor_source_1x1_picture = {
    name: "render_picture",
    fs_exec:  "       vec4 source = texture(sampler, vec2(0.5));\n",
    locations: glamor_program_location_fillsamp,
    use_render: &use_source_1x1_picture,
};

private const(glamor_facet)*[glamor_program_source_count] glamor_facet_source = [
    glamor_program_source_solid: &glamor_source_solid,
    glamor_program_source_picture: &glamor_source_picture,
    glamor_program_source_1x1_picture: &glamor_source_1x1_picture,
];

private const(char)*[5] glamor_combine = [
    glamor_program_alpha_normal: "       frag_color = source * mask.a;\n",
    glamor_program_alpha_ca_first: "       frag_color = source.a * mask;\n",
    glamor_program_alpha_ca_second: "       frag_color = source * mask;\n",
    glamor_program_alpha_dual_blend: "      color0 = source * mask;\n"
                                        ~ "      color1 = source.a * mask;\n",
    glamor_program_alpha_dual_blend_gles2: " gl_FragColor = source * mask;\n"
                                              ~ " gl_SecondaryFragColorEXT = source.a * mask;\n"
];

private Bool glamor_setup_one_program_render(ScreenPtr screen, glamor_program* prog, glamor_program_source source_type, glamor_program_alpha alpha, const(glamor_facet)* prim, const(char)* defines)
{
    if (prog.failed)
        return FALSE;

    if (!prog.prog) {
        const(glamor_facet)* fill = glamor_facet_source[source_type];

        if (!fill)
            return FALSE;

        prog.alpha = alpha;
        if (!glamor_build_program(screen, prog, prim, fill, glamor_combine[alpha], defines))
            return FALSE;
    }

    return TRUE;
}

glamor_program* glamor_setup_program_render(CARD8 op, PicturePtr src, PicturePtr mask, PicturePtr dst, glamor_program_render* program_render, const(glamor_facet)* prim, const(char)* defines)
{
    ScreenPtr screen = dst.pDrawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    glamor_program_alpha alpha = void;
    glamor_program_source source_type = void;
    glamor_program* prog = void;

    if (op > mixin(ARRAY_SIZE!("composite_op_info")))
        return null;

    if (glamor_is_component_alpha(mask)) {
        if (glamor_priv.has_dual_blend) {
            alpha = glamor_glsl_has_ints(glamor_priv) ?
                    glamor_program_alpha_dual_blend :
                    glamor_program_alpha_dual_blend_gles2;
        } else {
            /* This only works for PictOpOver */
            if (op != PictOpOver)
                return null;

            alpha = glamor_program_alpha_ca_first;
        }
    } else
        alpha = glamor_program_alpha_normal;

    if (src.pDrawable) {

        /* Can't do transforms, alphamaps or sourcing from non-pixmaps yet */
        if (src.transform || src.alphaMap || src.pDrawable.type != DRAWABLE_PIXMAP)
            return null;

        if (src.pDrawable.width == 1 && src.pDrawable.height == 1 && src.repeat)
            source_type = glamor_program_source_1x1_picture;
        else
            source_type = glamor_program_source_picture;
    } else {
        SourcePictPtr sp = src.pSourcePict;
        if (!sp)
            return null;
        switch (sp.type) {
        case SourcePictTypeSolidFill:
            source_type = glamor_program_source_solid;
            break;
        default:
            return null;
        }
    }

    prog = &program_render.progs[alpha][source_type];
    if (!glamor_setup_one_program_render(screen, prog, source_type, alpha, prim, defines))
        return null;

    if (alpha == glamor_program_alpha_ca_first) {

	  /* Make sure we can also build the second program before
	   * deciding to use this path.
	   */
	  if (!glamor_setup_one_program_render(screen,
					       &program_render.progs[source_type][glamor_program_alpha_ca_second],
					       source_type, glamor_program_alpha_ca_second, prim,
					       defines))
	      return null;
    }
    return prog;
}

Bool glamor_use_program_render(glamor_program* prog, CARD8 op, PicturePtr src, PicturePtr dst)
{
    glUseProgram(prog.prog);

    if (prog.prim_use_render && !prog.prim_use_render(op, src, dst, prog))
        return FALSE;

    if (prog.fill_use_render && !prog.fill_use_render(op, src, dst, prog))
        return FALSE;
    return TRUE;
}
