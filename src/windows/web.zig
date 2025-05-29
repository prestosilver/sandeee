const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const files = @import("../system/files.zig");
const tex = @import("../util/texture.zig");
const window_events = @import("../events/window.zig");
const events = @import("../util/events.zig");
const popups = @import("../drawers/popup2d.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");
const texture_manager = @import("../util/texmanager.zig");
const HttpClient = @import("../util/http.zig");
const log = @import("../util/log.zig").log;

const steam = @import("steam");
const options = @import("options");

const HEADER_SIZE = 1024;
var web_idx: u8 = 0;

pub const WebData = struct {
    const Self = @This();

    const UrlKind = enum(u8) {
        Steam = '$',
        Web = '@',
        Local = '/',
        _,
    };

    pub fn getConts(self: *Self, in_path: []const u8) ![]const u8 {
        var path = try allocator.alloc.dupe(u8, in_path);
        defer allocator.alloc.free(path);

        if (@as(UrlKind, @enumFromInt(in_path[0])) != .Local and std.mem.indexOf(u8, in_path, ":") == null) {
            allocator.alloc.free(path);
            const idx = std.mem.indexOf(u8, self.path, ":") orelse 0;

            path = try std.fmt.allocPrint(allocator.alloc, "{s}:{s}", .{ self.path[0..idx], in_path[1..] });
        }

        log.debug("web load: {s}", .{path});

        switch (@as(UrlKind, @enumFromInt(path[0]))) {
            .Steam => {
                if (options.IsSteam) {
                    const idx = std.mem.indexOf(u8, path, ":") orelse {
                        return try allocator.alloc.dupe(u8, "Error: Bad Remote");
                    };

                    const root = path[1..idx];
                    const sub = path[idx + 1 ..];
                    if (std.mem.eql(u8, root, "list")) {
                        const page_idx = try std.fmt.parseInt(u32, sub, 0);
                        return try steamList(page_idx);
                    } else if (std.mem.eql(u8, root, "item")) {
                        const slash_idx = std.mem.indexOf(u8, sub, "/");

                        var tmp_path: []const u8 = "/";
                        var page_idx = sub;

                        if (slash_idx) |slash| {
                            page_idx = sub[0..slash];
                            tmp_path = sub[slash + 1 ..];
                        }

                        return steamItem(.{ .data = std.fmt.parseInt(u64, page_idx, 10) catch {
                            return try allocator.alloc.dupe(u8, "Error: Invalid list page");
                        } }, path, tmp_path) catch |err| {
                            return try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                        };
                    } else {
                        return try allocator.alloc.dupe(u8, "Error: Bad steam link");
                    }
                } else {
                    return try allocator.alloc.dupe(u8, "Error: Steam is not enabled");
                }
            },
            .Local => {
                const root = try files.FolderLink.resolve(.root);
                const file = try root.getFile(path);
                return try allocator.alloc.dupe(u8, try file.read(null));
            },
            .Web => {
                // const result = self.http.fetch() catch |err| {
                //     return switch (err) {};
                // };

                // return try allocator.alloc.dupe(u8, result);

                const idx = std.mem.indexOf(u8, path, ":") orelse {
                    return try allocator.alloc.dupe(u8, "Error: Bad Remote");
                };

                var client = std.http.Client{ .allocator = allocator.alloc };
                defer client.deinit();

                const uri = std.Uri{
                    .scheme = "http",
                    .user = null,
                    .password = null,
                    .host = .{ .raw = path[1..idx] },
                    .port = 80,
                    .path = .{ .raw = path[idx + 1 ..] },
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

                const fconts = try req.reader().readAllAlloc(allocator.alloc, req.response.content_length orelse {
                    return try std.fmt.allocPrint(allocator.alloc, "Error: cant read from stream", .{});
                });
                defer allocator.alloc.free(fconts);

                return try allocator.alloc.dupe(u8, fconts);
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
        pos: rect.Rectangle,
    };

    pub const Style = struct {
        pub const Align = enum {
            Left,
            Center,
            Right,
        };

        ali: Align = .Left,
        scale: f32 = 1.0,
        color: col.Color = .{ .r = 0, .g = 0, .b = 0 },
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

    highlight: sprite.Sprite,
    menubar: sprite.Sprite,
    text_box: [2]sprite.Sprite,
    icons: [2]sprite.Sprite,
    path: []u8,

    shader: *shd.Shader,
    conts: ?[]const u8,
    links: std.ArrayList(WebLink),
    hist: std.ArrayList([]u8),

    scroll_top: bool = false,
    scroll_link: bool = false,

    highlight_idx: usize = 0,
    loading: bool = false,
    add_imgs: bool = false,
    add_links: bool = false,
    web_idx: u8,

    bnds: rect.Rectangle = undefined,

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

    pub fn steamList(page: u32) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const query = ugc.createQueryRequest(.RankedByVote, 0, steam.NO_APP_ID, steam.STEAM_APP_ID, page + 1);
        const handle = ugc.sendQueryRequest(query);
        const steam_utils = steam.getSteamUtils();

        var failed = true;
        while (!steam_utils.isCallComplete(handle, &failed)) {
            std.time.sleep(200_000_000);
        }

        if (failed) {
            return try std.fmt.allocPrint(allocator.alloc, "{}", .{failed});
        }

        const details: *steam.UGCDetails = try allocator.alloc.create(steam.UGCDetails);
        defer allocator.alloc.destroy(details);

        const prev = try std.fmt.allocPrint(allocator.alloc, "> prev: $list:{}\n", .{if (page == 0) 0 else page - 1});
        const next = try std.fmt.allocPrint(allocator.alloc, "> next: $list:{}\n", .{page + 1});
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
            if (details.visible != 0) continue;

            added = true;

            if (steam.fake_api) {
                const old = conts;
                defer allocator.alloc.free(old);

                const title_text = try std.fmt.allocPrint(allocator.alloc, "--- {s} ---", .{details.title});
                defer allocator.alloc.free(title_text);

                const desc_text = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item:{}", .{ details.desc, details.file_id.data });
                defer allocator.alloc.free(desc_text);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, title_text, "\n", desc_text, "\n\n" });
            } else {
                const old = conts;
                defer allocator.alloc.free(old);

                const title: [*:0]u8 = @ptrCast(&details.title);

                const title_text = try std.fmt.allocPrint(allocator.alloc, "--- {s} ---", .{title[0..std.mem.len(title)]});
                defer allocator.alloc.free(title_text);

                const desc: [*:0]u8 = @ptrCast(&details.desc);
                const desc_text = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item:{}", .{ desc[0..std.mem.len(desc)], details.file_id.data });
                defer allocator.alloc.free(desc_text);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, title_text, "\n", desc_text, "\n\n" });
            }
        }

        _ = ugc.releaseQueryResult(query);

        if (!added) {
            const old = conts;
            defer allocator.alloc.free(old);

            conts = try std.mem.concat(allocator.alloc, u8, &.{ old, "\n-- No Results --\n> Page 1: $list:0\n\n" });
        }

        {
            const old = conts;
            defer allocator.alloc.free(old);

            conts = try std.mem.concat(allocator.alloc, u8, &.{ old, nav });
        }

        return conts;
    }

    pub fn steamItem(id: steam.SteamPubFileId, parent: []const u8, path: []const u8) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const BUFFER_SIZE = 256;

        var size: u64 = undefined;
        var folder = [_]u8{0} ** (BUFFER_SIZE + 1);
        var timestamp: u32 = undefined;

        if (!ugc.getItemInstallInfo(id, &size, &folder, &timestamp)) {
            if (!ugc.downloadItem(id, true)) {
                return try std.fmt.allocPrint(allocator.alloc, "Error: Failed to load page {}.", .{id});
            }

            while (!ugc.getItemInstallInfo(id, &size, &folder, &timestamp)) {
                std.time.sleep(200_000_000);
            }
        }

        const folder_pointer = folder[0..std.mem.len(@as([*:0]u8, @ptrCast(&folder)))];

        const file_path = try std.fmt.allocPrint(allocator.alloc, "{s}/{s}", .{ folder_pointer, path });
        defer allocator.alloc.free(file_path);

        log.debug("file_path: {s}", .{file_path});

        const walker = std.fs.openDirAbsolute(file_path, .{ .iterate = true }) catch {
            const file = try std.fs.openFileAbsolute(file_path, .{});
            defer file.close();
            const conts = try file.reader().readAllAlloc(allocator.alloc, 100_000_000);
            defer allocator.alloc.free(conts);

            const cont = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, conts, "\r", ""));
            _ = std.mem.replace(u8, conts, "\r", "", cont);

            return cont;
        };

        if (walker.access("index.edf", .{})) {
            const file = try walker.openFile("index.edf", .{});
            defer file.close();
            const conts = try file.reader().readAllAlloc(allocator.alloc, 100_000_000);
            defer allocator.alloc.free(conts);

            const cont = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, conts, "\r", ""));
            _ = std.mem.replace(u8, conts, "\r", "", cont);

            return cont;
        } else |_| {
            var iter = walker.iterate();

            var conts = try std.fmt.allocPrint(allocator.alloc, "Contents of {s}", .{path});

            while (try iter.next()) |item| {
                const old = conts;
                defer allocator.alloc.free(old);

                conts = try std.fmt.allocPrint(allocator.alloc, "{s}\n> {s}: {s}/{s}", .{ old, item.name, parent, item.name });
            }

            return conts;
        }
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

        if (std.mem.containsAtLeast(u8, self.path, 1, ".") and !std.mem.endsWith(u8, self.path, ".edf")) {
            const fconts = try self.getConts(self.path);
            defer allocator.alloc.free(fconts);

            try self.saveDialog(try allocator.alloc.dupe(u8, fconts), self.path[(std.mem.lastIndexOf(u8, self.path, "/") orelse 0) + 1 ..]);

            try self.back(true);
            return;
        }

        self.conts = try self.getConts(self.path);

        var iter = std.mem.splitScalar(u8, self.conts.?, '\n');

        while (iter.next()) |fullLine| {
            if (std.mem.startsWith(u8, fullLine, "#Style ")) {
                try self.loadStyle(fullLine["#Style ".len..]);
            }
        }
    }

    pub fn loadimage(self: *Self, path: []const u8, target: []const u8) !void {
        self.image_lock.lock();
        defer self.image_lock.unlock();

        defer allocator.alloc.free(target);
        defer allocator.alloc.free(path);
        const fconts = try self.getConts(path);
        defer allocator.alloc.free(fconts);

        const texture = texture_manager.TextureManager.instance.get(target).?;

        try texture.loadMem(fconts);
        try texture.upload();

        self.resetLinks();
    }

    pub fn loadStyle(self: *Self, url: []const u8) !void {
        const fconts = try self.getConts(url);
        defer allocator.alloc.free(fconts);

        var iter = std.mem.splitScalar(u8, fconts, '\n');
        var current_style: *Style = self.styles.getPtr("") orelse unreachable;

        while (iter.next()) |fullLine| {
            if (std.mem.startsWith(u8, fullLine, "#")) {
                try self.styles.put(try allocator.alloc.dupe(u8, fullLine[1..]), .{});
                current_style = self.styles.getPtr(fullLine[1..]) orelse unreachable;
            }
            if (std.mem.startsWith(u8, fullLine, "align: ")) {
                if (std.mem.eql(u8, fullLine, "align: Center")) {
                    current_style.ali = .Center;
                }
                if (std.mem.eql(u8, fullLine, "align: Left")) {
                    current_style.ali = .Left;
                }
                if (std.mem.eql(u8, fullLine, "align: Right")) {
                    current_style.ali = .Right;
                }
            }
            if (std.mem.startsWith(u8, fullLine, "suffix: ")) {
                current_style.suffix = try allocator.alloc.dupe(u8, fullLine[8..]);
            }
            if (std.mem.startsWith(u8, fullLine, "prefix: ")) {
                current_style.prefix = try allocator.alloc.dupe(u8, fullLine[8..]);
            }
            if (std.mem.startsWith(u8, fullLine, "scale: ")) {
                current_style.scale = std.fmt.parseFloat(f32, fullLine["scale: ".len..]) catch 1.0;
            }
            if (std.mem.startsWith(u8, fullLine, "color: ")) {
                const buf = fullLine["color: ".len..];
                current_style.color = if (buf.len > 6)
                    .{ .r = 1, .g = 0, .b = 0 }
                else
                    col.Color.parseColor(buf[0..6].*) catch
                        .{ .r = 1, .g = 0, .b = 0 };
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

        const adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
        adds.* = .{
            .text = try std.mem.concat(allocator.alloc, u8, &.{ home.name, name }),
            .data = @as(*anyopaque, @ptrCast(output)),
            .submit = &submit,
            .prompt = try allocator.alloc.dupe(u8, "Pick a path to save the file"),
        };

        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
            .popup = .{
                .texture = "win",
                .data = .{
                    .title = "Save As",
                    .source = .{ .w = 1, .h = 1 },
                    .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                    .contents = popups.PopupData.PopupContents.init(adds),
                },
            },
        });
    }

    pub fn submit(file: []const u8, data: *anyopaque) !void {
        const conts: *[]const u8 = @ptrCast(@alignCast(data));

        const root = try files.FolderLink.resolve(.root);
        try root.newFile(file);

        const target = try root.getFile(file);
        try target.write(conts.*, null);

        allocator.alloc.free(conts.*);
        allocator.alloc.destroy(conts);
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
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

            var pos = vecs.Vector2{ .y = -props.scroll.?.value + 50 };

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
                        try texture_manager.TextureManager.instance.putMem(&texid, @embedFile("../images/error.eia"));

                        texture_manager.TextureManager.instance.get(&texid).?.size =
                            texture_manager.TextureManager.instance.get(&texid).?.size.div(4);

                        const img_thread = try std.Thread.spawn(.{}, loadimage, .{ self, try allocator.alloc.dupe(u8, line[1 .. line.len - 1]), try allocator.alloc.dupe(u8, &texid) });
                        img_thread.detach();
                    }

                    const size = texture_manager.TextureManager.instance.get(&texid).?.size.mul(2 * style.scale);

                    switch (style.ali) {
                        .Center => {
                            const x = (web_width - size.x) / 2;

                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = .{ .w = 1, .h = 1 },
                                    .size = size,
                                },
                            }, self.shader, .{ .x = bnds.x + 6 + x, .y = bnds.y + 6 + pos.y });
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Left => {
                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = .{ .w = 1, .h = 1 },
                                    .size = size,
                                },
                            }, self.shader, .{ .x = bnds.x + 6 + pos.x, .y = bnds.y + 6 + pos.y });
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Right => {
                            const x = web_width - size.x;

                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = .{ .w = 1, .h = 1 },
                                    .size = size,
                                },
                            }, self.shader, .{ .x = bnds.x + 6 + x, .y = bnds.y + 6 + pos.y });
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

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.highlight, self.shader, .{ .x = hlpos.x + bnds.x, .y = hlpos.y + bnds.y - props.scroll.?.value + 4 });
            }

            self.add_links = false;
            self.add_imgs = false;
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.menubar, self.shader, .{ .x = bnds.x, .y = bnds.y });

        self.text_box[0].data.size.x = bnds.w - 76;
        self.text_box[1].data.size.x = bnds.w - 80;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, .{ .x = bnds.x + 72, .y = bnds.y + 2 });
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, .{ .x = bnds.x + 74, .y = bnds.y + 4 });

        const tmp = batch.SpriteBatch.instance.scissor;
        batch.SpriteBatch.instance.scissor = .{ .x = bnds.x + 34, .y = bnds.y + 4, .w = bnds.w - 8 - 32, .h = 28 };
        try font.draw(.{
            .shader = font_shader,
            .text = self.path,
            .pos = .{ .x = bnds.x + 82, .y = bnds.y + 8 },
            .wrap = bnds.w - 90,
            .maxlines = 1,
        });
        batch.SpriteBatch.instance.scissor = tmp;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[0], self.shader, .{ .x = bnds.x + 2, .y = bnds.y + 2 });
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[1], self.shader, .{ .x = bnds.x + 38, .y = bnds.y + 2 });
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
            allocator.alloc.free(self.path);

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
        if (self.highlight_idx == 0) return;

        var last_host: []const u8 = "";
        if (std.mem.indexOf(u8, self.path, ":")) |idx|
            last_host = self.path[0..idx];

        try self.hist.append(self.path);

        const targ = self.links.items[self.highlight_idx - 1].url;

        if (std.mem.indexOf(u8, targ, ":") == null) {
            self.path = try std.fmt.allocPrint(allocator.alloc, "{s}:{s}", .{ last_host, targ[1..] });
        } else {
            self.path = try allocator.alloc.dupe(u8, targ);
        }

        if (self.conts) |conts| {
            allocator.alloc.free(conts);
            self.conts = null;
        }

        self.highlight_idx = 0;
        self.scroll_top = true;
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        if (pos.y < 40) {
            if ((rect.Rectangle{ .w = 38, .h = 40 }).contains(pos)) {
                try self.back(false);
            }

            if ((rect.Rectangle{ .x = 38, .w = 38, .h = 40 }).contains(pos)) {
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

    pub fn moveResize(self: *Self, _: rect.Rectangle) !void {
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

        allocator.alloc.free(self.path);

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

        for (self.hist.items) |h| {
            allocator.alloc.free(h);
        }

        self.hist.deinit();

        // self
        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(WebData);

    log.info("{s}", .{conf.SettingManager.instance.get("web_home") orelse "@sandeee.prestosilver.info:/index.edf"});

    self.* = .{
        .highlight = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 28 },
            },
        },
        .menubar = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
                .size = .{ .y = 40 },
            },
        },
        .text_box = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 32 },
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 28 },
                },
            },
        },
        .icons = .{
            .{
                .texture = "icons",
                .data = .{
                    .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 32, .y = 32 },
                },
            },
            .{
                .texture = "icons",
                .data = .{
                    .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 32, .y = 32 },
                },
            },
        },
        .path = try allocator.alloc.dupe(u8, conf.SettingManager.instance.get("web_home") orelse "@sandeee.prestosilver.info:/index.edf"),
        .conts = null,
        .shader = shader,
        .links = std.ArrayList(WebData.WebLink).init(allocator.alloc),
        .hist = std.ArrayList([]u8).init(allocator.alloc),
        .web_idx = web_idx,
        .styles = std.StringArrayHashMap(WebData.Style).init(allocator.alloc),
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

    return win.WindowContents.init(self, "web", "Xplorer", .{ .r = 1, .g = 1, .b = 1 });
}
