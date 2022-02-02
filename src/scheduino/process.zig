const std = @import("std");
const memory = @import("memory.zig");
const scheduler = @import("scheduler.zig");
const Libz = @import("../libz/libz.zig");

pub const Process = struct {
    pid: u8,
    func: fn () void,
    state: ProcState,
    wait_offset: usize,
    stack_pointer: usize,
    stack_layout: memory.StackLayout,
};

pub const ProcDef = struct {
    func: fn () void,
    stack_size: memory.StackSize,
};

pub const ProcState = enum(u8) {
    New,
    Running,
    Waiting,
    Dead,
};

pub fn handOver() void {
    scheduler.handProcessOver();
}

pub fn sleepTick(tick: usize) void {
    var self_proc = &scheduler.MemState.processes[scheduler.currentId];
    self_proc.state = .Waiting;
    self_proc.wait_offset = tick;
    //handOver();
}

pub export var k = false;

pub fn mainProcess() void {
    scheduler.hasJumped = true;

    Libz.GpIO.DIGITAL_MODE(3, .OUTPUT) catch {};

    var counter: u8 = 0;

    // Initialize the stack of all other processes
    for (scheduler.MemState.processes) |*proc| {
        if (counter != 0) {
            var address_low = @intToPtr(*volatile u8, proc.stack_pointer - 1);
            var address_high = @intToPtr(*volatile u8, proc.stack_pointer - 2);
            address_low.* = @intCast(u8, @ptrToInt(proc.func) & 0xff);
            address_high.* = @intCast(u8, @ptrToInt(proc.func) >> 8);

            const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
            var oldSREG: u8 = SREG.read();
            var address_sreg =
                @intToPtr(*volatile u8, proc.stack_pointer - (2 + 33));
            address_sreg.* = oldSREG;

            proc.state = .Running;

            proc.stack_pointer -= 3 + 33;
        }
        counter += 1;
    }

    sleepTick(10);
    while (true) {
        Libz.Utilities.delay(50_000);
        Libz.GpIO.DIGITAL_WRITE(3, if (k) .LOW else .HIGH) catch {};

        k = if (k) false else true;
    }
}

pub fn secondProcess() void {
    var st: bool = true;
    Libz.GpIO.DIGITAL_MODE(6, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_WRITE(6, .HIGH) catch {};

    while (true) {
        Libz.Utilities.delay(75_000);
        Libz.GpIO.DIGITAL_WRITE(6, if (st) .LOW else .HIGH) catch {};

        st = if (st) false else true;
    }
}

pub fn testFunction() void {}
