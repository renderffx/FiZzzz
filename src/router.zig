const std = @import("std");
const Dest = @import("dest").Dest;
const blotter = @import("blotter");
const abort_scene = @import("abort_scene");
const fizz = @import("fizz");
const sched = @import("sched");
const http = @import("http");

pub fn serve(alloc: std.mem.Allocator, path: []const u8, rq: *fizz.Req, table: *sched.Table, dest: *Dest) void {
    // Root-only: /abort freezes, everything else is blotter.
    if (std.mem.startsWith(u8, path, "/abort")) {
        const after = http.queryAfter(path);
        dest.abort_after = after;
        abort_scene.serve(alloc, rq, table, after);
        return;
    }
    var sc = blotter.Scene.build(alloc, rq, table, 0) catch return;
    sc.run(alloc);
    alloc.free(sc.rows);
    alloc.free(sc.legs);
}
