module common.math;
/*
 * Copyright © 2026, Roman Vlasov
 *
 * See COPYING for the full license texts.
 */

/* @deprecated */
auto min(T, S) (T a, S b) {
    return a < b ? a : b;
}

auto max(T, S) (T a, S b) {
    return a > b ? a : b;
}

enum string modulus(string a, string b, string d) = `if (((` ~ d ~ `) = (` ~ a ~ `) % (` ~ b ~ `)) < 0) (` ~ d ~ `) += (` ~ b ~ `);`;