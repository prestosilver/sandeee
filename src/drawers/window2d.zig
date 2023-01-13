const sb = @import("../spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../shader.zig");
const va = @import("../vertArray.zig");

const TOTAL_SPRITES: f32 = 7.0;
const TEX_SIZE: f32 = 32;

pub var deskSize: vecs.Vector2 = vecs.newVec2(640, 480);

pub const DragMode = enum {
    None,
    Move,
    Close,
    Full,
    Min,
    ResizeL,
    ResizeR,
    ResizeB,
    ResizeLB,
    ResizeRB,
};

pub const WindowContents = struct {
    self: *[]u8,
    drawFn: ?*const fn (*[]u8, *sb.SpriteBatch, shd.Shader, *rect.Rectangle, *fnt.Font) void = null,
    clickFn: ?*const fn (*[]u8, vecs.Vector2, vecs.Vector2, i32) bool = null,
    keyFn: ?*const fn (*[]u8, i32, i32) void = null,
    deleteFn: *const fn (*[]u8) void,
    name: []const u8,
    clearColor: cols.Color,

    pub fn draw(self: *WindowContents, batch: *sb.SpriteBatch, shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
        if (self.drawFn == null) return;
        self.drawFn.?(self.self, batch, shader, bnds, font);
    }

    pub fn key(self: *WindowContents, keycode: i32, mods: i32) void {
        if (self.keyFn == null) return;
        self.keyFn.?(self.self, keycode, mods);
    }

    pub fn click(self: *WindowContents, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
        if (self.clickFn == null) return true;
        return self.clickFn.?(self.self, size, mousepos, btn);
    }

    pub fn deinit(self: *WindowContents) void {
        self.deleteFn(self.self);
    }
};

pub const WindowData = struct {
    source: rect.Rectangle,
    pos: rect.Rectangle,

    oldpos: rect.Rectangle = rect.newRect(0, 0, 0, 0),
    active: bool = false,
    full: bool = false,
    min: bool = false,

    contents: WindowContents,

    pub fn new(source: rect.Rectangle, size: vecs.Vector2) WindowData {
        return WindowData{
            .source = source,
            .size = size,
        };
    }

    pub fn deinit(self: *WindowData) void {
        self.contents.deinit();
    }

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle, color: cols.Color) void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @intToFloat(f32, sprite);

        arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), color);
        arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
        arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), color);
        arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
    }

    fn addUiQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, scale: i32, r: f32, l: f32, t: f32, b: f32, color: cols.Color) void {
        var sc = @intToFloat(f32, scale);

        addQuad(arr, sprite, rect.newRect(pos.x, pos.y, sc * l, sc * t), rect.newRect(0, 0, l / TEX_SIZE, t / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y, pos.w - sc * (l + r), sc * t), rect.newRect(l / TEX_SIZE, 0, (TEX_SIZE - l - r) / TEX_SIZE, t / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y, sc * r, sc * t), rect.newRect((TEX_SIZE - r) / TEX_SIZE, 0, r / TEX_SIZE, t / TEX_SIZE), color);

        addQuad(arr, sprite, rect.newRect(pos.x, pos.y + sc * t, sc * l, pos.h - sc * (t + b)), rect.newRect(0, t / TEX_SIZE, l / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + sc * t, pos.w - sc * (l + r), pos.h - sc * (t + b)), rect.newRect(l / TEX_SIZE, t / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + sc * t, sc * r, pos.h - sc * (t + b)), rect.newRect((TEX_SIZE - r) / TEX_SIZE, t / TEX_SIZE, r / TEX_SIZE, (TEX_SIZE - t - b) / TEX_SIZE), color);

        addQuad(arr, sprite, rect.newRect(pos.x, pos.y + pos.h - sc * b, sc * l, sc * b), rect.newRect(0, (TEX_SIZE - b) / TEX_SIZE, l / TEX_SIZE, b / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + sc * l, pos.y + pos.h - sc * b, pos.w - sc * (l + r), sc * b), rect.newRect(l / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, (TEX_SIZE - l - r) / TEX_SIZE, b / TEX_SIZE), color);
        addQuad(arr, sprite, rect.newRect(pos.x + pos.w - sc * r, pos.y + pos.h - sc * b, sc * r, sc * b), rect.newRect((TEX_SIZE - r) / TEX_SIZE, (TEX_SIZE - b) / TEX_SIZE, r / TEX_SIZE, b / TEX_SIZE), color);
    }

    pub fn getDragMode(self: *WindowData, mousepos: vecs.Vector2) DragMode {
        if (self.min) return DragMode.None;

        var close = rect.newRect(self.pos.x + self.pos.w - 64, self.pos.y, 64, 64);
        close.h = 26;
        close.x += close.w - 26;
        close.w = 26;
        if (close.contains(mousepos)) {
            return DragMode.Close;
        }
        var full = rect.newRect(self.pos.x + self.pos.w - 86, self.pos.y, 64, 64);
        full.h = 26;
        full.x += full.w - 26;
        full.w = 26;
        if (full.contains(mousepos)) {
            return DragMode.Full;
        }
        var min = rect.newRect(self.pos.x + self.pos.w - 108, self.pos.y, 64, 64);
        min.h = 26;
        min.x += min.w - 26;
        min.w = 26;
        if (min.contains(mousepos)) {
            return DragMode.Min;
        }

        var move = self.pos;
        move.h = 32;
        if (move.contains(mousepos)) {
            return DragMode.Move;
        }

        var bot = false;

        var bottom = self.pos;
        bottom.y += bottom.h - 10;
        bottom.h = 20;
        if (bottom.contains(mousepos)) {
            bot = true;
        }

        var left = self.pos;
        left.w = 20;
        left.x -= 10;
        if (left.contains(mousepos)) {
            if (bot) {
                return DragMode.ResizeLB;
            } else {
                return DragMode.ResizeL;
            }
        }

        var right = self.pos;
        right.x += right.w - 10;
        right.w = 20;
        if (right.contains(mousepos)) {
            if (bot) {
                return DragMode.ResizeRB;
            } else {
                return DragMode.ResizeR;
            }
        }

        if (bot) {
            return DragMode.ResizeB;
        } else {
            return DragMode.None;
        }
    }

    pub fn drawName(self: *WindowData, shader: shd.Shader, font: *fnt.Font, batch: *sb.SpriteBatch) void {
        if (self.min) return;

        var color = cols.newColorRGBA(197, 197, 197, 255);
        if (self.active) color = cols.newColorRGBA(255, 255, 255, 255);
        font.draw(batch, shader, self.contents.name, vecs.newVec2(self.pos.x + 9, self.pos.y + 3), color);
    }

    pub fn drawContents(self: *WindowData, shader: shd.Shader, font: *fnt.Font, batch: *sb.SpriteBatch) void {
        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 6;
        bnds.y += 34;
        bnds.w -= 12;
        bnds.h -= 40;

        self.contents.draw(batch, shader, &bnds, font);
    }

    pub fn scissor(self: WindowData) rect.Rectangle {
        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        return bnds;
    }

    pub fn click(self: *WindowData, mousepos: vecs.Vector2, btn: i32) bool {
        if (self.min) return false;
        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        if (bnds.contains(mousepos)) {
            return self.contents.click(vecs.newVec2(bnds.w, bnds.h), vecs.newVec2(mousepos.x - bnds.x, mousepos.y - bnds.y), btn);
        }

        return false;
    }

    pub fn key(self: *WindowData, keycode: i32, mods: i32) bool {
        if (self.min) return true;

        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        self.contents.key(keycode, mods);
        return true;
    }

    pub fn getVerts(self: *WindowData, _: vecs.Vector3) va.VertArray {
        var result = va.VertArray.init();
        var sprite: u8 = 0;
        if (self.min) return result;

        if (self.active) {
            sprite = 1;
        }

        if (self.full) {
            self.pos.w = deskSize.x;
            self.pos.h = deskSize.y - 38;
            self.pos.x = 0;
            self.pos.y = 0;
        }

        var close = rect.newRect(self.pos.x + self.pos.w - 64, self.pos.y, 64, 64);
        var full = rect.newRect(self.pos.x + self.pos.w - 86, self.pos.y, 64, 64);
        var min = rect.newRect(self.pos.x + self.pos.w - 108, self.pos.y, 64, 64);

        addUiQuad(&result, sprite, self.pos, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));
        addUiQuad(&result, 3, self.pos, 2, 3, 3, 17, 3, self.contents.clearColor);

        addUiQuad(&result, 4, close, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));
        addUiQuad(&result, 5, full, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));
        addUiQuad(&result, 6, min, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        return result;
    }
};

pub const Window = sb.Drawer(WindowData);
