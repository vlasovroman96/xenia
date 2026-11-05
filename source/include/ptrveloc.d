module include.ptrveloc;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2006-2011 Simon Thum             simon dot thum at gmx dot de
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

                          /* POINTERVELOCITY_H */
