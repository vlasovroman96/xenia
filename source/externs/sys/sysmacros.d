module externs.sys.sysmacros;

import core.sys.posix.sys.types : dev_t;

extern(C) nothrow @nogc
{
    uint gnu_dev_major(dev_t dev);
    uint gnu_dev_minor(dev_t dev);
    dev_t gnu_dev_makedev(uint major, uint minor);
}

alias major = gnu_dev_major;
alias minor = gnu_dev_minor;
alias makedev = gnu_dev_makedev;