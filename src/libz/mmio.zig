pub fn MMIO(comptime addr: usize, comptime IntType: type, comptime ReprType: type) type {
    return struct {
        pub fn ptr() *volatile IntType {
            return @intToPtr(*volatile IntType, addr);
        }
        pub fn read() ReprType {
            const intVal = ptr().*;
            return @bitCast(ReprType, intVal);
        }
        pub fn write(val: ReprType) void {
            const intVal = @bitCast(IntType, val);
            ptr().* = intVal;
        }
    };
}
