module common.math;
/*
 * Copyright © 2026, Roman Vlasov
 *
 * See COPYING for the full license texts.
 */

//Issue #68: Drop core.stdc.math
public import core.stdc.math;

//Issue #67: replace max/min by std.algorithm;
auto min(T, S) (T a, S b) {
    return a < b ? a : b;
}

//Issue #67: replace max/min by std.algorithm;
auto max(T, S) (T a, S b) {
    return a > b ? a : b;
}

auto modulus(A, B)(A a, B b) {
    int d = a % b;

    if (d < 0) 
        d += b;

    return d;
}