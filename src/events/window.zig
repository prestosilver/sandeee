const std = @import("std");
const rect = @import("../math/rects.zig");
const ev = @import("../util/events.zig");
const win = @import("../drawers/window2d.zig");

pub const EventCreateWindow = struct { window: win.Window, center: bool = false };
