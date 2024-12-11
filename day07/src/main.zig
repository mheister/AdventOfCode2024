const std = @import("std");
const mcha = @import("mecha");

const dbg = std.log.debug;

const Ch = mcha.ascii.char;
const Operands = mcha.many(mcha.int(u32, .{}), .{ .separator = Ch(' ').discard() });
const Equation = struct {
    result: u64,
    operands: []u32,
    fn deinit(self: @This(), a: std.mem.Allocator) void {
        a.free(self.operands);
    }
};
const EquationParser = mcha.combine(.{
    mcha.int(u64, .{}),
    Ch(':').discard(),
    Ch(' ').discard(),
    Operands,
}).map(mcha.toStruct(Equation));
const Calibration = struct {
    equations: []Equation,
    fn deinit(self: @This(), a: std.mem.Allocator) void {
        for (self.equations) |eqn| {
            eqn.deinit(a);
        }
        a.free(self.equations);
    }
};
const Input = mcha.many(EquationParser, .{ .separator = Ch('\n').discard() })
    .map(mcha.toStruct(Calibration));

pub fn parse_input(a: std.mem.Allocator, input: []const u8) !Calibration {
    const res = try Input.parse(a, input);
    switch (res.value) {
        .ok => return res.value.ok,
        .err => return error.ParseError,
    }
    return 0;
}

test "parse input test" {
    const expect = std.testing.expect;
    const expectEq = std.testing.expectEqual;
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    const a = std.testing.allocator;
    const res = try parse_input(a, input);
    defer res.deinit(a);
    const eqns = res.equations;
    try expectEq(eqns.len, 9);
    try expectEq(eqns[0].result, 190);
    try expect(std.mem.eql(u32, eqns[0].operands, &.{ 10, 19 }));
}

const EqnChecker = struct {
    const WorkItem = struct { pos: usize, intermed: u64, op: Op };
    const Op = enum { Mul, Plus };
    a: std.mem.Allocator,
    work: std.ArrayList(WorkItem), // flyweight
    fn init(a: std.mem.Allocator) @This() {
        return @This(){ .a = a, .work = std.ArrayList(WorkItem).init(a) };
    }
    fn deinit(this: @This()) void {
        this.work.deinit();
    }
    fn check(this: *@This(), eqn: Equation) !bool {
        this.work.clearRetainingCapacity();
        try this.work.appendSlice(&.{
            .{ .pos = 1, .intermed = eqn.operands[0], .op = Op.Plus },
            .{ .pos = 1, .intermed = eqn.operands[0], .op = Op.Mul },
        });
        while (this.work.items.len > 0) {
            const e = this.work.pop();
            if (e.pos == eqn.operands.len) {
                if (e.intermed == eqn.result) {
                    return true;
                }
                continue;
            }
            const intermed = switch (e.op) {
                Op.Mul => e.intermed * eqn.operands[e.pos],
                Op.Plus => e.intermed + eqn.operands[e.pos],
            };
            if (intermed > eqn.result) {
                continue;
            }
            try this.work.appendSlice(&.{
                .{ .pos = e.pos + 1, .intermed = intermed, .op = Op.Plus },
                .{ .pos = e.pos + 1, .intermed = intermed, .op = Op.Mul },
            });
        }
        return false;
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

    const input = try file.readToEndAlloc(a, std.math.pow(u32, 2, 20));
    const calibration = try parse_input(a, input);
    defer calibration.deinit(a);

    var sum: u64 = 0;

    var checker = EqnChecker.init(a);
    defer checker.deinit();

    for (calibration.equations) |eqn| {
        if (try checker.check(eqn)) {
            sum += eqn.result;
        }
    }

    _ = try stdout.print("The sum is {}\n", .{sum});

    try bw.flush();
}
