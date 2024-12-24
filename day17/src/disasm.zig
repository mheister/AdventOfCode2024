const std = @import("std");
const log = std.log.info;

pub fn log_disasm(program: []const u8) !void {
    var ip: usize = 0;
    while (ip < program.len - 1) : (ip += 2) {
        const op: [:0]const u8 = switch (program[ip]) {
            0 => "div #a, ",
            1 => "xor #b, ",
            2 => "st  #b, ",
            3 => "jnz #a, ",
            4 => "xor #b, #c",
            5 => "out ",
            6 => "div #b, #a, ",
            7 => "div #c, #a, ",
            else => "INV ",
        };
        var operand_buf: [12:0]u8 = undefined;
        @memset(&operand_buf, 0);
        const operand = switch (program[ip]) {
            0, 2, 5, 6, 7 => try switch (program[ip + 1]) {
                0, 1, 2, 3 => std.fmt.bufPrint(&operand_buf, "{}", .{program[ip + 1]}),
                4, 5, 6 => std.fmt.bufPrint(
                    &operand_buf,
                    "#{c}",
                    .{'a' - 4 + program[ip + 1]},
                ),
                else => std.fmt.bufPrint(&operand_buf, "#INV", .{}),
            },
            1, 3 => try std.fmt.bufPrint(&operand_buf, "{}", .{program[ip + 1]}),
            else => &.{},
        };
        log("{d: >3.0}: {s}{s}", .{ ip, op, operand });
    }
}
