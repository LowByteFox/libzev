const std = @import("std");
const aio = @import("aio");
const Loop = @import("loop.zig");
const Task = @import("task.zig");

const Self = @This();

userdata: usize,
task: Task,
timeout_ns: u128,
fun: *const fn(self: *Self) Task.TaskAction,

pub fn init(fun: fn(self: *Self) Task.TaskAction, timeout: u128, userdata: usize) Self {
    return .{
        .userdata = userdata,
        .timeout_ns = timeout,
        .task = Task.init(gen, done),
        .fun = fun,
    };
}

pub fn register(self: *Self, loop: *Loop) !void {
    self.task.userdata = @intFromPtr(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    const timer: *Self = @ptrFromInt(self.userdata);

    try rt.queue(aio.op(.timeout, .{
        .ns = timer.timeout_ns,
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const timer: *Self = @ptrFromInt(task.userdata);
    return timer.fun(timer);
}



var counter: u128 = 100;

fn hello(timer: *Self) Task.TaskAction {
    std.debug.print("Hello, World after {}ms!\n", .{counter});

    counter += 100;

    timer.timeout_ns = counter * std.time.ns_per_ms;

    if (counter <= 1000) {
        return .rearm;
    }

    return .disarm;
}

test "timer test" {
    var loop = try Loop.init(std.testing.allocator, 4096);
    defer loop.deinit();

    var timer = init(hello, counter, 0);
    try timer.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}
