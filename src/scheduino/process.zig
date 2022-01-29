const Memory = @import("memory.zig");

pub const Process = struct {
    pid: u8,
    state: ProcState,
    stack_layout: Memory.StackLayout,
};

pub const ProcState = enum(u8) {
    New,
    Running,
    Waiting,
    Dead,
    Empty,
};