const std = @import("std");

// From dest mem join: list of {RC|RX, id}. No RC after RX for same id.
pub const Ev = struct {
    kind: u8, // 0=RC, 1=RX
    id: u32,
};

fn parseNum(s: []const u8) ?u32 {
    var v: u32 = 0;
    var any = false;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + (c - '0');
        any = true;
    }
    return if (any) v else null;
}

pub fn parse(alloc: std.mem.Allocator, wire: []const u8) []Ev {
    var out = std.ArrayList(Ev).init(alloc);
    var i: usize = 0;
    while (i < wire.len) {
        if (i + 4 <= wire.len and std.mem.eql(u8, wire[i .. i + 4], "$RC(")) {
            // $RC("B:N","S:N")
            if (std.mem.indexOf(u8, wire[i..], "B:")) |bi| {
                const s = i + bi + 2;
                var e = s;
                while (e < wire.len and wire[e] >= '0' and wire[e] <= '9') : (e += 1) {}
                if (parseNum(wire[s..e])) |id| out.append(.{ .kind = 0, .id = id }) catch {};
                i = e;
                continue;
            }
            i += 4;
        } else if (i + 4 <= wire.len and std.mem.eql(u8, wire[i .. i + 4], "$RX(")) {
            if (std.mem.indexOf(u8, wire[i..], "B:")) |bi| {
                const s = i + bi + 2;
                var e = s;
                while (e < wire.len and wire[e] >= '0' and wire[e] <= '9') : (e += 1) {}
                if (parseNum(wire[s..e])) |id| out.append(.{ .kind = 1, .id = id }) catch {};
                i = e;
                continue;
            }
            i += 4;
        } else {
            i += 1;
        }
    }
    return out.toOwnedSlice() catch @as([]Ev, @constCast(&[_]Ev{}));
}

// Returns true if wire violates "no RC after RX for same id".
pub fn hasRcAfterRx(evs: []const Ev) bool {
    var i: usize = 0;
    while (i < evs.len) : (i += 1) {
        if (evs[i].kind != 1) continue;
        var j = i + 1;
        while (j < evs.len) : (j += 1) {
            if (evs[j].kind == 0 and evs[j].id == evs[i].id) return true;
        }
    }
    return false;
}
