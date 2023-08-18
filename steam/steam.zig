const std = @import("std");

const root = @import("root");
const enableApi = @hasDecl(root, "useSteam") and root.useSteam;

pub const STEAM_APP_ID = 383980;

const TestUser: SteamUser = .{ .data = 1000 };
const TestUGC: SteamUGC = .{};
const TestUtils: SteamUtils = .{};
const TestStats: SteamUserStats = .{};

pub const SteamUser = extern struct {
    data: i32,

    extern fn SteamAPI_ISteamUser_GetSteamID(SteamUser) SteamId;
    pub fn getSteamId(self: SteamUser) SteamId {
        if (enableApi) {
            return SteamAPI_ISteamUser_GetSteamID(self);
        } else {
            std.log.debug("Get Steam Id From User", .{});
            return .{
                .id = 1000,
            };
        }
    }
};

pub const SteamUtils = extern struct {
    extern fn SteamAPI_ISteamUtils_IsAPICallCompleted(*const SteamUtils, APIHandle, *bool) bool;
    pub fn isCallComplete(self: *const SteamUtils, handle: APIHandle, failed: *bool) bool {
        if (enableApi) {
            return SteamAPI_ISteamUtils_IsAPICallCompleted(self, handle, failed);
        } else {
            std.log.debug("Check complete", .{});
            return .{
                .id = 1000,
            };
        }
    }
};

pub const SteamUserStats = extern struct {};
pub const SteamPipe = extern struct {};

pub const APIHandle = extern struct {
    data: u64,
};

pub const UGCQueryHandle = extern struct {
    data: u64,
};

pub const PublishedFileId = extern struct {
    id: u64,
};

pub const UGCDetails = extern struct {
    fileId: u64,
    result: u32,
    fileType: u32,
    creator: u32,
    consumer: u32,
    title: [129]u8,
    desc: [8000]u8,
    owner: u64,
    created: u32,
    updated: u32,
    added: u32,
    visible: u8,
    banned: bool,
    acceptable: bool,
    tagsTurnic: bool,
    tags: [1025]u8,
    file: UGCQueryHandle,
    previewFile: UGCQueryHandle,
    fileName: [260]u8,
    fileSize: i32,
    previewFileSize: i32,
    rgchURL: [256]u8,
    upVotes: u32,
    downVotes: u32,
    score: f32,
    children: u32,
};

pub const SteamUGC = extern struct {
    extern fn SteamAPI_ISteamUGC_DownloadItem(ugc: *const SteamUGC, id: u64, hp: bool) bool;
    pub fn downloadItem(ugc: *const SteamUGC, id: u64, hp: bool) bool {
        if (enableApi) {
            return SteamAPI_ISteamUGC_DownloadItem(ugc, id, hp);
        } else {
            std.log.debug("Download Item: {}", .{id});
            return .{
                .data = 1,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_GetItemInstallInfo(ugc: *const SteamUGC, id: u64, size: *u64, folder: [*c]u8, folderSize: u32, timestamp: *u32) bool;
    pub fn getItemInstallInfo(ugc: *const SteamUGC, id: u64, size: *u64, folder: []u8, timestamp: *u32) bool {
        if (enableApi) {
            return SteamAPI_ISteamUGC_GetItemInstallInfo(ugc, id, size, folder.ptr, @intCast(folder.len), timestamp);
        } else {
            std.log.debug("itemInfo: {}", .{id});
            return false;
        }
    }

    extern fn SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) APIHandle;
    pub fn sendQueryRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) APIHandle {
        if (enableApi) {
            return SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc, handle);
        } else {
            std.log.debug("SendQuery: handle: {}", .{handle});
            return .{
                .data = 1,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc: *const SteamUGC, queryKind: u32, kind: u32, creatorId: u32, consumerId: u32, page: u32) UGCQueryHandle;
    pub fn createQueryRequest(
        ugc: *const SteamUGC,
        queryKind: u32,
        kind: u32,
        creatorId: u32,
        consumerId: u32,
        page: u32,
    ) UGCQueryHandle {
        if (enableApi) {
            return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc, queryKind, kind, creatorId, consumerId, page);
        } else {
            std.log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ queryKind, kind, creatorId, consumerId, page });
            return .{
                .data = 10,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_GetQueryUGCResult(ugc: *const SteamUGC, handle: UGCQueryHandle, index: u32, details: *UGCDetails) bool;
    pub fn getQueryResult(
        ugc: *const SteamUGC,
        handle: UGCQueryHandle,
        index: u32,
        details: *UGCDetails,
    ) bool {
        if (enableApi) {
            return SteamAPI_ISteamUGC_GetQueryUGCResult(ugc, handle, index, details);
        } else {
            std.log.debug("query result", .{});
            return false;
        }
    }

    extern fn SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) bool;
    pub fn releaseQueryResult(
        ugc: *const SteamUGC,
        handle: UGCQueryHandle,
    ) bool {
        if (enableApi) {
            return SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc, handle);
        } else {
            std.log.debug("query result", .{});
            return false;
        }
    }
};

pub const SteamId = extern struct {
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

extern fn SteamAPI_SteamUGC_v017() *const SteamUGC;
pub fn getSteamUGC() *const SteamUGC {
    if (enableApi) {
        return SteamAPI_SteamUGC_v017();
    } else {
        std.log.debug("Get UGC", .{});
        return &TestUGC;
    }
}

extern fn SteamAPI_SteamUser_v023() SteamUser;
pub fn getUser() SteamUser {
    if (enableApi) {
        return SteamAPI_SteamUser_v023();
    } else {
        std.log.debug("Get User", .{});
        return TestUser;
    }
}

extern fn SteamAPI_SteamUtils_v010() *const SteamUtils;
pub fn getSteamUtils() *const SteamUtils {
    if (enableApi) {
        return SteamAPI_SteamUtils_v010();
    } else {
        std.log.debug("Init Steam Utils", .{});
        return &TestUtils;
    }
}

extern fn SteamAPI_SteamUserStats_v012() *const SteamUserStats;
pub fn getUserStats() *const SteamUserStats {
    if (enableApi) {
        return SteamAPI_SteamUserStats_v012();
    } else {
        std.log.debug("Init Steam Utils", .{});
        return &TestStats;
    }
}

extern fn SteamAPI_RunCallbacks() void;
pub fn runCallbacks() void {
    if (enableApi) {
        return SteamAPI_RunCallbacks();
    } else {
        std.log.debug("Init Steam Utils", .{});
        return &TestStats;
    }
}

pub const CALLBACK_COMPLETED = 703;

pub const CallbackMsg = extern struct {
    user: SteamUser,
    callback: i32,
    param: *void,
    paramSize: i32,
};

var manualSetup: bool = false;

extern fn SteamAPI_GetHSteamPipe() *const SteamPipe;
extern fn SteamAPI_ManualDispatch_Init() void;
extern fn SteamAPI_ManualDispatch_RunFrame(*const SteamPipe) void;
extern fn SteamAPI_ManualDispatch_GetNextCallback(*const SteamPipe, *CallbackMsg) bool;
extern fn SteamAPI_ManualDispatch_FreeLastCallback(*const SteamPipe) void;
pub fn manualCallback(comptime calls: fn (CallbackMsg) anyerror!void) !void {
    if (enableApi) {
        if (!manualSetup) {
            SteamAPI_ManualDispatch_Init();
        }

        const steamPipe = SteamAPI_GetHSteamPipe();
        SteamAPI_ManualDispatch_RunFrame(steamPipe);
        var callback: CallbackMsg = undefined;

        while (SteamAPI_ManualDispatch_GetNextCallback(steamPipe, &callback)) {
            try calls(callback);

            SteamAPI_ManualDispatch_FreeLastCallback(steamPipe);
        }
    }
}
