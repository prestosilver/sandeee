const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const win2d = @import("window2d.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");

const TOTAL_SPRITES: f32 = 7.0;
const TEX_SIZE: f32 = 32;

pub const PopupData = struct {
    source: rect.Rectangle,
    size: vecs.Vector2,
    parentPos: rect.Rectangle,

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle, color: cols.Color) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @intToFloat(f32, sprite);

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
    }

    fn addUiQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, scale: i32, r: f32, l: f32, t: f32, b: f32, color: cols.Color) !void {
        var sc = @intToFloat(f32, scale);

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y, sc * l, sc * t), rect.newRect(0, 0, l / TEX_SIZE, t / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y, pos.w - sc * (l + r), sc * t), rect.newRect(l / TEX_SIZE, 0, (TEX_SIZE - l - r) / TEX_SIZE, t / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y, sc * r, sc * t), rect.newRect((TEX_SIZE - r) / TEX_SIZE, 0, r / TEX_SIZE, t / TEX_SIZE), color);

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y + sc * t, sc * l, pos.h - sc * (t + b)), rect.newRect(0, t / TEX_SIZE, l / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + sc * t, pos.w - sc * (l + r), pos.h - sc * (t + b)), rect.newRect(l / TEX_SIZE, t / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + sc * t, sc * r, pos.h - sc * (t + b)), rect.newRect((TEX_SIZE - r) / TEX_SIZE, t / TEX_SIZE, r / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);

        try addQuad(arr, sprite, rect.newRect(pos.x, pos.y + pos.h - sc * b, sc * l, sc * b), rect.newRect(0, (TEX_SIZE - b) / TEX_SIZE, l / TEX_SIZE, b / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + pos.h - sc * b, pos.w - sc * (l + r), sc * b), rect.newRect(l / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, b / TEX_SIZE), color);
        try addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + pos.h - sc * b, sc * r, sc * b), rect.newRect((TEX_SIZE - r) / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, r / TEX_SIZE, b / TEX_SIZE), color);
    }

    pub fn new(source: rect.Rectangle, size: vecs.Vector2) PopupData {
        return PopupData{
            .source = source,
            .size = size,
        };
    }

    pub fn drawContents(self: *PopupData, shader: *shd.Shader, font: *fnt.Font, batch: *sb.SpriteBatch) !void {
        _ = self;
        _ = font;
        try batch.addEntry(&.{
            .update = true,
            .texture = batch.queue[batch.queue.len - 1].texture,
            .verts = try va.VertArray.init(),
            .shader = shader.*,
            .clear = cols.newColor(0, 0, 0, 1),
        });
    }

    pub fn getVerts(self: *PopupData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        var sprite: u8 = 1;

        var pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2));

        var close = rect.newRect(pos.x + self.size.x - 64, pos.y, 64, 64);

        try addUiQuad(&result, sprite, rect.newRect(pos.x, pos.y, self.size.x, self.size.y), 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        try addUiQuad(&result, 4, close, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        return result;
    }

    pub fn click(self: *PopupData, mousepos: vecs.Vector2) bool {
        var pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2));
        var close = rect.newRect(pos.x + self.size.x - 64, pos.y, 64, 64);
        close.h = 26;
        close.x += close.w - 26;
        close.w = 26;
        if (close.contains(mousepos)) {
            return true;
        }

        return false;
    }

    pub fn scissor(self: *const PopupData) rect.Rectangle {
        var pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2));
        var bnds = .{
            .x = pos.x,
            .y = pos.y,
            .w = self.size.x,
            .h = self.size.y,
        };
        bnds.y += 34;
        bnds.x += 6;
        bnds.w -= 12;
        bnds.h -= 40;

        return bnds;
    }
};

pub const Popup = sb.Drawer(PopupData);
