const std = @import("std");
const glfw = @import("glfw");
const builtin = @import("builtin");

const windows = @import("../windows.zig");
const drawers = @import("../drawers.zig");
const system = @import("../system.zig");
const events = @import("../events.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const data = @import("../data.zig");

const Window = drawers.Window;
const Sprite = drawers.Sprite;
const Popup = drawers.Popup;

const Rect = math.Rect;
const Vec2 = math.Vec2;
const Color = math.Color;

const popups = windows.popups;

const SpriteBatch = util.SpriteBatch;
const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const allocator = util.allocator;
const log = util.log;

const Vm = system.Vm;
const mail = system.mail;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;

const strings = data.strings;

// TODO: remove var
pub var notif: Sprite = undefined;

const EmailData = struct {
    const Self = @This();

    const LoginInput = enum { Username, Password };

    backbg: Sprite,
    reply: Sprite,
    divx: Sprite,
    dive: Sprite,
    back: Sprite,
    logo: Sprite,
    sel: Sprite,
    text_box: [2]Sprite,
    button: [2]Sprite,

    shader: *Shader,

    scroll_top: bool = false,
    box: usize = 0,
    viewing: ?*mail.EmailManager.Email = null,
    selected: ?*mail.EmailManager.Email = null,
    offset: *f32 = undefined,
    rowsize: f32 = 0,
    bnds: Rect = .{ .w = 0, .h = 0 },

    login_pos: Vec2 = .{ .x = 0, .y = 0 },

    login: ?[]const u8 = null,
    login_error: ?[]const u8 = null,
    login_input: ?LoginInput = null,
    login_text: [2][]u8,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
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

            try SpriteBatch.global.draw(Sprite, &self.logo, self.shader, .{ .x = center - 26 - 50, .y = center_y - 250 });

            self.text_box[0].data.size.x = 200;
            self.text_box[1].data.size.x = 196;
            self.button[0].data.size.x = 100;
            self.button[1].data.size.x = 96;
            try SpriteBatch.global.draw(Sprite, &self.text_box[0], self.shader, .{ .x = center, .y = center_y - 102 });
            try SpriteBatch.global.draw(Sprite, &self.text_box[1], self.shader, .{ .x = center + 2, .y = center_y - 100 });

            try font.draw(.{
                .shader = font_shader,
                .text = "Password:",
                .pos = .{
                    .x = center - 100,
                    .y = center_y - 100,
                },
            });

            {
                const text = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.login_text[1], if (self.login_input != null and self.login_input.? == .Password) "|" else "" });
                defer allocator.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{
                        .x = center + 5,
                        .y = center_y - 100,
                    },
                });
            }

            try SpriteBatch.global.draw(Sprite, &self.text_box[0], self.shader, .{ .x = center, .y = center_y - 152 });
            try SpriteBatch.global.draw(Sprite, &self.text_box[1], self.shader, .{ .x = center + 2, .y = center_y - 150 });

            try font.draw(.{
                .shader = font_shader,
                .text = "Username:",
                .pos = .{
                    .x = center - 100,
                    .y = center_y - 150,
                },
            });

            {
                const text = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.login_text[0], if (self.login_input != null and self.login_input.? == .Username) "|" else "" });
                defer allocator.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{
                        .x = center + 5,
                        .y = center_y - 150,
                    },
                });
            }

            try SpriteBatch.global.draw(Sprite, &self.button[0], self.shader, .{ .x = center, .y = center_y - 52 });
            try SpriteBatch.global.draw(Sprite, &self.button[1], self.shader, .{ .x = center + 2, .y = center_y - 50 });

            const size = font.sizeText(.{
                .text = "Login",
            });

            try font.draw(.{
                .shader = font_shader,
                .text = "Login",
                .pos = .{
                    .x = self.bnds.x + @floor((self.bnds.w - size.x) * 0.5),
                    .y = center_y - 50,
                },
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

        try SpriteBatch.global.draw(Sprite, &self.divx, self.shader, .{ .x = bnds.x + 100, .y = bnds.y });

        self.dive.data.size.x = bnds.w - 102;

        if (self.viewing == null) {
            var y: f32 = bnds.y + 4.0 - props.scroll.?.value;

            for (mail.EmailManager.instance.emails.items) |*email| {
                var inbox = false;

                if (std.mem.eql(u8, email.from, self.login.?)) {
                    inbox = true;

                    if (self.box != mail.EmailManager.instance.boxes.len - 1) continue;
                } else if (email.box != self.box) continue;
                var color = Color{ .r = 0, .g = 0, .b = 0 };
                if (builtin.mode == .Debug) {
                    if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) color.a = 0.5;
                } else {
                    if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) continue;
                }

                const text = try std.fmt.allocPrint(allocator, "{s} - {s}", .{ email.from, email.subject });
                defer allocator.free(text);

                if (email.is_complete or inbox) {
                    try font.draw(.{
                        .shader = font_shader,
                        .text = strings.CHECK,
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

                    try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 102, .y = y - 4 });
                }

                try SpriteBatch.global.draw(Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = y + font.size + 2 });

                y += font.size + 8;
            }

            self.rowsize = font.size + 8;

            props.scroll.?.maxy = y - bnds.y - bnds.h + props.scroll.?.value - 6;
        } else {
            self.backbg.data.size.x = bnds.w - 102;

            try SpriteBatch.global.draw(Sprite, &self.backbg, self.shader, .{ .x = bnds.x + 102, .y = bnds.y - 2 });
            try SpriteBatch.global.draw(Sprite, &self.reply, self.shader, .{ .x = bnds.x + 104, .y = bnds.y });
            try SpriteBatch.global.draw(Sprite, &self.back, self.shader, .{ .x = bnds.x + 144, .y = bnds.y });

            const email = self.viewing.?;

            const from = try std.fmt.allocPrint(allocator, "from: {s}", .{email.from});
            defer allocator.free(from);
            try font.draw(.{
                .shader = font_shader,
                .text = from,
                .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 },
            });

            const text = try std.fmt.allocPrint(allocator, "subject: {s}", .{email.subject});
            defer allocator.free(text);
            try font.draw(.{
                .shader = font_shader,
                .text = text,
                .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 + font.size },
            });

            const y = bnds.y + 44 + font.size * 2 - props.scroll.?.value;

            try SpriteBatch.global.draw(Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = bnds.y + 44 + font.size * 2 });

            {
                const old_scissor = SpriteBatch.global.scissor;
                defer SpriteBatch.global.scissor = old_scissor;

                SpriteBatch.global.scissor.?.y = bnds.y + 48 + font.size * 2;
                SpriteBatch.global.scissor.?.h = bnds.h - 48 - font.size * 2;

                try font.draw(.{
                    .shader = font_shader,
                    .text = email.contents,
                    .pos = .{ .x = bnds.x + 108, .y = y + 2 },
                    .wrap = bnds.w - 116.0 - 20,
                });
            }

            props.scroll.?.maxy = font.sizeText(.{
                .text = email.contents,
                .wrap = bnds.w - 116.0 - 20,
            }).y;
        }

        for (mail.EmailManager.instance.boxes, 0..) |box, idx| {
            if (idx == self.box) {
                const text = try std.fmt.allocPrint(allocator, "{s} {d:0>3}%", .{ box[0..@min(3, box.len)], mail.EmailManager.instance.getPc(idx) });
                defer allocator.free(text);

                try font.draw(.{
                    .shader = font_shader,
                    .text = text,
                    .pos = .{
                        .x = bnds.x + 2,
                        .y = bnds.y + font.size * @as(f32, @floatFromInt(idx)),
                    },
                });
            } else {
                try font.draw(.{
                    .shader = font_shader,
                    .text = box,
                    .pos = .{
                        .x = bnds.x + 2,
                        .y = bnds.y + font.size * @as(f32, @floatFromInt(idx)),
                    },
                });
            }
        }

        self.sel.data.size.x = 100;
        self.sel.data.size.y = font.size;

        try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x, .y = bnds.y + font.size * @as(f32, @floatFromInt(self.box)) });
    }

    pub fn submitFile(self: *Self) !void {
        const home = try files.FolderLink.resolve(.home);

        const adds = try allocator.create(popups.filepick.PopupFilePick);
        adds.* = .{
            .path = try allocator.dupe(u8, home.name),
            .data = self,
            .submit = @ptrCast(&submit),
        };

        try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
            .popup = .atlas("win", .{
                .title = "Send Attachment",
                .source = .{ .w = 1, .h = 1 },
                .pos = .initCentered(self.bnds, 350, 125),
                .contents = .init(adds),
            }),
        });
    }

    pub fn key(self: *Self, keycode: i32, _: i32, down: bool) !void {
        if (!down) return;

        if (self.login == null) {
            if (keycode == glfw.KeyTab) {
                self.login_input = if (self.login_input) |li|
                    switch (li) {
                        .Username => .Password,
                        .Password => .Username,
                    }
                else
                    .Username;
            }

            if (keycode == glfw.KeyEnter) {
                self.onLogin();
            }

            if (keycode == glfw.KeyBackspace) {
                if (self.login_input) |input|
                    switch (input) {
                        .Username => {
                            if (self.login_text[0].len == 0) return;

                            self.login_text[0] = try allocator.realloc(
                                self.login_text[0],
                                self.login_text[0].len - 1,
                            );
                        },
                        .Password => {
                            if (self.login_text[1].len == 0) return;

                            self.login_text[1] = try allocator.realloc(
                                self.login_text[1],
                                self.login_text[1].len - 1,
                            );
                        },
                    };
            }

            return;
        }

        if (keycode == glfw.KeyR) {
            if (self.viewing) |viewing| {
                for (viewing.condition) |condition| {
                    if (condition != .SubmitContains and condition != .SubmitRuns and condition != .SubmitLib) return;

                    try self.submitFile();
                    return;
                }
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

            //             var vm_instance = try Vm.init(allocator, files.home, "", true);
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
            var vmInstance = try Vm.init(allocator, files.home, "", true);
            defer vmInstance.deinit();

            // try vmInstance.input.appendSlice(input.items);
            try vmInstance.input.append('\n');

            try vmInstance.loadString(conts[4..]);

            try vmInstance.runAll();
            const trimmed = std.mem.trimLeft(u8, vmInstance.out.items, " \n");

            good.* = std.ascii.endsWithIgnoreCase(trimmed, target_text);
        }
    }

    pub fn submit(file: ?*files.File, self: *Self) !void {
        if (file) |target| {
            const conts = try target.read(null);

            if (self.viewing) |selected| {
                var good = true;

                for (selected.condition) |condition| {
                    switch (condition) {
                        .SubmitContains => |contains| {
                            const target_text = contains.conts;
                            const target_conts = std.mem.trim(u8, conts, &.{'\n'});

                            good = good and std.ascii.eqlIgnoreCase(target_text, target_conts);
                        },
                        .SubmitRuns => |runs| blk: {
                            if (!std.mem.startsWith(u8, conts, "EEEp")) break :blk;

                            var vm_instance: Vm = .init(allocator, .home, &.{}, true);
                            defer vm_instance.deinit();

                            if (runs.input) |input|
                                try vm_instance.input.appendSlice(input);
                            try vm_instance.input.append('\n');

                            try vm_instance.loadString(conts[4..]);
                            try vm_instance.runAll();
                            const trimmed = std.mem.trimLeft(u8, vm_instance.out.items, " \n");

                            good = good and std.ascii.eqlIgnoreCase(trimmed, runs.conts);
                        },
                        .SubmitLib => |runs| blk: {
                            if (!std.mem.startsWith(u8, conts, "elib")) break :blk;
                            var library_idx: usize = 7;
                            var start_idx: usize = 256 * @as(usize, @intCast(conts[4])) + @as(usize, @intCast(conts[5]));

                            for (0..conts[6]) |_| {
                                const name_len: usize = @intCast(conts[library_idx]);
                                library_idx += 1;
                                if (library_idx + name_len < conts.len and std.mem.eql(u8, runs.libfn, conts[library_idx .. library_idx + name_len])) {
                                    const fnsize = @as(usize, @intCast(conts[library_idx + 1 + name_len])) * 256 + @as(usize, @intCast(conts[library_idx + 2 + name_len]));

                                    var vm_instance: Vm = .init(allocator, .home, &.{}, true);
                                    defer vm_instance.deinit();

                                    try vm_instance.loadString(conts[start_idx .. start_idx + fnsize]);
                                    vm_instance.return_stack[0] = .{
                                        .function = null,
                                        .location = vm_instance.code.?.len + 1,
                                    };
                                    vm_instance.return_rsp = 1;

                                    try vm_instance.runAll();

                                    const result = try vm_instance.popStack();

                                    var result_string: []const u8 = &.{};
                                    defer allocator.free(result_string);
                                    if (result.data().* == .value) {
                                        allocator.free(result_string);
                                        result_string = try std.fmt.allocPrint(allocator, "{}", .{result.data().value});
                                    } else if (result.data().* == .string) {
                                        allocator.free(result_string);
                                        result_string = try std.fmt.allocPrint(allocator, "{f}", .{result.data().string});
                                    }

                                    good = good and std.ascii.eqlIgnoreCase(result_string, runs.conts);

                                    break :blk;
                                }

                                library_idx += 1 + name_len;
                                start_idx += @as(usize, @intCast(conts[library_idx])) * 256;
                                library_idx += 1;
                                start_idx += @intCast(conts[library_idx]);
                                library_idx += 1;
                            }
                        },
                        else => {},
                    }
                }

                if (good) {
                    try mail.EmailManager.instance.setEmailComplete(selected);
                }

                // var iter = std.mem.split(u8, selected.condition.Submit.req, ";");

                // var good = true;
                // var input = std.ArrayList(u8).init(allocator);
                // defer input.deinit();

                // const total = std.mem.count(u8, selected.condition.Submit.req, ";") + 1;
                // var threads = try allocator(std.Thread, total);
                // var outputs = try allocator(bool, total);
                // defer allocator.free(threads);
                // defer allocator.free(outputs);

                // var idx: usize = 0;

                // while (iter.next()) |cond| : (idx += 1) {
                //     threads[idx] = try std.Thread.spawn(.{}, submit_thread, .{
                //         conts,
                //         cond,
                //         &outputs[idx],
                //     });
                // }

                // for (threads) |thread| {
                //     thread.join();
                // }

                // for (outputs) |o| {
                //     if (!o) good = false;
                // }
            }
        }
    }

    pub fn onLogin(self: *Self) void {
        for (data.email.LOGINS) |login| {
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

    pub fn click(self: *Self, size: Vec2, mousepos: Vec2, btn: ?i32) !void {
        if (btn == null) return;

        if (self.login == null) {
            {
                const box_bounds = Rect{
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
                const box_bounds = Rect{
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
                const btn_bounds = Rect{
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
                    const reply_bnds = Rect{ .x = 104, .w = 32, .h = 32 };
                    if (reply_bnds.contains(mousepos)) {
                        try self.submitFile();
                    }

                    const back_bnds = Rect{ .x = 144, .w = 32, .h = 32 };
                    if (back_bnds.contains(mousepos)) {
                        self.viewing = null;
                        return;
                    }
                }

                const cont_bnds = Rect{ .x = 102, .w = size.x - 102, .h = size.y };
                if (cont_bnds.contains(mousepos)) {
                    if (self.viewing != null) return;

                    var y: i32 = 2 - @as(i32, @intFromFloat(self.offset.*));

                    for (mail.EmailManager.instance.emails.items) |*email| {
                        if (std.mem.eql(u8, email.from, self.login.?)) {
                            if (self.box != mail.EmailManager.instance.boxes.len - 1) continue;
                        } else if (email.box != self.box) continue;

                        if (builtin.mode != .Debug) {
                            if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) continue;
                        }

                        const bnds = Rect{
                            .x = 102,
                            .y = @as(f32, @floatFromInt(y)),
                            .w = size.x - 102,
                            .h = self.rowsize,
                        };

                        y += @intFromFloat(self.rowsize);

                        if (bnds.contains(mousepos)) {
                            if (self.selected != null and email == self.selected.?) {
                                try mail.EmailManager.instance.viewEmail(email);
                                self.selected = null;
                                self.viewing = email;
                                self.scroll_top = true;
                            } else {
                                self.selected = email;
                            }
                        }
                    }
                } else {
                    const bnds = Rect{ .w = 102, .h = size.y };
                    if (bnds.contains(mousepos)) {
                        const id = mousepos.y / 24.0;

                        self.box = @as(u8, @intCast(@as(i32, @intFromFloat(id + 0.5))));

                        self.viewing = null;
                        self.scroll_top = true;

                        if (self.box < 0) {
                            self.box = 0;
                        } else if (self.box > mail.EmailManager.instance.boxes.len - 1) {
                            self.box = mail.EmailManager.instance.boxes.len - 1;
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
                        defer allocator.free(old);
                        self.login_text[0] = try std.mem.concat(allocator, u8, &.{
                            self.login_text[0],
                            &.{@as(u8, @intCast(codepoint))},
                        });
                    },
                    .Password => {
                        const old = self.login_text[1];
                        defer allocator.free(old);
                        self.login_text[1] = try std.mem.concat(allocator, u8, &.{
                            self.login_text[1],
                            &.{@as(u8, @intCast(codepoint))},
                        });
                    },
                };
        }
    }

    pub fn deinit(self: *Self) void {
        for (self.login_text) |i|
            allocator.free(i);

        allocator.destroy(self);
    }
};

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(EmailData);

    self.* = .{
        .divx = .atlas("ui", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 2 },
        }),
        .dive = .atlas("ui", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .y = 2 },
        }),
        .logo = .atlas("email-logo", .{
            .source = .{ .w = 1, .h = 1 },
            .size = .{ .x = 256, .y = 72 },
        }),
        .sel = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .y = 6 },
            .color = .{ .r = 1, .g = 0, .b = 0 },
        }),
        .reply = .atlas("icons", .{
            .source = .{ .x = 1.0 / 8.0, .y = 1.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 32, .y = 32 },
        }),
        .back = .atlas("icons", .{
            .source = .{ .x = 3.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 32, .y = 32 },
        }),
        .backbg = .atlas("ui", .{
            .source = .{ .x = 4.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 4.0 / 8.0 },
            .size = .{ .x = 28, .y = 40 },
        }),
        .text_box = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 32 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 28 },
            }),
        },
        .button = .{
            .atlas("ui", .{
                .source = .{ .x = 2.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 32 },
            }),
            .atlas("ui", .{
                .source = .{ .x = 3.0 / 8.0, .y = 3.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
                .size = .{ .x = 2, .y = 28 },
                .color = .{ .r = 0.75, .g = 0.75, .b = 0.75 },
            }),
        },
        .shader = shader,
        .login_text = [2][]u8{ &.{}, &.{} },
    };

    return Window.Data.WindowContents.init(self, "email", strings.EEE ++ "Mail", .{ .r = 0.75, .g = 0.75, .b = 0.75 });
}
