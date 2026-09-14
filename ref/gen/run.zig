const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const sched = @import("sched");
const parse_wire = @import("parse_wire");
const fam = @import("./fam.zig");

pub const Ctx = struct {
    req: *fizz.Req,
    table: *sched.Table,
    rows: std.AutoHashMap(u32, u32),
    legs: std.AutoHashMap(u32, u32),
    alloc: std.mem.Allocator,
};

pub fn setup(alloc: std.mem.Allocator, dest: *Dest, n: u32, legs_rows: []const u32) !Ctx {
    var req = try alloc.create(fizz.Req);
    req.* = fizz.Req.init(alloc, dest);
    try req.root();
    const table = try alloc.create(sched.Table);
    table.* = sched.Table.init(alloc);
    var rows = std.AutoHashMap(u32, u32).init(alloc);
    var legs = std.AutoHashMap(u32, u32).init(alloc);
    const rseg: u32 = 0;
    var r: u32 = 1;
    while (r <= n) : (r += 1) {
        const rb = try req.addBound(0, rseg, 1);
        try rows.put(r, rb);
        for (legs_rows) |lr| {
            if (lr == r) {
                const lb = try req.addBound(rb, req.bounds.items[rb].root_seg, 1);
                try legs.put(r, lb);
            }
        }
        var fb: [64]u8 = undefined;
        const fs = try std.fmt.bufPrint(&fb, "<tr><td>{d}</td></tr>", .{r});
        req.hole(rseg, rb, fs);
    }
    return .{ .req = req, .table = table, .rows = rows, .legs = legs, .alloc = alloc };
}

pub fn teardown(c: *Ctx) void {
    c.rows.deinit();
    c.legs.deinit();
    c.table.deinit();
    c.alloc.destroy(c.table);
    c.req.deinit();
    c.alloc.destroy(c.req);
}

pub fn runCase(alloc: std.mem.Allocator, n: u32, order: []const fam.FamTerm, fails: []const u32, abort_at: usize, max_write: usize) !struct { evs: []parse_wire.Ev, wire: []u8 } {
    var dest = Dest.ofMem(alloc, max_write, 0);
    var ctx = try setup(alloc, &dest, n, &[_]u32{ 2, 3 });
    var idx: usize = 0;
    if (order.len > 0 and order[0].kind == 2) {
        const lb = ctx.legs.get(order[0].row).?;
        const seg = ctx.req.bounds.items[lb].root_seg;
        var cb: [32]u8 = undefined;
        const cs = try std.fmt.bufPrint(&cb, "<td>l{d}</td>", .{order[0].row});
        try ctx.req.segs.items[seg].html.appendSlice(cs);
        ctx.req.finishSeg(seg);
        idx = 1;
    }
    ctx.req.flushRoot(0);
    var done: usize = if (idx == 1) 1 else 0;
    while (idx < order.len) : (idx += 1) {
        if (abort_at > 0 and done >= abort_at) {
            ctx.table.abort(ctx.req);
            break;
        }
        const t = order[idx];
        if (t.kind == 1 or fam.isFail(t.row, fails)) {
            const bid = ctx.rows.get(t.row).?;
            ctx.req.failBound(bid, "D", "NAK", "s");
        } else if (t.kind == 2) {
            const lb = ctx.legs.get(t.row) orelse continue;
            const seg = ctx.req.bounds.items[lb].root_seg;
            var cb: [32]u8 = undefined;
            const cs = try std.fmt.bufPrint(&cb, "<td>l{d}</td>", .{t.row});
            try ctx.req.segs.items[seg].html.appendSlice(cs);
            ctx.req.finishSeg(seg);
        } else {
            const bid = ctx.rows.get(t.row).?;
            const seg = ctx.req.bounds.items[bid].root_seg;
            var cb: [64]u8 = undefined;
            const cs = try std.fmt.bufPrint(&cb, "<td>r{d}</td>", .{t.row});
            try ctx.req.segs.items[seg].html.appendSlice(cs);
            ctx.req.finishSeg(seg);
        }
        done += 1;
    }
    const wire = try alloc.dupe(u8, dest.join());
    const evs = parse_wire.parse(alloc, wire);
    dest.deinit();
    teardown(&ctx);
    return .{ .evs = evs, .wire = wire };
}
