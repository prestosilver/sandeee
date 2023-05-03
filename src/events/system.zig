pub const State = enum {
    Disks,
    Loading,
    Installer,
    Recovery,
    Windowed,

    Crash,
};

pub const EventStateChange = struct { targetState: State };
pub const EventEmailRecv = struct {};
pub const EventRunCmd = struct { cmd: []const u8 };
pub const EventSetSetting = struct { setting: []const u8, value: []const u8 };
