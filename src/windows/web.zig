const std = @import("std");
const steam = @import("steam");
const options = @import("options");
const c = @import("../c.zig");

const Windows = @import("mod.zig");

const drawers = @import("../drawers/mod.zig");
const system = @import("../system/mod.zig");
const events = @import("../events/mod.zig");
const math = @import("../math/mod.zig");
const util = @import("../util/mod.zig");
const data = @import("../data/mod.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const HttpClient = util.HttpClient;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Url = util.Url;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const config = system.config;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

const strings = data.strings;

const HEADER_SIZE = 1024;
var web_idx: u8 = 0;

const STEAM_MINE_NAME = "mine";
const STEAM_LIST_NAME = "list";
const STEAM_ITEM_NAME = "item";

pub const WebData = struct {
    const Self = @This();

    pub fn getConts(_: *Self, url: Url) ![]const u8 {
        switch (url.kind) {
            .Steam => {
                if (options.IsSteam) {
                    const root = url.domain;
                    const sub = try allocator.alloc.dupeZ(u8, url.path);
                    defer allocator.alloc.free(sub);
                    if (std.mem.startsWith(u8, root, STEAM_LIST_NAME) and root.len != STEAM_LIST_NAME.len) {
                        const page_idx = try std.fmt.parseInt(u32, root[4..], 0);
                        return try steamList(page_idx, false, sub);
                    } else if (std.mem.startsWith(u8, root, STEAM_MINE_NAME) and root.len != STEAM_MINE_NAME.len) {
                        const page_idx = try std.fmt.parseInt(u32, root[4..], 0);
                        return try steamList(page_idx, true, sub);
                    } else if (std.mem.startsWith(u8, root, STEAM_ITEM_NAME) and root.len != STEAM_ITEM_NAME.len) {
                        const page_idx = std.fmt.parseInt(u64, root[4..], 10) catch {
                            return try allocator.alloc.dupe(u8, "Error: Invalid item page");
                        };

                        return steamItem(.{ .id = page_idx }, url) catch |err|
                            try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                    } else {
                        return try allocator.alloc.dupe(u8, "Error: Bad steam link");
                    }
                } else {
                    return try allocator.alloc.dupe(u8, "Error: Steam is not enabled");
                }
            },
            .Local => {
                const root = try files.FolderLink.resolve(.root);
                const file = try root.getFile(url.path);
                return try allocator.alloc.dupe(u8, try file.read(null));
            },
            .Web => {
                // const result = self.http.fetch() catch |err| {
                //     return switch (err) {};
                // };

                // return try allocator.alloc.dupe(u8, result);

                if (url.domain.len == 0)
                    return try allocator.alloc.dupe(u8, "Error: Bad Remote");

                var client = std.http.Client{ .allocator = allocator.alloc };
                defer client.deinit();

                const uri = std.Uri{
                    .scheme = "http",
                    .user = null,
                    .password = null,
                    .host = .{ .raw = url.domain },
                    .port = 80,
                    .path = .{ .raw = url.path },
                    .query = null,
                    .fragment = null,
                };

                const header_buffer = try allocator.alloc.alloc(u8, HEADER_SIZE);
                defer allocator.alloc.free(header_buffer);

                var req = client.open(.GET, uri, .{
                    .server_header_buffer = header_buffer,
                    .headers = .{
                        .user_agent = .{ .override = "SandEEE/0.0" },
                        .connection = .{ .override = "Close" },
                    },
                }) catch |err| {
                    return if (err == error.TemporaryNameServerFailure)
                        try std.fmt.allocPrint(allocator.alloc, "Error: No Internet Connection", .{})
                    else
                        try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                };

                defer req.deinit();

                req.send() catch |err| {
                    return try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                };

                req.wait() catch |err| {
                    return try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                };

                if (req.response.status != .ok) {
                    return try std.fmt.allocPrint(allocator.alloc, "Error: {} - {s}", .{ @intFromEnum(req.response.status), @tagName(req.response.status) });
                }

                const fconts = try req.reader().readAllAlloc(allocator.alloc, std.math.maxInt(usize));
                defer allocator.alloc.free(fconts);

                return try allocator.alloc.dupe(u8, fconts);
            },
            .Log => {
                const log_import = @import("../util/log.zig");
                const debug_mode = std.mem.eql(u8, url.path, "all");

                const log_data = log_import.getLogs();
                var len: usize = 0;

                for (log_data) |pool| for (pool) |log_item| {
                    if (!debug_mode and log_item.level == .debug) continue;

                    const color = switch (log_item.level) {
                        .err => strings.COLOR_RED,
                        .warn => strings.COLOR_DARK_YELLOW,
                        .info => strings.COLOR_BLACK,
                        .debug => strings.COLOR_BLACK,
                    };

                    len += color.len + log_item.data.?.len;
                };

                const result = try allocator.alloc.alloc(u8, len);

                var idx: usize = len;
                for (log_data) |pool| for (pool) |log_item| {
                    if (!debug_mode and log_item.level == .debug) continue;

                    const color = switch (log_item.level) {
                        .err => strings.COLOR_RED,
                        .warn => strings.COLOR_DARK_YELLOW,
                        .info => strings.COLOR_BLACK,
                        .debug => strings.COLOR_BLACK,
                    };

                    idx -= log_item.data.?.len;
                    @memcpy(result[idx .. idx + log_item.data.?.len], log_item.data.?);

                    idx -= color.len;
                    @memcpy(result[idx .. idx + color.len], color);
                };

                return result;
            },
            _ => {
                return try allocator.alloc.dupe(u8, "Error: Invalid Url protocol");
            },
        }
    }

    // TODO: loading bar?
    // pub const LoadState = enum {
    //     Fetch,
    //     Images,
    //     Links,
    // };

    pub const WebLink = struct {
        url: []const u8,
        pos: Rect,
    };

    pub const Style = struct {
        pub const Align = enum {
            Left,
            Center,
            Right,
        };

        ali: Align = .Left,
        scale: f32 = 1.0,
        color: Color = .{ .r = 0, .g = 0, .b = 0 },
        locked: bool = false,
        suffix: ?[]const u8 = null,
        prefix: ?[]const u8 = null,

        pub fn deinit(self: *const Style) void {
            if (self.suffix) |suffix| {
                allocator.alloc.free(suffix);
            }

            if (self.prefix) |prefix| {
                allocator.alloc.free(prefix);
            }
        }
    };

    load_thread: ?std.Thread = null,
    // http: HttpClient,

    highlight: Sprite,
    menubar: Sprite,
    text_box: [2]Sprite,
    icons: [2]Sprite,
    path: Url,

    shader: *Shader,
    conts: ?[]const u8,
    links: std.ArrayList(WebLink),
    hist: std.ArrayList(Url),

    scroll_top: bool = false,
    scroll_link: bool = false,

    highlight_idx: usize = 0,
    loading: bool = false,
    add_imgs: bool = false,
    add_links: bool = false,
    web_idx: u8,

    bnds: Rect = .{ .w = 1, .h = 1 },

    styles: std.StringArrayHashMap(Style),

    link_lock: std.Thread.Mutex = .{},
    image_lock: std.Thread.Mutex = .{},

    pub fn resetLinks(self: *Self) void {
        self.link_lock.lock();
        defer self.link_lock.unlock();

        for (self.links.items) |link| {
            allocator.alloc.free(link.url);
        }

        self.links.clearAndFree();
        self.add_links = true;
    }

    pub fn steamList(page: u32, mine: bool, query_text: [:0]const u8) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const query = if (mine)
            ugc.createUserQueryRequest(steam.getUser().getSteamId(), .Published, 0, .CreateAsc, steam.NO_APP_ID, steam.STEAM_APP_ID, page + 1)
        else
            ugc.createQueryRequest(.RankedByVote, .Items, steam.NO_APP_ID, steam.STEAM_APP_ID, page + 1);
        // const query = ugc.createUserQueryRequest(steam.getUser().getSteamId(), .Published, 0, .CreateAsc, steam.NO_APP_ID, steam.STEAM_APP_ID, page + 1);
        defer query.deinit(ugc);

        if (query_text.len != 0 and !mine) {
            try query.setSearchText(ugc, query_text);
        }

        const handle = ugc.sendQueryRequest(query);
        const steam_utils = steam.getSteamUtils();

        var failed = true;
        while (!steam_utils.isCallComplete(handle, &failed)) {
            std.time.sleep(200_000_000);
        }

        if (failed) {
            return try std.fmt.allocPrint(allocator.alloc, "{}", .{failed});
        }

        const details = try allocator.alloc.create(steam.UGC.ItemDetails);
        defer allocator.alloc.destroy(details);

        const prev = try std.fmt.allocPrint(allocator.alloc, "> prev: $list{}:{s}\n", .{ if (page == 0) 0 else page - 1, query_text });
        const next = try std.fmt.allocPrint(allocator.alloc, "> next: $list{}:{s}\n", .{ page + 1, query_text });
        defer allocator.alloc.free(prev);
        defer allocator.alloc.free(next);

        const nav = try std.mem.concat(allocator.alloc, u8, &.{
            if (page != 0) prev else "prev\n",
            next,
        });
        defer allocator.alloc.free(nav);

        // var conts = try std.fmt.allocPrint(allocator.alloc, "- {} -\n{s}", .{ page, nav });
        var conts = try std.fmt.allocPrint(allocator.alloc, "- Steam List -\n-- Page {} --\n", .{page + 1});
        var idx: u32 = 0;

        var added = false;

        while (ugc.getQueryResult(query, idx, details)) : (idx += 1) {
            // if (details.visible != 0) continue;

            added = true;

            if (steam.fake_api) {
                const old = conts;
                defer allocator.alloc.free(old);

                const title_text = try std.fmt.allocPrint(allocator.alloc, "--- {s} ---", .{details.title});
                defer allocator.alloc.free(title_text);

                const desc_text = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item{}:", .{ details.desc, details.file_id.id });
                defer allocator.alloc.free(desc_text);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, title_text, "\n", desc_text, "\n\n" });
            } else {
                const old = conts;
                defer allocator.alloc.free(old);

                const title: [*:0]u8 = @ptrCast(&details.title);

                const title_text = try std.fmt.allocPrint(allocator.alloc, "--- {s} ---", .{title[0..std.mem.len(title)]});
                defer allocator.alloc.free(title_text);

                const desc: [*:0]u8 = @ptrCast(&details.desc);
                const desc_text = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item{}:", .{ desc[0..std.mem.len(desc)], details.file_id.id });
                defer allocator.alloc.free(desc_text);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, title_text, "\n", desc_text, "\n\n" });
            }
        }

        if (!added) {
            const old = conts;
            defer allocator.alloc.free(old);

            conts = try std.mem.concat(allocator.alloc, u8, &.{ old, "\n-- No Results --\n> Page 1: $list0:\n\n", query_text });
        }

        {
            const old = conts;
            defer allocator.alloc.free(old);

            conts = try std.mem.concat(allocator.alloc, u8, &.{ old, nav });
        }

        return conts;
    }

    pub fn steamItem(id: steam.UGC.PubFileId, url: Url) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const BUFFER_SIZE = 256;

        {
            const state = ugc.getItemState(id);
            log.debug("steam item {} state: {}", .{ id, state });
        }

        if (!ugc.downloadItem(id, true)) {
            return try std.fmt.allocPrint(allocator.alloc, "Error: Failed to start steam download.", .{});
        }

        while (true) {
            const state = ugc.getItemState(id);

            if (!state.downloading and !state.downloadpending) {
                log.debug("item {} state: {}", .{ id, state });
                break;
            }

            std.time.sleep(2_000);
        }

        var size: u64 = 0;
        var timestamp: u32 = 0;
        var folder = std.mem.zeroes([BUFFER_SIZE + 1]u8);

        if (!ugc.getItemInstallInfo(id, &size, &folder, &timestamp))
            return error.SteamDownloadError;

        const folder_pointer = folder[0..std.mem.len(@as([*:0]u8, @ptrCast(&folder)))];

        const file_path = try std.fmt.allocPrint(allocator.alloc, "{s}/{s}", .{ folder_pointer, url.path });
        defer allocator.alloc.free(file_path);

        log.debug("file_path: {s}", .{file_path});

        var walker = std.fs.openDirAbsolute(file_path, .{ .iterate = true }) catch {
            const file = try std.fs.openFileAbsolute(file_path, .{});
            defer file.close();

            const stat = try file.stat();
            const cont = try file.reader().readAllAlloc(allocator.alloc, stat.size);

            return cont;
        };

        // if this is a directory give a file listing
        defer walker.close();

            // if index exists open that instead
            if (try (walker.access("index.edf", .{}) catch |err| switch (err) {
                error.FileNotFound => null,
                else => err,
            })) |_| {
                const file = try walker.openFile("index.edf", .{});
                defer file.close();

                const stat = try file.stat();
                const cont = try file.reader().readAllAlloc(allocator.alloc, stat.size);

                return cont;
            }

            var iter = walker.iterate();

            var conts = if (std.mem.eql(u8, url.path, ""))
                try std.fmt.allocPrint(allocator.alloc, "Contents of $item{}:/", .{id.id})
            else
                try std.fmt.allocPrint(allocator.alloc, "Contents of $item{}:{s}", .{ id.id, url.path });

            while (try iter.next()) |item| {
                const old = conts;
                defer allocator.alloc.free(old);

                conts = if (url.path.len > 0 and url.path[0] == '/')
                    try std.fmt.allocPrint(allocator.alloc, "{s}\n> {s}: @{s}/{s}", .{ old, item.name, url.path, item.name })
                else
                    try std.fmt.allocPrint(allocator.alloc, "{s}\n> {s}: @/{s}", .{ old, item.name, item.name });
            }

            return conts;
        }

        const file = try std.fs.openFileAbsolute(file_path, .{});
        defer file.close();
        const stat = try file.stat();
        const cont = try file.reader().readAllAlloc(allocator.alloc, stat.size);

        return cont;
    }

    pub fn loadPage(self: *Self) !void {
        if (self.loading) return;

        self.loading = true;
        defer {
            self.resetLinks();

            self.add_imgs = true;
            self.loading = false;
        }

        try self.resetStyles();

        if (std.mem.containsAtLeast(u8, self.path.path, 1, ".") and !std.mem.endsWith(u8, self.path.path, ".edf")) {
            const fconts = try self.getConts(self.path);
            defer allocator.alloc.free(fconts);

            try self.saveDialog(try allocator.alloc.dupe(u8, fconts), self.path.path[(std.mem.lastIndexOf(u8, self.path.path, "/") orelse 0) + 1 ..]);

            try self.back(true);

            return;
        }

        self.conts = try self.getConts(self.path);

        var iter = std.mem.splitScalar(u8, self.conts.?, '\n');

        while (iter.next()) |fullLine| {
            if (std.mem.startsWith(u8, fullLine, "#Style ")) {
                const tmp_path = try self.path.child(fullLine["#Style ".len..]);
                defer tmp_path.deinit();

                try self.loadStyle(tmp_path);
            }
        }
    }

    pub fn loadimage(self: *Self, url: Url, target: []const u8) !void {
        self.image_lock.lock();
        defer self.image_lock.unlock();

        defer allocator.alloc.free(target);
        defer url.deinit();
        const fconts = try self.getConts(url);
        defer allocator.alloc.free(fconts);

        const texture = TextureManager.instance.get(target).?;

        try texture.loadMem(fconts);
        try texture.upload();

        self.resetLinks();
    }

    pub fn loadStyle(self: *Self, url: Url) !void {
        const fconts = try self.getConts(url);
        defer allocator.alloc.free(fconts);

        var iter = std.mem.splitScalar(u8, fconts, '\n');
        var current_style: *Style = self.styles.getPtr("") orelse unreachable;

        while (iter.next()) |full_line| {
            if (std.mem.startsWith(u8, full_line, "#")) {
                try self.styles.put(try allocator.alloc.dupe(u8, full_line[1..]), .{});
                current_style = self.styles.getPtr(full_line[1..]) orelse unreachable;

                continue;
            }

            const comment_index = std.mem.indexOfScalar(u8, full_line, ';') orelse full_line.len;
            const comment_line = std.mem.trim(u8, full_line[0..comment_index], &std.ascii.whitespace);

            if (comment_line.len == 0)
                continue;

            const colon_index = std.mem.indexOfScalar(u8, comment_line, ':') orelse {
                log.warn("style line invalid: `{s}`", .{comment_line});

                continue;
            };

            const prop_name = std.mem.trim(u8, comment_line[0..colon_index], &std.ascii.whitespace);
            const prop_value = std.mem.trim(u8, comment_line[colon_index + 1 ..], &std.ascii.whitespace);

            if (std.mem.eql(u8, prop_name, "align")) {
                if (std.ascii.eqlIgnoreCase(prop_value, "center")) {
                    current_style.ali = .Center;
                } else if (std.ascii.eqlIgnoreCase(prop_value, "left")) {
                    current_style.ali = .Left;
                } else if (std.ascii.eqlIgnoreCase(prop_value, "right")) {
                    current_style.ali = .Right;
                } else {
                    log.warn("unknown align: `{s}`", .{prop_value});
                }
            } else if (std.mem.eql(u8, prop_name, "suffix")) {
                current_style.suffix = try allocator.alloc.dupe(u8, prop_value);
            } else if (std.mem.eql(u8, prop_name, "prefix")) {
                current_style.prefix = try allocator.alloc.dupe(u8, prop_value);
            } else if (std.mem.eql(u8, prop_name, "scale")) {
                current_style.scale = std.fmt.parseFloat(f32, prop_value) catch {
                    log.warn("cannot parse style scale: f32({s})", .{prop_value});
                    continue;
                };
            } else if (std.mem.eql(u8, prop_name, "color")) {
                if (prop_value.len == 6) {
                    current_style.color = Color.parseColor(prop_value[0..6].*) catch {
                        log.warn("cannot parse style color: Color({s})", .{prop_value});
                        continue;
                    };
                } else {
                    log.warn("cannot parse style color: Color({s})", .{prop_value});
                }
            } else {
                log.warn("unknown style prop: `{s}`", .{prop_name});
            }
        }
    }

    pub fn resetStyles(self: *Self) !void {
        var copy = try self.styles.clone();
        defer copy.deinit();

        self.styles.clearAndFree();
        var style_iter = copy.iterator();
        while (style_iter.next()) |style| {
            if (style.value_ptr.locked) {
                try self.styles.put(style.key_ptr.*, style.value_ptr.*);
            } else {
                style.value_ptr.deinit();
                allocator.alloc.free(style.key_ptr.*);
            }
        }

        try self.styles.put("", .{ .locked = true });
    }

    pub fn saveDialog(self: *Self, output_data: []const u8, name: []const u8) !void {
        const output = try allocator.alloc.create([]const u8);
        output.* = output_data;

        const home = try files.FolderLink.resolve(.home);

        const adds = try allocator.alloc.create(Popup.Data.textpick.PopupTextPick);
        adds.* = .{
            .text = try std.mem.concat(allocator.alloc, u8, &.{ home.name, name }),
            .data = @as(*anyopaque, @ptrCast(output)),
            .submit = &submit,
            .prompt = try allocator.alloc.dupe(u8, "Pick a path to save the file"),
        };

        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
            .popup = .atlas("win", .{
                .title = "Save As",
                .source = .{ .w = 1, .h = 1 },
                .pos = Rect.initCentered(self.bnds, 350, 125),
                .contents = Popup.Data.PopupContents.init(adds),
            }),
        });
    }

    pub fn submit(file: []const u8, submit_data: *anyopaque) !void {
        const conts: *[]const u8 = @ptrCast(@alignCast(submit_data));

        const root = try files.FolderLink.resolve(.root);
        try root.newFile(file);

        const target = try root.getFile(file);
        try target.write(conts.*, null);

        allocator.alloc.free(conts.*);
        allocator.alloc.destroy(conts);
    }

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        self.bnds = bnds.*;

        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 40,
            };
        }

        if (self.scroll_top) {
            props.scroll.?.value = 0;
            self.scroll_top = false;
        }

        if (self.scroll_link) {
            self.link_lock.lock();
            defer self.link_lock.unlock();
            if (self.highlight_idx != 0)
                props.scroll.?.value = std.math.clamp(self.links.items[self.highlight_idx - 1].pos.y - (bnds.h / 2), 0, props.scroll.?.maxy);
            self.scroll_link = false;
        }

        if (!self.loading) drawConts: {
            if (self.load_thread) |load_thread| {
                load_thread.join();
                self.load_thread = null;
            }

            const web_width = bnds.w - 14;

            var pos = Vec2{ .y = -props.scroll.?.value + 50 };

            if (self.conts == null) {
                self.load_thread = try std.Thread.spawn(.{}, loadPage, .{self});

                break :drawConts;
            }

            const cont = self.conts orelse "Error Loading Page";

            var iter = std.mem.splitScalar(u8, cont, '\n');

            var texid = [_]u8{ 'w', 'e', 'b', '_', 0, 0 };
            texid[4] = 0;
            texid[5] = self.web_idx;

            // draw text
            while (iter.next()) |full_line| {
                if (std.mem.startsWith(u8, full_line, "#")) {
                    continue;
                }

                var line = full_line;
                var style: Style = self.styles.get("") orelse .{};

                if (line.len > 1 and line[0] == ':' and std.mem.containsAtLeast(u8, line, 2, ":")) {
                    const end_idx = (std.mem.indexOf(u8, line[1..], ":") orelse unreachable) + 1;
                    const style_name = line[1..end_idx];

                    if (self.styles.get(style_name)) |style_data| {
                        style = style_data;
                        line = line[end_idx + 1 ..];
                        line = std.mem.trim(u8, line, &std.ascii.whitespace);
                    }
                }

                if (std.mem.startsWith(u8, line, "- ") and std.mem.endsWith(u8, line, " -")) {
                    style.scale *= 3.0;
                    line = line[2 .. line.len - 2];
                }

                if (std.mem.startsWith(u8, line, "-- ") and std.mem.endsWith(u8, line, " --")) {
                    style.scale *= 2.0;
                    line = line[3 .. line.len - 3];
                }

                if (std.mem.startsWith(u8, line, "[") and std.mem.endsWith(u8, line, "]")) {
                    if (self.add_imgs) {
                        try TextureManager.instance.putMem(&texid, @embedFile("../images/error.eia"));

                        TextureManager.instance.get(&texid).?.size =
                            TextureManager.instance.get(&texid).?.size.div(4);

                        const img_thread = try std.Thread.spawn(.{}, loadimage, .{ self, try self.path.child(line[1 .. line.len - 1]), try allocator.alloc.dupe(u8, &texid) });
                        img_thread.detach();
                    }

                    const size = TextureManager.instance.get(&texid).?.size.mul(2 * style.scale);

                    switch (style.ali) {
                        .Center => {
                            const x = (web_width - size.x) / 2;

                            try SpriteBatch.global.draw(Sprite, &.atlas(&texid, .{
                                .source = .{ .w = 1, .h = 1 },
                                .size = size,
                            }), self.shader, .{ .x = bnds.x + 6 + x, .y = bnds.y + 6 + pos.y });
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Left => {
                            try SpriteBatch.global.draw(Sprite, &.atlas(&texid, .{
                                .source = .{ .w = 1, .h = 1 },
                                .size = size,
                            }), self.shader, .{ .x = bnds.x + 6 + pos.x, .y = bnds.y + 6 + pos.y });
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Right => {
                            const x = web_width - size.x;

                            try SpriteBatch.global.draw(Sprite, &.atlas(&texid, .{
                                .source = .{ .w = 1, .h = 1 },
                                .size = size,
                            }), self.shader, .{ .x = bnds.x + 6 + x, .y = bnds.y + 6 + pos.y });
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                    }
                    continue;
                }

                if (std.mem.startsWith(u8, line, "|")) {
                    line = line[1..];
                }

                if (std.mem.startsWith(u8, line, "> ")) {
                    style.color = .{ .r = 0, .g = 0, .b = 1 };
                    const linkcont = line[2..];
                    const linkidx = std.mem.indexOf(u8, linkcont, ":") orelse 0;

                    line = linkcont[0..linkidx];
                    line = std.mem.trim(u8, line, &std.ascii.whitespace);

                    if (self.add_links) {
                        const url = try allocator.alloc.dupe(u8, std.mem.trim(u8, linkcont[linkidx + 1 ..], &std.ascii.whitespace));
                        const size = font.sizeText(.{ .text = line, .scale = style.scale });

                        self.link_lock.lock();
                        defer self.link_lock.unlock();

                        switch (style.ali) {
                            .Left => {
                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = .{ .x = pos.x, .y = 2 + pos.y + props.scroll.?.value, .w = size.x + 4, .h = size.y + 2 },
                                };
                                try self.links.append(link);
                            },
                            .Center => {
                                const x = (web_width - size.x) / 2;

                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = .{ .x = x, .y = 2 + pos.y + props.scroll.?.value, .w = size.x + 4, .h = size.y + 2 },
                                };
                                try self.links.append(link);
                            },
                            .Right => {
                                const x = (web_width - size.x) - 7;

                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = .{ .x = x, .y = 2 + pos.y + props.scroll.?.value, .w = size.x + 4, .h = size.y + 2 },
                                };
                                try self.links.append(link);
                            },
                        }
                    }
                }

                const aline = try std.mem.concat(allocator.alloc, u8, &.{
                    style.prefix orelse "",
                    line,
                    style.suffix orelse "",
                });
                defer allocator.alloc.free(aline);

                const size = font.sizeText(.{ .text = aline, .scale = style.scale, .wrap = web_width });

                if (pos.y > 0 and pos.y + size.y - 20 < bnds.h) {
                    switch (style.ali) {
                        .Left => {
                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = .{ .x = bnds.x + 6 + pos.x, .y = bnds.y + 6 + pos.y },
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = web_width,
                            });
                        },
                        .Center => {
                            const x = (web_width - size.x) / 2;

                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = .{ .x = bnds.x + x, .y = bnds.y + 6 + pos.y },
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = web_width,
                            });
                        },
                        .Right => {
                            const x = (web_width - size.x);

                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = .{ .x = bnds.x + x, .y = bnds.y + 6 + pos.y },
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = web_width,
                            });
                        },
                    }
                }

                pos.y += size.y;
                pos.x = 0;
            }

            props.scroll.?.maxy = pos.y + 64 + props.scroll.?.value - bnds.h;

            // draw highlight for url
            if (self.highlight_idx != 0 and self.links.items.len >= self.highlight_idx) {
                const hlpos = self.links.items[self.highlight_idx - 1].pos;

                self.highlight.data.size.x = hlpos.w;
                self.highlight.data.size.y = hlpos.h;

                self.highlight.data.color = .{ .r = 0, .g = 0, .b = 1, .a = 0.75 };

                try SpriteBatch.global.draw(Sprite, &self.highlight, self.shader, .{ .x = hlpos.x + bnds.x, .y = hlpos.y + bnds.y - props.scroll.?.value + 4 });
            }

            self.add_links = false;
            self.add_imgs = false;
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try SpriteBatch.global.draw(Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 76;
        self.text_box[1].data.size.x = bnds.w - 80;
        try SpriteBatch.global.draw(Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 72, .y = bnds.y + 2 });
        try SpriteBatch.global.draw(Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 74, .y = bnds.y + 4 });

        const text = try std.fmt.allocPrint(allocator.alloc, "{c}{s}:{s}", .{ @as(u8, @intFromEnum(self.path.kind)), self.path.domain, self.path.path });
        defer allocator.alloc.free(text);

        const tmp = SpriteBatch.global.scissor;
        SpriteBatch.global.scissor = .{ .x = bnds.x + 34, .y = bnds.y + 4, .w = bnds.w - 8 - 32, .h = 28 };
        try font.draw(.{
            .shader = font_shader,
            .text = text,
            .pos = .{ .x = bnds.x + 82, .y = bnds.y + 8 },
            .wrap = bnds.w - 90,
            .maxlines = 1,
        });
        SpriteBatch.global.scissor = tmp;

        try SpriteBatch.global.draw(Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
        try SpriteBatch.global.draw(Sprite, &self.icons[1], self.shader, .{ .x = bnds.x + 38, .y = bnds.y + 2 });
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        for (self.links.items, 0..) |link, idx| {
            if (link.pos.contains(.{ .x = x, .y = y })) {
                self.highlight_idx = idx + 1;
                return;
            }
        }
        self.highlight_idx = 0;
    }

    pub fn back(self: *Self, force: bool) !void {
        if (self.loading and !force) return;

        if (self.hist.pop()) |last| {
            self.path.deinit();

            self.path = last;
            if (self.conts) |conts| {
                allocator.alloc.free(conts);
                self.conts = null;
            }

            self.resetLinks();

            self.highlight_idx = 0;
            self.scroll_top = true;
        } else {
            self.conts = try allocator.alloc.dupe(u8, "Error: No more history");
        }
    }

    // TODO: BUG possible leak
    pub fn followLink(self: *Self) !void {
        if (self.add_links) return;

        if (self.highlight_idx == 0) return;

        try self.hist.append(self.path);

        const targ = self.links.items[self.highlight_idx - 1].url;

        if (self.path.child(targ)) |child| {
            self.path = child;
        } else |err| {
            self.path = try self.path.dupe();
            std.log.warn("{} bad sub path '{}'/'{s}'", .{ err, self.path, targ });
        }

        if (self.conts) |conts| {
            allocator.alloc.free(conts);
            self.conts = null;
        }

        self.highlight_idx = 0;
        self.scroll_top = true;
    }

    pub fn click(self: *Self, _: Vec2, pos: Vec2, btn: ?i32) !void {
        if (btn == null) return;

        if (pos.y < 40) {
            if ((Rect{ .w = 38, .h = 40 }).contains(pos)) {
                try self.back(false);
            }

            if ((Rect{ .x = 38, .w = 38, .h = 40 }).contains(pos)) {
                if (self.conts) |conts| {
                    if (!self.loading) {
                        allocator.alloc.free(conts);
                        self.conts = null;
                        self.scroll_top = true;
                    }
                }
            }

            return;
        } else {
            try self.followLink();
        }
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_BACKSPACE => {
                try self.back(true);
                return;
            },
            c.GLFW_KEY_TAB => {
                if (mods == c.GLFW_MOD_SHIFT) {
                    self.highlight_idx -= 1;
                } else {
                    self.highlight_idx += 1;
                }

                if (self.highlight_idx > self.links.items.len)
                    self.highlight_idx = 1;
                if (self.highlight_idx < 1)
                    self.highlight_idx = self.links.items.len;

                self.scroll_link = true;

                return;
            },
            c.GLFW_KEY_ENTER => {
                try self.followLink();
            },
            else => {},
        }
    }

    pub fn moveResize(self: *Self, _: Rect) !void {
        if (self.loading) return;

        self.resetLinks();
    }

    pub fn deinit(self: *Self) void {
        {
            self.image_lock.lock();
            defer self.image_lock.unlock();
        }

        // self.http.cancel();
        // self.http.deinit();

        if (self.load_thread) |load_thread| {
            std.Thread.join(load_thread);
        }

        // styles
        var styleIter = self.styles.iterator();
        while (styleIter.next()) |style| {
            if (!style.value_ptr.locked) {
                style.value_ptr.deinit();
                allocator.alloc.free(style.key_ptr.*);
            }
        }

        self.path.deinit();

        self.styles.deinit();

        if (self.conts) |conts| {
            allocator.alloc.free(conts);
        }

        // links
        if (!self.add_links) {
            for (self.links.items) |link| {
                allocator.alloc.free(link.url);
            }

            self.links.deinit();
        }

        for (self.hist.items) |h|
            h.deinit();

        self.hist.deinit();

        // self
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.alloc.create(WebData);

    log.debug("opening web homepage {s}", .{config.SettingManager.instance.get("web_home") orelse "@sandeee.prestosilver.info:/index.edf"});

    self.* = .{
        .highlight = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 2, .y = 28 },
        }),
        .menubar = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .size = .{ .y = 40 },
        }),
        .text_box = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 32 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 28 },
            }),
        },
        .icons = .{
            .atlas("icons", .{
                .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            }),
            .atlas("icons", .{
                .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            }),
        },
        .path = Url.parse(config.SettingManager.instance.get("web_home") orelse "@sandeee.prestosilver.info:/index.edf") catch
            try Url.parse("@sandeee.prestosilver.info:/index.edf"),
        .conts = null,
        .shader = shader,
        .links = .init(allocator.alloc),
        .hist = .init(allocator.alloc),
        .web_idx = web_idx,
        .styles = .init(allocator.alloc),
        // .http = try HttpClient.init(allocator.alloc),
    };

    web_idx += 1;

    try self.styles.put("center", .{
        .ali = .Center,
        .locked = true,
    });

    try self.styles.put("left", .{
        .ali = .Left,
        .locked = true,
    });

    try self.styles.put("right", .{
        .ali = .Right,
        .locked = true,
    });

    return .init(self, "web", "Xplorer", .{ .r = 1, .g = 1, .b = 1 });
}
