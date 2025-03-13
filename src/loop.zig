const std = @import("std");
const aio = @import("aio");

const Task = @import("task.zig");

const Self = @This();

allocator: std.mem.Allocator,
rt: aio.Dynamic,

pub fn init(allocator: std.mem.Allocator, max_entries: u16) !Self {
    return .{
        .allocator = allocator,
        .rt = try aio.Dynamic.init(allocator, max_entries),
    };
}

pub fn deinit(self: *Self) void {
    self.rt.deinit(self.allocator);
}

pub fn add_task(self: *Self, task: *Task) !void {
    try task.gen(task, &self.rt);
}

pub fn tick(self: *Self, mode: aio.CompletionMode) !u16 {
    const completion = try self.rt.complete(mode, self);

    return completion.num_completed;
}

pub fn aio_complete(self: *Self, _: aio.Id, userdata: usize, failed: bool) void {
    std.debug.assert(userdata != 0);
    var task: *Task = @ptrFromInt(userdata);

    if (task.after(task, failed) == .rearm) {
        // FIXME: This is very dumb
        // but I'll go with this for the time being
        task.gen(task, &self.rt) catch {};
    }
}
