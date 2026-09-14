const types = @import("./types.zig");
const req_mod = @import("./req.zig");

pub fn root(self: *req_mod.Req) !void {
    const sid: u32 = @intCast(self.segs.items.len);
    const bid: u32 = @intCast(self.bounds.items.len);
    try self.segs.append(.{ .id = sid, .owner = bid, .status = types.PENDING, .html = @import("std").ArrayList(u8).init(self.alloc) });
    try self.bounds.append(.{ .id = bid, .parent = null, .status = types.PENDING, .parent_flushed = true, .pending_tasks = 0, .root_seg = sid, .kind = 0 });
}

pub fn addBound(self: *req_mod.Req, parent: ?u32, in_doc: u32, kind: u8) !u32 {
    _ = in_doc;
    const sid: u32 = @intCast(self.segs.items.len);
    const bid: u32 = @intCast(self.bounds.items.len);
    try self.segs.append(.{ .id = sid, .owner = bid, .status = types.PENDING, .html = @import("std").ArrayList(u8).init(self.alloc) });
    try self.bounds.append(.{ .id = bid, .parent = parent, .status = types.PENDING, .parent_flushed = false, .pending_tasks = 0, .root_seg = sid, .kind = kind });
    return bid;
}

pub fn hole(self: *req_mod.Req, parent_seg: u32, child_id: u32, fallback: []const u8) void {
    if (self.dest.dead or self.aborted) return;
    const out = &self.segs.items[parent_seg].html;
    out.appendSlice("<!--$?--><template id=\"B:") catch return;
    var nb: [16]u8 = undefined;
    const ns = @import("std").fmt.bufPrint(&nb, "{d}", .{child_id}) catch return;
    out.appendSlice(ns) catch return;
    out.appendSlice("\"></template>") catch return;
    out.appendSlice(fallback) catch return;
    out.appendSlice("<!--/$-->") catch return;
    if (self.segs.items[parent_seg].status == types.FLUSHED) {
        self.bounds.items[child_id].parent_flushed = true;
    }
}
