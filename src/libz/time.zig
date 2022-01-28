const constants = @import("constants.zig");

pub fn delay(s: u32, ms: u32, micros: u32) void {
    var total_cycles: u32 = constants.UNO_clock_s * s + constants.UNO_clock_ms * ms + constants.UNO_clock_micros * micros;
    // TBD
    const correction: u32 = 0;
    if (total_cycles <= correction) {
        // Do something to still take `correction` cycles
        return;
    }
}
