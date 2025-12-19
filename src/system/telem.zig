const std = @import("std");
const options = @import("options");
const builtin = @import("builtin");
const c = @import("../c.zig");

const system = @import("mod.zig");

const windows = @import("../windows/mod.zig");
const drawers = @import("../drawers/mod.zig");
const events = @import("../events/mod.zig");
const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const EventManager = events.EventManager;
const window_events = events.windows;

const Rect = math.Rect;

const files = system.files;

const allocator = util.allocator;
const log = util.log;

const Window = drawers.Window;

pub const Telem = packed struct {
    // TODO: move to data module
    pub const PATH = "/_priv/telem.bin";

    pub var instance: Telem = .{
        .random_id = 0,
    };

    logins: u64 = 0,
    instruction_calls: u128 = 0,
    random_id: u64,

    version: packed struct {
        major: u2,
        index: u30,
    } = .{
        .major = @intFromEnum(options.SandEEEVersion.phase),
        .index = options.SandEEEVersion.index,
    },

    pub fn checkVersion() void {
        if (builtin.is_test) return;

        if (instance.version.major != @intFromEnum(options.SandEEEVersion.phase) or
            instance.version.index != options.SandEEEVersion.index)
        {
            const update_window: Window = .atlas("win", .{
                .source = .{ .w = 1, .h = 1 },
                .pos = .{ .w = 600, .h = 350 },
                .contents = windows.update.init() catch return,
                .active = true,
            });

            events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = update_window, .center = true }) catch return;
        }
    }

    pub fn load() !void {
        defer checkVersion();

        const root = try files.FolderLink.resolve(.root);

        if (root.getFile(PATH) catch null) |file| {
            const conts = try file.read(null);

            if (conts.len != @sizeOf(Telem)) return;

            instance = std.mem.bytesToValue(Telem, conts[0..@sizeOf(Telem)]);
        } else {
            var rnd = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
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

        const root = try files.FolderLink.resolve(.root);

        _ = try root.newFile(PATH);
        try root.writeFile(PATH, conts, null);
    }

    pub fn getDebugPassword() ![]u8 {
        const a: u32 = @intCast(instance.random_id >> 0 & std.math.maxInt(u32));
        const b: u32 = @intCast(instance.random_id >> 32 & std.math.maxInt(u32));

        const a_bytes = std.mem.asBytes(&a);
        const b_bytes = std.mem.asBytes(&b);

        const enc = std.base64.standard_no_pad.Encoder;

        var ap = std.mem.zeroes([enc.calcSize(4)]u8);
        var bp = std.mem.zeroes([enc.calcSize(4)]u8);

        const aenc = enc.encode(&ap, a_bytes);
        const benc = enc.encode(&bp, b_bytes);

        return try std.mem.concat(allocator.alloc, u8, &.{ aenc, "-", benc });
    }
};
