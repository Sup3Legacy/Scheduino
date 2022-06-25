const MMIO = @import("mmio.zig").MMIO;
const constants = @import("constants.zig");
const Libz = @import("libz.zig");
const std = @import("std");

const UDR0 = MMIO(0xc6, u8, packed union {
    RXB: u8,
    TXB: u8,
});

const UCSR0A = MMIO(0xc0, u8, packed struct {
    MPCM0: u1 = 0,
    U2X0: u1 = 0,
    UPE0: u1 = 0,
    DOR0: u1 = 0,
    FE0: u1 = 0,
    UDRE0: u1 = 0,
    TXC0: u1 = 0,
    RXC0: u1 = 0,
});

const UCSR0B = MMIO(0xc1, u8, packed struct {
    TXB80: u1 = 0,
    RXB80: u1 = 0,
    UCSZ02: u1 = 0,
    TXEN0: u1 = 0,
    RXEN0: u1 = 0,
    UDRIE0: u1 = 0,
    TXCIE0: u1 = 0,
    RXCIE0: u1 = 0,
});

const UCSR0C = MMIO(0xc2, u8, packed struct {
    UCPOL0: u1 = 0,
    UCSZ00: u1 = 1,
    UCSZ01: u1 = 1,
    USBS0: u1 = 0,
    UPM00: u1 = 0,
    UPM01: u1 = 0,
    UMSEL00: u1 = 0,
    UMSEL01: u1 = 0,
});

const UBRR0L = MMIO(0xc4, u8, packed struct {
    USART: u8 = 0,
});

const UBRR0H = MMIO(0xc5, u8, packed struct {
    USART: u4 = 0,
    reserved: u4 = 0,
});

pub fn init(comptime baud: comptime_int) void {
    const UBRRn: u12 = comptime blk: {
        break :blk (constants.UNO_clock_s / (8 * baud)) - 1;
    };

    // Set baudrate
    UBRR0L.write(.{ .USART = UBRRn });
    UBRR0H.write(.{ .USART = UBRRn >> 8 });

    // Default uart settings are 8n1, so no need to change them!
    UCSR0A.write(.{ .U2X0 = 1 });

    // Enable transmitter!
    UCSR0B.write(.{ .TXEN0 = 1 });
}

pub fn writeChar(ch: u8) void {
    // Wait till the transmit buffer is empty
    const SREG = Libz.MmIO.MMIO(0x5F, u8, u8);
    var oldSREG: u8 = SREG.read();
    @import("libz.zig").Interrupts.cli();
    while (UCSR0A.read().UDRE0 != 1) {}

    UDR0.write(.{ .TXB = ch });
    SREG.write(oldSREG);
}

pub fn write(data: []const u8) void {
    for (data) |ch| {
        writeChar(ch);
    }

    // Wait till we are actually done sending
    while (UCSR0A.read().TXC0 != 1) {}
}

pub fn writeSlice(context: u1, bytes: []const u8) !usize {
    _ = context;
    write(bytes);
    return bytes.len;
}

const SerialWriter = std.io.Writer(u1, error{}, writeSlice);

var SerialWriterInstance = SerialWriter{
    .context = 1,
};

pub fn print(comptime fmt: []const u8, args: anytype) void {
    SerialWriter.print(SerialWriterInstance, fmt, args) catch {};
}

pub fn flush() void {
    while (UCSR0B.read().UDRIE0 & ~UCSR0A.read().TXC0 != 0) {
        @import("utilities.zig").no_op();
    }
}

pub fn end() void {
    flush();
    UCSR0B.write(.{ .RXEN0 = 0 });
    UCSR0B.write(.{ .TXEN0 = 0 });
    UCSR0B.write(.{ .RXCIE0 = 0 });
    UCSR0B.write(.{ .UDRIE0 = 0 });
}
