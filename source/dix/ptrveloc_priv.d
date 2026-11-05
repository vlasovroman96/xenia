module dix.ptrveloc_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2006-2011 Simon Thum             simon dot thum at gmx dot de
 */
 
public import dix.input;

public import ptrveloc;

/* fwd */
struct _DeviceVelocityRec;

/**
 * a motion history, with just enough information to
 * calc mean velocity and decide which motion was along
 * a more or less straight line
 */
struct _MotionTracker {
    double dx = 0, dy = 0;              /* accumulated delta for each axis */
    int time;                   /* time of creation */
    int dir;                    /* initial direction bitfield */
}

/**
 * contains the run-time data for the predictable scheme, that is, a
 * DeviceVelocityPtr and the property handlers.
 */
struct _PredictableAccelSchemeRec {
    DeviceVelocityPtr vel;
    c_long* prop_handlers;
    int num_prop_handlers;
}alias PredictableAccelSchemeRec = _PredictableAccelSchemeRec;
alias PredictableAccelSchemePtr = _PredictableAccelSchemeRec*;

// void AccelerationDefaultCleanup(DeviceIntPtr dev);

// Bool InitPredictableAccelerationScheme(DeviceIntPtr dev, _ValuatorAccelerationRec* protoScheme);

// void acceleratePointerPredictable(DeviceIntPtr dev, ValuatorMask* val, CARD32 evtime);

// void acceleratePointerLightweight(DeviceIntPtr dev, ValuatorMask* val, CARD32 evtime);

// void InitTrackers(DeviceVelocityPtr vel, int ntracker);

 /* _XSERVER_POINTERVELOCITY_PRIV_H */
