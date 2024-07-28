const std = @import("std");
const options = @import("options");
const files = @import("files.zig");
const allocator = @import("../util/allocator.zig");
const win = @import("../drawers/window2d.zig");
const wins = @import("../windows/all.zig");
const events = @import("../util/events.zig");
const window_events = @import("../events/window.zig");
const rect = @import("../math/rects.zig");

const log = @import("../util/log.zig").log;

pub const Telem = packed struct {
    pub const PATH = "/_priv/telem.bin";

    pub var instance: Telem = .{
        .random_id = 0,
    };

    logins: u64 = 0,
    instruction_calls: u128 = 0,
    random_id: u64,

    version: packed struct {
        major: u16,
        minor: u8,
        patch: u8,
    } = .{
        .major = options.SandEEEVersion.major,
        .minor = options.SandEEEVersion.minor,
        .patch = options.SandEEEVersion.patch,
    },

    pub fn checkVersion() void {
        if (instance.version.major != options.SandEEEVersion.major or
            instance.version.minor != options.SandEEEVersion.minor or
            instance.version.patch != options.SandEEEVersion.patch)
        {
            const update_window = win.Window.new("win", win.WindowData{
                .source = rect.Rectangle{
                    .x = 0.0,
                    .y = 0.0,
                    .w = 1.0,
                    .h = 1.0,
                },
                .pos = .{
                    .x = 0,
                    .y = 0,
                    .w = 600,
                    .h = 350,
                },
                .contents = wins.update.new() catch return,
                .active = true,
            });

            events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = update_window, .center = true }) catch return;
        }
    }

    pub fn load() !void {
        defer checkVersion();

        if (files.root.getFile(PATH) catch null) |file| {
            const conts = try file.read(null);

            if (conts.len != @sizeOf(Telem)) return;

            instance = std.mem.bytesToValue(Telem, conts[0..@sizeOf(Telem)]);
        } else {
            var rnd = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
            instance = .{
                .random_id = rnd.random().int(u64),
            };

            const pass = try getDebugPassword();
            defer allocator.alloc.free(pass);
            log.debug("Set telem pass: {s}", .{pass});
        }
    }

    pub fn save() !void {
        const conts = std.mem.asBytes(&instance);

        _ = try files.root.newFile(PATH);
        try files.root.writeFile(PATH, conts, null);
    }

    pub fn getDebugPassword() ![]u8 {
        const a: u32 = @intCast(instance.random_id >> 0 & std.math.maxInt(u32));
        const b: u32 = @intCast(instance.random_id >> 32 & std.math.maxInt(u32));

        const a_bytes = std.mem.asBytes(&a);
        const b_bytes = std.mem.asBytes(&b);

        const enc = std.base64.standard_no_pad.Encoder;

        var ap: [enc.calcSize(4)]u8 = undefined;
        var bp: [enc.calcSize(4)]u8 = undefined;

        const aenc = enc.encode(&ap, a_bytes);
        const benc = enc.encode(&bp, b_bytes);

        return try std.mem.concat(allocator.alloc, u8, &.{ aenc, "-", benc });
    }
};
