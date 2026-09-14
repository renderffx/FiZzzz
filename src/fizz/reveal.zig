const html = @import("html");
const mutants = @import("./mutants.zig");
const req_mod = @import("./req.zig");

pub fn emitReveal(self: *req_mod.Req, bid: u32) void {
    if (self.dest.dead or self.aborted) return;
    if (bid >= self.bounds.items.len) return;
    const b = &self.bounds.items[bid];
    if (b.status != @import("./types.zig").PENDING) return;
    const child_root = b.root_seg;
    const primary = self.segs.items[child_root].html.items;
    self.tmp.clearRetainingCapacity();
    if (mutants.Flags.BARE_ROOT) {
        self.tmp.appendSlice("<tr id=\"S:") catch return;
        var nb2: [16]u8 = undefined;
        const ns2 = @import("std").fmt.bufPrint(&nb2, "{d}", .{bid}) catch return;
        self.tmp.appendSlice(ns2) catch return;
        self.tmp.appendSlice("\">") catch return;
        self.tmp.appendSlice(primary) catch return;
        self.tmp.appendSlice("</tr><script>$RC(\"B:") catch return;
        self.tmp.appendSlice(ns2) catch return;
        self.tmp.appendSlice("\",\"S:") catch return;
        self.tmp.appendSlice(ns2) catch return;
        self.tmp.appendSlice("\")</script>") catch return;
        self.dest.seg(self.tmp.items);
        b.status = @import("./types.zig").COMPLETED;
        self.segs.items[child_root].status = @import("./types.zig").FLUSHED;
        for (self.bounds.items) |*c| {
            if (c.parent) |pid| {
                if (pid == bid) c.parent_flushed = true;
            }
        }
        return;
    }
    self.tmp.appendSlice("<div hidden id=\"S:") catch return;
    var nb: [16]u8 = undefined;
    const ns = @import("std").fmt.bufPrint(&nb, "{d}", .{bid}) catch return;
    self.tmp.appendSlice(ns) catch return;
    self.tmp.appendSlice("\">") catch return;
    html.wrapInto(&self.tmp, html.kindFromU8(b.kind), primary);
    self.tmp.appendSlice("</div><script>$RC(\"B:") catch return;
    self.tmp.appendSlice(ns) catch return;
    self.tmp.appendSlice("\",\"S:") catch return;
    self.tmp.appendSlice(ns) catch return;
    self.tmp.appendSlice("\")</script>") catch return;
    self.dest.seg(self.tmp.items);
    b.status = @import("./types.zig").COMPLETED;
    self.segs.items[child_root].status = @import("./types.zig").FLUSHED;
    for (self.bounds.items) |*c| {
        if (c.parent) |pid| {
            if (pid == bid) c.parent_flushed = true;
        }
    }
}

pub fn flushRoot(self: *req_mod.Req, root_seg: u32) void {
    if (self.dest.dead or self.aborted) return;
    if (root_seg >= self.segs.items.len) return;
    self.dest.seg(self.segs.items[root_seg].html.items);
    self.segs.items[root_seg].status = @import("./types.zig").FLUSHED;
    const owner = self.segs.items[root_seg].owner;
    for (self.bounds.items) |*c| {
        if (c.parent) |pid| {
            if (pid == owner) c.parent_flushed = true;
        }
    }
}
