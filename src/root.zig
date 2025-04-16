//! `Libxev` inspired library using `zig-aio`, provides user friendly APIs with an event loop backed by `zig-aio`.

pub const Loop = @import("Loop.zig");
const Task = @import("Task.zig");
pub const TaskAction = Task.TaskAction;
pub const Idle = @import("Idle.zig");
pub const Timer = @import("Timer.zig");
pub const Worker = @import("Worker.zig");

test {
    _ = @import("Loop.zig");
    _ = @import("Idle.zig");
    _ = @import("Timer.zig");
    _ = @import("Worker.zig");
    _ = @import("server_client_test.zig");
}
