const std = @import("std");
const state = @import("./state.zig");
const wake = @import("./wake.zig");

pub const Table = struct {
    alloc: std.mem.Allocator,
    map: std.AutoHashMap(u32, Entry),

    const Entry = struct {
        state: u8,
        html: []u8,
        rej: state.Rej,
    };

    pub fn init(alloc: std.mem.Allocator) Table {
        return .{ .alloc = alloc, .map = std.AutoHashMap(u32, Entry).init(alloc) };
    }

    pub fn deinit(self: *Table) void {
        var it = self.map.iterator();
        while (it.next()) |e| {
            if (e.value_ptr.state == 1) self.alloc.free(e.value_ptr.html);
            if (e.value_ptr.state == 2) {
                self.alloc.free(e.value_ptr.rej.digest);
                self.alloc.free(e.value_ptr.rej.msg);
                self.alloc.free(e.value_ptr.rej.stack);
            }
        }
        self.map.deinit();
    }

    pub fn addPending(self: *Table, id: u32) void {
        self.map.put(id, .{ .state = 0, .html = @as([]u8, @constCast("")), .rej = .{ .digest = "", .msg = "", .stack = "" } }) catch {};
    }

    pub fn fulfill(self: *Table, id: u32, h: []const u8) void {
        const cp = self.alloc.dupe(u8, h) catch return;
        if (self.map.getPtr(id)) |e| {
            if (e.state == 1) self.alloc.free(e.html);
            e.state = 1;
            e.html = cp;
        } else {
            self.map.put(id, .{ .state = 1, .html = cp, .rej = .{ .digest = "", .msg = "", .stack = "" } }) catch {
                self.alloc.free(cp);
            };
        }
    }

    pub fn reject(self: *Table, id: u32, digest: []const u8, msg: []const u8, stack: []const u8) void {
        // Lifetime: Table OWNS rej slices (dupes). Callers pass string
        // literals/templates; without dupe, failBound would read freed
        // alloc.dupe'd buffers after terms.zig frees them.
        const dg = self.alloc.dupe(u8, digest) catch return;
        errdefer self.alloc.free(dg);
        const mm = self.alloc.dupe(u8, msg) catch {
            self.alloc.free(dg);
            return;
        };
        errdefer self.alloc.free(mm);
        const ss = self.alloc.dupe(u8, stack) catch {
            self.alloc.free(dg);
            self.alloc.free(mm);
            return;
        };
        const r: state.Rej = .{ .digest = dg, .msg = mm, .stack = ss };
        if (self.map.getPtr(id)) |e| {
            if (e.state == 1) self.alloc.free(e.html);
            if (e.state == 2) {
                self.alloc.free(e.rej.digest);
                self.alloc.free(e.rej.msg);
                self.alloc.free(e.rej.stack);
            }
            e.state = 2;
            e.html = @as([]u8, @constCast(""));
            e.rej = r;
        } else {
            self.map.put(id, .{ .state = 2, .html = @as([]u8, @constCast("")), .rej = r }) catch {};
        }
    }

    pub fn get(self: *Table, id: u32) state.State {
        if (self.map.get(id)) |e| {
            if (e.state == 1) return .{ .fulfilled = e.html };
            if (e.state == 2) return .{ .rejected = e.rej };
        }
        return .pending;
    }

    pub fn wakeOk(self: *Table, req: anytype, bid: u32, id: u32, h: []const u8) void {
        wake.wakeOk(self, req, bid, id, h);
    }

    pub fn wakeErr(self: *Table, req: anytype, bid: u32, id: u32, digest: []const u8, msg: []const u8, stack: []const u8) void {
        wake.wakeErr(self, req, bid, id, digest, msg, stack);
    }

    pub fn abort(self: *Table, req: anytype) void {
        wake.abort(self, req);
    }
};
