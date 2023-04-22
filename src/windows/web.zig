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

const SCROLL = 30;

pub const WebData = struct {
    const Self = @This();

    pub const WebLink = struct {
        url: ?*files.File,
        pos: rect.Rectangle,
        color: col.Color,
    };

    highlight: sprite.Sprite,
    menubar: sprite.Sprite,
    text_box: [2]sprite.Sprite,
    icons: [1]sprite.Sprite,
    shader: *shd.Shader,
    file: ?*files.File,
    links: std.ArrayList(WebLink),
    hist: std.ArrayList(*files.File),

    top: bool = false,
    highlight_idx: usize = 0,

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

        var pos = vecs.newVec2(0, -props.scroll.?.value + 34);

        var cont: []const u8 = "Error Loading File";
        if (self.file) |file| {
            cont = try file.read(null);
        }

        var iter = std.mem.split(u8, cont, "\n");

        const add_links = self.links.items.len == 0;

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
                var linkiter = std.mem.split(u8, linkcont, ":");
                text = linkiter.next().?;
                text = std.mem.trim(u8, text, &std.ascii.whitespace);
                var url = linkiter.next();
                url = std.mem.trim(u8, url.?, &std.ascii.whitespace);
                if (url) |path| {
                    var size = font.sizeText(.{ .text = text, .scale = scale });
                    var file = try self.file.?.parent.getFile(path);

                    if (path[0] == '/') {
                        file = try files.root.getFile(path);
                    }

                    if (file == null) {
                        color = col.newColor(1, 0, 0, 1);
                    }

                    if (add_links) {
                        var link = WebData.WebLink{
                            .url = file,
                            .pos = rect.newRect(6 + pos.x, 6 + pos.y + props.scroll.?.value, size.x, size.y),
                            .color = color,
                        };
                        try self.links.append(link);
                    }
                }
            }

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

            self.highlight.data.color = self.links.items[self.highlight_idx - 1].color;

            try batch.draw(sprite.Sprite, &self.highlight, self.shader, vecs.newVec3(hlpos.x + bnds.x, hlpos.y + bnds.y - props.scroll.?.value + 4, 0));
        }

        // draw menubar
        self.menubar.data.size.x = bnds.w;
        try batch.draw(sprite.Sprite, &self.menubar, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + 32, bnds.y + 2, 0));
        self.text_box[1].data.size.x = bnds.w - 150 - 34;

        try batch.draw(sprite.Sprite, &self.text_box[1], self.shader, vecs.newVec3(bnds.x + 34, bnds.y + 2, 0));
        try batch.draw(sprite.Sprite, &self.text_box[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 150, bnds.y + 2, 0));

        var tmp = batch.scissor;
        batch.scissor = rect.newRect(bnds.x + 34, bnds.y + 4, bnds.w - 150 - 34, 28);
        if (self.file) |file| {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = file.name,
                .pos = vecs.newVec2(bnds.x + 36, bnds.y + 2),
                .wrap = bnds.w,
            });
        } else {
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = "Error",
                .pos = vecs.newVec2(bnds.x + 36, bnds.y + 2),
                .wrap = bnds.w,
            });
        }
        batch.scissor = tmp;

        try batch.draw(sprite.Sprite, &self.icons[0], self.shader, vecs.newVec3(bnds.x + 6, bnds.y + 6, 0));
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

    pub fn click(self: *Self, _: vecs.Vector2, pos: vecs.Vector2, _: i32) !void {
        if (pos.y < 36) {
            if (rect.newRect(0, 0, 28, 28).contains(pos)) {
                if (self.hist.popOrNull()) |last| {
                    self.file = last;
                    self.links.clearAndFree();
                    self.highlight_idx = 0;
                    self.top = true;
                }
            }

            return;
        }

        if (self.highlight_idx == 0) return;

        try self.hist.append(self.file.?);

        self.file = self.links.items[self.highlight_idx - 1].url;
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

pub fn new(texture: *tex.Texture, shader: *shd.Shader) !win.WindowContents {
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
        },
        .shader = shader,
        .file = try files.root.getFile("/docs/index.edf"),
        .links = std.ArrayList(WebData.WebLink).init(allocator.alloc),
        .hist = std.ArrayList(*files.File).init(allocator.alloc),
    };

    return win.WindowContents.init(self, "web", "Xplorer", col.newColor(1, 1, 1, 1));
}
