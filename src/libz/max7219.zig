const Libz = @import("libz.zig");
const GPIO = Libz.GpIO;

var DIN_pin: u8 = 10;
var LOAD_pin: u8 = 11;
var CLOCK_pin: u8 = 12;

const Instr = enum(u8) {
    Nop = 0x00,
    Digit0 = 0x01,
    Digit1 = 0x02,
    Digit2 = 0x03,
    Digit3 = 0x04,
    Digit4 = 0x05,
    Digit5 = 0x06,
    Digit6 = 0x07,
    Digit7 = 0x08,
    DecodeMode = 0x09,
    Intensity = 0x0a,
    ScanLimit = 0x0b,
    Shutdown = 0x0c,
    DisplayTest = 0x0f,
};

pub fn SPISendByte(data: u8) void {
    comptime var i = 8;
    inline while (i > 0) : (i -= 1) {
        GPIO.DIGITAL_WRITE(CLOCK_pin, .LOW) catch {};
        asm volatile ("nop" ::: "memory");
        var data_to_write: GPIO.VALUE = .LOW;
        if (data & (@as(u8, 1) << @intCast(u3, i - 1)) != 0) {
            data_to_write = .HIGH;
        }
        GPIO.DIGITAL_WRITE(DIN_pin, data_to_write) catch {};
        asm volatile ("nop" ::: "memory");
        GPIO.DIGITAL_WRITE(CLOCK_pin, .HIGH) catch {};
    }
}

fn fillRegister(reg: u8, data: u8) void {
    GPIO.DIGITAL_WRITE(LOAD_pin, .LOW) catch {};
    asm volatile ("nop" ::: "memory");
    SPISendByte(reg);
    asm volatile ("nop" ::: "memory");
    SPISendByte(data);
    asm volatile ("nop" ::: "memory");
    GPIO.DIGITAL_WRITE(LOAD_pin, .HIGH) catch {};
    //GPIO.DIGITAL_WRITE(CLOCK_pin, .LOW) catch {};
}

pub var LED_buffer: [8]u8 = [_]u8{0} ** 8;

pub fn draw() void {
    comptime var i = 0;
    inline while (i < 8) : (i += 1) {
        fillRegister(i + 1, LED_buffer[i]);
    }
}

pub fn init() void {
    GPIO.DIGITAL_MODE(DIN_pin, .OUTPUT) catch {};
    GPIO.DIGITAL_MODE(CLOCK_pin, .OUTPUT) catch {};
    GPIO.DIGITAL_MODE(LOAD_pin, .OUTPUT) catch {};
    
    fillRegister(@enumToInt(Instr.Shutdown), 0x01);
    fillRegister(@enumToInt(Instr.ScanLimit), 0x07);
    fillRegister(@enumToInt(Instr.DecodeMode), 0x00);

    fillRegister(@enumToInt(Instr.DisplayTest), 0x00);

    var i: u8 = 1;
    while (i < 9) : (i += 1) {
        fillRegister(i, 0x0);
    }

    fillRegister(@enumToInt(Instr.Intensity), 0x08);
}

pub fn toggle_pixel(x: u8, y: u8, state: bool) void {
    if (x >= 8 or y >= 8) {
        return;
    }

    if (state) {
        LED_buffer[x] |= (@as(u8, 1) << @intCast(u3, y));
    } else {
        LED_buffer[x] &= ~(@as(u8, 1) << @intCast(u3, y));
    }
}
