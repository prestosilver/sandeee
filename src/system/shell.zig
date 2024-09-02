const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");
const events = @import("../util/events.zig");
const window_events = @import("../events/window.zig");
const system_events = @import("../events/system.zig");
const wins = @import("../windows/all.zig");
const win = @import("../drawers/window2d.zig");
const tex = @import("../util/texture.zig");
const shd = @import("../util/shader.zig");
const vecs = @import("../math/vecs.zig");
const rect = @import("../math/rects.zig");
const opener = @import("opener.zig");
const vm_manager = @import("../system/vmmanager.zig");
const popups = @import("../drawers/popup2d.zig");
const gfx = @import("../util/graphics.zig");
const font = @import("../util/font.zig");
const c = @import("../c.zig");

const Result = struct {
    data: []u8 = &.{},
    exit: bool = false,
    clear: bool = false,

    pub fn deinit(self: *const Result) void {
        allocator.alloc.free(self.data);
    }
};

pub var shader: *shd.Shader = undefined;

pub const ASM_HEADER = "EEEp";

const ShellError = error{
    MissingParameter,
    BadASMFile,
};

const TOTAL_BAR_SPRITES: f32 = 13;

pub const Shell = struct {
    root: *files.Folder,
    vm: ?vm_manager.VMManager.VMHandle = null,

    const ParamType = *std.mem.SplitIterator(u8, .scalar);

    pub fn getPrompt(self: *Shell) []const u8 {
        if (self.root.name.len == 0)
            return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name}) catch "> ";
        return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name[0 .. self.root.name.len - 1]}) catch "> ";
    }

    fn runFileInFolder(self: *Shell, folder: *files.Folder, cmd: []const u8, param: ParamType) !Result {
        var result_data = std.ArrayList(u8).init(allocator.alloc);
        defer result_data.deinit();

        const file = folder.getFile(cmd) catch |err| {
            if (std.mem.endsWith(u8, cmd, ".eep")) return err;

            const cmdeep = try std.fmt.allocPrint(allocator.alloc, "{s}.eep", .{cmd});
            defer allocator.alloc.free(cmdeep);

            return self.runFileInFolder(folder, cmdeep, param);
        };

        var line = std.ArrayList(u8).init(allocator.alloc);
        defer line.deinit();

        if ((try file.read(null)).len > 3 and std.mem.eql(u8, (try file.read(null))[0..4], ASM_HEADER)) {
            return try self.runAsm(folder, cmd, param);
        }

        if (std.mem.endsWith(u8, file.name, ".esh")) {
            for (try file.read(null)) |char| {
                if (char == '\n') {
                    const res = try self.runLine(line.items);
                    defer allocator.alloc.free(res.data);
                    try result_data.appendSlice(res.data);
                    if (result_data.items.len != 0)
                        if (result_data.getLast() != '\n') try result_data.append('\n');
                    try line.resize(0);
                } else {
                    try line.append(char);
                }
            }
            const res = try self.runLine(line.items);
            defer allocator.alloc.free(res.data);
            try result_data.appendSlice(res.data);
            if (result_data.items.len != 0 and result_data.getLast() != '\n') try result_data.append('\n');

            return .{
                .data = try allocator.alloc.dupe(u8, result_data.items),
            };
        }

        return error.InvalidFileType;
    }

    fn runFile(self: *Shell, cmd: []const u8, param: ParamType) !Result {
        return self.runFileInFolder(files.exec, cmd, param) catch |err| {
            switch (err) {
                error.FileNotFound, error.InvalidFileType => {
                    return self.runFileInFolder(self.root, cmd, param) catch |subErr| {
                        switch (subErr) {
                            error.FileNotFound, error.InvalidFileType => {
                                const file = try self.root.getFile(cmd);
                                const opens = try opener.openFile(cmd);
                                const params = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ opens, file.name });
                                defer allocator.alloc.free(params);

                                return self.run(params);
                            },
                            else => return subErr,
                        }
                    };
                },
                else => return err,
            }
        };
    }

    fn todo(name: []const u8) std.meta.Tuple(&.{ []const u8, ShellCommand }) {
        return .{
            name,
            .{
                .name = name,
                .desc = "Not implemented",
                .help = name ++ " [:help]",
                .func = struct {
                    fn todo(_: *Shell, _: ParamType) !Result {
                        return .{
                            .data = try std.mem.concat(allocator.alloc, u8, &.{ "Command `", name, "` Not yet implemented!" }),
                        };
                    }
                }.todo,
            },
        };
    }

    pub fn getVMResult(self: *Shell) !?Result {
        if (self.vm) |vm_handle| {
            const data = try vm_manager.VMManager.instance.getOutput(vm_handle);
            defer data.deinit();

            if (data.done) self.vm = null;

            return .{
                .data = try allocator.alloc.dupe(u8, data.data),
            };
        }

        return null;
    }

    pub fn appendVMIn(self: *Shell, char: u8) !void {
        if (self.vm) |vm_handle| {
            try vm_manager.VMManager.instance.appendInputSlice(vm_handle, &.{char});
        }
    }

    fn runAsm(self: *Shell, folder: *files.Folder, cmd: []const u8, params: ParamType) !Result {
        for (folder.contents.items, 0..) |_, idx| {
            const rootlen = folder.name.len;
            const item = folder.contents.items[idx];

            if (std.mem.eql(u8, item.name[rootlen..], cmd)) {
                const cont = try item.read(null);
                if (cont.len < 4 or !std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                    return error.BadASMFile;
                }

                const ops = cont[4..];

                self.vm = try vm_manager.VMManager.instance.spawn(self.root, params.buffer, ops);

                return .{};
            }
        }

        return error.FileNotFound;
    }

    pub fn runBg(self: *Shell, cmd: []const u8) !void {
        const result = try self.run(cmd);
        result.deinit();

        self.vm = null;
    }

    fn runLine(self: *Shell, line: []const u8) !Result {
        if (line.len == 0) {
            return .{};
        }

        return self.run(line);
    }

    pub const ShellCommand = struct {
        func: *const fn (*Shell, ParamType) anyerror!Result,
        name: []const u8,
        desc: []const u8,
        help: []const u8,

        pub fn run(self: *const ShellCommand, shell: *Shell, params: ParamType) !Result {
            const copy = params.rest();
            var iter = std.mem.splitScalar(u8, copy, ' ');

            while (iter.next()) |param| {
                if (param.len == 0) continue;
                if (param[0] != ':') break;

                if (std.mem.eql(u8, param[1..], "help")) {
                    return .{
                        .data = try std.fmt.allocPrint(allocator.alloc, "{s} - {s}\n\n{s}\n", .{ self.name, self.desc, self.help }),
                    };
                }
            }

            return self.func(shell, params);
        }
    };

    pub const window_commands = .{
        .{ "cmd", .{
            .name = "cmd",
            .help = "cmd [:help]",
            .desc = "Opens the command prompt",
            .func = struct {
                pub fn cmd(_: *Shell, param: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = .{
                            .source = rect.Rectangle{ .w = 1, .h = 1 },
                            .contents = try wins.cmd.init(),
                            .active = true,
                        },
                    };
                    if (param.next()) |command| {
                        const cmd_self: *wins.cmd.CMDData = @ptrCast(@alignCast(window.data.contents.ptr));
                        @memcpy(cmd_self.input_buffer[0..command.len], command);
                        cmd_self.input_len = @intCast(command.len);
                        try cmd_self.key(c.GLFW_KEY_ENTER, 0, true);
                    }
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.cmd,
        } },
        .{ "edit", .{
            .name = "edit",
            .help = "edit [:help] [file]",
            .desc = "Opens the text editor",
            .func = struct {
                pub fn edit(shell: *Shell, param: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = .{
                            .source = rect.Rectangle{ .w = 1, .h = 1 },
                            .contents = try wins.editor.init(shader),
                            .active = true,
                        },
                    };
                    if (param.next()) |file_name| {
                        const ed_self: *wins.editor.EditorData = @ptrCast(@alignCast(window.data.contents.ptr));
                        if (file_name[0] == '/')
                            ed_self.file = try files.root.getFile(file_name)
                        else
                            ed_self.file = try shell.root.getFile(file_name);
                        if (ed_self.file) |file| {
                            const file_conts = try file.read(null);
                            const lines = std.mem.count(u8, file_conts, "\n") + 1;
                            ed_self.buffer = if (ed_self.buffer) |buffer|
                                try allocator.alloc.realloc(buffer, lines)
                            else
                                try allocator.alloc.alloc(wins.editor.EditorData.Row, lines);
                            var iter = std.mem.splitScalar(u8, file_conts, '\n');
                            var idx: usize = 0;
                            while (iter.next()) |line| : (idx += 1) {
                                ed_self.buffer.?[idx] = .{
                                    .text = try allocator.alloc.dupe(u8, line),
                                    .render = null,
                                };
                            }
                        } else {
                            return .{};
                        }
                    }
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.edit,
        } },
        .{ "web", .{
            .name = "web",
            .help = "web [:help] [url]",
            .desc = "Opens the web browser",
            .func = struct {
                fn web(_: *Shell, param: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = win.WindowData{
                            .source = rect.Rectangle{ .w = 1, .h = 1 },
                            .contents = try wins.web.init(shader),
                            .active = true,
                        },
                    };
                    if (param.next()) |url| {
                        const webself: *wins.web.WebData = @ptrCast(@alignCast(window.data.contents.ptr));
                        webself.path = try allocator.alloc.realloc(webself.path, url.len);
                        @memcpy(webself.path, url);
                    }
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.web,
        } },
        .{ "mail", .{
            .name = "mail",
            .help = "mail [:help]",
            .desc = "Opens the email browser",
            .func = struct {
                fn mail(_: *Shell, _: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = .{
                            .contents = try wins.email.init(shader),
                            .active = true,
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.mail,
        } },
        .{ "task", .{
            .name = "task",
            .help = "task [:help]",
            .desc = "Opens the task manager",
            .func = struct {
                fn task(_: *Shell, _: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = win.WindowData{
                            .contents = try wins.tasks.init(shader),
                            .active = true,
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.task,
        } },
        .{ "set", .{
            .name = "set",
            .help = "set [:help]",
            .desc = "Opens the setting manager",
            .func = struct {
                fn settings(_: *Shell, _: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = win.WindowData{
                            .contents = try wins.settings.init(shader),
                            .active = true,
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.settings,
        } },
        .{ "launch", .{
            .name = "launch",
            .help = "launch [:help]",
            .desc = "Opens the application launcher",
            .func = struct {
                fn launch(_: *Shell, _: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = win.WindowData{
                            .contents = try wins.apps.init(shader),
                            .active = true,
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.launch,
        } },
        .{ "logout", .{
            .name = "logout",
            .help = "logout [:help]",
            .desc = "Opens the logout prompt",
            .func = struct {
                fn logout(_: *Shell, _: ParamType) !Result {
                    const adds = try allocator.alloc.create(popups.all.quit.PopupQuit);
                    adds.* = .{
                        .shader = shader,
                        .icons = .{
                            .{
                                .texture = "bar",
                                .data = .{
                                    .source = .{ .y = 11.0 / TOTAL_BAR_SPRITES, .w = 1.0, .h = 1.0 / TOTAL_BAR_SPRITES },
                                    .size = .{ .x = 64, .y = 64 },
                                },
                            },
                            .{
                                .texture = "bar",
                                .data = .{
                                    .source = .{ .y = 12.0 / TOTAL_BAR_SPRITES, .w = 1.0, .h = 1.0 / TOTAL_BAR_SPRITES },
                                    .size = .{ .x = 64, .y = 64 },
                                },
                            },
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                        .global = true,
                        .popup = .{
                            .texture = "win",
                            .data = .{
                                .title = "Quit SandEEE",
                                .source = .{ .w = 0, .h = 0 },
                                .pos = rect.Rectangle.initCentered(.{
                                    .x = 0,
                                    .y = 0,
                                    .w = gfx.Context.instance.size.x,
                                    .h = gfx.Context.instance.size.y,
                                }, 350, 125),
                                .contents = popups.PopupData.PopupContents.init(adds),
                            },
                        },
                    });
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Launched"),
                    };
                }
            }.logout,
        } },
        .{ "files", .{
            .name = "files",
            .help = "files [:help]",
            .desc = "Opens the file manager",
            .func = struct {
                fn files(_: *Shell, _: ParamType) !Result {
                    const window = .{
                        .texture = "win",
                        .data = win.WindowData{
                            .contents = try wins.explorer.init(shader),
                            .active = true,
                        },
                    };
                    try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                    return .{};
                }
            }.files,
        } },
    };

    pub const shell_commands = .{
        .{ "help", .{
            .name = "help",
            .desc = "Prints a help message",
            .help = "help [:help]",
            .func = struct {
                pub fn help(_: *Shell, _: ParamType) !Result {
                    var data = std.ArrayList(u8).init(allocator.alloc);
                    defer data.deinit();
                    try data.appendSlice("Sh" ++ font.EEE ++ "ll Help:\n" ++ "=============\n");
                    inline for (help_data) |help_group| {
                        try data.append('\n');
                        try data.appendSlice(help_group.name ++ "\n");
                        try data.appendNTimes('-', help_group.name.len);
                        try data.append('\n');
                        inline for (help_group.cmds) |command| {
                            try data.appendSlice(std.fmt.comptimePrint("{s} - {s}\n", .{ command.@"1".name, command.@"1".desc }));
                        }
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, data.items),
                    };
                }
            }.help,
        } },
        .{ "ls", .{
            .name = "ls",
            .desc = "Lists files and folders in a directory",
            .help = "ls [:help] [path]",
            .func = struct {
                pub fn ls(shell: *Shell, params: ParamType) !Result {
                    if (params.next()) |path| {
                        const folder = try shell.root.getFolder(path);
                        var result_data = std.ArrayList(u8).init(allocator.alloc);
                        defer result_data.deinit();
                        const rootlen = folder.name.len;
                        const sub_folders = try folder.getFolders();
                        defer allocator.alloc.free(sub_folders);
                        for (sub_folders) |item| {
                            try result_data.appendSlice(item.name[rootlen..]);
                            try result_data.append(' ');
                        }
                        const contents = try folder.getFiles();
                        defer allocator.alloc.free(contents);
                        for (contents) |item| {
                            try result_data.appendSlice(item.name[rootlen..]);
                            try result_data.append(' ');
                        }
                        return .{
                            .data = try allocator.alloc.dupe(u8, result_data.items),
                        };
                    } else {
                        const folder = shell.root;
                        var result_data = std.ArrayList(u8).init(allocator.alloc);
                        defer result_data.deinit();
                        const rootlen = folder.name.len;
                        const sub_folders = try folder.getFolders();
                        defer allocator.alloc.free(sub_folders);
                        for (sub_folders) |item| {
                            try result_data.appendSlice(item.name[rootlen..]);
                            try result_data.append(' ');
                        }
                        const contents = try folder.getFiles();
                        defer allocator.alloc.free(contents);
                        for (contents) |item| {
                            try result_data.appendSlice(item.name[rootlen..]);
                            try result_data.append(' ');
                        }
                        return .{
                            .data = try allocator.alloc.dupe(u8, result_data.items),
                        };
                    }
                }
            }.ls,
        } },
        .{ "cd", .{
            .name = "cd",
            .desc = "Changes the current directory",
            .help = "cd [:help] [path]",
            .func = struct {
                pub fn cd(shell: *Shell, params: ParamType) !Result {
                    if (params.next()) |child| {
                        if (child[0] == '/') {
                            const folder = try files.root.getFolder(child[1..]);
                            shell.root = folder;
                            return .{};
                        }
                        const folder = try shell.root.getFolder(child);
                        shell.root = folder;
                        return .{};
                    }
                    shell.root = files.home;
                    return .{};
                }
            }.cd,
        } },
        .{ "stop", .{
            .name = "stop",
            .desc = "Stops a background vm process",
            .help = "stop [:help] id",
            .func = struct {
                pub fn stop(_: *Shell, params: ParamType) !Result {
                    if (params.next()) |id_string| {
                        const id = try std.fmt.parseInt(u8, id_string, 16);
                        vm_manager.VMManager.instance.destroy(.{
                            .id = id,
                        });
                        return .{
                            .data = try allocator.alloc.dupe(u8, "Stopped"),
                        };
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, "stop requires an id"),
                    };
                }
            }.stop,
        } },
        .{ "new", .{
            .name = "new",
            .desc = "Creates a new file",
            .help = "new [:help] path",
            .func = struct {
                fn new(self: *Shell, param: ParamType) !Result {
                    if (param.next()) |path| {
                        try self.root.newFile(path);
                        return .{
                            .data = try allocator.alloc.dupe(u8, "Created"),
                        };
                    }
                    return error.MissingParameter;
                }
            }.new,
        } },
        .{ "dnew", .{
            .name = "dnew",
            .desc = "Creates a new directory",
            .help = "dnew [:help] path",
            .func = struct {
                fn dnew(self: *Shell, param: ParamType) !Result {
                    if (param.next()) |path| {
                        try self.root.newFolder(path);
                        return .{
                            .data = try allocator.alloc.dupe(u8, "Created"),
                        };
                    }
                    return error.MissingParameter;
                }
            }.dnew,
        } },
        .{ "rem", .{
            .name = "rem",
            .desc = "Deletes a file",
            .help = "rem [:help] path",
            .func = struct {
                fn rem(self: *Shell, params: ParamType) !Result {
                    if (params.peek() == null)
                        return error.MissingParameter;
                    while (params.next()) |path| {
                        try self.root.removeFile(path);
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Removed"),
                    };
                }
            }.rem,
        } },
        .{ "drem", .{
            .name = "drem",
            .desc = "Deletes a directory",
            .help = "drem [:help] path",
            .func = struct {
                fn drem(self: *Shell, params: ParamType) !Result {
                    if (params.peek() == null)
                        return error.MissingParameter;
                    while (params.next()) |path| {
                        try self.root.removeFolder(path);
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Removed"),
                    };
                }
            }.drem,
        } },
        .{ "cpy", .{
            .name = "cpy",
            .desc = "Copies a file",
            .help = "cpy [:help] src dst",
            .func = struct {
                fn cpy(self: *Shell, params: ParamType) !Result {
                    const input = params.next() orelse return error.MissingParameter;
                    const output = params.next() orelse return error.MissingParameter;
                    const root = if (input.len != 0 and input[0] == '/')
                        files.root
                    else
                        self.root;
                    const oroot = if (output.len != 0 and output[0] == '/')
                        files.root
                    else
                        self.root;
                    const file = try root.getFile(input);
                    const targ = try oroot.getFolder(output);
                    try file.copyTo(targ);
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Copied"),
                    };
                }
            }.cpy,
        } },
        todo("dcpy"),
        .{ "bg", .{
            .name = "bg",
            .desc = "Runs a command in the background",
            .help = "bg [:help] command",
            .func = struct {
                fn bg(self: *Shell, params: ParamType) !Result {
                    if (params.peek()) |_| {
                        try self.runBg(params.rest());
                        const result: Result = Result{
                            .data = try allocator.alloc.dupe(u8, "Running"),
                        };
                        return result;
                    }
                    const result: Result = Result{
                        .data = try allocator.alloc.dupe(u8, "No Command Specified"),
                    };
                    return result;
                }
            }.bg,
        } },
        .{ "cls", .{
            .name = "cls",
            .desc = "Clears the console",
            .help = "cls [:help]",
            .func = struct {
                fn clear(_: *Shell, _: ParamType) !Result {
                    const result: Result = Result{
                        .data = &.{},
                        .clear = true,
                    };
                    return result;
                }
            }.clear,
        } },
        .{ "exit", .{
            .name = "exit",
            .desc = "Exits the console",
            .help = "exit [:help]",
            .func = struct {
                fn exit(_: *Shell, _: ParamType) !Result {
                    const result: Result = Result{
                        .data = &.{},
                        .exit = true,
                    };
                    return result;
                }
            }.exit,
        } },
    };

    pub const help_data = .{
        .{ .name = "Commands", .cmds = shell_commands },
        .{ .name = "Applications", .cmds = window_commands },
    };

    pub const command_map = std.StaticStringMap(ShellCommand).initComptime(
        shell_commands ++
            if (!@import("builtin").is_test) window_commands else .{},
    );

    pub fn run(self: *Shell, params: []const u8) anyerror!Result {
        try events.EventManager.instance.sendEvent(system_events.EventRunCmd{
            .cmd = params,
        });

        if (params.len == 0) {
            return error.MissingParameter;
        }

        var iter = std.mem.splitScalar(u8, params, ' ');
        const cmd = iter.first();

        if (command_map.get(cmd)) |runs|
            return runs.run(self, &iter);

        return self.runFile(cmd, &iter);
    }

    pub fn deinit(self: *Shell) void {
        if (self.vm) |vm_handle| {
            vm_manager.VMManager.instance.destroy(vm_handle);
            self.vm = null;
        }
    }
};
