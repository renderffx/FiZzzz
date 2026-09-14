const std = @import("std");
const fizz = @import("fizz");
const flight = @import("flight");
const tape = @import("tape");
const cells = @import("./cells.zig");
const scene_mod = @import("./scene.zig");

pub fn applyTerm(self: *scene_mod.Scene, alloc: std.mem.Allocator, t: tape.Term) bool {
    if (self.abort_after > 0 and self.terminals_done >= self.abort_after) {
        self.table.abort(self.req);
        return false;
    }
    if (self.req.aborted or self.req.dest.dead) return false;
    if (t.kind == 1) {
        const bid = self.rows[t.row - 1];
        self.table.reject(t.row + 1000, "E digest", "NAK", "stack0");
        self.req.failBound(bid, "E digest", "NAK", "stack0");
        flight.push(self.req, 1, t.row + 1000, 'E', "{\"digest\":\"E digest\",\"msg\":\"NAK\"}") catch {};
    } else if (t.kind == 2) {
        const lb = self.legs[t.row - 1];
        const lh = cells.legsCells(alloc, t.row);
        defer alloc.free(lh);
        const seg = self.req.bounds.items[lb].root_seg;
        self.req.segs.items[seg].html.appendSlice(lh) catch {};
        self.req.finishSeg(seg);
        flight.push(self.req, 1, t.row + 2000, 'J', "{\"legs\":1}") catch {};
    } else {
        const bid = self.rows[t.row - 1];
        const seg = self.req.bounds.items[bid].root_seg;
        const poison = (t.row == 3);
        if (self.legs[t.row - 1] != std.math.maxInt(u32)) {
            const lb = self.legs[t.row - 1];
            if (self.req.bounds.items[lb].status == fizz.COMPLETED) {
                const lh = self.req.segs.items[self.req.bounds.items[lb].root_seg].html.items;
                self.req.segs.items[seg].html.clearRetainingCapacity();
                const rowc = cells.rowCells(alloc, t.row, poison, lh);
                defer alloc.free(rowc);
                self.req.segs.items[seg].html.appendSlice(rowc) catch {};
                self.req.finishSeg(seg);
            } else {
                const head = cells.rowCells(alloc, t.row, poison, null);
                defer alloc.free(head);
                const close = "</td>";
                const prefix = head[0 .. head.len - close.len];
                self.req.segs.items[seg].html.appendSlice(prefix) catch {};
                var nb2: [16]u8 = undefined;
                const ns2 = std.fmt.bufPrint(&nb2, "{d}", .{t.row}) catch "0";
                var fb = std.ArrayList(u8).init(alloc);
                defer fb.deinit();
                fb.appendSlice("<span class=\"skel\">legs") catch {};
                fb.appendSlice(ns2) catch {};
                fb.appendSlice("</span>") catch {};
                self.req.hole(seg, lb, fb.items);
                self.req.segs.items[seg].html.appendSlice(close) catch {};
                self.req.finishSeg(seg);
            }
        } else {
            const rowc = cells.rowCells(alloc, t.row, poison, null);
            defer alloc.free(rowc);
            self.req.segs.items[seg].html.appendSlice(rowc) catch {};
            self.req.finishSeg(seg);
        }
        var nb: [128]u8 = undefined;
        const jp = std.fmt.bufPrint(&nb, "{{\"row\":{d},\"sym\":\"$1\",\"px\":\"$@1\"}}", .{t.row}) catch "{\"row\":0}";
        const cp = alloc.dupe(u8, jp) catch "{\"row\":0}";
        defer alloc.free(cp);
        flight.push(self.req, 1, t.row, 'J', cp) catch {};
    }
    self.terminals_done += 1;
    if (self.abort_after > 0 and self.terminals_done >= self.abort_after) {
        self.table.abort(self.req);
        return false;
    }
    return true;
}
