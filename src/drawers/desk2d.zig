const std = @import("std");
const c = @import("../c.zig");

const drawers = @import("mod.zig");

const windows = @import("../windows/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;

const Shell = system.Shell;
const files = system.files;
const config = system.config;

const EventManager = events.EventManager;
const window_events = events.windows;

const Window = drawers.Window;
const Popup = drawers.Popup;

const SPACING = Vec2{ .x = 128, .y = 100 };

pub const DeskData = struct {
    const Self = @This();

    sel: ?usize = null,
    shell: Shell,

    inline fn addQuad(arr: *VertArray, sprite: u8, pos: Rect, src: Rect) !void {
        const source = Rect{
            .x = src.x / 8 + 1.0 / 8.0 * @as(f32, @floatFromInt(sprite)),
            .y = src.y / 8,
            .w = src.w / 8,
            .h = src.h / 8,
        };

        const color = Color{ .r = 1, .g = 1, .b = 1 };

        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y + pos.h }, .{ .x = source.x + source.w, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y }, .{ .x = source.x, .y = source.y }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
    }

    pub fn updatePos(pos: *Vec2) void {
        pos.y += 1;

        if (pos.y * SPACING.y > graphics.Context.instance.size.y) {
            pos.y = 0;
            pos.x += 1;
        }
    }

    pub fn checkIconSkip(name: []const u8) bool {
        if (config.SettingManager.instance.getBool("explorer_hidden") orelse false) return true;

        const idx = std.mem.lastIndexOf(u8, name, "/") orelse 0;

        return name[idx + 1] != '_';
    }

    pub fn click(self: *DeskData, shader: *Shader, pos: ?Vec2) !void {
        if (pos == null) {
            self.sel = null;
            return;
        }

        var position = Vec2{};
        var idx: usize = 0;

        const home = try files.FolderLink.resolve(.home);

        var sub_folder = try home.getFolders();
        while (sub_folder) |folder| : (sub_folder = folder.next_sibling) {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            if ((Rect{ .x = position.x * SPACING.x, .y = position.y * SPACING.y, .w = SPACING.x, .h = SPACING.y }).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const window: Window = .atlas("win", .{
                        .source = Rect{ .w = 1, .h = 1 },
                        .contents = try windows.explorer.init(shader),
                        .active = true,
                    });

                    const explorer_self: *windows.explorer.ExplorerData = @ptrCast(@alignCast(window.data.contents.ptr));

                    explorer_self.shell.root = .link(folder);

                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });

                    self.sel = null;

                    return;
                }
                self.sel = idx;
            }

            idx += 1;

            updatePos(&position);
        }

        var sub_file = try home.getFiles();
        while (sub_file) |file| : (sub_file = file.next_sibling) {
            if (!checkIconSkip(file.name)) continue;

            if ((Rect{ .x = position.x * SPACING.x, .y = position.y * SPACING.y, .w = SPACING.x, .h = SPACING.y }).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const index = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;

                    const cmd = file.name[index + 1 ..];

                    self.shell.runBg(cmd) catch |err| {
                        const message = try std.fmt.allocPrint(allocator.alloc, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

                        const adds = try allocator.alloc.create(Popup.Data.confirm.PopupConfirm);
                        adds.* = .{
                            .data = self,
                            .message = message,
                            .shader = shader,
                            .buttons = Popup.Data.confirm.PopupConfirm.initButtonsFromStruct(errorData),
                        };

                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                            .global = true,
                            .popup = .atlas("win", .{
                                .title = "File Picker",
                                .source = .{ .w = 1, .h = 1 },
                                .pos = Rect.initCentered(.{
                                    .w = graphics.Context.instance.size.x,
                                    .h = graphics.Context.instance.size.y,
                                }, 350, 125),
                                .contents = Popup.Data.PopupContents.init(adds),
                            }),
                        });
                    };

                    self.sel = null;

                    return;
                }
                self.sel = idx;
            }

            idx += 1;

            updatePos(&position);
        }
    }

    pub const errorData = struct {
        pub fn ok(_: *align(@alignOf(Self)) const anyopaque) anyerror!void {}
    };

    pub fn getVerts(self: *const DeskData, _: Vec3) !VertArray {
        var result = try VertArray.init(0);

        var position = Vec2{};
        var idx: usize = 0;

        const home = try files.FolderLink.resolve(.home);

        var sub_folder = try home.getFolders();
        while (sub_folder) |folder| : (sub_folder = folder.next_sibling) {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try result.appendQuad(
                .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 },
                .{ .x = 1.0 / 8.0, .y = 0.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .{},
            );

            if (self.sel) |sel| {
                if (idx == sel)
                    try result.appendQuad(
                        .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 },
                        .{ .x = (7.0 / 32.0 / 8.0) + 2.0 / 8.0, .y = 3.0 / 32.0 / 8.0, .w = 3.0 / 32.0 / 8.0, .h = 3.0 / 32.0 / 8.0 },
                        .{},
                    );
            }

            idx += 1;

            updatePos(&position);
        }

        var sub_file = try home.getFiles();
        while (sub_file) |file| : (sub_file = file.next_sibling) {
            if (!checkIconSkip(file.name)) continue;

            try result.appendQuad(
                .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 },
                .{
                    .w = 1.0 / 8.0,
                    .h = 1.0 / 8.0,
                },
                .{},
            );

            if (self.sel) |sel|
                if (idx == sel)
                    try result.appendQuad(
                        .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 },
                        .{ .x = (7.0 / 32.0 / 8.0) + 2.0 / 8.0, .y = 3.0 / 32.0 / 8.0, .w = 3.0 / 32.0 / 8.0, .h = 3.0 / 32.0 / 8.0 },
                        .{},
                    );

            idx += 1;

            updatePos(&position);
        }

        return result;
    }

    pub fn addIconText(position: Vec2, name: []const u8, font_shader: *Shader, font: *Font, textColor: Color) !void {
        const idx = std.mem.lastIndexOf(u8, name[0..], "/") orelse 0;

        const size = font.sizeText(.{
            .text = name[idx + 1 ..],
            .wrap = 100,
        });

        const offsetx = (SPACING.x - size.x) / 2;

        try font.draw(.{
            .shader = font_shader,
            .text = name[idx + 1 ..],
            .pos = .{
                .x = position.x * SPACING.x + offsetx,
                .y = position.y * SPACING.y + SPACING.y + 5,
            },
            .color = textColor,
            .wrap = 100,
            .maxlines = 1,
        });
    }

    pub fn addText(_: *DeskData, font_shader: *Shader, font: *Font) !void {
        const text_color = graphics.Context.instance.color.contrast();

        var position = Vec2{};

        const home = try files.FolderLink.resolve(.home);

        var sub_folder = try home.getFolders();
        while (sub_folder) |folder| : (sub_folder = folder.next_sibling) {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addIconText(position, folder.name[0 .. folder.name.len - 1], font_shader, font, text_color);

            updatePos(&position);
        }

        var sub_file = try home.getFiles();
        while (sub_file) |file| : (sub_file = file.next_sibling) {
            if (!checkIconSkip(file.name)) continue;

            try addIconText(position, file.name, font_shader, font, text_color);

            updatePos(&position);
        }
    }

    pub fn updateVm(self: *DeskData) !void {
        if (self.shell.vm != null) {
            const result = self.shell.getVMResult() catch null;
            if (result) |result_data| {
                allocator.alloc.free(result_data.data);
            }
        }
    }
};

pub const drawer = SpriteBatch.Drawer(DeskData);
