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
    add_links: bool = false,

    pub fn loadPage(self: *Self) !void {
        if (self.path) |path| {
            self.loading = true;
            defer self.loading = false;
            defer self.add_links = true;
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
                            .pos = rect.newRect(6 + pos.x, 6 + pos.y + props.scroll.?.value, size.x, size.y),
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
            if (self.highlight_idx != 0) {
                var hlpos = self.links.items[self.highlight_idx - 1].pos;

                self.highlight.data.size.x = hlpos.w;
                self.highlight.data.size.y = hlpos.h;

                self.highlight.data.color = col.newColor(0, 0, 255, 128);

                try batch.draw(sprite.Sprite, &self.highlight, self.shader, vecs.newVec3(hlpos.x + bnds.x, hlpos.y + bnds.y - props.scroll.?.value + 4, 0));
            }

            self.add_links = false;
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 64, bnds.y + 2, 0));
        self.text_box[1].data.size.x = bnds.w - 150 - 66;

        try batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 66, bnds.y + 2, 0));
        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 150, bnds.y + 2, 0));

        var tmp = batch.scissor;
        batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 150 - 34, 28);
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
        self.links.clearAndFree();
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
    };

    return win.WindowContents.init(self, "web", "Xplorer", col.newColor(1, 1, 1, 1));
}
