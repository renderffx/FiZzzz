const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const parse_wire = @import("parse_wire");

pub fn childFirstWire(alloc: std.mem.Allocator) !struct { wire: []u8, evs: []parse_wire.Ev } {
    var dest = Dest.ofMem(alloc, 17, 0);
    var req = fizz.Req.init(alloc, &dest);
    try req.root();
    const parent = try req.addBound(0, 0, 0);
    const child = try req.addBound(parent, req.bounds.items[parent].root_seg, 0);
    try req.segs.items[req.bounds.items[child].root_seg].html.appendSlice("kid");
    req.finishSeg(req.bounds.items[child].root_seg);
    try req.segs.items[req.bounds.items[parent].root_seg].html.appendSlice("par");
    req.finishSeg(req.bounds.items[parent].root_seg);
    req.flushRoot(0);
    const wire = try alloc.dupe(u8, dest.join());
    const evs = parse_wire.parse(alloc, wire);
    dest.deinit();
    req.deinit();
    return .{ .wire = wire, .evs = evs };
}

pub fn parentFirstWire(alloc: std.mem.Allocator) !struct { wire: []u8, evs: []parse_wire.Ev } {
    var dest = Dest.ofMem(alloc, 17, 0);
    var req = fizz.Req.init(alloc, &dest);
    try req.root();
    const parent = try req.addBound(0, 0, 0);
    try req.segs.items[req.bounds.items[parent].root_seg].html.appendSlice("par");
    req.finishSeg(req.bounds.items[parent].root_seg);
    req.flushRoot(0);
    const child = try req.addBound(parent, req.bounds.items[parent].root_seg, 0);
    req.bounds.items[child].parent_flushed = true;
    try req.segs.items[req.bounds.items[child].root_seg].html.appendSlice("kid");
    req.finishSeg(req.bounds.items[child].root_seg);
    const wire = try alloc.dupe(u8, dest.join());
    const evs = parse_wire.parse(alloc, wire);
    dest.deinit();
    req.deinit();
    return .{ .wire = wire, .evs = evs };
}

pub fn failWire(alloc: std.mem.Allocator) !struct { wire: []u8, evs: []parse_wire.Ev } {
    var dest = Dest.ofMem(alloc, 17, 0);
    var req = fizz.Req.init(alloc, &dest);
    try req.root();
    const b = try req.addBound(0, 0, 0);
    req.flushRoot(0);
    req.failBound(b, "D1", "NAK", "s");
    const wire = try alloc.dupe(u8, dest.join());
    const evs = parse_wire.parse(alloc, wire);
    dest.deinit();
    req.deinit();
    return .{ .wire = wire, .evs = evs };
}

pub fn countKind(evs: []parse_wire.Ev, k: u8) usize {
    var n: usize = 0;
    for (evs) |e| {
        if (e.kind == k) n += 1;
    }
    return n;
}
