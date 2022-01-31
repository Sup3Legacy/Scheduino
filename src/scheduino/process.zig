const std = @import("std");
const memory = @import("memory.zig");
const scheduler = @import("scheduler.zig");
const Libz = @import("../libz/libz.zig");

pub const Process = struct {
    pid: u8,
    func: fn () void,
    state: ProcState,
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
    Empty,
};

var k = false;

pub fn mainProcess() void {
    scheduler.hasJumped = true;

    //asm volatile ("cli");

    Libz.GpIO.DIGITAL_MODE(3, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_WRITE(3, if (k) .HIGH else .LOW) catch {};

    k = if (k) false else true;

    var counter: u8 = 0;

    for (scheduler.MemState.processes) |*proc| {
        if (counter != 0) {
            var address = @intToPtr(*volatile usize, proc.stack_pointer);
            address.* = @ptrToInt(proc.func);
            proc.stack_pointer -= 2 + 7;
        }
        counter += 1;
    }

    //asm volatile ("sei");

    //asm volatile ("cli");

    while (true) {
        asm volatile ("nop");
    }
}
