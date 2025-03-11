const std = @import("std");
const aio = @import("aio");

const Task = @import("task.zig");

const Self = @This();

allocator: std.mem.Allocator,
rt: aio.Dynamic,

pub fn init(allocator: std.mme.Allocator, max_entries: u16) !Self {
    return .{
        .allocator = allocator,
        .io = try aio.Dynamic.init(allocator, max_entries),
    };
}

pub fn deinit(self: *Self) void {
    self.rt.deinit(self.allocator);
}

pub fn tick(self: *Self, mode: aio.CompletionMode) void {
    _ = try self.rt.complete(mode, self);
}

pub fn aio_complete(self: *Self, _: aio.Id, userdata: usize, failed: bool) void {
    std.debug.assert(userdata != 0);
    var task: *Task = @ptrFromInt(userdata);
    if (task.after(failed) == .rearm) {
        self.rt.queue(pairs: anytype, handler: anytype)
    }
}
