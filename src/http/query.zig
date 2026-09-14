const std = @import("std");

pub fn queryAfter(path: []const u8) usize {
    if (std.mem.indexOf(u8, path, "after=")) |ai| {
        var v: usize = 0;
        var j = ai + 6;
        var any = false;
        while (j < path.len and path[j] >= '0' and path[j] <= '9') : (j += 1) {
            const d: usize = path[j] - '0';
            // Saturate instead of wrapping: huge after= clamps, never panics.
            if (v > (std.math.maxInt(usize) - d) / 10) return std.math.maxInt(usize);
            v = v * 10 + d;
            any = true;
        }
        if (any) return v;
    }
    return 11;
}

pub fn hasToken(path: []const u8, token: []const u8) bool {
    return std.mem.indexOf(u8, path, token) != null;
}
