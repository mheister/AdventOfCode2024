const std = @import("std");
const mcha = @import("mecha");

const Spaces = mcha.many(mcha.ascii.char(' ').discard(), .{ .collect = false }).discard();
const InputLine = mcha.combine(.{ mcha.int(u32, .{}), Spaces, mcha.int(u32, .{}) });
const Input = mcha.many(InputLine, .{ .separator = mcha.ascii.char('\n').discard() });

pub fn parse_input(a: std.mem.Allocator, input: []const u8) ![]struct { u32, u32 } {
    const res = try Input.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
    return 0;
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;
    const a = std.testing.allocator;
    const res = try parse_input(a, input);
    try expectEq(res.len, 6);
    try expectEq(res[0], .{ 3, 4 });
    try expectEq(res[1], .{ 4, 3 });
    try expectEq(res[2], .{ 2, 5 });
    try expectEq(res[3], .{ 1, 3 });
    try expectEq(res[4], .{ 3, 9 });
    try expectEq(res[5], .{ 3, 3 });
    a.free(res);
}

fn transpose_input(a: std.mem.Allocator, data: []struct { u32, u32 }) !struct { []u32, []u32 } {
    var res = .{
        try a.alloc(u32, data.len),
        try a.alloc(u32, data.len),
    };
    for (data, 0..) |entry, i| {
        res[0][i] = entry[0];
        res[1][i] = entry[1];
    }
    return res;
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
    const data = try transpose_input(a, data_rows);
    a.free(data_rows);

    std.mem.sort(u32, data[0], {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, data[1], {}, comptime std.sort.asc(u32));

    std.log.debug("Calculatig sum", .{});
    var sum: u64 = 0;
    for (0..data[0].len) |i| {
        sum += @abs(@as(i64, data[0][i]) - @as(i64, data[1][i]));
    }

    _ = try stdout.print("The sum is {}\n", .{sum});

    std.log.debug("Calculatig similarity", .{});
    var similarity: u64 = 0;
    var ridx: usize = 0;
    for (0..data[0].len) |i| {
        const val = data[0][i];
        while (ridx < data[1].len and data[1][ridx] < val) {
            ridx += 1;
        }
        while (ridx < data[1].len and data[1][ridx] == val) {
            similarity += val;
            ridx += 1;
        }
    }

    _ = try stdout.print("The similarity is {}\n", .{similarity});

    try bw.flush();
}
