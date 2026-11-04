module glx.extension_string;
@nogc nothrow:
extern(C): __gshared:
/*
 * (C) Copyright IBM Corporation 2002-2006
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * on the rights to use, copy, modify, merge, publish, distribute, sub
 * license, and/or sell copies of the Software, and to permit persons to whom
 * the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDERS AND/OR THEIR SUPPLIERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
 * USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 * \file extension_string.c
 * Routines to manage the GLX extension string and GLX version for AIGLX
 * drivers.  This code is loosely based on src/glx/X11/glxextensions.c from
 * Mesa.
 *
 * \author Ian Romanick <idr@us.ibm.com>
 */

import build.dix_config;

import dix.dix_priv;
import os.utils;

import glx.extension_string;

import std.meta : AliasSeq;

enum __GLX_EXT_BYTES = ((__NUM_GLX_EXTS + 7) / 8);

enum SET_BIT(string m, string b) =    `(`~m~`[ (`~b~`) / 8 ] |=  (1U << ((`~b~`) % 8)))`;
// enum CLR_BIT(string m, string b)    (m[ (b) / 8 ] &= ~(1U << ((b) % 8)))
enum IS_SET(string m, string b) =   `((`~m~`[ (`~b~`) / 8 ] &   (1U << ((`~b~`) % 8))) != 0)`;
// enum CONCAT(a,b) a ## b
// enum GLX(n) "GLX_" # n, 4 + sizeof( # n ) - 1, CONCAT(n,_bit)
// enum VER(a,b)  a, b
// enum Y  1
// enum N  0
enum EXT_ENABLED(string bit, string supported) = (IS_SET!(supported, bit));

enum {
/*   GLX_ARB_get_proc_address is implemented on the client. */
    ARB_context_flush_control_bit = 0,
    ARB_create_context_bit,
    ARB_create_context_no_error_bit,
    ARB_create_context_profile_bit,
    ARB_create_context_robustness_bit,
    ARB_fbconfig_float_bit,
    ARB_framebuffer_sRGB_bit,
    ARB_multisample_bit,
    EXT_create_context_es_profile_bit,
    EXT_create_context_es2_profile_bit,
    EXT_fbconfig_packed_float_bit,
    EXT_get_drawable_type_bit,
    EXT_import_context_bit,
    EXT_libglvnd_bit,
    EXT_no_config_context_bit,
    EXT_stereo_tree_bit,
    EXT_texture_from_pixmap_bit,
    EXT_visual_info_bit,
    EXT_visual_rating_bit,
    MESA_copy_sub_buffer_bit,
    OML_swap_method_bit,
    SGI_make_current_read_bit,
    SGI_swap_control_bit,
    SGI_video_sync_bit,
    SGIS_multisample_bit,
    SGIX_fbconfig_bit,
    SGIX_pbuffer_bit,
    SGIX_visual_select_group_bit,
    INTEL_swap_event_bit,
    __NUM_GLX_EXTS,
};

alias EXT_framebuffer_sRGB_bit = ARB_framebuffer_sRGB_bit;

struct extension_info {
    const(char*) name;
    uint name_len;
    ubyte bit;
    ubyte version_major;
    ubyte version_minor;
    ubyte driver_support;
}
// 1. Превращаем функцию в шаблон времени компиляции
// Переносим имя расширения 'n' в шаблонные аргументы. 
// Благодаря этому 'n' гарантированно доступен для mixin во время сборки!
extension_info GLX(string n)(ubyte major = 0, ubyte minor = 0, ubyte driver_support = 0)
{
    // Склеивание имени бита теперь работает идеально
    enum ubyte bitValue = cast(ubyte) mixin(n ~ "_bit");
    
    // Используем статическую константу, чтобы строка выделилась в сегменте данных (ноль GC!)
    enum string fullStr = "GLX_" ~ n ~ "\0";

    return extension_info(
        fullStr.ptr,                  // name: честный char* без аллокаций
        cast(uint)(4 + n.length),     // name_len
        bitValue,                     // bit
        major,                        // version_major
        minor,                        // version_minor
        driver_support                // driver_support
    );
}

// Константы для читаемости
enum ubyte Y = 1;
enum ubyte N = 0;

private const(extension_info)[30] known_glx_extensions = [
    /* *INDENT-OFF* */
    // Теперь передаем имя через восклицательный знак: GLX!"ИМЯ"(аргументы)
    GLX!"ARB_context_flush_control"(0, 0, N),
    GLX!"ARB_create_context"(0, 0, N),
    GLX!"ARB_create_context_no_error"(0, 0, N),
    GLX!"ARB_create_context_profile"(0, 0, N),
    GLX!"ARB_create_context_robustness"(0, 0, N),
    GLX!"ARB_fbconfig_float"(0, 0, N),
    GLX!"ARB_framebuffer_sRGB"(0, 0, N),
    GLX!"ARB_multisample"(1, 4, Y),

    GLX!"EXT_create_context_es_profile"(0, 0, N),
    GLX!"EXT_create_context_es2_profile"(0, 0, N),
    GLX!"EXT_fbconfig_packed_float"(0, 0, N),
    GLX!"EXT_framebuffer_sRGB"(0, 0, N),
    GLX!"EXT_get_drawable_type"(0, 0, Y),
    GLX!"EXT_import_context"(0, 0, N),
    GLX!"EXT_libglvnd"(0, 0, N),
    GLX!"EXT_no_config_context"(0, 0, N),
    GLX!"EXT_stereo_tree"(0, 0, N),
    GLX!"EXT_texture_from_pixmap"(0, 0, N),
    GLX!"EXT_visual_info"(0, 0, Y),
    GLX!"EXT_visual_rating"(0, 0, Y),

    GLX!"MESA_copy_sub_buffer"(0, 0, N),
    GLX!"OML_swap_method"(0, 0, Y),
    GLX!"SGI_make_current_read"(1, 3, Y),
    GLX!"SGI_swap_control"(0, 0, N),
    GLX!"SGIS_multisample"(0, 0, Y),
    GLX!"SGIX_fbconfig"(1, 3, Y),
    GLX!"SGIX_pbuffer"(1, 3, Y),
    GLX!"SGIX_visual_select_group"(0, 0, Y),
    GLX!"INTEL_swap_event"(0, 0, N),
    
    extension_info(null, 0, 0, 0, 0, 0)
    /* *INDENT-ON* */
];
/**
 * Create a GLX extension string for a set of enable bits.
 *
 * Creates a GLX extension string for the set of bit in \c enable_bits.  This
 * string is then stored in \c buffer if buffer is not \c NULL.  This allows
 * two-pass operation.  On the first pass the caller passes \c NULL for
 * \c buffer, and the function determines how much space is required to store
 * the extension string.  The caller allocates the buffer and calls the
 * function again.
 *
 * \param enable_bits  Bits representing the enabled extensions.
 * \param buffer       Buffer to store the extension string.  May be \c NULL.
 *
 * \return
 * The number of characters in \c buffer that were written to.  If \c buffer
 * is \c NULL, this is the size of buffer that must be allocated by the
 * caller.
 */
int __glXGetExtensionString(const(ubyte)* enable_bits, char* buffer)
{
    uint i = void;
    int length = 0;

    for (i = 0; known_glx_extensions[i].name !is null; i++) {
        const(uint) bit = known_glx_extensions[i].bit;
        const(size_t) len = known_glx_extensions[i].name_len;

        if (mixin(EXT_ENABLED!(`bit`, `enable_bits`))) {
            if (buffer !is null) {
                cast(void) memcpy(&buffer[length], known_glx_extensions[i].name,
                              len);

                buffer[length + len + 0] = ' ';
                buffer[length + len + 1] = '\0';
            }

            length += len + 1;
        }
    }

    return length + 1;
}

void __glXEnableExtension(ubyte* enable_bits, const(char)* ext)
{
    const(size_t) ext_name_len = strlen(ext);
    uint i = void;

    for (i = 0; known_glx_extensions[i].name !is null; i++) {
        if ((ext_name_len == known_glx_extensions[i].name_len)
            && (memcmp(ext, known_glx_extensions[i].name, ext_name_len) == 0)) {
            mixin(SET_BIT!(`enable_bits`, `known_glx_extensions[i].bit`)~";");
            break;
        }
    }
}

void __glXInitExtensionEnableBits(ubyte* enable_bits)
{
    uint i = void;

    cast(void) memset(enable_bits, 0, __GLX_EXT_BYTES);

    for (i = 0; known_glx_extensions[i].name !is null; i++) {
        if (known_glx_extensions[i].driver_support) {
            mixin(SET_BIT!(`enable_bits`, `known_glx_extensions[i].bit`)~";");
        }
    }

    if (enableIndirectGLX)
        __glXEnableExtension(enable_bits, "GLX_EXT_import_context");
}
