const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const systemEvs = @import("../events/system.zig");
const windowEvs = @import("../events/window.zig");
const files = @import("../system/files.zig");
const emailWin = @import("../windows/email.zig");

const log = @import("../util/log.zig").log;
const font = @import("../util/font.zig");

pub const EmailManager = struct {
    pub const Email = struct {
        const ConditionKind = enum(u8) {
            None,
            View,
            Submit,
            Run,
            Logins,
            SysCall,
            Debug,
        };

        const Condition = union(ConditionKind) {
            const Self = @This();

            None: struct {},
            View: struct {},
            Submit: struct {
                req: []const u8,
            },
            Run: struct {
                req: []const u8,
            },
            Logins: struct {
                count: u64,
            },
            SysCall: struct {
                id: u8,
            },
            Debug: struct {},

            pub fn toString(self: *const Self) ![]const u8 {
                return switch (self.*) {
                    .None, .View, .Debug => try allocator.alloc.dupe(u8, ""),
                    .Submit => |r| try std.fmt.allocPrint(allocator.alloc, "{s}", .{r.req}),
                    .Run => |r| try std.fmt.allocPrint(allocator.alloc, "{s}", .{r.req}),
                    .Logins => |r| try std.fmt.allocPrint(allocator.alloc, "{}", .{r.count}),
                    .SysCall => |r| try std.fmt.allocPrint(allocator.alloc, "{}", .{r.id}),
                };
            }

            pub fn free(self: *const Self) void {
                switch (self.*) {
                    .Submit => |r| allocator.alloc.free(r.req),
                    .Run => |r| allocator.alloc.free(r.req),
                    else => {},
                }
            }
        };

        from: []const u8,
        to: []const u8,
        subject: []const u8,
        contents: []const u8,
        deps: []u8,

        viewed: bool = false,
        isComplete: bool = false,
        show: bool = true,
        condition: Condition = .None,
        box: u8 = 0,
        id: u8 = 0,

        pub fn lessThan(_: bool, a: Email, b: Email) bool {
            return a.id < b.id;
        }

        pub fn parseTxt(file: std.fs.File) !Email {
            var result = Email{
                .to = "",
                .from = "",
                .subject = "",
                .contents = "",
                .deps = try allocator.alloc.alloc(u8, 0),
                .condition = .{
                    .None = .{},
                },
            };

            var buf_reader = std.io.bufferedReader(file.reader());
            const in_stream = buf_reader.reader();
            var contents = std.ArrayList(u8).init(allocator.alloc);
            defer contents.deinit();

            var buf: [1024]u8 = undefined;
            while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
                _ = std.mem.replace(u8, line, "EEE", font.EEE, line);
                _ = std.mem.replace(u8, line, "Epsilon", font.E ++ "psilon", line);

                if (std.mem.startsWith(u8, line, "id: ")) {
                    result.id = try std.fmt.parseInt(u8, line[4..], 0);
                } else if (std.mem.startsWith(u8, line, "box: ")) {
                    result.box = try std.fmt.parseInt(u8, line[5..], 0);
                } else if (std.mem.startsWith(u8, line, "to: ")) {
                    result.to = try allocator.alloc.dupe(u8, line[4..]);
                } else if (std.mem.startsWith(u8, line, "from: ")) {
                    result.from = try allocator.alloc.dupe(u8, line[6..]);
                } else if (std.mem.startsWith(u8, line, "sub: ")) {
                    result.subject = try allocator.alloc.dupe(u8, line[5..]);
                } else if (std.mem.startsWith(u8, line, "deps: ")) {
                    result.deps = try allocator.alloc.realloc(result.deps, result.deps.len + 1);
                    result.deps[result.deps.len - 1] = try std.fmt.parseInt(u8, line[6..], 0);
                } else if (std.mem.startsWith(u8, line, "submit: ")) {
                    result.condition = .{
                        .Submit = .{
                            .req = try allocator.alloc.dupe(u8, line[8..]),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "run: ")) {
                    result.condition = .{
                        .Run = .{
                            .req = try allocator.alloc.dupe(u8, line[5..]),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "sys: ")) {
                    result.condition = .{
                        .SysCall = .{
                            .id = try std.fmt.parseInt(u8, line[5..], 10),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "logins: ")) {
                    result.condition = .{
                        .Logins = .{
                            .count = try std.fmt.parseInt(u64, line[8..], 10),
                        },
                    };
                } else if (std.mem.eql(u8, line, "view")) {
                    result.condition = .{
                        .View = .{},
                    };
                } else if (std.mem.eql(u8, line, "hide")) {
                    result.show = false;
                } else if (std.mem.eql(u8, line, "debug")) {
                    result.condition = .Debug;
                } else {
                    try contents.appendSlice(line);
                    try contents.appendSlice("\n");
                }
            }

            const str_contents = try allocator.alloc.dupe(u8, contents.items);

            result.contents = str_contents;

            return result;
        }
    };

    emails: std.ArrayList(Email),
    boxes: [][]const u8,

    pub fn init() !EmailManager {
        return EmailManager{
            .emails = std.ArrayList(Email).init(allocator.alloc),
            .boxes = try allocator.alloc.dupe([]const u8, &.{}),
        };
    }

    pub fn deinit(self: *EmailManager) void {
        for (self.emails.items) |email| {
            allocator.alloc.free(email.to);
            allocator.alloc.free(email.deps);
            allocator.alloc.free(email.from);
            allocator.alloc.free(email.subject);
            allocator.alloc.free(email.contents);
            email.condition.free();
        }

        allocator.alloc.free(self.boxes);

        self.emails.deinit();
    }

    pub fn getPc(self: *EmailManager, box: usize) u8 {
        var total: f32 = 0;
        var comp: f32 = 0;
        for (self.emails.items) |email| {
            if (email.box != box) continue;
            total += 1;
            if (email.isComplete) comp += 1;
        }

        if (total == 0) return 100;

        return @as(u8, @intFromFloat(comp / total * 100));
    }

    pub fn getEmailUnlocks(self: *EmailManager, email: *Email) bool {
        for (self.emails.items) |dep| {
            if (dep.box != email.box) continue;
            if (std.mem.indexOf(u8, dep.deps, &.{email.id})) |_| {
                if (self.getEmailVisible(email, "admin@eee.org")) return true;
            }
        }

        return false;
    }

    pub fn getEmailVisible(self: *EmailManager, email: *Email, user: []const u8) bool {
        if (!email.show) return false;
        if (!(std.mem.eql(u8, user, email.from) or std.mem.eql(u8, user, "admin@eee.org") or std.mem.eql(u8, user, email.to))) return false;

        for (self.emails.items) |dep| {
            if (dep.box != email.box) continue;
            if (std.mem.indexOf(u8, email.deps, &.{dep.id})) |_| {
                if (!dep.isComplete) return false;
            }
        }

        return true;
    }

    pub fn setEmailComplete(self: *EmailManager, email: *Email) !void {
        email.isComplete = true;
        if (self.getEmailUnlocks(email)) {
            for (self.emails.items) |*dep| {
                if (dep.box != email.box) continue;
                if (std.mem.indexOf(u8, dep.deps, &.{email.id})) |_| {
                    if (self.getEmailVisible(dep, "admin@eee.org"))
                        try events.EventManager.instance.sendEvent(windowEvs.EventNotification{
                            .title = "You got mail",
                            .text = dep.subject,
                            .icon = emailWin.notif,
                        });
                }
            }
            try events.EventManager.instance.sendEvent(systemEvs.EventEmailRecv{});
        }
    }

    pub fn viewEmail(self: *EmailManager, email: *Email) !void {
        if (!email.viewed) {
            email.viewed = true;

            if (email.condition == .View) {
                try self.setEmailComplete(email);
            }
        }
    }

    pub fn updateDebug(self: *EmailManager) !void {
        for (self.emails.items) |*email| {
            if (email.condition == .Debug) {
                try self.setEmailComplete(email);
            }
        }
    }

    pub fn updateLogins(self: *EmailManager, logins: u64) !void {
        for (self.emails.items) |*email| {
            if (email.condition == .Logins and logins >= email.condition.Logins.count) {
                try self.setEmailComplete(email);
            }
        }
    }

    pub fn saveStateFile(self: *EmailManager, path: []const u8) !void {
        var start = try allocator.alloc.alloc(u8, 1);
        defer allocator.alloc.free(start);

        start[0] = @as(u8, @intCast(self.boxes.len));

        for (self.boxes) |boxname| {
            const sidx = start.len;
            start = try allocator.alloc.realloc(start, start.len + boxname.len + 1);
            start[sidx] = @as(u8, @intCast(boxname.len));
            @memcpy(start[sidx + 1 ..], boxname);
        }

        const conts = try allocator.alloc.alloc(u8, start.len + 256 * self.boxes.len);
        @memset(conts, 0);

        @memcpy(conts[0..start.len], start);

        for (self.emails.items) |*email| {
            if (email.viewed) conts[start.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 0;
            if (email.isComplete) conts[start.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 1;
        }

        _ = try files.root.newFile(path);
        try files.root.writeFile(path, conts, null);

        allocator.alloc.free(conts);
    }

    pub fn loadStateFile(self: *EmailManager, path: []const u8) !void {
        const file = try files.root.getFile(path);

        const conts = try file.read(null);
        var idx: usize = 0;

        const total = conts[idx];
        idx += 1;

        const names = try allocator.alloc.alloc([]const u8, total);
        defer allocator.alloc.free(names);

        for (names) |*name| {
            const len = conts[idx];
            idx += 1;

            name.* = conts[idx .. idx + len];
            idx += len;
        }

        const startidx = idx;

        for (names, 0..) |name, nameidx| {
            for (self.boxes, 0..) |boxname, boxidx| {
                if (std.mem.eql(u8, boxname, name)) {
                    for (self.emails.items) |*email| {
                        if (email.box != boxidx) continue;

                        email.viewed = (conts[startidx + email.id + 256 * nameidx] & (1 << 0)) != 0;
                        email.isComplete = (conts[startidx + email.id + 256 * nameidx] & (1 << 1)) != 0;
                    }
                }
            }
        }
    }

    pub fn append(self: *EmailManager, e: Email) !void {
        try self.emails.append(e);
    }

    pub fn exportData(self: *EmailManager) ![]u8 {
        var result = try allocator.alloc.alloc(u8, 4);

        const len = std.mem.toBytes(self.emails.items.len)[0..4];
        @memcpy(result, len);
        for (self.emails.items) |email| {
            const start = result.len;

            const cond = try email.condition.toString();

            const idStr = std.mem.toBytes(email.id);
            const show = std.mem.toBytes(email.show);
            const toLen = std.mem.toBytes(email.to.len)[0..4];
            const fromLen = std.mem.toBytes(email.from.len)[0..4];
            const depsLen = std.mem.toBytes(email.deps.len)[0..4];
            const condsLen = std.mem.toBytes(cond.len)[0..4];
            const subjectLen = std.mem.toBytes(email.subject.len)[0..4];
            const contentLen = std.mem.toBytes(email.contents.len)[0..4];

            const appends = try std.mem.concat(
                allocator.alloc,
                u8,
                &[_][]const u8{
                    &idStr,
                    &show,
                    &.{@intFromEnum(email.condition)},
                    condsLen,
                    cond,
                    depsLen,
                    email.deps,
                    toLen,
                    email.to,
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

            @memcpy(result[start..], appends);
        }
        return result;
    }

    pub fn loadFromFolder(self: *EmailManager, path: []const u8) !void {
        const folder = try files.root.getFolder(path);
        var fileList = std.ArrayList(*const files.File).init(allocator.alloc);
        defer fileList.deinit();
        try folder.getFilesRec(&fileList);

        self.boxes = try allocator.alloc.alloc([]u8, fileList.items.len + 1);

        self.boxes[self.boxes.len - 1] = "outbox";

        for (fileList.items, 0..) |file, boxid| {
            log.debug("load emails: {s}", .{file.name});

            self.boxes[boxid] = file.name[folder.name.len .. file.name.len - 4];

            const conts = try file.read(null);

            var fidx: usize = 0;

            const start = self.emails.items.len;

            const count = @as(u32, @bitCast(conts[fidx .. fidx + 4][0..4].*));
            try self.emails.resize(start + count);

            fidx += 4;

            for (start..start + count) |idx| {
                self.emails.items[idx].viewed = false;
                self.emails.items[idx].isComplete = false;

                self.emails.items[idx].id = conts[fidx];
                fidx += 1;

                self.emails.items[idx].show = conts[fidx] != 0;
                fidx += 1;

                self.emails.items[idx].box = @as(u8, @intCast(boxid));

                const condKind = @as(Email.ConditionKind, @enumFromInt(conts[fidx]));

                fidx += 1;

                const kind = *align(1) const u32;

                switch (condKind) {
                    .None => {
                        self.emails.items[idx].condition = .{ .None = .{} };
                        fidx += 4;
                    },
                    .View => {
                        self.emails.items[idx].condition = .{ .View = .{} };
                        fidx += 4;
                    },
                    .Debug => {
                        self.emails.items[idx].condition = .{ .Debug = .{} };
                        fidx += 4;
                    },
                    .Submit => {
                        const len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                        fidx += 4;
                        const data = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                        self.emails.items[idx].condition = .{ .Submit = .{
                            .req = data,
                        } };
                        fidx += len;
                    },
                    .Run => {
                        const len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                        fidx += 4;
                        const data = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                        self.emails.items[idx].condition = .{ .Run = .{
                            .req = data,
                        } };
                        fidx += len;
                    },
                    .Logins => {
                        const len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                        fidx += 4;
                        const data = try std.fmt.parseInt(u64, conts[fidx .. fidx + len], 10);
                        self.emails.items[idx].condition = .{ .Logins = .{
                            .count = data,
                        } };
                        fidx += len;
                    },
                    .SysCall => {
                        const len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                        fidx += 4;
                        const data = try std.fmt.parseInt(u8, conts[fidx .. fidx + len], 10);
                        self.emails.items[idx].condition = .{ .SysCall = .{
                            .id = data,
                        } };
                        fidx += len;
                    },
                }

                var len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].deps = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].to = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].from = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].subject = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].contents = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;
            }
            std.sort.insertion(Email, self.emails.items[start..], false, Email.lessThan);
        }
    }
};
