const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

const allocator = @import("../util/allocator.zig");

const win = @import("../drawers/window2d.zig");
const batch = @import("../util/spritebatch.zig");
const sprite = @import("../drawers/sprite2d.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const fnt = @import("../util/font.zig");
const col = @import("../math/colors.zig");
const vmManager = @import("../system/vmmanager.zig");
const graph = @import("../drawers/graph2d.zig");

pub const TasksData = struct {
    const Self = @This();

    panel: [2]sprite.Sprite,
    shader: *shd.Shader,
    stats: []vmManager.VMManager.VMStats,
    graph: graph.Graph,

    scroll_value: f32 = 0,
    scroll_maxy: f32 = 0,

    scroll_sprites: [4]sprite.Sprite,

    pub fn drawScroll(self: *Self, bnds: rect.Rectangle) !void {
        if (self.scroll_maxy <= 0) return;

        const scrollPc = self.scroll_value / self.scroll_maxy;

        self.scroll_sprites[1].data.size.y = bnds.h - (20 * 2 - 2) + 2;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.scroll_sprites[0], self.shader, vecs.newVec3(bnds.x + bnds.w - 18, bnds.y, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.scroll_sprites[1], self.shader, vecs.newVec3(bnds.x + bnds.w - 18, bnds.y + 20, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.scroll_sprites[2], self.shader, vecs.newVec3(bnds.x + bnds.w - 18, bnds.y + bnds.h - 20 + 2, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.scroll_sprites[3], self.shader, vecs.newVec3(bnds.x + bnds.w - 18, (bnds.h - (20 * 2) - 30 + 4) * scrollPc + bnds.y + 20 - 2, 0));
    }

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;

        self.panel[0].data.size.x = 350;
        self.panel[0].data.size.y = 282;
        self.panel[1].data.size.x = 346;
        self.panel[1].data.size.y = 278;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[0], self.shader, vecs.newVec3(bnds.x + 21, bnds.y + bnds.h - 282 - 25, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[1], self.shader, vecs.newVec3(bnds.x + 23, bnds.y + bnds.h - 278 - 27, 0));

        self.scroll_maxy = -278;

        // draw active vms
        const old_scissor = batch.SpriteBatch.instance.scissor;
        batch.SpriteBatch.instance.scissor = .{
            .x = bnds.x + 25,
            .y = bnds.y + bnds.h - 305,
            .w = 346,
            .h = 278,
        };

        for (self.stats, 0..) |s, idx| {
            const y = bnds.h - 284 - 21 + @as(f32, @floatFromInt(idx)) * font.size - self.scroll_value;
            const text = try std.fmt.allocPrint(allocator.alloc, "{X:2}|{s:<9}|\x85 {:<4} |\x86 {:<4}", .{ s.id, s.name, s.meta_usage, s.last_exec });
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

        batch.SpriteBatch.instance.scissor = old_scissor;

        try self.drawScroll(.{
            .x = bnds.x + 25,
            .y = bnds.y + bnds.h - 305,
            .w = 344,
            .h = 276,
        });

        // draw graph
        self.panel[0].data.size.y = 87;
        self.panel[1].data.size.y = 83;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[0], self.shader, vecs.newVec3(bnds.x + 21, bnds.y + 25, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[1], self.shader, vecs.newVec3(bnds.x + 23, bnds.y + 27, 0));

        self.graph.data.size.x = 346;
        self.graph.data.size.y = 83;

        try batch.SpriteBatch.instance.draw(graph.Graph, &self.graph, self.shader, vecs.newVec3(bnds.x + 23, bnds.y + 27, 0));

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
        // TODO: un hardcode
        self.scroll_value -= y * 30;

        if (self.scroll_value > self.scroll_maxy)
            self.scroll_value = self.scroll_maxy;
        if (self.scroll_value < 0)
            self.scroll_value = 0;
    }

    pub fn move(_: *Self, _: f32, _: f32) void {}
    pub fn click(_: *Self, _: vecs.Vector2, _: vecs.Vector2, _: ?i32) !void {}
    pub fn char(_: *Self, _: u32, _: i32) !void {}
    pub fn key(_: *Self, _: i32, _: i32, _: bool) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: rect.Rectangle) !void {}
    pub fn refresh(self: *Self) !void {
        for (self.stats) |stat| {
            allocator.alloc.free(stat.name);
        }

        allocator.alloc.free(self.stats);

        self.stats = try vmManager.VMManager.instance.getStats();

        std.mem.copyForwards(f32, self.graph.data.data[0 .. self.graph.data.data.len - 1], self.graph.data.data[1..]);
        self.graph.data.data[self.graph.data.data.len - 1] = @floatCast(vmManager.VMManager.vm_time);
    }

    pub fn deinit(self: *Self) void {
        for (self.stats) |stat| {
            allocator.alloc.free(stat.name);
        }

        allocator.alloc.free(self.stats);

        allocator.alloc.destroy(self);
    }
};

pub fn new(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(TasksData);
    self.* = .{
        .panel = .{
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(2.0 / 8.0, 0.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 32.0),
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 28),
            )),
        },
        .scroll_sprites = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = rect.newRect(0, 0, 2.0 / 8.0, 2.0 / 8.0),
                    .size = vecs.newVec2(20, 20),
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = rect.newRect(0, 2.0 / 8.0, 2.0 / 8.0, 1.0 / 8.0),
                    .size = vecs.newVec2(20, 64),
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = rect.newRect(0, 6.0 / 8.0, 2.0 / 8.0, 2.0 / 8.0),
                    .size = vecs.newVec2(20, 20),
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = rect.newRect(0, 3.0 / 8.0, 2.0 / 8.0, 3.0 / 8.0),
                    .size = vecs.newVec2(20, 30),
                },
            },
        },
        .shader = shader,
        .stats = try vmManager.VMManager.instance.getStats(),
        .graph = graph.Graph.new(
            "white",
            try graph.GraphData.new(.{ .x = 100, .y = 100 }),
        ),
    };

    allocator.alloc.free(self.graph.data.data);
    self.graph.data.data = try allocator.alloc.dupe(f32, &(.{0} ** 20));
    self.graph.data.color = col.newColorRGBA(255, 128, 128, 255);

    var result = try win.WindowContents.init(self, "Tasks", "SandEEE Tasks", col.newColorRGBA(192, 192, 192, 255));
    result.props.size.min = vecs.newVec2(400, 500);
    result.props.size.max = vecs.newVec2(400, 500);

    return result;
}
