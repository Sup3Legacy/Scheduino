const std = @import("std");
const process = @import("process.zig");
const RAM_START = 0x800100 + 0x00100; // Account for static data
const RAM_SIZE = 2000 - 0x00100; // Less than 2048

pub const StackSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,

    pub fn to_usize(this: *const @This()) usize {
        _ = this;
        return 128;
    }
};

pub const StackLayout = struct {
    start: usize,
    size: StackSize,
};

pub const BufferSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,

    pub fn to_usize(this: *const @This()) usize {
        _ = this;
        return 128;
    }
};

pub const BufferDef = struct {
    ty: type,
    size: BufferSize,
};

const Buffer = struct {
    start: usize,
    size: usize,
    used: usize,
    lock: Lock,
};

pub const Lock = struct {
    locked: bool,
    pid: ?u8,

    pub fn unlock(this: *@This()) void {
        _ = this;
    }

    pub fn lock(this: *@This()) void {
        _ = this;
    }

    pub fn new() @This() {
        return @This(){
            .locked = false,
            .id = null,
        };
    }
};

fn test_func() void {
    var i: u8 = 0;
    i += 1;
}

pub var MemState = blk: {
    const ProcDef = process.ProcDef;
    const procs = [_]process.ProcDef{ProcDef{
        .func = test_func,
        .stack_size = .Small,
    }};
    const bufs = [_]BufferDef{BufferDef{
        .ty = u8,
        .size = .Small,
    }};
    comptime var alloc = allocate(
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

fn allocate(comptime proc: []const process.ProcDef, comptime buf: []const BufferDef) struct { processes: [proc.len]process.Process, buffers: [buf.len]Buffer } {
    comptime var used: usize = 0;

    comptime var processes = [_]process.Process{undefined} ** proc.len;
    comptime var buffers = [_]Buffer{undefined} ** buf.len;

    comptime var i: usize = 0;

    while (i < proc.len) : (i += 1) {
        var size = proc[i].stack_size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to process stack {}", .{i});
            @compileError("Exiting.");
        }
        processes[i] = process.Process{ .pid = @intCast(u8, i), .state = .New, .stack_layout = StackLayout{ .start = used, .size = proc[i].stack_size } };

        used += size;
    }

    i = 0;
    while (i < buf.len) : (i += 1) {
        var size = buf[i].size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to buffer {}", .{i});
            @compileError("Exiting.");
        }
        buffers[i] = Buffer{
            .start = used,
            .size = size,
            .used = @as(usize, 0),
            .lock = Lock{
                .locked = false,
                .pid = null,
            },
        };

        used += size;
    }

    return .{
        .processes = processes,
        .buffers = buffers,
    };
}
