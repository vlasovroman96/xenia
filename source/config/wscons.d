module config.wscons;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2011 Matthieu Herrb
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
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import build.dix_config;

import core.sys.posix.sys.time;
// if(HasVersion!"OpenBSD") {
// import dev.wscons.wsconsio;
// import dev.wscons.wsksymdef;
// }

import core.sys.posix.sys.ioctl;
import core.stdc.errno;
import core.sys.posix.fcntl;
import core.stdc.string;
import core.sys.posix.unistd;

import dix.input;
import dix.inputstr;import include.os;
import config.config_backends;
import externs.gnu;
import dix.inpututils;
import os.log;

enum KB_OVRENC = nameint.init; // Пустой элемент-заглушка

enum int KB_UK = 0x0100; // Типичное значение маски для британской раскладки в wscons
enum int KB_DE = 0x0200; // Немецкая
enum int KB_FR = 0x0300; // Французская (если компилятор ругнется на неё дальше)
enum int KB_US = 0x0000; // Американская по умолчанию

enum KB_NODEAD       = 0x00010000; // Отключение dead accents
enum KB_DECLK        = 0x00020000;
enum KB_DVORAK       = 0x00040000;
enum KB_METAESC      = 0x00080000;
enum KB_SWAPCTRLCAPS = 0x00100000;

enum KB_USER         = 0x0000;
// enum KB_US           = 0x0100;
// enum KB_DE           = 0x0200;
// enum KB_FR           = 0x0300;
enum KB_DK           = 0x0400;
enum KB_IT           = 0x0500;
enum KB_NO           = 0x0600;
// enum KB_SV           = 0x0700;
enum KB_FI           = 0x0800;
// enum KB_UK           = 0x0900;
enum KB_JP           = 0x0a0a;
enum KB_SV_NODEAD    = KB_SV | KB_NODEAD;
enum KB_SG           = 0x0d00; // Swiss German
enum KB_SF           = 0x0e00; // Swiss French
enum KB_CF = 0x0f00; // Canadian French

// Типы клавиатур из системного заголовка wsconsio.h
enum WSKBD_TYPE_PCXT      = 1;
enum WSKBD_TYPE_PCAT      = 2;
enum WSKBD_TYPE_USB       = 3;
enum WSKBD_TYPE_HIL       = 4;
enum WSKBD_TYPE_LK201     = 5;
enum WSKBD_TYPE_SUN       = 6;
enum WSKBD_TYPE_SUN5      = 7;
enum WSKBD_TYPE_ADB       = 8;
enum WSKBD_TYPE_NEXT      = 9;
enum WSKBD_TYPE_GIO       = 10;
enum WSKBD_TYPE_LK401     = 11;
enum WSKBD_TYPE_MAPLE     = 12;

// Целевая константа для Sharp Zaurus
enum WSKBD_TYPE_ZAURUS    = 13; 

enum WSCONS_KBD_DEVICE = "/dev/wskbd";
enum WSCONS_MOUSE_PREFIX = "/dev/wsmouse";

struct nameint {
    int val;
    string name; // В D строки — это string
}

// === 2. Заглушки отсутствующих констант ядра BSD ===
// enum KB_UK = 256;
// enum KB_DE = 257;
enum KB_SV = 258; // Шведская раскладка (добавлено)
// enum KB_SG = 259; // Швейцарская немецкая (добавлено)

// KB_ENCTAB в оригинале — это макрос-список, заменяем на массив заглушек
enum nameint[] KB_ENCTAB = [
    nameint(KB_UK, "gb"),
    nameint(KB_DE, "de")
];
// ==========================================

// === 3. Правильное объявление массива ===
// Убедитесь, что kbdenc объявлен именно как nameint[], а не int[]!
// nameint[] kbdenc = [
//     nameint( KB_UK, "gb" ), 
//     nameint( KB_SV, "se" ), 
//     nameint( KB_SG, "ch" )
//     // ... остальные элементы массива перепишите в формате nameint(КОД, "СТРОКА"),
// ];

nameint[] kbdenc = [
    nameint(KB_UK, "gb"),
    nameint(KB_DE, "de"),
    nameint(KB_SV, "se"),
    nameint(KB_SG, "ch"),
    // Если ниже в оригинальном коде были другие элементы, запишите их так же: nameint(КОД, "ИМЯ"),
    
    nameint(0, null) // Финальный нулевой элемент-терминатор из Си кода
];

// version(NetBSD) {
//     enum nameint[3] kbdenc = [
//         KB_OVRENC,
//         KB_ENCTAB,
//         {0}
//     ];
// }
// else {
//     enum nameint[3] kbdenc = [
//         KB_OVRENC,
//         KB_ENCTAB
//     ];
// }

nameint[9] kbdvar = [
    {KB_NODEAD | KB_SG, "de_nodeadkeys"},
    {KB_NODEAD | KB_SF, "fr_nodeadkeys"},
    {KB_SF, "fr"},
    {KB_DVORAK | KB_CF, "fr-dvorak"},
    {KB_DVORAK | KB_FR, "bepo"},
    {KB_DVORAK, "dvorak"},
    {KB_CF, "fr-legacy"},
    {KB_NODEAD, "nodeadkeys"},
    {0}
];

nameint[2] kbdopt = [
    {KB_SWAPCTRLCAPS, "ctrl:swapcaps"},
    {0}
];

nameint[2] kbdmodel = [
    {WSKBD_TYPE_ZAURUS, "zaurus"},
    {0}
];

// private void wscons_add_keyboard()
// {
//     InputAttributes attrs = { };
//     DeviceIntPtr dev = null;
//     InputOption* input_options = null;
//     char* config_info = null;
//     int fd = void, i = void, rc = void;
//     uint type = void;
//     kbd_t wsenc = 0;

//     /* Find keyboard configuration */
//     fd = open(WSCONS_KBD_DEVICE, O_RDWR | O_NONBLOCK | O_EXCL);
//     if (fd == -1) {
//         LogMessage(X_ERROR, "wskbd: open %s: %s\n",
//                    WSCONS_KBD_DEVICE, strerror(errno));
//         return;
//     }
//     if (ioctl(fd, WSKBDIO_GETENCODING, &wsenc) == -1) {
//         LogMessage(X_WARNING, "wskbd: ioctl(WSKBDIO_GETENCODING) "
//                    ~ "failed: %s\n", strerror(errno));
//         close(fd);
//         return;
//     }
//     if (ioctl(fd, WSKBDIO_GTYPE, &type) == -1) {
//         LogMessage(X_WARNING, "wskbd: ioctl(WSKBDIO_GTYPE) "
//                    ~ "failed: %s\n", strerror(errno));
//         close(fd);
//         return;
//     }
//     close(fd);

//     input_options = input_option_new(input_options, "_source", "server/wscons");
//     if (input_options is null)
//         return;

//     LogMessage(X_INFO, "config/wscons: checking input device %s\n",
//                WSCONS_KBD_DEVICE);
//     input_options = input_option_new(input_options, "name", WSCONS_KBD_DEVICE);
//     input_options = input_option_new(input_options, "driver", "kbd");

//     if (asprintf(&config_info, "wscons:%s", WSCONS_KBD_DEVICE) == -1)
//         goto unwind;
//     if (KB_ENCODING(wsenc) == KB_USER) {
//         /* Ignore wscons "user" layout */
//         LogMessageVerb(X_INFO, 3, "wskbd: ignoring \"user\" layout\n");
//         goto kbd_config_done;
//     }
//     for (i = 0; kbdenc[i].val; i++)
//         if (KB_ENCODING(wsenc) == kbdenc[i].val) {
//             LogMessageVerb(X_INFO, 3, "wskbd: using layout %s\n",
//                            kbdenc[i].name);
//             input_options = input_option_new(input_options,
//                                              "xkb_layout", kbdenc[i].name);
//             break;
//         }
//     for (i = 0; kbdvar[i].val; i++)
//         if (wsenc == kbdvar[i].val || KB_VARIANT(wsenc) == kbdvar[i].val) {
//             LogMessageVerb(X_INFO, 3, "wskbd: using variant %s\n",
//                            kbdvar[i].name);
//             input_options = input_option_new(input_options,
//                                              "xkb_variant", kbdvar[i].name);
//             break;
//         }
//     for (i = 0; kbdopt[i].val; i++)
//         if (KB_VARIANT(wsenc) == kbdopt[i].val) {
//             LogMessageVerb(X_INFO, 3, "wskbd: using option %s\n",
//                            kbdopt[i].name);
//             input_options = input_option_new(input_options,
//                                              "xkb_options", kbdopt[i].name);
//             break;
//         }
//     for (i = 0; kbdmodel[i].val; i++)
//         if (type == kbdmodel[i].val) {
//             LogMessageVerb(X_INFO, 3, "wskbd: using model %s\n",
//                            kbdmodel[i].name);
//             input_options = input_option_new(input_options,
//                                              "xkb_model", kbdmodel[i].name);
//             break;
//         }

//  kbd_config_done:
//     attrs.flags |= ATTR_KEY | ATTR_KEYBOARD;
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
//     rc = NewInputDeviceRequest(input_options, &attrs, &dev);
//     if (rc != Success)
//         goto unwind;

//     for (; dev; dev = dev.next) {
//         free(dev.config_info);
//         dev.config_info = strdup(config_info);
//     }
//  unwind:
//     input_option_free_list(&input_options);
// }

// private void wscons_add_pointer(const(char)* path, const(char)* driver, int flags)
// {
//     InputAttributes attrs = { };
//     DeviceIntPtr dev = null;
//     InputOption* input_options = null;
//     char* config_info = null;
//     int rc = void;

//     if (asprintf(&config_info, "wscons:%s", path) == -1)
//         return;

//     input_options = input_option_new(input_options, "_source", "server/wscons");
//     if (input_options is null)
//         return;

//     input_options = input_option_new(input_options, "name", strdup(path));
//     input_options = input_option_new(input_options, "driver", strdup(driver));
//     input_options = input_option_new(input_options, "device", strdup(path));
//     LogMessage(X_INFO, "config/wscons: checking input device %s\n", path);
//     attrs.flags |= flags;
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
//     rc = NewInputDeviceRequest(input_options, &attrs, &dev);
//     if (rc != Success)
//         goto unwind;

//     for (; dev; dev = dev.next) {
//         free(dev.config_info);
//         dev.config_info = strdup(config_info);
//     }
//  unwind:
//     input_option_free_list(&input_options);
// }

// private void wscons_add_pointers()
// {
//     char[256] devname = void;
//     int fd = void, i = void, wsmouse_type = void;

//     /* Check pointing devices */
//     for (i = 0; i < 4; i++) {
//         // snprintf(devname.ptr, devname.sizeof, "%s%d", WSCONS_MOUSE_PREFIX, i);
//         LogMessageVerb(X_INFO, 10, "wsmouse: checking %s\n", devname.ptr);
// version (HAVE_OPEN_DEVICE) {
//         fd = open_device(devname.ptr, O_RDWR | O_NONBLOCK | O_EXCL);
// } else {
//         fd = open(devname.ptr, O_RDWR | O_NONBLOCK | O_EXCL);
// }
//         if (fd == -1) {
//             LogMessageVerb(X_WARNING, 10, "%s: %s\n", devname.ptr, strerror(errno));
//             continue;
//         }
//         if (ioctl(fd, WSMOUSEIO_GTYPE, &wsmouse_type) != 0) {
//             LogMessageVerb(X_WARNING, 10,
//                            "%s: WSMOUSEIO_GTYPE failed\n", devname.ptr);
//             close(fd);
//             continue;
//         }
//         close(fd);
//         switch (wsmouse_type) {
// version (WSMOUSE_TYPE_SYNAPTICS) {
//         case WSMOUSE_TYPE_SYNAPTICS:
//             wscons_add_pointer(devname.ptr, "synaptics", ATTR_TOUCHPAD);
//             break;
// }
//         case WSMOUSE_TYPE_TPANEL:
//             wscons_add_pointer(devname.ptr, "ws", ATTR_TOUCHSCREEN);
//             break;
//         default:
//             break;
//         }
//     }
//     /* Add a default entry catching all other mux elements as pointers */
//     wscons_add_pointer(WSCONS_MOUSE_PREFIX, "ws", ATTR_POINTER);
// }

// int config_wscons_init()
// {
//     wscons_add_keyboard();
//     wscons_add_pointers();
//     return 1;
// }

void config_wscons_fini()
{
    /* Not much to do ? */
}
