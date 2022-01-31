pub const Buffer = struct {
    start: usize,
    size: usize,
    used: usize,
    lock: Lock,

    pub fn read_raw(this: *@This(), idx: usize) ?u8 {
        if (idx < this.used) {
            return @intToPtr(*u8, this.start + idx).*;
        } else {
            return null;
        }
    }

    pub fn read(this: *@This(), comptime ty: type, idx: usize) ?ty {
        if (idx < (this.used / @sizeOf(ty))) {
            return @intToPtr(*ty, this.start + idx * @sizeOf(ty)).*;
        } else {
            return null;
        }
    }
};

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