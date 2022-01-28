const Libz = @import("libz.zig");

pub inline fn no_op() void {
    asm volatile ("nop" ::: "memory");
}

pub fn read_SP() u16 {
    const low = Libz.MmIO.MMIO(0x5D, u8, u8).read();
    const high = Libz.MmIO.MMIO(0x5E, u8, u8).read();
    return @as(u16, low) + @as(u16, high) << 8;
}

pub fn set_SP(new_value: u16) void {
    _ = new_value;
    // TODO in asm because changing the SP requires some thinking
}

// ~16 instructions per delay unit so ~~50 clock cycle
pub fn delay(m: u32) void {
    var i: u32 = 0;
    while (i < m) {
        i += 1;
        asm volatile ("nop");
    }
}
