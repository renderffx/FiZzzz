const std = @import("std");
const fizz = @import("fizz");
const sched = @import("sched");
const blotter = @import("blotter");

// GET /abort?after=N: run blotter but kill the dest after N chunks.
// Remaining terminals -> Silent, table intact, no further chunks (F9).
pub fn serve(alloc: std.mem.Allocator, req: *fizz.Req, table: *sched.Table, after: usize) void {
    var sc = blotter.Scene.build(alloc, req, table, after) catch return;
    sc.run(alloc);
    alloc.free(sc.rows);
    alloc.free(sc.legs);
}
