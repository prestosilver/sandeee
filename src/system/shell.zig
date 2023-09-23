const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");
const events = @import("../util/events.zig");
const windowEvs = @import("../events/window.zig");
const systemEvs = @import("../events/system.zig");
const wins = @import("../windows/all.zig");
const win = @import("../drawers/window2d.zig");
const tex = @import("../util/texture.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const opener = @import("opener.zig");
const vmManager = @import("../system/vmmanager.zig");

const Result = struct {
    data: []u8,
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

pub const Shell = struct {
    root: *files.Folder,
    vm: ?vmManager.VMManager.VMHandle = null,

    pub fn getPrompt(self: *Shell) []const u8 {
        if (self.root.name.len == 0)
            return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name}) catch "> ";
        return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name[0 .. self.root.name.len - 1]}) catch "> ";
    }

    pub fn cd(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            if (param[3] == '/') {
                const folder = try files.root.getFolder(param[4..]);
                self.root = folder;
                return .{
                    .data = try allocator.alloc.dupe(u8, ""),
                };
            }

            const folder = try self.root.getFolder(param[3..]);
            self.root = folder;

            return .{
                .data = try allocator.alloc.dupe(u8, ""),
            };
        } else {
            self.root = files.home;

            return .{
                .data = try allocator.alloc.dupe(u8, ""),
            };
        }
    }

    fn ls(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            const folder = try self.root.getFolder(param[3..]);
            var resultData = std.ArrayList(u8).init(allocator.alloc);
            defer resultData.deinit();

            const rootlen = folder.name.len;

            const subfolders = try folder.getFolders();
            defer allocator.alloc.free(subfolders);

            for (subfolders) |item| {
                try resultData.appendSlice(item.name[rootlen..]);
                try resultData.append(' ');
            }

            const contents = try folder.getFiles();
            defer allocator.alloc.free(contents);

            for (contents) |item| {
                try resultData.appendSlice(item.name[rootlen..]);
                try resultData.append(' ');
            }

            return .{
                .data = try allocator.alloc.dupe(u8, resultData.items),
            };
        } else {
            const folder = self.root;
            var resultData = std.ArrayList(u8).init(allocator.alloc);
            defer resultData.deinit();

            const rootlen = folder.name.len;

            const subfolders = try folder.getFolders();
            defer allocator.alloc.free(subfolders);

            for (subfolders) |item| {
                try resultData.appendSlice(item.name[rootlen..]);
                try resultData.append(' ');
            }

            const contents = try folder.getFiles();
            defer allocator.alloc.free(contents);

            for (contents) |item| {
                try resultData.appendSlice(item.name[rootlen..]);
                try resultData.append(' ');
            }

            return .{
                .data = try allocator.alloc.dupe(u8, resultData.items),
            };
        }
    }

    pub fn stop(_: *Shell, param: []const u8) !Result {
        const id = try std.fmt.parseInt(u8, param[5..], 16);

        try vmManager.VMManager.instance.destroy(.{
            .id = id,
        });

        return .{
            .data = try allocator.alloc.dupe(u8, "Stopped"),
        };
    }

    pub fn runCmd(_: *Shell, param: []const u8) !Result {
        const window = win.Window.new("win", win.WindowData{
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.cmd.new(),
            .active = true,
        });

        if (param.len > 5) {
            const cmdself: *wins.cmd.CMDData = @ptrCast(@alignCast(window.data.contents.ptr));

            _ = try cmdself.shell.run(param[4..]);
        }

        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return .{
            .data = try allocator.alloc.dupe(u8, ""),
        };
    }

    pub fn runEdit(self: *Shell, param: []const u8) !Result {
        const window = win.Window.new("win", win.WindowData{
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.editor.new(shader),
            .active = true,
        });

        if (param.len > 5) {
            const edself: *wins.editor.EditorData = @ptrCast(@alignCast(window.data.contents.ptr));

            if (param[5] == '/')
                edself.file = try files.root.getFile(param[5..])
            else
                edself.file = try self.root.getFile(param[5..]);

            if (edself.file == null) return .{
                .data = try allocator.alloc.dupe(u8, ""),
            };
            const fileConts = try edself.file.?.read(null);
            const lines = std.mem.count(u8, fileConts, "\n") + 1;

            if (edself.buffer == null) {
                edself.buffer = try allocator.alloc.alloc(wins.editor.EditorData.Row, lines);
            } else {
                edself.buffer = try allocator.alloc.realloc(edself.buffer.?, lines);
            }

            var iter = std.mem.split(u8, fileConts, "\n");
            var idx: usize = 0;
            while (iter.next()) |line| {
                edself.buffer.?[idx] = .{
                    .text = try allocator.alloc.dupe(u8, line),
                    .render = null,
                };

                idx += 1;
            }
        }

        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return .{
            .data = try allocator.alloc.dupe(u8, ""),
        };
    }

    pub fn runTask(self: *Shell, _: []const u8) !Result {
        _ = self;
        const window = win.Window.new("win", win.WindowData{
            .contents = try wins.tasks.new(shader),
            .active = true,
        });

        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return .{
            .data = try allocator.alloc.dupe(u8, ""),
        };
    }

    pub fn runWeb(self: *Shell, param: []const u8) !Result {
        _ = self;
        const window = win.Window.new("win", win.WindowData{
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.web.new(shader),
            .active = true,
        });

        if (param.len > 4) {
            const webself: *wins.web.WebData = @ptrCast(@alignCast(window.data.contents.ptr));

            webself.path = try allocator.alloc.dupe(u8, param[4..]);
        }

        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return .{
            .data = try allocator.alloc.dupe(u8, ""),
        };
    }

    pub fn runFileInFolder(self: *Shell, folder: *files.Folder, cmd: []const u8, param: []const u8) !Result {
        var resultData = std.ArrayList(u8).init(allocator.alloc);
        defer resultData.deinit();

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
                    try resultData.appendSlice(res.data);
                    if (resultData.items.len != 0)
                        if (resultData.getLast() != '\n') try resultData.append('\n');
                    try line.resize(0);
                } else {
                    try line.append(char);
                }
            }
            const res = try self.runLine(line.items);
            defer allocator.alloc.free(res.data);
            try resultData.appendSlice(res.data);
            if (resultData.items.len != 0 and resultData.getLast() != '\n') try resultData.append('\n');

            return .{
                .data = try allocator.alloc.dupe(u8, resultData.items),
            };
        }

        return error.InvalidFileType;
    }

    pub fn runFile(self: *Shell, cmd: []const u8, param: []const u8) !Result {
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

    pub fn help(_: *Shell, _: []const u8) !Result {
        return .{
            .data = try allocator.alloc.dupe(u8, "" ++
                "Sh\x82\x82\x82ll Help:\n" ++
                "=============\n" ++
                "\n" ++
                "Commands\n" ++
                "--------\n" ++
                "help - prints this\n" ++
                "ls   - lists the contents of the current folder\n" ++
                "cd   - changes the current folder\n" ++
                "bg   - runs a command in the background\n" ++
                "new  - creates a new file\n" ++
                "dnew - creates a new folder\n" ++
                "rem  - removes a file\n" ++
                "drem - removes a folder\n" ++
                "cpy  - copies a file\n" ++
                "dcpy - copies a folder\n" ++
                "cls  - clears the terminal\n" ++
                "exit - closes the terminal\n" ++
                "stop - closes a process with the given id\n" ++
                "\n" ++
                "Applications\n" ++
                "------------\n" ++
                "cmd  - opens cmd\n" ++
                "edit - opens the text editor\n" ++
                "web  - opens the web browser\n" ++
                "task - opens the task manager\n" ++
                "\n" ++
                "You can also run any file in /exec with its name.\n"),
        };
    }

    pub fn new(self: *Shell, param: []const u8) !Result {
        if (param.len > 4) {
            try self.root.newFile(param[4..]);

            return .{
                .data = try allocator.alloc.dupe(u8, "Created"),
            };
        }

        return error.MissingParameter;
    }

    pub fn dnew(self: *Shell, param: []const u8) !Result {
        if (param.len > 5) {
            try self.root.newFolder(param[5..]);

            return .{
                .data = try allocator.alloc.dupe(u8, "Created"),
            };
        }

        return error.MissingParameter;
    }

    pub fn todo(_: *Shell, _: []const u8) !Result {
        return .{
            .data = try allocator.alloc.dupe(u8, "Unimplemented"),
        };
    }

    pub fn getVMResult(self: *Shell) !?Result {
        if (self.vm) |vm_handle| {
            const data = try vmManager.VMManager.instance.getOutput(vm_handle);
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
            try vmManager.VMManager.instance.appendInputSlice(vm_handle, &.{char});
        }
    }

    pub fn runAsm(self: *Shell, folder: *files.Folder, cmd: []const u8, params: []const u8) !Result {
        for (folder.contents.items, 0..) |_, idx| {
            const rootlen = folder.name.len;
            const item = folder.contents.items[idx];

            if (std.mem.eql(u8, item.name[rootlen..], cmd)) {
                const cont = try item.read(null);
                if (cont.len < 4 or !std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                    return error.BadASMFile;
                }

                const ops = cont[4..];

                self.vm = try vmManager.VMManager.instance.spawn(self.root, params, ops);

                return .{
                    .data = try allocator.alloc.dupe(u8, ""),
                };
            }
        }

        return error.FileNotFound;
    }

    pub fn runBg(self: *Shell, cmd: []const u8) !void {
        _ = try self.run(cmd);
        self.vm = null;
    }

    pub fn runLine(self: *Shell, line: []const u8) !Result {
        if (line.len == 0) {
            return .{
                .data = try allocator.alloc.dupe(u8, ""),
            };
        }

        return self.run(line);
    }

    pub fn cpy(self: *Shell, params: []const u8) !Result {
        if (params.len > 4) {
            var iter = std.mem.split(u8, params, " ");
            _ = iter.next();
            const input = iter.next() orelse return error.MissingParameter;
            const output = iter.next() orelse return error.MissingParameter;

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

        return error.MissingParameter;
    }

    pub fn rem(self: *Shell, params: []const u8) !Result {
        if (params.len > 5) {
            var iter = std.mem.split(u8, params, " ");
            _ = iter.next();

            while (iter.next()) |folder| {
                try self.root.removeFile(folder);
            }

            return .{
                .data = try allocator.alloc.dupe(u8, "Removed"),
            };
        }

        return error.MissingParameter;
    }

    pub fn drem(self: *Shell, params: []const u8) !Result {
        if (params.len > 5) {
            var iter = std.mem.split(u8, params, " ");
            _ = iter.next();

            while (iter.next()) |folder| {
                try self.root.removeFolder(folder);
            }

            return .{
                .data = try allocator.alloc.dupe(u8, "Removed"),
            };
        }

        return error.MissingParameter;
    }

    pub fn run(self: *Shell, params: []const u8) anyerror!Result {
        try events.EventManager.instance.sendEvent(systemEvs.EventRunCmd{
            .cmd = params,
        });

        const idx = std.mem.indexOf(u8, params, " ") orelse params.len;
        const cmd = params[0..idx];

        if (!@import("builtin").is_test) {
            if (std.mem.eql(u8, cmd, "cmd")) return self.runCmd(params);
            if (std.mem.eql(u8, cmd, "edit")) return self.runEdit(params);
            if (std.mem.eql(u8, cmd, "web")) return self.runWeb(params);
            if (std.mem.eql(u8, cmd, "task")) return self.runTask(params);
        }
        if (std.mem.eql(u8, cmd, "help")) return self.help(params);
        if (std.mem.eql(u8, cmd, "stop")) return self.stop(params);
        if (std.mem.eql(u8, cmd, "ls")) return self.ls(params);
        if (std.mem.eql(u8, cmd, "cd")) return self.cd(params);
        if (std.mem.eql(u8, cmd, "new")) return self.new(params);
        if (std.mem.eql(u8, cmd, "dnew")) return self.dnew(params);
        if (std.mem.eql(u8, cmd, "rem")) return self.rem(params);
        if (std.mem.eql(u8, cmd, "drem")) return self.drem(params);
        if (std.mem.eql(u8, cmd, "cpy")) return self.cpy(params);
        if (std.mem.eql(u8, cmd, "dcpy")) return self.todo(params);

        if (std.mem.eql(u8, cmd, "bg")) {
            if (params.len > 3) {
                try self.runBg(params[3..]);

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

        if (std.mem.eql(u8, cmd, "cls")) {
            const result: Result = Result{
                .data = try allocator.alloc.dupe(u8, ""),
                .clear = true,
            };

            return result;
        }
        if (std.mem.eql(u8, cmd, "exit")) {
            const result: Result = Result{
                .data = try allocator.alloc.dupe(u8, ""),
                .exit = true,
            };

            return result;
        }

        return self.runFile(cmd, params);
    }

    pub fn deinit(self: *Shell) !void {
        if (self.vm) |vm_handle| {
            try vmManager.VMManager.instance.destroy(vm_handle);
            self.vm = null;
        }
    }
};
