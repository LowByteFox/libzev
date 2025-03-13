const std = @import("std");
const testing = std.testing;
const Loop = @import("loop.zig");
const Task = @import("task.zig");
const Idle = @import("idle.zig");

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
    var loop = try Loop.init(testing.allocator, 4096);
    defer loop.deinit();

    var idle = Idle.init(0, hello);
    try idle.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}

test {
    _ = @import("loop.zig");
}
