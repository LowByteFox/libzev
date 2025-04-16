//! `Server` task allows for creating a server to which clients can connect to
//!
//! The only reason why an `std.mem.Allocator` is required, is to create temporary `Client` which you are REQUIRED to manage once `accept` finishes
//!
//! Ensure it lives long enough, if not, there will be consequences!!

const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");
const Client = @import("Client.zig");
const flags = @import("socket.zig").flags;

const Server = @This();

allocator: std.mem.Allocator,
addr: std.net.Address,
userdata: ?*anyopaque,
task: Task,
socket: std.posix.socket_t,
on_accept: *const fn(self: *Server, client: *Client) Task.TaskAction,
loop: ?*Loop,
tmp_client: ?*Client,

/// Initialize `Server` task, `addr` can be any type of socket (UNIX, IPv4, IPv6, ...), `on_accept` runs after a connection has be accepted, `Client` is heap allocated - the user is REQUIRED to manage this memory.
pub fn init(allocator: std.mem.Allocator, addr: std.net.Address, on_accept: *const fn(self: *Server, client: *Client) Task.TaskAction, userdata: ?*anyopaque) !Server {
    return .{
        .allocator = allocator,
        .addr = addr,
        .userdata = userdata,
        .task = Task.init(gen, done),
        .socket = try std.posix.socket(addr.any.family, flags, 0),
        .on_accept = on_accept,
        .tmp_client = null,
        .loop = null,
    };
}

/// Closes the server socket.
pub fn deinit(self: *Server) void {
    std.posix.close(self.socket);
}

/// Register the task on the event loop.
pub fn register(self: *Server, loop: *Loop, backlog: u31, reuse_addr: bool) !void {
    self.loop = loop;

    if (reuse_addr) {
        try std.posix.setsockopt(self.socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    }

    try std.posix.bind(self.socket, &self.addr.any, self.addr.getOsSockLen());
    try std.posix.listen(self.socket, backlog);

    self.task.userdata = @ptrCast(self);
    try loop.add_task(&self.task);
}


fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    const server: *Server = @ptrCast(@alignCast(self.userdata));
    server.tmp_client = try server.allocator.create(Client);
    server.tmp_client.?._initServer(server);

    try rt.queue(aio.op(.accept, .{
        .socket = server.socket,
        .out_socket = &server.tmp_client.?.socket,
        .out_addr = &server.tmp_client.?.sock_addr,
        .inout_addrlen = &server.tmp_client.?.sock_addrlen,
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, failed: bool) Task.TaskAction {
    if (failed) {
        return .disarm;
    }

    const server: *Server = @ptrCast(@alignCast(task.userdata));
    const ret = server.on_accept(server, server.tmp_client.?);

    if (ret == .rearm) {
        server.tmp_client = null;
    }

    return ret;
}
