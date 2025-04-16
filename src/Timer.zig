//! `Timer` task is useful for timing an operation asynchronously
//!
//! Ensure it lives long enough, if not, there will be consequences!!

const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");

const Timer = @This();

userdata: ?*anyopaque,
task: Task,
timeout_ns: u128,
fun: *const fn(self: *Timer) Task.TaskAction,

/// Initialize `Timer` task, runs `fun` after `timeout` nanoseconds pass.
pub fn init(fun: fn(self: *Timer) Task.TaskAction, timeout: u128, userdata: ?*anyopaque) Timer {
    return .{
        .userdata = userdata,
        .timeout_ns = timeout,
        .task = Task.init(gen, done),
        .fun = fun,
    };
}

/// Register the task on the event loop
pub fn register(self: *Timer, loop: *Loop) !void {
    self.task.userdata = @ptrCast(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    const timer: *Timer = @ptrCast(@alignCast(self.userdata));

    try rt.queue(aio.op(.timeout, .{
        .ns = timer.timeout_ns,
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const timer: *Timer = @ptrCast(@alignCast(task.userdata));
    return timer.fun(timer);
}



var counter: u128 = 100;

fn hello(timer: *Timer) Task.TaskAction {
    std.debug.print("Hello, World after {}ms!\n", .{counter});

    counter += 100;

    timer.timeout_ns = counter * std.time.ns_per_ms;

    if (counter <= 500) {
        return .rearm;
    }

    return .disarm;
}

test "timer test" {
    var loop = try Loop.init(std.testing.allocator, 4096);
    defer loop.deinit();

    var timer = init(hello, counter, null);
    try timer.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}
