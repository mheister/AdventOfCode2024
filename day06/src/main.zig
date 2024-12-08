const std = @import("std");
const Grid = @import("utils").Grid;

const dbg = std.log.debug;

fn load_map(a: std.mem.Allocator, filepath: []const u8) !Grid(u8) {
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

const Pos = struct {
    row: isize,
    col: isize,

    pub fn add(self: Pos, other: Pos) Pos {
        return .{
            .row = self.row + other.row,
            .col = self.col + other.col,
        };
    }

    pub fn toCoord(self: Pos) ?struct { row: usize, col: usize } {
        if (self.row < 0 or self.col < 0) return null;
        return .{ .row = @intCast(self.row), .col = @intCast(self.col) };
    }

    const up = Pos{ .row = -1, .col = 0 };
    const right = Pos{ .row = 0, .col = 1 };
    const down = Pos{ .row = 1, .col = 0 };
    const left = Pos{ .row = 0, .col = -1 };

    pub fn rot90(self: Pos) Pos {
        return .{ .row = self.col, .col = -1 * self.row };
    }
};

fn grid_elem(grid: *Grid(u8), pos: Pos) ?*u8 {
    const coord = pos.toCoord() orelse return null;
    if (coord.col >= grid.width) return null;
    if (coord.row >= grid.height()) return null;
    return &grid.r(coord.row)[coord.col];
}

fn guard_walk(grid: *Grid(u8)) usize {
    const start = grid.indexOf('^') orelse unreachable;
    var pos: Pos = .{ .row = @intCast(start.row), .col = @intCast(start.col) };
    var count: usize = 1;
    var dir = Pos.up;
    while (true) {
        const next: struct { Pos, u8 } = (for (1..4) |_| {
            const next_pos = pos.add(dir);
            const next_ch = grid_elem(grid, next_pos) orelse break null;
            if (next_ch.* != '#') break .{ next_pos, next_ch.* };
            dir = dir.rot90();
        } else null) orelse break;
        if (next[1] != 'X') {
            count += 1;
        }
        grid_elem(grid, pos).?.* = 'X';
        pos = next[0];
        dbg("{any}", .{pos});
    }
    return count;
}

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

    var map = try load_map(a, infile);
    const cnt1 = guard_walk(&map);
    _ = try stdout.print("The number of guard steps is {}\n", .{cnt1});

    try bw.flush();
}
