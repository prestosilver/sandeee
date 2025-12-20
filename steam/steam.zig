const std = @import("std");
const log = std.log.scoped(.Steam);

pub const callback = @import("callbacks.zig");

const options = if (@hasDecl(@import("root"), "steam_options")) @import("root").steam_options else .{};

pub const fake_api = @hasDecl(options, "fake_steam") and options.fake_steam;
const enable_api = !fake_api and (@hasDecl(options, "use_steam") and options.use_steam);

pub const STEAM_APP_ID: AppId = if (@hasDecl(options, "app_id")) .{ .id = options.app_id } else .{ .id = 4124360 };
pub const allocator = if (@hasDecl(options, "alloc")) options.alloc else std.heap.c_allocator;

const TEST_USER: User.Id = .{ .id = 1000 };
const TEST_UGC: UGC = .{};
const TEST_UTILS: Utils = .{};
const TEST_STATS: UserStats = .{};

pub const NO_APP_ID: AppId = .{ .id = 0 };

pub const CallbackId = enum(u32) {
    CreateItem = 3403,
    UpdateItem = 3404,
};

pub const UGCQueryKind = enum(u32) {
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
    GameManagedItem = 15,
};

pub const Result = enum(u32) {
    Ok = 1,
    Fail = 2,
    NoConnection = 3,
    InvalidPassword = 4,
    LoggedInElsewhere = 5,
    _,
};

pub const WorkshopItemVisibility = enum(u32) {
    Public,
    FriendsOnly,
    Private,
    Unlisted,
};

pub const AppId = extern struct { id: u32 };

pub const User = extern struct {
    pub const Id = extern struct { id: u64 };

    data: u32,

    extern fn SteamAPI_ISteamUser_GetSteamID(User) Id;
    pub fn getSteamId(
        self: User,
    ) Id {
        if (enable_api) {
            return SteamAPI_ISteamUser_GetSteamID(self);
        } else {
            log.debug("Get Steam Id From User", .{});
            return TEST_USER;
        }
    }
};

fn updateFakeUGC() !void {
    const file = try std.fs.openFileAbsolute("/home/john/doc/rep/github.com/sandeee/fake_steam/ugc.csv", .{ .mode = .write_only });
    defer file.close();

    var writer = file.writer(&.{});

    for (steam_items.items) |item| {
        try writer.interface.print("{s},{s},{s}\n", .{ item.title, item.desc, item.folder });
    }
}

pub const Utils = extern struct {
    extern fn SteamAPI_ISteamUtils_IsAPICallCompleted(*const Utils, APIHandle, *bool) bool;
    pub fn isCallComplete(
        self: *const Utils,
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
                .CreateItem => {
                    failed.* = false;
                    return true;
                },
                .UpdateItem => {
                    failed.* = false;
                    return true;
                },
            }
        }
    }

    extern fn SteamAPI_ISteamUtils_GetAPICallResult(self: *const Utils, handle: APIHandle, data: *anyopaque, data_len: u32, callback_id: CallbackId, failed: *bool) bool;
    pub fn getCallResult(
        self: *const Utils,
        comptime T: type,
        handle: APIHandle,
        data: *T,
        failed: *bool,
    ) bool {
        if (enable_api) {
            data.* = std.mem.zeroes(T);

            return SteamAPI_ISteamUtils_GetAPICallResult(
                self,
                handle,
                data,
                @intCast(@sizeOf(T)),
                T.ID,
                failed,
            );
        } else {
            get_result: {
                switch (T.ID) {
                    .CreateItem => {
                        const id = steam_items.items.len;
                        const path = std.fmt.allocPrint(allocator, "/home/john/doc/rep/github.com/sandeee/fake_steam/created/{}", .{id}) catch break :get_result;

                        var root = std.fs.openDirAbsolute("/", .{}) catch break :get_result;
                        defer root.close();

                        root.makePath(path) catch break :get_result;

                        steam_items.append(.{
                            .title = allocator.dupe(u8, "") catch break :get_result,
                            .desc = allocator.dupe(u8, "") catch break :get_result,
                            .folder = path,
                        }) catch
                            break :get_result;

                        updateFakeUGC() catch break :get_result;

                        data.* = .{
                            .result = .Ok,
                            .file_id = .{ .id = id },
                            .needs_workshop_agree = false,
                        };

                        failed.* = false;
                        return true;
                    },
                    .UpdateItem => {
                        data.* = .{
                            .result = .Ok,
                            .needs_workshop_agree = false,
                        };

                        failed.* = false;
                        return true;
                    },
                }
            }

            failed.* = true;
            return false;
        }
    }
};

pub const UserStats = extern struct {};
pub const Pipe = extern struct {};

const APIHandleKind = enum {
    Query,
    CreateItem,
    UpdateItem,
};

pub const APIHandle = if (fake_api) union(APIHandleKind) {
    Query: struct {
        handle: UGCQueryHandle,
    },
    CreateItem,
    UpdateItem,
} else extern struct { data: u64 };

pub const UGCQueryHandle = if (fake_api) struct {
    kind: UGCQueryKind,
    page: u32,

    pub fn deinit(self: UGCQueryHandle, ugc: *const UGC) void {
        _ = self;
        _ = ugc;
    }

    pub fn setSearchText(self: UGCQueryHandle, ugc: *const UGC, text: [:0]const u8) !void {
        _ = self;
        _ = ugc;
        _ = text;
    }
} else extern struct {
    data: u64,
    extern fn SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc: *const UGC, self: UGCQueryHandle) bool;
    pub fn deinit(self: UGCQueryHandle, ugc: *const UGC) void {
        _ = SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc, self);
    }

    extern fn SteamAPI_ISteamUGC_SetSearchText(ugc: *const UGC, handle: UGCQueryHandle, text: [*:0]const u8) bool;
    pub fn setSearchText(self: UGCQueryHandle, ugc: *const UGC, text: [:0]const u8) !void {
        if (!SteamAPI_ISteamUGC_SetSearchText(ugc, self, text.ptr))
            return error.UnknownError;
    }
};

pub const PublishedFileId = extern struct {
    id: u64,
};

pub const UGC = extern struct {
    pub const ItemDetails = if (fake_api) struct {
        file_id: PubFileId,
        result: Result,
        file_type: WorkshopFileType,
        creator: AppId,
        consumer: AppId,
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
        file_id: PubFileId,
        result: Result,
        file_type: WorkshopFileType,
        creator: AppId,
        consumer: AppId,
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

    pub const UpdateHandle = extern struct {
        id: u64,

        extern fn SteamAPI_ISteamUGC_SetItemTitle(ugc: *const UGC, handle: UpdateHandle, title: [*:0]const u8) bool;
        pub fn setTitle(
            self: UpdateHandle,
            ugc: *const UGC,
            title: []const u8,
        ) bool {
            if (enable_api) {
                const tmp_title = allocator.dupeZ(u8, title) catch return false;
                defer allocator.free(tmp_title);

                return SteamAPI_ISteamUGC_SetItemTitle(ugc, self, tmp_title);
            } else {
                log.debug("Set item title: {}", .{self.id});

                steam_items.items[self.id].title = (allocator.realloc(steam_items.items[self.id].title, title.len) catch return false);
                @memcpy(steam_items.items[self.id].title, title);

                updateFakeUGC() catch return false;

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemVisibility(ugc: *const UGC, handle: UpdateHandle, vis: WorkshopItemVisibility) bool;
        pub fn setVisibility(
            self: UpdateHandle,
            ugc: *const UGC,
            vis: WorkshopItemVisibility,
        ) bool {
            if (enable_api) {
                return SteamAPI_ISteamUGC_SetItemVisibility(ugc, self, vis);
            } else {
                log.debug("Set item vis: {}", .{self.id});

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemDescription(ugc: *const UGC, handle: UpdateHandle, desc: [*:0]const u8) bool;
        pub fn setDescription(
            self: UpdateHandle,
            ugc: *const UGC,
            desc: []const u8,
        ) bool {
            if (enable_api) {
                const tmp_desc = allocator.dupeZ(u8, desc) catch return false;
                defer allocator.free(tmp_desc);

                return SteamAPI_ISteamUGC_SetItemDescription(ugc, self, tmp_desc);
            } else {
                log.debug("Set item desc: {}", .{self.id});

                steam_items.items[self.id].desc = (allocator.realloc(steam_items.items[self.id].desc, desc.len) catch return false);
                @memcpy(steam_items.items[self.id].desc, desc);

                updateFakeUGC() catch return false;

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemContent(ugc: *const UGC, handle: UpdateHandle, path: [*:0]const u8) bool;
        pub fn setContent(
            self: UpdateHandle,
            ugc: *const UGC,
            path: std.fs.Dir,
        ) bool {
            if (enable_api) {
                var outBuffer = std.mem.zeroes([256]u8);

                const tmp_path = path.realpathZ(".", &outBuffer) catch return false;

                return SteamAPI_ISteamUGC_SetItemContent(ugc, self, @ptrCast(tmp_path));
            } else {
                log.debug("Set item content: {}", .{self.id});

                // manual guard on sandeee, hello, and cats
                if (self.id < 3)
                    return false;

                if (self.id > steam_items.items.len)
                    return false;

                {
                    var rm_child = std.process.Child.init(
                        &.{ "rm", "-r", steam_items.items[self.id].folder },
                        allocator,
                    );
                    _ = rm_child.spawnAndWait() catch return false;
                }

                var outBuffer = std.mem.zeroes([256]u8);
                const tmp_path = path.realpath(".", &outBuffer) catch return false;

                log.debug("create path for item {s}", .{tmp_path});

                {
                    var cp_child = std.process.Child.init(
                        &.{ "cp", "-r", tmp_path, steam_items.items[self.id].folder },
                        allocator,
                    );
                    _ = cp_child.spawnAndWait() catch return false;
                }

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SubmitItemUpdate(ugc: *const UGC, item: UpdateHandle, note: [*:0]const u8) APIHandle;
        pub fn submit(
            self: UpdateHandle,
            ugc: *const UGC,
            note: []const u8,
        ) APIHandle {
            if (enable_api) {
                const tmp_note = allocator.dupeZ(u8, note) catch return .{ .data = 0 };
                defer allocator.free(tmp_note);

                return SteamAPI_ISteamUGC_SubmitItemUpdate(ugc, self, tmp_note);
            } else {
                log.debug("Submit Update: {}", .{self.id});
                return .UpdateItem;
            }
        }
    };

    pub const PubFileId = extern struct { id: u64 };

    extern fn SteamAPI_ISteamUGC_DownloadItem(ugc: *const UGC, id: PubFileId, hp: bool) bool;
    pub fn downloadItem(
        ugc: *const UGC,
        id: PubFileId,
        hp: bool,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_DownloadItem(ugc, id, hp);
        } else {
            log.debug("Download Item: {}", .{id});
            return true;
        }
    }

    extern fn SteamAPI_ISteamUGC_CreateItem(ugc: *const UGC, appid: AppId, kind: WorkshopFileType) APIHandle;
    pub fn createItem(
        ugc: *const UGC,
        appid: AppId,
        kind: WorkshopFileType,
    ) APIHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_CreateItem(ugc, appid, kind);
        } else {
            log.debug("CreateItem: kind: {}", .{kind});
            return .CreateItem;
        }
    }

    extern fn SteamAPI_ISteamUGC_StartItemUpdate(ugc: *const UGC, appid: AppId, item: PubFileId) UpdateHandle;
    pub fn startUpdate(
        ugc: *const UGC,
        appid: AppId,
        item: PubFileId,
    ) UpdateHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_StartItemUpdate(ugc, appid, item);
        } else {
            log.debug("Start Update: {}", .{item});
            return .{ .id = item.id };
        }
    }

    const ItemState = packed struct {
        subscribed: bool = false,
        legacy: bool = false,
        installed: bool = false,
        needsUpdate: bool = false,
        downloading: bool = false,
        downloadpending: bool = false,
        padding: u26 = 0,

        pub fn empty(self: *const ItemState) bool {
            const v: *const u32 = @ptrCast(self);
            return v.* == 0;
        }
    };

    extern fn SteamAPI_ISteamUGC_GetItemState(ugc: *const UGC, id: PubFileId) ItemState;
    pub fn getItemState(
        ugc: *const UGC,
        id: PubFileId,
    ) ItemState {
        if (enable_api) {
            return SteamAPI_ISteamUGC_GetItemState(ugc, id);
        } else {
            return .{
                .installed = id.id < steam_items.items.len,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_GetItemInstallInfo(ugc: *const UGC, id: PubFileId, size: *u64, folder: [*c]u8, folderSize: u32, timestamp: *u32) bool;
    pub fn getItemInstallInfo(
        ugc: *const UGC,
        id: PubFileId,
        size: *u64,
        folder: []u8,
        timestamp: *u32,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_GetItemInstallInfo(ugc, id, size, folder.ptr, @intCast(folder.len), timestamp);
        } else {
            log.debug("itemInfo: {}", .{id.id});

            if (id.id < steam_items.items.len) {
                size.* = 0;
                const path = steam_items.items[id.id].folder;
                @memcpy(folder[0..path.len], path);
                timestamp.* = 0;

                return true;
            }

            return false;
        }
    }

    extern fn SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc: *const UGC, handle: UGCQueryHandle) APIHandle;
    pub fn sendQueryRequest(
        ugc: *const UGC,
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

    const UserQuery = enum(u32) {
        Published = 0,
        VotedOn = 1,
        VotedUp = 2,
        VotedDown = 3,
        VotedLater = 4,
        Favorited = 5,
        Subscribed = 6,
        UsedOrPlayed = 7,
        Followed = 8,
    };

    const UGCMatchingType = enum(u32) {
        Items = 0,
        ItemsMtx = 1,
        ItemsReadyToUse = 2,
        UsableInGame = 10,
        All = 0xffff_ffff,
    };

    const SortOrder = enum(u32) {
        CreateDesc = 0,
        CreateAsc = 1,
    };

    extern fn SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(ugc: *const UGC, id: User.Id, list_type: UserQuery, kind: u32, sort: SortOrder, creator_id: AppId, consumer_id: AppId, page: u32) UGCQueryHandle;
    pub fn createUserQueryRequest(
        ugc: *const UGC,
        account: User.Id,
        query_kind: UserQuery,
        kind: u32,
        sort: SortOrder,
        creator_id: AppId,
        consumer_id: AppId,
        page: u32,
    ) UGCQueryHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(ugc, account, query_kind, kind, sort, creator_id, consumer_id, page);
        } else {
            log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ query_kind, kind, creator_id, consumer_id, page });
            return .{
                .kind = .RankedByVote,
                .page = page,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc: *const UGC, queryKind: UGCQueryKind, kind: UGCMatchingType, creatorId: AppId, consumerId: AppId, page: u32) UGCQueryHandle;
    pub fn createQueryRequest(
        ugc: *const UGC,
        query_kind: UGCQueryKind,
        item_kind: UGCMatchingType,
        creator_id: AppId,
        consumer_id: AppId,
        page: u32,
    ) UGCQueryHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc, query_kind, item_kind, creator_id, consumer_id, page);
        } else {
            log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ query_kind, item_kind, creator_id, consumer_id, page });
            return .{
                .kind = query_kind,
                .page = page,
            };
        }
    }

    extern fn SteamAPI_ISteamUGC_GetQueryUGCResult(ugc: *const UGC, handle: UGCQueryHandle, index: u32, details: *ItemDetails) bool;
    pub fn getQueryResult(
        ugc: *const UGC,
        handle: UGCQueryHandle,
        index: u32,
        details: *ItemDetails,
    ) bool {
        if (enable_api) {
            return SteamAPI_ISteamUGC_GetQueryUGCResult(ugc, handle, index, details);
        } else {
            log.debug("query result", .{});
            if (handle.page != 1) return false;
            if (index >= steam_items.items.len) return false;

            details.* = .{
                .file_id = .{ .id = @intCast(index) },
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

    extern fn SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc: *const UGC, handle: UGCQueryHandle) bool;
    pub fn releaseQueryResult(
        ugc: *const UGC,
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

pub const FakeUGCEntry = struct {
    title: []u8,
    desc: []u8,
    folder: []u8,
};

pub var steam_items: std.array_list.Managed(FakeUGCEntry) = .init(allocator);

extern fn SteamAPI_Init() bool;
pub fn init() !void {
    if (enable_api) {
        if (!SteamAPI_Init()) {
            return error.SteamInitFail;
        }
        return;
    } else {
        const file = try std.fs.openFileAbsolute("/home/john/doc/rep/github.com/sandeee/fake_steam/ugc.csv", .{});
        defer file.close();

        var reader_buffer: [1024]u8 = undefined;
        var reader = file.reader(&reader_buffer);

        while (try reader.interface.takeDelimiter('\n')) |line| {
            var split = std.mem.splitScalar(u8, line, ',');

            const title = split.next() orelse continue;
            const desc = split.next() orelse continue;
            const folder = split.next() orelse continue;

            try steam_items.append(.{
                .title = try allocator.dupe(u8, title),
                .desc = try allocator.dupe(u8, desc),
                .folder = try allocator.dupe(u8, folder),
            });
        }

        log.debug("UGC Count {}", .{steam_items.items.len});
        log.debug("Init Steam", .{});

        return;
    }
}

extern fn SteamAPI_RestartAppIfNecessary(app_id: AppId) bool;
pub fn restartIfNeeded(
    app_id: AppId,
) bool {
    if (enable_api) {
        return SteamAPI_RestartAppIfNecessary(app_id);
    } else {
        log.debug("Restart If Needed: {}", .{app_id});
        return false;
    }
}

extern fn SteamAPI_Shutdown() void;
pub fn deinit() void {
    if (enable_api) {
        return SteamAPI_Shutdown();
    } else {
        for (steam_items.items) |item| {
            allocator.free(item.title);
            allocator.free(item.desc);
            allocator.free(item.folder);
        }
        steam_items.deinit();
    }
}

extern fn SteamAPI_SteamUGC_v017() *const UGC;
pub fn getSteamUGC() *const UGC {
    if (enable_api) {
        return SteamAPI_SteamUGC_v017();
    } else {
        return &TEST_UGC;
    }
}

extern fn SteamAPI_SteamUser_v023() User;
pub fn getUser() User {
    if (enable_api) {
        return SteamAPI_SteamUser_v023();
    } else {
        return .{ .data = 0 };
    }
}

extern fn SteamAPI_SteamUtils_v010() *const Utils;
pub fn getSteamUtils() *const Utils {
    if (enable_api) {
        return SteamAPI_SteamUtils_v010();
    } else {
        return &TEST_UTILS;
    }
}

extern fn SteamAPI_SteamUserStats_v012() *const UserStats;
pub fn getUserStats() *const UserStats {
    if (enable_api) {
        return SteamAPI_SteamUserStats_v012();
    } else {
        return &TEST_STATS;
    }
}

extern fn SteamAPI_RunCallbacks() void;
pub fn runCallbacks() void {
    if (enable_api) {
        return SteamAPI_RunCallbacks();
    } else {
        return &TEST_STATS;
    }
}

pub const CALLBACK_COMPLETED = 703;

pub const CallbackMsg = extern struct {
    user: User,
    callback: i32,
    param: *void,
    param_size: i32,
};

var manual_setup: bool = false;

extern fn SteamAPI_GetHSteamPipe() *const Pipe;
extern fn SteamAPI_ManualDispatch_Init() void;
extern fn SteamAPI_ManualDispatch_RunFrame(*const Pipe) void;
extern fn SteamAPI_ManualDispatch_GetNextCallback(*const Pipe, *CallbackMsg) bool;
extern fn SteamAPI_ManualDispatch_FreeLastCallback(*const Pipe) void;
pub fn manualCallback(comptime calls: fn (CallbackMsg) anyerror!void) !void {
    if (enable_api) {
        if (!manual_setup) {
            SteamAPI_ManualDispatch_Init();
        }

        const steam_pipe = SteamAPI_GetHSteamPipe();
        SteamAPI_ManualDispatch_RunFrame(steam_pipe);
        var callback_msg: CallbackMsg = undefined;

        while (SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, &callback_msg)) {
            try calls(callback_msg);

            SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
        }
    }
}
