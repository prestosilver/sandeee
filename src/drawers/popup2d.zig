const std = @import("std");

const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const va = @import("../util/vertArray.zig");
const win2d = @import("window2d.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");

const SpriteBatch = @import("../util/spritebatch.zig");

pub const all = @import("../windows/popups/all.zig");

pub var popup_shader: *shd.Shader = undefined;

const TOTAL_SPRITES: f32 = 9.0;
const TEX_SIZE: f32 = 32;

pub const PopupData = struct {
    pub const PopupContents = struct {
        const Self = @This();

        const VTable = struct {
            draw: *const fn (*anyopaque, *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) anyerror!void,
            key: *const fn (*anyopaque, i32, i32, bool) anyerror!void,
            char: *const fn (*anyopaque, u32, i32) anyerror!void,
            click: *const fn (*anyopaque, vecs.Vector2) anyerror!void,
            deinit: *const fn (*anyopaque) void,
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

        pub fn deinit(self: *Self) void {
            return self.vtable.deinit(self.ptr);
        }

        pub fn init(ptr: anytype) Self {
            const Ptr = @TypeOf(ptr);
            const ptr_info = @typeInfo(Ptr);

            if (ptr_info != .pointer) @compileError("ptr must be a pointer");
            if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

            const child_t = ptr_info.pointer.child;

            const gen = struct {
                fn drawImpl(pointer: *anyopaque, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.draw, .{ self, shader, bnds, font });
                }

                fn keyImpl(pointer: *anyopaque, keycode: c_int, mods: c_int, down: bool) !void {
                    if (std.meta.hasMethod(child_t, "key")) {
                        const self: Ptr = @ptrCast(@alignCast(pointer));

                        return @call(.always_inline, ptr_info.pointer.child.key, .{ self, keycode, mods, down });
                    }
                }

                fn charImpl(pointer: *anyopaque, keycode: u32, mods: i32) !void {
                    if (std.meta.hasMethod(child_t, "char")) {
                        const self: Ptr = @ptrCast(@alignCast(pointer));

                        return @call(.always_inline, ptr_info.pointer.child.char, .{ self, keycode, mods });
                    }
                }

                fn deinitImpl(pointer: *anyopaque) void {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.deinit, .{self});
                }

                fn clickImpl(pointer: *anyopaque, mousepos: vecs.Vector2) !void {
                    if (std.meta.hasMethod(child_t, "click")) {
                        const self: Ptr = @ptrCast(@alignCast(pointer));

                        return @call(.always_inline, ptr_info.pointer.child.click, .{ self, mousepos });
                    }
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
    pos: rect.Rectangle,
    contents: PopupContents,
    title: []const u8,

    pub fn drawName(self: *PopupData, shader: *shd.Shader, font: *fnt.Font) !void {
        try font.draw(.{
            .shader = shader,
            .text = self.title,
            .pos = .{ .x = self.pos.x + 9, .y = self.pos.y + 8 },
            .color = .{ .r = 1, .g = 1, .b = 1 },
            .wrap = self.pos.w - 64,
            .maxlines = 1,
        });
    }

    pub fn drawContents(self: *PopupData, shader: *shd.Shader, font: *fnt.Font) !void {
        try SpriteBatch.global.addEntry(&.{
            .texture = .none,
            .verts = try va.VertArray.init(0),
            .shader = shader.*,
            .clear = .{ .r = 0.75, .g = 0.75, .b = 0.75 },
        });

        try self.contents.draw(shader, self.scissor(), font);
    }

    pub fn getVerts(self: *const PopupData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(9 * 6 * 2);
        const sprite: u8 = 2;

        const close = rect.Rectangle{
            .x = self.pos.x + self.pos.w - 64,
            .y = self.pos.y,
            .w = 64,
            .h = 64,
        };

        try result.appendUiQuad(self.pos, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = @floatFromInt(sprite) },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });
        try result.appendUiQuad(close, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = 3 },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });

        return result;
    }

    pub const ClickKind = enum {
        Close,
        Move,
        None,
    };

    const PADDING = 26;

    pub fn click(self: *PopupData, mousepos: vecs.Vector2) !ClickKind {
        const close = rect.Rectangle{
            .x = self.pos.x + self.pos.w - 64 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (close.contains(mousepos)) {
            return .Close;
        }

        const click_pos = mousepos.sub(self.pos.location());

        if (click_pos.x < 0) return .None;
        if (click_pos.x > self.pos.w or click_pos.y > self.pos.h) return .None;

        if (click_pos.y < 34 and click_pos.y > 0) return .Move;

        try self.contents.click(click_pos);

        return .None;
    }

    pub inline fn scissor(self: *const PopupData) rect.Rectangle {
        return .{
            .x = self.pos.x + 6,
            .y = self.pos.y + 34,
            .w = self.pos.w - 12,
            .h = self.pos.h - 40,
        };
    }
};

pub const Popup = SpriteBatch.Drawer(PopupData);
