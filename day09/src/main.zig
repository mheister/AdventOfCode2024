const std = @import("std");
const mcha = @import("mecha");

fn dbg(obj: anytype) @TypeOf(obj) {
    std.log.warn("{any}", .{obj});
    return obj;
}

const File = struct {
    id: usize,
    len: u32, // length in blocks
    space_after: u32,
};

fn parse_input(a: std.mem.Allocator, input: []const u8) !std.ArrayList(File) {
    var fs = std.ArrayList(File).init(a);
    var entry_it = std.mem.window(u8, input, 2, 2);
    var id: usize = 0;
    while (entry_it.next()) |entry| {
        if (entry[0] == '\n') break;
        const space = if (entry.len == 2 and entry[1] != '\n') (entry[1] - '0') else 0;
        try fs.append(.{
            .id = id,
            .len = entry[0] - '0',
            .space_after = space,
        });
        id += 1;
    }
    return fs;
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const input = "12345"; // 0..111....22222
    const a = std.testing.allocator;
    const fs = try parse_input(a, input);
    try expectEq(3, fs.items.len);
    try expectEq(0, fs.items[0].id);
    // try expectEq(0, fs.items[0].pos);
    try expectEq(1, fs.items[0].len);
    try expectEq(2, fs.items[0].space_after);
    try expectEq(1, fs.items[1].id);
    // try expectEq(3, fs.items[1].pos);
    try expectEq(3, fs.items[1].len);
    try expectEq(4, fs.items[1].space_after);
    try expectEq(2, fs.items[2].id);
    // try expectEq(10, fs.items[2].pos);
    try expectEq(5, fs.items[2].len);
    try expectEq(0, fs.items[2].space_after);
    fs.deinit();
}

fn fs_compact(fs: *std.ArrayList(File)) !void {
    if (fs.items.len == 0) return;
    op: while (true) {
        for (0..fs.items.len - 1) |insert_after_idx| {
            if (fs.items[insert_after_idx].space_after == 0) continue;
            const blks_to_move = @min(
                fs.items[insert_after_idx].space_after,
                fs.items[fs.items.len - 1].len,
            );
            fs.items[fs.items.len - 1].space_after += blks_to_move;
            fs.items[fs.items.len - 1].len -= blks_to_move;
            try fs.insert(insert_after_idx + 1, .{
                .id = fs.items[fs.items.len - 1].id,
                .len = blks_to_move,
                .space_after = fs.items[insert_after_idx].space_after - blks_to_move,
            });
            fs.items[insert_after_idx].space_after = 0;
            if (fs.items[fs.items.len - 1].len == 0) {
                const space = fs.pop().space_after;
                fs.items[fs.items.len - 1].space_after += space;
            }
            continue :op;
        }
        break;
    }
}

test "fs_compact" {
    const expectEq = std.testing.expectEqual;

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 11, .len = 2, .space_after = 10 });
        try fs.append(.{ .id = 22, .len = 5, .space_after = 10 });
        try fs_compact(&fs);

        try expectEq(2, fs.items.len);
        try expectEq(11, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(22, fs.items[1].id);
        try expectEq(20, fs.items[1].space_after);
    }

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 0, .len = 2, .space_after = 2 });
        try fs.append(.{ .id = 1, .len = 2, .space_after = 2 });
        try fs.append(.{ .id = 2, .len = 2, .space_after = 2 });
        try fs_compact(&fs);

        try expectEq(3, fs.items.len);
        try expectEq(0, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(2, fs.items[1].id);
        try expectEq(0, fs.items[1].space_after);
        try expectEq(1, fs.items[2].id);
        try expectEq(6, fs.items[2].space_after);
    }

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 0, .len = 2, .space_after = 2 });
        try fs.append(.{ .id = 1, .len = 2, .space_after = 2 });
        try fs.append(.{ .id = 2, .len = 4, .space_after = 0 });
        try fs_compact(&fs);

        try expectEq(4, fs.items.len);
        try expectEq(0, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(2, fs.items[1].id);
        try expectEq(0, fs.items[1].space_after);
        try expectEq(1, fs.items[2].id);
        try expectEq(0, fs.items[2].space_after);
        try expectEq(2, fs.items[3].id);
        try expectEq(4, fs.items[3].space_after);
    }
}

fn fs_compact_nofrag(fs: *std.ArrayList(File)) !void {
    if (fs.items.len == 0) return;
    var to_move_id = fs.items[fs.items.len - 1].id;
    op: while (to_move_id > 0) : (to_move_id -= 1) {
        var to_move_idx = for (0.., fs.items) |idx, it| {
            if (it.id == to_move_id) break idx;
        } else continue;
        for (0..to_move_idx) |insert_after_idx| {
            if (fs.items[insert_after_idx].space_after < //
                fs.items[to_move_idx].len) continue;
            try fs.insert(insert_after_idx + 1, .{
                .id = fs.items[to_move_idx].id,
                .len = fs.items[to_move_idx].len,
                .space_after = //
                fs.items[insert_after_idx].space_after - fs.items[to_move_idx].len,
            });
            to_move_idx += 1;
            fs.items[insert_after_idx].space_after = 0;
            fs.items[to_move_idx - 1].space_after += //
                fs.items[to_move_idx].space_after + fs.items[to_move_idx].len;
            _ = fs.orderedRemove(to_move_idx);
            continue :op;
        }
    }
}

test "fs_compact_nofrag" {
    const expectEq = std.testing.expectEqual;

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 11, .len = 2, .space_after = 10 });
        try fs.append(.{ .id = 22, .len = 5, .space_after = 10 });
        try fs_compact_nofrag(&fs);

        try expectEq(2, fs.items.len);
        try expectEq(11, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(22, fs.items[1].id);
        try expectEq(20, fs.items[1].space_after);
    }

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 11, .len = 1, .space_after = 1 });
        try fs.append(.{ .id = 22, .len = 10, .space_after = 10 });
        try fs.append(.{ .id = 33, .len = 1, .space_after = 1 });
        try fs_compact_nofrag(&fs);

        try expectEq(3, fs.items.len);
        try expectEq(11, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(33, fs.items[1].id);
        try expectEq(0, fs.items[1].space_after);
        try expectEq(22, fs.items[2].id);
        try expectEq(12, fs.items[2].space_after);
    }

    {
        var fs = std.ArrayList(File).init(std.testing.allocator);
        defer fs.deinit();
        try fs.append(.{ .id = 1, .len = 1, .space_after = 1 });
        try fs.append(.{ .id = 2, .len = 10, .space_after = 10 });
        try fs.append(.{ .id = 3, .len = 10, .space_after = 10 });
        try fs.append(.{ .id = 4, .len = 1, .space_after = 1 });
        try fs_compact_nofrag(&fs);
        _ = dbg(fs.items);

        try expectEq(4, fs.items.len);
        try expectEq(1, fs.items[0].id);
        try expectEq(0, fs.items[0].space_after);
        try expectEq(4, fs.items[1].id);
        try expectEq(0, fs.items[1].space_after);
        try expectEq(2, fs.items[2].id);
        try expectEq(0, fs.items[2].space_after);
        try expectEq(3, fs.items[3].id);
        try expectEq(22, fs.items[3].space_after);
    }
}

fn fs_print(fs: std.ArrayList(File), writer: anytype) !void {
    var pos: usize = 0;
    for (fs.items) |file| {
        if (pos > 100) break;
        for (pos..pos + file.len) |_| {
            try std.fmt.formatInt(file.id, 10, .upper, .{}, writer);
        }
        pos += file.len;
        for (pos..pos + file.space_after) |_| {
            _ = try writer.write(".");
        }
        pos += file.space_after;
    }
    _ = try writer.write("\n");
}

fn fs_checksum(fs: std.ArrayList(File)) usize {
    var chksum: usize = 0;
    var pos: usize = 0;
    for (fs.items) |file| {
        for (pos..pos + file.len) |blkpos| {
            chksum += file.id * blkpos;
        }
        pos += file.len + file.space_after;
    }
    return chksum;
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
    var fs = try parse_input(a, input);
    defer fs.deinit();

    std.log.debug("Compacting Filesystem", .{});
    try fs_compact(&fs);

    try fs_print(fs, stdout);

    std.log.debug("Calculatig checksum", .{});
    const sum: u64 = fs_checksum(fs);
    _ = try stdout.print("The checksum is {}\n", .{sum});

    fs = try parse_input(a, input);
    std.log.debug("Compacting Filesystem w/o Fragmentation", .{});
    try fs_compact_nofrag(&fs);

    try fs_print(fs, stdout);

    std.log.debug("Calculatig checksum again", .{});
    const sum2: u64 = fs_checksum(fs);
    _ = try stdout.print("The checksum is {}\n", .{sum2});
    try bw.flush();
}
