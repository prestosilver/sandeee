const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const windowEvs = @import("../events/window.zig");
const files = @import("../system/files.zig");
const emailWin = @import("../windows/email.zig");

pub var emails: std.ArrayList(Email) = undefined;

pub fn saveEmailsState(path: []const u8) !void {
    var conts = try allocator.alloc.alloc(u8, emails.items.len);

    for (emails.items) |*email| {
        conts[email.id] = 0;
        if (email.viewed) conts[email.id] |= 1 << 0;
        if (email.complete()) conts[email.id] |= 1 << 1;
    }

    _ = try files.root.newFile(path);
    try files.root.writeFile(path, conts, null);

    allocator.alloc.free(conts);
}

pub fn loadEmailsState(path: []const u8) !void {
    if (try files.root.getFile(path)) |file| {
        var conts = try file.read(null);

        for (emails.items) |*email| {
            if (conts.len < email.id + 1) continue;

            email.viewed = (conts[email.id] & (1 << 0)) != 0;
            email.isComplete = (conts[email.id] & (1 << 1)) != 0;
        }
    }
}

pub fn append(e: Email) !void {
    if (emails.items.len < e.id + 1) {
        try emails.resize(e.id + 1);
    }
    emails.items[e.id] = e;
}

pub fn toStr() ![]u8 {
    var result = try allocator.alloc.alloc(u8, 4);

    var len = std.mem.toBytes(emails.items.len)[0..4];
    std.mem.copy(u8, result, len);
    for (emails.items) |email| {
        var start = result.len;

        var idStr = std.mem.toBytes(email.id);
        var boxStr = std.mem.toBytes(email.box);
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
                &boxStr,
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

    var str_contents = try allocator.alloc.alloc(u8, contents.items.len);
    std.mem.copy(u8, str_contents, contents.items);

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
    var path = fm.getContentDir();
    defer allocator.alloc.free(path);

    var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

    var file = try d.openFile("content/emails.eme", .{});

    var lenbuffer: []u8 = try allocator.alloc.alloc(u8, 4);
    var bytebuffer: []u8 = try allocator.alloc.alloc(u8, 1);
    defer allocator.alloc.free(bytebuffer);

    defer allocator.alloc.free(lenbuffer);
    _ = try file.read(lenbuffer);
    var count = @bitCast(u32, lenbuffer[0..4].*);
    try emails.resize(count);

    for (0..count) |idx| {
        emails.items[idx].viewed = false;
        emails.items[idx].isComplete = false;

        _ = try file.read(bytebuffer);
        emails.items[idx].id = bytebuffer[0];
        _ = try file.read(bytebuffer);
        emails.items[idx].box = bytebuffer[0];
        _ = try file.read(bytebuffer);
        emails.items[idx].condition = @intToEnum(Email.Condition, bytebuffer[0]);

        _ = try file.read(lenbuffer);
        var condsize = @bitCast(u32, lenbuffer[0..4].*);
        var condbuffer = try allocator.alloc.alloc(u8, condsize);
        _ = try file.read(condbuffer);
        emails.items[idx].conditionData = condbuffer;

        _ = try file.read(lenbuffer);
        var depssize = @bitCast(u32, lenbuffer[0..4].*);
        var depsbuffer = try allocator.alloc.alloc(u8, depssize);
        _ = try file.read(depsbuffer);
        emails.items[idx].deps = depsbuffer;

        _ = try file.read(lenbuffer);
        var fromsize = @bitCast(u32, lenbuffer[0..4].*);
        var frombuffer: []u8 = try allocator.alloc.alloc(u8, fromsize);
        _ = try file.read(frombuffer);
        emails.items[idx].from = frombuffer;

        _ = try file.read(lenbuffer);
        var subsize = @bitCast(u32, lenbuffer[0..4].*);
        var subbuffer: []u8 = try allocator.alloc.alloc(u8, subsize);
        _ = try file.read(subbuffer);
        emails.items[idx].subject = subbuffer;

        _ = try file.read(lenbuffer);
        var contentsize = @bitCast(u32, lenbuffer[0..4].*);
        var contentbuffer: []u8 = try allocator.alloc.alloc(u8, contentsize);
        _ = try file.read(contentbuffer);
        emails.items[idx].contents = contentbuffer;
    }
}

pub const Email = struct {
    const Self = @This();
    const Condition = enum(u8) {
        None,
        View,
        Submit,
        Run,
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
                if (std.mem.indexOf(u8, dep.deps, &.{self.id})) |_| {
                    if (dep.visible())
                        events.em.sendEvent(windowEvs.EventNotification{
                            .title = "You got mail",
                            .text = dep.subject,
                            .icon = emailWin.notif,
                        });
                }
            }
            events.em.sendEvent(systemEvs.EventEmailRecv{});
        }
    }

    pub fn visible(self: *const Self) bool {
        for (emails.items) |dep| {
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
            if (std.mem.indexOf(u8, dep.deps, &.{self.id})) |_| {
                if (dep.visible()) return true;
            }
        }

        return false;
    }
};
