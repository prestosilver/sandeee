const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");

pub const SettingManager = struct {
    settings: std.StringHashMap([]u8),

    pub fn init(self: *SettingManager) void {
        self.*.settings = std.StringHashMap([]u8).init(allocator.alloc);
    }

    pub fn set(self: *SettingManager, setting: []const u8, value: []const u8) !void {
        if (self.settings.getEntry(setting)) |val| {
            allocator.alloc.free(val.key_ptr.*);
            allocator.alloc.free(val.value_ptr.*);
        }

        try self.*.settings.put(try allocator.alloc.dupe(u8, setting), try allocator.alloc.dupe(u8, value));

        events.EventManager.instance.sendEvent(systemEvs.EventSetSetting{
            .setting = setting,
            .value = value,
        });
    }

    pub inline fn get(self: *SettingManager, setting: []const u8) ?[]const u8 {
        return self.*.settings.get(setting);
    }

    pub inline fn getBool(self: *SettingManager, setting: []const u8) bool {
        if (self.get(setting)) |val|
            return std.ascii.eqlIgnoreCase(val, "yes")
        else
            return false;
    }

    pub fn save(self: *SettingManager) !void {
        var iter = self.settings.keyIterator();
        var out = std.ArrayList(u8).init(allocator.alloc);
        defer out.deinit();

        while (iter.next()) |entry| {
            try out.appendSlice(entry.*);
            try out.appendSlice(" = \"");
            try out.appendSlice(self.settings.get(entry.*) orelse "");
            try out.appendSlice("\"\n");
        }

        try files.root.writeFile("/conf/system.cfg", out.items, null);
    }

    pub fn deinit(self: *SettingManager) !void {
        try self.save();

        var iter = self.settings.iterator();

        while (iter.next()) |*entry| {
            allocator.alloc.free(entry.value_ptr.*);
            allocator.alloc.free(entry.key_ptr.*);
        }

        self.*.settings.deinit();
    }
};
