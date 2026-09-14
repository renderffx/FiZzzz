const std = @import("std");

pub const Rej = struct {
    digest: []const u8,
    msg: []const u8,
    stack: []const u8,
};

pub const State = union(enum) {
    pending,
    fulfilled: []const u8,
    rejected: Rej,
};
