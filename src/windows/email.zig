const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../texture.zig");
const mail = @import("../system/mail.zig");

const boxes: u8 = 3;

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

const EmailData = struct {
    const Self = @This();

    text: []const u8,
    icon: sprite.Sprite,
    divx: sprite.Sprite,
    divy: sprite.Sprite,
    dive: sprite.Sprite,
    sel: sprite.Sprite,
    shader: *shd.Shader,
    box: u8 = 0,
    viewing: ?*mail.Email = null,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) !void {
        self.divy.data.size.y = bnds.h + 4;

        try batch.draw(sprite.Sprite, &self.divy, self.shader, vecs.newVec3(bnds.x + 100, bnds.y - 2, 0));

        self.divx.data.size.x = 104;

        try batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 100, 0));

        try batch.draw(sprite.Sprite, &self.icon, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        try font.draw(batch, font_shader, "  Inbox", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 0), col.newColor(0, 0, 0, 1));
        try font.draw(batch, font_shader, "  Trash", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 1), col.newColor(0, 0, 0, 1));
        try font.draw(batch, font_shader, "  Spam", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 2), col.newColor(0, 0, 0, 1));
        try font.draw(batch, font_shader, ">", vecs.newVec2(bnds.x + 6, bnds.y + 106 + @intToFloat(f32, self.box) * font.size), col.newColor(0, 0, 0, 1));

        if (self.viewing == null) {
            self.dive.data.size.x = bnds.w - 118;

            var y: f32 = bnds.y + 2.0;

            for (mail.emails.items) |email| {
                if (email.box != self.box) continue;

                var text = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ email.from, email.subject });
                defer allocator.alloc.free(text);

                if (email.selected) {
                    self.sel.data.size.x = bnds.w - 106;
                    self.sel.data.size.y = font.size + 4;

                    try batch.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 106, y - 2, 0));
                }

                try font.draw(batch, font_shader, text, vecs.newVec2(bnds.x + 112, y - 4), col.newColor(0, 0, 0, 1));

                try batch.draw(sprite.Sprite, &self.dive, self.shader, vecs.newVec3(bnds.x + 112, y + font.size, 0));

                y += 28;
            }
        } else {
            self.divx.data.size.x = bnds.w - 100;
            try batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x + 104, bnds.y + 2 + font.size * 2, 0));

            var email = self.viewing.?;

            var from = try std.fmt.allocPrint(allocator.alloc, "from: {s}", .{email.from});
            defer allocator.alloc.free(from);
            try font.draw(batch, font_shader, from, vecs.newVec2(bnds.x + 112, bnds.y - 4), col.newColor(0, 0, 0, 1));

            var text = try std.fmt.allocPrint(allocator.alloc, "subject: {s}", .{email.subject});
            defer allocator.alloc.free(text);
            try font.draw(batch, font_shader, text, vecs.newVec2(bnds.x + 112, bnds.y - 4 + font.size), col.newColor(0, 0, 0, 1));

            var line = std.ArrayList(u8).init(allocator.alloc);
            defer line.deinit();
            var y = bnds.y + 8 + font.size * 2;

            for (email.contents) |char| {
                if (char == '\n') {
                    try font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
                    line.clearAndFree();
                    y += font.size;
                } else {
                    try line.append(char);
                    if (font.sizeText(line.items).x > bnds.w - 112.0) {
                        try line.resize(line.items.len - 1);
                        try font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
                        line.clearAndFree();
                        y += font.size;

                        try line.append(char);
                    }
                }
            }
            try font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
        }
    }

    pub fn key(_: *Self, _: i32, _: i32) !void {}

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
        switch (btn) {
            0 => {
                var contBnds = rect.newRect(106, 0, size.x - 106, size.y);
                if (contBnds.contains(mousepos)) {
                    var y: i32 = 0;

                    for (mail.emails.items) |email, idx| {
                        if (email.box != self.box) continue;

                        var bnds = rect.newRect(106, @intToFloat(f32, y), size.x - 106, 28);

                        y += 28;

                        if (bnds.contains(mousepos)) {
                            if (email.selected) {
                                mail.emails.items[idx].selected = false;
                                self.viewing = &mail.emails.items[idx];
                            } else {
                                mail.emails.items[idx].selected = true;
                            }
                        } else {
                            mail.emails.items[idx].selected = false;
                        }
                    }
                } else {
                    var bnds = rect.newRect(0, 106, 106, size.y - 106);
                    if (bnds.contains(mousepos)) {
                        var id = (mousepos.y - 106.0) / 22.0;

                        self.box = @intCast(u8, @floatToInt(i32, id - 0.5));

                        self.viewing = null;

                        if (self.box < 0) {
                            self.box = 0;
                        } else if (self.box > boxes - 1) {
                            self.box = boxes - 1;
                        }
                    }
                }
            },
            else => {},
        }
    }

    pub fn scroll(_: *Self, _: f32, _: f32) !void {}
    pub fn move(_: *Self, _: f32, _: f32) !void {}
    pub fn focus(_: *Self) !void {}

    pub fn deinit(self: *Self) !void {
        allocator.alloc.destroy(self);
    }
};

pub fn new(texture: *tex.Texture, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(EmailData);

    self.divy = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0, 3.0 / 32.0, 3.0 / 32.0, 29.0 / 32.0),
        vecs.newVec2(6, 100),
    ));
    self.divx = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 0, 29.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self.dive = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(16.0 / 32.0, 3.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self.sel = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(16.0 / 32.0, 6.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self.icon = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 3.0 / 32.0, 13.0 / 32.0, 13.0 / 32.0),
        vecs.newVec2(100, 100),
    ));
    self.shader = shader;
    self.viewing = null;
    self.box = 0;

    return win.WindowContents.init(self, "email", "EEE Mail", col.newColor(1, 1, 1, 1));
}
