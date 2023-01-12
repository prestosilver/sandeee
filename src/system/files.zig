const std = @import("std");
const allocator = @import("../util/allocator.zig");

pub var root: Folder = undefined;

pub const ROOT_NAME = "/";
pub const SCRIPT = "echo lol\necho poop\necho no";

pub const File = struct {
    name: []const u8,
    contents: []const u8,
};

fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}

pub const Folder = struct {
    name: []const u8,
    subfolders: std.ArrayList(Folder),
    contents: std.ArrayList(File),

    pub fn init(alloc: std.mem.Allocator) void {
        root = Folder{
            .name = ROOT_NAME,
            .subfolders = std.ArrayList(Folder).init(alloc),
            .contents = std.ArrayList(File).init(alloc),
        };
        var f = std.fs.cwd().openFile(
            "disk.eee",
            .{ },
        ) catch null;
        if (f == null) {
            root.contents.append(File{
                .name = "/lol.esh",
                .contents = SCRIPT,
            }) catch {};

            return;
        }
        defer f.?.close();

        var file = f.?;

        var lenbuffer: []u8 = allocator.alloc.alloc(u8, 8) catch undefined;
        defer allocator.alloc.free(lenbuffer);
        _ = file.read(lenbuffer) catch 0;
        var count = @bitCast(usize, lenbuffer[0..8].*);
        for (range(count)) |_| {
            _ = file.read(lenbuffer) catch 0;
            var namesize = @bitCast(usize, lenbuffer[0..8].*);
            var namebuffer: []u8 = allocator.alloc.alloc(u8, namesize) catch undefined;
            _ = file.read(namebuffer) catch 0;
            _ = file.read(lenbuffer) catch 0;
            var contsize = @bitCast(usize, lenbuffer[0..8].*);
            var contbuffer: []u8 = allocator.alloc.alloc(u8, contsize) catch undefined;
            _ = file.read(contbuffer) catch 0;
            root.contents.append(File{
                .name = namebuffer,
                .contents = contbuffer,
            }) catch {};
        }
    }

    pub fn write(self: *Folder, writer: std.fs.File) void {
        var files = std.ArrayList(File).init(allocator.alloc);
        defer files.deinit();
        self.getfiles(&files);

        var len = @bitCast([8]u8, files.items.len);
        _ = writer.write(&len) catch 0;
        for (files.items) |file| {
            len = @bitCast([8]u8, file.name.len);
            _ = writer.write(&len) catch 0;
            _ = writer.write(file.name) catch 0;
            len = @bitCast([8]u8, file.contents.len);
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
};

pub fn write() void {
    var file = std.fs.cwd().createFile(
        "disk.eee",
        .{ },
    ) catch null;
    if (file == null) {
        std.c.exit(1);
    }

    defer file.?.close();

    root.write(file.?);
}
