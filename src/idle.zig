const std = @import("std");
const aio = @import("aio");
const Loop = @import("loop.zig");
const Task = @import("task.zig");

const Self = @This();

userdata: usize,
task: Task,
fun: *const fn(self: *Self) Task.TaskAction,

pub fn init(userdata: usize, fun: fn(self: *Self) Task.TaskAction) Self {
    return .{
        .userdata = userdata,
        .task = Task.init(gen, done),
        .fun = fun,
    };
}

pub fn register(self: *Self, loop: *Loop) !void {
    self.task.userdata = @intFromPtr(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    try rt.queue(aio.op(.nop, .{
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const idle: *Self = @ptrFromInt(task.userdata);
    return idle.fun(idle);
}
