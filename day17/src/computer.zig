const std = @import("std");

const expectEq = std.testing.expectEqual;

pub const Error = error{ InvalidOpcode, InvalidCombo, MissingPrinter, PrintError };
pub const StepResult = enum { ok, halted };

pub const Computer = struct {
    reg_a: usize = 0,
    reg_b: usize = 0,
    reg_c: usize = 0,
    ip: usize = 0,
    program: []const u8,
    printer: ?Printer = null,

    pub fn step(self: *@This()) Error!StepResult {
        if (self.ip >= self.program.len) {
            return .halted;
        }
        const fetch = self.program[self.ip .. self.ip + 2];
        self.ip += 2;
        switch (fetch[0]) {
            0 => try self.adv(fetch[1]),
            1 => try self.bxl(fetch[1]),
            2 => try self.bst(fetch[1]),
            3 => try self.jnz(fetch[1]),
            4 => try self.bxc(fetch[1]),
            5 => try self.out(fetch[1]),
            6 => try self.bdv(fetch[1]),
            7 => try self.cdv(fetch[1]),
            else => return error.InvalidOpcode,
        }
        return .ok;
    }

    pub fn setPrinter(self: *@This(), p: Printer) void {
        self.printer = p;
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

    fn bxl(self: *@This(), operand: u8) Error!void {
        self.reg_b = self.reg_b ^ operand;
    }

    fn bst(self: *@This(), operand: u8) Error!void {
        const operand_resolved = try self.combo(operand);
        self.reg_b = operand_resolved & 0b111;
    }

    fn jnz(self: *@This(), operand: u8) Error!void {
        if (self.reg_a != 0) {
            self.ip = @intCast(operand);
        }
    }

    fn bxc(self: *@This(), _: u8) Error!void {
        self.reg_b = self.reg_b ^ self.reg_c;
    }

    fn out(self: *@This(), operand: u8) Error!void {
        if (self.printer) |printer| {
            const operand_resolved = try self.combo(operand);
            printer.print(@intCast(operand_resolved & 0b111)) catch |err| {
                std.log.warn("Failed to print: {!}", .{err});
                return error.PrintError;
            };
        } else return error.MissingPrinter;
    }

    fn bdv(self: *@This(), operand: u8) Error!void {
        const operand_resolved = try self.combo(operand);
        self.reg_b = self.reg_a / (@as(usize, 1) << @intCast(operand_resolved));
    }

    fn cdv(self: *@This(), operand: u8) Error!void {
        const operand_resolved = try self.combo(operand);
        self.reg_c = self.reg_a / (@as(usize, 1) << @intCast(operand_resolved));
    }
};

pub const Printer = struct {
    user: *anyopaque,
    print_fn: *const fn (user: *anyopaque, data: u3) anyerror!void,

    fn print(self: @This(), data: u3) !void {
        return self.print_fn(self.user, data);
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

test "adv" {
    // immediates
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
    // register
    {
        const program = [_]u8{ 0, 5 }; // div combo 5 for reg_b
        var c = Computer{ .reg_a = 8, .reg_b = 1, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_a);
    }
}

test "bxl" {
    {
        const program = [_]u8{ 1, 0b101 };
        var c = Computer{ .reg_b = 0b111, .program = &program };
        _ = try c.step();
        try expectEq(0b010, c.reg_b);
    }
    {
        const program = [_]u8{ 1, 0b000 };
        var c = Computer{ .reg_b = 0b111, .program = &program };
        _ = try c.step();
        try expectEq(0b111, c.reg_b);
    }
}

test "bst" {
    // immediate
    {
        const program = [_]u8{ 2, 2 };
        var c = Computer{ .program = &program };
        _ = try c.step();
        try expectEq(2, c.reg_b);
    }
    // reg
    {
        const program = [_]u8{ 2, 4 }; // bst combo 4 for reg_a
        var c = Computer{ .reg_a = 0b111111, .program = &program };
        _ = try c.step();
        try expectEq(0b111, c.reg_b);
    }
}

test "jnz" {
    {
        const program = [_]u8{ 3, 8, 3, 8 };
        var c = Computer{ .reg_a = 0, .program = &program };
        _ = try c.step();
        try expectEq(2, c.ip); // a == 0 -> no jump
        c.reg_a = 11;
        _ = try c.step();
        try expectEq(8, c.ip);
    }
}

test "bxc" {
    {
        const program = [_]u8{ 4, 0 };
        var c = Computer{ .reg_b = 0b10101, .reg_c = 0b11110, .program = &program };
        _ = try c.step();
        try expectEq(0b01011, c.reg_b);
    }
}

const OneTimePrinter = struct {
    output: ?u3 = null,
    fn print(self_o: *anyopaque, data: u3) !void {
        const self: *@This() = @ptrCast(@alignCast(self_o));
        if (self.output != null) return error.AlreadyPrinted;
        self.output = data;
    }
    fn get(self: *@This()) Printer {
        return .{
            .user = self,
            .print_fn = print,
        };
    }
};

test "out" {
    {
        const program = [_]u8{ 5, 1 };
        var c = Computer{ .program = &program };
        try std.testing.expectError(error.MissingPrinter, c.step());
    }
    {
        var printer = OneTimePrinter{};
        const program = [_]u8{ 5, 1 };
        var c = Computer{ .program = &program, .printer = printer.get() };
        _ = try c.step();
        try expectEq(1, printer.output);
    }
    {
        var printer = OneTimePrinter{};
        const program = [_]u8{ 5, 4 };
        var c = Computer{ .reg_a = 7, .program = &program, .printer = printer.get() };
        _ = try c.step();
        try expectEq(7, printer.output);
    }
    {
        // OneTimePrinter errros with pre-set value -> should error on step
        var printer = OneTimePrinter{ .output = 0 };
        const program = [_]u8{ 5, 1 };
        var c = Computer{ .program = &program, .printer = printer.get() };
        try std.testing.expectError(error.PrintError, c.step());
    }
}

test "bdv" {
    // immediates
    {
        const program = [_]u8{ 6, 0 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(8, c.reg_b);
    }
    {
        const program = [_]u8{ 6, 1 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_b);
    }
    {
        const program = [_]u8{ 6, 2 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(2, c.reg_b);
    }
    // register
    {
        const program = [_]u8{ 6, 5 }; // div combo 5 for reg_b
        var c = Computer{ .reg_a = 8, .reg_b = 1, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_b);
    }
}

test "cdv" {
    // immediates
    {
        const program = [_]u8{ 7, 0 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(8, c.reg_c);
    }
    {
        const program = [_]u8{ 7, 1 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_c);
    }
    {
        const program = [_]u8{ 7, 2 };
        var c = Computer{ .reg_a = 8, .program = &program };
        _ = try c.step();
        try expectEq(2, c.reg_c);
    }
    // register
    {
        const program = [_]u8{ 7, 5 }; // div combo 5 for reg_b
        var c = Computer{ .reg_a = 8, .reg_b = 1, .program = &program };
        _ = try c.step();
        try expectEq(4, c.reg_c);
    }
}
