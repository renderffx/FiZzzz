const std = @import("std");

// Blotter tape: deterministic terminal order that must hold.
// N=30 rows. Legs on 14 and 28. Fails on 7 and 19.
// Order yields: 14.legs Absorb, 14 Reveal, 7/19 RX, 28 Reveal, 28.legs Reveal.
pub const N_ROWS: u32 = 30;
pub const LEG_A: u32 = 14;
pub const LEG_B: u32 = 28;
pub const FAIL_A: u32 = 7;
pub const FAIL_B: u32 = 19;

pub const Term = struct {
    kind: u8, // 0=row ok, 1=row fail, 2=legs ok
    row: u32,
};

pub fn hasLegs(row: u32) bool {
    return row == LEG_A or row == LEG_B;
}

pub fn isFail(row: u32) bool {
    return row == FAIL_A or row == FAIL_B;
}

// Wake order: legs14, fail7, fail19, row14, row28, legs28, then all other rows asc.
pub fn buildOrder(alloc: std.mem.Allocator) []Term {
    var list = std.ArrayList(Term).init(alloc);
    list.append(.{ .kind = 2, .row = LEG_A }) catch {};
    list.append(.{ .kind = 1, .row = FAIL_A }) catch {};
    list.append(.{ .kind = 1, .row = FAIL_B }) catch {};
    list.append(.{ .kind = 0, .row = LEG_A }) catch {};
    list.append(.{ .kind = 0, .row = LEG_B }) catch {};
    list.append(.{ .kind = 2, .row = LEG_B }) catch {};
    var r: u32 = 1;
    while (r <= N_ROWS) : (r += 1) {
        if (r == LEG_A or r == LEG_B or r == FAIL_A or r == FAIL_B) continue;
        list.append(.{ .kind = 0, .row = r }) catch {};
    }
    return list.toOwnedSlice() catch @as([]Term, @constCast(&[_]Term{}));
}

pub const Class = enum { Absorb, Reveal, RX, Silent };
