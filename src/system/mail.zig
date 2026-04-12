const std = @import("std");
const c = @import("../c.zig");

const system = @import("../system.zig");
const windows = @import("../windows.zig");
const eee_data = @import("../data.zig");
const events = @import("../events.zig");
const util = @import("../util.zig");

const allocator = util.allocator;
const storage = util.files;
const log = util.log;

const files = system.files;

const email_window = windows.email;

const EventManager = events.EventManager;
const window_events = events.windows;
const system_events = events.system;

const strings = eee_data.strings;

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
                    .None, .View, .Debug => try allocator.dupe(u8, ""),
                    .SubmitContains => |r| try std.fmt.allocPrint(allocator, "{s}", .{r.conts}),
                    .ShellRun => |r| try std.fmt.allocPrint(allocator, "{s}", .{r.cmd}),
                    .SubmitRuns => |r| if (r.input) |input|
                        try std.fmt.allocPrint(allocator, ">{s}||{s}", .{ input, r.conts })
                    else
                        try std.fmt.allocPrint(allocator, "{s}", .{r.conts}),
                    .SubmitLib => |r| if (r.input) |input|
                        try std.fmt.allocPrint(allocator, ">{s}||{s}||{s}", .{ input, r.libfn, r.conts })
                    else
                        try std.fmt.allocPrint(allocator, "{s}||{s}", .{ r.libfn, r.conts }),
                    .Logins => |r| try std.fmt.allocPrint(allocator, "{}", .{r.count}),
                    .SysCall => |r| try std.fmt.allocPrint(allocator, "{}", .{r.id}),
                };
                defer allocator.free(result);

                return std.fmt.allocPrint(allocator, "{c}{s}", .{ @intFromEnum(self.*), result });
            }

            pub fn deinit(self: *const Self) void {
                switch (self.*) {
                    .ShellRun => |runs| {
                        allocator.free(runs.cmd);
                    },
                    .SubmitContains => |contains| {
                        allocator.free(contains.conts);
                    },
                    .SubmitRuns => |runs| {
                        if (runs.input) |input|
                            allocator.free(input);
                        allocator.free(runs.conts);
                    },
                    .SubmitLib => |lib| {
                        if (lib.input) |input|
                            allocator.free(input);
                        allocator.free(lib.libfn);
                        allocator.free(lib.conts);
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

            var reader_buffer: [1024]u8 = undefined;
            var reader = file.reader(&reader_buffer);
            var contents: std.array_list.Managed(u8) = .init(allocator);
            var input: ?[]const u8 = null;
            var deps: std.array_list.Managed(u8) = .init(allocator);
            var condition: std.array_list.Managed(Condition) = .init(allocator);

            while (try reader.interface.takeDelimiter('\n')) |line| {
                _ = std.mem.replace(u8, line, "EEE", strings.EEE, line);
                _ = std.mem.replace(u8, line, "Epsilon", strings.E ++ "psilon", line);

                if (std.mem.startsWith(u8, line, "id: ")) {
                    result.id = try std.fmt.parseInt(u8, line[4..], 0);
                } else if (std.mem.startsWith(u8, line, "box: ")) {
                    result.box = try std.fmt.parseInt(u8, line[5..], 0);
                } else if (std.mem.startsWith(u8, line, "to: ")) {
                    result.to = try allocator.dupe(u8, line[4..]);
                } else if (std.mem.startsWith(u8, line, "from: ")) {
                    result.from = try allocator.dupe(u8, line[6..]);
                } else if (std.mem.startsWith(u8, line, "sub: ")) {
                    result.subject = try allocator.dupe(u8, line[5..]);
                } else if (std.mem.startsWith(u8, line, "deps: ")) {
                    try deps.append(try std.fmt.parseInt(u8, line[6..], 0));
                } else if (std.mem.startsWith(u8, line, "submit: ")) {
                    return error.BadParse;
                } else if (std.mem.startsWith(u8, line, "input: ")) {
                    input = try allocator.dupe(u8, line[7..]);
                } else if (std.mem.startsWith(u8, line, "shell: ")) {
                    try condition.append(.{
                        .ShellRun = .{
                            .cmd = try allocator.dupe(u8, line[7..]),
                        },
                    });
                } else if (std.mem.startsWith(u8, line, "runs: ")) {
                    try condition.append(.{
                        .SubmitRuns = .{
                            .input = input,
                            .conts = try allocator.dupe(u8, line[6..]),
                        },
                    });

                    input = null;
                } else if (std.mem.startsWith(u8, line, "libruns: ")) {
                    if (std.mem.indexOf(u8, line[9..], ":")) |idx| {
                        try condition.append(.{
                            .SubmitLib = .{
                                .input = input,
                                .libfn = try allocator.dupe(u8, line[9 .. 9 + idx]),
                                .conts = try allocator.dupe(u8, line[9 + idx + 1 ..]),
                            },
                        });
                    }

                    input = null;
                } else if (std.mem.startsWith(u8, line, "contains: ")) {
                    try condition.append(.{
                        .SubmitContains = .{
                            .conts = try allocator.dupe(u8, line[10..]),
                        },
                    });
                } else if (std.mem.startsWith(u8, line, "sys: ")) {
                    try condition.append(.{
                        .SysCall = .{
                            .id = try std.fmt.parseInt(u8, line[5..], 10),
                        },
                    });
                } else if (std.mem.startsWith(u8, line, "logins: ")) {
                    try condition.append(.{
                        .Logins = .{
                            .count = try std.fmt.parseInt(u64, line[8..], 10),
                        },
                    });
                } else if (std.mem.eql(u8, line, "view")) {
                    try condition.append(.{
                        .View = .{},
                    });
                } else if (std.mem.eql(u8, line, "hide")) {
                    result.show = false;
                } else if (std.mem.eql(u8, line, "debug")) {
                    try condition.append(.Debug);
                } else {
                    try contents.appendSlice(line);
                    try contents.appendSlice("\n");
                }
            }

            result.contents = try contents.toOwnedSlice();
            result.deps = try deps.toOwnedSlice();
            result.condition = try condition.toOwnedSlice();

            return result;
        }
    };

    emails: std.array_list.Managed(Email) = .init(allocator),
    boxes: std.array_list.Managed([]const u8) = .init(allocator),

    pub fn init() !void {
        EmailManager.instance = .{};
    }

    pub fn deinit(self: *EmailManager) void {
        for (self.emails.items) |email| {
            allocator.free(email.to);
            allocator.free(email.deps);
            allocator.free(email.from);
            allocator.free(email.subject);
            allocator.free(email.contents);
            for (email.condition) |condition|
                condition.deinit();
            allocator.free(email.condition);
        }

        self.boxes.clearAndFree();
        self.emails.clearAndFree();
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
        if (!(std.mem.eql(u8, user, email.from) or std.mem.eql(u8, user, "admin@eee.org") or std.mem.eql(u8, user, email.to) or std.mem.eql(u8, "prestosilver", email.from))) return false;

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
                            .title = "New mail decrypted",
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
        var start: std.array_list.Managed(u8) = .init(allocator);
        defer start.deinit();

        try start.append(@intCast(self.boxes.items.len));

        for (self.boxes.items) |boxname| {
            try start.append(@intCast(boxname.len));
            try start.appendSlice(boxname);
        }

        const conts = try allocator.alloc(u8, start.items.len + 256 * self.boxes.items.len);
        defer allocator.free(conts);
        @memcpy(conts[0..start.items.len], start.items);
        @memset(conts[start.items.len..], 0);

        for (self.emails.items) |*email| {
            if (email.viewed) conts[start.items.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 0;
            if (email.is_complete) conts[start.items.len + @as(usize, @intCast(email.box)) * 256 + email.id] |= 1 << 1;
        }

        const root = try files.FolderLink.resolve(.root);

        _ = root.newFile(path) catch |err| switch (err) {
            error.FileExists => {},
            else => return err,
        };

        try root.writeFile(path, conts, null);
    }

    pub fn loadStateFile(self: *EmailManager, path: []const u8) !void {
        const files_root = try files.FolderLink.resolve(.root);
        const file = try files_root.getFile(path);

        const conts = try file.read(null);
        var idx: usize = 0;

        const total = conts[idx];
        idx += 1;

        const names = try allocator.alloc([]const u8, total);
        defer allocator.free(names);

        for (names) |*name| {
            const len = conts[idx];
            idx += 1;

            name.* = conts[idx .. idx + len];
            idx += len;
        }

        const startidx = idx;

        for (names, 0..) |name, nameidx| {
            for (self.boxes.items, 0..) |boxname, boxidx| {
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
        var result: std.array_list.Managed(u8) = .init(allocator);

        const len = std.mem.toBytes(self.emails.items.len)[0..4];
        try result.appendSlice(len);

        for (self.emails.items) |email| {
            // TODO: fix conds
            const id_string = std.mem.toBytes(email.id);
            const show = std.mem.toBytes(email.show);
            const to_length = std.mem.toBytes(email.to.len)[0..4];
            const from_length = std.mem.toBytes(email.from.len)[0..4];
            const deps_length = std.mem.toBytes(email.deps.len)[0..4];
            const conds_length = std.mem.toBytes(email.condition.len)[0..4];
            const subject_length = std.mem.toBytes(email.subject.len)[0..4];
            const content_length = std.mem.toBytes(email.contents.len)[0..4];

            try result.appendSlice(&id_string);
            try result.appendSlice(&show);

            try result.appendSlice(conds_length);
            for (email.condition) |input| {
                const t = try input.toString();
                defer allocator.free(t);

                try result.appendSlice(t);
                try result.append(0);
            }

            try result.appendSlice(deps_length);
            try result.appendSlice(email.deps);
            try result.appendSlice(to_length);
            try result.appendSlice(email.to);
            try result.appendSlice(from_length);
            try result.appendSlice(email.from);
            try result.appendSlice(subject_length);
            try result.appendSlice(email.subject);
            try result.appendSlice(content_length);
            try result.appendSlice(email.contents);
        }

        return try result.toOwnedSlice();
    }

    pub fn loadFromFolder(self: *EmailManager, path: []const u8) !void {
        const root_path = try files.FolderLink.resolve(.root);
        const folder = try root_path.getFolder(path);

        self.boxes.clearAndFree();

        var current: ?*files.File = folder.files;
        var boxid: usize = 0;

        while (current) |file| : ({
            boxid += 1;
            current = file.next_sibling;
        }) {
            log.info("Load email file {s}", .{file.name});

            try self.boxes.append(file.name[folder.name.len .. file.name.len - 4]);

            const conts = try file.read(null);

            var fidx: usize = 0;

            const start = self.emails.items.len;

            const count: usize = @intCast(@as(*align(1) const u32, @ptrCast(&conts[fidx])).*);

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

                const conds_length = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].condition = try allocator.alloc(Email.Condition, conds_length);

                for (0..conds_length) |cond_idx| {
                    const cond_kind: Email.ConditionKind = @enumFromInt(conts[fidx]);
                    fidx += 1;

                    var data = std.array_list.Managed(u8).init(allocator);
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
                                .conts = try allocator.dupe(u8, data.items),
                            },
                        },
                        .SubmitRuns => if (data.items[0] == '>') blk: {
                            var iter = std.mem.splitSequence(u8, data.items[1..], "||");

                            break :blk .{
                                .SubmitRuns = .{
                                    .input = try allocator.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        } else .{
                            .SubmitRuns = .{
                                .input = null,
                                .conts = try allocator.dupe(u8, data.items),
                            },
                        },
                        .SubmitLib => if (data.items[0] == '>') blk: {
                            var iter = std.mem.splitSequence(u8, data.items[1..], "||");

                            break :blk .{
                                .SubmitLib = .{
                                    .input = try allocator.dupe(u8, iter.next() orelse ""),
                                    .libfn = try allocator.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        } else blk: {
                            var iter = std.mem.splitSequence(u8, data.items, "||");

                            break :blk .{
                                .SubmitLib = .{
                                    .input = null,
                                    .libfn = try allocator.dupe(u8, iter.next() orelse ""),
                                    .conts = try allocator.dupe(u8, iter.next() orelse ""),
                                },
                            };
                        },
                        .ShellRun => .{
                            .ShellRun = .{
                                .cmd = try allocator.dupe(u8, data.items),
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
                        log.debug("Email {} has condition {} with data '{s}'", .{ idx, cond_kind, data.items });
                }

                var len = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].deps = try allocator.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].to = try allocator.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].from = try allocator.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].subject = try allocator.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;

                len = @as(*align(1) const u32, @ptrCast(&conts[fidx])).*;
                fidx += 4;

                self.emails.items[idx].contents = try allocator.dupe(u8, conts[fidx .. fidx + len]);
                fidx += len;
            }

            std.sort.insertion(Email, self.emails.items[start..], false, Email.lessThan);
        }

        try self.boxes.append("outbox");

        log.debug("Loaded {} total emails", .{self.emails.items.len});
    }
};
