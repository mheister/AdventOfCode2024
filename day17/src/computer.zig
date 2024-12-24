const std = @import("std");

const expectEq = std.testing.expectEqual;

pub const Error = error{ InvalidOpcode, InvalidCombo };
pub const StepResult = enum { ok, halted };

pub const Computer = struct {
    reg_a: usize = 0,
    reg_b: usize = 0,
    reg_c: usize = 0,
    ip: usize = 0,
    program: []const u8,
    pub fn step(self: *@This()) Error!StepResult {
        defer self.ip += 2;
        if (self.ip >= self.program.len) {
            return .halted;
        }
        const fetch = self.program[self.ip .. self.ip + 2];
        switch (fetch[0]) {
            0 => try self.adv(fetch[1]),
            else => return error.InvalidOpcode,
        }
        return .ok;
    }
    fn combo(self: *const @This(), operand: u8) Error!usize {
        return switch (operand) {
            0...3 => @intCast(operand),
            4 => self.reg_a,
            5 => self.reg_b,
            6 => self.reg_c,
            else => error.InvalidCombo,
        };
    }
    test "combo" {
        const c = @This(){ .reg_a = 10, .reg_b = 20, .reg_c = 30, .program = &.{} };
        try expectEq(0, try c.combo(0));
        try expectEq(1, try c.combo(1));
        try expectEq(2, try c.combo(2));
        try expectEq(3, try c.combo(3));
        try expectEq(10, try c.combo(4));
        try expectEq(20, try c.combo(5));
        try expectEq(30, try c.combo(6));
    }
    fn adv(self: *@This(), operand: u8) Error!void {
        const operand_resolved = try self.combo(operand);
        self.reg_a = self.reg_a / (@as(usize, 1) << @intCast(operand_resolved));
    }
};

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

test "adv_immediate" {
    {
        const program = [_]u8{ 0, 0 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(8, c.reg_a);
    }
    {
        const program = [_]u8{ 0, 1 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_a);
    }
    {
        const program = [_]u8{ 0, 2 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(2, c.reg_a);
    }
}

test "adv_reg" {
    {
        const program = [_]u8{ 0, 5 }; // div combo 5 for reg_b
        var c = Computer{ .reg_a = 8, .reg_b = 1, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_a);
    }
}
