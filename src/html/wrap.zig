const std = @import("std");

pub const Kind = enum { flow, tr, thead_cell };

pub fn wrapInto(out: *std.ArrayList(u8), kind: Kind, primary: []const u8) void {
    switch (kind) {
        .flow => {
            out.appendSlice(primary) catch return;
        },
        .tr => {
            out.appendSlice("<tr>") catch return;
            out.appendSlice(primary) catch return;
            out.appendSlice("</tr>") catch return;
        },
        .thead_cell => {
            out.appendSlice("<th>") catch return;
            out.appendSlice(primary) catch return;
            out.appendSlice("</th>") catch return;
        },
    }
}

pub fn kindFromU8(k: u8) Kind {
    return switch (k) {
        1 => .tr,
        2 => .thead_cell,
        else => .flow,
    };
}
