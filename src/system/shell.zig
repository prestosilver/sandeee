const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");
const vm = @import("vm.zig");
const events = @import("../util/events.zig");
const windowEvs = @import("../events/window.zig");
const wins = @import("../windows/all.zig");
const win = @import("../drawers/window2d.zig");
const tex = @import("../texture.zig");
const shd = @import("../shader.zig");
const rect = @import("../math/rects.zig");

const Result = struct {
    data: std.ArrayList(u8),
    exit: bool = false,
    clear: bool = false,
};

pub var wintex: *tex.Texture = undefined;
pub var webtex: *tex.Texture = undefined;
pub var edittex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

const VM_TIME = 5000000; // nano seconds
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

    fn echo(_: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (param.len > 5) try result.data.appendSlice(param[5..]);

        return result;
    }

    fn dump(self: *Shell, param: []const u8) !Result {
        if (param.len > 5) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            for (self.root.contents.items) |_, idx| {
                var rootlen = self.root.name.len;
                var item = &self.root.contents.items[idx];

                if (std.mem.eql(u8, item.name[rootlen..], param[5..])) {
                    var cont = item.read();
                    for (cont) |ch| {
                        if (ch < 32 or ch == 255) {
                            if (ch == '\n' or ch == '\r') {
                                try result.data.append('\n');
                            } else {
                                try result.data.appendSlice("\\");
                                var next = try std.fmt.allocPrint(allocator.alloc, "{}", .{ch});
                                defer allocator.alloc.free(next);
                                try result.data.appendSlice(next);
                            }
                        } else {
                            try result.data.append(ch);
                        }
                    }
                    if (item.pseudoRead != null) {
                        allocator.alloc.free(cont);
                    }

                    return result;
                }
            }

            return error.FileNotFound;
        } else {}
        return self.todo(param);
    }

    pub fn cd(self: *Shell, param: []const u8) !Result {
        if (param.len > 3) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            if (check(param[3..], "..")) {
                self.root = self.root.parent;

                return result;
            }

            for (self.root.subfolders.items) |item, idx| {
                var rootlen = self.root.name.len;

                if (std.mem.eql(u8, item.name[rootlen .. item.name.len - 1], param[3..])) {
                    self.root = &self.root.subfolders.items[idx];

                    return result;
                }
            }

            return error.FileNotFound;
        } else {}
        return self.todo(param);
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

        var window = win.Window.new(wintex.*, win.WindowData{
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
            .contents = wins.cmd.new(),
            .active = true,
        });

        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runEdit(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var window = win.Window.new(wintex.*, win.WindowData{
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
            .contents = wins.editor.new(edittex.*, shader.*),
            .active = true,
        });

        if (param.len > 5) {
            var edself = @ptrCast(*wins.editor.EditorData, window.data.contents.self);

            edself.file = self.root.getFile(param[5..]);
            edself.buffer.clearAndFree();
            if (edself.file == null) return result;
            try edself.buffer.appendSlice(edself.file.?.read());
        }
        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runWeb(self: *Shell, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        var window = win.Window.new(wintex.*, win.WindowData{
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
            .contents = wins.web.new(webtex.*, shader.*),
            .active = true,
        });

        if (param.len > 4) {
            var edself = @ptrCast(*wins.editor.EditorData, window.data.contents.self);

            edself.file = self.root.getFile(param[4..]);
        }
        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runFile(self: *Shell, cmd: []const u8, param: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        for (self.root.contents.items) |_, idx| {
            var item = self.root.contents.items[idx];

            var rootlen = self.root.name.len;
            if (check(cmd, item.name[rootlen..])) {
                var line = std.ArrayList(u8).init(allocator.alloc);
                defer line.deinit();

                if (item.read().len > 3 and check(item.read()[0..4], ASM_HEADER)) {
                    return try self.runAsm(param);
                }

                for (item.read()) |char| {
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
        return error.FileNotFound;
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
        try result.data.appendSlice("dump - displays a files contents\n");
        try result.data.appendSlice("$dump - runs a files contents\n");
        try result.data.appendSlice("$run - runs the output of a command\n");
        try result.data.appendSlice("asm - runs a file\n");
        try result.data.appendSlice("echo - prints the value\n");
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

    pub fn check(cmd: []const u8, exp: []const u8) bool {
        if (cmd.len != exp.len) return false;

        for (cmd) |char, idx| {
            if (char != exp[idx])
                return false;
        }
        return true;
    }

    pub fn runAsm(self: *Shell, params: []const u8) !Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };
        var iter = std.mem.split(u8, params, " ");
        var file = iter.first();

        for (self.root.contents.items) |_, idx| {
            var rootlen = self.root.name.len;
            var item = &self.root.contents.items[idx];

            if (std.mem.eql(u8, item.name[rootlen..], file)) {
                var cont = item.read();
                if (cont.len < 4 or !check(item.read()[0..4], ASM_HEADER)) {
                    result.data.deinit();

                    return error.BadASMFile;
                }

                self.vm = try vm.VM.init(allocator.alloc, params);
                vms += 1;

                var ops = item.read()[4..];

                self.vm.?.loadString(ops);

                try self.vm.?.out.append('\n');

                return result;
            }
        }

        result.data.deinit();

        return error.FileNotFound;
    }

    pub fn updateVM(self: *Shell) !?Result {
        if (self.vm.?.runTime(VM_TIME / vms) catch |err| {
            self.vm.?.destroy();
            self.vm = null;
            vms -= 1;

            return err;
        }) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            try result.data.appendSlice(self.vm.?.out.items);

            self.vm.?.destroy();
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

    pub fn run(self: *Shell, cmd: []const u8, params: []const u8) !Result {
        if (check(cmd, "help")) return self.help(params);
        if (check(cmd, "echo")) return self.echo(params);
        if (check(cmd, "ls")) return self.ls(params);
        if (check(cmd, "dump")) return self.dump(params);
        if (check(cmd, "$dump")) return self.todo(params);
        if (check(cmd, "cmd")) return self.runCmd(params);
        if (check(cmd, "edit")) return self.runEdit(params);
        if (check(cmd, "email")) return self.todo(params);
        if (check(cmd, "new")) return self.new(params);
        if (check(cmd, "cd")) return self.cd(params);

        if (check(cmd, "$run")) {
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
        if (check(cmd, "cls")) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.clear = true;

            return result;
        }
        if (check(cmd, "run")) {
            if (params.len < 5) {
                return error.ExpectedParameter;
            }

            return self.runLine(params[4..]);
        }
        if (check(cmd, "asm")) {
            if (params.len < 5) {
                var result: Result = Result{
                    .data = std.ArrayList(u8).init(allocator.alloc),
                };

                try result.data.appendSlice("Need a file name");

                return result;
            }
            return try self.runAsm(params[4..]);
        }
        return self.runFile(cmd, params);
    }
};
