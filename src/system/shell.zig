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

pub var wintex: *tex.Texture = undefined;
pub var webtex: *tex.Texture = undefined;
pub var edittex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

const VM_TIME = 8000000; // nano seconds
const ASM_HEADER = "EEEp";

const ShellError = error{
    FileNotFound,
    MissingParameter,
    BadASMFile,
};

pub const Shell = struct {
    root: *files.Folder,
    vm: ?vm.VM = null,

    var vms: usize = 0;

    pub fn getPrompt(self: *Shell) []const u8 {
        return std.fmt.allocPrint(allocator.alloc, "{s}> ", .{self.root.name[0 .. self.root.name.len - 1]}) catch "> ";
    }

    pub fn cd(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            if (try self.root.getFolder(param[3..])) |folder| {
                self.root = folder;
                return result;
            }

            return error.FileNotFound;
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
            return self.todo(param);
        } else {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            var rootlen = self.root.name.len;

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

    pub fn runCmd(_: *Shell, _: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var window = win.Window.new(wintex, win.WindowData{
            .pos = rect.Rectangle{
                .x = 100,
                .y = 100,
                .w = 400,
                .h = 300,
            },
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.cmd.new(),
            .active = true,
        });

        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runEdit(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var window = win.Window.new(wintex, win.WindowData{
            .pos = rect.Rectangle{
                .x = 100,
                .y = 100,
                .w = 400,
                .h = 300,
            },
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.editor.new(edittex, shader),
            .active = true,
        });

        if (param.len > 5) {
            const alignment = @typeInfo(*wins.editor.EditorData).Pointer.alignment;
            var edself = @ptrCast(*wins.editor.EditorData, @alignCast(alignment, window.data.contents.ptr));

            edself.file = try self.root.getFile(param[5..]);
            edself.buffer.clearAndFree();
            if (edself.file == null) return result;
            try edself.buffer.appendSlice(try edself.file.?.read(null));
        }
        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runWeb(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var window = win.Window.new(wintex, win.WindowData{
            .pos = rect.Rectangle{
                .x = 100,
                .y = 100,
                .w = 400,
                .h = 300,
            },
            .source = rect.Rectangle{
                .x = 0.0,
                .y = 0.0,
                .w = 1.0,
                .h = 1.0,
            },
            .contents = try wins.web.new(webtex, shader),
            .active = true,
        });

        if (param.len > 4) {
            const alignment = @typeInfo(*wins.web.WebData).Pointer.alignment;
            var webself = @ptrCast(*wins.web.WebData, @alignCast(alignment, window.data.contents.ptr));

            webself.file = try self.root.getFile(param[4..]);
        }
        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runFileInFolder(self: *Shell, folder: *files.Folder, cmd: []const u8, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var folderlen = folder.name.len;
        var cmdeep = try std.fmt.allocPrint(allocator.alloc, "{s}.eep", .{cmd});
        defer allocator.alloc.free(cmdeep);

        for (folder.contents.items, 0..) |_, idx| {
            var item = folder.contents.items[idx];

            if (std.mem.eql(u8, cmd, item.name[folderlen..])) {
                var line = std.ArrayList(u8).init(allocator.alloc);
                defer line.deinit();

                if ((try item.read(null)).len > 3 and std.mem.eql(u8, (try item.read(null))[0..4], ASM_HEADER)) {
                    return try self.runAsm(folder, cmd, param);
                }

                for (try item.read(null)) |char| {
                    if (char == '\n') {
                        var res = try self.runLine(line.items);
                        defer res.data.deinit();
                        try result.data.appendSlice(res.data.items);
                        if (result.data.getLast() != '\n') try result.data.append('\n');
                        try line.resize(0);
                    } else {
                        try line.append(char);
                    }
                }
                var res = try self.runLine(line.items);
                defer res.data.deinit();
                try result.data.appendSlice(res.data.items);
                if (result.data.items.len != 0 and result.data.getLast() != '\n') try result.data.append('\n');

                return result;
            }

            if (std.mem.eql(u8, cmdeep, item.name[folderlen..])) {
                var line = std.ArrayList(u8).init(allocator.alloc);
                defer line.deinit();

                var cont = try item.read(null);

                if (cont.len > 3 and std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                    return try self.runAsm(folder, cmdeep, param);
                }

                for (cont) |char| {
                    if (char == '\n') {
                        var res = try self.runLine(line.items);
                        defer res.data.deinit();
                        try result.data.appendSlice(res.data.items);
                        if (result.data.getLast() != '\n') try result.data.append('\n');
                        try line.resize(0);
                    } else {
                        try line.append(char);
                    }
                }
                var res = try self.runLine(line.items);
                defer res.data.deinit();
                try result.data.appendSlice(res.data.items);
                if (result.data.getLast() != '\n') try result.data.append('\n');

                return result;
            }
        }

        result.data.deinit();
        return error.FileNotFound;
    }

    pub fn runFile(self: *Shell, cmd: []const u8, param: []const u8) !Result {
        return self.runFileInFolder(files.exec, cmd, param) catch
            self.runFileInFolder(self.root, cmd, param) catch {
            if (try self.root.getFile(cmd) != null) {
                var opens = try opener.openFile(cmd);
                var params = try std.fmt.allocPrint(allocator.alloc, "{s} {s}", .{ opens, param });
                defer allocator.alloc.free(params);

                return self.run(opens, params);
            } else {
                return error.FileNotFound;
            }
        };
    }

    pub fn help(_: *Shell, _: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        try result.data.appendSlice("Sheeell Help:\n");
        try result.data.appendSlice("=============\n");
        try result.data.appendSlice("help - prints this\n");
        try result.data.appendSlice("run - runs a command\n");
        try result.data.appendSlice("ls - lists the current folder\n");
        try result.data.appendSlice("cd - changes the current folder\n");
        try result.data.appendSlice("$run - runs the output of a command\n");
        try result.data.appendSlice("asm - runs a file\n");
        try result.data.appendSlice("edit - opens an editor with the file open\n");
        try result.data.appendSlice("cmd - opens cmd");

        return result;
    }

    pub fn new(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (param.len > 4) {
            if (try self.root.newFile(param[4..])) {
                try result.data.appendSlice("created");
                return result;
            } else {
                result.data.deinit();
                return error.FileNotFound;
            }
        }

        return self.todo(param);
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
            var rootlen = folder.name.len;
            var item = &folder.contents.items[idx];

            if (std.mem.eql(u8, item.name[rootlen..], cmd)) {
                var cont = try item.read(null);
                if (cont.len < 4 or !std.mem.eql(u8, cont[0..4], ASM_HEADER)) {
                    result.data.deinit();

                    return error.BadASMFile;
                }

                self.vm = try vm.VM.init(allocator.alloc, self.root, params);
                vms += 1;

                var ops = cont[4..];

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
        if (self.vm.?.runTime(VM_TIME / vms) catch |err| {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            try result.data.appendSlice(self.vm.?.out.items);

            var errString = try std.fmt.allocPrint(allocator.alloc, "Error: {s}\n", .{@errorName(err)});
            defer allocator.alloc.free(errString);

            try result.data.appendSlice(errString);

            var msgString = try self.vm.?.getOp();
            defer allocator.alloc.free(msgString);

            try result.data.appendSlice(msgString);

            try self.vm.?.deinit();
            self.vm = null;
            vms -= 1;

            return result;
        }) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            try result.data.appendSlice(self.vm.?.out.items);

            try self.vm.?.deinit();
            self.vm = null;
            vms -= 1;

            return result;
        }

        return null;
    }

    pub fn runLine(self: *Shell, line: []const u8) !Result {
        if (line.len == 0) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            return result;
        }

        var command = std.ArrayList(u8).init(allocator.alloc);
        defer command.deinit();
        for (line) |char| {
            if (char == ' ') {
                break;
            } else {
                try command.append(char);
            }
        }
        return self.run(command.items, line);
    }

    pub fn rem(self: *Shell, params: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (params.len > 4) {
            self.root.removeFile(params[4..], null) catch {
                result.data.deinit();
                return error.FileNotFound;
            };
            try result.data.appendSlice("removed");
            return result;
        }

        return self.todo(params);
    }

    pub fn run(self: *Shell, cmd: []const u8, params: []const u8) !Result {
        if (std.mem.eql(u8, cmd, "help")) return self.help(params);
        if (std.mem.eql(u8, cmd, "ls")) return self.ls(params);
        if (std.mem.eql(u8, cmd, "cmd")) return self.runCmd(params);
        if (std.mem.eql(u8, cmd, "edit")) return self.runEdit(params);
        if (std.mem.eql(u8, cmd, "web")) return self.runWeb(params);
        if (std.mem.eql(u8, cmd, "new")) return self.new(params);
        if (std.mem.eql(u8, cmd, "rem")) return self.rem(params);
        if (std.mem.eql(u8, cmd, "cd")) return self.cd(params);

        if (std.mem.eql(u8, cmd, "$run")) {
            if (params.len < 6) {
                return error.ExpectedParameter;
            }

            var out: Result = undefined;

            {
                var command = std.ArrayList(u8).init(allocator.alloc);
                defer command.deinit();

                for (params[5..]) |char| {
                    if (char == ' ') {
                        break;
                    } else {
                        try command.append(char);
                    }
                }
                out = try self.run(command.items, params[5..]);
            }

            defer out.data.deinit();

            var command = std.ArrayList(u8).init(allocator.alloc);
            defer command.deinit();

            for (out.data.items) |char| {
                if (char == ' ') {
                    break;
                } else {
                    try command.append(char);
                }
            }
            return self.run(command.items, out.data.items);
        }
        if (std.mem.eql(u8, cmd, "cls")) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.clear = true;

            return result;
        }
        if (std.mem.eql(u8, cmd, "exit")) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.exit = true;

            return result;
        }
        if (std.mem.eql(u8, cmd, "run")) {
            if (params.len < 5) {
                return error.ExpectedParameter;
            }

            return self.runLine(params[4..]);
        }
        return self.runFile(cmd, params);
    }
};
