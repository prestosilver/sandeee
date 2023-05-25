const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const windowEvs = @import("../events/window.zig");
const files = @import("../system/files.zig");
const emailWin = @import("../windows/email.zig");

pub var emails: std.ArrayList(Email) = undefined;
pub var boxes: [][]const u8 = undefined;

pub fn saveEmailsState(path: []const u8) !void {
    var start = try allocator.alloc.alloc(u8, 1);

    start[0] = @intCast(u8, boxes.len);

    for (boxes) |boxname| {
        var sidx = start.len;
        start = try allocator.alloc.realloc(start, start.len + boxname.len + 1);
        start[sidx] = @intCast(u8, boxname.len);
        std.mem.copy(u8, start[sidx + 1 ..], boxname);
    }

    var conts = try allocator.alloc.alloc(u8, start.len + 256 * boxes.len);
    @memset(conts, 0);

    std.mem.copy(u8, conts[0..start.len], start);

    for (emails.items) |*email| {
        if (email.viewed) conts[start.len + @intCast(usize, email.box) * 256 + email.id] |= 1 << 0;
        if (email.complete()) conts[start.len + @intCast(usize, email.box) * 256 + email.id] |= 1 << 1;
    }

    _ = try files.root.newFile(path);
    try files.root.writeFile(path, conts, null);

    allocator.alloc.free(conts);
}

pub fn loadEmailsState(path: []const u8) !void {
    if (try files.root.getFile(path)) |file| {
        var conts = try file.read(null);
        var idx: usize = 0;

        var total = conts[idx];
        idx += 1;

        var names = try allocator.alloc.alloc([]const u8, total);

        for (names) |*name| {
            var len = conts[idx];
            idx += 1;

            name.* = conts[idx .. idx + len];
            idx += len;
        }

        var startidx = idx;

        for (names, 0..) |name, nameidx| {
            for (boxes, 0..) |boxname, boxidx| {
                if (std.mem.eql(u8, boxname, name)) {
                    for (emails.items) |*email| {
                        if (email.box != boxidx) continue;

                        email.viewed = (conts[startidx + email.id + 256 * nameidx] & (1 << 0)) != 0;
                        email.isComplete = (conts[startidx + email.id + 256 * nameidx] & (1 << 1)) != 0;
                    }
                }
            }
        }
    }
}

pub fn append(e: Email) !void {
    try emails.append(e);
}

pub fn toStr() ![]u8 {
    var result = try allocator.alloc.alloc(u8, 4);

    var len = std.mem.toBytes(emails.items.len)[0..4];
    std.mem.copy(u8, result, len);
    for (emails.items) |email| {
        var start = result.len;

        var idStr = std.mem.toBytes(email.id);
        var fromLen = std.mem.toBytes(email.from.len)[0..4];
        var depsLen = std.mem.toBytes(email.deps.len)[0..4];
        var condsLen = std.mem.toBytes(email.conditionData.len)[0..4];
        var subjectLen = std.mem.toBytes(email.subject.len)[0..4];
        var contentLen = std.mem.toBytes(email.contents.len)[0..4];

        var appends = try std.mem.concat(
            allocator.alloc,
            u8,
            &[_][]const u8{
                &idStr,
                &.{@enumToInt(email.condition)},
                condsLen,
                email.conditionData,
                depsLen,
                email.deps,
                fromLen,
                email.from,
                subjectLen,
                email.subject,
                contentLen,
                email.contents,
            },
        );
        defer allocator.alloc.free(appends);

        result = try allocator.alloc.realloc(result, start + appends.len);

        std.mem.copy(u8, result[start..], appends);
    }
    return result;
}

pub fn parseTxt(file: std.fs.File) !Email {
    var result = Email{
        .from = "",
        .subject = "",
        .contents = "",
        .conditionData = "",
        .deps = try allocator.alloc.alloc(u8, 0),
        .condition = .None,
    };

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var contents = std.ArrayList(u8).init(allocator.alloc);
    defer contents.deinit();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.startsWith(u8, line, "id: ")) {
            result.id = try std.fmt.parseInt(u8, line[4..], 0);
        } else if (std.mem.startsWith(u8, line, "box: ")) {
            result.box = try std.fmt.parseInt(u8, line[5..], 0);
        } else if (std.mem.startsWith(u8, line, "from: ")) {
            var sub = try allocator.alloc.alloc(u8, line.len - 6);
            std.mem.copy(u8, sub, line[6..]);
            result.from = sub;
        } else if (std.mem.startsWith(u8, line, "sub: ")) {
            var sub = try allocator.alloc.alloc(u8, line.len - 5);
            std.mem.copy(u8, sub, line[5..]);
            result.subject = sub;
        } else if (std.mem.startsWith(u8, line, "deps: ")) {
            result.deps = try allocator.alloc.realloc(result.deps, result.deps.len + 1);
            result.deps[result.deps.len - 1] = try std.fmt.parseInt(u8, line[6..], 0);
        } else if (std.mem.startsWith(u8, line, "submit: ")) {
            result.condition = .Submit;
            result.conditionData = try allocator.alloc.dupe(u8, line[8..]);
        } else if (std.mem.startsWith(u8, line, "run: ")) {
            result.condition = .Run;
            result.conditionData = try allocator.alloc.dupe(u8, line[5..]);
        } else if (std.mem.eql(u8, line, "view")) {
            result.condition = .View;
            result.conditionData = try allocator.alloc.dupe(u8, "");
        } else {
            try contents.appendSlice(line);
            try contents.appendSlice("\n");
        }
    }

    var str_contents = try allocator.alloc.dupe(u8, contents.items);

    result.contents = str_contents;

    return result;
}

pub fn init() void {
    emails = std.ArrayList(Email).init(allocator.alloc);
}

pub fn deinit() void {
    for (emails.items) |email| {
        allocator.alloc.free(email.deps);
        allocator.alloc.free(email.from);
        allocator.alloc.free(email.subject);
        allocator.alloc.free(email.contents);
        allocator.alloc.free(email.conditionData);
    }

    emails.deinit();
}

pub fn load() !void {
    if (try files.root.getFolder("/cont/mail/")) |folder| {
        var fileList = std.ArrayList(*files.File).init(allocator.alloc);
        defer fileList.deinit();
        try folder.getFiles(&fileList);

        boxes = try allocator.alloc.alloc([]u8, fileList.items.len);

        for (fileList.items, 0..) |file, boxid| {
            std.log.info("load emails: {s}", .{file.name});

            boxes[boxid] = file.name[folder.name.len .. file.name.len - 4];

            var conts = try file.read(null);

            var fidx: usize = 0;

            var start = emails.items.len;

            var count = @bitCast(u32, conts[fidx .. fidx + 4][0..4].*);
            try emails.resize(start + count);

            fidx += 4;

            for (start..start + count) |idx| {
                emails.items[idx].viewed = false;
                emails.items[idx].isComplete = false;

                emails.items[idx].id = conts[fidx];
                fidx += 1;

                emails.items[idx].box = @intCast(u8, boxid);

                emails.items[idx].condition = @intToEnum(Email.Condition, conts[fidx]);
                fidx += 1;

                const kind = *align(1) const u32;

                var len = @ptrCast(kind, conts[fidx .. fidx + 4]).*;
                fidx += 4;

                emails.items[idx].conditionData = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @ptrCast(kind, conts[fidx .. fidx + 4]).*;
                fidx += 4;

                emails.items[idx].deps = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @ptrCast(kind, conts[fidx .. fidx + 4]).*;
                fidx += 4;

                emails.items[idx].from = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @ptrCast(kind, conts[fidx .. fidx + 4]).*;
                fidx += 4;

                emails.items[idx].subject = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @ptrCast(kind, conts[fidx .. fidx + 4]).*;
                fidx += 4;

                emails.items[idx].contents = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;
            }
        }
    }
}

pub const Email = struct {
    const Self = @This();
    const Condition = enum(u8) {
        None,
        View,
        Submit,
        Run,
        Logins,
    };

    from: []const u8,
    subject: []const u8,
    contents: []const u8,
    conditionData: []const u8,
    deps: []u8,

    viewed: bool = false,
    isComplete: bool = false,
    condition: Condition = .None,
    box: u8 = 0,
    id: u8 = 0,

    pub fn view(self: *Self) void {
        if (!self.viewed) {
            self.viewed = true;

            if (self.condition == .View) {
                self.setComplete();
            }
        }
    }

    pub fn setComplete(self: *Self) void {
        self.isComplete = true;
        if (self.unlocks()) {
            for (emails.items) |dep| {
                if (dep.box != self.box) continue;
                if (std.mem.indexOf(u8, dep.deps, &.{self.id})) |_| {
                    if (dep.visible())
                        events.EventManager.instance.sendEvent(windowEvs.EventNotification{
                            .title = "You got mail",
                            .text = dep.subject,
                            .icon = emailWin.notif,
                        });
                }
            }
            events.EventManager.instance.sendEvent(systemEvs.EventEmailRecv{});
        }
    }

    pub fn visible(self: *const Self) bool {
        for (emails.items) |dep| {
            if (dep.box != self.box) continue;
            if (std.mem.indexOf(u8, self.deps, &.{dep.id})) |_| {
                if (!dep.complete()) return false;
            }
        }

        return true;
    }

    pub fn complete(self: *const Self) bool {
        return self.isComplete;
    }

    pub fn unlocks(self: *const Self) bool {
        for (emails.items) |dep| {
            if (dep.box != self.box) continue;
            if (std.mem.indexOf(u8, dep.deps, &.{self.id})) |_| {
                if (dep.visible()) return true;
            }
        }

        return false;
    }
};
