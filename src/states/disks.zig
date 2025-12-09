const builtin = @import("builtin");
const options = @import("options");
const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("../drawers/mod.zig");
const windows = @import("../windows/mod.zig");
const loaders = @import("../loaders/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const states = @import("../states/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Color = math.Color;
const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const Sprite = drawers.Sprite;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const storage = util.storage;
const audio = util.audio;

const EventManager = events.EventManager;
const system_events = events.system;

const strings = data.strings;

const GSDisks = @This();

const VERSION = std.fmt.comptimePrint("Boot" ++ strings.EEE ++ " seed#3_0\nFor Sand" ++ strings.EEE ++ " " ++ strings.SANDEEE_VERSION_TEXT, .{});
const TEXT_COLOR = Color{ .r = 0.75, .g = 0.75, .b = 0.75 };
const TOTAL_LINES = 10;

const DISK_LIST = "0123456789ABCDEF";

face: *Font,
font_shader: *Shader,
shader: *Shader,
logo_sprite: Sprite,
disk: *?[]u8,
blip_sound: *audio.Sound,
select_sound: *audio.Sound,

remaining: f32 = 10,
sel: usize = 0,
auto: bool = true,
disks: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(allocator.alloc),
start: usize = 0,

pub fn getDate(name: []const u8) i128 {
    const path = std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{name}) catch return 0;
    defer allocator.alloc.free(path);
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();
    return (file.metadata() catch return 0).modified();
}

pub fn sortDisksLt(_: u0, a: []const u8, b: []const u8) bool {
    return getDate(b) < getDate(a);
}

pub fn setup(self: *GSDisks) !void {
    graphics.Context.instance.color = .{ .r = 0, .g = 0, .b = 0 };

    self.sel = 0;
    self.auto = true;
    self.remaining = 10;
    self.disks.clearAndFree();

    var dir = try std.fs.cwd().openDir("disks", .{
        .iterate = true,
    });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        if (!std.mem.endsWith(u8, item.name, ".eee")) continue;

        const entry = try allocator.alloc.dupe(u8, item.name);

        try self.disks.append(entry);
    }

    const dat: u0 = 0;

    std.sort.insertion([]const u8, self.disks.items, dat, sortDisksLt);

    for (self.disks.items, 0..) |_, idx| {
        const copy = self.disks.items[idx];
        defer allocator.alloc.free(copy);

        const ch = if (idx < DISK_LIST.len) DISK_LIST[idx] else ' ';

        self.disks.items[idx] = try std.fmt.allocPrint(allocator.alloc, "{c} {s}", .{ ch, copy });
    }

    try self.disks.append("N New Disk");
    if (self.disks.items.len > 1)
        try self.disks.append("R Recovery");
    try self.disks.append("X Quit");
}

pub fn deinit(self: *GSDisks) void {
    if (self.disks.items.len > 2) {
        for (self.disks.items[0 .. self.disks.items.len - 3]) |item| {
            allocator.alloc.free(item);
        }
    }

    self.disks.clearAndFree();
}

pub fn update(self: *GSDisks, dt: f32) !void {
    if (self.auto) self.remaining -= dt;

    if (self.remaining <= 0) {
        try audio.instance.playSound(self.select_sound.*);
        self.disk.* = null;

        if (self.disks.items.len > 2) {
            if (self.sel < self.disks.items.len - 2) {
                const sel = self.disks.items[self.sel];

                self.disk.* = try allocator.alloc.dupe(u8, sel[2..]);
            }

            if (self.sel == self.disks.items.len - 1) {
                c.glfwSetWindowShouldClose(graphics.Context.instance.window, 1);
            } else if (self.sel == self.disks.items.len - 2) {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Recovery,
                });
            } else if (self.sel == self.disks.items.len - 3) {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Installer,
                });
            } else {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Loading,
                });
            }
        } else {
            if (self.sel == 0) {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Installer,
                });
            } else {
                c.glfwSetWindowShouldClose(graphics.Context.instance.window, 1);
            }
            return;
        }
    }
}

pub fn draw(self: *GSDisks, _: Vec2) !void {
    var pos = Vec2{ .x = 100, .y = 100 };

    var line: []u8 = &.{};

    try SpriteBatch.global.draw(Sprite, &self.logo_sprite, self.shader, .{ .x = pos.x, .y = pos.y });
    pos.y += self.logo_sprite.data.size.y;

    if (self.auto) {
        line = try std.fmt.allocPrint(allocator.alloc, "{s}\nBooting to default in {}s", .{ VERSION, @as(i32, @intFromFloat(self.remaining + 0.5)) });
    } else {
        line = try std.fmt.allocPrint(allocator.alloc, "{s}\nAutoboot canceled", .{VERSION});
    }

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = line,
        .wrap = graphics.Context.instance.size.x - 200,
        .pos = pos,
        .color = TEXT_COLOR,
    });

    pos.y += self.face.sizeText(.{
        .text = line,
        .wrap = graphics.Context.instance.size.x - 200,
    }).y;

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = "Select a disk",
        .pos = pos,
        .color = TEXT_COLOR,
    });
    pos.y += self.face.size * 1;

    if (self.disks.items.len != 0) {
        for (self.disks.items[self.start..@min(self.start + TOTAL_LINES, self.disks.items.len)], self.start..) |disk, idx| {
            allocator.alloc.free(line);

            line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{disk});
            if (idx == self.sel) {
                line[0] = '>';
            }

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = line,
                .pos = pos,
                .color = TEXT_COLOR,
            });
            pos.y += self.face.size * 1;
        }
    }
    allocator.alloc.free(line);
}

pub fn keypress(self: *GSDisks, key: c_int, _: c_int, down: bool) !void {
    if (!down) return;

    self.auto = false;
    switch (key) {
        c.GLFW_KEY_ENTER => {
            self.remaining = 0;
        },
        c.GLFW_KEY_DOWN => {
            if (self.sel < self.disks.items.len - 1) {
                if (self.sel + 1 == self.start + TOTAL_LINES - 1) {
                    self.start += 1;
                }
                self.sel += 1;
                try audio.instance.playSound(self.blip_sound.*);
            }
        },
        c.GLFW_KEY_UP => {
            if (self.sel > 0) {
                if (self.sel - 1 == self.start) {
                    if (self.start > 0)
                        self.start -= 1;
                }

                self.sel -= 1;
                try audio.instance.playSound(self.blip_sound.*);
            }
        },
        else => {
            if (c.glfwGetKeyName(key, 0) == null) return;

            for (self.disks.items, 0..) |disk, idx| {
                if (std.ascii.toUpper(c.glfwGetKeyName(key, 0)[0]) == disk[0]) {
                    self.sel = idx;
                    self.remaining = 0;
                }
            }
        },
    }

    return;
}
