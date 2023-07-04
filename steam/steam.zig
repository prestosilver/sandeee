const std = @import("std");

const root = @import("root");
const enableApi = @hasDecl(root, "useSteam") and root.useSteam;

pub const STEAM_APP_ID = 0;

const TestUser: SteamUser = .{};
const TestUGC: SteamUGC = .{};
const TestUtils: SteamUtils = .{};
const TestStats: SteamUserStats = .{};

extern fn SteamAPI_ISteamUser_GetSteamID(*const SteamUser) SteamId;
pub const SteamUser = extern struct {
    pub fn getSteamId(self: *const SteamUser) SteamId {
        if (enableApi) {
            return SteamAPI_ISteamUser_GetSteamID(self, 0, 0, "");
        } else {
            std.log.debug("Get Steam Id From User", .{});
            return .{
                .id = 1000,
            };
        }
    }
};

pub const SteamUtils = extern struct {};
pub const SteamUserStats = extern struct {};

pub const UGCQueryHandle = struct {
    data: u64,
};

pub const PublishedFileId = struct {
    id: u64,
};

pub const SteamUGC = extern struct {
    pub fn downloadItem(self: *const SteamUGC, id: PublishedFileId, priority: bool) bool {
        _ = priority;
        _ = id;
        _ = self;
    }
};

extern fn SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(queryKind: u32, kind: u32, creatorId: u32, consumerId: u32, page: u32) UGCQueryHandle;
pub fn createQueryAllUGCRequest(
    queryKind: u32,
    kind: u32,
    creatorId: u32,
    consumerId: u32,
    page: u32,
) UGCQueryHandle {
    if (enableApi) {
        return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(queryKind, kind, creatorId, consumerId, page);
    } else {
        std.log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ queryKind, kind, creatorId, consumerId, page });
        return .{
            .data = 10,
        };
    }
}

pub const SteamId = struct {
    id: u64,
};

extern fn SteamAPI_Init() bool;
pub fn init() bool {
    if (enableApi) {
        return SteamAPI_Init();
    } else {
        std.log.debug("Init Steam", .{});
        return true;
    }
}

extern fn SteamAPI_RestartAppIfNecessary(app_id: u32) bool;
pub fn restartIfNeeded(app_id: u32) bool {
    if (enableApi) {
        return SteamAPI_RestartAppIfNecessary(app_id);
    } else {
        std.log.debug("Restart If Needed: {}", .{app_id});
        return false;
    }
}

extern fn SteamAPI_SteamUGC_v017() ?*const SteamUser;
pub fn getSteamUGC() ?*const SteamUser {
    if (enableApi) {
        return SteamAPI_SteamUGC_v017();
    } else {
        std.log.debug("Get UGC", .{});
        return &TestUGC;
    }
}

extern fn SteamAPI_GetISteamUser() ?*const SteamUser;
pub fn getUser() ?*const SteamUser {
    if (enableApi) {
        return SteamAPI_GetISteamUser();
    } else {
        std.log.debug("Get User", .{});
        return &TestUser;
    }
}

extern fn SteamAPI_SteamUtils_v010() ?*const SteamUtils;
pub fn getSteamUtils() *const SteamUtils {
    if (enableApi) {
        return SteamAPI_SteamUtils_v010();
    } else {
        std.log.debug("Init Steam Utils", .{});
        return &TestUtils;
    }
}

extern fn SteamAPI_SteamUserStats_v012() ?*const SteamUserStats;
pub fn getUserStats() *const SteamUserStats {
    if (enableApi) {
        return SteamAPI_SteamUserStats_v012();
    } else {
        std.log.debug("Init Steam Utils", .{});
        return &TestStats;
    }
}
