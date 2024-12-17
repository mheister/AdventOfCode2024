const std = @import("std");

pub fn main() !void {
    const a = std.heap.page_allocator;

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var stones = try get_input(a);
    defer stones.deinit();

    for (0..25) |_| {
        try blink(&stones);
    }

    _ = try stdout.print(
        "The number of stones after 25 blinks is {}\n",
        .{stones.items.len},
    );

    for (0..50) |i| {
        std.log.debug("blink {}", .{i + 25});
        try blink(&stones);
    }

    _ = try stdout.print(
        "The number of stones after 75 blinks is {}\n",
        .{stones.items.len},
    );

    try bw.flush();
}

fn get_input(a: std.mem.Allocator) !std.ArrayList(u64) {
    var res = std.ArrayList(u64).init(a);
    try res.appendSlice(&.{ 3279, 998884, 1832781, 517, 8, 18864, 28, 0 });
    return res;
}

fn blink(stones: *std.ArrayList(u64)) !void {
    const max_len = 20;
    var buf: [max_len]u8 = undefined;

    for (0..stones.items.len) |stone_idx| {
        if (stones.items[stone_idx] == 0) {
            stones.items[stone_idx] = 1;
            continue;
        }
        const stone_str = try std.fmt.bufPrint(&buf, "{}", .{stones.items[stone_idx]});
        if (stone_str.len % 2 == 0) {
            stones.items[stone_idx] =
                try std.fmt.parseInt(
                u64,
                stone_str[0 .. stone_str.len / 2],
                10,
            );
            try stones.append(
                try std.fmt.parseInt(
                    u64,
                    stone_str[stone_str.len / 2 .. stone_str.len],
                    10,
                ),
            );
            continue;
        }
        stones.items[stone_idx] *= 2024;
    }
}

test "blink_rule0" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(u64).init(a);
    defer stones.deinit();
    try stones.append(0);
    try blink(&stones);
    try expectEq(1, stones.items.len);
    try expectEq(1, stones.items[0]);
}

test "blink_rule1" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(u64).init(a);
    defer stones.deinit();
    try stones.append(12);
    try blink(&stones);
    try expectEq(2, stones.items.len);
    try expectEq(1, stones.items[0]);
    try expectEq(2, stones.items[1]);
}

test "blink_rule2" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(u64).init(a);
    defer stones.deinit();
    try stones.append(1);
    try blink(&stones);
    try expectEq(1, stones.items.len);
    try expectEq(2024, stones.items[0]);
}
