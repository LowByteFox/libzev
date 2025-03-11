const std = @import("std");
const aio = @import("aio");

pub const TaskAction = enum {
    rearm,
    disarm
};

const Self = @This();
const after_completion = fn(self: *Self, failed: bool) TaskAction;

userdata: usize,
after: after_completion,

pub fn init(op: aio.Operation, userdata: usize, after: after_completion) Self {
    return .{
        .op = op,
        .userdata = userdata,
        .after = after,
    };
}
