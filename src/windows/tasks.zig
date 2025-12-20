const std = @import("std");
const options = @import("options");
const c = @import("../c.zig");

const Windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Graph = drawers.Graph;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const HttpClient = util.HttpClient;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Url = util.Url;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const Shell = system.Shell;
const Vm = system.Vm;
const config = system.config;
const files = system.files;

const strings = data.strings;

const EventManager = events.EventManager;
const window_events = events.windows;

pub const TasksData = struct {
    const Self = @This();

    panel: [2]Sprite,
    shader: *Shader,
    stats: []Vm.Manager.VMStats,
    render_graph: Graph,
    vm_graph: Graph,

    scroll_value: f32 = 0,
    scroll_maxy: f32 = 0,

    scroll_sprites: [4]Sprite,

    pub fn drawScroll(self: *Self, bnds: Rect) !void {
        if (self.scroll_maxy <= 0) return;

        const scroll_pc = self.scroll_value / self.scroll_maxy;

        self.scroll_sprites[1].data.size.y = bnds.h - (20 * 2 - 2) + 2;

        try SpriteBatch.global.draw(Sprite, &self.scroll_sprites[0], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y });
        try SpriteBatch.global.draw(Sprite, &self.scroll_sprites[1], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y + 20 });
        try SpriteBatch.global.draw(Sprite, &self.scroll_sprites[2], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = bnds.y + bnds.h - 20 + 2 });
        try SpriteBatch.global.draw(Sprite, &self.scroll_sprites[3], self.shader, .{ .x = bnds.x + bnds.w - 18, .y = (bnds.h - (20 * 2) - 30 + 4) * scroll_pc + bnds.y + 20 - 2 });
    }

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, _: *Window.Data.WindowContents.WindowProps) !void {
        self.panel[0].data.size.x = 350;
        self.panel[0].data.size.y = 282;
        self.panel[1].data.size.x = 346;
        self.panel[1].data.size.y = 278;

        try SpriteBatch.global.draw(Sprite, &self.panel[0], self.shader, .{ .x = bnds.x + 21, .y = bnds.y + bnds.h - 282 - 25 });
        try SpriteBatch.global.draw(Sprite, &self.panel[1], self.shader, .{ .x = bnds.x + 23, .y = bnds.y + bnds.h - 278 - 27 });

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
            const text = try std.fmt.allocPrint(allocator, "{X:2}|{s:<9}|" ++ strings.META ++ " {:<4} |" ++ strings.FRAME ++ " {:<4}", .{ s.id, s.name, s.meta_usage, s.last_exec });
            defer allocator.free(text);

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

        try SpriteBatch.global.draw(Sprite, &self.panel[0], self.shader, .{ .x = bnds.x + 21, .y = bnds.y + 25 });
        try SpriteBatch.global.draw(Sprite, &self.panel[1], self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

        self.render_graph.data.size.x = 346;
        self.render_graph.data.size.y = 83;

        try SpriteBatch.global.draw(Graph, &self.render_graph, self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

        self.vm_graph.data.size.x = 346;
        self.vm_graph.data.size.y = 83;

        try SpriteBatch.global.draw(Graph, &self.vm_graph, self.shader, .{ .x = bnds.x + 23, .y = bnds.y + 27 });

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
        self.scroll_value -= y * Window.Data.scroll_mul();

        if (self.scroll_value > self.scroll_maxy)
            self.scroll_value = self.scroll_maxy;
        if (self.scroll_value < 0)
            self.scroll_value = 0;
    }

    pub fn refresh(self: *Self) !void {
        for (self.stats) |stat| {
            allocator.free(stat.name);
        }

        allocator.free(self.stats);

        self.stats = try Vm.Manager.instance.getStats();

        std.mem.copyForwards(f32, self.vm_graph.data.data[0 .. self.vm_graph.data.data.len - 1], self.vm_graph.data.data[1..]);
        std.mem.copyForwards(f32, self.render_graph.data.data[0 .. self.render_graph.data.data.len - 1], self.render_graph.data.data[1..]);

        var acc: f32 = @floatCast(Vm.Manager.last_vm_time / Vm.Manager.last_frame_time);
        self.vm_graph.data.data[self.vm_graph.data.data.len - 1] = acc;
        acc += @floatCast(Vm.Manager.last_render_time / Vm.Manager.last_frame_time);
        self.render_graph.data.data[self.render_graph.data.data.len - 1] = acc;
    }

    pub fn deinit(self: *Self) void {
        allocator.free(self.render_graph.data.data);
        allocator.free(self.vm_graph.data.data);

        for (self.stats) |stat| {
            allocator.free(stat.name);
        }

        allocator.free(self.stats);

        allocator.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(TasksData);
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
        .stats = try Vm.Manager.instance.getStats(),
        .render_graph = .atlas("white", .{
            .size = .{ .x = 100, .y = 100 },
            .data = try allocator.dupe(f32, &(.{0} ** 20)),
            .color = .{ .r = 0.5, .g = 0, .b = 0 },
        }),
        .vm_graph = .atlas("white", .{
            .size = .{ .x = 100, .y = 100 },
            .data = try allocator.dupe(f32, &(.{0} ** 20)),
            .color = .{ .r = 1, .g = 0.5, .b = 0.5 },
        }),
    };

    var result: Window.Data.WindowContents = try .init(self, "Tasks", "SandEEE Tasks", .{ .r = 0.75, .g = 0.75, .b = 0.75 });
    result.props.size.min = .{ .x = 400, .y = 500 };
    result.props.size.max = .{ .x = 400, .y = 500 };

    return result;
}
