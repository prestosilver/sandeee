const std = @import("std");
const c = @import("../c.zig");

const system = @import("../system.zig");

const events = @import("../events.zig");
const util = @import("../util.zig");

const allocator = util.allocator;
const log = util.log;

const files = system.files;

const EventManager = events.EventManager;
const system_events = events.system;

pub const SettingManager = struct {
    pub var instance: SettingManager = .{};

    settings: std.StringHashMap([]u8) = std.StringHashMap([]u8).init(allocator),

    pub fn set(self: *SettingManager, setting: []const u8, value: []const u8) !void {
        if (self.settings.fetchRemove(setting)) |val| {
            allocator.free(val.key);
            allocator.free(val.value);
        }

        try self.*.settings.put(try allocator.dupe(u8, setting), try allocator.dupe(u8, value));

        try events.EventManager.instance.sendEvent(system_events.EventSetSetting{
            .setting = setting,
            .value = value,
        });
    }

    pub inline fn get(self: *SettingManager, setting: []const u8) ?[]const u8 {
        return self.*.settings.get(setting);
    }

    pub inline fn setBool(self: *SettingManager, setting: []const u8, value: bool) !void {
        return self.set(setting, if (value) "yes" else "no");
    }

    pub inline fn getBool(self: *SettingManager, setting: []const u8) ?bool {
        if (self.get(setting)) |val|
            return std.ascii.eqlIgnoreCase(val, "yes")
        else
            return null;
    }

    pub inline fn getFloat(self: *SettingManager, setting: []const u8) ?f32 {
        if (self.get(setting)) |val|
            return std.fmt.parseFloat(f32, val) catch null
        else
            return null;
    }

    pub inline fn getInt(self: *SettingManager, setting: []const u8) ?i64 {
        if (self.get(setting)) |val|
            return std.fmt.parseInt(i64, val, 0) catch null
        else
            return null;
    }

    pub fn save(self: *SettingManager) !void {
        var iter = self.settings.keyIterator();
        var out: std.array_list.Managed(u8) = .init(allocator);
        defer out.deinit();

        while (iter.next()) |entry| {
            try out.appendSlice(entry.*);
            try out.appendSlice(" = \"");
            try out.appendSlice(self.settings.get(entry.*) orelse "");
            try out.appendSlice("\"\n");
        }

        const root = try files.FolderLink.resolve(.root);
        try root.writeFile("/conf/system.cfg", out.items, null);
    }

    pub fn deinit() void {
        instance.save() catch {
            log.err("failed to save settings", .{});
        };

        var iter = instance.settings.iterator();

        while (iter.next()) |*entry| {
            allocator.free(entry.value_ptr.*);
            allocator.free(entry.key_ptr.*);
        }

        instance.settings.deinit();
    }
};
