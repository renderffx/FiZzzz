const std = @import("std");
const Dest = @import("dest").Dest;
const fizz = @import("fizz");
const sched = @import("sched");
const http = @import("http");
const router = @import("router");

fn handle(alloc: std.mem.Allocator, stream: std.net.Stream) void {
    var reqline: [512]u8 = undefined;
    const path = http.readPath(stream, &reqline);
    const owned = alloc.dupe(u8, path) catch return;
    defer alloc.free(owned);
    http.drainHeaders(stream);

    var dest = Dest.ofNet(alloc, stream);
    defer dest.deinit();
    dest.headers();
    var rq = fizz.Req.init(alloc, &dest);
    defer rq.deinit();
    var table = sched.Table.init(alloc);
    defer table.deinit();

    router.serve(alloc, owned, &rq, &table, &dest);
    dest.fin();
    stream.close();
}

pub fn main() !void {
    const addr = try std.net.Address.parseIp4("127.0.0.1", 8787);
    var srv = try addr.listen(.{ .reuse_address = true });
    defer srv.deinit();
    while (true) {
        // Threaded: a slow paced stream must not block other routes.
        const conn = srv.accept() catch continue;
        const t = std.Thread.spawn(.{}, handleThread, .{conn.stream}) catch {
            conn.stream.close();
            continue;
        };
        t.detach();
    }
}

fn handleThread(stream: std.net.Stream) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    handle(gpa.allocator(), stream);
}
