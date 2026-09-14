const std = @import("std");
const html = @import("html");

pub fn rowCells(alloc: std.mem.Allocator, row: u32, poison: bool, legs_html: ?[]const u8) []u8 {
    var out = std.ArrayList(u8).init(alloc);
    var nb: [64]u8 = undefined;
    const ns = std.fmt.bufPrint(&nb, "{d}", .{row}) catch return out.toOwnedSlice() catch @as([]u8, @constCast(""));
    out.appendSlice("<td>") catch {};
    out.appendSlice(ns) catch {};
    out.appendSlice("</td><td>SYM") catch {};
    out.appendSlice(ns) catch {};
    out.appendSlice("</td><td>") catch {};
    out.appendSlice(ns) catch {};
    out.appendSlice(".25</td><td>") catch {};
    if (poison) {
        html.escapeInto(&out, "<script>alert(1)</script><!--pwn-->&\"'");
    } else {
        out.appendSlice("ok") catch {};
    }
    if (legs_html) |lh| out.appendSlice(lh) catch {};
    out.appendSlice("</td>") catch {};
    return out.toOwnedSlice() catch @as([]u8, @constCast(""));
}

pub fn legsCells(alloc: std.mem.Allocator, row: u32) []u8 {
    var out = std.ArrayList(u8).init(alloc);
    var nb: [32]u8 = undefined;
    const ns = std.fmt.bufPrint(&nb, "{d}", .{row}) catch return out.toOwnedSlice() catch @as([]u8, @constCast(""));
    out.appendSlice(" <span class=\"legs\">legs·") catch {};
    out.appendSlice(ns) catch {};
    out.appendSlice("</span>") catch {};
    return out.toOwnedSlice() catch @as([]u8, @constCast(""));
}

pub fn fallbackRow(alloc: std.mem.Allocator, row: u32) []u8 {
    var fb = std.ArrayList(u8).init(alloc);
    fb.appendSlice("<tr><td>") catch return fb.toOwnedSlice() catch @as([]u8, @constCast(""));
    var nb: [16]u8 = undefined;
    const ns = std.fmt.bufPrint(&nb, "{d}", .{row}) catch return fb.toOwnedSlice() catch @as([]u8, @constCast(""));
    fb.appendSlice(ns) catch {};
    fb.appendSlice("</td><td><span class=\"skel\"></span></td><td><span class=\"skel\"></span></td><td><span class=\"skel\"></span></td></tr>") catch {};
    return fb.toOwnedSlice() catch @as([]u8, @constCast(""));
}
