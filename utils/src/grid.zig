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

        // clone the grid using the same allocator
        pub fn clone(self: *const @This()) !@This() {
            const new = @This(){
                .data = try self.allocator.alloc(T, self.size),
                .width = self.width,
                .size = self.size,
                .allocator = self.allocator,
            };
            @memcpy(new.data, self.data);
            return new;
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.data);
        }

        pub fn height(self: *const @This()) usize {
            return self.size / self.width;
        }

        pub fn r(self: *@This(), idx: usize) []T {
            if (self.size == 0) return &.{};
            return self.data[self.width * idx .. self.width * (idx + 1)];
        }

        pub fn cr(self: *const @This(), idx: usize) []const T {
            if (self.size == 0) return &.{};
            return self.data[self.width * idx .. self.width * (idx + 1)];
        }

        pub fn crows(self: *const @This()) ConstRowIterator(T) {
            return .{ .grid = self };
        }

        pub fn atPos(self: *const @This(), pos: Pos) ?T {
            if (pos.row > self.height()) return null;
            if (pos.col > self.width) return null;
            return self.cr(pos.row)[pos.col];
        }

        pub fn atPosRef(self: *@This(), pos: Pos) ?*T {
            if (pos.row > self.height()) return null;
            if (pos.col > self.width) return null;
            return &self.r(pos.row)[pos.col];
        }

        pub fn cardinalNeighbours(self: *const @This(), pos: Pos) CardinalNeighbourIterator(T) {
            return .{ .grid = self, .around = pos };
        }

        // find the first index (row, column) of a given element
        pub fn indexOf(self: *const @This(), element: T) ?Pos {
            const flatidx = std.mem.indexOfScalar(T, self.data, element) orelse return null;
            return .{
                .row = flatidx / self.width,
                .col = flatidx % self.width,
            };
        }
    };
}

pub const Pos = struct { row: usize, col: usize };

pub fn ConstRowIterator(T: type) type {
    return struct {
        grid: *const Grid(T),
        current: usize = 0,
        pub fn next(self: *@This()) ?[]const T {
            if (self.current == self.grid.height()) {
                return null;
            }
            self.current += 1;
            return self.grid.cr(self.current - 1);
        }
    };
}

pub fn CardinalNeighbourIterator(T: type) type {
    return struct {
        grid: *const Grid(T),
        around: Pos,
        current: u8 = 0, // enumerates left, up, right, down
        pub fn next(self: *@This()) ?struct { Pos, T } {
            const res = while (self.current < 4) : (self.current += 1) {
                switch (self.current) {
                    0 => if (self.around.col == 0) continue,
                    1 => if (self.around.row == 0) continue,
                    else => {},
                }
                const pos: Pos = switch (self.current) {
                    0 => .{ .row = self.around.row, .col = self.around.col - 1 },
                    1 => .{ .row = self.around.row - 1, .col = self.around.col },
                    2 => .{ .row = self.around.row, .col = self.around.col + 1 },
                    3 => .{ .row = self.around.row + 1, .col = self.around.col },
                    else => unreachable,
                };
                break .{ pos, self.grid.atPos(pos) orelse continue };
            } else null;
            self.current += 1;
            return res;
        }
    };
}

test "grid.cardinalNeighbours" {
    const expectEqDeep = std.testing.expectEqualDeep;
    var grid = try Grid(u8).init(std.testing.allocator, 3, 3);
    defer grid.deinit();
    @memcpy(grid.data, ( //
        "abc" ++
        "def" ++
        "ghi"));
    {
        var n = grid.cardinalNeighbours(.{ .row = 0, .col = 0 });
        try expectEqDeep(.{ Pos{ .row = 0, .col = 1 }, 'b' }, n.next());
        try expectEqDeep(.{ Pos{ .row = 1, .col = 0 }, 'd' }, n.next());
        try expectEqDeep(null, n.next());
    }
    {
        var n = grid.cardinalNeighbours(.{ .row = 1, .col = 1 });
        try expectEqDeep(.{ Pos{ .row = 1, .col = 0 }, 'd' }, n.next());
        try expectEqDeep(.{ Pos{ .row = 0, .col = 1 }, 'b' }, n.next());
        try expectEqDeep(.{ Pos{ .row = 1, .col = 2 }, 'f' }, n.next());
        try expectEqDeep(.{ Pos{ .row = 2, .col = 1 }, 'h' }, n.next());
        try expectEqDeep(null, n.next());
    }
}

// load a Grid(u8) from a text file
pub fn loadGridFromFile(a: std.mem.Allocator, filepath: []const u8) !Grid(u8) {
    const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return err;
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());

    var line = std.ArrayList(u8).init(a);
    defer line.deinit();
    const writer = line.writer();
    try buf_reader.reader().streamUntilDelimiter(writer, '\n', null);
    try file.seekTo(0);
    buf_reader = std.io.bufferedReader(file.reader());

    const width = line.items.len;
    // this might not work on windows
    const height_ = try file.getEndPos() / (width + 1);
    var grid = try Grid(u8).init(a, width, height_);

    line.clearRetainingCapacity();
    const reader = buf_reader.reader();
    var line_no: usize = 0;
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        const gridrow = grid.r(line_no);
        @memcpy(gridrow, line.items);
        line_no += 1;
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                return error.PleaseAddTrailingNewLine;
            }
        },
        else => return err,
    }
    return grid;
}
