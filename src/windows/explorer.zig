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
const window_events = @import("../events/window.zig");
const system_events = @import("../events/system.zig");
const events = @import("../util/events.zig");
const gfx = @import("../util/graphics.zig");
const va = @import("../util/vertArray.zig");

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
    last_action: ?ExplorerMouseAction = null,
    icon_data: []const ExplorerIcon,
    bnds: rect.Rectangle = undefined,

    pub fn getIcons(self: *Self) ![]const ExplorerIcon {
        const sub_folders = try self.shell.root.getFolders();
        const sub_files = try self.shell.root.getFiles();
        defer allocator.alloc.free(sub_folders);
        defer allocator.alloc.free(sub_files);

        const result = try allocator.alloc.alloc(ExplorerIcon, sub_folders.len + sub_files.len);
        var idx: usize = 0;

        for (sub_folders) |folder| {
            result[idx] = ExplorerIcon{
                .name = folder.name[self.shell.root.name.len .. folder.name.len - 1],
                .icon = 2,
            };
            idx += 1;
        }

        for (sub_files) |file| {
            result[idx] = ExplorerIcon{
                .name = file.name[self.shell.root.name.len..],
                .icon = 1,
            };
            idx += 1;
        }

        return result;
    }

    pub const ErrorData = struct {
        pub fn ok(_: *align(@alignOf(Self)) const anyopaque) anyerror!void {}
    };

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 34,
            };
        }
        if (self.last_action) |*last_action| {
            if (last_action.time <= 0) {
                self.last_action = null;
            } else {
                last_action.time -= 5;
            }
        }

        self.bnds = bnds.*;

        const title = try std.fmt.allocPrint(allocator.alloc, "{s}", .{self.shell.root.name});
        defer allocator.alloc.free(title);
        try props.setTitle(title);

        if (self.shell.vm != null) {
            const result = self.shell.getVMResult() catch null;
            if (result) |result_data| {
                allocator.alloc.free(result_data.data);
            }
        }

        var done: bool = false;
        draw_loop: while (!done) {
            done = true;

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
                        .pos = .{ .x = bnds.x + x + xo - 14, .y = bnds.y + 64 + y + 6 },
                        .color = .{ .r = 0, .g = 0, .b = 0 },
                        .wrap = 100,
                        .maxlines = 1,
                    });

                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[icon.icon], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                    if (self.selected) |selected| {
                        if (selected == idx) {
                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[3], self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });
                        }
                    }
                }

                if (self.last_action) |last_action| {
                    if ((rect.Rectangle{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(last_action.pos)) {
                        switch (last_action.kind) {
                            .SingleLeft => {
                                self.selected = idx;
                            },
                            .DoubleLeft => {
                                self.last_action = null;

                                const new_path = self.shell.root.getFolder(icon.name) catch null;
                                if (new_path) |path| {
                                    self.shell.root = path;
                                    try self.refresh();
                                    self.selected = null;

                                    // the active folder changed !!!
                                    // clear and redraw
                                    try batch.SpriteBatch.instance.addEntry(&.{
                                        .texture = "",
                                        .verts = try va.VertArray.init(0),
                                        .shader = self.shader.*,
                                        .clear = props.clear_color,
                                    });

                                    done = false;
                                    continue :draw_loop;
                                } else {
                                    _ = self.shell.runBg(icon.name) catch |err| {
                                        const message = try std.fmt.allocPrint(allocator.alloc, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

                                        const adds = try allocator.alloc.create(popups.all.confirm.PopupConfirm);
                                        adds.* = .{
                                            .data = self,
                                            .message = message,
                                            .buttons = popups.all.confirm.PopupConfirm.createButtonsFromStruct(ErrorData),
                                            .shader = self.shader,
                                        };

                                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                                            .popup = .{
                                                .texture = "win",
                                                .data = .{
                                                    .title = "File Picker",
                                                    .source = .{ .w = 1, .h = 1 },
                                                    .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                                                    .contents = popups.PopupData.PopupContents.init(adds),
                                                },
                                            },
                                        });
                                    };
                                }
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
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 36;
        self.text_box[1].data.size.x = bnds.w - 40;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 36, .y = bnds.y + 2 });
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 38, .y = bnds.y + 4 });

        const tmp = batch.SpriteBatch.instance.scissor;
        batch.SpriteBatch.instance.scissor = .{ .x = bnds.x + 42, .y = bnds.y + 4, .w = bnds.w - 4 - 34, .h = 28 };
        try font.draw(.{
            .shader = font_shader,
            .text = self.shell.root.name,
            .pos = .{
                .x = bnds.x + 42,
                .y = bnds.y + 8,
            },
            .color = .{ .r = 0, .g = 0, .b = 0 },
        });

        batch.SpriteBatch.instance.scissor = tmp;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
    }

    pub fn deinit(self: *Self) void {
        self.shell.deinit();
        allocator.alloc.free(self.icon_data);
        allocator.alloc.destroy(self);
    }

    pub fn click(self: *Self, _: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (self.shell.vm != null) return;
        if (btn == null) return;

        if (mousepos.y < 36) {
            if ((rect.Rectangle{ .w = 28, .h = 28 }).contains(mousepos)) {
                self.shell.root = self.shell.root.parent;
                try self.refresh();
                self.selected = null;
            }

            return;
        }

        switch (btn.?) {
            0 => {
                self.last_action = if (self.last_action) |last_action|
                    if (mousepos.distSq(last_action.pos) < 100)
                        .{
                            .kind = .DoubleLeft,
                            .pos = mousepos,
                            .time = 10,
                        }
                    else
                        .{
                            .kind = .SingleLeft,
                            .pos = mousepos,
                            .time = 100,
                        }
                else
                    .{
                        .kind = .SingleLeft,
                        .pos = mousepos,
                        .time = 100,
                    };
            },
            else => {},
        }
    }

    pub fn refresh(self: *Self) !void {
        allocator.alloc.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    pub const confirmData = struct {
        pub fn yes(data: *align(@alignOf(Self)) const anyopaque) anyerror!void {
            const self = @as(*const Self, @ptrCast(data));

            self.shell.root.removeFile(self.icon_data[self.selected.?].name) catch |err| {
                switch (err) {
                    error.FileNotFound => return,
                    else => return err,
                }
            };
        }

        pub fn no(_: *align(@alignOf(Self)) const anyopaque) anyerror!void {}
    };

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (self.shell.vm != null) return;
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_DELETE => {
                if (self.selected != null and (self.shell.root.getFile(self.icon_data[self.selected.?].name) catch null) != null) {
                    const adds = try allocator.alloc.create(popups.all.confirm.PopupConfirm);
                    adds.* = .{
                        .data = self,
                        .message = try allocator.alloc.dupe(u8, "Are you sure you want to delete this file."),
                        .buttons = popups.all.confirm.PopupConfirm.createButtonsFromStruct(confirmData),
                        .shader = self.shader,
                    };

                    try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                        .popup = .{
                            .texture = "win",
                            .data = .{
                                .title = "File Picker",
                                .source = .{ .w = 1.0, .h = 1.0 },
                                .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
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
            .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .{ .x = 72.0, .y = 72.0 },
        )),
        .menubar = sprite.Sprite.new("ui", sprite.SpriteData.new(
            .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .{ .y = 40.0 },
        )),
        .text_box = .{
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .{ .x = 2.0, .y = 32.0 },
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .{ .x = 2.0, .y = 28.0 },
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
            .{ .x = i / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .{ .x = 64, .y = 64 },
        ));
    }

    self.icons[0] = sprite.Sprite.new("icons", sprite.SpriteData.new(
        .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
        .{ .x = 32, .y = 32 },
    ));

    try self.refresh();

    return win.WindowContents.init(self, "explorer", "Files", .{ .r = 1, .g = 1, .b = 1 });
}
