const scheduler = @import("scheduler.zig");
const utils = @import("../libz/libz.zig").Utilities;

// Lock on all the GPIO pins
var Lock: [24]LockState = [_]LockState{.Unlocked} ** 24;

// Possible states of a lock
const LockState = union(enum) {
    Unlocked,
    Locked: u8,
};

/// Acquire the lock on a GPIO pin. Only one process can acquire
/// it at a time
pub fn acquireLock(id: u8) bool {
    utils.fence();
    var locked = Lock[id];
    var result = switch (locked) {
        .Unlocked => {
            Lock[id] = LockState{ .Locked = scheduler.currentId };
            break true;
        },
        .Locked => |lock_id| {
            // WARN: Maybe disallow acquiring the same pin multiple times
            // WARN: from a unique process
            break (lock_id == scheduler.currentId);
        },
    };
    utils.deFence();
    return result;
}

pub fn acquireLockBlocking(id: u8) void {
    while (!acquireLock(id)) {
        asm volatile ("nop" ::: "memory");
    }
}

/// Release the lock on a GPIO pin.
pub fn releaseLock(id: u8) void {
    utils.fence();
    var locked = Lock[id];
    switch (locked) {
        .Unlocked => {
            // return true;
        },
        .Locked => |lock_id| {
            if (lock_id == scheduler.currentId) {
                Lock[id] = .Unlocked;
            }
        },
    }
    utils.deFence();
}
