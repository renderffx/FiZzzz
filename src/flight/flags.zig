pub const DupFlightId = error{
    DupFlightId,
};

pub const Flags = struct {
    pub var BUFFER: bool = false;
    pub var ALLOW_REMINT_AFTER_ABORT: bool = false;
};
