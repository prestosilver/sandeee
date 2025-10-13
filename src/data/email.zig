const EmailLogin = struct {
    user: []const u8,
    password: []const u8,
};

pub const LOGINS = [_]EmailLogin{
    .{
        .user = "rob_r@eee.org",
        .password = "12345",
    },
    .{
        .user = "joe_m@eee.org",
        .password = "ILoveEEE",
    },
    .{
        .user = "ERIC_L@eee.org",
        .password = "EEEON2010",
    },
};
