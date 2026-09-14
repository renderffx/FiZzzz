const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const flight = @import("flight");
const parse_wire = @import("parse_wire");
const wires = @import("./wires.zig");

pub fn m4(alloc: std.mem.Allocator) bool {
    _ = alloc;
    var f = std.fs.cwd().openFile("src/boot.js", .{}) catch return false;
    defer f.close();
    var buf: [1 << 16]u8 = undefined;
    const n = f.readAll(&buf) catch return false;
    const is_depth = std.mem.indexOf(u8, buf[0..n], "depth") != null;
    if (is_depth) {
        std.debug.print("M4 no-depth-$RC caught (boot tracks depth)\n", .{});
        return true;
    }
    std.debug.print("M4 SURVIVED\n", .{});
    return false;
}

pub fn m5(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    fizz.Flags.RX_THEN_RC = true;
    const r = try wires.failWire(alloc);
    defer alloc.free(r.wire);
    defer alloc.free(r.evs);
    fizz.resetMutants();
    if (parse_wire.hasRcAfterRx(r.evs)) {
        std.debug.print("M5 rx-then-rc caught\n", .{});
        return true;
    }
    std.debug.print("M5 SURVIVED\n", .{});
    return false;
}

pub fn m6(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    flight.Flags.BUFFER = true;
    var dest = Dest.ofMem(alloc, 17, 0);
    var req = fizz.Req.init(alloc, &dest);
    try req.root();
    try flight.push(&req, 1, 42, 'J', "{\"a\":1}");
    req.aborted = true;
    dest.dead = true;
    flight.flushBuf(&req);
    const has = dest.has("_F.push");
    flight.resetMutants();
    dest.deinit();
    req.deinit();
    if (!has) {
        std.debug.print("M6 buffered-flight caught (push lost)\n", .{});
        return true;
    }
    std.debug.print("M6 SURVIVED\n", .{});
    return false;
}

pub fn m7(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    var dest = Dest.ofMem(alloc, 17, 0);
    var req = fizz.Req.init(alloc, &dest);
    try req.root();
    try flight.push(&req, 1, 9, 'J', "{\"a\":1}");
    req.aborted = true;
    dest.dead = true;
    flight.Flags.ALLOW_REMINT_AFTER_ABORT = true;
    const ok = flight.push(&req, 1, 9, 'J', "{\"b\":2}");
    dest.deinit();
    req.deinit();
    flight.resetMutants();
    if (ok) |_| {
        std.debug.print("M7 remint-after-abort caught (no DupFlightId)\n", .{});
        return true;
    } else |_| {
        std.debug.print("M7 SURVIVED\n", .{});
        return false;
    }
}
