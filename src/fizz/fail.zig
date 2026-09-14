const types = @import("./types.zig");
const mutants = @import("./mutants.zig");
const req_mod = @import("./req.zig");

pub fn failBound(self: *req_mod.Req, bid: u32, digest: []const u8, msg: []const u8, stack: []const u8) void {
    if (self.dest.dead or self.aborted) return;
    if (bid >= self.bounds.items.len) return;
    const b = &self.bounds.items[bid];
    if (b.status == types.CLIENT_RENDERED or b.status == types.COMPLETED) return;
    b.status = types.CLIENT_RENDERED;
    b.pending_tasks = 0;
    if (b.parent_flushed) {
        self.tmp.clearRetainingCapacity();
        self.tmp.appendSlice("<script>$RX(\"B:") catch return;
        var nb: [16]u8 = undefined;
        const ns = @import("std").fmt.bufPrint(&nb, "{d}", .{bid}) catch return;
        self.tmp.appendSlice(ns) catch return;
        self.tmp.appendSlice("\",\"") catch return;
        self.tmp.appendSlice(digest) catch return;
        self.tmp.appendSlice("\",\"") catch return;
        self.tmp.appendSlice(msg) catch return;
        self.tmp.appendSlice("\",\"") catch return;
        self.tmp.appendSlice(stack) catch return;
        self.tmp.appendSlice("\")</script>") catch return;
        self.dest.seg(self.tmp.items);
        if (mutants.Flags.RX_THEN_RC) {
            b.status = types.PENDING;
            self.emitReveal(bid);
            return;
        }
    }
}
