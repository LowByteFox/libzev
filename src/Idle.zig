//! `Idle` task is useful for waking up the event loop or running task asynchronously
//!
//! Ensure it lives long enough, if not, there will be consequences!!

const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");

const Idle = @This();

userdata: ?*anyopaque,
task: Task,
fun: *const fn(self: *Idle) Task.TaskAction,

/// Initialize `Idle` task, runs `fun` after completion.
pub fn init(fun: fn(self: *Idle) Task.TaskAction, userdata: ?*anyopaque) Idle {
    return .{
        .userdata = userdata,
        .task = Task.init(gen, done),
        .fun = fun,
    };
}

/// Register the task on the event loop.
pub fn register(self: *Idle, loop: *Loop) !void {
    self.task.userdata = @ptrCast(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    try rt.queue(aio.op(.nop, .{
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const idle: *Idle = @ptrCast(@alignCast(task.userdata));
    return idle.fun(idle);
}



var counter: i32 = 0;

fn hello(_: *Idle) Task.TaskAction {
    std.debug.print("Hello, World!\n", .{});

    counter += 1;
    if (counter < 10) {
        return .rearm;
    }
    return .disarm;
}

test "idle test" {
    var loop = try Loop.init(std.testing.allocator, 4096);
    defer loop.deinit();

    var idle = init(hello, null);
    try idle.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}
