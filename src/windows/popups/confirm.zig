const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const spr = @import("../../drawers/sprite2d.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const popups = @import("../../drawers/popup2d.zig");
const c = @import("../../c.zig");

var outlineSprites = [_]spr.Sprite{
    .{
        .texture = "ui",
        .data = spr.SpriteData.new(
            rect.newRect(
                2.0 / 8.0,
                0.0 / 8.0,
                1.0 / 8.0,
                1.0 / 8.0,
            ),
            vecs.newVec2(32, 32),
        ),
    },
    .{
        .texture = "ui",
        .data = spr.SpriteData.new(
            rect.newRect(
                3.0 / 8.0,
                0.0 / 8.0,
                1.0 / 8.0,
                1.0 / 8.0,
            ),
            vecs.newVec2(32, 32),
        ),
    },
};

pub const PopupConfirm = struct {
    const Self = @This();

    pub const ConfirmButton = struct {
        text: []const u8,
        calls: *const fn (*anyopaque) anyerror!void,
    };

    pub fn createButtonsFromStruct(comptime T: anytype) []const ConfirmButton {
        const typeInfo = @typeInfo(T);
        if (typeInfo != .Struct)
            @compileError("expected struct");

        const len: usize = comptime blk: {
            var len: usize = 0;

            for (typeInfo.Struct.decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(T, decl.name)));
                if (info != .Fn) {
                    continue;
                }

                len += 1;
            }
            break :blk len;
        };

        const result: [len]ConfirmButton = comptime blk: {
            var res: [len]ConfirmButton = undefined;

            var idx = 0;

            for (typeInfo.Struct.decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(T, decl.name)));
                if (info != .Fn)
                    continue;

                const text = std.fmt.comptimePrint("{c}{s}", .{ std.ascii.toUpper(decl.name[0]), decl.name[1..] });

                res[idx] = .{
                    .text = text,
                    .calls = @ptrCast(&@field(T, decl.name)),
                };

                idx += 1;
            }
            break :blk res;
        };

        return &result;
    }

    data: *anyopaque,
    message: []const u8,
    buttons: []const ConfirmButton,
    shader: *shd.Shader,

    singleWidth: f32 = 1,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        const midy = bnds.y + bnds.h / 2;

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = self.message,
            .color = cols.newColor(0, 0, 0, 1),
        });

        self.singleWidth = bnds.w / @as(f32, @floatFromInt(self.buttons.len));

        for (self.buttons, 0..) |btn, idx| {
            const width = font.sizeText(.{
                .text = btn.text,
            }).x;

            const startx = ((self.singleWidth - width) / 2) + bnds.x + (self.singleWidth) * @as(f32, @floatFromInt(idx));

            outlineSprites[0].data.size = vecs.Vector2{
                .x = width + 10,
                .y = font.size + 8,
            };
            outlineSprites[1].data.size = vecs.Vector2{
                .x = width + 6,
                .y = font.size + 4,
            };

            try batch.SpriteBatch.instance.draw(spr.Sprite, &outlineSprites[0], self.shader, vecs.newVec3(startx - 4, midy - 4, 0.0));
            try batch.SpriteBatch.instance.draw(spr.Sprite, &outlineSprites[1], self.shader, vecs.newVec3(startx - 2, midy - 2, 0.0));

            try font.draw(.{
                .shader = shader,
                .pos = .{
                    .x = startx,
                    .y = midy,
                },
                .text = btn.text,
            });
        }
    }

    pub fn click(self: *Self, pos: vecs.Vector2) !void {
        const idx: usize = @intFromFloat(pos.x / self.singleWidth);

        if (idx > self.buttons.len) return;

        try self.buttons[idx].calls(self.data);
        try events.EventManager.instance.sendEvent(windowEvs.EventClosePopup{
            .popup_conts = self,
        });
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.destroy(self);
    }
};
