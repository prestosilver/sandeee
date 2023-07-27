const std = @import("std");
const options = @import("options");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const fake = @import("pseudo/all.zig");
const vm = @import("vm.zig");
const config = @import("config.zig");

pub var root: *Folder = undefined;
pub var home: *Folder = undefined;
pub var exec: *Folder = undefined;
pub var settingsManager: *config.SettingManager = undefined;

var rootOut: ?[]const u8 = null;

pub const ROOT_NAME = "/";

pub fn getExtrPath() []const u8 {
    return settingsManager.get("extr_path") orelse "";
}

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

    pub fn copyTo(self: *File, target: *Folder) !void {
        if (self.parent.protected) return error.FolderProtected;
        if (target.protected) return error.FolderProtected;

        const lastIdx = std.mem.lastIndexOf(u8, self.name, "/") orelse return error.UnknownError;
        const name = self.name[lastIdx + 1 ..];

        const clone = try allocator.alloc.create(File);
        clone.* = .{
            .parent = target,
            .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ target.name, name }),
            .contents = try allocator.alloc.dupe(u8, self.contents),
        };

        try target.contents.append(clone);

        root.fixFolders();
    }
};

pub const Folder = struct {
    name: []const u8,
    subfolders: std.ArrayList(*Folder),
    contents: std.ArrayList(*File),
    parent: *Folder,
    protected: bool = false,
    ext: ?struct {
        dir: std.fs.Dir,
        filesVisited: bool = false,
        foldersVisited: bool = false,
    } = null,

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
        defer allocator.alloc.free(settingsOut);

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

    pub fn setupExtr() !void {
        const path = getExtrPath();
        if (!std.fs.path.isAbsolute(path)) return;

        if (std.fs.openDirAbsolute(path, .{}) catch null) |extr_dir| {
            const extr = try allocator.alloc.create(Folder);
            extr.* = .{
                .ext = .{
                    .dir = extr_dir,
                },
                .protected = true,
                .parent = root,
                .name = try allocator.alloc.dupe(u8, "/extr/"),
                .contents = std.ArrayList(*File).init(allocator.alloc),
                .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
            };

            try root.subfolders.append(extr);
        }
    }

    pub fn write(self: *Folder, writer: std.fs.File) !void {
        var folders = std.ArrayList(*const Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFoldersRec(&folders);

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
        try self.getFilesRec(&files);

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

    pub fn getFiles(self: *Folder) ![]*File {
        if (self.ext) |extPath| {
            if (extPath.filesVisited) {
                return try allocator.alloc.dupe(*File, self.contents.items);
            }

            const iterDir = try extPath.dir.openIterableDir(".", .{
                .access_sub_paths = false,
            });

            var iter = iterDir.iterate();

            while (iter.next() catch null) |file| {
                const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, file.name });
                defer allocator.alloc.free(fullname);

                switch (file.kind) {
                    .file => {
                        const fileReader = try extPath.dir.openFile(file.name, .{});
                        defer fileReader.close();

                        const subFile = try allocator.alloc.create(File);
                        subFile.* = .{
                            .parent = self,
                            .contents = try fileReader.reader().readAllAlloc(allocator.alloc, std.math.maxInt(usize)),
                            .name = try allocator.alloc.dupe(u8, fullname),
                        };

                        try self.contents.append(subFile);
                    },
                    else => {},
                }
            }

            self.ext.?.filesVisited = true;
        }

        return try allocator.alloc.dupe(*File, self.contents.items);
    }

    pub fn getFolders(self: *Folder) ![]*Folder {
        if (self.ext) |extPath| {
            if (extPath.foldersVisited) {
                return try allocator.alloc.dupe(*Folder, self.subfolders.items);
            }

            const iterDir = try extPath.dir.openIterableDir(".", .{
                .access_sub_paths = false,
            });

            var iter = iterDir.iterate();

            while (iter.next() catch null) |file| {
                const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.name });
                defer allocator.alloc.free(fullname);

                switch (file.kind) {
                    .directory => {
                        const subFolder = try allocator.alloc.create(Folder);
                        subFolder.* = .{
                            .parent = self,
                            .ext = .{
                                .dir = try extPath.dir.openDir(file.name, .{}),
                            },
                            .name = try allocator.alloc.dupe(u8, fullname),
                            .contents = std.ArrayList(*File).init(allocator.alloc),
                            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                        };

                        try self.subfolders.append(subFolder);
                    },
                    else => {},
                }
            }

            self.ext.?.foldersVisited = true;
        }

        return try allocator.alloc.dupe(*Folder, self.subfolders.items);
    }

    pub fn getFoldersRec(self: *const Folder, folders: *std.ArrayList(*const Folder)) !void {
        if (self.protected) return;
        if (self.ext != null) return;

        try folders.append(self);

        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFoldersRec(folders);
        }
    }

    pub fn getFilesRec(self: *const Folder, files: *std.ArrayList(*const File)) !void {
        if (self.protected) return;
        if (self.ext != null) return;

        try files.appendSlice(self.contents.items);

        for (self.subfolders.items, 0..) |_, idx| {
            try self.subfolders.items[idx].getFilesRec(files);
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
        const last = std.mem.lastIndexOf(u8, name, "/");

        const folder = if (last) |li| try self.getFolder(name[0..li]) else self;

        const fullname = if (last) |li|
            try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ folder.name, name[li + 1 ..] })
        else
            try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ folder.name, name });

        for (folder.contents.items) |subfile| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return;
            }
        }

        const cont = try allocator.alloc.alloc(u8, 0);

        const adds = try allocator.alloc.create(File);
        adds.* = .{
            .name = fullname,
            .contents = cont,
            .parent = folder,
        };
        try folder.contents.append(adds);

        folder.fixFolders();
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
        if (name.len == 0) return error.InvalidName;

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

    pub fn removeFolder(self: *Folder, name: []const u8) !void {
        const folder = try self.getFolder(name);

        if (folder.subfolders.items.len != 0 or
            folder.contents.items.len != 0)
            return error.FolderNotEmpty;

        for (folder.parent.subfolders.items, 0..) |subfolder, idx| {
            if (std.mem.eql(u8, subfolder.name, folder.name)) {
                _ = folder.parent.subfolders.orderedRemove(idx);
                return;
            }
        }
        return error.FolderNotFound;
    }

    pub fn getFile(self: *Folder, name: []const u8) !*File {
        if (name.len == 0) return error.InvalidName;

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

        if (self.ext) |osFolder| {
            for (self.contents.items, 0..) |subfile, idx| {
                if (std.mem.eql(u8, subfile.name, fullname)) {
                    return self.contents.items[idx];
                }
            }

            if (osFolder.dir.openFile(name, .{}) catch null) |osFile| {
                defer osFile.close();
                const file = try allocator.alloc.create(File);
                file.* = .{
                    .parent = self,
                    .contents = try osFile.reader().readAllAlloc(allocator.alloc, std.math.maxInt(usize)),
                    .name = try allocator.alloc.dupe(u8, fullname),
                };

                try self.contents.append(file);

                return file;
            }

            return error.FileNotFound;
        }

        for (self.contents.items, 0..) |subfile, idx| {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                return self.contents.items[idx];
            }
        }

        return error.FileNotFound;
    }

    pub fn getFolder(self: *Folder, name: []const u8) !*Folder {
        if (std.mem.eql(u8, name, "..")) return self.parent;
        if (name.len == 0) return self;

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

            if (self.ext) |osFolder| {
                if (osFolder.dir.openDir(name[index + 1 ..], .{}) catch null) |osSubfolder| {
                    const tmpFolder = try allocator.alloc.create(Folder);
                    tmpFolder.* = .{
                        .name = try allocator.alloc.dupe(u8, fullname),
                        .parent = self,
                        .ext = .{
                            .dir = osSubfolder,
                        },
                        .protected = true,
                        .contents = std.ArrayList(*File).init(allocator.alloc),
                        .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                    };

                    try self.subfolders.append(tmpFolder);

                    return tmpFolder.getFolder(name[index + 1 ..]);
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

        if (self.ext) |osFolder| {
            if (osFolder.dir.openDir(name, .{}) catch null) |osSubfolder| {
                const folder = try allocator.alloc.create(Folder);
                folder.* = .{
                    .name = try allocator.alloc.dupe(u8, fullname),
                    .parent = self,
                    .ext = .{
                        .dir = osSubfolder,
                    },
                    .protected = true,
                    .contents = std.ArrayList(*File).init(allocator.alloc),
                    .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                };

                try self.subfolders.append(folder);

                return folder;
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

        if (self.ext) |*extPath| {
            extPath.dir.close();
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
        try self.getFoldersRec(&folders);

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
        try self.getFilesRec(&files);

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
