const std = @import("std");
const allocator = @import("../../util/allocator.zig");
const files = @import("../files.zig");
const vmwin = @import("../../windows/vm.zig");
const winev = @import("../../events/window.zig");
const events = @import("../../util/events.zig");
const win = @import("../../drawers/window2d.zig");
const tex = @import("../../util/texture.zig");
const rect = @import("../../math/rects.zig");
const shd = @import("../../util/shader.zig");
const audio = @import("../../util/audio.zig");
const vm = @import("../vm.zig");

pub const play = struct {
    pub fn write(data: []const u8, _: ?*vm.VM) !void {
        if (data.len == 0) return;

        const snd = audio.Sound.init(data);
        defer snd.deinit();

        try audio.instance.playSound(snd);
    }
};
