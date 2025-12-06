const std = @import("std");
const c = @import("../c.zig");

const system = @import("mod.zig");

const sandeee_data = @import("../data/mod.zig");
const windows = @import("../windows/mod.zig");
const drawers = @import("../drawers/mod.zig");
const events = @import("../events/mod.zig");
const util = @import("../util/mod.zig");
const math = @import("../math/mod.zig");

const Color = math.Color;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Rect = math.Rect;

const Window = drawers.Window;
const Popup = drawers.Popup;

const Texture = util.Texture;
const Shader = util.Shader;
const Font = util.Font;
const Eln = util.Eln;
const Url = util.Url;
const allocator = util.allocator;
const graphics = util.graphics;
const log = util.log;

const VmManager = system.VmManager;
const Opener = system.Opener;
const Vm = system.Vm;
const files = system.files;

const EventManager = events.EventManager;
const window_events = events.windows;
const system_events = events.system;

const strings = sandeee_data.strings;

// TODO: split this file

pub const Result = struct {
    data: []u8 = &.{},
    exit: bool = false,
    clear: bool = false,

    pub fn deinit(self: *const Result) void {
        allocator.alloc.free(self.data);
    }
};

pub var shader: *Shader = undefined;

// TODO: move to data module
pub const ASM_HEADER = "EEEp";

const ShellError = error{
    MissingParameter,
    BadASMFile,
};

// TODO: move to data module
const TOTAL_BAR_SPRITES: f32 = 13;

const Shell = @This();

headless: bool = false,
vm: ?VmManager.VMHandle = null,

root: files.FolderLink,

pub const Params = struct {
    buffer: []const u8,
    index: ?usize,

    const Self = @This();

    fn incIndex(self: *Self) !void {
        if (self.index) |idx| {
            if (self.buffer.len <= idx + 1) {
                self.index = null;

                return error.Done;
            }

            self.index = idx + 1;

            return;
        } else return error.Done;
    }

    pub fn init(data: []const u8) Self {
        return .{
            .buffer = data,
            .index = if (data.len == 0) null else 0,
        };
    }

    pub fn next(self: *Self) ?[]const u8 {
        if (self.index == null) return null;

        while (self.index != null and std.ascii.isWhitespace(self.buffer[self.index.?])) {
            self.incIndex() catch return null;
        }

        const start = self.index.?;

        while (self.index != null and !std.ascii.isWhitespace(self.buffer[self.index.?])) {
            self.incIndex() catch return self.buffer[start..];
        }

        return self.buffer[start..self.index.?];
    }

    pub fn rest(self: *Self) []const u8 {
        if (self.index == null) return "";

        const start = self.index;

        while (std.ascii.isWhitespace(self.buffer[self.index.?])) {
            self.incIndex() catch return "";
        }

        const result = self.buffer[self.index.?..];

        self.index = start;

        return result;
    }

    pub fn peek(self: *Self) ?[]const u8 {
        if (self.index == null) return null;

        const start = self.index;
        const result = self.next();

        self.index = start;

        return result;
    }
};

pub fn getPrompt(self: *Shell) ![]const u8 {
    const path = get: {
        const root = self.root.resolve() catch break :get "";
        if (root.name.len <= 1) break :get "";

        break :get root.name[0 .. root.name.len - 1];
    };

    return try std.mem.concat(allocator.alloc, u8, &.{
        path,
        "> ",
    });
}

fn runFileInFolder(self: *Shell, root: files.FolderLink, cmd: []const u8, param: *Params) !Result {
    var result_data = std.ArrayList(u8).init(allocator.alloc);
    defer result_data.deinit();

    const folder = try root.resolve();
    const file = folder.getFile(cmd) catch |err| {
        if (std.mem.endsWith(u8, cmd, ".eep")) return err;

        const cmdeep = try std.fmt.allocPrint(allocator.alloc, "{s}.eep", .{cmd});
        defer allocator.alloc.free(cmdeep);

        return self.runFileInFolder(root, cmdeep, param);
    };

    var line = std.ArrayList(u8).init(allocator.alloc);
    defer line.deinit();

    if ((try file.read(null)).len > 3 and std.mem.eql(u8, (try file.read(null))[0..4], ASM_HEADER)) {
        return try self.runAsm(root, cmd, param);
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

    const open_cmd = try Opener.instance.openFile(cmd);
    const new_cmd = try std.mem.concat(allocator.alloc, u8, &.{
        open_cmd,
        " ",
        cmd,
        " ",
        param.rest(),
    });
    defer allocator.alloc.free(new_cmd);
    log.debug("Run {s} instead of {s} {s}", .{ new_cmd, cmd, param.rest() });

    return self.run(new_cmd);
}

fn runFile(self: *Shell, cmd: []const u8, param: *Params) !Result {
    inline for ([_]files.FolderLink{ self.root, .exec }) |dir| {
        if (self.runFileInFolder(dir, cmd, param)) |result| {
            return result;
        } else |err| {
            switch (err) {
                error.FileNotFound => {
                    log.warn("File not found {s} {s} in {}", .{ cmd, param.rest(), dir });
                },
                error.InvalidFileType => {
                    log.warn("Bad filetype {s} {s} in {}", .{ cmd, param.rest(), dir });
                },
                else => return err,
            }
        }
    }

    return error.CommandNotFound;
}

fn todo(name: []const u8) std.meta.Tuple(&.{ []const u8, ShellCommand }) {
    return .{
        name,
        .{
            .name = name,
            .desc = "Not implemented",
            .help = name ++ " [:help]",
            .func = struct {
                fn todo(_: *Shell, _: *Params) !Result {
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
        const data = try VmManager.instance.getOutput(vm_handle);
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
        try VmManager.instance.appendInputSlice(vm_handle, &.{char});
    }
}

fn runAsm(self: *Shell, root: files.FolderLink, cmd: []const u8, params: *Params) !Result {
    const folder = try root.resolve();
    const rootlen = folder.name.len;

    var file = folder.files;

    while (file) |item| : (file = item.next_sibling) {
        if (std.mem.eql(u8, item.name[rootlen..], cmd)) {
            const cont = try item.read(null);
            if (cont.len < 4 or !std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                return error.BadASMFile;
            }

            const ops = cont[4..];

            self.vm = try VmManager.instance.spawn(self.root, params.buffer, ops);

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
    gui: bool = false,
    func: *const fn (*Shell, *Params) anyerror!Result,
    name: []const u8,
    desc: []const u8,
    help: []const u8,

    pub fn run(self: *const ShellCommand, shell: *Shell, params: *Params) !Result {
        const copy = params.rest();
        var iter = Params.init(copy);

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
    .{ "cmd", ShellCommand{
        .gui = true,
        .name = "cmd",
        .help = "cmd [:help]",
        .desc = "Opens the command prompt",
        .func = struct {
            pub fn cmd(_: *Shell, param: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .source = Rect{ .w = 1, .h = 1 },
                    .contents = try windows.cmd.init(),
                    .active = true,
                });
                if (param.next()) |command| {
                    const cmd_self: *windows.cmd.CMDData = @ptrCast(@alignCast(window.data.contents.ptr));
                    @memcpy(cmd_self.input_buffer[0..command.len], command);
                    cmd_self.input_len = @intCast(command.len);
                    try cmd_self.key(c.GLFW_KEY_ENTER, 0, true);
                }
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.cmd,
    } },
    .{ "edit", ShellCommand{
        .gui = true,
        .name = "edit",
        .help = "edit [:help] [file]",
        .desc = "Opens the text editor",
        .func = struct {
            pub fn edit(shell: *Shell, param: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .source = Rect{ .w = 1, .h = 1 },
                    .contents = try windows.editor.init(shader),
                    .active = true,
                });
                if (param.next()) |file_name| {
                    const ed_self: *windows.editor.EditorData = @ptrCast(@alignCast(window.data.contents.ptr));
                    const root_link: files.FolderLink = if (std.mem.startsWith(u8, file_name, "/"))
                        .root
                    else
                        shell.root;
                    const root = try root_link.resolve();
                    ed_self.file = try root.getFile(file_name);
                    if (ed_self.file) |file| {
                        const file_conts = try file.read(null);
                        const lines = std.mem.count(u8, file_conts, "\n") + 1;
                        ed_self.buffer = if (ed_self.buffer) |buffer|
                            try allocator.alloc.realloc(buffer, lines)
                        else
                            try allocator.alloc.alloc(windows.editor.EditorData.Row, lines);
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
    .{ "web", ShellCommand{
        .gui = true,
        .name = "web",
        .help = "web [:help] [:file] [url]",
        .desc = "Opens the web browser",
        .func = struct {
            fn web(shell: *Shell, param: *Params) !Result {
                const shell_root = try shell.root.resolve();
                const window: Window = .atlas("win", .{
                    .source = .{ .w = 1, .h = 1 },
                    .contents = try windows.web.init(shader),
                    .active = true,
                });
                var url_data: ?[]const u8 = null;
                var file = false;
                while (param.next()) |in_param| {
                    if (std.mem.eql(u8, in_param, ":file")) {
                        file = true;
                    } else {
                        if (url_data == null) {
                            url_data = in_param;
                        } else {
                            return .{
                                .data = try allocator.alloc.dupe(u8, "Invalid web call with 2 urls"),
                            };
                        }
                    }
                }
                if (url_data) |url| {
                    const webself: *windows.web.WebData = @ptrCast(@alignCast(window.data.contents.ptr));
                    if (file) {
                        webself.path.deinit();
                        const web_file = try shell_root.getFile(url);
                        webself.path = try Url.parse(web_file.name);
                    } else {
                        webself.path.deinit();
                        webself.path = try Url.parse(url);
                    }
                }
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.web,
    } },
    .{ "mail", ShellCommand{
        .gui = true,
        .name = "mail",
        .help = "mail [:help]",
        .desc = "Opens the email browser",
        .func = struct {
            fn mail(_: *Shell, _: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .contents = try windows.email.init(shader),
                    .active = true,
                });
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.mail,
    } },
    .{ "task", ShellCommand{
        .gui = true,
        .name = "task",
        .help = "task [:help]",
        .desc = "Opens the task manager",
        .func = struct {
            fn task(_: *Shell, _: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .contents = try windows.tasks.init(shader),
                    .active = true,
                });
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.task,
    } },
    .{ "set", ShellCommand{
        .gui = true,
        .name = "set",
        .help = "set [:help]",
        .desc = "Opens the setting manager",
        .func = struct {
            fn settings(_: *Shell, _: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .contents = try windows.settings.init(shader),
                    .active = true,
                });
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.settings,
    } },
    .{ "launch", ShellCommand{
        .gui = true,
        .name = "launch",
        .help = "launch [:help]",
        .desc = "Opens the application launcher",
        .func = struct {
            fn launch(_: *Shell, _: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .contents = try windows.apps.init(shader),
                    .active = true,
                });
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.launch,
    } },
    .{ "logout", ShellCommand{
        .gui = true,
        .name = "logout",
        .help = "logout [:help]",
        .desc = "Opens the logout prompt",
        .func = struct {
            fn logout(_: *Shell, _: *Params) !Result {
                const adds = try allocator.alloc.create(Popup.Data.quit.PopupQuit);
                adds.* = .{
                    .shader = shader,
                    .icons = .{
                        .atlas("bar", .{
                            .source = .{ .y = 11.0 / TOTAL_BAR_SPRITES, .w = 1.0, .h = 1.0 / TOTAL_BAR_SPRITES },
                            .size = .{ .x = 64, .y = 64 },
                        }),
                        .atlas("bar", .{
                            .source = .{ .y = 12.0 / TOTAL_BAR_SPRITES, .w = 1.0, .h = 1.0 / TOTAL_BAR_SPRITES },
                            .size = .{ .x = 64, .y = 64 },
                        }),
                    },
                };
                try events.EventManager.instance.sendEvent(window_events.EventCreatePopup{
                    .global = true,
                    .popup = .atlas("win", .{
                        .title = "Quit SandEEE",
                        .source = .{ .w = 0, .h = 0 },
                        .pos = .initCentered(.{
                            .x = 0,
                            .y = 0,
                            .w = graphics.Context.instance.size.x,
                            .h = graphics.Context.instance.size.y,
                        }, 350, 125),
                        .contents = .init(adds),
                    }),
                });
                return .{
                    .data = try allocator.alloc.dupe(u8, "Launched"),
                };
            }
        }.logout,
    } },
    .{ "files", ShellCommand{
        .gui = true,
        .name = "files",
        .help = "files [:help]",
        .desc = "Opens the file manager",
        .func = struct {
            fn files(_: *Shell, _: *Params) !Result {
                const window: Window = .atlas("win", .{
                    .contents = try windows.explorer.init(shader),
                    .active = true,
                });
                try events.EventManager.instance.sendEvent(window_events.EventCreateWindow{ .window = window });
                return .{};
            }
        }.files,
    } },
};

pub const shell_commands = .{
    .{ "help", ShellCommand{
        .name = "help",
        .desc = "Prints a help message",
        .help = "help [:help]",
        .func = struct {
            pub fn help(shell: *Shell, _: *Params) !Result {
                var data = std.ArrayList(u8).init(allocator.alloc);
                defer data.deinit();
                try data.appendSlice("Sh" ++ strings.EEE ++ "ll Help:\n" ++ "=============\n");
                if (shell.headless or @import("builtin").is_test) {
                    inline for (headless_help_data) |help_group| {
                        try data.append('\n');
                        try data.appendSlice(help_group.name ++ "\n");
                        try data.appendNTimes('-', help_group.name.len);
                        try data.append('\n');
                        inline for (help_group.cmds) |command| {
                            try data.appendSlice(std.fmt.comptimePrint("{s} - {s}\n", .{ command.@"1".name, command.@"1".desc }));
                        }
                    }
                } else {
                    inline for (help_data) |help_group| {
                        try data.append('\n');
                        try data.appendSlice(help_group.name ++ "\n");
                        try data.appendNTimes('-', help_group.name.len);
                        try data.append('\n');
                        inline for (help_group.cmds) |command| {
                            try data.appendSlice(std.fmt.comptimePrint("{s} - {s}\n", .{ command.@"1".name, command.@"1".desc }));
                        }
                    }
                }
                return .{
                    .data = try allocator.alloc.dupe(u8, data.items),
                };
            }
        }.help,
    } },
    .{ "ls", ShellCommand{
        .name = "ls",
        .desc = "Lists files and folders in a directory",
        .help = "ls [:help] [path]",
        .func = struct {
            pub fn ls(shell: *Shell, params: *Params) !Result {
                const root = try shell.root.resolve();
                if (params.next()) |path| {
                    const folder = try root.getFolder(path);
                    var result_data = std.ArrayList(u8).init(allocator.alloc);
                    defer result_data.deinit();
                    const rootlen = folder.name.len;
                    var sub_folder = try folder.getFolders();
                    while (sub_folder) |item| : (sub_folder = item.next_sibling) {
                        try result_data.appendSlice(item.name[rootlen..]);
                        try result_data.append(' ');
                    }
                    var sub_file = try folder.getFiles();
                    while (sub_file) |item| : (sub_file = item.next_sibling) {
                        try result_data.appendSlice(item.name[rootlen..]);
                        try result_data.append(' ');
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, result_data.items),
                    };
                } else {
                    const folder = try shell.root.resolve();
                    var result_data = std.ArrayList(u8).init(allocator.alloc);
                    defer result_data.deinit();
                    const rootlen = folder.name.len;
                    var sub_folder = try folder.getFolders();
                    while (sub_folder) |item| : (sub_folder = item.next_sibling) {
                        try result_data.appendSlice(item.name[rootlen..]);
                        try result_data.append(' ');
                    }
                    var sub_file = try folder.getFiles();
                    while (sub_file) |item| : (sub_file = item.next_sibling) {
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
    .{ "Eln", ShellCommand{
        .name = "Eln",
        .help = "Eln [:help] file",
        .desc = "Opens a Eln file",
        .func = struct {
            pub fn cmd(shell: *Shell, param: *Params) !Result {
                if (param.next()) |path| {
                    const root = try shell.root.resolve();
                    const file = try root.getFile(path);
                    const data = try Eln.parse(file);
                    try data.run(shell, shader);
                    return .{};
                }
                return error.MissingParameter;
            }
        }.cmd,
    } },
    .{ "cd", ShellCommand{
        .name = "cd",
        .desc = "Changes the current directory",
        .help = "cd [:help] [path]",
        .func = struct {
            pub fn cd(shell: *Shell, params: *Params) !Result {
                if (params.next()) |child| {
                    if (std.mem.eql(u8, child, "/")) {
                        shell.root = .root;
                        return .{};
                    }
                    const root_link: files.FolderLink = if (std.mem.startsWith(u8, child, "/"))
                        .root
                    else
                        shell.root;
                    const root = try root_link.resolve();
                    const folder = try root.getFolder(child);
                    shell.root = .link(folder);
                    return .{};
                } else {
                    shell.root = .home;
                    return .{};
                }
            }
        }.cd,
    } },
    .{ "stop", ShellCommand{
        .name = "stop",
        .desc = "Stops a background vm process",
        .help = "stop [:help] id",
        .func = struct {
            pub fn stop(_: *Shell, params: *Params) !Result {
                if (params.next()) |id_string| {
                    const id = try std.fmt.parseInt(u8, id_string, 16);
                    VmManager.instance.destroy(.{
                        .id = id,
                    });
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Stopped"),
                    };
                }
                return error.MissingParameter;
            }
        }.stop,
    } },
    .{
        "new", ShellCommand{
            .name = "new",
            .desc = "Creates a new file",
            .help = "new [:help] path",
            .func = struct {
                fn new(self: *Shell, param: *Params) !Result {
                    if (param.next()) |path| {
                        // TODO: /root
                        const root = try self.root.resolve();
                        try root.newFile(path);
                        return .{
                            .data = try allocator.alloc.dupe(u8, "Created"),
                        };
                    }
                    return error.MissingParameter;
                }
            }.new,
        },
    },
    .{
        "dnew", ShellCommand{
            .name = "dnew",
            .desc = "Creates a new directory",
            .help = "dnew [:help] path",
            .func = struct {
                fn dnew(self: *Shell, param: *Params) !Result {
                    if (param.next()) |path| {
                        // TODO: /root
                        const root = try self.root.resolve();
                        try root.newFolder(path);
                        return .{
                            .data = try allocator.alloc.dupe(u8, "Created"),
                        };
                    }
                    return error.MissingParameter;
                }
            }.dnew,
        },
    },
    .{
        "rem", ShellCommand{
            .name = "rem",
            .desc = "Deletes a file",
            .help = "rem [:help] paths+",
            .func = struct {
                fn rem(self: *Shell, params: *Params) !Result {
                    if (params.peek() == null)
                        return error.MissingParameter;
                    // TODO: /root
                    const root = try self.root.resolve();
                    while (params.next()) |path| {
                        try root.removeFile(path);
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Removed"),
                    };
                }
            }.rem,
        },
    },
    .{
        "drem", ShellCommand{
            .name = "drem",
            .desc = "Deletes a directory",
            .help = "drem [:help] paths+",
            .func = struct {
                fn drem(self: *Shell, params: *Params) !Result {
                    if (params.peek() == null)
                        return error.MissingParameter;
                    // TODO: /root
                    const root = try self.root.resolve();
                    while (params.next()) |path| {
                        try root.removeFolder(path);
                    }
                    return .{
                        .data = try allocator.alloc.dupe(u8, "Removed"),
                    };
                }
            }.drem,
        },
    },
    .{ "cpy", ShellCommand{
        .name = "cpy",
        .desc = "Copies a file",
        .help = "cpy [:help] src dst",
        .func = @import("shell/cpy.zig").cpy,
    } },
    todo("dcpy"),
    .{ "bg", ShellCommand{
        .name = "bg",
        .desc = "Runs a command in the background",
        .help = "bg [:help] command",
        .func = struct {
            fn bg(self: *Shell, params: *Params) !Result {
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
    .{ "cls", ShellCommand{
        .name = "cls",
        .desc = "Clears the console",
        .help = "cls [:help]",
        .func = struct {
            fn clear(_: *Shell, _: *Params) !Result {
                const result: Result = Result{
                    .data = &.{},
                    .clear = true,
                };
                return result;
            }
        }.clear,
    } },
    .{ "exit", ShellCommand{
        .name = "exit",
        .desc = "Exits the console",
        .help = "exit [:help]",
        .func = struct {
            fn exit(_: *Shell, _: *Params) !Result {
                const result: Result = Result{
                    .data = &.{},
                    .exit = true,
                };
                return result;
            }
        }.exit,
    } },
};

pub const headless_help_data = .{
    .{ .name = "Commands", .cmds = shell_commands },
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

    if (params.len == 0)
        return error.MissingParameter;

    var iter = Params.init(params);
    const cmd = iter.next() orelse return .{};

    if (command_map.get(cmd)) |runs|
        if (!runs.gui or !self.headless and !@import("builtin").is_test)
            return runs.run(self, &iter);

    return self.runFile(cmd, &iter);
}

pub fn deinit(self: *Shell) void {
    if (self.vm) |vm_handle| {
        VmManager.instance.destroy(vm_handle);
        self.vm = null;
    }
}

test "Shell fuzz" {}
