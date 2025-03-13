const std = @import("std");
const aio = @import("aio");
const Loop = @import("loop.zig");

pub const TaskAction = enum {
    rearm,
    disarm
};

const Self = @This();

userdata: usize,
gen: *const fn(self: *Self, rt: *aio.Dynamic) anyerror!void,
after: *const fn(self: *Self, failed: bool) TaskAction,

pub fn init(gen: *const fn(self: *Self, rt: *aio.Dynamic) anyerror!void, done: *const fn(self: *Self, failed: bool) TaskAction) Self {
    return .{
        .userdata = 0,
        .gen = gen,
        .after = done,
    };
}
