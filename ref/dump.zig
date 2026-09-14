const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const sched = @import("sched");
const blotter = @import("blotter");
const abort_scene = @import("abort_scene");
const parse_wire = @import("parse_wire");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Full scene into mem, mimics GET /
    {
        var dest = Dest.ofMem(alloc, 8192, 0);
        var req = fizz.Req.init(alloc, &dest);
        var table = sched.Table.init(alloc);
        var sc = try blotter.Scene.build(alloc, &req, &table, 0);
        sc.run(alloc);
        alloc.free(sc.rows);
        alloc.free(sc.legs);
        const wire = try alloc.dupe(u8, dest.join());
        defer alloc.free(wire);
        const evs = parse_wire.parse(alloc, wire);
        defer alloc.free(evs);
        var rc: usize = 0;
        var rx: usize = 0;
        for (evs) |e| {
            if (e.kind == 0) rc += 1 else rx += 1;
        }
        std.debug.print("FULL wire={d} evs={d} RC={d} RX={d} rcAfterRx={}\n", .{ wire.len, evs.len, rc, rx, parse_wire.hasRcAfterRx(evs) });
        std.debug.print("  hasRC_B14={} hasRX_B7={} hasRX_B19={} hasRC_B28={} bareTR={} escaped={}\n", .{
            std.mem.indexOf(u8, wire, "$RC(\"B:14\"") != null,
            std.mem.indexOf(u8, wire, "$RX(\"B:7\"") != null,
            std.mem.indexOf(u8, wire, "$RX(\"B:19\"") != null,
            std.mem.indexOf(u8, wire, "$RC(\"B:28\"") != null,
            std.mem.indexOf(u8, wire, "<tr id=\"S:") != null,
            std.mem.indexOf(u8, wire, "&lt;script&gt;") != null,
        });
        // legs14 absorb: no RC/RX for its legs bid; find any $RC with legs? legs bids differ; just report ids
        std.debug.print("  evs: ", .{});
        for (evs) |e| std.debug.print("{s}{d} ", .{ if (e.kind == 0) "RC" else "RX", e.id });
        std.debug.print("\n", .{});
        dest.deinit();
        req.deinit();
        table.deinit();
    }
    // Abort scene into mem, mimics GET /abort?after=11
    {
        var dest = Dest.ofMem(alloc, 8192, 0);
        dest.abort_after = 11;
        var req = fizz.Req.init(alloc, &dest);
        var table = sched.Table.init(alloc);
        abort_scene.serve(alloc, &req, &table, 11);
        const wire = try alloc.dupe(u8, dest.join());
        defer alloc.free(wire);
        const evs = parse_wire.parse(alloc, wire);
        defer alloc.free(evs);
        std.debug.print("ABORT wire={d} evs={d} chunks={d} dead={}\n", .{ wire.len, evs.len, dest.chunks, dest.dead });
        dest.deinit();
        req.deinit();
        table.deinit();
    }
}
