const std = @import("std");
const Grid = @import("utils").Grid;

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

    const map = try load_map(a, infile);
    const trailheads = try find_trailheads(a, map);
    dbg("trailheads: {any}", .{trailheads});
    var score_reachable_nines: usize = 0;
    for (trailheads) |head| {
        const score = try score_trail(a, head, map, .reachable_nines);
        dbg("({}, {}) -> {}", .{ head.row, head.col, score });
        score_reachable_nines += score;
    }
    _ = try stdout.print("The sum of trail scores is {}\n", .{score_reachable_nines});
    var score_distinct_trails: usize = 0;
    for (trailheads) |head| {
        const score = try score_trail(a, head, map, .distinct_trails);
        dbg("({}, {}) -> {}", .{ head.row, head.col, score });
        score_distinct_trails += score;
    }
    _ = try stdout.print("The sum of trail scores is {}\n", .{score_distinct_trails});

    try bw.flush();
}

// TODO: copy of load_wordsearch (day 4) and load_map (day 6), should move into utils
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

const Position = struct { row: usize, col: usize };

fn find_trailheads(a: std.mem.Allocator, map: Grid(u8)) ![]Position {
    var res = std.ArrayList(Position).init(a);
    for (0..map.height()) |row| {
        for (0..map.width) |col| {
            if (map.cr(row)[col] == '0') {
                try res.append(.{ .row = row, .col = col });
            }
        }
    }
    return res.toOwnedSlice();
}

const ScoreKind = enum { reachable_nines, distinct_trails };

fn score_trail(
    a: std.mem.Allocator,
    head: Position,
    map: Grid(u8),
    comptime score_kind: ScoreKind,
) !usize {
    var wmap = switch (score_kind) {
        .reachable_nines => try map.clone(),
        .distinct_trails => map,
    };
    var wrk = std.ArrayList(Position).init(a);
    defer wrk.deinit();
    try wrk.append(head);
    var score: usize = 0;
    while (wrk.items.len > 0) {
        const p = wrk.pop();
        const height = wmap.cr(p.row)[p.col];
        if (height == '9') {
            if (score_kind == .reachable_nines) {
                wmap.r(p.row)[p.col] = 'X';
            }
            score += 1;
            continue;
        }
        if (p.col > 0 and wmap.cr(p.row)[p.col - 1] == height + 1) {
            try wrk.append(.{ .row = p.row, .col = p.col - 1 });
        }
        if (p.row > 0 and wmap.cr(p.row - 1)[p.col] == height + 1) {
            try wrk.append(.{ .row = p.row - 1, .col = p.col });
        }
        if (p.col < wmap.width - 1 and wmap.cr(p.row)[p.col + 1] == height + 1) {
            try wrk.append(.{ .row = p.row, .col = p.col + 1 });
        }
        if (p.row < wmap.height() - 1 and wmap.cr(p.row + 1)[p.col] == height + 1) {
            try wrk.append(.{ .row = p.row + 1, .col = p.col });
        }
    }
    if (score_kind == .reachable_nines) {
        wmap.deinit();
    }
    return score;
}

test "score_trail" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    {
        var map = try Grid(u8).init(a, 10, 1);
        defer map.deinit();
        @memcpy(map.data, "0123456789");
        try expectEq(1, score_trail(a, .{ .row = 0, .col = 0 }, map));
    }
    {
        var map = try Grid(u8).init(a, 10, 2);
        defer map.deinit();
        @memcpy(map.data, ( //
            "0123456789" ++
            "0123456789"));
        try expectEq(1, score_trail(a, .{ .row = 0, .col = 0 }, map));
    }
    {
        var map = try Grid(u8).init(a, 10, 2);
        defer map.deinit();
        @memcpy(map.data, ( //
            "0000000000" ++
            "1234567890"));
        try expectEq(1, score_trail(a, .{ .row = 0, .col = 0 }, map));
    }
    {
        var map = try Grid(u8).init(a, 10, 3);
        defer map.deinit();
        @memcpy(map.data, ( //
            "0123456789" ++
            "1000000000" ++
            "2345678900"));
        try expectEq(2, score_trail(a, .{ .row = 0, .col = 0 }, map));
    }
    {
        var map = try Grid(u8).init(a, 7, 7);
        defer map.deinit();
        @memcpy(map.data, ( //
            "10..9.." ++
            "2...8.." ++
            "3...7.." ++
            "4567654" ++
            "...8..3" ++
            "...9..2" ++
            ".....01"));
        try expectEq(1, score_trail(a, .{ .row = 0, .col = 1 }, map));
        try expectEq(2, score_trail(a, .{ .row = 6, .col = 5 }, map));
    }
}
