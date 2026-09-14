const std = @import("std");
const Dest = @import("dest").Dest;
const blotter = @import("blotter");
const abort_scene = @import("abort_scene");
const fizz = @import("fizz");
const sched = @import("sched");
const http = @import("http");

pub fn serve(alloc: std.mem.Allocator, path: []const u8, rq: *fizz.Req, table: *sched.Table, dest: *Dest) void {
    if (std.mem.startsWith(u8, path, "/abort")) {
        const after = http.queryAfter(path);
        dest.abort_after = after;
        abort_scene.serve(alloc, rq, table, after);
        return;
    }
    if (std.mem.startsWith(u8, path, "/ppr")) {
        servePpr(alloc, rq, table, dest) catch {};
        return;
    }
    var sc = blotter.Scene.build(alloc, rq, table, 0) catch return;
    sc.run(alloc);
    alloc.free(sc.rows);
    alloc.free(sc.legs);
}

fn servePpr(alloc: std.mem.Allocator, rq: *fizz.Req, table: *sched.Table, dest: *Dest) !void {
    const sc = try blotter.Scene.build(alloc, rq, table, 0);
    var snap = try blotter.Scene.captureShell(alloc, sc);
    defer snap.deinit();
    var resumed = try fizz.resumeReq(alloc, dest, &snap);
    defer resumed.deinit();
    var sc2 = blotter.Scene{ .req = &resumed, .table = table, .rows = sc.rows, .legs = sc.legs, .abort_after = 0 };
    sc2.run(alloc);
    alloc.free(sc.rows);
    alloc.free(sc.legs);
}
