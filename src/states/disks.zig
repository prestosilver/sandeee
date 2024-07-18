const std = @import("std");
const options = @import("options");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const font = @import("../util/font.zig");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const gfx = @import("../util/graphics.zig");
const cols = @import("../math/colors.zig");
const audio = @import("../util/audio.zig");

const c = @import("../c.zig");

pub const GSDisks = struct {
    const Self = @This();
    const VERSION = std.fmt.comptimePrint("Boot" ++ font.EEE ++ " V_0.2.0\nFor Sand" ++ font.EEE ++ " " ++ options.VersionText, .{options.SandEEEVersion});
    const TEXT_COLOR = cols.newColorRGBA(192, 192, 192, 255);

    const TOTAL_LINES = 10;

    face: *font.Font,
    font_shader: *shd.Shader,
    shader: *shd.Shader,
    logo_sprite: sp.Sprite,
    disk: *?[]u8,
    blipSound: *audio.Sound,
    selectSound: *audio.Sound,
    audioMan: *audio.Audio,

    remaining: f32 = 10,
    sel: usize = 0,
    auto: bool = true,
    disks: std.ArrayList([]const u8) = undefined,
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

    const DISK_LIST = "0123456789ABCDEF";

    pub fn setup(self: *Self) !void {
        gfx.Context.instance.color = cols.newColor(0, 0, 0, 1);

        self.sel = 0;
        self.auto = true;
        self.remaining = 10;
        self.disks = std.ArrayList([]const u8).init(allocator.alloc);

        const dir = try std.fs.cwd().openDir("disks", .{
            .iterate = true,
        });

        var iter = dir.iterate();

        while (try iter.next()) |item| {
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

    pub fn deinit(self: *Self) !void {
        if (self.disks.items.len > 2) {
            for (self.disks.items[0 .. self.disks.items.len - 3]) |item| {
                allocator.alloc.free(item);
            }
        }

        self.disks.deinit();
    }

    pub fn update(self: *Self, dt: f32) !void {
        if (self.auto) self.remaining -= dt;

        if (self.remaining <= 0) {
            try self.audioMan.playSound(self.selectSound.*);
            self.disk.* = null;

            if (self.disks.items.len > 2) {
                if (self.sel < self.disks.items.len - 2) {
                    const sel = self.disks.items[self.sel];

                    self.disk.* = try allocator.alloc.alloc(u8, sel.len - 2);
                    @memcpy(self.disk.*.?, sel[2..]);
                }

                if (self.sel == self.disks.items.len - 1) {
                    c.glfwSetWindowShouldClose(gfx.Context.instance.window, 1);
                } else if (self.sel == self.disks.items.len - 2) {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Recovery,
                    });
                } else if (self.sel == self.disks.items.len - 3) {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Installer,
                    });
                } else {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Loading,
                    });
                }
            } else {
                if (self.sel == 0) {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Installer,
                    });
                } else {
                    c.glfwSetWindowShouldClose(gfx.Context.instance.window, 1);
                }
                return;
            }
        }
    }

    pub fn draw(self: *Self, _: vecs.Vector2) !void {
        var pos = vecs.newVec2(100, 100);

        var line: []u8 = undefined;

        try batch.SpriteBatch.instance.draw(sp.Sprite, &self.logo_sprite, self.shader, vecs.newVec3(pos.x, pos.y, 0));
        pos.y += self.logo_sprite.data.size.y;

        if (self.auto) {
            line = try std.fmt.allocPrint(allocator.alloc, "{s}\nBooting to default in {}s", .{ VERSION, @as(i32, @intFromFloat(self.remaining + 0.5)) });
        } else {
            line = try std.fmt.allocPrint(allocator.alloc, "{s}\nAutoboot canceled", .{VERSION});
        }

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = line,
            .wrap = gfx.Context.instance.size.x - 200,
            .pos = pos,
            .color = TEXT_COLOR,
        });

        pos.y += self.face.sizeText(.{
            .text = line,
            .wrap = gfx.Context.instance.size.x - 200,
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

    pub fn keypress(self: *Self, key: c_int, _: c_int, down: bool) !void {
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
                    try self.audioMan.playSound(self.blipSound.*);
                }
            },
            c.GLFW_KEY_UP => {
                if (self.sel > 0) {
                    if (self.sel - 1 == self.start) {
                        if (self.start > 0)
                            self.start -= 1;
                    }

                    self.sel -= 1;
                    try self.audioMan.playSound(self.blipSound.*);
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
};
