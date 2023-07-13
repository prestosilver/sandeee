const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");
const events = @import("../util/events.zig");
const windowEvs = @import("../events/window.zig");
const wins = @import("../windows/all.zig");
const win = @import("../drawers/window2d.zig");
const tex = @import("../util/texture.zig");
const shd = @import("../util/shader.zig");
const rect = @import("../math/rects.zig");
const opener = @import("opener.zig");

const Result = struct {
    data: std.ArrayList(u8),
    exit: bool = false,
    clear: bool = false,
};

pub var shader: *shd.Shader = undefined;

pub const ASM_HEADER = "EEEp";

pub var frameEnd: u64 = 0;
pub var vms: usize = 0;

pub var threads: std.ArrayList(std.Thread) = undefined;

const ShellError = error{
    FileNotFound,
    MissingParameter,
    BadASMFile,
};

pub const Shell = struct {
    root: *files.Folder,
    vm: ?vm.VM = null,

    pub fn getPrompt(self: *Shell) []const u8 {
        if (self.root.name.len == 0)
            return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name}) catch "> ";
        return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name[0 .. self.root.name.len - 1]}) catch "> ";
    }

    pub fn cd(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            if (param[3] == '/') {
                const folder = try files.root.getFolder(param[4..]);
                self.root = folder;
                return result;
            }

            const folder = try self.root.getFolder(param[3..]);
            self.root = folder;

            return result;
        } else {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            self.root = files.home;

            return result;
        }
    }

    fn ls(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            const folder = try self.root.getFolder(param[3..]);
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            const rootlen = folder.name.len;

            for (folder.subfolders.items) |item| {
                try result.data.appendSlice(item.name[rootlen..]);
                try result.data.append(' ');
            }

            for (folder.contents.items) |item| {
                try result.data.appendSlice(item.name[rootlen..]);
                try result.data.append(' ');
            }

            return result;
        } else {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            const rootlen = self.root.name.len;

            for (self.root.subfolders.items) |item| {
                try result.data.appendSlice(item.name[rootlen..]);
                try result.data.append(' ');
            }

            for (self.root.contents.items) |item| {
                try result.data.appendSlice(item.name[rootlen..]);
                try result.data.append(' ');
            }

            return result;
        }
    }

    pub fn runCmd(_: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

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

        return result;
    }

    pub fn runEdit(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        const window = win.Window.new("win", win.WindowData{
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.editor.new("editor", shader),
            .active = true,
        });

        if (param.len > 5) {
            const edself: *wins.editor.EditorData = @ptrCast(@alignCast(window.data.contents.ptr));

            if (param[5] == '/')
                edself.file = try files.root.getFile(param[5..])
            else
                edself.file = try self.root.getFile(param[5..]);

            edself.buffer.clearAndFree();
            if (edself.file == null) return result;
            try edself.buffer.appendSlice(try edself.file.?.read(null));
        }
        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runWeb(self: *Shell, param: []const u8) !Result {
        _ = self;
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        const window = win.Window.new("win", win.WindowData{
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.web.new("web", shader),
            .active = true,
        });

        if (param.len > 4) {
            const webself: *wins.web.WebData = @ptrCast(@alignCast(window.data.contents.ptr));

            webself.path = try allocator.alloc.dupe(u8, param[4..]);
        }
        try events.EventManager.instance.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runFileInFolder(self: *Shell, folder: *files.Folder, cmd: []const u8, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

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
                    defer res.data.deinit();
                    try result.data.appendSlice(res.data.items);
                    if (result.data.items.len != 0)
                        if (result.data.getLast() != '\n') try result.data.append('\n');
                    try line.resize(0);
                } else {
                    try line.append(char);
                }
            }
            const res = try self.runLine(line.items);
            defer res.data.deinit();
            try result.data.appendSlice(res.data.items);
            if (result.data.items.len != 0 and result.data.getLast() != '\n') try result.data.append('\n');

            return result;
        }

        result.data.deinit();
        return error.InvalidFileType;
    }

    pub fn runFile(self: *Shell, cmd: []const u8, param: []const u8) !Result {
        return self.runFileInFolder(files.exec, cmd, param) catch
            self.runFileInFolder(self.root, cmd, param) catch {
            if (self.root.getFile(cmd) catch null) |file| {
                const opens = try opener.openFile(cmd);
                const params = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ opens, file.name });
                defer allocator.alloc.free(params);

                return self.run(params);
            } else {
                return error.FileNotFound;
            }
        };
    }

    pub fn help(_: *Shell, _: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        try result.data.appendSlice("" ++
            "Sh\x82\x82\x82ll Help:\n" ++
            "=============\n" ++
            "\n" ++
            "Commands\n" ++
            "--------\n" ++
            "help - prints this\n" ++
            "ls   - lists the contents of the current folder\n" ++
            "cd   - changes the current folder\n" ++
            "new  - creates a new file\n" ++
            "dnew - creates a new folder\n" ++
            "rem  - removes a file\n" ++
            "drem - removes a file\n" ++
            "cls  - clears the terminal\n" ++
            "exit - closes the terminal\n" ++
            "\n" ++
            "Applications\n" ++
            "------------\n" ++
            "cmd  - opens cmd\n" ++
            "edit - opens the text editor\n" ++
            "web  - opens the web browser\n" ++
            "\n" ++
            "You can also run any file in /exec with its name.\n");

        return result;
    }

    pub fn new(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (param.len > 4) {
            self.root.newFile(param[4..]) catch |err| {
                result.data.deinit();
                return err;
            };

            try result.data.appendSlice("created");
            return result;
        }

        return error.MissingParameter;
    }

    pub fn dnew(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (param.len > 4) {
            self.root.newFolder(param[4..]) catch |err| {
                result.data.deinit();
                return err;
            };

            try result.data.appendSlice("created");
            return result;
        }

        return error.MissingParameter;
    }

    pub fn todo(_: *Shell, _: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        try result.data.appendSlice("Unimplemented");

        return result;
    }

    pub fn runAsm(self: *Shell, folder: *files.Folder, cmd: []const u8, params: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        for (folder.contents.items, 0..) |_, idx| {
            const rootlen = folder.name.len;
            const item = folder.contents.items[idx];

            if (std.mem.eql(u8, item.name[rootlen..], cmd)) {
                const cont = try item.read(null);
                if (cont.len < 4 or !std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                    result.data.deinit();

                    return error.BadASMFile;
                }

                self.vm = try vm.VM.init(allocator.alloc, self.root, params, false);
                vms += 1;

                const ops = cont[4..];

                self.vm.?.loadString(ops) catch |err| {
                    result.data.deinit();

                    try self.vm.?.deinit();
                    self.vm = null;
                    vms -= 1;

                    return err;
                };

                return result;
            }
        }

        result.data.deinit();

        return error.FileNotFound;
    }

    pub fn updateVM(self: *Shell) !?Result {
        if (self.vm) |*vmInst| {
            if (vmInst.stopped) {
                var result: Result = Result{
                    .data = std.ArrayList(u8).init(allocator.alloc),
                };

                try result.data.appendSlice(vmInst.out.items);

                try vmInst.deinit();
                self.vm = null;
                vms -= 1;

                return result;
            }

            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            try result.data.appendSlice(vmInst.out.items);
            vmInst.out.clearAndFree();

            try threads.append(try std.Thread.spawn(.{}, vmThread, .{self}));

            return result;
        }

        return null;
    }

    pub fn vmThread(self: *Shell) !void {
        const time: u64 = @intCast(std.time.nanoTimestamp());

        if (frameEnd < time) {
            return;
        }

        if (self.vm.?.runTime(frameEnd - time, @import("builtin").mode == .Debug) catch |err| {
            self.vm.?.stopped = true;

            const errString = try std.fmt.allocPrint(allocator.alloc, "Error: {s}\n", .{@errorName(err)});
            defer allocator.alloc.free(errString);

            try self.vm.?.out.appendSlice(errString);

            const msgString = try self.vm.?.getOp();
            defer allocator.alloc.free(msgString);

            try self.vm.?.out.appendSlice(msgString);

            return;
        }) {
            return;
        }
        return;
    }

    pub fn runLine(self: *Shell, line: []const u8) !Result {
        if (line.len == 0) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            return result;
        }

        return self.run(line);
    }

    pub fn rem(self: *Shell, params: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (params.len > 4) {
            self.root.removeFile(params[4..]) catch |err| {
                result.data.deinit();
                return err;
            };
            try result.data.appendSlice("removed");
            return result;
        }

        return error.MissingParameter;
    }

    pub fn run(self: *Shell, params: []const u8) anyerror!Result {
        const idx = std.mem.indexOf(u8, params, " ") orelse params.len;
        const cmd = params[0..idx];

        if (!@import("builtin").is_test) {
            if (std.mem.eql(u8, cmd, "cmd")) return self.runCmd(params);
            if (std.mem.eql(u8, cmd, "edit")) return self.runEdit(params);
            if (std.mem.eql(u8, cmd, "web")) return self.runWeb(params);
        }
        if (std.mem.eql(u8, cmd, "help")) return self.help(params);
        if (std.mem.eql(u8, cmd, "ls")) return self.ls(params);
        if (std.mem.eql(u8, cmd, "cd")) return self.cd(params);
        if (std.mem.eql(u8, cmd, "new")) return self.new(params);
        if (std.mem.eql(u8, cmd, "dnew")) return self.dnew(params);
        if (std.mem.eql(u8, cmd, "rem")) return self.rem(params);

        if (std.mem.eql(u8, cmd, "cls")) {
            const result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
                .clear = true,
            };

            return result;
        }
        if (std.mem.eql(u8, cmd, "exit")) {
            const result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
                .exit = true,
            };

            return result;
        }

        return self.runFile(cmd, params);
    }
};
