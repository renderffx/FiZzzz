const std = @import("std");
const fizz = @import("fizz");
const flight = @import("flight");
const wires = @import("./wires.zig");

pub fn m1(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    fizz.Flags.ALWAYS_RC = true;
    const r = try wires.childFirstWire(alloc);
    defer alloc.free(r.wire);
    defer alloc.free(r.evs);
    const rc = wires.countKind(r.evs, 0);
    fizz.resetMutants();
    if (rc >= 1) {
        std.debug.print("M1 always-$RC caught (rc={d})\n", .{rc});
        return true;
    }
    std.debug.print("M1 SURVIVED\n", .{});
    return false;
}

pub fn m2(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    fizz.Flags.ALWAYS_ABSORB = true;
    const r = try wires.parentFirstWire(alloc);
    defer alloc.free(r.wire);
    defer alloc.free(r.evs);
    const rc = wires.countKind(r.evs, 0);
    fizz.resetMutants();
    if (rc == 0) {
        std.debug.print("M2 always-absorb caught (rc=0, want 1)\n", .{});
        return true;
    }
    std.debug.print("M2 SURVIVED\n", .{});
    return false;
}

pub fn m3(alloc: std.mem.Allocator) !bool {
    fizz.resetMutants();
    flight.resetMutants();
    fizz.Flags.BARE_ROOT = true;
    const r = try wires.parentFirstWire(alloc);
    defer alloc.free(r.evs);
    defer alloc.free(r.wire);
    fizz.resetMutants();
    if (std.mem.indexOf(u8, r.wire, "<tr id=\"S:")) |_| {
        std.debug.print("M3 bare-tr caught\n", .{});
        return true;
    }
    std.debug.print("M3 SURVIVED\n", .{});
    return false;
}
