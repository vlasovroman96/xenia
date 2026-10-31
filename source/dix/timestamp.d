module dix.timestamp;

import x11.Xmd;

enum EARLIER = -1;
enum SAMETIME = 0;
enum LATER = 1;

alias TimeStampPtr = _TimeStamp*;

struct _TimeStamp {
    CARD32 months;              /* really ~49.7 days */
    CARD32 milliseconds;
}

alias TimeStamp = _TimeStamp;
