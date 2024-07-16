const std = @import("std");

const root = @import("root");
pub const fakeApi = @hasDecl(root, "fakeSteam") and root.fakeSteam;

const enableApi = !fakeApi and (@hasDecl(root, "useSteam") and root.useSteam);

pub const STEAM_APP_ID = 480;

const TestUser: SteamUser = .{ .data = 1000 };
const TestUGC: SteamUGC = .{};
const TestUtils: SteamUtils = .{};
const TestStats: SteamUserStats = .{};

const log = std.log.scoped(.Steam);

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

pub const steamAlloc = std.heap.c_allocator;

pub const SteamUser = extern struct {
    data: i32,

    extern fn SteamAPI_ISteamUser_GetSteamID(SteamUser) SteamId;
    pub fn getSteamId(self: SteamUser) SteamId {
        if (enableApi) {
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
    pub fn isCallComplete(self: *const SteamUtils, handle: APIHandle, failed: *bool) bool {
        if (enableApi) {
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

pub const APIHandle = if (fakeApi) union(APIHandleKind) {
    Query: struct {
        handle: UGCQueryHandle,
    },
} else extern struct {
    data: u64,
};

pub const UGCQueryHandle = if (fakeApi) struct {
    kind: UGCQueryKind,
    page: u32,
} else extern struct {
    data: u64,
};

pub const PublishedFileId = extern struct {
    id: u64,
};

pub const UGCDetails = if (fakeApi) struct {
    fileId: u64,
    result: u32,
    fileType: WorkshopFileType,
    creator: u32,
    consumer: u32,
    title: []const u8,
    desc: []const u8,
    owner: u64,
    created: u32,
    updated: u32,
    added: u32,
    visible: u8,
    banned: bool,
    acceptable: bool,
    tagsTurnic: bool,
    tags: []const u8,
    file: UGCQueryHandle,
    previewFile: UGCQueryHandle,
    fileName: []const u8,
    fileSize: i32,
    previewFileSize: i32,
    rgchURL: []const u8,
    upVotes: u32,
    downVotes: u32,
    score: f32,
    children: u32,
} else extern struct {
    fileId: u64,
    result: u32,
    fileType: WorkshopFileType,
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
            log.debug("Download Item: {}", .{id});
            return true;
        }
    }

    extern fn SteamAPI_ISteamUGC_GetItemInstallInfo(ugc: *const SteamUGC, id: u64, size: *u64, folder: [*c]u8, folderSize: u32, timestamp: *u32) bool;
    pub fn getItemInstallInfo(ugc: *const SteamUGC, id: u64, size: *u64, folder: []u8, timestamp: *u32) bool {
        if (enableApi) {
            return SteamAPI_ISteamUGC_GetItemInstallInfo(ugc, id, size, folder.ptr, @intCast(folder.len), timestamp);
        } else {
            log.debug("itemInfo: {}", .{id});

            if (id < steamItems.items.len) {
                size.* = 0;
                const path = steamItems.items[id].folder;
                @memcpy(folder[0..path.len], path);
                timestamp.* = 0;

                return true;
            }

            return false;
        }
    }

    extern fn SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) APIHandle;
    pub fn sendQueryRequest(ugc: *const SteamUGC, handle: UGCQueryHandle) APIHandle {
        if (enableApi) {
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
        queryKind: UGCQueryKind,
        kind: u32,
        creatorId: u32,
        consumerId: u32,
        page: u32,
    ) UGCQueryHandle {
        if (enableApi) {
            return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc, queryKind, kind, creatorId, consumerId, page);
        } else {
            log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ queryKind, kind, creatorId, consumerId, page });
            return .{
                .kind = queryKind,
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
        if (enableApi) {
            return SteamAPI_ISteamUGC_GetQueryUGCResult(ugc, handle, index, details);
        } else {
            log.debug("query result", .{});
            if (handle.page != 1) return false;
            if (index >= steamItems.items.len) return false;

            details.* = .{
                .fileId = index,
                .result = 0,
                .fileType = .Community,
                .creator = 0,
                .consumer = 0,
                .title = steamItems.items[index].title,
                .desc = steamItems.items[index].desc,
                .owner = 0,
                .created = 0,
                .updated = 0,
                .added = 0,
                .visible = 0,
                .banned = false,
                .acceptable = true,
                .tagsTurnic = false,
                .tags = "test,steam",
                .file = handle,
                .previewFile = undefined,
                .fileName = "test",
                .fileSize = 0,
                .previewFileSize = 0,
                .rgchURL = "",
                .upVotes = 0,
                .downVotes = 0,
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
        if (enableApi) {
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

pub var steamItems = std.ArrayList(FakeUGCEntry).init(steamAlloc);

extern fn SteamAPI_Init() bool;
pub fn init() !void {
    if (enableApi) {
        if (!SteamAPI_Init()) {
            return error.SteamInitFail;
        }
        return;
    } else {
        const file = try std.fs.cwd().openFile("fake_steam/ugc.csv", .{});
        const reader = file.reader();

        while (reader.readUntilDelimiterOrEofAlloc(steamAlloc, '\n', 1000) catch null) |buffer| {
            defer steamAlloc.free(buffer);

            var iter = std.mem.split(u8, buffer, ",");
            const title = iter.next() orelse return error.SteamParse;
            const desc = iter.next() orelse return error.SteamParse;
            const folder = iter.next() orelse return error.SteamParse;

            try steamItems.append(.{
                .title = try steamAlloc.dupe(u8, title),
                .desc = try steamAlloc.dupe(u8, desc),
                .folder = try std.mem.concat(steamAlloc, u8, &.{
                    "/home/john/doc/rep/github.com/sandeee/fake_steam/",
                    folder,
                }),
            });
        }

        log.info("{any}", .{steamItems.items});

        log.debug("Init Steam", .{});
        return;
    }
}

extern fn SteamAPI_RestartAppIfNecessary(app_id: u32) bool;
pub fn restartIfNeeded(app_id: u32) bool {
    if (enableApi) {
        return SteamAPI_RestartAppIfNecessary(app_id);
    } else {
        log.debug("Restart If Needed: {}", .{app_id});
        return false;
    }
}

extern fn SteamAPI_SteamUGC_v017() *const SteamUGC;
pub fn getSteamUGC() *const SteamUGC {
    if (enableApi) {
        return SteamAPI_SteamUGC_v017();
    } else {
        log.debug("Get UGC", .{});
        return &TestUGC;
    }
}

extern fn SteamAPI_SteamUser_v023() SteamUser;
pub fn getUser() SteamUser {
    if (enableApi) {
        return SteamAPI_SteamUser_v023();
    } else {
        log.debug("Get User", .{});
        return TestUser;
    }
}

extern fn SteamAPI_SteamUtils_v010() *const SteamUtils;
pub fn getSteamUtils() *const SteamUtils {
    if (enableApi) {
        return SteamAPI_SteamUtils_v010();
    } else {
        log.debug("Init Steam Utils", .{});
        return &TestUtils;
    }
}

extern fn SteamAPI_SteamUserStats_v012() *const SteamUserStats;
pub fn getUserStats() *const SteamUserStats {
    if (enableApi) {
        return SteamAPI_SteamUserStats_v012();
    } else {
        log.debug("Init Steam Utils", .{});
        return &TestStats;
    }
}

extern fn SteamAPI_RunCallbacks() void;
pub fn runCallbacks() void {
    if (enableApi) {
        return SteamAPI_RunCallbacks();
    } else {
        log.debug("Init Steam Utils", .{});
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
