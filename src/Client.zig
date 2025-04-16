const std = @import("std");
const aio = @import("aio");
const Loop = @import("Loop.zig");
const Task = @import("Task.zig");
const Server = @import("Server.zig");
const flags = @import("socket.zig").flags;

const Client = @This();

userdata: ?*anyopaque,
task: Task,
addr: std.net.Address,
on_connect: *const fn(self: *Client) void,

// INFO: Server fills those in
socket: std.posix.socket_t,
loop: ?*Loop,
reader: Reader,
writer: Writer,
sock_addr: std.posix.sockaddr = undefined,
sock_addrlen: std.posix.socklen_t = undefined,

pub fn init(addr: std.net.Address, on_connect: *const fn(self: *Client) void, userdata: ?*anyopaque) !Client {
    return .{
        .addr = addr,
        .userdata = userdata,
        .task = Task.init(gen, done),
        .socket = try std.posix.socket(addr.any.family, flags, 0),
        .on_connect = on_connect,
        .reader = Reader.init(),
        .writer = Writer.init(),
        .loop = null,
    };
}

pub fn initServer(self: *Client, server: *Server) void {
    self.sock_addrlen = @sizeOf(std.posix.socket_t);
    self.loop = server.loop;
    self.reader = Reader.init();
    self.writer = Writer.init();
}

pub fn register(self: *Client, loop: *Loop) !void {
    self.loop = loop;

    self.task.userdata = @ptrCast(self);
    try loop.add_task(&self.task);
}

pub fn deinit(self: *Client) void {
    std.posix.close(self.socket);
}

fn gen(self: *Task, rt: *aio.Dynamic) anyerror!void {
    const client: *Client = @ptrCast(@alignCast(self.userdata));
    
    try rt.queue(aio.op(.connect, .{
        .socket = client.socket,
        .addr = &client.addr.any,
        .addrlen = client.addr.getOsSockLen(),
        .userdata = @intFromPtr(self),
    }, .unlinked), {});
}

fn done(task: *Task, failed: bool) Task.TaskAction {
    if (failed) {
        return .disarm;
    }

    const client: *Client = @ptrCast(@alignCast(task.userdata));
    client.on_connect(client);

    return .disarm;
}

pub fn read(self: *Client, buffer: []u8, fun: ?*const fn(self: *Client, buffer: []u8, read: usize) Task.TaskAction) !void {
    self.reader.buffer = buffer;
    self.reader.fun = fun;

    self.reader.task.userdata = @ptrCast(self);
    try self.loop.?.add_task(&self.reader.task);
}

pub fn write(self: *Client, buffer: []const u8, fun: ?*const fn(self: *Client, buffer: []const u8, write: usize) Task.TaskAction) !void {
    self.writer.buffer = buffer;
    self.writer.fun = fun;

    self.writer.task.userdata = @ptrCast(self);
    try self.loop.?.add_task(&self.writer.task);
}


const Reader = struct {
    const Self = @This();

    task: Task,
    buffer: ?[]u8,
    out_read: usize,
    fun: ?*const fn(self: *Client, buffer: []u8, read: usize) Task.TaskAction,

    pub fn init() Self {
        return .{
            .task = Task.init(Self.gen, Self.done),
            .buffer = null,
            .out_read = 0,
            .fun = null,
        };
    }

    pub fn updateBuffer(self: *Self, buffer: []u8) void {
        self.buffer = buffer;
    }

    fn gen(task: *Task, rt: *aio.Dynamic) anyerror!void {
        const client: *Client = @ptrCast(@alignCast(task.userdata));
        client.reader.out_read = 0;

        try rt.queue(aio.op(.recv, .{
            .socket = client.socket,
            .buffer = client.reader.buffer.?,
            .out_read = &client.reader.out_read,
            .userdata = @intFromPtr(task),
        }, .unlinked), {});
    }

    fn done(task: *Task, _: bool) Task.TaskAction {
        const client: *Client = @ptrCast(@alignCast(task.userdata));

        if (client.reader.fun) |f| {
            return f(client, client.reader.buffer.?, client.reader.out_read);
        }

        return .disarm;
    }
};

const Writer = struct {
    const Self = @This();

    task: Task,
    buffer: ?[]const u8,
    out_write: usize,
    fun: ?*const fn(self: *Client, buffer: []const u8, write: usize) Task.TaskAction,

    pub fn init() Self {
        return .{
            .task = Task.init(Self.gen, Self.done),
            .buffer = null,
            .out_write = 0,
            .fun = null,
        };
    }

    pub fn updateBuffer(self: *Self, buffer: []const u8) void {
        self.buffer = buffer;
    }

    fn gen(task: *Task, rt: *aio.Dynamic) anyerror!void {
        const client: *Client = @ptrCast(@alignCast(task.userdata));
        client.writer.out_write = 0;

        try rt.queue(aio.op(.send, .{
            .socket = client.socket,
            .buffer = client.writer.buffer.?,
            .out_written = &client.writer.out_write,
            .userdata = @intFromPtr(task),
        }, .unlinked), {});
    }

    fn done(task: *Task, _: bool) Task.TaskAction {
        const client: *Client = @ptrCast(@alignCast(task.userdata));

        if (client.writer.fun) |f| {
            return f(client, client.writer.buffer.?, client.writer.out_write);
        }

        return .disarm;
    }
};
