const std = @import("std");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");
const gfx = @import("../util/graphics.zig");
const allocator = @import("../util/allocator.zig");
const conf = @import("../system/config.zig");

const log = @import("../util/log.zig").log;

const Self = @This();

const FontType = enum {
    path,
    mem,
};

data: union(FontType) {
    path: []const u8,
    mem: []const u8,
},
output: *font.Font,

pub fn load(self: *const Self) anyerror!void {
    switch (self.data) {
        .path => |p| {
            const path = conf.SettingManager.instance.get(p) orelse p;

            log.debug("load font: {s}", .{path});

            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            self.output.* = try font.Font.init(path);
        },
        .mem => |m| {
            log.debug("load font in mem", .{});

            gfx.Context.makeCurrent();
            defer gfx.Context.makeNotCurrent();

            self.output.* = try font.Font.initMem(m);
        },
    }
}

pub fn unload(self: *const Self) void {
    // deinit font
    self.output.deinit();
}
