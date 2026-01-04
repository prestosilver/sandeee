const std = @import("std");

const util = @import("../util.zig");

const allocator = util.allocator;

const log = util.log;

const Rope = @This();

data: []const u8,

pub fn init(text: []const u8) !Rope {
    return .{
        .data = try allocator.dupe(u8, text),
    };
}

pub fn clone(rope: Rope) !Rope {
    return try .initRef(rope);
}

pub fn initRef(rope: Rope) !Rope {
    return .init(rope.data);
}

pub inline fn len(rope: *const Rope) usize {
    return rope.data.len;
}

pub inline fn index(rope: *const Rope, idx: usize) ?u8 {
    return if (idx < rope.data.len)
        rope.data[idx]
    else
        null;
}

pub fn cat(self: Rope, other: Rope) !Rope {
    const str = try std.mem.concat(allocator, u8, &.{ self.data, other.data });
    defer allocator.free(str);

    return .init(str);
}

pub fn subString(rope: *const Rope, start: usize, end: ?usize) !Rope {
    const start_idx = @min(start, rope.data.len);
    const end_idx = if (end) |e| @max(start_idx, rope.data.len - e) else rope.data.len;

    return try .init(rope.data[start_idx..end_idx]);
}

pub fn empty(self: *const Rope) bool {
    return self.data.len == 0;
}

pub fn iterate(self: *const Rope) Iterator {
    return Iterator{ .rope = self };
}

const Iterator = struct {
    rope: Rope,
    index: usize = 0,

    pub fn next(self: *Iterator) ?u8 {
        if (self.index >= self.rope.len()) return null;

        self.index += 1;

        return self.rope.data[self.index - 1];
    }

    pub fn atEnd(self: *const Iterator) bool {
        return self.index >= self.rope.len();
    }
};

pub fn eql(self: Rope, other: Rope) bool {
    return std.mem.eql(u8, self.data, other.data);
}

pub fn deinit(self: Rope) void {
    allocator.free(self.data);
}

const SkipWriter = struct {
    const Self = @This();

    base: std.io.AnyWriter,
    skip: usize,

    fn write(
        self: *Self,
        bytes: []const u8,
    ) std.io.AnyWriter.Error!usize {
        const skip = @min(self.skip, bytes.len);
        self.skip -= skip;

        return skip + try self.base.write(bytes[skip..]);
    }

    pub const Writer = std.io.Writer(*Self, std.io.AnyWriter.Error, write);
};

pub fn format(rope: *const Rope, writer: anytype) !void {
    try writer.writeAll(rope.data);
}

test "concat" {
    const rope_a: Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: Rope = try .init("ghjkl");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    try std.testing.expectFmt("asdfghjkl", "{f}", .{rope_c});
}

test "concat rope" {
    const rope_a: Rope = try .init("bar");
    defer rope_a.deinit();

    const rope_b: Rope = try .init("buzz");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    const rope_d: Rope = try .init("foo");
    defer rope_d.deinit();

    const rope_e = try rope_d.cat(rope_c);
    defer rope_e.deinit();

    try std.testing.expectFmt("foobarbuzz", "{f}", .{rope_e});
}

test "substring overflow" {
    const rope_a: Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b = try rope_a.subString(1, null);
    defer rope_b.deinit();

    const rope_c = try rope_b.subString(1, null);
    defer rope_c.deinit();

    const rope_d = try rope_c.subString(2, null);
    defer rope_d.deinit();

    const rope_e: Rope = try .init("asdf");
    defer rope_e.deinit();

    const rope_f = try rope_d.cat(rope_e);
    defer rope_f.deinit();

    try std.testing.expectFmt("sdf", "{f}", .{rope_b});
    try std.testing.expectFmt("df", "{f}", .{rope_c});
    try std.testing.expectFmt("", "{f}", .{rope_d});
    try std.testing.expectFmt("asdf", "{f}", .{rope_f});
}

test "substring cat" {
    const rope_a: Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: Rope = try .init("asdf");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    try std.testing.expectFmt("asdfasdf", "{f}", .{rope_c});
    const rope_d = try rope_c.subString(5, null);
    defer rope_d.deinit();

    try std.testing.expectFmt("sdf", "{f}", .{rope_d});

    const rope_e = try rope_c.subString(0, 5);
    defer rope_e.deinit();

    try std.testing.expectFmt("asd", "{f}", .{rope_e});
}

test "index" {
    const rope_a: Rope = try .init("asdf");
    defer rope_a.deinit();

    try std.testing.expectEqual('a', rope_a.index(0));
}
