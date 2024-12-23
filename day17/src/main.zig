// pick up tests
comptime {
    _ = @import("computer.zig");
}

const std = @import("std");

const Input = struct {
    reg_a: usize,
    reg_b: usize,
    reg_c: usize,
    program: []const u8,
};

fn parse_input(a: std.mem.Allocator, input: []const u8) !Input {
    const parser = comptime detail: {
        const ToInput = struct {
            fn do(v: struct { [3]usize, []u8 }) Input {
                return .{
                    .reg_a = v[0][0],
                    .reg_b = v[0][1],
                    .reg_c = v[0][2],
                    .program = v[1],
                };
            }
        };
        const mcha = @import("mecha");
        const NewLine = mcha.ascii.char('\n').discard();
        const Register = mcha.combine(.{
            mcha.string("Register ").discard(),
            mcha.ascii.range('A', 'Z').discard(),
            mcha.string(": ").discard(),
            mcha.int(usize, .{}),
        });
        const InputPrsr = mcha.combine(.{
            mcha.manyN(Register, 3, .{ .separator = NewLine }),
            NewLine,
            NewLine,
            mcha.string("Program: ").discard(),
            mcha.many(mcha.int(u8, .{}), .{ .separator = mcha.ascii.char(',').discard() }),
        }).map(ToInput.do);
        break :detail InputPrsr;
    };
    const res = try parser.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
    return 0;
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const expectEqSlices = std.testing.expectEqualSlices;
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;
    const a = std.testing.allocator;
    const res = try parse_input(a, input);
    try expectEq(729, res.reg_a);
    try expectEq(0, res.reg_b);
    try expectEq(0, res.reg_c);
    try expectEqSlices(u8, &.{ 0, 1, 5, 4, 3, 0 }, res.program);
    a.free(res.program);
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
    defer a.free(input.program);

    _ = try stdout.print("The output is {}\n", .{0});

    try bw.flush();
}
