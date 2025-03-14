pub const Loop = @import("loop.zig");
const Task = @import("task.zig");
pub const TaskAction = Task.TaskAction;
pub const Idle = @import("idle.zig");
pub const Timer = @import("timer.zig");
pub const Worker = @import("worker.zig");

test {
    _ = @import("loop.zig");
    _ = @import("idle.zig");
    _ = @import("timer.zig");
    _ = @import("worker.zig");
}
