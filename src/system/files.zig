const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const fake = @import("pseudo/all.zig");

pub var root: *Folder = undefined;
pub var home: *Folder = undefined;
pub var exec: *Folder = undefined;

pub const ROOT_NAME = "/";

pub const filesError = error{};

pub const File = struct {
    parent: *Folder,
    name: []const u8,
    contents: []u8,

    pseudoWrite: ?*const fn ([]const u8) void = null,
    pseudoRead: ?*const fn () []const u8 = null,

    pub fn write(self: *File, contents: []const u8) !void {
        if (self.pseudoWrite != null) {
            self.pseudoWrite.?(contents);
        } else {
            self.contents = try allocator.alloc.realloc(self.contents, contents.len);
            std.mem.copy(u8, self.contents, contents);
        }
    }

    pub fn read(self: *File) []const u8 {
        if (self.pseudoRead != null) {
            return self.pseudoRead.?();
        } else {
            return self.contents;
        }
    }

    pub fn deinit(self: *File) void {
        allocator.alloc.free(self.name);
        allocator.alloc.free(self.contents);
    }
};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub const Folder = struct {
    name: []const u8,
    subfolders: std.ArrayList(Folder),
    contents: std.ArrayList(File),
    parent: *Folder,

    pub fn init() !void {
        root = try allocator.alloc.create(Folder);

        root.name = try std.fmt.allocPrint(allocator.alloc, ROOT_NAME, .{});
        root.subfolders = std.ArrayList(Folder).init(allocator.alloc);
        root.contents = std.ArrayList(File).init(allocator.alloc);
        root.parent = root;

        try root.subfolders.append(fake.setupFake(root));

        var f = std.fs.cwd().openFile("disk.eee", .{}) catch null;
        if (f == null) {
            var path = fm.getContentDir();
            var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

            f = try d.openFile("content/default.eee", .{});
        }
        defer f.?.close();

        var file = f.?;

        var lenbuffer: []u8 = try allocator.alloc.alloc(u8, 4);
        defer allocator.alloc.free(lenbuffer);
        _ = try file.read(lenbuffer);
        var count = @bitCast(u32, lenbuffer[0..4].*);

        for (range(count)) |_| {
            _ = try file.read(lenbuffer);
            var namesize = @bitCast(u32, lenbuffer[0..4].*);
            var namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try file.read(lenbuffer);
            var contsize = @bitCast(u32, lenbuffer[0..4].*);
            var contbuffer: []u8 = try allocator.alloc.alloc(u8, contsize);
            _ = try file.read(contbuffer);
            _ = try root.newFile(namebuffer);
            _ = root.writeFile(namebuffer, contbuffer);
            allocator.alloc.free(contbuffer);
        }

        root.fixFolders();

        home = root.getFolder("/prof").?;
        exec = root.getFolder("/exec").?;
    }

    pub fn write(self: *Folder, writer: std.fs.File) !void {
        var files = std.ArrayList(File).init(allocator.alloc);
        defer files.deinit();
        try self.getfiles(&files);

        var len = @bitCast([4]u8, @intCast(u32, files.items.len));
        _ = try writer.write(&len);
        for (files.items) |file| {
            len = @bitCast([4]u8, @intCast(u32, file.name.len));
            _ = try writer.write(&len);
            _ = try writer.write(file.name);
            len = @bitCast([4]u8, @intCast(u32, file.contents.len));
            _ = try writer.write(&len);
            _ = try writer.write(file.contents);
        }
    }

    pub fn getfiles(self: *Folder, files: *std.ArrayList(File)) !void {
        if (std.mem.eql(u8, self.name, "/fake/")) return;

        try files.appendSlice(self.contents.items);
        for (self.subfolders.items) |_, idx| {
            try self.subfolders.items[idx].getfiles(files);
        }
    }

    fn fixFolders(self: *Folder) void {
        for (self.subfolders.items) |_, idx| {
            self.subfolders.items[idx].parent = self;
            self.subfolders.items[idx].fixFolders();
        }
        for (self.contents.items) |_, idx| {
            self.contents.items[idx].parent = self;
        }
    }

    fn check(cmd: []const u8, exp: []const u8) bool {
        if (cmd.len != exp.len) return false;

        for (cmd) |char, idx| {
            if (char != exp[idx])
                return false;
        }
        return true;
    }

    pub fn newFile(self: *Folder, name: []const u8) !bool {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.newFile(name[2..]);
                if (check(file.items, "")) return self.newFile(name[1..]);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, fullname)) {
                        return self.subfolders.items[idx].newFile(name[file.items.len + 1 ..]);
                    }
                }

                var folder = Folder{
                    .parent = self,
                    .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }),
                    .contents = std.ArrayList(File).init(allocator.alloc),
                    .subfolders = std.ArrayList(Folder).init(allocator.alloc),
                };
                var result = try folder.newFile(name[file.items.len + 1 ..]);
                if (result) {
                    try self.subfolders.append(folder);
                }
                return result;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        for (self.contents.items) |subfile| {
            if (check(subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return false;
            }
        }

        var cont = try std.fmt.allocPrint(allocator.alloc, "", .{});

        try self.contents.append(File{
            .name = fullname,
            .contents = cont,
            .parent = self,
        });

        return true;
    }

    pub fn newFolder(self: *Folder, name: []const u8) bool {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.newFolder(name[2..]);
                if (check(file.items, "")) return self.newFolder(name[1..]);

                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, file.items)) {
                        return self.subfolders.items[idx].newFolder(name[file.items.len + 1 ..]);
                    }
                }
                var folder = Folder{
                    .parent = self,
                    .name = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name }) catch "",
                    .contents = std.ArrayList(File).init(allocator.alloc),
                    .subfolders = std.ArrayList(Folder).init(allocator.alloc),
                };
                var result = folder.newFolder(name[file.items.len..]);
                self.subfolders.append(folder) catch {};
                return result;
            } else {
                file.append(ch) catch {};
            }
        }

        var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name }) catch undefined;
        for (self.subfolders.items) |subfile| {
            if (check(subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return false;
            }
        }

        self.subfolders.append(Folder{
            .parent = self,
            .name = fullname,
            .contents = std.ArrayList(File).init(allocator.alloc),
            .subfolders = std.ArrayList(Folder).init(allocator.alloc),
        }) catch {};

        return true;
    }

    pub fn writeFile(self: *Folder, name: []const u8, contents: []const u8) bool {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.writeFile(name[2..], contents);
                if (check(file.items, "")) return self.writeFile(name[1..], contents);

                var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }) catch undefined;
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, fullname)) {
                        return self.subfolders.items[idx].writeFile(name[file.items.len..], contents);
                    }
                }
                return false;
            } else {
                file.append(ch) catch {};
            }
        }

        var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name }) catch undefined;
        for (self.contents.items) |subfile, idx| {
            if (check(subfile.name, fullname)) {
                self.contents.items[idx].write(contents) catch {};
                //self.contents.items[idx].contents = contents;
                allocator.alloc.free(fullname);
                return true;
            }
        }
        return false;
    }

    pub fn getFile(self: *Folder, name: []const u8) ?*File {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.getFile(name[2..]);
                if (check(file.items, "")) return self.getFile(name[1..]);

                var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }) catch undefined;
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, fullname)) {
                        return self.subfolders.items[idx].getFile(name[file.items.len..]);
                    }
                }
                return null;
            } else {
                file.append(ch) catch {};
            }
        }

        var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name }) catch undefined;
        defer allocator.alloc.free(fullname);
        for (self.contents.items) |subfile, idx| {
            if (check(subfile.name, fullname)) {
                return &self.contents.items[idx];
            }
        }
        return null;
    }

    pub fn getFolder(self: *Folder, name: []const u8) ?*Folder {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.getFolder(name[2..]);
                if (check(file.items, "")) return self.getFolder(name[1..]);

                var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }) catch undefined;
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, fullname)) {
                        return self.subfolders.items[idx].getFolder(name[file.items.len..]);
                    }
                }
                return null;
            } else {
                file.append(ch) catch {};
            }
        }

        var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name }) catch undefined;
        defer allocator.alloc.free(fullname);
        for (self.subfolders.items) |subfolder, idx| {
            if (check(subfolder.name, fullname)) {
                return &self.subfolders.items[idx];
            }
        }
        return null;
    }


    pub fn deleteFile(self: *Folder, name: []const u8) bool {
        _ = name;
        _ = self;

        return false;
    }

    pub fn deinit(self: *Folder) void {
        for (self.subfolders.items) |_, idx| {
            self.subfolders.items[idx].deinit();
        }
        for (self.contents.items) |_, idx| {
            self.contents.items[idx].deinit();
        }
        self.subfolders.deinit();
        self.contents.deinit();

        allocator.alloc.free(self.name);
    }

    pub fn toStr(self: *Folder) !std.ArrayList(u8) {
        var result = std.ArrayList(u8).init(allocator.alloc);

        var files = std.ArrayList(File).init(allocator.alloc);
        defer files.deinit();
        try self.getfiles(&files);

        var len = @bitCast([4]u8, @intCast(u32, files.items.len));
        result.appendSlice(&len) catch {};
        for (files.items) |file| {
            len = @bitCast([4]u8, @intCast(u32, file.name.len));
            result.appendSlice(&len) catch {};
            result.appendSlice(file.name) catch {};
            len = @bitCast([4]u8, @intCast(u32, file.contents.len));
            result.appendSlice(&len) catch {};
            result.appendSlice(file.contents) catch {};
        }
        return result;
    }
};

pub fn newFile(name: []const u8) !bool {
    return try root.newFile(name);
}

pub fn writeFile(name: []const u8, contents: []const u8) bool {
    return root.writeFile(name, contents);
}

pub fn deleteFile(name: []const u8) bool {
    return root.deleteFile(name);
}

pub fn newFolder(name: []const u8) bool {
    return root.newFolder(name);
}

pub fn toStr() !std.ArrayList(u8) {
    return try root.toStr();
}

pub fn write(path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{});

    defer file.close();

    try root.write(file);
}

pub fn deinit() void {
    root.deinit();
    allocator.alloc.destroy(root);
}
