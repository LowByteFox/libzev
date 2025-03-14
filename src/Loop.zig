//! Basic event loop implementation. Initialize with `init`.
//!
//! To run the event loop call `tick` either with `.nonblocking` or `.blocking`.

const std = @import("std");
const aio = @import("aio");
const Task = @import("Task.zig");

const Loop = @This();

allocator: std.mem.Allocator,
rt: aio.Dynamic,

/// Initialize the event Loop, provide how many events the event loop can manage, if unsure, go with `4096`.
pub fn init(allocator: std.mem.Allocator, max_entries: u16) !Loop {
    return .{
        .allocator = allocator,
        .rt = try aio.Dynamic.init(allocator, max_entries),
    };
}

/// Deinitialize the event loop and clean up used resources.
pub fn deinit(self: *Loop) void {
    self.rt.deinit(self.allocator);
}

pub fn add_task(self: *Loop, task: *Task) !void {
    try task.gen(task, &self.rt);
}

/// Run the event loop once, either make it block using `.blocking` or to not block if nothing happened using `.nonblocking`. Function returns the number of completed events
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
