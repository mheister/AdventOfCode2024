const std = @import("std");
const testing = std.testing;

pub const grid = @import("grid.zig");
pub const Grid = grid.Grid;
pub const loadGridFromFile = grid.loadGridFromFile;

pub const enumerate = @import("iter.zig").enumerate;

// pick up tests
comptime {
    _ = @import("grid.zig");
    _ = @import("iter.zig");
}
