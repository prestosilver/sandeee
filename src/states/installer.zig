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
const system_events = @import("../events/system.zig");
const files = @import("../system/files.zig");
const audio = @import("../util/audio.zig");

const VERSION = "0.2.0";
const INSTALL_TIME = 1.5;

pub const GSInstall = struct {
    const Self = @This();

    const Status = enum(u8) {
        Naming,
        Settings,
        Installing,
        Done,
    };

    const SETTINGS = [_][3][]const u8{
        .{ "What is the current Hour", "", "00" },
        .{ "What is the current Minute", "", "00" },
        .{ "Do you want to keep the CRT Shader", "crt_shader", "Yes" },
        .{ "Do you like " ++ font.EEE, "evil_value", "Yes" },
    };

    const MAX_VALUE_LEN = 16;

    shader: *shd.Shader,
    face: *font.Font,
    font_shader: *shd.Shader,
    load_sprite: sp.Sprite,
    select_sound: *audio.Sound,

    setting_values: [SETTINGS.len][MAX_VALUE_LEN]u8 = undefined,
    setting_lengths: [SETTINGS.len]u8 = [_]u8{0} ** SETTINGS.len,
    setting_id: usize = 0,

    timer: f32 = 1,
    status: Status = .Naming,
    disk_name: std.ArrayList(u8) = undefined,
    offset: f32 = 0,

    pub fn setup(self: *Self) !void {
        gfx.Context.instance.color = .{ .r = 0, .g = 0, .b = 0.5 };

        @memset(&self.setting_lengths, 0);

        self.setting_id = 0;
        self.offset = 0;
        self.timer = 1;
        self.status = .Naming;
        self.disk_name = std.ArrayList(u8).init(allocator.alloc);
        self.load_sprite.data.color.b = 0;
    }

    pub fn updateSettingsVals(self: *Self) ![]const u8 {
        const ts = std.time.timestamp();
        const system_hours = @as(u64, @intCast(ts)) / std.time.s_per_hour % 24;
        const system_minutes = @as(u64, @intCast(ts)) / std.time.s_per_min % 60;
        const input_hours = std.fmt.parseInt(i8, self.setting_values[0][0..self.setting_lengths[0]], 0) catch 0;
        const input_minutes = std.fmt.parseInt(i8, self.setting_values[1][0..self.setting_lengths[1]], 0) catch 0;

        const hours_offset = @as(i8, @intCast(system_hours)) - input_hours;
        const minutes_offset = @as(i8, @intCast(system_minutes)) - input_minutes;

        var result = try std.fmt.allocPrint(allocator.alloc, "hours_offset = \"{}\"\nminutes_offset = \"{}\"\n", .{ hours_offset, minutes_offset });
        for (SETTINGS[2..], self.setting_values[2..], self.setting_lengths[2..]) |setting, value, len| {
            const old_result = result;
            defer allocator.alloc.free(old_result);

            const val = if (len == 0) setting[2] else value[0..len];
            result = try std.fmt.allocPrint(allocator.alloc, "{s}{s} = \"{s}\"\n", .{ old_result, setting[1], val });
        }

        return result;
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        var y: f32 = 100 - self.offset;
        defer self.offset = @max(@as(f32, 0), (y + self.offset) - (size.y - 100));

        const title_text = try std.fmt.allocPrint(allocator.alloc, "Sand" ++ font.EEE ++ " Installer v_{s}", .{VERSION});
        defer allocator.alloc.free(title_text);
        try self.face.draw(.{
            .shader = self.font_shader,
            .text = title_text,
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });
        y += self.face.size * 2;

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = "Please Enter new disk name:",
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });
        y += self.face.size * 1;

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = self.disk_name.items,
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });

        if (@intFromEnum(self.status) < @intFromEnum(Status.Settings)) return;

        y += self.face.size * 2;
        for (0..self.setting_id + 1) |idx| {
            if (idx > SETTINGS.len) return;
            const text = try std.fmt.allocPrint(allocator.alloc, "{s}?\n  [Def: {s}] {s}", .{
                SETTINGS[idx][0],
                SETTINGS[idx][2],
                self.setting_values[idx][0..self.setting_lengths[idx]],
            });
            defer allocator.alloc.free(text);

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = text,
                .pos = .{ .x = 100, .y = y },
                .wrap = gfx.Context.instance.size.x - 200,
                .color = .{ .r = 1, .b = 1, .g = 1 },
            });

            y += self.face.sizeText(.{
                .text = text,
                .wrap = gfx.Context.instance.size.x - 200,
            }).y;
        }

        if (@intFromEnum(self.status) < @intFromEnum(Status.Installing)) return;

        y += self.face.size * 2;
        try self.face.draw(.{
            .shader = self.font_shader,
            .text = "Installing...",
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });
        y += self.face.size * 2;

        self.load_sprite.data.size.x = (size.x - 200);
        if (self.status == .Installing) self.load_sprite.data.size.x *= 1 - self.timer;
        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.load_sprite, self.shader, .{ .x = 100, .y = y });

        if (@intFromEnum(self.status) < @intFromEnum(Status.Done)) return;

        y += self.face.size * 2;
        try self.face.draw(.{
            .shader = self.font_shader,
            .text = "Done!",
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });
        y += self.face.size * 1;

        const reboot_text = try std.fmt.allocPrint(allocator.alloc, "Rebooting in {}", .{@as(u32, @intFromFloat(0.5 + self.timer))});
        defer allocator.alloc.free(reboot_text);

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = reboot_text,
            .pos = .{ .x = 100, .y = y },
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.status == .Installing) {
            self.timer -= dt / INSTALL_TIME;
            if (self.timer < 0) {
                self.timer = 3;
                self.status = .Done;

                const vals = try self.updateSettingsVals();
                defer allocator.alloc.free(vals);

                try files.Folder.setupDisk(self.disk_name.items, vals);
            }
        } else if (self.status == .Done) {
            self.timer -= dt;
            if (self.timer < 0) {
                self.timer = 0;

                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });
            }
        }
    }

    pub fn appendChar(self: *Self, char: u8) !void {
        switch (self.status) {
            .Naming => {
                if (self.disk_name.items.len < MAX_VALUE_LEN)
                    try self.disk_name.append(char);
            },
            .Settings => {
                if (self.setting_lengths[self.setting_id] < MAX_VALUE_LEN) {
                    self.setting_values[self.setting_id][self.setting_lengths[self.setting_id]] = char;
                    self.setting_lengths[self.setting_id] += 1;
                }
            },
            else => {},
        }
    }

    pub fn removeChar(self: *Self) !void {
        switch (self.status) {
            .Naming => {
                _ = self.disk_name.popOrNull();
            },
            .Settings => {
                if (self.setting_lengths[self.setting_id] > 0) {
                    self.setting_lengths[self.setting_id] -= 1;
                }
            },
            else => {},
        }
    }

    pub fn keypress(self: *Self, keycode: c_int, mods: c_int, down: bool) !void {
        if (!down) return;
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
                        try audio.instance.playSound(self.select_sound.*);

                        if (self.disk_name.items.len == 0) return;
                        if (std.mem.containsAtLeast(u8, self.disk_name.items, 1, ".")) {
                            if (!std.mem.endsWith(u8, self.disk_name.items, ".eee")) return;
                        } else {
                            try self.disk_name.appendSlice(".eee");
                        }
                        self.status = .Settings;
                    },
                    .Settings => {
                        try audio.instance.playSound(self.select_sound.*);

                        if (self.setting_lengths[self.setting_id] == 0) {
                            self.setting_lengths[self.setting_id] = @as(u8, @intCast(SETTINGS[self.setting_id][2].len));
                            @memcpy(self.setting_values[self.setting_id][0..self.setting_lengths[self.setting_id]], SETTINGS[self.setting_id][2]);
                        }

                        self.setting_id += 1;
                        if (self.setting_id >= SETTINGS.len) {
                            self.status = .Installing;
                            self.setting_id -= 1;
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }
    }

    pub fn deinit(self: *Self) void {
        self.disk_name.deinit();
    }
};
