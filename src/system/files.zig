const std = @import("std");
const allocator = @import("../util/allocator.zig");
const fm = @import("../util/files.zig");

pub var root: *Folder = undefined;
pub var home: *Folder = undefined;

pub const ROOT_NAME = "/";

pub const File = struct {
    name: []const u8,
    contents: []const u8,

    pseudoWrite: ?*fn([]const u8) void = null,
    pseudoRead: ?*fn() []const u8 = null,

    pub fn write(self: *File, contents: []const u8) void {
        if (self.pseudoWrite != null) {
            std.log.info("pseudo write", .{});
            self.pseudoWrite.?(contents);
        } else {
            self.contents = contents;
        }
    }

    pub fn read(self: *File) []const u8 {
        if (self.pseudoRead != null) {
            std.log.info("pseudo read", .{});
            return self.pseudoRead.?(true);
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

    pub fn init() void {
        root = allocator.alloc.create(Folder) catch undefined;

        root.name = std.fmt.allocPrint(allocator.alloc, ROOT_NAME, .{}) catch ROOT_NAME;
        root.subfolders = std.ArrayList(Folder).init(allocator.alloc);
        root.contents = std.ArrayList(File).init(allocator.alloc);
        root.parent = root;

        var f = std.fs.cwd().openFile("disk.eee", .{}) catch null;
        if (f == null) {
            var path = fm.getContentDir();
            var d = std.fs.cwd().openDir(path, .{ .access_sub_paths = true }) catch null;

            f = d.?.openFile("content/default.eee", .{}) catch null;
        }
        defer f.?.close();

        var file = f.?;

        var lenbuffer: []u8 = allocator.alloc.alloc(u8, 4) catch undefined;
        defer allocator.alloc.free(lenbuffer);
        _ = file.read(lenbuffer) catch 0;
        var count = @bitCast(u32, lenbuffer[0..4].*);
        for (range(count)) |_| {
            _ = file.read(lenbuffer) catch 0;
            var namesize = @bitCast(u32, lenbuffer[0..4].*);
            var namebuffer: []u8 = allocator.alloc.alloc(u8, namesize) catch undefined;
            defer allocator.alloc.free(namebuffer);
            _ = file.read(namebuffer) catch 0;
            _ = file.read(lenbuffer) catch 0;
            var contsize = @bitCast(u32, lenbuffer[0..4].*);
            var contbuffer: []u8 = allocator.alloc.alloc(u8, contsize) catch undefined;
            _ = file.read(contbuffer) catch 0;
            _ = root.newFile(namebuffer);
            _ = root.writeFile(namebuffer, contbuffer);
        }
    }

    pub fn write(self: *Folder, writer: std.fs.File) void {
        var files = std.ArrayList(File).init(allocator.alloc);
        defer files.deinit();
        self.getfiles(&files);

        var len = @bitCast([4]u8, @intCast(u32, files.items.len));
        _ = writer.write(&len) catch 0;
        for (files.items) |file| {
            len = @bitCast([4]u8, @intCast(u32, file.name.len));
            _ = writer.write(&len) catch 0;
            _ = writer.write(file.name) catch 0;
            len = @bitCast([4]u8, @intCast(u32, file.contents.len));
            _ = writer.write(&len) catch 0;
            _ = writer.write(file.contents) catch 0;
        }
    }

    pub fn getfiles(self: *Folder, files: *std.ArrayList(File)) void {
        files.appendSlice(self.contents.items) catch {};
        for (self.subfolders.items) |_, idx| {
            self.subfolders.items[idx].getfiles(files);
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

    pub fn newFile(self: *Folder, name: []const u8) bool {
        var file = std.ArrayList(u8).init(allocator.alloc);
        defer file.deinit();

        for (name) |ch| {
            if (ch == '/') {
                if (check(file.items, ".")) return self.newFile(name[2..]);
                if (check(file.items, "")) return self.newFile(name[1..]);

                var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }) catch undefined;
                defer allocator.alloc.free(fullname);
                for (self.subfolders.items) |folder, idx| {
                    if (check(folder.name, fullname)) {
                        return self.subfolders.items[idx].newFile(name[file.items.len + 1 ..]);
                    }
                }

                var folder = Folder{
                    .parent = self,
                    .name = std.fmt.allocPrint(allocator.alloc, "{s}{s}/", .{ self.name, file.items }) catch undefined,
                    .contents = std.ArrayList(File).init(allocator.alloc),
                    .subfolders = std.ArrayList(Folder).init(allocator.alloc),
                };
                var result = folder.newFile(name[file.items.len + 1 ..]);
                if (result) {
                    self.subfolders.append(folder) catch {};
                }
                return result;
            } else {
                file.append(ch) catch {};
            }
        }

        var fullname = std.fmt.allocPrint(allocator.alloc, "{s}{s}", .{ self.name, name }) catch undefined;
        for (self.contents.items) |subfile| {
            if (check(subfile.name, fullname)) {
                allocator.alloc.free(fullname);
                return false;
            }
        }

        var cont = std.fmt.allocPrint(allocator.alloc, "", .{}) catch undefined;

        self.contents.append(File{
            .name = fullname,
            .contents = cont,
        }) catch {};

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
                self.contents.items[idx].write(contents);
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
        for (self.contents.items) |subfile, idx| {
            if (check(subfile.name, fullname)) {
                return &self.contents.items[idx];
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

    pub fn toStr(self: *Folder) std.ArrayList(u8) {
        var result = std.ArrayList(u8).init(allocator.alloc);

        var files = std.ArrayList(File).init(allocator.alloc);
        defer files.deinit();
        self.getfiles(&files);

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

pub fn newFile(name: []const u8) bool {
    return root.newFile(name);
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

pub fn toStr() std.ArrayList(u8) {
    return root.toStr();
}

pub fn write(path: []const u8) void {
    var file = std.fs.cwd().createFile(
        path,
        .{},
    ) catch null;
    if (file == null) {
        std.c.exit(1);
    }

    defer file.?.close();

    root.write(file.?);
}

pub fn deinit() void {
    root.deinit();
    allocator.alloc.destroy(root);
}
