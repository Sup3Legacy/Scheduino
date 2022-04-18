const Memory = @import("memory.zig");
const process = @import("process.zig");
const Libz = @import("../libz/libz.zig");

// Global variable used to handle the stack pointer
// upon context switch
pub export var __sp: usize = undefined;

// Id of the currently running process
pub var currentId = @as(u8, 0);

// Whether the system has already jumped into
// its operational mode
pub var hasJumped = false;

// Number of elapsed ticks since start
pub var ticks: u32 = 0;

pub var l = false;

// Called from the timer interrupt
pub fn switchProcess() void {
    // This operation is overflowing as we wouldn't want to crash at overflow
    ticks +%= 1;
    currentId = newPid();
    l = if (l) false else true;
    __sp = MemState.processes[currentId].stack_pointer;
}

// Determines the next process to be run based using a simple round-robin.
// It supports idle processes.
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

    // Not runnable process has been found.
    // Wait for the next rescheduling.
    while (true) {
        asm volatile ("nop");
    }
}

// Manually trigger the context switch.
// FIX: Does not work as it pushes a wrong address onto the stack
// TODO: Setup return address hack to make this work.
pub fn handProcessOver() void {
    @call(.{}, Libz.Interrupts._tim1_compb, .{});
}

// The global state structure of the OS. Holds all information
// about the processes and buffers
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

// Reset all buffers to zero. Midly important.
pub fn resetBuffers() void {
    inline for (MemState.buffers) |*b| {
        var ptr: usize = b.start;
        var end: usize = b.start + b.size;
        while (ptr < end) : (ptr += 1) {
            @intToPtr(*u8, ptr).* = 0;
        }
    }
}

// Setup the stack of each process. Highly important.
// HACK: Maybe make these things more simple
pub fn setProcesses() void {
    inline for (MemState.processes) |*p| {
        // The first time a process runs, it must be manually setup
        // by injecting its PC and the right place on the stack
        // so that the `reti` instruction fetches this address
        // and jumps into the process's main code.
        var address_low = @intToPtr(*volatile u8, p.stack_pointer - 1);
        var address_high = @intToPtr(*volatile u8, p.stack_pointer - 2);
        address_low.* = @intCast(u8, @ptrToInt(p.func) & 0xff);
        address_high.* = @intCast(u8, @ptrToInt(p.func) >> 8);

        // Write a neutral value to the process's SREG (TODO)
        const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
        var oldSREG: u8 = SREG.read();
        var address_sreg = @intToPtr(*volatile u8, p.stack_pointer - (2 + 33));
        address_sreg.* = oldSREG;

        // Change the process's SP in the OS's memory to account for
        // the extra stack taken by the ISR context on stack.
        p.stack_pointer -= 3 + 33;

        // Set the process's state to `Running`
        p.state = .Running;
    }
}
