const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const c = @import("../c.zig");
const shell = @import("../system/shell.zig");
const conf = @import("../system/config.zig");
const popups = @import("../drawers/popup2d.zig");
const winEvs = @import("../events/window.zig");
const systemEvs = @import("../events/system.zig");
const events = @import("../util/events.zig");

const SCROLL = 30;

pub const ExplorerData = struct {
    const ExplorerIcon = struct {
        name: []const u8,
        icon: u8,
    };

    const Self = @This();

    const ExplorerMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };

    const ExplorerMouseAction = struct {
        kind: ExplorerMouseActionType,
        pos: vecs.Vector2,
        time: f32,
    };

    shader: *shd.Shader,
    icons: [4]sprite.Sprite,
    text_box: [2]sprite.Sprite,
    menubar: sprite.Sprite,
    gray: sprite.Sprite,
    shell: shell.Shell,

    focused: ?u64 = null,
    selected: ?usize = null,
    lastAction: ?ExplorerMouseAction = null,
    icon_data: []const ExplorerIcon,

    pub fn getIcons(self: *Self) ![]const ExplorerIcon {
        const subFolders = try self.shell.root.getFolders();
        const subFiles = try self.shell.root.getFiles();
        defer allocator.alloc.free(subFolders);
        defer allocator.alloc.free(subFiles);

        const result = try allocator.alloc.alloc(ExplorerIcon, subFolders.len + subFiles.len);
        var idx: usize = 0;

        for (subFolders) |folder| {
            result[idx] = ExplorerIcon{
                .name = folder.name[self.shell.root.name.len .. folder.name.len - 1],
                .icon = 2,
            };
            idx += 1;
        }

        for (subFiles) |file| {
            result[idx] = ExplorerIcon{
                .name = file.name[self.shell.root.name.len..],
                .icon = 1,
            };
            idx += 1;
        }

        return result;
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 34,
            };
        }
        if (self.lastAction != null) {
            if (self.lastAction.?.time <= 0) {
                self.lastAction = null;
            } else {
                self.lastAction.?.time -= 5;
            }
        }

        const title = try std.fmt.allocPrint(allocator.alloc, "{s}", .{self.shell.root.name});
        defer allocator.alloc.free(title);
        try props.setTitle(title);

        if (self.shell.vm != null) {
            const result = self.shell.getVMResult() catch null;
            if (result != null) {
                allocator.alloc.free(result.?.data);
            }
        }

        var x: f32 = 0;
        var y: f32 = -props.scroll.?.value + 36;

        const hidden = conf.SettingManager.instance.getBool("explorer_hidden");

        for (self.icon_data, 0..) |icon, idx| {
            if (icon.name.len == 0) continue;
            if (!hidden and icon.name[0] == '_') continue;

            const size = font.sizeText(.{
                .text = icon.name,
                .wrap = 100,
            }).x;
            const xo = (128 - size) / 2;

            if (y + 64 + font.size > 0 and y < bnds.h) {
                try font.draw(.{
                    .shader = font_shader,
                    .text = icon.name,
                    .pos = vecs.newVec2(bnds.x + x + xo - 14, bnds.y + 64 + y + 6),
                    .color = col.newColor(0, 0, 0, 1),
                    .wrap = 100,
                    .maxlines = 1,
                });

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[icon.icon], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));

                if (self.selected != null and idx == self.selected.?)
                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[3], self.shader, vecs.newVec3(bnds.x + x + 6 + 16, bnds.y + y + 6, 0));
            }

            if (self.lastAction != null) {
                if (rect.newRect(x + 2 + 16, y + 2, 64, 64).contains(self.lastAction.?.pos)) {
                    switch (self.lastAction.?.kind) {
                        .SingleLeft => {
                            self.selected = idx;
                        },
                        .DoubleLeft => {
                            self.lastAction = null;

                            const newPath = self.shell.root.getFolder(icon.name) catch null;
                            if (newPath != null) {
                                self.shell.root = newPath.?;
                                try self.refresh();
                                self.selected = null;
                            } else {
                                _ = self.shell.runBg(icon.name) catch {
                                    //TODO: popup
                                };
                            }

                            return;
                        },
                    }
                }
            }

            x += 128;
            if (x + 128 > bnds.w) {
                y += 72 + font.size;
                x = 0;
            }
        }

        props.scroll.?.maxy = y + 64 + font.size + font.size + props.scroll.?.value - bnds.h;

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        self.text_box[0].data.size.x = bnds.w - 36;
        self.text_box[1].data.size.x = bnds.w - 40;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 36, bnds.y + 2, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 38, bnds.y + 4, 0));

        const tmp = batch.SpriteBatch.instance.scissor;
        batch.SpriteBatch.instance.scissor = rect.newRect(bnds.x + 42, bnds.y + 4, bnds.w - 4 - 34, 28);
        try font.draw(.{
            .shader = font_shader,
            .text = self.shell.root.name,
            .pos = vecs.newVec2(bnds.x + 42, bnds.y + 8),
            .color = col.newColor(0, 0, 0, 1),
        });

        batch.SpriteBatch.instance.scissor = tmp;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 2, 0));
    }

    pub fn deinit(self: *Self) !void {
        try self.shell.deinit();
        allocator.alloc.free(self.icon_data);
        allocator.alloc.destroy(self);
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (self.shell.vm != null) return;
        if (btn == null) return;

        if (mousepos.y < 36) {
            if (rect.newRect(0, 0, 28, 28).contains(mousepos)) {
                self.shell.root = self.shell.root.parent;
                try self.refresh();
                self.selected = null;
            }

            return;
        }

        switch (btn.?) {
            0 => {
                if (self.lastAction != null and mousepos.distSq(self.lastAction.?.pos) < 100) {
                    self.lastAction = .{
                        .kind = .DoubleLeft,
                        .pos = mousepos,
                        .time = 10,
                    };
                } else {
                    self.lastAction = .{
                        .kind = .SingleLeft,
                        .pos = mousepos,
                        .time = 100,
                    };
                }
            },
            else => {},
        }
    }

    pub fn char(_: *Self, _: u32, _: i32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: rect.Rectangle) !void {}

    pub fn refresh(self: *Self) !void {
        allocator.alloc.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    const tmpFuncs = struct {
        fn yes(data: *align(@alignOf(Self)) anyopaque) anyerror!void {
            const self = @as(*Self, @ptrCast(data));

            self.shell.root.removeFile(self.icon_data[self.selected.?].name) catch |err| {
                switch (err) {
                    error.FileNotFound => return,
                    else => return err,
                }
            };
        }

        fn no(_: *align(@alignOf(Self)) anyopaque) anyerror!void {}
    };

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (self.shell.vm != null) return;
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_DELETE => {
                if (self.selected != null and self.shell.root.getFile(self.icon_data[self.selected.?].name) catch null != null) {
                    const adds = try allocator.alloc.create(popups.all.confirm.PopupConfirm);
                    adds.* = .{
                        .data = self,
                        .message = "Are you sure you want to delete this file.",
                        .buttons = &.{
                            .{
                                .text = "Yes",
                                .calls = @as(*const fn (*anyopaque) anyerror!void, @ptrCast(&tmpFuncs.yes)),
                            },
                            .{
                                .text = "No",
                                .calls = @as(*const fn (*anyopaque) anyerror!void, @ptrCast(&tmpFuncs.no)),
                            },
                        },
                    };

                    try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
                        .popup = .{
                            .texture = "win",
                            .data = .{
                                .title = "File Picker",
                                .source = rect.newRect(0, 0, 1, 1),
                                .size = vecs.newVec2(350, 125),
                                .parentPos = undefined,
                                .contents = popups.PopupData.PopupContents.init(adds),
                            },
                        },
                    });
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                self.shell.root = self.shell.root.parent;
                try self.refresh();
                self.selected = null;
            },
            else => {},
        }
    }
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(ExplorerData);

    self.* = .{
        .gray = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(3.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(72.0, 72.0),
        )),
        .menubar = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(4.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 4.0 / 8.0),
            vecs.newVec2(0.0, 40.0),
        )),
        .text_box = .{
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 32.0),
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 28.0),
            )),
        },
        .icons = undefined,
        .shader = shader,
        .shell = .{
            .root = files.home,
            .vm = null,
        },
        .icon_data = try allocator.alloc.alloc(ExplorerData.ExplorerIcon, 0),
    };

    for (self.icons, 0..) |_, idx| {
        const i = @as(f32, @floatFromInt(idx)) - 1;

        self.icons[idx] = sprite.Sprite.new("big_icons", sprite.SpriteData.new(
            rect.newRect(i / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(64, 64),
        ));
    }

    self.icons[0] = sprite.Sprite.new("icons", sprite.SpriteData.new(
        rect.newRect(3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
        vecs.newVec2(32.0, 32.0),
    ));

    try self.refresh();

    return win.WindowContents.init(self, "explorer", "Files", col.newColor(1, 1, 1, 1));
}
