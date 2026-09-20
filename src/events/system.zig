const std = @import("std");

const drawers = @import("../drawers.zig");
const system = @import("../system.zig");

const Sprite = drawers.Sprite;

pub const State = enum {
    Disks,
    Loading,
    Installer,
    Recovery,
    Windowed,
    Logout,

    Crash,
};

const SystemEventError = std.mem.Allocator.Error || system.files.FileError;

pub const EventStateChange = struct {
    pub const Error = SystemEventError;

    target_state: State,
};
pub const EventEmailRecv = struct {
    pub const Error = SystemEventError;
};
pub const EventCmdRun = struct {
    pub const Error = SystemEventError;

    cmd: []const u8,
};
pub const EventSettingSet = struct {
    pub const Error = SystemEventError;

    setting: []const u8,
    value: []const u8,
};
pub const EventTelemUpdate = struct {
    pub const Error = SystemEventError;
};
pub const EventDebugSet = struct {
    pub const Error = SystemEventError;

    enabled: bool,
};
pub const EventSyscallRun = struct {
    pub const Error = SystemEventError;

    sysId: u64,
};
pub const EventNotificationSend = struct {
    pub const Error = SystemEventError;

    title: []const u8,
    text: []const u8 = "",
    icon: ?Sprite = null,
};
