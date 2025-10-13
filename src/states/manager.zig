const std = @import("std");

const math = @import("../math/mod.zig");

const Vec2 = math.Vec2;

pub const GameState = struct {
    const Self = @This();

    pub const Vtable = struct {
        setup: *const fn (*anyopaque) anyerror!void,
        deinit: *const fn (*anyopaque) void,
        refresh: *const fn (*anyopaque) anyerror!void,
        draw: *const fn (*anyopaque, Vec2) anyerror!void,
        update: *const fn (*anyopaque, f32) anyerror!void,
        keypress: *const fn (*anyopaque, c_int, c_int, bool) anyerror!void,
        keychar: *const fn (*anyopaque, u32, i32) anyerror!void,
        mousepress: *const fn (*anyopaque, c_int) anyerror!void,
        mouserelease: *const fn (*anyopaque) anyerror!void,
        mousemove: *const fn (*anyopaque, Vec2) anyerror!void,
        mousescroll: *const fn (*anyopaque, Vec2) anyerror!void,
    };

    ptr: *anyopaque,
    vtable: *const Vtable,
    is_setup: bool,

    pub fn setup(state: *Self) anyerror!void {
        if (!state.is_setup)
            try state.vtable.setup(state.ptr);
        state.is_setup = true;
    }

    pub fn deinit(state: *Self) void {
        if (state.is_setup)
            state.vtable.deinit(state.ptr);
        state.is_setup = false;
    }

    pub fn refresh(state: *Self) anyerror!void {
        return state.vtable.refresh(state.ptr);
    }

    pub fn draw(state: *Self, size: Vec2) anyerror!void {
        return state.vtable.draw(state.ptr, size);
    }

    pub fn update(state: *Self, dt: f32) anyerror!void {
        return state.vtable.update(state.ptr, dt);
    }

    pub fn keypress(state: *Self, key: c_int, mods: c_int, down: bool) anyerror!void {
        return state.vtable.keypress(state.ptr, key, mods, down);
    }

    pub fn keychar(state: *Self, codepoint: u32, mods: c_int) anyerror!void {
        return state.vtable.keychar(state.ptr, codepoint, mods);
    }

    pub fn mousepress(state: *Self, btn: c_int) anyerror!void {
        return state.vtable.mousepress(state.ptr, btn);
    }

    pub fn mouserelease(state: *Self) anyerror!void {
        return state.vtable.mouserelease(state.ptr);
    }

    pub fn mousemove(state: *Self, pos: Vec2) anyerror!void {
        return state.vtable.mousemove(state.ptr, pos);
    }

    pub fn mousescroll(state: *Self, dir: Vec2) anyerror!void {
        return state.vtable.mousescroll(state.ptr, dir);
    }

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const child_t = ptr_info.pointer.child;

        const gen = struct {
            fn setupImpl(pointer: *anyopaque) anyerror!void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.always_inline, ptr_info.pointer.child.setup, .{self});
            }

            fn deinitImpl(pointer: *anyopaque) void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                return @call(.always_inline, ptr_info.pointer.child.deinit, .{self});
            }

            fn refreshImpl(pointer: *anyopaque) anyerror!void {
                if (std.meta.hasMethod(child_t, "refresh")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.refresh, .{self});
                }
            }

            fn drawImpl(pointer: *anyopaque, size: Vec2) anyerror!void {
                if (std.meta.hasMethod(child_t, "draw")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.draw, .{ self, size });
                }
            }

            fn updateImpl(pointer: *anyopaque, dt: f32) anyerror!void {
                if (std.meta.hasMethod(child_t, "update")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.update, .{ self, dt });
                }
            }

            fn keypressImpl(pointer: *anyopaque, key: c_int, mods: c_int, down: bool) anyerror!void {
                if (std.meta.hasMethod(child_t, "keypress")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.keypress, .{ self, key, mods, down });
                }
            }

            fn keycharImpl(pointer: *anyopaque, codepoint: u32, mods: c_int) anyerror!void {
                if (std.meta.hasMethod(child_t, "keychar")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.keychar, .{ self, codepoint, mods });
                }
            }

            fn mousepressImpl(pointer: *anyopaque, btn: c_int) anyerror!void {
                if (std.meta.hasMethod(child_t, "mousepress")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.mousepress, .{ self, btn });
                }
            }

            fn mousereleaseImpl(pointer: *anyopaque) anyerror!void {
                if (std.meta.hasMethod(child_t, "mouserelease")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.mouserelease, .{self});
                }
            }

            fn mousemoveImpl(pointer: *anyopaque, size: Vec2) anyerror!void {
                if (std.meta.hasMethod(child_t, "mousemove")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.mousemove, .{ self, size });
                }
            }

            fn mousescrollImpl(pointer: *anyopaque, dir: Vec2) anyerror!void {
                if (std.meta.hasMethod(child_t, "mousescroll")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    return @call(.always_inline, ptr_info.pointer.child.mousescroll, .{ self, dir });
                }
            }

            const vtable = Vtable{
                .setup = setupImpl,
                .deinit = deinitImpl,
                .refresh = refreshImpl,
                .draw = drawImpl,
                .update = updateImpl,
                .keypress = keypressImpl,
                .keychar = keycharImpl,
                .mousepress = mousepressImpl,
                .mouserelease = mousereleaseImpl,
                .mousemove = mousemoveImpl,
                .mousescroll = mousescrollImpl,
            };
        };

        return .{
            .ptr = ptr,
            .vtable = &gen.vtable,
            .is_setup = false,
        };
    }
};
