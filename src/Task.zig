const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");

pub const TaskAction = enum {
    rearm,
    disarm
};

const Task = @This();

userdata: ?*anyopaque,
gen: *const fn(self: *Task, rt: *aio.Dynamic) anyerror!void,
after: *const fn(self: *Task, failed: bool) TaskAction,

pub fn init(gen: *const fn(self: *Task, rt: *aio.Dynamic) anyerror!void, done: *const fn(self: *Task, failed: bool) TaskAction) Task {
    return .{
        .userdata = null,
        .gen = gen,
        .after = done,
    };
}
