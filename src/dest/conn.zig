const std = @import("std");
const Dest = @import("./types.zig").Dest;

pub fn ofNet(alloc: std.mem.Allocator, stream: std.net.Stream) Dest {
    return .{ .alloc = alloc, .kind = .net, .stream = stream, .buf = std.ArrayList(u8).init(alloc) };
}

pub fn ofMem(alloc: std.mem.Allocator, max_write: usize, abort_after: usize) Dest {
    var mw = max_write;
    if (mw == 0) mw = 1;
    return .{ .alloc = alloc, .kind = .mem, .buf = std.ArrayList(u8).init(alloc), .max_write = mw, .abort_after = abort_after };
}

pub fn deinit(self: *Dest) void {
    self.buf.deinit();
}
