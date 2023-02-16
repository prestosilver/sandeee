const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const sb = @import("../spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const files = @import("../system/files.zig");
const tex = @import("../texture.zig");

pub const WebData = struct {
    shader: shd.Shader,
    file: ?*files.File,
    scroll: f32,
};

fn drawWeb(c: *[]u8, batch: *sb.SpriteBatch, font_shader: shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font) void {
    var self = @ptrCast(*WebData, c);

    var pos = vecs.newVec2(0, -self.scroll);

    var iter = std.mem.split(u8, self.file.?.contents, "\n");

    while (iter.next()) |line| {
        var scale: f32 = 1;
        var text = line;

        if (line.len == 0) {
            pos.x = 0;
            pos.y += font.size;
        }

        if (std.mem.startsWith(u8, line, "- ") and std.mem.endsWith(u8, line, " -")) {
            if (pos.x != 0) {
                pos.x = 0;
                pos.y += font.size;
            }
            scale = 3.0;
            text = line[2..line.len - 2];
        }

        if (std.mem.startsWith(u8, line, "-- ") and std.mem.endsWith(u8, line, " --")) {
            if (pos.x != 0) {
                pos.x = 0;
                pos.y += font.size;
            }
            scale = 2.0;
            text = line[3..line.len - 3];
        }

        font.drawScale(batch, font_shader, text, vecs.newVec2(bnds.x + 6 + pos.x, bnds.y + 6 + pos.y), col.newColor(0, 0, 0, 1), scale);

        if (scale != 1.0) {
            pos.x = 0;
            pos.y += font.size * scale;
        } else {
            pos.x += font.sizeText(line).x;
        }
    }

}

fn deleteWeb(cself: *[]u8) void {
    var self = @ptrCast(*WebData, cself);
    allocator.alloc.destroy(self);
}

pub fn new(_: tex.Texture, shader: shd.Shader) win.WindowContents {
    var self = allocator.alloc.create(WebData) catch undefined;

    self.shader = shader;

    self.file = files.root.getFile("/docs/vm/ops.eet");

    return win.WindowContents{
        .self = @ptrCast(*[]u8, self),
        .deleteFn = deleteWeb,
        .drawFn = drawWeb,
        .name = "Xplorer",
        .kind = "web",
        .clearColor = col.newColor(1, 1, 1, 1),
    };
}
