const std = @import("std");
const types = @import("./types.zig");

pub fn expected(alloc: std.mem.Allocator, order: []const types.Term, abort_after: usize, root_flush_at: usize) []types.Expect {
    var out = std.ArrayList(types.Expect).init(alloc);
    var done: usize = 0;
    for (order, 0..) |t, i| {
        const id = types.bidOf(t);
        if (abort_after > 0 and done >= abort_after) {
            out.append(.{ .term = i, .class = .Silent, .id = id }) catch {};
            continue;
        }
        if (t.kind == 1) {
            if (i < root_flush_at) {
                out.append(.{ .term = i, .class = .Silent, .id = id }) catch {};
            } else {
                out.append(.{ .term = i, .class = .RX, .id = id }) catch {};
            }
        } else if (t.kind == 2) {
            var row_idx: ?usize = null;
            for (order, 0..) |o, j| {
                if (o.row == t.row and o.kind != 2) {
                    row_idx = j;
                    break;
                }
            }
            if (row_idx) |ri| {
                if (i < ri) {
                    out.append(.{ .term = i, .class = .Absorb, .id = id }) catch {};
                } else {
                    out.append(.{ .term = i, .class = .Reveal, .id = id }) catch {};
                }
            } else {
                out.append(.{ .term = i, .class = .Reveal, .id = id }) catch {};
            }
        } else {
            if (i < root_flush_at) {
                out.append(.{ .term = i, .class = .Absorb, .id = id }) catch return out.toOwnedSlice() catch @as([]types.Expect, @constCast(&[_]types.Expect{}));
            } else {
                out.append(.{ .term = i, .class = .Reveal, .id = id }) catch {};
            }
        }
        done += 1;
    }
    return out.toOwnedSlice() catch @as([]types.Expect, @constCast(&[_]types.Expect{}));
}
