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
const window_events = @import("../../events/window.zig");
const popups = @import("../../drawers/popup2d.zig");
const c = @import("../../c.zig");

var outline_sprites = [_]spr.Sprite{
    .atlas("ui", .{
        .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
        .size = .{ .x = 32, .y = 32 },
    }),
    .atlas("ui", .{
        .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
        .size = .{ .x = 32, .y = 32 },
    }),
};

pub const PopupConfirm = struct {
    const Self = @This();

    pub const ConfirmButton = struct {
        text: []const u8,
        calls: *const fn (*const anyopaque) anyerror!void,
    };

    pub fn initButtonsFromStruct(comptime T: anytype) []const ConfirmButton {
        const type_info = @typeInfo(T);
        if (type_info != .@"struct")
            @compileError("expected struct");

        const len: usize = comptime blk: {
            var len: usize = 0;

            for (type_info.@"struct".decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(T, decl.name)));
                if (info != .@"fn") {
                    continue;
                }

                len += 1;
            }
            break :blk len;
        };

        const result: [len]ConfirmButton = comptime blk: {
            var res: [len]ConfirmButton = undefined;

            var idx = 0;

            for (type_info.@"struct".decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(T, decl.name)));
                if (info != .@"fn")
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

    data: *const anyopaque,
    message: []const u8,
    buttons: []const ConfirmButton,
    shader: *shd.Shader,

    single_width: f32 = 1,

    pub fn draw(self: *Self, shader: *shd.Shader, bnds: rect.Rectangle, font: *fnt.Font) !void {
        const midy = bnds.y + bnds.h / 2;

        try font.draw(.{
            .shader = shader,
            .pos = bnds.location(),
            .text = self.message,
            .color = .{ .r = 0, .g = 0, .b = 0 },
        });

        self.single_width = bnds.w / @as(f32, @floatFromInt(self.buttons.len));

        for (self.buttons, 0..) |btn, idx| {
            const width = font.sizeText(.{
                .text = btn.text,
            }).x;

            const startx = ((self.single_width - width) / 2) + bnds.x + (self.single_width) * @as(f32, @floatFromInt(idx));

            outline_sprites[0].data.size = vecs.Vector2{
                .x = width + 10,
                .y = font.size + 8,
            };
            outline_sprites[1].data.size = vecs.Vector2{
                .x = width + 6,
                .y = font.size + 4,
            };

            try batch.SpriteBatch.instance.draw(spr.Sprite, &outline_sprites[0], self.shader, .{ .x = startx - 4, .y = midy - 4 });
            try batch.SpriteBatch.instance.draw(spr.Sprite, &outline_sprites[1], self.shader, .{ .x = startx - 2, .y = midy - 2 });

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
        const idx: usize = @intFromFloat(pos.x / self.single_width);

        if (idx > self.buttons.len) return;

        try self.buttons[idx].calls(self.data);
        try events.EventManager.instance.sendEvent(window_events.EventClosePopup{
            .popup_conts = self,
        });
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.free(self.message);
        allocator.alloc.destroy(self);
    }
};
