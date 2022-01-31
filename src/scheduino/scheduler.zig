const Memory = @import("memory.zig");
const process = @import("process.zig");
const Libz = @import("../libz/libz.zig");

pub export var __sp: usize = undefined;

pub var currentId = @as(u8, 0);
pub var hasJumped = false;

pub var l = false;

pub fn switchProcess() void {
    Libz.GpIO.DIGITAL_MODE(4, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_WRITE(4, if (l) .LOW else .HIGH) catch {};

    var new_pid: u8 = 0;
    if (hasJumped) {
        MemState.processes[currentId].stack_pointer = __sp;
        new_pid = if (currentId + 1 == MemState.processes.len) 0 else (currentId + 1);
    }
    currentId = new_pid;
    l = if (l) false else true;
    __sp = MemState.processes[new_pid].stack_pointer;
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
            @intToPtr(*u8, ptr).* = 0;
        }
    }
}
