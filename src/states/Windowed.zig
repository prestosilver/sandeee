const std = @import("std");
const glfw = @import("glfw");

const options = @import("options");

const windows_mod = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const loaders = @import("../loaders.zig");
const events = @import("../events.zig");
const system = @import("../system.zig");
const states = @import("../states.zig");
const util = @import("../util.zig");
const math = @import("../math.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const TextureManager = util.TextureManager;
const SpriteBatch = util.SpriteBatch;
const VertArray = util.VertArray;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Eln = util.Eln;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const Notification = drawers.Notification;
const Sprite = drawers.Sprite;
const Window = drawers.Window;
const Cursor = drawers.Cursor;
const Popup = drawers.Popup;
const Desk = drawers.Desk;
const Wall = drawers.Wall;
const Bar = drawers.Bar;

const Shell = system.Shell;
const Vm = system.Vm;
const pseudo = system.pseudo;
const config = system.config;
const telem = system.telem;
const files = system.files;
const mail = system.mail;

const EventManager = events.EventManager;
const ClickKind = events.input.ClickKind;
const window_events = events.windows;
const system_events = events.system;

const Loader = loaders.Loader;

const GSWindowed = @This();

dragging_mode: Window.Data.DragMode = .None,
dragging_start: Vec2 = .{},
dragging_window: ?*Window = null,
dragging_popup: ?*Popup = null,
down: bool = false,

mousepos: Vec2 = .{},
windows: std.array_list.Managed(*Window) = .init(allocator),
notifs: std.array_list.Managed(*Notification) = .init(allocator),
popups: std.array_list.Managed(*Popup) = .init(allocator),

open_window: Vec2 = .{},

wallpaper: *Wall,
bar: Bar,
shader: *Shader,
font_shader: *Shader,
clear_shader: *Shader,
face: *Font,
bar_logo_sprite: Sprite,
cursor: Cursor,
init: bool = false,

desk: Desk,

shell: Shell,

color: Color = .{ .r = 0, .g = 0, .b = 0 },
debug_enabled: bool = false,

pub var global_self: *GSWindowed = undefined;

fn spawnPopup(event: window_events.EventCreatePopup) !void {
    const popup = try allocator.create(Popup);
    errdefer allocator.destroy(popup);

    popup.* = event.popup;

    try global_self.popups.append(popup);
}

fn closePopup(event: window_events.EventClosePopup) !void {
    const idx = for (global_self.popups.items, 0..) |_, idx| {
        if (global_self.popups.items[idx].data.contents.ptr == event.popup_conts) {
            break idx;
        }
    } else null;

    if (idx) |remove_idx| {
        var tmp_popup = global_self.popups.orderedRemove(remove_idx);
        tmp_popup.data.contents.deinit();
        allocator.destroy(tmp_popup);
    }
}

fn spawnWindow(event: window_events.EventCreateWindow) !void {
    const dragging_idx = if (global_self.dragging_window) |dragging| blk: {
        for (global_self.windows.items, 0..) |window, idx| {
            if (window == dragging) break :blk idx;
        }
        break :blk null;
    } else null;

    var target = Vec2{ .x = 100, .y = 100 };

    for (global_self.windows.items, 0..) |_, idx| {
        global_self.windows.items[idx].data.active = false;

        if (global_self.windows.items[idx].data.pos.x == 100 or global_self.windows.items[idx].data.pos.y == 100)
            target = global_self.open_window;
    }

    const window = try allocator.create(Window);
    errdefer allocator.destroy(window);

    window.* = event.window;

    try global_self.windows.append(window);

    if (event.center) {
        target.x = (graphics.Context.instance.size.x - event.window.data.pos.w) / 2;
        target.y = (graphics.Context.instance.size.y - event.window.data.pos.h) / 2;
    }

    window.data.pos.x = target.x;
    window.data.pos.y = target.y;
    window.data.idx = global_self.windows.items.len;

    global_self.open_window.x = target.x + 25;
    global_self.open_window.y = target.y + 25;

    if (dragging_idx) |idx| global_self.dragging_window = global_self.windows.items[idx];

    try global_self.windows.items[global_self.windows.items.len - 1].data.refresh();
}

pub fn notification(event: window_events.EventNotification) !void {
    const notif = try allocator.create(Notification);
    errdefer allocator.destroy(notif);

    notif.* = .atlas("ui", .{
        .title = event.title,
        .text = event.text,
        .icon = event.icon,
    });

    try global_self.notifs.append(notif);
}

pub fn debugSet(event: system_events.EventDebugSet) !void {
    if (!global_self.init) return;

    global_self.debug_enabled = event.enabled;
    try mail.EmailManager.instance.updateDebug();
}

pub fn settingSet(event: system_events.EventSetSetting) !void {
    if (!global_self.init) return;

    if (std.mem.eql(u8, event.setting, "wallpaper_color")) {
        if (event.value.len != 6) {
            global_self.color.r = 0;
            global_self.color.g = 0;
            global_self.color.b = 0;
        } else {
            global_self.color.r = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[0..2], 16) catch 0)) / 255;
            global_self.color.g = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[2..4], 16) catch 0)) / 255;
            global_self.color.b = @as(f32, @floatFromInt(std.fmt.parseInt(u8, event.value[4..6], 16) catch 0)) / 255;
        }

        graphics.Context.instance.color = global_self.color;
    } else if (std.mem.eql(u8, event.setting, "wallpaper_path")) {
        const texture = TextureManager.instance.get("wall") orelse return;
        texture.loadFile(event.value) catch return;
    }
}

pub fn setup(self: *GSWindowed) !void {
    self.init = true;

    Popup.Data.popup_shader = self.shader;

    graphics.Context.instance.color = self.color;

    pseudo.win.windows_ptr = &self.windows;

    global_self = self;

    Window.Data.WindowContents.scroll_sp[0] = .atlas("ui", .{
        .source = .{ .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
        .size = .{ .x = 20, .y = 20 },
    });

    Window.Data.WindowContents.scroll_sp[1] = .atlas("ui", .{
        .source = .{ .y = 2.0 / 8.0, .w = 2.0 / 8.0, .h = 1.0 / 8.0 },
        .size = .{ .x = 20, .y = 64 },
    });

    Window.Data.WindowContents.scroll_sp[2] = .atlas("ui", .{
        .source = .{ .y = 6.0 / 8.0, .w = 2.0 / 8.0, .h = 2.0 / 8.0 },
        .size = .{ .x = 20, .y = 20 },
    });

    Window.Data.WindowContents.scroll_sp[3] = .atlas("ui", .{
        .source = .{ .y = 3.0 / 8.0, .w = 2.0 / 8.0, .h = 3.0 / 8.0 },
        .size = .{ .x = 20, .y = 30 },
    });

    Window.Data.WindowContents.shader = self.shader;
    Shell.shader = self.shader;

    try events.EventManager.instance.registerListener(window_events.EventCreatePopup, spawnPopup);
    try events.EventManager.instance.registerListener(window_events.EventClosePopup, closePopup);
    try events.EventManager.instance.registerListener(window_events.EventCreateWindow, spawnWindow);
    try events.EventManager.instance.registerListener(window_events.EventNotification, notification);
    try events.EventManager.instance.registerListener(system_events.EventSetSetting, settingSet);
    try events.EventManager.instance.registerListener(system_events.EventDebugSet, debugSet);

    if (config.SettingManager.instance.getBool("show_welcome") orelse true) {
        const window: Window = .atlas("win", .{
            .source = Rect{ .w = 1, .h = 1 },
            .pos = .{ .w = 600, .h = 350 },
            .contents = try windows_mod.welcome.init(self.shader),
            .active = true,
        });

        try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window, .center = true });
    }

    self.desk.data.shell.root = .home;

    if (config.SettingManager.instance.get("wallpaper_color")) |color| {
        try settingSet(.{
            .setting = "wallpaper_color",
            .value = color,
        });
    }

    try telem.Telem.load();

    telem.Telem.instance.logins += 1;
    try mail.EmailManager.instance.updateLogins(telem.Telem.instance.logins);

    if (config.SettingManager.instance.get("startup_file")) |startupCmd| {
        self.shell = .{ .root = .root };
        _ = self.shell.run(startupCmd) catch return;
    }
}

pub fn deinit(self: *GSWindowed) void {
    // flag for stupidity
    self.init = false;

    // save telem data
    telem.Telem.save() catch |err|
        std.log.err("telem save failed {}", .{err});

    // close all windows
    for (self.windows.items) |window| {
        window.data.deinit();
        allocator.destroy(window);
    }

    // close all popups
    for (self.popups.items) |popup| {
        popup.data.contents.deinit();
        allocator.destroy(popup);
    }

    // deinit the Eln loader
    Eln.reset();

    // deinit lists
    self.windows.clearAndFree();
    self.popups.clearAndFree();
    self.notifs.clearAndFree();
}

pub fn refresh(self: *GSWindowed) !void {
    for (self.windows.items) |window| {
        try window.data.refresh();
    }
}

pub fn draw(self: *GSWindowed, size: Vec2) !void {
    if (self.open_window.x > size.x - 500) self.open_window.x = 100;
    if (self.open_window.y > size.y - 400) self.open_window.y = 100;

    // setup vm data for update
    if (self.shell.vm != null) {
        const result = self.shell.getVMResult() catch null;
        if (result) |result_data| {
            allocator.free(result_data.data);
        }
    }

    // draw wallpaper
    try SpriteBatch.global.draw(Wall, self.wallpaper, self.shader, .{});
    try SpriteBatch.global.draw(Desk, &self.desk, self.shader, .{});
    try self.desk.data.addText(self.font_shader, self.face);
    try self.desk.data.updateVm();

    for (self.windows.items) |window| {
        // update the window
        window.data.update();

        // draw the window border
        try SpriteBatch.global.draw(Window, window, self.shader, .{});

        // draw the windows name
        try window.data.drawName(self.font_shader, self.face);

        // update scisor region
        SpriteBatch.global.scissor = window.data.scissor();

        // draw the window contents
        try window.data.drawContents(self.font_shader, self.face);

        // reset scisor jic
        SpriteBatch.global.scissor = null;
    }

    // draw popups
    for (self.popups.items) |popup| {
        try SpriteBatch.global.draw(Popup, popup, self.shader, .{});

        try popup.data.drawName(self.font_shader, self.face);

        // update scisor region
        SpriteBatch.global.scissor = popup.data.scissor();

        try popup.data.drawContents(self.font_shader, self.face);

        // reset scisor jic
        SpriteBatch.global.scissor = null;
    }

    // draw bar
    try SpriteBatch.global.draw(Bar, &self.bar, self.shader, .{});
    try self.bar.data.drawName(self.font_shader, self.shader, &self.bar_logo_sprite, self.face, &self.windows);

    // draw notifications
    for (self.notifs.items, 0..) |notif, idx| {
        try SpriteBatch.global.draw(Notification, notif, self.shader, .{ .x = @floatFromInt(idx) });
        try notif.data.drawContents(self.shader, self.face, self.font_shader, idx);
    }

    // draw cursor
    try SpriteBatch.global.draw(Cursor, &self.cursor, self.shader, .{});

    // vm manager
    try Vm.Manager.instance.update();
}

pub fn update(self: *GSWindowed, dt: f32) !void {
    for (self.windows.items, 0..) |window, idx| {
        if (window.data.should_close) {
            if (self.dragging_window) |drag|
                if (window == drag) {
                    self.dragging_window = null;
                };

            const free_win = self.windows.orderedRemove(idx);
            free_win.data.deinit();

            allocator.destroy(free_win);

            break;
        }
    }

    for (self.notifs.items, 0..) |notif, idx| {
        try notif.data.update(dt);

        if (notif.data.time == 0) {
            _ = self.notifs.orderedRemove(idx);
            break;
        }
    }

    var offset: usize = 0;
    for (self.windows.items, 0..) |_, target| {
        var found = false;
        while (!found) {
            for (self.windows.items) |window| {
                if (window.data.idx == target + offset) {
                    window.data.idx = target;
                    found = true;
                    break;
                }
            }
            offset += 1;
        }
        offset -= 1;
    }

    for (self.windows.items, 0..) |window, idx| {
        if (window.data.contents.props.close) {
            const free_win = self.windows.orderedRemove(idx);
            free_win.data.deinit();

            allocator.destroy(free_win);

            break;
        }
    }

    self.cursor.data.index = 0;
    self.cursor.data.flip = false;

    for (self.windows.items, 0..) |_, idx| {
        if (self.windows.items[idx].data.min) continue;

        const window_pos = self.windows.items[idx].data.pos;
        const pos = Rect{
            .x = window_pos.x - 10,
            .y = window_pos.y - 10,
            .w = window_pos.w + 20,
            .h = window_pos.h + 20,
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

    const screen_bounds = Rect{
        .x = 0,
        .y = 0,
        .w = graphics.Context.instance.size.x,
        .h = graphics.Context.instance.size.y,
    };

    for (self.windows.items) |window| {
        if (window.data.pos.x < 0)
            window.data.pos.x = 0;

        if (window.data.pos.y < 0)
            window.data.pos.y = 0;

        if (window.data.pos.w > screen_bounds.w)
            window.data.pos.w = screen_bounds.w;

        if (window.data.pos.h > screen_bounds.h)
            window.data.pos.h = screen_bounds.h;

        if (window.data.pos.x > screen_bounds.w - window.data.pos.w)
            window.data.pos.x = screen_bounds.w - window.data.pos.w;

        if (window.data.pos.y > screen_bounds.h - window.data.pos.h)
            window.data.pos.y = screen_bounds.h - window.data.pos.h;
    }
}

pub fn keypress(self: *GSWindowed, key: c_int, mods: c_int, down: bool) !void {
    if (self.bar.data.btn_active and !down) {
        self.bar.data.btn_active = false;

        return;
    }

    if (self.popups.items.len != 0) {
        const top_popup = self.popups.items[0];
        try top_popup.data.contents.key(key, mods, down);

        return;
    }

    if (key == glfw.KeyP and mods == (glfw.ModifierControl | glfw.ModifierShift) and down) {
        const window: Window = .atlas("win", .{
            .source = .{ .w = 1, .h = 1 },
            .pos = .{ .w = 400, .h = 500 },
            .contents = try windows_mod.tasks.init(self.shader),
            .active = true,
        });

        try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window, .center = false });

        return;
    }

    for (self.windows.items) |window| {
        if (!window.data.active) continue;

        _ = try window.data.key(key, mods, down);
    }
}

pub fn keychar(self: *GSWindowed, code: u32, mods: c_int) !void {
    if (self.bar.data.btn_active) return;

    if (self.popups.items.len != 0) {
        const top_popup = self.popups.items[0];
        try top_popup.data.contents.char(code, mods);

        return;
    }

    for (self.windows.items) |window| {
        if (!window.data.active) continue;

        return window.data.char(code, mods);
    }
}

pub fn mousepress(self: *GSWindowed, btn: c_int, kind: ClickKind) !void {
    // TODO: This function feels hacky, clean it up
    //       maybe to a state machine structure or something
    //       idk i'll research
    if (self.popups.items.len != 0) {
        if (kind == .down) {
            switch (try self.popups.items[0].data.click(self.mousepos)) {
                .Close => try events.EventManager.instance.sendEvent(window_events.EventClosePopup{ .popup_conts = self.popups.items[0].data.contents.ptr }),
                .Move => {
                    self.dragging_popup = self.popups.items[0];
                    self.dragging_mode = .Move;

                    const start = self.dragging_popup.?.data.pos;
                    self.dragging_start = .{ .x = start.x - self.mousepos.x, .y = start.y - self.mousepos.y };
                },
                .None => {},
            }
        }

        if (kind != .up)
            return;
    }

    var new_top: ?u32 = null;

    for (self.windows.items, 0..) |_, idx| {
        if (self.windows.items[idx].data.min) continue;

        const window_pos = self.windows.items[idx].data.pos;
        const pos = Rect{
            .x = window_pos.x - 10,
            .y = window_pos.y - 10,
            .w = window_pos.w + 20,
            .h = window_pos.h + 20,
        };

        if (pos.contains(self.mousepos)) {
            new_top = @as(u32, @intCast(idx));
        } else self.windows.items[idx].data.active = false;
    }

    switch (kind) {
        .double => {
            if (new_top) |top| {
                var swap = self.windows.orderedRemove(@as(usize, @intCast(top)));
                const mode = swap.data.getDragMode(self.mousepos);

                if (!swap.data.active) {
                    swap.data.active = true;
                    try swap.data.contents.focus();
                    try swap.data.contents.move(self.mousepos.x - swap.data.pos.x, self.mousepos.y - swap.data.pos.y - 36);
                    try swap.data.click(self.mousepos, btn, kind);
                }

                switch (mode) {
                    .Move => {
                        if (swap.data.full) {
                            swap.data.pos = swap.data.oldpos;
                        } else {
                            swap.data.oldpos = swap.data.pos;
                        }

                        swap.data.full = !swap.data.full;
                        try swap.data.contents.moveResize(swap.data.pos);
                    },
                    else => {},
                }

                if (self.dragging_window) |dragging| {
                    try dragging.data.contents.moveResize(dragging.data.pos);
                    self.dragging_window = null;
                }

                try self.windows.append(swap);
            }
        },
        .down => {
            switch (btn) {
                0 => {
                    if (try self.bar.data.doClick(&self.windows, self.shader, self.mousepos)) return;

                    if (new_top) |top| {
                        var swap = self.windows.orderedRemove(@as(usize, @intCast(top)));

                        if (!swap.data.active) {
                            swap.data.active = true;
                            try swap.data.contents.focus();
                            try swap.data.contents.move(self.mousepos.x - swap.data.pos.x, self.mousepos.y - swap.data.pos.y - 36);
                            try swap.data.click(self.mousepos, btn, kind);
                        }

                        const mode = swap.data.getDragMode(self.mousepos);
                        switch (mode) {
                            .Close => {
                                if (swap.data.contents.props.no_close)
                                    try self.windows.append(swap)
                                else {
                                    swap.data.deinit();

                                    allocator.destroy(swap);

                                    return;
                                }
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
                                drag: {
                                    self.dragging_mode = mode;
                                    self.dragging_window = self.windows.items[self.windows.items.len - 1];
                                    const start = self.dragging_window.?.data.pos;
                                    self.dragging_start = switch (self.dragging_mode) {
                                        .None => break :drag,
                                        .Close => break :drag,
                                        .Full => .{},
                                        .Min => break :drag,
                                        .Move => .{ .x = start.x - self.mousepos.x, .y = start.y - self.mousepos.y },
                                        .ResizeR => .{ .x = start.w - self.mousepos.x },
                                        .ResizeB => .{ .y = start.h - self.mousepos.y },
                                        .ResizeL => .{ .x = start.w + start.x },
                                        .ResizeRB => .{ .x = start.w - self.mousepos.x, .y = start.h - self.mousepos.y },
                                        .ResizeLB => .{ .x = start.w + start.x, .y = start.h - self.mousepos.y },
                                    };

                                    try swap.data.contents.moveResize(swap.data.pos);
                                }
                            },
                        }
                    }
                },
                else => {},
            }
        },
        .up => {
            if (self.dragging_window) |dragging| {
                try dragging.data.contents.moveResize(dragging.data.pos);
                self.dragging_window = null;
            }

            if (self.dragging_popup) |_| {
                self.dragging_popup = null;
            }

            self.down = false;
        },
        else => {},
    }

    for (self.windows.items) |window| {
        if (!window.data.active) continue;

        try self.desk.data.click(self.shader, null, btn, kind);

        return window.data.click(self.mousepos, btn, kind);
    }

    try self.desk.data.click(self.shader, self.mousepos, btn, kind);
}

pub fn mousemove(self: *GSWindowed, pos: Vec2) !void {
    self.mousepos = pos;

    if (self.dragging_popup) |dragging| {
        const winpos = self.mousepos.add(self.dragging_start);

        switch (self.dragging_mode) {
            .Move => {
                dragging.data.pos.x = winpos.x;
                dragging.data.pos.y = winpos.y;
            },
            else => {},
        }
    }

    if (self.dragging_window) |dragging| {
        const old = dragging.data.pos;
        const winpos = self.mousepos.add(self.dragging_start);

        switch (self.dragging_mode) {
            .None => {},
            .Close => {},
            .Full => {},
            .Min => {},
            .Move => {
                if (self.mousepos.y < 10) {
                    if (!dragging.data.full) {
                        // dont need to update dragging pos here bc its unnoticable to user

                        dragging.data.full = true;
                        dragging.data.oldpos = dragging.data.pos;
                    }
                } else {
                    if (dragging.data.full) {
                        dragging.data.full = false;
                        dragging.data.pos = dragging.data.oldpos;
                    }

                    dragging.data.pos.x = winpos.x;
                    dragging.data.pos.y = winpos.y;

                    // dont want to move the grab point if uneeded, feels
                    // weirder than not moving it when it technically should
                    // this is a fix for fullscreen grabs when the windows
                    // size shrinks immedieatly
                    if (!dragging.data.pos.contains(self.mousepos)) {
                        self.dragging_start.x = -dragging.data.oldpos.w * 0.5;
                        self.dragging_start.y = -6;
                    }
                }
            },
            .ResizeR => {
                dragging.data.pos.w = winpos.x;
            },
            .ResizeL => {
                dragging.data.pos.x = self.mousepos.x;
                dragging.data.pos.w = self.dragging_start.x - self.mousepos.x;
            },
            .ResizeB => {
                dragging.data.pos.h = winpos.y;
            },
            .ResizeRB => {
                dragging.data.pos.w = winpos.x;
                dragging.data.pos.h = winpos.y;
            },
            .ResizeLB => {
                dragging.data.pos.x = self.mousepos.x;
                dragging.data.pos.w = self.dragging_start.x - self.mousepos.x;
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
        if (dragging.data.contents.props.size.max) |max| {
            if (dragging.data.pos.w > max.x) {
                dragging.data.pos.w = old.w;
                dragging.data.pos.x = old.x;
            }
            if (dragging.data.pos.h > max.y) {
                dragging.data.pos.h = old.h;
                dragging.data.pos.y = old.y;
            }
        }
    }
    if (self.down and self.dragging_mode == .None) {
        for (self.windows.items) |window| {
            if (!window.data.active) continue;

            try window.data.contents.drag(.{
                .x = window.data.pos.w,
                .y = window.data.pos.h - 36,
            }, Vec2.sub(self.mousepos, .{
                .x = window.data.pos.x,
                .y = window.data.pos.y + 36,
            }));
        }
    }

    if (self.dragging_mode == .None) {
        for (self.windows.items) |window| {
            if (window.data.min) continue;
            try window.data.contents.move(self.mousepos.x - window.data.pos.x, self.mousepos.y - window.data.pos.y - 36);
        }
    }
}

pub fn mousescroll(self: *GSWindowed, dir: Vec2) !void {
    var new_top: ?u32 = null;

    for (self.windows.items, 0..) |_, idx| {
        if (self.windows.items[idx].data.min) continue;

        const window_pos = self.windows.items[idx].data.pos;
        const pos = Rect{
            .x = window_pos.x - 10,
            .y = window_pos.y - 10,
            .w = window_pos.w + 20,
            .h = window_pos.h + 20,
        };

        if (pos.contains(self.mousepos)) {
            new_top = @as(u32, @intCast(idx));
        }
    }

    if (new_top) |top| {
        try self.windows.items[top].data.contents.scroll(dir.x, dir.y);
    }
}
