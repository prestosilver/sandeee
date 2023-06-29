const std = @import("std");
const sb = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");
const allocator = @import("../util/allocator.zig");
const spr = @import("sprite2d.zig");
const popup = @import("popup2d.zig");

const TOTAL_SPRITES: f32 = 7.0;
const TEX_SIZE: f32 = 32;
const RESIZE_PAD: f32 = 10;

pub var deskSize: *vecs.Vector2 = undefined;

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

const SCROLL_MUL = 30;

pub const WindowContents = struct {
    const Self = @This();

    pub const WindowProps = struct {
        const ScrollData = struct {
            offsetStart: f32 = 0,
            value: f32 = 0,
            maxy: f32 = 0,
        };

        const InfoData = struct {
            kind: []const u8,
            name: []const u8,
        };

        const SizeData = struct {
            min: vecs.Vector2,
            max: ?vecs.Vector2,
        };

        scroll: ?ScrollData = null,
        info: InfoData,
        size: SizeData = .{
            .min = vecs.newVec2(400, 300),
            .max = null,
        },

        pub fn setTitle(self: *WindowProps, title: []const u8) !void {
            if (!std.mem.eql(u8, self.info.name, title)) {
                allocator.alloc.free(self.info.name);
                self.info.name = try allocator.alloc.dupe(u8, title);
            }
        }
    };

    const VTable = struct {
        draw: *const fn (*anyopaque, *sb.SpriteBatch, *shd.Shader, *rect.Rectangle, *fnt.Font, *WindowProps) anyerror!void,
        click: *const fn (*anyopaque, vecs.Vector2, vecs.Vector2, i32) anyerror!void,
        key: *const fn (*anyopaque, i32, i32, bool) anyerror!void,
        char: *const fn (*anyopaque, u32, i32) anyerror!void,
        scroll: *const fn (*anyopaque, f32, f32) anyerror!void,
        move: *const fn (*anyopaque, f32, f32) anyerror!void,

        focus: *const fn (*anyopaque) anyerror!void,
        deinit: *const fn (*anyopaque) anyerror!void,
    };

    pub var scrollSp: [4]spr.Sprite = undefined;
    pub var shader: *shd.Shader = undefined;

    clearColor: cols.Color,
    props: WindowProps,

    ptr: *anyopaque,
    vtable: *const VTable,

    pub fn drawScroll(self: *Self, batch: *sb.SpriteBatch, bnds: *rect.Rectangle) !void {
        if (self.props.scroll) |scrolldat| {
            if (scrolldat.maxy <= 0) return;

            var scrollPc = scrolldat.value / scrolldat.maxy;

            scrollSp[1].data.size.y = bnds.h - scrolldat.offsetStart - (12 * 2) + 2;

            try batch.draw(spr.Sprite, &scrollSp[0], shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + scrolldat.offsetStart, 0));
            try batch.draw(spr.Sprite, &scrollSp[1], shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + scrolldat.offsetStart + 12, 0));
            try batch.draw(spr.Sprite, &scrollSp[2], shader, vecs.newVec3(bnds.x + bnds.w - 12, bnds.y + bnds.h - 10, 0));
            try batch.draw(spr.Sprite, &scrollSp[3], shader, vecs.newVec3(bnds.x + bnds.w - 12, (bnds.h - scrolldat.offsetStart - (10 * 2) - 26) * scrollPc + bnds.y + scrolldat.offsetStart + 10, 0));
        }
    }

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        if (self.props.scroll) |*scrollData| {
            if (scrollData.value > scrollData.maxy)
                scrollData.value = scrollData.maxy;
            if (scrollData.value < 0)
                scrollData.value = 0;
        }

        try self.vtable.draw(self.ptr, batch, font_shader, bnds, font, &self.props);
        try self.drawScroll(batch, bnds);
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        return self.vtable.key(self.ptr, keycode, mods, down);
    }

    pub fn char(self: *Self, codepoint: u32, mods: i32) !void {
        return self.vtable.char(self.ptr, codepoint, mods);
    }

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
        if (self.props.scroll) |*scrollData| {
            if (mousepos.x > size.x - 28 and mousepos.x < size.x) {
                var pc = (mousepos.y - 14) / (size.y - 28);
                scrollData.value = std.math.round(scrollData.maxy * pc);
            }
        }
        return self.vtable.click(self.ptr, size, mousepos, btn);
    }

    pub fn drag(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2) !void {
        if (self.props.scroll) |*scrollData| {
            if (mousepos.x > size.x - 28 and mousepos.x < size.x) {
                var pc = (mousepos.y - 14) / (size.y - 28);
                scrollData.value = std.math.round(scrollData.maxy * pc);

                return;
            }
        }
    }

    pub fn scroll(self: *Self, x: f32, y: f32) !void {
        if (self.props.scroll != null) {
            self.props.scroll.?.value -= y * SCROLL_MUL;
        }
        return self.vtable.scroll(self.ptr, x, y);
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
        if (self.props.scroll != null)
            return self.vtable.move(self.ptr, x, y + self.props.scroll.?.value);
        return self.vtable.move(self.ptr, x, y);
    }

    pub fn focus(self: *Self) !void {
        return self.vtable.focus(self.ptr);
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.free(self.props.info.name);
        return self.vtable.deinit(self.ptr);
    }

    pub fn init(ptr: anytype, kind: []const u8, name: []const u8, clearColor: cols.Color) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const gen = struct {
            fn drawImpl(
                pointer: *anyopaque,
                batch: *sb.SpriteBatch,
                font_shader: *shd.Shader,
                bnds: *rect.Rectangle,
                font: *fnt.Font,
                props: *WindowProps,
            ) anyerror!void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.draw, .{ self, batch, font_shader, bnds, font, props });
            }

            fn keyImpl(pointer: *anyopaque, keycode: i32, mods: i32, down: bool) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.key, .{ self, keycode, mods, down });
            }

            fn charImpl(pointer: *anyopaque, codepoint: u32, mods: i32) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.char, .{ self, codepoint, mods });
            }

            fn clickImpl(pointer: *anyopaque, size: vecs.Vector2, pos: vecs.Vector2, btn: c_int) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.click, .{ self, size, pos, btn });
            }

            fn scrollImpl(pointer: *anyopaque, x: f32, y: f32) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.scroll, .{ self, x, y });
            }

            fn moveImpl(pointer: *anyopaque, x: f32, y: f32) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.move, .{ self, x, y });
            }

            fn focusImpl(pointer: *anyopaque) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.focus, .{self});
            }

            fn deinitImpl(pointer: *anyopaque) !void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.auto, ptr_info.Pointer.child.deinit, .{self});
            }

            const vtable = VTable{
                .draw = drawImpl,
                .key = keyImpl,
                .char = charImpl,
                .click = clickImpl,
                .scroll = scrollImpl,
                .move = moveImpl,
                .focus = focusImpl,
                .deinit = deinitImpl,
            };
        };

        return Self{
            .ptr = ptr,
            .props = .{
                .info = .{
                    .kind = kind,
                    .name = allocator.alloc.dupe(u8, name) catch "",
                },
            },
            .vtable = &gen.vtable,
            .clearColor = clearColor,
        };
    }
};

pub const WindowData = struct {
    source: rect.Rectangle,
    pos: rect.Rectangle = rect.newRect(100, 100, 600, 400),

    oldpos: rect.Rectangle = rect.newRect(0, 0, 0, 0),
    active: bool = false,
    full: bool = false,
    min: bool = false,
    idx: usize = 0,
    popup: ?popup.Popup = null,

    contents: WindowContents,

    pub fn new(source: rect.Rectangle, size: vecs.Vector2) WindowData {
        return WindowData{
            .source = source,
            .size = size,
        };
    }

    pub fn deinit(self: *WindowData) !void {
        if (self.popup) |*popupData| {
            try popupData.data.contents.deinit();
        }

        try self.contents.deinit();
    }

    fn addQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, src: rect.Rectangle, color: cols.Color) !void {
        var source = src;

        source.y /= TOTAL_SPRITES;
        source.h /= TOTAL_SPRITES;

        source.y += 1.0 / TOTAL_SPRITES * @as(f32, @floatFromInt(sprite));

        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y + pos.h, 0), vecs.newVec2(source.x + source.w, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
        try arr.append(vecs.newVec3(pos.x, pos.y + pos.h, 0), vecs.newVec2(source.x, source.y + source.h), color);
        try arr.append(vecs.newVec3(pos.x, pos.y, 0), vecs.newVec2(source.x, source.y), color);
        try arr.append(vecs.newVec3(pos.x + pos.w, pos.y, 0), vecs.newVec2(source.x + source.w, source.y), color);
    }

    fn addUiQuad(arr: *va.VertArray, sprite: u8, pos: rect.Rectangle, scale: i32, r: f32, l: f32, t: f32, b: f32, color: cols.Color) !void {
        var sc = @as(f32, @floatFromInt(scale));

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
            if (self.contents.props.size.max == null)
                return DragMode.Full
            else
                return DragMode.None;
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

        var bottom = self.pos;
        bottom.y += bottom.h - RESIZE_PAD;
        bottom.h = RESIZE_PAD * 2;
        bottom.x -= RESIZE_PAD;
        bottom.w += RESIZE_PAD * 2;

        var bot = bottom.contains(mousepos);

        var left = self.pos;
        left.w = RESIZE_PAD * 2;
        left.x -= RESIZE_PAD;
        if (left.contains(mousepos)) {
            if (bot) {
                return DragMode.ResizeLB;
            } else {
                return DragMode.ResizeL;
            }
        }

        var right = self.pos;
        right.x += right.w - RESIZE_PAD;
        right.w = RESIZE_PAD * 2;
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

    pub fn drawName(self: *WindowData, shader: *shd.Shader, font: *fnt.Font, batch: *sb.SpriteBatch) !void {
        if (self.min) return;

        var color = cols.newColorRGBA(197, 197, 197, 255);
        if (self.active) color = cols.newColorRGBA(255, 255, 255, 255);
        try font.draw(.{
            .batch = batch,
            .shader = shader,
            .text = self.contents.props.info.name,
            .pos = vecs.newVec2(self.pos.x + 9, self.pos.y + 8),
            .color = color,
            .wrap = self.pos.w - 50,
            .maxlines = 1,
        });
    }

    pub fn drawContents(self: *WindowData, shader: *shd.Shader, font: *fnt.Font, batch: *sb.SpriteBatch) !void {
        if (self.full) {
            self.pos.w = deskSize.x;
            self.pos.h = deskSize.y - 38;
            self.pos.x = 0;
            self.pos.y = 0;
        }

        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 6;
        bnds.y += 34;
        bnds.w -= 12;
        bnds.h -= 40;

        try batch.addEntry(&.{
            .texture = "",
            .verts = try va.VertArray.init(),
            .shader = shader.*,
            .clear = self.contents.clearColor,
        });

        try self.contents.draw(batch, shader, &bnds, font);
    }

    pub fn scissor(self: *const WindowData) rect.Rectangle {
        var bnds = self.pos;
        bnds.y += 34;
        bnds.x += 6;
        bnds.w -= 12;
        bnds.h -= 40;

        return bnds;
    }

    pub fn click(self: *WindowData, mousepos: vecs.Vector2, btn: i32) !void {
        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        if (bnds.contains(mousepos)) {
            return self.contents.click(vecs.newVec2(bnds.w, bnds.h), vecs.newVec2(mousepos.x - bnds.x, mousepos.y - bnds.y), btn);
        }
    }

    pub fn key(self: *WindowData, keycode: i32, mods: i32, down: bool) !bool {
        if (self.min) return true;

        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        try self.contents.key(keycode, mods, down);
        return true;
    }

    pub fn char(self: *WindowData, codepoint: u32, mods: i32) !void {
        if (self.min) return;

        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        return self.contents.char(codepoint, mods);
    }

    pub fn getVerts(self: *const WindowData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        var sprite: u8 = 0;
        if (self.min) return result;

        if (self.active) {
            sprite = 1;
        }

        var close = rect.newRect(self.pos.x + self.pos.w - 64, self.pos.y, 64, 64);
        var full = rect.newRect(self.pos.x + self.pos.w - 86, self.pos.y, 64, 64);
        var min = rect.newRect(self.pos.x + self.pos.w - 108, self.pos.y, 64, 64);

        try addUiQuad(&result, sprite, self.pos, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        var maxAlpha: f32 = if (self.contents.props.size.max == null) 1.0 else 0.75;
        try addUiQuad(&result, 4, close, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));
        try addUiQuad(&result, 5, full, 2, 3, 3, 17, 3, cols.newColor(maxAlpha, maxAlpha, maxAlpha, 1));
        try addUiQuad(&result, 6, min, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        return result;
    }
};

pub const Window = sb.Drawer(WindowData);
