module dix.saveSet;

import x11.Xmd;
import dix.window;

struct SaveSetRec {
    WindowRec* windowPtr;
    Bool toRoot;
    Bool map;

@nogc: nothrow:
	void set(WindowPtr win, Bool toRoot, Bool map) {
		this.windowPtr = win;
		this.toRoot = toRoot;
		this.map = map;
	}
}