const std = @import("std");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const font = @import("../util/font.zig");
const vecs = @import("../math/vecs.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const allocator = @import("../util/allocator.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");

const c = @import("../c.zig");

const VERSION = "0.0.0";

pub const GSRecovery = struct {
    const Self = @This();

    shader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,

    sel: usize = 0,
    disks: std.ArrayList([]const u8) = undefined,

    const DISK_LIST = "0123456789ABCDEF";
    const TEXT_COLOR = cols.newColor(1, 1, 1, 1);

    pub fn getDate(name: []const u8) i128 {
        var path = std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{name}) catch return 0;
        defer allocator.alloc.free(path);
        var file = std.fs.cwd().openFile(path, .{}) catch return 0;
        defer file.close();
        return (file.metadata() catch return 0).modified();
    }

    pub fn sortDisksLt(_: u8, a: []const u8, b: []const u8) bool {
        return getDate(b) < getDate(a);
    }

    pub fn setup(self: *Self) !void {
        gfx.gContext.color = cols.newColor(0, 0, 1, 1);

        self.disks = std.ArrayList([]const u8).init(allocator.alloc);

        const dir = try std.fs.cwd().openIterableDir("disks", .{});

        var iter = dir.iterate();

        while (try iter.next()) |item| {
            var entry = try allocator.alloc.alloc(u8, item.name.len);

            std.mem.copy(u8, entry, item.name);

            try self.disks.append(entry);
        }

        var und: u8 = undefined;

        std.sort.sort([]const u8, self.disks.items, und, sortDisksLt);

        for (self.disks.items, 0..) |_, idx| {
            var copy = self.disks.items[idx];
            defer allocator.alloc.free(copy);

            self.disks.items[idx] = try std.fmt.allocPrint(allocator.alloc, "{c} {s}", .{ DISK_LIST[idx], copy });
        }

        self.disks.items.len = @min(self.disks.items.len, DISK_LIST.len);

        try self.disks.append("X Back");
    }

    pub fn deinit(self: *Self) !void {
        for (self.disks.items[0 .. self.disks.items.len - 1]) |item| {
            allocator.alloc.free(item);
        }

        self.disks.deinit();
    }

    pub fn update(_: *Self, _: f32) !void {}

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        _ = size;
        var y: f32 = 100;

        var titleLine = try std.fmt.allocPrint(allocator.alloc, "SandEEE Recovery v_{s}", .{VERSION});
        defer allocator.alloc.free(titleLine);
        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = titleLine,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 2;

        if (self.disks.items.len != 0) {
            for (self.disks.items, 0..) |disk, idx| {
                var line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{disk});
                defer allocator.alloc.free(line);

                if (idx == self.sel) {
                    line[0] = '>';
                }

                try self.face.draw(.{
                    .batch = self.sb,
                    .shader = self.font_shader,
                    .text = line,
                    .pos = vecs.newVec2(100, y),
                    .color = TEXT_COLOR,
                });
                y += self.face.size * 1;
            }
        }
    }

    pub fn keypress(self: *Self, key: c_int, _: c_int, down: bool) !bool {
        if (!down) return false;
        switch (key) {
            c.GLFW_KEY_ENTER => {
                if (self.sel == self.disks.items.len - 1)
                    events.em.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Disks,
                    });
            },
            c.GLFW_KEY_DOWN => {
                if (self.sel < self.disks.items.len - 1)
                    self.sel += 1;
            },
            c.GLFW_KEY_UP => {
                if (self.sel != 0)
                    self.sel -= 1;
            },
            else => {
                if (c.glfwGetKeyName(key, 0) == null) return false;
                for (self.disks.items, 0..) |disk, idx| {
                    if (c.glfwGetKeyName(key, 0)[0] == disk[0]) {
                        self.sel = idx;
                        // self.remaining = 0;
                    }
                }
            },
        }

        return false;
    }
    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
