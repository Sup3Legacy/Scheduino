pub const StackSize = enum(u8) {
    XSmall,
    Small,
    Normal,
    Large,
    XLarge,
};

pub const StackLayout = struct {
    start: usize,
    size: StackSize,
};