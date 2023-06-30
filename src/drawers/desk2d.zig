const sb = @import("../util/spritebatch.zig");
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
const windowEvs = @import("../events/window.zig");
const shell = @import("../system/shell.zig");
const config = @import("../system/config.zig");
const std = @import("std");

const TOTAL_SPRITES = 6.0;
const SPACING = vecs.newVec2(128, 100);

pub var deskSize: *vecs.Vector2 = undefined;
pub var settingsManager: *config.SettingManager = undefined;

pub const DeskData = struct {
    sel: ?usize = null,
    shell: shell.Shell,

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @as(f32, @floatFromInt(sprite));

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), cols.newColor(1, 1, 1, 1));
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), cols.newColor(1, 1, 1, 1));
    }

    pub fn updatePos(pos: *vecs.Vector2) void {
        pos.y += 1;

        if (pos.y * SPACING.y > deskSize.y) {
            pos.y = 0;
            pos.x += 1;
        }
    }

    pub fn checkIconSkip(name: []const u8) bool {
        if (settingsManager.getBool("explorer_hidden")) return true;

        var idx = std.mem.lastIndexOf(u8, name, "/") orelse 0;

        return name[idx + 1] != '_';
    }

    pub fn click(self: *DeskData, shader: *shd.Shader, pos: ?vecs.Vector2) !void {
        if (pos == null) {
            self.sel = null;
            return;
        }

        var position = vecs.newVec2(0, 0);
        var idx: usize = 0;

        for (self.shell.root.subfolders.items) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            if (rect.newRect(position.x * SPACING.x, position.y * SPACING.y, SPACING.x, SPACING.y).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    var window = win.Window.new("win", win.WindowData{
                        .source = rect.Rectangle{
                            .x = 0.0,
                            .y = 0.0,
                            .w = 1.0,
                            .h = 1.0,
                        },
                        .contents = try wins.explorer.new("explorer", shader),
                        .active = true,
                    });

                    var explorerSelf: *wins.explorer.ExplorerData = @ptrCast(@alignCast(window.data.contents.ptr));

                    explorerSelf.shell.root = folder;

                    try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

                    self.sel = null;

                    return;
                }
                self.sel = idx;
            }

            idx += 1;

            updatePos(&position);
        }

        for (self.shell.root.contents.items) |file| {
            if (!checkIconSkip(file.name)) continue;

            if (rect.newRect(position.x * SPACING.x, position.y * SPACING.y, SPACING.x, SPACING.y).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const index = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;

                    var cmd = file.name[index + 1 ..];

                    _ = self.shell.run(cmd, cmd) catch {
                        //TODO: popup
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

    pub fn getVerts(self: *const DeskData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();

        var position = vecs.newVec2(0, 0);
        var idx: usize = 0;

        for (files.home.subfolders.items) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addQuad(&result, 3, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

            if (self.sel) |sel| {
                if (idx == sel)
                    try addQuad(&result, 0, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(7.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0));
            }

            idx += 1;

            updatePos(&position);
        }

        for (files.home.contents.items) |file| {
            if (!checkIconSkip(file.name)) continue;

            try addQuad(&result, 4, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

            if (self.sel) |sel| {
                if (idx == sel)
                    try addQuad(&result, 0, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(7.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0));
            }

            idx += 1;

            updatePos(&position);
        }

        return result;
    }

    pub fn addIconText(batch: *sb.SpriteBatch, position: vecs.Vector2, name: []const u8, font_shader: *shd.Shader, font: *fnt.Font, textColor: cols.Color) !void {
        var idx = std.mem.lastIndexOf(u8, name[0..], "/") orelse 0;

        var size = font.sizeText(.{
            .text = name[idx + 1 ..],
        });

        var offsetx = (SPACING.x - size.x) / 2;

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = name[idx + 1 ..],
            .pos = .{
                .x = position.x * SPACING.x + offsetx,
                .y = position.y * SPACING.y + SPACING.y - 10,
            },
            .color = textColor,
        });
    }

    pub fn addText(_: *DeskData, batch: *sb.SpriteBatch, font_shader: *shd.Shader, font: *fnt.Font) !void {
        var position = vecs.newVec2(0, 0);
        var textColor = gfx.gContext.color.contrast();

        for (files.home.subfolders.items) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addIconText(batch, position, folder.name[0 .. folder.name.len - 1], font_shader, font, textColor);

            updatePos(&position);
        }

        for (files.home.contents.items) |file| {
            if (!checkIconSkip(file.name)) continue;

            try addIconText(batch, position, file.name, font_shader, font, textColor);

            updatePos(&position);
        }
    }

    pub fn updateVm(self: *DeskData) !void {
        if (self.shell.vm != null) {
            var result = self.shell.updateVM() catch null;
            if (result != null) {
                result.?.data.deinit();
            }
        }
    }
};

pub const Desk = sb.Drawer(DeskData);
