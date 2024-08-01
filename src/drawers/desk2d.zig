const batch = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const gfx = @import("../util/graphics.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const fnt = @import("../util/font.zig");
const win = @import("window2d.zig");
const wins = @import("../windows/all.zig");
const events = @import("../util/events.zig");
const shell = @import("../system/shell.zig");
const conf = @import("../system/config.zig");
const std = @import("std");
const allocator = @import("../util/allocator.zig");
const window_events = @import("../events/window.zig");
const popups = @import("popup2d.zig");

const SPACING = vecs.Vector2{ .x = 128, .y = 100 };

pub const DeskData = struct {
    const Self = @This();

    sel: ?usize = null,
    shell: shell.Shell,

    inline fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        const source = rect.Rectangle{
            .x = src.x / 8 + 1.0 / 8.0 * @as(f32, @floatFromInt(sprite)),
            .y = src.y / 8,
            .w = src.w / 8,
            .h = src.h / 8,
        };

        const color = cols.Color{ .r = 1, .g = 1, .b = 1 };

        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y + pos.h }, .{ .x = source.x + source.w, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y + pos.h }, .{ .x = source.x, .y = source.y + source.h }, color);
        try arr.append(.{ .x = pos.x, .y = pos.y }, .{ .x = source.x, .y = source.y }, color);
        try arr.append(.{ .x = pos.x + pos.w, .y = pos.y }, .{ .x = source.x + source.w, .y = source.y }, color);
    }

    pub fn updatePos(pos: *vecs.Vector2) void {
        pos.y += 1;

        if (pos.y * SPACING.y > gfx.Context.instance.size.y) {
            pos.y = 0;
            pos.x += 1;
        }
    }

    pub fn checkIconSkip(name: []const u8) bool {
        if (conf.SettingManager.instance.getBool("explorer_hidden")) return true;

        const idx = std.mem.lastIndexOf(u8, name, "/") orelse 0;

        return name[idx + 1] != '_';
    }

    pub fn click(self: *DeskData, shader: *shd.Shader, pos: ?vecs.Vector2) !void {
        if (pos == null) {
            self.sel = null;
            return;
        }

        var position = vecs.Vector2{};
        var idx: usize = 0;

        const sub_folders = try files.home.getFolders();
        defer allocator.alloc.free(sub_folders);

        for (sub_folders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            if ((rect.Rectangle{ .x = position.x * SPACING.x, .y = position.y * SPACING.y, .w = SPACING.x, .h = SPACING.y }).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const window = win.Window.new("win", win.WindowData{
                        .source = rect.Rectangle{ .w = 1, .h = 1 },
                        .contents = try wins.explorer.new(shader),
                        .active = true,
                    });

                    const explorer_self: *wins.explorer.ExplorerData = @ptrCast(@alignCast(window.data.contents.ptr));

                    explorer_self.shell.root = folder;

                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });

                    self.sel = null;

                    return;
                }
                self.sel = idx;
            }

            idx += 1;

            updatePos(&position);
        }

        const sub_files = try files.home.getFiles();
        defer allocator.alloc.free(sub_files);

        for (sub_files) |file| {
            if (!checkIconSkip(file.name)) continue;

            if ((rect.Rectangle{ .x = position.x * SPACING.x, .y = position.y * SPACING.y, .w = SPACING.x, .h = SPACING.y }).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const index = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;

                    const cmd = file.name[index + 1 ..];

                    self.shell.runBg(cmd) catch |err| {
                        const message = try std.fmt.allocPrint(allocator.alloc, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

                        const adds = try allocator.alloc.create(popups.all.confirm.PopupConfirm);
                        adds.* = .{
                            .data = self,
                            .message = message,
                            .shader = shader,
                            .buttons = popups.all.confirm.PopupConfirm.createButtonsFromStruct(errorData),
                        };

                        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                            .global = true,
                            .popup = .{
                                .texture = "win",
                                .data = .{
                                    .title = "File Picker",
                                    .source = .{ .w = 1, .h = 1 },
                                    .pos = rect.Rectangle.initCentered(.{
                                        .w = gfx.Context.instance.size.x,
                                        .h = gfx.Context.instance.size.y,
                                    }, 350, 125),
                                    .contents = popups.PopupData.PopupContents.init(adds),
                                },
                            },
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

    pub fn getVerts(self: *const DeskData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(0);

        var position = vecs.Vector2{};
        var idx: usize = 0;

        const sub_folders = try files.home.getFolders();
        defer allocator.alloc.free(sub_folders);

        for (sub_folders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addQuad(&result, 1, .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 }, .{ .w = 1, .h = 1 });

            if (self.sel) |sel| {
                if (idx == sel)
                    try addQuad(&result, 2, .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 }, .{ .x = 7.0 / 32.0, .y = 3.0 / 32.0, .w = 3.0 / 32.0, .h = 3.0 / 32.0 });
            }

            idx += 1;

            updatePos(&position);
        }

        const sub_files = try files.home.getFiles();
        defer allocator.alloc.free(sub_files);

        for (sub_files) |file| {
            if (!checkIconSkip(file.name)) continue;

            try addQuad(&result, 0, .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 }, .{ .w = 1, .h = 1 });

            if (self.sel) |sel|
                if (idx == sel)
                    try addQuad(&result, 2, .{ .x = position.x * SPACING.x + 32, .y = position.y * SPACING.y + 32, .w = 64, .h = 64 }, .{ .x = 7.0 / 32.0, .y = 3.0 / 32.0, .w = 3.0 / 32.0, .h = 3.0 / 32.0 });

            idx += 1;

            updatePos(&position);
        }

        return result;
    }

    pub fn addIconText(position: vecs.Vector2, name: []const u8, font_shader: *shd.Shader, font: *fnt.Font, textColor: cols.Color) !void {
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

    pub fn addText(_: *DeskData, font_shader: *shd.Shader, font: *fnt.Font) !void {
        const text_color = gfx.Context.instance.color.contrast();

        var position = vecs.Vector2{};

        const sub_folders = try files.home.getFolders();
        defer allocator.alloc.free(sub_folders);

        for (sub_folders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addIconText(position, folder.name[0 .. folder.name.len - 1], font_shader, font, text_color);

            updatePos(&position);
        }

        const sub_files = try files.home.getFiles();
        defer allocator.alloc.free(sub_files);

        for (sub_files) |file| {
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

pub const Desk = batch.Drawer(DeskData);
