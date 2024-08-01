const std = @import("std");
const allocator = @import("allocator.zig");
const texture_manager = @import("texmanager.zig");
const tex = @import("texture.zig");
const files = @import("../system/files.zig");
const shell = @import("../system/shell.zig");
const popups = @import("../drawers/popup2d.zig");
const shader = @import("../util/shader.zig");
const events = @import("../util/events.zig");
const window_events = @import("../events/window.zig");
const rect = @import("../math/rects.zig");
const gfx = @import("../util/graphics.zig");

const log = @import("log.zig").log;

pub const ElnData = struct {
    name: []const u8,
    icon: ?u8 = null,
    launches: []const u8,

    var texture: u8 = 0;
    var textures: std.StringHashMap(u8) = std.StringHashMap(u8).init(allocator.alloc);

    pub fn reset() void {
        textures.deinit();

        textures = std.StringHashMap(u8).init(allocator.alloc);
        texture = 0;
    }

    pub const errorData = struct {
        pub fn ok(_: *align(@alignOf(ElnData)) const anyopaque) anyerror!void {}
    };

    pub fn run(self: *const ElnData, shell_instance: *shell.Shell, shd: *shader.Shader) !void {
        shell_instance.runBg(self.launches) catch |err| {
            const message = try std.fmt.allocPrint(allocator.alloc, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

            const adds = try allocator.alloc.create(popups.all.confirm.PopupConfirm);
            adds.* = .{
                .data = self,
                .message = message,
                .shader = shd,
                .buttons = popups.all.confirm.PopupConfirm.createButtonsFromStruct(errorData),
            };

            try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                .global = true,
                .popup = .{
                    .texture = "win",
                    .data = .{
                        .title = "Error",
                        .source = .{ .w = 1, .h = 1 },
                        .pos = rect.Rectangle.initCentered(.{
                            .w = gfx.Context.instance.size.x,
                            .h = gfx.Context.instance.size.y,
                        }, 350, 125),
                        .contents = popups.PopupData.PopupContents.init(adds),
                    },
                },
            });
        };
    }

    pub fn parse(file: *files.File) !ElnData {
        const ext_idx = std.mem.lastIndexOf(u8, file.name, ".") orelse file.name.len;
        const folder_idx = std.mem.lastIndexOf(u8, file.name, "/") orelse file.name.len;

        var result = ElnData{
            .name = file.name[folder_idx..],
            .icon = null,
            .launches = file.name[folder_idx..ext_idx],
        };

        const conts = try file.read(null);
        var split = std.mem.split(u8, conts, "\n");
        while (split.next()) |entry| {
            const colon_idx = std.mem.indexOf(u8, entry, ":") orelse continue;
            const prop = std.mem.trim(u8, entry[0..colon_idx], " ");
            const value = std.mem.trim(u8, entry[colon_idx + 1 ..], " ");
            if (std.mem.eql(u8, prop, "name")) {
                result.name = value;
            } else if (std.mem.eql(u8, prop, "icon")) {
                if (textures.get(value)) |idx| {
                    result.icon = idx;
                } else {
                    const name = .{ 'e', 'l', 'n', texture };
                    if (tex.newTextureFile(value) catch null) |tmp_tex| {
                        try texture_manager.TextureManager.instance.put(&name, tmp_tex);
                    } else {
                        log.err("Failed to load image {s}", .{value});
                    }
                    try textures.put(value, texture);
                    result.icon = texture;

                    texture += 1;
                }
            } else if (std.mem.eql(u8, prop, "runs")) {
                result.launches = value;
            }
        }

        return result;
    }
};
