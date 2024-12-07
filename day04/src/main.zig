const std = @import("std");
const Grid = @import("grid.zig").Grid;

const dbg = std.log.debug;

pub fn main() !void {
    const a = std.heap.page_allocator;

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var infile: []const u8 = undefined;
    if (args.len > 1 and args[1].len >= 0) {
        infile = args[1];
    } else {
        infile = "example_input.txt";
    }

    const wordsearch = try load_wordsearch(a, infile);
    const cnt1 = search_rows(&wordsearch) + search_cols(&wordsearch) + search_diagonals(&wordsearch);
    _ = try stdout.print("The number of XMAS is {}\n", .{cnt1});
    const cnt2 = searh_x_mas(&wordsearch);
    _ = try stdout.print("The number of XMAS is really (part two) {}\n", .{cnt2});

    try bw.flush();
}

fn searh_x_mas(grid: *const Grid(u8)) usize {
    var count: usize = 0;
    for (1..grid.height() - 1) |row| {
        for (1..grid.width - 1) |col| {
            if (grid.cr(row)[col] != 'A') continue;
            const pd: [2]u8 = .{ grid.cr(row - 1)[col - 1], grid.cr(row + 1)[col + 1] };
            if (!std.mem.eql(u8, &pd, "MS") and !std.mem.eql(u8, &pd, "SM")) continue;
            const nd = .{ grid.cr(row + 1)[col - 1], grid.cr(row - 1)[col + 1] };
            if (!std.mem.eql(u8, &nd, "MS") and !std.mem.eql(u8, &nd, "SM")) continue;
            count += 1;
        }
    }
    return count;
}

fn search_rows(grid: *const Grid(u8)) usize {
    var count: usize = 0;
    var rowiter = grid.crows();
    while (rowiter.next()) |row| {
        var xmas: XmasAcceptor = .{};
        var samx: XmasAcceptor = .{ .xmas = "SAMX" };
        for (row) |ch| {
            count += xmas.take(ch);
            count += samx.take(ch);
        }
    }
    dbg("{} on rows", .{count});
    return count;
}

fn search_cols(grid: *const Grid(u8)) usize {
    var count: usize = 0;
    for (0..grid.width) |col| {
        var xmas: XmasAcceptor = .{};
        var samx: XmasAcceptor = .{ .xmas = "SAMX" };
        for (0..grid.height()) |row| {
            const ch = grid.cr(row)[col];
            count += xmas.take(ch);
            count += samx.take(ch);
        }
    }
    dbg("{} on columns", .{count});
    return count;
}

fn search_diagonals(grid: *const Grid(u8)) usize {
    var count: usize = 0;
    // positive diagonals
    for (0..grid.width + grid.height() - 1) |diag| {
        var xmas: XmasAcceptor = .{};
        var samx: XmasAcceptor = .{ .xmas = "SAMX" };
        var row = grid.height() - 1 -| diag; // clamped arithm.
        var col = diag -| (grid.height() - 1); // clamped arithm.
        while (col < grid.width and row < grid.height()) {
            const ch = grid.cr(row)[col];
            count += xmas.take(ch);
            count += samx.take(ch);
            row += 1;
            col += 1;
        }
    }
    // negative diagonals
    for (0..grid.width + grid.height() - 1) |diag| {
        var xmas: XmasAcceptor = .{};
        var samx: XmasAcceptor = .{ .xmas = "SAMX" };
        var row = grid.height() - 1 -| (diag -| (grid.width - 1)); // clamped arithm.
        var col = grid.width - 1 -| diag; // clamped arithm.
        while (col < grid.width and row > 0) {
            const ch = grid.cr(row)[col];
            count += xmas.take(ch);
            count += samx.take(ch);
            row -= 1;
            col += 1;
        }
        if (col < grid.width and row == 0) {
            const ch = grid.cr(row)[col];
            count += xmas.take(ch);
            count += samx.take(ch);
        }
    }
    dbg("{} on diagonals", .{count});
    return count;
}

const XmasAcceptor = struct {
    xmas: *const [4:0]u8 = "XMAS",
    have: u8 = 0,

    pub fn take(self: *@This(), ch: u8) u1 {
        std.debug.assert(self.have < self.xmas.len);
        if (self.xmas[self.have] != ch) {
            self.have = 0;
        }
        if (self.xmas[self.have] == ch) {
            self.have += 1;
        }
        if (self.have == self.xmas.len) {
            self.have = 0;
            return 1;
        }
        return 0;
    }

    pub fn reset(self: *@This()) void {
        self.have = 0;
    }
};

test "XmasAcceptor.simple" {
    var acp: XmasAcceptor = .{};
    try std.testing.expectEqual(0, acp.take('X'));
    try std.testing.expectEqual(0, acp.take('M'));
    try std.testing.expectEqual(0, acp.take('A'));
    try std.testing.expectEqual(1, acp.take('S'));
}

test "XmasAcceptor.more" {
    var acp: XmasAcceptor = .{};
    try std.testing.expectEqual(0, acp.take('X'));
    try std.testing.expectEqual(0, acp.take('M'));
    try std.testing.expectEqual(0, acp.take('A'));
    try std.testing.expectEqual(0, acp.take('$'));
    try std.testing.expectEqual(0, acp.take('S'));
    acp = .{};
    try std.testing.expectEqual(0, acp.take('X'));
    try std.testing.expectEqual(0, acp.take('M'));
    try std.testing.expectEqual(0, acp.take('X'));
    try std.testing.expectEqual(0, acp.take('M'));
    try std.testing.expectEqual(0, acp.take('A'));
    try std.testing.expectEqual(1, acp.take('S'));
}

fn load_wordsearch(a: std.mem.Allocator, filepath: []const u8) !Grid(u8) {
    dbg("Reading {s}", .{filepath});
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
    const height = try file.getEndPos() / (width + 1);
    var grid = try Grid(u8).init(a, width, height);

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
                line_no += 1;
                dbg("LASTLINE {d}--{s}\n", .{ line_no, line.items });
            }
        },
        else => return err,
    }
    return grid;
}
