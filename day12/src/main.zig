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

    const garden = try utils.loadGridFromFile(a, infile);

    var all_crops = std.AutoArrayHashMap(utils.grid.Pos, void).init(a);
    var total_price: usize = 0;

    var position_iterator = garden.allPositions();
    while (position_iterator.next()) |p| {
        if (all_crops.contains(p)) continue;
        const region = try floodfill(a, garden, p);
        total_price += region.fence_price;
        for (region.positions.items) |region_pos| try all_crops.put(region_pos, {});
        region.positions.deinit();
    }

    _ = try stdout.print("The price is {}\n", .{total_price});

    try bw.flush();
}

fn floodfill(
    a: std.mem.Allocator,
    garden: utils.Grid(u8),
    pos: utils.grid.Pos,
) !struct { fence_price: usize, positions: std.ArrayList(utils.grid.Pos) } {
    var region = std.AutoArrayHashMap(utils.grid.Pos, void).init(a);
    defer region.deinit();
    var circumference: usize = 0;
    const crop = garden.atPos(pos).?;
    var wrk = std.ArrayList(utils.grid.Pos).init(a);
    try wrk.append(pos);
    try region.put(pos, {});
    while (wrk.items.len > 0) {
        const p = wrk.pop();
        for (garden.cardinalNeighbourPositions(p)) |n| {
            if (n == null or garden.atPos(n.?) != crop) {
                circumference += 1;
                continue;
            }
            if (region.contains(n.?)) continue;
            try region.put(n.?, {});
            try wrk.append(n.?);
        }
    }
    // reuse wrk for result
    wrk.clearRetainingCapacity();
    try wrk.appendSlice(region.keys());
    return .{ .fence_price = circumference * wrk.items.len, .positions = wrk };
}
