const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const files = @import("../system/files.zig");
const tex = @import("../util/texture.zig");
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");
const popups = @import("../drawers/popup2d.zig");
const gfx = @import("../util/graphics.zig");
const settings = @import("settings.zig");
const c = @import("../c.zig");

const steam = @import("steam");

var web_idx: u8 = 0;

pub const WebData = struct {
    const Self = @This();

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

    top: bool = false,
    highlight_idx: usize = 0,
    loading: bool = false,
    add_imgs: bool = false,
    add_links: bool = false,
    web_idx: u8,

    styles: std.StringArrayHashMap(Style),

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
            switch (path[0]) {
                '@' => {
                    const idx = std.mem.indexOf(u8, path, ":") orelse {
                        self.conts = try allocator.alloc.dupe(u8, "Bad Remote");

                        return;
                    };

                    var client = std.http.Client{ .allocator = allocator.alloc };
                    defer client.deinit();

                    const uri = std.Uri{
                        .scheme = "http",
                        .user = null,
                        .password = null,
                        .host = path[1..idx],
                        .port = 80,
                        .path = path[idx + 1 ..],
                        .query = null,
                        .fragment = null,
                    };

                    var headers = std.http.Headers{ .allocator = allocator.alloc };
                    defer headers.deinit();

                    try headers.append("User-Agent", "SandEEE/0.0");
                    try headers.append("Connection", "Close");

                    var req = client.request(.GET, uri, headers, .{}) catch |err| {
                        if (err == error.TemporaryNameServerFailure)
                            self.conts = try std.fmt.allocPrint(allocator.alloc, "No Internet Connection", .{})
                        else
                            self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});

                        return;
                    };
                    defer req.deinit();

                    req.start() catch |err| {
                        self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                        return;
                    };
                    req.wait() catch |err| {
                        self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: {s}", .{@errorName(err)});
                        return;
                    };

                    if (req.response.status != .ok) {
                        self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: {} - {s}", .{ @intFromEnum(req.response.status), @tagName(req.response.status) });
                        return;
                    }

                    const fconts = try req.reader().readAllAlloc(allocator.alloc, req.response.content_length orelse return);
                    defer allocator.alloc.free(fconts);

                    if (!std.mem.endsWith(u8, self.path.?, "edf")) {
                        try self.saveDialog(try allocator.alloc.dupe(u8, fconts), self.path.?[(std.mem.lastIndexOf(u8, self.path.?, "/") orelse 0) + 1 ..]);

                        try self.back(true);
                        return;
                    }

                    self.conts = try allocator.alloc.dupe(u8, fconts);
                },
                '/' => {
                    self.conts = try allocator.alloc.dupe(u8, try (try files.root.getFile(path)).read(null));
                },
                '$' => {
                    const query = steam.createQueryAllUGCRequest(0, 0, 0, steam.STEAM_APP_ID, 1);
                    _ = query;
                    self.conts = try allocator.alloc.dupe(u8, "lolol");
                },
                else => {
                    self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: Invalid Url protocol", .{});
                },
            }
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

        var target_path = try allocator.alloc.dupe(u8, path);
        defer allocator.alloc.free(target_path);

        if (std.mem.indexOf(u8, path, ":") == null) {
            allocator.alloc.free(target_path);
            const idx = std.mem.indexOf(u8, self.path.?, ":") orelse 0;

            target_path = try std.fmt.allocPrint(allocator.alloc, "@{s}:{s}", .{ self.path.?[1..idx], path[1..] });
        }

        const idx = std.mem.indexOf(u8, target_path, ":") orelse 0;

        var client = std.http.Client{ .allocator = allocator.alloc };
        defer client.deinit();

        const uri = std.Uri{
            .scheme = "http",
            .user = null,
            .password = null,
            .host = target_path[1..idx],
            .port = 80,
            .path = target_path[idx + 1 ..],
            .query = null,
            .fragment = null,
        };

        var headers = std.http.Headers{ .allocator = allocator.alloc };
        defer headers.deinit();

        try headers.append("User-Agent", "SandEEE/0.0");
        try headers.append("Connection", "Close");

        var req = try client.request(.GET, uri, headers, .{});
        defer req.deinit();

        req.start() catch return;
        req.wait() catch return;

        if (req.response.status != .ok) {
            self.conts = try std.fmt.allocPrint(allocator.alloc, "Error: {}", .{req.response.status});
            return;
        }

        const fconts = try req.reader().readAllAlloc(allocator.alloc, req.response.content_length orelse return);
        defer allocator.alloc.free(fconts);

        const texture = sb.textureManager.get(target).?;

        try tex.uploadTextureMem(texture, fconts);

        self.add_links = true;
        self.links.clearAndFree();
    }

    pub fn loadStyle(self: *Self, url: []const u8) !void {
        var target_path = try allocator.alloc.dupe(u8, url);
        defer allocator.alloc.free(target_path);

        if (std.mem.indexOf(u8, url, ":") == null) {
            allocator.alloc.free(target_path);
            const idx = std.mem.indexOf(u8, self.path.?, ":") orelse 0;

            target_path = try std.fmt.allocPrint(allocator.alloc, "@{s}:{s}", .{ self.path.?[1..idx], url[1..] });
        }

        const idx = std.mem.indexOf(u8, target_path, ":") orelse 0;

        var client = std.http.Client{ .allocator = allocator.alloc };
        defer client.deinit();

        const uri = std.Uri{
            .scheme = "http",
            .user = null,
            .password = null,
            .host = target_path[1..idx],
            .port = 80,
            .path = target_path[idx + 1 ..],
            .query = null,
            .fragment = null,
        };

        var headers = std.http.Headers{ .allocator = allocator.alloc };
        defer headers.deinit();

        try headers.append("User-Agent", "SandEEE/0.0");
        try headers.append("Connection", "Close");

        var req = try client.request(.GET, uri, headers, .{});
        defer req.deinit();

        req.start() catch return;
        req.wait() catch return;

        const fconts = try req.reader().readAllAlloc(allocator.alloc, req.response.content_length orelse return);
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
        _ = self;
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
                    .size = vecs.newVec2(350, 125),
                    .parentPos = undefined,
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

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 40,
            };
        }

        if (self.top) {
            props.scroll.?.value = 0;
            self.top = false;
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
                        gfx.gContext.makeCurrent();
                        defer gfx.gContext.makeNotCurrent();

                        try sb.textureManager.putMem(&texid, @embedFile("../images/error.eia"));

                        sb.textureManager.get(&texid).?.size =
                            sb.textureManager.get(&texid).?.size.div(4);

                        _ = try std.Thread.spawn(.{}, loadimage, .{ self, try allocator.alloc.dupe(u8, line[1 .. line.len - 1]), try allocator.alloc.dupe(u8, &texid) });
                    }

                    const size = sb.textureManager.get(&texid).?.size.mul(2 * style.scale);

                    switch (style.ali) {
                        .Center => {
                            const x = (webWidth - size.x) / 2;

                            try batch.draw(sprite.Sprite, &.{
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
                            try batch.draw(sprite.Sprite, &.{
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

                            try batch.draw(sprite.Sprite, &.{
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
                                    .pos = rect.newRect(6 + pos.x, 2 + pos.y + props.scroll.?.value, size.x + 4, size.y + 2),
                                };
                                try self.links.append(link);
                            },
                            .Center => {
                                const x = (webWidth - size.x) / 2 - 7;

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

                if (pos.y - size.y > 0 and pos.y < bnds.h - 6) {
                    switch (style.ali) {
                        .Left => {
                            try font.draw(.{
                                .batch = batch,
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
                                .batch = batch,
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
                                .batch = batch,
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

                try batch.draw(sprite.Sprite, &self.highlight, self.shader, vecs.newVec3(hlpos.x + bnds.x, hlpos.y + bnds.y - props.scroll.?.value + 4, 0));
            }

            self.add_links = false;
            self.add_imgs = false;
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        self.text_box[0].data.size.x = bnds.w - 76;
        self.text_box[1].data.size.x = bnds.w - 80;
        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 72, bnds.y + 2, 0));
        try batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 74, bnds.y + 4, 0));

        const tmp = batch.scissor;
        batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 8 - 34, 28);
        if (self.path) |file| {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = file,
                .pos = vecs.newVec2(bnds.x + 82, bnds.y + 8),
                .wrap = bnds.w,
            });
        } else {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = "Error",
                .pos = vecs.newVec2(bnds.x + 82, bnds.y + 8),
                .wrap = bnds.w,
            });
        }
        batch.scissor = tmp;

        try batch.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 2, bnds.y + 2, 0));

        try batch.draw(sprite.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 38, bnds.y + 2, 0));
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}

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
            self.top = true;
        }
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
                    self.top = true;
                }
            }

            return;
        }

        var lastHost: []const u8 = "";
        if (self.path.?[0] == '@') {
            if (std.mem.indexOf(u8, self.path.?, ":")) |idx|
                lastHost = self.path.?[1..idx];
        }

        if (self.highlight_idx == 0) return;

        try self.hist.append(self.path.?);

        self.path = self.links.items[self.highlight_idx - 1].url;

        if (self.path.?[0] == '@') {
            if (std.mem.indexOf(u8, self.path.?, ":") == null) {
                self.path = try std.fmt.allocPrint(allocator.alloc, "@{s}:{s}", .{ lastHost, self.path.?[1..] });
            }
        }

        if (self.conts != null) {
            allocator.alloc.free(self.conts.?);
            self.conts = null;
        }
        self.highlight_idx = 0;
        self.top = true;
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) return;

        switch (keycode) {
            c.GLFW_KEY_BACKSPACE => {
                try self.back(true);
                return;
            },
            c.GLFW_KEY_TAB => {
                self.highlight_idx += 1;
                if (self.highlight_idx > self.links.items.len)
                    self.highlight_idx = 1;

                return;
            },
            else => {},
        }
    }

    pub fn focus(_: *Self) !void {}

    pub fn moveResize(self: *Self, _: *rect.Rectangle) !void {
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
        self.links.deinit();
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
        .path = settings.settingManager.get("web_home") orelse "@sandeee.org:/index.edf",
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
