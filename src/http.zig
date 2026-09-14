const std = @import("std");

pub fn readPath(stream: std.net.Stream, buf: *[512]u8) []const u8 {
    return @import("./http/request.zig").readPath(stream, buf);
}

pub fn drainHeaders(stream: std.net.Stream) void {
    return @import("./http/request.zig").drainHeaders(stream);
}

pub fn queryAfter(path: []const u8) usize {
    return @import("./http/query.zig").queryAfter(path);
}
