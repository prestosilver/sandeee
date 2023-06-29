const std = @import("std");
const vecs = @import("../math/vecs.zig");
const sp = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const c = @import("../c.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const files = @import("../system/files.zig");
const audio = @import("../util/audio.zig");

const VERSION = "0.1.0";
const INSTALL_TIME = 1.5;

pub const GSInstall = struct {
    const Self = @This();

    const Status = enum(u8) {
        Naming,
        Settings,
        Installing,
        Done,
    };

    const Settings = [_][3][]const u8{
        .{ "What is the current Hour", "", "00" },
        .{ "What is the current Minute", "", "00" },
        .{ "Do you like \x82\x82\x82", "evil_value", "Yes" },
    };
    const MAX_VALUE_LEN = 128;

    shader: *shd.Shader,
    sb: *batch.SpriteBatch,
    face: *font.Font,
    font_shader: *shd.Shader,
    load_sprite: sp.Sprite,
    selectSound: *audio.Sound,
    audioMan: *audio.Audio,

    settingValues: [Settings.len][MAX_VALUE_LEN]u8 = undefined,
    settingLens: [Settings.len]u8 = [_]u8{0} ** Settings.len,
    timer: f32 = 1,
    settingId: usize = 0,
    status: Status = .Naming,
    diskName: std.ArrayList(u8) = undefined,
    offset: f32 = 0,

    pub fn setup(self: *Self) !void {
        gfx.gContext.color = cols.newColor(0, 0, 0.3333, 1);

        @memset(&self.settingLens, 0);

        self.settingId = 0;
        self.offset = 0;
        self.timer = 1;
        self.status = .Naming;
        self.diskName = std.ArrayList(u8).init(allocator.alloc);
        self.load_sprite.data.color.b = 0;
    }

    pub fn deinit(self: *Self) !void {
        self.diskName.deinit();
    }

    pub fn updateSettingsVals(self: *Self) ![]const u8 {
        var ts = std.time.timestamp();
        var aHours = @as(u64, @intCast(ts)) / std.time.s_per_hour % 24;
        var aMins = @as(u64, @intCast(ts)) / std.time.s_per_min % 60;
        const inputHours = std.fmt.parseInt(i8, self.settingValues[0][0..self.settingLens[0]], 0) catch 0;
        const inputMins = std.fmt.parseInt(i8, self.settingValues[1][0..self.settingLens[1]], 0) catch 0;

        var hoursOffset = @as(i8, @intCast(aHours)) - inputHours;
        var minsOffset = @as(i8, @intCast(aMins)) - inputMins;

        return std.fmt.allocPrint(allocator.alloc, "hours_offset = \"{}\"\nminutes_offset = \"{}\"\n", .{ hoursOffset, minsOffset });
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        var y: f32 = 100 - self.offset;
        defer self.offset = @max(@as(f32, 0), (y + self.offset) - (size.y - 100));

        var titleLine = try std.fmt.allocPrint(allocator.alloc, "Sand\x82\x82\x82 Installer v_{s}", .{VERSION});
        defer allocator.alloc.free(titleLine);
        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = titleLine,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 2;

        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = "Please Enter new disk name:",
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 1;

        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = self.diskName.items,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });

        if (@intFromEnum(self.status) < @intFromEnum(Status.Settings)) return;

        y += self.face.size * 2;
        for (0..self.settingId + 1) |idx| {
            if (idx > Settings.len) return;
            var text = try std.fmt.allocPrint(allocator.alloc, "{s}? [{s}] {s}", .{
                Settings[idx][0],
                Settings[idx][2],
                self.settingValues[idx][0..self.settingLens[idx]],
            });
            defer allocator.alloc.free(text);

            try self.face.draw(.{
                .batch = self.sb,
                .shader = self.font_shader,
                .text = text,
                .pos = vecs.newVec2(100, y),
                .color = cols.newColor(1, 1, 1, 1),
            });
            y += self.face.size * 1;
        }

        if (@intFromEnum(self.status) < @intFromEnum(Status.Installing)) return;

        y += self.face.size * 2;
        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = "Installing",
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 2;

        self.load_sprite.data.size.x = (size.x - 200);
        if (self.status == .Installing) self.load_sprite.data.size.x *= 1 - self.timer;
        try self.sb.draw(sp.Sprite, &self.load_sprite, self.shader, vecs.newVec3(100, y, 0));

        if (@intFromEnum(self.status) < @intFromEnum(Status.Done)) return;

        y += self.face.size * 2;
        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = "Done!",
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 1;

        var rebootLine = try std.fmt.allocPrint(allocator.alloc, "Rebooting in {}", .{@as(u32, @intFromFloat(0.5 + self.timer))});
        defer allocator.alloc.free(rebootLine);

        try self.face.draw(.{
            .batch = self.sb,
            .shader = self.font_shader,
            .text = rebootLine,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.status == .Installing) {
            self.timer -= dt / INSTALL_TIME;
            if (self.timer < 0) {
                self.timer = 3;
                self.status = .Done;

                var vals = try self.updateSettingsVals();
                defer allocator.alloc.free(vals);
                std.log.info("{s}", .{vals});

                try files.Folder.setupDisk(self.diskName.items, vals);
            }
        } else if (self.status == .Done) {
            self.timer -= dt;
            if (self.timer < 0) {
                self.timer = 0;

                events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                    .targetState = .Disks,
                });
            }
        }
    }

    pub fn appendChar(self: *Self, char: u8) !void {
        switch (self.status) {
            .Naming => {
                try self.diskName.append(char);
            },
            .Settings => {
                if (self.settingLens[self.settingId] < MAX_VALUE_LEN) {
                    self.settingValues[self.settingId][self.settingLens[self.settingId]] = char;
                    self.settingLens[self.settingId] += 1;
                }
            },
            else => {},
        }
    }

    pub fn removeChar(self: *Self) !void {
        switch (self.status) {
            .Naming => {
                _ = self.diskName.popOrNull();
            },
            .Settings => {
                if (self.settingLens[self.settingId] > 0) {
                    self.settingLens[self.settingId] -= 1;
                }
            },
            else => {},
        }
    }

    pub fn keypress(self: *Self, keycode: c_int, mods: c_int, down: bool) !bool {
        if (!down) return false;
        switch (keycode) {
            c.GLFW_KEY_A...c.GLFW_KEY_Z => {
                if ((mods & c.GLFW_MOD_SHIFT) != 0) {
                    try self.appendChar(@as(u8, @intCast(keycode - c.GLFW_KEY_A)) + 'A');
                } else {
                    try self.appendChar(@as(u8, @intCast(keycode - c.GLFW_KEY_A)) + 'a');
                }
            },
            c.GLFW_KEY_0...c.GLFW_KEY_9 => {
                try self.appendChar(@as(u8, @intCast(keycode - c.GLFW_KEY_0)) + '0');
            },
            c.GLFW_KEY_PERIOD => {
                try self.appendChar('.');
            },
            c.GLFW_KEY_BACKSPACE => {
                try self.removeChar();
            },
            c.GLFW_KEY_MINUS => {
                try self.appendChar('-');
            },
            c.GLFW_KEY_SPACE => {
                try self.appendChar('_');
            },
            c.GLFW_KEY_ENTER => {
                switch (self.status) {
                    .Naming => {
                        try self.audioMan.playSound(self.selectSound.*);

                        if (self.diskName.items.len == 0) return false;
                        if (std.mem.containsAtLeast(u8, self.diskName.items, 1, ".")) {
                            if (!std.mem.endsWith(u8, self.diskName.items, ".eee")) return false;
                        } else {
                            try self.diskName.appendSlice(".eee");
                        }
                        self.status = .Settings;
                    },
                    .Settings => {
                        try self.audioMan.playSound(self.selectSound.*);

                        if (self.settingLens[self.settingId] == 0) {
                            self.settingLens[self.settingId] = @as(u8, @intCast(Settings[self.settingId][2].len));
                            @memcpy(self.settingValues[self.settingId][0..self.settingLens[self.settingId]], Settings[self.settingId][2]);
                        }

                        self.settingId += 1;
                        if (self.settingId >= Settings.len) {
                            self.status = .Installing;
                            self.settingId -= 1;
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
        return false;
    }

    pub fn keychar(_: *Self, _: u32, _: c_int) !void {}
    pub fn mousepress(_: *Self, _: c_int) !void {}
    pub fn mouserelease(_: *Self) !void {}
    pub fn mousemove(_: *Self, _: vecs.Vector2) !void {}
    pub fn mousescroll(_: *Self, _: vecs.Vector2) !void {}
};
