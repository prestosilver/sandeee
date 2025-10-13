const std = @import("std");
const c = @import("../c.zig");

const system = @import("../system/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");

const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const config = system.config;

const Self = @This();

const FontType = enum {
    path,
    mem,
};

data: union(FontType) {
    path: []const u8,
    mem: []const u8,
},
output: *Font,

pub fn load(self: *const Self) anyerror!void {
    switch (self.data) {
        .path => |p| {
            const path = config.SettingManager.instance.get(p) orelse p;

            log.debug("load font: {s}", .{path});

            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            self.output.* = try .init(path);
        },
        .mem => |m| {
            log.debug("load font in mem", .{});

            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            self.output.* = try .initMem(m);
        },
    }
}

pub fn unload(self: *const Self) void {
    // deinit font
    self.output.deinit();
}
