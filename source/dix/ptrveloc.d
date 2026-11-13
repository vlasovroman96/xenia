module ptrveloc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright © 2006-2009 Simon Thum             simon dot thum at gmx dot de
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

import core.stdc.math;

import dix.exevents_priv;
import dix.ptrveloc_priv;
import os.bug_priv;

import ptrveloc;
import externs.X11.Xatom;
import os.os;

import common.xserver_properties;
import Xi.xiproperty;
import mi.miarc;
import os.log;
import dix.dixutils;
import dix.inpututils;
import os.inputthread;



/*****************************************************************************
 * Predictable pointer acceleration
 *
 * 2006-2009 by Simon Thum (simon [dot] thum [at] gmx de)
 *
 * Serves 3 complementary functions:
 * 1) provide a sophisticated ballistic velocity estimate to improve
 *    the relation between velocity (of the device) and acceleration
 * 2) make arbitrary acceleration profiles possible
 * 3) decelerate by two means (constant and adaptive) if enabled
 *
 * Important concepts are the
 *
 * - Scheme
 *      which selects the basic algorithm
 *      (see devices.c/InitPointerAccelerationScheme)
 * - Profile
 *      which returns an acceleration
 *      for a given velocity
 *
 *  The profile can be selected by the user at runtime.
 *  The classic profile is intended to cleanly perform old-style
 *  function selection (threshold =/!= 0)
 *
 ****************************************************************************/

/* fwds */

public import dix.input;
import dix.ptrveloc_priv;
/* constants for acceleration profiles */

enum AccelProfileNone = -1;
enum AccelProfileClassic =  0;
enum AccelProfileDeviceSpecific = 1;
enum AccelProfilePolynomial = 2;
enum AccelProfileSmoothLinear = 3;
enum AccelProfileSimple = 4;
enum AccelProfilePower = 5;
enum AccelProfileLinear = 6;
enum AccelProfileSmoothLimited = 7;
enum AccelProfileLAST = AccelProfileSmoothLimited;

/* fwd */
// struct _DeviceVelocityRec;

/**
 * profile
 * returns actual acceleration depending on velocity, acceleration control,...
 */
alias PointerAccelerationProfileFunc = double function(DeviceIntPtr dev, _DeviceVelocityRec* vel, double velocity, double threshold, double accelCoeff);

alias MotionTracker = _MotionTracker;
alias MotionTrackerPtr = _MotionTracker*;

/**
 * Contains all data needed to implement mouse ballistics
 */
struct _DeviceVelocityRec {
    MotionTrackerPtr tracker;
    int num_tracker;
    int cur_tracker;            /* current index */
    double velocity = 0;            /* velocity as guessed by algorithm */
    double last_velocity = 0;       /* previous velocity estimate */
    double last_dx = 0;             /* last time-difference */
    double last_dy = 0;             /* phase of last/current estimate */
    double corr_mul = 0;            /* config: multiply this into velocity */
    double const_acceleration = 0;  /* config: (recipr.) const deceleration */
    double min_acceleration = 0;    /* config: minimum acceleration */
    short reset_time;           /* config: reset non-visible state after # ms */
    short use_softening;        /* config: use softening of mouse values */
    double max_rel_diff = 0;        /* config: max. relative difference */
    double max_diff = 0;            /* config: max. difference */
    int initial_range;          /* config: max. offset used as initial velocity */
    Bool average_accel;         /* config: average acceleration over velocity */
    PointerAccelerationProfileFunc Profile;
    PointerAccelerationProfileFunc deviceSpecificProfile;
    void* profile_private;      /* extended data, see  SetAccelerationProfile() */
    struct _Statistics {                    /* to be able to query this information */
        int profile_number;
    }_Statistics statistics;
}alias DeviceVelocityRec = _DeviceVelocityRec;
alias DeviceVelocityPtr = _DeviceVelocityRec*;

// void  GetDevicePredictableAccelData(DeviceIntPtr dev);

void  SetDeviceSpecificAccelerationProfile(DeviceVelocityPtr vel, PointerAccelerationProfileFunc profile);





/*#define PTRACCEL_DEBUGGING*/

// version (PTRACCEL_DEBUGGING) {
// enum string DebugAccelF(...) = `ErrorF("dix/ptraccel: " __VA_ARGS__)`;
// } else {
// //#define DebugAccelF(...)        /* */
// }

/********************************
 *  Init/Uninit
 *******************************/

/* some int which is not a profile number */
enum PROFILE_UNINITIALIZE = (-100);



/**
 * Init DeviceVelocity struct so it should match the average case
 */
private void InitVelocityData(DeviceVelocityPtr vel)
{
    memset(vel, 0, DeviceVelocityRec.sizeof);

    vel.corr_mul = 10.0;       /* dots per 10 millisecond should be usable */
    vel.const_acceleration = 1.0;      /* no acceleration/deceleration  */
    vel.reset_time = 300;
    vel.use_softening = 1;
    vel.min_acceleration = 1.0;        /* don't decelerate */
    vel.max_rel_diff = 0.2;
    vel.max_diff = 1.0;
    vel.initial_range = 2;
    vel.average_accel = True;
    SetAccelerationProfile(vel, AccelProfileClassic);
    InitTrackers(vel, 16);
}

/**
 * Clean up DeviceVelocityRec
 */
private void FreeVelocityData(DeviceVelocityPtr vel)
{
    free(vel.tracker);
    SetAccelerationProfile(vel, PROFILE_UNINITIALIZE);
}

/**
 * Init predictable scheme
 */
Bool InitPredictableAccelerationScheme(DeviceIntPtr dev, ValuatorAccelerationPtr protoScheme)
{
    DeviceVelocityPtr vel = void;
    ValuatorAccelerationRec scheme = void;
    PredictableAccelSchemePtr schemeData = void;

    scheme = *protoScheme;
    vel = cast(DeviceVelocityRec*) calloc(1, DeviceVelocityRec.sizeof);
    schemeData = cast(PredictableAccelSchemeRec*) calloc(1, PredictableAccelSchemeRec.sizeof);
    if (!vel || !schemeData) {
        free(vel);
        free(schemeData);
        return False;
    }
    InitVelocityData(vel);
    schemeData.vel = vel;
    scheme.accelData = schemeData;
    if (!InitializePredictableAccelerationProperties(dev, vel, schemeData)) {
        FreeVelocityData(vel);
        free(vel);
        free(schemeData);
        return False;
    }
    /* all fine, assign scheme to device */
    dev.valuator.accelScheme = scheme;
    return True;
}

/**
 *  Uninit scheme
 */
void AccelerationDefaultCleanup(DeviceIntPtr dev)
{
    DeviceVelocityPtr vel = GetDevicePredictableAccelData(dev);

    if (vel) {
        /* the proper guarantee would be that we're not inside of
         * AccelSchemeProc(), but that seems impossible. Schemes don't get
         * switched often anyway.
         */
        input_lock();
        dev.valuator.accelScheme.AccelSchemeProc = null;
        FreeVelocityData(vel);
        free(vel);
        DeletePredictableAccelerationProperties(dev,
                                                cast(PredictableAccelSchemePtr)
                                                dev.valuator.accelScheme.
                                                accelData);
        free(dev.valuator.accelScheme.accelData);
        dev.valuator.accelScheme.accelData = null;
        input_unlock();
    }
}

/*************************
 * Input property support
 ************************/

/**
 * choose profile
 */
private int AccelSetProfileProperty(DeviceIntPtr dev, Atom atom, XIPropertyValuePtr val, BOOL checkOnly)
{
    DeviceVelocityPtr vel = void;
    int profile = void; int* ptr = &profile;
    int rc = void;
    int nelem = 1;

    if (atom != XIGetKnownProperty(ACCEL_PROP_PROFILE_NUMBER))
        return Success;

    vel = GetDevicePredictableAccelData(dev);
    if (!vel)
        return BadValue;
    rc = XIPropToInt(val, &nelem, &ptr);

    if (checkOnly) {
        if (rc)
            return rc;

        if (GetAccelerationProfile(vel, profile) is null)
            return BadValue;
    }
    else
        SetAccelerationProfile(vel, profile);

    return Success;
}

private c_long AccelInitProfileProperty(DeviceIntPtr dev, DeviceVelocityPtr vel)
{
    int profile = vel.statistics.profile_number;
    Atom prop_profile_number = XIGetKnownProperty(ACCEL_PROP_PROFILE_NUMBER);

    XIChangeDeviceProperty(dev, prop_profile_number, XA_INTEGER, 32,
                           PropModeReplace, 1, &profile, False);
    XISetDevicePropertyDeletable(dev, prop_profile_number, False);
    return XIRegisterPropertyHandler(dev, &AccelSetProfileProperty, null, null);
}

/**
 * constant deceleration
 */
private int AccelSetDecelProperty(DeviceIntPtr dev, Atom atom, XIPropertyValuePtr val, BOOL checkOnly)
{
    DeviceVelocityPtr vel = void;
    float v = void; float* ptr = &v;
    int rc = void;
    int nelem = 1;

    if (atom != XIGetKnownProperty(ACCEL_PROP_CONSTANT_DECELERATION))
        return Success;

    vel = GetDevicePredictableAccelData(dev);
    if (!vel)
        return BadValue;
    rc = XIPropToFloat(val, &nelem, &ptr);

    if (checkOnly) {
        if (rc)
            return rc;
        return (v > 0) ? Success : BadValue;
    }

    vel.const_acceleration = 1 / v;

    return Success;
}

private c_long AccelInitDecelProperty(DeviceIntPtr dev, DeviceVelocityPtr vel)
{
    float fval = 1.0 / vel.const_acceleration;
    Atom prop_const_decel = XIGetKnownProperty(ACCEL_PROP_CONSTANT_DECELERATION);
    XIChangeDeviceProperty(dev, prop_const_decel,
                           XIGetKnownProperty(XATOM_FLOAT), 32, PropModeReplace,
                           1, &fval, False);
    XISetDevicePropertyDeletable(dev, prop_const_decel, False);
    return XIRegisterPropertyHandler(dev, &AccelSetDecelProperty, null, null);
}

/**
 * adaptive deceleration
 */
private int AccelSetAdaptDecelProperty(DeviceIntPtr dev, Atom atom, XIPropertyValuePtr val, BOOL checkOnly)
{
    DeviceVelocityPtr veloc = void;
    float v = void; float* ptr = &v;
    int rc = void;
    int nelem = 1;

    if (atom != XIGetKnownProperty(ACCEL_PROP_ADAPTIVE_DECELERATION))
        return Success;

    veloc = GetDevicePredictableAccelData(dev);
    if (!veloc)
        return BadValue;
    rc = XIPropToFloat(val, &nelem, &ptr);

    if (checkOnly) {
        if (rc)
            return rc;
        return (v >= 1.0f) ? Success : BadValue;
    }

    if (v >= 1.0f)
        veloc.min_acceleration = 1 / v;

    return Success;
}

private c_long AccelInitAdaptDecelProperty(DeviceIntPtr dev, DeviceVelocityPtr vel)
{
    float fval = 1.0 / vel.min_acceleration;
    Atom prop_adapt_decel = XIGetKnownProperty(ACCEL_PROP_ADAPTIVE_DECELERATION);

    XIChangeDeviceProperty(dev, prop_adapt_decel,
                           XIGetKnownProperty(XATOM_FLOAT), 32, PropModeReplace,
                           1, &fval, False);
    XISetDevicePropertyDeletable(dev, prop_adapt_decel, False);
    return XIRegisterPropertyHandler(dev, &AccelSetAdaptDecelProperty, null,
                                     null);
}

/**
 * velocity scaling
 */
private int AccelSetScaleProperty(DeviceIntPtr dev, Atom atom, XIPropertyValuePtr val, BOOL checkOnly)
{
    DeviceVelocityPtr vel = void;
    float v = void; float* ptr = &v;
    int rc = void;
    int nelem = 1;

    if (atom != XIGetKnownProperty(ACCEL_PROP_VELOCITY_SCALING))
        return Success;

    vel = GetDevicePredictableAccelData(dev);
    if (!vel)
        return BadValue;
    rc = XIPropToFloat(val, &nelem, &ptr);

    if (checkOnly) {
        if (rc)
            return rc;

        return (v > 0) ? Success : BadValue;
    }

    if (v > 0)
        vel.corr_mul = v;

    return Success;
}

private c_long AccelInitScaleProperty(DeviceIntPtr dev, DeviceVelocityPtr vel)
{
    float fval = vel.corr_mul;
    Atom prop_velo_scale = XIGetKnownProperty(ACCEL_PROP_VELOCITY_SCALING);

    XIChangeDeviceProperty(dev, prop_velo_scale,
                           XIGetKnownProperty(XATOM_FLOAT), 32, PropModeReplace,
                           1, &fval, False);
    XISetDevicePropertyDeletable(dev, prop_velo_scale, False);
    return XIRegisterPropertyHandler(dev, &AccelSetScaleProperty, null, null);
}

private BOOL InitializePredictableAccelerationProperties(DeviceIntPtr dev, DeviceVelocityPtr vel, PredictableAccelSchemePtr schemeData)
{
    int num_handlers = 4;

    if (!vel)
        return False;

    schemeData.prop_handlers = cast(long*)calloc(num_handlers, c_long.sizeof);
    if (!schemeData.prop_handlers)
        return False;
    schemeData.num_prop_handlers = num_handlers;
    schemeData.prop_handlers[0] = AccelInitProfileProperty(dev, vel);
    schemeData.prop_handlers[1] = AccelInitDecelProperty(dev, vel);
    schemeData.prop_handlers[2] = AccelInitAdaptDecelProperty(dev, vel);
    schemeData.prop_handlers[3] = AccelInitScaleProperty(dev, vel);

    return True;
}

BOOL DeletePredictableAccelerationProperties(DeviceIntPtr dev, PredictableAccelSchemePtr scheme)
{
    DeviceVelocityPtr vel = void;
    Atom prop = void;

    prop = XIGetKnownProperty(ACCEL_PROP_VELOCITY_SCALING);
    XIDeleteDeviceProperty(dev, prop, False);
    prop = XIGetKnownProperty(ACCEL_PROP_ADAPTIVE_DECELERATION);
    XIDeleteDeviceProperty(dev, prop, False);
    prop = XIGetKnownProperty(ACCEL_PROP_CONSTANT_DECELERATION);
    XIDeleteDeviceProperty(dev, prop, False);
    prop = XIGetKnownProperty(ACCEL_PROP_PROFILE_NUMBER);
    XIDeleteDeviceProperty(dev, prop, False);

    vel = GetDevicePredictableAccelData(dev);
    if (vel) {
        for (int i = 0; i < scheme.num_prop_handlers; i++)
            if (scheme.prop_handlers[i])
                XIUnregisterPropertyHandler(dev, scheme.prop_handlers[i]);
    }

    free(scheme.prop_handlers);
    scheme.prop_handlers = null;
    scheme.num_prop_handlers = 0;
    return True;
}

/*********************
 * Tracking logic
 ********************/

void InitTrackers(DeviceVelocityPtr vel, int ntracker)
{
    if (ntracker < 1) {
        ErrorF("invalid number of trackers\n");
        return;
    }
    free(vel.tracker);
    vel.tracker = cast(MotionTrackerPtr) calloc(ntracker, MotionTracker.sizeof);
    vel.num_tracker = ntracker;
}

enum directions {
    N = (1 << 0),
    NE = (1 << 1),
    E = (1 << 2),
    SE = (1 << 3),
    S = (1 << 4),
    SW = (1 << 5),
    W = (1 << 6),
    NW = (1 << 7),
    UNDEFINED = 0xFF
}
alias N = directions.N;
alias NE = directions.NE;
alias E = directions.E;
alias SE = directions.SE;
alias S = directions.S;
alias SW = directions.SW;
alias W = directions.W;
alias NW = directions.NW;
alias UNDEFINED = directions.UNDEFINED;


/**
 * return a bit field of possible directions.
 * There's no reason against widening to more precise directions (<45 degrees),
 * should it not perform well. All this is needed for is sort out non-linear
 * motion, so precision isn't paramount. However, one should not flag direction
 * too narrow, since it would then cut the linear segment to zero size way too
 * often.
 *
 * @return A bitmask for N, NE, S, SE, etc. indicating the directions for
 * this movement.
 */
private int DoGetDirection(int dx, int dy)
{
    int dir = 0;

    /* on insignificant mickeys, flag 135 degrees */
    if (abs(dx) < 2 && abs(dy) < 2) {
        /* first check diagonal cases */
        if (dx > 0 && dy > 0)
            dir = E | SE | S;
        else if (dx > 0 && dy < 0)
            dir = N | NE | E;
        else if (dx < 0 && dy < 0)
            dir = W | NW | N;
        else if (dx < 0 && dy > 0)
            dir = W | SW | S;
        /* check axis-aligned directions */
        else if (dx > 0)
            dir = NE | E | SE;
        else if (dx < 0)
            dir = NW | W | SW;
        else if (dy > 0)
            dir = SE | S | SW;
        else if (dy < 0)
            dir = NE | N | NW;
        else
            dir = UNDEFINED;    /* shouldn't happen */
    }
    else {                      /* compute angle and set appropriate flags */
        double r = void;
        int i1 = void, i2 = void;

        r = atan2(dy, dx);
        /* find direction.
         *
         * Add 360° to avoid r become negative since C has no well-defined
         * modulo for such cases. Then divide by 45° to get the octant
         * number,  e.g.
         *          0 <= r <= 1 is [0-45]°
         *          1 <= r <= 2 is [45-90]°
         *          etc.
         * But we add extra 90° to match up with our N, S, etc. defines up
         * there, rest stays the same.
         */
        r = (r + (M_PI * 2.5)) / (M_PI / 4);
        /* this intends to flag 2 directions (45 degrees),
         * except on very well-aligned mickeys. */
        i1 = cast(int) (r + 0.1) % 8;
        i2 = cast(int) (r + 0.9) % 8;
        if (i1 < 0 || i1 > 7 || i2 < 0 || i2 > 7)
            dir = UNDEFINED;    /* shouldn't happen */
        else
            dir = (1 << i1 | 1 << i2);
    }
    return dir;
}

enum DIRECTION_CACHE_RANGE = 5;
enum DIRECTION_CACHE_SIZE = (DIRECTION_CACHE_RANGE*2+1);

/* cache DoGetDirection().
 * To avoid excessive use of direction calculation, cache the values for
 * [-5..5] for both x/y. Anything outside of that is calculated on the fly.
 *
 * @return A bitmask for N, NE, S, SE, etc. indicating the directions for
 * this movement.
 */
private int GetDirection(int dx, int dy)
{
    static int[DIRECTION_CACHE_SIZE][DIRECTION_CACHE_SIZE] cache;
    int dir = void;

    if (abs(dx) <= DIRECTION_CACHE_RANGE && abs(dy) <= DIRECTION_CACHE_RANGE) {
        /* cacheable */
        dir = cache[DIRECTION_CACHE_RANGE + dx][DIRECTION_CACHE_RANGE + dy];
        if (dir == 0) {
            dir = DoGetDirection(dx, dy);
            cache[DIRECTION_CACHE_RANGE + dx][DIRECTION_CACHE_RANGE + dy] = dir;
        }
    }
    else {
        /* non-cacheable */
        dir = DoGetDirection(dx, dy);
    }

    return dir;
}

/* convert offset (age) to array index */
enum string TRACKER_INDEX(string s, string d) = `(((` ~ s ~ `).num_tracker + (` ~ s ~ `).cur_tracker - (` ~ d ~ `)) % (` ~ s ~ `).num_tracker)`;
enum string TRACKER(string s, string d) = `&(` ~ s ~ `).tracker[` ~ TRACKER_INDEX!(s,d) ~ `]`;

/**
 * Add the delta motion to each tracker, then reset the latest tracker to
 * 0/0 and set it as the current one.
 */
pragma(inline, true) private void FeedTrackers(DeviceVelocityPtr vel, double dx, double dy, int cur_t)
{
    int n = void;

    for (n = 0; n < vel.num_tracker; n++) {
        vel.tracker[n].dx += dx;
        vel.tracker[n].dy += dy;
    }
    n = (vel.cur_tracker + 1) % vel.num_tracker;
    vel.tracker[n].dx = 0.0;
    vel.tracker[n].dy = 0.0;
    vel.tracker[n].time = cur_t;
    vel.tracker[n].dir = GetDirection(cast(int)dx, cast(int)dy);
    // DebugAccelF("motion [dx: %f dy: %f dir:%d diff: %d]\n",
    //             dx, dy, vel.tracker[n].dir,
    //             cur_t - vel.tracker[vel.cur_tracker].time);
    vel.cur_tracker = n;
}

/**
 * calc velocity for given tracker, with
 * velocity scaling.
 * This assumes linear motion.
 */
private double CalcTracker(const(MotionTracker)* tracker, int cur_t)
{
    double dist = sqrt(tracker.dx * tracker.dx + tracker.dy * tracker.dy);
    int dtime = cur_t - tracker.time;

    if (dtime > 0)
        return dist / dtime;
    else
        return 0;               /* synonymous for NaN, since we're not C99 */
}

/* find the most plausible velocity. That is, the most distant
 * (in time) tracker which isn't too old, the movement vector was
 * in the same octant, and where the velocity is within an
 * acceptable range to the initial velocity.
 *
 * @return The tracker's velocity or 0 if the above conditions are unmet
 */
private double QueryTrackers(DeviceVelocityPtr vel, int cur_t)
{
    int offset = void, dir = UNDEFINED, used_offset = -1, age_ms = void;

    /* initial velocity: a low-offset, valid velocity */
    double initial_velocity = 0, result = 0, velocity_diff = void;
    double velocity_factor = vel.corr_mul * vel.const_acceleration;   /* premultiply */

    /* loop from current to older data */
    for (offset = 1; offset < vel.num_tracker; offset++) {
        MotionTracker* tracker = mixin(TRACKER!(`vel`, `offset`));
        double tracker_velocity = void;

        age_ms = cur_t - tracker.time;

        /* bail out if data is too old and protect from overrun */
        if (age_ms >= vel.reset_time || age_ms < 0) {
            // DebugAccelF("query: tracker too old (reset after %d, age is %d)\n",
            //             vel.reset_time, age_ms);
            break;
        }

        /*
         * this heuristic avoids using the linear-motion velocity formula
         * in CalcTracker() on motion that isn't exactly linear. So to get
         * even more precision we could subdivide as a final step, so possible
         * non-linearities are accounted for.
         */
        dir &= tracker.dir;
        if (dir == 0) {         /* we've changed octant of movement (e.g. NE → NW) */
            // DebugAccelF("query: no longer linear\n");
            /* instead of breaking it we might also inspect the partition after,
             * but actual improvement with this is probably rare. */
            break;
        }

        tracker_velocity = CalcTracker(tracker, cur_t) * velocity_factor;

        if ((initial_velocity == 0 || offset <= vel.initial_range) &&
            tracker_velocity != 0) {
            /* set initial velocity and result */
            result = initial_velocity = tracker_velocity;
            used_offset = offset;
        }
        else if (initial_velocity != 0 && tracker_velocity != 0) {
            velocity_diff = fabs(initial_velocity - tracker_velocity);

            if (velocity_diff > vel.max_diff &&
                velocity_diff / (initial_velocity + tracker_velocity) >=
                vel.max_rel_diff) {
                /* we're not in range, quit - it won't get better. */
                // DebugAccelF("query: tracker too different:"
                //             ~ " old %2.2f initial %2.2f diff: %2.2f\n",
                //             tracker_velocity, initial_velocity, velocity_diff);
                break;
            }
            /* we're in range with the initial velocity,
             * so this result is likely better
             * (it contains more information). */
            result = tracker_velocity;
            used_offset = offset;
        }
    }
    if (offset == vel.num_tracker) {
        // DebugAccelF("query: last tracker in effect\n");
        used_offset = vel.num_tracker - 1;
    }
    if (used_offset >= 0) {
version (PTRACCEL_DEBUGGING) {
        MotionTracker* tracker = mixin(TRACKER!(`vel`, `used_offset`));

        DebugAccelF("result: offset %i [dx: %f dy: %f diff: %i]\n",
                    used_offset, tracker.dx, tracker.dy,
                    cur_t - tracker.time);
}
    }
    return result;
}

/**
 * Perform velocity approximation based on 2D 'mickeys' (mouse motion delta).
 * return true if non-visible state reset is suggested
 */
private BOOL ProcessVelocityData2D(DeviceVelocityPtr vel, double dx, double dy, int time)
{
    double velocity = void;

    vel.last_velocity = vel.velocity;

    FeedTrackers(vel, dx, dy, time);

    velocity = QueryTrackers(vel, time);

    // DebugAccelF("velocity is %f\n", velocity);

    vel.velocity = velocity;
    return velocity == 0;
}

/**
 * this flattens significant ( > 1) mickeys a little bit for more steady
 * constant-velocity response
 */
pragma(inline, true) private double ApplySimpleSoftening(double prev_delta, double delta)
{
    double result = delta;

    if (delta < -1.0 || delta > 1.0) {
        if (delta > prev_delta)
            result -= 0.5;
        else if (delta < prev_delta)
            result += 0.5;
    }
    return result;
}

/**
 * Soften the delta based on previous deltas stored in vel.
 *
 * @param[in,out] fdx Delta X, modified in-place.
 * @param[in,out] fdx Delta Y, modified in-place.
 */
private void ApplySoftening(DeviceVelocityPtr vel, double* fdx, double* fdy)
{
    if (vel.use_softening) {
        *fdx = ApplySimpleSoftening(vel.last_dx, *fdx);
        *fdy = ApplySimpleSoftening(vel.last_dy, *fdy);
    }
}

private void ApplyConstantDeceleration(DeviceVelocityPtr vel, double* fdx, double* fdy)
{
    *fdx *= vel.const_acceleration;
    *fdy *= vel.const_acceleration;
}

/*
 * compute the acceleration for given velocity and enforce min_acceleration
 */
private double BasicComputeAcceleration(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{

    double result = void;

    result = vel.Profile(dev, vel, velocity, threshold, acc);

    /* enforce min_acceleration */
    if (result < vel.min_acceleration)
        result = vel.min_acceleration;
    return result;
}

/**
 * Compute acceleration. Takes into account averaging, nv-reset, etc.
 * If the velocity has changed, an average is taken of 6 velocity factors:
 * current velocity, last velocity and 4 times the average between the two.
 */
private double ComputeAcceleration(DeviceIntPtr dev, DeviceVelocityPtr vel, double threshold, double acc)
{
    double result = void;

    if (vel.velocity <= 0) {
        // DebugAccelF("profile skipped\n");
        /*
         * If we have no idea about device velocity, don't pretend it.
         */
        return 1;
    }

    if (vel.average_accel && vel.velocity != vel.last_velocity) {
        /* use simpson's rule to average acceleration between
         * current and previous velocity.
         * Though being the more natural choice, it causes a minor delay
         * in comparison, so it can be disabled. */
        result =
            BasicComputeAcceleration(dev, vel, vel.velocity, threshold, acc);
        result +=
            BasicComputeAcceleration(dev, vel, vel.last_velocity, threshold,
                                     acc);
        result +=
            4.0 * BasicComputeAcceleration(dev, vel,
                                            (vel.last_velocity +
                                             vel.velocity) / 2,
                                            threshold,
                                            acc);
        result /= 6.0;
        // DebugAccelF("profile average [%.2f ... %.2f] is %.3f\n",
        //             vel.velocity, vel.last_velocity, result);
    }
    else {
        result = BasicComputeAcceleration(dev, vel,
                                          vel.velocity, threshold, acc);
        // DebugAccelF("profile sample [%.2f] is %.3f\n",
        //             vel.velocity, result);
    }

    return result;
}

/*****************************************
 *  Acceleration functions and profiles
 ****************************************/

/**
 * Polynomial function similar previous one, but with f(1) = 1
 */
private double PolynomialAccelerationProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double ignored, double acc)
{
    return pow(velocity, (acc - 1.0) * 0.5);
}

/**
 * returns acceleration for velocity.
 * This profile selects the two functions like the old scheme did
 */
private double ClassicProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    if (threshold > 0) {
        return SimpleSmoothProfile(dev, vel, velocity, threshold, acc);
    }
    else {
        return PolynomialAccelerationProfile(dev, vel, velocity, 0, acc);
    }
}

/**
 * Power profile
 * This has a completely smooth transition curve, i.e. no jumps in the
 * derivatives.
 *
 * This has the expense of overall response dependency on min-acceleration.
 * In effect, min_acceleration mimics const_acceleration in this profile.
 */
private double PowerProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    double vel_dist = void;

    acc = (acc - 1.0) * 0.1 + 1.0;     /* without this, acc of 2 is unusable */

    if (velocity <= threshold)
        return vel.min_acceleration;
    vel_dist = velocity - threshold;
    return (pow(acc, vel_dist)) * vel.min_acceleration;
}

/**
 * just a smooth function in [0..1] -> [0..1]
 *  - point symmetry at 0.5
 *  - f'(0) = f'(1) = 0
 *  - starts faster than a sinoid
 *  - smoothness C1 (Cinf if you dare to ignore endpoints)
 */
pragma(inline, true) private double CalcPenumbralGradient(double x)
{
    x *= 2.0;
    x -= 1.0;
    return 0.5 + (x * sqrt(1.0 - x * x) + asin(x)) / M_PI;
}

/**
 * acceleration function similar to classic accelerated/unaccelerated,
 * but with smooth transition in between (and towards zero for adaptive dec.).
 */
private double SimpleSmoothProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    if (velocity < 1.0f)
        return CalcPenumbralGradient(0.5 + velocity * 0.5) * 2.0f - 1.0f;
    if (threshold < 1.0f)
        threshold = 1.0f;
    if (velocity <= threshold)
        return 1;
    velocity /= threshold;
    if (velocity >= acc)
        return acc;
    else
        return 1.0f + (CalcPenumbralGradient(velocity / acc) * (acc - 1.0f));
}

/**
 * This profile uses the first half of the penumbral gradient as a start
 * and then scales linearly.
 */
private double SmoothLinearProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    double res = void, nv = void;

    if (acc > 1.0)
        acc -= 1.0;            /*this is so acc = 1 is no acceleration */
    else
        return 1.0;

    nv = (velocity - threshold) * acc * 0.5;

    if (nv < 0) {
        res = 0;
    }
    else if (nv < 2) {
        res = CalcPenumbralGradient(nv * 0.25) * 2.0;
    }
    else {
        nv -= 2.0;
        res = nv * 2.0 / M_PI  /* steepness of gradient at 0.5 */
            + 1.0;             /* gradient crosses 2|1 */
    }
    res += vel.min_acceleration;
    return res;
}

/**
 * From 0 to threshold, the response graduates smoothly from min_accel to
 * acceleration. Beyond threshold it is exactly the specified acceleration.
 */
private double SmoothLimitedProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    double res = void;

    if (velocity >= threshold || threshold == 0.0)
        return acc;

    velocity /= threshold;      /* should be [0..1[ now */

    res = CalcPenumbralGradient(velocity) * (acc - vel.min_acceleration);

    return vel.min_acceleration + res;
}

private double LinearProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    return acc * velocity;
}

private double NoProfile(DeviceIntPtr dev, DeviceVelocityPtr vel, double velocity, double threshold, double acc)
{
    return 1.0;
}

private PointerAccelerationProfileFunc GetAccelerationProfile(DeviceVelocityPtr vel, int profile_num)
{
    switch (profile_num) {
    case AccelProfileClassic:
        return &ClassicProfile;
    case AccelProfileDeviceSpecific:
        return vel.deviceSpecificProfile;
    case AccelProfilePolynomial:
        return &PolynomialAccelerationProfile;
    case AccelProfileSmoothLinear:
        return &SmoothLinearProfile;
    case AccelProfileSimple:
        return &SimpleSmoothProfile;
    case AccelProfilePower:
        return &PowerProfile;
    case AccelProfileLinear:
        return &LinearProfile;
    case AccelProfileSmoothLimited:
        return &SmoothLimitedProfile;
    case AccelProfileNone:
        return &NoProfile;
    default:
        return null;
    }
}

/**
 * Set the profile by number.
 * Intended to make profiles exchangeable at runtime.
 * If you created a profile, give it a number here and in the header to
 * make it selectable. In case some profile-specific init is needed, here
 * would be a good place, since FreeVelocityData() also calls this with
 * PROFILE_UNINITIALIZE.
 *
 * returns False if profile number is unavailable, True otherwise.
 */
private int SetAccelerationProfile(DeviceVelocityPtr vel, int profile_num)
{
    PointerAccelerationProfileFunc profile = void;

    profile = GetAccelerationProfile(vel, profile_num);

    if (profile is null && profile_num != PROFILE_UNINITIALIZE)
        return False;

    /* Here one could free old profile-private data */
    free(vel.profile_private);
    vel.profile_private = null;
    /* Here one could init profile-private data */
    vel.Profile = profile;
    vel.statistics.profile_number = profile_num;
    return True;
}

/**********************************************
 * driver interaction
 **********************************************/

/**
 * device-specific profile
 *
 * The device-specific profile is intended as a hook for a driver
 * which may want to provide an own acceleration profile.
 * It should not rely on profile-private data, instead
 * it should do init/uninit in the driver (ie. with DEVICE_INIT and friends).
 * Users may override or choose it.
 */
void SetDeviceSpecificAccelerationProfile(DeviceVelocityPtr vel, PointerAccelerationProfileFunc profile)
{
    if (vel)
        vel.deviceSpecificProfile = profile;
}

/**
 * Use this function to obtain a DeviceVelocityPtr for a device. Will return NULL if
 * the predictable acceleration scheme is not in effect.
 */
DeviceVelocityPtr GetDevicePredictableAccelData(DeviceIntPtr dev)
{
    mixin(BUG_RETURN_VAL!("!dev", "null"));

    if (dev.valuator &&
        dev.valuator.accelScheme.AccelSchemeProc is
        &acceleratePointerPredictable &&
        dev.valuator.accelScheme.accelData !is null) {

        return (cast(PredictableAccelSchemePtr)
                dev.valuator.accelScheme.accelData).vel;
    }
    return null;
}

/********************************
 *  acceleration schemes
 *******************************/

/**
 * Modifies valuators in-place.
 * This version employs a velocity approximation algorithm to
 * enable fine-grained predictable acceleration profiles.
 */
void acceleratePointerPredictable(DeviceIntPtr dev, ValuatorMask* val, CARD32 evtime)
{
    double dx = 0, dy = 0;
    DeviceVelocityPtr velocitydata = GetDevicePredictableAccelData(dev);
    Bool soften = True;

    if (valuator_mask_num_valuators(val) == 0 || !velocitydata)
        return;

    if (velocitydata.statistics.profile_number == AccelProfileNone &&
        velocitydata.const_acceleration == 1.0) {
        return;                 /*we're inactive anyway, so skip the whole thing. */
    }

    if (valuator_mask_isset(val, 0)) {
        dx = valuator_mask_get_double(val, 0);
    }

    if (valuator_mask_isset(val, 1)) {
        dy = valuator_mask_get_double(val, 1);
    }

    if (dx != 0.0 || dy != 0.0) {
        /* reset non-visible state? */
        if (ProcessVelocityData2D(velocitydata, dx, dy, cast(int)evtime)) {
            soften = False;
        }

        if (dev.ptrfeed && dev.ptrfeed.ctrl.num) {
            double mult = void;

            /* invoke acceleration profile to determine acceleration */
            mult = ComputeAcceleration(dev, velocitydata,
                                       dev.ptrfeed.ctrl.threshold,
                                       cast(double) dev.ptrfeed.ctrl.num /
                                       cast(double) dev.ptrfeed.ctrl.den);

            // DebugAccelF("mult is %f\n", mult);
            if (mult != 1.0 || velocitydata.const_acceleration != 1.0) {
                if (mult > 1.0 && soften)
                    ApplySoftening(velocitydata, &dx, &dy);
                ApplyConstantDeceleration(velocitydata, &dx, &dy);

                if (dx != 0.0)
                    valuator_mask_set_double(val, 0, mult * dx);
                if (dy != 0.0)
                    valuator_mask_set_double(val, 1, mult * dy);
                // DebugAccelF("delta x:%.3f y:%.3f\n", mult * dx, mult * dy);
            }
        }
    }
    /* remember last motion delta (for softening/slow movement treatment) */
    velocitydata.last_dx = dx;
    velocitydata.last_dy = dy;
}

/**
 * Originally a part of xf86PostMotionEvent; modifies valuators
 * in-place. Retained mostly for embedded scenarios.
 */
void acceleratePointerLightweight(DeviceIntPtr dev, ValuatorMask* val, CARD32 ignored)
{
    double mult = 0.0, tmpf = void;
    double dx = 0.0, dy = 0.0;

    if (valuator_mask_isset(val, 0)) {
        dx = valuator_mask_get(val, 0);
    }

    if (valuator_mask_isset(val, 1)) {
        dy = valuator_mask_get(val, 1);
    }

    if (valuator_mask_num_valuators(val) == 0)
        return;

    if (dev.ptrfeed && dev.ptrfeed.ctrl.num) {
        /* modeled from xf86Events.c */
        if (dev.ptrfeed.ctrl.threshold) {
            if ((fabs(dx) + fabs(dy)) >= dev.ptrfeed.ctrl.threshold) {
                if (dx != 0.0) {
                    tmpf = (dx * cast(double) (dev.ptrfeed.ctrl.num)) /
                        cast(double) (dev.ptrfeed.ctrl.den);
                    valuator_mask_set_double(val, 0, tmpf);
                }

                if (dy != 0.0) {
                    tmpf = (dy * cast(double) (dev.ptrfeed.ctrl.num)) /
                        cast(double) (dev.ptrfeed.ctrl.den);
                    valuator_mask_set_double(val, 1, tmpf);
                }
            }
        }
        else {
            mult = pow(dx * dx + dy * dy,
                       (cast(double) (dev.ptrfeed.ctrl.num) /
                        cast(double) (dev.ptrfeed.ctrl.den) - 1.0) / 2.0) / 2.0;
            if (dx != 0.0)
                valuator_mask_set_double(val, 0, mult * dx);
            if (dy != 0.0)
                valuator_mask_set_double(val, 1, mult * dy);
        }
    }
}
