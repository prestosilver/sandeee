const std = @import("std");

const system = @import("../system.zig");
const events = @import("../events.zig");
const drawers = @import("../drawers.zig");
const math = @import("../math.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;

const EventManager = events.EventManager;

const WindowEventError = std.mem.Allocator.Error || std.Io.Writer.Error || std.Io.File.Writer.Error || std.Io.File.Reader.Error || system.files.FileError;

pub const EventWindowCreate = struct {
    pub const Error = WindowEventError;

    window: Window,
    center: bool = false,
};
pub const EventWindowClose = struct {
    pub const Error = WindowEventError;

    window: Window,
};
pub const EventPopupCreate = struct {
    pub const Error = WindowEventError;

    popup: Popup,
    global: bool = false,
};
pub const EventPopupClose = struct {
    pub const Error = WindowEventError;

    popup_conts: *const anyopaque,
};
