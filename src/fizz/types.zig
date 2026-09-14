const std = @import("std");
const Dest = @import("dest").Dest;

pub const PENDING: u8 = 0;
pub const COMPLETED: u8 = 1;
pub const FLUSHED: u8 = 2;
pub const CLIENT_RENDERED: u8 = 5;

pub const Segment = struct {
    id: u32,
    owner: u32,
    status: u8,
    html: std.ArrayList(u8),
};

pub const Boundary = struct {
    id: u32,
    parent: ?u32,
    status: u8,
    parent_flushed: bool,
    pending_tasks: u32,
    root_seg: u32,
    kind: u8,
};
