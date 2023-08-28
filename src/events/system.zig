pub const State = enum {
    Disks,
    Loading,
    Installer,
    Recovery,
    Windowed,
    Logout,

    Crash,
};

pub const EventStateChange = struct { targetState: State };
pub const EventEmailRecv = struct {};
pub const EventRunCmd = struct { cmd: []const u8 };
pub const EventSetSetting = struct { setting: []const u8, value: []const u8 };
pub const EventTelemUpdate = struct {};
pub const EventDebugSet = struct { enabled: bool };

pub const EventCopy = struct { value: []const u8 };
pub const EventPaste = struct {};
pub const EventSys = struct { sysId: u64 };
