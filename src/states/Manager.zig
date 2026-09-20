const std = @import("std");

const math = @import("../math.zig");
const util = @import("../util.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const loaders = @import("../loaders.zig");

const ClickKind = events.input.ClickKind;

const Vec2 = math.Vec2;

pub const GameState = struct {
    const Self = @This();

    pub const StateDrawError = util.Url.Error || std.mem.Allocator.Error || system.files.FileError || std.http.Client.RequestError || error{
        ThreadQuotaExceeded,
        LockedMemoryLimitExceeded,

        // TODO: find where these come from
        InvalidHostName,
        WrongSize,
        UnexpectedCharacter,
        InvalidFormat,
        InvalidPort,
        UnsupportedCompressionMethod,
    };
    pub const StateUpdateError = loaders.Loader.LoaderError || std.mem.Allocator.Error || system.files.FileError || system.files.DiskError || std.Io.File.OpenError;
    pub const StateSetupError = std.mem.Allocator.Error || system.files.FileError || system.files.DiskError || error{
        ThreadQuotaExceeded,
        LockedMemoryLimitExceeded,
    } || std.Io.File.OpenError;

    pub const Vtable = struct {
        setup: *const fn (*anyopaque) StateSetupError!void,
        deinit: *const fn (*anyopaque) void,
        draw: *const fn (*anyopaque, Vec2) StateDrawError!void,
        refresh: *const fn (*anyopaque) StateUpdateError!void,
        update: *const fn (*anyopaque, f32) StateUpdateError!void,
        keypress: *const fn (*anyopaque, c_int, c_int, bool) (events.input.EventKeyDown.Error || events.input.EventKeyUp.Error)!void,
        keychar: *const fn (*anyopaque, []const u8, i32) events.input.EventKeyChar.Error!void,
        mousepress: *const fn (*anyopaque, c_int, ClickKind) events.input.EventMouseClick.Error!void,
        mousemove: *const fn (*anyopaque, Vec2) events.input.EventMouseMove.Error!void,
        mousescroll: *const fn (*anyopaque, Vec2) events.input.EventMouseScroll.Error!void,
    };

    ptr: *anyopaque,
    vtable: *const Vtable,
    is_setup: bool,

    pub fn setup(state: *Self) StateSetupError!void {
        if (!state.is_setup)
            try state.vtable.setup(state.ptr);
        state.is_setup = true;
    }

    pub fn deinit(state: *Self) void {
        if (state.is_setup)
            state.vtable.deinit(state.ptr);
        state.is_setup = false;
    }

    pub fn refresh(state: *Self) StateUpdateError!void {
        return state.vtable.refresh(state.ptr);
    }

    pub fn draw(state: *Self, size: Vec2) StateDrawError!void {
        return state.vtable.draw(state.ptr, size);
    }

    pub fn update(state: *Self, dt: f32) StateUpdateError!void {
        return state.vtable.update(state.ptr, dt);
    }

    pub fn keypress(state: *Self, key: c_int, mods: c_int, down: bool) !void {
        return state.vtable.keypress(state.ptr, key, mods, down);
    }

    pub fn keychar(state: *Self, char_string: []const u8, mods: c_int) !void {
        return state.vtable.keychar(state.ptr, char_string, mods);
    }

    pub fn mousepress(state: *Self, btn: c_int, kind: ClickKind) !void {
        return state.vtable.mousepress(state.ptr, btn, kind);
    }

    pub fn mousemove(state: *Self, pos: Vec2) !void {
        return state.vtable.mousemove(state.ptr, pos);
    }

    pub fn mousescroll(state: *Self, dir: Vec2) !void {
        return state.vtable.mousescroll(state.ptr, dir);
    }

    pub fn init(ptr: anytype) Self {
        const Ptr = @TypeOf(ptr);
        const ptr_info = @typeInfo(Ptr);

        if (ptr_info != .pointer) @compileError("ptr must be a pointer");
        if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

        const child_t = ptr_info.pointer.child;

        const gen = struct {
            fn setupImpl(pointer: *anyopaque) StateSetupError!void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                try @call(.always_inline, ptr_info.pointer.child.setup, .{self});
            }

            fn deinitImpl(pointer: *anyopaque) void {
                const self: Ptr = @ptrCast(@alignCast(pointer));

                @call(.always_inline, ptr_info.pointer.child.deinit, .{self});
            }

            fn refreshImpl(pointer: *anyopaque) StateUpdateError!void {
                if (std.meta.hasMethod(child_t, "refresh")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.refresh, .{self});
                }
            }

            fn drawImpl(pointer: *anyopaque, size: Vec2) StateDrawError!void {
                if (std.meta.hasMethod(child_t, "draw")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.draw, .{ self, size });
                }
            }

            fn updateImpl(pointer: *anyopaque, dt: f32) StateUpdateError!void {
                if (std.meta.hasMethod(child_t, "update")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.update, .{ self, dt });
                }
            }

            fn keypressImpl(pointer: *anyopaque, key: c_int, mods: c_int, down: bool) !void {
                if (std.meta.hasMethod(child_t, "keypress")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.keypress, .{ self, key, mods, down });
                }
            }

            fn keycharImpl(pointer: *anyopaque, codepoint: []const u8, mods: c_int) !void {
                if (std.meta.hasMethod(child_t, "keychar")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.keychar, .{ self, codepoint, mods });
                }
            }

            fn mousepressImpl(pointer: *anyopaque, btn: c_int, kind: ClickKind) !void {
                if (std.meta.hasMethod(child_t, "mousepress")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.mousepress, .{ self, btn, kind });
                }
            }

            fn mousemoveImpl(pointer: *anyopaque, size: Vec2) !void {
                if (std.meta.hasMethod(child_t, "mousemove")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.mousemove, .{ self, size });
                }
            }

            fn mousescrollImpl(pointer: *anyopaque, dir: Vec2) !void {
                if (std.meta.hasMethod(child_t, "mousescroll")) {
                    const self: Ptr = @ptrCast(@alignCast(pointer));

                    try @call(.always_inline, ptr_info.pointer.child.mousescroll, .{ self, dir });
                }
            }
        };

        return .{
            .ptr = ptr,
            .vtable = &.{
                .setup = gen.setupImpl,
                .deinit = gen.deinitImpl,
                .refresh = gen.refreshImpl,
                .draw = gen.drawImpl,
                .update = gen.updateImpl,
                .keypress = gen.keypressImpl,
                .keychar = gen.keycharImpl,
                .mousepress = gen.mousepressImpl,
                .mousemove = gen.mousemoveImpl,
                .mousescroll = gen.mousescrollImpl,
            },
            .is_setup = false,
        };
    }
};
