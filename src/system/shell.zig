const std = @import("std");
const allocator = @import("../util/allocator.zig");
const files = @import("files.zig");

const Result = struct {
    data: std.ArrayList(u8),
    code: u8,
    clear: bool = false,
};

fn echo(param: []const u8) Result {
    var result: Result = undefined;
    result.data = std.ArrayList(u8).init(allocator.alloc);

    if (param.len > 5) result.data.appendSlice(param[5..]) catch {};

    result.code = 0;

    return result;
}

fn disp(param: []const u8) Result {
    if (param.len > 5) {
        var result: Result = undefined;
        result.data = std.ArrayList(u8).init(allocator.alloc);
        result.code = 1;

        for (files.root.contents.items) |item| {
            var rootlen = files.root.name.len;

            if (std.mem.eql(u8, item.name[rootlen..], param[5..])) {
                result.data.appendSlice(item.contents) catch {};
                result.code = 0;
            }
        }

        if (result.code == 1) {
            result.data.appendSlice("Error file not found") catch {};
        }

        return result;
    } else {}
    return todo(param);
}

fn ls(param: []const u8) Result {
    if (param.len > 3) {} else {
        var result: Result = undefined;
        result.data = std.ArrayList(u8).init(allocator.alloc);

        var rootlen = files.root.name.len;

        for (files.root.subfolders.items) |item| {
            result.data.appendSlice(item.name[rootlen..]) catch {};
            result.data.appendSlice("/ ") catch {};
        }

        for (files.root.contents.items) |item| {
            result.data.appendSlice(item.name[rootlen..]) catch {};
            result.data.append(' ') catch {};
        }
        result.code = 0;

        return result;
    }
    return todo(param);
}

pub fn runFile(cmd: []const u8, param: []const u8) Result {
    var result: Result = undefined;
    result.data = std.ArrayList(u8).init(allocator.alloc);

    for (files.root.contents.items) |item| {
        var rootlen = files.root.name.len;
        if (check(cmd, item.name[rootlen..])) {
            var line = std.ArrayList(u8).init(allocator.alloc);
            defer line.deinit();
            for (item.contents) |char| {
                if (char == '\n') {
                    var res = runLine(line.items);
                    if (res.code != 0) {
                        return res;
                    }
                    result.data.appendSlice(res.data.items) catch {};
                    result.data.append('\n') catch {};
                    line.resize(0) catch {};
                } else {
                    line.append(char) catch {};
                }
            }
            var res = runLine(line.items);
            if (res.code != 0) {
                return res;
            }
            result.data.appendSlice(res.data.items) catch {};
            result.data.append('\n') catch {};
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

pub fn help(_: []const u8) Result {
    var result: Result = undefined;
    result.data = std.ArrayList(u8).init(allocator.alloc);

    result.data.appendSlice("Sheeell Help:\n") catch {};
    result.data.appendSlice("=============\n") catch {};
    result.data.appendSlice("help - prints this\n") catch {};
    result.data.appendSlice("run - runs a command\n") catch {};
    result.data.appendSlice("ls - lists the current folder\n") catch {};
    result.data.appendSlice("disp - displays a files contents\n") catch {};
    result.data.appendSlice("$disp - runs a files contents\n") catch {};
    result.data.appendSlice("$run - runs the output of a command\n") catch {};
    result.data.appendSlice("echo - prints the value") catch {};

    return result;
}

pub fn todo(_: []const u8) Result {
    var result: Result = undefined;
    result.data = std.ArrayList(u8).init(allocator.alloc);

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

pub fn runLine(line: []const u8) Result {
    var command = std.ArrayList(u8).init(allocator.alloc);
    defer command.deinit();
    for (line) |char| {
        if (char == ' ') {
            break;
        } else {
            command.append(char) catch {};
        }
    }
    return run(command.items, line);
}

pub fn run(cmd: []const u8, params: []const u8) Result {
    if (check(cmd, "help")) {
        return help(params);
    }

    if (check(cmd, "echo")) {
        return echo(params);
    }

    if (check(cmd, "ls")) {
        return ls(params);
    }

    if (check(cmd, "disp")) {
        return disp(params);
    }

    if (check(cmd, "$disp")) {
        return todo(params);
    }

    if (check(cmd, "cmd")) {
        return todo(params);
    }

    if (check(cmd, "email")) {
        return todo(params);
    }

    if (check(cmd, "$run")) {
        if (params.len < 6) {
            var result: Result = undefined;
            result.data = std.ArrayList(u8).init(allocator.alloc);

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
            out = run(command.items, params[5..]);
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
        return run(command.items, out.data.items);
    }
    if (check(cmd, "cls")) {
        var result: Result = undefined;
        result.data = std.ArrayList(u8).init(allocator.alloc);
        result.clear = true;
        result.code = 0;

        return result;
    }
    if (check(cmd, "run")) {
        if (params.len < 5) {
            var result: Result = undefined;
            result.data = std.ArrayList(u8).init(allocator.alloc);

            result.data.appendSlice("$run expected parameter") catch {};

            result.code = 2;

            return result;
        }

        return runLine(params[4..]);
    }
    return runFile(cmd, params);
}
