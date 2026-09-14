const std = @import("std");

pub const Dest = struct {
    alloc: std.mem.Allocator,
    kind: enum { net, mem },
    stream: ?std.net.Stream = null,
    buf: std.ArrayList(u8),
    max_write: usize = 8192,
    abort_after: usize = 0,
    chunks: usize = 0,
    dead: bool = false,

    pub fn ofNet(alloc: std.mem.Allocator, stream: std.net.Stream) Dest {
        return @import("./conn.zig").ofNet(alloc, stream);
    }

    pub fn ofMem(alloc: std.mem.Allocator, max_write: usize, abort_after: usize) Dest {
        return @import("./conn.zig").ofMem(alloc, max_write, abort_after);
    }

    pub fn deinit(self: *Dest) void {
        @import("./conn.zig").deinit(self);
    }

    pub fn raw(self: *Dest, bytes: []const u8) void {
        @import("./stream.zig").raw(self, bytes);
    }

    pub fn headers(self: *Dest) void {
        @import("./stream.zig").headers(self);
    }

    pub fn seg(self: *Dest, html: []const u8) void {
        @import("./stream.zig").seg(self, html);
    }

    pub fn fin(self: *Dest) void {
        @import("./stream.zig").fin(self);
    }

    pub fn join(self: *Dest) []const u8 {
        return @import("./stream.zig").join(self);
    }

    pub fn has(self: *Dest, needle: []const u8) bool {
        return @import("./stream.zig").has(self, needle);
    }
};
