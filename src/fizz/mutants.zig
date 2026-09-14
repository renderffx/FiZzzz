pub const Flags = struct {
    pub var ALWAYS_RC: bool = false;
    pub var ALWAYS_ABSORB: bool = false;
    pub var BARE_ROOT: bool = false;
    pub var RX_THEN_RC: bool = false;
};

pub fn resetMutants() void {
    Flags.ALWAYS_RC = false;
    Flags.ALWAYS_ABSORB = false;
    Flags.BARE_ROOT = false;
    Flags.RX_THEN_RC = false;
}
