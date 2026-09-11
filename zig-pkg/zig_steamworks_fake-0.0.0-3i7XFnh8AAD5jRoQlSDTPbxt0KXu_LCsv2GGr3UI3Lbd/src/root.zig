const std = @import("std");
const log = std.log.scoped(.Steam);

pub const callback = @import("callbacks.zig");

const options = if (@hasDecl(@import("root"), "steam_options")) @import("root").steam_options else .{};

const fake_api = @hasDecl(options, "fake_steam") and options.fake_steam;
const enable_api = !fake_api and (@hasDecl(options, "use_steam") and options.use_steam);
const allocator = if (@hasDecl(options, "allocator")) options.allocator else std.heap.c_allocator;

const TEST_UGC: UGC = .{};
const TEST_UTILS: Utils = .{};
const TEST_STATS: UserStats = .{};

pub const CallbackId = enum(u32) {
    ugc_query_completed = 3401,
    create_item = 3403,
    update_item = 3404,
};

pub const WorkshopFileType = enum(u32) {
    community = 0,
    microtransaction = 1,
    collection = 2,
    art = 3,
    video = 4,
    screenshot = 5,
    game = 6,
    game_managed_item = 15,
};

pub const Error = error{
    Fail,
    NoConnection,
    InvalidPassword,
    LoggedInElsewhere,
    InvalidProtocolVersion,
    InvalidParameter,
    FileNotFound,
    Busy,
    InvalidState,
    InvalidName,
    InvalidEmail,
    DuplicateName,
    AccessDenied,
    Timeout,
    Banned,
    AccountNotFound,
    InvalidSteamId,

    UnregisteredError,
    UnknownError,
};

pub const Result = enum(u32) {
    ok = 1,
    fail = 2,
    no_connection = 3,
    invalid_password = 5,
    logged_in_elsewhere = 6,
    invalid_protocol_version = 7,
    invalid_parameter = 8,
    file_not_found = 9,
    busy = 10,
    invalid_state = 11,
    invalid_name = 12,
    invalid_email = 13,
    duplicate_name = 14,
    access_denied = 15,
    timeout = 16,
    banned = 17,
    account_not_found = 18,
    invalid_steam_id = 19,
    service_unavailable = 20,
    not_logged_on = 21,
    pending = 22,
    encryption_failure = 23,
    insufficient_privilege = 24,
    limit_exceeded = 25,
    revoked = 26,
    expired = 27,
    already_redeemed = 28,
    duplicate_request = 29,
    already_owned = 30,
    ip_not_found = 31,
    persist_failed = 32,
    locking_failed = 33,
    logon_session_replaced = 34,
    connect_failed = 35,
    handshake_failed = 36,
    io_failure = 37,
    remote_disconnect = 38,
    shopping_cart_not_found = 39,
    blocked = 40,
    ignored = 41,
    no_match = 42,
    account_disabled = 43,
    service_read_only = 44,
    admin_ok = 46,
    content_version = 47,
    try_another_cm = 48,
    password_required_to_kick_session = 49,
    logged_in_elsehwhere = 50,
    suspended = 51,
    cancelled = 52,
    data_corruption = 53,
    disk_full = 54,
    remote_call_failed = 55,
    pasword_unset = 56,
    external_account_unlinked = 57,

    _,

    pub fn check(r: Result) Error!void {
        return switch (r) {
            .ok => return,
            .fail => error.Fail,
            .no_connection => error.NoConnection,
            .invalid_password => error.InvalidPassword,
            .logged_in_elsewhere => error.LoggedInElsewhere,
            .invalid_protocol_version => error.InvalidProtocolVersion,
            .invalid_parameter => error.InvalidParameter,
            .file_not_found => error.FileNotFound,
            .busy => error.Busy,
            .invalid_state => error.InvalidState,
            .invalid_name => error.InvalidName,
            .invalid_email => error.InvalidEmail,
            .duplicate_name => error.DuplicateName,
            .access_denied => error.AccessDenied,
            .timeout => error.Timeout,
            .banned => error.Banned,
            .account_not_found => error.AccountNotFound,
            .invalid_steam_id => error.InvalidSteamId,
            // TODO: cleanup else
            else => error.UnregisteredError,
            _ => error.UnknownError,
        };
    }
};

pub const WorkshopItemVisibility = enum(u32) {
    public,
    friends_only,
    private,
    unlisted,
};

pub const AppId = enum(u32) {
    const raw_appid = if (@hasDecl(options, "app_id")) options.app_id else 480;

    none = 0,
    this_app = raw_appid,
    _,

    pub const ugc_app: AppId = @enumFromInt(if (@hasDecl(options, "ugc_app_id")) options.ugc_app_id else raw_appid);
};

pub const User = enum(u32) {
    pub const Id = enum(u64) {
        fakeuser = 1000,
        _,
    };

    fakeuser = 1000,
    _,

    extern fn SteamAPI_ISteamUser_GetSteamID(User) Id;
    pub fn getSteamId(
        self: User,
    ) Id {
        if (enable_api) {
            return SteamAPI_ISteamUser_GetSteamID(self);
        } else {
            log.debug("Get Steam Id From User", .{});
            return .fakeuser;
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
    extern fn SteamAPI_SteamUtils_v010() *const Utils;
    pub fn get() *const Utils {
        if (enable_api) {
            return SteamAPI_SteamUtils_v010();
        } else {
            return &TEST_UTILS;
        }
    }
};

pub const UserStats = extern struct {
    extern fn SteamAPI_SteamUserStats_v012() *const UserStats;
    pub fn get() *const UserStats {
        if (enable_api) {
            return SteamAPI_SteamUserStats_v012();
        } else {
            return &TEST_STATS;
        }
    }
};

pub const Pipe = extern struct {
    extern fn SteamAPI_GetHSteamPipe() *const Pipe;
};

pub const APIHandle = extern struct {
    const Kind = enum {
        query,
        create_item,
        update_item,
        start_playtime_tracking,
        stop_playtime_tracking,
    };

    pub const invalid: APIHandle = .{ .handle = .invalid };
    pub fn isInvalid(self: APIHandle) bool {
        return self.handle == .invalid;
    }

    handle: if (fake_api) union(Kind) {
        query: struct {
            handle: UGC.Query.Handle,
        },
        invalid,
        create_item,
        update_item,
        start_playtime_tracking,
        stop_playtime_tracking,
    } else enum(u64) { invalid = 0, _ },

    extern fn SteamAPI_ISteamUtils_GetAPICallFailureReason(self: *const Utils, handle: APIHandle) Result;
    extern fn SteamAPI_ISteamUtils_GetAPICallResult(self: *const Utils, handle: APIHandle, data: *anyopaque, data_len: u32, callback_id: CallbackId, failed: *bool) bool;
    pub fn getResult(
        handle: APIHandle,
        comptime T: type,
    ) !T {
        if (enable_api) {
            var data: T = undefined;
            var failed: bool = true;

            if (!SteamAPI_ISteamUtils_GetAPICallResult(
                .get(),
                handle,
                &data,
                @intCast(@sizeOf(T)),
                T.ID,
                &failed,
            )) return error.Fail;

            if (failed)
                try SteamAPI_ISteamUtils_GetAPICallFailureReason(.get(), handle).check()
            else
                return data;

            unreachable;
        } else {
            get_result: {
                switch (T.ID) {
                    .create_item => {
                        const id: UGC.PublishedFile = @enumFromInt(steam_items.items.len);
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

                        return .{
                            .result = .ok,
                            .file_id = id,
                            .needs_workshop_agree = false,
                        };
                    },
                    .update_item => {
                        return .{
                            .result = .ok,
                            .needs_workshop_agree = false,
                        };
                    },
                }
            }

            return error.Fail;
        }
    }

    extern fn SteamAPI_ISteamUtils_IsAPICallCompleted(*const Utils, APIHandle, *bool) bool;
    pub fn isComplete(
        handle: APIHandle,
    ) bool {
        if (enable_api) {
            var failed = false;
            return SteamAPI_ISteamUtils_IsAPICallCompleted(.get(), handle, &failed);
        } else {
            log.debug("Check complete {}", .{handle});
            switch (handle) {
                .query => {
                    return true;
                },
                .create_item => {
                    return true;
                },
                .update_item => {
                    return true;
                },
                .start_playtime_tracking => {
                    return true;
                },
                .stop_playtime_tracking => {
                    return true;
                },
            }
        }
    }
};

pub const UGC = extern struct {
    pub const PublishedFile = enum(u64) {
        invalid = 0,
        _,

        extern fn SteamAPI_ISteamUGC_GetItemState(ugc: *const UGC, id: PublishedFile) UGC.ItemState;
        pub fn getItemState(id: PublishedFile) UGC.ItemState {
            if (enable_api) {
                return SteamAPI_ISteamUGC_GetItemState(.get(), id);
            } else {
                return .{
                    .installed = @intFromEnum(id) < steam_items.items.len,
                };
            }
        }

        extern fn SteamAPI_ISteamUGC_GetItemInstallInfo(ugc: *const UGC, id: PublishedFile, size: *u64, folder: [*c]u8, folderSize: u32, timestamp: *u32) bool;
        pub fn getInstallInfo(
            id: PublishedFile,
            size: *u64,
            folder: []u8,
            timestamp: *u32,
        ) bool {
            if (enable_api) {
                return SteamAPI_ISteamUGC_GetItemInstallInfo(.get(), id, size, folder.ptr, @intCast(folder.len), timestamp);
            } else {
                log.debug("itemInfo: {}", .{@intFromEnum(id)});

                if (@intFromEnum(id) < steam_items.items.len) {
                    size.* = 0;
                    const path = steam_items.items[@intFromEnum(id)].folder;
                    @memcpy(folder[0..path.len], path);
                    timestamp.* = 0;

                    return true;
                }

                return false;
            }
        }

        extern fn SteamAPI_ISteamUGC_StartItemUpdate(ugc: *const UGC, appid: AppId, item: PublishedFile) UGC.Update;
        pub fn startUpdate(
            item: PublishedFile,
            appid: AppId,
        ) !UGC.Update {
            if (enable_api) {
                const result = SteamAPI_ISteamUGC_StartItemUpdate(.get(), appid, item);
                if (result == .invalid) return error.Fail;

                return result;
            } else {
                log.debug("Start Update: {}", .{@intFromEnum(item)});

                const tmp: u64 = @intFromEnum(item);
                return @enumFromInt(tmp);
            }
        }

        extern fn SteamAPI_ISteamUGC_DownloadItem(ugc: *const UGC, id: UGC.PublishedFile, high_priority: bool) bool;
        pub fn download(
            id: UGC.PublishedFile,
            high_priority: bool,
        ) bool {
            if (enable_api) {
                return SteamAPI_ISteamUGC_DownloadItem(.get(), id, high_priority);
            } else {
                log.debug("Download Item: {}", .{id});
                return true;
            }
        }
    };

    extern fn SteamAPI_SteamUGC_v017() *const UGC;
    pub fn get() *const UGC {
        if (enable_api) {
            return SteamAPI_SteamUGC_v017();
        } else {
            return &TEST_UGC;
        }
    }

    pub const Query = extern struct {
        handle: if (fake_api) struct {
            kind: Kind,
            page: u32,
        } else enum(u64) {
            invalid = 0xffff_ffff_ffff_ffff,
            _,
        },

        pub const Kind = enum(u32) {
            ranked_by_vote = 0,
            ranked_by_publication_date = 1,
            accepted_for_game_ranked_by_acceptance_date = 2,
            ranked_by_trend = 3,
        };

        const UserQueryKind = enum(u32) {
            published = 0,
            voted_on = 1,
            voted_up = 2,
            voted_down = 3,
            voted_later = 4,
            favorited = 5,
            subscribed = 6,
            used_or_played = 7,
            followed = 8,
        };

        const SortOrder = enum(u32) {
            create_desc = 0,
            create_asc = 1,
            title_asc = 2,
            last_updated_desc = 3,
            subscription_date_desc = 4,
            vote_score_desc = 5,
        };

        extern fn SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(ugc: *const UGC, queryKind: Kind, kind: UGCMatchingType, creatorId: AppId, consumerId: AppId, page: u32) Query;
        pub fn initAll(
            query_kind: Kind,
            item_kind: UGCMatchingType,
            creator_id: AppId,
            consumer_id: AppId,
            page: u32,
        ) Query {
            if (enable_api) {
                return SteamAPI_ISteamUGC_CreateQueryAllUGCRequestPage(.get(), query_kind, item_kind, creator_id, consumer_id, page);
            } else {
                log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ query_kind, item_kind, creator_id, consumer_id, page });
                return .{
                    .kind = query_kind,
                    .page = page,
                };
            }
        }

        extern fn SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(ugc: *const UGC, id: User.Id, list_type: UserQueryKind, kind: u32, sort: SortOrder, creator_id: AppId, consumer_id: AppId, page: u32) Query;
        pub fn initUser(
            account: User.Id,
            query_kind: UserQueryKind,
            kind: u32,
            sort: SortOrder,
            creator_id: AppId,
            consumer_id: AppId,
            page: u32,
        ) Query {
            if (enable_api) {
                return SteamAPI_ISteamUGC_CreateQueryUserUGCRequest(.get(), account, query_kind, kind, sort, creator_id, consumer_id, page);
            } else {
                log.debug("Query: querykind: {}, kind: {}, creator: {}, consumer: {}, page: {}", .{ query_kind, kind, creator_id, consumer_id, page });
                return .{
                    .kind = .ranked_by_vote,
                    .page = page,
                };
            }
        }

        extern fn SteamAPI_ISteamUGC_SendQueryUGCRequest(ugc: *const UGC, handle: Query) APIHandle;
        pub fn send(
            handle: Query,
        ) APIHandle {
            if (enable_api) {
                return SteamAPI_ISteamUGC_SendQueryUGCRequest(.get(), handle);
            } else {
                log.debug("SendQuery: handle: {}", .{handle});
                return .{
                    .query = .{
                        .handle = handle,
                    },
                };
            }
        }

        extern fn SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(ugc: *const UGC, handle: Query) bool;
        pub fn deinit(
            handle: Query,
        ) void {
            if (enable_api) {
                _ = SteamAPI_ISteamUGC_ReleaseQueryUGCRequest(.get(), handle);
            } else {
                log.debug("query free", .{});
            }
        }

        extern fn SteamAPI_ISteamUGC_SetSearchText(ugc: *const UGC, handle: Query, text: [*:0]const u8) bool;
        pub fn setSearchText(
            self: Query,
            text: [:0]const u8,
        ) !void {
            if (enable_api) {
                if (!SteamAPI_ISteamUGC_SetSearchText(.get(), self, text.ptr))
                    return error.UnknownError;
            } else {
                // TODO
            }
        }

        extern fn SteamAPI_ISteamUGC_GetQueryUGCResult(ugc: *const UGC, handle: Query, index: u32, details: *ItemDetails) bool;
        pub fn getResult(
            handle: Query,
            index: u32,
            details: *ItemDetails,
        ) bool {
            if (enable_api) {
                return SteamAPI_ISteamUGC_GetQueryUGCResult(.get(), handle, index, details);
            } else {
                log.debug("query result", .{});
                if (handle.page != 1) return false;
                if (index >= steam_items.items.len) return false;

                details.* = .{
                    .file_id = @enumFromInt(index),
                    .result = .ok,
                    .file_type = .community,
                    .creator = .this_app,
                    .consumer = .this_app,
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
    };

    pub const ItemDetails = if (fake_api) struct {
        file_id: UGC.PublishedFile,
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
        file: Query.Handle,
        preview_file: Query.Handle,
        file_name: []const u8,
        file_size: i32,
        preview_file_size: i32,
        rgch_url: []const u8,
        up_votes: u32,
        down_votes: u32,
        score: f32,
        children: u32,

        pub fn titleSlice(self: @This()) []const u8 {
            return self.title;
        }

        pub fn descSlice(self: @This()) []const u8 {
            return self.desc;
        }
    } else extern struct {
        file_id: UGC.PublishedFile,
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
        file: UGC.Handle,
        preview_file: UGC.Handle,
        file_name: [260]u8,
        file_size: i32,
        preview_file_size: i32,
        rgch_url: [256]u8,
        up_votes: u32,
        down_votes: u32,
        score: f32,
        children: u32,

        pub fn titleSlice(self: @This()) []const u8 {
            return std.mem.sliceTo(&self.title, 0);
        }

        pub fn descSlice(self: @This()) []const u8 {
            return std.mem.sliceTo(&self.desc, 0);
        }
    };

    pub const Handle = enum(u64) { invalid = 0xffff_ffff_ffff_ffff, _ };

    pub const Update = enum(u64) {
        invalid = 0xffff_ffff_ffff_ffff,
        _,

        extern fn SteamAPI_ISteamUGC_SetItemTitle(ugc: *const UGC, handle: Update, title: [*:0]const u8) bool;
        pub fn setTitle(
            self: Update,
            title: [:0]const u8,
        ) !void {
            if (enable_api) {
                if (!SteamAPI_ISteamUGC_SetItemTitle(.get(), self, title))
                    return error.Fail;
            } else {
                log.debug("Set item title: {}", .{@intFromEnum(self)});

                steam_items.items[@intFromEnum(self)].title = (allocator.realloc(steam_items.items[@intFromEnum(self)].title, title.len) catch return false);
                @memcpy(steam_items.items[@intFromEnum(self)].title, title);

                updateFakeUGC() catch return error.Fail;
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemVisibility(ugc: *const UGC, handle: Update, vis: WorkshopItemVisibility) bool;
        pub fn setVisibility(
            self: Update,
            vis: WorkshopItemVisibility,
        ) !void {
            if (enable_api) {
                if (!SteamAPI_ISteamUGC_SetItemVisibility(.get(), self, vis))
                    return error.Fail;
            } else {
                log.debug("Set item vis: {}", .{@intFromEnum(self)});
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemDescription(ugc: *const UGC, handle: Update, desc: [*:0]const u8) bool;
        pub fn setDescription(
            self: Update,
            desc: [:0]const u8,
        ) !void {
            if (enable_api) {
                if (!SteamAPI_ISteamUGC_SetItemDescription(.get(), self, desc))
                    return error.Fail;
            } else {
                log.debug("Set item desc: {}", .{@intFromEnum(self)});

                steam_items.items[@intFromEnum(self)].desc = (allocator.realloc(steam_items.items[@intFromEnum(self)].desc, desc.len) catch return false);
                @memcpy(steam_items.items[@intFromEnum(self)].desc, desc);

                try updateFakeUGC();
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemContent(ugc: *const UGC, handle: Update, path: [*:0]const u8) bool;
        pub fn setContent(
            self: Update,
            path: std.fs.Dir,
        ) Error!void {
            if (enable_api) {
                var outBuffer = std.mem.zeroes([256]u8);

                const tmp_path = path.realpathZ(".", &outBuffer) catch
                    return error.FileNotFound;

                if (!SteamAPI_ISteamUGC_SetItemContent(.get(), self, @ptrCast(tmp_path)))
                    return error.Fail;
            } else {
                log.debug("Set item content: {}", .{@intFromEnum(self)});

                // manual guard on sandeee, hello, and cats
                if (@intFromEnum(self) < 1)
                    return false;

                if (@intFromEnum(self) > steam_items.items.len)
                    return false;

                {
                    var rm_child = std.process.Child.init(
                        &.{ "rm", "-r", steam_items.items[@intFromEnum(self)].folder },
                        allocator,
                    );
                    _ = rm_child.spawnAndWait() catch return false;
                }

                var outBuffer = std.mem.zeroes([256]u8);
                const tmp_path = path.realpath(".", &outBuffer) catch return false;

                log.debug("create path for item {s}", .{tmp_path});

                {
                    var cp_child = std.process.Child.init(
                        &.{ "cp", "-r", tmp_path, steam_items.items[@intFromEnum(self)].folder },
                        allocator,
                    );
                    _ = cp_child.spawnAndWait() catch return false;
                }

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SetItemPreview(ugc: *const UGC, item: Update, file: [*:0]const u8) bool;
        pub fn setPreview(
            self: Update,
            file: [:0]const u8,
        ) !void {
            if (enable_api) {
                if (SteamAPI_ISteamUGC_SetItemPreview(.get(), self, file))
                    return error.Fail;
            } else {
                log.debug("Add preview {}, {s}", .{ @intFromEnum(self), file });

                return true;
            }
        }

        extern fn SteamAPI_ISteamUGC_SubmitItemUpdate(ugc: *const UGC, item: Update, note: [*:0]const u8) APIHandle;
        pub fn submit(
            self: Update,
            note: [:0]const u8,
        ) !APIHandle {
            if (enable_api) {
                const result = SteamAPI_ISteamUGC_SubmitItemUpdate(.get(), self, note);
                if (result.isInvalid()) return error.Fail;

                return result;
            } else {
                log.debug("Submit update: {}", .{@intFromEnum(self)});

                return .update_item;
            }
        }
    };

    extern fn SteamAPI_ISteamUGC_CreateItem(ugc: *const UGC, appid: AppId, kind: WorkshopFileType) APIHandle;
    pub fn createItem(
        kind: WorkshopFileType,
        appid: AppId,
    ) APIHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_CreateItem(.get(), appid, kind);
        } else {
            log.debug("Create item: kind: {}", .{kind});
            return .create_item;
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

    extern fn SteamAPI_ISteamUGC_StartPlaytimeTracking(self: *const UGC, ids: [*c]const PublishedFile, count: u32) APIHandle;
    pub fn startPlaytimeTracking(ids: []const PublishedFile) APIHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_StartPlaytimeTracking(.get(), ids.ptr, @intCast(ids.len));
        } else {
            log.debug("Start playtime tracking, {any}", .{ids});
            return .start_playtime_tracking;
        }
    }

    extern fn SteamAPI_ISteamUGC_StopPlaytimeTracking(self: *const UGC, ids: [*c]const PublishedFile, count: u32) APIHandle;
    pub fn stopPlaytimeTracking(ids: []const PublishedFile) APIHandle {
        if (enable_api) {
            return SteamAPI_ISteamUGC_StopPlaytimeTracking(.get(), ids.ptr, @intCast(ids.len));
        } else {
            log.debug("Stop playtime tracking, {any}", .{ids});
            return .stop_playtime_tracking;
        }
    }

    const UGCMatchingType = enum(u32) {
        items = 0,
        items_mtx = 1,
        items_ready_to_use = 2,
        usable_in_game = 10,
        all = 0xffff_ffff,
    };
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
        log.debug("Restart If Needed: {}", .{@intFromEnum(app_id)});
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

extern fn SteamAPI_SteamUser_v023() User;
pub fn getUser() User {
    if (enable_api) {
        return SteamAPI_SteamUser_v023();
    } else {
        return .fakeuser;
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

extern fn SteamAPI_ManualDispatch_Init() void;
extern fn SteamAPI_ManualDispatch_RunFrame(*const Pipe) void;
extern fn SteamAPI_ManualDispatch_GetNextCallback(*const Pipe, *CallbackMsg) bool;
extern fn SteamAPI_ManualDispatch_FreeLastCallback(*const Pipe) void;
pub fn manualCallback(comptime calls: fn (CallbackMsg) anyerror!void) !void {
    if (enable_api) {
        if (!manual_setup) {
            SteamAPI_ManualDispatch_Init();
        }

        const steam_pipe: Pipe = .get();
        SteamAPI_ManualDispatch_RunFrame(steam_pipe);
        var callback_msg: CallbackMsg = undefined;

        while (SteamAPI_ManualDispatch_GetNextCallback(steam_pipe, &callback_msg)) {
            try calls(callback_msg);

            SteamAPI_ManualDispatch_FreeLastCallback(steam_pipe);
        }
    }
}
