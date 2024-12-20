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

    _ = try stdout.print("The safety factor is {}\n", .{0});

    try bw.flush();
}
