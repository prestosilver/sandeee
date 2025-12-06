const std = @import("std");
const c = @import("../c.zig");

const Windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Eln = util.Eln;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const Opener = system.Opener;
const Shell = system.Shell;
const config = system.config;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;
const system_events = events.system;

pub const ExplorerData = struct {
    const ExplorerIcon = struct {
        name: []const u8,
        launches: []const u8,
        icon: Sprite,
    };

    const Self = @This();

    const ExplorerMouseActionType = enum {
        SingleLeft,
        DoubleLeft,
    };

    const ExplorerMouseAction = struct {
        kind: ExplorerMouseActionType,
        pos: Vec2,
        time: f32,
    };

    shader: *Shader,
    icons: [2]Sprite,
    selected_sprite: Sprite,
    back_sprite: Sprite,
    text_box: [2]Sprite,
    menubar: Sprite,
    gray: Sprite,
    shell: Shell,

    focused: ?u64 = null,

    selected: ?usize = null,
    last_action: ?ExplorerMouseAction = null,
    icon_data: []const ExplorerIcon = &.{},
    bnds: Rect = .{ .w = 0, .h = 0 },

    pub fn getIcons(self: *Self) ![]const ExplorerIcon {
        const shell_root = try self.shell.root.resolve();

        //const result = try allocator.alloc.alloc(ExplorerIcon, sub_folders.len + sub_files.len);
        var result: std.ArrayList(ExplorerIcon) = .init(allocator.alloc);
        defer result.deinit();

        var sub_folder = try shell_root.getFolders();
        while (sub_folder) |folder| : (sub_folder = folder.next_sibling) {
            const name = folder.name[shell_root.name.len .. folder.name.len - 1];

            try result.append(ExplorerIcon{
                .name = try allocator.alloc.dupe(u8, name),
                .launches = try allocator.alloc.dupe(u8, name),
                .icon = self.icons[1],
            });
        }

        var sub_file = try shell_root.getFiles();
        while (sub_file) |file| : (sub_file = file.next_sibling) {
            const parsed = try Eln.parse(file);

            const icon_spr: Sprite = if (parsed.icon) |icon| .override(icon, .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 64, .y = 64 },
            }) else self.icons[0];

            const folder_idx = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;

            try result.append(ExplorerIcon{
                .name = try allocator.alloc.dupe(u8, file.name[(folder_idx + 1)..]),
                .launches = try allocator.alloc.dupe(u8, parsed.launches),
                .icon = icon_spr,
            });
        }

        return try allocator.alloc.dupe(ExplorerIcon, result.items);
    }

    pub const ErrorData = struct {
        pub fn ok(_: *align(@alignOf(Self)) const anyopaque) anyerror!void {}
    };

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
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

        const shell_root = try self.shell.root.resolve();

        const title = try std.fmt.allocPrint(allocator.alloc, "{s}", .{shell_root.name});
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

            const hidden = config.SettingManager.instance.getBool("explorer_hidden") orelse false;

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

                    try SpriteBatch.global.draw(Sprite, &icon.icon, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });

                    if (self.selected) |selected| {
                        if (selected == idx) {
                            try SpriteBatch.global.draw(Sprite, &self.selected_sprite, self.shader, .{ .x = bnds.x + x + 6 + 16, .y = bnds.y + y + 6 });
                        }
                    }
                }

                if (self.last_action) |last_action| {
                    if ((Rect{ .x = x + 2 + 16, .y = y + 2, .w = 64, .h = 64 }).contains(last_action.pos)) {
                        switch (last_action.kind) {
                            .SingleLeft => {
                                self.selected = idx;
                            },
                            .DoubleLeft => {
                                self.last_action = null;

                                const new_path = shell_root.getFolder(icon.name) catch null;
                                if (new_path) |path| {
                                    self.shell.root = .link(path);
                                    try self.refresh();
                                    self.selected = null;

                                    // the active folder changed !!!
                                    // clear and redraw
                                    try SpriteBatch.global.addEntry(&.{
                                        .texture = .none,
                                        .verts = try VertArray.init(0),
                                        .shader = self.shader.*,
                                        .clear = props.clear_color,
                                    });

                                    done = false;
                                    continue :draw_loop;
                                } else {
                                    _ = self.shell.runBg(icon.launches) catch |err| {
                                        const message = try std.fmt.allocPrint(allocator.alloc, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

                                        const adds = try allocator.alloc.create(Popup.Data.confirm.PopupConfirm);
                                        adds.* = .{
                                            .data = self,
                                            .message = message,
                                            .buttons = Popup.Data.confirm.PopupConfirm.initButtonsFromStruct(ErrorData),
                                            .shader = self.shader,
                                        };

                                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                                            .popup = .atlas("win", .{
                                                .title = "Error",
                                                .source = .{ .w = 1, .h = 1 },
                                                .pos = .initCentered(self.bnds, 350, 125),
                                                .contents = .init(adds),
                                            }),
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
        try SpriteBatch.global.draw(Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 36;
        self.text_box[1].data.size.x = bnds.w - 40;
        try SpriteBatch.global.draw(Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 36, .y = bnds.y + 2 });
        try SpriteBatch.global.draw(Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 38, .y = bnds.y + 4 });

        {
            const old_scissor = SpriteBatch.global.scissor;
            defer SpriteBatch.global.scissor = old_scissor;

            SpriteBatch.global.scissor = .{ .x = bnds.x + 42, .y = bnds.y + 4, .w = bnds.w - 4 - 34, .h = 28 };
            try font.draw(.{
                .shader = font_shader,
                .text = shell_root.name,
                .pos = .{
                    .x = bnds.x + 42,
                    .y = bnds.y + 8,
                },
                .color = .{ .r = 0, .g = 0, .b = 0 },
            });
        }

        try SpriteBatch.global.draw(Sprite, &self.back_sprite, self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
    }

    pub fn deinit(self: *Self) void {
        self.shell.deinit();
        for (self.icon_data) |icon| {
            allocator.alloc.free(icon.name);
            allocator.alloc.free(icon.launches);
        }
        allocator.alloc.free(self.icon_data);
        allocator.alloc.destroy(self);
    }

    pub fn click(self: *Self, _: Vec2, mousepos: Vec2, btn: ?i32) !void {
        if (self.shell.vm != null) return;
        if (btn == null) return;

        const shell_root = try self.shell.root.resolve();

        if (mousepos.y < 36) {
            if ((Rect{ .w = 28, .h = 28 }).contains(mousepos)) {
                self.shell.root = shell_root.parent orelse .root;
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
        for (self.icon_data) |icon| {
            allocator.alloc.free(icon.name);
            allocator.alloc.free(icon.launches);
        }
        allocator.alloc.free(self.icon_data);
        self.icon_data = try self.getIcons();
    }

    pub const confirmData = struct {
        pub fn yes(popup_data: *align(@alignOf(Self)) const anyopaque) anyerror!void {
            const self = @as(*const Self, @ptrCast(popup_data));

            const shell_root = try self.shell.root.resolve();

            shell_root.removeFile(self.icon_data[self.selected.?].name) catch |err| {
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

        const shell_root = try self.shell.root.resolve();

        switch (keycode) {
            c.GLFW_KEY_DELETE => {
                if (self.selected != null and (shell_root.getFile(self.icon_data[self.selected.?].name) catch null) != null) {
                    const adds = try allocator.alloc.create(Popup.Data.confirm.PopupConfirm);
                    adds.* = .{
                        .data = self,
                        .message = try allocator.alloc.dupe(u8, "Are you sure you want to delete this file."),
                        .buttons = Popup.Data.confirm.PopupConfirm.initButtonsFromStruct(confirmData),
                        .shader = self.shader,
                    };

                    try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                        .popup = .atlas("win", .{
                            .title = "File Picker",
                            .source = .{ .w = 1.0, .h = 1.0 },
                            .pos = .initCentered(self.bnds, 350, 125),
                            .contents = .init(adds),
                        }),
                    });
                }
            },
            c.GLFW_KEY_BACKSPACE => {
                self.shell.root = shell_root.parent orelse .root;
                try self.refresh();
                self.selected = null;
            },
            else => {},
        }
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.alloc.create(ExplorerData);

    self.* = .{
        .gray = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 72.0, .y = 72.0 },
        }),
        .menubar = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .size = .{ .y = 40.0 },
        }),
        .text_box = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 32.0 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 28.0 },
            }),
        },
        .icons = undefined,
        .back_sprite = .atlas("icons", .{
            .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 32, .y = 32 },
        }),
        .selected_sprite = .atlas("big_icons", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 64, .y = 64 },
        }),
        .shader = shader,
        .shell = .{
            .root = .home,
            .vm = null,
        },
    };

    for (self.icons, 0..) |_, idx| {
        const i = @as(f32, @floatFromInt(idx));

        self.icons[idx] = .atlas("big_icons", .{
            .source = .{ .x = i / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 64, .y = 64 },
        });
    }

    try self.refresh();

    return Window.Data.WindowContents.init(self, "explorer", "Files", .{ .r = 1, .g = 1, .b = 1 });
}
