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
const tex = @import("../util/texture.zig");
const mail = @import("../system/mail.zig");

const boxes: u8 = 3;

const EmailData = struct {
    const Self = @This();

    icon: sprite.Sprite,
    divx: sprite.Sprite,
    divy: sprite.Sprite,
    dive: sprite.Sprite,
    sel: sprite.Sprite,
    shader: *shd.Shader,

    box: u8 = 0,
    viewing: ?*mail.Email = null,
    selected: ?*mail.Email = null,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        self.divy.data.size.y = bnds.h + 4;

        try batch.draw(sprite.Sprite, &self.divy, self.shader, vecs.newVec3(bnds.x + 100, bnds.y - 2, 0));

        self.divx.data.size.x = 104;

        try batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 100, 0));

        try batch.draw(sprite.Sprite, &self.icon, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "  Inbox",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 0),
        });
        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "  Spam",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 1),
        });
        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = "  Trash",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 2),
        });
        try font.draw(.{
            .batch = batch,
            .shader = font_shader,
            .text = ">",
            .pos = vecs.newVec2(bnds.x + 6, bnds.y + 106 + @intToFloat(f32, self.box) * font.size),
        });

        if (self.viewing == null) {
            self.dive.data.size.x = bnds.w - 118;

            var y: f32 = bnds.y + 2.0;

            for (0..mail.emails.items.len) |idx| {
                var email = &mail.emails.items[mail.emails.items.len - 1 - idx];
                if (email.box != self.box) continue;
                if (!email.visible()) continue;

                var text = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ email.from, email.subject });
                defer allocator.alloc.free(text);

                if (self.selected != null and email == self.selected.?) {
                    self.sel.data.size.x = bnds.w - 106;
                    self.sel.data.size.y = 22;

                    try batch.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 106, y - 2, 0));
                }

                if (email.complete()) {
                    try font.draw(.{
                        .batch = batch,
                        .shader = font_shader,
                        .text = "\x83",
                        .pos = vecs.newVec2(bnds.x + 112, y - 4),
                        .color = col.newColor(0, 1.0, 0, 1.0),
                    });
                }

                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = text,
                    .pos = vecs.newVec2(bnds.x + 112 + 20, y - 4),
                });

                try batch.draw(sprite.Sprite, &self.dive, self.shader, vecs.newVec3(bnds.x + 112, y + font.size, 0));

                y += 24;
            }
        } else {
            self.divx.data.size.x = bnds.w - 100;
            try batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x + 104, bnds.y + 2 + font.size * 2, 0));

            var email = self.viewing.?;

            var from = try std.fmt.allocPrint(allocator.alloc, "from: {s}", .{email.from});
            defer allocator.alloc.free(from);
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = from,
                .pos = vecs.newVec2(bnds.x + 112, bnds.y - 4),
            });

            var text = try std.fmt.allocPrint(allocator.alloc, "subject: {s}", .{email.subject});
            defer allocator.alloc.free(text);
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = text,
                .pos = vecs.newVec2(bnds.x + 112, bnds.y - 4 + font.size),
            });

            var y = bnds.y + 8 + font.size * 2;

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = email.contents,
                .pos = vecs.newVec2(bnds.x + 112, y),
                .wrap = bnds.w - 112.0,
            });
        }
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }
    pub fn key(_: *Self, _: i32, _: i32, _: bool) !void {}

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
        switch (btn) {
            0 => {
                var contBnds = rect.newRect(106, 0, size.x - 106, size.y);
                if (contBnds.contains(mousepos)) {
                    if (self.viewing != null) return;

                    var y: i32 = 2;

                    for (0..mail.emails.items.len) |idx| {
                        var email = &mail.emails.items[mail.emails.items.len - 1 - idx];
                        if (email.box != self.box) continue;
                        if (!email.visible()) continue;

                        var bnds = rect.newRect(106, @intToFloat(f32, y), size.x - 106, 24);

                        y += 24;

                        if (bnds.contains(mousepos)) {
                            if (self.selected != null and email == self.selected.?) {
                                email.view();
                                self.selected = null;
                                self.viewing = email;
                            } else {
                                self.selected = email;
                            }
                        }
                    }
                } else {
                    var bnds = rect.newRect(0, 106, 106, size.y - 106);
                    if (bnds.contains(mousepos)) {
                        var id = (mousepos.y - 106.0) / 24.0;

                        self.box = @intCast(u8, @floatToInt(i32, id + 0.5));

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

    self.* = .{
        .divy = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(0, 3.0 / 32.0, 3.0 / 32.0, 29.0 / 32.0),
            vecs.newVec2(6, 100),
        )),
        .divx = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(3.0 / 32.0, 0, 29.0 / 32.0, 3.0 / 32.0),
            vecs.newVec2(100, 6),
        )),
        .dive = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(16.0 / 32.0, 3.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
            vecs.newVec2(100, 6),
        )),
        .sel = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(16.0 / 32.0, 6.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
            vecs.newVec2(100, 6),
        )),
        .icon = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(16.0 / 32.0, 16.0 / 32.0, 16.0 / 32.0, 16.0 / 32.0),
            vecs.newVec2(100, 100),
        )),
        .shader = shader,
    };

    return win.WindowContents.init(self, "email", "\x82\x82\x82 Mail", col.newColor(1, 1, 1, 1));
}
