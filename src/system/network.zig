const std = @import("std");
const allocator = @import("../util/allocator.zig");

const ServeFileError = error{
    RecvHeaderEOF,
    RecvHeaderExceededBuffer,
    HeaderDidNotMatch,
};

pub var server: Server = undefined;

pub const Server = struct {
    const BUFSIZ = 512;

    stream: std.net.StreamServer,
    data: std.AutoHashMap(u8, []u8),

    pub fn init() !Server {
        var listener = std.net.StreamServer.init(.{});

        const self_addr = try std.net.Address.resolveIp("127.0.0.1", 33333);

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
