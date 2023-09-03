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
    update_timer: std.time.Timer,
    graph: graph.Graph,

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        _ = props;

        self.panel[0].data.size.x = 350;
        self.panel[0].data.size.y = 282;
        self.panel[1].data.size.x = 346;
        self.panel[1].data.size.y = 278;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[0], self.shader, vecs.newVec3(bnds.x + 21, bnds.y + bnds.h - 282 - 25, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[1], self.shader, vecs.newVec3(bnds.x + 23, bnds.y + bnds.h - 278 - 27, 0));

        if (self.update_timer.read() > 1_000_000_000) {
            for (self.stats) |stat| {
                allocator.alloc.free(stat.name);
            }

            allocator.alloc.free(self.stats);

            self.stats = try vmManager.VMManager.instance.getStats();
            self.update_timer.reset();

            std.mem.copyForwards(f32, self.graph.data.data[0 .. self.graph.data.data.len - 1], self.graph.data.data[1..]);
            self.graph.data.data[self.graph.data.data.len - 1] = @floatCast(vmManager.VMManager.vm_time);
        }

        for (self.stats, 0..) |s, idx| {
            const y = bnds.h - 282 - 21 + @as(f32, @floatFromInt(idx)) * font.size;
            const text = try std.fmt.allocPrint(allocator.alloc, "{s}, {}", .{ s.name, s.metaUsage });
            defer allocator.alloc.free(text);

            try font.draw(.{
                .shader = font_shader,
                .text = text,
                .pos = .{
                    .x = bnds.x + 25,
                    .y = bnds.y + y,
                },
            });
        }

        self.panel[0].data.size.y = 87;
        self.panel[1].data.size.y = 83;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[0], self.shader, vecs.newVec3(bnds.x + 21, bnds.y + 25, 0));
        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.panel[1], self.shader, vecs.newVec3(bnds.x + 23, bnds.y + 27, 0));

        self.graph.data.size.x = 346;
        self.graph.data.size.y = 83;

        try batch.SpriteBatch.instance.draw(graph.Graph, &self.graph, self.shader, vecs.newVec3(bnds.x + 23, bnds.y + 27, 0));
    }

    pub fn scroll(_: *Self, _: f32, _: f32) void {}
    pub fn move(_: *Self, _: f32, _: f32) void {}
    pub fn click(_: *Self, _: vecs.Vector2, _: vecs.Vector2, _: ?i32) !void {}
    pub fn char(_: *Self, _: u32, _: i32) !void {}
    pub fn key(_: *Self, _: i32, _: i32, _: bool) !void {}
    pub fn focus(_: *Self) !void {}
    pub fn moveResize(_: *Self, _: rect.Rectangle) !void {}

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
                rect.newRect(2.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 32.0),
            )),
            sprite.Sprite.new("ui", sprite.SpriteData.new(
                rect.newRect(3.0 / 8.0, 3.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
                vecs.newVec2(2.0, 28),
            )),
        },
        .shader = shader,
        .stats = try vmManager.VMManager.instance.getStats(),
        .update_timer = try std.time.Timer.start(),
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
