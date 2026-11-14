module common.swap;

/*
 * Copyright © 2026, Roman Vlasov
 *
 * See COPYING for the full license texts.
 */

import core.bitop;

@nogc nothrow:
pure auto bswap_16(T)(T x) => byteswap(cast(ushort)x); 
pure auto bswap_32(T)(T x) => bswap(cast(uint)x);
pure auto bswap_64(T)(T x) => bswap(cast(ulong)x);

void swaps(T)(T* x) {
	*x = bswap_16(*x); 
}

auto swapl(T)(T* t) {
	*t = cast(T)bswap_32(*t); 
}

auto swapll(T)(T* t) {
	*t = cast(T)bswap_64(*t);          
}

void cpswaps(T, U)(ref T src, ref U dst) {
	dst = bswap_16(src); 
}

void cpswapl(T, U)(ref T src, ref U dst) {
	dst = bswap_32(src); 
}
