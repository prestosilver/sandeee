const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const events = @import("../util/events.zig");
const system_events = @import("../events/system.zig");
const window_events = @import("../events/window.zig");
const files = @import("../system/files.zig");
const email_window = @import("../windows/email.zig");

const log = @import("../util/log.zig").log;
const font = @import("../util/font.zig");

pub const EmailManager = struct {
    pub var instance: EmailManager = .{};

    pub const Email = struct {
        const ConditionKind = enum(u8) {
            None,
            View,
            SubmitContains,
            SubmitRuns,
            SubmitLib,
            ShellRun,
            Logins,
            SysCall,
            Debug,
        };

        const Condition = union(ConditionKind) {
            const Self = @This();

            None: struct {},
            View: struct {},
            SubmitContains: struct {
                conts: []const u8,
            },
            SubmitRuns: struct {
                input: ?[]const u8,
                conts: []const u8,
            },
            SubmitLib: struct {
                input: ?[]const u8,
                libfn: []const u8,
                conts: []const u8,
            },
            ShellRun: struct {
                cmd: []const u8,
            },
            Logins: struct {
                count: u64,
            },
            SysCall: struct {
                id: u8,
            },
            Debug: struct {},

            pub fn toString(self: *const Self) ![]const u8 {
                const result = switch (self.*) {
                    .None, .View, .Debug => try allocator.alloc.dupe(u8, ""),
                    .SubmitContains => |r| try std.fmt.allocPrint(allocator.alloc, "{s}", .{r.conts}),
                    .ShellRun => |r| try std.fmt.allocPrint(allocator.alloc, "{s}", .{r.cmd}),
                    .SubmitRuns => |r| if (r.input) |input|
                        try std.fmt.allocPrint(allocator.alloc, ">{s}||{s}", .{ input, r.conts })
                    else
                        try std.fmt.allocPrint(allocator.alloc, "{s}", .{r.conts}),
                    .SubmitLib => |r| if (r.input) |input|
                        try std.fmt.allocPrint(allocator.alloc, ">{s}||{s}||{s}", .{ input, r.libfn, r.conts })
                    else
                        try std.fmt.allocPrint(allocator.alloc, "{s}||{s}", .{ r.libfn, r.conts }),
                    .Logins => |r| try std.fmt.allocPrint(allocator.alloc, "{}", .{r.count}),
                    .SysCall => |r| try std.fmt.allocPrint(allocator.alloc, "{}", .{r.id}),
                };
                defer allocator.alloc.free(result);

                return std.fmt.allocPrint(allocator.alloc, "{c}{s}", .{ @intFromEnum(self.*), result });
            }

            pub fn deinit(self: *const Self) void {
                switch (self.*) {
                    .ShellRun => |runs| {
                        allocator.alloc.free(runs.cmd);
                    },
                    .SubmitContains => |contains| {
                        allocator.alloc.free(contains.conts);
                    },
                    .SubmitRuns => |runs| {
                        if (runs.input) |input|
                            allocator.alloc.free(input);
                        allocator.alloc.free(runs.conts);
                    },
                    .SubmitLib => |lib| {
                        if (lib.input) |input|
                            allocator.alloc.free(input);
                        allocator.alloc.free(lib.libfn);
                        allocator.alloc.free(lib.conts);
                    },
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
        is_complete: bool = false,
        show: bool = true,
        condition: []Condition = &.{},
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
                .deps = &.{},
                .condition = &.{},
            };

            var buf_reader = std.io.bufferedReader(file.reader());
            const in_stream = buf_reader.reader();
            var contents = std.ArrayList(u8).init(allocator.alloc);
            defer contents.deinit();
            var input: ?[]const u8 = null;

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
                    return error.BadParse;
                } else if (std.mem.startsWith(u8, line, "input: ")) {
                    input = try allocator.alloc.dupe(u8, line[7..]);
                } else if (std.mem.startsWith(u8, line, "shell: ")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .ShellRun = .{
                            .cmd = try allocator.alloc.dupe(u8, line[7..]),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "runs: ")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .SubmitRuns = .{
                            .input = input,
                            .conts = try allocator.alloc.dupe(u8, line[6..]),
                        },
                    };

                    input = null;
                } else if (std.mem.startsWith(u8, line, "libruns: ")) {
                    if (std.mem.indexOf(u8, line[9..], ":")) |idx| {
                        result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                        result.condition[result.condition.len - 1] = .{
                            .SubmitLib = .{
                                .input = input,
                                .libfn = try allocator.alloc.dupe(u8, line[9 .. 9 + idx]),
                                .conts = try allocator.alloc.dupe(u8, line[9 + idx + 1 ..]),
                            },
                        };
                    }

                    input = null;
                } else if (std.mem.startsWith(u8, line, "contains: ")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .SubmitContains = .{
                            .conts = try allocator.alloc.dupe(u8, line[10..]),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "sys: ")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .SysCall = .{
                            .id = try std.fmt.parseInt(u8, line[5..], 10),
                        },
                    };
                } else if (std.mem.startsWith(u8, line, "logins: ")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .Logins = .{
                            .count = try std.fmt.parseInt(u64, line[8..], 10),
                        },
                    };
                } else if (std.mem.eql(u8, line, "view")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .{
                        .View = .{},
                    };
                } else if (std.mem.eql(u8, line, "hide")) {
                    result.show = false;
                } else if (std.mem.eql(u8, line, "debug")) {
                    result.condition = try allocator.alloc.realloc(result.condition, result.condition.len + 1);

                    result.condition[result.condition.len - 1] = .Debug;
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

    emails: std.ArrayList(Email) = std.ArrayList(Email).init(allocator.alloc),
    boxes: [][]const u8 = undefined,

    pub fn init() !void {
        EmailManager.instance = .{
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
            for (email.condition) |condition|
                condition.deinit();
            allocator.alloc.free(email.condition);
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
            if (email.is_complete) comp += 1;
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
                if (!dep.is_complete) return false;
            }
        }

        return true;
    }

    pub fn setEmailComplete(self: *EmailManager, email: *Email) !void {
        email.is_complete = true;
        if (self.getEmailUnlocks(email)) {
            for (self.emails.items) |*dep| {
                if (dep.box != email.box) continue;
                if (std.mem.indexOf(u8, dep.deps, &.{email.id})) |_| {
                    if (self.getEmailVisible(dep, "admin@eee.org"))
                        try events.EventManager.instance.sendEvent(window_events.EventNotification{
                            .title = "You got mail",
                            .text = dep.subject,
                            .icon = email_window.notif,
                        });
                }
            }
            try events.EventManager.instance.sendEvent(system_events.EventEmailRecv{});
        }
    }

    pub fn viewEmail(self: *EmailManager, email: *Email) !void {
        if (!email.viewed) {
            email.viewed = true;

            for (email.condition) |condition| {
                if (condition == .View) {
                    try self.setEmailComplete(email);
                }
            }
        }
    }

    pub fn updateDebug(self: *EmailManager) !void {
        for (self.emails.items) |*email| {
            for (email.condition) |condition| {
                if (condition == .Debug) {
                    try self.setEmailComplete(email);
                }
            }
        }
    }

    pub fn updateLogins(self: *EmailManager, logins: u64) !void {
        for (self.emails.items) |*email| {
            for (email.condition) |condition| {
                if (condition == .Logins and logins >= condition.Logins.count) {
                    try self.setEmailComplete(email);
                }
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
        defer allocator.alloc.free(conts);
        @memset(conts, 0);
        @memcpy(conts[0..start.len], start);

        for (self.emails.items) |*email| {
            if (email.viewed) conts[start.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 0;
            if (email.is_complete) conts[start.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 1;
        }

        const root = try files.FolderLink.resolve(.root);

        _ = try root.newFile(path);
        try root.writeFile(path, conts, null);
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
                        email.is_complete = (conts[startidx + email.id + 256 * nameidx] & (1 << 1)) != 0;
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

            var cond_list = std.ArrayList(u8).init(allocator.alloc);
            defer cond_list.deinit();

            for (email.condition) |input| {
                const t = try input.toString();
                defer allocator.alloc.free(t);

                try cond_list.appendSlice(t);
                try cond_list.append(0);
            }

            // TODO: fix conds
            const id_string = std.mem.toBytes(email.id);
            const show = std.mem.toBytes(email.show);
            const to_length = std.mem.toBytes(email.to.len)[0..4];
            const from_length = std.mem.toBytes(email.from.len)[0..4];
            const deps_length = std.mem.toBytes(email.deps.len)[0..4];
            const conds_length = std.mem.toBytes(email.condition.len)[0..4];
            const subject_length = std.mem.toBytes(email.subject.len)[0..4];
            const content_length = std.mem.toBytes(email.contents.len)[0..4];

            const appends = try std.mem.concat(
                allocator.alloc,
                u8,
                &[_][]const u8{
                    &id_string,
                    &show,
                    conds_length,
                    cond_list.items,
                    deps_length,
                    email.deps,
                    to_length,
                    email.to,
                    from_length,
                    email.from,
                    subject_length,
                    email.subject,
                    content_length,
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
        var file_list = std.ArrayList(*files.File).init(allocator.alloc);
        defer file_list.deinit();

        try folder.getFilesRec(&file_list);

        self.boxes = try allocator.alloc.alloc([]const u8, file_list.items.len + 1);

        self.boxes[self.boxes.len - 1] = "outbox";

        for (file_list.items, 0..) |file, boxid| {
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
                self.emails.items[idx].is_complete = false;

                self.emails.items[idx].id = conts[fidx];
                fidx += 1;

                self.emails.items[idx].show = conts[fidx] != 0;
                fidx += 1;

                self.emails.items[idx].box = @as(u8, @intCast(boxid));

                const len_kind = *align(1) const u32;
                const conds_length = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].condition = try allocator.alloc.alloc(Email.Condition, conds_length);

                for (0..conds_length) |cond_idx| {
                    const cond_kind: Email.ConditionKind = @enumFromInt(conts[fidx]);
                    fidx += 1;

                    var data = std.ArrayList(u8).init(allocator.alloc);
                    defer data.deinit();

                    while (conts[fidx] != '\x00') : (fidx += 1) {
                        try data.append(conts[fidx]);
                    }
                    fidx += 1;

                    self.emails.items[idx].condition[cond_idx] = switch (cond_kind) {
                        .View => .{
                            .View = .{},
                        },
                        .SubmitContains => .{
                            .SubmitContains = .{
                                .conts = try allocator.alloc.dupe(u8, data.items),
                            },
                        },
                        .SubmitRuns => if (data.items[0] == '>') blk: {
                            var iter = std.mem.splitSequence(u8, data.items[1..], "||");

                            break :blk .{
                                .SubmitRuns = .{
                                    .input = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        } else .{
                            .SubmitRuns = .{
                                .input = null,
                                .conts = try allocator.alloc.dupe(u8, data.items),
                            },
                        },
                        .SubmitLib => if (data.items[0] == '>') blk: {
                            var iter = std.mem.splitSequence(u8, data.items[1..], "||");

                            break :blk .{
                                .SubmitLib = .{
                                    .input = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                    .libfn = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        } else blk: {
                            var iter = std.mem.splitSequence(u8, data.items, "||");

                            break :blk .{
                                .SubmitLib = .{
                                    .input = null,
                                    .libfn = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.alloc.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        },
                        .ShellRun => .{
                            .ShellRun = .{
                                .cmd = try allocator.alloc.dupe(u8, data.items),
                            },
                        },
                        .Logins => .{
                            .Logins = .{
                                .count = try std.fmt.parseInt(u64, data.items, 0),
                            },
                        },
                        .SysCall => .{
                            .SysCall = .{
                                .id = try std.fmt.parseInt(u8, data.items, 0),
                            },
                        },
                        .Debug => .{
                            .Debug = .{},
                        },
                        else => .{
                            .None = .{},
                        },
                    };

                    if (self.emails.items[idx].condition[cond_idx] != cond_kind)
                        log.info("{} '{s}'", .{ cond_kind, data.items });
                }

                var len = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].deps = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].to = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].from = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].subject = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(len_kind, @ptrCast(conts[fidx .. fidx + 4])).*;
                fidx += 4;

                self.emails.items[idx].contents = try allocator.alloc.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;
            }

            std.sort.insertion(Email, self.emails.items[start..], false, Email.lessThan);
        }
    }
};
