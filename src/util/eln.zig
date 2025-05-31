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
const file_utils = @import("../util/files.zig");

const log = @import("log.zig").log;

pub const ElnData = struct {
    name: []const u8,
    icon: ?tex.Texture = null,
    launches: []const u8,

    var textures: std.StringHashMap(tex.Texture) = .init(allocator.alloc);

    pub fn reset() void {
        var iter = textures.iterator();

        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }

        textures.clearAndFree();
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
                .buttons = popups.all.confirm.PopupConfirm.initButtonsFromStruct(errorData),
            };

            try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                .global = true,
                .popup = .atlas("win", .{
                    .title = "Error",
                    .source = .{ .w = 1, .h = 1 },
                    .pos = rect.Rectangle.initCentered(.{
                        .w = gfx.Context.instance.size.x,
                        .h = gfx.Context.instance.size.y,
                    }, 350, 125),
                    .contents = popups.PopupData.PopupContents.init(adds),
                }),
            });
        };
    }

    pub fn parse(file: *files.File) !ElnData {
        const parts = file_utils.splitPath(file.name);

        if (parts.file == null)
            return error.NotAFile;

        var result = ElnData{
            .name = parts.file.?,
            .launches = parts.file.?,
            .icon = null,
        };

        if (parts.ext) |ext| {
            if (std.mem.eql(u8, ext, "eln")) {
                const conts = try file.read(null);
                var split = std.mem.splitScalar(u8, conts, '\n');
                while (split.next()) |entry| {
                    const colon_idx = std.mem.indexOf(u8, entry, ":") orelse continue;
                    const prop = std.mem.trim(u8, entry[0..colon_idx], " ");
                    const value = std.mem.trim(u8, entry[colon_idx + 1 ..], " ");
                    if (std.mem.eql(u8, prop, "name")) {
                        result.name = value;
                    } else if (std.mem.eql(u8, prop, "icon")) {
                        if (textures.get(value)) |texture| {
                            result.icon = texture;
                        } else load_tex: {
                            var texture = tex.Texture.init();

                            texture.loadFile(value) catch |err| {
                                log.err("Failed to load image {s}: {}", .{ value, err });
                                texture.deinit();
                                break :load_tex;
                            };

                            texture.upload() catch |err| {
                                log.err("Failed to upload image {s}: {}", .{ value, err });
                                texture.deinit();
                                break :load_tex;
                            };

                            try textures.put(value, texture);

                            result.icon = texture;
                        }
                    } else if (std.mem.eql(u8, prop, "runs")) {
                        result.launches = value;
                    }
                }
            } else if (std.mem.eql(u8, ext, "eia")) {
                if (textures.get(file.name)) |texture| {
                    result.icon = texture;
                } else load_tex: {
                    var texture = tex.Texture.init();

                    texture.loadFile(file.name) catch |err| {
                        log.err("Failed to load image {s}: {}", .{ file.name, err });
                        texture.deinit();
                        break :load_tex;
                    };

                    texture.upload() catch |err| {
                        log.err("Failed to upload image {s}: {}", .{ file.name, err });
                        texture.deinit();
                        break :load_tex;
                    };

                    try textures.put(file.name, texture);
                }
            }
        }

        return result;
    }
};
