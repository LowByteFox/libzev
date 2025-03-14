const std = @import("std");
const aio = @import("aio");
const Loop = @import("loop.zig");
const Task = @import("task.zig");

const Self = @This();

userdata: usize,
task: Task,
notifier: aio.EventSource,
work: *const fn(self: *Self) Task.TaskAction,
after_work: *const fn(self: *Self) Task.TaskAction,

pub fn init(work: fn(self: *Self) Task.TaskAction, after: fn(self: *Self) Task.TaskAction, userdata: usize) !Self {
    return .{
        .userdata = userdata,
        .task = Task.init(gen, done),
        .work = work,
        .after_work = after,
        .notifier = try aio.EventSource.init(),
    };
}

pub fn register(self: *Self, loop: *Loop) !void {
    self.task.userdata = @intFromPtr(self);
    try loop.add_task(&self.task);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    const worker: *Self = @ptrFromInt(self.userdata);

    try rt.queue(aio.op(.wait_event_source, .{
        .source = &worker.notifier,
        .userdata = @intFromPtr(self),
    }, .unlinked), {});

    _ = try std.Thread.spawn(.{}, perform_work, .{worker});
}

fn done(task: *Task, _: bool) Task.TaskAction {
    const worker: *Self = @ptrFromInt(task.userdata);

    return blk: {
        const ret = worker.after_work(worker);
        if (ret == .rearm) {
            worker.notifier.deinit();
            worker.notifier = aio.EventSource.init() catch {
                break :blk .disarm;
            };
        }

        break :blk ret;
    };
}

fn perform_work(self: *Self) void {
    while (self.work(self) == .rearm) {}
    self.notifier.notify();
}



fn fibonacci(n: u64) u64 {
    if (n == 0) {
        return 0;
    } else if (n == 1) {
        return 1;
    } else {
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

var value: u64 = 10;

fn test_work(_: *Self) Task.TaskAction {
    std.debug.print("Doing work from Thread!\n", .{});
    const out = fibonacci(value);
    std.debug.print("Work from thread {}: {}\n", .{std.Thread.getCurrentId(), out});

    value += 10;
    if (value < 50) {
        return .rearm;
    }

    return .disarm;
}

fn test_after(_: *Self) Task.TaskAction {
    std.debug.print("Work Done!\n", .{});

    value -= 5; // becomes 45

    if (value < 50) {
        std.debug.print("Thread {} re-run the work!\n", .{std.Thread.getCurrentId()});
        return .rearm;
    }

    return .disarm;
}

test "worker test" {
    var loop = try Loop.init(std.testing.allocator, 4096);
    defer loop.deinit();

    var worker = try init(test_work, test_after, 0);
    try worker.register(&loop);

    while (try loop.tick(.blocking) > 0) {}
}
