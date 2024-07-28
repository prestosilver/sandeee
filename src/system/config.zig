const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("../system/files.zig");
const events = @import("../util/events.zig");
const system_events = @import("../events/system.zig");

pub const SettingManager = struct {
    pub var instance: SettingManager = undefined;

    settings: std.StringHashMap([]u8),

    pub fn init() void {
        instance.settings = std.StringHashMap([]u8).init(allocator.alloc);
    }

    pub fn set(self: *SettingManager, setting: []const u8, value: []const u8) !void {
        if (self.settings.fetchRemove(setting)) |val| {
            allocator.alloc.free(val.key);
            allocator.alloc.free(val.value);
        }

        try self.*.settings.put(try allocator.alloc.dupe(u8, setting), try allocator.alloc.dupe(u8, value));

        try events.EventManager.instance.sendEvent(system_events.EventSetSetting{
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

    pub inline fn setBool(self: *SettingManager, setting: []const u8, value: bool) !void {
        return self.set(setting, if (value) "yes" else "no");
    }

    pub inline fn getInt(self: *SettingManager, setting: []const u8) i64 {
        if (self.get(setting)) |val|
            return std.fmt.parseInt(i64, val, 0) catch 0
        else
            return 0;
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

    pub fn deinit() !void {
        try instance.save();

        var iter = instance.settings.iterator();

        while (iter.next()) |*entry| {
            allocator.alloc.free(entry.value_ptr.*);
            allocator.alloc.free(entry.key_ptr.*);
        }

        instance.settings.deinit();
    }
};
