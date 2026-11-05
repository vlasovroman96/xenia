module xf86int10_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 1999 Egbert Eich
 *
 *                   XFree86 int10 module
 *   execute BIOS int 10h calls in x86 real mode environment
 */
 
// public ////import x11.Xmd;
//public import x11.Xdefs;
public import xf86pciBus;
public import xf86int10;

version (_INT10_PRIVATE) {

/* int.c */
int int_handler(xf86Int10InfoPtr pInt);

/* helper_exec.c */
int setup_int(xf86Int10InfoPtr pInt);
void finish_int(xf86Int10InfoPtr, int sig);
uint getIntVect(xf86Int10InfoPtr pInt, int num);
void pushw(xf86Int10InfoPtr pInt, ushort val);
int run_bios_int(int num, xf86Int10InfoPtr pInt);
void dump_code(xf86Int10InfoPtr pInt);
void dump_registers(xf86Int10InfoPtr pInt);
void stack_trace(xf86Int10InfoPtr pInt);
ubyte bios_checksum(const(ubyte)* start, int size);
void LockLegacyVGA(xf86Int10InfoPtr pInt, legacyVGAPtr vga);
void UnlockLegacyVGA(xf86Int10InfoPtr pInt, legacyVGAPtr vga);

int port_rep_inb(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);
int port_rep_inw(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);
int port_rep_inl(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);
int port_rep_outb(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);
int port_rep_outw(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);
int port_rep_outl(xf86Int10InfoPtr pInt, ushort port, uint base, int d_f, uint count);

ubyte x_inb(ushort port);
ushort x_inw(ushort port);
void x_outb(ushort port, ubyte val);
void x_outw(ushort port, ushort val);
uint x_inl(ushort port);
void x_outl(ushort port, uint val);

ubyte Mem_rb(uint addr);
ushort Mem_rw(uint addr);
uint Mem_rl(uint addr);
void Mem_wb(uint addr, ubyte val);
void Mem_ww(uint addr, ushort val);
void Mem_wl(uint addr, uint val);

/* helper_mem.c */
void setup_int_vect(xf86Int10InfoPtr pInt);
int setup_system_bios(void* base_addr);
void reset_int_vect(xf86Int10InfoPtr pInt);
void set_return_trap(xf86Int10InfoPtr pInt);
Bool int10skip(const(void)* options);
Bool int10_check_bios(int scrnIndex, int codeSeg, const(ubyte)* vbiosMem);
Bool initPrimary(const(void)* options);
version (DEBUG) {
void dprint(c_ulong start, c_ulong size);
}

}                          /* _INT10_PRIVATE */

 /* _XSERVER_XF86INT10_H */
