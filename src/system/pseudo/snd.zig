const std = @import("std");
const c = @import("../../c.zig");

const system = @import("../mod.zig");

const drawers = @import("../../drawers/mod.zig");
const windows = @import("../../windows/mod.zig");
const events = @import("../../events/mod.zig");
const states = @import("../../states/mod.zig");
const math = @import("../../math/mod.zig");
const util = @import("../../util/mod.zig");

const Vm = system.Vm;
const files = system.files;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Color = math.Color;

const VmWindow = windows.Vm;

const EventManager = events.EventManager;
const window_events = events.windows;

const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const allocator = util.allocator;
const audio = util.audio;
const log = util.log;

pub const play = struct {
    pub fn write(data: []const u8, _: ?*Vm) !void {
        if (data.len == 0) return;

        const snd = audio.Sound.init(data);
        defer snd.deinit();

        try audio.instance.playSound(snd);
    }
};
