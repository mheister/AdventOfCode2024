const std = @import("std");
const mcha = @import("mecha");

const Mul = mcha.combine(.{
    mcha.string("mul(").discard(),
    mcha.int(u32, .{}),
    mcha.ascii.char(',').discard(),
    mcha.int(u32, .{}),
    mcha.ascii.char(')').discard(),
});
const Input1 = mcha.many(
    mcha.oneOf(.{ Mul, mcha.ascii.range(1, 255).mapConst(@as(@TypeOf(Mul).T, .{ 0, 0 })) }),
    .{},
);
const DontDo = mcha.combine(.{
    mcha.string("don't()").discard(),
    mcha.many(mcha.ascii.not(mcha.string("do()")).discard(), .{ .collect = false }).discard(),
});
const Input2 = mcha.many(
    mcha.oneOf(.{
        DontDo.mapConst(@as(@TypeOf(Mul).T, .{ 0, 0 })),
        Mul,
        mcha.ascii.range(1, 255).mapConst(@as(@TypeOf(Mul).T, .{ 0, 0 })),
    }),
    .{},
);

pub fn parse_program(a: std.mem.Allocator, input: []const u8) ![]struct { u32, u32 } {
    const res = try Input1.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
}

test "parse program test" {
    const expectEq = std.testing.expectEqual;
    const input =
        \\mul(1,1)
        \\xmul(2,2)x
    ;
    const a = std.testing.allocator;
    const res = try parse_program(a, input);
    try expectEq(res.len, 5);
    try expectEq(res[0], .{ 1, 1 });
    try expectEq(res[1], .{ 0, 0 });
    try expectEq(res[2], .{ 0, 0 });
    try expectEq(res[3], .{ 2, 2 });
    try expectEq(res[4], .{ 0, 0 });
    a.free(res);
}

pub fn parse_program_2(a: std.mem.Allocator, input: []const u8) ![]struct { u32, u32 } {
    const res = try Input2.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
}

test "parse program 2 test" {
    const expectEq = std.testing.expectEqual;
    const input = "mul(1,1)don't()xmul(2,2)do()mul(1,1)don't()mul(7,7)";
    const a = std.testing.allocator;
    const res = try parse_program_2(a, input);
    try expectEq(res.len, 8);
    try expectEq(res[0], .{ 1, 1 });
    try expectEq(res[1], .{ 0, 0 }); // don'txmul(2,2)
    try expectEq(res[2], .{ 0, 0 }); // d
    try expectEq(res[3], .{ 0, 0 }); // o
    try expectEq(res[4], .{ 0, 0 }); // (
    try expectEq(res[5], .{ 0, 0 }); // )
    try expectEq(res[6], .{ 1, 1 });
    try expectEq(res[7], .{ 0, 0 }); // don'tmul(7,7)
    a.free(res);
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

    std.log.debug("Calculatig program result", .{});
    const program = try parse_program(a, input);
    defer a.free(program);
    var sum: u64 = 0;
    for (program) |mul| {
        sum += mul[0] * mul[1];
    }

    _ = try stdout.print("The result is {}\n", .{sum});

    std.log.debug("Calculatig program result again with flow instructions", .{});
    const program2 = try parse_program_2(a, input);
    defer a.free(program2);
    var sum2: u64 = 0;
    for (program2) |mul| {
        sum2 += mul[0] * mul[1];
    }

    _ = try stdout.print("The result is {}\n", .{sum2});

    try bw.flush();
}
