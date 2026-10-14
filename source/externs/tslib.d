module externs.tslib;

extern(C):
@nogc: nothrow:

/*
 *  tslib/src/tslib.h
 *
 *  Copyright (C) 2016 Martin Kepplinger <martink@posteo.de>
 *  Copyright (C) 2001 Russell King.
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 *
 * Touch screen library interface definitions.
 */
 
import core.stdc.stdarg;
import core.sys.posix.sys.time;

struct tsdev;

struct ts_sample {
	int		x;
	int		y;
	uint	pressure;
	timeval	tv;
};

struct ts_sample_mt {
	/* ABS_MT_* event codes. linux/include/uapi/linux/input-event-codes.h
	 * has the definitions.
	 */
	int		x;
	int		y;
	uint	pressure;
	int		slot;
	int		tracking_id;

	int		tool_type;
	int		tool_x;
	int		tool_y;
	uint	touch_major;
	uint	width_major;
	uint	touch_minor;
	uint	width_minor;
	int		orientation;
	int		distance;
	int		blob_id;

	timeval	tv;

	/* BTN_TOUCH state */
	short		pen_down;

	/* valid is set != 0 if this sample
	 * contains new data; see below for the
	 * bits that get set.
	 * valid is set to 0 otherwise
	 */
	short		valid;
};

enum TSLIB_MT_VALID =			(1 << 0);	/* any new data */
enum TSLIB_MT_VALID_TOOL =		(1 << 1);	/* new tool_x or tool_y data */

struct ts_lib_version_data {
	const char	*package_version;
	int		version_num;
	uint	features; /* bitmask, see below */
};

enum TSLIB_VERSION_MT= 		(1 << 0);	/* multitouch support */
enum TSLIB_VERSION_OPEN_RESTRICTED= 	(1 << 1);	/* ts_open_restricted() */
enum TSLIB_VERSION_EVENTPATH= 		(1 << 2);	/* ts_get_eventpath() */
enum TSLIB_VERSION_VERSION= 		(1 << 3);	/* tslib_version() */

enum ts_param {
	TS_SCREEN_RES = 0,		/* 2 integer args, x and y */
	TS_SCREEN_ROT			/* 1 integer arg, 1 = rotate */
};

struct ts_module_conf {
	char *name;
	char *params;
	int raw;
	int nr;

	ts_module_conf *next;
	ts_module_conf *prev;
};

/*
 * Close the touchscreen device, free all resources.
 */
int ts_close(tsdev *);

/*
 * Reloads all modules - useful to reload calibration data.
 */
int ts_reconfig(tsdev *);

/*
 * Configure the touchscreen device.
 */
int ts_config(tsdev *);

/*
 * Changes a setting.
 */
int ts_option(tsdev *, ts_param, ...);

/*
 * Change this hook to point to your custom error handling function.
 */
extern int function(const char *fmt, va_list ap) ts_error_fn;

/*
 * Implement this to override open() for the input device and return the fd.
 */
extern int function(const char *path, int flags, void *user_data) ts_open_restricted;

/*
 * Implement this to override close().
 */
extern void function(int fd, void *user_data) ts_close_restricted;

/*
 * Returns the file descriptor in use for the touchscreen device.
 */
int ts_fd(tsdev *);

/*
 * Load a filter/scaling module
 */
int ts_load_module(tsdev *, const char *mod, const char *params);

/*
 * Open the touchscreen device.
 */
tsdev *ts_open(const char *dev_name, int nonblock);

/*
 * Find, open and configure the touchscreen device.
 */
tsdev *ts_setup(const char *dev_name, int nonblock);

/*
 * Return a scaled touchscreen sample.
 */
int ts_read(tsdev *, ts_sample *, int);

/*
 * Returns a raw, unscaled sample from the touchscreen.
 */
int ts_read_raw(tsdev *, ts_sample *, int);

/*
 * Return a scaled touchscreen multitouch sample.
 */
int ts_read_mt(tsdev *, ts_sample_mt **, int slots, int nr);

/*
 * Return a raw, unscaled touchscreen multitouch sample.
 */
int ts_read_raw_mt(tsdev *, ts_sample_mt **, int slots, int nr);

/*
 * This function returns a pointer to a static copy of the version info struct.
 */
ts_lib_version_data *ts_libversion();

/*
 * Get the list of (commented-in) ts.conf module lines (as structs)
 */
ts_module_conf *ts_conf_get(tsdev *ts);

/*
 * Write the list of modules to ts.conf
 */
int ts_conf_set(ts_module_conf *conf);

/*
 * This function returns the path to the opened touchscreen input device file.
 */
char *ts_get_eventpath(tsdev *tsdev);

/*
 * This simply returns tslib's version string
 */
char *tslib_version();

/*
 * This prints tslib's logo to stdout, with pos preceding spaces
 */
void ts_print_ascii_logo(uint pos);
