const std = @import("std");
const fizz = @import("fizz");
const flight = @import("flight");
const fam = @import("./gen/fam.zig");
const check = @import("./gen/check.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    fizz.resetMutants();
    flight.resetMutants();
    const mws = [_]usize{ 1, 7, 17 };
    {
        const fam4 = fam.buildFam(alloc, 4);
        defer alloc.free(fam4);
        var terms = std.ArrayList(fam.FamTerm).init(alloc);
        defer terms.deinit();
        try terms.appendSlice(fam4);
        const fails = [_]u32{ 1, 4 };
        for (mws) |mw| {
            var a: usize = 0;
            while (a <= terms.items.len) : (a += 1) {
                if (try check.permute(alloc, terms.items, 0, 4, &fails, a, mw)) |ce| {
                    std.debug.print("COUNTEREXAMPLE: {s}\n", .{ce});
                    std.process.exit(1);
                }
            }
        }
    }
    {
        const seed: u64 = 0x1234567;
        var prng = std.Random.DefaultPrng.init(seed);
        const R = prng.random();
        var pi: usize = 0;
        while (pi < 200) : (pi += 1) {
            var terms = std.ArrayList(fam.FamTerm).init(alloc);
            var rr: u32 = 1;
            while (rr <= 8) : (rr += 1) try terms.append(.{ .kind = 0, .row = rr });
            try terms.append(.{ .kind = 2, .row = 2 });
            try terms.append(.{ .kind = 2, .row = 3 });
            var i = terms.items.len;
            while (i > 1) {
                i -= 1;
                const j = R.intRangeAtMost(usize, 0, i);
                const t = terms.items[i];
                terms.items[i] = terms.items[j];
                terms.items[j] = t;
            }
            const fails = [_]u32{ 5, 6 };
            for (mws) |mw| {
                var a: usize = 0;
                while (a <= terms.items.len) : (a += 1) {
                    if (try check.checkCase(alloc, 8, terms.items, &fails, a, mw)) |ce| {
                        std.debug.print("COUNTEREXAMPLE: {s}\n", .{ce});
                        std.process.exit(1);
                    }
                }
            }
            terms.deinit();
        }
    }
    {
        const seed: u64 = 0x7654321;
        var prng = std.Random.DefaultPrng.init(seed);
        const R = prng.random();
        var pi: usize = 0;
        while (pi < 300) : (pi += 1) {
            var terms = std.ArrayList(fam.FamTerm).init(alloc);
            defer terms.deinit();
            var r: u32 = 1;
            while (r <= 30) : (r += 1) try terms.append(.{ .kind = 0, .row = r });
            try terms.append(.{ .kind = 2, .row = 14 });
            try terms.append(.{ .kind = 2, .row = 28 });
            var i = terms.items.len;
            while (i > 1) {
                i -= 1;
                const j = R.intRangeAtMost(usize, 0, i);
                const t = terms.items[i];
                terms.items[i] = terms.items[j];
                terms.items[j] = t;
            }
            const fails = [_]u32{ 7, 19 };
            const legs = [_]u32{ 14, 28 };
            if (try check.checkCaseWithLegs(alloc, 30, terms.items, &fails, &legs, 11, 1)) |ce| {
                std.debug.print("COUNTEREXAMPLE blotter-hard: {s}\n", .{ce});
                std.process.exit(1);
            }
        }
    }
    std.debug.print("NO COUNTEREXAMPLE\n", .{});
}
