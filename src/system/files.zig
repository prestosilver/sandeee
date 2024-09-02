const std = @import("std");
const options = @import("options");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");
const fake = @import("pseudo/all.zig");
const vm = @import("vm.zig");
const config = @import("config.zig");
const telem = @import("telem.zig");

pub var root: *Folder = undefined;
pub var home: *Folder = undefined;
pub var exec: *Folder = undefined;

pub var root_out: ?[]const u8 = null;

pub const ROOT_NAME = "/";

pub inline fn getExtrPath() []const u8 {
    return config.SettingManager.instance.get("extr_path") orelse "";
}

pub const FileError = error{
    InvalidPsuedoData,

    InvalidFileName,
    InvalidFolderName,

    FolderProtected,

    FolderNotFound,
    FileNotFound,

    OutOfMemory,
} || std.fs.File.SeekError || std.fs.File.ReadError || std.fs.File.WriteError || error{StreamTooLong};

pub const DiskError = error{
    BadDiskSize,

    OutOfMemory,

    AccessDenied,
    SystemResources,
    Unexpected,
    Unseekable,
} || FileError || std.fs.File.ReadError;

pub const File = struct {
    const FileKind = enum {
        Os,
        Disk,
        Pseudo,
    };

    const FileData = union(FileKind) {
        Os: std.fs.File,
        Disk: []u8,
        Pseudo: struct {
            pseudo_write: *const fn ([]const u8, ?*vm.VM) FileError!void,
            pseudo_read: *const fn (?*vm.VM) FileError![]const u8,
        },
    };

    parent: *Folder,
    name: []const u8,

    data: FileData,

    pub fn size(self: *const File) FileError!usize {
        switch (self.data) {
            .Os => |os_file| {
                const stat = try os_file.stat();
                return stat.size;
            },
            .Disk => |disk_file| {
                return disk_file.len;
            },
            .Pseudo => {
                return 0;
            },
        }
    }

    pub inline fn write(self: *File, contents: []const u8, vm_instance: ?*vm.VM) FileError!void {
        switch (self.data) {
            .Os => |os_file| {
                try os_file.writeAll(contents);
            },
            .Disk => |*disk_file| {
                disk_file.* = try allocator.alloc.realloc(disk_file.*, contents.len);
                @memcpy(disk_file.*, contents);
            },
            .Pseudo => |pseudo_file| {
                try pseudo_file.pseudo_write(contents, vm_instance);
            },
        }
    }

    pub inline fn read(self: *const File, vm_instance: ?*vm.VM) FileError![]const u8 {
        switch (self.data) {
            .Os => |os_file| {
                const stat = try os_file.stat();
                const result = try allocator.alloc.alloc(u8, stat.size);

                try os_file.seekTo(0);
                _ = try os_file.readAll(result);

                return result;
            },
            .Disk => |*disk_file| {
                return disk_file.*;
            },
            .Pseudo => |pseudo_file| {
                return try pseudo_file.pseudo_read(vm_instance);
            },
        }
    }

    pub fn deinit(self: *File) void {
        allocator.alloc.free(self.name);
        switch (self.data) {
            .Os => |os_file| {
                os_file.close();
            },
            .Disk => |disk_file| {
                allocator.alloc.free(disk_file);
            },
            else => {},
        }

        allocator.alloc.destroy(self);
    }

    pub fn copyTo(self: *File, target: *Folder) FileError!void {
        if (self.parent.protected) return error.FolderProtected;
        if (target.protected) return error.FolderProtected;
        if (self.data != .Disk) return error.InvalidFileName;

        const last_idx = std.mem.lastIndexOf(u8, self.name, "/") orelse return error.InvalidFileName;
        const name = self.name[last_idx + 1 ..];

        const clone = try allocator.alloc.create(File);
        clone.* = .{
            .parent = target,
            .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ target.name, name }),
            .data = .{
                .Disk = try allocator.alloc.dupe(u8, self.data.Disk),
            },
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
        files_visited: bool = false,
        folders_visited: bool = false,
    } = null,

    pub fn loadDisk(file: std.fs.File) DiskError!void {
        if (try file.getEndPos() < 4) return error.BadDiskSize;

        var lenbuffer = [_]u8{0} ** 4;
        _ = try file.read(&lenbuffer);
        const folder_count = std.mem.readInt(u32, &lenbuffer, .big);
        for (0..folder_count) |_| {
            _ = try file.read(&lenbuffer);
            const namesize = std.mem.readInt(u32, &lenbuffer, .big);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try root.newFolder(namebuffer);
        }

        _ = try file.read(&lenbuffer);
        const file_count = std.mem.readInt(u32, &lenbuffer, .big);
        for (0..file_count) |_| {
            _ = try file.read(&lenbuffer);
            const namesize = std.mem.readInt(u32, &lenbuffer, .big);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            _ = try file.read(namebuffer);
            _ = try file.read(&lenbuffer);
            const contsize = std.mem.readInt(u32, &lenbuffer, .big);
            const contbuffer: []u8 = try allocator.alloc.alloc(u8, contsize);
            defer allocator.alloc.free(contbuffer);
            _ = try file.read(contbuffer);
            try root.newFile(namebuffer);
            try root.writeFile(namebuffer, contbuffer, null);
        }
    }

    pub fn setupDisk(disk_name: []const u8, settings: []const u8) !void {
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

        const settings_out = try std.mem.concat(allocator.alloc, u8, &.{ conts, "\n", settings });
        defer allocator.alloc.free(settings_out);

        try conf.write(settings_out, null);

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{disk_name});
        defer allocator.alloc.free(out);

        const file = try std.fs.cwd().createFile(out, .{});

        defer file.close();

        root.fixFolders();

        try root.write(file);
    }

    pub fn recoverDisk(disk_name: []const u8, override_settings: bool) !void {
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

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{disk_name});
        defer allocator.alloc.free(out);

        {
            const out_file = try d.openFile(out, .{});
            defer out_file.close();

            const recovery = try d.openFile("content/recovery.eee", .{});
            defer recovery.close();
            try loadDisk(out_file);
            if (!override_settings) {
                const settings_file = try root.getFile("/conf/system.cfg");

                const settings = try allocator.alloc.dupe(u8, try settings_file.read(null));
                defer allocator.alloc.free(settings);

                try loadDisk(recovery);

                const new_settings_file = try root.getFile("/conf/system.cfg");
                try new_settings_file.write(settings, null);
            } else {
                try loadDisk(recovery);
            }
        }

        // update telem version
        try telem.Telem.load();

        telem.Telem.instance.version = .{
            .major = options.SandEEEVersion.major,
            .minor = options.SandEEEVersion.minor,
            .patch = options.SandEEEVersion.patch,
        };

        try telem.Telem.save();

        const file = try std.fs.cwd().createFile(out, .{});
        defer file.close();

        root.fixFolders();

        try root.write(file);
    }

    pub fn init(input_disk_path: ?[]const u8) !void {
        if (root_out) |out| {
            allocator.alloc.free(out);
            root_out = null;
        }

        if (input_disk_path) |diskPath| {
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

            const user_disk = try (try d.openDir("disks", .{})).openFile(diskPath, .{});
            defer user_disk.close();
            try loadDisk(user_disk);

            root_out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskPath});

            root.fixFolders();

            if (root.getFolder("/prof") catch null) |folder| {
                home = folder;
            } else return error.NoProfFolder;

            if (root.getFolder("/exec") catch null) |folder| {
                exec = folder;
            } else return error.NoExecFolder;
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

        std.mem.writeInt(u32, &len, @as(u32, @intCast(folders.items.len)), .big);
        _ = try writer.write(&len);
        for (folders.items) |folder| {
            std.mem.writeInt(u32, &len, @as(u32, @intCast(folder.name.len)), .big);
            _ = try writer.write(&len);
            _ = try writer.write(folder.name);
        }

        var files = std.ArrayList(*const File).init(allocator.alloc);
        defer files.deinit();
        try self.getFilesRec(&files);

        std.mem.writeInt(u32, &len, @as(u32, @intCast(files.items.len)), .big);
        _ = try writer.write(&len);
        for (files.items) |file| {
            if (file.data != .Disk) continue;

            std.mem.writeInt(u32, &len, @as(u32, @intCast(file.name.len)), .big);
            _ = try writer.write(&len);
            _ = try writer.write(file.name);
            std.mem.writeInt(u32, &len, @as(u32, @intCast(file.data.Disk.len)), .big);
            _ = try writer.write(&len);
            _ = try writer.write(file.data.Disk);
        }
    }

    pub fn getFiles(self: *Folder) ![]*File {
        if (self.ext) |*ext_path| {
            if (ext_path.files_visited) {
                return try allocator.alloc.dupe(*File, self.contents.items);
            }

            const dir = try ext_path.dir.openDir(".", .{
                .access_sub_paths = false,
                .iterate = true,
            });

            var iter = dir.iterate();

            while (iter.next() catch null) |file| {
                const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, file.name });
                defer allocator.alloc.free(fullname);

                switch (file.kind) {
                    .file => {
                        const file_reader = try ext_path.dir.openFile(file.name, .{});
                        defer file_reader.close();

                        const sub_file = try allocator.alloc.create(File);
                        sub_file.* = .{
                            .parent = self,
                            .data = .{
                                .Disk = try file_reader.reader().readAllAlloc(allocator.alloc, std.math.maxInt(usize)),
                            },
                            .name = try allocator.alloc.dupe(u8, fullname),
                        };

                        try self.contents.append(sub_file);
                    },
                    else => {},
                }
            }

            ext_path.files_visited = true;
        }

        return try allocator.alloc.dupe(*File, self.contents.items);
    }

    pub fn getFolders(self: *Folder) ![]*Folder {
        if (self.ext) |ext_path| {
            if (ext_path.folders_visited) {
                return try allocator.alloc.dupe(*Folder, self.subfolders.items);
            }

            const dir = try ext_path.dir.openDir(".", .{
                .access_sub_paths = false,
                .iterate = true,
            });

            var iter = dir.iterate();

            while (iter.next() catch null) |file| {
                const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.name });
                defer allocator.alloc.free(fullname);

                switch (file.kind) {
                    .directory => {
                        const sub_folder = try allocator.alloc.create(Folder);
                        sub_folder.* = .{
                            .parent = self,
                            .ext = .{
                                .dir = try ext_path.dir.openDir(file.name, .{}),
                            },
                            .name = try allocator.alloc.dupe(u8, fullname),
                            .contents = std.ArrayList(*File).init(allocator.alloc),
                            .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                        };

                        try self.subfolders.append(sub_folder);
                    },
                    else => {},
                }
            }

            self.ext.?.folders_visited = true;
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

    pub fn newFile(self: *Folder, name: []const u8) FileError!void {
        if (std.mem.containsAtLeast(u8, name, 1, " ")) return error.InvalidFileName;

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

        const adds = try allocator.alloc.create(File);
        adds.* = .{
            .name = fullname,
            .parent = folder,
            .data = .{
                .Disk = &.{},
            },
        };
        try folder.contents.append(adds);

        folder.fixFolders();
    }

    pub fn newFolder(self: *Folder, name: []const u8) FileError!void {
        if (std.mem.containsAtLeast(u8, name, 1, " ")) return error.InvalidFolderName;
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
                const file = self.contents.orderedRemove(idx);
                file.deinit();

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

    pub fn getFile(self: *Folder, name: []const u8) FileError!*File {
        if (name.len == 0) return error.InvalidFileName;

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

        if (self.ext) |os_folder| {
            for (self.contents.items, 0..) |subfile, idx| {
                if (std.mem.eql(u8, subfile.name, fullname)) {
                    return self.contents.items[idx];
                }
            }

            if (os_folder.dir.openFile(name, .{}) catch null) |os_file| {
                const file = try allocator.alloc.create(File);
                file.* = .{
                    .parent = self,
                    .name = try allocator.alloc.dupe(u8, fullname),

                    .data = .{
                        .Os = os_file,
                    },
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

            if (self.ext) |os_folder| {
                if (os_folder.dir.openDir(name[index + 1 ..], .{}) catch null) |os_sub_folder| {
                    const tmp_folder = try allocator.alloc.create(Folder);
                    tmp_folder.* = .{
                        .name = try allocator.alloc.dupe(u8, fullname),
                        .parent = self,
                        .ext = .{
                            .dir = os_sub_folder,
                        },
                        .protected = true,
                        .contents = std.ArrayList(*File).init(allocator.alloc),
                        .subfolders = std.ArrayList(*Folder).init(allocator.alloc),
                    };

                    try self.subfolders.append(tmp_folder);

                    return tmp_folder.getFolder(name[index + 1 ..]);
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

        if (self.ext) |os_folder| {
            if (os_folder.dir.openDir(name, .{}) catch null) |os_sub_folder| {
                const folder = try allocator.alloc.create(Folder);
                folder.* = .{
                    .name = try allocator.alloc.dupe(u8, fullname),
                    .parent = self,
                    .ext = .{
                        .dir = os_sub_folder,
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

        if (self.ext) |*ext_path| {
            ext_path.dir.close();
        }

        self.subfolders.deinit();
        self.contents.deinit();

        allocator.alloc.free(self.name);
        allocator.alloc.destroy(self);

        if (root_out) |out| {
            allocator.alloc.free(out);
            root_out = null;
        }
    }

    pub fn toStr(self: *Folder) !std.ArrayList(u8) {
        var result = std.ArrayList(u8).init(allocator.alloc);

        var folders = std.ArrayList(*const Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFoldersRec(&folders);

        var len = [4]u8{ 0, 0, 0, 0 };

        std.mem.writeInt(u32, &len, @as(u32, @intCast(folders.items.len)), .big);
        try result.appendSlice(&len);
        for (folders.items) |folder| {
            std.mem.writeInt(u32, &len, @as(u32, @intCast(folder.name.len)), .big);
            try result.appendSlice(&len);
            try result.appendSlice(folder.name);
        }

        var files = std.ArrayList(*const File).init(allocator.alloc);
        defer files.deinit();
        try self.getFilesRec(&files);

        std.mem.writeInt(u32, &len, @as(u32, @intCast(files.items.len)), .big);
        try result.appendSlice(&len);
        for (files.items) |file| {
            if (file.data == .Disk) {
                std.mem.writeInt(u32, &len, @as(u32, @intCast(file.name.len)), .big);
                try result.appendSlice(&len);
                try result.appendSlice(file.name);
                std.mem.writeInt(u32, &len, @as(u32, @intCast(file.data.Disk.len)), .big);
                try result.appendSlice(&len);
                try result.appendSlice(file.data.Disk);
            }
        }
        return result;
    }
};

pub fn toStr() !std.ArrayList(u8) {
    return try root.toStr();
}

pub fn write() void {
    if (options.IsDemo) return;

    if (root_out) |output| {
        const file = std.fs.cwd().createFile(output, .{}) catch {
            @panic("couldnt make save");
        };
        defer file.close();

        root.write(file) catch |err| {
            @panic(std.fmt.allocPrint(allocator.alloc, "failed to save game {}", .{err}) catch "");
        };
    }
}

pub fn deinit() void {
    root.deinit();
}
