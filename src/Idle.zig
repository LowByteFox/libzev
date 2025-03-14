const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");

const Idle = @This();

userdata: usize,
task: Task,
fun: *const fn(self: *Idle) Task.TaskAction,

pub fn init(fun: fn(self: *Idle) Task.TaskAction, userdata: usize) Idle {
    return .{
        .userdata = userdata,
        .task = Task.init(gen, done),
        .fun = fun,
    };
}

pub fn register(self: *Idle, loop: *Loop) !void {
    self.task.userdata = @intFromPtr(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    try rt.queue(aio.op(.nop, .{
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const idle: *Idle = @ptrFromInt(task.userdata);
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

    var idle = init(hello, 0);
    try idle.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}
