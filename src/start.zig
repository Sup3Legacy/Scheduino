/// Second-stage bootstraping functions.
const std = @import("std");
const Libz = @import("./libz/libz.zig");
const mmio = Libz.MmIO;
const interrupt = Libz.Interrupts;
const utilities = Libz.Utilities;
const Serial = Libz.Serial;
const gpio = Libz.GpIO;
const timer = Libz.Timer;
const Max7219 = Libz.Max7219;

const memory = @import("scheduino/memory.zig");
const scheduler = @import("scheduino/scheduler.zig");
const process = @import("scheduino/process.zig");
const buffer = @import("scheduino/buffer.zig");

var str = "Hello, world!\n\r";

pub fn initSOC() void {
    // Init serial interface
    Serial.init(19200);
    // Init ADC's prescaler. Must do in order to initialize the ADC
    gpio.ADCSRA.write(gpio.ADCSRA.read() | 0x07);
    // Init the LED array controller
    Max7219.init();
}

pub fn bootstrap() noreturn {
    _ = .MemState;
    _ = @import("scheduino/buffer.zig").Buffer.read;
    scheduler.resetBuffers();
    // Init the SoC
    initSOC();
    utilities.delay(100_000);
    // Hello, world!
    Serial.write(str);

    // Reset the Lustre state machine

    // Enable ticking ot keep track of time
    //timer.enableTimer0ClockInt();

    // Print the address of the reset itnerrupt for debug
    utilities.delay(100_000);
    Serial.write_usize(@intCast(u8, interrupt.__ISR[0] >> 8));
    utilities.delay(100_000);
    Serial.write_usize(@intCast(u8, interrupt.__ISR[0]));

    // Somehow screen needs a CRLF-type line ending
    utilities.delay(100_000);
    Serial.write_ch('\r');
    utilities.delay(100_000);
    Serial.write_ch('\n');

    // Enable global interrupts
    interrupt.sei();

    // Attach the step function to the timer1 interrupt
    // Initializes the timer1 interrupt (B overflow)

    main();
}

fn main() noreturn {
    var mainThread: *process.Process = &scheduler.MemState.processes[0];
    var address_low = @intToPtr(*volatile u8, mainThread.stack_pointer - 1);
    var address_high = @intToPtr(*volatile u8, mainThread.stack_pointer - 2);
    address_low.* = @intCast(u8, @ptrToInt(mainThread.func) & 0xff);
    address_high.* = @intCast(u8, @ptrToInt(mainThread.func) >> 8);

    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();
    var address_sreg = @intToPtr(*volatile u8, mainThread.stack_pointer - (2 + 33));
    address_sreg.* = oldSREG;

    mainThread.stack_pointer -= 3 + 33;
    mainThread.state = .Running;

    timer.initTimer1(1_000_000);

    Libz.GpIO.DIGITAL_MODE(2, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_MODE(3, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_WRITE(2, .HIGH) catch {};

    while (true) {
        utilities.delay(100_000);

        Libz.GpIO.DIGITAL_WRITE(2, .HIGH) catch {};

        utilities.delay(100_000);

        Libz.GpIO.DIGITAL_WRITE(2, .LOW) catch {};

        // Housekeeping stuff of needed
    }
}
