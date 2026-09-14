const std = @import("std");
const Dest = @import("./types.zig").Dest;

pub fn raw(self: *Dest, bytes: []const u8) void {
    var off: usize = 0;
    while (off < bytes.len) {
        if (self.dead) return;
        var n = bytes.len - off;
        if (self.kind == .mem and n > self.max_write) n = self.max_write;
        if (self.kind == .mem) {
            self.buf.appendSlice(bytes[off .. off + n]) catch {
                self.dead = true;
                return;
            };
        } else {
            if (self.stream) |s| {
                s.writeAll(bytes[off .. off + n]) catch {
                    self.dead = true;
                    return;
                };
            } else return;
        }
        off += n;
        if (self.kind == .net) break;
    }
}

pub fn headers(self: *Dest) void {
    if (self.dead) return;
    self.raw("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nX-Accel-Buffering: no\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n");
}

pub fn seg(self: *Dest, html: []const u8) void {
    if (self.dead) return;
    if (html.len == 0) return;
    if (self.abort_after > 0 and self.chunks >= self.abort_after) {
        self.dead = true;
        return;
    }
    var hbuf: [32]u8 = undefined;
    const h = std.fmt.bufPrint(&hbuf, "{x}", .{html.len}) catch return;
    self.raw(h);
    self.raw("\r\n");
    self.raw(html);
    self.raw("\r\n");
    self.chunks += 1;
}

pub fn fin(self: *Dest) void {
    if (self.dead) return;
    self.raw("0\r\n\r\n");
}

pub fn join(self: *Dest) []const u8 {
    return self.buf.items;
}

pub fn has(self: *Dest, needle: []const u8) bool {
    return std.mem.indexOf(u8, self.buf.items, needle) != null;
}
