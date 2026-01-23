const std = @import("std");

const util = @import("../util.zig");

const allocator = util.allocator;

const log = util.log;

const Rope = @This();

const RopeKind = enum {
    string,
    ref,
};

const RopeData = struct {
    refs: usize = 0,
    data: union(RopeKind) {
        string: []const u8,
        ref: Rope,
    },
    next: ?Rope = null,
};

data: *RopeData,

pub fn init(text: []const u8) !Rope {
    const data = try allocator.create(RopeData);
    errdefer allocator.destroy(data);

    data.* = .{
        .refs = 1,
        .data = .{
            .string = try allocator.dupe(u8, text),
        },
    };

    return .{ .data = data };
}

pub fn clone(rope: Rope) !Rope {
    return try .initRef(rope);
}

pub fn initRef(rope: Rope) !Rope {
    const data = try allocator.create(RopeData);
    errdefer allocator.destroy(data);

    data.* = .{
        .refs = 1,
        .data = .{
            .ref = .{ .data = rope.data },
        },
    };

    rope.data.refs += 1;

    log.info("init rope ref: {f}", .{Rope{ .data = data }});

    return .{ .data = data };
}

pub fn len(rope: *const Rope) usize {
    return switch (rope.data.data) {
        .string => |str| str.len,
        .ref => |ref| ref.len(),
    } + if (rope.data.next) |next| next.len() else 0;
}

pub fn index(rope: *const Rope, idx: usize) ?u8 {
    return switch (rope.data.data) {
        .string => |str| return if (idx < str.len)
            str[idx]
        else if (rope.data.next) |next|
            index(&next, idx - str.len)
        else
            null,
        .ref => |ref| return if (idx < ref.len())
            ref.index(idx)
        else if (rope.data.next) |next|
            next.index(idx - ref.len())
        else
            null,
    };
}

pub fn cat(self: Rope, other: Rope) !Rope {
    var result: Rope = try .initRef(self);

    other.data.refs += 1;
    result.data.next = other;

    return result;
}

pub fn subString(rope: *const Rope, start: usize, end: ?usize) !Rope {
    switch (rope.data.data) {
        .string => |str| if (str.len < start)
            if (rope.data.next) |next| {
                return subString(&next, start - str.len, if (end) |e| e - str.len else null);
            },
        .ref => |ref| if (ref.len() < start)
            if (rope.data.next) |next| {
                return subString(&next, start - ref.len(), if (end) |e| e - ref.len() else null);
            },
    }

    const string = try std.fmt.allocPrint(allocator, "{f}", .{rope});
    defer allocator.free(string);

    const start_idx = @min(start, string.len);
    const end_idx = if (end) |e| @max(start_idx, string.len - e) else string.len;

    return try .init(string[start_idx..end_idx]);
}

pub fn empty(self: *const Rope) bool {
    return self.data.next == null and switch (self.data.data) {
        .string => |str| str.len == 0,
        .ref => |ref| ref.empty(),
    };
}

pub fn iterate(self: Rope) Iterator {
    return Iterator{ .rope = self };
}

const Iterator = struct {
    rope: Rope,
    child: ?*Iterator = null,
    index: usize = 0,

    pub fn next(self: *Iterator) ?u8 {
        if (self.child) |child| {
            if (child.next()) |nxt|
                return nxt
            else {
                allocator.destroy(child);
                self.child = null;
                return self.next();
            }
        }

        switch (self.rope.data.data) {
            .string => |str| {
                if (self.index < str.len) {
                    defer self.index += 1;

                    return str[self.index];
                }

                if (self.rope.data.next) |next_rope| {
                    self.rope = next_rope;
                    self.index = 0;
                    return self.next();
                }
            },
            .ref => |r| {
                if (self.rope.data.next) |next_rope| {
                    self.child = allocator.create(Iterator) catch unreachable;
                    self.child.?.* = .{
                        .rope = r,
                        .index = 0,
                    };

                    self.rope = next_rope;
                    self.index = 0;
                    return self.child.?.next();
                } else {
                    self.rope = r;
                    self.index = 0;
                    return self.next();
                }
            },
        }

        return null;
    }

    pub fn atEnd(self: *const Iterator) bool {
        if (self.child) |_| return false;

        return switch (self.rope.data.data) {
            .string => |str| self.index >= str.len,
            .ref => |_| false,
        } and self.rope.data.next == null;
    }
};

pub fn eql(self: Rope, other: Rope) bool {
    var self_iter = self.iterate();
    var other_iter = other.iterate();

    while (true) {
        if ((self_iter.next() orelse break) != (other_iter.next() orelse return false)) return false;
    }

    return self_iter.atEnd() and other_iter.atEnd();
}

pub fn deinit(self: Rope) void {
    self.data.refs -= 1;

    if (self.data.refs > 0)
        return;

    if (self.data.next) |next|
        next.deinit();

    switch (self.data.data) {
        .string => |str| allocator.free(str),
        .ref => |r| r.deinit(),
    }

    allocator.destroy(self.data);
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

pub fn format(value: *const Rope, writer: anytype) !void {
    var current: ?Rope = value.*;
    while (current) |node| : (current = node.data.next) {
        switch (node.data.data) {
            .string => |str| try writer.writeAll(str),
            .ref => |ref| try writer.print("{f}", .{ref}),
        }
    }
}

test "concat" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: *Rope = try .init("ghjkl");
    defer rope_b.deinit();

    const rope_c = try rope_a.cat(rope_b);
    defer rope_c.deinit();

    try std.testing.expectFmt("asdfghjkl", "{f}", .{rope_c});
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

    try std.testing.expectFmt("foobarbuzz", "{f}", .{rope_e});
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

    try std.testing.expectFmt("sdf", "{f}", .{rope_b});
    try std.testing.expectFmt("df", "{f}", .{rope_c});
    try std.testing.expectFmt("", "{f}", .{rope_d});
    try std.testing.expectFmt("asdf", "{f}", .{rope_f});
}

test "substring cat" {
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    const rope_b: *Rope = try .init("asdf");
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
    const rope_a: *Rope = try .init("asdf");
    defer rope_a.deinit();

    try std.testing.expectEqual('a', rope_a.index(0));
}
