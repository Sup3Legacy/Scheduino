const std = @import("std");
const memory = @import("memory.zig");
const scheduler = @import("scheduler.zig");
const Libz = @import("../libz/libz.zig");

/// OS representation of a process
///
/// * pid: id of the process
/// * func: start function
/// * state: current state
/// * wait_offset: if in Waiting mode, number of cycles to wait for
/// * stack_pointer: saved SP
/// * stack_layout: comptime information about the process's stack
pub const Process = struct {
    pid: u8,
    func: fn () void,
    state: ProcState,
    wait_offset: usize,
    stack_pointer: usize,
    stack_layout: memory.StackLayout,
};

/// * Comptime definition of a process
///
/// * func: start function
/// * stack_size: requested stack size
pub const ProcDef = struct {
    func: fn () void,
    stack_size: memory.StackSize,
};

/// State of a process
///
/// * New: Not yet started
/// * Running: normal mode
/// * Waiting: paused, waiting for an event
/// * Dead: will not be revived
pub const ProcState = enum(u8) {
    New,
    Running,
    Waiting,
    Dead,
};

/// Cooperatively hand control over to the next process
/// WARN: Not workign currently
pub fn handOver() void {
    scheduler.handProcessOver();
}

/// Initialize sleep
pub fn sleepTick(tick: usize) void {
    var self_proc = &scheduler.MemState.processes[scheduler.currentId];
    self_proc.state = .Waiting;
    self_proc.wait_offset = tick;
    handOver();
}

pub export var k = false;

/// Test process n.1
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

/// Test process n.2
pub fn secondProcess() void {
    var st: bool = true;
    Libz.GpIO.DIGITAL_MODE(6, .OUTPUT) catch {};

    while (true) {
        Libz.Utilities.delay(75_000);
        Libz.GpIO.DIGITAL_WRITE(6, if (st) .LOW else .HIGH) catch {};

        st = if (st) false else true;
    }
}
