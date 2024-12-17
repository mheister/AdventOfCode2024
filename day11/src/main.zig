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
        condense(&stones);
    }

    _ = try stdout.print(
        "The number of stones after 25 blinks is {}\n",
        .{count_stones(stones.items)},
    );

    std.log.debug("stones25: {any}", .{stones.items});

    for (0..50) |_| {
        try blink(&stones);
        condense(&stones);
    }

    _ = try stdout.print(
        "The number of stones after 75 blinks is {}\n",
        .{count_stones(stones.items)},
    );

    try bw.flush();
}

const MultiStone = struct {
    engraving: u64,
    multiplicity: u64 = 1,
    fn less(_: void, a: MultiStone, b: MultiStone) bool {
        return std.sort.asc(u64)({}, a.engraving, b.engraving);
    }
};

fn count_stones(stones: []MultiStone) usize {
    var count: usize = 0;
    for (stones) |stone| {
        count += stone.multiplicity;
    }
    return count;
}

fn get_input(a: std.mem.Allocator) !std.ArrayList(MultiStone) {
    var res = std.ArrayList(MultiStone).init(a);
    for ([_]u64{ 3279, 998884, 1832781, 517, 8, 18864, 28, 0 }) |stone| {
        try res.append(.{ .engraving = stone });
    }
    return res;
}

fn blink(stones: *std.ArrayList(MultiStone)) !void {
    const max_len = 20;
    var buf: [max_len]u8 = undefined;

    for (0..stones.items.len) |stone_idx| {
        if (stones.items[stone_idx].engraving == 0) {
            stones.items[stone_idx].engraving = 1;
            continue;
        }
        const stone_str = try std.fmt.bufPrint(
            &buf,
            "{}",
            .{stones.items[stone_idx].engraving},
        );
        if (stone_str.len % 2 == 0) {
            stones.items[stone_idx].engraving =
                try std.fmt.parseInt(
                u64,
                stone_str[0 .. stone_str.len / 2],
                10,
            );
            try stones.append(.{
                .engraving = try std.fmt.parseInt(
                    u64,
                    stone_str[stone_str.len / 2 .. stone_str.len],
                    10,
                ),
                .multiplicity = stones.items[stone_idx].multiplicity,
            });
            continue;
        }
        stones.items[stone_idx].engraving *= 2024;
    }
}

test "blink_rule0" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(MultiStone).init(a);
    defer stones.deinit();
    try stones.append(.{ .engraving = 0 });
    try blink(&stones);
    try expectEq(1, stones.items.len);
    try expectEq(1, stones.items[0].engraving);
}

test "blink_rule1" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(MultiStone).init(a);
    defer stones.deinit();
    try stones.append(.{ .engraving = 12 });
    try blink(&stones);
    try expectEq(2, stones.items.len);
    try expectEq(1, stones.items[0].engraving);
    try expectEq(2, stones.items[1].engraving);
}

test "blink_rule2" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(MultiStone).init(a);
    defer stones.deinit();
    try stones.append(.{ .engraving = 1 });
    try blink(&stones);
    try expectEq(1, stones.items.len);
    try expectEq(2024, stones.items[0].engraving);
}

fn condense(stones: *std.ArrayList(MultiStone)) void {
    if (stones.items.len == 0) {
        return;
    }
    std.mem.sort(MultiStone, stones.items, {}, comptime MultiStone.less);
    var idx: usize = 0;
    while (idx < stones.items.len) : (idx += 1) {
        var stone = &stones.items[idx];
        const dup_idx = idx + 1;
        while (dup_idx < stones.items.len) {
            const dup = &stones.items[dup_idx];
            if (stone.engraving != dup.engraving) break;
            stone.multiplicity += stones.orderedRemove(dup_idx).multiplicity;
        }
    }
}

test "condense" {
    const expectEq = std.testing.expectEqual;
    const a = std.testing.allocator;
    var stones = std.ArrayList(MultiStone).init(a);
    defer stones.deinit();
    try stones.append(.{ .engraving = 1 });
    try stones.append(.{ .engraving = 2 });
    try stones.append(.{ .engraving = 1, .multiplicity = 2 });
    condense(&stones);
    try expectEq(2, stones.items.len);
    try expectEq(3, stones.items[0].multiplicity);
    try expectEq(1, stones.items[0].engraving);
    try expectEq(1, stones.items[1].multiplicity);
    try expectEq(2, stones.items[1].engraving);
}
