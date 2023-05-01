const std = @import("std");
const rect = @import("../math/rects.zig");
const ev = @import("../util/events.zig");
const win = @import("../drawers/window2d.zig");
const popups = @import("../drawers/popup2d.zig");
const spr = @import("../drawers/sprite2d.zig");

pub const EventCreateWindow = struct { window: win.Window, center: bool = false };
pub const EventCreatePopup = struct { popup: popups.Popup };
pub const EventClosePopup = struct {};
pub const EventNotification = struct { title: []const u8, text: []const u8 = "", icon: ?spr.Sprite = null };
