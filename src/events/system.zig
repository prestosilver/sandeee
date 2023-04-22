pub const State = enum {
    Disks,
    Loading,
    Installer,
    Recovery,
    Windowed,

    Crash,
};

pub const EventStateChange = struct {
    targetState: State,
};
