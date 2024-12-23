const std = @import("std");

pub const Error = error{invalid_opcode};
pub const StepResult = enum { ok, halted };

pub const Computer = struct {
    reg_a: usize = 0,
    reg_b: usize = 0,
    rec_c: usize = 0,
    ip: usize = 0,
    program: []const u8,
    pub fn step(self: *@This()) Error!StepResult {
        //
        const res: StepResult = if (self.ip < self.program.len) .ok else .halted;
        self.ip += 2;
        return res;
    }
};

const expectEq = std.testing.expectEqual;

test "step" {
    const program = [_]u8{ 0, 0 };
    var c = Computer{ .program = &program };
    try expectEq(.ok, try c.step());
}

test "halt" {
    {
        const program = [_]u8{};
        var c = Computer{ .program = &program };
        try expectEq(.halted, try c.step());
    }
    {
        const program = [_]u8{ 0, 0 };
        var c = Computer{ .ip = 2, .program = &program };
        try expectEq(.halted, try c.step());
    }
}

test "ip_advances" {
    {
        const program = [_]u8{ 0, 0 };
        var c = Computer{ .program = &program };
        _ = try c.step();
        try expectEq(2, c.ip);
    }
}
