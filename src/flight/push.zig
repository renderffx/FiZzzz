const flags = @import("./flags.zig");
const buffer = @import("./buffer.zig");

pub fn hexId(into: *[16]u8, id: u32) []u8 {
    const std = @import("std");
    const s = std.fmt.bufPrint(into, "{x}", .{id}) catch return into[0..0];
    return s;
}

pub fn push(req: anytype, pri: u8, id: u32, tag: u8, payload: []const u8) flags.DupFlightId!void {
    const was_minted = req.minted.get(id) orelse false;
    if (was_minted and tag != 'C' and !flags.Flags.ALLOW_REMINT_AFTER_ABORT) return error.DupFlightId;
    if (!(was_minted and tag != 'C' and flags.Flags.ALLOW_REMINT_AFTER_ABORT)) {
        req.minted.put(id, true) catch return error.DupFlightId;
    }

    const is_dead = req.dest.dead or req.aborted;
    if (is_dead and !flags.Flags.BUFFER) return;
    if (flags.Flags.BUFFER) {
        buffer.queue(req.alloc, pri, id, tag, payload);
        return;
    }
    if (is_dead) return;

    var hbuf: [16]u8 = undefined;
    const hx = hexId(&hbuf, id);
    req.tmp.clearRetainingCapacity();
    req.tmp.appendSlice("<script>__F.push(\"") catch return;
    req.tmp.appendSlice(hx) catch return;
    req.tmp.appendSlice(":") catch return;
    req.tmp.append(@as(u8, tag)) catch return;
    // Payload is embedded inside a double-quoted JS string: escape
    // backslash, double-quote, and </script> so attacker-controlled
    // row bytes cannot break out of the script block.
    for (payload) |c| {
        if (c == '\\' or c == '"') req.tmp.append('\\') catch return;
        req.tmp.append(c) catch return;
    }
    req.tmp.appendSlice("\\n\")</script>") catch return;
    req.dest.seg(req.tmp.items);
}

pub fn flushBuf(req: anytype) void {
    buffer.flushBuf(req);
}

pub fn resetMutants() void {
    flags.Flags.BUFFER = false;
    flags.Flags.ALLOW_REMINT_AFTER_ABORT = false;
    buffer.resetBuf();
}
