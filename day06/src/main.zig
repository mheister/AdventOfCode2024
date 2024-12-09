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

fn guard_walk(grid: *Grid(u8)) ?usize {
    const start = grid.indexOf('^') orelse unreachable;
    var pos: Pos = .{ .row = @intCast(start.row), .col = @intCast(start.col) };
    var count: usize = 1;
    var dir = Pos.up;
    // guard can walk at most each inner field once in each direction and then out; could
    // think of more efficient ways to detect infinite walks if needed
    const max_steps = 4 * (grid.height() - 2) * (grid.width - 2) + 1;
    return for (0..max_steps) |_| {
        const next: struct { Pos, u8 } = (for (1..4) |_| {
            const next_pos = pos.add(dir);
            const next_ch = grid_elem(grid, next_pos) orelse break null;
            if (next_ch.* != '#') break .{ next_pos, next_ch.* };
            dir = dir.rot90();
        } else null) orelse break count;
        if (next[1] != 'X') {
            count += 1;
        }
        grid_elem(grid, pos).?.* = 'X';
        pos = next[0];
    } else null;
}

fn nof_possible_obstacles_to_put_guardian_in_loop(grid: *Grid(u8)) !usize {
    const start = grid.indexOf('^') orelse unreachable;
    const startpos: Pos = .{ .row = @intCast(start.row), .col = @intCast(start.col) };
    dbg("Start @ {any}", .{startpos});
    var count: usize = 0;
    var pos = startpos;
    var dir = Pos.up;
    var attempt_count: usize = 0;
    for (0..2 * grid.size) |_| {
        const next: struct { Pos, u8 } = (for (1..4) |_| {
            const next_pos = pos.add(dir);
            const next_ch = grid_elem(grid, next_pos) orelse break null;
            if (next_ch.* != '#') break .{ next_pos, next_ch.* };
            dir = dir.rot90();
        } else null) orelse break;
        if (next[1] != 'X' and next[1] != '^' and next[1] != '#') {
            attempt_count += 1;
            // possible position for additional obstacle
            var subgrid = try grid.clone();
            defer subgrid.deinit();
            grid_elem(&subgrid, next[0]).?.* = '#';
            if (guard_walk(&subgrid) == null) {
                dbg("Loop with obstacle @ {any}", .{next[0]});
                count += 1;
            }
        }
        if (grid_elem(grid, pos).?.* != '^') {
            grid_elem(grid, pos).?.* = 'X';
        }
        pos = next[0];
    }
    std.log.info("attempted {} obstacle positions", .{attempt_count});
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
    const cnt1 = guard_walk(&map).?;
    _ = try stdout.print("The number of guard steps is {}\n", .{cnt1});
    map = try load_map(a, infile);
    const cnt2 = try nof_possible_obstacles_to_put_guardian_in_loop(&map);
    _ = try stdout.print("The number of additional obstacle positions is {}\n", .{cnt2});

    try bw.flush();
}
