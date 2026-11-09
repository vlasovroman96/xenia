module xf86Parser_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 1997 Metro Link Incorporated
 */
 
public import core.stdc.stdlib;

public import hw.xfree86.parser.xf86Parser;

// void xf86initConfigFiles();
// char* xf86openConfigFile(const(char)* path, const(char)* cmdline, const(char)* projroot);
// char* xf86openConfigDirFiles(const(char)* path, const(char)* cmdline, const(char)* projroot);
// void xf86setBuiltinConfig(const(char)** config);
// XF86ConfigPtr xf86readConfigFile();
// void xf86closeConfigFile();
XF86ConfigPtr xf86allocateConfig();
void xf86freeConfig(XF86ConfigPtr p);
int xf86writeConfigFile(const(char)* filename, XF86ConfigPtr cptr);
// int xf86layoutAddInputDevices(XF86ConfigPtr config, XF86ConfLayoutPtr layout);

pragma(inline, true) void xf86freeMatchGroup(xf86MatchGroup* group)
{
    group.entry.removeFromList();
    foreach(pattern; group.patterns.byEntriesSafe!(xf86MatchPattern, "entry")){
        pattern.entry.removeFromList();
        if (pattern.str)
            free(pattern.str);
        free(pattern);
    }
    free(group);
}

pragma(inline, true) void xf86freeMatchGroupList(XList* grouplist) {
    foreach(group; grouplist.byEntriesSafe!(xf86MatchGroup, "entry")) {
        xf86freeMatchGroup(group);
    }
}

 /* _XSERVER_XF86_PARSER_PRIV */
