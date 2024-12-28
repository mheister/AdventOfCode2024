// pick up tests
comptime {
    _ = @import("computer.zig");
}

const std = @import("std");
const computer = @import("computer.zig");
const log_disasm = @import("disasm.zig").log_disasm;

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

    try log_disasm(input.program);

    var output = std.ArrayList(u3).init(a);
    defer output.deinit();

    var printer = ArrayListPrinter{ .array_list = &output };

    var c = computer.Computer{
        .reg_a = input.reg_a,
        .reg_b = input.reg_b,
        .reg_c = input.reg_c,
        .program = input.program,
        .printer = printer.get(),
    };

    for (0..9000) |_| {
        if (try c.step() == .halted) break;
    }

    _ = try stdout.print("Output: ", .{});

    if (output.items.len > 0) {
        _ = try stdout.print("{}", .{output.items[0]});
    }
    for (output.items[1..]) |o| {
        _ = try stdout.print(",{}", .{o});
    }

    // Part 2: (given my input)
    // - #a needs to be at least 8^(proglen - 1)
    // - oup = (b6 ^ c4).l = (reg_a.l ^ 1 ^ (reg_a / 2^(reg_a.l ^ 2))).l
    // - for step N: oup := U => reg_a.l ^ 1 ^ (reg_a / 2^(reg_a.l ^ 2)) = U
    // => reg_a.l ^ U ^ 1 = reg_a / 2^(reg_a.l ^ 2)
    // for U=1, 2^(reg_a.l ^ 2) = 1 + 8*X
    // - div by 8 is like shift 3 and so on..
    // - input reg_a is 64584136 = 11.110.110.010.111.100.111.001.000
    // - high bits of reg_a's init value don't seem to influence low early outputs

    // fix an init value for reg A, fix outputs one by one from the end
    var try_a: usize = 0;
    var chk_idx: usize = 15;
    while (true) {
        const start = (try_a >> @intCast(chk_idx * 3)) & 7;
        std.log.debug("attempting {} - start={o} reg a={o}", .{ chk_idx, start, try_a });
        for (start..9) |v| {
            const try_a_sub = try_a //
            & ~(@as(usize, 7) << @intCast(chk_idx * 3)) //
            | ((v & 7) << @intCast(chk_idx * 3));
            std.log.debug("  -{}- a={o}", .{ v, try_a_sub });
            output.clearRetainingCapacity();
            c.reg_a = try_a_sub;
            c.ip = 0;
            for (0..9000) |_| {
                if (try c.step() == .halted) break;
            }
            if (output.items.len < 15) continue;
            if (output.items[chk_idx] == input.program[chk_idx]) {
                try_a = try_a_sub;
                break;
            }
        } else {
            std.log.debug("no sol for {} - reg a={b}", .{ chk_idx, try_a });
            // try_a = try_a | (@as(usize, 7) << @intCast(chk_idx * 3));
            try_a = try_a & ~(@as(usize, 7) << @intCast(chk_idx * 3));
            // backtrack to an earlier position
            chk_idx += 1;
            const prev_start = (try_a >> @intCast(chk_idx * 3)) & 7;
            try_a = try_a //
            & ~(@as(usize, 7) << @intCast(chk_idx * 3)) //
            | ((prev_start + 1) << @intCast(chk_idx * 3));
            continue;
        }
        if (chk_idx == 0) break;
        chk_idx -= 1;
    }
    _ = try stdout.print("\nReplicating A value: {}\n", .{try_a});

    try bw.flush();
}

const ArrayListPrinter = struct {
    array_list: *std.ArrayList(u3),
    fn print(self_o: *anyopaque, data: u3) !void {
        const self: *@This() = @ptrCast(@alignCast(self_o));
        try self.array_list.append(data);
    }
    fn get(self: *@This()) computer.Printer {
        return .{
            .user = self,
            .print_fn = print,
        };
    }
};
