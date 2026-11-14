module common.xorgVersion;
@nogc nothrow:
extern(C): __gshared:

/*
 * Copyright © 2026, Roman Vlasov
 *
 * See COPYING for the full license texts.
 */

import build.xlibre_server;

struct XServerVersion {
	uint Major;
	uint Minor;
	uint Patch;
	uint Snap;

	this(uint numericVersion) {
		Major = numericVersion / 10000000;
		Minor = (numericVersion % 10000000) / 100000;
		Patch = (numericVersion % 100000) / 1000;
		Snap = numericVersion % 1000;
	}

	uint getNumeric() {
		return Major * 10000000 + Minor * 100000 + Patch * 1000 + Snap;
	}
}

enum XServerVersion ServerVersion = XServerVersion(build.xlibre_server.XORG_VERSION_CURRENT);

