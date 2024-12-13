const std = @import("std");
const mcha = @import("mecha");

const FileSystemEntry = struct {
    file_id: ?usize, // given for files
    len: u32,
};

pub fn parse_input(a: std.mem.Allocator, input: []const u8) ![]FileSystemEntry {
    var fs = std.ArrayList(FileSystemEntry).init(a);
    var entry_it = std.mem.window(u8, input, 2, 2);
    var id: usize = 0;
    while (entry_it.next()) |entry| {
        if (entry[0] == '\n') break;
        try fs.append(.{ .file_id = id, .len = entry[0] - '0' });
        if (entry.len == 2) {
            if (entry[1] == '\n') break;
            try fs.append(.{ .file_id = null, .len = entry[1] - '0' });
        }
        id += 1;
    }
    return fs.toOwnedSlice();
}

test "parse input test" {
    const expectEq = std.testing.expectEqual;
    const input = "12345";
    const a = std.testing.allocator;
    const fs = try parse_input(a, input);
    try expectEq(fs.len, 5);
    try expectEq(0, fs[0].file_id);
    try expectEq(1, fs[0].len);
    try expectEq(null, fs[1].file_id);
    try expectEq(2, fs[1].len);
    try expectEq(1, fs[2].file_id);
    try expectEq(3, fs[2].len);
    try expectEq(null, fs[3].file_id);
    try expectEq(4, fs[3].len);
    try expectEq(2, fs[4].file_id);
    try expectEq(5, fs[4].len);
    a.free(fs);
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
    const fs = try parse_input(a, input);
    defer a.free(fs);

    std.log.debug("Calculatig checksum", .{});
    const sum: u64 = 0;
    _ = try stdout.print("The sum is {}\n", .{sum});

    try bw.flush();
}
