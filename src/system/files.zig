const options = @import("options");
const std = @import("std");

const system = @import("mod.zig");

const util = @import("../util/mod.zig");

const allocator = util.allocator;
const storage = util.storage;
const log = util.log;

const Vm = system.Vm;
const config = system.config;
const telem = system.telem;

const fake = @import("pseudo/all.zig");

pub var named_paths: std.EnumArray(NamedPath, ?*Folder) = .initFill(null);

pub const NamedPath = enum {
    root,
    home,
    exec,
};

pub const LinkKind = enum {
    named,
    valid,
};

pub const FolderLink = union(LinkKind) {
    named: NamedPath,
    valid: *Folder,

    pub const root = FolderLink{ .named = .root };
    pub const home = FolderLink{ .named = .home };
    pub const exec = FolderLink{ .named = .exec };
    pub fn link(f: *Folder) FolderLink {
        return .{ .valid = f };
    }

    pub fn resolve(self: FolderLink) !*Folder {
        switch (self) {
            .named => |n| {
                if (named_paths.get(n)) |named|
                    return named
                else
                    return error.FolderNotFound;
            },
            .valid => |v| return v,
        }
    }
};

pub var root_out: ?[]const u8 = null;

// TODO: move to data module, and test other values
pub const ROOT_NAME = "/";

pub inline fn getExtrPath() []const u8 {
    if (@import("builtin").mode != .Debug)
        return "";

    return config.SettingManager.instance.get("extr_path") orelse "";
}

pub const FileError = error{
    InvalidPsuedoData,

    InvalidFileName,
    InvalidFolderName,

    FolderProtected,

    FolderNotFound,
    FileNotFound,

    FolderExists,
    FileExists,

    OutOfMemory,
} || std.fs.File.SeekError || std.fs.File.ReadError || std.fs.File.WriteError || error{StreamTooLong};

pub const DiskError = error{
    BadDiskSize,

    OutOfMemory,

    AccessDenied,
    SystemResources,
    Unexpected,
    Unseekable,
    EndOfStream,
} || std.fs.File.Reader.Error || FileError;

pub const File = struct {
    const FileKind = enum {
        os,
        disk,
        pseudo,
    };

    const PseudoData = struct {
        pub const WriteFn = *const fn ([]const u8, ?*Vm) FileError!void;
        pub const ReadFn = *const fn (?*Vm) FileError![]const u8;

        write: WriteFn,
        read: ReadFn,
    };

    const FileData = union(FileKind) {
        os: std.fs.File,
        disk: []u8,
        pseudo: PseudoData,

        const default = struct {
            pub fn read(_: ?*Vm) FileError![]const u8 {
                return &.{};
            }

            pub fn write(_: []const u8, _: ?*Vm) FileError!void {
                return;
            }
        };

        pub fn initFake(comptime T: type) FileData {
            return .{ .pseudo = .{
                .read = if (@hasDecl(T, "read")) T.read else default.read,
                .write = if (@hasDecl(T, "write")) T.write else default.write,
            } };
        }
    };

    lock: std.Thread.Mutex = .{},
    parent: FolderLink,
    name: []const u8,

    next_sibling: ?*File = null,

    data: FileData,

    pub fn size(self: *const File) FileError!usize {
        switch (self.data) {
            .os => |os_file| {
                const stat = try os_file.stat();
                return stat.size;
            },
            .disk => |disk_file| {
                return disk_file.len;
            },
            .pseudo => {
                return 0;
            },
        }
    }

    pub inline fn write(self: *File, contents: []const u8, vm_instance: ?*Vm) FileError!void {
        self.lock.lock();
        defer self.lock.unlock();

        switch (self.data) {
            .os => |os_file| {
                try os_file.writeAll(contents);
            },
            .disk => |*disk_file| {
                disk_file.* = try allocator.alloc.realloc(disk_file.*, contents.len);
                @memcpy(disk_file.*, contents);
            },
            .pseudo => |pseudo_file| {
                try pseudo_file.write(contents, vm_instance);
            },
        }
    }

    pub inline fn read(self: *File, vm_instance: ?*Vm) FileError![]const u8 {
        self.lock.lock();
        defer self.lock.unlock();

        switch (self.data) {
            .os => |os_file| {
                const stat = try os_file.stat();
                const result = try allocator.alloc.alloc(u8, stat.size);

                try os_file.seekTo(0);
                _ = try os_file.readAll(result);

                return result;
            },
            .disk => |*disk_file| {
                return disk_file.*;
            },
            .pseudo => |pseudo_file| {
                return try pseudo_file.read(vm_instance);
            },
        }
    }

    pub fn deinit(self: *File) void {
        if (self.next_sibling) |sibling|
            sibling.deinit();

        allocator.alloc.free(self.name);
        switch (self.data) {
            .os => |os_file| {
                os_file.close();
            },
            .disk => |disk_file| {
                allocator.alloc.free(disk_file);
            },
            else => {},
        }

        allocator.alloc.destroy(self);
    }

    pub fn copyTo(self: *File, target: *Folder) FileError!void {
        const parent = try self.parent.resolve();
        if (parent.protected) return error.FolderProtected;
        if (target.protected) return error.FolderProtected;
        if (self.data != .disk) return error.InvalidFileName;

        const last_idx = std.mem.lastIndexOf(u8, self.name, "/") orelse return error.InvalidFileName;
        const name = self.name[last_idx + 1 ..];

        const clone = try allocator.alloc.create(File);
        clone.* = .{
            .parent = .link(target),
            .name = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ target.name, name }),
            .data = .{
                .disk = try allocator.alloc.dupe(u8, self.data.disk),
            },
        };

        clone.next_sibling = target.files;
        target.files = clone;
    }

    pub fn copyOver(self: *File, target: *File) FileError!void {
        try target.write(try self.read(null), null);
    }
};

pub const Folder = struct {
    name: []const u8,
    parent: ?FolderLink,

    folders: ?*Folder = null,
    files: ?*File = null,
    next_sibling: ?*Folder = null,
    protected: bool = false,
    ext: ?struct {
        dir: std.fs.Dir,
        files_visited: bool = false,
        folders_visited: bool = false,
    } = null,

    const FolderItemKind = enum { folder, file };
    pub const FolderItem = struct {
        name: []const u8,
        data: union(FolderItemKind) {
            folder: []const FolderItem,
            file: File.FileData,
        },

        pub fn folder(comptime name: []const u8, comptime items: []const FolderItem) FolderItem {
            return FolderItem{
                .name = name,
                .data = .{ .folder = items },
            };
        }

        pub fn file(comptime name: []const u8, comptime data: File.FileData) FolderItem {
            return FolderItem{
                .name = name,
                .data = .{ .file = data },
            };
        }
    };

    pub inline fn fromFolderItemArray(name: []const u8, comptime items: []const FolderItem) !*Folder {
        const root = try allocator.alloc.create(Folder);
        errdefer root.deinit();

        root.* = .{
            .protected = false,
            .name = try allocator.alloc.dupe(u8, name),
            .parent = null,
        };

        inline for (items) |item| {
            switch (item.data) {
                .folder => |subitems| {
                    const fullname = try std.mem.concat(allocator.alloc, u8, &.{ name, item.name, "/" });
                    defer allocator.alloc.free(fullname);

                    const new = try fromFolderItemArray(fullname, subitems);
                    new.next_sibling = root.folders;
                    new.parent = .link(root);
                    root.folders = new;
                },
                .file => |subfile| {
                    const fullname = try std.mem.concat(allocator.alloc, u8, &.{ name, item.name });

                    const new = try allocator.alloc.create(File);
                    new.* = .{
                        .name = fullname,
                        .next_sibling = root.files,
                        .data = subfile,
                        .parent = .link(root),
                    };
                    root.files = new;
                },
            }
        }

        return root;
    }

    pub fn loadDisk(file: std.fs.File) DiskError!*Folder {
        if (try file.getEndPos() < 4) return error.BadDiskSize;
        const reader = file.reader();

        const root = try allocator.alloc.create(Folder);
        errdefer root.deinit();

        root.* = .{
            .protected = false,
            .name = try allocator.alloc.dupe(u8, ROOT_NAME),
            .parent = null,
        };

        const folder_count = try reader.readInt(u32, .big);
        for (0..folder_count) |_| {
            const namesize = try reader.readInt(u32, .big);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            if (try reader.read(namebuffer) != namesize) return error.EndOfStream;
            root.newFolder(namebuffer) catch |e| {
                switch (e) {
                    error.FolderExists => {
                        log.warn("folder exists on load {s}", .{namebuffer});
                    },
                    else => return e,
                }
            };
        }

        const file_count = try reader.readInt(u32, .big);
        for (0..file_count) |_| {
            const namesize = try reader.readInt(u32, .big);
            const namebuffer: []u8 = try allocator.alloc.alloc(u8, namesize);
            defer allocator.alloc.free(namebuffer);
            if (try reader.read(namebuffer) != namesize) return error.EndOfStream;
            try root.newFile(namebuffer);

            const contsize = try reader.readInt(u32, .big);
            const contbuffer: []u8 = try allocator.alloc.alloc(u8, contsize);
            defer allocator.alloc.free(contbuffer);
            if (try reader.read(contbuffer) != contsize) return error.EndOfStream;

            try root.writeFile(namebuffer, contbuffer, null);
        }

        return root;
    }

    pub fn setupDisk(disk_name: []const u8, settings: []const u8) !void {
        const d = std.fs.cwd();

        const recovery = try d.openFile("content/recovery.eee", .{});
        defer recovery.close();

        var root = try loadDisk(recovery);
        defer root.deinit();
        named_paths.set(.root, root);
        defer named_paths.set(.root, null);

        const conf = try root.getFile("/conf/system.cfg");
        const conts = try conf.read(null);

        const settings_out = try std.mem.concat(allocator.alloc, u8, &.{ conts, "\n", settings });
        defer allocator.alloc.free(settings_out);

        try conf.write(settings_out, null);

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{disk_name});
        defer allocator.alloc.free(out);

        const file = try std.fs.cwd().createFile(out, .{});
        defer file.close();

        try root.write(file);
    }

    pub fn recoverDisk(disk_name: []const u8, override_settings: bool) !void {
        const d = std.fs.cwd();

        const out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{disk_name});
        defer allocator.alloc.free(out);

        const out_file = try d.openFile(out, .{ .mode = .read_write });
        defer out_file.close();

        var root_disk = try loadDisk(out_file);
        defer root_disk.deinit();

        const recovery = try d.openFile("content/recovery.eee", .{});
        defer recovery.close();

        var rec_disk = try loadDisk(recovery);
        defer rec_disk.deinit();

        named_paths.set(.root, root_disk);
        defer named_paths.set(.root, null);

        if (!override_settings) {
            const settings_file = try root_disk.getFile("/conf/system.cfg");
            const settings = try allocator.alloc.dupe(u8, try settings_file.read(null));
            defer allocator.alloc.free(settings);

            var files = std.ArrayList(*File).init(allocator.alloc);
            defer files.deinit();
            try rec_disk.getFilesRec(&files);

            for (files.items) |file| {
                if (file.data != .disk) continue;

                try root_disk.writeFile(file.name, file.data.disk, null);
            }

            const new_settings_file = try root_disk.getFile("/conf/system.cfg");
            try new_settings_file.write(settings, null);
        } else {
            var files = std.ArrayList(*File).init(allocator.alloc);
            defer files.deinit();
            try rec_disk.getFilesRec(&files);

            for (files.items) |file| {
                if (file.data != .disk) continue;

                try root_disk.writeFile(file.name, file.data.disk, null);
            }
        }

        // update telem version
        try telem.Telem.load();

        telem.Telem.instance.version = .{
            .major = options.SandEEEVersion.major,
            .minor = options.SandEEEVersion.minor,
            .patch = options.SandEEEVersion.patch,
        };

        telem.Telem.save() catch |err|
            std.log.err("telem save failed {}", .{err});

        const file = try std.fs.cwd().createFile(out, .{});
        defer file.close();

        try root_disk.write(file);
    }

    pub fn init(input_disk_path: ?[]const u8) !void {
        if (root_out) |out| {
            allocator.alloc.free(out);
            root_out = null;
        }

        if (input_disk_path) |diskPath| {
            const user_disk_out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskPath});
            defer allocator.alloc.free(user_disk_out);

            var user_disk = try std.fs.cwd().openFile(user_disk_out, .{});
            defer user_disk.close();

            var root = try loadDisk(user_disk);
            errdefer root.deinit();
            named_paths.set(.root, root);
            errdefer named_paths.set(.root, null);

            const fake_root: *Folder = try .fromFolderItemArray("/fake/", fake.all);
            fake_root.protected = true;
            fake_root.parent = .root;
            fake_root.next_sibling = root.folders;

            root.folders = fake_root;

            root_out = try std.fmt.allocPrint(allocator.alloc, "disks/{s}", .{diskPath});

            if (root.getFolder("/prof") catch null) |folder| {
                named_paths.set(.home, folder);
            }

            if (root.getFolder("/exec") catch null) |folder| {
                named_paths.set(.exec, folder);
            }
        }
    }

    pub fn setupExtr() !void {
        if (@import("builtin").mode == .Debug) {
            const extr_path = getExtrPath();
            const path = if (std.fs.path.isAbsolute(extr_path))
                std.fs.openDirAbsolute(extr_path, .{}) catch null
            else
                std.fs.cwd().openDir(extr_path, .{}) catch null;

            const root = try FolderLink.resolve(.root);

            if (path) |extr_dir| {
                const extr = try allocator.alloc.create(Folder);
                extr.* = .{
                    .ext = .{
                        .dir = extr_dir,
                    },
                    .protected = true,
                    .parent = .root,
                    .name = try allocator.alloc.dupe(u8, "/extr/"),
                };

                extr.next_sibling = root.folders;
                root.folders = extr;
            } else {
                log.err("failed to load extr path: '{s}'", .{extr_path});
            }
        }
    }

    pub fn write(self: *Folder, file: std.fs.File) !void {
        var folders = std.ArrayList(*const Folder).init(allocator.alloc);
        defer folders.deinit();
        try self.getFoldersRec(&folders);

        const writer = file.writer();

        try writer.writeInt(u32, @as(u32, @intCast(folders.items.len)), .big);
        for (folders.items) |folder| {
            try writer.writeInt(u32, @as(u32, @intCast(folder.name.len)), .big);
            if (folder.name.len != try writer.write(folder.name)) return error.OutOfMemory;
        }

        var files = std.ArrayList(*File).init(allocator.alloc);
        defer files.deinit();
        try self.getFilesRec(&files);

        try writer.writeInt(u32, @intCast(files.items.len), .big);
        for (files.items) |subfile| {
            try writer.writeInt(u32, @intCast(subfile.name.len), .big);
            if (subfile.name.len != try writer.write(subfile.name)) return error.OutOfMemory;

            try writer.writeInt(u32, @intCast(subfile.data.disk.len), .big);
            if (subfile.data.disk.len != try writer.write(subfile.data.disk)) return error.OutOfMemory;
        }
    }

    pub fn getFiles(self: *Folder) !?*File {
        if (self.ext) |*ext_path| {
            if (ext_path.files_visited) {
                return self.files;
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
                            .parent = .link(self),
                            .data = .{
                                .disk = try file_reader.reader().readAllAlloc(allocator.alloc, std.math.maxInt(usize)),
                            },
                            .name = try allocator.alloc.dupe(u8, fullname),
                        };

                        sub_file.next_sibling = self.files;
                        self.files = sub_file;
                    },
                    else => {},
                }
            }

            ext_path.files_visited = true;
        }

        return self.files;
    }

    pub fn getFolders(self: *Folder) !?*Folder {
        if (self.ext) |ext_path| {
            if (ext_path.folders_visited) {
                return self.folders;
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
                            .parent = .link(self),
                            .ext = .{
                                .dir = try ext_path.dir.openDir(file.name, .{}),
                            },
                            .name = try allocator.alloc.dupe(u8, fullname),
                        };

                        sub_folder.next_sibling = self.folders;
                        self.folders = sub_folder;
                    },
                    else => {},
                }
            }

            self.ext.?.folders_visited = true;
        }

        return self.folders;
    }

    pub fn getFoldersRec(self: *const Folder, folders: *std.ArrayList(*const Folder)) !void {
        if (self.ext == null and !self.protected) {
            try folders.append(self);

            if (self.folders) |folder|
                try folder.getFoldersRec(folders);
        }

        if (self.next_sibling) |sibling|
            try sibling.getFoldersRec(folders);
    }

    pub fn getFilesRec(self: *const Folder, files: *std.ArrayList(*File)) !void {
        if (self.ext == null and !self.protected) {
            if (self.protected) return;
            if (self.ext != null) return;

            var file_node = self.files;
            while (file_node) |file| : (file_node = file.next_sibling) {
                if (file.data == .disk)
                    try files.append(file);
            }

            if (self.folders) |folder|
                try folder.getFilesRec(files);
        }

        if (self.next_sibling) |sibling|
            try sibling.getFilesRec(files);
    }

    fn sortFiles(_: bool, a: *File, b: *File) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }

    fn sortFolders(_: bool, a: *Folder, b: *Folder) bool {
        return std.mem.lessThan(u8, a.name, b.name);
    }

    pub fn newFile(self: *Folder, name: []const u8) FileError!void {
        if (std.mem.containsAtLeast(u8, name, 1, " ")) {
            log.err("space in file name '{s}'", .{name});
            return error.InvalidFileName;
        }

        const last = std.mem.lastIndexOf(u8, name, "/");

        const folder = if (last) |li| try self.getFolder(name[0..li]) else self;

        const fullname = if (last) |li|
            try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ folder.name, name[li + 1 ..] })
        else
            try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ folder.name, name });
        errdefer allocator.alloc.free(fullname);

        var file_node = folder.files;
        while (file_node) |subfile| : (file_node = subfile.next_sibling) {
            if (std.mem.eql(u8, subfile.name, fullname))
                return error.FileExists;
        }

        const file = try allocator.alloc.create(File);
        file.* = .{
            .name = fullname,
            .parent = .link(folder),
            .data = .{
                .disk = &.{},
            },
            .next_sibling = folder.files,
        };

        folder.files = file;
    }

    pub fn newFolder(self: *Folder, name: []const u8) FileError!void {
        if (std.mem.containsAtLeast(u8, name, 1, " ")) return error.InvalidFolderName;
        if (self.protected) return error.FolderProtected;
        if (name.len == 0) return;

        if (std.mem.endsWith(u8, name, "/")) return self.newFolder(name[0 .. name.len - 1]);

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return if (self.parent) |p|
                (try p.resolve()).newFolder(name[index + 1 ..])
            else
                error.FolderNotFound;
            if (std.mem.eql(u8, folder, ".")) return self.newFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.newFolder(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            var subfolder_node = self.folders;
            while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
                if (std.mem.eql(u8, subfolder.name, fullname))
                    return subfolder.newFolder(name[index + 1 ..]);
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name });
        errdefer allocator.alloc.free(fullname);

        var subfolder_node = self.folders;
        while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
            if (std.mem.eql(u8, subfolder.name, fullname))
                return error.FolderExists;
        }

        const folder = try allocator.alloc.create(Folder);
        folder.* = .{
            .parent = .link(self),
            .name = fullname,
            .next_sibling = self.folders,
        };

        self.folders = folder;
    }

    pub fn writeFile(self: *Folder, name: []const u8, contents: []const u8, vmInstance: ?*Vm) !void {
        const file = try self.getFile(name);

        return file.write(contents, vmInstance);
    }

    pub fn removeFile(self: *Folder, name: []const u8) !void {
        if (std.mem.containsAtLeast(u8, name, 1, " ")) return error.InvalidFolderName;
        if (self.protected) return error.FolderProtected;
        if (name.len == 0) return;

        if (std.mem.endsWith(u8, name, "/")) return self.removeFile(name[0 .. name.len - 1]);

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return if (self.parent) |p|
                (try p.resolve()).removeFile(name[index + 1 ..])
            else
                error.FolderNotFound;
            if (std.mem.eql(u8, folder, ".")) return self.removeFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.removeFile(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            var subfolder_node = self.folders;
            while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
                if (std.mem.eql(u8, subfolder.name, fullname))
                    return subfolder.removeFile(name[index + 1 ..]);
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        defer allocator.alloc.free(fullname);

        var subfile_node = &self.files;
        while (subfile_node.*) |subfile| : (subfile_node = &subfile.next_sibling) {
            if (std.mem.eql(u8, subfile.name, fullname)) {
                subfile_node.* = subfile.next_sibling;

                subfile.next_sibling = null;
                subfile.deinit();
                return;
            }
        }

        return error.FileNotFound;
    }

    pub fn removeFolder(self: *Folder, name: []const u8) !void {
        const folder = try self.getFolder(name);

        if (folder.folders != null or folder.files != null)
            return error.FolderNotEmpty;

        const parent = try FolderLink.resolve(folder.parent orelse {
            return error.FolderNotFound;
        });

        var subfolder_node = &parent.folders;
        while (subfolder_node.*) |subfolder| : (subfolder_node = &subfolder.next_sibling) {
            if (std.mem.eql(u8, subfolder.name, folder.name)) {
                subfolder_node.* = subfolder.next_sibling;
                subfolder.next_sibling = null;
                subfolder.deinit();
                return;
            }
        }

        return error.FolderNotFound;
    }

    pub fn getFile(self: *Folder, name: []const u8) FileError!*File {
        if (name.len == 0) {
            log.err("empty filename", .{});
            return error.InvalidFileName;
        }

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return if (self.parent) |p|
                (try p.resolve()).getFile(name[index + 1 ..])
            else
                error.FolderNotFound;
            if (std.mem.eql(u8, folder, ".")) return self.getFile(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.getFile(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            var subfolder_node = self.folders;
            while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
                if (std.mem.eql(u8, subfolder.name, fullname))
                    return subfolder.getFile(name[index + 1 ..]);
            }

            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name });
        defer allocator.alloc.free(fullname);

        if (self.ext) |os_folder| {
            var file_node = self.files;
            while (file_node) |subfile| : (file_node = subfile.next_sibling) {
                if (std.mem.eql(u8, subfile.name, fullname))
                    return subfile;
            }

            if (os_folder.dir.openFile(name, .{}) catch null) |os_file| {
                const file = try allocator.alloc.create(File);
                file.* = .{
                    .parent = .link(self),
                    .name = try allocator.alloc.dupe(u8, fullname),

                    .data = .{
                        .os = os_file,
                    },
                    .next_sibling = self.files,
                };

                self.files = file;

                return file;
            }

            return error.FileNotFound;
        }

        var file_node = self.files;
        while (file_node) |subfile| : (file_node = subfile.next_sibling) {
            if (std.mem.eql(u8, subfile.name, fullname))
                return subfile;
        }

        return error.FileNotFound;
    }

    pub fn getFolder(self: *Folder, name: []const u8) !*Folder {
        if (std.mem.eql(u8, name, ".."))
            return if (self.parent) |p|
                p.resolve()
            else
                error.FolderNotFound;
        if (name.len == 0) return self;

        const first = std.mem.indexOf(u8, name, "/");
        if (first) |index| {
            const folder = name[0..index];

            if (std.mem.eql(u8, folder, "..")) return if (self.parent) |p|
                (try p.resolve()).getFolder(name[index + 1 ..])
            else
                error.FolderNotFound;
            if (std.mem.eql(u8, folder, ".")) return self.getFolder(name[index + 1 ..]);
            if (std.mem.eql(u8, folder, "")) return self.getFolder(name[index + 1 ..]);

            const fullname = try std.mem.concat(allocator.alloc, u8, &.{ self.name, folder, "/" });
            defer allocator.alloc.free(fullname);

            var subfolder_node = self.folders;
            while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
                if (std.mem.eql(u8, subfolder.name, fullname))
                    return subfolder.getFolder(name[index + 1 ..]);
            }

            if (self.ext) |os_folder| {
                if (os_folder.dir.openDir(name[index + 1 ..], .{}) catch null) |os_sub_folder| {
                    const tmp_folder = try allocator.alloc.create(Folder);
                    tmp_folder.* = .{
                        .name = try allocator.alloc.dupe(u8, fullname),
                        .parent = .link(self),
                        .ext = .{
                            .dir = os_sub_folder,
                        },
                        .protected = true,
                        .next_sibling = self.folders,
                    };
                    self.folders = tmp_folder;

                    return tmp_folder.getFolder(name[index + 1 ..]);
                }
            }
            return error.FolderNotFound;
        }

        const fullname = try std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, name });
        defer allocator.alloc.free(fullname);

        var subfolder_node = self.folders;
        while (subfolder_node) |subfolder| : (subfolder_node = subfolder.next_sibling) {
            if (std.ascii.eqlIgnoreCase(subfolder.name, fullname))
                return subfolder;
        }

        if (self.ext) |os_folder| {
            if (os_folder.dir.openDir(name, .{}) catch null) |os_sub_folder| {
                const folder = try allocator.alloc.create(Folder);
                folder.* = .{
                    .name = try allocator.alloc.dupe(u8, fullname),
                    .parent = .link(self),
                    .ext = .{
                        .dir = os_sub_folder,
                    },
                    .protected = true,
                    .next_sibling = self.folders,
                };

                self.folders = folder;

                return folder;
            }
        }

        return error.FolderNotFound;
    }

    pub fn deinit(self: *Folder) void {
        if (self.folders) |subfolder|
            subfolder.deinit();

        if (self.next_sibling) |sibling|
            sibling.deinit();

        if (self.files) |file|
            file.deinit();

        if (self.ext) |*ext_path|
            ext_path.dir.close();

        if (self.parent == null)
            if (root_out) |out| {
                allocator.alloc.free(out);
                root_out = null;
            };

        allocator.alloc.free(self.name);
        allocator.alloc.destroy(self);
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

        var files = std.ArrayList(*File).init(allocator.alloc);
        defer files.deinit();
        try self.getFilesRec(&files);

        std.mem.writeInt(u32, &len, @as(u32, @intCast(files.items.len)), .big);
        try result.appendSlice(&len);
        for (files.items) |file| {
            if (file.data == .disk) {
                std.mem.writeInt(u32, &len, @as(u32, @intCast(file.name.len)), .big);
                try result.appendSlice(&len);
                try result.appendSlice(file.name);
                std.mem.writeInt(u32, &len, @as(u32, @intCast(file.data.disk.len)), .big);
                try result.appendSlice(&len);
                try result.appendSlice(file.data.disk);
            }
        }
        return result;
    }
};

pub fn toStr() !std.ArrayList(u8) {
    return (try FolderLink.resolve(.root)).toStr();
}

pub fn write() void {
    if (options.IsDemo) return;

    if (root_out) |output| {
        const file = std.fs.cwd().createFile(output, .{}) catch {
            @panic("couldnt make save");
        };
        defer file.close();

        if (FolderLink.resolve(.root)) |root|
            root.write(file) catch |err| {
                @panic(std.fmt.allocPrint(allocator.alloc, "failed to save game {}", .{err}) catch "");
            }
        else |_|
            log.warn("root is null on write", .{});
    }
}

pub fn deinit() void {
    if (FolderLink.resolve(.root)) |root|
        root.deinit()
    else |_|
        std.log.warn("root is null on deinit", .{});
}
