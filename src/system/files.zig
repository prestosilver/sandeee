const std = @import("std");
const options = @import("options");
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

    pub fn size(self: *const File) usize {
        if (self.pseudoRead != null) return 0;
        return self.contents.len;
    }

    pub fn write(self: *File, contents: []const u8, vmInstance: ?*vm.VM) !void {
        if (self.pseudoWrite != null) {
            return self.pseudoWrite.?(contents, vmInstance);
        } else {
            self.contents = try allocator.alloc.realloc(self.contents, contents.len);
            std.mem.copy(u8, self.contents, contents);
        }
    }

    pub fn read(self: *const File, vmInstance: ?*vm.VM) ![]const u8 {
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

pub const Folder = struct {
    name: []const u8,
    subfolders: std.ArrayList(*Folder),
    contents: std.ArrayList(*File),
    parent: *Folder,
    protected: bool = false,

    pub fn loadDisk(file: std.fs.File) !void {
        if (try file.getEndPos() < 4) return error.BadFile;

        const lenbuffer: []u8 = try allocator.alloc.alloc(u8, 4);
        defer allocator.alloc.free(lenbuffer);
        _ = try file.read(lenbuffer);
        const folderCount = std.mem.readIntBig(u32, &lenbuffer[0..4].*);
        for (0..folderCount) |_| {
            _ = try file.read(lenbuffer);
            const namesize = std.mem.readIntBig(u32, &lenbuffer[0..4].*);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try root.newFolder(namebuffer);
        }

        _ = try file.read(lenbuffer);
        const fileCount = std.mem.readIntBig(u32, &lenbuffer[0..4].*);
        for (0..fileCount) |_| {
            _ = try file.read(lenbuffer);
            const namesize = std.mem.readIntBig(u32, &lenbuffer[0..4].*);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try file.read(lenbuffer);
            const contsize = std.mem.readIntBig(u32, &lenbuffer[0..4].*);
            const contbuffer: []u8 = try allocator.alloc.alloc(u8, contsize);
            defer allocator.alloc.free(contbuffer);
            _ = try file.read(contbuffer);
            try root.newFile(namebuffer);
            try root.writeFile(namebuffer, contbuffer, null);
        }
    }

    pub fn setupDisk(diskName: []const u8, settings: []const u8) !void {
        root = try allocator.alloc.create(Folder);
        defer root.deinit();

        root.* = .{
            .protected = false,
            .name = try allocator.alloc.dupe(u8, ROOT_NAME),
            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
            .contents = std.ArrayList(*File).init(allocator.alloc),
            .parent = root,
        };

        const d = std.fs.cwd();

        const recovery = try d.openFile("content/recovery.eee", .{});
        defer recovery.close();
        try loadDisk(recovery);
        const conf = try root.getFile("/conf/system.cfg");
        const conts = try conf.read(null);

        const settingsOut = try std.mem.concat(allocator.alloc, u8, &.{ conts, "\n", settings });

        try conf.write(settingsOut, null);

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskName});
        defer allocator.alloc.free(out);

        const file = try std.fs.cwd().createFile(out, .{});

        defer file.close();

        root.fixFolders();

        try root.write(file);
    }

    pub fn recoverDisk(diskName: []const u8, overrideSettings: bool) !void {
        root = try allocator.alloc.create(Folder);
        defer root.deinit();

        root.* = .{
            .protected = false,
            .name = try allocator.alloc.dupe(u8, ROOT_NAME),
            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
            .contents = std.ArrayList(*File).init(allocator.alloc),
            .parent = root,
        };

        const d = std.fs.cwd();

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskName});
        defer allocator.alloc.free(out);

        {
            const outFile = try d.openFile(out, .{});
            defer outFile.close();

            const recovery = try d.openFile("content/recovery.eee", .{});
            defer recovery.close();
            try loadDisk(outFile);
            if (!overrideSettings) {
                const settingsFile = try root.getFile("/conf/system.cfg");

                const settings = try settingsFile.read(null);

                try loadDisk(recovery);

                const newSettingsFile = try root.getFile("/conf/system.cfg");
                try newSettingsFile.write(settings, null);
            } else {
                try loadDisk(recovery);
            }
        }

        const file = try std.fs.cwd().createFile(out, .{});
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

            const d = std.fs.cwd();

            rootOut = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskPath});

            const user = (try d.openDir("disks", .{})).openFile(diskPath, .{}) catch null;
            if (user) |userdisk| {
                defer userdisk.close();
                try loadDisk(userdisk);
            }

            root.fixFolders();

            if (root.getFolder("/prof") catch null) |folder| {
                home = folder;
            } else return error.NoProfFolder;

            if (root.getFolder("/exec") catch null) |folder| {
                exec = folder;
            } else return error.NoExecFolder;

            return;
        }
    }

    pub fn write(self: *Folder, writer: std.fs.File) !void {
        var folders = std.ArrayList(*const Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFolders(&folders);

        var len = [4]u8{ 0, 0, 0, 0 };

        std.mem.writeIntBig(u32, &len, @as(u32, @intCast(folders.items.len)));
        _ = try writer.write(&len);
        for (folders.items) |folder| {
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(folder.name.len)));
            _ = try writer.write(&len);
            _ = try writer.write(folder.name);
        }

        var files = std.ArrayList(*const File).init(allocator.alloc);
        defer files.deinit();
        try self.getFiles(&files);

        std.mem.writeIntBig(u32, &len, @as(u32, @intCast(files.items.len)));
        _ = try writer.write(&len);
        for (files.items) |file| {
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(file.name.len)));
            _ = try writer.write(&len);
            _ = try writer.write(file.name);
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(file.contents.len)));
            _ = try writer.write(&len);
            _ = try writer.write(file.contents);
        }
    }

    pub fn getFolders(self: *const Folder, folders: *std.ArrayList(*const Folder)) !void {
        if (self.protected) return;

        try folders.append(self);

        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFolders(folders);
        }
    }

    pub fn getFiles(self: *const Folder, files: *std.ArrayList(*const File)) !void {
        if (self.protected) return;

        try files.appendSlice(self.contents.items);

        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFiles(files);
        }
    }

    fn sortFiles(_: bool, a: *File, b: *File) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }

    fn sortFolders(_: bool, a: *Folder, b: *Folder) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }

    fn fixFolders(self: *Folder) void {
        std.sort.insertion(*Folder, self.subfolders.items, true, sortFolders);
        std.sort.insertion(*File, self.contents.items, true, sortFiles);
        for (self.subfolders.items, 0..) |_, idx| {
            self.subfolders.items[idx].parent = self;
            self.subfolders.items[idx].fixFolders();
        }
        for (self.contents.items, 0..) |_, idx| {
            self.contents.items[idx].parent = self;
        }
    }

    pub fn newFile(self: *Folder, name: []const u8) !void {
        if (self.protected) return error.FolderProtected;

        const first = std.mem.indexOf(u8, name, "/");

        if (first) |index| {
            const file = name[0..index];

            if (std.mem.eql(u8, file, "..")) return self.parent.newFile(name[index + 1 ..]);
            if (std.mem.eql(u8, file, ".")) return self.newFile(name[index + 1 ..]);
            if (std.mem.eql(u8, file, "")) return self.newFile(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, file, "/" });
            defer allocator.alloc.free(fullname);

            for (self.subfolders.items) |folder| {
                if (std.mem.eql(u8, folder.name, fullname)) {
                    return folder.newFile(name[index + 1 ..]);
                }
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        for (self.contents.items) |subfile| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return error.FileExists;
            }
        }

        const cont = try allocator.alloc.alloc(u8, 0);

        const adds = try allocator.alloc.create(File);
        adds.* = .{
            .name = fullname,
            .contents = cont,
            .parent = self,
        };
        try self.contents.append(adds);

        self.fixFolders();
    }

    pub fn newFolder(self: *Folder, name: []const u8) anyerror!void {
        if (self.protected) return error.FolderProtected;
        if (name.len == 0) return;

        if (std.mem.endsWith(u8, name, "/")) return self.newFolder(name[0 .. name.len - 1]);

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return self.parent.newFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, ".")) return self.newFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.newFolder(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            for (self.subfolders.items) |subfolder| {
                if (std.mem.eql(u8, subfolder.name, fullname)) {
                    return subfolder.newFolder(name[index + 1 ..]);
                }
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name });
        for (self.subfolders.items) |subfolder| {
            if (std.mem.eql(u8, subfolder.name, fullname)) {
                allocator.alloc.free(fullname);
                return;
            }
        }

        const folder = try allocator.alloc.create(Folder);
        folder.* = .{
            .parent = self,
            .name = fullname,
            .contents = std.ArrayList(*File).init(allocator.alloc),
            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
        };
        try self.subfolders.append(folder);

        self.fixFolders();
    }

    pub fn writeFile(self: *Folder, name: []const u8, contents: []const u8, vmInstance: ?*vm.VM) !void {
        const file = try self.getFile(name);

        return file.write(contents, vmInstance);
    }

    pub fn removeFile(self: *Folder, name: []const u8) !void {
        if (self.protected) return error.FolderProtected;
        if (name.len == 0) return;

        if (std.mem.endsWith(u8, name, "/")) return self.newFolder(name[0 .. name.len - 1]);

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return self.parent.removeFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, ".")) return self.removeFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.removeFile(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            for (self.subfolders.items) |subfolder| {
                if (std.mem.eql(u8, subfolder.name, fullname)) {
                    return subfolder.removeFile(name[index + 1 ..]);
                }
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        defer allocator.alloc.free(fullname);
        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                _ = self.contents.orderedRemove(idx);
                return;
            }
        }
        return error.FileNotFound;
    }

    pub fn getFile(self: *Folder, name: []const u8) !*File {
        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return self.parent.getFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, ".")) return self.getFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.getFile(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            for (self.subfolders.items) |subfolder| {
                if (std.mem.eql(u8, subfolder.name, fullname)) {
                    return subfolder.getFile(name[index + 1 ..]);
                }
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        defer allocator.alloc.free(fullname);

        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                return self.contents.items[idx];
            }
        }

        return error.FileNotFound;
    }

    pub fn getFolder(self: *Folder, name: []const u8) !*Folder {
        if (std.mem.eql(u8, name, "..")) return self.parent;
        if (std.mem.eql(u8, name, "")) return self;

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return self.parent.getFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, ".")) return self.getFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.getFolder(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            for (self.subfolders.items) |subfolder| {
                if (std.mem.eql(u8, subfolder.name, fullname)) {
                    return subfolder.getFolder(name[index + 1 ..]);
                }
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name });
        defer allocator.alloc.free(fullname);
        for (self.subfolders.items, 0..) |subfolder, idx| {
            if (std.ascii.eqlIgnoreCase(subfolder.name, fullname)) {
                return self.subfolders.items[idx];
            }
        }

        return error.FolderNotFound;
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

        var folders = std.ArrayList(*const Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFolders(&folders);

        var len = [4]u8{ 0, 0, 0, 0 };

        std.mem.writeIntBig(u32, &len, @as(u32, @intCast(folders.items.len)));
        try result.appendSlice(&len);
        for (folders.items) |folder| {
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(folder.name.len)));
            try result.appendSlice(&len);
            try result.appendSlice(folder.name);
        }

        var files = std.ArrayList(*const File).init(allocator.alloc);
        defer files.deinit();
        try self.getFiles(&files);

        std.mem.writeIntBig(u32, &len, @as(u32, @intCast(files.items.len)));
        try result.appendSlice(&len);
        for (files.items) |file| {
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(file.name.len)));
            try result.appendSlice(&len);
            try result.appendSlice(file.name);
            std.mem.writeIntBig(u32, &len, @as(u32, @intCast(file.contents.len)));
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
    if (options.IsDemo) return;

    if (rootOut) |output| {
        const file = try std.fs.cwd().createFile(output, .{});

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
