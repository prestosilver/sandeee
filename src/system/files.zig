const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const fake = @import("pseudo/all.zig");
const vm = @import("vm.zig");

pub var root: *Folder = undefined;
pub var home: *Folder = undefined;
pub var exec: *Folder = undefined;

var rootOut: ?[]const u8 = null;

pub const ROOT_NAME = "/";

pub const File = struct {
    parent: *Folder,
    name: []const u8,
    contents: []u8,

    pseudoWrite: ?*const fn ([]const u8, ?*vm.VM) anyerror!void = null,
    pseudoRead: ?*const fn (?*vm.VM) anyerror![]const u8 = null,

    pub fn write(self: *File, contents: []const u8, vmInstance: ?*vm.VM) !void {
        if (self.pseudoWrite != null) {
            return self.pseudoWrite.?(contents, vmInstance);
        } else {
            self.contents = try allocator.alloc.realloc(self.contents, contents.len);
            std.mem.copy(u8, self.contents, contents);
        }
    }

    pub fn read(self: *File, vmInstance: ?*vm.VM) ![]const u8 {
        if (self.pseudoRead != null) {
            return self.pseudoRead.?(vmInstance);
        } else {
            return self.contents;
        }
    }

    pub fn deinit(self: *File) void {
        allocator.alloc.free(self.name);
        allocator.alloc.free(self.contents);
        allocator.alloc.destroy(self);
    }
};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub const Folder = struct {
    name: []const u8,
    subfolders: std.ArrayList(*Folder),
    contents: std.ArrayList(*File),
    parent: *Folder,
    protected: bool = false,

    pub fn loadDisk(file: std.fs.File) !void {
        var lenbuffer: []u8 = try allocator.alloc.alloc(u8, 4);
        defer allocator.alloc.free(lenbuffer);
        _ = try file.read(lenbuffer);
        var folderCount = @bitCast(u32, lenbuffer[0..4].*);
        for (range(folderCount)) |_| {
            _ = try file.read(lenbuffer);
            var namesize = @bitCast(u32, lenbuffer[0..4].*);
            var namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try root.newFolder(namebuffer);
        }

        _ = try file.read(lenbuffer);
        var fileCount = @bitCast(u32, lenbuffer[0..4].*);
        for (range(fileCount)) |_| {
            _ = try file.read(lenbuffer);
            var namesize = @bitCast(u32, lenbuffer[0..4].*);
            var namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try file.read(lenbuffer);
            var contsize = @bitCast(u32, lenbuffer[0..4].*);
            var contbuffer: []u8 = try allocator.alloc.alloc(u8, contsize);
            defer allocator.alloc.free(contbuffer);
            _ = try file.read(contbuffer);
            _ = try root.newFile(namebuffer);
            try root.writeFile(namebuffer, contbuffer, null);
        }
    }

    pub fn setupDisk(diskName: []const u8) !void {
        root = try allocator.alloc.create(Folder);
        defer root.deinit();

        root.* = .{
            .protected = false,
            .name = try allocator.alloc.dupe(u8, ROOT_NAME),
            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
            .contents = std.ArrayList(*File).init(allocator.alloc),
            .parent = root,
        };

        var path = fm.getContentDir();
        defer allocator.alloc.free(path);
        var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

        var recovery = try d.openFile("content/recovery.eee", .{});
        defer recovery.close();
        try loadDisk(recovery);

        var out = try std.fmt.allocPrint(allocator.alloc, "{s}/disks/{s}", .{ path, diskName });
        defer allocator.alloc.free(out);

        var file = try std.fs.cwd().createFile(out, .{});

        defer file.close();

        root.fixFolders();

        try root.write(file);
    }

    pub fn init(aDiskPath: ?[]const u8) !void {
        if (aDiskPath) |diskPath| {
            root = try allocator.alloc.create(Folder);

            root.* = .{
                .protected = false,
                .name = try allocator.alloc.dupe(u8, ROOT_NAME),
                .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                .contents = std.ArrayList(*File).init(allocator.alloc),
                .parent = root,
            };

            try root.subfolders.append(try fake.setupFake(root));

            var path = fm.getContentDir();
            defer allocator.alloc.free(path);

            var d = try std.fs.cwd().openDir(path, .{ .access_sub_paths = true });

            rootOut = try std.fmt.allocPrint(allocator.alloc, "{s}/disks/{s}", .{ path, diskPath });

            var user = (try d.openDir("disks", .{})).openFile(diskPath, .{}) catch null;
            if (user) |userdisk| {
                defer userdisk.close();
                try loadDisk(userdisk);
            }

            root.fixFolders();

            if (try root.getFolder("/prof")) |folder| {
                home = folder;
            } else @panic("Disk has no prof folder");

            if (try root.getFolder("/exec")) |folder| {
                exec = folder;
            } else @panic("Disk has no exec folder");

            return;
        }
    }

    pub fn write(self: *Folder, writer: std.fs.File) !void {
        var folders = std.ArrayList(*Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFolders(&folders);

        var len = @bitCast([4]u8, @intCast(u32, folders.items.len));
        _ = try writer.write(&len);
        for (folders.items) |folder| {
            len = @bitCast([4]u8, @intCast(u32, folder.name.len));
            _ = try writer.write(&len);
            _ = try writer.write(folder.name);
        }

        var files = std.ArrayList(*File).init(allocator.alloc);
        defer files.deinit();
        try self.getFiles(&files);

        len = @bitCast([4]u8, @intCast(u32, files.items.len));
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

    pub fn getFolders(self: *Folder, folders: *std.ArrayList(*Folder)) !void {
        if (self.protected) return;

        try folders.append(self);
        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFolders(folders);
        }
    }

    pub fn getFiles(self: *Folder, files: *std.ArrayList(*File)) !void {
        if (self.protected) return;

        try files.appendSlice(self.contents.items);
        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFiles(files);
        }
    }

    fn sortList(comptime T: type, a: T, b: T) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }

    fn fixFolders(self: *Folder) void {
        std.sort.sort(*Folder, self.subfolders.items, *Folder, sortList);
        std.sort.sort(*File, self.contents.items, *File, sortList);
        for (self.subfolders.items, 0..) |_, idx| {
            self.subfolders.items[idx].parent = self;
            self.subfolders.items[idx].fixFolders();
        }
        for (self.contents.items, 0..) |_, idx| {
            self.contents.items[idx].parent = self;
        }
    }

    pub fn newFile(self: *Folder, name: []const u8) !bool {
        if (self.protected) return error.FolderProtected;

        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, ".")) return self.newFile(name[2..]);
                if (std.mem.eql(u8, file.items, "")) return self.newFile(name[1..]);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.mem.eql(u8, folder.name, fullname)) {
                        return self.subfolders.items[idx].newFile(name[file.items.len + 1 ..]);
                    }
                }

                var folder = try allocator.alloc.create(Folder);
                folder.* = .{
                    .parent = self,
                    .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }),
                    .contents = std.ArrayList(*File).init(allocator.alloc),
                    .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
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
            if (std.mem.eql(u8, subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return false;
            }
        }

        var cont = try allocator.alloc.alloc(u8, 0);

        var adds = try allocator.alloc.create(File);
        adds.* = .{
            .name = fullname,
            .contents = cont,
            .parent = self,
        };
        try self.contents.append(adds);

        self.fixFolders();

        return true;
    }

    pub fn newFolder(self: *Folder, name: []const u8) !bool {
        if (self.protected) return error.FolderProtected;
        if (name.len == 0) return true;
        if (name[name.len - 1] != '/') {
            var newName = try std.fmt.allocPrint(allocator.alloc, "{s}/", .{name});
            defer allocator.alloc.free(newName);
            return self.newFolder(newName);
        }
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, "..")) return self.parent.newFolder(name[3..]);
                if (std.mem.eql(u8, file.items, ".")) return self.newFolder(name[2..]);
                if (std.mem.eql(u8, file.items, "")) return self.newFolder(name[1..]);
                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);

                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.ascii.eqlIgnoreCase(folder.name, fullname)) {
                        return self.subfolders.items[idx].newFolder(name[file.items.len + 1 ..]);
                    }
                }
                var folder = try allocator.alloc.create(Folder);
                folder.* = Folder{
                    .parent = self,
                    .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }),
                    .contents = std.ArrayList(*File).init(allocator.alloc),
                    .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                };
                var result = folder.newFolder(name[file.items.len..]);
                try self.subfolders.append(folder);
                return result;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
        for (self.subfolders.items) |subfile| {
            if (std.ascii.eqlIgnoreCase(subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return false;
            }
        }

        var folder = try allocator.alloc.create(Folder);
        folder.* = .{
            .parent = self,
            .name = fullname,
            .contents = std.ArrayList(*File).init(allocator.alloc),
            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
        };
        try self.subfolders.append(folder);

        self.fixFolders();

        return true;
    }

    pub fn writeFile(self: *Folder, name: []const u8, contents: []const u8, vmInstance: ?*vm.VM) !void {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, "..")) return try self.parent.writeFile(name[3..], contents, vmInstance);
                if (std.mem.eql(u8, file.items, ".")) return try self.writeFile(name[2..], contents, vmInstance);
                if (std.mem.eql(u8, file.items, "")) return try self.writeFile(name[1..], contents, vmInstance);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.mem.eql(u8, folder.name, fullname)) {
                        return try self.subfolders.items[idx].writeFile(name[file.items.len..], contents, vmInstance);
                    }
                }
                return error.FolderNotFound;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                try self.contents.items[idx].write(contents, vmInstance);
                allocator.alloc.free(fullname);
                return;
            }
        }
        return error.FileNotFound;
    }

    pub fn removeFile(self: *Folder, name: []const u8, vmInstance: ?*vm.VM) !void {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, "..")) return try self.parent.removeFile(name[3..], vmInstance);
                if (std.mem.eql(u8, file.items, ".")) return try self.removeFile(name[2..], vmInstance);
                if (std.mem.eql(u8, file.items, "")) return try self.removeFile(name[1..], vmInstance);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.mem.eql(u8, folder.name, fullname)) {
                        return try self.subfolders.items[idx].removeFile(name[file.items.len..], vmInstance);
                    }
                }
                return error.FolderNotFound;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                _ = self.contents.orderedRemove(idx);
                allocator.alloc.free(fullname);
                return;
            }
        }
        return error.FileNotFound;
    }

    pub fn getFile(self: *Folder, name: []const u8) !?*File {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, "..")) return self.parent.getFile(name[3..]);
                if (std.mem.eql(u8, file.items, ".")) return self.getFile(name[2..]);
                if (std.mem.eql(u8, file.items, "")) return self.getFile(name[1..]);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.mem.eql(u8, folder.name, fullname)) {
                        return self.subfolders.items[idx].getFile(name[file.items.len..]);
                    }
                }
                return null;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        defer allocator.alloc.free(fullname);
        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                return self.contents.items[idx];
            }
        }
        return null;
    }

    pub fn getFolder(self: *Folder, name: []const u8) !?*Folder {
        if (std.mem.eql(u8, name, "..")) return self.parent;

        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (std.mem.eql(u8, file.items, "..")) return self.parent.getFolder(name[3..]);
                if (std.mem.eql(u8, file.items, ".")) return self.getFolder(name[2..]);
                if (std.mem.eql(u8, file.items, "")) return self.getFolder(name[1..]);

                var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items });
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items, 0..) |folder, idx| {
                    if (std.ascii.eqlIgnoreCase(folder.name, fullname)) {
                        return self.subfolders.items[idx].getFolder(name[file.items.len..]);
                    }
                }
                return null;
            } else {
                try file.append(ch);
            }
        }

        var fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name });
        defer allocator.alloc.free(fullname);
        for (self.subfolders.items, 0..) |subfolder, idx| {
            if (std.ascii.eqlIgnoreCase(subfolder.name, fullname)) {
                return self.subfolders.items[idx];
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
        for (self.subfolders.items) |*item| {
            item.*.deinit();
        }

        for (self.contents.items) |*item| {
            item.*.deinit();
        }

        self.subfolders.deinit();
        self.contents.deinit();

        allocator.alloc.free(self.name);
        allocator.alloc.destroy(self);
    }

    pub fn toStr(self: *Folder) !std.ArrayList(u8) {
        var result = std.ArrayList(u8).init(allocator.alloc);

        var folders = std.ArrayList(*Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFolders(&folders);

        var len = @bitCast([4]u8, @intCast(u32, folders.items.len));
        try result.appendSlice(&len);
        for (folders.items) |folder| {
            len = @bitCast([4]u8, @intCast(u32, folder.name.len));
            try result.appendSlice(&len);
            try result.appendSlice(folder.name);
        }

        var files = std.ArrayList(*File).init(allocator.alloc);
        defer files.deinit();
        try self.getFiles(&files);

        len = @bitCast([4]u8, @intCast(u32, files.items.len));
        try result.appendSlice(&len);
        for (files.items) |file| {
            len = @bitCast([4]u8, @intCast(u32, file.name.len));
            try result.appendSlice(&len);
            try result.appendSlice(file.name);
            len = @bitCast([4]u8, @intCast(u32, file.contents.len));
            try result.appendSlice(&len);
            try result.appendSlice(file.contents);
        }
        return result;
    }
};

pub fn toStr() !std.ArrayList(u8) {
    return try root.toStr();
}

pub fn write() !void {
    if (rootOut) |output| {
        var file = try std.fs.cwd().createFile(output, .{});

        defer file.close();

        try root.write(file);
    }
}

pub fn deinit() void {
    root.deinit();

    if (rootOut) |toFree| {
        allocator.alloc.free(toFree);
    }
    rootOut = null;
}
