const std = @import("std");
const options = @import("options");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const win = @import("../drawers/window2d.zig");
const desk = @import("../drawers/desk2d.zig");
const allocator = @import("../util/allocator.zig");
const batch = @import("../util/spritebatch.zig");
const wall = @import("../drawers/wall2d.zig");
const bar = @import("../drawers/bar2d.zig");
const sp = @import("../drawers/sprite2d.zig");
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
const vmManager = @import("../system/vmmanager.zig");
const texMan = @import("../util/texmanager.zig");

const log = @import("../util/log.zig").log;

pub const GSWindowed = struct {
    const Self = @This();

    dragmode: win.DragMode = .None,
    draggingStart: vecs.Vector2 = vecs.newVec2(0, 0),
    dragging_window: ?*win.Window = null,
    dragging_popup: ?*popups.Popup = null,
    down: bool = false,

    mousepos: vecs.Vector2 = vecs.newVec2(0, 0),
    windows: std.ArrayList(win.Window) = undefined,

    notifs: std.ArrayList(notifications.Notification) = undefined,
    openWindow: vecs.Vector2 = vecs.newVec2(0, 0),

    wallpaper: *wall.Wallpaper,
    bar: bar.Bar,
    shader: *shd.Shader,
    font_shader: *shd.Shader,
    clearShader: *shd.Shader,
    face: *font.Font,
    emailManager: *emails.EmailManager,
    bar_logo_sprite: sp.Sprite,
    cursor: cursor.Cursor,
    init: bool = false,

    desk: desk.Desk,

    popups: std.ArrayList(popups.Popup) = undefined,
    shell: shell.Shell = undefined,

    color: cols.Color = cols.newColor(0, 0, 0, 1),
    debug_enabled: bool = false,

    pub var globalSelf: *Self = undefined;

    fn createPopup(event: windowEvs.EventCreatePopup) !void {
        try globalSelf.popups.append(event.popup);
    }

    fn closePopup(event: windowEvs.EventClosePopup) !void {
        const idx = for (globalSelf.popups.items, 0..) |_, idx| {
            if (globalSelf.popups.items[idx].data.contents.ptr == event.popup_conts) {
                break idx;
            }
        } else null;

        if (idx) |remove_idx| {
            var tmp_popup = globalSelf.popups.orderedRemove(remove_idx);
            try tmp_popup.data.contents.deinit();
        }
    }

    fn createWindow(event: windowEvs.EventCreateWindow) !void {
        const draggingIdx = if (globalSelf.dragging_window) |dragging| blk: {
            for (globalSelf.windows.items, 0..) |*window, idx| {
                if (window == dragging) break :blk idx;
            }
            break :blk null;
        } else null;

        var target = vecs.newVec2(100, 100);

        for (globalSelf.windows.items, 0..) |_, idx| {
            globalSelf.windows.items[idx].data.active = false;

            if (globalSelf.windows.items[idx].data.pos.x == 100 or globalSelf.windows.items[idx].data.pos.y == 100)
                target = globalSelf.openWindow;
        }

        try globalSelf.windows.append(event.window);

        if (event.center) {
            target.x = (gfx.Context.instance.size.x - event.window.data.pos.w) / 2;
            target.y = (gfx.Context.instance.size.y - event.window.data.pos.h) / 2;
        }

        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.pos.x = target.x;
        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.pos.y = target.y;
        globalSelf.windows.items[globalSelf.windows.items.len - 1].data.idx = globalSelf.windows.items.len;

        globalSelf.openWindow.x = target.x + 25;
        globalSelf.openWindow.y = target.y + 25;

        if (draggingIdx) |idx| globalSelf.dragging_window = &globalSelf.windows.items[idx];

        try globalSelf.windows.items[globalSelf.windows.items.len - 1].data.refresh();
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
    }

    pub fn debugSet(event: systemEvs.EventDebugSet) !void {
        if (!globalSelf.init) return;

        globalSelf.debug_enabled = event.enabled;
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

            gfx.Context.instance.color = globalSelf.color;
        } else if (std.mem.eql(u8, event.setting, "wallpaper_path")) {
            const texture = texMan.TextureManager.instance.get("wall") orelse return;
            tex.uploadTextureFile(texture, event.value) catch return;
        }
    }

    pub fn setup(self: *Self) !void {
        self.init = true;

        popups.popupShader = self.shader;

        // create lists
        self.windows = std.ArrayList(win.Window).init(allocator.alloc);
        self.popups = std.ArrayList(popups.Popup).init(allocator.alloc);

        self.notifs = std.ArrayList(notifications.Notification).init(allocator.alloc);

        gfx.Context.instance.color = self.color;

        pseudo.win.windowsPtr = &self.windows;

        globalSelf = self;

        win.WindowContents.scrollSp[0] = .{
            .texture = "ui",
            .data = .{
                .source = rect.newRect(0, 0, 2.0 / 8.0, 2.0 / 8.0),
                .size = vecs.newVec2(20, 20),
            },
        };

        win.WindowContents.scrollSp[1] = .{
            .texture = "ui",
            .data = .{
                .source = rect.newRect(0, 2.0 / 8.0, 2.0 / 8.0, 1.0 / 8.0),
                .size = vecs.newVec2(20, 64),
            },
        };

        win.WindowContents.scrollSp[2] = .{
            .texture = "ui",
            .data = .{
                .source = rect.newRect(0, 6.0 / 8.0, 2.0 / 8.0, 2.0 / 8.0),
                .size = vecs.newVec2(20, 20),
            },
        };

        win.WindowContents.scrollSp[3] = .{
            .texture = "ui",
            .data = .{
                .source = rect.newRect(0, 3.0 / 8.0, 2.0 / 8.0, 3.0 / 8.0),
                .size = vecs.newVec2(20, 30),
            },
        };

        win.WindowContents.shader = self.shader;
        shell.shader = self.shader;

        try events.EventManager.instance.registerListener(windowEvs.EventCreatePopup, createPopup);
        try events.EventManager.instance.registerListener(windowEvs.EventClosePopup, closePopup);
        try events.EventManager.instance.registerListener(windowEvs.EventCreateWindow, createWindow);
        try events.EventManager.instance.registerListener(windowEvs.EventNotification, notification);
        try events.EventManager.instance.registerListener(systemEvs.EventSetSetting, settingSet);
        try events.EventManager.instance.registerListener(systemEvs.EventDebugSet, debugSet);

        if (conf.SettingManager.instance.getBool("show_welcome")) {
            const window = win.Window.new("win", win.WindowData{
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

        if (conf.SettingManager.instance.get("wallpaper_color")) |color| {
            try settingSet(.{
                .setting = "wallpaper_color",
                .value = color,
            });
        }

        try telem.Telem.load();

        telem.Telem.instance.logins += 1;
        try self.emailManager.updateLogins(telem.Telem.instance.logins);

        if (conf.SettingManager.instance.get("startup_file")) |startupCmd| {
            self.shell = .{ .root = files.root };
            _ = self.shell.run(startupCmd) catch return;
        }
    }

    pub fn deinit(self: *Self) !void {
        // flag for stupidity
        self.init = false;

        // save telem data
        try telem.Telem.save();

        // save email data
        try self.emailManager.saveStateFile("/_priv/emails.bin");

        // close all windows
        for (self.windows.items) |*window| {
            try window.data.deinit();
        }

        // close all popups
        for (self.popups.items) |*popup| {
            try popup.data.contents.deinit();
        }

        // deinit the font face
        try self.face.deinit();

        // save the disk and settings
        try conf.SettingManager.deinit();
        try files.write();

        // deinit lists
        self.windows.deinit();
        self.emailManager.deinit();
        self.notifs.deinit();
        files.deinit();
    }

    pub fn refresh(self: *Self) !void {
        for (self.windows.items) |*window| {
            try window.data.refresh();
        }
    }

    pub fn draw(self: *Self, size: vecs.Vector2) !void {
        if (self.openWindow.x > size.x - 500) self.openWindow.x = 100;
        if (self.openWindow.y > size.y - 400) self.openWindow.y = 100;

        // setup vm data for update
        if (self.shell.vm != null) {
            const result = self.shell.getVMResult() catch null;
            if (result != null) {
                allocator.alloc.free(result.?.data);
            }
        }

        // draw wallpaper
        try batch.SpriteBatch.instance.draw(wall.Wallpaper, self.wallpaper, self.shader, vecs.newVec3(0, 0, 0));
        try batch.SpriteBatch.instance.draw(desk.Desk, &self.desk, self.shader, vecs.newVec3(0, 0, 0));
        try self.desk.data.addText(self.font_shader, self.face);
        try self.desk.data.updateVm();

        for (self.windows.items) |*window| {
            // update the window
            window.data.update();

            // draw the window border
            try batch.SpriteBatch.instance.draw(win.Window, window, self.shader, vecs.newVec3(0, 0, 0));

            // draw the windows name
            try window.data.drawName(self.font_shader, self.face);

            // update scisor region
            batch.SpriteBatch.instance.scissor = window.data.scissor();

            // draw the window contents
            try window.data.drawContents(self.font_shader, self.face);

            // reset scisor jic
            batch.SpriteBatch.instance.scissor = null;
        }

        // draw popups
        for (self.popups.items) |*popup| {
            try batch.SpriteBatch.instance.draw(popups.Popup, popup, self.shader, vecs.newVec3(0, 0, 0));

            try popup.data.drawName(self.font_shader, self.face);

            // update scisor region
            batch.SpriteBatch.instance.scissor = popup.data.scissor();

            try popup.data.drawContents(self.font_shader, self.face);

            // reset scisor jic
            batch.SpriteBatch.instance.scissor = null;
        }

        // draw bar
        try batch.SpriteBatch.instance.draw(bar.Bar, &self.bar, self.shader, vecs.newVec3(0, 0, 0));
        try self.bar.data.drawName(self.font_shader, self.shader, &self.bar_logo_sprite, self.face, &self.windows);

        // draw notifications
        for (self.notifs.items, 0..) |*notif, idx| {
            try batch.SpriteBatch.instance.draw(notifications.Notification, notif, self.shader, vecs.newVec3(@as(f32, @floatFromInt(idx)), 0, 0));
            try notif.data.drawContents(self.shader, self.face, self.font_shader, idx);
        }

        // draw cursor
        try batch.SpriteBatch.instance.draw(cursor.Cursor, &self.cursor, self.shader, vecs.newVec3(0, 0, 0));

        // vm manager
        try vmManager.VMManager.instance.update();
    }

    pub fn update(self: *Self, dt: f32) !void {
        for (self.windows.items, 0..) |window, idx| {
            if (window.data.shouldClose) {
                _ = self.windows.orderedRemove(idx);
                break;
            }
        }

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

        for (self.windows.items, 0..) |*window, idx| {
            if (window.data.contents.props.close)
                _ = self.windows.orderedRemove(idx);
        }

        self.cursor.data.index = 0;
        self.cursor.data.flip = false;

        for (self.windows.items, 0..) |_, idx| {
            if (self.windows.items[idx].data.min) continue;

            const windowPos = self.windows.items[idx].data.pos;
            const pos = rect.Rectangle{
                .x = windowPos.x - 10,
                .y = windowPos.y - 10,
                .w = windowPos.w + 20,
                .h = windowPos.h + 20,
            };

            if (pos.contains(self.mousepos)) {
                const mode = self.windows.items[idx].data.getDragMode(self.mousepos);
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

        const screen_bounds = rect.Rectangle{
            .x = 0,
            .y = 0,
            .w = gfx.Context.instance.size.x,
            .h = gfx.Context.instance.size.y,
        };

        for (self.windows.items) |*window| {
            if (!screen_bounds.contains_some(window.data.pos)) {
                window.data.pos.x = 100;
                window.data.pos.y = 100;
            }
        }
    }

    pub fn keypress(self: *Self, key: c_int, mods: c_int, down: bool) !void {
        if (self.bar.data.btnActive and !down) {
            self.bar.data.btnActive = false;

            return;
        }

        if (self.popups.items.len != 0) {
            const top_popup = &self.popups.items[0];
            try top_popup.data.contents.key(key, mods, down);

            return;
        }

        if (key == c.GLFW_KEY_P and mods == (c.GLFW_MOD_CONTROL | c.GLFW_MOD_SHIFT) and down) {
            const window = win.Window.new("win", win.WindowData{
                .source = .{
                    .x = 0.0,
                    .y = 0.0,
                    .w = 1.0,
                    .h = 1.0,
                },
                .pos = .{
                    .x = 0,
                    .y = 0,
                    .w = 400,
                    .h = 500,
                },
                .contents = try wins.tasks.new(self.shader),
                .active = true,
            });

            try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window, .center = false });

            return;
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            _ = try window.data.key(key, mods, down);
        }
    }

    pub fn keychar(self: *Self, code: u32, mods: c_int) !void {
        if (self.bar.data.btnActive) return;

        if (self.popups.items.len != 0) {
            const top_popup = &self.popups.items[0];
            try top_popup.data.contents.char(code, mods);

            return;
        }

        for (self.windows.items) |*window| {
            if (!window.data.active) continue;

            return window.data.char(code, mods);
        }
    }

    pub fn mousepress(self: *Self, btn: c_int) !void {
        self.down = true;

        if (self.popups.items.len != 0) {
            switch (try self.popups.items[0].data.click(self.mousepos)) {
                .Close => _ = self.popups.orderedRemove(0),
                .Move => {
                    self.dragging_popup = &self.popups.items[0];
                    self.dragmode = .Move;

                    const start = self.dragging_popup.?.data.pos;
                    self.draggingStart = vecs.newVec2(start.x - self.mousepos.x, start.y - self.mousepos.y);
                },
                .None => {},
            }

            return;
        }

        switch (btn) {
            0 => {
                if (try self.bar.data.doClick(&self.windows, self.shader, self.mousepos)) return;

                var newTop: ?u32 = null;

                for (self.windows.items, 0..) |_, idx| {
                    if (self.windows.items[idx].data.min) continue;

                    const window_pos = self.windows.items[idx].data.pos;
                    const pos = rect.Rectangle{
                        .x = window_pos.x - 10,
                        .y = window_pos.y - 10,
                        .w = window_pos.w + 20,
                        .h = window_pos.h + 20,
                    };

                    if (pos.contains(self.mousepos)) {
                        newTop = @as(u32, @intCast(idx));
                    }

                    self.windows.items[idx].data.active = false;
                }

                if (newTop) |top| {
                    var swap = self.windows.orderedRemove(@as(usize, @intCast(top)));

                    if (!swap.data.active) {
                        swap.data.active = true;
                        try swap.data.contents.focus();
                    }

                    const mode = swap.data.getDragMode(self.mousepos);
                    switch (mode) {
                        .Close => {
                            if (swap.data.contents.props.no_close)
                                try self.windows.append(swap)
                            else
                                return swap.data.deinit();
                        },
                        .Full => {
                            if (swap.data.full) {
                                swap.data.pos = swap.data.oldpos;
                            } else {
                                swap.data.oldpos = swap.data.pos;
                            }

                            swap.data.full = !swap.data.full;
                            try swap.data.contents.moveResize(swap.data.pos);

                            try self.windows.append(swap);
                        },
                        .Min => {
                            if (!swap.data.contents.props.no_min) {
                                swap.data.min = !swap.data.min;
                            }

                            try self.windows.append(swap);
                        },
                        else => {
                            try self.windows.append(swap);
                            if (!swap.data.full) {
                                self.dragmode = mode;
                                self.dragging_window = &self.windows.items[self.windows.items.len - 1];
                                const start = self.dragging_window.?.data.pos;
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

            return window.data.click(self.mousepos, btn);
        }

        try self.desk.data.click(self.shader, self.mousepos);
    }

    pub fn mouserelease(self: *Self) !void {
        if (self.dragging_window) |dragging| {
            try dragging.data.contents.moveResize(dragging.data.pos);
            self.dragging_window = null;
        }

        if (self.dragging_popup) |_| {
            self.dragging_popup = null;
        }

        self.down = false;

        for (self.windows.items) |*window| {
            try window.data.click(self.mousepos, null);
        }
    }

    pub fn mousemove(self: *Self, pos: vecs.Vector2) !void {
        self.mousepos = pos;

        if (self.dragging_popup) |dragging| {
            const winpos = pos.add(self.draggingStart);

            switch (self.dragmode) {
                .Move => {
                    dragging.data.pos.x = winpos.x;
                    dragging.data.pos.y = winpos.y;
                },
                else => {},
            }
        }

        if (self.dragging_window) |dragging| {
            const old = dragging.data.pos;
            const winpos = pos.add(self.draggingStart);

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

        if (self.dragmode == .None) {
            for (self.windows.items) |*window| {
                if (!window.data.active) continue;
                try window.data.contents.move(pos.x - window.data.pos.x, pos.y - window.data.pos.y - 36);
            }
        }
    }

    pub fn mousescroll(self: *Self, dir: vecs.Vector2) !void {
        var newTop: ?u32 = null;

        for (self.windows.items, 0..) |_, idx| {
            if (self.windows.items[idx].data.min) continue;

            const windowPos = self.windows.items[idx].data.pos;
            const pos = rect.Rectangle{
                .x = windowPos.x - 10,
                .y = windowPos.y - 10,
                .w = windowPos.w + 20,
                .h = windowPos.h + 20,
            };

            if (pos.contains(self.mousepos)) {
                newTop = @as(u32, @intCast(idx));
            }
        }

        if (newTop) |top| {
            try self.windows.items[top].data.contents.scroll(dir.x, dir.y);
        }
    }
};
