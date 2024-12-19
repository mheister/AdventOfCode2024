const std = @import("std");
const mcha = @import("mecha");

const ButtonA = mcha.combine(.{
    mcha.string("Button A: X+").discard(),
    mcha.int(u32, .{}),
    mcha.string(", Y+").discard(),
    mcha.int(u32, .{}),
});
const ButtonB = mcha.combine(.{
    mcha.string("Button B: X+").discard(),
    mcha.int(u32, .{}),
    mcha.string(", Y+").discard(),
    mcha.int(u32, .{}),
});
const Prize = mcha.combine(.{
    mcha.string("Prize: X=").discard(),
    mcha.int(u32, .{}),
    mcha.string(", Y=").discard(),
    mcha.int(u32, .{}),
});
const NewLine = mcha.ascii.char('\n').discard();
const MachinePrsr = mcha.combine(.{
    ButtonA,
    NewLine,
    ButtonB,
    NewLine,
    Prize,
}).map(mcha.toStruct(Machine));
const Input = mcha.many(
    MachinePrsr,
    .{ .separator = mcha.many(NewLine, .{ .collect = false }).discard() },
);

pub fn parse_input(a: std.mem.Allocator, input: []const u8) ![]Machine {
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
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
    ;
    const a = std.testing.allocator;
    const res = try parse_input(a, input);
    try expectEq(2, res.len);
    try expectEq(.{ 94, 34 }, res[0].button_a);
    try expectEq(.{ 22, 67 }, res[0].button_b);
    try expectEq(.{ 8400, 5400 }, res[0].prize);
    try expectEq(.{ 26, 66 }, res[1].button_a);
    try expectEq(.{ 67, 21 }, res[1].button_b);
    try expectEq(.{ 12748, 12176 }, res[1].prize);
    a.free(res);
}

const Machine = struct {
    button_a: struct { u32, u32 }, // xy
    button_b: struct { u32, u32 }, // xy
    prize: struct { u32, u32 }, // xy
};

fn asI32(i: u32) i32 {
    return @as(i32, @intCast(i));
}

// return cost of winning or zero if impossible
fn win(m: Machine) u32 {
    // solving for a and b
    // btn_a.x * a + btn_b.x * b = prz.x
    // btn_a.y * a + btn_b.y * b = prz.y

    const determinant =
        asI32(m.button_a[0] * m.button_b[1]) - asI32(m.button_a[1] * m.button_b[0]);

    var a: u32 = undefined;
    var b: u32 = undefined;

    if (determinant != 0) {
        // Cramer's rule
        a = @intCast(@max(0, @divTrunc(
            (asI32(m.prize[0] * m.button_b[1]) - asI32(m.prize[1] * m.button_b[0])),
            determinant,
        )));
        b = @intCast(@max(0, @divTrunc(
            (asI32(m.button_a[0] * m.prize[1]) - asI32(m.button_a[1] * m.prize[0])),
            determinant,
        )));
    } else {
        // minimize 3a + b, given
        // btn_a.x * a + btn_b.x * b = prz.x
        const b_guess = @divFloor(m.prize[0], m.button_b[0]);
        a = std.math.divCeil(
            u32,
            (m.prize[0] - m.button_b[0] * b_guess),
            m.button_a[0],
        ) catch unreachable;
        b = @divFloor((m.prize[0] - m.button_a[0] * a), m.button_a[0]);
    }

    if (m.button_a[0] * a + m.button_b[0] * b == m.prize[0]) {
        return 3 * a + b;
    }
    return 0;
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
    const machines = try parse_input(a, input);
    defer a.free(machines);

    var sum: usize = 0;
    for (machines) |m| {
        const cost = win(m);
        std.log.debug("Machine costs {}", .{cost});
        sum += cost;
    }

    _ = try stdout.print("Winning it all costs at least {} tokens\n", .{sum});
    try bw.flush();
}
