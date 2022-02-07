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
    handOver();
}

pub export var k = false;

pub fn mainProcess() void {
    scheduler.hasJumped = true;

    asm volatile ("sei");

    Libz.GpIO.DIGITAL_MODE(3, .OUTPUT) catch {};

    while (true) {
        sleepTick(10);
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
