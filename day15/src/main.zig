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
    ;
    const a = std.testing.allocator;
    var res = try parse_input(a, input);
    defer res.deinit();
    try expectEq(8, res.warehouse.height());
    try expectEq(8, res.warehouse.width);
    try expectEq(15, res.movements.len);
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

fn move_robot(w: *utils.Grid(u8), dir: u8) !void {
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
    w.atPosRef(bot_pos).?.* = '.';
    w.atPosRef(bot_tgt).?.* = '@';
}

fn gps_coord(pos: utils.grid.Pos) usize {
    return @as(usize, @intCast(pos.row)) * 100 + @as(usize, @intCast(pos.col));
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

    for (input.movements) |move| {
        try move_robot(&input.warehouse, move);
    }
    input.warehouse.log();

    var sum: usize = 0;
    var pos_it = input.warehouse.allPositions();
    while (pos_it.next()) |pos| {
        if (input.warehouse.atPos(pos) == 'O') {
            sum += gps_coord(pos);
        }
    }

    _ = try stdout.print("The sum of GPS coordinates is {}\n", .{sum});

    try bw.flush();
}
