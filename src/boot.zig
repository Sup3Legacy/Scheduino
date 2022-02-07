pub const Libz = @import("./libz/libz.zig");
pub const std = @import("std");
pub const Serial = Libz.Serial;

/// Entry point of the program
/// It initializes the memory and ISRs and then jumps into the 
// bootstrap main function
pub export fn _start() callconv(.Naked) noreturn {
    @call(.{ .modifier = .never_inline }, copyDataToRAM, .{});
    @call(.{ .modifier = .never_inline }, clearBSS, .{});
    //@call(.{.modifier = .never_inline }, updateISR, .{});

    // Set ISR magic number
    // This enables the use of the second-stage interrupt vector table
    Libz.Interrupts.__ISR_LOADED = 0x69;

    @call(.{ .modifier = .never_inline }, @import("start.zig").bootstrap, .{});

    while (true) {}
}

/// Override panic function
pub fn panic(msg: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn {
    Libz.Interrupts.cli();
    _ = stack_trace;
    Serial.init(19200);
    Libz.Utilities.delay(100_000);
    Serial.write(msg);
    Libz.Utilities.delay(100_000);
    Serial.write("\n\r___fault (kernel dumped).\n\rWe're not using any C code but it somehow crashed anyway...");
    while (true) {}
}

/// Not used for now
fn updateISR() void {
    asm volatile (
        \\ ldi r30, lo8(_start)
        \\ ldi r31, hi8(_start)
        \\ sts __ISR, r30
        \\ sts __ISR + 1, r31
        ::: "r30", "r31");

    //var ptr = @ptrCast(*volatile usize, &(@import("interrupt.zig").__ISR[0]));
    //var add = @ptrToInt(&(_start2));
    //ptr.* = add;
    //@import("interrupt.zig").initISR();
}

/// Load the .data segment into RAM. Highly important!
fn copyDataToRAM() void {
    asm volatile (
        \\
        \\ ldi r30, lo8(__data_load_start)
        \\ ldi r31, hi8(__data_load_start)
        \\
        \\ ldi r28, lo8(__data_start)
        \\ ldi r29, hi8(__data_start)
        \\
        \\ ldi r26, lo8(__data_end)
        \\ ldi r27, hi8(__data_end)
        \\
        \\.ram_cpy_0:
        \\ cp r28, r26
        \\ cpc r29, r27
        \\ brne .ram_cpy_1
        \\ rjmp .ram_cpy_2
        \\.ram_cpy_1:
        \\ lpm r20, Z+
        \\ st Y+, r20
        \\ rjmp .ram_cpy_0
        \\
        \\.ram_cpy_2:
        ::: "r30", "r31", "r28", "r29", "r26", "r27", "r25", "r20");
}

/// Clear the .bss segment. Maybe kinda secondary
fn clearBSS() void {
    asm volatile (
        \\ push r25
        \\
        \\ ldi r25, 0x0
        \\
        \\ ldi r28, lo8(__bss_start)
        \\ ldi r29, hi8(__bss_start)
        \\
        \\ ldi r26, lo8(__bss_end)
        \\ ldi r27, hi8(__bss_end)
        \\
        \\.bss_clear_0:
        \\ cp r28, r26
        \\ cpc r29, r27
        \\ brne .bss_clear_1
        \\ rjmp .bss_clear_2
        \\.bss_clear_1:
        \\ st Y+, r25
        \\ rjmp .bss_clear_0
        \\
        \\.bss_clear_2:
        \\ pop r25
        ::: "r28", "r29", "r26", "r27");
}
