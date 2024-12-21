const std = @import("std");
const mcha = @import("mecha");
const utils = @import("utils");

const Input = struct {
    warehouse: utils.Grid(u8),
    movements: []u8, // <^>v
    allocator: std.mem.Allocator,
    fn deinit(self: *@This()) void {
        self.warehouse.deinit();
        self.allocator.free(self.movements);
    }
};

pub fn parse_input(a: std.mem.Allocator, input: []const u8) !Input {
    var split = std.mem.splitSequence(u8, input, "\n\n");
    var res = Input{ .warehouse = undefined, .movements = undefined, .allocator = a };
    res.warehouse = try utils.grid.loadGridFromStr(
        a,
        split.next() orelse return error.NoWarehouse,
    );
    const movements_str = split.next() orelse return error.NoMovements;
    var movements = std.ArrayList(u8).init(a);
    for (movements_str) |ch| {
        if (ch != '\n') try movements.append(ch);
    }
    res.movements = try movements.toOwnedSlice();
    if (split.next() != null) return error.ExtraParagraph;
    return res;
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const input =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
        \\
        \\<^^>>>vv<v>>v<<
        \\^^>>>vv<v>>v<<<
    ;
    const a = std.testing.allocator;
    var res = try parse_input(a, input);
    defer res.deinit();
    try expectEq(8, res.warehouse.height());
    try expectEq(8, res.warehouse.width);
    try expectEq(30, res.movements.len);
    try expectEq('<', res.movements[0]);
}

fn offPos(pos: utils.grid.Pos, dir: u8) ?utils.grid.Pos {
    switch (dir) {
        '<' => if (pos.col == 0) return null,
        '^' => if (pos.row == 0) return null,
        else => {},
    }
    switch (dir) {
        '<' => return .{ .row = pos.row, .col = pos.col - 1 },
        '^' => return .{ .row = pos.row - 1, .col = pos.col },
        '>' => return .{ .row = pos.row, .col = pos.col + 1 },
        'v' => return .{ .row = pos.row + 1, .col = pos.col },
        else => unreachable,
    }
}

const MoveWideBoxAction = struct {
    from: utils.grid.Pos,
    to: utils.grid.Pos,
    behind_me: [2]?*@This() = [2]?*@This(){ null, null },
    fn alloc(a: std.mem.Allocator) !*@This() {
        return try a.create(@This());
    }
    fn dealloc(self: *@This(), a: std.mem.Allocator) void {
        if (self.behind_me[0]) |b| b.dealloc(a);
        if (self.behind_me[1]) |b| b.dealloc(a);
        a.destroy(self);
    }
    fn execute(self: @This(), w: *utils.Grid(u8)) void {
        if (self.behind_me[0]) |b| b.execute(w);
        if (self.behind_me[1]) |b| b.execute(w);
        if (w.atPos(self.to).? == '[') return; // has already been moved (pyramid)
        const from_r = offPos(self.from, '>').?;
        w.atPosRef(self.from).?.* = '.';
        w.atPosRef(from_r).?.* = '.';
        const to_r = offPos(self.to, '>').?;
        w.atPosRef(self.to).?.* = '[';
        w.atPosRef(to_r).?.* = ']';
    }
};

// move a wide box (given by left position) in the given direction
fn moveWidebox(
    a: std.mem.Allocator,
    w: *utils.Grid(u8),
    pos: utils.grid.Pos,
    dir: u8,
) !?*MoveWideBoxAction {
    const spot = offPos(pos, dir).?;
    const spot_r = offPos(spot, '>').?;
    if (w.atPos(spot) == '#' or w.atPos(spot_r) == '#') return null;
    var action = MoveWideBoxAction{ .from = pos, .to = spot };
    switch (dir) {
        '<' => {
            // ?[]@
            if (w.atPos(spot) == ']') {
                action.behind_me[0] = (try moveWidebox(a, w, offPos(spot, '<').?, '<')) //
                orelse return null;
            }
        },
        '>' => {
            // @[]?
            if (w.atPos(spot_r) == '[') {
                action.behind_me[0] = (try moveWidebox(a, w, spot_r, '>')) orelse {
                    return null;
                };
            }
        },
        '^', 'v' => {
            if (w.atPos(spot) == '[') {
                action.behind_me[0] = (try moveWidebox(a, w, spot, dir)) orelse {
                    return null;
                };
            }
            if (w.atPos(spot) == ']') {
                action.behind_me[0] = (try moveWidebox(a, w, offPos(spot, '<').?, dir)) //
                orelse return null;
            }
            if (w.atPos(spot_r) == '[') {
                action.behind_me[1] = (try moveWidebox(a, w, spot_r, dir)) orelse {
                    if (action.behind_me[0]) |b| b.dealloc(a);
                    return null;
                };
            }
        },
        else => unreachable,
    }
    const res = try MoveWideBoxAction.alloc(a);
    res.* = action;
    return res;
}

fn moveRobot(w: *utils.Grid(u8), dir: u8) !void {
    var alc = std.heap.stackFallback(50 * 50 * 8, std.heap.page_allocator);
    const a = alc.get();
    const bot_pos = w.indexOf('@') orelse return error.NoBot;
    const bot_tgt = offPos(bot_pos, dir).?;
    if (w.atPos(bot_tgt).? == '#') return;
    if (w.atPos(bot_tgt) == 'O') {
        var free_spot = offPos(bot_tgt, dir);
        while (free_spot) |spot| : (free_spot = offPos(spot, dir)) {
            if (w.atPos(spot) == '#') return;
            if (w.atPos(spot) == '.') {
                w.atPosRef(spot).?.* = 'O';
                break;
            }
        }
    }
    if (w.atPos(bot_tgt) == '[') {
        const action = (try moveWidebox(a, w, bot_tgt, dir)) orelse return;
        action.execute(w);
        action.dealloc(a);
    }
    if (w.atPos(bot_tgt) == ']') {
        const action = (try moveWidebox(a, w, offPos(bot_tgt, '<').?, dir)) orelse return;
        action.execute(w);
        action.dealloc(a);
    }
    w.atPosRef(bot_pos).?.* = '.';
    w.atPosRef(bot_tgt).?.* = '@';
}

fn gpsCoord(pos: utils.grid.Pos) usize {
    return @as(usize, @intCast(pos.row)) * 100 + @as(usize, @intCast(pos.col));
}

fn widenWarehouse(a: std.mem.Allocator, w: utils.Grid(u8)) !utils.Grid(u8) {
    var wide = try utils.Grid(u8).init(a, w.width * 2, w.height());
    for (0..w.height()) |row_idx| {
        const row = w.cr(row_idx);
        var wide_row = wide.r(row_idx);
        for (0.., row) |og_col_idx, og_elem| {
            const wide_elems = switch (og_elem) {
                '#' => "##",
                'O' => "[]",
                '.' => "..",
                '@' => "@.",
                else => "??",
            };
            wide_row[og_col_idx * 2] = wide_elems[0];
            wide_row[og_col_idx * 2 + 1] = wide_elems[1];
        }
    }
    return wide;
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

    std.log.debug("Reading {s}", .{infile});
    const file = std.fs.cwd().openFile(infile, .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return;
    };
    defer file.close();

    const input_str = try file.readToEndAlloc(a, std.math.pow(u32, 2, 20));
    var input = try parse_input(a, input_str);
    defer input.deinit();

    var wide_warehouse = try widenWarehouse(a, input.warehouse);
    defer wide_warehouse.deinit();

    {
        for (input.movements) |move| {
            try moveRobot(&input.warehouse, move);
        }
        input.warehouse.log();

        var sum: usize = 0;
        var pos_it = input.warehouse.allPositions();
        while (pos_it.next()) |pos| {
            if (input.warehouse.atPos(pos) == 'O') {
                sum += gpsCoord(pos);
            }
        }

        _ = try stdout.print("The sum of GPS coordinates is {}\n", .{sum});
    }

    {
        wide_warehouse.log();
        for (input.movements) |move| {
            try moveRobot(&wide_warehouse, move);
            std.log.debug("\nMove {c}:", .{move});
            wide_warehouse.log();
        }

        var sum: usize = 0;
        var pos_it = wide_warehouse.allPositions();
        while (pos_it.next()) |pos| {
            if (wide_warehouse.atPos(pos) == '[') {
                sum += gpsCoord(pos);
            }
        }

        _ = try stdout.print(
            "The sum of GPS coordinates in the wide warehouse is {}\n",
            .{sum},
        );
    }

    try bw.flush();
}
