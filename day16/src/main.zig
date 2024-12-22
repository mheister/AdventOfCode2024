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

fn findLowestScore(a: std.mem.Allocator, maze: utils.Grid(u8)) !usize {
    var low_score: usize = std.math.maxInt(usize);
    const State = struct {
        pos: Pos,
        dir: Dir,
        moves: [3]?Move = [_]?Move{ .walk, .rot_left, .rot_right },
        score: usize,
    };
    const start = maze.indexOf('S') orelse return error.NoStart;
    var bt = std.ArrayList(State).init(a);
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
    var iteration: usize = 0;
    while (bt.items.len > 0) : (iteration += 1) {
        if (iteration % 1024 == 0) {
            // sort low scores to end every once in a while to prevent running in circles
            std.mem.sort(State, bt.items, {}, StateSorter.cmp);
        }
        var state = bt.pop();
        if (state.score >= low_score) continue;
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
                    'E' => low_score = @min(low_score, score),
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
    return low_score;
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

    const low_score = try findLowestScore(a, maze);

    _ = try stdout.print("The minimal score is {}\n", .{low_score});

    try bw.flush();
}
