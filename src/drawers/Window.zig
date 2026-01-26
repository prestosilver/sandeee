const std = @import("std");
const glfw = @import("glfw");

const drawers = @import("../drawers.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");

const Sprite = drawers.Sprite;

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const VertArray = util.VertArray;
const Shader = util.Shader;
const Font = util.Font;
const graphics = util.graphics;
const allocator = util.allocator;
const SpriteBatch = util.SpriteBatch;

const ClickKind = events.input.ClickKind;

const config = system.config;

pub const WindowData = struct {
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

    pub inline fn scroll_mul() f32 {
        return 30 * (config.SettingManager.instance.getFloat("scroll_speed") orelse 1.0);
    }

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
                min: Vec2,
                max: ?Vec2,
            };

            scroll: ?ScrollData = null,
            info: InfoData,
            size: SizeData = .{
                .min = .{ .x = 400, .y = 300 },
                .max = null,
            },
            close: bool = false,
            clear_color: Color,

            no_min: bool = false,
            no_close: bool = false,

            pub fn setTitle(self: *WindowProps, title: []const u8) !void {
                if (!std.mem.eql(u8, self.info.name, title)) {
                    allocator.free(self.info.name);
                    self.info.name = try allocator.dupe(u8, title);
                }
            }
        };

        const Vtable = struct {
            draw: *const fn (*anyopaque, *Shader, *Rect, *Font, *WindowProps) anyerror!void,
            click: *const fn (*anyopaque, Vec2, Vec2, i32, ClickKind) anyerror!void,
            key: *const fn (*anyopaque, i32, i32, bool) anyerror!void,
            char: *const fn (*anyopaque, u32, i32) anyerror!void,
            scroll: *const fn (*anyopaque, f32, f32) anyerror!void,
            move: *const fn (*anyopaque, f32, f32) anyerror!void,

            moveResize: *const fn (*anyopaque, Rect) anyerror!void,

            refresh: *const fn (*anyopaque) anyerror!void,
            focus: *const fn (*anyopaque) anyerror!void,
            deinit: *const fn (*anyopaque) void,
        };

        pub var scroll_sp: [4]Sprite = undefined;
        pub var shader: *Shader = undefined;

        props: WindowProps,

        scrolling: bool = false,

        ptr: *anyopaque,
        vtable: *const Vtable,

        pub fn drawScroll(self: *Self, bnds: *Rect) !void {
            if (self.props.scroll) |scroll_data| {
                if (scroll_data.maxy <= 0) return;

                const scroll_pc = scroll_data.value / scroll_data.maxy;

                scroll_sp[1].data.size.y = bnds.h - scroll_data.offset_start - (20 * 2 - 2) + 2;

                try SpriteBatch.global.draw(Sprite, &scroll_sp[0], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + scroll_data.offset_start });
                try SpriteBatch.global.draw(Sprite, &scroll_sp[1], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + scroll_data.offset_start + 20 });
                try SpriteBatch.global.draw(Sprite, &scroll_sp[2], shader, .{ .x = bnds.x + bnds.w - 20, .y = bnds.y + bnds.h - 20 + 2 });
                try SpriteBatch.global.draw(Sprite, &scroll_sp[3], shader, .{ .x = bnds.x + bnds.w - 20, .y = (bnds.h - scroll_data.offset_start - (20 * 2) - 30 + 4) * scroll_pc + bnds.y + scroll_data.offset_start + 20 - 2 });
            }
        }

        pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font) !void {
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
            if (keycode == glfw.KeyPageUp) {
                if (self.props.scroll) |*scroll_data|
                    scroll_data.value -= 1 * scroll_mul();
            } else if (keycode == glfw.KeyPageDown) {
                if (self.props.scroll) |*scroll_data|
                    scroll_data.value += 1 * scroll_mul();
            } else {
                return self.vtable.key(self.ptr, keycode, mods, down);
            }
        }

        pub fn char(self: *Self, codepoint: u32, mods: i32) !void {
            return self.vtable.char(self.ptr, codepoint, mods);
        }

        pub fn click(self: *Self, size: Vec2, mousepos: Vec2, btn: i32, kind: ClickKind) !void {
            if (kind == .down) {
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

            return self.vtable.click(self.ptr, size, mousepos, btn, kind);
        }

        pub fn drag(self: *Self, size: Vec2, mousepos: Vec2) !void {
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
                scroll_data.value -= y * scroll_mul();
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

        pub fn moveResize(self: *Self, bnds: Rect) !void {
            return self.vtable.moveResize(self.ptr, bnds);
        }

        pub fn deinit(self: *Self) void {
            self.vtable.deinit(self.ptr);

            allocator.free(self.props.info.name);

            return;
        }

        pub fn init(ptr: anytype, kind: []const u8, name: []const u8, clear_color: Color) !Self {
            const Ptr = @TypeOf(ptr);
            const ptr_info = @typeInfo(Ptr);

            if (ptr_info != .pointer) @compileError("ptr must be a pointer");
            if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

            const child_t = ptr_info.pointer.child;

            const gen = struct {
                fn drawImpl(
                    pointer: *anyopaque,
                    font_shader: *Shader,
                    bnds: *Rect,
                    font: *Font,
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

                fn clickImpl(pointer: *anyopaque, size: Vec2, pos: Vec2, btn: c_int, click_kind: ClickKind) !void {
                    if (std.meta.hasMethod(child_t, "click")) {
                        const self: Ptr = @ptrCast(@alignCast(pointer));

                        return @call(.always_inline, ptr_info.pointer.child.click, .{ self, size, pos, btn, click_kind });
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

                fn moveResizeImpl(pointer: *anyopaque, bnds: Rect) !void {
                    if (std.meta.hasMethod(child_t, "moveResize")) {
                        const self: Ptr = @ptrCast(@alignCast(pointer));

                        return @call(.always_inline, ptr_info.pointer.child.moveResize, .{ self, Rect{
                            .x = bnds.x + 6,
                            .y = bnds.y + 34,
                            .w = bnds.w - 12,
                            .h = bnds.h - 40,
                        } });
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
                        .name = try allocator.dupe(u8, name),
                    },
                    .clear_color = clear_color,
                },
                .vtable = &gen.vtable,
            };
        }
    };

    source: Rect = .{ .w = 1.0, .h = 1.0 },
    pos: Rect = .{ .x = 100, .y = 100, .w = 600, .h = 400 },

    oldpos: Rect = .{ .w = 0.0, .h = 0.0 },
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

    pub fn getDragMode(self: *WindowData, mousepos: Vec2) DragMode {
        if (self.min) return DragMode.None;

        const close = Rect{
            .x = self.pos.x + self.pos.w - 64 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (close.contains(mousepos)) {
            return DragMode.Close;
        }
        const full = Rect{
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
        const min = Rect{
            .x = self.pos.x + self.pos.w - 108 + 64 - PADDING,
            .y = self.pos.y,
            .w = PADDING,
            .h = PADDING,
        };
        if (min.contains(mousepos)) {
            return DragMode.Min;
        }

        const move = Rect{
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

        const bottom = Rect{
            .x = self.pos.x - RESIZE_PAD,
            .y = self.pos.y + self.pos.h - RESIZE_PAD,
            .w = self.pos.w + RESIZE_PAD * 2,
            .h = RESIZE_PAD * 2,
        };

        const bot = bottom.contains(mousepos);

        const left = Rect{
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

        const right = Rect{
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

    pub fn drawName(self: *WindowData, shader: *Shader, font: *Font) !void {
        if (self.min) return;

        const color = if (self.active)
            Color{ .r = 1, .g = 1, .b = 1 }
        else
            Color{ .r = 0.75, .g = 0.75, .b = 0.75 };

        try font.draw(.{
            .shader = shader,
            .text = self.contents.props.info.name,
            .pos = .{ .x = self.pos.x + 9, .y = self.pos.y + 8 },
            .color = color,
            .wrap = self.pos.w - 100,
            .maxlines = 1,
        });
    }

    pub fn drawContents(self: *WindowData, shader: *Shader, font: *Font) !void {
        const desk_size = graphics.Context.instance.size;

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

        try SpriteBatch.global.addEntry(&.{
            .texture = .none,
            .verts = try VertArray.init(0),
            .shader = shader.*,
            .clear = self.contents.props.clear_color,
        });

        try self.contents.draw(shader, &bnds, font);
    }

    pub fn scissor(self: *const WindowData) Rect {
        var bnds = self.pos;
        bnds.y += 34;
        bnds.x += 6;
        bnds.w -= 12;
        bnds.h -= 40;

        return bnds;
    }

    pub fn click(self: *WindowData, mousepos: Vec2, btn: i32, kind: ClickKind) !void {
        if (self.min) return;
        var bnds = self.pos;
        bnds.x += 4;
        bnds.y += 32;
        bnds.w -= 8;
        bnds.h -= 36;

        if (bnds.contains(mousepos) or kind == .up) {
            return self.contents.click(bnds.size(), .{ .x = mousepos.x - bnds.x, .y = mousepos.y - bnds.y }, btn, kind);
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

    pub fn getVerts(self: *const WindowData, _: Vec3) !VertArray {
        var result = try VertArray.init(9 * 6 * 4 + 3 * 6);
        var sprite: u8 = 0;
        if (self.min) return result;

        if (self.active) {
            sprite = 1;
        }

        const close = Rect{ .x = self.pos.x + self.pos.w - 64, .y = self.pos.y, .w = 64, .h = 64 };
        const full = Rect{ .x = self.pos.x + self.pos.w - 86, .y = self.pos.y, .w = 64, .h = 64 };
        const min = Rect{ .x = self.pos.x + self.pos.w - 108, .y = self.pos.y, .w = 64, .h = 64 };

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

pub const drawer = SpriteBatch.Drawer(WindowData);
