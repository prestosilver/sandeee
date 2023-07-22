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
const allocator = @import("../util/allocator.zig");

const SPACING = vecs.newVec2(128, 100);

pub var deskSize: *vecs.Vector2 = undefined;
pub var settingsManager: *config.SettingManager = undefined;

pub const DeskData = struct {
    sel: ?usize = null,
    shell: shell.Shell,

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        source.y /= 8;
        source.h /= 8;

        source.x /= 8;
        source.w /= 8;

        source.x += 1.0 / 8.0 * @as(f32, @floatFromInt(sprite));

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

        const idx = std.mem.lastIndexOf(u8, name, "/") orelse 0;

        return name[idx + 1] != '_';
    }

    pub fn click(self: *DeskData, shader: *shd.Shader, pos: ?vecs.Vector2) !void {
        if (pos == null) {
            self.sel = null;
            return;
        }

        var position = vecs.newVec2(0, 0);
        var idx: usize = 0;

        const subFolders = try files.home.getFolders();
        defer allocator.alloc.free(subFolders);

        for (subFolders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            if (rect.newRect(position.x * SPACING.x, position.y * SPACING.y, SPACING.x, SPACING.y).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const window = win.Window.new("win", win.WindowData{
                        .source = rect.Rectangle{
                            .x = 0.0,
                            .y = 0.0,
                            .w = 1.0,
                            .h = 1.0,
                        },
                        .contents = try wins.explorer.new(shader),
                        .active = true,
                    });

                    const explorerSelf: *wins.explorer.ExplorerData = @ptrCast(@alignCast(window.data.contents.ptr));

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

        const subFiles = try files.home.getFiles();
        defer allocator.alloc.free(subFiles);

        for (subFiles) |file| {
            if (!checkIconSkip(file.name)) continue;

            if (rect.newRect(position.x * SPACING.x, position.y * SPACING.y, SPACING.x, SPACING.y).contains(pos.?)) {
                if (self.sel != null and self.sel == idx) {
                    const index = std.mem.lastIndexOf(u8, file.name, "/") orelse 0;

                    const cmd = file.name[index + 1 ..];

                    _ = self.shell.run(cmd) catch {
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

        const subFolders = try files.home.getFolders();
        defer allocator.alloc.free(subFolders);

        for (subFolders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addQuad(&result, 1, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

            if (self.sel) |sel| {
                if (idx == sel)
                    try addQuad(&result, 2, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(7.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0));
            }

            idx += 1;

            updatePos(&position);
        }

        const subFiles = try files.home.getFiles();
        defer allocator.alloc.free(subFiles);

        for (subFiles) |file| {
            if (!checkIconSkip(file.name)) continue;

            try addQuad(&result, 0, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

            if (self.sel) |sel| {
                if (idx == sel)
                    try addQuad(&result, 2, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(7.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0));
            }

            idx += 1;

            updatePos(&position);
        }

        return result;
    }

    pub fn addIconText(batch: *sb.SpriteBatch, position: vecs.Vector2, name: []const u8, font_shader: *shd.Shader, font: *fnt.Font, textColor: cols.Color) !void {
        const idx = std.mem.lastIndexOf(u8, name[0..], "/") orelse 0;

        const size = font.sizeText(.{
            .text = name[idx + 1 ..],
            .wrap = 100,
            .turnicate = true,
        });

        const offsetx = (SPACING.x - size.x) / 2;

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = name[idx + 1 ..],
            .pos = .{
                .x = position.x * SPACING.x + offsetx + 5,
                .y = position.y * SPACING.y + SPACING.y + 5,
            },
            .center = true,
            .color = textColor,
            .wrap = 100,
            .maxlines = 1,
        });
    }

    pub fn addText(_: *DeskData, batch: *sb.SpriteBatch, font_shader: *shd.Shader, font: *fnt.Font) !void {
        const textColor = gfx.gContext.color.contrast();

        var position = vecs.newVec2(0, 0);

        const subFolders = try files.home.getFolders();
        defer allocator.alloc.free(subFolders);

        for (subFolders) |folder| {
            if (!checkIconSkip(folder.name[0 .. folder.name.len - 1])) continue;

            try addIconText(batch, position, folder.name[0 .. folder.name.len - 1], font_shader, font, textColor);

            updatePos(&position);
        }

        const subFiles = try files.home.getFiles();
        defer allocator.alloc.free(subFiles);

        for (subFiles) |file| {
            if (!checkIconSkip(file.name)) continue;

            try addIconText(batch, position, file.name, font_shader, font, textColor);

            updatePos(&position);
        }
    }

    pub fn updateVm(self: *DeskData) !void {
        if (self.shell.vm != null) {
            const result = self.shell.updateVM() catch null;
            if (result != null) {
                allocator.alloc.free(result.?.data);
            }
        }
    }
};

pub const Desk = sb.Drawer(DeskData);
