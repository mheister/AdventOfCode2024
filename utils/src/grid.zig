const std = @import("std");

pub fn Grid(T: type) type {
    return struct {
        data: []T,
        width: usize,
        size: usize,
        allocator: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator, width: usize, height_: usize) !@This() {
            return @This(){
                .data = try a.alloc(T, width * height_),
                .width = width,
                .size = width * height_,
                .allocator = a,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.data);
        }

        pub fn height(self: *const @This()) usize {
            return self.size / self.width;
        }

        pub fn r(self: *@This(), idx: usize) []u8 {
            if (self.size == 0) return &.{};
            return self.data[self.width * idx .. self.width * (idx + 1)];
        }

        pub fn cr(self: *const @This(), idx: usize) []const u8 {
            if (self.size == 0) return &.{};
            return self.data[self.width * idx .. self.width * (idx + 1)];
        }

        pub fn crows(self: *const @This()) ConstRowIterator(@This()) {
            return .{ .grid = self };
        }
    };
}

pub fn ConstRowIterator(GridType: type) type {
    return struct {
        grid: *const GridType,
        current: usize = 0,
        pub fn next(self: *@This()) ?[]const u8 {
            if (self.current == self.grid.height()) {
                return null;
            }
            self.current += 1;
            return self.grid.cr(self.current - 1);
        }
    };
}
