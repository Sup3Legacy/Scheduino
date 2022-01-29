const memory = @import("memory.zig");

pub const Process = struct {
    pid: u8,
    state: ProcState,
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
