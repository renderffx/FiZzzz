const std = @import("std");
const abc = @import("./mut/cases_abc.zig");
const defg = @import("./mut/cases_defg.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var caught: usize = 0;
    const total: usize = 7;
    if (try abc.m1(alloc)) caught += 1;
    if (try abc.m2(alloc)) caught += 1;
    if (try abc.m3(alloc)) caught += 1;
    if (defg.m4(alloc)) caught += 1;
    if (try defg.m5(alloc)) caught += 1;
    if (try defg.m6(alloc)) caught += 1;
    if (try defg.m7(alloc)) caught += 1;
    std.debug.print("mutants: {d}/{d} caught\n", .{ caught, total });
    if (caught != total) std.process.exit(1);
}
