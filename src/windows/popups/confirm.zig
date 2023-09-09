const std = @import("std");

const allocator = @import("../../util/allocator.zig");
const batch = @import("../../util/spritebatch.zig");
const shd = @import("../../util/shader.zig");
const rect = @import("../../math/rects.zig");
const cols = @import("../../math/colors.zig");
const files = @import("../../system/files.zig");
const vecs = @import("../../math/vecs.zig");
const fnt = @import("../../util/font.zig");
const events = @import("../../util/events.zig");
const windowEvs = @import("../../events/window.zig");
const c = @import("../../c.zig");

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

            inline for (typeInfo.Struct.decls) |decl| {
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

            inline for (typeInfo.Struct.decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(T, decl.name)));
                if (info != .Fn)
                    continue;

                res[idx] = .{
                    .text = decl.name,
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

    pub fn key(_: *Self, _: c_int, _: c_int, _: bool) !void {}

    pub fn char(_: *Self, _: u32, _: i32) !void {}

    pub fn click(self: *Self, pos: vecs.Vector2) !void {
        const idx: usize = @intFromFloat(pos.x / self.singleWidth);

        try self.buttons[idx].calls(self.data);
        try events.EventManager.instance.sendEvent(windowEvs.EventClosePopup{});
    }

    pub fn deinit(self: *Self) !void {
        allocator.alloc.destroy(self);
    }
};
