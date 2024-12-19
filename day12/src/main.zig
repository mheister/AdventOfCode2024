const std = @import("std");
const utils = @import("utils");

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

    const garden = try utils.loadGridFromFileWithBorder(a, infile, '~');
    garden.log();

    var all_crops = std.AutoArrayHashMap(utils.grid.Pos, void).init(a);
    var total_price: usize = 0;
    var total_price_discounted: usize = 0;

    var position_iterator = garden.allPositions();
    while (position_iterator.next()) |p| {
        if (garden.atPos(p) == '~') continue; // border
        if (all_crops.contains(p)) continue;
        const region = try floodfill(a, garden, p);
        total_price += region.fence_price;
        total_price_discounted += region.fence_price_discounted;
        for (region.positions.items) |region_pos| try all_crops.put(region_pos, {});
        region.positions.deinit();
    }

    _ = try stdout.print(
        "The price is {}, with bulk discount {}\n",
        .{ total_price, total_price_discounted },
    );

    try bw.flush();
}

const CardinalDirection = enum { l, u, r, d };
const Cardinals = [4]CardinalDirection{ .l, .u, .r, .d };

fn floodfill(
    a: std.mem.Allocator,
    garden: utils.Grid(u8),
    pos: utils.grid.Pos,
) !struct {
    fence_price: usize,
    fence_price_discounted: usize,
    positions: std.ArrayList(utils.grid.Pos),
} {
    var region = std.AutoArrayHashMap(utils.grid.Pos, void).init(a);
    defer region.deinit();
    var side_tracker = SideTracker.init(a);
    defer side_tracker.deinit();
    const crop = garden.atPos(pos).?;
    var wrk = std.ArrayList(utils.grid.Pos).init(a);
    try wrk.append(pos);
    try region.put(pos, {});
    while (wrk.items.len > 0) {
        const p = wrk.pop();
        for (garden.cardinalNeighbourPositions(p), Cardinals) |maybe_n, dir| {
            const n = maybe_n orelse unreachable; // working with a bordered map
            if (garden.atPos(n) != crop) {
                try side_tracker.put_neighbouring_pos(n, dir);
                continue;
            }
            if (region.contains(n)) continue;
            try region.put(n, {});
            try wrk.append(n);
        }
    }
    // reuse wrk for result
    wrk.clearRetainingCapacity();
    try wrk.appendSlice(region.keys());
    const circumference = side_tracker.get_circumference();
    const sides = side_tracker.get_side_count();
    std.log.debug(
        "Region {c}: area {}, circumference {}, sides {}",
        .{ crop, wrk.items.len, circumference, sides },
    );
    return .{
        .fence_price = circumference * wrk.items.len,
        .fence_price_discounted = sides * wrk.items.len,
        .positions = wrk,
    };
}

const SideTracker = struct {
    const BorderingPosition = struct {
        dir: CardinalDirection,
        // column for left and right bordering positions,
        // row for up and down
        idx: usize,
    };

    // map l/r bordering positions to a list of rows, and
    // u/d bordering positions to a list of columns, respectively
    const SideMap = std.AutoArrayHashMap(BorderingPosition, std.ArrayList(usize));

    bordering_positions: SideMap,
    circumference: usize = 0,
    allocator: std.mem.Allocator,

    fn init(a: std.mem.Allocator) @This() {
        return .{
            .bordering_positions = SideMap.init(a),
            .allocator = a,
        };
    }

    fn deinit(self: *@This()) void {
        for (self.bordering_positions.values()) |l| l.deinit();
        self.bordering_positions.deinit();
    }

    fn put_neighbouring_pos(
        self: *@This(),
        pos: utils.grid.Pos,
        dir: CardinalDirection,
    ) !void {
        self.circumference += 1;
        const kv_entry = switch (dir) {
            .l, .r => .{ pos.col, pos.row },
            .u, .d => .{ pos.row, pos.col },
        };
        const entry = try self.bordering_positions.getOrPut(
            .{ .dir = dir, .idx = kv_entry[0] },
        );
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(usize).init(self.allocator);
        }
        try entry.value_ptr.append(kv_entry[1]);
    }

    fn get_circumference(self: *const @This()) usize {
        return self.circumference;
    }

    fn get_side_count(self: *@This()) usize {
        var res: usize = 0;
        for (self.bordering_positions.values()) |vals| {
            std.mem.sort(usize, vals.items, {}, comptime std.sort.asc(usize));
            res += 1; // there will be at least one entry
            var rhs = vals.items[0];
            for (vals.items[1..]) |lhs| {
                if (lhs - rhs > 1) res += 1; // new side with every gap
                rhs = lhs;
            }
        }
        return res;
    }
};
