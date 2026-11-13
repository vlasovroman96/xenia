module evdev_autodetect;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026 stefan11111 <stefan11111@shitposting.expert>
 */

import config.kdrive_config;

import x11.Xdefs;


import core.stdc.stdio;
import core.stdc.stdint;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;

import hw.kdrive.src.kdrive;
import evdev;

enum EVDEV_FMT = "/dev/input/event%d";

enum PROC_DEVICES = "/proc/bus/input/devices";

enum PHYS_MAX = 64 /* Busid + device id */;
enum EVDEV_NAME_MAX = 256;

enum MOUSE_EV = (1 << 2);
enum KBD_EV = 0x120013;

enum {
    EVDEV_KEYBOARD = 0,
    EVDEV_MOUSE = 1,
}

enum NUM_FALLBACK_EVDEV = 32;

/* Simple fallback that was already here */
private char* FallbackEvdevCheck()
{
    char[19] fallback_dev = "/dev/input/eventxx";

    for (int i = 0; i < NUM_FALLBACK_EVDEV; i++) {
        sprintf(fallback_dev.ptr, EVDEV_FMT, i);
        int fd = open(fallback_dev.ptr, O_RDWR);
        if (fd >= 0) {
            close(fd);
            return strdup(fallback_dev.ptr);
        }
    }

    return null;
}

/* All numbers read are in base 16 */
pragma(inline, true) private ulong read_val(const(char)* val)
{
    return strtol(val, null, 16);
}

struct EvdevOptionalInfo {
    uint Bus; /* Bus= */
    uint Vendor; /* Vendor= */
    uint Product; /* Product= */
    uint Version; /* Version= */
}

struct EventDevice {
/**
 * Info that should be unique across physical devices,
 * but not across logical devices.
 */
    EvdevOptionalInfo info; /* I: */
    char[PHYS_MAX] Phys = 0; /* P: Phys = */
 /* char *Sysfs; */ /* S: Sysfs= */
    ulong Uniq; /* U: Uniq= */

    char[EVDEV_NAME_MAX] Name = 0; /* N: Name = */

    int EventNo; /* H: Handlers=... eventxx ... */

    /* If checking for these 2 ever causes problems, remove them */
    int is_mouse; /* H: Handlers=... mousexx ... */
    int is_kbd; /* H: handlers=... kbd ... */

    ulong EV; /* B: EV= */
    int is_read;
}

private EventDevice DefaultPtr;
private EventDevice DefaultKbd;

pragma(inline, true) private void ReadOptInfo(EvdevOptionalInfo* dst, const(char)* data)
{
    const(char)* val = null;

    val = strstr(data, "Bus=");
    if (val) {
        val += (("Bus=") - 1).sizeof;
        dst.Bus = read_val(val);
    }

    val = strstr(data, "Vendor=");
    if (val) {
        val += (("Vendor=") - 1).sizeof;
        dst.Vendor = read_val(val);
    }

    val = strstr(data, "Product=");
    if (val) {
        val += (("Product=") - 1).sizeof;
        dst.Product = read_val(val);
    }

    val = strstr(data, "Version=");
    if (val) {
        val += (("Version=") - 1).sizeof;
        dst.Version = read_val(val);
    }
}

pragma(inline, true) private void ReadName(char* dst, const(char)* data)
{
    char* p = dst;

    data = strstr(data, "Name=");
    if (!data) {
        return;
    }

    data = strchr(data, '"');
    if (!data) {
        return;
    }
    data++;

    while (*data && *data != '"' && p - dst < EVDEV_NAME_MAX - 1) {
        *p = *data;
        p++;
        data++;
    }
    *p = '\0';
}

pragma(inline, true) private void ReadPhys(char* dst, const(char)* data)
{
    char* p = dst;

    data = strstr(data, "Phys=");
    if (!data) {
        return;
    }

    data += (("Phys=") - 1).sizeof;
    while (*data && *data != '/' && p - dst < PHYS_MAX - 1) {
        *p = *data;
        p++;
        data++;
    }
    *p = '\0';
}

pragma(inline, true) private void ReadUniq(ulong* dst, const(char)* data)
{
    data = strstr(data, "Uniq=");
    if (!data) {
        return;
    }

    data += (("Uniq=") - 1).sizeof;
    *dst = read_val(data);
}

pragma(inline, true) private void ReadHandlers(EventDevice* dst, const(char)* data)
{
    dst.is_mouse = !!strstr(data, "mouse");
    dst.is_kbd = !!strstr(data, "kbd");

    data = strstr(data, "event");
    if (!data) {
        /* If this one is missing, we really can't do anything */
        dst.EventNo = -1;
    }

    data += (("event") - 1).sizeof;

    /* This one is base10 */
    dst.EventNo = strtol(data, null, 10);
}

pragma(inline, true) private void ReadEV(ulong* EV, const(char)* data)
{
    data = strstr(data, "EV=");
    if (!data) {
        return;
    }

    data += (("EV=") - 1).sizeof;
    *EV = read_val(data);
}

private Bool ReadEvdev(EventDevice* dst, FILE* f)
{
    for (;;) {
        char* line = null;
        char* end = null;
        char* data = null;
        size_t unused = 0;

        if (getline(&line, &unused, f) < 0) {
            free(line);
            return False;
        }
        end = strchr(line, '\n');
        if (end) {
            *end = '\0';
        }

        if (line[0] == '\0') {
            free(line);
            dst.is_read = True;
            return True;
        }

        if (line[1] != ':'  ||
            line[2] == '\0' || line[3] == '\0') {
            /* Skip this line */
            free(line);
            continue;
        }

        data = line + 3;

        switch (line[0]) {
            case 'I': /* Optional info I: */
                ReadOptInfo(&dst.info, data);
                break;
            case 'N': /* N: Name="..." */
                ReadName(dst.Name, data);
                break;
            case 'P': /* P: Phys= */
                ReadPhys(dst.Phys, data);
                break;
            case 'U': /* U; Uniq= */
                ReadUniq(&dst.Uniq, data);
                break;
            case 'H': /* H: Handlers= */
                ReadHandlers(dst, data);
                break;
            case 'B': /* B: ... */
                ReadEV(&dst.EV, data);
                break;
        default: break;}

        free(line);
    }
}

pragma(inline, true) private Bool EvdevIsKbd(EventDevice* dev)
{
    return dev.is_kbd && ((dev.EV & KBD_EV) == KBD_EV);
}

pragma(inline, true) private Bool EvdevIsPtr(EventDevice* dev)
{
    return dev.is_mouse && ((dev.EV & MOUSE_EV) == MOUSE_EV);
}

private Bool EvdevDifferentDevices(EventDevice* a, EventDevice* b)
{
enum string IS_DIFFERENT(string x, string y) = `(cast(x) && cast(y) && (` ~ x ~ `) != (` ~ y ~ `))`;
enum string IS_DIFF(string f) = `if (` ~ IS_DIFFERENT!(`a.` ~ f ~ ``, `b.` ~ f ~ ``) ~ `) { return True; }`;

    if (!a.is_read || !b.is_read) {
        return True;
    }

    mixin(IS_DIFF!(`Uniq`));

    mixin(IS_DIFF!(`info.Bus`));
    mixin(IS_DIFF!(`info.Vendor`));
    mixin(IS_DIFF!(`info.Product`));
    mixin(IS_DIFF!(`info.Version`));

    if (a.Phys[0] && b.Phys[0] && strcmp(a.Phys, b.Phys)) {
        return True;
    }

    return False;
}

private char* EvdevDefaultDevice(char** name, int type)
{
    char* ret = null;
    FILE* f = null;
    EventDevice read_dev = {0};

    EventDevice* desired = (type == EVDEV_KEYBOARD) ?
                           &DefaultKbd : &DefaultPtr;

    EventDevice* other = (type == EVDEV_KEYBOARD) ?
                         &DefaultPtr : &DefaultKbd;

    if (desired.is_read) {
        if (asprintf(&ret, EVDEV_FMT, desired.EventNo) < 0) {
            return FallbackEvdevCheck();
        }
        return ret;
    }

    f = fopen(PROC_DEVICES, "r");
    if (!f) {
        return FallbackEvdevCheck();
    }

    for (;;) {
        if (feof(f)) {
            fclose(f);
            return FallbackEvdevCheck();
        }

        memset(&read_dev, 0, read_dev.sizeof);

        if (!ReadEvdev(&read_dev, f)) {
            fclose(f);
            return FallbackEvdevCheck();
        }

        if (read_dev.EventNo == -1) {
            continue;
        }

        if (type == EVDEV_KEYBOARD && !EvdevIsKbd(&read_dev)) {
            continue;
        }

        if (type == EVDEV_MOUSE && !EvdevIsPtr(&read_dev)) {
            continue;
        }

        /**
         * Sometimes, modern mice advertise themselved as keyboards.
         * As such, we have to check that the mouse and keyboard
         * are separate physical devices.
         *
         * Keyboards rarely advertise themselves as mice,
         * but it doesn't hurt to check them too.
         */
        if (EvdevDifferentDevices(&read_dev, other)) {
            memcpy(desired, &read_dev, read_dev.sizeof);
            fclose(f);
            if (asprintf(&ret, EVDEV_FMT, desired.EventNo) < 0) {
                return FallbackEvdevCheck();
            }
            if (name && read_dev.Name[0] != '\0') {
                char* old_name = *name;
                *name = strdup(read_dev.Name);
                if (*name) {
                    free(old_name);
                } else {
                    *name = old_name;
                }
            }
            return ret;
        }
    }

    /* Unreachable */
    fclose(f);
    return FallbackEvdevCheck();
}

char* EvdevDefaultKbd(char** name)
{
    return EvdevDefaultDevice(name, EVDEV_KEYBOARD);
}

char* EvdevDefaultPtr(char** name)
{
    return EvdevDefaultDevice(name, EVDEV_MOUSE);
}
