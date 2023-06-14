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
const popups = @import("../drawers/popup2d.zig");
const files = @import("../system/files.zig");
const winEvs = @import("../events/window.zig");
const events = @import("../util/events.zig");
const vm = @import("../system/vm.zig");

const c = @import("../c.zig");

pub var notif: sprite.Sprite = undefined;
pub var emailManager: *mail.EmailManager = undefined;

const EmailData = struct {
    const Self = @This();

    backbg: sprite.Sprite,
    reply: sprite.Sprite,
    icon: sprite.Sprite,
    divx: sprite.Sprite,
    divy: sprite.Sprite,
    dive: sprite.Sprite,
    back: sprite.Sprite,
    sel: sprite.Sprite,

    shader: *shd.Shader,

    box: usize = 0,
    viewing: ?*mail.EmailManager.Email = null,
    selected: ?*mail.EmailManager.Email = null,

    pub fn draw(self: *Self, batch: *sb.SpriteBatch, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;
        self.divy.data.size.y = bnds.h + 4;

        try batch.draw(sprite.Sprite, &self.divy, self.shader, vecs.newVec3(bnds.x + 100, bnds.y - 2, 0));

        self.divx.data.size.x = 104;

        try batch.draw(sprite.Sprite, &self.divx, self.shader, vecs.newVec3(bnds.x - 2, bnds.y + 100, 0));

        try batch.draw(sprite.Sprite, &self.icon, self.shader, vecs.newVec3(bnds.x, bnds.y, 0));

        if (self.viewing == null) {
            self.dive.data.size.x = bnds.w - 118;

            var y: f32 = bnds.y + 2.0;

            for (emailManager.emails.items) |*email| {
                if (email.box != self.box) continue;
                if (!emailManager.getEmailVisible(email)) continue;

                var text = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ email.from, email.subject });
                defer allocator.alloc.free(text);

                if (self.selected != null and email == self.selected.?) {
                    self.sel.data.size.x = bnds.w - 106;
                    self.sel.data.size.y = 22;

                    try batch.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x + 106, y - 2, 0));
                }

                if (email.isComplete) {
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
            try batch.draw(sprite.Sprite, &self.backbg, self.shader, vecs.newVec3(bnds.x + 104, bnds.y - 2, 0));
            try batch.draw(sprite.Sprite, &self.reply, self.shader, vecs.newVec3(bnds.x + 104, bnds.y, 0));
            try batch.draw(sprite.Sprite, &self.back, self.shader, vecs.newVec3(bnds.x + 104, bnds.y + 26, 0));

            var email = self.viewing.?;

            var from = try std.fmt.allocPrint(allocator.alloc, "from: {s}", .{email.from});
            defer allocator.alloc.free(from);
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = from,
                .pos = vecs.newVec2(bnds.x + 112 + 28, bnds.y),
            });

            var text = try std.fmt.allocPrint(allocator.alloc, "subject: {s}", .{email.subject});
            defer allocator.alloc.free(text);
            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = text,
                .pos = vecs.newVec2(bnds.x + 112 + 28, bnds.y + font.size),
            });

            var y = bnds.y + 8 + font.size * 2;

            try font.draw(.{
                .batch = batch,
                .shader = font_shader,
                .text = email.contents,
                .pos = vecs.newVec2(bnds.x + 112, y),
                .wrap = bnds.w - 116.0,
            });
        }

        self.sel.data.size.x = 100;
        self.sel.data.size.y = font.size;

        try batch.draw(sprite.Sprite, &self.sel, self.shader, vecs.newVec3(bnds.x, bnds.y + 106 + font.size * @intToFloat(f32, self.box), 0));

        for (emailManager.boxes, 0..) |box, idx| {
            const pos = vecs.newVec2(bnds.x + 2, bnds.y + 106 + font.size * @intToFloat(f32, idx));

            if (idx == self.box) {
                var text = try std.fmt.allocPrint(allocator.alloc, "{s} {d:0>3}%", .{ box[0..@min(3, box.len)], emailManager.getPc(idx) });
                defer allocator.alloc.free(text);

                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = text,
                    .pos = pos,
                });
            } else {
                try font.draw(.{
                    .batch = batch,
                    .shader = font_shader,
                    .text = box,
                    .pos = pos,
                });
            }
        }
    }

    pub fn char(self: *Self, code: u32, mods: i32) !void {
        _ = mods;
        _ = code;
        _ = self;
    }

    pub fn submitFile(self: *Self) !void {
        var adds = try allocator.alloc.create(popups.all.filepick.PopupFilePick);
        adds.* = .{
            .path = try allocator.alloc.dupe(u8, files.home.name),
            .data = self,
            .submit = &submit,
        };

        events.EventManager.instance.sendEvent(winEvs.EventCreatePopup{
            .popup = .{
                .texture = "win",
                .data = .{
                    .title = "Send Attachment",
                    .source = rect.newRect(0, 0, 1, 1),
                    .size = vecs.newVec2(350, 125),
                    .parentPos = undefined,
                    .contents = popups.PopupData.PopupContents.init(adds),
                },
            },
        });
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) return;

        if (keycode == c.GLFW_KEY_R and self.viewing != null) {
            if (self.viewing.?.condition != .Submit) return;
            try self.submitFile();
            return;
        }
    }

    pub fn submit(file: ?*files.File, data: *anyopaque) !void {
        if (file) |target| {
            var self = @ptrCast(*Self, @alignCast(@alignOf(Self), data));

            var conts = try target.read(null);

            if (self.viewing) |selected| {
                if (selected.condition != .Submit) return;
                var iter = std.mem.split(u8, selected.conditionData, ";");

                var good = true;

                while (iter.next()) |cond| {
                    var idx = std.mem.indexOf(u8, cond, "=") orelse cond.len - 1;
                    var name = cond[0..idx];
                    if (std.mem.eql(u8, name, "conts")) {
                        var targetText = cond[idx + 1 ..];
                        good = good and std.ascii.eqlIgnoreCase(targetText, conts);
                    }
                    if (std.mem.eql(u8, name, "runs")) {
                        if (!std.mem.startsWith(u8, conts, "EEEp")) return;
                        var vmInstance = try vm.VM.init(allocator.alloc, files.home, "", true);
                        defer vmInstance.deinit() catch {};

                        try vmInstance.loadString(conts[4..]);

                        try vmInstance.runAll();
                        var targetText = cond[idx + 1 ..];

                        good = good and std.ascii.eqlIgnoreCase(vmInstance.out.items, targetText);
                    }
                }

                if (good) {
                    emailManager.setEmailComplete(selected);
                }
            }
        }
    }

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: i32) !void {
        switch (btn) {
            0 => {
                if (self.viewing) |_| {
                    var replyBnds = rect.newRect(106, 0, 26, 26);

                    if (replyBnds.contains(mousepos)) {
                        try self.submitFile();
                    }

                    var backBnds = rect.newRect(106, 26, 26, 10);

                    if (backBnds.contains(mousepos)) {
                        self.viewing = null;
                        return;
                    }
                }

                var contBnds = rect.newRect(106, 0, size.x - 106, size.y);
                if (contBnds.contains(mousepos)) {
                    if (self.viewing != null) return;

                    var y: i32 = 2;

                    for (emailManager.emails.items) |*email| {
                        if (email.box != self.box) continue;
                        if (!emailManager.getEmailVisible(email)) continue;

                        var bnds = rect.newRect(106, @intToFloat(f32, y), size.x - 106, 24);

                        y += 24;

                        if (bnds.contains(mousepos)) {
                            if (self.selected != null and email == self.selected.?) {
                                emailManager.viewEmail(email);
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
                        } else if (self.box > emailManager.boxes.len - 1) {
                            self.box = emailManager.boxes.len - 1;
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

pub fn new(texture: []const u8, shader: *shd.Shader) !win.WindowContents {
    var self = try allocator.alloc.create(EmailData);

    self.* = .{
        .divy = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(0, 3.0 / 64.0, 3.0 / 32.0, 29.0 / 64.0),
            vecs.newVec2(6, 100),
        )),
        .divx = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(3.0 / 32.0, 0, 29.0 / 32.0, 3.0 / 64.0),
            vecs.newVec2(100, 6),
        )),
        .dive = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(17.0 / 32.0, 3.0 / 64.0, 15.0 / 32.0, 3.0 / 64.0),
            vecs.newVec2(100, 6),
        )),
        .sel = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(17.0 / 32.0, 6.0 / 64.0, 15.0 / 32.0, 3.0 / 64.0),
            vecs.newVec2(100, 6),
        )),
        .icon = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(16.0 / 32.0, 16.0 / 64.0, 16.0 / 32.0, 16.0 / 64.0),
            vecs.newVec2(100, 100),
        )),
        .reply = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(3.0 / 32.0, 35.0 / 64.0, 13.0 / 32.0, 13.0 / 64.0),
            vecs.newVec2(26, 26),
        )),
        .back = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(19.0 / 32.0, 38.0 / 64.0, 13.0 / 32.0, 9.0 / 64.0),
            vecs.newVec2(26, 18),
        )),
        .backbg = sprite.Sprite.new(texture, sprite.SpriteData.new(
            rect.newRect(3.0 / 32.0, 3.0 / 64.0, 14.0 / 32.0, 13.0 / 64.0),
            vecs.newVec2(28, 42),
        )),
        .shader = shader,
    };

    return win.WindowContents.init(self, "email", "\x82\x82\x82Mail", col.newColor(1, 1, 1, 1));
}
