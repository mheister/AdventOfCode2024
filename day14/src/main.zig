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

fn walk_robot(bot: Robot, dims: Vec2d, seconds: i32) Vec2d {
    std.debug.assert(bot.velo.x <= dims.x and bot.velo.y <= dims.y);
    const x = @rem((bot.pos.x + (dims.x + bot.velo.x) * seconds), dims.x);
    const y = @rem((bot.pos.y + (dims.y + bot.velo.y) * seconds), dims.y);
    return .{ .x = x, .y = y };
}

test "walk_robot" {
    const expectEq = std.testing.expectEqual;
    const dims = Vec2d{ .x = 11, .y = 7 };
    {
        const bot = Robot{ .pos = .{ .x = 0, .y = 0 }, .velo = .{ .x = 1, .y = 0 } };
        try expectEq(Vec2d{ .x = 0, .y = 0 }, walk_robot(bot, dims, 0));
        try expectEq(Vec2d{ .x = 1, .y = 0 }, walk_robot(bot, dims, 1));
        try expectEq(Vec2d{ .x = 10, .y = 0 }, walk_robot(bot, dims, 10));
        try expectEq(Vec2d{ .x = 0, .y = 0 }, walk_robot(bot, dims, 11));
        try expectEq(Vec2d{ .x = 1, .y = 0 }, walk_robot(bot, dims, 12));
        try expectEq(Vec2d{ .x = 0, .y = 0 }, walk_robot(bot, dims, 22));
    }
    {
        const bot = Robot{ .pos = .{ .x = 2, .y = 4 }, .velo = .{ .x = 2, .y = -3 } };
        try expectEq(Vec2d{ .x = 4, .y = 1 }, walk_robot(bot, dims, 1));
        try expectEq(Vec2d{ .x = 6, .y = 5 }, walk_robot(bot, dims, 2));
        try expectEq(Vec2d{ .x = 1, .y = 3 }, walk_robot(bot, dims, 5));
    }
}

const QuadrantCounter = struct {
    dims: Vec2d,
    quads: [4]usize = [_]usize{ 0, 0, 0, 0 },
    fn count(self: *@This(), pos: Vec2d) void {
        const border_coords =
            Vec2d{ .x = @divFloor(self.dims.x, 2), .y = @divFloor(self.dims.y, 2) };
        if (pos.x == border_coords.x or pos.y == border_coords.y) return;
        const qidx: usize =
            (if (pos.x < border_coords.x) @as(usize, 0) else 1) +
            (if (pos.y < border_coords.y) @as(usize, 0) else 2);
        self.quads[qidx] += 1;
    }
    fn get_safety_factor(self: @This()) usize {
        return self.quads[0] * self.quads[1] * self.quads[2] * self.quads[3];
    }
};

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

    const n_seconds = 100;

    var counter = QuadrantCounter{ .dims = input.dimensions };
    for (input.robots) |bot| {
        counter.count(walk_robot(bot, input.dimensions, n_seconds));
    }

    _ = try stdout.print("The sum is {}\n", .{counter.get_safety_factor()});

    try bw.flush();
}
