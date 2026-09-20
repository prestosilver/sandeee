const std = @import("std");

const system = @import("../system.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");

const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const config = system.config;

const Self = @This();

data: union(enum) {
    path: []const u8,
    mem: []const u8,
},
output: *Font,

pub fn load(self: *const Self) !void {
    switch (self.data) {
        .path => |p| {
            const path = config.SettingManager.instance.get(p) orelse p;

            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            self.output.* = try .init(path);

            log.debug("Loaded font {s}", .{p});
        },
        .mem => |m| {
            graphics.Context.makeCurrent();
            defer graphics.Context.makeNotCurrent();

            self.output.* = try .initMem(m);

            log.debug("Loaded font from memory", .{});
        },
    }
}

pub fn unload(self: *const Self) void {
    // deinit font
    self.output.deinit();

    switch (self.data) {
        .path => |p| log.debug("Unloaded font {s}", .{p}),
        .mem => log.debug("Unloaded font from memory", .{}),
    }
}
