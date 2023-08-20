const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const win2d = @import("window2d.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const batch = @import("../util/spritebatch.zig");

pub const all = @import("../windows/popups/all.zig");

pub var popupShader: *shd.Shader = undefined;

const TOTAL_SPRITES: f32 = 7.0;
const TEX_SIZE: f32 = 32;

pub const PopupData = struct {
    pub const PopupContents = struct {
        const Self = @This();

        const VTable = struct {
            draw: *const fn (*anyopaque, *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) anyerror!void,
            key: *const fn (*anyopaque, i32, i32, bool) anyerror!void,
            char: *const fn (*anyopaque, u32, i32) anyerror!void,
            click: *const fn (*anyopaque, vecs.Vector2) anyerror!void,
            deinit: *const fn (*anyopaque) anyerror!void,
        };

        ptr: *anyopaque,
        vtable: *const VTable,

        pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
            return self.vtable.draw(self.ptr, shader, bnds, font);
        }

        pub fn char(self: *Self, keycode: u32, mods: i32) !void {
            return self.vtable.char(self.ptr, keycode, mods);
        }

        pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
            return self.vtable.key(self.ptr, keycode, mods, down);
        }

        pub fn click(self: *Self, mousepos: vecs.Vector2) !void {
            return self.vtable.click(self.ptr, mousepos);
        }

        pub fn deinit(self: *Self) !void {
            return self.vtable.deinit(self.ptr);
        }

        pub fn init(ptr: anytype) Self {
            const Ptr = @TypeOf(ptr);
            const ptr_info = @typeInfo(Ptr);

            if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
            if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

            const gen = struct {
                fn drawImpl(pointer: *anyopaque, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.Pointer.child.draw, .{ self, shader, bnds, font });
                }

                fn keyImpl(pointer: *anyopaque, keycode: c_int, mods: c_int, down: bool) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.Pointer.child.key, .{ self, keycode, mods, down });
                }

                fn charImpl(pointer: *anyopaque, keycode: u32, mods: i32) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.Pointer.child.char, .{ self, keycode, mods });
                }

                fn deinitImpl(pointer: *anyopaque) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.Pointer.child.deinit, .{self});
                }

                fn clickImpl(pointer: *anyopaque, mousepos: vecs.Vector2) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.Pointer.child.click, .{ self, mousepos });
                }

                const vtable = VTable{
                    .draw = drawImpl,
                    .key = keyImpl,
                    .char = charImpl,
                    .deinit = deinitImpl,
                    .click = clickImpl,
                };
            };

            return Self{
                .ptr = ptr,
                .vtable = &gen.vtable,
            };
        }
    };

    source: rect.Rectangle,
    size: vecs.Vector2,
    parentPos: rect.Rectangle,
    contents: PopupContents,
    title: []const u8,

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
        const sc = @as(f32, @floatFromInt(scale));

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

    pub fn drawName(self: *PopupData, shader: *shd.Shader, font: *fnt.Font) !void {
        const pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2)).round();

        const color = cols.newColorRGBA(255, 255, 255, 255);
        try font.draw(.{
            .shader = shader,
            .text = self.title,
            .pos = vecs.newVec2(pos.x + 9, pos.y + 8),
            .color = color,
            .wrap = self.size.x,
            .maxlines = 1,
        });
    }

    pub fn drawContents(self: *PopupData, shader: *shd.Shader, font: *fnt.Font) !void {
        try batch.SpriteBatch.instance.addEntry(&.{
            .texture = "",
            .verts = try va.VertArray.init(),
            .shader = shader.*,
            .clear = cols.newColorRGBA(192, 192, 192, 255),
        });

        try self.contents.draw(shader, self.scissor(), font);
    }

    pub fn getVerts(self: *const PopupData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init();
        const sprite: u8 = 1;

        const pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2)).round();

        const close = rect.newRect(pos.x + self.size.x - 64, pos.y, 64, 64);

        try addUiQuad(&result, sprite, rect.newRect(pos.x, pos.y, self.size.x, self.size.y), 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        try addUiQuad(&result, 4, close, 2, 3, 3, 17, 3, cols.newColor(1, 1, 1, 1));

        return result;
    }

    pub fn click(self: *PopupData, mousepos: vecs.Vector2) !bool {
        const pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2)).round();
        var close = rect.newRect(pos.x + self.size.x - 64, pos.y, 64, 64);
        close.h = 26;
        close.x += close.w - 26;
        close.w = 26;
        if (close.contains(mousepos)) {
            return true;
        }

        const clickPos = mousepos.sub(pos);

        if (clickPos.x < 0 or clickPos.y < 34) return false;
        if (clickPos.x > self.size.x or clickPos.y > self.size.y) return false;

        try self.contents.click(clickPos);

        return false;
    }

    pub fn scissor(self: *const PopupData) rect.Rectangle {
        const pos = self.parentPos.location().add(self.parentPos.size().sub(self.size).div(2)).round();
        return .{
            .x = pos.x + 6,
            .y = pos.y + 34,
            .w = self.size.x - 12,
            .h = self.size.y - 40,
        };
    }
};

pub const Popup = batch.Drawer(PopupData);
