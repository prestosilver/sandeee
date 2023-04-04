const std = @import("std");
const shd = @import("../util/shader.zig");
const sb = @import("../util/spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");

const c = @import("../c.zig");

pub const GSDisks = struct {
    const Self = @This();
    const VERSION = "0.0.1";

    face: *font.Font,
    font_shader: *shd.Shader,
    shader: *shd.Shader,
    sb: *sb.SpriteBatch,
    logo_sprite: sp.Sprite,
    disk: *?[]u8,

    remaining: f32 = 3,
    sel: usize = 0,
    auto: bool = true,
    disks: std.ArrayList([]const u8) = undefined,

    pub fn setup(self: *Self) !void {
        gfx.gContext.color = cols.newColor(0, 0, 0, 1);

        self.sel = 0;
        self.auto = true;
        self.remaining = 3;
        self.disks = std.ArrayList([]const u8).init(allocator.alloc);

        const dir = try std.fs.cwd().openIterableDir("disks", .{});

        var iter = dir.iterate();

        while (try iter.next()) |item| {
            var entry = try allocator.alloc.alloc(u8, item.name.len);

            std.mem.copy(u8, entry, item.name);

            try self.disks.append(entry);
        }

        try self.disks.append("New Disk");
    }

    pub fn deinit(self: *Self) !void {
        for (self.disks.items[0 .. self.disks.items.len - 1]) |item| {
            allocator.alloc.free(item);
        }

        self.disks.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.auto) self.remaining -= dt;

        if (self.remaining <= 0) {
            self.disk.* = null;

            if (self.sel != self.disks.items.len - 1) {
                var sel = self.disks.items[self.sel];

                self.disk.* = try allocator.alloc.alloc(u8, sel.len);
                std.mem.copy(u8, self.disk.*.?, sel);
            }

            if (self.disk.* != null) {
                events.em.sendEvent(systemEvs.EventStateChange{
                    .targetState = .Loading,
                });
            } else {
                events.em.sendEvent(systemEvs.EventStateChange{
                    .targetState = .Installer,
                });
            }
        }
    }

    pub fn draw(self: *Self, _: vecs.Vector2) !void {
        var pos = vecs.newVec2(100, 100);

        var line: []u8 = undefined;

        try self.sb.draw(sp.Sprite, &self.logo_sprite, self.shader, vecs.newVec3(pos.x, pos.y, 0));
        pos.y += self.logo_sprite.data.size.y;

        if (self.auto) {
            line = try std.fmt.allocPrint(allocator.alloc, "BootEEE V_{s} Booting to disk.eee in {}s", .{ VERSION, @floatToInt(i32, self.remaining + 0.5) });
        } else {
            line = try std.fmt.allocPrint(allocator.alloc, "BootEEE V_{s}", .{VERSION});
        }

        try self.face.drawScale(self.sb, self.font_shader, line, pos, cols.newColor(0.7, 0.7, 0.7, 1), 1, null);
        pos.y += self.face.size * 2;
        try self.face.drawScale(self.sb, self.font_shader, "Select a disk", pos, cols.newColor(0.7, 0.7, 0.7, 1), 1, null);
        pos.y += self.face.size * 1;

        if (self.disks.items.len != 0) {
            for (self.disks.items, 0..) |disk, idx| {
                allocator.alloc.free(line);

                line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{disk});
                if (idx == self.sel) {
                    line[0] = '>';
                }

                try self.face.drawScale(self.sb, self.font_shader, line, pos, cols.newColor(0.7, 0.7, 0.7, 1), 1, null);
                pos.y += self.face.size * 1;
            }
        }
        allocator.alloc.free(line);
    }

    pub fn keypress(self: *Self, key: c_int, _: c_int) !bool {
        self.auto = false;
        switch (key) {
            c.GLFW_KEY_ENTER => {
                self.remaining = 0;
            },
            c.GLFW_KEY_DOWN => {
                if (self.sel < self.disks.items.len - 1)
                    self.sel += 1;
            },
            c.GLFW_KEY_UP => {
                if (self.sel != 0)
                    self.sel -= 1;
            },
            else => {},
        }

        return false;
    }

    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
