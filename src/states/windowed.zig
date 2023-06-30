const std = @import("std");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const win = @import("../drawers/window2d.zig");
const desk = @import("../drawers/desk2d.zig");
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
const systemEvs = @import("../events/system.zig");
const pseudo = @import("../system/pseudo/all.zig");
const files = @import("../system/files.zig");
const emails = @import("../system/mail.zig");
const conf = @import("../system/config.zig");
const gfx = @import("../util/graphics.zig");
const shell = @import("../system/shell.zig");
const cols = @import("../math/colors.zig");
const cursor = @import("../drawers/cursor2d.zig");
const wins = @import("../windows/all.zig");
const popups = @import("../drawers/popup2d.zig");
const notifications = @import("../drawers/notification2d.zig");
const va = @import("../util/vertArray.zig");
const telem = @import("../system/telem.zig");
const c = @import("../c.zig");

pub const GSWindowed = struct {
    const Self = @This();

    dragmode: win.DragMode = .None,
    draggingStart: vecs.Vector2 = vecs.newVec2(0, 0),
    dragging: ?*win.Window = null,
    down: bool = false,

    mousepos: vecs.Vector2 = vecs.newVec2(0, 0),
    windows: std.ArrayList(win.Window) = undefined,
    notifs: std.ArrayList(notifications.Notification) = undefined,
    openWindow: vecs.Vector2 = vecs.newVec2(0, 0),

    wallpaper: wall.Wallpaper,
    bar: bar.Bar,
    sb: *batch.SpriteBatch,
    shader: *shd.Shader,
    font_shader: *shd.Shader,
    clearShader: *shd.Shader,
    face: *font.Font,
    settingsManager: *conf.SettingManager,
    emailManager: *emails.EmailManager,
    bar_logo_sprite: sp.Sprite,
    cursor: cursor.Cursor,
    init: bool = false,
    lastFrameTime: f32 = 1 / 60,

    desk: desk.Desk,

    popup: ?popups.Popup = null,
    shell: shell.Shell = undefined,

    color: cols.Color = cols.newColor(0, 0, 0, 1),

    pub var deskSize: *vecs.Vector2 = undefined;

    var globalSelf: *Self = undefined;

    fn createPopup(event: windowEvs.EventCreatePopup) !void {
        if (event.global) {
            globalSelf.popup = event.popup;
            return;
        }

        for (globalSelf.windows.items) |*window| {
            if (window.data.active) {
                window.data.popup = event.popup;

                return;
            }
        }

        return;
    }

    fn closePopup(_: windowEvs.EventClosePopup) !void {
        if (globalSelf.popup) |*popup| {
            try popup.data.contents.deinit();
            globalSelf.popup = null;

            return;
        }

        for (globalSelf.windows.items) |*window| {
            if (window.data.active) {
                if (window.data.popup) |*popup| {
                    try popup.data.contents.deinit();
                }
                window.data.popup = null;

                return;
            }
        }

        return;
    }

    fn createWindow(event: windowEvs.EventCreateWindow) !void {
        var target = vecs.newVec2(100, 100);

        for (globalSelf.windows.items, 0..) |_, idx| {
            globalSelf.windows.items[idx].data.active = false;

            if (globalSelf.windows.items[idx].data.pos.x == 100 or globalSelf.windows.items[idx].data.pos.y == 100)
                target = globalSelf.openWindow;
        }

        try globalSelf.windows.append(event.window);

        if (event.center) {
            target.x = (deskSize.x - event.window.data.pos.w) / 2;
            target.y = (deskSize.y - event.window.data.pos.h) / 2;
        }

        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.pos.x = target.x;
        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.pos.y = target.y;
        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.idx = globalSelf.windows.items.len;

        globalSelf.openWindow.x = target.x + 25;
        globalSelf.openWindow.y = target.y + 25;

        return;
    }

    pub fn notification(event: windowEvs.EventNotification) !void {
        try globalSelf.notifs.append(
            .{
                .texture = "notif",
                .data = .{
                    .title = event.title,
                    .text = event.text,
                    .icon = event.icon,
                },
            },
        );

        return;
    }

    pub fn settingSet(event: systemEvs.EventSetSetting) !void {
        if (!globalSelf.init) return;

        if (std.mem.eql(u8, event.setting, "wallpaper_color")) {
            if (event.value.len != 6) {
                globalSelf.color.r = 0;
                globalSelf.color.g = 0;
                globalSelf.color.b = 0;
            } else {
                globalSelf.color.r = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[0..2], 16) catch 0)) / 255;
                globalSelf.color.g = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[2..4], 16) catch 0)) / 255;
                globalSelf.color.b = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[4..6], 16) catch 0)) / 255;
            }

            gfx.gContext.color = globalSelf.color;

            return;
        }
        if (std.mem.eql(u8, event.setting, "wallpaper_path")) {
            var texture = batch.textureManager.textures.getPtr("wall") orelse return;
            tex.uploadTextureFile(texture, event.value) catch return;

            return;
        }
        return;
    }

    pub fn setup(self: *Self) !void {
        self.init = true;

        self.popup = null;
        self.windows = std.ArrayList(win.Window).init(allocator.alloc);
        self.notifs = std.ArrayList(notifications.Notification).init(allocator.alloc);

        gfx.gContext.color = self.color;

        pseudo.win.windowsPtr = &self.windows;

        globalSelf = self;

        win.WindowContents.scrollSp[0] = .{
            .texture = "scroll",
            .data = .{
                .source = rect.newRect(0, 0, 7.0 / 16.0, 6.0 / 16.0),
                .size = vecs.newVec2(14, 12),
            },
        };

        win.WindowContents.scrollSp[1] = .{
            .texture = "scroll",
            .data = .{
                .source = rect.newRect(0, 6.0 / 16.0, 7.0 / 16.0, 4.0 / 16.0),
                .size = vecs.newVec2(14, 64),
            },
        };

        win.WindowContents.scrollSp[2] = .{
            .texture = "scroll",
            .data = .{
                .source = rect.newRect(0, 10.0 / 16.0, 7.0 / 16.0, 6.0 / 16.0),
                .size = vecs.newVec2(14, 12),
            },
        };

        win.WindowContents.scrollSp[3] = .{
            .texture = "scroll",
            .data = .{
                .source = rect.newRect(7.0 / 16.0, 0.0 / 16.0, 7.0 / 16.0, 14.0 / 16.0),
                .size = vecs.newVec2(14, 28),
            },
        };

        win.WindowContents.shader = self.shader;
        shell.shader = self.shader;

        try events.EventManager.instance.registerListener(windowEvs.EventCreatePopup, createPopup);
        try events.EventManager.instance.registerListener(windowEvs.EventClosePopup, closePopup);
        try events.EventManager.instance.registerListener(windowEvs.EventCreateWindow, createWindow);
        try events.EventManager.instance.registerListener(windowEvs.EventNotification, notification);
        try events.EventManager.instance.registerListener(systemEvs.EventSetSetting, settingSet);

        if (self.settingsManager.getBool("show_welcome")) {
            var window = win.Window.new("win", win.WindowData{
                .source = rect.Rectangle{
                    .x = 0.0,
                    .y = 0.0,
                    .w = 1.0,
                    .h = 1.0,
                },
                .pos = .{
                    .x = 0,
                    .y = 0,
                    .w = 600,
                    .h = 350,
                },
                .contents = try wins.welcome.new(),
                .active = true,
            });

            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window, .center = true });
        }

        self.desk.data.shell.root = files.home;
        desk.settingsManager = self.settingsManager;

        if (self.settingsManager.get("wallpaper_color")) |color| {
            try settingSet(.{
                .setting = "wallpaper_color",
                .value = color,
            });
        }

        try telem.Telem.load();

        telem.Telem.instance.logins += 1;
        try self.emailManager.updateLogins(telem.Telem.instance.logins);

        if (self.settingsManager.get("startup_file")) |startupCmd| {
            self.shell = .{ .root = files.root };
            _ = self.shell.run(startupCmd, startupCmd) catch return;
        }
    }

    pub fn deinit(self: *Self) !void {
        self.init = false;

        try telem.Telem.save();

        try self.emailManager.saveStateFile("conf/emails.bin");

        for (self.windows.items) |*window| {
            try window.data.deinit();
        }

        if (self.popup) |*popup| {
            try popup.data.contents.deinit();
        }

        try self.face.deinit();

        try files.write();
        try self.settingsManager.deinit();

        self.windows.deinit();
        self.emailManager.deinit();
        files.deinit();
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        if (self.openWindow.x > size.x - 500) self.openWindow.x = 100;
        if (self.openWindow.y > size.y - 400) self.openWindow.y = 100;

        // setup vm data for update
        shell.frameTime = @as(u64, @intFromFloat(self.lastFrameTime * std.time.ns_per_s * 0.5));
        shell.vmsLeft = shell.vms;

        if (self.shell.vm != null) {
            var result = self.shell.updateVM() catch null;
            if (result != null) {
                result.?.data.deinit();
            }
        }

        // draw wallpaper
        try self.sb.draw(wall.Wallpaper, &self.wallpaper, self.shader, vecs.newVec3(0, 0, 0));
        try self.sb.draw(desk.Desk, &self.desk, self.shader, vecs.newVec3(0, 0, 0));
        try self.desk.data.addText(self.sb, self.font_shader, self.face);
        try self.desk.data.updateVm();

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

            if (self.windows.items[idx].data.popup) |*popup| {
                popup.data.parentPos = window.data.pos;

                try self.sb.draw(popups.Popup, popup, self.shader, vecs.newVec3(0, 0, 0));

                try popup.data.drawName(self.font_shader, self.face, self.sb);

                // update scisor region
                self.sb.scissor = popup.data.scissor();

                try popup.data.drawContents(self.font_shader, self.face, self.sb);

                // reset scisor jic
                self.sb.scissor = null;
            }
        }

        // draw bar
        try self.sb.draw(bar.Bar, &self.bar, self.shader, vecs.newVec3(0, 0, 0));
        try self.bar.data.drawName(self.font_shader, self.shader, &self.bar_logo_sprite, self.face, self.sb, &self.windows);

        // draw notifications
        for (self.notifs.items, 0..) |*notif, idx| {
            try self.sb.draw(notifications.Notification, notif, self.shader, vecs.newVec3(@as(f32, @floatFromInt(idx)), 0, 0));
            try notif.data.drawContents(self.sb, self.shader, self.face, self.font_shader, idx);
        }

        // draw popup if exists
        if (self.popup) |*popup| {
            var clearSprite = sp.Sprite{
                .texture = "none",
                .data = .{
                    .size = vecs.newVec2(deskSize.x, deskSize.y),
                    .source = rect.newRect(0, 0, deskSize.x, deskSize.y),
                },
            };

            try self.sb.draw(sp.Sprite, &clearSprite, self.clearShader, vecs.newVec3(0, 0, 0));

            popup.data.parentPos = rect.newRect(0, 0, deskSize.x, deskSize.y);

            try self.sb.draw(popups.Popup, popup, self.shader, vecs.newVec3(0, 0, 0));

            try popup.data.drawName(self.font_shader, self.face, self.sb);

            // update scisor region
            self.sb.scissor = popup.data.scissor();

            try popup.data.drawContents(self.font_shader, self.face, self.sb);

            // reset scisor jic
            self.sb.scissor = null;
        }

        // draw cursor
        try self.sb.draw(cursor.Cursor, &self.cursor, self.shader, vecs.newVec3(0, 0, 0));
    }

    pub fn update(self: *Self, dt: f32) !void {
        self.lastFrameTime = dt;

        for (self.notifs.items, 0..) |*notif, idx| {
            try notif.data.update(dt);

            if (notif.data.time == 0) {
                _ = self.notifs.orderedRemove(idx);
                break;
            }
        }

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
        self.cursor.data.flip = false;

        if (self.popup == null) {
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
                        .ResizeR => true,
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
    }

    pub fn keypress(self: *Self, key: c_int, mods: c_int, down: bool) !void {
        if (self.bar.data.btnActive and !down) {
            self.bar.data.btnActive = false;

            return;
        }

        if (self.popup) |*popup| {
            try popup.data.contents.key(key, mods, down);

            return;
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            if (window.data.popup) |*popup| {
                try popup.data.contents.key(key, mods, down);

                return;
            }

            _ = try window.data.key(key, mods, down);
        }
    }

    pub fn keychar(self: *Self, code: u32, mods: c_int) !void {
        if (self.bar.data.btnActive) {
            return;
        }

        if (self.popup) |*popup| {
            return popup.data.contents.char(code, mods);
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            if (window.data.popup) |*popup| {
                return popup.data.contents.char(code, mods);
            }

            return window.data.char(code, mods);
        }

        return;
    }

    pub fn mousepress(self: *Self, btn: c_int) !void {
        if (self.popup) |*popup| {
            if (popup.data.click(self.mousepos)) {
                self.popup = null;
            }

            return;
        }

        self.down = true;
        switch (btn) {
            0 => {
                if (try self.bar.data.doClick(&self.windows, self.shader, self.mousepos)) {
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
                        newTop = @as(u32, @intCast(idx));
                    }

                    self.windows.items[idx].data.active = false;
                }

                if (newTop) |top| {
                    var swap = self.windows.orderedRemove(@as(usize, @intCast(top)));
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
                            if (!swap.data.full) {
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
                            }
                        },
                    }
                }
            },
            else => {},
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            try self.desk.data.click(self.shader, null);

            if (window.data.popup) |*popup| {
                if (popup.data.click(self.mousepos)) {
                    window.data.popup = null;
                }
                return;
            }

            return window.data.click(self.mousepos, btn);
        }

        try self.desk.data.click(self.shader, self.mousepos);
    }

    pub fn mouserelease(self: *Self) !void {
        self.dragging = null;
        self.down = false;

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            if (window.data.popup) |*popup| {
                if (popup.data.click(self.mousepos)) {
                    window.data.popup = null;
                }
                return;
            }

            return window.data.click(self.mousepos, null);
        }
    }

    pub fn mousemove(self: *Self, pos: vecs.Vector2) !void {
        self.mousepos = pos;

        if (self.popup != null) return;

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
                dragging.data.pos.x = old.x;
            }
            if (dragging.data.pos.h < dragging.data.contents.props.size.min.y) {
                dragging.data.pos.h = old.h;
                dragging.data.pos.y = old.y;
            }

            // max size
            if (dragging.data.contents.props.size.max != null) {
                if (dragging.data.pos.w > dragging.data.contents.props.size.max.?.x) {
                    dragging.data.pos.w = old.w;
                    dragging.data.pos.x = old.x;
                }
                if (dragging.data.pos.h > dragging.data.contents.props.size.max.?.y) {
                    dragging.data.pos.h = old.h;
                    dragging.data.pos.y = old.y;
                }
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
                newTop = @as(u32, @intCast(idx));
            }
        }

        if (newTop) |top| {
            try self.windows.items[top].data.contents.scroll(dir.x, dir.y);
        }
    }
};
