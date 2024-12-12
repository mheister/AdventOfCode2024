const std = @import("std");
const utils = @import("utils");

const dbg = std.log.debug;

const Antenna = struct {
    row: u32,
    col: u32,
    freq: u8,
};

fn parse_input(a: std.mem.Allocator, input: []const u8) !std.ArrayList(Antenna) {
    var res = std.ArrayList(Antenna).init(a);

    var line_it = utils.enumerate(std.mem.splitScalar(u8, input, '\n'));
    while (line_it.next()) |line| {
        if (line.val.len == 0) break; // trailing newline
        for (0.., line.val) |col, ch| {
            if (ch == '.') continue;
            try res.append(
                .{ .row = @intCast(line.idx), .col = @intCast(col), .freq = ch },
            );
        }
    }

    return res;
}

test "parse_input" {
    const expectDeq = std.testing.expectEqualDeep;
    const a = std.testing.allocator;
    const res = try parse_input(a,
        \\............
        \\........0...
        \\.....r......
    );
    defer res.deinit();
    try expectDeq(
        &.{
            Antenna{ .row = 1, .col = 8, .freq = '0' },
            Antenna{ .row = 2, .col = 5, .freq = 'r' },
        },
        res.items,
    );
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
    const data = try parse_input(a, input);

    std.log.debug("Calculatig sum", .{});
    const sum: u64 = data.items.len;

    _ = try stdout.print("The sum is {}\n", .{sum});

    try bw.flush();
}
