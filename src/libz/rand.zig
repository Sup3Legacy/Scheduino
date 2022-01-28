const Libz = @import("libz.zig");
const std = @import("std");

var prng = std.rand.DefaultPrng.init(542);

pub fn get_random(at_least: isize, less_than: isize) isize {
    return prng.random().intRangeLessThan(isize, at_least, less_than);
}
