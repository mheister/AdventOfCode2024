const std = @import("std");
const mcha = @import("mecha");

const dbg = std.log.debug;

const Rule = mcha.combine(
    .{
        mcha.int(u32, .{}),
        mcha.ascii.char('|').discard(),
        mcha.int(u32, .{}),
    },
);
const RuleList = mcha.many(Rule, .{ .separator = mcha.ascii.char('\n').discard() });
const Update = mcha.many(mcha.int(u32, .{}), .{
    .min = 1,
    .separator = mcha.ascii.char(',').discard(),
});
const UpdateList = mcha.many(Update, .{ .separator = mcha.ascii.char('\n').discard() });
const Input = struct {
    rules: []struct { u32, u32 },
    updates: [][]u32,
    fn deinit(self: @This(), a: std.mem.Allocator) void {
        a.free(self.rules);
        for (self.updates) |u| a.free(u);
        a.free(self.updates);
    }
};
const InputParser = mcha.combine(
    .{
        RuleList,
        mcha.ascii.char('\n').discard(),
        mcha.ascii.char('\n').discard(),
        UpdateList,
    },
).map(mcha.toStruct(Input));

pub fn parse_input(a: std.mem.Allocator, input: []const u8) !Input {
    const res = try InputParser.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
    return error.ShouldNotHappen;
}

test "parse input test" {
    const expect = std.testing.expect;
    const expectEq = std.testing.expectEqual;
    const input =
        \\1|2
        \\3|4
        \\
        \\5,6,7
        \\8
    ;
    const a = std.testing.allocator;
    const res = try parse_input(a, input);
    defer res.deinit(a);
    try expectEq(res.rules.len, 2);
    try expectEq(res.rules[0], .{ 1, 2 });
    try expectEq(res.rules[1], .{ 3, 4 });
    try expectEq(res.updates.len, 2);
    try expect(std.mem.eql(u32, res.updates[0], &.{ 5, 6, 7 }));
    try expect(std.mem.eql(u32, res.updates[1], &.{8}));
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
    const input = try parse_input(a, input_str);
    defer input.deinit(a);

    _ = try stdout.print("Input {any}\n", .{input});

    try bw.flush();
}
