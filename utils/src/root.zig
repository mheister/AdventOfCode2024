const std = @import("std");
const testing = std.testing;

pub const Grid = @import("grid.zig").Grid;
pub const loadGridFromFile = @import("grid.zig").loadGridFromFile;

pub const enumerate = @import("iter.zig").enumerate;

// pick up tests
comptime {
    _ = @import("grid.zig");
    _ = @import("iter.zig");
}
