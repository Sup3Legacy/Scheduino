const std = @import("std");
const process = @import("process.zig");
const buffer = @import("buffer.zig");
const RAM_START = 0x00200; // Account for static data
const RAM_SIZE = 2000 - 0x00200; // Less than 2048

// Size of stacks
pub const StackSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,

    pub fn to_usize(this: *const @This()) usize {
        switch (this.*) {
            .XSmall => return 32,
            .Small => return 64,
            .Normal => return 128,
            .Large => return 256,
            .XLarge => return 512,
        }
    }
};

pub const StackLayout = struct {
    start: usize,
    size: StackSize,
};

// Size of buffers
pub const BufferSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,

    // INFO: Might want to adapt this
    pub fn to_usize(this: *const @This()) usize {
        switch (this.*) {
            .XSmall => return 32,
            .Small => return 64,
            .Normal => return 128,
            .Large => return 256,
            .XLarge => return 512,
        }
    }
};

pub const BufferDef = struct {
    ty: type,
    size: BufferSize,
};

// Compile-time static stack-and-buffer allocation.
// Comptime-crashes in the case of a OOM exception.
pub fn allocate(comptime proc: []const process.ProcDef, comptime buf: []const BufferDef) struct { processes: [proc.len]process.Process, buffers: [buf.len]buffer.Buffer } {
    comptime var used: usize = 0;

    comptime var processes = [_]process.Process{undefined} ** proc.len;
    comptime var buffers = [_]buffer.Buffer{undefined} ** buf.len;

    comptime var i: usize = 0;

    while (i < proc.len) : (i += 1) {
        var size = proc[i].stack_size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to process stack {}", .{i});
            @compileError("Exiting.");
        }
        processes[i] = process.Process{
            .pid = @intCast(u8, i),
            .func = proc[i].func,
            .state = .New,
            .wait_offset = 0,
            .stack_pointer = used + RAM_START + size - 1,
            .stack_layout = StackLayout{ .start = used + RAM_START + size - 1, .size = proc[i].stack_size },
        };

        used += size;
    }

    i = 0;
    while (i < buf.len) : (i += 1) {
        var size = buf[i].size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to buffer {}", .{i});
            @compileError("Exiting.");
        }
        buffers[i] = buffer.Buffer{
            .start = used + RAM_START,
            .size = size,
            .used = @as(usize, 0),
            .lock = buffer.Lock{
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
