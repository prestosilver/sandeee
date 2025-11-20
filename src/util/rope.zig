const std = @import("std");

const util = @import("../util/mod.zig");

const allocator = util.allocator;

const Rope = @This();

refs: usize = 0,
string: []const u8,
next: ?*Rope = null,

pub fn init(text: []const u8) !*Rope {
    const self = try allocator.alloc.create(Rope);
    errdefer allocator.alloc.destroy(self);

    self.* = .{
        .refs = 1,
        .string = try allocator.alloc.dupe(u8, text),
    };

    return self;
}

pub fn clone(rope: *Rope) !*Rope {
    return try .initRef(rope);
}

pub fn initRef(rope: *Rope) !*Rope {
    const self = try allocator.alloc.create(Rope);
    errdefer allocator.alloc.destroy(self);

    self.* = .{
        .refs = 1,
        .string = try std.fmt.allocPrint(allocator.alloc, "{}", .{rope}),
    };

    return self;
}

pub fn index(rope: *Rope, idx: usize) ?u8 {
    return if (idx < rope.string.len)
        rope.string[idx]
    else if (rope.next) |next|
        index(next, idx - rope.string.len)
    else
        null;
}

pub fn cat(self: *Rope, other: *Rope) !*Rope {
    var result: *Rope = try .initRef(self);

    other.refs += 1;
    result.next = other;

    return result;
}

pub fn subString(rope: *Rope, start: usize, end: ?usize) !*Rope {
    if (rope.string.len < start)
        if (rope.next) |next| {
            return subString(next, start - rope.string.len, if (end) |e| e - rope.string.len else null);
        };

    const self = try allocator.alloc.create(Rope);
    errdefer allocator.alloc.destroy(self);

    self.* = .{
        .refs = 1,
        .string = try allocator.alloc.dupe(u8, rope.string[@min(start, rope.string.len)..]),
        .next = rope.next,
    };

    if (rope.next) |next|
        next.refs += 1;

    return self;
}

pub fn getLen(self: *const Rope) usize {
    return self.string.len + if (self.next) |next| next.getLen() else 0;
}

pub fn empty(self: *const Rope) bool {
    return self.string.len == 0 and self.next == null;
}

pub fn iterate(self: *const Rope) Iterator {
    return Iterator{ .rope = self };
}

const Iterator = struct {
    rope: *const Rope,
    index: usize = 0,

    pub fn next(self: *Iterator) ?u8 {
        if (self.index < self.rope.string.len) {
            defer self.index += 1;

            return self.rope.string[self.index];
        }

        if (self.rope.next) |next_rope| {
            self.rope = next_rope;
            self.index = 1;
            return self.rope.string[0];
        }

        return null;
    }

    pub fn atEnd(self: *const Iterator) bool {
        return self.index < self.rope.string.len or self.rope.next != null;
    }
};

pub fn eql(self: *const Rope, other: *const Rope) bool {
    var self_iter = self.iterate();
    var other_iter = other.iterate();

    while (true) {
        if (self_iter.next() orelse break != other_iter.next() orelse return false) return false;
    }

    return self_iter.atEnd() and other_iter.atEnd();
}

pub fn deinit(self: *Rope) void {
    self.refs -= 1;

    if (self.refs > 0)
        return;

    if (self.next) |next|
        next.deinit();

    allocator.alloc.free(self.string);

    allocator.alloc.destroy(self);
}

const SkipWriter = struct {
    const Self = @This();

    base: std.io.AnyWriter,
    skip: usize,
    // end: []const u8,

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

pub fn format(value: *const Rope, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    var current: ?*const Rope = value;
    while (current) |node| : (current = node.next) {
        try writer.writeAll(node.string);
    }
}

test "concat" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: *Rope = try .init("ghjkl");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    try std.testing.expectFmt("asdfghjkl", "{}", .{rope_c});
}

test "concat rope" {
    const rope_a: *Rope = try .init("bar");
    defer rope_a.deinit();

    const rope_b: *Rope = try .init("buzz");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    const rope_d: *Rope = try .init("foo");
    defer rope_d.deinit();

    const rope_e = try rope_d.cat(rope_c);
    defer rope_e.deinit();

    try std.testing.expectFmt("foobarbuzz", "{}", .{rope_e});
}

test "substring overflow" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b = try rope_a.subString(1, null);
    defer rope_b.deinit();

    const rope_c = try rope_b.subString(1, null);
    defer rope_c.deinit();

    const rope_d = try rope_c.subString(2, null);
    defer rope_d.deinit();

    const rope_e: *Rope = try .init("asdf");
    defer rope_e.deinit();

    const rope_f = try rope_d.cat(rope_e);
    defer rope_f.deinit();

    try std.testing.expectFmt("sdf", "{}", .{rope_b});
    try std.testing.expectFmt("df", "{}", .{rope_c});
    try std.testing.expectFmt("", "{}", .{rope_d});
    try std.testing.expectFmt("asdf", "{}", .{rope_f});
}

test "substring cat" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: *Rope = try .init("asdf");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    try std.testing.expectFmt("asdfasdf", "{}", .{rope_c});
    const rope_d = try rope_c.subString(5, null);
    defer rope_d.deinit();

    try std.testing.expectFmt("sdf", "{}", .{rope_d});
}

test "index" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    try std.testing.expectEqual('a', rope_a.index(0));
}
