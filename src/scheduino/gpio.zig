const scheduler = @import("scheduler.zig");
const utils = @import("../libz/libz.zig").Utilities;

// Lock on all the GPIO pins
var Lock: [24]LockState = [_]LockState{.Unlocked} ** 24;

const LockState = union(enum) {
    Unlocked,
    Locked: u8,
};

pub fn acquireLock(id: u8) bool {
    utils.fence();
    var locked = Lock[id];
    switch (locked) {
        .Unlocked => {
            Lock[id] = LockState{ .Locked = scheduler.currentId };
            return true;
        },
        .Locked => |lock_id| {
            // WARN: Maybe disallow acquiring the same pin multiple times
            // WARN: from a unique process
            return (lock_id == scheduler.currentId);
        },
    }
    utils.deFence();
}

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
