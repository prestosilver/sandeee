pub const State = enum {
    Disks,
    Loading,
    Installer,
    Windowed,

    Crash,
};

pub const EventStateChange = struct {
    targetState: State,
};
