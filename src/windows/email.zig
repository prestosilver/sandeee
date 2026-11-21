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
const ui = @import("../ui.zig");

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
const ClickKind = events.input.ClickKind;
const window_events = events.windows;

const strings = data.strings;

// TODO: remove var
pub var notif: Sprite = undefined;

const EmailData = struct {
    const Self = @This();

    const LoginInput = enum { username, password };

    ui_context: ui.Context,
    ui_root: ui.Panel,

    ui_login_logo: ui.Icon,
    ui_login_root: ui.Panel,
    ui_login_error: ui.Label,
    ui_login_submit: ui.Button,
    ui_login_username: ui.Input,
    ui_login_password: ui.Input,

    ui_list_root: ui.Panel,
    ui_list_scroll: ui.Scroll,
    ui_list_scroll_root: ui.Panel,

    ui_list_text: ui.Label,

    backbg: Sprite,
    reply: Sprite,
    divx: Sprite,
    dive: Sprite,
    back: Sprite,
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

    login: ?[]const u8 = null,

    pub fn draw(self: *Self, font_shader: *Shader, bnds: *Rect, font: *Font, props: *Window.Data.WindowContents.WindowProps) !void {
        self.bnds = bnds.*;

        self.ui_context.font_shader = font_shader;
        self.ui_context.font = font;

        props.clear_color = .gray(0.75);

        self.ui_context.arrange();
        self.ui_context.draw(bnds.getCorner(.top_left));

        // if (self.login == null) {
        //     return;
        // }

        // props.clear_color = .white;

        // if (props.scroll == null) {
        //     props.scroll = .{
        //         .offset_start = 0,
        //     };
        // }

        // self.offset = &props.scroll.?.value;

        // if (self.scroll_top) {
        //     props.scroll.?.value = 0;
        //     self.scroll_top = false;
        // }

        // props.scroll.?.offset_start = if (self.viewing == null) 0 else 38;

        // self.divx.data.size.y = bnds.h;

        // try SpriteBatch.global.draw(Sprite, &self.divx, self.shader, .{ .x = bnds.x + 100, .y = bnds.y });

        // self.dive.data.size.x = bnds.w - 102;

        // if (self.viewing == null) {
        //     var y: f32 = bnds.y + 4.0 - props.scroll.?.value;

        //     for (mail.EmailManager.instance.emails.items) |*email| {
        //         var inbox = false;

        //         if (std.mem.eql(u8, email.from, self.login.?)) {
        //             inbox = true;

        //             if (self.box != mail.EmailManager.instance.boxes.items.len - 1) continue;
        //         } else if (email.box != self.box) continue;
        //         var color: Color = .black;
        //         if (builtin.mode == .debug) {
        //             if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) color.a = 0.5;
        //         } else {
        //             if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) continue;
        //         }

        //         const text = try allocator.print("{s} - {s}", .{ email.from, email.subject });
        //         defer allocator.free(text);

        //         if (email.is_complete or inbox) {
        //             try font.draw(.{
        //                 .shader = font_shader,
        //                 .text = strings.CHECK,
        //                 .pos = .{ .x = bnds.x + 108, .y = y - 2 },
        //                 .color = .green,
        //             });
        //         }

        //         try font.draw(.{
        //             .shader = font_shader,
        //             .text = text,
        //             .pos = .{ .x = bnds.x + 108 + 20, .y = y - 2 },
        //             .color = color,
        //             .wrap = bnds.w - 108 - 20 - 20,
        //             .maxlines = 1,
        //         });

        //         if (self.selected != null and email == self.selected.?) {
        //             self.sel.data.size.x = bnds.w - 102;
        //             self.sel.data.size.y = font.size + 8 - 2;

        //             try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x + 102, .y = y - 4 });
        //         }

        //         try SpriteBatch.global.draw(Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = y + font.size + 2 });

        //         y += font.size + 8;
        //     }

        //     self.rowsize = font.size + 8;

        //     props.scroll.?.maxy = y - bnds.y - bnds.h + props.scroll.?.value - 6;
        // } else {
        //     self.backbg.data.size.x = bnds.w - 102;

        //     try SpriteBatch.global.draw(Sprite, &self.backbg, self.shader, .{ .x = bnds.x + 102, .y = bnds.y - 2 });
        //     try SpriteBatch.global.draw(Sprite, &self.reply, self.shader, .{ .x = bnds.x + 104, .y = bnds.y });
        //     try SpriteBatch.global.draw(Sprite, &self.back, self.shader, .{ .x = bnds.x + 144, .y = bnds.y });

        //     const email = self.viewing.?;

        //     const from = try allocator.print("from: {s}", .{email.from});
        //     defer allocator.free(from);
        //     try font.draw(.{
        //         .shader = font_shader,
        //         .text = from,
        //         .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 },
        //     });

        //     const subject = try allocator.print("subject: {s}", .{email.subject});
        //     defer allocator.free(subject);
        //     try font.draw(.{
        //         .shader = font_shader,
        //         .text = subject,
        //         .pos = .{ .x = bnds.x + 108, .y = bnds.y + 44 + font.size },
        //     });

        //     const y = bnds.y + 44 + font.size * 2 - props.scroll.?.value;

        //     try SpriteBatch.global.draw(Sprite, &self.dive, self.shader, .{ .x = bnds.x + 102, .y = bnds.y + 44 + font.size * 2 });

        //     {
        //         const old_scissor = SpriteBatch.global.scissor;
        //         defer SpriteBatch.global.scissor = old_scissor;

        //         SpriteBatch.global.scissor.?.y = bnds.y + 48 + font.size * 2;
        //         SpriteBatch.global.scissor.?.h = bnds.h - 48 - font.size * 2;

        //         try font.draw(.{
        //             .shader = font_shader,
        //             .text = email.contents,
        //             .pos = .{ .x = bnds.x + 108, .y = y + 2 },
        //             .wrap = bnds.w - 116.0 - 20,
        //         });
        //     }

        //     props.scroll.?.maxy = font.sizeText(.{
        //         .text = email.contents,
        //         .wrap = bnds.w - 116.0 - 20,
        //     }).y;
        // }

        // for (mail.EmailManager.instance.boxes.items, 0..) |box, idx| {
        //     if (idx == self.box) {
        //         const text = try allocator.print("{s} {d:0>3}%", .{ box[0..@min(3, box.len)], mail.EmailManager.instance.getPc(idx) });
        //         defer allocator.free(text);

        //         try font.draw(.{
        //             .shader = font_shader,
        //             .text = text,
        //             .pos = .{
        //                 .x = bnds.x + 2,
        //                 .y = bnds.y + font.size * @as(f32, @floatFromInt(idx)),
        //             },
        //         });
        //     } else {
        //         try font.draw(.{
        //             .shader = font_shader,
        //             .text = box,
        //             .pos = .{
        //                 .x = bnds.x + 2,
        //                 .y = bnds.y + font.size * @as(f32, @floatFromInt(idx)),
        //             },
        //         });
        //     }
        // }

        // self.sel.data.size.x = 100;
        // self.sel.data.size.y = font.size;

        // try SpriteBatch.global.draw(Sprite, &self.sel, self.shader, .{ .x = bnds.x, .y = bnds.y + font.size * @as(f32, @floatFromInt(self.box)) });
    }

    pub fn submitFile(self: *Self) !void {
        const home = try files.FolderLink.resolve(.home);

        const adds = try allocator.create(popups.filepick.PopupFilePick);
        adds.* = .{
            .path = .fromOwnedSlice(allocator, try allocator.dupe(u8, home.name)),
            .data = self,
            .submit = @ptrCast(&submit),
        };

        try events.EventManager.event_popup_create.send(.{
            .popup = .atlas("win", .{
                .title = "Send Attachment",
                .source = .{ .w = 1, .h = 1 },
                .pos = .initCentered(self.bnds, 350, 125),
                .contents = .init(adds),
            }),
        });
    }

    pub fn key(self: *Self, keycode: i32, mods: i32, down: bool) !void {
        self.ui_context.keyEvent(keycode, mods, down);

        // if (!down) return;

        // if (self.login == null)
        //     return;

        // if (keycode == glfw.KeyR) {
        //     if (self.viewing) |viewing| {
        //         for (viewing.condition) |condition| {
        //             if (condition != .submit_contains and condition != .submit_runs and condition != .submit_lib) return;

        //             try self.submitFile();
        //             return;
        //         }
        //     }
        // }
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
                        .submit_contains => |contains| {
                            const target_text = contains.conts;
                            const target_conts = std.mem.trim(u8, conts, &.{'\n'});

                            good = good and std.ascii.eqlIgnoreCase(target_text, target_conts);
                        },
                        .submit_runs => |runs| blk: {
                            if (!std.mem.startsWith(u8, conts, "EEEp")) break :blk;

                            const name = try allocator.dupe(u8, "runs.eep");
                            const args = try allocator.dupe([]const u8, &.{name});

                            var vm_instance: Vm = .init(allocator, .home, args, true);
                            defer vm_instance.deinit();

                            if (runs.input) |input|
                                try vm_instance.input.appendSlice(input);
                            try vm_instance.input.append('\n');

                            try vm_instance.loadString(conts[4..]);
                            try vm_instance.runAll();
                            const trimmed = std.mem.trimStart(u8, vm_instance.out.items, " \n");

                            good = good and std.ascii.eqlIgnoreCase(trimmed, runs.conts);
                        },
                        .submit_lib => |runs| blk: {
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
                                        result_string = try allocator.print("{}", .{result.data().value});
                                    } else if (result.data().* == .string) {
                                        allocator.free(result_string);
                                        result_string = try allocator.print("{f}", .{result.data().string});
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
            if (std.mem.eql(u8, self.ui_login_username.input.items, login.user)) {
                if (std.mem.eql(u8, self.ui_login_password.input.items, login.password)) {
                    self.login = login.user;
                    self.ui_login_error.setText("");
                    log.debug("Logged into email as `{s}`", .{login.user});
                    self.ui_login_root.base.setVisible(false);
                    self.ui_list_root.base.setVisible(true);
                } else {
                    self.ui_login_error.setText("Invalid Password");
                }

                break;
            }
        } else {
            std.log.info("Email does not exist: `{s}`", .{self.ui_login_username.input.items});
            self.ui_login_error.setText("Account dosent exist");
        }
    }

    pub fn click(self: *Self, size: Vec2, mousepos: Vec2, btn: i32, kind: ClickKind) !void {
        self.ui_context.mouseClick(kind, btn);

        _ = size;
        _ = mousepos;

        // if (kind == .down or kind == .up) return;

        // if (self.login == null)
        //     return;

        // switch (btn) {
        //     0 => {
        //         if (self.viewing) |_| {
        //             if (kind == .single) {
        //                 const reply_bnds = Rect{ .x = 104, .w = 32, .h = 32 };
        //                 if (reply_bnds.contains(mousepos)) {
        //                     try self.submitFile();
        //                 }

        //                 const back_bnds = Rect{ .x = 144, .w = 32, .h = 32 };
        //                 if (back_bnds.contains(mousepos)) {
        //                     self.viewing = null;
        //                     return;
        //                 }
        //             }
        //         }

        //         const cont_bnds = Rect{ .x = 102, .w = size.x - 102, .h = size.y };
        //         if (cont_bnds.contains(mousepos)) {
        //             if (self.viewing != null) return;

        //             var y: i32 = 2 - @as(i32, @intFromFloat(self.offset.*));

        //             for (mail.EmailManager.instance.emails.items) |*email| {
        //                 if (std.mem.eql(u8, email.from, self.login.?)) {
        //                     if (self.box != mail.EmailManager.instance.boxes.items.len - 1) continue;
        //                 } else if (email.box != self.box) continue;

        //                 if (builtin.mode != .debug) {
        //                     if (!mail.EmailManager.instance.getEmailVisible(email, self.login.?)) continue;
        //                 }

        //                 const bnds = Rect{
        //                     .x = 102,
        //                     .y = @as(f32, @floatFromInt(y)),
        //                     .w = size.x - 102,
        //                     .h = self.rowsize,
        //                 };

        //                 y += @intFromFloat(self.rowsize);

        //                 if (bnds.contains(mousepos)) {
        //                     if (kind == .double) {
        //                         try mail.EmailManager.instance.viewEmail(email);
        //                         self.selected = null;
        //                         self.viewing = email;
        //                         self.scroll_top = true;
        //                     } else if (kind == .single) {
        //                         self.selected = email;
        //                     }
        //                 }
        //             }
        //         } else {
        //             const bnds = Rect{ .w = 102, .h = size.y };
        //             if (bnds.contains(mousepos)) {
        //                 const id = mousepos.y / 24.0;

        //                 self.box = @as(u8, @intCast(@as(i32, @intFromFloat(id + 0.5))));

        //                 self.viewing = null;
        //                 self.scroll_top = true;

        //                 if (kind == .single) {
        //                     if (self.box < 0) {
        //                         self.box = 0;
        //                     } else if (self.box > mail.EmailManager.instance.boxes.items.len - 1) {
        //                         self.box = mail.EmailManager.instance.boxes.items.len - 1;
        //                     }
        //                 }
        //             }
        //         }
        //     },
        //     else => {},
        // }
    }

    pub fn scroll(self: *Self, x: f32, y: f32) void {
        self.ui_context.mouseWheel(.{ .x = x, .y = y });
    }

    pub fn move(self: *Self, x: f32, y: f32) void {
        self.ui_context.mouseMove(.{ .x = x, .y = y });
    }

    pub fn moveResize(self: *Self, bounds: Rect) void {
        self.ui_context.resize(.{
            .x = @intFromFloat(bounds.w - 12),
            .y = @intFromFloat(bounds.h - 40),
        });
    }

    pub fn char(self: *Self, char_string: []const u8, _: i32) !void {
        self.ui_context.textInput(char_string);
    }

    pub fn deinit(self: *Self) void {
        allocator.destroy(self);
    }
};

fn clickLogin(_: *ui.Element, _: *ui.Context.Event, userdata: *anyopaque) bool {
    const self: *EmailData = @ptrCast(@alignCast(userdata));

    self.onLogin();

    return true;
}

pub fn init(shader: *Shader) !Window.Data.WindowContents {
    const self = try allocator.create(EmailData);

    self.* = .{
        .ui_root = .{
            .base = .init(&self.ui_context, "root", ui.Panel, .{
                .desired_size = .{ .w = 600, .h = 400 },
            }),
            .flags = .{
                .direction = .column,
                .content_align = .center,
                .wrap = true,
                .justify = .center,
            },
        },
        .ui_login_root = .{
            .base = .init(&self.ui_context, "login_root", ui.Panel, .{}),
            .flags = .{
                .direction = .column,
                .content_align = .center,
                .wrap = true,
                .justify = .center,
            },
        },
        .ui_login_logo = .{
            .base = .init(&self.ui_context, "logo", ui.Icon, .{}),
            .sprite = .atlas("email-logo", .{
                .source = .{ .w = 1, .h = 1 },
                .size = .{ .x = 256, .y = 72 },
            }),
        },
        .ui_login_error = .{
            .base = .init(&self.ui_context, "error", ui.Label, .{
                .padding = .all(5),
                .margin = .all(5),
                .min_size = .{ .y = 60 },
            }),
            .text = "",
            .color = .red,
        },
        .ui_login_username = .{
            .base = .init(&self.ui_context, "username", ui.Input, .{
                .padding = .all(5),
                .margin = .all(5),
                .min_size = .{ .x = 300 },
            }),
            .placeholder = "username",
            .input = .initBuffer(&self.ui_login_username.input_buf),
        },
        .ui_login_password = .{
            .base = .init(&self.ui_context, "password", ui.Input, .{
                .padding = .all(5),
                .margin = .all(5),
                .min_size = .{ .x = 300 },
            }),
            .password = true,
            .placeholder = "password",
            .input = .initBuffer(&self.ui_login_password.input_buf),
        },
        .ui_login_submit = .{
            .base = .init(&self.ui_context, "submit", ui.Button, .{
                .padding = .all(5),
                .margin = .all(5),
            }),
            .label = "Login",
        },
        .ui_list_root = .{
            .base = .init(&self.ui_context, "list_root", ui.Panel, .{
                .visible = false,
                .expand_w = true,
                .expand_h = true,
            }),
            .flags = .{
                .direction = .row,
                .content_align = .center,
                .wrap = true,
                .justify = .center,
            },
        },
        .ui_list_scroll = .{
            .base = .init(&self.ui_context, "scroll", ui.Scroll, .{
                .expand_w = true,
                .expand_h = true,
            }),
            .flags = .{},
        },
        .ui_list_scroll_root = .{
            .base = .init(&self.ui_context, "list_root", ui.Panel, .{}),
            .flags = .{},
        },
        .ui_list_text = .{
            .base = .init(&self.ui_context, "error", ui.Label, .{
                .padding = .all(5),
                .margin = .all(5),
                .min_size = .{ .y = 600 },
            }),
            .text = "Test",
            .color = .red,
        },
        .ui_context = .{
            .sprite_batch = &SpriteBatch.global,
            .shader = shader,
            .font = undefined,
            .font_shader = undefined,
            .window_size = .{ .x = 640, .y = 480 },
            .clip_stack = .initBuffer(&self.ui_context.clip_stack_buf),
            .root = &self.ui_root.base,
        },
        .divx = .atlas("ui", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .x = 2 },
        }),
        .dive = .atlas("ui", .{
            .source = .{ .x = 2.0 / 8.0, .y = 0.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .y = 2 },
        }),
        .sel = .atlas("ui", .{
            .source = .{ .x = 3.0 / 8.0, .y = 4.0 / 8.0, .w = 1.0 / 8.0, .h = 1.0 / 8.0 },
            .size = .{ .y = 6 },
            .color = .red,
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
                .color = .gray(0.75),
            }),
        },
        .shader = shader,
    };

    try self.ui_root.base.onEvent(.resize, ui.Element.Handlers.resizeWithMax, undefined);
    try self.ui_login_submit.base.onEvent(.mouse_click, clickLogin, self);

    try self.ui_login_username.base.onEvent(.submit, clickLogin, self);
    try self.ui_login_password.base.onEvent(.submit, clickLogin, self);

    self.ui_root.base.addChild(&self.ui_login_root.base);
    self.ui_root.base.addChild(&self.ui_list_root.base);

    self.ui_login_root.base.addChild(&self.ui_login_logo.base);
    self.ui_login_root.base.addChild(&self.ui_login_error.base);
    self.ui_login_root.base.addChild(&self.ui_login_username.base);
    self.ui_login_root.base.addChild(&self.ui_login_password.base);
    self.ui_login_root.base.addChild(&self.ui_login_submit.base);

    self.ui_list_root.base.addChild(&self.ui_list_scroll.base);
    self.ui_list_scroll.content = &self.ui_list_scroll_root.base;

    self.ui_list_scroll_root.base.addChild(&self.ui_list_text.base);

    // self.ui_root.base.addChild(&self.ui_scroll.base);
    // self.ui_scroll.content = &self.ui_login_root.base;

    // self.ui_login_root.base.addChild(&self.ui_login_logo.base);
    // self.ui_login_root.base.addChild(&self.ui_username.base);
    // self.ui_login_root.base.addChild(&self.ui_password.base);
    // self.ui_login_root.base.addChild(&self.ui_submit_button.base);

    return Window.Data.WindowContents.init(self, "email", strings.EEE ++ "Mail", .gray(0.75));
}
