const std = @import("std");
const log = std.log.scoped(.Steam);

const options = if (@hasDecl(@import("root"), "steam_options")) @import("root").steam_options else .{};

pub const fake_api = @hasDecl(options, "fake_steam") and options.fake_steam;
const enable_api = !fake_api and (@hasDecl(options, "use_steam") and options.use_steam);

pub const STEAM_APP_ID: SteamAppId = if (@hasDecl(options, "app_id")) .{ .data = options.app_id } else .{ .data = 480 };
const TEST_USER: SteamUser = .{ .data = 1000 };
const TEST_UGC: SteamUGC = .{};
const TEST_UTILS: SteamUtils = .{};
const TEST_STATS: SteamUserStats = .{};

pub const NO_APP_ID: SteamAppId = .{ .data = 0 };

pub const allocator = std.heap.c_allocator;

pub const UGCQueryKind = enum(i32) {
    RankedByVote = 0,
    RankedByPublicationDate = 1,
    AcceptedForGameRankedByAcceptanceDate = 2,
    RankedByTrend = 3,
};

pub const WorkshopFileType = enum(u32) {
    Community = 0,
    Microtransaction = 1,
    Collection = 2,
    Art = 3,
    Video = 4,
    Screenshot = 5,
    Game = 6,
};

pub const SteamResult = enum(u32) {
    Ok = 1,
    Fail = 2,
    NoConnection = 3,
    InvalidPassword = 4,
    LoggedInElsewhere = 5,
    _,
};

pub const SteamAppId = struct {
    data: u32,
};

pub const SteamPubFileId = struct {
    data: u64,
};

pub const SteamUser = extern struct {
    data: i32,

    extern fn SteamAPI_ISteamUser_GetSteamID(SteamUser) SteamId;
    pub fn getSteamId(
        self: SteamUser,
    ) SteamId {
        if (enable_api) {
            return SteamAPI_ISteamUser_GetSteamID(self);
        } else {
            log.debug("Get Steam Id From User", .{});
            return .{
                .id = 1000,
            };
        }
    }
};

pub const SteamUtils = extern struct {
    extern fn SteamAPI_ISteamUtils_IsAPICallCompleted(*const SteamUtils, APIHandle, *bool) bool;
    pub fn isCallComplete(
        self: *const SteamUtils,
        handle: APIHandle,
        failed: *bool,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUtils_IsAPICallCompleted(self, handle, failed);
        } else {
            log.debug("Check complete {}", .{handle});
            switch (handle) {
                .Query => {
                    failed.* = false;

                    return true;
                },
            }
        }
    }
};

pub const SteamUserStats = extern struct {};
pub const SteamPipe = extern struct {};

const APIHandleKind = enum {
    Query,
};

pub const APIHandle = if (fake_api) union(APIHandleKind) {
    Query: struct {
        handle: UGCQueryHandle,
    },
} else extern struct {
    data: u64,
};

pub const UGCQueryHandle = if (fake_api) struct {
    kind: UGCQueryKind,
    page: u32,
} else extern struct {
    data: u64,
};

pub const PublishedFileId = extern struct {
    id: u64,
};

pub const UGCDetails = if (fake_api) struct {
    file_id: SteamPubFileId,
    result: SteamResult,
    file_type: WorkshopFileType,
    creator: SteamAppId,
    consumer: SteamAppId,
    title: []const u8,
    desc: []const u8,
    owner: u64,
    created: u32,
    updated: u32,
    added: u32,
    visible: u8,
    banned: bool,
    acceptable: bool,
    tags_turnic: bool,
    tags: []const u8,
    file: UGCQueryHandle,
    preview_file: UGCQueryHandle,
    file_name: []const u8,
    file_size: i32,
    preview_file_size: i32,
    rgch_url: []const u8,
    up_votes: u32,
    down_votes: u32,
    score: f32,
    children: u32,
} else extern struct {
    file_id: SteamPubFileId,
    result: SteamResult,
    file_type: WorkshopFileType,
    creator: SteamAppId,
    consumer: SteamAppId,
    title: [129]u8,
    desc: [8000]u8,
    owner: u64,
    created: u32,
    updated: u32,
    added: u32,
    visible: u8,
    banned: bool,
    acceptable: bool,
    tags_turnic: bool,
    tags: [1025]u8,
    file: UGCQueryHandle,
    preview_file: UGCQueryHandle,
    file_name: [260]u8,
    file_size: i32,
    preview_file_size: i32,
    rgch_url: [256]u8,
    up_votes: u32,
    down_votes: u32,
    score: f32,
    children: u32,
};

pub const SteamUGC = extern struct {
    extern fn SteamAPI_ISteamUGC_DownloadItem(ugc: *const SteamUGC, id: SteamPubFileId, hp: bool) bool;
    pub fn downloadItem(
        ugc: *const SteamUGC,
        id: SteamPubFileId,
        hp: bool,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_DownloadItem(ugc, id, hp);
        } else {
            log.debug("Download Item: {}", .{id});
            return true;
        }
    }

    extern fn SteamAPI_ISteamUGC_GetItemInstallInfo(ugc: *const SteamUGC, id: SteamPubFileId, size: *u64, folder: [*c]u8, folderSize: u32, timestamp: *u32) bool;
    pub fn getItemInstallInfo(
        ugc: *const SteamUGC,
        id: SteamPubFileId,
        size: *u64,
        folder: []u8,
        timestamp: *u32,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_GetItemInstallInfo(ugc, id, size, folder.ptr, @intCast(folder.len), timestamp);
        } else {
            log.debug("itemInfo: {}", .{id});

            if (id.data < steam_items.items.len) {
                size.* = 0;
                const path = steam_items.items[id.data].folder;
                @memcpy(folder[0..path.len], path);
                timestamp.* = 0;

                return true;
            }

            return false;
        }
    }

    extern fn SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) APIHandle;
    pub fn sendQueryRequest(
        ugc: *const SteamUGC,
        handle: UGCQueryHandle,
    ) APIHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc, handle);
        } else {
            log.debug("SendQuery: handle: {}", .{handle});
            return .{
                .Query = .{
                    .handle = handle,
                },
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc: *const SteamUGC, queryKind: UGCQueryKind, kind: u32, creatorId: u32, consumerId: u32, page: u32) UGCQueryHandle;
    pub fn createQueryRequest(
        ugc: *const SteamUGC,
        query_kind: UGCQueryKind,
        kind: u32,
        creator_id: SteamAppId,
        consumer_id: SteamAppId,
        page: u32,
    ) UGCQueryHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc, query_kind, kind, creator_id, consumer_id, page);
        } else {
            log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ query_kind, kind, creator_id, consumer_id, page });
            return .{
                .kind = query_kind,
                .page = page,
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
        if (enable_api) {
            return SteamAPI_ISteamUGC_GetQueryUGCResult(ugc, handle, index, details);
        } else {
            log.debug("query result", .{});
            if (handle.page != 1) return false;
            if (index >= steam_items.items.len) return false;

            details.* = .{
                .file_id = .{ .data = @intCast(index) },
                .result = .Ok,
                .file_type = .Community,
                .creator = STEAM_APP_ID,
                .consumer = STEAM_APP_ID,
                .title = steam_items.items[index].title,
                .desc = steam_items.items[index].desc,
                .owner = 0,
                .created = 0,
                .updated = 0,
                .added = 0,
                .visible = 0,
                .banned = false,
                .acceptable = true,
                .tags_turnic = false,
                .tags = "test,steam",
                .file = handle,
                .preview_file = undefined,
                .file_name = "test",
                .file_size = 0,
                .preview_file_size = 0,
                .rgch_url = "",
                .up_votes = 0,
                .down_votes = 0,
                .score = 0,
                .children = 0,
            };
            return true;
        }
    }

    extern fn SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) bool;
    pub fn releaseQueryResult(
        ugc: *const SteamUGC,
        handle: UGCQueryHandle,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc, handle);
        } else {
            log.debug("query free", .{});
            return false;
        }
    }
};

pub const SteamId = extern struct {
    id: u64,
};

pub const FakeUGCEntry = struct {
    title: []const u8,
    desc: []const u8,
    folder: []const u8,
};

pub var steam_items = std.ArrayList(FakeUGCEntry).init(allocator);

extern fn SteamAPI_Init() bool;
pub fn init() !void {
    if (enable_api) {
        if (!SteamAPI_Init()) {
            return error.SteamInitFail;
        }
        return;
    } else {
        const file = try std.fs.cwd().openFile("fake_steam/ugc.csv", .{});
        const reader = file.reader();

        while (reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1000) catch null) |buffer| {
            defer allocator.free(buffer);

            var iter = std.mem.split(u8, buffer, ",");
            const title = iter.next() orelse return error.SteamParse;
            const desc = iter.next() orelse return error.SteamParse;
            const folder = iter.next() orelse return error.SteamParse;

            try steam_items.append(.{
                .title = try allocator.dupe(u8, title),
                .desc = try allocator.dupe(u8, desc),
                .folder = try std.mem.concat(allocator, u8, &.{
                    "/home/john/doc/rep/github.com/sandeee/fake_steam/",
                    folder,
                }),
            });
        }

        log.debug("UGC Count {}", .{steam_items.items.len});

        log.debug("Init Steam", .{});
        return;
    }
}

extern fn SteamAPI_RestartAppIfNecessary(app_id: SteamAppId) bool;
pub fn restartIfNeeded(
    app_id: SteamAppId,
) bool {
    if (enable_api) {
        return SteamAPI_RestartAppIfNecessary(app_id);
    } else {
        log.debug("Restart If Needed: {}", .{app_id});
        return false;
    }
}

extern fn SteamAPI_SteamUGC_v017() *const SteamUGC;
pub fn getSteamUGC() *const SteamUGC {
    if (enable_api) {
        return SteamAPI_SteamUGC_v017();
    } else {
        log.debug("Get UGC", .{});
        return &TEST_UGC;
    }
}

extern fn SteamAPI_SteamUser_v023() SteamUser;
pub fn getUser() SteamUser {
    if (enable_api) {
        return SteamAPI_SteamUser_v023();
    } else {
        log.debug("Get User", .{});
        return TEST_USER;
    }
}

extern fn SteamAPI_SteamUtils_v010() *const SteamUtils;
pub fn getSteamUtils() *const SteamUtils {
    if (enable_api) {
        return SteamAPI_SteamUtils_v010();
    } else {
        log.debug("Init Steam Utils", .{});
        return &TEST_UTILS;
    }
}

extern fn SteamAPI_SteamUserStats_v012() *const SteamUserStats;
pub fn getUserStats() *const SteamUserStats {
    if (enable_api) {
        return SteamAPI_SteamUserStats_v012();
    } else {
        log.debug("Init Steam Utils", .{});
        return &TEST_STATS;
    }
}

extern fn SteamAPI_RunCallbacks() void;
pub fn runCallbacks() void {
    if (enable_api) {
        return SteamAPI_RunCallbacks();
    } else {
        log.debug("Init Steam Utils", .{});
        return &TEST_STATS;
    }
}

pub const CALLBACK_COMPLETED = 703;

pub const CallbackMsg = extern struct {
    user: SteamUser,
    callback: i32,
    param: *void,
    param_size: i32,
};

var manual_setup: bool = false;

extern fn SteamAPI_GetHSteamPipe() *const SteamPipe;
extern fn SteamAPI_ManualDispatch_Init() void;
extern fn SteamAPI_ManualDispatch_RunFrame(*const SteamPipe) void;
extern fn SteamAPI_ManualDispatch_GetNextCallback(*const SteamPipe, *CallbackMsg) bool;
extern fn SteamAPI_ManualDispatch_FreeLastCallback(*const SteamPipe) void;
pub fn manualCallback(comptime calls: fn (CallbackMsg) anyerror!void) !void {
    if (enable_api) {
        if (!manual_setup) {
            SteamAPI_ManualDispatch_Init();
        }

        const steam_pipe = SteamAPI_GetHSteamPipe();
        SteamAPI_ManualDispatch_RunFrame(steam_pipe);
        var callback: CallbackMsg = undefined;

        while (SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, &callback)) {
            try calls(callback);

            SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
        }
    }
}
