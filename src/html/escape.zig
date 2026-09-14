const std = @import("std");

pub fn escapeInto(out: *std.ArrayList(u8), s: []const u8) void {
    var i: usize = 0;
    while (i < s.len) {
        const c = s[i];
        if (c == '&') {
            out.appendSlice("&amp;") catch return;
            i += 1;
        } else if (c == '<') {
            if (i + 3 < s.len and s[i + 1] == '!' and s[i + 2] == '-' and s[i + 3] == '-') {
                out.appendSlice("&lt;!--") catch return;
                i += 4;
            } else {
                out.appendSlice("&lt;") catch return;
                i += 1;
            }
        } else if (c == '>') {
            out.appendSlice("&gt;") catch return;
            i += 1;
        } else if (c == '"') {
            out.appendSlice("&#34;") catch return;
            i += 1;
        } else if (c == 0x27) {
            out.appendSlice("&#39;") catch return;
            i += 1;
        } else {
            out.append(c) catch return;
            i += 1;
        }
    }
}
