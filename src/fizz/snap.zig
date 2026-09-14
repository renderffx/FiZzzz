const std = @import("std");
const req_mod = @import("./req.zig");
const types = @import("./types.zig");

pub const Snap = struct {
    alloc: std.mem.Allocator,
    bounds: []types.Boundary,
    segs_html: [][]u8,
    segs_owner: []u32,
    segs_status: []u8,
    minted: []u32,

    pub fn deinit(self: *Snap) void {
        for (self.segs_html) |h| self.alloc.free(h);
        self.alloc.free(self.segs_html);
        self.alloc.free(self.segs_owner);
        self.alloc.free(self.segs_status);
        self.alloc.free(self.bounds);
        self.alloc.free(self.minted);
    }
};

pub fn capture(alloc: std.mem.Allocator, req: *req_mod.Req) !Snap {
    var bounds = try alloc.alloc(types.Boundary, req.bounds.items.len);
    for (req.bounds.items, 0..) |b, i| bounds[i] = b;
    var segs_html = try alloc.alloc([]u8, req.segs.items.len);
    errdefer alloc.free(segs_html);
    var segs_owner = try alloc.alloc(u32, req.segs.items.len);
    errdefer alloc.free(segs_owner);
    var segs_status = try alloc.alloc(u8, req.segs.items.len);
    errdefer alloc.free(segs_status);
    for (req.segs.items, 0..) |*s, i| {
        segs_html[i] = try alloc.dupe(u8, s.html.items);
        segs_owner[i] = s.owner;
        segs_status[i] = s.status;
    }
    var minted_list = std.ArrayList(u32).init(alloc);
    defer minted_list.deinit();
    var it = req.minted.iterator();
    while (it.next()) |kv| try minted_list.append(kv.key_ptr.*);
    return .{
        .alloc = alloc,
        .bounds = bounds,
        .segs_html = segs_html,
        .segs_owner = segs_owner,
        .segs_status = segs_status,
        .minted = try minted_list.toOwnedSlice(),
    };
}

pub fn resumeReq(alloc: std.mem.Allocator, dest: *@import("dest").Dest, snap: *const Snap) !req_mod.Req {
    var req = req_mod.Req.init(alloc, dest);
    for (snap.bounds, 0..) |b, i| {
        const sid: u32 = @intCast(i);
        var html = std.ArrayList(u8).init(alloc);
        try html.appendSlice(snap.segs_html[i]);
        try req.segs.append(.{ .id = sid, .owner = snap.segs_owner[i], .status = snap.segs_status[i], .html = html });
        try req.bounds.append(b);
    }
    for (snap.minted) |id| try req.minted.put(id, true);
    return req;
}
