const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const sched = @import("sched");
const tape = @import("tape");
const cells = @import("./cells.zig");

pub const Scene = struct {
    req: *fizz.Req,
    table: *sched.Table,
    rows: []u32,
    legs: []u32,
    abort_after: usize = 0,
    terminals_done: usize = 0,

    pub fn build(alloc: std.mem.Allocator, req: *fizz.Req, table: *sched.Table, abort_after: usize) !Scene {
        try req.root();
        const rows = try alloc.alloc(u32, tape.N_ROWS);
        errdefer alloc.free(rows);
        const legs = try alloc.alloc(u32, tape.N_ROWS);
        for (legs) |*l| l.* = std.math.maxInt(u32);
        const sc = Scene{ .req = req, .table = table, .rows = rows, .legs = legs, .abort_after = abort_after };

        const root_seg: u32 = 0;
        {
            const r0 = &req.segs.items[root_seg].html;
            try r0.appendSlice("<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"color-scheme\" content=\"light only\"><style>");
            try r0.appendSlice(@embedFile("../blotter.css"));
            try r0.appendSlice("</style></head><body>");
            try r0.appendSlice(@embedFile("../shared/nav.html"));
            try r0.appendSlice(@embedFile("../shared/glossary.html"));
            try r0.appendSlice("<table><caption>FiZz blotter</caption>");
            try r0.appendSlice("<thead><tr><th>row</th><th>sym</th><th>px</th><th>note</th></tr></thead><tbody>");
        }

        var r: u32 = 1;
        while (r <= tape.N_ROWS) : (r += 1) {
            const rb = try req.addBound(0, root_seg, 1);
            rows[r - 1] = rb;
        }
        r = 1;
        while (r <= tape.N_ROWS) : (r += 1) {
            if (tape.hasLegs(r)) {
                legs[r - 1] = try req.addBound(rows[r - 1], req.bounds.items[rows[r - 1]].root_seg, 0);
            }
        }
        r = 1;
        while (r <= tape.N_ROWS) : (r += 1) {
            const fb = cells.fallbackRow(alloc, r);
            defer alloc.free(fb);
            req.hole(root_seg, rows[r - 1], fb);
        }
        {
            const r0b = &req.segs.items[root_seg].html;
            try r0b.appendSlice("</tbody></table>");
            try r0b.appendSlice("<script>");
            try r0b.appendSlice(@embedFile("../boot.js"));
            try r0b.appendSlice("</script>");
        }
        return sc;
    }

    pub fn captureShell(alloc: std.mem.Allocator, sc: Scene) !fizz.Snap {
        sc.req.flushRoot(0);
        return fizz.capture(alloc, sc.req);
    }

    pub fn run(self: *Scene, alloc: std.mem.Allocator) void {
        const order = tape.buildOrder(alloc);
        defer alloc.free(order);
        _ = @import("./terms.zig").applyTerm(self, alloc, order[0]);
        self.req.flushRoot(0);
        var i: usize = 1;
        while (i < order.len) : (i += 1) {
            if (!@import("./terms.zig").applyTerm(self, alloc, order[i])) break;
        }
    }

    pub fn runResume(self: *Scene, alloc: std.mem.Allocator) void {
        const order = tape.buildOrder(alloc);
        defer alloc.free(order);
        for (order) |t| if (!@import("./terms.zig").applyTerm(self, alloc, t)) break;
    }
};
