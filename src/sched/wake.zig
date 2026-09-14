const table = @import("./table.zig");

pub fn wakeOk(self: *table.Table, req: anytype, bid: u32, id: u32, h: []const u8) void {
    self.fulfill(id, h);
    const seg = req.bounds.items[bid].root_seg;
    req.segs.items[seg].html.appendSlice(h) catch {};
    req.finishSeg(seg);
}

pub fn wakeErr(self: *table.Table, req: anytype, bid: u32, id: u32, digest: []const u8, msg: []const u8, stack: []const u8) void {
    self.reject(id, digest, msg, stack);
    req.failBound(bid, digest, msg, stack);
}

pub fn abort(self: *table.Table, req: anytype) void {
    _ = self;
    req.aborted = true;
    req.dest.dead = true;
}
