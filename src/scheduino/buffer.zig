// A compile-time defined and allocated buffer,
// to be used either as single-threaded "bulk" memory
// by a process or as a pipe
//
// A buffer is always guarded by a lock and access to
// its content must respect this to avoid any data-race
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

// Basic implementation of locks, used to protect shared buffers
// from data-races. WIP
pub const Lock = struct {
    locked: bool,
    pid: ?u8,

    // TODO: Implement this
    pub fn acquire(this: *@This()) void {
        _ = this;
    }

    // TODO: Implement this
    pub fn release(this: *@This()) void {
        _ = this;
    }

    pub fn new() @This() {
        return @This(){
            .locked = false,
            .id = null,
        };
    }
};
