const std = @import("std");
const c = @import("../../c.zig");

const drawers = @import("../../drawers/mod.zig");
const system = @import("../../system/mod.zig");
const events = @import("../../events/mod.zig");
const math = @import("../../math/mod.zig");
const util = @import("../../util/mod.zig");

const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const SpriteBatch = util.SpriteBatch;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;

const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

var outline_sprites = [_]Sprite{
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
    shader: *Shader,

    single_width: f32 = 1,

    pub fn draw(self: *Self, shader: *Shader, bnds: Rect, font: *Font) !void {
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

            outline_sprites[0].data.size = Vec2{
                .x = width + 10,
                .y = font.size + 8,
            };
            outline_sprites[1].data.size = Vec2{
                .x = width + 6,
                .y = font.size + 4,
            };

            try SpriteBatch.global.draw(Sprite, &outline_sprites[0], self.shader, .{ .x = startx - 4, .y = midy - 4 });
            try SpriteBatch.global.draw(Sprite, &outline_sprites[1], self.shader, .{ .x = startx - 2, .y = midy - 2 });

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

    pub fn click(self: *Self, pos: Vec2) !void {
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
