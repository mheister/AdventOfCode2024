const std = @import("std");

const dbg = std.debug.print;

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

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var line = std.ArrayList(u8).init(a);
    defer line.deinit();

    const writer = line.writer();
    var line_no: usize = 0;
    var safe_cnt_p1: usize = 0;
    var safe_cnt_p2: usize = 0;
    while (reader.streamUntilDelimiter(writer, '\n', null)) {
        defer line.clearRetainingCapacity();
        line_no += 1;
        var report = std.ArrayList(i32).init(a);
        defer report.deinit();
        var it = std.mem.splitScalar(u8, line.items, ' ');
        while (it.next()) |x| {
            try report.append(try std.fmt.parseInt(i32, x, 10));
        }
        if (is_safe_report(&report, false)) safe_cnt_p1 += 1;
        if (is_safe_report(&report, true)) safe_cnt_p2 += 1;
    } else |err| switch (err) {
        error.EndOfStream => { // end of file
            if (line.items.len > 0) {
                line_no += 1;
                dbg("LASTLINE {d}--{s}\n", .{ line_no, line.items });
            }
        },
        else => return err,
    }

    _ = try stdout.print("The number of safe paths is {}\n", .{safe_cnt_p1});
    _ = try stdout.print("The number of safe paths is really (part two) {}\n", .{safe_cnt_p2});

    try bw.flush();
}

fn is_safe_report(report: *std.ArrayList(i32), allowskip: bool) bool {
    if (is_safe_report_noskips(report.items)) {
        return true;
    }
    if (allowskip) {
        for (0..report.items.len) |idx| {
            const a = report.orderedRemove(idx);
            if (is_safe_report_noskips(report.items)) {
                return true;
            }
            report.insert(idx, a) catch {
                dbg("should not happen", .{});
            };
        }
    }
    return false;
}

fn is_safe_report_noskips(report: []i32) bool {
    if (report.len == 0) {
        return true;
    }
    const Dir = enum { up, par, down };
    var left = report[0];
    var dir: Dir = .par;
    for (report[1..]) |right| {
        var newdir: Dir = .par;
        if (left < right) newdir = .up;
        if (left > right) newdir = .down;
        if (dir != .par and dir != newdir or
            @abs(left - right) == 0 or
            @abs(left - right) > 3)
        {
            // dbg("UNSAFE {any}\n", .{report});
            return false;
        }
        left = right;
        dir = newdir;
    }
    return true;
}
