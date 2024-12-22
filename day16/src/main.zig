const std = @import("std");
const mcha = @import("mecha");
const utils = @import("utils");

const Pos = utils.grid.Pos;
const Dir = enum { w, n, e, s }; // west, north, south, east

fn offPos(pos: Pos, dir: Dir) utils.grid.Pos {
    switch (dir) {
        .w => return .{ .row = pos.row, .col = pos.col - 1 },
        .n => return .{ .row = pos.row - 1, .col = pos.col },
        .e => return .{ .row = pos.row, .col = pos.col + 1 },
        .s => return .{ .row = pos.row + 1, .col = pos.col },
    }
}

const Move = enum { walk, rot_left, rot_right };

// rotate counterclockwise
fn rotLeft(dir: Dir) Dir {
    return switch (dir) {
        .w => .s,
        .n => .w,
        .e => .n,
        .s => .e,
    };
}

// rotate clockwise
fn rotRight(dir: Dir) Dir {
    return switch (dir) {
        .w => .n,
        .n => .e,
        .e => .s,
        .s => .w,
    };
}

fn findLowestScoreAndBestPathTileCount(
    a: std.mem.Allocator,
    maze: utils.Grid(u8),
) !struct { usize, usize } {
    var low_score: usize = std.math.maxInt(usize);
    const State = struct {
        pos: Pos,
        dir: Dir,
        moves: [3]?Move = [_]?Move{ .walk, .rot_left, .rot_right },
        score: usize,
    };
    const start = maze.indexOf('S') orelse return error.NoStart;
    var bt = std.ArrayList(State).init(a);
    defer bt.deinit();
    try bt.append(.{
        .pos = start,
        .dir = .e,
        .score = 0,
    });
    const StateSorter = struct {
        fn cmp(_: void, lhs: State, rhs: State) bool {
            return lhs.score > rhs.score;
        }
    };
    var low_score_per_state = std.AutoArrayHashMap(struct { Pos, Dir }, usize).init(a);
    defer low_score_per_state.deinit();
    var iteration: usize = 0;
    while (bt.items.len > 0) : (iteration += 1) {
        if (iteration % 1024 == 0) {
            // sort low scores to end every once in a while to prevent running in circles
            std.mem.sort(State, bt.items, {}, StateSorter.cmp);
        }
        var state = bt.pop();
        if (state.score > low_score) continue;
        const low_score_entry = try low_score_per_state.getOrPut(.{ state.pos, state.dir });
        if (low_score_entry.found_existing and low_score_entry.value_ptr.* < state.score)
            continue;
        low_score_entry.value_ptr.* = state.score;

        const move = for (0.., state.moves) |idx, maybe_move| {
            if (maybe_move) |move| {
                state.moves[idx] = null;
                break move;
            }
        } else continue;
        const moves_left = for (state.moves) |maybe_move| {
            if (maybe_move) |_| break true;
        } else false;
        if (moves_left) try bt.append(state);
        switch (move) {
            .walk => {
                const score = state.score + 1;
                const tgt = offPos(state.pos, state.dir);
                switch (maze.atPos(tgt).?) {
                    'E' => {
                        low_score = @min(low_score, score);
                        // push backtrack state so that low_score_per_state entry will be
                        // created for E
                        try bt.append(.{
                            .pos = tgt,
                            .dir = state.dir,
                            .moves = .{ null, null, null },
                            .score = score,
                        });
                    },
                    '.' => {
                        try bt.append(.{
                            .pos = tgt,
                            .dir = state.dir,
                            .score = score,
                        });
                    },
                    else => {},
                }
            },
            .rot_left => {
                const score = state.score + 1000;
                const dir = rotLeft(state.dir);
                const facing_pos = offPos(state.pos, dir);
                // never useful to rotate in a direction we can't walk
                if (maze.atPos(facing_pos) == '#') continue;
                try bt.append(.{
                    .pos = state.pos,
                    .dir = dir,
                    // neither rotating back nor twice to where we came from makes sense
                    .moves = .{ .walk, null, null },
                    .score = score,
                });
            },
            .rot_right => {
                const score = state.score + 1000;
                const dir = rotRight(state.dir);
                const facing_pos = offPos(state.pos, dir);
                // never useful to rotate in a direction we can't walk
                if (maze.atPos(facing_pos) == '#') continue;
                try bt.append(.{
                    .pos = state.pos,
                    .dir = dir,
                    // neither rotating back nor twice to where we came from makes sense
                    .moves = .{ .walk, null, null },
                    .score = score,
                });
            },
        }
    }

    // walk backwards from end on optimal tiles
    const end = maze.indexOf('E') orelse return error.NoEnd;
    var opti_tiles = std.AutoArrayHashMap(Pos, void).init(a);
    defer opti_tiles.deinit();
    bt.clearRetainingCapacity();
    for ([_]Dir{ .w, .n, .e, .s }) |dir| {
        if (low_score_per_state.get(.{ end, dir }) == low_score) {
            try bt.append(.{ .pos = end, .dir = dir, .score = low_score });
        }
    }
    while (bt.items.len > 0) {
        const state = bt.pop();
        try opti_tiles.put(state.pos, {});
        for (state.moves) |maybe_move| {
            const move = maybe_move.?;
            switch (move) {
                .walk => if (state.score < 1) continue,
                .rot_left, .rot_right => if (state.score < 1000) continue,
            }
            const src_score = switch (move) {
                .walk => state.score - 1,
                .rot_left, .rot_right => state.score - 1000,
            };
            const src_pos = switch (move) {
                .walk => offPos(state.pos, rotLeft(rotLeft(state.dir))),
                else => state.pos,
            };
            const src_dir = switch (move) {
                .rot_left => rotRight(state.dir),
                .rot_right => rotLeft(state.dir),
                else => state.dir,
            };
            const elm = low_score_per_state.get(.{ src_pos, src_dir });
            if (elm == src_score) {
                try bt.append(.{ .pos = src_pos, .dir = src_dir, .score = src_score });
            }
        }
    }

    return .{ low_score, opti_tiles.keys().len };
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

    var maze = try utils.loadGridFromFile(a, infile);
    defer maze.deinit();

    maze.log();

    const res = try findLowestScoreAndBestPathTileCount(a, maze);

    _ = try stdout.print("The minimal score is {}\n", .{res[0]});
    _ = try stdout.print("There are {} tiles on best paths\n", .{res[1]});

    try bw.flush();
}
