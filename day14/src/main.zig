const std = @import("std");
const mcha = @import("mecha");

const Vec2d = struct { x: i32, y: i32 };
const Robot = struct { pos: Vec2d, velo: Vec2d };

const Input = struct {
    robots: []Robot,
    dimensions: Vec2d, // width and height
    allocator: std.mem.Allocator,
    fn deinit(self: *@This()) void {
        self.allocator.free(self.robots);
    }
};

pub fn parse_input(a: std.mem.Allocator, input: []const u8) !Input {
    const InputPrsr = comptime detail: {
        const DiscardNewLine = mcha.ascii.char('\n').discard();
        const DiscardSpace = mcha.ascii.char(' ').discard();
        const InputPosition = mcha.combine(.{
            mcha.string("p=").discard(),
            mcha.int(i32, .{}),
            mcha.ascii.char(',').discard(),
            mcha.int(i32, .{}),
        }).map(mcha.toStruct(Vec2d));
        const InputVecocity = mcha.combine(.{
            mcha.string("v=").discard(),
            mcha.int(i32, .{}),
            mcha.ascii.char(',').discard(),
            mcha.int(i32, .{}),
        }).map(mcha.toStruct(Vec2d));
        const InputLine =
            mcha.combine(.{ InputPosition, DiscardSpace, InputVecocity })
            .map(mcha.toStruct(Robot));
        break :detail mcha.many(InputLine, .{ .separator = DiscardNewLine });
    };

    const res = try InputPrsr.parse(a, input);
    const bots = switch (res.value) {
        .ok => res.value.ok,
        .err => return error.ParseError,
    };
    // they always put a robot in the corner, so we can get the space dimensions
    var dimensions = Vec2d{ .x = 0, .y = 0 };
    for (bots) |bot| {
        dimensions.x = @max(dimensions.x, bot.pos.x + 1);
        dimensions.y = @max(dimensions.y, bot.pos.y + 1);
    }
    return .{ .robots = bots, .dimensions = dimensions, .allocator = a };
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
    ;
    const a = std.testing.allocator;
    var res = try parse_input(a, input);
    defer res.deinit();
    try expectEq(3, res.robots.len);
    try expectEq(Vec2d{ .x = 0, .y = 4 }, res.robots[0].pos);
    try expectEq(Vec2d{ .x = 3, .y = -3 }, res.robots[0].velo);
    try expectEq(Vec2d{ .x = 10, .y = 3 }, res.robots[2].pos);
    try expectEq(Vec2d{ .x = -1, .y = 2 }, res.robots[2].velo);
    try expectEq(Vec2d{ .x = 11, .y = 5 }, res.dimensions);
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

    const input = try file.readToEndAlloc(a, std.math.pow(u32, 2, 20));
    const data_rows = try parse_input(a, input);
    defer a.free(data_rows);

    _ = try stdout.print("The sum is {}\n", .{0});

    try bw.flush();
}
