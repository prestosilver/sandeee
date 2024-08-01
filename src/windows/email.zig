const std = @import("std");

const win = @import("../drawers/window2d.zig");
const rect = @import("../math/rects.zig");
const vecs = @import("../math/vecs.zig");
const col = @import("../math/colors.zig");
const fnt = @import("../util/font.zig");
const batch = @import("../util/spritebatch.zig");
const allocator = @import("../util/allocator.zig");
const shd = @import("../util/shader.zig");
const sprite = @import("../drawers/sprite2d.zig");
const tex = @import("../util/texture.zig");
const mail = @import("../system/mail.zig");
const popups = @import("../drawers/popup2d.zig");
const files = @import("../system/files.zig");
const window_events = @import("../events/window.zig");
const events = @import("../util/events.zig");
const vm = @import("../system/vm.zig");
const log = @import("../util/log.zig").log;

const e_data = @import("../data/email.zig");

const c = @import("../c.zig");

pub var notif: sprite.Sprite = undefined;
pub var email_manager: *mail.EmailManager = undefined;

const EmailData = struct {
    const Self = @This();

    const LoginInput = enum { Username, Password };

    backbg: sprite.Sprite,
    reply: sprite.Sprite,
    divx: sprite.Sprite,
    dive: sprite.Sprite,
    back: sprite.Sprite,
    logo: sprite.Sprite,
    sel: sprite.Sprite,
    text_box: [2]sprite.Sprite,
    button: [2]sprite.Sprite,

    shader: *shd.Shader,

    scroll_top: bool = false,
    box: usize = 0,
    viewing: ?*mail.EmailManager.Email = null,
    selected: ?*mail.EmailManager.Email = null,
    offset: *f32 = undefined,
    rowsize: f32 = 0,
    bnds: rect.Rectangle = undefined,

    login_pos: vecs.Vector2 = .{ .x = 0, .y = 0 },

    login: ?[]const u8 = null,
    login_error: ?[]const u8 = null,
    login_input: ?LoginInput = null,
    login_text: [2][]u8,

    pub fn draw(self: *Self, font_shader: *shd.Shader, bnds: *rect.Rectangle, font: *fnt.Font, props: *win.WindowContents.WindowProps) !void {
        self.bnds = bnds.*;

        if (self.login == null) {
            props.clear_color = .{ .r = 0.75, .g = 0.75, .b = 0.75 };
            if (self.login_error) |err| {
                try font.draw(.{
                    .shader = font_shader,
                    .text = err,
                    .pos = .{
                        .x = bnds.x,
                        .y = bnds.y,
                    },
                });
            }

            const center = bnds.x + @floor(bnds.w * 0.5 - 50.0);
            const center_y = bnds.y + (bnds.h * 0.5) + 150;

            self.login_pos = .{ .x = center - bnds.x, .y = center_y - bnds.y };

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.logo, self.shader, .{ .x = center - 26 - 50, .y = center_y - 250 });

            self.text_box[0].data.size.x = 200;
            self.text_box[1].data.size.x = 196;
            self.button[0].data.size.x = 100;
            self.button[1].data.size.x = 96;
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, .{ .x = center, .y = center_y - 102 });
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, .{ .x = center + 2, .y = center_y - 100 });

            try font.draw(.{
                .shader = font_shader,
                .text = "Password:",
                .pos = .{
                    .x = center - 100,
                    .y = center_y - 100,
                },
            });

            {
                const text = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.login_text[1], if (self.login_input != null and self.login_input.? == .Password) "|" else "" });
                defer allocator.alloc.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{
                        .x = center + 5,
                        .y = center_y - 100,
                    },
                });
            }

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[0], self.shader, .{ .x = center, .y = center_y - 152 });
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.text_box[1], self.shader, .{ .x = center + 2, .y = center_y - 150 });

            try font.draw(.{
                .shader = font_shader,
                .text = "Username:",
                .pos = .{
                    .x = center - 100,
                    .y = center_y - 150,
                },
            });

            {
                const text = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.login_text[0], if (self.login_input != null and self.login_input.? == .Username) "|" else "" });
                defer allocator.alloc.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{
                        .x = center + 5,
                        .y = center_y - 150,
                    },
                });
            }

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.button[0], self.shader, .{ .x = center, .y = center_y - 52 });
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.button[1], self.shader, .{ .x = center + 2, .y = center_y - 50 });

            const size = font.sizeText(.{
                .text = "Login",
            });
            const pos = .{
                .x = self.bnds.x + @floor((self.bnds.w - size.x) * 0.5),
                .y = center_y - 50,
            };
            try font.draw(.{
                .shader = font_shader,
                .text = "Login",
                .pos = pos,
            });

            return;
        }

        props.clear_color = .{ .r = 1, .g = 1, .b = 1 };

        if (props.scroll == null) {
            props.scroll = .{
                .offset_start = 0,
            };
        }

        self.offset = &props.scroll.?.value;

        if (self.scroll_top) {
            props.scroll.?.value = 0;
            self.scroll_top = false;
        }

        props.scroll.?.offset_start = if (self.viewing == null) 0 else 38;

        self.divx.data.size.y = bnds.h;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.divx, self.shader, .{ .x = bnds.x + 100, .y = bnds.y });

        self.dive.data.size.x = bnds.w - 102;

        if (self.viewing == null) {
            var y: f32 = bnds.y + 4.0 - props.scroll.?.value;

            for (email_manager.emails.items) |*email| {
                var inbox = false;

                if (std.mem.eql(u8, email.from, self.login.?)) {
                    inbox = true;

                    if (self.box != email_manager.boxes.len - 1) continue;
                } else if (email.box != self.box) continue;
                var color = col.Color{ .r = 0, .g = 0, .b = 0 };
                if (@import("builtin").mode == .Debug) {
                    if (!email_manager.getEmailVisible(email, self.login.?)) color.a = 0.5;
                } else {
                    if (!email_manager.getEmailVisible(email, self.login.?)) continue;
                }

                const text = try std.fmt.allocPrint(allocator.alloc, "{s} - {s}", .{ email.from, email.subject });
                defer allocator.alloc.free(text);

                if (email.is_complete or inbox) {
                    try font.draw(.{
                        .shader = font_shader,
                        .text = fnt.CHECK,
                        .pos = .{ .x = bnds.x + 108, .y = y - 2 },
                        .color = .{ .r = 0, .g = 1, .b = 0 },
                    });
                }

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{ .x = bnds.x + 108 + 20, .y = y - 2 },
                    .color = color,
                    .wrap = bnds.w - 108 - 20 - 20,
                    .maxlines = 1,
                });

                if (self.selected != null and email == self.selected.?) {
                    self.sel.data.size.x = bnds.w - 102;
                    self.sel.data.size.y = font.size + 8 - 2;

                    try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.sel, self.shader, .{ .x = bnds.x + 102, .y = y - 4 });
                }

                try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = y + font.size + 2 });

                y += font.size + 8;
            }

            self.rowsize = font.size + 8;

            props.scroll.?.maxy = y - bnds.y - bnds.h + props.scroll.?.value - 6;
        } else {
            self.backbg.data.size.x = bnds.w - 102;

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.backbg, self.shader, .{ .x = bnds.x + 102, .y = bnds.y - 2 });
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.reply, self.shader, .{ .x = bnds.x + 104, .y = bnds.y });
            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.back, self.shader, .{ .x = bnds.x + 144, .y = bnds.y });

            const email = self.viewing.?;

            const from = try std.fmt.allocPrint(allocator.alloc, "from: {s}", .{email.from});
            defer allocator.alloc.free(from);
            try font.draw(.{
                .shader = font_shader,
                .text = from,
                .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 },
            });

            const text = try std.fmt.allocPrint(allocator.alloc, "subject: {s}", .{email.subject});
            defer allocator.alloc.free(text);
            try font.draw(.{
                .shader = font_shader,
                .text = text,
                .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 + font.size },
            });

            const y = bnds.y + 44 + font.size * 2 - props.scroll.?.value;

            try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = bnds.y + 44 + font.size * 2 });

            const old_scissor = batch.SpriteBatch.instance.scissor;
            batch.SpriteBatch.instance.scissor.?.y = bnds.y + 48 + font.size * 2;
            batch.SpriteBatch.instance.scissor.?.h = bnds.h - 48 - font.size * 2;

            try font.draw(.{
                .shader = font_shader,
                .text = email.contents,
                .pos = .{ .x = bnds.x + 108, .y = y + 2 },
                .wrap = bnds.w - 116.0 - 20,
            });

            batch.SpriteBatch.instance.scissor = old_scissor;

            props.scroll.?.maxy = font.sizeText(.{
                .text = email.contents,
                .wrap = bnds.w - 116.0 - 20,
            }).y;
        }

        for (email_manager.boxes, 0..) |box, idx| {
            const pos = .{ .x = bnds.x + 2, .y = bnds.y + font.size * @as(f32, @floatFromInt(idx)) };

            if (idx == self.box) {
                const text = try std.fmt.allocPrint(allocator.alloc, "{s} {d:0>3}%", .{ box[0..@min(3, box.len)], email_manager.getPc(idx) });
                defer allocator.alloc.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = pos,
                });
            } else {
                try font.draw(.{
                    .shader = font_shader,
                    .text = box,
                    .pos = pos,
                });
            }
        }

        self.sel.data.size.x = 100;
        self.sel.data.size.y = font.size;

        try batch.SpriteBatch.instance.draw(sprite.Sprite, &self.sel, self.shader, .{ .x = bnds.x, .y = bnds.y + font.size * @as(f32, @floatFromInt(self.box)) });
    }

    pub fn submitFile(self: *Self) !void {
        const adds = try allocator.alloc.create(popups.all.filepick.PopupFilePick);
        adds.* = .{
            .path = try allocator.alloc.dupe(u8, files.home.name),
            .data = self,
            .submit = &submit,
        };

        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
            .popup = .{
                .texture = "win",
                .data = .{
                    .title = "Send Attachment",
                    .source = .{ .w = 1, .h = 1 },
                    .pos = rect.Rectangle.initCentered(self.bnds, 350, 125),
                    .contents = popups.PopupData.PopupContents.init(adds),
                },
            },
        });
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) return;

        if (self.login == null) {
            if (keycode == c.GLFW_KEY_TAB) {
                self.login_input = if (self.login_input) |li|
                    switch (li) {
                        .Username => .Password,
                        .Password => .Username,
                    }
                else
                    .Username;
            }

            if (keycode == c.GLFW_KEY_ENTER) {
                self.onLogin();
            }

            if (keycode == c.GLFW_KEY_BACKSPACE) {
                if (self.login_input) |input|
                    switch (input) {
                        .Username => {
                            if (self.login_text[0].len == 0) return;

                            self.login_text[0] = try allocator.alloc.realloc(
                                self.login_text[0],
                                self.login_text[0].len - 1,
                            );
                        },
                        .Password => {
                            if (self.login_text[1].len == 0) return;

                            self.login_text[1] = try allocator.alloc.realloc(
                                self.login_text[1],
                                self.login_text[1].len - 1,
                            );
                        },
                    };
            }

            return;
        }

        if (keycode == c.GLFW_KEY_R) {
            if (self.viewing) |viewing| {
                if (viewing.condition != .Submit) return;

                try self.submitFile();
                return;
            }
        }
    }

    // TODO: reimplement old
    pub fn submit_thread(conts: []const u8, cond: []const u8, good: *bool) !void {
        const idx = std.mem.indexOf(u8, cond, "=") orelse cond.len - 1;
        const name = cond[0..idx];
        if (std.mem.eql(u8, name, "conts")) {
            const target_text = cond[idx + 1 ..];
            const target_conts = std.mem.trim(u8, conts, &.{'\n'});

            good.* = std.ascii.eqlIgnoreCase(target_text, target_conts);
        } // else if (std.mem.eql(u8, name, "input")) {
        // input.clearAndFree();
        // try input.appendSlice(cond[idx + 1 ..]);
        // } else if (std.mem.eql(u8, name, "libfn")) {
        //     libfn = cond[idx + 1 ..];
        // }
        else if (std.mem.eql(u8, name, "runs")) {
            const target_text = cond[idx + 1 ..];

            // if (libfn) |fnname| {
            //     if (!std.mem.startsWith(u8, conts, "elib")) return;
            //     var library_idx: usize = 7;
            //     var start_idx: usize = 256 * @as(usize, @intCast(conts[4])) + @as(usize, @intCast(conts[5]));

            //     for (0..@as(usize, @intCast(conts[6]))) |_| {
            //         const name_len: usize = @intCast(conts[library_idx]);
            //         library_idx += 1;
            //         if (library_idx + name_len < conts.len and std.mem.eql(u8, fnname, conts[library_idx .. library_idx + name_len])) {
            //             const fnsize = @as(usize, @intCast(conts[library_idx + 1 + name_len])) * 256 + @as(usize, @intCast(conts[library_idx + 2 + name_len]));

            //             var vm_instance = try vm.VM.init(allocator.alloc, files.home, "", true);
            //             defer vm_instance.deinit();

            //             vm_instance.loadString(conts[start_idx .. start_idx + fnsize]) catch {
            //                 return;
            //             };
            //             vm_instance.return_stack[0] = .{
            //                 .function = null,
            //                 .location = vm_instance.code.?.len + 1,
            //             };
            //             vm_instance.return_rsp = 1;

            //             vm_instance.runAll() catch {
            //                 good = false;
            //                 break :blk;
            //             };

            //             const result = try vm_instance.popStack();

            //             good.* = result.data().* == .string and std.mem.eql(u8, result.data().string, target_text);

            //             break :blk;
            //         }
            //         library_idx += 1 + name_len;
            //         start_idx += @as(usize, @intCast(conts[library_idx])) * 256;
            //         library_idx += 1;
            //         start_idx += @intCast(conts[library_idx]);
            //         library_idx += 1;
            //     }

            //     good.* = false;
            //     continue;
            // }

            if (!std.mem.startsWith(u8, conts, "EEEp")) return;
            var vmInstance = try vm.VM.init(allocator.alloc, files.home, "", true);
            defer vmInstance.deinit();

            // try vmInstance.input.appendSlice(input.items);
            try vmInstance.input.append('\n');

            try vmInstance.loadString(conts[4..]);

            try vmInstance.runAll();
            const trimmed = std.mem.trimLeft(u8, vmInstance.out.items, " \n");

            good.* = std.ascii.endsWithIgnoreCase(trimmed, target_text);
        }
    }

    pub fn submit(file: ?*files.File, data: *anyopaque) !void {
        if (file) |target| {
            const self: *Self = @ptrCast(@alignCast(data));

            const conts = try target.read(null);

            if (self.viewing) |selected| {
                if (selected.condition != .Submit) return;
                var iter = std.mem.split(u8, selected.condition.Submit.req, ";");

                var good = true;
                var input = std.ArrayList(u8).init(allocator.alloc);
                defer input.deinit();

                const total = std.mem.count(u8, selected.condition.Submit.req, ";") + 1;
                var threads = try allocator.alloc.alloc(std.Thread, total);
                var outputs = try allocator.alloc.alloc(bool, total);
                defer allocator.alloc.free(threads);
                defer allocator.alloc.free(outputs);

                var idx: usize = 0;

                while (iter.next()) |cond| : (idx += 1) {
                    threads[idx] = try std.Thread.spawn(.{}, submit_thread, .{
                        conts,
                        cond,
                        &outputs[idx],
                    });
                }

                for (threads) |thread| {
                    thread.join();
                }

                for (outputs) |o| {
                    if (!o) good = false;
                }

                if (good) {
                    try email_manager.setEmailComplete(selected);
                }
            }
        }
    }

    pub fn onLogin(self: *Self) void {
        for (e_data.EMAIL_LOGINS) |login| {
            if (std.mem.eql(u8, self.login_text[0], login.user)) {
                if (std.mem.eql(u8, self.login_text[1], login.password)) {
                    self.login = login.user;
                    self.login_error = "";
                    log.debug("Logged into email `{s}`", .{login.user});
                } else {
                    self.login_error = "Invalid Password";
                }

                break;
            }
        } else {
            self.login_error = "Account dosent exist";
        }
    }

    pub fn click(self: *Self, size: vecs.Vector2, mousepos: vecs.Vector2, btn: ?i32) !void {
        if (btn == null) return;

        if (self.login == null) {
            {
                const box_bounds = rect.Rectangle{
                    .x = self.login_pos.x,
                    .y = self.login_pos.y - 102,
                    .w = 200,
                    .h = 32,
                };

                if (box_bounds.contains(mousepos)) {
                    self.login_input = .Password;
                    return;
                }
            }

            {
                const box_bounds = rect.Rectangle{
                    .x = self.login_pos.x,
                    .y = self.login_pos.y - 150,
                    .w = 200,
                    .h = 32,
                };

                if (box_bounds.contains(mousepos)) {
                    self.login_input = .Username;
                    return;
                }
            }

            {
                const btn_bounds = rect.Rectangle{
                    .x = @floor((self.bnds.w - 100) * 0.5),
                    .y = self.login_pos.y - 50,
                    .w = 100,
                    .h = 32,
                };

                if (btn_bounds.contains(mousepos)) {
                    self.onLogin();
                    return;
                }
            }

            return;
        }

        switch (btn.?) {
            0 => {
                if (self.viewing) |_| {
                    const reply_bnds = rect.Rectangle{ .x = 104, .w = 32, .h = 32 };
                    if (reply_bnds.contains(mousepos)) {
                        try self.submitFile();
                    }

                    const back_bnds = rect.Rectangle{ .x = 144, .w = 32, .h = 32 };
                    if (back_bnds.contains(mousepos)) {
                        self.viewing = null;
                        return;
                    }
                }

                const cont_bnds = rect.Rectangle{ .x = 102, .w = size.x - 102, .h = size.y };
                if (cont_bnds.contains(mousepos)) {
                    if (self.viewing != null) return;

                    var y: i32 = 2 - @as(i32, @intFromFloat(self.offset.*));

                    for (email_manager.emails.items) |*email| {
                        if (std.mem.eql(u8, email.from, self.login.?)) {
                            if (self.box != email_manager.boxes.len - 1) continue;
                        } else if (email.box != self.box) continue;

                        if (@import("builtin").mode != .Debug) {
                            if (!email_manager.getEmailVisible(email, self.login.?)) continue;
                        }

                        const bnds = rect.Rectangle{
                            .x = 102,
                            .y = @as(f32, @floatFromInt(y)),
                            .w = size.x - 102,
                            .h = self.rowsize,
                        };

                        y += @intFromFloat(self.rowsize);

                        if (bnds.contains(mousepos)) {
                            if (self.selected != null and email == self.selected.?) {
                                try email_manager.viewEmail(email);
                                self.selected = null;
                                self.viewing = email;
                                self.scroll_top = true;
                            } else {
                                self.selected = email;
                            }
                        }
                    }
                } else {
                    const bnds = rect.Rectangle{ .w = 102, .h = size.y };
                    if (bnds.contains(mousepos)) {
                        const id = mousepos.y / 24.0;

                        self.box = @as(u8, @intCast(@as(i32, @intFromFloat(id + 0.5))));

                        self.viewing = null;
                        self.scroll_top = true;

                        if (self.box < 0) {
                            self.box = 0;
                        } else if (self.box > email_manager.boxes.len - 1) {
                            self.box = email_manager.boxes.len - 1;
                        }
                    }
                }
            },
            else => {},
        }
    }

    pub fn char(self: *Self, codepoint: u32, _: i32) !void {
        if (codepoint > 128) return;

        if (self.login == null) {
            if (self.login_input) |input|
                switch (input) {
                    .Username => {
                        const old = self.login_text[0];
                        defer allocator.alloc.free(old);
                        self.login_text[0] = try std.mem.concat(allocator.alloc, u8, &.{
                            self.login_text[0],
                            &.{@as(u8, @intCast(codepoint))},
                        });
                    },
                    .Password => {
                        const old = self.login_text[1];
                        defer allocator.alloc.free(old);
                        self.login_text[1] = try std.mem.concat(allocator.alloc, u8, &.{
                            self.login_text[1],
                            &.{@as(u8, @intCast(codepoint))},
                        });
                    },
                };
        }
    }

    pub fn deinit(self: *Self) void {
        for (self.login_text) |i|
            allocator.alloc.free(i);

        allocator.alloc.destroy(self);
    }
};

pub fn init(shader: *shd.Shader) !win.WindowContents {
    const self = try allocator.alloc.create(EmailData);

    self.* = .{
        .divx = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2 },
            },
        },
        .dive = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .y = 2 },
            },
        },
        .logo = .{
            .texture = "email-logo",
            .data = .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 256, .y = 72 },
            },
        },
        .sel = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .y = 6 },
            },
        },
        .reply = .{
            .texture = "icons",
            .data = .{
                .source = .{ .x = 1.0 / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            },
        },
        .back = .{
            .texture = "icons",
            .data = .{
                .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 32, .y = 32 },
            },
        },
        .backbg = .{
            .texture = "ui",
            .data = .{
                .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
                .size = .{ .x = 28, .y = 40 },
            },
        },
        .text_box = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 32 },
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 28 },
                },
            },
        },
        .button = .{
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 32 },
                },
            },
            .{
                .texture = "ui",
                .data = .{
                    .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                    .size = .{ .x = 2, .y = 28 },
                },
            },
        },
        .shader = shader,
        .login_text = [2][]u8{ try allocator.alloc.alloc(u8, 0), try allocator.alloc.alloc(u8, 0) },
    };

    self.button[1].data.color = .{ .r = 0.75, .g = 0.75, .b = 0.75 };
    self.sel.data.color = .{ .r = 1, .g = 0, .b = 0 };

    return win.WindowContents.init(self, "email", fnt.EEE ++ "Mail", .{ .r = 0.75, .g = 0.75, .b = 0.75 });
}
