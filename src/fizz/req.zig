const std = @import("std");
const Dest = @import("dest").Dest;
const types = @import("./types.zig");

pub const Req = struct {
    alloc: std.mem.Allocator,
    dest: *Dest,
    segs: std.ArrayList(types.Segment),
    bounds: std.ArrayList(types.Boundary),
    minted: std.AutoHashMap(u32, bool),
    aborted: bool = false,
    tmp: std.ArrayList(u8),

    pub fn init(alloc: std.mem.Allocator, dest: *Dest) Req {
        return .{
            .alloc = alloc,
            .dest = dest,
            .segs = std.ArrayList(types.Segment).init(alloc),
            .bounds = std.ArrayList(types.Boundary).init(alloc),
            .minted = std.AutoHashMap(u32, bool).init(alloc),
            .tmp = std.ArrayList(u8).init(alloc),
        };
    }

    pub fn deinit(self: *Req) void {
        for (self.segs.items) |*s| s.html.deinit();
        self.segs.deinit();
        self.bounds.deinit();
        self.minted.deinit();
        self.tmp.deinit();
    }

    pub fn root(self: *Req) !void {
        const bounds = @import("./bounds.zig");
        try bounds.root(self);
    }

    pub fn addBound(self: *Req, parent: ?u32, in_doc: u32, kind: u8) !u32 {
        const bounds = @import("./bounds.zig");
        return bounds.addBound(self, parent, in_doc, kind);
    }

    pub fn hole(self: *Req, parent_seg: u32, child_id: u32, fallback: []const u8) void {
        const bounds = @import("./bounds.zig");
        bounds.hole(self, parent_seg, child_id, fallback);
    }

    pub fn finishSeg(self: *Req, sid: u32) void {
        const settle = @import("./settle.zig");
        settle.finishSeg(self, sid);
    }

    pub fn completeBound(self: *Req, bid: u32) void {
        const settle = @import("./settle.zig");
        settle.completeBound(self, bid);
    }

    pub fn failBound(self: *Req, bid: u32, digest: []const u8, msg: []const u8, stack: []const u8) void {
        const fail = @import("./fail.zig");
        fail.failBound(self, bid, digest, msg, stack);
    }

    pub fn emitReveal(self: *Req, bid: u32) void {
        const reveal = @import("./reveal.zig");
        reveal.emitReveal(self, bid);
    }

    pub fn flushRoot(self: *Req, root_seg: u32) void {
        const reveal = @import("./reveal.zig");
        reveal.flushRoot(self, root_seg);
    }
};
