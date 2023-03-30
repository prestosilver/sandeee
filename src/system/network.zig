const std = @import("std");
const allocator = @import("../util/allocator.zig");

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

    stream: std.net.StreamServer,
    data: std.AutoHashMap(u8, []u8),

    pub fn init() !Server {
        var listener = std.net.StreamServer.init(.{});

        const self_addr = std.net.Address.initIp4([_]u8{ 0, 0, 0, 0 }, PORT);

        try listener.listen(self_addr);

        std.log.debug("Listening on {}", .{self_addr});

        return .{
            .stream = listener,
            .data = std.AutoHashMap(u8, []u8).init(allocator.alloc),
        };
    }

    pub fn send(self: *Server, port: u8, data: []const u8) !void {
        var dat = try allocator.alloc.alloc(u8, data.len);
        std.mem.copy(u8, dat, data);

        std.log.debug("send data to port {}", .{port});

        try self.data.put(port, dat);
    }

    pub fn serve() !void {
        var recv_buf: [BUFSIZ]u8 = undefined;
        var recv_total: usize = 0;

        while (true) {
            var conn = try server.stream.accept();
            std.log.debug("recv on conn {}", .{conn.address});
            while (conn.stream.read(recv_buf[recv_total..])) |recv_len| {
                if (recv_len == 0)
                    break;

                recv_total += recv_len;

                if (recv_total > 1 and recv_total > 1 + recv_buf[1]) break;

                if (recv_total >= recv_buf.len)
                    return ServeFileError.RecvHeaderExceededBuffer;
            } else |read_err| {
                return read_err;
            }

            var port: u8 = recv_buf[0];
            std.log.debug("port active {}", .{port});

            if (server.data.get(port)) |data| {
                std.log.debug("send on port {}", .{port});
                try conn.stream.writeAll(data);
                _ = server.data.remove(port);
            }
            conn.stream.close();
        }
    }
};
