const std = @import("std");
const vecs = @import("../math/vecs.zig");

pub const GameState = struct {
    const Self = @This();

    pub const VTable = struct {
        setup: *const fn (*anyopaque) anyerror!void,
        deinit: *const fn (*anyopaque) anyerror!void,
        draw: *const fn (*anyopaque, vecs.Vector2) anyerror!void,
        update: *const fn (*anyopaque, f32) anyerror!void,
        keypress: *const fn (*anyopaque, c_int, c_int, bool) anyerror!bool,
        keychar: *const fn (*anyopaque, u32, i32) anyerror!void,
        mousepress: *const fn (*anyopaque, c_int) anyerror!void,
        mouserelease: *const fn (*anyopaque) anyerror!void,
        mousemove: *const fn (*anyopaque, vecs.Vector2) anyerror!void,
        mousescroll: *const fn (*anyopaque, vecs.Vector2) anyerror!void,
    };

    ptr: *anyopaque,
    vtable: *const VTable,
    isSetup: bool,

    pub fn setup(state: *Self) anyerror!void {
        if (!state.isSetup)
            try state.vtable.setup(state.ptr);
        state.isSetup = true;
    }

    pub fn deinit(state: *Self) anyerror!void {
        if (state.isSetup)
            try state.vtable.deinit(state.ptr);
        state.isSetup = false;
    }

    pub fn draw(state: *Self, size: vecs.Vector2) anyerror!void {
        return state.vtable.draw(state.ptr, size);
    }

    pub fn update(state: *Self, dt: f32) anyerror!void {
        return state.vtable.update(state.ptr, dt);
    }

    pub fn keypress(state: *Self, key: c_int, mods: c_int, down: bool) anyerror!bool {
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

    pub fn mousemove(state: *Self, pos: vecs.Vector2) anyerror!void {
        return state.vtable.mousemove(state.ptr, pos);
    }

    pub fn mousescroll(state: *Self, dir: vecs.Vector2) anyerror!void {
        return state.vtable.mousescroll(state.ptr, dir);
    }

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
        if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

        const alignment = ptr_info.Pointer.alignment;

        const gen = struct {
            fn setupImpl(pointer: *anyopaque) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.setup, .{self});
            }

            fn deinitImpl(pointer: *anyopaque) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.deinit, .{self});
            }

            fn drawImpl(pointer: *anyopaque, size: vecs.Vector2) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.draw, .{ self, size });
            }

            fn updateImpl(pointer: *anyopaque, dt: f32) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.update, .{ self, dt });
            }

            fn keypressImpl(pointer: *anyopaque, key: c_int, mods: c_int, down: bool) anyerror!bool {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.keypress, .{ self, key, mods, down });
            }

            fn keycharImpl(pointer: *anyopaque, codepoint: u32, mods: c_int) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.keychar, .{ self, codepoint, mods });
            }

            fn mousepressImpl(pointer: *anyopaque, btn: c_int) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.mousepress, .{ self, btn });
            }

            fn mousereleaseImpl(pointer: *anyopaque) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.mouserelease, .{self});
            }

            fn mousemoveImpl(pointer: *anyopaque, size: vecs.Vector2) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.mousemove, .{ self, size });
            }

            fn mousescrollImpl(pointer: *anyopaque, dir: vecs.Vector2) anyerror!void {
                const self = @ptrCast(Ptr, @alignCast(alignment, pointer));

                return @call(.auto, ptr_info.Pointer.child.mousescroll, .{ self, dir });
            }

            const vtable = VTable{
                .setup = setupImpl,
                .deinit = deinitImpl,
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
            .isSetup = false,
        };
    }
};
