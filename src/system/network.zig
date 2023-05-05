const std = @import("std");
const allocator = @import("../util/allocator.zig");
const network = @import("network");

const ServeFileError = error{
    RecvHeaderEOF,
    RecvHeaderExceededBuffer,
    HeaderDidNotMatch,
};

pub var server: Server = undefined;
const PORT = 33333;

pub const Client = struct {
    port: u8,
    host: []const u8,

    pub fn send(self: *Client, data: []const u8) ![]const u8 {
        var stream = try std.net.tcpConnectToHost(allocator.alloc, self.host, PORT);
        var toWrite = try std.fmt.allocPrint(allocator.alloc, "{s}{s}{s}", .{ @ptrCast(*const [1]u8, &self.port), @ptrCast(*const [1]u8, &data.len), data });

        _ = try stream.write(toWrite);

        var recv_buf = try allocator.alloc.alloc(u8, 100);
        var len = try stream.readAll(recv_buf);
        recv_buf.len = len;
        std.log.info("recived: '{s}'", .{recv_buf});

        allocator.alloc.free(toWrite);

        return recv_buf;
    }
};

pub const Server = struct {
    const BUFSIZ = 512;

    data: std.AutoHashMap(u8, []u8),
    input: std.AutoHashMap(u8, []u8),
    sock: network.Socket,

    pub fn init() !Server {
        try network.init();

        var sock = try network.Socket.create(.ipv4, .tcp);
        var bindAddr = network.EndPoint{
            .address = network.Address{
                .ipv4 = network.Address.IPv4.any,
            },
            .port = PORT,
        };

        try sock.bind(bindAddr);

        return .{
            .sock = sock,
            .data = std.AutoHashMap(u8, []u8).init(allocator.alloc),
            .input = std.AutoHashMap(u8, []u8).init(allocator.alloc),
        };
    }

    pub fn deinit(self: *Server) !void {
        self.sock.deinit();
        network.deinit();
    }

    pub fn send(self: *Server, port: u8, data: []const u8) !void {
        var dat = try allocator.alloc.dupe(u8, data);

        std.log.debug("send data to port {}", .{port});

        try self.data.put(port, dat);
    }

    pub fn serve() !void {
        var recv_buf: [BUFSIZ]u8 = undefined;

        try server.sock.listen();

        while (true) {
            var client = try server.sock.accept();
            defer client.close();

            std.log.info("client: {}", .{try client.getLocalEndPoint()});

            const len = try client.receive(&recv_buf);
            if (len == 0) continue;

            var port = recv_buf[0];
            if (len > 1)
                try server.input.put(port, recv_buf[1..]);

            if (server.data.get(port)) |data| {
                _ = try client.send(data);
            }
        }
    }
};
