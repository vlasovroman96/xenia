module hw.xfree86.utils.compiler;

@nogc: nothrow:
import core.stdc.stdint;
import core.volatile;

alias CARD8  = uint8_t;
alias CARD16 = uint16_t;
alias CARD32 = uint32_t;

version (X86)
{
    enum hasStrongMemoryOrdering = true;

    @nogc nothrow
    void memBarrier()
    {
        asm @nogc nothrow
        {
            mfence;
        }
    }

    @nogc nothrow
    void writeMemBarrier()
    {
        asm @nogc nothrow
        {
            sfence;
        }
    }
}
else version (X86_64)
{
    enum hasStrongMemoryOrdering = true;

    @nogc nothrow
    void memBarrier()
    {
        asm @nogc nothrow
        {
            mfence;
        }
    }

    @nogc nothrow
    void writeMemBarrier()
    {
        asm @nogc nothrow
        {
            sfence;
        }
    }
}
else version (ARM)
{
    @nogc nothrow
    void memBarrier()
    {
        asm @nogc nothrow
        {
            dmb;
        }
    }

    alias writeMemBarrier = memBarrier;
}
else
{
    @nogc nothrow
    void memBarrier() {}

    alias writeMemBarrier = memBarrier;
}

@nogc nothrow
T mmioRead(T)(void* base, size_t offset)
if (is(T == CARD8) || is(T == CARD16) || is(T == CARD32))
{
    auto ptr = cast(T*)(cast(ubyte*) base + offset);

    static if (T.sizeof == 1)
    {
        return volatileLoad(ptr);
    }
    else static if (T.sizeof == 2)
    {
        return volatileLoad(ptr);
    }
    else static if (T.sizeof == 4)
    {
        return volatileLoad(ptr);
    }
}

@nogc nothrow
void mmioWrite(T)(void* base, size_t offset, T value)
if (is(T == CARD8) || is(T == CARD16) || is(T == CARD32))
{
    auto ptr = cast(T*)(cast(ubyte*) base + offset);

    volatileStore(ptr, value);

    writeMemBarrier();
}


alias MMIO_IN8  = mmioRead!CARD8;
alias MMIO_IN16 = mmioRead!CARD16;
alias MMIO_IN32 = mmioRead!CARD32;

alias MMIO_OUT8  = mmioWrite!CARD8;
alias MMIO_OUT16 = mmioWrite!CARD16;
alias MMIO_OUT32 = mmioWrite!CARD32;


version (X86)
{
    @nogc nothrow
    void outb(ushort port, ubyte value)
    {
        asm
        {
            mov DX, port;
            mov AL, value;
            out DX, AL;
        }
    }

    @nogc nothrow
    ubyte inb(ushort port)
    {
        ubyte value;

        asm
        {
            mov DX, port;
            in AL, DX;
            mov value, AL;
        }

        return value;
    }
}

version (X86_64)
{
    @nogc nothrow
    void outb(ushort port, ubyte value)
    {
        asm @nogc nothrow
        {
            mov DX, port;
            mov AL, value;
            out DX, AL;
        }
    }

    @nogc nothrow
    ubyte inb(ushort port)
    {
        ubyte value;

        asm @nogc nothrow
        {
            mov DX, port;
            in AL, DX;
            mov value, AL;
        }

        return value;
    }
}


@nogc nothrow
void slowBCopyToBus(const(void)* src, void* dst, size_t size)
{
    import core.stdc.string : memcpy;

    memcpy(dst, src, size);
    writeMemBarrier();
}

@nogc nothrow
void slowBCopyFromBus(const(void)* src, void* dst, size_t size)
{
    import core.stdc.string : memcpy;

    memcpy(dst, src, size);
    memBarrier();
}