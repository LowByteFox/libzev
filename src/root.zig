//! `Libxev` inspired library using `zig-aio`, provides user friendly APIs with an event loop backed by `zig-aio`.
//!
//! `Libzev` is an alpha software, I don't recommend using it, but you do you.
//!
//! You can find the repository [here](https://git.sr.ht/~lowbytefox/libzev).

pub const Loop = @import("Loop.zig");
const Task = @import("Task.zig");
pub const TaskAction = Task.TaskAction;
pub const Idle = @import("Idle.zig");
pub const Timer = @import("Timer.zig");
pub const Worker = @import("Worker.zig");
pub const Server = @import("Server.zig");
pub const Client = @import("Client.zig");

test {
    _ = @import("Loop.zig");
    _ = @import("Idle.zig");
    _ = @import("Timer.zig");
    _ = @import("Worker.zig");
    _ = @import("server_client_test.zig");
}
