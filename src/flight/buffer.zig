const std = @import("std");

pub const FlightRow = struct {
    pri: u8,
    id: u32,
    tag: u8,
    payload: []u8,
};

var buf_queue: std.ArrayList(FlightRow) = undefined;
var buf_init: bool = false;
var buf_alloc: std.mem.Allocator = undefined;

pub fn queue(alloc: std.mem.Allocator, pri: u8, id: u32, tag: u8, payload: []const u8) void {
    if (!buf_init) {
        buf_alloc = alloc;
        buf_queue = std.ArrayList(FlightRow).init(alloc);
        buf_init = true;
    }
    const cp = alloc.dupe(u8, payload) catch return;
    buf_queue.append(.{ .pri = pri, .id = id, .tag = tag, .payload = cp }) catch return;
}

pub fn flushBuf(req: anytype) void {
    if (!buf_init) return;
    for (buf_queue.items) |r| {
        if (req.dest.dead or req.aborted) {
            req.alloc.free(r.payload);
            continue;
        }
        var hbuf: [16]u8 = undefined;
        const hx = @import("./push.zig").hexId(&hbuf, r.id);
        req.tmp.clearRetainingCapacity();
        req.tmp.appendSlice("<script>__F.push(\"") catch break;
        req.tmp.appendSlice(hx) catch break;
        req.tmp.appendSlice(":") catch break;
        req.tmp.append(r.tag) catch break;
        req.tmp.appendSlice(r.payload) catch break;
        req.tmp.appendSlice("\\n\")</script>") catch break;
        req.dest.seg(req.tmp.items);
        req.alloc.free(r.payload);
    }
    buf_queue.clearRetainingCapacity();
}

pub fn resetBuf() void {
    if (!buf_init) return;
    for (buf_queue.items) |r| buf_alloc.free(r.payload);
    buf_queue.deinit();
    buf_init = false;
}
