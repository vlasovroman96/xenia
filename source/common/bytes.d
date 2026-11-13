module common.bytes;

/**
 * Calculate the number of bytes needed to hold bits.
 * @param bits The minimum number of bits needed.
 * @return The number of bytes needed to hold bits.
 */
pure @nogc nothrow
int bytesForBits(const int bits) => (bits + 7) >> 3;

/**
 * Calculate the number of 4-byte units needed to hold the given number of
 * bytes.
 * @param bytes The minimum number of bytes needed.
 * @return The number of 4-byte units needed to hold bytes.
 */
pure @nogc nothrow
uint int32ForBytes(const size_t bytes) => cast(uint)((bytes + 3) >> 2);

/**
 * Calculate the number of bytes (in multiples of 4) needed to hold bytes.
 * @param bytes The minimum number of bytes needed.
 * @return The closest multiple of 4 that is equal or higher than bytes.
 */
pure @nogc nothrow
int padForInt32(const int bytes) => ((bytes + 3) & ~3);

/**
 * Calculate padding needed to bring the number of bytes to an even
 * multiple of 4.
 * @param bytes The minimum number of bytes needed.
 * @return The bytes of padding needed to arrive at the closest multiple of 4
 * that is equal or higher than bytes.
 */
pure @nogc nothrow
int paddingForInt32(const(int) bytes) => (-bytes & 3);
