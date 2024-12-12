const std = @import("std");

fn EnumeratingIterator(comptime TIter: type) type {
    return struct {
        idx: usize,
        inner: TIter,
        const TOpt = @typeInfo(@TypeOf(TIter.next)).@"fn".return_type orelse ?void;
        const T = std.meta.Child(TOpt);
        pub inline fn next(self: *@This()) ?struct { idx: usize, val: T } {
            const idx = self.idx;
            const val = self.inner.next() orelse return null;
            self.idx += 1;
            return .{ .idx = idx, .val = val };
        }
    };
}

pub fn enumerate(iterator: anytype) EnumeratingIterator(@TypeOf(iterator)) {
    return EnumeratingIterator(@TypeOf(iterator)){ .idx = 0, .inner = iterator };
}
