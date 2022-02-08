const Libz = @import("libz.zig");

pub inline fn no_op() void {
    asm volatile ("nop" ::: "memory");
}

pub fn readSP() u16 {
    const low = Libz.MmIO.MMIO(0x5D, u8, u8).read();
    const high = Libz.MmIO.MMIO(0x5E, u8, u8).read();
    return @as(u16, low) + @as(u16, high) << 8;
}

pub fn setSP(new_value: u16) void {
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

pub export var interruptEnable: bool = true;

// Disables interrupts in order to perform a critical operation.
// Includes a (most probably useless) memory fence
// PERF: We would want to only disable timer1 ovfb interrupts
pub fn fence() void {
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    interruptEnable = SREG.read() & (@as(u8, 1) << 7) != 0;
    Libz.Interrupts.cli();
    asm volatile ("nop" ::: "memory");
}

// Re-enables interrupts if they ware enables before the `fence`
pub fn deFence() void {
    if (interruptEnable) {
        Libz.Interrupts.sei();
    }
    asm volatile ("nop" ::: "memory");
}
