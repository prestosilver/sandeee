const std = @import("std");
const c = @import("../c.zig");

const util = @import("../util.zig");

const windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const events = @import("../events.zig");
const system = @import("../system.zig");
const math = @import("../math.zig");

const Popup = drawers.Popup;

const popups = windows.popups;

const Rect = math.Rect;

const TextureManager = util.TextureManager;
const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;
const graphics = util.graphics;
const storage = util.storage;
const log = util.log;

const files = system.files;
const Shell = system.Shell;

const EventManager = events.EventManager;
const window_events = events.windows;

const Eln = @This();

name: []const u8,
icon: ?Texture = null,
launches: []const u8,

var textures: std.StringHashMap(Texture) = .init(allocator);

pub fn reset() void {
    var iter = textures.iterator();

    while (iter.next()) |entry| {
        entry.value_ptr.deinit();
    }

    textures.clearAndFree();
}

pub const errorData = struct {
    pub fn ok(_: *align(@alignOf(Eln)) const anyopaque) anyerror!void {}
};

pub fn run(self: *const Eln, shell_instance: *Shell, shd: *Shader) !void {
    shell_instance.runBg(self.launches) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "Couldnt not launch the VM.\n    {s}", .{@errorName(err)});

        const adds = try allocator.create(popups.confirm.PopupConfirm);
        adds.* = .{
            .data = self,
            .message = message,
            .shader = shd,
            .buttons = popups.confirm.PopupConfirm.initButtonsFromStruct(errorData),
        };

        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
            .global = true,
            .popup = .atlas("win", .{
                .title = "Error",
                .source = .{ .w = 1, .h = 1 },
                .pos = Rect.initCentered(.{
                    .w = graphics.Context.instance.size.x,
                    .h = graphics.Context.instance.size.y,
                }, 350, 125),
                .contents = .init(adds),
            }),
        });
    };
}

pub fn parse(file: *files.File) !Eln {
    const parts = storage.splitPath(file.name);

    if (parts.file == null)
        return error.NotAFile;

    var result = Eln{
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
                        var texture = Texture.init();

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
                var texture = Texture.init();

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
