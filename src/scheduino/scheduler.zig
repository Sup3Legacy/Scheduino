const Memory = @import("memory.zig");
const process = @import("process.zig");
const Libz = @import("../libz/libz.zig");

pub export var __sp: usize = 0;

pub var currentId = @as(u8, 0);
pub var hasJumped = false;
pub var ticks: u32 = 0;

pub var l = false;

pub fn switchProcess() void {
    ticks += 1;
    Libz.GpIO.DIGITAL_MODE(4, .OUTPUT) catch {};

    newPid();

    Libz.GpIO.DIGITAL_WRITE(4, if (l) .LOW else .HIGH) catch {};
    l = if (l) false else true;
    __sp = MemState.processes[currentId].stack_pointer;
}

fn newPid() void {
    if (!hasJumped) {
        return;
    }
    var current_pid: u8 = currentId;
    var _i: u8 = 1;
    while (_i <= MemState.processes.len) : (_i += 1) {
        var __i = (current_pid + _i);
        var i: u8 = if (__i >= MemState.processes.len) (__i - @intCast(u8, MemState.processes.len)) else __i;
        var proc = &MemState.processes[i];
        switch (proc.state) {
            .New => {},
            .Running => {
                currentId = i;
                return;
            },
            .Waiting => {
                if (proc.wait_offset <= 1) {
                    proc.wait_offset = 0;
                    proc.state = .Running;
                    currentId = i;
                    return;
                } else {
                    proc.wait_offset -= 1;
                }
            },
            .Dead => {},
        }
    }
    while (true) {
        asm volatile ("nop");
    }
}

pub fn handProcessOver() void {
    @call(.{}, Libz.Interrupts._tim1_compb, .{});
}

pub var MemState = blk: {
    const ProcDef = process.ProcDef;
    const procs = [_]process.ProcDef{ ProcDef{
        .func = process.mainProcess,
        .stack_size = .Normal,
    }, ProcDef{
        .func = process.secondProcess,
        .stack_size = .Normal,
    } };
    const bufs = [_]Memory.BufferDef{Memory.BufferDef{
        .ty = u8,
        .size = .Small,
    }};
    comptime var alloc = Memory.allocate(
        procs[0..],
        bufs[0..],
    );
    break :blk alloc;
};

pub fn resetBuffers() void {
    inline for (MemState.buffers) |*b| {
        var ptr: usize = b.start;
        var end: usize = b.start + b.size;
        while (ptr < end) : (ptr += 1) {
            @intToPtr(*volatile u8, ptr).* = 0;
        }
    }
}
