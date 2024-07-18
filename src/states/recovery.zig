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
const files = @import("../system/files.zig");
const audio = @import("../util/audio.zig");

const c = @import("../c.zig");

const VERSION = "0.1.0";

pub const GSRecovery = struct {
    const Self = @This();

    const RecoveryMenuEntry = enum {
        Reinstall,
        ReinstallReset,
        Delete,
        Back,
    };

    shader: *shd.Shader,
    face: *font.Font,
    font_shader: *shd.Shader,
    blipSound: *audio.Sound,
    selectSound: *audio.Sound,
    audioMan: *audio.Audio,

    sel: usize = 0,
    disks: std.ArrayList([]const u8) = undefined,
    status: []const u8 = "",
    sub_sel: ?RecoveryMenuEntry = null,
    confirm_sel: ?bool = null,

    const DISK_LIST = "0123456789ABCDEF";
    const TEXT_COLOR = cols.newColor(1, 1, 1, 1);

    pub fn getDate(name: []const u8) i128 {
        const path = std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{name}) catch return 0;
        defer allocator.alloc.free(path);
        const file = std.fs.cwd().openFile(path, .{}) catch return 0;
        defer file.close();
        return (file.metadata() catch return 0).modified();
    }

    pub fn sortDisksLt(_: u8, a: []const u8, b: []const u8) bool {
        return getDate(a) < getDate(b);
    }

    pub fn setup(self: *Self) !void {
        gfx.Context.instance.color = cols.newColor(0, 0, 0.3333, 1);

        self.disks = std.ArrayList([]const u8).init(allocator.alloc);

        self.sel = 0;
        self.sub_sel = null;
        self.status = "";

        const dir = try std.fs.cwd().openDir("disks", .{
            .iterate = true,
        });

        var iter = dir.iterate();

        while (try iter.next()) |item| {
            const entry = try allocator.alloc.alloc(u8, item.name.len);

            @memcpy(entry, item.name);

            try self.disks.append(entry);
        }

        const und: u8 = undefined;

        std.sort.insertion([]const u8, self.disks.items, und, sortDisksLt);

        for (self.disks.items, 0..) |_, idx| {
            const copy = self.disks.items[idx];
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

    const UPDATE_MODES = [_][*:0]const u8{
        "R Reinstall System Files",
        "S Reinstall System Files and Default Settings",
        "D Delete disk",
        "X Back",
    };

    const CONFIRM = [_][*:0]const u8{
        "Y Yes",
        "N No",
    };

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        _ = size;
        var y: f32 = 100;

        const titleLine = try std.fmt.allocPrint(allocator.alloc, "Recover" ++ font.EEE ++ " v_{s}", .{VERSION});
        defer allocator.alloc.free(titleLine);
        try self.face.draw(.{
            .shader = self.font_shader,
            .text = titleLine,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 1;

        try self.face.draw(.{
            .shader = self.font_shader,
            .text = self.status,
            .pos = vecs.newVec2(100, y),
            .color = cols.newColor(1, 1, 1, 1),
        });
        y += self.face.size * 2;

        if (self.confirm_sel) |confirm_sel| {
            const prompt = switch (self.sub_sel orelse unreachable) {
                .Reinstall => "Reinstall All System Files?",
                .ReinstallReset => "Reinstall All System Files And Settings?",
                .Delete => "Delete this disk?",
                else => "",
            };

            try self.face.draw(.{
                .shader = self.font_shader,
                .text = prompt,
                .pos = vecs.newVec2(100, y),
                .color = TEXT_COLOR,
            });
            y += self.face.size * 1;

            const lines: [2][]u8 = .{
                try std.fmt.allocPrint(allocator.alloc, "  {s}", .{CONFIRM[0]}),
                try std.fmt.allocPrint(allocator.alloc, "  {s}", .{CONFIRM[1]}),
            };

            const idx: usize = if (confirm_sel) 0 else 1;

            lines[idx][0] = '>';

            for (lines) |line| {
                defer allocator.alloc.free(line);

                try self.face.draw(.{
                    .shader = self.font_shader,
                    .text = line,
                    .pos = vecs.newVec2(100, y),
                    .color = TEXT_COLOR,
                });
                y += self.face.size * 1;
            }
        } else if (self.sub_sel) |sub_sel| {
            for (UPDATE_MODES, 0..) |mode, idx| {
                const line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{mode});
                defer allocator.alloc.free(line);

                if (idx == @intFromEnum(sub_sel)) {
                    line[0] = '>';
                }

                try self.face.draw(.{
                    .shader = self.font_shader,
                    .text = line,
                    .pos = vecs.newVec2(100, y),
                    .color = TEXT_COLOR,
                });
                y += self.face.size * 1;
            }
        } else if (self.disks.items.len != 0) {
            for (self.disks.items, 0..) |disk, idx| {
                const line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{disk});
                defer allocator.alloc.free(line);

                if (idx == self.sel) {
                    line[0] = '>';
                }

                try self.face.draw(.{
                    .shader = self.font_shader,
                    .text = line,
                    .pos = vecs.newVec2(100, y),
                    .color = TEXT_COLOR,
                });
                y += self.face.size * 1;
            }
        }
    }

    pub fn keypress(self: *Self, key: c_int, _: c_int, down: bool) !void {
        if (!down) return;

        switch (key) {
            c.GLFW_KEY_ESCAPE => {
                if (self.confirm_sel != null)
                    self.confirm_sel = null
                else if (self.sub_sel != null)
                    self.sub_sel = null
                else
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Disks,
                    });
            },
            c.GLFW_KEY_ENTER => {
                if (self.sub_sel) |sub_sel| {
                    if (self.confirm_sel) |confirm| {
                        if (confirm) {
                            switch (sub_sel) {
                                .Reinstall => {
                                    try files.Folder.recoverDisk(self.disks.items[self.sel][2..], false);
                                    self.status = "Reinstalled";
                                    try self.audioMan.playSound(self.selectSound.*);
                                },
                                .ReinstallReset => {
                                    try files.Folder.recoverDisk(self.disks.items[self.sel][2..], true);
                                    self.status = "Reinstalled & Reset";
                                    try self.audioMan.playSound(self.selectSound.*);
                                },
                                .Delete => {
                                    const path = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{self.disks.items[self.sel][2..]});
                                    defer allocator.alloc.free(path);

                                    self.status = "Deleted";

                                    try std.fs.cwd().deleteFile(path);

                                    _ = self.disks.orderedRemove(self.sel);

                                    self.confirm_sel = null;
                                    self.sub_sel = null;
                                    self.sel = 0;

                                    if (self.disks.items.len == 1) {
                                        try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                                            .targetState = .Disks,
                                        });

                                        try self.audioMan.playSound(self.selectSound.*);
                                    }

                                    return;
                                },
                                else => {},
                            }
                        }

                        self.confirm_sel = null;

                        try self.audioMan.playSound(self.selectSound.*);

                        self.sub_sel = .Reinstall;
                        self.sel = 0;

                        return;
                    } else if (sub_sel == .Back) {
                        self.sub_sel = null;
                        try self.audioMan.playSound(self.selectSound.*);
                    } else {
                        self.confirm_sel = true;
                        try self.audioMan.playSound(self.selectSound.*);
                    }
                } else if (self.sel == self.disks.items.len - 1) {
                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Disks,
                    });

                    try self.audioMan.playSound(self.selectSound.*);
                } else {
                    self.sub_sel = .Reinstall;

                    try self.audioMan.playSound(self.selectSound.*);
                }
            },
            c.GLFW_KEY_DOWN => {
                if (self.confirm_sel != null) {
                    self.confirm_sel = false;
                } else if (self.sub_sel) |sub_sel| {
                    if (@intFromEnum(sub_sel) < @intFromEnum(RecoveryMenuEntry.Back)) {
                        self.sub_sel.? = @enumFromInt(@intFromEnum(self.sub_sel.?) + 1);

                        try self.audioMan.playSound(self.blipSound.*);
                    }
                } else if (self.sel < self.disks.items.len - 1) {
                    self.sel += 1;
                    try self.audioMan.playSound(self.blipSound.*);
                }
            },
            c.GLFW_KEY_UP => {
                if (self.confirm_sel != null) {
                    self.confirm_sel = true;
                } else if (self.sub_sel) |sub_sel| {
                    if (@intFromEnum(sub_sel) > @intFromEnum(RecoveryMenuEntry.Reinstall)) {
                        self.sub_sel.? = @enumFromInt(@intFromEnum(self.sub_sel.?) - 1);
                        try self.audioMan.playSound(self.blipSound.*);
                    }
                } else if (self.sel != 0) {
                    self.sel -= 1;
                    try self.audioMan.playSound(self.blipSound.*);
                }
            },
            else => {
                if (c.glfwGetKeyName(key, 0) == null) return;

                if (std.ascii.toUpper(c.glfwGetKeyName(key, 0)[0]) == 'X') {
                    if (self.sub_sel) |_| {
                        self.sub_sel = null;

                        try self.audioMan.playSound(self.selectSound.*);
                        return;
                    }

                    try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                        .targetState = .Disks,
                    });

                    try self.audioMan.playSound(self.selectSound.*);
                } else if (self.sub_sel) |sub_sel| {
                    _ = sub_sel;
                    switch (std.ascii.toUpper(c.glfwGetKeyName(key, 0)[0])) {
                        'R' => {
                            try files.Folder.recoverDisk(self.disks.items[self.sel][2..], false);
                            self.status = "Reinstalled";
                            try self.audioMan.playSound(self.selectSound.*);
                        },
                        'S' => {
                            try files.Folder.recoverDisk(self.disks.items[self.sel][2..], true);
                            self.status = "Reinstalled & Reset";
                            try self.audioMan.playSound(self.selectSound.*);
                        },
                        'D' => {
                            const path = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{self.disks.items[self.sel][2..]});
                            defer allocator.alloc.free(path);

                            self.status = "Deleted";

                            try std.fs.cwd().deleteFile(path);

                            _ = self.disks.orderedRemove(self.sel);

                            self.sub_sel = null;
                            self.sel = 0;

                            if (self.disks.items.len == 1) {
                                try events.EventManager.instance.sendEvent(systemEvs.EventStateChange{
                                    .targetState = .Disks,
                                });

                                try self.audioMan.playSound(self.selectSound.*);

                                return;
                            }

                            try self.audioMan.playSound(self.selectSound.*);
                        },
                        else => {},
                    }
                } else {
                    for (self.disks.items, 0..) |disk, idx| {
                        if (std.ascii.toUpper(c.glfwGetKeyName(key, 0)[0]) == disk[0]) {
                            self.sel = idx;
                            self.sub_sel = .Reinstall;

                            try self.audioMan.playSound(self.selectSound.*);
                        }
                    }
                }
            },
        }
    }
};
