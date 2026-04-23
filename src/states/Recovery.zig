const options = @import("options");
const std = @import("std");
const glfw = @import("glfw");

const sandeee_data = @import("../data.zig");
const drawers = @import("../drawers.zig");
const events = @import("../events.zig");
const states = @import("../states.zig");
const system = @import("../system.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");

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

const GSRecovery = @This();

const RecoveryChoice = struct {
    name: []const u8,
    disk: []const u8 = "",
};

shader: *Shader,
face: *Font,
font_shader: *Shader,
blip_sound: *audio.Sound,
select_sound: *audio.Sound,

sel: usize = 0,
disks: std.array_list.Managed([]const u8) = .init(allocator),
status: []const u8 = "",
sub_sel: ?usize = null,
confirm_sel: ?bool = null,
recovery_choices: std.array_list.Managed(RecoveryChoice) = .init(allocator),

const DISK_LIST = "0123456789ABCDEF";
const TEXT_COLOR = Color{ .r = 1, .g = 1, .b = 1 };

pub fn getDate(name: []const u8) i128 {
    const path = std.fmt.allocPrint(allocator, "disks/{s}", .{name}) catch return 0;
    defer allocator.free(path);
    const file = std.fs.cwd().openFile(path, .{}) catch return 0;
    defer file.close();

    return (file.stat() catch return 0).mtime;
}

pub fn sortRecoveryLt(_: void, a: RecoveryChoice, b: RecoveryChoice) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

pub fn sortDisksLt(_: void, a: []const u8, b: []const u8) bool {
    return getDate(a) < getDate(b);
}

pub fn setup(self: *GSRecovery) !void {
    graphics.Context.instance.color = .{ .r = 0, .g = 0, .b = 0.3333 };

    self.sel = 0;
    self.sub_sel = null;
    self.status = "";

    // setup disk list
    {
        var dir = try std.fs.cwd().openDir("disks", .{
            .iterate = true,
        });
        defer dir.close();

        var iter = dir.iterate();

        while (try iter.next()) |item| {
            if (!std.mem.endsWith(u8, item.name, ".eee")) continue;

            const entry = try allocator.dupe(u8, item.name);

            try self.disks.append(entry);
        }

        std.sort.insertion([]const u8, self.disks.items, {}, sortDisksLt);

        for (self.disks.items, 0..) |_, idx| {
            const copy = self.disks.items[idx];
            defer allocator.free(copy);

            self.disks.items[idx] = try std.fmt.allocPrint(allocator, "{c} {s}", .{ DISK_LIST[idx], copy });
        }

        self.disks.items.len = @min(self.disks.items.len, DISK_LIST.len);

        try self.disks.append("X Back");
    }

    // setup recovery option list
    {
        var dir = try std.fs.cwd().openDir("content", .{
            .iterate = true,
        });
        defer dir.close();

        var iter = dir.iterate();

        while (try iter.next()) |item| {
            if (!std.mem.endsWith(u8, item.name, ".eee")) continue;

            var file = try dir.openFile(item.name, .{ .mode = .read_only });
            defer file.close();

            const disk = try allocator.dupe(u8, item.name);
            var name = try allocator.dupe(u8, item.name);

            const conts = try files.Folder.diskRecoveryInfo(file);
            if (conts) |c| {
                var split = std.mem.splitScalar(u8, c, '\n');

                while (split.next()) |entry| {
                    const line = std.mem.trim(u8, entry, &std.ascii.whitespace);
                    if (std.mem.containsAtLeast(u8, line, 2, "=")) continue;

                    const equals_idx = std.mem.indexOf(u8, line, "=") orelse continue;

                    const menu_entry = std.mem.trim(u8, line[0..equals_idx], &std.ascii.whitespace);
                    if (std.mem.eql(u8, menu_entry, "menu_option")) {
                        const assigns = std.mem.trim(u8, line[equals_idx + 1 ..], &std.ascii.whitespace);

                        name = try allocator.realloc(name, assigns.len);
                        @memcpy(name, assigns);
                    }
                }
            }
            defer if (conts) |c| allocator.free(c);

            try self.recovery_choices.append(.{
                .name = name,
                .disk = disk,
            });
        }

        std.sort.insertion(RecoveryChoice, self.recovery_choices.items, {}, sortRecoveryLt);

        for (self.recovery_choices.items, 0..) |_, idx| {
            const copy = self.recovery_choices.items[idx].name;
            defer allocator.free(copy);

            self.recovery_choices.items[idx].name = try std.fmt.allocPrint(allocator, "{c} {s}", .{ DISK_LIST[idx], copy });
        }

        try self.recovery_choices.append(.{ .name = "D Delete Disk" });
        try self.recovery_choices.append(.{ .name = "X Back" });
    }
}

pub fn deinit(self: *GSRecovery) void {
    for (self.disks.items[0 .. self.disks.items.len - 1]) |item| {
        allocator.free(item);
    }
    self.disks.clearAndFree();

    for (self.recovery_choices.items[0 .. self.recovery_choices.items.len - 2]) |item| {
        allocator.free(item.name);
        allocator.free(item.disk);
    }
    self.recovery_choices.clearAndFree();
}

const CONFIRM = [_][*:0]const u8{
    "Y Yes",
    "N No",
};

pub fn draw(self: *GSRecovery, _: Vec2) !void {
    var y: f32 = 100;

    const title_text = try std.fmt.allocPrint(allocator, "BootEEE v_{s}", .{strings.BOOTEEE_VERSION_TEXT});
    defer allocator.free(title_text);
    try self.face.draw(.{
        .shader = self.font_shader,
        .text = title_text,
        .pos = .{ .x = 100, .y = y },
        .color = .{ .r = 1, .g = 1, .b = 1 },
    });
    y += self.face.size * 1;

    try self.face.draw(.{
        .shader = self.font_shader,
        .text = self.status,
        .pos = .{ .x = 100, .y = y },
        .color = .{ .r = 1, .g = 1, .b = 1 },
    });
    y += self.face.size * 2;

    if (self.confirm_sel) |confirm_sel| {
        const prompt = if (self.sub_sel) |sub_sel|
            if (sub_sel == self.recovery_choices.items.len - 2)
                "Delete this disk?"
            else
                "Reinstall all system files?"
        else
            unreachable;

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = prompt,
            .pos = .{ .x = 100, .y = y },
            .color = TEXT_COLOR,
        });
        y += self.face.size * 1;

        const lines: [2][]u8 = .{
            try std.fmt.allocPrint(allocator, "  {s}", .{CONFIRM[0]}),
            try std.fmt.allocPrint(allocator, "  {s}", .{CONFIRM[1]}),
        };

        const idx: usize = if (confirm_sel) 0 else 1;

        lines[idx][0] = '>';

        for (lines) |line| {
            defer allocator.free(line);

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = line,
                .pos = .{ .x = 100, .y = y },
                .color = TEXT_COLOR,
            });
            y += self.face.size * 1;
        }
    } else if (self.sub_sel) |sub_sel| {
        for (self.recovery_choices.items, 0..) |choice, idx| {
            const line = try std.fmt.allocPrint(allocator, "  {s}", .{choice.name});
            defer allocator.free(line);

            if (idx == sub_sel) {
                line[0] = '>';
            }

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = line,
                .pos = .{ .x = 100, .y = y },
                .color = TEXT_COLOR,
            });
            y += self.face.size * 1;
        }
    } else if (self.disks.items.len != 0) {
        for (self.disks.items, 0..) |disk, idx| {
            const line = try std.fmt.allocPrint(allocator, "  {s}", .{disk});
            defer allocator.free(line);

            if (idx == self.sel) {
                line[0] = '>';
            }

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = line,
                .pos = .{ .x = 100, .y = y },
                .color = TEXT_COLOR,
            });
            y += self.face.size * 1;
        }
    }
}

pub fn keypress(self: *GSRecovery, key: c_int, _: c_int, down: bool) !void {
    if (!down) return;

    switch (key) {
        glfw.KeyEscape => {
            if (self.confirm_sel != null)
                self.confirm_sel = null
            else if (self.sub_sel != null)
                self.sub_sel = null
            else
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });
        },
        glfw.KeyEnter => {
            if (self.sub_sel) |sub_sel| {
                if (self.confirm_sel) |confirm| {
                    if (confirm) {
                        if (sub_sel == self.recovery_choices.items.len - 2) {
                            const path = try std.fmt.allocPrint(allocator, "disks/{s}", .{self.disks.items[self.sel][2..]});
                            defer allocator.free(path);

                            self.status = "Deleted";

                            try std.fs.cwd().deleteFile(path);

                            _ = self.disks.orderedRemove(self.sel);

                            self.confirm_sel = null;
                            self.sub_sel = null;
                            self.sel = 0;

                            if (self.disks.items.len == 1) {
                                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                                    .target_state = .Disks,
                                });

                                try audio.instance.playSound(self.select_sound.*);
                            }

                            return;
                        } else if (sub_sel < self.recovery_choices.items.len - 2) {
                            try files.Folder.recoverDisk(self.disks.items[self.sel][2..], self.recovery_choices.items[sub_sel].disk, false);
                            self.status = "Reinstalled";
                            try audio.instance.playSound(self.select_sound.*);
                        }
                    }

                    self.confirm_sel = null;

                    try audio.instance.playSound(self.select_sound.*);

                    self.sub_sel = 0;
                    self.sel = 0;

                    return;
                } else if (sub_sel == self.recovery_choices.items.len - 1) {
                    self.sub_sel = null;
                    try audio.instance.playSound(self.select_sound.*);
                } else {
                    self.confirm_sel = true;
                    try audio.instance.playSound(self.select_sound.*);
                }
            } else if (self.sel == self.disks.items.len - 1) {
                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });

                try audio.instance.playSound(self.select_sound.*);
            } else {
                self.sub_sel = 0;

                try audio.instance.playSound(self.select_sound.*);
            }
        },
        glfw.KeyDown => {
            if (self.confirm_sel != null) {
                self.confirm_sel = false;
            } else if (self.sub_sel) |*sub_sel| {
                if (sub_sel.* < self.recovery_choices.items.len - 1) {
                    sub_sel.* += 1;
                    try audio.instance.playSound(self.blip_sound.*);
                }
            } else if (self.sel < self.disks.items.len - 1) {
                self.sel += 1;
                try audio.instance.playSound(self.blip_sound.*);
            }
        },
        glfw.KeyUp => {
            if (self.confirm_sel != null) {
                self.confirm_sel = true;
            } else if (self.sub_sel) |*sub_sel| {
                if (sub_sel.* != 0) {
                    sub_sel.* -= 1;
                    try audio.instance.playSound(self.blip_sound.*);
                }
            } else if (self.sel != 0) {
                self.sel -= 1;
                try audio.instance.playSound(self.blip_sound.*);
            }
        },
        else => if (glfw.getKeyName(key, 0)) |name| {
            if (std.ascii.toUpper(name[0]) == 'X') {
                if (self.sub_sel) |_| {
                    self.sub_sel = null;

                    try audio.instance.playSound(self.select_sound.*);
                    return;
                }

                try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                    .target_state = .Disks,
                });

                try audio.instance.playSound(self.select_sound.*);
            } else if (self.sub_sel) |sub_sel| {
                _ = sub_sel;
                switch (std.ascii.toUpper(name[0])) {
                    'D' => {
                        const path = try std.fmt.allocPrint(allocator, "disks/{s}", .{self.disks.items[self.sel][2..]});
                        defer allocator.free(path);

                        self.status = "Deleted";

                        try std.fs.cwd().deleteFile(path);

                        _ = self.disks.orderedRemove(self.sel);

                        self.sub_sel = null;
                        self.sel = 0;

                        if (self.disks.items.len == 1) {
                            try events.EventManager.instance.sendEvent(system_events.EventStateChange{
                                .target_state = .Disks,
                            });

                            try audio.instance.playSound(self.select_sound.*);

                            return;
                        }

                        try audio.instance.playSound(self.select_sound.*);
                    },
                    else => {},
                }
            } else {
                for (self.disks.items, 0..) |disk, idx| {
                    if (std.ascii.toUpper(name[0]) == disk[0]) {
                        self.sel = idx;
                        self.sub_sel = 0;

                        try audio.instance.playSound(self.select_sound.*);
                    }
                }
            }
        },
    }
}
