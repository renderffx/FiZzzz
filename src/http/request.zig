const std = @import("std");

pub fn readPath(stream: std.net.Stream, buf: *[512]u8) []const u8 {
    var n: usize = 0;
    var overflowed = false;
    while (true) {
        var one: [1]u8 = undefined;
        const k = stream.read(one[0..]) catch break;
        if (k == 0) break;
        if (n < buf.len) {
            buf[n] = one[0];
            n += k;
        } else {
            overflowed = true;
        }
        if (one[0] == '\n') break;
        if (overflowed and n >= buf.len) {
            // Keep draining to end of line so the next read is aligned,
            // but never store past buf. Path stays "/" (safe default).
            continue;
        }
        if (n >= 2 and buf[n - 2] == '\r' and buf[n - 1] == '\n') break;
    }
    if (overflowed) return "/";
    const line = buf[0..n];
    var path: []const u8 = "/";
    var i: usize = 0;
    while (i < line.len and line[i] != ' ') : (i += 1) {}
    i += 1;
    const ps = i;
    while (i < line.len and line[i] != ' ' and line[i] != '\r' and line[i] != '\n') : (i += 1) {}
    if (i > ps) path = line[ps..i];
    return path;
}

pub fn drainHeaders(stream: std.net.Stream) void {
    var tail = [_]u8{ 0, 0, 0, 0 };
    var drained: usize = 0;
    while (drained < 8192) {
        var one: [1]u8 = undefined;
        const k = stream.read(one[0..]) catch break;
        if (k == 0) break;
        tail[0] = tail[1];
        tail[1] = tail[2];
        tail[2] = tail[3];
        tail[3] = one[0];
        drained += 1;
        if (std.mem.eql(u8, &tail, "\r\n\r\n")) break;
        if (tail[2] == '\n' and tail[3] == '\n') break;
    }
}
