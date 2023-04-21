const std = @import("std");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const win = @import("../drawers/window2d.zig");
const allocator = @import("../util/allocator.zig");
const wall = @import("../drawers/wall2d.zig");
const bar = @import("../drawers/bar2d.zig");
const sp = @import("../drawers/sprite2d.zig");
const batch = @import("../util/spritebatch.zig");
const shd = @import("../util/shader.zig");
const font = @import("../util/font.zig");
const tex = @import("../util/texture.zig");
const events = @import("../util/events.zig");
const windowEvs = @import("../events/window.zig");
const pseudo = @import("../system/pseudo/all.zig");
const files = @import("../system/files.zig");
const emails = @import("../system/mail.zig");
const conf = @import("../system/config.zig");
const gfx = @import("../util/graphics.zig");
const shell = @import("../system/shell.zig");
const cols = @import("../math/colors.zig");
const network = @import("../system/network.zig");
const cursor = @import("../drawers/cursor2d.zig");

pub const GSWindowed = struct {
    const Self = @This();

    dragmode: win.DragMode = .None,
    draggingStart: vecs.Vector2 = vecs.newVec2(0, 0),
    dragging: ?*win.Window = null,
    down: bool = false,

    mousepos: vecs.Vector2 = vecs.newVec2(0, 0),
    windows: std.ArrayList(win.Window) = undefined,
    openWindow: vecs.Vector2 = vecs.newVec2(0, 0),

    wallpaper: wall.Wallpaper,
    bar: bar.Bar,
    sb: *batch.SpriteBatch,
    shader: *shd.Shader,
    font_shader: *shd.Shader,
    face: *font.Font,
    settingsManager: *conf.SettingManager,
    bar_logo_sprite: sp.Sprite,
    cursor: cursor.Cursor,

    webtex: *tex.Texture,
    wintex: *tex.Texture,
    emailtex: *tex.Texture,
    editortex: *tex.Texture,
    scrolltex: *tex.Texture,
    explorertex: *tex.Texture,

    var globalSelf: *Self = undefined;

    fn createWindow(event: windowEvs.EventCreateWindow) bool {
        var target = vecs.newVec2(100, 100);
        var self = globalSelf;

        for (self.windows.items, 0..) |_, idx| {
            self.windows.items[idx].data.active = false;

            if (self.windows.items[idx].data.pos.x == 100 or self.windows.items[idx].data.pos.y == 100)
                target = self.openWindow;
        }

        self.windows.append(event.window) catch {
            std.log.err("couldnt create window!", .{});
            return false;
        };

        self.windows.items[self.windows.items.len - 1].data.pos.x = target.x;
        self.windows.items[self.windows.items.len - 1].data.pos.y = target.y;
        self.windows.items[self.windows.items.len - 1].data.idx = self.windows.items.len;

        self.openWindow.x = target.x + 25;
        self.openWindow.y = target.y + 25;

        return false;
    }

    pub fn setup(self: *Self) !void {
        gfx.gContext.color = cols.newColor(0, 0.5, 0.5, 1);

        self.windows = std.ArrayList(win.Window).init(allocator.alloc);

        pseudo.win.windowsPtr = &self.windows;

        globalSelf = self;

        win.WindowContents.scrollSp[0] = .{
            .texture = self.scrolltex,
            .data = .{
                .source = rect.newRect(0, 0, 7.0 / 16.0, 6.0 / 16.0),
                .size = vecs.newVec2(14, 12),
            },
        };

        win.WindowContents.scrollSp[1] = .{
            .texture = self.scrolltex,
            .data = .{
                .source = rect.newRect(0, 6.0 / 16.0, 7.0 / 16.0, 4.0 / 16.0),
                .size = vecs.newVec2(14, 64),
            },
        };

        win.WindowContents.scrollSp[2] = .{
            .texture = self.scrolltex,
            .data = .{
                .source = rect.newRect(0, 10.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0),
                .size = vecs.newVec2(14, 12),
            },
        };

        win.WindowContents.scrollSp[3] = .{
            .texture = self.scrolltex,
            .data = .{
                .source = rect.newRect(7.0 / 16.0, 0.0 / 16.0, 7.0 / 16.0, 14.0 / 16.0),
                .size = vecs.newVec2(14, 28),
            },
        };

        win.WindowContents.shader = self.shader;

        events.em.registerListener(windowEvs.EventCreateWindow, createWindow);
    }

    pub fn deinit(self: *Self) !void {
        for (self.windows.items) |*window| {
            try window.data.deinit();
        }

        try files.write();

        self.settingsManager.deinit();
        self.windows.deinit();
        emails.deinit();
        files.deinit();
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        if (self.openWindow.x > size.x - 500) self.openWindow.x = 100;
        if (self.openWindow.y > size.y - 400) self.openWindow.y = 100;

        shell.frameTime = shell.VM_TIME;
        shell.vmsLeft = shell.vms;

        // draw wallpaper
        try self.sb.draw(wall.Wallpaper, &self.wallpaper, self.shader, vecs.newVec3(0, 0, 0));

        for (self.windows.items, 0..) |window, idx| {
            // continue if window closed on update
            if (idx >= self.windows.items.len) continue;

            // draw the window border
            try self.sb.draw(win.Window, &self.windows.items[idx], self.shader, vecs.newVec3(0, 0, 0));

            // draw the windows name
            try self.windows.items[idx].data.drawName(self.font_shader, self.face, self.sb);

            // update scisor region
            self.sb.scissor = window.data.scissor();

            // draw the window contents
            try self.windows.items[idx].data.drawContents(self.font_shader, self.face, self.sb);

            // reset scisor jic
            self.sb.scissor = null;
        }

        // draw bar
        try self.sb.draw(bar.Bar, &self.bar, self.shader, vecs.newVec3(0, 0, 0));
        try self.bar.data.drawName(self.font_shader, self.shader, &self.bar_logo_sprite, self.face, self.sb, &self.windows);

        // draw cursor
        try self.sb.draw(cursor.Cursor, &self.cursor, self.shader, vecs.newVec3(0, 0, 0));
    }

    pub fn update(self: *Self, _: f32) !void {
        var offset: usize = 0;
        for (0..self.windows.items.len) |target| {
            var found = false;
            while (!found) {
                for (self.windows.items) |*item| {
                    if (item.data.idx == target + offset) {
                        item.data.idx = target;
                        found = true;
                        break;
                    }
                }
                offset += 1;
            }
            offset -= 1;
        }

        self.cursor.data.index = 0;
        for (self.windows.items, 0..) |_, idx| {
            if (self.windows.items[idx].data.min) continue;

            var pos = self.windows.items[idx].data.pos;
            pos.x -= 10;
            pos.y -= 10;
            pos.w += 20;
            pos.h += 20;

            if (pos.contains(self.mousepos)) {
                var mode = self.windows.items[idx].data.getDragMode(self.mousepos);
                self.cursor.data.flip = switch (mode) {
                    .None => false,
                    .Move => false,
                    .Close => false,
                    .Full => false,
                    .Min => false,
                    .ResizeL => false,
                    .ResizeR => false,
                    .ResizeB => false,
                    .ResizeLB => false,
                    .ResizeRB => true,
                };
                self.cursor.data.index = switch (mode) {
                    .None => 0,
                    .Move => 3,
                    .Close => 0,
                    .Full => 0,
                    .Min => 0,
                    .ResizeL => 1,
                    .ResizeR => 1,
                    .ResizeB => 2,
                    .ResizeLB => 4,
                    .ResizeRB => 4,
                };
            }
        }
    }

    pub fn keypress(self: *Self, key: c_int, mods: c_int) !bool {
        if (self.bar.data.btnActive) {
            self.bar.data.btnActive = false;

            return false;
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            return window.data.key(key, mods);
        }

        return false;
    }

    pub fn keychar(self: *Self, code: u32, mods: c_int) !void {
        if (self.bar.data.btnActive) {
            return;
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            return window.data.char(code, mods);
        }

        return;
    }

    pub fn mousepress(self: *Self, btn: c_int) !void {
        self.down = true;
        switch (btn) {
            0 => {
                if (try self.bar.data.doClick(&self.windows, self.webtex, self.wintex, self.emailtex, self.editortex, self.explorertex, self.shader, self.mousepos)) {
                    return;
                }

                var newTop: ?u32 = null;

                for (self.windows.items, 0..) |_, idx| {
                    if (self.windows.items[idx].data.min) continue;

                    var pos = self.windows.items[idx].data.pos;
                    pos.x -= 10;
                    pos.y -= 10;
                    pos.w += 20;
                    pos.h += 20;

                    if (pos.contains(self.mousepos)) {
                        newTop = @intCast(u32, idx);
                    }

                    self.windows.items[idx].data.active = false;
                }

                if (newTop) |top| {
                    var swap = self.windows.orderedRemove(@intCast(usize, top));
                    swap.data.active = true;
                    try swap.data.contents.focus();
                    var mode = swap.data.getDragMode(self.mousepos);

                    switch (mode) {
                        .Close => {
                            return swap.data.deinit();
                        },
                        .Full => {
                            if (swap.data.full) {
                                swap.data.pos = swap.data.oldpos;
                            } else {
                                swap.data.oldpos = swap.data.pos;
                            }
                            swap.data.full = !swap.data.full;
                            try self.windows.append(swap);
                        },
                        .Min => {
                            swap.data.min = !swap.data.min;
                            try self.windows.append(swap);
                        },
                        else => {
                            try self.windows.append(swap);
                            if (swap.data.full) return;
                            self.dragmode = mode;
                            self.dragging = &self.windows.items[self.windows.items.len - 1];
                            var start = self.dragging.?.data.pos;
                            self.draggingStart = switch (self.dragmode) {
                                win.DragMode.None => vecs.newVec2(0, 0),
                                win.DragMode.Close => vecs.newVec2(0, 0),
                                win.DragMode.Full => vecs.newVec2(0, 0),
                                win.DragMode.Min => vecs.newVec2(0, 0),
                                win.DragMode.Move => vecs.newVec2(start.x - self.mousepos.x, start.y - self.mousepos.y),
                                win.DragMode.ResizeR => vecs.newVec2(start.w - self.mousepos.x, 0),
                                win.DragMode.ResizeB => vecs.newVec2(0, start.h - self.mousepos.y),
                                win.DragMode.ResizeL => vecs.newVec2(start.w + start.x, 0),
                                win.DragMode.ResizeRB => vecs.newVec2(start.w - self.mousepos.x, start.h - self.mousepos.y),
                                win.DragMode.ResizeLB => vecs.newVec2(start.w + start.x, start.h - self.mousepos.y),
                            };
                        },
                    }
                }
            },
            else => {},
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            return window.data.click(self.mousepos, btn);
        }
    }

    pub fn mouserelease(self: *Self) !void {
        self.dragging = null;
        self.down = false;
    }

    pub fn mousemove(self: *Self, pos: vecs.Vector2) !void {
        self.mousepos = pos;

        if (self.dragging) |dragging| {
            var old = dragging.data.pos;
            var winpos = pos.add(self.draggingStart);

            switch (self.dragmode) {
                .None => {},
                .Close => {},
                .Full => {},
                .Min => {},
                .Move => {
                    dragging.data.pos.x = winpos.x;
                    dragging.data.pos.y = winpos.y;
                },
                .ResizeR => {
                    dragging.data.pos.w = winpos.x;
                },
                .ResizeL => {
                    dragging.data.pos.x = pos.x;
                    dragging.data.pos.w = self.draggingStart.x - pos.x;
                },
                .ResizeB => {
                    dragging.data.pos.h = winpos.y;
                },
                .ResizeRB => {
                    dragging.data.pos.w = winpos.x;
                    dragging.data.pos.h = winpos.y;
                },
                .ResizeLB => {
                    dragging.data.pos.x = pos.x;
                    dragging.data.pos.w = self.draggingStart.x - pos.x;
                    dragging.data.pos.h = winpos.y;
                },
            }

            // min size
            if (dragging.data.pos.w < dragging.data.contents.props.size.min.x) {
                dragging.data.pos.w = old.w;
            }
            if (dragging.data.pos.h < dragging.data.contents.props.size.min.y) {
                dragging.data.pos.h = old.h;
            }

            // max size
            if (dragging.data.pos.w > dragging.data.contents.props.size.max.x) {
                dragging.data.pos.w = old.w;
            }
            if (dragging.data.pos.h > dragging.data.contents.props.size.max.y) {
                dragging.data.pos.h = old.h;
            }
        }
        if (self.down and self.dragmode == .None) {
            for (self.windows.items) |*window| {
                if (!window.data.active) continue;

                try window.data.contents.drag(.{
                    .x = window.data.pos.w,
                    .y = window.data.pos.h - 36,
                }, vecs.Vector2.sub(self.mousepos, .{
                    .x = window.data.pos.x,
                    .y = window.data.pos.y + 36,
                }));
            }
        }
        for (self.windows.items) |*window| {
            if (!window.data.active) continue;
            try window.data.contents.move(pos.x - window.data.pos.x, pos.y - window.data.pos.y - 36);
        }
    }

    pub fn mousescroll(self: *Self, dir: vecs.Vector2) !void {
        var newTop: ?u32 = null;

        for (self.windows.items, 0..) |_, idx| {
            if (self.windows.items[idx].data.min) continue;

            var pos = self.windows.items[idx].data.pos;
            pos.x -= 10;
            pos.y -= 10;
            pos.w += 20;
            pos.h += 20;

            if (pos.contains(self.mousepos)) {
                newTop = @intCast(u32, idx);
            }
        }

        if (newTop) |top| {
            try self.windows.items[top].data.contents.scroll(dir.x, dir.y);
        }
    }
};
