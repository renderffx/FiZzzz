const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const sched = @import("sched");
const blotter = @import("blotter");
const parse_wire = @import("parse_wire");
const oracle = @import("oracle");

pub fn pprCase(alloc: std.mem.Allocator) !struct { evs: []parse_wire.Ev, shell_dup: bool } {
    var dest1 = Dest.ofMem(alloc, 1, 0);
    defer dest1.deinit();
    var req1 = fizz.Req.init(alloc, &dest1);
    defer req1.deinit();
    var table = sched.Table.init(alloc);
    defer table.deinit();
    const sc = try blotter.Scene.build(alloc, &req1, &table, 0);
    var snap = try blotter.Scene.captureShell(alloc, sc);
    defer snap.deinit();
    var dest2 = Dest.ofMem(alloc, 1, 0);
    defer dest2.deinit();
    var req2 = try fizz.resumeReq(alloc, &dest2, &snap);
    defer req2.deinit();
    const rows2 = try alloc.dupe(u32, sc.rows);
    const legs2 = try alloc.dupe(u32, sc.legs);
    var sc2 = blotter.Scene{ .req = &req2, .table = &table, .rows = rows2, .legs = legs2, .abort_after = sc.abort_after };
    sc2.runResume(alloc);
    const wire = dest2.join();
    const evs = parse_wire.parse(alloc, wire);
    const has_shell_dup = std.mem.indexOf(u8, wire, "<!DOCTYPE html>") != null;
    alloc.free(sc.rows);
    alloc.free(sc.legs);
    alloc.free(rows2);
    alloc.free(legs2);
    return .{ .evs = evs, .shell_dup = has_shell_dup };
}
