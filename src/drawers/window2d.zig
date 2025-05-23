const std = @import("std");
const batch = @import("../util/spritebatch.zig");
const vecs = @import("../math/vecs.zig");
const cols = @import("../math/colors.zig");
const rect = @import("../math/rects.zig");
const fnt = @import("../util/font.zig");
const shd = @import("../util/shader.zig");
const va = @import("../util/vertArray.zig");
const allocator = @import("../util/allocator.zig");
const spr = @import("sprite2d.zig");
const gfx = @import("../util/graphics.zig");
const c = @import("../c.zig");

const TOTAL_SPRITES: f32 = 9.0;
const TEX_SIZE: f32 = 32;
const RESIZE_PAD: f32 = 10;

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

// TODO: un hardcode
pub const SCROLL_MUL = 30;

pub const WindowContents = struct {
    const Self = @This();

    pub const WindowProps = struct {
        const ScrollData = struct {
            offset_start: f32 = 0,
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
            .min = .{ .x = 400, .y = 300 },
            .max = null,
        },
        close: bool = false,
        clear_color: cols.Color,

        no_min: bool = false,
        no_close: bool = false,

        pub fn setTitle(self: *WindowProps, title: []const u8) !void {
            if (!std.mem.eql(u8, self.info.name, title)) {
                allocator.alloc.free(self.info.name);
                self.info.name = try allocator.alloc.dupe(u8, title);
            }
        }
    };

    const Vtable = struct {
        draw: *const fn (*anyopaque, *shd.Shader, *rect.Rectangle, *fnt.Font, *WindowProps) anyerror!void,
        click: *const fn (*anyopaque, vecs.Vector2, vecs.Vector2, ?i32) anyerror!void,
        key: *const fn (*anyopaque, i32, i32, bool) anyerror!void,
        char: *const fn (*anyopaque, u32, i32) anyerror!void,
        scroll: *const fn (*anyopaque, f32, f32) anyerror!void,
        move: *const fn (*anyopaque, f32, f32) anyerror!void,

        moveResize: *const fn (*anyopaque, rect.Rectangle) anyerror!void,

        refresh: *const fn (*anyopaque) anyerror!void,
        focus: *const fn (*anyopaque) anyerror!void,
        deinit: *const fn (*anyopaque) void,
    };

    pub var scroll_sp: [4]spr.Sprite = undefined;
    pub var shader: *shd.Shader = undefined;

    props: WindowProps,

    scrolling: bool = false,

    ptr: *anyopaque,
    vtable: *const Vtable,

    pub fn drawScroll(self: *Self, bnds: *rect.Rectangle) !void {
        if (self.props.scroll) |scroll_data| {
            if (scroll_data.maxy <= 0) return;

            const scroll_pc = scroll_data.value / scroll_data.maxy;

            scroll_sp[1].data.size.y = bnds.h - scroll_data.offset_start - (20 * 2 - 2) + 2;

            try batch.SpriteBatch.instance.draw(spr.Sprite, &scroll_sp[0], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + scroll_data.offset_start });
            try batch.SpriteBatch.instance.draw(spr.Sprite, &scroll_sp[1], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + scroll_data.offset_start + 20 });
            try batch.SpriteBatch.instance.draw(spr.Sprite, &scroll_sp[2], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + bnds.h - 20 + 2 });
            try batch.SpriteBatch.instance.draw(spr.Sprite, &scroll_sp[3], shader, .{ .x = bnds.x + bnds.w - 20, .y = (bnds.h - scroll_data.offset_start - (20 * 2) - 30 + 4) * scroll_pc + bnds.y + scroll_data.offset_start + 20 - 2 });
        }
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        if (self.props.scroll) |*scroll_data| {
            if (scroll_data.value > scroll_data.maxy)
                scroll_data.value = scroll_data.maxy;
            if (scroll_data.value < 0)
                scroll_data.value = 0;
        }

        try self.vtable.draw(self.ptr, font_shader, bnds, font, &self.props);
        try self.drawScroll(bnds);
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (keycode == c.GLFW_KEY_PAGE_UP) {
            if (self.props.scroll) |*scroll_data|
                scroll_data.value -= 1 * SCROLL_MUL;
        } else if (keycode == c.GLFW_KEY_PAGE_DOWN) {
            if (self.props.scroll) |*scroll_data|
                scroll_data.value += 1 * SCROLL_MUL;
        } else {
            return self.vtable.key(self.ptr, keycode, mods, down);
        }
    }

    pub fn char(self: *Self, codepoint: u32, mods: i32) !void {
        return self.vtable.char(self.ptr, codepoint, mods);
    }

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (btn) |_| {
            if (self.props.scroll) |*scroll_data| {
                self.scrolling = false;
                if (mousepos.x > size.x - 28 and mousepos.x < size.x and mousepos.y > scroll_data.offset_start + 14) {
                    const pc = (mousepos.y - 14 - scroll_data.offset_start) / (size.y - 28 - scroll_data.offset_start);
                    scroll_data.value = std.math.round(scroll_data.maxy * pc);
                    self.scrolling = true;
                    return;
                }
            }
        }

        return self.vtable.click(self.ptr, size, mousepos, btn);
    }

    pub fn drag(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2) !void {
        if (self.props.scroll) |*scroll_data| {
            if (self.scrolling) {
                const pc = (mousepos.y - 14 - scroll_data.offset_start) / (size.y - 28 - scroll_data.offset_start);
                scroll_data.value = std.math.round(scroll_data.maxy * pc);

                return;
            }
        }
    }

    pub fn scroll(self: *Self, x: f32, y: f32) !void {
        if (self.props.scroll) |*scroll_data| {
            scroll_data.value -= y * SCROLL_MUL;
        }

        return self.vtable.scroll(self.ptr, x, y);
    }

    pub fn move(self: *Self, x: f32, y: f32) !void {
        if (self.props.scroll) |*scroll_data|
            return self.vtable.move(self.ptr, x, y + scroll_data.value);
        return self.vtable.move(self.ptr, x, y);
    }

    pub fn focus(self: *Self) !void {
        return self.vtable.focus(self.ptr);
    }

    pub fn refresh(self: *Self) !void {
        return self.vtable.refresh(self.ptr);
    }

    pub fn moveResize(self: *Self, bnds: rect.Rectangle) !void {
        return self.vtable.moveResize(self.ptr, bnds);
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.free(self.props.info.name);
        return self.vtable.deinit(self.ptr);
    }

    pub fn init(ptr: anytype, kind: []const u8, name: []const u8, clear_color: cols.Color) !Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const child_t = ptr_info.pointer.child;

        const gen = struct {
            fn drawImpl(
                pointer: *anyopaque,
                font_shader: *shd.Shader,
                bnds: *rect.Rectangle,
                font: *fnt.Font,
                props: *WindowProps,
            ) anyerror!void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.always_inline, ptr_info.pointer.child.draw, .{ self, font_shader, bnds, font, props });
            }

            fn deinitImpl(pointer: *anyopaque) void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.always_inline, ptr_info.pointer.child.deinit, .{self});
            }

            fn keyImpl(pointer: *anyopaque, keycode: i32, mods: i32, down: bool) !void {
                if (std.meta.hasMethod(child_t, "key")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.key, .{ self, keycode, mods, down });
                }
            }

            fn charImpl(pointer: *anyopaque, codepoint: u32, mods: i32) !void {
                if (std.meta.hasMethod(child_t, "char")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.char, .{ self, codepoint, mods });
                }
            }

            fn clickImpl(pointer: *anyopaque, size: vecs.Vector2, pos: vecs.Vector2, btn: ?c_int) !void {
                if (std.meta.hasMethod(child_t, "click")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.click, .{ self, size, pos, btn });
                }
            }

            fn scrollImpl(pointer: *anyopaque, x: f32, y: f32) !void {
                if (std.meta.hasMethod(child_t, "scroll")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.scroll, .{ self, x, y });
                }
            }

            fn moveImpl(pointer: *anyopaque, x: f32, y: f32) !void {
                if (std.meta.hasMethod(child_t, "move")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.move, .{ self, x, y });
                }
            }

            fn focusImpl(pointer: *anyopaque) !void {
                if (std.meta.hasMethod(child_t, "focus")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.focus, .{self});
                }
            }

            fn moveResizeImpl(pointer: *anyopaque, bnds: rect.Rectangle) !void {
                if (std.meta.hasMethod(child_t, "moveResize")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.moveResize, .{ self, bnds });
                }
            }

            fn refreshImpl(pointer: *anyopaque) !void {
                if (std.meta.hasMethod(child_t, "refresh")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.refresh, .{self});
                }
            }

            const vtable = Vtable{
                .draw = drawImpl,
                .key = keyImpl,
                .char = charImpl,
                .click = clickImpl,
                .scroll = scrollImpl,
                .moveResize = moveResizeImpl,
                .move = moveImpl,
                .focus = focusImpl,
                .deinit = deinitImpl,
                .refresh = refreshImpl,
            };
        };

        return Self{
            .ptr = ptr,
            .props = .{
                .info = .{
                    .kind = kind,
                    .name = try allocator.alloc.dupe(u8, name),
                },
                .clear_color = clear_color,
            },
            .vtable = &gen.vtable,
        };
    }
};

pub const WindowData = struct {
    source: rect.Rectangle = .{ .w = 1.0, .h = 1.0 },
    pos: rect.Rectangle = .{ .x = 100, .y = 100, .w = 600, .h = 400 },

    oldpos: rect.Rectangle = .{ .w = 0.0, .h = 0.0 },
    active: bool = false,
    full: bool = false,
    min: bool = false,
    idx: usize = 0,
    should_close: bool = false,

    contents: WindowContents,

    pub fn deinit(self: *WindowData) void {
        self.contents.deinit();
    }

    const PADDING = 25;

    pub fn getDragMode(self: *WindowData, mousepos: vecs.Vector2) DragMode {
        if (self.min) return DragMode.None;

        const close = rect.Rectangle{
            .x = self.pos.x + self.pos.w - 64 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (close.contains(mousepos)) {
            return DragMode.Close;
        }
        const full = rect.Rectangle{
            .x = self.pos.x + self.pos.w - 86 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (full.contains(mousepos)) {
            if (self.contents.props.size.max == null)
                return DragMode.Full
            else
                return DragMode.None;
        }
        const min = rect.Rectangle{
            .x = self.pos.x + self.pos.w - 108 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (min.contains(mousepos)) {
            return DragMode.Min;
        }

        const move = rect.Rectangle{
            .x = self.pos.x,
            .y = self.pos.y,
            .w = self.pos.w,
            .h = 32,
        };
        if (move.contains(mousepos)) {
            return DragMode.Move;
        }

        if (self.contents.props.size.max) |max_size| {
            const min_size = self.contents.props.size.min;
            if (max_size.x == min_size.x and
                max_size.y == min_size.y)
            {
                return DragMode.None;
            }
        }

        const bottom = rect.Rectangle{
            .x = self.pos.x - RESIZE_PAD,
            .y = self.pos.y + self.pos.h - RESIZE_PAD,
            .w = self.pos.w + RESIZE_PAD * 2,
            .h = RESIZE_PAD * 2,
        };

        const bot = bottom.contains(mousepos);

        const left = rect.Rectangle{
            .x = self.pos.x - RESIZE_PAD,
            .y = self.pos.y,
            .w = RESIZE_PAD * 2,
            .h = self.pos.h,
        };
        if (left.contains(mousepos)) {
            if (bot) {
                return DragMode.ResizeLB;
            } else {
                return DragMode.ResizeL;
            }
        }

        const right = rect.Rectangle{
            .x = self.pos.x + self.pos.w - RESIZE_PAD,
            .y = self.pos.y,
            .w = RESIZE_PAD * 2,
            .h = self.pos.h,
        };
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

    pub fn drawName(self: *WindowData, shader: *shd.Shader, font: *fnt.Font) !void {
        if (self.min) return;

        const color = if (self.active)
            cols.Color{ .r = 1, .g = 1, .b = 1 }
        else
            cols.Color{ .r = 0.75, .g = 0.75, .b = 0.75 };

        try font.draw(.{
            .shader = shader,
            .text = self.contents.props.info.name,
            .pos = .{ .x = self.pos.x + 9, .y = self.pos.y + 8 },
            .color = color,
            .wrap = self.pos.w - 100,
            .maxlines = 1,
        });
    }

    pub fn drawContents(self: *WindowData, shader: *shd.Shader, font: *fnt.Font) !void {
        const desk_size = gfx.Context.instance.size;

        if (self.full) {
            self.pos.w = desk_size.x;
            self.pos.h = desk_size.y - 38;
            self.pos.x = 0;
            self.pos.y = 0;
        }

        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 6;
        bnds.y += 34;
        bnds.w -= 12;
        bnds.h -= 40;

        try batch.SpriteBatch.instance.addEntry(&.{
            .texture = "",
            .verts = try va.VertArray.init(0),
            .shader = shader.*,
            .clear = self.contents.props.clear_color,
        });

        try self.contents.draw(shader, &bnds, font);
    }

    pub fn scissor(self: *const WindowData) rect.Rectangle {
        var bnds = self.pos;
        bnds.y += 34;
        bnds.x += 6;
        bnds.w -= 12;
        bnds.h -= 40;

        return bnds;
    }

    pub fn click(self: *WindowData, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        if (bnds.contains(mousepos) or btn == null) {
            return self.contents.click(bnds.size(), .{ .x = mousepos.x - bnds.x, .y = mousepos.y - bnds.y }, btn);
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

    pub fn refresh(self: *WindowData) !void {
        return self.contents.refresh();
    }

    pub fn update(self: *WindowData) void {
        if (self.contents.props.size.max) |max| {
            const min = self.contents.props.size.min;
            if (max.y == min.y and
                max.x == min.x)
            {
                self.pos.w = self.contents.props.size.min.x;
                self.pos.h = self.contents.props.size.min.y;
            }
        }

        self.pos = self.pos.round();
    }

    pub fn getVerts(self: *const WindowData, _: vecs.Vector3) !va.VertArray {
        var result = try va.VertArray.init(9 * 6 * 4 + 3 * 6);
        var sprite: u8 = 0;
        if (self.min) return result;

        if (self.active) {
            sprite = 1;
        }

        const close = rect.Rectangle{ .x = self.pos.x + self.pos.w - 64, .y = self.pos.y, .w = 64, .h = 64 };
        const full = rect.Rectangle{ .x = self.pos.x + self.pos.w - 86, .y = self.pos.y, .w = 64, .h = 64 };
        const min = rect.Rectangle{ .x = self.pos.x + self.pos.w - 108, .y = self.pos.y, .w = 64, .h = 64 };

        try result.appendUiQuad(self.pos, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = @floatFromInt(sprite) },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });

        const close_index: u8 = if (!self.contents.props.no_close) 3 else 6;
        const max_index: u8 = if (self.contents.props.size.max == null) 4 else 7;
        const min_index: u8 = if (!self.contents.props.no_min) 5 else 8;

        try result.appendUiQuad(close, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = @floatFromInt(close_index) },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });
        try result.appendUiQuad(full, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = @floatFromInt(max_index) },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });
        try result.appendUiQuad(min, .{
            .sheet_size = .{ .x = 1, .y = TOTAL_SPRITES },
            .sprite_size = .{ .x = TEX_SIZE, .y = TEX_SIZE },
            .sprite = .{ .y = @floatFromInt(min_index) },
            .draw_scale = 2,
            .borders = .{ .l = 3, .r = 3, .t = 17, .b = 3 },
        });

        return result;
    }
};

pub const Window = batch.Drawer(WindowData);
