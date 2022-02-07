const Memory = @import("memory.zig");
const process = @import("process.zig");
const Libz = @import("../libz/libz.zig");

pub export var __sp: usize = undefined;

pub var currentId = @as(u8, 0);
pub var hasJumped = false;
pub var ticks: u32 = 0;

pub var l = false;

pub fn switchProcess() void {
    ticks += 1;
    Libz.GpIO.DIGITAL_MODE(4, .OUTPUT) catch {};
    Libz.GpIO.DIGITAL_WRITE(4, if (l) .LOW else .HIGH) catch {};

    currentId = newPid();
    l = if (l) false else true;
    __sp = MemState.processes[currentId].stack_pointer;
}

fn newPid() u8 {
    if (!hasJumped) {
        return currentId;
    }
    var current_pid: u8 = currentId;
    var _i: u8 = 0;
    while (_i <= MemState.processes.len) : (_i += 1) {
        var i: u8 = if (current_pid + _i >= MemState.processes.len) ((current_pid + _i) - @intCast(u8, MemState.processes.len)) else (current_pid + _i);
        var proc = &MemState.processes[i];
        switch (proc.state) {
            .New => {},
            .Running => {
                return i;
            },
            .Waiting => {
                if (proc.wait_offset <= 1) {
                    proc.wait_offset = 0;
                    proc.state = .Running;
                    return i;
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
            @intToPtr(*u8, ptr).* = 0;
        }
    }
}

pub fn setProcesses() void {
    inline for (MemState.processes) |*p| {
        var address_low = @intToPtr(*volatile u8, p.stack_pointer - 1);
        var address_high = @intToPtr(*volatile u8, p.stack_pointer - 2);
        address_low.* = @intCast(u8, @ptrToInt(p.func) & 0xff);
        address_high.* = @intCast(u8, @ptrToInt(p.func) >> 8);

        const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
        var oldSREG: u8 = SREG.read();
        var address_sreg = @intToPtr(*volatile u8, p.stack_pointer - (2 + 33));
        address_sreg.* = oldSREG;

        p.stack_pointer -= 3 + 33;
        p.state = .Running;
    }
}
