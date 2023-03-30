const std = @import("std");
const vecs = @import("../math/vecs.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../shader.zig");
const batch = @import("../util/spritebatch.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const c = @import("../c.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const files = @import("../system/files.zig");

const VERSION = "0.0.1";
const INSTALL_TIME = 3;

pub const GSInstall = struct {
    const Self = @This();

    const Status = enum {
        Naming,
        Installing,
        Done,
    };

    shader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,
    load_sprite: sp.Sprite,

    timer: f32 = 1,
    status: Status = .Naming,
    diskName: std.ArrayList(u8) = undefined,

    pub fn setup(self: *Self) !void {
        gfx.gContext.color = cols.newColor(0, 0, 0.3333, 1);

        self.timer = 1;
        self.status = .Naming;
        self.diskName = std.ArrayList(u8).init(allocator.alloc);
        self.load_sprite.data.color.b = 0;
    }

    pub fn deinit(self: *Self) !void {
        self.diskName.deinit();
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        var y: f32 = 100;

        var titleLine = try std.fmt.allocPrint(allocator.alloc, "SandEEE Installer v_{s}", .{VERSION});
        defer allocator.alloc.free(titleLine);
        try self.face.drawScale(self.sb, self.font_shader, titleLine, vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);
        y += self.face.size * 2;

        try self.face.drawScale(self.sb, self.font_shader, "Please Enter new disk name:", vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);
        y += self.face.size * 1;

        try self.face.drawScale(self.sb, self.font_shader, self.diskName.items, vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);

        if (self.status == .Naming) return;
        y += self.face.size * 2;
        try self.face.drawScale(self.sb, self.font_shader, "Installing", vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);
        y += self.face.size * 2;

        self.load_sprite.data.size.x = (size.x - 200);
        if (self.status == .Installing) self.load_sprite.data.size.x *= 1 - self.timer;
        try self.sb.draw(sp.Sprite, &self.load_sprite, self.shader, vecs.newVec3(100, y, 0));

        if (self.status == .Installing) return;
        y += self.face.size * 2;
        try self.face.drawScale(self.sb, self.font_shader, "Done!", vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);
        y += self.face.size * 1;

        var rebootLine = try std.fmt.allocPrint(allocator.alloc, "Rebooting in {}", .{@floatToInt(u32, 0.5 + self.timer)});
        defer allocator.alloc.free(rebootLine);

        try self.face.drawScale(self.sb, self.font_shader, rebootLine, vecs.newVec2(100, y), cols.newColor(1, 1, 1, 1), 1);
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.status == .Installing) {
            self.timer -= dt / INSTALL_TIME;
            if (self.timer < 0) {
                self.timer = 3;
                self.status = .Done;

                try files.Folder.setupDisk(self.diskName.items);
            }
        } else if (self.status == .Done) {
            self.timer -= dt;
            if (self.timer < 0) {
                self.timer = 0;
                events.em.sendEvent(systemEvs.EventStateChange{
                    .targetState = .Disks,
                });
            }
        }
    }

    pub fn keypress(self: *Self, keycode: c_int, mods: c_int) !bool {
        switch (keycode) {
            c.GLFW_KEY_A...c.GLFW_KEY_Z => {
                switch (self.status) {
                    .Naming => {
                        if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                            try self.diskName.append(@intCast(u8, keycode - c.GLFW_KEY_A) + 'A');
                        } else {
                            try self.diskName.append(@intCast(u8, keycode - c.GLFW_KEY_A) + 'a');
                        }
                    },
                    else => {},
                }
            },
            c.GLFW_KEY_0...c.GLFW_KEY_9 => {
                try self.diskName.append(@intCast(u8, keycode - c.GLFW_KEY_0) + '0');
            },
            c.GLFW_KEY_PERIOD => {
                try self.diskName.append('.');
            },
            c.GLFW_KEY_BACKSPACE => {
                _ = self.diskName.popOrNull();
            },
            c.GLFW_KEY_MINUS => {
                try self.diskName.append('-');
            },
            c.GLFW_KEY_ENTER => {
                switch (self.status) {
                    .Naming => {
                        if (self.diskName.items.len == 0) return false;
                        if (std.mem.containsAtLeast(u8, self.diskName.items, 1, ".")) {
                            if (!std.mem.endsWith(u8, self.diskName.items, ".eee")) return false;
                        } else {
                            try self.diskName.appendSlice(".eee");
                        }
                        self.status = .Installing;
                    },
                    else => {},
                }
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
