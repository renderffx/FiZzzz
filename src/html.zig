const escape_mod = @import("./html/escape.zig");
const wrap_mod = @import("./html/wrap.zig");

pub const escapeInto = escape_mod.escapeInto;
pub const Kind = wrap_mod.Kind;
pub const wrapInto = wrap_mod.wrapInto;
pub const kindFromU8 = wrap_mod.kindFromU8;
