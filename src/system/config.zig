const std = @import("std");
const allocator = @import("../util/allocator.zig");

pub const SettingManager = struct {
    settings: std.StringHashMap([]const u8),

    pub fn init(self: *SettingManager) void {
        self.*.settings = std.StringHashMap([]const u8).init(allocator.alloc);
    }

    pub fn set(self: *SettingManager, setting: []const u8, value: []const u8) !void {
        try self.*.settings.put(setting, value);
    }

    pub fn get(self: *SettingManager, setting: []const u8) ?[]const u8 {
        return self.*.settings.get(setting);
    }

    pub fn deinit(self: *SettingManager) void {
        self.*.settings.deinit();
    }
};
