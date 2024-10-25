const std = @import("std");

const HttpClient = @This();

const HEADER_SIZE = 1024;

header_buffer: []u8,
client: std.http.Client,
allocator: std.mem.Allocator,
cancel: bool = false,
running: bool = false,

pub fn init(allocator: std.mem.Allocator) !HttpClient {
    return .{
        .header_buffer = try allocator.alloc(u8, HEADER_SIZE),
        .client = .{ .allocator = allocator },
        .allocator = allocator,
    };
}

pub fn fetch(self: *HttpClient, url: []const u8) ![]const u8 {
    if (url.len == 0) return error.BadRemote;
    if (url[0] != '@') return error.BadRemote;

    const idx = std.mem.indexOf(u8, url, ":") orelse {
        return error.BadRemote;
    };

    const uri = std.Uri{
        .scheme = "http",
        .host = .{ .raw = url[1..idx] },
        .path = .{ .raw = url[idx + 1 ..] },
        .port = 80,
    };

    var req = try self.client.open(.GET, uri, .{
        .server_header_buffer = self.header_buffer,
        .headers = .{
            .user_agent = .{ .override = "SandEEE/0.0" },
            .connection = .{ .override = "Close" },
        },
    });
    defer req.deinit();
    try req.send();

    self.running = true;

    defer {
        self.cancel = false;
        self.running = false;
    }

    wait: {
        // rest is from std/http/Client.zig but with a cancel
        while (true) {
            if (self.cancel) return error.Canceled;

            // This while loop is for handling redirects, which means the request's
            // connection may be different than the previous iteration. However, it
            // is still guaranteed to be non-null with each iteration of this loop.
            const connection = req.connection.?;

            while (true) { // read headers
                if (self.cancel) return error.Canceled;

                try connection.fill();

                const nchecked = try req.response.parser.checkCompleteHead(connection.peek());
                connection.drop(@intCast(nchecked));

                if (req.response.parser.state.isContent()) break;
            }

            try req.response.parse(req.response.parser.get());

            if (req.response.status == .@"continue") {
                // We're done parsing the continue response; reset to prepare
                // for the real response.
                req.response.parser.done = true;
                req.response.parser.reset();

                if (req.handle_continue)
                    continue;

                break :wait; // we're not handling the 100-continue
            }

            // we're switching protocols, so this connection is no longer doing http
            if (req.method == .CONNECT and req.response.status.class() == .success) {
                connection.closing = false;
                req.response.parser.done = true;
                break :wait; // the connection is not HTTP past this point
            }

            connection.closing = !req.response.keep_alive or !req.keep_alive;

            // Any response to a HEAD request and any response with a 1xx
            // (Informational), 204 (No Content), or 304 (Not Modified) status
            // code is always terminated by the first empty line after the
            // header fields, regardless of the header fields present in the
            // message.
            if (req.method == .HEAD or req.response.status.class() == .informational or
                req.response.status == .no_content or req.response.status == .not_modified)
            {
                req.response.parser.done = true;
                break :wait; // The response is empty; no further setup or redirection is necessary.
            }

            switch (req.response.transfer_encoding) {
                .none => {
                    if (req.response.content_length) |cl| {
                        req.response.parser.next_chunk_length = cl;

                        if (cl == 0) req.response.parser.done = true;
                    } else {
                        // read until the connection is closed
                        req.response.parser.next_chunk_length = std.math.maxInt(u64);
                    }
                },
                .chunked => {
                    req.response.parser.next_chunk_length = 0;
                    req.response.parser.state = .chunk_head_size;
                },
            }

            if (req.response.status.class() == .redirect and req.redirect_behavior != .unhandled) {
                // skip the body of the redirect response, this will at least
                // leave the connection in a known good state.
                req.response.skip = true;
                std.debug.assert( // we're skipping, no buffer is necessary
                    transfer_read: {
                    if (req.response.parser.done) break :transfer_read 0;

                    var index: usize = 0;
                    while (index == 0) {
                        const amt = try req.response.parser.read(req.connection.?, &.{}, req.response.skip);
                        if (amt == 0 and req.response.parser.done) break;
                        index += amt;
                    }

                    break :transfer_read index;
                } == 0);

                if (req.redirect_behavior == .not_allowed) return error.TooManyHttpRedirects;

                const location = req.response.location orelse
                    return error.HttpRedirectLocationMissing;

                // This mutates the beginning of header_bytes_buffer and uses that
                // for the backing memory of the returned Uri.
                try req.redirect(req.uri.resolve_inplace(
                    location,
                    &req.response.parser.header_bytes_buffer,
                ) catch |err| switch (err) {
                    error.UnexpectedCharacter,
                    error.InvalidFormat,
                    error.InvalidPort,
                    => return error.HttpRedirectLocationInvalid,
                    error.NoSpaceLeft => return error.HttpHeadersOversize,
                });
                try req.send();
            } else {
                req.response.skip = false;
                if (!req.response.parser.done) {
                    switch (req.response.transfer_compression) {
                        .identity => req.response.compression = .none,
                        .compress, .@"x-compress" => return error.CompressionUnsupported,
                        .deflate => req.response.compression = .{
                            .deflate = std.compress.zlib.decompressor(req.transferReader()),
                        },
                        .gzip, .@"x-gzip" => req.response.compression = .{
                            .gzip = std.compress.gzip.decompressor(req.transferReader()),
                        },
                        // https://github.com/ziglang/zig/issues/18937
                        //.zstd => req.response.compression = .{
                        //    .zstd = std.compress.zstd.decompressStream(req.client.allocator, req.transferReader()),
                        //},
                        .zstd => return error.CompressionUnsupported,
                    }
                }

                break;
            }
        }
    }
}

pub fn doCancel(self: *HttpClient) !void {
    self.cancel = true;

    while (self.running) {
        std.Thread.yield();
    }
}

pub fn deinit(self: *HttpClient) void {
    self.allocator.free(self.header_buffer);
    self.client.deinit();
}
