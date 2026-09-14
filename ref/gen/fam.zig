const std = @import("std");

pub const FamTerm = struct { kind: u8, row: u32 };

pub fn buildFam(alloc: std.mem.Allocator, n: u32) []FamTerm {
    var l = std.ArrayList(FamTerm).init(alloc);
    var r: u32 = 1;
    while (r <= n) : (r += 1) {
        l.append(.{ .kind = 0, .row = r }) catch {};
    }
    if (n >= 4) {
        l.append(.{ .kind = 2, .row = 2 }) catch {};
        l.append(.{ .kind = 2, .row = 3 }) catch {};
    }
    return l.toOwnedSlice() catch @as([]FamTerm, @constCast(&[_]FamTerm{}));
}

pub fn isFail(row: u32, fails: []const u32) bool {
    for (fails) |f| if (f == row) return true;
    return false;
}
