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
    code: u8 = 0,
    exit: bool = false,
    clear: bool = false,
};

pub var wintex: *tex.Texture = undefined;
pub var webtex: *tex.Texture = undefined;
pub var edittex: *tex.Texture = undefined;
pub var shader: *shd.Shader = undefined;

const VM_TIME = 5000000; // nano seconds
const ASM_HEADER = "EEEp";

pub const Shell = struct {
    root: *files.Folder,
    vm: ?vm.VM = null,

    var vms: usize = 0;

    fn echo(_: *Shell, param: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        if (param.len > 5) result.data.appendSlice(param[5..]) catch {};

        result.code = 0;

        return result;
    }

    fn dump(self: *Shell, param: []const u8) Result {
        if (param.len > 5) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.code = 1;

            for (self.root.contents.items) |item| {
                var rootlen = self.root.name.len;

                if (std.mem.eql(u8, item.name[rootlen..], param[5..])) {
                    for (item.contents) |ch| {
                        if (ch < 32 or ch == 255) {
                            if (ch == '\n' or ch == '\r') {
                                result.data.append('\n') catch {};
                            } else {
                                result.data.append('?') catch {};
                            }
                        } else {
                            result.data.append(ch) catch {};
                            result.code = 0;
                        }
                    }
                }
            }

            if (result.code == 1) {
                result.data.appendSlice("Error file not found") catch {};
            }

            return result;
        } else {}
        return self.todo(param);
    }

    pub fn cd(self: *Shell, param: []const u8) Result {
        if (param.len > 3) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.code = 1;

            if (check(param[3..], "..")) {
                self.root = self.root.parent;

                result.code = 0;
                return result;
            }

            for (self.root.subfolders.items) |item, idx| {
                var rootlen = self.root.name.len;

                if (std.mem.eql(u8, item.name[rootlen .. item.name.len - 1], param[3..])) {
                    self.root = &self.root.subfolders.items[idx];

                    result.code = 0;
                    return result;
                }
            }

            if (result.code == 1) {
                result.data.appendSlice("Error folder not found") catch {};
            }

            return result;
        } else {}
        return self.todo(param);
    }

    fn ls(self: *Shell, param: []const u8) Result {
        if (param.len > 3) {
            return self.todo(param);
        } else {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            var rootlen = self.root.name.len;

            for (self.root.subfolders.items) |item| {
                result.data.appendSlice(item.name[rootlen..]) catch {};
                result.data.append(' ') catch {};
            }

            for (self.root.contents.items) |item| {
                result.data.appendSlice(item.name[rootlen..]) catch {};
                result.data.append(' ') catch {};
            }
            result.code = 0;

            return result;
        }
    }

    pub fn runCmd(_: *Shell, _: []const u8) Result {
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

    pub fn runEdit(self: *Shell, param: []const u8) Result {
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
            edself.buffer.appendSlice(edself.file.?.contents) catch {};
        }
        events.em.sendEvent(windowEvs.EventCreateWindow{ .window = window });

        return result;
    }

    pub fn runWeb(self: *Shell, param: []const u8) Result {
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

    pub fn runFile(self: *Shell, cmd: []const u8, param: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        for (self.root.contents.items) |item| {
            var rootlen = self.root.name.len;
            if (check(cmd, item.name[rootlen..])) {
                var line = std.ArrayList(u8).init(allocator.alloc);
                defer line.deinit();

                if (item.contents.len > 3 and check(item.contents[0..4], ASM_HEADER)) {
                    return self.runAsm(param);
                }

                for (item.contents) |char| {
                    if (char == '\n') {
                        var res = self.runLine(line.items);
                        defer res.data.deinit();
                        if (res.code != 0) {
                            result.data.appendSlice(res.data.items) catch {};
                            if (result.data.getLast() != '\n') result.data.append('\n') catch {};
                            result.code = res.code;

                            return result;
                        }
                        result.data.appendSlice(res.data.items) catch {};
                        if (result.data.getLast() != '\n') result.data.append('\n') catch {};
                        line.resize(0) catch {};
                    } else {
                        line.append(char) catch {};
                    }
                }
                var res = self.runLine(line.items);
                defer res.data.deinit();
                if (res.code != 0) {
                    return res;
                }
                result.data.appendSlice(res.data.items) catch {};
                if (result.data.getLast() != '\n') result.data.append('\n') catch {};
                result.code = 0;

                return result;
            }
        }
        result.code = 1;
        result.data.appendSlice("Unknown command: '") catch {};
        result.data.appendSlice(param) catch {};
        result.data.appendSlice("'") catch {};

        return result;
    }

    pub fn help(_: *Shell, _: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        result.data.appendSlice("Sheeell Help:\n") catch {};
        result.data.appendSlice("=============\n") catch {};
        result.data.appendSlice("help - prints this\n") catch {};
        result.data.appendSlice("run - runs a command\n") catch {};
        result.data.appendSlice("ls - lists the current folder\n") catch {};
        result.data.appendSlice("cd - changes the current folder\n") catch {};
        result.data.appendSlice("dump - displays a files contents\n") catch {};
        result.data.appendSlice("$dump - runs a files contents\n") catch {};
        result.data.appendSlice("$run - runs the output of a command\n") catch {};
        result.data.appendSlice("asm - runs a file\n") catch {};
        result.data.appendSlice("echo - prints the value\n") catch {};
        result.data.appendSlice("edit - opens an editor with the file open\n") catch {};
        result.data.appendSlice("cmd - opens cmd") catch {};

        result.code = 0;

        return result;
    }

    pub fn new(self: *Shell, param: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };
        result.code = 1;

        if (param.len > 4) {
            if (self.root.newFile(param[4..])) {
                result.code = 0;
                result.data.appendSlice("created") catch {};
            } else {
                result.data.appendSlice("Failed to create '") catch {};
                result.data.appendSlice(param[4..]) catch {};
                result.data.appendSlice("'") catch {};
            }
        }

        return result;
    }

    pub fn todo(_: *Shell, _: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };

        result.data.appendSlice("Unimplemented") catch {};

        result.code = 1;

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

    pub fn runAsm(self: *Shell, params: []const u8) Result {
        var result: Result = Result{
            .data = std.ArrayList(u8).init(allocator.alloc),
        };
        for (self.root.contents.items) |item| {
            var rootlen = self.root.name.len;

            if (std.mem.eql(u8, item.name[rootlen..], params)) {
                self.vm = vm.VM.init(allocator.alloc);
                vms += 1;

                if (!check(item.contents[0..4], ASM_HEADER)) {
                    result.code = 4;
                    result.data.appendSlice("Error not a asm file") catch {};

                    return result;
                }

                var ops = item.contents[4..];

                self.vm.?.loadString(ops);

                self.vm.?.out.append('\n') catch {};

                return result;
            }
        }

        result.data.appendSlice("File not found") catch {};

        result.code = 1;

        return result;
    }

    pub fn updateVM(self: *Shell) ?Result {
        if (self.vm.?.runTime(VM_TIME / vms) catch |msg| {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.code = 4;
            result.data.appendSlice("ASM Error") catch {};
            result.data.appendSlice(@errorName(msg)) catch {};

            self.vm.?.destroy();
            self.vm = null;
            vms -= 1;

            return result;
        }) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };

            result.data.appendSlice(self.vm.?.out.items) catch {};

            result.code = 0;
            self.vm.?.destroy();
            self.vm = null;
            vms -= 1;

            return result;
        }

        return null;
    }

    pub fn runLine(self: *Shell, line: []const u8) Result {
        if (line.len == 0) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.code = 0;

            return result;
        }

        var command = std.ArrayList(u8).init(allocator.alloc);
        defer command.deinit();
        for (line) |char| {
            if (char == ' ') {
                break;
            } else {
                command.append(char) catch {};
            }
        }
        return self.run(command.items, line);
    }

    pub fn run(self: *Shell, cmd: []const u8, params: []const u8) Result {
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
                var result: Result = Result{
                    .data = std.ArrayList(u8).init(allocator.alloc),
                };

                result.data.appendSlice("$run expected parameter") catch {};

                result.code = 2;

                return result;
            }

            var out: Result = undefined;

            {
                var command = std.ArrayList(u8).init(allocator.alloc);
                defer command.deinit();

                for (params[5..]) |char| {
                    if (char == ' ') {
                        break;
                    } else {
                        command.append(char) catch {};
                    }
                }
                out = self.run(command.items, params[5..]);
            }

            if (out.code != 0) {
                return out;
            }

            defer out.data.deinit();

            var command = std.ArrayList(u8).init(allocator.alloc);
            defer command.deinit();

            for (out.data.items) |char| {
                if (char == ' ') {
                    break;
                } else {
                    command.append(char) catch {};
                }
            }
            return self.run(command.items, out.data.items);
        }
        if (check(cmd, "cls")) {
            var result: Result = Result{
                .data = std.ArrayList(u8).init(allocator.alloc),
            };
            result.clear = true;
            result.code = 0;

            return result;
        }
        if (check(cmd, "run")) {
            if (params.len < 5) {
                var result: Result = Result{
                    .data = std.ArrayList(u8).init(allocator.alloc),
                };

                result.data.appendSlice("$run expected parameter") catch {};

                result.code = 2;

                return result;
            }

            return self.runLine(params[4..]);
        }
        if (check(cmd, "asm")) {
            if (params.len < 5) {
                var result: Result = Result{
                    .data = std.ArrayList(u8).init(allocator.alloc),
                };
                result.code = 0;

                result.data.appendSlice("Need a file name") catch {};

                return result;
            }
            return self.runAsm(params[4..]);
        }
        return self.runFile(cmd, params);
    }
};
