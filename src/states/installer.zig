const options = @import("options");
const builtin = @import("builtin");
const glfw = @import("glfw");
const std = @import("std");

const states = @import("mod.zig");

const sandeee_data = @import("../data/mod.zig");
const drawers = @import("../drawers/mod.zig");
const events = @import("../events/mod.zig");
const system = @import("../system/mod.zig");
const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Sprite = drawers.Sprite;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const audio = util.audio;

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const EventManager = events.EventManager;
const system_events = events.system;

const files = system.files;

const strings = sandeee_data.strings;

const VERSION = "seed#3_1";
const INSTALL_TIME = if (builtin.mode == .Debug) 0.0 else 1.5;

const GSInstaller = @This();

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
    .{ "Do you like " ++ strings.EEE, "evil_value", "Yes" },
};

const MAX_VALUE_LEN = 16;

shader: *Shader,
face: *Font,
font_shader: *Shader,
load_sprite: Sprite,
select_sound: *audio.Sound,

setting_values: [SETTINGS.len][MAX_VALUE_LEN]u8 = .{[_]u8{0} ** MAX_VALUE_LEN} ** SETTINGS.len,
setting_lengths: [SETTINGS.len]u8 = [_]u8{0} ** SETTINGS.len,
setting_id: usize = 0,

timer: f32 = 1,
status: Status = .Naming,
disk_name: std.array_list.Managed(u8) = .init(allocator.alloc),
offset: f32 = 0,

pub fn setup(self: *GSInstaller) !void {
    graphics.Context.instance.color = .{ .r = 0, .g = 0, .b = 0.5 };

    @memset(&self.setting_lengths, 0);

    self.setting_id = 0;
    self.offset = 0;
    self.timer = 1;
    self.status = .Naming;
    self.load_sprite.data.color.b = 0;
}

pub fn updateSettingsVals(self: *GSInstaller) ![]const u8 {
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

pub fn draw(self: *GSInstaller, size: Vec2) !void {
    var y: f32 = 100 - self.offset;
    defer self.offset = @max(@as(f32, 0), (y + self.offset) - (size.y - 100));

    const title_text = try std.fmt.allocPrint(allocator.alloc, "Sand" ++ strings.EEE ++ " Installer v_{s}", .{VERSION});
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
            .wrap = graphics.Context.instance.size.x - 200,
            .color = .{ .r = 1, .b = 1, .g = 1 },
        });

        y += self.face.sizeText(.{
            .text = text,
            .wrap = graphics.Context.instance.size.x - 200,
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
    try SpriteBatch.global.draw(Sprite, &self.load_sprite, self.shader, .{ .x = 100, .y = y });

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

pub fn update(self: *GSInstaller, dt: f32) !void {
    if (self.status == .Installing) {
        self.timer -= dt / INSTALL_TIME;
        if (self.timer < 0) {
            self.timer =
                if (builtin.mode == .Debug)
                    0
                else
                    3;
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

pub fn appendChar(self: *GSInstaller, char: u8) !void {
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

pub fn removeChar(self: *GSInstaller) !void {
    switch (self.status) {
        .Naming => {
            _ = self.disk_name.pop();
        },
        .Settings => {
            if (self.setting_lengths[self.setting_id] > 0) {
                self.setting_lengths[self.setting_id] -= 1;
            }
        },
        else => {},
    }
}

pub fn keypress(self: *GSInstaller, keycode: c_int, mods: c_int, down: bool) !void {
    if (!down) return;
    switch (keycode) {
        glfw.KeyA...glfw.KeyZ => {
            if ((mods & glfw.ModifierShift) != 0) {
                try self.appendChar(@as(u8, @intCast(keycode - glfw.KeyA)) + 'A');
            } else {
                try self.appendChar(@as(u8, @intCast(keycode - glfw.KeyA)) + 'a');
            }
        },
        glfw.KeyNum0...glfw.KeyNum9 => {
            try self.appendChar(@as(u8, @intCast(keycode - glfw.KeyNum0)) + '0');
        },
        glfw.KeyPeriod => {
            try self.appendChar('.');
        },
        glfw.KeyBackspace => {
            try self.removeChar();
        },
        glfw.KeyMinus => {
            try self.appendChar('-');
        },
        glfw.KeySpace => {
            try self.appendChar('_');
        },
        glfw.KeyEnter => {
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

pub fn deinit(self: *GSInstaller) void {
    self.disk_name.clearAndFree();
}
