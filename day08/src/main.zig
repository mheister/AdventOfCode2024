const std = @import("std");
const utils = @import("utils");

const dbg = std.log.debug;

const Antenna = struct {
    row: u32,
    col: u32,
    freq: u8,
};

const City = struct {
    width: u32,
    height: u32,
    antennas: []Antenna,
    a: std.mem.Allocator,
    pub fn deinit(self: *@This()) void {
        self.a.free(self.antennas);
    }
    fn init_from_input(a: std.mem.Allocator, input: []const u8) !City {
        var res = City{
            .a = a,
            .width = undefined,
            .height = undefined,
            .antennas = undefined,
        };
        var antennas = std.ArrayList(Antenna).init(a);
        var line_it = utils.enumerate(std.mem.splitScalar(u8, input, '\n'));
        res.width = @intCast(line_it.peek().?.val.len);
        while (line_it.next()) |line| {
            if (line.val.len == 0) break; // trailing newline
            res.height = @intCast(line.idx + 1);
            for (0.., line.val) |col, ch| {
                if (ch == '.') continue;
                try antennas.append(
                    .{ .row = @intCast(line.idx), .col = @intCast(col), .freq = ch },
                );
            }
        }
        res.antennas = try antennas.toOwnedSlice();
        return res;
    }
};

test "parse_input" {
    const expectEq = std.testing.expectEqual;
    const expectDeq = std.testing.expectEqualDeep;
    const a = std.testing.allocator;
    var res = try City.init_from_input(a,
        \\............
        \\........0...
        \\.....r......
    );
    defer res.deinit();
    try expectEq(3, res.height);
    try expectEq(12, res.width);
    try expectDeq(
        &.{
            Antenna{ .row = 1, .col = 8, .freq = '0' },
            Antenna{ .row = 2, .col = 5, .freq = 'r' },
        },
        res.antennas,
    );
}

fn intCast32(number: anytype) i32 {
    return @as(i32, @intCast(number));
}

fn count_antinodes(city: *const City, comptime harmonics: bool) !u32 {
    const memreq = if (harmonics) 2 * 8 * 50 * 50 else 2048;
    var alc = std.heap.stackFallback(memreq, std.heap.page_allocator);
    var antinodes = std.AutoArrayHashMap(struct { u32, u32 }, void) //
        .init(alc.get());
    for (city.antennas) |a| {
        for (city.antennas) |b| {
            if (a.freq != b.freq) continue;
            if (a.row == b.row and a.col == b.col) continue;
            // project from a forwards over b
            const dr = intCast32(b.row) - intCast32(a.row);
            const dc = intCast32(b.col) - intCast32(a.col);
            std.debug.assert(dr != 0 or dc != 0);
            const rng_start = if (harmonics) 0 else 1;
            const rng_end = if (harmonics) 50 else 2;
            for (rng_start..rng_end) |stp| {
                const row = intCast32(b.row) + intCast32(stp) * dr;
                const col = intCast32(b.col) + intCast32(stp) * dc;
                if (row < 0 or row >= city.height or //
                    col < 0 or col >= city.width) break;
                dbg("{any} -> {any} -> {}, {}", .{ a, b, row, col });
                try antinodes.put(.{ @intCast(row), @intCast(col) }, {});
            }
        }
    }
    return @intCast(antinodes.count());
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
    const city = try City.init_from_input(a, input);

    const num_antinodes: u64 = try count_antinodes(&city, false);

    _ = try stdout.print(
        "The number of distinct positions with antinodes is {}\n",
        .{num_antinodes},
    );

    const num_antinodes_2: u64 = try count_antinodes(&city, true);

    _ = try stdout.print(
        "The number of distinct positions with antinodes is really {}\n",
        .{num_antinodes_2},
    );

    try bw.flush();
}
