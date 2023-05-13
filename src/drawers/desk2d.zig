const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const gfx = @import("../util/graphics.zig");
const files = @import("../system/files.zig");
const shd = @import("../util/shader.zig");
const fnt = @import("../util/font.zig");
const std = @import("std");

const TOTAL_SPRITES = 6.0;
const SPACING = vecs.newVec2(128, 100);

pub var deskSize: *vecs.Vector2 = undefined;

pub const DeskData = struct {
    pub fn new() DeskData {
        return DeskData{};
    }

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @intToFloat(f32, sprite);

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

    pub fn getVerts(_: *DeskData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();

        var position = vecs.newVec2(0, 0);

        for (files.home.subfolders.items) |_| {
            try addQuad(&result, 3, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

            updatePos(&position);
        }

        for (files.home.contents.items) |_| {
            try addQuad(&result, 4, rect.newRect(position.x * SPACING.x + 32, position.y * SPACING.y + 32, 64, 64), rect.newRect(0, 0, 1, 1));

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
        var textColor = gfx.gContext.color;
        textColor.r = 1.0 - textColor.r;
        textColor.g = 1.0 - textColor.g;
        textColor.b = 1.0 - textColor.b;

        for (files.home.subfolders.items) |folder| {
            try addIconText(batch, position, folder.name[0 .. folder.name.len - 1], font_shader, font, textColor);

            updatePos(&position);
        }

        for (files.home.contents.items) |file| {
            try addIconText(batch, position, file.name, font_shader, font, textColor);

            updatePos(&position);
        }
    }
};

pub const Desk = sb.Drawer(DeskData);
