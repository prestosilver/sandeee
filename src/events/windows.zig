const std = @import("std");

const events = @import("../events.zig");
const drawers = @import("../drawers.zig");
const math = @import("../math.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;

const EventManager = events.EventManager;

pub const EventCreateWindow = struct { window: Window, center: bool = false };
pub const EventCreatePopup = struct { popup: Popup, global: bool = false };
pub const EventClosePopup = struct { popup_conts: *const anyopaque };
pub const EventNotification = struct { title: []const u8, text: []const u8 = "", icon: ?Sprite = null };
