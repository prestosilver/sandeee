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
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");
const popups = @import("../drawers/popup2d.zig");
const gfx = @import("../util/graphics.zig");
const conf = @import("../system/config.zig");
const c = @import("../c.zig");
const texMan = @import("../util/texmanager.zig");
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

        if (std.mem.indexOf(u8, in_path, ":") == null) {
            allocator.alloc.free(path);
            const idx = std.mem.indexOf(u8, self.path.?, ":") orelse 0;

            path = try std.fmt.allocPrint(allocator.alloc, "{s}:{s}", .{ self.path.?[0..idx], in_path[1..] });
        }

        log.info("load: {s}", .{path});

        switch (@as(UrlKind, @enumFromInt(path[0]))) {
            .Steam => {
                if (options.IsSteam) {
                    const idx = std.mem.indexOf(u8, path, ":") orelse {
                        return try allocator.alloc.dupe(u8, "Bad Remote");
                    };

                    const root = path[1..idx];
                    const sub = path[idx + 1 ..];
                    if (std.mem.eql(u8, root, "list")) {
                        const pageIdx = try std.fmt.parseInt(u32, sub, 0);
                        return try steamList(pageIdx);
                    } else if (std.mem.eql(u8, root, "item")) {
                        const slashIdx = std.mem.indexOf(u8, sub, "/");

                        var tmp_path: []const u8 = "/";
                        var page_idx = sub;

                        if (slashIdx) |slash| {
                            page_idx = sub[0..slash];
                            tmp_path = sub[slash + 1 ..];
                        }

                        return steamItem(try std.fmt.parseInt(u64, page_idx, 10), path, tmp_path) catch |err| {
                            return try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                        };
                    } else {
                        return try allocator.alloc.dupe(u8, "Error: Bad Remote");
                    }
                } else {
                    return try allocator.alloc.dupe(u8, "Error: Steam is not enabled");
                }
            },
            .Local => {
                return try allocator.alloc.dupe(u8, try (try files.root.getFile(path)).read(null));
            },
            .Web => {
                const idx = std.mem.indexOf(u8, path, ":") orelse {
                    return try allocator.alloc.dupe(u8, "Bad Remote");
                };

                var client = std.http.Client{ .allocator = allocator.alloc };
                defer client.deinit();

                const uri = std.Uri{
                    .scheme = "https",
                    .user = null,
                    .password = null,
                    .host = .{ .raw = path[1..idx] },
                    .port = 443,
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
                        try std.fmt.allocPrint(allocator.alloc, "No Internet Connection", .{})
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
        color: col.Color = col.newColor(0, 0, 0, 1),
        locked: bool = false,
        suffix: ?[]const u8 = null,
        prefix: ?[]const u8 = null,

        pub fn free(self: *const Style) void {
            if (self.suffix) |suffix| {
                allocator.alloc.free(suffix);
            }

            if (self.prefix) |prefix| {
                allocator.alloc.free(prefix);
            }
        }
    };

    highlight: sprite.Sprite,
    menubar: sprite.Sprite,
    text_box: [2]sprite.Sprite,
    icons: [2]sprite.Sprite,
    path: ?[]const u8,

    shader: *shd.Shader,
    conts: ?[]const u8,
    links: std.ArrayList(WebLink),
    hist: std.ArrayList([]const u8),

    scroll_top: bool = false,
    scroll_link: bool = false,

    highlight_idx: usize = 0,
    loading: bool = false,
    add_imgs: bool = false,
    add_links: bool = false,
    web_idx: u8,

    bnds: rect.Rectangle = undefined,

    styles: std.StringArrayHashMap(Style),

    pub fn steamList(page: u32) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const query = ugc.createQueryRequest(.RankedByVote, 0, 0, steam.STEAM_APP_ID, page);
        const handle = ugc.sendQueryRequest(query);
        const steamUtils = steam.getSteamUtils();

        var failed = true;
        while (!steamUtils.isCallComplete(handle, &failed)) {
            std.time.sleep(200_000_000);
        }

        if (failed) {
            return try std.fmt.allocPrint(allocator.alloc, "{}", .{failed});
        }

        const details: *steam.UGCDetails = try allocator.alloc.create(steam.UGCDetails);
        defer allocator.alloc.destroy(details);

        var conts = try std.fmt.allocPrint(allocator.alloc, "{}\n> prev: $list:{}\n> next: $list:{}\n", .{ page, page - 1, page + 1 });
        var idx: u32 = 0;

        while (ugc.getQueryResult(query, idx, details)) : (idx += 1) {
            if (details.visible != 0) continue;

            if (steam.fakeApi) {
                const old = conts;
                defer allocator.alloc.free(old);

                const title: [*:0]const u8 = @ptrCast(details.title);

                const titlePrint = try std.fmt.allocPrint(allocator.alloc, "-- {s} --", .{title[0..std.mem.len(title)]});
                defer allocator.alloc.free(titlePrint);

                const desc: [*:0]const u8 = @ptrCast(details.desc);
                const descPrint = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item:{}", .{ desc[0..std.mem.len(desc)], details.fileId });
                defer allocator.alloc.free(descPrint);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, titlePrint, "\n", descPrint, "\n\n" });
            } else {
                const old = conts;
                defer allocator.alloc.free(old);

                const title: [*:0]u8 = @ptrCast(&details.title);

                const titlePrint = try std.fmt.allocPrint(allocator.alloc, "-- {s} --", .{title[0..std.mem.len(title)]});
                defer allocator.alloc.free(titlePrint);

                const desc: [*:0]u8 = @ptrCast(&details.desc);
                const descPrint = try std.fmt.allocPrint(allocator.alloc, "{s}\n> link: $item:{}", .{ desc[0..std.mem.len(desc)], details.fileId });
                defer allocator.alloc.free(descPrint);

                conts = try std.mem.concat(allocator.alloc, u8, &.{ old, titlePrint, "\n", descPrint, "\n\n" });
            }
        }

        _ = ugc.releaseQueryResult(query);

        {
            const old = conts;
            defer allocator.alloc.free(old);

            const footer = try std.fmt.allocPrint(allocator.alloc, "{}\n> prev: $list:{}\n> next: $list:{}", .{ page, page - 1, page + 1 });
            defer allocator.alloc.free(footer);

            conts = try std.mem.concat(allocator.alloc, u8, &.{ old, footer });
        }

        return conts;
    }

    pub fn steamItem(id: u64, parent: []const u8, path: []const u8) ![]const u8 {
        const ugc = steam.getSteamUGC();
        const BUFFER_SIZE = 256;

        var size: u64 = undefined;
        var folder = [_]u8{0} ** (BUFFER_SIZE + 1);
        var timestamp: u32 = undefined;

        if (!ugc.getItemInstallInfo(id, &size, &folder, &timestamp)) {
            if (!ugc.downloadItem(id, true)) {
                return try std.fmt.allocPrint(allocator.alloc, "Failed to load page {}.", .{id});
            }

            while (!ugc.getItemInstallInfo(id, &size, &folder, &timestamp)) {
                std.time.sleep(200_000_000);
            }
        }

        const folderPtr = folder[0..std.mem.len(@as([*:0]u8, @ptrCast(&folder)))];

        const file_path = try std.fmt.allocPrint(allocator.alloc, "{s}/{s}", .{ folderPtr, path });
        defer allocator.alloc.free(file_path);

        log.info("file_path: {s}", .{file_path});

        const walker = std.fs.openDirAbsolute(file_path, .{ .iterate = true }) catch {
            const file = try std.fs.openFileAbsolute(file_path, .{});
            defer file.close();
            const conts = try file.reader().readAllAlloc(allocator.alloc, 100_000_000);

            const cont = try allocator.alloc.alloc(u8, std.mem.replacementSize(u8, conts, "\r", ""));
            _ = std.mem.replace(u8, conts, "\r", "", cont);

            return cont;
        };

        var iter = walker.iterate();

        var conts = try std.fmt.allocPrint(allocator.alloc, "Contents of {s}", .{path});

        while (try iter.next()) |item| {
            const old = conts;
            defer allocator.alloc.free(old);

            conts = try std.fmt.allocPrint(allocator.alloc, "{s}\n> {s}: {s}/{s}", .{ old, item.name, parent, item.name });
        }

        return conts;
    }

    pub fn loadPage(self: *Self) !void {
        if (self.loading) return;

        self.loading = true;
        defer {
            self.loading = false;
            self.add_imgs = true;
            self.add_links = true;
            self.links.clearAndFree();
        }

        try self.resetStyles();

        if (self.path) |path| {
            self.conts = try self.getConts(path);
        }

        var iter = std.mem.split(u8, self.conts orelse return, "\n");

        while (iter.next()) |fullLine| {
            if (std.mem.startsWith(u8, fullLine, "#Style ")) {
                try self.loadStyle(fullLine["#Style ".len..]);
            }
        }
    }

    pub fn loadimage(self: *Self, path: []const u8, target: []const u8) !void {
        defer allocator.alloc.free(target);
        defer allocator.alloc.free(path);
        const fconts = try self.getConts(path);
        defer allocator.alloc.free(fconts);

        const texture = texMan.TextureManager.instance.get(target).?;

        try tex.uploadTextureMem(texture, fconts);

        self.add_links = true;
        self.links.clearAndFree();
    }

        const fconts = try self.getConts(url);
        defer allocator.alloc.free(fconts);

        var iter = std.mem.split(u8, fconts, "\n");
        var currentStyle: *Style = self.styles.getPtr("") orelse unreachable;

        while (iter.next()) |fullLine| {
            if (std.mem.startsWith(u8, fullLine, "#")) {
                try self.styles.put(try allocator.alloc.dupe(u8, fullLine[1..]), .{});
                currentStyle = self.styles.getPtr(fullLine[1..]) orelse unreachable;
            }
            if (std.mem.startsWith(u8, fullLine, "align: ")) {
                if (std.mem.eql(u8, fullLine, "align: Center")) {
                    currentStyle.ali = .Center;
                }
                if (std.mem.eql(u8, fullLine, "align: Left")) {
                    currentStyle.ali = .Left;
                }
                if (std.mem.eql(u8, fullLine, "align: Right")) {
                    currentStyle.ali = .Right;
                }
            }
            if (std.mem.startsWith(u8, fullLine, "suffix: ")) {
                currentStyle.suffix = try allocator.alloc.dupe(u8, fullLine[8..]);
            }
            if (std.mem.startsWith(u8, fullLine, "prefix: ")) {
                currentStyle.prefix = try allocator.alloc.dupe(u8, fullLine[8..]);
            }
            if (std.mem.startsWith(u8, fullLine, "scale: ")) {
                currentStyle.scale = std.fmt.parseFloat(f32, fullLine["scale: ".len..]) catch 1.0;
            }
            if (std.mem.startsWith(u8, fullLine, "color: ")) {
                const val = std.fmt.parseInt(u32, fullLine["color: ".len..], 16) catch 0xFF0000;
                currentStyle.color = col.newColorRGBA(
                    @intCast((val >> 16) & 0xFF),
                    @intCast((val >> 8) & 0xFF),
                    @intCast((val >> 0) & 0xFF),
                    0xFF,
                );
            }
        }
    }

    pub fn resetStyles(self: *Self) !void {
        var copy = try self.styles.clone();
        defer copy.deinit();

        self.styles.clearAndFree();
        var styleIter = copy.iterator();
        while (styleIter.next()) |style| {
            if (style.value_ptr.locked) {
                try self.styles.put(style.key_ptr.*, style.value_ptr.*);
            } else {
                style.value_ptr.free();
                allocator.alloc.free(style.key_ptr.*);
            }
        }

        try self.styles.put("", .{ .locked = true });
    }

    pub fn saveDialog(self: *Self, outputData: []const u8, name: []const u8) !void {
        const output = try allocator.alloc.create([]const u8);
        output.* = outputData;

        const adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
        adds.* = .{
            .text = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ files.home.name, name }),
            .data = @as(*anyopaque, @ptrCast(output)),
            .submit = &submit,
            .prompt = "Pick a path to save the file",
        };

        try events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
            .popup = .{
                .texture = "win",
                .data = .{
                    .title = "Save As",
                    .source = rect.newRect(0, 0, 1, 1),
                    .pos = rect.newRectCentered(self.bnds, 350, 125),
                    .contents = popups.PopupData.PopupContents.init(adds),
                },
            },
        });
    }

    pub fn submit(file: []const u8, data: *anyopaque) !void {
        const conts: *[]const u8 = @ptrCast(@alignCast(data));

        _ = try files.root.newFile(file);
        const target = try files.root.getFile(file);

        try target.write(conts.*, null);

        allocator.alloc.free(conts.*);
        allocator.alloc.destroy(conts);
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        self.bnds = bnds.*;

        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 40,
            };
        }

        if (self.scroll_top) {
            props.scroll.?.value = 0;
            self.scroll_top = false;
        }

        if (self.scroll_link) {
            if (self.highlight_idx != 0)
                props.scroll.?.value = std.math.clamp(self.links.items[self.highlight_idx - 1].pos.y - (bnds.h / 2), 0, props.scroll.?.maxy);
            self.scroll_link = false;
        }

        if (!self.loading) drawConts: {
            const webWidth = bnds.w - 14;

            var pos = vecs.newVec2(0, -props.scroll.?.value + 50);

            if (self.conts == null) {
                _ = try std.Thread.spawn(.{}, loadPage, .{self});
                break :drawConts;
            }

            const cont = self.conts orelse "Error Loading Page";

            var iter = std.mem.split(u8, cont, "\n");

            var texid = [_]u8{ 'w', 'e', 'b', '_', 0, 0 };
            texid[4] = 0;
            texid[5] = self.web_idx;

            // draw text
            while (iter.next()) |fullLine| {
                if (std.mem.startsWith(u8, fullLine, "#")) {
                    continue;
                }

                var line = fullLine;
                var style: Style = self.styles.get("") orelse .{};

                var styleIter = self.styles.iterator();

                while (styleIter.next()) |styleData| {
                    const name = try std.fmt.allocPrint(allocator.alloc, ":{s}:", .{styleData.key_ptr.*});
                    defer allocator.alloc.free(name);
                    if (std.mem.startsWith(u8, fullLine, name)) {
                        style = styleData.value_ptr.*;
                        line = fullLine[name.len..];
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
                        gfx.Context.makeCurrent();
                        defer gfx.Context.makeNotCurrent();

                        try texMan.TextureManager.instance.putMem(&texid, @embedFile("../images/error.eia"));

                        texMan.TextureManager.instance.get(&texid).?.size =
                            texMan.TextureManager.instance.get(&texid).?.size.div(4);

                        _ = try std.Thread.spawn(.{}, loadimage, .{ self, try allocator.alloc.dupe(u8, line[1 .. line.len - 1]), try allocator.alloc.dupe(u8, &texid) });
                    }

                    const size = texMan.TextureManager.instance.get(&texid).?.size.mul(2 * style.scale);

                    switch (style.ali) {
                        .Center => {
                            const x = (webWidth - size.x) / 2;

                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = rect.newRect(0, 0, 1, 1),
                                    .size = size,
                                },
                            }, self.shader, vecs.newVec3(bnds.x + 6 + x, bnds.y + 6 + pos.y, 0));
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Left => {
                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = rect.newRect(0, 0, 1, 1),
                                    .size = size,
                                },
                            }, self.shader, vecs.newVec3(bnds.x + 6 + pos.x, bnds.y + 6 + pos.y, 0));
                            texid[4] += 1;
                            pos.y += size.y;
                        },
                        .Right => {
                            const x = webWidth - size.x;

                            try batch.SpriteBatch.instance.draw(sprite.Sprite, &.{
                                .texture = &texid,
                                .data = .{
                                    .source = rect.newRect(0, 0, 1, 1),
                                    .size = size,
                                },
                            }, self.shader, vecs.newVec3(bnds.x + 6 + x, bnds.y + 6 + pos.y, 0));
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
                    style.color = col.newColor(0, 0, 1, 1);
                    const linkcont = line[2..];
                    const linkidx = std.mem.indexOf(u8, linkcont, ":") orelse 0;
                    line = linkcont[0..linkidx];
                    line = std.mem.trim(u8, line, &std.ascii.whitespace);
                    var url = linkcont[linkidx + 1 ..];
                    url = std.mem.trim(u8, url, &std.ascii.whitespace);
                    const size = font.sizeText(.{ .text = line, .scale = style.scale });

                    if (self.add_links) {
                        switch (style.ali) {
                            .Left => {
                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = rect.newRect(pos.x, 2 + pos.y + props.scroll.?.value, size.x + 4, size.y + 2),
                                };
                                try self.links.append(link);
                            },
                            .Center => {
                                const x = (webWidth - size.x) / 2;

                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = rect.newRect(x, 2 + pos.y + props.scroll.?.value, size.x + 4, size.y + 2),
                                };
                                try self.links.append(link);
                            },
                            .Right => {
                                const x = (webWidth - size.x) - 7;

                                const link = WebData.WebLink{
                                    .url = url,
                                    .pos = rect.newRect(x, 2 + pos.y + props.scroll.?.value, size.x + 4, size.y + 2),
                                };
                                try self.links.append(link);
                            },
                        }
                    }
                }

                const aline = try std.fmt.allocPrint(allocator.alloc, "{s}{s}{s}", .{
                    style.prefix orelse "",
                    line,
                    style.suffix orelse "",
                });
                defer allocator.alloc.free(aline);

                const size = font.sizeText(.{ .text = aline, .scale = style.scale, .wrap = webWidth });

                if (pos.y > 0 and pos.y + size.y - 20 < bnds.h) {
                    switch (style.ali) {
                        .Left => {
                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = vecs.newVec2(bnds.x + 6 + pos.x, bnds.y + 6 + pos.y),
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = webWidth,
                            });
                        },
                        .Center => {
                            const x = (webWidth - size.x) / 2;

                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = vecs.newVec2(bnds.x + x, bnds.y + 6 + pos.y),
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = webWidth,
                            });
                        },
                        .Right => {
                            const x = (webWidth - size.x);

                            try font.draw(.{
                                .shader = font_shader,
                                .text = aline,
                                .pos = vecs.newVec2(bnds.x + x, bnds.y + 6 + pos.y),
                                .color = style.color,
                                .scale = style.scale,
                                .wrap = webWidth,
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

                self.highlight.data.color = col.newColor(0, 0, 1, 0.75);

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.highlight, self.shader, vecs.newVec3(hlpos.x + bnds.x, hlpos.y + bnds.y - props.scroll.?.value + 4, 0));
            }

            self.add_links = false;
            self.add_imgs = false;
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        self.text_box[0].data.size.x = bnds.w - 76;
        self.text_box[1].data.size.x = bnds.w - 80;
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 72, bnds.y + 2, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 74, bnds.y + 4, 0));

        const tmp = batch.SpriteBatch.instance.scissor;
        batch.SpriteBatch.instance.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 8 - 32, 28);
        if (self.path) |file| {
            try font.draw(.{
                .shader = font_shader,
                .text = file,
                .pos = vecs.newVec2(bnds.x + 82, bnds.y + 8),
                .wrap = bnds.w - 90,
                .maxlines = 1,
            });
        } else {
            try font.draw(.{
                .shader = font_shader,
                .text = "Error",
                .pos = vecs.newVec2(bnds.x + 82, bnds.y + 8),
                .wrap = bnds.w - 90,
                .maxlines = 1,
            });
        }
        batch.SpriteBatch.instance.scissor = tmp;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 2, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 38, bnds.y + 2, 0));
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        for (self.links.items, 0..) |link, idx| {
            if (link.pos.contains(vecs.newVec2(x, y))) {
                self.highlight_idx = idx + 1;
                return;
            }
        }
        self.highlight_idx = 0;
    }

    pub fn back(self: *Self, force: bool) !void {
        if (self.loading and !force) return;

        if (self.hist.popOrNull()) |last| {
            self.path = last;
            if (self.conts != null) {
                allocator.alloc.free(self.conts.?);
                self.conts = null;
            }
            self.links.clearAndFree();
            self.highlight_idx = 0;
            self.scroll_top = true;
        }
    }

    // TODO: test memleak
    pub fn followLink(self: *Self) !void {
        if (self.highlight_idx == 0) return;

        var lastHost: []const u8 = "";
        if (std.mem.indexOf(u8, self.path.?, ":")) |idx|
            lastHost = self.path.?[0..idx];

        try self.hist.append(self.path.?);

        const targ = self.links.items[self.highlight_idx - 1].url;

        if (std.mem.indexOf(u8, targ, ":") == null) {
            self.path = try std.fmt.allocPrint(allocator.alloc, "{s}:{s}", .{ lastHost, targ[1..] });
        } else {
            self.path = try allocator.alloc.dupe(u8, targ);
        }

        if (self.conts != null) {
            allocator.alloc.free(self.conts.?);
            self.conts = null;
        }
        self.highlight_idx = 0;
        self.scroll_top = true;
    }

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        if (pos.y < 40) {
            if (rect.newRect(0, 0, 38, 40).contains(pos)) {
                try self.back(false);
            }

            if (rect.newRect(38, 0, 38, 40).contains(pos)) {
                if (self.conts != null and !self.loading) {
                    allocator.alloc.free(self.conts.?);
                    self.conts = null;
                    self.scroll_top = true;
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

        self.links.clearAndFree();
        self.add_links = true;
    }

    pub fn deinitThread(self: *Self) void {
        while (self.loading) {}

        // styles
        var styleIter = self.styles.iterator();
        while (styleIter.next()) |style| {
            if (!style.value_ptr.locked) {
                style.value_ptr.free();
                allocator.alloc.free(style.key_ptr.*);
            }
        }

        self.styles.deinit();

        if (self.conts) |conts| {
            allocator.alloc.free(conts);
        }

        // links
        if (!self.add_links) {
            self.links.deinit();
        }

        self.hist.deinit();

        // self
        allocator.alloc.destroy(self);
    }

    pub fn deinit(self: *Self) !void {
        _ = try std.Thread.spawn(.{}, deinitThread, .{self});
    }
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(WebData);

    self.* = .{
        .highlight = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(3.0 / 8.0, 4.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
            vecs.newVec2(2.0, 28),
        )),
        .menubar = sprite.Sprite.new("ui", sprite.SpriteData.new(
            rect.newRect(4.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 4.0 / 8.0),
            vecs.newVec2(0.0, 40.0),
        )),
        .text_box = .{
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 32.0),
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 28),
            )),
        },
        .icons = .{
            sprite.Sprite.new("icons", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
            sprite.Sprite.new("icons", sprite.SpriteData.new(
                rect.newRect(4.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(32, 32),
            )),
        },
        .path = conf.SettingManager.instance.get("web_home") orelse "@sandeee.prestosilver.info:/index.edf",
        .conts = null,
        .shader = shader,
        .links = std.ArrayList(WebData.WebLink).init(allocator.alloc),
        .hist = std.ArrayList([]const u8).init(allocator.alloc),
        .web_idx = web_idx,
        .styles = std.StringArrayHashMap(WebData.Style).init(allocator.alloc),
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

    return win.WindowContents.init(self, "web", "Xplorer", col.newColor(1, 1, 1, 1));
}
