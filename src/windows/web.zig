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

const SCROLL = 30;
var web_idx: u8 = 0;

pub const WebData = struct {
    const Self = @This();

    pub const WebLink = struct {
        url: []const u8,
        pos: rect.Rectangle,
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

    pub fn loadPage(self: *Self) !void {
        if (self.path) |path| {
            self.loading = true;
            defer {
                self.loading = false;
                self.add_imgs = true;
                self.add_links = true;
                self.links.clearAndFree();
            }

            switch (path[0]) {
                '@' => {
                    var idx = std.mem.indexOf(u8, path, ":") orelse {
                        self.conts = "Bad Remote";

                        return;
                    };

                    var stream = try std.net.tcpConnectToHost(allocator.alloc, path[1..idx], 80);
                    var request = try std.fmt.allocPrint(allocator.alloc, "GET {s} HTTP/1.1\r\nUser-Agent: SandEEE/0.0\r\nConnection: Close\r\nHost: {s}\r\n\r\n", .{
                        path[idx + 1 ..],
                        path[1..idx],
                    });

                    defer allocator.alloc.free(request);

                    _ = try stream.write(request);

                    var conts = try allocator.alloc.alloc(u8, 10000);
                    defer allocator.alloc.free(conts);

                    var fconts = conts[0..try stream.readAll(conts)];
                    if (std.mem.indexOf(u8, fconts, "404 File not found") != null) {
                        self.conts = try allocator.alloc.dupe(u8, "- 404 Error -");

                        return;
                    }

                    fconts = fconts[(std.mem.indexOf(u8, fconts, "\r\n\r\n") orelse 0) + 4 ..];

                    if (!std.mem.endsWith(u8, self.path.?, "edf")) {
                        try self.saveDialog(try allocator.alloc.dupe(u8, fconts), self.path.?[std.mem.lastIndexOf(u8, self.path.?, "/") orelse 0 ..]);

                        try self.back();
                        return;
                    }

                    self.conts = try allocator.alloc.dupe(u8, fconts);
                },
                '/' => {
                    self.conts = try ((try files.root.getFile(path)) orelse return).read(null);
                },
                else => {},
            }
        }
    }

    pub fn loadimage(self: *Self, path: []const u8, target: []const u8) void {
        defer allocator.alloc.free(target);
        defer allocator.alloc.free(path);

        var target_path = allocator.alloc.dupe(u8, path) catch return;

        if (std.mem.indexOf(u8, path, ":") == null) {
            allocator.alloc.free(target_path);
            var idx = std.mem.indexOf(u8, self.path.?, ":") orelse 0;

            target_path = std.fmt.allocPrint(allocator.alloc, "@{s}:{s}", .{ self.path.?[1..idx], path[1..] }) catch return;
        }

        var idx = std.mem.indexOf(u8, target_path, ":") orelse 0;

        var stream = std.net.tcpConnectToHost(allocator.alloc, target_path[1..idx], 80) catch return;
        var request = std.fmt.allocPrint(allocator.alloc, "GET {s} HTTP/1.1\r\nUser-Agent: SandEEE/0.0\r\nConnection: Close\r\nHost: {s}\r\n\r\n", .{
            target_path[idx + 1 ..],
            target_path[1..idx],
        }) catch return;

        defer allocator.alloc.free(request);

        _ = stream.write(request) catch return;

        var conts = allocator.alloc.alloc(u8, 10000) catch return;
        defer allocator.alloc.free(conts);

        var fconts = conts[0 .. stream.readAll(conts) catch return];
        if (std.mem.indexOf(u8, fconts, "404 File not found") != null) {
            std.log.info("404: {s}", .{target_path});
            return;
        }

        fconts = fconts[(std.mem.indexOf(u8, fconts, "\r\n\r\n") orelse 0) + 4 ..];

        var texture = sb.textureManager.get(target).?;

        tex.uploadTextureMem(texture, fconts) catch {};

        self.add_links = true;
        self.links.clearAndFree();
    }

    pub fn saveDialog(self: *Self, outputData: []const u8, name: []const u8) !void {
        _ = self;
        var output = try allocator.alloc.create([]const u8);
        output.* = outputData;

        var adds = try allocator.alloc.create(popups.all.textpick.PopupTextPick);
        adds.* = .{
            .text = try std.fmt.allocPrint(allocator.alloc, "{s}/{s}", .{ files.home.name, name }),
            .data = @ptrCast(*anyopaque, output),
            .submit = &submit,
            .prompt = "Pick a path to save the file",
        };

        events.em.sendEvent(winEvs.EventCreatePopup{
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
        var conts = @ptrCast(*[]const u8, @alignCast(@alignOf(Self), data));

        _ = try files.root.newFile(file);
        if (try files.root.getFile(file)) |target| {
            try target.write(conts.*, null);

            allocator.alloc.free(conts.*);
            allocator.alloc.destroy(conts);
        }
    }

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        if (props.scroll == null) {
            props.scroll = .{
                .offsetStart = 34,
            };
        }

        if (self.top) {
            props.scroll.?.value = 0;
            self.top = false;
        }

        if (!self.loading) drawConts: {
            var pos = vecs.newVec2(0, -props.scroll.?.value + 34);

            if (self.conts == null) {
                _ = try std.Thread.spawn(.{}, loadPage, .{self});
                break :drawConts;
            }

            var cont = self.conts orelse "Error Loading Page";

            var iter = std.mem.split(u8, cont, "\n");

            var texid: [6]u8 = undefined;
            texid[0] = 'w';
            texid[1] = 'e';
            texid[2] = 'b';
            texid[3] = '_';
            texid[4] = 0;
            texid[5] = self.web_idx;

            // draw text
            while (iter.next()) |line| {
                var scale: f32 = 1;
                var text = line;
                var color = col.newColor(0, 0, 0, 1);

                if (std.mem.startsWith(u8, line, "- ") and std.mem.endsWith(u8, line, " -")) {
                    scale = 3.0;
                    text = line[2 .. line.len - 2];
                }

                if (std.mem.startsWith(u8, line, "-- ") and std.mem.endsWith(u8, line, " --")) {
                    scale = 2.0;
                    text = line[3 .. line.len - 3];
                }

                if (std.mem.startsWith(u8, line, "[") and std.mem.endsWith(u8, line, "]")) {
                    if (self.add_imgs) {
                        try sb.textureManager.putMem(try allocator.alloc.dupe(u8, &texid), "eimg\x01\x00\x01\x00\x00\x00\x00\xff");

                        _ = try std.Thread.spawn(.{}, loadimage, .{ self, try allocator.alloc.dupe(u8, line[1 .. line.len - 1]), try allocator.alloc.dupe(u8, &texid) });
                    }

                    var size = sb.textureManager.get(&texid).?.size.mul(2);
                    try batch.draw(sprite.Sprite, &.{
                        .texture = &texid,
                        .data = .{
                            .source = rect.newRect(0, 0, 1, 1),
                            .size = size,
                        },
                    }, self.shader, vecs.newVec3(bnds.x + 6 + pos.x, bnds.y + 6 + pos.y, 0));
                    texid[4] += 1;
                    pos.y += size.y;
                    continue;
                }

                if (std.mem.startsWith(u8, line, "> ")) {
                    color = col.newColor(0, 0, 1, 1);
                    var linkcont = line[2..];
                    var linkidx = std.mem.indexOf(u8, linkcont, ":") orelse 0;
                    text = linkcont[0..linkidx];
                    text = std.mem.trim(u8, text, &std.ascii.whitespace);
                    var url = linkcont[linkidx + 1 ..];
                    url = std.mem.trim(u8, url, &std.ascii.whitespace);
                    var size = font.sizeText(.{ .text = text, .scale = scale });

                    if (self.add_links) {
                        var link = WebData.WebLink{
                            .url = url,
                            .pos = rect.newRect(6 + pos.x, 2 + pos.y + props.scroll.?.value, size.x + 4, size.y + 2),
                        };
                        try self.links.append(link);
                    }
                }

                if (pos.y > bnds.h + bnds.y and !self.add_links) continue;

                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = text,
                    .pos = vecs.newVec2(bnds.x + 6 + pos.x, bnds.y + 6 + pos.y),
                    .color = color,
                    .scale = scale,
                    .wrap = bnds.w,
                });

                pos.y += font.sizeText(.{ .text = text, .scale = scale, .wrap = bnds.w }).y;
                pos.x = 0;
            }

            props.scroll.?.maxy = pos.y + 64 + font.size + props.scroll.?.value - bnds.h;

            // draw highlight for url
            if (self.highlight_idx != 0 and self.links.items.len >= self.highlight_idx) {
                var hlpos = self.links.items[self.highlight_idx - 1].pos;

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

        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 64, bnds.y + 2, 0));
        self.text_box[1].data.size.x = bnds.w - 8 - 66;

        try batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 66, bnds.y + 2, 0));
        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 8, bnds.y + 2, 0));

        var tmp = batch.scissor;
        batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 8 - 34, 28);
        if (self.path) |file| {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = file,
                .pos = vecs.newVec2(bnds.x + 68, bnds.y + 8),
                .wrap = bnds.w,
            });
        } else {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = "Error",
                .pos = vecs.newVec2(bnds.x + 68, bnds.y + 8),
                .wrap = bnds.w,
            });
        }
        batch.scissor = tmp;

        try batch.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 6, bnds.y + 6, 0));

        try batch.draw(sprite.Sprite, &self.icons[1], self.shader, vecs.newVec3(bnds.x + 36, bnds.y + 6, 0));
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

    pub fn back(self: *Self) !void {
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

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, _: i32) !void {
        if (pos.y < 36) {
            if (rect.newRect(0, 0, 28, 28).contains(pos)) {
                try self.back();
            }

            if (rect.newRect(30, 0, 28, 28).contains(pos)) {
                if (self.conts != null) {
                    allocator.alloc.free(self.conts.?);
                    self.conts = null;
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

    pub fn key(_: *Self, _: i32, _: i32, _: bool) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn deinit(self: *Self) void {
        self.links.deinit();
        allocator.alloc.destroy(self);
    }
};

pub fn new(texture: []const u8, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(WebData);

    self.* = .{
        .highlight = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(15.0 / 32.0, 7.0 / 32.0, 3.0 / 32.0, 3.0 / 32.0),
            vecs.newVec2(0.0, 0.0),
        )),
        .menubar = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(14.0 / 32.0, 7.0 / 32.0, 1.0 / 32.0, 18.0 / 32.0),
            vecs.newVec2(0.0, 36.0),
        )),
        .text_box = .{
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(15.0 / 32.0, 10.0 / 32.0, 1.0 / 32.0, 14.0 / 32.0),
                vecs.newVec2(2.0, 28.0),
            )),
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(16.0 / 32.0, 10.0 / 32.0, 1.0 / 32.0, 14.0 / 32.0),
                vecs.newVec2(2.0, 28),
            )),
        },
        .icons = .{
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(0.0 / 32.0, 22.0 / 32.0, 11.0 / 32.0, 10.0 / 32.0),
                vecs.newVec2(22, 20),
            )),
            sprite.Sprite.new(texture, sprite.SpriteData.new(
                rect.newRect(22.0 / 32.0, 22.0 / 32.0, 10.0 / 32.0, 10.0 / 32.0),
                vecs.newVec2(20, 20),
            )),
        },
        .path = "@sandeee.org:/index.edf",
        .conts = null,
        .shader = shader,
        .links = std.ArrayList(WebData.WebLink).init(allocator.alloc),
        .hist = std.ArrayList([]const u8).init(allocator.alloc),
        .web_idx = web_idx,
    };

    web_idx += 1;

    return win.WindowContents.init(self, "web", "Xplorer", col.newColor(1, 1, 1, 1));
}
