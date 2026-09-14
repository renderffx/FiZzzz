const types_mod = @import("./fizz/types.zig");
const mutants_mod = @import("./fizz/mutants.zig");
const req_mod = @import("./fizz/req.zig");

pub const PENDING = types_mod.PENDING;
pub const COMPLETED = types_mod.COMPLETED;
pub const FLUSHED = types_mod.FLUSHED;
pub const CLIENT_RENDERED = types_mod.CLIENT_RENDERED;
pub const Segment = types_mod.Segment;
pub const Boundary = types_mod.Boundary;
pub const Req = req_mod.Req;
pub const Flags = mutants_mod.Flags;
pub fn resetMutants() void {
    mutants_mod.resetMutants();
}
