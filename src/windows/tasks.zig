const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const allocator = @import("../util/allocator.zig");

const win = @import("../drawers/window2d.zig");
const sprite = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const fnt = @import("../util/font.zig");
const col = @import("../math/colors.zig");
const vm_manager = @import("../system/vmmanager.zig");
const graph = @import("../drawers/graph2d.zig");

const SpriteBatch = @import("../util/spritebatch.zig");

pub const TasksData = struct {
    const Self = @This();

    panel: [2]sprite.Sprite,
    shader: *shd.Shader,
    stats: []vm_manager.VMManager.VMStats,
    render_graph: graph.Graph,
    vm_graph: graph.Graph,

    scroll_value: f32 = 0,
    scroll_maxy: f32 = 0,

    scroll_sprites: [4]sprite.Sprite,

    pub fn drawScroll(self: *Self, bnds: rect.Rectangle) !void {
        if (self.scroll_maxy <= 0) return;

        const scroll_pc = self.scroll_value / self.scroll_maxy;

        self.scroll_sprites[1].data.size.y = bnds.h - (20 * 2 - 2) + 2;

        try SpriteBatch.global.draw(sprite.Sprite, &self.scroll_sprites[0], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y });
        try SpriteBatch.global.draw(sprite.Sprite, &self.scroll_sprites[1], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y + 20 });
        try SpriteBatch.global.draw(sprite.Sprite, &self.scroll_sprites[2], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y + bnds.h - 20 + 2 });
        try SpriteBatch.global.draw(sprite.Sprite, &self.scroll_sprites[3], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = (bnds.h - (20 * 2) - 30 + 4) * scroll_pc + bnds.y + 20 - 2 });
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, _: *win.WindowContents.WindowProps) !void {
        self.panel[0].data.size.x = 350;
        self.panel[0].data.size.y = 282;
        self.panel[1].data.size.x = 346;
        self.panel[1].data.size.y = 278;

        try SpriteBatch.global.draw(sprite.Sprite, &self.panel[0], self.shader, .{ .x = bnds.x + 21, .y = bnds.y + bnds.h - 282 - 25 });
        try SpriteBatch.global.draw(sprite.Sprite, &self.panel[1], self.shader, .{ .x = bnds.x + 23, .y = bnds.y + bnds.h - 278 - 27 });

        self.scroll_maxy = -278;

        // draw active vms
        const old_scissor = SpriteBatch.global.scissor;
        SpriteBatch.global.scissor = .{
            .x = bnds.x + 25,
            .y = bnds.y + bnds.h - 305,
            .w = 346,
            .h = 278,
        };

        for (self.stats, 0..) |s, idx| {
            const y = bnds.h - 284 - 21 + @as(f32, @floatFromInt(idx)) * font.size - self.scroll_value;
            const text = try std.fmt.allocPrint(allocator.alloc, "{X:2}|{s:<9}|" ++ fnt.META ++ " {:<4} |" ++ fnt.FRAME ++ " {:<4}", .{ s.id, s.name, s.meta_usage, s.last_exec });
            defer allocator.alloc.free(text);

            try font.draw(.{
                .shader = font_shader,
                .text = text,
                .wrap = 346,
                .maxlines = 1,
                .pos = .{
                    .x = bnds.x + 25,
                    .y = bnds.y + y,
                },
            });

            self.scroll_maxy += font.size;
        }

        SpriteBatch.global.scissor = old_scissor;

        try self.drawScroll(.{
            .x = bnds.x + 25,
            .y = bnds.y + bnds.h - 305,
            .w = 344,
            .h = 276,
        });

        // draw graph
        self.panel[0].data.size.y = 87;
        self.panel[1].data.size.y = 83;

        try SpriteBatch.global.draw(sprite.Sprite, &self.panel[0], self.shader, .{ .x = bnds.x + 21, .y = bnds.y + 25 });
        try SpriteBatch.global.draw(sprite.Sprite, &self.panel[1], self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

        self.render_graph.data.size.x = 346;
        self.render_graph.data.size.y = 83;

        try SpriteBatch.global.draw(graph.Graph, &self.render_graph, self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

        self.vm_graph.data.size.x = 346;
        self.vm_graph.data.size.y = 83;

        try SpriteBatch.global.draw(graph.Graph, &self.vm_graph, self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

        // draw labels
        try font.draw(.{
            .shader = font_shader,
            .text = "VM Processes",
            .wrap = 346,
            .maxlines = 1,
            .pos = .{
                .x = bnds.x + 25,
                .y = bnds.y + bnds.h - 305 - font.size - 2,
            },
        });

        try font.draw(.{
            .shader = font_shader,
            .text = "VM Speed",
            .wrap = 346,
            .maxlines = 1,
            .pos = .{
                .x = bnds.x + 25,
                .y = bnds.y + 25 - font.size - 2,
            },
        });
    }

    pub fn scroll(self: *Self, _: f32, y: f32) void {
        self.scroll_value -= y * win.SCROLL_MUL;

        if (self.scroll_value > self.scroll_maxy)
            self.scroll_value = self.scroll_maxy;
        if (self.scroll_value < 0)
            self.scroll_value = 0;
    }

    pub fn refresh(self: *Self) !void {
        for (self.stats) |stat| {
            allocator.alloc.free(stat.name);
        }

        allocator.alloc.free(self.stats);

        self.stats = try vm_manager.VMManager.instance.getStats();

        std.mem.copyForwards(f32, self.vm_graph.data.data[0 .. self.vm_graph.data.data.len - 1], self.vm_graph.data.data[1..]);
        std.mem.copyForwards(f32, self.render_graph.data.data[0 .. self.render_graph.data.data.len - 1], self.render_graph.data.data[1..]);

        var acc: f32 = @floatCast(vm_manager.VMManager.last_vm_time / vm_manager.VMManager.last_frame_time);
        self.vm_graph.data.data[self.vm_graph.data.data.len - 1] = acc;
        acc += @floatCast(vm_manager.VMManager.last_render_time / vm_manager.VMManager.last_frame_time);
        self.render_graph.data.data[self.render_graph.data.data.len - 1] = acc;
    }

    pub fn deinit(self: *Self) void {
        allocator.alloc.free(self.render_graph.data.data);
        allocator.alloc.free(self.vm_graph.data.data);

        for (self.stats) |stat| {
            allocator.alloc.free(stat.name);
        }

        allocator.alloc.free(self.stats);

        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(TasksData);
    self.* = .{
        .panel = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 32.0 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2.0, .y = 28.0 },
            }),
        },
        .scroll_sprites = .{
            .atlas("ui", .{
                .source = .{ .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                .size = .{ .x = 20, .y = 20 },
            }),
            .atlas("ui", .{
                .source = .{ .y = 2.0 / 8.0, .w = 2.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 20, .y = 64 },
            }),
            .atlas("ui", .{
                .source = .{ .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
                .size = .{ .x = 20, .y = 20 },
            }),
            .atlas("ui", .{
                .source = .{ .y = 3.0 / 8.0, .w = 2.0 / 8.0, .h = 3.0 / 8.0 },
                .size = .{ .x = 20, .y = 30 },
            }),
        },
        .shader = shader,
        .stats = try vm_manager.VMManager.instance.getStats(),
        .render_graph = .atlas("white", .{
            .size = .{ .x = 100, .y = 100 },
            .data = try allocator.alloc.dupe(f32, &(.{0} ** 20)),
            .color = .{ .r = 0.5, .g = 0, .b = 0 },
        }),
        .vm_graph = .atlas("white", .{
            .size = .{ .x = 100, .y = 100 },
            .data = try allocator.alloc.dupe(f32, &(.{0} ** 20)),
            .color = .{ .r = 1, .g = 0.5, .b = 0.5 },
        }),
    };

    var result = try win.WindowContents.init(self, "Tasks", "SandEEE Tasks", .{ .r = 0.75, .g = 0.75, .b = 0.75 });
    result.props.size.min = .{ .x = 400, .y = 500 };
    result.props.size.max = .{ .x = 400, .y = 500 };

    return result;
}
