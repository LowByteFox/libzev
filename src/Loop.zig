const std = @import("std");
const aio = @import("aio");
const Task = @import("Task.zig");

const Loop = @This();

allocator: std.mem.Allocator,
rt: aio.Dynamic,

pub fn init(allocator: std.mem.Allocator, max_entries: u16) !Loop {
    return .{
        .allocator = allocator,
        .rt = try aio.Dynamic.init(allocator, max_entries),
    };
}

pub fn deinit(self: *Loop) void {
    self.rt.deinit(self.allocator);
}

pub fn add_task(self: *Loop, task: *Task) !void {
    try task.gen(task, &self.rt);
}

pub fn tick(self: *Loop, mode: aio.CompletionMode) !u16 {
    const completion = try self.rt.complete(mode, self);

    return completion.num_completed;
}

pub fn aio_complete(self: *Loop, _: aio.Id, userdata: usize, failed: bool) void {
    if (userdata == 0) {
        return;
    }

    var task: *Task = @ptrFromInt(userdata);

    if (task.after(task, failed) == .rearm) {
        // FIXME: This is very dumb
        // but I'll go with this for the time being
        task.gen(task, &self.rt) catch {};
    }
}
