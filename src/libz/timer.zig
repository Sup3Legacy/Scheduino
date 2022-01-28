const Libz = @import("libz.zig");
const MMIO = Libz.MmIO.MMIO;
const Constants = Libz.CONSTANTS;

const TIMER1_RESOLUTION: u64 = 65536;

/// Enables the TIMER1 with the given period.
/// It will generate interrupts on TIMER1_B_COMP channel
pub fn initTimer1(comptime period: u64) void {
    // `period` is in µs.
    const ICR1 = MMIO(0x86, u16, u16);
    const TCNT1 = MMIO(0x84, u16, u16);
    const TCCR1B = MMIO(0x81, u8, u8);
    const TCCR1A = MMIO(0x80, u8, u8);
    const TIMSK1 = MMIO(0x6F, u8, u8);

    TCCR1B.write(1 << 4);
    TCCR1A.write(0);
    TIMSK1.write(TIMSK1.read() | (1 << 2));

    // Number of cycles in each period
    comptime var cycles = ((Constants.UNO_clock_s / 100_000 * period) / 20);

    var clockSelectBits: u8 = 0;
    var pwmPeriod: u64 = 0;

    if (cycles < TIMER1_RESOLUTION) {
        clockSelectBits = 1 << 0;
        pwmPeriod = cycles;
    } else if (cycles < TIMER1_RESOLUTION * 8) {
        clockSelectBits = 1 << 1;
        pwmPeriod = cycles / 8;
    } else if (cycles < TIMER1_RESOLUTION * 64) {
        clockSelectBits = 1 << 1 | 1 << 0;
        pwmPeriod = cycles / 64;
    } else if (cycles < TIMER1_RESOLUTION * 256) {
        clockSelectBits = 1 << 2;
        pwmPeriod = cycles / 256;
    } else if (cycles < TIMER1_RESOLUTION * 1024) {
        clockSelectBits = 1 << 2 | 1 << 0;
        pwmPeriod = cycles / 1024;
    } else {
        clockSelectBits = 1 << 2 | 1 << 0;
        pwmPeriod = TIMER1_RESOLUTION - 1;
    }

    // Disable A overflow interrupt
    TCNT1.write(0);
    ICR1.write(@intCast(u16, pwmPeriod));
    // Enable B overflow interrupt
    TCCR1B.write((1 << 4) | clockSelectBits);
}

/// Stop the TIMER1
pub fn stop() void {
    const TCCR1B = MMIO(0x81, u8, u8);
    const TIMSK1 = MMIO(0x6F, u8, u8);

    TIMSK1.write(TIMSK1.read() & ~@as(u8, 1 << 2));
    TCCR1B.write(1 << 4);
}

/// Enable the TIMER0 interrupt with a pre-defined period
/// It is not used by any direct user-purpose but is used
/// to keep track of time on a small scale, e.g. to be
/// used by the `micros` function
pub fn enableTimer0ClockInt() void {
    const TIMSK0 = MMIO(0x6E, u8, u8);
    const TCCR0A = MMIO(0x44, u8, u8); // here we add 0x20 to the address to account for the IO offset!
    const TCCR0B = MMIO(0x45, u8, u8);

    TCCR0A.write(@as(u8, 3));
    TCCR0B.write(@as(u8, 3));

    TIMSK0.write(TIMSK0.read() | @as(u8, 1));
}

/// Disable the TIMER0 interrupt
pub fn disableTimer0ClockInt() void {
    const TIMSK0 = MMIO(0x6E, u8, u8);

    // Add TCCR0A and TCCR0B handling
    TIMSK0.write(TIMSK0.read() & ~@as(u8, 1 << 0));
}

// This part is copied over from the Arduino C library

// Timer0 interrupt to keep track of µs time.
// Useful for various things including detecting time-sensitive events.

const MICROSECONDS_PER_TIMER0_OVERFLOW: u32 = (64 * 256 / (Libz.CONSTANTS.UNO_clock_micros));

// the whole number of milliseconds per timer0 overflow
const MILLIS_INC: u32 = (MICROSECONDS_PER_TIMER0_OVERFLOW / 1000);

// the fractional number of milliseconds per timer0 overflow. we shift right
// by three to fit these numbers into a byte. (for the clock speeds we care
// about - 8 and 16 MHz - this doesn't lose precision.)
const FRACT_INC: u8 = @intCast(u8, (MICROSECONDS_PER_TIMER0_OVERFLOW % 1000) >> 3);
const FRACT_MAX: u8 = (1000 >> 3);

pub var timer0_overflow_count: u32 = 0;
var timer0_millis: u32 = 0;
var timer0_fract: u8 = 0;

/// To attach to the TIM0_OVF int
pub fn timer0OverflowInt() callconv(.C) void {
    var m: u32 = timer0_millis;
    var f: u8 = timer0_fract;

    m +%= MILLIS_INC;
    f +%= FRACT_INC;

    if (f >= FRACT_MAX) {
        f -= FRACT_MAX;
        m +%= 1;
    }
    timer0_fract = f;
    timer0_millis = m;
    timer0_overflow_count +%= 1;
}

/// Returns the number of µs since the last power-up of the core
pub fn micros() u32 {
    var m: u32 = 0;
    var t: u8 = 0;
    const SREG = MMIO(0x3F, u8, u8);
    var oldSREG: u8 = SREG.read();

    const TCNT0 = MMIO(0x46, u8, u8); // + 0x20
    const TIFR0 = MMIO(0x35, u8, u8);

    m = timer0_overflow_count;
    t = TCNT0.read();

    if ((t < 255) and ((TIFR0.read() & 1) != 0)) {
        m += 1;
    }
    SREG.write(oldSREG);

    return ((m << 8) + @as(u32, t)) * (64 / Libz.CONSTANTS.UNO_clock_micros);
}
