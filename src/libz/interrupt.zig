const Libz = @import("libz.zig");
const Utilities = Libz.Utilities;
const MMIO = Libz.MmIO.MMIO;
const GPIO = Libz.GpIO;

/// Enable interrupts globaly
pub inline fn sei() void {
    asm volatile ("sei" ::: "memory");
}

/// Disable interrupts globaly
pub inline fn cli() void {
    asm volatile ("cli" ::: "memory");
}

pub const PCIFR = MMIO(0x1b, u8, u8);
// en/disable pin-interrupts on a per-port basis
const PCICR = MMIO(0x68, u8, u8);
// Pin interrupt mask on port B
const PCMSK0 = MMIO(0x6b, u8, u8);
// Pin interrupt mask on port C
const PCMSK1 = MMIO(0x6c, u8, u8);
// Pin interrupt mask on port D
const PCMSK2 = MMIO(0x6d, u8, u8);

const Port = enum {
    C,
    B,
    D,
};

const ports = struct {
    portB: u8,
    portC: u8,
    portD: u8,
};

var last_pin_state = ports{
    .portB = 0,
    .portC = 0,
    .portD = 0,
};

/// Interrupt nesting can (and mostly will) cause instability and crashes
var INTERRUPT_NESTING: bool = false;

/// Toggle software-controlled interrupt nesting
/// This does not totally deactive interrupts for now,
/// so every incoming interrupt will still consume some CPU time.
/// However, with `INTERRUPT_NESTING` equal to `false`,
/// the ISR will at least prematurely return is nesting is detected.
pub fn toggleInterruptNesting(state: bool) void {
    INTERRUPT_NESTING = state;
}

/// 
var is_ticking: [28]bool = [_]bool{false} ** 28;

const State = enum {
    LOW,
    HIGH,
    ANY,
};

pub fn stateOfInt(i: isize) State {
    switch (i) {
        0 => {
            return .LOW;
        },
        1 => {
            return .HIGH;
        },
        else => {
            return .ANY;
        },
    }
}

/// Timestamp reference for each pin. Used for `time_pulse`
pub var time_reference: [20]u32 = [_]u32{0} ** 20;

pub var last_time: [20]u32 = [_]u32{0} ** 20;

pub var did_interrupt_occur: [20]bool = [_]bool{false} ** 20;

pub var do_interrupt: [20]bool = [_]bool{false} ** 20;

pub var interrupt_state: [20]State = [_]State{.ANY} ** 20;

/// Set the reference timestamp to the actual time
pub fn setReference(pin: u8) void {
    var micros = Libz.Timer.micros();
    time_reference[pin] = micros;
    //last_time[pin] = micros;
    //did_interrupt_occur[pin] = false;
}

pub fn setInterruptState(pin: u8, state: State) void {
    interrupt_state[pin] = state;
}

fn updatePinTime(pin: u8) void {
    var micros = Libz.Timer.micros();
    last_time[pin] = micros;
}

pub fn getLastTime(pin: u8) u32 {
    return last_time[pin];
}

pub fn getTimeReference(pin: u8) u32 {
    return time_reference[pin];
}

pub fn resetPinInterrupt(pin: u8) void {
    did_interrupt_occur[pin] = false;
}

fn handlePinInterrupt(pin_event: PinInterrupt) void {
    switch (pin_event) {
        PinInterrupt.Rising => |i| {
            updatePinTime(i);
            switch (interrupt_state[i]) {
                State.LOW => {
                    // Stop
                    did_interrupt_occur[i] = true;
                    do_interrupt[i] = false;
                },
                State.HIGH => {
                    // Continue
                    did_interrupt_occur[i] = false;
                    setReference(i);
                },
                State.ANY => {
                    // Stop
                    did_interrupt_occur[i] = true;
                    do_interrupt[i] = false;
                },
            }
            togglePinInterrupt(i, do_interrupt[i]);
        },
        PinInterrupt.Falling => |i| {
            updatePinTime(i);
            switch (interrupt_state[i]) {
                State.LOW => {
                    did_interrupt_occur[i] = false;
                    setReference(i);
                },
                State.HIGH => {
                    did_interrupt_occur[i] = true;
                    do_interrupt[i] = false;
                },
                State.ANY => {
                    did_interrupt_occur[i] = true;
                    do_interrupt[i] = false;
                },
            }
            togglePinInterrupt(i, do_interrupt[i]);
        },
    }
}

const PinInterruptType = enum {
    Rising,
    Falling,
};

/// The contained value is the index of the pin
const PinInterrupt = union(PinInterruptType) {
    Rising: u8,
    Falling: u8,
};

fn pinInterruptToPin(pi: PinInterrupt) u8 {
    switch (pi) {
        PinInterrupt.Rising => |i| return i,
        PinInterrupt.Falling => |i| return i,
    }
}

const PinInterruptError = error{
    MultipleChanges,
    NoChange,
    UnknownError,
};

fn findSetBit(arg: u8) PinInterruptError!u8 {
    var res: ?u8 = null;
    var i: u8 = 0;
    while (i < 8) : (i += 1) {
        if (arg & (@as(u8, 1) << @intCast(u3, i)) != 0) {
            if (res != null) {
                return PinInterruptError.MultipleChanges;
            } else {
                res = i;
            }
        }
    }
    return res orelse return PinInterruptError.NoChange;
}

fn detectInterrupt(port: Port) PinInterruptError!PinInterrupt {
    switch (port) {
        .B => {
            var int_mask = PCMSK0.read();
            var new_status = GPIO.PINB.read();
            var masked_status = (new_status ^ last_pin_state.portB) & int_mask;
            last_pin_state.portB = new_status;
            var index = findSetBit(masked_status) catch |err| return err;
            if (new_status & (@as(u8, 1) << @intCast(u3, index)) != 0) {
                return PinInterrupt{ .Rising = index + 8 };
            } else {
                return PinInterrupt{ .Falling = index + 8 };
            }
        },
        .C => {
            var int_mask = PCMSK1.read();
            var new_status = GPIO.PINC.read();
            var masked_status = (new_status ^ last_pin_state.portC) & int_mask;
            last_pin_state.portC = new_status;
            var index = findSetBit(masked_status) catch |err| return err;
            if (new_status & (@as(u8, 1) << @intCast(u3, index)) != 0) {
                return PinInterrupt{ .Rising = index + 14 };
            } else {
                return PinInterrupt{ .Falling = index + 14 };
            }
        },
        .D => {
            var int_mask = PCMSK2.read();
            var new_status = GPIO.PIND.read();
            var masked_status = (new_status ^ last_pin_state.portD) & int_mask;
            last_pin_state.portD = new_status;
            var index = findSetBit(masked_status) catch |err| return err;
            if (new_status & (@as(u8, 1) << @intCast(u3, index)) != 0) {
                return PinInterrupt{ .Rising = index + 0 };
            } else {
                return PinInterrupt{ .Falling = index + 0 };
            }
        },
    }

    return .UnknownError;
}

pub fn togglePinInterrupt(pin_id: u8, enabled: bool) void {
    switch (pin_id) {
        0...7 => {
            if (enabled) {
                PCMSK2.write(PCMSK2.read() | GPIO.itb(pin_id));
            } else {
                PCMSK2.write(PCMSK2.read() & ~GPIO.itb(pin_id));
            }
            togglePinChangeIntPort(.D, enabled);
        },
        8...13 => {
            if (enabled) {
                PCMSK0.write(PCMSK0.read() | GPIO.itb(pin_id));
            } else {
                PCMSK0.write(PCMSK0.read() & ~GPIO.itb(pin_id));
            }
            togglePinChangeIntPort(.B, enabled);
        },
        14...19 => {
            if (enabled) {
                PCMSK1.write(PCMSK1.read() | GPIO.itb(pin_id));
            } else {
                PCMSK1.write(PCMSK1.read() & ~GPIO.itb(pin_id));
            }
            togglePinChangeIntPort(.C, enabled);
        },
        else => {
            return;
        },
    }
}

/// Attach an ISR at runtime
/// Not operational for now
pub fn attachInterrupt(id: usize, addr: usize) void {
    __ISR[id] = addr;
}

// Interrupt vector. Put at the right place by the linker
comptime {
    asm (
        \\.section .vectors
        \\ jmp _start
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _pcint0
        \\ jmp _pcint1
        \\ jmp _pcint2
        \\ jmp _wdt
        \\ jmp _tim2_compa
        \\ jmp _tim2_compb
        \\ jmp _tim2_ovf
        \\ jmp _tim1_capt
        \\ jmp _tim1_compa
        \\ jmp _tim1_compb 
        \\ jmp _tim1_ovf
        \\ jmp _tim0_compa
        \\ jmp _tim0_compb
        \\ jmp _tim0_ovf
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt
        \\ jmp _unknown_interrupt        
    );
}

/// Vain attempt at creating an universal ISR
pub export fn _handle_ir() void {
    asm volatile (
        \\ push r18
        \\ push r19
        \\ push r20
        \\ push r21
        \\ push r22
        \\ push r23
        \\ push r24
        \\ push r25
        \\ push r26
        \\ push r27
        \\ push r28
        \\ push r29
        \\ push r30
        \\ push r31
        \\ lds r30, __ISR_LOADED
        \\ cpi r30, 0x69 ; Check whether the .data segment has been loaded into the RAM
        \\ brne .lol
        //\\ rjmp _start2
        \\ lds r30, (__ISR)
        \\ lds r31, (__ISR + 1)
        //\\ lds r31, __ISR+1
        \\ icall
        \\ rjmp .lol1
        \\.lol:
        \\ call _start
        \\.lol1:
        \\ pop r31
        \\ pop r30
        \\ pop r29
        \\ pop r28
        \\ pop r27
        \\ pop r26
        \\ pop r25
        \\ pop r24
        \\ pop r23
        \\ pop r22
        \\ pop r21
        \\ pop r20
        \\ pop r19
        \\ pop r18
        \\ reti
        ::: "r30", "r31");
}

/// Hacky variable to check whether the .data segment has already been loaded into RAM. 
/// If not, the ISR no. 0 must jump directly to _start instead of reading garbage in `__ISR`
/// This is because `__ISR` is located in the .Data segment. So any interrupt happening before
/// this segment gets loaded into RAM would try to jump to whatever offset was at this place
/// in memory before .data-loading
/// Basically, if this variable isn't equal to `0x69`, we MUST NOT use anything from .data
pub export var __ISR_LOADED: u16 = 0x69;

/// runtime ISR-vector.
pub export var __ISR = [_]usize{0x068} ** 28;

pub fn initISR() void {
    var index: u8 = 0;
    while (index < 28) : (index += 1) {
        __ISR[index] = @ptrToInt(_unknown_interrupt);
    }
}

/// Fallback ISR
export fn _unknown_interrupt() callconv(.Naked) noreturn {
    while (true) {}
}

/// Ext int 0
export fn _int0() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);

    var oldSREG: u8 = SREG.read();
    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}

/// Ext int 1
export fn _int1() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}

/// Pin change int 0
export fn _pcint0() callconv(.Interrupt) void {
    asm volatile ("cli" ::: "memory");
    //push();
    //const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    //var oldSREG: u8 = SREG.read();

    var a = detectInterrupt(.B) catch null;
    if (a) |pin| {
        handlePinInterrupt(pin);
    }

    //SREG.write(oldSREG);
    //pop();

    //asm volatile ("reti");
}

/// Pin change int 1
export fn _pcint1() callconv(.Interrupt) void {
    asm volatile ("cli" ::: "memory");
    var a = detectInterrupt(.C) catch null;

    if (a) |pin| {
        handlePinInterrupt(pin);
    }
}

/// Pin change int 2
export fn _pcint2() callconv(.Interrupt) void {
    asm volatile ("cli" ::: "memory");
    var a = detectInterrupt(.D) catch null;
    if (a) |pin| {
        handlePinInterrupt(pin);
    }
}

/// Watchdog timeout
export fn _wdt() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}

// 7 0x000C WDT Watchdog Time-out Interrupttime_reference
// 8 0x000E TIMER2 COMPA Timer/Counter2 Compare Match A
export fn _tim2_compa() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 9 0x0010 TIMER2 COMPB Timer/Counter2 Compare Match B
export fn _tim2_compb() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 10 0x0012 TIMER2 OVF Timer/Counter2 Overflow
export fn _tim2_ovf() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 11 0x0014 TIMER1 CAPT Timer/Counter1 Capture Event
export fn _tim1_capt() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 12 0x0016 TIMER1 COMPA Timer/Counter1 Compare Match A
export fn _tim1_compa() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 13 0x0018 TIMER1 COMPB Timer/Coutner1 Compare Match B
pub export fn _tim1_compb() callconv(.C) noreturn {
    //asm volatile ("cli" ::: "memory");
    //push();
    //asm volatile ("nop" ::: "memory");
    //const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    //var oldSREG: u8 = SREG.read();

    asm volatile (
        \\ push r0
        \\ push r1
        \\ push r2
        \\ push r3
        \\ push r4
        \\ push r5
        \\ push r6
        \\ push r7
        \\ push r8
        \\ push r9
        \\ push r10
        \\ push r11
        \\ push r12
        \\ push r13
        \\ push r14
        \\ push r15
        \\ push r16
        \\ push r17
        \\ push r18
        \\ push r19
        \\ push r20
        \\ push r21
        \\ push r22
        \\ push r23
        \\ push r24
        \\ push r25
        \\ push r26
        \\ push r27
        \\ push r28
        \\ push r29
        \\ push r30
        \\ push r31
    );

    //Libz.Serial.write_ch('x');
    //_ = @import("../main.zig").step();
    //var v = @intCast(u16, Utilities.read_SP());
    //Libz.Serial.write_usize(@intCast(u8, v >> 8));
    //Utilities.delay(100);
    //Libz.Serial.write_usize(@intCast(u8, v));
    //Libz.Serial.write("\n\r");

    asm volatile (
        \\ in r0, 0x7F
        \\ push r0
    );

    //var sp_low_old: u8 = asm volatile (
    //    \\ in r1, 0x7D
    //    : [ret] "={r1}" (-> u8),
    //    :
    //    : "r1"
    //);
    //var sp_high_old: u8 = asm volatile (
    //    \\ in r2, 0x7E
    //    : [ret] "={r2}" (-> u8),
    //    :
    //    : "r2"
    //);

    asm volatile (
        \\ in r0, 0x7D
        \\ sts (__sp), r0
        \\ in r0, 0x7E
        \\ sts (__sp + 1), r0
        ::: "r0");

    const scheduler = @import("../scheduino/scheduler.zig");

    asm volatile ("nop" ::: "memory");

    @call(.{ .modifier = .never_inline }, scheduler.switchProcess, .{});

    asm volatile ("nop" ::: "memory");

    asm volatile (
        \\ lds r0, (__sp)
        \\ out 0x7D, r0
        \\ lds r0, (__sp + 1)
        \\ out 0x7E, r0
        ::: "r0");

    //var sp_low: u8 = @intCast(u8, scheduler.__sp & 0xff);
    //var sp_high: u8 = @intCast(u8, (scheduler.__sp >> 8) & 0xff);

    //asm volatile (
    //    \\ out 0x5E, r2
    //    :
    //    : [sp_high] "{r2}" (sp_high),
    //    : "r2"
    //);

    //asm volatile (
    //    \\ out 0x5D, r0
    //    :
    //    : [sp_low] "{r1}" (sp_low),
    //    : "r1"
    //);

    //@intToPtr(*volatile u8, 0x5e).* = sp_high;
    //@intToPtr(*volatile u8, 0x5d).* = sp_low;

    asm volatile (
        \\ pop r0
        \\ out 0x7F, r0
    );

    asm volatile (
        \\ pop r31
        \\ pop r30
        \\ pop r29
        \\ pop r28
        \\ pop r27
        \\ pop r26
        \\ pop r25
        \\ pop r24
        \\ pop r23
        \\ pop r22
        \\ pop r21
        \\ pop r20
        \\ pop r19
        \\ pop r18
        \\ pop r17
        \\ pop r16
        \\ pop r15
        \\ pop r14
        \\ pop r13
        \\ pop r12
        \\ pop r11
        \\ pop r10
        \\ pop r9
        \\ pop r8
        \\ pop r7
        \\ pop r6
        \\ pop r5
        \\ pop r4
        \\ pop r3
        \\ pop r2
        \\ pop r1
        \\ pop r0
    );

    sei();

    asm volatile ("reti");

    unreachable;

    //SREG.write(oldSREG);
    //asm volatile ("nop" ::: "memory");
    //pop();
}
// 14 0x001A TIMER1 OVF Timer/Counter1 Overflow
export fn _tim1_ovf() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 15 0x001C TIMER0 COMPA Timer/Counter0 Compare Match A
export fn _tim0_compa() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 16 0x001E TIMER0 COMPB Timer/Counter0 Compare Match B
export fn _tim0_compb() callconv(.Naked) void {
    push();
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();

    SREG.write(oldSREG);
    pop();

    asm volatile ("reti");
}
// 17 0x0020 TIMER0 OVF Timer/Counter0 Overflow
export fn _tim0_ovf() callconv(.Interrupt) void {
    Libz.Timer.timer0OverflowInt();
}
// 18 0x0022 SPI, STC SPI Serial Transfer Complete
// 19 0x0024 USART, RX USART Rx Complete
// 20 0x0026 USART, UDRE USART, Data Register Empty
// 21 0x0028 USART, TX USART, Tx Complete
// 22 0x002A ADC ADC Conversion Complete
// 23 0x002C EE READY EEPROM Ready
// 24 0x002E ANALOG COMP Analog Comparator
// 25 0x0030 TWI 2-wire Serial Interface
// 0x0032 SPM READY Store Program Memory Ready

fn togglePinChangeIntPort(port: Port, state: bool) void {
    switch (port) {
        Port.B => {
            if (state) {
                PCICR.write(PCICR.read() | @as(u8, 1));
            } else {
                PCICR.write(PCICR.read() & ~@as(u8, 1));
            }
        },
        Port.C => {
            if (state) {
                PCICR.write(PCICR.read() | @as(u8, 2));
            } else {
                PCICR.write(PCICR.read() & ~@as(u8, 2));
            }
        },
        Port.D => {
            if (state) {
                PCICR.write(PCICR.read() | @as(u8, 4));
            } else {
                PCICR.write(PCICR.read() & ~@as(u8, 4));
            }
        },
    }
}

pub fn pop() void {
    asm volatile (
        \\ pop r31
        \\ pop r30
        \\ pop r29
        \\ pop r28
        \\ pop r27
        \\ pop r26
        \\ pop r25
        \\ pop r24
        \\ pop r23
        \\ pop r22
        \\ pop r21
        \\ pop r20
        \\ pop r19
        \\ pop r18
        \\ pop r17
        \\ pop r16
        \\ pop r15
        \\ pop r14
        \\ pop r13
        \\ pop r12
        \\ pop r11
        \\ pop r10
        \\ pop r9
        \\ pop r8
        \\ pop r7
        \\ pop r6
        \\ pop r5
        \\ pop r4
        \\ pop r3
        \\ pop r2
        \\ pop r1
        \\ pop r0
    );
}

pub fn push() void {
    asm volatile (
        \\ push r0
        \\ push r1
        \\ push r2
        \\ push r3
        \\ push r4
        \\ push r5
        \\ push r6
        \\ push r7
        \\ push r8
        \\ push r9
        \\ push r10
        \\ push r11
        \\ push r12
        \\ push r13
        \\ push r14
        \\ push r15
        \\ push r16
        \\ push r17
        \\ push r18
        \\ push r19
        \\ push r20
        \\ push r21
        \\ push r22
        \\ push r23
        \\ push r24
        \\ push r25
        \\ push r26
        \\ push r27
        \\ push r28
        \\ push r29
        \\ push r30
        \\ push r31
    );
}
