const std = @import("std");

pub const Class = enum { Absorb, Reveal, RX, Silent };

pub const Term = struct {
    kind: u8,
    row: u32,
};

pub const Expect = struct {
    term: usize,
    class: Class,
    id: u32,
};

pub fn bidOf(t: Term) u32 {
    return if (t.kind == 2) t.row * 2 + 1 else t.row * 2;
}
