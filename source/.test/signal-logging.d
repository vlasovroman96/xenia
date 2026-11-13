module test.signal_logging;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/**
 * Copyright © 2012 Canonical, Ltd.
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
import core.sys.posix.unistd;

import os.fmt;
import os.log_priv;

// import assert;

import test.tests_common;
import test.tests;


struct number_format_test {
    ulong number;
    char[21] string = 0;
    char[17] hex_string = 0;
}

struct signed_number_format_test {
    long number;
    char[21] string = 0;
}

struct float_number_format_test {
    double number = 0;
    char[21] string = 0;
}

private Bool check_signed_number_format_test(c_long number)
{
    char[21] string = void;
    char[21] expected = void;

    sprintf(expected.ptr, "%ld", number);
    FormatInt64(number, string.ptr);
    if(strncmp(string.ptr, expected.ptr, 21) != 0) {
        fprintf(stderr, "Failed to convert %jd to decimal string (expected %s but got %s)\n",
                cast(intmax_t) number, expected.ptr, string.ptr);
        return False;
    }

    return True;
}

private Bool check_float_format_test(double number)
{
    char[21] string = void;
    char[21] expected = void;

    /* we currently always print float as .2f */
    sprintf(expected.ptr, "%.2f", number);

    FormatDouble(number, string.ptr);
    if(strncmp(string.ptr, expected.ptr, 21) != 0) {
        fprintf(stderr, "Failed to convert %f to string (%s vs %s)\n",
                number, expected.ptr, string.ptr);
        return False;
    }

    return True;
}

private Bool check_number_format_test(c_ulong number)
{
    char[21] string = void;
    char[21] expected = void;

    sprintf(expected.ptr, "%lu", number);

    FormatUInt64(number, string.ptr);
    if(strncmp(string.ptr, expected.ptr, 21) != 0) {
        fprintf(stderr, "Failed to convert %ju to decimal string (%s vs %s)\n",
                cast(intmax_t) number, expected.ptr, string.ptr);
        return False;
    }

    sprintf(expected.ptr, "%lx", number);
    FormatUInt64Hex(number, string.ptr);
    if(strncmp(string.ptr, expected.ptr, 17) != 0) {
        fprintf(stderr, "Failed to convert %ju to hexadecimal string (%s vs %s)\n",
                cast(intmax_t) number, expected.ptr, string.ptr);
        return False;
    }

    return True;
}

/* FIXME: max range stuff */
double[10] float_tests = [ 0, 5, 0.1, 0.01, 5.2342, 10.2301,
                         -1, -2.00, -0.6023, -1203.30
                        ];

// #pragma GCC diagnostic push
// #pragma GCC diagnostic ignored "-Woverflow"

private void number_formatting()
{
    int i = void;
    c_ulong[8] unsigned_tests = [ 0,/* Zero */
                                           5, /* Single digit number */
                                           12, /* Two digit decimal number */
                                           37, /* Two digit hex number */
                                           0xC90B2, /* Large < 32 bit number */
                                           0x15D027BF211B37A, /* Large > 32 bit number */
                                           0xFFFFFFFFFFFFFFFF, /* Maximum 64-bit number */
    ];

    c_long[13] signed_tests = [ 0,/* Zero */
                                5, /* Single digit number */
                                12, /* Two digit decimal number */
                                37, /* Two digit hex number */
                                0xC90B2, /* Large < 32 bit number */
                                0x15D027BF211B37A, /* Large > 32 bit number */
                                0x7FFFFFFFFFFFFFFF, /* Maximum 64-bit signed number */
                                -1, /* Single digit number */
                                -12, /* Two digit decimal number */
                                -0xC90B2, /* Large < 32 bit number */
                                -0x15D027BF211B37A, /* Large > 32 bit number */
                                -0x7FFFFFFFFFFFFFFF, /* Maximum 64-bit signed number */
    ];

    xorgLogVerbosity = -1;

    for (i = 0; i < unsigned_tests.length; i++)
        assert(check_number_format_test(unsigned_tests[i]));

    for (i = 0; i < signed_tests.length; i++)
        assert(check_signed_number_format_test(signed_tests[i]));

    for (i = 0; i < float_tests.length; i++)
        assert(check_float_format_test(float_tests[i]));
}
// #pragma GCC diagnostic pop

// #pragma GCC diagnostic push
// #pragma GCC diagnostic ignored "-Wformat-security"
// #pragma GCC diagnostic ignored "-Wformat"
// #pragma GCC diagnostic ignored "-Wformat-extra-args"
private void logging_format()
{
    const(char)* log_file_path = "/tmp/Xorg-logging-test.log";
    const(char)* str = "%s %d %u %% %p %i";
    char[1024] buf = void;
    int i = void;
    uint ui = void;
    c_long li = void;
    c_ulong lui = void;
    FILE* f = void;
    char[2048] read_buf = void;
    char* logmsg = void;
    uintptr_t ptr = void;
    char* fname = null;

    xorgLogVerbosity = -1;

    /* set up buf to contain ".....end" */
    memset(buf.ptr, '.', buf.sizeof);
    strcpy(&buf[((buf).ptr - 4).sizeof], "end");

    fname = cast(char*)LogInit(log_file_path, null);
    assert(fname !is null);
    assert((f = fopen(log_file_path, "r")));
    free(fname);

enum string read_log_msg(string msg) = `do {                                  
        ` ~ msg ~ ` = fgets(read_buf.ptr, read_buf.sizeof, f);             
        assert(` ~ msg ~ ` !is null);                                   
        ` ~ msg ~ ` = strchr(read_buf.ptr, ']');                            
        assert(` ~ msg ~ ` !is null);                                    
        assert(strlen(` ~ msg ~ `) > 2);                                
        ` ~ msg ~ ` = ` ~ msg ~ ` + 2; /* advance past [time.stamp] */          
    } while (0)`;

    /* boring test message */
    LogMessageVerb(X_ERROR, 1, "test message\n");
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) test message\n") == 0);

    /* long buf is truncated to "....en\n" */
    LogMessageVerb(X_ERROR, 1, buf);
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(&logmsg[strlen(logmsg) - 3], "en\n") == 0);

    /* same thing, this time as string substitution */
    LogMessageVerb(X_ERROR, 1, "%s", buf);
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(&logmsg[strlen(logmsg) - 3], "en\n") == 0);

    /* strings containing placeholders should just work */
    LogMessageVerb(X_ERROR, 1, "%s\n", str);
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) %s %d %u %% %p %i\n") == 0);

    /* literal % */
    LogMessageVerb(X_ERROR, 1, "test %%\n");
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) test %\n") == 0);

    /* character */
    LogMessageVerb(X_ERROR, 1, "test %c\n", 'a');
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) test a\n") == 0);

    /* something unsupported % */
    LogMessageVerb(X_ERROR, 1, "test %Q\n");
    mixin(read_log_msg!(`logmsg`));
    assert(strstr(logmsg, "BUG") !is null);
    LogMessageVerb(X_ERROR, 1, "\n");
    fseek(f, 0, SEEK_END);

    /* string substitution */
    LogMessageVerb(X_ERROR, 1, "%s\n", "substituted string");
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) substituted string\n") == 0);

    /* Invalid format */
    LogMessageVerb(X_ERROR, 1, "%4", 4);
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) ") == 0);
    LogMessageVerb(X_ERROR, 1, "\n");
    fseek(f, 0, SEEK_END);

    /* %hld is bogus */
    LogMessageVerb(X_ERROR, 1, "%hld\n", 4);
    mixin(read_log_msg!(`logmsg`));
    assert(strstr(logmsg, "BUG") !is null);
    LogMessageVerb(X_ERROR, 1, "\n");
    fseek(f, 0, SEEK_END);

    /* number substitution */
    ui = 0;
    do {
        char[30] expected = 0;
        sprintf(expected.ptr, "(EE) %u\n", ui);
        LogMessageVerb(X_ERROR, 1, "%u\n", ui);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %x\n", ui);
        LogMessageVerb(X_ERROR, 1, "%x\n", ui);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        if (ui == 0)
            ui = 1;
        else
            ui <<= 1;
    } while(ui);

    lui = 0;
    do {
        char[30] expected = 0;
        sprintf(expected.ptr, "(EE) %lu\n", lui);
        LogMessageVerb(X_ERROR, 1, "%lu\n", lui);
        mixin(read_log_msg!(`logmsg`));

        sprintf(expected.ptr, "(EE) %lld\n", cast(ulong)ui);
        LogMessageVerb(X_ERROR, 1, "%lld\n", cast(ulong)ui);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %lx\n", lui);
        LogMessageVerb(X_ERROR, 1, "%lx\n", lui);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %llx\n", cast(ulong)ui);
        LogMessageVerb(X_ERROR, 1, "%llx\n", cast(ulong)ui);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        if (lui == 0)
            lui = 1;
        else
            lui <<= 1;
    } while(lui);

    /* signed number substitution */
    i = 0;
    do {
        char[30] expected = 0;
        sprintf(expected.ptr, "(EE) %d\n", i);
        LogMessageVerb(X_ERROR, 1, "%d\n", i);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %d\n", i | INT_MIN);
        LogMessageVerb(X_ERROR, 1, "%d\n", i | INT_MIN);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        if (i == 0)
            i = 1;
        else
            i <<= 1;
    } while(i > INT_MIN);

    li = 0;
    do {
        char[30] expected = 0;
        sprintf(expected.ptr, "(EE) %ld\n", li);
        LogMessageVerb(X_ERROR, 1, "%ld\n", li);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %ld\n", li | LONG_MIN);
        LogMessageVerb(X_ERROR, 1, "%ld\n", li | LONG_MIN);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %lld\n", cast(long)li);
        LogMessageVerb(X_ERROR, 1, "%lld\n", cast(long)li);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        sprintf(expected.ptr, "(EE) %lld\n", cast(long)(li | LONG_MIN));
        LogMessageVerb(X_ERROR, 1, "%lld\n", cast(long)(li | LONG_MIN));
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        if (li == 0)
            li = 1;
        else
            li <<= 1;
    } while(li > LONG_MIN);


    /* pointer substitution */
    /* we print a null-pointer differently to printf */
    LogMessageVerb(X_ERROR, 1, "%p\n", null);
    mixin(read_log_msg!(`logmsg`));
    assert(strcmp(logmsg, "(EE) 0x0\n") == 0);

    ptr = 1;
    do {
        char[30] expected = 0;
version (__sun) { /* Solaris doesn't autoadd "0x" to %p format */
        sprintf(expected.ptr, "(EE) 0x%p\n", cast(void*)ptr);
} else {
        sprintf(expected.ptr, "(EE) %p\n", cast(void*)ptr);
}
        LogMessageVerb(X_ERROR, 1, "%p\n", cast(void*)ptr);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);
        ptr <<= 1;
    } while(ptr);


    for (i = 0; i < float_tests.length; i++) {
        double d = float_tests[i];
        char[30] expected = 0;
        sprintf(expected.ptr, "(EE) %.2f\n", d);
        LogMessageVerb(X_ERROR, 1, "%f\n", d);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        /* test for length modifiers, we just ignore them atm */
        LogMessageVerb(X_ERROR, 1, "%.3f\n", d);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        LogMessageVerb(X_ERROR, 1, "%3f\n", d);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);

        LogMessageVerb(X_ERROR, 1, "%.0f\n", d);
        mixin(read_log_msg!(`logmsg`));
        assert(strcmp(logmsg, expected.ptr) == 0);
    }

    if (f)
        fclose(f);

    LogClose(EXIT_NO_ERROR);
    unlink(log_file_path);

}
// #pragma GCC diagnostic pop /* "-Wformat-security" */

const(testfunc_t)* signal_logging_test()
{
    static const(testfunc_t)[4] testfuncs = [
        number_formatting,
        logging_format,
        null,
    ];
    return testfuncs;
}
