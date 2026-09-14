const std = @import("std");
const oracle = @import("oracle");
const parse_wire = @import("parse_wire");
const fam = @import("./fam.zig");
const run = @import("./run.zig");

pub fn checkCase(alloc: std.mem.Allocator, n: u32, order: []const fam.FamTerm, fails: []const u32, abort_at: usize, max_write: usize) !?[]u8 {
    const r = try run.runCase(alloc, n, order, fails, abort_at, max_write);
    defer alloc.free(r.wire);
    defer alloc.free(r.evs);
    var oterms = std.ArrayList(oracle.Term).init(alloc);
    defer oterms.deinit();
    for (order) |t| {
        var k = t.kind;
        if (k == 0 and fam.isFail(t.row, fails)) k = 1;
        try oterms.append(.{ .kind = k, .row = t.row });
    }
    const root_flush_at: usize = if (order.len > 0 and order[0].kind == 2) 1 else 0;
    const exp = oracle.expected(alloc, oterms.items, abort_at, root_flush_at);
    defer alloc.free(exp);
    var want_rc: usize = 0;
    var want_rx: usize = 0;
    for (exp) |e| {
        if (e.class == .Reveal) want_rc += 1;
        if (e.class == .RX) want_rx += 1;
    }
    var got_rc: usize = 0;
    var got_rx: usize = 0;
    for (r.evs) |e| {
        if (e.kind == 0) got_rc += 1 else got_rx += 1;
    }
    if (parse_wire.hasRcAfterRx(r.evs)) {
        return try std.fmt.allocPrint(alloc, "RC-after-RX n={d} abort={d} mw={d}", .{ n, abort_at, max_write });
    }
    if (got_rc != want_rc or got_rx != want_rx) {
        var ob = std.ArrayList(u8).init(alloc);
        defer ob.deinit();
        for (order, 0..) |t, idx| {
            var eb: [48]u8 = undefined;
            const es = std.fmt.bufPrint(&eb, "({d},{d})", .{ t.kind, t.row }) catch "?";
            ob.appendSlice(es) catch {};
            if (idx + 1 < order.len) ob.appendSlice(" ") catch {};
        }
        return try std.fmt.allocPrint(alloc, "count mismatch n={d} abort={d} mw={d} want RC={d} RX={d} got RC={d} RX={d} order=[{s}] evs={d}", .{ n, abort_at, max_write, want_rc, want_rx, got_rc, got_rx, ob.items, r.evs.len });
    }
    return null;
}

pub fn permute(alloc: std.mem.Allocator, items: []fam.FamTerm, k: usize, n: u32, fails: []const u32, abort_at: usize, mw: usize) !?[]u8 {
    if (k == items.len) {
        if (try checkCase(alloc, n, items, fails, abort_at, mw)) |ce| return ce;
        return null;
    }
    var i = k;
    while (i < items.len) : (i += 1) {
        const t = items[k];
        items[k] = items[i];
        items[i] = t;
        if (try permute(alloc, items, k + 1, n, fails, abort_at, mw)) |ce| return ce;
        const t2 = items[k];
        items[k] = items[i];
        items[i] = t2;
    }
    return null;
}
