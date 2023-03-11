const std = @import("std");
const shd = @import("../shader.zig");
const sb = @import("../spritebatch.zig");
const sp = @import("../drawers/sprite2d.zig");
const vecs = @import("../math/vecs.zig");
const font = @import("../util/font.zig");
const cols = @import("../math/colors.zig");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");

pub var biosFace: font.Font = undefined;

const VERSION = "0.0.1";

pub var sel: usize = 0;
pub var auto = true;

pub var disks: std.ArrayList([]const u8) = undefined;

pub fn setupDisks() !void {
    disks = std.ArrayList([]const u8).init(allocator.alloc);

    const path = fm.getContentDir();

    const dir = try (try std.fs.cwd().openDir(path, .{ .access_sub_paths = true })).openIterableDir("disks", .{});

    var iter = dir.iterate();

    while (try iter.next()) |item| {
        var entry = try allocator.alloc.alloc(u8, item.name.len);

        std.mem.copy(u8, entry, item.name);

        try disks.append(entry);
    }
}

pub fn drawDisks(shader: shd.Shader, font_shader: shd.Shader, batch: *sb.SpriteBatch, sprite: *sp.Sprite, remaining: f32) !void {
    if (font_shader.id != 0) {
        var pos = vecs.newVec2(20, 20);

        var line: []u8 = undefined;

        batch.draw(sp.Sprite, sprite, shader, vecs.newVec3(20, 20, 0));
        pos.y += sprite.data.size.y;

        if (auto) {
            line = try std.fmt.allocPrint(allocator.alloc, "DiskEEE V_{s} Booting to disk.eee in {}s", .{ VERSION, @floatToInt(i32, remaining + 0.5) });
        } else {
            line = try std.fmt.allocPrint(allocator.alloc, "DiskEEE V_{s}", .{VERSION});
        }

        biosFace.drawScale(batch, font_shader, line, pos, cols.newColor(0.7, 0.7, 0.7, 1), 1);
        pos.y += biosFace.size * 2;
        biosFace.drawScale(batch, font_shader, "Select a disk", pos, cols.newColor(0.7, 0.7, 0.7, 1), 1);
        pos.y += biosFace.size * 1;

        if (sel >= disks.items.len) sel = disks.items.len - 1;

        for (disks.items) |disk, idx| {
            allocator.alloc.free(line);

            line = try std.fmt.allocPrint(allocator.alloc, "  {s}", .{disk});
            if (idx == sel) {
                line[0] = '>';
            }

            biosFace.drawScale(batch, font_shader, line, pos, cols.newColor(0.7, 0.7, 0.7, 1), 1);
            pos.y += biosFace.size * 1;
        }
        allocator.alloc.free(line);
    }
}
