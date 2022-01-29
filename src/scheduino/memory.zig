const process = @import("process.zig");
const RAM_START = 0x800100;
const RAM_SIZE = 2000; // Less than 2048

pub const StackSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,

    pub fn to_usize(this: *@This()) usize {
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

    pub fn to_usize(this: *@This()) usize {
        _ = this;
        return 128;
    }
};

pub const BufferDef = struct {
    ty: type,
    size: usize,
};

pub fn Buffer(T: type) type {
    _ = T;
    return struct {
        start: usize,
        size: BufferSize,
        lock: Lock,
    };
}

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

var State = {
    comptime var alloc = allocate({}, {});
    alloc;
};


fn allocate(comptime proc: []process.ProcDef, comptime buf: []BufferDef) struct { processes: [_]process.Process, buffers: [_]Buffer } {
    comptime var used: usize = 0;

    comptime var processes = []process.Process{undefined} ** proc.len;
    comptime var buffers = []Buffers{undefined} ** buf.len;

    comptime var i: usize = 0;

    while (i < proc.len) : (i += 1) {
        var size = proc[i].stack_size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to process stack {}", .{i});
            @compileError("Exiting.");
        }
        processes[i] = process.Process{ .pid = @intCast(u8, i), .state = .New, .stack_layout = StackLayout{} };

        used += size;
    }

    i = 0;
    while (i < proc.buf) : (i += 1) {
        var size = buf[i].stack_size.to_usize();
        if (used + size > RAM_SIZE) {
            @compileLog("Cannot allocate memory to buffer {}", .{i});
            @compileError("Exiting.");
        }
        buffers[i] = Buffer{
            .start = used,
            .size = buf[i].size,
            .lock = Lock {
                .locked = false,
                .pid = null,
            },
        };

        used += size;
    }

    return struct {
        processes = processes,
        buffers = buffers,
    };
}
