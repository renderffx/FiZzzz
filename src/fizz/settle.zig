const types = @import("./types.zig");
const mutants = @import("./mutants.zig");
const req_mod = @import("./req.zig");

pub fn finishSeg(self: *req_mod.Req, sid: u32) void {
    if (self.dest.dead or self.aborted) return;
    if (sid >= self.segs.items.len) return;
    self.segs.items[sid].status = types.COMPLETED;
    const owner = self.segs.items[sid].owner;
    if (owner >= self.bounds.items.len) return;
    const b = &self.bounds.items[owner];
    if (b.pending_tasks > 0) b.pending_tasks -= 1;
    if (b.pending_tasks == 0 and b.status == types.PENDING) self.completeBound(owner);
}

pub fn completeBound(self: *req_mod.Req, bid: u32) void {
    if (self.dest.dead or self.aborted) return;
    if (bid >= self.bounds.items.len) return;
    const b = &self.bounds.items[bid];
    if (b.status != types.PENDING) return;
    if (b.parent_flushed and !mutants.Flags.ALWAYS_ABSORB) {
        self.emitReveal(bid);
    } else if (mutants.Flags.ALWAYS_RC) {
        self.emitReveal(bid);
    } else if (b.parent) |pid| {
        const child_root = b.root_seg;
        const parent_root = self.bounds.items[pid].root_seg;
        // Guard: parent already absorbed this child (legs row re-applied
        // after child COMPLETED). Without this the legs bytes emit twice:
        // once absorbed in the parent, once revealed with the child.
        if (self.segs.items[child_root].status == types.COMPLETED) return;
        self.segs.items[parent_root].html.appendSlice(self.segs.items[child_root].html.items) catch return;
        b.status = types.COMPLETED;
        self.segs.items[child_root].status = types.COMPLETED;
    } else {
        b.status = types.COMPLETED;
    }
}
