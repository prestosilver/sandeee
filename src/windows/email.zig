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

const boxes: u8 = 3;

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

const EmailData = struct {
    const Email = struct {
        from: []const u8,
        subject: []const u8,
        contents: []const u8,
        solved: bool = false,
        selected: bool = false,
        box: u8 = 0,
    };

    text: []const u8,
    icon: sprite.Sprite,
    divx: sprite.Sprite,
    divy: sprite.Sprite,
    dive: sprite.Sprite,
    sel: sprite.Sprite,
    shader: shd.Shader,
    emails: std.ArrayList(Email),
    box: u8 = 0,
    viewing: ?Email = null,
};

pub fn drawEmail(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*EmailData, c);

    self.divy.data.size.y = bnds.h + 4;

    batch.draw(sprite.Sprite, &self.divy, self.shader, vecs.newVec3(bnds.x + 100, bnds.y - 2, 0));

    self.divx.data.size.x = 104;

    batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 100, 0));

    batch.draw(sprite.Sprite, &self.icon, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

    font.draw(batch, font_shader, "  Inbox", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 0), col.newColor(0, 0, 0, 1));
    font.draw(batch, font_shader, "  Trash", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 1), col.newColor(0, 0, 0, 1));
    font.draw(batch, font_shader, "  Spam", vecs.newVec2(bnds.x + 6, bnds.y + 106 + font.size * 2), col.newColor(0, 0, 0, 1));
    font.draw(batch, font_shader, ">", vecs.newVec2(bnds.x + 6, bnds.y + 106 + @intToFloat(f32, self.box) * font.size), col.newColor(0, 0, 0, 1));

    if (self.viewing == null) {
        self.dive.data.size.x = bnds.w - 118;

        var y: f32 = bnds.y + 2.0;

        for (self.emails.items) |email| {
            if (email.box != self.box) continue;

            var text = std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ email.from, email.subject }) catch "";
            defer allocator.alloc.free(text);

            if (email.selected) {
                self.sel.data.size.x = bnds.w - 106;
                self.sel.data.size.y = font.size + 4;

                batch.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 106, y - 2, 0));
            }

            font.draw(batch, font_shader, text, vecs.newVec2(bnds.x + 112, y - 4), col.newColor(0, 0, 0, 1));

            batch.draw(sprite.Sprite, &self.dive, self.shader, vecs.newVec3(bnds.x + 112, y + font.size, 0));

            y += 28;
        }
    } else {
        self.divx.data.size.x = bnds.w - 100;
        batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x + 104, bnds.y + 2 + font.size * 2, 0));

        var email = self.viewing.?;

        var from = std.fmt.allocPrint(allocator.alloc, "from: {s}", .{email.from}) catch "";
        defer allocator.alloc.free(from);
        font.draw(batch, font_shader, from, vecs.newVec2(bnds.x + 112, bnds.y - 4), col.newColor(0, 0, 0, 1));

        var text = std.fmt.allocPrint(allocator.alloc, "subject: {s}", .{email.subject}) catch "";
        defer allocator.alloc.free(text);
        font.draw(batch, font_shader, text, vecs.newVec2(bnds.x + 112, bnds.y - 4 + font.size), col.newColor(0, 0, 0, 1));

        var line = std.ArrayList(u8).init(allocator.alloc);
        defer line.deinit();
        var y = bnds.y + 8 + font.size * 2;

        for (email.contents) |char| {
            if (char == '\n') {
                font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
                line.resize(0) catch {};
                y += font.size;
            } else {
                line.append(char) catch {};
                if (font.sizeText(line.items).x > bnds.w - 112.0) {
                    line.resize(line.items.len - 1) catch {};
                    font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
                    line.resize(0) catch {};
                    y += font.size;

                    line.append(char) catch {};
                }
            }
        }
        font.draw(batch, font_shader, line.items, vecs.newVec2(bnds.x + 112, y), col.newColor(0, 0, 0, 1));
    }
}

pub fn clickEmail(c: *[]u8, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) bool {
    var self = @ptrCast(*EmailData, c);
    switch (btn) {
        0 => {
            var contBnds = rect.newRect(106, 0, size.x - 106, size.y);
            if (contBnds.contains(mousepos)) {
                var y: i32 = 0;

                for (self.emails.items) |email, idx| {
                    if (email.box != self.box) continue;

                    var bnds = rect.newRect(106, @intToFloat(f32, y), size.x - 106, 28);

                    y += 28;

                    if (bnds.contains(mousepos)) {
                        if (email.selected) {
                            self.emails.items[idx].selected = false;
                            self.viewing = email;
                        } else {
                            self.emails.items[idx].selected = true;
                        }
                    } else {
                        self.emails.items[idx].selected = false;
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

    return true;
}

pub fn new(texture: tex.Texture, shader: shd.Shader) win.WindowContents {
    var self = allocator.alloc.alloc(EmailData, 1) catch undefined;

    self[0].divy = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(0, 3.0 / 32.0, 3.0 / 32.0, 29.0 / 32.0),
        vecs.newVec2(6, 100),
    ));
    self[0].divx = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 0, 29.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self[0].dive = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(16.0 / 32.0, 3.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self[0].sel = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(16.0 / 32.0, 6.0 / 32.0, 16.0 / 32.0, 3.0 / 32.0),
        vecs.newVec2(100, 6),
    ));
    self[0].icon = sprite.Sprite.new(texture, sprite.SpriteData.new(
        rect.newRect(3.0 / 32.0, 3.0 / 32.0, 13.0 / 32.0, 13.0 / 32.0),
        vecs.newVec2(100, 100),
    ));
    self[0].shader = shader;
    self[0].viewing = null;
    self[0].box = 0;

    self[0].emails = std.ArrayList(EmailData.Email).init(allocator.alloc);
    self[0].emails.append(EmailData.Email{
        .from = "joe_m@eee.org",
        .subject = "I know where you live",
        .contents = "Hello\nI know where you live, if you dont want me releasing this, please program for me.\n\nJoe Moe",
        .box = 0,
    }) catch {};
    for (range(100)) |_, idx| {
        self[0].emails.append(EmailData.Email{
            .from = "joe_m@eee.org",
            .subject = "Program for me",
            .contents = "Please?",
            .box = @intCast(u8, @mod(idx, 2) + 1),
        }) catch {};
    }

    return win.WindowContents{
        .self = @ptrCast(*[]u8, &self[0]),
        .drawFn = drawEmail,
        .clickFn = clickEmail,
        .name = "EEE MAIL",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
