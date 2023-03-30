const std = @import("std");

const Server = struct {
    stream: std.net.StreamServer,
}

pub fn setupServer() Server {
    var listener = std.net.StreamServer.inti(.{});

    const self_addr = try net.Address.resolveIp("127.0.0.1", 33333);

    try listener.listen(self_addr);

    std.log.debug("Listening on {}", .{self_addr});
}
