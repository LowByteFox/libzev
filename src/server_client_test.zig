const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");

const Client = @import("Client.zig");
const Server = @import("Server.zig");

var buffer: [1024]u8 = undefined;

fn accepted(_: *Server, client: *Client) Task.TaskAction {
    std.debug.print("Recieved connection!\n", .{});

    client.write("Hello from libzev!", null) catch unreachable;

    return .disarm;
}

fn connected(client: *Client) void {
    std.debug.print("Connected to the Server!\n", .{});

    client.read(&buffer, on_read) catch unreachable;
}

fn on_read(client: *Client, buf: []u8, _: usize) Task.TaskAction {
    std.debug.print("Recieved: {s}\n", .{buf});

    client.deinit();
    return .disarm;
}

test "server on_accept/client on_connect" {
    var loop = try Loop.init(std.testing.allocator, 4096);
    defer loop.deinit();

    const addr = try std.net.Address.initUnix("/tmp/zig.sock");
    var server = try Server.init(std.testing.allocator, addr, accepted, null);
    try server.register(&loop, 8, false);

    var client = try Client.init(addr, connected, null);
    try client.register(&loop);

    while (try loop.tick(.blocking) > 0) {}

    server.deinit();
    try std.fs.deleteFileAbsolute("/tmp/zig.sock");
}
